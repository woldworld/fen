import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 引入系统级操作(退出App)
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background/flutter_background.dart'; // 🚀 引入后台服务
import 'package:wakelock_plus/wakelock_plus.dart';           // 🚀 引入休眠锁

import '../core/theme_provider.dart';
import '../core/mode_controller.dart';
import '../core/dream_service.dart'; 
import '../core/agent_service.dart'; 
import '../core/p2p_service.dart';   // 🚀 引入底层硬件服务
import '../core/lan_service.dart';   // 🚀 引入底层硬件服务
import '../l10n/app_localizations.dart';
import 'topic_list_screen.dart'; 
import 'device_control_screen.dart';
import 'notification_sms_screen.dart';
import 'weekly_report_screen.dart';
import '../core/voice_service.dart';
import '../core/calendar_service.dart';
import '../core/notification_service.dart';
import '../core/morning_digest_service.dart';
import 'tool_list_screen.dart';
import 'skill_market_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';
import 'help_dot.dart';

class ManageScreen extends StatefulWidget {
  @override
  _ManageScreenState createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  bool _isDreaming = false;

  // 🚀 触发造梦引擎
  Future<void> _triggerEvolution() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isDreaming = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.manageDreamSleeping), duration: const Duration(seconds: 3)),
    );

    final success = await DreamService().triggerNightlyReflection();
    
    if (success) {
      // 记忆进化成功后，必须重启主大脑，让它加载全新的 Agent.md 档案！
      await AgentService().initAgent(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageDreamAwake), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageDreamFailed), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isDreaming = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    // 订阅模式：切换时本页重建 —— 自我进化 / 技能库 / 技能市场随档位增减。
    final mode = Provider.of<ModeController>(context);
    
    return Container(
      color: Colors.transparent, 
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          
          // 🚀 自我进化（0.61.0：**仅进阶模式**显示 —— 属调参层，入门模式收起）。
          if (!mode.simpleMode)
          // 🚀 全新加入：记忆进化引擎控制台（神经网络大脑净化控制台）
          Card(
            color: isDark ? Colors.black87 : Colors.white.withOpacity(0.95),
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.accentColor.withOpacity(0.5), width: 1)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: theme.accentColor, size: 24),
                      const SizedBox(width: 12),
                      Text(l10n.manageSelfEvolutionTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.manageSelfEvolutionBody,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  
                  // 🚀 新增：拟物化大脑进化参数面板（核心亮点）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMetricItem(l10n.manageMetricDepth, "98.7%", theme, isDark),
                      _buildMetricItem(l10n.manageMetricSkillsLabel, l10n.manageMetricSkillsValue(4), theme, isDark),
                      _buildMetricItem(l10n.manageMetricSessionsLabel, l10n.manageMetricSessionsValue(12), theme, isDark),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isDreaming 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.bedtime, color: Colors.white),
                      label: Text(_isDreaming ? l10n.manageDreaming : l10n.manageTriggerEvolution, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isDreaming ? null : _triggerEvolution,
                    ),
                  )
                ],
              ),
            ),
          ),

          // 模块：历史记录
          _buildActionCard(
            title: l10n.manageHistoryTitle,
            subtitle: l10n.manageHistorySubtitle,
            icon: Icons.history_edu,
            theme: theme,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TopicListScreen()));
            },
          ),
          
          // 模块：技能库 + 技能市场（0.61.0：**仅进阶模式**显示 ——
          // 属“自造技能 / 交易”层，入门用户先把基本盘跑通即可）。
          if (!mode.simpleMode) ...[
          // 模块：技能库
          _buildActionCard(
            title: l10n.manageToolsTitle,
            subtitle: l10n.manageToolsSubtitle,
            icon: Icons.construction,
            theme: theme,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ToolListScreen()));
            },
          ),

          // 模块：技能市场（M9：签名上架 + 作者分成）
          _buildActionCard(
            title: l10n.skillMarketTitle,
            subtitle: l10n.skillMarketSubtitle,
            icon: Icons.storefront,
            theme: theme,
            onTap: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SkillMarketScreen()));
            },
          ),
          ],

          // ===== 系统与能力（0.120.0 从控制中心迁入；0.121.0 按 ADR-005 拆粒度）=====
          // 迁出 != 消失：tool/verify_settings_split.dart 的 D2 段逐 token 钉住
          // 「初级页不留 + 本页必须收」。
          // ★ 0.121.0：整块**常显**（此前整块仅进阶 ⇒ 入门用户连"通知权限"
          //   和"日历只读授权"都点不到，等于被系统门永久拦在外面）。
          //   门控下沉到区块内部，只包「调参组」；「授权组」两卡常显。
          _buildSystemCapabilitySection(theme, isDark, l10n, mode),

          // 模块：举报中心（0.115.0：客户端内举报入口 —— 《服务条款》§6 承诺的落地）
          _buildActionCard(
            title: l10n.reportCenterTitle,
            subtitle: l10n.reportCenterSubtitle,
            icon: Icons.flag_outlined,
            theme: theme,
            onTap: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ReportScreen()));
            },
          ),

          // 模块：绝密档案
          _buildActionCard(
            title: l10n.manageProfileTitle,
            subtitle: l10n.manageProfileSubtitle,
            icon: Icons.admin_panel_settings,
            theme: theme,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
            },
          ),
          
          const SizedBox(height: 24),
          const Divider(color: Colors.grey, height: 1),
          const SizedBox(height: 16),

          // 🚀 新增：系统级安全停机与清零重启机制
          Card(
            color: Colors.redAccent.withOpacity(0.1),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.redAccent, width: 1)
            ),
            child: InkWell(
              onTap: () => _performEmergencyShutdown(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      radius: 22,
                      child: Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.manageShutdownTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          const SizedBox(height: 4),
                          Text(l10n.manageShutdownSubtitle, style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 新增的核心清零退出方法
  Future<void> _performEmergencyShutdown(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    // 弹窗确认
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.manageShutdownDialogTitle),
        content: Text(l10n.manageShutdownDialogBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(l10n.manageForceQuit, style: const TextStyle(color: Colors.white))
          ),
        ],
      )
    );

    if (confirm != true) return;

    try {
      // 1. 强行终止并清空所有物理扫描与网络服务
      await P2PService().stopPatrolling();
      await LanService().stopLanEngine();
      
      // 2. 清零底层巡逻状态，防止下次启动时复现异常死锁
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('agent_is_patrolling', false);
      await prefs.setInt('radar_end_time', 0);
      await prefs.setBool('link_near_field_enabled', false);
      await prefs.setBool('link_lan_enabled', false);
      await prefs.setBool('link_cloud_enabled', false);

      // 3. 强行释放 CPU 休眠锁与 Android 前台保活通知
      WakelockPlus.disable();
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (e) {
      print("强制释放资源时遇阻 (通常可忽略): $e");
    } finally {
      // 4. 发出系统级信号，优雅退出 App
      SystemNavigator.pop();
    }
  }

  Widget _buildActionCard({
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required ThemeProvider theme,
    required VoidCallback onTap,
    }) {
    final isDark = theme.isDark;
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withOpacity(0.8),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.accentColor.withOpacity(0.15),
                radius: 22,
                child: Icon(icon, color: theme.accentColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildMetricItem(String label, String value, ThemeProvider theme, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.accentColor, fontFamily: 'Courier')),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold)),
      ],
    );
  }
  /// 「系统与能力」区块（0.120.0 从控制中心迁入；0.121.0 按 ADR-005 拆门控粒度）。
  ///
  /// 六项分两组：
  ///   · **授权组（任何模式都渲染）**：通知设置（含通知权限授予）/ 系统日历
  ///     （含只读授权）—— 这两张卡是系统权限弹窗的**唯一** UI 通路，
  ///     被模式门控挡住 = 主人**无法完成授权**（ADR-005 §3-3）。
  ///   · **调参组（仅进阶展开）**：手机控制 / 通知与短信 / 语音播报 / 智能体周报。
  Widget _buildSystemCapabilitySection(ThemeProvider theme, bool isDark,
      AppLocalizations l10n, ModeController mode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          child: Row(children: [
            Icon(Icons.tune, size: 18, color: theme.accentColor),
            const SizedBox(width: 8),
            Text(l10n.manageSystemCapabilityTitle,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 16, 12),
          // 两套口径：入门模式要回答「其余在哪」，进阶模式要回答「这就是全部」。
          child: Text(
              mode.simpleMode
                  ? l10n.manageSystemCapabilityHintSimple
                  : l10n.manageSystemCapabilityHint,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54)),
        ),
        // ★ 授权组：**门控之外**，任何模式都渲染（ADR-005 §2.3-1）。
        _buildAuthorizationCards(),
        // ★ 门控只包「调参组」四项 —— 位置由 tool/verify_mode_visibility.dart
        //   ⑦ 的区间判定 + 两条负控反向钉住（R50：计数会被"数字对但位置错"糊弄）。
        if (!mode.simpleMode) ...[
          _buildAdvancedCapabilityItems(theme, l10n),
        ],
      ],
    );
  }

  /// 授权组：**任何模式都渲染**（ADR-005 §2.3-1 / §3-3）。
  ///
  /// 通知权限（`requestPermissions`）与日历只读授权（`requestRead`）的 UI 入口
  /// 全仓**只**在这里各一处 —— 谁把这两张卡挪进门控，谁就让入门用户永远无法授权。
  Widget _buildAuthorizationCards() {
    return Column(
      children: [
        const _NotifySettingsCard(),
        const SizedBox(height: 12),
        const _CalendarSettingsCard(),
      ],
    );
  }

  /// 调参组：仅进阶模式展开（两张能力入口卡 + 语音播报 + 智能体周报）。
  Widget _buildAdvancedCapabilityItems(
      ThemeProvider theme, AppLocalizations l10n) {
    return Column(
      children: [
        for (final e in _systemCapabilityItems)
          _buildActionCard(
            title: e.title(l10n),
            subtitle: e.subtitle(l10n),
            icon: e.icon,
            theme: theme,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: e.builder),
            ),
          ),
        const SizedBox(height: 12),
        const _TtsSettingsCard(),
        const SizedBox(height: 12),
        const _WeeklyReportCard(),
      ],
    );
  }
}

