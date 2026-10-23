import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'cloud_service.dart';
import 'db_helper.dart';
import 'federation_intake.dart';
import 'l10n_holder.dart';

/// 一次自动拉取的执行结果（给 UI 说人话 + 给日志留痕）。
class FederationAutoPullResult {
  const FederationAutoPullResult({
    required this.attempted,
    required this.added,
    required this.skip,
    required this.error,
    required this.nextEligibleMs,
  });

  /// 是否**真的发起了**这次拉取（开关开 + 过了节流窗）。false 表示被闸挡下。
  final bool attempted;

  /// 本次收录进陌生档的条数。
  final int added;

  /// 未发起时的原因；发起时（含中途网络失败）为 null。
  final FederationSkip? skip;

  /// 发起但失败时的原因文案（网络/未配置 Hub/无身份）；成功为 null。
  final String? error;

  /// 下一次允许自动拉取的时刻（epoch 毫秒）。
  final int nextEligibleMs;

  @override
  String toString() => 'FederationAutoPullResult(attempted=$attempted, '
      'added=$added, skip=$skip, error=$error, nextEligibleMs=$nextEligibleMs)';
}

/// 联邦名册**自动拉取**的宿主编排（开关 → 云 → 判据 → 落库）。
///
/// 职责边界（与 [FederationIntake] 的分工）：
///   · 本类只做"取数 / 落库 / 记节流 / 读开关"，**判据一条都不写在这里**；
///   · 判据（节流/单次上限/总量上限/排除）全在 [FederationIntake.plan]（纯逻辑）。
///
/// ★★ 红线（与 PRD §9.1 / `agent_boundary` KB 条目一致）：
///   本类**不做任何对外动作** —— 不搭讪、不发信、不碰审查网关卡。
///   自动收录只是把"中转站里公开可读的注册名册"里、主人还没收录的人
///   放进本地陌生档；此后是否搭讪，仍走既有的 网关决策 → `_auditDraft`（fail-closed）
///   → 观察模式（默认开）→ 预算闸。这里**一行绕过都不加**。
///   由 `tool/verify_federation_auto_pull.dart` 静态钉住：本文件不得出现任何
///   发信/搭讪函数名。
class FederationAutoPull {
  FederationAutoPull._();

  /// 开关的 prefs 键。**默认关**（键不存在 = 关）——
  /// 让机器"自主把人拉进主人的名册"是**敏感的自主性**，必须由主人显式开启。
  static const String prefsEnabled = 'federation_auto_pull';

  /// 上次成功拉取的时刻（epoch 毫秒），节流用。
  static const String prefsLastMs = 'federation_auto_pull_last_ms';

  /// 生产默认参数（6h 节流 / 单次 20 / 总量 200）。
  static const FederationIntakeConfig defaultConfig = FederationIntakeConfig();

