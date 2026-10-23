import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agent_identity.dart';
import 'agent_protocol.dart';
import 'session_handshake.dart';

/// 每会话加密（替代全 App 共享固定密钥的"伪加密"）。
///
/// 握手（详见 `session_handshake.dart`）：
/// 1. 每端持有**一次性 X25519 密钥对**（本进程内，用完即弃）；
/// 2. HELLO 只携带**公钥**（Ed25519 身份公钥 + X25519 公钥）并用身份私钥签名——
///    明文传输（公钥非机密，签名只负责防篡改/防重放），**不再用任何静态密钥加密**；
/// 3. 双方各自 `HKDF(X25519(myPriv, peerXPub))` 得到同一把会话密钥；
/// 4. 之后所有业务消息使用 AES-256-GCM + 每消息随机 12 字节 nonce。
///
/// 身份层（Ed25519 + TOFU）：
/// - HELLO 里的公钥经签名验证，接收方先验签、再查 did 一致性，最后做 TOFU 固定；
/// - TOFU：同一 agentId 首次绑定后，换绑不同公钥即拒绝（防身份替换）；
/// - 绑定持久化在 SharedPreferences，重启不重置。
///
/// ⚠️ **不再是"过渡期"**：静态密钥（`pocketagent2026supersecretkey123`）与
/// `CryptoUtils` 已**彻底删除**；无身份旧客户端的 HELLO 兼容分支一并移除——
/// 无真实用户时一次换净，不留兼容包袱（fail-closed，见《交付记录》§16.3）。
class SessionCrypto {
  SessionCrypto._();

  static final SessionCrypto instance = SessionCrypto._();

  /// 测试专用：创建相互隔离的实例（正常代码请使用 instance）
  static SessionCrypto createIsolated() => SessionCrypto._();

  static const String _pinPrefix = 'identity_pin_';

  final Random _rng = Random.secure();

  /// 我方的**一次性 X25519 密钥对**（每次进程一对，懒生成、只生成一次）
  SimpleKeyPair? _myXKeyPair;
  String? _myXPubB58;

  String? _cachedHelloFor; // 缓存的 HELLO 绑定的 agentId
  String? _cachedHello;

  /// 各对端在本次会话里的 X25519 公钥
  final Map<String, SimplePublicKey> _peerXPub = {};
  final Map<String, Key> _sessionKeys = {};
  final Map<String, String> _pins = {};
  final Set<String> _attacks = {};

  /// TOFU 换绑攻击标记：handleHello 返回 false 后可查询并消费（一次性）。
  /// 调用方（P2P/LAN 通道）借此区分"普通握手失败"与"身份被替换"。
  bool consumeIdentityAttack(String agentId) => _attacks.remove(agentId);

  bool hasSession(String agentId) => _sessionKeys.containsKey(agentId);

