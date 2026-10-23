/// M6 轻量前置 · 可验证签名互介记录（PRD §4 M6「信誉体系的种子」）。
///
/// **为什么这件事不能后补**（PRD §5.4「不可补录」原则）：
/// 信誉体系的全部价值来自"履历可被第三方独立验证"。履历一旦以
/// "只存在我这台机器上的一个整数分数"的形式开始，事后无法追溯补签 ——
/// 所以种子必须在第一个用户之前就位（与 M1 的双向签名圈籍同款纪律）。
///
/// ## 记录什么（PRD §4 M6 原话三条）
///
/// | 要求 | 本层如何满足 |
/// |---|---|
/// | **这次互介是谁发起** | `initiatorId` + 发起方对 `intentCanonical()` 的签名 |
/// | **双方是否同意** | 发起方与对端**对同一份 `consentCanonical()` 各签一次** |
/// | **结果如何** | `outcome`（握手/拒绝/无回应/撤回）+ 主张方签名 + 对端可选追认 |
///
/// ## 为什么"双方同意"必须两把钥匙签同一份字节
///
/// 沿用 M1 `CircleMembership` 的做法（那里是 memberSig + hostSig）：
/// **两把签名覆盖同一份规范字节**。这一条直接消灭了"单方伪造"：
/// - 发起方无法自己造出一条 `consented` 记录 —— 它没有对端的私钥；
/// - 任何一方都无法事后改写 `topic` / `circleId` / `roomId` / 时间 ——
///   这些字段被写进了**双方都已签过的**那份字节里，改一个字两个签名全废。
///
/// 结果段同理：`resolveCanonical()` 把整份 `consentCanonical()` **内嵌**进去，
/// 所以"改结果"必须连对端的同意签名一起推翻；对端还可以再签一次 `ackCanonical()`
/// 追认结果，于是"结果"也从"单方主张"升级为"双方确认"。
///
/// ## 可离线验证（VC 的实质，PRD §16「SCT 可验证凭证」）
///
/// 验证一条记录**只需要两个公钥**，不需要联网、不需要信任任何服务器、
/// 不需要查任何注册表。公钥即身份（`did:wold:` 从公钥直接导出，见 [WoldDid]）。
///
/// ## 诚实口径
///
/// 本层**不产生"信誉分"**。它只产生**可验证的事实**：
/// "有过这条互介、双方签了、结果是握手"。
/// 分数怎么算、权重多少，是上层策略 —— 而且必须可后置调整（PRD §5.4：
/// 策略与阈值可后置，签名与留痕不可后补）。
///
/// 本文件**零平台依赖**（不 import Flutter / sqflite），
/// `dart run tool/verify_attestation.dart` 可离线复算全部判定。

library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'agent_protocol.dart';
import 'circle_service.dart' show Signer; // 复用签名抽象（生产=设备密钥，测试=纯 Dart）
import 'wold_did.dart';

// ---------------------------------------------------------------------------
// 状态与结果码（**语言无关的稳定码**，UI 侧负责翻译成文案）
// ---------------------------------------------------------------------------

/// 记录所处阶段（由字段是否具备推导，不是独立存储的状态）。
abstract final class IntroState {
  /// 只签了"我想认识他" —— 对方还没同意。
  static const String proposed = 'proposed';

  /// **双方都签了** —— 互介在可验证意义上成立（这是最小充分条件）。
  static const String consented = 'consented';

  /// 已记录结果。
  static const String resolved = 'resolved';
}

/// 终局结果码。
abstract final class IntroOutcome {
  /// ✅ 真正握手（链路 β 的成功事件，PRD §4.0 的"互介→握手"分子）。
  static const String handshake = 'handshake';

  /// 对方明确拒绝。
  static const String declined = 'declined';

  /// 超过窗口无回应。
  static const String noResponse = 'no_response';

  /// 发起方在窗口内撤回（与 M3 的 24h 撤回同款纪律）。
  static const String withdrawn = 'withdrawn';

  static const Set<String> all = {handshake, declined, noResponse, withdrawn};

  /// 该结果是否算"成功握手"。
  static bool isSuccess(String? code) => code == handshake;
}

/// 可验证等级（**由实际验过的签名决定，不由记录自称决定**）。
///
/// 这是本层最重要的一个概念：一条记录可以"自称"已经是握手，
/// 但 [IntroVerifier] 只按**真正验过的签名**给出等级。
/// UI 必须显示等级，而不是显示记录里的 `outcome` 字段本身。
abstract final class IntroTrust {
  /// 连发起签名都验不过 —— 不可用。
  static const String none = 'none';

  /// 只有发起方签名（`proposed`）。
  static const String initiated = 'initiated';

  /// 双方签名齐全且都验过（`consented`）。**互介成立**。
  static const String consented = 'consented';

  /// 追加了结果主张方签名（`resolved`）。
  static const String resolved = 'resolved';

  /// 对端追认了结果（`acknowledged`）。**最强档**：连"结果"都是双方的共识。
  static const String acknowledged = 'acknowledged';

  /// 等级高低（用于"至少达到某档"的判断）。
  static int rankOf(String level) => switch (level) {
        acknowledged => 4,
        resolved => 3,
        consented => 2,
        initiated => 1,
        _ => 0,
      };
}

/// 校验失败原因码（fail-closed：**任一项不过，等级就停在它下面那一档**）。
abstract final class AttestFault {
  static const String emptyIds = 'empty_ids';
  static const String selfIntroduction = 'self_introduction';
  static const String badId = 'bad_id';
  static const String badTimeOrder = 'bad_time_order';
  static const String missingInitiatorPub = 'missing_initiator_pub';
  static const String badInitiatorSig = 'bad_initiator_sig';

  /// 🔴 **同一把密钥同时扮演双方** —— 这是"双方同意"最容易被钻的洞：
  /// 只要不查这一条，一个人用**自己的**密钥签两次、把两处 pub 都填成自己，
  /// 就能伪造出一条"双方同意"的记录。所以它是硬规则，不是可选项。
  static const String sameKeyBothSides = 'same_key_both_sides';

