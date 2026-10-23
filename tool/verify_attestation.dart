// 纯 Dart 校验脚本：验证 M6 轻量前置「可验证签名互介记录」（PRD §4 M6 信誉体系的种子）。
// 运行：dart run tool/verify_attestation.dart
//
// 验收（对应 PRD §4 M6 原文三条）：
//   ① **这次互介是谁发起** —— 发起方对 intentCanonical 的签名，验过才算数；
//   ② **双方是否同意** —— 两把**不同的**密钥对**同一份** consentCanonical 各签一次；
//      任何单方（含用同一把钥匙演双方）都造不出 consented；
//   ③ **结果如何** —— 结果由当事人签署，可被对端追认升级为"双方共识"。
//
// 另验：信任档只由**验过的签名**决定（不由记录自称决定）；时序不可倒流；
// 幂等；线格式解析即验收；互介→握手转化率的分母诚实。

import 'dart:convert';

import 'package:dahuang_ai/core/attestation_service.dart';
import 'package:dahuang_ai/core/circle_service.dart' show Ed25519Signer;

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

const int kT0 = 1800000000000; // 固定时钟：结果可复算
const String kRoom = 'lisbon-night';
const String kCircle = 'cA';

final List<Map<String, Object?>> _events = [];

/// 一台虚拟设备：独立密钥 + 独立账本 + 独立服务。
class Device {
  final String id;
  final Ed25519Signer signer;
  final MemoryAttestationStore store = MemoryAttestationStore();
  late final AttestationService svc;

  Device(this.id, this.signer) {
    svc = AttestationService(
      store: store,
      signer: signer,
      selfId: () async => id,
      onEvent: (n, p) => _events.add({'name': n, 'actor': id, ...p}),
    );
  }

  Future<String> get pub => signer.publicKeyBase58();
}

