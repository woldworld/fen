/// ============================================================
/// 系统自检：把"底座事实"变成**可读数**的探针（本文件**零依赖**，只 import dart:async）。
///
/// 为什么要有它（两条都来自实测，不是想象）：
///   · 真机复核（W0）需要一堆"看不见的事实"—— FTS5 到底建没建起来、
///     记忆地址能不能反查、召回要多久…… 它们在 UI 上**原本没有出口**；
///   · 更硬的一条：`DBHelper._ensureFts` 原本把整段包在 `catch (_) {}` 里 ——
///     平台不支持 FTS5 时**静默**退回 LIKE，没有任何标记或日志。
///     这正是本项目"静默失败是红线"的典型形态，也是真机复核最想知道的事实
///     （桌面 FFI 引擎证明不了 Android 的 SQLite 带不带 FTS5）。
///
/// 设计纪律（与 `net_diagnosis.dart` 同款）：
///   · **纯逻辑**：探针是**注入**的 `Future<DiagFinding> Function()`；
///     "跑法 / 计时 / 异常兜底"全在这一层，可离线断言；
///   · **单条不拖垮整轮**：某个探针抛异常 ⇒ 它自己变成一条 [DiagStatus.fail]，
///     其余照跑（一个坏探针不该让"自检"整体失败）；
///   · **顺序稳定**：结果顺序 == 入参顺序（屏幕与复制文本都依赖它）。
/// ============================================================
library;

import 'dart:async';

/// 一条探针的结论等级。
enum DiagStatus {
  /// 正常。
  ok,

  /// 需要留意（能用，但有降级 / 代价）。
  warn,

  /// 失败（底座事实不成立）。
  fail,

  /// 纯信息（无好坏之分，如版本号）。
  info,
}

/// 探针自己给出的**结论**（不含 id 与耗时 —— 那两个由 [runDiagnostics] 统一填）。
class DiagFinding {
  final DiagStatus status;
  final String detail;
  const DiagFinding(this.status, this.detail);

  const DiagFinding.ok(String detail) : this(DiagStatus.ok, detail);
  const DiagFinding.warn(String detail) : this(DiagStatus.warn, detail);
  const DiagFinding.fail(String detail) : this(DiagStatus.fail, detail);
  const DiagFinding.info(String detail) : this(DiagStatus.info, detail);
}

/// 一条探针：稳定 [id] + 一个**可注入**的跑法。
///
/// [id] 同时是 UI 取本地化标题的键（见 `diagnostics_screen.dart` 的映射），
/// 故 **id 一旦发布不要改名**（改名 = 老屏幕取不到标题）。
class DiagnosticProbe {
  final String id;
  final Future<DiagFinding> Function() run;
  const DiagnosticProbe(this.id, this.run);
}

/// 一条探针的最终结果。
class DiagResult {
  final String id;
  final DiagStatus status;
  final String detail;
  final int elapsedMs;
  const DiagResult(this.id, this.status, this.detail, this.elapsedMs);
}

/// 顺序跑完 [probes]，逐条计时；**单条抛异常 ⇒ 该条变 [DiagStatus.fail]**，其余不受影响。
Future<List<DiagResult>> runDiagnostics(List<DiagnosticProbe> probes) async {
  final out = <DiagResult>[];
  for (final p in probes) {
    final sw = Stopwatch()..start();
    DiagFinding f;
    try {
      f = await p.run();
    } catch (e) {
      f = DiagFinding.fail('probe threw: $e');
    }
    sw.stop();
    out.add(DiagResult(p.id, f.status, f.detail, sw.elapsedMilliseconds));
  }
  return out;
}

/// 把结果拍成**纯文本**（供"复制结果"按钮 —— 主人可整段粘回给我）。
///
/// ★ 形如 `OK  fts  full-text available · indexed=12 (3ms)` —— 前缀是稳定的
///   状态 token（`OK`/`WARN`/`FAIL`/`INFO`），便于我这边按行解析，不必依赖中文。
String formatDiagnostics(List<DiagResult> results) {
  final buf = StringBuffer();
  for (final r in results) {
    buf.writeln('${statusToken(r.status)}  ${r.id}  ${r.detail} (${r.elapsedMs}ms)');
  }
  return buf.toString().trimRight();
}

/// 状态 → 稳定英文 token（**不本地化**：它是给机器读的，与 UI 上的标签分开）。
String statusToken(DiagStatus s) {
  switch (s) {
    case DiagStatus.ok:
      return 'OK';
    case DiagStatus.warn:
      return 'WARN';
    case DiagStatus.fail:
      return 'FAIL';
    case DiagStatus.info:
      return 'INFO';
  }
}
