/// 身份换钥（identity rotation）—— 让身份**能在换机后活下来**。
///
/// ---------------------------------------------------------------------------
/// 为什么恢复必须是"换钥"而不是"把种子抄过去"
/// ---------------------------------------------------------------------------
/// `did:wold` 身份**就是**那把钥匙。若新机沿用同一把钥匙，同时坏掉三件事：
///
/// 1. **「一个人 = 一个身份」不再成立** —— 同一个 DID 出现两个活体，
///    社交行为分叉（两边的账本各写各的）；
/// 2. **旧机仍握着能用的钥匙** ⇒ **手机被卖掉 = 账号被卖掉**，而且**无从察觉**；
/// 3. **现有防护抓不住它** —— `AttestFault.sameKeyBothSides` 只拦"一把钥自演双方"，
///    从来拦不住"两台设备共用一把钥"。
///
/// 所以恢复被建模为**迁移**：
///
///   用户出示旧钥（这就是"我是本人"的全部证明）→ 用旧钥签一条 ROTATE 声明、
///   在其中指认一把**新钥** → 服务端把 `agent_id → new_pub` 改绑 →
///   新钥接管，**旧钥在任何地方都失效**。
///
/// **重放安全是白送的**：一旦某次换钥被应用，重放**同一条声明**会撞上
/// `not_current_key`（`old_pub` 已不再是服务端记录在案的那把钥）。
/// 因此这里**不需要**为防重放维护额外状态。
///
/// ---------------------------------------------------------------------------
/// 本模块**刻意不做**什么
/// ---------------------------------------------------------------------------
/// 它**不阻止**一个人把自己的钥匙交给别人 —— 那与"把设备交出去"是同一个动作。
/// 它做的是让这件事**显形**：每一次换钥都是一条**有签名、只追加、可被第三方独立复算**
/// 的记录（Hub 的 `key_rotations` + §16 透明日志叶子）。
/// 这与 §9.1「用结构，不用措辞」是同一个思路：挡不住的，就让它留下痕迹。
///
/// 本文件**零平台依赖**（不 import Flutter / sqflite / shared_preferences），
/// 因此 `dart run tool/verify_identity_rotation.dart` 可直接离线复算。
library;

import 'dart:convert';

import 'ed25519_sig.dart';
import 'wold_did.dart';

/// 否决码（**语言无关的稳定码**，UI 侧负责翻译成文案）。
///
/// ★ 用字符串常量而不是 enum：这些码是**落库与线格式的一部分**，
/// 改不动已经发出去的记录（与 `IntroState` / `AttestFault` 同款纪律）。
abstract final class RotationFault {
  static const String missingFields = 'missing_fields';
  static const String badPubkey = 'bad_pubkey';

  /// 换到同一把钥上：什么也没改变，却白占一条只追加的记录。
  static const String noopRotation = 'noop_rotation';

  /// ★ **本模块的核心判据**：只有**当前记录在案的那把钥**才有资格退休自己。
  static const String notCurrentKey = 'not_current_key';

  static const String badTime = 'bad_time';
  static const String badSignature = 'bad_signature';
  static const String staleRotation = 'stale_rotation';
}

/// 换钥声明的判定结果。
///
/// 刻意不做成 `bool`：调用方需要区分"字段不全"与"签名伪造"，
/// 而一个 `bool` 会把它们压成同一个"不行"。
class RotationVerdict {
  final bool accept;
  final String code;

  const RotationVerdict({required this.accept, required this.code});

  @override
  String toString() => 'RotationVerdict(accept=$accept, code=$code)';
}

/// 一条**已签名的**换钥声明。
class IdentityRotation {
  /// 哪个身份在换钥（`my_agent_id`）。
  final String agentId;

  /// 被退休的公钥（base58）—— **签名方就是它**。
  final String oldPub;

  /// 接管的新公钥（base58）。
  final String newPub;

  final int rotatedAtMs;

  /// base64 签名，由 `oldPub` 对应的私钥签出。未签时为空串。
  final String sig;

  /// 比信封的 5 分钟窗口**更宽**：刚装好的新手机时钟可能有偏差。
  ///
  /// 放宽的代价可控：换钥**不是**一次性令牌，重放已经被
  /// [RotationFault.notCurrentKey] 挡住，时间窗只用来挡"陈年声明突然生效"。
  static const int maxSkewMs = 15 * 60 * 1000;

  const IdentityRotation({
    required this.agentId,
    required this.oldPub,
    required this.newPub,
    required this.rotatedAtMs,
    this.sig = '',
  });

  /// 换钥之后的 `did:wold`（由新公钥直接导出，不需要任何注册表）。
  String get newDid => WoldDid.fromPub(newPub);

