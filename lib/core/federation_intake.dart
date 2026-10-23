/// ============================================================
/// 联邦名册**自动拉取**的纯逻辑内核（零平台依赖：只 import `dart:core`）。
///
/// 为什么单独成文件：把「谁能自动进名册、进多少、多久进一次」这几条判据
/// 钉在一个**不碰网络、不碰数据库、不碰 Flutter**的纯函数里 ——
/// 才能用 `dart run` 真跑复算（本项目纪律：结论必须能指到一次实测）。
/// 宿主编排 [FederationAutoPull] 只负责"取数 / 落库 / 记节流"，判据一律走这里。
///
/// 这件事本身**不做任何对外动作**：既不搭讪、也不发信、更不绕过审查网关卡。
/// 它只把「中转站里公开可读的注册名册」里、主人还没收录的陌生智能体
/// 收进本地陌生档 —— 而这一步是**可一键撤回**的（靠 `agent_friends.auto_pulled`）。
///
/// 四条判据（全在此文件内，可单测）：
///   ① 节流   —— 同一台机器 [FederationIntakeConfig.cooldown] 内不重复拉；
///   ② 单次上限 —— 一次最多收 [FederationIntakeConfig.maxPerPull] 个；
///   ③ 总量上限 —— 机器自动收录的行**总数**不超过 [FederationIntakeConfig.maxAutoTotal]；
///   ④ 排除   —— 跳过自己、跳过已在名册里的人、跳过脏数据（空 id / 重复）。
/// ============================================================
library;

/// 一个待收录的候选（从名册里筛出来的最小信息集）。
class FederationCandidate {
  const FederationCandidate({
    required this.agentId,
    required this.nickname,
    required this.lastSeen,
  });

  /// 目标智能体的稳定标识（`agent_id`）。**唯一**，用它查重。
  final String agentId;

  /// 展示名（名册可能没给，落库时由宿主补占位）。
  final String nickname;

  /// 最近在线时间（epoch 毫秒；名册拿不到时给 0）。仅用于排序，不落库语义。
  final int lastSeen;

  @override
  String toString() => 'FederationCandidate($agentId, $nickname, $lastSeen)';
}

/// 自动拉取的参数。默认值即**生产默认**：6 小时节流、单次最多 20、总量最多 200。
class FederationIntakeConfig {
  const FederationIntakeConfig({
    this.cooldown = const Duration(hours: 6),
    this.maxPerPull = 20,
    this.maxAutoTotal = 200,
  });

  /// 两次自动拉取之间的最小间隔。
  final Duration cooldown;

  /// 单次最多收录多少个。
  final int maxPerPull;

  /// 机器自动收录的行**总数**上限（主人手动收录的不计入）。
  final int maxAutoTotal;
}

/// 未拉取的原因（给 UI 说人话用；[FederationIntakePlan.allowed] 为 true 时无此值）。
enum FederationSkip {
  /// 自动拉取开关**处于关闭态**（默认关）。这是最外层的一道闸，
  /// 由宿主 [FederationAutoPull] 判定，不进入本文件的 plan 逻辑。
  disabled,

  /// 距上次拉取不足 [FederationIntakeConfig.cooldown]。
  cooldown,

  /// 名册里没有"尚未收录"的新面孔（都拉过了）。
  nothingNew,

  /// 自动收录总量已达上限。
  quotaReached,
}

/// 一次自动拉取的**决策与结果**（纯数据）。
class FederationIntakePlan {
  const FederationIntakePlan({
    required this.allowed,
    required this.skip,
    required this.candidates,
    required this.nextEligibleMs,
  });

  /// 是否可以进行这次拉取/收录。
  final bool allowed;

  /// 不允许时的原因；允许时为 null。
  final FederationSkip? skip;

  /// 允许时：本次应当收录的候选（已排序、已截断）。
  final List<FederationCandidate> candidates;

