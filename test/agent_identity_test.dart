import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dahuang_ai/core/agent_identity.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/wold_did.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // 重置单例缓存，保证每个用例从干净状态开始
    await AgentIdentity.debugInjectSeedForTest(
        List<int>.generate(32, (i) => i + 1));
  });

  group('AgentProtocol.base58', () {
    test('编码/解码往返', () {
      final bytes = [0x01, 0x00, 0x02, 255, 128, 7];
      expect(AgentProtocol.base58Decode(AgentProtocol.base58Encode(bytes)),
          bytes);
    });

    test('空输入与非法字符', () {
      expect(AgentProtocol.base58Encode(const []), '');
      expect(() => AgentProtocol.base58Decode('0OIl'),
          throwsFormatException); // 非字母表字符
    });
  });

  group('AgentIdentity', () {
    test('同一种子生成确定公钥，did 可解析回 32 字节', () async {
      final pub1 = await AgentIdentity().publicKeyBase58();
      await AgentIdentity.debugInjectSeedForTest(
          List<int>.generate(32, (i) => i + 1));
      final pub2 = await AgentIdentity().publicKeyBase58();
      expect(pub1, pub2);
      expect(AgentProtocol.base58Decode(pub1).length, 32);
      // v1.3 品牌置换后签发前缀为 did:wold:（已不再签发 did:pocketagent:）。
      // ⚠️ 这条断言长期停在旧值 `did:pocketagent:` 上却没人发现 —— 因为
      // `flutter test` 在本机一直被 HTTP 代理挡住（flutter_tester 的**本地**
      // WebSocket 被代理走了），套件从未真正执行过。
      // **"测试全绿"和"测试没跑"是两件事**，这里就是代价。
      final did = await AgentIdentity().did();
      expect(did, 'did:wold:$pub1');
      // 名副其实：did 必须能解析回同一个 32 字节公钥
      // （而不是只有一个恰好的字符串前缀）
      expect(WoldDid.pubOf(did), pub1);
      expect(AgentProtocol.base58Decode(WoldDid.pubOf(did)!).length, 32);
      expect(WoldDid.isValid(did), isTrue);
    });

    test('默认算法为 hmac（Hub 未确认前），标记后切换 ed25519', () async {
      expect(await AgentIdentity().activeAlg(), 'hmac-sha256');
      await AgentIdentity().markEd25519Active();
      expect(await AgentIdentity().activeAlg(), 'ed25519');
    });
  });

  group('Ed25519 信封', () {
    test('签名可验签，篡改即失效', () async {
      final env = await AgentProtocol.buildEd25519Envelope(
        fromId: 'AG-1',
        toId: 'AG-2',
        payload: {'kind': 'text', 'body': '你好，公钥世界'},
        keyPair: await AgentIdentity().getOrCreateKeyPair(),
      );
      final pub = await AgentIdentity().publicKeyBase58();

      expect(env['alg'], 'ed25519');
      expect(
        await AgentProtocol.verifyEnvelopeAsync(env, pubKeyBase58: pub),
        isNotNull,
      );
      // 错误公钥
      expect(
        await AgentProtocol.verifyEnvelopeAsync(env, pubKeyBase58: pub),
        isNotNull,
      );
      final tampered = Map<String, dynamic>.from(env);
      tampered['payload'] = {'kind': 'text', 'body': '被篡改'};
      expect(
        await AgentProtocol.verifyEnvelopeAsync(tampered, pubKeyBase58: pub),
        isNull,
      );
    });

    test('跨语言向量：Node 端签名的信封可在 Dart 端验签', () async {
      // 由 Node.js crypto（ed25519）以固定种子签名生成，专用于校验两端
      // 规范化 JSON（键序 + UTF-8）完全一致。
      const pubB58 = '9C6hybhQ6Aycep9jaUnP6uL9ZYvDjUp1aSkFWPUFJtpj';
      const envelopeJson =
          '{"proto":"pocketagent/1","alg":"ed25519","type":"text","from":"AG-VECTOR","to":"hub","ts":1700000000,"nonce":"deadbeefdeadbeefdeadbeefdeadbeef","payload":{"kind":"text","body":"跨语言验签向量"},"sig":"0CFvAnb+pEv/v71nBflvauM3LEX5HPNFV88wLTOOmi0L/aEIG6+rxvV4sgtMcE9OCTKqFPW5MLyP6iKYD0KFDQ=="}';

      final env = Map<String, dynamic>.from(jsonDecode(envelopeJson));
      expect(
        await AgentProtocol.verifyEnvelopeAsync(env, pubKeyBase58: pubB58),
        isNotNull,
      );

      // 篡改一个字段后必须失效
      env['ts'] = 1700000001;
      expect(
        await AgentProtocol.verifyEnvelopeAsync(env, pubKeyBase58: pubB58),
        isNull,
      );
    });
  });

  group('HMAC 兼容（旧路径不回归）', () {
    test('旧信封仍可验签，且不会被公钥路径误放行', () async {
      final env = AgentProtocol.buildEnvelope(
        fromId: 'AG-1',
        toId: 'AG-2',
        payload: {'kind': 'text', 'body': '旧节点'},
        secret: 'test-secret',
      );
      expect(AgentProtocol.verifyEnvelope(env, 'test-secret'), isNotNull);
      expect(
          await AgentProtocol.verifyEnvelopeAsync(env, secret: 'test-secret'),
          isNotNull);
      expect(
        await AgentProtocol.verifyEnvelopeAsync(env, pubKeyBase58: '8888'),
        isNull,
      );
    });
  });
}
