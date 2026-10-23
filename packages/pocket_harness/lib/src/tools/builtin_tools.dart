/// 官方内置工具集：依赖显式注入，包本身零宿主耦合。
///
/// 对齐 DeepSeek Harness tool-catalog 的两个 partial 项（见 DSH_ALIGNMENT.md）：
/// - `session_search` / `session_read`：模型侧会话自检索（dsh `session_*` 族）
///   ——agent 能回忆自己早前说过的话、做过的约定，梦境/反思场景的地基；
/// - `web_fetch`：公网只读抓取（dsh `web_fetch`）——读取朋友分享的链接。
///
/// 安全模型与 dsh 对齐并收紧：web_fetch 只抓公开 http(s) 地址，回环/内网/
/// 链路本地/元数据段一律拒绝（[WebFetchGuard]），重定向手动跟随、每一跳
/// 重新校验（`HttpClient` 自动跟随会绕过校验，不能开）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart' show Schema;

import '../session/session_event.dart';
import '../session/session_store.dart';
import 'tool_spec.dart';

// ---------------------------------------------------------------------------
// 会话自检索（session_search / session_read）
// ---------------------------------------------------------------------------

/// 事件的模型可读文本：优先 text（用户/助手消息主键），
/// 其次 output/detail，最后整个 data 的紧凑 JSON。
String sessionEventText(SessionEvent e) {
  final d = e.data;
  for (final key in const ['text', 'output', 'detail']) {
    final v = d[key];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
  }
  if (d.isEmpty) return '';
  return jsonEncode(d);
}

String _fmtTime(DateTime ts) {
  final m = ts.month.toString().padLeft(2, '0');
  final d = ts.day.toString().padLeft(2, '0');
  final hh = ts.hour.toString().padLeft(2, '0');
  final mm = ts.minute.toString().padLeft(2, '0');
  return '${ts.year}-$m-$d $hh:$mm';
}

int _clampInt(Object? raw, int min, int max, int fallback) {
  final v = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  if (v == null) return fallback;
  return v < min ? min : (v > max ? max : v);
}

/// 关键词命中上下文摘录：命中点前后各留窗口，换行压成空格。
String _excerpt(String text, int matchIndex, int needleLength,
    {int before = 60, int after = 90}) {
  final start = (matchIndex - before).clamp(0, text.length);
  final end = (matchIndex + needleLength + after).clamp(0, text.length);
  final head = start > 0 ? '…' : '';
  final tail = end < text.length ? '…' : '';
  final body =
      text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
  return '$head$body$tail';
}

/// `session_search`：按关键词检索当前会话历史。
///
/// 返回格式固定为"序号 + 类型 + 时间 + 摘录"，序号是回放顺序位置（1 起），
/// 可直接喂给 [buildSessionReadTool] 的 `from` 翻上下文。
ToolSpec buildSessionSearchTool({
  required SessionStore store,
  required String Function() threadId,
  int defaultLimit = 10,
}) {
  return ToolSpec(
    name: 'session_search',
    description: '在当前会话历史（你与主人的对话、工具调用记录）中按关键词检索，'
        '用于回忆早前的约定、事实与上下文。返回匹配条目的序号、时间与摘录；'
        '要看某条前后的完整上下文，用 session_read 从该序号附近翻页。',
    permission: PermissionLevel.normal,
    inputSchema: Schema.object(properties: {
      'query': Schema.string(description: '检索关键词（子串匹配，不区分大小写）'),
      'limit': Schema.integer(description: '最多返回条数，默认 $defaultLimit，上限 50'),
    }, required: ['query']),
    handler: (ctx, args) async {
      final query = (args['query'] ?? '').toString().trim();
      if (query.isEmpty) return '【session_search】query 不能为空';
      final limit = _clampInt(args['limit'], 1, 50, defaultLimit);
      final tid = threadId();
      final List<SessionEvent> events;
      try {
        events = await store.replay(tid);
      } catch (e) {
        return '【session_search】会话读取失败: $e';
      }
      final needle = query.toLowerCase();
      final lines = <String>[];
      var hits = 0;
      for (var i = 0; i < events.length && hits < limit; i++) {
        final text = sessionEventText(events[i]);
        final idx = text.toLowerCase().indexOf(needle);
        if (idx == -1) continue;
        hits++;
        lines.add('#${i + 1} [${events[i].type}] ${_fmtTime(events[i].ts)}\n'
            '  ${_excerpt(text, idx, query.length)}');
      }
      if (hits == 0) {
        return '【session_search】会话「$tid」（共 ${events.length} 条事件）'
            '中没有包含"$query"的记录';
      }
      return '【session_search】会话「$tid」共 ${events.length} 条事件，'
          '命中 $hits 条（显示前 $hits 条）：\n${lines.join('\n')}';
    },
  );
}

