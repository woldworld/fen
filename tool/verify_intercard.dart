// 纯 Dart 校验脚本：验证 M3 互介卡（PRD §4 M3 三条验收）。
// 运行：dart run tool/verify_intercard.dart
//
// 验收（二值）：
//   ① 未经确认的卡不会发出；
//   ② 第③级（仅本人可见）字段不出现在卡里 —— 键与**值**都进不来；
//   ③ 撤回后对方侧卡片消失（24h 窗口内）。

import 'package:dahuang_ai/core/circle_service.dart';
import 'package:dahuang_ai/core/intercard_service.dart';

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

/// 虚拟设备：独立 store + signer + service + relay
class Device {
  final String id;
  final Signer signer;
  final MemoryInterCardStore store = MemoryInterCardStore();
  final List<Map<String, Object?>> events = [];
  late final InterCardService svc;
  late final InterCardRelay relay;
  void Function(String target, String wire)? wire;
  bool online = true;

  Device(this.id, this.signer) {
    svc = InterCardService(
      store: store,
      signer: signer,
      onEvent: (n, p) => events.add({'name': n, ...p}),
    );
    relay = InterCardRelay(
      store: store,
      service: svc,
      selfId: () async => id,
      send: (target, w) async {
        if (!online) return false;
        wire?.call(target, w);
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
  final delivered = <String>[];
  alice.wire = (t, w) => delivered.add(w);
  bob.wire = (t, w) => delivered.add(w);

  final fields = {
    'nickname': '夜航星',
    'city': '里斯本',
    'interests': '天文学, 徒步',
    // 第③级：仅本人可见
    'phone': '+351-912-345-678',
    'home_address': 'Rua das Flores 42',
  };

  print('--- 验收②：第③级字段进不来 ---');
  final g1 = await alice.svc.generate(
    circleId: 'c1',
    ownerId: aliceId,
    toId: bobId,
    reason: '喜欢深夜聊黑洞，人也靠谱',
    topics: ['里斯本哪里能看到流星', '徒步装备推荐', '最近的科幻小说'],
    fields: fields,
    forbiddenKeys: {'phone', 'home_address'},
  );
  check(g1.ok, '正常生成');
  final c1 = g1.card!;
  check(!c1.fields.containsKey('phone'), '第③级键被剔除');
  check(!c1.fields.containsKey('home_address'), '第③级键被剔除（2）');
  check(!c1.visibleText().contains('+351-912-345-678'), '第③级值不在卡文本里');
  check(c1.fields['nickname'] == '夜航星', '第②级字段保留');

  // 主人把手机号写进了 reason → 值泄漏 → 整张卡拒绝生成
  final g2 = await alice.svc.generate(
    circleId: 'c1',
    ownerId: aliceId,
    toId: bobId,
    reason: '联系我 +351-912-345-678',
    topics: ['天文学'],
    fields: fields,
    forbiddenKeys: {'phone', 'home_address'},
  );
  check(!g2.ok && g2.reason == 'l3_leak', '第③级值写进 reason → fail-closed 拒绝生成');
  check(
      alice.events.any((e) =>
          e['name'] == 'intercard_generated' && e['contains_l3'] == true),
      '被拦的生成尝试留痕 contains_l3=true');

  print('--- 验收①：未经确认不发出 ---');
  final unconfirmed = await alice.svc.generate(
    circleId: 'c1',
    ownerId: aliceId,
    toId: bobId,
    reason: '喜欢聊城市更新',
    topics: ['里斯本老楼改造', '跳蚤市场', '手冲咖啡'],
    fields: {'nickname': '夜航星'},
  );
  final draft = unconfirmed.card!;
  check(!draft.isConfirmed, '草稿未确认');
  delivered.clear();
  check(!await alice.relay.dispatch(draft), '未确认卡 dispatch 被拒');
  check(delivered.isEmpty, '线上没有报文（验收①：不会发出）');
  check(
      alice.events.any((e) =>
          e['name'] == 'intercard_dropped' && e['reason'] == 'unconfirmed'),
      '绕过确认 → 留痕 unconfirmed');
  var threw = false;
  try {
    InterCardWire.encodeCard(draft);
  } catch (_) {
    threw = true;
  }
  check(threw, '线格式直接对未确认卡抛错（协议层兜底）');

  print('--- 确认 → 发出 → 对方收到 ---');
  final approved = (await alice.svc.approve(id: draft.id, approverId: aliceId))!;
  check(approved.isConfirmed && approved.sig != null, '确认后带签名');
  check(
      alice.events.any((e) =>
          e['name'] == 'intercard_approved' &&
          e['card_id'] == draft.id &&
          e['contains_l3'] == false),
      '产出 intercard_approved（β 中介事件，contains_l3 恒为否）');
  delivered.clear();
  check(await alice.relay.dispatch(approved), '确认后可发出');
  check(delivered.length == 1, '线上出现一条报文');
  final sent = (await alice.store.byId(draft.id))!;
  check(sent.sentAtMs != null, '发出时刻已回填（撤回窗口起点）');

  final consumed = await bob.relay.onIncoming(aliceId, delivered.last);
  check(consumed, 'Bob 认领互介报文');
  final inbox = await bob.store.inbox(bobId);
  check(inbox.any((c) => c.id == draft.id), 'Bob 的收件箱出现这张卡');
  check(!bob.events.any((e) => e['name'] == 'intercard_dropped'),
      '正常路径无丢弃');

  print('--- 对端安全 ---');
  // 篡改：改 reason 后重发 → 验签失败
  final tamperedJson =
      delivered.last.replaceAll('城市更新', '城市更新（改）');
  check(await bob.relay.onIncoming(aliceId, tamperedJson) == true, '篡改卡仍被认领');
  check(
      bob.events.any((e) =>
          e['name'] == 'intercard_dropped' && e['reason'] == 'bad_signature'),
      '篡改 → bad_signature 丢弃');

  // 冒名：报文说是 mallory 发的
  check(await bob.relay.onIncoming('mallory', delivered.last) == true, '冒名被认领');
  check(
      bob.events.any((e) =>
          e['name'] == 'intercard_dropped' && e['reason'] == 'sender_mismatch'),
      '冒名 → sender_mismatch');

  print('--- 验收③：24h 内撤回，对方侧消失 ---');
  // 未发出（sentAtMs == null）→ 不可撤回
  final d2 = (await alice.svc.generate(
          circleId: 'c1',
          ownerId: aliceId,
          toId: bobId,
          reason: '还没发出去的卡',
          topics: ['话题'],
          fields: {'nickname': '夜航星'}))
      .card!;
  check(await alice.svc.revoke(id: d2.id, revokerId: aliceId) == null,
      '未发出的卡不在撤回窗口内');
  // 非本人不能撤
  check(await alice.svc.revoke(id: draft.id, revokerId: 'mallory') == null,
      '非本人不能撤回');

  final revoked = (await alice.svc.revoke(id: draft.id, revokerId: aliceId))!;
  check(revoked.revokedAtMs != null, '24h 内本人可撤回');
  delivered.clear();
  check(await alice.relay.dispatchRevoke(revoked), '撤回报文发出');
  check(await bob.relay.onIncoming(aliceId, delivered.last) == true, 'Bob 认领撤回');
  check(!(await bob.store.inbox(bobId)).any((c) => c.id == draft.id),
      '验收③：对方侧卡片消失');
  check(await bob.store.byId(draft.id) == null, '本地记录已删除');

  // 撤回幂等：已撤回的卡不能再次撤回 / 二次撤回报文无害
  check(await alice.svc.revoke(id: draft.id, revokerId: aliceId) == null,
      '已撤回不可再撤');

  print('--- 24h 窗口 ---');
  final lateCard = InterCard(
    id: 'late1',
    circleId: 'c1',
    ownerId: aliceId,
    toId: bobId,
    reason: '超窗的卡',
    topics: ['话题'],
    fields: const {'nickname': 'x'},
    generatedAtMs: 0,
    approvedAtMs: 0,
    sentAtMs: 0, // 假装 1970 年发出
  );
  check(!lateCard.canRevokeAt(DateTime.now().millisecondsSinceEpoch),
      '发出超 24h → canRevokeAt=false');
  check(await alice.svc.revoke(id: 'late1', revokerId: aliceId) == null,
      '超窗撤回被拒（本地无此卡，行为一致）');

  print('--- 通道不通 ---');
  alice.online = false;
  final d3 = (await alice.svc.generate(
          circleId: 'c1',
          ownerId: aliceId,
          toId: bobId,
          reason: '离线时的卡',
          topics: ['话题'],
          fields: {'nickname': 'x'}))
      .card!;
  final d3ok = (await alice.svc.approve(id: d3.id, approverId: aliceId))!;
  check(!await alice.relay.dispatch(d3ok), '无通道 → dispatch false');
  check((await alice.store.byId(d3.id))!.sentAtMs == null,
      '无通道不回填 sentAtMs（撤回窗口不从失败投递起算）');
  check(
      alice.events.any((e) =>
          e['name'] == 'intercard_dropped' && e['reason'] == 'no_channel'),
      '无通道留痕');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
