// 纯 Dart 校验脚本：验证 M2「事务委托」。
// 运行：dart run tool/verify_delegation.dart
//
// 覆盖 PRD §4 M2 与 §7.1 TTFD 分阶段口径：
//   - 主人下达 → 对方 60s 内收到 → 明确回执（完成/需本人确认/拒绝）
//   - 零结算：数据模型无金额字段 + 结算措辞 fail-closed 拦截
//   - 全程留痕（双方签名）+ 可撤销
//   - 弱/强口径可切换，切换后历史数据仍可用

import 'package:dahuang_ai/core/circle_service.dart';
import 'package:dahuang_ai/core/delegation_service.dart';

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

/// 取非空结果；为 null 时**先记 FAIL 再抛**，避免脚本中途崩掉看不到失败项。
Delegation need(Delegation? d, String label) {
  if (d == null) {
    _fail++;
    print('  FAIL  $label（返回 null）');
    throw StateError('$label: null');
  }
  return d;
}

Future<void> main() async {
  final alice = await Ed25519Signer.generate();
  final bob = await Ed25519Signer.generate();
  final alicePub = await alice.publicKeyBase58();
  final bobPub = await bob.publicKeyBase58();

  final store = MemoryDelegationStore();
  final events = <Map<String, Object?>>[];
  final svcA = DelegationService(
      store: store, signer: alice, onEvent: (n, p) => events.add({'name': n, ...p}));
  final svcB = DelegationService(
      store: store, signer: bob, onEvent: (n, p) => events.add({'name': n, ...p}));

  print('--- 零结算护栏（PRD §2.3 明确不做）---');
  check(looksLikeSettlement('帮我转账 500 给老王'), '识别"转账"');
  check(looksLikeSettlement('帮我转 500 给老王'), '识别"转 500"（无"转账"二字）');
  check(looksLikeSettlement('please pay him 20'), '识别 "pay"');
  check(looksLikeSettlement('这顿你先垫付一下'), '识别"垫付"');
  check(looksLikeSettlement('帮我发个红包'), '识别"红包"');
  check(!looksLikeSettlement('帮我问下老王周末有没有空'), '正常委托不误拦');
  check(!looksLikeSettlement('问下他周末有没有空打球'), '含"打"字不误判为打钱');
  check(!looksLikeSettlement('问下他打 5 号场地行不行'), '"打 5 号"不误判为打钱');
  check(!looksLikeSettlement('帮我问下那个 500 块的票还有效吗'),
      '裸金额（500 块）不误伤');

  final blocked = await svcA.create(
      circleId: 'c1', fromId: 'alice', toId: 'bob', task: '帮我转账 500 给老王');
  check(blocked.blocked && blocked.reason == 'settlement_not_allowed',
      '结算类委托被拦截，不代发');
  check(blocked.delegation == null, '被拦时不产生委托记录');
  check(events.isEmpty, '被拦时不发埋点');

  final empty = await svcA.create(
      circleId: 'c1', fromId: 'alice', toId: 'bob', task: '   ');
  check(empty.blocked && empty.reason == 'empty_task', '空委托被拒');

  print('--- 下达与签收（M2 验收）---');
  final created = await svcA.create(
    circleId: 'c1',
    fromId: 'alice',
    toId: 'bob',
    task: '帮我问下老王周末有没有空',
  );
  check(created.ok, '委托创建成功');
  final d0 = created.delegation!;
  check(d0.state == DelegationState.pending, '初始为 pending');
  check(d0.reqSig != null && d0.fromPub == alicePub, '发起即签名（留痕，不可后补）');
  check(events.any((e) => e['name'] == 'delegation_sent'), '产出 delegation_sent');

  // B 端能取到（验收："B 端 60 秒内收到"的可观测等价物）
  final inboxB = await store.forPeer('bob');
  check(inboxB.any((d) => d.id == d0.id), '受托方可收到委托');

  print('--- 回执：完成 / 需本人确认 / 拒绝 ---');
  final done = need(
      await svcB.respond(
        id: d0.id,
        responderId: 'bob',
        state: DelegationState.answered,
        response: '老王周六下午有空',
      ),
      '回执=完成');
  check(done.state == DelegationState.answered, '回执=完成');
  check(done.respSig != null && done.toPub == bobPub, '回执侧也签名');
  check(done.isFinished, '完成后进入终态');
  final evDone =
      events.firstWhere((e) => e['name'] == 'delegation_done', orElse: () => {});
  check(evDone['result'] == 'done', 'delegation_done 带 result=done');
  check(evDone['duration_ms'] != null, 'delegation_done 带 duration_ms（TTFD 用）');
  check(evDone['basis'] == 'weak', 'delegation_done 带 basis（口径）');

  final d2 = (await svcA.create(
          circleId: 'c1', fromId: 'alice', toId: 'bob', task: '问下他周五几点到'))
      .delegation!;
  final needsHuman = need(
      await svcB.respond(
          id: d2.id, responderId: 'bob', state: DelegationState.needsHuman),
      '回执=需本人确认');
  check(needsHuman.state == DelegationState.needsHuman, '回执=需本人确认');
  check(needsHuman.canRevoke, '需本人确认状态仍可撤销');

  final d3 = (await svcA.create(
          circleId: 'c1', fromId: 'alice', toId: 'bob', task: '问下他能不能带设备'))
      .delegation!;
  final declined = need(
      await svcB.respond(
          id: d3.id, responderId: 'bob', state: DelegationState.declined),
      '回执=拒绝');
  check(declined.state == DelegationState.declined, '回执=拒绝');
  check(events.where((e) => e['name'] == 'delegation_done').length == 1,
      '拒绝不计入 delegation_done');

  print('--- 权限与状态机 ---');
  final d4 = (await svcA.create(
          circleId: 'c1', fromId: 'alice', toId: 'bob', task: '问下他住哪'))
      .delegation!;
  check(await svcA.respond(
          id: d4.id,
          responderId: 'alice',
          state: DelegationState.answered) ==
      null, '非受托方不能回执');
  check(await svcB.revoke(id: d4.id, ownerId: 'bob') == null, '非发起方不能撤销');
  check(
      await svcB.respond(
              id: d0.id, responderId: 'bob', state: DelegationState.answered) ==
          null,
      '已完成委托不可重复回执');

  print('--- 撤销 ---');
  final revoked =
      need(await svcA.revoke(id: d4.id, ownerId: 'alice'), '主人可撤销');
  check(revoked.state == DelegationState.revoked, '主人可撤销');
  check(events.any((e) => e['name'] == 'delegation_revoked'), '产出 delegation_revoked');
  check(revoked.isFinished, '撤销属终态');
  check(!revoked.canRevoke, '终态后不可再撤销');
  check(await svcA.revoke(id: d4.id, ownerId: 'alice') == null, '终态后撤销被拒');

  print('--- TTFD 口径（PRD §7.1）---');
  final d5 = (await svcA.create(
          circleId: 'c1', fromId: 'alice', toId: 'bob', task: '问下他周日有空吗'))
      .delegation!;
  final answered5 = need(
      await svcB.respond(
        id: d5.id,
        responderId: 'bob',
        state: DelegationState.answered,
        response: '有空',
      ),
      '回执（用于弱口径）');
  final t0 = answered5.respondedAtMs!;

  check(svcA.evaluateBasis(answered5, nowMs: t0 + 1000) == DelegationBasis.weak,
      '刚回执：弱口径暂定成立');

  // 真人否认（回执后 1h）→ 两种口径都不算
  final denied = need(await svcA.markHumanDenied(id: d5.id, atMs: t0 + 3600000),
      '真人否认留痕');
  check(svcA.evaluateBasis(denied, nowMs: t0 + 3600000) == null,
      '真人否认 → 任一口径都不算完成');
  check(denied.state == DelegationState.answered,
      '否认只改口径不改状态（留痕，不篡改事实）');

  // 回执后 25h 才否认 → 不回溯作废（否则历史口径永远悬空）
  final lateDenied =
      need(await svcA.markHumanDenied(id: d5.id, atMs: t0 + 25 * 3600000), '超窗否认');
  check(svcA.evaluateBasis(lateDenied, nowMs: t0 + 25 * 3600000) == DelegationBasis.weak,
      '超 24h 的否认不回溯作废已成立回执');

  // 换成真人确认 → 强口径
  final d6 = (await svcA.create(
          circleId: 'c1', fromId: 'alice', toId: 'bob', task: '问下他车几点到'))
      .delegation!;
  final answered6 = need(
      await svcB.respond(
        id: d6.id,
        responderId: 'bob',
        state: DelegationState.answered,
        response: '七点',
      ),
      '回执（用于强口径）');
  final t1 = answered6.respondedAtMs!;
  final confirmed = need(
      await svcA.markHumanConfirmed(
          id: d6.id, humanId: 'alice', atMs: t1 + 60000),
      '真人主动确认');
  check(svcA.evaluateBasis(confirmed, nowMs: t1 + 60000) == DelegationBasis.strong,
      '真人主动确认 → 强口径');
  check(
      svcA.evaluateBasis(
              confirmed, nowMs: t1 + const Duration(hours: 25).inMilliseconds) ==
          DelegationBasis.strong,
      '强口径不随"现在"漂移（口径写在记录里，M4 切换可整体重算）');

  // 回执后 25h 才确认 → 超出强口径窗口，退回弱口径
  final d8 = (await svcA.create(
          circleId: 'c1', fromId: 'alice', toId: 'bob', task: '问下他几点下班'))
      .delegation!;
  final answered8 = need(
      await svcB.respond(
          id: d8.id, responderId: 'bob', state: DelegationState.answered,
          response: '六点'),
      '回执（超时确认）');
  final t2 = answered8.respondedAtMs!;
  final lateConfirmed = need(
      await svcA.markHumanConfirmed(
          id: d8.id, humanId: 'alice', atMs: t2 + 25 * 3600000),
      '超窗确认');
  check(
      svcA.evaluateBasis(lateConfirmed, nowMs: t2 + 26 * 3600000) ==
          DelegationBasis.weak,
      '确认超出 24h → 退回弱口径（信号仍在，只是口径降级）');

  print('--- 未回执不算完成 ---');
  final d7 = (await svcA.create(
          circleId: 'c1', fromId: 'alice', toId: 'bob', task: '问下他明天来吗'))
      .delegation!;
  check(svcA.evaluateBasis(d7, nowMs: d7.createdAtMs + 1000) == null,
      'pending 不算完成');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
