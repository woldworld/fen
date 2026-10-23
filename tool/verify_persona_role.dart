// 纯 Dart 校验脚本：M10 P1「人格模式 Persona Modes + 房间角色 Room Roles」。
// 运行：dart run tool/verify_persona_role.dart
//
// 为什么把这两件事写在一个脚本里：
//   PRD §4 M10 把它们放在**同一行表格**里，因为它们是同一个决定的产物 ——
//   "多身份"不靠多账号，而靠**同一身份**在不同场合 / 不同房间的**属性**。
//   两条铁律（人格不改身份 / 角色属于房间）本质是同一条：
//   **权力与语气都挂在"场合"上，不挂在"身份"上**。分开验就会各自退化成口号。
//
// 本脚本盯住四类"编译通过但语义已经错了"的缺陷：
//   ① 人格模式注册表漏项 / 未知值不降级 → LLM 收到空准则；
//   ② 人格文案里混进 Agent ID → 人格层偷偷拿到了身份信息（信任稀释的起点）；
//   ③ 房间角色能被"账号级"地持有 → 到哪个房间都自带权力（M10 明令要防的刷量）；
//   ④ 谁都能授予角色、或把房间最后的主持人撤掉 → 房间变成无人负责的悬空态。
//
// 全部用内存 store 复算；DDL 漂移用**源文本比对**（不需要真 sqlite，
// 与 `verify_attestation_persistence.dart` 同一套办法）。

import 'dart:io';

import 'package:dahuang_ai/core/persona_mode.dart';
import 'package:dahuang_ai/core/room_role.dart';

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

const int kNow = 1800000000000;

