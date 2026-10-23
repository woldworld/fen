// 纯 Dart 校验脚本：M10 P1 房间角色「Host 层权益」的**可验证性**。
// 运行：dart run tool/verify_room_role_host.dart
//
// 为什么值得单独一个脚本：
//   PRD §10.3 里 M10 P1 的缺口是**一句诚实的话** ——
//   "服务端尚未参与，因此'对面是不是真的主持人'无法被第三方验证"。
//   本脚本盯的就是这句话**是否被兑现**，而且盯的方式不是"我们声明做到了"：
//
//   ① **结构断言**：`RoomRoleGrant` 的签名载荷里没有 `scope`/`global` 字段，
//      且房间为空时**先于验签**就被拒 —— 于是"账号级角色"在字节层没有形式；
//   ② **跨语言同序断言**：直接读 `packages/protocol/src/roomRole.js` 的 `canonical`
//      键序，与 Dart `canonical()` 生成的 JSON 键序**逐项比对**。键序漂移的病症是
//      "Dart 签得对、Hub 一律拒"，而本断言**不需要起 Node**就能抓住它；
//   ③ **拒绝路径**：验签的每一条 fail-closed 分支都有负例（自证签名无效、改字段失效）；
//   ④ **权威判定可复算**：把同一份"此前授予"列表喂给判定，任何观察者得同一结论。
//
// 本脚本只 import 纯 Dart 模块（无 Flutter / sqflite），故可离线复算。

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'package:dahuang_ai/core/agent_protocol.dart';
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

/// 生成一把 Ed25519 密钥，返回 (base58 公钥, 签名函数)。
Future<({String pub, Future<String> Function(List<int>) sign})> _newKey() async {
  final kp = await Ed25519().newKeyPair();
  final pubBytes = await kp.extractPublicKey();
  final pub = AgentProtocol.base58Encode(pubBytes.bytes);
  return (
    pub: pub,
    sign: (List<int> msg) async {
      final s = await Ed25519().sign(msg, keyPair: kp);
      return base64Encode(s.bytes);
    },
  );
}

RoomRoleGrant _grant({
  required String roomId,
  required String agentId,
  required String agentPub,
  required RoomRoleKind role,
  required String grantedBy,
  required String granterPub,
  int atMs = kNow,
}) =>
    RoomRoleGrant(
      roomId: roomId,
      agentId: agentId,
      role: role,
      grantedBy: grantedBy,
      atMs: atMs,
      agentPub: agentPub,
      granterPub: granterPub,
    );

/// 从 JS 源码里抠出 `roomRole.canonical()` 的键序。
///
/// 这是本脚本里**最值钱**的一段：它把"两端必须同序"从"我们希望如此"
/// 变成了一条可执行断言，而且不依赖 Node（`run_all_verify.dart` 也会跑到它）。
List<String> _jsCanonicalKeys(String src) {
  final start = src.indexOf('function canonical(g) {');
  if (start < 0) return const [];
  final end = src.indexOf('}', start);
  // 守卫：段找得到才算数。宁可返回空清单 → 触发下面的 `jsKeys.isNotEmpty` FAIL，
  // 也**绝不** substring(-1) 直接抛 RangeError —— 崩掉的脚本看起来像"环境问题"，
  // 而 FAIL 才是指向真正病灶的信号（同 2026-09-27 抽取迁移踩过的坑）。
  if (end <= start) return const [];
  final body = src.substring(start, end);
  final keys = <String>[];
  for (final line in body.split('\n')) {
    final m = RegExp(r'^\s*([a-z_]+)\s*:').firstMatch(line);
    if (m != null) keys.add(m.group(1)!);
  }
  return keys;
}

