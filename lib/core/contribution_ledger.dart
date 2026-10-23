/// M10 · **分享成长红利的五件套**（PRD §4 M10）：贡献声望 + 可验证贡献账本，
/// 并承接 ① 创始成员、② 永久价格锁定 两份**签名声明**。
///
/// ---------------------------------------------------------------------------
/// 先说清楚本模块替代掉了什么
/// ---------------------------------------------------------------------------
/// 原方案是"股东分红"。它被否掉的原因不是"钱不够"，而是**法律性质**：
/// 在多法域会被认定为证券发行（详见 PRD §9.1 红线）。
/// 本模块做的是**精神采纳、形式重构**——把"股权"拆成五个**不构成证券**的机制：
///
/// | # | 机制 | 本文件的落点 |
/// |---|---|---|
/// | ① | 创始成员 | [FoundingDeclaration]（自签承诺 + 进 §16 日志） |
/// | ② | 永久价格锁定 | [PriceLockClaim]（平台签发的**定价权**） |
/// | ③ | 贡献声望 | [ContributionLedger.tally]（**不可转让**的累计分） |
/// | ④ | 一层收入分成 | P2，本文件不涉及（分成只有一层，见 `skill_registry`） |
/// | ⑤ | 可验证贡献账本 | [ContributionRecord] + [ContributionRecord.logLeafBytes] |
///
/// ---------------------------------------------------------------------------
/// 红线（PRD §4 M10 原文）
/// ---------------------------------------------------------------------------
/// > ⚠️ 以上五项**都不得演化为可转让、可兑现、可与利润挂钩的凭证**。
/// > 一旦出现"可变现"，就从"权益"变成"证券"，本条全部作废。
///
/// 这条红线在本模块里**不是文档约定，是结构约束**：
/// - 没有 transfer / sell / redeem / cashout / payout 任何接口或字段；
/// - 声望分是**派生值**（由记录现算），不落库、不可写、因此无处转让；
/// - `contribution_records` 表**故意没有** `owner_id` / `to_pub` / `price_cents`
///   这类列（见 `DBHelper._migrateV32`），想加转让必须先改表；
/// - `tool/verify_contribution_ledger.dart` 有**源码级断言**盯着上面三条。
///
/// ---------------------------------------------------------------------------
/// 为什么"可验证"是这一整套的支点
/// ---------------------------------------------------------------------------
/// PRD 原话：**把"分红"从金融问题变成数据可信问题——而这是我们的技术优势**。
/// 所以每一条贡献都是**已签名**的，且它的叶子哈希可以直接进 §16 那棵**同一棵树**
/// （PRD §16.1：同一棵树、同一个 monitor、同一期透明报告）。
/// 于是"我贡献了多少"不再需要谁背书，第三方拿记录就能复算；
/// 而"记录有没有被事后改过"由 §16 的包含证明 + 一致性证明兜住。
///
/// ---------------------------------------------------------------------------
/// 为什么"他人证明"比"自报"值钱
/// ---------------------------------------------------------------------------
/// M6 已经踩过这个坑（见 `reputation_network.dart` 文件头）：**自报的声誉天然可刷**。
/// 贡献分同理会退化成"自己给自己打分大赛"。所以：
/// - 关系型贡献（[ContributionKind.invite] / [ContributionKind.host]）
///   **必须由受益方签名证明**，自报一律拒（[ContributionCode.selfAttestation]）；
/// - 对象型贡献（circle / plugin / skill）允许自签，因为平台上**已存在一份
///   该主体签过名的独立物证**（圈成员记录 / 插件 `source_sig` / 技能清单），
///   不是空口白话；
/// - 所有类型都有**按类型的累计上限**（[ContributionCaps.perKindCap]）——
///   刷量不是"扣分",是**结构上不涨**。
///
/// 本文件**零平台依赖**（不 import `flutter` / `sqflite` / `shared_preferences`；
/// 只用 `dart:convert` + `ed25519_sig`），因此
/// `dart run tool/verify_contribution_ledger.dart` 可离线复算全部判定与计分。
library;

import 'dart:convert';

// 验签**不自己实现**：与 M6 背书 / M9 技能签名共用 `Ed25519Sig` 同一份实现。
// 三处各写一份必然漂移，而漂移的形态是"这边拒的假签名那边却收了"。
import 'ed25519_sig.dart' show Ed25519Sig;

/// 贡献类型。
///
/// ⚠️ 取值是**稳定标识符**（写进签名载荷），改字面量等于让历史签名全部失效 ——
/// 所以一律英文 token，中文文案在 UI/ARB 层渲染。
abstract final class ContributionKind {
  /// ① 创始成员（一次性、终身）。权重最高，因为它**不可再生**。
  static const String founding = 'founding';

  /// 邀请他人入场（关系型：必须由被邀请人签名证明）。
  static const String invite = 'invite';

  /// 建圈并使之存活（对象型：圈成员记录是一份独立物证）。
  static const String circle = 'circle';

  /// 主持活动（关系型：必须由参与者签名证明）。
  static const String host = 'host';

  /// 贡献插件（对象型：插件总线的 `source_sig` 是物证）。
  static const String plugin = 'plugin';

  /// 在技能生态上架技能（对象型：`skill_listings` 的清单由作者签名）。
  static const String skill = 'skill';

  static const List<String> values = [
    founding,
    invite,
    circle,
    host,
    plugin,
    skill,
  ];

  static bool isValid(String v) => values.contains(v);

