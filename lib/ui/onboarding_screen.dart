import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/agent_identity.dart';
import '../core/agent_service.dart';
import '../core/backup_nudge_policy.dart';
import '../core/cloud_service.dart';
import '../core/db_helper.dart';
import '../core/language_controller.dart';
import '../core/mode_controller.dart';
import '../core/radar_service.dart';
import '../core/setup_service.dart';
import '../core/world_service.dart';
import '../core/trial_client.dart';
import '../core/theme_provider.dart';
import '../data/story_theater.dart';
import '../l10n/app_localizations.dart';
import 'identity_backup_flow.dart';
import 'open_external_link.dart';
import 'setup_result_text.dart';
import 'story_sprite.dart';

/// ============================================================
/// 三分钟接入向导（新手第一次打开 App 时出现）
///
/// 目标：让完全不懂技术的用户独立完成
///   ① 选择模型服务  → ② 填密钥并真实测通 → ③ 给智能体起名
///   → ④ **备份身份**（★ 不再是可选项，见下）→ ⑤（可选）连中转站 → ⑥ 开始使用
///
/// ### ★ 为什么"备份身份"必须是**必经步**而不是一个提示
///
/// 身份是**自证**的：私钥不在我们手里，所以**没有任何中心能替用户重发**。
/// 手机一坏、又没备份 —— 用户永久失去身份与全部履历，而**我们想帮也帮不上**。
/// 这是一个"事后无法补救"的坑，因此它必须在**用户第一次进来的路上**被拦住，
/// 而不是等他想起来去设置里找。
///
/// 但**不硬拦死**：底部给一条"暂不备份"，点它必须过一次**警告确认框**
/// （说清代价、要求显式确认）。理由是硬拦会逼出"随手抄一个假口令"的应付行为，
/// 那比诚实跳过更糟；而"强提示 + 显式跳过"能让这个决定**留下痕迹**。
/// ============================================================
class OnboardingScreen extends StatefulWidget {
  /// 全部完成后回调（由 main.dart 切换到主界面）
  final VoidCallback onFinished;

  const OnboardingScreen({Key? key, required this.onFinished}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// ★ 步骤号常量（0.55.0）：**第 0 步是语言选择**。
  ///
  /// 为什么语言必须在最前：引导页从第二步开始全是长文案（隐私明示、模型说明、
  /// 备份风险），用户读不懂的语言等于没写。先挑语言，后面每一步才是他能读懂的。
  ///
  /// 用常量而不是裸数字：插一步会平移后面所有分支，裸数字改一处漏一处。
  ///
  /// ★ 0.100.0（章回剧场移植，见《章回剧场移植首启引导-实现方案.md》§0/§3）：
  /// 语言步之后插入「序幕」步（蛋三态 + 起名 + 掷性格 + 撤回演示卡），
  /// 其后各步顺移、完成步 7 → 8。底栏分派链与 `_buildStepBody` switch 必须
  /// **同批**补 `_stepPrologue` 分支（反 0.62.0「漏分支 ⇒ 直接 _finish」同族
  /// bug），由 `tool/verify_story_prologue.dart` 钉住两处分派齐整。
  static const int _stepLanguage = 0;
  static const int _stepPrologue = 1;
  static const int _stepWelcome = 2;
  static const int _stepModel = 3;
  static const int _stepKey = 4;
  static const int _stepIdentity = 5;
  static const int _stepBackup = 6;
  static const int _stepSocial = 7;
  static const int _lastStep = 8; // 完成步

  int _step = 0;
  String _presetId = 'deepseek';

  /// 身份备份状态（决定备份步的呈现）。
  bool _backedUp = false;
  String _myAgentId = '';
  bool _backupBusy = false;

  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _masterNameController = TextEditingController(text: '主人');
  final _agentNameController = TextEditingController(text: '小荒');
  final _toneController = TextEditingController(text: '温暖、简洁、有主见');
  /// 中转站 / 世界服务器地址：**出厂即预填官方线上地址**（见 `SetupService`）。
  /// 用户若自建后端，进来时会被 `_loadEndpointsFromPrefs()` 覆盖成他自己的值 ——
  /// 否则"重跑引导"会把自建地址冲掉。
  final _hubUrlController =
      TextEditingController(text: SetupService.defaultHubUrl);
  final _worldUrlController =
      TextEditingController(text: SetupService.defaultWorldUrl);
  /// 中转站访问 Key（ADR-002 准入闸）：**留空 = 该中转站不要求准入**
  /// （自建 / 局域网形态）。官方站启用准入后才是必填。
  ///
  /// 存储键走 `CloudService.prefsHubAccessKey`（与「高级设置」页**同一个键**）——
  /// 两处若各写各的字面量，症状就是"引导里填了 Key、进阶页里是空的"。
  final _hubKeyController = TextEditingController();

  bool _obscureKey = true;
  bool _modelTesting = false;
  bool _hubTesting = false;
  bool _finishing = false;
  bool _enableCloud = false;

  /// ★ 0.62.0（问题⑥）：本轮引导是否走**免费体验**路径。
  ///
  /// 完成步（第 8 步）据此**分两种情形**呈现：体验用户看到「这是体验 / 经官方
  /// 中转 / 限 20 轮」，自有 Key 用户看到「某某模型已配置好」。此前完成步**不
  /// 分路径**，给没填 Key 的体验用户显示了 `DeepSeek（推荐·国内直连）`——那既
  /// 不真实，也误导他认为自己在直连官方模型。
  bool _trialMode = false;

  /// ★ 0.66.0（真机反馈）：「欢迎」步的两条路径改为**单选圆点**（原为两个胶囊按钮）。
  /// true = 免费体验（默认，主路径）；false = 自有 API Key。
  bool _welcomeTrial = true;

  /// ★ 0.100.0 序幕步：蛋是否已孵化。点蛋置位；**重跑引导且 `soul_agent_name`
  ///   有存档时由 `_loadSoulPrefs()` 直接置位**（不强制重温孵化，方案 §3）。
  bool _prologueHatched = false;

  /// ★ 0.100.0 序幕步：掷中的性格（null = 还没掷）。掷中只**预填**语气框，
  ///   身份步可改；`_finish()` 才是 prefs 写入方。
  StoryTrait? _rolledTrait;

  /// ★ 0.100.0 序幕步：撤回演示卡是否已演示完。演示前精灵呈 alert（它看见了
  ///   那条坏消息），划掉后回 hatched 微笑（移植方案 §6）。
  bool _undoDone = false;

  SetupTestResult? _modelResult;
  SetupTestResult? _hubResult;

  @override
  void initState() {
    super.initState();
    // 首帧之前不需要 setState，直接填充控制器即可
    _applyPreset(SetupService.presetById(_presetId), notify: false);
    _loadIdentityState();
    // ★ 若用户已配置过后端地址（含自建后端 / 主动清空），以他的值为准覆盖出厂默认，
    //   否则"重跑引导"会把自建地址静默冲成官方地址 —— 那是**弄丢用户配置**。
    _loadEndpointsFromPrefs();
    // ★ 0.62.0：把「是否曾选免费体验」读回来 —— 完成步要据此分情形呈现。
    _loadTrialMode();
    // ★ 0.100.0（修 F14）：把已保存的 soul_* 读回三个身份控制器 ——
    //   否则重跑引导的用户一进身份步看到默认名，直接点完 ⇒ _finish() 用默认值
    //   **静默覆盖**他已保存的名字/语气（与 0.62.0 修掉的地址冲掉同族）。
    _loadSoulPrefs();
  }

  /// 用已保存的中转站 / 世界服务器地址覆盖预填值。
  ///
  /// 判据（**与设置页共用同一份实现** `SetupService.resolveStoredOrDefault`）：
  ///   - 键不存在 → 用户从没设过 ⇒ 保留出厂的官方默认值；
  ///   - 键存在（哪怕是空串）→ 用户设过、或主动清空过 ⇒ 一律以他的为准。
  ///     "清空"是他显式做的决定（我不连云端），不能被默认值悄悄推翻。
  Future<void> _loadEndpointsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 已卸载就别再写控制器（写已 dispose 的控制器会触发断言）
    setState(() {
      _hubUrlController.text = SetupService.resolveStoredOrDefault(
        keyPresent: prefs.containsKey('cloud_hub_url'),
        stored: prefs.getString('cloud_hub_url'),
        fallback: SetupService.defaultHubUrl,
      );
      _worldUrlController.text = SetupService.resolveStoredOrDefault(
        keyPresent: prefs.containsKey('world_hub_url'),
        stored: prefs.getString('world_hub_url'),
        fallback: SetupService.defaultWorldUrl,
      );
      _hubKeyController.text =
          prefs.getString(CloudService.prefsHubAccessKey) ?? '';
    });
  }

