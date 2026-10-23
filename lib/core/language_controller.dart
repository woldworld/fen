import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// ============================================================
/// 界面语言单一事实源（LanguageController）
///
/// 存在理由：0.55.0 之前 App **没有语言选择**，只有跟随系统一条路。
///   ① `MaterialApp` 没给 `locale:`，于是用户选不了语言；
///   ② `L10nHolder._systemLocale()` 只比 `languageCode`，
///      繁体机器（zh-TW）会被解析成 `zh` ⇒ 简体 —— 繁体用户拿到简体界面；
///   ③ 后台 isolate 更彻底：连"系统语言"都读的是自己那份。
///
/// 本类的三条纪律：
///   ① **落库只存语言码**（`system`/`zh`/`zh_Hant`/`en`/`ja`/`vi`），
///      不存显示名 —— 显示名随界面语言变，写进库就会僵死（同主题 ID 的教训）。
///   ② **'system' 在这里就折成具体语种**，`MaterialApp.locale` 永不为 null。
///      不把歧义留给 Flutter 的 locale 解析：它会把 zh-TW 折成 zh（简体），
///      正是本轮要修的病。
///   ③ **后台 isolate 必须再 load 一次**（`LanguageController.i.load()`）——
///      内存态不跨 isolate 继承，与通知旁听器同一纪律。
/// ============================================================
class LanguageController with ChangeNotifier {
  LanguageController._();

  static final LanguageController i = LanguageController._();

  /// 持久化键。值 = 语言码（不是显示名）。
  static const String prefKey = 'app_language';

  /// 「跟随系统」——本身不是语种，是一个**解析策略**。
  static const String followSystem = 'system';

  /// 可选项（顺序 = 语言选择器的展示顺序）。
  /// 非 `system` 的每一项都**必须与 ARB 文件名一一对应**：
  ///   zh → app_zh.arb ／ zh_Hant → app_zh_Hant.arb ／ en → app_en.arb ／ …
  /// 这条对应关系由 `tool/verify_i18n.dart` 钉死（文件名错一个下划线就编译不过）。
  static const List<String> selectableCodes = <String>[
    followSystem,
    'zh',
    'zh_Hant',
    'en',
    'ja',
    'vi',
  ];

  /// 语种（不含 `system`）→ 该语种的**自称**。
  ///
  /// 刻意**不进 ARB**：挑语言时，如果选项被翻译成当前界面语言，
  /// 一个只会中文的用户在英文界面下就永远找不到「简体中文」在哪。
  /// 自称（endonym）是全球通行做法，且它**不随界面语言变化**。
  static const Map<String, String> endonyms = <String, String>{
    'zh': '简体中文',
    'zh_Hant': '繁體中文',
    'en': 'English',
    'ja': '日本語',
    'vi': 'Tiếng Việt',
  };

  /// ★ 送给 LLM 的回复语言指令（拼在每条**面向用户**的 system prompt 末尾）。
  ///
  /// 为什么必须显式写「无论上文用什么语言写成」：本 App 的提示词骨架、
  /// 记忆片段、工具回执**几乎全是中文**，模型会本能地跟着上文走 ——
  /// 只写"用日语回答"不够，得把"上下文语言 ≠ 输出语言"这件事挑明。
  static const Map<String, String> replyDirectives = <String, String>{
    'zh': '【回复语言】无论上文用什么语言写成，你最终都必须用「简体中文」回答用户。',
    'zh_Hant': '【回覆語言】無論上文用什麼語言寫成，你最終都必須用「繁體中文」回答使用者。',
    'en': '【Reply language】No matter what language the context above is written in, '
        'you MUST answer the user in English.',
    'ja': '【回答言語】上記のコンテキストがどの言語で書かれていても、'
        '最終的には必ず「日本語」で回答してください。',
    'vi': '【Ngôn ngữ trả lời】Bất kể ngữ cảnh ở trên được viết bằng ngôn ngữ nào, '
        'bạn PHẢI trả lời người dùng bằng tiếng Việt.',
  };

  String _code = followSystem;

  /// 用户选的语言码（可能是 `followSystem`）
  String get code => _code;

