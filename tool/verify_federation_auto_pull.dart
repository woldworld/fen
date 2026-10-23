// 纯 Dart 校验脚本：**联邦名册自动拉取守卫**（0.89.0）。
// 运行：dart run tool/verify_federation_auto_pull.dart
//
// ## 抓的是什么
//
// 0.89.0 给分身加了一条**敏感的自主性**：开关打开后，它会自己去中转站把公开的
// 注册名册拉回来、收进主人的陌生档。这件事本身**不发出任何对外消息**，但它是
// "机器改了主人的名册" —— 所以它有六条红线，本脚本把它们钉在源码文本上：
//
//   ① **默认关**：`prefs.getBool(prefsEnabled) ?? false` —— 键不存在即关。
//      绝不允许出现 `?? true`（默认开 = 机器未经同意就替主人收人）。
//   ② **关 = 不发一次网络请求**：开关判定必须**早于** `fetchA2aRoster` 调用。
//      （顺序反了 = "关着也偷偷拉一次"，用户看不见的动作最危险。）
//   ③ **只走唯一写入方**：落库只能 `DBHelper.insertAgentFriend(..., autoPulled: true)`，
//      本模块**不得**自己 `insert('agent_friends', ...)`（否则绕过列默认与归属标记）。
//   ④ **不绕过审查**：本模块**不 import** 任何发信/搭讪/审查模块
//      （`agent_service` / `world_service` / `*_proactive*`），源码里也不得出现
//      `sendMessage` / `_auditDraft` / `evaluateAndProactiveMessage` 等符号。
//   ⑤ **节流与上限**：`cooldown` / `maxPerPull` / `maxAutoTotal` 三个参数必须在
//      纯逻辑内核里真实参与判定（无限拉取会把主人的名册拉爆）。
//   ⑥ **清空可撤回**：`clearAutoPulledAgents` 只删
//      `auto_pulled = 1 AND handshake_status = 'none'` —— 已交往的、主人手动收录的
//      一律动不到。
//
// ## 为什么判据要能"翻面"（positive control）
//
// 纯文本判据最容易写成一个**恒真**的表达式（比如拼错符号名 → `contains` 恒 false
// 被反转成恒 true），那样守卫自己失效却报绿灯。故每条关键判据都配一条**正控**：
// 把源码改坏一处，判据必须判出。
//
// ## 盲区（显式声明，不假装覆盖）
//
// 本脚本扫的是**源码文本**，不是 AST；它证明"红线写在/没写在这里"，
// 不证明"运行时真的按节流跑了"（那需要真库 + 真网络的端到端，本仓未覆盖）。

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

/// 剥行注释。★ 负向后顾 `(?<!:)//` —— 普通 `//.*$` 会吃掉 `https://` 之后的整段。
String _decomment(String s) =>
    s.replaceAll(RegExp(r'(?<!:)//.*$', multiLine: true), '');

// ---------------------------------------------------------------------------
// 判据（提到顶层，便于正控直接调用）
// ---------------------------------------------------------------------------

/// ① 开关默认关：默认取值必须是 `?? false`，且**不得**出现 `?? true`。
bool switchDefaultsOff(String s) =>
    s.contains('prefs.getBool(prefsEnabled) ?? false') &&
    !s.contains('prefs.getBool(prefsEnabled) ?? true');

/// ② 关 = 不发网络请求：开关判定（早退）必须**先于**取数调用。
bool offMeansNoFetch(String s) {
  final gate = s.indexOf('if (!(prefs.getBool(prefsEnabled) ?? false))');
  final fetch = s.indexOf('fetchA2aRoster');
  return gate >= 0 && fetch >= 0 && gate < fetch;
}

/// ③ 只走唯一写入方 + auto_pulled: true；不得自己直插 agent_friends。
bool onlyViaSingleWriter(String s) =>
    s.contains('DBHelper.insertAgentFriend(') &&
    s.contains('autoPulled: true') &&
    !RegExp(r"insert\(\s*'agent_friends'").hasMatch(s);

