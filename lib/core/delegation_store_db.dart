import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'delegation_service.dart';

/// [DelegationStore] 的 SQLite 实现（迁移版本 21，见 DBHelper._migrateV21）。
///
/// 与 `circle_store_db.dart` 同样的分工：`delegation_service.dart` 保持零平台依赖，
/// 可在 `dart run` 中验证；持久化细节隔离在这里。
class DbDelegationStore implements DelegationStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> upsert(Delegation d) async {
    final db = await _db;
    await db.insert(
      'delegations',
      d.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Delegation?> byId(String id) async {
    final db = await _db;
    final rows = await db.query(
      'delegations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Delegation.fromMap(rows.first);
  }

  /// 与我相关的委托（我发起的 + 别人托给我的）。
  @override
  Future<List<Delegation>> forPeer(String agentId) async {
    final db = await _db;
    final rows = await db.query(
      'delegations',
      where: 'to_id = ? OR from_id = ?',
      whereArgs: [agentId, agentId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Delegation.fromMap).toList();
  }

  /// 待我处理的（受托方收件箱，UI 用）。
  Future<List<Delegation>> inbox(String agentId) async {
    final db = await _db;
    final rows = await db.query(
      'delegations',
      where: "to_id = ? AND state = 'pending'",
      whereArgs: [agentId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Delegation.fromMap).toList();
  }

  /// 我发出的（主人侧看进度，UI 用）。
  Future<List<Delegation>> outbox(String agentId) async {
    final db = await _db;
    final rows = await db.query(
      'delegations',
      where: 'from_id = ?',
      whereArgs: [agentId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Delegation.fromMap).toList();
  }
}
