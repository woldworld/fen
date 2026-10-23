/// 邮箱工具 · SMTP 提交（只做"发一封"）
///
/// 与 IMAP 对称：不引第三方库，`dart:io` 足够。
/// 端口约定（RFC 6409 —— 提交用 587/465，**绝不用 25**）：
/// - 465 隐式 TLS（连上即握手）
/// - 587 明文 + `STARTTLS`
library;

import 'dart:convert';
import 'dart:math';

import 'mail_transport.dart';
import 'mail_types.dart';
import 'mime_codec.dart';

/// 连接器签名（测试注入用）。
typedef SmtpConnector = Future<MailTransport> Function(
    String host, int port, bool implicitTls);

class SmtpClient {
  final String host;
  final int port;
  final String user;
  final String password;
  final bool implicitTls;
  final SmtpConnector _connect;
  final Duration timeout;

  MailTransport? _t;

  SmtpClient({
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.implicitTls,
    SmtpConnector? connector,
    this.timeout = const Duration(seconds: 30),
  }) : _connect = connector ??
            ((h, p, tls) => tls
                ? MailTransport.connectTls(h, p, connectTimeout: timeout)
                : MailTransport.connectPlain(h, p, connectTimeout: timeout));

  Future<void> _open() async {
    if (_t != null) return;
    final t = await _connect(host, port, implicitTls);
    _t = t;
    await _expect(t, '220', 'SMTP 问候');
    await _ehlo(t);
    if (!implicitTls) {
      t.write('STARTTLS\r\n');
      await _expect(t, '220', 'STARTTLS');
      // 升级后旧的 transport 作废（它已把 socket 交出去）
      _t = await t.upgradeToTls(host);
      await _ehlo(_t!);
    }
    await _auth(_t!);
  }

  Future<void> _ehlo(MailTransport t) async {
    t.write('EHLO fen.local\r\n');
    final first = await t.readLine();
    if (first == null) throw const MailConnectException('EHLO 无响应');
    final code = first.length >= 3 ? first.substring(0, 3) : '';
    if (code != '250') {
      throw MailProtocolException('EHLO 被拒：${first.trim()}');
    }
    // 多行响应：`250-` 继续，`250 ` 结束
    var line = first;
    while (line.length > 3 && line[3] == '-') {
      final next = await t.readLine();
      if (next == null) throw const MailConnectException('EHLO 响应中断');
      line = next;
    }
  }

  Future<void> _auth(MailTransport t) async {
    t.write('AUTH LOGIN\r\n');
    await _expect(t, '334', 'AUTH LOGIN');
    t.write('${base64.encode(utf8.encode(user))}\r\n');
    await _expect(t, '334', 'AUTH 用户名');
    t.write('${base64.encode(utf8.encode(password))}\r\n');
    final r = await t.readLine();
    if (r == null) throw const MailConnectException('AUTH 无响应');
    final code = r.length >= 3 ? r.substring(0, 3) : '';
    if (code != '235') {
      // 最常见的原因就是这里，所以把服务端原文带出去
      throw MailProtocolException('SMTP 认证失败（$code）：${r.trim()}');
    }
  }

  /// 发一封。返回服务端最终响应（已含 250）。
  Future<String> send({
    required String from,
    required List<String> to,
    required String subject,
    required String body,
    String? inReplyTo,
  }) async {
    if (to.isEmpty) throw const MailProtocolException('没有收件人');
    for (final a in to) {
      if (!isPlausibleEmail(a)) {
        throw MailProtocolException('收件人地址形状不合法，已拒绝：$a');
      }
    }
    if (hasHeaderInjection(subject) ||
        hasHeaderInjection(from) ||
        to.any(hasHeaderInjection)) {
      throw const MailProtocolException('头部含换行符，已拒绝（防头注入）');
    }
    if (!isPlausibleEmail(from)) {
      throw MailProtocolException('发件人地址形状不合法：$from');
    }

    try {
      await _open();
      final t = _t!;
      t.write('MAIL FROM:<$from>\r\n');
      await _expect(t, '250', 'MAIL FROM');
      for (final a in to) {
        t.write('RCPT TO:<$a>\r\n');
        await _expect(t, '250', 'RCPT TO $a');
      }
      t.write('DATA\r\n');
      await _expect(t, '354', 'DATA');

      final message = buildRfc5322(
        from: from,
        to: to,
        subject: subject,
        body: body,
        inReplyTo: inReplyTo,
      );
      t.write(message);
      t.write('\r\n.\r\n'); // 结束符（正文走 base64，不会出现行首单点）
      final done = await t.readLine();
      if (done == null) throw const MailConnectException('投递无响应');
      final code = done.length >= 3 ? done.substring(0, 3) : '';
      if (code != '250') {
        throw MailProtocolException('投递被拒（$code）：${done.trim()}');
      }
      return done.trim();
    } finally {
      await _quit();
    }
  }

