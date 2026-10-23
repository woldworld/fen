// 守卫：设置中心**拆成两页**（0.83.0）+ 文档与邮箱的试用口径对齐（隐私审计 P0-2）
//
// 为什么单独立一个脚本：
//   · "分两页"最容易被做成假的 —— 入口挪了、字段还留在原页（甚至两边都写同一批
//     键），用户看到的是同一坨长列表，或者更糟：改了不生效（一组键两个写入方）。
//   · 文档"试用放行"是**改判**（0.73.0 的硬拒 → 0.83.0 的确认放行）。改判最容易
//     改一半：选取时放开了、发送前还拦着（或反过来），用户撞见两个自相矛盾的门。
//
// 运行：dart run tool/verify_settings_split.dart
import 'dart:io';

int _pass = 0;
int _fail = 0;

void check(bool ok, String msg) {
  if (ok) {
    _pass++;
    print('  PASS  $msg');
  } else {
    _fail++;
    print('  FAIL  $msg');
  }
}

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

String _decomment(String s) => s.replaceAll(RegExp(r'//[^\n]*'), '');

/// 抽出某文件里 `prefs.setXxx(<键>)` 的所有键（= 该文件的**写入面**）
///
/// 三种写法都要认：
///   · 裸字面量 `prefs.setString('base_url', ...)`
///   · 本仓常量 `prefs.setString(kSearchProviderKey, ...)`
///   · 跨类常量 `prefs.setString(TrialClient.baseUrlKey, ...)`（引擎三件套走这个）
Set<String> _writtenKeys(String src) {
  final out = <String>{};
  for (final m in RegExp(
          r"prefs\.set(?:String|Bool|Int|StringList)\(\s*'([a-zA-Z0-9_]+)'")
      .allMatches(src)) {
    out.add(m.group(1)!);
  }
  for (final m in RegExp(
          r"prefs\.set(?:String|Bool|Int|StringList)\(\s*([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)*Key)\s*,")
      .allMatches(src)) {
    out.add(m.group(1)!);
  }
  return out;
}

