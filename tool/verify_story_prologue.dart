// 纯 Dart 校验脚本：**章回剧场移植首启引导守卫**（0.100.0）。
// 运行：dart run tool/verify_story_prologue.dart
//
// ## 抓的是什么
//
// 0.100.0 把官网章回剧场《小荒出世·一梦游大荒》的序幕移植进 App 首启向导：
// 语言步之后插入「序幕」步（蛋三态 CustomPainter + 起名 + 掷性格 + 撤回演示卡）。
// 这条改动踩在两条老伤痕上，本脚本把它们钉住：
//
//   ① **步分派齐整（反 0.62.0）**：0.62.0 实证「底栏漏一个分支 ⇒ 自有 Key 用户被
//      `else → _finish()` 跳过四步、分身失声」。插步会平移所有分支，故每个步常量
//      **必须同时**出现在 `_buildStepBody` 的 switch 与 `_buildBottomBar` 的分派链里。
//   ② **几何同构**：蛋精灵几何逐条移植自 `landing/build.js:143-164` 的 `spriteArt()`。
//      本脚本直接 import 零依赖结构层 `lib/data/story_theater.dart`，把
//      `spriteShapes()` 还原的 SVG 元素串拿去 build.js **活原文**里逐条比对 ——
//      官网改了精灵而 App 没跟上（或反之）立刻翻红。
//   ③ **F14 修复在位**：重跑引导曾把自定义 `soul_*` 静默冲回默认值（0.62.0 同族），
//      `initState` 必须经 `_loadSoulPrefs()` 回填三个身份控制器。
//   ④ **只预填不直写**：序幕步不碰 prefs，`_finish()` 仍是 `soul_*` 唯一写入方；
//      掷性格只填 `_toneController`（语气建议，身份步可改）。
//   ⑤ **三态可构造**：egg / hatched / alert 在结构层与 painter 两侧都齐；
//      egg → alert（演示前）也播放孵化 crossfade。
//   ⑥ **F11 承重**：`TrialClient.applyTrialConfig(` / `setSimpleMode` 经 ModeController
//      且不裸写 `simple_mode`（承 verify_trial_switch / verify_mode_visibility）。
//   ⑦ **序幕交互与归巢（批次③）**：三句台词 + 起名接**智能体名**（不是主人名）+
//      骰子 + 撤回演示卡（纯 UI 剧场，无 DB/审计符号）+ 诚信免责常驻；
//      完成步头图 = hatched 精灵 + 归巢文案（check_circle 退场）。
//
// ## 为什么判据要能"翻面"（positive control）
//
// 纯文本判据最容易写成**恒真**表达式（拼错符号名 → contains 恒 false 被反转成恒 true），
// 那样守卫自己失效却报绿灯。故每条关键判据都配一条**正控**：把源码/原文改坏一处，
// 判据必须判出。
//
// ## 盲区（显式声明，不假装覆盖）
//
// 本脚本扫的是**源码文本 + 结构层几何**，不证明"真机上蛋画得对不对"（那要目视），
// 也不证明"ARB 五语齐 / KB 口径"——那两条在批次④随 ARB/KB 落盘后补进本脚本。

import 'dart:io';

import 'package:dahuang_ai/data/story_theater.dart';

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

/// 剥行注释。★ 负向后顾 `(?<!:)//` —— 普通 `//.*$` 会吃掉 `https://` 之后的整段。
String _decomment(String s) =>
    s.replaceAll(RegExp(r'(?<!:)//.*$', multiLine: true), '');

/// 取某个方法的源码块（签名 → 下一个 2 空格缩进的 `}`）。
/// 锚点用 `\n  }\n`：方法收尾就是它；内部闭括号都缩得更深，不会误截。
String _methodBody(String src, String signature) {
  final i = src.indexOf(signature);
  if (i < 0) return '';
  final end = src.indexOf('\n  }\n', i);
  return end < 0 ? '' : src.substring(i, end);
}

// ---------------------------------------------------------------------------
// 判据（提到顶层，便于正控直接调用）
// ---------------------------------------------------------------------------

/// 步常量表：解析 `static const int _stepX = N;`。
Map<String, int> stepConstants(String src) {
  final out = <String, int>{};
  for (final m
      in RegExp(r'static const int (_step\w+|_lastStep) = (\d+);').allMatches(src)) {
    out[m.group(1)!] = int.parse(m.group(2)!);
  }
  return out;
}

