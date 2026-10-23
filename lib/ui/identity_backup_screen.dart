import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/agent_identity.dart';
import '../core/cloud_service.dart';
import '../core/db_helper.dart';
import '../core/identity_recovery.dart';
import '../core/identity_rotation.dart';
import '../core/key_backup.dart';
import '../core/local_archive.dart';
import '../core/wold_did.dart';
import '../l10n/app_localizations.dart';
import 'device_migration_screen.dart';
import 'help_dot.dart';
import 'identity_backup_flow.dart';
import 'rotation_chain_screen.dart';

/// 身份备份与恢复（"随人不随设备"）—— 见 `lib/身份可携带与恢复方案.md`。
///
/// 这一页只干两件事，但两件都必须**如实**：
///
/// | 动作 | 它凭什么安全 |
/// |---|---|
/// | **备份** | 恢复码里的种子是**口令加密**的；口令只用来解密，**从不经过网络** —— 我们既没存它，也没能力验证它 |
/// | **恢复** | 由**旧钥**签一条 ROTATE 声明交给 Hub 改绑，**新旧钥不同** ⇒ 旧手机当场失效，是迁移而不是复制 |
///
/// ### 三个刻意的设计选择（都不是随手写的）
///
/// ① **不许截图**要写在按钮前面，不是写在提示里 —— 恢复码等于身份，截图等于把身份
///    留在了相册与系统备份里，而用户不会把两者联系起来。
/// ② **恢复必须能核对身份**：先显示待恢复的 DID 再执行。拿 A 的备份恢复成 B，
///    是这类功能最坏的失败形态（不报错、无法察觉、不可挽回）。
/// ③ **界面不给"客服帮你找回"**：私钥不在我们手里，那会是一句我们**做不到**的承诺。
class IdentityBackupScreen extends StatefulWidget {
  const IdentityBackupScreen({Key? key}) : super(key: key);

  @override
  State<IdentityBackupScreen> createState() => _IdentityBackupScreenState();
}

class _IdentityBackupScreenState extends State<IdentityBackupScreen> {
  bool _busy = false;
  String _myId = '';
  String _did = '';

