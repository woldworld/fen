// 网络层故障判据与一次退避重试的守卫。
//
// 运行：dart run tool/verify_net_diagnosis.dart
//
// ============================================================
// 为什么要有它（2026-10-03 用户实测）
// ------------------------------------------------------------
// 用户让两个分身在**局域网**里互聊：设备能互相发现（物理通道打通），
// 但那条 Wi-Fi **没有外网出口** ⇒ 调云端大模型时内核回
//   `ClientException with SocketException: No route to host (errno = 113)`
// 而**私聊入站路径**把这条**环境问题**报成了
//   「❌ 社交决策流水线异常，本轮已终止」 ——「大家能发现，却聊不了」。
//
// 根因不是"逻辑坏了"，而是**同一个故障在两条路径上说法不一致**：
//   · 主人对话框 (`sendMessage`) 早有判据 + 可操作指引（写在 catch 里，**硬编码**）；
//   · 社交入站 (`_processBatchedMessages`) **没有**。
// ⇒ 本脚本钉住"判据只有一份 + 两条路径都接上 + 旧硬编码已消失"。
//
// ★ 自带**正控**：先证明"我抓得到接线/抓得到旧串"，再扫真实文件。
//   否则匹配式一漂移就"扫到 0 处 ⇒ 恒绿"（恒真守卫比没有守卫更坏）。
//
// ============================================================
// [P0 追加] 降级链的可离线断言（2026-10-03）
// ------------------------------------------------------------
// 主人定的策略：连 LLM 时**先走 Wi-Fi → 不通降级蜂窝 → 再不通就如实提醒**。
// 这段策略抽成**纯函数** `NetDiagnosis.nextStep`（F2 段钉死三段 + 短路），
// 执行器 `withNetworkRetry(..., switchRoute:)` 里 `switchRoute` 是**唯一插槽**：
//   · 不传（P0） ⇒ 第 2 次失败**如实抛出**（F4：只试 2 次，绝不假装换路成功）；
//   · 传入（P1） ⇒ 第 2 次失败后**恰好换路一次**（F5：提前钉住 P1 契约）。
// ★ Dart 不能把连接绑到指定网络 ⇒ 真换路需原生 Kotlin（Android only，iOS 无对应）。
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:dahuang_ai/core/net_diagnosis.dart';

int _pass = 0;
int _fail = 0;
final List<String> _failures = <String>[];

void _ok(String what) {
  _pass++;
  print('  ok   $what');
}

void _bad(String what) {
  _fail++;
  _failures.add(what);
  print('  FAIL $what');
}

/// 计数（needle 非空；本脚本不对空串计数）
int _countOf(String haystack, String needle) =>
    haystack.split(needle).length - 1;

/// 剥注释：**先块注释、再行注释**。
/// 本仓正解 —— 只按"行首是 * / //"剥会漏掉块注释里不以 * 开头的续行，
/// 于是注释里的同串被当成代码，判据假红（踩过五次，形态每次略不同）。
String _stripComments(String s) {
  var out = s.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  out = out.replaceAll(RegExp(r'//[^\n]*'), '');
  return out;
}

/// 可控 toString 的假异常：用来**逐字**复现真机日志的形态。
class _FakeErr implements Exception {
  _FakeErr(this._s);
  final String _s;
  @override
  String toString() => _s;
}

/// 用户实测的那条原串（逐字，仅把本机临时端口那段的粘连处规整为分隔符）。
const String _userCase =
    'ClientException with SocketException: No route to host '
    '(OS Error: No route to host, errno = 113), address = api.deepseek.com, '
    'uri=https://api.deepseek.com/chat/completions';

