import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_helper.dart';

/// ============================================================
/// 插件总线（Plugin Bus）
///
/// 借鉴 DeepSeek Harness "一切皆插件" 思路的 Dart 侧轻量实现：
/// 每个工具/技能/Webhook/MCP 服务都是一份带「清单 + 签名 + 能力声明」
/// 的插件，加载前验签（篡改即拒绝、fail-closed），调用前按能力声明
/// 做首次授权弹窗，授权记录持久化，可在工具页一键吊销。
///
/// 签名语义：
/// - 本地创建的插件用设备密钥做 HMAC-SHA256（防篡改 + 设备绑定）；
///   等未来出现第三方插件商店时，再叠加作者 Ed25519 公钥体系，
///   source_sig 的 "hmac-sha256." 前缀保留升级空间。
/// - 内置硬编码工具标记为 "builtin"，不参与验签。
/// ============================================================
class PluginCapability {
  PluginCapability._();

  /// 发起网络 / API 请求（Webhook、搜索、MCP 服务）
  static const String network = 'network';

  /// 唤起外部 App / 网页
  static const String launchApp = 'launchApp';

  /// 本地硬件（震动等）
  static const String device = 'device';

  /// 操作手机屏幕（无障碍：读取界面、点击、输入）——最高敏感度之一
  static const String screenControl = 'screenControl';

  /// 读取系统通知与短信（只读）——最高敏感度之一。
  ///
  /// ★ 0.75.0（W6/G9）新增。**为什么要单独开一个码而不是复用 `screenControl`**：
  ///   授权弹窗靠能力码告诉主人"这个工具要动什么"（见 0.64.0 的教训——
  ///   把出网工具标成"本地能力"就是**说错话**）。读通知/短信与"操作屏幕"是
  ///   两件完全不同的事，混用会让弹窗撒谎。
  static const String notification = 'notification';

  /// 读写本地记忆 / 日志 / 技能库
  static const String memory = 'memory';

  /// 修改主人 / 系统设置
  static const String settings = 'settings';

  /// 代表主人在外社交发言
  static const String social = 'social';

  /// 纯本地、无副作用
  static const String local = 'local';

  // 注意：能力码 → 展示文案的映射**不在核心层**。
  // 核心层只保码（码会被写进签名载荷 canonical()，改动即等于改签名），
  // 展示文案由 UI 层的 `ui/plugin_labels.dart#capabilityLabel` 按当前语言产出。
}

/// 风险等级（决定是否走授权弹窗；fail-closed：弹窗无应答一律拒绝）
class PluginRisk {
  PluginRisk._();

  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';

  // 风险码 → 展示文案同样交给 UI（`ui/plugin_labels.dart#riskLabel`）。
}

/// 插件清单：由数据库 tools 行推导，签名覆盖其中全部字段。
class PluginMeta {
  final String name;
  final String version;
  final String kind; // local / mcp / skill
  final String description;
  final String content;
  final String author;
  final String risk;
  final List<String> capabilities;

  const PluginMeta({
    required this.name,
    required this.version,
    required this.kind,
    required this.description,
    required this.content,
    required this.author,
    required this.risk,
    required this.capabilities,
  });

  /// 规范化签名载荷：键序固定、能力排序，内容与描述都被签名，
  /// 任何一处被篡改都会导致验签失败。
  String canonical() {
    final sorted = [...capabilities]..sort();
    return jsonEncode({
      'name': name,
      'version': version,
      'kind': kind,
      'author': author,
      'risk': risk,
      'description': description,
      'content': content,
      'capabilities': sorted,
    });
  }
}

class PluginBus {
  PluginBus._();

  static const String algPrefix = 'hmac-sha256.';
  static const String builtinMarker = 'builtin';
  static const String defaultAuthor = '本地用户';
  static const String defaultVersion = '1.0.0';

  static const String allowKey = 'plugin_auto_allow';
  static const String denyKey = 'plugin_denied';