/// 「系统与能力」条目（0.120.0）。
///
/// 标题/副标题用**函数**而不是字符串键：l10n 是强类型 getter，
/// 存字符串键没法动态取（「认不出就显形」纪律的延伸）。
class _SystemCapabilityEntry {
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) subtitle;
  final IconData icon;
  final WidgetBuilder builder;
  const _SystemCapabilityEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

final List<_SystemCapabilityEntry> _systemCapabilityItems =
    <_SystemCapabilityEntry>[
  _SystemCapabilityEntry(
    title: (l) => l.settingsDeviceControlTitle,
    subtitle: (l) => l.settingsDeviceControlSubtitle,
    icon: Icons.phone_android,
    builder: (_) => const DeviceControlScreen(),
  ),
  _SystemCapabilityEntry(
    title: (l) => l.settingsNotifySmsTitle,
    subtitle: (l) => l.settingsNotifySmsSubtitle,
    icon: Icons.notifications_active_outlined,
    builder: (_) => const NotificationSmsScreen(),
  ),
];

/// 「语音播报」设置卡（0.72.0 W3）。
///
/// 与通知卡同一纪律：**写穿生效**——拨一下立刻落库生效，不等页面底部
/// 那次「保存并重铸灵魂」。默认**关**（不打扰原则：把回复念出声是
/// 「系统主动出声」，默认做就是打扰）；打开后聊天页回复会朗读，
/// 输入行出现「停止」按钮，随时可打断。
class _TtsSettingsCard extends StatefulWidget {
  const _TtsSettingsCard();

