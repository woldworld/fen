import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/agent_identity.dart';
import '../core/key_backup.dart';
import '../l10n/app_localizations.dart';
import 'help_dot.dart';

/// 「生成恢复码」的**共用流程** —— 引导页与身份备份页共用这一份。
///
/// 为什么必须共用：这是一段**由错误码和文案构成的策略**（口令多长、
/// 抄错会怎样、什么时候算"已备份"）。两处各写一份，迟早会有一处漏掉某个判断，
/// 而漏掉的那处恰恰是用户第一次遇到它的地方（引导页）。本仓吃过
/// "两处实现悄悄漂移"的亏，这里是同一个道理。
///
/// 返回 `true` = 已生成**且**用户确认抄下（并已 [AgentIdentity.markBackedUp]）。
Future<bool> runBackupFlow(
  BuildContext context, {
  required String agentId,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final pw = TextEditingController();
  final pw2 = TextEditingController();

  void toast(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.idbSectionBackup),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ★ 先讲"为什么"，再讲"怎么做"：用户不知道手机丢了会丢身份，
          //   就会把这一步当成一个可以随手划掉的表单。
          Text(l10n.onbBackupWhy),
          const SizedBox(height: 12),
          Text(l10n.idbWarnNoScreenshot),
          const SizedBox(height: 12),
          TextField(
            controller: pw,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.idbPwLabel),
          ),
          TextField(
            controller: pw2,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.idbPwConfirmLabel),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel)),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.idbGenerateAction)),
      ],
    ),
  );
  if (ok != true) return false;
  if (pw.text != pw2.text) {
    toast(l10n.idbPwMismatch);
    return false;
  }
  if (!KeyBackup.isPasswordAcceptable(pw.text)) {
    toast(l10n.idbPwTooShort);
    return false;
  }

  String? code;
  try {
    code = await AgentIdentity()
        .exportBackupCode(password: pw.text, agentId: agentId);
  } catch (_) {
    code = null;
  } finally {
    // 口令用完即弃：不保留任何引用
    pw.clear();
    pw2.clear();
  }
  if (code == null) {
    toast(l10n.idbRestoreUnavailable);
    return false;
  }
  if (!context.mounted) return false;

  final confirmed = await _showRecoveryCode(context, code);
  if (!confirmed) return false;
  // ★ 只有**用户确认已抄下**才记"已备份" —— 这一步决定红标是否熄灭。
  await AgentIdentity().markBackedUp();
  toast(l10n.idbDoneToast);
  return true;
}

/// 「暂不备份」的**警告框**：必须过一次显式确认——**强提示，不静默跳过**。
///
/// 返回 `true` = 用户看了警告仍然选择继续。
Future<bool> confirmSkipBackup(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
      title: Text(l10n.onbSkipWarnTitle),
      content: Text(l10n.onbSkipWarnBody),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.idbGenerateAction)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.onbSkipConfirm,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  return go == true;
}

/// 显示恢复码并等用户确认。返回 `true` = 已确认抄下。
Future<bool> _showRecoveryCode(BuildContext context, String code) async {
  final l10n = AppLocalizations.of(context);
  var copied = false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Row(children: [
            Flexible(child: Text(l10n.idbCodeTitle)),
            const SizedBox(width: 6),
            // 0.51.0：抄写须知（长按复制 / 逐段核对）搬进 `?`
            const HelpDot(topic: HelpTopic.identityCode),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(ctx).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  code,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.idbCopyCode),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    setLocal(() => copied = true);
                  },
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: copied,
                onChanged: (v) => setLocal(() => copied = v ?? false),
                title: Text(l10n.idbICopied,
                    style: Theme.of(ctx).textTheme.bodyMedium),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!copied) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(l10n.idbNeedCopied)));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      });
    },
  );
  return ok == true;
}
