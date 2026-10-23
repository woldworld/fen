import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/mail/mail_types.dart';
import 'package:dahuang_ai/core/mail/mime_codec.dart';
import 'package:dahuang_ai/core/mail/smtp_client.dart';

/// 邮箱工具（0.64.0）纯函数单测。
///
/// 这里只测**不碰平台**的部分（地址校验 / 头注入 / 主机判定 / MIME 解码 / 报文构造），
/// 也就是"邮件读错、发错"最常见的根因所在。
/// 协议会话（IMAP/SMTP 真跑）与源码级红线断言在 `tool/verify_mail_tools.dart`。
void main() {
  group('地址与注入校验', () {
    test('形状合理的地址通过', () {
      expect(isPlausibleEmail('a@b.com'), isTrue);
      expect(isPlausibleEmail('first.last+tag@gmail.com'), isTrue);
      expect(isPlausibleEmail('  a@b.co  '), isTrue, reason: '两侧空白应先裁剪');
    });

    test('可疑形状一律拒绝', () {
      for (final bad in const [
        '',
        'a@b',
        'a b@c.com',
        '@b.com',
        'a@.com',
        'a@@b.com',
        'a@b.com\nBcc: x@y.com',
        'a@b.com, c@d.com',
        '"a"@b.com',
        'a@b.com;',
      ]) {
        expect(isPlausibleEmail(bad), isFalse, reason: '应拒绝：$bad');
      }
    });

    test('头注入被单独识别（发信前的最后一道闸）', () {
      expect(hasHeaderInjection('hi\r\nBcc: x@y.com'), isTrue);
      expect(hasHeaderInjection('hi\nthere'), isTrue);
      expect(hasHeaderInjection('普通主题'), isFalse);
    });

    test('只连公网主机（内网/回环/元数据地址一律拒绝）', () {
      expect(isPublicHost('imap.gmail.com'), isTrue);
      expect(isPublicHost('8.8.8.8'), isTrue);
      for (final bad in const [
        'localhost',
        '127.0.0.1',
        '0.0.0.0',
        '10.1.2.3',
        '192.168.0.1',
        '172.20.0.1',
        '169.254.169.254',
        'mail.local',
      ]) {
        expect(isPublicHost(bad), isFalse, reason: '应拒绝：$bad');
      }
    });
  });

  group('MIME 头部解码（RFC 2047）', () {
    test('B 编码', () {
      expect(decodeEncodedWords('=?UTF-8?B?5L2g5aW9?='), '你好');
    });

    test('Q 编码（下划线 = 空格）', () {
      expect(decodeEncodedWords('=?UTF-8?Q?hello_=E4=BD=A0?='), 'hello 你');
    });

    test('无编码原样返回', () {
      expect(decodeEncodedWords('plain subject'), 'plain subject');
    });

    test('相邻编码字之间的空白必须丢弃（否则中文主题被塞空格）', () {
      expect(decodeEncodedWords('=?UTF-8?B?5L2g?= =?UTF-8?B?5aW9?='), '你好');
    });

    test('编码字与普通文本混排时保留普通文本', () {
      expect(decodeEncodedWords('Re: =?UTF-8?B?5L2g5aW9?= (fwd)'),
          'Re: 你好 (fwd)');
    });
  });

  group('传输编码', () {
    test('base64（含漏 padding 的容错）', () {
      expect(utf8.decode(decodeTransfer('5L2g5aW9', 'base64')), '你好');
      expect(utf8.decode(decodeTransfer('5L2g5aW9\n', 'base64')), '你好',
          reason: '换行应被忽略');
    });

    test('quoted-printable', () {
      expect(utf8.decode(decodeTransfer('a=3Db=0A', 'quoted-printable')), 'a=b\n');
      expect(utf8.decode(decodeTransfer('line=\r\nnext', 'quoted-printable')),
          'linenext',
          reason: '软换行要吃掉');
    });

    test('7bit / 未声明：原样', () {
      expect(utf8.decode(decodeTransfer('raw', '7bit')), 'raw');
      expect(utf8.decode(decodeTransfer('raw', '')), 'raw');
    });
  });

  group('multipart 与正文挑选', () {
    const alt = 'From: A <a@x.com>\r\n'
        'Subject: =?UTF-8?B?5L2g5aW9?=\r\n'
        'Content-Type: multipart/alternative; boundary="BND"\r\n'
        '\r\n'
        '--BND\r\n'
        'Content-Type: text/plain; charset=UTF-8\r\n'
        '\r\n'
        '纯文本正文\r\n'
        '--BND\r\n'
        'Content-Type: text/html; charset=UTF-8\r\n'
        '\r\n'
        '<p>HTML <b>正文</b></p>\r\n'
        '--BND--\r\n';

    test('拆出 part 并优先 text/plain', () {
      final node = parseMessage(alt);
      expect(node.isMultipart, isTrue);
      expect(node.children, hasLength(2));
      expect(extractPlainText(node), '纯文本正文');
    });

    test('中文正文不被 charset 往返毁掉（施工时踩过的真 bug）', () {
      final node = parseMessage(alt);
      final plain = node.children
          .firstWhere((c) => c.contentType == 'text/plain');
      expect(plain.decodedBody.contains('纯文本正文'), isTrue,
          reason: '7bit 文本不得再走一遍 codeUnits→utf8.decode');
    });

    test('text/plain 只有样板话时回落到 HTML', () {
      const boiler = 'Content-Type: multipart/alternative; boundary="B"\r\n'
          '\r\n'
          '--B\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n'
          'View this email in your browser\r\n'
          '--B\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n'
          '<p>真正的正文</p>\r\n'
          '--B--\r\n';
      expect(extractPlainText(parseMessage(boiler)).contains('真正的正文'), isTrue);
    });

    test('附件只报名字，不取内容', () {
      const mixed = 'Content-Type: multipart/mixed; boundary="M"\r\n\r\n'
          '--M\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nhi\r\n'
          '--M\r\nContent-Type: application/pdf; name="a.pdf"\r\n'
          'Content-Disposition: attachment; filename="=?UTF-8?B?5oql5ZGK?=.pdf"\r\n'
          '\r\n'
          'JVBERi0=\r\n--M--\r\n';
      final atts = attachmentNames(parseMessage(mixed));
      expect(atts, hasLength(1));
      expect(atts.first, contains('报告'));
    });
  });

  group('报文构造', () {
    final msg = buildRfc5322(
      from: 'me@gmail.com',
      to: ['you@example.com'],
      subject: '=?UTF-8?B?5L2g5aW9?=',
      body: '第一行\n第二行',
      now: DateTime(2026, 10, 8, 8, 30, 0),
    );

    test('必要头部齐备', () {
      expect(msg, contains('From: me@gmail.com\r\n'));
      expect(msg, contains('To: you@example.com\r\n'));
      expect(msg, contains('MIME-Version: 1.0\r\n'));
      expect(msg, contains('Content-Type: text/plain; charset=UTF-8\r\n'));
      expect(msg, contains('Content-Transfer-Encoding: base64\r\n'));
      expect(msg, contains('Message-ID: <'));
      expect(msg, contains('Date: Thu, 08 Oct 2026'));
    });

    test('正文走 base64：明文不出现、可无损还原、天然免疫 dot-stuffing', () {
      expect(msg.contains('第一行'), isFalse);
      final bodyPart = msg.split('\r\n\r\n').last.trim();
      expect(utf8.decode(base64.decode(bodyPart.replaceAll('\r\n', ''))),
          '第一行\n第二行');
      expect(RegExp(r'^\.$', multiLine: true).hasMatch(msg), isFalse);
    });

    test('头部编码：ASCII 不动，非 ASCII 走 RFC2047，长值折行不产生空行', () {
      expect(encodeHeaderValue('hello'), 'hello');
      expect(encodeHeaderValue('你好'), startsWith('=?UTF-8?B?'));
      expect(encodeHeaderValue('你好' * 40).contains('\n\n'), isFalse,
          reason: '空行会提前结束头部区 —— 那是封坏信');
    });

    test('日期格式符合 RFC 5322', () {
      expect(RegExp(r'^[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4} '
              r'\d{2}:\d{2}:\d{2} [+-]\d{4}$')
          .hasMatch(rfc5322Date(DateTime(2026, 10, 8, 8, 30, 0))), isTrue);
    });

    // ★ 0.90.0（专家 #8）：日期与时间必须取**同一套分量**。
    //   旧实现星期/日月年取 UTC、时分秒取本地 ⇒ 在 UTC+8 机器上把本地 07:30
    //   印成「前一天 + 07:30」（日期与 "+0800" 自相矛盾）。
    test('日期分量与时间分量自洽（跨零点不差一天，0.90.0）', () {
      const mo = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      // 取一个"本地日期 ≠ UTC 日期"的时刻（偏移 > 0 时用当天 23:30）
      final utcT = DateTime.utc(2026, 10, 8, 23, 30, 0);
      final l = utcT.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(
        rfc5322Date(utcT),
        contains('${two(l.day)} ${mo[l.month - 1]} ${l.year} '
            '${two(l.hour)}:${two(l.minute)}:${two(l.second)}'),
        reason: '日期部分必须取自本地分量，不能与 ±HHMM 偏移矛盾',
      );
    });

    // ★ 0.90.0（专家 #8）：中文主题此前**裸拼**进头部（违反 RFC 5322 只允许 ASCII）。
    test('主题走 RFC 2047：中文编码、ASCII 原样（0.90.0）', () {
      final cn = buildRfc5322(
        from: 'me@gmail.com',
        to: ['you@example.com'],
        subject: '会议纪要',
        body: 'x',
        now: DateTime(2026, 10, 8, 8, 30, 0),
      );
      expect(cn, contains('Subject: =?UTF-8?B?'));
      expect(cn.contains('Subject: 会议纪要'), isFalse);
      final ascii = buildRfc5322(
        from: 'a@b.com',
        to: ['c@d.com'],
        subject: 'Hello',
        body: 'x',
        now: DateTime(2026, 10, 8, 8, 30, 0),
      );
      expect(ascii, contains('Subject: Hello\r\n'));
    });
  });
}
