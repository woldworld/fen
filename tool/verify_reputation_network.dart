// 纯 Dart 校验脚本：M6「网络级信誉 · 签名背书 + 可验证的信任传播」。
// 运行：dart run tool/verify_reputation_network.dart
//
// 为什么值得单独一个脚本：
//   网络信誉是**最容易被做成自我安慰**的一类功能 —— 一个"全网信誉分"看起来很美，
//   而它天然可刷（注册一堆小号互送好评即可）。本脚本盯的不是"功能能不能跑"，
//   而是"抗刷的每一条是不是真的在代码里"：
//   ① 无锚点即 unknown（不退化成 0 分 / 50 分）；
//   ② **只取最优路径、绝不累加**（造 100 条中继不能涨一分）—— 整个模块最容易写错的一行；
//   ③ 自证无效；④ 背书会过期；⑤ 网络背书永远抬不到 family。
//
// 签名部分需要真 Ed25519 密钥；其余判定与传播全是纯函数，直接复算。
// DDL 漂移 / 埋点名一致性 / WoldRuntime 装配用**源文本比对**。

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/reputation_network.dart';
import 'package:dahuang_ai/core/telemetry.dart';

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
const int kDay = 86400000;

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
    cols.add(first);
  }
  return cols;
}

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

Future<Endorsement> _signed(
  String issuerPub,
  Future<String> Function(List<int>) sign, {
  required String subjectPub,
  required String tier,
  int issuedAtMs = kNow,
  int? expiresAtMs,
  String note = '',
}) async {
  final e = Endorsement(
    issuerPub: issuerPub,
    subjectPub: subjectPub,
    tier: tier,
    issuedAtMs: issuedAtMs,
    expiresAtMs: expiresAtMs ?? issuedAtMs + 365 * kDay,
    note: note,
  );
  return e.copyWith(sig: await sign(e.canonicalBytes()));
}

Future<EndorsementRevocation> _signedRevocation(
  String issuerPub,
  Future<String> Function(List<int>) sign, {
  required String subjectPub,
  int atMs = kNow,
}) async {
  final r = EndorsementRevocation(
      issuerPub: issuerPub, subjectPub: subjectPub, atMs: atMs);
  return EndorsementRevocation(
    issuerPub: r.issuerPub,
    subjectPub: r.subjectPub,
    atMs: r.atMs,
    sig: await sign(r.canonicalBytes()),
  );
}