  /// 下一次**允许**拉取的时刻（epoch 毫秒）= 上次拉取 + 节流窗。
  /// 无论本次是否允许都给值，便于 UI 显示"下次可拉取时间"。
  final int nextEligibleMs;
}

/// 自动拉取的判据集合。全部 static，无状态 —— 便于单测与 `dart run` 复算。
class FederationIntake {
  FederationIntake._();

  /// 依据名册与现状算出「本次该收哪些人」。
  ///
  /// [roster] 为 `fetchA2aRoster` 原样返回的列表（元素含 `agent_id` / `nickname` /
  /// `last_seen`）。[knownIds] 是本地名册里已有的 `agent_id`（含手动与自动收录的，
  /// 二者都不该被重复收录）。[currentAutoCount] 是本地**机器自动收录**的行数
  /// （`agent_friends WHERE auto_pulled = 1`），用于总量闸。
  static FederationIntakePlan plan({
    required List<Map<String, dynamic>> roster,
    required String myAgentId,
    required Set<String> knownIds,
    required int lastPullMs,
    required int nowMs,
    required int currentAutoCount,
    FederationIntakeConfig config = const FederationIntakeConfig(),
  }) {
    final nextEligible = lastPullMs > 0
        ? lastPullMs + config.cooldown.inMilliseconds
        : 0;

    // ① 节流：距上次拉取不足冷却窗 ⇒ 不拉。
    if (lastPullMs > 0 && nowMs < nextEligible) {
      return FederationIntakePlan(
        allowed: false,
        skip: FederationSkip.cooldown,
        candidates: const [],
        nextEligibleMs: nextEligible,
      );
    }

    // ④ 排除 + 去重：跳过自己、脏数据、已在名册里的人；同一 id 只留一条。
    //    去重取 `lastSeen` 更大者（名册理论上不该有重复，但脏数据要兜住）。
    final byId = <String, FederationCandidate>{};
    for (final raw in roster) {
      final id = (raw['agent_id'] ?? '').toString().trim();
      if (id.isEmpty || id == myAgentId) continue;
      if (knownIds.contains(id)) continue;
      final nickname = (raw['nickname'] ?? '').toString();
      final lastSeen = ((raw['last_seen'] as num?) ?? 0).toInt();
      final prev = byId[id];
      if (prev == null || lastSeen > prev.lastSeen) {
        byId[id] = FederationCandidate(
          agentId: id,
          nickname: nickname,
          lastSeen: lastSeen,
        );
      }
    }

    // 排序：最近在线的优先。★ 必须带 `agentId` 兜底 tiebreaker ——
    // `List.sort` **不稳定**，只按 lastSeen 排会让同分项的顺序随实现漂移，
    // 于是"这次收 A 下次收 B"变得不可复现（本项目已踩过 List.sort 的坑）。
    final picked = byId.values.toList()
      ..sort((a, b) {
        final bySeen = b.lastSeen.compareTo(a.lastSeen);
        if (bySeen != 0) return bySeen;
        return a.agentId.compareTo(b.agentId);
      });

    if (picked.isEmpty) {
      return FederationIntakePlan(
        allowed: false,
        skip: FederationSkip.nothingNew,
        candidates: const [],
        nextEligibleMs: nextEligible,
      );
    }

    // ③ 总量闸：自动收录总数不得越过 maxAutoTotal。
    final remaining = config.maxAutoTotal - currentAutoCount;
    if (remaining <= 0) {
      return FederationIntakePlan(
        allowed: false,
        skip: FederationSkip.quotaReached,
        candidates: const [],
        nextEligibleMs: nextEligible,
      );
    }

    // ② 单次上限 ∩ 剩余额度 ∩ 实际候选数。
    var take = config.maxPerPull;
    if (take > remaining) take = remaining;
    if (take > picked.length) take = picked.length;

    return FederationIntakePlan(
      allowed: true,
      skip: null,
      candidates: List<FederationCandidate>.unmodifiable(picked.take(take)),
      nextEligibleMs: nextEligible,
    );
  }
}
