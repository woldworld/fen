import 'package:sqflite/sqflite.dart';

import 'attestation_service.dart';
import 'db_helper.dart';

/// [AttestationStore] 的 SQLite 实现（迁移版本 26，见 `DBHelper._migrateV26`）。
///
/// 单独成文件的原因与 `circle_store_db.dart` / `world_bridge_store_db.dart` 相同：
/// `attestation_service.dart` 保持**零平台依赖**，可直接 `dart run` 离线复算判定。
class DbAttestationStore implements AttestationStore {
  Future<Database> get _db => DBHelper.db;

  /// 幂等写入 —— 但**不是无脑覆盖**。
  ///
  /// 记录是**分段推进**的（发起 → 互允 → 结果 → 追认），每次推进都写同一行。
  /// 这里遵守 [shouldAcceptUpsert] 定义的**单向前进**纪律（口径只有那一份）：
  /// 一个只签了"发起"的旧报文被重放时，不得把已互允的记录打回"未同意"。
  ///
  /// 用 `INSERT OR REPLACE` 而不是 `ON CONFLICT ... DO UPDATE`：
  /// 后者要 SQLite 3.24+，而 Android 10 自带 3.22 会直接语法报错
  /// （与 `room_presences` 踩的是同一个坑）。读改写放进事务，
  /// 保证并发两条推进不会各自读到旧值再写回。
  @override
  Future<void> upsert(IntroAttestation a) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query('attestations',
          where: 'id = ?', whereArgs: [a.id], limit: 1);
      final existing =
          rows.isEmpty ? null : IntroAttestation.fromMap(rows.first);
      if (!shouldAcceptUpsert(existing, a)) return; // 只前进不后退
      await txn.insert('attestations', a.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<IntroAttestation?> byId(String id) async {
    final db = await _db;
    final rows =
        await db.query('attestations', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return IntroAttestation.fromMap(rows.first);
  }

  @override
  Future<List<IntroAttestation>> involving(String agentId) async {
    final db = await _db;
    // 我是发起方 或 我是对端 都算"与我有关"。
    // 两个索引 (initiator_id, initiated_at) / (counterparty_id, initiated_at)
    // 分别服务这条 OR 的两侧，避免全表扫描。
    final rows = await db.query('attestations',
        where: 'initiator_id = ? OR counterparty_id = ?',
        whereArgs: [agentId, agentId],
        orderBy: 'initiated_at DESC');
    return rows.map(IntroAttestation.fromMap).toList();
  }
}
