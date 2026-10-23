/// M9 · 插件与技能生态（PRD §4 M9）：**技能注册表 + 作者分成 + 签名上架**。
///
/// ---------------------------------------------------------------------------
/// 这三件事为什么必须一起做
/// ---------------------------------------------------------------------------
/// 少了任何一件，"生态"都会退化成别的东西：
/// - 只有注册表、没有**作者签名** → 注册表就是"平台说了算的清单"，
///   平台（或攻破 Hub 的人）可以随时换掉别人技能的内容，作者无从自证；
/// - 只有签名、没有**版本幂等/防换手** → 作者可以"先低价上架、用户付钱后再改内容"，
///   或者别人拿同一 skillId **抢注**他积累的声望；
/// - 只有分成、没有**可验证账本** → 分成比例只能"信平台"，
///   而 PRD §16 的整个技术优势恰恰是"你不必相信我，你可以验我"。
///
/// 所以本模块交付一个闭环：
/// **作者签一份清单 → 任何人可离线验 → 注册表只接受"签名有效且版本单调"的上架 →
/// 购买时按固定比例精确分账 → 分账写进可复算的账本。**
///
/// ---------------------------------------------------------------------------
/// 四条铁律（本层强制，且全部可离线复算）
/// ---------------------------------------------------------------------------
/// 1. **清单必须由作者私钥签名**，签名覆盖**全部定价与内容哈希** ——
///    因此"事后改价""事后换内容"都必然让签名失效。验不过 → 一律不得安装（fail-closed）。
/// 2. **同 (skillId, version) 只能有一个内容**；同 skillId **不得换作者公钥**。
///    防的是"付过钱之后被换内容"与"抢注别人的技能 ID"。
/// 3. **分成只做一层**（PRD §9.1 红线：多层返利触碰《禁止传销条例》）。
///    本 API 的**形态本身**就排除多级：只有一个 `referrerBps`，没有上级链、没有递归。
/// 4. **分账绝不让分**：`author + platform + referrer == amount`（**逐分相等**）。
///    余数一律归**作者**，而不是四舍五入丢掉。
///
/// 本文件**零平台依赖**（不 import `flutter` / `sqflite` / `shared_preferences`；
/// 只用 `dart:convert` + `package:crypto` + `package:cryptography` + `agent_protocol`），
/// `dart run tool/verify_skill_registry.dart` 可直接复算全部判定。

library;

import 'dart:convert';

import 'package:crypto/crypto.dart' as c;

import 'agent_protocol.dart' show AgentProtocol;
import 'ed25519_sig.dart' show Ed25519Sig;

/// 技能风险等级码。
///
/// ⚠️ 取值必须与 `plugin_bus.dart#PluginRisk` 的**字面量**保持一致（low/medium/high）——
/// 两边同名不同值时，UI 的徽标会静默错色。`verify_skill_registry` 有源码级断言盯着这件事。
/// （不直接 import `plugin_bus.dart`：它依赖 `shared_preferences`，会把本模块拖出
/// "零平台依赖、可 `dart run`" 的边界。）
abstract final class SkillRisk {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';

  static bool isValid(String v) => v == low || v == medium || v == high;
}

/// 验签 / 安装判定结果码（UI 侧翻译成文案）。
abstract final class SkillVerifyCode {
  static const String ok = 'ok';

  /// 必填字段缺失（skillId / version / authorPub / contentHash / signature）。
  static const String missingFields = 'missing_fields';

  /// 公钥不是合法的 32 字节 Ed25519 公钥。
  static const String badPubkey = 'bad_pubkey';

  /// Ed25519 验签失败 —— **清单被改过**（改价、改内容哈希、改作者，都会落到这里）。
  static const String badSignature = 'bad_signature';

  /// 内容哈希对不上（拿真实内容复算 sha256 与清单声明不符）。
  static const String hashMismatch = 'hash_mismatch';

  /// 该版本已被作者吊销。
  static const String revoked = 'revoked';

  /// 风险等级码非法（防止用未知风险值绕过授权弹窗）。
  static const String badRisk = 'bad_risk';
}

/// 上架判定结果码。
abstract final class PublishCode {
  /// 接受为上架。
  static const String accepted = 'accepted';

  /// 同 (skillId, version, contentHash) 已存在 —— **幂等**，不重复写。
  static const String duplicate = 'duplicate';

