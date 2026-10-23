import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'skill_registry.dart';

/// [SkillStore] 的 SQLite 实现（迁移版本 28，见 `DBHelper._migrateV28`）。
///
/// 三张表各管一件事，且**各有一条不变式**：
/// - `skill_listings`：主键 `(skill_id, version)` —— 同版本天然只能有一行，
///   "付过钱后被换内容"在存储层就写不进去（判定层 `publishDecision` 再拦一次）。
/// - `skill_revoked`：主键 `(skill_id, version)`，`version` 为空串表示全版本吊销。
/// - `payout_ledger`：主键 `purchase_id` —— 同一笔购买只落一条，幂等由主键保证，
///   **且刻意没有 `level` / `upline` 列**（PRD §9.1 单层红线，见 `skill_registry.dart`）。
class DbSkillStore implements SkillStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> upsertListing(SkillListing l) async {
    final db = await _db;
    // 不用 `ON CONFLICT ... DO UPDATE`（Android 10 自带 SQLite 3.22 不支持）。
    // 上架是低频操作，"先查再插/改"在任何设备上都成立。
    final existing = await db.query('skill_listings',
        where: 'skill_id = ? AND version = ?',
        whereArgs: [l.skillId, l.version],
        limit: 1);
    final row = _listingRow(l);
    if (existing.isEmpty) {
      await db.insert('skill_listings', row);
    } else {
      await db.update('skill_listings', row,
          where: 'skill_id = ? AND version = ?', whereArgs: [l.skillId, l.version]);
    }
    DBHelper.dataRevision++;
  }

  @override
  Future<List<SkillListing>> listingsOf(String skillId) async {
    final db = await _db;
    final rows = await db.query('skill_listings',
        where: 'skill_id = ?', whereArgs: [skillId]);
    final out = rows.map(_listingFromRow).toList();
    out.sort((a, b) => SkillRegistry.compareVersion(b.version, a.version));
    return out;
  }

  @override
  Future<SkillListing?> listing(String skillId, String version) async {
    final db = await _db;
    final rows = await db.query('skill_listings',
        where: 'skill_id = ? AND version = ?',
        whereArgs: [skillId, version],
        limit: 1);
    return rows.isEmpty ? null : _listingFromRow(rows.first);
  }

  @override
  Future<List<SkillListing>> allListings() async {
    final db = await _db;
    final rows = await db.query('skill_listings', orderBy: 'published_at DESC');
    return rows.map(_listingFromRow).toList();
  }

  @override
  Future<void> addRevocation(SkillRevocation r) async {
    final db = await _db;
    final existing = await db.query('skill_revoked',
        where: 'skill_id = ? AND version = ?',
        whereArgs: [r.skillId, r.version],
        limit: 1);
    if (existing.isEmpty) {
      await db.insert('skill_revoked', {
        'skill_id': r.skillId,
        'version': r.version,
        'author_pub': r.authorPub,
        'reason': r.reason,
        'at_ms': r.atMs,
        'sig': r.signatureB64,
      });
    }
    DBHelper.dataRevision++;
  }

  @override
  Future<List<SkillRevocation>> revocations() async {
    final db = await _db;
    final rows = await db.query('skill_revoked', orderBy: 'at_ms DESC');
    return rows
        .map((m) => SkillRevocation(
              skillId: (m['skill_id'] as String?) ?? '',
              version: (m['version'] as String?) ?? '',
              authorPub: (m['author_pub'] as String?) ?? '',
              reason: (m['reason'] as String?) ?? '',
              atMs: (m['at_ms'] as num?)?.toInt() ?? 0,
              signatureB64: (m['sig'] as String?) ?? '',
            ))
        .toList();
  }

  @override
  Future<Set<String>> revokedKeys() async {
    final db = await _db;
    final rows = await db.query('skill_revoked', columns: ['skill_id', 'version']);
    final out = <String>{};
    for (final m in rows) {
      final sid = (m['skill_id'] as String?) ?? '';
      final ver = (m['version'] as String?) ?? '';
      // 与 SkillRegistry.verifyListing 的约定一致：全版本吊销 = `skillId@`。
      out.add(ver.isEmpty ? '$sid@' : '$sid@$ver');
    }
    return out;
  }

  @override
  Future<void> addPayout(PayoutLedgerEntry e) async {
    final db = await _db;
    final existing = await db.query('payout_ledger',
        where: 'purchase_id = ?', whereArgs: [e.purchaseId], limit: 1);
    if (existing.isEmpty) {
      await db.insert('payout_ledger', {
        'purchase_id': e.purchaseId,
        'skill_id': e.skillId,
        'version': e.version,
        'author_pub': e.authorPub,
        'buyer_id': e.buyerId,
        'amount_cents': e.amountCents,
        'author_cents': e.split.authorCents,
        'platform_cents': e.split.platformCents,
        'referrer_cents': e.split.referrerCents,
        'referrer_id': e.referrerId,
        'at_ms': e.atMs,
      });
    }
    DBHelper.dataRevision++;
  }

  @override
  Future<PayoutLedgerEntry?> payout(String purchaseId) async {
    final db = await _db;
    final rows = await db.query('payout_ledger',
        where: 'purchase_id = ?', whereArgs: [purchaseId], limit: 1);
    return rows.isEmpty ? null : _payoutFromRow(rows.first);
  }

  @override
  Future<List<PayoutLedgerEntry>> payoutsOf(String authorPub) async {
    final db = await _db;
    final rows = await db.query('payout_ledger',
        where: 'author_pub = ?', whereArgs: [authorPub], orderBy: 'at_ms DESC');
    return rows.map(_payoutFromRow).toList();
  }

  @override
  Future<List<PayoutLedgerEntry>> allPayouts() async {
    final db = await _db;
    final rows = await db.query('payout_ledger', orderBy: 'at_ms DESC');
    return rows.map(_payoutFromRow).toList();
  }

  // ------------------------------------------------------------------

  Map<String, Object?> _listingRow(SkillListing l) => {
        'skill_id': l.skillId,
        'version': l.version,
        'name': l.name,
        'description': l.description,
        'author_id': l.authorId,
        'author_pub': l.authorPub,
        // capabilities 以 JSON 数组落库（无独立关联表的必要：只读不查）。
        'capabilities': jsonEncode(l.capabilities),
        'risk': l.risk,
        'content_hash': l.contentHash,
        'price_cents': l.pricing.priceCents,
        'currency': l.pricing.currency,
        'published_at': l.publishedAtMs,
        'sig': l.signatureB64,
      };

  SkillListing _listingFromRow(Map<String, Object?> m) => SkillListing(
        skillId: (m['skill_id'] as String?) ?? '',
        version: (m['version'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        authorId: (m['author_id'] as String?) ?? '',
        authorPub: (m['author_pub'] as String?) ?? '',
        capabilities: _decodeCaps(m['capabilities']),
        risk: (m['risk'] as String?) ?? SkillRisk.low,
        contentHash: (m['content_hash'] as String?) ?? '',
        pricing: SkillPricing(
          priceCents: (m['price_cents'] as num?)?.toInt() ?? 0,
          currency: (m['currency'] as String?) ?? 'CNY',
        ),
        publishedAtMs: (m['published_at'] as num?)?.toInt() ?? 0,
        signatureB64: (m['sig'] as String?) ?? '',
      );

  PayoutLedgerEntry _payoutFromRow(Map<String, Object?> m) => PayoutLedgerEntry(
        purchaseId: (m['purchase_id'] as String?) ?? '',
        skillId: (m['skill_id'] as String?) ?? '',
        version: (m['version'] as String?) ?? '',
        authorPub: (m['author_pub'] as String?) ?? '',
        buyerId: (m['buyer_id'] as String?) ?? '',
        amountCents: (m['amount_cents'] as num?)?.toInt() ?? 0,
        split: RevenueSplit(
          authorCents: (m['author_cents'] as num?)?.toInt() ?? 0,
          platformCents: (m['platform_cents'] as num?)?.toInt() ?? 0,
          referrerCents: (m['referrer_cents'] as num?)?.toInt() ?? 0,
        ),
        referrerId: m['referrer_id'] as String?,
        atMs: (m['at_ms'] as num?)?.toInt() ?? 0,
      );

  static List<String> _decodeCaps(Object? raw) {
    if (raw == null) return const [];
    final s = raw.toString();
    if (s.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {/* 坏数据降级为空，不让一行烂数据毒死整个列表 */}
    return const [];
  }
}
