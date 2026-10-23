// 0.80.0 守卫：**结构化输出不得压掉工具调用** + **设置类工具不得谎报成功**。
//
// 缘起（真机复现）：主人发「改成粉色主题」，分身只回话不动手、还自认"忘了真正
// 执行"。根因 = 一次请求里同时下发 `response_format(json_schema, strict)` 与
// `tools`，被 DeepSeek / Kimi / DashScope 等端点优先满足前者 ⇒ `tool_calls`
// 永不产生。另有一条独立缺陷：`change_system_settings` 对 `app_theme` 不校验
// 就写 prefs 并回报"底层参数已篡改完毕"（而色板里根本没有"粉"）⇒ **假成功**。
//
// 本脚本把这些不变量钉在**源码序**上，防止下一轮"改回注释、改不回行为"：
//   ① 运行时：有工具 ⇒ 不下发 schema（`chooseOutputSchema`），且 `turn` 真的用它；
//   ② 宿主：把"有没有工具"注入运行时（同一来源 = 工具注册表）；
//   ③ 色板：`粉/粉色/pink/rose` 必须归一到 red（不新增第 10 色）；
//   ④ 工具：`app_theme` 走 `themeKeyOrNull` 校验；失败项存在时**不得**走到成功话术
//      （次序判据：`problems` 分支必须出现在"已篡改完毕"之前）；
//   ⑤ 提示词：ReAct 段必须点名 `change_system_settings`。
//   ⑧ 0.85.0：设置工具扩到 **App 自操作面** —— 非隐私键（语言/语音/雷达三通道）
//      默认可直呼，且**只走各自既有唯一写入方**（LanguageController / TtsService /
//      RadarService），不许绕过去写 prefs；
//   ⑨ 每次写入必须**回读校验**，不一致即报失败（拒绝假成功）；
//   ⑩★★★ 隐私能力（邮箱/手机控制/通知短信）**只指路、不代开** —— 开启分支必须
//      先把「让你自己开」写进 guides 并 continue，且排在「关闭」写入**之前**；
//   ⑪ 关闭隐私能力必须走**各自唯一写入方**；
//   ⑫ 工具描述要把「两类」写给模型看；⑬ KB 的 `builtin_tools` 条目要把两类写给用户。
//
// 源文本扫描型脚本必须带**正控**（把好副本人为改坏，判据必须判出），否则
// 匹配式一坏就"扫到 0 处 → 恒绿"。
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
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

// ------------------------------------------------------------------
// 判据（纯函数，可被正控喂坏副本）
// ------------------------------------------------------------------

/// ① 运行时：存在 `chooseOutputSchema`，语义是"有工具 ⇒ null"，且 `turn` 采用它。
bool runtimeChoosesToolFirst(String src) {
  final def = RegExp(r'hasTools\s*\?\s*null\s*:\s*AgentReply\.outputSchema');
  return src.contains('chooseOutputSchema') &&
      def.hasMatch(src) &&
      src.contains('chooseOutputSchema(hasTools:') &&
      src.contains('outputSchema: outputSchema');
}

/// ② 宿主把"有工具"注入运行时。
///
/// ★★ 0.90.0（专家 #5）：`hasTools` 必须与 `_agent.tools` 出自**同一份注册表快照**，
///   否则"建 tools"与"定 hasTools"各取一次即时快照，在 50ms 防抖重建窗口里会短暂
///   不一致 —— schema 决策（有工具就不发结构化 schema）与工具实况错配。
///   判据三连（缺一不可）：
///     a) 运行时读的是缓存的 `_agentHasTools`（**不再**就地取快照）；
///     b) `_rebuildAgent()` 里**只出现一次** `_toolRegistry.snapshot()`；
///     c) 同一 `snapshot` 既喂 `_agentHasTools`、又喂 `tools` 构造。
bool hostInjectsHasTools(String src) {
  final readsCachedFlag = src.contains('hasTools: () => _agentHasTools');
  final noInlineSnapshot =
      !src.contains('hasTools: () => _toolRegistry.snapshot().isNotEmpty');
  final oneSnapshot = RegExp(r'_toolRegistry\.snapshot\(\)').allMatches(src).length == 1;
  final sameSnapshot =
      src.contains('final snapshot = _toolRegistry.snapshot();') &&
      src.contains('_agentHasTools = snapshot.isNotEmpty;') &&
      src.contains('for (final spec in snapshot)');
  return readsCachedFlag && noInlineSnapshot && oneSnapshot && sameSnapshot;
}