Future<void> main() async {
  final alice = await _newKey(); // 主持人
  final bob = await _newKey(); // 被授予者
  final carol = await _newKey(); // 旁观者 / 冒名者

  // =========================================================================
  print('--- ① 签名载荷：键序与协议包逐项同构（跨语言漂移的探针） ---');
  final jsSrc = File('packages/protocol/src/roomRole.js').readAsStringSync();
  final jsKeys = _jsCanonicalKeys(jsSrc);
  final dartKeys = (jsonDecode(_grant(
            roomId: 'r1',
            agentId: 'alice',
            agentPub: alice.pub,
            role: RoomRoleKind.host,
            grantedBy: 'alice',
            granterPub: alice.pub,
          ).canonical()) as Map<String, dynamic>)
      .keys
      .toList();

  check(jsKeys.isNotEmpty, '能在 roomRole.js 里找到 canonical 键序（段找得到）');
  check(
    jsKeys.length == dartKeys.length &&
        List.generate(jsKeys.length, (i) => jsKeys[i] == dartKeys[i]).every((x) => x),
    '★ Dart 与 JS 的 canonical 键序**逐项相同**（${jsKeys.join(',')}）',
  );
  check(
    dartKeys.contains('room_id') &&
        dartKeys.contains('agent_pub') &&
        dartKeys.contains('granter_pub'),
    '载荷里绑定房间、被授权人公钥、授予人公钥',
  );

  // =========================================================================
  print('--- ② 铁律 1 的可验证形式：没有房间的角色不合法（先于验签） ---');
  final roomless = _grant(
    roomId: '',
    agentId: 'alice',
    agentPub: alice.pub,
    role: RoomRoleKind.host,
    grantedBy: 'alice',
    granterPub: alice.pub,
  ).copyWith(sig: await alice.sign(
    _grant(
      roomId: '',
      agentId: 'alice',
      agentPub: alice.pub,
      role: RoomRoleKind.host,
      grantedBy: 'alice',
      granterPub: alice.pub,
    ).canonicalBytes(),
  ));
  var v = await RoomRoleAuthority.verify(roomless);
  check(v.code == RoomRoleVerifyCode.noRoom, '空房间的角色 → no_room（即使签名有效也被拒）');
  check(roomless.isSigned, '...而它确实带齐了签名（所以拦它的是房间校验，不是"没签名"）');

  check(
    !dartKeys.contains('scope') &&
        !dartKeys.contains('global') &&
        !dartKeys.contains('owner'),
    '★ 载荷里**没有** scope/global/owner —— 账号级权力无处表达',
  );

  // =========================================================================
  print('--- ③ 验签 fail-closed 的每一条拒绝路径 ---');
  final good = _grant(
    roomId: 'room-alpha',
    agentId: 'alice',
    agentPub: alice.pub,
    role: RoomRoleKind.host,
    grantedBy: 'alice',
    granterPub: alice.pub,
  ).copyWith(sig: await alice.sign(
    _grant(
      roomId: 'room-alpha',
      agentId: 'alice',
      agentPub: alice.pub,
      role: RoomRoleKind.host,
      grantedBy: 'alice',
      granterPub: alice.pub,
    ).canonicalBytes(),
  ));
  v = await RoomRoleAuthority.verify(good);
  check(v.ok && v.code == RoomRoleVerifyCode.ok, '合法的自封主持人 → ok');

  v = await RoomRoleAuthority.verify(good.copyWith(sig: ''));
  check(v.code == RoomRoleVerifyCode.missingFields, '缺签名 → missing_fields');

  // 未签名（公钥为空）不得被当成"可验证"——不许把不可验证伪装成可验证。
  final unsigned = _grant(
    roomId: 'room-alpha',
    agentId: 'alice',
    agentPub: '',
    role: RoomRoleKind.host,
    grantedBy: 'alice',
    granterPub: '',
  ).copyWith(sig: 'AAAA');
  v = await RoomRoleAuthority.verify(unsigned);
  check(v.code == RoomRoleVerifyCode.badPubkey, '未签名（空公钥）→ bad_pubkey');

  v = await RoomRoleAuthority.verify(good.copyWith(role: RoomRoleKind.cohost));
  check(v.code == RoomRoleVerifyCode.badSignature, '签完再把自己的角色升级 → bad_signature');

  v = await RoomRoleAuthority.verify(good.copyWith(atMs: kNow + 1));
  check(v.code == RoomRoleVerifyCode.badSignature, '签完再改时间 → bad_signature');

  // 换被授权人：agentId 变了 → 载荷变 → 验签失败
  final swapped = RoomRoleGrant(
    roomId: good.roomId,
    agentId: 'bob',
    role: good.role,
    grantedBy: good.grantedBy,
    atMs: good.atMs,
    agentPub: good.agentPub,
    granterPub: good.granterPub,
    sig: good.sig,
  );
  v = await RoomRoleAuthority.verify(swapped);
  check(v.code == RoomRoleVerifyCode.badSignature, '把授予改到别人头上 → bad_signature');

  // 拿别人的私钥签（冒名）
  final forged = _grant(
    roomId: 'room-alpha',
    agentId: 'alice',
    agentPub: alice.pub,
    role: RoomRoleKind.host,
    grantedBy: 'alice',
    granterPub: alice.pub,
  ).copyWith(sig: await carol.sign(
    _grant(
      roomId: 'room-alpha',
      agentId: 'alice',
      agentPub: alice.pub,
      role: RoomRoleKind.host,
      grantedBy: 'alice',
      granterPub: alice.pub,
    ).canonicalBytes(),
  ));
  v = await RoomRoleAuthority.verify(forged);
  check(v.code == RoomRoleVerifyCode.badSignature, '拿第三方的私钥冒名签 → bad_signature');

  v = await RoomRoleAuthority.verify(good.copyWith(atMs: 0));
  check(v.code == RoomRoleVerifyCode.badWindow, '时间为 0 → bad_window');

  final longRoom = RoomRoleGrant(
    roomId: 'x' * (RoomRoleAuthority.maxRoomIdChars + 1),
    agentId: 'alice',
    role: RoomRoleKind.host,
    grantedBy: 'alice',
    atMs: kNow,
    agentPub: alice.pub,
    granterPub: alice.pub,
    sig: 'AAAA',
  );
  v = await RoomRoleAuthority.verify(longRoom);
  check(v.code == RoomRoleVerifyCode.badRoom, '房间 id 过长 → bad_room');

  final longAgent = RoomRoleGrant(
    roomId: 'room-alpha',
    agentId: 'y' * (RoomRoleAuthority.maxAgentIdChars + 1),
    role: RoomRoleKind.host,
    grantedBy: 'alice',
    atMs: kNow,
    agentPub: alice.pub,
    granterPub: alice.pub,
    sig: 'AAAA',
  );
  v = await RoomRoleAuthority.verify(longAgent);
  check(v.code == RoomRoleVerifyCode.badAgent, '被授权人 id 过长 → bad_agent');

  // 所有合法角色都必须验得过（bad_role 在 Dart 侧不可达，因为 role 是枚举）。
  var allRolesOk = true;
  for (final r in RoomRoleKind.values) {
    final g = _grant(
      roomId: 'room-alpha',
      agentId: 'alice',
      agentPub: alice.pub,
      role: r,
      grantedBy: 'alice',
      granterPub: alice.pub,
    );
    final signed = g.copyWith(sig: await alice.sign(g.canonicalBytes()));
    if (!(await RoomRoleAuthority.verify(signed)).ok) allRolesOk = false;
  }
  check(allRolesOk, '${RoomRoleKind.values.length} 个合法角色全部验得过（无"合法却被拒"）');

  // =========================================================================
  print('--- ④ §16 公开叶子：只含公钥，不含人名 ---');
  final leaf = jsonDecode(utf8.decode(good.logBytes())) as Map<String, dynamic>;
  check(
    !leaf.containsKey('agent_id') && !leaf.containsKey('granted_by'),
    '★ 公开叶子里**不含** agent_id / granted_by（人取的名字不进公开日志）',
  );
  check(
    leaf.containsKey('agent_pub') &&
        leaf.containsKey('granter_pub') &&
        leaf.containsKey('room_id') &&
        leaf.containsKey('role'),
    '叶子只陈述关于公钥的断言（谁、什么角色、哪个房间、由谁授予）',
  );
  // 换掉人名（其余全同）→ 叶子**不变**，但签名载荷**变**。
  // 这正是"公开日志只关于公钥"的可执行证明。
  final renamed = RoomRoleGrant(
    roomId: good.roomId,
    agentId: 'another-handle',
    role: good.role,
    grantedBy: 'yet-another-handle',
    atMs: good.atMs,
    agentPub: good.agentPub,
    granterPub: good.granterPub,
    sig: good.sig,
  );
  check(
    utf8.decode(renamed.logBytes()) == utf8.decode(good.logBytes()),
    '★ 换掉 agent_id / granted_by 后叶子字节不变（人名不进公开日志）',
  );
  check(
    renamed.canonical() != good.canonical(),
    '...但签名载荷变了（所以人名仍被签名绑定，改了必然验签失败）',
  );

  // =========================================================================
  print('--- ⑤ 幂等键：一个 (房间, 人) 只有一个角色 ---');
  check(
    RoomRoleAuthority.keyOf('room-alpha', 'alice') ==
        RoomRoleAuthority.keyOf('room-alpha', 'alice'),
    '同一 (房间, 人) 的键稳定',
  );
  check(
    RoomRoleAuthority.keyOf('room-alpha', 'alice') !=
        RoomRoleAuthority.keyOf('room-beta', 'alice'),
    '同一个人换个房间就是另一个键（角色不跟着账号走）',
  );

  // =========================================================================
  print('--- ⑥ 权威判定：第三方复算，铁律 2 ---');
  final hostGrant = good;
  final cohostGrant = await (() async {
    final g = _grant(
      roomId: 'room-alpha',
      agentId: 'bob',
      agentPub: bob.pub,
      role: RoomRoleKind.cohost,
      grantedBy: 'alice',
      granterPub: alice.pub,
      atMs: kNow + 1000,
    );
    return g.copyWith(sig: await alice.sign(g.canonicalBytes()));
  })();

  var d = RoomRoleAuthority.grantDecision(hostGrant, const []);
  check(d.accept && d.code == RoomRoleAuthorityCode.claimed,
      '空房间自封主持人 → claimed（合法，且只能是自己）');

  final claimForOther = await (() async {
    final g = _grant(
      roomId: 'room-alpha',
      agentId: 'bob',
      agentPub: bob.pub,
      role: RoomRoleKind.host,
      grantedBy: 'bob',
      granterPub: bob.pub,
    );
    return g.copyWith(sig: await bob.sign(g.canonicalBytes()));
  })();
  d = RoomRoleAuthority.grantDecision(claimForOther, [hostGrant]);
  check(!d.accept && d.code == RoomRoleAuthorityCode.hostExists,
      '房间已有主持人时再自封 → host_exists（防二次占位夺权）');

  final participantGrant = await (() async {
    final g = _grant(
      roomId: 'room-alpha',
      agentId: 'bob',
      agentPub: bob.pub,
      role: RoomRoleKind.npc,
      grantedBy: 'carol',
      granterPub: carol.pub,
    );
    return g.copyWith(sig: await carol.sign(g.canonicalBytes()));
  })();
  d = RoomRoleAuthority.grantDecision(participantGrant, [hostGrant]);
  check(!d.accept && d.code == RoomRoleAuthorityCode.notHost,
      '普通参与者授角色 → not_host');

  d = RoomRoleAuthority.grantDecision(cohostGrant, [hostGrant]);
  check(d.accept && d.code == RoomRoleAuthorityCode.accepted,
      '主持人任命联合主持人 → accepted');

  d = RoomRoleAuthority.grantDecision(cohostGrant, [hostGrant, cohostGrant]);
  check(d.accept && d.code == RoomRoleAuthorityCode.accepted,
      '同一份此前列表重放两次 → 同一结论（可复算）');

  final stepDown = await (() async {
    final g = _grant(
      roomId: 'room-alpha',
      agentId: 'alice',
      agentPub: alice.pub,
      role: RoomRoleKind.participant,
      grantedBy: 'alice',
      granterPub: alice.pub,
      atMs: kNow + 2000,
    );
    return g.copyWith(sig: await alice.sign(g.canonicalBytes()));
  })();
  d = RoomRoleAuthority.grantDecision(stepDown, [hostGrant]);
  check(!d.accept && d.code == RoomRoleAuthorityCode.lastHost,
      '撤掉房间最后一个主持层 → last_host');

  d = RoomRoleAuthority.grantDecision(stepDown, [hostGrant, cohostGrant]);
  check(d.accept && d.code == RoomRoleAuthorityCode.accepted,
      '还有别的联合主持人时，主持人可以卸任 → accepted');

  // =========================================================================
  print('--- ⑦ 铁律 1 正向表述：离开房间，你什么都不是 ---');
  check(
    RoomRoleAuthority.roleOf([hostGrant], 'room-alpha', 'alice') ==
        RoomRoleKind.host,
    '房间内：读到 host',
  );
  check(
    RoomRoleAuthority.roleOf([hostGrant], 'room-beta', 'alice') ==
        RoomRoleKind.participant,
    '★ 出了这个房间：恒为 participant（角色不跟账号走）',
  );
  check(
    await RoomRoleService(store: MemoryRoomRoleStore()).globalRole('alice') ==
        RoomRoleKind.participant,
    'RoomRoleService.globalRole 恒为 participant（与上一条同一铁律）',
  );

  // =========================================================================
  // 给 Node 侧跨语言校验留**探针**（与 M9 技能清单同一做法）：
  // Dart 签的这条授予，稍后必须能被 Node 验过，且两端 canonical / 叶子字节逐字节相同。
  print('--- ⑧ 留跨语言探针（供 tool/verify_room_role_hub.js 消费） ---');
  File('tool/_m10_role_signed_grant.json')
      .writeAsStringSync(jsonEncode(good.toSignedMap()));
  File('tool/_m10_role_canonical.txt').writeAsStringSync(good.canonical());
  File('tool/_m10_role_leaf.txt').writeAsStringSync(utf8.decode(good.logBytes()));
  check(
    File('tool/_m10_role_signed_grant.json').existsSync(),
    '探针文件已写出（_m10_role_signed_grant.json / canonical / leaf）',
  );

  // =========================================================================
  print('');
  print('================ 房间角色 Host 层可验证性校验：$_pass PASS / $_fail FAIL ================');
  // ★ `run_all_verify.dart` 用这个格式解析读数，别改名。
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exit(1);
}
