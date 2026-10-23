import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'agent_protocol.dart';

/// M1 · 入场即进圈（PRD §4）。
///
/// 与旧设计的区别：**邀请的产物不是一条边，而是一次入场**。
///   旧：A 邀请 B → A↔B 二元结对 → 10 对 = 10 个孤岛，无网络效应；
///      且 A、B 若关系一般，B 打开只看到 A，**反而放大孤岛感**。
///   新：B 进入 A 所在的**邻里圈**（同城/同兴趣），第一天就见到多个非 A 的分身。
///
/// 设计约束（PRD §5.4「不可补录」原则）：
///   圈子成员关系必须带**双向签名**，且必须在第一个用户之前就位——
///   关系一旦建立却无签名，历史就无法追溯补签。
///   因此本模块把签名作为一等公民：membership 记录同时持有 memberSig 与 hostSig，
///   二者覆盖**同一份 canonical 载荷**，任何一方事后都无法单方伪造。
///
/// 可测试性：签名能力通过 [Signer] 注入，持久化通过 [CircleStore] 注入，
/// 因此本文件的全部逻辑可在 `flutter test` / `dart run` 中不依赖插件通道验证。

// ---------------------------------------------------------------- 签名抽象

/// 签名能力抽象。生产用 AgentIdentitySigner，测试用 Ed25519Signer（纯 Dart）。
abstract class Signer {
  Future<String> publicKeyBase58();
  Future<String> signBytes(List<int> message);
}

/// 生产实现：复用设备 Ed25519 身份（私钥永不出设备）。
class AgentIdentitySigner implements Signer {
  final Future<String> Function() _pub;
  final Future<String> Function(List<int>) _sign;

  AgentIdentitySigner({required Future<String> Function() pub,
    required Future<String> Function(List<int>) sign})
      : _pub = pub,
        _sign = sign;

  @override
  Future<String> publicKeyBase58() => _pub();

  @override
  Future<String> signBytes(List<int> message) => _sign(message);
}

/// 测试/纯 Dart 实现：直接用 cryptography 的 Ed25519，不碰 SharedPreferences。
class Ed25519Signer implements Signer {
  final SimpleKeyPair keyPair;
  Ed25519Signer(this.keyPair);

  static Future<Ed25519Signer> generate() async =>
      Ed25519Signer(await Ed25519().newKeyPair());

  @override
  Future<String> publicKeyBase58() async {
    final pub = await keyPair.extractPublicKey();
    return AgentProtocol.base58Encode(pub.bytes);
  }

  @override
  Future<String> signBytes(List<int> message) async {
    final sig = await Ed25519().sign(message, keyPair: keyPair);
    return base64Encode(sig.bytes);
  }
}

// ---------------------------------------------------------------- 数据模型

/// 邀请码的载荷。编码为 `base64url(json).sig`。
class CircleInvite {
  final String circleId;
  final String circleName;
  final String inviterId;
  final String inviterPub;
  final String nonce;
  final int expMs;
  final String sig;

  const CircleInvite({
    required this.circleId,
    required this.circleName,
    required this.inviterId,
    required this.inviterPub,
    required this.nonce,
    required this.expMs,
    required this.sig,
  });

  /// 待签名的规范载荷（字段顺序固定，防歧义）。
  String canonical() =>
      'INVITE|$circleId|$circleName|$inviterId|$inviterPub|$nonce|$expMs';

  String encode() {
    final jsonPart = base64Url.encode(utf8.encode(jsonEncode({
      'circleId': circleId,
      'circleName': circleName,
      'inviterId': inviterId,
      'inviterPub': inviterPub,
      'nonce': nonce,
      'exp': expMs,
    })));
    return '$jsonPart.$sig';
  }

  static CircleInvite? decode(String code) {
    final parts = code.split('.');
    if (parts.length != 2) return null;
    try {
      final m = jsonDecode(
          utf8.decode(base64Url.decode(parts[0]))) as Map<String, dynamic>;
      return CircleInvite(
        circleId: m['circleId'] as String,
        circleName: (m['circleName'] as String?) ?? '',
        inviterId: m['inviterId'] as String,
        inviterPub: m['inviterPub'] as String,
        nonce: m['nonce'] as String,
        expMs: (m['exp'] as num).toInt(),
        sig: parts[1],
      );
    } catch (_) {
      return null;
    }
  }

  bool isExpired(int nowMs) => nowMs > expMs;

  /// 校验邀请码确由 [inviterPub] 签发（防止伪造邀请把人拉进钓鱼圈）。
  Future<bool> verify() => AgentProtocol.verifyRawSignature(
        utf8.encode(canonical()),
        sig,
        inviterPub,
      );
}

/// 圈子成员关系。**双向签名**是一等公民。
class CircleMembership {
  final String circleId;
  final String memberId;
  final String memberPub;
  final String inviterId;
  final int joinedAtMs;

  /// 加入方对自己入圈行为的签名（加入瞬间生成，不可后补）。
  final String? memberSig;

  /// 邀请方（圈主）对同一次入圈的签名（对方上线确认时生成）。
  final String? hostSig;

