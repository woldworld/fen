/// 身份备份/恢复：**恢复码 + 用户口令 + 用户 ID** 三要素。
///
/// ---------------------------------------------------------------------------
/// 为什么是"三要素"，各自负责什么（别让它们互相冒充）
/// ---------------------------------------------------------------------------
/// | 要素 | 它真正的作用 | 它**不是**什么 |
/// |---|---|---|
/// | **恢复码** | 装着被口令加密的**旧私钥种子** —— 没有它就什么都恢复不了 | 不是"账号"，不能单独使用（有口令才解得开） |
/// | **用户口令** | 唯一用途是**解密恢复码** | ★ **绝不用于服务端验证**（见下） |
/// | **用户 ID** | **对错纠错**：恢复出的身份必须就是你要的那个 | 不是安全要素（ID 在 Hub 上公开可查） |
///
/// ---------------------------------------------------------------------------
/// ★ 为什么口令**绝不能**用来做服务端验证
/// ---------------------------------------------------------------------------
/// 一旦我们在 Hub 上存了口令（或它的哈希），Hub 就成了**身份保管人**：
/// 它可以在用户不知情时替用户重签、可以拿拖库的哈希离线爆破，
/// 而"身份与信誉归你自己持有"（服务条款 §1）就变成了一句空话。
///
/// 所以本模块的口令**不经过网络、不落任何地方**：
/// 它只做一件事 —— 从恢复码里解出种子。**解得开 = 口令对**，
/// 我们既不需要存它，也**没有能力**验证它。这条不是实现细节，是设计约束。
///
/// ---------------------------------------------------------------------------
/// 为什么恢复码里**明文带着** agent_id 与公钥
/// ---------------------------------------------------------------------------
/// 公钥即身份、`did:wold` 由它直接导出 —— 这两样**本来就是公开的**（Hub 上可查）。
/// 明文放它们的收益很实在：用户在**输口令之前**就能看到"这份备份属于哪个身份"，
/// 从而避免"拿 A 的备份去恢复 B"这类把两个身份搅在一起的事故。
/// 真正需要保护的东西只有一样：**种子**。它被口令加密封在里面。
///
/// 本文件**零平台依赖**（不 import Flutter / sqflite / shared_preferences；
/// 只用 `dart:convert` + `package:cryptography`），因此可离线复算。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'agent_protocol.dart';
import 'ed25519_sig.dart';

/// 恢复码的解析/解密失败码（语言无关的稳定码，UI 负责翻译）。
abstract final class BackupFault {
  /// 格式不对（分段数、前缀、base64 任一不合法）——**fail-closed**。
  static const String badFormat = 'bad_format';

  /// 用户输入的 ID 与恢复码里的 ID 不一致。★ 这是"防恢复到错误身份"的第一道闸。
  static const String idMismatch = 'id_mismatch';

  /// 口令错（或恢复码被改动过）。GCM 的认证标签能区分不了这两者，**也不需要**区分：
  /// 对用户来说处理方式一样，对攻击者来说都解不开。
  static const String badPassword = 'bad_password';

  /// 解出来的种子长度不是 32 字节 —— 合法恢复码不可能走到这里。
  static const String badSeed = 'bad_seed';

  /// 解出的种子推导出的公钥与恢复码里记的公钥不符（恢复码被改过）。
  static const String pubMismatch = 'pub_mismatch';

  static const String weakPassword = 'weak_password';
}

/// 解密成功后的内容。
class BackupOpen {
  final String agentId;

  /// 旧公钥（base58）—— 换钥声明要退休的就是它。
  final String pubB58;

  /// 32 字节 Ed25519 种子。**调用方用完必须尽快丢弃**（不要落库、不要写日志）。
  final Uint8List seed;

  const BackupOpen({
    required this.agentId,
    required this.pubB58,
    required this.seed,
  });

  @override
  String toString() =>
      'BackupOpen(agentId=$agentId, pub=${pubB58.length > 12 ? '${pubB58.substring(0, 12)}…' : pubB58})';
}

/// 解密失败的结论（带码，便于 UI 说清"是哪一步不对"）。
class BackupError {
  final String code;
  const BackupError(this.code);
  @override
  String toString() => 'BackupError($code)';
}

abstract final class KeyBackup {
  /// 恢复码版本前缀。**改格式必须换前缀**（旧码要能被识别为"另一个版本"而不是"坏码"）。
  static const String prefix = 'FENBK1';

  /// 本地数据归档（`.dahuang`）的前缀。
  ///
  /// ⚠️ 与恢复码**刻意用不同前缀**，不是洁癖：两者都是"口令加密的一坨字节"，
  /// 但**装的东西完全不同** —— 恢复码里是**身份**（种子），归档里是**数据**。
  /// 同前缀会让"把归档当恢复码喂进恢复流程"在**格式校验**那一层就通过，
  /// 于是错误只在很后面才暴露。前缀不同 ⇒ 一眼可辨。
  static const String archivePrefix = 'FENARC1';

