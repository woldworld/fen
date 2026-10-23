// 系统日历只读桥接（0.74.0 W5/S6）验证。
//
// 只测**纯函数**部分：平台通道（Android ContentResolver）无法在单测里跑，
// 由 tool/verify_calendar.dart 做结构级断言、由真机做端到端验收。
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/calendar_service.dart';

void main() {
  group('CalendarEvent.fromMap', () {
    test('完整字段解析', () {
      final e = CalendarEvent.fromMap({
        'title': '开会',
        'beginMs': 1000,
        'endMs': 2000,
        'allDay': true,
        'calendarName': '工作',
      });
      expect(e.title, '开会');
      expect(e.beginMs, 1000);
      expect(e.endMs, 2000);
      expect(e.allDay, isTrue);
      expect(e.calendarName, '工作');
    });

    test('缺字段时安全降级（不抛）', () {
      final e = CalendarEvent.fromMap({});
      expect(e.title, '');
      expect(e.beginMs, 0);
      expect(e.endMs, 0);
      expect(e.allDay, isFalse);
      expect(e.calendarName, '');
    });

    test('allDay 非 true 时视为 false', () {
      expect(CalendarEvent.fromMap({'allDay': 1}).allDay, isFalse);
      expect(CalendarEvent.fromMap({'allDay': true}).allDay, isTrue);
    });
  });

  group('CalendarStatus', () {
    test('unavailable 常量 = 不支持且未授权', () {
      const s = CalendarStatus.unavailable();
      expect(s.supported, isFalse);
      expect(s.granted, isFalse);
    });
  });
}
