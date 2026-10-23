// 系统自检 / FTS5 可观测 守卫（0.79.0 新增）。
//
// 它钉住四类**症状静默**的退化，防止下一轮改动把它们改回去：
//   ① FTS5 降级重新变回"静默"：`_ensureFts` 必须是**标记 + 日志**，不能退回裸
//      `catch (_) {}` —— 那正是 0.79.0 要修的那条"静默失败"红线。
//   ② 探针"只问表在不在"：FTS5 探针必须**真跑一次 MATCH**（建表成功 ≠ 能检索）。
//   ③ 探针加了、屏幕取不到标题：`diagnostic_probes.dart` 的 id 与
//      `diagnostics_screen.dart` 的 `case '<id>':` 必须**集合相等**。
//   ④ 漏翻：18 个新键必须**五个语种齐**（KB 与 ARB 判据相反：ARB 必须齐）。
//
// 源文本扫描型脚本必须带**自检（positive control）**：匹配式一坏就"扫到 0 处 → 恒绿"。
// 故下面把判据抽成纯函数，并在末尾对**内存里被人为改坏的副本**各断言一次"必须被判出"。
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

/// ARB 五语种必须齐的 18 个新键。
const List<String> _newKeys = [
  'settingsDiagnosticsTitle',
  'settingsDiagnosticsSubtitle',
  'diagnosticsTitle',
  'diagnosticsIntro',
  'diagnosticsRun',
  'diagnosticsRunning',
  'diagnosticsCopy',
  'diagnosticsCopied',
  'diagStatusOk',
  'diagStatusWarn',
  'diagStatusFail',
  'diagStatusInfo',
  'diagProbeSchema',
  'diagProbeFts',
  'diagProbeMemoryRows',
  'diagProbeMemoryRecall',
  'diagProbeMemoryAddress',
  'diagProbeKb',
];

const List<String> _arbFiles = [
  'lib/l10n/app_en.arb',
  'lib/l10n/app_zh.arb',
  'lib/l10n/app_zh_Hant.arb',
  'lib/l10n/app_ja.arb',
  'lib/l10n/app_vi.arb',
];

// ------------------------------------------------------------------
// 判据（纯函数，可被正控喂坏副本）
// ------------------------------------------------------------------

/// ① diagnostics.dart 必须**零依赖**：只允许 `import 'dart:async';`。
bool pureDiagnostics(String s) {
  final imports = RegExp("^\\s*import\\s+'([^']+)'", multiLine: true)
      .allMatches(s)
      .map((m) => m.group(1)!)
      .toList();
  return imports.length == 1 && imports.first == 'dart:async';
}

/// ② `_ensureFts` 的降级必须**显形**（标记 + 日志），不得退回静默。
bool ensureFtsNotSilent(String s) {
  return s.contains('_ftsAvailable = false') &&
      s.contains('_ftsAvailable = true') &&
      s.contains("name: 'db.fts'");
}

/// ③ FTS5 探针必须**真跑一次 MATCH**（不能只 COUNT 表）。
bool probeRunsRealMatch(String s) {
  return s.contains('messages_fts MATCH ?');
}

/// ④ 探针 id 集合 == 屏幕 `case '<id>':` 集合。
List<String> probeIds(String s) => RegExp("DiagnosticProbe\\('([A-Za-z0-9_]+)'")
    .allMatches(s)
    .map((m) => m.group(1)!)
    .toList();

List<String> screenCaseIds(String s) => RegExp("case '([A-Za-z0-9_]+)':")
    .allMatches(s)
    .map((m) => m.group(1)!)
    .toList();

