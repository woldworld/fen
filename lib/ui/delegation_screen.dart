import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/circle_service.dart';
import '../core/db_helper.dart';
import '../core/delegation_service.dart';
import '../core/digest_service.dart';
import '../core/intercard_service.dart';
import '../core/neighbor_source.dart';
import '../core/telemetry.dart';
import '../core/telemetry_store_db.dart';
import '../core/theme_provider.dart';
import '../core/wold_runtime.dart';
import '../l10n/app_localizations.dart';
import 'dashboard_screen.dart';
import 'digest_screen.dart';

/// M1 入场即进圈 + M2 事务委托的界面（PRD §4）。
///
/// 0.46.0：内容**不再分页** —— 托我办 / 我托的 / 我的圈 并成一条可滚动列表，于是
/// 同一份实现既能当**独立页面**（好友卡片菜单 push 进来、可预填对方），也能直接
/// 作为**「社交」页的第 4 个 Tab** 内嵌（见 [DelegationPanel]）。
/// ★ 为什么拉平：内嵌到 Tab 时，若保留自己的 3 个页签就会出现"页签套页签"。
///
/// 数据一律走 `WoldRuntime`（真设备身份 + SQLite），本文件不碰任何平台 API。
class DelegationScreen extends StatelessWidget {
  /// 从名册卡片直接发起时预填的对象（可选）。
  final String? presetPeerId;
  final String? presetPeerName;

  const DelegationScreen({super.key, this.presetPeerId, this.presetPeerName});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context);

    // ★ 本页是「被 push 出来的路由」，不在 MainNavigator 的 PageView 里 ⇒ 拿不到
    //   MainNavigator body 那层品牌渐变背景。若 Scaffold 背景透明，浅色主题下会露出
    //   窗口默认底色（黑），再叠上浅色主题的深色文字 ⇒ 整页漆黑、什么都看不见。
    //   这里自带同一份渐变，与 App 各分页观感一致（深色主题同理，不再透出黑底）。
    //
    // 0.46.0：摘要/看板入口已**下沉到 [DelegationPanel] 顶部** ⇒ 独立页与「社交」页
    // 第 4 个 Tab 的入口完全一致、不会分叉；本 AppBar 只留标题。
    return Container(
      decoration: theme.backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.delegationTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: DelegationPanel(
          presetPeerId: presetPeerId,
          presetPeerName: presetPeerName,
        ),
      ),
    );
  }
}

/// 托办内容面板（**可内嵌**）。
///
/// 不含 Scaffold / AppBar ⇒ 独立页（[DelegationScreen]）与「社交」页第 4 个 Tab
/// 共用**同一份**实现（改一处两边都变，不会分叉）。
///
/// ★ 顶部自带「发起托办 + 每日摘要 + 看板」入口：原先是独立页 AppBar 的动作项，
///   内嵌后 AppBar 不存在了，所以下沉到这里，两处入口才一致。
class DelegationPanel extends StatefulWidget {
  final String? presetPeerId;
  final String? presetPeerName;

  const DelegationPanel({super.key, this.presetPeerId, this.presetPeerName});

  /// ★ 请求**所有在场**的托办面板重新拉数据（自身也会被通知到）。
  ///
  /// 为什么需要"广播"而不是各自 `_load()`：面板带 `AutomaticKeepAliveClientMixin`
  /// 保活后 `initState` 只跑一次 ⇒ ① 切回「社交」页第 4 个页签时**不会自动刷新**；
  /// ② 独立页与页签里的实例可能**同时存在**（页签在下面活着），在其中一处改了数据，
  /// 另一处仍是旧的。⇒ 凡是"改了数据"的地方一律走 [requestReload]。
  static final ValueNotifier<int> reloadTick = ValueNotifier<int>(0);

  /// 见 [reloadTick]。**改了数据就调它**，不要只调自己的 `_load()`。
  static void requestReload() => reloadTick.value++;

  @override
  State<DelegationPanel> createState() => _DelegationPanelState();
}

