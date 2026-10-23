// App 自操作面 —— **纯逻辑真跑**守卫（0.85.0）。
//
// 运行：dart run tool/verify_app_self_plane.dart
//
// ============================================================
// 为什么要有它
// ------------------------------------------------------------
// 主人要求「智能体必须能自我操作我们的 App」：主题 / 语言 / 语音 / 雷达三通道
// 这类"改配置"的操作，主人一句话，主智能体就该替他办了。
// 这些取值归一逻辑（宽松布尔、语言别名）原本内联在 `change_system_settings`
// 的 handler 里 —— 而那个 handler 依赖 `SharedPreferences` / Flutter，
// 本机跑不了单测（WMI 被封，`flutter test` 起不来）。
//
// 于是把两段**可判定的纯函数**抽到零依赖的
//   `lib/core/app_self_settings.dart`
// 由本脚本用 `dart run` **真跑**行为断言（不是扫源码）。
//
// ★ 核心红线：两段都遵守「认不出 ⇒ 返回 null，**绝不**静默当默认值」。
//   若哪天有人图省事把它改成"认不出就返回默认"（比如未知语言 → en），
//   这里立刻红 —— 因为那正是本仓反复栽过的「静默失败」。
//
// ★ 本脚本是**真跑**型（调真实函数），不是源文本扫描型；
//   但仍带一条**反例自证**：确保 `_check` 真的判得出负例（否则恒绿）。
// ============================================================

import 'package:dahuang_ai/core/app_self_settings.dart';

int _pass = 0;
int _fail = 0;
final List<String> _failures = <String>[];

void _check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    _failures.add(label);
    print('  FAIL  $label');
  }
}

/// `LanguageController.selectableCodes` 的值域（去掉 `system` 前的原始集合）。
/// 判据：`resolveLanguageCode` 的任何非 null 返回值**必须**落在这个集合内，
/// 否则会喂给 `setCode` 一个它直接 `return` 掉的非法码（= 用户以为切了、其实没切）。
const Set<String> _selectable = <String>{
  'system',
  'zh',
  'zh_Hant',
  'en',
  'ja',
  'vi',
};

void main() {
  print('== App 自操作纯逻辑（真跑）==');

  _check(!_isTrue(parseSettingBool('§nonsense§')),
      '反例自证：_check 判得出负例（否则恒绿）');

  _parseSettingBoolCases();
  _resolveLanguageCodeCases();
  _resolveAppPageKeyCases();
  _crossInvariant();

  print('');
  if (_fail > 0) {
    print('--- 失败明细 ---');
    for (final f in _failures) {
      print('  • $f');
    }
    print('');
  }
  print('PASS=$_pass FAIL=$_fail');
}

bool _isTrue(bool? v) => v == true;

void _parseSettingBoolCases() {
  print('-- parseSettingBool：认得出 ⇒ 真值 --');
  // 已经是 bool
  _check(parseSettingBool(true) == true, 'bool true ⇒ true');
  _check(parseSettingBool(false) == false, 'bool false ⇒ false');
  // 数字
  _check(parseSettingBool(1) == true, 'num 1 ⇒ true');
  _check(parseSettingBool(0) == false, 'num 0 ⇒ false');
  _check(parseSettingBool(2) == true, 'num 2 ⇒ true（非零即真）');
  // 字符串真值集
  for (final s in const ['true', 'on', '开', '打开', 'yes', '1']) {
    _check(parseSettingBool(s) == true, "字符串 '$s' ⇒ true");
  }
  // 字符串假值集
  for (final s in const ['false', 'off', '关', '关闭', 'no', '0']) {
    _check(parseSettingBool(s) == false, "字符串 '$s' ⇒ false");
  }
  // 大小写不敏感 + 去空白
  _check(parseSettingBool('TRUE') == true, '大小写不敏感：TRUE ⇒ true');
  _check(parseSettingBool('On') == true, '大小写不敏感：On ⇒ true');
  _check(parseSettingBool('NO') == false, '大小写不敏感：NO ⇒ false');
  _check(parseSettingBool('  开  ') == true, '去首尾空白：  开  ⇒ true');
  _check(parseSettingBool(' off ') == false, '去首尾空白： off ⇒ false');

  print('-- parseSettingBool：认不出 ⇒ **null**（不许当默认值）--');
  _check(parseSettingBool(null) == null, 'null ⇒ null');
  _check(parseSettingBool('maybe') == null, '未知串 maybe ⇒ null');
  _check(parseSettingBool('') == null, '空串 ⇒ null');
  _check(parseSettingBool('2') == null, '字符串 2 不在真值集 ⇒ null（刻意，不猜）');
  _check(parseSettingBool('是') == null, '是 不在集合 ⇒ null（保守）');
  _check(parseSettingBool(<int>[1]) == null, 'List ⇒ null（类型不认）');
  _check(parseSettingBool(const <String, int>{'a': 1}) == null, 'Map ⇒ null（类型不认）');
}

