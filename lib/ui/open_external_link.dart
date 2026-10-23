import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 打开一个**外部链接**，并把「打不开」变成**看得见的失败**。
///
/// 为什么单独抽一份实现：本仓已有多处外链入口（设置页的两份法务文档、
/// ADR-002 准入闸的「申请访问 Key」）。`launchUrl` 返回 `false` 或抛异常时
/// 若不上屏，用户点了**没反应** —— 那正是本仓反复警惕的**静默失败**。
/// 两处一旦分叉，症状就是"某个链接点得动、另一个点了像没接线"，而这种
/// 漂移在界面上极难看出是同一件事。
///
/// ★ `messenger` / `l10n` 都在 `await` **之前**从 `context` 取好，避免
///   `use_build_context_synchronously`；`await` 之后再查一次 `mounted`，
///   免得往已经走掉的页面 messenger 上贴 SnackBar。
Future<void> openExternalLink(
  BuildContext context,
  String url, {
  required String failureText,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(failureText)));
  }
}
