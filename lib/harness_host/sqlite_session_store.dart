import 'dart:convert';

import 'package:pocket_harness/pocket_harness.dart';

import '../core/db_helper.dart';

/// pocket_harness `SessionStore` 的宿主实现（M2）：
/// 落在 SQLite `session_events` 表（DB v19），append-only，自增 id 即游标。
///
/// 游标语义：[replay] 的 `after` 为事件 id（单调递增），返回 id > after 的全部事件。
/// 注意：与 messages 表（UI 聊天记录）职责分离——轨迹是喂给大模型的多轮记忆，
/// UI 是给人看的聊天记录，二者独立落库。
class SqliteSessionStore implements SessionStore {
  /// 单会话单次回放上限（保护上下文；M4 ContextManager 将精细化预算）
  static const int replayLimit = 200;

  @override
  Future<Session> open(String id) async {
    // 惰性：不预加载历史（可能很大），turn 时按需 replay
    return Session(id, const []);
  }

  @override
  Future<void> append(String id, SessionEvent event) async {
    final dbClient = await DBHelper.db;
    await dbClient.insert('session_events', {
      'session_id': id,
      'type': event.type,
      'ts': event.ts.millisecondsSinceEpoch,
      'data': jsonEncode(event.data),
    });
  }

  /// 回放轨迹。
  ///
  /// ★ 0.42.0 修的一个**记忆冻结**缺陷：此前一律 `ORDER BY id ASC LIMIT 200`
  ///   ⇒ 单会话事件数超过 [replayLimit] 后，返回的永远是**最旧的** 200 条，
  ///   最新消息再也进不了模型（症状＝"越聊越傻"，且**静默无报错**；线程 id 只在
  ///   `AgentService.resetAgent()` 轮换，日常不回滚 ⇒ 长会话必然触发）。
  ///   现在：**增量**语义（`after >= 0`，按游标取其后的事件）不变；
  ///   **全量**回放（`after < 0`）改为取**最新** [replayLimit] 条，
  ///   并仍按时间升序返回（下游 `AgentRuntime.buildHistory` 依赖时间顺序）。
  @override
  Future<List<SessionEvent>> replay(String id, {int after = -1}) async {
    final dbClient = await DBHelper.db;
    // ★ 0.70.0：排除软删行 —— 主人"遗忘这段会话"后，轨迹不得再进模型
    //   （画像 / 对话统计两处已同口径过滤）。
    if (after >= 0) {
      final rows = await dbClient.query(
        'session_events',
        where: 'session_id = ? AND id > ? AND deleted_at IS NULL',
        whereArgs: [id, after],
        orderBy: 'id ASC',
        limit: replayLimit,
      );
      return rows.map(_rowToEvent).toList();
    }
    // 全量：先按 id 倒序取最新 N 条，再反转回时间升序。
    final rows = await dbClient.query(
      'session_events',
      where: 'session_id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      orderBy: 'id DESC',
      limit: replayLimit,
    );
    return rows.reversed.map(_rowToEvent).toList();
  }

  @override
  Future<void> close(String id) async {
    // SQLite 无连接级会话状态，无需处理
  }

  /// 读取某会话当前游标（最新事件 id）；空会话返回 -1。
  /// M4 ContextManager 做增量拉取时使用。
  Future<int> cursor(String id) async {
    final dbClient = await DBHelper.db;
    final rows = await dbClient.query('session_events',
        columns: ['id'],
        where: 'session_id = ?',
        orderBy: 'id DESC',
        limit: 1);
    return rows.isEmpty ? -1 : rows.first['id'] as int;
  }

  /// 清空某线程轨迹（AgentService.resetAgent 轮换线程后，旧轨迹保留供回溯；
  /// 如需彻底遗忘，由主人手动清应用数据——轨迹里可能有隐私对话）
  Future<void> deleteThread(String id) async {
    final dbClient = await DBHelper.db;
    await dbClient.delete('session_events', where: 'session_id = ?', whereArgs: [id]);
  }

  SessionEvent _rowToEvent(Map<String, dynamic> row) {
    Map<String, dynamic> data;
    try {
      data = (jsonDecode(row['data'] as String) as Map).cast<String, dynamic>();
    } catch (_) {
      data = {};
    }
    return SessionEvent(
      type: row['type'] as String? ?? 'unknown',
      ts: DateTime.fromMillisecondsSinceEpoch((row['ts'] as int?) ?? 0),
      data: data,
    );
  }
}
