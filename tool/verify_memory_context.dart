// 记忆 / 上下文守卫（0.42.0 新增）。
//
// 它钉住四个**曾经真实存在、且症状静默**的缺陷，防止下一轮改动把它们改回去：
//   ① **回放记忆冻结**：`SqliteSessionStore.replay` 若回到"一律 ASC LIMIT 200"，
//      超 200 事件后最新消息永远进不了模型（"越聊越傻"，无报错）。
//   ② **检索域太窄**：`searchAllMemory` 必须同时查 messages / social_logs /
//      memory_events 三张表——少查一张，某类记忆就永远搜不到。
//   ③ **检索入口回退**：工具执行器与 ToolContext 注入必须走 `searchAllMemory`，
//      不许退回只查 messages 的 `searchMessages`。
//   ④ **私聊历史重新变裸**：私聊两处历史块必须仍包在 `_wrapUntrusted` 里，
//      否则对方在早前轮次埋的注入文本会以"可信历史"进入模型。
//   ⑤ **自动回忆装配残缺**（0.43.0）：`buildRecallBlock` 必须同时接"最近情景记忆"
//      与"模糊相关往事"两条腿，少一条就等于没回忆。
//   ⑥ **模糊回忆漏表**：`fuzzyRecallHits` 必须覆盖 messages / social_logs /
//      memory_events 三张表（与 `searchAllMemory` 同域）。
//   ⑦ **自动回忆未接线 / 变裸**：主聊天必须真的把回忆拼进系统提示词，且按
//      不可信输入包裹（回忆里可能夹着别的智能体写进 social_logs 的话）。
//
// 源文本扫描型脚本必须带**自检（positive control）**：匹配式一坏就"扫到 0 处 → 恒绿"。
// 故下面把判据抽成纯函数，并在末尾对**内存里被人为改坏的四份副本**各断言一次"必须被判出"。
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

