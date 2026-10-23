import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/pii_detector.dart';

/// PiiDetector 检测与全面脱敏（免审通道的兜底线，必须钉住）
void main() {
  group('detect 检测', () {
    test('手机号/邮箱/身份证/银行卡/微信号命中', () {
      expect(PiiDetector.detect('电话 13812345678'), isNotNull);
      expect(PiiDetector.detect('邮箱 someone@example.com'), isNotNull);
      expect(PiiDetector.detect('身份证 110101199003074258'), isNotNull);
      expect(PiiDetector.detect('卡号 6222020200112233445'), isNotNull);
      expect(PiiDetector.detect('加我微信 wechat_id_123'), isNotNull);
      expect(PiiDetector.detect('vx：abc12345'), isNotNull);
    });

    test('正常内容不误伤', () {
      expect(PiiDetector.detect('今天天气不错，一起散步吗'), isNull);
      expect(PiiDetector.detect('订单号是 20260902'), isNull);
    });

    // ★ 2026-10-07 外交自由聊天"审核误杀"治理：裸 6 位数字不再当邮编拦掉。
    //   修复前 `(?<!\d)[1-9]\d{5}(?!\d)` 会把价格/数量/编号全判成隐私。
    test('裸 6 位数字不再误判为邮编（误杀治理）', () {
      expect(PiiDetector.detect('报价 999999 元'), isNull);
      expect(PiiDetector.detect('数量 123456 件'), isNull);
      expect(PiiDetector.detect('编号 300200 已发出'), isNull);
      expect(PiiDetector.detect('这次活动来了 100000 人'), isNull);
    });

    test('带标签的邮编仍然命中（不放松真检测）', () {
      expect(PiiDetector.detect('邮编 100080'), isNotNull);
      expect(PiiDetector.detect('邮政编码：010000'), isNotNull);
      expect(PiiDetector.detect('postal code 200000'), isNotNull);
    });
  });

  group('maskSensitive 全面脱敏', () {
    test('手机号保留前 3 后 4', () {
      final out = PiiDetector.maskSensitive('电话13812345678收到');
      expect(out, contains('138****5678'));
      expect(out, isNot(contains('13812345678')));
    });

    test('邮箱保留首字符与域名', () {
      final out = PiiDetector.maskSensitive('发到 someone@example.com 谢谢');
      expect(out, contains('s***@example.com'));
      expect(out, isNot(contains('someone@')));
    });

    test('身份证只留前 3 后 4', () {
      final out = PiiDetector.maskSensitive('证件 110101199003074258');
      expect(out, contains('110***********4258'));
      expect(out, isNot(contains('19900307')));
    });

    test('银行卡只留后 4', () {
      final out = PiiDetector.maskSensitive('卡号 6222020200112233445');
      expect(out, contains('****3445'));
      expect(out, isNot(contains('6222020200112233445')));
    });

    test('微信号打码', () {
      final out = PiiDetector.maskSensitive('加微信 wechat_id_123');
      expect(out, isNot(contains('wechat_id_123')));
      expect(out, contains('***'));
    });

    test('普通文本原样返回', () {
      const text = '今天下午三点开会，记得带笔记本。';
      expect(PiiDetector.maskSensitive(text), text);
    });
  });
}
