// 会话压缩守卫（0.44.0 新增私聊 / 0.45.0 扩会客厅 + 自动回忆扩域）。
//
// 它钉住"分身 / 房间记住更早对话"这条链路的几个**静默失效点**，防止下一轮改动改回去：
//   ① **迁移/表没落地**：`schemaVersion` 必须等于 `_migrations` 最大键，且
//      `_migrateV35` 建 `peer_summaries`、`_migrateV36` 建 `room_summaries`
//      （少一处 = 真机 `no such table`）。
//   ② **过滤退回 Dart 侧**：`getRecentChatLogs` 必须在 **SQL 侧**用白名单
//      `action_type IN (...)` 过滤四类对话（评审 §二 P4）—— 退回"先取 200 再筛"
//      会让系统/基建日志把对话行挤出窗口。
//   ③ **摘要读写缺腿**：`getPeerSummary`/`upsertPeerSummary` 落在 `peer_summaries`、
//      `getRoomSummary`/`upsertRoomSummary` 落在 `room_summaries`（缺一条 = 摘要永远存不进）。
//   ④ **私聊压缩未接线**：`_getRecentChatContext` 必须走 `getRecentChatLogs` +
//      `getPeerSummary` + `_maybeCompactPeerChat`，且**不得**退回 `getRecentSocialLogs(`。
//   ⑤ **摘要器变成带工具的**：`_maybeCompactPeerChat` / `_maybeCompactRoomChat` 必须用
//      `_createTempAgent`（**无工具**辅助 Agent），且必须 try/catch 静默降级。
//   ⑥ **分身丢时间锚**：`_buildSubAgentPrompt` 必须含"当前时间"（评审 §1.2）。
//   ⑦ ★ **会客厅退回"全量渲染"**（0.45.0；评审 §次级问题 ⑥）：`_draftWorldRoomReply`
//      必须走 `_getRoomChatContext(`（滚动摘要 + 预算），**不得**再出现 `buf.writeln(`
//      —— 那是"把整个房间历史无预算塞进 prompt"的旧形态。
//   ⑧ ★ **自动回忆只接主聊天**（0.45.0）：`_augmentWithRecall` 必须支持对外护栏
//      `{String? guard}`，且私聊/会客厅路径必须真的调用它（`guard: _recallForeignGuard`
//      至少三处）—— 否则"回忆扩到私聊/会客厅"只是文档里的话。
//
// 源文本扫描型脚本必须带**自检（positive control）**：匹配式一坏就"扫到 0 处 → 恒绿"。
import 'dart:io';

int _pass = 0;
int _fail = 0;
void check(bool ok, String label) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    print('  FAIL: $label');
  }
}

String _read(String p) => File(p).readAsStringSync();

String _stripComments(String s) {
  final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
  return noBlock
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'//.*$'), ''))
      .join('\n');
}

/// 从 [src] 里截出以 [signatureStart] 开头的方法体 `{...}`（含花括号）。
/// 做法与 `verify_memory_context.dart` 一致：只认**括号深度 ≤ 0** 处的第一个 `{`，
/// 免得被命名参数的花括号（`({int a = 5})`）带偏。
String? _methodBody(String src, String signatureStart) {
  final i = src.indexOf(signatureStart);
  if (i < 0) return null;
  var parenDepth = 0;
  for (final ch in signatureStart.split('')) {
    if (ch == '(') {
      parenDepth++;
    } else if (ch == ')') {
      parenDepth--;
    }
  }
  final from = i + signatureStart.length;
  var brace = -1;
  for (var j = from; j < src.length; j++) {
    final c = src[j];
    if (c == '(') {
      parenDepth++;
    } else if (c == ')') {
      parenDepth--;
    } else if (c == '{' && parenDepth <= 0) {
      brace = j;
      break;
    }
  }
  if (brace < 0) return null;
  var depth = 0;
  for (var j = brace; j < src.length; j++) {
    final c = src[j];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return src.substring(brace, j + 1);
    }
  }
  return null;
}