  /// 公钥与 agentId 不配套（需要调用方提供 id→pub 的权威来源才可判）。
  static const String initiatorIdPubMismatch = 'initiator_id_pub_mismatch';
  static const String counterpartyIdPubMismatch = 'counterparty_id_pub_mismatch';

  static const String missingCounterpartyPub = 'missing_counterparty_pub';
  static const String missingCounterpartySig = 'missing_counterparty_sig';
  static const String badCounterpartySig = 'bad_counterparty_sig';
  static const String badOutcomeCode = 'bad_outcome_code';
  static const String outcomeByNotParty = 'outcome_by_not_party';
  static const String missingOutcomeSig = 'missing_outcome_sig';
  static const String badOutcomeSig = 'bad_outcome_sig';
  static const String missingAckSig = 'missing_ack_sig';
  static const String badAckSig = 'bad_ack_sig';
  static const String ackByWrongParty = 'ack_by_wrong_party';
}

// ---------------------------------------------------------------------------
// 记录本体
// ---------------------------------------------------------------------------

/// 一次跨圈互介的**互签记录**。
///
/// 三个字段组按时间顺序填充，每一组都带自己的签名：
/// ① 发起（必填）→ ② 双方同意（可选，但**只有它让互介在可验证意义上成立**）
/// → ③ 结果 + 对端追认（可选）。
class IntroAttestation {
  /// 稳定主键：由（发起方 / 对端 / 发起时刻）确定性导出 ——
  /// 两端从同一份首段内容算出**同一个 id**，天然幂等，不需要中心分配。
  final String id;

  final String initiatorId;
  final String counterpartyId;

  /// 互介出处：我的圈（M5「房间是圈的载体」要求边与卡都有圈归属）。
  final String circleId;

  /// 因哪个房间而结识（空串 = 不是从房间认识的，比如通讯录互介）。
  final String roomId;

  /// 一句话主题（"为什么值得认识"）—— 与 M3 互介卡的 `reason` 对齐。
  /// 这是**数据**不是文案：由用户填写，不参与本地化。
  final String topic;

  // ---- ① 发起 ----
  final int initiatedAtMs;
  final String initiatorPub;
  final String initiatorSig;

  // ---- ② 双方同意（同一份 consentCanonical，各签一次）----
  final int? consentedAtMs;
  final String? counterpartyPub;
  final String? counterpartySig;

  // ---- ③ 结果 + 追认 ----
  final String? outcome; // IntroOutcome.*
  final String? outcomeBy; // 主张结果的当事人（必是两端之一）
  final int? resolvedAtMs;
  final String? outcomeSig;

  final int? ackAtMs;
  final String? ackSig;

  const IntroAttestation({
    required this.id,
    required this.initiatorId,
    required this.counterpartyId,
    this.circleId = '',
    this.roomId = '',
    this.topic = '',
    required this.initiatedAtMs,
    required this.initiatorPub,
    required this.initiatorSig,
    this.consentedAtMs,
    this.counterpartyPub,
    this.counterpartySig,
    this.outcome,
    this.outcomeBy,
    this.resolvedAtMs,
    this.outcomeSig,
    this.ackAtMs,
    this.ackSig,
  });

  // ---------------- 推导属性 ----------------

  /// 当前阶段码（[IntroState.*]）。刻意用 `String` 而不是枚举：
  /// 码是**落库与线格式的一部分**，字符串常量改不动已发出的记录。
  String get state {
    if (resolvedAtMs != null) return IntroState.resolved;
    if (consentedAtMs != null) return IntroState.consented;
    return IntroState.proposed;
  }

  /// 两端身份（顺序固定：发起方在前），便于 UI 稳定渲染。
  List<String> get parties => [initiatorId, counterpartyId];

  bool involves(String agentId) =>
      agentId == initiatorId || agentId == counterpartyId;

  /// 我与这次互介的关系（UI 用来显示"我发起 / 我收到"）。
  bool isInitiator(String agentId) => agentId == initiatorId;

  /// 发起方的 `did:wold` —— 由公钥直接导出，**不需要任何注册表**。
  /// 这就是 M6「护照」之所以是"护照"的地方：公钥即身份。
  String get initiatorDid => WoldDid.fromPub(initiatorPub);

  String? get counterpartyDid {
    final pub = counterpartyPub;
    if (pub == null || pub.isEmpty) return null;
    final did = WoldDid.fromPub(pub);
    return WoldDid.isValid(did) ? did : null;
  }

  /// 全部参与者的可验证 DID（去重，仅含公钥合法的）。
  List<String> get dids {
    final out = <String>[];
    for (final p in [initiatorPub, counterpartyPub]) {
      if (p == null || p.isEmpty) continue;
      final did = WoldDid.fromPub(p);
      if (WoldDid.isValid(did) && !out.contains(did)) out.add(did);
    }
    return out;
  }

  /// 这次互介是否因**房间**而产生（M5 的出处可追溯）。
  bool get roomBacked => roomId.trim().isNotEmpty;

  /// §16 透明日志的**叶子字节**（确定性：任何 monitor 都能独立复算）。
  ///
  /// 只纳入**可公开检验**的字段：记录 id、阶段、结果码、双方 `did:wold`。
  /// 刻意**不纳入 `topic`**（那是用户自由文本）—— 日志是公开账本，
  /// 公开账本承载隐私字段等于把"可验证"做成"可围观"。
  /// 需要私密关联方自然持有完整记录（含 topic），日志只负责证明
  /// "这条记录在某期确实存在过、且没被改过"。
  ///
  /// ⚠️ `state` 与 `stage` **两个都要**，少一个就有缺陷（真机用例抓到过）：
  /// `state` 把"已落结果"和"对端已追认"都归为 `resolved`，所以**只放 state**
  /// 会让第 3 步和第 4 步算出**完全相同的叶子** → `appendOnce` 幂等去重 →
  /// **追认这一步在公开日志里不留痕**，与"每推进一步都留痕"的设计承诺不符。
  /// `stage` 是细粒度推进序号（1..4），把这条缝补上。
  List<int> logLeafBytes() => utf8.encode(
      'IA|$id|$state|$stage|${outcome ?? ''}|$initiatorDid|${counterpartyDid ?? ''}');

