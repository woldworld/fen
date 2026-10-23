import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/skill_registry.dart';

/// M9：技能注册表 + 作者分成 + 签名上架的单元测试。
///
/// 与 `tool/verify_skill_registry.dart` 的分工：
///   - 离线脚本是**交付验收口径**（83 条断言，纯 `dart run`，零平台依赖）；
///   - 这里把最容易被后续改动打破的语义固化成回归测试。
/// 两者刻意重复：一个保证"离线可复算"，一个保证"改坏了会红"。
const int kNow = 1800000000000;

Future<SimpleKeyPair> _kp() => Ed25519().newKeyPair();

Future<String> _pub(SimpleKeyPair kp) async =>
    AgentProtocol.base58Encode((await kp.extractPublicKey()).bytes);

Future<SkillListing> _sign({
  required SimpleKeyPair kp,
  required String skillId,
  required String version,
  String content = 'C',
  int priceCents = 0,
  String risk = SkillRisk.low,
  List<String> caps = const [],
}) async {
  final base = SkillListing(
    skillId: skillId,
    version: version,
    name: '技能',
    authorId: 'AG-1',
    authorPub: await _pub(kp),
    capabilities: caps,
    risk: risk,
    contentHash: SkillRegistry.contentHashOf(content),
    pricing: SkillPricing(priceCents: priceCents),
    publishedAtMs: kNow,
  );
  final sig = await Ed25519().sign(base.canonicalBytes(), keyPair: kp);
  return base.copyWith(signatureB64: base64Encode(sig.bytes));
}