  /// 该类型的**单条**分值（不可转让、不可兑现，只用于累计声望）。
  ///
  /// 数字很小且刻意拉开量级：
  /// - 创始成员 100 —— 终身只可能有一条，是"早期参与者"的唯一载体；
  /// - 技能 20 / 插件 15 —— 产出型贡献，价值高但可重复；
  /// - 主持 5 / 建圈 3 / 邀请 2 —— 行为型贡献，量大但单次价值低。
  ///
  /// ⚠️ 这几个数字同时出现在**签名载荷**里（见 [ContributionRecord.weight]），
  /// 所以调整它们**不会**追溯改写历史记录的分值 ——
  /// "你当年赚到的分，就是你永远拥有的分"。
  static int weightOf(String kind) => switch (kind) {
        founding => 100,
        skill => 20,
        plugin => 15,
        host => 5,
        circle => 3,
        invite => 2,
        _ => 0,
      };
}

/// 判定/结果码（UI 侧翻译成文案；**不写中文**，见 `tool/scan_hardcoded.dart`）。
abstract final class ContributionCode {
  static const String ok = 'ok';

  /// 必填字段缺失。
  static const String missingFields = 'missing_fields';

  /// 公钥不是合法的 32 字节 Ed25519 公钥。
  static const String badPubkey = 'bad_pubkey';

  /// 贡献类型非法。
  static const String badKind = 'bad_kind';

  /// 引用对象缺失或超长。
  static const String badRef = 'bad_ref';

  /// **自报无效**：该类型必须由他人证明，但 attestor 就是 subject 本人。
  static const String selfAttestation = 'self_attestation';

  /// 声明的分值与该类型的法定分值不符（想靠改 weight 抬分）。
  static const String badWeight = 'bad_weight';

  /// 时间戳非法（<= 0）。
  static const String badWindow = 'bad_window';

  /// 附言超长（超出即拒，**不截断** —— 截断会产生"半截意思"）。
  static const String noteTooLong = 'note_too_long';

  /// Ed25519 验签失败 —— 记录被改过（改分值、改主体、改时间都会落到这里）。
  static const String badSignature = 'bad_signature';

  /// 平台**不能给自己**发定价权（否则"定价权"退化成"平台自说自话"）。
  static const String selfIssuance = 'self_issuance';

  /// 定价权作用域非法。
  static const String badScope = 'bad_scope';

  /// 折扣比例超出 0..10000（万分之一）区间。
  static const String badDiscount = 'bad_discount';

  /// 无意义的定价权声明（既不免服务费、折扣又为 0）。
  static const String emptyClaim = 'empty_claim';

  /// 创始承诺标识不匹配（签名绑定的必须是**当前生效的那份承诺**）。
  static const String badPledge = 'bad_pledge';
}

/// 贡献参数。**全部是编译期常量**，理由与 M8 的 `TrialCaps` / M6 的
/// `ReputationCaps` 相同：这些数字就是抗刷能力的全部来源，
/// 做成可配置就等于把防线交给了运营。
abstract final class ContributionCaps {
  /// 附言长度上限。
  static const int maxNoteChars = 140;

  /// 引用对象标识长度上限。
  static const int maxRefChars = 200;

  /// **必须由他人证明**的贡献类型（自报无效）。
  ///
  /// 为什么只有这两类：它们是**关系型**贡献 —— 只有受益方能证明它真的发生过。
  /// 邀请：被邀请人签名"是这个人邀请我来的"；主持：参与者签名"这个人主持了活动"。
  /// 自报这两类等于把声望变成自吹自擂，而这正是 M6 已经论证过必然失败的形态。
  ///
  /// 其余类型（circle / plugin / skill）是**对象型**：平台上已有一份该主体
  /// 签过名的独立物证，收自签不构成"空口白话"。
  static const Set<String> requiresCounterparty = {
    ContributionKind.invite,
    ContributionKind.host,
  };

  /// 每个主体、每种类型的**累计上限**。
  ///
  /// ★ 这是抗刷的核心，不是"防作弊的补丁"：没有它，
  ///   "邀请 1000 个人"就能把声望刷到任意高度，而邀请恰恰是最低成本的可造假行为。
  ///   上限让刷量**结构上不涨分** —— 刷子照样能刷，但刷不出东西来。
  ///
  /// 取值逻辑：约等于"一个真诚的早期用户在其生命周期内**合理上限**"的 1.5~2 倍，
  /// 留出余量给真正的重度贡献者，同时把刷子的收益压到接近零。
  static const Map<String, int> perKindCap = {
    ContributionKind.founding: 100, // 一个人一辈子一条，上限 = 单条分值
    ContributionKind.invite: 200, // 最多 100 次有效邀请
    ContributionKind.circle: 60, // 最多 20 个圈
    ContributionKind.host: 100, // 最多 20 场活动
    ContributionKind.plugin: 150, // 最多 10 个插件
    ContributionKind.skill: 400, // 最多 20 个技能
  };

  /// 某个类型的累计上限（未知类型为 0，fail-closed）。
  static int capOf(String kind) => perKindCap[kind] ?? 0;
}

