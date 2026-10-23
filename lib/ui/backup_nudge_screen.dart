import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../core/backup_nudge_policy.dart';
import '../core/db_helper.dart';
import '../l10n/app_localizations.dart';
import 'identity_backup_flow.dart';

/// 备份补课屏：老用户 / 引导期跳过备份的用户，冷启动先见这一面。
///
/// 只有两个出口：**备份完成**（runBackupFlow 返回 true，isBackedUp 恒真，
/// 永不再见）或 **以后再说**（snooze 3 天）。没有"永久不再提醒"——
/// 备份是身份的生死线，这不是营销弹窗。
class BackupNudgeScreen extends StatefulWidget {
  const BackupNudgeScreen({Key? key, required this.onFinished})
      : super(key: key);

  final VoidCallback onFinished;

  @override
  State<BackupNudgeScreen> createState() => _BackupNudgeScreenState();
}

class _BackupNudgeScreenState extends State<BackupNudgeScreen> {
  bool _busy = false;

  Future<void> _doBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final agentId = await DBHelper.getAmbassador('my_agent_id') ?? '';
      if (!mounted) return;
      final ok = await runBackupFlow(context, agentId: agentId);
      if (ok && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await BackupNudgePolicy.clear(prefs);
        widget.onFinished();
      }
    } catch (e) {
      AppLogger.w('backup.nudge', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _later() async {
    final prefs = await SharedPreferences.getInstance();
    await BackupNudgePolicy.snooze(prefs);
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Icon(Icons.key_off_outlined, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                l10n.idbStatusNotBackedUp,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.onbBackupWhy,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, height: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const Spacer(flex: 3),
              FilledButton.icon(
                onPressed: _busy ? null : _doBackup,
                icon: _busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.key_outlined),
                label: Text(l10n.idbGenerateAction),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _later,
                child: Text(l10n.onbSkipBackup),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
