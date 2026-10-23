import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'presence_service.dart';

/// [PresenceStore] 的 SQLite 实现（迁移版本 24，见 DBHelper._migrateV24）。
///
/// 每个 peer 只保留**最新一条**在场信号：在场是状态，不是流水。
/// 过期判断留在 core（`isFreshAt`），这里不主动删 —— 删了就查不出"刚才还在"。
class DbPresenceStore implements PresenceStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> upsert(PresenceSignal s) async {
    final db = await _db;
    await db.insert(
      'peer_presence',
      {
        'from_id': s.fromId,
        'to_id': s.toId,
        'path': s.path,
        'at_ms': s.atMs,
        'expires_at': s.expiresAtMs,
        'sig': s.sig,
        'from_pub': s.fromPub,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<PresenceSignal?> latestOf(String fromId) async {
    final db = await _db;
    final rows = await db.query('peer_presence',
        where: 'from_id = ?', whereArgs: [fromId], limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return PresenceSignal(
      fromId: r['from_id'] as String,
      toId: r['to_id'] as String,
      path: r['path'] as String,
      atMs: (r['at_ms'] as num).toInt(),
      expiresAtMs: (r['expires_at'] as num).toInt(),
      sig: r['sig'] as String?,
      fromPub: r['from_pub'] as String?,
    );
  }

  @override
  Future<List<String>> freshPeers(int nowMs) async {
    final db = await _db;
    final rows = await db.query('peer_presence',
        columns: ['from_id'],
        where: 'expires_at >= ?',
        whereArgs: [nowMs]);
    return [for (final r in rows) r['from_id'] as String];
  }

  @override
  Future<void> clear(String fromId) async {
    final db = await _db;
    await db.delete('peer_presence', where: 'from_id = ?', whereArgs: [fromId]);
  }
}

/// [SelfIntroStore] 的 SQLite 实现（迁移版本 24）。
///
/// ⚠️ **append-only 语义**：只 INSERT，绝不改写既有行的 `first_at_ms` ——
/// "第一次自报是什么时候"是审计事实，改了就说不清"到底披露过没有"。
class DbSelfIntroStore implements SelfIntroStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<bool> hasIntroduced(String peerId) async {
    final db = await _db;
    final rows = await db.query('self_intro_ledger',
        where: 'peer_id = ?', whereArgs: [peerId], limit: 1);
    return rows.isNotEmpty;
  }

  @override
  Future<bool> markIntroduced(String peerId, int atMs) async {
    final db = await _db;
    final inserted = await db.insert(
      'self_intro_ledger',
      {'peer_id': peerId, 'first_at_ms': atMs},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // sqflite：ignore 冲突时返回 0，即"本次不是首次"。
    return inserted != 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM self_intro_ledger');
    return (rows.first['c'] as num).toInt();
  }
}
