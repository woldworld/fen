/// §16 · Merkle root 外部锚定：补上**哈希链原理上查不出**的那个洞。
///
/// 为什么需要锚定（这是 §16 里最容易被忽略、却最致命的一处）：
/// [TransparencyLog] 的哈希链能发现"**改写**"与"**中段删除**"——因为后面所有条目的
/// `prev_hash` / `index` 会立刻错位。但它**原理上查不出"截断"**：
/// 把末尾若干条整段砍掉后，剩下的前缀依然是一条自洽的链，`verifyChain()` 照样返回 true。
/// 而"砍掉尾部"恰恰是最省事的作恶方式——删掉对自己不利的最新记录，日志看起来一切正常。
///
/// **唯一的解法是外部锚定**：把某一期的 `(size, root)` 写到日志自己管不到的地方，
/// 之后无论 Hub 怎么改自己的存储，都对不上那份外部记录。PRD §16 指定的载体是：
/// **GitHub 签名提交**（时间戳由提交历史提供）或 **OpenTimestamps**。
///
/// 本文件只做**纯逻辑**：判据、序列自检、收据生成。网络与落盘在 `tool/anchor_log.dart`。
/// 零平台依赖，可离线复算。
///
/// ⚠️ 三条 fail-closed 判据（任何一条触发都**不得**追加，且必须报错退出）：
///   1. **规模倒退**（`size < last.size`）→ 日志被回滚/截断；
///   2. **同期换根**（`size == last.size` 且 `root != last.root`）→ 历史被改写；
///   3. **序列自检不过** → 锚定文件本身被动过。
///
/// 注意判据 2 的含义：仅仅"规模没长"不算异常（可能这期没有新记录，属正常），
/// 但"规模一样、根却变了"**一定是**篡改 —— 同样多的叶子不可能长出两个根。

library;

import 'dart:convert';

/// 一条锚定记录：某个时刻，日志有 [size] 片叶子、Merkle 根为 [root]。
///
/// 只存 `(size, root, 时间)` 三项 —— 不存叶子、不存原文。
/// 于是这份文件**本身不泄露任何业务信息**，可以放心提交到公开仓库。
class LogAnchor {
  /// 锚定时日志的规模（叶子数量）。
  final int size;

  /// 该规模下的 Merkle 根（base58）。
  final String root;

  /// 锚定时刻（毫秒时间戳，UTC）。
  final int anchoredAtMs;

  /// 可选备注（例如"每周一 00:00 例行锚定"）。
  final String? note;

  const LogAnchor({
    required this.size,
    required this.root,
    required this.anchoredAtMs,
    this.note,
  });

  /// UTC ISO-8601 形式，便于人读与排序。
  String get iso => DateTime.fromMillisecondsSinceEpoch(anchoredAtMs, isUtc: true)
      .toIso8601String();

  Map<String, Object?> toJson() => {
        'size': size,
        'root': root,
        'anchored_at': anchoredAtMs,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  static LogAnchor fromJson(Map<String, dynamic> m) => LogAnchor(
        size: (m['size'] as num).toInt(),
        root: m['root'] as String,
        anchoredAtMs: (m['anchored_at'] as num).toInt(),
        note: m['note'] as String?,
      );

  /// 一行 JSONL（append-only 文件的一行）。
  String toJsonl() => jsonEncode(toJson());

  static LogAnchor? parseJsonl(String line) {
    final t = line.trim();
    if (t.isEmpty) return null;
    final m = jsonDecode(t) as Map<String, dynamic>;
    return fromJson(m);
  }

  /// 解析整份 JSONL（忽略空行）。
  static List<LogAnchor> seriesFromJsonl(String content) {
    final out = <LogAnchor>[];
    for (final line in const LineSplitter().convert(content)) {
      final a = parseJsonl(line);
      if (a != null) out.add(a);
    }
    return out;
  }

  @override
  String toString() => 'LogAnchor(size=$size, root=$root, at=$iso)';
}

/// 追加判定的结论。
enum AnchorVerdict {
  /// 正常：规模前进，可以追加。
  append,

  /// 幂等：(size, root) 与上一条完全相同，无需重复追加。
  duplicate,

  /// 回滚/截断：规模比上一条**变小**了。
  rollback,

  /// 改写：规模相同但根不同。
  fork,

  /// 输入非法（负数规模、空根等）。
  invalid,
}

class AnchorDecision {
  final AnchorVerdict verdict;

