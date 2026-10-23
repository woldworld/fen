// 通知 + 短信（只读）桥接（0.75.0 W6/G9）验证。
//
// 只测**纯函数/纯数据**部分：平台通道（Android NotificationListenerService /
// Telephony provider）无法在单测里跑，由 tool/verify_notify_sms.dart 做结构级
// 断言、由真机做端到端验收。
//
// ★ 脱敏是重点：它同时承担"保护隐私"与"别把正常内容打码到没用"两个目标，
//   后者曾在本仓踩过坑（裸 6 位数字被当邮编全拦掉，2026-10-07 修）。
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/notification_sms_service.dart';

void main() {
  group('NotificationSmsService.redactSensitive', () {
    test('手机号打码（复用 PiiDetector）', () {
      final out = NotificationSmsService.redactSensitive('联系我 13812345678 谢谢');
      expect(out.contains('13812345678'), isFalse);
      expect(out.contains('138'), isTrue);
    });

    test('邮箱打码（保留首字符与域名）', () {
      final out =
          NotificationSmsService.redactSensitive('发给 zhangsan@example.com');
      expect(out.contains('zhangsan'), isFalse);
      expect(out.contains('@example.com'), isTrue);
    });

    test('验证码打码：带标签才判定', () {
      final out = NotificationSmsService.redactSensitive(
          '【某银行】您的验证码为 837462，请勿泄露');
      expect(out.contains('837462'), isFalse);
      expect(out.contains('****'), isTrue);
      // 标签本身要保留，否则模型读不懂上下文
      expect(out.contains('验证码'), isTrue);
    });

    test('英文标签的验证码同样打码', () {
      final out = NotificationSmsService.redactSensitive(
          'Your verification code is 5566');
      expect(out.contains('5566'), isFalse);
    });

    test('★ 裸数字**不**打码（防止把快递单号/金额/日期全误杀）', () {
      const raw = '你的快递单号 837462 已到驿站，取件码 445566';
      final out = NotificationSmsService.redactSensitive(raw);
      expect(out.contains('837462'), isTrue,
          reason: '无标签的 6 位数字必须原样保留（裸数字误杀是已修过的老坑）');
      expect(out.contains('445566'), isTrue);
    });

    test('身份证/银行卡打码', () {
      final out = NotificationSmsService.redactSensitive(
          '身份证 11010119900307123X 银行卡 6222021234567890123');
      expect(out.contains('11010119900307123X'), isFalse);
      expect(out.contains('6222021234567890123'), isFalse);
    });

    test('空串与无敏感内容原样返回', () {
      expect(NotificationSmsService.redactSensitive(''), '');
      expect(NotificationSmsService.redactSensitive('今天天气不错'), '今天天气不错');
    });
  });

  group('NotifyItem.fromMap', () {
    test('完整字段解析', () {
      final n = NotifyItem.fromMap({
        'packageName': 'com.tencent.mm',
        'appLabel': '微信',
        'title': '张三',
        'text': '在吗',
        'subText': '工作群',
        'category': 'msg',
        'postTime': 1700000000000,
        'ongoing': false,
      });
      expect(n.packageName, 'com.tencent.mm');
      expect(n.appLabel, '微信');
      expect(n.title, '张三');
      expect(n.text, '在吗');
      expect(n.subText, '工作群');
      expect(n.postTimeMs, 1700000000000);
      expect(n.ongoing, isFalse);
    });

    test('缺字段安全降级（不抛）', () {
      final n = NotifyItem.fromMap({});
      expect(n.packageName, '');
      expect(n.appLabel, '');
      expect(n.postTimeMs, 0);
      expect(n.ongoing, isFalse);
    });

    test('postTime 非 num 时归零', () {
      expect(NotifyItem.fromMap({'postTime': 'abc'}).postTimeMs, 0);
    });

    test('toLine 用 appLabel，缺失时退回包名', () {
      final a = NotifyItem.fromMap({
        'packageName': 'com.a.b',
        'appLabel': '某应用',
        'title': '标题',
        'text': '正文',
        'postTime': 1,
      });
      expect(a.toLine(time: '01-01 08:00'), contains('某应用'));
      final b = NotifyItem.fromMap({'packageName': 'com.a.b'});
      expect(b.toLine(time: '01-01 08:00'), contains('com.a.b'));
    });
  });

  group('SmsItem.fromMap / boxLabel', () {
    test('完整字段解析', () {
      final s = SmsItem.fromMap({
        'address': '10690000',
        'body': '验证码 1234',
        'dateMs': 1700000000000,
        'read': true,
        'type': 1,
      });
      expect(s.address, '10690000');
      expect(s.body, '验证码 1234');
      expect(s.dateMs, 1700000000000);
      expect(s.read, isTrue);
      expect(s.type, 1);
      expect(s.boxLabel, '收件箱');
    });

    test('缺字段安全降级（不抛）', () {
      final s = SmsItem.fromMap({});
      expect(s.address, '');
      expect(s.body, '');
      expect(s.dateMs, 0);
      expect(s.read, isFalse);
    });

    test('boxLabel 覆盖各 type', () {
      expect(SmsItem.fromMap({'type': 2}).boxLabel, '已发送');
      expect(SmsItem.fromMap({'type': 3}).boxLabel, '草稿');
      expect(SmsItem.fromMap({'type': 4}).boxLabel, '发件箱');
      expect(SmsItem.fromMap({'type': 5}).boxLabel, '发送失败');
      expect(SmsItem.fromMap({'type': 6}).boxLabel, '待发送');
      expect(SmsItem.fromMap({'type': 1, 'read': false}).boxLabel, '未读');
    });

    test('toLine 空白号码给可读占位', () {
      expect(SmsItem.fromMap({'body': 'hi'}).toLine(time: '01-01 08:00'),
          contains('(未知号码)'));
    });
  });

  group('NotifySmsStatus 就绪判定', () {
    test('通知"勾选≠可用"：未连上时不算就绪', () {
      const s = NotifySmsStatus(
        supported: true,
        listenerDeclared: true,
        listenerEnabled: true,
        listenerConnected: false,
        smsDeclared: true,
        smsGranted: false,
        message: '',
      );
      expect(s.notificationsReady, isFalse,
          reason: '系统设置里勾了但服务没连上 ⇒ 读不到通知，不能算就绪');
      expect(s.anyReady, isFalse);
    });

    test('通知连上 ⇒ 通知就绪', () {
      const s = NotifySmsStatus(
        supported: true,
        listenerDeclared: true,
        listenerEnabled: true,
        listenerConnected: true,
        smsDeclared: false,
        smsGranted: false,
        message: '',
      );
      expect(s.notificationsReady, isTrue);
      expect(s.smsReady, isFalse);
      expect(s.anyReady, isTrue);
    });

    test('只授权短信也算任一就绪', () {
      const s = NotifySmsStatus(
        supported: true,
        listenerDeclared: false,
        listenerEnabled: false,
        listenerConnected: false,
        smsDeclared: true,
        smsGranted: true,
        message: '',
      );
      expect(s.smsReady, isTrue);
      expect(s.anyReady, isTrue);
    });

    test('store 渠道（supported=false）三者皆不就绪', () {
      const s = NotifySmsStatus(
        supported: false,
        listenerDeclared: false,
        listenerEnabled: false,
        listenerConnected: false,
        smsDeclared: false,
        smsGranted: false,
        message: '',
      );
      expect(s.notificationsReady, isFalse);
      expect(s.smsReady, isFalse);
      expect(s.anyReady, isFalse);
    });
  });

  group('常量', () {
    test('单次读取上限收口（防止一次读回整机短信）', () {
      expect(NotificationSmsService.maxLimit, 100);
    });
    test('总开关键名固定（读键者与写键者必须一致）', () {
      expect(NotificationSmsService.notifySmsEnabledPref, 'notify_sms_enabled');
    });
  });
}
