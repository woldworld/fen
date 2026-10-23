import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:pocket_harness/pocket_harness.dart';
import 'package:test/test.dart';

Agent _unreachableAgent() => Agent.forProvider(
      OpenAIProvider(
          apiKey: 'test-key', baseUrl: Uri.parse('http://127.0.0.1:1')),
      chatModelName: 'test-model',
    );

Agent _agentAt(int port) => Agent.forProvider(
      OpenAIProvider(
          apiKey: 'test-key',
          baseUrl: Uri.parse('http://127.0.0.1:$port')),
      chatModelName: 'test-model',
    );

/// 起一个**假的 OpenAI 端点**并统计请求数。
///
/// 为什么用 400/500 能干净地计数：`openai_dart` 的重试器只重试 429 与
/// **幂等方法**的 5xx（见 retry_wrapper.dart `_shouldRetry`），而 chat
/// completions 走 **POST（非幂等）** ⇒ 任何 4xx/5xx 都**只发一次**。
/// 于是 hits 的长度 == 这一轮真实发出的 HTTP 次数。
Future<(HttpServer, List<String>)> _startMockServer(
  int status, {
  String? sseText,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final hits = <String>[];
  server.listen((req) async {
    final body = await utf8.decoder.bind(req).join();
    hits.add(body);
    if (status != 200 || sseText == null) {
      req.response
        ..statusCode = status
        ..write('{"error":{"message":"mock","type":"mock"}}');
      await req.response.close();
      return;
    }
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType('text', 'event-stream', charset: 'utf-8');
    // 必须按 UTF-8 写字节：HttpResponse.write 默认 ISO-8859-1，中文会抛
    // "Contains invalid characters"。SSE 载荷里有中文 ⇒ 走 add(utf8.encode(..))。
    void send(String s) => req.response.add(utf8.encode(s));
    void chunk(Map<String, Object?> delta, String? finish) {
      send('data: ${jsonEncode({
            'id': 'c1',
            'object': 'chat.completion.chunk',
            'created': 0,
            'model': 'mock',
            'choices': [
              {'index': 0, 'delta': delta, 'finish_reason': finish}
            ],
          })}\n\n');
    }

    chunk({'role': 'assistant', 'content': sseText}, null);
    chunk(<String, Object?>{}, 'stop');
    send('data: [DONE]\n\n');
    await req.response.close();
  });
  return (server, hits);
}

