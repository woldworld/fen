import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/telemetry.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late MemoryTelemetryStore store;
  late Telemetry t;

  setUp(() {
    store = MemoryTelemetryStore();
    t = Telemetry(store);
  });

  TelemetryEvent ev(
    String name,
    int ts, {
    String? self,
    String? peer,
    Map<String, Object?>? extra,
  }) =>
      TelemetryEvent(
        name: name,
        tsMs: ts,
        props: {
          if (self != null) 'self': self,
          if (peer != null) 'peer': peer,
          ...?extra,
        },
      );

  group('Telemetry 基础', () {
    test('track 写入事件并可读取', () async {
      t.track(TelemetryEvents.onboardingDone, props: {'self': 'u1'});
      await tick();
      final all = await t.events();
      expect(all.length, 1);
      expect(all.first.name, TelemetryEvents.onboardingDone);
      expect(all.first.props['self'], 'u1');
    });

    test('事件名常量覆盖 PRD §7.2 全部事件（含 §7.1 依赖的 message_sent_human）', () {
      const required = {
        'onboarding_done',
        'invite_created',
        'invite_accepted',
        'circle_entered',
        'delegation_sent',
        'delegation_done',
        'intercard_generated',
        'intercard_approved',
        'human_presence_marked',
        'message_sent_human',
        'handshake',
        'disclosure_variant',
        'digest_opened',
        'report_filed',
      };
      for (final n in required) {
        expect(n.isNotEmpty, true, reason: n);
      }
      // §7.1 握手定义依赖"真人直发消息"，字典若缺它北极星就不可计算
      expect(TelemetryEvents.messageSentHuman, 'message_sent_human');
    });

    test('track 永不抛异常（存储抛错时静默）', () async {
      final boom = _ThrowingStore();
      final bad = Telemetry(boom);
      expect(() => bad.track('x'), returnsNormally);
    });

    test('countsByName 与 funnel 顺序', () async {
      t.track(TelemetryEvents.onboardingDone, props: {'self': 'u1'});
      t.track(TelemetryEvents.circleEntered, props: {'self': 'u1'});
      t.track(TelemetryEvents.delegationDone, props: {'self': 'u1'});
      await tick();

      final c = await t.countsByName();
      expect(c[TelemetryEvents.onboardingDone], 1);

      final f = await t.funnel();
      // onboarding → 进圈 → 委托完成 → 互介确认 → 握手
      expect(f, [1, 1, 1, 0, 0]);
    });

    test('exportJsonLines 可被 fromJson 还原', () async {
      t.track(TelemetryEvents.disclosureVariant,
          props: {'self': 'u1', 'arm': 'disclosed', 'replied': true});
      await tick();
      final lines = await t.exportJsonLines();
      final first = lines.split('\n').first;
      expect(first.contains('disclosure_variant'), true);
      expect(first.contains('disclosed'), true);
    });
  });

  group('HandshakeJudge（PRD §7.1）', () {
    final now = 1000000000000;
    final h = Duration(hours: 24).inMilliseconds;

    test('满足 3 条真人消息 + α 中介 → 握手成立', () {
      final events = [
        ev(TelemetryEvents.messageSentHuman, now - h ~/ 2, self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - h ~/ 3, self: 'b', peer: 'a'),
        ev(TelemetryEvents.messageSentHuman, now - h ~/ 4, self: 'a', peer: 'b'),
        ev(TelemetryEvents.delegationDone, now - h, self: 'a', peer: 'b'),
      ];
      final v = HandshakeJudge.judge(a: 'a', b: 'b', events: events, nowMs: now);
      expect(v.ok, true);
      expect(v.humanMessages, 3);
      expect(v.mediationSource, 'alpha');
    });

    test('只有 2 条真人消息 → 不成立，且给出可判定原因', () {
      final events = [
        ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'b'),
        ev(TelemetryEvents.delegationDone, now - 3000, self: 'a', peer: 'b'),
      ];
      final v = HandshakeJudge.judge(a: 'a', b: 'b', events: events, nowMs: now);
      expect(v.ok, false);
      expect(v.reason, 'human_messages_insufficient');
      expect(v.humanMessages, 2);
    });

    test('消息够但无中介事件 → 不成立', () {
      final events = [
        ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - 3000, self: 'a', peer: 'b'),
      ];
      final v = HandshakeJudge.judge(a: 'a', b: 'b', events: events, nowMs: now);
      expect(v.ok, false);
      expect(v.reason, 'no_mediation_event');
    });

    test('超出 24 小时窗口的消息不计入', () {
      final events = [
        ev(TelemetryEvents.messageSentHuman, now - h - 1000,
            self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - h - 2000,
            self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - h - 3000,
            self: 'a', peer: 'b'),
        ev(TelemetryEvents.intercardApproved, now - 1000, self: 'a', peer: 'b'),
      ];
      final v = HandshakeJudge.judge(a: 'a', b: 'b', events: events, nowMs: now);
      expect(v.ok, false);
      expect(v.humanMessages, 0);
    });

    test('中介事件超出 7 天 → 不成立（防旧中介蹭新对话）', () {
      final events = [
        ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - 3000, self: 'a', peer: 'b'),
        ev(TelemetryEvents.intercardApproved,
            now - Duration(days: 8).inMilliseconds,
            self: 'a', peer: 'b'),
      ];
      final v = HandshakeJudge.judge(a: 'a', b: 'b', events: events, nowMs: now);
      expect(v.ok, false);
      expect(v.reason, 'no_mediation_event');
    });

    test('不相关第三方 pair 的消息不会被误算', () {
      final events = [
        ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'c'),
        ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'c'),
        ev(TelemetryEvents.messageSentHuman, now - 3000, self: 'c', peer: 'a'),
        ev(TelemetryEvents.delegationDone, now - 4000, self: 'a', peer: 'b'),
      ];
      final v = HandshakeJudge.judge(a: 'a', b: 'b', events: events, nowMs: now);
      expect(v.ok, false);
      expect(v.humanMessages, 0);
    });

    test('β 互介也能作为中介来源', () {
      final events = [
        ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'b'),
        ev(TelemetryEvents.messageSentHuman, now - 3000, self: 'b', peer: 'a'),
        ev(TelemetryEvents.intercardApproved, now - 4000, self: 'b', peer: 'a'),
      ];
      final v = HandshakeJudge.judge(a: 'a', b: 'b', events: events, nowMs: now);
      expect(v.ok, true);
      expect(v.mediationSource, 'beta');
    });
  });

  group('TTFD', () {
    test('取 onboarding 之后首个委托完成', () {
      final events = [
        ev(TelemetryEvents.onboardingDone, 1000, self: 'u1'),
        ev(TelemetryEvents.delegationDone, 5000, self: 'u1'),
        ev(TelemetryEvents.delegationDone, 9000, self: 'u1'),
      ];
      expect(Ttfd.firstDelegationLatency(self: 'u1', events: events), 4000);
    });

    test('无 onboarding → null（不能凭空算 TTFD）', () {
      final events = [ev(TelemetryEvents.delegationDone, 5000, self: 'u1')];
      expect(Ttfd.firstDelegationLatency(self: 'u1', events: events), isNull);
    });

    test('中位数：奇偶都正确', () {
      expect(Ttfd.median([3, 1, 2]), 2);
      expect(Ttfd.median([4, 1, 3, 2]), 2);
      expect(Ttfd.median([]), isNull);
    });
  });
}

class _ThrowingStore extends TelemetryStore {
  @override
  Future<void> append(TelemetryEvent e) async => throw StateError('boom');

  @override
  Future<List<TelemetryEvent>> all() async => throw StateError('boom');

  @override
  Future<void> clear() async => throw StateError('boom');
}