/// 一份**已签名的贡献记录**。
///
/// 签名由 [attestorPub] 产生，覆盖 [canonical] 的**全部字段**（含两个公钥、
/// 类型、引用对象、分值、时间、附言）—— 因此"事后改分值""事后换主体"
/// "事后延长到别的月份"都必然让签名失效。
///
/// 主体是**公钥**而不是 Agent ID：ID 可被重发/换绑，公钥才是身份根
/// （换一次 ID 就能甩掉全部差评的"信誉洗白"，与 M6 同一条理由）。
class ContributionRecord {
  /// 贡献者的 Ed25519 公钥（base58）—— 这条记录**为谁**计分。
  final String subjectPub;

  /// 证明人的 Ed25519 公钥（base58）。关系型贡献时必须 ≠ [subjectPub]。
  final String attestorPub;

  /// 贡献类型（[ContributionKind.values] 之一）。
  final String kind;

  /// 被引用的对象标识：被邀请人公钥 / 圈 ID / 活动 ID / 技能 ID 等。
  /// 它是**幂等键的一半** —— 同一件事重复上报不会计第二遍。
  final String ref;

  /// 本条的**法定分值**（应等于 [ContributionKind.weightOf]）。
  ///
  /// ⚠️ 刻意把它写进签名载荷而不是在计分时现算：
  /// 现算的话，将来调整分值表会**追溯改写历史记录的价值** ——
  /// 那正是"账本不可信"的经典形态。钉进签名 = "当年的分永远是当年的分"。
  final int weight;

  final int atMs;

  /// 附言（可选，≤ [ContributionCaps.maxNoteChars] 字符）。
  final String note;

  /// 证明人的 Ed25519 签名（base64），覆盖 [canonicalBytes]。
  final String sig;

  const ContributionRecord({
    required this.subjectPub,
    required this.attestorPub,
    required this.kind,
    required this.ref,
    required this.weight,
    required this.atMs,
    this.note = '',
    this.sig = '',
  });

  /// **幂等键**：同一件事只计一次分的实现方式。
  ///
  /// - `founding` 按**主体**去重（一个人一辈子只有一条创始记录）；
  /// - 其余按 `(类型, 主体, 引用对象)` 去重 —— 刻意**不含时间戳**：
  ///   含时间戳的话，把同一条贡献换个时间重签就能重复计分。
  ///
  /// 这就是"把一件事记十遍"在结构上不涨分的原因（[ContributionLedger.tally]
  /// 会先按本键去重，再累加）。
  String get key => kind == ContributionKind.founding
      ? '${ContributionKind.founding}|$subjectPub'
      : '$kind|$subjectPub|$ref';