class _DelegationPanelState extends State<DelegationPanel>
    with AutomaticKeepAliveClientMixin {
  // 内嵌进 TabBarView 时，切走再切回不要丢状态、也不要重跑 _load（页面更稳）。
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  /// `_load()` 是否正在飞行中（见 [_load] 的并发合并）。
  bool _loadInFlight = false;
  /// 飞行中又来了刷新请求 ⇒ 记下来，落地后补跑一次。
  bool _loadPendingAgain = false;
  bool _digestUnread = false;
  String _me = '';
  List<Delegation> _inbox = [];
  List<Delegation> _outbox = [];
  List<Map<String, dynamic>> _circles = [];
  Map<String, int> _counts = {};
  String? _selectedCircleId;
  CircleVisible? _visible;
  List<InterCard> _receivedCards = [];
  List<InterCard> _myCards = [];

  @override
  void initState() {
    super.initState();
    DelegationPanel.reloadTick.addListener(_onReloadTick);
    _checkDigestBadge();
    _load().then((_) {
      if (widget.presetPeerId != null && mounted) {
        _showCreateDialog(presetPeerId: widget.presetPeerId);
      }
    });
  }

  void _onReloadTick() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    DelegationPanel.reloadTick.removeListener(_onReloadTick);
    super.dispose();
  }

  /// 今天是否还没看过每日摘要（"每日一次存在感"红点）。
  Future<void> _checkDigestBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final unread = prefs.getString('digest_last_opened_day') != dayKey;
    if (mounted && unread != _digestUnread) {
      setState(() => _digestUnread = unread);
    } else if (mounted && !unread && _digestUnread) {
      setState(() => _digestUnread = false);
    }
  }

  /// 摘要页动作 → 跳转（摘要页不做导航决策）。
  ///
  /// 0.46.0：托办内容已拉平到一页 ⇒ "去收件箱 / 发件箱 / 我的圈"回到本页即可
  /// （它们现在同屏）；只有"看看板"还需要再 push 一层。
  void _onDigestAction(String actionKind) {
    Navigator.pop(context); // 先回到托办页
    if (actionKind == DigestAction.kindOpenDashboard) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  /// 拉取本页全部数据（收件箱 / 发件箱 / 圈子 / 可见分身 / 互介卡）。
  ///
  /// ★ 并发合并：`requestReload()` 是**广播**，发起方自己也在监听者里
  ///   ⇒ 改一次数据会触发两遍 `_load()`（两遍 SQLite 查询 + 两遍 setState）。
  ///   这里把"飞行中到达的请求"折成一次落地后的补跑：既不会漏掉刷新，
  ///   也不会让同一份数据被拉两遍。
  Future<void> _load() async {
    if (_loadInFlight) {
      _loadPendingAgain = true;
      return;
    }
    _loadInFlight = true;
    try {
      await _loadCore();
    } finally {
      _loadInFlight = false;
    }
    if (_loadPendingAgain && mounted) {
      _loadPendingAgain = false;
      await _load();
    }
  }

  Future<void> _loadCore() async {
    final rt = WoldRuntime.i;
    final me = await rt.myAgentId();
    final inbox = await rt.delegationStore.inbox(me);
    final outbox = await rt.delegationStore.outbox(me);
    final circles = await rt.circleStore.circlesOf(me);

    final circleId = _selectedCircleId ??
        (circles.isEmpty ? null : circles.first['circle_id'] as String);
    CircleVisible? visible;
    if (circleId != null) {
      visible = await rt.circles.visibleFens(circleId: circleId, selfId: me);
    }

    final counts = await (Telemetry.instance?.store is DbTelemetryStore
            ? (Telemetry.instance!.store as DbTelemetryStore).counts()
            : Future<Map<String, int>>.value(const {}));

    final receivedCards = await rt.interCardStore.inbox(me);
    final myCards = await rt.interCardStore.mine(me);

    if (!mounted) return;
    setState(() {
      _me = me;
      _inbox = inbox;
      _outbox = outbox;
      _circles = circles;
      _selectedCircleId = circleId;
      _visible = visible;
      _counts = counts;
      _receivedCards = receivedCards;
      _myCards = myCards;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------- 托办

  Future<void> _showCreateDialog({String? presetPeerId}) async {
    final l10n = AppLocalizations.of(context);
    if (_circles.isEmpty) {
      // 没有圈就发不出托办。原实现只闪一句"建一个圈"让用户自己去找入口，
      // 而用户此刻的意图明确就是"我要托办" ⇒ 直接把建圈框弹出来；
      // 建完再顺回来接着填托办，别让他再点一次「+」。
      await _createCircle();
      if (!mounted) return;
      if (_selectedCircleId == null) return; // 取消 / 建圈失败 ⇒ 到此为止
      await _load(); // 让新圈真正进 `_circles`、可见分身也算出来
      if (!mounted || _circles.isEmpty) return; // 没建成就不再绕一圈
      await _showCreateDialog(presetPeerId: presetPeerId);
      return;
    }

    // ★ 不写 `_selectedCircleId!`：「`_circles` 非空」只说明"有圈"，
    //   选中的那一个仍可能是 null（保活期间圈被别处删掉等），解包失败会直接崩。
    final circleId = _selectedCircleId;
    if (circleId == null) {
      _snack(l10n.errorGeneric);
      return;
    }

    final friends = await DBHelper.getAgentFriends();
    // 下拉要显示**名字**：一串 agent_id 用户看不出该选谁。
    final names = <String, String>{};
    for (final f in friends) {
      final id = f['agent_id'];
      final name = f['agent_name'];
      if (id is String && id.isNotEmpty && name is String && name.isNotEmpty) {
        names[id] = name;
      }
    }
    // 从名册卡片进来时，对方可能不在本机好友表（或名字已改）⇒ 用带进来的名字兜住。
    final presetName = widget.presetPeerName;
    if (presetPeerId != null && presetName != null && presetName.isNotEmpty) {
      names[presetPeerId] = presetName;
    }

    final candidates = <String>{
      ...?_visible?.fens,
      if (presetPeerId != null) presetPeerId,
    }.toList();
    if (candidates.isEmpty) {
      for (final f in friends) {
        final id = f['agent_id'];
        if (id is String && id.isNotEmpty) candidates.add(id);
      }
    }

    String? peer = presetPeerId ?? (candidates.isEmpty ? null : candidates.first);
    final taskCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(l10n.delegationNew),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: peer,
                  decoration: InputDecoration(labelText: l10n.delegationTo),
                  items: candidates
                      .map((id) => DropdownMenuItem(
                          value: id, child: Text(_peerLabel(id, names))))
                      .toList(),
                  onChanged: (v) => setLocal(() => peer = v),
                ),
                TextField(
                  controller: taskCtrl,
                  decoration: InputDecoration(hintText: l10n.delegationTaskHint),
                  maxLines: 2,
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () async {
                  if (peer == null) {
                    _snack(l10n.delegationNoPeer);
                    return;
                  }
                  if (taskCtrl.text.trim().isEmpty) {
                    _snack(l10n.delegationEmptyTask);
                    return;
                  }
                  final res = await WoldRuntime.i.delegations.create(
                    circleId: circleId,
                    fromId: _me,
                    toId: peer!,
                    task: taskCtrl.text.trim(),
                  );
                  if (!mounted) return;
                  if (res.blocked) {
                    Navigator.pop(ctx);
                    await _showBlocked(l10n, res.reason);
                    return;
                  }
                  // 真正投递出去（近场/局域网/云端，哪个通算哪个）
                  final delivered =
                      await WoldRuntime.i.relay.dispatch(res.delegation!);
                  Navigator.pop(ctx);
                  _snack(delivered
                      ? l10n.delegationSent
                      : l10n.delegationOfflineQueued);
                  DelegationPanel.requestReload();
                },
                child: Text(l10n.commonConfirm),
              ),
            ],
          );
        });
      },
    );
  }

  /// 下拉项文案：**有名字就显示名字**，没有才退化成截断的 ID
  /// （对方可能只是"可见分身"、还不在本机好友表里）。
  String _peerLabel(String id, Map<String, String> names) {
    final name = names[id];
    if (name != null && name.isNotEmpty) return name;
    return id.length > 12 ? '${id.substring(0, 12)}…' : id;
  }

  Future<void> _showBlocked(AppLocalizations l10n, String? reason) {
    final isSettlement = reason == 'settlement_not_allowed';
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSettlement
            ? l10n.delegationBlockedTitle
            : l10n.errorInvalidInput),
        content: Text(isSettlement
            ? l10n.delegationBlockedBody
            : l10n.delegationEmptyTask),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  Future<void> _showRespondDialog(Delegation d) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d.task),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: l10n.delegationAskResponse),
          maxLines: 2,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _respond(d, DelegationState.declined, null);
              if (mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.delegationActDecline),
          ),
          TextButton(
            onPressed: () async {
              await _respond(d, DelegationState.needsHuman, ctrl.text.trim());
              if (mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.delegationActNeedsHuman),
          ),
          TextButton(
            onPressed: () async {
              await _respond(d, DelegationState.answered, ctrl.text.trim());
              if (mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.delegationActDone),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(Delegation d, DelegationState state, String? resp) async {
    final updated = await WoldRuntime.i.delegations.respond(
      id: d.id,
      responderId: _me,
      state: state,
      response: (resp == null || resp.isEmpty) ? null : resp,
    );
    if (updated == null) {
      if (mounted) _snack(AppLocalizations.of(context).errorGeneric);
      return;
    }
    // 回执要发回发起方，否则对方永远看不到"办好了"
    await WoldRuntime.i.relay.dispatchReceipt(updated);
    DelegationPanel.requestReload();
  }

  Future<void> _revoke(Delegation d) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.delegationRevoke),
            content: Text(l10n.delegationRevokeConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.commonCancel)),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.delegationRevoke)),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await WoldRuntime.i.delegations.revoke(id: d.id, ownerId: _me);
    DelegationPanel.requestReload();
  }

  /// 撤回互介卡（发出后 24h 内）：本机标记 + 撤回报文让对方删除（验收③）。
  Future<void> _revokeCard(InterCard c) async {
    final updated = await WoldRuntime.i.intercards.revoke(id: c.id, revokerId: _me);
    if (updated != null) {
      await WoldRuntime.i.intercardRelay.dispatchRevoke(updated);
    }
    DelegationPanel.requestReload();
  }

  // ---------------------------------------------------------------- 圈子

  Future<void> _createCircle() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.circleCreate),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: l10n.circleNameHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.commonConfirm)),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    // ★ 0.115.0：圈 ID 加 6 位随机后缀（同 `delegation_service`）——
    //   纯毫秒时间戳在同毫秒内会撞，而圈 ID 撞了 = 两个不同的圈同名。
    final id =
        'c_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_randSuffix()}';
    await WoldRuntime.i.circles.createCircle(
      id: id,
      name: name,
      founderId: _me,
    );
    if (!mounted) return;
    _snack(l10n.circleCreated);
    setState(() => _selectedCircleId = id);
    DelegationPanel.requestReload();
  }

  Future<void> _generateInvite() async {
    final l10n = AppLocalizations.of(context);
    final id = _selectedCircleId;
    if (id == null) return;
    final row = _circles.firstWhere(
      (c) => c['circle_id'] == id,
      orElse: () => <String, dynamic>{'name': id},
    );
    final invite = await WoldRuntime.i.circles.createInvite(
      circleId: id,
      circleName: (row['name'] as String?) ?? id,
      inviterId: _me,
    );
    final code = invite.encode();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.circleInviteCode),
        content: SelectableText(code),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonOk)),
        ],
      ),
    );
  }

  Future<void> _joinWithCode() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.circleJoin),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: l10n.circleJoinHint),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.commonConfirm)),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    final m = await WoldRuntime.i.circles.acceptInvite(code: code, memberId: _me);
    if (!mounted) return;
    _snack(m == null ? l10n.circleJoinFailed : l10n.circleJoined);
    DelegationPanel.requestReload();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------- 渲染

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    final theme = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.isDark;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: theme.accentColor));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        // 顶部入口行：发起托办（原 FAB 已移除：内嵌到 Tab 时没有 FAB 可用）
        // + 每日摘要（今天没看过 → 红点）+ 最小看板。三者都是**本页自己的事**，
        // 放一起、两处入口一致。
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _showCreateDialog(),
                icon: const Icon(Icons.add_task),
                label: Text(l10n.delegationNew),
              ),
            ),
            const SizedBox(width: 6),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.wb_sunny_outlined),
                  tooltip: l10n.digestTitle,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DigestScreen(onNavigate: _onDigestAction),
                      ),
                    );
                    _checkDigestBadge(); // 回来后刷新红点
                  },
                ),
                if (_digestUnread)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.query_stats),
              tooltip: l10n.dashboardTitle,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen())),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _header(l10n.delegationTabInbox),
        if (_inbox.isEmpty)
          _empty(l10n.delegationEmptyInbox)
        else
          ..._inbox.map((d) => _buildCard(l10n, d, true)),
        const SizedBox(height: 16),

        _header(l10n.delegationTabOutbox),
        if (_outbox.isEmpty)
          _empty(l10n.delegationEmptyOutbox)
        else
          ..._outbox.map((d) => _buildCard(l10n, d, false)),
        const SizedBox(height: 16),

        _header(l10n.delegationTabCircle),
        ..._circleSection(l10n, theme, isDark),
      ],
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  Widget _buildCard(AppLocalizations l10n, Delegation d, bool incoming) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final other = incoming ? d.fromId : d.toId;
    final stateColor = switch (d.state) {
      DelegationState.answered => Colors.green,
      DelegationState.needsHuman => Colors.orange,
      DelegationState.declined => Colors.red,
      DelegationState.revoked || DelegationState.expired => Colors.grey,
      DelegationState.pending => Colors.blueGrey,
    };

    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(d.task,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: stateColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_stateLabel(l10n, d.state),
                      style: const TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${incoming ? '←' : '→'} $other · ${_time(d.createdAtMs)}',
              style: TextStyle(
                  fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
            ),
            if (d.response != null && d.response!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(d.response!),
            ],
            if (incoming && d.state == DelegationState.pending) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showRespondDialog(d),
                  // ★ 这里原写 `delegationActDone`（"办好了"），但点开是"办好了 /
                  //   需本人确认 / 拒绝"三选一 ⇒ 按钮像是在替主人先答应了。改成中性
                  //   的"回应"，选什么由主人在弹窗里决定。
                  child: Text(l10n.delegationActRespond),
                ),
              ),
            ],
            if (!incoming && d.canRevoke) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _revoke(d),
                  child: Text(l10n.delegationRevoke),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _stateLabel(AppLocalizations l10n, DelegationState s) => switch (s) {
        DelegationState.pending => l10n.delegationStatePending,
        DelegationState.answered => l10n.delegationStateAnswered,
        DelegationState.needsHuman => l10n.delegationStateNeedsHuman,
        DelegationState.declined => l10n.delegationStateDeclined,
        DelegationState.revoked => l10n.delegationStateRevoked,
        DelegationState.expired => l10n.delegationStateRevoked,
      };

  String _time(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// 我的圈 + 互介卡 + 埋点自检（原 `_buildCircleTab` 的 children，
  /// 去掉 ListView 外壳后并入主列表）。
  List<Widget> _circleSection(
      AppLocalizations l10n, ThemeProvider theme, bool isDark) {
    final v = _visible;

    return [
      // ---- M1 验收卡：可见分身
      if (v != null)
        Card(
          color: v.meetsAcceptance
              ? Colors.green.withValues(alpha: 0.12)
              : Colors.orange.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      v.meetsAcceptance ? Icons.check_circle : Icons.error_outline,
                      color: v.meetsAcceptance ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        v.meetsAcceptance
                            ? l10n.circleAcceptancePass
                            : l10n.circleAcceptanceFail,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(l10n.circleVisibleSummary(v.fens.length, v.nonInviterCount)),
                // 兜底来源必须写清楚：真机复核要能回答"这几个可见分身哪来的"
                if (v.fromFallback.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.circleFallbackNote(
                          v.fromFallback.length, NeighborSource.lastSource),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

      // ---- 收到的互介卡（M3，链路 β）
      if (_receivedCards.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(l10n.intercardReceivedTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        for (final c in _receivedCards)
          Card(
            child: ListTile(
              dense: true,
              title: Text('${c.fields['nickname'] ?? c.ownerId} · ${c.reason}',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(c.topics.join(' · '),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],

      // ---- 我发出的互介卡（24h 内可撤回）
      if (_myCards.any((c) => c.isConfirmed && c.revokedAtMs == null)) ...[
        const SizedBox(height: 16),
        Text(l10n.intercardMineTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        for (final c in _myCards)
          if (c.isConfirmed && c.revokedAtMs == null)
            Card(
              child: ListTile(
                dense: true,
                title: Text('→ ${c.toId} · ${c.reason}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: c.canRevokeAt(DateTime.now().millisecondsSinceEpoch)
                    ? TextButton(
                        onPressed: () => _revokeCard(c),
                        child: Text(l10n.intercardRevoke),
                      )
                    : null,
              ),
            ),
      ],

      // ---- 我的圈
      const SizedBox(height: 8),
      if (_circles.isEmpty)
        Card(
          child: ListTile(
            leading: const Icon(Icons.group_add),
            title: Text(l10n.circleCreate),
            onTap: _createCircle,
          ),
        )
      else
        ..._circles.map((c) {
          final id = c['circle_id'] as String;
          final selected = id == _selectedCircleId;
          return Card(
            color: selected
                ? theme.accentColor.withValues(alpha: 0.12)
                : (isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9)),
            child: ListTile(
              leading: const Icon(Icons.groups),
              title: Text(c['name'] as String? ?? id),
              subtitle: Text(
                  '$id · ${l10n.circleMemberCount((c['member_count'] as num?)?.toInt() ?? 0)}'),
              onTap: () async {
                // ★ 这里**刻意不走** `DelegationPanel.requestReload()`：
                //   切圈是**本机 UI 选择**（看哪个圈的可见分身），不是数据变更；
                //   广播出去会让独立页里那个面板也跟着切圈 —— 那是另一处的选择，不该被改动。
                setState(() => _selectedCircleId = id);
                await _load();
              },
            ),
          );
        }),

      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _createCircle,
              icon: const Icon(Icons.group_add),
              label: Text(l10n.circleCreate),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _generateInvite,
              icon: const Icon(Icons.share),
              label: Text(l10n.circleGenerateInvite),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _joinWithCode,
              icon: const Icon(Icons.vpn_key),
              label: Text(l10n.circleJoin),
            ),
          ),
        ],
      ),

      // ---- 埋点自检（验收需要能当场看到事件真的落地了）
      const SizedBox(height: 16),
      Text(l10n.telemetryCounts,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      if (_counts.isEmpty)
        Text(l10n.telemetryEmpty)
      else
        ..._counts.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                Text(e.value.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
    ];
  }
}

/// 6 位随机后缀（base36）—— 供圈 ID 去碰撞用。
///
/// ★ 0.115.0：圈 ID 原为**纯毫秒时间戳** ⇒ 同毫秒建两个圈会撞名。
String _randSuffix() {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
  final b = StringBuffer();
  for (var i = 0; i < 6; i++) {
    b.write(chars[Random.secure().nextInt(chars.length)]);
  }
  return b.toString();
}
