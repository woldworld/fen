import 'dart:math';
import 'dart:convert';

import 'circle_service.dart';

/// M2 · 事务委托（PRD §4，链路 α 的杀手用法）。
///
/// 需求原文：**"帮我问下老王周末有没有空"** —— 分身之间代办小事，**不涉及任何结算**。
///
/// 三条设计原则
/// 1. **零结算不是口号，是结构上的不可能**（见 [_looksLikeSettlement] 与 Delegation 字段表）：
///    委托记录里**没有任何承载金额的字段**，钱这件事从数据模型上就放不进去。
/// 2. **全程留痕 + 可撤销**：请求与回执双方各签一把，状态机只允许合法迁移；
///    未完成前主人可随时撤销。
/// 3. **TTFD 口径可切换**（PRD §7.1）：埋点同时记录弱/强两种信号，
///    口径从弱切到强时**历史数据仍然可用**（本模块负责把两种信号都存下来）。
///
/// 与 M1 一样：Signer / DelegationStore 均为注入，故全部逻辑可在 `dart run` 中验证。

enum DelegationState {
  pending,
  answered,
  needsHuman,
  declined,
  revoked,
  expired,
}

/// TTFD 判定口径（PRD §7.1 分阶段）。
enum DelegationBasis { weak, strong }

/// 结算类措辞（**fail-closed**：命中即不代发，宁可误拦也不越铁律）。
///
/// 两层匹配：
/// 1. 结算动词（转账/汇款/红包/报销…）；
/// 2. **动词 + 金额**（`转\s*\d`、`¥500`、`$20`）—— 覆盖"帮我转 500 给老王"这类
///    不含"转账"二字但明显是钱的说法。
///
/// 刻意保守：误拦只是让主人手动发一句，误放则是触碰 PRD §2.3 铁律。
/// 只匹配"动词+数字"，不匹配裸数字（如"那个 500 块的票"），避免过度误伤。
final RegExp _settlementPattern = RegExp(
  r'转账|汇款|付款|打钱|借钱|还钱|收款|收款码|红包|结算|报销|买单|垫付|代付|'
  r'转\s*\d|付\s*\d|打\s*\d+\s*(块|元|毛)|'
  r'[¥￥]\s*\d|\$\s*\d|\b\d+\s*(usd|rmb|cny)\b|'
  r'\b(transfer|remit|wire|pay|payment|invoice|settle|refund|venmo|zelle)\b',
  caseSensitive: false,
);

/// 是否看起来像"用户间资金流转"（PRD §2.3 明确不做的四件事之一）。
bool looksLikeSettlement(String text) => _settlementPattern.hasMatch(text);

class Delegation {
  final String id;
  final String circleId;
  final String fromId; // 主人（发起方）
  final String toId; // 圈内对象
  final String task; // 自然语言委托内容
  final int createdAtMs;

  final DelegationState state;
  final String? response;
  final int? respondedAtMs;
  final DelegationBasis? basis;

  /// 请求方签名（发起即签，不可后补）
  final String? reqSig;
  final String? fromPub;

  /// 对方回执签名
  final String? respSig;
  final String? toPub;

  /// 对方真人**主动确认**的时刻（强口径证据）
  final int? humanConfirmedAtMs;

  /// 对方真人在 24h 内**否认/撤回**的时刻（弱口径下会使回执失效）
  final int? humanDeniedAtMs;

  const Delegation({
    required this.id,
    required this.circleId,
    required this.fromId,
    required this.toId,
    required this.task,
    required this.createdAtMs,
    this.state = DelegationState.pending,
    this.response,
    this.respondedAtMs,
    this.basis,
    this.reqSig,
    this.fromPub,
    this.respSig,
    this.toPub,
    this.humanConfirmedAtMs,
    this.humanDeniedAtMs,
  });

  String requestCanonical() => 'DELEG|$id|$circleId|$fromId|$toId|$task|$createdAtMs';

