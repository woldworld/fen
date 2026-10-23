import 'dart:io';

import 'package:pocket_harness/pocket_harness.dart';
import 'package:test/test.dart';

void main() {
  ToolContext ctx() => ToolContext(
        log: (tag, msg) {},
        searchMemory: (k) async => 'mem:$k',
        httpClient: HttpClient(),
      );

  group('bridgeTool：ToolSpec → dartantic Tool', () {
    test('名字/描述透传，handler 收到原始参数', () async {
      final spec = ToolSpec(
        name: 'echo',
        description: '回声测试',
        permission: PermissionLevel.normal,
        inputSchema: Schema.object(properties: {'text': Schema.string()}),
        handler: (ctx, args) async => 'got:${args['text']}',
      );
      final t = bridgeTool(spec, ctx());
      expect(t.name, 'echo');
      expect(t.description, '回声测试');
      final out = await t.call({'text': '你好'});
      expect(out, 'got:你好');
    });

    test('无参工具（schema 为 null）可用空参数调用', () async {
      final spec = ToolSpec(
        name: 'tick',
        description: '无参',
        permission: PermissionLevel.normal,
        handler: (ctx, args) async => 'args:${args.length}',
      );
      final out = await bridgeTool(spec, ctx()).call({});
      expect(out, 'args:0');
    });

    test('handler 抛异常收口为错误字符串（fail-soft，不炸整轮对话）', () async {
      final spec = ToolSpec(
        name: 'boom',
        description: '会炸',
        permission: PermissionLevel.normal,
        handler: (ctx, args) async => throw StateError('爆炸了'),
      );
      final out = await bridgeTool(spec, ctx()).call({});
      expect(out, contains('【工具执行异常】boom'));
      expect(out, contains('爆炸了'));
    });

    test('与 ToolRegistry 端到端：注册 → 桥接 → 调用 → 卸载', () async {
      final reg = InMemoryToolRegistry();
      final spec = ToolSpec(
        name: 'plus',
        description: '加法',
        permission: PermissionLevel.normal,
        inputSchema: Schema.object(properties: {
          'a': Schema.integer(),
          'b': Schema.integer(),
        }, required: ['a', 'b']),
        handler: (ctx, args) async =>
            '${(args['a'] as int) + (args['b'] as int)}',
      );
      final reg1 = reg.register(spec);
      final built = [for (final s in reg.snapshot()) bridgeTool(s, ctx())];
      expect(built.single.name, 'plus');
      expect(await built.single.call({'a': 2, 'b': 3}), '5');

      reg1.dispose();
      expect(reg.snapshot(), isEmpty);
    });
  });
}
