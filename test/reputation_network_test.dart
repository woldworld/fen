// M6「网络级信誉 · 签名背书 + 可验证的信任传播」单测。
//
// 与 `tool/verify_reputation_network.dart` 的分工：那边做**源码层面的合规审计**
// （DDL 漂移、埋点名一致性、WoldRuntime 装配、档位字面量对齐），这里做**行为断言**。
//
// ## 为什么网络信誉必须这么设计
// 最容易被做成自我安慰的一类功能：一个"全网信誉分"看起来很美，
// 而它天然可刷（注册一堆小号互送好评即可）。所以本模块**不做全局分**，
// 只做"**对你而言**这个陌生人有多可信" —— 这些用例盯的就是抗刷的每一条。
//
// 运行（★ 走唯一入库入口，它会自动剥代理；踩坑说明见 db_migration_test.dart）：
//   dart run tool/run_flutter_test.dart -- test/reputation_network_test.dart

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/reputation_network.dart';
import 'package:dahuang_ai/core/telemetry.dart';

const int kNow = 1800000000000;
const int kDay = 86400000;

/// 一把测试用 Ed25519 密钥。
class _Key {
  final String pub;
  final Future<String> Function(List<int>) sign;
  _Key(this.pub, this.sign);

  static Future<_Key> generate() async {
    final kp = await Ed25519().newKeyPair();
    final pubBytes = await kp.extractPublicKey();
    return _Key(AgentProtocol.base58Encode(pubBytes.bytes), (msg) async {
      final s = await Ed25519().sign(msg, keyPair: kp);
      return base64Encode(s.bytes);
    });
  }
}

Future<Endorsement> _endorsement(
  _Key issuer, {
  required String subjectPub,
  required String tier,
  int issuedAtMs = kNow,
  int? expiresAtMs,
  String note = '',
}) async {
  final e = Endorsement(
    issuerPub: issuer.pub,
    subjectPub: subjectPub,
    tier: tier,
    issuedAtMs: issuedAtMs,
    expiresAtMs: expiresAtMs ?? issuedAtMs + 365 * kDay,
    note: note,
  );
  return e.copyWith(sig: await issuer.sign(e.canonicalBytes()));
}