const String _getChatLogsSig =
    'static Future<List<Map<String, dynamic>>> getRecentChatLogs(';
const String _getSummarySig =
    'static Future<Map<String, dynamic>?> getPeerSummary(';
const String _upsertSummarySig = 'static Future<void> upsertPeerSummary(';
const String _getRoomSummarySig =
    'static Future<Map<String, dynamic>?> getRoomSummary(';
const String _upsertRoomSummarySig = 'static Future<void> upsertRoomSummary(';
const String _getCtxSig = 'Future<String> _getRecentChatContext(';
const String _compactSig = 'Future<_PeerCompaction?> _maybeCompactPeerChat(';
const String _roomCtxSig = 'Future<String> _getRoomChatContext(';
const String _roomCompactSig =
    'Future<_RoomCompaction?> _maybeCompactRoomChat(';
const String _roomDraftSig = 'Future<String?> _draftWorldRoomReply(';
const String _subPromptSig = 'Future<String> _buildSubAgentPrompt(';
const String _migV35Sig = 'static Future<void> _migrateV35(';
const String _migV36Sig = 'static Future<void> _migrateV36(';

/// 解析 `_migrations` 的键（升序）。
List<int> _migrationKeys(String dbSrc) {
  final keys = <int>[];
  for (final m in RegExp(r'^\s*(\d+):\s*_migrateV', multiLine: true)
      .allMatches(dbSrc)) {
    keys.add(int.parse(m.group(1)!));
  }
  keys.sort();
  return keys;
}

int _count(String s, String sub) {
  var n = 0, i = 0;
  while (true) {
    final j = s.indexOf(sub, i);
    if (j < 0) break;
    n++;
    i = j + sub.length;
  }
  return n;
}

