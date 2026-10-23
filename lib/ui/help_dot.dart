import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 按需帮助（0.41.0）——把"贴在界面上的说明小字"收进一个可点开的问号。
///
/// 三条纪律（写在这里，避免后来者把它当成装饰件滥用）：
/// 1. **只在三类地方挂问号**：看不懂的名词、会踩坑的操作、**不可逆的动作**（后者属解释义务，必挂）。
/// 2. **同屏不超过 3 个**；超过 3 处需要解释 ⇒ 说明那是"整页常识"，应改用页面级 [HelpAction]。
/// 3. **挂上问号就把原来的小字删掉** —— 两者并存等于把凌乱翻倍。
///
/// 文案一律走 ARB（否则英文界面会出中文），见 `help*` 键族。
enum HelpTopic {
  worldOverview,
  worldMetric,
  worldBridge,
  worldRoomRole,
  intercardDisclosure,
  passportOverview,
  passportOffline,
  passportFunnel,
  passportReputation,
  passportLog,
  socialOverview,
  socialPersonaTier,
  socialRadar,
  socialChannelGuide,
  notifyGuide,
  settingsLocalModel,
  skillMarket,
  // ── 0.51.0 推广批次：把「段落型常驻小字」（≥40 字）搬进 `?` ──
  settingsRecall,
  identityRestore,
  identityArchive,
  identityCode,
  deviceMigration,
  rotationChainAuthority,
  toolBus,
  // ── 遇幸实验室：恢复集成时丢掉的"逐页使用说明"（每个 tab 一个，五语种）──
  serendipityMorning,
  serendipityChallenge,
  serendipityAlchemist,
  serendipityNight,
  serendipityDiary,
  serendipityOracle,
  // ── 0.115.0 举报批次：举报流程（入口/工单/状态/申诉）说明 ──
  reportGuide,
}

/// 一个帮助主题的标题 + 正文（均取自 ARB）。
class HelpContent {
  const HelpContent(this.title, this.body);

  final String title;
  final String body;
}

