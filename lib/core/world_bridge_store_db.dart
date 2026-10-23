import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'world_bridge_service.dart';

/// [BridgeLinkStore] / [RoomPresenceStore] 的 SQLite 实现（迁移版本 25，
/// 见 `DBHelper._migrateV25`）。
///
/// 单独成文件的原因与 `circle_store_db.dart` 相同：
/// `world_bridge_service.dart` 保持零平台依赖，可直接 `dart run` 复算判定。
class DbBridgeLinkStore implements BridgeLinkStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> insert(BridgeLink l) async {
    final db = await _db;
    // 幂等：PK = `self->peer`，重复建边不产生第二条账
    await db.insert('bridge_links', l.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<BridgeLink>> linksOf(String selfId) async {
    final db = await _db;
    final rows = await db.query('bridge_links',
        where: 'self_id = ?', whereArgs: [selfId], orderBy: 'at_ms DESC');
    return rows.map(BridgeLink.fromMap).toList();
  }

  @override
  Future<BridgeLink?> find(String selfId, String peerId) async {
    final db = await _db;
    final rows = await db.query('bridge_links',
        where: 'self_id = ? AND peer_id = ?',
        whereArgs: [selfId, peerId],
        limit: 1);
    if (rows.isEmpty) return null;
    return BridgeLink.fromMap(rows.first);
  }
}

class DbRoomPresenceStore implements RoomPresenceStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> observe({
    required String roomId,
    required String agentId,
    required String nickname,
    required int atMs,
  }) async {
    final db = await _db;
    // 不用 `ON CONFLICT ... DO UPDATE`（SQLite 3.24+ 才支持，Android 10
    // 及以下系统自带 SQLite 3.22 会直接语法报错）。改为事务内读改写，
    // 在任何设备上都成立，且并发两条消息不会各自读到旧值再写回。
    await db.transaction((txn) async {
      final rows = await txn.query('room_presences',
          columns: ['nickname', 'msg_count'],
          where: 'room_id = ? AND agent_id = ?',
          whereArgs: [roomId, agentId],
          limit: 1);
      if (rows.isEmpty) {
        await txn.insert('room_presences', {
          'room_id': roomId,
          'agent_id': agentId,
          'nickname': nickname,
          'msg_count': 1,
          'last_seen': atMs,
        });
      } else {
        final prevNick = (rows.first['nickname'] as String?) ?? '';
        final prevCount = (rows.first['msg_count'] as num?)?.toInt() ?? 0;
        await txn.update(
          'room_presences',
          {
            'msg_count': prevCount + 1,
            'last_seen': atMs,
            'nickname': nickname.isEmpty ? prevNick : nickname,
          },
          where: 'room_id = ? AND agent_id = ?',
          whereArgs: [roomId, agentId],
        );
      }
    });
  }

  @override
  Future<List<RoomPresence>> presences(String selfId) async {
    final db = await _db;
    final rows = await db.query('room_presences',
        where: 'agent_id != ?', whereArgs: [selfId], orderBy: 'last_seen DESC');
    return rows.map(RoomPresence.fromMap).toList();
  }

  @override
  Future<List<RoomPresence>> inRoom(String roomId, String selfId) async {
    final db = await _db;
    final rows = await db.query('room_presences',
        where: 'room_id = ? AND agent_id != ?',
        whereArgs: [roomId, selfId],
        orderBy: 'last_seen DESC');
    return rows.map(RoomPresence.fromMap).toList();
  }
}
