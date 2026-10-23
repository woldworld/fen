import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_logger.dart';
import '../core/db_helper.dart';
import '../core/mode_controller.dart';
import '../core/theme_provider.dart';
import '../core/p2p_service.dart';
import '../core/lan_service.dart';
import '../core/cloud_service.dart';
import '../core/agent_service.dart';
import '../core/intercard_service.dart';
import '../core/persona_mode.dart';
import '../core/diplomatic_tasks.dart';
import '../core/federation_auto_pull.dart';
import '../core/presence_service.dart';
import '../core/radar_service.dart';
import '../core/session_crypto.dart';
import '../core/reputation_service.dart';
import 'agent_action_inbox_screen.dart';
import 'contact_detail_screen.dart';
import 'delegation_screen.dart';
import 'duty_permission_flow.dart';
import 'gift_picker_dialog.dart';
import 'radar_permission_flow.dart';
import '../core/wold_runtime.dart';
import '../l10n/app_localizations.dart';
import 'intercard_topics.dart'; 
import 'help_dot.dart';

class SocialScreen extends StatefulWidget {
  @override
  _SocialScreenState createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; 

  late TabController _tabController;
  // 模式（首批用户方案 §三）：入门模式收起「托办」签，但「日志」**绝不收起**
  // （它是「待我确认的建议」唯一入口）。单一事实源 = ModeController（0.61.0）。
  bool _simpleMode = false;
  /// 上一次稳定停留的页签序号 —— 页签切换动画期间 listener 会触发多次，
  /// 用它把"切一次"压成"触发一次"。
  int _lastTabIndex = 0;
  late AnimationController _radarController; 
  Timer? _countdownTimer; 

  bool _isLoading = true;
  bool _saving = false;
  String _currentMode = 'casual';

  /// ★ 0.50.0（体检 P1-5「social/contact 屏 DB 无降级」）：本屏数据全部直连本地库，
  ///   库拿不到时（初始化失败 / 句柄异常）改前会**一直停在 loading**（无提示、无出路）。
  ///   为 true 时在页面顶部给一条"数据暂时读不到 + 重试"，而不是无限转圈。
  bool _dbDegraded = false;

