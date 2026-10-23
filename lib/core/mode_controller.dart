import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// 界面模式单一事实源（ModeController）
///
/// 存在理由：0.61.0 之前 `simple_mode` 是**散落三处各读一遍**的裸 prefs 键 ——
///   · `onboarding_screen`（引导完成写 `true`）
///   · `settings_screen`（"完整模式"开关写 `!v`）
///   · `social_screen`（`initState` 里读一次，决定 3 签还是 5 签）
/// 三处各写各的，谁也别指望"改一处全 App 跟着变"。更糟的是：**社交页只在
/// `initState` 读一次**，用户在任何别处改了模式，社交页也不会重建 —— 这就是
/// "模式开关像没生效"的根。
///
/// 本类的三条纪律（刻意与 `LanguageController` 同构，便于统一心智模型）：
///   ① **落库只存布尔**（`simple_mode`），不存模式的显示名 —— 显示名随界面
///      语言变，写进库就会僵死（同主题 ID / 语言显示名的教训）。
///   ② **内存态即真相**：谁要读模式就读 `ModeController.i.simpleMode`，不再
///      自己去 `SharedPreferences` 翻键。落库只是"下次冷启动能恢复"，不是读源。
///   ③ **写入必 `notifyListeners()`**：顶栏切换后，社交页 / 管理页 / 控制中心
///      都在监听本控制器，一次通知全部重建 —— 这正是修掉"改了不生效"的机关。
///
/// ⚠️ 跨 isolate：本值**不进后台 isolate**（后台心跳/造梦不读模式），故无需像
///    语言那样在 `callbackDispatcher` 里再 `load()` 一次。若将来后台代码要读，
///    必须补一次 `ModeController.i.load()`（见 R10/R11 纪律）。
/// ============================================================
class ModeController with ChangeNotifier {
  ModeController._();

  static final ModeController i = ModeController._();

  /// 持久化键。值 = 布尔（`true` = 入门模式，`false` = 进阶模式）。
  ///
  /// ★ 键名沿用历史 `simple_mode`，**刻意不改名**：老用户库里已有该键，
  ///   改名等于让全部存量用户"模式丢失、回落默认"。键值语义也不变
  ///   （`true` = 少显示进阶功能），所以是零迁移成本的升级。
  ///
  /// ★★ **常量名刻意**不叫 `prefKey`（尽管那是本仓既有惯例）：`tool/verify_data_keys.dart`
  ///   的键解析建的是**全局**「常量名 → 字面量」表，**同名即歧义 ⇒ 两处都被降级成
  ///   "动态键"**（它只能报"新增了未登记的动态键"，看不出真实原因是重名）。
  ///   `LanguageController` 已占用 `prefKey` ⇒ 这里必须换个唯一名，否则那条守卫会
  ///   被永久蒙住（对 `prefKey` 的解析将再不可用）。**新键常量一律取全局唯一名。**
  static const String modePrefKey = 'simple_mode';

  bool _simpleMode = false;

  /// `true` = 入门模式（小白向，收起进阶页签与参数）；
  /// `false` = 进阶模式（显示全部页签与参数）。
  ///
  /// ★ 默认 `false`（进阶）**不是**新装用户的默认 —— 新装默认在引导完成时由
  ///   `OnboardingScreen` 显式写 `true`（首批用户方案 §三）。这里的 `false` 只是
  ///   "键不存在时的兜底"，服务的是**老用户升级**（无该键 ⇒ 保持进阶、零感知）。
  bool get simpleMode => _simpleMode;

  /// 从持久化恢复（冷启动一次；键不存在 ⇒ 保持默认进阶）。
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _simpleMode = prefs.getBool(modePrefKey) ?? false;
    } catch (_) {
      // 读不到就用默认 —— 模式读取失败绝不该挡住任何流程
    }
    notifyListeners();
  }

  /// 切换模式：先改内存 + 通知 UI，再落库（落库失败不影响本次生效，
  /// 只意味着"下次冷启动回到上一次的模式"）。
  Future<void> setSimpleMode(bool value) async {
    if (_simpleMode == value) return;
    _simpleMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(modePrefKey, value);
    } catch (_) {
      // 持久化失败不回滚当前生效值（与 LanguageController 同策略）
    }
  }

  /// 测试用：不碰 SharedPreferences 直接改内存值
  static void debugSetForTest(bool value) {
    i._simpleMode = value;
    i.notifyListeners();
  }
}