void _resolveLanguageCodeCases() {
  print('-- resolveLanguageCode：语言码 / 自称 / 别名 --');
  // 跟随系统
  for (final s in const ['system', '跟随系统', 'auto', '自动']) {
    _check(resolveLanguageCode(s) == 'system', "'$s' ⇒ system");
  }
  // 简体
  for (final s in const [
    'zh',
    'zh_CN',
    'zh-cn',
    'zh-Hans',
    '简体中文',
    '简体',
    '中文',
  ]) {
    _check(resolveLanguageCode(s) == 'zh', "'$s' ⇒ zh");
  }
  // 繁体 —— 必须落在 zh_Hant（不是 zh），否则简体会被误选
  for (final s in const [
    'zh_Hant',
    'zh-Hant',
    'zh_TW',
    'zh-tw',
    '繁體中文',
    '繁体中文',
    '繁體',
    '繁体',
  ]) {
    _check(resolveLanguageCode(s) == 'zh_Hant', "'$s' ⇒ zh_Hant");
  }
  // 英 / 日 / 越
  for (final s in const ['en', 'English', '英文', '英语']) {
    _check(resolveLanguageCode(s) == 'en', "'$s' ⇒ en");
  }
  for (final s in const ['ja', 'jp', 'Japanese', '日本語', '日语']) {
    _check(resolveLanguageCode(s) == 'ja', "'$s' ⇒ ja");
  }
  for (final s in const ['vi', 'Vietnamese', 'Tiếng Việt', '越南语']) {
    _check(resolveLanguageCode(s) == 'vi', "'$s' ⇒ vi");
  }
  // 大小写 / 空白
  _check(resolveLanguageCode('  EN  ') == 'en', '去空白 + 小写：  EN  ⇒ en');
  _check(resolveLanguageCode('ZH-HANT') == 'zh_Hant', 'ZH-HANT ⇒ zh_Hant');

  print('-- resolveLanguageCode：认不出 ⇒ **null** --');
  _check(resolveLanguageCode(null) == null, 'null ⇒ null');
  _check(resolveLanguageCode('de') == null, '德语 de ⇒ null（不支持就别说支持）');
  _check(resolveLanguageCode('klingon') == null, 'klingon ⇒ null');
  _check(resolveLanguageCode('') == null, '空串 ⇒ null');
  _check(resolveLanguageCode('français') == null, '法语 ⇒ null（未收录）');
}

