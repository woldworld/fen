// 纯 Dart 校验脚本：换钥链**公开视图**（`GET /api/identity/rotations` 的消费侧）。
// 运行：dart run tool/verify_rotation_chain.dart
//
// 为什么值得单独一个脚本：
//   这一层是"**可被第三方独立复核**"里"**复核方**"的那一半。Hub 只回原始记录、
//   不回结论；结论必须在读者这一侧算出来。因此这里盯的是三件事：
//
//   ① **fail-closed 解析**：回包形状不对一律返回 null，不猜、不部分接受。
//      —— 一个"半信半疑地接受"的解析器，比不解析更危险：它会显示出一份
//         看起来正常的链，而其中某些字段其实来自畸形输入。
//   ② **本地独立复算**：`verifySignatures` / `verifyLinks` / `tipMatchesActive`
//      的每一条判定都有正例与负例（篡改中段、签名错挂、末端不指活跃钥）。
//   ③ **Hub 的自述只是对照**：`chain_ok` / `chain_links_ok` 即便说"好"，
//      也不能让本地结论变成"好" —— 断言这一点，是为了防止将来有人图省事
//      把 Hub 的字段直接当结论展示。
//
// 本脚本只 import 纯 Dart 模块（无 Flutter / sqflite / shared_preferences），故可离线复算。
// ★ 末尾必须打印 `PASS=n FAIL=n`（`tool/run_all_verify.dart` 的汇总口径）。

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/identity_rotation.dart';
import 'package:dahuang_ai/core/rotation_chain.dart';

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
const String kAgent = 'AG-CHAIN01';

Future<({String pub, Uint8List seed})> _newKey() async {
  final kp = await Ed25519().newKeyPair();
  final seed = await kp.extractPrivateKeyBytes();
  final pubBytes = await kp.extractPublicKey();
  return (
    pub: AgentProtocol.base58Encode(pubBytes.bytes),
    seed: Uint8List.fromList(seed),
  );
}

Future<String> _sign(Uint8List seed, List<int> msg) async {
  final kp = await Ed25519().newKeyPairFromSeed(seed);
  final s = await Ed25519().sign(msg, keyPair: kp);
  return base64Encode(s.bytes);
}

/// 造一条**真签名**的换钥记录。
Future<IdentityRotation> _rot({
  required Uint8List signSeed,
  required String oldPub,
  required String newPub,
  int atMs = kNow,
  String agentId = kAgent,
}) async {
  final r = IdentityRotation(
    agentId: agentId,
    oldPub: oldPub,
    newPub: newPub,
    rotatedAtMs: atMs,
  );
  return r.copyWith(sig: await _sign(signSeed, r.canonicalBytes()));
}

/// Hub 回包的最小形状（字段名与 `lib/hub/hub.js` 的 `/api/identity/rotations` 对齐）。
Map<String, Object?> _hubJson({
  required List<IdentityRotation> rotations,
  Map<String, Object?>? subject,
  bool chainLinksOk = true,
  List<String> broken = const [],
  int logSize = 7,
  String root = 'AAAA',
}) =>
    {
      'proto': 'wold/1',
      'size': rotations.length,
      'total': rotations.length,
      'log_size': logSize,
      'root': root,
      'chain_links_ok': chainLinksOk,
      'broken_agents': broken,
      'subject': subject,
      'rotations': rotations.map((r) => r.toMap()).toList(),
    };

