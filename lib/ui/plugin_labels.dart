import '../core/plugin_bus.dart';
import '../l10n/app_localizations.dart';

/// ============================================================
/// 插件总线「码 → 展示文案」的唯一翻译点。
///
/// 核心层（`core/plugin_bus.dart`）只保留语言无关的**码**：
/// 能力码会被写进签名载荷 `PluginMeta.canonical()`，风险码决定授权档位——
/// 它们都是数据，改动即等于改签名/改行为，因此文案一律不在核心层拼装。
/// UI 侧统一走本文件，杜绝同一份中文在多处各写一份。
/// ============================================================

/// 能力码（`PluginCapability.*`）→ 展示文案
String capabilityLabel(AppLocalizations l10n, String cap) {
  switch (cap) {
    case PluginCapability.network:
      return l10n.capNetwork;
    case PluginCapability.launchApp:
      return l10n.capLaunchApp;
    case PluginCapability.device:
      return l10n.capDevice;
    case PluginCapability.screenControl:
      return l10n.capScreenControl;
    case PluginCapability.notification:
      return l10n.capNotification;
    case PluginCapability.memory:
      return l10n.capMemory;
    case PluginCapability.settings:
      return l10n.capSettings;
    case PluginCapability.social:
      return l10n.capSocial;
    case PluginCapability.local:
      return l10n.capLocal;
    default:
      return cap;
  }
}

/// 风险码（`PluginRisk.*`）→ 展示文案
String riskLabel(AppLocalizations l10n, String risk) {
  switch (risk) {
    case PluginRisk.high:
      return l10n.riskHigh;
    case PluginRisk.medium:
      return l10n.riskMedium;
    default:
      return l10n.riskLow;
  }
}
