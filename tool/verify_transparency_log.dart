// 纯 Dart 校验脚本：验证 §16「可验证性：闭源信任层的补位机制」的 Merkle 基建。
// 运行：dart run tool/verify_transparency_log.dart
//
// 逐条对齐 RFC 6962（证书透明度 CT 的树定义）：
//   · 只追加日志（哈希链，改任何一条历史都会断链）
//   · Inclusion proof  §2.1.1 —— "我的这条记录确实在日志里"
//   · Consistency proof §2.1.2 —— "第 N 期是第 N−1 期的延续"
//
// PRD §16 原话：**"只发 root 不够 —— 一致性证明才能证明第 N 期是第 N−1 期的延续。"**
// 所以本脚本对两种证明都做**正反两向**验证（能验过 + 篡改必被拒）。

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/transparency_log.dart';

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

/// 造一片叶子（业务无关：叶子的语义由调用方决定，见 §16.1 与 M10 合流）
List<int> leaf(String s) => utf8.encode(s);

/// RFC 6962 §2.1.3 的经典测试树（n=7），叶子内容固定 → 结果可复算。
const List<String> _ctLeaves = [
  'd0',
  'd1',
  'd2',
  'd3',
  'd4',
  'd5',
  'd6',
];

Future<TransparencyLog> buildLog([List<String>? src]) async {
  final log = TransparencyLog();
  for (final s in (src ?? _ctLeaves)) {
    await log.append(leaf(s));
  }
  return log;
}

