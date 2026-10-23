// 记忆地址 / 中文检索 / 相关度排序 守卫（0.77.0 新增）。
//
// 它钉住六个**症状静默**的缺陷，防止下一轮改动把它们改回去：
//   ① 记忆地址不下发：`buildRecallBlock` 两条腿 + `searchAllMemory` 都必须带
//      `memory://<ns>/<id>`，否则模型只能复述文本，无法定点引用/删除/去重。
//   ② 地址不可兑现：`resolveMemoryAddress` 的 ns→表 映射必须与 `_MemoryHit`
//      实际使用的 ns 取值一一对应，否则地址是死字符串（看着有用实则无用）。
//   ③ FTS5 静默降级（★ 本轮实证抓到的真 bug）：对 `messages_fts` 的 SELECT
//      只能取它自己声明的列，元数据必须 JOIN 回 `messages`。写成直选
//      isUser/timestamp 会**每次**抛 `no such column` 并被 catch 吞掉
//      ⇒ 索引只写不读，且没有任何报错。
//   ④ 中文兜底被"优化"掉：FTS5 默认 `unicode61` 把整串中文切成一个 token
//      （"我喜欢喝咖啡" → `['我喜欢喝咖啡']`），`MATCH '咖啡'` 命中不了它；
//      `trigram` 能切但要 SQLite≥3.34，Android 平台版无保障 ⇒ LIKE 不可删。
//   ⑤ 排序丢 tiebreaker：Dart 的 `List.sort` **不稳定**，同分条目必须靠
//      ns + id 兜底，否则同一句话的回忆每次顺序都可能不同（不可复现）。
//   ⑥ 半衰期与画像口径不一致：`_recallHalfLifeDays` 必须等于
//      `UserProfileStore.defaultHalfLifeDays`，否则同一件事在回忆里比在
//      画像里衰减得更快，两套时间观打架。
//   ⑦ **地址只是打印、模型不知道能用**（0.78.0）：地址若只进回忆块而无说明书，
//      模型看到的是"行首一串看不懂的前缀" ⇒ 等于死代码。工具描述须含 `memory://`
//      用法 + **开库收敛**（老库播种行不会更新）+ 回忆块两条腿标题都点明用法。
//   ⑧ 检索结果**未过不可信包裹**（0.78.0）：结果含第三方（social_logs 里别的
//      智能体的话）⇒ 工具分支必须 `_wrapUntrusted`。
//   ⑨ **全仓级**禁止"直选 messages_fts 未声明列"，且死代码 `searchMessagesSmart`
//      不得复活（同款缺陷）。
//   ⑩ 打分的噪声片段（含功能字的二元组）须被过滤；检索结果须有总长上限。
//   ⑪ KB `memory` 条目须回归**用户语言**（不得出现 `memory://` / 算法参数）。
//
// 源文本扫描型脚本必须带**自检（positive control）**：匹配式一坏就"扫到 0 处 → 恒绿"。
// 故下面把判据抽成纯函数，并在末尾对**内存里被人为改坏的若干份副本**各断言一次"必须被判出"。
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

/// 剥注释（行 + 块），**正确处理 Dart 字符串字面量**。
///
/// ★ 必须用真正的扫描器，而不是 `replaceAll(RegExp('//.*\$'),'')` 这类朴素正则：
///   源码里存在 `'memory://episode/12'` 这种**字符串内部自带 `//`** 的写法，
///   朴素正则会从 `//` 处把字符串砍断 ⇒ 守卫锚点凭空消失，判据真假难辨
///   （这是"先剥注释再断言"这条纪律自带的隐藏陷阱，本文件第一版就踩了）。
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
    final isRaw = c == 'r' &&
        i + 1 < n &&
        (s[i + 1] == "'" || s[i + 1] == '"');
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
///   带默认值参数的签名（`{int after = -1}`）里的花括号会被误判成方法体开头。
///   做法：先按 [signatureStart] 里的括号记账，扫描时只有**括号深度 ≤ 0** 处的
///   `{` 才算方法体开头。
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