/// ③b 拉取模块只**读** `auto_pulled`（用于计数），**绝不写**该列 / 不直插 / 不 update。
bool neverWritesAutoPulled(String s) =>
    !RegExp(r'''['"]auto_pulled['"]\s*:''').hasMatch(s) &&
    !s.contains("update('agent_friends'") &&
    !s.contains("insert('agent_friends'");

/// ④ 不绕过审查：不 import / 不引用任何发信、搭讪、审查符号。
bool noOutreachOrReviewSymbols(String s) {
  const forbidden = <String>[
    "agent_service.dart",
    "world_service.dart",
    "p2p_service.dart",
    "sendMessage",
    "_auditDraft",
    "evaluateAndProactiveMessage",
    "triggerMassStimulus",
    "ProactiveMessage",
    "SocialBudget",
  ];
  for (final t in forbidden) {
    if (s.contains(t)) return false;
  }
  return true;
}

/// ④b 纯逻辑内核**零依赖**：不得出现任何 `import` 语句（只允许 `library;`）。
bool intakeIsZeroDep(String s) =>
    !RegExp(r'^\s*import\s', multiLine: true).hasMatch(s);

/// ⑤ 节流与上限三参数都在内核里。
bool hasThrottleAndCaps(String s) =>
    s.contains('cooldown') && s.contains('maxPerPull') && s.contains('maxAutoTotal');

/// ⑥ 清空的判据按"两条同时成立"写。
bool clearJudgeIsExact(String s) =>
    s.contains("auto_pulled = 1 AND handshake_status = 'none'");

/// 从 `db_helper.dart` 读出**实际声明**的 schemaVersion。
int? schemaVersionDeclared(String dbHelper) {
  final m = RegExp(r'schemaVersion\s*=\s*(\d+)\s*;').firstMatch(dbHelper);
  return m == null ? null : int.parse(m.group(1)!);
}

/// ⑥ 联邦名册加列那一版（v39）**是否仍在迁移链上**。
///
/// ★ 判据是「当前声明版本 **≥ 39**」，不是「当前声明版本 **恰好等于 39**」。
///   写死数字是**错判据**：版本号每轮都会前进，写死等于给守卫埋一个定时炸弹
///   （0.106.0 实测 —— 加 `owner_profile_cards`（v39→v40）后这条立刻变成假 FAIL，
///   而本轮之前四关从未跑过 ⇒ 炸点一直藏着）。同族先例：`verify_peer_compaction.dart`
///   的 0.70.0 修订（那里是反例构造写死 '37' ⇒ `replaceFirst` 替不中 ⇒ 自检恒假红）。
bool federationColumnStillOnChain(String dbHelper, {int floor = 39}) {
  final v = schemaVersionDeclared(dbHelper);
  return v != null && v >= floor;
}

/// ⑥ 当前声明版本**自己的**迁移是否登记在册（`N: _migrateVN`）。
/// 抓住"版本号涨了、迁移表项没写"这一类事故（历史事故见 `verify_mail_tools.dart`
/// 文件头：`schemaVersion=32` 生效但表项没写 ⇒ 只在老库升级路径炸）。
bool latestMigrationRegistered(String dbHelper) {
  final v = schemaVersionDeclared(dbHelper);
  return v != null && dbHelper.contains('$v: _migrateV$v');
}

