// 纯 Dart 校验脚本：验证 M2 委托的**跨设备投递**（PRD §4「对方 60 秒内收到」）。
// 运行：dart run tool/verify_delegation_transport.dart
//
// 用两台"虚拟设备"（Alice / Bob，各自独立的 store + signer）+ 一条假通道，
// 把「下达 → 送达 → 对方落箱 → 回执 → 发起方收到」整条链路跑一遍，
// 不含任何平台依赖（flutter test 在本机跑不起来，这是既定验证方式）。

import 'dart:convert';

import 'package:dahuang_ai/core/circle_service.dart';
import 'package:dahuang_ai/core/delegation_service.dart';
import 'package:dahuang_ai/core/delegation_transport.dart';

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

/// 设备：独立的 store + signer + relay
class Device {
  final String id;
  final Signer signer;
  final MemoryDelegationStore store = MemoryDelegationStore();
  final List<Map<String, Object?>> events = [];
  late final DelegationService svc;
  late final DelegationRelay relay;

  /// 出站"网线"：投递成功时把报文交给这个回调（模拟通道已通）
  void Function(String target, String wire)? wire;
  bool online = true;

  Device(this.id, this.signer) {
    svc = DelegationService(
      store: store,
      signer: signer,
      onEvent: (n, p) => events.add({'name': n, ...p}),
    );
    relay = DelegationRelay(
      store: store,
      selfId: () async => id,
      send: (target, w) async {
        if (!online) return false;
        final sink = wire;
        if (sink == null) return false;
        sink(target, w);
        return true;
      },
      onEvent: (n, p) => events.add({'name': n, ...p}),
    );
  }
}