/// 主题 → 文案。**穷尽 switch**：新增枚举值若忘配文案，编译期就报错。
HelpContent helpContentOf(AppLocalizations l10n, HelpTopic topic) {
  switch (topic) {
    case HelpTopic.worldOverview:
      return HelpContent(l10n.helpWorldOverviewTitle, l10n.helpWorldOverviewBody);
    case HelpTopic.worldMetric:
      return HelpContent(l10n.helpWorldMetricTitle, l10n.helpWorldMetricBody);
    case HelpTopic.worldBridge:
      return HelpContent(l10n.helpWorldBridgeTitle, l10n.helpWorldBridgeBody);
    case HelpTopic.worldRoomRole:
      return HelpContent(l10n.helpWorldRoomRoleTitle, l10n.helpWorldRoomRoleBody);
    case HelpTopic.intercardDisclosure:
      return HelpContent(
          l10n.helpIntercardDisclosureTitle, l10n.helpIntercardDisclosureBody);
    case HelpTopic.passportOverview:
      return HelpContent(l10n.helpPassportOverviewTitle, l10n.helpPassportOverviewBody);
    case HelpTopic.passportOffline:
      return HelpContent(l10n.helpPassportOfflineTitle, l10n.helpPassportOfflineBody);
    case HelpTopic.passportFunnel:
      return HelpContent(l10n.helpPassportFunnelTitle, l10n.helpPassportFunnelBody);
    case HelpTopic.passportReputation:
      return HelpContent(
          l10n.helpPassportReputationTitle, l10n.helpPassportReputationBody);
    case HelpTopic.passportLog:
      return HelpContent(l10n.helpPassportLogTitle, l10n.helpPassportLogBody);
    case HelpTopic.socialOverview:
      return HelpContent(l10n.helpSocialOverviewTitle, l10n.helpSocialOverviewBody);
    case HelpTopic.socialPersonaTier:
      return HelpContent(
          l10n.helpSocialPersonaTierTitle, l10n.helpSocialPersonaTierBody);
    case HelpTopic.socialRadar:
      return HelpContent(l10n.helpSocialRadarTitle, l10n.helpSocialRadarBody);
    case HelpTopic.socialChannelGuide:
      return HelpContent(
          l10n.helpSocialChannelGuideTitle, l10n.helpSocialChannelGuideBody);
    case HelpTopic.notifyGuide:
      return HelpContent(l10n.helpNotifyGuideTitle, l10n.helpNotifyGuideBody);
    case HelpTopic.settingsLocalModel:
      return HelpContent(
          l10n.helpSettingsLocalModelTitle, l10n.helpSettingsLocalModelBody);
    case HelpTopic.skillMarket:
      return HelpContent(l10n.helpSkillMarketTitle, l10n.helpSkillMarketBody);
    case HelpTopic.settingsRecall:
      return HelpContent(l10n.helpSettingsRecallTitle, l10n.helpSettingsRecallBody);
    case HelpTopic.identityRestore:
      return HelpContent(
          l10n.helpIdentityRestoreTitle, l10n.helpIdentityRestoreBody);
    case HelpTopic.identityArchive:
      return HelpContent(
          l10n.helpIdentityArchiveTitle, l10n.helpIdentityArchiveBody);
    case HelpTopic.identityCode:
      return HelpContent(l10n.helpIdentityCodeTitle, l10n.helpIdentityCodeBody);
    case HelpTopic.deviceMigration:
      return HelpContent(
          l10n.helpDeviceMigrationTitle, l10n.helpDeviceMigrationBody);
    case HelpTopic.rotationChainAuthority:
      return HelpContent(l10n.helpRotationChainAuthorityTitle,
          l10n.helpRotationChainAuthorityBody);
    case HelpTopic.toolBus:
      return HelpContent(l10n.helpToolBusTitle, l10n.helpToolBusBody);
    case HelpTopic.serendipityMorning:
      return HelpContent(l10n.helpSerendipityMorningTitle,
          l10n.helpSerendipityMorningBody);
    case HelpTopic.serendipityChallenge:
      return HelpContent(l10n.helpSerendipityChallengeTitle,
          l10n.helpSerendipityChallengeBody);
    case HelpTopic.serendipityAlchemist:
      return HelpContent(l10n.helpSerendipityAlchemistTitle,
          l10n.helpSerendipityAlchemistBody);
    case HelpTopic.serendipityNight:
      return HelpContent(
          l10n.helpSerendipityNightTitle, l10n.helpSerendipityNightBody);
    case HelpTopic.serendipityDiary:
      return HelpContent(
          l10n.helpSerendipityDiaryTitle, l10n.helpSerendipityDiaryBody);
    case HelpTopic.serendipityOracle:
      return HelpContent(
          l10n.helpSerendipityOracleTitle, l10n.helpSerendipityOracleBody);
    case HelpTopic.reportGuide:
      return HelpContent(l10n.helpReportGuideTitle, l10n.helpReportGuideBody);
  }
}

/// 打开某个主题的说明弹层（底部弹层，点遮罩即关）。
Future<void> showHelpSheet(BuildContext context, HelpTopic topic) {
  final l10n = AppLocalizations.of(context);
  final content = helpContentOf(l10n, topic);
  final text = Theme.of(context).textTheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, size: 18, color: text.titleMedium?.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(content.title,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content.body, style: text.bodyMedium?.copyWith(height: 1.7)),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: Text(l10n.helpSheetClose),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 问号圆点。**放在标签之后**（放前面会挤窄主操作热区，且一排问号本身就是新噪声）。
class HelpDot extends StatelessWidget {
  const HelpDot({super.key, required this.topic, this.color, this.size = 16});

  final HelpTopic topic;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: l10n.helpDotTooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(size),
        onTap: () => showHelpSheet(context, topic),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.withValues(alpha: 0.65), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              '?',
              style: TextStyle(fontSize: size * 0.68, height: 1.0, color: c),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「标题 + 问号」：省掉每处手写 Row 间距。
class HelpTitle extends StatelessWidget {
  const HelpTitle({
    super.key,
    required this.text,
    required this.topic,
    this.style,
    this.color,
    this.trailing,
  });

  final String text;
  final HelpTopic topic;
  final TextStyle? style;
  final Color? color;

  /// 问号之后还想放的东西（如计数徽标）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Text(text, style: style, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 4),
        HelpDot(topic: topic, color: color),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ],
    );
  }
}

/// 页面级问号：整页玩法说明放一个，胜过每个按钮各挂一个。
class HelpAction extends StatelessWidget {
  const HelpAction({super.key, required this.topic, this.color});

  final HelpTopic topic;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: Icon(Icons.help_outline, color: color),
      tooltip: l10n.helpDotTooltip,
      onPressed: () => showHelpSheet(context, topic),
    );
  }
}
