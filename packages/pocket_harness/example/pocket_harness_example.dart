/// pocket_harness 30 秒导览：注册表 → 权限闸 → 桥接 → 会话 → dsh 兼容层。
///
/// 纯 Dart，无需 API Key，无需 Flutter：
///   dart run example/pocket_harness_example.dart
import 'dart:io';

import 'package:pocket_harness/pocket_harness.dart';

/// 演示用策略：critical 档一律拒绝，其余放行（真实策略在宿主实现）。
class DemoPolicy implements PermissionPolicy {
  const DemoPolicy();

  @override
  Future<PermissionDecision> check(ToolSpec tool, Map<String, dynamic> args) {
    return Future.value(
        tool.permission == PermissionLevel.critical
            ? const Deny('critical 工具需要主人现场确认')
            : const Allow());
  }
}

Future<void> main() async {
  final ctx = ToolContext(
    log: (tag, msg) => print('  [log] $tag: $msg'),
    searchMemory: (_) async => '（宿主记忆检索未接入）',
    httpClient: HttpClient(),
  );

  // ── 1. 万物皆插件：工具与技能同一注册表，注册即可逆 ──────────────────
  final registry = InMemoryToolRegistry();
  registry.register(buildWebFetchTool());
  registry.register(ToolSpec(
    name: 'get_time',
    description: '获取当前时间',
    permission: PermissionLevel.normal,
    inputSchema: Schema.object(properties: {
      'greeting': Schema.string(description: '问候语前缀'),
    }),
    handler: (ctx, args) async =>
        '${args['greeting'] ?? '现在时间是'} ${DateTime.now().toIso8601String()}',
  ));
  final skillReg =
      registry.registerSkill(SkillSpec(name: 'tone', content: '始终用温和语气'));
  print('① 注册表：${registry.snapshot().map((t) => t.name).toList()}'
      ' + 技能 ${registry.snapshotSkills().map((s) => s.name).toList()}');

  // ── 2. 桥接 + 权限闸：bridgeTool 产出 dartantic Tool，闸前置、异常收口 ──
  final timeTool = registry.lookup('get_time')!;
  final bridged = bridgeTool(timeTool, ctx, policy: const DemoPolicy());
  final result = await bridged.onCall({'greeting': '现在是'});
  print('② 桥接执行 get_time → $result');

  // critical 工具被策略拒绝时，handler 不会执行，LLM 收到拒绝原因
  final dangerous = ToolSpec(
    name: 'wipe_db',
    description: '清空数据库',
    permission: PermissionLevel.critical,
    handler: (ctx, args) async => '（不应被执行）',
  );
  final denied = await bridgeTool(dangerous, ctx, policy: const DemoPolicy())
      .onCall({});
  print('   桥接执行 wipe_db → $denied');

  // ── 3. 会话轨迹：append-only，游标幂等回放 ────────────────────────────
  final store = InMemorySessionStore();
  await store.open('demo');
  await store.append('demo',
      SessionEvent(type: 'user_message', data: {'text': '我们约好周五去图书馆'}));
  await store.append(
      'demo',
      SessionEvent(
          type: 'assistant_message', data: {'text': '好的，已记下周五图书馆之约'}));
  final history = await store.replay('demo');
  print('③ 会话回放：${history.length} 条事件，最后一条 = '
      '${history.last.data['text']}');

  // ── 4. 内置会话检索工具：模型侧"回忆" ─────────────────────────────────
  final search = buildSessionSearchTool(store: store, threadId: () => 'demo');
  print('④ session_search("图书馆") →');
  print(_indent(await search.handler(ctx, {'query': '图书馆'})));

  // ── 5. 可逆卸载：事件流广播变更，热插拔的基础 ─────────────────────────
  skillReg.dispose();
  print('⑤ 卸载技能后：技能 ${registry.snapshotSkills().length} 个');

  // ── 6. DeepSeek Harness 兼容层：技能直译 + patch 盘点 + MCP 命名互转 ──
  final imported = DshSkillImporter.import({
    'web-research': '---\nname: web-research\ndescription: 多轮网页调研\n---\n步骤：先搜索再交叉验证',
    '中文技能': '无 frontmatter 的中文名技能',
  });
  print('⑥ dsh 技能直译：接受 ${imported.accepted.map((s) => s.name).toList()}，'
      '拒绝 ${imported.rejected.keys.toList()}');
  print('   MCP 命名互转 mcp__memorix__search → '
      '${DshNames.dshMcpToolToOurs('mcp__memorix__search')}');
  print('   web_fetch 覆盖判定 → ${DshToolMap.classify('web_fetch').coverage}');

  ctx.httpClient.close();
}

String _indent(String s) =>
    s.split('\n').map((l) => '   $l').join('\n');
