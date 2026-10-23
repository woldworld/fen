/// Hub 上行 outbox：**把"要公示的事"先落本地，Hub 不可达时不丢**。
///
/// ---------------------------------------------------------------------------
/// 为什么必须有这一层（而不是"调用失败就算了"）
/// ---------------------------------------------------------------------------
/// 本 App 是**本地优先**的：离线是常态，不是异常。如果上行只做一次性的
/// best-effort 调用、失败就放弃，那么离线期间产生的每一片叶子都会**永久**
/// 缺席公开日志 —— 而 §16 的承诺是"你不必相信我，你可以验我"。
/// 缺了数据就**没有可验之物**，那句承诺就退化成一句口号。
/// 所以本层不是可选优化，是那条承诺得以成立的前提。
///
/// ---------------------------------------------------------------------------
/// ⚠️ 入队的是**已签名的域对象**，不是信封 —— 这一条不能妥协
/// ---------------------------------------------------------------------------
/// 协议包 `envelope.TS_WINDOW_SECONDS = 300`（±5 分钟防重放）。信封一旦落盘，
/// 几分钟后重放必被 Hub 的 `bad_timestamp` 拒掉 —— 于是"离线攒了一天"这件事
/// 会变成"攒了一堆永远发不出去的废信封"。
/// 因此：**信封每次发送时现构**，队列里只存不随时间失效的那部分（域对象本身）。
///
/// 幂等由 Hub 侧兜住（`logAppendOnce` 按叶子哈希去重、贡献按幂等键去重、
/// 技能按版本去重、角色按叶子哈希去重），所以**重放是安全的**，
/// 不需要在客户端再做一层"已发送"标记 —— 那反而会引入"标记成功但实际没到"的假象。
library;

/// 队列里的一条待上行记录。
///
/// 刻意**不含**"已发送成功"之类的标志位：成功即从队列删除。
/// 一个可以长期处于"既在队列里、又已经发出去"的状态，只会让人分不清
/// 到底哪份才是真的。
class HubOutboxItem {
  /// 自增主键；`0` 表示尚未入库。
  final int id;

  /// 目标端点（如 `/api/log/append`）。队列不解析它，只回传给发送方。
  final String endpoint;

  /// 已签名的域对象（JSON 字符串）—— **不含信封**，理由见文件头。
  final String payloadJson;

  /// 已失败次数（成功即删除，故只增不减）。
  final int attempts;

  /// 下次允许尝试的时刻（毫秒）。退避由 [HubOutboxPolicy.retryDelayMs] 给出。
  final int nextAttemptAtMs;

  /// 入队时刻（毫秒）。
  final int createdAtMs;

  /// 最近一次失败原因（人可读，用于排错；不参与任何判定）。
  final String lastError;

  const HubOutboxItem({
    this.id = 0,
    required this.endpoint,
    required this.payloadJson,
    this.attempts = 0,
    required this.nextAttemptAtMs,
    required this.createdAtMs,
    this.lastError = '',
  });

  bool isDueAt(int nowMs) => nextAttemptAtMs <= nowMs;

  Map<String, Object?> toMap() => {
        'id': id,
        'endpoint': endpoint,
        'payload': payloadJson,
        'attempts': attempts,
        'next_at_ms': nextAttemptAtMs,
        'created_at_ms': createdAtMs,
        'last_error': lastError,
      };

  static HubOutboxItem fromMap(Map<String, Object?> m) => HubOutboxItem(
        id: (m['id'] as num?)?.toInt() ?? 0,
        endpoint: (m['endpoint'] as String?) ?? '',
        payloadJson: (m['payload'] as String?) ?? '',
        attempts: (m['attempts'] as num?)?.toInt() ?? 0,
        nextAttemptAtMs: (m['next_at_ms'] as num?)?.toInt() ?? 0,
        createdAtMs: (m['created_at_ms'] as num?)?.toInt() ?? 0,
        lastError: (m['last_error'] as String?) ?? '',
      );
}

/// 队列存储抽象。内存实现供纯逻辑单测；生产用 SQLite 实现（`hub_outbox_store_db.dart`）。
abstract class HubOutboxStore {
  /// 入队，返回新行主键。
  Future<int> enqueue(HubOutboxItem item);

  /// 取**到期**的待发条目（按入队顺序，最旧的先发）。
  Future<List<HubOutboxItem>> due({required int nowMs, int limit});

