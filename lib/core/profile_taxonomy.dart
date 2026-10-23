/// 画像卡的**词表与契约**：分类 / 来源 / 状态 / 合并结论 / 候选结构。
///
/// ---------------------------------------------------------------------------
/// 为什么单独一个文件（不是为了好看）
/// ---------------------------------------------------------------------------
/// 本文件**零 import**（连 `dart:` 都不用）。这是刻意的：
///
/// * 它是 `ProfileCardStore`（要 sqflite，跑在 Flutter 里）与
///   `ProfileCardExtractor`（纯字符串规则，**应该能在 `dart run` 里跑**）的**共同词表**。
/// * 如果抽取器从 `profile_card_store.dart` 里取常量，它就会连带 import sqflite
///   → **在纯 Dart VM 里 import 失败** → 那套规则就只能靠"扫源码字符串"来验证，
///   而扫源码**证明不了规则对不对**（"实证 ≠ 修复"同族：能编译不代表语义对）。
/// * 放到这里之后，`tool/verify_profile_cards.dart` 可以 **真的调用 [extract]**
///   并把结果逐条断言 —— 这才叫"结论能指到一次实测"。
///
/// ⚠️ 因此本文件**不许**加任何 import。加一个 `package:` 就会把上面这条能力废掉，
/// `verify_profile_cards.dart` 有一条断言盯着它。
library;

/// 画像分类。**固定枚举**，不允许自由文本 ——
/// 自由分类会让同一件事散成十几张卡（"工作"/"职业"/"岗位"），
/// 而"合并重复描述"正是需求里明确要求的。
abstract final class ProfileCategory {
  static const String identity = 'identity';
  static const String career = 'career';
  static const String preference = 'preference';
  static const String goal = 'goal';
  static const String habit = 'habit';
  static const String constraint = 'constraint';
  static const String context = 'context';

  static const List<String> all = <String>[
    identity, career, preference, goal, habit, constraint, context,
  ];

  /// 未知分类一律归到 [context]，**不丢弃**卡片。
  static String of(String raw) => all.contains(raw) ? raw : context;
}

/// 卡片来源。**唯一写入方登记处**。
abstract final class ProfileSource {
  /// 主人自己在界面上填写/修改。**置信度 1.0，且享有覆盖特权**。
  static const String owner = 'owner';

  /// 智能体从对话里抽取。
  static const String agentPrefix = 'agent:';

  /// 每日沉淀合并。
  static const String digestPrefix = 'digest:';

  static bool isOwner(String s) => s == owner;
}

/// 卡片状态。
abstract final class ProfileStatus {
  /// 生效中。**一个 slot 至多一张**。
  static const String active = 'active';

  /// 已被同 slot 的新卡取代（留痕，可回看）。
  static const String superseded = 'superseded';

  /// 与主人自述冲突，等主人裁决。
  static const String pending = 'pending';
}

/// `upsert` 的结果。**把"发生了什么"显式返回**，而不是让调用方猜 ——
/// 冲突被静默吞掉正是最坏的那种"成功"。
enum ProfileMergeOutcome {
  /// 新 slot，插入。
  inserted,

  /// 同 slot 同陈述 ⇒ 只提升置信度/时间（重复观察）。
  reinforced,

  /// 同 slot 不同陈述 ⇒ 旧卡留痕、新卡生效。
  superseded,

  /// 与**主人自述**冲突 ⇒ 不覆盖，落 pending 等裁决。
  pendingOwnerConflict,

  /// 入参不合法（空 slot / 空陈述），未写库。
  rejected,
}

/// 置信度台阶（**唯一事实源**，库与抽取器共用，不得各写一套）。
abstract final class ProfileConfidence {
  /// 首次观察。
  static const double firstSeen = 0.5;

  /// 每再观察一次的上调量。
  static const double step = 0.15;

  /// 自动累积的上限（永远到不了 1.0 —— 1.0 只留给主人手写）。
  static const double cap = 0.95;

  /// 主人手写/确认。
  static const double owner = 1.0;
}

/// 抽取出的候选（尚未落库）。**纯数据，无 IO**。
class ProfileCandidate {
  const ProfileCandidate({
    required this.category,
    required this.slot,
    required this.statement,
    required this.evidence,
    this.confidence,
  });

  final String category;

  /// 冲突判定的键。
  final String slot;

  /// 客观简洁的一句（第三人称陈述，便于直接展示给主人复核）。
  final String statement;

  /// 来源依据（可读的一句）。
  final String evidence;

  /// 为 null = 交给 `ProfileCardStore` 用 [ProfileConfidence.firstSeen]。
  /// 只有"主人显式要求记住"这类**规则特有**的置信度才在这里给值。
  final double? confidence;
}
