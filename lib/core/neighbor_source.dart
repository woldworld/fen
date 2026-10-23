import 'db_helper.dart';
import 'lan_service.dart';
import 'neighbor_pool.dart';
import 'p2p_service.dart';

/// 圈子人数不足时的兜底来源：**真实在线/已连接的分身**。
///
/// 为什么要单独一个文件：
/// - `circle_service.dart` 必须保持零平台依赖（好让 `dart run` 验证），
///   而真实来源要读 SQLite、P2P、LAN —— 所以只能由宿主侧适配后再注入。
/// - 兜底最怕两件事：**空数组**（等于 M1 验收过不了）和**假数据**（等于把验收变成演戏）。
///   这里只列"此刻确实连得上或确实标了在线"的节点。
///
/// 分工：本文件只负责**取真实 ID 列表**；去重/排除自己/上限/来源统计
/// 由 [NeighborPool]（纯逻辑、可离线验证）完成；是否够 3 个仍由
/// `CircleService.visibleFens` 判定（验收口径不能分叉）。
class NeighborSource {
  /// 最近一次兜底的实际来源，形如 `nearfield:2,lan:1,roster:4`（`none` = 一个都没有）。
  ///
  /// 为什么要留这个：真机复核时"这几个可见分身哪来的"必须能回答，
  /// 否则"兜底"就成了一个说不清的黑洞。
  static String lastSource = 'none';

  static Future<List<String>> resolve(String circleId, String selfId) async {
    final bySource = <String, List<String>>{};

    // ① 近场（P2P mesh）：此刻真的有物理连接
    try {
      bySource['nearfield'] = P2PService().connectedAgents;
    } catch (_) {
      bySource['nearfield'] = const [];
    }

    // ② 局域网：同一 Wi-Fi 下已握手
    try {
      bySource['lan'] = LanService().connectedLanAgents;
    } catch (_) {
      bySource['lan'] = const [];
    }

    // ③ 名册里标了在线的（含云端心跳在线）
    try {
      final friends = await DBHelper.getAgentFriends();
      bySource['roster'] = [
        for (final f in friends)
          if (f['is_online'] == 1) f['agent_id']?.toString() ?? '',
      ];
    } catch (_) {
      bySource['roster'] = const [];
    }

    lastSource = NeighborPool.summarize(selfId: selfId, bySource: bySource);
    return NeighborPool.merge(selfId: selfId, bySource: bySource);
  }
}