  final String? hostPub;

  const CircleMembership({
    required this.circleId,
    required this.memberId,
    required this.memberPub,
    required this.inviterId,
    required this.joinedAtMs,
    this.memberSig,
    this.hostSig,
    this.hostPub,
  });

  /// 双方共同签名的规范载荷——**两把签名覆盖同一份字节**，这是"不可单方伪造"的关键。
  String canonical() =>
      'JOIN|$circleId|$memberId|$memberPub|$inviterId|$joinedAtMs';

  bool get isFullySigned => memberSig != null && hostSig != null;

  CircleMembership copyWith({String? hostSig, String? hostPub}) =>
      CircleMembership(
        circleId: circleId,
        memberId: memberId,
        memberPub: memberPub,
        inviterId: inviterId,
        joinedAtMs: joinedAtMs,
        memberSig: memberSig,
        hostSig: hostSig ?? this.hostSig,
        hostPub: hostPub ?? this.hostPub,
      );

  Future<bool> verifyMember() => memberSig == null
      ? Future.value(false)
      : AgentProtocol.verifyRawSignature(
          utf8.encode(canonical()), memberSig!, memberPub);

  Future<bool> verifyHost() => (hostSig == null || hostPub == null)
      ? Future.value(false)
      : AgentProtocol.verifyRawSignature(
          utf8.encode(canonical()), hostSig!, hostPub!);

  /// 完整校验：两把签名都在且都有效。
  Future<bool> verify() async => await verifyMember() && await verifyHost();

  Map<String, Object?> toMap() => {
        'circle_id': circleId,
        'member_id': memberId,
        'member_pub': memberPub,
        'inviter_id': inviterId,
        'joined_at': joinedAtMs,
        'member_sig': memberSig,
        'host_sig': hostSig,
        'host_pub': hostPub,
      };

  static CircleMembership fromMap(Map<String, dynamic> m) => CircleMembership(
        circleId: m['circle_id'] as String,
        memberId: m['member_id'] as String,
        memberPub: m['member_pub'] as String,
        inviterId: m['inviterId'] as String? ?? m['inviter_id'] as String? ?? '',
        joinedAtMs: (m['joined_at'] as num).toInt(),
        memberSig: m['member_sig'] as String?,
        hostSig: m['host_sig'] as String?,
        hostPub: m['host_pub'] as String?,
      );
}

// ---------------------------------------------------------------- 存储抽象

abstract class CircleStore {
  Future<void> upsertMembership(CircleMembership m);
  Future<List<CircleMembership>> membersOf(String circleId);
  Future<CircleMembership?> find(String circleId, String memberId);

  Future<void> upsertCircle(
      {required String id, required String name, String? city});
}

class MemoryCircleStore implements CircleStore {
  final Map<String, CircleMembership> _rows = {};
  final Map<String, Map<String, String>> _circles = {};

  @override
  Future<void> upsertMembership(CircleMembership m) async {
    _rows['${m.circleId}::${m.memberId}'] = m;
  }

  @override
  Future<List<CircleMembership>> membersOf(String circleId) async => _rows.values
      .where((m) => m.circleId == circleId)
      .toList()
    ..sort((a, b) => a.joinedAtMs.compareTo(b.joinedAtMs));

  @override
  Future<CircleMembership?> find(String circleId, String memberId) async =>
      _rows['$circleId::$memberId'];

  @override
  Future<void> upsertCircle(
          {required String id, required String name, String? city}) async =>
      _circles[id] = {'name': name, 'city': city ?? ''};
}

// ---------------------------------------------------------------- 服务

/// 可见分身的兜底来源：当圈子人数不足时，由宿主注入（如"同房间/同城在线分身"）。
typedef NeighborFallback = Future<List<String>> Function(
    String circleId, String selfId);

class CircleService {
  final CircleStore store;
  final Signer signer;
  final NeighborFallback? neighborFallback;

  /// 埋点回调（可选）：入圈/邀请事件写入 Telemetry。
  final void Function(String name, Map<String, Object?> props)? onEvent;

  CircleService({
    required this.store,
    required this.signer,
    this.neighborFallback,
    this.onEvent,
  });

  int _now() => DateTime.now().millisecondsSinceEpoch;
  String _nonce() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  // ---- 建圈与邀请

  /// 建圈。**圈主本人必须是圈子的第一个成员**——
  /// 否则会出现"邀请者不在自己圈子里"的荒谬状态，且新人可见分身数会少一个。
  Future<void> createCircle({
    required String id,
    required String name,
    required String founderId,
    String? city,
  }) async {
    await store.upsertCircle(id: id, name: name, city: city);

    final pub = await signer.publicKeyBase58();
    final ts = _now();
    final founder = CircleMembership(
      circleId: id,
      memberId: founderId,
      memberPub: pub,
      inviterId: founderId, // 自建圈：邀请方即本人
      joinedAtMs: ts,
    );
    final sig = await signer.signBytes(utf8.encode(founder.canonical()));
    await store.upsertMembership(CircleMembership(
      circleId: id,
      memberId: founderId,
      memberPub: pub,
      inviterId: founderId,
      joinedAtMs: ts,
      memberSig: sig,
      hostSig: sig, // 圈主自签，双向签名即达成
      hostPub: pub,
    ));

    onEvent?.call('circle_entered', {'self': founderId, 'circle_id': id});
  }

