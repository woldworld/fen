/// 智能体动作统计源（周报用）—— 离线、隐私不出本机。
///
/// 数据来自 `agent_actions` 审计表（每一次分身动作都会落一行：设备操作、
/// 工具创造/设置变更、社交发送、主动建议、审查拦截……）。本文件只做
/// **结构化聚合**，不读正文、不送模型：周报回答的是主人最朴素的疑问
/// ——「这周它到底替我做了些什么？」。
///
/// 设计对齐 [chat_stats_source.dart]：抽象源 + 默认 SQLite 实现（注入式，
/// 便于桩替换的单测），失败一律返回空统计**绝不抛**（报表是增益，不能让
/// 它拖垮晨间问候或页面加载）。
///
/// 诚实边界：`agent_actions` 是**审计**而非全量埋点 —— 只有走工具/社交/
/// 设备通道的动作会留痕；分身纯聊天不产生行。故周报口径写「动作次数」，
/// 不写「干的活」。
library;

import 'app_logger.dart';
import 'db_helper.dart';

/// 动作类别（周报分组口径）。
///
/// ★ 分类是**展示层派生值**：由 `action_type` 前缀/枚举映射而来，不落库
///   （R8：派生值不落库）。新增 `action_type` 时若无匹配前缀，落 [other]，
///   不会丢数据。
enum AgentActionCategory {
  tools, // 工具与设置：create_tool / change_settings
  device, // 手机操作：device_*
  social, // 社交动作：social_send / proactive_send / manual_send / world_reply* / mass_stimulus / gift / rep
  suggestion, // 主动建议：proactive_suggestion
  review, // 审查与拦截：plugin_denied / policy_error
  other, // 其他（未来新增类型的安全兜底）
}

/// 一段窗口内的分身动作统计。
class AgentActionStats {
  final int total; // 动作总数
  final int activeDays; // 跨了几天
  final int lastActionMs; // 末次动作时间戳
  final Map<AgentActionCategory, int> byCategory; // 仅含计数 > 0 的类别

  const AgentActionStats({
    this.total = 0,
    this.activeDays = 0,
    this.lastActionMs = 0,
    this.byCategory = const {},
  });

  bool get isEmpty => total == 0;

  /// 把 `agent_actions.action_type` 映射到展示类别（纯函数，可单测）。
  static AgentActionCategory categorize(String actionType) {
    final t = actionType.trim();
    if (t.startsWith('device_')) return AgentActionCategory.device;
    switch (t) {
      case 'create_tool':
      case 'change_settings':
        return AgentActionCategory.tools;
      case 'social_send':
      case 'proactive_send':
      case 'manual_send':
      case 'world_reply':
      case 'world_reply_manual':
      case 'mass_stimulus':
      case 'gift':
      case 'rep':
        return AgentActionCategory.social;
      case 'proactive_suggestion':
        return AgentActionCategory.suggestion;
      case 'plugin_denied':
      case 'policy_error':
        return AgentActionCategory.review;
      default:
        return AgentActionCategory.other;
    }
  }
}

/// 统计源的抽象（注入式，便于测试用桩替换）。
abstract class AgentReportSource {
  Future<AgentActionStats> aggregateSince(int sinceMs);
}

/// 默认实现：直接查 SQLite `agent_actions`。
class SqliteAgentReportSource implements AgentReportSource {
  @override
  Future<AgentActionStats> aggregateSince(int sinceMs) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'agent_actions',
        columns: ['action_type', 'created_at'],
        where: 'created_at >= ?',
        whereArgs: [sinceMs],
      );
      if (rows.isEmpty) return const AgentActionStats();

      final byCat = <AgentActionCategory, int>{};
      final days = <String>{};
      var last = 0;

      for (final r in rows) {
        final type = (r['action_type'] as String?) ?? '';
        final cat = AgentActionStats.categorize(type);
        byCat[cat] = (byCat[cat] ?? 0) + 1;

        final ts = (r['created_at'] as int?) ?? 0;
        if (ts > last) last = ts;
        if (ts > 0) {
          final d = DateTime.fromMillisecondsSinceEpoch(ts);
          days.add('${d.year}-${d.month}-${d.day}');
        }
      }

      return AgentActionStats(
        total: rows.length,
        activeDays: days.length,
        lastActionMs: last,
        byCategory: byCat,
      );
    } catch (e) {
      AppLogger.w('agentReport', e);
      return const AgentActionStats();
    }
  }
}
