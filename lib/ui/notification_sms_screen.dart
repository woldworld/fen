import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/agent_service.dart';
import '../core/notification_sms_service.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';

/// ============================================================
/// 通知与短信（只读）设置页（0.75.0 · W6/G9）
///
/// 与「手机控制（无障碍）」页同构，但有三点必须说清的差异：
///   ① **只读** —— 本页解锁的任何工具都不会发送、回复、修改通知或短信；
///   ② **渠道差异** —— 只有 sideload 构建带这套能力；store 构建下
///      `status.supported == false`，本页会明说"当前版本不支持"，
///      而**不是**给一个点了没反应的开关（不给假状态）；
///   ③ **授权方式不同** —— 通知读取靠用户在系统「通知使用权」里手动勾选，
///      App 无法代开 ⇒ 只提供跳转；短信则是一次运行时权限，可在页内申请。
///
/// 信任面：通知只进原生内存环缓冲（不落库），短信按需查询（不落库），
/// 正文脱敏后才给模型，每次调用写审计。可随时到系统设置撤销。
/// ============================================================
class NotificationSmsScreen extends StatefulWidget {
  const NotificationSmsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSmsScreen> createState() => _NotificationSmsScreenState();
}

class _NotificationSmsScreenState extends State<NotificationSmsScreen> {
  NotifySmsStatus? _status;
  bool _userEnabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final status = await NotificationSmsService.status();
    final enabled = await NotificationSmsService.isUserEnabled();
    if (!mounted) return;
    setState(() {
      _status = status;
      _userEnabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggleMaster(bool value) async {
    final l10n = AppLocalizations.of(context);
    final status = _status;
    if (value && (status == null || !status.anyReady)) {
      // 未就绪就不放行 —— 否则会挂上"点了没反应"的工具
      _toast(l10n.notifySmsToastNeedService);
      await NotificationSmsService.openListenerSettings();
      return;
    }
    setState(() => _saving = true);
    await NotificationSmsService.setUserEnabled(value);
    // 立即重挂/撤销工具（可逆，不需要重启 App）
    await AgentService().refreshDbTools();
    if (!mounted) return;
    setState(() {
      _userEnabled = value;
      _saving = false;
    });
    _toast(value ? l10n.notifySmsToastOn : l10n.notifySmsToastOff);
  }

  Future<void> _requestSms() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    await NotificationSmsService.requestSms();
    await _reload();
    if (!mounted) return;
    setState(() => _saving = false);
    _toast(l10n.notifySmsRefreshStatus);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    final status = _status;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(l10n.notifySmsScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.notifySmsRefreshStatus,
            onPressed: _loading ? null : _reload,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: theme.accentColor))
          : Container(
              decoration: theme.backgroundDecoration,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _statusCard(theme, isDark, status),
                  const SizedBox(height: 16),
                  _masterSwitchCard(theme, isDark, status),
                  const SizedBox(height: 16),
                  if (status != null && status.smsDeclared) ...[
                    _smsCard(theme, isDark, status, l10n),
                    const SizedBox(height: 16),
                  ],
                  _toolsCard(theme, isDark, l10n),
                  const SizedBox(height: 24),
                  _footerNote(isDark, l10n),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _statusCard(
      ThemeProvider theme, bool isDark, NotifySmsStatus? status) {
    final l10n = AppLocalizations.of(context);
    final supported = status?.supported ?? false;
    final notifyReady = status?.notificationsReady ?? false;
    final checked =
        (status?.listenerEnabled ?? false) && !(status?.listenerConnected ?? false);
    final color = !supported
        ? Colors.grey
        : (notifyReady ? Colors.green : Colors.orange);
    final title = !supported
        ? l10n.notifySmsUnsupported
        : (notifyReady
            ? l10n.notifySmsListenerConnected
            : (checked
                ? l10n.notifySmsListenerCheckedNotConnected
                : l10n.notifySmsListenerOff));

    return Card(
      color: isDark ? Colors.black54 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  supported && notifyReady
                      ? Icons.notifications_active
                      : Icons.notifications_off_outlined,
                  color: color,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              status?.message ?? l10n.notifySmsStatusUnknown,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            if (supported) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await NotificationSmsService.openListenerSettings();
                    _toast(l10n.notifySmsGoSystemHint);
                  },
                  icon: const Icon(Icons.settings_applications, size: 18),
                  label: Text(l10n.notifySmsGoSettings),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              if (checked) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _reload,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.notifySmsRedetect),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.notifySmsRedetectTip,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _masterSwitchCard(
      ThemeProvider theme, bool isDark, NotifySmsStatus? status) {
    final l10n = AppLocalizations.of(context);
    final ready = status?.anyReady ?? false;
    final supported = status?.supported ?? false;
    return Card(
      color: isDark ? Colors.black54 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(l10n.notifySmsAllowTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            subtitle: Text(
              !supported
                  ? l10n.notifySmsUnsupported
                  : (ready ? l10n.notifySmsAllowSubReady : l10n.notifySmsAllowSubNeedService),
              style: const TextStyle(fontSize: 12),
            ),
            value: _userEnabled,
            activeColor: theme.accentColor,
            onChanged: (_saving || !supported) ? null : _toggleMaster,
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  Widget _smsCard(ThemeProvider theme, bool isDark, NotifySmsStatus status,
      AppLocalizations l10n) {
    final granted = status.smsGranted;
    return Card(
      color: isDark ? Colors.black54 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  granted ? Icons.mark_email_read_outlined : Icons.sms_failed_outlined,
                  color: granted ? Colors.green : Colors.orange,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.notifySmsSmsCardTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              granted ? l10n.notifySmsSmsGranted : l10n.notifySmsSmsNotGranted,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            if (!granted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _requestSms,
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: Text(l10n.notifySmsRequestSms),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toolsCard(ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    final tools = [
      ['notify_list', l10n.notifySmsToolNotifyList],
      ['sms_list', l10n.notifySmsToolSmsList],
      ['sms_search', l10n.notifySmsToolSmsSearch],
      ['notify_sms_status', l10n.notifySmsToolStatus],
    ];
    return Card(
      color: isDark ? Colors.black54 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle_outlined,
                    color: theme.accentColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  l10n.notifySmsToolsHeader,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tools.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle,
                          size: 6, color: theme.accentColor.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            children: [
                              TextSpan(
                                text: '${t[0]}  ',
                                style: const TextStyle(
                                    fontFamily: 'Courier',
                                    fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: t[1]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _footerNote(bool isDark, AppLocalizations l10n) {
    return Text(
      l10n.notifySmsFooter,
      style: TextStyle(
        fontSize: 12,
        height: 1.7,
        color: isDark ? Colors.white54 : Colors.black45,
      ),
    );
  }
}