Future<void> main() async {
  // =========================================================================
  print('--- ① 铁律 1：无锚点即 unknown（不退化成 0 分 / 50 分）---');
  // =========================================================================
  final me = await _newKey();
  final bob = await _newKey();
  final carol = await _newKey();
  final dave = await _newKey();

  var v = ReputationGraph.evaluate(
    subjectPub: dave.pub,
    anchors: {bob.pub: 0.9},
    endorsements: [
      await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.friend),
    ],
    nowMs: kNow,
  );
  check(v.known, '有通路 → known');

  v = ReputationGraph.evaluate(
    subjectPub: carol.pub,
    anchors: {bob.pub: 0.9},
    endorsements: [
      await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.friend),
    ],
    nowMs: kNow,
  );
  check(v.isUnknown, '★ 查不到 → unknown（不是 0，也不是 50）');
  check(v.code == EndorseCode.unknown, 'unknown 的码是 unknown');
  check(v.confidence == 0, '★ unknown 的置信度必须是 0（否则 UI 会拿它当分显示）');
  check(v.path.isEmpty, 'unknown 不带证据链（没有证据可出示）');

  v = ReputationGraph.evaluate(
      subjectPub: dave.pub, anchors: const {}, endorsements: const [], nowMs: kNow);
  check(v.isUnknown, '★ 一个锚点都没有 → unknown（不能凭空信任陌生人）');

  v = ReputationGraph.evaluate(
      subjectPub: '', anchors: {bob.pub: 0.9}, endorsements: const [], nowMs: kNow);
  check(v.isUnknown && v.code == EndorseCode.missingFields, '空主体 → missing_fields');

  // 锚点权重 0 = 我不信，不该产生通路
  v = ReputationGraph.evaluate(
    subjectPub: dave.pub,
    anchors: {bob.pub: 0.0},
    endorsements: [
      await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.family),
    ],
    nowMs: kNow,
  );
  check(v.isUnknown, '锚点权重 0 → 不产生通路');

  // =========================================================================
  print('--- ② 铁律 2：★ 只取最优路径，绝不累加（刷分的第一入口）---');
  // =========================================================================
  // 造 8 条中继，全部指向 dave。若实现写成"求和"，dave 会被刷爆。
  final relays = <Endorsement>[
    await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.acquaintance),
  ];
  for (var i = 0; i < 8; i++) {
    final r = await _newKey();
    relays.add(await _signed(
        bob.pub, bob.sign, subjectPub: r.pub, tier: ReputationTier.acquaintance));
    relays.add(await _signed(
        r.pub, r.sign, subjectPub: dave.pub, tier: ReputationTier.acquaintance));
  }
  final manyPaths = ReputationGraph.evaluate(
      subjectPub: dave.pub,
      anchors: {bob.pub: 0.9},
      endorsements: relays,
      nowMs: kNow);
  final singlePath = ReputationGraph.evaluate(
    subjectPub: dave.pub,
    anchors: {bob.pub: 0.9},
    endorsements: [
      await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.acquaintance),
    ],
    nowMs: kNow,
  );
  check(manyPaths.confidence == singlePath.confidence,
      '★ 8 条中继 + 1 条直达 == 只有 1 条直达（多路径不累加）');

  // 同一深度上的**多个不同背书人**：条数必须如实记下，但置信度仍只取最优。
  final alice = await _newKey();
  final twoBackers = ReputationGraph.evaluate(
    subjectPub: dave.pub,
    anchors: {bob.pub: 0.9, alice.pub: 0.5},
    endorsements: [
      await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.friend),
      await _signed(alice.pub, alice.sign, subjectPub: dave.pub, tier: ReputationTier.friend),
    ],
    nowMs: kNow,
  );
  final onlyStrong = ReputationGraph.evaluate(
    subjectPub: dave.pub,
    anchors: {bob.pub: 0.9},
    endorsements: [
      await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.friend),
    ],
    nowMs: kNow,
  );
  check(twoBackers.paths == 2, '通路条数被如实记下（两个不同的人背书 → 2 条）');
  check(twoBackers.confidence == onlyStrong.confidence,
      '★ 2 条通路 == 只有最强那 1 条（条数是证据厚度，不参与置信度）');

  // 深度衰减：两跳必须明显弱于一跳
  final twoHop = ReputationGraph.evaluate(
    subjectPub: carol.pub,
    anchors: {bob.pub: 0.9},
    endorsements: [
      await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.family),
      await _signed(dave.pub, dave.sign, subjectPub: carol.pub, tier: ReputationTier.family),
    ],
    nowMs: kNow,
  );
  check(twoHop.known && twoHop.depth == 2, '两跳可达 → depth 2');
  check(twoHop.confidence < 0.9 * ReputationCaps.attenuation + 0.0001,
      '两跳权重 ≤ anchor × attenuation（信任随距离衰减）');

  // =========================================================================
  print('--- ③ 铁律 3/4/5：自证无效 / 会过期 / 网络背书到不了 family ---');
  // =========================================================================
  final selfEnd = await _signed(dave.pub, dave.sign,
      subjectPub: dave.pub, tier: ReputationTier.family);
  final selfV = await ReputationGraph.verifyEndorsement(selfEnd, nowMs: kNow);
  check(!selfV.accept && selfV.code == EndorseCode.selfEndorsement,
      '★ 自证 → self_endorsement（自己给自己背书写不进去）');

  final expiredEnd = await _signed(bob.pub, bob.sign,
      subjectPub: dave.pub,
      tier: ReputationTier.family,
      issuedAtMs: kNow - 400 * kDay,
      expiresAtMs: kNow - 1 * kDay);
  final expiredV =
      await _expiryGuard(expiredEnd);
  check(!expiredV.accept && expiredV.code == EndorseCode.expired,
      '★ 过期背书 → expired（信任必须有终点）');

  // 铁律 5：一跳衰减后到不了 family
  final oneHopFamily = ReputationGraph.evaluate(
    subjectPub: dave.pub,
    anchors: {bob.pub: 1.0},
    endorsements: [
      await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.family),
    ],
    nowMs: kNow,
  );
  check(oneHopFamily.known, '（前提）一跳可达');
  check(oneHopFamily.tier != ReputationTier.family,
      '★ 网络背书永远抬不到 family（铁律 5：家人只能本人认定）');
  check(ReputationGraph.tierFromConfidence(0.59) == ReputationTier.friend,
      '0.59 → friend（family 门槛 0.60 取不到）');
  check(ReputationGraph.tierFromConfidence(0.61) == ReputationTier.family,
      '0.61 → family（锚点自身可以是 family）');
  check(ReputationCaps.maxAnchorWeight *
              ReputationCaps.attenuation *
              ReputationTier.weightOf(ReputationTier.family) <
          ReputationCaps.familyFloor,
      '★ 算术保证：锚点上限 × attenuation × 最大边权 < family 门槛（铁律 5 的物理形式）');
  check(oneHopFamily.confidence <=
          ReputationCaps.maxAnchorWeight * ReputationCaps.attenuation + 1e-9,
      '★ 传入 anchor=1.0 被 clamp 到上限（主观信任不可能是 100%）');

  // =========================================================================
  print('--- ④ 验签 fail-closed：改档位 / 换主体 / 坏公钥 / 无签名 ---');
  // =========================================================================
  final good = await _signed(bob.pub, bob.sign,
      subjectPub: dave.pub, tier: ReputationTier.friend);
  check((await ReputationGraph.verifyEndorsement(good, nowMs: kNow)).accept,
      '合法背书 → 通过');

  final tamperedTier = good.copyWith(tier: ReputationTier.family);
  check((await ReputationGraph.verifyEndorsement(tamperedTier, nowMs: kNow)).code ==
      EndorseCode.badSignature,
      '★ 改档位（签名不动）→ bad_signature（事后升级背书做不到）');

  // 换主体：copyWith 刻意不开放 subjectPub（主体是身份，不该被"改"出来），
  // 所以这里用构造函数重建一份"字段已改、签名照抄"的伪造件。
  final tamperedSubject = Endorsement(
    issuerPub: good.issuerPub,
    subjectPub: carol.pub,
    tier: good.tier,
    issuedAtMs: good.issuedAtMs,
    expiresAtMs: good.expiresAtMs,
    note: good.note,
    sig: good.sig,
  );
  check((await ReputationGraph.verifyEndorsement(tamperedSubject, nowMs: kNow)).code ==
      EndorseCode.badSignature,
      '★ 换主体 → bad_signature（不能把背书转给别人）');

  final tamperedWindow = good.copyWith(expiresAtMs: good.expiresAtMs + 100 * kDay);
  check((await ReputationGraph.verifyEndorsement(tamperedWindow, nowMs: kNow)).code ==
      EndorseCode.badSignature,
      '改有效期 → bad_signature');

  final badSubject = Endorsement(
    issuerPub: good.issuerPub,
    subjectPub: 'not-a-pubkey',
    tier: good.tier,
    issuedAtMs: good.issuedAtMs,
    expiresAtMs: good.expiresAtMs,
    note: good.note,
    sig: good.sig,
  );
  check((await ReputationGraph.verifyEndorsement(badSubject, nowMs: kNow)).code ==
      EndorseCode.badPubkey, '坏公钥 → bad_pubkey');
  check((await ReputationGraph.verifyEndorsement(
          good.copyWith(sig: ''), nowMs: kNow))
      .code ==
      EndorseCode.missingFields, '无签名 → missing_fields');
  check((await ReputationGraph.verifyEndorsement(
          good.copyWith(tier: ReputationTier.stranger), nowMs: kNow))
      .code ==
      EndorseCode.badTier, '背书 stranger → bad_tier（无意义的边）');
  check((await ReputationGraph.verifyEndorsement(
          good.copyWith(note: 'x' * (ReputationCaps.maxNoteChars + 1)), nowMs: kNow))
      .code ==
      EndorseCode.noteTooLong, '附言超长 → note_too_long（不截断）');
  check((await ReputationGraph.verifyEndorsement(
          good.copyWith(expiresAtMs: good.issuedAtMs - 1), nowMs: kNow))
      .code ==
      EndorseCode.badWindow, '有效期早于签发时间 → bad_window');

  // 吊销先于验签
  final revokedOk = await ReputationGraph.verifyEndorsement(good,
      nowMs: kNow, revokedKeys: {good.key});
  check(!revokedOk.accept && revokedOk.code == EndorseCode.revoked,
      '★ 已吊销 → revoked（签名再合法也不采信）');

  // =========================================================================
  print('--- ⑤ 吊销：只有签发人本人 ---');
  // =========================================================================
  final bobRev = await _signedRevocation(bob.pub, bob.sign, subjectPub: dave.pub);
  check((await ReputationGraph.verifyRevocation(bobRev)).accept, '签发人本人吊销 → 通过');
  final daveRev = await _signedRevocation(dave.pub, dave.sign, subjectPub: dave.pub);
  check((await ReputationGraph.verifyRevocation(daveRev)).accept,
      '（前提）dave 也能签出合法吊销声明');
  final forged = EndorsementRevocation(
      issuerPub: bob.pub, subjectPub: dave.pub, atMs: kNow, sig: daveRev.sig);
  check(!(await ReputationGraph.verifyRevocation(forged)).accept,
      '★ 拿别人的签名冒充签发人吊销 → 拒（否则任何人能清场别人的信誉）');

  // =========================================================================
  print('--- ⑥ 签收判定：幂等 / 可更新 / 不叠加 ---');
  // =========================================================================
  check(ReputationGraph.endorseDecision(incoming: good, existing: null).detail == '',
      '首次背书 → accepted（无 detail）');
  check(ReputationGraph.endorseDecision(incoming: good, existing: good).detail ==
      'duplicate', '完全相同 → duplicate（幂等）');
  check(ReputationGraph.endorseDecision(
          incoming: good.copyWith(tier: ReputationTier.family, sig: 'x'),
          existing: good)
      .detail ==
      'updated', '改看法 → updated（允许覆盖，但只有一份）');

  // =========================================================================
  print('--- ⑦ 服务层（内存 store 全链路）---');
  // =========================================================================
  final store = MemoryReputationStore();
  final events = <String>[];
  final svc = ReputationNetworkService(store: store, onEvent: (k, _) => events.add(k));

  check((await svc.endorse(good, nowMs: kNow)).accept, '合法背书 → 签收');
  check((await store.endorsement(bob.pub, dave.pub)) != null, '背书已落库');
  check((await svc.endorse(good, nowMs: kNow)).isDuplicate, '重复签收 → duplicate');

  final before = (await store.all()).length;
  await svc.endorse(
      await _signed(bob.pub, bob.sign, subjectPub: dave.pub, tier: ReputationTier.family),
      nowMs: kNow);
  check((await store.all()).length == before,
      '★ 改看法不新增行（一人对一人只有一份背书，叠加不出第二份）');

  check(!(await svc.endorse(selfEnd, nowMs: kNow)).accept, '服务层：自证 → 拒');

  final q1 = await svc.query(
      subjectPub: dave.pub, anchors: {bob.pub: 0.9}, nowMs: kNow);
  check(q1.known, '服务层查询 → known');
  check(q1.path.first == bob.pub && q1.path.last == dave.pub,
      '证据链首尾正确（可顺着逐个验签）');

  check((await svc.revoke(bobRev)).accept, '签发人吊销 → 通过');
  final q2 = await svc.query(
      subjectPub: dave.pub, anchors: {bob.pub: 0.9}, nowMs: kNow);
  check(q2.isUnknown, '★ 吊销后 → 查不到（敞口收回是即时的）');

  final q3 = await svc.query(
      subjectPub: carol.pub, anchors: {bob.pub: 0.9}, nowMs: kNow);
  check(q3.isUnknown, '无关主体 → unknown');
  check(events.contains(ReputationNetworkEvents.queryUnknown), 'unknown 也留痕（可观测）');

  // 吊销一个不存在的背书不该凭空造记录
  check(!(await svc.revoke(await _signedRevocation(me.pub, me.sign,
              subjectPub: carol.pub, atMs: kNow)))
      .accept,
      '吊销不存在的背书 → 拒（不凭空造吊销记录）');

  // =========================================================================
  print('--- ⑧ 落库：DDL ↔ 序列化字段漂移（源文本比对）---');
  // =========================================================================
  final dbSrc = _stripComments(File('lib/core/db_helper.dart').readAsStringSync());
  final verM = RegExp(r'schemaVersion\s*=\s*(\d+)').firstMatch(dbSrc);
  final ver = verM == null ? -1 : int.parse(verM.group(1)!);
  check(ver >= 31, 'DBHelper.schemaVersion >= 31（v30 背书 + v31 接缝表都已落地，当前 $ver）');
  check(dbSrc.contains('30: _migrateV30'), '_migrations 注册了 30');
  check(dbSrc.contains('31: _migrateV31'), '_migrations 注册了 31');

  final endCols = _ddlColumns(dbSrc, 'endorsements');
  final endMap = good.toMap().keys.toSet();
  check(endCols.isNotEmpty, 'endorsements DDL 存在');
  check(endCols.difference(endMap).isEmpty && endMap.difference(endCols).isEmpty,
      'endorsements 列集合 == Endorsement.toMap 键集合（缺列 = 真机 no such column）');

  final revCols = _ddlColumns(dbSrc, 'endorsement_revoked');
  final revMap = bobRev.toMap().keys.toSet();
  check(revCols.difference(revMap).isEmpty && revMap.difference(revCols).isEmpty,
      'endorsement_revoked 列集合 == EndorsementRevocation.toMap 键集合');

  check(endCols.contains('expires_at'), '★ 背书有 expires_at（信任必须有终点）');
  check(endCols.contains('subject_pub') && !endCols.contains('subject_id'),
      '★ 主体是**公钥**不是 ID（换 ID 洗不掉差评）');

  // v31 接缝表：本地信誉(agent_id) ↔ 网络信誉(pubkey) 唯一的桥。
  // 这张表缺列 = 真机运行时报 no such column = 锚点永远是空的 = 网络背书写了也查不到。
  final keyCols = _ddlColumns(dbSrc, 'agent_pubkeys');
  check((keyCols.toList()..sort()).join(',') == 'agent_id,at_ms,pubkey,source',
      'agent_pubkeys 列集合固定（PK agent_id / pubkey / source / at_ms）');
  check(ReputationBridge.anchorsFrom(
          scoreById: const {'A': 90}, pubById: {'A': bob.pub})[bob.pub] ==
      0.9,
      '接缝产物形状 == 传播所需形状（无需二次转换）');
  final uiSrc =
      _stripComments(File('lib/ui/passport_screen.dart').readAsStringSync());
  check(uiSrc.contains("'agent_pubkeys'"), '护照页真的读写接缝表');
  check(uiSrc.contains('_bindPubkey'), '★ 接缝有写入点（只读不写的桥 = 永远空表）');
  check(!uiSrc.contains('ConflictAlgorithm'),
      '接缝写库用 read-then-upsert（Android 10 的 SQLite 3.22 不支持 ON CONFLICT）');

  final runtime = File('lib/core/wold_runtime.dart').readAsStringSync();
  check(runtime.contains('import \'reputation_network.dart\';'), 'WoldRuntime 引入了信誉网络');
  check(runtime.contains('reputationStore = DbReputationStore()'),
      'WoldRuntime 建的是 **Db**ReputationStore（不是内存）');
  check(runtime.contains('ReputationNetworkService('), 'WoldRuntime 建了 ReputationNetworkService');

  // =========================================================================
  print('--- ⑨ 埋点名与 TelemetryEvents 一致（漂移会静默丢数据）---');
  // =========================================================================
  check(ReputationNetworkEvents.endorseAccepted ==
      TelemetryEvents.reputationEndorseAccepted, 'endorseAccepted 一致');
  check(ReputationNetworkEvents.endorseRejected ==
      TelemetryEvents.reputationEndorseRejected, 'endorseRejected 一致');
  check(ReputationNetworkEvents.revoked ==
      TelemetryEvents.reputationEndorsementRevoked, 'revoked 一致');
  check(ReputationNetworkEvents.queryKnown == TelemetryEvents.reputationQueryKnown,
      'queryKnown 一致');
  check(ReputationNetworkEvents.queryUnknown == TelemetryEvents.reputationQueryUnknown,
      'queryUnknown 一致');

  // =========================================================================
  print('--- ⑩ 档位字面量必须与本地信誉体系一致（两边同名不同值 = 静默错档）---');
  // =========================================================================
  final repSrc =
      _stripComments(File('lib/core/reputation_service.dart').readAsStringSync());
  for (final t in const ['stranger', 'friend', 'family']) {
    check(repSrc.contains('\'$t\''), 'reputation_service 也用 $t 字面量（档位对齐）');
  }
  check(ReputationTier.values.length == 4, '档位共 4 档');
  check(ReputationTier.endorsable.length == 3, '可背书档位 3 档（stranger 被排除）');
  check(ReputationTier.weightOf(ReputationTier.family) >
          ReputationTier.weightOf(ReputationTier.friend) &&
      ReputationTier.weightOf(ReputationTier.friend) >
          ReputationTier.weightOf(ReputationTier.acquaintance),
      '档位权重单调（family > friend > acquaintance）');

  // =========================================================================
  print('--- ⑪ canonical：键序固定 + alg/kind 入载荷 ---');
  // =========================================================================
  final c = jsonDecode(good.canonical()) as Map<String, dynamic>;
  check(c['alg'] == 'ed25519', 'canonical 含 alg（挡算法混淆）');
  check(c['kind'] == 'endorsement', 'canonical 含 kind（挡"拿吊销声明当背书验"）');
  check(c.keys.toList().join(',') ==
      'alg,kind,issuer_pub,subject_pub,tier,issued_at,expires_at,note',
      'canonical 键序固定（跨语言复算的前提）');
  final rc = jsonDecode(bobRev.canonical()) as Map<String, dynamic>;
  check(rc['kind'] == 'endorsement_revocation', '吊销 canonical 的 kind 不同');
  check(good.logLeafBytes().isNotEmpty, 'logLeafBytes 非空（可进 §16 日志）');

  // 跨语言探针导出（供 Node 侧复验 canonical 逐字节一致）
  final probe = {
    'endorsement': good.canonical(),
    'endorsement_sig': good.sig,
    'endorsement_pub': good.issuerPub,
    'revocation': bobRev.canonical(),
    'revocation_sig': bobRev.sig,
    'revocation_pub': bobRev.issuerPub,
  };
  File('tool/.reputation_probe.json').writeAsStringSync(jsonEncode(probe));
  check(File('tool/.reputation_probe.json').existsSync(),
      '已导出跨语言探针（Dart §⑪ 产物）');

  // =========================================================================
  print('--- ⑫ 接缝：本地信誉(agent_id) → 网络锚点(pubkey) ---');
  // =========================================================================
  // 两个体系索引键不同（本地按 agent_id、网络按 pubkey），接缝是 DB v31 的
  // agent_pubkeys。**桥写错了不会报错** —— 网络背书会永远是一张空表，
  // 追溯永远回答"我不知道"，而这一页看上去完全正常。
  final bridged = ReputationBridge.anchorsFrom(
    scoreById: const {'A': 90, 'B': 70, 'C': 30, 'D': 88},
    pubById: {'A': bob.pub, 'B': carol.pub, 'C': dave.pub}, // D 有分但没公钥
  );
  check(bridged[bob.pub] == 0.9, '有分 + 有公钥 → 进锚点（权重 = score/100）');
  check(bridged.containsKey(carol.pub), '刚过门槛（70 ≥ 60）也进锚点');
  check(!bridged.containsKey(dave.pub), '★ 分数低于门槛 → 根本不做起点（不是权重调低）');
  check(bridged.length == 2, '★ 有分但没公钥的人诚实跳过（不拿 ID 冒充公钥）');
  check(ReputationBridge.anchorsFrom(scoreById: const {}, pubById: const {}).isEmpty,
      '空输入 → 空锚点（不凭空造信任）');

  // ★ 同一把钥匙被两个身份指向 → 取最高，绝不叠加。
  //   叠加 = 一个人开 N 个身份指向同一把钥匙，就能给自己凭空加权。
  final merged = ReputationBridge.anchorsFrom(
    scoreById: const {'A': 80, 'B': 95},
    pubById: {'A': bob.pub, 'B': bob.pub},
  );
  check(merged[bob.pub] == 0.95,
      '★ 同一把钥匙被多身份指向 → 取最高，不叠加（Sybil 堵点）');
  check(bridged.length + merged.length == 3, '桥不改动入参、也不产生额外锚点');

  // 端到端：桥的产物直接喂进传播，必须查得到 —— 证明接缝真的接通。
  final endToEnd = ReputationGraph.evaluate(
    subjectPub: dave.pub,
    anchors: ReputationBridge.anchorsFrom(
        scoreById: const {'A': 90}, pubById: {'A': bob.pub}),
    endorsements: [
      await _signed(bob.pub, bob.sign,
          subjectPub: dave.pub, tier: ReputationTier.friend),
    ],
    nowMs: kNow,
  );
  check(endToEnd.known,
      '★ 桥产物直接可查：接缝接通（否则网络背书写进去也永远是空表）');
  check(endToEnd.path.isNotEmpty &&
          endToEnd.path.first == bob.pub &&
          endToEnd.path.last == dave.pub,
      '证据链从锚点起、到主体止（可逐段验签）');

  // Bridge 照实给 1.0，clamp 必须发生在传播里（两处各管一件事）
  final capped = ReputationBridge.anchorsFrom(
      scoreById: const {'A': 100}, pubById: {'A': bob.pub});
  check(capped[bob.pub] == 1.0, '满分锚点 Bridge 照实给 1.0（不在这一层 clamp）');
  final cappedEval = ReputationGraph.evaluate(
    subjectPub: dave.pub,
    anchors: capped,
    endorsements: [
      await _signed(bob.pub, bob.sign,
          subjectPub: dave.pub, tier: ReputationTier.family),
    ],
    nowMs: kNow,
  );
  check(
      cappedEval.confidence <=
          ReputationCaps.maxAnchorWeight * ReputationCaps.attenuation + 1e-9,
      '★ 100 分锚点在传播时被 clamp（主观信任不可能是 100%）');

  // ---------------------------------------------------------------- 身份别名
  // 背书按 `subject_pub` 计（不用 agent_id：名字可被重发 ⇒ "改个名就能甩掉差评"）。
  // 代价是换钥退休旧公钥之后，别人此前给他的背书全都留在那把死钥上 ——
  // "履历随人走"当场退化成"随钥走"（换一次手机履历归零）。
  // 别名（`RotationChain.keysOf` 的产物）就是解药；而它做错的后果是
  // **把别人的履历算到他头上**，所以这里正反两面都要钉死。
  print('--- ⑬ 身份别名：履历随人走，且绝不跨身份 ---');
  final eve = await _newKey();
  final frankOld = await _newKey();
  final frankNew = await _newKey();
  final stranger = await _newKey();
  final aliasAnchors = {eve.pub: 0.9};
  final eveEndorse = await _signed(eve.pub, eve.sign,
      subjectPub: frankOld.pub, tier: ReputationTier.friend);

  // 不给别名 ⇒ 换钥之后"我认识他"变成"我不知道" —— 这就是要修的病根本身。
  final noAlias = ReputationGraph.evaluate(
    subjectPub: frankNew.pub,
    anchors: aliasAnchors,
    endorsements: [eveEndorse],
    nowMs: kNow,
  );
  check(!noAlias.known,
      '★ 不给别名：查新钥 → unknown（换个手机就"不认识"，正是 Gap A 的病根）');

  final withAlias = ReputationGraph.evaluate(
    subjectPub: frankNew.pub,
    anchors: aliasAnchors,
    endorsements: [eveEndorse],
    subjectAliases: {frankOld.pub},
    nowMs: kNow,
  );
  check(withAlias.known, '★ 给了别名：查新钥 → 仍然认识（履历随人走）');
  check(withAlias.matchedKey == frankOld.pub,
      '★ 如实报出"命中的是历史钥"（UI 才能说清结论从哪来，而不是让它猜）');
  check(withAlias.depth == 1 && withAlias.path.last == frankOld.pub,
      '证据链末端落在真正记着背书的那把钥上');
  check(
      (withAlias.confidence - 0.9 * ReputationCaps.attenuation * 0.75).abs() < 1e-9,
      '别名只改"命中谁"，不改权重（衰减照算，不因换钥变强变弱）');

  // 反方向：以旧钥为主体、新钥当别名 —— 同一件事，答案必须一样
  final mirror = ReputationGraph.evaluate(
    subjectPub: frankOld.pub,
    anchors: aliasAnchors,
    endorsements: [eveEndorse],
    subjectAliases: {frankNew.pub},
    nowMs: kNow,
  );
  check(mirror.known && (mirror.confidence - withAlias.confidence).abs() < 1e-9,
      '两个方向查得到同一个结论（别名是**对称**并集，不是单向继承）');

  // ★ 别名**不产生**信任：它只是把已有的边重新贴上"同一个人"的标签
  final selfAlias = ReputationGraph.evaluate(
    subjectPub: frankNew.pub,
    anchors: aliasAnchors,
    endorsements: [eveEndorse],
    subjectAliases: {frankNew.pub},
    nowMs: kNow,
  );
  check(!selfAlias.known, '★ 别名里只有它自己 ⇒ 仍是 unknown（别名不凭空造边）');

  // ★ 别名**不做二次校验**：给什么集合就认什么集合（纯函数，无从判断真假）。
  //   所以"擅自多塞一把别人的钥"确实会把别人的履历算到他头上 ——
  //   挡这件事的闸在**派生端**（`RotationChain.keysOf` 的 fail-closed，
  //   见 verify_rotation_chain ⑦ 与 Node 侧 alias 用例）。
  //   这里把这个边界钉死，免得将来有人以为"反正 evaluate 会拦"。
  final borrow = ReputationGraph.evaluate(
    subjectPub: stranger.pub,
    anchors: aliasAnchors,
    endorsements: [eveEndorse],
    subjectAliases: {frankOld.pub},
    nowMs: kNow,
  );
  check(
      borrow.known && borrow.matchedKey == frankOld.pub,
      '★ 边界：evaluate 忠实执行给定集合、**不做**别名校验 ⇒ 闸必须在派生端 keysOf');
  final borrowNoAlias = ReputationGraph.evaluate(
    subjectPub: stranger.pub,
    anchors: aliasAnchors,
    endorsements: [eveEndorse],
    nowMs: kNow,
  );
  check(!borrowNoAlias.known,
      '★ 不传别名时陌生人借不到任何人的履历（真实防冒领的那一条）');

  // 未换钥时行为**逐字段不变**（别名默认为空集）
  final plain = ReputationGraph.evaluate(
    subjectPub: frankOld.pub,
    anchors: aliasAnchors,
    endorsements: [eveEndorse],
    nowMs: kNow,
  );
  check(plain.known && plain.matchedKey == frankOld.pub,
      '不传别名时 matchedKey = 查询的那把钥（默认行为不变）');

  // ---- 服务层：按"全部历史公钥"取并集 ----
  final store2 = MemoryReputationStore();
  final svc2 = ReputationNetworkService(store: store2);
  final acc = await svc2.endorse(eveEndorse, nowMs: kNow);
  check(acc.accept, '背书先落库（服务层链路通）');
  check((await svc2.receivedBy({frankOld.pub})).length == 1,
      'receivedBy(旧钥) → 1（与 forSubject 等价的那一半）');
  check((await svc2.receivedBy({frankNew.pub})).isEmpty,
      'receivedBy(新钥) → 0 —— 这正是"只认当前钥 ⇒ 履历归零"的机制');
  check((await svc2.receivedBy({frankNew.pub, frankOld.pub})).length == 1,
      '★ receivedBy(新钥 ∪ 旧钥) → 1（UI 用的就是这一路）');
  check((await svc2.receivedBy(<String>{})).isEmpty,
      '空集合 → 空结果（不炸、不悄悄回退成全表）');
  check((await svc2.issuedBy({eve.pub})).length == 1 &&
          (await svc2.issuedBy({frankNew.pub})).isEmpty,
      'issuedBy 同理：按签发人的全部历史公钥取并集');

  // =========================================================================
  print('--- ⑭ ★ 拉取归属闸：Hub 回什么不算数，只有"我的钥"才准落库 ---');
  // =========================================================================
  // 外部审计 P2③：`pullMyReputation` 原先**逐条验签但不核对主体**。
  // 验签只证明"这份签名确实由它自称的 issuer 签过"，**完全不说明被背书的人是我**。
  // 于是被篡改 / 有 bug 的 Hub 可以回一批 `subject_pub = 别人` 的**合法签名**记录，
  // 逐条验签全过 ⇒ 原样落进我的库 ⇒ 我的履历里混进别人的背书，
  // 而我此后拿这份库当"我看到的世界"（护照页还会把它当"我"的资历展示）。
  //
  // 归属**只能由本机自己算**（当前钥 ∪ 本地退休记录 ∪ 本地验过的换钥链），
  // 不能采信 Hub 回包里的 `alias.keys`（那只是它的说法）。
  final mineSet = {frankNew.pub, frankOld.pub};

  check(ReputationGraph.subjectIsMine(frankNew.pub, mineSet),
      '主体 == 我的当前钥 → 收');
  check(ReputationGraph.subjectIsMine(frankOld.pub, mineSet),
      '★ 主体 == 我的**已退休**旧钥 → 也要收（换钥后履历仍在旧钥名下，这正是 Gap A）');
  check(!ReputationGraph.subjectIsMine(stranger.pub, mineSet),
      '★ 主体是**别人** → 拒（哪怕签名完全合法，也不是我的履历）');
  check(!ReputationGraph.subjectIsMine('', mineSet),
      '空主体 → 拒（不给"空串当成我"的机会）');
  check(!ReputationGraph.subjectIsMine(frankNew.pub, <String>{}),
      '★ fail-closed：算不出我的钥 ⇒ 一条都不收（宁可空着，不塞别人的东西）');
  check(ReputationGraph.subjectIsMine('  ${frankOld.pub}  ', mineSet),
      '两侧 trim（真机粘贴来源带空白时不该静默丢自己的履历）');

  // 反证：归属闸挡掉的这条记录，**验签是能过的** —— 说明"验签过了"根本不等于"是我的"。
  final someoneElses = await _signed(eve.pub, eve.sign,
      subjectPub: stranger.pub, tier: ReputationTier.friend);
  check((await ReputationGraph.verifyEndorsement(someoneElses, nowMs: kNow)).accept,
      '（前提）别人主体的背书**验签通过** —— 即"验签"对此无能为力');
  check(!ReputationGraph.subjectIsMine(someoneElses.subjectPub, mineSet),
      '★ 同一条记录，只有归属闸能把它挡在库外（这就是 P2③ 的病根）');

  // ---- 源码级：闸必须在**验签之前**、且**不采信 Hub 的 alias.keys** ----
  final runtimeSrc = _stripComments(runtime);
  check(runtimeSrc.contains('subjectIsMine'),
      'WoldRuntime.pullMyReputation 真的调了归属闸（不是只在文档里写着）');
  check(runtimeSrc.contains('no_identity_keys'),
      '算不出我的钥时留痕并拒收（fail-closed 可见，不静默）');
  final pullAt = runtimeSrc.indexOf('Future<int> pullMyReputation');
  check(pullAt > 0, '找得到 pullMyReputation 函数体');
  if (pullAt > 0) {
    final body = runtimeSrc.substring(pullAt, (pullAt + 4000).clamp(0, runtimeSrc.length));
    final iMine = body.indexOf('subjectIsMine');
    final iVerify = body.indexOf('verifyEndorsement');
    check(iMine > 0 && iVerify > 0 && iMine < iVerify,
        '★ 顺序：**先归属、再验签**（颠倒会让"验签通过"被误读成"这条可信"）');
    check(body.contains('myIdentityKeys'),
        '归属集合由**本机**算（myIdentityKeys），不是 Hub 说的');
    // 只看"归属判定那一段"（函数开头 → 第一次验签）里有没有 aliasKeys：
    // 函数末尾的埋点（`'alias_keys': view.aliasKeys.length`）只是**报数**，不算采信。
    if (iVerify > 0) {
      final gateRegion = body.substring(0, iVerify);
      check(!gateRegion.contains('aliasKeys'),
          '★ 归属区段内不出现 aliasKeys（判定期间绝不读 Hub 的自证字段）');
    }
  }

  // =========================================================================
  print('--- ⑮ ★ 接缝表只有一个写入点（P2② 第二写入者已收敛）---');
  // =========================================================================
  // `agent_pubkeys` 是「本地信誉(agent_id) ↔ 网络信誉(pubkey)」唯一的桥。
  // 原先有两个写入者：`AgentIdentity.adoptAgentId`（会先把旧钥抄进退休表）
  // 与护照页 `_bindPubkey`（**直接覆盖、旧钥不留痕**，也不拦退休钥写回）。
  // 同一条不变式在两条路上强度不同 ⇒ "换钥必先留痕"只在恢复那条路成立。
  // 现在必须**只剩一个**写入点，且那个点必须自带"先留痕、后覆盖"。
  final idSrc = _stripComments(File('lib/core/agent_identity.dart').readAsStringSync());
  check(idSrc.contains('Future<bool> bindSeam('),
      'AgentIdentity.bindSeam 存在（接缝表的唯一写入点）');
  check(idSrc.contains('viaConfirmedRotation'),
      '权威换钥路径用的是**显式开关**（不是静默放行，读代码的人一眼看得见）');

  final bindAt = idSrc.indexOf('Future<bool> bindSeam(');
  if (bindAt > 0) {
    final body = idSrc.substring(bindAt, (bindAt + 2600).clamp(0, idSrc.length));
    final iRetired = body.indexOf('retiredKeys(');
    final iRecord = body.indexOf('_recordRetiredKey(');
    final iInsert = body.indexOf('db.insert(');
    check(iRetired > 0, '① 空值 + 退休钥两道闸都在（fail-closed）');
    check(iRecord > 0 && iInsert > 0 && iRecord < iInsert,
        '★ ② **先留痕、再覆盖**（顺序反了 = 旧钥被顶掉却没人记得）');
    check(body.contains('conflictAlgorithm: ConflictAlgorithm.replace'),
        '③ upsert（不用 ON CONFLICT：Android 10 的 SQLite 3.22 不支持）');
    check(body.contains('priorPub == p'), '④ 同值不写（幂等，不刷新 at_ms）');
  }

  // adoptAgentId 必须**委托**，不能自己再写一遍。
  final adoptAt = idSrc.indexOf('Future<void> adoptAgentId(');
  check(adoptAt > 0, '找得到 adoptAgentId');
  if (adoptAt > 0) {
    final tail = idSrc.substring(adoptAt, (adoptAt + 2600).clamp(0, idSrc.length));
    final nextMethod = tail.indexOf('Future<bool> bindSeam(');
    final adoptBody = nextMethod > 0 ? tail.substring(0, nextMethod) : tail;
    check(adoptBody.contains('bindSeam('), 'adoptAgentId 改走 bindSeam');
    check(!adoptBody.contains('db.insert('),
        '★ adoptAgentId 自己**不再**写接缝表（否则第二写入者又长回来）');
  }

  // ---- 全 lib/ 扫一遍：往 agent_pubkeys 写的代码只准出现在一个文件、且只有一处 ----
  final writeRe = RegExp(r"""\.(insert|update)\(\s*'agent_pubkeys'""");
  final writers = <String>[];
  var writeSites = 0;
  for (final ent in Directory('lib').listSync(recursive: true)) {
    if (ent is! File || !ent.path.endsWith('.dart')) continue;
    final s = _stripComments(ent.readAsStringSync());
    if (writeRe.hasMatch(s)) {
      writers.add(ent.path.replaceAll(r'\', '/'));
      writeSites += writeRe.allMatches(s).length;
    }
  }
  writers.sort();
  check(writers.length == 1 && writers.first == 'lib/core/agent_identity.dart',
      '★ 全 lib/ 只有 agent_identity.dart 写接缝表（实际：${writers.join(' / ')}）');
  check(writeSites == 1,
      '★ 写入语句**只有一处**（实际 $writeSites 处；多一处就说明口子又开了）');
  check(!uiSrc.contains("insert('agent_pubkeys'") &&
          !uiSrc.contains("update('agent_pubkeys'") &&
          !uiSrc.contains('ConflictAlgorithm'),
      '护照页彻底不碰接缝表的写（只读它去折锚点）');
  check(uiSrc.contains('bindSeam(') && uiSrc.contains('AgentIdentity()'),
      '护照页确实把绑定转交给了 bindSeam（不是把这个功能删掉）');

  print('');
  print('================ M6 网络信誉校验 ================');
  print('PASS=$_pass FAIL=$_fail');
}

/// 小工具：过期判定（单独抽出来是为了让上面的断言读起来顺）。
Future<EndorseDecision> _expiryGuard(Endorsement e) =>
    ReputationGraph.verifyEndorsement(e, nowMs: kNow);
