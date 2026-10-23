// 纯 Dart 校验脚本：钉死 0.82.0 试用地带的两条真机事故修复 + 一处收口。
// 运行：dart run tool/verify_trial_switch.dart
//
// ★★ 为什么需要这个脚本（真机事故）：
//   主人在「设置」里按横幅提示"填入自己的 Key"，而 `_saveSettings` 当时**无条件覆盖**
//   base_url/api_key/model_name（写 `llm_mode` 的地方**只有引导页**）⇒ 试用身份
//   （Bearer = 本机 agent_id）被覆盖、模式却仍是 trial ⇒ 服务端 401 `trial_agent_required`
//   ⇒ 界面又提示"前往设置填入自己的 Key" ⇒ **死循环**。主人原话："试用期为什么不让
//   操作邮箱呢？这不太合理吧？"（其实邮件互斥门根本没触发，是通道 401）。
//
//   两条修复：
//     ① 试用下**开放邮箱**（放行 + 每轮可见告知"内容经官方服务器转发、不留存"）；
//     ② 主人改了自己的 Key ⇒ **自动切成自有模式**并纠正端点（`/api/trial` → 直连）。
//
// ★★ 本脚本**真跑**纯逻辑（`import package:dahuang_ai/core/trial_config.dart`）：
//   该文件**零 Flutter 依赖** ⇒ 可被 `dart run` 直接执行，挂 CI 时也不需要 Flutter SDK。
//
// ★ 归因更正（0.89.0 实证，0.108.0 再确认并固化）：
//   本机 `flutter test` 早期"39 个文件在 loading 期整锅假挂"，**不是**宿主层面的原因，
//   而是 **HTTP(S) 代理环境变量劫持了 `flutter_tester` 回连 flutter tool 的本地 WebSocket**
//   （`Invalid WebSocket upgrade request`）。剥掉 `*_proxy`、设
//   `no_proxy=127.0.0.1,localhost,::1` 后：**459 / 0 All tests passed**。
//   该动作已固化进**唯一入库入口** `dart run tool/run_flutter_test.dart`
//   （守卫：`tool/verify_regression_entry.dart`），别再手敲 `env -u ...`。
//   本脚本继续走 `dart run` 是**刻意选择**（零平台依赖），不是"跑不了"的将就。
//
// 施工坑（两处，已修）：① 抓函数体不能用 `\n  }`（会被签名里的 `\n  })` 提前截断）
//   ⇒ 必须 `\n  }\n`；②「不得再出现 X」这类**反证**必须落在**具体文案**上，不能扫整文件
//   —— 因为**纪律注释**里恰恰会引用那句被禁的话。

import 'dart:io';

import 'package:dahuang_ai/core/trial_config.dart';

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

/// kbVersion 是**单调递增的整数串**。旧写法（断言某个具体快照值）属于**写死的版本快照**
/// （红线 13）—— 每次 KB bump 这几条守卫就集体假红。
/// ⇒ 只断言**下限**：该能力自 KB v28 起存在，之后怎么涨都算满足。
bool kbAtLeast(String kb, int min) {
  final m = RegExp(r"kbVersion\s*=\s*'(\d+)'").firstMatch(kb);
  if (m == null) return false;
  final v = int.tryParse(m.group(1)!);
  return v != null && v >= min;
}

