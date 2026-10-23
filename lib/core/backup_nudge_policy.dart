/// 备份补课（backup nudge）的判定策略 —— 从 `_RootGate` 抽出来纯化，
/// 让"谁该被提醒"可以被单测钉死，而不是埋在 Widget 生命周期里。
///
/// 背景：`_RootGate` 对"已配置过 API Key 的老用户"整体跳过引导
///（`onboarding_done ?? alreadyConfigured`），而"备份成为必经"只写在
/// 引导流程里。结果：**他自己手机上的第一批用户可能永远没有恢复码**——
/// 手机一坏，身份、声望、公示历史全部归零。本策略补上这个洞。
///
/// 触发条件（全部满足才提醒）：
/// 1. 引导已走完或已被老用户跳过（不用管引导本身）；
/// 2. **当前钥未备份**（`AgentIdentity.isBackedUp` 按公钥比对——换钥后
///    自动复位为未备份，天然重新纳入提醒，不需要清理代码）；
/// 3. 不在免打扰期（用户点"以后再说" → snooze 3 天，不弹窗轰炸）。
///
/// 免打扰设计说明：不设"永久不再提醒"——备份是身份的生死线，只有
/// "备份完成"（isBackedUp 恒真）才是真正的出口。
library;

import 'package:shared_preferences/shared_preferences.dart';

abstract final class BackupNudgePolicy {
  /// 冷启动是否应展示备份补课屏。
  ///
  /// [isBackedUpFn] 可注入（测试桩）；生产默认由调用方传入
  /// `AgentIdentity().isBackedUp`——本层不 import 身份实现，
  /// 保持纯策略（身份不可用时调用方应 catch 并跳过提醒）。
  static Future<bool> shouldShow(
    SharedPreferences prefs, {
    required Future<bool> Function() isBackedUpFn,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final snoozeUntil = prefs.getInt(snoozeKey) ?? 0;
    if (snoozeUntil > current.millisecondsSinceEpoch) return false;
    return !(await isBackedUpFn());
  }

  /// 用户点了"以后再说"：免打扰 [duration]（默认 3 天）。
  static Future<void> snooze(
    SharedPreferences prefs, {
    Duration duration = const Duration(days: 3),
    DateTime? now,
  }) async {
    final current = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await prefs.setInt(snoozeKey, current + duration.inMilliseconds);
  }

  /// 备份完成后清除免打扰（红标由 isBackedUp 恒真接管，键位顺手清干净）。
  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(snoozeKey);
  }

  static const String snoozeKey = 'backup_nudge_snoozed_until_ms';
}