  String receiptCanonical() =>
      'RECEIPT|$id|$toId|$fromId|${state.name}|${response ?? ''}|${respondedAtMs ?? 0}';

  bool get isFinished =>
      state == DelegationState.answered ||
      state == DelegationState.needsHuman ||
      state == DelegationState.declined ||
      state == DelegationState.revoked ||
      state == DelegationState.expired;

  /// 是否可撤销（**未完成即可撤**，PRD"全程留痕、可撤销"）
  bool get canRevoke =>
      state == DelegationState.pending || state == DelegationState.needsHuman;

  Delegation copyWith({
    DelegationState? state,
    String? response,
    int? respondedAtMs,
    DelegationBasis? basis,
    String? respSig,
    String? toPub,
    int? humanConfirmedAtMs,
    int? humanDeniedAtMs,
  }) =>
      Delegation(
        id: id,
        circleId: circleId,
        fromId: fromId,
        toId: toId,
        task: task,
        createdAtMs: createdAtMs,
        state: state ?? this.state,
        response: response ?? this.response,
        respondedAtMs: respondedAtMs ?? this.respondedAtMs,
        basis: basis ?? this.basis,
        reqSig: reqSig,
        fromPub: fromPub,
        respSig: respSig ?? this.respSig,
        toPub: toPub ?? this.toPub,
        humanConfirmedAtMs: humanConfirmedAtMs ?? this.humanConfirmedAtMs,
        humanDeniedAtMs: humanDeniedAtMs ?? this.humanDeniedAtMs,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'circle_id': circleId,
        'from_id': fromId,
        'to_id': toId,
        'task': task,
        'created_at': createdAtMs,
        'state': state.name,
        'response': response,
        'responded_at': respondedAtMs,
        'basis': basis?.name,
        'req_sig': reqSig,
        'from_pub': fromPub,
        'resp_sig': respSig,
        'to_pub': toPub,
        'human_confirmed_at': humanConfirmedAtMs,
        'human_denied_at': humanDeniedAtMs,
      };

  static Delegation fromMap(Map<String, dynamic> m) => Delegation(
        id: m['id'] as String,
        circleId: m['circle_id'] as String,
        fromId: m['from_id'] as String,
        toId: m['to_id'] as String,
        task: m['task'] as String,
        createdAtMs: (m['created_at'] as num).toInt(),
        state: DelegationState.values.firstWhere(
          (s) => s.name == m['state'],
          orElse: () => DelegationState.pending,
        ),
        response: m['response'] as String?,
        respondedAtMs: (m['responded_at'] as num?)?.toInt(),
        basis: m['basis'] == null
            ? null
            : DelegationBasis.values.firstWhere((b) => b.name == m['basis'],
                orElse: () => DelegationBasis.weak),
        reqSig: m['req_sig'] as String?,
        fromPub: m['from_pub'] as String?,
        respSig: m['resp_sig'] as String?,
        toPub: m['to_pub'] as String?,
        humanConfirmedAtMs: (m['human_confirmed_at'] as num?)?.toInt(),
        humanDeniedAtMs: (m['human_denied_at'] as num?)?.toInt(),
      );
}

abstract class DelegationStore {
  Future<void> upsert(Delegation d);
  Future<Delegation?> byId(String id);
  Future<List<Delegation>> forPeer(String agentId);
}

class MemoryDelegationStore implements DelegationStore {
  final Map<String, Delegation> _rows = {};

  @override
  Future<void> upsert(Delegation d) async => _rows[d.id] = d;

  @override
  Future<Delegation?> byId(String id) async => _rows[id];

  @override
  Future<List<Delegation>> forPeer(String agentId) async => _rows.values
      .where((d) => d.toId == agentId || d.fromId == agentId)
      .toList()
    ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
}

/// 委托结果：带上是否被结算护栏拦下（PRD"不碰用户间资金"）。
class DelegationResult {
  final Delegation? delegation;
  final bool blocked;
  final String? reason;