  /// 已推进到的段数（1=只发起，2=已互允，3=已落结果，4=已追认）。
  /// 用于"只前进不后退"的落库纪律（见 `attestation_store_db.dart`）。
  int get stage {
    if (ackAtMs != null) return 4;
    if (resolvedAtMs != null) return 3;
    if (consentedAtMs != null) return 2;
    return 1;
  }

  // ---------------- 规范串（签名的覆盖对象）----------------
  //
  // 关键设计：**后一段把前一段整串内嵌**。
  // 于是"改前段"必然让后段签名字节变化 → 后段签名失效。
  // 这是"不可回填、不可单方改写"的机制来源，而不是靠约定。

  static String intentCanonical({
    required String id,
    required String initiatorId,
    required String counterpartyId,
    required String circleId,
    required String roomId,
    required String topic,
    required int initiatedAtMs,
  }) =>
      'IA-INTENT|$id|$initiatorId|$counterpartyId|$circleId|$roomId|$topic|$initiatedAtMs';

  /// 由首段内容确定性导出 id（两端算出同一个值 → 幂等，无需中心分配）。
  static Future<String> deriveId({
    required String initiatorId,
    required String counterpartyId,
    required int initiatedAtMs,
  }) async {
    final h = await Sha256().hash(utf8.encode(
        'IA-ID|$initiatorId|$counterpartyId|$initiatedAtMs'));
    return 'ia_${AgentProtocol.base58Encode(h.bytes)}';
  }

  String intentCanonicalStr() => intentCanonical(
        id: id,
        initiatorId: initiatorId,
        counterpartyId: counterpartyId,
        circleId: circleId,
        roomId: roomId,
        topic: topic,
        initiatedAtMs: initiatedAtMs,
      );

  /// 双方签的是**这一份**字节。`consentedAtMs` 为 null 时不可用。
  String consentCanonicalStr() {
    final at = consentedAtMs;
    if (at == null) {
      throw StateError('consent canonical requires consentedAtMs');
    }
    return 'IA-CONSENT|${intentCanonicalStr()}|$at';
  }

  String resolveCanonicalStr() {
    final o = outcome;
    final by = outcomeBy;
    final at = resolvedAtMs;
    if (o == null || by == null || at == null) {
      throw StateError('resolve canonical requires outcome/outcomeBy/resolvedAtMs');
    }
    return 'IA-RESOLVE|${consentCanonicalStr()}|$o|$by|$at';
  }

  String ackCanonicalStr() {
    final at = ackAtMs;
    if (at == null) throw StateError('ack canonical requires ackAtMs');
    return 'IA-ACK|${resolveCanonicalStr()}|$at';
  }

  /// 这张记录在**本地库**里挂到哪几个人身上（用于履历索引）。
  List<String> get indexKeys => [initiatorId, counterpartyId];

  // ---------------- 序列化 ----------------

  Map<String, Object?> toMap() => {
        'id': id,
        'initiator_id': initiatorId,
        'counterparty_id': counterpartyId,
        'circle_id': circleId,
        'room_id': roomId,
        'topic': topic,
        'initiated_at': initiatedAtMs,
        'initiator_pub': initiatorPub,
        'initiator_sig': initiatorSig,
        'consented_at': consentedAtMs,
        'counterparty_pub': counterpartyPub,
        'counterparty_sig': counterpartySig,
        'outcome': outcome,
        'outcome_by': outcomeBy,
        'resolved_at': resolvedAtMs,
        'outcome_sig': outcomeSig,
        'ack_at': ackAtMs,
        'ack_sig': ackSig,
      };

  static IntroAttestation fromMap(Map<String, dynamic> m) => IntroAttestation(
        id: m['id'] as String,
        initiatorId: (m['initiator_id'] ?? '').toString(),
        counterpartyId: (m['counterparty_id'] ?? '').toString(),
        circleId: (m['circle_id'] ?? '').toString(),
        roomId: (m['room_id'] ?? '').toString(),
        topic: (m['topic'] ?? '').toString(),
        initiatedAtMs: (m['initiated_at'] as num?)?.toInt() ?? 0,
        initiatorPub: (m['initiator_pub'] ?? '').toString(),
        initiatorSig: (m['initiator_sig'] ?? '').toString(),
        consentedAtMs: (m['consented_at'] as num?)?.toInt(),
        counterpartyPub: m['counterparty_pub'] as String?,
        counterpartySig: m['counterparty_sig'] as String?,
        outcome: m['outcome'] as String?,
        outcomeBy: m['outcome_by'] as String?,
        resolvedAtMs: (m['resolved_at'] as num?)?.toInt(),
        outcomeSig: m['outcome_sig'] as String?,
        ackAtMs: (m['ack_at'] as num?)?.toInt(),
        ackSig: m['ack_sig'] as String?,
      );

  IntroAttestation copyWith({
    String? id,
    String? circleId,
    String? roomId,
    String? topic,
    int? consentedAtMs,
    String? counterpartyPub,
    String? counterpartySig,
    String? outcome,
    String? outcomeBy,
    int? resolvedAtMs,
    String? outcomeSig,
    int? ackAtMs,
    String? ackSig,
  }) =>
      IntroAttestation(
        id: id ?? this.id,
        initiatorId: initiatorId,
        counterpartyId: counterpartyId,
        circleId: circleId ?? this.circleId,
        roomId: roomId ?? this.roomId,
        topic: topic ?? this.topic,
        initiatedAtMs: initiatedAtMs,
        initiatorPub: initiatorPub,
        initiatorSig: initiatorSig,
        consentedAtMs: consentedAtMs ?? this.consentedAtMs,
        counterpartyPub: counterpartyPub ?? this.counterpartyPub,
        counterpartySig: counterpartySig ?? this.counterpartySig,
        outcome: outcome ?? this.outcome,
        outcomeBy: outcomeBy ?? this.outcomeBy,
        resolvedAtMs: resolvedAtMs ?? this.resolvedAtMs,
        outcomeSig: outcomeSig ?? this.outcomeSig,
        ackAtMs: ackAtMs ?? this.ackAtMs,
        ackSig: ackSig ?? this.ackSig,
      );
}

