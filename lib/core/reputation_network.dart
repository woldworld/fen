/// M6 · **网络级信誉**（PRD §4 M6 的收尾件）：签名背书 + 可验证的信任传播。
///
/// ---------------------------------------------------------------------------
/// 先说清楚本模块**刻意不做**什么
/// ---------------------------------------------------------------------------
/// **不做全局信誉分。**
/// `reputation_service.dart` 里已经写明理由：自报的全局分天然可刷 —— 注册一堆小号
/// 互送好评即可。所有"全网统一信誉分"的方案都倒在这一条上，本模块不重复这个错误。
///
/// 本模块做的是 **EigenTrust 风格的局部信任**：
/// ① 你先有一小撮**自己认定的锚点**（anchors，权重来自你的本地主观信誉）；
/// ② 别人签发的**背书**（Endorsement，Ed25519 签名）是可验证的**边**；
/// ③ 从你的锚点出发，沿边做**衰减传播**，得到"**对你而言**这个陌生人有多可信"。
///
/// 同一个陌生人，在你眼里和在别人眼里**答案不同** —— 这不是缺陷，这正是它抗刷的原因：
/// 刷分者必须逐个攻破每个观察者的锚点，而不是攻破一个全局数据库。
///
/// ---------------------------------------------------------------------------
/// 五条铁律（本层强制，全部可离线复算）
/// ---------------------------------------------------------------------------
/// 1. **无锚点即不可知（fail-closed）**：没有从锚点出发的通路 → 返回 `unknown`，
///    **不是 0 也不是 50**。0 会被读成"坏人"、50 会被读成"普通人"，两者都是谎言；
///    "我不知道"才是诚实的答案。
/// 2. **只取最优路径，绝不累加**：到达同一终点只保留**权重最大的一条**链。
///    若改成累加，造 100 条中继路径就能刷到满分 —— 这是整个模块最容易写错的一行。
/// 3. **自证无效**：`issuerPub == subjectPub` 的背书一律不采信（自己给自己背书）。
/// 4. **信任会过期**：背书有 `expires_at`。不设过期 = 永不回收的信任，
///    与 M8 的 `quotaValidDays` 同理 —— 敞口必须有终点。
/// 5. **网络背书永远达不到 family**：一跳衰减后置信度**结构上**到不了 family 档
///    （见 [ReputationCaps.attenuation] 的推导）。family 是"我自己认定的家人"，
///    只能由本人给出，不能由网络替你认定。
///
/// ---------------------------------------------------------------------------
/// 为什么用**公钥**而不是 Agent ID 做背书主体
/// ---------------------------------------------------------------------------
/// Agent ID 是**平台发的名字**，可被重发、可被换绑；Ed25519 公钥才是**身份根**。
/// 若用 ID 做主体，换一次 ID 就能甩掉全部差评（"信誉洗白"）。
/// 这一条同时呼应 PRD 的监护身份设计：网络节点数 = 真实人数，信誉才有归属。
///
/// 本文件**零平台依赖**（不 import `flutter` / `sqflite` / `shared_preferences`；
/// 只用 `dart:convert` + `agent_protocol` + `ed25519_sig`），
/// 因此 `dart run tool/verify_reputation_network.dart` 可直接复算全部判定。
library;

import 'dart:convert';

// 验签**不自己实现**：与 M9 技能签名共用 `Ed25519Sig` 同一份实现。
// 两处各写一份必然漂移，而漂移的形态是"一边拒的假签名另一边却收了"。
import 'ed25519_sig.dart' show Ed25519Sig;

/// 信誉档位。
///
/// ⚠️ 取值必须与 `reputation_service.dart` 的 tier 字面量保持一致
/// （`stranger` / `friend` / `family`）—— 两边同名不同值时，UI 会静默错档。
/// `verify_reputation_network` 有源码级断言盯着这件事。
abstract final class ReputationTier {
  static const String stranger = 'stranger';
  static const String acquaintance = 'acquaintance';
  static const String friend = 'friend';
  static const String family = 'family';

  /// 可**作为背书内容**声明的档位：`stranger` 不在此列 ——
  /// "我背书他是个陌生人"是无意义的边，收下它只会给图增加噪音。
  static const List<String> endorsable = [acquaintance, friend, family];

  /// 全部合法档位（用于输出与反序列化校验）。
  static const List<String> values = [stranger, acquaintance, friend, family];

  static bool isValid(String v) => values.contains(v);
  static bool isEndorsable(String v) => endorsable.contains(v);

  /// 档位 → 边权（0..1）。传播时与衰减因子相乘。
  ///
  /// 三档刻意拉开距离：让"泛泛之交"与"朋友"在网络图里**真的不一样重**，
  /// 而不是靠签名者的自觉去区分。
  static double weightOf(String tier) => switch (tier) {
        family => 1.0,
        friend => 0.75,
        acquaintance => 0.5,
        _ => 0.0,
      };
}

/// 背书/传播的参数。**全部是编译期常量**，理由与 M8 的 `TrialCaps` 相同：
/// 这些数字就是抗刷能力的全部来源，做成配置就等于把防线交给了运营。
abstract final class ReputationCaps {
  /// 最大传播深度（跳数）。
  ///
  /// 为什么是 2：1 跳只看直接关系（那还不如用本地分），3 跳以上信任已衰减到
  /// 与噪音同量级，且组合爆炸。**超过 2 跳的"朋友的朋友的朋友"不采信。**
  static const int maxDepth = 2;

