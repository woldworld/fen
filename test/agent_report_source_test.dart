// 智能体周报统计源（0.74.0 W5/S7）验证。
//
// 为什么用**真 SQLite 引擎**：最容易错的是 SQL 语义（where 时间窗、列名），
// 桩测不出"列名拼错 / where 少条件"。分类映射是纯函数，直接断言。
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/agent_report_source.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('AgentActionStats.categorize（纯函数分类）', () {
    test('设备操作按 device_ 前缀归类', () {
      expect(AgentActionStats.categorize('device_tap'),
          AgentActionCategory.device);
      expect(AgentActionStats.categorize('device_open_app'),
          AgentActionCategory.device);
    });

    test('社交 / 工具 / 建议 / 审查 各归其类', () {
      expect(AgentActionStats.categorize('social_send'),
          AgentActionCategory.social);
      expect(AgentActionStats.categorize('world_reply'),
          AgentActionCategory.social);
      expect(AgentActionStats.categorize('create_tool'),
          AgentActionCategory.tools);
      expect(AgentActionStats.categorize('change_settings'),
          AgentActionCategory.tools);
      expect(AgentActionStats.categorize('proactive_suggestion'),
          AgentActionCategory.suggestion);
      expect(AgentActionStats.categorize('plugin_denied'),
          AgentActionCategory.review);
      expect(AgentActionStats.categorize('policy_error'),
          AgentActionCategory.review);
    });

    test('未知类型落入 other（不丢数据）', () {
      expect(AgentActionStats.categorize('some_future_type'),
          AgentActionCategory.other);
      expect(AgentActionStats.categorize(''),
          AgentActionCategory.other);
    });
  });

  group('SqliteAgentReportSource（真 SQLite 引擎）', () {
    late Database db;

    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
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

    test('时间窗外的动作不计入；窗口内按类别聚合', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = now - const Duration(days: 30).inMilliseconds;
      final recent = now - const Duration(days: 1).inMilliseconds;

      Future<void> ins(String type, int ts) => db.insert('agent_actions', {
            'action_type': type,
            'target_id': null,
            'detail': 'x',
            'status': 'done',
            'created_at': ts,
          });

      await ins('device_tap', recent);
      await ins('device_open_app', recent);
      await ins('social_send', recent);
      await ins('create_tool', recent);
      await ins('proactive_suggestion', recent);
      await ins('plugin_denied', recent);
      await ins('device_tap', old); // 窗口外，应被排除

      final since = now - const Duration(days: 7).inMilliseconds;
      final stats = await SqliteAgentReportSource().aggregateSince(since);

      expect(stats.total, 6, reason: '窗口内 6 条（30 天前那条被排除）');
      expect(stats.isEmpty, isFalse);
      expect(stats.byCategory[AgentActionCategory.device], 2);
      expect(stats.byCategory[AgentActionCategory.social], 1);
      expect(stats.byCategory[AgentActionCategory.tools], 1);
      expect(stats.byCategory[AgentActionCategory.suggestion], 1);
      expect(stats.byCategory[AgentActionCategory.review], 1);
    });

    test('空表 ⇒ 空统计（不抛）', () async {
      final stats = await SqliteAgentReportSource()
          .aggregateSince(DateTime.now().millisecondsSinceEpoch);
      expect(stats.isEmpty, isTrue);
      expect(stats.total, 0);
      expect(stats.byCategory, isEmpty);
    });
  });
}
