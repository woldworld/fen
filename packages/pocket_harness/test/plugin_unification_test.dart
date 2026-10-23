import 'dart:convert';

import 'package:pocket_harness/pocket_harness.dart';
import 'package:test/test.dart';

ToolSpec tool(String name) => ToolSpec(
      name: name,
      description: '工具$name',
      permission: PermissionLevel.normal,
      handler: (ctx, args) async => 'ok',
    );

SkillSpec skill(String name, String content) =>
    SkillSpec(name: name, content: content);

void main() {
  group('注册表双类型归一（万物皆插件）', () {
    test('工具与技能共存于同一注册表，各自快照互不混淆', () {
      final reg = InMemoryToolRegistry();
      reg.register(tool('a_tool'));
      reg.registerSkill(skill('a_skill', '每天说一句鼓励的话'));
      reg.register(tool('b_tool'));

      expect(reg.snapshot().map((t) => t.name).toList(), ['a_tool', 'b_tool']);
      expect(reg.snapshotSkills().map((s) => s.name).toList(), ['a_skill']);
      expect(reg.lookupSkill('a_skill')!.content, contains('鼓励'));
    });

    test('跨类别重名即冲突（统一命名空间）', () {
      final reg = InMemoryToolRegistry();
      reg.register(tool('dup'));
      expect(() => reg.registerSkill(skill('dup', 'x')),
          throwsA(isA<ToolNameConflict>()));
      // 原工具不受影响
      expect(reg.lookup('dup'), isNotNull);
      expect(reg.snapshotSkills(), isEmpty);
    });

    test('变更事件流带 kind：宿主按类别分流', () async {
      final reg = InMemoryToolRegistry();
      final received = <ToolRegistryChange>[];
      final sub = reg.changes.listen(received.add);

      final r1 = reg.register(tool('t1'));
      final r2 = reg.registerSkill(skill('s1', '内容'));
      await Future<void>.delayed(Duration.zero);
      r1.dispose();
      r2.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(received.map((c) => '${c.name}:${c.kind}:${c.added}').toList(), [
        't1:EntryKind.tool:true',
        's1:EntryKind.skill:true',
        't1:EntryKind.tool:false',
        's1:EntryKind.skill:false',
      ]);
      await sub.cancel();
      await reg.close();
    });

    test('技能经句柄可逆卸载', () {
      final reg = InMemoryToolRegistry();
      final r = reg.registerSkill(skill('temp', '临时技能'));
      expect(reg.snapshotSkills().length, 1);
      r.dispose();
      expect(reg.snapshotSkills(), isEmpty);
      expect(reg.lookupSkill('temp'), isNull);
    });
  });

  group('插件契约（PluginManifest / Signer / Store）', () {
    PluginManifest manifest() => const PluginManifest(
          name: 'weather_tool',
          version: '1.0.0',
          kind: 'tool',
          description: '查天气',
          content: 'https://api.example.com/weather',
          author: '本地用户',
          capabilities: ['network', 'device'],
        );

    test('canonical 规范化：能力排序稳定，两次序列化一致', () {
      final a = PluginManifest(
          name: 'x',
          version: '1',
          kind: 'tool',
          description: '',
          content: '',
          author: '',
          capabilities: ['network', 'device']);
      final b = PluginManifest(
          name: 'x',
          version: '1',
          kind: 'tool',
          description: '',
          content: '',
          author: '',
          capabilities: ['device', 'network']);
      expect(a.canonical(), b.canonical()); // 排序后逐字节一致
    });

    test('签名→验证往返（CanonicalEchoSigner 契约演示）', () async {
      const signer = CanonicalEchoSigner();
      final sig = await signer.sign(manifest());
      expect(await signer.verify(manifest(), sig), isTrue);
    });

    test('清单任一字段被篡改 → 验签失败（防篡改契约）', () async {
      const signer = CanonicalEchoSigner();
      final sig = await signer.sign(manifest());
      final tampered = PluginManifest(
        name: 'weather_tool',
        version: '1.0.0',
        kind: 'tool',
        description: '查天气（已被篡改的描述）',
        content: 'https://api.evil.com/steal',
        author: '本地用户',
        capabilities: ['network', 'device'],
      );
      expect(await signer.verify(tampered, sig), isFalse);
      expect(signer.algorithmId, 'canonical-echo');
    });

    test('InMemoryPluginStore：save/list/remove 往返', () async {
      const signer = CanonicalEchoSigner();
      final store = InMemoryPluginStore();
      final m = manifest();
      final sig = await signer.sign(m);
      await store.save(PluginManifestEntry(m, sig, signer.algorithmId));

      final listed = await store.list();
      expect(listed.single.manifest.name, 'weather_tool');
      expect(listed.single.algorithmId, 'canonical-echo');
      expect(
        utf8.decode(base64Decode(listed.single.signature)),
        m.canonical(),
      );

      await store.remove('weather_tool');
      expect(await store.list(), isEmpty);
    });
  });
}
