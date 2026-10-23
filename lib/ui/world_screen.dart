import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/agent_service.dart';
import '../core/db_helper.dart';
import '../core/god_service.dart';
import '../core/theme_provider.dart';
import '../core/room_role.dart';
import '../core/wold_runtime.dart';
import '../core/world_bridge_service.dart';
import '../core/world_service.dart';
import '../l10n/app_localizations.dart';
import 'intercard_topics.dart';
import 'help_dot.dart';

/// 关闭房间的二次确认框（**仅房主**入口共用一份）。
///
/// ★ 为什么必须二次确认：关闭会把房间**从公开面摘下来**（陌生人再也搜不到、也进不来），
///   这是房主之外所有人都会看到的不可逆观感变化 —— 一次误触代价太大。
/// ★ 为什么抽成公共函数：列表页与房间页各要一个入口，两处各写一份 AlertDialog
///   迟早出现"一处改了文案、另一处还是旧的"（本仓反复强调：能共用的判定/文案只留一份）。
Future<bool> _confirmCloseRoom(BuildContext context, AppLocalizations l10n) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text(l10n.worldRoomCloseTitle),
      content: Text(l10n.worldRoomCloseBody),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(l10n.commonCancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(dCtx, true),
          child: Text(l10n.worldRoomCloseConfirm),
        ),
      ],
    ),
  );
  return r == true;
}

/// 官方大厅（服务端固定 `id == 'lobby'`，名字写死在 `lib/hub/world.js`）的名字与简介
/// 是**服务端数据**，但它是**系统房间、不是用户内容** ⇒ 由**客户端**按当前语言渲染
/// （PRD v1.70 / 交付 §82）。其余房间一律照显服务端给的值。
/// ★ 为什么不改服务端：`world.js` 是**多端共用**的部署文件，改它要重发服务端；而
///   "官方大厅叫什么"是**展示层**的事，客户端一处映射即可（且不碰任何用户数据）。
String worldRoomName(Map<String, dynamic> room, AppLocalizations l10n) {
  final id = (room['id'] ?? room['room_id'] ?? '').toString();
  if (id == 'lobby') return l10n.worldLobbyName;
  return room['name']?.toString() ?? id;
}

/// 官方大厅的简介同样本地化；其余房间照显服务端 topic。
String worldRoomTopic(Map<String, dynamic> room, AppLocalizations l10n) {
  final id = (room['id'] ?? room['room_id'] ?? '').toString();
  if (id == 'lobby') return l10n.worldLobbyTopic;
  return room['topic']?.toString() ?? '';
}

/// 世界页（Step 2）：房间列表、加入/退出、世界日报。
/// 观察模式：入站消息只进日志与记忆流；主人可对任意消息一键生成"建议卡"。
class WorldScreen extends StatefulWidget {
  const WorldScreen({Key? key}) : super(key: key);

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  String _myId = '';
  List<Map<String, dynamic>> _rooms = [];
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _creating = false;
  /// M5：一次采集成型的跨圈判定输入（房间出现记录 + 我的圈 + 已识人 + 已建边）。
  /// 判定本身是纯函数，所以这里只放事实，拿它给每个房间现场算池子与活跃度。
  WorldBridgeInput? _bridgeInput;
  BridgeMetric? _metric;
  // GOD 控制室（Step 4）：仅在设置中配置了桥接地址时出现
  bool _godConfigured = false;
  bool _godBusy = false;
  Map<String, dynamic>? _godStatus;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _myId = await DBHelper.getAmbassador('my_agent_id') ?? '';
    if (_myId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final rooms = await WorldService().fetchRooms(_myId);
    final report = await WorldService().fetchReport(_myId);
    _godConfigured = await GodService().isConfigured();
    final godStatus = _godConfigured ? await GodService().fetchStatus(_myId) : null;

    // M5：跨圈边只从房间长出 —— 把本地事实采一次，逐房间现场判定。
    // 运行时未就绪（init 尚未完成）时不阻塞房间列表渲染。
    WorldBridgeInput? bridgeInput;
    BridgeMetric? metric;
    if (WoldRuntime.i.isReady) {
      try {
        bridgeInput = await WoldRuntime.i.bridgeInput(_myId);
        metric = WoldRuntime.i.bridges.metric(bridgeInput);
      } catch (_) {
        // 采集失败只影响「朋友池互荐」区块，房间列表照常可用
        bridgeInput = null;
        metric = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _report = report;
      _bridgeInput = bridgeInput;
      _metric = metric;
      _godStatus = godStatus;
      _loading = false;
    });
  }

  Future<void> _refreshGod() async {
    final godStatus = await GodService().fetchStatus(_myId);
    if (!mounted) return;
    setState(() => _godStatus = godStatus);
  }

