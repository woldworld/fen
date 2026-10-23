// 0.87.0 守卫：智能体**自省**（`list_my_tools`）与**自检**（`run_diagnostics`）。
//
// 缘起（主人指令「逐步进行」· 续 0.85.0/0.86.0）：
//   0.85.0 让智能体能"改设置"，0.86.0 让智能体能"开页面"，本轮补两条**自我认知**能力：
//     · `list_my_tools` —— 主人问"你都能做什么"时，读**真实注册表**回答（不凭记忆编）；
//     · `run_diagnostics` —— 主人问"哪儿不对"时，真跑一遍**只读**底座探针。
//   两条都不改数据、不出网 ⇒ `normal` 档、**无闸**（与 0.85.0/0.86.0 同口径）。
//
// 本脚本把这几条不变量钉在**源码序**上：
//   ① `list_my_tools`：normal 档 + 无 grantKey + 清单来自**真实注册表**
//      （`toolRegistry.snapshot()`）—— "能力清单与真实能力同源"，绝不手抄；
//   ② `run_diagnostics`：normal 档 + 无 grantKey + 复用**同一事实源**
//      （`runDiagnostics(buildAppProbes())` + `formatDiagnostics()`）—— 不另写一套探针；
//   ③ 依赖接线：agent_service 必须 import `diagnostics.dart` / `diagnostic_probes.dart`；
//   ④ `switch_social_scenario` 的描述要把「假面/人设」讲全（主人 0.87.0 拍板：
//      `mask_profile` **不新增第二入口**，就在此工具内设定）—— 治的是 0.78.0
//      那条「能力已实现 ≠ 使用者知道它存在」；
//   ⑤ KB 同一提交更新：把"问我有哪些工具 / 让我跑自检"讲给用户 + kbVersion bump。
//
// ★ 源文本扫描型脚本必须带**正控**（把好副本人为改坏，判据必须判出），否则匹配式
//   一坏就"扫到 0 处 → 恒绿"。
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

/// 剥注释：判据锚点要落在**真代码 / 真字符串**上，不能被自己写的注释骗到
/// （本仓老坑「存在性判据不用会被复用的文本」——见 verify_agent_tools 正控⑦）。
String _stripComments(String s) => s
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// 取某工具 `name: '<name>'` 到**下一个** `_registerBuiltin(` 之间的源码块。
/// ★ 不能用 `));` 当右界：`runDiagnostics(buildAppProbes())` 里就含 `))`，会**截短**。
String _toolBlock(String src, String name) {
  final i = src.indexOf("name: '$name'");
  if (i < 0) return '';
  final j = src.indexOf('_registerBuiltin(', i + 1);
  return j < 0 ? src.substring(i) : src.substring(i, j);
}

// ------------------------------------------------------------------
// 判据（纯函数，可被正控喂坏副本）
// ------------------------------------------------------------------

/// ① 自省工具：normal 档、无闸、清单来自**真实注册表**。
bool listMyToolsIntrospects(String src) {
  final b = _stripComments(_toolBlock(src, 'list_my_tools'));
  return b.isNotEmpty &&
      b.contains('PermissionLevel.normal') &&
      !b.contains('grantKey') &&
      b.contains('toolRegistry.snapshot()');
}

/// ② 自检工具：normal 档、无闸、复用**同一事实源**（不另写探针）。
bool runDiagnosticsReusesProbes(String src) {
  final b = _stripComments(_toolBlock(src, 'run_diagnostics'));
  return b.isNotEmpty &&
      b.contains('PermissionLevel.normal') &&
      !b.contains('grantKey') &&
      b.contains('runDiagnostics(buildAppProbes())') &&
      b.contains('formatDiagnostics(');
}

/// ③ 依赖接线（缺 import ⇒ 编译期就炸，但这里显式钉一次，防被"绕过"改法骗过）。
bool diagnosticsImportsWired(String src) =>
    src.contains("import 'diagnostics.dart';") &&
    src.contains("import 'diagnostic_probes.dart';");