/// ③ 粉色别名统一到 red。
bool pinkAliasesToRed(String src) =>
    RegExp(r"'粉'\s*:\s*'red'").hasMatch(src) &&
    RegExp(r"'粉色'\s*:\s*'red'").hasMatch(src) &&
    RegExp(r"'pink'\s*:\s*'red'").hasMatch(src);

/// ④-a 设置工具走唯一判据校验（不是自己写一套 contains）。
bool settingsValidatesTheme(String src) =>
    src.contains('themeKeyOrNull(raw)') && src.contains('problems.add(');

/// ④-b **次序**：失败分支必须写在成功话术之前（否则仍可能谎报成功）。
///
/// ★★ 锚点必须**只可能出现在代码里**（带 `return "` 前缀），**不能**用裸文案。
///   本脚本初版拿 `'底层参数已篡改完毕'` 当锚，结果**被自己新写的注释**（在
///   前言里引用了这句旧话术）拉到了失败分支**之前** ⇒ 守卫假 FAIL。
///   这正是本仓的老坑（0.73.0「存在性判据不用会被复用的文本」）——见正控⑦。
bool settingsFailureBeforeSuccess(String src) {
  final iFail = src.indexOf('if (problems.isNotEmpty) {');
  final iOk = src.indexOf('return "【最高权限系统反馈】底层参数已篡改完毕');
  return iFail >= 0 && iOk >= 0 && iFail < iOk;
}

/// ⑤ ReAct 段点名设置工具。
bool promptMentionsSettings(String src) =>
    src.contains('必须真的调用 `change_system_settings`');

/// ⑦ KB 的 `theme` 条目必须把**色板（含 pink 别名）**讲给用户。
///
/// ★ 0.78.0 红线：「**能力已实现 ≠ 使用者知道它存在**」—— 本轮真机上"改成粉色"
///   失败的半边原因，正是**没有任何地方告诉用户支持哪些颜色**（"粉"在色板里
///   并不存在）。修了行为却不更新 KB ⇒ 下一个人还会踩同一个坑。
bool kbThemeTellsPalette(String src) =>
    src.contains("HelpEntry('theme'") &&
    src.contains('red, orange, yellow, green, cyan, blue, purple, white, black') &&
    src.contains('"pink" maps to the red palette');

/// ⑧ 0.85.0：设置工具覆盖"App 自操作面"，且每类只走**既有唯一写入方**。
bool settingsCoversAppSelfPlane(String src) =>
    src.contains('LanguageController.i.setCode(code)') &&
    src.contains('TtsService.i.setEnabled(v)') &&
    src.contains('RadarService.instance.setChannel(') &&
    src.contains("'radar_near_field': 'link_near_field_enabled'") &&
    src.contains("'radar_lan': 'link_lan_enabled'") &&
    src.contains("'radar_cloud': 'link_cloud_enabled'");

/// ⑨ ★★ 每次写入**回读校验**（写后读回比对），不一致必须报失败 —— 拒绝假成功。
///    ★ 回读**不得**退化成 `prefs.getBool(<动态键>)`：那会引入 `verify_data_keys`
///      明令禁止的"动态键盲区"。雷达回读改走 `RadarService` 自身状态（`radarOn`）。
bool settingsVerifiesByReadBack(String src) =>
    RegExp(r'写入后回读不一致').allMatches(src).length >= 2 &&
    src.contains('prefs.getBool(kTtsEnabledKey)') &&
    src.contains('final back = radarOn(e.value);') &&
    !src.contains('prefs.getBool(e.value)') &&
    !src.contains('prefs.getBool(k) ?? false');

/// ⑩ ★★★ 隐私能力**只指路、不代开**：开启分支先把"让你自己开"写进 guides 并 continue，
///     **排在**"关闭"写入（走唯一写入方）之前；且文案**点名能力与入口**。
bool privacySwitchGuidesNotOpens(String src) {
  final iGuide = src.indexOf('我不能替你开启');
  final iDisable = src.indexOf('await setMailEnabled(false);');
  return iGuide >= 0 &&
      iDisable >= 0 &&
      iGuide < iDisable &&
      src.contains("'mail': ['邮箱代管'") &&
      src.contains("'phone_control': ['手机控制（无障碍）', '设置 → 手机控制']") &&
      src.contains("'notify_sms': ['通知 / 短信读取'");
}