void main() {
  group('AgentReply', () {
    test('fromJson 缺字段兜底，不让单轮对话失败', () {
      final r = AgentReply.fromJson({'reply': '你好'});
      expect(r.reply, '你好');
      expect(r.topic, '日常交流');
      expect(r.keywords, '');

      final r2 = AgentReply.fromJson({'reply': 'hi', 'topic': '', 'keywords': null});
      expect(r2.topic, '日常交流');
      expect(r2.keywords, '');
    });

    test('outputSchema 必含 reply/topic/keywords', () {
      final s = AgentReply.outputSchema;
      expect(s.toString(), contains('reply'));
      expect(s.toString(), contains('topic'));
      expect(s.toString(), contains('keywords'));
    });
  });

  group('AgentRuntime.buildHistory（纯函数，离线可测）', () {
    test('system 置顶 + user/assistant 角色映射', () {
      final events = [
        SessionEvent(type: 'user_message', data: {'text': '你好'}),
        SessionEvent(type: 'assistant_message', data: {'text': '在的'}),
        SessionEvent(type: 'system_note', data: {'text': '应被忽略'}),
      ];
      final h = AgentRuntime.buildHistory(
          systemPrompt: 'SYS', events: events, maxEvents: 40);
      expect(h.length, 3);
      expect(h.first.role, ChatMessageRole.system);
      expect(h[1].role, ChatMessageRole.user);
      expect(h[2].role, ChatMessageRole.model);
    });

    test('maxEvents 窗口取最近 N 条', () {
      final events = [
        for (var i = 0; i < 10; i++) ...[
          SessionEvent(type: 'user_message', data: {'text': 'u$i'}),
          SessionEvent(type: 'assistant_message', data: {'text': 'a$i'}),
        ]
      ];
      final h = AgentRuntime.buildHistory(
          systemPrompt: 'SYS', events: events, maxEvents: 6);
      // 6 条窗口 + system
      expect(h.length, 7);
      expect(h[1].parts.first.toString(), contains('u7'));
    });

    test('空 text 事件跳过', () {
      final events = [
        SessionEvent(type: 'user_message', data: {'text': ''}),
        SessionEvent(type: 'assistant_message', data: {'other': 1}),
        SessionEvent(type: 'user_message', data: {'text': '在吗'}),
      ];
      final h = AgentRuntime.buildHistory(
          systemPrompt: 'SYS', events: events, maxEvents: 40);
      expect(h.length, 2); // system + 1 条有效
    });
  });

  group('AgentRuntime.turn 降级链', () {
    test('agentSource 为 null：no_agent 降级，不抛错', () async {
      final rt = AgentRuntime(agentSource: () => null);
      final out = await rt.turn(systemPrompt: 's', message: 'hi');
      expect(out.degraded, isTrue);
      expect(out.degradeReason, 'no_agent');
      expect(out.reply, contains('请配置 API Key'));
    });

    test('结构化与普通 send 全失败 → 离线 fallback 接管，用户消息仍落盘', () async {
      final store = InMemorySessionStore();
      await store.open('t1');
      final rt = AgentRuntime(
        agentSource: _unreachableAgent, // 127.0.0.1:1 立即拒绝连接
        fallback: (sys, msg) async => '本地兜底回复',
        // dartantic 内部有 HTTP 重试，超时给小值让降级链快速走完
        timeout: const Duration(seconds: 3),
      );
      final out = await rt.turn(
          systemPrompt: 's', message: '帮我查天气', sessions: store, sessionId: 't1');
      expect(out.degraded, isTrue);
      expect(out.degradeReason, contains('offline_fallback'));
      expect(out.reply, contains('本地兜底回复'));

      // 轨迹完整性：用户消息 + 降级回复都落了盘
      final events = await store.replay('t1');
      expect(events.map((e) => e.type).toList(),
          ['user_message', 'assistant_message']);
      expect(events.first.data['text'], '帮我查天气');
      expect(events.last.data['text'], contains('本地兜底回复'));
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('无 fallback 且全失败 → rethrow 给宿主 UX 兜底', () async {
      final rt = AgentRuntime(
        agentSource: _unreachableAgent,
        timeout: const Duration(seconds: 3),
      );
      await expectLater(
        rt.turn(systemPrompt: 's', message: 'hi'),
        throwsA(isA<Object>()),
      );
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  // ★ 0.66.0：主路径改「一次请求、两种解读」后，用**真实 HTTP 计数**钉住
  //   "一轮对话到底发了几次请求"。这是"用户看得见的才算 1 次对话"口径的
  //   客户端侧不变式：任何情况下，一轮最多 1 次（试用模式下绝不补发第二次）。
  group('AgentRuntime.turn 单请求口径（同轮双计修复）', () {
    test('tryDecodeReply：只认 JSON 对象，其余一律 null（供复用原文）', () {
      expect(AgentRuntime.tryDecodeReply('{"reply":"hi","topic":"问好"}'),
          isNotNull);
      expect(AgentRuntime.tryDecodeReply('{"reply":"hi"}')!.reply, 'hi');
      // 纯文本 / 空串 / JSON 非对象 ⇒ null（调用方按纯文本复用，不补发请求）
      expect(AgentRuntime.tryDecodeReply('我是分身，你好呀'), isNull);
      expect(AgentRuntime.tryDecodeReply('   '), isNull);
      expect(AgentRuntime.tryDecodeReply('[1,2,3]'), isNull);
      expect(AgentRuntime.tryDecodeReply('"just a string"'), isNull);
    });

    test('模型回纯文本：只发一次请求，复用同一响应（不补发）', () async {
      final (server, hits) = await _startMockServer(200, sseText: '我是分身，你好呀');
      addTearDown(() => server.close(force: true));
      final rt = AgentRuntime(
        agentSource: () => _agentAt(server.port),
        allowPlainRetry: () async => false, // 试用模式
        timeout: const Duration(seconds: 10),
      );
      final out = await rt.turn(systemPrompt: 's', message: 'hi');
      expect(hits.length, 1, reason: '同一轮只允许一次真实请求');
      expect(out.degraded, isTrue);
      expect(out.reply, contains('我是分身'));
      expect(out.degradeReason,
          'structured_output_unparsed_reused_response');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('正控：上游拒绝 schema 时，补发开关决定 1 次还是 2 次', () async {
      // 一律 400（POST 非幂等 ⇒ 客户端不重试）—— 模拟"上游不支持 schema"
      final (server, hits) = await _startMockServer(400);
      addTearDown(() => server.close(force: true));

      // ① 允许补发（自有 Key 场景）：主路径 + 补发 = 2 次
      final rtOn = AgentRuntime(
        agentSource: () => _agentAt(server.port),
        allowPlainRetry: () async => true,
        fallback: (s, m) async => '兜底',
        timeout: const Duration(seconds: 10),
      );
      final o1 = await rtOn.turn(systemPrompt: 's', message: 'hi');
      expect(hits.length, 2, reason: '允许补发 ⇒ 这一轮发了两次');
      expect(o1.degraded, isTrue);

      // ② 禁止补发（试用模式）：主路径失败即止，**只有 1 次**
      hits.clear();
      final rtOff = AgentRuntime(
        agentSource: () => _agentAt(server.port),
        allowPlainRetry: () async => false,
        fallback: (s, m) async => '兜底',
        timeout: const Duration(seconds: 10),
      );
      final o2 = await rtOff.turn(systemPrompt: 's', message: 'hi');
      expect(hits.length, 1, reason: '试用模式禁止补发 ⇒ 只发一次');
      expect(o2.degraded, isTrue);
    }, timeout: const Timeout(Duration(seconds: 90)));
  });

  // ★★ 0.80.0（真机"改 app 主题卡住"根因）：一次请求里同时下发
  //   `response_format(json_schema, strict)` 与 `tools`，会被 DeepSeek / Kimi /
  //   DashScope 等 OpenAI 兼容端点**优先满足 response_format 而跳过工具调用**
  //   ⇒ `tool_calls` 永不产生，分身只回话不动手。口径 = **有工具就不发 schema**。
  //   这里用**真实请求体**断言，不靠读源码 —— 防止"改回注释、改不回行为"。
  group('AgentRuntime 结构化输出 vs 工具调用（0.80.0 根因）', () {
    test('chooseOutputSchema：有工具 ⇒ null（工具优先）', () {
      expect(AgentRuntime.chooseOutputSchema(hasTools: true), isNull);
      expect(AgentRuntime.chooseOutputSchema(hasTools: false), isNotNull);
    });

    test('有工具：请求体带 tools、**不带 response_format**', () async {
      final (server, hits) =
          await _startMockServer(200, sseText: '好的主人，这就给您换成粉色调～');
      addTearDown(() => server.close(force: true));
      final rt = AgentRuntime(
        agentSource: () => _agentWithToolsAt(server.port),
        hasTools: () => true,
        allowPlainRetry: () async => false,
        timeout: const Duration(seconds: 10),
      );
      final out = await rt.turn(systemPrompt: 's', message: '改成粉色主题');
      expect(hits.length, 1);
      final body = jsonDecode(hits.first) as Map<String, dynamic>;
      expect(body.containsKey('tools'), isTrue, reason: '工具必须照发');
      expect(body.containsKey('response_format'), isFalse,
          reason: '有工具时下发 response_format 会让 tool_calls 永不产生');
      expect(out.reply, contains('粉色调'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('无工具：仍走结构化输出（历史行为不回退）', () async {
      final (server, hits) = await _startMockServer(200,
          sseText: '{"reply":"好的","topic":"问好","keywords":"你好,问候"}');
      addTearDown(() => server.close(force: true));
      final rt = AgentRuntime(
        agentSource: () => _agentAt(server.port),
        hasTools: () => false,
        allowPlainRetry: () async => false,
        timeout: const Duration(seconds: 10),
      );
      final out = await rt.turn(systemPrompt: 's', message: 'hi');
      final body = jsonDecode(hits.first) as Map<String, dynamic>;
      expect(body.containsKey('response_format'), isTrue);
      expect(body.containsKey('tools'), isFalse);
      expect(out.reply, '好的');
      expect(out.topic, '问好');
      expect(out.keywords, '你好,问候');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('hasTools 缺省（null）＝按"无工具"处理，包外消费者零影响', () {
      final rt = AgentRuntime(agentSource: () => null);
      expect(rt.hasTools, isNull);
    });
  });
}

Agent _agentWithToolsAt(int port) => Agent.forProvider(
      OpenAIProvider(
          apiKey: 'test-key', baseUrl: Uri.parse('http://127.0.0.1:$port')),
      chatModelName: 'test-model',
      tools: [
        Tool<Map<String, dynamic>>(
          name: 'change_system_settings',
          description: '修改 App 设置（换主题色等）',
          inputSchema: Schema.object(
            properties: {'app_theme': Schema.string(description: '主题色')},
          ),
          onCall: (args) async => 'ok',
        ),
      ],
    );
