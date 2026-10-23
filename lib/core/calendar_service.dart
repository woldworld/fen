/// 系统日历集成（只读）—— 0.74.0 W5/S6。
///
/// ---------------------------------------------------------------------------
/// 定位
/// ---------------------------------------------------------------------------
/// 晨间问候此前只讲「过去 72 小时做了什么」，缺了**前瞻**的一面：
/// 「今天你要去哪」。本服务只做**只读**读取系统日历当天的日程，供
/// 晨间问候与 `calendar_today` 工具使用。
///
/// ---------------------------------------------------------------------------
/// 设计纪律（对齐 [device_control_service.dart]）
/// ---------------------------------------------------------------------------
/// 1. **能力分级**：非 Android / 通道不存在 / 未授权时，所有调用安全降级为空
///    列表 + 状态标记，**绝不抛异常给用户**；
/// 2. **只读**：只申请 `READ_CALENDAR`（绝不申请写权限），不做任何增删改。
///    ★ 授权**刻意走原生通道自持**（见 `MainActivity.queryCalendarEvents` 与
///    `request` 分支），**不用** `permission_handler` 的通用日历组 —— 后者在本仓
///    锁定的 `permission_handler_platform_interface 4.4.0` 里只剩
///    `calendar`(读写组)/`calendarWriteOnly`/`calendarFullAccess`，
///    **没有"只读"枚举**，用它等于连写权限一起请求，直接违背只读红线；
/// 3. **隐私不出本机**：日历文本只在本机聚合与呈现，不写入任何记忆表，
///    不送任何模型（与 `chat_stats_source` 同款「结构化聚合、零上传」纪律）；
/// 4. **不静默失败**：未授权时由 UI 显式提示并提供授权入口（红线：静默失败）。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'app_logger.dart';

/// 一条日历日程（只读快照）。
class CalendarEvent {
  final String title;
  final int beginMs;
  final int endMs;
  final bool allDay;
  final String calendarName;

  const CalendarEvent({
    required this.title,
    required this.beginMs,
    required this.endMs,
    this.allDay = false,
    this.calendarName = '',
  });

  factory CalendarEvent.fromMap(Map<dynamic, dynamic> m) => CalendarEvent(
        title: (m['title'] ?? '').toString(),
        beginMs: (m['beginMs'] as num?)?.toInt() ?? 0,
        endMs: (m['endMs'] as num?)?.toInt() ?? 0,
        allDay: m['allDay'] == true,
        calendarName: (m['calendarName'] ?? '').toString(),
      );
}

/// 日历可用性（三态解耦：装没装 / 授没授权）。
class CalendarStatus {
  /// 平台通道是否可用（当前安装包是否带日历读取能力）。
  final bool supported;

  /// READ_CALENDAR 是否已授权（= 能不能真的读到）。
  final bool granted;

  const CalendarStatus({required this.supported, required this.granted});

  const CalendarStatus.unavailable()
      : supported = false,
        granted = false;
}

class CalendarService {
  CalendarService._();
  static final CalendarService i = CalendarService._();

  static const MethodChannel _channel = MethodChannel('dahuang/calendar');

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// 当前可用性。任何查询失败都视为「不可用」，绝不抛。
  Future<CalendarStatus> status() async {
    if (!_isAndroid) return const CalendarStatus.unavailable();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('status');
      if (raw == null) return const CalendarStatus.unavailable();
      return CalendarStatus(
        supported: raw['supported'] == true,
        granted: raw['granted'] == true,
      );
    } on MissingPluginException {
      // 未带通道的构建：降级为不可用（不静默：UI 会显示"当前版本不支持"）。
      return const CalendarStatus.unavailable();
    } catch (e) {
      AppLogger.w('calendar.status', e);
      return const CalendarStatus.unavailable();
    }
  }

  /// 请求 READ_CALENDAR 授权；返回是否已授权。非 Android 一律 false。
  Future<bool> requestPermission() async {
    if (!_isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('request');
      return ok == true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      AppLogger.w('calendar.request', e);
      return false;
    }
  }

  /// 读取 [startMs, endMs) 窗口内的日程（含全天事件）。
  ///
  /// 未授权 / 通道缺失 / 查询异常 ⇒ 返回空列表（调用方用 [status] 区分
  /// 「没日程」与「读不到」）。
  Future<List<CalendarEvent>> eventsBetween(int startMs, int endMs) async {
    if (!_isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'listEvents',
        {'startMs': startMs, 'endMs': endMs},
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((m) => CalendarEvent.fromMap(m))
          .where((e) => e.title.trim().isNotEmpty)
          .toList(growable: false);
    } on MissingPluginException {
      // 未带通道的构建：静默降级为空（status.supported 会给出 false）。
      return const [];
    } catch (e) {
      AppLogger.w('calendar.events', e);
      return const [];
    }
  }

  /// 今天的日程（本地日界 00:00 → 次日 00:00）。
  Future<List<CalendarEvent>> todayEvents() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final list = await eventsBetween(
        start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
    // 按开始时间升序（全天事件排在最前）。
    // ★ 0.76.0：末级补 tiebreaker —— Dart `List.sort` **不稳定**，同刻多事件
    //   （allDay 与 beginMs 都相同）此前顺序不定，会让晨间简报 take(3) 每次
    //   取到不同的前三条。按 endMs → title 定序，让展示可复现。
    final sorted = [...list]..sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        final byBegin = a.beginMs.compareTo(b.beginMs);
        if (byBegin != 0) return byBegin;
        final byEnd = a.endMs.compareTo(b.endMs);
        if (byEnd != 0) return byEnd;
        return a.title.compareTo(b.title);
      });
    return sorted;
  }
}
