/// 邮箱工具 · IMAP 最小子集（只做"列信 + 读一封"）
///
/// 刻意**不做**：IDLE（实时推送，见方案 §2「设备直连的能力上限」）、
/// 删除/移动/标记（写操作会扩大爆炸半径）、附件下载（提示注入高危 + 烧 token）。
///
/// 协议要点（也是唯一的难点）：IMAP 的字面量是 `{n}` + 紧随其后的 **n 字节**，
/// 不是行文本 —— 所以读取必须逐字节精确，靠 [MailTransport.readExact]。
///
/// ★ 本类只依赖 [MailTransport]，因此**可离线驱动**（喂预置字节流即可跑完整会话）。
///
/// ★★ 0.66.0 新增：登录后按需发 `ID`（RFC 2971）。
/// **网易邮箱（163 / 126 / yeah.net）**在 `LOGIN` 之后要求客户端先声明身份，
/// 否则后续 `SELECT` 一律回
/// `NO [UNAVAILABLE] Unsafe Login. Please contact kefu@188.com` ——
/// **授权码填得再对也连不上**（真机反馈：163 账号"看着连上了，一读信就被踢"）。
/// 详见 [_loginAndIdentify] 里"为什么先探 CAPABILITY 再发"的说明。
library;

import 'dart:convert';

import 'mail_transport.dart';
import 'mail_types.dart';
import 'mime_codec.dart';

/// 连接器签名（测试注入用）。
typedef MailConnector = Future<MailTransport> Function(String host, int port);

class ImapClient {
  final String host;
  final int port;
  final String user;
  final String password;
  final MailConnector _connect;
  final Duration timeout;

  MailTransport? _t;
  int _tagSeq = 0;

  ImapClient({
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    MailConnector? connector,
    this.timeout = const Duration(seconds: 30),
  }) : _connect = connector ??
            ((h, p) => MailTransport.connectTls(h, p, connectTimeout: timeout));

  String _tag() {
    _tagSeq += 1;
    return 'a$_tagSeq';
  }

  /// 向服务端声明的客户端身份（RFC 2971 的 `name`/`version`/`vendor` 字段）。
  /// 只声明"是什么客户端"，**不含任何用户数据**（不是隐私面）。
  static const String idName = 'Fen';
  static const String idVersion = '1.0';
  static const String idVendor = 'Wold';

  /// 服务端响应里是否广告了 `ID`（RFC 2971）。
  ///
  /// 只看 `* CAPABILITY ...` 那一行的 token，**不许**用 `contains('ID')` ——
  /// 那会被 `UIDPLUS` / `XAPPLEPUSHSERVICE` 之类误命中（假绿）。
  static bool advertisesId(List<MailLine> lines) {
    for (final l in lines) {
      final t = l.text.trim().toUpperCase();
      if (!t.startsWith('* CAPABILITY')) continue;
      return t.split(RegExp(r'\s+')).contains('ID');
    }
    return false;
  }

  Future<void> _ensureConnected() async {
    if (_t != null) return;
    final t = await _connect(host, port);
    _t = t;
    final greeting = await t.readLine();
    if (greeting == null) {
      throw const MailConnectException('IMAP 服务端未返回问候语');
    }
    final g = greeting.toUpperCase();
    if (!g.startsWith('* OK') && !g.startsWith('* PREAUTH')) {
      throw MailProtocolException('IMAP 问候异常：$greeting');
    }
  }

  /// 执行一条命令并返回响应行（已校验完成行是 OK）。
  Future<List<MailLine>> _cmd(String command, {Set<String>? continueOn}) async {
    await _ensureConnected();
    final t = _t!;
    final tag = _tag();
    t.write('$tag $command\r\n');
    final lines = await t.readUntilTagged(tag);
    final done = lines.last.text;
    final ok = done.toUpperCase().startsWith('${tag.toUpperCase()} OK');
    if (!ok) {
      final allow = continueOn != null &&
          continueOn.any((s) => done.toUpperCase().contains(s));
      if (!allow) {
        // ★ 0.81.0：异常文案**绝不回显凭证** —— `LOGIN` 命令原文带着授权码，
        // 直接抛出去就会印在 UI 错误横幅上、并落进 `last_error`（0.80.0 真机
        // 截图实证：授权码明文出现在屏上）。服务端响应原则上不含凭证，
        // 但同样过一遍（防御性，成本为零）。
        throw MailProtocolException(
            'IMAP ${_redact(command)} 失败：${_redact(done.trim())}');
      }
    }
    return lines;
  }

  /// 把 [s] 里的凭证替换成掩码（原文形态 + IMAP 引号转义形态都要替换）。
  ///
  /// ★ 用 `replaceAll` 的**字面量**重载（不是正则）：授权码里可能有 `.*+` 之类
  /// 字符，按正则会抛 `FormatException`，把"报错"变成"抛不出错"。
  String _redact(String s) {
    if (password.isEmpty) return s;
    return s
        .replaceAll(_q(password), '"****"')
        .replaceAll(password, '****');
  }

