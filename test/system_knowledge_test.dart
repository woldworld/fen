import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/system_knowledge.dart';
import 'package:pocket_harness/pocket_harness.dart';

void main() {
  group('KB integrity (every feature ships with an entry)', () {
    test('entry count and unique ids', () {
      expect(systemKnowledge.length, greaterThanOrEqualTo(45));
      final ids = systemKnowledge.map((e) => e.id).toSet();
      expect(ids.length, systemKnowledge.length, reason: 'id 不得重复');
    });

    test('entry discipline: English steps within token budget', () {
      for (final e in systemKnowledge) {
        expect(e.steps.length, lessThanOrEqualTo(450),
            reason: '「${e.id}」steps ${e.steps.length} chars — 检索结果直接进 prompt');
        expect(e.keywords, isNotEmpty, reason: '「${e.id}」缺关键词 = 检索盲区');
      }
    });

    test('troubleshooting trio exists (no-reply / connect / wifi)', () {
      final ids = systemKnowledge.map((e) => e.id).toSet();
      expect(ids, containsAll(['ts_no_reply', 'ts_connect', 'ts_wifi']));
    });
  });

  group('retrieval (English canonical queries)', () {
    test('radar intent', () {
      final r = retrieveHelp('how do I start the radar patrol');
      expect(r.first.id, 'radar');
    });

    test('lost phone → recovery code', () {
      final r = retrieveHelp('lost my phone can I recover my identity');
      expect(r.map((e) => e.id), contains('backup_code'));
    });

    test('agent not replying → troubleshooting', () {
      final r = retrieveHelp('my agent is not replying to messages');
      expect(r.first.id, 'ts_no_reply');
    });

    test('trial quota question', () {
      final r = retrieveHelp('how many free turns are left when trial ends');
      expect(r.map((e) => e.id), containsAll(['free_trial', 'trial_exhausted']));
    });

    test('hosting in room', () {
      final r = retrieveHelp('where is the auto reply switch in a room');
      expect(r.map((e) => e.id), contains('room_hosting'));
    });

    test('delegation location (simple-mode user)', () {
      final r = retrieveHelp('where is the tasks tab it is missing');
      expect(r.map((e) => e.id), containsAll(['delegation', 'full_mode']));
    });

    test('email feature ships with an entry (bind account → agent sends)', () {
      // 邮箱工具是一等用户功能（KB 纪律：新功能无条目 = 发布不完整）⇒ 必须可检索到。
      final ids = systemKnowledge.map((e) => e.id).toSet();
      expect(ids, contains('email'));
      final r = retrieveHelp('how do I let my agent read and send my email');
      expect(r.map((e) => e.id), contains('email'));
    });

    test('0.67/0.68 features ship with entries (late catch-up)', () {
      // ★ 0.69.0 补登记：晨间问候（0.67.0）与长期画像（0.68.0/0.69.0）**上线时都没动 KB**，
      //   违反了 `system_knowledge.dart` 顶部「feature changes update the matching entry
      //   in the same commit」。本单测只盯**格式与可检索性**；
      //   「新功能有没有被登记」这条由 `tool/verify_system_knowledge.dart` 的对账清单盯住。
      final ids = systemKnowledge.map((e) => e.id).toSet();
      expect(ids, containsAll(['morning_greeting', 'long_term_profile']));
      expect(
          retrieveHelp('when do I get the morning greeting three day review')
              .map((e) => e.id),
          contains('morning_greeting'));
      expect(
          retrieveHelp('how do I stop my agent using my long term profile')
              .map((e) => e.id),
          contains('long_term_profile'));
    });

    test('boundary entry ships and is retrievable (0.88.0)', () {
      // 「能 / 不能替主人做什么」是主人最常问的期望边界 ⇒ 必须可检索到。
      final ids = systemKnowledge.map((e) => e.id).toSet();
      expect(ids, contains('agent_boundary'));
      expect(retrieveHelp('what can you do for me').map((e) => e.id),
          contains('agent_boundary'));
      expect(retrieveHelp('what can you not do for me').map((e) => e.id),
          contains('agent_boundary'));
    });

    test('vision routing guard: image input question → device control? no, falls to entries',
        () {
      // 英文检索不因问法变体而空手
      final r = retrieveHelp('why does wifi turn on by itself');
      expect(r.first.id, 'ts_wifi');
    });

    test('top-N cap; off-topic queries degrade to best-effort ranking', () {
      expect(retrieveHelp('agent room chat settings memory').length,
          lessThanOrEqualTo(3));
      // 英文二元组对宽泛词组是 best-effort 排序（常见组合会 incidental 命中）
      // ——真正的"无命中"入口是空查询（由 formatHelpResult 出兜底文案）。
      expect(retrieveHelp('quantum wave function collapse').length,
          lessThanOrEqualTo(3));
      expect(retrieveHelp('   '), isEmpty);
    });
  });

  group('formatHelpResult', () {
    test('hit: bounded output with translate instruction', () {
      final out = formatHelpResult('radar', retrieveHelp('radar'));
      expect(out, contains('radar'));
      expect(out, contains('Translate and adapt'));
      expect(out.length, lessThan(1400));
    });

    test('miss: all topics listed for re-ask guidance', () {
      final out = formatHelpResult('wave function', const []);
      expect(out, contains('No entry matches'));
      expect(out, contains('[Social radar (patrol)]'));
    });
  });

  group('buildSystemHelpTool', () {
    final tool = buildSystemHelpTool();
    test('metadata: english-query contract in description', () {
      expect(tool.name, 'system_help');
      expect(tool.permission, PermissionLevel.normal);
      expect(tool.description, contains('MUST be English'));
    });

    test('handler: hit / miss / empty-arg all safe', () async {
      final ctx = ToolContext(
          log: (_, __) {},
          searchMemory: (_) async => '',
          httpClient: HttpClient());
      final hit = await tool.handler(ctx, {'query': 'room hosting enable'});
      expect(hit, contains('Room hosting'));
      final miss = await tool.handler(ctx, {'query': ''});
      expect(miss, contains('No entry matches'));
      final noArg = await tool.handler(ctx, {});
      expect(noArg, contains('No entry matches'));
    });
  });
}
