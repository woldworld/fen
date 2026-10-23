import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

/// Agent 联邦协议 v1：通道无关的消息信封。
///
/// 双算法支持（信封新增 `alg` 字段，缺省 hmac-sha256，向后兼容旧节点）：
/// - `hmac-sha256`：设备共享密钥（可防篡改；引导期方案）。
/// - `ed25519`：设备私钥签名，公钥注册进 Hub（`did:wold:<base58(pubkey)>`），
///   私钥永不出设备，Hub 被拖库不危及身份。sig 为 64 字节签名的 base64。
///
/// **协议名（v1.2 改名）**：新信封发 `wold/1`；验签**同时接受**旧值
/// `pocketagent/1`，保证升级过渡期内新旧客户端互通（见 §决策记录 v1.2）。
class AgentProtocol {
  AgentProtocol._();

  static const String protoVersion = 'wold/1';
  static const String legacyProtoVersion = 'pocketagent/1';

  /// 是否为受支持的协议版本（新版与过渡期旧版都算）
  static bool isSupportedProto(Object? proto) =>
      proto == protoVersion || proto == legacyProtoVersion;

  static const String algHmac = 'hmac-sha256';
  static const String algEd25519 = 'ed25519';
  static final Ed25519 _ed25519 = Ed25519();

  /// 构造带 HMAC 签名的信封（本地通道与兼容回退路径继续使用）
  static Map<String, dynamic> buildEnvelope({
    required String fromId,
    required String toId,
    required Map<String, dynamic> payload,
    required String secret,
  }) {
    final body = _envelopeBody(
      fromId: fromId,
      toId: toId,
      payload: payload,
      alg: algHmac,
    );
    body['sig'] = _hmacHex(secret, jsonEncode(body));
    return body;
  }

  /// 构造 Ed25519 签名的信封（Hub 通道升级路径：公钥注册 + 私钥不出设备）
  static Future<Map<String, dynamic>> buildEd25519Envelope({
    required String fromId,
    required String toId,
    required Map<String, dynamic> payload,
    required SimpleKeyPair keyPair,
  }) async {
    final body = _envelopeBody(
      fromId: fromId,
      toId: toId,
      payload: payload,
      alg: algEd25519,
    );
    final sig = await _ed25519.sign(utf8.encode(jsonEncode(body)), keyPair: keyPair);
    body['sig'] = base64Encode(sig.bytes);
    return body;
  }

  static Map<String, dynamic> _envelopeBody({
    required String fromId,
    required String toId,
    required Map<String, dynamic> payload,
    required String alg,
  }) {
    return {
      'proto': protoVersion,
      'alg': alg,
      'type': payload['kind'] ?? 'text',
      'from': fromId,
      'to': toId,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'nonce': _randomHex(16),
      'payload': payload,
    };
  }

  /// 验签并返回信封（HMAC，同步；本地通道与旧节点用）
  static Map<String, dynamic>? verifyEnvelope(
    Map<String, dynamic> env,
    String secret,
  ) {
    return _verifyHmac(env, secret);
  }

  /// 按信封 `alg` 验签（Hub 通道）：ed25519 用公钥，hmac 用共享密钥。
  /// 验证失败一律返回 null。
  static Future<Map<String, dynamic>?> verifyEnvelopeAsync(
    Map<String, dynamic> env, {
    String? secret,
    String? pubKeyBase58,
  }) async {
    final alg = env['alg'] as String? ?? algHmac;
    if (alg == algEd25519) {
      if (pubKeyBase58 == null) return null;
      final ok = await _verifyEd25519(env, pubKeyBase58);
      return ok ? env : null;
    }
    return _verifyHmac(env, secret ?? '');
  }

  static Map<String, dynamic>? _verifyHmac(Map<String, dynamic> env, String secret) {
    try {
      final sig = env['sig'] as String?;
      if (sig == null || sig.isEmpty || secret.isEmpty) return null;
      if (!isSupportedProto(env['proto'])) return null;
      final unsigned = Map<String, dynamic>.from(env)..remove('sig');
      if (_hmacHex(secret, jsonEncode(unsigned)) != sig) return null;
      return env;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _verifyEd25519(Map<String, dynamic> env, String pubKeyBase58) async {
    try {
      final sigB64 = env['sig'] as String?;
      if (sigB64 == null || sigB64.isEmpty) return false;
      if (!isSupportedProto(env['proto'])) return false;
      final pubBytes = base58Decode(pubKeyBase58);
      if (pubBytes.length != 32) return false;
      final pub = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
      final sig = base64Decode(sigB64);
      final unsigned = Map<String, dynamic>.from(env)..remove('sig');
      return await _ed25519.verify(
        utf8.encode(jsonEncode(unsigned)),
        signature: Signature(sig, publicKey: pub),
      );
    } catch (_) {
      return false;
    }
  }

  /// 裸消息 Ed25519 验签（本地通道 HELLO 等场景使用）
  static Future<bool> verifyRawSignature(
      List<int> message, String sigB64, String pubKeyBase58) async {
    try {
      final pubBytes = base58Decode(pubKeyBase58);
      if (pubBytes.length != 32) return false;
      final pub = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
      return await _ed25519.verify(
        message,
        signature: Signature(base64Decode(sigB64), publicKey: pub),
      );
    } catch (_) {
      return false;
    }
  }

  // ---------- base58（Bitcoin 字母表；公钥的规范编码） ----------

  static const String _b58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String base58Encode(List<int> bytes) {
    if (bytes.isEmpty) return '';
    var num = BigInt.zero;
    for (final b in bytes) {
      num = (num << 8) | BigInt.from(b);
    }
    var out = '';
    while (num > BigInt.zero) {
      final mod = num % BigInt.from(58);
      out = _b58Alphabet[mod.toInt()] + out;
      num = num ~/ BigInt.from(58);
    }
    for (final b in bytes) {
      if (b == 0) {
        out = '1$out';
      } else {
        break;
      }
    }
    return out;
  }

  static List<int> base58Decode(String s) {
    var num = BigInt.zero;
    for (final ch in s.split('')) {
      final idx = _b58Alphabet.indexOf(ch);
      if (idx < 0) throw FormatException('invalid base58 char: $ch');
      num = num * BigInt.from(58) + BigInt.from(idx);
    }
    final bytes = <int>[];
    while (num > BigInt.zero) {
      bytes.insert(0, (num & BigInt.from(0xff)).toInt());
      num = num >> 8;
    }
    for (final ch in s.split('')) {
      if (ch == '1') {
        bytes.insert(0, 0);
      } else {
        break;
      }
    }
    return bytes;
  }

  static Map<String, dynamic>? payloadOf(Map<String, dynamic> env) {
    final payload = env['payload'];
    return payload is Map<String, dynamic> ? payload : null;
  }

  static String _hmacHex(String secret, String data) {
    final keyBytes = utf8.encode(secret);
    final hmac = crypto.Hmac(crypto.sha256, keyBytes);
    return hmac.convert(utf8.encode(data)).toString();
  }

  static String _randomHex(int n) {
    final rng = Random.secure();
    final bytes = List<int>.generate(n, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