  @override
  State<_TtsSettingsCard> createState() => _TtsSettingsCardState();
}

class _TtsSettingsCardState extends State<_TtsSettingsCard> {
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await TtsService.i.currentEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = v;
      _loading = false;
    });
  }

  Future<void> _toggle(bool v) async {
    await TtsService.i.setEnabled(v); // 唯一写入方；关 = 立刻停当前朗读
    if (!mounted) return;
    setState(() => _enabled = v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              secondary: Icon(Icons.volume_up_outlined, color: theme.accentColor),
              title: Text(l10n.settingsTtsEnabled,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              subtitle: Text(l10n.settingsTtsHint,
                  style: const TextStyle(fontSize: 12)),
              value: _enabled,
              onChanged: _toggle,
            ),
    );
  }
}

/// 「系统通知」设置卡（0.48.0）。
////// 独立成组件而不是并进 `_SettingsScreenState`，是为了让通知偏好**写穿生效**：
/// 拨一下开关就立刻落库并让内核重读，不必等页面底部那次"保存配置并重铸灵魂"
/// 的重量级重初始化。把「静音」这种即时诉求绑在一次灵魂重铸上，是反直觉的。
class _NotifySettingsCard extends StatefulWidget {
  const _NotifySettingsCard();

  @override
  State<_NotifySettingsCard> createState() => _NotifySettingsCardState();
}

