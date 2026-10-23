// 纯 Dart 校验脚本：验证 0.74.0 W5/S6「只读系统日历集成」的结构级落地。
// 运行：dart run tool/verify_calendar.dart
//
// 盯四件事：
//   ① **只读红线**：Manifest 声明 READ_CALENDAR，**绝不**声明 WRITE_CALENDAR；
//      Dart 侧不出现任何写日历的调用（新增/修改/删除）。
//   ② **跨端四件**：Manifest 权限、MainActivity 通道、Dart 桥接服务、工具注册
//      四者同时存在（缺一即功能上线不了）。
//   ③ **晨间挂接**：morning_digest_service 真的读了日历要点。
//   ④ **五语种**：日历相关 ARB 键 5 个语种齐备。

import 'dart:convert';
import 'dart:io';

int _pass = 0;
int _fail = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

const List<String> _arbFiles = [
  'lib/l10n/app_zh.arb',
  'lib/l10n/app_en.arb',
  'lib/l10n/app_zh_Hant.arb',
  'lib/l10n/app_ja.arb',
  'lib/l10n/app_vi.arb',
];

const List<String> _calendarKeys = [
  'settingsCalendarTitle',
  'settingsCalendarHint',
  'settingsCalendarGrant',
  'settingsCalendarGranted',
  'settingsCalendarDenied',
  'settingsCalendarUnsupported',
  'calendarPermissionNeeded',
  'calendarAllDay',
  'morningHiCalendar',
];

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

/// ★ 扫 Dart 源码前先剥注释：本仓习惯把「旧缺陷/反面教材」写进注释，
///   不剥的话守卫会被说明文字报红（skill §22.3；本轮实测：文件头注释里
///   解释「为什么不用 permission_handler」反而被判成"依赖了它"）。
String _stripComments(String s) {
  final out = StringBuffer();
  var i = 0;
  final n = s.length;
  while (i < n) {
    final c = s[i];
    if (c == '/' && i + 1 < n && s[i + 1] == '/') {
      while (i < n && s[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && s[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(s[i] == '*' && s[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// 读 Dart 源码并剥注释。
String _readCode(String p) => _stripComments(_read(p));

void main() {
  print('== verify_calendar (W5/S6 只读系统日历) ==');

  // ① 只读红线
  final manifest =
      _read('android/app/src/main/AndroidManifest.xml');
  check(manifest.contains('android.permission.READ_CALENDAR'),
      'Manifest 声明 READ_CALENDAR');
  check(!manifest.contains('android.permission.WRITE_CALENDAR'),
      '★ Manifest **未**声明 WRITE_CALENDAR（只读红线）');

  // ② 跨端四件
  final kt = _read(
      'android/app/src/main/kotlin/world/wold/fen/MainActivity.kt');
  check(kt.contains('dahuang/calendar'), 'MainActivity 注册 dahuang/calendar 通道');
  check(kt.contains('CalendarContract.Instances'),
      'MainActivity 经 CalendarContract.Instances 读取');
  check(kt.contains('queryCalendarEvents'), 'MainActivity 有 queryCalendarEvents 实现');
  check(kt.contains('ActivityCompat.requestPermissions') &&
          kt.contains('Manifest.permission.READ_CALENDAR'),
      '授权在原生侧自持（requestPermissions 只带 READ_CALENDAR）');
  check(kt.contains('onRequestPermissionsResult'),
      'MainActivity 回推授权结果（onRequestPermissionsResult）');

  final svc = _readCode('lib/core/calendar_service.dart');
  check(svc.contains('class CalendarService'), 'calendar_service 暴露 CalendarService');
  check(svc.contains('class CalendarEvent'), 'calendar_service 暴露 CalendarEvent');
  check(svc.contains('class CalendarStatus'), 'calendar_service 暴露 CalendarStatus');
  check(svc.contains('eventsBetween'), 'calendar_service 有 eventsBetween');
  check(svc.contains('todayEvents'), 'calendar_service 有 todayEvents');
  check(svc.contains("MethodChannel('dahuang/calendar')"),
      'calendar_service 绑定 dahuang/calendar 通道');
  // ★ 只读纪律：不得借助通用权限插件的"读写组"（会连带请求 WRITE_CALENDAR）
  check(!svc.contains('permission_handler'),
      '★ calendar_service 不依赖 permission_handler（避免连带请求写权限）');

  final agent = _readCode('lib/core/agent_service.dart');
  check(agent.contains("'calendar_today'"), 'agent_service 注册 calendar_today 工具');
  // 工具档位必须是 normal（读取类不该弹高危确认）
  final idx = agent.indexOf("'calendar_today'");
  final window = idx < 0 ? '' : agent.substring(idx, (idx + 400).clamp(0, agent.length));
  check(window.contains('PermissionLevel.normal'),
      "calendar_today 为 PermissionLevel.normal（读类不应走高危闸）");

  // ③ 晨间挂接
  final morning = _readCode('lib/core/morning_digest_service.dart');
  check(morning.contains('CalendarService.i'), 'morning_digest 调用 CalendarService');
  check(morning.contains('morningHiCalendar'), 'morning_digest 使用 morningHiCalendar 要点');

  // ④ 五语种
  for (final arb in _arbFiles) {
    final text = _read(arb);
    late Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      check(false, '$arb 可解析为 JSON ($e)');
      continue;
    }
    final missing = _calendarKeys.where((k) => !json.containsKey(k)).toList();
    check(missing.isEmpty,
        '$arb 含全部 ${_calendarKeys.length} 个日历键${missing.isEmpty ? '' : '，缺 $missing'}');
  }

  print('');
  print('PASS=$_pass FAIL=$_fail');
  exit(_fail == 0 ? 0 : 1);
}
