// 纯 Dart 校验：§16 外部锚定（`lib/core/log_anchor.dart`）的 fail-closed 判据。
// 运行：dart run tool/verify_log_anchor.dart
//
// 本脚本回答两个问题：
//   1. 判据本身对不对 —— 规模倒退 / 同期换根 / 序列损坏，是否都被拦下；
//   2. **锚定是否真的补上了哈希链的洞** —— 用一个"被砍掉尾巴"的日志现场演示：
//      它的 `verifyChain()` 照样返回 true（哈希链查不出截断），
//      但锚定比对会立刻发现"我锚过 size=7 的根，你现在只有 3 片"。

import 'dart:convert';

import 'package:dahuang_ai/core/log_anchor.dart';
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

List<int> leaf(String s) => utf8.encode(s);

const List<String> _ctLeaves = ['d0', 'd1', 'd2', 'd3', 'd4', 'd5', 'd6'];

Future<TransparencyLog> buildLog(List<String> src) async {
  final log = TransparencyLog();
  for (final s in src) {
    await log.append(leaf(s));
  }
  return log;
}

Future<void> main() async {
  // ---------------------------------------------------------------------
  print('--- 判据：规模推进 / 回滚 / 同期换根 / 幂等 ---');
  final base = LogAnchor(size: 5, root: 'ROOT5', anchoredAtMs: 1000);

  check(AnchorPolicy.decide(last: null, size: 5, root: 'ROOT5').verdict ==
      AnchorVerdict.append, '首条锚定 → append（创世）');
  check(AnchorPolicy.decide(last: base, size: 7, root: 'ROOT7').verdict ==
      AnchorVerdict.append, '规模前进 5→7 → append');
  check(AnchorPolicy.decide(last: base, size: 3, root: 'ROOT3').verdict ==
      AnchorVerdict.rollback, '规模倒退 5→3 → rollback（截断被拦）');
  check(AnchorPolicy.decide(last: base, size: 5, root: 'ROOT5').verdict ==
      AnchorVerdict.duplicate, '同期同根 → duplicate（幂等，不重复写）');
  check(AnchorPolicy.decide(last: base, size: 5, root: 'OTHER').verdict ==
      AnchorVerdict.fork, '同期换根 → fork（改写被拦）');
  check(AnchorPolicy.decide(last: base, size: -1, root: 'R').verdict ==
      AnchorVerdict.invalid, '负规模 → invalid');
  check(AnchorPolicy.decide(last: base, size: 6, root: '').verdict ==
      AnchorVerdict.invalid, '空根 → invalid');

  check(!AnchorPolicy.decide(last: base, size: 3, root: 'ROOT3').acceptable,
      'rollback 不是可接受状态（fail-closed）');
  check(!AnchorPolicy.decide(last: base, size: 5, root: 'OTHER').acceptable,
      'fork 不是可接受状态（fail-closed）');

  // ---------------------------------------------------------------------
  print('--- 序列自检 ---');
  final good = [
    LogAnchor(size: 1, root: 'R1', anchoredAtMs: 1000),
    LogAnchor(size: 3, root: 'R3', anchoredAtMs: 2000),
    LogAnchor(size: 7, root: 'R7', anchoredAtMs: 3000),
  ];
  check(AnchorPolicy.validateSeries(good) == null, '正常递增序列 → 通过');
  check(
      AnchorPolicy.validateSeries([
        LogAnchor(size: 7, root: 'R7', anchoredAtMs: 3000),
        LogAnchor(size: 3, root: 'R3', anchoredAtMs: 4000),
      ]) !=
          null,
      '规模倒退的序列 → 被拒');
  check(
      AnchorPolicy.validateSeries([
        LogAnchor(size: 5, root: 'R5', anchoredAtMs: 1000),
        LogAnchor(size: 5, root: 'R5x', anchoredAtMs: 2000),
      ]) !=
          null,
      '同期换根的序列 → 被拒');
  check(
      AnchorPolicy.validateSeries([
        LogAnchor(size: 1, root: 'R1', anchoredAtMs: 3000),
        LogAnchor(size: 2, root: 'R2', anchoredAtMs: 1000),
      ]) !=
          null,
      '时间戳倒退的序列 → 被拒');
  check(AnchorPolicy.validateSeries([]) == null, '空序列 → 通过（尚无锚定）');

  // ---------------------------------------------------------------------
  print('--- JSONL 往返 ---');
  final a = LogAnchor(size: 9, root: 'RRR', anchoredAtMs: 1234567890, note: '周例行');
  final back = LogAnchor.parseJsonl(a.toJsonl())!;
  check(back.size == a.size && back.root == a.root && back.anchoredAtMs == a.anchoredAtMs && back.note == a.note,
      '序列化 → 反序列化字段一致');
  final series = LogAnchor.seriesFromJsonl('${good[0].toJsonl()}\n\n${good[1].toJsonl()}\n');
  check(series.length == 2, '解析 JSONL 忽略空行（2 条）');

  // ---------------------------------------------------------------------
  print('--- 收据（供 GitHub 签名提交）---');
  final receipt = AnchorReceipt.build(anchor: a, prevRoot: 'PREV');
  check(receipt.contains('tree_size    : 9'), '收据含 tree_size');
  check(receipt.contains('merkle_root  : RRR'), '收据含 merkle_root');
  check(receipt.contains('prev_root    : PREV'), '收据含 prev_root');
  check(AnchorReceipt.build(anchor: a).contains('(genesis)'),
      '首条锚定的 prev_root 标为 (genesis)');

  // ---------------------------------------------------------------------
  print('--- 与 Merkle 层打通：锚定 + 一致性证明 ---');
  final log = await buildLog(_ctLeaves); // 7 片
  final r3 = await log.rootAt(3);
  final r7 = await log.root();

  final a3 = LogAnchor(size: 3, root: r3, anchoredAtMs: 1000);
  final a7 = LogAnchor(size: 7, root: r7, anchoredAtMs: 2000);
  check(AnchorPolicy.sizesConnectable(a3, a7), '锚定 3 → 7 在规模上可连接');
  final proof37 = await log.consistencyProof(3, 7);
  check(await MerkleVerify.consistency(proof: proof37, fromRoot: r3, toRoot: r7),
      '(3,7) 一致性证明通过 —— 锚定 #1 确实是锚定 #0 的前缀延续');

  // 篡改：把 7 期的根换成"3 期的根"，一致性证明必须过不了
  check(
      !await MerkleVerify.consistency(proof: proof37, fromRoot: r3, toRoot: r3),
      '把 to_root 填成旧根 → 一致性证明过不了（伪造锚定被拦）');

  // ---------------------------------------------------------------------
  print('--- 关键演示：哈希链查不出截断，锚定能 ---');
  final truncated = await buildLog(_ctLeaves.sublist(0, 3)); // 攻击者砍掉尾部 4 片
  check(await truncated.verifyChain(),
      '（前提）被截断的 3 片日志 verifyChain() 仍然是 true —— 哈希链原理上查不出截断');
  check(await truncated.root() == r3,
      '（前提）被截断日志的根 == 真树在 size=3 时的根（前缀稳定）');
  // 但外部锚定记录着"我见过 size=7"：
  final decision = AnchorPolicy.decide(
      last: a7, size: 3, root: await truncated.root());
  check(decision.verdict == AnchorVerdict.rollback,
      '把截断后的日志拿去对比"锚过的 size=7" → rollback（锚定补上了哈希链的洞）');

  // ---------------------------------------------------------------------
  print('--- 端到端：锚定序列 + 每段一致性证明全通过 ---');
  final anchors = [
    LogAnchor(size: 1, root: await log.rootAt(1), anchoredAtMs: 1000),
    LogAnchor(size: 3, root: r3, anchoredAtMs: 2000),
    LogAnchor(size: 5, root: await log.rootAt(5), anchoredAtMs: 3000),
    LogAnchor(size: 7, root: r7, anchoredAtMs: 4000),
  ];
  check(AnchorPolicy.validateSeries(anchors) == null, '完整锚定序列自检通过');
  var chainOk = true;
  for (var i = 1; i < anchors.length; i++) {
    final p = await log.consistencyProof(anchors[i - 1].size, anchors[i].size);
    final ok = await MerkleVerify.consistency(
        proof: p, fromRoot: anchors[i - 1].root, toRoot: anchors[i].root);
    if (!ok) {
      chainOk = false;
      print('        ✗ #${i - 1}→#$i');
    }
  }
  check(chainOk, '全部相邻锚定之间的一致性证明都验得过（一条连续历史）');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
