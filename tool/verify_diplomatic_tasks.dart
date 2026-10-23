// 纯 Dart 校验脚本：外交自由聊天"有目的、有营养、不误杀"三件套。
// 运行：dart run tool/verify_diplomatic_tasks.dart
//
// 为什么单独一个脚本：
//   2026-10-07 用户反馈 —— 主人不知道/懒得填「外交任务」时，分身带着**空指令**
//   进入自由聊天 ⇒ 只会"你好/在吗/哈哈"式空聊。本轮做了三件事：
//     ① 内置外交任务库（`lib/core/diplomatic_tasks.dart`）—— 空则自动补一条；
//     ② 修 PII 第一道闸的**裸 6 位数字**误杀（把价格/数量/编号全判成"邮编"）；
//     ③ 放宽 LLM 审核网关的提示词基调（默认放行，只拦真泄露）。
//   这三件事都属"编译通过但语义可能已经错了"，故用**行为断言 + 源码取证**钉住。
//
// 全部零依赖复算（不 import Flutter / DB）；源码取证剥注释（本项目正文会
// **刻意**引用被废弃的旧写法当反面教材，不剥会把说明文字当成本文件真的还在用，
// 与 `verify_persona_role.dart` / `verify_i18n.dart` 同一套办法）。

import 'dart:io';

import 'package:dahuang_ai/core/diplomatic_tasks.dart';
import 'package:dahuang_ai/core/persona_mode.dart';
import 'package:dahuang_ai/core/pii_detector.dart';

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