  /// 生成邀请码：由邀请方签名，接收方可独立验签（不需要联网询问服务器）。
  Future<CircleInvite> createInvite({
    required String circleId,
    required String circleName,
    required String inviterId,
    Duration ttl = const Duration(days: 7),
  }) async {
    final pub = await signer.publicKeyBase58();
    final nonce = _nonce();
    final exp = _now() + ttl.inMilliseconds;
    final draft = CircleInvite(
      circleId: circleId,
      circleName: circleName,
      inviterId: inviterId,
      inviterPub: pub,
      nonce: nonce,
      expMs: exp,
      sig: '',
    );
    final sig = await signer.signBytes(utf8.encode(draft.canonical()));
    final invite = CircleInvite(
      circleId: circleId,
      circleName: circleName,
      inviterId: inviterId,
      inviterPub: pub,
      nonce: nonce,
      expMs: exp,
      sig: sig,
    );
    onEvent?.call('invite_created', {
      'self': inviterId,
      'circle_id': circleId,
      'nonce': nonce,
    });
    return invite;
  }

  /// 接受邀请：加入方**此刻**签名（不可后补），hostSig 待对方确认。
  Future<CircleMembership?> acceptInvite({
    required String code,
    required String memberId,
  }) async {
    final invite = CircleInvite.decode(code);
    if (invite == null) return null;
    if (invite.isExpired(_now())) return null;
    if (!await invite.verify()) return null;

    final pub = await signer.publicKeyBase58();
    final ts = _now();
    final m = CircleMembership(
      circleId: invite.circleId,
      memberId: memberId,
      memberPub: pub,
      inviterId: invite.inviterId,
      joinedAtMs: ts,
    );
    final sig = await signer.signBytes(utf8.encode(m.canonical()));
    final signed = CircleMembership(
      circleId: m.circleId,
      memberId: m.memberId,
      memberPub: m.memberPub,
      inviterId: m.inviterId,
      joinedAtMs: m.joinedAtMs,
      memberSig: sig,
    );
    await store.upsertMembership(signed);

    onEvent?.call('invite_accepted', {
      'self': memberId,
      'peer': invite.inviterId,
      'circle_id': invite.circleId,
    });
    onEvent?.call('circle_entered', {
      'self': memberId,
      'circle_id': invite.circleId,
    });
    return signed;
  }

  /// 圈主对入圈做第二把签名（双向签名达成）。
  Future<CircleMembership?> hostApprove({
    required String circleId,
    required String memberId,
  }) async {
    final m = await store.find(circleId, memberId);
    if (m == null) return null;
    final hostPub = await signer.publicKeyBase58();
    final sig = await signer.signBytes(utf8.encode(m.canonical()));
    final updated = m.copyWith(hostSig: sig, hostPub: hostPub);
    await store.upsertMembership(updated);
    return updated;
  }

  // ---- 可见性（PRD M1 验收口径）

  /// B 入圈后可见的分身集合。
  ///
  /// 验收（二值）：**≥3 个可互动分身，其中 ≥2 个不是邀请者**。
  /// 圈子人数不足时由 [neighborFallback] 兜底（同城/同房间在线分身），
  /// 兜底产出天然不是邀请者，因此只会让"非邀请者数"达标而不会破坏口径。
  Future<CircleVisible> visibleFens({
    required String circleId,
    required String selfId,
    String? inviterId,
    int minFens = 3,
  }) async {
    final members = await store.membersOf(circleId);
    final fromCircle = members
        .where((m) => m.memberId != selfId)
        .map((m) => m.memberId)
        .toList();

    final seen = <String>{...fromCircle};
    final fallback = <String>[];

    if (seen.length < minFens && neighborFallback != null) {
      for (final id in await neighborFallback!(circleId, selfId)) {
        if (id == selfId) continue;
        if (seen.add(id)) fallback.add(id);
      }
    }

    final all = seen.toList();
    final nonInviter =
        all.where((id) => id != inviterId).length;

    return CircleVisible(
      fens: all,
      fromCircle: fromCircle,
      fromFallback: fallback,
      nonInviterCount: inviterId == null ? all.length : nonInviter,
      meetsAcceptance: all.length >= minFens &&
          (inviterId == null ? all.length : nonInviter) >= (minFens - 1),
    );
  }
}

/// 可见性结果（验收可二值判定）。
class CircleVisible {
  final List<String> fens;
  final List<String> fromCircle;
  final List<String> fromFallback;
  final int nonInviterCount;
  final bool meetsAcceptance;

  const CircleVisible({
    required this.fens,
    required this.fromCircle,
    required this.fromFallback,
    required this.nonInviterCount,
    required this.meetsAcceptance,
  });

  @override
  String toString() =>
      'CircleVisible(n=${fens.length}, nonInviter=$nonInviterCount, ok=$meetsAcceptance)';
}