void main() {
  late _Key me;
  late _Key bob;
  late _Key carol;
  late _Key dave;

  setUpAll(() async {
    me = await _Key.generate();
    bob = await _Key.generate();
    carol = await _Key.generate();
    dave = await _Key.generate();
  });

  group('铁律 1：无锚点即 unknown（不退化成 0 分 / 50 分）', () {
    test('查不到 → unknown，且置信度必须是 0', () async {
      final v = ReputationGraph.evaluate(
        subjectPub: carol.pub,
        anchors: {bob.pub: 0.9},
        endorsements: [
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend),
        ],
        nowMs: kNow,
      );
      expect(v.isUnknown, isTrue);
      expect(v.code, EndorseCode.unknown);
      // 0 会被读成"坏人"、50 会被读成"普通人"，两者都是谎言
      expect(v.confidence, 0);
      expect(v.path, isEmpty);
    });

    test('一个锚点都没有 → unknown', () {
      final v = ReputationGraph.evaluate(
          subjectPub: dave.pub, anchors: const {}, endorsements: const [], nowMs: kNow);
      expect(v.isUnknown, isTrue, reason: '不能凭空信任陌生人');
    });

    test('锚点权重 0（我不信）→ 不产生通路', () async {
      final v = ReputationGraph.evaluate(
        subjectPub: dave.pub,
        anchors: {bob.pub: 0.0},
        endorsements: [
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.family),
        ],
        nowMs: kNow,
      );
      expect(v.isUnknown, isTrue);
    });
  });

  group('铁律 2：只取最优路径，绝不累加', () {
    test('★ 多个不同背书人：条数如实记下，置信度仍只取最强那条', () async {
      final many = ReputationGraph.evaluate(
        subjectPub: dave.pub,
        anchors: {bob.pub: 0.9, me.pub: 0.5},
        endorsements: [
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend),
          await _endorsement(me, subjectPub: dave.pub, tier: ReputationTier.friend),
        ],
        nowMs: kNow,
      );
      final one = ReputationGraph.evaluate(
        subjectPub: dave.pub,
        anchors: {bob.pub: 0.9},
        endorsements: [
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend),
        ],
        nowMs: kNow,
      );
      expect(many.paths, 2, reason: '证据厚度要如实（两个人背书 → 2 条）');
      expect(many.confidence, one.confidence,
          reason: '★ 条数不参与置信度 —— 否则造路径就能刷分');
    });

    test('★ 8 条中继 + 1 条直达 == 只有 1 条直达', () async {
      final edges = <Endorsement>[
        await _endorsement(bob,
            subjectPub: dave.pub, tier: ReputationTier.acquaintance),
      ];
      for (var i = 0; i < 8; i++) {
        final r = await _Key.generate();
        edges.add(await _endorsement(bob,
            subjectPub: r.pub, tier: ReputationTier.acquaintance));
        edges.add(await _endorsement(
            r, subjectPub: dave.pub, tier: ReputationTier.acquaintance));
      }
      final many = ReputationGraph.evaluate(
          subjectPub: dave.pub, anchors: {bob.pub: 0.9}, endorsements: edges, nowMs: kNow);
      final one = ReputationGraph.evaluate(
        subjectPub: dave.pub,
        anchors: {bob.pub: 0.9},
        endorsements: [
          await _endorsement(bob,
              subjectPub: dave.pub, tier: ReputationTier.acquaintance),
        ],
        nowMs: kNow,
      );
      expect(many.confidence, one.confidence);
    });

    test('信任随距离衰减，且深度上限为 2', () async {
      final v = ReputationGraph.evaluate(
        subjectPub: carol.pub,
        anchors: {bob.pub: 0.9},
        endorsements: [
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.family),
          await _endorsement(dave, subjectPub: carol.pub, tier: ReputationTier.family),
        ],
        nowMs: kNow,
      );
      expect(v.known, isTrue);
      expect(v.depth, 2);
      expect(v.confidence, lessThan(0.9 * ReputationCaps.attenuation + 1e-9));
    });
  });

  group('铁律 3/4/5：自证 / 过期 / 网络背书到不了 family', () {
    test('★ 自证 → self_endorsement', () async {
      final e = await _endorsement(dave,
          subjectPub: dave.pub, tier: ReputationTier.family);
      final v = await ReputationGraph.verifyEndorsement(e, nowMs: kNow);
      expect(v.accept, isFalse);
      expect(v.code, EndorseCode.selfEndorsement);
    });

    test('★ 过期背书 → expired', () async {
      final e = await _endorsement(bob,
          subjectPub: dave.pub,
          tier: ReputationTier.family,
          issuedAtMs: kNow - 400 * kDay,
          expiresAtMs: kNow - kDay);
      final v = await ReputationGraph.verifyEndorsement(e, nowMs: kNow);
      expect(v.code, EndorseCode.expired, reason: '信任必须有终点');
    });

    test('★ 网络背书永远抬不到 family（家人只能本人认定）', () async {
      final v = ReputationGraph.evaluate(
        subjectPub: dave.pub,
        anchors: {bob.pub: 1.0}, // 即便声称 100% 信任
        endorsements: [
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.family),
        ],
        nowMs: kNow,
      );
      expect(v.known, isTrue);
      expect(v.tier, isNot(ReputationTier.family));
      // 物理形式：锚点上限 × 衰减 × 最大边权 < family 门槛
      expect(
        ReputationCaps.maxAnchorWeight *
            ReputationCaps.attenuation *
            ReputationTier.weightOf(ReputationTier.family),
        lessThan(ReputationCaps.familyFloor),
      );
    });
  });

  group('验签 fail-closed', () {
    test('合法背书 → 通过；改档位 / 换主体 → bad_signature', () async {
      final good =
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend);
      expect((await ReputationGraph.verifyEndorsement(good, nowMs: kNow)).accept, isTrue);

      expect(
        (await ReputationGraph.verifyEndorsement(
                good.copyWith(tier: ReputationTier.family), nowMs: kNow))
            .code,
        EndorseCode.badSignature,
        reason: '★ 事后把 friend 升级成 family 做不到',
      );

      final moved = Endorsement(
          issuerPub: good.issuerPub,
          subjectPub: carol.pub,
          tier: good.tier,
          issuedAtMs: good.issuedAtMs,
          expiresAtMs: good.expiresAtMs,
          note: good.note,
          sig: good.sig);
      expect((await ReputationGraph.verifyEndorsement(moved, nowMs: kNow)).code,
          EndorseCode.badSignature, reason: '★ 背书不能转手给别人');
    });

    test('已吊销 → revoked（签名再合法也不采信）', () async {
      final good =
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend);
      final v = await ReputationGraph.verifyEndorsement(good,
          nowMs: kNow, revokedKeys: {good.key});
      expect(v.code, EndorseCode.revoked);
    });

    test('无签名 / 坏公钥 / stranger 档 / 附言超长 → 各自拒', () async {
      final good =
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend);
      expect((await ReputationGraph.verifyEndorsement(good.copyWith(sig: ''), nowMs: kNow)).code,
          EndorseCode.missingFields);
      expect(
          (await ReputationGraph.verifyEndorsement(
                  good.copyWith(tier: ReputationTier.stranger), nowMs: kNow))
              .code,
          EndorseCode.badTier,
          reason: '"我背书他是个陌生人"是无意义的边');
      expect(
          (await ReputationGraph.verifyEndorsement(
                  good.copyWith(note: 'x' * (ReputationCaps.maxNoteChars + 1)),
                  nowMs: kNow))
              .code,
          EndorseCode.noteTooLong);
    });
  });

  group('吊销：只有签发人本人', () {
    test('★ 拿别人的签名冒充签发人 → 拒', () async {
      final r = EndorsementRevocation(
          issuerPub: bob.pub, subjectPub: dave.pub, atMs: kNow);
      final bobRev = EndorsementRevocation(
          issuerPub: bob.pub,
          subjectPub: dave.pub,
          atMs: kNow,
          sig: await bob.sign(r.canonicalBytes()));
      final daveSig = await dave.sign(r.canonicalBytes());
      final forged = EndorsementRevocation(
          issuerPub: bob.pub, subjectPub: dave.pub, atMs: kNow, sig: daveSig);

      expect((await ReputationGraph.verifyRevocation(bobRev)).accept, isTrue);
      expect((await ReputationGraph.verifyRevocation(forged)).accept, isFalse,
          reason: '★ 否则任何人都能清场别人的信誉');
    });
  });

  group('服务层', () {
    late MemoryReputationStore store;
    late ReputationNetworkService svc;
    late List<String> events;

    setUp(() {
      store = MemoryReputationStore();
      events = [];
      svc = ReputationNetworkService(store: store, onEvent: (k, _) => events.add(k));
    });

    test('签收 → 落库；重复签收 → duplicate', () async {
      final e =
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend);
      expect((await svc.endorse(e, nowMs: kNow)).accept, isTrue);
      expect(await store.endorsement(bob.pub, dave.pub), isNotNull);
      expect((await svc.endorse(e, nowMs: kNow)).isDuplicate, isTrue);
    });

    test('★ 改看法不新增行（一人对一人只有一份背书）', () async {
      await svc.endorse(
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend),
          nowMs: kNow);
      final before = (await store.all()).length;
      await svc.endorse(
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.family),
          nowMs: kNow);
      expect((await store.all()).length, before,
          reason: '叠加不出第二份背书（叠加 = 变相放大边权 = 刷分）');
    });

    test('★ 吊销后立刻查不到（敞口收回是即时的）', () async {
      await svc.endorse(
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend),
          nowMs: kNow);
      expect((await svc.query(
              subjectPub: dave.pub, anchors: {bob.pub: 0.9}, nowMs: kNow))
          .known,
          isTrue);

      final r = EndorsementRevocation(
          issuerPub: bob.pub, subjectPub: dave.pub, atMs: kNow);
      expect(
          (await svc.revoke(EndorsementRevocation(
              issuerPub: bob.pub,
              subjectPub: dave.pub,
              atMs: kNow,
              sig: await bob.sign(r.canonicalBytes()))))
              .accept,
          isTrue);
      expect((await svc.query(
              subjectPub: dave.pub, anchors: {bob.pub: 0.9}, nowMs: kNow))
          .isUnknown,
          isTrue);
    });

    test('unknown 也留痕（可观测："我有多少次查不到"）', () async {
      await svc.query(subjectPub: carol.pub, anchors: {bob.pub: 0.9}, nowMs: kNow);
      expect(events, contains(ReputationNetworkEvents.queryUnknown));
      expect(ReputationNetworkEvents.queryUnknown,
          TelemetryEvents.reputationQueryUnknown);
    });
  });

  group('canonical：键序固定（跨语言复算的前提）', () {
    test('alg / kind 入载荷，键序不可变', () async {
      final e =
          await _endorsement(bob, subjectPub: dave.pub, tier: ReputationTier.friend);
      final m = jsonDecode(e.canonical()) as Map<String, dynamic>;
      expect(m['alg'], 'ed25519', reason: '挡算法混淆');
      expect(m['kind'], 'endorsement', reason: '挡"拿吊销声明当背书验"');
      expect(m.keys.join(','),
          'alg,kind,issuer_pub,subject_pub,tier,issued_at,expires_at,note');
    });
  });
}