  /// 机器可读的说明：**英文 token 风格**（与 `transparency_log.dart` / `hub.js` 的
  /// `bad_sizes`、`tree_size_out_of_range` 同口径）。
  ///
  /// 为什么不在这里写中文：本文件是**纯逻辑层**，与 `transparency_log.dart` 一样
  /// 保持"中文字面量零残留"（中文只出现在注释里）。面向操作者的中文描述
  /// 由 CLI（`tool/anchor_log.dart`，不在 `lib/` 扫描范围内）按 [verdict] 渲染。
  final String detail;

  const AnchorDecision(this.verdict, this.detail);

  /// 是否应当写入新的一行。
  bool get shouldAppend => verdict == AnchorVerdict.append;

  /// 是否是可接受的状态（正常追加 or 幂等重复）。回滚/改写/非法都不可接受。
  bool get acceptable =>
      verdict == AnchorVerdict.append || verdict == AnchorVerdict.duplicate;

  @override
  String toString() => '${verdict.name}: $detail';
}

class AnchorPolicy {
  /// 核心判据：拿"这次观测到的 (size, root)"与**上一条锚定记录**比对，
  /// 决定是否可以追加。`last == null` 表示这是第一条（创世锚定）。
  static AnchorDecision decide({
    required LogAnchor? last,
    required int size,
    required String root,
  }) {
    if (size < 0) {
      return const AnchorDecision(AnchorVerdict.invalid, 'invalid_size');
    }
    if (root.isEmpty) {
      return const AnchorDecision(AnchorVerdict.invalid, 'invalid_root');
    }
    if (last == null) {
      return const AnchorDecision(AnchorVerdict.append, 'append:genesis');
    }
    if (size < last.size) {
      // 注意：**规模变小**是哈希链原理上查不出的一类作恶（截断），必须在这里拦住。
      return AnchorDecision(
        AnchorVerdict.rollback,
        'rollback:${last.size}->$size',
      );
    }
    if (size == last.size) {
      if (root == last.root) {
        return const AnchorDecision(AnchorVerdict.duplicate, 'duplicate');
      }
      // 同样多的叶子不可能长出两个根 —— 一定是历史被改写。
      return AnchorDecision(AnchorVerdict.fork, 'fork:size$size');
    }
    return AnchorDecision(AnchorVerdict.append, 'append:${last.size}->$size');
  }

  /// 对整份锚定序列做离线自检。
  /// 返回 `null` 表示通过；否则返回第一处问题的英文 token 说明。
  static String? validateSeries(List<LogAnchor> anchors) {
    for (var i = 0; i < anchors.length; i++) {
      final a = anchors[i];
      if (a.size < 0) return 'negative_size_at_$i';
      if (a.root.isEmpty) return 'empty_root_at_$i';
      if (a.anchoredAtMs <= 0) return 'bad_timestamp_at_$i';
      if (i == 0) continue;
      final prev = anchors[i - 1];
      if (a.size < prev.size) return 'shrink_at_$i:${prev.size}->${a.size}';
      if (a.size == prev.size && a.root != prev.root) {
        return 'fork_at_$i:size${a.size}';
      }
      if (a.anchoredAtMs < prev.anchoredAtMs) return 'time_going_back_at_$i';
    }
    return null;
  }

  /// 相邻两条锚定之间的**规模差**是否可被一致性证明连接（即 b 是 a 的前缀延续）。
  /// 这是"离线判据"能给出的最强结论：它在无需网络时先确认 (m,n) 合法。
  static bool sizesConnectable(LogAnchor a, LogAnchor b) =>
      b.size >= a.size && b.anchoredAtMs >= a.anchoredAtMs;
}

/// 生成"锚定收据"：一小段可粘贴进 **GitHub 签名提交** 的文本。
///
/// 为什么是提交而不是别的地方：签名的提交**不可事后伪造时间**——
/// 提交历史本身就是一份第三方可查的、带时间戳的只追加记录。
/// 把收据写进提交信息 + 提交 `merkle_roots.jsonl`，就等于给这一期的根盖了时间戳。
class AnchorReceipt {
  /// 规范化文本。字段顺序固定，便于 diff 与 grep。
  static String build({required LogAnchor anchor, String? prevRoot}) {
    final b = StringBuffer()
      ..writeln('Wold transparency-log anchor')
      ..writeln('period       : ${anchor.iso}')
      ..writeln('tree_size    : ${anchor.size}')
      ..writeln('merkle_root  : ${anchor.root}')
      ..writeln('prev_root    : ${(prevRoot == null || prevRoot.isEmpty) ? '(genesis)' : prevRoot}');
    if (anchor.note != null && anchor.note!.isNotEmpty) {
      b.writeln('note         : ${anchor.note}');
    }
    return b.toString();
  }
}