/// 判据（纯函数，供自检复用）。返回违反项列表（空 = 全过）。
List<String> judge({
  required String dbHelper,
  required String agentService,
}) {
  final bad = <String>[];

  // ① schemaVersion == 迁移表最大键；V35 建 peer_summaries、V36 建 room_summaries
  final verM = RegExp(r'schemaVersion\s*=\s*(\d+)').firstMatch(dbHelper);
  final keys = _migrationKeys(dbHelper);
  if (verM == null || keys.isEmpty) {
    bad.add('解析不到 schemaVersion / 迁移表');
  } else {
    final declared = int.parse(verM.group(1)!);
    if (declared != keys.last) {
      bad.add('schemaVersion($declared) != 迁移表最大键(${keys.last})');
    }
    if (!keys.contains(35)) bad.add('_migrations 未注册 35');
    if (!keys.contains(36)) bad.add('_migrations 未注册 36');
  }
  final mig35 = _methodBody(dbHelper, _migV35Sig);
  if (mig35 == null) {
    bad.add('_migrateV35 方法体找不到');
  } else if (!mig35.contains('peer_summaries')) {
    bad.add('_migrateV35 未建 peer_summaries');
  }
  final mig36 = _methodBody(dbHelper, _migV36Sig);
  if (mig36 == null) {
    bad.add('_migrateV36 方法体找不到');
  } else if (!mig36.contains('room_summaries')) {
    bad.add('_migrateV36 未建 room_summaries');
  }

  // ② getRecentChatLogs：SQL 侧白名单过滤四类
  final chat = _methodBody(dbHelper, _getChatLogsSig);
  if (chat == null) {
    bad.add('getRecentChatLogs 方法体找不到');
  } else {
    if (!chat.contains('action_type IN')) {
      bad.add('getRecentChatLogs 未在 SQL 侧按 action_type 过滤');
    }
    for (final t in const ['send', 'send_manual', 'receive', 'system']) {
      if (!chat.contains("'$t'")) bad.add('getRecentChatLogs 白名单缺 $t');
    }
  }

  // ③ 摘要读写必须真的落在各自的表
  final gs = _methodBody(dbHelper, _getSummarySig);
  if (gs == null) {
    bad.add('getPeerSummary 方法体找不到');
  } else if (!gs.contains('peer_summaries')) {
    bad.add('getPeerSummary 未查 peer_summaries');
  }
  final us = _methodBody(dbHelper, _upsertSummarySig);
  if (us == null) {
    bad.add('upsertPeerSummary 方法体找不到');
  } else if (!us.contains('peer_summaries')) {
    bad.add('upsertPeerSummary 未写 peer_summaries');
  }
  final grs = _methodBody(dbHelper, _getRoomSummarySig);
  if (grs == null) {
    bad.add('getRoomSummary 方法体找不到');
  } else if (!grs.contains('room_summaries')) {
    bad.add('getRoomSummary 未查 room_summaries');
  }
  final urs = _methodBody(dbHelper, _upsertRoomSummarySig);
  if (urs == null) {
    bad.add('upsertRoomSummary 方法体找不到');
  } else if (!urs.contains('room_summaries')) {
    bad.add('upsertRoomSummary 未写 room_summaries');
  }

  // ④ 私聊上下文接线：新取数 + 摘要 + 压缩；不得退回旧取数
  final ctx = _methodBody(agentService, _getCtxSig);
  if (ctx == null) {
    bad.add('_getRecentChatContext 方法体找不到');
  } else {
    if (!ctx.contains('getRecentChatLogs(')) {
      bad.add('_getRecentChatContext 未用 SQL 侧过滤的 getRecentChatLogs');
    }
    if (!ctx.contains('getPeerSummary(')) {
      bad.add('_getRecentChatContext 未读滚动摘要');
    }
    if (!ctx.contains('_maybeCompactPeerChat(')) {
      bad.add('_getRecentChatContext 未触发对话压缩');
    }
    if (ctx.contains('getRecentSocialLogs(')) {
      bad.add('_getRecentChatContext 退回旧取数 getRecentSocialLogs（§二 P4 被改回）');
    }
  }

  // ⑤ 摘要器必须无工具 + 静默降级（私聊 / 会客厅两份）
  final cmp = _methodBody(agentService, _compactSig);
  if (cmp == null) {
    bad.add('_maybeCompactPeerChat 方法体找不到');
  } else {
    if (!cmp.contains('_createTempAgent')) {
      bad.add('_maybeCompactPeerChat 未用无工具辅助 Agent');
    }
    if (!cmp.contains('upsertPeerSummary(')) {
      bad.add('_maybeCompactPeerChat 未落库摘要');
    }
    if (!cmp.contains('catch')) {
      bad.add('_maybeCompactPeerChat 未做静默降级（无 catch）');
    }
  }
  final rcmp = _methodBody(agentService, _roomCompactSig);
  if (rcmp == null) {
    bad.add('_maybeCompactRoomChat 方法体找不到');
  } else {
    if (!rcmp.contains('_createTempAgent')) {
      bad.add('_maybeCompactRoomChat 未用无工具辅助 Agent');
    }
    if (!rcmp.contains('upsertRoomSummary(')) {
      bad.add('_maybeCompactRoomChat 未落库摘要');
    }
    if (!rcmp.contains('catch')) {
      bad.add('_maybeCompactRoomChat 未做静默降级（无 catch）');
    }
  }

  // ⑥ 分身时间锚
  final sp = _methodBody(agentService, _subPromptSig);
  if (sp == null) {
    bad.add('_buildSubAgentPrompt 方法体找不到');
  } else if (!sp.contains('当前时间')) {
    bad.add('_buildSubAgentPrompt 缺"当前时间"（§1.2 回归）');
  }

  // ⑦ 会客厅上下文：滚动摘要 + 预算；不得退回"全量渲染"
  final rctx = _methodBody(agentService, _roomCtxSig);
  if (rctx == null) {
    bad.add('_getRoomChatContext 方法体找不到');
  } else {
    if (!rctx.contains('getRoomSummary(')) {
      bad.add('_getRoomChatContext 未读房间滚动摘要');
    }
    if (!rctx.contains('_maybeCompactRoomChat(')) {
      bad.add('_getRoomChatContext 未触发房间压缩');
    }
    if (!rctx.contains('maxChars')) {
      bad.add('_getRoomChatContext 未按预算裁剪（maxChars）');
    }
  }
  final rdr = _methodBody(agentService, _roomDraftSig);
  if (rdr == null) {
    bad.add('_draftWorldRoomReply 方法体找不到');
  } else {
    if (!rdr.contains('_getRoomChatContext(')) {
      bad.add('_draftWorldRoomReply 未走 _getRoomChatContext（会客厅未接压缩）');
    }
    if (rdr.contains('buf.writeln(')) {
      bad.add('_draftWorldRoomReply 退回"全量渲染"房间历史（评审 §次级问题 ⑥）');
    }
  }

  // ⑧ 自动回忆扩域：护栏 + 私聊/会客厅真的调用
  if (!agentService
      .contains('Future<String> _augmentWithRecall(String base, String query, '
          '{String? guard})')) {
    bad.add('_augmentWithRecall 未支持对外护栏 {String? guard}');
  }
  if (!agentService.contains('_recallForeignGuard')) {
    bad.add('缺 _recallForeignGuard（对外回忆护栏）');
  }
  final guardUses = _count(agentService, 'guard: _recallForeignGuard');
  if (guardUses < 4) {
    bad.add('自动回忆未扩到私聊/会客厅（护栏仅 $guardUses 处，应 ≥4：私聊/搭讪/重连/会客厅）');
  }

  return bad;
}

