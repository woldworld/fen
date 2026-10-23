import '../session/session_event.dart';

/// 上下文预算管理（M4）。
///
/// token 估算起步实现：1 token ≈ 4 字符（中英混合的粗粒度估计，
/// 够做预算裁剪用；精确计数留给未来接 tokenizer）。
///
/// 设计要点：
/// - [selectRecent] **新消息优先**：从最新往回装，直到预算耗尽——
///   替代"limit:50 硬截断"（旧实现 50 条长消息可能爆上下文，500 条短消息又浪费）；
/// - **摘要折叠感知**：列表里出现 `summary` 事件时，它之前的所有事件视为已被
///   摘要覆盖，直接折叠掉（append-only 存储上的"虚拟删除"）；
/// - 最新一条事件永远保留（哪怕单条超预算——最新输入不能丢）。
class ContextManager {
  final int maxChars;

  const ContextManager({this.maxChars = 24000});

  static int estimateChars(SessionEvent e) =>
      e.type.length + (e.data['text']?.toString().length ?? 24);

  /// 从事件流里按预算选出送入模型的历史（返回保持时间顺序）。
  /// [maxChars] 缺省用构造时的预算，可按管道覆盖。
  List<SessionEvent> selectRecent(List<SessionEvent> events, {int? maxChars}) {
    final budget = maxChars ?? this.maxChars;
    if (events.isEmpty) return const [];

    // 摘要折叠：定位最后一个 summary 事件，其之前的事件全部视为已覆盖
    var start = 0;
    for (var i = 0; i < events.length; i++) {
      if (events[i].type == 'summary') start = i;
    }
    final effective = events.sublist(start);

    // 新消息优先装入预算
    final picked = <SessionEvent>[];
    var used = 0;
    for (var i = effective.length - 1; i >= 0; i--) {
      final e = effective[i];
      final cost = estimateChars(e);
      if (picked.isNotEmpty && used + cost > budget) break;
      // 最新一条无条件保留（超预算也不能丢当前输入）
      picked.add(e);
      used += cost;
    }
    return picked.reversed.toList();
  }

  /// 行式内容裁剪（技能库等 prompt 段落的溢出防护）：
  /// 超预算时从尾部整行丢弃（保持行完整，绝不切半个词），并追加省略提示。
  String fitLines(String block, {int? maxChars, String ellipsis = '\n（其余内容已按预算省略）'}) {
    final limit = maxChars ?? this.maxChars;
    if (block.length <= limit) return block;
    final lines = block.split('\n');
    final buf = StringBuffer();
    var used = 0;
    var dropped = false;
    for (final line in lines) {
      final cost = line.length + 1;
      if (used + cost > limit - ellipsis.length && used > 0) {
        dropped = true;
        break;
      }
      buf.writeln(line);
      used += cost;
    }
    return dropped ? '${buf.toString()}$ellipsis' : block;
  }
}