  /// ★ 0.100.0（修 F14，移植取证新发现）：把已保存的 `soul_*` 读回三个身份控制器。
  ///
  /// 此前三控制器只有硬编码默认值（主人 / 小荒 / 温暖、简洁、有主见），
  /// `initState` 从不回填 ⇒ 重跑引导的用户看到默认名，直接点完 ⇒ `_finish()`
  /// 用默认值**静默覆盖**他已保存的自定义名字/语气。与 0.62.0 修掉的
  /// 「重跑引导把自建地址静默冲掉」同族（那次修的是地址，名字一直没修）。
  ///
  /// 判据与 `_loadEndpointsFromPrefs` 同款（共用 `SetupService.resolveStoredOrDefault`）：
  /// 键不存在 ⇒ 保留出厂默认；键存在（含空串）⇒ 以用户上次的值为准。
  /// 同时按「agent 名有存档」把序幕蛋置为**已孵化**（不强制重温）。
  Future<void> _loadSoulPrefs() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return; // 读不到 prefs 不拦引导
    }
    if (!mounted) return;
    setState(() {
      _masterNameController.text = SetupService.resolveStoredOrDefault(
        keyPresent: prefs.containsKey('soul_master_name'),
        stored: prefs.getString('soul_master_name'),
        fallback: '主人',
      );
      _agentNameController.text = SetupService.resolveStoredOrDefault(
        keyPresent: prefs.containsKey('soul_agent_name'),
        stored: prefs.getString('soul_agent_name'),
        fallback: '小荒',
      );
      _toneController.text = SetupService.resolveStoredOrDefault(
        keyPresent: prefs.containsKey('soul_tone'),
        stored: prefs.getString('soul_tone'),
        fallback: '温暖、简洁、有主见',
      );
      _prologueHatched = prefs.containsKey('soul_agent_name');
    });
  }

  /// ★ 0.62.0（问题⑥）：读回"是否曾选免费体验"（`llm_mode == trial`）。
  ///
  /// 首次安装该键不存在 ⇒ 默认自有路径。重跑引导的用户若上次选了体验，这一步
  /// 能把它认出来，完成步就不会错报成"自有模型已配置"。
  Future<void> _loadTrialMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isTrial = (prefs.getString(TrialClient.modeKey) ?? 'own') ==
          TrialClient.trialModeValue;
      if (mounted && isTrial) setState(() => _trialMode = true);
    } catch (_) {
      // 读不到 prefs 不影响引导：按自有路径呈现即可
    }
  }

  /// 读"我的身份 ID"与"当前钥是否已备份"。
  ///
  /// 注意：这里会顺带触发数据库首次打开与初始种子（`my_agent_id` 是在库初始化时
  /// 用 `ConflictAlgorithm.ignore` 写下的一次性随机 ID）。
  Future<void> _loadIdentityState() async {
    var id = '';
    var backed = false;
    try {
      id = await DBHelper.getAmbassador('my_agent_id') ?? '';
      backed = await AgentIdentity().isBackedUp();
    } catch (_) {
      // 身份还没就绪：备份步会显示为"未备份"，动作按钮会自己提示
    }
    if (!mounted) return;
    setState(() {
      _myAgentId = id;
      _backedUp = backed;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _masterNameController.dispose();
    _agentNameController.dispose();
    _toneController.dispose();
    _hubUrlController.dispose();
    _worldUrlController.dispose();
    _hubKeyController.dispose();
    super.dispose();
  }

  void _applyPreset(ModelPreset preset, {bool notify = true}) {
    _presetId = preset.id;
    if (preset.baseUrl.isNotEmpty) _baseUrlController.text = preset.baseUrl;
    if (preset.defaultModel.isNotEmpty) {
      _modelController.text = preset.defaultModel;
    }
    if (notify && mounted) {
      setState(() => _modelResult = null);
    } else {
      _modelResult = null;
    }
  }

  // ------------------------------------------------------------------
  // 操作
  // ------------------------------------------------------------------
  Future<void> _testModel() async {
    setState(() {
      _modelTesting = true;
      _modelResult = null;
    });
    final result = await SetupService.testModel(
      baseUrl: _baseUrlController.text,
      apiKey: _apiKeyController.text,
      model: _modelController.text,
    );
    if (!mounted) return;
    setState(() {
      _modelResult = result;
      _modelTesting = false;
    });
  }

  Future<void> _testHub() async {
    setState(() {
      _hubTesting = true;
      _hubResult = null;
    });
    final result = await SetupService.testHub(_hubUrlController.text);
    if (!mounted) return;
    setState(() {
      _hubResult = result;
      _hubTesting = false;
      if (result.ok) _enableCloud = true;
    });
  }

  void _next() {
    if (_step >= _lastStep) return;
    setState(() => _step++);
  }

  void _back() {
    if (_step <= 0) return;
    setState(() => _step--);
  }

  /// 模型没测通过时，友好地劝一次，而不是硬拦
  Future<void> _handleNextFromModelStep() async {
    if (_modelResult?.ok == true) {
      _next();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final goOn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.onboardingWarnNotTestedTitle),
        content: Text(l10n.onboardingWarnNotTestedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.onboardingGoBackTest),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.onboardingContinueAnyway),
          ),
        ],
      ),
    );
    if (goOn == true) _next();
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final masterName = _masterNameController.text.trim().isEmpty
          ? '主人'
          : _masterNameController.text.trim();
      final agentName = _agentNameController.text.trim().isEmpty
          ? '小荒'
          : _agentNameController.text.trim();
      final tone = _toneController.text.trim().isEmpty
          ? '温暖、简洁、有主见'
          : _toneController.text.trim();
      final hub = SetupService.normalizeBaseUrl(_hubUrlController.text);

      if (_trialMode) {
        // 试用模式：base_url/api_key/model_name 已在 _chooseTrial 落库。
        // 这三个键**不能**被控制器的默认值覆盖——覆盖一次，试用配置就静默
        // 变回 DeepSeek 直连 + 空 Key，分身当场失声。
      } else {
        // ★ 0.62.0：显式写回自有模式。否则"上次选过体验、这次改填自己的 Key"
        //   的重跑用户，llm_mode 仍停在 trial —— 这里会**跳过**下面的写入，
        //   旧体验配置被当成自有配置沿用（问题⑥的分支判据也因此失真）。
        await prefs.setString(TrialClient.modeKey, 'own');
        await prefs.setString(
            'base_url', SetupService.normalizeBaseUrl(_baseUrlController.text));
        await prefs.setString('api_key', _apiKeyController.text.trim());
        await prefs.setString('model_name', _modelController.text.trim());
      }
      await prefs.setString('soul_master_name', masterName);
      await prefs.setString('soul_agent_name', agentName);
      await prefs.setString('soul_tone', tone);
      if (hub.isNotEmpty) await prefs.setString('cloud_hub_url', hub);
      // 中转站访问 Key（ADR-002）。只在非空时写，与地址同口径：
      // "没填"不能被写成"填了空串"——那会让服务端把用户当成持空 Key 的人。
      final hubKey = _hubKeyController.text.trim();
      if (hubKey.isNotEmpty) {
        await prefs.setString(CloudService.prefsHubAccessKey, hubKey);
      }
      // 世界服务器地址（出厂已预填官方地址）。用户若清空则不写 —— 交由
      // world_service 的"Hub 地址 + /world"回落，与设置页语义一致。
      final world = SetupService.normalizeBaseUrl(_worldUrlController.text);
      if (world.isNotEmpty) await prefs.setString('world_hub_url', world);

      // 让社交名册里显示正确的名字（未设置过时才写入）
      final existingNick = await DBHelper.getAmbassador('nickname');
      if (existingNick == null || existingNick.trim().isEmpty) {
        await DBHelper.saveAmbassador('nickname', agentName);
      }
      final existingMask = await DBHelper.getAmbassador('mask_profile');
      if (existingMask == null || existingMask.trim().isEmpty) {
        await DBHelper.saveAmbassador('mask_profile', '刚来到大荒的新朋友');
      }

      await prefs.setBool('onboarding_done', true);
      // 首批用户方案 §四：完成引导即自动加入新手大厅（官方分身常驻）——
      // 新用户第一次打开世界页就能看见活跃对话。尽力而为：失败不拦引导。
      final lobbyId = await DBHelper.getAmbassador('my_agent_id');
      if (lobbyId != null && lobbyId.isNotEmpty) {
        WorldService()
            .joinRoom(lobbyId, 'lobby')
            .catchError((_) => false)
            .whenComplete(() {});
      }
      // 首批用户方案 §三：新装用户默认**入门模式**（社交页收起「托办」签；
      // 「日志」仍在——它是「待我确认的建议」唯一入口，不可收起）。
      // 老用户升级无此键 = 进阶模式。
      // ★ 0.61.0：写**单一事实源**，不再裸写 prefs —— 否则 ModeController 的内存态
      //   还是旧值，本轮引导结束进主界面就会显示错误的页签数。
      await ModeController.i.setSimpleMode(true);

      if (hub.isNotEmpty && _enableCloud) {
        try {
          // 开启云端通道时会顺带向中转站注册本机智能体（幂等）
          await RadarService.instance.setChannel('link_cloud_enabled', true);
        } catch (_) {
          // 中转站暂时不通不影响本地使用
        }
      }

      await AgentService().initAgent();
    } finally {
      if (mounted) {
        setState(() => _finishing = false);
        widget.onFinished();
      }
    }
  }

  // ------------------------------------------------------------------
  // 界面
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Container(
        decoration: theme.backgroundDecoration,
        child: SafeArea(
          child: Column(
            children: [
              _buildProgress(theme, isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _buildStepBody(theme, isDark),
                ),
              ),
              _buildBottomBar(theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.onboardingStepLanguage,
      l10n.onboardingStepPrologue,
      l10n.onboardingStepWelcome,
      l10n.onboardingStepModel,
      l10n.onboardingStepKey,
      l10n.onboardingStepIdentity,
      l10n.onboardingStepBackup,
      l10n.onboardingStepSocial,
      l10n.onboardingStepDone,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.onboardingStepIndicator(
                    _step + 1, _lastStep + 1, labels[_step]),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_step + 1) / (_lastStep + 1),
              minHeight: 6,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: _finishing ? null : _back,
              child: Text(l10n.onboardingPrevStep),
            ),
          const Spacer(),
          if (_step == _stepIdentity || _step == _stepSocial)
            TextButton(
              onPressed: _finishing ? null : _next,
              child: Text(l10n.commonSkip),
            ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _finishing
                ? null
                : () {
                    if (_step == _stepLanguage ||
                        _step == _stepPrologue ||
                        _step == _stepModel ||
                        _step == _stepIdentity) {
                      // ★ 0.62.0（复查发现）：「选模型」步（当时 3/8）此前**漏在分支外**，
                      //   底栏"下一步"直接落到 `else → _finish()` —— 自有 Key 路径
                      //   的用户在这里一点"下一步"，引导当场结束：跳过填 Key、设身份、
                      //   备份、社交四步，且 api_key 还是空串 ⇒ 分身失声。
                      //   补上 `_stepModel`，让它照常推进到「填密钥」步。
                      // ★ 0.100.0：插「序幕」步时同批补 `_stepPrologue` 分支
                      //   （反同族 bug：漏一个分支 ⇒ 该步用户被直接送进 _finish）。
                      _next();
                    } else if (_step == _stepWelcome) {
                      // ★ 0.66.0：欢迎步两条路径改为**单选圆点**（原为两条胶囊按钮）⇒
                      //   底栏「下一步」按**所选项**分派（`_welcomeTrial`，默认免费体验）。
                      //   ★ 必须保住 0.62.0 的语义：走自有路径时由 `_chooseOwnKey()`
                      //   **显式清掉体验标记**，否则 `_trialMode` 会停在真 ⇒ 完成步
                      //   错显体验卡，且 `_finish()` 走体验支 ⇒ **静默丢弃**用户刚填的
                      //   base_url/api_key/model_name。
                      if (_welcomeTrial) {
                        _chooseTrial();
                      } else {
                        _chooseOwnKey();
                      }
                    } else if (_step == _stepKey) {
                      _handleNextFromModelStep();
                    } else if (_step == _stepBackup) {
                      // ★ 备份步：未备份时主按钮本身就是"生成恢复码"
                      if (_backedUp) {
                        _next();
                      } else {
                        _doBackup();
                      }
                    } else if (_step == _stepSocial) {
                      _next();
                    } else {
                      _finish();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _finishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_step == _lastStep
                    ? l10n.onboardingStart
                    : (_step == _stepBackup && !_backedUp)
                        ? l10n.idbGenerateAction
                        : l10n.commonNext),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(ThemeProvider theme, bool isDark) {
    switch (_step) {
      case _stepLanguage:
        return _buildLanguage(theme, isDark);
      case _stepPrologue:
        return _buildPrologue(theme, isDark);
      case _stepWelcome:
        return _buildWelcome(theme, isDark);
      case _stepModel:
        return _buildChooseModel(theme, isDark);
      case _stepKey:
        return _buildEnterKey(theme, isDark);
      case _stepIdentity:
        return _buildIdentity(theme, isDark);
      case _stepBackup:
        return _buildBackup(theme, isDark);
      case _stepSocial:
        return _buildSocial(theme, isDark);
      default:
        return _buildDone(theme, isDark);
    }
  }

  // ---------- 第 5 步：备份身份（★ 必经，见类注释） ----------

  Future<void> _doBackup() async {
    if (_myAgentId.isEmpty) await _loadIdentityState();
    if (!mounted) return;
    setState(() => _backupBusy = true);
    try {
      final done = await runBackupFlow(context, agentId: _myAgentId);
      if (!mounted) return;
      if (done) setState(() => _backedUp = true);
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  /// 「免费体验」：零 Key 进入。试用配置在**此刻**落库（base_url 指向官方
  /// Hub 的代调端点，Bearer = 本机 agent_id），然后直跳备份步——
  /// 模型/Key/身份三步对试用用户全部省略（身份已由 WoldRuntime.init 签发）。
  Future<void> _chooseTrial() async {
    final prefs = await SharedPreferences.getInstance();
    final hub = SetupService.normalizeBaseUrl(_hubUrlController.text);
    final base = hub.isNotEmpty ? hub : SetupService.defaultHubUrl;
    final myId = await DBHelper.getAmbassador('my_agent_id') ?? '';
    // ★ 0.82.0：四件套（llm_mode / base_url / api_key / model_name）抽到
    //   `TrialClient.applyTrialConfig`，与设置页「恢复免费试用」**共用同一实现**。
    //   事故根因之一正是"写试用配置"只散落在引导页这一处 ⇒ 设置页另有一套
    //   无条件覆盖逻辑，主人一填自有 Key 就把试用身份打废（见 trial_client 注释）。
    await TrialClient.applyTrialConfig(prefs, hubUrl: base, agentId: myId);
    // ★ 0.62.0（问题⑥）：记住走的是体验路径 —— 完成步据此分情形呈现。
    if (mounted) setState(() => _trialMode = true);
    if (mounted) setState(() => _step = _stepBackup); // 直跳备份步
  }

  /// ★ 0.62.0（问题⑥）：走「我有自己的 API Key」路径（老路径原样 → 模型/Key 步）。
  ///
  /// 必须**显式清除体验标记**：重跑引导的用户若上次选了体验，`_loadTrialMode`
  /// 已把 `_trialMode` 置 true；本次改走自有路径，完成步就不能再显示体验卡片。
  void _chooseOwnKey() {
    if (_trialMode) setState(() => _trialMode = false);
    _next();
  }

  /// "暂不备份"：必须过一次显式警告确认（强提示，不静默跳过）。
  Future<void> _skipBackup() async {
    final go = await confirmSkipBackup(context);
    if (go && mounted) {
      // 用户刚看过警告并显式拒绝——补课屏（BackupNudgePolicy）3 天内
      // 不再追问，避免"引导里刚跳过、下次冷启动立刻又弹"的骚扰感。
      await BackupNudgePolicy.snooze(await SharedPreferences.getInstance());
      _next();
    }
  }

  Widget _buildBackup(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final ok = _backedUp;
    final color = ok ? Colors.green : Colors.redAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(l10n.onbBackupTitle, l10n.onbBackupSubtitle, isDark),
        // 先把**代价**说清楚，再谈按钮 —— 用户不知道手机丢了会丢身份，
        // 就会把这一步当成一个可以随手划掉的表单。
        _infoCard(
          icon: Icons.phonelink_erase,
          title: l10n.onbBackupWhyTitle,
          body: l10n.onbBackupWhy,
          theme: theme,
          isDark: isDark,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ok ? Icons.verified_user : Icons.warning_amber_rounded,
                color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ok ? l10n.onbBackupDone : l10n.idbStatusNotBackedUp,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (!ok)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _backupBusy ? null : _doBackup,
              icon: _backupBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.key_outlined),
              label: Text(l10n.idbGenerateAction),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: theme.accentColor),
                foregroundColor: theme.accentColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        const SizedBox(height: 6),
        if (!ok)
          Center(
            child: TextButton(
              onPressed: _finishing || _backupBusy ? null : _skipBackup,
              child: Text(l10n.onbSkipBackup,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45)),
            ),
          ),
      ],
    );
  }

  // ---------- 第 0 步：选择语言（0.55.0） ----------

  /// 为什么语言是第一步：后面每一步都是长文案（隐私明示 / 模型说明 / 备份风险），
  /// 用一门用户读不懂的语言写出来，等于没写。
  Widget _buildLanguage(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _stepTitle(l10n.onbLangTitle, l10n.onbLangSubtitle, isDark),
        const SizedBox(height: 20),
        // 「跟随系统」单独置顶：它是**解析策略**不是一门语言，
        // 混在语种列表里会让人以为是一门叫"跟随系统"的话。
        _langTile(
          code: LanguageController.followSystem,
          label: l10n.langFollowSystem,
          hint: l10n.langFollowSystemHint,
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        // 语种一律用**自称**（简体中文 / 繁體中文 / English / 日本語 / Tiếng Việt）：
        // 若按当前界面语言翻译，英文界面下的中文用户就找不到自己的语言了。
        for (final code in LanguageController.selectableCodes)
          if (code != LanguageController.followSystem)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _langTile(
                code: code,
                label: LanguageController.endonyms[code] ?? code,
                theme: theme,
                isDark: isDark,
              ),
            ),
        const SizedBox(height: 8),
        Text(
          l10n.onbLangChangeableHint,
          style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white60 : Colors.black54),
        ),
      ],
    );
  }

  Widget _langTile({
    required String code,
    required String label,
    String? hint,
    required ThemeProvider theme,
    required bool isDark,
  }) {
    final selected = LanguageController.i.code == code;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => unawaited(LanguageController.i.setCode(code)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? theme.accentColor.withOpacity(0.16)
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
          border: Border.all(
            color: selected
                ? theme.accentColor
                : (isDark ? Colors.white12 : Colors.black12),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected
                  ? theme.accentColor
                  : (isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: isDark ? Colors.white : Colors.black87),
              ),
            ),
            if (hint != null)
              Text(hint,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }

  // ---------- 第 1 步：欢迎 ----------
  Widget _buildWelcome(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          l10n.onboardingWelcomeHeading,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.onboardingWelcomeBody,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        // 铁律 1 的"产品级明示"：首启必须讲清"默认由分身出面"
        Text(
          l10n.onboardingDisclosureNote,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: theme.accentColor,
          ),
        ),
        const SizedBox(height: 24),
        // ★ 0.66.0（真机反馈）：三条提示**收进同一个框**（原为三张独立卡片，
        //   卡片之间留白把「三条并列的说明」切成了三块互相独立的观感 ⇒ 用户要求
        //   "放在一个文本框内"）。改为一张卡 + 细分隔线，语义仍是三条并列说明。
        Card(
          color: isDark ? Colors.black54 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _infoRow(
                  icon: Icons.lock_outline,
                  title: l10n.privacyDataLocalTitle,
                  body: l10n.privacyDataLocalBody,
                  theme: theme,
                  isDark: isDark,
                ),
                _cardDivider(isDark),
                _infoRow(
                  icon: Icons.people_outline,
                  title: l10n.onboardingSocialCardTitle,
                  body: l10n.onboardingSocialCardBody,
                  theme: theme,
                  isDark: isDark,
                ),
                _cardDivider(isDark),
                _infoRow(
                  icon: Icons.vpn_key_outlined,
                  title: l10n.onboardingModelCardTitle,
                  body: l10n.onboardingModelCardBody,
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // ★ 0.66.0（真机反馈）：两条路径改为**单选圆点 + 文字**——原为「实心胶囊 +
        //   描边胶囊」两个大圆角按钮，用户评价"两个圆弧形框很不协调" ⇒ 直接给
        //   「○ 免费体验（20 轮）」「○ 我有自己的 API Key」，圆点在前、选项在后，
        //   由底栏「下一步」按所选项推进（免费体验仍为默认主路径）。
        _choiceRow(
          selected: _welcomeTrial,
          onTap: () => setState(() => _welcomeTrial = true),
          label: l10n.onbFreeTrialBtn,
          theme: theme,
          isDark: isDark,
        ),
        _choiceRow(
          selected: !_welcomeTrial,
          onTap: () => setState(() => _welcomeTrial = false),
          label: l10n.onbOwnKeyBtn,
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.onboardingThreeThings,
          style: TextStyle(
              fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
        ),
      ],
    );
  }

  // ---------- 第 2 步：选模型 ----------
  Widget _buildChooseModel(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(l10n.onboardingPickModelTitle, l10n.onboardingPickModelSubtitle, isDark),
        const SizedBox(height: 8),
        ...SetupService.presets.map((p) {
          final selected = p.id == _presetId;
          return Card(
            color: selected
                ? theme.accentColor.withOpacity(0.12)
                : (isDark ? Colors.black54 : Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: selected
                    ? theme.accentColor
                    : (isDark ? Colors.white12 : Colors.black12),
                width: selected ? 1.6 : 1,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _applyPreset(p),
              leading: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? theme.accentColor : Colors.grey,
              ),
              title: Text(
                setupPresetText(p, l10n).label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                setupPresetText(p, l10n).note,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---------- 第 3 步：填密钥并测试 ----------
  Widget _buildEnterKey(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final preset = SetupService.presetById(_presetId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(l10n.onboardingPasteKeyTitle,
            setupPresetText(preset, l10n).keyHint, isDark),
        const SizedBox(height: 8),
        _field(
          label: l10n.onboardingFieldBaseUrl,
          controller: _baseUrlController,
          theme: theme,
          isDark: isDark,
          hint: l10n.onboardingHintBaseUrl,
        ),
        _field(
          label: l10n.onboardingFieldModelName,
          controller: _modelController,
          theme: theme,
          isDark: isDark,
          hint: l10n.onboardingHintModelName,
        ),
        _field(
          label: l10n.onboardingFieldApiKey,
          controller: _apiKeyController,
          theme: theme,
          isDark: isDark,
          hint: 'sk-...',
          obscure: _obscureKey,
          suffix: IconButton(
            icon: Icon(
              _obscureKey ? Icons.visibility_off : Icons.visibility,
              size: 20,
            ),
            onPressed: () => setState(() => _obscureKey = !_obscureKey),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _modelTesting ? null : _testModel,
            icon: _modelTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label:
                Text(_modelTesting ? l10n.onboardingTesting : l10n.onboardingTestConnection),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: theme.accentColor),
              foregroundColor: theme.accentColor,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_modelResult != null) _resultCard(_modelResult!, isDark),
      ],
    );
  }

  // ---------- 第 4 步：设定身份 ----------
  Widget _buildIdentity(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(l10n.onboardingNameStepTitle, l10n.onboardingNameStepSubtitle, isDark),
        const SizedBox(height: 8),
        _field(
          label: l10n.onboardingFieldMasterName,
          controller: _masterNameController,
          theme: theme,
          isDark: isDark,
          hint: l10n.onboardingHintMasterName,
        ),
        _field(
          label: l10n.onboardingFieldAgentName,
          controller: _agentNameController,
          theme: theme,
          isDark: isDark,
          hint: l10n.onboardingHintAgentName,
        ),
        _field(
          label: l10n.onboardingFieldTone,
          controller: _toneController,
          theme: theme,
          isDark: isDark,
          hint: l10n.onboardingHintTone,
        ),
      ],
    );
  }

  // ---------- 第 6 步：连社交（可跳过） ----------
  Widget _buildSocial(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          l10n.onboardingSocialStepTitle,
          l10n.onboardingSocialStepSubtitle,
          isDark,
        ),
        const SizedBox(height: 8),
        _field(
          label: l10n.onboardingFieldHubUrl,
          controller: _hubUrlController,
          theme: theme,
          isDark: isDark,
          hint: l10n.onboardingHintHubUrl,
        ),
        // ★ ADR-002 准入闸：官方中转站可要求"新身份须持访问 Key"。
        //   此前引导页对这个要求**只字未提** —— 用户按默认地址走完引导，
        //   服务器却回 registration_key_required，界面上的表现是"社交发不出去"，
        //   没有任何地方告诉他缺什么。所以这里必须显式摆出来（可留空）。
        //   obscure：它等价于凭据，别让人在咖啡厅里被隔壁看到。
        _field(
          label: l10n.onboardingFieldHubKey,
          controller: _hubKeyController,
          theme: theme,
          isDark: isDark,
          hint: l10n.onboardingHintHubKey,
          obscure: true,
        ),
        // 申请入口：**只有运营方配了真实渠道才出现**（hubKeyApplyUrl 非空）。
        // 空串时刻意不渲染 —— 不放占位假链接（见 SetupService.hubKeyApplyUrl）。
        if (SetupService.hubKeyApplyUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openExternalLink(
                  context,
                  SetupService.hubKeyApplyUrl,
                  failureText: l10n.settingsHubKeyApplyFailed,
                ),
                icon: Icon(Icons.open_in_new, size: 16, color: theme.accentColor),
                label: Text(
                  l10n.settingsHubKeyApply,
                  style: TextStyle(color: theme.accentColor, fontSize: 13),
                ),
              ),
            ),
          ),
        // ★ 世界服务器是与中转站**不同的域名**（独立的 `world.wold.world`）。
        //   若不单独填，`world_service` 会回落成"Hub 地址 + /world" —— 而线上 Hub
        //   **没有** /world 这条路由（实查 2026-10-02：`https://hub.wold.world/world`
        //   与 `/world/health` **均 404**）。即：不预填 = 让用户默默拿到一个连不上的地址。
        //   所以官方世界地址必须**显式摆出来并预填**，不能靠猜。
        _field(
          label: l10n.onboardingFieldWorldUrl,
          controller: _worldUrlController,
          theme: theme,
          isDark: isDark,
          hint: l10n.onboardingHintWorldUrl,
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _hubTesting ? null : _testHub,
            icon: _hubTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
            label: Text(_hubTesting ? l10n.onboardingConnecting : l10n.onboardingTestAndConnect),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: theme.accentColor),
              foregroundColor: theme.accentColor,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_hubResult != null) _resultCard(_hubResult!, isDark),
      ],
    );
  }

  // ---------- 序幕：章回剧场「小荒出世」（0.100.0 移植，方案 §4） ----------
  //
  // 移植范围（方案 §0）：蛋三态 + 起名 + 掷性格 + 撤回演示卡 + 诚信免责；
  // 中间五回与六城 reel **不移植**（首启要短，那些能力在 App 内是真实入口）。
  // ★ 只预填、不直写：本步不碰 prefs，`_finish()` 仍是 `soul_*` 唯一写入方。
  // ★ 命名语义（方案 §5）：蛋的名字 = **智能体名**（不是主人名）；掷性格 =
  //   语气**建议**（预填 `_toneController`，身份步可改）。
  Widget _buildPrologue(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          l10n.storyPrologueTitle,
          l10n.storyPrologueSubtitle,
          isDark,
        ),
        Center(
          child: StorySprite(
            state: _prologueSpriteState,
            onTap: _hatchEgg,
          ),
        ),
        const SizedBox(height: 16),
        if (!_prologueHatched)
          Text(l10n.storyEggHint, style: _prologueLineStyle(isDark))
        else ...[
          Text(l10n.storyAwakenLine1, style: _prologueLineStyle(isDark)),
          Text(l10n.storyAwakenLine2, style: _prologueLineStyle(isDark)),
          const SizedBox(height: 16),
          // 起名：第三句台词「先给我起个名字。」就是输入框的标签；
          // 控制器直接接 `_agentNameController`（蛋名 = 智能体名）。
          _field(
            label: l10n.storyAwakenLine3,
            controller: _agentNameController,
            theme: theme,
            isDark: isDark,
            hint: l10n.storyNamePlaceholder,
            suffix: IconButton(
              tooltip: l10n.storyDiceLabel,
              onPressed: _rollTrait,
              icon: Icon(Icons.casino_outlined, color: theme.accentColor),
            ),
          ),
          // 骰子结果：没掷过是占位提示；掷中了是语气建议（已预填语气框）。
          Text(
            _rolledTrait == null
                ? l10n.storyTraitPlaceholder
                : _traitText(l10n, _rolledTrait!),
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight:
                  _rolledTrait == null ? FontWeight.normal : FontWeight.bold,
              color: _rolledTrait == null
                  ? (isDark ? Colors.white38 : Colors.black38)
                  : theme.accentColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 14),
            child: Text(
              l10n.storyDiceNote,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          _buildUndoDemoCard(theme, isDark),
          const SizedBox(height: 12),
          // 诚信免责（R27：对外主张必须可证实）：常驻小字讲清这是情景演绎。
          Text(
            l10n.storyDisclaimer,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ],
    );
  }

  TextStyle _prologueLineStyle(bool isDark) => TextStyle(
        fontSize: 14.5,
        height: 1.8,
        color: isDark ? Colors.white70 : Colors.black54,
      );

  /// 序幕精灵三态：未孵化 = 蛋；演示前 = alert（它看见了那条坏消息）；
  /// 撤回后 = hatched 微笑（移植方案 §6）。
  StorySpriteState get _prologueSpriteState {
    if (!_prologueHatched) return StorySpriteState.egg;
    return _undoDone ? StorySpriteState.hatched : StorySpriteState.alert;
  }

  /// 性格 → 语气描述词（ARB `storyTrait1..5`，顺序承 story.json awaken.traits）。
  String _traitText(AppLocalizations l10n, StoryTrait trait) {
    switch (trait) {
      case StoryTrait.curious:
        return l10n.storyTrait1;
      case StoryTrait.chatty:
        return l10n.storyTrait2;
      case StoryTrait.cautious:
        return l10n.storyTrait3;
      case StoryTrait.warm:
        return l10n.storyTrait4;
      case StoryTrait.slowToTrust:
        return l10n.storyTrait5;
    }
  }

  /// 掷性格：结构层纯函数 `rollTraitIndex`（单测覆盖边界与全覆盖），
  /// 掷中后**只预填**语气框 —— 不写 prefs。
  void _rollTrait() {
    final trait = storyTraits[rollTraitIndex(Random().nextDouble())];
    setState(() {
      _rolledTrait = trait;
      _toneController.text = _traitText(AppLocalizations.of(context), trait);
    });
  }

  /// 撤回演示卡（官网 auditable 章 → 序幕步内第二张卡）。
  ///
  /// ★ 纯 UI 剧场：不写 DB、不写审计、不调任何服务 —— 卡上带「演示」标，
  ///   坏消息行可点、划掉后浮出审计回执，精灵回微笑（移植方案 §7 保全措施 10）。
  Widget _buildUndoDemoCard(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: isDark ? Colors.black54 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 18, color: theme.accentColor),
                const SizedBox(width: 8),
                Text(
                  l10n.storyUndoTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                // 「演示」标：这张卡里没有一条真消息（诚信边界，必须显形）。
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.accentColor),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.storyDemoTag,
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                      color: theme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.storyUndoHint,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            _undoDemoLine(l10n.storyUndoLine1, isDark: isDark, bad: false),
            const SizedBox(height: 8),
            _undoDemoLine(l10n.storyUndoBad, isDark: isDark, bad: true),
            if (_undoDone) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.undo, size: 16, color: theme.accentColor),
                  const SizedBox(width: 6),
                  Text(
                    l10n.storyUndoConfirm,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.storyUndoNote,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 演示卡里的一行台词。坏消息行在撤回前可点（InkWell），撤回后划掉。
  Widget _undoDemoLine(String text, {required bool isDark, required bool bad}) {
    final struck = bad && _undoDone;
    final row = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          decoration: struck ? TextDecoration.lineThrough : null,
          color: struck
              ? (isDark ? Colors.white38 : Colors.black38)
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
    if (!bad || _undoDone) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _crossOutBadLine,
      child: row,
    );
  }

  /// 点坏消息行：划掉 + 浮出审计回执 + 精灵回微笑（只改内存态）。
  void _crossOutBadLine() {
    if (_undoDone) return;
    setState(() => _undoDone = true);
  }

  /// 点蛋：孵化（只改内存态，不写 prefs —— 写入方只有 `_finish()`）。
  void _hatchEgg() {
    if (_prologueHatched) return;
    setState(() => _prologueHatched = true);
  }

  // ---------- 完成 ----------
  Widget _buildDone(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final preset = SetupService.presetById(_presetId);
    final hubReady = _hubResult?.ok == true && _enableCloud;
    final hub = SetupService.normalizeBaseUrl(_hubUrlController.text);
    final ownModel = _modelController.text.trim();
    // 「自有 Key 已就绪」= 未走体验路径，且模型名与 Key 都填了。
    final ownReady = !_trialMode &&
        ownModel.isNotEmpty &&
        _apiKeyController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // ★ 0.100.0（章回剧场移植，方案 §4）：完成步头图 check_circle →
        //   hatched 精灵 + 一句归巢文案（终章 explore 的最小落点）。
        Center(
          child: StorySprite(state: StorySpriteState.hatched, size: 116),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            l10n.storyFinaleTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.storyFinaleBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.onboardingDoneHeading,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),

        // ★ 0.62.0（问题⑥）：完成步**分两种情形**——
        //   ① 免费体验：先讲清"这是体验、经官方服务器代调、限 20 轮"，并给出
        //      升级入口（中转站地址随 {hub} 注入）；
        //   ② 自有 Key：先确认"某某模型已配置好"，再列出模型参数。
        //   此前不分路径，给**没填 Key 的体验用户**显示了
        //   `DeepSeek（推荐·国内直连）`/`deepseek-v4-flash` —— 既不真实，也误导
        //   他以为自己直连了官方模型（用户截图反馈"明显不合适"）。
        if (_trialMode) ...[
          _infoCard(
            icon: Icons.rocket_launch_outlined,
            title: l10n.onboardingTrialNoticeTitle,
            body: l10n.onboardingTrialNoticeBody(hub),
            theme: theme,
            isDark: isDark,
          ),
          _summaryRow(
              l10n.onboardingSummaryModel, l10n.onboardingTrialService, isDark),
          _summaryRow(l10n.onboardingFieldModelName,
              l10n.onboardingTrialModelName, isDark),
        ] else ...[
          // 自有 Key：就绪时给"某某模型已配置好"的确认；未就绪（缺模型/Key）
          // 则如实显示"未填写"，不谎报就绪。
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.accentColor.withValues(alpha: 0.45)),
            ),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.verified_outlined,
                  color: theme.accentColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ownReady
                      ? l10n.onboardingOwnReady(ownModel)
                      : l10n.onboardingNotFilled,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _summaryRow(l10n.onboardingSummaryModel,
              setupPresetText(preset, l10n).label, isDark),
          _summaryRow(l10n.onboardingFieldModelName,
              ownModel.isEmpty ? l10n.onboardingNotFilled : ownModel, isDark),
        ],

        _summaryRow(
            l10n.onboardingSummaryAgentName,
            _agentNameController.text.trim().isEmpty
                ? '小荒'
                : _agentNameController.text.trim(),
            isDark),
        _summaryRow(
          l10n.onboardingSummaryCloud,
          hubReady ? l10n.onboardingCloudOn : l10n.onboardingCloudOff,
          isDark,
        ),
        const SizedBox(height: 18),
        Text(
          l10n.onboardingNextWhere,
          style: TextStyle(
            fontSize: 13,
            height: 1.7,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 小组件
  // ------------------------------------------------------------------
  Widget _stepTitle(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
    required ThemeProvider theme,
    required bool isDark,
  }) {
    return Card(
      color: isDark ? Colors.black54 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.accentColor.withOpacity(0.15),
              child: Icon(icon, color: theme.accentColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ★ 0.66.0：「欢迎」步「一个框内三条提示」的单行（无卡片外壳，供分组复用）。
  /// 与 `_infoCard` 的差别只在**没有 Card 外壳与卡片间距** —— 三条并列说明放进
  /// 同一张卡里，靠 `_cardDivider` 分隔。
  Widget _infoRow({
    required IconData icon,
    required String title,
    required String body,
    required ThemeProvider theme,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.accentColor.withOpacity(0.15),
            child: Icon(icon, color: theme.accentColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ★ 0.66.0：三条提示之间的细分隔线。
  Widget _cardDivider(bool isDark) => Divider(
        height: 1,
        thickness: 0.6,
        color: isDark ? Colors.white12 : Colors.black12,
      );

  /// ★ 0.66.0（真机反馈）：**单选圆点 + 文字**，替代原「实心/描边胶囊按钮」两条
  /// （用户：两个大圆角框很不协调）。圆点在前、选项文案在后，整行可点。
  Widget _choiceRow({
    required bool selected,
    required VoidCallback onTap,
    required String label,
    required ThemeProvider theme,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: selected
                  ? theme.accentColor
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required ThemeProvider theme,
    required bool isDark,
    String hint = '',
    bool obscure = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              suffixIcon: suffix,
              filled: true,
              fillColor: isDark ? Colors.grey[850] : Colors.grey[200],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.accentColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(SetupTestResult result, bool isDark) {
    // ★ 0.110.0：文案在**渲染时**按当前语言解析（setup_result_text）。
    //   引导页第 1 步可切语言，早先测完的结果卡必须跟着变语言。
    final l10n = AppLocalizations.of(context);
    final text = setupResultText(result, l10n);
    final color = result.ok ? Colors.green : Colors.redAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(result.ok ? Icons.check_circle : Icons.error_outline,
                  color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text.message,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          if (text.suggestion != null) ...[
            const SizedBox(height: 8),
            Text(
              '👉 ${text.suggestion}',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
