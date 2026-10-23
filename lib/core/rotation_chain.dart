/// 换钥链的**公开视图** —— `GET /api/identity/rotations` 的客户端解析 + **本地独立复算**。
///
/// ---------------------------------------------------------------------------
/// 为什么这个文件存在
/// ---------------------------------------------------------------------------
/// Hub 的那个端点**刻意只回原始记录**（含 `sig`），**不回** `sig_ok` 之类的结论。
/// 原因和 §16 透明日志一致：一个"我替你验过了"的字段等于**本店自查**，
/// 只有**读者自己验**才算得上可监督。
///
/// 于是这里承担两件事：
///   1. 把线格式解析成对象（`tryParse` 一律 fail-closed：形状不对就返回 null，绝不猜）；
///   2. 给读者提供**本地独立复算**——[RotationChain.verifySignatures] 逐条验签、
///      [RotationChain.verifyLinks] 逐环查链。**结论完全由读者算出**，Hub 的话只作为对照。
///
/// ★ 本文件**零平台依赖**（不 import Flutter / sqflite / shared_preferences），
///   因此可被 `dart run tool/verify_rotation_chain.dart` 离线复算。
library;

import 'identity_rotation.dart';

/// 一处链断裂。`reason` 是**语言无关的稳定码**（与 Hub 侧同字面量）。
class ChainBreak {
  /// 出问题的记录在链中的位置（= Hub 的 `idx`）。
  final int atIdx;

  /// `link_mismatch`（上一条 new_pub ≠ 下一条 old_pub）
  /// / `tip_not_active`（链末端 ≠ 当前活跃钥）
  /// / `subject_unknown`（有换钥记录却没有注册记录）。
  final String reason;

  const ChainBreak({required this.atIdx, required this.reason});

  static ChainBreak? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final reason = (raw['reason'] ?? '').toString();
    if (reason.isEmpty) return null;
    final idx = (raw['at_idx'] as num?)?.toInt();
    if (idx == null) return null;
    return ChainBreak(atIdx: idx, reason: reason);
  }

  @override
  String toString() => '$reason@$atIdx';
}

/// 被查询身份的**汇总**（Hub 的 `subject` 字段）。
class RotationSubject {
  final String? agentId;
  final String? did;

  /// Hub 是否认识这个身份。false 且 `rotations == 0` ⇒ 从未注册过。
  final bool registered;

  /// Hub 当前记录在案的活跃公钥（换钥链的**应然末端**）。
  final String? currentPubkey;

  /// 换钥条数（Hub 自报；读者应自行用 [RotationChain.rotations] 的长度对照）。
  final int rotations;

  /// Hub 自报的链是否完好 —— ★ **仅作对照**，读者必须用
  /// [RotationChain.verifySignatures] / [RotationChain.verifyLinks] 自行判定。
  final bool chainOk;

  final List<ChainBreak> chainBreaks;

  const RotationSubject({
    this.agentId,
    this.did,
    this.registered = false,
    this.currentPubkey,
    this.rotations = 0,
    this.chainOk = true,
    this.chainBreaks = const [],
  });

  static RotationSubject? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final breaks = <ChainBreak>[];
    final rawBreaks = raw['chain_breaks'];
    if (rawBreaks is List) {
      for (final b in rawBreaks) {
        final parsed = ChainBreak.tryParse(b);
        // 形状不对的断裂项**不静默丢弃**：它本身就是"Hub 回复异常"的信号，
        // 直接让整段解析失败，好过给出一份看起来干净的结论。
        if (parsed == null) return null;
        breaks.add(parsed);
      }
    } else if (rawBreaks != null) {
      return null;
    }
    return RotationSubject(
      agentId: raw['agent_id']?.toString(),
      did: raw['did']?.toString(),
      registered: raw['registered'] == true,
      currentPubkey: raw['current_pubkey']?.toString(),
      rotations: (raw['rotations'] as num?)?.toInt() ?? 0,
      chainOk: raw['chain_ok'] != false,
      chainBreaks: breaks,
    );
  }

  /// 未注册且零换钥 = "Hub 根本不认识这个身份"。
  bool get unknownIdentity => !registered && rotations == 0;
}

/// 读者自算的**验签报告**（每一条 ROTATE 都由其 `old_pub` 签名覆盖）。
class RotationSignatureReport {
  final int total;