bool stepConstantsAreNineSteps(Map<String, int> consts) {
  const expected = <String, int>{
    '_stepLanguage': 0,
    '_stepPrologue': 1,
    '_stepWelcome': 2,
    '_stepModel': 3,
    '_stepKey': 4,
    '_stepIdentity': 5,
    '_stepBackup': 6,
    '_stepSocial': 7,
    '_lastStep': 8,
  };
  if (consts.length != expected.length) return false;
  for (final e in expected.entries) {
    if (consts[e.key] != e.value) return false;
  }
  return true;
}

/// 八个非完成步常量（完成步走 default / else，单独判）。
const List<String> _stepConsts = [
  '_stepLanguage',
  '_stepPrologue',
  '_stepWelcome',
  '_stepModel',
  '_stepKey',
  '_stepIdentity',
  '_stepBackup',
  '_stepSocial',
];

/// ① 步骤体 switch：八个步一个 case 都不能少；完成步走 default → _buildDone。
bool switchDispatchComplete(String stepBody) {
  for (final c in _stepConsts) {
    if (!stepBody.contains('case $c:')) return false;
  }
  return stepBody.contains('return _buildDone(');
}

/// ①b 底栏分派链：八个步都要出现在链里（反 0.62.0 漏分支）；
///     完成步以 `_lastStep` 出现在按钮文案判定里。
bool bottomBarDispatchComplete(String bottomBar) {
  for (final c in _stepConsts) {
    if (!bottomBar.contains(c)) return false;
  }
  return bottomBar.contains('_lastStep');
}

/// ② 进度条 labels 与步数齐平（9 个 step 标签 + Prologue），
///     且步骤指示器用 `_lastStep + 1` 算总数（不手写 8/9）。
bool labelsComplete(String progressBody) {
  final n = RegExp(r'l10n\.onboardingStep(?!Indicator)\w+')
      .allMatches(progressBody)
      .length;
  return n == 9 &&
      progressBody.contains('l10n.onboardingStepPrologue') &&
      RegExp(r'onboardingStepIndicator\(\s*_step \+ 1,\s*_lastStep \+ 1')
          .hasMatch(progressBody);
}

/// ③ F14：initState 调 `_loadSoulPrefs()`；该 loader 读三个 soul_ 键、
///     写三个控制器，并共用 `SetupService.resolveStoredOrDefault`（与地址回填同款判据）。
bool soulPrefsBackfillWired(String src) {
  final init = _methodBody(src, 'void initState()');
  final loader = _methodBody(src, 'Future<void> _loadSoulPrefs()');
  return init.contains('_loadSoulPrefs();') &&
      loader.contains("'soul_master_name'") &&
      loader.contains("'soul_agent_name'") &&
      loader.contains("'soul_tone'") &&
      loader.contains('_masterNameController.text =') &&
      loader.contains('_agentNameController.text =') &&
      loader.contains('_toneController.text =') &&
      loader.contains('SetupService.resolveStoredOrDefault(');
}

/// ④ 序幕步只预填不直写：方法体内不出现任何 prefs 写入。
bool prologueNoDirectWrite(String prologueBody) =>
    !prologueBody.contains('setString(') &&
    !prologueBody.contains('setBool(') &&
    !prologueBody.contains('SharedPreferences');

/// ④b 序幕步真的挂上蛋精灵（防"加了步却没画蛋"）。
bool prologueMountsSprite(String prologueBody) =>
    prologueBody.contains('StorySprite(');

/// ④c `_finish()` 仍是 soul_* 唯一写入方（三处写入都在）。
bool finishStillUniqueWriter(String src) {
  final body = _methodBody(src, 'Future<void> _finish()');
  return body.contains("prefs.setString('soul_master_name'") &&
      body.contains("prefs.setString('soul_agent_name'") &&
      body.contains("prefs.setString('soul_tone'");
}

/// ⑤ 结构层三态齐：`spriteShapes` 的 switch 恰好覆盖三个枚举值。
bool theaterCoversThreeStates(String theaterSrc) {
  final cases = RegExp(r'case StorySpriteState\.(\w+):')
      .allMatches(theaterSrc)
      .map((m) => m.group(1)!)
      .toSet();
  return cases.length == 3 &&
      cases.containsAll(const {'egg', 'hatched', 'alert'});
}

