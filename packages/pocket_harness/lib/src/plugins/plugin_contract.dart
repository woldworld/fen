import 'dart:convert';

/// 插件清单：一个待加载插件（工具/技能/MCP 服务）的全部可签名内容。
///
/// "万物皆插件"的契约层：清单 + 签名 + 能力声明。包内只定义契约——
/// 签名算法（HMAC 设备密钥 / Ed25519 / 远程签发）与存储后端
///（SQLite / 远程商店）由宿主实现注入，与 PermissionPolicy 同一模式。
class PluginManifest {
  final String name;
  final String version;
  final String kind; // tool / mcp / skill（宿主词汇表）
  final String description;
  final String content;
  final String author;

  /// 能力声明（不透明字符串，由宿主词汇表定义，如 'network'/'device'）。
  /// 契约层不做语义解读——授权等级仍由宿主从可信来源推导，
  /// **绝不从清单反推**（防篡改设计：声明字段可被篡改）。
  final List<String> capabilities;

  const PluginManifest({
    required this.name,
    required this.version,
    required this.kind,
    required this.description,
    required this.content,
    required this.author,
    required this.capabilities,
  });

  /// 规范化序列化：键序固定、能力排序——签名的载荷。
  /// 任何一处内容被篡改，规范化结果都会改变，签名验证即失败。
  String canonical() {
    final sorted = [...capabilities]..sort();
    return jsonEncode({
      'name': name,
      'version': version,
      'kind': kind,
      'author': author,
      'description': description,
      'content': content,
      'capabilities': sorted,
    });
  }
}

/// 签名器契约：对插件清单做防篡改签名。
abstract class PluginSigner {
  /// 算法标识（如 'hmac-sha256' / 'ed25519'），落盘时与签名一起存储，
  /// 为未来多算法共存与升级留出空间。
  String get algorithmId;

  Future<String> sign(PluginManifest manifest);

  /// 验签：内容或签名任一被篡改必须返回 false（fail-closed 由调用方保证）。
  Future<bool> verify(PluginManifest manifest, String signature);
}

/// 插件存储契约：插件包的持久化后端。
abstract class PluginStore {
  Future<List<PluginManifestEntry>> list();

  /// 保存整条记录（清单 + 签名 + 算法标识）——算法标识由签名器提供，
  /// 存储层只负责持久化，不做密码学判断。
  Future<void> save(PluginManifestEntry entry);

  Future<void> remove(String name);
}

/// 存储条目：清单 + 签名 + 签名算法标识。
class PluginManifestEntry {
  final PluginManifest manifest;
  final String signature;
  final String algorithmId;
  const PluginManifestEntry(this.manifest, this.signature, this.algorithmId);
}

/// 内存实现（测试与本地实验用；宿主持久实现见大荒 harness_host）。
class InMemoryPluginStore implements PluginStore {
  final Map<String, PluginManifestEntry> _entries = {};

  @override
  Future<List<PluginManifestEntry>> list() async =>
      List.unmodifiable(_entries.values);

  @override
  Future<void> save(PluginManifestEntry entry) async =>
      _entries[entry.manifest.name] = entry;

  @override
  Future<void> remove(String name) async => _entries.remove(name);
}

/// 契约测试常用的参考实现：规范化文本直接作为"签名"（无密码学强度，
/// 仅用于测试签名/验证的往返语义，生产宿主必须用真签名器）。
class CanonicalEchoSigner implements PluginSigner {
  const CanonicalEchoSigner();
  @override
  String get algorithmId => 'canonical-echo';
  @override
  Future<String> sign(PluginManifest m) async => base64Encode(utf8.encode(m.canonical()));
  @override
  Future<bool> verify(PluginManifest m, String signature) async =>
      base64Encode(utf8.encode(m.canonical())) == signature;
}
