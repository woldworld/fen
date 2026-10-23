/// 每日摘要（带动作）—— PRD §5.2 B 阶段交付物 / §10.3"个人分身"缺口。
///
/// 双重身份：
/// 1. **"每日一次存在感"的最小实现**（保护测量，非功能）：
///    α 的委托完成率受"结对对象不在线"影响，摘要让主人每天至少被提醒一次。
/// 2. **A3 实验**（PRD §7.2 `digest_opened`）：纯摘要 vs 带动作，
///    量"打开与否、是否点击动作"。
///
/// 设计边界：
/// - **摘要由结构化事实拼装，不经大模型**——可靠、零成本、可离线；
///   LLM 润色是以后的可选项，不是前提。
/// - 本文件**零平台依赖**（store 全部注入），`dart run tool/verify_digest.dart` 可验证。
/// - 动作只是"跳转到已有页面"的意图（[DigestAction.kind]），不做新操作——
///   摘要绝不代客执行。

library;

import 'delegation_service.dart';
import 'chat_stats_source.dart';

/// 摘要里的一条事实。
class DigestFact {
  static const kindPendingInbox = 'delegation_pending'; // 托我的，待回执
  static const kindSentNew = 'delegation_sent_new'; // 我新下达的
  static const kindSentAnswered = 'delegation_answered'; // 我托的，已回执
  static const kindSentDeclined = 'delegation_declined'; // 我托的，被拒
  static const kindSentRevoked = 'delegation_revoked'; // 我撤销的
  static const kindCircleJoined = 'circle_joined'; // 新加入的圈
  static const kindErrandDone = 'errand_done'; // 统计：完成的委托数
  static const kindHandshake = 'handshake'; // 统计：真人握手数
  static const kindChatSummary =
      'chat_summary'; // 近窗口内与主智能体的对话统计（来自 session_events）

  final String kind;
  final Map<String, Object?> data;

  const DigestFact(this.kind, this.data);
}

/// 摘要给出的动作（跳转意图，不是操作）。
///
/// ⚠️ **只承载语言中立的 `kind`**。曾有一个 `label` 字段存中文（'去回执' / '看看板'…），
/// 但**全项目没有任何地方读它** —— UI 侧 `digest_screen` 早就是按 `kind` 查 ARB
/// （`l10n.digestActionOpenInbox` 等）。所以它不是"待翻译的文案"，而是**死字段**：
/// 留着的唯一后果是每次审计都被当成"还有硬编码中文"。**已删除。**
class DigestAction {
  static const kindOpenInbox = 'open_inbox'; // 去回执
  static const kindOpenOutbox = 'open_outbox'; // 看进度/撤销
  static const kindOpenCircle = 'open_circle'; // 看圈子
  static const kindOpenDashboard = 'open_dashboard'; // 看看板

  final String kind;

  const DigestAction(this.kind);
}

/// A3 实验分桶：按 selfId **确定性**分桶（同 Phase −1 的 arm_for_id 思路），
/// 重开 App / 重算摘要都不会换组。
class DigestVariant {
  static const plain = 'plain'; // 纯摘要：不显示动作按钮
  static const withActions = 'action'; // 带动作

  /// FNV-1a 哈希取偶 → 50/50。
  static String forId(String selfId) {
    var h = 0x811c9dc5;
    for (final c in selfId.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.isEven ? withActions : plain;
  }
}

/// 一次摘要的完整产出。
class DigestReport {
  final String selfId;
  final String variant; // DigestVariant
  final int sinceMs;
  final int untilMs;
  final List<DigestFact> facts;

  const DigestReport({
    required this.selfId,
    required this.variant,
    required this.sinceMs,
    required this.untilMs,
    required this.facts,
  });

  bool get isEmpty => facts.isEmpty;

  List<DigestFact> of(String kind) =>
      facts.where((f) => f.kind == kind).toList();

  /// 该报告应给出的动作集合（去重，按优先级排序）。
  /// 纯摘要组（variant=plain）返回空 —— 这正是 A3 实验的自变量。
  /// **只给 kind**，显示文案由 UI 按 kind 查 ARB（见 [DigestAction] 的注释）。
  List<DigestAction> get actions {
    if (variant != DigestVariant.withActions) return const [];
    final out = <DigestAction>[];
    void add(String kind) {
      if (out.any((a) => a.kind == kind)) return;
      out.add(DigestAction(kind));
    }

    if (of(DigestFact.kindPendingInbox).isNotEmpty) {
      add(DigestAction.kindOpenInbox);
    }
    if (of(DigestFact.kindSentNew).isNotEmpty ||
        of(DigestFact.kindSentAnswered).isNotEmpty ||
        of(DigestFact.kindSentDeclined).isNotEmpty ||
        of(DigestFact.kindSentRevoked).isNotEmpty) {
      add(DigestAction.kindOpenOutbox);
    }
    if (of(DigestFact.kindCircleJoined).isNotEmpty) {
      add(DigestAction.kindOpenCircle);
    }
    if (of(DigestFact.kindErrandDone).isNotEmpty ||
        of(DigestFact.kindHandshake).isNotEmpty) {
      add(DigestAction.kindOpenDashboard);
    }
    return out;
  }
}

/// 摘要依赖的只读视图（全部注入，保持零平台依赖）。
class DigestSources {
  /// 委托存储（用既有 [DelegationStore] 抽象，与业务同一套）。
  final DelegationStore delegationStore;