  /// **确定性签名载荷**（JSON，键序固定）。
  ///
  /// ⚠️ 键序必须与 `packages/protocol/src/rotation.js` 的 `canonical()` **逐字节一致**——
  /// 由 `tool/verify_identity_rotation.js` 跨语言钉住（Dart 签、Node 验）。
  /// `alg` 与 `kind` 必须入载荷：前者挡"算法混淆"，后者挡
  /// "拿一份合法的**签发**记录当作**换钥**去验"（两者字段高度相似）。
  String canonical() => jsonEncode({
        'alg': Ed25519Sig.alg,
        'kind': 'identity_rotation',
        'agent_id': agentId,
        'old_pub': oldPub,
        'new_pub': newPub,
        'rotated_at': rotatedAtMs,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  /// §16 公开日志里**被承诺的那串字节**。
  ///
  /// ⚠️ 刻意与 [canonical] **不是同一个对象**（照抄 `contribution.logBytes` 的分工）：
  /// [canonical] 是**旧钥签的东西**（所以带 `alg`），这里是**第三方 monitor 从公开
  /// 记录复算的东西**（所以带 `kind`、**不带 `sig`** —— Ed25519 签名是确定性的，
  /// 签名不提供"钥 + 消息"之外的信息）。两端必须逐字节一致，否则会各自长出一棵不同的树。
  List<int> logBytes() => utf8.encode(jsonEncode({
        'kind': 'identity_rotation',
        'agent_id': agentId,
        'old_pub': oldPub,
        'new_pub': newPub,
        'rotated_at': rotatedAtMs,
      }));

  /// 幂等键 —— `agent_id|old_pub`，与两边 `key_rotations` 的主键同构
  /// （一把钥只能退休一次；换了一把钥就是**另一次**事件）。
  ///
  /// ⚠️ 时间**刻意不入键**（理由同 `contribution.keyOf`）：入键就能把同一次换钥
  /// 改个时间重签一遍、在只追加日志里塞进第二条。
  static String keyOf(String agentId, String oldPub) => '$agentId|$oldPub';

  IdentityRotation copyWith({String? newPub, String? sig}) => IdentityRotation(
        agentId: agentId,
        oldPub: oldPub,
        newPub: newPub ?? this.newPub,
        rotatedAtMs: rotatedAtMs,
        sig: sig ?? this.sig,
      );

  Map<String, Object?> toMap() => {
        'agent_id': agentId,
        'old_pub': oldPub,
        'new_pub': newPub,
        'rotated_at': rotatedAtMs,
        'sig': sig,
      };

  static IdentityRotation fromMap(Map<String, dynamic> m) => IdentityRotation(
        agentId: (m['agent_id'] ?? '').toString(),
        oldPub: (m['old_pub'] ?? '').toString(),
        newPub: (m['new_pub'] ?? '').toString(),
        rotatedAtMs: (m['rotated_at'] as num?)?.toInt() ?? 0,
        sig: (m['sig'] ?? '').toString(),
      );

  /// 签名是否有效（`oldPub` 是否为合法公钥 + 签名是否覆盖 [canonical]）。
  Future<bool> sigValid() => Ed25519Sig.verify(
        message: canonicalBytes(),
        signatureB64: sig,
        publicKeyBase58: oldPub,
      );

  /// 服务端/观察者的**准入判定**（廉价检查在前、密码学在后）。
  ///
  /// [currentPub] 是服务端**当前**为 `agentId` 记录的公钥；
  /// 不知道这个身份时传空串（此时一律 `not_current_key` ——
  /// **不允许把一个不存在的身份"换钥"出来**）。
  static Future<RotationVerdict> verify(
    IdentityRotation r, {
    required String currentPub,
    int? nowMs,
  }) async {
    if (r.agentId.trim().isEmpty ||
        r.oldPub.isEmpty ||
        r.newPub.isEmpty ||
        r.sig.isEmpty) {
      return const RotationVerdict(
          accept: false, code: RotationFault.missingFields);
    }
    if (!Ed25519Sig.isPubkey(r.oldPub) || !Ed25519Sig.isPubkey(r.newPub)) {
      return const RotationVerdict(accept: false, code: RotationFault.badPubkey);
    }
    // 换到同一把钥上：什么也没变，却会白占一条只追加的记录。**在验签之前**判，
    // 因为一份"签名完全合法"的空操作仍然不该被接受。
    if (r.oldPub == r.newPub) {
      return const RotationVerdict(
          accept: false, code: RotationFault.noopRotation);
    }
    // ★ 核心：只有当前记录在案的钥才能退休自己。被取代的钥换不了第二次，
    //   攻击者也无法靠在这条声明里写上别人的身份来换掉别人的钥。
    if (currentPub.isEmpty || r.oldPub != currentPub) {
      return const RotationVerdict(
          accept: false, code: RotationFault.notCurrentKey);
    }
    // 廉价检查在密码学之前（与 `endorsement.accept` 同款顺序）：
    // 形状搞错的调用方应该拿到形状错误，而不是一句 bad_signature。
    if (r.rotatedAtMs <= 0) {
      return const RotationVerdict(accept: false, code: RotationFault.badTime);
    }
    if (!await r.sigValid()) {
      return const RotationVerdict(
          accept: false, code: RotationFault.badSignature);
    }
    if (nowMs != null && (nowMs - r.rotatedAtMs).abs() > maxSkewMs) {
      return const RotationVerdict(
          accept: false, code: RotationFault.staleRotation);
    }
    return const RotationVerdict(accept: true, code: 'ok');
  }
}
