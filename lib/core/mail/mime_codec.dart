/// 邮箱工具 · MIME 解码（**纯函数**，可离线单测）
///
/// 只做"读邮件真正需要的那一块"：头部解码（RFC 2047）、传输编码解码
/// （base64 / quoted-printable）、multipart 拆分、以及"从多个 part 里挑出正文"。
///
/// 刻意**不做**的事：
/// - 不解析附件内容（只把附件名与大小报出来，正文里不掺附件二进制）；
/// - 不实现完整 charset 表（只有 UTF-8 与 Latin-1 两档 + 明确的降级标注），
///   遇到 GBK/Big5 这类**多字节老编码**会丢字 —— 这是已知边界，写在这里而不是
///   假装支持。
library;

import 'dart:convert';

import 'package:pocket_harness/pocket_harness.dart' show htmlToText;

/// 一个 MIME 节点（邮件本身，或 multipart 里的一个 part）。
class MimeNode {
  /// 头部名统一小写；同名字段（如 Received）只保留第一条。
  final Map<String, String> headers;

  /// **未解码**的正文原始串（仍带 base64 / QP 编码）。
  final String rawBody;

  /// multipart 的子节点（非 multipart 时为空）。
  final List<MimeNode> children;

  const MimeNode({
    required this.headers,
    required this.rawBody,
    this.children = const [],
  });

  /// `text/plain`、`multipart/alternative` 这类主类型（已去参数、转小写）。
  String get contentType {
    final raw = headers['content-type'] ?? 'text/plain';
    final semi = raw.indexOf(';');
    return (semi < 0 ? raw : raw.substring(0, semi)).trim().toLowerCase();
  }

  /// `charset=` 参数（缺省 `utf-8`）。
  String get charset {
    final raw = headers['content-type'] ?? '';
    final m = RegExp(r'charset\s*=\s*"?([A-Za-z0-9_\-]+)"?',
            caseSensitive: false)
        .firstMatch(raw);
    return (m?.group(1) ?? 'utf-8').toLowerCase();
  }

  /// `boundary=` 参数（multipart 才有）。
  String? get boundary {
    final raw = headers['content-type'] ?? '';
    // boundary 可能带引号，也可能是裸 token；两种都要认（RFC 2046 §5.1.1）
    final quoted = RegExp(r'boundary\s*=\s*"([^"]+)"', caseSensitive: false)
        .firstMatch(raw);
    if (quoted != null) return quoted.group(1);
    final bare = RegExp(r'boundary\s*=\s*([^;\s]+)', caseSensitive: false)
        .firstMatch(raw);
    return bare?.group(1);
  }

  bool get isMultipart => contentType.startsWith('multipart/');

  /// 该节点正文的**解码后**文本（按 charset + transfer-encoding 处理）。
  ///
  /// multipart 节点返回空串 —— 正文在 [children] 里。
  ///
  /// ★ 只对 `base64` / `quoted-printable` 走"字节 → 按 charset 解码"这条路。
  /// `7bit` / `8bit` / `binary` / 未声明时，[rawBody] **本身已经是字符串**
  /// （上游用 `utf8.decode(literal)` 得到的），若再取 `codeUnits` 去过一遍
  /// `utf8.decode`，中文会被解成乱码 —— 这是施工时踩到并修掉的真 bug。
  String get decodedBody {
    if (isMultipart) return '';
    final cte = (headers['content-transfer-encoding'] ?? '').trim().toLowerCase();
    if (cte == 'base64' || cte == 'quoted-printable') {
      return decodeBytes(decodeTransfer(rawBody, cte), charset);
    }
    return rawBody;
  }
}

// ---------------------------------------------------------------------------
// 头部
// ---------------------------------------------------------------------------

/// 拆出头部与正文，并**展开续行**（continuation line 以空白开头）。
///
/// 返回 `(headers, rawBody)`。头名小写；首条优先。
(Map<String, String>, String) splitHeadersAndBody(String raw) {
  // 头/正文分隔：空行。三种行尾都认。
  final m = RegExp(r'\r?\n\r?\n').firstMatch(raw);
  final headPart = m == null ? raw : raw.substring(0, m.start);
  final bodyPart = m == null ? '' : raw.substring(m.end);

  final unfolded = headPart.replaceAll(RegExp(r'\r?\n[ \t]+'), ' ');
  final headers = <String, String>{};
  for (final line in unfolded.split(RegExp(r'\r?\n'))) {
    if (line.trim().isEmpty) continue;
    final c = line.indexOf(':');
    if (c <= 0) continue;
    final k = line.substring(0, c).trim().toLowerCase();
    final v = line.substring(c + 1).trim();
    headers.putIfAbsent(k, () => v);
  }
  return (headers, bodyPart);
}