  /// **确定性签名载荷**（JSON，键序固定）。
  ///
  /// `alg` 与 `kind` 必须入载荷：前者挡"算法混淆"，后者挡
  /// "拿一份合法的**定价权**声明当作**贡献**去验"（两者字段部分重叠）。
  String canonical() => jsonEncode({
        'alg': Ed25519Sig.alg,
        'kind': 'contribution',
        'ctype': kind,
        'subject_pub': subjectPub,
        'attestor_pub': attestorPub,
        'ref': ref,
        'weight': weight,
        'at': atMs,
        'note': note,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  ContributionRecord copyWith({String? note, String? sig}) => ContributionRecord(
        subjectPub: subjectPub,
        attestorPub: attestorPub,
        kind: kind,
        ref: ref,
        weight: weight,
        atMs: atMs,
        note: note ?? this.note,
        sig: sig ?? this.sig,
      );

  Map<String, Object?> toMap() => {
        'subject_pub': subjectPub,
        'attestor_pub': attestorPub,
        'kind': kind,
        'ref': ref,
        'weight': weight,
        'at_ms': atMs,
        'note': note,
        'sig': sig,
      };

  /// **上行线格式**（提交给 Hub 的 `POST /api/contributions/commit`）。
  ///
  /// ⚠️ 字段名与 [toMap] **刻意不同**，不要"统一"它们：
  /// - [toMap] 是**本地表列名**（`kind` / `at_ms`），对应 v32 的 `contribution_records`；
  /// - 本方法是**协议线格式**（`ctype` / `at`），对应 `@woldworld/protocol` 的
  ///   `contribution.canonical()` 与 `logBytes()`。
  ///
  /// 为什么线格式是 `ctype` 而不是 `kind`：`kind` 在协议里另有含义
  /// （`'contribution'` 域分隔标签，用来挡"拿定价权声明当贡献去验"的类型混淆），
  /// 所以"贡献类型"只能叫 `ctype`。把它俩合并 = 让域分隔失效。
  ///
  /// 为什么不直接提交 [toMap]：Hub 的 `contributionVerify` 读的是 `ctype` / `at`，
  /// 提交落库列名会一律得到 `bad_kind` —— 这是**两端最容易漂移一处**，
  /// `tool/smoke_log_hub.js` 的跨语言探针段落专门盯着字段口径。
  ///
  /// ⚠️ 这里**没有、也不该有**"分值/余额"字段：[weight] 是**该条记录的固定分值**，
  /// 由类型决定且已入签名载荷；累计声望是**派生值**，只在
  /// [ContributionLedger.tally] 现算，任何一端都不得把它变成可传输的字段
  /// （否则 §9.1 红线当场失守）。
  Map<String, Object?> toWireMap() => {
        'ctype': kind,
        'subject_pub': subjectPub,
        'attestor_pub': attestorPub,
        'ref': ref,
        'weight': weight,
        'at': atMs,
        'note': note,
        'sig': sig,
      };

  static ContributionRecord fromMap(Map<String, dynamic> m) => ContributionRecord(
        subjectPub: (m['subject_pub'] as String?) ?? '',
        attestorPub: (m['attestor_pub'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? '',
        ref: (m['ref'] as String?) ?? '',
        weight: (m['weight'] as num?)?.toInt() ?? 0,
        atMs: (m['at_ms'] as num?)?.toInt() ?? 0,
        note: (m['note'] as String?) ?? '',
        sig: (m['sig'] as String?) ?? '',
      );

  /// 叶子字节：只含**公开字段**、顺序固定 —— 任何第三方都能独立算出同一个哈希，
  /// 可直接进 §16 只追加日志（与 `Endorsement.logLeafBytes()` 同款）。
  ///
  /// ⚠️ 刻意**不含 [note]**：附言是自由文本，可能夹带个人信息。
  /// 公开账本只该承载"谁在何时做了什么类型的贡献"，不该承载他写了什么。
  List<int> logLeafBytes() => utf8.encode(jsonEncode({
        'kind': 'contribution',
        'ctype': kind,
        'subject_pub': subjectPub,
        'attestor_pub': attestorPub,
        'ref': ref,
        'weight': weight,
        'at': atMs,
      }));
}

/// 贡献签收判定结果。
class ContributionDecision {
  final bool accept;
  final String code; // ContributionCode.*
  final String detail;

  const ContributionDecision({
    required this.accept,
    required this.code,
    this.detail = '',
  });

  /// 幂等：与已有记录同键（同一件事重复上报）→ 不写第二遍，也不报错。
  bool get isDuplicate => accept && code == ContributionCode.ok && detail == 'duplicate';
}

/// ① 创始成员的**承诺标识**。
///
/// ---------------------------------------------------------------------------
/// 为什么签名绑定的是"承诺标识"而不是一段文案
/// ---------------------------------------------------------------------------
/// 文案必须本地化（中文/英文/…），而签名是**字节级**的 —— 若签名覆盖文案，
/// 换一次翻译就让全世界的历史签名失效。
/// 所以签名覆盖的是 `pledge_id`，**文案是这个 id 的公开注释**，放在仓库里。
/// 于是"我签的是哪一版承诺"是可判定的、可追责的。
abstract final class FoundingPledge {
  /// 当前生效的承诺版本。改动本字符串 = 发布新一版承诺（老签名仍指向老版本）。
  static const String pledgeId = 'founding_member_non_transferable_v1';

  /// 本承诺**明文禁止**的四件事（英文 token，UI 渲染成人类语言）。
  ///
  /// 这四条就是 PRD §9.1 红线在代码里的可机器校验形式：
  /// - `transferable` —— 可转让；
  /// - `redeemable` —— 可兑现；
  /// - `profit_linked` —— 与利润挂钩；
  /// - `voting_binding` —— 投票有约束力（PRD 明写"**非约束性**方向投票"）。
  ///
  /// 一个"创始成员"若主张其中任何一条，**本承诺自动作废**（法务兜底条款）。
  static const List<String> forbidden = [
    'transferable',
    'redeemable',
    'profit_linked',
    'voting_binding',
  ];
}

/// ① **创始成员声明**：本人自签的"我接受创始成员身份，且清楚它是荣誉不是所有权"。
///
/// 为什么必须是**本人签名**而不是平台发放：PRD 原话的意思正是
/// "**荣誉可以匿名，所有权不能**"。平台单方面发放一个标识，那是"平台说你特殊"；
/// 本人签名接受一份**附红线的承诺**，才是"我们知道彼此在做什么"。
class FoundingDeclaration {
  final String subjectPub;
  final int declaredAtMs;

  /// 承诺标识（必须是 [FoundingPledge.pledgeId] 的当前值）。
  final String pledgeId;

  final String sig;

  const FoundingDeclaration({
    required this.subjectPub,
    required this.declaredAtMs,
    this.pledgeId = FoundingPledge.pledgeId,
    this.sig = '',
  });

  String get key => 'founding|$subjectPub';

  String canonical() => jsonEncode({
        'alg': Ed25519Sig.alg,
        'kind': 'founding_declaration',
        'subject_pub': subjectPub,
        'pledge': pledgeId,
        'at': declaredAtMs,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  FoundingDeclaration copyWith({String? sig}) => FoundingDeclaration(
        subjectPub: subjectPub,
        declaredAtMs: declaredAtMs,
        pledgeId: pledgeId,
        sig: sig ?? this.sig,
      );

  Map<String, Object?> toMap() => {
        'subject_pub': subjectPub,
        'pledge': pledgeId,
        'at_ms': declaredAtMs,
        'sig': sig,
      };

  static FoundingDeclaration fromMap(Map<String, dynamic> m) =>
      FoundingDeclaration(
        subjectPub: (m['subject_pub'] as String?) ?? '',
        declaredAtMs: (m['at_ms'] as num?)?.toInt() ?? 0,
        pledgeId: (m['pledge'] as String?) ?? '',
        sig: (m['sig'] as String?) ?? '',
      );

  List<int> logLeafBytes() => utf8.encode(jsonEncode({
        'kind': 'founding_declaration',
        'subject_pub': subjectPub,
        'pledge': pledgeId,
        'at': declaredAtMs,
      }));
}

/// ② 定价权作用域：折扣作用于**哪一笔费用**。
///
/// 这三个是平台上**真实存在**的费用项。作用域必须**显式**：
/// 一个模糊的"永久折扣"会在未来被解释成"免一切费用"，
/// 而明确到费用项，它才是一份可计算、可兑现的**定价权**。
abstract final class PriceLockScope {
  /// 主持费（Host 层权益）。
  static const String hostFee = 'host_fee';

  /// 服务费（平台的通用服务费）。
  static const String serviceFee = 'service_fee';

  /// 技能分账抽成（M9 生态的平台侧比例）。
  static const String skillCommission = 'skill_commission';

  static const List<String> values = [hostFee, serviceFee, skillCommission];

  static bool isValid(String v) => values.contains(v);
}

/// ② **永久价格锁定**：平台签发给早期用户的一份**定价权**。
///
/// ---------------------------------------------------------------------------
/// 为什么它是"定价权"而不是"证券"（PRD 原话）
/// ---------------------------------------------------------------------------
/// 用户得到的是"将来涨价时我的价格不变"。它的**成本是未来的定价空间**，
/// 而不是公司的现金流或利润 —— 这是发行方对**自己的定价**作出的承诺，
/// 与"分享利润"在法理上是两件事。
///
/// 所以本类**结构上只有价格维度**：作用域、折扣率、是否全免、生效时间。
/// 它**没有**面值、没有可变现比例、没有受益人指定、没有二级转让 ——
/// 那些字段一旦出现，"定价权"立刻退化成"证券"，本机制全部作废。
/// `tool/verify_contribution_ledger.dart` 对字段清单有源码级断言。
class PriceLockClaim {
  /// 签发人 = **平台**（它的公钥）。用户拿不到签发权，只能持有。
  final String issuerPub;

  /// 持有人 = 早期用户公钥。
  final String subjectPub;

  /// 作用域（[PriceLockScope.values] 之一）。
  final String scope;

  /// 折扣（万分之一，即 bps）：3000 = 打七折。
  final int discountBps;

  /// 是否全免该项费用。
  final bool feeWaived;

  final int effectiveFromMs;

  /// 是否永久（PRD 明确"永久锁定"，故正常应为 true；留字段以支持限时权益）。
  final bool permanent;

  final String sig;

  const PriceLockClaim({
    required this.issuerPub,
    required this.subjectPub,
    required this.scope,
    required this.discountBps,
    required this.effectiveFromMs,
    this.feeWaived = false,
    this.permanent = true,
    this.sig = '',
  });

  String get key => '$scope|$subjectPub';

  /// 实际生效的折扣率（全免等价于 10000 bps）。
  int get effectiveDiscountBps => feeWaived ? 10000 : discountBps;

  String canonical() => jsonEncode({
        'alg': Ed25519Sig.alg,
        'kind': 'price_lock',
        'issuer_pub': issuerPub,
        'subject_pub': subjectPub,
        'scope': scope,
        'discount_bps': discountBps,
        'fee_waived': feeWaived,
        'effective_from': effectiveFromMs,
        'permanent': permanent,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  PriceLockClaim copyWith({String? sig}) => PriceLockClaim(
        issuerPub: issuerPub,
        subjectPub: subjectPub,
        scope: scope,
        discountBps: discountBps,
        effectiveFromMs: effectiveFromMs,
        feeWaived: feeWaived,
        permanent: permanent,
        sig: sig ?? this.sig,
      );

  Map<String, Object?> toMap() => {
        'issuer_pub': issuerPub,
        'subject_pub': subjectPub,
        'scope': scope,
        'discount_bps': discountBps,
        'fee_waived': feeWaived ? 1 : 0,
        'effective_from': effectiveFromMs,
        'permanent': permanent ? 1 : 0,
        'sig': sig,
      };

  static PriceLockClaim fromMap(Map<String, dynamic> m) => PriceLockClaim(
        issuerPub: (m['issuer_pub'] as String?) ?? '',
        subjectPub: (m['subject_pub'] as String?) ?? '',
        scope: (m['scope'] as String?) ?? '',
        discountBps: (m['discount_bps'] as num?)?.toInt() ?? 0,
        feeWaived: ((m['fee_waived'] as num?)?.toInt() ?? 0) != 0,
        effectiveFromMs: (m['effective_from'] as num?)?.toInt() ?? 0,
        permanent: ((m['permanent'] as num?)?.toInt() ?? 1) != 0,
        sig: (m['sig'] as String?) ?? '',
      );

  List<int> logLeafBytes() => utf8.encode(jsonEncode({
        'kind': 'price_lock',
        'issuer_pub': issuerPub,
        'subject_pub': subjectPub,
        'scope': scope,
        'discount_bps': discountBps,
        'fee_waived': feeWaived,
        'effective_from': effectiveFromMs,
        'permanent': permanent,
      }));
}

/// ③ **贡献声望**（派生值，**不落库、不可写**）。
///
/// ⚠️ `byKind` 是**封顶后**的分值，`rawByKind` 是封顶前的原始累计。
/// 两者都给出，是因为 UI 需要能解释"为什么我继续邀请人也不涨了" ——
/// 那正是上限在起作用，而不是系统坏了。
///
/// **没有** `transferTo` / `sell` / `redeem` / `cashOut` 任何方法，
/// 也**不提供**写入接口：分值永远由 [ContributionLedger.tally] 从记录现算。
/// 派生 + 只读 = 无处转让。这是 PRD §9.1 红线在 API 层面的落地。
class ContributionScore {
  /// 封顶后的总分。
  final int total;

  /// 封顶后的分类型分值。
  final Map<String, int> byKind;

  /// 封顶前的分类型原始累计。
  final Map<String, int> rawByKind;

  /// 计入分值的记录条数（已去重）。
  final int records;

  /// 被去重掉的重复条数（同一件事被记了多次）。
  final int duplicates;

  const ContributionScore({
    required this.total,
    required this.byKind,
    required this.rawByKind,
    required this.records,
    required this.duplicates,
  });

  static const ContributionScore empty = ContributionScore(
    total: 0,
    byKind: {},
    rawByKind: {},
    records: 0,
    duplicates: 0,
  );

  /// 某类型是否**已触顶**（UI 用它解释"再刷也不涨"）。
  bool capped(String kind) =>
      (rawByKind[kind] ?? 0) > (byKind[kind] ?? 0);
}

/// 贡献账本的**纯判定层**（不落库、不发网络、不读时钟）。
abstract final class ContributionLedger {
  /// **验一条贡献记录**（fail-closed）。
  ///
  /// 检查顺序：便宜的先、密码学的后；任何一步不过直接返回，绝不"部分通过"。
  static Future<ContributionDecision> verify(ContributionRecord r) async {
    if (r.subjectPub.trim().isEmpty ||
        r.attestorPub.trim().isEmpty ||
        r.kind.trim().isEmpty ||
        r.sig.trim().isEmpty) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.missingFields);
    }
    if (!Ed25519Sig.isPubkey(r.subjectPub) ||
        !Ed25519Sig.isPubkey(r.attestorPub)) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badPubkey);
    }
    if (!ContributionKind.isValid(r.kind)) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badKind);
    }
    // 引用对象：对象型/关系型都必须有（它是幂等键的一半），创始成员除外。
    if (r.kind != ContributionKind.founding) {
      if (r.ref.trim().isEmpty ||
          r.ref.length > ContributionCaps.maxRefChars) {
        return const ContributionDecision(
            accept: false, code: ContributionCode.badRef);
      }
    }
    // ★ 关系型贡献**自报无效**（先于验签 —— 自证的"合法签名"照样不能采信）。
    if (ContributionCaps.requiresCounterparty.contains(r.kind) &&
        r.attestorPub == r.subjectPub) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.selfAttestation);
    }
    // 分值必须等于法定分值（想靠改 weight 抬分 → 在这里就被拦下）。
    if (r.weight != ContributionKind.weightOf(r.kind)) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badWeight);
    }
    if (r.atMs <= 0) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badWindow);
    }
    if (r.note.length > ContributionCaps.maxNoteChars) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.noteTooLong);
    }
    final sigOk = await Ed25519Sig.verify(
      message: r.canonicalBytes(),
      signatureB64: r.sig,
      publicKeyBase58: r.attestorPub,
    );
    if (!sigOk) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badSignature);
    }
    return const ContributionDecision(accept: true, code: ContributionCode.ok);
  }

  /// **签收判定**（纯函数）：同一件事 [ContributionRecord.key] 只计一份。
  ///
  /// 与 M6 背书"允许覆盖更新"**不同**：贡献是**历史事实**，
  /// 发生了就是发生了 —— 所以重复上报是幂等（不写、不报错），
  /// 而不是覆盖。改一条历史贡献的语义等于篡改账本。
  static ContributionDecision recordDecision({
    required ContributionRecord incoming,
    required ContributionRecord? existing,
  }) {
    if (existing == null) {
      return const ContributionDecision(
          accept: true, code: ContributionCode.ok);
    }
    return const ContributionDecision(
        accept: true, code: ContributionCode.ok, detail: 'duplicate');
  }

  /// **计分**（纯函数，幂等）：先按幂等键去重，再分类型累加、封顶。
  ///
  /// 调用方应传入**已验证通过**的记录；本函数仍会做一次"法定分值"过滤，
  /// 因为计分口径不该依赖调用方有没有先验签。
  static ContributionScore tally(Iterable<ContributionRecord> records) {
    final seen = <String>{};
    final raw = <String, int>{};
    var kept = 0;
    var dup = 0;

    for (final r in records) {
      if (!ContributionKind.isValid(r.kind)) continue;
      if (r.weight != ContributionKind.weightOf(r.kind)) continue;
      if (r.subjectPub.isEmpty) continue;
      if (!seen.add(r.key)) {
        dup++;
        continue;
      }
      raw[r.kind] = (raw[r.kind] ?? 0) + r.weight;
      kept++;
    }

    final byKind = <String, int>{};
    var total = 0;
    for (final entry in raw.entries) {
      final capped = entry.value > ContributionCaps.capOf(entry.key)
          ? ContributionCaps.capOf(entry.key)
          : entry.value;
      byKind[entry.key] = capped;
      total += capped;
    }

    return ContributionScore(
      total: total,
      byKind: byKind,
      rawByKind: raw,
      records: kept,
      duplicates: dup,
    );
  }

  /// 从多条记录里筛出**属于某主体**的那些（计分/展示用）。
  static List<ContributionRecord> ofSubject(
    Iterable<ContributionRecord> records,
    String subjectPub,
  ) =>
      [for (final r in records) if (r.subjectPub == subjectPub) r];

  /// **验一份创始成员声明**（fail-closed）。
  static Future<ContributionDecision> verifyFounding(
      FoundingDeclaration d) async {
    if (d.subjectPub.trim().isEmpty || d.sig.trim().isEmpty) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.missingFields);
    }
    if (!Ed25519Sig.isPubkey(d.subjectPub)) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badPubkey);
    }
    // 承诺标识必须**逐字**等于当前生效版本 —— 否则"我同意的是哪一版"就无从判定。
    if (d.pledgeId != FoundingPledge.pledgeId) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badPledge);
    }
    if (d.declaredAtMs <= 0) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badWindow);
    }
    final ok = await Ed25519Sig.verify(
      message: d.canonicalBytes(),
      signatureB64: d.sig,
      publicKeyBase58: d.subjectPub,
    );
    return ok
        ? const ContributionDecision(accept: true, code: ContributionCode.ok)
        : const ContributionDecision(
            accept: false, code: ContributionCode.badSignature);
  }

  /// **验一份定价权声明**（fail-closed）。签名者是**平台**，不是持有人。
  static Future<ContributionDecision> verifyPriceLock(PriceLockClaim c) async {
    if (c.issuerPub.trim().isEmpty ||
        c.subjectPub.trim().isEmpty ||
        c.scope.trim().isEmpty ||
        c.sig.trim().isEmpty) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.missingFields);
    }
    if (!Ed25519Sig.isPubkey(c.issuerPub) ||
        !Ed25519Sig.isPubkey(c.subjectPub)) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badPubkey);
    }
    // 平台不能给自己发定价权 —— 那等于"平台自说自话"，机制失去意义。
    if (c.issuerPub == c.subjectPub) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.selfIssuance);
    }
    if (!PriceLockScope.isValid(c.scope)) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badScope);
    }
    if (c.discountBps < 0 || c.discountBps > 10000) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badDiscount);
    }
    if (c.effectiveFromMs <= 0) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.badWindow);
    }
    // 无意义声明：既不免该费用、折扣又是 0 —— 收下它只会让"定价权"变成空壳。
    if (!c.feeWaived && c.discountBps == 0) {
      return const ContributionDecision(
          accept: false, code: ContributionCode.emptyClaim);
    }
    final ok = await Ed25519Sig.verify(
      message: c.canonicalBytes(),
      signatureB64: c.sig,
      publicKeyBase58: c.issuerPub,
    );
    return ok
        ? const ContributionDecision(accept: true, code: ContributionCode.ok)
        : const ContributionDecision(
            accept: false, code: ContributionCode.badSignature);
  }

  /// ① + ② + ⑤ 的**联合自检**：一份记录流是否整体自洽。
  ///
  /// 它回答一个 UI 必须能回答的问题："**我这本账现在能被第三方验过吗？**"
  /// 任一条验不过 → 整本账判定为不可出示（fail-closed），
  /// 并给出第一条出问题的记录下标，避免"静默少算"。
  static Future<({bool ok, int badIndex, String code})> verifyLedger(
      List<ContributionRecord> records) async {
    for (var i = 0; i < records.length; i++) {
      final d = await verify(records[i]);
      if (!d.accept) return (ok: false, badIndex: i, code: d.code);
    }
    return (ok: true, badIndex: -1, code: ContributionCode.ok);
  }
}

