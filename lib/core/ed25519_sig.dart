/// Ed25519 验签的**唯一实现**（M9 技能签名 / M6 背书签名共用）。
///
/// ---------------------------------------------------------------------------
/// 为什么要有这个文件
/// ---------------------------------------------------------------------------
/// M9 的 `skill_registry.dart` 里原本有一份私有 `_verifyEd25519`。M6 的背书签名
/// 需要**同一套**验签语义（同样的 base58 公钥、同样的 base64 签名、同样的
/// "任何异常都 fail-closed"）。复制一份到新模块是最容易的做法，但那会埋下
/// 本项目最典型的一类缺陷：**两处密码学实现悄悄漂移** ——
/// 一边放宽了长度校验、另一边没有，于是"技能签名验不过的假签名，背书那边却验过了"。
///
/// 所以抽成单一实现，两处都调它。
///
/// 本文件**零平台依赖**（不 import `flutter` / `sqflite` / `shared_preferences`；
/// 只用 `dart:convert` + `package:cryptography` + `agent_protocol`），
/// 因此 `dart run tool/verify_*.dart` 可直接复算。
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'agent_protocol.dart' show AgentProtocol;

abstract final class Ed25519Sig {
  /// 签名算法标识。**必须**写进签名载荷（canonical），否则攻击者可打"算法混淆"：
  /// 拿同一份载荷换成另一种算法/公钥去验，而验签方无法察觉载荷本身没变。
  static const String alg = 'ed25519';

  /// Ed25519 公钥的字节长度。
  static const int pubkeyBytes = 32;

  /// Ed25519 签名的字节长度。
  static const int signatureBytes = 64;

  /// 公钥是否为合法的 32 字节 Ed25519 公钥（base58）。
  static bool isPubkey(String publicKeyBase58) {
    try {
      return AgentProtocol.base58Decode(publicKeyBase58).length == pubkeyBytes;
    } catch (_) {
      return false; // fail-closed
    }
  }

  /// 验签。**任何异常都返回 false**（fail-closed）：坏 base58、坏 base64、
  /// 长度不对、公钥不合法 —— 一律视为"验不过"，绝不放过。
  static Future<bool> verify({
    required List<int> message,
    required String signatureB64,
    required String publicKeyBase58,
  }) async {
    try {
      final pubBytes = AgentProtocol.base58Decode(publicKeyBase58);
      if (pubBytes.length != pubkeyBytes) return false;
      final sigBytes = base64Decode(signatureB64);
      if (sigBytes.length != signatureBytes) return false;
      final pub = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
      return await Ed25519().verify(
        message,
        signature: Signature(sigBytes, publicKey: pub),
      );
    } catch (_) {
      return false;
    }
  }
}
