import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/agent_service.dart';
import '../core/device_control_service.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';

/// ============================================================
/// 手机控制（无障碍通道）设置页
///
/// 这是"智能体真正能替你办事"的开关页：打开后，它能读屏、点击、
/// 输入、滑动、打开应用——但受三重保险约束：
///   ① 这里的总开关（关掉即撤销工具，立即生效）
///   ② 首次使用时的一次性授权弹窗（可吊销）
///   ③ 敏感应用黑名单（银行/支付/系统设置永不触碰）
/// 每个动作都会写进审计，可在"管理设置"里回看。
/// ============================================================
class DeviceControlScreen extends StatefulWidget {
  const DeviceControlScreen({Key? key}) : super(key: key);

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  DeviceControlStatus? _status;
  bool _userEnabled = false;
  bool _loading = true;
  bool _saving = false;
  late TextEditingController _denylistController;

  @override
  void initState() {
    super.initState();
    _denylistController = TextEditingController();
    _reload();
  }

  @override
  void dispose() {
    _denylistController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final status = await DeviceControlService.status();
    final enabled = await DeviceControlService.isUserEnabled();
    final list = await DeviceControlService.denylist();
    if (!mounted) return;
    setState(() {
      _status = status;
      _userEnabled = enabled;
      _denylistController.text = list.join('\n');
      _loading = false;
    });
  }

  Future<void> _toggleMaster(bool value) async {
    final l10n = AppLocalizations.of(context);
    final status = _status;
    if (value && (status == null || !status.enabled)) {
      _toast(l10n.deviceControlToastNeedAccessibility);
      await DeviceControlService.openAccessibilitySettings();
      return;
    }
    setState(() => _saving = true);
    await DeviceControlService.setUserEnabled(value);
    // 立即重挂/撤销设备工具（可逆，不需要重启 App）
    await AgentService().refreshDbTools();
    if (!mounted) return;
    setState(() {
      _userEnabled = value;
      _saving = false;
    });
    _toast(value ? l10n.deviceControlToastOn : l10n.deviceControlToastOff);
  }

  Future<void> _saveDenylist() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    final list = _denylistController.text
        .split(RegExp(r'[\n,\uFF0C;\uFF1B]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await DeviceControlService.setDenylist(list);
    if (!mounted) return;
    setState(() => _saving = false);
    _toast(l10n.deviceControlToastSaved('${list.length}'));
  }

  Future<void> _resetDenylist() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    await DeviceControlService.setDenylist(
        List<String>.from(DeviceControlService.defaultDenylist));
    await _reload();
    if (!mounted) return;
    setState(() => _saving = false);
    _toast(l10n.deviceControlToastReset);
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
        title: Text(l10n.deviceControlTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.deviceControlRefreshStatus,
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
                  _toolsCard(theme, isDark),
                  const SizedBox(height: 16),
                  _denylistCard(theme, isDark),
                  const SizedBox(height: 24),
                  _footerNote(isDark),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _statusCard(
      ThemeProvider theme, bool isDark, DeviceControlStatus? status) {
    final l10n = AppLocalizations.of(context);
    final enabled = status?.enabled ?? false;
    final systemEnabled = status?.systemEnabled ?? false;
    final supported = status?.supported ?? false;
    final color = !supported
        ? Colors.grey
        : (enabled ? Colors.green : Colors.orange);
    final title = !supported
        ? l10n.deviceControlUnsupported
        : (enabled
            ? l10n.deviceControlServiceConnected
            : (systemEnabled
                ? l10n.deviceControlServiceCheckedNotConnected
                : l10n.deviceControlServiceOff));

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
                  supported && enabled
                      ? Icons.phone_android
                      : Icons.phonelink_erase,
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
              status?.message ?? l10n.deviceControlStatusUnknown,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            if (!enabled && !systemEnabled) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await DeviceControlService.openAccessibilitySettings();
                    _toast(l10n.deviceControlGoSystemHint);
                  },
                  icon: const Icon(Icons.settings_accessibility, size: 18),
                  label: Text(l10n.deviceControlGoSettings),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
            if (!enabled && systemEnabled) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.deviceControlRedetect),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.deviceControlRedetectTip,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _masterSwitchCard(
      ThemeProvider theme, bool isDark, DeviceControlStatus? status) {
    final l10n = AppLocalizations.of(context);
    final systemReady = status?.enabled ?? false;
    return Card(
      color: isDark ? Colors.black54 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(l10n.deviceControlAllowTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            subtitle: Text(
              systemReady
                  ? l10n.deviceControlAllowSubReady
                  : ((_status?.systemEnabled ?? false)
                      ? l10n.deviceControlAllowSubChecked
                      : l10n.deviceControlAllowSubNeedService),
              style: const TextStyle(fontSize: 12),
            ),
            value: _userEnabled,
            activeColor: theme.accentColor,
            onChanged: _saving ? null : _toggleMaster,
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

  Widget _toolsCard(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final tools = [
      ['phone_read_screen', l10n.deviceControlToolReadScreen],
      ['phone_tap', l10n.deviceControlToolTap],
      ['phone_input_text', l10n.deviceControlToolInput],
      ['phone_swipe', l10n.deviceControlToolSwipe],
      ['phone_press_key', l10n.deviceControlToolPressKey],
      ['phone_open_app', l10n.deviceControlToolOpenApp],
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
                  l10n.deviceControlToolsHeader,
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

  Widget _denylistCard(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
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
                const Icon(Icons.gpp_maybe_outlined,
                    color: Colors.redAccent, size: 22),
                const SizedBox(width: 10),
                Text(
                  l10n.deviceControlDenylistTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.deviceControlDenylistBody,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _denylistController,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'Courier', fontSize: 12.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[200],
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveDenylist,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(l10n.deviceControlSaveDenylist),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _saving ? null : _resetDenylist,
                  child: Text(l10n.deviceControlResetDefault),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerNote(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.deviceControlFooter,
      style: TextStyle(
        fontSize: 12,
        height: 1.7,
        color: isDark ? Colors.white54 : Colors.black45,
      ),
    );
  }
}