/// 剥掉注释再扫源码（见文件头说明）。
String _stripComments(String src) {
  final out = StringBuffer();
  var i = 0;
  final n = src.length;
  while (i < n) {
    final c = src[i];
    if (c == '/' && i + 1 < n && src[i + 1] == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) {
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

Future<void> main() async {
  // =========================================================================
  print('--- ① 任务库完备：每个模式都有池，每条都"可执行、不空洞"---');
  // =========================================================================
  check(DiplomaticTasks.pools.length == 5, '注册了 5 个模式的任务池');
  for (final m in PersonaModes.all) {
    check(DiplomaticTasks.pools.containsKey(m.id), '模式 ${m.id} 有任务池');
  }
  check(DiplomaticTasks.pools.values.every((p) => p.isNotEmpty), '每个池都非空');
  check(DiplomaticTasks.generic.isNotEmpty, '兜底池非空');
  // 任务要"像一句话、能执行"：至少 8 个字，且不含占位空话
  final all = DiplomaticTasks.allTasks;
  check(all.isNotEmpty, '任务库非空');
  check(all.every((t) => t.trim().length >= 8), '每条任务都有实质长度（>=8 字）');
  check(all.every((t) => !DiplomaticTasks.isBlank(t)), '池里不含占位空话（不会自我退化）');
  check(all.toSet().length == all.length, '任务库无完全重复项');

  // =========================================================================
  print('--- ② 确定性 pick：同一 (模式, 分身) 永远同一条（不抖）---');
  // =========================================================================
  check(DiplomaticTasks.pick('casual', seed: 'AG-1') ==
      DiplomaticTasks.pick('casual', seed: 'AG-1'),
      '同 seed 两次 pick 结果一致（确定性）');
  check(DiplomaticTasks.pools['casual']!.contains(
      DiplomaticTasks.pick('casual', seed: 'AG-1')), 'pick 落在该模式的池内');
  check(DiplomaticTasks.generic.contains(DiplomaticTasks.pick('__nope__')),
      '未知模式 → 从兜底池取（fail-safe，不返回空）');
  check(DiplomaticTasks.pick('casual', seed: '') ==
      DiplomaticTasks.pools['casual']!.first, 'seed 为空 → 按模式取池首条（稳定）');
  // 不同 seed 要能命中不同任务（证明不是写死一条）
  final spread = {
    for (var i = 0; i < 100; i++) DiplomaticTasks.pick('casual', seed: 'AG-$i')
  };
  check(spread.length >= 2, '不同分身能分到不同任务（命中 ${spread.length} 种）');

  // =========================================================================
  print('--- ③ effective：主人优先，空/占位空话才回落内置库 ---');
  // =========================================================================
  check(DiplomaticTasks.effective(
          mode: 'casual', stored: '帮我找铝合金供应商', agentId: 'AG-1') ==
      '帮我找铝合金供应商', '主人写了实质任务 → 原样使用（只补空，不覆盖）');
  final filled =
      DiplomaticTasks.effective(mode: 'casual', stored: '', agentId: 'AG-1');
  check(filled.isNotEmpty &&
          DiplomaticTasks.pools['casual']!.contains(filled),
      '留空 → 自动补一条 casual 内置任务');
  check(DiplomaticTasks.effective(
          mode: 'custom', stored: '自由交流', agentId: 'AG-1') !=
      '自由交流', '占位空话"自由交流" → 被替换（custom 历史默认值）');
  check(DiplomaticTasks.effective(
          mode: 'casual', stored: '无特定任务，自由友善交谈。', agentId: 'AG-1') !=
      '无特定任务，自由友善交谈。', '占位空话"无特定任务…" → 被替换（casual 历史默认值）');
  check(DiplomaticTasks.effective(mode: 'casual', stored: '   ', agentId: 'AG-1') ==
      filled, '纯空白 = 空（回落，且结果与空串一致）');
  check(DiplomaticTasks.generic.contains(DiplomaticTasks.effective(
      mode: '__nope__', stored: '', agentId: 'AG-1')), '未知模式 → 兜底池');
  check(DiplomaticTasks.effective(mode: 'casual', stored: '', agentId: 'AG-1') ==
      filled, 'effective 自身确定（同输入同输出）');

  // =========================================================================
  print('--- ④ isBlank：把"没任务"的几种写法都认出来 ---');
  // =========================================================================
  check(DiplomaticTasks.isBlank(null), 'null → 空');
  check(DiplomaticTasks.isBlank(''), '空串 → 空');
  check(DiplomaticTasks.isBlank('   '), '纯空白 → 空');
  check(DiplomaticTasks.isBlank('自由交流'), '"自由交流" → 空');
  check(DiplomaticTasks.isBlank('无特定任务，自由友善交谈。'), '"无特定任务…" → 空');
  check(!DiplomaticTasks.isBlank('向周边节点自我介绍并寻求业务资源'), '实质任务 → 非空');

  // =========================================================================
  print('--- ⑤ reroll：用户主动换 → 要变（与自动补空的确定性互补）---');
  // =========================================================================
  final cur = DiplomaticTasks.pools['casual']!.first;
  check(DiplomaticTasks.reroll('casual', avoid: cur) != cur,
      'reroll 会避开当前这条');
  check(DiplomaticTasks.pools['casual']!
      .contains(DiplomaticTasks.reroll('casual', avoid: cur)), 'reroll 仍在池内');
  final rr = {
    for (var i = 0; i < 30; i++)
      DiplomaticTasks.reroll('casual', avoid: cur)
  };
  check(rr.length >= 2, 'reroll 是随机的（30 次命中 ${rr.length} 种）');
  check(DiplomaticTasks.generic.contains(DiplomaticTasks.reroll('__nope__')),
      'reroll 未知模式 → 兜底池内取值（不崩）');
  check(DiplomaticTasks.reroll('casual', avoid: '不存在的任务').isNotEmpty,
      'avoid 不在池内时仍返回一条（不崩）');

  // =========================================================================
  print('--- ⑥ 零平台依赖（可 dart run 复算）---');
  // =========================================================================
  final libSrc = _stripComments(
      File('lib/core/diplomatic_tasks.dart').readAsStringSync());
  check(!libSrc.contains("import 'package:flutter"), '不 import Flutter');
  check(!libSrc.contains('shared_preferences'), '不 import SharedPreferences');
  check(!libSrc.contains('sqflite'), '不 import sqflite');
  check(libSrc.contains('library;'), '声明 library（与 persona_mode 同款）');

  // =========================================================================
  print('--- ⑦ 接线取证：任务库真的被用上（否则等于没写）---');
  // =========================================================================
  final agentSrc =
      _stripComments(File('lib/core/agent_service.dart').readAsStringSync());
  final socialSrc =
      _stripComments(File('lib/ui/social_screen.dart').readAsStringSync());
  check(agentSrc.contains('DiplomaticTasks.effective'),
      'agent_service 的密令任务走 effective()（空则自动补）');
  check(agentSrc.contains('taskSection'),
      'agent_service 已按模式决定是否重复注入任务（修 custom 双注入）');
  check(agentSrc.contains('modeAppendsTask'),
      'agent_service 识别 appendsTask（双注入修复的判据）');
  check(agentSrc.contains('【交流质量'),
      'agent_service 子智能体提示词含【交流质量】段（逼出有营养的发言）');
  check(socialSrc.contains('DiplomaticTasks.effective'),
      'social_screen 载入时分身任务走 effective()');
  check(socialSrc.contains('DiplomaticTasks.reroll'), 'social_screen 提供"换一个"');
  check(socialSrc.contains('_socialTaskFocus'), 'social_screen 有焦点守卫（不打断主人输入）');

  // =========================================================================
  print('--- ⑧ 审核误杀治理：PII 裸 6 位数字规则已移除 ---');
  // =========================================================================
  final piiSrc =
      _stripComments(File('lib/core/pii_detector.dart').readAsStringSync());
  check(!piiSrc.contains(r'[1-9]\d{5}(?!\d)'),
      '不再有"裸 6 位数字 = 邮编"的误杀规则（剥注释后）');
  check(piiSrc.contains('邮政编码') || piiSrc.contains('邮编'),
      '邮编检测改为"带标签前缀"（保住真检测）');
  // 行为断言（运行时，比源码 grep 更硬）
  check(PiiDetector.detect('报价 999999 元') == null, '价格 6 位数字不再误判');
  check(PiiDetector.detect('数量 123456 件') == null, '数量 6 位数字不再误判');
  check(PiiDetector.detect('邮编 100080') != null, '带标签的邮编仍然命中');
  // 红线仍在（只降误杀，不放松）
  check(PiiDetector.detect('电话 13812345678') != null, '手机号仍硬拦（红线未松）');
  check(PiiDetector.detect('身份证 110101199003074258') != null, '身份证仍硬拦');
  check(PiiDetector.detect('卡号 6222020200112233445') != null, '银行卡仍硬拦');

  // =========================================================================
  print('--- ⑨ 审核放宽：网关基调从"极其冷酷"改为"默认放行" ---');
  // =========================================================================
  check(!agentSrc.contains('极其冷酷'),
      '网关提示词不再有"极其冷酷"的过度拒绝基调（剥注释后）');
  check(agentSrc.contains('默认放行') || agentSrc.contains('一律放行'),
      '网关提示词改为"默认放行 + 窄拦截清单"');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
