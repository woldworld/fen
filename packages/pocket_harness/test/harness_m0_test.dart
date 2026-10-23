import 'dart:io';

import 'package:pocket_harness/pocket_harness.dart';
import 'package:test/test.dart';

ToolSpec tool(String name, {PermissionLevel level = PermissionLevel.normal}) =>
    ToolSpec(
      name: name,
      description: '测试工具 $name',
      permission: level,
      handler: (ctx, args) async => 'ok:$name',
    );

void main() {
  group('ToolRegistry 可逆注册', () {
    test('注册 → 快照有序 → dispose 卸载', () async {
      final reg = InMemoryToolRegistry();
      final r1 = reg.register(tool('a'));
      final r2 = reg.register(tool('b'));

      expect(reg.snapshot().map((t) => t.name).toList(), ['a', 'b']);

      r1.dispose();
      expect(reg.snapshot().map((t) => t.name).toList(), ['b']);
      expect(reg.lookup('a'), isNull);
      expect(reg.lookup('b'), isNotNull);

      // 句柄幂等
      r1.dispose();
      expect(reg.snapshot().length, 1);
      r2.dispose();
      expect(reg.snapshot(), isEmpty);
    });

    test('重名注册抛冲突，原工具不受影响', () {
      final reg = InMemoryToolRegistry();
      reg.register(tool('dup'));
      expect(() => reg.register(tool('dup')), throwsA(isA<ToolNameConflict>()));
      // 抛错后原注册仍完好
      expect(reg.lookup('dup'), isNotNull);
      expect(reg.snapshot().length, 1);
    });

    test('按名字卸载幂等（未注册不炸）', () {
      final reg = InMemoryToolRegistry();
      reg.dispose('no-such-tool'); // 不应抛错
      expect(reg.snapshot(), isEmpty);
    });

    test('changes 事件流广播增删', () async {
      final reg = InMemoryToolRegistry();
      final received = <ToolRegistryChange>[];
      final sub = reg.changes.listen(received.add);

      final r = reg.register(tool('x'));
      await Future<void>.delayed(Duration.zero);
      r.dispose();
      reg.dispose('y'); // 未注册：不产生事件
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 2);
      expect(received[0].name, 'x');
      expect(received[0].added, isTrue);
      expect(received[1].name, 'x');
      expect(received[1].added, isFalse);

      await sub.cancel();
      await reg.close();
    });
  });

  group('SessionStore append-only 轨迹', () {
    test('open → append → replay 全量与增量游标', () async {
      final store = InMemorySessionStore();
      final s = await store.open('chat-1');
      expect(s.events, isEmpty);

      final e1 = SessionEvent(type: 'user_message', data: {'text': '你好'});
      final e2 = SessionEvent(type: 'assistant_message', data: {'text': '在的'});
      final e3 = SessionEvent(type: 'tool_call', data: {'name': 'web_search'});
      await store.append('chat-1', e1);
      await store.append('chat-1', e2);
      await store.append('chat-1', e3);

      final all = await store.replay('chat-1');
      expect(all.map((e) => e.type).toList(),
          ['user_message', 'assistant_message', 'tool_call']);

      // 游标幂等：after=e1 的序号 → 只剩 e2/e3
      final after1 = await store.replay('chat-1', after: store.seqOf(e1));
      expect(after1.length, 2);
      expect(after1.first.type, 'assistant_message');

      // 游标到最新 → 空
      final afterAll = await store.replay('chat-1', after: store.seqOf(e3));
      expect(afterAll, isEmpty);
    });

    test('未 open 直接 append 抛 StateError（fail-closed）', () async {
      final store = InMemorySessionStore();
      expect(
        () => store.append('ghost', SessionEvent(type: 'user_message', data: {})),
        throwsA(isA<StateError>()),
      );
    });

    test('事件 JSON 往返（持久化宿主实现的序列化契约）', () {
      final e = SessionEvent(
        type: 'tool_result',
        data: {'name': 'x', 'output': 'done'},
        ts: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final back = SessionEvent.fromJson(e.toJson());
      expect(back.type, 'tool_result');
      expect(back.data['output'], 'done');
      expect(back.ts, e.ts);
    });
  });

  group('权限策略接口', () {
    test('AllowAllPolicy 放行（仅测试用）', () async {
      const policy = AllowAllPolicy();
      final d = await policy.check(tool('t', level: PermissionLevel.critical), {});
      expect(d, isA<Allow>());
    });

    test('PermissionLevel.parse 容错', () {
      expect(PermissionLevel.parse('high'), PermissionLevel.high);
      expect(PermissionLevel.parse('critical'), PermissionLevel.critical);
      expect(PermissionLevel.parse('乱写'), PermissionLevel.normal);
      expect(PermissionLevel.parse(null), PermissionLevel.normal);
    });
  });

  group('ToolContext 注入', () {
    test('宿主能力经构造注入（不 import 任何宿主实现）', () async {
      final ctx = ToolContext(
        log: (tag, msg) {},
        searchMemory: (k) async => 'mem:$k',
        httpClient: HttpClient(),
      );
      expect(await ctx.searchMemory('天气'), 'mem:天气');
    });
  });

  group('ToolSpec', () {
    test('hasParameters 由 schema 有无决定', () {
      expect(tool('a').hasParameters, isFalse);
      final withSchema = ToolSpec(
        name: 'b',
        description: '带参',
        permission: PermissionLevel.normal,
        inputSchema: Schema.object(properties: {
          'query': Schema.string(),
        }, required: ['query']),
        handler: (ctx, args) async => args['query'].toString(),
      );
      expect(withSchema.hasParameters, isTrue);
    });
  });
}
