/// M3 · 陌生人互介（PRD §4 M3，链路 β 的核心）。
///
/// 一张互介卡 = 我的分身向另一个分身发出的自我介绍：
/// "为什么值得认识 + 3 个可聊话题"。
///
/// 三条验收（二值，全部在本层强制，UI 想违反都难）：
/// 1. **未经主人确认的卡不会发出** —— 线格式只对 approved 状态的卡编码，
///    `dispatch` 对未确认卡直接拒绝并留痕。
/// 2. **第③级（仅本人可见）字段不出现在卡里** —— 两道闸：
///    a) 生成时按禁键过滤字段；b) **禁键的值**若出现在卡文本里，
///    整张卡拒绝生成（fail-closed）——因为光删键挡不住"主人把手机号写进 reason"。
/// 3. **发出后 24h 内可撤回，撤回后对方侧卡片消失** —— 撤回报文让对端删除。
///
/// 与 M2 委托同款纪律：全程留痕、发出时签名、对端验签 fail-closed。
/// 本文件**零平台依赖**，`dart run tool/verify_intercard.dart` 可验证。

library;

import 'dart:math';
import 'dart:convert';

import 'agent_protocol.dart';
import 'circle_service.dart'; // 复用 Signer 抽象
import 'telemetry.dart' show TelemetryEvents;

// ---------------------------------------------------------------------------
// 数据模型
// ---------------------------------------------------------------------------

enum InterCardState {
  generated, // 草稿：主人还没确认，**不可发出**
  approved, // 主人已确认（已签名），可发出
  revoked, // 已撤回（24h 窗口内）
}

class InterCard {
  final String id;
  final String circleId;
  final String ownerId; // 卡片介绍的是谁（= 主人自己的分身）
  final String toId; // 收卡方
  final String reason; // 为什么值得认识
  final List<String> topics; // 3 个可聊话题
  final Map<String, String> fields; // 披露快照（生成时已过滤第③级）
  final int generatedAtMs;
  final int? approvedAtMs;
  final int? sentAtMs;
  final int? revokedAtMs;

  final String? sig; // 主人确认时的签名（覆盖 canonical）
  final String? ownerPub;

  const InterCard({
    required this.id,
    required this.circleId,
    required this.ownerId,
    required this.toId,
    required this.reason,
    required this.topics,
    required this.fields,
    required this.generatedAtMs,
    this.approvedAtMs,
    this.sentAtMs,
    this.revokedAtMs,
    this.sig,
    this.ownerPub,
  });

  InterCardState get state => revokedAtMs != null
      ? InterCardState.revoked
      : approvedAtMs != null
          ? InterCardState.approved
          : InterCardState.generated;

  bool get isConfirmed => approvedAtMs != null;

  /// 撤回窗口（PRD：发出后 24h 内）。
  static const Duration revokeWindow = Duration(hours: 24);

  /// [nowMs] 供注入（验证可复算）。
  bool canRevokeAt(int nowMs) {
    final sent = sentAtMs;
    if (sent == null) return false;
    if (revokedAtMs != null) return false;
    return nowMs - sent <= revokeWindow.inMilliseconds;
  }

  /// 规范串（签名覆盖对象）。fields 按 key 排序，保证同一张卡签名唯一。
  String canonical() {
    final sortedFields =
        Map.fromEntries(fields.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return 'ICARD|$id|$circleId|$ownerId|$toId|$reason|'
        '${topics.join('::')}|${jsonEncode(sortedFields)}|'
        '${approvedAtMs ?? 0}';
  }

  /// 卡的全部可见文本（供第③级"值泄漏"检查）。
  String visibleText() =>
      '$reason ${topics.join(' ')} ${fields.entries.map((e) => '${e.key}:${e.value}').join(' ')}';

  Map<String, Object?> toMap() => {
        'id': id,
        'circle_id': circleId,
        'owner_id': ownerId,
        'to_id': toId,
        'reason': reason,
        'topics': topics.join('::'),
        'fields': jsonEncode(fields),
        'generated_at': generatedAtMs,
        'approved_at': approvedAtMs,
        'sent_at': sentAtMs,
        'revoked_at': revokedAtMs,
        'sig': sig,
        'owner_pub': ownerPub,
      };

  static InterCard fromMap(Map<String, dynamic> m) => InterCard(
        id: m['id'] as String,
        circleId: m['circle_id'] as String,
        ownerId: m['owner_id'] as String,
        toId: m['to_id'] as String,
        reason: m['reason'] as String? ?? '',
        topics: (m['topics'] as String? ?? '')
            .split('::')
            .where((s) => s.isNotEmpty)
            .toList(),
        fields: Map<String, String>.from(
            (jsonDecode(m['fields'] as String? ?? '{}') as Map?) ?? {}),
        generatedAtMs: (m['generated_at'] as num).toInt(),
        approvedAtMs: (m['approved_at'] as num?)?.toInt(),
        sentAtMs: (m['sent_at'] as num?)?.toInt(),
        revokedAtMs: (m['revoked_at'] as num?)?.toInt(),
        sig: m['sig'] as String?,
        ownerPub: m['owner_pub'] as String?,
      );

  InterCard copyWith({
    int? approvedAtMs,
    int? sentAtMs,
    int? revokedAtMs,
    String? sig,
    String? ownerPub,
  }) =>
      InterCard(
        id: id,
        circleId: circleId,
        ownerId: ownerId,
        toId: toId,
        reason: reason,
        topics: topics,
        fields: fields,
        generatedAtMs: generatedAtMs,
        approvedAtMs: approvedAtMs ?? this.approvedAtMs,
        sentAtMs: sentAtMs ?? this.sentAtMs,
        revokedAtMs: revokedAtMs ?? this.revokedAtMs,
        sig: sig ?? this.sig,
        ownerPub: ownerPub ?? this.ownerPub,
      );
}

// ---------------------------------------------------------------------------
// 存储
// ---------------------------------------------------------------------------

abstract class InterCardStore {
  Future<void> upsert(InterCard c);