class _NotifySettingsCardState extends State<_NotifySettingsCard> {
  NotificationSettings _s = NotificationSettings.defaults;
  bool _granted = true;
  bool _loading = true;
  // ★ 0.68.0：晨间问候时间。此前 `morning_hour` 在 `MorningDigestService` 里
  //   **只有读取方、全项目无人写** ⇒ 该设置永远等于默认值 7 点（用户改不了，
  //   也不知道自己改不了）。这里补上**唯一的写入方**。
  int _morningHour = MorningDigestService.defaultMorningHour;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await NotificationSettings.load();
    var granted = true;
    try {
      granted = await NotificationService.i.permissionGranted;
    } catch (_) {
      // 拿不到就按"已授权"显示，不挂假警告（与设置页其它红标同款纪律）
    }
    final prefs = await SharedPreferences.getInstance();
    final morningHour = prefs.getInt(MorningDigestService.morningHourKey) ??
        MorningDigestService.defaultMorningHour;
    if (!mounted) return;
    setState(() {
      _s = s;
      _granted = granted;
      _morningHour = morningHour;
      _loading = false;
    });
  }

  /// 改晨间问候时间：落库 → 刷新本卡（与 `_apply` 同一纪律，不留下"改了没生效")。
  Future<void> _setMorningHour(int hour) async {
    await MorningDigestService.i.setMorningHour(hour);
    if (!mounted) return;
    setState(() => _morningHour = hour);
  }

  /// 写穿：落库 → 内核重读 → 刷新本卡。三步都在同一次点击里做完。
  Future<void> _apply(NotificationSettings next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationKeys.enabled, next.enabled);
    await prefs.setBool(NotificationKeys.quietEnabled, next.quietEnabled);
    await prefs.setInt(NotificationKeys.quietStartHour, next.quietStartHour);
    await prefs.setInt(NotificationKeys.quietEndHour, next.quietEndHour);
    await NotificationService.i.refreshSettings();
    if (!mounted) return;
    setState(() => _s = next);
  }

  Future<void> _grant() async {
    final ok = await NotificationService.i.requestPermission();
    if (!mounted) return;
    setState(() => _granted = ok);
    if (!ok) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsNotifyPermissionNeeded)),
      );
    }
  }

  String _windowLabel() {
    String two(int h) => h.toString().padLeft(2, '0');
    return '${two(_s.quietStartHour)}:00 – ${two(_s.quietEndHour)}:00';
  }

  Widget _hourField(
    String label,
    int value,
    ValueChanged<int> onChanged,
    ThemeProvider theme,
    bool isDark,
  ) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      dropdownColor: isDark ? Colors.black87 : Colors.white,
      items: [
        for (var h = 0; h < 24; h++)
          DropdownMenuItem<int>(
            value: h,
            child: Text('${h.toString().padLeft(2, '0')}:00'),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;

    final cardColor =
        isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );

    if (_loading) {
      return Card(
        color: cardColor,
        shape: shape,
        elevation: 4,
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return Card(
      color: cardColor,
      shape: shape,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: theme.accentColor, size: 28),
                const SizedBox(width: 10),
                Flexible(
                  child: HelpTitle(
                    text: l10n.settingsNotifySection,
                    topic: HelpTopic.notifyGuide,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
              ],
            ),
            // 权限没给 ⇒ 通知根本画不出来。这是**静默失败**，属于必须常驻示警的
            // 三类文字之一（另两类：红线警示、数据边界告示）。
            if (!_granted)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange),
                title: Text(
                  l10n.settingsNotifyPermissionNeeded,
                  style: const TextStyle(fontSize: 13),
                ),
                onTap: _grant,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsNotifyEnabled),
              value: _s.enabled,
              activeThumbColor: theme.accentColor,
              onChanged: (v) => _apply(_s.copyWith(enabled: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsNotifyQuiet),
              subtitle: Text(_windowLabel()),
              value: _s.quietEnabled,
              activeThumbColor: theme.accentColor,
              // 总开关关掉时，子开关没有意义 ⇒ 置灰
              onChanged: _s.enabled
                  ? (v) => _apply(_s.copyWith(quietEnabled: v))
                  : null,
            ),
            if (_s.enabled && _s.quietEnabled)
              Row(
                children: [
                  Expanded(
                    child: _hourField(
                      l10n.settingsNotifyQuietStart,
                      _s.quietStartHour,
                      (h) => _apply(_s.copyWith(quietStartHour: h)),
                      theme,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _hourField(
                      l10n.settingsNotifyQuietEnd,
                      _s.quietEndHour,
                      (h) => _apply(_s.copyWith(quietEndHour: h)),
                      theme,
                      isDark,
                    ),
                  ),
                ],
              ),
            // ★ 0.68.0：晨间问候时间（`morning_hour` 的**唯一写入方**）。
            //   总开关关掉时它没有意义 ⇒ 一并隐藏，与免打扰子开关同款纪律。
            if (_s.enabled)
              _hourField(
                l10n.settingsMorningHour,
                _morningHour,
                _setMorningHour,
                theme,
                isDark,
              ),
          ],
        ),
      ),
    );
  }
}