  /// 读开关（默认关：键不存在或非 true 均为关）。
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsEnabled) ?? false;
  }

  /// 写开关（**唯一写入方**：UI 只调这里，不自己 `prefs.setBool`）。
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsEnabled, enabled);
  }

  /// 执行一次自动拉取（幂等、可安全重复调用）。
  ///
  /// [force] 为 true 时**跳过节流窗**（仅用于主人刚把开关打开的当次，
  /// 好让效果立刻可见）；单次上限与总量上限**仍然生效**。
  /// [nowMs] 仅供离线复算注入。
  static Future<FederationAutoPullResult> maybePull({
    bool force = false,
    int? nowMs,
    FederationIntakeConfig config = defaultConfig,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 第 0 道闸：开关。**默认关** —— 关着就直接返回，绝不发任何网络请求。
    if (!(prefs.getBool(prefsEnabled) ?? false)) {
      return const FederationAutoPullResult(
        attempted: false,
        added: 0,
        skip: FederationSkip.disabled,
        error: null,
        nextEligibleMs: 0,
      );
    }

    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final lastMs = prefs.getInt(prefsLastMs) ?? 0;

    // 第 1 道闸：身份。没有分身身份就无从签名，直接早退（不发请求）。
    final myId = await DBHelper.getAmbassador('my_agent_id') ?? '';
    if (myId.isEmpty) {
      return FederationAutoPullResult(
        attempted: false,
        added: 0,
        skip: null,
        error: L10nHolder.l10n.socialFederationNoIdentity,
        nextEligibleMs: lastMs > 0 ? lastMs + config.cooldown.inMilliseconds : 0,
      );
    }

    // 取本地现状：已在名册里的人（含手动+自动）+ 机器自动收录的行数。
    final friends = await DBHelper.getAgentFriends();
    final knownIds = friends
        .map((f) => (f['agent_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet();
    final autoCount = friends
        .where((f) => ((f['auto_pulled'] as num?) ?? 0).toInt() == 1)
        .length;

    // 判据（纯逻辑）：节流 / 去重 / 上限。force 时把 lastPullMs 传 0 以放行节流闸，
    // 但单次与总量上限仍在 plan 内生效。
    FederationIntakePlan plan = FederationIntake.plan(
      roster: const [],
      myAgentId: myId,
      knownIds: knownIds,
      lastPullMs: force ? 0 : lastMs,
      nowMs: now,
      currentAutoCount: autoCount,
      config: config,
    );

    // 节流闸在"还没取名册"时就能判 —— 若已判为冷却，直接返回，省一次网络往返。
    if (!plan.allowed && plan.skip == FederationSkip.cooldown) {
      return FederationAutoPullResult(
        attempted: false,
        added: 0,
        skip: FederationSkip.cooldown,
        error: null,
        nextEligibleMs: plan.nextEligibleMs,
      );
    }

    // 取名册（唯一一次网络请求）。
    final roster = await CloudService().fetchA2aRoster(myId);
    final fetchErr = CloudService().lastError;

    // 网络/配置失败：**不记节流**（失败不算一次成功拉取），留待下次重试。
    if (roster.isEmpty && fetchErr != null) {
      AppLogger.w('federation.autopull', '拉取失败：$fetchErr');
      return FederationAutoPullResult(
        attempted: true,
        added: 0,
        skip: null,
        error: fetchErr,
        nextEligibleMs: lastMs > 0 ? lastMs + config.cooldown.inMilliseconds : 0,
      );
    }

    // 拿到名册后重算判据（含 nothingNew / quotaReached）。
    plan = FederationIntake.plan(
      roster: roster,
      myAgentId: myId,
      knownIds: knownIds,
      lastPullMs: force ? 0 : lastMs,
      nowMs: now,
      currentAutoCount: autoCount,
      config: config,
    );

    if (!plan.allowed) {
      // 名册确实取到了（无错），无论"没新面孔"还是"额度满"，都记一次节流，
      // 避免紧接着的调用再次空跑网络。
      await prefs.setInt(prefsLastMs, now);
      AppLogger.i('federation.autopull',
          '未收录（${plan.skip}），名册 ${roster.length} 条，自动存量 $autoCount');
      return FederationAutoPullResult(
        attempted: true,
        added: 0,
        skip: plan.skip,
        error: null,
        nextEligibleMs: now + config.cooldown.inMilliseconds,
      );
    }

    // 落库：逐个走**唯一写入方** insertAgentFriend(autoPulled: true)。
    // 不抓 Agent Card（省 N 次往返；名片可在用户打开详情时再取）。
    final l10n = L10nHolder.l10n;
    var added = 0;
    for (final c in plan.candidates) {
      final name = c.nickname.trim().isEmpty ? l10n.socialAnonAgent : c.nickname.trim();
      await DBHelper.insertAgentFriend(
        name,
        l10n.socialFederationSource,
        c.agentId,
        'stranger',
        l10n.socialFederationAutoNote,
        l10n.socialFederationDiscovered,
        '🌐',
        autoPulled: true,
      );
      added++;
    }

    await prefs.setInt(prefsLastMs, now);
    AppLogger.i('federation.autopull',
        '自动收录 $added 条联邦名册项 → 陌生档（未发任何消息）');
    return FederationAutoPullResult(
      attempted: true,
      added: added,
      skip: null,
      error: null,
      nextEligibleMs: now + config.cooldown.inMilliseconds,
    );
  }
}