// ---------------------------------------------------------------------------
// 存储抽象（零依赖；SQLite 实现在 contribution_store_db.dart）
// ---------------------------------------------------------------------------

/// 贡献记录的持久化抽象。
///
/// ⚠️ **刻意没有**任何"更新分值""转让记录""兑现"的方法 ——
/// 贡献账本是**只追加**的。抽象层不给口子，实现层就写不出转让。
///
/// 抽出来只有一个目的：让"贡献账本"既能在真库上跑，也能在内存里被离线复算
/// （`dart run` 校验脚本要用）。生产实现必须是 SQLite ——
/// 贡献是**可出示的证据**，只存内存等于重启即失。
abstract class ContributionStore {
  /// 追加一条贡献记录（幂等：同键已存在则不动）。
  Future<void> addRecord(ContributionRecord r);

  Future<ContributionRecord?> recordByKey(String key);

  Future<List<ContributionRecord>> allRecords();

  Future<List<ContributionRecord>> recordsOf(String subjectPub);

  /// 记录一条创始成员声明（幂等：一主体一条）。
  Future<void> setFounding(FoundingDeclaration d);

  Future<FoundingDeclaration?> founding(String subjectPub);

  /// 记录一份定价权（幂等：同 `(scope, subject)` 一份）。
  Future<void> setPriceLock(PriceLockClaim c);