void main() {
  group('验签：fail-closed（改价 / 换内容 / 无签名一律拒）', () {
    test('作者合法签名 → 通过', () async {
      final kp = await _kp();
      final l = await _sign(kp: kp, skillId: 'wold.skill.t', version: '1.0.0');
      final v = await SkillRegistry.verifyListing(l);
      expect(v.ok, isTrue);
      expect(v.code, SkillVerifyCode.ok);
      expect(v.installable, isTrue);
    });

    test('★ 铁律 1：签名覆盖定价 —— 事后改价必然验签失败', () async {
      final kp = await _kp();
      final l = await _sign(kp: kp, skillId: 'wold.skill.t', version: '1.0.0', priceCents: 500);
      final repriced = SkillListing(
        skillId: l.skillId, version: l.version, name: l.name, description: l.description,
        authorId: l.authorId, authorPub: l.authorPub, capabilities: l.capabilities,
        risk: l.risk, contentHash: l.contentHash,
        pricing: const SkillPricing(priceCents: 1), publishedAtMs: l.publishedAtMs,
        signatureB64: l.signatureB64,
      );
      expect((await SkillRegistry.verifyListing(repriced)).code,
          SkillVerifyCode.badSignature);
    });

    test('★ 铁律 1：签名覆盖内容哈希 —— 换内容必然验签失败', () async {
      final kp = await _kp();
      final l = await _sign(kp: kp, skillId: 'wold.skill.t', version: '1.0.0', content: 'A');
      final rehashed = SkillListing(
        skillId: l.skillId, version: l.version, name: l.name, description: l.description,
        authorId: l.authorId, authorPub: l.authorPub, capabilities: l.capabilities,
        risk: l.risk, contentHash: SkillRegistry.contentHashOf('B'),
        pricing: l.pricing, publishedAtMs: l.publishedAtMs, signatureB64: l.signatureB64,
      );
      expect((await SkillRegistry.verifyListing(rehashed)).code,
          SkillVerifyCode.badSignature);
    });

    test('无签名 / 坏公钥 / 未知风险码 / 内容不符 各自落到对应码', () async {
      final kp = await _kp();
      final l = await _sign(kp: kp, skillId: 'wold.skill.t', version: '1.0.0', content: 'A');
      expect((await SkillRegistry.verifyListing(l.copyWith(signatureB64: ''))).code,
          SkillVerifyCode.missingFields);

      final badPub = SkillListing(
        skillId: 's', version: '1.0.0', name: 'n', authorId: 'a', authorPub: 'xyz',
        contentHash: 'h', publishedAtMs: kNow, signatureB64: l.signatureB64);
      expect((await SkillRegistry.verifyListing(badPub)).code, SkillVerifyCode.badPubkey);

      final badRisk = SkillListing(
        skillId: 's', version: '1.0.0', name: 'n', authorId: 'a', authorPub: l.authorPub,
        risk: 'nuke', contentHash: 'h', publishedAtMs: kNow, signatureB64: l.signatureB64);
      expect((await SkillRegistry.verifyListing(badRisk)).code, SkillVerifyCode.badRisk);

      expect((await SkillRegistry.verifyListing(l, content: 'TAMPER')).code,
          SkillVerifyCode.hashMismatch);
      expect((await SkillRegistry.verifyListing(l, content: 'A')).ok, isTrue);
    });

    test('已吊销 → 即使签名有效也不得安装（吊销先于验签）', () async {
      final kp = await _kp();
      final l = await _sign(kp: kp, skillId: 'wold.skill.t', version: '1.0.0');
      expect((await SkillRegistry.verifyListing(l, revokedKeys: {l.key})).code,
          SkillVerifyCode.revoked);
      expect((await SkillRegistry.verifyListing(l, revokedKeys: {'${l.skillId}@'})).code,
          SkillVerifyCode.revoked);
    });
  });

  group('上架判定：不换作者 / 同版本不换内容 / 版本只许前进', () {
    test('全新 → accepted；同版本同内容 → duplicate', () async {
      final kp = await _kp();
      final a = await _sign(kp: kp, skillId: 's', version: '1.0.0', content: 'A', priceCents: 100);
      expect(SkillRegistry.publishDecision(incoming: a, existing: const []).code,
          PublishCode.accepted);
      final b = await _sign(kp: kp, skillId: 's', version: '1.0.0', content: 'A', priceCents: 100);
      expect(SkillRegistry.publishDecision(incoming: b, existing: [a]).code,
          PublishCode.duplicate);
    });

    test('★ 同版本换内容 → version_conflict（拦住"收钱后换内容"）', () async {
      final kp = await _kp();
      final a = await _sign(kp: kp, skillId: 's', version: '1.0.0', content: 'A');
      final b = await _sign(kp: kp, skillId: 's', version: '1.0.0', content: 'B');
      expect(SkillRegistry.publishDecision(incoming: b, existing: [a]).code,
          PublishCode.versionConflict);
    });

    test('★ 同 skillId 换作者 → author_changed（防抢注）', () async {
      final kp1 = await _kp();
      final kp2 = await _kp();
      final a = await _sign(kp: kp1, skillId: 's', version: '1.0.0');
      final b = await _sign(kp: kp2, skillId: 's', version: '2.0.0');
      expect(SkillRegistry.publishDecision(incoming: b, existing: [a]).code,
          PublishCode.authorChanged);
    });

    test('版本只许前进', () async {
      final kp = await _kp();
      final a = await _sign(kp: kp, skillId: 's', version: '1.2.0');
      final lower = await _sign(kp: kp, skillId: 's', version: '1.1.9');
      final higher = await _sign(kp: kp, skillId: 's', version: '1.2.1');
      expect(SkillRegistry.publishDecision(incoming: lower, existing: [a]).code,
          PublishCode.versionNotIncreased);
      expect(SkillRegistry.publishDecision(incoming: higher, existing: [a]).code,
          PublishCode.accepted);
    });

    test('版本比较口径：数字段 / 缺段 / 跨大版本', () {
      expect(SkillRegistry.compareVersion('1.2.10', '1.2.9'), greaterThan(0));
      expect(SkillRegistry.compareVersion('1.0', '1.0.0'), 0);
      expect(SkillRegistry.compareVersion('2.0.0', '1.9.9'), greaterThan(0));
    });
  });

  group('分成：逐分守恒 + 余数归作者 + 单层红线', () {
    test('author + platform + referrer == amount（逐分守恒）', () {
      for (final amt in [1, 3, 7, 99, 101, 333, 1000, 1999, 10001, 123456]) {
        final s = RevenueShare.split(amt, platformBps: 3000, referrerBps: 1000);
        expect(s.total, amt, reason: '金额 $amt 分账必须逐分守恒');
      }
    });

    test('余数归作者（不从创作者身上扣）', () {
      final s = RevenueShare.split(101, platformBps: 3000, referrerBps: 1000);
      expect(s.platformCents, 30);
      expect(s.referrerCents, 10);
      expect(s.authorCents, 61);
    });

    test('无推荐人 → 那一份不产生（绝不先扣再留）', () {
      final s = RevenueShare.split(101, platformBps: 3000, referrerBps: 0);
      expect(s.referrerCents, 0);
      expect(s.total, 101);
    });

    test('★ PRD §9.1 红线：分成层数恒为 1', () {
      expect(RevenueShare.maxReferrerLevels, 1);
    });

    test('bps 溢出 / 负数金额 → 抛错（宁可炸掉也不静默截断）', () {
      expect(() => RevenueShare.split(100, platformBps: 9000, referrerBps: 2000),
          throwsArgumentError);
      expect(() => RevenueShare.split(-1), throwsArgumentError);
    });

    test('★ 账本条目没有 level/upline/parent 字段（结构上写不出多级）', () {
      final e = PayoutLedgerEntry(
        purchaseId: 'P', skillId: 's', version: '1.0.0', authorPub: 'pub',
        buyerId: 'b', amountCents: 101,
        split: const RevenueSplit(authorCents: 61, platformCents: 30, referrerCents: 10),
        referrerId: 'r', atMs: kNow,
      );
      expect(e.balanced, isTrue);
      final m = e.toMap();
      expect(m.containsKey('level'), isFalse);
      expect(m.containsKey('upline'), isFalse);
      expect(m.containsKey('parent'), isFalse);
      expect(e.entryHash().length, 64);
    });
  });

  group('服务层：上架 → 安装 → 吊销 → 记账', () {
    test('publish 验签不过 → unverified；合法 → accepted 并落库', () async {
      final kp = await _kp();
      final store = MemorySkillStore();
      final svc = SkillRegistryService(store: store);
      final l = await _sign(kp: kp, skillId: 's', version: '1.0.0');
      expect((await svc.publish(l.copyWith(signatureB64: ''))).code,
          PublishCode.unverified);
      expect((await svc.publish(l)).code, PublishCode.accepted);
      expect(await store.listing('s', '1.0.0'), isNotNull);
    });

    test('install 复算内容；吊销后 install → revoked；未上架 → 拒', () async {
      final kp = await _kp();
      final store = MemorySkillStore();
      final svc = SkillRegistryService(store: store);
      final l = await _sign(kp: kp, skillId: 's', version: '1.0.0', content: 'GOOD');
      await svc.publish(l);

      expect((await svc.install('s', '1.0.0', content: 'GOOD')).ok, isTrue);
      expect((await svc.install('s', '1.0.0', content: 'BAD')).code,
          SkillVerifyCode.hashMismatch);
      expect((await svc.install('nope', '1.0.0')).code, SkillVerifyCode.missingFields);

      final rev = SkillRevocation(
          skillId: 's', authorPub: l.authorPub, atMs: kNow);
      final sig = await Ed25519().sign(rev.canonicalBytes(), keyPair: kp);
      final signedRev = SkillRevocation(
          skillId: 's', authorPub: l.authorPub, atMs: kNow,
          signatureB64: base64Encode(sig.bytes));
      expect((await svc.revoke(signedRev)).ok, isTrue);
      expect((await svc.install('s', '1.0.0', content: 'GOOD')).code,
          SkillVerifyCode.revoked);
    });

    test('recordPurchase：付费产生平衡分账并幂等；免费不产生', () async {
      final kp = await _kp();
      final store = MemorySkillStore();
      final svc = SkillRegistryService(store: store);
      final paid = await _sign(kp: kp, skillId: 'paid', version: '1.0.0', priceCents: 1999);
      final free = await _sign(kp: kp, skillId: 'free', version: '1.0.0');
      await svc.publish(paid);
      await svc.publish(free);

      final e = await svc.recordPurchase(
        purchaseId: 'B1', listing: paid, buyerId: 'AG-9', amountCents: 1999,
        referrerId: 'AG-8', atMs: kNow);
      expect(e, isNotNull);
      expect(e!.balanced, isTrue);
      expect(e.split.total, 1999);

      await svc.recordPurchase(
        purchaseId: 'B1', listing: paid, buyerId: 'AG-9', amountCents: 1999,
        referrerId: 'AG-8', atMs: kNow);
      expect((await store.allPayouts()).length, 1, reason: '同 purchaseId 只落一条');

      expect(
        await svc.recordPurchase(
            purchaseId: 'B2', listing: free, buyerId: 'AG-9', amountCents: 0, atMs: kNow),
        isNull,
        reason: '免费技能不产生分账',
      );
    });
  });

  group('序列化往返', () {
    test('SkillListing toMap → fromMap 不掉字段', () async {
      final kp = await _kp();
      final l = await _sign(kp: kp, skillId: 's', version: '1.2.3',
          content: 'C', priceCents: 700, caps: ['net', 'llm'], risk: SkillRisk.high);
      final r = SkillListing.fromMap(Map<String, dynamic>.from(l.toMap()));
      expect(r.skillId, l.skillId);
      expect(r.version, l.version);
      expect(r.authorPub, l.authorPub);
      expect(r.contentHash, l.contentHash);
      expect(r.pricing.priceCents, 700);
      expect(r.risk, SkillRisk.high);
      expect(r.capabilities, l.capabilities);
      expect(r.signatureB64, l.signatureB64);
      // 往返后签名仍然验得过（canonical 不因序列化变形）
      expect((await SkillRegistry.verifyListing(r)).ok, isTrue);
    });

    test('canonical 对能力顺序不敏感（排序后入载荷）', () async {
      final kp = await _kp();
      final a = await _sign(kp: kp, skillId: 's', version: '1.0.0', caps: ['net', 'llm']);
      final b = await _sign(kp: kp, skillId: 's', version: '1.0.0', caps: ['llm', 'net']);
      expect(a.canonical(), b.canonical());
    });
  });
}
