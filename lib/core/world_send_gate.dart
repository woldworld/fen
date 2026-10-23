/// 会客厅「发言排队闸」：把"撞上节奏闸 → 事后退避重试一次"升级为
/// **按房间事前排队**（同一房间的发言串行 + 在已知冷却窗口内提前等待）。
///
/// 为什么单独成文件：与 `world_retry_policy.dart` 同一理由 —— 判据要能
/// 离线 `dart run`，不能拉进 `dart:io` / `shared_preferences`。
///
/// 它补的是 `WorldRetryPolicy` **解决不了**的那一半：
///   - `WorldRetryPolicy` 是**事后**：已经撞上 429 了，才算出"等多久再试一次"。
///   - 本闸是**事前**：同一个房间的两条发言不再同时冲闸（本地串行），
///     且已知的冷却窗口（上次成功发送 / 上次 429）在**发出去之前**先等过去。
///
/// ★ 边界（诚实，别把话说满）：服务端的节奏闸是按**整个房间**判的
///   （`room.last_msg_at`，见 `world.js`）——**别台设备**的发言同样会推进它。
///   所以本地预测**只能减少碰撞、不能消灭**。因此 429 兜底**必须保留**：
///   本闸不替代 `WorldRetryPolicy`，而是串在它前面。
///
/// ★ 同房间「两条都要发」的真实形态：托管发言（`agent_service`）与主人在房间页
///   手动发言（`world_screen`）会先后落到同一个 `WorldService().say`；
///   此前第二条会当场撞 429、白跑一次往返再退避重试。
library;

import 'dart:async';

class WorldSendGate {
  /// 注入时钟与"睡眠"（只为离线可断言；生产用默认实现）。
  WorldSendGate({int Function()? clock, Future<void> Function(int ms)? sleep})
      : _clock = clock ?? _wallClock,
        _sleep = sleep ?? _realSleep;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  static Future<void> _realSleep(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  final int Function() _clock;
  final Future<void> Function(int ms) _sleep;

  /// 一次发言**成功后**首猜"该房间多久内不能再发"。
  ///
  /// 对齐服务端默认 `ROOM_MIN_INTERVAL_MS = 8000`（`world.js` 可被环境变量覆盖）。
  /// 刻意**不做自适应学习**：从 429 反推间隔会被别台设备的发言污染（推大），
  /// 宁可少猜 —— 猜小了只是偶尔仍撞一次 429（有兜底），猜大了会让界面白等。
  static const int defaultMinIntervalMs = 8000;

  /// 单次**事前**等待的上界：超过它就不再等，照常发一次、靠 429 兜底。
  /// 与 `WorldRetryPolicy.maxBackoffMs` 同值 —— 再长的等待对"主人点了一次发送"
  /// 来说已经等于界面卡死，不如如实报错。
  static const int maxWaitMs = 10000;

  final Map<String, int> _nextAllowedAt = {};
  final Map<String, Future<void>> _chains = {};

  /// 诊断/测试用：该房间冷却截止时刻（0 = 从未记录过）。
  int nextAllowedAtMs(String roomId) => _nextAllowedAt[roomId] ?? 0;

  /// **纯计算**：距"现在可以再发"还需等多少毫秒（0 = 立刻可发）。
  int waitMsFor(String roomId, int nowMs) {
    final until = _nextAllowedAt[roomId] ?? 0;
    if (until <= nowMs) return 0;
    return until - nowMs;
  }

  /// 事前排队：等到本房间的冷却窗口结束（最多 `maxWaitMs`）；返回实际等待毫秒。
  Future<int> waitTurn(String roomId) async {
    final ms = waitMsFor(roomId, _clock());
    if (ms <= 0) return 0;
    final wait = ms > maxWaitMs ? maxWaitMs : ms;
    await _sleep(wait);
    return wait;
  }

  /// 在**该房间**的串行队列里跑一次发送：同一房间的两次发送不会重叠，
  /// 且会先等过已知的冷却窗口。不同房间互不影响（可并发）。
  ///
  /// 队列是"接力棒"式：后来的先等前一个的 `done`，谁最后完成谁负责清理表项。
  Future<T> run<T>(String roomId, Future<T> Function() action) async {
    final prev = _chains[roomId] ?? Future<void>.value();
    final done = Completer<void>();
    _chains[roomId] = done.future;
    await prev;
    try {
      await waitTurn(roomId);
      return await action();
    } finally {
      // 只为"不卡住后来者"而完成；异常照常向上抛，不吞。
      done.complete();
      if (identical(_chains[roomId], done.future)) {
        _chains.remove(roomId);
      }
    }
  }

  /// 一次发言**成功**后调用：把冷却窗口推到 `now + defaultMinIntervalMs`。
  ///
  /// 依据：服务端在成功时才写 `room.last_msg_at = now`（`world.js`），
  /// 所以"刚发成功"⇒"这个房间 8 秒内谁都发不出"对**默认配置**是成立的事实。
  void noteSent(String roomId) {
    _nextAllowedAt[roomId] = _clock() + defaultMinIntervalMs;
  }

  /// 撞上 `429 {"error":"room_too_fast","retry_after_ms":N}` 后调用：
  /// 按服务端给的毫秒排冷却（**这是权威值**，比本地预测准）。
  /// `N <= 0` 视为无效（不排冷却 —— 不把"等 0 毫秒"当承诺）。
  void noteRoomTooFast(String roomId, int retryAfterMs) {
    if (retryAfterMs <= 0) return;
    final ms = retryAfterMs > maxWaitMs ? maxWaitMs : retryAfterMs;
    _nextAllowedAt[roomId] = _clock() + ms;
  }

  /// 房间被关闭 / 身份切换时清掉该房间的记忆（队列本身不需要清 —— 它是瞬态的）。
  void forget(String roomId) {
    _nextAllowedAt.remove(roomId);
  }
}