  Future<void> _godCommand(String action, String okMsg,
      {Map<String, dynamic> fields = const {}}) async {
    if (_godBusy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _godBusy = true);
    final ok = await GodService().command(_myId, action, fields: fields);
    if (!mounted) return;
    setState(() => _godBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? okMsg : l10n.worldCmdFailed(GodService().lastError ?? l10n.worldUnknownError)),
    ));
    _refreshGod();
  }

  /// 提问小镇：目标留空 = 全镇
  Future<void> _showAskDialog(ThemeProvider theme) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.worldAskTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.worldAskHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              decoration: InputDecoration(
                  labelText: l10n.worldAskTargetLabel),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.worldAskSend),
          ),
        ],
      ),
    );
    if (sent != true || ctrl.text.trim().isEmpty) return;
    await _godCommand('ask', l10n.worldAskOk,
        fields: {'question': ctrl.text.trim(), 'target': targetCtrl.text.trim()});
  }

  /// 注入干预：内容进入小镇的下一步（next step）
  Future<void> _showInterveneDialog(ThemeProvider theme) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.worldInterveneTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.worldInterveneBody,
                style: TextStyle(fontSize: 12, color: theme.isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.worldInterveneHint),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.worldInterveneSend),
          ),
        ],
      ),
    );
    if (sent != true || ctrl.text.trim().isEmpty) return;
    await _godCommand('intervene', l10n.worldInterveneOk,
        fields: {'instructions': ctrl.text.trim()});
  }

  Future<void> _stopGod() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.worldStopTitle),
        content: Text(l10n.worldStopBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.worldStop),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _godCommand('stop', l10n.worldStopOk);
  }

  Future<void> _leave(Map<String, dynamic> room) async {
    final l10n = AppLocalizations.of(context);
    final ok = await WorldService().leaveRoom(_myId, room['id'].toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l10n.worldLeft(worldRoomName(room, l10n)) : l10n.worldLeaveFailed(WorldService().lastError ?? l10n.worldUnknownError)),
    ));
    _refresh();
  }

  /// 房主手动关闭房间（**仅房主**）—— 确认后房间转"只读留档"。
  /// 服务端会重新核 owner，客户端传什么都不算数；这里的按钮只对房主显示。
  Future<void> _close(Map<String, dynamic> room) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirmCloseRoom(context, l10n)) return;
    final ok = await WorldService().closeRoom(_myId, room['id'].toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.worldRoomClosedOk(worldRoomName(room, l10n))
          : l10n.worldRoomCloseFailed(WorldService().lastError ?? l10n.worldUnknownError)),
    ));
    _refresh();
  }

  Future<void> _createRoom() async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    String mode = 'free';
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(l10n.worldCreateRoomTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: l10n.worldRoomNameLabel)),
              const SizedBox(height: 12),
              TextField(controller: topicCtrl, decoration: InputDecoration(labelText: l10n.worldTopicLabel)),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'free', label: Text(l10n.worldModeFree)),
                  ButtonSegment(value: 'turn', label: Text(l10n.worldModeTurn)),
                ],
                selected: {mode},
                onSelectionChanged: (v) => setDialogState(() => mode = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(l10n.commonCancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(l10n.worldCreate),
            ),
          ],
        ),
      ),
    );
    if (created != true || nameCtrl.text.trim().isEmpty) return;

    setState(() => _creating = true);
    // room_id 由名称转写：非 [a-z0-9_-] 字符替换为下划线，末尾加随机后缀防撞
    final raw = nameCtrl.text.trim().toLowerCase();
    final slug = raw.replaceAll(RegExp(r'[^a-z0-9_-]'), '_').replaceAll(RegExp(r'_+'), '_');
    final roomId =
        'r_${slug.isEmpty ? 'room' : slug.substring(0, slug.length.clamp(1, 26))}${DateTime.now().millisecondsSinceEpoch % 1000}';

    final ok = await WorldService()
        .createRoom(_myId, roomId, nameCtrl.text.trim(), topicCtrl.text.trim(), mode);
    if (!mounted) return;
    setState(() => _creating = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.worldCreatedPrivate
          : (WorldService().lastErrorCode == 'my_rooms_full'
              ? l10n.worldMyRoomsFull
              : l10n.worldCreateFailed(
                  WorldService().lastError ?? l10n.worldNoWorldUrl))),
    ));
    _refresh();
  }

  /// 加入；撞上"个人房需审批"时**顺势转成申请**，而不是弹一句看不懂的 403。
  ///
  /// ★ 为什么不让「加入」按钮直接报错：服务端已经把个人房从列表里过滤掉了，
  ///   列表上还能点到的非官方房基本只有"官方房变私有"这类边界情形 ——
  ///   此时把人**引导到申请流程**才是对的动作，报错只是把路堵死。
  Future<void> _join(Map<String, dynamic> room) async {
    final l10n = AppLocalizations.of(context);
    final ok = await WorldService().joinRoom(_myId, room['id'].toString());
    if (!mounted) return;
    if (!ok && WorldService().lastErrorCode == 'need_approval') {
      await _requestJoin(room);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l10n.worldJoined(worldRoomName(room, l10n)) : l10n.worldJoinFailed(WorldService().lastError ?? l10n.worldUnknownError)),
    ));
    _refresh();
  }

  /// 申请加入（个人房的**唯一**入口；官方房在这里会被服务端直接放行）
  Future<void> _requestJoin(Map<String, dynamic> room) async {
    final l10n = AppLocalizations.of(context);
    final noteCtrl = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.worldRequestJoin),
        content: TextField(
          controller: noteCtrl,
          decoration: InputDecoration(labelText: l10n.worldRequestNoteLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(l10n.worldRequestJoin)),
        ],
      ),
    );
    if (send != true) return;
    final result = await WorldService()
        .requestJoin(_myId, room['id'].toString(), note: noteCtrl.text.trim());
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.worldRequestFailed(
            WorldService().lastError ?? l10n.worldUnknownError)),
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result == 'joined'
          ? l10n.worldJoined(worldRoomName(room, l10n))
          : l10n.worldRequestSent),
    ));
    _refresh();
  }

  /// 按房间号查找（QQ 群号模式）：个人房不出现在列表里，只能凭号找到再申请。
  Future<void> _searchRoom() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.worldSearchTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.worldSearchHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(l10n.worldSearchBtn)),
        ],
      ),
    );
    if (go != true) return;
    final roomId = ctrl.text.trim();
    if (roomId.isEmpty) return;
    final data = await WorldService().fetchRoom(_myId, roomId);
    if (!mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(WorldService().lastErrorCode == 'room_not_found'
            ? l10n.worldSearchNotFound(roomId)
            : l10n.worldRequestFailed(
                WorldService().lastError ?? l10n.worldUnknownError)),
      ));
      return;
    }
    final room = Map<String, dynamic>.from(data['room'] as Map? ?? const {});
    final isMember = room['i_am_member'] == true;
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(worldRoomName(room, l10n)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${room['id']}', style: const TextStyle(fontSize: 12)),
            if (worldRoomTopic(room, l10n).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(worldRoomTopic(room, l10n)),
            ],
            const SizedBox(height: 6),
            Text(room['official'] == true ? l10n.worldBadgeOfficial : l10n.worldNeedApproval,
                style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dCtx);
              if (isMember) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => WorldRoomScreen(room: room, myAgentId: _myId)));
              } else {
                _requestJoin(room);
              }
            },
            child: Text(isMember
                ? l10n.worldRoomEnter
                : (room['request_pending'] == true ? l10n.worldBadgePending : l10n.worldRequestJoin)),
          ),
        ],
      ),
    );
  }

  /// 房主视角：本房的待审批列表（同意 ⇒ 直接入内；拒绝 ⇒ 删申请）
  Future<void> _showRequests(Map<String, dynamic> room) async {
    final l10n = AppLocalizations.of(context);
    final list =
        await WorldService().fetchJoinRequests(_myId, roomId: room['id'].toString());
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.worldRequestsTitle('${list.length}')),
        content: SizedBox(
          width: double.maxFinite,
          child: list.isEmpty
              ? Text(l10n.worldRequestsEmpty)
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final q = list[i];
                    final name = q['nickname']?.toString() ??
                        q['agent_id']?.toString() ??
                        '';
                    final note = q['note']?.toString() ?? '';
                    Future<void> handle(bool approve) async {
                      // ★ 先把 Navigator 取到手：await 之后再用 `dCtx` 属于
                      //   "跨异步间隙用 BuildContext"（页面的 mounted 守不住对话框的 context）。
                      final nav = Navigator.of(dCtx);
                      final ok = await WorldService().handleJoinRequest(
                          _myId, room['id'].toString(), q['agent_id'].toString(), approve);
                      if (!mounted) return;
                      nav.pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? (approve ? l10n.worldApproveOk(name) : l10n.worldRejectOk(name))
                            : l10n.worldHandleFailed(
                                WorldService().lastError ?? l10n.worldUnknownError)),
                      ));
                      _refresh();
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      subtitle: note.isEmpty ? null : Text(note),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(onPressed: () => handle(true), child: Text(l10n.worldApprove)),
                          TextButton(onPressed: () => handle(false), child: Text(l10n.worldReject)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  /// 分组：官方房（全员可见）在前，其余（我建的 / 我加入的 / 我申请的）在后。
  /// ★ 分组本身就是规则的可视化 —— 主人一眼能分清"哪些是官方的、哪些只属于我"。
  List<Widget> _buildRoomSections(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final official = _rooms.where((r) => r['official'] == true).toList();
    final mine = _rooms.where((r) => r['official'] != true).toList();
    final out = <Widget>[];
    if (official.isNotEmpty) {
      out.add(_sectionHeader(l10n.worldSectionOfficial, theme));
      out.addAll(official.map((r) => _buildRoomCard(r, theme, isDark)));
    }
    if (mine.isNotEmpty) {
      out.add(_sectionHeader(l10n.worldSectionMine, theme));
      out.addAll(mine.map((r) => _buildRoomCard(r, theme, isDark)));
    }
    return out;
  }

  Widget _sectionHeader(String title, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: theme.accentColor),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: theme.accentColor));
    }
    if (_myId.isEmpty) {
      return Center(child: Text(l10n.worldNoIdentity));
    }

    return Container(
      decoration: theme.backgroundDecoration,
      child: RefreshIndicator(
        color: theme.accentColor,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_godConfigured) ...[
              _buildGodCard(theme, isDark),
              const SizedBox(height: 16),
            ],
            _buildReportCard(theme, isDark),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.explore, color: theme.accentColor),
                const SizedBox(width: 8),
                Text(l10n.worldRoomsHeader, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(width: 4),
                HelpAction(topic: HelpTopic.worldOverview, color: theme.accentColor),
                const Spacer(),
                _creating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ★ 按房间号查找：个人房不进列表，这条入口是找到它们的**唯一**路径
                          IconButton(
                            icon: const Icon(Icons.search, size: 20),
                            tooltip: l10n.worldSearchTitle,
                            onPressed: _searchRoom,
                          ),
                          TextButton.icon(
                            onPressed: _createRoom,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(l10n.worldCreateRoom),
                          ),
                        ],
                      ),
              ],
            ),
            const SizedBox(height: 8),
            if (_rooms.isEmpty)
              Card(
                color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(l10n.worldNoRooms, textAlign: TextAlign.center)),
                ),
              )
            else
              ..._buildRoomSections(theme, isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// GOD 控制室卡片：实时状态 + 暂停/继续/单步/停止 + 提问/注入
  Widget _buildGodCard(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final data = _godStatus;
    final exp = data?['experiment'];
    final status = data?['status'];
    String statusLine;
    if (data == null) {
      statusLine = GodService().lastError ?? l10n.worldGodUnreachable;
    } else if (status is Map) {
      final parts = <String>[];
      if (status['paused'] == true) {
        parts.add(l10n.worldGodPaused);
      } else if (status['paused'] == false) {
        parts.add(l10n.worldGodRunning);
      }
      if (status['step'] != null) parts.add(l10n.worldGodStep('${status['step']}'));
      statusLine = parts.isEmpty
          ? status.toString()
          : parts.join(' · ');
    } else {
      statusLine = l10n.worldGodStatusUnknown;
    }

    return Card(
      color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.tune, color: theme.accentColor),
              const SizedBox(width: 8),
              Text(l10n.worldGodTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: l10n.worldRefreshStatus,
                onPressed: _godBusy ? null : _refreshGod,
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              exp is Map
                  ? l10n.worldGodTown('${exp['hypothesis_id']}', '${exp['experiment_id']}')
                  : l10n.worldGodNoExperiment,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 6),
            Text(statusLine, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _godAction(theme, l10n.worldGodResume, () => _godCommand('auto', l10n.worldGodResumeOk)),
                _godAction(theme, l10n.worldGodPause, () => _godCommand('pause', l10n.worldGodPauseOk)),
                _godAction(theme, l10n.worldGodStepBtn, () => _godCommand('run-step', l10n.worldGodStepOk)),
                _godAction(theme, l10n.worldGodStopBtn, _stopGod, danger: true),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _godAction(theme, l10n.worldGodAskBtn, () => _showAskDialog(theme)),
                _godAction(theme, l10n.worldGodInterveneBtn, () => _showInterveneDialog(theme)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _godAction(ThemeProvider theme, String label, VoidCallback onTap, {bool danger = false}) {
    final busy = _godBusy;
    return OutlinedButton(
      onPressed: busy ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? Colors.redAccent : theme.accentColor,
        side: BorderSide(color: danger ? Colors.redAccent : theme.accentColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  // ------------------------------------------------------------------
  // M5 文案：结构化枚举 → 显示文案只在这一处，UI 不再散落分支
  // ------------------------------------------------------------------

  String _vibrancyLabel(AppLocalizations l10n, RoomVibrancy v) => switch (v) {
        RoomVibrancy.hot => l10n.worldVibrancyHot,
        RoomVibrancy.warm => l10n.worldVibrancyWarm,
        RoomVibrancy.cold => l10n.worldVibrancyCold,
      };

  /// 「凭什么推荐他」：共同房间数（≥2 才有意义）+ 累计发言数，全部可复算。
  String _whyLine(AppLocalizations l10n, BridgeCandidate c) {
    final parts = <String>[];
    if (c.sharedRooms > 1) {
      parts.add(l10n.worldBridgeSharedRooms('${c.sharedRooms}'));
    }
    parts.add(l10n.worldBridgeMsgCount('${c.msgCount}'));
    return l10n.worldBridgeWhyLine(parts.join(' · '));
  }

  Widget _buildReportCard(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final r = _report;
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r == null)
              Text(l10n.worldReportUnavailable(WorldService().lastError ?? l10n.worldReportNoServer),
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54))
            else ...[
              Row(children: [
                Icon(Icons.auto_stories, color: theme.accentColor),
                const SizedBox(width: 8),
                Text(l10n.worldReportTitle('${r['date'] ?? ''}'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              Text(
                l10n.worldReportSummary('${r['total_messages'] ?? 0}', '${r['active_agents'] ?? 0}', '${r['my_messages'] ?? 0}'),
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
              ),
              if ((r['rooms'] as List?)?.isNotEmpty == true) ...[
                const Divider(height: 20),
                ...((r['rooms'] as List).map((room) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        l10n.worldReportRoomLine(worldRoomName(room, l10n), '${room['messages'] ?? 0}', '${room['my_messages'] ?? 0}'),
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    ))),
              ],
            ],
            // M5 指标：人均跨圈连接数（本机口径，分子分母都如实标注）
            _buildMetricBlock(l10n, theme, isDark),
          ],
        ),
      ),
    );
  }

  /// M5 指标块：**绝不凑一个好看的估算值** —— 分子分母都写出来，并注明口径边界。
  Widget _buildMetricBlock(AppLocalizations l10n, ThemeProvider theme, bool isDark) {
    final m = _metric;
    final head = Row(children: [
      Icon(Icons.hub, size: 18, color: theme.accentColor),
      const SizedBox(width: 8),
      Text(l10n.worldMetricTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    ]);
    final body = m == null || m.knownAgents == 0
        ? Text(l10n.worldMetricNoData,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.worldMetricLine(
                    '${m.crossCircleLinks}', '${m.knownAgents}', m.perCapita2.toStringAsFixed(2)),
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: HelpDot(topic: HelpTopic.worldMetric, color: theme.accentColor),
              ),
            ],
          );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        head,
        const SizedBox(height: 8),
        body,
      ]),
    );
  }

  /// 房间卡片：活跃度徽标 + 「朋友池互荐」（跨圈边的唯一出处就是这个房间）。
  Widget _buildBridgeBlock(Map<String, dynamic> room, AppLocalizations l10n, ThemeProvider theme, bool isDark) {
    final input = _bridgeInput;
    if (input == null) return const SizedBox.shrink();
    final rid = room['id'].toString();

    final act = WoldRuntime.i.bridges.activity(input, roomId: rid);
    final pool = WoldRuntime.i.bridges.pool(input, roomId: rid);
    final cross = pool.crossCircle.take(3).toList();

    final sub = TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 活跃度：判据（窗口内发言人数 / 条数）全部显式，可复算
          Row(children: [
            Text(_vibrancyLabel(l10n, act.vibrancy), style: TextStyle(fontSize: 12, color: theme.accentColor)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${l10n.worldVibrancyDetail('${act.activeSpeakers}', '${act.messages}')}'
                '${act.messagesAreExact ? '' : ' *'}',
                style: sub,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          if (!act.messagesAreExact)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l10n.worldVibrancyObservedHint, style: sub),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.diversity_3, size: 15, color: theme.accentColor),
            const SizedBox(width: 6),
            Text(l10n.worldBridgeSection,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(l10n.worldBridgeCount('${pool.crossCircleCount}'),
                  style: TextStyle(fontSize: 11, color: theme.accentColor),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: HelpDot(topic: HelpTopic.worldBridge, color: theme.accentColor),
          ),
          const SizedBox(height: 6),
          if (cross.isEmpty)
            Text(l10n.worldBridgeNone, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54))
          else
            ...cross.map((c) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    // 04% 黑（浅色主题）/ 白 10%（深色主题）：等价于 withOpacity，
                    // 但用固定色值避免引入新的 deprecated 提示。
                    color: isDark ? Colors.white10 : const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.nickname.isEmpty ? c.agentId : c.nickname,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                        const SizedBox(height: 2),
                        Text(_whyLine(l10n, c), style: sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    // 一键发起跨圈互介（进房间页并自动定位到该人）
                    OutlinedButton(
                      onPressed: () => _openBridgeRecommend(room, c),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.accentColor,
                        side: BorderSide(color: theme.accentColor),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(l10n.worldBridgeRecommend, style: const TextStyle(fontSize: 12)),
                    ),
                  ]),
                )),
          // 为什么不推荐他们：把被排除的人**列出来**，否则主人会以为池子坏了
          if (pool.sameCircle.isNotEmpty || pool.linked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                if (pool.sameCircle.isNotEmpty)
                  _poolTag('${l10n.worldBridgeSameCircle} ${pool.sameCircle.length}', isDark),
                if (pool.linked.isNotEmpty)
                  _poolTag('${l10n.worldBridgeAlreadyLinked} ${pool.linked.length}', isDark),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _poolTag(String text, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0x14000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54)),
      );

  /// 进房间页并带上"指定互介对象"，由房间页完成建边 + 互介卡。
  Future<void> _openBridgeRecommend(Map<String, dynamic> room, BridgeCandidate c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorldRoomScreen(
          room: room,
          myAgentId: _myId,
          recommendPeerId: c.agentId,
          recommendPeerName: c.nickname,
        ),
      ),
    );
    _refresh();
  }

  Widget _roomBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // `withValues` 而非 `withOpacity`：后者已废弃（会新增 lint 提示）
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final isMember = room['i_am_member'] == true;
    final mode = room['mode']?.toString() ?? 'free';
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: theme.accentColor.withOpacity(0.15),
              child: Text(mode == 'turn' ? '🎯' : '💬'),
            ),
            title: Text(worldRoomName(room, l10n),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              // ★ 两个数分开显示：此前 `worldRoomSubtitle` 文案写的是"人在场"，
              //   喂进去的却是 `member_count`（含离线订阅者）—— 文案与事实不符。
              //   现在"在场"喂 present_count（60s 心跳内），"订阅"喂 member_count。
              '${l10n.worldRoomSubtitle(mode == 'turn' ? l10n.worldModeTurn : l10n.worldRoomChatFree, '${room['present_count'] ?? 0}', '${room['member_count'] ?? 0}')}'
              '${worldRoomTopic(room, l10n).isNotEmpty ? l10n.worldRoomTopicSuffix(worldRoomTopic(room, l10n)) : ''}',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isMember
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(
                      onPressed: () async {
                        await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => WorldRoomScreen(room: room, myAgentId: _myId)));
                        _refresh();
                      },
                      child: Text(l10n.worldRoomEnter),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, size: 18),
                      tooltip: l10n.worldRoomExitTooltip,
                      onPressed: () => _leave(room),
                    ),
                  ])
                : room['official'] == true
                    // 官方房：公开群，直接进
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: Colors.white),
                        onPressed: () => _join(room),
                        child: Text(l10n.worldRoomJoin),
                      )
                    // 个人房：只能申请（已递交 ⇒ 按钮变"申请中"且不可再点）
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: Colors.white),
                        onPressed: room['request_pending'] == true ? null : () => _requestJoin(room),
                        child: Text(room['request_pending'] == true ? l10n.worldBadgePending : l10n.worldRequestJoin),
                      ),
          ),
          // ★ 归属与状态**必须看得见**：否则主人分不清"这房是官方的还是我的、
          //   我申请过没有"，只能靠猜（猜错的表现就是"点了没反应"）。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _roomBadge(
                  room['official'] == true ? l10n.worldBadgeOfficial : l10n.worldBadgeMine,
                  room['official'] == true ? theme.accentColor : Colors.grey,
                  isDark,
                ),
                // ★ 已关闭（只读留档）：状态必须看得见，否则主人会误以为"这房坏了/卡了"。
                if (room['closed'] == true)
                  _roomBadge(l10n.worldRoomClosedBadge, Colors.blueGrey, isDark),
                if (room['request_pending'] == true)
                  _roomBadge(l10n.worldBadgePending, Colors.orangeAccent, isDark),
                // 待审批入口**只给房主**：条数是服务端按 owner 判过才下发的
                if (room['i_am_owner'] == true && (room['pending_count'] as int? ?? 0) > 0)
                  TextButton(
                    onPressed: () => _showRequests(room),
                    child: Text(l10n.worldRequestsTitle('${room['pending_count']}')),
                  ),
                // 「关闭房间」**只给房主**，且仅对"未关闭"的房间显示（关闭后按钮收起，
                // 避免重复关闭；服务端本身也是幂等的）。
                if (room['i_am_owner'] == true && room['closed'] != true)
                  TextButton(
                    onPressed: () => _close(room),
                    child: Text(l10n.worldRoomCloseAction,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
          ),
          // 只有"我已在场"的房间才谈得上"在这里遇见了谁"
          if (isMember) _buildBridgeBlock(room, l10n, theme, isDark),
        ],
      ),
    );
  }
}

