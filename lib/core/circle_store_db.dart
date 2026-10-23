import 'package:sqflite/sqflite.dart';

import 'circle_service.dart';
import 'db_helper.dart';

/// [CircleStore] 的 SQLite 实现（迁移版本 20，见 DBHelper._migrateV20）。
///
/// 单独成文件的原因：`circle_service.dart` 保持零平台依赖，
/// 可直接在 `dart run` 中验证；持久化细节隔离在这里。
class DbCircleStore implements CircleStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> upsertMembership(CircleMembership m) async {
    final db = await _db;
    await db.insert(
      'circle_members',
      m.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<CircleMembership>> membersOf(String circleId) async {
    final db = await _db;
    final rows = await db.query(
      'circle_members',
      where: 'circle_id = ?',
      whereArgs: [circleId],
      orderBy: 'joined_at ASC',
    );
    return rows.map(CircleMembership.fromMap).toList();
  }

  @override
  Future<CircleMembership?> find(String circleId, String memberId) async {
    final db = await _db;
    final rows = await db.query(
      'circle_members',
      where: 'circle_id = ? AND member_id = ?',
      whereArgs: [circleId, memberId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CircleMembership.fromMap(rows.first);
  }

  @override
  Future<void> upsertCircle(
      {required String id, required String name, String? city}) async {
    final db = await _db;
    await db.insert(
      'circles',
      {
        'circle_id': id,
        'name': name,
        'city': city,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 我加入的所有圈（供 UI 列列入场后的邻里圈）。
  Future<List<String>> myCircles(String memberId) async {
    final db = await _db;
    final rows = await db.query(
      'circle_members',
      columns: ['circle_id'],
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
    return rows.map((r) => r['circle_id'] as String).toList();
  }

  /// 我在 [sinceMs] 之后新加入的圈（每日摘要用，DigestSources.recentJoins）。
  Future<List<Map<String, dynamic>>> recentJoins(
      String memberId, int sinceMs) async {
    final db = await _db;
    return db.rawQuery(
      'SELECT c.circle_id, c.name, me.joined_at FROM circle_members me '
      'JOIN circles c ON c.circle_id = me.circle_id '
      'WHERE me.member_id = ? AND me.joined_at >= ? '
      'ORDER BY me.joined_at DESC',
      [memberId, sinceMs],
    );
  }

  /// 我加入的圈**带名称与成员数**（UI 直接可用，不用再逐圈查一次）。
  Future<List<Map<String, dynamic>>> circlesOf(String memberId) async {
    final db = await _db;
    return db.rawQuery(
      'SELECT c.circle_id, c.name, c.city, c.created_at, '
      '(SELECT COUNT(*) FROM circle_members m WHERE m.circle_id = c.circle_id) '
      'AS member_count FROM circles c '
      'JOIN circle_members me ON me.circle_id = c.circle_id '
      'WHERE me.member_id = ? ORDER BY c.created_at DESC',
      [memberId],
    );
  }
}