/// ⑤b painter 三态齐：绘制层三个状态都真的被画。
bool painterCoversThreeStates(String painterSrc) =>
    painterSrc.contains('StorySpriteState.egg') &&
    painterSrc.contains('StorySpriteState.hatched') &&
    painterSrc.contains('StorySpriteState.alert');

/// ② 几何同构：结构层还原的 SVG 元素串必须逐条出现在 build.js 活原文里。
bool geometryMatches(List<SpriteShape> shapes, String buildJs) {
  for (final s in shapes) {
    if (!buildJs.contains(s.svgElement())) return false;
  }
  return true;
}

/// ⑥ F11 承重（onboarding 侧）：落库走 applyTrialConfig；模式写走 ModeController。
bool onboardingKeepsF11(String src) =>
    src.contains('TrialClient.applyTrialConfig(') &&
    src.contains('await ModeController.i.setSimpleMode(true);') &&
    !src.contains("setBool('simple_mode'");

/// ⑨a 序幕步挂诚信免责（R27：主张可证实；「情景演绎」必须显形）。
bool prologueCarriesDisclaimer(String prologueBody) =>
    prologueBody.contains('l10n.storyDisclaimer');

/// ⑨b 撤回演示卡是**纯 UI 剧场**：无 DB / 审计 / 服务符号、无 prefs 写入。
bool undoCardIsPureTheatre(String cardBody) {
  const forbidden = <String>[
    'DBHelper',
    'saveAmbassador',
    'audit',
    'WorldService',
    'RadarService',
    'AgentService',
    'insert(',
    'setString(',
    'setBool(',
    'SharedPreferences',
  ];
  for (final t in forbidden) {
    if (cardBody.contains(t)) return false;
  }
  return true;
}

/// ⑨c 序幕交互接线齐：三句台词 + 起名接**智能体名** + 骰子 + 撤回卡都挂上。
bool prologueInteractionsWired(String prologueBody) =>
    prologueBody.contains('l10n.storyAwakenLine1') &&
    prologueBody.contains('l10n.storyAwakenLine2') &&
    prologueBody.contains('l10n.storyAwakenLine3') &&
    prologueBody.contains('controller: _agentNameController') &&
    prologueBody.contains('_rollTrait') &&
    prologueBody.contains('_buildUndoDemoCard');

/// ⑨d 骰子只**预填**语气框（不直写 prefs）。
bool diceOnlyPrefillsTone(String src) {
  final body = _methodBody(src, 'void _rollTrait()');
  return body.contains('_toneController.text =') &&
      !body.contains('setString(') &&
      !body.contains('setBool(');
}

/// ⑨e 归巢头图：完成步挂 hatched 精灵 + 两句归巢文案，check_circle 已退场。
bool doneStepHasFinaleHeader(String src) {
  final body = _methodBody(src, 'Widget _buildDone(');
  return body.contains('StorySprite(') &&
      body.contains('StorySpriteState.hatched') &&
      body.contains('l10n.storyFinaleTitle') &&
      body.contains('l10n.storyFinaleBody') &&
      !body.contains('Icons.check_circle');
}

/// ⑨f 孵化进 alert 也播 crossfade（egg → 任何非蛋态统一走 forward）。
bool hatchAnimatesIntoAlert(String painterSrc) {
  final body = _methodBody(painterSrc, 'void didUpdateWidget(');
  final gate = body.indexOf('oldWidget.state == StorySpriteState.egg');
  final fwd = body.indexOf('_hatch.forward(from: 0)');
  return gate >= 0 && fwd >= 0 && gate < fwd;
}