/// `session_read`：从指定回放位置顺序读取会话事件（翻上下文用）。
ToolSpec buildSessionReadTool({
  required SessionStore store,
  required String Function() threadId,
  int defaultLimit = 20,
  int perEventMaxChars = 600,
}) {
  return ToolSpec(
    name: 'session_read',
    description: '从会话历史的指定位置顺序读取事件原文（配合 session_search '
        '返回的序号使用，from 从 0 起）。用于回忆一段对话的完整经过。',
    permission: PermissionLevel.normal,
    inputSchema: Schema.object(properties: {
      'from': Schema.integer(description: '起始回放位置（0 = 最早一条），默认 0'),
      'limit': Schema.integer(description: '最多读取条数，默认 $defaultLimit，上限 100'),
    }),
    handler: (ctx, args) async {
      final from = _clampInt(args['from'], 0, 1 << 30, 0);
      final limit = _clampInt(args['limit'], 1, 100, defaultLimit);
      final tid = threadId();
      final List<SessionEvent> events;
      try {
        events = await store.replay(tid);
      } catch (e) {
        return '【session_read】会话读取失败: $e';
      }
      if (from >= events.length) {
        return '【session_read】位置 $from 已超出会话末尾（共 ${events.length} 条事件）';
      }
      final end = (from + limit).clamp(0, events.length);
      final buf = StringBuffer(
          '【session_read】会话「$tid」事件 #$from..${end - 1}（共 ${events.length} 条）：\n');
      for (var i = from; i < end; i++) {
        final text = sessionEventText(events[i]);
        final shown = text.length <= perEventMaxChars
            ? text
            : '${text.substring(0, perEventMaxChars)}…[截断]';
        buf.writeln('#$i [${events[i].type}] ${_fmtTime(events[i].ts)}');
        if (shown.isNotEmpty) buf.writeln('  $shown');
      }
      if (end < events.length) {
        buf.write('（后面还有 ${events.length - end} 条，可用更大的 from 继续）');
      }
      return buf.toString().trim();
    },
  );
}

// ---------------------------------------------------------------------------
// 公网只读抓取（web_fetch）
// ---------------------------------------------------------------------------

/// web_fetch 的地址守卫：只放行公网 http(s)。
///
/// 拒绝清单（SSRF 防护，与 dsh"拒绝非公开目的地址"对齐并加细）：
/// 非 http(s) 协议、带 userinfo 的 URL、localhost 及 .local/.internal 域、
/// IPv4 私有/保留段（0/8、10/8、127/8、100.64/10、169.254/16、172.16/12、
/// 192.168/16、224+/组播）、IPv6 回环/链路本地/唯一本地/IPv4 映射私网。
abstract final class WebFetchGuard {
  static final _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