/// 房间内页：消息流（观察）+ 主人直接发言 + 一键"建议卡" + 一键跨圈互介
class WorldRoomScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  final String myAgentId;

  /// M5：从世界页「朋友池互荐」进来时，指定要互介的圈外人（进页即弹互介流程）。
  final String? recommendPeerId;
  final String? recommendPeerName;

  const WorldRoomScreen({
    Key? key,
    required this.room,
    required this.myAgentId,
    this.recommendPeerId,
    this.recommendPeerName,
  }) : super(key: key);

  @override
  State<WorldRoomScreen> createState() => _WorldRoomScreenState();
}

class _WorldRoomScreenState extends State<WorldRoomScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _pollTimer;
  bool _sending = false;
  bool _autoReply = false;
  List<Map<String, dynamic>> _messages = [];
  String _lastDecision = '';
  /// 从世界页带过来的待互介对象：只弹一次，避免每 5s 轮询反复弹。
  bool _recommendHandled = false;
  /// 本房间是否已被房主**手动关闭**（只读留档）。初值取世界页带过来的快照，
  /// 之后由 /room（进房时）与 feed 的 `closed_rooms`（每 5s）双向校准。
  late bool _closed = widget.room['closed'] == true;
  /// 服务端如实报的保留口径（P2 空态说明要用；拿不到就用客户端默认值）
  int _serverMaxKept = 500;
  int _serverRetained = 0;

  String get _roomId => widget.room['id'].toString();
  String get _roomName => worldRoomName(widget.room, AppLocalizations.of(context));

  /// M10 房间角色：本房间的**非默认**角色分布。
  /// 默认角色 `participant` 不落库，所以表里没有的人天然就是普通参与者。
  Map<String, RoomRoleKind> _roles = {};

  Future<void> _reloadRoles() async {
    if (!WoldRuntime.i.isReady) return;
    final rows = await WoldRuntime.i.roomRoles.rolesIn(_roomId);
    if (!mounted) return;
    setState(() => _roles = rows);
  }

  /// 本地化角色名（core 层不依赖 l10n，翻译在 UI 侧完成）。
  String _roleLabel(AppLocalizations l10n, RoomRoleKind r) {
    // 5 个枚举值全部覆盖，故不写 default（写了会触发 unreachable_switch_default）
    switch (r) {
      case RoomRoleKind.host:
        return l10n.roomRoleHost;
      case RoomRoleKind.cohost:
        return l10n.roomRoleCohost;
      case RoomRoleKind.guest:
        return l10n.roomRoleGuest;
      case RoomRoleKind.npc:
        return l10n.roomRoleNpc;
      case RoomRoleKind.participant:
        return l10n.roomRoleParticipant;
    }
  }

  /// 角色徽标（默认角色返回 null —— 不显示，避免每个人头上都挂个"参与者"）。
  Widget? _roleBadge(String? senderId, AppLocalizations l10n, bool isDark) {
    final r = _roles[senderId ?? ''] ?? RoomRoleKind.participant;
    if (r.isDefault) return null;
    final host = r.isHostLayer;
    // 固定色值而非 withOpacity：避免引入新的 deprecated 提示（沿用本文件既有做法）
    final fg = host
        ? const Color(0xFFB8860B)
        : (isDark ? Colors.white60 : const Color(0xFF555555));
    final bg = host
        ? const Color(0x22D4A017)
        : (isDark ? Colors.white10 : const Color(0x14000000));
    final border = host
        ? const Color(0x80D4A017)
        : (isDark ? Colors.white24 : const Color(0x33000000));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (host) ...[
          Icon(Icons.workspace_premium, size: 10, color: fg),
          const SizedBox(width: 3),
        ],
        Text(_roleLabel(l10n, r),
            style: TextStyle(
                fontSize: 9, color: fg, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAutoReply();
    // ★ 进房先**按房回填一次**历史（feed 的全局游标拿不到进房之前的消息），
    //   再把落盘的缓存读回来 —— 这两步合起来才修得好"另一台手机一条历史都没有"。
    //   只跑一次：5s 轮询仍走 feed，不重复打这个端点。
    _backfillOnce().then((_) => _pullAndReload()).then((_) => _maybeAutoRecommend());
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pullAndReload());
  }

  Future<void> _backfillOnce() async {
    await WorldService().loadPersistedCache(widget.myAgentId);
    final data = await WorldService().fetchRoom(widget.myAgentId, _roomId);
    if (data == null) return;
    _serverMaxKept = (data['max_kept'] as num?)?.toInt() ?? _serverMaxKept;
    _serverRetained = (data['retained'] as num?)?.toInt() ?? _serverRetained;
    final room = data['room'];
    if (room is Map && room['message_count'] != null) {
      _serverRetained = (room['message_count'] as num?)?.toInt() ?? _serverRetained;
    }
    // 关闭状态以服务端为准：进房时同步一次（此后由 5s 轮询的 feed 兜底）。
    final closedFromServer = room is Map && room['closed'] == true;
    if (!mounted) return;
    setState(() {
      _messages = WorldService().recentRoomMessages(_roomId).toList();
      _closed = closedFromServer;
    });
    _scrollToBottom();
  }

  /// 世界页一键互介进来的自动流程（首帧之后再弹，保证 context 可用）。
  Future<void> _maybeAutoRecommend() async {
    if (_recommendHandled) return;
    final peerId = widget.recommendPeerId;
    if (peerId == null || peerId.isEmpty) return;
    _recommendHandled = true;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await _startBridge(
      peerId: peerId,
      peerName: widget.recommendPeerName ?? l10n.worldAnonAgent,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    // ⚠️ 这里**刻意不调用 leaveRoom**：世界页的「加入房间」是显式且持久的**观察订阅**
    //   —— 离开房间页之后，该房间的消息仍会经 feed 进入本机观察流（社交日志 /
    //   记忆事件 / M5 跨圈边）。离开页面就自动退订 = 静默取消主人主动建立的订阅，
    //   他此后连"我不在时发生了什么"都看不到。
    //   ⇒ 所以"幽灵成员"不能靠客户端补一次 leave 来治，只能由服务端分层治理：
    //     在场窗口（60s，只管回合轮转与在线计数）/ 订阅回收（7 天闲置）/ 房间回收。
    //     见 lib/hub/world.js 的在场-回收常量段。
    super.dispose();
  }

  Future<void> _loadAutoReply() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _autoReply = prefs.getBool('world_room_autoreply_$_roomId') ?? false);
  }

  Future<void> _toggleAutoReply(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('world_room_autoreply_$_roomId', v);
    if (!mounted) return;
    setState(() => _autoReply = v);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(v ? l10n.worldAutoreplyOn : l10n.worldAutoreplyOff),
    ));
  }

  /// 「为什么这里没有历史」—— 空态必须给出**可判定的解释 + 一条自救动作**。
  ///
  /// 三个可能的原因，全部如实列出（不编造"加载中"）：
  ///   ① 你是刚加入的：历史只从加入后开始累积（feed 用全局单调游标，进房之前的
  ///      消息本来就不送给你 —— 但可以**按房回填**，见下面的按钮）；
  ///   ② 服务端每房只保留最近 N 条，更早的确实没有了；
  ///   ③ 服务端这个房间就是空的。
  /// ★ 按钮走 `/api/world/room`：它按房间取、不看游标，是①的正面解药。
  Future<void> _pullHistory() async {
    final l10n = AppLocalizations.of(context);
    final before = _messages.length;
    final data = await WorldService().fetchRoom(widget.myAgentId, _roomId);
    if (!mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.worldPullHistoryFailed(
            WorldService().lastError ?? l10n.worldUnknownError)),
      ));
      return;
    }
    final fresh = WorldService().recentRoomMessages(_roomId).toList();
    setState(() => _messages = fresh);
    final added = fresh.length - before;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added > 0
          ? l10n.worldPullHistoryOk('$added')
          : l10n.worldPullHistoryNone),
    ));
    _scrollToBottom();
  }

  Widget _buildEmptyHistory(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.worldRoomEmpty),
            const SizedBox(height: 10),
            Text(
              l10n.worldHistoryWhy('$_serverMaxKept', '$_serverRetained'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pullHistory,
              icon: const Icon(Icons.history, size: 18),
              label: Text(l10n.worldPullHistory),
            ),
          ],
        ),
      ),
    );
  }

  /// 主人是不是正看着最新消息（贴底 80px 内即算；尚未完成布局时按"是"处理）。
  bool _atBottom() {
    if (!_scrollCtrl.hasClients) return true;
    final p = _scrollCtrl.position;
    return (p.maxScrollExtent - p.pixels) <= 80;
  }

  /// 轮询/刷新：**无变化就不重建**。
  /// 此前每 5s 无条件 setState + 滚到底，两个副作用都在真实使用里被踩到：
  ///   ① 每 5s 把整条消息列表重建一次（房间越久越贵，白烧一帧）；
  ///   ② 主人往上翻历史时每 5s 被强行拽回底部 —— 历史根本读不成。
  Future<void> _pullAndReload() async {
    final wasAtBottom = _atBottom();
    await WorldService().pullFeed(widget.myAgentId);
    final decision = await AgentService.lastWorldDecision(_roomId);
    // M10：房间角色与消息一起刷新 —— 角色是**活动内属性**，随房间加载
    Map<String, RoomRoleKind> roles = _roles;
    if (WoldRuntime.i.isReady) {
      roles = await WoldRuntime.i.roomRoles.rolesIn(_roomId);
    }
    final fresh = WorldService().recentRoomMessages(_roomId).toList();
    // 关闭状态由 feed 的 `closed_rooms` 每次刷新 ⇒ 房主一关闭，房内所有人 5s 内变只读。
    final closedNow = WorldService().isRoomClosed(_roomId);
    if (!mounted) return;
    // 消息：比条数 + 末条 id（roomCache 是只增/截断的，末条不变即内容不变）
    final sameMessages = fresh.length == _messages.length &&
        (fresh.isEmpty || fresh.last['id'] == _messages.last['id']);
    final sameRoles = roles.length == _roles.length &&
        roles.entries.every((e) => _roles[e.key] == e.value);
    if (sameMessages && sameRoles && decision == _lastDecision && closedNow == _closed) {
      return; // 什么都没变 ⇒ 一次 setState 都不发（这才是 5s 轮询应有的开销）
    }
    setState(() {
      _messages = fresh;
      _lastDecision = decision;
      _roles = roles;
      _closed = closedNow;
    });
    // ★ 只在"主人本来就在底部"时才自动跟随新消息；他正在往上翻历史时绝不抢滚动位置。
    if (wasAtBottom) _scrollToBottom();
  }

  /// 「让分身说一句」：手动触发一次房间发言，结果直接弹给主人看
  Future<void> _forceReply() async {
    if (_sending) return;
    // 已关闭（只读留档）⇒ 不再让分身发言：否则它会一路走到服务端被 403 room_closed 顶回，
    // 主人看到的却是一句含糊的失败提示。
    if (_closed) {
      final l10n0 = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n0.worldRoomClosedSendRejected),
      ));
      return;
    }
    setState(() => _sending = true);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.worldDrafting),
      duration: const Duration(seconds: 2),
    ));
    final result = await AgentService().forceWorldReply(_roomId);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result),
      duration: const Duration(seconds: 6),
    ));
    await Future.delayed(const Duration(milliseconds: 800));
    // 主人主动点了「让它说一句」⇒ 无论他此前滚到哪儿，都把结果推到他眼前
    await _pullAndReload();
    if (!mounted) return;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await WorldService().say(widget.myAgentId, _roomId, text.trim());
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      final l10n = AppLocalizations.of(context);
      // 房间已被关闭：这不是"网络/限流"那类可重试的错误，而是**状态已变** ——
      // 顺手把本页切成只读，并给一句与状态一致的话，而不是弹一句含糊的"发送失败"。
      if (WorldService().lastErrorCode == 'room_closed') {
        setState(() => _closed = true);
        await WorldService().fetchRoom(widget.myAgentId, _roomId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.worldRoomClosedSendRejected),
        ));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.worldSendFailed(WorldService().lastError ?? l10n.worldUnknownError)),
      ));
      return;
    }
    // 服务器有最小发言间隔闸门，立即拉取可能尚未包含本条；稍候再拉
    await Future.delayed(const Duration(milliseconds: 600));
    await _pullAndReload();
    if (!mounted) return;
    _scrollToBottom(); // 自己刚发的一定要看得见（即使此前正在翻历史）
  }

  /// 房间页内的「关闭房间」入口（**仅房主**可见，由 AppBar 按钮触发）。
  Future<void> _closeThisRoom() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirmCloseRoom(context, l10n)) return;
    final ok = await WorldService().closeRoom(widget.myAgentId, _roomId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.worldRoomClosedOk(_roomName)
          : l10n.worldRoomCloseFailed(WorldService().lastError ?? l10n.worldUnknownError)),
    ));
    if (ok && mounted) setState(() => _closed = true);
    await _pullAndReload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    final mode = widget.room['mode']?.toString() ?? 'free';
    final decision = _lastDecision.isEmpty ? l10n.worldLoading : _lastDecision;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        title: Text('$_roomName${mode == 'turn' ? l10n.worldRoomTurnSuffix : ''}'),
        actions: [
          // 关闭房间（**仅房主**，且房间尚未关闭时）：服务端会重新核 owner，客户端不算数。
          if (widget.room['i_am_owner'] == true && !_closed)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: l10n.worldRoomCloseAction,
              onPressed: _closeThisRoom,
            ),
          // M10：房间角色（主持人 / 嘉宾 / NPC）——角色属于房间，不改变身份
          IconButton(
            icon: const Icon(Icons.workspace_premium_outlined),
            tooltip: l10n.roomRoleManageTitle,
            onPressed: _openRoleSheet,
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: l10n.worldAutopilotTooltip,
            onPressed: (_sending || _closed) ? null : _forceReply,
          ),
          Switch(
            value: _autoReply,
            activeColor: theme.accentColor,
            // 已关闭的房间不让开"托管"：开了也只会被服务端一次次拒，反而让人困惑。
            onChanged: _closed ? null : _toggleAutoReply,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 14),
            child: Text(l10n.worldAutopilotLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: Container(
        decoration: theme.backgroundDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // 已关闭（只读留档）：常驻横幅 —— 属"数据边界告示"类的**必要常驻文字**
              // （把输入框静默置灰而不说为什么，等于让主人以为 App 坏了）。
              if (_closed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.blueGrey.withValues(alpha: isDark ? 0.30 : 0.14),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.worldRoomClosedReadonlyHint,
                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                ),
              // 「为什么它不说话」——把最近一次决策显示出来，不再让主人靠猜
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                child: Row(
                  children: [
                    Icon(
                      _autoReply ? Icons.smart_toy : Icons.visibility,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.worldAutopilotStatus(_autoReply ? l10n.worldAutopilotStateOn : l10n.worldAutopilotStateOff, decision),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _messages.isEmpty
                    // ★ P2：空的**必须说明白为什么空**，不能只是一句"还很安静"。
                    //   真机反馈"另一台手机一条历史都没有"的根因（全局单调游标 + 内存缓存）
                    //   在页面上完全不可见 ⇒ 主人只能猜"是不是坏了"。
                    ? _buildEmptyHistory(theme, isDark)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) => _buildBubble(_messages[i], theme, isDark),
                      ),
              ),
              _closed ? _buildClosedBar(theme, isDark) : _buildInputBar(theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // M10 房间角色：管理面板（Host 层权益，fail-closed）
  // ------------------------------------------------------------------

  /// 打开房间角色面板。
  ///
  /// 规则（与 `room_role.dart` 一一对应，UI 不做任何自己的判定）：
  /// - 本房间无人主持时，可「认领主持人」（第一个认领者成为主持人）；
  /// - 已有主持人时认领被拒（Toast 明说，不让主人以为按钮坏了）；
  /// - 只有主持层能改角色；撤销最后一个主持人会被拒。
  Future<void> _openRoleSheet() async {
    final l10n = AppLocalizations.of(context);
    if (!WoldRuntime.i.isReady) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.worldLoading)));
      return;
    }
    final me = widget.myAgentId;
    final svc = WoldRuntime.i.roomRoles;

    var members = await WoldRuntime.i.roomPresences.inRoom(_roomId, me);
    var roles = await svc.rolesIn(_roomId);
    var myRole = await svc.roleIn(_roomId, me);
    var hasHost = await svc.hasHost(_roomId);
    var sheetOpen = true;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          final sub = TextStyle(
              fontSize: 11, color: isDark ? Colors.white54 : Colors.black54);

          // 每次操作后统一重读：UI 与库不分叉（也顺手刷新气泡上的徽标）
          Future<void> refresh() async {
            members = await WoldRuntime.i.roomPresences.inRoom(_roomId, me);
            roles = await svc.rolesIn(_roomId);
            myRole = await svc.roleIn(_roomId, me);
            hasHost = await svc.hasHost(_roomId);
            await _reloadRoles();
            if (sheetOpen && mounted) setSheet(() {});
          }

          void toast(String msg) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }

          Future<void> doClaim() async {
            final r = await svc.claimHost(
                roomId: _roomId,
                agentId: me,
                atMs: DateTime.now().millisecondsSinceEpoch);
            toast(r.ok ? l10n.roomRoleClaimedHost : l10n.roomRoleClaimHostExists);
            await refresh();
          }

          Future<void> doSet(String agentId, RoomRoleKind role) async {
            final r = await svc.grant(
                roomId: _roomId,
                agentId: agentId,
                role: role,
                granterId: me,
                atMs: DateTime.now().millisecondsSinceEpoch);
            final msg = r.ok
                ? l10n.roomRoleSetTo(_roleLabel(l10n, role))
                : (r.reason == RoomRoleBlockCode.lastHost
                    ? l10n.roomRoleLastHostBlocked
                    : l10n.roomRoleNotHost);
            toast(msg);
            await refresh();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.workspace_premium,
                        size: 18, color: Theme.of(sheetCtx).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(l10n.roomRoleManageTitle,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('$_roomName', style: sub),
                  ]),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: HelpDot(topic: HelpTopic.worldRoomRole),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Flexible(
                      child: Text(l10n.roomRoleMine(_roleLabel(l10n, myRole)),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(sheetCtx).colorScheme.primary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    if (!hasHost)
                      OutlinedButton(
                        onPressed: doClaim,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          minimumSize: const Size(0, 30),
                        ),
                        child: Text(l10n.roomRoleClaimHost,
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  if (members.isEmpty)
                    Text(l10n.roomRoleNoMembers, style: sub)
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: members.length,
                        itemBuilder: (_, i) {
                          final m = members[i];
                          final cur = roles[m.agentId] ?? RoomRoleKind.participant;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        m.nickname.isEmpty
                                            ? m.agentId
                                            : m.nickname,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(m.agentId,
                                        style: sub,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 非主持层 → 下拉禁用（能看见，但改不动）
                              DropdownButton<RoomRoleKind>(
                                value: cur,
                                dropdownColor: Theme.of(sheetCtx)
                                    .colorScheme
                                    .surface,
                                onChanged: myRole.isHostLayer
                                    ? (v) {
                                        if (v != null && v != cur) {
                                          doSet(m.agentId, v);
                                        }
                                      }
                                    : null,
                                items: [
                                  for (final r in RoomRoleKind.values)
                                    DropdownMenuItem(
                                      value: r,
                                      child: Text(_roleLabel(l10n, r),
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                            ]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    sheetOpen = false;
  }

  Widget _buildBubble(Map<String, dynamic> msg, ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    // ★ 系统消息（如"房主已关闭房间"）：居中灰条，且**不带**"建议卡 / 互介"按钮
    //   ——那两个按钮对 'system' 这个发送者毫无意义（点了只会去给"system"发建议）。
    //   文案优先按机器可读的 `kind` 本地化：服务端刻意只发 kind、不发某一种语言的文案。
    if (msg['sender_id']?.toString() == 'system') {
      final kind = msg['kind']?.toString();
      final sysText = kind == 'room_closed'
          ? l10n.worldRoomClosedSystemMsg
          : (msg['message']?.toString() ?? '');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: isDark ? 0.30 : 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              sysText,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      );
    }
    final mine = msg['sender_id']?.toString() == widget.myAgentId;
    final text = msg['message']?.toString() ?? '';
    final nickname = msg['nickname']?.toString() ?? l10n.worldAnonAgent;
    final ts = DateTime.fromMillisecondsSinceEpoch((msg['created_at'] as num? ?? 0).toInt());
    final timeLabel =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // M10：昵称后跟房间角色徽标（默认角色 participant 不显示徽标）
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${mine ? l10n.worldMe : nickname} · $timeLabel',
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black38)),
                if (_roleBadge(msg['sender_id']?.toString(), l10n, isDark) !=
                    null) ...[
                  const SizedBox(width: 4),
                  _roleBadge(msg['sender_id']?.toString(), l10n, isDark)!,
                ],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!mine)
                  IconButton(
                    icon: Icon(Icons.tips_and_updates_outlined, size: 18, color: theme.accentColor),
                    tooltip: l10n.worldSuggestionTooltip,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 4),
                    onPressed: () => _showSuggestionCard(msg, theme),
                  ),
                // M5：跨圈互介 —— 把房间里遇到的圈外人变成一条跨圈边
                if (!mine)
                  IconButton(
                    icon: Icon(Icons.person_add_alt_1_outlined, size: 18, color: theme.accentColor),
                    tooltip: l10n.worldBridgeTooltip,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 4),
                    onPressed: () => _startBridge(
                      peerId: msg['sender_id']?.toString() ?? '',
                      peerName: msg['nickname']?.toString() ?? l10n.worldAnonAgent,
                    ),
                  ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: mine ? theme.accentColor : (isDark ? Colors.grey[800] : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 14, color: mine ? Colors.white : (isDark ? Colors.white : Colors.black87)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 建议卡弹窗：先展示生成中，草稿回来后可编辑，确认才发送
  Future<void> _showSuggestionCard(Map<String, dynamic> msg, ThemeProvider theme) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    var generated = false;
    var failed = false;
    var requested = false;

    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) {
          if (!generated && !failed && !requested) {
            requested = true;
            AgentService()
                .draftWorldReplySuggestion(
                    _roomId, msg['nickname']?.toString() ?? '', msg['message']?.toString() ?? '')
                .then((draft) {
              if (!dCtx.mounted) return;
              setDialogState(() {
                if (draft == null || draft.isEmpty) {
                  failed = true;
                } else {
                  ctrl.text = draft;
                  generated = true;
                }
              });
            });
          }
          return AlertDialog(
            title: Text(l10n.worldSuggestionTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!generated && !failed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(l10n.worldSuggestionDrafting, style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                if (failed)
                  Text(l10n.worldSuggestionFailed,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                if (generated)
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    autofocus: false,
                    decoration: InputDecoration(hintText: l10n.worldSuggestionEditHint),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(l10n.commonCancel)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: Colors.white),
                onPressed: generated
                    ? () async {
                        Navigator.pop(dCtx);
                        await _send(ctrl.text.trim());
                      }
                    : null,
                child: Text(l10n.worldSuggestionSend),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // M5 · 跨圈互介：先把"房间看见过他"变成一条跨圈边，再走既有互介卡流程
  // ------------------------------------------------------------------

  /// 建边（fail-closed，四条铁律在 core 层强制）→ 成功后起草互介卡。
  ///
  /// `circleId` 用**我自己的圈**，不再是硬编码的 'direct' —— M5 明确要求
  /// 这条边挂在"我的圈"这个端点上，否则边就没有归属。
  Future<void> _startBridge({required String peerId, required String peerName}) async {
    if (peerId.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final selfId = widget.myAgentId;

    if (!WoldRuntime.i.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.worldBridgeLinkFailed)));
      return;
    }

    // 我的圈：互介卡的 circleId 出处。入场即进圈（M1），正常不会为空。
    final myCircle = await WoldRuntime.i.primaryCircle(selfId);
    if (myCircle == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.worldBridgeNoCircle)));
      return;
    }
    final myCircleId = myCircle.id;
    final myCircleName = myCircle.name;

    final input = await WoldRuntime.i.bridgeInput(selfId);
    final res = await WoldRuntime.i.bridges.link(
      input: input,
      roomId: _roomId,
      peerId: peerId,
      myCircleId: myCircleId,
    );
    if (!mounted) return;

    if (!res.ok) {
      await _showBridgeBlocked(res.reason);
      return;
    }

    // 建边成功（created）或边已存在（duplicate）→ 起草互介卡
    final sentOk = await _showBridgeInterCard(
      toAgentId: peerId,
      toName: peerName,
      circleId: myCircleId,
      circleName: myCircleName,
      theme: theme,
    );
    if (!mounted || !sentOk) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.created
          ? '${l10n.worldBridgeLinkCreated(_roomName)}\n${l10n.intercardSentOk}'
          : l10n.intercardSentOk),
      duration: const Duration(seconds: 4),
    ));
  }

  /// 被四条铁律拦下时，把**具体原因**告诉主人（不吞错、不糊弄）。
  Future<void> _showBridgeBlocked(String? code) async {
    final l10n = AppLocalizations.of(context);
    final text = switch (code) {
      BridgeBlockCode.notInRoom => l10n.worldBridgeBlockedNotInRoom,
      BridgeBlockCode.sameCircle => l10n.worldBridgeBlockedSameCircle,
      BridgeBlockCode.alreadyLinked => l10n.worldBridgeBlockedAlreadyLinked,
      BridgeBlockCode.self => l10n.worldBridgeBlockedSelf,
      BridgeBlockCode.noRoom => l10n.worldBridgeBlockedNoRoom,
      BridgeBlockCode.duplicate => l10n.worldBridgeBlockedDuplicate,
      _ => l10n.worldBridgeLinkFailed,
    };
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.worldBridgeBlockedTitle),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonOk)),
        ],
      ),
    );
  }

  /// 互介卡草稿 → 主人确认（签名）→ 发出。返回 true 表示真的发出了。
  ///
  /// 三级披露与 `social_screen` 同源：只有 nickname / mask_profile（第②级）上卡，
  /// 第③级键在 core 层 fail-closed，误填其值也会被整卡拒绝。
  Future<bool> _showBridgeInterCard({
    required String toAgentId,
    required String toName,
    required String circleId,
    required String circleName,
    required ThemeProvider theme,
  }) async {
    final l10n = AppLocalizations.of(context);
    final reasonCtrl = TextEditingController();
    final topicsCtrl = TextEditingController();

    final nickname = await DBHelper.getAmbassador('nickname') ?? '';
    final maskProfile = await DBHelper.getAmbassador('mask_profile') ?? '';
    final level2 = <String, String>{
      'nickname': nickname,
      'mask_profile': maskProfile,
    };
    if (!mounted) return false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.intercardDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.worldBridgeRoomProvenance(_roomName),
                  style: TextStyle(fontSize: 12, color: theme.accentColor)),
              const SizedBox(height: 2),
              Text(l10n.worldBridgeCircleLine(circleName),
                  style: TextStyle(fontSize: 12, color: theme.accentColor)),
              const SizedBox(height: 2),
              Text('@$toName', style: TextStyle(fontSize: 12, color: theme.accentColor)),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(labelText: l10n.intercardReasonLabel),
                maxLines: 2,
                autofocus: true,
              ),
              TextField(
                controller: topicsCtrl,
                decoration: InputDecoration(labelText: l10n.intercardTopicsLabel),
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: HelpDot(
                    topic: HelpTopic.intercardDisclosure, color: theme.accentColor),
              ),
              const SizedBox(height: 4),
              for (final e in level2.entries)
                Text('· ${e.key}: ${e.value.isEmpty ? "—" : e.value}',
                    style: TextStyle(fontSize: 11, color: theme.accentColor)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.intercardConfirmSend)),
        ],
      ),
    );
    if (ok != true || !mounted) return false;

    final topics = parseTopics(topicsCtrl.text);
    final gen = await WoldRuntime.i.intercards.generate(
      circleId: circleId, // ← 我的圈（M5：边与卡都必须有圈归属）
      ownerId: widget.myAgentId,
      toId: toAgentId,
      reason: reasonCtrl.text.trim(),
      topics: topics,
      fields: level2,
      forbiddenKeys: {'phone', 'home_address', 'legal_name', 'id_number', 'email'},
    );
    if (!mounted) return false;
    if (gen.blocked) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.intercardBlockedTitle),
          content: Text(gen.reason == 'l3_leak'
              ? l10n.intercardBlockedL3
              : l10n.intercardEmptyContent),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonOk)),
          ],
        ),
      );
      return false;
    }
    final approved = await WoldRuntime.i.intercards.approve(
        id: gen.card!.id, approverId: gen.card!.ownerId);
    if (approved == null) return false;
    await WoldRuntime.i.intercardRelay.dispatch(approved);
    return true;
  }

  /// 已关闭房间的"输入栏"：不提供输入框，只给一句状态说明（只读留档）。
  Widget _buildClosedBar(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      color: isDark ? Colors.black87 : Colors.white,
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.worldRoomClosedReadonlyHint,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: isDark ? Colors.black87 : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                hintText: l10n.worldSayHint,
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onSubmitted: (v) {
                _inputCtrl.clear();
                _send(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _sending
                ? null
                : () {
                    final v = _inputCtrl.text;
                    _inputCtrl.clear();
                    _send(v);
                  },
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              backgroundColor: theme.accentColor,
              child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
