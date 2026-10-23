import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

/// 主题配置（类型安全，替代原先 List 混存 Color 与 ThemeMode）
class ThemeConfig {
  const ThemeConfig({
    required this.key,
    required this.start,
    required this.end,
    required this.mode,
    required this.accent,
  });

  final String key;
  final Color start;
  final Color end;
  final ThemeMode mode;
  final Color accent;
}

/// 9 种全局主题配置
///
/// key 是**语言中立的稳定 ID**，会落库到 SharedPreferences 的 `app_theme`；
/// 显示名称按当前语言在 [themeLabel] 里解析——不把语言写进持久化数据。
const Map<String, ThemeConfig> THEMES = {
  'red': ThemeConfig(key: 'red', start: Color(0xFFff758c), end: Color(0xFFff7eb3), mode: ThemeMode.light, accent: Color(0xFFd81b60)),
  'orange': ThemeConfig(key: 'orange', start: Color(0xFFf6d365), end: Color(0xFFfda085), mode: ThemeMode.light, accent: Color(0xFFe65100)),
  'yellow': ThemeConfig(key: 'yellow', start: Color(0xFFfff9db), end: Color(0xFFfff3bf), mode: ThemeMode.light, accent: Color(0xFFf57f17)),
  'green': ThemeConfig(key: 'green', start: Color(0xFFa8edea), end: Color(0xFFfed6e3), mode: ThemeMode.light, accent: Color(0xFF2e7d32)),
  'cyan': ThemeConfig(key: 'cyan', start: Color(0xFFe0c3fc), end: Color(0xFF8ec5fc), mode: ThemeMode.light, accent: Color(0xFF651fff)),
  'blue': ThemeConfig(key: 'blue', start: Color(0xFF0f172a), end: Color(0xFF1e1b4b), mode: ThemeMode.dark, accent: Color(0xFF29b6f6)),
  'purple': ThemeConfig(key: 'purple', start: Color(0xFF3b2667), end: Color(0xFFbc78ec), mode: ThemeMode.dark, accent: Color(0xFFe040fb)),
  'white': ThemeConfig(key: 'white', start: Color(0xFFf5f7fa), end: Color(0xFFc3cfe2), mode: ThemeMode.light, accent: Color(0xFF37474f)),
  'black': ThemeConfig(key: 'black', start: Color(0xFF141e30), end: Color(0xFF243b55), mode: ThemeMode.dark, accent: Color(0xFF00e5ff)),
};

/// 遗留主题 ID 迁移表。
///
/// 早期版本直接把中文色名当 ID 落库；读取时做一次归一化并顺手回写，
/// 保证老用户已选的主题不丢（这一层是**数据兼容**，不是 UI 文案）。
const Map<String, String> legacyThemeIds = {
  '红': 'red',
  '橙': 'orange',
  '黄': 'yellow',
  '绿': 'green',
  '青': 'cyan',
  '蓝': 'blue',
  '紫': 'purple',
  '白': 'white',
  '黑': 'black',
  // ★★★ 0.80.0：**等价别名**。真机复现：主人说「改成粉色主题」，而色板里根本没
  //   "粉" ⇒ 模型传来的值落不了地（旧实现还**谎报"已改好"**，见
  //   `agent_service.dart` 的 change_system_settings）。red 主题的渐变本就是
  //   粉调（#ff758c → #ff7eb3），故把"粉 / 粉色 / pink / rose"**显式**归一到
  //   red —— 不给"静默近似"，工具层会**照实回报**归一到了哪一色。
  '粉': 'red',
  '粉色': 'red',
  'pink': 'red',
  'rose': 'red',
};

/// 任意色名 → **稳定主题 key**；**认不出返回 null**。
///
/// 调用方据此可以"要么真改、要么明说"，**不允许静默忽略**（0.80.0 红线）。
/// 判据只有这一份：`ThemeProvider.setTheme` / `loadTheme` / `change_system_settings`
/// 三处共用同一张 `legacyThemeIds` 表，禁止工具层另写一套。
String? themeKeyOrNull(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final lower = t.toLowerCase();
  final normalized = legacyThemeIds[t] ?? legacyThemeIds[lower] ?? lower;
  return THEMES.containsKey(normalized) ? normalized : null;
}

/// 色板里所有**稳定 key**（供错误文案列举可选值）。
List<String> get themeKeys => THEMES.keys.toList(growable: false);

/// 主题显示名（按当前语言）
String themeLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'red':
      return l10n.themeRed;
    case 'orange':
      return l10n.themeOrange;
    case 'yellow':
      return l10n.themeYellow;
    case 'green':
      return l10n.themeGreen;
    case 'cyan':
      return l10n.themeCyan;
    case 'blue':
      return l10n.themeBlue;
    case 'purple':
      return l10n.themePurple;
    case 'white':
      return l10n.themeWhite;
    case 'black':
      return l10n.themeBlack;
    default:
      return key;
  }
}

class ThemeProvider with ChangeNotifier {
  String _currentThemeKey = 'cyan';

  String get currentThemeKey => _currentThemeKey;

  ThemeConfig get config => THEMES[_currentThemeKey] ?? THEMES['cyan']!;

  Color get colorStart => config.start;
  Color get colorEnd => config.end;
  ThemeMode get themeMode => config.mode;
  Color get accentColor => config.accent;
  bool get isDark => config.mode == ThemeMode.dark;

  /// 从持久化恢复主题（统一入口，避免与 main() 重复加载）
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme');
    if (saved == null) return;
    // 认不出（含历史脏值）⇒ 保持当前主题，不崩；认得出则归一化并顺手回写
    final normalized = themeKeyOrNull(saved);
    if (normalized == null) return;
    _currentThemeKey = normalized;
    // 老版本的中文 ID / 等价别名顺手升级成语言中立 ID
    if (normalized != saved) await prefs.setString('app_theme', normalized);
    notifyListeners();
  }

  Future<void> setTheme(String themeName) async {
    // 单一判据（含"粉→red"等别名）：认不出则**不动**（调用方须自行校验并明说）
    final normalized = themeKeyOrNull(themeName);
    if (normalized == null) return;
    _currentThemeKey = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', normalized);
  }

  BoxDecoration get backgroundDecoration {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colorStart, colorEnd],
      ),
    );
  }
}
