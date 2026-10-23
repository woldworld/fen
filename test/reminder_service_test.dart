// 提醒/待办 + 记忆管理（0.70.0 W1）验证。
//
// 为什么用**真 SQLite 引擎**（`sqflite_common_ffi` + `DBHelper.attachDbForTest`）：
// 这里最容易错的全是 SQL 语义——迁移链 37→38 的 ALTER 加列、补发去重的
// notified_at 写回、软删列在三个读取点（画像聚合 / 对话统计 / 轨迹回放）的
// 过滤——桩测不出"列名拼错""where 少一个条件"这类错，真跑才作数。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/chat_stats_source.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:dahuang_ai/core/reminder_service.dart';
import 'package:dahuang_ai/core/user_profile_store.dart';
import 'package:dahuang_ai/harness_host/sqlite_session_store.dart';
import 'package:pocket_harness/pocket_harness.dart' show SessionEvent;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('DB v38 迁移（真 SQLite 引擎）', () {
    test('全新安装（from 0）⇒ reminders 表 + session_events.deleted_at 都在', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: DBHelper.schemaVersion,
            onCreate: (d, v) => DBHelper.migrate(d, from: 0, to: v),
          ));
      addTearDown(db.close);
      final tables = await db.query('sqlite_master',
          where: "type = 'table' AND name = 'reminders'");
      expect(tables, isNotEmpty, reason: 'v38 必须建 reminders 表');
      final cols = await db.rawQuery('PRAGMA table_info(session_events)');
      expect(cols.any((c) => c['name'] == 'deleted_at'), isTrue,
          reason: 'v38 必须给 session_events 加软删列');
    });

    test('老库升级（37 → 38）⇒ 列补上、旧数据保留且 deleted_at 为 NULL', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 37,
            onCreate: (d, v) => DBHelper.migrate(d, from: 0, to: v),
          ));
      addTearDown(db.close);
      // 先在 v37 里落一条 session_events（表在 v19 已存在）
      await db.insert('session_events', {
        'session_id': 'old-s',
        'type': 'user',
        'ts': 1700000000000,
        'data': jsonEncode({'topic': '旧数据'}),
      });
      // 升级
      await DBHelper.migrate(db, from: 37, to: 38);
      final cols = await db.rawQuery('PRAGMA table_info(session_events)');
      expect(cols.any((c) => c['name'] == 'deleted_at'), isTrue);
      final rows = await db.query('session_events');
      expect(rows, hasLength(1));
      expect(rows.first['deleted_at'], isNull,
          reason: '升级用户的既有记忆必须原样保留（未删）');
      // reminders 表升级后同样可写
      await db.insert('reminders', {'title': 'x', 'created_at': 1});
      expect(await db.query('reminders'), hasLength(1));
    });
  });

  group('ReminderService（真 SQLite 引擎）', () {
    late Database db;
    final fired = <String>[];

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
      fired.clear();
      ReminderService.i.clock = DateTime.now;
    });

    tearDown(() async {
      ReminderService.i.clock = DateTime.now;
      DBHelper.detachDbForTest();
      await db.close();
    });

    Future<int> emit() => ReminderService.i.maybeEmitDue(
        notifyFn: (r) async => fired.add('${r.id}:${r.title}'));

    test('create：待办与提醒；非法 repeat 归 null；空标题拒绝', () async {
      final todo = await ReminderService.i.create(title: '买酱油');
      expect(todo.isTodo, isTrue);
      final r = await ReminderService.i.create(
          title: '开会', dueAt: 123, repeatRule: 'yearly');
      expect(r.isRepeating, isFalse, reason: 'yearly 不在白名单 ⇒ 按 null');
      expect(
        () => ReminderService.i.create(title: '   '),
        throwsArgumentError,
      );
      final list = await ReminderService.i.list();
      expect(list, hasLength(2));
      expect(list.map((e) => e.id), containsAll([todo.id, r.id]));
    });

    test('list 排序：定时的在前按时间升序，待办垫底', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await ReminderService.i.create(title: '待办B');
      await ReminderService.i.create(title: '晚的', dueAt: now + 7200000);
      await ReminderService.i.create(title: '早的', dueAt: now + 60000);
      await ReminderService.i.create(title: '待办A');
      final list = await ReminderService.i.list();
      expect(list.map((e) => e.title).toList(),
          ['早的', '晚的', '待办B', '待办A']);
    });

    test('complete / delete 生效', () async {
      final r = await ReminderService.i.create(title: 'x');
      await ReminderService.i.complete(r.id);
      expect((await ReminderService.i.list()), isEmpty);
      expect((await ReminderService.i.list(includeDone: true)), hasLength(1));
      await ReminderService.i.delete(r.id);
      expect((await ReminderService.i.list(includeDone: true)), isEmpty);
    });

    test('maybeEmitDue：到期触发一次并写回 notified_at；第二轮不重复', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final r = await ReminderService.i.create(title: '到点了', dueAt: now - 1000);
      expect(await emit(), 1);
      expect(fired, ['${r.id}:到点了']);
      final after = await db.query('reminders', where: 'id = ?', whereArgs: [r.id]);
      expect((after.first['notified_at'] as int?), isNotNull);
      expect(await emit(), 0, reason: '已提醒过 ⇒ 补发去重');
      expect(fired, hasLength(1));
    });

    test('maybeEmitDue：未到期不触发', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await ReminderService.i.create(title: '未来', dueAt: now + 3600000);
      expect(await emit(), 0);
      expect(fired, isEmpty);
    });

    test('maybeEmitDue：待办（due_at NULL）不触发', () async {
      await ReminderService.i.create(title: '纯待办');
      expect(await emit(), 0);
    });

    test('maybeEmitDue：通知失败不写标记，下一轮重试', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final r = await ReminderService.i.create(title: '失败重试', dueAt: now - 1);
      var calls = 0;
      final boom = (Reminder r) async {
        calls++;
        throw StateError('presenter down');
      };
      expect(await ReminderService.i.maybeEmitDue(notifyFn: boom), 0);
      final rows = await db.query('reminders', where: 'id = ?', whereArgs: [r.id]);
      expect(rows.first['notified_at'], isNull);
      expect(await emit(), 1, reason: '上一轮失败 ⇒ 标记没写 ⇒ 这轮补上');
      expect(calls, 1, reason: '失败那次不计入 fired');
    });

    test('重复提醒：触发后推进一个周期、notified_at 清空；死 3 天只补响 1 次', () async {
      final now = DateTime.now();
      final due = now.subtract(const Duration(days: 3));
      final r = await ReminderService.i.create(
          title: '吃药',
          dueAt: due.millisecondsSinceEpoch,
          repeatRule: 'daily');
      expect(await emit(), 1, reason: '错过 3 天也只补响一次');
      final rows = await db.query('reminders', where: 'id = ?', whereArgs: [r.id]);
      final nextDue = rows.first['due_at'] as int;
      final next = DateTime.fromMillisecondsSinceEpoch(nextDue);
      expect(next.isAfter(now), isTrue, reason: '推进到"下一个尚未过去的周期"');
      expect(rows.first['notified_at'], isNull,
          reason: 'notified_at 清空 ⇒ 明天到点还能再响');
      // 推进点应是"明天同一时刻"：与 now 差 ≈ 24h（不该连跳，也不该停在现在）。
      // 用毫秒区间断言而非 inDays —— Duration.inDays 向零截断，
      // 4 天差 1ms 会读成 3（毫秒截断坑，真机时间从不整）。
      final gapH = next.difference(now).inMinutes / 60.0;
      expect(gapH, greaterThan(22), reason: '推进点应至少是明天附近');
      expect(gapH, lessThan(26), reason: '推进点不应跳过一整个周期');
    });

    test('dueSoon：24h 内到期 + 全部待办，已完成不出现', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final a = await ReminderService.i.create(title: '马上', dueAt: now);
      await ReminderService.i.create(title: '明天内', dueAt: now + 3600000);
      await ReminderService.i.create(title: '太远', dueAt: now + 86400000 * 5);
      await ReminderService.i.create(title: '待办');
      await ReminderService.i.complete(a.id);
      final soon = await ReminderService.i.dueSoon();
      expect(soon.map((e) => e.title).toList(), ['明天内', '待办']);
    });
  });

  group('软删过滤（session_events.deleted_at 三个读取点）', () {
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
      UserProfileStore.i.invalidate();
      ReminderService.i.clock = DateTime.now;
    });

    tearDown(() async {
      DBHelper.detachDbForTest();
      await db.close();
    });

    Future<String> seedSession(String sid, {String topic = '咖啡'}) async {
      final store = SqliteSessionStore();
      await store.append(sid,
          SessionEvent(type: 'user', data: {'topic': topic, 'keywords': '关键词'}));
      return sid;
    }

    test('forgetSession 软删后：画像 / 统计 / 轨迹回放三处都不再读到', () async {
      await seedSession('dead');
      await seedSession('alive', topic: '旅行');
      final n = await DBHelper.forgetSession('dead');
      expect(n, 1, reason: '恰好软删该线程的全部行');

      // ① 画像聚合
      final profile = await UserProfileStore.i.refresh();
      expect(profile.topics.map((e) => e.name), isNot(contains('咖啡')));
      expect(profile.topics.map((e) => e.name), contains('旅行'));

      // ② 对话统计
      final stats =
          await SqliteChatStatsSource().aggregateSince(0);
      expect(stats.sessions, 1, reason: '只剩 alive 线程');

      // ③ 轨迹回放（全量 + 增量两个分支）
      final store = SqliteSessionStore();
      final full = await store.replay('dead');
      expect(full, isEmpty);
      final incr = await store.replay('dead', after: -1);
      expect(incr, isEmpty);
      expect(await store.replay('alive'), hasLength(1));
    });

    test('forgetSession 联动删除该线程的情景记忆', () async {
      await seedSession('gone');
      await db.insert('memory_events', {
        'event_type': 'chat_user',
        'session_id': 'gone',
        'summary': '这段要被忘掉',
        'topic': '',
        'keywords': '',
        'people': '',
        'ref_ids': '',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await DBHelper.forgetSession('gone');
      expect(await db.query('memory_events'), isEmpty);
    });

    test('deleteMemoryEvent：硬删记忆 + ref_ids 指向的 messages 行', () async {
      final msgId = await db.insert('messages', {
        'session_id': 's1',
        'text': '要删的原文',
        'isUser': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      final mid = await db.insert('memory_events', {
        'event_type': 'chat_user',
        'session_id': 's1',
        'summary': '摘要',
        'topic': '',
        'keywords': '',
        'people': '',
        'ref_ids': '$msgId',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      expect(await DBHelper.deleteMemoryEvent(mid), greaterThanOrEqualTo(2),
          reason: 'memory_events 1 行 + messages 1 行');
      expect(await db.query('memory_events'), isEmpty);
      expect(await db.query('messages'), isEmpty);
    });

    test('listSessions 只统计未软删事件', () async {
      await seedSession('x');
      await seedSession('y');
      await DBHelper.forgetSession('x');
      final sessions = await DBHelper.listSessions();
      expect(sessions.map((e) => e['session_id']), ['y']);
    });
  });
}
