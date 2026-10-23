import 'dart:convert';

import 'agent_protocol.dart';
import 'delegation_service.dart';

/// M2 委托的**线上信封**（PRD §4：主人下达 → 对方 60 秒内收到）。
///
/// `delegation_service.dart` 只负责本机状态机，这一层负责"把它送到对方设备上"。
/// 与礼物/推荐信保持一致：线格式是 `{"da_type":"deleg", ...}` 的 JSON 文本，
/// 复用既有 `_dispatchRouteMessage`（近场 / 局域网 / 云端全通道覆盖）。
///
/// 三条铁律：
/// 1. **验签不过就丢**：收到的委托必须能用 `fromPub` 验过 `reqSig`，
///    否则无法证明"确实是那个分身下达的"，一律丢弃并留痕（fail-closed）。
/// 2. **不代客决策**：收到只落库，绝不自动回执；回执由对方分身/真人决定。
/// 3. **不可补录**：送达时刻写进埋点 `delegation_received`，
///    `delivery_ms = 收到 − 下达`，这才是「60 秒」这条验收口径能用的数。

enum DelegationWireKind { request, receipt }

/// 一个解析后的线上报文。
class DelegationPacket {
  final DelegationWireKind kind;
  final Delegation delegation;

  const DelegationPacket(this.kind, this.delegation);
}

class DelegationWire {
  static const String _type = 'deleg';
  static const int _version = 1;

  /// 报文上限（8 KB）：防止对端用超大报文打爆本地存储/内存。
  static const int maxWireChars = 8 * 1024;

  static String encode(Delegation d, DelegationWireKind kind) => jsonEncode({
        'da_type': _type,
        'v': _version,
        'kind': kind.name,
        'd': d.toMap(),
      });

  static DelegationPacket? tryParse(String text) {
    final t = text.trim();
    if (t.length > maxWireChars) return null;
    if (!t.startsWith('{') || !t.endsWith('}')) return null;
    try {
      final m = jsonDecode(t);
      if (m is! Map) return null;
      if (m['da_type'] != _type) return null;
      if ((m['v'] as num?)?.toInt() != _version) return null;

      final kind = switch (m['kind']) {
        'request' => DelegationWireKind.request,
        'receipt' => DelegationWireKind.receipt,
        _ => null,
      };
      if (kind == null) return null;

      final d = m['d'];
      if (d is! Map) return null;
      final delegation = Delegation.fromMap(Map<String, dynamic>.from(d));

      // 结构性前置校验：缺签名/公钥的报文在验签阶段就会被拒，这里先挡一次
      if (kind == DelegationWireKind.request) {
        if (delegation.reqSig == null || delegation.fromPub == null) return null;
      } else {
        if (delegation.respSig == null || delegation.toPub == null) return null;
      }
      return DelegationPacket(kind, delegation);
    } catch (_) {
      return null;
    }
  }
}

/// 出站通道抽象：`(对方分身 ID, 线格式文本) → 是否投递成功`。
typedef DelegationSender = Future<bool> Function(
    String targetAgentId, String wire);

class DelegationRelay {
  final DelegationStore store;
  final DelegationSender send;

  /// 我的分身 ID（用于判断"这条是不是发给我的"）。
  final Future<String> Function()? selfId;

  final void Function(String name, Map<String, Object?> props)? onEvent;

  DelegationRelay({
    required this.store,
    required this.send,
    this.selfId,
    this.onEvent,
  });

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// 发起方：把委托投递给对方。
  /// 返回 false = 一条通道都没通（对方不在线 / 没开通道），**本地记录仍在**。
  Future<bool> dispatch(Delegation d) async {
    final ok = await send(d.toId, DelegationWire.encode(d, DelegationWireKind.request));
    onEvent?.call(
      ok ? 'delegation_dispatched' : 'delegation_dropped',
      {
        'self': d.fromId,
        'peer': d.toId,
        'delegation_id': d.id,
        if (!ok) 'reason': 'no_channel',
      },
    );
    // 送达失败靠埋点 `delegation_dropped/reason=no_channel` 留痕，
    // 否则"发出去没回音"和"压根没发出去"分不清。
    // 注意：本文件**不得 import 任何 Flutter 依赖**（app_logger 也不行），
    // 否则 `dart run tool/verify_delegation_transport.dart` 会因 dart:ui 不可用而跑不起来。
    return ok;
  }

