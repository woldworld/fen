// W2 (0.71.0) 真搜索单测：纯函数解析/聚合 + 工具 handler 行为（覆写缝，不碰真网）。
//
// 覆盖：
//   ① 三 Provider 响应解析（Tavily / SearXNG / Bing）
//   ② 聚合：去重（host+path 归一）、权重排序（pro > wiki > jina）、6000 截断
//   ③ handler：pro 模式聚合输出 + 模式标注；无 Key = 基础模式兜底；空 query 参数缺失
//   ④ SearchConfig.proEnabled 判据（tavily/bing 需 Key，searxng 需 URL）
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_harness/pocket_harness.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dahuang_ai/core/search/search_tools.dart';

ToolContext _ctx() => ToolContext(
      log: (_, __) {},
      searchMemory: (_) async => '',
      httpClient: HttpClient(),
    );

void main() {
  group('SearchConfig.proEnabled', () {
    test('tavily/bing 需要 Key，searxng 需要 URL，未知/空 provider 一律 false', () {
      expect(const SearchConfig(provider: '').proEnabled, isFalse);
      expect(const SearchConfig(provider: 'tavily').proEnabled, isFalse);
      expect(
          const SearchConfig(provider: 'tavily', apiKey: 'k').proEnabled,
          isTrue);
      expect(const SearchConfig(provider: 'bing').proEnabled, isFalse);
      expect(
          const SearchConfig(provider: 'bing', apiKey: 'k').proEnabled,
          isTrue);
      expect(const SearchConfig(provider: 'searxng').proEnabled, isFalse);
      expect(
          const SearchConfig(provider: 'searxng', searxngUrl: 'https://x')
              .proEnabled,
          isTrue);
      expect(
          const SearchConfig(provider: 'unknown', apiKey: 'k').proEnabled,
          isFalse);
    });
  });

  group('Provider 响应解析', () {
    test('parseTavilyResponse：取 title/url/content，空 url 剔除', () {
      final hits = parseTavilyResponse({
        'results': [
          {'title': 'A', 'url': 'https://a.com/x', 'content': 'ca'},
          {'title': '', 'url': '', 'content': 'no url'},
          {'title': 'B', 'url': 'https://b.com/', 'content': ''},
        ],
      });
      expect(hits.length, 2);
      expect(hits[0].url, 'https://a.com/x');
      expect(hits[0].weight, 0);
    });

    test('parseSearxngResponse：同形态', () {
      final hits = parseSearxngResponse({
        'results': [
          {'title': 'S', 'url': 'https://s.com/1', 'content': 'cs'},
        ],
      });
      expect(hits.length, 1);
      expect(hits.first.title, 'S');
    });

    test('parseBingResponse：webPages.value → name/url/snippet', () {
      final hits = parseBingResponse({
        'webPages': {
          'value': [
            {'name': 'N', 'url': 'https://n.com', 'snippet': 'sn'},
          ],
        },
      });
      expect(hits.length, 1);
      expect(hits.first.title, 'N');
      expect(hits.first.snippet, 'sn');
    });

    test('畸形输入不抛：非 List / 缺字段', () {
      expect(parseTavilyResponse({}), isEmpty);
      expect(parseTavilyResponse({'results': 'x'}), isEmpty);
      expect(parseBingResponse({}), isEmpty);
    });
  });

  group('aggregateAndFormat', () {
    test('按 host+path 去重，权重排序（pro > wiki > jina）', () {
      final out = aggregateAndFormat(hits: [
        SearchHit('W', 'https://en.wikipedia.org/wiki/A', 'd', weight: 1),
        SearchHit('P2', 'https://p.com/b', 'd2', weight: 0),
        SearchHit('W2', 'https://en.wikipedia.org/wiki/A', 'dup', weight: 1),
        SearchHit('J', 'https://r.jina.ai/search', 'digest', weight: 2),
        SearchHit('P1', 'https://p.com/a', 'd1', weight: 0),
      ]);
      expect(out, contains('1. P2'));
      expect(out, contains('2. P1'));
      // ★ 稳定排序：P2/P1 同权重（=0），保持**输入顺序**（P2 先出现）——
      //   Dart List.sort 不保证稳定，实现用下标 tiebreaker 钉死这一语义。
      expect(out, contains('3. W'));
      expect(out, contains('4. J'));
      // 去重：wikipedia/A 只出现一次
      expect('dup'.allMatches(out).length, 0);
      expect(RegExp(r'en\.wikipedia\.org/wiki/A').allMatches(out).length, 1);
    });

    test('超长截断到 maxChars 并标注', () {
      final out = aggregateAndFormat(
        hits: List.generate(
            50,
            (i) => SearchHit('T$i', 'https://h$i.com/p$i',
                'x' * 300, weight: i)),
        maxChars: 6000,
      );
      expect(out.length, lessThanOrEqualTo(6010));
      expect(out, contains('已截断'));
    });

    test('空输入 → 空串（handler 层据此报搜索失败）', () {
      expect(aggregateAndFormat(hits: const []), isEmpty);
    });
  });

  group('web_search_pro handler', () {
    test('pro 模式：聚合 pro 源 + 基础腿，输出含模式标注与不可信包裹', () async {
      final specs = buildSearchTools(
        wrapUntrusted: (raw) => '<<U>>$raw<</U>>',
        log: (_, __) {},
        configOverride: () async =>
            const SearchConfig(provider: 'tavily', apiKey: 'k'),
        proSearchOverride: (q, cfg) async => [
          SearchHit('ProHit', 'https://pro.com/x', 'pro snippet'),
        ],
        basicLegsOverride: (q) async => [
          SearchHit('WikiHit', 'https://en.wikipedia.org/wiki/Q', 'w'),
        ],
      );
      final spec = specs.single;
      expect(spec.name, 'web_search_pro');
      expect(spec.permission, PermissionLevel.sensitive);
      expect(spec.grantKey, kSearchProGrantKey);

      final out = await spec.handler(_ctx(), {'query': 'hello'});
      expect(out, contains('【搜索聚合 · pro（tavily）】'));
      expect(out, contains('<<U>>'));
      expect(out, contains('ProHit'));
      expect(out, contains('WikiHit'));
    });

    test('无 Key = 基础模式兜底（行为与现状两腿一致），仍可用', () async {
      SharedPreferences.setMockInitialValues({});
      final specs = buildSearchTools(
        wrapUntrusted: (raw) => raw,
        log: (_, __) {},
        basicLegsOverride: (q) async => [
          SearchHit('WikiHit', 'https://en.wikipedia.org/wiki/Q', 'w',
              weight: 1),
        ],
      );
      final out = await specs.single.handler(_ctx(), {'query': 'hello'});
      expect(out, contains('【搜索聚合 · 基础模式】'));
      expect(out, contains('WikiHit'));
    });

    test('全部腿失败 → 明说搜索失败，不抛、不静默', () async {
      final specs = buildSearchTools(
        wrapUntrusted: (raw) => raw,
        log: (_, __) {},
        basicLegsOverride: (q) async => [],
      );
      final out = await specs.single.handler(_ctx(), {'query': 'hello'});
      expect(out, contains('【搜索失败】'));
    });

    test('★ 0.76.0：pro 腿抛异常只退化该腿，基础腿照跑（不返回搜索失败）', () async {
      // 回归防呆：此前 proLeg 的**非超时异常**（Key 失效→401 / 5xx / 响应非
      // JSON）会冒泡到 handler 外层 catch，直接把 Wikipedia+Jina 基础腿一起
      // 丢掉 —— 配错 Key 反而不如不配。修法 = proLeg 调用自身也纳入兜底。
      final specs = buildSearchTools(
        wrapUntrusted: (raw) => raw,
        log: (_, __) {},
        configOverride: () async =>
            const SearchConfig(provider: 'tavily', apiKey: 'bad-key'),
        proSearchOverride: (q, cfg) async =>
            throw HttpException('HTTP 401', uri: Uri.parse('https://api.tavily.com')),
        basicLegsOverride: (q) async => [
          SearchHit('WikiHit', 'https://en.wikipedia.org/wiki/Q', 'w',
              weight: 1),
        ],
      );
      final out = await specs.single.handler(_ctx(), {'query': 'hello'});
      expect(out, contains('WikiHit')); // 基础腿仍未被丢弃
      expect(out, isNot(contains('【搜索失败】')));
      expect(out, contains('【搜索聚合'));
    });

    test('空 query → 参数缺失', () async {
      final specs = buildSearchTools(
        wrapUntrusted: (raw) => raw,
        log: (_, __) {},
      );
      final out = await specs.single.handler(_ctx(), {'query': '  '});
      expect(out, contains('【参数缺失】'));
    });
  });

  test('hitKey：scheme/query/fragment 不影响归一，host 小写', () {
    expect(hitKey('https://A.com/x/?q=1#f'), hitKey('http://a.com/x'));
    expect(hitKey('not a url'), 'not a url');
  });

  test('SearXNG 腿真 HTTP 端到端：本地回环假服务验证 URL 拼装与响应解析',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Uri? seen;
    try {
      server.listen((req) async {
        seen = req.uri;
        req.response.headers.contentType =
            ContentType('application', 'json', charset: 'utf-8');
        req.response.write(jsonEncode({
          'results': [
            {'title': 'LocalHit', 'url': 'https://x.test/a', 'content': 'cx'},
          ],
        }));
        await req.response.close();
      });
      final base = 'http://127.0.0.1:${server.port}';
      final specs = buildSearchTools(
        wrapUntrusted: (raw) => raw,
        log: (_, __) {},
        configOverride: () async =>
            SearchConfig(provider: 'searxng', searxngUrl: base),
        basicLegsOverride: (q) async => const [],
      );
      final out = await specs.single.handler(_ctx(), {'query': 'q1'});
      expect(seen!.path, '/search');
      expect(seen!.queryParameters['format'], 'json');
      expect(seen!.queryParameters['q'], 'q1');
      expect(out, contains('LocalHit'));
      expect(out, contains('pro（searxng）'));
    } finally {
      await server.close(force: true);
    }
  });
}