  /// 幂等写入：已存在的卡（含已收到的）不覆盖。
  Future<void> insertIfAbsent(InterCard c);

  Future<InterCard?> byId(String id);

  /// 删除（撤回报文到达时用 —— 验收③：对方侧卡片消失）。
  Future<void> delete(String id);

  /// 发给我的、未撤回的卡（收件箱）。
  Future<List<InterCard>> inbox(String toId);

  /// 我发出/草稿的卡。
  Future<List<InterCard>> mine(String ownerId);
}

class MemoryInterCardStore implements InterCardStore {
  final Map<String, InterCard> _rows = {};

  @override
  Future<void> upsert(InterCard c) async => _rows[c.id] = c;

  @override
  Future<void> insertIfAbsent(InterCard c) async =>
      _rows.putIfAbsent(c.id, () => c);

  @override
  Future<InterCard?> byId(String id) async => _rows[id];

  @override
  Future<void> delete(String id) async => _rows.remove(id);

  @override
  Future<List<InterCard>> inbox(String toId) async => _rows.values
      .where((c) => c.toId == toId && c.state != InterCardState.revoked)
      .toList();

  @override
  Future<List<InterCard>> mine(String ownerId) async => _rows.values
      .where((c) => c.ownerId == ownerId)
      .toList()
    ..sort((a, b) => a.generatedAtMs.compareTo(b.generatedAtMs));
}

// ---------------------------------------------------------------------------
// 服务
// ---------------------------------------------------------------------------

class GenerateResult {
  final InterCard? card;
  final bool blocked;
  final String? reason; // l3_leak / empty_content

  const GenerateResult({this.card, this.blocked = false, this.reason});
  bool get ok => !blocked && card != null;
}

class InterCardService {
  final InterCardStore store;
  final Signer signer;
  final void Function(String name, Map<String, Object?> props)? onEvent;

  InterCardService({required this.store, required this.signer, this.onEvent});

  int _now() => DateTime.now().millisecondsSinceEpoch;
  /// ★ 0.115.0：同 `delegation_service` —— 原式只由毫秒时间戳构成
  ///   （且末段拼的是**长度数字**而非随机量）⇒ 同毫秒必撞。
  String _newId() =>
      'ic_${_now().toRadixString(36)}${_randSuffix()}';

  /// 6 位随机后缀（base36），`Random.secure()`。
  static final Random _rng = Random.secure();
  String _randSuffix() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final b = StringBuffer();
    for (var i = 0; i < 6; i++) {
      b.write(chars[_rng.nextInt(chars.length)]);
    }
    return b.toString();
  }