/// 剥注释（行 + 块），**必须正确处理 Dart 字符串字面量**。
///
/// ★ 朴素写法 `replaceAll(RegExp('//.*\$'), '')` 会在**字符串内部的 `//`** 处
///   误砍整行 —— 例如 `if (kw.startsWith('memory://')) {` 会被砍成
///   `if (kw.startsWith('memory:`，**行尾的 `{` 一起消失** ⇒ 后续按花括号配平
///   截取方法体时提前收尾，判据② 就会假报"searchAllMemory 未查询三张表"。
///   0.77.0 引入记忆地址时真实踩到（当时本脚本正是朴素写法）。
///
/// 保留换行：删行注释时只删内容、不删换行，避免行号漂移影响排错。
String _stripComments(String s) {
  final out = StringBuffer();
  var i = 0;
  final n = s.length;
  while (i < n) {
    final c = s[i];
    // 块注释
    if (c == '/' && i + 1 < n && s[i + 1] == '*') {
      final j = s.indexOf('*/', i + 2);
      i = (j < 0) ? n : j + 2;
      out.write(' ');
      continue;
    }
    // 行注释
    if (c == '/' && i + 1 < n && s[i + 1] == '/') {
      final j = s.indexOf('\n', i);
      i = (j < 0) ? n : j;
      continue;
    }
    // 字符串字面量（支持 r'..' / r".." 前缀）
    final isRaw =
        c == 'r' && i + 1 < n && (s[i + 1] == "'" || s[i + 1] == '"');
    if (isRaw || c == "'" || c == '"') {
      final q = isRaw ? s[i + 1] : c;
      var j = isRaw ? i + 2 : i + 1;
      // ★ 引号本身要照抄回输出：很多判据锚点是 `'text LIKE ?'` 这种
      //   **含引号**的字面量，丢了引号守卫就会假红。
      if (isRaw) {
        out.write('r');
      }
      out.write(q);
      while (j < n) {
        final d = s[j];
        if (!isRaw && d == '\\') {
          out.write(s.substring(j, (j + 2 <= n) ? j + 2 : n));
          j += 2;
          continue;
        }
        if (d == q) {
          out.write(q);
          j++;
          break;
        }
        out.write(d);
        j++;
      }
      i = j;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// 从 [src] 里截出以 [signatureStart] 开头的方法体 `{...}`（含花括号）。
/// ★ 关键：从签名**末尾之后**才开始找**不在括号里**的第一个 `{` —— 否则
///   ① 带默认值参数的签名（`{int after = -1}`）、或
///   ② 签名只给到 `(` 的（如 `buildRecallBlock(` 后面的 `String q, {int a = 5}`）
///   里面的花括号会被误判成方法体开头。做法：先按 [signatureStart] 里的括号记账，
///   扫描时只有**括号深度 ≤ 0** 处的 `{` 才算方法体开头。
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

const String _searchAllSig = 'static Future<String> searchAllMemory(String keyword)';
const String _replaySig = 'replay(String id, {int after = -1})';
const String _recallSig = 'static Future<String> buildRecallBlock(';
const String _fuzzySig = 'static Future<List<_MemoryHit>> _fuzzyRecallHits(';
const String _augmentSig =
    'Future<String> _augmentWithRecall(String base, String query, {String? guard})';

// 私聊历史两处的"已包裹"正形态与"裸形态"负形态（均锚定在 `send(` 上，
// 避免负形态成为正形态的子串 —— 站点② 的包裹只包了内层字符串，曾因此误报）。
const String _chatWrapped1 = r'send("""${_wrapUntrusted(chatHistoryContext)}';
const String _chatWrapped2 = r"""send("${_wrapUntrusted('历史：$chatHistoryContext')}""";
const String _chatBare1 = r'send("""$chatHistoryContext';
const String _chatBare2 = r'send("历史：$chatHistoryContext';

/// 判据（纯函数，供自检复用）。返回违反项列表（空 = 全过）。
List<String> judge({
  required String sessionStore,
  required String dbHelper,
  required String agentService,
}) {
  final bad = <String>[];

  // ① replay 全量分支必须取最新（DESC）且保留增量（after >= 0）语义
  final replay = _methodBody(sessionStore, _replaySig);
  if (replay == null) {
    bad.add('replay 方法体找不到（签名变了？）');
  } else {
    if (!replay.contains("'id DESC'")) bad.add('replay 全量分支未取最新（缺 id DESC）');
    if (!replay.contains('after >= 0')) bad.add('replay 缺增量分支（after >= 0）');
  }

  // ② searchAllMemory 必须同查三张表
  final all = _methodBody(dbHelper, _searchAllSig);
  if (all == null) {
    bad.add('searchAllMemory 方法体找不到');
  } else {
    for (final t in const ['messages_fts', 'social_logs', 'memory_events']) {
      if (!all.contains(t)) bad.add('searchAllMemory 未查询 $t');
    }
  }

  // ③ 检索入口：工具执行器 + ToolContext 注入都必须走 searchAllMemory
  //
  // ⚠️ 判据必须**跨行**：0.78.0 给该分支加了"过不可信包裹"后，分支体被折成多行，
  //    按**单行**取会只拿到 `else if (content == 'BUILTIN_SEARCH_MEMORY') {` ⇒ 误报
  //    "未走 searchAllMemory"（本脚本 0.78.0 真踩过，与 §5「折行误杀」同族）。
  final iMem = agentService.indexOf('BUILTIN_SEARCH_MEMORY');
  if (iMem < 0) {
    bad.add('找不到 BUILTIN_SEARCH_MEMORY 执行器');
  } else {
    final win = agentService.substring(
        iMem, (iMem + 600).clamp(0, agentService.length));
    if (!win.contains('searchAllMemory')) {
      bad.add('BUILTIN_SEARCH_MEMORY 未走 searchAllMemory');
    }
    if (win.contains('searchMessages(')) {
      bad.add('BUILTIN_SEARCH_MEMORY 仍调用旧 searchMessages');
    }
  }
  if (!agentService.contains('searchMemory: DBHelper.searchAllMemory')) {
    bad.add('ToolContext.searchMemory 未注入 searchAllMemory');
  }

  // ④ 私聊两处历史必须仍被包裹；不得出现裸形态
  if (!agentService.contains(_chatWrapped1)) bad.add('私聊历史①未按不可信输入包裹');
  if (!agentService.contains(_chatWrapped2)) bad.add('私聊历史②未按不可信输入包裹');
  if (agentService.contains(_chatBare1)) bad.add('私聊历史①出现裸形态');
  if (agentService.contains(_chatBare2)) bad.add('私聊历史②出现裸形态');

  // ⑤ 自动回忆装配：buildRecallBlock 必须同时接"最近情景记忆"与"模糊相关往事"
  final recall = _methodBody(dbHelper, _recallSig);
  if (recall == null) {
    bad.add('buildRecallBlock 方法体找不到');
  } else {
    if (!recall.contains('getMemoryEvents')) {
      bad.add('buildRecallBlock 未取最近情景记忆');
    }
    if (!recall.contains('fuzzyRecallHits')) {
      bad.add('buildRecallBlock 未做相关往事检索');
    }
  }

  // ⑥ 模糊回忆必须覆盖三张表（与 searchAllMemory 同域）
  final fuzzy = _methodBody(dbHelper, _fuzzySig);
  if (fuzzy == null) {
    bad.add('fuzzyRecallHits 方法体找不到');
  } else {
    for (final t in const ['messages', 'social_logs', 'memory_events']) {
      if (!fuzzy.contains(t)) bad.add('fuzzyRecallHits 未查询 $t');
    }
  }

  // ⑦ 主聊天必须真的注入，且按不可信输入包裹
  final augment = _methodBody(agentService, _augmentSig);
  if (augment == null) {
    bad.add('_augmentWithRecall 方法体找不到');
  } else {
    if (!augment.contains('buildRecallBlock(')) {
      bad.add('_augmentWithRecall 未调用 buildRecallBlock');
    }
    if (!augment.contains('_wrapUntrusted(')) {
      bad.add('_augmentWithRecall 未按不可信输入包裹回忆');
    }
  }
  if (!agentService.contains('_augmentWithRecall(dynamicSystemPrompt')) {
    bad.add('sendMessage 未接入自动回忆');
  }

  return bad;
}

void main() {
  const sessionPath = 'lib/harness_host/sqlite_session_store.dart';
  const dbPath = 'lib/core/db_helper.dart';
  const agentPath = 'lib/core/agent_service.dart';

  final sessionStore = _stripComments(_read(sessionPath));
  final dbHelper = _stripComments(_read(dbPath));
  final agentService = _stripComments(_read(agentPath));

  final bad = judge(
    sessionStore: sessionStore,
    dbHelper: dbHelper,
    agentService: agentService,
  );

  // ── 正向断言 ──
  check(sessionStore.length > 500, '会话存储真被读到');
  check(dbHelper.length > 5000, 'DB 助手真被读到');
  check(agentService.length > 5000, '智能体服务真被读到');
  check(bad.isEmpty, '判据全过${bad.isEmpty ? '' : ' — 见下逐条'}');
  for (final b in bad) {
    print('    · $b');
  }

  // ── 方法体截取有效性（含"签名带花括号"这个曾踩的坑）──
  check(_methodBody('void f() { if (x) { y(); } }', 'void f()') == '{ if (x) { y(); } }',
      '方法体截取有效（嵌套花括号配平）');
  check(_methodBody('void f({int a = -1}) async { body; }', 'void f({int a = -1})') == '{ body; }',
      '方法体截取有效（签名自带花括号不误判）');
  check(
      _methodBody('void f(String q, {int a = 5}) async { body; }', 'void f(') ==
          '{ body; }',
      '方法体截取有效（签名只给到 `(` 也不被命名参数花括号带偏）');
  check(_methodBody('void f() {}', 'void g()') == null, '找不到签名返回 null');

  // ── ★ 自检（positive control）：改坏四份副本，每份都必须被判出 ──
  final m1 = judge(
    sessionStore: sessionStore.replaceFirst("'id DESC'", "'id ASC'"),
    dbHelper: dbHelper,
    agentService: agentService,
  );
  check(m1.any((e) => e.contains('未取最新')), '自检①：replay 退回 ASC 必须被判出');

  final allBody = _methodBody(dbHelper, _searchAllSig);
  final dbMut = (allBody == null)
      ? dbHelper
      : dbHelper.replaceFirst(
          allBody, allBody.replaceFirst("'memory_events'", "'mem_evts_x'"));
  final m2 = judge(
    sessionStore: sessionStore,
    dbHelper: dbMut,
    agentService: agentService,
  );
  check(m2.any((e) => e.contains('memory_events')), '自检②：漏查 memory_events 必须被判出');

  final m3 = judge(
    sessionStore: sessionStore,
    dbHelper: dbHelper,
    agentService: agentService.replaceFirst(
        'DBHelper.searchAllMemory((arguments', 'DBHelper.searchMessages((arguments'),
  );
  check(m3.any((e) => e.contains('未走 searchAllMemory')), '自检③：检索入口回退必须被判出');

  final m4 = judge(
    sessionStore: sessionStore,
    dbHelper: dbHelper,
    agentService: agentService.replaceFirst(_chatWrapped1, _chatBare1),
  );
  check(m4.any((e) => e.contains('裸形态') || e.contains('未按不可信输入包裹')),
      '自检④：私聊历史重新变裸必须被判出');

  // ⑤⑥⑦⑧：0.43.0 自动回忆装配
  final recallBody = _methodBody(dbHelper, _recallSig);
  final m5 = judge(
    sessionStore: sessionStore,
    dbHelper: (recallBody == null)
        ? dbHelper
        : dbHelper.replaceFirst(recallBody,
            recallBody.replaceFirst('getMemoryEvents', 'getMemEvtsX')),
    agentService: agentService,
  );
  check(m5.any((e) => e.contains('未取最近情景记忆')),
      '自检⑤：回忆不含最近情景记忆必须被判出');

  final fuzzyBody = _methodBody(dbHelper, _fuzzySig);
  final m6 = judge(
    sessionStore: sessionStore,
    dbHelper: (fuzzyBody == null)
        ? dbHelper
        : dbHelper.replaceFirst(fuzzyBody,
            fuzzyBody.replaceFirst("'memory_events'", "'mem_evts_x'")),
    agentService: agentService,
  );
  check(m6.any((e) => e.contains('fuzzyRecallHits 未查询 memory_events')),
      '自检⑥：模糊回忆漏表必须被判出');

  final m7 = judge(
    sessionStore: sessionStore,
    dbHelper: dbHelper,
    agentService: agentService.replaceFirst(
        '_augmentWithRecall(dynamicSystemPrompt', 'dynamicSystemPrompt_asis_'),
  );
  check(m7.any((e) => e.contains('未接入自动回忆')),
      '自检⑦：自动回忆未接线必须被判出');

  final augmentBody = _methodBody(agentService, _augmentSig);
  final m8 = judge(
    sessionStore: sessionStore,
    dbHelper: dbHelper,
    agentService: (augmentBody == null)
        ? agentService
        : agentService.replaceFirst(
            augmentBody, augmentBody.replaceAll('_wrapUntrusted(', '_wrapX(')),
  );
  check(m8.any((e) => e.contains('未按不可信输入包裹回忆')),
      '自检⑧：回忆变裸必须被判出');

  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
