/// ============================================================
/// 生产探针集（0.79.0）：把"系统自检"屏真正要看的**底座事实**接起来。
///
/// 与 `diagnostics.dart` 的分工：
///   · `diagnostics.dart` 只有**跑法与判据**（零依赖、可离线断言）；
///   · 本文件是**接线层** —— 允许依赖 DBHelper / 知识库，只做"读一次、报一句"。
///
/// 三条纪律：
///   · **只读**：不改任何数据、不发任何网络请求（真机复核不该有副作用）；
///   · **不假装**：没有数据 ≠ 失败（报 `info`），底座坏了才报 `fail`；
///   · **id 稳定**：id 是 UI 取标题的键，也是我按行解析的键，改名要同步全链。
/// ============================================================
library;

import 'db_helper.dart';
import 'diagnostics.dart';
import 'system_knowledge.dart';

/// 组装当前 App 的探针列表（顺序 == 屏幕显示顺序）。
List<DiagnosticProbe> buildAppProbes() => <DiagnosticProbe>[
      DiagnosticProbe('schema', () async {
        return DiagFinding.info('schema=${DBHelper.schemaVersion}');
      }),
      DiagnosticProbe('fts', () async {
        final r = await DBHelper.probeFullText();
        if (r.available) {
          return DiagFinding.ok('fts5 available · indexed=${r.indexedRows}');
        }
        // 降级不是崩溃，但**必须显形**（这正是 0.79.0 要修的那条静默失败）。
        return DiagFinding.warn('fts5 unavailable · recall falls back to LIKE'
            '${r.error == null ? '' : ' · ${_trim(r.error!)}'}');
      }),
      DiagnosticProbe('memoryRows', () async {
        final c = await DBHelper.memoryCounts();
        return DiagFinding.info(
            'chat=${c['messages']} social=${c['social_logs']} '
            'episode=${c['memory_events']} session=${c['session_events']}');
      }),
      DiagnosticProbe('memoryRecall', () async {
        final db = await DBHelper.db;
        final rows = await db.rawQuery(
            'SELECT text FROM messages ORDER BY id DESC LIMIT 1');
        if (rows.isEmpty) {
          return DiagFinding.info('no chat data yet · skipped');
        }
        final sample = (rows.first['text']?.toString() ?? '').trim();
        if (sample.isEmpty) return DiagFinding.info('latest message empty · skipped');
        // 用**真实存在的一段文本**当查询词：召回通路正常就一定能命中，
        // 命中不了 = 通路真坏了（比拿固定样例词可靠得多）。
        final kw = sample.length > 12 ? sample.substring(0, 12) : sample;
        final out = await DBHelper.searchAllMemory(kw);
        final n = out.trim().length;
        return n > 0
            ? DiagFinding.ok('recall returned $n chars')
            : DiagFinding.fail('recall returned empty for an existing row');
      }),
      DiagnosticProbe('memoryAddress', () async {
        // 地址**可兑现**是 0.77.0 的核心承诺 —— 这里做一次真实往返：
        // 取最新一行 → 组地址 → 反查 → 必须取回同一行。
        final db = await DBHelper.db;
        final rows =
            await db.rawQuery('SELECT id FROM messages ORDER BY id DESC LIMIT 1');
        if (rows.isEmpty) return DiagFinding.info('no chat data yet · skipped');
        final id = rows.first['id'];
        if (id is! int) return DiagFinding.info('no usable row id · skipped');
        final addr = 'memory://chat/$id';
        final got = await DBHelper.resolveMemoryAddress(addr);
        return got == null
            ? DiagFinding.fail('address $addr did not resolve')
            : DiagFinding.ok('$addr -> row ok');
      }),
      DiagnosticProbe('kb', () async {
        return DiagFinding.info('kbVersion=$kbVersion entries=${systemKnowledge.length}');
      }),
    ];

/// 把异常文本压成一行、限长（探针详情要能塞进一行复制文本里）。
String _trim(String s) {
  final oneLine = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length > 120 ? '${oneLine.substring(0, 120)}…' : oneLine;
}
