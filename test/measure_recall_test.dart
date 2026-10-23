// 记忆召回**度量**（0.78.0 · 方案 §2-E）：把"记忆变好了"从**声明**变成**读数**。
//
// 为什么需要它：前几轮交付的是"改动 + 三关绿 + 合成用例" —— 那证明的是
// **"代码改对了"**，不是 **"记忆变好了"**。两者不是一回事。本文件给一组
// **固定样本**上的命中率对比（这是"完善记忆系统"这一目标的**达成度**读数）。
//
// 对比口径（诚实说明，别把复现当成了两份代码）：
//   · 改后 = 真实的 `DBHelper.extractRecallKeywords` + 真实的 `buildRecallBlock`；
//   · 改前 = "0.77.0 的决策函数"在本文件内的**等价复现**（旧切词：**不**丢弃含功能字
//     的二元组；打分 / SQL / 排序兜底与 0.78.0 逐条相同）。
//     同一进程无法同时加载两个版本的 `DBHelper`，故复现的是**决策函数**、不是两份
//    代码修订。为防"复现写飘了还全绿"，本文件用一条**交叉校验**把它钉死：
//     本地复现的（改后）排序结果必须与真实 `buildRecallBlock` 的腿②**逐条一致**。
//
// 样本设计（25 条固定查询 = 20 条"不利" + 5 条对照组，合成库）：每条投放
//   ① 1 条"贴题"记忆（含查询的**一个实词片段**）；
//   ② 8 条只含**噪声片段**（如 `天的` / `的会`）且**更新**的"干扰"记忆。
// 判据 = 贴题记忆是否进 top-6。噪声片段由查询自身导出（`旧切词 − 新切词`），
// 不是手写常量 —— 换一条查询，样本自动跟着变。
// ⚠️ **诚实边界**：这是**刻意构造的不利情形**（干扰项既更近、又命中噪声片段）⇒
//   它证明的是**机制**（噪声片段确实能把贴题记忆挤出 top-6），**不代表**真实语料
//   里的绝对提升幅度；对照组用于证明"对比不是一律变好"。
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 20 条（查询, 贴题记忆正文）。贴题正文刻意只含**一个**实词片段，
/// 这样它在"改前"里与干扰记忆的分差最小、最容易被噪声压下去。
const List<List<String>> _samples = [
  ['想订明天的会议室', '会议已经安排好了'],
  ['整理上次的账单', '账单我收好了'],
  ['妈妈做的清淡菜', '清淡一点比较好'],
  ['买的牛奶面包', '牛奶喝完了'],
  ['那个电影的剧情', '电影很好看'],
  ['周末爬山的计划', '爬山改期了'],
  ['医生说的喝温水', '温水记得喝'],
  ['下月的预算没批', '预算还在审批'],
  ['钢琴课的时间', '时间要调整'],
  ['川菜馆的味道', '川菜很正宗'],
  ['手机的电池不耐用', '电池该换了'],
  ['下周的上海出差', '上海见'],
  ['房子的采光很好', '采光不错'],
  ['健身房的年卡', '年卡到期了'],
  ['奶奶的血压偏高', '血压有点高'],
  ['快递的单号呢', '单号发你了'],
  ['养的那只猫很胖', '那只猫吃多了'],
  ['昨天的会议纪要', '纪要整理完了'],
  ['旅行箱的轮子坏了', '轮子需要修'],
  ['那本书借给同事了', '同事还没还'],
  // ↓ 对照组：查询**不含**功能字 ⇒ 噪声片段为空、改前改后应当**都命中**。
  //   没有对照组的话，"全都变好"会让人怀疑是对比本身写坏了。
  ['周末爬山计划要提前', '计划提前了'],
  ['牛奶面包采购清单', '采购清单做好了'],
  ['会议纪要整理归档', '整理归档都做完了'],
  ['血压偏高需要复查', '需要复查一下'],
  ['快递单号发我一下', '单号已经发过去了'],
];

