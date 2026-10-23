import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';

/// 术语速查页（0.50.0）——把 App 里反复出现、但第一次看不知道是什么的词
/// 一次说清（降低上手难度）。
///
/// ★ 为什么单独成页而不是继续加「?」：`?` 只治**单点**的"看不懂名词"，
///   而这里是"**整页常识**"—— 名词太多、跨页反复出现，逐处挂问号反而更乱
///   （见 `help_dot.dart` 顶部纪律②：同屏超过 3 处需要解释 ⇒ 应改用页面级入口）。
/// ★ 权威口径：本页每一条的**标题都取自 App 里真实出现的标签**（导航项 / 页签 / 卡片标题），
///   不是自造术语 —— 否则用户拿着速查表在界面上找不到对应词，等于没查。
/// ★ 本页是被 `Navigator.push` 出来的路由页：拿不到 `MainNavigator` 的渐变底，
///   必须自备一份（否则浅色主题下透明 Scaffold 会露出窗口黑底 ⇒ 整页看不见）。
class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    final groups = <_Group>[
      _Group(l10n.glossaryGroupIdentity, [
        _Term(l10n.glossaryAgentTitle, l10n.glossaryAgentBody),
        _Term(l10n.glossaryMaskTitle, l10n.glossaryMaskBody),
        _Term(l10n.glossaryPassportTitle, l10n.glossaryPassportBody),
        _Term(l10n.glossaryMigrationTitle, l10n.glossaryMigrationBody),
      ]),
      _Group(l10n.glossaryGroupSocial, [
        _Term(l10n.glossaryRadarTitle, l10n.glossaryRadarBody),
        _Term(l10n.glossaryRosterTitle, l10n.glossaryRosterBody),
        _Term(l10n.glossaryIntercardTitle, l10n.glossaryIntercardBody),
      ]),
      _Group(l10n.glossaryGroupWorld, [
        _Term(l10n.glossaryWorldTitle, l10n.glossaryWorldBody),
        _Term(l10n.glossaryRoomRoleTitle, l10n.glossaryRoomRoleBody),
        _Term(l10n.glossaryAutopilotTitle, l10n.glossaryAutopilotBody),
      ]),
      _Group(l10n.glossaryGroupTrust, [
        _Term(l10n.glossaryRepNetTitle, l10n.glossaryRepNetBody),
        _Term(l10n.glossaryMemoryTitle, l10n.glossaryMemoryBody),
        // ★ 0.69.0：长期画像是**主人第一次会撞见的新名词**，且直接关联两个开关的语义
        //   （回忆是总闸、画像是从属），不写进术语页 ⇒ 主人只能靠猜。
        _Term(l10n.glossaryProfileTitle, l10n.glossaryProfileBody),
        _Term(l10n.glossarySerendipityTitle, l10n.glossarySerendipityBody),
      ]),
    ];

    final headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: theme.accentColor,
    );
    final bodyStyle = TextStyle(
      fontSize: 13,
      height: 1.5,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    return Container(
      decoration: theme.backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          title: Text(l10n.glossaryTitle),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              l10n.glossaryIntro,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 12),
            for (final g in groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(g.header, style: headerStyle),
              ),
              for (final t in g.terms)
                Card(
                  color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ExpansionTile(
                    // 默认折叠：一屏能看到全部词条，想细看再点开（避免又是一面文字墙）
                    title: Text(t.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.body, style: bodyStyle),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Term {
  const _Term(this.title, this.body);
  final String title;
  final String body;
}

class _Group {
  const _Group(this.header, this.terms);
  final String header;
  final List<_Term> terms;
}
