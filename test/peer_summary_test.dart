// 会话压缩（私聊 0.44.0 / 会客厅 0.45.0）验证。
//
// 三层：
//  ① `peer_summaries`（按 peer）/ `room_summaries`（按房间）的读写（真 SQLite 引擎）
//     —— 滚动摘要要能**跨轮持久**，且各自主键保证"一个维度只留最新一份"
//     （重复写是 UPDATE 不叠加）；
//  ② `getRecentChatLogs` 的 **SQL 侧白名单过滤** —— 评审 §二 P4 的修正：
//     系统 / 基建日志不得再挤占"对话上下文"窗口。
//
// ⚠️ 为什么不满足于源码扫描：`IN ('send','send_manual','receive','system')` 这种
//    白名单漏一个类型、或 orderBy 写成 ASC，源码扫描看不出——只有真跑一次 SQL 才知道。
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<List<String>> _tables(Database db) async {
  final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
  return rows.map((r) => (r['name'] ?? '').toString()).toList();
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

  group('peer_summaries（真 SQLite 引擎）', () {
    test('迁移建出 peer_summaries（v35）', () async {
      expect(await _tables(db), contains('peer_summaries'));
      final cols =
          (await db.rawQuery('PRAGMA table_info(peer_summaries)'))
              .map((r) => (r['name'] ?? '').toString())
              .toList()
            ..sort();
      expect(cols,
          ['covered_until_id', 'peer_id', 'summary', 'updated_ms']);
    });

    test('upsert + get 往返：摘要与游标都能读回', () async {
      expect(await DBHelper.getPeerSummary('AG-x'), isNull, reason: '首次无记录');
      await DBHelper.upsertPeerSummary('AG-x',
          summary: '聊过周六爬山', coveredUntilId: 42);
      final row = await DBHelper.getPeerSummary('AG-x');
      expect(row, isNotNull);
      expect(row!['summary'], '聊过周六爬山');
      expect(row['covered_until_id'], 42);
    });

    test('主键 peer_id：重复摘要是覆盖，不叠出第二行', () async {
      await DBHelper.upsertPeerSummary('AG-x', summary: '第一版', coveredUntilId: 10);
      await DBHelper.upsertPeerSummary('AG-x', summary: '第二版', coveredUntilId: 20);
      final rows = await db.query('peer_summaries', where: 'peer_id = ?', whereArgs: ['AG-x']);
      expect(rows.length, 1, reason: '★ 一个 peer 只留最新一份滚动摘要');
      expect(rows.first['summary'], '第二版');
      expect(rows.first['covered_until_id'], 20, reason: '游标一并推进');
    });

    test('不同 peer 各自独立', () async {
      await DBHelper.upsertPeerSummary('AG-a', summary: '甲的摘要', coveredUntilId: 5);
      await DBHelper.upsertPeerSummary('AG-b', summary: '乙的摘要', coveredUntilId: 7);
      expect((await DBHelper.getPeerSummary('AG-a'))!['summary'], '甲的摘要');
      expect((await DBHelper.getPeerSummary('AG-b'))!['summary'], '乙的摘要');
    });
  });

  group('room_summaries（会客厅滚动摘要，真 SQLite 引擎，0.45.0）', () {
    test('迁移建出 room_summaries（v36）', () async {
      expect(await _tables(db), contains('room_summaries'));
      final cols = (await db.rawQuery('PRAGMA table_info(room_summaries)'))
          .map((r) => (r['name'] ?? '').toString())
          .toList()
        ..sort();
      expect(cols, ['covered_until_id', 'room_id', 'summary', 'updated_ms']);
    });

    test('upsert + get 往返：摘要与游标都能读回', () async {
      expect(await DBHelper.getRoomSummary('lobby'), isNull, reason: '首次无记录');
      await DBHelper.upsertRoomSummary('lobby',
          summary: '房间聊过周末聚会', coveredUntilId: 88);
      final row = await DBHelper.getRoomSummary('lobby');
      expect(row, isNotNull);
      expect(row!['summary'], '房间聊过周末聚会');
      expect(row['covered_until_id'], 88);
    });

    test('主键 room_id：重复摘要是覆盖，不叠出第二行', () async {
      await DBHelper.upsertRoomSummary('lobby', summary: '第一版', coveredUntilId: 10);
      await DBHelper.upsertRoomSummary('lobby', summary: '第二版', coveredUntilId: 30);
      final rows =
          await db.query('room_summaries', where: 'room_id = ?', whereArgs: ['lobby']);
      expect(rows.length, 1, reason: '★ 一个房间只留最新一份滚动摘要');
      expect(rows.first['summary'], '第二版');
      expect(rows.first['covered_until_id'], 30, reason: '游标一并推进');
    });

    test('不同房间各自独立；房间维度与 peer 维度是两张表、互不串', () async {
      await DBHelper.upsertRoomSummary('room-1', summary: '一号房摘要', coveredUntilId: 5);
      await DBHelper.upsertRoomSummary('room-2', summary: '二号房摘要', coveredUntilId: 9);
      expect((await DBHelper.getRoomSummary('room-1'))!['summary'], '一号房摘要');
      expect((await DBHelper.getRoomSummary('room-2'))!['summary'], '二号房摘要');
      // ★ 用一个同名键写 peer 表：两张表互不干扰（维度不同，绝不是同一份数据的两种读法）
      await DBHelper.upsertPeerSummary('room-1',
          summary: 'peer 同名但不同表', coveredUntilId: 1);
      expect((await DBHelper.getRoomSummary('room-1'))!['summary'], '一号房摘要');
      expect((await DBHelper.getPeerSummary('room-1'))!['summary'], 'peer 同名但不同表');
    });
  });

  group('getRecentChatLogs（SQL 侧白名单过滤，评审 §二 P4）', () {
    Future<void> log(String type, String target, int ts, String desc) =>
        db.insert('social_logs', {
          'timestamp': ts,
          'action_type': type,
          'target_id': target,
          'description': desc,
        });

    test('只取对话四类；infra / observe 被挡在 SQL 之外', () async {
      const peer = 'AG-p';
      await log('send', peer, 1, '分身说');
      await log('receive', peer, 2, '对方说');
      await log('send_manual', peer, 3, '主人插话');
      await log('system', peer, 4, '系统提示');
      await log('infra', peer, 5, '隧道断开'); // 噪音
      await log('observe', peer, 6, '观察记录'); // 噪音

      final got = await DBHelper.getRecentChatLogs(peer, limit: 50);
      final types = got.map((e) => e['action_type']).toSet();
      expect(types, {'send', 'receive', 'send_manual', 'system'});
      expect(types, isNot(contains('infra')));
      expect(types, isNot(contains('observe')));
    });

    test('噪音再多也不挤掉对话行（这正是旧路径的病）', () async {
      const peer = 'AG-q';
      // 1 条对话 + 120 条 infra：旧路径"先取全类型 200 再过滤"若窗口更小就会丢对话
      await log('send', peer, 1, '唯一一条对话');
      for (var i = 0; i < 120; i++) {
        await log('infra', peer, 100 + i, '噪音$i');
      }
      final got = await DBHelper.getRecentChatLogs(peer, limit: 50);
      expect(got.length, 1, reason: 'SQL 侧过滤后只剩那条对话');
      expect(got.first['description'], '唯一一条对话');
    });

    test('新→旧排序（timestamp DESC），且含 target=all 的全局行', () async {
      const peer = 'AG-r';
      await log('send', peer, 100, '早');
      await log('receive', peer, 200, '晚');
      await log('system', 'all', 150, '全局系统提示');

      final got = await DBHelper.getRecentChatLogs(peer, limit: 50);
      expect(got.map((e) => e['description']).toList(), ['晚', '全局系统提示', '早'],
          reason: '按 timestamp DESC；target=all 也在域内');
    });
  });
}
