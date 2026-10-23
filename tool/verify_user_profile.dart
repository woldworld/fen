// 纯 Dart 校验脚本：验证「P1 双向记忆层（长期用户画像）」落地（结构级断言）。
// 运行：dart run tool/verify_user_profile.dart
//
// P1 验收（不依赖运行中的 App / 设备，仅查源码与 ARB 契约）：
//   ① **不落库**：画像是 `session_events` 的派生聚合 ⇒ 未为它建表、DB 版本未变；
//   ② **只做关键词+时间**：源码（去注释后）不得出现任何向量 / embedding 依赖；
//   ③ **只读**：只 `db.query('session_events')`，不写任何表、不读正文列 `text`；
//   ④ 回灌：`_augmentWithRecall` 内注入 `UserProfileStore.i.buildProfileBlock`
//      （⇒ 自动继承 recall_enabled 开关与对外护栏）；
//   ⑤ 沉淀：`morning_digest_service` 每日 `UserProfileStore.i.refresh()`；
//   ⑥ ARB 五语种齐含 `morningHiLongTerm`；
//   ⑦ 停用词与 P0 三日回顾客同源（不得各写一套）。
//   ⑧ 0.69.0：画像拿到**自己的开关** `profile_enabled`，但它是**二级 gate** ——
//      回忆关 ⇒ 画像必停；回忆开 ⇒ 由它单独决定画像停不停。断言就落在
//      `_augmentWithRecall` 的**源码次序**上：recall 判断必须早于任何画像读取。
//   ⑨ 0.69.0：开关必须**两处都管**（注入 + 晨间卡片「长期关注」）。
//      只挡注入、晨间照旧弹 ⇒ 主人会看到"我明明关了却还在" ⇒ 静默不符预期。

import 'dart:convert';
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

const List<String> _arbFiles = [
  'lib/l10n/app_zh.arb',
  'lib/l10n/app_en.arb',
  'lib/l10n/app_zh_Hant.arb',
  'lib/l10n/app_ja.arb',
  'lib/l10n/app_vi.arb',
];

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

/// 去掉整行注释（`///` / `//`）。
///
/// 为什么必须去注释：本文件的文档里**刻意写了**"不做向量 / embedding"的理由，
/// 若连带注释一起扫禁词，这条断言会被自己的说明文字误伤 ⇒ 只扫**代码行**。
String _stripComments(String src) {
  final out = <String>[];
  for (final line in src.split('\n')) {
    final t = line.trimLeft();
    if (t.startsWith('//')) continue;
    out.add(line);
  }
  return out.join('\n');
}

/// 取方法体窗口（从签名起，到下一个顶层方法签名 / 类结束为止）。
/// 只用于"某个调用确实落在某个方法里"这类断言，不做精确花括号配对。
String _methodWindow(String src, String signature, {int maxChars = 2500}) {
  final i = src.indexOf(signature);
  if (i < 0) return '';
  return src.substring(i, (i + maxChars > src.length) ? src.length : i + maxChars);
}

