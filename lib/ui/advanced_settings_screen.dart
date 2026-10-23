import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../core/agent_service.dart';
import '../core/cloud_service.dart';
import '../core/db_helper.dart';
import '../core/local_model_service.dart';
import '../core/search/search_tools.dart';
import '../core/setup_service.dart';
import '../core/trial_client.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'help_dot.dart';
import 'memory_manager_screen.dart';
import 'profile_cards_screen.dart';
import 'diagnostics_screen.dart';
import 'onboarding_screen.dart';
import 'open_external_link.dart';

/// 「进阶设置」页（0.83.0）—— 引擎 / 记忆 / 灵魂 / 系统自检。
///
/// ---------------------------------------------------------------------------
/// 为什么要独立成页（主人反馈：「设置中心页长长的一大页，足以吓退初级用户」）
/// ---------------------------------------------------------------------------
/// 此前设置中心是**一张长列表**：外观 + 安全 + 灵魂 + 记忆 + 引擎 + 自检 + 术语 +
/// 周报 + 法务 + 通知 + 语音 + 日历 + 保存。其中「引擎」一块就有 10 个输入框
/// （接口地址 / 模型名 / API Key / 三个 Hub 地址 / 本地模型两项 / 搜索三项），
/// 初级用户一进来先撞见一堆他这辈子都不会碰的旋钮。
///
/// 分层口径（与 `ModeController` 的入门 / 进阶同一把尺，**不新增第二套模式**）：
///   · 初级页（`SettingsScreen`）= 天天会碰的：外观、安全、邮箱开关、通知、
///     语音、日历、周报、法务；
///   · 进阶页（本页）= 只有"我要自己调"的人才会进：引擎、记忆、灵魂、自检。
///   · **入口只在进阶模式下出现**（`SettingsScreen` 里那个「进阶模式」开关，
///     复用的就是 `ModeController`，单一事实源）。
///
/// ★ 保存口径：本页**自带**「保存并重铸灵魂」，与初级页的保存按钮**各写各的
///   一组键、互不重叠**（详见 `_saveSettings` 注释）。两边都调 `initAgent()`，
///   因为改任何配置都得让智能体按新配置重铸。
class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _hubUrlController = TextEditingController();
  /// 中转站访问 Key（ADR-002）。**留空 = 该中转站不需要**（自建 / 局域网形态）。
  ///
  /// 为什么放在"进阶设置"而不是引导流程：自建站一步都不该多问；只有官方站的新用户
  /// 才会遇到 `registration_key_required`，那时他自己会找到这里。
  final _hubAccessKeyController = TextEditingController();
  final _worldUrlController = TextEditingController();
  final _godUrlController = TextEditingController();
  final _localModelUrlController = TextEditingController();
  final _localModelNameController = TextEditingController();
  String _searchProvider = '';
  final _searchApiKeyController = TextEditingController();
  final _searchSearxngUrlController = TextEditingController();

  final _agentNameController = TextEditingController();
  final _masterNameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _toneController = TextEditingController();
  final _extraDescController = TextEditingController();

  final _maxRoundsController = TextEditingController();
  final _timeLimitController = TextEditingController();
  final _autoAllowController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _localModelTesting = false;
  LocalModelTestResult? _localModelTestResult;

  /// 当前是否**免费试用**模式（`llm_mode == trial`）。试用下「接口地址 / API Key /
  /// 模型名」三格由系统托管 ⇒ 只读（改它只会把试用打废，见 `_trialManagedNotice`）。
  bool _isTrial = false;
  int? _trialRemaining;

  /// 自动回忆（键不存在 = 默认开）
  bool _recallEnabled = true;
  /// 长期画像注入的**二级 gate**（键不存在 = 默认开）
  bool _profileEnabled = true;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _hubUrlController.dispose();
    _hubAccessKeyController.dispose();
    _worldUrlController.dispose();
    _godUrlController.dispose();
    _localModelUrlController.dispose();
    _localModelNameController.dispose();
    _searchApiKeyController.dispose();
    _searchSearxngUrlController.dispose();
    _agentNameController.dispose();
    _masterNameController.dispose();
    _relationshipController.dispose();
    _toneController.dispose();
    _extraDescController.dispose();
    _maxRoundsController.dispose();
    _timeLimitController.dispose();
    _autoAllowController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _baseUrlController.text = prefs.getString('base_url') ?? 'https://api.deepseek.com';
      _apiKeyController.text = prefs.getString('api_key') ?? '';
      _modelController.text = prefs.getString('model_name') ?? 'deepseek-v4-flash';
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
      _godUrlController.text = prefs.getString('god_hub_url') ?? '';
      _hubAccessKeyController.text =
          prefs.getString(CloudService.prefsHubAccessKey) ?? '';
      _localModelUrlController.text = SetupService.resolveStoredOrDefault(
        keyPresent: prefs.containsKey('local_model_base_url'),
        stored: prefs.getString('local_model_base_url'),
        fallback: LocalModelService.defaultBaseUrl,
      );
      _localModelNameController.text = () {
        final v = (prefs.getString('local_model_name') ?? '').trim();
        return v.isEmpty ? LocalModelService.defaultModel : v;
      }();
      _searchProvider = prefs.getString(kSearchProviderKey) ?? '';
      _searchApiKeyController.text = prefs.getString(kSearchApiKeyKey) ?? '';
      _searchSearxngUrlController.text = prefs.getString(kSearchSearxngUrlKey) ?? '';

      _agentNameController.text = prefs.getString('soul_agent_name') ?? '超级管家';
      _masterNameController.text = prefs.getString('soul_master_name') ?? '主人';
      _relationshipController.text =
          prefs.getString('soul_relationship') ?? '绝对忠诚的 AI 助理';
      _toneController.text = prefs.getString('soul_tone') ?? '专业热情';
      _extraDescController.text = prefs.getString('soul_extra_desc') ?? '';

      _maxRoundsController.text = (prefs.getInt('context_max_rounds') ?? 50).toString();
      _timeLimitController.text = (prefs.getInt('context_time_limit') ?? 24).toString();
      _autoAllowController.text =
          (prefs.getStringList('tool_auto_allow') ?? const []).join(',');
      _recallEnabled = prefs.getBool('recall_enabled') ?? true;
      _profileEnabled = prefs.getBool('profile_enabled') ?? true;

      if (prefs.getString(TrialClient.modeKey) == TrialClient.trialModeValue) {
        _isTrial = true;
        TrialClient.fetchRemainingTurns(prefs).then((n) {
          if (mounted) setState(() => _trialRemaining = n);
        });
      } else {
        _isTrial = false;
      }
      _isLoading = false;
    });
  }

  /// 本地模型连通性自检（**可配 ≠ 可用**）：填了地址不算数，要有一次真实探活。
  Future<void> _testLocalModel() async {
    if (_localModelTesting) return;
    setState(() {
      _localModelTesting = true;
      _localModelTestResult = null;
    });
    final r = await LocalModelService.testConnection(
      baseUrl: _localModelUrlController.text,
      model: _localModelNameController.text,
    );
    if (!mounted) return;
    setState(() {
      _localModelTesting = false;
      _localModelTestResult = r;
    });
  }

  Widget _buildLocalModelTest(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final r = _localModelTestResult;
    String? line;
    var lineColor = isDark ? Colors.white60 : Colors.black54;
    if (r != null) {
      if (r.ok) {
        line = l10n.settingsLocalModelTestOk(r.model, r.baseUrl);
        lineColor = const Color(0xFF2E7D32); // 绿：这次真的通了
      } else {
        final reason = r.reason ?? '';
        line = switch (reason) {
          'disabled' => l10n.settingsLocalModelTestDisabled,
          'unreachable' => l10n.settingsLocalModelTestUnreachable(r.baseUrl),
          'not_json' => l10n.settingsLocalModelTestNotJson,
          'no_message' => l10n.settingsLocalModelTestNoMessage,
          _ => l10n.settingsLocalModelTestHttp(reason.replaceFirst('http_', '')),
        };
        lineColor = Colors.orangeAccent;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(l10n.settingsLocalModelSection,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87)),
            ),
            const SizedBox(width: 6),
            // 「?」解释"可配 ≠ 可用"：地址填得对不代表那儿真有服务在听
            const HelpDot(topic: HelpTopic.settingsLocalModel),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _localModelTesting ? null : _testLocalModel,
            icon: _localModelTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.network_check, size: 18),
            label: Text(_localModelTesting
                ? l10n.settingsLocalModelTesting
                : l10n.settingsLocalModelTest),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.accentColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (line != null) ...[
          const SizedBox(height: 8),
          Text(line, style: TextStyle(fontSize: 12, color: lineColor)),
        ],
      ],
    );
  }

  /// 试用模式下的**托管说明块**（一次说清：托管 / 改了会自动切自有 / 改坏可一键恢复）。
  Widget _trialManagedNotice(
      ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.accentColor.withOpacity(isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.accentColor.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.hourglass_bottom, size: 18, color: theme.accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.trialManagedTitle,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(l10n.trialManagedNotice,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _restoreTrial,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(l10n.trialRestoreAction,
                  style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.accentColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 一键**恢复免费试用**配置（把"被改坏的试用凭证"修回正轨）。
  Future<void> _restoreTrial() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trialRestoreAction),
        content: Text(l10n.trialRestoreConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonOk)),
        ],
      ),
    );
    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    final rawHub = SetupService.normalizeBaseUrl(_hubUrlController.text);
    final hub = rawHub.isNotEmpty ? rawHub : SetupService.defaultHubUrl;
    final agentId = await DBHelper.getAmbassador('my_agent_id') ?? '';
    await TrialClient.applyTrialConfig(prefs, hubUrl: hub, agentId: agentId);
    await AgentService().initAgent();

    if (!mounted) return;
    setState(() {
      _baseUrlController.text = TrialClient.trialApiBase(hub);
      _apiKeyController.text = agentId.trim().isEmpty ? 'AG-TRIAL' : agentId;
      _modelController.text = TrialClient.trialModelName;
      _isTrial = true;
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.trialRestoreDone)));
  }

  Widget _buildTextField(String label, TextEditingController controller,
      ThemeProvider theme,
      {bool obscure = false,
      int lines = 1,
      String hint = "",
      TextInputType type = TextInputType.text,
      VoidCallback? onChanged,
      bool enabled = true}) {
    final isDark = theme.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            maxLines: lines,
            keyboardType: type,
            enabled: enabled,
            onChanged: onChanged == null ? null : (_) => onChanged(),
            style: TextStyle(
                color: enabled
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white38 : Colors.black45),
                fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              filled: true,
              fillColor: enabled
                  ? (isDark ? Colors.grey[800] : Colors.grey[200])
                  : (isDark ? Colors.grey[850] : Colors.grey[300]),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: _inputBorder(isDark),
              enabledBorder: _inputBorder(isDark),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: theme.accentColor.withOpacity(0.35), width: 1.0)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.accentColor, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _inputBorder(bool isDark) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: isDark
            ? BorderSide.none
            : const BorderSide(color: Colors.black12, width: 1.0),
      );

  /// 保存**本页这一组**键。
  ///
  /// ★★ 与初级页（`SettingsScreen._saveSettings`）**键集互不重叠** ——
  ///   本页写 引擎 / 灵魂 / 记忆 / 搜索 / 工具放行；初级页写 观察模式 / 模式档位。
  ///   两边都不许越界写对方的键：一组键两个写入方 = 迟早出现"改了没生效"。
  ///   （工具守卫 `tool/verify_settings_split.dart` 逐键钉死这个划分。）
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();

    // ★★ 0.82.0：**先看模式再写值**（真机事故：试用主人改了自己的 Key，
    //   模式却仍是 trial ⇒ 401 ⇒ 死循环）。三件事一起做：
    //     ① 试用下**不写空值**（清空 ≠ 改配置）；
    //     ② 主人真改了自己的 Key ⇒ **自动切成自有模式**并纠正端点；
    //     ③ 结果**可见**（SnackBar 说明切了什么、端点被改成什么）。
    final modeBefore = prefs.getString(TrialClient.modeKey);
    final keyBefore = prefs.getString(TrialClient.apiKeyKey) ?? '';
    final wasTrial = modeBefore == TrialClient.trialModeValue;
    final newBase = _baseUrlController.text.trim();
    final newKey = _apiKeyController.text.trim();

    final keepTrialBase = wasTrial && newBase.isEmpty;
    final keepTrialKey = wasTrial && newKey.isEmpty;
    if (!keepTrialBase) await prefs.setString(TrialClient.baseUrlKey, newBase);
    if (!keepTrialKey) await prefs.setString(TrialClient.apiKeyKey, newKey);
    await prefs.setString(TrialClient.modelNameKey, _modelController.text.trim());

    final switchToOwn = TrialClient.shouldSwitchToOwn(
      currentMode: modeBefore,
      previousKey: keyBefore,
      newKey: newKey,
    );
    String? ownedBase;
    if (switchToOwn) {
      await prefs.setString(TrialClient.modeKey, 'own');
      ownedBase = TrialClient.ownBaseUrlFix(newBase);
      if (ownedBase != null) {
        await prefs.setString(TrialClient.baseUrlKey, ownedBase);
        _baseUrlController.text = ownedBase;
      }
    }

    // 准入自检要用"改之前"的值 ⇒ 必须在写盘之前取出来。
    final hubBeforeAdmission = (prefs.getString('cloud_hub_url') ?? '').trim();
    final accessKeyBeforeAdmission =
        (prefs.getString(CloudService.prefsHubAccessKey) ?? '').trim();
    final hubAfterAdmission = _hubUrlController.text.trim();
    final accessKeyAfterAdmission = _hubAccessKeyController.text.trim();

    await prefs.setString('cloud_hub_url', hubAfterAdmission);
    await prefs.setString(
        CloudService.prefsHubAccessKey, accessKeyAfterAdmission);
    await prefs.setString('world_hub_url', _worldUrlController.text.trim());
    await prefs.setString('god_hub_url', _godUrlController.text.trim());
    await prefs.setString(
        'local_model_base_url', _localModelUrlController.text.trim());
    await prefs.setString(
        'local_model_name', _localModelNameController.text.trim());

    await prefs.setString(kSearchProviderKey, _searchProvider.trim());
    await prefs.setString(kSearchApiKeyKey, _searchApiKeyController.text.trim());
    await prefs.setString(
        kSearchSearxngUrlKey, _searchSearxngUrlController.text.trim());

    await prefs.setString('soul_agent_name', _agentNameController.text.trim());
    await prefs.setString('soul_master_name', _masterNameController.text.trim());
    await prefs.setString(
        'soul_relationship', _relationshipController.text.trim());
    await prefs.setString('soul_tone', _toneController.text.trim());
    await prefs.setString('soul_extra_desc', _extraDescController.text.trim());

    await prefs.setInt('context_max_rounds',
        int.tryParse(_maxRoundsController.text.trim()) ?? 50);
    await prefs.setInt('context_time_limit',
        int.tryParse(_timeLimitController.text.trim()) ?? 24);
    await prefs.setStringList(
      'tool_auto_allow',
      _autoAllowController.text
          .split(RegExp(r'[,，]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );

    await AgentService().initAgent();

    // ---------- 准入自检（ADR-002） ----------
    //
    // 只在"中转站地址或访问 Key 变了"时跑一次注册探测 —— 这是**唯一**能当场告诉
    // 用户"你填的 Key 不对"的时机。错过了，他只会在几小时后发现"社交发不出去"，
    // 而注册失败在 `radar_service` 里是 fire-and-forget，界面上一点痕迹都没有。
    //
    // ★ 只对**准入类**失败拦人：网络不通 / 中转站临时故障不拦（否则改个设置还得
    //   等对方服务器活着），那种情况按老路径静默重试即可。
    if ((hubAfterAdmission != hubBeforeAdmission ||
            accessKeyAfterAdmission != accessKeyBeforeAdmission) &&
        hubAfterAdmission.isNotEmpty) {
      final myAgentId = await DBHelper.getAmbassador('my_agent_id') ?? '';
      if (myAgentId.isNotEmpty) {
        final registered = await CloudService().registerAgent(
          myAgentId,
          await DBHelper.getAmbassador('nickname') ?? '',
          await DBHelper.getAmbassador('mask_profile') ?? '',
        );
        if (!registered && CloudService().lastRegisterWasAdmissionRejection) {
          final msg = CloudService().lastRegisterErrorText;
          if (!mounted) return;
          setState(() => _isSaving = false);
          // ★ 留在本页，不要"提示一下就退出"：退出后用户多半找不回这一页，
          //   于是同一条错误会在下一次心跳里再静默失败一遍。
          final l10nNow = AppLocalizations.of(context);
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10nNow.settingsHubKey),
              content: Text(msg ?? l10nNow.cloudKeyInvalid),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10nNow.commonOk),
                ),
                // 被闸挡下时顺手给申请入口：只摆在**这条**错误上，
                // 网络不通 / 中转站故障不摆（那些不是缺 Key）。
                if (SetupService.hubKeyApplyUrl.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      openExternalLink(
                        context,
                        SetupService.hubKeyApplyUrl,
                        failureText: l10nNow.settingsHubKeyApplyFailed,
                      );
                    },
                    child: Text(l10nNow.settingsHubKeyApply),
                  ),
              ],
            ),
          );
          return;
        }
      }
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switchToOwn
          ? l10n.settingsTrialSwitchedToOwn(ownedBase ?? newBase)
          : l10n.settingsSaved),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    final cardColor = isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9);
    final titleColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(l10n.settingsAdvancedTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.accentColor))
          : Container(
              decoration: theme.backgroundDecoration,
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // -------------------------------------------------- 灵魂
                    Card(
                      color: cardColor,
                      shape: shape,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.face_retouching_natural,
                                  color: theme.accentColor, size: 28),
                              const SizedBox(width: 10),
                              Text(l10n.settingsSecSoul,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor)),
                            ]),
                            const SizedBox(height: 20),
                            _buildTextField(
                                l10n.settingsAgentName, _agentNameController, theme),
                            _buildTextField(
                                l10n.settingsMasterName, _masterNameController, theme),
                            _buildTextField(l10n.settingsRelationship,
                                _relationshipController, theme),
                            _buildTextField(l10n.settingsTone, _toneController, theme),
                            _buildTextField(l10n.settingsExtraDesc,
                                _extraDescController, theme,
                                lines: 3),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------- 记忆
                    Card(
                      color: cardColor,
                      shape: shape,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.sd_storage,
                                  color: theme.accentColor, size: 28),
                              const SizedBox(width: 10),
                              Text(l10n.settingsSecMemory,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor)),
                            ]),
                            const SizedBox(height: 20),
                            _buildTextField(l10n.settingsMaxRounds,
                                _maxRoundsController, theme,
                                type: TextInputType.number,
                                hint: l10n.settingsMaxRoundsHint),
                            _buildTextField(l10n.settingsTimeLimit,
                                _timeLimitController, theme,
                                type: TextInputType.number,
                                hint: l10n.settingsTimeLimitHint),
                            // 自动回忆：**写穿生效**（拨一下立刻落库，不等保存）
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _recallEnabled,
                              onChanged: (v) async {
                                setState(() => _recallEnabled = v);
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool('recall_enabled', v);
                              },
                              title: Row(children: [
                                Flexible(
                                  child: Text(l10n.settingsRecallEnabled,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87)),
                                ),
                                const SizedBox(width: 4),
                                const HelpDot(topic: HelpTopic.settingsRecall),
                              ]),
                            ),
                            // 长期画像：**二级 gate** —— 回忆关 ⇒ 本项置灰不可点
                            // （否则就是骗主人："我关了画像"其实早就没喂了）。
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _recallEnabled ? _profileEnabled : false,
                              onChanged: _recallEnabled
                                  ? (v) async {
                                      setState(() => _profileEnabled = v);
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setBool('profile_enabled', v);
                                    }
                                  : null,
                              title: Text(l10n.settingsProfileEnabled,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87)),
                            ),
                            // 画像卡（0.106.0）：主人查看 / 修改 / 删除系统整理出的
                            // 长期画像（职业 / 偏好 / 目标 / 习惯 / 约束）。
                            //
                            // ⚠️ 刻意**不受**上面那个画像开关约束 —— 开关只决定
                            //   "这份画像要不要注入给模型"，而"看和改"是主人的**异议权**，
                            //   不该因为关掉注入就消失（关掉了反而更该能看：那是他决定
                            //   不再共享的东西，更要知道里面存了什么）。
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.badge_outlined,
                                  color: theme.accentColor),
                              title: Text(l10n.profileCardsTitle,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87)),
                              trailing: const Icon(Icons.chevron_right, size: 20),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ProfileCardsScreen()),
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.manage_history,
                                  color: theme.accentColor),
                              title: Text(l10n.settingsMemoryManager,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87)),
                              trailing: const Icon(Icons.chevron_right, size: 20),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const MemoryManagerScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------- 引擎
                    Card(
                      color: cardColor,
                      shape: shape,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.memory,
                                  color: theme.accentColor, size: 28),
                              const SizedBox(width: 10),
                              Text(l10n.settingsSecEngine,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor)),
                            ]),
                            const SizedBox(height: 20),
                            if (_isTrial) _trialManagedNotice(theme, isDark, l10n),
                            _buildTextField(
                                l10n.settingsBaseUrl, _baseUrlController, theme),
                            // 试用下模型由服务端池账号决定 ⇒ 只读，免得白折腾
                            _buildTextField(l10n.settingsModelName,
                                _modelController, theme,
                                enabled: !_isTrial),
                            if (_trialRemaining != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.hourglass_bottom,
                                    color: theme.accentColor),
                                title: Text(
                                    l10n.trialRemainingTurns(_trialRemaining!),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(l10n.trialExhaustedReply,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            _buildTextField(l10n.settingsApiKey,
                                _apiKeyController, theme,
                                obscure: true),
                            _buildTextField(l10n.settingsHubUrl,
                                _hubUrlController, theme,
                                hint: l10n.settingsHubUrlHint),
                            // ADR-002：官方中转站要 Key，自建留空即可。
                            // obscure：它等价于凭据，别让人在咖啡厅里被隔壁看到。
                            _buildTextField(l10n.settingsHubKey,
                                _hubAccessKeyController, theme,
                                obscure: true,
                                hint: l10n.settingsHubKeyHint),
                            // ★ ADR-002：被准入闸挡下的用户唯一出路是"去哪申请 Key"。
                            //   只有运营方配了真实渠道才渲染（hubKeyApplyUrl 非空）——
                            //   空串时刻意不显示，绝不放占位假链接。
                            if (SetupService.hubKeyApplyUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => openExternalLink(
                                      context,
                                      SetupService.hubKeyApplyUrl,
                                      failureText:
                                          l10n.settingsHubKeyApplyFailed,
                                    ),
                                    icon: Icon(Icons.open_in_new,
                                        size: 16, color: theme.accentColor),
                                    label: Text(
                                      l10n.settingsHubKeyApply,
                                      style: TextStyle(
                                          color: theme.accentColor,
                                          fontSize: 13),
                                    ),
                                  ),
                                ),
                              ),
                            _buildTextField(l10n.settingsWorldUrl,
                                _worldUrlController, theme,
                                hint: l10n.settingsWorldUrlHint),
                            _buildTextField(l10n.settingsGodUrl,
                                _godUrlController, theme,
                                hint: l10n.settingsGodUrlHint),
                            _buildTextField(l10n.settingsLocalModelUrl,
                                _localModelUrlController, theme,
                                hint: l10n.settingsLocalModelUrlHint,
                                onChanged: () =>
                                    setState(() => _localModelTestResult = null)),
                            _buildTextField(l10n.settingsLocalModelName,
                                _localModelNameController, theme,
                                hint: l10n.settingsLocalModelNameHint,
                                onChanged: () =>
                                    setState(() => _localModelTestResult = null)),
                            _buildLocalModelTest(theme, isDark),
                            const SizedBox(height: 20),
                            Row(children: [
                              Icon(Icons.travel_explore,
                                  color: theme.accentColor, size: 22),
                              const SizedBox(width: 8),
                              Text(l10n.settingsSearchTitle,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor)),
                            ]),
                            const SizedBox(height: 8),
                            Text(l10n.settingsSearchHint,
                                style: TextStyle(fontSize: 12, color: subColor)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _searchProvider,
                              decoration: InputDecoration(
                                labelText: l10n.settingsSearchProvider,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              items: [
                                DropdownMenuItem(
                                    value: '',
                                    child: Text(l10n.settingsSearchBasicMode)),
                                const DropdownMenuItem(
                                    value: 'tavily', child: Text('Tavily')),
                                const DropdownMenuItem(
                                    value: 'searxng', child: Text('SearXNG')),
                                const DropdownMenuItem(
                                    value: 'bing', child: Text('Bing')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _searchProvider = v ?? ''),
                            ),
                            if (_searchProvider == 'tavily' ||
                                _searchProvider == 'bing')
                              _buildTextField(l10n.settingsSearchApiKey,
                                  _searchApiKeyController, theme,
                                  obscure: true),
                            if (_searchProvider == 'searxng')
                              _buildTextField(l10n.settingsSearchSearxngUrl,
                                  _searchSearxngUrlController, theme,
                                  hint: l10n.settingsSearchSearxngUrlHint),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------- 工具自动放行
                    Card(
                      color: cardColor,
                      shape: shape,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.gpp_good_outlined,
                                  color: theme.accentColor, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(l10n.settingsSecSafety,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor)),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            _buildTextField(l10n.settingsAutoAllowLabel,
                                _autoAllowController, theme,
                                hint: l10n.settingsAutoAllowHint),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------- 自检
                    Card(
                      color: cardColor,
                      shape: shape,
                      elevation: 4,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        leading: Icon(Icons.health_and_safety_outlined,
                            color: theme.accentColor),
                        title: Text(l10n.settingsDiagnosticsTitle,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87)),
                        subtitle: Text(l10n.settingsDiagnosticsSubtitle,
                            style: TextStyle(fontSize: 12, color: subColor)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DiagnosticsScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OnboardingScreen(
                                onFinished: () => Navigator.pop(context),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: Text(l10n.settingsRerunOnboarding),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 8),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(l10n.settingsSaveButton,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
