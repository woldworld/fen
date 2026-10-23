/// Hub 地址解析的**单一策略**（新上行通道专用）。
///
/// ---------------------------------------------------------------------------
/// 为什么单独抽一个类
/// ---------------------------------------------------------------------------
/// 上行通道必须打到 App **注册的那个 Hub**（同一个地址、同一把注册身份），
/// 否则会出现"注册在 A、公示到 B"这种最坏情况：数据看起来发出去了，
/// 但在任何人能验证的那棵树上都不存在。
/// 所以这里把策略写成可通过的参数，让"打到哪儿"是**显式且可断言**的，
/// 而不是散落在各处的字面量。
///
/// ⚠️ 已知重复：`cloud_service.dart` / `world_service.dart` / `god_service.dart`
/// 各自持有一份等价的私有实现（历史原因，读的是同一个 prefs 键）。
/// 本轮**不去改动那三个**（动它们要重跑各自的冒烟，超出本轮范围），
/// 但后续应统一到本类 —— 否则那份"私有网段白名单"一旦漂移，
/// 就会有一个通道开始拒绝自家电脑上跑的 Hub，而症状是"只有某个功能连不上"。
abstract final class HubEndpoint {
  /// 与 `cloud_service` 同源：Hub 地址存在这个键里。
  static const String prefsKey = 'cloud_hub_url';

  /// 私有网段：允许显式 `http://`（Hub 可以跑在自家电脑/局域网里）。
  static final RegExp _privateHost = RegExp(
      r'^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.|localhost$)');

  static bool isPrivateHost(String host) => _privateHost.hasMatch(host);

  /// 传输安全判定（**纯函数**，可离线断言）。
  ///
  /// - 公网必须是 HTTPS；
  /// - 私网/本机允许显式 `http://`（否则本地调试与局域网部署都做不了）。
  static bool isAcceptable(String url) {
    final u = url.trim();
    if (u.isEmpty) return false;
    if (!u.startsWith('http://')) return true; // https:// 或其它显式 scheme
    final host = Uri.tryParse(u)?.host.toLowerCase() ?? '';
    return isPrivateHost(host);
  }

  /// 由**已读出的原始值**解析 Hub 地址（**纯函数**，可离线断言）。
  /// 未配置或被策略拒绝 → 返回**空串**，调用方必须早退
  /// （绝不能拿占位域名发请求，那只是无意义的 DNS 空转）。
  ///
  /// 刻意不在本类里读 `SharedPreferences`：那会把 Flutter 依赖引进来，
  /// 于是"打到哪儿"这条策略就无法在纯 Dart 环境下断言 —— 而它一旦漂移，
  /// 症状是"数据看起来发出去了，但任何人都验不到"。
  static String resolveFrom(String? raw) {
    final url = (raw ?? '').trim();
    return isAcceptable(url) ? url : '';
  }
}
