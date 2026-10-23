/// 会客厅「节奏闸」退避策略：**零依赖纯逻辑**。
///
/// 为什么单独成文件：`world_service.dart` 拉进了 `shared_preferences` / `app_logger`
/// ⇒ 它没法被 `dart run tool/verify_*.dart` 直接跑（`dart:ui is not available`）。
/// 而这段判据恰恰是**能离线断言的**（给一个 429 响应体，看它算不算得出该等多久），
/// 所以按本仓惯例（`hub_push_outcome` / `session_handshake` 同款）拆成零依赖文件。
///
/// 背景：服务端 `world.js` 有一道**同房间最小间隔**闸（`ROOM_MIN_INTERVAL_MS`，默认 8 秒），
/// 未到点回 `429 {"error":"room_too_fast","retry_after_ms":N}`。
/// 而客户端此前**从不消费**这个字段，撞闸就"直接放弃并报错" ⇒
/// 两个智能体互答时必然互相挡，主人看到的是"它突然不说话了"。
library;

import 'dart:convert';

class WorldRetryPolicy {
  WorldRetryPolicy._();

  /// 等待上限：服务端给多少就等多少，但不能无限等
  /// （防服务端算出离谱值把 App 挂住；也为将来误配置兜底）。
  static const int maxBackoffMs = 10000;

  /// 从 429 响应体算出"该等多少毫秒再试"；**返回 `0` = 不该重试**。
  ///
  /// 只认 `room_too_fast`（同房间最小间隔 —— 一定是**暂时**的，等一会就能发）。
  /// `member_cap`（本小时额度用尽）等再久也没用 ⇒ 返回 0，让调用方如实报错。
  /// 任何解析失败（非 JSON / 非 Map / 字段缺失 / 非正数）一律 **fail-safe 返回 0**：
  /// 宁可如实报错，也不要"猜一个等待时间"。
  static int backoffMsFrom429(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return 0;
    }
    if (decoded is! Map) return 0;
    if (decoded['error']?.toString() != 'room_too_fast') return 0;
    final raw = decoded['retry_after_ms'];
    final ms = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (ms == null || ms <= 0) return 0;
    return ms > maxBackoffMs ? maxBackoffMs : ms;
  }
}