// ---------------------------------------------------------------------------
// 离线验证
// ---------------------------------------------------------------------------

/// 验证结论：**验过什么、没验过什么、为什么**，全部显式。
///
/// 刻意不做成 `bool`：一个 `bool` 会让"只验过发起签名"和"连结果都双方追认了"
/// 看起来一样，而这两者的可信度天差地别。
class IntroVerifyResult {
  /// 真正验过的等级（[IntroTrust.*]）。
  final String trust;

  /// 通过的检查项（人类可读的短码，便于 UI 列出"已验证 ✓"）。
  final List<String> checks;

  /// 未通过 / 缺失的原因码（[AttestFault.*]）。
  final List<String> faults;

  const IntroVerifyResult({
    required this.trust,
    this.checks = const [],
    this.faults = const [],
  });

  bool get usable => trust != IntroTrust.none;

  /// 至少达到某档（例：`atLeast(IntroTrust.consented)` = 互介在可验证意义上成立）。
  bool atLeast(String level) =>
      IntroTrust.rankOf(trust) >= IntroTrust.rankOf(level);

  /// 直接回答 M6 的核心问题：**这次互介双方都同意了吗**（且可证）。
  bool get mutuallyConsented => atLeast(IntroTrust.consented);

  /// 且结果也是双方共识。
  bool get mutuallyAcknowledged => atLeast(IntroTrust.acknowledged);

  @override
  String toString() =>
      'IntroVerifyResult(trust=$trust, checks=$checks, faults=$faults)';
}