  /// 口令**最短**长度。
  ///
  /// 长度门槛是有效性和可用性之间唯一诚实的折中：口令是这份备份的**唯一**保护，
  /// 而恢复码本身可以（而且应该）另存一处。过短的口令等于没有第二因子。
  static const int minPasswordChars = 10;

  /// ★ PBKDF2 迭代次数 —— **这是可调参数，不是随口写的常量**。
  ///
  /// 为什么是 120000 而不是 OWASP 建议的 600000：本项目的 KDF 跑在
  /// **纯 Dart** 实现上（未引入原生加速包），迭代次数直接决定用户按住按钮的秒数。
  /// 120000 是在"离线爆破成本"与"恢复时不要卡到用户以为死机"之间取的值。
  /// ⚠️ **待真机复核**：实测恢复耗时；若明显偏快/偏慢，改这一个常量即可
  ///    （⚠️ 改了**不能**读旧码 —— 所以迭代次数被写进恢复码里，见 [seal]）。
  static const int pbkdf2Iterations = 120000;

  static const int _saltBytes = 16;
  static const int _nonceBytes = 12;

  /// 是否达到了口令强度门槛。
  static bool isPasswordAcceptable(String password) =>
      password.trim().length >= minPasswordChars;

  /// 把种子封成一个**恢复码**（口令加密）。
  ///
  /// 输出形如 `FENBK1.<agentId>.<pub>.<salt>.<nonce>.<ct>.<mac>`，
  /// 每一段都是 base64（第 2/3 段是明文标识，其余是密文材料）。
  static Future<String> seal({
    required List<int> seed,
    required String agentId,
    required String pubB58,
    required String password,
  }) async {
    if (seed.length != Ed25519Sig.pubkeyBytes) {
      throw ArgumentError('seed must be 32 bytes, got ${seed.length}');
    }
    if (agentId.trim().isEmpty || pubB58.trim().isEmpty) {
      throw ArgumentError('agentId and pubB58 are required');
    }

    final rnd = Random.secure();
    final salt = _randomBytes(rnd, _saltBytes);
    final nonce = _randomBytes(rnd, _nonceBytes);
    final key = await _deriveKey(password, salt);

    final box = await AesGcm.with256bits().encrypt(
      seed,
      secretKey: key,
      nonce: nonce,
    );

    return [
      prefix,
      agentId.trim(),
      pubB58.trim(),
      base64.encode(salt),
      base64.encode(nonce),
      base64.encode(box.cipherText),
      base64.encode(box.mac.bytes),
    ].join('.');
  }

  /// 打开恢复码。
  ///
  /// [expectedAgentId] **必填**：它就是用户手工输入的那个 ID。
  /// 与码内 ID 不一致时直接 [BackupFault.idMismatch]，**不做任何解密尝试** ——
  /// 用户要恢复的是"某个特定身份"，把别人的备份恢复进这台机器是最坏的结果之一。
  ///
  /// 返回 [BackupOpen] 或 [BackupError]（不抛异常，便于 UI 逐码提示）。
  static Future<Object> open(
    String code, {
    required String password,
    required String expectedAgentId,
  }) async {
    final parts = code.trim().split('.');
    if (parts.length != 7 || parts[0] != prefix) {
      return const BackupError(BackupFault.badFormat);
    }

    final agentId = parts[1];
    final pubB58 = parts[2];
    final Uint8List salt;
    final Uint8List nonce;
    final Uint8List ct;
    final Uint8List mac;
    try {
      salt = base64.decode(parts[3]);
      nonce = base64.decode(parts[4]);
      ct = base64.decode(parts[5]);
      mac = base64.decode(parts[6]);
    } catch (_) {
      return const BackupError(BackupFault.badFormat);
    }
    if (salt.length != _saltBytes ||
        nonce.length != _nonceBytes ||
        mac.isEmpty ||
        ct.isEmpty) {
      return const BackupError(BackupFault.badFormat);
    }

    // ★ 先比 ID，再谈解密 —— 顺序不能反（见方法注释）。
    if (agentId != expectedAgentId.trim()) {
      return const BackupError(BackupFault.idMismatch);
    }

    final seed = await _decrypt(password, salt, nonce, ct, mac);
    if (seed == null) return const BackupError(BackupFault.badPassword);
    if (seed.length != Ed25519Sig.pubkeyBytes) {
      return const BackupError(BackupFault.badSeed);
    }

    // 恢复码里的公钥与种子必须配套。GCM 已经保证了"密文没被改"，
    // 这一步保的是"**明文那段也没被改**"（改 pubB58 不触碰密文，GCM 察觉不到）。
    final derivedPub = await pubFromSeed(seed);
    if (derivedPub != pubB58) {
      return const BackupError(BackupFault.pubMismatch);
    }

    return BackupOpen(agentId: agentId, pubB58: pubB58, seed: seed);
  }

