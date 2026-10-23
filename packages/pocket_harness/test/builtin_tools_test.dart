import 'dart:async';
import 'dart:io';

import 'package:pocket_harness/pocket_harness.dart';
import 'package:test/test.dart';

void main() {
  group('session_search / session_read', () {
    late InMemorySessionStore store;
    late String threadId;

    setUp(() async {
      store = InMemorySessionStore();
      threadId = 'main_test';
      await store.open(threadId);
      Future<void> add(String type, String text) => store.append(
          threadId, SessionEvent(type: type, data: {'text': text}));
      await add('user_message', '我们约好周五去图书馆看书');
      await add('assistant_message', '好的主人，我已经记下周五图书馆的约定');
      await add('tool_call', 'send_gift(gift="book")');
      await add('user_message', '今天天气真不错');
    });

    test('关键词命中：序号、类型、摘录', () async {
      final tool = buildSessionSearchTool(store: store, threadId: () => threadId);
      final out = await tool.handler(_noopCtx(), {'query': '图书馆'});
      expect(out, contains('#1'));
      expect(out, contains('[user_message]'));
      expect(out, contains('周五'));
      expect(out, contains('命中 2 条'));
    });

    test('大小写不敏感 + limit 截断', () async {
      await store.append(
          threadId, SessionEvent(type: 'system_note', data: {'text': 'OK OK OK'}));
      final tool = buildSessionSearchTool(store: store, threadId: () => threadId);
      final out = await tool.handler(_noopCtx(), {'query': 'ok', 'limit': 2});
      expect(out, contains('命中 2 条'));
    });

    test('无命中 / 空查询 / 空会话', () async {
      final tool = buildSessionSearchTool(store: store, threadId: () => threadId);
      expect(await tool.handler(_noopCtx(), {'query': '不存在的词'}),
          contains('没有包含'));
      expect(await tool.handler(_noopCtx(), {'query': '  '}), contains('不能为空'));

      final emptyTool = buildSessionSearchTool(
          store: store, threadId: () => 'never_opened');
      final out = await emptyTool.handler(_noopCtx(), {'query': 'x'});
      expect(out, contains('共 0 条事件'));
    });

    test('session_read：翻页、截断、越界提示', () async {
      final long = '长' * 1000;
      await store.append(
          threadId, SessionEvent(type: 'user_message', data: {'text': long}));
      final tool = buildSessionReadTool(store: store, threadId: () => threadId);

      final page1 = await tool.handler(_noopCtx(), {'from': 0, 'limit': 2});
      expect(page1, contains('#0 [user_message]'));
      expect(page1, contains('#1 [assistant_message]'));
      expect(page1, contains('后面还有'));

      final pageLong = await tool.handler(_noopCtx(), {'from': 4, 'limit': 1});
      expect(pageLong, contains('…[截断]'));

      final beyond = await tool.handler(_noopCtx(), {'from': 99});
      expect(beyond, contains('已超出'));
    });

    test('store 异常收口为可读文本（fail-soft，不炸轮次）', () async {
      final broken = _BrokenStore();
      final tool = buildSessionSearchTool(store: broken, threadId: () => 't');
      final out = await tool.handler(_noopCtx(), {'query': 'x'});
      expect(out, contains('会话读取失败'));
    });
  });

  group('WebFetchGuard（SSRF 防护）', () {
    bool allow(String u) => WebFetchGuard.isPublicHttpUrl(Uri.parse(u));

    test('放行：公网 http(s) 与普通域名', () {
      expect(allow('https://example.com/a?q=1'), isTrue);
      expect(allow('http://news.example.co.uk:8080/x'), isTrue);
      expect(allow('https://8.8.8.8/dns'), isTrue);
    });

    test('拒绝：协议与 userinfo', () {
      expect(allow('ftp://example.com'), isFalse);
      expect(allow('file:///etc/passwd'), isFalse);
      expect(allow('https://user:pass@example.com/'), isFalse);
    });

    test('拒绝：本机/内网/元数据地址', () {
      expect(allow('http://localhost/x'), isFalse);
      expect(allow('http://127.0.0.1:8080/x'), isFalse);
      expect(allow('http://10.1.2.3/x'), isFalse);
      expect(allow('http://172.16.0.9/x'), isFalse);
      expect(allow('http://172.31.255.1/x'), isFalse);
      expect(allow('http://192.168.1.1/router'), isFalse);
      expect(allow('http://169.254.169.254/latest/meta-data/'), isFalse);
      expect(allow('http://100.64.1.1/x'), isFalse);
      expect(allow('http://0.0.0.0/x'), isFalse);
      expect(allow('http://224.0.0.1/x'), isFalse);
      expect(allow('http://myhost.local/x'), isFalse);
      expect(allow('http://svc.internal/x'), isFalse);
    });

    test('拒绝：IPv6 回环/链路本地/唯一本地/映射私网；放行公网 v6', () {
      expect(allow('http://[::1]/x'), isFalse);
      expect(allow('http://[fe80::1]/x'), isFalse);
      expect(allow('http://[fc00::abcd]/x'), isFalse);
      expect(allow('http://[fd12::abcd]/x'), isFalse);
      expect(allow('http://[::ffff:192.168.0.1]/x'), isFalse);
      expect(allow('http://[2606:4700::1111]/x'), isTrue);
    });

    test('边界放行：172.32 不在私有段', () {
      expect(allow('http://172.32.0.1/x'), isTrue);
    });
  });

  group('htmlToText / extractHtmlTitle', () {
    test('去脚本样式、块级转行、剥标签、实体解码', () {
      final html = '''<html><head><title>你好 &amp; 世界</title>
<script>evil()</script><style>.x{}</style></head>
<body><h1>标题一</h1><p>第一段，a&nbsp;&lt;b&gt;。</p>
<p>第二段&#x4E2D;文&#39;引号&apos;？</p><ul><li>条目A</li><li>条目B</li></ul>
<!-- 注释 --><script src="x.js">alert(1)</script></body></html>''';
      final text = htmlToText(html);
      expect(text, isNot(contains('evil')));
      expect(text, isNot(contains('alert')));
      expect(text, isNot(contains('注释')));
      expect(text, contains('标题一'));
      expect(text, contains('第一段，a <b>。'));
      expect(text, contains('第二段中文\'引号\'？'));
      expect(text, contains('条目A'));
      expect(extractHtmlTitle(html), '你好 & 世界');
    });

    test('无标题返回 null', () {
      expect(extractHtmlTitle('<p>no title</p>'), isNull);
    });
  });

  group('web_fetch（真实本地 HttpServer 全链路）', () {
    late HttpServer server;
    late Uri base;
    late HttpClient client;

    setUp(() async {
      server = await HttpServer.bind('127.0.0.1', 0);
      base = Uri.parse('http://127.0.0.1:${server.port}');
      client = HttpClient();
      server.listen((req) async {
        switch (req.uri.path) {
          case '/html':
            req.response.headers.contentType =
                ContentType('text', 'html', charset: 'utf-8');
            req.response.write('<html><title>测试页</title><body><p>正文内容'
                '你好</p><script>ignored()</script></body></html>');
            await req.response.close();
          case '/plain':
            req.response.write('纯文本内容');
            await req.response.close();
          case '/redirect':
            await req.response.redirect(Uri.parse('/html'), status: 302);
          case '/redirect-loop':
            await req.response.redirect(Uri.parse('/redirect-loop'), status: 302);
          case '/redirect-evil':
            await req.response.redirect(Uri.parse('http://10.9.8.7/inner'),
                status: 302);
          case '/big':
            req.response.headers.contentType = ContentType.text;
            req.response.write('A' * 5000);
            await req.response.close();
          case '/binary':
            req.response.headers.contentType =
                ContentType.binary; // application/octet-stream
            req.response.add([1, 2, 3]);
            await req.response.close();
          case '/unicode':
            req.response.headers.contentType =
                ContentType('text', 'plain', charset: 'utf-8');
            req.response.write('中文内容');
            await req.response.close();
          default:
            req.response.statusCode = 404;
            await req.response.close();
        }
      });
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    ToolSpec toolWithTestGuard() => buildWebFetchTool(
          // 测试注入：本机回环放行（服务器就绑在回环上），其余走真实守卫
          urlGuard: (u) =>
              u.host == '127.0.0.1' || WebFetchGuard.isPublicHttpUrl(u),
        );

    test('HTML 抓取：标题 + 转文本 + 去脚本', () async {
      final out = await toolWithTestGuard()
          .handler(_ctxWith(client), {'url': '$base/html'});
      expect(out, contains('标题: 测试页'));
      expect(out, contains('正文内容'));
      expect(out, isNot(contains('ignored')));
    });

    test('纯文本直读', () async {
      final out = await toolWithTestGuard()
          .handler(_ctxWith(client), {'url': '$base/plain'});
      expect(out, contains('纯文本内容'));
    });

    test('重定向跟随（逐跳过守卫）', () async {
      final out = await toolWithTestGuard()
          .handler(_ctxWith(client), {'url': '$base/redirect'});
      expect(out, contains('正文内容'));
    });

    test('重定向到内网被拒', () async {
      final out = await toolWithTestGuard()
          .handler(_ctxWith(client), {'url': '$base/redirect-evil'});
      expect(out, contains('重定向到非公开地址被拒绝'));
    });

    test('重定向环超限放弃', () async {
      final out = await toolWithTestGuard()
          .handler(_ctxWith(client), {'url': '$base/redirect-loop'});
      expect(out, contains('重定向超过'));
    });

    test('404 返回状态码文本', () async {
      final out = await toolWithTestGuard()
          .handler(_ctxWith(client), {'url': '$base/missing'});
      expect(out, contains('HTTP 404'));
    });

    test('二进制内容类型拒绝', () async {
      final out = await toolWithTestGuard()
          .handler(_ctxWith(client), {'url': '$base/binary'});
      expect(out, contains('不支持的内容类型'));
    });

    test('max_chars 截断生效', () async {
      final out = await toolWithTestGuard().handler(_ctxWith(client),
          {'url': '$base/big', 'max_chars': 100});
      expect(out, contains('[已截断，原文'));
    });

    test('默认守卫拒绝回环地址（即使服务器可达）', () async {
      final out = await buildWebFetchTool()
          .handler(_ctxWith(client), {'url': '$base/html'});
      expect(out, contains('拒绝访问非公开地址'));
    });

    test('非法 URL 与空参收口', () async {
      final t = toolWithTestGuard();
      expect(await t.handler(_ctxWith(client), {'url': '::::'}),
          contains('无法解析'));
      expect(await t.handler(_ctxWith(client), {'url': ''}),
          contains('无法解析'));
    });
  });
}

ToolContext _noopCtx() => ToolContext(
      log: (_, _) {},
      searchMemory: (_) async => '',
      httpClient: HttpClient(),
    );

ToolContext _ctxWith(HttpClient client) => ToolContext(
      log: (_, _) {},
      searchMemory: (_) async => '',
      httpClient: client,
    );

class _BrokenStore implements SessionStore {
  @override
  Future<Session> open(String id) async => Session(id, const []);

  @override
  Future<void> append(String id, SessionEvent event) async {}

  @override
  Future<List<SessionEvent>> replay(String id, {int after = -1}) async {
    throw StateError('boom');
  }

  @override
  Future<void> close(String id) async {}
}