  /// 签名有效的条数。
  final int valid;

  /// 签名无效 / 无法验证的**记录下标**（在 [RotationChain.rotations] 里的位置）。
  final List<int> invalidIndices;

  const RotationSignatureReport({
    required this.total,
    required this.valid,
    required this.invalidIndices,
  });

  bool get allValid => total > 0 && invalidIndices.isEmpty;

  @override
  String toString() =>
      'RotationSignatureReport($valid/$total valid, bad=$invalidIndices)';
}

/// `GET /api/identity/rotations` 的完整视图。
class RotationChain {
  final String proto;

  /// 本次返回的记录条数（指定身份时 = 该身份的换钥条数）。
  final int size;

  /// Hub 上**全部**换钥记录条数（不限身份）—— 让读者知道查询所截取的局部。
  final int total;

  /// Hub 的 §16 透明日志长度 + Merkle 根，供读者把换钥记录**锚定进日志**。
  final int logSize;
  final String root;

  /// Hub 自报"全库链拼接无断裂"（对照用；读者自算见 [verifyLinksAcross]）。
  final bool chainLinksOk;

  /// Hub 自报的断裂身份清单（对照用）。
  final List<String> brokenAgents;

  final RotationSubject? subject;
  final List<IdentityRotation> rotations;

  const RotationChain({
    required this.proto,
    required this.size,
    required this.total,
    required this.logSize,
    required this.root,
    required this.chainLinksOk,
    required this.brokenAgents,
    this.subject,
    this.rotations = const [],
  });

