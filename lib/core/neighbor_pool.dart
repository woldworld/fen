/// 兜底邻居池的**纯逻辑**（零平台依赖，可 `dart run` 验证）。
///
/// 为什么拆出来：`neighbor_source.dart` 要读 P2P / LAN / SQLite（跑不进纯 Dart 验证），
/// 但"哪些人算邻居"这件事本身有规则——**排除自己、跨来源去重、上限、来源可查**——
/// 规则错了会直接污染 M1 验收（可见分身数），所以规则必须能离线复算。
///
/// 分工：
/// - 本文件（纯）：给定各来源的 ID 列表 → 去重后的邻居 + 来源统计；
/// - `neighbor_source.dart`（宿主适配）：去真实通道取 ID 列表，然后调用这里。
library;

class NeighborPool {
  /// 默认上限：防某个通道状态异常时把列表撑爆。
  static const int defaultMax = 20;

  /// 各来源按优先级拼接去重。
  ///
  /// [bySource] 的插入顺序即优先级（近场 > 局域网 > 名册）。
  /// 返回纯 ID 列表；来源统计用 [summarize]。
  static List<String> merge({
    required String selfId,
    required Map<String, List<String>> bySource,
    int max = defaultMax,
  }) {
    final seen = <String>{selfId}; // 自己永远不是"别人"
    final out = <String>[];
    for (final ids in bySource.values) {
      for (final raw in ids) {
        final id = raw.trim();
        if (id.isEmpty || !seen.add(id)) continue;
        if (out.length >= max) return out;
        out.add(id);
      }
    }
    return out;
  }

  /// 来源统计串，形如 `nearfield:2,lan:1,roster:4`；一个都没有时返回 `none`。
  ///
  /// 只用**实际贡献了邻居**的来源（去重后），否则会出现
  /// "roster:3" 但其中 3 个其实是从近场重复来的 —— 那是假账。
  static String summarize({
    required String selfId,
    required Map<String, List<String>> bySource,
    int max = defaultMax,
  }) {
    final seen = <String>{selfId};
    final parts = <String>[];
    var total = 0;
    for (final e in bySource.entries) {
      var n = 0;
      for (final raw in e.value) {
        final id = raw.trim();
        if (id.isEmpty || !seen.add(id)) continue;
        if (total >= max) break;
        total++;
        n++;
      }
      if (n > 0) parts.add('${e.key}:$n');
      if (total >= max) break;
    }
    return parts.isEmpty ? 'none' : parts.join(',');
  }
}
