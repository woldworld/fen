import 'package:pocket_harness/pocket_harness.dart';
import 'package:test/test.dart';

SessionEvent user(String text) =>
    SessionEvent(type: 'user_message', data: {'text': text});
SessionEvent bot(String text) =>
    SessionEvent(type: 'assistant_message', data: {'text': text});

void main() {
  group('ContextManager.selectRecent（M4）', () {
    test('预算内全部保留，顺序不乱', () {
      final events = [user('一'), bot('二'), user('三')];
      final picked =
          const ContextManager(maxChars: 10000).selectRecent(events);
      expect(picked.length, 3);
      expect(picked.first.data['text'], '一');
    });

    test('超预算：新消息优先，最旧的先被丢弃', () {
      final events = [
        for (var i = 0; i < 10; i++) user('消息$i${'x' * 50}'),
      ];
      // 每条约 55 字符，预算 200 → 大约装 3 条
      final picked = const ContextManager(maxChars: 200).selectRecent(events);
      expect(picked.length, lessThan(10));
      expect(picked.length, greaterThanOrEqualTo(1));
      // 最旧的一定不在，最新的一定在
      expect(picked.first.data['text'], isNot(contains('消息0x')));
      expect(picked.last.data['text'], contains('消息9'));
    });

    test('最新一条即使超预算也无条件保留（当前输入不能丢）', () {
      final events = [user('短'), user('超长${'y' * 500}')];
      final picked = const ContextManager(maxChars: 100).selectRecent(events);
      expect(picked.length, 1);
      expect(picked.last.data['text'], contains('超长'));
    });

    test('摘要折叠：最后一个 summary 之前的事件全部折叠', () {
      final events = [
        user('旧1'),
        bot('旧2'),
        SessionEvent(type: 'summary', data: {'text': '此前聊了天气'}),
        user('新'),
      ];
      final picked = const ContextManager(maxChars: 10000).selectRecent(events);
      expect(picked.length, 2);
      expect(picked.first.type, 'summary');
      expect(picked.first.data['text'], '此前聊了天气');
      expect(picked.last.data['text'], '新');
    });

    test('取最后一个 summary（多次折叠场景）', () {
      final events = [
        user('第一段'),
        SessionEvent(type: 'summary', data: {'text': '摘要A'}),
        bot('中段'),
        SessionEvent(type: 'summary', data: {'text': '摘要B'}),
        user('最新'),
      ];
      final picked = const ContextManager(maxChars: 10000).selectRecent(events);
      // 摘要B 覆盖它之前的一切（含摘要A 与中段）
      expect(picked.length, 2);
      expect(picked.first.data['text'], '摘要B');
      expect(picked.last.data['text'], '最新');
    });
  });

  group('ContextManager.fitLines（prompt 段落溢出防护）', () {
    test('预算内原样返回', () {
      const block = '技能一\n技能二';
      expect(const ContextManager(maxChars: 100).fitLines(block), block);
    });

    test('超预算整行丢弃并追加省略提示，不切半个词', () {
      final block = List.generate(10, (i) => '技能内容$i${'v' * 20}').join('\n');
      final fitted = const ContextManager(maxChars: 120).fitLines(block);
      expect(fitted.length, lessThan(block.length));
      expect(fitted, contains('已按预算省略'));
      expect(fitted, endsWith('）'));
      // 被保留的行是完整的
      for (final line in fitted.split('\n')) {
        if (line.startsWith('技能内容')) {
          expect(line, matches(RegExp(r'技能内容\d+v{20}$')));
        }
      }
    });
  });

  group('Compactor（M4 摘要折叠）', () {
    test('未超阈值：不折叠', () async {
      final store = InMemorySessionStore();
      await store.open('s');
      for (var i = 0; i < 10; i++) {
        await store.append('s', user('消息$i'));
      }
      var summarizeCalled = false;
      final c = Compactor(
        threshold: 60,
        keepRecent: 20,
        summarize: (t) async {
          summarizeCalled = true;
          return '摘要';
        },
      );
      expect(await c.compactIfNeeded(store, 's'), isFalse);
      expect(summarizeCalled, isFalse);
    });

    test('超阈值：旧事件压缩为 summary 事件，最近原文保留', () async {
      final store = InMemorySessionStore();
      await store.open('s');
      for (var i = 0; i < 30; i++) {
        await store.append('s', user('消息$i'));
      }
      final c = Compactor(
        threshold: 10,
        keepRecent: 5,
        summarize: (transcript) async {
          expect(transcript, contains('消息0'));
          expect(transcript, contains('消息24'));
          expect(transcript, isNot(contains('消息25')));
          return '这是前 25 条的摘要';
        },
      );
      expect(await c.compactIfNeeded(store, 's'), isTrue);

      final events = await store.replay('s');
      // append-only：30 原文 + 1 摘要 + 5 条保留原文的重追副本
      expect(events.length, 36);
      final summary = events.where((e) => e.type == 'summary').single;
      expect(summary.data['text'], '这是前 25 条的摘要');
      expect(summary.data['covered_events'], 25);

      // 折叠后的选择视图：[摘要, 重追的最近 5 条]——压缩语义完全一致
      final view = const ContextManager(maxChars: 100000).selectRecent(events);
      expect(view.length, 6);
      expect(view.first.type, 'summary');
      expect(view.last.data['text'], contains('消息29'));
      // 重追副本顺序保持时间序
      expect(view[1].data['text'], contains('消息25'));
    });

    test('summarize 返回 null：放弃折叠不报错', () async {
      final store = InMemorySessionStore();
      await store.open('s');
      for (var i = 0; i < 20; i++) {
        await store.append('s', user('消息$i'));
      }
      final c = Compactor(
        threshold: 10,
        keepRecent: 5,
        summarize: (t) async => null,
      );
      expect(await c.compactIfNeeded(store, 's'), isFalse);
      final events = await store.replay('s');
      expect(events.where((e) => e.type == 'summary'), isEmpty);
    });

    test('多次折叠：只压最后一个 summary 之后的部分', () async {
      final store = InMemorySessionStore();
      await store.open('s');
      for (var i = 0; i < 25; i++) {
        await store.append('s', user('第一轮$i'));
      }
      var call = 0;
      final c = Compactor(
        threshold: 10,
        keepRecent: 5,
        summarize: (t) async => call++ == 0 ? '摘要A' : '摘要B',
      );
      await c.compactIfNeeded(store, 's');
      // 再追加 20 条，触发第二次折叠
      for (var i = 0; i < 20; i++) {
        await store.append('s', user('第二轮$i'));
      }
      expect(await c.compactIfNeeded(store, 's'), isTrue);
      final events = await store.replay('s');
      final summaries =
          events.where((e) => e.type == 'summary').toList();
      expect(summaries.length, 2);
      expect(summaries.last.data['text'], '摘要B');
      // 第二次压缩范围：alive=25（上次保留的 5 条副本 + 新增 20 条），
      // compress 20、keep 5；摘要 A 之前的内容绝不重复压缩
      expect((summaries.last.data['covered_events'] as int), 20);
    });
  });
}
