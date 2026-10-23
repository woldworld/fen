/// 换机恢复的**编排层**：把"三要素"变成一次可执行的迁移。
///
/// ---------------------------------------------------------------------------
/// 流程（顺序即正确性，别调换）
/// ---------------------------------------------------------------------------
/// ```
///   用户输入：恢复码 + 口令 + 用户 ID
///        ↓ ① 解开恢复码（口令错 / ID 不符 → 到此为止，本机不作任何改动）
///   旧种子 → 旧钥（只用来签名，**不会**被装进本机）
///        ↓ ② 本地生成一把**新钥**
///        ↓ ③ 用**旧钥**签 ROTATE{身份, 旧公钥, 新公钥, 时刻}
///   Hub 验签通过 → 把 agent_id 改绑到新钥 → **旧设备当场失效**
///        ↓ ④ 此时才把新种子装进本机
/// ```
///
/// **为什么 ③ 必须在 ④ 之前**：反过来的话，一旦服务端拒绝（离线、签名不符、
/// 身份已被别人换过），这台机器就握着一把**没有任何人认的**钥匙，
/// 而旧钥匙已经被它丢掉了 —— 用户会同时失去新旧两个身份。
/// 所以 [RestorePlan.apply] 被刻意做成**独立的一步**，
/// 由调用方在拿到服务端确认之后再执行。
///
/// **为什么旧钥匙不装进本机**：那正是"复制私钥"的老路 ——
/// 两台设备共用一把钥 ⇒ 卖手机等于卖账号，而且双方都察觉不到。
///
/// 本文件**零平台依赖**（不 import Flutter / sqflite / shared_preferences），
/// 但 [RestorePlan.apply] 会经 `AgentIdentity` 落盘（那是它唯一的副作用）。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'agent_identity.dart';
import 'db_helper.dart';
import 'ed25519_sig.dart';
import 'identity_rotation.dart';
import 'key_backup.dart';

/// 恢复过程的失败码（在 [BackupFault] 之外，本层自己产生的）。
abstract final class RecoverFault {
  /// 用旧钥签换钥声明这一步失败 —— 只会在密钥材料不合法时出现。
  static const String signFailed = 'sign_failed';

  /// 新旧公钥算出相同值（极小概率的种子碰撞），拒绝继续。
  static const String degenerateKeys = 'degenerate_keys';
}

/// 一次已准备好、但**尚未落地**的恢复。
class RestorePlan {
  final String agentId;

  /// 旧公钥（base58）—— 换钥声明要退休的那把。
  final String oldPub;

  /// 旧 DID（`did:wold:<old_pub>`）—— UI 用它显示"你要恢复的是这个身份吗"。
  ///
  /// ⚠️ **仅当恢复码里的 `old_pub` 就是创世钥时，它才等于 Hub 的身份锚 `did`**。
  /// 若用户是在**换钥之后**才做的备份，恢复码里的 `old_pub` 已是第二把钥 ⇒
  /// 此值会**偏离**真实身份锚（恢复码里没有携带 `did` 本身）。
  /// ⇒ 用它对用户核对**不可靠**，正式解法是让恢复码或 Hub 提供身份锚（缺口 B）。
  final String oldDid;

  /// 新公钥（base58）—— 接管的那把。
  final String newPub;

  /// 由**新钥**派生的 DID（`did:wold:<new_pub>`）。
  ///
  /// ⚠️ **这不是"恢复后的身份地址"** —— Hub 的换钥端点**只改绑活跃钥、`did` 保持不变**
  /// （见 `lib/hub/hub.js` `/api/identity/rotate` 内的"唯一语义决策点"注释）。
  /// 本字段只用于**指认新钥对应哪个 DID**（换钥链上的下一跳）。
  ///
  /// ⏳ 相关未决项：客户端目前仍按活跃钥派生 DID（`passport_screen` / `_issueDidIfNeeded`），
  /// 与 Hub 的"稳定 DID"**尚未对齐**（缺口 B，见 `lib/身份可携带与恢复方案.md` 开头）。
  final String newDid;

  /// 已由**旧钥**签名的换钥声明 —— 原样交给服务端即可。
  final IdentityRotation rotation;

  /// 32 字节新种子。**只在 [apply] 时使用**，调用方不得落库/写日志。
  final Uint8List newSeed;

  const RestorePlan({
    required this.agentId,
    required this.oldPub,
    required this.oldDid,
    required this.newPub,
    required this.newDid,
    required this.rotation,
    required this.newSeed,
  });

  /// 换钥声明的 JSON（送给服务端 `POST /api/identity/rotate` 的 `payload.rotation`）。
  Map<String, Object?> rotationWire() => rotation.toMap();