Future<void> main() async {
  const aliceId = 'alice';
  const bobId = 'bob';

  final alice = Device(aliceId, await Ed25519Signer.generate());
  final bob = Device(bobId, await Ed25519Signer.generate());

  // 网线：任何出站报文都直接送到 Bob（模拟"通道已通"）
  final delivered = <String>[];
  alice.wire = (target, w) {
    delivered.add(w);
  };
  bob.wire = (target, w) {
    delivered.add(w);
  };

  print('--- 线格式 ---');
  final created = (await alice.svc.create(
    circleId: 'c1',
    fromId: aliceId,
    toId: bobId,
    task: '帮我问下老王周末有没有空',
  ))
      .delegation!;

  final wireReq = DelegationWire.encode(created, DelegationWireKind.request);
  final parsed = DelegationWire.tryParse(wireReq);
  check(parsed != null, 'request 报文可解析');
  check(parsed!.kind == DelegationWireKind.request, 'kind=request');
  check(parsed.delegation.task == created.task, '内容往返一致');
  check(DelegationWire.tryParse('{"da_type":"gift"}') == null, '非委托报文不认领');
  check(DelegationWire.tryParse('hello 老王') == null, '普通聊天不认领');
  check(
      DelegationWire.tryParse(wireReq.replaceAll('"v":1', '"v":2')) == null,
      '版本不符不认领');
  check(DelegationWire.tryParse('{"da_type":"deleg","v":1,"kind":"request","d":{}}') == null,
      '缺签名的报文在解析阶段就被拒');
  check(DelegationWire.tryParse('x' * 9000) == null, '超长报文直接拒（防打爆）');

  print('--- 下达 → 对方收到（PRD: 60 秒内）---');
  final okSend = await alice.relay.dispatch(created);
  check(okSend, '投递成功（通道已通）');
  check(delivered.length == 1, '线上只有一条报文');

  final consumed = await bob.relay.onIncoming(aliceId, delivered.last);
  check(consumed, 'Bob 侧认领了这条报文（不再进聊天流水线）');
  final bobInbox = await bob.store.forPeer(bobId);
  check(bobInbox.any((d) => d.id == created.id), 'Bob 的收件箱里出现了这条委托');
  final got = (await bob.store.byId(created.id))!;
  check(got.state == DelegationState.pending, '收到时状态仍是 pending（不代客决策）');
  check(got.reqSig == created.reqSig, '签名随报文一起到达（可离线验）');

  final recv = bob.events.firstWhere(
    (e) => e['name'] == 'delegation_received',
    orElse: () => {},
  );
  check(recv['delegation_id'] == created.id, '产出 delegation_received');
  check(recv['delivery_ms'] != null, '带 delivery_ms（这才是「60 秒」能用的数）');

  print('--- 安全：验签 / 路由 ---');
  // ① 篡改内容
  final tampered = jsonDecode(wireReq) as Map<String, dynamic>;
  (tampered['d'] as Map)['task'] = '帮我转账 500 给老王';
  check(await bob.relay.onIncoming(aliceId, jsonEncode(tampered)) == true,
      '篡改报文仍被认领（不会漏进聊天流水线）');
  final afterTamper = await bob.store.byId(created.id);
  check(afterTamper!.task == created.task, '篡改内容被丢弃，本地记录未被覆盖');

  // ② 冒充：报文是 alice 签的，却说是 mallory 发的
  check(await bob.relay.onIncoming('mallory', wireReq) == true, '冒名报文被认领');
  check(
      bob.events.any((e) =>
          e['name'] == 'delegation_dropped' && e['reason'] == 'sender_mismatch'),
      '冒名 → sender_mismatch 丢弃并留痕');

  // ③ 路由不对：发给 carol 的报文送到了 bob
  final toCarol = (await alice.svc.create(
          circleId: 'c1', fromId: aliceId, toId: 'carol', task: '问下他几点到'))
      .delegation!;
  check(await bob.relay.onIncoming(aliceId,
          DelegationWire.encode(toCarol, DelegationWireKind.request)) ==
      true,
      '错投报文被认领');
  check(
      bob.events.any((e) =>
          e['name'] == 'delegation_dropped' && e['reason'] == 'misrouted'),
      '错投 → misrouted 丢弃并留痕');
  check(await bob.store.byId(toCarol.id) == null, '错投不落 Bob 的库');

  print('--- 回执：Bob → Alice ---');
  final answered = (await bob.svc.respond(
    id: created.id,
    responderId: bobId,
    state: DelegationState.answered,
    response: '老王周六下午有空',
  ))!;
  check(answered.respSig != null, '回执已签名');
  delivered.clear();
  final okReceipt = await bob.relay.dispatchReceipt(answered);
  check(okReceipt, '回执投递成功');
  final consumed2 = await alice.relay.onIncoming(bobId, delivered.last);
  check(consumed2, 'Alice 侧认领回执');
  final backHome = (await alice.store.byId(created.id))!;
  check(backHome.state == DelegationState.answered, 'Alice 看到状态变为已回执');
  check(backHome.response == '老王周六下午有空', '回执内容带回来了');
  check(
      alice.events.any((e) => e['name'] == 'delegation_receipt'),
      '产出 delegation_receipt');

  print('--- 回执侧的安全 ---');
  // 伪造回执：签名字节替换
  final forged = jsonDecode(delivered.last) as Map<String, dynamic>;
  (forged['d'] as Map)['resp_sig'] =
      base64Encode(List<int>.filled(64, 7));
  check(await alice.relay.onIncoming(bobId, jsonEncode(forged)) == true,
      '伪造回执被认领');
  check(
      alice.events.any((e) =>
          e['name'] == 'delegation_dropped' && e['reason'] == 'bad_signature'),
      '伪造回执 → bad_signature 丢弃');
  check((await alice.store.byId(created.id))!.state == DelegationState.answered,
      '伪造回执未改写本地状态');

  // 未知委托的回执：Bob 凭空造一条"alice 托我"的委托并回执 → Alice 侧没这条记录，
  // 必须拒绝凭空建档（否则任何人都能给自己伪造一份"已办妥"的留痕）
  final ghostCreated = (await bob.svc.create(
    circleId: 'c1',
    fromId: aliceId,
    toId: bobId,
    task: '问下他几点下班',
  ))
      .delegation!;
  final ghost = (await bob.svc.respond(
    id: ghostCreated.id,
    responderId: bobId,
    state: DelegationState.answered,
    response: '六点',
  ))!;
  check(
      await alice.relay.onIncoming(bobId,
              DelegationWire.encode(ghost, DelegationWireKind.receipt)) ==
          true,
      '未知委托的回执被认领');
  check(
      alice.events.any((e) =>
          e['name'] == 'delegation_dropped' &&
          e['reason'] == 'unknown_delegation'),
      '未知委托 → 不凭空建档');

  print('--- 通道不通时（对方离线）---');
  final offlineDev = Device('carol', await Ed25519Signer.generate());
  offlineDev.online = false;
  offlineDev.wire = (t, w) {};
  final offlineMsg = (await offlineDev.svc.create(
          circleId: 'c1', fromId: 'carol', toId: aliceId, task: '问下他明天来吗'))
      .delegation!;
  final okOffline = await offlineDev.relay.dispatch(offlineMsg);
  check(!okOffline, '无通道 → dispatch 返回 false');
  check(
      offlineDev.events.any((e) =>
          e['name'] == 'delegation_dropped' && e['reason'] == 'no_channel'),
      '无通道 → 留痕 no_channel（与"发出去没回音"区分开）');
  check((await offlineDev.store.byId(offlineMsg.id))!.state ==
          DelegationState.pending,
      '本地记录仍在（不会假装送达）');

  print('--- 幂等 ---');
  final before = await bob.store.byId(created.id);
  await bob.relay.onIncoming(aliceId, wireReq);
  final after = await bob.store.byId(created.id);
  check(before!.state == after!.state, '重复收到已完成委托不覆盖');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
