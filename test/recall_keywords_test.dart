// 自动回忆（0.43.0 检索增强）验证。
//
// 两层：
//  ① `extractRecallKeywords` —— 纯函数，直接断言切词行为；
//  ② `buildRecallBlock` / `_fuzzyRecallHits` —— 用**真 SQLite 引擎**
//     （`sqflite_common_ffi` + `DBHelper.attachDbForTest`）跑真 SQL，
//     断言"最近情景记忆 + 跨三表相关往事"真的被拼出来。
//
// ⚠️ 为什么不满足于源码扫描：`_fuzzyRecallHits` 里 `memory_events` 那条 WHERE
//    是"三组 OR + 参数重复三遍"，**参数个数写错**这种缺陷源码扫描根本看不出，
//    只有真跑一次 SQL 才会报 `argument count mismatch`。
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 切词：它是"系统自动回忆"的入口 —— 切错了要么捞不到相关往事，
/// 要么把整句当关键词去 LIKE（永远匹配不到）。故把行为钉死。
void main() {
  group('extractRecallKeywords', () {
    test('空串/纯标点返回空', () {
      expect(DBHelper.extractRecallKeywords(''), isEmpty);
      expect(DBHelper.extractRecallKeywords('   '), isEmpty);
      expect(DBHelper.extractRecallKeywords('，。！？'), isEmpty);
    });

    test('英文/数字取整词（长度 ≥2）', () {
      expect(DBHelper.extractRecallKeywords('hello world'),
          containsAllInOrder(['hello', 'world']));
      // 单字母被丢弃（太泛，会捞回一大堆）
      expect(DBHelper.extractRecallKeywords('a go'), equals(['go']));
    });

    test('中文短串（≤4 字）整串保留', () {
      expect(DBHelper.extractRecallKeywords('吃饭'), equals(['吃饭']));
      expect(DBHelper.extractRecallKeywords('明天'), equals(['明天']));
    });

    test('中文长串（>4 字）切成二元组', () {
      final kws = DBHelper.extractRecallKeywords('我想订明天的会议室');
      // 二元组：我想 想订 订明 明天 天的 的会 会议 议室；
      // 0.78.0 起丢弃含功能字的片段（天的 / 的会）⇒ 会议 / 议室 得以留下（默认取前 6）
      expect(kws, equals(['我想', '想订', '订明', '明天', '会议', '议室']));
      // 关键：必须含"明天"这样的实词片段，否则 LIKE 捞不到
      expect(kws, contains('明天'));
    });

    test('中英混合：ASCII 词在前、中文片段随后', () {
      final kws = DBHelper.extractRecallKeywords('明天 meeting 安排');
      expect(kws, containsAllInOrder(['meeting', '明天', '安排']));
    });

    test('去重且封顶 max', () {
      final kws = DBHelper.extractRecallKeywords('一二三四五六七八九十', max: 3);
      expect(kws.length, 3);
      expect(kws.toSet().length, 3); // 无重复
    });
  });

  group('buildRecallBlock（真 SQLite 引擎）', () {
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

    Future<void> seed() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('memory_events', {
        'event_type': 'chat',
        'session_id': '',
        'summary': '主人喜欢喝美式咖啡',
        'topic': '',
        'keywords': '',
        'people': '',
        'ref_ids': '',
        'created_at': now,
      });
      await db.insert('messages', {
        'session_id': 'main',
        'text': '上次说的那个餐厅叫什么来着',
        'topic': '',
        'keywords': '',
        'isUser': 1,
        'timestamp': now,
      });
      await db.insert('social_logs', {
        'timestamp': now,
        'action_type': 'send',
        'target_id': 'AG-1',
        'description': '跟对方聊了餐厅预订的事',
      });
    }

    test('注入最近情景记忆 + 跨三表的相关往事', () async {
      await seed();
      final block = await DBHelper.buildRecallBlock('餐厅 咖啡');
      // ① 最近情景记忆（memory_events 的读路径）
      expect(block, contains('你最近记下的事'));
      expect(block, contains('美式咖啡'));
      // ② 相关往事：对话 / 社交 两张表都要被捞到
      expect(block, contains('可能与当前话题相关的往事'));
      expect(block, contains('[对话]'));
      expect(block, contains('[社交]'));
      expect(block, contains('餐厅'));
    });

    test('无任何记忆时返回空串（调用方应跳过注入，不注入空块）', () async {
      final block = await DBHelper.buildRecallBlock('随便说点什么');
      expect(block, isEmpty);
    });

    test('长度封顶 maxChars（防长记忆撑爆系统提示词）', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 20; i++) {
        await db.insert('memory_events', {
          'event_type': 'chat',
          'session_id': '',
          'summary': '第$i条：${'很长的记忆内容' * 30}',
          'topic': '',
          'keywords': '',
          'people': '',
          'ref_ids': '',
          'created_at': now + i,
        });
      }
      final block = await DBHelper.buildRecallBlock('记忆');
      expect(block.length, lessThanOrEqualTo(1601)); // maxChars=1600 + '…'
      expect(block.endsWith('…'), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // 记忆地址（0.77.0）
  // ------------------------------------------------------------------
  // 为什么钉这个：地址若只是"打印出来好看"而**取不回东西**，模型引用了却没法
  // 回看 ⇒ 用户以为它能用，实际是个空门牌。这里用真引擎断言地址真的可兑现。
  group('记忆地址 memory://（0.77.0）', () {
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

    test('buildRecallBlock 两条腿都带 memory:// 地址', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('memory_events', {
        'event_type': 'chat',
        'session_id': '',
        'summary': '主人喜欢喝美式咖啡',
        'topic': '',
        'keywords': '',
        'people': '',
        'ref_ids': '',
        'created_at': now,
      });
      await db.insert('messages', {
        'session_id': 'main',
        'text': '上次说的那个餐厅',
        'topic': '',
        'keywords': '',
        'isUser': 1,
        'timestamp': now,
      });
      final block = await DBHelper.buildRecallBlock('咖啡 餐厅');
      // 腿①（最近情景记忆）+ 腿②（跨三表相关往事）都要带地址
      expect(block, contains('memory://episode/'));
      expect(block, contains('memory://chat/'));
    });

    test('resolveMemoryAddress 按地址取回原文（地址可兑现）', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await db.insert('memory_events', {
        'event_type': 'chat',
        'session_id': '',
        'summary': '主人对花生过敏',
        'topic': '',
        'keywords': '',
        'people': '',
        'ref_ids': '',
        'created_at': now,
      });
      final row = await DBHelper.resolveMemoryAddress('memory://episode/$id');
      expect(row, isNotNull);
      expect(row!['summary'], equals('主人对花生过敏'));
    });

    test('地址非法 / 行不存在 ⇒ 返回 null（失效地址不抛）', () async {
      expect(await DBHelper.resolveMemoryAddress('memory://episode/999999'),
          isNull);
      expect(await DBHelper.resolveMemoryAddress('memory://nope/1'), isNull);
      expect(await DBHelper.resolveMemoryAddress('随便一句话'), isNull);
    });

    test('searchAllMemory 传入地址 ⇒ 直达且不截断', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final long = '很长的记忆内容' * 60; // 420 字 —— 必然越过 140 截断线
      final id = await db.insert('memory_events', {
        'event_type': 'chat',
        'session_id': '',
        'summary': long,
        'topic': '',
        'keywords': '',
        'people': '',
        'ref_ids': '',
        'created_at': now,
      });
      final out = await DBHelper.searchAllMemory('memory://episode/$id');
      expect(out, contains(long)); // 全文，不是截断版
    });

    test('排序：多词共现的旧记忆排在只命中一词的新记忆之前', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      const day = 86400000;
      // 两条都放 messages ⇒ 都走腿②（相关往事），这样比较的才是打分结果
      await db.insert('messages', {
        'session_id': 'main',
        'text': '咖啡 过敏 记录', // 两个词都命中，但 60 天前
        'topic': '',
        'keywords': '',
        'isUser': 1,
        'timestamp': now - 60 * day,
      });
      await db.insert('messages', {
        'session_id': 'main',
        'text': '今天只提到咖啡', // 只命中一词，但是刚刚
        'topic': '',
        'keywords': '',
        'isUser': 1,
        'timestamp': now,
      });
      final block = await DBHelper.buildRecallBlock('咖啡 过敏');
      final iOld = block.indexOf('咖啡 过敏 记录');
      final iNew = block.indexOf('今天只提到咖啡');
      expect(iOld, greaterThanOrEqualTo(0), reason: '旧记忆应被捞到');
      expect(iNew, greaterThanOrEqualTo(0), reason: '新记忆应被捞到');
      expect(iOld, lessThan(iNew), reason: '贴题（2 词）应压过新鲜（1 词）');
    });

    test('排序确定性：同分条目连续两次结果逐字一致', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 8; i++) {
        await db.insert('messages', {
          'session_id': 'main',
          'text': '同一时间戳第$i条咖啡记录',
          'topic': '',
          'keywords': '',
          'isUser': 1,
          'timestamp': now, // 时间戳与命中词完全相同 ⇒ 全同分
        });
      }
      final a = await DBHelper.buildRecallBlock('咖啡');
      final b = await DBHelper.buildRecallBlock('咖啡');
      expect(a, equals(b),
          reason: 'Dart 的 List.sort 不稳定，同分必须靠 ns+id 兜底');
    });
  });
}
