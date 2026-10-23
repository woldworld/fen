// 纯 Dart 校验脚本：**入门 / 进阶模式可见性守卫**（0.61.0）。
// 运行：dart run tool/verify_mode_visibility.dart
//
// ## 抓的是什么
//
// 0.61.0 之前 `simple_mode` 是**散落三处各读一遍**的裸 prefs 键，且**社交页只在
// `initState` 读一次**。用户实测的后果不是"少个开关"，而是：
//
//   ★★ **「待我确认的建议」审批入口全 App 断链** —— 该入口（`AgentActionInboxScreen`）
//      全仓只被 `social_screen.dart` 的 `_buildLedgerTab` push 一次，而日志页签当时
//      受 `if (!_simpleMode)` 门控 ⇒ 新装用户（默认入门模式）**永远到不了审批页**，
//      观察模式产出的建议卡落库即死角 —— 体感就是"分身完全不动"。
//
// 因此本守卫钉住的**不是"某个开关的默认值"**，而是三条**红线**：
//
//   ① **日志页签恒常显**（含入门模式）—— 它是审批入口的**唯一**通路，谁门控它谁断链；
//   ② **托办仍受门控** —— 用户要的正是"入门模式收起托办"；若哪天门控被顺手删掉，
//      需求被静默丢掉（**"少做一件事"没有任何测试会红**，故必须正面钉住）；
//   ③ **模式是单一事实源** —— `'simple_mode'` 字面量只许出现在 `ModeController`；
//      其余各处一律走 `ModeController.i`。散落回各处 = 重演"改了不生效"。
//
// ## 为什么常量名要钉
//
// `tool/verify_data_keys.dart` 的键解析建的是**全局**「常量名 → 字面量」表：
// 同名即歧义 ⇒ 两处都被降级成"动态键"、那条守卫对被撞名的常量**永久失效**。
// 0.61.0 首次就撞了（`prefKey` 与 `LanguageController.prefKey` 重名）。
// 故这里正面钉住"`prefKey` 全仓只声明一次"这条不变式。
//
// ## 盲区（显式声明）
//
// 本脚本扫的是**源码文本**，不是 AST。它能证明"门控写在/没写在这里"，
// 不能证明"运行时真的渲染了 N 个页签"（那属 widget 测试的领域，本仓未覆盖）。

import 'dart:io';

int _pass = 0;
int _fail = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) throw StateError('missing: $p');
  return f.readAsStringSync();
}

/// 剥行注释。★ 用**负向后顾** `(?<!:)//` —— 普通 `//.*$` 会把 `https://` 的 `//`
/// 之后整段吃掉（本仓 `.ps1` / URL 常量遍布），那是"剥注释反而剥掉判据"的经典自伤。
String _decomment(String s) =>
    s.replaceAll(RegExp(r'(?<!:)//.*$', multiLine: true), '');

List<File> _libDart() => (Directory('lib').listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path)));