  Future<List<PriceLockClaim>> priceLocksOf(String subjectPub);
}

/// 内存实现（单测 / 离线复算用；**不落盘** —— 正因如此不能用于生产）。
class MemoryContributionStore implements ContributionStore {
  final Map<String, ContributionRecord> _records = {};
  final Map<String, FoundingDeclaration> _foundings = {};
  final Map<String, PriceLockClaim> _locks = {};

  @override
  Future<void> addRecord(ContributionRecord r) async =>
      _records.putIfAbsent(r.key, () => r);

  @override
  Future<ContributionRecord?> recordByKey(String key) async => _records[key];

  @override
  Future<List<ContributionRecord>> allRecords() async => _records.values.toList();

  @override
  Future<List<ContributionRecord>> recordsOf(String subjectPub) async =>
      [for (final r in _records.values) if (r.subjectPub == subjectPub) r];

  @override
  Future<void> setFounding(FoundingDeclaration d) async =>
      _foundings.putIfAbsent(d.subjectPub, () => d);

  @override
  Future<FoundingDeclaration?> founding(String subjectPub) async =>
      _foundings[subjectPub];

  @override
  Future<void> setPriceLock(PriceLockClaim c) async =>
      _locks.putIfAbsent(c.key, () => c);

  @override
  Future<List<PriceLockClaim>> priceLocksOf(String subjectPub) async =>
      [for (final c in _locks.values) if (c.subjectPub == subjectPub) c];
}

