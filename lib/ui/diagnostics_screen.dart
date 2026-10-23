import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/diagnostic_probes.dart';
import '../core/diagnostics.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';

/// 系统自检屏（0.79.0）。
///
/// 用途：**真机复核**时把"看不见的底座事实"摊开 —— 只读、无副作用、无网络。
/// 特别是 FTS5：桌面 FFI 引擎证明不了 Android 的 SQLite 带不带 FTS5，
/// 只有真机跑一次才知道（见 `DBHelper._ensureFts` 的注释）。
///
/// ★ 路由纪律（R10）：本页由 `Navigator.push` 进入 ⇒ **必须自备不透明背景**，
///   否则浅色主题下整页看不见。这里用 `Scaffold` 的 `backgroundColor` 显式给底。
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<DiagResult>? _results;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    final r = await runDiagnostics(buildAppProbes());
    if (!mounted) return;
    setState(() {
      _results = r;
      _running = false;
    });
  }

  Future<void> _copy(AppLocalizations l10n) async {
    final r = _results;
    if (r == null) return;
    await Clipboard.setData(ClipboardData(text: formatDiagnostics(r)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.diagnosticsCopied)));
  }

  /// id → 本地化探针名。★ id 与 `diagnostic_probes.dart` 一一对应（改名要同步）。
  String _label(AppLocalizations l10n, String id) {
    switch (id) {
      case 'schema':
        return l10n.diagProbeSchema;
      case 'fts':
        return l10n.diagProbeFts;
      case 'memoryRows':
        return l10n.diagProbeMemoryRows;
      case 'memoryRecall':
        return l10n.diagProbeMemoryRecall;
      case 'memoryAddress':
        return l10n.diagProbeMemoryAddress;
      case 'kb':
        return l10n.diagProbeKb;
      default:
        return id; // 未知 id 原样显示，不假装有标题
    }
  }

  String _statusLabel(AppLocalizations l10n, DiagStatus s) {
    switch (s) {
      case DiagStatus.ok:
        return l10n.diagStatusOk;
      case DiagStatus.warn:
        return l10n.diagStatusWarn;
      case DiagStatus.fail:
        return l10n.diagStatusFail;
      case DiagStatus.info:
        return l10n.diagStatusInfo;
    }
  }

  IconData _statusIcon(DiagStatus s) {
    switch (s) {
      case DiagStatus.ok:
        return Icons.check_circle_outline;
      case DiagStatus.warn:
        return Icons.warning_amber_rounded;
      case DiagStatus.fail:
        return Icons.error_outline;
      case DiagStatus.info:
        return Icons.info_outline;
    }
  }

  /// 状态色。★ 不随主题反转（绿=好、红=坏是诊断语义，不是股票涨跌）。
  Color _statusColor(DiagStatus s) {
    switch (s) {
      case DiagStatus.ok:
        return const Color(0xFF2E7D32);
      case DiagStatus.warn:
        return const Color(0xFFE65100);
      case DiagStatus.fail:
        return const Color(0xFFC62828);
      case DiagStatus.info:
        return const Color(0xFF546E7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = _results;

    return Scaffold(
      // ★ 自备背景（R10）：push 进来的页不能是透明的。
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: Text(l10n.diagnosticsTitle),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.diagnosticsIntro,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          if (r == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l10n.diagnosticsRunning,
                      style: const TextStyle(fontSize: 13)),
                ]),
              ),
            )
          else
            Card(
              color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final it in r) ...[
                      ListTile(
                        leading: Icon(_statusIcon(it.status),
                            color: _statusColor(it.status)),
                        title: Text(
                          _label(l10n, it.id),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          // 前缀是稳定状态 token（不本地化），后面才是人读的细节。
                          '${_statusLabel(l10n, it.status)} · ${it.detail}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text('${it.elapsedMs}ms',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38)),
                      ),
                      if (it != r.last) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _running ? null : _run,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.diagnosticsRun),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: r == null ? null : () => _copy(l10n),
                icon: const Icon(Icons.copy_all, size: 18),
                label: Text(l10n.diagnosticsCopy),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
