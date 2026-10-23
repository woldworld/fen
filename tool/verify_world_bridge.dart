// 纯 Dart 校验脚本：验证 M5「世界房间 = 圈的载体」（PRD §4 M5）。
// 运行：dart run tool/verify_world_bridge.dart
//
// 验收（二值）：**两个原本不认识的圈子，因同一房间产生 ≥1 次互介。**
//
// 本机侧的可证形式 = 存在一条跨圈边，满足：
//   ① 边有房间出处（因房间产生，不是通讯录里翻出来的）；
//   ② 对端不在我任一成员圈内（→ 必然来自另一个圈）；
//   ③ 这条边挂在"我的圈"上（myCircleId 非空）。
// 同时验证四条铁律的 fail-closed：没进过房间 / 同圈 / 已连接 / 重复，一律建不出边。

import 'package:dahuang_ai/core/circle_service.dart';
import 'package:dahuang_ai/core/intercard_service.dart';
import 'package:dahuang_ai/core/world_bridge_service.dart';

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

const int kNow = 1800000000000; // 固定时钟：结果可复算

/// 造一条房间观测：某人在某房间说了 n 句话
RoomPresence seen(String room, String agent,
        {String nickname = '', int n = 1, int agoMs = 0}) =>
    RoomPresence(
      roomId: room,
      agentId: agent,
      nickname: nickname,
      msgCount: n,
      lastSeenMs: kNow - agoMs,
    );

