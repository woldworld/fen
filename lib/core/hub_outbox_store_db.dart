import 'db_helper.dart';
import 'hub_outbox.dart';

/// [HubOutboxStore] 的 SQLite 实现（迁移版本 33，见 `DBHelper._migrateV33`）。
///
/// 表只有"待发"语义：**发送成功即 DELETE**。
/// 刻意**没有 status / sent_at 之类的标志列** —— 一个可以长期停留在
/// "已发送但还在表里"的状态，会让"到底哪些还没公布"这个问题失去唯一答案，
/// 而那个答案正是 §16「你可以验我」能不能被回答的前提。
class DbHubOutboxStore implements HubOutboxStore {
  @override
  Future<int> enqueue(HubOutboxItem item) async {
    final db = await DBHelper.db;
    return db.insert('hub_outbox', {
      'endpoint': item.endpoint,
      'payload': item.payloadJson,
      'attempts': item.attempts,
      'next_at_ms': item.nextAttemptAtMs,
      'created_at_ms': item.createdAtMs,
      'last_error': item.lastError,
    });
  }

  @override
  Future<List<HubOutboxItem>> due({required int nowMs, int limit = 50}) async {
    final db = await DBHelper.db;
    final rows = await db.query(
      'hub_outbox',
      where: 'next_at_ms <= ?',
      whereArgs: [nowMs],
      orderBy: 'id ASC',
      limit: limit,
    );
    return [for (final r in rows) HubOutboxItem.fromMap(r)];
  }

  @override
  Future<void> markAttempt(int id, String error, int nextAttemptAtMs) async {
    final db = await DBHelper.db;
    // ⚠️ 用 SQL 侧自增（`attempts + 1`）而不是"先读再写"：
    //    读-改-写在并发下会丢计数，而计数是退避时长的唯一输入。
    await db.rawUpdate(
      'UPDATE hub_outbox SET attempts = attempts + 1, next_at_ms = ?, '
      'last_error = ? WHERE id = ?',
      [nextAttemptAtMs, error, id],
    );
  }

  @override
  Future<void> remove(int id) async {
    final db = await DBHelper.db;
    await db.delete('hub_outbox', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> count() async {
    final db = await DBHelper.db;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM hub_outbox');
    return (r.isEmpty ? 0 : (r.first['c'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<void> clear() async {
    final db = await DBHelper.db;
    await db.delete('hub_outbox');
  }

  /// 容量控制：超出 [HubOutboxPolicy.maxQueued] 时删**最旧**的若干条，
  /// 返回被删条数（调用方据此留埋点 —— 丢弃必须是**可观测**的，不能静默）。
  Future<int> trimOldest() async {
    final db = await DBHelper.db;
    final n = await count();
    final over = n - HubOutboxPolicy.maxQueued;
    if (over <= 0) return 0;
    final rows = await db.query(
      'hub_outbox',
      columns: ['id'],
      orderBy: 'id ASC',
      limit: over,
    );
    for (final r in rows) {
      await db.delete('hub_outbox', where: 'id = ?', whereArgs: [r['id']]);
    }
    return over;
  }
}