  Future<void> _quit() async {
    final t = _t;
    _t = null;
    if (t == null) return;
    try {
      t.write('QUIT\r\n');
    } catch (_) {
      // 已断开
    }
    await t.close();
  }

  Future<void> _expect(MailTransport t, String code, String stage) async {
    final line = await t.readLine();
    if (line == null) throw MailConnectException('$stage 无响应');
    if (line.length < 3 || line.substring(0, 3) != code) {
      throw MailProtocolException('$stage 期望 $code，实收：${line.trim()}');
    }
  }
}

// ---------------------------------------------------------------------------
// 报文构造（**纯函数**，离线可测）
// ---------------------------------------------------------------------------

/// RFC 5322 日期（`Thu, 08 Oct 2026 08:31:43 +0800`）。
///
/// ★★ 0.90.0（专家 #8）：**日期、星期、时分秒必须取同一套分量**。
///   旧写法把星期/日月年取 `utc` 分量、时分秒取 `local` 分量 —— 在 UTC+8
///   的机器上，本地 07:30 对应 UTC 前一天 23:30，于是报头会印成
///   `Wed, 07 Oct 2026 07:30:00 +0800`（**日期与时间差一天**，且星期标签
///   指向错误的 UTC 那一天）。收件方按 "+0800" 解读时会得到错误时刻。
///   ⇒ 全部改按 `toLocal()` 分量 + 本地偏移，日期与时间自洽。
String rfc5322Date(DateTime t) {
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = t.toLocal();
  final offMin = local.timeZoneOffset.inMinutes;
  final sign = offMin < 0 ? '-' : '+';
  final abs = offMin.abs();
  final hh = (abs ~/ 60).toString().padLeft(2, '0');
  final mm = (abs % 60).toString().padLeft(2, '0');
  String two(int n) => n.toString().padLeft(2, '0');
  // 星期 / 日 / 月 / 年 / 时分秒 —— **全部**取自本地分量，与下面的 ±HHMM 自洽。
  return '${wd[local.weekday - 1]}, ${two(local.day)} ${mo[local.month - 1]} '
      '${local.year} ${two(local.hour)}:${two(local.minute)}:${two(local.second)} '
      '$sign$hh$mm';
}

/// 构造一封 `text/plain; charset=UTF-8` 的邮件（正文走 base64）。
///
/// 为什么正文用 base64：① 免去 dot-stuffing（行首 `.` 转义）这条经典坑；
/// ② 免去 998 字节行长限制；③ 免去 8bit 传输在各家 MTA 上的兼容问题。
String buildRfc5322({
  required String from,
  required List<String> to,
  required String subject,
  required String body,
  String? inReplyTo,
  String? messageId,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final domain = from.contains('@') ? from.split('@').last : 'fen.local';
  final mid = messageId ?? generateMessageId(domain, t);
  final b64 = base64.encode(utf8.encode(body));
  final wrapped = <String>[];
  for (var i = 0; i < b64.length; i += 76) {
    wrapped.add(b64.substring(i, (i + 76 > b64.length) ? b64.length : i + 76));
  }
  final buf = StringBuffer()
    ..write('From: $from\r\n')
    ..write('To: ${to.join(', ')}\r\n')
    // ★ 0.90.0（专家 #8）：主题走 RFC 2047 编码。此前直接拼原文 ——
    //   中文/emoji 主题会把**非 ASCII 字节**塞进头部，违反 RFC 5322
    //   （头部只允许 ASCII），部分 MTA 会改写或拒收。纯 ASCII 主题不受影响
    //   （encodeHeaderValue 原样返回），已是编码字（`=?UTF-8?B?…?=`）的主题
    //   也不会被二次编码。
    ..write('Subject: ${encodeHeaderValue(subject)}\r\n')
    ..write('Date: ${rfc5322Date(t)}\r\n')
    ..write('Message-ID: $mid\r\n');
  if (inReplyTo != null && inReplyTo.isNotEmpty) {
    buf.write('In-Reply-To: $inReplyTo\r\n');
    buf.write('References: $inReplyTo\r\n');
  }
  buf
    ..write('MIME-Version: 1.0\r\n')
    ..write('Content-Type: text/plain; charset=UTF-8\r\n')
    ..write('Content-Transfer-Encoding: base64\r\n')
    ..write('\r\n')
    ..write(wrapped.join('\r\n'));
  return buf.toString();
}

/// 生成 Message-ID（`<ts.rand@domain>`，纯 ASCII）。
String generateMessageId(String domain, DateTime t) {
  final r = Random();
  final rand = List.generate(16, (_) => r.nextInt(36).toRadixString(36)).join();
  return '<${t.millisecondsSinceEpoch}.$rand@$domain>';
}