Future<void> main() async {
  const alice = 'alice';
  const carol = 'carol'; // alice 同圈的人
  const bob = 'bob'; // 另一个圈（cB）的人
  const dave = 'dave'; // 另一个圈（cB）的人
  const erin = 'erin'; // 房间里的圈外人，但 alice 早就加过好友
  const room = 'lisbon-night';

  final store = MemoryBridgeLinkStore();
  final events = <Map<String, Object?>>[];
  final svc = WorldBridgeService(
    store: store,
    onEvent: (n, p) => events.add({'name': n, ...p}),
  );

  // ---- 事实：房间里的出现记录（跨圈边唯一的合法出处）----
  final presences = <RoomPresence>[
    seen(room, carol, nickname: 'Carol', n: 12),
    seen(room, bob, nickname: 'Bob', n: 8),
    seen(room, dave, nickname: 'Dave', n: 3),
    seen(room, erin, nickname: 'Erin', n: 2),
    // 别的房间的观测：不算这个房间的出处
    seen('other-room', bob, n: 1),
  ];

  WorldBridgeInput input({
    Set<String> circleMembers = const {carol},
    Set<String> linkedPeers = const {erin},
    List<BridgeLink> links = const [],
  }) =>
      WorldBridgeInput(
        selfId: alice,
        presences: presences,
        circleMembers: circleMembers,
        linkedPeers: linkedPeers,
        links: links,
        nowMs: kNow,
      );

  print('--- 朋友池采集：圈内 / 跨圈新人 / 已连接 ---');
  final pool = svc.pool(input(), roomId: room);
  final cross = pool.crossCircle.map((c) => c.agentId).toList();
  check(pool.crossCircleCount == 2, '跨圈新人 = 2（bob / dave）');
  check(cross.contains(bob) && cross.contains(dave), '正是 bob 与 dave');
  check(!cross.contains(carol), '同圈的人不进跨圈池');
  check(!cross.contains(erin), '已连接的人不进跨圈池');
  check(pool.sameCircle.length == 1 && pool.sameCircle.first.agentId == carol,
      'carol 归入同圈');
  check(pool.linked.length == 1 && pool.linked.first.agentId == erin,
      'erin 归入已连接');
  check(pool.crossCircle.first.agentId == bob,
      '排序：共同房间多优先（bob 2 房 > dave 1 房）');
  check(pool.crossCircle.every((c) => c.bridgeable), '跨圈项均为可建边');
  check(pool.crossCircle.first.sharedRooms == 2,
      '出处可解释：bob 在 2 个房间遇见过（rooms 跨房间统计）');
  check(pool.crossCircle.last.sharedRooms == 1, 'dave 只在 1 个房间遇见过');

  print('--- 铁律 1：边必须有出处 ---');
  final ghost = await svc.link(
      input: input(), roomId: room, peerId: 'stranger', myCircleId: 'cA');
  check(!ghost.ok && ghost.reason == BridgeBlockCode.notInRoom,
      '没在房间出现过 → not_in_room');
  check(
      events.any((e) =>
          e['name'] == 'bridge_link_blocked' &&
          e['reason'] == BridgeBlockCode.notInRoom),
      '被拒也留痕（否则"没有假边"没有证据）');

  final otherRoom = await svc.link(
      input: input(), roomId: 'other-room', peerId: dave, myCircleId: 'cA');
  check(!otherRoom.ok && otherRoom.reason == BridgeBlockCode.notInRoom,
      '在别的房间出现过 ≠ 在这个房间出现过');

  final noRoom = await svc.link(
      input: input(), roomId: '', peerId: bob, myCircleId: 'cA');
  check(!noRoom.ok && noRoom.reason == BridgeBlockCode.noRoom,
      '缺房间出处 → no_room');

  print('--- 铁律 2/3：同圈 / 已连接 不重复建边 ---');
  final same = await svc.link(
      input: input(), roomId: room, peerId: carol, myCircleId: 'cA');
  check(!same.ok && same.reason == BridgeBlockCode.sameCircle,
      '同圈 → same_circle');

  final linked = await svc.link(
      input: input(), roomId: room, peerId: erin, myCircleId: 'cA');
  check(!linked.ok && linked.reason == BridgeBlockCode.alreadyLinked,
      '已经连接过 → already_linked');

  final self = await svc.link(
      input: input(), roomId: room, peerId: alice, myCircleId: 'cA');
  check(!self.ok && self.reason == BridgeBlockCode.self, '不能和自己建边');

  print('--- 建边：跨圈 + 有出处 + 原本不认识 ---');
  final r1 = await svc.link(
      input: input(), roomId: room, peerId: bob, myCircleId: 'cA');
  check(r1.ok && r1.created, 'alice → bob 建边成功');
  check(r1.link!.roomId == room, '边的出处 = lisbon-night');
  check(r1.link!.myCircleId == 'cA', '边挂在我的圈 cA 上');
  check(r1.link!.id == '$alice->$bob', '边 ID 天然幂等（self->peer）');
  check(
      events.any((e) =>
          e['name'] == 'bridge_link_created' &&
          e['peer'] == bob &&
          e['room_id'] == room),
      '留痕 bridge_link_created（带房间出处）');

  print('--- 铁律 4：幂等（同一个人只留一条边）---');
  final linksAfter1 = await store.linksOf(alice);
  final r2 = await svc.link(
      input: input(links: linksAfter1),
      roomId: room,
      peerId: bob,
      myCircleId: 'cA');
  check(r2.reason == BridgeBlockCode.duplicate, '重复建边 → duplicate');
  check(!r2.created, '重复调用不新建');
  check((await store.linksOf(alice)).length == 1, '账上仍只有 1 条边');

  // 第二条边：dave（另一个圈的第二个人）
  final r3 = await svc.link(
      input: input(links: linksAfter1),
      roomId: room,
      peerId: dave,
      myCircleId: 'cA');
  check(r3.ok && r3.created, 'alice → dave 建边成功');
  final links = await store.linksOf(alice);
  check(links.length == 2, '账上共 2 条跨圈边');

  print('--- 房间活跃度三档 ---');
  final hot = svc.activity(
      input(), roomId: room, serverMessages: 40);
  check(hot.vibrancy == RoomVibrancy.hot, '4 人发言 + 40 条 → 🔥 hot');
  check(hot.activeSpeakers == 4, '窗口内独立发言者 = 4');
  check(hot.messagesAreExact, '服务端精确条数已采纳');
  check(hot.crossCircleSpeakers == 3, '其中圈外 3 人（bob/dave/erin）');

  final warmInput = WorldBridgeInput(
    selfId: alice,
    presences: [seen(room, bob, n: 3), seen(room, dave, n: 2)],
    circleMembers: const {carol},
    linkedPeers: const {erin},
    nowMs: kNow,
  );
  check(svc.activity(warmInput, roomId: room).vibrancy == RoomVibrancy.warm,
      '2 人发言 → 🌤 warm');
  final emptyInput = WorldBridgeInput(selfId: alice, nowMs: kNow);
  check(svc.activity(emptyInput, roomId: room).vibrancy == RoomVibrancy.cold,
      '无人发言 → 🌙 cold');

  final stale = svc.activity(
      WorldBridgeInput(
        selfId: alice,
        // 30 小时前的观测：超出 24h 窗口 → 不计入活跃
        presences: [
          seen(room, bob, n: 9, agoMs: 30 * 3600 * 1000),
          seen(room, dave, n: 9, agoMs: 30 * 3600 * 1000),
        ],
        nowMs: kNow,
      ),
      roomId: room);
  check(stale.vibrancy == RoomVibrancy.cold, '超窗口的旧观测不计入活跃（不虚报）');

  print('--- 指标：人均跨圈连接数（本机口径）---');
  final m = svc.metric(input(links: links));
  check(m.crossCircleLinks == 2, '我的跨圈边 = 2');
  check(m.sameCircleAgents == 1, '圈内接触 1 人（carol）');
  check(m.crossCircleContacts == 3, '跨圈接触 3 人（bob/dave/erin）');
  check(m.knownAgents == 4, '接触过 4 个不同分身（分母如实，不注水）');
  check((m.perCapita2 - 0.5).abs() < 1e-9, '人均跨圈连接数 = 0.5（2/4）');

  print('--- 验收（二值）：两个原本不认识的圈子，因同一房间产生 ≥1 次互介 ---');
  final acc = svc.acceptance(input(links: links));
  check(acc.met, '验收成立');
  check(acc.evidence != null, '带证据（可当场回答"哪条边、因哪个房间"）');
  check(acc.evidence!.roomId == room, '证据：边因 lisbon-night 产生');
  check(!acc.evidence!.peerId.isEmpty, '证据：对端是一个圈外人');
  check(acc.reason == 'room_backed_cross_circle', '理由码 room_backed_cross_circle');

  // 反例：若边没有房间出处（凭空认识），验收不成立 —— 证明"房间"是承重的
  final noRoomLinks = <BridgeLink>[
    BridgeLink(
        selfId: alice, peerId: bob, roomId: '', myCircleId: 'cA', atMs: kNow),
  ];
  final acc2 = svc.acceptance(input(links: noRoomLinks));
  check(!acc2.met && acc2.reason == 'no_room_backed_link',
      '没有房间出处的边不算验收（房间是承重结构）');

  // 反例：同圈的人之间连不成跨圈边 → 也不构成"两个圈子"
  final sameCircleLinks = <BridgeLink>[
    BridgeLink(
        selfId: alice,
        peerId: carol,
        roomId: room,
        myCircleId: 'cA',
        atMs: kNow),
  ];
  final acc3 = svc.acceptance(input(links: sameCircleLinks));
  check(!acc3.met, '同圈之间的"边"不构成跨圈验收');

  // -------------------------------------------------------------------------
  // 端到端复算 UI 实际路径：世界页「朋友池互荐」→ 房间页建边 → 互介卡
  //
  // 这一段专门盯住 M5 的最后一个尾巴：`circleId` 必须来自**我自己的圈**，
  // 不能再像改造前那样硬编码 'direct' —— 否则边与卡都没有圈归属，
  // "房间是圈的载体"就退化成一句口号。
  // -------------------------------------------------------------------------
  print('--- 端到端：世界页互荐 → 房间建边 → 互介卡（UI 实际路径）---');

  // UI 用 circleStore.circlesOf(selfId).first['circle_id'] 解出"我的圈"
  final circleStore = MemoryCircleStore();
  await circleStore.upsertCircle(id: 'cA', name: 'Lisbon Circle');
  await circleStore.upsertMembership(CircleMembership(
    circleId: 'cA',
    memberId: alice,
    memberPub: 'pubA',
    inviterId: alice,
    joinedAtMs: kNow,
  ));
  final myCircleIds = (await circleStore.membersOf('cA'))
      .where((m) => m.memberId == alice)
      .map((m) => m.circleId)
      .toList();
  final myCircleId = myCircleIds.isEmpty ? '' : myCircleIds.first;
  check(myCircleId == 'cA', 'UI 解圈：circleId 来自"我的圈"');
  check(myCircleId != 'direct', 'circleId 不再是硬编码的 direct');

  // 房间页建边（用 UI 解出来的 circleId）
  final e2eStore = MemoryBridgeLinkStore();
  final e2eSvc = WorldBridgeService(store: e2eStore);
  final e2eInput = input(links: const []);
  final e2eRes = await e2eSvc.link(
      input: e2eInput, roomId: room, peerId: bob, myCircleId: myCircleId);
  check(e2eRes.ok && e2eRes.created, '因房间建成跨圈边');
  check(e2eRes.link!.myCircleId == myCircleId, '边挂在"我的圈"上');
  check(e2eRes.link!.roomId == room, '边的出处 = 该房间（不是通讯录）');

  // 互介卡：与边同源同圈
  final icSvc = InterCardService(
    store: MemoryInterCardStore(),
    signer: await Ed25519Signer.generate(),
  );
  final genCard = await icSvc.generate(
    circleId: myCircleId,
    ownerId: alice,
    toId: bob,
    reason: '同房间聊得来',
    topics: ['CFD', 'SAP2000', '风洞'],
    fields: {'nickname': 'Alice', 'mask_profile': '结构工程师'},
    forbiddenKeys: {'phone', 'home_address', 'legal_name'},
  );
  check(genCard.ok, '互介卡生成成功');
  check(genCard.card!.circleId == myCircleId, '卡与边同源同圈（同一个 circleId）');
  check(genCard.card!.circleId != 'direct', '卡也不再硬编码 direct');
  final approvedCard =
      await icSvc.approve(id: genCard.card!.id, approverId: alice);
  check(approvedCard != null && approvedCard.isConfirmed,
      '主人确认后卡带签名（才可能发出）');

  // 二值验收：边有房间出处 + 对端不在我圈内 + 边挂在"我的圈"上
  final accE2E = e2eSvc.acceptance(WorldBridgeInput(
    selfId: alice,
    presences: presences,
    circleMembers: {'carol'},
    linkedPeers: {'erin'},
    links: await e2eStore.linksOf(alice),
    nowMs: kNow,
  ));
  check(accE2E.met, '端到端验收成立（两个圈子，因同一房间互介 ≥1 次）');
  check(accE2E.evidence!.peerId == bob, '证据指向那个圈外对端');

  // -------------------------------------------------------------------------
  // ③ 边界与不变量（穷尽状态机：优先级顺序 / 阈值 / 窗口 / 去重 / 往返）
  //
  // 纯逻辑脚本最容易"看着绿其实漏"的就是边界：判据是 >= 还是 >、多个拒绝码
  // 谁先谁后、空/空白输入是否 fail-closed、分母是否注水。下面逐条钉死，
  // 让任何一次口径漂移都能在本地当场暴露。
  // -------------------------------------------------------------------------
  print('--- ③a 建边拒绝码的优先级（顺序即语义）---');

  // no_room 是第 0 道闸：空白房间先于 self
  final noRoomSelf = await svc.link(
      input: input(), roomId: '   ', peerId: alice, myCircleId: 'cA');
  check(!noRoomSelf.ok && noRoomSelf.reason == BridgeBlockCode.noRoom,
      'roomId 全空白 → no_room（先于 self）');

  // self 先于 not_in_room：和自己建边与"在不在房间"无关
  final selfNoSeen = await svc.link(
      input: input(), roomId: room, peerId: alice, myCircleId: 'cA');
  check(!selfNoSeen.ok && selfNoSeen.reason == BridgeBlockCode.self,
      '和自己建边 → self（先于 not_in_room）');

  // not_in_room 先于 same_circle：同圈但没进过房间，仍是 not_in_room
  final circleNotInRoom = await svc.link(
      input: input(circleMembers: const {'carol', 'zoe'}),
      roomId: room,
      peerId: 'zoe',
      myCircleId: 'cA');
  check(!circleNotInRoom.ok &&
          circleNotInRoom.reason == BridgeBlockCode.notInRoom,
      '同圈但未进房 → not_in_room（房间出处先于圈关系）');

  // not_in_room 先于 already_linked
  final linkedNotInRoom = await svc.link(
      input: input(linkedPeers: const {'erin', 'yvonne'}),
      roomId: room,
      peerId: 'yvonne',
      myCircleId: 'cA');
  check(!linkedNotInRoom.ok &&
          linkedNotInRoom.reason == BridgeBlockCode.notInRoom,
      '已连接但未进房 → not_in_room');

  // same_circle 先于 already_linked：同时命中两集合 → same_circle
  final bothCircleAndLinked = await svc.link(
      input: input(
          circleMembers: const {'bob'}, linkedPeers: const {'bob'}),
      roomId: room,
      peerId: bob,
      myCircleId: 'cA');
  check(!bothCircleAndLinked.ok &&
          bothCircleAndLinked.reason == BridgeBlockCode.sameCircle,
      '同时命中同圈/已连接 → same_circle 优先');

  // already_linked 先于 duplicate：已有边 + 也在已连接集合 → already_linked
  final dupStore = MemoryBridgeLinkStore();
  final dupSvc = WorldBridgeService(store: dupStore);
  await dupSvc.link(
      input: input(), roomId: room, peerId: bob, myCircleId: 'cA');
  final dupRes = await dupSvc.link(
      input: input(
          links: await dupStore.linksOf(alice), linkedPeers: const {'erin', bob}),
      roomId: room,
      peerId: bob,
      myCircleId: 'cA');
  check(dupRes.reason == BridgeBlockCode.alreadyLinked,
      '已连接集合命中时 → already_linked（先于 duplicate）');

  print('--- ③b 铁律 1 的"确证发言"边界 ---');

  // msgCount=0 的观测：不算"出现过"（fail-closed）
  final zeroInput = WorldBridgeInput(
    selfId: alice,
    presences: [seen(room, bob, n: 0)],
    nowMs: kNow,
  );
  final zeroRes = await WorldBridgeService(store: MemoryBridgeLinkStore())
      .link(input: zeroInput, roomId: room, peerId: bob, myCircleId: 'cA');
  check(!zeroRes.ok && zeroRes.reason == BridgeBlockCode.notInRoom,
      '仅 msgCount=0 的观测 → not_in_room（不算"出现过"）');

  // 对照：msgCount=1 恰在下界内（可建边）
  final oneRes = await WorldBridgeService(store: MemoryBridgeLinkStore()).link(
      input: WorldBridgeInput(
        selfId: alice,
        presences: [seen(room, bob, n: 1)],
        nowMs: kNow,
      ),
      roomId: room,
      peerId: bob,
      myCircleId: 'cA');
  check(oneRes.ok && oneRes.created, 'msgCount=1 恰在下界内 → 可建边');

  // 自己在房间里的观测恒被排除
  final selfSeenPool = svc.pool(
      WorldBridgeInput(
        selfId: alice,
        presences: [seen(room, alice, n: 9), seen(room, bob, n: 1)],
        nowMs: kNow,
      ),
      roomId: room);
  check(!selfSeenPool.crossCircle.any((c) => c.agentId == alice) &&
          selfSeenPool.crossCircleCount == 1,
      '自己的观测不进池；排除后跨圈数如实');

  print('--- ③c 活跃度阈值（>= 与"取较热档"）---');
  check(RoomActivity.grade(speakers: 5, messages: 0) == RoomVibrancy.hot,
      'speakers=5（下界）→ hot');
  check(RoomActivity.grade(speakers: 4, messages: 0) == RoomVibrancy.warm,
      'speakers=4（下界-1）→ warm');
  check(RoomActivity.grade(speakers: 2, messages: 0) == RoomVibrancy.warm,
      'speakers=2（warm 下界）→ warm');
  check(RoomActivity.grade(speakers: 1, messages: 0) == RoomVibrancy.cold,
      'speakers=1 → cold');
  check(RoomActivity.grade(speakers: 0, messages: 20) == RoomVibrancy.hot,
      'messages=20（下界）→ hot（条数可单独抬档）');
  check(RoomActivity.grade(speakers: 0, messages: 19) == RoomVibrancy.warm,
      'messages=19 → warm');
  check(RoomActivity.grade(speakers: 0, messages: 5) == RoomVibrancy.warm,
      'messages=5（warm 下界）→ warm');
  check(RoomActivity.grade(speakers: 0, messages: 4) == RoomVibrancy.cold,
      'messages=4 → cold');
  check(RoomActivity.grade(speakers: 4, messages: 19) == RoomVibrancy.warm,
      '两判据同为 warm → warm');
  check(RoomActivity.grade(speakers: 1, messages: 20) == RoomVibrancy.hot,
      '人数冷但条数热 → 取较热 hot');

  print('--- ③d 活跃度窗口边界（>=：恰好在界内）---');
  final justInside = svc.activity(
      WorldBridgeInput(
        selfId: alice,
        presences: [seen(room, bob, n: 1, agoMs: 24 * 3600 * 1000)],
        nowMs: kNow,
      ),
      roomId: room);
  check(justInside.activeSpeakers == 1, '恰好 24h（界上）→ 计入活跃');
  final justOutside = svc.activity(
      WorldBridgeInput(
        selfId: alice,
        presences: [seen(room, bob, n: 1, agoMs: 24 * 3600 * 1000 + 1)],
        nowMs: kNow,
      ),
      roomId: room);
  check(justOutside.activeSpeakers == 0, '24h+1ms → 不计入（界外）');

  // serverMessages=0 是显式精确值（0 ≠ null）
  final exactZero = svc.activity(
      WorldBridgeInput(
        selfId: alice,
        presences: [seen(room, bob, n: 3), seen(room, dave, n: 2)],
        nowMs: kNow,
      ),
      roomId: room,
      serverMessages: 0);
  check(exactZero.messages == 0 && exactZero.messagesAreExact,
      'serverMessages=0 被采纳为精确值（0 ≠ null）');
  check(exactZero.vibrancy == RoomVibrancy.warm,
      '条数 0 但 2 人发言 → 仍按人数判 warm');

  print('--- ③e 指标不变量（分母不注水 / 去重 / 归属）---');
  final emptyMetric = svc.metric(WorldBridgeInput(selfId: alice, nowMs: kNow));
  check(emptyMetric.knownAgents == 0 && emptyMetric.perCapita2 == 0,
      '零接触 → 人均=0（不做除零）');
  final m2 = svc.metric(WorldBridgeInput(
    selfId: alice,
    presences: [seen(room, carol, n: 1)],
    circleMembers: const {'carol', 'zoe'},
    nowMs: kNow,
  ));
  check(m2.sameCircleAgents == 1,
      '同圈接触数 = 观测到的交集（未观测的圈成员不计）');
  final m3 = svc.metric(WorldBridgeInput(
    selfId: alice,
    presences: [seen(room, erin, n: 1)],
    linkedPeers: const {'erin'},
    nowMs: kNow,
  ));
  check(m3.crossCircleContacts == 1, '已连接的人仍计入跨圈接触（分母如实）');
  final dupLinks = <BridgeLink>[
    BridgeLink(
        selfId: alice, peerId: bob, roomId: room, myCircleId: 'cA', atMs: kNow),
    BridgeLink(
        selfId: alice,
        peerId: bob,
        roomId: room,
        myCircleId: 'cA',
        atMs: kNow + 1),
  ];
  check(
      svc
              .metric(WorldBridgeInput(
                  selfId: alice, links: dupLinks, nowMs: kNow))
              .crossCircleLinks ==
          1,
      '重复对端只算一条跨圈边');
  final foreignLinks = <BridgeLink>[
    BridgeLink(
        selfId: bob, peerId: dave, roomId: room, myCircleId: 'cB', atMs: kNow),
  ];
  check(
      svc
              .metric(WorldBridgeInput(
                  selfId: alice, links: foreignLinks, nowMs: kNow))
              .crossCircleLinks ==
          0,
      '别人名下的边不计入我的跨圈边');

  print('--- ③f 验收：证据选择与空/空白输入 ---');
  final noLinks = svc.acceptance(WorldBridgeInput(selfId: alice, nowMs: kNow));
  check(!noLinks.met &&
          noLinks.evidence == null &&
          noLinks.reason == 'no_room_backed_link',
      '无边 → 验收不成立且无证据（fail-closed）');
  final blankCircle = svc.acceptance(WorldBridgeInput(
    selfId: alice,
    links: [
      BridgeLink(
          selfId: alice,
          peerId: bob,
          roomId: room,
          myCircleId: '   ',
          atMs: kNow),
    ],
    nowMs: kNow,
  ));
  check(!blankCircle.met, 'myCircleId 全空白 → 不算验收（trim 后为空）');
  final blankRoom = svc.acceptance(WorldBridgeInput(
    selfId: alice,
    links: [
      BridgeLink(
          selfId: alice,
          peerId: bob,
          roomId: '   ',
          myCircleId: 'cA',
          atMs: kNow),
    ],
    nowMs: kNow,
  ));
  check(!blankRoom.met, 'roomId 全空白 → 不算验收');
  final pickSecond = svc.acceptance(WorldBridgeInput(
    selfId: alice,
    circleMembers: const {'carol'},
    links: [
      BridgeLink(
          selfId: alice,
          peerId: carol,
          roomId: room,
          myCircleId: 'cA',
          atMs: kNow),
      BridgeLink(
          selfId: alice, peerId: bob, roomId: room, myCircleId: 'cA', atMs: kNow),
    ],
    nowMs: kNow,
  ));
  check(pickSecond.met && pickSecond.evidence!.peerId == bob,
      '跳过同圈边，证据取第一条合格的跨圈边');

  print('--- ③g 朋友池：分类归属、排序、去重 ---');
  final precPool = svc.pool(
      WorldBridgeInput(
        selfId: alice,
        presences: [seen(room, bob, n: 1)],
        circleMembers: const {'bob'},
        linkedPeers: const {'bob'},
        nowMs: kNow,
      ),
      roomId: room);
  check(precPool.sameCircle.length == 1 &&
          precPool.crossCircle.isEmpty &&
          precPool.linked.isEmpty,
      '池分类：同圈/已连接同时命中 → 单归属同圈');
  final tiePool = svc.pool(
      WorldBridgeInput(
        selfId: alice,
        presences: [seen(room, bob, n: 1), seen(room, dave, n: 1)],
        nowMs: kNow,
      ),
      roomId: room);
  check(tiePool.crossCircle.map((c) => c.agentId).toList().toString() ==
          '[bob, dave]',
      '同分同条 → 按 ID 升序（bob < dave，可复算）');
  final dupObsPool = svc.pool(
      WorldBridgeInput(
        selfId: alice,
        presences: [seen(room, bob, n: 2), seen(room, bob, n: 3)],
        nowMs: kNow,
      ),
      roomId: room);
  check(
      dupObsPool.crossCircleCount == 1 &&
          dupObsPool.crossCircle.first.msgCount == 5,
      '同房间多条观测 → 候选唯一、条数累加（2+3=5）');
  final offRoomPool = svc.pool(
      WorldBridgeInput(
        selfId: alice,
        presences: [seen('other-room', bob, n: 9)],
        nowMs: kNow,
      ),
      roomId: room);
  check(offRoomPool.isEmpty, '只有别的房间观测 → 本房间朋友池为空');

  print('--- ③h 存储：幂等（PK）与账本序 ---');
  final idemStore = MemoryBridgeLinkStore();
  await idemStore.insert(BridgeLink(
      selfId: alice, peerId: bob, roomId: room, myCircleId: 'cA', atMs: kNow));
  await idemStore.insert(BridgeLink(
      selfId: alice,
      peerId: bob,
      roomId: 'later-room',
      myCircleId: 'cA',
      atMs: kNow + 5));
  final idemRows = await idemStore.linksOf(alice);
  check(idemRows.length == 1 && idemRows.first.roomId == 'later-room',
      '同 (self,peer) 二次 insert 覆盖而非新增（PK 幂等）');
  final orderStore = MemoryBridgeLinkStore();
  await orderStore.insert(BridgeLink(
      selfId: alice, peerId: bob, roomId: room, myCircleId: 'cA', atMs: kNow));
  await orderStore.insert(BridgeLink(
      selfId: alice,
      peerId: dave,
      roomId: room,
      myCircleId: 'cA',
      atMs: kNow + 10));
  check((await orderStore.linksOf(alice)).first.peerId == dave,
      '账本按 atMs 降序（最新在前）');
  check((await orderStore.find(alice, bob))!.peerId == bob, 'find 精确取同对');
  check(await orderStore.find(alice, 'nobody') == null, 'find 未命中 → null');

  print('--- ③i 序列化往返（落库/传输不失真）---');
  const l0 = BridgeLink(
      selfId: alice, peerId: bob, roomId: room, myCircleId: 'cA', atMs: kNow);
  final rt = BridgeLink.fromMap(Map<String, dynamic>.from(l0.toMap()));
  check(
      rt.selfId == l0.selfId &&
          rt.peerId == l0.peerId &&
          rt.roomId == l0.roomId &&
          rt.myCircleId == l0.myCircleId &&
          rt.atMs == l0.atMs,
      'BridgeLink toMap→fromMap 往返一致');
  check(l0.id == '$alice->$bob', '边 ID = self->peer（天然幂等键）');
  final sparse = BridgeLink.fromMap(
      Map<String, dynamic>.from({'self_id': alice, 'peer_id': bob}));
  check(sparse.roomId == '' && sparse.myCircleId == '' && sparse.atMs == 0,
      '缺可选字段 → 默认空串/0（不抛）');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
