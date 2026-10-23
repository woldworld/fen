import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/telemetry.dart';
import '../core/telemetry_store_db.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';

/// 最小看板（PRD §7.3）：一行一周的漏斗 + TTFD 中位数 + 披露代价 Δ。
///
/// 数据源 = 本机 `DbTelemetryStore`。PRD 里的"下载/7 日留存"需要服务端数据，
/// 单机版先不做，表里留空 —— 不假装有数。
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _WeekRow {
  final String label;
  int onboarding = 0;
  int circle = 0;
  int delegation = 0;
  int intercard = 0;
  int handshake = 0;
  final Set<String> active = {};
  final List<int> ttfd = [];

  _WeekRow(this.label);
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  List<_WeekRow> _rows = [];
  int? _ttfdMedian;
  double? _delta;

  static const int _weeks = 8;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = Telemetry.instance?.store;
    final events = store is DbTelemetryStore
        ? await store.all()
        : (await Telemetry.instance?.events() ?? const <TelemetryEvent>[]);

    // 周桶：以周一 00:00 为界，取最近 _weeks 周（含本周）
    final now = DateTime.now();
    final thisMonday =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final buckets = List<_WeekRow>.generate(_weeks, (i) {
      final start = thisMonday.subtract(Duration(days: 7 * (_weeks - 1 - i)));
      return _WeekRow('${start.month}/${start.day}');
    });

    int? weekIndex(int tsMs) {
      final d = DateTime.fromMillisecondsSinceEpoch(tsMs);
      final monday =
          DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
      final diff = monday.difference(thisMonday).inDays;
      final idx = (diff / 7).round() + (_weeks - 1);
      return (idx >= 0 && idx < _weeks) ? idx : null;
    }

    for (final e in events) {
      final i = weekIndex(e.tsMs);
      if (i == null) continue;
      final row = buckets[i];
      final self = (e.props['self'] ?? '') as String;
      if (self.isNotEmpty) row.active.add(self);

      switch (e.name) {
        case TelemetryEvents.onboardingDone:
          row.onboarding++;
        case TelemetryEvents.circleEntered:
          row.circle++;
        case TelemetryEvents.delegationDone:
          row.delegation++;
        case TelemetryEvents.intercardApproved:
          row.intercard++;
        case TelemetryEvents.handshake:
          row.handshake++;
      }
    }

    // TTFD：按用户算 onboarding → 首个委托完成的耗时，落到"完成那周"
    final users = <String>{
      for (final e in events)
        if (e.name == TelemetryEvents.onboardingDone)
          (e.props['self'] ?? '') as String,
    }..removeWhere((s) => s.isEmpty);
    for (final u in users) {
      // 该用户首个 delegation_done 的时间
      int? doneAt;
      for (final e in events) {
        if (e.name == TelemetryEvents.delegationDone &&
            e.props['self'] == u &&
            (doneAt == null || e.tsMs < doneAt)) {
          doneAt = e.tsMs;
        }
      }
      if (doneAt == null) continue;
      final i = weekIndex(doneAt);
      final lat = Ttfd.firstDelegationLatency(self: u, events: events);
      if (i != null && lat != null) buckets[i].ttfd.add(lat);
    }

    // Δ（Phase −1）：disclosure_variant 事件 → 各组回复率之差
    final groups = <String, List<bool>>{};
    for (final e in events) {
      if (e.name != TelemetryEvents.disclosureVariant) continue;
      final variant = (e.props['variant'] ?? e.props['group'] ?? '?') as String;
      final replied = e.props['replied'] == true || e.props['replied'] == 1;
      groups.putIfAbsent(variant, () => []).add(replied);
    }
    double? rateOf(List<String> keys) {
      final vals = [for (final k in keys) ...?groups[k]];
      if (vals.isEmpty) return null;
      return vals.where((r) => r).length / vals.length;
    }

    final control = rateOf(['control', 'no_disclosure', 'A']);
    final treated = rateOf(['disclosure', 'B']);
    double? delta;
    if (control != null && treated != null) delta = control - treated;

    if (!mounted) return;
    setState(() {
      _rows = buckets;
      _ttfdMedian = Ttfd.median(buckets.expand((r) => r.ttfd).toList());
      _delta = delta;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.isDark;

    // ★ 同 delegation_screen：本页是被 push 出来的路由，拿不到 MainNavigator 的渐变底，
    //   透明 Scaffold 会在浅色主题下露出黑底 ⇒ 自带一份渐变。
    return Container(
      decoration: theme.backgroundDecoration,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: theme.accentColor))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _summaryCards(l10n, isDark),
                const SizedBox(height: 16),
                Text(l10n.dashboardFunnelTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _funnelTable(l10n, isDark),
                const SizedBox(height: 12),
                Text(l10n.dashboardSourceHint,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
      ),
    );
  }

  Widget _summaryCards(AppLocalizations l10n, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _card(
            l10n.dashboardTtfd,
            _ttfdMedian == null
                ? '—'
                : _fmtDuration(_ttfdMedian!),
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _card(
            l10n.dashboardDelta,
            _delta == null ? '—' : '${_delta! >= 0 ? '+' : ''}${(_delta! * 100).toStringAsFixed(1)}pt',
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _card(String title, String value, bool isDark) {
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _funnelTable(AppLocalizations l10n, bool isDark) {
    if (_rows.every((r) =>
        r.onboarding == 0 &&
        r.circle == 0 &&
        r.delegation == 0 &&
        r.intercard == 0 &&
        r.handshake == 0 &&
        r.active.isEmpty)) {
      return Text(l10n.dashboardNoData);
    }
    final headerStyle = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white54 : Colors.black54);

    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          headingTextStyle: headerStyle,
          columns: [
            DataColumn(label: Text(l10n.dashboardColWeek)),
            DataColumn(label: Text(l10n.dashboardColOnboarding), numeric: true),
            DataColumn(label: Text(l10n.dashboardColCircle), numeric: true),
            DataColumn(label: Text(l10n.dashboardColDelegation), numeric: true),
            DataColumn(label: Text(l10n.dashboardColIntercard), numeric: true),
            DataColumn(label: Text(l10n.dashboardColHandshake), numeric: true),
            DataColumn(label: Text(l10n.dashboardColActive), numeric: true),
          ],
          rows: [
            for (final r in _rows)
              DataRow(cells: [
                DataCell(Text(r.label)),
                DataCell(Text('${r.onboarding}')),
                DataCell(Text('${r.circle}')),
                DataCell(Text('${r.delegation}')),
                DataCell(Text('${r.intercard}')),
                DataCell(Text('${r.handshake}')),
                DataCell(Text('${r.active.length}')),
              ]),
          ],
        ),
      ),
    );
  }

  String _fmtDuration(int ms) {
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(0)}s';
    if (ms < 3600000) return '${(ms / 60000).toStringAsFixed(0)}m';
    if (ms < 86400000) return '${(ms / 3600000).toStringAsFixed(1)}h';
    return '${(ms / 86400000).toStringAsFixed(1)}d';
  }
}