  /// 当前这把钥是否已备份（决定红标显不显示）。
  bool _backedUp = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await DBHelper.getAmbassador('my_agent_id') ?? '';
    String did = '';
    bool backed = false;
    try {
      // ★ 用**身份根 DID**：换钥后按当前钥现推会与 Hub 的身份锚分叉。
      final candidate = await AgentIdentity().identityRootDid();
      if (WoldDid.isValid(candidate)) did = candidate;
      backed = await AgentIdentity().isBackedUp();
    } catch (_) {
      // 身份未就绪：did 留空，页面照常显示，只是动作会提示不可用
    }
    if (!mounted) return;
    setState(() {
      _myId = id;
      _did = did;
      _backedUp = backed;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 把语言无关的错误码翻译成可照做的文案。
  String _friendly(AppLocalizations l10n, String? code) {
    switch (code) {
      case 'hub_not_configured':
        return l10n.idbErrHubNotConfigured;
      case BackupFault.idMismatch:
        return l10n.idbErrIdMismatch;
      case BackupFault.badPassword:
        return l10n.idbErrBadPassword;
      case BackupFault.badFormat:
      case BackupFault.badSeed:
      case BackupFault.pubMismatch:
        return l10n.idbErrBadFormat;
      case RotationFault.notCurrentKey:
        return l10n.idbErrNotCurrentKey;
      default:
        return l10n.idbRestoreFail(code ?? 'unknown');
    }
  }

  // ---------------------------------------------------------------- 备份

  Future<void> _startBackup() async {
    final l10n = AppLocalizations.of(context);
    if (_myId.isEmpty || _did.isEmpty) {
      _toast(l10n.idbRestoreUnavailable);
      return;
    }
    // 共用流程（与引导页同一份，避免两处口径漂移）
    final done = await runBackupFlow(context, agentId: _myId);
    if (done && mounted) await _load();
  }

  // ---------------------------------------------------------------- 恢复

  Future<void> _startRestore() async {
    final l10n = AppLocalizations.of(context);
    final codeCtl = TextEditingController();
    final idCtl = TextEditingController();
    final pwCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Flexible(child: Text(l10n.idbRestoreAction)),
          const SizedBox(width: 6),
          // 0.51.0：「换机恢复=带证明的换钥、旧机当场失效」搬进 `?`
          const HelpDot(topic: HelpTopic.identityRestore),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: codeCtl,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.idbRestoreCodeLabel),
            ),
            TextField(
              controller: idCtl,
              decoration: InputDecoration(labelText: l10n.idbRestoreIdLabel),
            ),
            TextField(
              controller: pwCtl,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.idbRestorePwLabel),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.idbRestoreCheckAction)),
        ],
      ),
    );
    if (ok != true) return;
    final code = codeCtl.text.trim();
    final agentId = idCtl.text.trim();
    final password = pwCtl.text;
    if (code.isEmpty || agentId.isEmpty || password.isEmpty) {
      _toast(l10n.idbRestoreNeedAll);
      return;
    }

    setState(() => _busy = true);
    Object plan;
    try {
      // ① 只做"准备"：**本机不落地任何改动**（服务端一拒就两头空，见 identity_recovery 头注释）
      plan = await IdentityRecovery.prepareFromBackup(
        code: code,
        password: password,
        agentId: agentId,
      );
    } finally {
      pwCtl.clear();
      if (mounted) setState(() => _busy = false);
    }
    if (plan is BackupError) {
      _toast(_friendly(l10n, plan.code));
      return;
    }
    final p = plan as RestorePlan;
    if (!mounted) return;

    // ② 让用户**核对身份**再动手：拿 A 的备份恢复成 B 是这类功能最坏的失败形态。
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.idbRestoreConfirmTitle),
        content: SelectableText(l10n.idbRestoreConfirmBody(p.oldDid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.idbRestoreConfirmAction)),
        ],
      ),
    );
    if (confirmed != true) return;

    // ③ 交给 Hub 改绑 —— 拿到成功**之后**才落地新钥（顺序不能反）
    setState(() => _busy = true);
    try {
      final res = await CloudService().rotateIdentity(p.rotation);
      if (!res.ok) {
        _toast(_friendly(l10n, res.code));
        return;
      }
      await p.apply(didAnchor: res.did);
      await _load();
      _toast(l10n.idbRestoreOk);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --------------------------------------------------- 本地数据导出 / 导入

  /// 导出本地数据成口令加密的 `.dahuang`。
  ///
  /// 口令与恢复码**可以不同**，也**建议不同**：两个文件的作用不同
  /// （一个是身份、一个是数据），共用一个口令等于把两把锁串成一把。
  Future<void> _exportArchive() async {
    final l10n = AppLocalizations.of(context);
    final pw = TextEditingController();
    final pw2 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.arcExportAction),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.arcExportNote),
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
              child: Text(l10n.arcExportAction)),
        ],
      ),
    );
    if (ok != true) return;
    if (pw.text != pw2.text) {
      _toast(l10n.idbPwMismatch);
      return;
    }
    if (!KeyBackup.isPasswordAcceptable(pw.text)) {
      _toast(l10n.idbPwTooShort);
      return;
    }

    setState(() => _busy = true);
    String? blob;
    try {
      blob = await LocalArchive.export(password: pw.text);
    } catch (_) {
      blob = null;
    } finally {
      pw.clear();
      pw2.clear();
      if (mounted) setState(() => _busy = false);
    }
    if (blob == null) {
      _toast(l10n.idbRestoreUnavailable);
      return;
    }
    final path = await _saveArchiveFile(blob);
    if (!mounted) return;
    await _showArchiveSaved(blob, path);
  }

  /// 把归档写到文件。优先**外部存储**（`Android/data/<pkg>/files`，用户能用
  /// 文件管理器/USB 取走），失败再退回应用私有目录。
  ///
  /// ⚠️ 归档是**纯文本**（`FENARC1....`），所以"复制内容"永远是一条可用的退路 ——
  /// 文件路径在部分机型上不好找，复制不受这些影响。
  Future<String?> _saveArchiveFile(String blob) async {
    try {
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {
        dir = null;
      }
      dir ??= await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final f = File('${dir.path}${Platform.pathSeparator}dahuang-$ts.dahuang');
      await f.writeAsString(blob, flush: true);
      return f.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showArchiveSaved(String blob, String? path) async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.arcSavedTitle),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(path == null ? l10n.arcSavedNoPath : l10n.arcSavedPath),
                if (path != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(path,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ],
                const SizedBox(height: 12),
                Text(l10n.arcSavedHint,
                    style: Theme.of(ctx).textTheme.bodySmall),
              ]),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l10n.idbCopyCode),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: blob));
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx)
                  .showSnackBar(SnackBar(content: Text(l10n.idbCopiedToast)));
            },
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonConfirm)),
        ],
      ),
    );
  }

  /// 导入归档：**先检查、再确认、最后才写**（顺序不能反）。
  Future<void> _importArchive() async {
    final l10n = AppLocalizations.of(context);
    final textCtl = TextEditingController();
    final pwCtl = TextEditingController();
    final picked = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.arcImportAction),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.arcImportNote),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(l10n.arcPickFile),
                onPressed: () async {
                  try {
                    final res = await FilePicker.platform.pickFiles();
                    final p = res?.files.single.path;
                    if (p != null) {
                      textCtl.text = await File(p).readAsString();
                    }
                  } catch (_) {
                    // 选文件失败不致命：还有"直接粘贴"这条路
                  }
                },
              ),
            ),
            TextField(
              controller: textCtl,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.arcImportCodeLabel),
            ),
            TextField(
              controller: pwCtl,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.idbRestorePwLabel),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.idbRestoreCheckAction)),
        ],
      ),
    );
    if (picked != true) return;
    final text = textCtl.text.trim();
    final password = pwCtl.text;
    if (text.isEmpty || password.isEmpty) {
      _toast(l10n.idbRestoreNeedAll);
      return;
    }

    setState(() => _busy = true);
    Object opened;
    try {
      opened = await LocalArchive.open(text, password: password);
    } finally {
      pwCtl.clear();
      if (mounted) setState(() => _busy = false);
    }
    if (opened is BackupError) {
      _toast(_friendly(l10n, opened.code));
      return;
    }
    if (opened is String) {
      _toast(l10n.arcErrNotArchive);
      return;
    }
    final payload = Map<String, Object?>.from(opened as Map);

    // 检查（本机零改动）；日志接不上 ⇒ 硬拒
    final inspect = await LocalArchive.inspect(payload);
    if (inspect is! ArchiveInspection) {
      _toast(l10n.arcErrNotArchive);
      return;
    }
    if (!mounted) return;
    if (!inspect.importable) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.arcLogConflictTitle),
          content: Text(l10n.arcLogConflictBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonConfirm)),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.arcImportConfirmTitle),
        content: SelectableText(l10n.arcImportConfirmBody(
            inspect.totalRows, inspect.counts.length, inspect.logSize)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.arcImportAction)),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final written = await LocalArchive.apply(payload);
      final total = written.values.fold<int>(0, (a, b) => a + b);
      await _load();
      _toast(l10n.arcImportOk(total));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 常驻状态条：未备份 = 红；已备份 = 绿。
  ///
  /// 为什么"未备份"必须常驻而不是弹一次：恢复码是**可选动作**，
  /// 弹窗点掉就再也没有提醒 —— 而用户是在**手机坏掉那一刻**才发现自己没有退路，
  /// 那时已经来不及了。这条红标就是那个"来不及"的哨兵。
  Widget _statusBanner(AppLocalizations l10n, ThemeData theme) {
    final ok = _backedUp;
    final color = ok ? Colors.green : theme.colorScheme.error;
    return Container(
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              ok ? l10n.idbStatusBackedUp : l10n.idbStatusNotBackedUp,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              ok ? l10n.idbStatusBackedUpHint : l10n.idbStatusNotBackedUpHint,
              style: theme.textTheme.bodySmall,
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ready = _myId.isNotEmpty && _did.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.idbTitle)),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.idbIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            // ★ 常驻状态条：未备份必须**看得见**（专家建议：像微信提示备份那样一直在）
            _statusBanner(l10n, theme),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: Text(l10n.idbCurrentDid),
                subtitle: SelectableText(_did.isEmpty ? '—' : _did),
                leading: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: const Text('User ID'),
                subtitle: SelectableText(_myId.isEmpty ? '—' : _myId),
                leading: const Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.idbSectionBackup,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(l10n.idbWarnNoScreenshot,
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: (!ready || _busy) ? null : _startBackup,
                        icon: const Icon(Icons.key_outlined),
                        label: Text(l10n.idbGenerateAction),
                      ),
                    ]),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HelpTitle(
                        text: l10n.idbSectionRestore,
                        topic: HelpTopic.identityRestore,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _startRestore,
                        icon: const Icon(Icons.restore),
                        label: Text(l10n.idbRestoreAction),
                      ),
                    ]),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HelpTitle(
                        text: l10n.arcSectionTitle,
                        topic: HelpTopic.identityArchive,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 10, runSpacing: 8, children: [
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _exportArchive,
                          icon: const Icon(Icons.save_alt),
                          label: Text(l10n.arcExportAction),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _importArchive,
                          icon: const Icon(Icons.file_open_outlined),
                          label: Text(l10n.arcImportAction),
                        ),
                      ]),
                    ]),
              ),
            ),
            const SizedBox(height: 16),
            // 换机直迁：两台手机面对面走完的一次迁移（新机发起 / 老机确认）。
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_iphone),
                title: Text(l10n.dmTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DeviceMigrationScreen(),
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 8),
            // 换钥链：把"可被第三方独立复核"摆到用户眼前。
            // ★ 这里刻意只做**入口**，不复述结论 —— 结论必须在本机重算（见该页头注释）。
            Card(
              child: ListTile(
                leading: const Icon(Icons.link),
                title: Text(l10n.rcTitle),
                subtitle: Text(l10n.rcIntro, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RotationChainScreen(agentId: _myId),
                          ),
                        ),
              ),
            ),
          ],
        ),
        if (_busy)
          Container(
            color: Colors.black26,
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.idbRestoreBusy),
            ]),
          ),
      ]),
    );
  }
}