  static bool isPublicHttpUrl(Uri url) {
    if (url.scheme != 'http' && url.scheme != 'https') return false;
    if (url.userInfo.isNotEmpty) return false;
    final rawHost = url.host.toLowerCase();
    if (rawHost.isEmpty) return false;
    final host = rawHost.startsWith('[') && rawHost.endsWith(']')
        ? rawHost.substring(1, rawHost.length - 1)
        : rawHost;
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal')) {
      return false;
    }
    final v4 = _ipv4.firstMatch(host);
    if (v4 != null) {
      final groups = v4.groups([1, 2, 3, 4]);
      if (groups.any((g) => g == null)) return false;
      final o = [for (final g in groups) int.parse(g!)];
      if (o.any((x) => x > 255)) return false;
      return _isPublicIpv4(o);
    }
    final addr = InternetAddress.tryParse(host);
    if (addr != null) {
      return _isPublicIpv6(host, addr);
    }
    return true; // 普通域名
  }

  static bool _isPublicIpv4(List<int> o) {
    final a = o[0], b = o[1];
    if (a == 0 || a == 10 || a == 127) return false;
    if (a == 100 && b >= 64 && b <= 127) return false; // CGNAT
    if (a == 169 && b == 254) return false; // 链路本地/云元数据
    if (a == 172 && b >= 16 && b <= 31) return false;
    if (a == 192 && b == 168) return false;
    if (a >= 224) return false; // 组播与保留
    return true;
  }

  static bool _isPublicIpv6(String host, InternetAddress addr) {
    if (addr.isLoopback || addr.isLinkLocal) return false;
    // IPv4 映射 ::ffff:10.0.0.1 —— 按映射的 v4 段判定
    final mapped = RegExp(r'^::ffff:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$',
            caseSensitive: false)
        .firstMatch(host);
    if (mapped != null) {
      final o = [for (final g in mapped.group(1)!.split('.')) int.parse(g)];
      if (o.any((x) => x > 255)) return false;
      return _isPublicIpv4(o);
    }
    // 唯一本地 fc00::/7：首字节高 7 位为 1111110x
    final first = int.tryParse(host.split(':')[0], radix: 16);
    if (first != null && ((first >> 8) & 0xFE) == 0xFC) return false;
    return true;
  }
}

/// 极简 HTML → 纯文本：去 script/style/注释、块级标签转行、剥标签、
/// 解常见实体、压空行。为"读朋友分享的链接"服务，不做全文排版还原。
String htmlToText(String html) {
  var s = html;
  s = s.replaceAll(
      RegExp(r'<(script|style)[\s\S]*?</\1>', caseSensitive: false), ' ');
  s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
  s = s.replaceAll(
      RegExp(r'</?(br|p|div|li|tr|h[1-6]|ul|ol|table|section|article)[^>]*>',
          caseSensitive: false),
      '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
  s = _decodeEntities(s);
  final lines = s
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((l) => l.isNotEmpty);
  return lines.join('\n');
}

String? extractHtmlTitle(String html) {
  final m = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
      .firstMatch(html);
  if (m == null) return null;
  final t = _decodeEntities(m.group(1)!).replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.isEmpty ? null : t;
}

String _decodeEntities(String s) {
  var out = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  // 数字实体（十进制/十六进制）
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final v = int.tryParse(m.group(1)!);
    return v == null ? m.group(0)! : String.fromCharCode(v);
  });
  out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final v = int.tryParse(m.group(1)!, radix: 16);
    return v == null ? m.group(0)! : String.fromCharCode(v);
  });
  return out;
}