/// 取出 `call(` 之后的第一实参，且它必须是**字符串字面量**。
///
/// Dart 里相邻字符串字面量会自动拼接（`'a'  'b'` == `'ab'`），SQL 又普遍写成
/// 跨行拼接的形式 ⇒ 这里把相邻的字面量**拼成一个**返回，才能按 SQL 结构断言。
/// 非字符串（比如变量、插值整体）返回 `null`，让守卫报红而不是静默放过。
String? _firstStringArg(String src, String call) {
  final i = src.indexOf('$call(');
  if (i < 0) return null;
  var j = i + call.length + 1;
  final sb = StringBuffer();
  var got = false;
  while (j < src.length) {
    // 跳过空白（含换行与缩进）
    while (j < src.length &&
        (src[j] == ' ' || src[j] == '\n' || src[j] == '\t' || src[j] == '\r')) {
      j++;
    }
    if (j >= src.length) break;
    final c = src[j];
    final isRaw = c == 'r' &&
        j + 1 < src.length &&
        (src[j + 1] == "'" || src[j + 1] == '"');
    if (!isRaw && c != "'" && c != '"') break; // 形态变了 ⇒ 交回上层报红
    final q = isRaw ? src[j + 1] : c;
    var k = isRaw ? j + 2 : j + 1;
    while (k < src.length) {
      final d = src[k];
      if (!isRaw && d == '\\') {
        sb.write(src.substring(k, (k + 2 <= src.length) ? k + 2 : src.length));
        k += 2;
        continue;
      }
      if (d == q) {
        k++;
        break;
      }
      sb.write(d);
      k++;
    }
    got = true;
    j = k;
  }
  return got ? sb.toString() : null;
}

const String _searchAllSig =
    'static Future<String> searchAllMemory(String keyword)';
const String _recallSig = 'static Future<String> buildRecallBlock(';
const String _fuzzySig = 'static Future<List<_MemoryHit>> _fuzzyRecallHits(';
const String _resolveSig =
    'static Future<Map<String, dynamic>?> resolveMemoryAddress(';
const String _hitClass = 'class _MemoryHit';

/// 判据③：FTS5 查询的 SELECT 列表里，每个列表达式必须是
/// `messages_fts` **自己声明的列**，或是 `m.` 前缀（JOIN 回主表取的元数据）。
///
/// 独立成函数是为了避免嵌套过深 —— 嵌套一深，花括号就配不平（本文件就踩过）。
/// [all] 为 `searchAllMemory` 方法体（已剥注释），[dbHelper] 为整个文件源文本。
List<String> judgeFtsQuery(String all, String dbHelper) {
  final bad = <String>[];

  if (!all.contains('JOIN messages m ON m.id = f.rowid')) {
    bad.add('messages_fts 查询未 JOIN 回 messages 取元数据');
  }

  // 动态解析 DDL 声明列 —— 不写死，DDL 改了守卫自动跟着改。
  // ⚠️ 不能写成 `messages_fts USING fts5\(` 这种正则：DDL 是**跨行的相邻
  //    字符串字面量**拼接的（`'... messages_fts '` 换行 `'USING fts5(...'`），
  //    两个片段之间隔着引号和缩进 ⇒ 正则永远匹配不到（第一版就踩了）。
  final iFts = dbHelper.indexOf('messages_fts');
  if (iFts < 0) {
    bad.add('找不到 messages_fts 的 DDL（签名变了？）');
    return bad;
  }
  final ddl = RegExp(r'fts5\(([^)]*)\)').firstMatch(dbHelper.substring(iFts));
  final declared = <String>{};
  if (ddl == null) {
    bad.add('找不到 messages_fts 的 fts5 DDL（签名变了？）');
    return bad;
  }
  for (final p in ddl.group(1)!.split(',')) {
    final t = p.trim();
    if (t.startsWith('content=') ||
        t.startsWith('content_rowid=') ||
        t.startsWith('tokenize=') ||
        t.startsWith('prefix=')) {
      continue;
    }
    if (t.isNotEmpty) {
      declared.add(t);
    }
  }
  if (declared.isEmpty) {
    bad.add('messages_fts DDL 解析出 0 个声明列');
    return bad;
  }

  final sql = _firstStringArg(all, 'rawQuery');
  if (sql == null) {
    bad.add('searchAllMemory 里找不到 messages_fts 的 rawQuery 字符串实参');
    return bad;
  }

  final iFrom = sql.toUpperCase().indexOf(' FROM ');
  if (iFrom < 0) {
    bad.add('messages_fts 查询解析不出 FROM（SQL 结构变了？）');
    return bad;
  }

  for (final c0 in sql.substring(0, iFrom).split(',')) {
    final c = c0.trim();
    if (c.isEmpty) {
      continue;
    }
    final head =
        c.toUpperCase().startsWith('SELECT') ? c.substring(6).trim() : c;
    if (head.startsWith('m.')) {
      continue; // 主表别名，允许
    }
    if (declared.contains(head)) {
      continue; // FTS5 已声明的列，允许
    }
    bad.add('messages_fts 查询直选了未声明列 `$head`'
        '（会抛 no such column 并被静默降级为 LIKE）');
  }
  return bad;
}