Future<void> main() async {
  final alice = Device('AG-alice', await Ed25519Signer.generate());
  final bob = Device('AG-bob', await Ed25519Signer.generate());
  final evil = Device('AG-evil', await Ed25519Signer.generate());

  // ---------------------------------------------------------------------
  print('--- ① 发起：只有发起签名，等级只能到 initiated ---');
  final a0 = await alice.svc.propose(
    counterpartyId: bob.id,
    circleId: kCircle,
    roomId: kRoom,
    topic: '同房间聊得来，都想聊结构风洞',
    nowMs: kT0,
  );
  check(a0.state == IntroState.proposed, '发起后状态 = proposed');
  check(a0.roomBacked, '记录带房间出处（M5 的"房间是圈的载体"可追溯）');
  check(a0.id.startsWith('ia_'), 'id 由内容确定性导出（ia_ 前缀）');
  check(a0.initiatorDid.startsWith('did:wold:'), '护照：发起方 did:wold 可从公钥直接导出');
  check(a0.dids.length == 1, '此刻只有一个可验证 DID（对端还没签）');

  final v0 = await IntroVerifier.verify(a0);
  check(v0.trust == IntroTrust.initiated, '信任档 = initiated');
  check(!v0.mutuallyConsented, '还没到"双方同意"—— 不能被当成互介成立');
  check(IntroOutcome.isSuccess(a0.outcome) == false, '没有结果时不算握手');

  // id 幂等：同样的输入必须得到同一个 id（两端才算同一份记录）
  final a0again = await alice.svc.propose(
    counterpartyId: bob.id,
    circleId: kCircle,
    roomId: kRoom,
    topic: '同房间聊得来，都想聊结构风洞',
    nowMs: kT0,
  );
  check(a0again.id == a0.id, '同输入 → 同 id（天然幂等，无需中心分配）');

  // ---------------------------------------------------------------------
  print('--- ② 双方同意：两把不同密钥签同一份字节 ---');
  // 先证明"只有对端能同意"
  final notMine = await evil.svc.consent(a0, nowMs: kT0 + 100);
  check(notMine == null, '非对端（第三方）无法签出同意');

  final selfTry = await alice.svc.consent(a0, nowMs: kT0 + 100);
  check(selfTry == null, '发起方自己不能签"对方同意"');

  final a1 = await bob.svc.consent(a0, nowMs: kT0 + 1000);
  check(a1 != null, '对端签出同意');
  final v1 = await IntroVerifier.verify(a1!);
  check(v1.trust == IntroTrust.consented, '信任档 = consented');
  check(v1.mutuallyConsented, '互介在可验证意义上成立（双方都签了）');
  check(v1.atLeast(IntroTrust.consented), 'atLeast(consented) 为真');
  check(v1.checks.contains('mutual_consent_valid'), '检查项含 mutual_consent_valid');
  check(v1.checks.contains('distinct_keys'), '检查项含 distinct_keys（两把不同密钥）');
  check(a1.counterpartyDid != null && a1.dids.length == 2, '此刻有两个可验证 DID');

  // 幂等：重复同意不改动
  final a1again = await bob.svc.consent(a1, nowMs: kT0 + 5000);
  check(a1again!.consentedAtMs == a1.consentedAtMs, '重复同意幂等（时间不回改）');

  // ---------------------------------------------------------------------
  print('--- 🔴 反例：同一把钥匙演双方，必须造不出 consented ---');
  // 攻击者用**自己的**密钥签 consentCanonical，并把两处 pub 都填成自己。
  // 这个洞不堵，一个人就能凭空制造"双方同意"的记录。
  final alicePub = await alice.pub;
  final staged = a0.copyWith(consentedAtMs: kT0 + 1000);
  final selfSig =
      await alice.signer.signBytes(utf8.encode(staged.consentCanonicalStr()));
  final forged = staged.copyWith(
      counterpartyPub: alicePub, counterpartySig: selfSig);
  final vForged = await IntroVerifier.verify(forged);
  check(vForged.faults.contains(AttestFault.sameKeyBothSides),
      '被拦：原因码 same_key_both_sides');
  check(vForged.trust == IntroTrust.initiated,
      '等级停在 initiated（签名虽然"数学上有效"，但仍是单方）');
  check(!vForged.mutuallyConsented, '伪造记录不构成"双方同意"');

  // 线格式也拒收（解析即验收）
  final forgedWire = await IntroWire.tryParse(IntroWire.encodeProposal(forged));
  check(forgedWire != null,
      '线格式层面：发起段有效 → 能被接收（但它只配"发起"这一档）');
  final vWireForged = await IntroVerifier.verify(forgedWire!.$2);
  check(vWireForged.trust == IntroTrust.initiated,
      '解析回来的伪造记录，信任档仍是 initiated');
  check(!vWireForged.mutuallyConsented,
      '过线不改性质：伪造记录在接收端也不构成"双方同意"');

  // ---------------------------------------------------------------------
  print('--- ③ 结果：当事人签署，对端可追认升级 ---');
  final a2 = await alice.svc.resolve(a1, outcome: IntroOutcome.handshake, nowMs: kT0 + 2000);
  check(a2 != null, '主张结果成功');
  final v2 = await IntroVerifier.verify(a2!);
  check(v2.trust == IntroTrust.resolved, '信任档 = resolved');
  check(!v2.mutuallyAcknowledged, '此刻结果仍是"单方主张"，对端还没追认');

  // 主张结果的人不能自己追认自己
  final selfAck = await alice.svc.acknowledge(a2, nowMs: kT0 + 3000);
  check(selfAck == null, '主张结果者不能自我追认');

  final a3 = await bob.svc.acknowledge(a2, nowMs: kT0 + 3000);
  check(a3 != null, '对端追认成功');
  final v3 = await IntroVerifier.verify(a3!);
  check(v3.trust == IntroTrust.acknowledged, '信任档 = acknowledged（最强档）');
  check(v3.mutuallyAcknowledged, '结果升级为"双方共识"');
  check(v3.checks.contains('counterparty_ack_valid'), '检查项含 counterparty_ack_valid');

  // ---------------------------------------------------------------------
  print('--- fail-closed：逐条改写都会被同一个验签器拦住 ---');
  // 改主题 → 发起签名失效（因为主题被写进了双方都签过的字节里）
  final tamperTopic = a3.copyWith(topic: '被改过的主题');
  final vTopic = await IntroVerifier.verify(tamperTopic);
  check(vTopic.trust == IntroTrust.none &&
          vTopic.faults.contains(AttestFault.badInitiatorSig),
      '改 topic → 发起签名失效（改一个字，两个签名全废）');

  // 改房间出处 → 同样失效（M5 的出处不可事后伪造）
  final tamperRoom = a3.copyWith(roomId: 'other-room');
  final vRoom = await IntroVerifier.verify(tamperRoom);
  check(vRoom.faults.contains(AttestFault.badInitiatorSig),
      '改 roomId → 签名失效（房间出处不可事后编造）');

  // 改同意时刻，令其早于发起时刻
  final stagedBack = a1.copyWith(consentedAtMs: kT0 - 5000);
  final cSigBack =
      await bob.signer.signBytes(utf8.encode(stagedBack.consentCanonicalStr()));
  final back = stagedBack.copyWith(
      counterpartyPub: await bob.pub, counterpartySig: cSigBack);
  final vBack = await IntroVerifier.verify(back);
  check(vBack.faults.contains(AttestFault.badTimeOrder) &&
          !vBack.mutuallyConsented,
      '同意早于发起 → bad_time_order，且不构成双方同意');

  // 没有同意，直接落结果
  final noConsent = a0.copyWith(
      outcome: IntroOutcome.handshake, outcomeBy: alice.id, resolvedAtMs: kT0 + 10);
  final vNoConsent = await IntroVerifier.verify(noConsent);
  check(vNoConsent.faults.contains(AttestFault.badTimeOrder),
      'proposed 直接跳结果 → bad_time_order（没有同意就没有结果可言）');

  // 非法结果码
  final stagedBadCode = a1.copyWith(
      outcome: 'bribed', outcomeBy: alice.id, resolvedAtMs: kT0 + 2000);
  final badCodeSig = await alice.signer
      .signBytes(utf8.encode(stagedBadCode.resolveCanonicalStr()));
  final badCode = stagedBadCode.copyWith(outcomeSig: badCodeSig);
  final vBadCode = await IntroVerifier.verify(badCode);
  check(vBadCode.faults.contains(AttestFault.badOutcomeCode),
      '非法结果码 → bad_outcome_code');

  // 结果由第三方主张
  final stagedThird = a1.copyWith(
      outcome: IntroOutcome.handshake, outcomeBy: evil.id, resolvedAtMs: kT0 + 2000);
  final thirdSig = await evil.signer
      .signBytes(utf8.encode(stagedThird.resolveCanonicalStr()));
  final third = stagedThird.copyWith(outcomeSig: thirdSig);
  final vThird = await IntroVerifier.verify(third);
  check(vThird.faults.contains(AttestFault.outcomeByNotParty),
      '第三方主张结果 → outcome_by_not_party');

  // 结果签名缺失
  final stagedNoSig = a1.copyWith(
      outcome: IntroOutcome.handshake, outcomeBy: alice.id, resolvedAtMs: kT0 + 2000);
  final vNoSig = await IntroVerifier.verify(stagedNoSig);
  check(vNoSig.faults.contains(AttestFault.missingOutcomeSig),
      '结果无签名 → missing_outcome_sig');

  // 改结果（handshake → declined）而不重签
  final tamperOutcome = a2.copyWith(outcome: IntroOutcome.declined);
  final vTamperOutcome = await IntroVerifier.verify(tamperOutcome);
  check(vTamperOutcome.faults.contains(AttestFault.badOutcomeSig),
      '改结果 → 结果签名失效（RESOLVE 内嵌了整份 CONSENT）');
  check(vTamperOutcome.trust == IntroTrust.consented,
      '等级退回 consented（不能因为自称 declined 就改变已证事实）');

  // 自己和自己
  final selfIntro = IntroAttestation(
    id: 'x',
    initiatorId: alice.id,
    counterpartyId: alice.id,
    initiatedAtMs: kT0,
    initiatorPub: 'p',
    initiatorSig: 's',
  );
  final vSelf = await IntroVerifier.verify(selfIntro);
  check(vSelf.trust == IntroTrust.none &&
          vSelf.faults.contains(AttestFault.selfIntroduction),
      '自己和自己 → self_introduction');

  // id 与内容不自洽
  final badIdAtt = a3.copyWith(id: 'ia_forged');
  final vBadId = await IntroVerifier.verify(badIdAtt);
  check(vBadId.faults.contains(AttestFault.badId),
      'id 与内容不自洽 → bad_id（防止同一互介在两端裂成两条）');

  // 空 id
  final vEmpty = await IntroVerifier.verify(IntroAttestation(
    id: 'x',
    initiatorId: '',
    counterpartyId: '',
    initiatedAtMs: 0,
    initiatorPub: 'p',
    initiatorSig: 's',
  ));
  check(vEmpty.faults.contains(AttestFault.emptyIds), '空当事人 → empty_ids');

  // ---------------------------------------------------------------------
  print('--- 服务层时序闸门：不可倒流、不可改写 ---');
  final earlyResolve = await alice.svc.resolve(a1, outcome: IntroOutcome.handshake, nowMs: kT0 - 1);
  check(earlyResolve == null, '结果时刻早于同意时刻 → 服务层直接拒绝');
  final earlyAck = await bob.svc.acknowledge(a2, nowMs: kT0 - 1);
  check(earlyAck == null, '追认时刻早于结果时刻 → 服务层直接拒绝');
  final rewriteOutcome =
      await alice.svc.resolve(a2, outcome: IntroOutcome.declined, nowMs: kT0 + 9000);
  check(rewriteOutcome!.outcome == IntroOutcome.handshake,
      '结果一旦落定不可改写（幂等返回原值）');

  // ---------------------------------------------------------------------
  print('--- 线格式：解析即验收 ---');
  final wire = IntroWire.encodeProposal(a1);
  final parsed = await IntroWire.tryParse(wire);
  check(parsed != null && parsed.$1 == 'proposal', 'proposal 可解析');
  check(parsed!.$2.id == a1.id, '解析回来是同一条记录');
  check(IntroWire.isIntro(wire), 'isIntro 快速判定为真');
  check(!IntroWire.isIntro('{"da_type":"gift"}'), '别的 da_type 不被误认');

  // 篡改线上 payload → 发起签名失效 → 拒收
  final tamperedWire =
      wire.replaceFirst('同房间聊得来', '被中间人改过的主题（长度不同）');
  if (tamperedWire != wire) {
    final bad = await IntroWire.tryParse(tamperedWire);
    check(bad == null, '线上 payload 被改 → 拒收（不是"先收下再说"）');
  } else {
    check(false, '线上 payload 被改 → 拒收（替换未生效，测试本身有问题）');
  }

  // ---------------------------------------------------------------------
  print('--- 互介→握手转化率（PRD 链路 β 指标）：分母诚实 ---');
  // 造 4 条：
  //   ① 握手（双方签 + 结果 + 追认）
  //   ② 被拒（双方签 + 结果）
  //   ③ 在途（只双方签，未落结果）
  //   ④ 只发起（对方未同意）
  final s = Device('AG-solo', await Ed25519Signer.generate());
  final p = Device('AG-peer', await Ed25519Signer.generate());

  // 三条完整链（时间必须与各自的 t0 对齐，否则服务层会以"时序倒流"拒绝）
  //
  // 这里**刻意模拟线格式回传**：对端的同意/结果/追认必须回到发起方的账本，
  // 否则发起方手里只有自己签的那半张，永远证不出"双方同意"。
  // 真实运行时由 IntroRelay + agent_service 的入站拦截完成这一步。
  Future<IntroAttestation> full(String topic, int t0) async {
    final x = await s.svc.propose(
        counterpartyId: p.id, circleId: kCircle, topic: topic, nowMs: t0);
    final consented = (await p.svc.consent(x, nowMs: t0 + 10))!;
    final rx = (await IntroWire.tryParse(IntroWire.encodeUpdate(consented)))!;
    await s.store.upsert(rx.$2); // ← 线格式回传后入账
    return rx.$2;
  }

  const int t1 = kT0 + 10000;
  final f1 = await full('握手那条', t1);
  final r1 =
      (await s.svc.resolve(f1, outcome: IntroOutcome.handshake, nowMs: t1 + 20))!;
  await p.svc.acknowledge(r1, nowMs: t1 + 30);

  const int t2 = kT0 + 20000;
  final f2 = await full('被拒那条', t2);
  await s.svc.resolve(f2, outcome: IntroOutcome.declined, nowMs: t2 + 20);

  await full('在途那条', kT0 + 30000); // 不落结果

  await s.svc.propose(
      counterpartyId: p.id, circleId: kCircle, topic: '没人搭理那条', nowMs: kT0 + 40000);

  final funnel = await s.svc.myFunnel();
  check(funnel.proposed == 4, 'proposed = 4（发起过 4 次互介）');
  check(funnel.consented == 3, 'consented = 3（其中 3 次双方同意）');
  check(funnel.handshake == 1, 'handshake = 1');
  check(funnel.declined == 1, 'declined = 1');
  check(funnel.inFlight == 1, 'inFlight = 1（在途单独列出，不被当成失败）');
  check(funnel.settled == 2, 'settled = 2（已落结果的诚实分母）');
  check((funnel.consentRate2 - 0.75).abs() < 1e-9, '双方同意率 = 3/4 = 0.75');
  check((funnel.handshakeConversion2 - 0.5).abs() < 1e-9,
      '互介→握手转化率 = 1/2 = 0.5（分母只用已落结果）');
  check((funnel.handshakeOverConsented2 - 0.33).abs() < 1e-9,
      '保守口径 = 1/3 = 0.33（在途算未成功，与上面口径并列显示）');

  // 反例：伪造的"握手"不得污染转化率
  final sPub = await s.pub;
  final fStaged = await s.svc.propose(
      counterpartyId: p.id, circleId: kCircle, topic: '伪造握手那条', nowMs: kT0 + 50000);
  final fStaged2 = fStaged.copyWith(consentedAtMs: kT0 + 50010);
  final fSelfSig =
      await s.signer.signBytes(utf8.encode(fStaged2.consentCanonicalStr()));
  final fForged = fStaged2.copyWith(
          counterpartyPub: sPub, counterpartySig: fSelfSig)
      .copyWith(
          outcome: IntroOutcome.handshake,
          outcomeBy: s.id,
          resolvedAtMs: kT0 + 50020);
  await s.store.upsert(fForged);
  final funnel2 = await s.svc.myFunnel();
  check(funnel2.handshake == 1,
      '伪造的"握手"不计入分子（它连双方同意都验不过）');
  check(funnel2.consented == 3, '伪造记录不计入 consented 分母');
  check(funnel2.proposed == 5, '但它确实被"发起"过，所以 proposed +1（不隐藏事实）');

  // ---------------------------------------------------------------------
  print('--- 可选：名字与钥匙的绑定（生产查 did_issuance 账本）---');
  final boundOk = await IntroVerifier.verify(a3,
      pubOfAgent: (id) async => id == alice.id
          ? await alice.pub
          : id == bob.id
              ? await bob.pub
              : null);
  check(boundOk.checks.contains('initiator_id_pub_bound'), '签发账本配套 → 绑定校验通过');
  check(boundOk.checks.contains('counterparty_id_pub_bound'), '对端绑定也通过');
  final boundBad = await IntroVerifier.verify(a3,
      pubOfAgent: (id) async => id == alice.id ? await evil.pub : await bob.pub);
  check(boundBad.faults.contains(AttestFault.initiatorIdPubMismatch),
      '名字与钥匙不配套 → initiator_id_pub_mismatch');
  check(boundBad.mutuallyConsented == false || boundBad.faults.isNotEmpty,
      '绑定失败会被记录在案（不被静默忽略）');

  // ---------------------------------------------------------------------
  print('--- 埋点：三段式每一步都留痕 ---');
  check(_events.any((e) => e['name'] == 'intro_proposed'), '有 intro_proposed');
  check(_events.any((e) => e['name'] == 'intro_consented'), '有 intro_consented');
  check(_events.any((e) => e['name'] == 'intro_resolved'), '有 intro_resolved');
  check(_events.any((e) => e['name'] == 'intro_acknowledged'), '有 intro_acknowledged');
  final rejected = _events.where((e) => e['name'] == 'intro_proposed').length;
  check(rejected >= 5, '每次发起都记了一条（含伪造尝试，不隐藏）');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