/// ⑪ 关闭隐私能力走**各自唯一写入方**（不许绕过去写 prefs）。
bool privacyOffUsesCanonicalWriters(String src) =>
    src.contains('await setMailEnabled(false);') &&
    src.contains('DeviceControlService.setUserEnabled(false)') &&
    src.contains('NotificationSmsService.setUserEnabled(false)');

/// ⑫ 工具描述把"两类"写给模型看（能力要可发现）。
bool descriptionTellsTwoClasses(String src) =>
    src.contains('【隐私能力：★ 你**不能**替主人开启，只能指路】') &&
    src.contains('【运行开关：默认可直接改】') &&
    src.contains('- language:') &&
    src.contains('- tts:');

/// ⑬ KB `builtin_tools` 条目把两类讲给用户（R15：能力变化必须同一提交更新 KB）。
bool kbTellsTwoClasses(String src) =>
    src.contains("HelpEntry('builtin_tools'") &&
    src.contains('Two classes to remember');

void main() {
  final runtime =
      _read('packages/pocket_harness/lib/src/runtime/agent_runtime.dart');
  final agent = _read('lib/core/agent_service.dart');
  final theme = _read('lib/core/theme_provider.dart');
  final kb = _read('lib/core/system_knowledge.dart');
  final test = _read('test/theme_key_test.dart');
  final pkgTest = _read('packages/pocket_harness/test/agent_runtime_test.dart');

  // 文件存在性（读不到 = 路径写错 → 后面判据会全 FAIL，先显形）
  check(runtime.isNotEmpty, '读得到 agent_runtime.dart');
  check(agent.isNotEmpty, '读得到 agent_service.dart');
  check(theme.isNotEmpty, '读得到 theme_provider.dart');

  print('  --- ① 运行时：有工具就不发 schema ---');
  check(runtimeChoosesToolFirst(runtime),
      'chooseOutputSchema 语义 = hasTools ? null : schema，且 turn 采用');

  print('  --- ② 宿主注入 hasTools ---');
  check(hostInjectsHasTools(agent), 'agent_service 注入工具注册表来源');

  print('  --- ③ 粉色别名 ---');
  check(pinkAliasesToRed(theme), '粉/粉色/pink → red（不新增第 10 色）');
  check(theme.contains('String? themeKeyOrNull('), '存在唯一判据 themeKeyOrNull');
  check(theme.contains('legacyThemeIds[t] ?? legacyThemeIds[lower] ?? lower'),
      'setTheme/loadTheme 共用同一张归一表（大小写容错）');

  print('  --- ④ 设置工具：校验 + 不谎报 ---');
  check(settingsValidatesTheme(agent), 'app_theme 走 themeKeyOrNull 校验');
  check(settingsFailureBeforeSuccess(agent),
      '失败分支在成功话术之前（次序不可逆）');
  check(agent.contains('【设置未全部生效】'), '有明确的失败回灌文案');

  print('  --- ⑤ 提示词点名 ---');
  check(promptMentionsSettings(agent), 'ReAct 段点名 change_system_settings');

  print('  --- ⑥ 测试在册 ---');
  check(test.contains("themeKeyOrNull('粉')"), '主仓单测覆盖粉色别名');
  check(pkgTest.contains("containsKey('response_format')"),
      '包内单测用真实请求体钉住 response_format 有无');

  print('  --- ⑦ KB 把色板讲给用户 ---');
  check(kb.isNotEmpty, '读得到 system_knowledge.dart');
  check(kbThemeTellsPalette(kb), 'theme 条目列出 9 色 + pink 别名（能力要可发现）');

  print('  --- ⑧–⑬ 0.85.0 App 自操作面（默认可直呼 / 隐私只指路） ---');
  check(settingsCoversAppSelfPlane(agent),
      '非隐私键走唯一写入方（LanguageController / TtsService / RadarService 三通道）');
  check(settingsVerifiesByReadBack(agent), '每次写入都做回读校验（拒绝假成功）');
  check(privacySwitchGuidesNotOpens(agent),
      '隐私能力只指路不代开（开启分支在关闭写入之前，且点名能力+入口）');
  check(privacyOffUsesCanonicalWriters(agent), '关闭隐私能力走各自唯一写入方');
  check(descriptionTellsTwoClasses(agent), '工具描述把两类写给模型看');
  check(kbTellsTwoClasses(kb), 'KB builtin_tools 条目把两类讲给用户');

  // ------------------------------------------------------------------
  // 正控：把好副本**人为改坏**，判据必须判出
  // ------------------------------------------------------------------
  print('  --- positive control ---');
  check(!runtimeChoosesToolFirst(
          runtime.replaceAll('hasTools ? null : AgentReply.outputSchema',
              'AgentReply.outputSchema')),
      '正控①：改回"永远带 schema" ⇒ 判工具不优先 ✓');
  check(!hostInjectsHasTools(agent.replaceAll('hasTools: () => _agentHasTools', '')),
      '正控②：抹掉宿主注入 ⇒ 判出 ✓');
  // 正控②b：**回退到旧写法**（运行时就地取快照）⇒ 必须判出（#298 的真正护栏）。
  check(
      !hostInjectsHasTools(agent.replaceAll('hasTools: () => _agentHasTools',
          'hasTools: () => _toolRegistry.snapshot().isNotEmpty')),
      '正控②b：hasTools 退回就地取快照 ⇒ 判出 ✓');
  // 正控②c：**双取快照**（账本与 tools 各取一次）⇒ 必须判出。
  check(
      !hostInjectsHasTools(agent.replaceAll('_agentHasTools = snapshot.isNotEmpty;',
          '_agentHasTools = _toolRegistry.snapshot().isNotEmpty;')),
      '正控②c：hasTools 与 tools 各取一次快照 ⇒ 判出 ✓');
  check(!pinkAliasesToRed(theme.replaceAll("'粉': 'red',", '')),
      '正控③：删掉粉色别名 ⇒ 判出 ✓');
  check(!settingsValidatesTheme(agent.replaceAll('themeKeyOrNull(raw)', 'raw')),
      '正控④：退回不校验 ⇒ 判出 ✓');
  check(
      !settingsFailureBeforeSuccess(
          agent.replaceAll('if (problems.isNotEmpty) {', 'if (false) {')),
      '正控⑤：让失败分支永不进入 ⇒ 判出 ✓');
  check(!promptMentionsSettings(agent.replaceAll('必须真的调用', '可选调用')),
      '正控⑥：抹掉提示词指引 ⇒ 判出 ✓');
  // 正控⑦：**防"被自己的注释骗到"**。在失败分支**之前**插一条引用旧成功话术的
  //   注释；code-only 锚必须不受影响（因为注释里没有 `return "` 那个形态）。
  check(
      settingsFailureBeforeSuccess(agent.replaceFirst(
          '        final List<String> problems = [];',
          '        // 旧实现照样回「底层参数已篡改完毕！」\n'
              '        final List<String> problems = [];')),
      '正控⑦：前言里的同名注释不影响次序判据（code-only 锚）✓');
  check(
      !kbThemeTellsPalette(kb.replaceAll(
          'red, orange, yellow, green, cyan, blue, purple, white, black', '')),
      '正控⑧：KB 抹掉色板枚举 ⇒ 判出 ✓');

  check(!settingsCoversAppSelfPlane(agent.replaceAll('TtsService.i.setEnabled(v)', '')),
      '正控⑨：抹掉 tts 唯一写入方 ⇒ 判出 ✓');
  check(!settingsVerifiesByReadBack(agent.replaceAll('写入后回读不一致', '已生效')),
      '正控⑩：抹掉回读校验 ⇒ 判出 ✓');
  check(
      !settingsVerifiesByReadBack(
          agent.replaceAll('final back = radarOn(e.value);',
              'final back = prefs.getBool(e.value) ?? false;')),
      '正控⑩b：回读退回动态键 prefs.getBool(e.value) ⇒ 判出 ✓');
  check(
      !privacySwitchGuidesNotOpens(agent.replaceAll('我不能替你开启', '已为你开启')),
      '正控⑪：把"只指路"改成"已开启" ⇒ 判出 ✓');
  check(
      !privacyOffUsesCanonicalWriters(
          agent.replaceAll('DeviceControlService.setUserEnabled(false)', '')),
      '正控⑫：关闭绕过唯一写入方 ⇒ 判出 ✓');
  check(!descriptionTellsTwoClasses(agent.replaceAll('【运行开关：默认可直接改】', '')),
      '正控⑬：描述抹掉类别标记 ⇒ 判出 ✓');
  check(!kbTellsTwoClasses(kb.replaceAll('Two classes to remember', '')),
      '正控⑭：KB 抹掉两类说明 ⇒ 判出 ✓');
  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
