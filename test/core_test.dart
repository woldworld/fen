import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/pii_detector.dart';
import 'package:dahuang_ai/core/social_budget.dart';

void main() {
  group('PiiDetector', () {
    test('识别手机号、邮箱、身份证等敏感信息', () {
      expect(PiiDetector.detect('我的电话是 13812345678'), isNotNull);
      expect(PiiDetector.detect('联系 foo@bar.com'), isNotNull);
      expect(PiiDetector.detect('身份证 11010119900307889X'), isNotNull);
      expect(PiiDetector.detect('今天天气不错，一起去散步吧'), isNull);
    });

    test('手机号脱敏', () {
      expect(PiiDetector.maskPhoneNumbers('13812345678'), '138****5678');
    });
  });

  group('AgentProtocol', () {
    test('信封可验签，且防篡改', () {
      final env = AgentProtocol.buildEnvelope(
        fromId: 'AG-1',
        toId: 'AG-2',
        payload: {'kind': 'text', 'body': '你好'},
        secret: 'test-secret',
      );
      expect(AgentProtocol.verifyEnvelope(env, 'test-secret'), isNotNull);
      expect(AgentProtocol.verifyEnvelope(env, 'wrong-secret'), isNull);
      env['payload'] = {'kind': 'text', 'body': '被篡改'};
      expect(AgentProtocol.verifyEnvelope(env, 'test-secret'), isNull);
    });
  });

  group('SocialBudget', () {
    test('限制主动行为频率', () {
      final budget = SocialBudget(perHourMax: 1, perDayMax: 100);
      expect(budget.allow(), isTrue);
      expect(budget.allow(), isFalse);
    });
  });
}