  // ------------------------------------------------------------------
  // 能力与风险推导（只信类型+内容，绝不信任库里的 permissions 列，
  // 防止攻击者篡改声明字段绕过授权）
  // ------------------------------------------------------------------
  static List<String> capabilitiesOfRow(Map<String, dynamic> row) {
    final type = (row['type'] as String?) ?? '';
    final content = (row['content'] as String?) ?? '';
    switch (type) {
      case 'mcp':
        return const [PluginCapability.network];
      case 'skill':
        return const [PluginCapability.memory];
      case 'local':
        if (content == 'BUILTIN_VIBRATE') return const [PluginCapability.device];
        if (content == 'BUILTIN_STATUS') return const [PluginCapability.local];
        if (content == 'BUILTIN_SEARCH_MEMORY') {
          return const [PluginCapability.memory];
        }
        if (content == 'BUILTIN_TIME') return const [PluginCapability.local];
        if (content == 'BUILTIN_MONOLOGUE') {
          return const [PluginCapability.memory];
        }
        if (content == 'BUILTIN_URL') {
          return const [PluginCapability.launchApp];
        }
        if (content == 'BUILTIN_CREATE_TOOL') {
          return const [PluginCapability.memory];
        }
        if (content == 'BUILTIN_WEB_SEARCH_CHINA') {
          return const [PluginCapability.network];
        }
        // 自定义 Webhook：一切不以 BUILTIN_ 开头的 local 内容都视为网络 API
        return const [PluginCapability.network];
      default:
        return const [PluginCapability.local];
    }
  }

  static String riskOfRow(Map<String, dynamic> row) {
    final caps = capabilitiesOfRow(row);
    return riskForCapabilities(caps);
  }

  /// 能力 → 风险（公开：供 harness_host 的 PluginSigner 契约适配器复用，
  /// 与 metaOfRow 的推导规则保持唯一来源）
  static String riskForCapabilities(List<String> caps) {
    if (caps.contains(PluginCapability.launchApp) ||
        caps.contains(PluginCapability.settings) ||
        caps.contains(PluginCapability.social) ||
        // 0.75.0：读通知/短信属"看一眼就拿到全部隐私"的能力，按 high 展示
        caps.contains(PluginCapability.notification)) {
      return PluginRisk.high;
    }
    if (caps.contains(PluginCapability.network)) return PluginRisk.medium;
    return PluginRisk.low;
  }

  static String kindOfRow(Map<String, dynamic> row) =>
      (row['type'] as String?) ?? 'local';

  static PluginMeta metaOfRow(Map<String, dynamic> row) {
    return PluginMeta(
      name: (row['name'] as String?) ?? 'unknown',
      version: (row['version'] as String?) ?? defaultVersion,
      kind: kindOfRow(row),
      description: (row['description'] as String?) ?? '',
      content: (row['content'] as String?) ?? '',
      author: (row['author'] as String?) ?? defaultAuthor,
      risk: (row['risk_level'] as String?) ?? riskOfRow(row),
      capabilities: capabilitiesOfRow(row),
    );
  }

