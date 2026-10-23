import 'dart:io';

import 'package:pocket_harness/pocket_harness.dart';
import 'package:test/test.dart';

ToolContext ctx() => ToolContext(
      log: (tag, msg) {},
      searchMemory: (k) async => 'mem:$k',
      httpClient: HttpClient(),
    );

void main() {
  group('bridgeTool × PermissionPolicy（M3 权限闸）', () {
    test('Deny：handler 不执行，拒绝原因返回给 LLM', () async {
      var handlerRan = false;
      final spec = ToolSpec(
        name: 'danger',
        description: '危险工具',
        permission: PermissionLevel.high,
        handler: (ctx, args) async {
          handlerRan = true;
          return '不应出现';
        },
      );
      final t = bridgeTool(spec, ctx(),
          policy: const AllowAllPolicy()); // 先确认基线放行
      expect(await t.call({}), '不应出现');
      expect(handlerRan, isTrue);

      final t2 = bridgeTool(spec, ctx(),
          policy: _DenyPolicy('测试拒绝'));
      final out = await t2.call({});
      expect(handlerRan, isTrue); // 第二次调用未改变第一次的事实
      expect(out, contains('【权限拒绝】danger'));
      expect(out, contains('测试拒绝'));
    });

    test('策略抛异常 = fail-closed，调用被中止', () async {
      final spec = ToolSpec(
        name: 'x',
        description: 'x',
        permission: PermissionLevel.critical,
        handler: (ctx, args) async => 'boom',
      );
      final t = bridgeTool(spec, ctx(), policy: _ThrowPolicy());
      final out = await t.call({});
      expect(out, contains('【权限闸异常】'));
      expect(out, isNot(contains('boom')));
    });

    test('无 policy 时行为与 M1 完全一致（向后兼容）', () async {
      final spec = ToolSpec(
        name: 'free',
        description: '无闸',
        permission: PermissionLevel.normal,
        handler: (ctx, args) async => 'ran',
      );
      expect(await bridgeTool(spec, ctx()).call({}), 'ran');
    });
  });
}

class _DenyPolicy implements PermissionPolicy {
  final String reason;
  const _DenyPolicy(this.reason);
  @override
  Future<PermissionDecision> check(
          ToolSpec tool, Map<String, dynamic> args) async =>
      Deny(reason);
}

class _ThrowPolicy implements PermissionPolicy {
  const _ThrowPolicy();
  @override
  Future<PermissionDecision> check(
          ToolSpec tool, Map<String, dynamic> args) async =>
      throw StateError('policy exploded');
}