/// 离线验证器：只依赖公钥与记录本身，**不依赖任何服务器或本地库**。
///
/// ## 它能证明什么、不能证明什么（务必分清）
///
/// **能证明**：这条记录由一个**密钥 A** 发起、被一个**与 A 不同**的**密钥 B** 同意，
/// 且双方签的是同一份字节；结果由当事人之一签署，必要时另一方追认。
/// 全程只看公钥，任何人可复算。
///
/// **不能证明**：`initiatorId` 这个"名字"真的属于密钥 A。
/// 公钥↔agentId 的绑定是**外部事实**，离线验证无从判定 ——
/// 除非调用方把权威来源传进来（见 [verify] 的 `pubOfAgent`）。
/// 在本项目里那个权威来源就是 M1 的 `did_issuance` append-only 账本
/// （`DBHelper` 的 `did_issuance` 表：agent_id ↔ pub ↔ 签发签名）。
///
/// 所以本层刻意**不把"验签通过"说成"这个身份就是可信的"**：
/// 它只把可验证的部分验到最实，把不可验证的部分**显式留白**。
class IntroVerifier {
  /// [pubOfAgent] 可选：给出 `agentId → 公钥` 的权威解析（生产＝查 `did_issuance`）。
  /// 传了就额外校验"名字与钥匙配套"，并把结论写进 `checks`；
  /// 不传则只做纯密码学校验（第三方监督者的默认模式，符合 §16）。
  static Future<IntroVerifyResult> verify(
    IntroAttestation a, {
    Future<String?> Function(String agentId)? pubOfAgent,
  }) async {
    final faults = <String>[];
    final checks = <String>[];

    // ---- 0. 结构与形状 ----
    if (a.initiatorId.trim().isEmpty || a.counterpartyId.trim().isEmpty) {
      return const IntroVerifyResult(
          trust: IntroTrust.none, faults: [AttestFault.emptyIds]);
    }
    if (a.initiatorId == a.counterpartyId) {
      // "自己和自己互介"没有任何信息量，且会让"双方同意"退化为单方
      return const IntroVerifyResult(
          trust: IntroTrust.none, faults: [AttestFault.selfIntroduction]);
    }
    if (a.id.trim().isEmpty) {
      faults.add(AttestFault.badId);
    } else {
      // id 必须与内容自洽（否则两端可能对同一次互介持有不同 id → 账本裂开）
      final expected = await IntroAttestation.deriveId(
        initiatorId: a.initiatorId,
        counterpartyId: a.counterpartyId,
        initiatedAtMs: a.initiatedAtMs,
      );
      if (expected != a.id) {
        faults.add(AttestFault.badId);
      } else {
        checks.add('id_derived_from_content');
      }
    }

    // ---- 1. 发起段（必填，不过则整条不可用）----
    if (a.initiatorPub.isEmpty) {
      return IntroVerifyResult(
          trust: IntroTrust.none,
          checks: checks,
          faults: [...faults, AttestFault.missingInitiatorPub]);
    }
    final intentOk = await AgentProtocol.verifyRawSignature(
        utf8.encode(a.intentCanonicalStr()), a.initiatorSig, a.initiatorPub);
    if (!intentOk) {
      return IntroVerifyResult(
          trust: IntroTrust.none,
          checks: checks,
          faults: [...faults, AttestFault.badInitiatorSig]);
    }
    checks.add('initiator_sig_valid');
    var trust = IntroTrust.initiated;

    // ---- 1b. 名字与钥匙的绑定（仅在调用方给了权威来源时才可判）----
    if (pubOfAgent != null) {
      final iPub = await pubOfAgent(a.initiatorId);
      if (iPub == null) {
        faults.add(AttestFault.initiatorIdPubMismatch);
      } else if (iPub != a.initiatorPub) {
        faults.add(AttestFault.initiatorIdPubMismatch);
      } else {
        checks.add('initiator_id_pub_bound');
      }
    }

    // ---- 2. 双方同意段（互介在可验证意义上成立的最小充分条件）----
    final consentedAt = a.consentedAtMs;
    if (consentedAt != null) {
      if (consentedAt < a.initiatedAtMs) {
        faults.add(AttestFault.badTimeOrder);
      } else if (a.counterpartyPub == null || a.counterpartyPub!.isEmpty) {
        faults.add(AttestFault.missingCounterpartyPub);
      } else if (a.counterpartyPub == a.initiatorPub) {
        // 🔴 同一把钥匙演双方 —— 见 [AttestFault.sameKeyBothSides]
        faults.add(AttestFault.sameKeyBothSides);
      } else if (a.counterpartySig == null || a.counterpartySig!.isEmpty) {
        faults.add(AttestFault.missingCounterpartySig);
      } else {
        final cOk = await AgentProtocol.verifyRawSignature(
            utf8.encode(a.consentCanonicalStr()),
            a.counterpartySig!,
            a.counterpartyPub!);
        if (!cOk) {
          faults.add(AttestFault.badCounterpartySig);
        } else {
          if (pubOfAgent != null) {
            final cPub = await pubOfAgent(a.counterpartyId);
            if (cPub == null || cPub != a.counterpartyPub) {
              faults.add(AttestFault.counterpartyIdPubMismatch);
            } else {
              checks.add('counterparty_id_pub_bound');
            }
          }
          // 两把**不同密钥**的签名作用于同一份字节 → 互介在可验证意义上成立
          checks.add('mutual_consent_valid');
          checks.add('distinct_keys');
          trust = IntroTrust.consented;
        }
      }
    }

    // ---- 3. 结果段 ----
    final resolvedAt = a.resolvedAtMs;
    if (resolvedAt != null) {
      if (consentedAt == null) {
        // 没有同意就没有"结果"可言：proposed → 直接到结果，中间那段是空的
        faults.add(AttestFault.badTimeOrder);
      } else if (resolvedAt < consentedAt) {
        faults.add(AttestFault.badTimeOrder);
      } else if (a.outcome == null || !IntroOutcome.all.contains(a.outcome)) {
        faults.add(AttestFault.badOutcomeCode);
      } else if (a.outcomeBy == null || !a.parties.contains(a.outcomeBy)) {
        // 结果必须由**当事人**主张，不能由第三方代填
        faults.add(AttestFault.outcomeByNotParty);
      } else if (a.outcomeSig == null || a.outcomeSig!.isEmpty) {
        faults.add(AttestFault.missingOutcomeSig);
      } else {
        final oPub = a.outcomeBy == a.initiatorId
            ? a.initiatorPub
            : a.counterpartyPub;
        final oOk = oPub != null &&
            oPub.isNotEmpty &&
            await AgentProtocol.verifyRawSignature(
                utf8.encode(a.resolveCanonicalStr()), a.outcomeSig!, oPub);
        if (!oOk) {
          faults.add(AttestFault.badOutcomeSig);
        } else {
          checks.add('outcome_sig_valid');
          if (trust == IntroTrust.consented) trust = IntroTrust.resolved;
        }
      }
    }

    // ---- 4. 对端追认（把"结果"从单方主张升级为双方共识）----
    final ackAt = a.ackAtMs;
    if (ackAt != null) {
      if (resolvedAt == null) {
        faults.add(AttestFault.badTimeOrder);
      } else if (ackAt < resolvedAt) {
        faults.add(AttestFault.badTimeOrder);
      } else if (a.ackSig == null || a.ackSig!.isEmpty) {
        faults.add(AttestFault.missingAckSig);
      } else {
        // 追认方必须是**没主张结果的那一方**（自己追认自己毫无意义，
        // 而且那会让"双方确认"退化成同一个人的两次签名）
        final acker =
            a.outcomeBy == a.initiatorId ? a.counterpartyId : a.initiatorId;
        final aPub =
            acker == a.initiatorId ? a.initiatorPub : a.counterpartyPub;
        final ackOk = aPub != null &&
            aPub.isNotEmpty &&
            await AgentProtocol.verifyRawSignature(
                utf8.encode(a.ackCanonicalStr()), a.ackSig!, aPub);
        if (!ackOk) {
          faults.add(AttestFault.badAckSig);
        } else if (trust != IntroTrust.resolved) {
          // 追认是在"结果"之上的，如果结果那一段本身没验过，追认也立不住
          faults.add(AttestFault.badAckSig);
        } else {
          checks.add('counterparty_ack_valid');
          trust = IntroTrust.acknowledged;
        }
      }
    }

    return IntroVerifyResult(trust: trust, checks: checks, faults: faults);
  }
}

// ---------------------------------------------------------------------------
// 转化率漏斗（PRD §4.0 链路 β 的指标：**互介→握手转化率**）
// ---------------------------------------------------------------------------

/// 互介漏斗。**分子分母全部显式**，不合成一个漂亮的单一比值。
class IntroFunnel {
  /// 全部记录数（＝发起过的互介数）。
  final int proposed;

  /// 双方都签过（互介在可验证意义上成立）。
  final int consented;

  final int handshake;
  final int declined;
  final int noResponse;
  final int withdrawn;

  const IntroFunnel({
    this.proposed = 0,
    this.consented = 0,
    this.handshake = 0,
    this.declined = 0,
    this.noResponse = 0,
    this.withdrawn = 0,
  });

  /// 互介成立但还没落结果（在途）—— **必须单独列出**，
  /// 否则在途记录会被当成"失败"压低转化率。
  int get inFlight => consented - handshake - declined - noResponse - withdrawn;

  /// 已落结果的条数（转化的诚实分母）。
  int get settled => handshake + declined + noResponse + withdrawn;

  /// 双方同意率 ＝ consented / proposed。
  double get consentRate => proposed == 0 ? 0 : consented / proposed;

