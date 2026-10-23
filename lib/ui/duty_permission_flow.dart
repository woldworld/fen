import 'package:flutter/material.dart';

import '../core/background_duty_service.dart';
import '../core/app_logger.dart';
import '../core/rom_guide_service.dart';
import '../l10n/app_localizations.dart';

/// 「值班权限」的共用授权流程（照抄 identity_backup_flow 的共用纪律）：
/// 社交页的巡逻开关 / 云端开关等多处入口共用这一份，理由与文案只在一处维护。
///
/// 原则：**先讲理由，再弹系统框**（裸弹系统权限框的拒绝率极高）；
/// 用户拒绝也不阻断功能——App 内一切照旧，只是退到后台可能被系统暂停。
///
/// 返回 `true` = 两项权限此刻都已就绪（本来就有或本次拿到）。
Future<bool> ensureDutyPermissions(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  if (await BackgroundDuty.dutyFullyPermitted) return true;

  // 先讲理由。用户在这里点"暂不"就到此为止——不弹任何系统框。
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.nights_stay_outlined),
      title: Text(l10n.dutyAskTitle),
      content: Text(l10n.dutyAskBody),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.dutyAskLater)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.dutyAskConfirm)),
      ],
    ),
  );
  if (go != true || !context.mounted) {
    return BackgroundDuty.dutyFullyPermitted;
  }

  // 系统框：通知 → 电池优化（后者跳系统设置页，用户可能不回来——
  // 所以 toast 口径按"部分授予"描述后果，不说死）。
  var ok = await BackgroundDuty.requestNotificationPermission();
  if (context.mounted) {
    ok = await BackgroundDuty.requestBatteryExemption() && ok;
  }
  if (context.mounted) {
    final messenger = ScaffoldMessenger.of(context);
    final msg = ok ? l10n.dutyDoneToast : l10n.dutyPartialToast;
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }
  if (!ok) {
    AppLogger.w('duty.permissions',
        'notification=${await BackgroundDuty.notificationAllowed} '
        'battery=${await BackgroundDuty.batteryExempt}');
  }
  return ok;
}

/// 「上岗引导」完整版 = 值班权限（层 1）+ ROM 自启动指引（层 2）。
/// 社交页的两个上岗时刻统一走这一份。
Future<bool> ensureDutyOnboarding(BuildContext context) async {
  final permsOk = await ensureDutyPermissions(context);
  // ROM 指引与权限结果无关——权限全给了，MIUI 照样杀后台。
  if (context.mounted) await maybeShowRomGuide(context);
  return permsOk;
}

/// 层 2：国产 ROM 自启动指引。同一厂商只强提醒一次（可"不再提醒"）。
Future<void> maybeShowRomGuide(BuildContext context) async {
  if (!context.mounted) return;
  if (!await RomGuide.shouldShowGuide()) return;
  final l10n = AppLocalizations.of(context);
  final vendor = await RomGuide.detectVendor();
  if (!context.mounted) return;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.shield_outlined),
      title: Text(l10n.romGuideTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment:
            CrossAxisAlignment.start, children: [
          Text(_vendorSteps(l10n, vendor)),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await RomGuide.markGuideDismissed();
            if (ctx.mounted) Navigator.pop(ctx, false);
          },
          child: Text(l10n.romGuideDismiss),
        ),
        FilledButton(
          onPressed: () async {
            await RomGuide.openAutoStartSettings();
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: Text(l10n.romGuideGo),
        ),
      ],
    ),
  );
  AppLogger.w('duty.romGuide', 'vendor=$vendor dismissed=${go == false}');
}

/// 厂商 → 分机型步骤文案（l10n 键选择集中在这，加厂商只改这一处）。
String _vendorSteps(AppLocalizations l10n, RomVendor vendor) {
  switch (vendor) {
    case RomVendor.xiaomi:
      return l10n.romStepsXiaomi;
    case RomVendor.huawei:
      return l10n.romStepsHuawei;
    case RomVendor.honor:
      return l10n.romStepsHonor;
    case RomVendor.oppo:
      return l10n.romStepsOppo;
    case RomVendor.oneplus:
      return l10n.romStepsOneplus;
    case RomVendor.vivo:
      return l10n.romStepsVivo;
    case RomVendor.meizu:
      return l10n.romStepsMeizu;
    case RomVendor.samsung:
      return l10n.romStepsSamsung;
    case RomVendor.generic:
      return l10n.romStepsGeneric;
  }
}
