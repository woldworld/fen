import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/trial_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrialClient.isQuotaExhaustedError（耗尽识别：宁可多识别不可吞一轮）', () {
    test('服务端 402 载荷特征命中', () {
      expect(
          TrialClient.isQuotaExhaustedError(
              'OpenAIException: {"error":"trial_quota_exhausted","used":20}'),
          isTrue);
    });

    test('裸状态码 402 命中（openai_dart 的异常文案形态）', () {
      expect(TrialClient.isQuotaExhaustedError('Error: Status 402 (billing)'), isTrue);
    });

    test('不误伤：401/429/普通网络错误不算耗尽', () {
      expect(TrialClient.isQuotaExhaustedError('Status 401 unauthorized'), isFalse);
      expect(TrialClient.isQuotaExhaustedError('Status 429 rate_limited'), isFalse);
      expect(TrialClient.isQuotaExhaustedError('SocketException: 网络不可达'), isFalse);
      expect(TrialClient.isQuotaExhaustedError(''), isFalse);
    });

    test('不误伤：1202/1402 这类含 402 子串的数字不算耗尽', () {
      // \b 词边界：1402、1202 不得命中
      expect(TrialClient.isQuotaExhaustedError('Status 1402 weird'), isFalse);
    });
  });

  group('TrialClient.classifyTrialError（服务端 8 类码逐一归类；0.57.0）', () {
    test('错误码串路径：每个服务端错误码都归到预设类别', () {
      expect(
          TrialClient.classifyTrialError(
              '{"error":"trial_quota_exhausted","used":20}'),
          TrialFailure.quotaExhausted);
      expect(TrialClient.classifyTrialError('{"error":"trial_not_configured"}'),
          TrialFailure.notConfigured);
      expect(
          TrialClient.classifyTrialError(
              '{"error":"input_type_unsupported","modality":"vision"}'),
          TrialFailure.inputUnsupported);
      expect(TrialClient.classifyTrialError('{"error":"rate_limited"}'),
          TrialFailure.rateLimited);
      expect(TrialClient.classifyTrialError('{"error":"trial_ip_rate_limited"}'),
          TrialFailure.rateLimited);
      expect(
          TrialClient.classifyTrialError('{"error":"trial_ip_daily_limited"}'),
          TrialFailure.rateLimited);
      expect(
          TrialClient.classifyTrialError(
              '{"error":"trial_uppool_exhausted","detail":"x"}'),
          TrialFailure.poolBusy);
      expect(TrialClient.classifyTrialError('{"error":"trial_agent_required"}'),
          TrialFailure.identityRejected);
      expect(
          TrialClient.classifyTrialError(
              '{"error":"prompt_too_large","limit":8000}'),
          TrialFailure.promptTooLarge);
      expect(TrialClient.classifyTrialError('{"error":"messages_required"}'),
          TrialFailure.badRequest);
    });

    test('裸状态码路径：异常文案里只剩 Status NNN 时也认得出', () {
      for (final e in TrialClient.statusToFailure.entries) {
        expect(
            TrialClient.classifyTrialError(
                'OpenAIException: Status ${e.key} (whatever)'),
            e.value,
            reason: 'Status ${e.key} 必须归到 ${e.value.name}');
      }
    });

    test('不误伤：认不出的返回 null（调用方按普通故障继续走）', () {
      expect(TrialClient.classifyTrialError(''), isNull);
      expect(TrialClient.classifyTrialError('SocketException: 网络不可达'), isNull);
      expect(TrialClient.classifyTrialError('Status 1402 weird'), isNull);
      expect(TrialClient.classifyTrialError('Status 1202 weird'), isNull);
      expect(TrialClient.classifyTrialError('FormatException: Unexpected character'),
          isNull);
    });

    test('★ 优先级：错误码串赢过裸状态码（串更精确）', () {
      // 文案里同时有 402 与"未配置"的串 ⇒ 必须按串归成 notConfigured，
      // 否则用户会被告知"额度用完了"，而真相是"官方池还没配"。
      expect(
          TrialClient.classifyTrialError('Status 402 ... trial_not_configured'),
          TrialFailure.notConfigured);
    });

    test('表自身完整：8 个状态码各归一类，无两类共用一条文案', () {
      expect(TrialClient.statusToFailure.length, 8);
      expect(TrialClient.errorCodeToFailure.length, greaterThanOrEqualTo(8));
      expect(TrialClient.statusToFailure.values.toSet().length, 8,
          reason: '8 个状态码必须映射到 8 个不同类别（否则两类故障共用一张卡）');
      // 每个类别都必须**至少**能从错误码串路径认出来（不能只有裸状态码一条路）
      expect(TrialClient.errorCodeToFailure.values.toSet(),
          TrialClient.statusToFailure.values.toSet());
    });
  });

  group('TrialClient.parseRemaining（余量解析：异常一律 null 而不是 0）', () {
    test('正常解析', () {
      expect(TrialClient.parseRemaining('{"used": 3, "limit": 20}'), 17);
      expect(TrialClient.parseRemaining('{"used": 20, "limit": 20}'), 0);
      expect(TrialClient.parseRemaining('{"used": 25, "limit": 20}'), 0,
          reason: '超用不显示负数');
    });

    test('坏输入返回 null（UI 显示"未知"而不是假装额度用完）', () {
      expect(TrialClient.parseRemaining('not-json'), isNull);
      expect(TrialClient.parseRemaining('{"foo": 1}'), isNull);
      expect(TrialClient.parseRemaining('{"used": "3", "limit": "20"}'), 17,
          reason: '字符串数字也算数（宽松解析，端点数据形态变化时 UI 不崩）');
    });
  });

  group('TrialClient 试用配置四件套（0.82.0：改 Key 自动切自有 + 端点纠正）', () {
    test('trialApiBase：带/不带尾斜杠都归一为 <hub>/api/trial', () {
      expect(TrialClient.trialApiBase('https://h.example.com'),
          'https://h.example.com/api/trial');
      expect(TrialClient.trialApiBase('https://h.example.com/'),
          'https://h.example.com/api/trial');
    });

    test('★ shouldSwitchToOwn：仅"试用中 + 新 Key 非空 + 与旧值不同"才切', () {
      // 命中：三条同时成立
      expect(
          TrialClient.shouldSwitchToOwn(
              currentMode: 'trial',
              previousKey: 'AG-abc123',
              newKey: 'sk-deepseek'),
          isTrue);
      // 非试用（本来就是自有）⇒ 与本次改动无关，不切
      expect(
          TrialClient.shouldSwitchToOwn(
              currentMode: 'own', previousKey: 'AG-abc', newKey: 'sk-x'),
          isFalse);
      expect(
          TrialClient.shouldSwitchToOwn(
              currentMode: null, previousKey: 'AG-abc', newKey: 'sk-x'),
          isFalse);
      // ★ 清空 ≠ 改 Key：一次误清空不许毁掉试用身份（事故的另一种形态）
      expect(
          TrialClient.shouldSwitchToOwn(
              currentMode: 'trial', previousKey: 'AG-abc', newKey: ''),
          isFalse);
      expect(
          TrialClient.shouldSwitchToOwn(
              currentMode: 'trial', previousKey: 'AG-abc', newKey: '   '),
          isFalse);
      // 没改（新旧相同）⇒ 不切；前后空白不算改动
      expect(
          TrialClient.shouldSwitchToOwn(
              currentMode: 'trial', previousKey: 'AG-abc', newKey: 'AG-abc'),
          isFalse);
      expect(
          TrialClient.shouldSwitchToOwn(
              currentMode: 'trial', previousKey: 'AG-abc', newKey: '  AG-abc  '),
          isFalse);
    });

    test('★ ownBaseUrlFix：仅当仍指向 /api/trial 才纠正（否则 null = 不动）', () {
      expect(TrialClient.ownBaseUrlFix('https://h.example.com/api/trial'),
          TrialClient.defaultOwnBaseUrl);
      // 已直连 ⇒ 不动（返回 null 表示"无需改动"）
      expect(TrialClient.ownBaseUrlFix('https://api.deepseek.com'), isNull);
      // 自定义 fallback 生效
      expect(
          TrialClient.ownBaseUrlFix('https://x/api/trial', fallback: 'https://y'),
          'https://y');
    });

    test('applyTrialConfig：四件套一次写齐（单一事实源）', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await TrialClient.applyTrialConfig(prefs,
          hubUrl: 'https://h.example.com', agentId: 'AG-xyz');
      expect(prefs.getString(TrialClient.modeKey), 'trial');
      expect(prefs.getString(TrialClient.baseUrlKey),
          'https://h.example.com/api/trial');
      expect(prefs.getString(TrialClient.apiKeyKey), 'AG-xyz');
      expect(prefs.getString(TrialClient.modelNameKey), 'trial');
    });

    test('applyTrialConfig：agentId 为空时回落 AG-TRIAL（不许写空 Key）', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await TrialClient.applyTrialConfig(prefs,
          hubUrl: 'https://h.example.com', agentId: '   ');
      expect(prefs.getString(TrialClient.apiKeyKey), 'AG-TRIAL');
    });
  });
}