/// `web_fetch`：公网网页只读抓取。GET-only、手动重定向逐跳校验、
/// 文本类内容转纯文本截断返回。用于读取朋友分享的链接、查证公开信息。
ToolSpec buildWebFetchTool({
  bool Function(Uri url)? urlGuard,
  int defaultMaxChars = 8000,
  int maxBytes = 2 * 1024 * 1024,
  Duration timeout = const Duration(seconds: 20),
  int maxRedirects = 5,
}) {
  final guard = urlGuard ?? WebFetchGuard.isPublicHttpUrl;
  return ToolSpec(
    name: 'web_fetch',
    description: '抓取一个公开网页并返回正文纯文本（HTML 自动转文本，超长截断）。'
        '用于阅读朋友分享的链接、查证公开资料。限制：只能 GET 公网 http(s) '
        '地址（拒绝本机/内网），不能登录、提交表单或执行页面脚本。',
    permission: PermissionLevel.normal,
    inputSchema: Schema.object(properties: {
      'url': Schema.string(description: '要抓取的完整 URL（http/https）'),
      'max_chars':
          Schema.integer(description: '返回正文最大字符数，默认 $defaultMaxChars'),
    }, required: ['url']),
    handler: (ctx, args) async {
      final rawUrl = (args['url'] ?? '').toString().trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || rawUrl.isEmpty) {
        return '【web_fetch】URL 无法解析: "$rawUrl"';
      }
      if (!guard(uri)) {
        return '【web_fetch】拒绝访问非公开地址: "$rawUrl"（本工具只抓取公网网页）';
      }
      final maxChars = _clampInt(args['max_chars'], 500, 20000, defaultMaxChars);

      var current = uri;
      String? bodyText;
      String mime = '';
      for (var hop = 0; hop <= maxRedirects; hop++) {
        final HttpClientResponse resp;
        try {
          final req = await ctx.httpClient.getUrl(current);
          req.followRedirects = false; // 手动跟随：每一跳重新过守卫
          req.headers.set(HttpHeaders.userAgentHeader,
              'pocket_harness-web_fetch (+https://github.com/woldworld/fen)');
          resp = await req.close().timeout(timeout);
        } on TimeoutException {
          return '【web_fetch】抓取超时（>${timeout.inSeconds}s）: $current';
        } on SocketException catch (e) {
          return '【web_fetch】网络不可达: $current（${e.message}）';
        }
        final status = resp.statusCode;
        if (status >= 300 && status < 400) {
          final loc = resp.headers.value(HttpHeaders.locationHeader);
          await resp.drain<void>();
          if (loc == null) return '【web_fetch】HTTP $status 重定向缺少 Location';
          final next = current.resolve(loc);
          if (!guard(next)) {
            return '【web_fetch】重定向到非公开地址被拒绝: $next';
          }
          current = next;
          continue;
        }
        if (status != 200) {
          await resp.drain<void>();
          return '【web_fetch】HTTP $status from $current';
        }
        mime = resp.headers.contentType?.mimeType ?? 'application/octet-stream';
        final isText = mime.startsWith('text/') ||
            mime == 'application/json' ||
            mime == 'application/xml' ||
            mime == 'application/javascript';
        if (!isText) {
          await resp.drain<void>();
          return '【web_fetch】不支持的内容类型 "$mime"（只能读取文本类网页）';
        }
        final bytes = <int>[];
        var overflow = false;
        try {
          await for (final chunk in resp) {
            bytes.addAll(chunk);
            if (bytes.length > maxBytes) {
              overflow = true;
              break; // 退出 await-for 即取消订阅，连接被回收
            }
          }
        } on TimeoutException {
          return '【web_fetch】读取正文超时: $current';
        }
        final charset = resp.headers.contentType?.charset;
        final encoding = Encoding.getByName(charset ?? 'utf-8') ?? utf8;
        bodyText = _decodeBody(bytes, encoding);
        if (overflow) bodyText += '\n…[正文超过 ${maxBytes ~/ 1024}KB，已截断]';
        break;
      }
      if (bodyText == null) {
        return '【web_fetch】重定向超过 $maxRedirects 次，放弃: $current';
      }

      final content =
          mime.contains('html') ? htmlToText(bodyText) : bodyText.trim();
      final title = mime.contains('html') ? extractHtmlTitle(bodyText) : null;
      final clipped = content.length > maxChars
          ? '${content.substring(0, maxChars)}\n…[已截断，原文 ${content.length} 字符]'
          : content;
      final head = StringBuffer('【web_fetch】$current');
      if (title != null) head.write('\n标题: $title');
      return '$head\n\n${clipped.isEmpty ? '（正文为空）' : clipped}';
    },
  );
}

String _decodeBody(List<int> bytes, Encoding encoding) {
  String text;
  try {
    text = encoding.decode(bytes);
  } catch (_) {
    // 非严格编码（如 GBK 字节按 utf-8 解）失败时兜底为容错 UTF-8
    text = utf8.decode(bytes, allowMalformed: true);
  }
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  return text;
}
