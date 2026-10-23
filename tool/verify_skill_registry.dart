// 纯 Dart 校验脚本：M9「技能注册表 + 作者分成 + 签名上架」。
// 运行：dart run tool/verify_skill_registry.dart
//
// 为什么这三件事必须一起验：
//   少了任一件，"生态"就退化成别的东西 ——
//   只有目录没签名 → 目录＝平台说了算；只有签名没版本幂等 → 可以"低价上架、收钱后换内容"；
//   只有分成没可复算账本 → 只能"信平台"。所以本脚本盯住四类**编译通过但语义已错**的缺陷：
//   ① 清单能不带有效签名就进注册表（或被改价/换内容后仍验得过）；
//   ② 同 skillId 能换作者 / 同版本能换内容 / 版本能倒退；
//   ③ 分账出现多级（撞《禁止传销条例》红线）或"四舍五入吞掉作者的钱"；
//   ④ Dart 端与 Node Hub 端算出的**签名载荷**不一致（作者签得对，Hub 却一律拒）。
//
// 全部用真 Ed25519 密钥对当场签名复算；DDL 漂移与 Hub 一致性用**源文本比对**
// （不需要真 sqlite / 不需要起 Node），与 verify_persona_role.dart 同一套办法。

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/skill_registry.dart';

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
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final head = parts.first.toUpperCase();
    if (head == 'PRIMARY' ||
        head == 'UNIQUE' ||
        head == 'FOREIGN' ||
        head == 'INDEX' ||
        head == 'CONSTRAINT') {
      continue;
    }
    cols.add(parts.first);
  }
  return cols;
}

/// 校验一段源码里若干键名是否**按给定顺序**出现（签名载荷键序一致性的硬检查）。
bool _keysInOrder(String region, List<String> keys) {
  var cursor = -1;
  for (final k in keys) {
    final idx = region.indexOf(k, cursor + 1);
    if (idx < 0) return false;
    cursor = idx;
  }
  return true;
}

/// 当场签一份清单。
Future<SkillListing> _sign({
  required SimpleKeyPair kp,
  required String skillId,
  required String version,
  String name = '技能',
  String authorId = 'AG-1',
  List<String> caps = const [],
  String risk = SkillRisk.low,
  required String content,
  int priceCents = 0,
  int atMs = kNow,
}) async {
  final pub = await kp.extractPublicKey();
  final base = SkillListing(
    skillId: skillId,
    version: version,
    name: name,
    description: 'desc',
    authorId: authorId,
    authorPub: AgentProtocol.base58Encode(pub.bytes),
    capabilities: caps,
    risk: risk,
    contentHash: SkillRegistry.contentHashOf(content),
    pricing: SkillPricing(priceCents: priceCents),
    publishedAtMs: atMs,
  );
  final sig = await Ed25519().sign(base.canonicalBytes(), keyPair: kp);
  return base.copyWith(signatureB64: base64Encode(sig.bytes));
}