/// ④ 假面口径：`switch_social_scenario` 描述必须讲全"假面/人设"（不新增第二入口）。
///    ★ 锚点用**描述里独有**的串（`公开人设/假面`），不用 `mask_profile` ——
///      后者在 handler 代码里也出现，会**恒真**。
bool socialScenarioTellsMask(String src) {
  final b = _stripComments(_toolBlock(src, 'switch_social_scenario'));
  return b.contains('公开人设/假面') && b.contains('对外形象');
}

/// ⑤ KB 同一提交更新：把两条自认知能力讲给用户 + kbVersion bump。
bool kbTellsIntrospection(String kb) =>
    kbAtLeast(kb, 28) &&
    kb.contains('what can you do?') &&
    kb.contains('run a system check');

/// ⑥ 0.107.0：提示词里的**能力边界硬约束**。
///
/// 反的就是「邮箱没配，管家却说邮箱已打开」那次真机事故：光把工具回执改好**不够** ——
/// 换个模型、换个措辞，它照样能编出「设置一下我就能帮你读邮件」。
/// ⇒ 提示词层必须同时立两条规矩：不许承诺没有的能力 + 打开页面 ≠ 启用能力。
bool promptStatesCapabilityBoundary(String src) {
  final i = src.indexOf('【ReAct 自循环与自我进化约束】');
  if (i < 0) return false;
  final seg = src.substring(i, (i + 3200).clamp(0, src.length));
  return seg.contains('不许承诺你没有的能力') &&
      seg.contains('打开页面 ≠ 启用能力') &&
      seg.contains('list_my_tools');
}

/// ⑦ 0.107.0：「我能做什么」**只有一个事实源** —— 真实工具注册表。
///   此前 KB 里静态写一段、注册表里另有一份 ⇒ 模型照静态那段答题就能凭空承诺。
///   ⇒ `system_help` 必须注入 `toolLines`，且 KB 侧要有那份「live」清单的落点。
bool kbCapabilityComesFromRegistry(String agent, String kb) =>
    agent.contains('buildSystemHelpTool(toolLines:') &&
    agent.contains('_toolRegistryLines()') &&
    kb.contains('List<String> Function()? toolLines') &&
    kb.contains('[Live capability list · straight from the real tool registry]');

/// ⑧ 0.107.0：清单的**唯一格式化出口**必须自己读真实注册表（不接手抄名单）。
///   （① 只盯着"list_my_tools 块里出现 snapshot()"，0.107.0 把行格式化抽走后
///     那条会退化成靠 `snapshot().length` 这种偶然子串才绿 ⇒ 这里正面钉出口本身。）
bool toolLinesReadRealRegistry(String src) {
  final i = src.indexOf('List<String> _toolRegistryLines(');
  if (i < 0) return false;
  final seg = src.substring(i, (i + 1200).clamp(0, src.length));
  return seg.contains('toolRegistry.snapshot()');
}

/// kbVersion 是**单调递增的整数串**。旧写法（断言某个具体快照值）属于**写死的版本快照**
/// （红线 13）—— 每次 KB bump 这几条守卫就集体假红。
/// ⇒ 只断言**下限**：该能力自 KB v28 起存在，之后怎么涨都算满足。
bool kbAtLeast(String kb, int min) {
  final m = RegExp(r"kbVersion\s*=\s*'(\d+)'").firstMatch(kb);
  if (m == null) return false;
  final v = int.tryParse(m.group(1)!);
  return v != null && v >= min;
}