/// RFC 2047 编码字解码：`=?UTF-8?B?...?=` / `=?UTF-8?Q?...?=`。
///
/// 相邻编码字之间的空白按规范**必须丢弃**（否则中文长主题会被塞进空格）。
String decodeEncodedWords(String input) {
  if (!input.contains('=?')) return input;
  final re = RegExp(r'=\?([^?]+)\?([BbQq])\?([^?]*)\?=');
  final sb = StringBuffer();
  var last = 0;
  String? pendingCharset;
  for (final m in re.allMatches(input)) {
    final between = input.substring(last, m.start);
    if (pendingCharset == null) {
      sb.write(between);
    } else {
      // 上一个编码字与这一个之间若**只有空白**，按 RFC 2047 丢弃
      if (between.trim().isNotEmpty) sb.write(between);
    }
    last = m.end;
    final charset = m.group(1)!;
    final enc = m.group(2)!.toUpperCase();
    final payload = m.group(3)!;
    final bytes =
        enc == 'B' ? _b64Bytes(payload) : _rfc2047QBytes(payload);
    sb.write(decodeBytes(bytes, charset));
    pendingCharset = charset;
  }
  if (last == 0) return input;
  sb.write(input.substring(last));
  return sb.toString();
}

// ---------------------------------------------------------------------------
// 传输编码
// ---------------------------------------------------------------------------

/// 按 `Content-Transfer-Encoding` 把原始正文还原成字节。
List<int> decodeTransfer(String raw, String cte) {
  switch (cte.trim().toLowerCase()) {
    case 'base64':
      return _b64Bytes(raw);
    case 'quoted-printable':
      return _quotedPrintableBytes(raw);
    default:
      // 7bit / 8bit / binary / 空：原样（按 Latin-1 取字节，保住高位字节）
      return raw.codeUnits;
  }
}

/// 按 charset 把字节解成字符串。
///
/// 只有两档：UTF-8，其余一律 Latin-1（**不抛异常** —— 邮件可能任何编码都有，
/// 抛异常等于整封信读不出来；宁可个别字变乱码，也不能整封失败）。
String decodeBytes(List<int> bytes, String charset) {
  final cs = charset.toLowerCase().trim();
  final isUtf8 = cs == 'utf-8' || cs == 'utf8' || cs.isEmpty;
  if (isUtf8) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }
  if (cs == 'us-ascii' || cs == 'ascii') {
    return latin1.decode(bytes, allowInvalid: true);
  }
  // iso-8859-* / windows-1252 / gbk / big5 / shift_jis … 统一降级
  return latin1.decode(bytes, allowInvalid: true);
}

/// 编码时用：判断某串是否纯 ASCII（决定要不要走 RFC 2047）。
bool isAsciiOnly(String s) => s.codeUnits.every((c) => c < 128);

/// 把任意头部值编码成可安全放在头部里的 ASCII（RFC 2047 折行编码）。
String encodeHeaderValue(String s) {
  if (isAsciiOnly(s)) return s;
  final b64 = base64.encode(utf8.encode(s));
  // 长值按 60 字符折成多个编码字，避免超过 76 字符行长
  final chunks = <String>[];
  for (var i = 0; i < b64.length; i += 60) {
    chunks.add('=?UTF-8?B?${b64.substring(i, i + 60 > b64.length ? b64.length : i + 60)}?=');
  }
  return chunks.join('\r\n ');
}

// ---------------------------------------------------------------------------
// multipart
// ---------------------------------------------------------------------------

/// 按 boundary 拆出子节点（**递归**：嵌套 multipart 也拆）。
///
/// 宽容策略：boundary 找不到、或者拆出来是空的，就**退回**把整段当单个节点，
/// 而不是抛异常 —— 真实世界的邮件比规范脏得多，读信工具不能因为格式瑕疵整封失败。
MimeNode parseMessage(String raw) {
  final (headers, body) = splitHeadersAndBody(raw);
  final root = MimeNode(headers: headers, rawBody: body);
  return _expand(root);
}

MimeNode _expand(MimeNode node) {
  if (!node.isMultipart) return node;
  final b = node.boundary;
  if (b == null || b.isEmpty) {
    return MimeNode(headers: node.headers, rawBody: node.rawBody);
  }
  final parts = splitMultipart(node.rawBody, b);
  if (parts.isEmpty) {
    return MimeNode(headers: node.headers, rawBody: node.rawBody);
  }
  final kids = <MimeNode>[];
  for (final p in parts) {
    final (h, bd) = splitHeadersAndBody(p);
    kids.add(_expand(MimeNode(headers: h, rawBody: bd)));
  }
  return MimeNode(headers: node.headers, rawBody: '', children: kids);
}