void main() {
  print('== verify_story_prologue (章回剧场移植首启引导 · 0.100.0) ==');

  final onb = _read('lib/ui/onboarding_screen.dart');
  final onbCode = _decomment(onb);
  final theater = _read('lib/data/story_theater.dart');
  final painter = _read('lib/ui/story_sprite.dart');
  final buildJs = _read('landing/build.js');

  print('--- ⓿ 文件齐备 ---');
  check(onb.isNotEmpty && theater.isNotEmpty && painter.isNotEmpty && buildJs.isNotEmpty,
      '源文件齐备（onboarding / story_theater / story_sprite / build.js）');

  print('--- ① 步常量 = 九步 0..8（语言 0 → 序幕 1 → … → 完成 8）---');
  final consts = stepConstants(onbCode);
  check(stepConstantsAreNineSteps(consts),
      '步常量逐值符合预期${stepConstantsAreNineSteps(consts) ? '' : ' → 实际 $consts'}');

  print('--- ② 两处分派齐整（反 0.62.0「漏分支 ⇒ 直接 _finish」）---');
  final stepBody = _methodBody(onbCode, 'Widget _buildStepBody(');
  final bottomBar = _methodBody(onbCode, 'Widget _buildBottomBar(');
  check(stepBody.isNotEmpty && switchDispatchComplete(stepBody),
      '步骤体 switch：八个步常量各有一个 case，完成步走 _buildDone');
  check(bottomBar.isNotEmpty && bottomBarDispatchComplete(bottomBar),
      '底栏分派链：八个步常量都在链里（含序幕），完成步经 _lastStep 判定');

  print('--- ③ 进度条 labels 与步数齐平 ---');
  final progressBody = _methodBody(onbCode, 'Widget _buildProgress(');
  check(progressBody.isNotEmpty && labelsComplete(progressBody),
      'labels 恰 9 个（含 onboardingStepPrologue），指示器总数走 _lastStep + 1');

  print('--- ④ F14：soul_* 回填在位（修「重跑引导冲掉自定义名字/语气」）---');
  check(soulPrefsBackfillWired(onbCode),
      'initState 调 _loadSoulPrefs()，loader 读三键写三控制器且共用 resolveStoredOrDefault');

  print('--- ⑤ 序幕步只预填不直写 + 蛋精灵真的挂上 ---');
  final prologue = _methodBody(onbCode, 'Widget _buildPrologue(');
  check(prologue.isNotEmpty, '_buildPrologue 方法存在');
  check(prologue.isNotEmpty && prologueNoDirectWrite(prologue),
      '序幕步无任何 prefs 直写（setString/setBool/SharedPreferences 全无）');
  check(prologue.isNotEmpty && prologueMountsSprite(prologue),
      '序幕步挂上了 StorySprite（不是空步）');
  check(finishStillUniqueWriter(onbCode),
      '_finish() 仍是 soul_* 唯一写入方（三处写入都在）');

  print('--- ⑥ 蛋三态可构造（结构层 + painter 两侧）---');
  check(theaterCoversThreeStates(theater),
      'spriteShapes switch 恰好覆盖 egg / hatched / alert 三态');
  check(painterCoversThreeStates(painter),
      'painter 三态都被绘制（egg / hatched / alert）');

  print('--- ⑦ 几何同构：App 精灵 vs 官网 build.js 活原文 ---');
  for (final state in StorySpriteState.values) {
    final shapes = spriteShapes(state);
    check(geometryMatches(shapes, buildJs),
        '${state.name} 态 ${shapes.length} 个元素全部在 build.js 原文里'
        '${geometryMatches(shapes, buildJs) ? '' : ' → 缺 ${shapes.where((s) => !buildJs.contains(s.svgElement())).map((s) => s.svgElement()).toList()}'}');
  }

  print('--- ⑧ F11 承重（承 verify_trial_switch / verify_mode_visibility）---');
  check(onboardingKeepsF11(onbCode),
      '引导页经 applyTrialConfig 落库；模式写走 ModeController；不裸写 simple_mode');

  print('--- ⑨ 序幕交互与归巢头图（批次③）---');
  final undoCard = _methodBody(onbCode, 'Widget _buildUndoDemoCard(');
  check(prologue.isNotEmpty && prologueCarriesDisclaimer(prologue),
      '序幕步常驻诚信免责（storyDisclaimer）');
  check(undoCard.isNotEmpty && undoCardIsPureTheatre(undoCard),
      '撤回演示卡纯 UI 剧场：无 DB / 审计 / 服务 / prefs 符号');
  check(prologue.isNotEmpty && prologueInteractionsWired(prologue),
      '序幕接线齐：三句台词 + 起名接智能体名 + 骰子 + 撤回卡');
  check(diceOnlyPrefillsTone(onbCode),
      '掷性格只预填语气框（_toneController），不直写 prefs');
  check(doneStepHasFinaleHeader(onbCode),
      '完成步归巢头图：hatched 精灵 + 两句归巢文案，check_circle 退场');
  check(hatchAnimatesIntoAlert(painter),
      'egg → alert 也播放孵化 crossfade（不瞬间显形）');

  print('--- ⑩ 正控：把好副本改坏一处，判据必须判出 ---');
  final brokenBar =
      bottomBar.replaceFirst('_step == _stepPrologue ||\n', '');
  check(!bottomBarDispatchComplete(brokenBar),
      '正控①：抽掉底栏序幕分支 ⇒ 判出 ✓');
  final brokenSwitch =
      stepBody.replaceFirst('case _stepPrologue:\n        return _buildPrologue(theme, isDark);\n', '');
  check(!switchDispatchComplete(brokenSwitch),
      '正控②：抽掉 switch 序幕 case ⇒ 判出 ✓');
  final brokenProgress =
      progressBody.replaceFirst('l10n.onboardingStepPrologue,\n', '');
  check(!labelsComplete(brokenProgress),
      '正控③：删掉进度条序幕标签 ⇒ 判出 ✓');
  final brokenInit = onbCode.replaceFirst('    _loadSoulPrefs();\n', '');
  check(!soulPrefsBackfillWired(brokenInit),
      '正控④：initState 不再调 _loadSoulPrefs ⇒ 判出 ✓');
  final brokenPrologue = prologue.replaceFirst(
      'onTap: _hatchEgg,', "onTap: () { prefs.setString('soul_agent_name', x); },");
  check(!prologueNoDirectWrite(brokenPrologue),
      '正控⑤：往序幕步塞一处 prefs 直写 ⇒ 判出 ✓');
  final brokenTheater =
      theater.replaceFirst('case StorySpriteState.alert:', 'case StorySpriteState.hatched:');
  check(!theaterCoversThreeStates(brokenTheater),
      '正控⑥：结构层丢掉 alert 态 ⇒ 判出 ✓');
  final brokenJs = buildJs.replaceFirst('rx="33"', 'rx="34"');
  check(!geometryMatches(spriteShapes(StorySpriteState.egg), brokenJs),
      '正控⑦：build.js 改坏一个蛋壳半径 ⇒ 判出 ✓');
  final brokenFinish = onbCode.replaceFirst(
      "      await prefs.setString('soul_tone', tone);\n", '');
  check(!finishStillUniqueWriter(brokenFinish),
      '正控⑧：_finish 少写一处 soul_* ⇒ 判出 ✓');
  final brokenDisclaimer =
      prologue.replaceFirst('l10n.storyDisclaimer', 'l10n.storyEggHint');
  check(!prologueCarriesDisclaimer(brokenDisclaimer),
      '正控⑨：序幕步抹掉免责小字 ⇒ 判出 ✓');
  final brokenCard =
      undoCard.replaceFirst('child: Text(', 'child: DBHelper.x(Text(');
  check(!undoCardIsPureTheatre(brokenCard),
      '正控⑩：往撤回演示卡塞 DBHelper ⇒ 判出 ✓');
  final brokenDice = onbCode.replaceFirst(
      '      _toneController.text = _traitText(AppLocalizations.of(context), trait);\n',
      "      prefs.setString('soul_tone', _traitText(AppLocalizations.of(context), trait));\n");
  check(!diceOnlyPrefillsTone(brokenDice),
      '正控⑪：骰子改成直写 prefs ⇒ 判出 ✓');
  final brokenDone = onbCode.replaceFirst(
      'StorySprite(state: StorySpriteState.hatched, size: 116)',
      'Icon(Icons.check_circle, color: theme.accentColor, size: 56)');
  check(!doneStepHasFinaleHeader(brokenDone),
      '正控⑫：完成步换回 check_circle ⇒ 判出 ✓');
  final brokenHatch = painter.replaceFirst(
      'oldWidget.state == StorySpriteState.egg',
      'widget.state == StorySpriteState.alert');
  check(!hatchAnimatesIntoAlert(brokenHatch),
      '正控⑬：alert 退回瞬间显形 ⇒ 判出 ✓');
  final brokenName =
      prologue.replaceFirst('controller: _agentNameController', 'controller: _masterNameController');
  check(!prologueInteractionsWired(brokenName),
      '正控⑭：起名框错接主人名（蛋名必须是智能体名）⇒ 判出 ✓');

  print('');
  print('== 结果：PASS=$_pass FAIL=$_fail ==');
  if (_fail > 0) throw StateError('verification failed');
}