  /// **互介→握手转化率**（PRD 原指标）：分母只用**已落结果**的条数，
  /// 排除在途；同时 [handshakeOverConsented] 给出含在途的保守口径。
  double get handshakeConversion => settled == 0 ? 0 : handshake / settled;

  /// 保守口径：分母用全部已互介成立的条数（在途算未成功）。
  double get handshakeOverConsented =>
      consented == 0 ? 0 : handshake / consented;

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  double get consentRate2 => _round2(consentRate);
  double get handshakeConversion2 => _round2(handshakeConversion);
  double get handshakeOverConsented2 => _round2(handshakeOverConsented);
}

// ---------------------------------------------------------------------------
// 存储抽象（生产实现见 attestation_store_db.dart）
// ---------------------------------------------------------------------------

abstract class AttestationStore {
  /// 幂等写入（PK = `id`，由内容确定性导出）。
  Future<void> upsert(IntroAttestation a);

  Future<IntroAttestation?> byId(String id);

  /// 与我有关的全部记录（我是发起方或对端），按发起时刻倒序。
  Future<List<IntroAttestation>> involving(String agentId);
}

/// 落库纪律：**只前进，不后退**（所有 [AttestationStore] 实现必须共用这一条）。
///
/// 为什么这条不能各写各的：记录是分段推进的（发起→互允→结果→追认），
/// 每次推进写同一行。若允许低阶段覆盖高阶段，一个**只签了"发起"的旧报文**
/// 被重放一次，就能把一条已经双方互允的记录打回"未同意"。
/// 记录被**回滚**比被篡改更隐蔽 —— 篡改会留下验签失败，回滚看起来一切正常。
///
/// 抽成顶层纯函数（而不是写在 SQL 里）的理由：口径只能有一份，
/// 且必须能被离线复算/断言（见 `tool/verify_attestation_persistence.dart`）。
bool shouldAcceptUpsert(IntroAttestation? existing, IntroAttestation incoming) =>
    existing == null || incoming.stage >= existing.stage;

class MemoryAttestationStore implements AttestationStore {
  final Map<String, IntroAttestation> _rows = {};

  @override
  Future<void> upsert(IntroAttestation a) async {
    // 内存实现也必须遵守同一条纪律，否则"测试通过、生产回滚"。
    if (!shouldAcceptUpsert(_rows[a.id], a)) return;
    _rows[a.id] = a;
  }

  @override
  Future<IntroAttestation?> byId(String id) async => _rows[id];

  @override
  Future<List<IntroAttestation>> involving(String agentId) async =>
      _rows.values.where((a) => a.involves(agentId)).toList()
        ..sort((a, b) => b.initiatedAtMs.compareTo(a.initiatedAtMs));
}

// ---------------------------------------------------------------------------
// 服务：三段式签署 + 漏斗统计
// ---------------------------------------------------------------------------

class AttestationService {
  final AttestationStore store;
  final Signer signer;

  /// 我方分身 ID（签署时校验"这一步该由谁签"）。
  final Future<String> Function() selfId;

  final void Function(String name, Map<String, Object?> props)? onEvent;

  /// 每推进一步（发起 / 同意 / 结果 / 追认）后的回调 —— §16 透明日志的**唯一挂点**。
  ///
  /// 做成注入式而不是在服务里直连日志，是为了让本文件保持零平台依赖：
  /// 生产装配（`wold_runtime.dart`）把它接到数据库日志上；
  /// 验证脚本里接一个内存列表，就能断言"每一步都留痕"。
  ///
  /// ⚠️ 它必须**在签名落库之后**触发：日志叶子取自**已签名的记录**，
  /// 若提前触发，记进公开账本的会是"还没有签名的自称" —— 那就白记了。
  final Future<void> Function(IntroAttestation a)? onAdvance;

  AttestationService({
    required this.store,
    required this.signer,
    required this.selfId,
    this.onEvent,
    this.onAdvance,
  });

  // ---------------- ① 发起 ----------------

  /// 发起一次互介并签下"我想认识他"。
  ///
  /// `nowMs` 可注入 —— 同样的输入必须得到同样的 id，否则验证无法复算。
  Future<IntroAttestation> propose({
    required String counterpartyId,
    required String circleId,
    String roomId = '',
    String topic = '',
    int? nowMs,
  }) async {
    final me = await selfId();
    final at = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final id = await IntroAttestation.deriveId(
        initiatorId: me, counterpartyId: counterpartyId, initiatedAtMs: at);
    final pub = await signer.publicKeyBase58();
    final canonical = IntroAttestation.intentCanonical(
      id: id,
      initiatorId: me,
      counterpartyId: counterpartyId,
      circleId: circleId,
      roomId: roomId,
      topic: topic,
      initiatedAtMs: at,
    );
    final sig = await signer.signBytes(utf8.encode(canonical));
    final a = IntroAttestation(
      id: id,
      initiatorId: me,
      counterpartyId: counterpartyId,
      circleId: circleId,
      roomId: roomId,
      topic: topic,
      initiatedAtMs: at,
      initiatorPub: pub,
      initiatorSig: sig,
    );
    await store.upsert(a);
    await onAdvance?.call(a);
    onEvent?.call('intro_proposed', {
      'self': me,
      'peer': counterpartyId,
      'intro_id': id,
      'room_id': roomId,
      'circle_id': circleId,
    });
    return a;
  }

  // ---------------- ② 双方同意 ----------------