  /// 生成草稿（**不发出**）。
  ///
  /// [fields] 是主人勾选的**第②级（互介可用）**字段；
  /// [forbiddenKeys] 是**第③级（仅本人可见）**的键 —— 键被剔除，
  /// 且它们的**值**若出现在卡文本里，整张卡拒绝生成（fail-closed）。
  Future<GenerateResult> generate({
    required String circleId,
    required String ownerId,
    required String toId,
    required String reason,
    required List<String> topics,
    required Map<String, String> fields,
    Set<String> forbiddenKeys = const {},
  }) async {
    final cleanTopics = topics.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (reason.trim().isEmpty || cleanTopics.isEmpty) {
      return const GenerateResult(blocked: true, reason: 'empty_content');
    }

    // ① 键过滤（大小写不敏感）
    final forbiddenLower = forbiddenKeys.map((k) => k.toLowerCase()).toSet();
    final safeFields = <String, String>{};
    for (final e in fields.entries) {
      if (!forbiddenLower.contains(e.key.toLowerCase()) && e.value.trim().isNotEmpty) {
        safeFields[e.key] = e.value.trim();
      }
    }

    // ② 值泄漏检查：第③级的**值**出现在卡文本里 → 拒绝生成
    final draftText =
        '$reason ${cleanTopics.join(' ')} ${safeFields.values.join(' ')}'.toLowerCase();
    for (final key in forbiddenKeys) {
      final v = fields[key]?.trim().toLowerCase();
      if (v != null && v.isNotEmpty && draftText.contains(v)) {
        onEvent?.call(TelemetryEvents.intercardGenerated, {
          'self': ownerId,
          'peer': toId,
          'contains_l3': true, // 被拦下的也算一次生成尝试，且必须留痕
          'blocked': 'l3_leak',
        });
        return const GenerateResult(blocked: true, reason: 'l3_leak');
      }
    }

    final card = InterCard(
      id: _newId(),
      circleId: circleId,
      ownerId: ownerId,
      toId: toId,
      reason: reason.trim(),
      topics: cleanTopics,
      fields: safeFields,
      generatedAtMs: _now(),
    );
    await store.upsert(card);
    onEvent?.call(TelemetryEvents.intercardGenerated, {
      'self': ownerId,
      'peer': toId,
      'contains_l3': false, // 验收②：字典口径要求"应始终为否"
    });
    return GenerateResult(card: card);
  }

  /// 主人确认（打签名）。**只有这一步之后卡才能被编码上线**（验收①）。
  Future<InterCard?> approve({required String id, required String approverId}) async {
    final c = await store.byId(id);
    if (c == null) return null;
    if (c.ownerId != approverId) return null; // 只有本人能确认自己的卡
    if (c.isConfirmed) return c; // 幂等
    final pub = await signer.publicKeyBase58();
    final approvedAt = _now();
    final updated0 = c.copyWith(approvedAtMs: approvedAt, ownerPub: pub);
    final sig = await signer.signBytes(utf8.encode(updated0.canonical()));
    final updated = updated0.copyWith(sig: sig);
    await store.upsert(updated);
    onEvent?.call(TelemetryEvents.intercardApproved, {
      'self': c.ownerId,
      'peer': c.toId,
      'card_id': id,
      'contains_l3': false,
    });
    return updated;
  }

  /// 发出成功后由 relay 回填 sent 时刻（撤回窗口从这一刻起算）。
  Future<InterCard?> markSent({required String id}) async {
    final c = await store.byId(id);
    if (c == null || !c.isConfirmed) return null;
    final updated = c.copyWith(sentAtMs: _now());
    await store.upsert(updated);
    onEvent?.call(TelemetryEvents.intercardSent, {
      'self': c.ownerId,
      'peer': c.toId,
      'card_id': id,
    });
    return updated;
  }

  /// 撤回：发出后 24h 内有效（验收③的前半）。
  Future<InterCard?> revoke({required String id, required String revokerId}) async {
    final c = await store.byId(id);
    if (c == null) return null;
    if (c.ownerId != revokerId) return null;
    if (!c.canRevokeAt(_now())) return null;
    final updated = c.copyWith(revokedAtMs: _now());
    await store.upsert(updated);
    onEvent?.call(TelemetryEvents.intercardRevoked, {
      'self': c.ownerId,
      'peer': c.toId,
      'card_id': id,
    });
    return updated;
  }
}

// ---------------------------------------------------------------------------
// 线格式与投递（与 M2 同款：验签 fail-closed、不代客决策）
// ---------------------------------------------------------------------------

class InterCardWire {
  static const String _type = 'intercard';
  static const int _version = 1;
  static const int maxWireChars = 8 * 1024;

  static String encodeCard(InterCard c) {
    if (!c.isConfirmed || c.sig == null) {
      throw StateError('unconfirmed card must never be serialized (验收①)');
    }
    return jsonEncode({'da_type': _type, 'v': _version, 'kind': 'card', 'c': c.toMap()});
  }

  static String encodeRevoke(InterCard c) => jsonEncode({
        'da_type': _type,
        'v': _version,
        'kind': 'revoke',
        'card_id': c.id,
        'owner_id': c.ownerId,
      });

