import '../session/session_event.dart';
import '../session/session_store.dart';

/// 摘要折叠器（M4）：轨迹超过阈值时，把较旧的一段压缩成一条 summary 事件
/// 追加回存储（append-only——旧事件保留在库里，但 selectRecent 会把最后一个
/// summary 之前的内容折叠掉，等效于"记忆被压缩"）。
///
/// [summarize] 由宿主/运行时注入：通常调一次**无工具**的辅助 Agent
///（绝不能用带工具的主 Agent——摘要过程绝不能触发工具调用）。
class Compactor {
  /// 轨迹超过 [threshold] 条时触发折叠
  final int threshold;

  /// 折叠时保留最近 [keepRecent] 条原文
  final int keepRecent;

  /// 摘要回调：入参为待压缩轨迹的转写文本；返回 null 表示放弃本次折叠
  ///（如辅助 Agent 不可用），静默跳过、绝不阻断主流程。
  final Future<String?> Function(String transcript) summarize;

  const Compactor({
    this.threshold = 60,
    this.keepRecent = 20,
    required this.summarize,
  });

  /// 需要且成功折叠返回 true；不需要/放弃返回 false。
  Future<bool> compactIfNeeded(SessionStore store, String sessionId) async {
    final events = await store.replay(sessionId);
    if (events.length <= threshold) return false;
    // 已有摘要的历史不再重复压缩：只压最后一个 summary 之后的部分
    var lastSummaryIdx = -1;
    for (var i = 0; i < events.length; i++) {
      if (events[i].type == 'summary') lastSummaryIdx = i;
    }
    final covered = lastSummaryIdx + 1; // summary 及其之前都已覆盖
    final alive = events.sublist(covered);
    if (alive.length <= threshold) return false;

    final toCompress = alive.sublist(0, alive.length - keepRecent);
    if (toCompress.isEmpty) return false;

    final transcript = toCompress
        .map((e) =>
            '[${e.type}] ${e.data['text']?.toString() ?? ''}')
        .join('\n');
    final summary = await summarize(transcript);
    if (summary == null || summary.isEmpty) return false;

    await store.append(
      sessionId,
      SessionEvent(
        type: 'summary',
        data: {
          'text': summary,
          'covered_events': toCompress.length,
          'covered_until': toCompress.last.ts.toIso8601String(),
        },
      ),
    );
    // 关键：把保留的最近原文**重新追加**到 summary 之后——
    // selectRecent 折叠"最后一个 summary 之前"的一切，
    // 摘要在末尾而保留原文在它之前的话会被误折叠。重追后视图即为
    // [摘要, 最近原文...]，与压缩语义完全一致（旧原文仍在库里，append-only）。
    for (final kept in alive.sublist(alive.length - keepRecent)) {
      await store.append(
        sessionId,
        SessionEvent(type: kept.type, data: kept.data, ts: kept.ts),
      );
    }
    return true;
  }
}