String _norm(String p) => p.replaceAll(r'\', '/');

/// 求出一段源码里所有 `if (!mode.simpleMode) ...[ ... ]` 门控**包住**的字符区间。
///
/// 为什么需要它（R50 / R44）：0.121.0 把管理页的门控从「包整个区块」改成
/// 「包区块内部的一组卡」。任何"门控出现 N 次"的计数判据都会被**数字对但位置错**
/// 糊弄 —— 把门控挪去包授权组，计数照样是 3，而入门用户已经点不到通知权限了。
/// 只有**区间**能回答"这两张卡到底在门里还是门外"。
///
/// 单行门控（`if (!mode.simpleMode) Card(...)`，无 `...[]`）**不构成区间**：
/// 它包的是单个表达式，不吞后面的兄弟节点，所以在这里显式跳过（跳过 ≠ 漏判：
/// 跳过意味着它不会假阳性地"包住"后面整段代码）。
List<List<int>> _gateRanges(String s) {
  final out = <List<int>>[];
  for (final m in RegExp(r'if \(!mode\.simpleMode\)').allMatches(s)) {
    var i = m.end;
    while (i < s.length && ' \t\r\n'.contains(s[i])) {
      i++;
    }
    if (s.startsWith('...', i)) {
      i += 3;
      while (i < s.length && ' \t\r\n'.contains(s[i])) {
        i++;
      }
    }
    if (i >= s.length || s[i] != '[') continue;
    var depth = 0;
    var j = i;
    for (; j < s.length; j++) {
      if (s[j] == '[') {
        depth++;
      } else if (s[j] == ']') {
        depth--;
        if (depth == 0) break;
      }
    }
    out.add(<int>[m.start, j]);
  }
  return out;
}

/// `idx` 处的 token 是否落在某个门控区间**内**。
bool _gatedAt(String s, int idx) =>
    idx >= 0 && _gateRanges(s).any((r) => idx >= r[0] && idx <= r[1]);

/// 某个 token 的**每一个**出现位置里，有几个落入门控区间（0 = 全在门外）。
int _gatedHits(String s, String token) {
  final ranges = _gateRanges(s);
  var n = 0;
  var k = s.indexOf(token);
  while (k >= 0) {
    if (ranges.any((r) => k >= r[0] && k <= r[1])) n++;
    k = s.indexOf(token, k + 1);
  }
  return n;
}

/// 授权卡（通知设置 / 日历）是否有**任一**出现位置落入门控区间。
bool _authCardGated(String s) =>
    _gatedHits(s, '_NotifySettingsCard()') > 0 ||
    _gatedHits(s, '_CalendarSettingsCard()') > 0;

void main() {
  final social = _decomment(_read('lib/ui/social_screen.dart'));
  final settings = _decomment(_read('lib/ui/settings_screen.dart'));
  final manage = _decomment(_read('lib/ui/manage_screen.dart'));
  final mainDart = _decomment(_read('lib/main.dart'));
  final modeCtrl = _decomment(_read('lib/core/mode_controller.dart'));
  final onboarding = _decomment(_read('lib/ui/onboarding_screen.dart'));

  // ---------------------------------------------------------------------
  print('--- ⓪ 扫描器自检（positive control）---');
  // 本守卫是**源码文本扫描型**：匹配式一旦因重构失效，会安静地"扫到 0 处" ⇒
  // 所有 `!contains(...)` 判据**全部恒真 → 全绿**。所以先证明"判据真的会翻"。
  bool ledGated(String s) => s.contains('if (!_simpleMode) _buildLedgerTab(theme)');
  check(!ledGated(social), '正控基线：当前源码里日志页签**未**被门控（判据初始为真）');
  check(
      ledGated(social.replaceFirst(
          '\n          _buildLedgerTab(theme),', '\n          if (!_simpleMode) _buildLedgerTab(theme),')),
      '正控：把日志页签改成被门控 ⇒ 判据必须翻为假（证明判据不是恒真）');

  bool delegGated(String s) => s.contains('if (!_simpleMode) const DelegationPanel(),');
  check(delegGated(social), '正控基线：托办当前**受**门控');
  check(
      !delegGated(social.replaceFirst(
          'if (!_simpleMode) const DelegationPanel(),', 'const DelegationPanel(),')),
      '正控：把托办的门控去掉 ⇒ 判据必须翻为假');

  bool logTabGated(String s) =>
      s.contains('if (!_simpleMode)\n          Tab(\n              icon: const Icon(Icons.article_outlined)');
  check(!logTabGated(social), '正控基线：日志 Tab 当前未被门控');
  check(
      logTabGated(social.replaceFirst("Tab(\n            icon: const Icon(Icons.article_outlined),",
          "if (!_simpleMode)\n          Tab(\n              icon: const Icon(Icons.article_outlined),")),
      '正控：日志 Tab 被门控 ⇒ 判据必须翻为假');

  // ★★ 0.84.0：控制中心**不放模式开关**（顶栏才是唯一入口），只留「进阶设置」入口
  //   （独立页 `AdvancedSettingsScreen`）+ 入门模式下一行指路小字。
  //   判据锚点随之改：老锚点 `_advancedMode` / `_buildAdvancedHeader` 都已删除，
  //   若还钉它们，判据会恒为假 ⇒ 下面两条正控立刻炸出来（不会静默）。
  bool noModeWrite(String s) => !s.contains('.setSimpleMode');
  check(noModeWrite(settings), '正控基线：控制中心**不写**模式（无 setSimpleMode 调用）');
  check(
      !noModeWrite(settings.replaceFirst(
          'final advanced =', 'ModeController.i.setSimpleMode(false);\n    final advanced =')),
      '正控：往控制中心塞一个模式开关 ⇒ 判据必须翻为假（证明判据不是恒真）');

  bool advFromController(String s) =>
      s.contains('!Provider.of<ModeController>(context).simpleMode');
  check(advFromController(settings), '正控基线：进阶入口按 `ModeController` 当前档位决定');
  check(
      !advFromController(settings.replaceFirst(
          '!Provider.of<ModeController>(context).simpleMode', 'false')),
      '正控：把档位来源换成常量 ⇒ 判据必须翻为假');

  // 0.121.0 负控：门控**区间**求解必须能区分「门控包住 A」与「门控包住 B」。
  //   R50 原话：判据强度也是查错对象 —— 只数"门控出现 3 次"时，把门控挪去包
  //   授权组，数字仍是 3 ⇒ 假绿。区间判定是这条红线的**唯一**可靠写法。
  const demoOther = 'if (!mode.simpleMode) ...[\n  _buildOther(),\n],\n_keep();';
  check(!_gatedAt(demoOther, demoOther.indexOf('_keep')),
      '正控：门控包的是**别的** widget ⇒ `_keep()` 判为不在区间内');
  const demoKeep = 'if (!mode.simpleMode) ...[\n  _keep(),\n],';
  check(_gatedAt(demoKeep, demoKeep.indexOf('_keep')),
      '正控：门控包住 `_keep()` ⇒ 区间判定必须为真（证明不是恒真）');
  const demoBare = 'if (!mode.simpleMode) _keep(),';
  check(!_gatedAt(demoBare, demoBare.indexOf('_keep')),
      '正控：单行门控（无 `...[]`）不构成区间，不吞后面的兄弟节点');

  // ---------------------------------------------------------------------
  print('');
  print('--- ① 红线：日志页签恒常显（审批入口不可断链）---');
  check(!ledGated(social),
      'TabBarView 里 `_buildLedgerTab(theme)` **不得**被 `if (!_simpleMode)` 门控');
  check(social.contains('\n          _buildLedgerTab(theme),'),
      'TabBarView 里存在**无条件**的 `_buildLedgerTab(theme),`');
  check(!logTabGated(social), '`_buildTabs` 里日志 Tab **不得**被 `if (!_simpleMode)` 门控');
  check(
      RegExp(r'Tab\(\s*icon: const Icon\(Icons\.article_outlined\),\s*text: l10n\.socialTabLogs\)')
          .hasMatch(social),
      '日志 Tab 以 `socialTabLogs` 恒常注册（无门控前缀）');

  print('');
  print('--- ② 审批入口唯一且落在日志页内 ---');
  final inboxUses = RegExp(r'const AgentActionInboxScreen\(\)').allMatches(social).length;
  check(inboxUses == 1, '`AgentActionInboxScreen` 在社交页**恰好被 push 一次**（实际 $inboxUses）');
  final ledgerIdx = social.indexOf('Widget _buildLedgerTab(ThemeProvider theme) {');
  final inboxIdx = social.indexOf('const AgentActionInboxScreen()');
  check(ledgerIdx >= 0 && inboxIdx > ledgerIdx,
      '审批页入口落在 `_buildLedgerTab` 方法体内（日志页 = 它的唯一通路）');
  final elsewhere = <String>[];
  for (final f in _libDart()) {
    if (_norm(f.path).endsWith('lib/ui/social_screen.dart')) continue;
    if (_norm(f.path).endsWith('lib/ui/agent_action_inbox_screen.dart')) continue;
    if (_decomment(f.readAsStringSync()).contains('AgentActionInboxScreen')) {
      elsewhere.add(_norm(f.path));
    }
  }
  check(elsewhere.isEmpty,
      '除社交页与其自身定义外，无别处引用审批页${elsewhere.isEmpty ? '' : '（→ $elsewhere）'}');

  print('');
  print('--- ③ 红线：托办仍受入门模式门控（需求不可被静默删掉）---');
  check(delegGated(social), 'TabBarView 里 `if (!_simpleMode) const DelegationPanel(),` 仍在');
  check(
      social.contains('if (!_simpleMode)\n          Tab(\n              icon: const Icon(Icons.assignment_outlined)'),
      '`_buildTabs` 里托办 Tab 仍受 `if (!_simpleMode)` 门控');
  check(social.contains(r'if (!_simpleMode && i == 3) DelegationPanel.requestReload();'),
      '`_onTabChanged` 的托办刷新带 `!_simpleMode` 守卫（入门模式 3 号是日志，不得误刷托办）');
  check(social.contains('int get _tabCount => _simpleMode ? 4 : 5;'),
      '页签数 = 入门 4 / 进阶 5（日志常显后序位前移，长度必须同步）');

  print('');
  print('--- ④ 模式 = 单一事实源（禁止散落回各处）---');
  final literalHits = <String>[];
  for (final f in _libDart()) {
    if (_decomment(f.readAsStringSync()).contains("'simple_mode'")) {
      literalHits.add(_norm(f.path));
    }
  }
  check(literalHits.length == 1 && literalHits.first.endsWith('lib/core/mode_controller.dart'),
      "字面量 `'simple_mode'` 全仓只出现在 ModeController${literalHits.length == 1 ? '' : '（→ $literalHits）'}");
  check(modeCtrl.contains("static const String modePrefKey = 'simple_mode';"),
      'ModeController 用 `modePrefKey` 常量承载该键');
  final prefKeyDecls = <String>[];
  for (final f in _libDart()) {
    if (RegExp(r'const\s+String\s+prefKey\s*=').hasMatch(_decomment(f.readAsStringSync()))) {
      prefKeyDecls.add(_norm(f.path));
    }
  }
  check(prefKeyDecls.length == 1,
      '常量名 `prefKey` 全仓只声明一次（重名会让 verify_data_keys 的解析歧义、守卫失效）'
      '${prefKeyDecls.length == 1 ? '' : '（→ $prefKeyDecls）'}');
  check(onboarding.contains('await ModeController.i.setSimpleMode(true);'),
      '引导完成写模式走单一事实源（不再裸写 prefs）');
  check(!onboarding.contains("setBool('simple_mode'"),
      '引导页不再直接写模式键（其余 prefs 写入如 onboarding_done 不受影响）');

  print('');
  print('--- ⑤ 顶栏 = 模式切换的**唯一**入口 ---');
  check(mainDart.contains('await ModeController.i.load();'),
      'main() 在 runApp 前 load 模式（首帧即定下页签数/进阶项）');
  check(mainDart.contains('ChangeNotifierProvider<ModeController>.value(value: ModeController.i)'),
      'ModeController 已挂进 Provider 树（切换时全 App 重建）');
  check(mainDart.contains('unawaited(ModeController.i.setSimpleMode(wantSimple));'),
      '顶栏模式切换真的写单一事实源');
  check(mainDart.contains('l10n.modeBeginnerTitle') && mainDart.contains('l10n.modeAdvancedTitle'),
      '顶栏模式项为「入门模式 / 进阶模式」两项');

  print('');
  print('--- ⑥ 控制中心：只留「进阶设置」入口，不再放模式开关（0.84.0 改判）---');
  check(!settings.contains('fullModeTitle') && !settings.contains('fullModeSubtitle'),
      '「完整模式」开关（及其 ARB 键引用）已从控制中心移除');
  check(noModeWrite(settings),
      '★★ 控制中心**没有**模式开关（模式的唯一入口是顶栏；本页再放一个 = 同一件事两个入口）');
  check(!settings.contains('l10n.settingsAdvancedModeTitle') &&
          !settings.contains('l10n.settingsAdvancedModeSubtitle'),
      '原「进阶模式」开关的两个 ARB 键引用已删净');
  check(settings.contains('l10n.settingsModeHint'),
      '入门模式下留一行指路小字（settingsModeHint：模式切换在顶部工具栏）');
  check(advFromController(settings),
      '进阶入口按 ModeController 档位决定（顶栏一改，本页立刻重建）');
  check(settings.contains('const AdvancedSettingsScreen()'),
      '门控内 push 的是独立页 `AdvancedSettingsScreen`（引擎 / 记忆 / 灵魂已搬走）');
  // ★ 0.83.0 分层的**反证**：那一大坨参数不许还留在控制中心。
  check(!settings.contains('_baseUrlController') &&
          !settings.contains('settingsSecEngine') &&
          !settings.contains('settingsSecSoul'),
      '引擎 / 灵魂那批字段已从控制中心移除（否则"分两页"就是假的）');
  check(!settings.contains("p.setBool('simple_mode'"),
      '控制中心不再裸写模式键');

  print('');
  print('--- ⑦ 管理页：门控**粒度**（授权组常显 / 调参组仅进阶 · 0.121.0 / ADR-005）---');
  // 0.120.0：控制中心瘦身，「系统与能力」区块迁入管理页，整块仅进阶模式显示。
  // ★ 0.121.0 **改判粒度**（ADR-005 §2.3-1）：整块常显，门控下沉只包「调参组」。
  //   理由是 0.120.0 那一版有个洞：通知权限（`requestPermissions`）与日历只读
  //   授权（`requestRead`）的 UI 入口**全仓只有这两张卡**，而它们被门控包住 ⇒
  //   入门（默认）模式的主人在 App 里**没有任何路径**能完成授权。
  //   R14 管的是"开关没盖住所有消费路径"，这里更严重：**开关本身没有入口**。
  //
  // ★★ 判据强度（R50）：计数判据会被"数字对但位置错"糊弄（把门控挪去包授权组，
  //   计数照样是 3）。故本轮改成**区间判定** + 两条负控 —— 见 ⓪ 的正控。
  final manageGates =
      RegExp(r'if \(!mode\.simpleMode\)').allMatches(manage).length;
  check(manageGates == 3,
      '管理页有 3 处 `if (!mode.simpleMode)` 门控（自我进化 + 技能库/市场 spread + 调参组，实际 $manageGates）');
  final ranges = _gateRanges(manage);
  check(ranges.length == 2,
      '其中 2 处是 `...[]` 区间门控（自我进化那处是单行门控，不构成区间；实际 ${ranges.length}）');

  final callIdx =
      manage.indexOf('_buildSystemCapabilitySection(theme, isDark, l10n, mode)');
  check(callIdx >= 0 && !_gatedAt(manage, callIdx),
      '★★ 「系统与能力」区块的**调用点**不在门控区间内（整块常显 ⇒ 入门模式也看得到授权入口）');

  check(_gatedHits(manage, '_NotifySettingsCard()') == 0 &&
          _gatedHits(manage, '_CalendarSettingsCard()') == 0,
      '★★ 授权组两卡（通知设置 / 系统日历）**无一**落入门控区间'
      '（ADR-005 §3-3：凡调用 requestPermission 的 UI 点，所在 widget 不得被模式门控包住）');
  final authCallIdx = manage.indexOf('_buildAuthorizationCards(),');
  check(
      authCallIdx >= 0 &&
          manage.indexOf('_buildAuthorizationCards(),', authCallIdx + 1) < 0 &&
          !_gatedAt(manage, authCallIdx),
      '授权组由 `_buildAuthorizationCards(),` 在门控**之外**渲染，且只有一个调用点');
  check(_gatedHits(manage, '_buildAdvancedCapabilityItems(theme, l10n)') == 1,
      '调参组由门控包住（4 项仍只进阶展开 —— 需求不因放开授权组而被顺手删掉）');

  // ★★ 负控：证明上面两条判据是**活的**（不是恒真）
  // ★ 坑：Dart 的 `replaceFirst` **不解释** `$1`（那是 JS 语义），用字符串拼
  //   `r'$1'` 会把整段门控前缀**替换成字面量 `$1`** —— 毒注反而把门控删了，
  //   于是负控自己恒为假、还看不出来。必须 `replaceFirstMapped`（0.121.0 实撞）。
  final authPoison = manage.replaceFirstMapped(
      RegExp(r'if \(!mode\.simpleMode\) \.\.\.\['),
      (m) => '${m.group(0)}\n          const _NotifySettingsCard(),');
  check(authPoison != manage && _authCardGated(authPoison),
      '负控：把 `_NotifySettingsCard()` 塞回门控块 ⇒ 授权可达判据必须翻为**红**');
  final advPoison = manage.replaceFirst(
      RegExp(r'if \(!mode\.simpleMode\) \.\.\.\[\s*_buildAdvancedCapabilityItems'),
      '_buildAdvancedCapabilityItems');
  check(advPoison != manage &&
          _gatedHits(advPoison, '_buildAdvancedCapabilityItems(theme, l10n)') == 0,
      '负控：删掉调参组的门控 ⇒ 「仅进阶」判据必须翻为**红**');

  check(manage.contains('Provider.of<ModeController>(context)'),
      '管理页订阅 ModeController（切换模式时本页重建）');
  check(manage.contains('l10n.manageHistoryTitle') && manage.contains('l10n.manageProfileTitle'),
      '历史记录 / 绝密档案**保留**（未被门控误伤）');

  print('');
  print('--- ⑧ 跨端 ARB：退役键已清、新键齐备 ---');
  const locales = ['en', 'zh', 'zh_Hant', 'ja', 'vi'];
  const want = [
    'modePickerTooltip',
    'modeBeginnerTitle',
    'modeAdvancedTitle',
    'settingsAdvancedTitle',
    'settingsAdvancedSubtitle',
    'settingsModeHint',
    'settingsAdvancedEntryHint',
  ];
  // ★ 0.84.0 退役：`settingsAdvancedModeTitle` / `settingsAdvancedModeSubtitle`
  //   （那两个键是设置页模式开关的标签；开关已删 ⇒ 键也必须清掉，否则
  //   "界面已经没有那个开关了，翻译文件里还留着它的文案"）。
  const dead = ['settingsAdvancedModeTitle', 'settingsAdvancedModeSubtitle'];
  final missing = <String>[];
  final stale = <String>[];
  for (final c in locales) {
    final arb = _read('lib/l10n/app_$c.arb');
    for (final k in want) {
      if (!arb.contains('"$k"')) missing.add('$c:$k');
    }
    final gone = dead.every((k) => !arb.contains('"$k"'));
    if (!gone ||
        arb.contains('"fullModeTitle"') ||
        arb.contains('"fullModeSubtitle"')) {
      stale.add(c);
    }
  }
  check(missing.isEmpty,
      '五语种均含 ${want.length} 个模式键${missing.isEmpty ? '' : '（缺 $missing）'}');
  check(stale.isEmpty,
      '五语种均已清掉 fullMode* 与「进阶模式开关」两键${stale.isEmpty ? '' : '（仍有 $stale）'}');

  // ---------------------------------------------------------------------
  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
