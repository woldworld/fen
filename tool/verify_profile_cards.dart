// 纯 Dart 校验脚本：验证「主人画像卡（可写自述层）」落地。
// 运行：dart run tool/verify_profile_cards.dart
//
// ---------------------------------------------------------------------------
// 这个脚本为什么和别的 verify_* 不一样
// ---------------------------------------------------------------------------
// 多数守卫只能**扫源码字符串**（"某个调用确实在某个方法里"）。
// 扫源码证明不了规则对不对 —— 能编译、字面量齐全，语义照样可以错。
//
// 本脚本能**真的执行**规则：`ProfileCardExtractor.extract` 是纯函数
// （只 import 零依赖的 `profile_taxonomy.dart`），于是在纯 Dart VM 里直接跑，
// 对输入 → 输出逐条断言。这是"结论能指到一次实测"的落点。
//
// 而被验证的能力（画像卡）本身要 sqflite，跑不了 —— 那部分的**冲突规则**
// 只能用源码断言（`upsert` 里四条分支的次序与存在性），并明确标注这是弱证据。
//
// 断言分四组：
//   A. taxonomy 层零依赖（否则上面那条能力立刻失效）
//   B. 抽取规则**真跑**（正向 + 反例 + 确定性 + 上限）
//   C. 冲突规则源码次序（弱证据，但能挡住"分支被删/次序被换"）
//   D. DB 侧：建表 / 版本一致 / 不与派生画像层撞名 / 无向量依赖

import 'dart:convert';
import 'dart:io';

import '../lib/core/profile_card_extractor.dart';
import '../lib/core/profile_taxonomy.dart';

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

/// 去掉整行注释后再扫禁词/结构 —— 否则文档里**刻意写的**说明文字会误伤自己。
String _code(String src) {
  final out = <String>[];
  for (final line in src.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    out.add(line);
  }
  return out.join('\n');
}

const List<String> _arbFiles = [
  'lib/l10n/app_zh.arb',
  'lib/l10n/app_en.arb',
  'lib/l10n/app_zh_Hant.arb',
  'lib/l10n/app_ja.arb',
  'lib/l10n/app_vi.arb',
];

/// 一条测试用例：输入 → 期望命中的「槽位/陈述」。
class Case {
  const Case(this.input, this.slot, this.statement, {this.absent = false});
  final String input;
  final String slot;
  final String statement;

  /// true = 断言**不该**出现该槽位（反例）。
  final bool absent;
}

