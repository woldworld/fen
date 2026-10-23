import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'room_role.dart';

/// [RoomRoleStore] 的 SQLite 实现（迁移版本 27，见 `DBHelper._migrateV27`）。
///
/// 单独成文件的原因与 `world_bridge_store_db.dart` 相同：
/// `room_role.dart` 保持零平台依赖，可直接 `dart run` 复算判定。
class DbRoomRoleStore implements RoomRoleStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> upsert(RoomRoleGrant g) async {
    final db = await _db;
    // 不用 `ON CONFLICT ... DO UPDATE`（SQLite 3.24+ 才支持，Android 10
    // 及以下系统自带 SQLite 3.22 会直接语法报错）。改为"先查再插/改"，
    // 在任何设备上都成立；角色授予是低频人工操作，无需事务级并发优化。
    final existing = await db.query('room_roles',
        where: 'room_id = ? AND agent_id = ?',
        whereArgs: [g.roomId, g.agentId],
        limit: 1);
    if (existing.isEmpty) {
      await db.insert('room_roles', g.toMap());
    } else {
      await db.update('room_roles', g.toMap(),
          where: 'room_id = ? AND agent_id = ?',
          whereArgs: [g.roomId, g.agentId]);
    }
  }

  @override
  Future<RoomRoleGrant?> get(String roomId, String agentId) async {
    final db = await _db;
    final rows = await db.query('room_roles',
        where: 'room_id = ? AND agent_id = ?',
        whereArgs: [roomId, agentId],
        limit: 1);
    if (rows.isEmpty) return null;
    return RoomRoleGrant.fromMap(rows.first);
  }

  @override
  Future<List<RoomRoleGrant>> inRoom(String roomId) async {
    final db = await _db;
    final rows = await db.query('room_roles',
        where: 'room_id = ?', whereArgs: [roomId], orderBy: 'at_ms DESC');
    return rows.map(RoomRoleGrant.fromMap).toList();
  }

  @override
  Future<List<RoomRoleGrant>> forAgent(String agentId) async {
    final db = await _db;
    final rows = await db.query('room_roles',
        where: 'agent_id = ?', whereArgs: [agentId], orderBy: 'at_ms DESC');
    return rows.map(RoomRoleGrant.fromMap).toList();
  }
}
