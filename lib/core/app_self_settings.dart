/// ============================================================
/// App 自操作设置的**纯逻辑**（零 Flutter 依赖）
///
/// 存在理由（0.85.0）：主人要求"智能体必须能自我操作我们的 App"。
/// `change_system_settings` 因此扩到"App 自操作面"，其中两段**取值归一**是可判定的
/// 纯函数 —— 但工具 handler 本身依赖 `SharedPreferences` / Flutter，**跑不了单测**。
/// 于是把这两段抽到这里（不 import dart:ui / shared_preferences），
/// 由 `tool/verify_app_self_plane.dart` 用 `dart run` **真跑**行为断言。
///
/// ★ 两段都遵守"认不出 ⇒ 返回 null，**绝不**静默当默认值"（本仓「静默失败」红线）。
/// ============================================================
library;

/// 宽松布尔解析：`true/on/开/打开/yes/1` → true；`false/off/关/关闭/no/0` → false。
/// 认不出（null / 其它串 / 其它类型）→ **null**（调用方必须显形，不许当默认值）。
bool? parseSettingBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (const ['true', 'on', '开', '打开', 'yes', '1'].contains(s)) return true;
    if (const ['false', 'off', '关', '关闭', 'no', '0'].contains(s)) return false;
  }
  return null;
}

/// 界面语言归一：语言码 / **自称**（endonym）/ 常见别名 → 语言码。
/// 返回值一定落在 `LanguageController.selectableCodes` 集合内；**认不出 → null**。
///
/// ★ 收自称是刻意的：一个只会中文的用户在英文界面下，说的往往是"简体中文"而不是 `zh`。
String? resolveLanguageCode(Object? raw) {
  if (raw == null) return null;
  final s = raw.toString().trim().toLowerCase();
  const map = <String, String>{
    // 跟随系统
    'system': 'system', '跟随系统': 'system', 'auto': 'system', '自动': 'system',
    // 简体
    'zh': 'zh', 'zh_cn': 'zh', 'zh-cn': 'zh', 'zh-hans': 'zh',
    '简体中文': 'zh', '简体': 'zh', '中文': 'zh',
    // 繁体
    'zh_hant': 'zh_Hant', 'zh-hant': 'zh_Hant', 'zh_tw': 'zh_Hant', 'zh-tw': 'zh_Hant',
    '繁體中文': 'zh_Hant', '繁体中文': 'zh_Hant', '繁體': 'zh_Hant', '繁体': 'zh_Hant',
    // 英 / 日 / 越
    'en': 'en', 'english': 'en', '英文': 'en', '英语': 'en',
    'ja': 'ja', 'jp': 'ja', 'japanese': 'ja', '日本語': 'ja', '日语': 'ja',
    'vi': 'vi', 'vietnamese': 'vi', 'tiếng việt': 'vi', '越南语': 'vi',
  };
  return map[s];
}

/// 页面键归一：把主人 / 模型给的说法（大小写、空白、连字符、中文别名）折成
/// **注册表里的规范键**。
///
/// ★ `knownKeys` 由调用方从**注册表**传入（`appPageKeys`）—— 本函数**不持有**页面清单，
///   从而保证"能打开的页面"只有注册表一个事实源。
/// ★ 认不出，**或别名指向的键不在 `knownKeys` 里** ⇒ 返回 **null**（调用方必须显形，不许猜）。
String? resolveAppPageKey(Object? raw, Iterable<String> knownKeys) {
  if (raw == null) return null;
  final s = raw
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  final known = knownKeys.toSet();
  if (known.contains(s)) return s;
  const alias = <String, String>{
    'setting': 'settings', '设置': 'settings', '设置中心': 'settings',
    'advanced': 'advanced_settings', 'advanced_setting': 'advanced_settings',
    '进阶设置': 'advanced_settings', '高级设置': 'advanced_settings',
    '身份证': 'passport', '护照': 'passport', '身份卡': 'passport',
    '备份': 'identity_backup', '身份备份': 'identity_backup',
    '换机': 'device_migration', '迁移': 'device_migration', '换设备': 'device_migration',
    '邮箱': 'mail', '邮件': 'mail', 'mail_account': 'mail',
    '手机控制': 'phone_control', '无障碍': 'phone_control', '设备控制': 'phone_control',
    '通知': 'notify_sms', '短信': 'notify_sms', '通知短信': 'notify_sms', '通知与短信': 'notify_sms',
    '记忆': 'memory', '记忆管理': 'memory',
    '自检': 'diagnostics', '诊断': 'diagnostics', '系统自检': 'diagnostics',
    '工具': 'tools', '工具列表': 'tools', '工具中心': 'tools',
    '技能': 'skill_market', '技能市场': 'skill_market',
    '个人资料': 'profile', '资料': 'profile',
    // ★ 刻意**没有**「待确认 / 建议 / 待办」这三条别名：它们指向审批页
    //   `pending_suggestions`，而该页带 0.61.0「唯一入口」红线、**不进注册表**
    //   （见 `lib/ui/app_pages.dart` 头注）⇒ 别名指向未注册的键只会返回 null，
    //   留着即是死别名（`verify_app_navigation` ⑤ 也会红）。
    '话题': 'topics', '聊天记录': 'topics',
    '术语': 'glossary', '术语速查': 'glossary',
    '周报': 'weekly_report', '周报页': 'weekly_report',
  };
  final t = alias[s];
  if (t != null && known.contains(t)) return t;
  return null;
}