  /// 每跳衰减因子。
  ///
  /// ★ 这个数字推导出铁律 5：一跳后最高置信 = `anchorWeight × 0.6 × 1.0 ≤ 0.6`，
  ///   而 `family` 档要求 `≥ 0.6`（见 [ReputationGraph.tierFromConfidence]）。
  ///   由于锚点权重上限是 1.0 且必须严格小于它才有意义，
  ///   **任何网络背书都不可能把陌生人抬到 family** ——
  ///   "家人"只能由本人认定，网络替不了你做这个判断。这不是策略，是算术。
  static const double attenuation = 0.6;

  /// 传播中的剪枝阈值：权重低于此值不再往外传（防图被稀释成一片噪音）。
  static const double minWeight = 0.05;

  /// 判定"已知"的最低置信度。低于此值一律 `unknown`（铁律 1）。
  static const double minConfidence = 0.10;

  /// 锚点权重的**上限**。
  ///
  /// ★ 这个常量是铁律 5 的另一半：锚点权重是**主观信任**，
  ///   而"100% 信任"等于放弃判断 —— 那不是信任，是盲从。所以上限取 0.95。
  ///   于是网络背书的理论最高置信 = `0.95 × 0.6 × 1.0 = 0.57 < 0.60(familyFloor)`，
  ///   **family 档在网络路径上结构性地取不到**。
  static const double maxAnchorWeight = 0.95;

  /// 置信度 → 档位的阈值（[ReputationGraph.tierFromConfidence]）。
  static const double familyFloor = 0.60;
  static const double friendFloor = 0.35;
  static const double acquaintanceFloor = 0.15;

  /// 背书附言长度上限（超出即拒，不截断 —— 截断会产生"半截意思"）。
  static const int maxNoteChars = 140;

  /// 背书有效期（天）。过期即失效（铁律 4）。
  static const int endorsementValidDays = 365;

  /// **成为锚点的最低本地信誉分**。
  ///
  /// 为什么要有门槛：泛泛之交（本地分 50 是**默认值**，不代表任何观察）
  /// 不该成为信任传播的起点 —— 否则"我加了一堆人"就等于"我的信任网络很大"，
  /// 而这正是刷分者最省力的一条路：**批量加好友即可放大自己的传播能力**。
  /// 60 分大致对应"真的打过交道、且没出过负面事件"。
  static const int minAnchorScore = 60;
}

/// 判定/结果码（UI 侧翻译成文案）。
abstract final class EndorseCode {
  static const String ok = 'ok';

  /// 必填字段缺失（issuer_pub / subject_pub / tier / sig）。
  static const String missingFields = 'missing_fields';

  /// 公钥不是合法的 32 字节 Ed25519 公钥。
  static const String badPubkey = 'bad_pubkey';

  /// 档位非法（含"背书 stranger"这种无意义的边）。
  static const String badTier = 'bad_tier';

  /// 附言超长。
  static const String noteTooLong = 'note_too_long';

  /// Ed25519 验签失败 —— 背书被改过（改档位、改主体、改时间都会落到这里）。
  static const String badSignature = 'bad_signature';

  /// **自己给自己背书**（铁律 3）。
  static const String selfEndorsement = 'self_endorsement';

  /// 已过期（铁律 4）。
  static const String expired = 'expired';

  /// 已被签发人吊销。
  static const String revoked = 'revoked';

  /// 时间区间非法（issued_at <= 0，或 expires_at 早于 issued_at）。
  static const String badWindow = 'bad_window';

  /// 与该主体之间**没有任何从锚点出发的通路**（铁律 1，诚实的"不知道"）。
  static const String unknown = 'unknown';

  /// ★★ **这条记录的主体不是我** —— 拉取时的归属闸（外部审计 P2③ 修复引入）。
  ///
  /// 与其余码的分工必须说清：`badSignature` 证明的是"**这份背书确实由它自称的
  /// issuer 签过、且一个字节没被改**"，它**完全没有说"被背书的人是我"**。
  /// 于是一个被篡改的 / 有 bug 的 Hub 可以回一批 `subject_pub = 别人` 的**合法签名**
  /// 记录：逐条验签**全过**（它们本来就是真的），然后被原样落进我的本地库 ——
  /// 我的履历里混进别人的背书，而我此后会拿这份库当"我看到的世界"。
  /// 归属**只能由本机自己算**（当前钥 ∪ 本地退休记录 ∪ 本地验过的换钥链），
  /// 不能采信 Hub 回包里的任何一句结论。
  static const String notMine = 'not_mine';
}

/// 一份**签名背书**：签发人用私钥声明"我认为这个公钥的主体是我的 X 档"。
///
/// 签名覆盖**全部字段**（含两个公钥、档位、时间窗、附言）——
/// 因此"事后改档位""事后换主体""事后延长有效期"都必然让签名失效。
class Endorsement {
  /// 签发人 Ed25519 公钥（base58）。**签名必须由它对应的私钥产生。**
  final String issuerPub;

  /// 被背书人 Ed25519 公钥（base58）。用公钥而非 Agent ID，理由见文件头。
  final String subjectPub;

  /// 档位（[ReputationTier.endorsable] 之一）。
  final String tier;

  final int issuedAtMs;
  final int expiresAtMs;

