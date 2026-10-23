/// 试用配置的**纯逻辑与单一事实源**（零 Flutter 依赖）。
///
/// ★★ 0.82.0 新增。为什么单独成文件：
///   ① **单一事实源**：试用四件套的键名、端点拼接（`<hub>/api/trial`）、
///      "主人改了自己的 Key 该不该切自有"的判定、"切了要不要纠正端点"的规则
///      —— 此前都散在 `trial_client.dart` 的静态成员里；而**写入规则一度只活在
///      引导页**（`_saveSettings` 无条件覆盖、却不写 `llm_mode`），正是真机
///      401 `trial_agent_required` **死循环**的根因之一。抽到一处，两页共用。
///   ② **可被 `dart run` 直接执行**：本文件**不 import 任何 Flutter 包** ⇒
///      在本机环境（宿主向 `flutter_tester` 注入 DLL、剥掉 `Upgrade` 逐跳头
///      导致 `flutter test` 全部测试 loading 期假挂）下，仍可用
///      `dart run tool/verify_trial_switch.dart` **真跑**这些纯函数断言
///      （承纪律「结论必须能指到一次实测」）。
///
/// ★ `trial_client.dart` 保留同名 `static` 转发 ⇒ 对外 API 不变。
library;

abstract final class TrialConfig {
  /// 试用开关键：`trial` / `own`。
  static const String modeKey = 'llm_mode';

  static const String trialModeValue = 'trial';

  /// 试用配置四件套里另外三个（与 `modeKey` 一起构成完整配置）。
  static const String baseUrlKey = 'base_url';
  static const String apiKeyKey = 'api_key';
  static const String modelNameKey = 'model_name';

  /// 试用模式下的模型名占位（服务端按池内账号决定真实模型，客户端发什么都不算数）。
  static const String trialModelName = 'trial';

  /// 自有 Key 模式下的端点回落值（切模式下 `base_url` 仍指向 `/api/trial` 时用）。
  static const String defaultOwnBaseUrl = 'https://api.deepseek.com';

  /// 官方代调端点 = `<hub>/api/trial`（拼接规则**只此一处**）。
  static String trialApiBase(String hub) {
    final h = hub.endsWith('/') ? hub : '$hub/';
    return '${h}api/trial';
  }

  /// 判定：本次保存是否命中"主人改了自己的 Key ⇒ 该把试用切成自有模式"。
  ///
  /// 三条判据（都是**必须**的，缺一条就会把试用配置误伤成废配置）：
  ///   ① 当前**是**试用模式（否则与本次改动无关）；
  ///   ② 新 Key **非空** —— ★ 清空 ≠ 改 Key：一次误清空若被当成"换 Key"，
  ///      会把试用身份连同模式一起毁掉（这正是事故的另一种形态）；
  ///   ③ 新 Key 与当前值**不同**（这就是"改了"）。
  static bool shouldSwitchToOwn({
    required String? currentMode,
    required String previousKey,
    required String newKey,
  }) {
    if (currentMode != trialModeValue) return false;
    final k = newKey.trim();
    if (k.isEmpty) return false;
    return k != previousKey.trim();
  }

  /// 切自有模式时**必须**一起纠正端点：仍指向 `/api/trial` 就改成直连默认值
  /// （否则 own 模式带着自己的 Key 打试用端点 ⇒ 还是 401，等于没切）。
  /// 返回 `null` = 无需改动。
  static String? ownBaseUrlFix(String baseUrl, {String? fallback}) {
    if (!baseUrl.contains('/api/trial')) return null;
    return fallback ?? defaultOwnBaseUrl;
  }
}
