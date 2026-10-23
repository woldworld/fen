import 'dart:io';

import 'package:pocket_harness/pocket_harness.dart';
import 'package:test/test.dart';

ToolContext ctx() => ToolContext(
      log: (tag, msg) {},
      searchMemory: (k) async => 'mem:$k',
      httpClient: HttpClient(),
    );

ToolSpec spec(String name, String desc) => ToolSpec(
      name: name,
      description: desc,
      permission: PermissionLevel.normal,
      handler: (ctx, args) async => 'ok',
    );

void main() {
  group('McpConnectionManager.namespace', () {
    test('合法字符保留，非法清洗，含服务与工具名', () {
      // 中文服务名每字清洗为一个下划线
      expect(McpConnectionManager.namespace('天气服务', 'get-weather'),
          'mcp______get_weather');
      expect(McpConnectionManager.namespace('docs', 'search'),
          'mcp_docs_search');
    });

    test('超长截断到 64 字符', () {
      final ns = McpConnectionManager.namespace(
          'a-very-long-server-name', 't' * 80);
      expect(ns.length, lessThanOrEqualTo(64));
    });
  });

  group('McpConnectionManager 状态机', () {
    test('不可达服务器：failed 状态 + 错误可观测（不再静默失败）', () async {
      final mgr = McpConnectionManager();
      final updates = <McpServerUpdate>[];
      final sub = mgr.updates.listen(updates.add);

      final result = await mgr.loadServer(
        name: 'ghost',
        url: Uri.parse('http://127.0.0.1:1'),
        ctx: ctx(),
        timeout: const Duration(seconds: 3),
      );
      expect(result.state, McpState.failed);
      expect(result.error, isNotNull);
      expect(result.tools, isEmpty);

      final st = mgr.statusOf('ghost');
      expect(st.state, McpState.failed);
      expect(st.lastError, isNotNull);

      await Future<void>.delayed(Duration.zero);
      expect(updates.map((u) => u.state).toList(),
          containsAll([McpState.connecting, McpState.failed]));
      await sub.cancel();
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('ToolSearch 关键词降级版', () {
    final specs = [
      spec('web_search', '全网搜索工具，查新闻资料'),
      spec('get_current_time', '获取当前时间'),
      spec('send_email', '发送电子邮件给联系人'),
      spec('play_music', '播放音乐歌曲'),
    ];

    test('中文 query：名称与描述均参与打分', () {
      final hits = ToolSearch.rank('搜索一下今天的新闻', specs);
      expect(hits.first.spec.name, 'web_search');
    });

    test('英文 query：整词匹配', () {
      final hits = ToolSearch.rank('send email', specs);
      expect(hits.first.spec.name, 'send_email');
      expect(hits, everyElement(isA<ScoredTool>()));
    });

    test('无命中：返回空（显式结果而非硬凑）', () {
      expect(ToolSearch.rank('zzzz', specs), isEmpty);
    });

    test('top-N 截断与得分排序', () {
      final broad = [
        spec('a_search', '搜索 search 搜索'),
        spec('b_search', 'search'),
        spec('c_other', '无关'),
      ];
      final hits = ToolSearch.rank('search', broad, top: 2);
      expect(hits.length, 2);
      expect(hits.first.spec.name, 'a_search'); // 名称×3+描述×1 > 仅描述
      expect(hits.last.spec.name, 'b_search');
    });

    test('grantKey 透传：MCP 工具共享服务级授权键', () {
      final s = ToolSpec(
        name: 'mcp_docs_search',
        description: 'x',
        permission: PermissionLevel.sensitive,
        grantKey: 'mcp:docs',
        handler: (ctx, args) async => 'ok',
      );
      expect(s.grantKey, 'mcp:docs');
      final fallback = spec('plain', 'plain');
      expect(fallback.grantKey, isNull); // 未设置时由策略回退到工具名
    });
  });
}
