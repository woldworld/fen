// 纯 Dart 校验脚本：M10「分享成长红利的五件套」——
// ① 创始成员 / ② 永久价格锁定 / ③ 贡献声望 / ⑤ 可验证贡献账本。
// 运行：dart run tool/verify_contribution_ledger.dart
//
// 为什么值得单独一个脚本：
//   这一套之所以合法，**完全**建立在"它不是证券"上（PRD §9.1 红线）。
//   而"不是证券"不是一句声明 —— 它必须体现为**结构上做不到**：
//   ① 三张表里没有任何一列能被解释成"转让 / 兑现 / 收益"；
//   ② 声望分**不落库**（派生值），存储层根本没有写分数的入口；
//   ③ 公开 API 里没有任何 `transfer*` / `redeem*` / `payout*` 方法。
//   本脚本对这三条下**源码级断言** —— 想违反红线，得先改代码并让本脚本变红。
//
// 第二部分盯的是"可验证"本身：同一件事不得重复计分（幂等键去重）、
// 按类型封顶让刷量**结构上不涨**、以及贡献叶子确实进了 **§16 那同一棵树**。

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/contribution_ledger.dart';
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

/// 剥掉注释再扫源码（本项目正文刻意引用旧写法作反面教材）。
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

/// 从 DDL 抠列名。
Set<String> _ddlColumns(String src, String table) {
  final m = RegExp('CREATE TABLE IF NOT EXISTS $table\\(([\\s\\S]*?)\\n\\s*\\)')
      .firstMatch(src);
  if (m == null) return <String>{};
  final cols = <String>{};
  for (final raw in m.group(1)!.split('\n')) {
    final line = raw.trim().replaceAll(',', '');
    if (line.isEmpty) continue;
    final first = line.split(RegExp(r'\s+')).first;
    if (first.toUpperCase() == 'PRIMARY') continue;
    cols.add(first.toLowerCase());
  }
  return cols;
}

Future<ContributionRecord> _signedRecord(
  String attestorPub,
  Future<String> Function(List<int>) sign, {
  required String subjectPub,
  required String kind,
  required String ref,
  int? atMs,
  String note = '',
}) async {
  final r = ContributionRecord(
    subjectPub: subjectPub,
    attestorPub: attestorPub,
    kind: kind,
    ref: ref,
    weight: ContributionKind.weightOf(kind),
    atMs: atMs ?? kNow,
    note: note,
  );
  return r.copyWith(sig: await sign(r.canonicalBytes()));
}

