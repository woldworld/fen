// 按需帮助（`?`）体系的守卫（0.41.0 新增）。
//
// 它防的是三件事，每件都曾在本仓真实发生过：
//   ① **枚举与文案脱钩**：新增一个 HelpTopic 却忘了配 ARB 键 ⇒ 弹层空白（编译期抓不到，因为 getter 是生成的）。
//   ② **孤儿 help* 键**：文案删了、键还在 ⇒ 下一个人以为"这个主题已经有了"。
//   ③ ★★ **减掉的小字悄悄长回来**：把说明搬进 `?` 之后，某次改动又把同一句话贴回界面上 ——
//      这是本文件存在的主要理由。判据＝**旧 hint 键必须已退役**（ARB 里没有、UI 里没人引用）。
//
// 源文本扫描型脚本必须带**自检（positive control）**：匹配式一坏就会"扫到 0 处 → 恒绿"。
// 所以下面把判据抽成纯函数，并在末尾对**内存里被人为改坏的三份副本**各断言一次"必须被判出"。
// ★ 本脚本**不 import** `lib/ui/help_dot.dart` —— 它拉着 package:flutter，`dart run` 会直接崩
//   （`dart:ui is not available on this platform`）。枚举值改从源码文本里解析，顺带避开"抄一份会漂移"。
import 'dart:convert';
import 'dart:io';

int _pass = 0;
int _fail = 0;
void check(bool ok, String label) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    print('  FAIL: $label');
  }
}

String _stripComments(String s) {
  // 行注释 + 块注释 + 字符串里的 // 都直接剥（本脚本只做"出现/不出现"判断，不做语义解析）
  final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
  return noBlock
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'//.*$'), ''))
      .join('\n');
}

String _read(String p) => File(p).readAsStringSync();

/// 递归收集 lib 下的 .dart（排除生成物 l10n 与 tool/）。
List<String> _dartFilesUnder(String dir) {
  final out = <String>[];
  final d = Directory(dir);
  if (!d.existsSync()) return out;
  for (final e in d.listSync(recursive: true)) {
    if (e is! File) continue;
    final p = e.path.replaceAll('\\', '/');
    if (!p.endsWith('.dart')) continue;
    if (p.contains('/lib/l10n/')) continue;
    out.add(p);
  }
  out.sort();
  return out;
}

// ── 判据（纯函数，供自检复用）──────────────────────────────────────────
class Rule {
  Rule(this.files, this.zhKeys, this.enKeys, this.topicNames);
  final Map<String, String> files; // path -> 已剥注释的源码
  final Set<String> zhKeys;
  final Set<String> enKeys;
  final List<String> topicNames;
}

/// 0.41.0 起**必须已退役**的"常驻小字"键（说明已搬进 `?`）。
const List<String> retiredHintKeys = <String>[
  'worldMetricHint',
  'worldBridgeSectionHint',
  'roomRoleHint',
  'passportOfflineHint',
  'passportFunnelHint',
  'passportLogHint',
  'repNetHint',
  'personaTierHint',
  'intercardDisclosureNote',
  'socialNetworkGuide',
  // ── 0.51.0 推广批次：段落型常驻小字（≥40 字）搬进 `?` ──
  'settingsRecallEnabledHint',
  'idbRestoreNote',
  'arcSectionNote',
  'dmSameNetworkNote',
  'dmDoneNewHint',
  'idbCodeHint',
  'rcHubClaimNote',
  'mcpBusNote',
  'repNetAnchorsHint',
  'repNetQueryUnknownHint',
];

/// 刻意**保留常驻**的小字（不隐藏）：披露类、红线警示类、条件性状态警告类。
/// 写在这里是为了让"为什么不转问号"有据可查，而不是被下一个人当成漏网之鱼。
///
/// 0.51.0 逐条复核（判据：**"用户不点问号也不会出事"才可搬**）：
/// · [条件性状态警告] `deviceControlRedetectTip` 只在"系统开关开着但检测不到"时出现；
/// · [条件性状态警告] `socialVerifyHintNoPin` 只在"还没握手、拿不到固定身份"时出现；
/// · [条件性状态警告] `socialDbDegradedHint` 只在本地库读不到时出现；
/// · [结果内容] `rcAnchorNote` / `rcVerdictTipNotActive` / `dro*` 类 dsh 备注随结果渲染；
/// · 其余见下方 keys 与 `dahuang-ondemand-help-migration` 技能 §2。
const List<String> keptInlineKeys = <String>[
  'socialRadarOffHint',
  'idbStatusNotBackedUpHint',
  'worldVibrancyObservedHint',
  // ── 0.51.0 ──
  'dashboardSourceHint', // 数据边界：仅本机埋点
  'circleFallbackNote', // 数据边界：兜底项不是圈内成员
  'dmDoneOldHint', // 数据边界：直迁不搬数据（旧机）
  'digestNotePlain', // A/B 实验披露
  'digestNoteAction', // A/B 实验披露
  'socialDbDegradedHint', // 降级状态
  'idbStatusBackedUpHint', // 与 NotBackedUp 成对的状态
  'arcSavedHint', // 红线：没有口令谁也打不开
  'onboardingDisclosureNote', // 铁律 1 的产品级明示
  'worldRoomClosedReadonlyHint', // 房间状态
  'deviceControlRedetectTip', // 条件性排障（仅"检测不到"时出现）
  'socialVerifyHintNoPin', // 条件性状态（仅"未握手"时出现）
];