/// 改前的切词（0.77.0）：与 `extractRecallKeywords` 同算法，但**不**做功能字过滤。
List<String> _oldKeywords(String text, {int max = 6}) {
  final t = text.trim();
  if (t.isEmpty) return const [];
  final raw = <String>[];
  for (final m in RegExp(r'[A-Za-z0-9_]{2,}').allMatches(t)) {
    raw.add(m.group(0)!);
  }
  for (final m in RegExp(r'[\u4e00-\u9fa5]+').allMatches(t)) {
    final run = m.group(0)!;
    if (run.length <= 4) {
      raw.add(run);
    } else {
      for (var i = 0; i + 2 <= run.length; i++) {
        raw.add(run.substring(i, i + 2));
      }
    }
  }
  final seen = <String>{};
  final out = <String>[];
  for (final k in raw) {
    if (seen.add(k)) out.add(k);
    if (out.length >= max) break;
  }
  return out;
}

class _Hit {
  final int ts;
  final String ns;
  final int id;
  final int match;
  _Hit(this.ts, this.ns, this.id, this.match);
  String get addr => 'memory://$ns/$id';
}

/// `_recallScore` 的等价复现（1.0 / 0.6 / 21 天）。
double _score(int matches, int ts) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final age = (now - ts) / 86400000.0;
  final c = age < 0 ? 0.0 : (age.isNaN ? 0.0 : age);
  return matches * 1.0 + math.pow(0.5, c / 21.0).toDouble() * 0.6;
}