Future<void> main() async {
  // ---------------------------------------------------------------------
  print('--- 只追加日志：哈希链 ---');
  final log = await buildLog();
  check(log.size == 7, '7 片叶子');
  check(await log.verifyChain(), '链自洽（每条 prev_hash 都接得上）');
  check(log.entries.first.prevHash == '', '第 0 条的 prev 为空');
  check(log.last!.index == 6 && log.last!.hash.isNotEmpty, '末条有哈希');

  // 链规则可复算：hash = base58(SHA-256('WL|idx|leafHash|prevHash'))
  Future<String> chainHash(int idx, String leafHash, String prev) async =>
      AgentProtocol.base58Encode(
          (await Sha256().hash(utf8.encode('WL|$idx|$leafHash|$prev'))).bytes);

  var chainFormulaOk = true;
  for (final e in log.entries) {
    if (await chainHash(e.index, e.leafHash, e.prevHash) != e.hash) {
      chainFormulaOk = false;
    }
  }
  check(chainFormulaOk, '每条 hash 都等于链式公式的结果（第三方可独立复算）');

  // 改历史：把第 2 条的 leafHash 换掉，链式公式立刻对不上
  final e2 = log.entries[2];
  final forgedLeafHash = AgentProtocol.base58Encode(
      (await Sha256().hash(utf8.encode('forged-leaf'))).bytes);
  check(await chainHash(e2.index, forgedLeafHash, e2.prevHash) != e2.hash,
      '改第 2 条的 leafHash → 该条 hash 对不上（改写必留痕）');

  // 删历史：把第 2 条拿掉，第 3 条的 index/prev 立刻错位
  final e3 = log.entries[3];
  check(e3.prevHash == e2.hash, '（前提）第 3 条的 prev 指向第 2 条');
  check(e3.index != e2.index, '（前提）序号各不相同');
  check(await chainHash(e3.index, e3.leafHash, e2.prevHash) != e3.hash,
      '删掉第 2 条 → 第 3 条既错序号又错 prev，hash 对不上（删除必留痕）');

  // ---------------------------------------------------------------------
  print('--- Merkle 根：规模前缀稳定 ---');
  final r7 = await log.root();
  final r5 = await log.rootAt(5);
  check(r7.isNotEmpty && r5.isNotEmpty && r7 != r5, 'n=7 与 n=5 的根不同');

  // 前缀稳定性：另造一棵前 5 片相同、后 2 片不同的树，n=5 的根必须一致。
  // 这就是"一致性"的基础事实。
  final log2 = await buildLog(['d0', 'd1', 'd2', 'd3', 'd4', 'X5', 'X6']);
  check(await log2.rootAt(5) == r5, '前 5 片相同 → n=5 的根相同（前缀稳定）');
  check(await log2.root() != r7, '后 2 片不同 → 整树根不同');

  // 空树
  final empty = TransparencyLog();
  check(await empty.root() == await TransparencyLog.emptyRoot(), '空树根 = SHA-256()');
  check(empty.isEmpty && await empty.verifyChain(), '空树链自洽');

  // ---------------------------------------------------------------------
  print('--- 域分隔（防二级原像攻击）---');
  final single = TransparencyLog();
  await single.append(leaf('d0'));
  final singleRoot = await single.root();
  final rawHash = AgentProtocol.base58Encode(
      (await Sha256().hash(leaf('d0'))).bytes);
  check(singleRoot != rawHash,
      '单叶树根 ≠ SHA-256(leaf)（0x00 前缀生效，叶子不能冒充内部节点）');
  final nodeStyle = AgentProtocol.base58Encode(
      (await Sha256().hash(_catB([0x01], _catB([0x00], leaf('d0'))))).bytes);
  check(singleRoot != nodeStyle, '叶子哈希与内部节点哈希不重合（0x00 / 0x01 分离）');

  // ---------------------------------------------------------------------
  print('--- Inclusion proof：每一片叶子都要验得过 ---');
  var allInclusion = true;
  for (var i = 0; i < log.size; i++) {
    final p = await log.inclusionProof(i);
    final ok = await MerkleVerify.inclusion(
        leaf: leaf(_ctLeaves[i]), proof: p, root: r7);
    if (!ok) {
      allInclusion = false;
      print('        ✗ index=$i');
    }
  }
  check(allInclusion, 'n=7 全部 7 片叶子的包含证明都验得过');

  // 边界规模：n=1..7 全跑一遍（2 的幂与非幂都要覆盖）
  var allSizes = true;
  for (var n = 1; n <= 7; n++) {
    final l = await buildLog(_ctLeaves.sublist(0, n));
    final root = await l.root();
    for (var i = 0; i < n; i++) {
      final p = await l.inclusionProof(i);
      if (!await MerkleVerify.inclusion(
          leaf: leaf(_ctLeaves[i]), proof: p, root: root)) {
        allSizes = false;
        print('        ✗ n=$n index=$i');
      }
    }
  }
  check(allSizes, 'n=1..7 每个规模、每片叶子都验得过（含 2 的幂边界）');

  // ---------------------------------------------------------------------
  print('--- Inclusion proof 反例：改叶 / 换根 / 错位都要被拒 ---');
  final p2 = await log.inclusionProof(2);
  check(!await MerkleVerify.inclusion(
          leaf: leaf('d9-not-in-log'), proof: p2, root: r7),
      '叶子内容不对 → 不通过');
  check(!await MerkleVerify.inclusion(
          leaf: leaf('d2'), proof: p2, root: r5),
      '根不对 → 不通过');
  check(!await MerkleVerify.inclusion(
          leaf: leaf('d2'),
          proof: MerkleProof(
              index: 3, treeSize: p2.treeSize, path: p2.path),
          root: r7),
      '索引错位 → 不通过');
  check(!await MerkleVerify.inclusion(
          leaf: leaf('d2'),
          proof: MerkleProof(
              index: p2.index,
              treeSize: p2.treeSize,
              path: [...p2.path]..removeLast()),
          root: r7),
      '路径被截断 → 不通过');
  check(!await MerkleVerify.inclusion(
          leaf: leaf('d2'),
          proof: MerkleProof(
              index: p2.index,
              treeSize: p2.treeSize,
              path: [...p2.path.sublist(0, p2.path.length - 1), r5]),
          root: r7),
      '路径里塞一个别的哈希 → 不通过');

  // ---------------------------------------------------------------------
  print('--- Consistency proof：第 N 期是第 N−1 期的延续 ---');
  var allConsistency = true;
  var pairs = 0;
  for (var m = 0; m <= 7; m++) {
    for (var n = m; n <= 7; n++) {
      pairs++;
      final proof = await log.consistencyProof(m, n);
      final fromR = await log.rootAt(m);
      final toR = await log.rootAt(n);
      final ok = await MerkleVerify.consistency(
          proof: proof, fromRoot: fromR, toRoot: toR);
      if (!ok) {
        allConsistency = false;
        print('        ✗ m=$m n=$n');
      }
    }
  }
  check(allConsistency, '全部 $pairs 组 (m,n) 一致性证明都验得过（m≤n，含 m=0 与 m=n）');

  // ---------------------------------------------------------------------
  print('--- Consistency proof 反例：伪造 / 参数错配 / 回滚都要被拒 ---');
  final c37 = await log.consistencyProof(3, 7);
  check(!await MerkleVerify.consistency(
          proof: c37, fromRoot: await log.rootAt(4), toRoot: r7),
      '第一期根填错 → 不通过');
  check(!await MerkleVerify.consistency(
          proof: c37, fromRoot: await log.rootAt(3), toRoot: r5),
      '第二期根填错 → 不通过');
  check(!await MerkleVerify.consistency(
          proof: ConsistencyProof(fromSize: 3, toSize: 7, path: [...c37.path]..removeLast()),
          fromRoot: await log.rootAt(3),
          toRoot: r7),
      '证明路径被截断 → 不通过');
  check(!await MerkleVerify.consistency(
          proof: ConsistencyProof(
              fromSize: 3,
              toSize: 7,
              path: [...c37.path.sublist(0, c37.path.length - 1), await log.rootAt(2)]),
          fromRoot: await log.rootAt(3),
          toRoot: r7),
      '路径里塞一个别的哈希 → 不通过');
  // 参数错配：拿 (2,7) 的证明冒充 (3,7)
  final c27 = await log.consistencyProof(2, 7);
  check(!await MerkleVerify.consistency(
          proof: ConsistencyProof(fromSize: 3, toSize: 7, path: c27.path),
          fromRoot: await log.rootAt(3),
          toRoot: r7),
      '(2,7) 的证明冒充 (3,7) → 不通过');

  // 回滚攻击：攻击者删掉第 3..6 片叶子后的树，无法为老根出具延续证明
  final rollback = await buildLog(['d0', 'd1', 'd2']); // 只剩 3 片
  final rbRoot = await rollback.root();
  check(rbRoot == await log.rootAt(3), '（前提）被截断的树在前 3 片上与真树一致');
  var rollbackRejected = false;
  try {
    // 攻击者要证明"我的 3 片是那棵 7 片树的前缀" —— 它得先有 7 片的树
    await rollback.consistencyProof(3, 7);
  } on RangeError {
    rollbackRejected = true; // 越界：连证明都生成不出来
  }
  check(rollbackRejected, '回滚：截断后的日志生成不出到更大规模的证明（越界即拒）');

  // 而且它伪造一份也过不了验签器
  final forgedProof = ConsistencyProof(
      fromSize: 3, toSize: 7, path: [await rollback.rootAt(3)]);
  check(!await MerkleVerify.consistency(
          proof: forgedProof, fromRoot: await log.rootAt(3), toRoot: r7),
      '回滚：伪造的延续证明过不了验签器');

  // ---------------------------------------------------------------------
  print('--- 与 M6 合流：叶子哈希重放（第三方只需 leafHash 即可复算）---');
  final replay = TransparencyLog();
  for (final e in log.entries) {
    await replay.appendLeafHash(e.leafHash);
  }
  check(await replay.root() == r7, '仅凭 leafHash 列表重放 → 得到同一个根');
  check(await replay.verifyChain(), '重放后链仍自洽');
  for (var i = 0; i < 7; i++) {
    final p = await replay.inclusionProof(i);
    check(await MerkleVerify.inclusion(
            leaf: leaf(_ctLeaves[i]), proof: p, root: r7),
        '重放树里第 $i 片的包含证明验得过');
  }

  // ---------------------------------------------------------------------
  print('--- 跨语言探针导出（供 Node 侧独立复算 + 互验）---');
  // 只导出**叶子哈希**与**证明**，不导出叶子原文 —— 与 §16 的口径一致：
  // 第三方拿哈希列表就能复算整棵树，这正是"任何人可监督"的工程前提。
  // Node 侧（tool/verify_transparency_hub.js）会用同一份哈希列表
  // **自己重算**每一期根与每一份证明，并要求与这里逐项相同。
  final probe = {
    'leaves': [for (final s in _ctLeaves) await TransparencyLog.leafHashOf(leaf(s))],
    'roots': [for (var n = 0; n <= _ctLeaves.length; n++) await log.rootAt(n)],
    'inclusion': [
      for (var i = 0; i < _ctLeaves.length; i++)
        (await log.inclusionProof(i)).toMap(),
    ],
    'consistency': [
      for (var m = 0; m <= _ctLeaves.length; m++)
        for (var n = m; n <= _ctLeaves.length; n++)
          (await log.consistencyProof(m, n)).toMap(),
    ],
  };
  File('tool/.log_probe.json').writeAsStringSync(jsonEncode(probe));
  check(File('tool/.log_probe.json').existsSync(), '已导出跨语言探针（§16 产物）');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}

List<int> _catB(List<int> a, List<int> b) => [...a, ...b];