  const DelegationResult({this.delegation, this.blocked = false, this.reason});

  bool get ok => !blocked && delegation != null;
}

class DelegationService {
  final DelegationStore store;
  final Signer signer;
  final void Function(String name, Map<String, Object?> props)? onEvent;

  /// 弱口径下"真人在多久内没否认"才算数（PRD §7.1：24h 内未否认/未撤回）
  static const Duration weakDenyWindow = Duration(hours: 24);

  /// 强口径下"真人主动确认"的时效（PRD §7.1：N 小时内，默认取 24h）
  static const Duration strongConfirmWindow = Duration(hours: 24);

  DelegationService({required this.store, required this.signer, this.onEvent});

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// ★ 0.115.0：ID 必须**自带随机后缀** —— 原式只由毫秒时间戳构成，
  ///   **同一毫秒内两次 create 必得同一个 ID**（实测：批量跑时
  ///   `verify_delegation_transport` 的「未知委托 → 不凭空建档」负例
  ///   因 ghost 回执与真委托撞 id 而红；单跑绿、批量红 ⇒ 是真缺陷被负载放大）。
  ///   前缀格式不变（存量 id 仍可解析），只追加 6 位随机 36 进制。
  String _newId() =>
      'dlg_${_now().toRadixString(36)}${_randSuffix()}';

