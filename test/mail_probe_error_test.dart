import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/mail/imap_client.dart';
import 'package:dahuang_ai/core/mail/mail_errors.dart';
import 'package:dahuang_ai/core/mail/mail_transport.dart';

/// 0.81.0：邮箱探测失败路径的两个不变量（163 真机反馈收口）。
///
/// ★★ 缘起（0.80.0 真机截图实证）：填错授权码时，错误横幅把**授权码明文**
/// 印在屏上 —— 根因是 `_cmd` 抛错时把整条 `LOGIN` 命令（含密码）塞进异常文案；
/// 且网易 163 的 `NO LOGIN Login error or password error` 不带
/// `AUTHENTICATIONFAILED`，旧分类认不出 ⇒ 用户看到原始报文而不是可照做的提示。
///
/// 本测试**不碰网络**：用 `MailTransport.fromStream` 喂脚本化字节流
/// （同 `imap_id_test.dart` 的离线驱动法）。
Future<String> _probeErrorFor(String script) async {
  final ctrl = StreamController<List<int>>();
  // ★ 顺序要紧：先让 `fromStream` 订阅，再 add/close（见 imap_id_test 的教训）。
  final t = MailTransport.fromStream(ctrl.stream, outgoing: (_) {});
  ctrl.add(utf8.encode(script));
  unawaited(ctrl.close());
  final c = ImapClient(
    host: 'imap.example.com',
    port: 993,
    user: 'u@example.com',
    password: 'secret',
    connector: (h, p) async => t,
  );
  try {
    await c.testConnection();
  } catch (e) {
    return '$e';
  }
  fail('服务端拒信时必须抛错，而不是"测试通过"');
}

void main() {
  group('异常文案绝不回显凭证（imap_client._cmd）', () {
    test('★ LOGIN 被拒（163 形态）⇒ 报错含服务端原因，但绝不含密码原文', () async {
      final msg = await _probeErrorFor(
        '* OK IMAP4rev1 ready\r\n'
        'a1 NO LOGIN Login error or password error\r\n',
      );
      expect(msg, contains('NO LOGIN Login error or password error'));
      expect(msg, isNot(contains('secret')));
      expect(msg, contains('****'));
    });

    test('★ 密码带引号/反斜杠（转义形态）也绝不回显', () async {
      final ctrl = StreamController<List<int>>();
      final t = MailTransport.fromStream(ctrl.stream, outgoing: (_) {});
      ctrl.add(utf8.encode(
        '* OK IMAP4rev1 ready\r\n'
        'a1 NO LOGIN Login error or password error\r\n',
      ));
      unawaited(ctrl.close());
      final c = ImapClient(
        host: 'imap.example.com',
        port: 993,
        user: 'u@example.com',
        // 原文里的形态是 `we"ird\\pw`（转义后），两种形态都必须被掩掉
        password: 'we"ird\\pw',
        connector: (h, p) async => t,
      );
      Object? caught;
      try {
        await c.testConnection();
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      final msg = '$caught';
      expect(msg, isNot(contains('we"ird')));
      expect(msg, isNot(contains('ird\\pw')));
      expect(msg, contains('****'));
    });

    test('正控：SELECT 被拒 ⇒ 报错仍带完整命令文本（不含凭证的命令不脱敏）', () async {
      final msg = await _probeErrorFor(
        '* OK IMAP4rev1 ready\r\n'
        'a1 OK LOGIN completed\r\n'
        '* CAPABILITY IMAP4rev1\r\n'
        'a2 OK CAPABILITY completed\r\n'
        'a3 NO SELECT denied\r\n',
      );
      expect(msg, contains('SELECT "INBOX"'));
      expect(msg, contains('SELECT denied'));
    });
  });

  group('classifyMailProbeError：按各家原文收口', () {
    test('★ 网易 163/126 形态（0.80.0 真机实证）⇒ auth', () {
      expect(
        classifyMailProbeError(
            'MailProtocolException: IMAP LOGIN "u" "****" 失败: '
            'a1 NO LOGIN Login error or password error'),
        'auth',
      );
    });

    test('Gmail/QQ 形态（AUTHENTICATIONFAILED）⇒ auth', () {
      expect(
        classifyMailProbeError(
            'a1 NO [AUTHENTICATIONFAILED] Invalid credentials'),
        'auth',
      );
    });

    test('SMTP 侧中文包装 ⇒ auth', () {
      expect(classifyMailProbeError('SMTP 认证失败（535）：auth fail'), 'auth');
    });

    test('网易 Unsafe Login（身份声明被拒）⇒ unsafeLogin', () {
      expect(
        classifyMailProbeError(
            'a2 NO [UNAVAILABLE] Unsafe Login. Please contact kefu@188.com'),
        'unsafeLogin',
      );
    });

    test('认不出 ⇒ null（调用方原样透出，不编造）', () {
      expect(classifyMailProbeError('a1 NO SELECT denied'), isNull);
      expect(classifyMailProbeError(''), isNull);
    });
  });
}
