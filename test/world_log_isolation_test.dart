// 世界房间 → 小荒社区日志隔离（0.109.0）行为级回归。
//
// 背景（主人 2026-10-16 指令）：「拉取世界房间的历史信息时，它居然把其他智能体的发言都
// 纳入到流水日志中去了……这是小荒社区日志，没有必要记录世界房间里的信息！」
//
// 为什么必须是**行为级**（真 SQLite + 真 `handleWorldRoomMessage`）而不是源码扫描：
// 源码扫描只能证明"某一行没了"，证明不了**整条路径**上再无第二条世界→social_logs
// 写入（0.109.0 实际堵了 10 处：6 处直写 + `_auditWithRewrite` 3 处审查留痕加闸 +
// 世界调用方开关）。只有真跑一次入站消息、数一遍表，才能下"零新增"的结论。
//
// 反空转设计（否则"零新增"可能是库没连上/查询写错造成的假绿）：
//   ① 同一条消息必须在 `memory_events` 留下 `world_receive`（证明观察点真执行到）；
//   ② `lastWorldDecision` 必须读到决策文本（证明 prefs 留痕线仍在工作）；
//   ③ 正对照：普通社交路径写 social_logs 必须成功落库（证明表可写、查询没错）。
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/agent_service.dart';
import 'package:dahuang_ai/core/app_events.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DBHelper.schemaVersion,
          onCreate: (d, v) => DBHelper.migrate(d, from: 0, to: v),
        ));
    DBHelper.attachDbForTest(db);
    await DBHelper.saveAmbassador('my_agent_id', 'AG-me');
  });

  tearDown(() async {
    DBHelper.detachDbForTest();
    await db.close();
  });

  Future<int> socialRows() async =>
      ((await db.rawQuery('SELECT COUNT(*) AS c FROM social_logs')).first['c']
          as int);

  test('入站世界消息：social_logs 零新增；记忆事件与房间决策照常留痕', () async {
    final before = await socialRows();
    await AgentService().handleWorldRoomMessage(WorldRoomMessageEvent(
      roomId: 'room_iso_1',
      senderAgentId: 'AG-other',
      nickname: '外乡智能体',
      message: '你好呀',
    ));

    expect(await socialRows(), before,
        reason: '世界房间的任何信息都不得写入 social_logs（小荒社区日志）');

    // 反空转①：观察点确实执行到了（记忆事件流收到 world_receive）
    final mem = await db.query('memory_events',
        where: 'event_type = ?', whereArgs: ['world_receive']);
    expect(mem, hasLength(1));
    expect(mem.first['summary'].toString(), contains('外乡智能体'));
    expect(mem.first['summary'].toString(), contains('你好呀'));

    // 反空转②：房间页「为什么没回话」的出处仍在
    final decision = await AgentService.lastWorldDecision('room_iso_1');
    expect(decision, contains('托管未开启'));
  });

  test('正对照：普通社交路径仍写 social_logs（证明零新增不是库坏了）', () async {
    await DBHelper.insertSocialLog('receive', 'AG-peer', 'peer 说你好');
    final rows = await db.query('social_logs');
    expect(rows, hasLength(1));
    expect(rows.first['action_type'], 'receive');
  });

  test('身份缺失：只留 prefs 决策，不写 social_logs', () async {
    await DBHelper.saveAmbassador('my_agent_id', '');
    final before = await socialRows();
    await AgentService().handleWorldRoomMessage(WorldRoomMessageEvent(
      roomId: 'room_iso_2',
      senderAgentId: 'AG-other',
      nickname: '外乡智能体',
      message: '在吗',
    ));
    expect(await socialRows(), before);
    expect(await AgentService.lastWorldDecision('room_iso_2'), contains('身份缺失'));
  });
}