Future<void> main() async {
  final kp = await Ed25519().newKeyPair();
  final kp2 = await Ed25519().newKeyPair();

  // =========================================================================
  print('--- ① 验签 fail-closed：改价 / 换内容 / 坏公钥 / 无签名一律拒绝 ---');
  // =========================================================================
  final good = await _sign(kp: kp, skillId: 'wold.skill.translate', version: '1.0.0',
      content: 'CONTENT_V1', priceCents: 500, caps: ['net', 'llm'], risk: SkillRisk.medium);
  var v = await SkillRegistry.verifyListing(good);
  check(v.ok && v.code == SkillVerifyCode.ok, '作者合法签名 → 验签通过');
  check(v.installable, '验签通过即 installable');

  check((await SkillRegistry.verifyListing(good.copyWith(signatureB64: ''))).code ==
      SkillVerifyCode.missingFields, '无签名 → missing_fields');

  final badPub = SkillListing(
    skillId: good.skillId, version: good.version, name: good.name,
    description: good.description, authorId: good.authorId, authorPub: 'abc',
    capabilities: good.capabilities, risk: good.risk, contentHash: good.contentHash,
    pricing: good.pricing, publishedAtMs: good.publishedAtMs, signatureB64: good.signatureB64,
  );
  check((await SkillRegistry.verifyListing(badPub)).code ==
      SkillVerifyCode.badPubkey, '坏公钥（长度不足 32B）→ bad_pubkey');

  // 铁律 1 的核心：签名覆盖定价与内容哈希 → 事后改价必然验签失败
  final repriced = SkillListing(
    skillId: good.skillId, version: good.version, name: good.name,
    description: good.description, authorId: good.authorId, authorPub: good.authorPub,
    capabilities: good.capabilities, risk: good.risk, contentHash: good.contentHash,
    pricing: const SkillPricing(priceCents: 1), // 从 500 改成 1
    publishedAtMs: good.publishedAtMs, signatureB64: good.signatureB64,
  );
  check((await SkillRegistry.verifyListing(repriced)).code ==
      SkillVerifyCode.badSignature, '改价后（签名不动）→ bad_signature');

  // 换内容（content_hash 被改）同理
  final rehashed = SkillListing(
    skillId: good.skillId, version: good.version, name: good.name,
    description: good.description, authorId: good.authorId, authorPub: good.authorPub,
    capabilities: good.capabilities, risk: good.risk,
    contentHash: SkillRegistry.contentHashOf('CONTENT_V2'), // 换成另一份内容
    pricing: good.pricing, publishedAtMs: good.publishedAtMs, signatureB64: good.signatureB64,
  );
  check((await SkillRegistry.verifyListing(rehashed)).code ==
      SkillVerifyCode.badSignature, '换内容哈希后 → bad_signature');

  final shortSig = good.copyWith(signatureB64: base64Encode(List.filled(63, 0)));
  check((await SkillRegistry.verifyListing(shortSig)).code ==
      SkillVerifyCode.badSignature, '签名长度不对（63B）→ 拒绝（fail-closed）');

  final badRisk = SkillListing(
    skillId: good.skillId, version: good.version, name: good.name,
    description: good.description, authorId: good.authorId, authorPub: good.authorPub,
    capabilities: good.capabilities, risk: 'nuke', contentHash: good.contentHash,
    pricing: good.pricing, publishedAtMs: good.publishedAtMs, signatureB64: good.signatureB64,
  );
  check((await SkillRegistry.verifyListing(badRisk)).code == SkillVerifyCode.badRisk,
      '未知风险码 → bad_risk（防止绕过授权弹窗）');

  // 安装前复算真实内容：清单声明与真实内容不符 → 拒
  check((await SkillRegistry.verifyListing(good, content: 'TAMPERED')).code ==
      SkillVerifyCode.hashMismatch, '真实内容与清单声明不符 → hash_mismatch');
  check((await SkillRegistry.verifyListing(good, content: 'CONTENT_V1')).ok,
      '真实内容与声明一致 → 通过');

  check((await SkillRegistry.verifyListing(good, revokedKeys: {'${good.skillId}@'})).code ==
      SkillVerifyCode.revoked, '作者全版本吊销 → revoked');
  check((await SkillRegistry.verifyListing(good, revokedKeys: {good.key})).code ==
      SkillVerifyCode.revoked, '作者按版本吊销 → revoked');

  // =========================================================================
  print('--- ② 上架判定：不换作者 / 同版本不换内容 / 版本只许前进 ---');
  // =========================================================================
  check(SkillRegistry.publishDecision(incoming: good, existing: const []).code ==
      PublishCode.accepted, '全新技能 → accepted');

  final sameSame = await _sign(kp: kp, skillId: good.skillId, version: '1.0.0',
      content: 'CONTENT_V1', priceCents: 500, caps: ['llm', 'net'], risk: SkillRisk.medium);
  check(SkillRegistry.publishDecision(incoming: sameSame, existing: [good]).code ==
      PublishCode.duplicate, '同版本同内容同价 → duplicate（幂等）');

  final sameVerDiff = await _sign(kp: kp, skillId: good.skillId, version: '1.0.0',
      content: 'CONTENT_X', priceCents: 500, caps: ['net', 'llm'], risk: SkillRisk.medium);
  check(SkillRegistry.publishDecision(incoming: sameVerDiff, existing: [good]).code ==
      PublishCode.versionConflict, '同版本内容不同 → version_conflict（拦住"收钱后换内容"）');

  final otherAuthor = await _sign(kp: kp2, skillId: good.skillId, version: '9.9.9',
      content: 'evil', priceCents: 0);
  check(SkillRegistry.publishDecision(incoming: otherAuthor, existing: [good]).code ==
      PublishCode.authorChanged, '同 skillId 换作者公钥 → author_changed（防抢注）');

  final v099 = await _sign(kp: kp, skillId: good.skillId, version: '0.9.9', content: 'old');
  check(SkillRegistry.publishDecision(incoming: v099, existing: [good]).code ==
      PublishCode.versionNotIncreased, '低于已上架最高版本 → version_not_increased');

  final v101 = await _sign(kp: kp, skillId: good.skillId, version: '1.0.1', content: 'new');
  check(SkillRegistry.publishDecision(incoming: v101, existing: [good]).code ==
      PublishCode.accepted, '高于最高版本 → accepted');

  // 版本比较口径
  check(SkillRegistry.compareVersion('1.2.10', '1.2.9') > 0, '1.2.10 > 1.2.9（数字段比较）');
  check(SkillRegistry.compareVersion('1.0', '1.0.0') == 0, '1.0 == 1.0.0（缺段视为 0）');
  check(SkillRegistry.compareVersion('2.0.0', '1.9.9') > 0, '跨大版本正确');

  // =========================================================================
  print('--- ③ 吊销：只有作者本人、且必须签名 ---');
  // =========================================================================
  Future<SkillRevocation> signRev({
    required SimpleKeyPair withKp,
    required String skillId,
    required String authorPub,
    String version = '',
  }) async {
    final base = SkillRevocation(
        skillId: skillId, version: version, authorPub: authorPub, reason: 'mistake', atMs: kNow);
    final sig = await Ed25519().sign(base.canonicalBytes(), keyPair: withKp);
    return SkillRevocation(
        skillId: skillId, version: version, authorPub: authorPub, reason: 'mistake',
        atMs: kNow, signatureB64: base64Encode(sig.bytes));
  }

  final pubB58 = good.authorPub;
  final revOk = await signRev(withKp: kp, skillId: good.skillId, authorPub: pubB58, version: '1.0.0');
  check((await SkillRegistry.verifyRevocation(revOk, listingAuthorPub: pubB58)).ok,
      '作者本人签名吊销 → 通过');

  final revImposter = await signRev(withKp: kp2, skillId: good.skillId, authorPub: pubB58);
  check((await SkillRegistry.verifyRevocation(revImposter, listingAuthorPub: pubB58)).code ==
      SkillVerifyCode.badSignature, '他人冒名吊销（签名对不上） → 拒');

  // 关键：声明公钥 ≠ 已上架清单作者公钥 → 一律拒（否则任何人可清场）
  final pub2 = AgentProtocol.base58Encode((await kp2.extractPublicKey()).bytes);
  final revWrongPub = await signRev(withKp: kp2, skillId: good.skillId, authorPub: pub2);
  check((await SkillRegistry.verifyRevocation(revWrongPub, listingAuthorPub: pubB58)).code !=
      SkillVerifyCode.ok, '声明公钥 ≠ 清单作者公钥 → 拒');

  check(SkillRevocation(skillId: 'x', authorPub: 'p', atMs: 0).covers('x', '1.0.0') &&
      SkillRevocation(skillId: 'x', authorPub: 'p', atMs: 0).covers('x', '9.9.9'),
      '空 version 的吊销覆盖全部版本');
  check(SkillRevocation(skillId: 'x', version: '1.0.0', authorPub: 'p', atMs: 0).covers('x', '1.0.0') &&
      !SkillRevocation(skillId: 'x', version: '1.0.0', authorPub: 'p', atMs: 0).covers('x', '2.0.0'),
      '带 version 的吊销只覆盖该版本');

  // =========================================================================
  print('--- ④ 分账：逐分守恒 + 余数归作者 + 单层红线 ---');
  // =========================================================================
  // 遍历一批"容易被四舍五入坑到"的金额
  var allExact = true;
  for (final amt in [1, 3, 7, 99, 101, 333, 1000, 1999, 10001, 123456]) {
    final s = RevenueShare.split(amt, platformBps: 3000, referrerBps: 1000);
    if (s.total != amt) allExact = false;
    if (s.authorCents + s.platformCents + s.referrerCents != amt) allExact = false;
  }
  check(allExact, 'author+platform+referrer == amount（逐分守恒，10 组金额）');

  final s101 = RevenueShare.split(101, platformBps: 3000, referrerBps: 1000);
  check(s101.platformCents == 30 && s101.referrerCents == 10 && s101.authorCents == 61,
      '101 分：平台 30 / 推荐 10 / 作者 61（余数归作者，不从作者身上扣）');
  check(s101.total == 101, '101 分分账逐分守恒');

  final sNoRef = RevenueShare.split(101, platformBps: 3000, referrerBps: 0);
  check(sNoRef.referrerCents == 0 && sNoRef.authorCents == 101 - sNoRef.platformCents,
      '无推荐人 → 不产生推荐分成那一份（绝不先扣再留）');

  check(RevenueShare.maxReferrerLevels == 1, 'PRD §9.1 红线：分成层数恒为 1');
  check(RevenueShare.bpsDenominator == 10000, 'bps 分母 = 10000');

  var threw = false;
  try {
    RevenueShare.split(100, platformBps: 9000, referrerBps: 2000);
  } catch (_) {
    threw = true;
  }
  check(threw, 'platformBps+referrerBps>10000 → 抛错（宁可炸掉也不静默截断）');

  threw = false;
  try {
    RevenueShare.split(-1);
  } catch (_) {
    threw = true;
  }
  check(threw, '负数金额 → 抛错');

  // 账本条目形态：无 level / upline / parent 字段
  final entry = PayoutLedgerEntry(
    purchaseId: 'P1', skillId: good.skillId, version: good.version, authorPub: good.authorPub,
    buyerId: 'AG-9', amountCents: 101, split: s101, referrerId: 'AG-8', atMs: kNow,
  );
  check(entry.balanced, '账本条目自检 balanced == true');
  final em = entry.toMap();
  check(!em.containsKey('level') && !em.containsKey('upline') && !em.containsKey('parent'),
      '账本条目 toMap 不含 level/upline/parent（结构上写不出多级）');
  check(entry.entryHash().length == 64, 'entryHash 为 sha256 hex（可进 §16 日志）');
  check(PayoutLedgerEntry.fromMap(entry.toMap()).split.total == 101,
      '账本条目序列化往返不掉钱');

  // =========================================================================
  print('--- ⑤ 服务层：上架→安装→吊销→记账（内存 store 全链路） ---');
  // =========================================================================
  final store = MemorySkillStore();
  final svc = SkillRegistryService(store: store);

  check((await svc.publish(good)).code == PublishCode.accepted, 'publish 合法清单 → accepted');
  check((await store.listing(good.skillId, good.version)) != null, 'publish 后已落库');
  check((await svc.publish(sameSame)).code == PublishCode.duplicate, '重复上架 → duplicate');

  final unsigned = good.copyWith(signatureB64: '');
  check((await svc.publish(unsigned)).code == PublishCode.unverified,
      '未签名清单 → unverified（注册表先问"是不是作者签的"）');

  check((await svc.install(good.skillId, good.version, content: 'CONTENT_V1')).ok,
      'install 复算内容 → 通过');
  check((await svc.install(good.skillId, good.version, content: 'TAMPER')).code ==
      SkillVerifyCode.hashMismatch, 'install 内容不符 → 拒');
  check((await svc.install('no.such.skill', '1.0.0')).code == SkillVerifyCode.missingFields,
      'install 未上架技能 → 拒（fail-closed）');

  check((await svc.revoke(revImposter)).code != SkillVerifyCode.ok, '服务层：冒名吊销 → 拒');
  check((await svc.revoke(revOk)).ok, '服务层：作者吊销 → 通过');
  check((await svc.install(good.skillId, good.version, content: 'CONTENT_V1')).code ==
      SkillVerifyCode.revoked, '吊销后安装 → revoked');

  final paid = await _sign(kp: kp, skillId: 'wold.skill.paid', version: '1.0.0',
      content: 'PAID', priceCents: 1999);
  await svc.publish(paid);
  final pe = await svc.recordPurchase(
    purchaseId: 'BUY-1', listing: paid, buyerId: 'AG-9', amountCents: 1999,
    referrerId: 'AG-8', atMs: kNow);
  check(pe != null && pe.balanced, '付费购买 → 产生平衡的分账单');
  check(pe!.split.authorCents + pe.split.platformCents + pe.split.referrerCents == 1999,
      '付费分账逐分守恒');
  final pe2 = await svc.recordPurchase(
    purchaseId: 'BUY-1', listing: paid, buyerId: 'AG-9', amountCents: 1999,
    referrerId: 'AG-8', atMs: kNow);
  check(identical(pe, pe2) || pe2!.purchaseId == 'BUY-1', '同 purchaseId 重复记账 → 幂等');
  check((await store.allPayouts()).length == 1, '重复记账不产生第二条（幂等由主键/键保证）');

  final free = await _sign(kp: kp, skillId: 'wold.skill.free', version: '1.0.0', content: 'FREE');
  await svc.publish(free);
  check(await svc.recordPurchase(
          purchaseId: 'BUY-2', listing: free, buyerId: 'AG-9', amountCents: 0, atMs: kNow) ==
      null, '免费技能 → 不产生分账');
  check(!PurchaseDecision.needsPayout(free) && PurchaseDecision.needsPayout(paid),
      'needsPayout：免费 false / 付费 true');

  check((await store.payoutsOf(paid.authorPub)).length == 1, '按作者公钥可查回自己的分账');

  // =========================================================================
  print('--- ⑥ DDL ↔ 序列化字段漂移（源文本比对） ---');
  // =========================================================================
  final dbSrc = _stripComments(File('lib/core/db_helper.dart').readAsStringSync());
  // 坑：这里**不能**写死 `== 28`。本脚本要验的是"v28 的迁移已经落地"，
  // 而后续里程碑（如 M8 → v29）必然会把版本号往上推 —— 写死等于每次升级都红一次。
  // 改成"至少 28"，语义才对。
  final verM = RegExp(r'schemaVersion\s*=\s*(\d+)').firstMatch(dbSrc);
  final ver = verM == null ? -1 : int.parse(verM.group(1)!);
  check(ver >= 28, 'DBHelper.schemaVersion >= 28（v28 迁移已落地，当前 $ver）');
  check(dbSrc.contains('28: _migrateV28'), '_migrations 注册了 28');

  final listCols = _ddlColumns(dbSrc, 'skill_listings');
  check(listCols.isNotEmpty, 'skill_listings DDL 存在');
  check(listCols.difference(good.toMap().keys.toSet()).isEmpty &&
      good.toMap().keys.toSet().difference(listCols).isEmpty,
      'skill_listings 列集合 == SkillListing.toMap 键集合');

  final revCols = _ddlColumns(dbSrc, 'skill_revoked');
  final revKeys = SkillRevocation(skillId: 'a', authorPub: 'b', atMs: 1).toMap().keys.toSet();
  check(revCols.difference(revKeys).isEmpty && revKeys.difference(revCols).isEmpty,
      'skill_revoked 列集合 == SkillRevocation.toMap 键集合');

  final payCols = _ddlColumns(dbSrc, 'payout_ledger');
  final payKeys = entry.toMap().keys.toSet();
  check(payCols.difference(payKeys).isEmpty && payKeys.difference(payCols).isEmpty,
      'payout_ledger 列集合 == PayoutLedgerEntry.toMap 键集合');

  check(!payCols.contains('level') && !payCols.contains('upline') && !payCols.contains('parent'),
      'payout_ledger DDL 不含 level/upline/parent（单层红线落到字段层）');
  check(payCols.contains('referrer_id'), 'payout_ledger 只有单个 referrer_id（至多一层）');

  // =========================================================================
  print('--- ⑦ 与 plugin_bus 的风险码一致 + WoldRuntime 接线 ---');
  // =========================================================================
  final busSrc = _stripComments(File('lib/core/plugin_bus.dart').readAsStringSync());
  check(busSrc.contains("'low'") && busSrc.contains("'medium'") && busSrc.contains("'high'"),
      'plugin_bus 的 PluginRisk 用了 low/medium/high 字面量（与 SkillRisk 对齐）');

  final rtSrc = _stripComments(File('lib/core/wold_runtime.dart').readAsStringSync());
  check(rtSrc.contains('skillStore = DbSkillStore()'), 'WoldRuntime 建了 DbSkillStore');
  check(rtSrc.contains('skills = SkillRegistryService('), 'WoldRuntime 建了 SkillRegistryService');
  check(rtSrc.contains("import 'skill_registry.dart'") && rtSrc.contains("import 'skill_store_db.dart'"),
      'WoldRuntime 引入了注册表与存储实现');

  // =========================================================================
  print('--- ⑧ Dart ↔ Node Hub 签名载荷键序一致（最易埋雷处） ---');
  // =========================================================================
  final libSrc = _stripComments(File('lib/core/skill_registry.dart').readAsStringSync());
  const listKeys = [
    'alg', 'skill_id', 'version', 'name', 'description', 'author_id', 'author_pub',
    'capabilities', 'risk', 'content_hash', 'price_cents', 'currency', 'published_at',
  ];
  // 守卫：**段找得到**才 substring。函数被搬运/改名时 `indexOf` 返回 -1，
  // 原写法 `substring(-1, …)` 会抛 RangeError 把整脚本崩掉（看起来像环境问题，
  // 掩盖真实病灶）；加了守卫就退化成一条干净的 FAIL，直指"载荷函数不在预期位置"。
  // 与下面 JS 侧 `jsCanonStart >= 0 && jsCanonEnd > jsCanonStart` 保持对称。
  final dartCanonStart = libSrc.indexOf('String canonical() {');
  final dartCanonEnd = dartCanonStart < 0
      ? -1
      : libSrc.indexOf('List<int> canonicalBytes()', dartCanonStart);
  check(dartCanonStart >= 0 && dartCanonEnd > dartCanonStart, 'Dart 清单 canonical 段找得到');
  final dartRegion = (dartCanonStart >= 0 && dartCanonEnd > dartCanonStart)
      ? libSrc.substring(dartCanonStart, dartCanonEnd)
      : '';
  check(_keysInOrder(dartRegion, listKeys), 'Dart 清单载荷键序正确');

  final hubSrc = _stripComments(File('lib/hub/hub.js').readAsStringSync());
  // v1.14：签名载荷已抽到协议包（单一事实源），键序断言改扫**包源码** ——
  // hub.js 现在只 require `@woldworld/protocol`，函数体不在它里面。
  final protoSrc = _stripComments(File('packages/protocol/src/skill.js').readAsStringSync());
  final jsCanonStart = protoSrc.indexOf('function canonical(');
  final jsCanonEnd = protoSrc.indexOf('function sigValid(', jsCanonStart);
  check(jsCanonStart >= 0 && jsCanonEnd > jsCanonStart, '协议包里找得到清单 canonical 段');
  final jsRegion = protoSrc.substring(jsCanonStart, jsCanonEnd);
  check(_keysInOrder(jsRegion, listKeys), 'Node Hub 清单载荷键序与 Dart 一致');

  const revOrderKeys = ['alg', 'kind', 'skill_id', 'version', 'author_pub', 'reason', 'at'];
  final revClassStart = libSrc.indexOf('class SkillRevocation');
  final dartRevStart = revClassStart < 0
      ? -1
      : libSrc.indexOf('String canonical() => jsonEncode', revClassStart);
  // 上界也要夹住：`+ 400` 可能越界，substring 同样会崩 —— 段没找到就退回空串，交给断言判 FAIL。
  final dartRevEnd = dartRevStart < 0 ? -1 : (dartRevStart + 400).clamp(0, libSrc.length);
  check(dartRevStart >= 0 && dartRevEnd > dartRevStart, 'Dart 吊销 canonical 段找得到');
  final dartRevRegion = (dartRevStart >= 0 && dartRevEnd > dartRevStart)
      ? libSrc.substring(dartRevStart, dartRevEnd)
      : '';
  check(_keysInOrder(dartRevRegion, revOrderKeys), 'Dart 吊销载荷键序正确');
  final jsRevStart = protoSrc.indexOf('function revocationCanonical(');
  final jsRevEnd = protoSrc.indexOf('function revocationSigValid(', jsRevStart);
  check(jsRevStart >= 0 && jsRevEnd > jsRevStart, '协议包里找得到吊销 canonical 段');
  check(_keysInOrder(protoSrc.substring(jsRevStart, jsRevEnd), revOrderKeys),
      'Node Hub 吊销载荷键序与 Dart 一致');

  check(hubSrc.contains("'/api/skills/publish'") &&
      hubSrc.contains("'/api/skills/revoke'") &&
      hubSrc.contains("'/api/skills/payout'") &&
      hubSrc.contains("'/api/skills'"),
      'Hub 暴露 publish/revoke/payout/list 四组技能端点');
  check(hubSrc.contains('author_pub_mismatch') && hubSrc.contains('unbalanced_split'),
      'Hub 侧拦住"替别人上架"与"不平的分账"');

  // =========================================================================
  print('--- ⑨ 导出跨语言探针（供 tool/verify_skill_hub.js 用 Node 复验） ---');
  // =========================================================================
  final probe = await _sign(
      kp: kp, skillId: 'wold.skill.crosslang', version: '1.0.0',
      content: 'CROSS_LANG', priceCents: 1234, caps: ['net', 'llm'], risk: SkillRisk.medium);
  File('tool/_m9_signed_listing.json').writeAsStringSync(jsonEncode(probe.toMap()));
  File('tool/_m9_canonical.txt').writeAsStringSync(probe.canonical());
  check(File('tool/_m9_signed_listing.json').existsSync() &&
      File('tool/_m9_canonical.txt').existsSync(),
      '已导出签名清单 + canonical（Dart §⑨ 产物）');

  // =========================================================================
  print('');
  print('================ M9 技能注册表校验 ================');
  // ⚠️ 结尾必须是标准的 `PASS=<n> FAIL=<n>`（本项目扫脚本读数靠它抓）。
  // 曾写成 `……：$_pass PASS / $_fail FAIL` —— 全角冒号紧贴数字，控制台编码串扰会
  // 把首位数字吞掉，汇总脚本据此算出 4 而不是 84。读数格式不是审美问题。
  print('PASS=$_pass FAIL=$_fail');
  if (_fail != 0) exit(1);
}
