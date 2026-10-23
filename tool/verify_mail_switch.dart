// 守卫：邮箱能力**总开关**（0.83.0 · 隐私审计 P0-1）
//
// 为什么单独立一个脚本：隐私能力的默认态是最容易被"顺手改坏"的东西 ——
//   · 有人为了省事把默认值改成 `?? true` ⇒ 装好就能读信，用户毫不知情；
//   · 有人把"关"实现成"注册了但 handler 拒答" ⇒ 模型照样看得见"主人有邮箱"，
//     也照样会反复尝试调用（关了个寂寞）；
//   · 有人给键换个名字却不改另一处 ⇒ 开关变成"拨了没反应"。
// 这三类都不是编译错误，跑起来也"看着正常"，只能靠钉。
//
// 运行：dart run tool/verify_mail_switch.dart
import 'dart:io';

import 'package:dahuang_ai/core/mail/mail_switch.dart';

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

/// 剥掉行注释（只用于"代码里有没有这个 token"类的判据）
String _decomment(String s) =>
    s.replaceAll(RegExp(r'//[^\n]*'), '');

List<File> _libDart() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String _norm(String p) => p.replaceAll(r'\', '/');

void main() {
  print('== verify_mail_switch (邮箱总开关 · 默认关 / 关即摘除 · 0.83.0) ==');

  final agent = _decomment(_read('lib/core/agent_service.dart'));
  final settings = _decomment(_read('lib/ui/settings_screen.dart'));
  final tools = _read('lib/core/mail/mail_tools.dart');
  final switchSrc = _read('lib/core/mail/mail_switch.dart');

  check(agent.isNotEmpty && settings.isNotEmpty && tools.isNotEmpty,
      '源文件齐备（agent_service / settings_screen / mail_tools / mail_switch）');

  // ================= A. 默认态 —— **行为实测**（跑真函数，不是读字符串）=================
  check(MailSwitch.mailEnabledPrefKey == 'mail_enabled', '★ 实测：键名 == mail_enabled');
  check(!MailSwitch.resolve(null), '★★ 实测：键不存在 ⇒ **关**（隐私能力默认关）');
  check(!MailSwitch.resolve(false), '★ 实测：显式 false ⇒ 关');
  check(MailSwitch.resolve(true), '★ 实测：显式 true ⇒ 开');

  // A2. 正控：把默认改成"键不存在 = 开"这种改动**扫不出来**，所以这里钉的是
  //     源码里的 `== true` 形态（真改坏 ⇒ 本条立刻翻假）。
  check(switchSrc.contains('static bool resolve(bool? stored) => stored == true;'),
      '默认语义写在源码里是 `stored == true`（改坏即被本条钉住）');

  // ================= B. 键名单一事实源 =================
  final literalHits = <String>[];
  for (final f in _libDart()) {
    if (_decomment(f.readAsStringSync()).contains("'mail_enabled'")) {
      literalHits.add(_norm(f.path));
    }
  }
  check(literalHits.length == 1 &&
          literalHits.first.endsWith('lib/core/mail/mail_switch.dart'),
      "字面量 'mail_enabled' 全仓只出现在 mail_switch.dart${literalHits.length == 1 ? '' : '（→ $literalHits）'}");
  check(agent.contains('MailSwitch.mailEnabledPrefKey') && settings.contains('MailSwitch.mailEnabledPrefKey'),
      '读取方（initAgent）与 UI 都走 `MailSwitch.mailEnabledPrefKey`（不各写各的字符串）');

  // ================= C. 注册门：关 = 压根不注册 =================
  // ★★ 0.107.0 修正（本轮活证，别改回去）：`iGate` **必须**定位**门控语句本身**
  //   （带 `if (` 的完整形态），**不能**只找 `MailSwitch.resolve(prefs.getBool`。
  //   后者在 0.107.0 有了**第二个合法读取点** —— `_privacyCapabilityNoteFor`
  //   回读开关状态、写进导航回执（修"打开邮箱页 ≠ 邮箱可用"那次真机事故）。
  //   用短形态会把那个**回读点误当成门控** ⇒ 下面的正控"抽掉门控"永远翻不了假
  //   （恒绿 = 守卫已瞎）。这正是"守卫两反模式①：反例锚点动态解析"的变体。
  const gateStmt =
      'if (MailSwitch.resolve(prefs.getBool(MailSwitch.mailEnabledPrefKey))) {';
  final iGate = agent.indexOf(gateStmt);
  final iRegister = agent.indexOf('buildMailTools(');
  check(iGate >= 0, 'initAgent 里有 `MailSwitch.resolve(...)` 门控');
  check(iRegister >= 0, 'initAgent 里有 buildMailTools( 注册点');
  check(iGate >= 0 && iRegister >= 0 && iGate < iRegister,
      '★ 次序：门控在注册**之前**（否则等于先注册再谈开关）');
  // ★ 反证（守卫两反模式①）：把门控抽掉 ⇒ 判据必须翻假，证明不是恒真
  final noGate = agent.replaceFirst(gateStmt, '// gate removed');
  check(noGate != agent && !noGate.contains(gateStmt),
      '正控：抽掉门控 ⇒ 判据必须翻为假（证明"关 = 不注册"真的在被钉）');
  // ★ 0.107.0：第二个读取点**必须也走同一事实源**，不许为回执手写第二套判据。
  check(
      RegExp(r"'mail'\s*=>\s*MailSwitch\.resolve\(prefs\.getBool\(MailSwitch\.mailEnabledPrefKey\)\)")
          .hasMatch(agent),
      '0.107.0 导航回执读取点同样走 MailSwitch.resolve（与门控同一事实源）');

  // ================= D. 关 = **摘除**（不是"拒答"）=================
  check(agent.contains('Future<void> setMailEnabled(bool value) async {'),
      'AgentService 提供 setMailEnabled（唯一写入方）');
  final setFn = RegExp(r'Future<void> setMailEnabled\(bool value\) async \{[\s\S]{0,600}?\n  \}')
          .firstMatch(_read('lib/core/agent_service.dart'))
          ?.group(0) ??
      '';
  check(setFn.isNotEmpty, 'setMailEnabled 函数体可被定位（供下述逐条钉）');
  check(setFn.contains('prefs.setBool(MailSwitch.mailEnabledPrefKey, value)'),
      'setMailEnabled 落库（不是只改内存）');
  check(setFn.contains('_toolRegistry.dispose(name)'),
      '★★ 关 = 从注册表 `dispose`（真摘除，模型看不见工具）');
  check(setFn.contains('kMailToolNames'),
      '摘除清单走 `kMailToolNames`（唯一一份，不手抄字符串）');
  check(setFn.contains('await initAgent();'),
      '开 = 重跑 initAgent（重新注册；_registerBuiltin 幂等）');

  // ================= E. 摘除清单与工具组**逐名一致** =================
  final declared = RegExp(r"name: '(mail_[a-z_]+)'")
      .allMatches(tools)
      .map((m) => m.group(1)!)
      .toList();
  check(declared.length == 5,
      'mail_tools 声明了 5 个邮箱工具（实际 ${declared.length}）');
  final namesConst = RegExp(r"const List<String> kMailToolNames = <String>\[([\s\S]{0,300}?)\];")
          .firstMatch(tools)
          ?.group(1) ??
      '';
  check(namesConst.isNotEmpty, 'kMailToolNames 常量存在');
  for (final n in declared) {
    check(namesConst.contains("'$n'"), '摘除清单含 `$n`');
  }
  // 顺序也要一致（顺序 = 注册顺序；乱序说明有人手改过其中一边）
  final listed = RegExp(r"'([a-z_]+)'").allMatches(namesConst).map((m) => m.group(1)!).toList();
  var sameOrder = listed.length == declared.length;
  for (var i = 0; i < listed.length && i < declared.length; i++) {
    if (listed[i] != declared[i]) sameOrder = false;
  }
  check(sameOrder, '★ 清单顺序与注册顺序一致（$listed）');

  // ================= F. UI：开关存在 + 写穿 + 不给假状态 =================
  check(settings.contains('AgentService().setMailEnabled('),
      '设置页经 `AgentService.setMailEnabled` 写（唯一写入方，不裸写 prefs）');
  check(settings.contains('MailSwitch.resolve(prefs.getBool(MailSwitch.mailEnabledPrefKey))'),
      '设置页读初值走 `MailSwitch.resolve`（默认关）');
  check(settings.contains('_mailEnabled && _mailAccountCount == 0'),
      '★ 开了却没绑账号 ⇒ 明说（不给"可用"的假状态）');
  check(settings.contains('const MailAccountScreen()'),
      '设置页提供「管理邮箱账号」入口（不用跑去管理页找）');

  // ================= G. 五语种文案齐备 =================
  const locales = ['en', 'zh', 'zh_Hant', 'ja', 'vi'];
  const want = [
    'settingsMailTitle',
    'settingsMailSubtitle',
    'settingsMailHint',
    'settingsMailManageAccounts',
    'settingsMailOnToast',
    'settingsMailOffToast',
    'settingsMailNoAccount',
  ];
  final missing = <String>[];
  for (final c in locales) {
    final arb = _read('lib/l10n/app_$c.arb');
    for (final k in want) {
      if (!arb.contains('"$k"')) missing.add('$c:$k');
    }
  }
  check(missing.isEmpty, '五语种 × 7 个邮箱键齐备${missing.isEmpty ? '' : '（缺 → $missing）'}');

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
