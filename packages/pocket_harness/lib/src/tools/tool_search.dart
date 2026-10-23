import '../tools/tool_spec.dart';

/// 一条检索命中
class ScoredTool {
  final ToolSpec spec;
  final double score;
  const ScoredTool(this.spec, this.score);
}

/// 工具语义检索——**关键词降级版**（M5）。
///
/// 背景：语义检索的正解是 embeddings，但 DeepSeek 不提供 embeddings API
/// （见 HARNESS_PLAN §5），在 provider 明确之前先用纯 Dart 关键词打分：
/// - 中文按二元组（bigram）切词，英文按连续字母词切分（小写化）；
/// - 名称命中权重 ×3，描述命中权重 ×1；
/// - 低于 [minScore] 的工具不返回（保证"检索不到"是显式结果）。
///
/// 用法场景：工具数膨胀（>30）后不把全量工具塞 prompt，而是按任务检索
/// top-N 挂载。embedding 版等 provider 明确后在此接口下替换。
class ToolSearch {
  /// 检索与 [query] 最相关的工具。
  static List<ScoredTool> rank(
    String query,
    List<ToolSpec> specs, {
    int top = 8,
    double minScore = 1.0,
  }) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return const [];
    final scored = <ScoredTool>[];
    for (final spec in specs) {
      final name = spec.name.toLowerCase();
      final desc = spec.description.toLowerCase();
      double score = 0;
      for (final tk in tokens) {
        if (name.contains(tk)) {
          score += 3;
        } else if (desc.contains(tk)) {
          score += 1;
        }
      }
      if (score >= minScore) scored.add(ScoredTool(spec, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.length > top ? scored.sublist(0, top) : scored;
  }

  /// 切词：CJK 连续段按二元组；拉丁/数字连续段按整词
  static Set<String> tokenize(String query) {
    final tokens = <String>{};
    final cjkRuns = RegExp(r'[\u4e00-\u9fff]+').allMatches(query);
    for (final m in cjkRuns) {
      final run = m.group(0)!;
      if (run.length == 1) {
        tokens.add(run);
      } else {
        for (var i = 0; i < run.length - 1; i++) {
          tokens.add(run.substring(i, i + 2));
        }
      }
    }
    for (final m in RegExp(r'[a-zA-Z0-9]{2,}').allMatches(query)) {
      tokens.add(m.group(0)!.toLowerCase());
    }
    return tokens;
  }
}
