import 'package:sqflite/sqflite.dart';

import 'contribution_ledger.dart';
import 'db_helper.dart';

/// [ContributionStore] 的 SQLite 实现（迁移版本 32，见 `DBHelper._migrateV32`）。
///
/// ⚠️ **为什么贡献记录必须落库**：贡献是**可出示的证据**。
/// 只存内存的话 App 重启即失，于是"我贡献过什么"会静默消失 ——
/// 而 M10 五件套的全部价值就在于这些记录**可复算、可出示、可被第三方验证**。
/// 内存实现（[MemoryContributionStore]）只用于单测与离线复算。
///
/// ---------------------------------------------------------------------------
/// 本类**刻意不提供**的接口（PRD §9.1 红线）
/// ---------------------------------------------------------------------------
/// 没有 `transferRecord` / `burnRecord` / `redeemScore` / `setScore` /
/// `cashOut` —— 一个都没有。理由：
/// - **贡献记录只追加**：历史事实不会被改写，重复上报走幂等（不动既有行）；
/// - **声望分不落库**：它由 [ContributionLedger.tally] 从记录现算（派生值），
///   本类里根本没有"写分数"的入口 —— 没有入口就写不出转账。
///
/// 这三张表的主键即各自的不变式（详见 `_migrateV32` 的文档注释）：
/// - `contribution_records` PK `(kind, subject_pub, ref)`：同一件事只有一条；
/// - `founding_members` PK `subject_pub`：一人一份创始声明；
/// - `price_lock_claims` PK `(scope, subject_pub)`：一作用域一人一份定价权。
class DbContributionStore implements ContributionStore {
  Future<Database> get _db => DBHelper.db;

  // ------------------------------------------------------------------
  // ⑤ 可验证贡献账本（只追加）
  // ------------------------------------------------------------------

  /// 追加一条记录。**幂等**：同键已存在则原样返回，绝不覆盖既有行 ——
  /// 覆盖会让"历史账本"变成"可编辑的账本"，那是可验证性的反面。
  ///
  /// 不用 `ON CONFLICT`（Android 10 自带 SQLite 3.22 不支持）；
  /// 用 `ConflictAlgorithm.ignore` 让"并发下只留第一条"由主键保证。
  @override
  Future<void> addRecord(ContributionRecord r) async {
    final db = await _db;
    final n = await db.insert('contribution_records', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
    if (n != 0) DBHelper.dataRevision++;
  }

  @override
  Future<ContributionRecord?> recordByKey(String key) async {
    // key 的构成见 ContributionRecord.key：`kind|subject|ref`（founding 只有两段）。
    final parts = key.split('|');
    if (parts.length < 2) return null;
    final kind = parts[0];
    final subject = parts[1];
    final ref = parts.length >= 3 ? parts.sublist(2).join('|') : '';
    final db = await _db;
    final rows = await db.query('contribution_records',
        where: 'kind = ? AND subject_pub = ? AND ref = ?',
        whereArgs: [kind, subject, ref],
        limit: 1);
    return rows.isEmpty ? null : ContributionRecord.fromMap(rows.first);
  }

  @override
  Future<List<ContributionRecord>> allRecords() async {
    final db = await _db;
    final rows = await db.query('contribution_records', orderBy: 'at_ms ASC');
    return rows.map(ContributionRecord.fromMap).toList();
  }

  @override
  Future<List<ContributionRecord>> recordsOf(String subjectPub) async {
    final db = await _db;
    final rows = await db.query('contribution_records',
        where: 'subject_pub = ?', whereArgs: [subjectPub], orderBy: 'at_ms ASC');
    return rows.map(ContributionRecord.fromMap).toList();
  }

  // ------------------------------------------------------------------
  // ① 创始成员（一主体一份）
  // ------------------------------------------------------------------

  @override
  Future<void> setFounding(FoundingDeclaration d) async {
    final db = await _db;
    final n = await db.insert('founding_members', d.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
    if (n != 0) DBHelper.dataRevision++;
  }

  @override
  Future<FoundingDeclaration?> founding(String subjectPub) async {
    final db = await _db;
    final rows = await db.query('founding_members',
        where: 'subject_pub = ?', whereArgs: [subjectPub], limit: 1);
    return rows.isEmpty ? null : FoundingDeclaration.fromMap(rows.first);
  }

  // ------------------------------------------------------------------
  // ② 永久价格锁定（一作用域一份）
  // ------------------------------------------------------------------

  @override
  Future<void> setPriceLock(PriceLockClaim c) async {
    final db = await _db;
    // 同 `(scope, subject)` 只有一份：先查再插/改（不用 ON CONFLICT，见类头）。
    final existing = await db.query('price_lock_claims',
        where: 'scope = ? AND subject_pub = ?',
        whereArgs: [c.scope, c.subjectPub],
        limit: 1);
    if (existing.isEmpty) {
      await db.insert('price_lock_claims', c.toMap());
    } else {
      await db.update('price_lock_claims', c.toMap(),
          where: 'scope = ? AND subject_pub = ?',
          whereArgs: [c.scope, c.subjectPub]);
    }
    DBHelper.dataRevision++;
  }

  @override
  Future<List<PriceLockClaim>> priceLocksOf(String subjectPub) async {
    final db = await _db;
    final rows = await db.query('price_lock_claims',
        where: 'subject_pub = ?', whereArgs: [subjectPub],
        orderBy: 'scope ASC');
    return rows.map(PriceLockClaim.fromMap).toList();
  }
}
