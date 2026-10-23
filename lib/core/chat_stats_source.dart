/// 对话历史统计源（晨间三日回顾用）—— 离线、隐私不出本机。
///
/// 数据来自 [sqlite_session_store] 落库的 `session_events` 表（DB v19，append-only，
/// 喂给模型的多轮轨迹）。我们只做**结构化聚合**，不把对话内容送任何模型：
/// 统计会话数 / 轮数 / 活跃天数 / 末次时间 / 高频主题词（主题词来自模型回执里
/// 已落库的 `topic` / `keywords` 字段，本就是元数据，不含正文）。
library;

import 'dart:convert';

import 'app_logger.dart';
import 'db_helper.dart';

/// 一段窗口内的对话统计。
class ChatStats {
  final int sessions; // 涉及几个会话线程
  final int turns; // 总轮数（事件条数）
  final int activeDays; // 跨了几天
  final int lastTurnMs; // 末次交互时间戳
  final List<String> topTopics; // 高频主题（去重、按频次取前 N）

  const ChatStats({
    this.sessions = 0,
    this.turns = 0,
    this.activeDays = 0,
    this.lastTurnMs = 0,
    this.topTopics = const [],
  });

  bool get isEmpty => turns == 0;
}

/// 统计源的抽象（注入式，便于测试用桩替换）。
abstract class ChatStatsSource {
  Future<ChatStats> aggregateSince(int sinceMs);
}

/// 默认实现：直接查 SQLite `session_events`。
class SqliteChatStatsSource implements ChatStatsSource {
  @override
  Future<ChatStats> aggregateSince(int sinceMs) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'session_events',
        columns: ['session_id', 'ts', 'data'],
        // ★ 0.70.0：排除软删行（主人删掉的对话不再计入统计，与画像同口径）。
        where: 'ts >= ? AND deleted_at IS NULL',
        whereArgs: [sinceMs],
      );
      if (rows.isEmpty) return const ChatStats();

      final sessions = <String>{};
      final days = <String>{};
      var last = 0;
      final topicCounts = <String, int>{};

      for (final r in rows) {
        final sid = (r['session_id'] as String?) ?? '';
        if (sid.isNotEmpty) sessions.add(sid);

        final ts = (r['ts'] as int?) ?? 0;
        if (ts > last) last = ts;
        if (ts > 0) {
          final d = DateTime.fromMillisecondsSinceEpoch(ts);
          days.add('${d.year}-${d.month}-${d.day}');
        }

        final data = _parseData(r['data']);
        final topic = (data['topic'] as String?)?.trim();
        if (topic != null &&
            topic.isNotEmpty &&
            topic != '未分类' &&
            topic != '日常交流') {
          topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
        }
        final kw = (data['keywords'] as String?)?.trim();
        if (kw != null && kw.isNotEmpty) {
          for (final k in kw.split(RegExp(r'[，,、\s]+'))) {
            final t = k.trim();
            if (t.isNotEmpty) topicCounts[t] = (topicCounts[t] ?? 0) + 1;
          }
        }
      }

      final ranked = topicCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topTopics = ranked.take(5).map((e) => e.key).toList();

      return ChatStats(
        sessions: sessions.length,
        turns: rows.length,
        activeDays: days.length,
        lastTurnMs: last,
        topTopics: topTopics,
      );
    } catch (e) {
      AppLogger.w('chatStats', e);
      return const ChatStats();
    }
  }

  Map<String, dynamic> _parseData(Object? raw) {
    if (raw == null) return const {};
    try {
      final decoded = (raw is String) ? jsonDecode(raw) : raw;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return const {};
  }
}
