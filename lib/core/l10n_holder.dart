import 'dart:ui' show Locale;

import '../l10n/app_localizations.dart';
import 'language_controller.dart';

/// ============================================================
/// 全局本地化句柄（L10nHolder）
///
/// 为什么需要它：大量**用户可见**文案是在 core 层拼好的——权限弹窗描述、
/// 工具回执、状态卡片的一句话……这些地方没有 `BuildContext`，
/// 拿不到 `AppLocalizations.of(context)`。
///
/// 两种解法：
///   ① 把 l10n 注入 core（本类）：UI 层每次 build 把当前语言放进来，core 取用；
///   ② core 只返回**语言无关的原因码**，由 UI 层负责翻译（更纯，但要改所有签名）。
///
/// 本工程选 ①：改动面小、立即可用，且 `AppLocalizations` 本身不是 UI 组件
/// （只是一个生成出来的纯 Dart 类），不违反 core 层不 import ui 的约定。
///
/// 用法：
///   core 层   → L10nHolder.l10n.xxx（永远非空；UI 未起时按 [LanguageController]
///               的当前语言解析 —— 用户在 App 里选的语言，或「跟随系统」的归并结果）
///   UI 层     → 在 MaterialApp.builder 里 install()，语言切换时自动刷新
///
/// 注意：语言无关的内容**不要**走这里——模型提示词、落库的审计详情、
/// 工具的描述字段都保持原样，避免把语言写进持久化数据或喂给模型。
/// ============================================================
class L10nHolder {
  L10nHolder._();

  static AppLocalizations? _current;

  /// UI 层注入当前语言（MaterialApp.builder 里调用，语言切换时会重跑）
  static void install(AppLocalizations l10n) {
    _current = l10n;
  }

  /// core 层取用。**三级解析**（绝不抛异常）：
  ///   ① UI 已注入 → 用它（跟随用户在 App 里看到的语言）；
  ///   ② UI 还没起（后台任务：workmanager 唤醒的雷达 / 造梦）→ 交给
  ///      [LanguageController]（它已从 SharedPreferences 恢复过用户选择，
  ///      「跟随系统」的方言归并也在那里做）；
  ///   ③ 都不成 → 用 `supportedLocales.first`。
  ///
  /// ⚠️ **为什么不能"未安装就硬回退英文"**：语言选择持久化之前，本类只能读系统
  /// 语言；若那一步再退化成英文，中文机器上的后台任务就会把雷达 / 通知文案发成
  /// **英文** —— 比不本地化更糟（用户看到的一半中文一半英文）。
  /// 0.55.0 起回落读的是 [LanguageController]，与用户显式选择一致。
  static AppLocalizations get l10n {
    final installed = _current;
    if (installed != null) return installed;
    return lookupAppLocalizations(_fallbackLocale());
  }

  /// 兜底 Locale：交给语言控制器（单一事实源），**不再自己比 languageCode**。
  ///
  /// ⚠️ 旧实现只比 `languageCode`，于是 zh-TW 会被匹成 `zh`（简体）——
  /// 繁体用户拿到简体界面。方言归并只有 [LanguageController] 一处，别处不许再写。
  static Locale _fallbackLocale() {
    try {
      return LanguageController.i.locale;
    } catch (_) {
      // 某些纯 Dart 宿主（CLI / 部分测试环境）连 SharedPreferences 通道都没有
    }
    return AppLocalizations.supportedLocales.first;
  }
}
