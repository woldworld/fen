// 纯 Dart 校验脚本：验证 0.74.0 W5/S7「智能体周报」的结构级落地。
// 运行：dart run tool/verify_agent_report.dart
//
// 盯五件事：
//   ① **统计源**：agent_report_source 暴露模型/抽象/实现，且分类映射覆盖
//      项目里实际写入过的 action_type（设备/社交/建议/审查/工具）。
//   ② **纯本地**：统计只查 agent_actions 表，无网络调用。
//   ③ **页面纪律**：周报页自备渐变底（R10：push 路由页必须自备背景）。
//   ④ **接线**：设置页有入口、晨间问候**仅周日**附加。
//   ⑤ **五语种**：周报相关 ARB 键 5 个语种齐备。

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

const List<String> _reportKeys = [
  'settingsWeeklyReportTitle',
  'settingsWeeklyReportHint',
  'weeklyReportTitle',
  'weeklyReportSubtitle',
  'weeklyReportRange',
  'weeklyReportTotal',
  'weeklyReportActiveDays',
  'weeklyReportCatTools',
  'weeklyReportCatDevice',
  'weeklyReportCatSocial',
  'weeklyReportCatSuggestion',
  'weeklyReportCatReview',
  'weeklyReportCatOther',
  'weeklyReportEmpty',
  'morningHiWeekly',
];

/// 剥注释（skill §22.3：本仓习惯把旧缺陷写进注释，不剥会让守卫被说明文字报红）。
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

/// 读文件；`.dart` 源码自动剥注释后再返回（ARB 等非 Dart 原样返回）。
String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  final t = f.readAsStringSync();
  return p.endsWith('.dart') ? _stripComments(t) : t;
}

void main() {
  print('== verify_agent_report (W5/S7 智能体周报) ==');

  // ① 统计源
  final src = _read('lib/core/agent_report_source.dart');
  check(src.contains('class AgentActionStats'), '暴露 AgentActionStats');
  check(src.contains('enum AgentActionCategory'), '暴露 AgentActionCategory');
  check(src.contains('abstract class AgentReportSource'), '暴露 AgentReportSource');
  check(src.contains('class SqliteAgentReportSource'), '暴露 SqliteAgentReportSource');
  // 分类映射必须覆盖实际写入过的 action_type 代表值
  check(src.contains("startsWith('device_')"), "分类识别 device_* 前缀");
  check(src.contains("'social_send'"), "分类含 social_send");
  check(src.contains("'proactive_suggestion'"), "分类含 proactive_suggestion");
  check(src.contains("'plugin_denied'"), "分类含 plugin_denied");

  // ② 纯本地：只读 agent_actions，无 http/网络
  check(src.contains("'agent_actions'"), '只查 agent_actions 表');
  check(!src.contains('HttpClient') && !src.contains('http://') && !src.contains('https://'),
      '★ 统计源无任何网络调用（纯本地）');

  // ③ 页面纪律（R10）
  final page = _read('lib/ui/weekly_report_screen.dart');
  check(page.contains('class WeeklyReportScreen'), '周报页 WeeklyReportScreen 存在');
  check(page.contains('backgroundDecoration'),
      '周报页自备渐变底（R10：push 路由页不透明背景）');
  check(page.contains('SqliteAgentReportSource'), '周报页使用本地统计源');

  // ④ 接线
  // ★ 0.120.0：控制中心瘦身，周报入口迁入管理页「系统与能力」区块（仅进阶模式）。
  //   判据改指 manage_screen 并**双向**钉：管理页必须收、控制中心不得再留
  //   （迁出 != 消失；单向判据会被「双入口」与「两处都没」同时糊弄，R50）。
  //   本轮实证过判据是活的：迁移前本关 1 FAIL（红），迁移后转绿。
  final manage = _read('lib/ui/manage_screen.dart');
  check(manage.contains('weekly_report_screen.dart') && manage.contains('WeeklyReportScreen'),
      '管理页「系统与能力」有周报入口（0.120.0 迁入）');
  final settings = _read('lib/ui/settings_screen.dart');
  check(!settings.contains('WeeklyReportScreen'),
      '★ 控制中心不再保留周报入口（迁出即迁出，不许双入口）');
  final morning = _read('lib/core/morning_digest_service.dart');
  check(morning.contains('SqliteAgentReportSource'), '晨间问候接入了周报统计源');
  check(morning.contains('morningHiWeekly'), '晨间问候使用 morningHiWeekly 要点');
  check(morning.contains('DateTime.sunday'),
      '★ 周报要点**仅周日**附加（周一到周六不打扰）');

  // ⑤ 五语种
  for (final arb in _arbFiles) {
    final text = _read(arb);
    late Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      check(false, '$arb 可解析为 JSON ($e)');
      continue;
    }
    final missing = _reportKeys.where((k) => !json.containsKey(k)).toList();
    check(missing.isEmpty,
        '$arb 含全部 ${_reportKeys.length} 个周报键${missing.isEmpty ? '' : '，缺 $missing'}');
  }

  print('');
  print('PASS=$_pass FAIL=$_fail');
  exit(_fail == 0 ? 0 : 1);
}
