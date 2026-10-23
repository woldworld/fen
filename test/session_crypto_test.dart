import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dahuang_ai/core/agent_identity.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/session_crypto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  /// 用独立密钥伪造一台"对端设备"的 HELLO（冒充/中间人测试用）
  ///
  /// 必须产出**格式合法**的 HELLO（含 `xpub`、签名覆盖 `HELLO|<agentId>|<pub>|<xpub>`）——
  /// 否则会在"缺字段"一步被拒，测不到后面的 TOFU 换绑判定。
  Future<String> forgedHello(String agentId, SimpleKeyPair impostor) async {
    final x = await X25519().newKeyPair();
    final xPub = AgentProtocol.base58Encode((await x.extractPublicKey()).bytes);
    final pubBytes = (await impostor.extractPublicKey()).bytes;
    final pub = AgentProtocol.base58Encode(pubBytes);
    final sig = await Ed25519().sign(
      utf8.encode('HELLO|$agentId|$pub|$xPub'),
      keyPair: impostor,
    );
    return jsonEncode({
      'type': 'HELLO',
      'did': 'did:wold:$pub',
      'pub': pub,
      'xpub': xPub,
      'sig': base64Encode(sig.bytes),
    });
  }

  group('SessionCrypto 握手（Ed25519 身份层）', () {
    test('双方握手后派生会话密钥，加解密往返', () async {
      final a = SessionCrypto.createIsolated();
      final b = SessionCrypto.createIsolated();

      final helloA = await a.buildHello('AG-A');
      final helloB = await b.buildHello('AG-B');

      expect(await a.handleHello('AG-B', helloB), isTrue);
      expect(await b.handleHello('AG-A', helloA), isTrue);
      expect(a.hasSession('AG-B'), isTrue);
      expect(b.hasSession('AG-A'), isTrue);

      final sealed = a.encryptFor('AG-B', jsonEncode({'message': '近场你好'}));
      expect(b.decryptFrom('AG-A', sealed), jsonEncode({'message': '近场你好'}));

      // 反向同样可用
      final sealed2 = b.encryptFor('AG-A', 'pong');
      expect(a.decryptFrom('AG-B', sealed2), 'pong');

      // 指纹：8 位十六进制
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(a.identityFingerprint('AG-B')),
          isTrue);
    });

    test('被篡改的 HELLO（签名失效）被拒', () async {
      final a = SessionCrypto.createIsolated();
      final b = SessionCrypto.createIsolated();
      await a.buildHello('AG-A');
      final helloB = await b.buildHello('AG-B');

      // 把 xpub 换成另一对密钥的公钥：字段本身合法（32 字节 base58），
      // 但签名覆盖的规范串变了 → 验签必须失败（防中间人替换密钥）
      final other = await X25519().newKeyPair();
      final otherPub =
          AgentProtocol.base58Encode((await other.extractPublicKey()).bytes);
      final data = Map<String, dynamic>.from(jsonDecode(helloB));
      data['xpub'] = otherPub;
      expect(await a.handleHello('AG-B', jsonEncode(data)), isFalse);
    });

    test('TOFU 钉扎：同一 agentId 换绑不同公钥（MITM）被拒', () async {
      final a = SessionCrypto.createIsolated();
      final b = SessionCrypto.createIsolated();
      await a.buildHello('AG-A');
      await b.buildHello('AG-B');

      final helloB = await b.buildHello('AG-B');
      expect(await a.handleHello('AG-B', helloB), isTrue); // 首次：绑定

      // 冒充者持自己的密钥，伪装成 AG-B 再握手
      final impostor = await Ed25519().newKeyPair();
      final forged = await forgedHello('AG-B', impostor);
      expect(await a.handleHello('AG-B', forged), isFalse);
      // 会话不受影响
      expect(a.hasSession('AG-B'), isTrue);
    });

    test('did 与公钥不一致的 HELLO 被拒', () async {
      final a = SessionCrypto.createIsolated();
      final impostor = await Ed25519().newKeyPair();
      final hello = await forgedHello('AG-X', impostor);
      final data = Map<String, dynamic>.from(jsonDecode(hello));
      data['did'] = 'did:pocketagent:DIFFERENT';
      await a.buildHello('AG-A');
      expect(await a.handleHello('AG-X', jsonEncode(data)), isFalse);
    });

    test('指纹比对：对方钉扎的我的指纹 == 我机显示的本机指纹', () async {
      final a = SessionCrypto.createIsolated();
      final b = SessionCrypto.createIsolated();
      final helloA = await a.buildHello('AG-A');
      final helloB = await b.buildHello('AG-B');
      expect(await a.handleHello('AG-B', helloB), isTrue);
      expect(await b.handleHello('AG-A', helloA), isTrue);

      // 人工比对协议的根基：我在对方手机上被钉扎的指纹 == 我手机上显示的本机指纹
      expect(await a.myIdentityFingerprint(), b.identityFingerprint('AG-A'));
      expect(await b.myIdentityFingerprint(), a.identityFingerprint('AG-B'));

      expect(a.hasIdentityPin('AG-B'), isTrue);
      expect(a.hasIdentityPin('AG-X'), isFalse);
      expect(a.pinnedPubKey('AG-B'), isNotNull);
      expect(a.pinnedPubKey('AG-X'), isNull);
    });

    test('身份攻击标记：TOFU 换绑拒绝后可消费一次', () async {
      final a = SessionCrypto.createIsolated();
      final b = SessionCrypto.createIsolated();
      await a.buildHello('AG-A');
      final helloB = await b.buildHello('AG-B');
      expect(await a.handleHello('AG-B', helloB), isTrue);

      final impostor = await Ed25519().newKeyPair();
      final forged = await forgedHello('AG-B', impostor);
      expect(await a.handleHello('AG-B', forged), isFalse);
      // 攻击标记一次性消费（供 P2P/LAN 通道记信誉事件）
      expect(a.consumeIdentityAttack('AG-B'), isTrue);
      expect(a.consumeIdentityAttack('AG-B'), isFalse);
    });

    test('换 agentId 重放 HELLO 被拒（防截获重放冒名）', () async {
      final a = SessionCrypto.createIsolated();
      final b = SessionCrypto.createIsolated();
      await a.buildHello('AG-A');
      final helloB = await b.buildHello('AG-B'); // 签名覆盖 HELLO|AG-B|pub|xpub

      // 原样重放、但声称来自 AG-X：签名对不上 HELLO|AG-X|pub|xpub → 拒绝
      expect(await a.handleHello('AG-X', helloB), isFalse);
      // 以其真实身份则通过（证明拒绝的原因正是 agentId 绑定）
      expect(await a.handleHello('AG-B', helloB), isTrue);
    });

    test('旧版 HELLO（无身份/xpub 字段）被拒（fail-closed，无兼容分支）', () async {
      final a = SessionCrypto.createIsolated();
      final b = SessionCrypto.createIsolated();
      await a.buildHello('AG-A');
      final helloB = await b.buildHello('AG-B');

      // 旧格式（只有一段对称加密的 key，无身份、无 xpub）——新协议一律拒绝
      final data = Map<String, dynamic>.from(jsonDecode(helloB));
      final legacy = jsonEncode({'type': 'HELLO', 'key': data['xpub']});
      expect(await a.handleHello('AG-B', legacy), isFalse);

      // 身份字段齐全但缺 xpub 同样拒绝（无静态密钥兜底）
      final noX = Map<String, dynamic>.from(jsonDecode(helloB))..remove('xpub');
      expect(await a.handleHello('AG-B', jsonEncode(noX)), isFalse);
    });

    test('钉扎持久化：warmUp 后换绑仍被拒', () async {
      final a = SessionCrypto.createIsolated();
      final b = SessionCrypto.createIsolated();
      await a.buildHello('AG-A');
      final helloB = await b.buildHello('AG-B');
      expect(await a.handleHello('AG-B', helloB), isTrue);
      // _persistPin 异步落库，等它完成
      await Future.delayed(const Duration(milliseconds: 50));

      // 新实例模拟重启后，从 prefs 恢复钉扎
      final a2 = SessionCrypto.createIsolated();
      await a2.warmUp();
      final impostor = await Ed25519().newKeyPair();
      final forged = await forgedHello('AG-B', impostor);
      expect(await a2.handleHello('AG-B', forged), isFalse);
    });
  });

  group('AgentIdentity 裸签名', () {
    test('signBase64 可被 verifyRawSignature 验证', () async {
      final identity = AgentIdentity();
      final sig = await identity.signBase64(utf8.encode('HELLO|test'));
      final pub = await identity.publicKeyBase58();
      expect(
        await AgentProtocol.verifyRawSignature(utf8.encode('HELLO|test'), sig, pub),
        isTrue,
      );
      expect(
        await AgentProtocol.verifyRawSignature(utf8.encode('HELLO|other'), sig, pub),
        isFalse,
      );
    });
  });
}
