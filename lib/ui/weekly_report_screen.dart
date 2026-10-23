import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/agent_report_source.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';

/// 智能体周报（0.74.0 W5/S7）——「这周它替我做了什么」的一次性交代。
///
/// ---------------------------------------------------------------------------
/// 为什么单独成页
/// ---------------------------------------------------------------------------
/// `agent_actions` 审计表一直在记账（设备操作 / 工具与设置 / 社交动作 /
/// 主动建议 / 审查拦截），但此前**只有写入方、零个主人可见的呈现** ——
/// 主人只能通过"分身到底干了什么"这个疑问去猜。本页把这份账本按**过去 7 天**
/// 摊开：每类动作各发生多少次，让信任有据可查。
///
/// ---------------------------------------------------------------------------
/// 边界（诚实登记）
/// ---------------------------------------------------------------------------
/// * **纯本地统计、零上传**：只读本机 `agent_actions` 表聚合计数，不读正文、
///   不送任何模型（与晨间三日回顾同款纪律）。
/// * **只读展示**：本页没有任何可操作项（不删、不改）——审计是事实记录。
/// * 口径是「动作次数」而非「干的活」：`agent_actions` 是**审计**埋点，
///   分身纯聊天不产生行。
/// * 本页是被 `Navigator.push` 出来的路由页：**自备渐变底**（R10 纪律，
///   否则浅色主题下透明 Scaffold 露出窗口黑底，整页看不见）。
class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  AgentActionStats _stats = const AgentActionStats();
  bool _loading = true;
  late DateTime _start;
  late DateTime _end;

  /// 展示顺序固定：与「重要 → 次要」的阅读顺序一致。
  static const List<AgentActionCategory> _order = [
    AgentActionCategory.tools,
    AgentActionCategory.device,
    AgentActionCategory.social,
    AgentActionCategory.suggestion,
    AgentActionCategory.review,
    AgentActionCategory.other,
  ];

  @override
  void initState() {
    super.initState();
    _end = DateTime.now();
    _start = _end.subtract(const Duration(days: 7));
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await SqliteAgentReportSource()
          .aggregateSince(_start.millisecondsSinceEpoch);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmtDay(DateTime d) => '${d.month}/${d.day}';

  IconData _iconFor(AgentActionCategory c) {
    switch (c) {
      case AgentActionCategory.tools:
        return Icons.build_circle_outlined;
      case AgentActionCategory.device:
        return Icons.phone_android;
      case AgentActionCategory.social:
        return Icons.public;
      case AgentActionCategory.suggestion:
        return Icons.lightbulb_outline;
      case AgentActionCategory.review:
        return Icons.shield_outlined;
      case AgentActionCategory.other:
        return Icons.more_horiz;
    }
  }

  String _labelFor(AppLocalizations l10n, AgentActionCategory c) {
    switch (c) {
      case AgentActionCategory.tools:
        return l10n.weeklyReportCatTools;
      case AgentActionCategory.device:
        return l10n.weeklyReportCatDevice;
      case AgentActionCategory.social:
        return l10n.weeklyReportCatSocial;
      case AgentActionCategory.suggestion:
        return l10n.weeklyReportCatSuggestion;
      case AgentActionCategory.review:
        return l10n.weeklyReportCatReview;
      case AgentActionCategory.other:
        return l10n.weeklyReportCatOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    final cardColor =
        isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      decoration: theme.backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(elevation: 0, title: Text(l10n.weeklyReportTitle)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text(l10n.weeklyReportSubtitle,
                        style: TextStyle(fontSize: 12, color: subColor)),
                    const SizedBox(height: 14),
                    _summaryCard(l10n, theme, cardColor, textColor, subColor),
                    const SizedBox(height: 16),
                    if (_stats.isEmpty)
                      _card(
                        cardColor: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l10n.weeklyReportEmpty,
                              style: TextStyle(fontSize: 13, color: subColor)),
                        ),
                      )
                    else
                      ...[
                        for (final c in _order)
                          if ((_stats.byCategory[c] ?? 0) > 0)
                            _categoryRow(l10n, theme, cardColor, textColor,
                                subColor, c, _stats.byCategory[c]!),
                      ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summaryCard(AppLocalizations l10n, ThemeProvider theme,
      Color cardColor, Color textColor, Color subColor) {
    return _card(
      cardColor: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.weeklyReportRange(_fmtDay(_start), _fmtDay(_end)),
              style: TextStyle(fontSize: 12, color: subColor),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.weeklyReportTotal(_stats.total),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.weeklyReportActiveDays(_stats.activeDays),
              style: TextStyle(fontSize: 12, color: subColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryRow(AppLocalizations l10n, ThemeProvider theme,
      Color cardColor, Color textColor, Color subColor,
      AgentActionCategory c, int count) {
    final total = _stats.total == 0 ? 1 : _stats.total;
    final frac = (count / total).clamp(0.0, 1.0);
    return _card(
      cardColor: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(c), size: 20, color: theme.accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_labelFor(l10n, c),
                      style: TextStyle(fontSize: 14, color: textColor)),
                ),
                Text('$count',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 6,
                backgroundColor: subColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, required Color cardColor}) => Card(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: child,
        ),
      );
}
