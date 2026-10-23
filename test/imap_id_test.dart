import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/mail/imap_client.dart';
import 'package:dahuang_ai/core/mail/mail_transport.dart';

/// IMAP 登录后**按需**发 `ID`（RFC 2971）的离线行为测试（0.66.0）。
///
/// 为什么两个方向都必须钉：
/// * **该发不发**：网易邮箱（163 / 126 / yeah.net）在 `LOGIN` 之后不发 `ID`，
///   后续 `SELECT` 一律回 `NO [UNAVAILABLE] Unsafe Login. Please contact
///   kefu@188.com` —— 真机表象是"账号看着连上了、一读信就被踢"，
///   从报错很难看回原因，授权码填得再对也没用。
/// * **不该发却发**：有的服务端对**它不认识的命令**会回一条**不带 tag** 的
///   `* BAD Command!`（协议违规），而 `readUntilTagged` 会一直等带 tag 的完成行
///   ⇒ **挂到超时**。所以对"没广告 ID"的服务端必须一个多余命令都不发。
///
/// 本测试**不碰网络**：用 [MailTransport.fromStream] 喂脚本化字节流
/// （`imap_client.dart` 的头注释即声明本类"可离线驱动"），
/// 并把出站字节收进一个 list 供断言。
Future<String> _outgoingFor(String script) async {
  final out = <int>[];
  final ctrl = StreamController<List<int>>();
  // ★ 顺序要紧：**先让 `fromStream` 订阅，再 add/close**。
  //   非广播 StreamController 的 `close()` 返回的 future 要等 done 事件**被送达**
  //   才完成；没有订阅者时 `await ctrl.close()` 会永远挂着（上一版就卡在这里，
  //   表现为 30s 测试超时 —— 与"协议挂死"长得一样，极易误判成被测代码的锅）。
  final t = MailTransport.fromStream(ctrl.stream, outgoing: out.addAll);
  ctrl.add(utf8.encode(script));
  unawaited(ctrl.close());
  final c = ImapClient(
    host: 'imap.example.com',
    port: 993,
    user: 'u@example.com',
    password: 'secret',
    connector: (h, p) async => t,
  );
  await c.testConnection();
  return utf8.decode(out);
}

void main() {
  group('advertisesId：必须按 CAPABILITY 的 token 比对', () {
    test('广告 ID ⇒ true', () {
      expect(
        ImapClient.advertisesId([
          MailLine(
              '* CAPABILITY IMAP4rev1 XLIST SPECIAL-USE ID LITERAL+ UIDPLUS',
              <List<int>>[]),
        ]),
        isTrue,
      );
    });

    test('★ 只有 UIDPLUS / XAPPLEPUSHSERVICE 而无 ID ⇒ false（contains 会假绿）', () {
      expect(
        ImapClient.advertisesId([
          MailLine(
              '* CAPABILITY IMAP4rev1 UIDPLUS XAPPLEPUSHSERVICE STARTTLS',
              <List<int>>[]),
        ]),
        isFalse,
      );
    });

    test('没有 CAPABILITY 响应行 / 空响应 ⇒ false', () {
      expect(
        ImapClient.advertisesId(
            [MailLine('a1 OK LOGIN completed', <List<int>>[])]),
        isFalse,
      );
      expect(ImapClient.advertisesId(const []), isFalse);
    });
  });

  group('登录后的真实出站字节', () {
    test('服务端广告 ID（网易形态）⇒ 登录后必须发出 ID', () async {
      final sent = await _outgoingFor(
        '* OK IMAP4rev1 ready\r\n'
        'a1 OK LOGIN completed\r\n'
        '* CAPABILITY IMAP4rev1 XLIST SPECIAL-USE ID LITERAL+ STARTTLS UIDPLUS\r\n'
        'a2 OK CAPABILITY completed\r\n'
        'a3 OK ID completed\r\n'
        '* 3 EXISTS\r\n'
        'a4 OK SELECT completed\r\n',
      );
      expect(sent,
          contains('a3 ID ("name" "Fen" "version" "1.0" "vendor" "Wold")'));
      expect(sent, contains('a4 SELECT "INBOX"'));
    });

    test('服务端不广告 ID ⇒ 绝不发 ID，流程照常走到 SELECT', () async {
      final sent = await _outgoingFor(
        '* OK IMAP4rev1 ready\r\n'
        'a1 OK LOGIN completed\r\n'
        '* CAPABILITY IMAP4rev1 UIDPLUS\r\n'
        'a2 OK CAPABILITY completed\r\n'
        '* 3 EXISTS\r\n'
        'a3 OK SELECT completed\r\n',
      );
      expect(sent, isNot(contains('ID (')));
      expect(sent, contains('a3 SELECT "INBOX"'));
    });

    test('ID 被拒（NO）⇒ 不阻断，仍能 SELECT（身份声明只是锦上添花）', () async {
      final sent = await _outgoingFor(
        '* OK IMAP4rev1 ready\r\n'
        'a1 OK LOGIN completed\r\n'
        '* CAPABILITY IMAP4rev1 ID\r\n'
        'a2 OK CAPABILITY completed\r\n'
        'a3 NO unsupported\r\n'
        '* 3 EXISTS\r\n'
        'a4 OK SELECT completed\r\n',
      );
      expect(sent, contains('a3 ID ('));
      expect(sent, contains('a4 SELECT "INBOX"'));
    });
  });
}
