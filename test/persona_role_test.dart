import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/persona_mode.dart';
import 'package:dahuang_ai/core/room_role.dart';

/// M10 P1：人格模式 + 房间角色的单元测试。
///
/// 与 `tool/verify_persona_role.dart` 的分工：
///   - 离线脚本是**交付验收口径**（95 条断言，纯 `dart run`，零平台依赖）；
///   - 这里把其中**最容易被后续改动打破的语义**固化成回归测试，
///     并额外覆盖 DB 无关的序列化往返。
/// 两者都在，是刻意的重复：一个保证"离线可复算"，一个保证"CI/本地改坏了会红"。
void main() {
  group('人格模式：注册表与 fail-safe 降级', () {
    test('5 个模式、ID 无重复、默认 casual', () {
      expect(PersonaModes.all.length, 5);
      expect(PersonaModes.all.map((m) => m.id).toSet().length, 5);
      expect(PersonaModes.defaultMode.id, PersonaModes.casual);
    });

    test('未知 / null / 空串 一律降级 casual（不抛异常）', () {
      for (final bad in <String?>[null, '', '__nope__', 'BUSINESS', 'business ']) {
        expect(PersonaModes.resolve(bad).id, PersonaModes.casual,
            reason: 'resolve(${bad == null ? 'null' : '"$bad"'}) 应降级 casual');
      }
      expect(PersonaModes.byIdOrNull('__nope__'), isNull);
    });

    test('准则文案与改造前逐字节一致（收拢不改语气）', () {
      expect(PersonaModes.directiveFor('casual'), '【行为准则】松弛幽默的邻居。自然破冰，随性沟通。');
      expect(PersonaModes.directiveFor('business'),
          '【行为准则】冷酷高效商务代理。不许废话，直击痛点，互换资源。');
      expect(PersonaModes.directiveFor('dating'),
          '【行为准则】高情商赛博僚机。幽默温和，优先找共同话题，绝不查户口。');
      expect(PersonaModes.directiveFor('emergency'),
          '【行为准则】紧急求助！忽略闲聊，立刻求助并承诺回报。');
      expect(PersonaModes.directiveFor('custom', task: '找供应商'),
          '【行为准则】严格执行主人临时战术：\n找供应商');
    });

    test('★ 铁律 1：人格准则里不含身份信息（人格层不持有身份）', () {
      const id = 'AG-777-SECRET';
      for (final m in PersonaModes.all) {
        expect(m.directiveFor('').contains(id), isFalse,
            reason: '${m.id} 的准则泄漏了身份信息');
        expect(m.changesIdentity, isFalse, reason: '${m.id} 必须声明不改身份');
      }
      expect(PersonaModes.changesIdentityOnSwitch, isFalse);
    });

    test('★ 铁律 2：切换人格不清记忆、不重置握手', () {
      for (final m in PersonaModes.all) {
        expect(m.wipesMemory, isFalse, reason: '${m.id} 必须声明不清记忆');
      }
      expect(PersonaModes.wipesMemoryOnSwitch, isFalse);
    });

    test('计费档：casual/custom 免费，business/dating/emergency 为专门模式', () {
      expect(PersonaModes.freeModes.map((m) => m.id).toSet(),
          {PersonaModes.casual, PersonaModes.custom});
      expect(PersonaModes.paidModes.map((m) => m.id).toSet(),
          {PersonaModes.business, PersonaModes.dating, PersonaModes.emergency});
      expect(PersonaModes.paidModes.every((m) => m.purchaseKey.isNotEmpty), isTrue);
      expect(PersonaModes.freeModes.every((m) => m.purchaseKey.isEmpty), isTrue);
    });
  });

  group('房间角色：铁律与 fail-closed', () {
    late RoomRoleService svc;
    late List<Map<String, Object?>> events;

    setUp(() {
      events = [];
      svc = RoomRoleService(
        store: MemoryRoomRoleStore(),
        onEvent: (n, p) => events.add({'name': n, ...p}),
      );
    });

    test('默认角色 = participant；未知落库值 fail-safe 降级', () {
      expect(RoomRoleKind.fromId(null), RoomRoleKind.participant);
      expect(RoomRoleKind.fromId('__nope__'), RoomRoleKind.participant);
      expect(RoomRoleKind.participant.isDefault, isTrue);
      expect(RoomRoleKind.host.isHostLayer, isTrue);
      expect(RoomRoleKind.cohost.isHostLayer, isTrue);
      expect(RoomRoleKind.guest.canModerate, isFalse);
      expect(RoomRoleKind.npc.canModerate, isFalse);
    });

    test('★ 铁律 1：角色属于房间，不存在账号级特权', () async {
      await svc.claimHost(roomId: 'rA', agentId: 'alice', atMs: 1);
      await svc.claimHost(roomId: 'rB', agentId: 'alice', atMs: 2);

      expect(await svc.roleIn('rA', 'alice'), RoomRoleKind.host);
      expect(await svc.roleIn('rB', 'alice'), RoomRoleKind.host);
      // 换个房间 → 什么都不是
      expect(await svc.roleIn('rC', 'alice'), RoomRoleKind.participant);
      // 脱离房间 → 恒为参与者
      expect(await svc.globalRole('alice'), RoomRoleKind.participant);
      // 每条记录都带房间出处
      expect((await svc.rolesOf('alice')).every((g) => g.roomId.isNotEmpty), isTrue);
    });

    test('认领主持人：空房间可认领，已有主持人则拒', () async {
      final first = await svc.claimHost(roomId: 'rA', agentId: 'alice', atMs: 1);
      expect(first.ok, isTrue);
      expect(first.changed, isTrue);

      final second = await svc.claimHost(roomId: 'rA', agentId: 'bob', atMs: 2);
      expect(second.ok, isFalse);
      expect(second.reason, RoomRoleBlockCode.hostExists);
      expect(await svc.roleIn('rA', 'bob'), RoomRoleKind.participant);
    });

    test('授予：只有主持层可授予（非主持层 → not_host）', () async {
      await svc.claimHost(roomId: 'rA', agentId: 'alice', atMs: 1);

      final denied = await svc.grant(
          roomId: 'rA',
          agentId: 'carol',
          role: RoomRoleKind.guest,
          granterId: 'bob',
          atMs: 2);
      expect(denied.ok, isFalse);
      expect(denied.reason, RoomRoleBlockCode.notHost);
      expect(await svc.roleIn('rA', 'carol'), RoomRoleKind.participant);

      final allowed = await svc.grant(
          roomId: 'rA',
          agentId: 'carol',
          role: RoomRoleKind.guest,
          granterId: 'alice',
          atMs: 3);
      expect(allowed.ok, isTrue);
      expect(allowed.changed, isTrue);
      expect(await svc.roleIn('rA', 'carol'), RoomRoleKind.guest);
    });

    test('缺房间出处 / 缺目标 → no_room / no_agent', () async {
      await svc.claimHost(roomId: 'rA', agentId: 'alice', atMs: 1);
      final noRoom = await svc.grant(
          roomId: '',
          agentId: 'bob',
          role: RoomRoleKind.guest,
          granterId: 'alice',
          atMs: 2);
      expect(noRoom.reason, RoomRoleBlockCode.noRoom);
      final noAgent = await svc.grant(
          roomId: 'rA',
          agentId: '',
          role: RoomRoleKind.guest,
          granterId: 'alice',
          atMs: 3);
      expect(noAgent.reason, RoomRoleBlockCode.noAgent);
    });

    test('不能撤掉房间里最后一个主持层（last_host）', () async {
      await svc.claimHost(roomId: 'rA', agentId: 'alice', atMs: 1);
      final blocked =
          await svc.revoke(roomId: 'rA', agentId: 'alice', granterId: 'alice', atMs: 2);
      expect(blocked.ok, isFalse);
      expect(blocked.reason, RoomRoleBlockCode.lastHost);
      expect(await svc.roleIn('rA', 'alice'), RoomRoleKind.host);

      // 有第二个主持层成员后即可撤销
      await svc.grant(
          roomId: 'rA',
          agentId: 'dave',
          role: RoomRoleKind.cohost,
          granterId: 'alice',
          atMs: 3);
      final ok =
          await svc.revoke(roomId: 'rA', agentId: 'alice', granterId: 'dave', atMs: 4);
      expect(ok.ok, isTrue);
      expect(ok.changed, isTrue);
      expect(await svc.roleIn('rA', 'alice'), RoomRoleKind.participant);
      expect(await svc.hasHost('rA'), isTrue, reason: 'dave 接管，房间未悬空');
    });

    test('幂等：重复授予同一角色 → ok 但未改动', () async {
      await svc.claimHost(roomId: 'rA', agentId: 'alice', atMs: 1);
      await svc.grant(
          roomId: 'rA',
          agentId: 'bob',
          role: RoomRoleKind.guest,
          granterId: 'alice',
          atMs: 2);
      final again = await svc.grant(
          roomId: 'rA',
          agentId: 'bob',
          role: RoomRoleKind.guest,
          granterId: 'alice',
          atMs: 3);
      expect(again.ok, isTrue);
      expect(again.changed, isFalse);
    });

    test('每一次判定都留痕（含被拒）', () async {
      await svc.claimHost(roomId: 'rA', agentId: 'alice', atMs: 1);
      await svc.claimHost(roomId: 'rA', agentId: 'bob', atMs: 2); // 拒
      expect(events.any((e) => e['name'] == 'room_role_claimed_host'), isTrue);
      expect(
          events.any((e) =>
              e['name'] == 'room_role_blocked' &&
              e['reason'] == RoomRoleBlockCode.hostExists),
          isTrue);
    });

    test('序列化往返 + 复合主键字符串', () {
      const g = RoomRoleGrant(
        roomId: 'rA',
        agentId: 'bob',
        role: RoomRoleKind.npc,
        grantedBy: 'alice',
        atMs: 42,
      );
      final back = RoomRoleGrant.fromMap(Map<String, dynamic>.from(g.toMap()));
      expect(back.roomId, g.roomId);
      expect(back.agentId, g.agentId);
      expect(back.role, g.role);
      expect(back.grantedBy, g.grantedBy);
      expect(back.atMs, g.atMs);
      expect(g.key, 'rA::bob');
    });
  });
}
