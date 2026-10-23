/// 会话事件（append-only 轨迹的最小单元）。
///
/// type 词汇表（宿主与包共用）：
/// - user_message / assistant_message / tool_call / tool_result
/// - system_note（降级、摘要折叠、错误等观测信息）
class SessionEvent {
  final String type;
  final DateTime ts;
  final Map<String, dynamic> data;

  SessionEvent({
    required this.type,
    required this.data,
    DateTime? ts,
  }) : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {'type': type, 'ts': ts.toIso8601String(), 'data': data};

  factory SessionEvent.fromJson(Map<String, dynamic> j) => SessionEvent(
        type: j['type'] as String,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? {},
        ts: DateTime.tryParse(j['ts']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// 会话（Thread）：id + 轨迹由 store 持有，本体只是只读视图。
class Session {
  final String id;
  final List<SessionEvent> events;
  const Session(this.id, this.events);
}