void main() {
  // 自检：kbAtLeast 认下限、不认快照（否则下次 KB bump 又集体假红）
  check(kbAtLeast("const String kbVersion = '29';", 28),
      '自检：kbVersion 29 满足「大于或等于 28」');
  check(!kbAtLeast("const String kbVersion = '27';", 28),
      '自检：kbVersion 27 不满足「大于或等于 28」（证明不是恒真）');

  print('== verify_agent_introspection (自省 / 自检 两工具) ==');

  final agent = _read('lib/core/agent_service.dart');
  final kb = _read('lib/core/system_knowledge.dart');

  check(agent.isNotEmpty, '读得到 agent_service.dart');
  check(kb.isNotEmpty, '读得到 system_knowledge.dart');

  print('  --- ① list_my_tools（自我盘点） ---');
  check(listMyToolsIntrospects(agent),
      'normal 档 + 无闸 + 清单来自真实注册表 toolRegistry.snapshot()');

  print('  --- ② run_diagnostics（系统自检） ---');
  check(runDiagnosticsReusesProbes(agent),
      'normal 档 + 无闸 + 复用同一事实源（buildAppProbes → runDiagnostics → formatDiagnostics）');

  print('  --- ③ 依赖接线 ---');
  check(diagnosticsImportsWired(agent), 'agent_service 已 import diagnostics / diagnostic_probes');

  print('  --- ④ 假面口径（不新增第二入口） ---');
  check(socialScenarioTellsMask(agent),
      'switch_social_scenario 描述讲全「假面/人设/昵称/头像」');

  print('  --- ⑤ KB 同一提交更新 ---');
  check(kbTellsIntrospection(kb),
      'KB 讲了两条自认知能力（what can you do / run a system check）+ kbVersion 大于或等于 28');

  print('  --- ⑥⑦ 0.107.0 能力边界（「邮箱已打开」事故的根治层） ---');
  check(promptStatesCapabilityBoundary(agent),
      '⑥ ★★ 提示词立了硬约束：不许承诺没有的能力 + 打开页面 ≠ 启用能力');
  check(kbCapabilityComesFromRegistry(agent, kb),
      '⑦ ★★ 「我能做什么」与真实注册表同源（system_help 注入 toolLines + KB 有 live 清单落点）');
  check(toolLinesReadRealRegistry(agent),
      '⑧ ★ 清单唯一出口 _toolRegistryLines 自己读 toolRegistry.snapshot()（不接手抄名单）');

  // ------------------------------------------------------------------
  // 正控：把好副本**人为改坏**，判据必须判出
  // ------------------------------------------------------------------
  print('  --- positive control ---');
  check(
      !listMyToolsIntrospects(
          agent.replaceAll("name: 'list_my_tools'", "name: 'zzz_self_list'")),
      '正控①：改名 ⇒ 取不到块 ⇒ 判出 ✓');
  check(
      !listMyToolsIntrospects(agent.replaceAll(
          'permission: PermissionLevel.normal, // 只读自省 ⇒ 无闸',
          'permission: PermissionLevel.critical, // x')),
      '正控①b：把自省工具改成 critical 档 ⇒ 判出 ✓（证明 normal 判据有效）');
  check(!runDiagnosticsReusesProbes(agent.replaceAll(
          'runDiagnostics(buildAppProbes())', 'runDiagnostics(<DiagnosticProbe>[])')),
      '正控②：不复用探针（自己造空表）⇒ 判出 ✓');
  check(!diagnosticsImportsWired(agent.replaceAll("import 'diagnostic_probes.dart';", '')),
      '正控③：抹掉 import ⇒ 判出 ✓');
  check(
      !socialScenarioTellsMask(
          agent.replaceAll('公开人设/假面', 'X')),
      '正控④：抹掉假面口径 ⇒ 判出 ✓');
  check(!kbTellsIntrospection(kb.replaceAll('what can you do?', '')),
      '正控⑤：KB 抹掉自省口径 ⇒ 判出 ✓');
  check(!promptStatesCapabilityBoundary(agent.replaceAll('不许承诺你没有的能力', '')),
      '正控⑥：提示词抹掉「不许承诺没有的能力」⇒ 判出 ✓');
  check(!promptStatesCapabilityBoundary(agent.replaceAll('打开页面 ≠ 启用能力', '')),
      '正控⑥b：提示词抹掉「打开页面 ≠ 启用能力」⇒ 判出 ✓');
  check(!kbCapabilityComesFromRegistry(agent.replaceAll('buildSystemHelpTool(toolLines:', 'buildSystemHelpTool('),
          kb),
      '正控⑦：system_help 不注入真清单（退回纯静态 KB）⇒ 判出 ✓');
  check(!toolLinesReadRealRegistry(agent.replaceAll('List<String> _toolRegistryLines(', 'List<String> _zzz(')),
      '正控⑧：清单出口被改名 ⇒ 判出 ✓');

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
