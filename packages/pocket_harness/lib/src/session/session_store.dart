import 'session_event.dart';

/// 会话存储（append-only，绝不覆盖历史）。
///
/// 宿主对接（M2）：SQLite 实现放宿主侧（messages 表 + 轨迹表），
/// 包内默认只提供 [InMemorySessionStore]（测试用）。
abstract class SessionStore {
  Future<Session> open(String id);

  /// 追加事件。未 open 的 id 抛 [StateError]（fail-closed，不静默建会话）。
  Future<void> append(String id, SessionEvent event);

  /// 增量回放：返回 id 下序号 > after 的全部事件（游标幂等）。
  Future<List<SessionEvent>> replay(String id, {int after = -1});

  Future<void> close(String id);
}

/// 内存实现（测试与本地实验用；事件自带递增序号供游标）。
class InMemorySessionStore implements SessionStore {
  final Map<String, List<SessionEvent>> _events = {};
  final Map<String, int> _seq = {};
  final Map<SessionEvent, int> _eventSeq = {};

  @override
  Future<Session> open(String id) async {
    _events.putIfAbsent(id, () => []);
    _seq.putIfAbsent(id, () => 0);
    return Session(id, List.unmodifiable(_events[id]!));
  }

  @override
  Future<void> append(String id, SessionEvent event) async {
    if (!_events.containsKey(id)) {
      throw StateError('session not opened: $id');
    }
    final next = (_seq[id] ?? 0) + 1;
    _seq[id] = next;
    _eventSeq[event] = next;
    _events[id]!.add(event);
  }

  @override
  Future<List<SessionEvent>> replay(String id, {int after = -1}) async {
    final list = _events[id];
    if (list == null) return const [];
    final out = <SessionEvent>[];
    for (final e in list) {
      if ((_eventSeq[e] ?? 0) > after) out.add(e);
    }
    return out;
  }

  @override
  Future<void> close(String id) async {
    // 内存实现保留事件（会话可重新 open 续聊）；持久实现可做 flush。
  }

  /// 测试辅助：事件序号
  int seqOf(SessionEvent e) => _eventSeq[e] ?? -1;
}