  /// 人格模式 → 本地化文案（M10：模式 ID 与默认值由 `PersonaModes` 提供，
  /// 这里只负责把 ID 翻成用户看得懂的名字 —— core 层不依赖 l10n）。
  String _personaLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case PersonaModes.business:
        return l10n.socialModeBusiness;
      case PersonaModes.dating:
        return l10n.socialModeDating;
      case PersonaModes.emergency:
        return l10n.socialModeEmergency;
      case PersonaModes.custom:
        return l10n.socialModeCustom;
      case PersonaModes.casual:
      default:
        return l10n.socialModeCasual;
    }
  }

  // 状态统一由 RadarService 提供（UI 只读，不再自己管理）
  bool get _isPatrolling => RadarService.instance.isPatrolling;
  bool get _isNearFieldEnabled => RadarService.instance.isNearFieldEnabled;
  bool get _isLanEnabled => RadarService.instance.isLanEnabled;
  bool get _isCloudEnabled => RadarService.instance.isCloudEnabled;

  /// 0.89.0 联邦名册**自动拉取**开关（默认关；唯一事实源是 prefs，这里只是镜像）。
  /// 只读，用来驱动 SwitchListTile 的显示；读写都走 [FederationAutoPull]。
  bool _autoPullEnabled = false;

  /// 当前"机器自动收录"的行数（`_agentFriends` 里 `auto_pulled=1` 的条数）。
  /// > 0 时才显示"清空联邦自动收录"按钮，避免给空态噪音。
  int _autoPulledCount = 0;

  // 🚀 核心修复 1：使用局部监听器，彻底取代全局 setState 导致的每秒卡顿
  final ValueNotifier<String> _timeLeftNotifier = ValueNotifier<String>("");
  int _selectedDurationMinutes = 60;

  List<Map<String, dynamic>> _socialLogs = [];
  List<Map<String, dynamic>> _agentFriends = [];
  Map<String, int> _msgCounts = {}; // 🚀 新增：保存每个人的对话条数统计
  String _myFingerprint = '--------'; // 本机设备身份指纹（近场握手时供对方比对）

  /// M3 互介卡：收到的（对方主人确认过的介绍）/ 我发出的（24h 内可撤回）。
  List<InterCard> _intercardsIn = [];
  List<InterCard> _intercardsMine = [];

  /// M4 在场：此刻**已验证且未过期**的"本人在线"peer 集合（一次查完，不逐人查）。
  Set<String> _peerPresence = {};
  
  final _nicknameController = TextEditingController();
  final _maskProfileController = TextEditingController();
  final _myAgentIdController = TextEditingController();
  final _avatarController = TextEditingController(); 
  final _socialTaskController = TextEditingController(); 
  /// 密令任务框的焦点：`_loadDataOnly` 反复同步时，**不要打断主人正在输入**的任务。
  final _socialTaskFocus = FocusNode();

  late VoidCallback _uiUpdateListener;

  @override
  void initState() {
    super.initState();
    // 模式（0.61.0）单一事实源 = ModeController（main() 已 load）。
    // 入门模式 4 签（面具 / 雷达 / 名册 / **日志**）；进阶模式 5 签（多一个托办）。
    _simpleMode = ModeController.i.simpleMode;
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 顶栏切模式 ⇒ 本页重建页签。不再只在 initState 读一次 —— 那正是
    // 「改了模式社交页却没变」的根。
    ModeController.i.addListener(_onModeChanged);
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    
    _uiUpdateListener = () { if (mounted) _loadDataOnly(); };
    P2PService().listeners.add(_uiUpdateListener);
    LanService().listeners.add(_uiUpdateListener);
    RadarService.instance.addListener(_uiUpdateListener);

    _initialLoad();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdownUI());
  }

  /// 页签数：入门模式收起「托办」一签（日志仍在），进阶模式全显。
  int get _tabCount => _simpleMode ? 4 : 5;

  /// 顶栏改了模式 ⇒ 重建 TabController（长度变了必须换实例）。
  ///
  /// ★ 为什么不复用旧的：`TabController.length` 不可变，4↔5 只能新建。
  ///   新建后把停留序号**归一化到合法区间**并同步 `_lastTabIndex`，
  ///   避免停在"已消失的托办签"上、或下一次切换被 `_onTabChanged` 误判成未变。
  void _onModeChanged() {
    if (!mounted) return;
    final sm = ModeController.i.simpleMode;
    if (sm == _simpleMode) return;
    final oldIndex = _tabController.index;
    _simpleMode = sm;
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _tabController = TabController(length: _tabCount, vsync: this);
    final idx = oldIndex < _tabCount ? oldIndex : _tabCount - 1;
    _tabController.index = idx;
    _lastTabIndex = idx;
    _tabController.addListener(_onTabChanged);
    setState(() {});
  }

  /// 页签切换：切到「托办」（第 4 个，序号 3）时请求它重新拉数据。
  ///
  /// ★ 为什么需要这个"刷新时机"：托办面板带 `AutomaticKeepAliveClientMixin` 保活
  ///   ⇒ 切走再切回**不会重建**、`initState` 不会再跑 ⇒ 新收到的委托会看不见。
  void _onTabChanged() {
    final i = _tabController.index;
    if (i == _lastTabIndex) return; // 切换动画期间会连触发几次，压成一次
    _lastTabIndex = i;
    // 托办签只在进阶模式存在（序号 3）⇒ 入门模式下 3 号是日志，别误刷托办。
    if (!_simpleMode && i == 3) DelegationPanel.requestReload();
    // 0.89.0：切到「捕获名册」（序号 2）时，若自动拉取开着就**静默**拉一次名册。
    // force=false ⇒ 受 6h 节流约束，反复切页不会重复打网络（开关关时零请求）。
    if (i == 2) unawaited(_maybeAutoPullQuiet());
  }

  @override
  void dispose() {
    ModeController.i.removeListener(_onModeChanged);
    _timeLeftNotifier.dispose(); // 🚀 别忘了销毁监听器
    P2PService().listeners.remove(_uiUpdateListener); 
    LanService().listeners.remove(_uiUpdateListener); 
    RadarService.instance.removeListener(_uiUpdateListener);
    _countdownTimer?.cancel();
    _tabController.dispose();
    _radarController.dispose();
    _nicknameController.dispose();
    _maskProfileController.dispose();
    _myAgentIdController.dispose();
    _avatarController.dispose();
    _socialTaskController.dispose();
    _socialTaskFocus.dispose();
    super.dispose();
  }

 void _updateCountdownUI() {
    final endTime = RadarService.instance.endTime;
    if (!RadarService.instance.isPatrolling || endTime == 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainStr = endTime > now ? _formatDuration(endTime - now) : "00:00";
    // 🚀 核心修复 2：只更新 Notifier 的值，绝对不要触发全局 setState！
    if (mounted) _timeLeftNotifier.value = remainStr;
  }

  String _formatDuration(int ms) {
    final secs = ms ~/ 1000;
    final m = secs ~/ 60;
    final s = secs % 60;
    return "${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}";
  }

  Future<void> _initialLoad() async {
    // ★ 0.50.0（体检 P1-5）：整段包 try/catch/finally —— **无论成败都要把 _isLoading 落下**。
    //   改前：`DBHelper` 抛异常时这是个**未被捕获的异步错误** ⇒ 页面永远停在转圈、
    //   既没有提示也没有出路（体检记的"social/contact 屏 DB 无降级"）。
    var ok = true;
    try {
      final nickname = await DBHelper.getAmbassador('nickname') ?? '外交代驾-阿尔法';
      final maskProfile = await DBHelper.getAmbassador('mask_profile') ?? '主要代主人搜集资讯，不持有隐私。';
      final myAgentId = await DBHelper.getAmbassador('my_agent_id') ?? 'AG-XXXXXX';
      final avatar = await DBHelper.getAmbassador('avatar') ?? '🤖';
      // ★ 2026-10-07：主人留空 / 只填占位空话时，从内置外交任务库自动补一条
      //   有目的的任务（确定性，按分身 ID 稳定），避免分身进入无意义空聊。
      final task = DiplomaticTasks.effective(
        mode: await DBHelper.getAmbassador('social_mode') ?? 'casual',
        stored: await DBHelper.getAmbassador('social_task') ?? '',
        agentId: myAgentId,
      );
      _myFingerprint = await SessionCrypto.instance.myIdentityFingerprint();

      _nicknameController.text = nickname;
      _maskProfileController.text = maskProfile;
      _myAgentIdController.text = myAgentId;
      _avatarController.text = avatar;
      _socialTaskController.text = task;

      // 雷达状态由 RadarService 统一管理（main() 启动时已恢复）
      if (RadarService.instance.isPatrolling) {
        _radarController.repeat();
      }
      await _loadDataOnly();
    } catch (e) {
      ok = false;
      AppLogger.w('social.load', e);
    } finally {
      if (mounted) {
        setState(() {
          _dbDegraded = !ok;
          _isLoading = false;
        });
      }
    }
  }

  /// 降级条上的「重试」：先把界面切回 loading，再重跑首屏加载。
  void _retryInitialLoad() {
    if (!mounted) return;
    setState(() {
      _dbDegraded = false;
      _isLoading = true;
    });
    _initialLoad();
  }

  Future<void> _loadDataOnly() async {
    // ★ 0.50.0（P1-5）：本方法被 `_uiUpdateListener`（多个服务的监听器）复用 ——
    //   那条链是 fire-and-forget，异常没人接。这里就地兜住，并把"读不到"
    //   如实反映到 `_dbDegraded`；**已拿到的旧数据保持不动**（不清空成假空态）。
    try {
      final logs = await DBHelper.getSocialLogs();
      final friends = await DBHelper.getAgentFriends();
      // 对话条数统计改为 SQL 聚合，避免全表遍历
      final Map<String, int> tempCounts = await DBHelper.countSocialLogsByTarget();
      // 🚀 新增：每次刷新数据时，同步读取底层数据库里的分身档案
      // 这样当主智能体在后台（通过大模型工具）修改了人设后，这里的 UI 输入框会自动同步！
      final dbNickname = await DBHelper.getAmbassador('nickname') ?? '';
      final dbMaskProfile = await DBHelper.getAmbassador('mask_profile') ?? '';
      final dbAvatar = await DBHelper.getAmbassador('avatar') ?? '🤖';
      final dbStoredTask = await DBHelper.getAmbassador('social_task') ?? '';
      final dbMyAgentId = await DBHelper.getAmbassador('my_agent_id') ?? '';
      
      // 🚀 新增：读取底层最新的社交模式（如果没有默认为 casual）
      final dbMode = await DBHelper.getAmbassador('social_mode') ?? 'casual';
      // ★ 2026-10-07：主人留空 / 只填占位空话 → 自动补一条内置外交任务（确定性，
      //   按分身 ID 稳定）。让分身即便在主人没写任务时也带着目的去聊。
      final dbTask = DiplomaticTasks.effective(
        mode: dbMode,
        stored: dbStoredTask,
        agentId: dbMyAgentId,
      );

      // M3 互介卡收发箱（运行时未就绪时留空，UI 显示"还没有"）
      if (WoldRuntime.i.isReady) {
        final me = await WoldRuntime.i.myAgentId();
        _intercardsIn = await WoldRuntime.i.interCardStore.inbox(me);
        _intercardsMine = await WoldRuntime.i.interCardStore.mine(me);
        // M4 在场：只有"验签通过且未过期"的 peer 才算本人在线
        _peerPresence = await WoldRuntime.i.presenceRelay.freshPeers();
      }

      // 先读出开关（await 必须在 setState 之外 —— setState 的回调是同步闭包）
      final autoPullOn = await FederationAutoPull.isEnabled();
      if (mounted) {
        setState(() {
          _dbDegraded = false;
          _socialLogs = logs;
          _agentFriends = friends;
          _autoPullEnabled = autoPullOn;
          _autoPulledCount = friends
              .where((f) => ((f['auto_pulled'] as num?) ?? 0).toInt() == 1)
              .length;
          _msgCounts = tempCounts; // 🚀 更新到 UI 状态
          // 🚀 新增：将数据库里的模式更新到 UI 的下拉框状态变量中
          _currentMode = dbMode;

          // 如果用户没在打字，就自动把主智能体设计的人设刷新到文本框里
          if (_nicknameController.text != dbNickname) _nicknameController.text = dbNickname;
          if (_maskProfileController.text != dbMaskProfile) _maskProfileController.text = dbMaskProfile;
          if (_avatarController.text != dbAvatar) _avatarController.text = dbAvatar;
          // 密令任务：主人正在输入时**不打断**（焦点守卫）；否则同步为"有效任务"
          // （留空 / 占位空话会自动补一条内置外交任务 —— 见 DiplomaticTasks）。
          if (!_socialTaskFocus.hasFocus &&
              _socialTaskController.text != dbTask) {
            _socialTaskController.text = dbTask;
          }
        });
      }
    } catch (e) {
      AppLogger.w('social.load', e);
      if (mounted) setState(() => _dbDegraded = true);
    }
  }

  /// 页签列表（顺序与 TabBarView children 严格对应）。
  ///
  /// ★ 顺带修一个 0.47 的遗漏：TAB5（社交日志）的视图一直存在、控制器
  ///   length=5，但页签数组漏了第 5 个 Tab —— 日志页只能靠滑动到达、
  ///   无页签可点。这里一并补上。
  List<Tab> _buildTabs(AppLocalizations l10n) => [
        Tab(icon: const Icon(Icons.face), text: l10n.socialTabMask),
        Tab(icon: const Icon(Icons.radar), text: l10n.socialTabRadar),
        Tab(icon: const Icon(Icons.people_alt), text: l10n.socialTabRoster),
        // 托办：仅进阶模式（可藏）。
        if (!_simpleMode)
          Tab(
              icon: const Icon(Icons.assignment_outlined),
              text: l10n.delegationTitle),
        // 日志：**恒常显**（含入门模式）——「待我确认的建议」的唯一入口。
        Tab(
            icon: const Icon(Icons.article_outlined),
            text: l10n.socialTabLogs),
      ];

  Future<void> _toggleLinkSwitch(String key, bool val) async {
    // 委托 RadarService：内部有并发锁 + 硬件自愈 + prefs 持久化
    await RadarService.instance.setChannel(key, val);
    // 开云端通道 = 分身要隔着网络值班：顺手把值班权限要齐（先讲理由，
    // 拒绝不阻断——App 内功能照旧，只是退后台可能被系统暂停）。
    if (val && key == 'link_cloud_enabled' && mounted) {
      unawaited(ensureDutyOnboarding(context));
    }
    await _loadDataOnly();
  }

  /// 0.89.0：进名册页时的**静默**自动拉取（开关关 / 冷却中 ⇒ 内部直接返回，零网络）。
  Future<void> _maybeAutoPullQuiet() async {
    try {
      final res = await FederationAutoPull.maybePull();
      if (res.added > 0 && mounted) {
        _showSnackBar(
            AppLocalizations.of(context).socialFederationAutoDone(res.added));
        await _loadDataOnly();
      }
    } catch (e) {
      AppLogger.w('social.autopull', e);
    }
  }

  /// 开关翻转：写穿 prefs；打开时**立刻**拉一次让效果可见（force 只跳过节流窗，
  /// 单次/总量上限仍在）。关掉只落开关，不删任何已收录的行 ——
  /// 那些行要删由「清空联邦自动收录」显式决定（不可逆动作不藏在开关里）。
  Future<void> _toggleAutoPull(bool val) async {
    await FederationAutoPull.setEnabled(val);
    if (!mounted) return;
    setState(() => _autoPullEnabled = val);
    if (!val) return;
    final l10n = AppLocalizations.of(context);
    _showSnackBar(l10n.socialFederationFetching);
    final res = await FederationAutoPull.maybePull(force: true);
    if (!mounted) return;
    if (res.error != null) {
      _showSnackBar(l10n.socialFederationAutoFailed(res.error!), isError: true);
    } else if (res.added > 0) {
      _showSnackBar(l10n.socialFederationAutoDone(res.added));
    } else {
      _showSnackBar(l10n.socialFederationAutoNone);
    }
    await _loadDataOnly();
  }

  /// 一键清空「联邦自动收录」：只删机器拉的、尚未交往的行（判据在 DBHelper）。
  Future<void> _clearAutoPulled() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.socialFederationAutoClearTitle),
        content: Text(l10n.socialFederationAutoClearConfirm(_autoPulledCount)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.socialDone)),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await DBHelper.clearAutoPulledAgents();
    if (!mounted) return;
    _showSnackBar(l10n.socialFederationAutoCleared(removed));
    await _loadDataOnly();
  }

  Future<void> _toggleRadar() async {
    // 委托 RadarService：内部处理保活、引擎启停、限时派对与心跳
    if (RadarService.instance.isProcessing) return;
    if (RadarService.instance.isPatrolling) {
      await RadarService.instance.stop();
    } else {
      // ★ 0.50.0（体检 P1-7「敏感权限用途说明」）：雷达内部会**裸弹**
      //   「定位 + 蓝牙 / 附近设备」系统框（`p2p_service._requestPermissions`）。
      //   先把"为什么系统会要定位"讲清；用户点「暂不」就到此为止 —— 不启动雷达。
      if (mounted && !await ensureRadarPermissions(context)) return;
      if (!mounted) return;
      // ★ 上岗流必须先于 start()：radar 内部的保活会裸弹系统权限框——
      //   先讲理由、先拿权限，裸框就只剩"已授权即静默"，值班引导不落空。
      if (mounted) await ensureDutyOnboarding(context);
      if (!mounted) return;
      await RadarService.instance.start(minutes: _selectedDurationMinutes);
    }
    if (!mounted) return;
    setState(() {
      if (RadarService.instance.isPatrolling) {
        _radarController.repeat();
      } else {
        _radarController.stop();
      }
    });
    await _loadDataOnly();
  }

  Future<void> _refreshContacts() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    
    // ★ 0.50.0（P1-5）：整段兜住 —— 改前这一路异常会让 `_isLoading` **永远停在 true**。
    try {
   // 1. 刷新在线状态
    final friends = await DBHelper.getAgentFriends();
    for (var f in friends) {
      final id = f['agent_id'];
      bool isOnline = P2PService().connectedAgents.contains(id) || LanService().connectedLanAgents.contains(id);
      
      // 🚀 核心修复 5：防止误伤云端连接。如果开启了云端通道，且该节点目前在数据库是离线的，
      // 我们不能因为近场雷达没扫到他，就强行把他踢下线，维持原状态即可。
      if (!isOnline && _isCloudEnabled) {
        isOnline = f['is_online'] == 1; 
      }
      
      await DBHelper.updateAgentOnlineStatus(f['id'], isOnline);
    }
    
    // 2. 🚀 响应用户需求：加入强力刺激引擎！
    _showSnackBar(l10n.socialFeedBrain);
    await AgentService().triggerMassStimulus(); // 调用刚才写的群发引擎
    
    await _loadDataOnly();
    } catch (e) {
      AppLogger.w('social.refresh', e);
      if (mounted) setState(() => _dbDegraded = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAmbassador() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    await DBHelper.saveAmbassador('nickname', _nicknameController.text.trim());
    await DBHelper.saveAmbassador('mask_profile', _maskProfileController.text.trim());
    await DBHelper.saveAmbassador('avatar', _avatarController.text.trim());
    await DBHelper.saveAmbassador('social_task', _socialTaskController.text.trim());
    
    // 🚀 核心修复 3：用户手动锁定新人设时，必须清空旧的人设交互记忆！
    await DBHelper.clearAllSocialLogsAndResetHandshakes();

    _showSnackBar(l10n.socialMaskLocked);
    if (mounted) setState(() => _saving = false);
  }

  void _showAddFriendDialog() {
    final l10n = AppLocalizations.of(context);
    final aNameCtrl = TextEditingController();
    final mNameCtrl = TextEditingController();
    final idCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(l10n.socialManualPairTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: aNameCtrl, decoration: InputDecoration(labelText: l10n.socialPeerAgentName)),
                TextField(controller: mNameCtrl, decoration: InputDecoration(labelText: l10n.socialPeerMasterName)),
                TextField(controller: idCtrl, decoration: InputDecoration(labelText: l10n.socialPeerHardId)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
            ElevatedButton(
              onPressed: () async {
                if (aNameCtrl.text.isNotEmpty && idCtrl.text.isNotEmpty) {
                  await DBHelper.insertAgentFriend(
                    aNameCtrl.text.trim(), mNameCtrl.text.trim(), idCtrl.text.trim(), "friend", l10n.socialSourceManual, l10n.socialNoSignatureBadge, "🤖"
                  );
                  Navigator.pop(context);
                  _loadDataOnly();
                  _showSnackBar(l10n.socialNodeAdded);
                }
              },
              child: Text(l10n.socialPair),
            )
          ],
        );
      },
    );
  }

  void _showCustomGreetDialog(String targetAgentId, String targetName) {
    final l10n = AppLocalizations.of(context);
    final instructCtrl = TextEditingController();
    // M4 在场证据：这个弹窗里输入的就是"主人亲手写的话"，逐键/粘贴在此采集。
    final compose = ComposeTracker();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(l10n.socialForceSendTitle(targetName)),
          content: TextField(
            controller: instructCtrl, maxLines: 2,
            decoration: InputDecoration(labelText: l10n.socialForceSendLabel, hintText: l10n.socialForceSendHint, border: const OutlineInputBorder()),
            onChanged: (t) => compose.onChanged(t),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor),
              onPressed: () {
                final text = instructCtrl.text.trim();
                if (text.isEmpty) return;
                final evidence = compose.evidence(totalChars: text.length);
                Navigator.pop(context);
                _showSnackBar(l10n.socialDirectSent);
                AgentService()
                    .manualProactiveMessage(targetAgentId, text, evidence: evidence);
              },
              child: Text(l10n.socialDirectSend, style: const TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }

  Future<void> _changeTier(int id, String newTier) async {
    await DBHelper.updateAgentTier(id, newTier);
    _loadDataOnly();
  }

  /// 🎁 从名册直接送礼（走全部已开启通道）
  Future<void> _sendGiftTo(Map<String, dynamic> friend) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final picked = await showGiftPickerDialog(context, theme);
    if (picked == null) return;
    final ok = await AgentService().sendGiftToAgent(
        friend['agent_id']?.toString() ?? '', picked.$1, picked.$2);
    if (!mounted) return;
    _showSnackBar(ok ? l10n.socialGiftSent(picked.$1) : l10n.socialGiftFailed);
    _loadDataOnly();
  }

  /// 🤝 从名册直接索取推荐信
  Future<void> _requestRecoFrom(Map<String, dynamic> friend) async {
    final l10n = AppLocalizations.of(context);
    final ok = await AgentService().sendRecoRequest(friend['agent_id']?.toString() ?? '');
    if (!mounted) return;
    _showSnackBar(ok ? l10n.socialRecoSent : l10n.socialRecoFailed);
    _loadDataOnly();
  }

  /// 🔐 身份指纹核验（防中间人）：双方见面时，把对方手机「外交假面」页显示的
  /// 8 位指纹输入进来，与本机 TOFU 固定值比对。
  /// 一致 = 本机固定的公钥确实是对方的设备密钥；不一致 = 疑似中间人，立即拉黑。
  void _showIdentityVerifyDialog(Map<String, dynamic> friend) {
    final agentId = friend['agent_id']?.toString() ?? '';
    final agentName = friend['agent_name']?.toString() ?? agentId;
    final hasPin = SessionCrypto.instance.hasIdentityPin(agentId);
    final pinned = SessionCrypto.instance.identityFingerprint(agentId);
    final inputCtrl = TextEditingController();
    int? verdict; // null=未比对 1=一致 0=不一致
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Provider.of<ThemeProvider>(ctx);
        final isDark = theme.isDark;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            title: Text(l10n.socialVerifyTitle(agentName)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.socialVerifyPinnedFor,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPin ? pinned : l10n.socialVerifyNoPin,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Courier', letterSpacing: 3, color: theme.accentColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.socialVerifyMyFingerprint(_myFingerprint),
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, fontFamily: 'Courier'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: inputCtrl,
                    maxLength: 8,
                    enabled: hasPin,
                    decoration: InputDecoration(
                      labelText: l10n.socialVerifyInputLabel,
                      counterText: "",
                    ),
                  ),
                  if (verdict == 1) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(l10n.socialVerifyMatch, style: const TextStyle(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  if (verdict == 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        l10n.socialVerifyMismatch,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  if (!hasPin) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.socialVerifyHintNoPin,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: Colors.white),
                onPressed: !hasPin
                    ? null
                    : () {
                        final input = inputCtrl.text.trim().toLowerCase();
                        setDialogState(() => verdict = (input == pinned.toLowerCase()) ? 1 : 0);
                      },
                child: Text(l10n.socialVerifyCompare),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🌐 A2A 联邦发现：拉取 Hub 名册，把未收录的注册 Agent 一键加入捕获名册（陌生档）。
  /// 只做"发现+收录"，搭讪仍走现有安全机制（网关审查/观察模式建议卡），不在此自动发信。
  Future<void> _showFederationDiscovery() async {
    final l10n = AppLocalizations.of(context);
    final myId = await DBHelper.getAmbassador('my_agent_id') ?? '';
    if (myId.isEmpty) {
      _showSnackBar(l10n.socialFederationNoIdentity, isError: true);
      return;
    }

    _showSnackBar(l10n.socialFederationFetching);
    final roster = await CloudService().fetchA2aRoster(myId);
    if (!mounted) return;
    if (roster.isEmpty) {
      _showSnackBar(l10n.socialFederationEmpty(CloudService().lastError ?? l10n.socialFederationEmptyErr), isError: true);
      return;
    }

    final friends = await DBHelper.getAgentFriends();
    final knownIds = friends.map((f) => f['agent_id'] as String?).toSet();
    final unknown =
        roster.where((a) => a['agent_id'] != myId && !knownIds.contains(a['agent_id'])).toList();

    if (!mounted) return;
    if (unknown.isEmpty) {
      _showSnackBar(l10n.socialFederationAllKnown(roster.length));
      return;
    }

    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = theme.isDark;
    await showDialog(
      context: context,
      builder: (ctx) {
        var adding = <String>[];
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            title: Text(l10n.socialFederationTitle(unknown.length)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: unknown.length,
                itemBuilder: (ctx, i) {
                  final a = unknown[i];
                  final id = a['agent_id'].toString();
                  final added = adding.contains(id);
                  return ListTile(
                    dense: true,
                    leading: const Text('🤖'),
                    title: Text(a['nickname']?.toString() ?? l10n.socialAnonAgent,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      l10n.socialFederationLastSeen(id, _formatTime(((a['last_seen'] as num?) ?? 0).toInt())),
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                    trailing: added
                        ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                        : TextButton(
                            onPressed: () async {
                              // 拉取 Agent Card 补全人设（失败则用占位，不阻断收录）
                              final card = await CloudService().fetchA2aCard(myId, id);
                              final mask = card?['description']?.toString() ?? l10n.socialFederationDiscovered;
                              await DBHelper.insertAgentFriend(
                                a['nickname']?.toString() ?? l10n.socialAnonAgent,
                                l10n.socialFederationSource,
                                id,
                                'stranger',
                                l10n.socialFederationMask,
                                mask,
                                '🌐',
                              );
                              // 弹窗可能已被关闭，防 setDialogState 崩溃
                              try {
                                setDialogState(() => adding.add(id));
                              } catch (_) {}
                            },
                            child: Text(l10n.socialCollect, style: const TextStyle(fontSize: 12)),
                          ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (adding.isNotEmpty) {
                    _loadDataOnly();
                    _showSnackBar(l10n.socialFederationCollected(adding.length));
                  }
                },
                child: Text(l10n.socialDone),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.redAccent : null, duration: const Duration(seconds: 2)));
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  // 🚀 终极丝滑版：赛博雷达（加入减速缓动曲线，极致顺畅）
  Widget _buildRadarScanner(ThemeProvider theme) {
    final l10n = AppLocalizations.of(context);
    final isAnimating = _isPatrolling;
    final isDark = theme.isDark;

    // 💡 尺寸控制器：在此修改整体雷达大小（默认76.0，越小越精致）
    final double radarSize = 66.0; 
    final double iconSize = radarSize * 0.42; 

    final staticCenterButton = Container(
      width: radarSize,
      height: radarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isAnimating 
            ? theme.accentColor 
            : (isDark ? Colors.grey[850] : Colors.grey[200]),
        boxShadow: isAnimating
            ? [BoxShadow(color: theme.accentColor.withOpacity(0.4), blurRadius: 15, spreadRadius: 1)]
            : [],
      ),
      child: Icon(
        isAnimating ? Icons.sensors_rounded : Icons.power_settings_new_rounded,
        color: isAnimating ? Colors.white : Colors.grey,
        size: iconSize,
      ),
    );

    return Column(
      children: [
        GestureDetector(
          onTap: _toggleRadar,
          child: Center(
            child: RepaintBoundary(
              child: SizedBox(
                // 🚀 给波纹扩散留足空间（乘 2.5 倍），防止边缘被砍断
                width: radarSize * 2.5, 
                height: radarSize * 2.5,
                child: AnimatedBuilder(
                  animation: _radarController,
                  child: staticCenterButton,
                  builder: (context, child) {
                    // 🚀 核心修复 3：加入 Curves (非线性缓动)
                    // 让波纹一开始爆发式弹出，然后极其丝滑地减速消失！
                    final curve = Curves.easeOutQuart; 
                    final val1 = curve.transform(_radarController.value);
                    final val2 = curve.transform((_radarController.value + 0.5) % 1.0);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isAnimating) ...[
                          _buildPulseRing(radarSize, val1, theme.accentColor),
                          _buildPulseRing(radarSize, val2, theme.accentColor),
                        ],
                        child!,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        
        // 🚀 局部刷新的倒计时文本（完美规避卡顿）
        if (_isPatrolling)
          ValueListenableBuilder<String>(
            valueListenable: _timeLeftNotifier,
            builder: (context, timeStr, child) {
              if (timeStr.isEmpty) return const SizedBox.shrink();
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white, 
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: theme.accentColor.withOpacity(0.5))
                  ),
                  child: Text(
                    l10n.socialCountdown(timeStr), 
                    style: TextStyle(color: theme.accentColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Courier')
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // 🚀 高效波纹绘制器
  Widget _buildPulseRing(double baseSize, double animValue, Color color) {
    return Transform.scale(
      // 扩散最终大小：(1.0 + 1.0) 倍 = 原大小的 2 倍。您可以微调这个 1.0 的数字。
      scale: 1.0 + (animValue * 1.0), 
      child: Opacity(
        // 透明度随动画进程丝滑减淡
        opacity: (1.0 - animValue).clamp(0.0, 1.0),
        child: Container(
          width: baseSize,
          height: baseSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
      ),
    );
  }
  

  /// M3 互介卡：生成草稿 → **主人预览确认** → 发出（发出后 24h 内可撤回）。
  /// 三级披露在本 UI 的体现：只有 nickname / mask_profile（第②级）上卡；
  /// 第③级键集合在核心层 fail-closed，即使误填其值也会被整卡拒绝。
  Future<void> _showInterCardDialog(String toAgentId) async {
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final reasonCtrl = TextEditingController();
    final topicsCtrl = TextEditingController();

    // 第②级（互介可用）字段：沿用外交假面里主人公开的人设
    final nickname = await DBHelper.getAmbassador('nickname') ?? '';
    final maskProfile = await DBHelper.getAmbassador('mask_profile') ?? '';
    final level2 = <String, String>{
      'nickname': nickname,
      'mask_profile': maskProfile,
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.intercardDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              onPressed: () async {
                // 未确认的卡在这里生成 → 立刻 approve（预览即确认），
                // **没有 approve 的路径不会发出**（核心层强制）。
                Navigator.pop(ctx, true);
              },
              child: Text(l10n.intercardConfirmSend)),
        ],
      ),
    );
    if (ok != true) return;

    final topics = parseTopics(topicsCtrl.text);
    // M5 收口：互介卡必须挂在"我的圈"上，不再无条件硬编码 'direct'。
    // 'direct' 只作为"确实没有任何圈"的退化兜底（区别于"有圈却挂着 direct"）。
    final ownerId = await WoldRuntime.i.myAgentId();
    final myCircle = await WoldRuntime.i.primaryCircle(ownerId);
    final gen = await WoldRuntime.i.intercards.generate(
      circleId: myCircle?.id ?? 'direct',
      ownerId: ownerId,
      toId: toAgentId,
      reason: reasonCtrl.text.trim(),
      topics: topics,
      fields: level2,
      forbiddenKeys: {'phone', 'home_address', 'legal_name', 'id_number', 'email'},
    );
    if (!mounted) return;
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
      return;
    }
    // 主人确认（签名）→ 发出 → 24h 内可在"我的圈"撤回
    final approved = await WoldRuntime.i.intercards.approve(
        id: gen.card!.id, approverId: gen.card!.ownerId);
    if (approved != null) {
      await WoldRuntime.i.intercardRelay.dispatch(approved);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.intercardSentOk)));
  }

  /// M3 互介卡收发箱：收到的（对方主人签名背书）+ 我发出的（24h 内可撤回）。
  Widget _buildInterCards(ThemeProvider theme) {
    final l10n = AppLocalizations.of(context);
    final isDark = theme.isDark;
    final now = DateTime.now().millisecondsSinceEpoch;
    final sub = TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38);

    Widget card(InterCard c, {bool mine = false}) {
      final meta = mine
          ? (c.state == InterCardState.revoked
              ? l10n.intercardRevoked
              : c.canRevokeAt(now)
                  ? l10n.intercardRevokeHint
                  : l10n.intercardSent)
          : l10n.intercardFrom(c.ownerId);
      return Card(
        color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🤝 ${c.reason}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
              if (c.topics.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(c.topics.join(' · '), style: TextStyle(fontSize: 12, color: theme.accentColor)),
                ),
              const SizedBox(height: 6),
              Text(meta, style: sub),
              if (mine && c.canRevokeAt(now))
                TextButton(
                  onPressed: () async {
                    final revoked = await WoldRuntime.i.intercards.revoke(id: c.id, revokerId: c.ownerId);
                    if (revoked != null) await WoldRuntime.i.intercardRelay.dispatchRevoke(revoked);
                    if (mounted) await _loadDataOnly();
                  },
                  child: Text(l10n.intercardRevoke),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Icon(Icons.redeem, size: 18, color: theme.accentColor),
            const SizedBox(width: 8),
            Text(l10n.intercardReceivedTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
          ]),
        ),
        if (_intercardsIn.isEmpty && _intercardsMine.isEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l10n.intercardNone, style: sub))
        else ...[
          for (final c in _intercardsIn) card(c),
          if (_intercardsMine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(l10n.intercardMineTitle, style: sub),
            ),
          for (final c in _intercardsMine) card(c, mine: true),
        ],
      ],
    );
  }

  Widget _buildTierList(String tier, String title, IconData icon, ThemeProvider theme) {    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    final list = _agentFriends.where((e) => e['tier'] == tier).toList();
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Icon(icon, size: 18, color: theme.accentColor), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))])),
        ListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: list.length,
          itemBuilder: (context, index) {
            final friend = list[index];
            final isOnline = friend['is_online'] == 1; 
            
            final lastChatTime = friend['last_chat_time'] as int? ?? 0;
            final isHotChatting = isOnline && (DateTime.now().millisecondsSinceEpoch - lastChatTime < 3 * 60 * 1000);

            final handshake = friend['handshake_status'] ?? 'none';
            String statusBadge = '';
            Color badgeColor = Colors.grey;
            if (handshake == 'sent') { statusBadge = l10n.socialBadgeSent; badgeColor = Colors.orange; }
            else if (handshake == 'received') { statusBadge = l10n.socialBadgeReviewing; badgeColor = Colors.purple; }
            else if (handshake == 'accepted') { statusBadge = l10n.socialBadgeChatting; badgeColor = Colors.green; }
            else if (handshake == 'rejected') { statusBadge = l10n.socialBadgeBlocked; badgeColor = Colors.red; }

            // 🚀 获取该节点的聊天总条数
            final msgCount = _msgCounts[friend['agent_id']] ?? 0;

            return Card(
              color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ContactDetailScreen(friendData: friend))); },
                leading: Stack(
                  clipBehavior: Clip.none, // 允许气泡稍微超出边缘
                  children: [
                    CircleAvatar(backgroundColor: isOnline ? theme.accentColor.withOpacity(0.2) : Colors.grey.withOpacity(0.2), child: Text(friend['avatar'] ?? '🤖', style: const TextStyle(fontSize: 20))),
                    
                    // 🚀 如果离线且无对话，不显示绿点。如果在线且5分钟内聊过，才显示热聊绿点。
                    if (isHotChatting) Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                    
                    // 🚀 核心新增：炫酷的未读/已聊消息数量气泡！
                    if (msgCount > 0)
                      Positioned(
                        right: -4, top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          child: Text(
                            msgCount > 99 ? '99+' : msgCount.toString(),
                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(child: Text("Agent@${friend['agent_name']}", overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: isOnline ? (isDark ? Colors.white : Colors.black87) : Colors.grey))),
                    // M4 本人到场：签名验证过、未过期的信号才显示（不是"在线"）
                    if (_peerPresence.contains(friend['agent_id'])) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(l10n.socialPresenceOnline,
                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    if (statusBadge.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)), child: Text(statusBadge, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
                    ]
                  ],
                ),
                subtitle: Text(l10n.socialPeerSubtitle(friend['master_name'], isOnline ? l10n.socialStatusOnline : l10n.socialStatusOffline, friend['agent_id'], '${friend['reputation'] ?? ReputationService.defaultScore}'), style: TextStyle(fontSize: 11, color: isOnline ? (isDark ? Colors.white54 : Colors.black54) : Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ★ M2「私下 1:1 私聊」的**可见入口**（PRD §10.3 记的缺口）。
                    //   以前只能靠"点整张卡片"进详情页 —— 而卡片上没有任何提示，
                    //   用户看不出那里能私聊。这里给一个显式按钮（整张卡仍可点）。
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      color: theme.accentColor,
                      tooltip: l10n.socialChatTooltip,
                      onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ContactDetailScreen(friendData: friend))); },
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : Colors.black54),
                      onSelected: (val) {
                        if (val == 'delete') { DBHelper.deleteAgentFriend(friend['id']).then((_) => _loadDataOnly()); }
                        else if (val == 'greet') { _showCustomGreetDialog(friend['agent_id'], friend['agent_name']); }
                        else if (val == 'verify') { _showIdentityVerifyDialog(friend); }
                        else if (val == 'gift') { _sendGiftTo(friend); }
                        else if (val == 'reco') { _requestRecoFrom(friend); }
                        // M2 事务委托入口：从名册直接对某个分身发起托办
                        else if (val == 'delegate') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => DelegationScreen(
                            presetPeerId: friend['agent_id'] as String?,
                            presetPeerName: friend['agent_name'] as String?,
                          )));
                        }
                        // M3 互介卡：生成草稿 → 主人预览确认 → 发出（24h 内可撤回）
                        else if (val == 'intercard') {
                          _showInterCardDialog(friend['agent_id'] as String? ?? '');
                        }
                        // ★ M2 私聊入口（与卡片上的 💬 按钮同一去处）
                        else if (val == 'chat') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ContactDetailScreen(friendData: friend)));
                        }
                        else { _changeTier(friend['id'], val); }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        PopupMenuItem(value: 'chat', child: Text(l10n.socialMenuChat)),
                        PopupMenuItem(value: 'delegate', child: Text(l10n.socialMenuDelegate)),
                        PopupMenuItem(value: 'intercard', child: Text(l10n.socialMenuIntercard)),
                        PopupMenuItem(value: 'greet', child: Text(l10n.socialMenuGreet)),
                        PopupMenuItem(value: 'gift', child: Text(l10n.socialMenuGift)),
                        PopupMenuItem(value: 'reco', child: Text(l10n.socialMenuReco)),
                        PopupMenuItem(value: 'verify', child: Text(l10n.socialMenuVerify)),
                        if (tier != 'family') PopupMenuItem(value: 'family', child: Text(l10n.socialMenuFamily)),
                        if (tier != 'friend') PopupMenuItem(value: 'friend', child: Text(l10n.socialMenuFriend)),
                        if (tier != 'stranger') PopupMenuItem(value: 'stranger', child: Text(l10n.socialMenuStranger)),
                        PopupMenuItem(value: 'delete', child: Text(l10n.socialMenuDelete, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    if (_isLoading) return Container(color: Colors.transparent, child: Center(child: CircularProgressIndicator(color: theme.accentColor)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.socialRadarTitle), backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          const HelpAction(topic: HelpTopic.socialOverview),
        ],
        bottom: TabBar(
          controller: _tabController, indicatorColor: theme.accentColor, labelColor: theme.accentColor, unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          // ★ 0.62.0：进阶模式 5 个页签（外交假面 / 雷达状态 / 捕获名册 / 托办 / 日志）在
          //   窄屏上**平分宽度会把标题截断**（"外交假""雷达状""捕获名"）。改为**可横向滑动**：
          //   每个页签取自然宽度，整条 TabBar 随当前页签滚动 —— 与下面 TabBarView 的左右
          //   滑动方向一致（滑页面 ⇄ 滑页签）。
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          // 0.46.0：托办（M1+M2）从"藏起来的 AppBar 按钮"升为第 4 个页签 —— 原入口要
          // 用户无意间才发现，这里让它直接可见（按钮已移除，只在名册卡片菜单保留直达）。
          tabs: _buildTabs(l10n),
        ),
      ),
      body: Column(
        children: [
          // ★ 0.50.0（P1-5）：本地库读不到时的**降级提示条** ——
          //   改前 DB 异常会让本页永远停在转圈（既没提示、也没出路）。
          if (_dbDegraded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.orange.shade900 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(children: [
                const Icon(Icons.storage, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.socialDbDegradedHint,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                TextButton(
                  onPressed: _retryInitialLoad,
                  child: Text(l10n.commonRetry),
                ),
              ]),
            ),
          Expanded(
            child: TabBarView(
        controller: _tabController,
        children: [
// ==================== TAB 1: 外交假面与任务 (全息特工名片重构版) ====================
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: isDark ? Colors.black87 : Colors.white.withOpacity(0.9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 6,
                shadowColor: theme.accentColor.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🌟 1. 【超酷核心点】全息特工名片实时预览盘 (Holographic Card Preview)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark 
                              ? [theme.accentColor.withOpacity(0.25), Colors.black45]
                              : [theme.accentColor.withOpacity(0.15), Colors.white],
                          ),
                          border: Border.all(color: theme.accentColor.withOpacity(0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: theme.accentColor.withOpacity(0.1),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Stack(
                          children: [
                            // 科技感网格背景线（装饰用）
                            Positioned(
                              right: -10, top: -10,
                              child: Icon(Icons.grid_3x3, size: 80, color: theme.accentColor.withOpacity(0.08)),
                            ),
                            Row(
                              children: [
                                // 呼吸灯头像框
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.accentColor.withOpacity(0.1),
                                    border: Border.all(color: theme.accentColor, width: 2),
                                    boxShadow: [
                                      BoxShadow(color: theme.accentColor.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)
                                    ]
                                  ),
                                  child: Center(
                                    child: Text(
                                      _avatarController.text.isEmpty ? '🤖' : _avatarController.text,
                                      style: const TextStyle(fontSize: 32)
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _nicknameController.text.isEmpty ? l10n.socialMaskUndefined : "Agent@${_nicknameController.text}",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87, letterSpacing: 1),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _maskProfileController.text.isEmpty ? l10n.socialMaskNoSignature : _maskProfileController.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, fontStyle: FontStyle.italic),
                                      ),
                                      const SizedBox(height: 6),
// 🚀 核心修复 1：将本机的硬核 Agent ID 骄傲地展示在卡片上！
                                      Text(
                                        l10n.socialHardId(_myAgentIdController.text),
                                        style: TextStyle(fontSize: 10, color: theme.accentColor, fontFamily: 'Courier', fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      // 🔐 设备身份指纹：近场首次握手时，两位主人当面比对这 8 位码，防中间人
                                      Text(
                                        l10n.socialFingerprintLine(_myFingerprint),
                                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54, fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 1),
                                      ),
                                      const SizedBox(height: 6),
                                      // 动态闪烁绿灯
                                      Row(
                                        children: [
                                          Container(
                                            width: 6, height: 6,
                                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(l10n.socialGatewayGuard, style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                        ],
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 🌟 2. 场景逻辑选择下拉菜单
                      Row(
                        children: [
                          Icon(Icons.psychology, color: theme.accentColor, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.socialLogicPreset, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[100], 
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1.0)
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                            value: _currentMode,
                            // M10：候选来自唯一事实源 PersonaModes（顺序 = all 的顺序）
                            items: [
                              for (final m in PersonaModes.all)
                                DropdownMenuItem(
                                  value: m.id,
                                  child: Text(
                                    '${m.isFree ? '' : '🔒 '}${_personaLabel(l10n, m.id)}',
                                    style: m.id == PersonaModes.emergency
                                        ? const TextStyle(color: Colors.redAccent)
                                        : null,
                                  ),
                                ),
                            ],
                            onChanged: (val) async {
                              if (val == null) return;
                              // M10：头像/昵称/任务的默认值也来自注册表，UI 与工具不再各写一份
                              final persona = PersonaModes.resolve(val);
                              await DBHelper.saveAmbassador('social_mode', persona.id);
                              _avatarController.text = persona.avatar;
                              _nicknameController.text = persona.nickname;
                              // ★ 2026-10-07：若该模式的默认任务是"占位空话"
                              //   （casual 的"无特定任务…"、custom 的"自由交流"），
                              //   自动补一条该模式下的内置外交任务，而不是把空话填进去。
                              _socialTaskController.text = DiplomaticTasks.effective(
                                mode: persona.id,
                                stored: persona.defaultTask,
                                agentId: _myAgentIdController.text.trim(),
                              );

                              await DBHelper.saveAmbassador('avatar', _avatarController.text);
                              await DBHelper.saveAmbassador('nickname', _nicknameController.text);
                              await DBHelper.saveAmbassador('social_task', _socialTaskController.text);

                              // M10 铁律：切换人格 = 换语气，不改身份、不清记忆。
                              // 改造前此处调 clearAllSocialLogsAndResetHandshakes()，
                              // 会把对方眼里的你变成陌生人（信任稀释），故移除。
                              _showSnackBar(l10n.socialModeSwitched(persona.id));

                              _loadDataOnly();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // M10：paid 档只是标识（计费未上线）—— 说明改走问号，不再常驻小字
                      Align(
                        alignment: Alignment.centerLeft,
                        child: HelpDot(topic: HelpTopic.socialPersonaTier),
                      ),
                      const SizedBox(height: 20),

                      // 🌟 3. 【高度对齐重构】皮肤与昵称输入组
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 彻底废除计数器，高度与右侧TextField完全等高对齐
                          Container(
                            width: 64, height: 56, // 🚀 完美对齐 Material3 默认输入框高度
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1.0)
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                TextField(
                                  controller: _avatarController,
                                  maxLength: 1, // 🚀 强制1个Emoji，防止计数器撑破容器
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 24),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.zero,
                                    counterText: "", // 🚀 隐藏讨厌的 "1/2" 计数器
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                // 小小的浮动标签
                                Positioned(
                                  top: 4, left: 6,
                                  child: Text(l10n.socialEmojiLabel, style: TextStyle(fontSize: 8, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _nicknameController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: l10n.socialNicknameLabel,
                                filled: true,
                                fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isDark ? BorderSide.none : const BorderSide(color: Colors.black12, width: 1.0)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isDark ? BorderSide.none : const BorderSide(color: Colors.black12, width: 1.0)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.accentColor, width: 1.5)),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 🌟 4. 对外脱敏人设输入框
                      TextField(
                        controller: _maskProfileController,
                        maxLines: 2,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: l10n.socialMaskProfileLabel,
                          filled: true,
                          fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isDark ? BorderSide.none : const BorderSide(color: Colors.black12, width: 1.0)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isDark ? BorderSide.none : const BorderSide(color: Colors.black12, width: 1.0)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.accentColor, width: 1.5)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      
                      // 🌟 5. 【终端化重构】当前社交战术任务框（特工暗黑机密终端风格）
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black38 : Colors.blueGrey.withOpacity(0.06), 
                          borderRadius: BorderRadius.circular(16), 
                          border: Border.all(color: theme.accentColor.withOpacity(0.2), width: 1.0)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.radar_rounded, color: theme.accentColor, size: 16),
                                const SizedBox(width: 6),
                                Text(l10n.socialIcebreakTask, style: TextStyle(fontWeight: FontWeight.bold, color: theme.accentColor, fontSize: 12, letterSpacing: 0.5)),
                                const Spacer(),
                                // 🎲 换一个：从内置外交任务库**显式**换一条（与自动补空的
                                //   确定性刻意相反 —— 用户主动换就要变）。
                                InkWell(
                                  onTap: () {
                                    final next = DiplomaticTasks.reroll(
                                      _currentMode,
                                      avoid: _socialTaskController.text,
                                    );
                                    setState(() => _socialTaskController.text = next);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🎲', style: TextStyle(fontSize: 12)),
                                        const SizedBox(width: 3),
                                        Text(
                                          l10n.socialTaskReroll,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accentColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _socialTaskController, 
                              focusNode: _socialTaskFocus,
                              maxLines: 2, 
                              decoration: InputDecoration(
                                hintText: l10n.socialIcebreakHint, 
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero
                              ), 
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontFamily: 'Courier'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity, 
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accentColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ), 
                          onPressed: _saveAmbassador, 
                          label: Text(l10n.socialLockMask, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1))
                        )
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ==================== TAB 2: 雷达与网络设置 (移至第二位置) ====================
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🚀 这里现在已经内置了雷达和新的局部刷新倒计时！
            _buildRadarScanner(theme),
            const SizedBox(height: 12),
            
            Center(
              child: Text(
                _isPatrolling 
                  ? l10n.socialHeartbeatOn 
                  : l10n.socialRadarIdle, 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isPatrolling ? theme.accentColor : Colors.grey)
              )
            ),
            const SizedBox(height: 20),
            
            if (!_isPatrolling)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.socialDurationLabel, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  DropdownButton<int>(
                    value: _selectedDurationMinutes,
                    dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                    style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold),
                    items: [
                      DropdownMenuItem(value: 15, child: Text(l10n.socialDuration15)),
                      DropdownMenuItem(value: 30, child: Text(l10n.socialDuration30)),
                      DropdownMenuItem(value: 60, child: Text(l10n.socialDuration60)),
                      DropdownMenuItem(value: 999999, child: Text(l10n.socialDurationUnlimited)),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDurationMinutes = val);
                    },
                  )
                ],
              ),

            const SizedBox(height: 24),
            Card(
              color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ★ 0.47.0：网络排障指南从常驻橙框收进「?」（帮助类文字不上墙，
                    //   挂问号就删原小字 —— 与 0.41.0 的 help 纪律一致）。
                    HelpTitle(
                      text: l10n.socialChannelConfig,
                      topic: HelpTopic.socialChannelGuide,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                    ),
                    // ★ 2026-09-29：雷达未开启时给一个**看得见**的说明。
                    //   原逻辑里雷达没开也能浏览名册、也能点发送，而发送会**静默失败**，
                    //   用户无从判断到底是"我没开雷达"还是"对方不在线"（实测反馈）。
                    if (!_isPatrolling)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.radar_outlined, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.socialRadarOffHint,
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile(title: Text(l10n.socialChannelNearby, style: const TextStyle(fontSize: 13)), activeColor: theme.accentColor, value: _isNearFieldEnabled, onChanged: _isPatrolling ? (val) => _toggleLinkSwitch('link_near_field_enabled', val) : null),
                    SwitchListTile(title: Text(l10n.socialChannelLan, style: const TextStyle(fontSize: 13)), activeColor: theme.accentColor, value: _isLanEnabled, onChanged: _isPatrolling ? (val) => _toggleLinkSwitch('link_lan_enabled', val) : null),
                    SwitchListTile(title: Text(l10n.socialChannelCloud, style: const TextStyle(fontSize: 13)), activeColor: theme.accentColor, value: _isCloudEnabled, onChanged: _isPatrolling ? (val) => _toggleLinkSwitch('link_cloud_enabled', val) : null),
                  ],
                ),
              ),
            ),
            // ★ 0.47.0：「待我确认的建议」入口与「社交日志」流水已整体移入第 5 个
            //   页签（用户实测"看流水要先穿过雷达页"）—— 这里刻意不留副本。
          ],
        ),

// ==================== TAB 3: 捕获名册 (位置不变) ====================
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.socialRosterTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  Row(
                    children: [
                      IconButton(icon: Icon(Icons.travel_explore, color: theme.accentColor), tooltip: l10n.socialFederationDiscovered, onPressed: _showFederationDiscovery),
                      IconButton(icon: Icon(Icons.refresh, color: theme.accentColor), onPressed: _refreshContacts),
                      ElevatedButton.icon(onPressed: _showAddFriendDialog, icon: const Icon(Icons.add_link, size: 16, color: Colors.white), label: Text(l10n.socialPair, style: const TextStyle(fontSize: 12, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor)),
                    ],
                  )
                ],
              ),
              // 0.89.0：联邦名册「自动拉取」开关 + 一键清空机器收录项。
              // ★ 默认关 —— 让机器替主人把人拉进名册是**敏感的自主性**，必须显式开启；
              //   开启后也只做"收录"（拉公开名册），**绝不自动发信**（搭讪仍走既有
              //   网关审查 / 观察模式 / 预算闸）。清空只删"机器拉的 + 尚未交往的"。
              Card(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                margin: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      secondary: Icon(Icons.cloud_sync_outlined,
                          color: theme.accentColor, size: 20),
                      title: Text(l10n.socialFederationAutoTitle,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(l10n.socialFederationAutoDesc,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: isDark ? Colors.white60 : Colors.black54)),
                      activeColor: theme.accentColor,
                      value: _autoPullEnabled,
                      onChanged: (v) => _toggleAutoPull(v),
                    ),
                    if (_autoPulledCount > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 6),
                          child: TextButton.icon(
                            onPressed: _clearAutoPulled,
                            icon: const Icon(Icons.delete_sweep_outlined,
                                size: 16),
                            label: Text(
                                l10n.socialFederationAutoClear(_autoPulledCount),
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_agentFriends.isEmpty) 
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 赛博天线环网 (微动效)
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 110, height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.accentColor.withOpacity(0.15), width: 1.5)
                              ),
                            ),
                            Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.accentColor.withOpacity(0.2), width: 1, style: BorderStyle.solid)
                              ),
                            ),
                            Icon(Icons.wifi_find_rounded, size: 40, color: theme.accentColor.withOpacity(0.4)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.socialScanning,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Courier', letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.socialScanIdle,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              
              _buildInterCards(theme),
              _buildTierList('family', l10n.socialTierFamily, Icons.favorite, theme),
              _buildTierList('friend', l10n.socialTierFriend, Icons.people, theme),
              _buildTierList('stranger', l10n.socialTierStranger, Icons.help_outline, theme),
            ],
          ),

// ==================== TAB 4: 托办（M1 邻里圈 + M2 事务委托） ====================
// 与「从名册卡片菜单 push 出来的独立页」共用同一份 DelegationPanel 实现。
// ★ 0.61.0：本签**仅进阶模式**显示（入门模式收起；日志不受影响）。
          if (!_simpleMode) const DelegationPanel(),

// ==================== TAB 5: 社交日志（流水页，与雷达状态平齐） ====================
// 0.47.0：用户实测"看流水要先穿过整个雷达页" ⇒ 抽成独立页签；
// 「待我确认的建议」入口按用户要求**置顶**在本页（从雷达页签**移**来，不复制两份）。
// ★★★ 0.61.0：本签**恒常显**（含入门模式）—— AgentActionInboxScreen 全 App
//   只在这里被 push，收起日志 = 审批入口断链。**托办可藏，日志不可藏。**
          _buildLedgerTab(theme),
        ],
      ),
          ),
        ],
      ),
    );
  }

  /// 「社交日志」页签（0.47.0 从雷达状态页签抽出，与雷达状态平齐）。
  ///
  /// ★ 顶端是「待我确认的建议」入口（用户要求置顶；从雷达页签**移**来，不复制两份）：
  ///   观察模式产出的建议卡落库即死角 —— 主人看不到、也无从批准，体感就是"分身完全不动"。
  ///   现在它有了一个**固定能看到**的位置：流水页打开第一眼就是它。
  Widget _buildLedgerTab(ThemeProvider theme) {
    final l10n = AppLocalizations.of(context);
    final isDark = theme.isDark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: DBHelper.getPendingAgentActions(),
          builder: (ctx, snap) {
            final n = snap.data?.length ?? 0;
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AgentActionInboxScreen()),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.approval_outlined, size: 18),
                label: Text(n == 0
                    ? l10n.suggestionInboxTitle
                    : '${l10n.suggestionInboxTitle} ($n)'),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(l10n.socialLedgerTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 12),
        _socialLogs.isEmpty
            ? Center(child: Text(l10n.socialLedgerEmpty, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)))
            : ListView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _socialLogs.length,
                itemBuilder: (context, index) {
                  final log = _socialLogs[index];
                  if (log['action_type'] == 'send' || log['action_type'] == 'receive') return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white60, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_moon, size: 16, color: theme.accentColor), const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(log['description'], style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 4), Text(_formatTime(log['timestamp'] as int), style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38))])),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }
}