  /// 同 (skillId, version) 已存在但**内容不同** —— 拒。
  /// 这是本模块最重要的一条：拦住"用户付过钱之后内容被换掉"。
  static const String versionConflict = 'version_conflict';

  /// 同 skillId 已存在但**作者公钥不同** —— 拒（防抢注 / 防换手）。
  static const String authorChanged = 'author_changed';

  /// 新版本号不高于该技能已上架的最高版本 —— 拒（版本只许前进）。
  static const String versionNotIncreased = 'version_not_increased';

  /// 清单**验签不过**（缺字段 / 坏公钥 / 改过签 / 风险码非法）——
  /// 注册表在判定"能不能上架"之前必须先是"是不是作者签的"。
  static const String unverified = 'unverified';
}

/// 定价（金额单位为**分**，避免浮点）。
class SkillPricing {
  /// 0 表示免费。
  final int priceCents;
  final String currency;

  const SkillPricing({this.priceCents = 0, this.currency = 'CNY'});

  bool get isFree => priceCents <= 0;

  Map<String, Object?> toMap() => {
        'price_cents': priceCents,
        'currency': currency,
      };
}

/// 一份**技能上架清单**。
///
/// 它同时是"作者的公开承诺"与"平台的不可篡改凭据"：
/// [canonical] 给出确定性签名载荷，[signatureB64] 由作者 Ed25519 私钥签署。
/// **签名覆盖定价与内容哈希**，所以价格与内容都是作者签过的，平台改不动。
class SkillListing {
  /// 稳定技能 ID（如 `world.wold.skill.translate`）。一旦上架不得改名。
  final String skillId;

  /// 语义化版本（`major.minor.patch`）。
  final String version;

  final String name;
  final String description;

  /// 作者标识（Agent ID / 昵称，仅展示用；**身份由 [authorPub] 决定**）。
  final String authorId;

  /// 作者 Ed25519 公钥（base58，32 字节）。**这是唯一可信的作者身份**。
  final String authorPub;

  /// 能力声明（与 `PluginCapability` 同码）。
  final List<String> capabilities;

  /// 风险等级（[SkillRisk]）。
  final String risk;

  /// 技能内容的 sha256（hex）。签名覆盖它 → 内容被换即验签失败。
  final String contentHash;

  /// 定价。
  final SkillPricing pricing;

  /// 上架时刻（由作者签名固定，平台不得改写）。
  final int publishedAtMs;

  /// 作者签名（base64，64 字节）。空串 = 未签名（一律不可安装）。
  final String signatureB64;

  const SkillListing({
    required this.skillId,
    required this.version,
    required this.name,
    this.description = '',
    required this.authorId,
    required this.authorPub,
    this.capabilities = const [],
    this.risk = SkillRisk.low,
    required this.contentHash,
    this.pricing = const SkillPricing(),
    required this.publishedAtMs,
    this.signatureB64 = '',
  });

  /// 落库/传输键：`skillId@version`（吊销与查重都用它）。
  String get key => '$skillId@$version';

  /// **确定性签名载荷**（JSON，键序固定、能力排序）。
  ///
  /// 为什么要把 `alg` 写进载荷：否则攻击者可以打"算法混淆"——
  /// 拿同一份载荷换成另一种算法/公钥去验，而验签方无法察觉载荷本身没变。
  /// 为什么要把 `price_cents` 与 `content_hash` 写进载荷：这两项是**钱与内容**，
  /// 不签就等于把定价权与内容完整性交给了中间人。
  String canonical() {
    final sortedCaps = [...capabilities]..sort();
    return jsonEncode({
      'alg': signatureAlg,
      'skill_id': skillId,
      'version': version,
      'name': name,
      'description': description,
      'author_id': authorId,
      'author_pub': authorPub,
      'capabilities': sortedCaps,
      'risk': risk,
      'content_hash': contentHash,
      'price_cents': pricing.priceCents,
      'currency': pricing.currency,
      'published_at': publishedAtMs,
    });
  }

  List<int> canonicalBytes() => utf8.encode(canonical());

  /// 签名算法标识（写进 `source_sig` 前缀，与 `plugin_bus.dart` 的 `hmac-sha256.` 并列）。
  static const String signatureAlg = 'ed25519';

  SkillListing copyWith({String? signatureB64, int? publishedAtMs}) => SkillListing(
        skillId: skillId,
        version: version,
        name: name,
        description: description,
        authorId: authorId,
        authorPub: authorPub,
        capabilities: capabilities,
        risk: risk,
        contentHash: contentHash,
        pricing: pricing,
        publishedAtMs: publishedAtMs ?? this.publishedAtMs,
        signatureB64: signatureB64 ?? this.signatureB64,
      );