  /// fail-closed 解析：任一必填字段缺失/形状不对 ⇒ null。
  static RotationChain? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final rawList = raw['rotations'];
    if (rawList is! List) return null;
    final rotations = <IdentityRotation>[];
    for (final r in rawList) {
      if (r is! Map) return null;
      rotations.add(IdentityRotation.fromMap(Map<String, dynamic>.from(r)));
    }
    final broken = <String>[];
    final rawBroken = raw['broken_agents'];
    if (rawBroken is List) {
      for (final a in rawBroken) {
        broken.add(a.toString());
      }
    }
    return RotationChain(
      proto: (raw['proto'] ?? '').toString(),
      size: (raw['size'] as num?)?.toInt() ?? rotations.length,
      total: (raw['total'] as num?)?.toInt() ?? rotations.length,
      logSize: (raw['log_size'] as num?)?.toInt() ?? 0,
      root: (raw['root'] ?? '').toString(),
      chainLinksOk: raw['chain_links_ok'] != false,
      brokenAgents: broken,
      subject: RotationSubject.tryParse(raw['subject']),
      rotations: rotations,
    );
  }

  /// ★ **本地逐条验签**（Hub 不替我们背书）。
  ///
  /// 每条 ROTATE 都必须由它自称的 `old_pub` 签名覆盖。
  Future<RotationSignatureReport> verifySignatures() async {
    final invalid = <int>[];
    var valid = 0;
    for (var i = 0; i < rotations.length; i++) {
      if (await rotations[i].sigValid()) {
        valid++;
      } else {
        invalid.add(i);
      }
    }
    return RotationSignatureReport(
      total: rotations.length,
      valid: valid,
      invalidIndices: invalid,
    );
  }

  /// ★ **本地逐环查链**：`rotations[i].oldPub` 必须等于 `rotations[i-1].newPub`。
  ///
  /// 与 Hub 的 `link_mismatch` 独立同源（两边各自算）。
  List<ChainBreak> verifyLinks() {
    final out = <ChainBreak>[];
    for (var i = 1; i < rotations.length; i++) {
      if (rotations[i].oldPub != rotations[i - 1].newPub) {
        out.add(ChainBreak(atIdx: i, reason: 'link_mismatch'));
      }
    }
    return out;
  }

  /// 链末端是否等于 [RotationSubject.currentPubkey]（"有没有漏记一次换钥"）。
  ///
  /// 空链、未注册、或 Hub 没报活跃钥时**不判为断裂**（无从比较）。
  bool tipMatchesActive() {
    final s = subject;
    if (s == null || rotations.isEmpty) return true;
    final cur = s.currentPubkey;
    if (cur == null || cur.isEmpty) return true;
    return rotations.last.newPub == cur;
  }

  /// 把读者自算的三项结论压成一句话，便于 UI 展示。
  /// 返回 `ok` / `sig_invalid` / `link_mismatch` / `tip_not_active`。
  static String summarize({
    required RotationSignatureReport sigs,
    required List<ChainBreak> links,
    required bool tipOk,
  }) {
    if (!sigs.allValid) return 'sig_invalid';
    if (links.isNotEmpty) return 'link_mismatch';
    if (!tipOk) return 'tip_not_active';
    return 'ok';
  }

  /// ★★ **身份别名**：`pub` 所属身份的**全部历史公钥**（创世 → 当前钥）。
  ///
  /// ---------------------------------------------------------------------------
  /// 为什么必须有这一步（Gap A）
  /// ---------------------------------------------------------------------------
  /// M6 背书按 **`subject_pub`** 计，不用 `agent_id`（名字可被重发 ⇒ "改个名就能
  /// 甩掉差评"）。代价是：**换钥退休旧公钥之后，他此前收到的全部背书都留在那把
  /// 死钥上** —— "履历随人走"当场退化成"随钥走"（= 换一次手机，履历归零）。
  /// 换钥链已经把"这些公钥是同一个人"证出来了，这里就是把它**用起来**。
  ///
  /// ---------------------------------------------------------------------------
  /// 为什么这是**第二份实现**（不在协议包里共用）
  /// ---------------------------------------------------------------------------
  /// 服务端读端点与客户端各自独立复算，是 v0.29.0 定下的纪律：Hub 只回原始记录，
  /// **结论由读者自己算**。共用一份实现就等于"本店自查"。两端只共享**规则**
  /// （同一套稳定码 + 同一套 fail-closed 判据），**不共享代码**。
  ///
  /// ---------------------------------------------------------------------------
  /// 为什么每一步都 fail-closed
  /// ---------------------------------------------------------------------------
  /// 别名算错的后果是**把别人的履历算到你头上**（或反之），比"算不出来"坏得多。
  /// 所以任何不确定都收敛到"只认它自己"：链断了、链上有坏签名、一把钥被两个
  /// 身份同时认领 —— 一律只返回 `[pub]`，并把放弃的原因写进 [IdentityKeys.status]。
  ///
  /// ⚠️ 与 Node 侧 `identityKeysOf` 的唯一差异：那边多一个 `unordered`
  ///   （记录里没有追加序号时拒绝排序）。这里不需要 —— [rotations] 只可能来自
  ///   Hub 端点，而它**按追加序号 `idx` 升序**返回（`rotated_at` 是客户端自报的，
  ///   刻意不用于排序）。何况顺序被弄乱时，"逐环相接"这一关本身就会把它判死。
  Future<IdentityKeys> keysOf(String pub) async {
    final subject = pub.trim();
    if (subject.isEmpty) {
      return const IdentityKeys(keys: [], tip: '', status: AliasStatus.noChain);
    }

    // 按 `agentId` 分组。声明值本身也被签名覆盖，所以这里是"按**声称的**归属分组"，
    // 先分组、后验签 —— 反过来会把伪造记录先滤掉，剩下的链只是**看起来**整齐。
    final groups = <String, List<IdentityRotation>>{};
    for (final r in rotations) {
      if (r.agentId.isEmpty) continue;
      groups.putIfAbsent(r.agentId, () => <IdentityRotation>[]).add(r);
    }

    final owners = <String>[];
    for (final entry in groups.entries) {
      if (entry.value.any((r) => r.oldPub == subject || r.newPub == subject)) {
        owners.add(entry.key);
      }
    }
    if (owners.isEmpty) {
      // 常见情形：这把钥从未换过钥，它自己就是整个身份。
      return IdentityKeys(keys: [subject], tip: subject, status: AliasStatus.noChain);
    }
    if (owners.length > 1) {
      // 一把钥被两个身份认领：必有一个在说谎（或记录不一致），而**无从分辨**。
      // 与 Node 侧同款：只认查询的那把钥，但把 `ambiguous` 如实报出去。
      return IdentityKeys(
          keys: [subject], tip: subject, status: AliasStatus.ambiguous);
    }

    final agentId = owners.first;
    final chain = List<IdentityRotation>.of(groups[agentId]!);

    // ★ 密码学闸门：只有密钥本人能签出"我退休我自己"。任何一环验不过，
    //   **整条链作废**（不是只丢那一环）—— 因为看不出断口哪一侧才是真的。
    for (final r in chain) {
      if (!await r.sigValid()) {
        return IdentityKeys(
          agentId: agentId,
          keys: [subject],
          tip: subject,
          status: AliasStatus.unsigned,
          chain: chain,
        );
      }
    }

    // 逐环相接：上一条的 newPub 必须等于下一条的 oldPub。
    for (var i = 1; i < chain.length; i++) {
      if (chain[i].oldPub != chain[i - 1].newPub) {
        return IdentityKeys(
          agentId: agentId,
          keys: [subject],
          tip: subject,
          status: AliasStatus.broken,
          chain: chain,
        );
      }
    }

    // 用过的**全部钥**（首次出现顺序去重）。合法链不会重复一把钥，但调用方可能递
    // 手写记录；而**换回旧钥**（A→B→A）本身是合法的 ⇒ 这里是**集合**，不是路径。
    final keys = <String>[];
    for (final k in [chain.first.oldPub, ...chain.map((r) => r.newPub)]) {
      if (!keys.contains(k)) keys.add(k);
    }
    // ⚠️ `tip` 是**当前活跃钥** = 链上最后一条的 `newPub`，**不是** `keys.last`。
    //   换回旧钥（A→B→A）会让去重后的列表以"刚被退休的那把"结尾 —— 取 `keys.last`
    //   就把死钥报成了末端，并与 Hub 端点（`hub.js` 读 `chain[chain.length-1].new_pub`）
    //   **不一致**。末端正是读者拿去与"Hub 报的活跃钥"比对的那个值，两侧必须同口径。
    return IdentityKeys(
      agentId: agentId,
      keys: keys,
      tip: chain.last.newPub,
      status: AliasStatus.ok,
      chain: chain,
    );
  }
}

