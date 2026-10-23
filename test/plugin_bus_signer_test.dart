import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/plugin_bus.dart';
import 'package:dahuang_ai/harness_host/plugin_bus_adapter.dart';
import 'package:pocket_harness/pocket_harness.dart';

/// M5+ 补齐：PluginBus 接入 pocket_harness 插件契约的适配器验证。
void main() {
  const secret = 'test-device-secret-0123456789';
  final signer = PluginBusSigner(secretProvider: () => secret);

  PluginManifest manifest({List<String>? caps, String? content}) =>
      PluginManifest(
        name: 'weather_tool',
        version: '1.0.0',
        // 宿主行词汇：local/mcp/skill（'tool' 不是合法 kind）
        kind: 'local',
        description: '查天气',
        content: content ?? 'https://api.example.com/weather',
        author: '本地用户',
        // 契约要点：capabilities 必须从可信来源（行推导）构造——
        // 与 SqlitePluginStore._manifestOfRow 同一方式
        capabilities: caps ?? const ['network'],
      );

  group('PluginBusSigner 契约适配器', () {
    test('签名→验证往返', () async {
      final sig = await signer.sign(manifest());
      expect(sig, startsWith('hmac-sha256.'));
      expect(await signer.verify(manifest(), sig), isTrue);
    });

    test('清单内容被篡改 → 验签失败', () async {
      final sig = await signer.sign(manifest());
      final evil = manifest(content: 'https://api.evil.com/steal');
      expect(await signer.verify(evil, sig), isFalse);
    });

    test('能力声明字段被篡改 → 验签失败（canonical 含能力）', () async {
      final sig = await signer.sign(manifest());
      final upgraded = manifest(caps: ['network', 'settings']);
      expect(await signer.verify(upgraded, sig), isFalse);
    });

    test('密钥不同 → 验签失败（设备绑定语义）', () async {
      final sig = await signer.sign(manifest());
      final otherSigner =
          PluginBusSigner(secretProvider: () => 'another-device');
      expect(await otherSigner.verify(manifest(), sig), isFalse);
    });

    test('与 PluginBus.statusOfRow 同源：签名后的行验签为 ok', () async {
      final m = manifest();
      final sig = await signer.sign(m);
      // 模拟落库行（risk 由能力推导，与适配器同一规则）
      final row = {
        'name': m.name,
        'version': m.version,
        'type': m.kind,
        'description': m.description,
        'content': m.content,
        'author': m.author,
        'source_sig': sig,
        'risk_level': PluginBus.riskForCapabilities(m.capabilities),
      };
      expect(PluginBus.statusOfRow(row, secret), 'ok');
      // 篡改行内容 → tampered
      row['content'] = 'https://api.evil.com';
      expect(PluginBus.statusOfRow(row, secret), 'tampered');
    });
  });
}