  Map<String, Object?> toMap() => {
        'skill_id': skillId,
        'version': version,
        'name': name,
        'description': description,
        'author_id': authorId,
        'author_pub': authorPub,
        'capabilities': capabilities,
        'risk': risk,
        'content_hash': contentHash,
        'price_cents': pricing.priceCents,
        'currency': pricing.currency,
        'published_at': publishedAtMs,
        'sig': signatureB64,
      };

  static SkillListing fromMap(Map<String, dynamic> m) => SkillListing(
        skillId: (m['skill_id'] as String?) ?? '',
        version: (m['version'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        authorId: (m['author_id'] as String?) ?? '',
        authorPub: (m['author_pub'] as String?) ?? '',
        capabilities: ((m['capabilities'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        risk: (m['risk'] as String?) ?? SkillRisk.low,
        contentHash: (m['content_hash'] as String?) ?? '',
        pricing: SkillPricing(
          priceCents: (m['price_cents'] as num?)?.toInt() ?? 0,
          currency: (m['currency'] as String?) ?? 'CNY',
        ),
        publishedAtMs: (m['published_at'] as num?)?.toInt() ?? 0,
        signatureB64: (m['sig'] as String?) ?? '',
      );
}

/// 作者**吊销**某个技能（或某个技能的全部版本）的签名声明。
///
/// 与上架清单同样必须由**作者公钥**签名 —— 否则任何人都能吊销别人的技能
/// （那会让整个注册表可被恶意清场）。
class SkillRevocation {
  final String skillId;

  /// 空串 = 吊销该技能**全部版本**。
  final String version;

  /// 声明者公钥；必须与上架该技能的作者公钥**完全一致**才生效。
  final String authorPub;

  final String reason;
  final int atMs;
  final String signatureB64;

  const SkillRevocation({
    required this.skillId,
    this.version = '',
    required this.authorPub,
    this.reason = '',
    required this.atMs,
    this.signatureB64 = '',
  });

  String get key => '$skillId@$version';

  /// 该吊销是否覆盖某个具体版本（version 为空表示全覆盖）。
  bool covers(String skillId, String version) =>
      this.skillId == skillId && (this.version.isEmpty || this.version == version);

  String canonical() => jsonEncode({
        'alg': SkillListing.signatureAlg,
        'kind': 'skill_revocation',
        'skill_id': skillId,
        'version': version,
        'author_pub': authorPub,
        'reason': reason,
        'at': atMs,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  Map<String, Object?> toMap() => {
        'skill_id': skillId,
        'version': version,
        'author_pub': authorPub,
        'reason': reason,
        'at_ms': atMs,
        'sig': signatureB64,
      };

  static SkillRevocation fromMap(Map<String, dynamic> m) => SkillRevocation(
        skillId: (m['skill_id'] as String?) ?? '',
        version: (m['version'] as String?) ?? '',
        authorPub: (m['author_pub'] as String?) ?? '',
        reason: (m['reason'] as String?) ?? '',
        atMs: (m['at_ms'] as num?)?.toInt() ?? (m['at'] as num?)?.toInt() ?? 0,
        signatureB64: (m['sig'] as String?) ?? '',
      );
}

class SkillVerifyResult {
  final bool ok;
  final String code; // SkillVerifyCode.*
  final List<String> faults;

  const SkillVerifyResult({required this.ok, required this.code, this.faults = const []});

  /// 可安装 = 验签通过（本模块 fail-closed 的唯一出口）。
  bool get installable => ok;
}

class PublishDecision {
  final bool accept;
  final String code; // PublishCode.*
  final String detail;

  const PublishDecision({required this.accept, required this.code, this.detail = ''});
}

// ---------------------------------------------------------------------------
// 注册表判定（纯函数）
// ---------------------------------------------------------------------------

abstract final class SkillRegistry {
  /// 内容哈希（`sha256` hex）。作者签名覆盖它 → 内容被换一定验签失败。
  static String contentHashOf(String content) =>
      c.sha256.convert(utf8.encode(content)).toString();

  /// **验一份上架清单**（fail-closed）。
  ///
  /// 检查顺序：便宜的先、密码学的后；任何一步不过直接返回，绝不"部分通过"。
  /// [content] 传入时额外复算内容哈希（安装前必须传）。
  /// [revokedKeys] 为已被作者吊销的 `skillId@version`（作者全版本吊销时用 `skillId@`）。
  static Future<SkillVerifyResult> verifyListing(
    SkillListing l, {
    String? content,
    Set<String> revokedKeys = const {},
  }) async {
    final missing = <String>[];
    if (l.skillId.trim().isEmpty) missing.add('skill_id');
    if (l.version.trim().isEmpty) missing.add('version');
    if (l.authorPub.trim().isEmpty) missing.add('author_pub');
    if (l.contentHash.trim().isEmpty) missing.add('content_hash');
    if (l.signatureB64.trim().isEmpty) missing.add('sig');
    if (missing.isNotEmpty) {
      return SkillVerifyResult(
          ok: false, code: SkillVerifyCode.missingFields, faults: missing);
    }
    if (!SkillRisk.isValid(l.risk)) {
      return const SkillVerifyResult(ok: false, code: SkillVerifyCode.badRisk);
    }

    final pubBytes = AgentProtocol.base58Decode(l.authorPub);
    if (pubBytes.length != 32) {
      return const SkillVerifyResult(ok: false, code: SkillVerifyCode.badPubkey);
    }

    // 吊销先于验签：一个已吊销的版本，即使签名有效也不得安装。
    if (revokedKeys.contains(l.key) || revokedKeys.contains('${l.skillId}@')) {
      return const SkillVerifyResult(ok: false, code: SkillVerifyCode.revoked);
    }

    final sigOk = await _verifyEd25519(
      message: l.canonicalBytes(),
      signatureB64: l.signatureB64,
      publicKeyBase58: l.authorPub,
    );
    if (!sigOk) {
      return const SkillVerifyResult(ok: false, code: SkillVerifyCode.badSignature);
    }

    if (content != null && contentHashOf(content) != l.contentHash) {
      return const SkillVerifyResult(ok: false, code: SkillVerifyCode.hashMismatch);
    }

    return const SkillVerifyResult(ok: true, code: SkillVerifyCode.ok);
  }

  /// **验一份吊销声明**：签名必须有效，且公钥必须与上架该技能的作者公钥一致。
  static Future<SkillVerifyResult> verifyRevocation(
    SkillRevocation r, {
    required String listingAuthorPub,
  }) async {
    if (r.skillId.trim().isEmpty || r.authorPub.trim().isEmpty || r.signatureB64.trim().isEmpty) {
      return const SkillVerifyResult(
          ok: false, code: SkillVerifyCode.missingFields);
    }
    if (r.authorPub != listingAuthorPub) {
      // 不是作者本人 → 一律拒（否则任何人可清场整个注册表）
      return const SkillVerifyResult(ok: false, code: SkillVerifyCode.badSignature);
    }
    final pubBytes = AgentProtocol.base58Decode(r.authorPub);
    if (pubBytes.length != 32) {
      return const SkillVerifyResult(ok: false, code: SkillVerifyCode.badPubkey);
    }
    final ok = await _verifyEd25519(
      message: r.canonicalBytes(),
      signatureB64: r.signatureB64,
      publicKeyBase58: r.authorPub,
    );
    return ok
        ? const SkillVerifyResult(ok: true, code: SkillVerifyCode.ok)
        : const SkillVerifyResult(ok: false, code: SkillVerifyCode.badSignature);
  }

  /// **上架判定**（纯函数）：注册表只接受"作者未换、版本单调、同版本同内容"的清单。
  static PublishDecision publishDecision({
    required SkillListing incoming,
    required List<SkillListing> existing,
  }) {
    final sameSkill = existing.where((e) => e.skillId == incoming.skillId).toList();
    if (sameSkill.isEmpty) {
      return const PublishDecision(accept: true, code: PublishCode.accepted);
    }

    // 铁律 2a：技能 ID 不得换作者（防抢注「别人积累声望的 ID」）
    if (sameSkill.any((e) => e.authorPub != incoming.authorPub)) {
      return const PublishDecision(
        accept: false,
        code: PublishCode.authorChanged,
        detail: '该 skillId 已由另一把作者公钥上架，不得换手',
      );
    }

    final sameVersion =
        sameSkill.where((e) => e.version == incoming.version).toList();
    if (sameVersion.isNotEmpty) {
      // 铁律 2b：同版本只认一个内容
      final identical = sameVersion.any((e) =>
          e.contentHash == incoming.contentHash &&
          e.pricing.priceCents == incoming.pricing.priceCents);
      return identical
          ? const PublishDecision(
              accept: false, code: PublishCode.duplicate, detail: '同版本同内容，幂等')
          : const PublishDecision(
              accept: false,
              code: PublishCode.versionConflict,
              detail: '同版本内容/价格不同 —— 拦住「付过钱后换内容」',
            );
    }

    // 铁律 2c：版本只许前进
    var maxExisting = sameSkill.first.version;
    for (final e in sameSkill) {
      if (compareVersion(e.version, maxExisting) > 0) maxExisting = e.version;
    }
    if (compareVersion(incoming.version, maxExisting) <= 0) {
      return PublishDecision(
        accept: false,
        code: PublishCode.versionNotIncreased,
        detail: '新版本 ${incoming.version} 不高于已上架最高版本 $maxExisting',
      );
    }
    return const PublishDecision(accept: true, code: PublishCode.accepted);
  }

  /// 语义化版本比较（只比较 major/minor/patch 的数字段；缺段视为 0）。
  ///
  /// 刻意**不用** `publishDecision` 之外的地方 —— 版本口径只允许有一个实现。
  static int compareVersion(String a, String b) {
    final pa = _parseVersion(a);
    final pb = _parseVersion(b);
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i] < pb[i] ? -1 : 1;
    }
    return 0;
  }

  static List<int> _parseVersion(String v) {
    final parts = v.split('.');
    final out = [0, 0, 0];
    for (var i = 0; i < 3 && i < parts.length; i++) {
      // 非数字段（如 '1.0.0-beta'）→ 取前导数字，取不到就 0。
      final m = RegExp(r'^\d+').firstMatch(parts[i].trim());
      out[i] = m == null ? 0 : (int.tryParse(m.group(0)!) ?? 0);
    }
    return out;
  }

  /// 委托给 `Ed25519Sig`（M9 技能签名与 M6 背书签名共用**同一份**验签实现 ——
  /// 两处各写一份必然漂移，而漂移的形态是"一边拒的假签名另一边却收了"）。
  static Future<bool> _verifyEd25519({
    required List<int> message,
    required String signatureB64,
    required String publicKeyBase58,
  }) =>
      Ed25519Sig.verify(
        message: message,
        signatureB64: signatureB64,
        publicKeyBase58: publicKeyBase58,
      );
}

// ---------------------------------------------------------------------------
// 作者分成
// ---------------------------------------------------------------------------

/// 精确到分的分账结果。**三个桶加起来必须恒等于实收金额。**
class RevenueSplit {
  final int authorCents;
  final int platformCents;
  final int referrerCents;

  const RevenueSplit({
    required this.authorCents,
    required this.platformCents,
    this.referrerCents = 0,
  });

  int get total => authorCents + platformCents + referrerCents;

  Map<String, Object?> toMap() => {
        'author_cents': authorCents,
        'platform_cents': platformCents,
        'referrer_cents': referrerCents,
      };
}

abstract final class RevenueShare {
  static const int bpsDenominator = 10000; // 1 bps = 0.01%

  /// 平台抽成（基点）。
  static const int defaultPlatformBps = 3000; // 30%

  /// 一层推荐分成（基点）。默认 0：**没有推荐人就不产生这一份**，
  /// 绝不"先扣再留"。
  static const int defaultReferrerBps = 1000; // 10%

  /// PRD §9.1 红线：**只做一层**。
  ///
  /// 这个常量不是"配置项"，而是一条**不可配置的产品红线**：
  /// 多层级返利触碰《禁止传销条例》。本 API 的形态（只有一个 referrer 参数、
  /// 没有上级链、没有递归）从结构上就写不出第二层来。
  static const int maxReferrerLevels = 1;

  /// **精确分账**：`author + platform + referrer == amountCents`（逐分相等）。
  ///
  /// 余数一律归**作者**：先取平台与推荐人的整数分，剩下的全给作者。
  /// 这样"四舍五入"永远不会从作者身上扣钱 —— 该吃亏的是平台，不是创作者。
  ///
  /// [platformBps] + [referrerBps] 必须 ≤ 10000，否则抛 [ArgumentError]
  /// （宁可炸掉也不静默截断：静默截断会让作者拿到负数或凭空多出来的钱）。
  static RevenueSplit split(
    int amountCents, {
    int platformBps = defaultPlatformBps,
    int referrerBps = 0,
  }) {
    if (amountCents < 0) {
      throw ArgumentError('amountCents must be >= 0, got $amountCents');
    }
    if (platformBps < 0 || referrerBps < 0) {
      throw ArgumentError('bps must be >= 0');
    }
    if (platformBps + referrerBps > bpsDenominator) {
      throw ArgumentError(
          'platformBps($platformBps) + referrerBps($referrerBps) > $bpsDenominator');
    }
    final platform = amountCents * platformBps ~/ bpsDenominator;
    final referrer = amountCents * referrerBps ~/ bpsDenominator;
    final author = amountCents - platform - referrer; // 余数归作者
    return RevenueSplit(
      authorCents: author,
      platformCents: platform,
      referrerCents: referrer,
    );
  }
}

/// 一条**分账账本**条目（可被第三方独立复算）。
///
/// 刻意**没有** `level` / `upline` / `parent` 之类字段：分账只有"作者 / 平台 / 推荐人"
/// 三方，[referrerId] 至多一个。想加多级返利，必须先改这张表的结构 ——
/// 那时它会撞上 `verify_skill_registry` 里"账本条目不得含 level 字段"的断言。
class PayoutLedgerEntry {
  /// 幂等键（同一笔购买只落一条）。
  final String purchaseId;

  final String skillId;
  final String version;

  /// 作者公钥（分账对象是**公钥**而不是昵称 —— 昵称可重名，公钥不会）。
  final String authorPub;

  final String buyerId;

  /// 实收金额（分）。
  final int amountCents;

  final RevenueSplit split;

  /// 一层推荐人（可为空 = 无推荐人）。**至多一个**。
  final String? referrerId;

  final int atMs;

  const PayoutLedgerEntry({
    required this.purchaseId,
    required this.skillId,
    required this.version,
    required this.authorPub,
    required this.buyerId,
    required this.amountCents,
    required this.split,
    this.referrerId,
    required this.atMs,
  });

  /// 不变式自检：分账必须**逐分守恒**。
  bool get balanced => split.total == amountCents;

  /// 叶子字节：只含公开字段、顺序固定 —— 任何第三方都能独立算出同一个哈希。
  List<int> logLeafBytes() => utf8.encode(jsonEncode({
        'kind': 'skill_payout',
        'purchase_id': purchaseId,
        'skill_id': skillId,
        'version': version,
        'author_pub': authorPub,
        'buyer_id': buyerId,
        'amount_cents': amountCents,
        'author_cents': split.authorCents,
        'platform_cents': split.platformCents,
        'referrer_cents': split.referrerCents,
        'referrer_id': referrerId ?? '',
        'at': atMs,
      }));

  /// 条目哈希（hex）—— 进 §16 公开只追加日志的叶子哈希。
  String entryHash() => c.sha256.convert(logLeafBytes()).toString();

  Map<String, Object?> toMap() => {
        'purchase_id': purchaseId,
        'skill_id': skillId,
        'version': version,
        'author_pub': authorPub,
        'buyer_id': buyerId,
        'amount_cents': amountCents,
        'author_cents': split.authorCents,
        'platform_cents': split.platformCents,
        'referrer_cents': split.referrerCents,
        'referrer_id': referrerId,
        'at_ms': atMs,
      };

  static PayoutLedgerEntry fromMap(Map<String, dynamic> m) => PayoutLedgerEntry(
        purchaseId: (m['purchase_id'] as String?) ?? '',
        skillId: (m['skill_id'] as String?) ?? '',
        version: (m['version'] as String?) ?? '',
        authorPub: (m['author_pub'] as String?) ?? '',
        buyerId: (m['buyer_id'] as String?) ?? '',
        amountCents: (m['amount_cents'] as num?)?.toInt() ?? 0,
        split: RevenueSplit(
          authorCents: (m['author_cents'] as num?)?.toInt() ?? 0,
          platformCents: (m['platform_cents'] as num?)?.toInt() ?? 0,
          referrerCents: (m['referrer_cents'] as num?)?.toInt() ?? 0,
        ),
        referrerId: m['referrer_id'] as String?,
        atMs: (m['at_ms'] as num?)?.toInt() ?? (m['at'] as num?)?.toInt() ?? 0,
      );
}

/// **购买**判定（纯函数，不做真金白银的划转 —— PRD §2.3 明确不做用户间资金流转）。
///
/// 本模块只负责"该给谁分多少"这件事**算得对、算得可复算、算得只有一层**；
/// 真正的收款与结算属 M8（试用额度代调 + 计费埋点）。
abstract final class PurchaseDecision {
  static const String ok = 'ok';
  static const String freeNoPayout = 'free_no_payout';
  static const String notInstallable = 'not_installable';
  static const String alreadyPurchased = 'already_purchased';

  /// 免费技能不产生分账（所以不会因为"分成比例"把免费技能变成收费技能）。
  static bool needsPayout(SkillListing l) => !l.pricing.isFree;
}

// ---------------------------------------------------------------------------
// 存储抽象（零依赖；SQLite 实现在 skill_store_db.dart）
// ---------------------------------------------------------------------------

/// 注册表 + 吊销 + 分账账本的持久化抽象。
///
/// 抽出来只有一个目的：让"判定逻辑"能在 `dart run`（无平台通道）里被复算，
/// 而不是把判定和 sqflite 焊死在一起。生产实现见 `skill_store_db.dart`。
abstract class SkillStore {
  Future<void> upsertListing(SkillListing l);

  /// 某技能的全部已上架版本（按版本号降序）。
  Future<List<SkillListing>> listingsOf(String skillId);

  Future<SkillListing?> listing(String skillId, String version);

  /// 全部上架清单（注册表全量视图）。
  Future<List<SkillListing>> allListings();

  Future<void> addRevocation(SkillRevocation r);
  Future<List<SkillRevocation>> revocations();

  /// 已吊销键集合：`skillId@version` 与全版本吊销的 `skillId@`。
  Future<Set<String>> revokedKeys();

  Future<void> addPayout(PayoutLedgerEntry e);
  Future<PayoutLedgerEntry?> payout(String purchaseId);
  Future<List<PayoutLedgerEntry>> payoutsOf(String authorPub);
  Future<List<PayoutLedgerEntry>> allPayouts();
}

/// 内存实现（单测 / 离线复算用；不落盘）。
class MemorySkillStore implements SkillStore {
  final Map<String, SkillListing> _byKey = {};
  final Map<String, SkillRevocation> _revocations = {};
  final Map<String, PayoutLedgerEntry> _payouts = {};

  @override
  Future<void> upsertListing(SkillListing l) async => _byKey[l.key] = l;

  @override
  Future<List<SkillListing>> listingsOf(String skillId) async {
    final out = _byKey.values.where((e) => e.skillId == skillId).toList();
    out.sort((a, b) => SkillRegistry.compareVersion(b.version, a.version));
    return out;
  }

  @override
  Future<SkillListing?> listing(String skillId, String version) async =>
      _byKey['$skillId@$version'];

  @override
  Future<List<SkillListing>> allListings() async => _byKey.values.toList();

  @override
  Future<void> addRevocation(SkillRevocation r) async => _revocations[r.key] = r;

  @override
  Future<List<SkillRevocation>> revocations() async => _revocations.values.toList();

  @override
  Future<Set<String>> revokedKeys() async => _revocations.keys.toSet();

  @override
  Future<void> addPayout(PayoutLedgerEntry e) async => _payouts[e.purchaseId] = e;

  @override
  Future<PayoutLedgerEntry?> payout(String purchaseId) async => _payouts[purchaseId];

  @override
  Future<List<PayoutLedgerEntry>> payoutsOf(String authorPub) async =>
      _payouts.values.where((e) => e.authorPub == authorPub).toList();

  @override
  Future<List<PayoutLedgerEntry>> allPayouts() async => _payouts.values.toList();
}

// ---------------------------------------------------------------------------
// 服务层：把"纯判定"和"落库"串成注册表的对外动作
// ---------------------------------------------------------------------------

/// 注册表服务：上架 / 安装 / 吊销 / 分账记账。
///
/// 刻意**不做**的事：不负责收款、不负责结算、不负责把分账真正划给谁 ——
/// 那是 M8 计费埋点的职责。这里只保证"该给谁分多少"**算得对、可复算、只有一层**。
class SkillRegistryService {
  final SkillStore store;
  final void Function(String kind, Map<String, Object?> data)? onEvent;

  /// 上架**落库成功后**的上行钩子（best-effort，由装配层 `wold_runtime` 提供）。
  ///
  /// 只在实际写入时触发：被判为 `duplicate` / `version_conflict` 的清单
  /// 本地都没落库，把它推上 Hub 只会让"平台上有什么"多出一份不存在的东西。
  final void Function(SkillListing listing)? onCommit;

  SkillRegistryService({required this.store, this.onEvent, this.onCommit});

  /// **上架**：先验签（fail-closed），再做幂等/防换手/版本单调判定。
  ///
  /// 返回 [PublishDecision]，`accept == true` 时清单已落库。
  Future<PublishDecision> publish(SkillListing l) async {
    final v = await SkillRegistry.verifyListing(l);
    if (!v.ok) {
      _emit('SKILL_PUBLISH_REJECTED',
          {'skill': l.key, 'reason': v.code});
      return PublishDecision(
          accept: false, code: PublishCode.unverified, detail: v.code);
    }
    final existing = await store.listingsOf(l.skillId);
    final d = SkillRegistry.publishDecision(incoming: l, existing: existing);
    if (d.accept) {
      await store.upsertListing(l);
      _emit('SKILL_PUBLISHED',
          {'skill': l.key, 'author_pub': l.authorPub, 'price_cents': l.pricing.priceCents});
      onCommit?.call(l);
    } else {
      _emit('SKILL_PUBLISH_REJECTED', {'skill': l.key, 'reason': d.code});
    }
    return d;
  }

  /// **安装前复算**：验签 + 内容哈希 + 吊销名单，三关全过才 `installable`。
  Future<SkillVerifyResult> install(
    String skillId,
    String version, {
    String? content,
  }) async {
    final l = await store.listing(skillId, version);
    if (l == null) {
      return const SkillVerifyResult(
          ok: false, code: SkillVerifyCode.missingFields, faults: ['not_listed']);
    }
    final revoked = await store.revokedKeys();
    return SkillRegistry.verifyListing(l, content: content, revokedKeys: revoked);
  }

  /// **吊销**：只有作者本人（公钥一致）能吊销自己的技能。
  Future<SkillVerifyResult> revoke(SkillRevocation r) async {
    final existing = await store.listingsOf(r.skillId);
    if (existing.isEmpty) {
      return const SkillVerifyResult(
          ok: false, code: SkillVerifyCode.missingFields, faults: ['not_listed']);
    }
    // 以**已上架清单的作者公钥**为准（不是吊销声明自称的公钥）。
    final v = await SkillRegistry.verifyRevocation(
        r, listingAuthorPub: existing.first.authorPub);
    if (v.ok) {
      await store.addRevocation(r);
      _emit('SKILL_REVOKED', {'skill': r.key, 'author_pub': r.authorPub});
    } else {
      _emit('SKILL_REVOKE_REJECTED', {'skill': r.key, 'reason': v.code});
    }
    return v;
  }

  /// **计一笔购买的分账**（幂等：同一 purchaseId 只落一条）。
  ///
  /// 免费技能不产生分账，直接返回 null。推荐人至多一个；[referrerBps] 只在
  /// 有推荐人时才生效 —— 没有推荐人就那一份不产生，绝不"先扣再留"。
  Future<PayoutLedgerEntry?> recordPurchase({
    required String purchaseId,
    required SkillListing listing,
    required String buyerId,
    required int amountCents,
    String? referrerId,
    required int atMs,
    int platformBps = RevenueShare.defaultPlatformBps,
    int referrerBps = RevenueShare.defaultReferrerBps,
  }) async {
    if (!PurchaseDecision.needsPayout(listing)) return null;
    final existing = await store.payout(purchaseId);
    if (existing != null) return existing; // 幂等

    final split = RevenueShare.split(
      amountCents,
      platformBps: platformBps,
      referrerBps: (referrerId == null || referrerId.isEmpty) ? 0 : referrerBps,
    );
    final entry = PayoutLedgerEntry(
      purchaseId: purchaseId,
      skillId: listing.skillId,
      version: listing.version,
      authorPub: listing.authorPub,
      buyerId: buyerId,
      amountCents: amountCents,
      split: split,
      referrerId: (referrerId == null || referrerId.isEmpty) ? null : referrerId,
      atMs: atMs,
    );
    await store.addPayout(entry);
    _emit('SKILL_PAYOUT', {
      'purchase': purchaseId,
      'skill': listing.key,
      'author_pub': listing.authorPub,
      'amount_cents': amountCents,
      'author_cents': split.authorCents,
      'platform_cents': split.platformCents,
      'referrer_cents': split.referrerCents,
      'hash': entry.entryHash(),
    });
    return entry;
  }

  void _emit(String kind, Map<String, Object?> data) => onEvent?.call(kind, data);
}