  /// 记一次失败：`attempts + 1`，并把 `next_at_ms` 推到退避之后。
  Future<void> markAttempt(int id, String error, int nextAttemptAtMs);

  /// 发送成功（或判定为永久拒绝）后删除。
  Future<void> remove(int id);

  Future<int> count();

  Future<void> clear();
}

/// 内存实现：只用于单测与"未接线"阶段。
class MemoryHubOutboxStore implements HubOutboxStore {
  final List<HubOutboxItem> _rows = [];
  int _seq = 0;

  @override
  Future<int> enqueue(HubOutboxItem item) async {
    final id = ++_seq;
    _rows.add(HubOutboxItem(
      id: id,
      endpoint: item.endpoint,
      payloadJson: item.payloadJson,
      attempts: item.attempts,
      nextAttemptAtMs: item.nextAttemptAtMs,
      createdAtMs: item.createdAtMs,
      lastError: item.lastError,
    ));
    return id;
  }

  @override
  Future<List<HubOutboxItem>> due(
      {required int nowMs, int limit = 50}) async {
    final out = _rows.where((e) => e.isDueAt(nowMs)).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return out.length <= limit ? out : out.sublist(0, limit);
  }

  @override
  Future<void> markAttempt(int id, String error, int nextAttemptAtMs) async {
    for (var i = 0; i < _rows.length; i++) {
      if (_rows[i].id != id) continue;
      final old = _rows[i];
      _rows[i] = HubOutboxItem(
        id: old.id,
        endpoint: old.endpoint,
        payloadJson: old.payloadJson,
        attempts: old.attempts + 1,
        nextAttemptAtMs: nextAttemptAtMs,
        createdAtMs: old.createdAtMs,
        lastError: error,
      );
      return;
    }
  }

  @override
  Future<void> remove(int id) async => _rows.removeWhere((e) => e.id == id);

  @override
  Future<int> count() async => _rows.length;

  @override
  Future<void> clear() async => _rows.clear();
}

/// 队列的**纯策略**：退避与容量。单独成类是为了能被离线脚本直接断言，
/// 不需要真库或真网络。
abstract final class HubOutboxPolicy {
  /// 单次重放最多取多少条 —— 避免一次启动把 Hub 打爆（Hub 侧还有 60 次/分限流）。
  static const int drainBatch = 50;

  /// 队列**周期性重放**的间隔。
  ///
  /// 为什么需要这个常量（而不是让宿主自己拍一个数）：在没有它之前，
  /// `flushOutbox` **全项目零调用方** —— 队列只进不出，攒到 [maxQueued] 就开始
  /// 丢最旧的，而"丢"还是设计好的行为。整条上行链路的可靠性因此只剩"运气"。
  /// 把间隔定在这里，是为了让"多久补一次"成为一个**可被断言的口径**，
  /// 而不是散在某个 UI 生命周期回调里的一行魔法数。
  ///
  /// 取值理由：上行的都是"已经签好名的记录"，晚 1 分钟公示不影响语义；
  /// 而 Hub 侧限流 60 次/分、单次最多取 [drainBatch] 条，60 秒一轮
  /// 既不会把 Hub 打爆，也不会让离线攒下的一批等太久。
  static const Duration drainInterval = Duration(seconds: 60);

  /// 队列容量上限。超出则丢**最旧**的一条并留痕。
  ///
  /// 为什么宁可丢也不无限涨：一张永不封顶的表最终会撑爆设备，
  /// 而"设备坏了"比"少几条历史记录"严重得多。丢掉的部分会留埋点，不静默。
  static const int maxQueued = 2000;

  /// 首次重试等待（毫秒）。
  static const int baseDelayMs = 5000;

  /// 退避上限（1 小时）。
  ///
  /// ⚠️ 刻意**不设"尝试次数上限"**：容量上限已经兜住了表的增长，
  /// 而"试够 N 次就丢"会**真的丢数据** —— 离线一整天的用户回来时，
  /// 那批记录会被自己的重试次数判死。宁可等得久，不可丢。
  static const int maxDelayMs = 3600000;

  /// 第 [attempts] 次失败后的等待时长（指数退避，封顶 [maxDelayMs]）。
  ///
  /// `attempts <= 0` → 0（首次入队立即可发）。
  static int retryDelayMs(int attempts) {
    if (attempts <= 0) return 0;
    var ms = baseDelayMs;
    for (var i = 1; i < attempts && ms < maxDelayMs; i++) {
      ms *= 2;
    }
    return ms > maxDelayMs ? maxDelayMs : ms;
  }
}