  /// 我在 [sinceMs] 之后新加入的圈（circle_id / name / joined_at）。
  final Future<List<Map<String, dynamic>>> Function(String selfId, int sinceMs)?
      recentJoins;

  /// 埋点事件（统计委托完成数 / 握手数）。
  final Future<List<Map<String, Object?>>> Function()? events;

  /// 对话历史统计（近窗口内与主智能体的会话数 / 轮数 / 主题）。
  /// [SqliteChatStatsSource] 走本地 `session_events`，隐私不出本机；注入式便于测试。
  final ChatStatsSource? chatStats;

  const DigestSources({
    required this.delegationStore,
    this.recentJoins,
    this.events,
    this.chatStats,
  });
}

class DigestService {
  final DigestSources sources;

  DigestService({required this.sources});

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// 构建过去 [hours] 小时（默认 24）的摘要。
  Future<DigestReport> build({
    required String selfId,
    int hours = 24,
    int? untilMs,
  }) async {
    final until = untilMs ?? _now();
    final since = until - Duration(hours: hours).inMilliseconds;
    final facts = <DigestFact>[];

    // ---- 委托（含"托我的 pending"，这是唯一带紧迫感的部分）
    final delegations = await sources.delegationStore.forPeer(selfId);
    for (final d in delegations) {
      if (d.toId == selfId && d.state == DelegationState.pending) {
        facts.add(DigestFact(DigestFact.kindPendingInbox,
            {'id': d.id, 'from': d.fromId, 'task': d.task}));
        continue;
      }
      if (d.fromId != selfId) continue; // 只摘要"我托的"这半边
      if (d.createdAtMs < since) {
        // 窗口外下达的委托：只有"窗口内状态变化"的才值得报
        if (d.respondedAtMs == null || d.respondedAtMs! < since) continue;
      }
      switch (d.state) {
        case DelegationState.pending:
          facts.add(DigestFact(DigestFact.kindSentNew,
              {'id': d.id, 'to': d.toId, 'task': d.task}));
        case DelegationState.answered:
          facts.add(DigestFact(DigestFact.kindSentAnswered, {
            'id': d.id,
            'to': d.toId,
            'task': d.task,
            'response': d.response,
          }));
        case DelegationState.declined:
          facts.add(DigestFact(DigestFact.kindSentDeclined,
              {'id': d.id, 'to': d.toId, 'task': d.task}));
        case DelegationState.revoked:
          facts.add(DigestFact(DigestFact.kindSentRevoked,
              {'id': d.id, 'to': d.toId, 'task': d.task}));
        default:
          break;
      }
    }

    // ---- 新加入的圈
    final joins = await sources.recentJoins?.call(selfId, since) ?? const [];
    for (final j in joins) {
      facts.add(DigestFact(DigestFact.kindCircleJoined, {
        'circle_id': j['circle_id'],
        'name': j['name'],
        'joined_at': j['joined_at'],
      }));
    }

    // ---- 统计（来自埋点，一宗算一条事实）
    final events = await sources.events?.call() ?? const [];
    var doneCount = 0;
    var hsCount = 0;
    for (final e in events) {
      final name = e['name'] as String?;
      final ts = (e['ts'] as num?)?.toInt() ?? 0;
      if (ts < since || ts > until) continue;
      if (name == 'delegation_done' && e['self'] == selfId) doneCount++;
      if (name == 'handshake' &&
          (e['self'] == selfId || e['peer'] == selfId)) {
        hsCount++;
      }
    }
    for (var i = 0; i < doneCount; i++) {
      facts.add(const DigestFact(DigestFact.kindErrandDone, {}));
    }
    for (var i = 0; i < hsCount; i++) {
      facts.add(const DigestFact(DigestFact.kindHandshake, {}));
    }

    // ---- 近窗口内与主智能体的对话统计（离线聚合，不送模型）
    final chat = await sources.chatStats?.aggregateSince(since);
    if (chat != null && !chat.isEmpty) {
      facts.add(DigestFact(DigestFact.kindChatSummary, {
        'sessions': chat.sessions,
        'turns': chat.turns,
        'days': chat.activeDays,
        'last': chat.lastTurnMs,
        'topics': chat.topTopics,
      }));
    }

    return DigestReport(
      selfId: selfId,
      variant: DigestVariant.forId(selfId),
      sinceMs: since,
      untilMs: until,
      facts: facts,
    );
  }
}