  /// 附言（可选，≤ [ReputationCaps.maxNoteChars] 字符）。
  final String note;

  /// Ed25519 签名（base64），覆盖 [canonicalBytes]。
  final String sig;

  const Endorsement({
    required this.issuerPub,
    required this.subjectPub,
    required this.tier,
    required this.issuedAtMs,
    required this.expiresAtMs,
    this.note = '',
    this.sig = '',
  });

  /// 落库/吊销/查重键：`issuer|subject`。
  String get key => '$issuerPub|$subjectPub';

  bool expiredAt(int nowMs) => nowMs > expiresAtMs;

  /// **确定性签名载荷**（JSON，键序固定）。
  ///
  /// `alg` 与 `kind` 必须入载荷：前者挡"算法混淆"，后者挡
  /// "拿一份合法的**吊销**声明当作**背书**去验"（两者字段高度相似）。
  String canonical() => jsonEncode({
        'alg': Ed25519Sig.alg,
        'kind': 'endorsement',
        'issuer_pub': issuerPub,
        'subject_pub': subjectPub,
        'tier': tier,
        'issued_at': issuedAtMs,
        'expires_at': expiresAtMs,
        'note': note,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  Endorsement copyWith({String? tier, int? expiresAtMs, String? note, String? sig}) =>
      Endorsement(
        issuerPub: issuerPub,
        subjectPub: subjectPub,
        tier: tier ?? this.tier,
        issuedAtMs: issuedAtMs,
        expiresAtMs: expiresAtMs ?? this.expiresAtMs,
        note: note ?? this.note,
        sig: sig ?? this.sig,
      );

  Map<String, Object?> toMap() => {
        'issuer_pub': issuerPub,
        'subject_pub': subjectPub,
        'tier': tier,
        'issued_at': issuedAtMs,
        'expires_at': expiresAtMs,
        'note': note,
        'sig': sig,
      };

  static Endorsement fromMap(Map<String, dynamic> m) => Endorsement(
        issuerPub: (m['issuer_pub'] as String?) ?? '',
        subjectPub: (m['subject_pub'] as String?) ?? '',
        tier: (m['tier'] as String?) ?? '',
        issuedAtMs: (m['issued_at'] as num?)?.toInt() ?? 0,
        expiresAtMs: (m['expires_at'] as num?)?.toInt() ?? 0,
        note: (m['note'] as String?) ?? '',
        sig: (m['sig'] as String?) ?? '',
      );

  /// 叶子字节：只含公开字段、顺序固定 —— 任何第三方都能独立算出同一个哈希，
  /// 可直接进 §16 只追加日志（与 M8 的 `UsageLedgerEntry.logLeafBytes()` 同款）。
  List<int> logLeafBytes() => utf8.encode(jsonEncode({
        'kind': 'endorsement',
        'issuer_pub': issuerPub,
        'subject_pub': subjectPub,
        'tier': tier,
        'issued_at': issuedAtMs,
        'expires_at': expiresAtMs,
      }));
}

/// 一份**背书吊销声明**：签发人收回此前对某人的背书。
///
/// 吊销只有签发人本人能做（签名公钥必须等于 [Endorsement.issuerPub]），
/// 否则任何人都能清场别人的信誉。
class EndorsementRevocation {
  final String issuerPub;
  final String subjectPub;
  final int atMs;
  final String sig;

  const EndorsementRevocation({
    required this.issuerPub,
    required this.subjectPub,
    required this.atMs,
    this.sig = '',
  });

  String get key => '$issuerPub|$subjectPub';

  String canonical() => jsonEncode({
        'alg': Ed25519Sig.alg,
        'kind': 'endorsement_revocation',
        'issuer_pub': issuerPub,
        'subject_pub': subjectPub,
        'at': atMs,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  Map<String, Object?> toMap() => {
        'issuer_pub': issuerPub,
        'subject_pub': subjectPub,
        'at_ms': atMs,
        'sig': sig,
      };

  static EndorsementRevocation fromMap(Map<String, dynamic> m) =>
      EndorsementRevocation(
        issuerPub: (m['issuer_pub'] as String?) ?? '',
        subjectPub: (m['subject_pub'] as String?) ?? '',
        atMs: (m['at_ms'] as num?)?.toInt() ?? 0,
        sig: (m['sig'] as String?) ?? '',
      );
}

/// 背书签收判定结果。
class EndorseDecision {
  final bool accept;
  final String code; // EndorseCode.*
  final String detail;

  const EndorseDecision({
    required this.accept,
    required this.code,
    this.detail = '',
  });

  /// 幂等：与已有背书逐字段相同（重复提交不写第二遍，也不报错）。
  bool get isDuplicate => accept && code == EndorseCode.ok && detail == 'duplicate';
}

/// **本地主观信誉 → 网络锚点**的桥（纯函数）。
///
/// ---------------------------------------------------------------------------
/// 为什么需要它
/// ---------------------------------------------------------------------------
/// 本地信誉（`reputation_service`）按 **agent_id** 索引（0-100 分，来自我一手往来）；
/// 网络信誉按 **公钥** 索引（公钥才是身份根）。两边索引键不同，
/// 没有这座桥就接不上 —— 于是"从我的名册出发做信任传播"无从下手，
/// 网络背书会永远是一张空表。接缝表是 DB v31 的 `agent_pubkeys`。
///
/// ---------------------------------------------------------------------------
/// 门槛的意义
/// ---------------------------------------------------------------------------
/// **不是名册里的每个人都有资格当锚点。** 泛泛之交（本地分 50 是默认值）
/// 不该成为信任传播的起点 —— 否则"我加了一堆人"就等于"我的信任网络很大"，
/// 而这恰恰是刷分者最省力的一条路（批量加好友即可放大自己的传播能力）。
/// 所以只有本地分 ≥ [ReputationCaps.minAnchorScore] 的人才进锚点集合。
abstract final class ReputationBridge {
  /// 把 (身份 → 本地分) + (身份 → 公钥) 折成 (公钥 → 锚点权重 0..1)。
  ///
  /// - 分数低于门槛的人**不进**锚点（不是权重低，是根本不做起点）；
  /// - 有分数但没有公钥的人也没法进（接不上网络，诚实跳过）；
  /// - 权重 = `score / 100`，上限由 [ReputationCaps.maxAnchorWeight] 在传播时 clamp。
  static Map<String, double> anchorsFrom({
    required Map<String, int> scoreById,
    required Map<String, String> pubById,
  }) {
    final out = <String, double>{};
    for (final entry in scoreById.entries) {
      final score = entry.value;
      if (score < ReputationCaps.minAnchorScore) continue;
      final pub = pubById[entry.key];
      if (pub == null || pub.isEmpty) continue;
      final w = score / 100;
      // 同一把钥匙被多个身份指向时，取最高的那个（不叠加 —— 叠加就是放大）
      final prev = out[pub];
      if (prev == null || w > prev) out[pub] = w;
    }
    return out;
  }
}

/// 网络信誉判定结果。
///
/// 刻意**不输出一个可排序的"分数"**：数字会被拿去排序、会诱导精确刷分，
/// 而且无法自我解释。输出的是**一条可验证的证据链** ——
/// [path] 让"你不必相信我，你可以验我"在 UI 上是**可点开看**的。
class NetworkVerdict {
  /// false = 我不知道（铁律 1）。此时 [confidence] 必为 0、[path] 为空。
  final bool known;

  final String code; // EndorseCode.*

  /// 置信度 0..1（从你的锚点出发、沿最优路径衰减后的权重）。
  final double confidence;

  /// 最浅跳数：0 = 该主体本身就是你的锚点（你直接认识）。
  final int depth;

  /// 建议档位（[ReputationTier.values] 之一）。
  final String tier;

  /// 最优证据链（公钥序列，首元素是锚点、末元素是查询主体）。
  /// 顺着它逐段验签即可独立复算 —— 这是本模块"可验证"的落点。
  final List<String> path;

  /// 到达该主体的**通路条数**（≥1）。用来表达"证据有多厚"；
  /// 注意：**它不影响置信度**（铁律 2：只取最优，不累加）。
  final int paths;

  /// 实际命中的那把公钥。
  ///
  /// 多数时候等于查询的公钥；**身份换过钥**时等于背书真正所在的那把历史公钥
  /// （见 [ReputationGraph.evaluate] 的 `subjectAliases`）。UI 据此可以说清
  /// "履历是按换钥链归并过来的"，而不是让用户猜。
  final String matchedKey;

  const NetworkVerdict({
    required this.known,
    required this.code,
    this.confidence = 0,
    this.depth = 0,
    this.tier = ReputationTier.stranger,
    this.path = const [],
    this.paths = 0,
    this.matchedKey = '',
  });

  bool get isUnknown => !known;
}

/// 网络信誉图（**纯函数**：不落库、不发网络、不读时钟之外的任何外部状态）。
abstract final class ReputationGraph {
  /// 置信度 → 档位。
  ///
  /// 阈值见 [ReputationCaps]。配合 `attenuation = 0.6` 可推出铁律 5：
  /// 一跳传播的上限是 `1.0 × 0.6 × 1.0 = 0.6`，而 [ReputationCaps.familyFloor]
  /// 取 0.60 —— 严格小于它（锚点权重不可能等于 1.0 还叫"主观信任"），
  /// 所以**网络背书永远抬不到 family**。
  static String tierFromConfidence(double c) {
    if (c >= ReputationCaps.familyFloor) return ReputationTier.family;
    if (c >= ReputationCaps.friendFloor) return ReputationTier.friend;
    if (c >= ReputationCaps.acquaintanceFloor) return ReputationTier.acquaintance;
    return ReputationTier.stranger;
  }

  /// ★★ **归属闸**：Hub 拉回来的这条记录，主体是不是**我自己的**钥。
  ///
  /// 为什么它必须独立于 [verifyEndorsement]：验签只回答"这份背书是不是真的由
  /// 它自称的 issuer 签的"，**不回答"被背书的人是不是我"**。缺了这一闸，
  /// 一个被篡改的 / 有 bug 的 Hub 就能把别人的（**签名完全合法**的）背书塞进我的库。
  ///
  /// [myKeys] 必须由本机自己算（`WoldRuntime.myIdentityKeys`：当前钥 ∪ 本地退休
  /// 记录 ∪ 本地逐条验过签的换钥链），**绝不可**采信 Hub 回包里的 `alias.keys`。
  ///
  /// fail-closed：`myKeys` 为空 ⇒ 一条都不收。"宁可空着"远比"塞进不属于我的东西"好 ——
  /// 后者会让用户看到一份**看起来完整**、实则掺了别人的履历。
  /// 走 `dart run` 的离线脚本可直接调本函数（本模块零平台依赖）。
  static bool subjectIsMine(String subjectPub, Set<String> myKeys) {
    final s = subjectPub.trim();
    if (s.isEmpty || myKeys.isEmpty) return false;
    for (final k in myKeys) {
      if (k.trim() == s) return true;
    }
    return false;
  }

  /// **验一份背书**（fail-closed）。
  ///
  /// 检查顺序：便宜的先、密码学的后；任何一步不过直接返回，绝不"部分通过"。
  /// [nowMs] 传入时额外判过期；[revokedKeys] 为已吊销的 `issuer|subject`。
  static Future<EndorseDecision> verifyEndorsement(
    Endorsement e, {
    int? nowMs,
    Set<String> revokedKeys = const {},
  }) async {
    if (e.issuerPub.trim().isEmpty ||
        e.subjectPub.trim().isEmpty ||
        e.tier.trim().isEmpty ||
        e.sig.trim().isEmpty) {
      return const EndorseDecision(
          accept: false, code: EndorseCode.missingFields);
    }
    if (!Ed25519Sig.isPubkey(e.issuerPub) || !Ed25519Sig.isPubkey(e.subjectPub)) {
      return const EndorseDecision(accept: false, code: EndorseCode.badPubkey);
    }
    // 铁律 3：自证无效（先于验签 —— 自证的"合法签名"照样不能采信）
    if (e.issuerPub == e.subjectPub) {
      return const EndorseDecision(
          accept: false, code: EndorseCode.selfEndorsement);
    }
    if (!ReputationTier.isEndorsable(e.tier)) {
      return const EndorseDecision(accept: false, code: EndorseCode.badTier);
    }
    if (e.note.length > ReputationCaps.maxNoteChars) {
      return const EndorseDecision(accept: false, code: EndorseCode.noteTooLong);
    }
    if (e.issuedAtMs <= 0 || e.expiresAtMs <= e.issuedAtMs) {
      return const EndorseDecision(accept: false, code: EndorseCode.badWindow);
    }

    // 吊销先于验签：已收回的背书，即使签名有效也不得采信。
    if (revokedKeys.contains(e.key)) {
      return const EndorseDecision(accept: false, code: EndorseCode.revoked);
    }

    final sigOk = await Ed25519Sig.verify(
      message: e.canonicalBytes(),
      signatureB64: e.sig,
      publicKeyBase58: e.issuerPub,
    );
    if (!sigOk) {
      return const EndorseDecision(
          accept: false, code: EndorseCode.badSignature);
    }

    if (nowMs != null && e.expiredAt(nowMs)) {
      return const EndorseDecision(accept: false, code: EndorseCode.expired);
    }
    return const EndorseDecision(accept: true, code: EndorseCode.ok);
  }

  /// **验一份吊销声明**：签名有效**且**公钥必须就是原背书的签发人。
  static Future<EndorseDecision> verifyRevocation(
    EndorsementRevocation r,
  ) async {
    if (r.issuerPub.trim().isEmpty ||
        r.subjectPub.trim().isEmpty ||
        r.sig.trim().isEmpty) {
      return const EndorseDecision(
          accept: false, code: EndorseCode.missingFields);
    }
    if (!Ed25519Sig.isPubkey(r.issuerPub) || !Ed25519Sig.isPubkey(r.subjectPub)) {
      return const EndorseDecision(accept: false, code: EndorseCode.badPubkey);
    }
    if (r.atMs <= 0) {
      return const EndorseDecision(accept: false, code: EndorseCode.badWindow);
    }
    final ok = await Ed25519Sig.verify(
      message: r.canonicalBytes(),
      signatureB64: r.sig,
      publicKeyBase58: r.issuerPub,
    );
    return ok
        ? const EndorseDecision(accept: true, code: EndorseCode.ok)
        : const EndorseDecision(
            accept: false, code: EndorseCode.badSignature);
  }

  /// **签收判定**（纯函数）：同 `(issuer, subject)` 只有一份当前背书。
  ///
  /// 与 M9 的"同版本换内容 → 拒"**不同**：人**可以**改变看法，所以这里是
  /// **允许覆盖更新**（[EndorseCode.ok]，detail=`updated`），但不允许多份并存
  /// —— 主键 `(issuer_pub, subject_pub)` 保证"叠加不出版第二份背书"。
  /// 完全相同则 [EndorseCode.ok] + detail=`duplicate`（幂等）。
  static EndorseDecision endorseDecision({
    required Endorsement incoming,
    required Endorsement? existing,
  }) {
    if (existing == null) {
      return const EndorseDecision(accept: true, code: EndorseCode.ok);
    }
    final identical = existing.tier == incoming.tier &&
        existing.note == incoming.note &&
        existing.expiresAtMs == incoming.expiresAtMs &&
        existing.issuedAtMs == incoming.issuedAtMs;
    return identical
        ? const EndorseDecision(
            accept: true, code: EndorseCode.ok, detail: 'duplicate')
        : const EndorseDecision(
            accept: true, code: EndorseCode.ok, detail: 'updated');
  }

  /// **信任传播**（max-product，纯函数）。
  ///
  /// 算法：从锚点出发做"最大乘积"松弛 ——
  /// `w[v] = max(w[u] × attenuation × tierWeight(e.tier))`。
  ///
  /// 为什么这个形式天然满足铁律 2、3、5：
  /// - **只取 max，不求和** → 造 100 条中继路径不会让置信度涨一分；
  /// - 由于 `attenuation × tierWeight < 1`，权重沿路径**严格递减**，
  ///   因此不可能回到已访问节点还能产生更大权重 → **结构上无环**，
  ///   不需要额外的环路检测代码（少一处代码就少一处出错的地方）；
  /// - 递减同时意味着深度越大越弱，"朋友的朋友的朋友"自然被衰减掉。
  ///
  /// [anchors] 为**我直接信任**的公钥 → 权重（0..1，来自本地主观信誉）。
  /// [endorsements] 为候选边（调用方应先自行剔除过期/吊销/验签不过的，
  /// 本函数也会再判一次时间窗与自证）。
  ///
  /// [subjectAliases] 是 [subjectPub] **所属身份的其余历史公钥**（换钥链算出，
  /// 见 `RotationChain.keysOf`）。为什么需要它：背书按 `subject_pub` 计，而换钥会
  /// 退休旧公钥 —— 不加这一步，**用户换一次手机，别人给他的背书就再也命中不了他**。
  /// ⚠️ 别名只做**集合成员判断**：本函数不展开、不猜、不跨身份。别名给错 =
  /// 把别人的履历算到他头上，所以由调用方负责 fail-closed 地算（链断就只传空集）。
  static NetworkVerdict evaluate({
    required String subjectPub,
    required Map<String, double> anchors,
    required List<Endorsement> endorsements,
    Set<String> revokedKeys = const {},
    Set<String> subjectAliases = const {},
    required int nowMs,
  }) {
    if (subjectPub.trim().isEmpty) {
      return const NetworkVerdict(known: false, code: EndorseCode.missingFields);
    }
    // "这个主体"= 查询的那把钥 ∪ 同一身份的其余历史公钥。
    final targets = subjectAliases.isEmpty
        ? <String>{subjectPub}
        : <String>{subjectPub, ...subjectAliases};

    // 边按签发人索引；先剔掉"无效边"（自证 / 过期 / 吊销 / 档位不可背书）。
    final outEdges = <String, List<Endorsement>>{};
    for (final e in endorsements) {
      if (e.issuerPub == e.subjectPub) continue;
      if (!ReputationTier.isEndorsable(e.tier)) continue;
      if (e.expiredAt(nowMs)) continue;
      if (revokedKeys.contains(e.key)) continue;
      outEdges.putIfAbsent(e.issuerPub, () => <Endorsement>[]).add(e);
    }

    // best[v] = 到达 v 的最大权重（及对应的深度与路径）
    final best = <String, _NodeBest>{};
    for (final entry in anchors.entries) {
      var w = entry.value;
      if (w <= 0) continue;
      // 主观信任不可能是 1.0（那是盲从，不是信任）—— 上限由常量钉住，
      // 它同时保证"网络背书抬不到 family"（铁律 5）。
      if (w > ReputationCaps.maxAnchorWeight) w = ReputationCaps.maxAnchorWeight;
      final pub = entry.key;
      if (best[pub] == null || w > best[pub]!.weight) {
        best[pub] = _NodeBest(weight: w, depth: 0, path: [pub]);
      }
    }

    // 朴素松弛：按权重降序反复取当前最优节点往外扩，最多 maxDepth 跳。
    // （节点规模是本机的社交圈，量级很小；可读性与"正确性看得见"优先于复杂度。）
    for (var hop = 0; hop < ReputationCaps.maxDepth; hop++) {
      final frontier = best.entries
          .where((e) => e.value.depth == hop)
          .toList()
        ..sort((a, b) => b.value.weight.compareTo(a.value.weight));

      for (final cur in frontier) {
        final edges = outEdges[cur.key];
        if (edges == null) continue;
        for (final e in edges) {
          final nw = cur.value.weight *
              ReputationCaps.attenuation *
              ReputationTier.weightOf(e.tier);
          if (nw < ReputationCaps.minWeight) continue;
          // 权重严格递减 → 不可能回到路径上已有的节点（结构上无环）
          if (cur.value.path.contains(e.subjectPub)) continue;
          final prev = best[e.subjectPub];
          if (prev == null || nw > prev.weight) {
            best[e.subjectPub] = _NodeBest(
              weight: nw,
              depth: hop + 1,
              path: [...cur.value.path, e.subjectPub],
            );
          }
        }
      }
    }

    // 命中的可能是该身份的**任一历史公钥**：背书留在旧钥上是换钥之后的常态，
    // 只在旧钥上命中而判 `unknown`，正是"换一次手机履历归零"的病根。
    // 多个历史钥都有通路时取权重最大的那条（铁律 2：只取最优，不累加）。
    _NodeBest? hit;
    var matched = subjectPub;
    for (final entry in best.entries) {
      if (!targets.contains(entry.key)) continue;
      final cur = entry.value;
      if (hit == null || cur.weight > hit.weight) {
        hit = cur;
        matched = entry.key;
      }
    }
    if (hit == null || hit.weight < ReputationCaps.minConfidence) {
      // 铁律 1：没有通路就老实说不知道 —— 不返回 0，也不返回 50。
      return const NetworkVerdict(known: false, code: EndorseCode.unknown);
    }
    final bestHit = hit;
    // 通路条数：在**最优深度的前驱层**里，有多少个**不同的人**为他背书。
    // 只用于表达证据厚度，**不参与置信度计算**（铁律 2：造再多路径也不涨一分）。
    var paths = 1;
    if (bestHit.depth > 0) {
      final backers = <String>{};
      for (final entry in best.entries) {
        // 别名钥也是"他本人"，同样不能算作自己的背书人。
        if (targets.contains(entry.key)) continue;
        if (entry.value.depth != bestHit.depth - 1) continue;
        if (entry.value.path.any(targets.contains)) continue; // 结构上无环
        final edges = outEdges[entry.key];
        if (edges == null) continue;
        for (final e in edges) {
          if (!targets.contains(e.subjectPub)) continue;
          final nw = entry.value.weight *
              ReputationCaps.attenuation *
              ReputationTier.weightOf(e.tier);
          if (nw < ReputationCaps.minWeight) continue;
          backers.add(entry.key);
        }
      }
      if (backers.isNotEmpty) paths = backers.length;
    }

    return NetworkVerdict(
      known: true,
      code: EndorseCode.ok,
      confidence: bestHit.weight,
      depth: bestHit.depth,
      tier: tierFromConfidence(bestHit.weight),
      path: bestHit.path,
      paths: paths,
      matchedKey: matched,
    );
  }
}

class _NodeBest {
  final double weight;
  final int depth;
  final List<String> path;
  const _NodeBest({required this.weight, required this.depth, required this.path});
}

// ---------------------------------------------------------------------------
// 存储抽象（零依赖；SQLite 实现在 reputation_network_store_db.dart）
// ---------------------------------------------------------------------------

/// 背书与吊销的持久化抽象。
///
/// 抽出来只有一个目的：让"网络信誉"既能在真库上跑，也能在内存里被离线复算
/// （`dart run` 校验脚本要用）。生产实现必须是 SQLite ——
/// 背书是**信誉资产**，只存内存等于重启即失。
abstract class ReputationStore {
  Future<void> upsertEndorsement(Endorsement e);
  Future<Endorsement?> endorsement(String issuerPub, String subjectPub);
  Future<List<Endorsement>> byIssuer(String issuerPub);
  Future<List<Endorsement>> forSubject(String subjectPub);
  Future<List<Endorsement>> all();

  Future<void> upsertRevocation(EndorsementRevocation r);
  Future<EndorsementRevocation?> revocation(String issuerPub, String subjectPub);
  Future<Set<String>> revokedKeys();
}

/// 内存实现（单测 / 离线复算用；**不落盘** —— 正因如此它不能用于生产背书）。
class MemoryReputationStore implements ReputationStore {
  final Map<String, Endorsement> _endorsements = {};
  final Map<String, EndorsementRevocation> _revocations = {};

  @override
  Future<void> upsertEndorsement(Endorsement e) async =>
      _endorsements[e.key] = e;

  @override
  Future<Endorsement?> endorsement(String issuerPub, String subjectPub) async =>
      _endorsements['$issuerPub|$subjectPub'];

  @override
  Future<List<Endorsement>> byIssuer(String issuerPub) async =>
      _endorsements.values.where((e) => e.issuerPub == issuerPub).toList();

  @override
  Future<List<Endorsement>> forSubject(String subjectPub) async =>
      _endorsements.values.where((e) => e.subjectPub == subjectPub).toList();

  @override
  Future<List<Endorsement>> all() async => _endorsements.values.toList();

  @override
  Future<void> upsertRevocation(EndorsementRevocation r) async =>
      _revocations[r.key] = r;

  @override
  Future<EndorsementRevocation?> revocation(
          String issuerPub, String subjectPub) async =>
      _revocations['$issuerPub|$subjectPub'];

  @override
  Future<Set<String>> revokedKeys() async => _revocations.keys.toSet();
}

// ---------------------------------------------------------------------------
// 事件名（必须与 TelemetryEvents 一致，漂移会静默丢埋点）
// ---------------------------------------------------------------------------
abstract final class ReputationNetworkEvents {
  static const String endorseAccepted = 'reputation_endorse_accepted';
  static const String endorseRejected = 'reputation_endorse_rejected';
  static const String revoked = 'reputation_endorsement_revoked';
  static const String queryKnown = 'reputation_query_known';
  static const String queryUnknown = 'reputation_query_unknown';
}

// ---------------------------------------------------------------------------
// 服务层：把"纯判定"和"落库/埋点"串起来
// ---------------------------------------------------------------------------

/// 网络信誉服务。
///
/// 刻意**不做**的事：不自己签发背书（私钥属于本机身份，签名在调用方完成，
/// 与 M9 的"UI 层用本机身份私钥签清单"同款 —— 服务层只收**已签名**的对象）。
class ReputationNetworkService {
  final ReputationStore store;
  final void Function(String kind, Map<String, Object?> data)? onEvent;

  /// 背书**落库成功后**的上行钩子（best-effort，由装配层提供）。
  ///
  /// 幂等重复（`detail == 'duplicate'`）不触发：本地没写、树上也早有这一片，
  /// 再推一次只是白跑一趟网络。
  final void Function(Endorsement endorsement)? onCommit;

  ReputationNetworkService({required this.store, this.onEvent, this.onCommit});

  /// **签收一份背书**：先验签（fail-closed），再做幂等判定，通过才落库。
  Future<EndorseDecision> endorse(Endorsement e, {int? nowMs}) async {
    final revoked = await store.revokedKeys();
    final v = await ReputationGraph.verifyEndorsement(
        e, nowMs: nowMs, revokedKeys: revoked);
    if (!v.accept) {
      _emit(ReputationNetworkEvents.endorseRejected,
          {'subject': e.subjectPub, 'reason': v.code});
      return v;
    }
    final existing = await store.endorsement(e.issuerPub, e.subjectPub);
    final d = ReputationGraph.endorseDecision(incoming: e, existing: existing);
    if (d.detail != 'duplicate') {
      await store.upsertEndorsement(e);
      onCommit?.call(e);
    }
    _emit(ReputationNetworkEvents.endorseAccepted,
        {'subject': e.subjectPub, 'tier': e.tier, 'result': d.detail});
    return d;
  }

  /// **吊销**：公钥必须与**原背书的签发人**一致，否则任何人都能清场别人的信誉。
  Future<EndorseDecision> revoke(EndorsementRevocation r) async {
    final v = await ReputationGraph.verifyRevocation(r);
    if (!v.accept) {
      _emit(ReputationNetworkEvents.endorseRejected,
          {'subject': r.subjectPub, 'reason': v.code});
      return v;
    }
    final prior = await store.endorsement(r.issuerPub, r.subjectPub);
    if (prior == null) {
      // 没有可吊销的东西 —— 不是错误，但也不该"吊销成功"（避免凭空造出吊销记录）
      return const EndorseDecision(
          accept: false, code: EndorseCode.missingFields, detail: 'no_such_endorsement');
    }
    if (prior.issuerPub != r.issuerPub) {
      return const EndorseDecision(
          accept: false, code: EndorseCode.badSignature, detail: 'not_issuer');
    }
    await store.upsertRevocation(r);
    _emit(ReputationNetworkEvents.revoked, {'subject': r.subjectPub});
    return const EndorseDecision(accept: true, code: EndorseCode.ok);
  }

  /// **查询**：从 [anchors] 出发传播，给出可验证的证据链。
  ///
  /// 调用方（UI）负责把本地主观信誉换算成锚点权重；
  /// 查不到就返回 `known: false`，**调用方不得把它显示成 0 分**。
  ///
  /// [subjectAliases] 为该主体所属身份的**其余历史公钥**（`RotationChain.keysOf`
  /// 的结果）。换钥之后背书仍在旧钥上，不传它就会把认识的人误判成"不知道"。
  Future<NetworkVerdict> query({
    required String subjectPub,
    required Map<String, double> anchors,
    required int nowMs,
    Set<String> subjectAliases = const {},
  }) async {
    final revoked = await store.revokedKeys();
    final all = await store.all();
    final v = ReputationGraph.evaluate(
      subjectPub: subjectPub,
      anchors: anchors,
      endorsements: all,
      revokedKeys: revoked,
      subjectAliases: subjectAliases,
      nowMs: nowMs,
    );
    _emit(
      v.known
          ? ReputationNetworkEvents.queryKnown
          : ReputationNetworkEvents.queryUnknown,
      {'subject': subjectPub, 'tier': v.tier, 'depth': v.depth},
    );
    return v;
  }

  /// **我收到的背书** —— 按"我的全部历史公钥"取并集，而不是只看当前那把。
  ///
  /// 为什么不直接用 `store.forSubject(myPub)`：换钥退休的是**钥**，不是人。
  /// 换钥之前收到的背书，签名覆盖的 `subject_pub` 就是那把**旧钥**，也只会记在
  /// 旧钥上。只按当前钥查，等于"换一次手机收到的履历当场归零" —— 这就是要修的缺口。
  ///
  /// ⚠️ [subjectKeys] 必须由 `RotationChain.keysOf` **fail-closed** 地算出
  ///   （链断/有坏签名/一把钥被两个身份认领 ⇒ 只传当前钥）。多传一把别人的钥 =
  ///   把别人的履历算到自己头上。本函数不做任何展开：它只按给定的集合取并集。
  Future<List<Endorsement>> receivedBy(Set<String> subjectKeys) async {
    if (subjectKeys.isEmpty) return const [];
    final all = await store.all();
    final out = all.where((e) => subjectKeys.contains(e.subjectPub)).toList();
    // 与 `forSubject` 同序（新 → 旧），UI 不必为两个来源写两套排序。
    out.sort((a, b) => b.issuedAtMs.compareTo(a.issuedAtMs));
    return out;
  }

  /// **我签发出去的背书** —— 同理按全部历史公钥取并集。
  ///
  /// 旧钥签的背书至今仍然有效（签名覆盖的是 `issuer_pub`，那正是那把旧钥），
  /// 所以它们不该从"我签发过谁"里消失 —— 收到与签发是同一件事的两个视角。
  Future<List<Endorsement>> issuedBy(Set<String> issuerKeys) async {
    if (issuerKeys.isEmpty) return const [];
    final all = await store.all();
    final out = all.where((e) => issuerKeys.contains(e.issuerPub)).toList();
    out.sort((a, b) => b.issuedAtMs.compareTo(a.issuedAtMs));
    return out;
  }

  void _emit(String kind, Map<String, Object?> data) => onEvent?.call(kind, data);
}