/// 判据（纯函数，供自检复用）。返回违反项列表（空 = 全过）。
///
/// [dbHelper] 为**已剥注释**的 `db_helper.dart` 源文本；
/// [dbRaw] 为**未剥注释**的原始源文本（用于检查"为什么这么写"的说明还在不在）；
/// [profileRaw] 为 `user_profile_store.dart` 原始源文本（跨文件数值一致性）。
List<String> judge({
  required String dbHelper,
  required String dbRaw,
  required String profileRaw,
}) {
  final bad = <String>[];

  // ---------- ① 记忆地址必须随每条回忆下发 ----------
  final recall = _methodBody(dbHelper, _recallSig);
  if (recall == null) {
    bad.add('buildRecallBlock 方法体找不到（签名变了？）');
  } else {
    if (!recall.contains('memory://episode/')) {
      bad.add('buildRecallBlock 腿①（最近情景记忆）未带记忆地址');
    }
    if (!recall.contains('h.memoryAddress')) {
      bad.add('buildRecallBlock 腿②（相关往事）未带记忆地址');
    }
  }

  final all = _methodBody(dbHelper, _searchAllSig);
  if (all == null) {
    bad.add('searchAllMemory 方法体找不到（签名变了？）');
  } else {
    if (!all.contains('h.memoryAddress')) {
      bad.add('searchAllMemory 结果未带记忆地址');
    }
  }

  // ---------- ② 地址必须可兑现 ----------
  final hit = _methodBody(dbHelper, _hitClass);
  if (hit == null) {
    bad.add('_MemoryHit 类体找不到');
  } else {
    if (!hit.contains('final String ns')) {
      bad.add('_MemoryHit 缺 ns 字段');
    }
    if (!hit.contains('final int id')) {
      bad.add('_MemoryHit 缺 id 字段');
    }
    if (!hit.contains(r'memory://$ns/$id')) {
      bad.add('_MemoryHit 缺 memoryAddress（或形态不符）');
    }
    if (!hit.contains('final int matchCount')) {
      bad.add('_MemoryHit 缺 matchCount（排序信号没了 ⇒ 回忆退回纯时间序）');
    }
  }

  final resolve = _methodBody(dbHelper, _resolveSig);
  if (resolve == null) {
    bad.add('resolveMemoryAddress 找不到（地址无法兑现）');
  } else {
    if (!resolve.contains('_memoryNamespaceTables')) {
      bad.add('resolveMemoryAddress 未走命名空间映射表（ns 与表可能失配）');
    }
    if (!resolve.contains(r'^memory://([a-z_]+)/(\d+)$')) {
      bad.add('resolveMemoryAddress 地址正则不符');
    }
  }

  // ns 取值 ↔ 表名映射三对齐全（改一处就要改另一处）
  for (final e in const <String>[
    "'chat': 'messages'",
    "'social': 'social_logs'",
    "'episode': 'memory_events'",
  ]) {
    if (!dbHelper.contains(e)) {
      bad.add('记忆命名空间映射缺 $e');
    }
  }

  // ---------- ③ FTS5 查询不得直选未声明列 ----------
  if (all != null) {
    bad.addAll(judgeFtsQuery(all, dbHelper));
  }

  // ---------- ④ 中文兜底（LIKE）不得删 ----------
  if (all != null && !all.contains("'text LIKE ?'")) {
    bad.add('messages 的 LIKE 兜底被删：unicode61 切不动中文，'
        'MATCH 会漏掉所有中文子串命中');
  }
  // 说明必须还在（否则下一个人会以为这是冗余代码再删一次）
  if (!dbRaw.contains('unicode61')) {
    bad.add('缺少"为何保留 LIKE 兜底"的说明（unicode61 切不动中文）');
  }

  // ---------- ⑤ 排序必须带 ns + id 兜底 ----------
  final fuzzy = _methodBody(dbHelper, _fuzzySig);
  if (fuzzy == null) {
    bad.add('fuzzyRecallHits 方法体找不到');
  } else {
    if (!fuzzy.contains('_recallScore(')) {
      bad.add('fuzzyRecallHits 未用 _recallScore 排序（退回纯时间序）');
    }
    final iSort = fuzzy.indexOf('hits.sort');
    if (iSort < 0) {
      bad.add('fuzzyRecallHits 里找不到 hits.sort');
    } else {
      final iEnd = fuzzy.indexOf('});', iSort);
      final cmp = fuzzy.substring(iSort, iEnd < 0 ? fuzzy.length : iEnd + 3);
      if (!cmp.contains('a.ns.compareTo(b.ns)') ||
          !cmp.contains('b.id.compareTo(a.id)')) {
        bad.add('hits.sort 比较器缺 ns/id 兜底：'
            'Dart 的 List.sort 不稳定，同分条目次序随机 ⇒ 回忆不可复现');
      }
    }
  }

  // ---------- ⑥ 半衰期跨文件一致（回忆 vs 画像）----------
  final recallHl =
      RegExp(r'_recallHalfLifeDays\s*=\s*([\d.]+)').firstMatch(dbHelper);
  final profileHl =
      RegExp(r'defaultHalfLifeDays\s*=\s*(\d+)').firstMatch(profileRaw);
  if (recallHl == null) {
    bad.add('db_helper 里找不到 _recallHalfLifeDays');
  } else if (profileHl == null) {
    bad.add('user_profile_store 里找不到 defaultHalfLifeDays');
  } else {
    final a = double.tryParse(recallHl.group(1)!);
    final b = double.tryParse(profileHl.group(1)!);
    if (a == null || b == null || (a - b).abs() > 1e-9) {
      bad.add('回忆半衰期($a) 与画像半衰期($b) 不一致');
    }
  }

  return bad;
}