  /// 启动时载入已固定的身份绑定（防重启后 TOFU 重置）
  Future<void> warmUp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith(_pinPrefix))) {
        final v = prefs.getString(k);
        if (v != null) _pins[k.substring(_pinPrefix.length)] = v;
      }
    } catch (_) {}
  }

  /// 懒生成我方一次性 X25519 密钥对（幂等：只生成一次，HELLO 与实际派生共用同一对）
  Future<SimpleKeyPair> _ensureMyEphemeral() async {
    final existing = _myXKeyPair;
    if (existing != null) return existing;
    final kp = await SessionHandshake.newEphemeralKeyPair();
    _myXKeyPair = kp;
    _myXPubB58 = await SessionHandshake.ephemeralPubBase58(kp);
    return kp;
  }

  /// 生成 HELLO 报文（一次性握手；含 Ed25519 身份公钥与自签 + X25519 公钥）。
  ///
  /// HELLO 为**明文**：它只带公钥，本非机密；签名覆盖 agentId
  /// （`HELLO|<agentId>|<edPub>|<xPub>`），否则报文被截获即可原样重放冒名。
  /// 机密性由后续 X25519 派生的会话密钥提供。
  Future<String> buildHello(String myAgentId) async {
    if (_cachedHello != null && _cachedHelloFor == myAgentId) {
      return _cachedHello!;
    }
    await _ensureMyEphemeral();
    final xPub = _myXPubB58!;
    final identity = AgentIdentity();
    final pub = await identity.publicKeyBase58();
    final did = await identity.did();
    final sig = await identity.signBase64(
        utf8.encode(SessionHandshake.canonicalHello(myAgentId, pub, xPub)));
    // 本地身份向量对（AgentIdentity._create）只生成一次，不会有"pub 变了 xPub 没变"的问题
    _cachedHelloFor = myAgentId;
    _cachedHello = jsonEncode({
      'type': 'HELLO',
      'did': did,
      'pub': pub,
      'xpub': xPub,
      'sig': sig,
    });
    return _cachedHello!;
  }

  /// 处理对方 HELLO；验签 + did 一致性 + TOFU 通过后，用 X25519 派生会话密钥。
  ///
  /// 返回是否已就绪。**缺任一字段即拒绝**（不再有"无身份旧客户端"兼容分支）。
  Future<bool> handleHello(String agentId, String helloJson) async {
    try {
      final data = jsonDecode(helloJson) as Map<String, dynamic>;
      if (data['type'] != 'HELLO') return false;

      final pub = data['pub'] as String?;
      final did = data['did'] as String?;
      final sig = data['sig'] as String?;
      final xPubB58 = data['xpub'] as String?;
      if (pub == null || did == null || sig == null || xPubB58 == null) {
        return false;
      }

      // v1.2 改名：接受 did:wold:（新）与 did:pocketagent:（过渡期旧客户端）
      final didOk = did == 'did:wold:$pub' || did == 'did:pocketagent:$pub';
      if (!didOk) return false;

      // 身份 HELLO 必须绑定 agentId（防截获重放冒名）
      final ok = await AgentProtocol.verifyRawSignature(
          utf8.encode(SessionHandshake.canonicalHello(agentId, pub, xPubB58)),
          sig,
          pub);
      if (!ok) return false;
      if (!_pinIdentity(agentId, pub)) return false;

      final SimplePublicKey peerX;
      try {
        peerX = SessionHandshake.publicKeyFromBase58(xPubB58);
      } catch (_) {
        return false;
      }
      _peerXPub[agentId] = peerX;
      return await _deriveIfReady(agentId);
    } catch (_) {
      return false;
    }
  }

  /// TOFU 固定：首次见到该 agentId 的公钥时记录并持久化；此后换绑不同公钥即拒绝
  bool _pinIdentity(String agentId, String pub) {
    final known = _pins[agentId];
    if (known == null) {
      _pins[agentId] = pub;
      unawaited(_persistPin(agentId, pub));
      return true;
    }
    if (known != pub) {
      // 同一 agentId 出现了不同的（验签通过的）公钥——按身份攻击记录
      _attacks.add(agentId);
      return false;
    }
    return true;
  }

  Future<void> _persistPin(String agentId, String pub) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_pinPrefix$agentId', pub);
    } catch (_) {}
  }

  /// 身份指纹（8 位）：首次连接时供主人人工比对，防中间人
  String identityFingerprint(String agentId) {
    final pub = _pins[agentId];
    if (pub == null) return '--------';
    return crypto.sha256.convert(utf8.encode(pub)).toString().substring(0, 8);
  }

  /// 我方设备身份的指纹——对方手机上 identityFingerprint(我的ID) 应显示同样的值
  Future<String> myIdentityFingerprint() async {
    final pub = await AgentIdentity().publicKeyBase58();
    return crypto.sha256.convert(utf8.encode(pub)).toString().substring(0, 8);
  }

  /// 该 agentId 是否已有 TOFU 固定身份
  bool hasIdentityPin(String agentId) => _pins.containsKey(agentId);

  /// 已固定的公钥（base58）；未固定返回 null（UI 展示用，不含私钥）
  String? pinnedPubKey(String agentId) => _pins[agentId];

  /// 双方密钥材料齐备后派生会话密钥（X25519 + HKDF）
  Future<bool> _deriveIfReady(String agentId) async {
    final theirs = _peerXPub[agentId];
    if (theirs == null) return false;
    final mine = await _ensureMyEphemeral();
    final bytes = await SessionHandshake.deriveSessionKey(
      myKeyPair: mine,
      peerPublicKey: theirs,
    );
    _sessionKeys[agentId] = Key(Uint8List.fromList(bytes));
    return true;
  }

  /// 加密给指定 Agent 的消息，输出 base64(nonce(12) || ciphertext || tag)
  String encryptFor(String agentId, String plaintext) {
    final key = _sessionKeys[agentId];
    if (key == null) {
      throw StateError('no session established for $agentId');
    }
    final nonce = IV(Uint8List.fromList(_randomBytes(12)));
    final enc = Encrypter(AES(key, mode: AESMode.gcm)).encrypt(plaintext, iv: nonce);
    return base64Encode([...nonce.bytes, ...enc.bytes]);
  }

  /// 解密来自指定 Agent 的消息；失败返回 null（绝不回退明文）
  String? decryptFrom(String agentId, String payload) {
    try {
      final key = _sessionKeys[agentId];
      if (key == null) return null;
      final raw = base64Decode(payload);
      if (raw.length <= 12) return null;
      final nonce = IV(Uint8List.fromList(raw.sublist(0, 12)));
      final body = raw.sublist(12);
      return Encrypter(AES(key, mode: AESMode.gcm)).decrypt(Encrypted(body), iv: nonce);
    } catch (_) {
      return null;
    }
  }

  /// 会话指纹：供用户人工比对（防中间人）
  String sessionFingerprint(String agentId) {
    final key = _sessionKeys[agentId];
    if (key == null) return '--------';
    return crypto.sha256.convert(key.bytes).toString().substring(0, 8);
  }

  List<int> _randomBytes(int n) =>
      List<int>.generate(n, (_) => _rng.nextInt(256));
}
