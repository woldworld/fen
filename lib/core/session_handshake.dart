import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'agent_protocol.dart';

/// 会话握手密钥协商（**X25519 ECDH + HKDF-SHA256**）。
///
/// 本文件**零平台依赖**（不碰 SharedPreferences / 插件通道），
/// 因此 `dart run tool/verify_session_crypto.dart` 可直接复算全部性质。
///
/// ## 为什么不再用"共享静态密钥加密握手材料"
///
/// 旧方案把 AES 密钥与 IV（`pocketagent2026supersecretkey123`）**硬编码进客户端**，
/// 等价于公开：任何拿到 App 的**被动窃听者**都能解出 HELLO 里的"会话材料"，
/// 从而由 `sha256(sorted(双方材料))` 推出**每会话密钥** —— 业务消息虽为 AES-GCM，
/// **对窃听者也不再保密**。
///
/// 关键区分：**验签 / TOFU 保证"对面确实是本人"（认证），但不保证"只有对面能看见"（机密性）**。
/// 这是两件事，签名不提供机密性，所以"验签 + TOFU"救不了这个洞。
///
/// ## 新方案
///
/// - HELLO 只携带**公钥**（Ed25519 身份公钥 + 一次性 X25519 公钥），用身份私钥**签名**——
///   公钥本非机密，只需防篡改 / 防重放，**无需加密**；
/// - 会话密钥 = `HKDF(X25519(myPriv, peerXPub))` —— **必须持有私钥才能算出**，
///   被动窃听者（只有两端的公钥）无法推出。
class SessionHandshake {
  SessionHandshake._();

  /// HKDF 的 info 域（两端必须一致；改动即协议不兼容）
  static const String hkdfInfo = 'wold/session/v1';

  /// X25519 公钥字节长度
  static const int xPubLength = 32;

  /// HELLO 签名覆盖的规范串（两端必须逐字节一致）。
  ///
  /// 覆盖 `agentId`：否则报文被截获即可**原样重放**，攻击者能顶替受害者建立会话。
  static String canonicalHello(
          String agentId, String edPubB58, String xPubB58) =>
      'HELLO|$agentId|$edPubB58|$xPubB58';

  /// 生成一次性 X25519 密钥对（每次会话一对，用完即弃）
  static Future<SimpleKeyPair> newEphemeralKeyPair() => X25519().newKeyPair();

  /// 取 X25519 公钥并编码为 base58
  static Future<String> ephemeralPubBase58(SimpleKeyPair kp) async {
    final pub = await kp.extractPublicKey();
    return AgentProtocol.base58Encode(pub.bytes);
  }

  /// base58 文本 → X25519 公钥对象（长度不符抛 [FormatException]）
  static SimplePublicKey publicKeyFromBase58(String b58) {
    final bytes = AgentProtocol.base58Decode(b58);
    if (bytes.length != xPubLength) {
      throw FormatException('x25519 pubkey must be $xPubLength bytes');
    }
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  /// 派生 32 字节会话密钥。
  ///
  /// salt ＝ 双方公钥字节按**字典序**拼接（两端各自算出同一 salt，故顺序必须确定），
  /// 把本次握手的两个公钥绑进派生过程（unknown-key-share 防御）。
  static Future<List<int>> deriveSessionKey({
    required SimpleKeyPair myKeyPair,
    required SimplePublicKey peerPublicKey,
  }) async {
    final shared = await X25519().sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: peerPublicKey,
    );
    final myPub = await myKeyPair.extractPublicKey();
    final salt = _sortedConcat(myPub.bytes, peerPublicKey.bytes);
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: shared,
      nonce: salt,
      info: utf8.encode(hkdfInfo),
    );
    return derived.extractBytes();
  }

  /// 两端排序必须一致：字典序较小者在前（长度作次级判据）
  static List<int> _sortedConcat(List<int> a, List<int> b) {
    final n = a.length < b.length ? a.length : b.length;
    var cmp = 0;
    for (var i = 0; i < n; i++) {
      if (a[i] != b[i]) {
        cmp = a[i] - b[i];
        break;
      }
    }
    if (cmp == 0) cmp = a.length - b.length;
    return cmp <= 0 ? [...a, ...b] : [...b, ...a];
  }

  /// 便捷：把派生结果包成不可变字节表
  static Uint8List asBytes(List<int> key) => Uint8List.fromList(key);
}