/// 判据 ⑦⑧⑨⑩：地址接线 / 不可信包裹 / 全仓 FTS5 / 打分噪声与长度上限。
List<String> judgeToolWiring({
  required String dbHelper,
  required String dbRaw,
  required String agentService,
}) {
  final bad = <String>[];

  // ⑦ 工具描述必须含 memory:// 地址用法（播种与收敛共用常量）
  if (!dbRaw.contains('_searchMemoryToolDescription')) {
    bad.add('内置工具描述未走常量 _searchMemoryToolDescription（播种/收敛会漂移）');
  }
  if (!dbRaw.contains('memory://<命名空间>/<行号>')) {
    bad.add('工具描述未含 memory:// 地址用法（模型仍不知道地址可用）');
  }
  // ⑦b 开库收敛（治"老库播种行永不更新"）
  if (!dbHelper.contains('healBuiltinToolDescriptions')) {
    bad.add('缺少开库收敛 healBuiltinToolDescriptions（老库描述永不更新）');
  }
  if (!dbHelper.contains('UPDATE tools SET description')) {
    bad.add('开库收敛未 UPDATE 工具描述列');
  }
  if (!dbHelper.contains('healBuiltinToolDescriptions(db);')) {
    bad.add('migrate() 尾部未调用开库收敛');
  }
  if (!dbHelper.contains('onOpen: (Database db) => healBuiltinToolDescriptions(db)')) {
    bad.add('_initDB 未挂 onOpen 收敛（"已是最新版"这条路径覆盖不到）');
  }

  // ⑧ 回忆块两条腿标题都说明地址用法
  final recall = _methodBody(dbHelper, _recallSig);
  if (recall == null) {
    bad.add('buildRecallBlock 方法体找不到（签名变了？）');
  } else {
    final n =
        RegExp('原样传给 search_historical_memory').allMatches(recall).length;
    if (n < 2) {
      bad.add('回忆块两条腿未都说明 memory:// 地址用法（命中 $n < 2）');
    }
  }

  // ⑨ 工具分支结果必须过不可信包裹（含第三方 social 内容）
  final iMem = agentService.indexOf('BUILTIN_SEARCH_MEMORY');
  if (iMem < 0) {
    bad.add('找不到 BUILTIN_SEARCH_MEMORY 分支');
  } else {
    final win =
        agentService.substring(iMem, (iMem + 600).clamp(0, agentService.length));
    if (!win.contains('searchAllMemory')) {
      bad.add('BUILTIN_SEARCH_MEMORY 未走 searchAllMemory');
    }
    if (!win.contains('_wrapUntrusted(')) {
      bad.add('BUILTIN_SEARCH_MEMORY 结果未按不可信输入包裹（第三方文本会进上下文）');
    }
  }

  // ⑨b 全仓级：禁止"直选 messages_fts 未声明列" + 死代码复活
  if (dbHelper.contains('FROM messages_fts WHERE')) {
    bad.add('全仓仍有"直选 messages_fts 未声明列"的写法（会静默降级为 LIKE）');
  }
  if (!dbHelper.contains('JOIN messages m ON m.id = f.rowid')) {
    bad.add('全仓找不到 FTS5 的 JOIN 取元数据写法（被改回直选了？）');
  }
  if (dbHelper.contains('searchMessagesSmart')) {
    bad.add('死代码 searchMessagesSmart 复活（同款直选缺陷）');
  }

  // ⑩ 打分噪声过滤 + 输出总长上限
  if (!dbHelper.contains('_recallStopChars')) {
    bad.add('extractRecallKeywords 缺功能字过滤（噪声片段会抬分、挤掉实词）');
  }
  if (!dbHelper.contains('_containsRecallStopChar(gram)')) {
    bad.add('二元组未按功能字过滤');
  }
  if (!dbHelper.contains('_capMemoryOutput(')) {
    bad.add('检索结果缺总长上限（超长记忆会撑爆上下文）');
  }
  return bad;
}