  /// 返回 (kind, card|revokeId) —— 解析失败返回 null。
  static Map<String, Object?>? tryParse(String text) {
    final t = text.trim();
    if (t.length > maxWireChars) return null;
    if (!t.startsWith('{') || !t.endsWith('}')) return null;
    try {
      final m = jsonDecode(t);
      if (m is! Map || m['da_type'] != _type) return null;
      if ((m['v'] as num?)?.toInt() != _version) return null;
      final kind = m['kind'];
      if (kind == 'revoke') {
        final cid = m['card_id'];
        final oid = m['owner_id'];
        if (cid is String && oid is String) {
          return {'kind': 'revoke', 'card_id': cid, 'owner_id': oid};
        }
        return null;
      }
      if (kind == 'card') {
        final c = m['c'];
        if (c is! Map) return null;
        final card = InterCard.fromMap(Map<String, dynamic>.from(c));
        if (!card.isConfirmed || card.sig == null || card.ownerPub == null) {
          return null; // 未确认卡上线 = 协议违规，直接拒收
        }
        return {'kind': 'card', 'card': card};
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// 出站通道抽象（与 M2 委托同一签名，可共用同一个 outbound）。
typedef InterCardSender = Future<bool> Function(String targetAgentId, String wire);

class InterCardRelay {
  final InterCardStore store;
  final InterCardSender send;
  final InterCardService service; // markSent 用
  final Future<String> Function()? selfId;
  final void Function(String name, Map<String, Object?> props)? onEvent;

  InterCardRelay({
    required this.store,
    required this.send,
    required this.service,
    this.selfId,
    this.onEvent,
  });

  /// 发起方：把已确认的卡投递给对方。
  Future<bool> dispatch(InterCard c) async {
    if (!c.isConfirmed) {
      // 验收①的运行时兜底：UI 绕过确认也发不出去
      onEvent?.call('intercard_dropped',
          {'self': c.ownerId, 'peer': c.toId, 'reason': 'unconfirmed'});
      return false;
    }
    final ok = await send(c.toId, InterCardWire.encodeCard(c));
    if (ok) {
      await service.markSent(id: c.id);
    } else {
      onEvent?.call('intercard_dropped',
          {'self': c.ownerId, 'peer': c.toId, 'reason': 'no_channel'});
    }
    return ok;
  }

  /// 撤回通知。
  Future<bool> dispatchRevoke(InterCard c) async {
    final ok = await send(c.toId, InterCardWire.encodeRevoke(c));
    onEvent?.call(ok ? 'intercard_revoked_sent' : 'intercard_dropped', {
      'self': c.ownerId,
      'peer': c.toId,
      'card_id': c.id,
      if (!ok) 'reason': 'no_channel',
    });
    return ok;
  }

  /// 入站：解析 → 验签 → 落库 / 删除。
  /// 返回 true = 报文已被消费（是互介报文）。
  Future<bool> onIncoming(String fromAgentId, String text) async {
    final packet = InterCardWire.tryParse(text);
    if (packet == null) return false;
    final kind = packet['kind'] as String;
    final me = selfId == null ? null : await selfId!();

    Future<void> drop(String reason, {String? cardId}) async {
      onEvent?.call('intercard_dropped', {
        'self': me ?? '',
        'peer': fromAgentId,
        if (cardId != null) 'card_id': cardId,
        'reason': reason,
      });
    }

    if (kind == 'revoke') {
      final cardId = packet['card_id'] as String;
      final ownerId = packet['owner_id'] as String;
      if (ownerId != fromAgentId) {
        await drop('sender_mismatch', cardId: cardId);
        return true;
      }
      await store.delete(cardId); // 验收③：对方侧卡片消失
      return true;
    }

    final card = packet['card'] as InterCard;
    if (card.ownerId != fromAgentId) {
      await drop('sender_mismatch', cardId: card.id);
      return true;
    }
    if (me != null && card.toId != me) {
      await drop('misrouted', cardId: card.id);
      return true;
    }
    // 验签：卡内容在签名之后被改过 → 丢弃
    final ok = await AgentProtocol.verifyRawSignature(
      utf8.encode(card.canonical()),
      card.sig!,
      card.ownerPub!,
    );
    if (!ok) {
      await drop('bad_signature', cardId: card.id);
      return true;
    }
    await store.insertIfAbsent(card); // 幂等：重放不覆盖
    onEvent?.call('intercard_received', {
      'self': card.toId,
      'peer': card.ownerId,
      'card_id': card.id,
      'contains_l3': false,
    });
    return true;
  }
}