  /// **对端**签下同意。只有被指名的那一方能签（否则返回 null）。
  ///
  /// 注意它签的是 [IntroAttestation.consentCanonicalStr] —— 与发起方
  /// **不是**同一份字节：发起方签的是"我想认识他"，对端签的是"我同意"，
  /// 而后者把前者整串内嵌了进去。两份签名合起来才构成"双方同意"。
  Future<IntroAttestation?> consent(IntroAttestation a, {int? nowMs}) async {
    final me = await selfId();
    if (me != a.counterpartyId) return null; // 只有对端能同意
    if (a.consentedAtMs != null) return a; // 幂等
    final at = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final staged = a.copyWith(consentedAtMs: at);
    final pub = await signer.publicKeyBase58();
    // 兜底：同一把钥匙不能既发起又同意（否则"双方同意"退化成一个签名）
    if (pub == a.initiatorPub) return null;
    final sig = await signer.signBytes(utf8.encode(staged.consentCanonicalStr()));
    final out = staged.copyWith(counterpartyPub: pub, counterpartySig: sig);
    await store.upsert(out);
    await onAdvance?.call(out);
    onEvent?.call('intro_consented', {
      'self': me,
      'peer': a.initiatorId,
      'intro_id': a.id,
      'room_id': a.roomId,
    });
    return out;
  }

  // ---------------- ③ 结果 ----------------

  /// 记录结果。`byId` 必须是当事人；只有在**已双方同意**之后才允许落结果
  /// （没有同意的"结果"是无源之水，见 [IntroVerifier] 的 fail-closed 规则）。
  Future<IntroAttestation?> resolve(
    IntroAttestation a, {
    required String outcome,
    int? nowMs,
  }) async {
    final me = await selfId();
    if (!a.involves(me)) return null;
    if (a.consentedAtMs == null) return null;
    if (a.resolvedAtMs != null) return a; // 幂等：结果一旦落定不再改写
    if (!IntroOutcome.all.contains(outcome)) return null;
    final at = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (at < a.consentedAtMs!) return null; // 时序不可倒流
    final staged = a.copyWith(outcome: outcome, outcomeBy: me, resolvedAtMs: at);
    final sig = await signer.signBytes(utf8.encode(staged.resolveCanonicalStr()));
    final out = staged.copyWith(outcomeSig: sig);
    await store.upsert(out);
    await onAdvance?.call(out);
    onEvent?.call('intro_resolved', {
      'self': me,
      'peer': a.isInitiator(me) ? a.counterpartyId : a.initiatorId,
      'intro_id': a.id,
      'outcome': outcome,
    });
    return out;
  }

  /// 对端追认结果（把"单方主张"升级为"双方共识"）。
  Future<IntroAttestation?> acknowledge(
    IntroAttestation a, {
    int? nowMs,
  }) async {
    final me = await selfId();
    if (!a.involves(me)) return null;
    if (a.resolvedAtMs == null) return null;
    if (a.outcomeBy == me) return null; // 主张结果的人不能自己追认自己
    if (a.ackAtMs != null) return a; // 幂等
    final at = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (at < a.resolvedAtMs!) return null;
    final staged = a.copyWith(ackAtMs: at);
    final sig = await signer.signBytes(utf8.encode(staged.ackCanonicalStr()));
    final out = staged.copyWith(ackSig: sig);
    await store.upsert(out);
    await onAdvance?.call(out);
    onEvent?.call('intro_acknowledged', {
      'self': me,
      'peer': a.isInitiator(me) ? a.counterpartyId : a.initiatorId,
      'intro_id': a.id,
    });
    return out;
  }

  // ---------------- 查询 ----------------

  /// 我的履历（原始记录，未验证）。**UI 必须对每条跑一次 [IntroVerifier.verify]
  /// 再显示等级** —— 直接显示记录里的 `outcome` 字段等于信任自称。
  Future<List<IntroAttestation>> myLedger({int? limit}) async {
    final me = await selfId();
    final rows = await store.involving(me);
    return limit == null || rows.length <= limit ? rows : rows.sublist(0, limit);
  }

  /// 我的履历 + 逐条验证结论（UI 直接可用）。
  Future<List<(IntroAttestation, IntroVerifyResult)>> myVerifiedLedger({
    int? limit,
  }) async {
    final rows = await myLedger(limit: limit);
    final out = <(IntroAttestation, IntroVerifyResult)>[];
    for (final a in rows) {
      out.add((a, await IntroVerifier.verify(a)));
    }
    return out;
  }

  /// 我的互介漏斗。
  ///
  /// 口径诚实性说明：**只统计"验证过双方同意"的记录**参与转化的分子分母 ——
  /// 一条自称握手的记录若连双方同意都验不过，它不该被算进任何漂亮的比率里。
  ///
  /// ⚠️ **前置条件（容易漏，漏了数字就是错的）**：对端的同意必须已经回到
  /// 我方账本。对本机来说，这意味着入站拦截把 `update` 报文的记录写进了 store
  /// （`IntroRelay.dispatchUpdate` 的对应动作）。若只签名不回传，
  /// 我方手里的记录缺对端签名 → 验不过 → 这一条永远不进分母。
  Future<IntroFunnel> myFunnel() async {
    final rows = await myLedger();
    var proposed = 0, consented = 0, hs = 0, dec = 0, nr = 0, wd = 0;
    for (final a in rows) {
      proposed++;
      final v = await IntroVerifier.verify(a);
      if (!v.mutuallyConsented) continue; // ← 没验过就不进分母
      consented++;
      switch (a.outcome) {
        case IntroOutcome.handshake:
          hs++;
        case IntroOutcome.declined:
          dec++;
        case IntroOutcome.noResponse:
          nr++;
        case IntroOutcome.withdrawn:
          wd++;
      }
    }
    return IntroFunnel(
      proposed: proposed,
      consented: consented,
      handshake: hs,
      declined: dec,
      noResponse: nr,
      withdrawn: wd,
    );
  }
}

// ---------------------------------------------------------------------------
// 线格式（与 M2/M3 同款：验签 fail-closed、不代客决策）
// ---------------------------------------------------------------------------

/// 互介记录在普通消息通道里的封装。
///
/// 两种报文：`proposal`（带发起签名，对方据此决定同不同意）
/// 与 `update`（带同意/结果/追认之后的最新记录，让对方同步状态）。
class IntroWire {
  static const String type = 'intro_attestation';
  static const int version = 1;
  static const int maxWireChars = 8 * 1024;