/// 判据 ⑪：KB `memory` 条目回归用户语言 —— 不得出现给模型的内部寻址符与算法参数。
List<String> judgeKnowledge(String kb) {
  final bad = <String>[];
  final i = kb.indexOf("HelpEntry('memory'");
  if (i < 0) {
    bad.add('KB 找不到 memory 条目');
    return bad;
  }
  var j = kb.indexOf('HelpEntry(', i + 5);
  if (j < 0) j = kb.length;
  final entry = kb.substring(i, j);
  if (entry.contains('memory://')) {
    bad.add('KB memory 条目仍含 memory:// 地址（用户会读到黑话）');
  }
  if (entry.contains('half-life')) {
    bad.add('KB memory 条目仍含 half-life（实现参数泄漏给用户）');
  }
  if (entry.contains('ranked by')) {
    bad.add('KB memory 条目仍含 ranked by（实现参数泄漏给用户）');
  }
  if (entry.contains('memory address')) {
    bad.add('KB memory 条目关键词仍含 memory address');
  }
  if (!entry.contains('Auto recall')) {
    bad.add('KB memory 条目丢了"怎么关"（Auto recall）');
  }
  return bad;
}

void main() {
  const dbPath = 'lib/core/db_helper.dart';
  const profilePath = 'lib/core/user_profile_store.dart';

  final dbRaw = _read(dbPath);
  final dbHelper = _stripComments(dbRaw);
  final profileRaw = _read(profilePath);
  const kbPath = 'lib/core/system_knowledge.dart';
  const agentPath = 'lib/core/agent_service.dart';
  final kbRaw = File(kbPath).existsSync() ? _read(kbPath) : '';
  final agentService =
      File(agentPath).existsSync() ? _stripComments(_read(agentPath)) : '';

  final bad = judge(dbHelper: dbHelper, dbRaw: dbRaw, profileRaw: profileRaw);

  // ── 正向断言 ──
  check(dbHelper.length > 5000, 'db_helper 真被读到');
  check(profileRaw.length > 1000, 'user_profile_store 真被读到');
  check(bad.isEmpty, '判据全过${bad.isEmpty ? '' : ' - 见下逐条'}');
  for (final b in bad) {
    print('    · $b');
  }

  // ── 方法体截取有效性（自检用的工具本身要先自证）──
  check(
    _methodBody('void f() { if (x) { y(); } }', 'void f()') ==
        '{ if (x) { y(); } }',
    '方法体截取有效（嵌套花括号配平）',
  );
  check(
    _methodBody('void f({int a = -1}) async { body; }', 'void f({int a = -1})') ==
        '{ body; }',
    '方法体截取有效（签名自带花括号不误判）',
  );
  check(_methodBody('void f() {}', 'void g()') == null, '找不到签名返回 null');

  // ── ★ 自检（positive control）：每改坏一处，都必须被判出 ──
  //    ★★ 改坏必须**限定在对应方法体内**：全文件 `replaceFirst` 打中的可能是
  //       另一个同名写法（本文件第一版就因此改到了 `searchMessages` 里那条
  //       同形的 `where: 'text LIKE ?'`，而判据看的是 `searchAllMemory`）
  //       ⇒ 改坏了却没被判出，守卫**假绿**。这是最危险的一类守卫缺陷。

  /// 把 [from] 在 [body] 内的首次出现改成 [to]，再把改动写回整份源码。
  /// 这样"改坏"只作用于目标方法，不会被别处的同形写法吸走。
  String corruptIn(String body, String from, String to) =>
      dbHelper.replaceFirst(body, body.replaceFirst(from, to));

  final recallText = _methodBody(dbHelper, _recallSig);
  final allText = _methodBody(dbHelper, _searchAllSig);
  final fuzzyText = _methodBody(dbHelper, _fuzzySig);
  check(recallText != null && allText != null && fuzzyText != null,
      '自检前提：三个目标方法体都找得到');

  // 自检①：腿①去掉记忆地址
  final a1 = 'memory://episode/';
  check(recallText!.contains(a1), '自检①前提：buildRecallBlock 里有腿①的地址锚点');
  final m1 = judge(
    dbHelper: corruptIn(recallText, a1, 'memoryX://episode/'),
    dbRaw: dbRaw,
    profileRaw: profileRaw,
  );
  check(m1.any((e) => e.contains('腿①')), '自检①：腿①去掉记忆地址必须被判出');

  // 自检②：腿②去掉记忆地址
  //   ★ 必须限定在 buildRecallBlock 内：全文件里 searchAllMemory 也有
  //     `h.memoryAddress`，直接 replaceFirst 会打中后者 ⇒ 判据②不报红 ⇒ 假绿。
  final a2 = 'h.memoryAddress';
  check(recallText.contains(a2), '自检②前提：buildRecallBlock 里有腿②的地址锚点');
  final m2 = judge(
    dbHelper: corruptIn(recallText, a2, 'h.source'),
    dbRaw: dbRaw,
    profileRaw: profileRaw,
  );
  check(m2.any((e) => e.contains('腿②')), '自检②：腿②去掉记忆地址必须被判出');

  // 自检③：FTS5 退回"直选未声明列"（本轮实证的真实缺陷形态）
  final a3 = "'SELECT m.id AS id, m.text AS text, m.isUser AS isUser, '";
  check(allText!.contains(a3),
      '自检③前提：searchAllMemory 里有当前 FTS5 的 SELECT 片段');
  final m3 = judge(
    dbHelper: corruptIn(
      allText,
      a3,
      "'SELECT text, isUser, timestamp FROM messages_fts '",
    ),
    dbRaw: dbRaw,
    profileRaw: profileRaw,
  );
  check(
    m3.any((e) => e.contains('直选了未声明列')),
    '自检③：FTS5 直选 isUser/timestamp 必须被判出',
  );

  // 自检④：删掉中文 LIKE 兜底
  //   ★ 同样必须限定在 searchAllMemory 内：`searchMessages` 里有一条同形写法。
  final a4 = "where: 'text LIKE ?',";
  check(allText.contains(a4),
      '自检④前提：searchAllMemory 里有 LIKE 兜底片段');
  final m4 = judge(
    dbHelper: corruptIn(allText, a4, "where: 'text = ?',"),
    dbRaw: dbRaw,
    profileRaw: profileRaw,
  );
  check(m4.any((e) => e.contains('LIKE 兜底被删')),
      '自检④：删掉中文 LIKE 兜底必须被判出');

  // 自检⑤：去掉排序的 ns/id 兜底
  final a5 = 'final byNs = a.ns.compareTo(b.ns);';
  check(dbHelper.contains(a5), '自检⑤前提：找得到当前排序兜底片段');
  final a5b =
      '$a5\n      if (byNs != 0) return byNs;\n      return b.id.compareTo(a.id);';
  check(dbHelper.contains(a5b), '自检⑤前提：排序兜底片段与源码逐字一致');
  final m5 = judge(
    dbHelper: dbHelper.replaceFirst(a5b, 'return 0;'),
    dbRaw: dbRaw,
    profileRaw: profileRaw,
  );
  check(m5.any((e) => e.contains('缺 ns/id 兜底')), '自检⑤：去掉排序兜底必须被判出');

  // 自检⑥：半衰期与画像失配
  final a6 = '_recallHalfLifeDays = 21.0';
  check(dbHelper.contains(a6), '自检⑥前提：找得到当前半衰期常量');
  final m6 = judge(
    dbHelper: dbHelper.replaceFirst(a6, '_recallHalfLifeDays = 7.0'),
    dbRaw: dbRaw,
    profileRaw: profileRaw,
  );
  check(
    m6.any((e) => e.contains('半衰期') && e.contains('不一致')),
    '自检⑥：半衰期与画像失配必须被判出',
  );

  // ── ⑦⑧⑨⑩⑪ 接线 / 不可信包裹 / 全仓 FTS5 / 打分噪声 / KB（0.78.0）──
  check(kbRaw.isNotEmpty, 'system_knowledge.dart 真被读到');
  check(agentService.isNotEmpty, 'agent_service.dart 真被读到');

  final wiring = judgeToolWiring(
    dbHelper: dbHelper,
    dbRaw: dbRaw,
    agentService: agentService,
  );
  check(wiring.isEmpty, '接线判据全过${wiring.isEmpty ? '' : ' - 见下逐条'}');
  for (final b in wiring) {
    print('    · $b');
  }

  final kbBad = judgeKnowledge(kbRaw);
  check(kbBad.isEmpty, 'KB 判据全过${kbBad.isEmpty ? '' : ' - 见下逐条'}');
  for (final b in kbBad) {
    print('    · $b');
  }

  // ── ★ 自检：改坏必须被判出 ──
  final w1 = judgeToolWiring(
    dbHelper: dbHelper.replaceFirst(
        'memory://<命名空间>/<行号>', 'memoryX://<命名空间>/<行号>'),
    dbRaw: dbRaw.replaceFirst(
        'memory://<命名空间>/<行号>', 'memoryX://<命名空间>/<行号>'),
    agentService: agentService,
  );
  check(w1.any((e) => e.contains('未含 memory://')),
      '自检⑦：工具描述去掉 memory:// 必须被判出');

  final w2 = judgeToolWiring(
    dbHelper: dbHelper.replaceFirst(
        'onOpen: (Database db) => healBuiltinToolDescriptions(db),', ''),
    dbRaw: dbRaw,
    agentService: agentService,
  );
  check(w2.any((e) => e.contains('onOpen')), '自检⑦b：去掉 onOpen 收敛必须被判出');

  final recallBody2 = _methodBody(dbHelper, _recallSig);
  final w3 = judgeToolWiring(
    dbHelper: recallBody2 == null
        ? dbHelper
        : dbHelper.replaceFirst(
            recallBody2,
            recallBody2.replaceAll('原样传给 search_historical_memory',
                '原样传给 searchHistoricalMemory')),
    dbRaw: dbRaw,
    agentService: agentService,
  );
  check(w3.any((e) => e.contains('两条腿')), '自检⑧：回忆块去掉地址用法必须被判出');

  final w4 = judgeToolWiring(
    dbHelper: dbHelper,
    dbRaw: dbRaw,
    agentService: agentService.replaceFirst(
        "_wrapUntrusted('【记忆检索结果】", "('【记忆检索结果】"),
  );
  check(w4.any((e) => e.contains('未按不可信输入包裹')),
      '自检⑨：检索结果变裸必须被判出');

  final w5 = judgeToolWiring(
    dbHelper:
        dbHelper.replaceFirst('FROM messages_fts f ', 'FROM messages_fts WHERE '),
    dbRaw: dbRaw,
    agentService: agentService,
  );
  check(w5.any((e) => e.contains('直选')), '自检⑩：全仓直选未声明列必须被判出');

  final w6 = judgeToolWiring(
    dbHelper:
        '$dbHelper\n  static Future<String> searchMessagesSmart(String keyword) async => "";\n',
    dbRaw: dbRaw,
    agentService: agentService,
  );
  check(w6.any((e) => e.contains('searchMessagesSmart') || e.contains('死代码')),
      '自检⑪：searchMessagesSmart 复活必须被判出');

  final w7 = judgeToolWiring(
    dbHelper:
        dbHelper.replaceFirst('_containsRecallStopChar(gram)', 'raw.add(gram)'),
    dbRaw: dbRaw,
    agentService: agentService,
  );
  check(w7.any((e) => e.contains('功能字')), '自检⑫：虚字过滤被删必须被判出');

  check(
      judgeKnowledge(
              "HelpEntry('memory', 't', 'memory', 'x memory://episode/42 y')")
          .isNotEmpty,
      '自检⑬：KB memory 条目含 memory:// 必须被判出');
  check(
      judgeKnowledge("HelpEntry('memory', 't', 'memory', 'ranked by x')")
          .isNotEmpty,
      '自检⑬：KB memory 条目含 ranked by 必须被判出');
  check(
      judgeKnowledge(
              "HelpEntry('memory', 't', 'k', 'ok. Stop all: Auto recall.')")
          .isEmpty,
      '自检⑬：干净的 memory 条目必须判过');

  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) {
    exitCode = 1;
  }
}