/// ⑤ 某 ARB 文本是否含全部新键（`"key":` 形态）。
bool arbHasAllKeys(String s) =>
    _newKeys.every((k) => s.contains('"$k"'));

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

  print('== verify_diagnostics (系统自检 / FTS5 可观测) ==');

  final diag = _read('lib/core/diagnostics.dart');
  final probes = _read('lib/core/diagnostic_probes.dart');
  final screen = _read('lib/ui/diagnostics_screen.dart');
  final db = _read('lib/core/db_helper.dart');
  // ★ 0.83.0：自检入口随「引擎 / 记忆 / 灵魂」一起搬进了**进阶设置页**。
  final settings = _read('lib/ui/advanced_settings_screen.dart');
  final kb = _read('lib/core/system_knowledge.dart');

  check(diag.isNotEmpty, 'diagnostics.dart 存在');
  check(probes.isNotEmpty, 'diagnostic_probes.dart 存在');
  check(screen.isNotEmpty, 'diagnostics_screen.dart 存在');

  // ① 纯逻辑层零依赖
  check(pureDiagnostics(diag), 'diagnostics.dart 零依赖（只 import dart:async）');

  // ② FTS5 降级不再静默（0.79.0 的核心修复）
  check(ensureFtsNotSilent(db), '_ensureFts 降级显形（标记 + db.fts 日志）');

  // ③ 探针真跑 MATCH
  check(probeRunsRealMatch(db), 'FTS5 探针真跑一次 MATCH（不只 COUNT）');

  // ④ 探针 id ↔ 屏幕标题集合相等（防"加了探针却取不到标题"）
  final pids = probeIds(probes).toSet();
  final cids = screenCaseIds(screen).toSet();
  check(pids.isNotEmpty, '解析出 ${pids.length} 个探针 id（>=1）');
  check(pids.length == cids.length && pids.containsAll(cids),
      '探针 id 与屏幕 case 标签集合相等（probes=$pids screen=$cids）');

  // ⑤ 五语种齐（ARB 必须齐 —— 与 KB「只英文」的判据**相反**）
  for (final f in _arbFiles) {
    final s = _read(f);
    final missing = _newKeys.where((k) => !s.contains('"$k"')).toList();
    check(s.isNotEmpty && missing.isEmpty,
        '$f 含全部 ${_newKeys.length} 个新键${missing.isEmpty ? '' : '，缺: $missing'}');
  }

  // ⑥ KB 与设置页接线
  check(kbAtLeast(kb, 28), 'KB kbVersion 大于或等于 28（自检能力自 v28 起；只断下限，不钉当前值）');
  check(kb.contains("HelpEntry('diagnostics'"), 'KB 已登记 diagnostics 条目');
  check(settings.contains("import 'diagnostics_screen.dart';"),
      '进阶设置页已 import 自检屏');
  check(settings.contains('DiagnosticsScreen()'), '进阶设置页已挂自检入口');

  // ⑦ 路由自备背景（R10：push 进来的页不能透明）
  check(screen.contains('backgroundColor:'), '自检屏自备不透明背景（R10）');

  // ⑧ 四种状态标签齐全（switch 覆盖，防"漏一个分支 ⇒ 编译不过或静默"）
  check(
      screen.contains('diagStatusOk') &&
          screen.contains('diagStatusWarn') &&
          screen.contains('diagStatusFail') &&
          screen.contains('diagStatusInfo'),
      '屏幕覆盖四种状态标签');

  // ------------------------------------------------------------------
  // 正控：把好副本**人为改坏**，判据必须判出（否则判据是恒绿的假守卫）
  // ------------------------------------------------------------------
  print('  --- positive control ---');
  check(!pureDiagnostics("import 'dart:async';\nimport 'package:flutter/material.dart';"),
      '正控①：掺入 flutter import ⇒ 判非纯 ✓');
  check(!ensureFtsNotSilent(db.replaceAll('_ftsAvailable = false', 'x')),
      '正控②：抹掉失败标记 ⇒ 判静默 ✓');
  check(!probeRunsRealMatch(db.replaceAll('messages_fts MATCH ?', 'COUNT(*)')),
      '正控③：探针退回 COUNT ⇒ 判不合格 ✓');
  check(probeIds("DiagnosticProbe('ghost', x);").toSet() !=
          screenCaseIds(screen).toSet(),
      '正控④：加一个屏幕没有的探针 ⇒ 集合不等 ✓');
  check(!arbHasAllKeys('{"a":"b"}'), '正控⑤：空 ARB ⇒ 判缺键 ✓');
  check(!pureDiagnostics(diag.replaceAll("import 'dart:async';", "import 'x';")),
      '正控⑥：改坏真副本 import ⇒ 判非纯 ✓');

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