/// 「智能体周报」入口卡（0.74.0 W5/S7）。
///
/// 只是入口——真正的聚合与呈现都在 `WeeklyReportScreen`（纯本地统计、
/// 数据不出本机）。
class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Icon(Icons.insights, color: theme.accentColor),
        title: Text(l10n.settingsWeeklyReportTitle,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(l10n.settingsWeeklyReportHint,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WeeklyReportScreen())),
      ),
    );
  }
}

/// 「系统日历（只读）」设置卡（0.74.0 W5/S6）。
///
/// 显示三态（不支持 / 已授权 / 未授权）并提供授权入口。授权后晨间问候
/// 会带上「今天日程」。★ 只申请 READ_CALENDAR（只读），对日历零写入。
class _CalendarSettingsCard extends StatefulWidget {
  const _CalendarSettingsCard();

  @override
  State<_CalendarSettingsCard> createState() => _CalendarSettingsCardState();
}

class _CalendarSettingsCardState extends State<_CalendarSettingsCard> {
  CalendarStatus _status = const CalendarStatus.unavailable();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await CalendarService.i.status();
    if (!mounted) return;
    setState(() {
      _status = st;
      _loading = false;
    });
  }

  Future<void> _grant() async {
    final ok = await CalendarService.i.requestPermission();
    if (!mounted) return;
    setState(() => _status = CalendarStatus(supported: true, granted: ok));
    if (!ok) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.calendarPermissionNeeded)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9);
    final titleColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    final String statusText;
    if (!_status.supported) {
      statusText = l10n.settingsCalendarUnsupported;
    } else if (_status.granted) {
      statusText = l10n.settingsCalendarGranted;
    } else {
      statusText = l10n.settingsCalendarDenied;
    }

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(children: [
                    Icon(Icons.calendar_month,
                        color: theme.accentColor, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.settingsCalendarTitle,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: titleColor)),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: Text(l10n.settingsCalendarHint,
                      style: TextStyle(fontSize: 12, color: subColor)),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(
                    _status.granted
                        ? Icons.check_circle_outline
                        : Icons.lock_outline,
                    color: _status.granted ? Colors.green : theme.accentColor,
                  ),
                  title:
                      Text(statusText, style: const TextStyle(fontSize: 14)),
                  trailing: (!_status.supported || _status.granted)
                      ? null
                      : TextButton(
                          onPressed: _grant,
                          child: Text(l10n.settingsCalendarGrant)),
                ),
              ],
            ),
    );
  }
}
