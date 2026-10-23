import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'trial_gateway.dart';

/// [TrialStore] 的 SQLite 实现（迁移版本 29，见 `DBHelper._migrateV29`）。
///
/// ⚠️ **这个文件的存在本身就是一条合规要求**：PRD §9.1 把「额度极小 + 限用途」
/// 当作代调风险的**缓释措施**，而缓释措施要成立，额度就必须**落库**。
/// 改造前只有 `SocialBudget`（纯内存计数，App 重启即归零）——
/// 那样"每天 20 次"可以靠重启刷穿，缓释措施形同虚设。
///
/// 两表各管一件事，且**主键即不变式**：
/// - `trial_quotas` PK `(agent_id, purpose)`：一个身份一个用途只有一份额度，
///   重复发放是 UPDATE 而不是 INSERT（不会叠加出双倍敞口）。
/// - `trial_usage` PK `call_id`：同一次调用只落一条，**重复记账不会把额度扣两遍**。
class DbTrialStore implements TrialStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> upsertQuota(TrialQuota q) async {
    final db = await _db;
    // 不用 ON CONFLICT（Android 10 自带 SQLite 3.22 不支持）；先查再插/改。
    final existing = await db.query('trial_quotas',
        where: 'agent_id = ? AND purpose = ?',
        whereArgs: [q.agentId, q.purpose],
        limit: 1);
    final row = <String, Object?>{
      'agent_id': q.agentId,
      'purpose': q.purpose,
      'granted_turns': q.grantedTurns,
      'used_turns': q.usedTurns,
      'budget_cents': q.budgetCents,
      'spent_cents': q.spentCents,
      'granted_at': q.grantedAtMs,
      'expires_at': q.expiresAtMs,
      'revoked_at': q.revokedAtMs,
    };
    if (existing.isEmpty) {
      await db.insert('trial_quotas', row);
    } else {
      await db.update('trial_quotas', row,
          where: 'agent_id = ? AND purpose = ?', whereArgs: [q.agentId, q.purpose]);
    }
    DBHelper.dataRevision++;
  }

  @override
  Future<TrialQuota?> quota(String agentId, String purpose) async {
    final db = await _db;
    final rows = await db.query('trial_quotas',
        where: 'agent_id = ? AND purpose = ?',
        whereArgs: [agentId, purpose],
        limit: 1);
    return rows.isEmpty ? null : TrialQuota.fromMap(rows.first);
  }

  @override
  Future<List<TrialQuota>> quotasOf(String agentId) async {
    final db = await _db;
    final rows = await db.query('trial_quotas',
        where: 'agent_id = ?', whereArgs: [agentId], orderBy: 'granted_at DESC');
    return rows.map(TrialQuota.fromMap).toList();
  }

  @override
  Future<void> addUsage(UsageLedgerEntry e) async {
    final db = await _db;
    final existing = await db.query('trial_usage',
        where: 'call_id = ?', whereArgs: [e.callId], limit: 1);
    if (existing.isEmpty) {
      await db.insert('trial_usage', {
        'call_id': e.callId,
        'agent_id': e.agentId,
        'purpose': e.purpose,
        'provider': e.provider,
        'model': e.model,
        'prompt_tokens': e.promptTokens,
        'completion_tokens': e.completionTokens,
        'cost_cents': e.costCents,
        'at_ms': e.atMs,
      });
    }
    DBHelper.dataRevision++;
  }

  @override
  Future<UsageLedgerEntry?> usage(String callId) async {
    final db = await _db;
    final rows = await db.query('trial_usage',
        where: 'call_id = ?', whereArgs: [callId], limit: 1);
    return rows.isEmpty ? null : UsageLedgerEntry.fromMap(rows.first);
  }

  @override
  Future<List<UsageLedgerEntry>> usageOf(String agentId, {int? sinceMs}) async {
    final db = await _db;
    final rows = sinceMs == null
        ? await db.query('trial_usage',
            where: 'agent_id = ?', whereArgs: [agentId], orderBy: 'at_ms DESC')
        : await db.query('trial_usage',
            where: 'agent_id = ? AND at_ms >= ?',
            whereArgs: [agentId, sinceMs],
            orderBy: 'at_ms DESC');
    return rows.map(UsageLedgerEntry.fromMap).toList();
  }
}