void main() {
  print('== verify_user_profile (P1 长期用户画像结构校验) ==');

  final store = _read('lib/core/user_profile_store.dart');
  final storeCode = _stripComments(store);
  final dbHelper = _read('lib/core/db_helper.dart');
  final agent = _read('lib/core/agent_service.dart');
  final morning = _read('lib/core/morning_digest_service.dart');

  // ① 不落库：画像为派生值，未建表。
  //    ★ 0.70.0 修订：原判据写死 `schemaVersion == 37` / 无 `_migrateV38`，
  //    但那是"0.68.0 当时 DB 版本恰好是 37"的巧合，不是画像的不变式 ——
  //    0.70.0 的 DB v38（reminders + session_events 软删）与画像无关，
  //    版本号照常前进。真正的不变式只有一条：**不为画像建表**（下方已有）。
  check(store.isNotEmpty, 'user_profile_store.dart 存在');
  check(!dbHelper.contains('CREATE TABLE IF NOT EXISTS user_profile'),
      'db_helper 未为画像建表（派生值不落库）');
  check(storeCode.contains('deleted_at IS NULL'),
      '画像聚合排除软删行（0.70.0 会话遗忘后不再进画像）');
  final storeCreate = _stripComments(store)
      .contains(RegExp(r'CREATE\s+TABLE', caseSensitive: false));
  check(!storeCreate, 'user_profile_store 内无 CREATE TABLE（不落库）');

  // ② 只做关键词+时间：禁止任何向量 / 语义检索依赖
  final banned = ['sqlite_vec', 'sqliteVec', 'embedding', 'Embedding', 'vector', 'Vector'];
  final hits = banned.where((w) => storeCode.contains(w)).toList();
  check(hits.isEmpty, '画像源码（去注释）无向量/embedding 依赖${hits.isEmpty ? '' : '，命中: $hits'}');

  // ③ 只读：只 query session_events，不写、不读正文
  check(storeCode.contains("'session_events'"), '只读 session_events');
  final writes = ['db.insert', 'db.update', 'db.delete', 'db.execute', 'rawInsert', 'rawUpdate', 'rawDelete'];
  final wHits = writes.where((w) => storeCode.contains(w)).toList();
  check(wHits.isEmpty, '画像源码无任何写库调用${wHits.isEmpty ? '' : '，命中: $wHits'}');
  check(!storeCode.contains("'text'"), '不读 messages 正文列 text（只取元数据）');

  // ④ 回灌：在 _augmentWithRecall 内注入（⇒ 复用开关与对外护栏）
  final win = _methodWindow(agent, 'Future<String> _augmentWithRecall',
      maxChars: 3000);
  check(win.contains('UserProfileStore.i.buildProfileBlock'),
      '_augmentWithRecall 内注入 buildProfileBlock（继承开关+护栏）');
  check(agent.contains("import 'user_profile_store.dart';"),
      'agent_service 已 import user_profile_store');
  check(win.contains('recall_enabled'), '画像注入仍受 recall_enabled 开关约束');

  // ⑤ 沉淀：每日回顾强制刷新一次
  check(morning.contains('UserProfileStore.i.refresh'),
      'morning_digest_service 每日 refresh 画像');

  // ⑥ ARB 五语种
  for (final arb in _arbFiles) {
    final text = _read(arb);
    late Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      check(false, '$arb 可解析为 JSON ($e)');
      continue;
    }
    check(json.containsKey('morningHiLongTerm'), '$arb 含 morningHiLongTerm');
    check(json.containsKey('settingsProfileEnabled'),
        '$arb 含 settingsProfileEnabled');
  }

  // ⑦ 停用词与 P0 同源
  final css = _read('lib/core/chat_stats_source.dart');
  final hasStop = store.contains("'未分类'") && store.contains("'日常交流'");
  final cssStop = css.contains("'未分类'") && css.contains("'日常交流'");
  check(hasStop && cssStop, '停用词口径与 P0 chat_stats_source 同源（未分类/日常交流）');

  // ⑧ 二级 gate：**源码次序**才是判据 —— 光"两个键都存在"证明不了
  //    「关了回忆就一定不读画像」。万一有人把画像读取挪到开关之前，画像虽然最终没进
  //    提示词，但每轮仍白扫一次事件表，且未来的改动很容易再把内容喂回去。
  final iRecall = win.indexOf('recall_enabled');
  final iReturnBase = win.indexOf('return base;');
  final iProfileKey = win.indexOf('profile_enabled');
  check(iRecall >= 0 && iProfileKey >= 0 && iReturnBase > iRecall,
      '二级 gate 存在：recall 判断早于 early return');
  check(iProfileKey > iReturnBase,
      '画像读取（含 profile_enabled）晚于 recall 的 early return（关回忆⇒绝不读画像）');
  check(win.contains('profileEnabled ? await UserProfileStore.i.buildProfileBlock'),
      'profile_enabled=false 时**不读**画像（不是读完再丢）');

  // ⑨ 开关两处都管：注入 + 晨间卡片
  check(morning.contains("getBool('profile_enabled')"),
      'morning_digest_service 也尊重 profile_enabled（关了则「长期关注」不出现）');

  // ★ 0.83.0：回忆 / 画像开关随「记忆」一块搬进了**进阶设置页**。
  final settings = _read('lib/ui/advanced_settings_screen.dart');
  check(settings.contains("prefs.setBool('profile_enabled'"),
      '设置页是 profile_enabled 的唯一写入方（写穿生效）');
  // ★ 这条钉的是「UI 不能给出一个只能骗人的可点状态」：二级 gate 下，
  //   回忆关闭时画像开关必须是灰的且显示 false —— 否则主人会以为"我关了画像"
  //   （其实回忆一关早就全停了），或以为"我开了画像"（其实不会生效）。
  check(settings.contains('_recallEnabled ? _profileEnabled : false'),
      '回忆开关关闭时，画像开关在 UI 上置灰（二级 gate 可见，不给假状态）');

  // ⑩ ★ 0.106.0：新增**第二层**画像 —— 「主人自述画像卡」（可写事实层）。
  //
  //    必须在**这里**说清楚，否则下一个人看到 `owner_profile_cards` 建表会以为
  //    "有人把 R8 破了"。真相是两层分工：
  //      · 本文件保护的是**派生层**（常关注话题/常在时段）—— session_events 的
  //        聚合，重算即得 ⇒ **必须不落库**（下面那条断言盯着）。
  //      · 新增的是**自述层**（职业/偏好/目标/习惯）—— **不是任何历史数据的函数**，
  //        重算不出来 ⇒ **必须落库**，否则主人的自述一关 App 就没了。
  //    两条断言**同时为真**才叫分工；只留一条就是漂移。
  final selfStore = _read('lib/core/profile_card_store.dart');
  check(selfStore.isNotEmpty, 'profile_card_store.dart 存在（新增的自述画像层）');
  check(dbHelper.contains('CREATE TABLE IF NOT EXISTS owner_profile_cards'),
      '自述画像**有**表（非派生值，落库合理；与 R8 不冲突）');
  check(!dbHelper.contains('CREATE TABLE IF NOT EXISTS user_profile'),
      '派生画像层仍然**不落库**（与上一条同时为真 = 两层分工，不是破例）');
  check(!_stripComments(selfStore).contains('CREATE TABLE'),
      '自述层内不建表（建表只在 db_helper，单一事实源）');

  // 注入入口唯一：两层共用同一个方法（R21「同一件事禁止两个入口」）
  check(
      win.contains('UserProfileStore.i.buildProfileBlock') &&
          win.contains('ProfileCardStore.i.buildCardsBlock'),
      '两层画像注入在**同一个入口** _augmentWithRecall（不是两个入口）');
  // 二级 gate 必须同样管住新增层：少一个 gate 就是绕过主人显式关闭
  check(win.contains('profileEnabled ? await ProfileCardStore.i.buildCardsBlock'),
      '自述画像也受 profile_enabled 约束（不给第三个开关绕过主人关闭）');

  // 界面入口唯一：画像卡只在进阶设置页出现一次（防"又加了一个入口"）
  final allScreens = ['lib/ui/advanced_settings_screen.dart'];
  var cardEntries = 0;
  for (final f in allScreens) {
    cardEntries += RegExp(r'ProfileCardsScreen\(\)').allMatches(_read(f)).length;
  }
  check(cardEntries == 1,
      '画像卡界面入口唯一（实际 $cardEntries 处）—— 同一件事不给两个入口');

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