  /// 登录 + 按需声明客户端身份（RFC 2971）。**三处入口共用这一份**。
  ///
  /// 顺序固定：`LOGIN` → `CAPABILITY` →（广告了 ID 才）`ID`。
  ///
  /// ★ 为什么先探 `CAPABILITY`、而不是无脑发 `ID`：
  ///   有的服务端对**它不认识的命令**会回一条**不带 tag** 的 `* BAD Command!`
  ///   （协议违规 —— 完成行必须以 tag 开头）。而 [MailTransport.readUntilTagged]
  ///   是"一直读到带 tag 的完成行"，碰上这种响应就会**挂到超时**，把一个
  ///   "该跳过的可选命令"变成"整条链路不可用"。只对**自己广告了 ID** 的服务端
  ///   发，就同时满足两边：网易拿到它要的身份声明，其余服务端一个多余命令都收不到。
  ///   （已在 163/126/QQ/Gmail/Yahoo/sina 的 CAPABILITY 上核对过：均含 `ID`。）
  ///
  /// ★ 容错：`ID` 回 `NO/BAD` 时**不阻断后续** —— 身份声明是"锦上添花"，
  ///   真正决定能不能读信的是 `SELECT`；不该因为声明格式被拒就把功能判死。
  Future<void> _loginAndIdentify() async {
    await _cmd('LOGIN ${_q(user)} ${_q(password)}');
    final caps = await _cmd('CAPABILITY');
    if (!advertisesId(caps)) return;
    await _cmd(
      'ID ("name" "$idName" "version" "$idVersion" "vendor" "$idVendor")',
      continueOn: {'NO', 'BAD'},
    );
  }

  /// 登录并发一次 `SELECT INBOX`，用于"测试连接"按钮。
  Future<void> testConnection() async {
    try {
      await _loginAndIdentify();
      await _cmd('SELECT "INBOX"');
    } finally {
      await logout();
    }
  }

  /// 列最近的信封（不含正文）。
  Future<List<MailSummary>> list({int limit = 20, bool unreadOnly = false}) async {
    if (limit <= 0) return const [];
    try {
      await _loginAndIdentify();
      await _cmd('SELECT "INBOX"');

      final searchLines =
          await _cmd(unreadOnly ? 'UID SEARCH UNSEEN' : 'UID SEARCH ALL');
      final uids = <int>[];
      for (final l in searchLines) {
        if (!l.text.startsWith('* SEARCH')) continue;
        for (final tok in l.text.substring('* SEARCH'.length).trim().split(RegExp(r'\s+'))) {
          final n = int.tryParse(tok);
          if (n != null) uids.add(n);
        }
      }
      if (uids.isEmpty) return const [];
      final slice = uids.length > limit ? uids.sublist(uids.length - limit) : uids;

      // 一次取多封：UID FETCH 支持集合，避免 N 次往返
      final set = slice.join(',');
      final fetchLines = await _cmd(
          'UID FETCH $set (UID FLAGS BODY.PEEK[HEADER.FIELDS (SUBJECT FROM DATE MESSAGE-ID)])');

      final out = <MailSummary>[];
      for (final l in fetchLines) {
        if (!l.text.contains('FETCH')) continue;
        if (l.literals.isEmpty) continue;
        final uid = _uidOf(l.text);
        if (uid == null) continue;
        final head = utf8.decode(l.literals.first, allowMalformed: true);
        final (h, _) = splitHeadersAndBody(head);
        out.add(MailSummary(
          uid: '$uid',
          subject: decodeEncodedWords(h['subject'] ?? ''),
          from: decodeEncodedWords(h['from'] ?? ''),
          date: decodeEncodedWords(h['date'] ?? ''),
          seen: (l.text.toLowerCase().contains(r'\seen')),
        ));
      }
      return out;
    } finally {
      await logout();
    }
  }

  /// 读一封的正文（已转纯文本，并附附件名——**不取附件内容**）。
  Future<(MailBody, List<String>)> fetchBody(String uid) async {
    final cleanUid = uid.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanUid.isEmpty) {
      throw const MailProtocolException('UID 非数字，已拒绝');
    }
    try {
      await _loginAndIdentify();
      await _cmd('SELECT "INBOX"');
      final lines = await _cmd('UID FETCH $cleanUid (UID BODY.PEEK[])',
          continueOn: {'NO', 'BAD'});
      for (final l in lines) {
        if (!l.text.contains('FETCH') || l.literals.isEmpty) continue;
        final raw = utf8.decode(l.literals.first, allowMalformed: true);
        final node = parseMessage(raw);
        final (h, _) = splitHeadersAndBody(raw);
        final body = MailBody(
          uid: cleanUid,
          subject: decodeEncodedWords(h['subject'] ?? ''),
          from: decodeEncodedWords(h['from'] ?? ''),
          to: decodeEncodedWords(h['to'] ?? ''),
          date: decodeEncodedWords(h['date'] ?? ''),
          text: extractPlainText(node),
          messageId: (h['message-id'] ?? '').trim(),
        );
        return (body, attachmentNames(node));
      }
      throw MailProtocolException('UID $cleanUid 未取到正文');
    } finally {
      await logout();
    }
  }

  Future<void> logout() async {
    final t = _t;
    _t = null;
    if (t == null) return;
    try {
      t.write('${_tag()} LOGOUT\r\n');
    } catch (_) {
      // 已断开：无需再发
    }
    await t.close();
  }

  static int? _uidOf(String line) {
    final m = RegExp(r'(?:^|[\s(])UID (\d+)').firstMatch(line);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// IMAP 引用串转义（`\` 与 `"` 必须转义，否则密码里一个引号就能注入命令）。
  ///
  /// ★★ 0.90.0（专家 #6）：**CR/LF 必须先剔除**。IMAP 的引用串**不允许**裸换行，
  ///   而在此之前这里只转了 `\` 与 `"` —— 一个含 `\r\n` 的口令即可提前结束
  ///   `LOGIN` 行、把后半段当成**下一条命令**执行（帧注入）。口令来自用户输入，
  ///   属不可信数据，必须在此收口（与 `hasHeaderInjection` 同一纪律）。
  static String _q(String s) {
    final clean = s.replaceAll(RegExp(r'[\r\n]'), '');
    final esc = clean.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$esc"';
  }
}