/// **页面级 `?` 预算**：一个页面文件里 `HelpDot(` 的上限。
///
/// 纪律是「**同屏** `?` ≤ 3」。长页（分节滚动）逐节各挂一个并非"同一屏"，
/// 所以这些页登记在表里并写明理由；其余页一律按 3 处理。
/// ★ 预算**只降不升**：调高必须改这张表（改表 = 显式承担一次"问号变多"的决定）。
const Map<String, int> dotBudget = <String, int>{
  // 分节长页：每个小节一个（离线 / 漏斗 / 信誉 / 日志…），不是同一屏
  'lib/ui/world_screen.dart': 4,
  'lib/ui/passport_screen.dart': 4,
};

String _pascal(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

List<String> checkAll(Rule r) {
  final bad = <String>[];
  final all = r.files.values.join('\n');

  // ① 每个枚举值：必须有 case + 必须有 Title/Body 两份文案（zh/en）
  for (final t in r.topicNames) {
    final k = 'help${_pascal(t)}';
    if (!r.files['lib/ui/help_dot.dart']!.contains('case HelpTopic.$t:')) {
      bad.add('missing case for $t');
    }
    for (final suffix in const ['Title', 'Body']) {
      if (!r.zhKeys.contains('$k$suffix')) bad.add('zh missing $k$suffix');
      if (!r.enKeys.contains('$k$suffix')) bad.add('en missing $k$suffix');
    }
  }

  // ② 无孤儿 help* 键（两个通用标签除外）
  const generic = <String>['helpDotTooltip', 'helpSheetClose'];
  final known = <String>{
    for (final t in r.topicNames) ...['help${_pascal(t)}Title', 'help${_pascal(t)}Body'],
    ...generic,
  };
  for (final k in r.zhKeys) {
    if (k.startsWith('help') && !known.contains(k)) bad.add('orphan zh key $k');
  }
  for (final k in r.enKeys) {
    if (k.startsWith('help') && !known.contains(k)) bad.add('orphan en key $k');
  }
  for (final g in generic) {
    if (!r.zhKeys.contains(g) || !r.enKeys.contains(g)) bad.add('missing generic $g');
  }

  // ③ 退役键：ARB 里不得复活、UI 里不得被引用
  for (final k in retiredHintKeys) {
    if (r.zhKeys.contains(k)) bad.add('retired key back in zh: $k');
    if (r.enKeys.contains(k)) bad.add('retired key back in en: $k');
    if (RegExp('\\.$k\\b').hasMatch(all)) bad.add('retired key still used: $k');
  }

  // ④ 刻意保留的常驻小字必须还在（否则是"误删"，不是"优化"）
  for (final k in keptInlineKeys) {
    if (!r.zhKeys.contains(k) || !r.enKeys.contains(k)) bad.add('kept-inline key lost: $k');
    if (!RegExp('\\.$k\\b').hasMatch(all)) bad.add('kept-inline key unused: $k');
  }

  // ⑤ 挂载点：三页各自至少挂了一个「?」，且 world 页同时有页面级入口
  int countIn(String path, String needle) =>
      needle.allMatches(r.files[path] ?? '').length;
  for (final p in const ['lib/ui/world_screen.dart', 'lib/ui/passport_screen.dart', 'lib/ui/social_screen.dart']) {
    if (r.files[p] == null) {
      bad.add('missing page $p');
      continue;
    }
    if (countIn(p, 'HelpDot(') < 1) bad.add('$p has no HelpDot');
    if (countIn(p, 'HelpAction(') < 1) bad.add('$p has no page-level HelpAction');
  }
  if (countIn('lib/ui/world_screen.dart', 'HelpDot(') < 3) {
    bad.add('world_screen HelpDot count dropped below 3');
  }

  // ⑥ 组件文件本身零中文（面向操作者的文案一律走 ARB）
  if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(r.files['lib/ui/help_dot.dart'] ?? '')) {
    bad.add('help_dot.dart contains hardcoded CJK');
  }

  // ⑦ 枚举里的主题数必须与 switch 的 case 数一致（少一个 case = 运行期不穷尽）
  final cases = RegExp(r'case HelpTopic\.').allMatches(r.files['lib/ui/help_dot.dart'] ?? '').length;
  if (cases != r.topicNames.length) bad.add('switch cases ($cases) != topics (${r.topicNames.length})');

  // ⑧ ★ 同屏 `?` 预算（0.51.0）：HelpDot + HelpTitle 合计 ≤ 每页预算（默认 3），
  //    页面级 HelpAction ≤ 1。预算表 `dotBudget` 里的长页理由写在表上方。
  for (final e in r.files.entries) {
    final p = e.key;
    if (!p.startsWith('lib/ui/')) continue;
    if (p == 'lib/ui/help_dot.dart') continue; // 组件本体，不是页面
    final dots = RegExp(r'HelpDot\(').allMatches(e.value).length +
        RegExp(r'HelpTitle\(').allMatches(e.value).length;
    final budget = dotBudget[p] ?? 3;
    if (dots > budget) bad.add('$p 问号超预算：$dots > $budget');
    final actions = RegExp(r'HelpAction\(').allMatches(e.value).length;
    if (actions > 1) bad.add('$p 页面级 HelpAction 多于 1 个：$actions');
  }

  return bad;
}

