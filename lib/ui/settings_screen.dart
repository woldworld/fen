import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; 
import '../core/agent_identity.dart';
import '../core/agent_service.dart';
import '../core/mail/mail_switch.dart';
import '../core/mail/mail_store_db.dart';
import '../core/mode_controller.dart';
import '../core/setup_service.dart';
import '../core/theme_provider.dart';
import '../core/update_check_service.dart';
import '../l10n/app_localizations.dart';
import 'glossary_screen.dart';
import 'identity_backup_screen.dart';
import 'mail_account_screen.dart';
import 'advanced_settings_screen.dart';
import 'open_external_link.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _observationMode = true;

  /// ★ 0.83.0：邮箱能力总开关（**默认关**，键不存在 = 关）。
  ///
  /// 之前邮箱唯一的门是"有没有绑账号" ⇒ 绑了号就无条件注册五个工具，
  /// 界面上还没有任何一处能关掉（"能开不能关"，隐私审计 P0-1）。
  bool _mailEnabled = false;
  /// 已绑定邮箱账号数（`null` = 还没读到）。用于"开了却没绑号"的显形提示。
  int? _mailAccountCount;

  /// 当前这把钥是否已备份 —— "安全"区里的常驻红标。
  ///
  /// 为什么必须常驻在这里：备份是**可选动作**，用户不主动做就永远不做；
  /// 而"手机丢了才发现没备份"已经来不及。红标是他每次进设置都会撞见的提醒。
  bool _backedUp = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _observationMode = prefs.getBool('agent_observation_mode') ?? true;
      // ★ 0.83.0：邮箱总开关（默认关 = 键不存在）
      _mailEnabled = MailSwitch.resolve(prefs.getBool(MailSwitch.mailEnabledPrefKey));
      _isLoading = false;
    });
    // 身份备份状态（决定"安全"区里的红标）—— 读不到就当已备份，不挂假警告。
    var backed = true;
    try {
      backed = await AgentIdentity().isBackedUp();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _backedUp = backed);
    // 邮箱账号数：开了总开关却没绑号 ⇒ 得在卡片里说出来（不给假状态）。
    try {
      final accs = await MailStoreDb.accounts();
      if (!mounted) return;
      setState(() => _mailAccountCount = accs.length);
    } catch (_) {
      // 读不到就不显示那条提示 —— 拿不到事实时不猜。
    }
  }

  /// ★ 0.120.0：观察模式改为**写穿生效**。
  ///
  /// 控制中心瘦身后，本页只剩这一个需要"保存"的开关 —— 底部那颗
  /// 「保存并重铸灵魂」大按钮随之退役（一个开关不配一颗大按钮）。
  /// 拨一下立刻落库 + 立刻让智能体按新配置重铸，不等保存。
  Future<void> _setObservationMode(bool v) async {
    setState(() => _observationMode = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('agent_observation_mode', v);
    await AgentService().initAgent();
  }

  /// ★ 0.83.0：邮箱总开关的**写穿**切换（拨一下立刻生效，不等页面底部保存）。
  ///
  /// 走 `AgentService.setMailEnabled`（唯一写入方）—— 它会同时落库并
  /// **立刻**把五个邮箱工具从注册表摘除 / 重新注册，所以关掉的这一下是真的关。
  Future<void> _setMailEnabled(bool v) async {
    setState(() => _mailEnabled = v);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await AgentService().setMailEnabled(v);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(v ? l10n.settingsMailOnToast : l10n.settingsMailOffToast),
    ));
  }

  /// 📧 邮箱代管卡（0.83.0）。
  ///
  /// ★ 三条纪律（隐私审计 P0-1 的正面要求）：
  ///   ① **默认关**，且关 = 工具根本不注册（`AgentService.setMailEnabled`）；
  ///   ② 开关**写穿生效**：拨一下立刻落库 + 立刻摘除 / 注册工具，不等页面底部保存；
  ///   ③ **不给假状态**：开了却没绑账号 ⇒ 明说"还没有账号"（开了也用不了就是
  ///      用不了，不能显示成可用）。
  Widget _buildMailCard(
      ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.alternate_email, color: theme.accentColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l10n.settingsMailTitle,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black)),
              ),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mailEnabled,
              activeColor: theme.accentColor,
              onChanged: _setMailEnabled,
              title: Text(l10n.settingsMailSubtitle,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: Text(l10n.settingsMailHint,
                  style: const TextStyle(fontSize: 12)),
            ),
            // 开了却没绑账号 ⇒ 实际上还是用不了。这是**静默失败**，必须显形。
            if (_mailEnabled && _mailAccountCount == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(l10n.settingsMailNoAccount,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orange)),
                  ),
                ]),
              ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.mail_outline, color: theme.accentColor),
              title: Text(l10n.settingsMailManageAccounts,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MailAccountScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎛 「进阶设置」入口（0.84.0：**本页不再放模式开关**）。
  ///
  /// 两个状态，用的都是**同一把尺**（`ModeController`，顶栏那个按钮写的也是它）：
  ///   · **进阶模式** ⇒ 一张卡，点进 `AdvancedSettingsScreen`（引擎 / 记忆 / 灵魂 /
  ///     自检那一大坨都搬到了那里，主人原话："不然设置中心页长长的一大页，
  ///     足以吓退初级用户"）；
  ///   · **入门模式** ⇒ 只留**一行小字**指路（`settingsModeHint`：模式切换在顶部
  ///     工具栏），不占卡片、不摆开关。★ 只留文字**不是**藏起来：告诉他在哪切，
  ///     他随时能切；而在本页再放一个开关就是"同一件事两个入口"，本仓已踩过。
  Widget _buildAdvancedEntry(
      ThemeProvider theme, bool isDark, AppLocalizations l10n, bool advanced) {
    if (!advanced) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          Icon(Icons.info_outline,
              size: 16, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 6),
          Expanded(
            child: Text(l10n.settingsModeHint,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54)),
          ),
        ]),
      );
    }
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Icon(Icons.tune, color: theme.accentColor),
        title: Text(l10n.settingsAdvancedTitle,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(l10n.settingsAdvancedEntryHint,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()),
        ),
      ),
    );
  }

  // 🚀 新增：挑选并保存自定义聊天背景
  Future<void> _pickBackground() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_bg_path', image.path);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsBgChanged)));
      }
    }
  }

  // 🚀 新增：恢复默认背景
  Future<void> _clearBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_bg_path');
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsBgReset)));
    }
  }

  /// 身份备份入口 + **常驻红标**（未备份时）。
  ///
  /// 与护照页那一处同款：状态长在**入口**上，用户不点进去也看得见。
  Widget _identityBackupTile(
      ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    final warn = !_backedUp;
    final accent = warn ? Colors.redAccent : theme.accentColor;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
          warn ? Icons.gpp_maybe_outlined : Icons.shield_moon_outlined,
          color: accent),
      title: Row(children: [
        Expanded(
          child: Text(l10n.idbEntry,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        if (warn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n.idbStatusNotBackedUp,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
      ]),
      subtitle: Text(
        warn ? l10n.idbStatusNotBackedUpHint : l10n.idbNoScreenshotShort,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IdentityBackupScreen()),
        );
        // 回来立刻刷新：用户很可能刚做完备份，红标应当马上熄灭。
        var backed = true;
        try {
          backed = await AgentIdentity().isBackedUp();
        } catch (_) {}
        if (mounted) setState(() => _backedUp = backed);
      },
    );
  }

  /// 打开一份**官网法务文档**（隐私政策 / 服务条款）。
  ///
  /// ★ 把「打不开」变成**看得见的失败**：`launchUrl` 返回 `false` 或抛异常时弹一条
  ///   SnackBar。不接住的话，用户点了**没反应** —— 那正是本仓反复警惕的**静默失败**。
  /// ★ URL 由 `SetupService.defaultWebUrl` 拼出（**出厂地址只此一处**），本方法不内嵌域名。
  /// ★ 「打不开要看得见」与 ADR-002 的「申请访问 Key」**共用同一实现**
  ///   （`openExternalLink`）—— 两处一旦分叉，症状就是"某个链接点得动、
  ///   另一个点了像没接线"，而这种漂移在界面上极难看出是同一件事。
  Future<void> _openLegal(String path) async {
    final l10n = AppLocalizations.of(context);
    await openExternalLink(
      context,
      '${SetupService.defaultWebUrl}$path',
      failureText: l10n.settingsLegalOpenFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    // ★★ 0.84.0：**不在本页放"进阶模式"开关**。模式的唯一入口是顶部工具栏
    //   （`main.dart` 里紧挨主题 / 语言的那个按钮，`ModeController` 单一事实源）。
    //   0.83.0 曾在本页又摆一个开关 —— 那是**同一件事两个入口**，正是
    //   `verify_mode_visibility` ⑤「顶栏 = 模式切换的唯一入口」要防的东西
    //   （本仓反复踩的老坑）。这里只**订阅**模式：`Provider.of` 默认 listen=true，
    //   顶栏一改，本页立刻重建 ⇒ 进阶入口随之出现 / 收起。
    final advanced = !Provider.of<ModeController>(context).simpleMode;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(title: Text(l10n.settingsTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: theme.accentColor))
        : Container(
            decoration: theme.backgroundDecoration,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // 🎨 外观与个性化（聊天背景墙纸）
                  Card(
                    color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.palette, color: theme.accentColor, size: 28), const SizedBox(width: 10), Text(l10n.settingsSecAppearance, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))]),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickBackground, 
                                icon: const Icon(Icons.image), 
                                label: Text(l10n.settingsSetWallpaper),
                                style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: Colors.white),
                              ),
                              OutlinedButton.icon(
                                onPressed: _clearBackground, 
                                icon: const Icon(Icons.delete_outline), 
                                label: Text(l10n.settingsRestoreDefault),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🔒 安全：观察模式 / 感知授权入口 / 身份备份
                  Card(
                    color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.verified_user, color: theme.accentColor, size: 28), const SizedBox(width: 10), Text(l10n.settingsSecSafety, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))]),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: Text(l10n.settingsObservationMode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            subtitle: Text(l10n.settingsObservationSubtitle, style: const TextStyle(fontSize: 12)),
                            value: _observationMode,
                            activeColor: theme.accentColor,
                            onChanged: _setObservationMode,
                          ),
                          const Divider(height: 24),
                          _identityBackupTile(theme, isDark, l10n),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 📧 邮箱代管（0.83.0：**总开关**，默认关 —— 隐私审计 P0-1）
                  _buildMailCard(theme, isDark, l10n),
                  const SizedBox(height: 16),
                  // 🎛 「进阶设置」入口（0.84.0：只有进阶模式才出现；入门模式只留一行指路小字）
                  _buildAdvancedEntry(theme, isDark, l10n, advanced),
                  const SizedBox(height: 16),
                  // 上手辅助：术语速查（0.50.0）—— 名词太多、跨页反复出现，
                  // 属"整页常识" ⇒ 用页面级入口，而不是逐处挂问号（见 help_dot「三条纪律」②）。
                  Card(
                    color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      leading: Icon(Icons.menu_book, color: theme.accentColor),
                      title: Text(l10n.glossaryTitle,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text(l10n.glossaryIntro,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GlossaryScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 法律与关于（0.54.0）—— 上架要求「隐私政策必须可达」，把两份法务文档的
                  // 入口放进 App 内。★ URL **显示出来**（打不开时用户仍能读到地址）；
                  // 域名走 SetupService.defaultWebUrl（出厂地址只此一处）。
                  // ★ 两个路径必须与 landing 生成器产出的页面一致 ⇒ 由
                  //   tool/verify_legal_links.dart 跨端钉死，别在这里手改路径。
                  Card(
                    color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          leading: Icon(Icons.gavel_outlined, color: theme.accentColor),
                          title: Text(l10n.settingsLegalTitle,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text(l10n.settingsLegalIntro,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: Icon(Icons.privacy_tip_outlined, color: theme.accentColor, size: 20),
                          title: Text(l10n.settingsPrivacyTitle,
                              style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text('${SetupService.defaultWebUrl}/privacy/',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
                          trailing: const Icon(Icons.open_in_new, size: 16),
                          onTap: () => _openLegal('/privacy/'),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: Icon(Icons.article_outlined, color: theme.accentColor, size: 20),
                          title: Text(l10n.settingsTermsTitle,
                              style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text('${SetupService.defaultWebUrl}/terms/',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
                          trailing: const Icon(Icons.open_in_new, size: 16),
                          onTap: () => _openLegal('/terms/'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 检查更新（0.113.0）—— 侧载分发没有应用商店，版本公告来自官网
                  // version.json（landing/build.js 构建时现算，与下载页同一事实源）。
                  _UpdateCheckCard(onOpenDownload: () => _openLegal('/download/')),
                  const SizedBox(height: 16),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }
}


/// 「检查更新」卡（0.113.0）。
///
/// 侧载分发**没有应用商店** ⇒ 版本公告只能来自官网 version.json。
/// 三条纪律（与 update_check_service.dart 对齐）：
///   ① 地址唯一来源 `SetupService.defaultWebUrl`（换域名只改那一处）；
///   ② 比较用版本名逐段数值化（本仓 versionCode 长期停在 +1，只比它会漏判）；
///   ③ 失败给语言无关状态码，UI 负责翻译；**网络失败 ≠ 没有更新**。
///
/// 进场自动检查走 24h 节流（节流期内不显形，不制造"每次都弹网络错误"的噪音）；
/// 手动点「检查更新」强制真查。
class _UpdateCheckCard extends StatefulWidget {
  const _UpdateCheckCard({required this.onOpenDownload});

  /// 打开官网下载页（经父级 _openLegal，与 privacy/terms 同一入口）。
  final VoidCallback onOpenDownload;

  @override
  State<_UpdateCheckCard> createState() => _UpdateCheckCardState();
}

class _UpdateCheckCardState extends State<_UpdateCheckCard> {
  /// null = 还没查到结论（节流期内进场自动检查就停在这个状态）。
  UpdateStatus? _status;
  RemoteVersion? _remote;
  String _localVersion = '—';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _autoCheck();
  }

  Future<void> _autoCheck() async {
    final lv = await UpdateCheckService().localVersion();
    if (!mounted) return;
    setState(() => _localVersion = lv?.version ?? '—');
    final r = await UpdateCheckService().check();
    if (!mounted) return;
    // 节流期内不显形 —— 没有新结论就不摆结果行（不给假状态）。
    if (r.status == UpdateStatus.throttled) return;
    setState(() {
      _status = r.status;
      _remote = r.remote;
    });
  }

  Future<void> _manualCheck() async {
    setState(() => _checking = true);
    final r = await UpdateCheckService().check(force: true);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _status = r.status;
      _remote = r.remote;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    // 状态 → 文案 + 颜色（语言无关码在这里才变成文字）
    String? resultText;
    Color? resultColor;
    FontWeight? resultWeight;
    if (_status == UpdateStatus.upToDate) {
      resultText = l10n.settingsUpdateUpToDate;
      resultColor = subColor;
    } else if (_status == UpdateStatus.updateAvailable && _remote != null) {
      resultText = l10n.settingsUpdateAvailable(_remote!.version);
      resultColor = theme.accentColor;
      resultWeight = FontWeight.bold;
    } else if (_status == UpdateStatus.networkError) {
      resultText = l10n.settingsUpdateNetworkError;
      resultColor = Colors.redAccent;
    } else if (_status == UpdateStatus.badResponse) {
      resultText = l10n.settingsUpdateBadResponse;
      resultColor = Colors.redAccent;
    }

    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.system_update, color: theme.accentColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l10n.settingsUpdateTitle,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: inkColor)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(l10n.settingsUpdateHint(_localVersion),
                style: TextStyle(fontSize: 12, color: subColor)),
            const SizedBox(height: 2),
            Text('${SetupService.defaultWebUrl}/download/',
                style: TextStyle(fontSize: 11, color: subColor)),
            if (resultText != null) ...[
              const SizedBox(height: 12),
              Text(resultText,
                  style: TextStyle(
                      fontSize: 13,
                      color: resultColor,
                      fontWeight: resultWeight ?? FontWeight.normal)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              if (_status == UpdateStatus.updateAvailable && _remote != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onOpenDownload,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(l10n.settingsUpdateOpenDownload,
                        style: const TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _checking ? null : _manualCheck,
                  icon: _checking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(
                      _checking
                          ? l10n.settingsUpdateChecking
                          : l10n.settingsUpdateButton,
                      style: const TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.accentColor,
                    side: BorderSide(color: theme.accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}