/// 别名解析的稳定码（与 Node 侧 `alias.js` 的 `STATUS` **同字面量**）。
abstract final class AliasStatus {
  /// 链完整、逐环相接、每条都验签通过。
  static const String ok = 'ok';

  /// 这把钥不在任何换钥记录里 —— 它就是它自己的整个身份。
  static const String noChain = 'no_chain';

  /// 同一把钥被两个身份的链同时认领 —— 拒绝替任何一方下结论。
  static const String ambiguous = 'ambiguous';

  /// 链上至少有一条**不是被它声称要退休的那把钥**签的。
  static const String unsigned = 'unsigned';

  /// 逐环接不上：漏记了一次换钥，或记录被人动过。
  static const String broken = 'broken';

  /// 全部码（用于输出与反序列化校验；新增码必须同时改这两端）。
  static const List<String> values = [ok, noChain, ambiguous, unsigned, broken];

  static bool isOk(String v) => v == ok;
}

/// [RotationChain.keysOf] 的结果：一个身份的**全部历史公钥**。
///
/// `status != ok` 时 [keys] 一定是 `[查询的那把钥]` 而不是别的 —— 宁可"少给"
/// （用户看到自己那把钥的履历），绝不可"错给"（把别人的履历算到他头上）。
class IdentityKeys {
  final String? agentId;

  /// 该身份用过的**全部公钥**（首次出现顺序去重）。★ **不是**"创世 → 当前"的路径：
  /// 换回旧钥（A→B→A）是合法的，此时末位是**已退休**的那把 —— 当前活跃钥看 [tip]。
  final List<String> keys;

  /// **当前活跃钥** = 链上最后一条的 `newPub`（未解析出链时就是查询的那把钥）。
  /// ⚠️ 与 `keys.last` **不等价**：换回旧钥时 `keys.last` 是一把死钥。
  final String tip;

  final String status; // AliasStatus.*

  /// 解析所依据的原始记录 —— 交给读者复核"我为什么这么算"。
  final List<IdentityRotation> chain;

  const IdentityKeys({
    this.agentId,
    this.keys = const [],
    this.tip = '',
    this.status = AliasStatus.noChain,
    this.chain = const [],
  });

  bool get resolved => status == AliasStatus.ok && keys.length > 1;

  /// 供 UI 用的一句话摘要（**不是**给用户看的文案，文案在 ARB 里）。
  @override
  String toString() => 'IdentityKeys($status, ${keys.length} keys)';
}
