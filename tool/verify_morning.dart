// 纯 Dart 校验脚本：验证「晨间问候 + 三日回顾」P0 落地（结构级断言）。
// 运行：dart run tool/verify_morning.dart
//
// P0 验收（不依赖运行中的 App / 设备，仅查源码与 ARB 契约）：
//   ① 5 语种 ARB 各含 16 个晨间问候键（含占位符 {count}/{sessions}/{turns}/{days}/{topics}）；
//   ② morning_digest_service.dart 的 localeName 映射覆盖 5 语种；
//   ③ notification_service.dart 含 NotifyKind.morningDigest 与 notifyMorning；
//   ④ main.dart 心跳分支挂接 MorningDigestService.i.maybeEmit；
//   ⑤ chat_stats_source.dart 暴露 ChatStatsSource / SqliteChatStatsSource。

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

const List<String> _morningKeys = [
  'morningGreetingMorning',
  'morningGreetingNoon',
  'morningGreetingEvening',
  'morningGreetingBody',
  'morningHiPending',
  'morningHiSent',
  'morningHiCircle',
  'morningHiTopics',
  'morningHiLongTerm', // P1（0.68.0）：长期画像「长期关注」要点
  'morningEmpty',
  'notifyMorningTitle',
  'notifyMorningBody',
  'notifyMorningBodyPending',
  'digestSectionChat',
  'digestChatSummary',
  'digestChatTopics',
  // W5（0.74.0）：今天日程（只读系统日历）+ 周日周报
  'calendarAllDay',
  'morningHiCalendar',
  'morningHiWeekly',
];

const List<String> _localeCodes = ['zh', 'zh_Hant', 'en', 'ja', 'vi'];

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

void main() {
  print('== verify_morning (P0 晨间问候结构校验) ==');

  // ① ARB 15 键齐备
  for (final arb in _arbFiles) {
    final text = _read(arb);
    late Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      check(false, '$arb 可解析为 JSON ($e)');
      continue;
    }
    var allPresent = true;
    for (final k in _morningKeys) {
      if (!json.containsKey(k)) {
        allPresent = false;
        break;
      }
    }
    check(allPresent, '$arb 含全部 ${_morningKeys.length} 个晨间键');
  }

  // ② localeName 映射覆盖 5 语种
  final mds = _read('lib/core/morning_digest_service.dart');
  final mapCovered = _localeCodes.every((c) => mds.contains("'$c'"));
  check(mapCovered, 'morning_digest_service 的 localeName 映射覆盖 5 语种');

  // ③ 通知 kind + 方法
  final ns = _read('lib/core/notification_service.dart');
  check(ns.contains('morningDigest'), 'notification_service 含 NotifyKind.morningDigest');
  check(ns.contains('notifyMorning'), 'notification_service 含 notifyMorning');

  // ④ 心跳挂接
  final mainSrc = _read('lib/main.dart');
  check(mainSrc.contains('MorningDigestService.i.maybeEmit'),
      'main 心跳分支挂接 MorningDigestService.i.maybeEmit');

  // ⑤ 对话统计源
  final css = _read('lib/core/chat_stats_source.dart');
  check(css.contains('abstract class ChatStatsSource'),
      'chat_stats_source 暴露 ChatStatsSource');
  check(css.contains('class SqliteChatStatsSource'),
      'chat_stats_source 暴露 SqliteChatStatsSource');

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
