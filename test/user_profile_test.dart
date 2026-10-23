// 长期用户画像（P1 双向记忆层）验证。
//
// 为什么用**真 SQLite 引擎**（`sqflite_common_ffi` + `DBHelper.attachDbForTest`）
// 而不是桩：画像的核心是一次 `session_events` 聚合 + 时间衰减排序，
// 真跑一次才能证明"按 ts 过滤窗口""JSON 里的 topic/keywords 真的被解析出来"
// 这些行为成立；源码扫描看不出聚合逻辑写反。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:dahuang_ai/core/user_profile_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('UserProfile（真 SQLite 引擎）', () {
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
    });

    tearDown(() async {
      DBHelper.detachDbForTest();
      await db.close();
    });

    Future<void> seedEvent({
      required String topic,
      String keywords = '',
      required int ts,
      String sessionId = 's1',
    }) async {
      await db.insert('session_events', {
        'session_id': sessionId,
        'type': 'user',
        'ts': ts,
        'data': jsonEncode({'topic': topic, 'keywords': keywords}),
      });
    }

    test('空库 ⇒ 空画像、注入块为空串', () async {
      final p = await UserProfileStore.i.refresh();
      expect(p.isEmpty, isTrue);
      expect(p.topics, isEmpty);
      final block = await UserProfileStore.i.buildProfileBlock();
      expect(block, isEmpty);
    });

    test('按频次排序：命中多的主题排前面', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 3; i++) {
        await seedEvent(topic: '咖啡', ts: now - i * 1000);
      }
      await seedEvent(topic: '旅行', ts: now);

      final p = await UserProfileStore.i.refresh();
      expect(p.turns, 4);
      expect(p.topics.first.name, '咖啡');
      expect(p.topics.first.hits, 3);
      expect(p.topics.any((e) => e.name == '旅行'), isTrue);
    });

    test('时间衰减：陈年高频话题让位于近期低频话题', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = now - const Duration(days: 90).inMilliseconds;
      // 旧话题：命中 10 次，但都是 90 天前（≈4.3 个半衰期 ⇒ 权重掉到 ~0.5）
      for (var i = 0; i < 10; i++) {
        await seedEvent(topic: '旧话题', ts: old + i * 1000);
      }
      // 新话题：只命中 2 次，但是今天（权重 = 2）
      await seedEvent(topic: '新话题', ts: now);
      await seedEvent(topic: '新话题', ts: now);

      final p = await UserProfileStore.i.refresh();
      expect(p.topics.first.name, '新话题',
          reason: '画像应跟随近况：近期 2 次 > 90 天前 10 次');
      final oldTopic = p.topics.firstWhere((e) => e.name == '旧话题');
      expect(oldTopic.hits, 10); // 原始频次仍如实保留
      expect(oldTopic.weight, lessThan(1.0)); // 但权重已衰减
    });

    test('关键词一并计入，且停用词被过滤', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await seedEvent(topic: '', keywords: '摄影,徒步', ts: now);
      await seedEvent(topic: '未分类', ts: now);
      await seedEvent(topic: '日常交流', ts: now);

      final p = await UserProfileStore.i.refresh();
      final names = p.topics.map((e) => e.name).toList();
      expect(names, containsAll(['摄影', '徒步']));
      expect(names, isNot(contains('未分类')));
      expect(names, isNot(contains('日常交流')));
    });

    test('活跃时段：只统计窗口内的小时', () async {
      final base = DateTime.now();
      final at21 = DateTime(base.year, base.month, base.day, 21, 30);
      await seedEvent(topic: '咖啡', ts: at21.millisecondsSinceEpoch);
      await seedEvent(topic: '咖啡', ts: at21.millisecondsSinceEpoch);
      await seedEvent(topic: '旅行', ts: DateTime(base.year, base.month, base.day, 9, 0)
          .millisecondsSinceEpoch);

      final p = await UserProfileStore.i.refresh();
      expect(p.topHours.first, 21);
      expect(p.topHours, contains(9));
    });

    test('注入块含画像要点且长度封顶', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await seedEvent(topic: '咖啡', ts: now);
      await seedEvent(topic: '咖啡', ts: now);

      final block = await UserProfileStore.i.buildProfileBlock();
      expect(block, contains('主人的长期画像'));
      expect(block, contains('咖啡'));

      final capped = await UserProfileStore.i.buildProfileBlock(maxChars: 20);
      expect(capped.length, lessThanOrEqualTo(21)); // 20 + 省略号
    });

    test('窗口外的数据不进画像', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tooOld = now - const Duration(days: 400).inMilliseconds;
      await seedEvent(topic: '远古话题', ts: tooOld);

      final p = await UserProfileStore.i.refresh();
      expect(p.topics.map((e) => e.name), isNot(contains('远古话题')));
    });
  });
}