  /// 把新种子装进本机，并让本机**接管旧身份**。
  ///
  /// ⚠️ **只在服务端确认改绑成功之后调用**（见文件头"流程 ③ 必须在 ④ 之前"）。
  ///
  /// [didAnchor] = 服务端返回的**身份锚**（`POST /api/identity/rotate` 的 `did`）。
  /// ★ 必须传：Hub 换钥**不改** `did`，本机若只按新钥现推，界面就会显示
  /// 一个 Hub 上查不到的身份地址（本仓 §44 起登记的缺口 B）。
  ///
  /// 三步都要做，缺一样都是"看起来恢复成功、实际收发不通"：
  ///   ① [AgentIdentity.installSeed] —— 换成本机以后用来签名的新钥；
  ///   ② [AgentIdentity.adoptAgentId] —— `my_agent_id`、身份锚与接缝表都指向**旧身份 + 新公钥**；
  ///   ③ 本地记一条**只追加**的换钥历史（权威记录仍在 Hub 与 §16 日志里）。
  ///
  /// ⚠️ 若 ② / ③ 抛错，本机处于"新钥 + 旧身份未接管"的半成品状态；重跑本方法即可
  ///    （三步都是幂等的：`installSeed` 覆盖写、`adoptAgentId` 用 replace、
  ///    ③ 用 `ConflictAlgorithm.ignore` 配 `(agent_id, old_pub)` 主键）。
  Future<void> apply({String? didAnchor}) async {
    final identity = AgentIdentity();
    await identity.installSeed(newSeed);
    await identity.adoptAgentId(
      agentId: agentId,
      pubB58: newPub,
      didAnchor: didAnchor,
    );
    await DBHelper.recordKeyRotation(
      agentId: agentId,
      oldPub: oldPub,
      newPub: newPub,
      rotatedAtMs: rotation.rotatedAtMs,
      sig: rotation.sig,
      confirmedBy: 'hub',
    );
  }

  @override
  String toString() => 'RestorePlan($agentId, $oldDid -> $newDid)';
}

abstract final class IdentityRecovery {
  /// 由恢复码准备一次迁移，**不改动本机任何状态**。
  ///
  /// 返回 [RestorePlan]，或 [BackupError]（口令/格式/ID 不符）。
  ///
  /// [newSeed] 可注入 —— 让测试可复现（生产不传即安全随机）。
  static Future<Object> prepareFromBackup({
    required String code,
    required String password,
    required String agentId,
    int? nowMs,
    List<int>? newSeed,
  }) async {
    final opened = await KeyBackup.open(
      code,
      password: password,
      expectedAgentId: agentId,
    );
    if (opened is! BackupOpen) return opened; // 原样透出 BackupError

    final oldPub = opened.pubB58;
    final seed = newSeed ?? _secureSeed();
    if (seed.length != Ed25519Sig.pubkeyBytes) {
      return const BackupError(RecoverFault.degenerateKeys);
    }

    final newPub = await KeyBackup.pubFromSeed(seed);
    if (newPub == oldPub) {
      // 撞上同一把钥：换钥声明会被服务端以 `noop_rotation` 拒掉。
      // 与其让用户看到服务端的错误码，不如在这里就说清楚。
      return const BackupError(RecoverFault.degenerateKeys);
    }

    final unsigned = IdentityRotation(
      agentId: opened.agentId,
      oldPub: oldPub,
      newPub: newPub,
      rotatedAtMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );

    // ★ 签名者 = **旧钥**。这就是"证明我是本人"的全部依据：
    //   没有旧钥就签不出来，因此服务端与任何第三方都**无法代签**。
    final sig = await _signWithSeed(opened.seed, unsigned.canonicalBytes());
    if (sig == null) {
      return const BackupError(RecoverFault.signFailed);
    }
    final signed = unsigned.copyWith(sig: sig);

    return RestorePlan(
      agentId: opened.agentId,
      oldPub: oldPub,
      oldDid: 'did:wold:$oldPub',
      newPub: newPub,
      newDid: 'did:wold:$newPub',
      rotation: signed,
      newSeed: Uint8List.fromList(seed),
    );
  }

  /// 用任意种子签一段字节（换钥声明必须由旧钥签，而旧钥此刻**并未**装在本机）。
  static Future<String?> _signWithSeed(List<int> seed, List<int> message) async {
    try {
      final kp =
          await Ed25519().newKeyPairFromSeed(Uint8List.fromList(seed));
      final sig = await Ed25519().sign(message, keyPair: kp);
      return base64Encode(sig.bytes);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _secureSeed() {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
  }
}