  /// 实际生效的语种码（`followSystem` 已按系统语言折成一个具体语种）
  String get effectiveCode {
    if (_code != followSystem) return _code;
    return _resolveSystem();
  }

  /// 交给 `MaterialApp.locale`。**永不为 null**、且一定是
  /// `AppLocalizations.supportedLocales` 里的**同一个实例** ——
  /// 不自己 new Locale，避免与生成代码里的 Locale 差一点（scriptCode 等）而匹配不上。
  Locale get locale {
    final wanted = effectiveCode;
    for (final l in AppLocalizations.supportedLocales) {
      if (codeOf(l) == wanted) return l;
    }
    return AppLocalizations.supportedLocales.first;
  }

  /// 当前生效的回复语言指令（语种不受支持时回落英文指令，绝不为空串）
  String get replyDirective =>
      replyDirectives[effectiveCode] ?? replyDirectives['en']!;

  /// Locale → 语言码（带 script 时拼成 `zh_Hant`，与 ARB 文件名同构）
  static String codeOf(Locale l) {
    final script = l.scriptCode;
    if (script != null && script.isNotEmpty) return '${l.languageCode}_$script';
    return l.languageCode;
  }

  /// 「跟随系统」的解析：zh-TW/HK/MO → 繁体，其余 zh → 简体，
  /// 命中受支持语种直接用，都不命中 → 英文。
  ///
  /// ⚠️ 只在这里做一次方言归并，别处不要再各写一份判定。
  static String _resolveSystem() {
    try {
      final sys = PlatformDispatcher.instance.locale;
      final lang = sys.languageCode.toLowerCase();
      if (lang == 'zh') {
        final country = (sys.countryCode ?? '').toUpperCase();
        // 港澳台用繁体；大陆/新加坡/裸 zh 用简体
        if (country == 'TW' || country == 'HK' || country == 'MO') {
          return 'zh_Hant';
        }
        return 'zh';
      }
      for (final c in selectableCodes) {
        if (c != followSystem && c == lang) return c;
      }
    } catch (_) {
      // 纯 Dart 宿主（部分测试环境）没有 PlatformDispatcher
    }
    return 'en';
  }

  /// 从持久化恢复（主 isolate 与**后台 isolate 都要调一次**）
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKey);
      if (saved != null && selectableCodes.contains(saved)) _code = saved;
    } catch (_) {
      // 读不到就用默认（跟随系统）——语言选择失败不该挡住任何流程
    }
    notifyListeners();
  }

  /// 切换语言：先改内存 + 通知 UI，再落库（落库失败不影响本次生效）
  Future<void> setCode(String code) async {
    if (!selectableCodes.contains(code)) return;
    if (_code == code) return;
    _code = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, code);
    } catch (_) {
      // 持久化失败只意味着"下次启动回到跟随系统"，不回滚当前生效值
    }
  }

  /// 测试用：不碰 SharedPreferences 直接改内存值
  static void debugSetForTest(String code) {
    if (!selectableCodes.contains(code)) return;
    i._code = code;
    i.notifyListeners();
  }
}

/// ============================================================
/// 两个提示词包装器（**所有** system prompt 必须二选一，不许裸传）
///
/// 为什么是"二选一"而不是"统一加"：有一类提示词的产出**不是给人看的**
/// —— 安全网关的 ALLOW/DENY、对话摘要器的摘要、结构化 JSON……
/// 给它们加"用日语回答"会直接把机器解析搞坏。
/// 于是：`llmSystem` = 面向用户，加语言指令；
///        `machineSystem` = 面向机器，**刻意不加**，并在调用处写明原因。
/// 守卫 `tool/verify_llm_language.dart` 钉住：裸传的一律报错。
/// ============================================================

/// 面向用户的 system prompt：末尾拼上当前回复语言指令。
String llmSystem(String body) {
  final directive = LanguageController.i.replyDirective;
  if (directive.isEmpty) return body;
  return '$body\n\n$directive';
}

/// 面向机器的 system prompt：**刻意不拼**语言指令。
///
/// 只用于产出需要被程序解析的内容（判定词 / JSON / 摘要回填）。
/// 调用处必须写一行注释说明"为什么它的产出不该被翻译"。
String machineSystem(String body) => body;