/// 页面键归一（0.86.0）：**白名单由调用方从注册表传入**，本函数不持有页面清单。
void _resolveAppPageKeyCases() {
  print('-- resolveAppPageKey：规范键 / 大小写 / 空白 / 中文别名 --');
  const known = <String>[
    'settings', 'advanced_settings', 'passport', 'identity_backup',
    'device_migration', 'key_rotation', 'mail', 'phone_control', 'notify_sms',
    'memory', 'diagnostics', 'tools', 'skill_market', 'dsh_import', 'profile',
    'topics', 'dashboard', 'serendipity', 'glossary',
    'weekly_report',
  ];
  // 规范键直通
  var allPass = true;
  for (final k in known) {
    if (resolveAppPageKey(k, known) != k) {
      allPass = false;
      print('      直通失败：$k');
    }
  }
  _check(allPass, '全部规范键直通（${known.length} 个）');
  // 大小写 / 空白 / 连字符 / 空格
  _check(resolveAppPageKey('  Settings  ', known) == 'settings', '  Settings  ⇒ settings');
  _check(resolveAppPageKey('ADVANCED-SETTINGS', known) == 'advanced_settings',
      'ADVANCED-SETTINGS ⇒ advanced_settings');
  _check(resolveAppPageKey('advanced settings', known) == 'advanced_settings',
      'advanced settings ⇒ advanced_settings');
  // 中文别名
  _check(resolveAppPageKey('设置', known) == 'settings', '设置 ⇒ settings');
  _check(resolveAppPageKey('邮箱', known) == 'mail', '邮箱 ⇒ mail');
  _check(resolveAppPageKey('工具', known) == 'tools', '工具 ⇒ tools');
  _check(resolveAppPageKey('记忆', known) == 'memory', '记忆 ⇒ memory');
  _check(resolveAppPageKey('通知短信', known) == 'notify_sms', '通知短信 ⇒ notify_sms');
  _check(resolveAppPageKey('周报', known) == 'weekly_report', '周报 ⇒ weekly_report');
  _check(resolveAppPageKey('自检', known) == 'diagnostics', '自检 ⇒ diagnostics');
  // 认不出 ⇒ null
  _check(resolveAppPageKey(null, known) == null, 'null ⇒ null');
  _check(resolveAppPageKey('', known) == null, '空串 ⇒ null');
  _check(resolveAppPageKey('   ', known) == null, '纯空白 ⇒ null');
  _check(resolveAppPageKey('nonexistent', known) == null, '未注册键 ⇒ null');
  _check(resolveAppPageKey('火箭发射', known) == null, '未知中文 ⇒ null');
  // ★ 别名指向**未注册**的键 ⇒ 也必须 null（白名单以注册表为准，别名不能"一说就算数"）
  _check(resolveAppPageKey('设置', const ['mail']) == null,
      '★ 别名 settings 不在 knownKeys 里 ⇒ null');
  _check(resolveAppPageKey('邮箱', const ['settings']) == null,
      '★ 别名 mail 不在 knownKeys 里 ⇒ null');
  // ★ 审批页（待我确认的建议）**刻意不进注册表**（0.61.0「唯一入口」红线）⇒ 其别名也须失效。
  _check(resolveAppPageKey('待确认', known) == null,
      '待确认 ⇒ null（审批页 pending_suggestions 刻意不进注册表）');
  _check(resolveAppPageKey('pending_suggestions', known) == null,
      'pending_suggestions ⇒ null（该页不由智能体代开）');
}

/// 跨函数不变量：任何被认出的语言码都必须落在 `selectableCodes` 内。
void _crossInvariant() {
  print('-- 跨函数不变量：认出的码必在 selectableCodes 内 --');
  const samples = <String>[
    'system', '跟随系统', 'auto', '自动',
    'zh', 'zh_CN', 'zh-cn', 'zh-Hans', '简体中文', '简体', '中文',
    'zh_Hant', 'zh-Hant', 'zh_TW', 'zh-tw', '繁體中文', '繁体中文', '繁體', '繁体',
    'en', 'English', '英文', '英语',
    'ja', 'jp', 'Japanese', '日本語', '日语',
    'vi', 'Vietnamese', 'Tiếng Việt', '越南语',
  ];
  var allIn = true;
  for (final s in samples) {
    final c = resolveLanguageCode(s);
    if (c != null && !_selectable.contains(c)) {
      allIn = false;
      print('      越界：$s ⇒ $c（不在 selectableCodes）');
    }
  }
  _check(allIn, '全部样本的归一结果都落在 selectableCodes 内');
}