void main() {
  print('== verify_settings_split (设置中心两页化 + 文档试用口径对齐 · 0.83.0) ==');

  final basicRaw = _read('lib/ui/settings_screen.dart');
  final advRaw = _read('lib/ui/advanced_settings_screen.dart');
  final chatRaw = _read('lib/ui/chat_screen.dart');
  // ★ 0.120.0：管理页也要读 —— 控制中心瘦身，6 项系统相关迁到它那里
  final manageRaw = _read('lib/ui/manage_screen.dart');
  final basic = _decomment(basicRaw);
  final adv = _decomment(advRaw);
  final chat = _decomment(chatRaw);
  final manage = _decomment(manageRaw);

  check(basicRaw.isNotEmpty && advRaw.isNotEmpty && chatRaw.isNotEmpty &&
          manageRaw.isNotEmpty,
      '源文件齐备（settings_screen / advanced_settings_screen / chat_screen / manage_screen）');

  // ================= A. 两页真的存在且接线 =================
  check(!basic.contains('.setSimpleMode'),
      '★★ 初级页**不放模式开关**（模式的唯一入口是顶部工具栏；0.84.0 改判）');
  check(basic.contains('l10n.settingsModeHint'),
      '初级页在入门模式下留一行指路小字（不占卡片、不摆开关）');
  check(basic.contains("import 'advanced_settings_screen.dart';"),
      '初级页 import 了进阶页');
  check(basic.contains('const AdvancedSettingsScreen()'),
      '初级页 push 的是 `AdvancedSettingsScreen`（独立页，不是再折叠一层）');
  check(adv.contains('class AdvancedSettingsScreen extends StatefulWidget'),
      '进阶页是一个真的页面（StatefulWidget）');
  check(adv.contains('appBar: AppBar(') || adv.contains('AppBar('),
      '进阶页自带 AppBar（可从顶栏返回，不会困在里面）');

  // ================= B. 初级页**不再**有那一大坨（反证：分两页不是假的）=================
  for (final token in <String>[
    '_baseUrlController',
    '_apiKeyController',
    'settingsSecEngine',
    'settingsSecSoul',
    'settingsSecMemory',
    'settingsRerunOnboarding',
    'settingsDiagnosticsTitle',
  ]) {
    check(!basic.contains(token), '★ 初级页已移除 `$token`（否则"分两页"是假的）');
  }

  // ================= C. 进阶页**收下了**那一大坨 =================
  for (final token in <String>[
    'settingsSecEngine',
    'settingsSecSoul',
    'settingsSecMemory',
    'settingsRerunOnboarding',
    'settingsDiagnosticsTitle',
    'settingsAutoAllowLabel',
    'settingsSearchTitle',
    'settingsLocalModelTest',
    'settingsTrialSwitchedToOwn',
  ]) {
    check(adv.contains(token), '进阶页收下了 `$token`');
  }

  // ================= D. 初级页该有的还在（不能被"瘦身"误伤）=================
  // ★ 0.120.0 改判：主人明确要求「控制中心瘦身」—— 6 项系统相关从初级页
  //   **迁至管理页**的「系统与能力」区块（仅进阶模式显示）。判据同步升级为
  //   「迁出 ≠ 消失」：初级页不许留、管理页必须收（见 D2）。保留项见下。
  for (final token in <String>[
    'settingsSecAppearance',
    'settingsSecSafety',
    'settingsObservationMode',
    '_identityBackupTile',
    'glossaryTitle',
    'settingsLegalTitle',
    '_openLegal(',
  ]) {
    check(basic.contains(token), '初级页保留了 `$token`');
  }

  // ================= D2. 0.120.0 迁出的 6 项：初级页不留 + 管理页必须收 =================
  for (final token in <String>[
    'settingsDeviceControlTitle',
    'settingsNotifySmsTitle',
    'settingsWeeklyReportTitle',
    '_NotifySettingsCard',
    '_TtsSettingsCard',
    '_CalendarSettingsCard',
  ]) {
    check(!basic.contains(token), '★★ 初级页已迁出 `$token`（0.120.0 控制中心瘦身）');
    check(manage.contains(token), '★★ 管理页已收下 `$token`（迁出不许消失）');
  }
  check(manage.contains('_systemCapabilityItems'),
      '管理页有「系统与能力」区块实体（`_systemCapabilityItems`）');
  // ★ 0.121.0（ADR-005 §2.3-1）：门控**粒度**改判 —— 整块常显、门控下沉只包
  //   「调参组」。这里只保留下限「门控仍在」，**不再判位置**：位置判定已升级成
  //   `tool/verify_mode_visibility.dart` ⑦ 的区间判定 + 两条负控；同一件事写两个
  //   判据 = 将来只改一处、另一处成漂移源（R40）。
  check(manage.contains('if (!mode.simpleMode)'),
      '管理页仍存在「仅进阶」门控（粒度 → verify_mode_visibility ⑦）');
  check(!manage.contains('manageMailTitle'),
      '★★ 管理页的「邮箱」卡已砍掉（与控制中心邮箱代管卡去重：同一目的地不许两个入口）');

  // ================= E. ★★ 一组键只许一个写入方（防"改了没生效"）=================
  final basicKeys = _writtenKeys(basic);
  final advKeys = _writtenKeys(adv);
  final overlap = basicKeys.intersection(advKeys).toList()..sort();
  check(overlap.isEmpty,
      '两页写入的 prefs 键**互不重叠**${overlap.isEmpty ? '' : '（重叠 → $overlap）'}（一组键两个写入方 = 改了不生效）');
  check(advKeys.contains('TrialClient.baseUrlKey') &&
          advKeys.contains('TrialClient.apiKeyKey') &&
          advKeys.contains('TrialClient.modelNameKey'),
      '引擎三件套（经 TrialClient.*Key）的写入方**只有**进阶页');
  check(basicKeys.contains('agent_observation_mode'),
      '观察模式的写入方**只有**初级页');

  // ================= F. 文档试用口径对齐邮箱（P0-2）=================
  check(!chat.contains('chatDocTrialBlocked'),
      '★★ 旧的「试用**硬拒**文档」已删除（与 0.82.0 放开的邮箱自相矛盾）');
  check(chat.contains('Future<bool> _ensureDocTrialAcked() async {'),
      '两处门共用一个确认实现 `_ensureDocTrialAcked`（不会一边放一边拦）');
  // ★ 只数 `await _ensureDocTrialAcked()` —— 函数**定义**那一行也含
  //   `_ensureDocTrialAcked()`，直接数方法名会把定义算进去（实得 3，误判）。
  final uses = RegExp(r'await _ensureDocTrialAcked\(\)').allMatches(chat).length;
  check(uses == 2,
      '★ 选取时 + 发送前**各一次**（定义不算，实得 $uses）');
  final ackFn =
      RegExp(r'Future<bool> _ensureDocTrialAcked\(\) async \{[\s\S]{0,900}?\n  \}')
              .firstMatch(chatRaw)
              ?.group(0) ??
          '';
  check(ackFn.isNotEmpty, '确认函数体可定位');
  check(ackFn.contains('TrialClient.isTrialMode()'), '只在试用下才问（自有 Key 不受打扰）');
  check(ackFn.contains('l10n.chatDocTrialNotice'), '弹的是**可见**告知（不是静默放行）');
  check(ackFn.contains('_docTrialAcked = true;'),
      '确认结果记在**内存**里（本次会话内不再重复问）');
  check(!chat.contains("prefs.setBool('_docTrialAcked") &&
          !chat.contains("prefs.setBool('doc_trial"),
      '★ 确认状态**不落库**（落库 = 点一次即永久默许）');
  // 反证：把发送前那道门改回硬拒 ⇒ 两处调用点必须变少（判据不是恒真）
  final noSecond = chatRaw.replaceFirst(
      'if (docsForSend.isNotEmpty && !await _ensureDocTrialAcked()) return;',
      '// removed');
  check(RegExp(r'await _ensureDocTrialAcked\(\)').allMatches(noSecond).length == 1,
      '正控：删掉发送前那道门 ⇒ 调用点从 2 变 1（证明判据真的在数）');

  // ================= G. 五语种：新键齐 + 旧键已清 =================
  const locales = ['en', 'zh', 'zh_Hant', 'ja', 'vi'];
  const want = [
    'settingsAdvancedTitle',
    'settingsAdvancedEntryHint',
    'settingsModeHint',
    'chatDocTrialTitle',
    'chatDocTrialNotice',
    'chatDocTrialContinue',
  ];
  // ★ 0.84.0：退役 `chatDocTrialBlocked` + 设置页模式开关的两个标签键。
  const dead = [
    'chatDocTrialBlocked',
    'settingsAdvancedModeTitle',
    'settingsAdvancedModeSubtitle',
  ];
  final missing = <String>[];
  final stale = <String>[];
  for (final c in locales) {
    final arb = _read('lib/l10n/app_$c.arb');
    for (final k in want) {
      if (!arb.contains('"$k"')) missing.add('$c:$k');
    }
    if (dead.any((k) => arb.contains('"$k"'))) stale.add(c);
  }
  check(missing.isEmpty, '五语种 × ${want.length} 键齐备${missing.isEmpty ? '' : '（缺 → $missing）'}');
  check(stale.isEmpty, '★ 五语种均已清掉退役键（${dead.join(" / ")}）${stale.isEmpty ? '' : '（仍在 → $stale）'}');

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