/// `_fuzzyRecallHits` 的等价复现（同三表 / 同候选池 12× / 同排序兜底）。
Future<List<_Hit>> _localFuzzy(Database db, List<String> keywords,
    {int perTable = 6}) async {
  final kws =
      keywords.map((k) => k.trim()).where((k) => k.length >= 2).toSet().toList();
  if (kws.isEmpty) return const [];
  final pool = perTable * 12;
  final lower = kws.map((k) => k.toLowerCase()).toList();
  int count(Iterable<String?> fs) {
    final b = fs.map((f) => f ?? '').join('\u0001').toLowerCase();
    var n = 0;
    for (final k in lower) {
      if (b.contains(k)) n++;
    }
    return n;
  }

  String orLike(String c) => kws.map((_) => '$c LIKE ?').join(' OR ');
  final args = [for (final k in kws) '%$k%'];
  final hits = <_Hit>[];

  final msgs = await db.query('messages',
      where: orLike('text'),
      whereArgs: args,
      orderBy: 'timestamp DESC',
      limit: pool);
  for (final e in msgs) {
    hits.add(_Hit((e['timestamp'] as int?) ?? 0, 'chat', (e['id'] as int?) ?? 0,
        count([e['text']?.toString()])));
  }
  final soc = await db.query('social_logs',
      where: orLike('description'),
      whereArgs: args,
      orderBy: 'timestamp DESC',
      limit: pool);
  for (final e in soc) {
    hits.add(_Hit((e['timestamp'] as int?) ?? 0, 'social', (e['id'] as int?) ?? 0,
        count([e['description']?.toString()])));
  }
  final mem = await db.query('memory_events',
      where:
          '(${orLike('summary')}) OR (${orLike('people')}) OR (${orLike('keywords')})',
      whereArgs: [...args, ...args, ...args],
      orderBy: 'created_at DESC',
      limit: pool);
  for (final e in mem) {
    hits.add(_Hit(
        (e['created_at'] as int?) ?? 0,
        'episode',
        (e['id'] as int?) ?? 0,
        count([
          e['summary']?.toString(),
          e['people']?.toString(),
          e['keywords']?.toString(),
        ])));
  }

  hits.sort((a, b) {
    final s = _score(b.match, b.ts).compareTo(_score(a.match, a.ts));
    if (s != 0) return s;
    final n = a.ns.compareTo(b.ns);
    if (n != 0) return n;
    return b.id.compareTo(a.id);
  });
  return hits;
}

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DBHelper.schemaVersion,
          onCreate: (d, v) => DBHelper.migrate(d, from: 0, to: v),
        ));
    DBHelper.attachDbForTest(db);
  });

  tearDown(() async {
    DBHelper.detachDbForTest();
    await db.close();
  });

  test('25 条固定样本：改后命中率 ≥ 改前（含与真实实现的交叉校验）', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var beforeHits = 0;
    var afterHits = 0;
    final beforeRanks = <int>[];
    final afterRanks = <int>[];
    final rows = <String>[];

    for (var i = 0; i < _samples.length; i++) {
      final q = _samples[i][0];
      final targetText = _samples[i][1];
      await db.delete('messages');

      final targetId = await db.insert('messages', {
        'session_id': 'measure',
        'text': targetText,
        'topic': '',
        'keywords': '',
        'isUser': 1,
        'timestamp': now,
      });

      final old = _oldKeywords(q);
      final nw = DBHelper.extractRecallKeywords(q);
      // 噪声片段 = 旧切词里被新切词丢掉的（含功能字的二元组）
      final noise = old.where((k) => !nw.contains(k)).toList();
      final distractor = 'A${noise.join('#')}B';
      for (var k = 0; k < 8; k++) {
        await db.insert('messages', {
          'session_id': 'measure',
          'text': distractor,
          'topic': '',
          'keywords': '',
          'isUser': 1,
          'timestamp': now + 1000 + k, // 干扰记忆都**更新**
        });
      }

      // ── 交叉校验：本地复现（改后）必须与真实腿②逐条一致 ──
      final real = await DBHelper.buildRecallBlock(q);
      final realAddrs = RegExp(r'memory://[a-z_]+/\d+')
          .allMatches(real)
          .map((m) => m.group(0)!)
          .toList();
      final localAfter = await _localFuzzy(db, nw);
      expect(localAfter.take(6).map((h) => h.addr).toList(), equals(realAddrs),
          reason: '样本 ${i + 1}：本地复现与真实 buildRecallBlock 腿②不一致（复现写飘了？）');

      // ── 度量（改前 vs 改后，同一套复现实现，隔离"切词"这一个变量）──
      final beforeList = await _localFuzzy(db, old);
      final bIdx = beforeList.indexWhere((h) => h.id == targetId && h.ns == 'chat');
      final aIdx = localAfter.indexWhere((h) => h.id == targetId && h.ns == 'chat');
      final bHit = bIdx >= 0 && bIdx < 6;
      final aHit = aIdx >= 0 && aIdx < 6;
      if (bHit) {
        beforeHits++;
        beforeRanks.add(bIdx + 1);
      }
      if (aHit) {
        afterHits++;
        afterRanks.add(aIdx + 1);
      }
      rows.add('${i + 1}\t$q\t切词改前[${old.join(",")}]\t切词改后[${nw.join(",")}]'
          '\t改前=${bHit ? bIdx + 1 : "未命中"}\t改后=${aHit ? aIdx + 1 : "未命中"}');
    }

    double mean(List<int> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    // ignore: avoid_print
    print('== 记忆召回度量（25 条固定样本，合成库）==');
    for (final r in rows) {
      // ignore: avoid_print
      print(r);
    }
    // ignore: avoid_print
    print('命中率@6：改前 $beforeHits/${_samples.length} '
        '(${(beforeHits * 100 / _samples.length).round()}%) → '
        '改后 $afterHits/${_samples.length} '
        '(${(afterHits * 100 / _samples.length).round()}%)');
    // ignore: avoid_print
    print('命中样本平均位次：改前 ${mean(beforeRanks).toStringAsFixed(2)} → '
        '改后 ${mean(afterRanks).toStringAsFixed(2)}');

    expect(_samples.length, 25);
    expect(afterHits, equals(_samples.length), reason: '设计上改后应全部命中 top-6');
    expect(beforeHits, greaterThan(0), reason: '对照组应命中（否则是对比写坏了）');
    expect(afterHits, greaterThan(beforeHits), reason: '度量未显示改后更好');
    if (afterRanks.isNotEmpty && beforeRanks.isNotEmpty) {
      expect(mean(afterRanks), lessThanOrEqualTo(mean(beforeRanks)),
          reason: '改后平均位次不应劣化');
    }
  });
}
