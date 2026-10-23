/// ============================================================
/// App 内页面注册表 + 导航（0.86.0）
///
/// 缘起：主人要求「用户一句话，主智能体都能帮用户搞定」。除了改设置
/// （`change_system_settings`），助手还应当**替主人打开 App 内的页面**：
/// 「帮我打开设置 / 邮箱 / 工具页」。
///
/// ★★ 两条纪律（本文件存在的理由）：
///   ① **白名单必须与真实页面同源** —— 页面清单**不在这里手写**，而由 UI 层
///      （`lib/ui/app_pages.dart`）在启动时**注册**进来。本文件只持有"已注册的表"，
///      因此 `open_app_page` 工具**不可能**打开一个不存在的页面，UI 新增页面
///      也不会漏登记（漏了只是"打不开"，不会"打开错的"）。
///   ② **core 不 import ui** —— 依赖方向反转为"UI 注入 core"，与本仓既有的
///      `AppEvents` / `PluginBus` 同款惯例（core 层之间不互相 import，避免成环）。
///
/// 本文件**不 import 任何 ui/**，只依赖 flutter 的 `GlobalKey / Navigator / MaterialPageRoute`。
/// ============================================================
import 'package:flutter/material.dart';

/// 全局导航键：`MaterialApp.navigatorKey` 用它，工具也从它拿 state。
/// ★ 与 `lib/main.dart` 的 `_FenAppState.navigatorKey` 是**同一个实例**
///   （后者直接引用本变量）⇒ "从工具里 push" 与 "从 UI 里 push" 落在同一个栈上。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 一个"可被智能体打开的 App 内页面"。
class AppPage {
  /// 稳定键（英文小写下划线）：唯一对模型可见的标识，也是工具参数取值。
  final String key;

  /// 人话标签（英文，KB 同款口径）：用于回报与工具描述，**不本地化**（KB 是英文单一源）。
  final String label;

  /// 页面构造器。★ **必须是无参可构造**的页面 —— 需要参数的页面不入表。
  final WidgetBuilder builder;

  const AppPage({required this.key, required this.label, required this.builder});
}

final Map<String, AppPage> _pages = <String, AppPage>{};

/// UI 层启动时调用一次，把**真实页面**注册进来。
/// 重复键**覆盖**（幂等，可安全重入 —— 热重载 / 二次调用不会翻倍）。
void registerAppPages(List<AppPage> pages) {
  for (final p in pages) {
    _pages[p.key] = p;
  }
}

/// 已注册页面的键，顺序 = 注册顺序（供工具描述与校验使用）。
/// ★ 只读快照（`growable: false`）：外部拿到的列表改不动内部注册表。
List<String> get appPageKeys => _pages.keys.toList(growable: false);

bool hasAppPage(String key) => _pages.containsKey(key);

String? appPageLabel(String key) => _pages[key]?.label;

/// 打开页面。
///
/// 返回 **null = 成功**（已压栈）；非 null = **失败原因**（人话，可直接回灌模型）。
/// ★ fail-closed：拿不到导航栈时**如实回报**，绝不假装"已打开"（本仓「拒绝假成功」红线）。
String? openAppPage(String key) {
  final page = _pages[key];
  if (page == null) {
    return 'unknown page "$key"';
  }
  final nav = appNavigatorKey.currentState;
  if (nav == null) {
    return 'no UI available right now';
  }
  nav.push(MaterialPageRoute(builder: page.builder));
  return null;
}

/// ★★ 0.107.0：「隐私能力页」—— 与 KB `agent_boundary` 点名的三类**逐一对应**
///   （email / phone control / notification & SMS reading）。
///
/// 共同点：**主人不亲手开，智能体就永远没有这个能力** —— 相关的工具**压根不注册**
///   （三道总开关，默认全关）：
///     · `mail`          → `MailSwitch`（`mail/mail_switch.dart`，键 `mail_enabled`）
///     · `phone_control` → `DeviceControlService.enabledPref`
///     · `notify_sms`    → `NotificationSmsService.notifySmsEnabledPref`
///
/// ★ 键**就是**注册表里的键（即 `buildAppPages()` 注册的那张表），**不是另抄一份
///   名单**；"每个键都真在注册表里"由 `tool/verify_app_navigation.dart` 判据⑨
///   **反向**钉住（抄错/页面改名 ⇒ 当场判出）。
const Map<String, String> privacyCapabilityPages = <String, String>{
  'mail': '邮箱',
  'phone_control': '手机控制',
  'notify_sms': '通知与短信读取',
};

/// 生成隐私能力页导航回执的**事实附注**（0.107.0）。
///
/// 返回 `null` = 不是隐私能力页（无需附注）；非 null = 必须**原样**回灌模型的事实串。
///
/// ★★ 为什么必须有这一层（0.107.0 真机事故，主人截图反馈）：
///   主人从没配过邮箱，模型调 `open_app_page` 打开邮箱页后回报「邮箱已打开」，
///   主人读成"邮箱已配好可用了"；模型还自己加了一句
///   「之后我就能帮你读邮件、回邮件、自动处理了」—— 源码里根本没有这句。
///   根因两条：① 回执只说"页面已打开"，**没说能力没开** ⇒ 留出了脑补空间；
///   ② 系统提示词没禁止它承诺未注册的能力。
///   ⇒ 修法是**把事实从代码侧注入**：开关的真实状态由本函数在回执里写死，
///     模型不需要"想起"这件事，也就没得编（比"在提示词里求它别乱说"可靠）。
///
/// [isEnabled] 由调用方注入（入参 = 页面键）：本文件不反向依赖各能力 Service。
String? privacyCapabilityNote(String pageKey, bool Function(String key)? isEnabled) {
  final name = privacyCapabilityPages[pageKey];
  if (name == null) return null;
  final on = isEnabled?.call(pageKey) ?? false;
  return on
      ? '（事实：「$name」的总开关当前是**开**的，相关工具已挂上，我确实能用。）'
      : '（事实：「$name」的总开关当前是**关**的 —— 我**只是把这个页面推到前台**，'
          '并没有打开这个能力，现在也读不到它的任何内容。'
          '必须主人到这一页亲自开启（邮箱还要先绑好账号），我的相关工具才会出现。'
          '★ 请如实告诉主人"还没开、我现在还用不了"，'
          '**绝不要**说成已经能用，也不要承诺超出上述范围的任何能力。）';
}