  /// 把**任意字节**封成口令加密的 blob（本地数据归档用）。
  ///
  /// 与 [seal] **共用同一套 KDF 与 AEAD**（[pbkdf2Iterations] / `_deriveKey` /
  /// `AesGcm.with256bits()`）—— **刻意不另写一份加密**：两处实现一旦漂移，
  /// 症状会是"本机导得出、换机读不回"，而那种缺陷极难复现。
  ///
  /// 输出形如 `<prefix>.<salt>.<nonce>.<ct>.<mac>`（5 段，均为 base64）。
  static Future<String> sealBlob({
    required List<int> payload,
    required String password,
    String prefix = archivePrefix,
  }) async {
    if (payload.isEmpty) {
      throw ArgumentError('payload must not be empty');
    }
    final rnd = Random.secure();
    final salt = _randomBytes(rnd, _saltBytes);
    final nonce = _randomBytes(rnd, _nonceBytes);
    final key = await _deriveKey(password, salt);

    final box = await AesGcm.with256bits().encrypt(
      Uint8List.fromList(payload),
      secretKey: key,
      nonce: nonce,
    );

    return [
      prefix,
      base64.encode(salt),
      base64.encode(nonce),
      base64.encode(box.cipherText),
      base64.encode(box.mac.bytes),
    ].join('.');
  }

  /// 打开 [sealBlob] 产出的 blob。
  ///
  /// 返回明文字节，或 [BackupError]（格式不对 = [BackupFault.badFormat]；
  /// 口令错/被改动 = [BackupFault.badPassword]）——
  /// **一律 fail-closed**，GCM 的认证标签不允许"读出一半"。
  static Future<Object> openBlob(
    String blob, {
    required String password,
    String prefix = archivePrefix,
  }) async {
    final parts = blob.trim().split('.');
    if (parts.length != 5 || parts[0] != prefix) {
      return const BackupError(BackupFault.badFormat);
    }
    final Uint8List salt;
    final Uint8List nonce;
    final Uint8List ct;
    final Uint8List mac;
    try {
      salt = base64.decode(parts[1]);
      nonce = base64.decode(parts[2]);
      ct = base64.decode(parts[3]);
      mac = base64.decode(parts[4]);
    } catch (_) {
      return const BackupError(BackupFault.badFormat);
    }
    if (salt.length != _saltBytes ||
        nonce.length != _nonceBytes ||
        mac.isEmpty ||
        ct.isEmpty) {
      return const BackupError(BackupFault.badFormat);
    }
    final clear = await _decrypt(password, salt, nonce, ct, mac);
    if (clear == null) return const BackupError(BackupFault.badPassword);
    return clear;
  }

  /// 由 32 字节种子推导 base58 公钥 —— 恢复路径上"这一段能不能对上"的唯一判据。
  ///
  /// ⚠️ base58 走 [AgentProtocol] 的**既有单一实现**，本文件不另写一份：
  /// 本仓吃过"两处 base58 / 两份 canonical 悄悄漂移"的亏，
  /// 那种缺陷的症状是"作者签得对、对面一律拒"，极难复现。
  static Future<String> pubFromSeed(List<int> seed) async {
    final kp =
        await Ed25519().newKeyPairFromSeed(Uint8List.fromList(seed));
    final pub = await kp.extractPublicKey();
    return AgentProtocol.base58Encode(pub.bytes);
  }

  /// 用**种子**签一段字节（base64 签名），与 [pubFromSeed] 成对、落在同一处。
  ///
  /// ★ 存在的唯一理由：换机直迁的 `ack` 必须由**新钥**签出，而那一时刻
  /// 新机手里只有**种子** —— `AgentIdentity` 指向的还是旧身份/旧钥
  /// （种子要等 Hub 确认后才由 `RestorePlan.apply` 装进钥匙串）。
  /// 没有这个方法，"新钥签名"就只能靠"先把钥装进去"来绕，
  /// 那正好把"落盘在前、回报在后"的次序又翻回去。
  ///
  /// ⚠️ 与 [pubFromSeed] 共用 `Ed25519().newKeyPairFromSeed`：两处若各写一份
  /// 密钥派生，就会出现"推出来的公钥对得上、签出来的名却验不过"这种最费时的缺陷。
  /// 验签侧是 `Ed25519Sig.verify`（全项目唯一实现），此处不另写。
  static Future<String> signWithSeed(List<int> seed, List<int> message) async {
    final kp =
        await Ed25519().newKeyPairFromSeed(Uint8List.fromList(seed));
    final sig = await Ed25519().sign(message, keyPair: kp);
    return base64Encode(sig.bytes);
  }

  // ------------------------------------------------------------------
  // 内部
  // ------------------------------------------------------------------

  static Future<SecretKey> _deriveKey(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static Future<Uint8List?> _decrypt(
    String password,
    List<int> salt,
    List<int> nonce,
    List<int> ct,
    List<int> mac,
  ) async {
    try {
      final key = await _deriveKey(password, salt);
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(ct, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } catch (_) {
      return null; // 口令错 / 被改动 / 参数不合法 —— 一律 fail-closed
    }
  }

  static Uint8List _randomBytes(Random rnd, int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => rnd.nextInt(256)));
}