// ---------------------------------------------------------------------------
// 事件名（必须与 TelemetryEvents 一致，漂移会静默丢埋点）
// ---------------------------------------------------------------------------
abstract final class ContributionEvents {
  static const String recordAccepted = 'contribution_record_accepted';
  static const String recordRejected = 'contribution_record_rejected';
  static const String foundingDeclared = 'contribution_founding_declared';
  static const String priceLockGranted = 'contribution_price_lock_granted';
  static const String scoreQueried = 'contribution_score_queried';
  static const String logAppendFailed = 'contribution_log_append_failed';
}

// ---------------------------------------------------------------------------
// 服务层：把"纯判定"和"落库 / 进 §16 日志 / 埋点"串起来
// ---------------------------------------------------------------------------

/// 贡献账本服务。
///
/// 刻意**不做**的事：
/// - **不自己签发**任何东西（私钥属于本机身份或平台，签名在调用方完成）——
///   与 M6 背书、M9 技能清单同款：服务层只收**已签名**的对象。
/// - **不提供**修改/删除/转让记录的接口（只追加）。
class ContributionService {
  final ContributionStore store;
  final void Function(String kind, Map<String, Object?> data)? onEvent;

  /// §16 合流：记录落库后，把它**已签名的叶子哈希**追加进公开只追加日志。
  ///
  /// 触发时机必须在**签名落库之后** —— 记进公开账本的必须是"已签名的记录"，
  /// 而不是一句还没有签名的自称（与 `AttestationService.onAdvance` 同一条纪律）。
  final Future<void> Function(ContributionRecord)? onAppend;

