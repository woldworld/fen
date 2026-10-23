import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'reputation_network.dart';

/// [ReputationStore] 的 SQLite 实现（迁移版本 30，见 `DBHelper._migrateV30`）。
///
/// ⚠️ **为什么背书必须落库**：背书是**信誉资产**。只存内存的话 App 重启即失，
/// 于是"我背书过谁、谁背书过我"这些证据会静默消失 —— 而网络信誉的整个价值
/// 就在于这些证据**可复算、可出示**。内存实现（[MemoryReputationStore]）
/// 只用于单测与离线复算。
///
/// 两表各管一件事，且**主键即不变式**：
/// - `endorsements` PK `(issuer_pub, subject_pub)`：一个人对另一个人
///   **只有一份**当前背书。重复签发是 UPDATE 而非 INSERT ——
///   **不会叠加出第二份背书**（叠加 = 变相放大边权 = 刷分）。
/// - `endorsement_revoked` PK `(issuer_pub, subject_pub)`：吊销也是幂等的，
///   且吊销判定**先于**验签结果（已收回的背书，签名再合法也不采信）。
///
/// 主体用**公钥**而不是 Agent ID：ID 可被重发/换绑，公钥才是身份根
/// （换一次 ID 就能甩掉全部差评的"信誉洗白"，在这里写不进去）。
class DbReputationStore implements ReputationStore {
  Future<Database> get _db => DBHelper.db;

  Future<void> _upsert(
    String table,
    Map<String, Object?> row,
    String issuerPub,
    String subjectPub,
  ) async {
    final db = await _db;
    // 不用 ON CONFLICT（Android 10 自带 SQLite 3.22 不支持）；先查再插/改。
    final existing = await db.query(table,
        where: 'issuer_pub = ? AND subject_pub = ?',
        whereArgs: [issuerPub, subjectPub],
        limit: 1);
    if (existing.isEmpty) {
      await db.insert(table, row);
    } else {
      await db.update(table, row,
          where: 'issuer_pub = ? AND subject_pub = ?',
          whereArgs: [issuerPub, subjectPub]);
    }
    DBHelper.dataRevision++;
  }

  @override
  Future<void> upsertEndorsement(Endorsement e) async =>
      _upsert('endorsements', e.toMap(), e.issuerPub, e.subjectPub);

  @override
  Future<Endorsement?> endorsement(String issuerPub, String subjectPub) async {
    final db = await _db;
    final rows = await db.query('endorsements',
        where: 'issuer_pub = ? AND subject_pub = ?',
        whereArgs: [issuerPub, subjectPub],
        limit: 1);
    return rows.isEmpty ? null : Endorsement.fromMap(rows.first);
  }

  @override
  Future<List<Endorsement>> byIssuer(String issuerPub) async {
    final db = await _db;
    final rows = await db.query('endorsements',
        where: 'issuer_pub = ?', whereArgs: [issuerPub], orderBy: 'issued_at DESC');
    return rows.map(Endorsement.fromMap).toList();
  }

  @override
  Future<List<Endorsement>> forSubject(String subjectPub) async {
    final db = await _db;
    final rows = await db.query('endorsements',
        where: 'subject_pub = ?',
        whereArgs: [subjectPub],
        orderBy: 'issued_at DESC');
    return rows.map(Endorsement.fromMap).toList();
  }

  @override
  Future<List<Endorsement>> all() async {
    final db = await _db;
    final rows = await db.query('endorsements', orderBy: 'issued_at DESC');
    return rows.map(Endorsement.fromMap).toList();
  }

  @override
  Future<void> upsertRevocation(EndorsementRevocation r) async =>
      _upsert('endorsement_revoked', r.toMap(), r.issuerPub, r.subjectPub);

  @override
  Future<EndorsementRevocation?> revocation(
      String issuerPub, String subjectPub) async {
    final db = await _db;
    final rows = await db.query('endorsement_revoked',
        where: 'issuer_pub = ? AND subject_pub = ?',
        whereArgs: [issuerPub, subjectPub],
        limit: 1);
    return rows.isEmpty ? null : EndorsementRevocation.fromMap(rows.first);
  }

  @override
  Future<Set<String>> revokedKeys() async {
    final db = await _db;
    final rows = await db.query('endorsement_revoked',
        columns: ['issuer_pub', 'subject_pub']);
    return rows
        .map((r) => '${r['issuer_pub']}|${r['subject_pub']}')
        .toSet();
  }
}
