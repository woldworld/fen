import 'package:pocket_harness/pocket_harness.dart';

import '../core/db_helper.dart';
import '../core/plugin_bus.dart';

/// pocket_harness `PluginSigner` 契约的宿主适配器（M5 补齐）：
/// 把大荒的"设备密钥 HMAC"签名体系接入包的插件契约——
/// 开源用户可换成 Ed25519 远程签发等任何实现，管线不变。
///
/// 安全边界（与 PluginBus 同源）：
/// - 能力声明只从 type+content 现场推导，**绝不信任清单里自带的能力字段**；
/// - 签名覆盖 canonical 清单（键序固定、能力排序），任何一处篡改即验签失败；
/// - grant/deny 持久化不在签名器职责内（那是 PermissionPolicy 的事）。
class PluginBusSigner implements PluginSigner {
  /// 设备密钥提供者（通常 () => DBHelper.getOrCreateDeviceSecret() 的缓存值）
  final String Function() secretProvider;

  PluginBusSigner({required this.secretProvider});

  @override
  String get algorithmId => PluginBus.algPrefix; // 'hmac-sha256.'

  /// 清单 → PluginMeta（risk 按能力推导，保持与 metaOfRow 唯一来源）
  PluginMeta _metaOf(PluginManifest m) => PluginMeta(
        name: m.name,
        version: m.version,
        kind: m.kind,
        description: m.description,
        content: m.content,
        author: m.author,
        risk: PluginBus.riskForCapabilities(m.capabilities),
        capabilities: m.capabilities,
      );

  @override
  Future<String> sign(PluginManifest manifest) async =>
      PluginBus.signWithSecret(secretProvider(), _metaOf(manifest));

  @override
  Future<bool> verify(PluginManifest manifest, String signature) async =>
      PluginBus.signWithSecret(secretProvider(), _metaOf(manifest)) ==
      signature;
}

/// `PluginStore` 契约的宿主参考实现：落在 tools 表
///（清单字段即表列，签名在 source_sig，算法前缀在签名头）。
/// 与 PluginBus.stampRow / statusOfRow 共享同一套规范化与验签。
class SqlitePluginStore implements PluginStore {
  final String Function() secretProvider;

  SqlitePluginStore({required this.secretProvider});

  PluginManifest _manifestOfRow(Map<String, dynamic> row) => PluginManifest(
        name: (row['name'] as String?) ?? 'unknown',
        version: (row['version'] as String?) ?? PluginBus.defaultVersion,
        kind: PluginBus.kindOfRow(row),
        description: (row['description'] as String?) ?? '',
        content: (row['content'] as String?) ?? '',
        author: (row['author'] as String?) ?? PluginBus.defaultAuthor,
        capabilities: PluginBus.capabilitiesOfRow(row),
      );

  @override
  Future<List<PluginManifestEntry>> list() async {
    final rows = await DBHelper.getAllToolsRaw();
    return [
      for (final row in rows)
        PluginManifestEntry(
          _manifestOfRow(row),
          (row['source_sig'] as String?) ?? '',
          PluginBus.algPrefix,
        ),
    ];
  }

  @override
  Future<void> save(PluginManifestEntry entry) async {
    final m = entry.manifest;
    final dbClient = await DBHelper.db;
    final existing = await dbClient.query('tools',
        where: 'name = ?', whereArgs: [m.name], limit: 1);
    if (existing.isEmpty) {
      // 新插件：入库并盖章（能力/风险按推导，不信任清单）
      final id = await DBHelper.insertTool(
          m.name, m.description, m.kind, m.content);
      await PluginBus.stampRow(
        id,
        name: m.name,
        type: m.kind,
        description: m.description,
        content: m.content,
        version: m.version,
        author: m.author,
      );
    } else {
      // 已存在：按 id 盖章刷新签名元数据
      await PluginBus.stampRow(
        existing.first['id'] as int,
        name: m.name,
        type: m.kind,
        description: m.description,
        content: m.content,
        version: m.version,
        author: m.author,
      );
    }
  }

  @override
  Future<void> remove(String name) async {
    final dbClient = await DBHelper.db;
    final rows = await dbClient.query('tools',
        columns: ['id'], where: 'name = ?', whereArgs: [name], limit: 1);
    if (rows.isNotEmpty) {
      await DBHelper.deleteTool(rows.first['id'] as int);
    }
    await PluginBus.revoke(name); // 插件删除 → 授权随插件失效
  }
}
