/// `did:wold` 去中心化身份标识（PRD §5.4 不可补录项）。
///
/// 格式：`did:wold:<base58(32字节 Ed25519 公钥)>` —— 公钥即身份，
/// DID 自带验证材料，不需要查询任何注册表。
///
/// 为什么"签发"是开发项而不是"格式化字符串"（PRD §5.4）：
/// - **身份一旦发放就固化**，事后换体系等于要求所有人重注册；
/// - **审计必须从第一天连续**：每一次签发都要有带时间戳的自签名记录，
///   断档不可补。所以除了格式，还要有 `issuanceCanonical()` 与签发记录落库。
///
/// 本文件保持**零平台依赖**（不 import Flutter / sqflite），
/// 可用 `dart run tool/verify_did.dart` 验证；签发记录的持久化在 WoldRuntime 里完成。
library;

import 'dart:convert';

import 'agent_protocol.dart';

class WoldDid {
  static const String prefix = 'did:wold:';

  /// 由 base58 公钥构造 DID。
  static String fromPub(String pubBase58) => '$prefix$pubBase58';

  /// 是否是合法的 did:wold（前缀 + base58 可解码 + 解码后恰为 32 字节公钥）。
  static bool isValid(String did) => pubOf(did) != null;

  /// 从 DID 中取出公钥（base58）；非法返回 null。
  static String? pubOf(String did) {
    if (!did.startsWith(prefix)) return null;
    final pub = did.substring(prefix.length);
    if (pub.isEmpty) return null;
    try {
      final bytes = AgentProtocol.base58Decode(pub);
      if (bytes.length != 32) return null;
      return pub;
    } catch (_) {
      return null;
    }
  }

  /// 签发凭证的规范串（自签名对象）。
  ///
  /// 覆盖：DID 本身、公钥、签发时刻。三者任一被篡改，签名即失效。
  /// 注意 DID 与 pub 冗余写入是刻意的——DID 里含 pub，但规范串里
  /// 两者分开出现，可以检测"格式正确但张冠李戴"的记录。
  static String issuanceCanonical({
    required String did,
    required String pub,
    required int issuedAtMs,
  }) =>
      'ISSUE|$did|$pub|$issuedAtMs';

  /// 校验一条签发记录（did / pub 自洽 + 自签名有效）。
  static Future<bool> verifyIssuance({
    required String did,
    required String pub,
    required int issuedAtMs,
    required String sigBase64,
  }) async {
    if (pubOf(did) != pub) return false; // DID 与公钥不配套
    return AgentProtocol.verifyRawSignature(
      utf8.encode(
          issuanceCanonical(did: did, pub: pub, issuedAtMs: issuedAtMs)),
      sigBase64,
      pub,
    );
  }
}