Future<void> main() async {
  final alice = await _newKey(); // 贡献者
  final bob = await _newKey(); // 邀请来的朋友（关系型贡献的证明人）
  final carol = await _newKey(); // 另一个朋友
  final platform = await _newKey(); // 平台（定价权签发人）

  // =========================================================================
  print('--- ① 贡献记录验签：fail-closed 的每一条拒绝路径 ---');
  // =========================================================================
  final good = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub, kind: ContributionKind.invite, ref: bob.pub);
  check((await ContributionLedger.verify(good)).accept, '合法记录 → accept');

  final noSig = ContributionRecord(
    subjectPub: alice.pub,
    attestorPub: bob.pub,
    kind: ContributionKind.invite,
    ref: bob.pub,
    weight: ContributionKind.weightOf(ContributionKind.invite),
    atMs: kNow,
  );
  check(
      (await ContributionLedger.verify(noSig)).code ==
          ContributionCode.missingFields,
      '空签名 → missing_fields');

  final badPub = ContributionRecord(
    subjectPub: 'not-a-key',
    attestorPub: good.attestorPub,
    kind: good.kind,
    ref: good.ref,
    weight: good.weight,
    atMs: kNow,
    sig: good.sig,
  );
  check(
      (await ContributionLedger.verify(badPub)).code ==
          ContributionCode.badPubkey,
      '非法公钥 → bad_pubkey');

  final badKind = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub, kind: ContributionKind.invite, ref: 'x');
  check(
      (await ContributionLedger.verify(ContributionRecord(
        subjectPub: badKind.subjectPub,
        attestorPub: badKind.attestorPub,
        kind: 'nonsense_kind',
        ref: badKind.ref,
        weight: ContributionKind.weightOf(ContributionKind.invite),
        atMs: kNow,
        sig: badKind.sig,
      )))
              .code ==
          ContributionCode.badKind,
      '未知类型 → bad_kind');

  final noRef = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub, kind: ContributionKind.invite, ref: '');
  check(
      (await ContributionLedger.verify(noRef)).code == ContributionCode.badRef,
      '对象型贡献缺引用对象 → bad_ref');

  // ★ 关系型贡献自报无效（先于验签）
  final selfClaim = await _signedRecord(alice.pub, alice.sign,
      subjectPub: alice.pub, kind: ContributionKind.invite, ref: carol.pub);
  check(
      (await ContributionLedger.verify(selfClaim)).code ==
          ContributionCode.selfAttestation,
      '邀请（关系型）自报 → self_attestation（拒）');

  final selfHost = await _signedRecord(alice.pub, alice.sign,
      subjectPub: alice.pub, kind: ContributionKind.host, ref: 'EVT-1');
  check(
      (await ContributionLedger.verify(selfHost)).code ==
          ContributionCode.selfAttestation,
      '主持（关系型）自报 → self_attestation（拒）');

  // 对象型允许自签（平台已有独立物证）
  final selfSkill = await _signedRecord(alice.pub, alice.sign,
      subjectPub: alice.pub, kind: ContributionKind.skill, ref: 'SK-1');
  check((await ContributionLedger.verify(selfSkill)).accept,
      '技能上架（对象型）自签 → accept（清单由作者签名，非空口）');

  // 改分值 → 先被"法定分值"拦下
  final tampered = ContributionRecord(
    subjectPub: good.subjectPub,
    attestorPub: good.attestorPub,
    kind: good.kind,
    ref: good.ref,
    weight: 9999,
    atMs: good.atMs,
    sig: good.sig,
  );
  check(
      (await ContributionLedger.verify(tampered)).code ==
          ContributionCode.badWeight,
      '把分值改成 9999 → bad_weight');

  // 改引用对象 → 验签失败（签名覆盖 ref）
  final refSwapped = ContributionRecord(
    subjectPub: good.subjectPub,
    attestorPub: good.attestorPub,
    kind: good.kind,
    ref: carol.pub,
    weight: good.weight,
    atMs: good.atMs,
    sig: good.sig,
  );
  check(
      (await ContributionLedger.verify(refSwapped)).code ==
          ContributionCode.badSignature,
      '事后换引用对象 → bad_signature');

  // 换主体 → 验签失败（签名覆盖 subject）。
  // ⚠️ 换成 carol 而不是 bob：若换成 bob（= attestor），会先被
  //    "关系型贡献自报无效"拦下，测的就变成前一条规则了。
  final subjectSwapped = ContributionRecord(
    subjectPub: carol.pub,
    attestorPub: good.attestorPub,
    kind: good.kind,
    ref: good.ref,
    weight: good.weight,
    atMs: good.atMs,
    sig: good.sig,
  );
  check(
      (await ContributionLedger.verify(subjectSwapped)).code ==
          ContributionCode.badSignature,
      '事后换贡献主体 → bad_signature');

  final tooLongNote = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.invite,
      ref: 'Z',
      note: 'x' * (ContributionCaps.maxNoteChars + 1));
  check(
      (await ContributionLedger.verify(tooLongNote)).code ==
          ContributionCode.noteTooLong,
      '附言超长 → note_too_long（不截断，直接拒）');

  final zeroAt = ContributionRecord(
    subjectPub: good.subjectPub,
    attestorPub: good.attestorPub,
    kind: good.kind,
    ref: good.ref,
    weight: good.weight,
    atMs: 0,
    sig: good.sig,
  );
  check(
      (await ContributionLedger.verify(zeroAt)).code ==
          ContributionCode.badWindow,
      '时间戳为 0 → bad_window');

  // =========================================================================
  print('--- ③ 计分：幂等键去重 + 按类型封顶（刷量结构上不涨）---');
  // =========================================================================
  final r1 = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub, kind: ContributionKind.invite, ref: bob.pub);
  // 同一件事的两个不同时间戳 —— 幂等键不含时间，故必须只算一次
  final r1dup = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.invite,
      ref: bob.pub,
      atMs: kNow + 1000);
  check(r1.key == r1dup.key, '幂等键**不含时间戳** → 换个时间重签仍是同一件事');

  final r2 = await _signedRecord(carol.pub, carol.sign,
      subjectPub: alice.pub, kind: ContributionKind.invite, ref: carol.pub);
  final s2 = ContributionLedger.tally([r1, r1dup, r2]);
  check(s2.total == 4, '两条不同邀请（各 2 分），重复项被去重 → total=4');
  check(s2.duplicates == 1, '重复上报被记为 duplicates=1');
  check(s2.records == 2, '计入分值的记录条数 = 2');

  // 封顶：invite 上限 200，刷 2000 条也只到 200
  final many = <ContributionRecord>[];
  for (var i = 0; i < 2000; i++) {
    many.add(await _signedRecord(bob.pub, bob.sign,
        subjectPub: alice.pub,
        kind: ContributionKind.invite,
        ref: 'friend-$i'));
  }
  final sCap = ContributionLedger.tally(many);
  check(sCap.byKind[ContributionKind.invite] == 200,
      '邀请刷 2000 条 → 封顶在 200（刷量结构上不涨）');
  check(sCap.rawByKind[ContributionKind.invite] == 4000,
      '封顶前原始累计仍如实保留（4000），不被抹掉');
  check(sCap.capped(ContributionKind.invite), 'capped(invite) → true（可解释"为何不涨"）');
  check(sCap.total == 200, '总分 = 封顶后的 200');

  // 非法记录不得计分（计分口径不依赖调用方先验签）
  final sBad = ContributionLedger.tally([
    ContributionRecord(
      subjectPub: alice.pub,
      attestorPub: bob.pub,
      kind: ContributionKind.invite,
      ref: 'bad',
      weight: 9999,
      atMs: kNow,
    ),
  ]);
  check(sBad.total == 0, '分值不符的记录被计分层二次过滤 → 计 0 分');

  check(
      ContributionLedger.ofSubject([r1, r2], alice.pub).length == 2 &&
          ContributionLedger.ofSubject([r1, r2], bob.pub).isEmpty,
      'ofSubject 只挑出属于该公钥的记录');

  // =========================================================================
  print('--- ③b 上限的**边界**与不变量（防 off-by-one / 防"新类型漏配上上限"）---');
  // =========================================================================
  // ① 每个合法类型都必须有 >0 的上限。
  //    若某类型漏配 perKindCap → capOf 返回 0 → 该类型**永远 0 分**：
  //    fail-closed 但**静默**（编译不报、单测若不查也不报，只表现为"某种贡献怎么都不涨分"）。
  final kindNoCap = [
    for (final k in ContributionKind.values)
      if (ContributionCaps.capOf(k) <= 0) k
  ];
  check(kindNoCap.isEmpty,
      '每种贡献类型都配了 >0 的上限（漏配=${kindNoCap.isEmpty ? '无' : kindNoCap.join(',')}）');

  final kindNoWeight = [
    for (final k in ContributionKind.values)
      if (ContributionKind.weightOf(k) <= 0) k
  ];
  check(kindNoWeight.isEmpty, '每种贡献类型都有 >0 的分值（不存在"零分类型"）');

  check(ContributionCaps.capOf('nonsense_kind') == 0,
      '未知类型的上限 = 0（fail-closed：未知类型拿不到分）');

  // 创始成员的特殊语义：上限 == 单条分值（终身只可能有一条，上限即那一条）
  check(
      ContributionCaps.capOf(ContributionKind.founding) ==
          ContributionKind.weightOf(ContributionKind.founding),
      'founding 的上限 == 单条分值（"终身一条"由上限直接体现）');

  // ② 封顶的**两条边界**：恰好到顶不算超、超一条才算超（off-by-one 只有边界能照出）
  final invW = ContributionKind.weightOf(ContributionKind.invite); // 2
  final invCap = ContributionCaps.capOf(ContributionKind.invite); // 200
  final exactTop = invCap ~/ invW; // 100 条正好到顶
  final atCap = <ContributionRecord>[];
  for (var i = 0; i < exactTop; i++) {
    atCap.add(await _signedRecord(bob.pub, bob.sign,
        subjectPub: alice.pub, kind: ContributionKind.invite, ref: 'edge-$i'));
  }
  final sAtCap = ContributionLedger.tally(atCap);
  check(
      sAtCap.byKind[ContributionKind.invite] == invCap &&
          !sAtCap.capped(ContributionKind.invite),
      '★ 恰好到顶（$exactTop 条 × $invW = $invCap）**不算**超顶：capped=false');

  final overCap = [
    ...atCap,
    await _signedRecord(bob.pub, bob.sign,
        subjectPub: alice.pub, kind: ContributionKind.invite, ref: 'edge-over'),
  ];
  final sOver = ContributionLedger.tally(overCap);
  check(
      sOver.byKind[ContributionKind.invite] == invCap &&
          sOver.rawByKind[ContributionKind.invite] == invCap + invW &&
          sOver.capped(ContributionKind.invite),
      '★ 超一条（${exactTop + 1} 条 = ${invCap + invW}）**才**封顶：'
      'byKind=$invCap / raw=${invCap + invW} / capped=true');

  // ③ 多类型**各自**封顶：total == 各类型封顶值之和（不是"共用一个全局额度池"）
  final circleCap = ContributionCaps.capOf(ContributionKind.circle); // 60
  final multi = <ContributionRecord>[...overCap]; // invite 已超顶
  for (var i = 0; i < 25; i++) {
    // circle 是**对象型**贡献，允许自签（平台已有独立物证），故用 alice 自签即可
    multi.add(await _signedRecord(alice.pub, alice.sign,
        subjectPub: alice.pub, kind: ContributionKind.circle, ref: 'C-$i'));
  }
  final sMulti = ContributionLedger.tally(multi);
  check(
      sMulti.capped(ContributionKind.invite) &&
          sMulti.capped(ContributionKind.circle),
      'invite 与 circle 两类**各自独立**封顶（不是共用一个额度池）');
  check(sMulti.total == invCap + circleCap,
      '★ total = 各类型封顶值之和（$invCap + $circleCap = ${invCap + circleCap}）');
  final rawSum =
      sMulti.rawByKind.values.fold<int>(0, (a, b) => a + b);
  check(sMulti.total < rawSum,
      '封顶后总分**严格小于**原始累计（$rawSum → ${sMulti.total}，差值即"被上限削掉的部分"）');

  // ④ 幂等键的**区分度**：kind / subject / ref 任一不同 → 键必须不同
  //    （否则"换个类型/换个人"就能顶掉别人的贡献，或两类贡献互相覆盖）
  final kBase = r1.key;
  final kOtherKind = (await _signedRecord(bob.pub, bob.sign,
          subjectPub: alice.pub,
          kind: ContributionKind.circle,
          ref: r1.ref))
      .key;
  final kOtherSubject = (await _signedRecord(bob.pub, bob.sign,
          subjectPub: carol.pub,
          kind: ContributionKind.invite,
          ref: r1.ref))
      .key;
  final kOtherRef = (await _signedRecord(bob.pub, bob.sign,
          subjectPub: alice.pub,
          kind: ContributionKind.invite,
          ref: 'other-ref'))
      .key;
  check(kBase != kOtherKind && kBase != kOtherSubject && kBase != kOtherRef,
      '★ 幂等键由 (kind, subject, ref) 共同决定：任一不同 → 键必不同');

  // ⑤ 长度/时间**上下界的"以内一侧"**必须收（只测"超了就拒"测不出"误拒合法输入"）
  final noteAtMax = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.invite,
      ref: 'NOTE-EDGE',
      note: 'n' * ContributionCaps.maxNoteChars);
  check(
      (await ContributionLedger.verify(noteAtMax)).accept,
      '附言恰好 ${ContributionCaps.maxNoteChars} 字符 → accept（边界以内不误拒）');

  final refAtMax = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.invite,
      ref: 'r' * ContributionCaps.maxRefChars);
  check(
      (await ContributionLedger.verify(refAtMax)).accept,
      '引用对象恰好 ${ContributionCaps.maxRefChars} 字符 → accept（边界以内不误拒）');

  final refTooLong = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.invite,
      ref: 'r' * (ContributionCaps.maxRefChars + 1));
  check(
      (await ContributionLedger.verify(refTooLong)).code ==
          ContributionCode.badRef,
      '引用对象超一个字符（${ContributionCaps.maxRefChars + 1}）→ bad_ref（上限真的在生效）');

  final atOne = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.invite,
      ref: 'AT-EDGE',
      atMs: 1);
  check((await ContributionLedger.verify(atOne)).accept,
      '时间戳 = 1（下界之上一个单位）→ accept');

  final atNegative = ContributionRecord(
    subjectPub: alice.pub,
    attestorPub: bob.pub,
    kind: ContributionKind.invite,
    ref: 'AT-NEG',
    weight: ContributionKind.weightOf(ContributionKind.invite),
    atMs: -1,
    sig: 'x',
  );
  check(
      (await ContributionLedger.verify(atNegative)).code ==
          ContributionCode.badWindow,
      '时间戳 = -1 → bad_window（下界是"严格大于 0"，负值一并拒）');

  // =========================================================================
  print('--- ① 创始成员声明（自签 + 绑定承诺版本）---');
  // =========================================================================
  final fd = FoundingDeclaration(subjectPub: alice.pub, declaredAtMs: kNow);
  final fdSigned = fd.copyWith(sig: await alice.sign(fd.canonicalBytes()));
  check((await ContributionLedger.verifyFounding(fdSigned)).accept,
      '本人自签的创始声明 → accept');

  final fdBadPledge = FoundingDeclaration(
      subjectPub: alice.pub, declaredAtMs: kNow, pledgeId: 'wrong_version');
  final fdBadPledgeSigned =
      fdBadPledge.copyWith(sig: await alice.sign(fdBadPledge.canonicalBytes()));
  check(
      (await ContributionLedger.verifyFounding(fdBadPledgeSigned)).code ==
          ContributionCode.badPledge,
      '承诺版本不符 → bad_pledge（签名绑定的必须是当前生效的那份）');

  // 用别人的私钥签 → 拒（创始声明必须是本人签的）
  final fdStolen = fd.copyWith(sig: await bob.sign(fd.canonicalBytes()));
  check(
      (await ContributionLedger.verifyFounding(fdStolen)).code ==
          ContributionCode.badSignature,
      '拿别人的私钥签创始声明 → bad_signature');

  check(FoundingPledge.forbidden.contains('transferable') &&
          FoundingPledge.forbidden.contains('redeemable') &&
          FoundingPledge.forbidden.contains('profit_linked') &&
          FoundingPledge.forbidden.contains('voting_binding'),
      '承诺明文禁止四件事：可转让 / 可兑现 / 与利润挂钩 / 投票有约束力');

  // =========================================================================
  print('--- ② 永久价格锁定（平台签发给用户，是定价权不是证券）---');
  // =========================================================================
  final lock = PriceLockClaim(
    issuerPub: platform.pub,
    subjectPub: alice.pub,
    scope: PriceLockScope.hostFee,
    discountBps: 3000,
    effectiveFromMs: kNow,
  );
  final lockSigned = lock.copyWith(sig: await platform.sign(lock.canonicalBytes()));
  check((await ContributionLedger.verifyPriceLock(lockSigned)).accept,
      '平台签发的定价权 → accept');
  check(lockSigned.effectiveDiscountBps == 3000, '折扣率 = 3000 bps（打七折）');

  final waiver = PriceLockClaim(
    issuerPub: platform.pub,
    subjectPub: alice.pub,
    scope: PriceLockScope.serviceFee,
    discountBps: 0,
    feeWaived: true,
    effectiveFromMs: kNow,
  );
  final waiverSigned =
      waiver.copyWith(sig: await platform.sign(waiver.canonicalBytes()));
  check((await ContributionLedger.verifyPriceLock(waiverSigned)).accept,
      '服务费全免（fee_waived）→ accept');
  check(waiverSigned.effectiveDiscountBps == 10000, '全免等价于 10000 bps');

  final selfIssue = PriceLockClaim(
    issuerPub: platform.pub,
    subjectPub: platform.pub,
    scope: PriceLockScope.hostFee,
    discountBps: 3000,
    effectiveFromMs: kNow,
  );
  check(
      (await ContributionLedger.verifyPriceLock(
              selfIssue.copyWith(sig: await platform.sign(selfIssue.canonicalBytes()))))
              .code ==
          ContributionCode.selfIssuance,
      '平台给自己发定价权 → self_issuance（拒）');

  final badScope = PriceLockClaim(
    issuerPub: platform.pub,
    subjectPub: alice.pub,
    scope: 'everything',
    discountBps: 3000,
    effectiveFromMs: kNow,
  );
  check(
      (await ContributionLedger.verifyPriceLock(
              badScope.copyWith(sig: await platform.sign(badScope.canonicalBytes()))))
              .code ==
          ContributionCode.badScope,
      '作用域非法 → bad_scope（模糊的"免一切费用"写不进去）');

  final badDisc = PriceLockClaim(
    issuerPub: platform.pub,
    subjectPub: alice.pub,
    scope: PriceLockScope.hostFee,
    discountBps: 10001,
    effectiveFromMs: kNow,
  );
  check(
      (await ContributionLedger.verifyPriceLock(
              badDisc.copyWith(sig: await platform.sign(badDisc.canonicalBytes()))))
              .code ==
          ContributionCode.badDiscount,
      '折扣 > 10000 bps → bad_discount');

  final empty = PriceLockClaim(
    issuerPub: platform.pub,
    subjectPub: alice.pub,
    scope: PriceLockScope.hostFee,
    discountBps: 0,
    effectiveFromMs: kNow,
  );
  check(
      (await ContributionLedger.verifyPriceLock(
              empty.copyWith(sig: await platform.sign(empty.canonicalBytes()))))
              .code ==
          ContributionCode.emptyClaim,
      '既不免费又零折扣 → empty_claim（空壳定价权不收）');

  // 把定价权当贡献记录验 → 载荷 kind 不同，必拒
  final crossKind = ContributionRecord(
    subjectPub: lock.subjectPub,
    attestorPub: lock.issuerPub,
    kind: ContributionKind.invite,
    ref: lock.scope,
    weight: ContributionKind.weightOf(ContributionKind.invite),
    atMs: lock.effectiveFromMs,
    sig: lockSigned.sig,
  );
  check(
      (await ContributionLedger.verify(crossKind)).code ==
          ContributionCode.badSignature,
      '拿定价权签名冒充贡献记录 → bad_signature（kind 入载荷的作用）');

  // =========================================================================
  print('--- ⑤ §16 合流：贡献叶子进的是**同一棵**树 ---');
  // =========================================================================
  final log = TransparencyLog();
  final contribLeaves = <String>[];
  for (final r in [good, r2, selfSkill]) {
    final h = await TransparencyLog.leafHashOf(r.logLeafBytes());
    contribLeaves.add(h);
    await log.appendLeafHash(h);
  }
  // 一个"互介记录"的叶子（另一类业务），证明两类叶子共处一棵树
  final otherLeaf = await TransparencyLog.leafHashOf(utf8.encode('intro|X|Y'));
  await log.appendLeafHash(otherLeaf);

  check(log.size == 4, '贡献 3 片 + 互介 1 片 → 同树共 4 片（§16.1 合流）');
  check(await log.verifyChain(), '混合了两类叶子的链自检仍为 true');

  // 叶子哈希确定性：同一记录两次算出的哈希必须一致（第三方要能独立复算）
  final h1 = await TransparencyLog.leafHashOf(good.logLeafBytes());
  final h2 = await TransparencyLog.leafHashOf(good.logLeafBytes());
  check(h1 == h2, '同一记录的叶子哈希可确定性复算');

  // 附言不进叶子（公开账本只承载"谁做了什么"，不承载自由文本）
  final withNote = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.invite,
      ref: bob.pub,
      note: 'secret-note');
  check(!utf8.decode(withNote.logLeafBytes()).contains('secret-note'),
      '自由文本附言**不进**公开叶子字节（公开账本不带 PII）');

  final proof = await log.inclusionProof(0);
  final root = await log.root();
  check(
      await MerkleVerify.inclusion(
          leaf: good.logLeafBytes(), proof: proof, root: root),
      '贡献叶子 #0 的包含证明可验（第三方现场复算）');

  final badProof = MerkleProof(
      index: proof.index, treeSize: proof.treeSize, path: proof.path.sublist(1));
  check(
      !await MerkleVerify.inclusion(
          leaf: good.logLeafBytes(), proof: badProof, root: root),
      '截断一条路径 → 包含证明必然失败（fail-closed）');

  // 自己算一遍叶子哈希，必须与日志里的第 0 片逐字节相同
  check(contribLeaves[0] == log.leafHashes[0],
      '独立复算的第 0 片叶子哈希 == 日志中的第 0 片（字节级一致）');

  final ledgerOk = await ContributionLedger.verifyLedger([good, r2, selfSkill]);
  check(ledgerOk.ok && ledgerOk.badIndex == -1, '整本账自检 → ok');

  final ledgerBad =
      await ContributionLedger.verifyLedger([good, tampered, selfSkill]);
  check(!ledgerBad.ok && ledgerBad.badIndex == 1,
      '夹一条被改分的记录 → 整本账判不可出示，并指出下标 1');

  // =========================================================================
  print('--- 红线（PRD §9.1）：结构上做不到"转让 / 兑现 / 与利润挂钩" ---');
  // =========================================================================
  final dbSrc = _stripComments(File('lib/core/db_helper.dart').readAsStringSync());
  const t1 = 'contribution_records';
  const t2 = 'founding_members';
  const t3 = 'price_lock_claims';
  final c1 = _ddlColumns(dbSrc, t1);
  final c2 = _ddlColumns(dbSrc, t2);
  final c3 = _ddlColumns(dbSrc, t3);
  check(c1.isNotEmpty && c2.isNotEmpty && c3.isNotEmpty,
      'v32 三张表都能从 DDL 抠出列清单（迁移真的存在）');

  // 任何一列都不允许表达"转让 / 兑现 / 收益 / 面值 / 二级持有人"
  const forbiddenCols = [
    'owner_id', 'to_pub', 'receiver_pub', 'beneficiary', 'transfer',
    'transferable', 'redeem', 'redeem_at', 'cashout', 'cash_out', 'payout',
    'price_cents', 'face_value', 'yield', 'dividend', 'equity', 'shares',
    'sellable', 'resale', 'liquidate',
  ];
  final allCols = {...c1, ...c2, ...c3};
  final hitCols = [
    for (final f in forbiddenCols)
      if (allCols.any((c) => c.contains(f))) f
  ];
  check(hitCols.isEmpty,
      '三张表无任何"转让/兑现/收益"列（命中=${hitCols.isEmpty ? '无' : hitCols.join(',')}）');

  // 主键即不变式：同一件事写不进第二条
  check(c1.contains('kind') && c1.contains('subject_pub') && c1.contains('ref'),
      'contribution_records 有 (kind, subject_pub, ref) → 幂等键由主键兜住');
  check(c1.contains('weight') && c1.contains('sig'),
      'contribution_records 的分值在列里（签名覆盖 → 事后改分必被验签拦下）');
  check(c2.contains('pledge'), 'founding_members 有 pledge 列（绑定承诺版本）');
  check(c3.contains('discount_bps') && c3.contains('fee_waived') &&
          c3.contains('scope'),
      'price_lock_claims 只有定价维度（作用域 / 折扣 / 是否全免）');

  // 声望分不得落库：不存在"分数表 / 余额表"
  final hasScoreTable = RegExp(
          r'CREATE TABLE IF NOT EXISTS \w*(score|balance|points|balance_sheet)\w*')
      .hasMatch(dbSrc);
  check(!hasScoreTable, '没有"分数/余额"表 → 声望分只能由记录现算（派生值无处转让）');

  // API 层：不得出现 transfer*/redeem*/payout*/cashout*/sell* 方法
  final apiSrc =
      _stripComments(File('lib/core/contribution_ledger.dart').readAsStringSync());
  final storeSrc = _stripComments(
      File('lib/core/contribution_store_db.dart').readAsStringSync());
  final apiPat = RegExp(
      r'\b(transfer|redeem|cashout|cash_out|payout|liquidate|sell|burn)[A-Za-z_]*\s*\(',
      caseSensitive: false);
  final apiHit = apiPat.firstMatch(apiSrc);
  final storeHit = apiPat.firstMatch(storeSrc);
  check(apiHit == null, 'contribution_ledger.dart 无转让/兑现类方法（${apiHit?.group(0) ?? '无'}）');
  check(storeHit == null,
      'contribution_store_db.dart 无转让/兑现类方法（${storeHit?.group(0) ?? '无'}）');

  final noSetScore = !RegExp(r'\b(setScore|addScore|writeScore|incScore)\s*\(')
      .hasMatch(apiSrc + storeSrc);
  check(noSetScore, '存储层没有"写分数"的入口 —— 没有入口就写不出转账');

  // 存储抽象里也不得有转让方法（抽象层不给口子，实现层就写不出）
  final storeAbs = RegExp(r'abstract class ContributionStore\s*\{([\s\S]*?)\n\}')
      .firstMatch(apiSrc);
  check(
      storeAbs != null &&
          !RegExp(r'\b(transfer|redeem|payout|sell)', caseSensitive: false)
              .hasMatch(storeAbs.group(1)!),
      'ContributionStore 抽象接口里无转让/兑现方法');

  // =========================================================================
  print('--- 埋点名一致性 / schemaVersion / 装配 ---');
  // =========================================================================
  const evPairs = <String, String>{
    'contributionRecordAccepted': ContributionEvents.recordAccepted,
    'contributionRecordRejected': ContributionEvents.recordRejected,
    'contributionFoundingDeclared': ContributionEvents.foundingDeclared,
    'contributionPriceLockGranted': ContributionEvents.priceLockGranted,
    'contributionScoreQueried': ContributionEvents.scoreQueried,
    'contributionLogAppendFailed': ContributionEvents.logAppendFailed,
  };
  final telSrc = File('lib/core/telemetry.dart').readAsStringSync();
  var evOk = true;
  final evBad = <String>[];
  for (final e in evPairs.entries) {
    if (!telSrc.contains("${e.key} = '${e.value}'")) {
      evOk = false;
      evBad.add(e.key);
    }
  }
  check(evOk, 'TelemetryEvents 与 ContributionEvents 字面量一一对应（漏=${evBad.join(',')})');

  // 五件套的事件前缀统一为 contribution_
  var prefixOk = true;
  for (final v in evPairs.values) {
    if (!v.startsWith('contribution_')) prefixOk = false;
  }
  check(prefixOk, '五件套事件名统一 contribution_ 前缀（便于按前缀切口径）');

  // 版本号会随迭代上抬，这里**不再写死数字**：读当前声明值，
  // 再校验「声明值 ↔ 迁移表项」自洽，且账本自己的 V32 迁移必须在。
  final mVer = RegExp(r'schemaVersion = (\d+)').firstMatch(dbSrc);
  final curVer = mVer == null ? -1 : int.parse(mVer.group(1)!);
  final versionOk = curVer >= 33 &&
      RegExp('32: _migrateV32').hasMatch(dbSrc) &&
      RegExp('$curVer: _migrateV${curVer}').hasMatch(dbSrc);
  check(versionOk,
      'schemaVersion=$curVer(>=33)、迁移表挂了 V32 且声明值与 _migrateV$curVer 自洽');

  final runtimeSrc = File('lib/core/wold_runtime.dart').readAsStringSync();
  check(
      runtimeSrc.contains('contributionStore = DbContributionStore()') &&
          runtimeSrc.contains('onAppend: _appendContributionToLog'),
      'WoldRuntime 装配了贡献账本，且 onAppend 指向日志追加');
  check(
      RegExp(r'contributions = ContributionService\([\s\S]{0,200}?onAppend: _appendContributionToLog')
          .hasMatch(runtimeSrc),
      '贡献服务与 §16 共用同一个 transparency 实例（不另建树）');

  // 与 §16 的"日志失败不阻断记账"纪律一致
  check(
      runtimeSrc.contains('contribution_log_append_failed'),
      '日志追加失败留痕（不阻断记账，下次幂等补上）');

  // =========================================================================
  print('--- 跨语言探针（供 tool/smoke_log_hub.js 比对，防 Dart/JS 键序漂移）---');
  // =========================================================================
  // 为什么必须做这一层：Dart `jsonEncode` 与 JS `JSON.stringify` 都产出无空格 JSON，
  // 但**键序取决于插入顺序**。两端键序一旦不同，就会出现
  // "客户端合法签的记录，Hub 一律拒" —— 而这在单语言测试里照不出来。
  // 所以这里把 Dart 端算出的 canonical / 叶字节 / 叶子哈希 / 幂等键**落盘**，
  // 由 Node 端逐字节比对。
  final probeAscii = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.invite,
      ref: bob.pub,
      note: 'thanks');
  final probeZh = await _signedRecord(carol.pub, carol.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.host,
      ref: 'EVT-2026-09',
      note: '谢谢你来主持');
  // 「同一件事换个时间重签」—— 它**合法签名**，但幂等键与 probeAscii 相同、
  // 叶子哈希不同。Hub 必须靠 key_conflict 拦下它（否则"把一件事记十遍"成立）。
  // ⚠️ 必须是**真签名**：拿改过字段的假签名去测，只会先撞上 bad_signature，
  //    测的根本不是 key_conflict。
  final probeFork = await _signedRecord(bob.pub, bob.sign,
      subjectPub: alice.pub,
      kind: ContributionKind.invite,
      ref: bob.pub,
      atMs: kNow + 1000,
      note: 'thanks');

  Map<String, Object?> pack(ContributionRecord r) => {
        'rec': {
          'ctype': r.kind,
          'subject_pub': r.subjectPub,
          'attestor_pub': r.attestorPub,
          'ref': r.ref,
          'weight': r.weight,
          'at': r.atMs,
          'note': r.note,
          'sig': r.sig,
        },
        'canonical': r.canonical(),
        'leaf_bytes': utf8.decode(r.logLeafBytes()),
        'leaf_hash': '',
        'key': r.key,
      };

  final probe = {
    'records': [
      for (final r in [probeAscii, probeZh])
        {...pack(r), 'leaf_hash': await TransparencyLog.leafHashOf(r.logLeafBytes())},
    ],
    'fork': {
      ...pack(probeFork),
      'leaf_hash': await TransparencyLog.leafHashOf(probeFork.logLeafBytes()),
    },
    'kinds': ContributionKind.values,
    'weights': {
      for (final k in ContributionKind.values) k: ContributionKind.weightOf(k),
    },
    'caps': ContributionCaps.perKindCap,
    'requires_counterparty': ContributionCaps.requiresCounterparty.toList(),
    'max_note_chars': ContributionCaps.maxNoteChars,
    'max_ref_chars': ContributionCaps.maxRefChars,
  };
  File('tool/.contribution_probe.json').writeAsStringSync(jsonEncode(probe));
  check(File('tool/.contribution_probe.json').existsSync(),
      '探针文件已写出（tool/.contribution_probe.json）');
  check(probe['records'] is List && (probe['records'] as List).length == 2,
      '探针含 ASCII 与中文两条记录（中文专门用来照出转义漂移）');
  final forkMap = probe['fork']! as Map;
  final firstMap = (probe['records']! as List).first as Map;
  check(
      forkMap['key'] == firstMap['key'] &&
          forkMap['leaf_hash'] != firstMap['leaf_hash'],
      '「换个时间重签」探针：键相同、叶子不同（这正是 key_conflict 要拦的形态）');

  print('');
  print('PASS=$_pass FAIL=$_fail');
}