  // ------------------------------------------------------------------
  // 签名 / 验签
  // ------------------------------------------------------------------
  static String _hmacHex(String secret, String data) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    return hmac.convert(utf8.encode(data)).toString();
  }

  static String signWithSecret(String secret, PluginMeta meta) {
    return '$algPrefix${_hmacHex(secret, meta.canonical())}';
  }

  /// 验签状态码：builtin / ok / unsigned / tampered
  /// （展示文案见 UI 层的 `mcpSig*` 系列 ARB 键，历史上这里曾有一份
  /// 中文 `statusLabel`，与 UI 重复且无人调用，已删除）
  static String statusOfRow(Map<String, dynamic> row, String secret) {
    final sig = (row['source_sig'] as String?) ?? '';
    if (sig == builtinMarker) return 'builtin';
    if (sig.isEmpty) return 'unsigned';
    if (!sig.startsWith(algPrefix)) return 'tampered';
    final expected = signWithSecret(secret, metaOfRow(row));
    return sig == expected ? 'ok' : 'tampered';
  }

  // ------------------------------------------------------------------
  // 落库 / 升级
  // ------------------------------------------------------------------

  /// 给一行计算完整清单元数据并写回 tools 表（建插件/编辑后调用）。
  static Future<void> stampRow(
    int id, {
    required String name,
    required String type,
    required String description,
    required String content,
    String? version,
    String? author,
  }) async {
    final secret = await DBHelper.getOrCreateDeviceSecret();
    final meta = PluginMeta(
      name: name,
      version: version ?? defaultVersion,
      kind: type,
      description: description,
      content: content,
      author: author ?? defaultAuthor,
      risk: _riskFor(name, type, content),
      capabilities: _capsFor(type, content),
    );
    await DBHelper.stampToolMeta(
      id,
      version: meta.version,
      sourceSig: signWithSecret(secret, meta),
      permissions: jsonEncode(meta.capabilities),
      author: meta.author,
      riskLevel: meta.risk,
    );
  }

  /// 首次升级到插件总线后，把历史遗留的无签名行全部补签（不改变可用性）。
  static Future<void> ensureAllSigned() async {
    final rows = await DBHelper.getAllToolsRaw();
    for (final row in rows) {
      final sig = (row['source_sig'] as String?) ?? '';
      if (sig.isNotEmpty) continue;
      final id = row['id'] as int;
      final name = (row['name'] as String?) ?? 'unknown';
      final type = (row['type'] as String?) ?? 'local';
      final description = (row['description'] as String?) ?? '';
      final content = (row['content'] as String?) ?? '';
      final version = (row['version'] as String?) ?? defaultVersion;
      await stampRow(
        id,
        name: name,
        type: type,
        description: description,
        content: content,
        version: version,
      );
    }
  }

  // ------------------------------------------------------------------
  // 授权（能力声明 → 首次弹窗 → 持久化）
  // ------------------------------------------------------------------
  static bool isGranted(String pluginName, List<String> caps) {
    // 低风险能力无需授权；其余按插件维度一次性授权
    final risk = _riskForCaps(caps);
    return risk == PluginRisk.low;
  }

  static Future<bool> hasGrant(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final allow = prefs.getStringList(allowKey) ?? const [];
    return allow.contains(key);
  }

  static Future<void> grant(String key) async {
    final prefs = await SharedPreferences.getInstance();
    // 注意：必须拷贝成可修改列表——`const []` 是不可变空列表，
    // 首次授权时对它 add 会抛 UnsupportedError，被权限闸兜成"异常"。
    final allow =
        List<String>.from(prefs.getStringList(allowKey) ?? const <String>[]);
    if (!allow.contains(key)) {
      allow.add(key);
      await prefs.setStringList(allowKey, allow);
    }
    // 授权即清空既往拒绝记录
    final denied =
        List<String>.from(prefs.getStringList(denyKey) ?? const <String>[]);
    if (denied.contains(key)) {
      denied.remove(key);
      await prefs.setStringList(denyKey, denied);
    }
  }

  static Future<bool> isDenied(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(denyKey) ?? const []).contains(key);
  }

  static Future<void> deny(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final denied =
        List<String>.from(prefs.getStringList(denyKey) ?? const <String>[]);
    if (!denied.contains(key)) {
      denied.add(key);
      await prefs.setStringList(denyKey, denied);
    }
  }

  /// 吊销：关闭插件或删除插件时调用，授权必须随插件一起失效。
  static Future<void> revoke(String pluginName) async {
    final prefs = await SharedPreferences.getInstance();
    final allow = prefs.getStringList(allowKey) ?? const [];
    final denied = prefs.getStringList(denyKey) ?? const [];
    final next = allow
        .where((k) => k != pluginName && k != 'mcp:$pluginName')
        .toList();
    final nextDenied = denied
        .where((k) => k != pluginName && k != 'mcp:$pluginName')
        .toList();
    if (next.length != allow.length) {
      await prefs.setStringList(allowKey, next);
    }
    if (nextDenied.length != denied.length) {
      await prefs.setStringList(denyKey, nextDenied);
    }
  }

  static Future<bool> hasGrantFor(String pluginName, bool isMcp) async {
    return hasGrant(isMcp ? 'mcp:$pluginName' : pluginName);
  }

  // ------------------------------------------------------------------
  // 内部推导（与 metaOfRow 保持一致；防止误用库里的声明字段）
  // ------------------------------------------------------------------
  static String _riskFor(String name, String type, String content) {
    final caps = _capsFor(type, content);
    return _riskForCaps(caps);
  }

  static String _riskForCaps(List<String> caps) {
    if (caps.contains(PluginCapability.launchApp) ||
        caps.contains(PluginCapability.settings) ||
        caps.contains(PluginCapability.social)) {
      return PluginRisk.high;
    }
    if (caps.contains(PluginCapability.network)) return PluginRisk.medium;
    return PluginRisk.low;
  }

  static List<String> _capsFor(String type, String content) {
    final row = <String, dynamic>{'type': type, 'content': content};
    return capabilitiesOfRow(row);
  }
}