void main() {
  print('== verify_federation_auto_pull (默认关 / 只收录不发信 / 可撤回) ==');

  final ap = _decomment(_read('lib/core/federation_auto_pull.dart'));
  final intake = _decomment(_read('lib/core/federation_intake.dart'));
  final db = _decomment(_read('lib/core/db_helper.dart'));
  final social = _decomment(_read('lib/ui/social_screen.dart'));

  // -----------------------------------------------------------------------
  print('');
  print('--- ① 开关默认关（键不存在 = 关）---');
  check(ap.contains("prefsEnabled = 'federation_auto_pull'"),
      "开关 prefs 键 = 'federation_auto_pull'");
  check(switchDefaultsOff(ap), '默认关：`prefs.getBool(prefsEnabled) ?? false`，且无 `?? true`');
  check(!ap.contains('?? true'),
      '自动拉取模块内不出现任何 `?? true`（不得有任何默认开的通道）');
  check(_decomment(_read('lib/core/system_knowledge.dart'))
          .contains('OFF by default; only you can turn it on') ||
      _read('lib/core/system_knowledge.dart')
          .contains('OFF by default; only you can turn it on'),
      'KB 对主人的口径一致：OFF by default；只有主人能开');

  // -----------------------------------------------------------------------
  print('');
  print('--- ② 关 = 一次网络请求都不发 ---');
  check(offMeansNoFetch(ap), '开关早退在 `fetchA2aRoster` 之前（关着不偷偷拉）');
  check(ap.contains('return const FederationAutoPullResult'),
      '关闭态直接返回（不进入取数分支）');

  // -----------------------------------------------------------------------
  print('');
  print('--- ③ 只走唯一写入方 + auto_pulled 归属标记 ---');
  check(onlyViaSingleWriter(ap),
      '落库只 `DBHelper.insertAgentFriend(..., autoPulled: true)`，不自行 insert');
  check(neverWritesAutoPulled(ap),
      '拉取模块只读 auto_pulled（计数），不写列 / 不直插 / 不 update');  check(db.contains('clearAutoPulledAgents'), 'DBHelper 暴露 clearAutoPulledAgents()');
  check(db.contains("'auto_pulled': autoPulled ? 1 : 0"),
      'insertAgentFriend 写入 auto_pulled 列（单一写入方）');

  // -----------------------------------------------------------------------
  print('');
  print('--- ④ 不绕过审查：无任何发信 / 搭讪 / 审查符号 ---');
  check(noOutreachOrReviewSymbols(ap),
      '自动拉取模块不 import / 不引用 agent_service / world_service / 发信符号');
  check(intakeIsZeroDep(intake), '纯逻辑内核零 import（只 dart:core）');
  check(ap.contains('FederationSkip.disabled'),
      '拉取模块显式声明"开关关闭"这一最外层原因（对外可解释）');

  // -----------------------------------------------------------------------
  print('');
  print('--- ⑤ 节流与上限 ---');
  check(hasThrottleAndCaps(intake), '内核含 cooldown / maxPerPull / maxAutoTotal');
  check(intake.contains('Duration(hours: 6)') ||
      intake.contains('const Duration(hours: 6)'),
      '默认节流窗 = 6 小时');
  check(RegExp(r'maxPerPull\s*=\s*20').hasMatch(intake), '单次上限默认 20');
  check(RegExp(r'maxAutoTotal\s*=\s*200').hasMatch(intake), '总量上限默认 200');

  // -----------------------------------------------------------------------
  print('');
  print('--- ⑥ 清空只删"机器收录且未交往" ---');
  check(clearJudgeIsExact(db),
      "清空判据 = `auto_pulled = 1 AND handshake_status = 'none'`（两条同时成立）");
  check(db.contains('auto_pulled = 1'), 'DB 侧确有 auto_pulled 列参与 DELETE');
  check(db.contains('auto_pulled INTEGER DEFAULT 0'),
      '建表含 auto_pulled 列（默认 0，全新装老库一致）');
  check(RegExp(r'_migrateV39').hasMatch(db) && db.contains('39: _migrateV39'),
      '_migrateV39 已注册（加列走升级路径）');
  // ★ 0.106.0 修订：原判据是 `db.contains('schemaVersion = 39')` —— 把**当时那个数字**
  //   钉死了。0.106.0 加 `owner_profile_cards`（v39→v40）后它立刻失真成假 FAIL。
  //   判据要断言的是**事实**（"联邦名册那一版仍在链上" + "当前版本的迁移已登记"），
  //   不是某个字符串恰好等于什么。两条都能随版本前进而保持有效，且各自仍能抓住
  //   真实的退化：版本被退回 < 39 / 版本涨了但迁移表项没写。
  check(federationColumnStillOnChain(db),
      'schemaVersion ≥ 39（联邦名册加列那一版仍在链上；实际声明 '
      '${schemaVersionDeclared(db)}）');
  check(latestMigrationRegistered(db),
      '当前声明版本自己的迁移已登记'
      '（${schemaVersionDeclared(db)}: _migrateV${schemaVersionDeclared(db)}）');

  // -----------------------------------------------------------------------
  print('');
  print('--- ⑦ UI 接线（社交页名册签）---');
  check(social.contains('FederationAutoPull.setEnabled'),
      '开关写穿走 FederationAutoPull.setEnabled（唯一写入方）');
  check(social.contains('FederationAutoPull.maybePull'),
      '页面触发走 FederationAutoPull.maybePull');
  check(social.contains('DBHelper.clearAutoPulledAgents'),
      '清空按钮调 DBHelper.clearAutoPulledAgents');
  check(social.contains('socialFederationAutoTitle'),
      'UI 文案走 ARB（socialFederationAutoTitle）');

  // -----------------------------------------------------------------------
  print('');
  print('--- ⓿ 正控：把源码改坏一处，判据必须判出 ---');
  check(!switchDefaultsOff(ap.replaceAll('?? false', '?? true')),
      '正控①：默认改开（?? true）⇒ 判出 ✓');
  check(
      !offMeansNoFetch(ap.replaceAll(
          'if (!(prefs.getBool(prefsEnabled) ?? false)) {\n      return const FederationAutoPullResult(',
          'if (false) {\n      return const FederationAutoPullResult(')),
      '正控②：删掉开关早退 ⇒ 判出 ✓');
  final apDirect = '$ap\nawait db.insert(\'agent_friends\', {\'agent_id\': x});';
  check(!onlyViaSingleWriter(apDirect), '正控③：直插 agent_friends ⇒ 判出 ✓');
  check(
      !neverWritesAutoPulled(
          '$ap\nawait db.update(\'agent_friends\', {\'auto_pulled\': 0});'),
      '正控③b：自行 UPDATE auto_pulled 列 ⇒ 判出 ✓');
  check(!noOutreachOrReviewSymbols('$ap\nimport "../core/agent_service.dart";'),
      '正控④：import agent_service ⇒ 判出 ✓');
  check(!intakeIsZeroDep('$intake\nimport "dart:io";'),
      '正控④b：内核引入 import ⇒ 判出 ✓');
  check(!hasThrottleAndCaps(intake.replaceAll('maxAutoTotal', 'unbounded')),
      '正控⑤：抹掉总量上限 ⇒ 判出 ✓');
  check(
      !clearJudgeIsExact(
          db.replaceAll("auto_pulled = 1 AND handshake_status = 'none'",
              'auto_pulled = 1')),
      '正控⑥：清空判据丢掉 handshake 条件 ⇒ 判出 ✓');

  // ★ 正控⑦：⑥ 组新判据（版本 ≥ 39 / 当前版本迁移已登记）也必须能翻面。
  //   反例**动态构造**（先读出实际声明值再替换），不再写死数字 —— 这正是
  //   `verify_peer_compaction.dart` 0.70.0 修订留下的教训。
  final vNow = schemaVersionDeclared(db);
  check(vNow != null, '正控前置：schemaVersion 可从源码解析');
  check(
      !federationColumnStillOnChain(
          db.replaceFirst('schemaVersion = $vNow', 'schemaVersion = 38')),
      '正控⑦：声明版本退回 38（联邦列那版之前）⇒ 判出 ✓');
  check(
      !latestMigrationRegistered(
          db.replaceFirst('$vNow: _migrateV$vNow', '// removed')),
      '正控⑦b：当前版本的迁移表项被删掉 ⇒ 判出 ✓');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