Future<void> main() async {
  if (!Directory('lib').existsSync()) {
    stderr.writeln('请在项目根目录运行（找不到 lib/）');
    print('PASS=0 FAIL=1');
    exitCode = 1;
    return;
  }

  print('== A. 用户实测原串（逐字）必须被判为网络层故障 ==');
  _okIf(NetDiagnosis.isNetworkError(_FakeErr(_userCase)),
      '原串 → isNetworkError');
  _okIf(NetDiagnosis.isUnreachable(_FakeErr(_userCase)),
      '原串 → isUnreachable（"到不了对端"）');
  _okIf(NetDiagnosis.retryDelayMs(_FakeErr(_userCase)) == 800,
      '原串 → 可重试（800ms）');

  print('== B. TimeoutException（既有的第三类判据） ==');
  _okIf(NetDiagnosis.isNetworkError(TimeoutException('t')),
      'TimeoutException → isNetworkError');
  _okIf(!NetDiagnosis.isUnreachable(TimeoutException('t')),
      'TimeoutException → 不算 "到不了对端"（是慢，不是没路）');

  print('== C. 同一族的其余形态 ==');
  _okIf(NetDiagnosis.isNetworkError(_FakeErr('SocketException: X')),
      'SocketException → 命中');
  _okIf(NetDiagnosis.isNetworkError(_FakeErr('ClientException: X')),
      'ClientException（只在外层）→ 命中');
  _okIf(NetDiagnosis.isNetworkError(_FakeErr('oops: Failed host lookup: a.com')),
      'Failed host lookup → 命中');
  _okIf(NetDiagnosis.isUnreachable(_FakeErr('Failed host lookup: a.com')),
      'Failed host lookup → 也算 "到不了对端"');
  _okIf(NetDiagnosis.isNetworkError(_FakeErr('Network is unreachable')),
      'ENETUNREACH → 命中');
  _okIf(NetDiagnosis.isNetworkError(_FakeErr('SocketException: Connection refused')),
      'Connection refused → 命中（网络层）');
  _okIf(!NetDiagnosis.isUnreachable(_FakeErr('Connection refused')),
      'Connection refused → 但**不算** "到不了对端"（有路由，只是没人听）');
  _okIf(NetDiagnosis.isNetworkError(_FakeErr('SOCKETEXCEPTION: X')),
      '大小写不敏感');

  print('== D. 负例：非网络故障一律不得误判 ==');
  for (final s in <String>[
    '',
    '   ',
    'FormatException: Unexpected character (at character 3)',
    'RangeError (index): Invalid value: Not in inclusive range',
    'null check operator used on a null value',
    '401 Unauthorized: invalid api key',
    '400 Bad Request: model not found',
    'room_too_fast',
    'PiiDetector: draft blocked',
    'StateError: Bad state: no element',
    'NoSuchMethodError: The getter x was called on null',
  ]) {
    _okIf(!NetDiagnosis.isNetworkError(_FakeErr(s)),
        '负例不误判: "$s"');
  }

  print('== E. 重试参数（只重一次 / 短退避） ==');
  _okIf(NetDiagnosis.maxRetries == 1, 'maxRetries == 1（不无限重试）');
  _okIf(NetDiagnosis.retryBackoffMs > 0 && NetDiagnosis.retryBackoffMs <= 2000,
      'retryBackoffMs 是"短退避"（0 < ms <= 2000）');
  _okIf(NetDiagnosis.retryDelayMs(_FakeErr('FormatException: x')) == 0,
      '非网络异常 → 不退避（0）');

  print('== F. withNetworkRetry 的语义 ==');
  // F1 非网络异常：不重试、立即抛、原样抛
  var calls = 0;
  Object? caught;
  try {
    await withNetworkRetry<int>(() async {
      calls++;
      throw _FakeErr('FormatException: planted');
    });
  } catch (e) {
    caught = e;
  }
  _okIf(calls == 1, 'F1 非网络异常**不重试**（calls==1）');
  _okIf(caught is _FakeErr, 'F1 非网络异常原样抛出（未被包装）');

  // F2 网络异常：重试一次并成功
  calls = 0;
  final v = await withNetworkRetry<int>(() async {
    calls++;
    if (calls == 1) throw _FakeErr('SocketException: Connection refused');
    return 42;
  });
  _okIf(calls == 2 && v == 42, 'F2 网络异常**重试一次**后成功（calls==2, v==42）');

  // F3 两次都失败：共 2 次，且抛的是**最后一次**的异常
  calls = 0;
  Object? last;
  try {
    await withNetworkRetry<int>(() async {
      calls++;
      throw _FakeErr('SocketException: attempt #$calls');
    });
  } catch (e) {
    last = e;
  }
  _okIf(calls == 2, 'F3 两次都失败：共尝试 2 次');
  _okIf(last.toString().contains('#2'), 'F3 抛出最后一次的异常（未被包装成新类型）');

  // F4 [P0] 降级链：`switchRoute` **未提供** ⇒ 第 2 次失败即如实抛出（不假装换路成功）
  calls = 0;
  Object? f4last;
  try {
    await withNetworkRetry<int>(
      () async {
        calls++;
        throw _FakeErr('SocketException: attempt #$calls');
      },
      switchRoute: null,
    );
  } catch (e) {
    f4last = e;
  }
  _okIf(calls == 2, 'F4[P0] 无换路能力 ⇒ 只试 2 次（绝不试第 3 次）');
  _okIf(f4last.toString().contains('#2'),
      'F4[P0] 无换路能力 ⇒ 抛出第 2 次的异常（不吞成假成功）');

  // F5 [P1 前瞻] 提供 `switchRoute` ⇒ 第 2 次失败后**恰好换路一次**再试
  //   这段是给 P1 的**预埋契约**：证明那个插槽真的能把"同路重试"升级成"换路重试"。
  calls = 0;
  var switches = 0;
  final v5 = await withNetworkRetry<int>(
    () async {
      calls++;
      if (calls <= 2) throw _FakeErr('SocketException: attempt #$calls');
      return 7;
    },
    switchRoute: () async {
      switches++;
    },
  );
  _okIf(calls == 3 && v5 == 7, 'F5[P1] 换路后第 3 次成功（calls==3, v5==7）');
  _okIf(switches == 1, 'F5[P1] 换路**恰好一次**（不反复切换）');

  print('== F2. 降级链 nextStep 的纯函数语义（三段 + 短路） ==');
  _okIf(
      NetDiagnosis.nextStep(_FakeErr('FormatException: x'), failuresSoFar: 1) ==
          NetFallbackStep.notNetwork,
      '非网络层 ⇒ notNetwork（不进链，立即抛）');
  _okIf(
      NetDiagnosis.nextStep(_FakeErr(_userCase), failuresSoFar: 1) ==
          NetFallbackStep.retrySameRoute,
      '网络层·第 1 次失败 ⇒ 同路再试（Wi-Fi）');
  _okIf(
      NetDiagnosis.nextStep(_FakeErr(_userCase), failuresSoFar: 2) ==
          NetFallbackStep.retryOtherRoute,
      '网络层·第 2 次失败 ⇒ 换路（蜂窝；P0 无此能力则如实降级）');
  _okIf(
      NetDiagnosis.nextStep(_FakeErr(_userCase), failuresSoFar: 3) ==
          NetFallbackStep.reportUnavailable,
      '网络层·第 3 次失败 ⇒ 如实提醒不可用');
  _okIf(NetDiagnosis.nextStep(_FakeErr(_userCase), failuresSoFar: 9) ==
          NetFallbackStep.reportUnavailable,
      '更多次失败 ⇒ 仍为 reportUnavailable（不无限换路）');
  _okIf(
      NetDiagnosis.nextStep(TimeoutException('t'), failuresSoFar: 2) ==
          NetFallbackStep.retryOtherRoute,
      'TimeoutException 也走降级链（同属网络层）');
  _okIf(NetDiagnosis.nextStep(_FakeErr('401 Unauthorized'), failuresSoFar: 5) ==
          NetFallbackStep.notNetwork,
      '鉴权错在任何次数下都短路（不因重试次数多而被当成网络问题）');

  print('== G. 扫描器自检（正控：先证明判据抓得到） ==');
  _okIf(_countOf(_stripComments('// NetDiagnosis.isNetworkError\nvar x=1;'),
          'NetDiagnosis.isNetworkError') == 0,
      '行注释里的名字**不算数**');
  _okIf(_countOf(_stripComments('/* NetDiagnosis.isNetworkError\n   续行 */var y=1;'),
          'NetDiagnosis.isNetworkError') == 0,
      '块注释**续行**也要剥掉');
  _okIf(_countOf(_stripComments('final a = NetDiagnosis.isNetworkError(e);'),
          'NetDiagnosis.isNetworkError') == 1,
      '真代码必须留下（不是把所有都剥光）');
  _okIf(_countOf(_stripComments('var s = "社交决策流水线异常";'), '社交决策流水线异常') == 1,
      '字符串字面量**不是**注释，必须留下');

  print('== H. 交付接线：三条路径共用一份判据 ==');
  final agentSrc = File('lib/core/agent_service.dart').readAsStringSync();
  final agent = _stripComments(agentSrc);
  // ★ 0.40.0：主动搭讪（evaluateAndProactiveMessage）也要计进熔断 ——
  //   它调的是同一个大模型，网络不通时同样一圈圈空烧 token，只是主人看不见"它在聊什么"。
  _okIf(_countOf(agent, 'NetDiagnosis.isNetworkError') == 3,
      'sendMessage + 私聊 catch + 主动搭讪 catch 共用判据（3 处）');
  _okIf(_countOf(agent, 'withNetworkRetry(') == 2,
      '主调用 + 重写各一次退避重试（2 处）');
  _okIf(_countOf(agent, 'netFaultLanHijackAdvice') == 1,
      '主人对话框文案走 ARB（1 处）');
  _okIf(_countOf(agent, 'netFaultSocialSkipped') == 1,
      '私聊网络失败文案走 ARB（1 处）');
  _okIf(_countOf(agent, 'netFaultNetworkTrouble') == 2,
      '[P0] "网络异常但非局域网"文案走 ARB（对话框 + 私聊各 1 处）');
  _okIf(_countOf(agent, 'NetDiagnosis.isUnreachable') == 2,
      '[P0] "到不了对端"细分判据在两条路径上都接上（2 处）');
  _okIf(_countOf(agent, 'switchRoute: null') == 2,
      '[P0] 两个 LLM 调用点**显式**声明无换路能力（2 处，P1 在此替换）');
  _okIf(_countOf(agent, 'socialPipelineError') == 1,
      '**非**网络错误仍报"流水线异常"（1 处，未被一起吞掉）');

  print('== H2. [0.40.0] 自激循环两层止血：日志分流 + 熔断 ==');
  // 症状（真机反馈）：两个智能体私聊时反复聊"网断了/网又来了"。
  // 根因是**自激循环**：失败 → 写日志 → 日志进 LLM 上下文 → 模型聊网络 → 再失败。
  // ① 分流：网络类日志改 action_type='infra'，且**不在**上下文白名单里；
  // ② 熔断：连续失败后不再调 LLM。两条缺一不可，故各钉一条。
  _okIf(_countOf(agent, "insertSocialLog(isNet ? 'infra' : 'system'") == 1,
      '[P0] 私聊网络日志按是否网络层分流到 infra（1 处）');
  _okIf(_countOf(agent, "insertSocialLog(\"infra\"") == 2,
      '[P0] 另两处投递/超时噪音也走 infra（2 处）');
  // ★ v0.44.0：上下文白名单**搬到了 SQL 侧** —— 私聊取数改走
  //   `DBHelper.getRecentChatLogs` 的 `action_type IN (...)`（评审 §二 P4 的修正：
  //   先取全类型 200 再在 Dart 侧筛，会让系统/基建日志把对话行挤出窗口）。
  //   判据随之迁移：钉 **SQL 白名单**含对话四类且**不含** infra，并钉 agent_service
  //   的取数**走的正是那个白名单化的方法**（白名单制，非黑名单）。
  final dbSrc = _stripComments(File('lib/core/db_helper.dart').readAsStringSync());
  final inIdx = dbSrc.indexOf('action_type IN');
  _okIf(inIdx >= 0, '[P0] DBHelper 里找得到 SQL 侧白名单（action_type IN）');
  final ctxTypes =
      inIdx < 0 ? '' : dbSrc.substring(inIdx, (inIdx + 160).clamp(0, dbSrc.length));
  _okIf(
      ctxTypes.contains("'send'") &&
          ctxTypes.contains("'send_manual'") &&
          ctxTypes.contains("'receive'") &&
          ctxTypes.contains("'system'") &&
          !ctxTypes.contains("'infra'"),
      "[P0] 上下文**白名单**含对话四类且**不含** infra（SQL 侧 IN，白名单制，非黑名单）");
  _okIf(_countOf(agent, 'getRecentChatLogs(') == 1,
      '[P0] 私聊取数走白名单化的 getRecentChatLogs（不再先取全类型再筛）');
  _okIf(_countOf(agent, '_netCoolingDown(') == 3,
      '[P0] 熔断闸在三条 LLM 路径前都设了卡（2 处调用 + 1 处定义）');
  _okIf(_countOf(agent, '_noteNetFailure(') == 3,
      '[P0] 失败计数在两处 catch + 一处定义都接上（3 处）');
  _okIf(_countOf(agent, '_noteNetSuccess(') == 3,
      '[P0] 成功清零同样是三条路径（2 处调用 + 1 处定义）');
  _okIf(_countOf(agent, 'netFaultCooldownSkipped') == 1,
      '[P0] 冷却期跳过说明走 ARB（1 处）');
  _okIf(_countOf(agent, '_netFailThreshold = 3') == 1 &&
          _countOf(agent, '_netCooldown = Duration(minutes: 10)') == 1,
      '[P0] 阈值与冷却时长在源码里可查（3 次 / 10 分钟）');
  // ★ 硬约束的另一半：光"不喂日志"不够，模型仍可能自己扯到网络
  _okIf(agentSrc.contains('绝对禁止谈论网络、连接、信号、掉线、超时、服务器'),
      '[P0] system prompt 有"绝不谈网络"的硬约束');

  print('== I. GONE：旧实现必须已消失 ==');
  _okIf(_countOf(agent, '夜间静默') == 0,
      '★ 夜间静默已整体取消（雷达与会客厅两条路径都不许再留）');
  _okIf(_countOf(agent, '社交决策流水线异常') == 0,
      '旧硬编码"流水线异常"已下沉 ARB');
  _okIf(_countOf(agent, "contains('SocketException')") == 0,
      '行内手写判据已抽走（不留第二份）');
  _okIf(_countOf(agent, '智能体自我诊断报告') == 0,
      '旧硬编码诊断文案已下沉 ARB');

  print('== J. 跨端契约：ARB ↔ 生成的 Dart ==');
  for (final f in <String>['lib/l10n/app_zh.arb', 'lib/l10n/app_en.arb']) {
    final s = File(f).readAsStringSync();
    _okIf(s.contains('"netFaultLanHijackAdvice"'), '$f 有 netFaultLanHijackAdvice');
    _okIf(s.contains('"netFaultSocialSkipped"'), '$f 有 netFaultSocialSkipped');
    _okIf(s.contains('"@netFaultSocialSkipped"'),
        '$f 声明了 netFaultSocialSkipped 的 {err} 占位符');
    _okIf(s.contains('"netFaultNetworkTrouble"'),
        '$f 有 netFaultNetworkTrouble（[P0] 新增）');
    _okIf(s.contains('"@netFaultNetworkTrouble"'),
        '$f 声明了 netFaultNetworkTrouble 的 {err} 占位符');
    _okIf(s.contains('"socialPipelineError"'), '$f 有 socialPipelineError');
    _okIf(s.contains('"@socialPipelineError"'),
        '$f 声明了 socialPipelineError 的 {err} 占位符');
    _okIf(s.contains('"netFaultCooldownSkipped"'),
        '$f 有 netFaultCooldownSkipped（[0.40.0] 熔断提示，无占位符）');
  }
  final gen = File('lib/l10n/app_localizations.dart').readAsStringSync();
  _okIf(gen.contains('String netFaultSocialSkipped(String err);'),
      '生成代码：netFaultSocialSkipped 是**带参**方法');
  _okIf(gen.contains('String get netFaultLanHijackAdvice;'),
      '生成代码：netFaultLanHijackAdvice 是**无参** getter');
  _okIf(gen.contains('String netFaultNetworkTrouble(String err);'),
      '生成代码：netFaultNetworkTrouble 是**带参**方法（[P0] 新增）');
  _okIf(gen.contains('String get netFaultCooldownSkipped;'),
      '生成代码：netFaultCooldownSkipped 是**无参** getter（[0.40.0] 熔断提示）');

  print('');
  if (_fail > 0) {
    print('--- 失败明细 ---');
    for (final f in _failures) {
      print('  • $f');
    }
    print('');
  }
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}

void _okIf(bool ok, String what) => ok ? _ok(what) : _bad(what);