  ContributionService({required this.store, this.onEvent, this.onAppend});

  /// **签收一条贡献**：先验签（fail-closed），再做幂等判定，通过才落库 + 进日志。
  Future<ContributionDecision> record(ContributionRecord r) async {
    final v = await ContributionLedger.verify(r);
    if (!v.accept) {
      _emit(ContributionEvents.recordRejected,
          {'subject': r.subjectPub, 'ctype': r.kind, 'reason': v.code});
      return v;
    }
    final existing = await store.recordByKey(r.key);
    final d = ContributionLedger.recordDecision(incoming: r, existing: existing);
    if (d.detail != 'duplicate') {
      await store.addRecord(r);
      final sink = onAppend;
      if (sink != null) {
        try {
          await sink(r);
        } catch (e) {
          // 日志失败不能让记账失败：日志是"可验证性"的补位机制，不是主链路的必经环节。
          _emit(ContributionEvents.logAppendFailed,
              {'subject': r.subjectPub, 'error': '$e'});
        }
      }
    }
    _emit(ContributionEvents.recordAccepted,
        {'subject': r.subjectPub, 'ctype': r.kind, 'result': d.detail});
    return d;
  }

  /// **声明创始成员身份**：本人自签接受承诺 → 落库 → 进日志。
  Future<ContributionDecision> declareFounding(FoundingDeclaration d) async {
    final v = await ContributionLedger.verifyFounding(d);
    if (!v.accept) {
      _emit(ContributionEvents.recordRejected,
          {'subject': d.subjectPub, 'ctype': ContributionKind.founding,
            'reason': v.code});
      return v;
    }
    final existing = await store.founding(d.subjectPub);
    if (existing != null && existing.canonical() == d.canonical()) {
      return const ContributionDecision(
          accept: true, code: ContributionCode.ok, detail: 'duplicate');
    }
    await store.setFounding(d);
    _emit(ContributionEvents.foundingDeclared, {'subject': d.subjectPub});
    return const ContributionDecision(accept: true, code: ContributionCode.ok);
  }

  /// **登记一份定价权**（平台签发，本机只收）。
  Future<ContributionDecision> grantPriceLock(PriceLockClaim c) async {
    final v = await ContributionLedger.verifyPriceLock(c);
    if (!v.accept) {
      _emit(ContributionEvents.recordRejected,
          {'subject': c.subjectPub, 'ctype': 'price_lock', 'reason': v.code});
      return v;
    }
    final existing = await store.priceLocksOf(c.subjectPub);
    final dup = existing.any((e) => e.key == c.key && e.canonical() == c.canonical());
    if (dup) {
      return const ContributionDecision(
          accept: true, code: ContributionCode.ok, detail: 'duplicate');
    }
    await store.setPriceLock(c);
    _emit(ContributionEvents.priceLockGranted,
        {'subject': c.subjectPub, 'scope': c.scope});
    return const ContributionDecision(accept: true, code: ContributionCode.ok);
  }

  /// **我的贡献声望**（派生值：从已落库的记录现算，不读任何缓存分）。
  Future<ContributionScore> scoreOf(String subjectPub) async {
    final rows = await store.recordsOf(subjectPub);
    final s = ContributionLedger.tally(rows);
    _emit(ContributionEvents.scoreQueried,
        {'subject': subjectPub, 'total': s.total, 'records': s.records});
    return s;
  }

  /// 我是否创始成员（依据是**本人签过的那份声明**，不是某个平台发的标记）。
  Future<bool> isFounding(String subjectPub) async =>
      await store.founding(subjectPub) != null;

  void _emit(String kind, Map<String, Object?> data) => onEvent?.call(kind, data);
}
