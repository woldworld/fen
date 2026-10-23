/// 邮箱工具 · 落库（迁移版本 **37**，见 `DBHelper._migrateV37`）
///
/// 与其他 `*_store_db.dart` 同形：`mail_types.dart` 保持零平台依赖，
/// 由本文件承担 SQLite 细节。这样工具层可以在纯 Dart 环境被驱动测试。
///
/// ★ 本文件**只碰三张表**，且这三张表里**没有**任何凭据列
/// （口令在 `mail_credential_store.dart`）。
library;

import 'package:sqflite/sqflite.dart';

import '../db_helper.dart';
import 'mail_types.dart';

class MailStoreDb {
  static Future<Database> get _db => DBHelper.db;

  // ------------------------------------------------------------------
  // 账号
  // ------------------------------------------------------------------

  /// 新增或更新账号（按 id）。刻意不用 `ON CONFLICT DO UPDATE`
  /// —— 老 Android 自带 SQLite 3.22 不支持（同 `DbRoomRoleStore` 的注释）。
  static Future<void> upsertAccount(MailAccount a) async {
    final db = await _db;
    final exists = await db.query('mail_accounts',
        columns: ['id'], where: 'id = ?', whereArgs: [a.id], limit: 1);
    if (exists.isEmpty) {
      await db.insert('mail_accounts', {
        ...a.toRow(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await db.update('mail_accounts', a.toRow(),
          where: 'id = ?', whereArgs: [a.id]);
    }
    DBHelper.dataRevision++;
  }

  static Future<List<MailAccount>> accounts() async {
    final db = await _db;
    final rows =
        await db.query('mail_accounts', orderBy: 'created_at ASC');
    return rows.map(MailAccount.fromRow).toList();
  }

  static Future<MailAccount?> account(String id) async {
    final db = await _db;
    final rows = await db
        .query('mail_accounts', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : MailAccount.fromRow(rows.first);
  }

  /// 解绑账号：**连已读游标一起删**（账号没了，游标就没有意义）。
  /// ★ 调用方**必须**同时 `MailCredentialStore.forget(id)`。
  static Future<void> deleteAccount(String id) async {
    final db = await _db;
    await db.delete('mail_accounts', where: 'id = ?', whereArgs: [id]);
    await db.delete('mail_seen', where: 'account_id = ?', whereArgs: [id]);
    DBHelper.dataRevision++;
  }

  /// 记录一次连接结果（成功清空错误，失败留下**可读原因**）。
  static Future<void> markResult(String id,
      {required bool ok, String? error}) async {
    final db = await _db;
    await db.update(
      'mail_accounts',
      {
        if (ok) 'last_ok_at': DateTime.now().millisecondsSinceEpoch,
        'last_error': ok ? null : (error ?? '未知错误'),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ------------------------------------------------------------------
  // 已读游标
  // ------------------------------------------------------------------

  static Future<void> markSeen(String accountId, String uid) async {
    final db = await _db;
    await db.insert(
      'mail_seen',
      {
        'account_id': accountId,
        'uid': uid,
        'seen_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<bool> isSeen(String accountId, String uid) async {
    final db = await _db;
    final rows = await db.query('mail_seen',
        columns: ['uid'],
        where: 'account_id = ? AND uid = ?',
        whereArgs: [accountId, uid],
        limit: 1);
    return rows.isNotEmpty;
  }

  // ------------------------------------------------------------------
  // 出站台账
  // ------------------------------------------------------------------

  /// 台账上限：只保留最近 [keepOutboxMax] 条（新条目写入时顺手裁剪）。
  ///
  /// ★ 0.90.0（专家 #8）：台账此前**只增不减**（每起草一封就多一条），长期使用会
  ///   无限膨胀。正文全文从不落库，历史条目只剩信封摘要，保留意义有限 ⇒ 按条数
  ///   上限滚动裁剪即可。
  static const int keepOutboxMax = 200;

  /// 只保留最近 [keep] 条台账，其余删除（由 [insertDraft] 在写入后调用）。
  static Future<void> pruneOutbox({int keep = keepOutboxMax}) async {
    final db = await _db;
    // 取"第 keep 新"的那条的 id；不足 keep 条时该查询为空 ⇒ 无需裁剪。
    final rows = await db.query('mail_outbox',
        columns: ['id'],
        orderBy: 'id DESC',
        limit: 1,
        offset: keep <= 0 ? 0 : keep - 1);
    if (rows.isEmpty) return;
    final cutoff = (rows.first['id'] as num).toInt();
    await db.delete('mail_outbox', where: 'id < ?', whereArgs: [cutoff]);
  }

  /// 存一条草稿，返回 id。`preview` 由调用方截断（**绝不放正文全文**）。
  static Future<int> insertDraft({
    required String accountId,
    required String toAddrs,
    required String subject,
    required String preview,
  }) async {
    final db = await _db;
    final id = await db.insert('mail_outbox', {
      'account_id': accountId,
      'status': MailOutboxStatus.draft.name,
      'to_addrs': toAddrs,
      'subject': subject,
      'preview': preview,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    DBHelper.dataRevision++;
    // 顺手裁剪：**纯家务**，失败绝不能连累"草稿已存"这个主结果。
    try {
      await pruneOutbox();
    } catch (_) {
      // 裁剪失败静默跳过（下次写入再试）；不影响本次草稿。
    }
    return id;
  }

  static Future<MailOutboxItem?> outboxItem(int id) async {
    final db = await _db;
    final rows =
        await db.query('mail_outbox', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  static Future<void> markSent(int id) async {
    final db = await _db;
    await db.update(
      'mail_outbox',
      {
        'status': MailOutboxStatus.sent.name,
        'sent_at': DateTime.now().millisecondsSinceEpoch,
        'error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> markFailed(int id, String error) async {
    final db = await _db;
    await db.update(
      'mail_outbox',
      {'status': MailOutboxStatus.failed.name, 'error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<MailOutboxItem>> recent({int limit = 20}) async {
    final db = await _db;
    final rows = await db.query('mail_outbox',
        orderBy: 'id DESC', limit: limit <= 0 ? 1 : limit);
    return rows.map(_fromRow).toList();
  }

  static MailOutboxItem _fromRow(Map<String, Object?> r) => MailOutboxItem(
        id: ((r['id'] as num?) ?? 0).toInt(),
        accountId: (r['account_id'] as String?) ?? '',
        status: MailOutboxStatus.parse(r['status'] as String?),
        toAddrs: (r['to_addrs'] as String?) ?? '',
        subject: (r['subject'] as String?) ?? '',
        preview: (r['preview'] as String?) ?? '',
        error: r['error'] as String?,
        createdAt: ((r['created_at'] as num?) ?? 0).toInt(),
        sentAt: (r['sent_at'] as num?)?.toInt(),
      );

  /// 台账预览的截断长度（对外唯一口径）。
  static const int previewMaxChars = 256;

  static String truncatePreview(String body) =>
      body.length <= previewMaxChars ? body : '${body.substring(0, previewMaxChars)}…';
}
