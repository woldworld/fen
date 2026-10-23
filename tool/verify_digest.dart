// 纯 Dart 校验脚本：验证每日摘要（带动作）—— PRD §5.2 B 阶段 / §7.2 A3 实验。
// 运行：dart run tool/verify_digest.dart

import 'package:dahuang_ai/core/circle_service.dart';
import 'package:dahuang_ai/core/delegation_service.dart';
import 'package:dahuang_ai/core/digest_service.dart';

int _pass = 0;
int _fail = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

/// 假埋点：直接给事件列表
class FakeEvents {
  final List<Map<String, Object?>> rows = [];
  Future<List<Map<String, Object?>>> all() async => rows;
}

DigestSources _sources(MemoryDelegationStore store, FakeEvents events,
    {List<Map<String, dynamic>> joins = const []}) {
  return DigestSources(
    delegationStore: store,
    recentJoins: (self, since) async => joins,
    events: events.all,
  );
}

void main() async {
  final aliceStore = MemoryDelegationStore();
  final bobStore = MemoryDelegationStore();
  final aliceEvents = FakeEvents();
  final bobEvents = FakeEvents();

  final aliceSigner = await Ed25519Signer.generate();
  final bobSigner = await Ed25519Signer.generate();
  final alice = DelegationService(
      store: aliceStore,
      signer: aliceSigner,
      onEvent: (n, p) => aliceEvents.rows.add({'name': n, 'ts': 0, ...p}));
  final bob = DelegationService(
      store: bobStore,
      signer: bobSigner,
      onEvent: (n, p) => bobEvents.rows.add({'name': n, 'ts': 0, ...p}));

  // 与 service 的真实时钟保持同一基准（service 内部用 DateTime.now()）
  final now = DateTime.now().millisecondsSinceEpoch;
  final day = const Duration(hours: 24).inMilliseconds;

  print('--- A3 分桶 ---');
  check(DigestVariant.forId('a') == DigestVariant.forId('a'),
      '同一 ID 永远同组（确定性，重开不变）');
  final buckets = <String>{};
  for (var i = 0; i < 50; i++) {
    buckets.add(DigestVariant.forId('user$i'));
  }
  check(buckets.length == 2, '50 个 ID 恰好分成两组（50/50 分桶有效）');

  print('--- 空摘要 ---');
  final empty = await DigestService(sources: _sources(aliceStore, aliceEvents))
      .build(selfId: 'alice', untilMs: now);
  check(empty.isEmpty, '无事发生 → 空摘要');
  // 原为 `empty.toText().contains('没有新动态')`。core 已删掉中文文案工厂 `toText()`
  // （只被本脚本用、生产无调用点），改断言**结构化事实**（UI 正文由 l10n 渲染）。
  check(empty.facts.isEmpty, '空摘要：facts 必须为空（不能有幽灵条目）');
  check(empty.actions.isEmpty, '空摘要：不给任何动作按钮');

  print('--- 托我的 pending → 唯一带紧迫感的事实 ---');
  // alice 托 bob；alice 侧存一份（发起），bob 侧存一份（收到）
  final d1 = (await alice.create(
          circleId: 'c1', fromId: 'alice', toId: 'bob', task: '问下老王周末有没有空'))
      .delegation!;
  await bobStore.upsert(
      (await bobStore.byId(d1.id)) ?? d1); // bob 的库也放一份（模拟已收到）
  final rBob = await DigestService(sources: _sources(bobStore, bobEvents))
      .build(selfId: 'bob', untilMs: now);
  check(rBob.of(DigestFact.kindPendingInbox).length == 1, 'bob 看到 1 条待回执');
  // 原为 `rBob.toText().contains('等你回执')`。改断言"待回执就是摘要里唯一那条事实"。
  check(rBob.facts.length == 1, 'bob 摘要只有 1 条事实（就是那条待回执）');
  check(rBob.actions.any((a) => a.kind == DigestAction.kindOpenInbox) ==
      (rBob.variant == DigestVariant.withActions),
      '带动作组才出"去回执"按钮');

  print('--- 我托的：新下达 / 已回执 / 被拒 ---');
  final rAlice = await DigestService(sources: _sources(aliceStore, aliceEvents))
      .build(selfId: 'alice', untilMs: now);
  check(rAlice.of(DigestFact.kindSentNew).length == 1, 'alice 看到 1 条新下达');
  check(rAlice.of(DigestFact.kindPendingInbox).isEmpty, 'alice 没有待回执（不是托他的）');

  final answered = (await bob.respond(
    id: d1.id,
    responderId: 'bob',
    state: DelegationState.answered,
    response: '周六下午有空',
  ))!;
  await aliceStore.upsert(answered); // 回执传回 alice（transport 已验证，这里直接落）
  aliceEvents.rows.add({
    'name': 'delegation_done',
    'ts': now - 1000,
    'self': 'alice',
  });
  final rAlice2 = await DigestService(sources: _sources(aliceStore, aliceEvents))
      .build(selfId: 'alice', untilMs: now);
  check(rAlice2.of(DigestFact.kindSentAnswered).length == 1, '已回执进摘要');
  check(
      rAlice2.of(DigestFact.kindSentAnswered).first.data['response'] ==
          '周六下午有空',
      '回执内容带进摘要');
  check(rAlice2.of(DigestFact.kindErrandDone).length == 1, 'delegation_done 统计 1 条');
  // 原为 `rAlice2.toText().contains('办妥')`。改断言"有办妥统计时，带动作组才给『看看板』"。
  check(rAlice2.actions.any((a) => a.kind == DigestAction.kindOpenDashboard) ==
      (rAlice2.variant == DigestVariant.withActions),
      '有办妥/握手统计 → 才给"看看板"动作');

  print('--- 窗口过滤 ---');
  // 3 天前下达且当天就回执的委托：不在 24h 窗口内 → 不出现在摘要
  final oldStore = MemoryDelegationStore();
  final oldD = Delegation(
    id: 'old1',
    circleId: 'c1',
    fromId: 'alice',
    toId: 'bob',
    task: '三天前的事',
    createdAtMs: now - 3 * day,
    state: DelegationState.answered,
    respondedAtMs: now - 3 * day + 60000,
  );
  await oldStore.upsert(oldD);
  final rOld = await DigestService(sources: _sources(oldStore, FakeEvents()))
      .build(selfId: 'alice', untilMs: now);
  check(rOld.of(DigestFact.kindSentAnswered).isEmpty, '窗口外的旧委托不进摘要');
  // 但窗口内刚回执的旧委托要报
  final oldJustAnswered = Delegation(
    id: 'old2',
    circleId: 'c1',
    fromId: 'alice',
    toId: 'bob',
    task: '三天前下的，刚回执',
    createdAtMs: now - 3 * day,
    state: DelegationState.answered,
    respondedAtMs: now - 60000,
  );
  await oldStore.upsert(oldJustAnswered);
  final rOld2 = await DigestService(sources: _sources(oldStore, FakeEvents()))
      .build(selfId: 'alice', untilMs: now);
  check(rOld2.of(DigestFact.kindSentAnswered).length == 1,
      '旧委托窗口内刚回执 → 仍进摘要');

  print('--- 新入圈 + 握手 ---');
  final joins = [
    {'circle_id': 'c9', 'name': '里斯本同城', 'joined_at': now - 3600000}
  ];
  final evWithHs = FakeEvents();
  evWithHs.rows
      .add({'name': 'handshake', 'ts': now - 1000, 'self': 'alice'});
  final rJoin = await DigestService(
          sources: DigestSources(
        delegationStore: aliceStore,
        recentJoins: (self, since) async => joins,
        events: evWithHs.all,
      ))
      .build(selfId: 'alice', untilMs: now);
  check(rJoin.of(DigestFact.kindCircleJoined).length == 1, '新入圈进摘要');
  check(rJoin.of(DigestFact.kindHandshake).length == 1, '握手进摘要');
  check(rJoin.actions.any((a) => a.kind == DigestAction.kindOpenCircle) ==
      (rJoin.variant == DigestVariant.withActions), '入圈 → 动作"看我的圈"');

  print('--- 动作去重与优先级 ---');
  final report = await DigestService(sources: _sources(aliceStore, evWithHs))
      .build(selfId: 'alice', untilMs: now);
  final kinds = report.actions.map((a) => a.kind).toList();
  check(kinds.length == kinds.toSet().length, '动作不重复');
  if (report.variant == DigestVariant.withActions) {
    check(kinds.first == DigestAction.kindOpenInbox,
        '有待回执时"去回执"排第一（紧迫感优先）');
  }

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