Future<void> main() async {
  // ---------------------------------------------------------------- 解析 fail-closed
  print('== ① fail-closed 解析');
  check(RotationChain.tryParse(null) == null, 'null → null');
  check(RotationChain.tryParse('x') == null, '字符串 → null');
  check(RotationChain.tryParse(<String, Object?>{}) == null,
      '缺 rotations → null');
  check(RotationChain.tryParse({'rotations': 'x'}) == null,
      'rotations 不是数组 → null');
  check(RotationChain.tryParse({'rotations': [1, 2]}) == null,
      '数组成员不是对象 → null（整份丢弃，不部分接受）');
  final emptyChain = RotationChain.tryParse({'rotations': <Object>[]});
  check(emptyChain != null && emptyChain.rotations.isEmpty,
      '空 rotations 是合法回包（"从未换过钥"是一条有意义的答复）');

  // subject 形状坏掉时：记录仍然保留，但 subject 置 null（不猜）
  final badSubject = RotationChain.tryParse({
    'rotations': <Object>[],
    'subject': {'agent_id': kAgent, 'chain_breaks': 'oops'},
  });
  check(badSubject != null && badSubject.subject == null,
      'subject.chain_breaks 形状坏 → subject 置 null（记录不受影响）');

  final badBreak = RotationChain.tryParse({
    'rotations': <Object>[],
    'subject': {
      'agent_id': kAgent,
      'chain_breaks': [
        {'at_idx': 1} // 缺 reason
      ],
    },
  });
  check(badBreak != null && badBreak.subject == null,
      '★ 断裂项缺 reason → 整段 subject 判为不可信（不静默丢掉那一项）');

  final goodBreak = RotationChain.tryParse({
    'rotations': <Object>[],
    'subject': {
      'agent_id': kAgent,
      'chain_breaks': [
        {'at_idx': 2, 'reason': 'link_mismatch'}
      ],
    },
  });
  check(goodBreak?.subject?.chainBreaks.single.atIdx == 2 &&
          goodBreak?.subject?.chainBreaks.single.reason == 'link_mismatch',
      '合法断裂项被正确解析');

  // ---------------------------------------------------------------- 本地查链
  print('== ② 本地逐环查链');
  final k0 = await _newKey();
  final k1 = await _newKey();
  final k2 = await _newKey();
  final r1 = await _rot(signSeed: k0.seed, oldPub: k0.pub, newPub: k1.pub);
  final r2 = await _rot(
      signSeed: k1.seed, oldPub: k1.pub, newPub: k2.pub, atMs: kNow + 1000);

  final good = RotationChain.tryParse(_hubJson(
    rotations: [r1, r2],
    subject: {
      'agent_id': kAgent,
      'did': 'did:wold:x',
      'registered': true,
      'current_pubkey': k2.pub,
      'rotations': 2,
      'chain_ok': true,
      'chain_breaks': <Object>[],
    },
  ))!;
  check(good.verifyLinks().isEmpty, '拼接正确的链 → 无断裂');
  check(good.tipMatchesActive(), '末端 = 当前活跃钥 → OK');
  check(good.subject!.unknownIdentity == false, '已注册 → 不是"未知身份"');

  // 把中段接错：第二条的 `old_pub` 不再等于第一条的 `new_pub`。
  // ⚠️ 刻意让它的**签名仍然有效**（由它自称的 old_pub 签出）——
  //    这样才能单独验证"链的拼接"这一项，而不被验签结果掩盖。
  final mislinked = IdentityRotation(
    agentId: kAgent,
    oldPub: k0.pub, // 应该是 k1.pub（= r1.newPub）
    newPub: k2.pub,
    rotatedAtMs: kNow + 1000,
  ).copyWith(sig: await _sign(k0.seed, IdentityRotation(
        agentId: kAgent,
        oldPub: k0.pub,
        newPub: k2.pub,
        rotatedAtMs: kNow + 1000,
      ).canonicalBytes()));

  final tamperedMid = RotationChain.tryParse(_hubJson(
    rotations: [r1, mislinked],
    subject: {'agent_id': kAgent, 'current_pubkey': k2.pub},
  ))!;
  final brk = tamperedMid.verifyLinks();
  check(brk.length == 1 && brk.single.atIdx == 1 &&
          brk.single.reason == 'link_mismatch',
      '★ 中段接错 → 本地报 link_mismatch@1');
  check(tamperedMid.tipMatchesActive(),
      '末端仍等于活跃钥 ⇒ 这一例只暴露"链断"，不与 tip 混淆');

  // 单独一例：链拼接正确，但末端不指活跃钥（中间漏了一次换钥）
  final tipBad = RotationChain.tryParse(_hubJson(
    rotations: [r1, r2],
    subject: {'agent_id': kAgent, 'current_pubkey': k0.pub}, // 应然是 k2.pub
  ))!;
  check(tipBad.verifyLinks().isEmpty, 'tipBad 的链本身是拼得上的');
  check(!tipBad.tipMatchesActive(),
      '★ 末端不等于活跃钥 → tipMatchesActive=false');

  // ---------------------------------------------------------------- 本地验签
  print('== ③ 本地逐条验签');
  final sigsOk = await good.verifySignatures();
  check(sigsOk.total == 2 && sigsOk.valid == 2 && sigsOk.allValid,
      '两条真签名 → 2/2 有效');
  check(sigsOk.invalidIndices.isEmpty, '无一条无效');

  // 把第 2 条的签名换成第 1 条的（签名与内容不匹配）
  final sigSwapped = RotationChain.tryParse(_hubJson(
    rotations: [r1, r2.copyWith(sig: r1.sig)],
    subject: {'agent_id': kAgent, 'current_pubkey': k2.pub},
  ))!;
  final sigsBad = await sigSwapped.verifySignatures();
  check(sigsBad.valid == 1 && sigsBad.invalidIndices.length == 1 &&
          sigsBad.invalidIndices.single == 1,
      '★ 签名错挂第 2 条 → 只有第 2 条判无效（逐条定位，不整份否定）');
  check(!sigsBad.allValid, '有无效签名 → allValid=false');

  // 一条**合法但属于别的消息**的签名：拿 r1 的规范串去签，却塞进 r2 的字段
  final foreign = await _sign(k0.seed, r2.canonicalBytes()); // k0 签 r2 的内容
  final sigForeign = RotationChain.tryParse(_hubJson(
    rotations: [r1, r2.copyWith(sig: foreign)],
    subject: {'agent_id': kAgent, 'current_pubkey': k2.pub},
  ))!;
  final sigsForeign = await sigForeign.verifySignatures();
  check(sigsForeign.invalidIndices.single == 1,
      '★ 用别人的钥签的内容 → 判无效（不是"签名格式对就算过"）');

  // ---------------------------------------------------------------- Hub 自述 ≠ 本机结论
  print('== ④ Hub 自述只作对照');
  final lyingHub = RotationChain.tryParse({
    ..._hubJson(
      rotations: [r1, r2.copyWith(sig: r1.sig)], // 签名是坏的
      subject: {'agent_id': kAgent, 'current_pubkey': k2.pub},
    ),
    'chain_links_ok': true, // 但 Hub 说自己没问题
  })!;
  check(lyingHub.chainLinksOk == true, 'Hub 字段被原样读取（不做二次解释）');
  final lyingSigs = await lyingHub.verifySignatures();
  check(!lyingSigs.allValid,
      '★★ 即便 Hub 说 ok，本机自算仍判无效 —— 结论在读者这一侧');

  // ---------------------------------------------------------------- summarize
  print('== ⑤ 结论汇总');
  check(RotationChain.summarize(
          sigs: sigsOk, links: const [], tipOk: true) ==
      'ok', '全好 → ok');
  check(RotationChain.summarize(
          sigs: sigsBad, links: const [], tipOk: true) ==
      'sig_invalid', '签名坏 → sig_invalid');
  check(RotationChain.summarize(
          sigs: sigsOk, links: brk, tipOk: true) ==
      'link_mismatch', '链断 → link_mismatch');
  check(RotationChain.summarize(
          sigs: sigsOk,
          links: tipBad.verifyLinks(),
          tipOk: tipBad.tipMatchesActive()) ==
      'tip_not_active', '末端不指活跃钥 → tip_not_active（用真实链算，不喂合成值）');
  check(RotationChain.summarize(
          sigs: sigsOk, links: brk, tipOk: false) ==
      'link_mismatch', '多种问题并存时优先级稳定（签名好则先报链断）');

  // ---------------------------------------------------------------- 未知身份
  print('== ⑥ 未知身份');
  final unknown = RotationChain.tryParse(_hubJson(
    rotations: const [],
    subject: {
      'agent_id': kAgent,
      'did': 'did:wold:x',
      'registered': false,
      'rotations': 0,
    },
  ))!;
  check(unknown.subject!.unknownIdentity,
      '未注册 + 零换钥 → unknownIdentity（UI 据此说"Hub 不认识它"）');
  check(emptyChain!.tipMatchesActive(),
      '空链的 tipMatchesActive 恒为 true（无从比较 ≠ 断裂）');

  // ---------------------------------------------------------------- 身份别名
  // M6 背书按 `subject_pub` 计（不用 agent_id：名字可被重发 ⇒ "改个名就能甩掉差评"）。
  // 代价是换钥退休旧公钥后，他此前收到的背书全都留在那把死钥上 —— 于是
  // "履历随人走"当场退化成"随钥走"（换一次手机履历归零）。
  // 别名解析就是把换钥链已经证明的事**用起来**，而它的失败方向必须是"少给"。
  print('== ⑦ 身份别名（谁的钥是"同一个人"）');
  final aliasTip = await good.keysOf(k2.pub);
  check(aliasTip.status == AliasStatus.ok,
      '完整签名 + 逐环相接的链 → ok');
  check(aliasTip.keys.length == 3 &&
          aliasTip.keys.first == k0.pub &&
          aliasTip.keys.last == k2.pub,
      '★ 查当前钥 → 返回整条历史（创世 → 当前）');
  final aliasOld = await good.keysOf(k0.pub);
  check(aliasOld.status == AliasStatus.ok && aliasOld.keys.length == 3,
      '★ 查**已退休**的钥 → 解出同一个身份（履历需要的正是这个方向）');
  check(aliasOld.keys.join('|') == aliasTip.keys.join('|'),
      '从两端查得到同一个集合');
  final aliasMid = await good.keysOf(k1.pub);
  check(aliasMid.status == AliasStatus.ok && aliasMid.keys.length == 3,
      '中间的钥同样解出整条链');
  check(aliasTip.chain.length == 2 && aliasTip.agentId == kAgent,
      '把依据（原始记录 + 归属身份）一并交出去，读者可复核');

  // ★★ 换回旧钥（A→B→A）：`keys` 是**集合**（[A,B]），而**末端必须仍是活跃钥 A**。
  //    取 `keys.last` 会把刚被退休的 B 报成末端 —— 与 Hub 端点（读 `chain[last].new_pub`）
  //    不一致；而末端正是读者拿去和"Hub 报的活跃钥"比对的那个值。
  final rBack = await _rot(
      signSeed: k1.seed, oldPub: k1.pub, newPub: k0.pub, atMs: kNow + 1000);
  final backChain = RotationChain.tryParse(_hubJson(
    rotations: [r1, rBack],
    subject: {
      'agent_id': kAgent,
      'did': 'did:wold:x',
      'registered': true,
      'current_pubkey': k0.pub, // 换回后活跃钥 = k0
      'rotations': 2,
      'chain_ok': true,
      'chain_breaks': <Object>[],
    },
  ))!;
  final back = await backChain.keysOf(k0.pub);
  check(back.status == AliasStatus.ok, '换回旧钥（A→B→A）仍解出 ok');
  check(back.keys.join('|') == [k0.pub, k1.pub].join('|'),
      '换回旧钥：keys 是去重后的**集合**（A,B）');
  check(back.keys.last != back.tip,
      '★ 换回旧钥：keys.last 是刚被退休的那把 ⇒ 不能当成末端');
  check(back.tip == k0.pub,
      '★★ 换回旧钥：tip = **当前活跃钥**（A），不是 keys.last（B）');
  check(backChain.tipMatchesActive(),
      '★ 换回旧钥：tipMatchesActive 与 keysOf 的 tip **同口径**（都读链尾 new_pub）');
  // 正控：直链上 tip 恰好等于 keys.last —— 说明上面两条不是"恒假检查"。
  check(aliasTip.tip == k2.pub && aliasTip.tip == aliasTip.keys.last,
      '★ 正控：直链上 tip = 当前钥 = keys.last');

  // ---- fail-closed：任何不确定都收敛到"只认它自己" ----
  final aliasNone = await good.keysOf('SOMEONE-ELSE');
  check(aliasNone.status == AliasStatus.noChain &&
          aliasNone.keys.length == 1 &&
          aliasNone.keys.single == 'SOMEONE-ELSE',
      '★ 不在任何换钥记录里的钥 = 它自己的整个身份（no_chain）');
  final aliasEmpty = await good.keysOf('   ');
  check(aliasEmpty.keys.isEmpty, '空主体 → 解不出任何钥');

  // 一环坏签名 ⇒ **整条链作废**（看不出断口哪一侧才是真的）
  final chainUnsigned =
      RotationChain.tryParse(_hubJson(rotations: [r1, r2.copyWith(sig: foreign)]))!;
  final aliasUnsigned = await chainUnsigned.keysOf(k2.pub);
  check(aliasUnsigned.status == AliasStatus.unsigned &&
          aliasUnsigned.keys.length == 1 &&
          aliasUnsigned.keys.single == k2.pub,
      '★ 链上有坏签名 → 收敛成单钥（unsigned），不把半条链当结论');

  // 逐环接不上 ⇒ 同样收敛（漏记一次换钥，或记录被动过）
  final chainBroken =
      RotationChain.tryParse(_hubJson(rotations: [r1, mislinked]))!;
  final aliasBroken = await chainBroken.keysOf(k2.pub);
  check(aliasBroken.status == AliasStatus.broken &&
          aliasBroken.keys.length == 1,
      '★ 环接不上 → 收敛成单钥（broken）');

  // 一把钥被两个身份认领 ⇒ 拒绝替任何一方下结论
  final otherKey = await _newKey();
  final rOther = await _rot(
    signSeed: otherKey.seed,
    oldPub: k2.pub,
    newPub: k1.pub,
    atMs: kNow + 2000,
    agentId: 'AG-OTHER01',
  );
  final chainAmb =
      RotationChain.tryParse(_hubJson(rotations: [r1, r2, rOther]))!;
  final aliasAmb = await chainAmb.keysOf(k2.pub);
  check(aliasAmb.status == AliasStatus.ambiguous &&
          aliasAmb.keys.length == 1 &&
          aliasAmb.keys.single == k2.pub,
      '★ 一把钥被两个身份认领 → ambiguous（不替任何一方下结论）');

  check(AliasStatus.values.contains(AliasStatus.ambiguous) &&
          AliasStatus.isOk(AliasStatus.ok) &&
          !AliasStatus.isOk(AliasStatus.broken),
      '稳定码表齐备，且只有 ok 才算解析成功');

  print('');
  print('PASS=$_pass FAIL=$_fail');
}