void main() {
  print('== verify_profile_cards (主人画像卡) ==');

  // ─────────────────────────────────────────────────────────────────
  // A. taxonomy 零依赖
  // ─────────────────────────────────────────────────────────────────
  print('');
  print('-- A. taxonomy 层零依赖 --');
  final tax = _read('lib/core/profile_taxonomy.dart');
  check(tax.isNotEmpty, 'profile_taxonomy.dart 存在');
  final taxImports = tax
      .split('\n')
      .where((l) => l.trimLeft().startsWith('import '))
      .toList();
  check(taxImports.isEmpty,
      'taxonomy 无任何 import（有则抽取器无法在纯 Dart VM 跑，行为断言全部失效）'
      '${taxImports.isEmpty ? '' : '，命中: $taxImports'}');

  final ext = _read('lib/core/profile_card_extractor.dart');
  final extImports = ext
      .split('\n')
      .where((l) => l.trimLeft().startsWith('import '))
      .map((l) => l.trim())
      .toList();
  check(
      extImports.length == 1 &&
          extImports.first.contains('profile_taxonomy.dart'),
      '抽取器只 import taxonomy（不得引入 sqflite / flutter）'
      '${extImports.length == 1 ? '' : '，实际: $extImports'}');

  // ─────────────────────────────────────────────────────────────────
  // B. 抽取规则真跑
  // ─────────────────────────────────────────────────────────────────
  print('');
  print('-- B. 抽取规则（真跑） --');

  const cases = <Case>[
    // 职业
    Case('我是结构工程师', 'career:job', '职业是结构工程师'),
    Case('我做前端开发', 'career:job', '职业是前端开发'),
    Case('我干销售的', 'career:job', '职业是销售的'),
    // 反例：不是职业，不该抽
    Case('我是家里的老大', 'career:job', '', absent: true),
    Case('我是这么想的', 'career:job', '', absent: true),
    // 偏好（同义褒贬词收敛成 喜欢/不喜欢）
    Case('我喜欢喝黑咖啡', 'preference:喝黑咖啡', '喜欢喝黑咖啡'),
    Case('我爱徒步', 'preference:徒步', '喜欢徒步'),
    Case('我不喜欢开会', 'preference:开会', '不喜欢开会'),
    Case('我讨厌开会', 'preference:开会', '不喜欢开会'),
    // 目标
    Case('我想学英语', 'goal:学英语', '想学英语'),
    Case('我打算明年换工作', 'goal:明年换工作', '想明年换工作'),
    // 习惯
    Case('我每天早上六点起来跑步', 'habit:早上六点起来跑步', '每天早上六点起来跑步'),
    Case('我经常加班到十点', 'habit:加班到十点', '经常加班到十点'),
    // 约束
    Case('我不能吃辣', 'constraint:吃辣', '不能吃辣'),
    Case('我必须每天午休', 'constraint:每天午休', '必须每天午休'),
    // 显式记忆
    Case('记住：我下个月要搬到杭州', 'explicit:下个月要搬到杭州', '下个月要搬到杭州'),
    // 居住地（须挡掉"我在写代码"这类假地名）
    Case('我住在杭州', 'identity:basic', '常在杭州'),
    Case('我在写代码', 'identity:basic', '', absent: true),
    // 太短不抽
    Case('好的', 'career:job', '', absent: true),
    Case('嗯嗯', 'preference:嗯嗯', '', absent: true),
  ];

  for (final c in cases) {
    final got = ProfileCardExtractor.extract(c.input);
    final hit = got.where((e) => e.slot == c.slot).toList();
    if (c.absent) {
      check(hit.isEmpty, '反例「${c.input}」不该产出 ${c.slot}');
    } else {
      check(hit.length == 1 && hit.first.statement == c.statement,
          '「${c.input}」→ ${c.slot} = 「${c.statement}」'
          '${hit.isEmpty ? '（未命中）' : '（实际「${hit.first.statement}」）'}');
    }
  }

  // 确定性：同输入两次结果完全一致（否则"重复观察"会变成两张卡）
  final a1 = ProfileCardExtractor.extract('我喜欢喝黑咖啡，我想学英语');
  final a2 = ProfileCardExtractor.extract('我喜欢喝黑咖啡，我想学英语');
  final s1 = a1.map((e) => '${e.slot}|${e.statement}').join(';');
  final s2 = a2.map((e) => '${e.slot}|${e.statement}').join(';');
  check(s1 == s2 && a1.isNotEmpty, '抽取确定性：同输入两次结果一致（$s1）');

  // 上限：一句塞满规则也不超过 maxPerTurn
  const packed = '我是结构工程师，我喜欢喝咖啡，我讨厌开会，我想学英语，'
      '我每天跑步，我不能吃辣，我住在杭州，记住：我下月搬家';
  final packedOut = ProfileCardExtractor.extract(packed);
  check(packedOut.length <= ProfileCardExtractor.maxPerTurn,
      '单轮抽取不超过 ${ProfileCardExtractor.maxPerTurn} 条（实际 ${packedOut.length}）');

  // 保底：真实长句至少能抽出东西（防"规则全部失效但脚本仍绿"）
  check(packedOut.length >= 4,
      '一句含 8 类信息的发言至少抽出 4 条（实际 ${packedOut.length}）');

  // 槽位/分类必须都在枚举内 —— 否则库里会存进"野分类"，UI 无法渲染
  final allOut = <ProfileCandidate>[...packedOut, ...a1];
  final badCat =
      allOut.where((e) => !ProfileCategory.all.contains(e.category)).toList();
  check(badCat.isEmpty,
      '抽取出的分类都在 ProfileCategory.all 内${badCat.isEmpty ? '' : '，命中: ${badCat.map((e) => e.category)}'}');

  // ─────────────────────────────────────────────────────────────────
  // C. 冲突规则（源码次序 —— 弱证据，但能挡住分支被删/次序被换）
  // ─────────────────────────────────────────────────────────────────
  print('');
  print('-- C. 冲突规则（源码结构） --');
  final store = _read('lib/core/profile_card_store.dart');
  final storeCode = _code(store);

  final iInsert = storeCode.indexOf('ProfileMergeOutcome.inserted');
  final iReinforce = storeCode.indexOf('ProfileMergeOutcome.reinforced');
  final iOwnerGuard = storeCode.indexOf('ProfileSource.isOwner(old.source)');
  final iSupersede = storeCode.indexOf('ProfileMergeOutcome.superseded');
  check(iInsert > 0 && iReinforce > iInsert && iOwnerGuard > iReinforce &&
          iSupersede > iOwnerGuard,
      '四条分支次序：插入 → 重复强化 → **主人自述优先保护** → 取代（保护必须早于取代）');

  final iSame = storeCode.indexOf('_sameStatement(old.statement, st)');
  check(iSame > 0 && iSame < iOwnerGuard,
      '「同陈述只强化」判定早于「主人保护」（否则重复观察会被误判成冲突）');

  check(storeCode.contains('ProfileStatus.superseded') &&
          storeCode.contains('superseded_by'),
      '取代是**留痕**（superseded + superseded_by）而不是原地改/删');
  check(!storeCode.contains('db.delete') || _hasOwnerDelete(storeCode),
      '仅主人删除通道才 delete（其余分支不得删行）');

  // 唯一写入方
  final ownerWriters = RegExp(r"source:\s*ProfileSource\.owner")
      .allMatches(storeCode)
      .length;
  check(ownerWriters == 1,
      'source=owner 的写入方唯一（实际 $ownerWriters 处）—— 多处拼装必然漂移');

  // 无向量 / 语义依赖（与 P1 派生画像层同一条纪律）
  final banned = ['sqlite_vec', 'sqliteVec', 'embedding', 'Embedding'];
  final hits = banned.where((w) => storeCode.contains(w)).toList();
  check(hits.isEmpty, '画像卡源码无向量/embedding 依赖${hits.isEmpty ? '' : '，命中: $hits'}');

  // ─────────────────────────────────────────────────────────────────
  // D. DB 侧
  // ─────────────────────────────────────────────────────────────────
  print('');
  print('-- D. 建表与版本 --');
  final db = _read('lib/core/db_helper.dart');

  check(db.contains('CREATE TABLE IF NOT EXISTS owner_profile_cards'),
      '建表 owner_profile_cards 存在');
  check(db.contains('static Future<void> _migrateV40'),
      '_migrateV40 存在');
  check(db.contains('40: _migrateV40,'), '_migrations 已登记 40');

  final verMatch =
      RegExp(r'static const int schemaVersion = (\d+);').firstMatch(db);
  final ver = verMatch == null ? -1 : int.parse(verMatch.group(1)!);
  final keys = RegExp(r'^\s*(\d+): _migrateV\d+,', multiLine: true)
      .allMatches(db)
      .map((m) => int.parse(m.group(1)!))
      .toList();
  final maxKey = keys.isEmpty ? -1 : (keys..sort()).last;
  check(ver == maxKey,
      'schemaVersion($ver) == _migrations 最大键($maxKey) —— 不等则全新安装会少建表');

  // ★ 与派生画像层不撞名：verify_user_profile 有一条断言"未为画像建表"，
  //   它用的是子串匹配 'CREATE TABLE IF NOT EXISTS user_profile'。
  //   本表叫 owner_profile_cards，**不得**命中那个子串，否则那条断言会假红。
  check(!db.contains('CREATE TABLE IF NOT EXISTS user_profile'),
      '新表名不得撞上派生层判据（owner_profile_cards 不含 user_profile 建表串）');

  // 索引：upsert 热路径（按 slot）与注入热路径（按 status）都该有
  check(db.contains('idx_profile_cards_slot') &&
          db.contains('idx_profile_cards_status'),
      'slot / status 两条查询路径都有索引');

  // ─────────────────────────────────────────────────────────────────
  // E. 接线：注入入口唯一 + 对话后观察
  // ─────────────────────────────────────────────────────────────────
  print('');
  print('-- E. 接线 --');
  final agent = _read('lib/core/agent_service.dart');
  final win = agent.indexOf('Future<String> _augmentWithRecall');
  final winBody = win < 0 ? '' : agent.substring(win, win + 3000);
  check(winBody.contains('ProfileCardStore.i.buildCardsBlock'),
      '画像卡注入在 _augmentWithRecall（与行为画像**同一入口**，R21）');
  check(winBody.contains('profileEnabled ? await ProfileCardStore.i'),
      '画像卡受同一个 profile_enabled 开关约束（不再开第三个开关绕过主人关闭）');
  final iRecallGate = winBody.indexOf('recall_enabled');
  final iCards = winBody.indexOf('buildCardsBlock');
  check(iRecallGate >= 0 && iCards > iRecallGate,
      '回忆总闸早于画像卡读取（二级 gate 不被绕过）');

  final chat = _read('lib/ui/chat_screen.dart');
  check(chat.contains('ProfileCardStore.i.observeTurn(text)'),
      '主聊天在每轮之后观察主人原话（只喂主人的话，不喂 AI 回复）');
  check(chat.contains('unawaited(ProfileCardStore.i.observeTurn'),
      '观察是非阻塞的（不 await）—— 画像是增强，不许拖慢对话');
  final iInsertMsg = chat.indexOf('_messages.insert(0, ChatMessageData(text: aiResponse.reply');
  final iObserve = chat.indexOf('observeTurn(text)');
  check(iInsertMsg > 0 && iObserve > iInsertMsg,
      '观察排在回复上屏**之后**（即使它写坏库，本轮对话已拿到）');

  // 小精灵阶段码 ↔ UI 映射覆盖
  final events = _read('lib/core/app_events.dart');
  final sprite = _read('lib/ui/chat_sprite.dart');
  final codes = RegExp(r"static const String (\w+) = '(\w+)';")
      .allMatches(events.substring(
          events.indexOf('class AgentActivity'), events.indexOf('class AgentActivityEvent')))
      .map((m) => m.group(2)!)
      .toList();
  check(codes.length == 8,
      'AgentActivity 共 8 个码（实际 ${codes.length}: $codes）');
  var mapped = 0;
  for (final c in codes) {
    if (chat.contains('AgentActivity.$c =>') || c == 'idle') mapped++;
  }
  check(mapped == codes.length,
      '每个阶段码在 UI 侧都有映射（实际 $mapped/${codes.length}）'
      '—— 加码忘了改 UI 会当场被这条钉住');
  check(sprite.isNotEmpty && sprite.contains('SpritePhase.idle'),
      'chat_sprite.dart 存在且定义 idle');

  // ─────────────────────────────────────────────────────────────────
  // F. ARB：新增界面文案五语种齐
  // ─────────────────────────────────────────────────────────────────
  print('');
  print('-- F. ARB 五语种 --');
  const newKeys = <String>[
    'profileCardsTitle',
    'profileCardsEmpty',
    'profileCardsAdd',
    'profileCardsPendingHint',
  ];
  for (final arb in _arbFiles) {
    final text = _read(arb);
    late Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      check(false, '$arb 可解析为 JSON ($e)');
      continue;
    }
    final missing = newKeys.where((k) => !json.containsKey(k)).toList();
    check(missing.isEmpty,
        '${arb.split('/').last} 含 ${newKeys.length} 个画像卡键'
        '${missing.isEmpty ? '' : '，缺: $missing'}');
  }

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}

/// 所有 `db.delete` 都必须落在**主人意志驱动**的三个方法之内
/// （否决待裁决 / 删除某张卡 / 清空）。
///
/// 为什么要有这条：`upsert` 的四个分支里**一个都不许删行** ——
/// 冲突的正确处置是"留痕取代"，删行会让画像失去来路（需求要求保留来源与时间）。
/// 判据用"首次出现的位置之后"：三个方法在文件里是连续的收尾段，
/// 在它们之前出现的任何 delete 都是新加的越权删除。
bool _hasOwnerDelete(String storeCode) {
  final idxs = <int>[];
  var from = 0;
  while (true) {
    final i = storeCode.indexOf('db.delete', from);
    if (i < 0) break;
    idxs.add(i);
    from = i + 1;
  }
  if (idxs.isEmpty) return true;
  final firstAllowed = storeCode.indexOf('Future<void> rejectPending');
  final hasAll = firstAllowed > 0 &&
      storeCode.contains('Future<void> deleteCard') &&
      storeCode.contains('Future<void> clear');
  if (!hasAll) return false;
  return idxs.every((i) => i > firstAllowed);
}