/// ⑨ **五语种齐 + 值非空 + en 零 CJK**（0.112.0 新增；此前 ① 只查 zh/en 的**键是否存在**）。
///
/// 由来：遇幸实验室（Serendipity）的逐页使用说明原本是**硬编码中文的对话弹窗**，
/// 集成进本仓时整块丢掉——所以这一批要**一次补五种语言**。而「键在、值是空串」
/// 与「键在、英文里塞了中文」这两种都能骗过 ①（只比 key 集合），故把**值**也纳入判据。
List<String> checkLocales(
    Map<String, Map<String, String>> arb, List<String> topics) {
  final bad = <String>[];
  const locales = <String>['en', 'zh', 'zh_Hant', 'ja', 'vi'];
  for (final loc in locales) {
    if (arb[loc] == null) bad.add('arb missing locale $loc');
  }
  for (final t in topics) {
    final k = 'help${_pascal(t)}';
    for (final loc in locales) {
      final m = arb[loc];
      if (m == null) continue;
      for (final suffix in const ['Title', 'Body']) {
        final key = '$k$suffix';
        final v = m[key];
        if (v == null || v.trim().isEmpty) bad.add('$loc missing/empty $key');
      }
    }
    // en 是"事实源语言"：英文界面里出现中文 ⇒ 一定是漏译/串台
    final cjk = RegExp(r'[\u3000-\u303f\u3400-\u4dbf\u4e00-\u9fff\uff00-\uffef]');
    for (final suffix in const ['Title', 'Body']) {
      if (cjk.hasMatch(arb['en']?['$k$suffix'] ?? '')) {
        bad.add('en CJK in $k$suffix');
      }
    }
  }
  return bad;
}

