import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// 「物理雷达」的敏感权限**用途说明**流程（体检 P1-7「敏感权限用途说明」）。
///
/// ★ 为什么要有它：雷达要的是「定位 + 蓝牙 / 附近设备」这一组**敏感权限**，
///   而改前是 `P2PService._requestPermissions()` **裸弹系统框** —— 一个字都不解释
///   （证据：`lib/core/p2p_service.dart:61-101`，直接 `.request()`；全仓无任何前置说明）。
///   定位又恰是国内市场审核与用户最敏感的一项 ⇒ 按本仓既有纪律
///   （见 `duty_permission_flow.dart` 开头的「**先讲理由，再弹系统框**」）抽成这一份共用实现。
///
/// ★ 与值班权限流程的分工（两份不重叠、也不互相调用）：
///   - `duty_permission_flow.dart` 管「通知 + 电池优化」——为的是**息屏后还能醒来**；
///   - 本文件管「定位 + 蓝牙 / 附近设备」——为的是**在同一个 Wi-Fi 里互相发现**。
///
/// ★ 只在**第一次**开雷达时解释一次：每次都弹比不解释更烦人。
///   用一个 prefs 键 `radar_permission_explained` 记住"已解释过"。
/// ★ 用户点「暂不」⇒ 返回 `false`，调用方**不启动雷达**、也不弹系统框；
///   点「去授权」⇒ 返回 `true`，真正的系统框仍由 `P2PService.startPatrolling()`
///   内部的 `_requestPermissions()` 弹出（**系统框只在一处弹**，不重复申请）。
Future<bool> ensureRadarPermissions(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  // 键：radar_permission_explained（读 / 写成对，"存储键接线守卫"核对）
  if (prefs.getBool('radar_permission_explained') == true) return true;

  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.radar),
      title: Text(l10n.radarAskTitle),
      content: Text(l10n.radarAskBody),
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
  if (go != true) return false;
  // 记"已解释过"：与权限最终给没给**无关** —— 它管的是"别再重复解释"，
  // 权限状态由系统框自己反映（给了就是给了，不给下次仍会弹系统框）。
  await prefs.setBool('radar_permission_explained', true);
  return true;
}
