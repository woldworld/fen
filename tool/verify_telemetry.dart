// 纯 Dart 校验脚本：不依赖 flutter_test，可在受限环境下直接 `dart run`。
// 用途：证明 telemetry.dart 的握手判定与 TTFD 计算确实按 PRD §7.1 工作。
import 'package:dahuang_ai/core/telemetry.dart';

int _fail = 0;
int _pass = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

TelemetryEvent ev(String name, int ts, {String? self, String? peer}) =>
    TelemetryEvent(
      name: name,
      tsMs: ts,
      props: {
        if (self != null) 'self': self,
        if (peer != null) 'peer': peer,
      },
    );

Future<void> main() async {
  final now = 1000000000000;
  final h = const Duration(hours: 24).inMilliseconds;

  print('--- Telemetry 基础 ---');
  final store = MemoryTelemetryStore();
  final t = Telemetry(store);
  t.track(TelemetryEvents.onboardingDone, props: {'self': 'u1'});
  t.track(TelemetryEvents.circleEntered, props: {'self': 'u1'});
  t.track(TelemetryEvents.delegationDone, props: {'self': 'u1'});
  await Future<void>.delayed(Duration.zero);
  check((await t.events()).length == 3, 'track 写入 3 条事件');
  final funnel = await t.funnel();
  check(funnel.toString() == '[1, 1, 1, 0, 0]', 'funnel 顺序 = $funnel');

  print('--- HandshakeJudge (PRD §7.1) ---');
  final ok3 = [
    ev(TelemetryEvents.messageSentHuman, now - h ~/ 2, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - h ~/ 3, self: 'b', peer: 'a'),
    ev(TelemetryEvents.messageSentHuman, now - h ~/ 4, self: 'a', peer: 'b'),
    ev(TelemetryEvents.delegationDone, now - h, self: 'a', peer: 'b'),
  ];
  final v1 = HandshakeJudge.judge(a: 'a', b: 'b', events: ok3, nowMs: now);
  check(v1.ok && v1.mediationSource == 'alpha', '3 条真人消息 + α 委托 → 握手成立 ($v1)');

  final twoOnly = [
    ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.delegationDone, now - 3000, self: 'a', peer: 'b'),
  ];
  final v2 = HandshakeJudge.judge(a: 'a', b: 'b', events: twoOnly, nowMs: now);
  check(!v2.ok && v2.reason == 'human_messages_insufficient',
      '仅 2 条真人消息 → 不成立 ($v2)');

  final noMed = [
    ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - 3000, self: 'a', peer: 'b'),
  ];
  final v3 = HandshakeJudge.judge(a: 'a', b: 'b', events: noMed, nowMs: now);
  check(!v3.ok && v3.reason == 'no_mediation_event', '无中介事件 → 不成立 ($v3)');

  final stale = [
    ev(TelemetryEvents.messageSentHuman, now - h - 1000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - h - 2000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - h - 3000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.intercardApproved, now - 1000, self: 'a', peer: 'b'),
  ];
  final v4 = HandshakeJudge.judge(a: 'a', b: 'b', events: stale, nowMs: now);
  check(!v4.ok && v4.humanMessages == 0, '超 24h 窗口的消息不计入 ($v4)');

  final oldMed = [
    ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - 3000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.intercardApproved,
        now - const Duration(days: 8).inMilliseconds, self: 'a', peer: 'b'),
  ];
  final v5 = HandshakeJudge.judge(a: 'a', b: 'b', events: oldMed, nowMs: now);
  check(!v5.ok && v5.reason == 'no_mediation_event', '中介超 7 天 → 不成立 ($v5)');

  final wrongPair = [
    ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'c'),
    ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'c'),
    ev(TelemetryEvents.messageSentHuman, now - 3000, self: 'c', peer: 'a'),
    ev(TelemetryEvents.delegationDone, now - 4000, self: 'a', peer: 'b'),
  ];
  final v6 = HandshakeJudge.judge(a: 'a', b: 'b', events: wrongPair, nowMs: now);
  check(!v6.ok && v6.humanMessages == 0, '第三方 pair 的消息不误算 ($v6)');

  final beta = [
    ev(TelemetryEvents.messageSentHuman, now - 1000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - 2000, self: 'a', peer: 'b'),
    ev(TelemetryEvents.messageSentHuman, now - 3000, self: 'b', peer: 'a'),
    ev(TelemetryEvents.intercardApproved, now - 4000, self: 'b', peer: 'a'),
  ];
  final v7 = HandshakeJudge.judge(a: 'a', b: 'b', events: beta, nowMs: now);
  check(v7.ok && v7.mediationSource == 'beta', 'β 互介亦可作中介 ($v7)');

  print('--- TTFD ---');
  final ttfdEvents = [
    ev(TelemetryEvents.onboardingDone, 1000, self: 'u1'),
    ev(TelemetryEvents.delegationDone, 5000, self: 'u1'),
    ev(TelemetryEvents.delegationDone, 9000, self: 'u1'),
  ];
  check(Ttfd.firstDelegationLatency(self: 'u1', events: ttfdEvents) == 4000,
      'TTFD = onboarding → 首个委托完成 = 4000ms');
  check(Ttfd.firstDelegationLatency(self: 'u2', events: ttfdEvents) == null,
      '无 onboarding 的用户返回 null');
  check(Ttfd.median([3, 1, 2]) == 2 && Ttfd.median([4, 1, 3, 2]) == 2,
      '中位数奇偶均正确');
  check(Ttfd.median([]) == null, '空数组返回 null');

  print('--- 埋点不阻断业务 ---');
  final bad = Telemetry(_ThrowingStore());
  var threw = false;
  try {
    bad.track('anything');
  } catch (_) {
    threw = true;
  }
  check(!threw, '存储抛错时 track 不抛出');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}

class _ThrowingStore extends TelemetryStore {
  @override
  Future<void> append(TelemetryEvent e) async => throw StateError('boom');

  @override
  Future<List<TelemetryEvent>> all() async => throw StateError('boom');

  @override
  Future<void> clear() async => throw StateError('boom');
}