void main() {
  const dbPath = 'lib/core/db_helper.dart';
  const agentPath = 'lib/core/agent_service.dart';

  final dbHelper = _stripComments(_read(dbPath));
  final agentService = _stripComments(_read(agentPath));

  final bad = judge(dbHelper: dbHelper, agentService: agentService);

  check(dbHelper.length > 5000, 'DB 助手真被读到');
  check(agentService.length > 5000, '智能体服务真被读到');
  check(bad.isEmpty, '判据全过${bad.isEmpty ? '' : ' — 见下逐条'}');
  for (final b in bad) {
    print('    · $b');
  }

  // ── 方法体截取有效性（含"签名带花括号"这个曾踩的坑）──
  check(_methodBody('void f() { if (x) { y(); } }', 'void f()') == '{ if (x) { y(); } }',
      '方法体截取有效（嵌套花括号配平）');
  check(
      _methodBody('void f(String q, {int a = 5}) async { body; }', 'void f(') ==
          '{ body; }',
      '方法体截取有效（命名参数花括号不误判）');

  // ── ★ 自检（positive control）：改坏副本，每一处都必须被判出 ──
  // ★ 0.70.0 修订：反例构造不再硬编码 '37' —— 版本号每轮都会前进，
  //   写死会让 replaceFirst 替不中 ⇒ 反例构造悄悄失败 ⇒ 自检恒假红。
  //   改为动态提取当前声明版本号后替换。
  final declaredVerM =
      RegExp(r'schemaVersion\s*=\s*(\d+)').firstMatch(dbHelper);
  check(declaredVerM != null, '自检① 前置：schemaVersion 可解析');
  final declaredVer = declaredVerM?.group(1) ?? '0';
  final m1 = judge(
    dbHelper: dbHelper.replaceFirst(
        'schemaVersion = $declaredVer', 'schemaVersion = 99'),
    agentService: agentService,
  );
  check(m1.any((e) => e.contains('schemaVersion')), '自检①：版本号与迁移表不一致必须被判出');

  final chatBody = _methodBody(dbHelper, _getChatLogsSig);
  final m2 = judge(
    dbHelper: (chatBody == null)
        ? dbHelper
        : dbHelper.replaceFirst(chatBody, chatBody.replaceFirst("'receive'", "'rx'")),
    agentService: agentService,
  );
  check(m2.any((e) => e.contains('白名单缺 receive')),
      '自检②：白名单漏一类必须被判出');

  final m3 = judge(
    dbHelper: dbHelper,
    agentService: agentService.replaceFirst('getRecentChatLogs(', 'getRecentSocialLogs('),
  );
  check(m3.any((e) => e.contains('退回旧取数') || e.contains('未用 SQL 侧过滤')),
      '自检③：取数退回旧路径必须被判出');

  final cmpBody = _methodBody(agentService, _compactSig);
  final m4 = judge(
    dbHelper: dbHelper,
    agentService: (cmpBody == null)
        ? agentService
        : agentService.replaceFirst(cmpBody, cmpBody.replaceFirst('_createTempAgent', '_someAgent')),
  );
  check(m4.any((e) => e.contains('未用无工具辅助 Agent')),
      '自检④：摘要器变成可能带工具的必须被判出');

  final spBody = _methodBody(agentService, _subPromptSig);
  final m5 = judge(
    dbHelper: dbHelper,
    agentService: (spBody == null)
        ? agentService
        : agentService.replaceFirst(
            spBody, spBody.replaceFirst('当前时间', '时间')),
  );
  check(m5.any((e) => e.contains('缺"当前时间"')), '自检⑤：分身丢时间锚必须被判出');

  // 自检⑥：会客厅退回"全量渲染"必须被判出
  final rdrBody = _methodBody(agentService, _roomDraftSig);
  final m6 = judge(
    dbHelper: dbHelper,
    agentService: (rdrBody == null)
        ? agentService
        : agentService.replaceFirst(
            rdrBody, rdrBody.replaceFirst('final roomContext =', "buf.writeln('x');\n    final roomContext =")),
  );
  check(m6.any((e) => e.contains('全量渲染')), '自检⑥：会客厅退回全量渲染必须被判出');

  // 自检⑦：房间摘要读写被摘掉必须被判出
  final rctxBody = _methodBody(agentService, _roomCtxSig);
  final m7 = judge(
    dbHelper: dbHelper,
    agentService: (rctxBody == null)
        ? agentService
        : agentService.replaceFirst(rctxBody, rctxBody.replaceFirst('getRoomSummary(', 'x(')),
  );
  check(m7.any((e) => e.contains('未读房间滚动摘要')),
      '自检⑦：房间摘要未接线必须被判出');

  // 自检⑧：对外回忆护栏被摘掉（签名丢 guard）必须被判出
  final m8 = judge(
    dbHelper: dbHelper,
    agentService: agentService.replaceFirst(
        'Future<String> _augmentWithRecall(String base, String query, '
        '{String? guard})',
        'Future<String> _augmentWithRecall(String base, String query)'),
  );
  check(m8.any((e) => e.contains('未支持对外护栏')),
      '自检⑧：回忆护栏签名丢失必须被判出');

  // 自检⑨：回忆没扩到对外路径（护栏调用被删到只剩主聊天）必须被判出
  final m9 = judge(
    dbHelper: dbHelper,
    agentService: agentService.replaceAll('guard: _recallForeignGuard', 'guard: nullX'),
  );
  check(m9.any((e) => e.contains('未扩到私聊/会客厅')),
      '自检⑨：回忆未扩到对外路径必须被判出');

  // 自检⑩：V36 迁移漏建表必须被判出
  final mig36Body = _methodBody(dbHelper, _migV36Sig);
  final m10 = judge(
    dbHelper: (mig36Body == null)
        ? dbHelper
        : dbHelper.replaceFirst(mig36Body, mig36Body.replaceFirst('room_summaries', 'rooms')),
    agentService: agentService,
  );
  check(m10.any((e) => e.contains('未建 room_summaries')),
      '自检⑩：V36 漏建 room_summaries 必须被判出');

  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