void main() {
  final dartFiles = _dartFilesUnder('lib');
  final files = <String, String>{
    for (final p in dartFiles) p: _stripComments(_read(p)),
  };
  final zhRaw = _read('lib/l10n/app_zh.arb');
  final enRaw = _read('lib/l10n/app_en.arb');
  final zh = (jsonDecode(zhRaw) as Map).keys.cast<String>().toSet();
  final en = (jsonDecode(enRaw) as Map).keys.cast<String>().toSet();

  // 枚举值直接从组件源码里读（而不是照抄一遍，抄的那份会漂移）
  final enumBody = RegExp(r'enum HelpTopic \{([\s\S]*?)\}')
      .firstMatch(files['lib/ui/help_dot.dart'] ?? '')
      ?.group(1) ??
      '';
  final names = enumBody
      .split(',')
      .map((e) => e.trim())
      .where((e) => RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(e))
      .toList();

  final rule = Rule(files, zh, en, names);
  final bad = checkAll(rule);

  // ⑨ 五语种齐 + 值非空 + en 零 CJK
  final arb = <String, Map<String, String>>{};
  for (final loc in const ['en', 'zh', 'zh_Hant', 'ja', 'vi']) {
    final p = 'lib/l10n/app_$loc.arb';
    if (!File(p).existsSync()) continue;
    arb[loc] = (jsonDecode(_read(p)) as Map)
        .map((k, v) => MapEntry(k as String, '$v'));
  }
  final badLocale = checkLocales(arb, names);
  check(badLocale.isEmpty,
      '五语种文案齐（${arb.keys.length} 个语种 / ${names.length} 主题）${badLocale.isEmpty ? '' : ' — 见下'}$badLocale');
  for (final b in badLocale) {
    print('    · $b');
  }

  // ── 正向断言 ──
  check(files.containsKey('lib/ui/help_dot.dart'), '组件存在');
  check(files.length >= 60, '源码树真被走到（${files.length} 个文件）');
  check(zh.length > 1200 && en.length > 1200, 'ARB 真被解析（zh=${zh.length} en=${en.length}）');
  check(names.length >= 10 && names.toSet().length == names.length,
      '枚举解析可信（${names.length} 个主题、无重名）');
  check(bad.isEmpty, '判据全过${bad.isEmpty ? '' : ' — 见下方逐条'}');
  for (final b in bad) {
    print('    · $b');
  }

  // ── 剥注释有效性 ──
  final stripped = _stripComments('// a.b\nfoo(); // x.y');
  check(!stripped.contains('a.b') && !stripped.contains('x.y'), '剥注释有效（注释里的引用不算数）');

  // ── ★ 自检（positive control）：改坏三份副本，每份都必须被判出 ──
  final mutated1 = Map<String, String>.from(files);
  mutated1['lib/ui/help_dot.dart'] = mutated1['lib/ui/help_dot.dart']!
      .replaceFirst('case HelpTopic.worldMetric:', 'case HelpTopic.worldMetryk:');
  check(checkAll(Rule(mutated1, zh, en, names)).isNotEmpty,
      '自检①：删掉一个 case 必须被判出');

  final zhMissing = Set<String>.from(zh)..remove('helpWorldOverviewBody');
  check(checkAll(Rule(files, zhMissing, en, names)).isNotEmpty,
      '自检②：抽掉一个帮助文案必须被判出');

  final zhOrphan = Set<String>.from(zh)..add('helpTotallyOrphanBody');
  check(checkAll(Rule(files, zhOrphan, en, names)).isNotEmpty,
      '自检③：孤儿 help* 键必须被判出');

  final zhResurrect = Set<String>.from(zh)..add('worldMetricHint');
  check(checkAll(Rule(files, zhResurrect, en, names)).isNotEmpty,
      '自检④：退役的小字键复活必须被判出');

  final mutated2 = Map<String, String>.from(files);
  mutated2['lib/ui/world_screen.dart'] = mutated2['lib/ui/world_screen.dart']!
      .replaceAll('HelpDot(', 'SizedBox(');
  check(checkAll(Rule(mutated2, zh, en, names)).isNotEmpty,
      '自检⑤：把某页的问号全删掉必须被判出');

  // ⑥ 同屏预算：往一个本来没有问号的页里塞 4 个 ⇒ 必须超预算被判出
  final mutated3 = Map<String, String>.from(files);
  final dash = mutated3['lib/ui/dashboard_screen.dart'];
  check(dash != null, '预算自检的靶页存在（dashboard_screen）');
  mutated3['lib/ui/dashboard_screen.dart'] =
      '${dash ?? ''} ${List.generate(4, (_) => 'HelpDot(a)').join(' ')} ';
  check(checkAll(Rule(mutated3, zh, en, names)).isNotEmpty,
      '自检⑥：某页问号超预算（4 > 3）必须被判出');

  // ⑦ 页面级入口只能有一个：塞第二个 HelpAction ⇒ 必须被判出
  final mutated4 = Map<String, String>.from(files);
  mutated4['lib/ui/settings_screen.dart'] =
      '${mutated4['lib/ui/settings_screen.dart'] ?? ''} HelpAction(a) HelpAction(b) ';
  check(checkAll(Rule(mutated4, zh, en, names)).isNotEmpty,
      '自检⑦：页面级 HelpAction >1 必须被判出');

  // ⑧ 五语种判据的正控：删掉 vi 的一条文案 ⇒ 必须被判出
  final viBroken = <String, Map<String, String>>{
    for (final e in arb.entries) e.key: Map<String, String>.from(e.value),
  };
  viBroken['vi']!.remove('helpSerendipityOracleBody');
  check(checkLocales(viBroken, names).isNotEmpty,
      '自检⑧：删掉一个语种的帮助文案必须被判出');

  // ⑨ 五语种判据的正控：往 en 里灌中文 ⇒ 必须被判出（正是"英文界面出中文"的形态）
  final enSino = <String, Map<String, String>>{
    for (final e in arb.entries) e.key: Map<String, String>.from(e.value),
  };
  enSino['en']!['helpSerendipityDiaryBody'] = '这里写点什么';
  check(checkLocales(enSino, names).isNotEmpty,
      '自检⑨：en 值混入中文必须被判出');

  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