  static String encodeProposal(IntroAttestation a) => jsonEncode({
        'da_type': type,
        'v': version,
        'kind': 'proposal',
        'a': a.toMap(),
      });

  static String encodeUpdate(IntroAttestation a) => jsonEncode({
        'da_type': type,
        'v': version,
        'kind': 'update',
        'a': a.toMap(),
      });

  static bool isIntro(String text) {
    final t = text.trim();
    if (t.length > maxWireChars) return false;
    if (!t.startsWith('{') || !t.endsWith('}')) return false;
    try {
      final m = jsonDecode(t);
      return m is Map && m['da_type'] == type;
    } catch (_) {
      return false;
    }
  }

  /// 返回记录本体；**解析即验收**：形状不对、或发起签名都验不过的，直接拒收。
  static Future<(String kind, IntroAttestation)?> tryParse(String text) async {
    final t = text.trim();
    if (t.length > maxWireChars) return null;
    if (!t.startsWith('{') || !t.endsWith('}')) return null;
    try {
      final m = jsonDecode(t);
      if (m is! Map || m['da_type'] != type) return null;
      if ((m['v'] as num?)?.toInt() != version) return null;
      final kind = m['kind'];
      if (kind != 'proposal' && kind != 'update') return null;
      final raw = m['a'];
      if (raw is! Map) return null;
      final a = IntroAttestation.fromMap(Map<String, dynamic>.from(raw));
      // 最小可用性：发起段必须立得住，否则不该进库（fail-closed）
      final v = await IntroVerifier.verify(a);
      if (!v.usable) return null;
      return (kind as String, a);
    } catch (_) {
      return null;
    }
  }
}

/// 出站通道抽象（与 M2 委托 / M3 互介卡同一签名，可共用同一个 outbound）。
typedef IntroSender = Future<bool> Function(String targetAgentId, String wire);

/// 投递：只投**已是有效签名状态**的记录（与 M3 的"未确认卡不发出"同款纪律）。
class IntroRelay {
  final IntroSender send;

  /// 入站落库目标。可为空 —— 只做投递的轻量用法不需要它。
  final AttestationStore? store;

  /// 我方分身 ID（入站时判"报文是不是发给我的"）。
  final Future<String> Function()? selfId;

  final void Function(String name, Map<String, Object?> props)? onEvent;

  /// 入站落库后的推进回调（生产接 §16 透明日志）。
  final Future<void> Function(IntroAttestation a)? onAdvance;

  IntroRelay({
    required this.send,
    this.store,
    this.selfId,
    this.onEvent,
    this.onAdvance,
  });

  /// 把 proposal 投给对端，请它决定是否同意。
  Future<bool> dispatchProposal(IntroAttestation a) =>
      send(a.counterpartyId, IntroWire.encodeProposal(a));

  /// 把更新后的状态同步给 [toId]（同意 / 结果 / 追认三种都走这条）。
  Future<bool> dispatchUpdate(IntroAttestation a, {required String toId}) =>
      send(toId, IntroWire.encodeUpdate(a));

  /// 入站：解析（**解析即验收**，含发起签名验签）→ 路由校验 → 落库。
  ///
  /// 返回 **true = "这是互介报文，已被消费"**（调用方不得再送进聊天流水线）；
  /// 返回 false = 不是互介报文。**验签/路由失败也返回 true**（已消费并丢弃）——
  /// 否则一条伪造报文会被当成普通聊天消息丢给大模型。
  ///
  /// ⚠️ **本方法绝不同意、绝不落结果**：收到 `proposal` 只落库 + 通知 UI，
  /// 是否同意由**用户**决定（PRD：不代客决策）。若这里自动同意，
  /// "双方同意"这条最关键的证据就退化成一句自说自话 —— 与 M1 的双向签名同理。
  Future<bool> onIncoming(String fromAgentId, String text) async {
    // 先用廉价形状检查把"根本不是我们家的报文"放行给别的处理器。
    if (!IntroWire.isIntro(text)) return false;

    final parsed = await IntroWire.tryParse(text);
    final me = selfId == null ? null : await selfId!();

    void drop(String reason, {String? introId}) =>
        onEvent?.call('intro_dropped', {
          'self': me ?? '',
          'peer': fromAgentId,
          if (introId != null) 'intro_id': introId,
          'reason': reason,
        });

    if (parsed == null) {
      // 形状像互介报文，但连发起签名都立不住 → 消费并丢弃（fail-closed）
      drop('unverifiable');
      return true;
    }
    final kind = parsed.$1;
    final a = parsed.$2;

    // ---- 路由校验：报文当事人必须自洽，且"我方必须是另一方" ----
    if (!a.involves(fromAgentId)) {
      drop('sender_not_party', introId: a.id);
      return true;
    }
    if (me != null && !a.involves(me)) {
      drop('misrouted', introId: a.id); // 发给别人的记录，不该进我的账本
      return true;
    }
    if (me != null && fromAgentId == me) {
      drop('self_echo', introId: a.id); // 自己发给自己的回环，丢弃
      return true;
    }
    // proposal 只能由发起方送来（对端无法提交"别人的发起段"）
    if (kind == 'proposal' && a.initiatorId != fromAgentId) {
      drop('sender_mismatch', introId: a.id);
      return true;
    }

    final st = store;
    if (st == null) return true; // 无库（纯投递用法）：消费但不上账

    // ---- 只前进不后退：低阶段报文不得覆盖本地更高阶段的记录 ----
    // 否则一个只签了"发起"的旧报文重放一次，就能把已互允的记录打回原形。
    final existing = await st.byId(a.id);
    if (existing != null && a.stage < existing.stage) {
      drop('stale_stage', introId: a.id);
      return true;
    }

    await st.upsert(a);
    await onAdvance?.call(a);
    onEvent?.call(kind == 'proposal' ? 'intro_received' : 'intro_updated', {
      'self': me ?? '',
      'peer': fromAgentId,
      'intro_id': a.id,
      'stage': a.stage,
    });
    return true;
  }
}