/// 按 boundary 切分原始正文。
List<String> splitMultipart(String raw, String boundary) {
  final delim = '--$boundary';
  final out = <String>[];
  var idx = raw.indexOf(delim);
  if (idx < 0) return out;
  // 跳过第一段（preamble）
  idx += delim.length;
  while (true) {
    // 结束标记 `--boundary--`
    if (raw.startsWith('--', idx)) break;
    // 吃掉边界行剩下的部分（含 CRLF / LF）
    final nl = raw.indexOf('\n', idx);
    if (nl < 0) break;
    final start = nl + 1;
    final next = raw.indexOf(delim, start);
    if (next < 0) break;
    var seg = raw.substring(start, next);
    // 段尾的回车属于边界行，不属于正文
    if (seg.endsWith('\r\n')) {
      seg = seg.substring(0, seg.length - 2);
    } else if (seg.endsWith('\n')) {
      seg = seg.substring(0, seg.length - 1);
    }
    out.add(seg);
    idx = next + delim.length;
  }
  return out;
}

/// 从解析结果里挑出**要喂给主人的正文**。
///
/// 优先级：`text/plain`（非空）> `text/html` 转纯文本 > 空串。
/// 刻意**不**在 text/plain 存在时再拼 HTML —— 见过太多"纯文本部分只有
/// 「请用 HTML 查看」一句话"的邮件，那种情况下应回落到 HTML。
String extractPlainText(MimeNode node) {
  final plain = <String>[];
  final html = <String>[];
  void walk(MimeNode n) {
    if (n.isMultipart) {
      for (final c in n.children) {
        walk(c);
      }
      return;
    }
    final ct = n.contentType;
    final body = n.decodedBody;
    if (ct == 'text/plain') {
      plain.add(body);
    } else if (ct == 'text/html') {
      html.add(body);
    }
  }

  walk(node);

  final plainText = plain.join('\n').trim();
  if (plainText.isNotEmpty && !_looksLikeBoilerplate(plainText)) {
    return plainText;
  }
  final htmlText = html.map(htmlToText).join('\n').trim();
  if (htmlText.isNotEmpty) return htmlText;
  return plainText;
}

/// "纯文本部分其实什么都没有"的常见形态。
bool _looksLikeBoilerplate(String s) {
  final t = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length > 80) return false;
  return t.contains('view this email in your browser') ||
      t.contains('html') && t.length < 40;
}

/// 附件名列表（只报名字，不取内容）。
///
/// 这是**安全取舍**：把附件二进制塞进上下文既烧 token 又是提示注入的高危载体。
List<String> attachmentNames(MimeNode node) {
  final out = <String>[];
  void walk(MimeNode n) {
    if (n.isMultipart) {
      for (final c in n.children) {
        walk(c);
      }
      return;
    }
    final raw = n.headers['content-disposition'] ?? '';
    if (!raw.toLowerCase().contains('attachment')) return;
    final m = RegExp(r'filename\s*=\s*"([^"]+)"', caseSensitive: false)
            .firstMatch(raw) ??
        RegExp(r'filename\s*=\s*([^;\s]+)', caseSensitive: false).firstMatch(raw);
    if (m != null) out.add(decodeEncodedWords(m.group(1)!.trim()));
  }

  walk(node);
  return out;
}

// ---------------------------------------------------------------------------
// 字节级小工具
// ---------------------------------------------------------------------------

List<int> _b64Bytes(String s) {
  final clean = s.replaceAll(RegExp(r'\s'), '');
  if (clean.isEmpty) return const [];
  // 补齐 padding：有些服务端会漏 '='
  final pad = clean.length % 4;
  final fixed = pad == 0 ? clean : clean + '=' * (4 - pad);
  try {
    return base64.decode(fixed);
  } catch (_) {
    return const [];
  }
}

/// RFC 2047 的 **Q 编码**：`_` 代表空格，`=XX` 是十六进制。
///
/// 与正文的 quoted-printable **不是同一套**（Q 编码里 `_` 是空格，QP 里不是），
/// 所以单独一个函数，不复用 `_quotedPrintableBytes` —— 复用会漏掉 `_`。
List<int> _rfc2047QBytes(String s) {
  final out = <int>[];
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 0x5F /* _ */) {
      out.add(0x20);
      i += 1;
      continue;
    }
    if (c == 0x3D /* = */ && i + 2 < s.length) {
      final v = int.tryParse(s.substring(i + 1, i + 3), radix: 16);
      if (v != null) {
        out.add(v);
        i += 3;
        continue;
      }
    }
    out.add(c);
    i += 1;
  }
  return out;
}

List<int> _quotedPrintableBytes(String s) {
  final out = <int>[];
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 0x3D /* = */) {
      // 软换行：`=\r\n` 或 `=\n`
      if (i + 1 < s.length && s.codeUnitAt(i + 1) == 0x0D) {
        i += (i + 2 < s.length && s.codeUnitAt(i + 2) == 0x0A) ? 3 : 2;
        continue;
      }
      if (i + 1 < s.length && s.codeUnitAt(i + 1) == 0x0A) {
        i += 2;
        continue;
      }
      if (i + 2 < s.length) {
        final hex = s.substring(i + 1, i + 3);
        final v = int.tryParse(hex, radix: 16);
        if (v != null) {
          out.add(v);
          i += 3;
          continue;
        }
      }
      out.add(c);
      i += 1;
      continue;
    }
    out.add(c);
    i += 1;
  }
  return out;
}