  /// 受托方：把回执发回发起方。
  Future<bool> dispatchReceipt(Delegation d) async {
    if (d.respSig == null) return false;
    final ok = await send(d.fromId, DelegationWire.encode(d, DelegationWireKind.receipt));
    onEvent?.call(
      ok ? 'delegation_receipt' : 'delegation_dropped',
      {
        'self': d.toId,
        'peer': d.fromId,
        'delegation_id': d.id,
        'result': d.state.name,
        if (!ok) 'reason': 'no_channel',
      },
    );
    return ok;
  }

  /// 入站：解析 → 验签 → 落库。
  ///
  /// 返回 **true 表示"这是委托报文，已被消费"**（调用方不要再把它送进聊天流水线）；
  /// 返回 false 表示不是委托报文。
  /// 注意：**验签失败也返回 true**（已消费并丢弃），否则会被当成普通聊天消息。
  Future<bool> onIncoming(String fromAgentId, String text) async {
    final packet = DelegationWire.tryParse(text);
    if (packet == null) return false;

    final d = packet.delegation;
    final me = selfId == null ? null : await selfId!();

    void drop(String reason) => onEvent?.call('delegation_dropped', {
          'self': me ?? '',
          'peer': fromAgentId,
          'delegation_id': d.id,
          'reason': reason,
        });

    // ① 路由校验：报文里的收发方必须自洽，且"我是那个该收到的人"
    if (packet.kind == DelegationWireKind.request) {
      if (d.fromId != fromAgentId) {
        drop('sender_mismatch');
        return true; // 冒充他人名义 → 丢弃
      }
      if (me != null && d.toId != me) {
        drop('misrouted');
        return true;
      }
      // ② 验签：证明"这条委托确实是 fromPub 那个分身下达的"
      final ok = await AgentProtocol.verifyRawSignature(
        utf8.encode(d.requestCanonical()),
        d.reqSig!,
        d.fromPub!,
      );
      if (!ok) {
        drop('bad_signature');
        return true;
      }
      // ③ 落库（幂等：已存在且已完成的不覆盖）
      final existing = await store.byId(d.id);
      if (existing == null || !existing.isFinished) {
        await store.upsert(d);
        onEvent?.call('delegation_received', {
          'self': d.toId,
          'peer': d.fromId,
          'delegation_id': d.id,
          'delivery_ms': _now() - d.createdAtMs,
        });
      }
      return true;
    }

    // ---- 回执：只有发起方认领
    if (d.toId != fromAgentId) {
      drop('sender_mismatch');
      return true;
    }
    if (me != null && d.fromId != me) {
      drop('misrouted');
      return true;
    }
    final ok = await AgentProtocol.verifyRawSignature(
      utf8.encode(d.receiptCanonical()),
      d.respSig!,
      d.toPub!,
    );
    if (!ok) {
      drop('bad_signature');
      return true;
    }
    final existing = await store.byId(d.id);
    if (existing == null) {
      // 没找到原委托（可能本机没发出过）→ 不凭空建档，避免伪造回执
      drop('unknown_delegation');
      return true;
    }
    if (!existing.isFinished) {
      await store.upsert(d);
      onEvent?.call('delegation_receipt', {
        'self': d.fromId,
        'peer': d.toId,
        'delegation_id': d.id,
        'result': d.state.name,
        'duration_ms': (d.respondedAtMs ?? _now()) - existing.createdAtMs,
      });
    }
    return true;
  }
}
