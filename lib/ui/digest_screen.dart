import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/digest_service.dart';
import '../core/telemetry.dart';
import '../core/theme_provider.dart';
import '../core/wold_runtime.dart';
import '../l10n/app_localizations.dart';

/// 每日摘要页（PRD §5.2 B 阶段 / §7.2 A3 实验）。
///
/// - 打开即记 `digest_last_opened_day`（"每日一次存在感"的红点依据）。
/// - 打开即埋 `digest_opened`（带 A3 分组 variant）；
///   点动作再埋 `digest_action_clicked`。
/// - 动作通过 [onNavigate] 回调交给宿主（托办页）执行跳转，
///   本页不做导航决策。
class DigestScreen extends StatefulWidget {
  /// 动作点击回调：参数为 DigestAction.kind。
  final void Function(String actionKind) onNavigate;

  const DigestScreen({super.key, required this.onNavigate});

  @override
  State<DigestScreen> createState() => _DigestScreenState();
}

class _DigestScreenState extends State<DigestScreen> {
  bool _loading = true;
  DigestReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rt = WoldRuntime.i;
    final me = await rt.myAgentId();
    final report = await rt.digest.build(selfId: me);

    // 打开即记录：今日已看过（红点消失）+ A3 打开埋点
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await prefs.setString('digest_last_opened_day', dayKey);
    Telemetry.instance?.track(TelemetryEvents.digestOpened, props: {
      'self': me,
      'variant': report.variant,
      'action_clicked': false,
    });

    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  void _onAction(DigestAction a) {
    final report = _report;
    if (report != null) {
      Telemetry.instance?.track(TelemetryEvents.digestActionClicked, props: {
        'self': report.selfId,
        'variant': report.variant,
        'action': a.kind,
      });
    }
    widget.onNavigate(a.kind);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.isDark;
    final report = _report;

    // ★ 同 delegation_screen：本页是被 push 出来的路由，拿不到 MainNavigator 的渐变底，
    //   透明 Scaffold 会在浅色主题下露出黑底 ⇒ 自带一份渐变。
    return Container(
      decoration: theme.backgroundDecoration,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.digestTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading || report == null
          ? Center(child: CircularProgressIndicator(color: theme.accentColor))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _noteCard(l10n, report, isDark),
                if (report.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(l10n.digestEmpty)),
                  )
                else ...[
                  _section(l10n, isDark, l10n.digestSectionPending,
                      _pendingCards(report, isDark)),
                  _section(l10n, isDark, l10n.digestSectionMine,
                      _mineCards(report, isDark)),
                  _section(l10n, isDark, l10n.digestSectionCircle,
                      _circleCards(report, isDark)),
                  if (report.of(DigestFact.kindChatSummary).isNotEmpty)
                    _section(l10n, isDark, l10n.digestSectionChat,
                        _chatCards(report, isDark)),
                  _section(l10n, isDark, l10n.digestSectionStats,
                      _statCards(l10n, report, isDark)),
                ],
              ],
            ),
      ),
    );
  }

  Widget _noteCard(AppLocalizations l10n, DigestReport report, bool isDark) {
    final withActions = report.variant == DigestVariant.withActions;
    return Card(
      color: isDark ? Colors.black38 : Colors.white.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(withActions ? l10n.digestNoteAction : l10n.digestNotePlain,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38)),
            if (report.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in report.actions)
                    OutlinedButton(
                      onPressed: () => _onAction(a),
                      child: Text(_actionLabel(l10n, a.kind)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _actionLabel(AppLocalizations l10n, String kind) => switch (kind) {
        DigestAction.kindOpenInbox => l10n.digestActionOpenInbox,
        DigestAction.kindOpenOutbox => l10n.digestActionOpenOutbox,
        DigestAction.kindOpenCircle => l10n.digestActionOpenCircle,
        DigestAction.kindOpenDashboard => l10n.digestActionOpenDashboard,
        _ => kind,
      };

  Widget _section(AppLocalizations l10n, bool isDark, String title,
      List<Widget> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...cards,
      ],
    );
  }

  Widget _factCard(bool isDark, String title, [String? subtitle]) {
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null || subtitle.isEmpty
            ? null
            : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  List<Widget> _pendingCards(DigestReport r, bool isDark) => [
        for (final f in r.of(DigestFact.kindPendingInbox))
          _factCard(isDark, f.data['task'] as String? ?? '', '← ${f.data['from']}'),
      ];

  List<Widget> _mineCards(DigestReport r, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final out = <Widget>[];
    for (final f in r.of(DigestFact.kindSentNew)) {
      out.add(_factCard(
          isDark, f.data['task'] as String? ?? '', '→ ${f.data['to']}'));
    }
    for (final f in r.of(DigestFact.kindSentAnswered)) {
      out.add(_factCard(isDark, '✅ ${f.data['task']}',
          l10n.digestToResponse('${f.data['to']}', '${f.data['response']}')));
    }
    for (final f in r.of(DigestFact.kindSentDeclined)) {
      out.add(_factCard(isDark, '❌ ${f.data['task']}', '→ ${f.data['to']}'));
    }
    for (final f in r.of(DigestFact.kindSentRevoked)) {
      out.add(_factCard(isDark, '🚫 ${f.data['task']}', '→ ${f.data['to']}'));
    }
    return out;
  }

  List<Widget> _circleCards(DigestReport r, bool isDark) => [
        for (final f in r.of(DigestFact.kindCircleJoined))
          _factCard(isDark, f.data['name'] as String? ?? ''),
      ];

  List<Widget> _chatCards(DigestReport r, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final out = <Widget>[];
    for (final f in r.of(DigestFact.kindChatSummary)) {
      final sessions = (f.data['sessions'] as int?) ?? 0;
      final turns = (f.data['turns'] as int?) ?? 0;
      final days = (f.data['days'] as int?) ?? 0;
      final topics =
          (f.data['topics'] as List?)?.cast<String>() ?? const <String>[];
      out.add(_factCard(
          isDark, l10n.digestChatSummary(sessions, turns, days)));
      if (topics.isNotEmpty) {
        out.add(_factCard(
            isDark, l10n.digestChatTopics(topics.take(3).join('、')),
            '常聊主题'));
      }
    }
    return out;
  }

  List<Widget> _statCards(AppLocalizations l10n, DigestReport r, bool isDark) {
    final done = r.of(DigestFact.kindErrandDone).length;
    final hs = r.of(DigestFact.kindHandshake).length;
    final out = <Widget>[];
    if (done > 0) out.add(_factCard(isDark, '$done ${l10n.digestStatDone}'));
    if (hs > 0) out.add(_factCard(isDark, '$hs ${l10n.digestStatHandshake}'));
    return out;
  }
}
