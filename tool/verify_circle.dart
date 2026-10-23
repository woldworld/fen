// 纯 Dart 校验脚本：验证 M1「入场即进圈」的核心不变量。
// 运行：dart run tool/verify_circle.dart
//
// 覆盖 PRD §4 M1 与 §5.4「不可补录」原则的关键点：
//   - 邀请码可独立验签（不需要联网问服务器）
//   - 入圈瞬间即生成成员签名（不可后补）
//   - 双向签名覆盖同一份 canonical 载荷（任何一方无法单方伪造）
//   - 验收：≥3 个可互动分身且 ≥2 个不是邀请者

import 'dart:convert';

import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/circle_service.dart';
import 'package:dahuang_ai/core/neighbor_pool.dart';

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

Future<void> main() async {
  final alice = await Ed25519Signer.generate(); // 邀请方（圈主）
  final bob = await Ed25519Signer.generate(); // 新人
  final carol = await Ed25519Signer.generate();
  final dave = await Ed25519Signer.generate();

  final alicePub = await alice.publicKeyBase58();
  final bobPub = await bob.publicKeyBase58();

  print('--- 邀请码 ---');
  final store = MemoryCircleStore();
  final svcA = CircleService(store: store, signer: alice);
  const circleId = 'lisbon-2026';
  await svcA.createCircle(
      id: circleId, name: 'Lisbon newcomers', founderId: 'alice', city: 'Lisbon');

  final invite = await svcA.createInvite(
    circleId: circleId,
    circleName: 'Lisbon newcomers',
    inviterId: 'alice',
  );

  final code = invite.encode();
  final decoded = CircleInvite.decode(code);
  check(decoded != null, '邀请码可解码');
  check(decoded!.circleId == circleId, '圈 ID 往返一致');
  check(decoded.inviterPub == alicePub, '邀请方公钥随码携带（可离线验签）');
  check(await decoded.verify(), '邀请码验签通过');

  final tampered = CircleInvite(
    circleId: 'evil-circle',
    circleName: 'Lisbon newcomers',
    inviterId: 'alice',
    inviterPub: decoded.inviterPub,
    nonce: decoded.nonce,
    expMs: decoded.expMs,
    sig: decoded.sig,
  );
  check(!await tampered.verify(), '篡改圈 ID 后验签失败（防钓鱼圈）');

  // ★ 邀请码来自**扫码/粘贴**（不可信输入），畸形串必须 fail-closed 返回 null，
  //   不能"半解码"出一个字段残缺的对象继续往下走。下面六种都实际踩得出来：
  String b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  final malformedCases = <String, String>{
    '空串': '',
    '无分隔符': 'not-a-code',
    '分隔符过多': 'a.b.c',
    '前半段非 base64url': '###.{sig}',
    '缺 inviterPub 字段':
        '${b64('{"circleId":"c","inviterId":"a","nonce":"n","exp":1}')}.sig',
    'exp 不是数字':
        '${b64('{"circleId":"c","inviterId":"a","inviterPub":"$alicePub","nonce":"n","exp":"soon"}')}.sig',
  };
  final decodeBad = <String>[];
  for (final e in malformedCases.entries) {
    if (CircleInvite.decode(e.value) != null) decodeBad.add(e.key);
  }
  check(decodeBad.isEmpty,
      '★ 六种畸形邀请码全部 fail-closed 返回 null（未拒=${decodeBad.isEmpty ? '无' : decodeBad.join(',')}）');

  // 换邀请方公钥、签名不动 → 必拒（防"拿 A 的码冒充 B 邀请"）
  final swappedInviter = CircleInvite(
    circleId: decoded.circleId,
    circleName: decoded.circleName,
    inviterId: decoded.inviterId,
    inviterPub: bobPub,
    nonce: decoded.nonce,
    expMs: decoded.expMs,
    sig: decoded.sig,
  );
  check(!await swappedInviter.verify(),
      '篡改邀请方公钥（签名换人）→ 验签失败（防张冠李戴）');

  print('--- 过期 ---');
  final expired = CircleInvite(
    circleId: circleId,
    circleName: 'x',
    inviterId: 'alice',
    inviterPub: alicePub,
    nonce: 'n1',
    expMs: 1000,
    sig: await alice.signBytes(utf8.encode(
        'INVITE|$circleId|x|alice|$alicePub|n1|1000')),
  );
  check(expired.isExpired(2000), '过期邀请被识别');
  // ★ 边界：判据是 `now > exp`（严格大于）→ 恰好等于到期时刻**不算**过期。
  //   只测"1000ms 之后过期"测不出 0/1 之差；真机上过期判断差 1ms 就会误拒还在有效期的码。
  check(!expired.isExpired(1000), 'now == expMs(1000) → 未过期（边界：严格大于才算）');
  check(expired.isExpired(1001), 'now == expMs + 1 → 过期（边界另一侧）');
  final storeB = MemoryCircleStore();
  final svcBExpired = CircleService(store: storeB, signer: bob);
  check(
    await svcBExpired.acceptInvite(code: expired.encode(), memberId: 'bob') == null,
    '过期邀请不可接受',
  );

  print('--- 入圈签名（不可补录）---');
  final svcB = CircleService(store: store, signer: bob);
  final join = await svcB.acceptInvite(code: code, memberId: 'bob');
  check(join != null, 'B 接受邀请成功');
  check(join!.memberSig != null, '入圈瞬间即生成成员签名（不可后补）');
  check(join.memberPub == bobPub, '成员公钥记录正确');
  check(await join.verifyMember(), '成员签名可验证');
  check(!join.isFullySigned, '此时尚未双向签名');
  check(!await join.verify(), '单向签名不算完整');

  print('--- 双向签名 ---');
  final approved = await svcA.hostApprove(circleId: circleId, memberId: 'bob');
  check(approved != null && approved.isFullySigned, '圈主副签后达成双向签名');
  check(await approved!.verify(), '双向签名整体校验通过');
  check(approved.hostPub == alicePub, '记录圈主公钥');

  // 关键不变量：两把签名覆盖同一份 canonical
  final canon = approved.canonical();
  check(
    await AgentProtocol.verifyRawSignature(
        utf8.encode(canon), approved.memberSig!, bobPub),
    '成员签名覆盖 canonical（用成员公钥验）',
  );
  check(
    await AgentProtocol.verifyRawSignature(
        utf8.encode(canon), approved.hostSig!, alicePub),
    '圈主签名覆盖**同一份** canonical（用圈主公钥验）',
  );
  // 任何一方篡改载荷都会让两把签名同时失效
  final forged = CircleMembership(
    circleId: circleId,
    memberId: 'bob',
    memberPub: bobPub,
    inviterId: 'alice',
    joinedAtMs: approved.joinedAtMs + 1,
    memberSig: approved.memberSig,
    hostSig: approved.hostSig,
    hostPub: approved.hostPub,
  );
  check(!await forged.verify(), '篡改 joined_at 后双向签名均失效');

  print('--- 验收：可见分身（PRD M1）---');
  // 让圈里凑够人：carol、dave 也已入圈
  final codeForCarol = (await svcA.createInvite(
          circleId: circleId, circleName: 'Lisbon newcomers', inviterId: 'alice'))
      .encode();
  await CircleService(store: store, signer: carol)
      .acceptInvite(code: codeForCarol, memberId: 'carol');
  final codeForDave = (await svcA.createInvite(
          circleId: circleId, circleName: 'Lisbon newcomers', inviterId: 'alice'))
      .encode();
  await CircleService(store: store, signer: dave)
      .acceptInvite(code: codeForDave, memberId: 'dave');

  final v = await svcB.visibleFens(
      circleId: circleId, selfId: 'bob', inviterId: 'alice');
  check(v.fens.length >= 3, 'B 可见 ≥3 个分身 (${v.fens.length})');
  check(v.nonInviterCount >= 2, '其中 ≥2 个不是邀请者 (${v.nonInviterCount})');
  check(v.meetsAcceptance, 'M1 验收通过：$v');
  check(!v.fens.contains('bob'), '不含自己');

  print('--- 兜底：圈子人数不足时 ---');
  final emptyStore = MemoryCircleStore();
  final svcSolo = CircleService(
    store: emptyStore,
    signer: bob,
    neighborFallback: (cid, self) async => ['n1', 'n2', 'n3'],
  );
  await svcSolo.createCircle(id: 'c2', name: 'Chiang Mai', founderId: 'alice');
  final v2 =
      await svcSolo.visibleFens(circleId: 'c2', selfId: 'bob', inviterId: 'alice');
  check(v2.fens.length >= 3, '兜底补足到 ≥3 (${v2.fens.length})');
  check(v2.fromFallback.length == 3, '兜底来源被单独标注');
  check(v2.meetsAcceptance, '兜底后验收通过：$v2');

  // ★ 验收阈值的**边界反例**：判据是"≥3 且其中 ≥2 不是邀请者"。
  //   只验"兜底后通过"是正例；这里给出"只有 2 个"的反例，证明阈值真的拦人。
  final svcTight = CircleService(
    store: MemoryCircleStore(),
    signer: bob,
    neighborFallback: (cid, self) async => ['alice', 'x'],
  );
  await svcTight.createCircle(id: 'c4', name: 'Tight', founderId: 'alice');
  final vTight = await svcTight.visibleFens(
      circleId: 'c4', selfId: 'bob', inviterId: 'alice');
  check(vTight.fens.length == 2 && !vTight.meetsAcceptance,
      '★ 只有 2 个可见分身 → 不通过验收（阈值是 ≥3，不是 ≥2）');
  check(vTight.nonInviterCount == 1,
      '2 个里 1 个是邀请者 → nonInviterCount=1（口径如实，不四舍五入）');

  print('--- 埋点事件 ---');
  final events = <Map<String, Object?>>[];
  final storeE = MemoryCircleStore();
  final svcE = CircleService(
      store: storeE,
      signer: alice,
      onEvent: (n, p) => events.add({'name': n, ...p}));
  await svcE.createCircle(id: 'c3', name: 'Austin', founderId: 'alice');
  final codeE = (await svcE.createInvite(
          circleId: 'c3', circleName: 'Austin', inviterId: 'alice'))
      .encode();
  await CircleService(
    store: storeE,
    signer: bob,
    onEvent: (n, p) => events.add({'name': n, ...p}),
  ).acceptInvite(code: codeE, memberId: 'bob');

  check(events.any((e) => e['name'] == 'invite_created'), '产出 invite_created');
  check(events.any((e) => e['name'] == 'invite_accepted'), '产出 invite_accepted');
  check(events.any((e) => e['name'] == 'circle_entered'), '产出 circle_entered');
  final ent = events.firstWhere((e) => e['name'] == 'circle_entered');
  check(ent['circle_id'] == 'c3', 'circle_entered 带 circle_id');

  // ---- 兜底池规则（真机侧由 NeighborSource 供 ID，规则在这里可离线复算）
  print('--- 兜底池：排除自己 / 跨来源去重 / 上限 / 来源统计 ---');
  check(
      NeighborPool.merge(
        selfId: 'me',
        bySource: {
          'nearfield': ['a', 'me'],
          'lan': ['a', 'b'],
          'roster': ['b', 'c'],
        },
      ).join(',') ==
          'a,b,c',
      '跨来源去重且排除自己 → a,b,c');
  check(
      NeighborPool.summarize(
        selfId: 'me',
        bySource: {
          'nearfield': ['a', 'me'],
          'lan': ['a', 'b'],
          'roster': ['b', 'c'],
        },
      ) ==
          'nearfield:1,lan:1,roster:1',
      '来源统计算的是"去重后各自的净贡献"（不虚报）');
  check(
      NeighborPool.summarize(selfId: 'me', bySource: {'nearfield': [], 'lan': []}) ==
          'none',
      '一个都没有 → none');
  check(
      NeighborPool.summarize(selfId: 'me', bySource: {
        'roster': ['me']
      }) ==
          'none',
      '只有自己 → none（不能把自己算成邻居）');
  final capped = NeighborPool.merge(
    selfId: 'me',
    bySource: {
      'roster': [for (var i = 0; i < 50; i++) 'p$i'],
    },
    max: 20,
  );
  check(capped.length == 20, '上限生效（50 → 20）');
  check(
      NeighborPool.merge(selfId: 'me', bySource: {
        'lan': ['a', 'b', 'c']
      }, max: 2).join(',') ==
          'a,b',
      '上限=2 恰好取前 2 个（off-by-one：不多不少）');
  check(
      NeighborPool.merge(selfId: 'me', bySource: {
        'lan': ['a', 'b']
      }, max: 0).isEmpty,
      'max=0 → 空（"上限为 0"就是"一个都不要"，不是"不限"）');
  check(
      NeighborPool.merge(selfId: 'me', bySource: {
        'lan': ['  ', 'x']
      }).join(',') ==
          'x',
      '空串/空白 ID 被丢弃');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