  /// 6 位随机后缀（base36）。用 `Random.secure()` —— 与工单号同口径。
  static final Random _rng = Random.secure();
  String _randSuffix() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final b = StringBuffer();
    for (var i = 0; i < 6; i++) {
      b.write(chars[_rng.nextInt(chars.length)]);
    }
    return b.toString();
  }

  /// 主人下达委托。命中结算措辞 → **fail-closed 不代发**。
  Future<DelegationResult> create({
    required String circleId,
    required String fromId,
    required String toId,
    required String task,
  }) async {
    if (task.trim().isEmpty) {
      return const DelegationResult(
          blocked: true, reason: 'empty_task');
    }
    if (looksLikeSettlement(task)) {
      return const DelegationResult(
        blocked: true,
        reason: 'settlement_not_allowed',
      );
    }

    final id = _newId();
    final ts = _now();
    final pub = await signer.publicKeyBase58();
    final draft = Delegation(
      id: id,
      circleId: circleId,
      fromId: fromId,
      toId: toId,
      task: task,
      createdAtMs: ts,
    );
    final sig = await signer.signBytes(utf8.encode(draft.requestCanonical()));

    final d = Delegation(
      id: id,
      circleId: circleId,
      fromId: fromId,
      toId: toId,
      task: task,
      createdAtMs: ts,
      reqSig: sig,
      fromPub: pub,
      state: DelegationState.pending,
    );
    await store.upsert(d);
    onEvent?.call('delegation_sent', {
      'self': fromId,
      'peer': toId,
      'delegation_id': id,
      'circle_id': circleId,
    });
    return DelegationResult(delegation: d);
  }

  /// 对方分身代答 / 转达本人。回执同样签名（留痕）。
  Future<Delegation?> respond({
    required String id,
    required String responderId,
    required DelegationState state,
    String? response,
  }) async {
    final d = await store.byId(id);
    if (d == null) return null;
    if (d.toId != responderId) return null; // 只有受托方可以回执
    if (d.isFinished) return null;

    if (state != DelegationState.answered &&
        state != DelegationState.needsHuman &&
        state != DelegationState.declined) {
      return null;
    }

    final ts = _now();
    final pub = await signer.publicKeyBase58();
    final updated0 = d.copyWith(
      state: state,
      response: response,
      respondedAtMs: ts,
      toPub: pub,
    );
    final sig = await signer.signBytes(utf8.encode(updated0.receiptCanonical()));
    final updated = updated0.copyWith(respSig: sig);

    await store.upsert(updated);

    if (state == DelegationState.answered) {
      onEvent?.call('delegation_done', {
        'self': d.fromId,
        'peer': d.toId,
        'delegation_id': id,
        'duration_ms': ts - d.createdAtMs,
        'result': 'done',
        // 埋点同时记录两种信号：此刻按弱口径落，后续若转强口径，历史仍可重算
        'basis': DelegationBasis.weak.name,
      });
    } else if (state == DelegationState.needsHuman) {
      onEvent?.call('delegation_needs_human', {
        'self': d.fromId,
        'peer': d.toId,
        'delegation_id': id,
      });
    }
    return updated;
  }

  /// 撤销（主人侧，未完成即可撤）。
  Future<Delegation?> revoke({
    required String id,
    required String ownerId,
  }) async {
    final d = await store.byId(id);
    if (d == null) return null;
    if (d.fromId != ownerId) return null;
    if (!d.canRevoke) return null;
    final updated = d.copyWith(state: DelegationState.revoked);
    await store.upsert(updated);
    onEvent?.call('delegation_revoked', {
      'self': ownerId,
      'peer': d.toId,
      'delegation_id': id,
    });
    return updated;
  }

  /// 对方真人主动确认（强口径证据）。
  ///
  /// [atMs] 可注入，用于把历史信号回填/重算口径（不写死"现在"）。
  Future<Delegation?> markHumanConfirmed({
    required String id,
    required String humanId,
    int? atMs,
  }) async {
    final d = await store.byId(id);
    if (d == null) return null;
    if (d.fromId != humanId) return null; // 由**发起方**记录对方的真人确认
    final updated = d.copyWith(humanConfirmedAtMs: atMs ?? _now());
    await store.upsert(updated);
    return updated;
  }

  /// 对方真人否认/撤回（弱口径下会让"分身代答"失效）。
  Future<Delegation?> markHumanDenied({required String id, int? atMs}) async {
    final d = await store.byId(id);
    if (d == null) return null;
    final updated = d.copyWith(humanDeniedAtMs: atMs ?? _now());
    await store.upsert(updated);
    return updated;
  }

  /// TTFD 口径判定（PRD §7.1）。
  ///
  /// 弱口径（M4 之前）：对方分身回执 + 对方真人 24h 内未否认/未撤回。
  /// 强口径（M4 之后）：对方真人在回执后 24h 内主动确认。
  ///
  /// 关键性质：**口径写在记录本身，不随"现在"漂移**。
  /// 强/弱只由存储下来的两条信号（回执时刻、真人确认时刻）导出，
  /// 因此 M4 把口径从弱切到强时，历史委托可以整体重算，不会作废。
  ///
  /// 返回 null 表示**按任一口径都不算完成**。
  DelegationBasis? evaluateBasis(Delegation d, {int? nowMs}) {
    final now = nowMs ?? _now();
    if (d.state != DelegationState.answered) return null;
    final respondedAt = d.respondedAtMs;
    if (respondedAt == null) return null;

    // ① 真人否认优先：否认发生在回执/确认之后 24h 内 → 两种口径都不算完成。
    //    超出窗口的否认仍然留痕，但不回溯作废已成立的回执（否则历史口径永远悬空）。
    final deniedAt = d.humanDeniedAtMs;
    if (deniedAt != null && deniedAt - respondedAt <= weakDenyWindow.inMilliseconds) {
      return null;
    }

    // ② 强口径：真人在回执后 24h 内主动确认（不晚于 now，防止未来时间戳作弊）。
    final confirmedAt = d.humanConfirmedAtMs;
    if (confirmedAt != null &&
        confirmedAt >= respondedAt &&
        confirmedAt <= now &&
        confirmedAt - respondedAt <= strongConfirmWindow.inMilliseconds) {
      return DelegationBasis.strong;
    }

    // ③ 弱口径：分身已回执，且窗口内无人否认。
    //    注：这是"暂定成立"——若 24h 内出现真人否认，回溯即作废（见 ①）。
    return DelegationBasis.weak;
  }
}