void main() {
  // 自检：kbAtLeast 认下限、不认快照（否则下次 KB bump 又集体假红）
  check(kbAtLeast("const String kbVersion = '29';", 28),
      '自检：kbVersion 29 满足「大于或等于 28」');
  check(!kbAtLeast("const String kbVersion = '27';", 28),
      '自检：kbVersion 27 不满足「大于或等于 28」（证明不是恒真）');

  print('== verify_trial_switch (试用开放邮箱 + 改 Key 自动切自有 · 0.82.0) ==');

  final trial = _read('lib/core/trial_client.dart');
  final cfg = _read('lib/core/trial_config.dart');
  // ★ 0.83.0：引擎那批字段（含"改 Key 自动切自有"）已搬到**进阶设置页**，
  //   本守卫的锚点必须跟着走 —— 继续钉 `settings_screen.dart` 会全部落空，
  //   而"落空"在这里的表现是 FAIL（不是静默全绿），所以能立刻发现。
  final settings = _read('lib/ui/advanced_settings_screen.dart');
  final onboarding = _read('lib/ui/onboarding_screen.dart');
  final mail = _read('lib/core/mail/mail_tools.dart');
  final kb = _read('lib/core/system_knowledge.dart');

  check(trial.isNotEmpty && settings.isNotEmpty && mail.isNotEmpty,
      '源文件齐备（trial_client / settings_screen / mail_tools）');
  if (trial.isEmpty || settings.isEmpty || mail.isEmpty) {
    print('');
    print('== 结果：PASS=$_pass  FAIL=$_fail ==');
    exit(1);
  }

  // ================= A. 试用配置四件套 —— 单一事实源 =================
  check(cfg.contains('class TrialConfig'), '纯逻辑收在 trial_config.dart（TrialConfig）');
  check(!cfg.contains('package:flutter') && !cfg.contains('package:shared_preferences'),
      '★ trial_config.dart 零 Flutter 依赖（故可 `dart run` 实测 —— 本脚本的前提）');
  // ★ 跨层**取值**实测：这些字面量已从 trial_client 搬进 trial_config，
  //   必须**实跑**钉住（字符串判据已随之失效，别让取值悄悄漂移）。
  check(TrialConfig.modeKey == 'llm_mode', '★ 实测：modeKey == llm_mode');
  check(TrialConfig.trialModeValue == 'trial', '★ 实测：trialModeValue == trial');
  check(
      TrialConfig.baseUrlKey == 'base_url' &&
          TrialConfig.apiKeyKey == 'api_key' &&
          TrialConfig.modelNameKey == 'model_name',
      '★ 实测：四件套键名（base_url / api_key / model_name）');
  // ★ 锚点用 `\n  }\n`：签名的收尾是 `\n  }) async {`，用 `\n  }` 会被它提前截断。
  final applyFn = RegExp(r'applyTrialConfig\([\s\S]{0,900}?\n  \}\n')
          .firstMatch(trial)
          ?.group(0) ??
      '';
  check(applyFn.contains('modeKey') &&
          applyFn.contains('baseUrlKey') &&
          applyFn.contains('apiKeyKey') &&
          applyFn.contains('modelNameKey'),
      'applyTrialConfig 一次写齐四件套（llm_mode/base_url/api_key/model_name）');
  check(applyFn.contains('AG-TRIAL'), 'applyTrialConfig 对空 agentId 回落 AG-TRIAL（不写空 Key）');
  check(onboarding.contains('TrialClient.applyTrialConfig('),
      '引导页经 applyTrialConfig 落库（不再手搓四件套）');
  check(settings.contains('TrialClient.applyTrialConfig('),
      '进阶设置页「恢复免费试用」与引导页**共用同一实现**');
  check(
      trial.contains('static bool shouldSwitchToOwn(') &&
          trial.contains('TrialConfig.shouldSwitchToOwn'),
      '★ trial_client 保留同名 static 转发（对外 API 不变，设置页/测试照旧）');

  // ================= B. 保存：先读模式，再写值（次序判据）=================
  final iModeRead = settings.indexOf('modeBefore =');
  final iKeyWrite = settings.indexOf('setString(TrialClient.apiKeyKey');
  check(iModeRead >= 0, '_saveSettings 保存前读出当前模式（modeBefore）');
  check(iKeyWrite >= 0, '_saveSettings 经 TrialClient.apiKeyKey 写入 Key（无裸字面量）');
  check(iModeRead >= 0 && iKeyWrite >= 0 && iModeRead < iKeyWrite,
      '★ 次序：**先读模式**再写 Key（反过来才是事故成因）');
  check(settings.contains('keepTrialKey') && settings.contains('keepTrialBase'),
      '试用下**不写空值**（一次误清空不许毁掉试用身份）');

  // ================= C. 改 Key 自动切自有 —— **行为实测**（真跑纯函数）=================
  check(
      TrialConfig.shouldSwitchToOwn(
          currentMode: 'trial',
          previousKey: 'AG-abc123',
          newKey: 'sk-deepseek'),
      '★ 实测 ①：试用 + 非空新 Key + 与旧不同 ⇒ **切**');
  check(
      !TrialConfig.shouldSwitchToOwn(
          currentMode: 'own', previousKey: 'AG-abc', newKey: 'sk-x'),
      '★ 实测 ②：非试用模式 ⇒ 不切（与本次改动无关）');
  check(
      !TrialConfig.shouldSwitchToOwn(
          currentMode: null, previousKey: 'AG-abc', newKey: 'sk-x'),
      '★ 实测 ③：老用户无模式 ⇒ 不切');
  check(
      !TrialConfig.shouldSwitchToOwn(
          currentMode: 'trial', previousKey: 'AG-abc', newKey: ''),
      '★ 实测 ④：清空 Key ⇒ 不切（一次误清空不许毁掉试用身份）');
  check(
      !TrialConfig.shouldSwitchToOwn(
          currentMode: 'trial', previousKey: 'AG-abc', newKey: '   '),
      '★ 实测 ⑤：纯空白 ⇒ 不切');
  check(
      !TrialConfig.shouldSwitchToOwn(
          currentMode: 'trial', previousKey: 'AG-abc', newKey: '  AG-abc  '),
      '★ 实测 ⑥：没改（前后空白容错）⇒ 不切');
  check(
      TrialConfig.trialApiBase('https://h.example.com') ==
              'https://h.example.com/api/trial' &&
          TrialConfig.trialApiBase('https://h.example.com/') ==
              'https://h.example.com/api/trial',
      '★ 实测 ⑦：trialApiBase 尾斜杠归一');
  check(
      TrialConfig.ownBaseUrlFix('https://h/api/trial') ==
          TrialConfig.defaultOwnBaseUrl,
      '★ 实测 ⑧：端点仍指 /api/trial ⇒ 纠正为直连');
  check(TrialConfig.ownBaseUrlFix('https://api.deepseek.com') == null,
      '★ 实测 ⑨：已直连 ⇒ 不动（返回 null）');
  check(
      TrialConfig.ownBaseUrlFix('https://x/api/trial', fallback: 'https://y') ==
          'https://y',
      '★ 实测 ⑩：自定义 fallback 生效');

  // C2. 接入点（源码层，防"函数在、没人调"）
  check(settings.contains('TrialClient.shouldSwitchToOwn('),
      '进阶设置页调用 shouldSwitchToOwn（接入点）');
  check(settings.contains("setString(TrialClient.modeKey, 'own')"),
      '★ 命中即切模式为 own（真的写库，不只提示）');
  check(settings.contains('TrialClient.ownBaseUrlFix('),
      '命中时一并纠正端点（own 模式不许再指向 /api/trial）');
  check(settings.contains('settingsTrialSwitchedToOwn'),
      '切模式**可见**（SnackBar 说明切了什么、端点改成什么）');

  // ================= D. 邮箱：放行 + 可见告知（反证旧拒绝已删）=================
  check(mail.contains('withTrialNotice'), 'mail_tools 提供 withTrialNotice（放行 + 告知包装）');
  // ★ 反证必须落在**告知文案**上：文件里那句"不得再说 X"的**纪律注释**会引用 X。
  final noticeBody =
      RegExp(r'String trialNotice\(\)[\s\S]{0,500}?;').firstMatch(mail)?.group(0) ?? '';
  check(noticeBody.isNotEmpty, 'mail_tools 定义试用告知文案');
  check(noticeBody.contains('官方服务器'),
      '★ 告知明确"内容经官方服务器转发"（对外措辞准确）');
  final useCount = RegExp(r'withTrialNotice\(').allMatches(mail).length;
  check(useCount >= 4,
      '★ 读信/发信三处 handler 全部包了告知（定义 1 + 调用 >= 3，实得 $useCount）');
  check(!mail.contains('trialRefusal'),
      '★ 旧的试用硬拒绝（trialRefusal）**已彻底删除**（反证半残分支）');
  check(!noticeBody.contains('不经过'),
      '★ 邮件告知不得再承诺"内容不经过我们的服务器"（试用下不成立）');

  // ================= E. KB 同一提交更新 =================
  check(kbAtLeast(kb, 28), 'KB kbVersion 大于或等于 28（试用告知自 v28 起；只断下限，不钉当前值）');
  // ★ 0.83.0：email 条目因补了「总开关」而显著变长，900 字符的窗口**不够**
  //   ⇒ 正则会截在半路，"free trial" 落在截断之外 ⇒ 判据假 FAIL。
  //   （教训：正则窗口是**隐性上限**，条目变长时它不会提醒你，只会变成红灯。）
  final emailEntry = RegExp(r"HelpEntry\('email'[\s\S]{0,1800}?\),")
          .firstMatch(kb)
          ?.group(0) ??
      '';
  check(emailEntry.contains('free trial'),
      'KB email 条目已改口（试用下可用、内容经官方服务器转发）');

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
