import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'intercard_service.dart';

/// [InterCardStore] 的 SQLite 实现（迁移版本 23，见 DBHelper._migrateV23）。
class DbInterCardStore implements InterCardStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> upsert(InterCard c) async {
    final db = await _db;
    await db.insert('intercards', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> insertIfAbsent(InterCard c) async {
    final db = await _db;
    await db.insert('intercards', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<InterCard?> byId(String id) async {
    final db = await _db;
    final rows = await db.query('intercards', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return InterCard.fromMap(rows.first);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('intercards', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<InterCard>> inbox(String toId) async {
    final db = await _db;
    final rows = await db.query('intercards',
        where: 'to_id = ? AND revoked_at IS NULL AND sig IS NOT NULL',
        whereArgs: [toId],
        orderBy: 'generated_at DESC');
    return rows.map(InterCard.fromMap).toList();
  }

  @override
  Future<List<InterCard>> mine(String ownerId) async {
    final db = await _db;
    final rows = await db.query('intercards',
        where: 'owner_id = ?',
        whereArgs: [ownerId],
        orderBy: 'generated_at DESC');
    return rows.map(InterCard.fromMap).toList();
  }
}
