// 0.81.0 守卫：**邮箱错误文案绝不回显凭证** + **163 的拒绝文案必须归到 auth**。
//
// 缘起（0.80.0 真机截图实证）：主人填错 163 授权码，错误横幅把授权码**明文**
// 印在屏上（`IMAP LOGIN "..." "<真实授权码>"`）—— 根因 = `imap_client._cmd`
// 抛错时把整条 LOGIN 命令塞进异常文案；且 `mail_account_screen` 的映射只认
// Gmail/QQ 形态（`AUTHENTICATIONFAILED`），认不出网易的
// `NO LOGIN Login error or password error` ⇒ 走了"原样透出"分支。
//
// 本脚本把这些不变量钉在**源码序**上：
//   ① 脱敏：`_cmd` 的 throw 必须对 command 与服务端响应**都**过 `_redact`；
//      `_redact` 必须覆盖 IMAP 引号转义形态 + 原文形态；旧裸形态不得回归；
//   ② 收口：分类抽成 `mail_errors.dart` 的纯函数（离线可测），163 形态归 'auth'，
//      认不出返回 null（不许编造）；
//   ③ UI：`_probe` 调 `classifyMailProbeError`，不再自带一份内联映射（两处判据会漂移）；
//   ④ 测试在册：`test/mail_probe_error_test.dart` 钉住"绝不回显 + 163 归 auth"。
//
// 源文本扫描型脚本必须带**正控**（把好副本人为改坏，判据必须判出），否则
// 匹配式一坏就"扫到 0 处 → 恒绿"。
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

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

// ------------------------------------------------------------------
// 判据（纯函数，可被正控喂坏副本）
// ------------------------------------------------------------------

/// ① `_cmd` 的 throw 必须脱敏（command 与服务端响应都过 `_redact`）。
bool throwIsRedacted(String src) =>
    src.contains(r"'IMAP ${_redact(command)} 失败：${_redact(done.trim())}'");

/// 旧的不安全形态（裸 `$command` 直接进异常文案）不得回归。
bool legacyUnsafeFormGone(String src) => !src.contains(r"'IMAP $command 失败");

/// `_redact` 必须覆盖**两种形态**（IMAP 引号转义形态 + 原文形态）。
bool redactCoversBothForms(String src) =>
    src.contains('.replaceAll(_q(password),') &&
    src.contains('.replaceAll(password,');

/// ② 分类函数在 core 层；163 形态判据在案。
bool classifyHas163Marker(String src) =>
    src.contains("contains('NO LOGIN')") &&
    src.contains("contains('Login error or password error')");

/// 认不出的必须返回 null（不许编造）。
bool classifyUnknownIsNull(String src) => src.contains('return null;');

/// ③ UI 只调分类函数，不再内联映射。
bool uiUsesClassifier(String src) =>
    src.contains('classifyMailProbeError(s) ??') &&
    !src.contains("s.contains('AUTHENTICATIONFAILED')");

/// ④ 测试在册。
bool testRegistered(String src) =>
    src.contains('classifyMailProbeError') &&
    src.contains("isNot(contains('secret'))") &&
    src.contains('NO LOGIN Login error or password error');

void main() {
  final imap = _read('lib/core/mail/imap_client.dart');
  final errs = _read('lib/core/mail/mail_errors.dart');
  final ui = _read('lib/ui/mail_account_screen.dart');
  final test = _read('test/mail_probe_error_test.dart');

  print('== 0.81.0 邮箱错误文案守卫 ==');
  check(imap.isNotEmpty, 'imap_client.dart 在案');
  check(errs.isNotEmpty, 'mail_errors.dart 在案');

  // ① 脱敏
  check(throwIsRedacted(imap), '① _cmd 抛错对 command + 响应都过 _redact');
  check(legacyUnsafeFormGone(imap), '① 旧裸形态（IMAP \$command 失败）不回归');
  check(redactCoversBothForms(imap), '① _redact 覆盖转义形态 + 原文形态');

  // ② 分类收口
  check(classifyHas163Marker(errs), '② 163 形态（NO LOGIN / Login error…）归 auth');
  check(classifyUnknownIsNull(errs), '② 认不出返回 null（不编造）');

  // ③ UI
  check(uiUsesClassifier(ui), '③ _probe 调分类函数，不再内联映射');

  // ④ 测试在册
  check(testRegistered(test), '④ 测试钉住"绝不回显 + 163 归 auth"');

  // ------------------------------------------------------------------
  // 正控：把好副本**人为改坏**，判据必须判出
  // ------------------------------------------------------------------
  print('  --- positive control ---');
  check(
      !throwIsRedacted(
          imap.replaceFirst('_redact(command)', 'command')),
      '正控①：抽掉 command 脱敏 ⇒ 判出 ✓');
  check(
      !legacyUnsafeFormGone(imap.replaceFirst(
          r"'IMAP ${_redact(command)} 失败", r"'IMAP $command 失败")),
      '正控②：改回裸形态 ⇒ 判出 ✓');
  check(
      !redactCoversBothForms(
          imap.replaceFirst('.replaceAll(password,', '.replaceAll(x,').replaceFirst(
              '.replaceAll(_q(password),', '.replaceAll(y,')),
      '正控③：只留一种形态的替换 ⇒ 判出 ✓');
  check(
      !classifyHas163Marker(errs.replaceFirst(
          "contains('NO LOGIN')", "/* removed */")),
      '正控④：抽掉 163 判据 ⇒ 判出 ✓');
  check(
      !classifyUnknownIsNull(
          errs.replaceFirst('return null;', 'return "auth";')),
      '正控⑤：认不出也编造 ⇒ 判出 ✓');
  check(
      !uiUsesClassifier(ui.replaceFirst('classifyMailProbeError(s) ??', 's ??')),
      '正控⑥：UI 退回内联/透传 ⇒ 判出 ✓');
  check(
      !testRegistered(test.replaceFirst("isNot(contains('secret'))", 'x')),
      '正控⑦：抹掉"绝不回显"断言 ⇒ 判出 ✓');

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