/// 剥掉注释再扫源码。
///
/// 为什么必须剥：本项目正文里会**刻意**引用被废弃的旧写法作为"反面教材"
/// （比如"改造前此处调 clearAllSocialLogsAndResetHandshakes()"），
/// 不剥注释就会把这些说明文字当成本文件真的还在调用。
/// 与 `verify_i18n.dart` / `verify_session_crypto.dart` 同一套办法。
String _stripComments(String src) {
  final out = StringBuffer();
  var i = 0;
  final n = src.length;
  while (i < n) {
    final c = src[i];
    if (c == '/' && i + 1 < n && src[i + 1] == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// 从 `db_helper.dart` 源码里抠出某张表的列名（DDL 与序列化字段漂移检查）。
Set<String> _ddlColumns(String src, String table) {
  final m = RegExp('CREATE TABLE IF NOT EXISTS $table\\(([\\s\\S]*?)\\n\\s*\\)')
      .firstMatch(src);
  if (m == null) return <String>{};
  final cols = <String>{};
  for (final raw in m.group(1)!.split('\n')) {
    final line = raw.trim().replaceAll(',', '');
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final head = parts.first.toUpperCase();
    if (head == 'PRIMARY' ||
        head == 'UNIQUE' ||
        head == 'FOREIGN' ||
        head == 'INDEX' ||
        head == 'CONSTRAINT') {
      continue;
    }
    cols.add(parts.first);
  }
  return cols;
}

Future<void> main() async {
  // =========================================================================
  print('--- ① 人格模式注册表：完备 + fail-safe 降级 ---');
  // =========================================================================
  check(PersonaModes.all.length == 5, '注册了 5 个人格模式');
  check(
      PersonaModes.all.map((m) => m.id).toSet().length == PersonaModes.all.length,
      '模式 ID 无重复');
  check(PersonaModes.byIdOrNull(PersonaModes.business)?.id == PersonaModes.business,
      'byIdOrNull 能取到已注册模式');
  check(PersonaModes.defaultMode.id == PersonaModes.casual, '默认模式 = casual');

  // fail-safe：未知 / null / 空串一律降级 casual（绝不抛异常、绝不透传脏值）
  check(PersonaModes.resolve(null).id == PersonaModes.casual, 'resolve(null) → casual');
  check(PersonaModes.resolve('').id == PersonaModes.casual, 'resolve("") → casual');
  check(PersonaModes.resolve('__no_such_mode__').id == PersonaModes.casual,
      '未知模式 → casual（fail-safe，而不是当 custom 透传）');
  check(PersonaModes.resolve('BUSINESS').id == PersonaModes.casual,
      '大小写不匹配 → casual（ID 是精确值，不做模糊匹配）');
  check(PersonaModes.byIdOrNull('__no_such_mode__') == null,
      'byIdOrNull 对未知值返回 null（由调用方显式决定降级策略）');

  // 为什么不能降级到 custom：custom 的准则是"严格执行主人临时战术："+任务，
  // 主人没填任务时 LLM 会收到一条**空准则**。
  check(PersonaModes.resolve('__no_such_mode__').appendsTask == false,
      '降级目标 casual 不依赖主人任务（不会产出空准则）');

  // =========================================================================
  print('--- ② 人格文案与改造前逐字节一致（不偷偷改语气）---');
  // =========================================================================
  const pinned = {
    'casual': '【行为准则】松弛幽默的邻居。自然破冰，随性沟通。',
    'business': '【行为准则】冷酷高效商务代理。不许废话，直击痛点，互换资源。',
    'dating': '【行为准则】高情商赛博僚机。幽默温和，优先找共同话题，绝不查户口。',
    'emergency': '【行为准则】紧急求助！忽略闲聊，立刻求助并承诺回报。',
  };
  for (final e in pinned.entries) {
    check(PersonaModes.directiveFor(e.key) == e.value,
        '${e.key} 准则与改造前硬编码文案一致');
  }
  check(
      PersonaModes.directiveFor(PersonaModes.custom, task: '帮我找铝合金供应商') ==
          '【行为准则】严格执行主人临时战术：\n帮我找铝合金供应商',
      'custom 准则 = 前缀 + 主人临时战术（含换行，与改造前一致）');
  check(PersonaModes.directiveFor(PersonaModes.casual).startsWith('【行为准则】'),
      '准则统一带【行为准则】前缀（prompt 注入点依赖它）');
  check(
      PersonaModes.directiveFor(PersonaModes.business, task: 'A') ==
          PersonaModes.directiveFor(PersonaModes.business, task: 'B'),
      '非 custom 模式的准则不受主人任务影响（任务另有【密令任务】段）');
  check(
      PersonaModes.directiveFor(PersonaModes.custom, task: 'A') !=
          PersonaModes.directiveFor(PersonaModes.custom, task: 'B'),
      'custom 模式的准则随主人任务变化');

  // =========================================================================
  print('--- ③ 铁律 1：人格不改身份（准则里不得出现任何 Agent ID）---');
  // =========================================================================
  const plantedId = 'AG-777-DO-NOT-LEAK';
  var leaked = <String>[];
  for (final m in PersonaModes.all) {
    // 人格**自己撰写**的部分（= 不传任务时的准则）里不得出现任何身份信息。
    // custom 会原样回显"主人任务"，那是主人的输入（性质完全不同），故这里不传任务。
    if (m.directiveFor('').contains(plantedId)) leaked.add(m.id);
  }
  check(leaked.isEmpty,
      '任何人格准则都不含身份信息（否则人格层偷到了身份 → 信任稀释）→ 泄漏 ${leaked}');
  check(!PersonaModes.resolve(PersonaModes.custom).behaviorBody.contains(plantedId),
      'custom 的**人格正文**不含身份信息（回显的只是主人任务，不是人格记住的身份）');
  check(PersonaModes.all.every((m) => m.changesIdentity == false),
      '每个人格都显式声明"不改身份"');
  check(PersonaModes.changesIdentityOnSwitch == false,
      '切换人格不改身份（对外真身 / 密钥一律不动）');

  // =========================================================================
  print('--- ④ 铁律 2：人格不清记忆（改造前会删光聊天记录 + 重置握手）---');
  // =========================================================================
  check(PersonaModes.all.every((m) => m.wipesMemory == false),
      '每个人格都显式声明"不清记忆"');
  check(PersonaModes.wipesMemoryOnSwitch == false,
      '切换人格不清社交记忆、不重置握手（"同一身份"的立身之本）');

  // 源码级取证：改造后 `agent_service.dart` 的人格切换路径不得再调用
  // clearAllSocialLogsAndResetHandshakes（否则又会把对方眼里的你变成陌生人）。
  final agentSrc = _stripComments(File('lib/core/agent_service.dart').readAsStringSync());
  check(!agentSrc.contains('clearAllSocialLogsAndResetHandshakes'),
      'agent_service 已彻底摘掉"切人格即清库"的调用（源码取证，已剥注释）');
  check(agentSrc.contains('PersonaModes.directiveFor'),
      'agent_service 的行为准则已改由 PersonaModes 提供（单一事实源）');
  // 源码级取证：注册表里那 5 段文案不得再散落在别处
  check(!agentSrc.contains('冷酷高效商务代理'),
      '商务准则文案不再硬编码在 agent_service（已收拢进注册表）');

  // =========================================================================
  print('--- ⑤ 计费档（"买专门的模式"）：只是数据模型，不是计费实现 ---');
  // =========================================================================
  check(PersonaModes.resolve(PersonaModes.casual).isFree, 'casual 是基础（免费）模式');
  check(!PersonaModes.resolve(PersonaModes.business).isFree, 'business 是专门（付费）模式');
  check(!PersonaModes.resolve(PersonaModes.dating).isFree, 'dating 是专门（付费）模式');
  check(!PersonaModes.resolve(PersonaModes.emergency).isFree,
      'emergency 是专门（付费）模式');
  check(PersonaModes.paidModes.length == 3, '专门模式共 3 个');
  check(PersonaModes.freeModes.length == 2, '基础模式共 2 个（casual / custom）');
  check(PersonaModes.paidModes.every((m) => m.purchaseKey.trim().isNotEmpty),
      '每个专门模式都有购买键（将来接定价不用回头猜）');
  check(PersonaModes.freeModes.every((m) => m.purchaseKey.isEmpty),
      '基础模式不挂购买键');

  // =========================================================================
  print('--- ⑥ 房间角色：默认值 + fail-safe 解析 ---');
  // =========================================================================
  check(RoomRoleKind.values.length == 5, '房间角色共 5 种');
  check(RoomRoleKind.fromId(null) == RoomRoleKind.participant, 'fromId(null) → 参与者');
  check(RoomRoleKind.fromId('__nope__') == RoomRoleKind.participant,
      'fromId(未知) → 参与者（fail-safe）');
  check(RoomRoleKind.fromId('host') == RoomRoleKind.host, 'fromId("host") → 主持人');
  check(RoomRoleKind.participant.isDefault, '参与者是默认角色（不落库）');
  check(!RoomRoleKind.guest.isDefault && !RoomRoleKind.npc.isDefault,
      '嘉宾 / NPC 都不是默认角色');
  check(RoomRoleKind.host.isHostLayer && RoomRoleKind.cohost.isHostLayer,
      '主持层 = 主持人 + 联合主持');
  check(!RoomRoleKind.guest.canModerate && !RoomRoleKind.npc.canModerate,
      '嘉宾 / NPC 没有管理权（角色 ≠ 权力，只有主持层有）');
  check(RoomRoleKind.host.canModerate && !RoomRoleKind.participant.canModerate,
      'canModerate 只对主持层为真');

  // =========================================================================
  print('--- ⑦ 铁律 1：角色永远属于房间（不存在"全局角色"）---');
  // =========================================================================
  final svc = RoomRoleService(store: MemoryRoomRoleStore());
  const roomA = 'lisbon-night';
  const roomB = 'tokyo-dawn';
  const alice = 'alice';
  const bob = 'bob';

  check(await svc.roleIn(roomA, alice) == RoomRoleKind.participant,
      '没被授予过的人在本房间 = 参与者（默认角色）');

  final claimA = await svc.claimHost(roomId: roomA, agentId: alice, atMs: kNow);
  check(claimA.ok && claimA.changed, '空房间第一个认领者成为主持人');
  check(await svc.roleIn(roomA, alice) == RoomRoleKind.host, 'alice 在 roomA 是主持人');

  // ★ 同一个人，换个房间就什么都不是 —— 这就是"防刷"的可证形式
  check(await svc.roleIn(roomB, alice) == RoomRoleKind.participant,
      'alice 在 roomB 仍是普通参与者（角色属于房间，不跟人走）');
  check(await svc.globalRole(alice) == RoomRoleKind.participant,
      '★ 铁律：无论当了多少房间的主持人，"脱离房间"时都恒为参与者（无账号级特权）');

  // 再当两个房间的主持人，globalRole 依然不变
  await svc.claimHost(roomId: roomB, agentId: alice, atMs: kNow);
  await svc.claimHost(roomId: 'berlin-noon', agentId: alice, atMs: kNow);
  check((await svc.roleIn(roomA, alice)) == RoomRoleKind.host &&
      (await svc.roleIn(roomB, alice)) == RoomRoleKind.host,
      'alice 在多个房间都是主持人（同一身份，多场合）');
  check(await svc.globalRole(alice) == RoomRoleKind.participant,
      '★ 三房主持人之后，"全局角色"仍是参与者（权力没有被累加成账号属性）');
  check((await svc.rolesOf(alice)).length == 3,
      '按人查：alice 在 3 个房间有非默认角色（rolesOf）');
  check((await svc.rolesOf(alice)).every((g) => g.roomId.trim().isNotEmpty),
      '★ 每一条角色记录都带房间出处（没有房间的角色无处安放）');

  // 房间名册只含本房间
  check((await svc.rolesIn(roomA)).keys.toSet().contains(alice), 'roomA 名册含 alice');
  check(!(await svc.rolesIn(roomA)).keys.toSet().contains(bob),
      'roomA 名册不含没被授予过的 bob');

  // =========================================================================
  print('--- ⑧ 认领主持人：fail-closed（防二次占位）---');
  // =========================================================================
  final reclaim = await svc.claimHost(roomId: roomA, agentId: bob, atMs: kNow);
  check(!reclaim.ok && reclaim.reason == RoomRoleBlockCode.hostExists,
      '房间已有主持人 → 再认领被拒（host_exists）');
  check((await svc.roleIn(roomA, bob)) == RoomRoleKind.participant,
      '被拒之后 bob 仍是参与者（没有偷偷写成主持人）');

  final claimNoRoom =
      await svc.claimHost(roomId: '', agentId: bob, atMs: kNow);
  check(!claimNoRoom.ok && claimNoRoom.reason == RoomRoleBlockCode.noRoom,
      '缺房间出处 → no_room');
  final claimNoAgent =
      await svc.claimHost(roomId: 'ghost-room', agentId: '', atMs: kNow);
  check(!claimNoAgent.ok && claimNoAgent.reason == RoomRoleBlockCode.noAgent,
      '缺认领人 → no_agent');

  // =========================================================================
  print('--- ⑨ 授予角色：Host 层权益，fail-closed ---');
  // =========================================================================
  // bob（参与者）想给 alice 派角色 → 拒
  final bobGrant = await svc.grant(
      roomId: roomA,
      agentId: alice,
      role: RoomRoleKind.host,
      granterId: bob,
      atMs: kNow);
  check(!bobGrant.ok && bobGrant.reason == RoomRoleBlockCode.notHost,
      '非主持层授予被拒（not_host）');
  check((await svc.roleIn(roomA, alice)) == RoomRoleKind.host,
      '被拒后目标角色未变（fail-closed：先校验后写入）');

  // alice（主持人）把 bob 设为嘉宾 → 通过
  final setGuest = await svc.grant(
      roomId: roomA,
      agentId: bob,
      role: RoomRoleKind.guest,
      granterId: alice,
      atMs: kNow);
  check(setGuest.ok && setGuest.changed, '主持人把 bob 设为嘉宾 → 成功');
  check(await svc.roleIn(roomA, bob) == RoomRoleKind.guest, 'bob 在 roomA 是嘉宾');

  // 幂等：再设一次同样的角色 → ok 但未改动
  final again = await svc.grant(
      roomId: roomA,
      agentId: bob,
      role: RoomRoleKind.guest,
      granterId: alice,
      atMs: kNow + 1);
  check(again.ok && !again.changed, '重复授予同一角色 → 幂等（ok 但不写库）');

  // bob（现在有管理权吗？嘉宾没有）→ 依旧不能授予
  final guestGrant = await svc.grant(
      roomId: roomA,
      agentId: 'carol',
      role: RoomRoleKind.npc,
      granterId: bob,
      atMs: kNow + 2);
  check(!guestGrant.ok && guestGrant.reason == RoomRoleBlockCode.notHost,
      '嘉宾虽有角色但**无管理权**，授予仍被拒（not_host）');

  // 授予缺房间 / 缺目标
  final noRoomGrant = await svc.grant(
      roomId: '',
      agentId: bob,
      role: RoomRoleKind.guest,
      granterId: alice,
      atMs: kNow);
  check(!noRoomGrant.ok && noRoomGrant.reason == RoomRoleBlockCode.noRoom,
      '授予缺房间出处 → no_room');
  final noAgentGrant = await svc.grant(
      roomId: roomA,
      agentId: '',
      role: RoomRoleKind.guest,
      granterId: alice,
      atMs: kNow);
  check(!noAgentGrant.ok && noAgentGrant.reason == RoomRoleBlockCode.noAgent,
      '授予缺目标 → no_agent');

  // =========================================================================
  print('--- ⑩ 主持层权威性：不能撤掉房间最后一个主持人 ---');
  // =========================================================================
  final revokeLast = await svc.revoke(
      roomId: roomA, agentId: alice, granterId: alice, atMs: kNow + 3);
  check(!revokeLast.ok && revokeLast.reason == RoomRoleBlockCode.lastHost,
      '撤销房间里唯一的主持人 → 被拒（last_host，房间不会失去主持）');
  check(await svc.roleIn(roomA, alice) == RoomRoleKind.host, 'alice 仍是主持人');

  // 先加一个联合主持，再撤销 alice 就允许了（房间仍有主持层）
  final setCohost = await svc.grant(
      roomId: roomA,
      agentId: 'dave',
      role: RoomRoleKind.cohost,
      granterId: alice,
      atMs: kNow + 4);
  check(setCohost.ok && setCohost.changed, '主持人可任命联合主持');
  check(await svc.hasHost(roomA), 'roomA 有主持层');
  final revokeNow = await svc.revoke(
      roomId: roomA, agentId: alice, granterId: 'dave', atMs: kNow + 5);
  check(revokeNow.ok && revokeNow.changed, '房里有第二个主持层成员时，撤销被允许');
  check(await svc.roleIn(roomA, alice) == RoomRoleKind.participant,
      'alice 被降级为参与者（撤销 = 授予 participant）');
  check(await svc.hasHost(roomA), '房间仍有主持层（dave 接管，没有悬空）');

  // =========================================================================
  print('--- ⑪ 留痕：每一次判定都进事件流（含被拒）---');
  // =========================================================================
  final events = <Map<String, Object?>>[];
  final svc2 = RoomRoleService(
    store: MemoryRoomRoleStore(),
    onEvent: (n, p) => events.add({'name': n, ...p}),
  );
  await svc2.claimHost(roomId: 'r1', agentId: 'x', atMs: kNow);
  await svc2.claimHost(roomId: 'r1', agentId: 'y', atMs: kNow); // 拒
  await svc2.grant(
      roomId: 'r1',
      agentId: 'z',
      role: RoomRoleKind.guest,
      granterId: 'y',
      atMs: kNow); // 拒（y 不是主持）
  await svc2.grant(
      roomId: 'r1',
      agentId: 'z',
      role: RoomRoleKind.guest,
      granterId: 'x',
      atMs: kNow); // 成
  check(events.any((e) => e['name'] == 'room_role_claimed_host'),
      '认领主持人留痕 room_role_claimed_host');
  check(
      events.any((e) =>
          e['name'] == 'room_role_blocked' &&
          e['reason'] == RoomRoleBlockCode.hostExists),
      '认领被拒留痕（否则"没有二次占位"没有证据）');
  check(
      events.any((e) =>
          e['name'] == 'room_role_blocked' &&
          e['reason'] == RoomRoleBlockCode.notHost),
      '越权授予留痕 room_role_blocked/not_host');
  check(
      events.any((e) =>
          e['name'] == 'room_role_granted' &&
          e['role'] == RoomRoleKind.guest.id &&
          e['granter'] == 'x'),
      '授予成功留痕 room_role_granted（含授予人）');

  // =========================================================================
  print('--- ⑫ 序列化往返 + DDL 漂移 ---');
  // =========================================================================
  const g = RoomRoleGrant(
    roomId: roomA,
    agentId: bob,
    role: RoomRoleKind.npc,
    grantedBy: alice,
    atMs: kNow,
  );
  final back = RoomRoleGrant.fromMap(Map<String, dynamic>.from(g.toMap()));
  check(back.roomId == g.roomId && back.agentId == g.agentId, 'roomId/agentId 往返一致');
  check(back.role == g.role, 'role 往返一致');
  check(back.grantedBy == g.grantedBy && back.atMs == g.atMs, '授予人/时刻往返一致');
  check(back.role.id == RoomRoleKind.npc.id, '落库值是稳定字符串（npc）');
  check(g.key == '$roomA::$bob', '复合主键 key = room::agent');

  final dbSrc = File('lib/core/db_helper.dart').readAsStringSync();
  final cols = _ddlColumns(dbSrc, 'room_roles');
  final fields = g.toMap().keys.toSet();
  check(cols.isNotEmpty, '（前提）解析到 room_roles 表结构');
  check(fields.difference(cols).isEmpty,
      '序列化字段全都有对应列（缺列会在真机报 no such column）→ 缺 ${fields.difference(cols)}');
  check(cols.difference(fields).isEmpty,
      '没有多余的死列 → 多 ${cols.difference(fields)}');
  check(cols.length == fields.length, 'room_roles 列数 = 字段数 = ${fields.length}');

  final verM = RegExp(r'schemaVersion\s*=\s*(\d+)').firstMatch(dbSrc);
  final migKeys = RegExp(r'^\s*(\d+): _migrateV\d+,', multiLine: true)
      .allMatches(dbSrc)
      .map((m) => int.parse(m.group(1)!))
      .toList()
    ..sort();
  check(verM != null && migKeys.isNotEmpty, '（前提）解析到 schemaVersion / 迁移表');
  final declared = int.parse(verM!.group(1)!);
  check(declared == migKeys.last, 'schemaVersion($declared) == 迁移表最大键(${migKeys.last})');
  check(migKeys.contains(27), 'V27 已注册进迁移表');
  check(dbSrc.contains('CREATE INDEX IF NOT EXISTS idx_room_roles_room') &&
      dbSrc.contains('CREATE INDEX IF NOT EXISTS idx_room_roles_agent'),
      'room_roles 两个查询方向的索引都已建（按房间列名册 / 按人查身份）');
  // ★ 铁律的物理形式：这张表**不允许**有任何"全局角色"列
  check(!cols.contains('scope') && !cols.contains('global') && !cols.contains('is_global'),
      'room_roles 没有 scope/global 列（账号级特权在表结构上就无处安放）');

  // =========================================================================
  print('--- ⑬ 运行时装配（WoldRuntime 必须把服务接出来，否则 UI 拿不到）---');
  // =========================================================================
  final rtSrc = File('lib/core/wold_runtime.dart').readAsStringSync();
  check(rtSrc.contains('RoomRoleService'), 'WoldRuntime 装配了 RoomRoleService');
  check(rtSrc.contains('DbRoomRoleStore'), 'WoldRuntime 装配了 DbRoomRoleStore');
  check(rtSrc.contains("import 'room_role.dart';"), 'WoldRuntime 引入 room_role');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
