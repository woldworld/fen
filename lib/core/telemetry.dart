import 'dart:convert';

/// 埋点骨架（PRD §7）。
///
/// 设计原则：
/// 1. **纯 Dart，零平台依赖** —— 可在 `flutter test` 中直接跑，不依赖 sqflite / 插件通道。
/// 2. **埋点永不阻断业务** —— track() 内部吞掉所有异常，绝不因埋点把主流程搞崩。
/// 3. **所有新功能必须走这里** —— 否则 W6 拿不到任何可判定数据（PRD §5.2 A 阶段出口条件）。
///
/// 方向约束同 app_events.dart：core 只产生事件，UI 负责展示；core 不 import UI。

/// 事件名常量（PRD §7.2 最小事件字典）。
///
/// ⚠️ 相对 PRD 的补充：`messageSentHuman` 在 §7.1 的握手定义里被依赖
/// （"24 小时内 ≥3 条由真人直接发出的消息"），但 §7.2 字典里**漏列了它**。
/// 没有这个事件，"每周真人握手数"这个北极星就无从计算，故在此补齐。
abstract final class TelemetryEvents {
  static const onboardingDone = 'onboarding_done';
  /// `did:wold` 身份签发（PRD §5.4 不可补录：审计从第一天连续）。
  static const didIssued = 'did_issued';
  static const inviteCreated = 'invite_created';
  static const inviteAccepted = 'invite_accepted';
  static const circleEntered = 'circle_entered';
  static const delegationSent = 'delegation_sent';
  static const delegationDone = 'delegation_done';
  /// 委托**实际投递到对方设备**（PRD M2「60 秒内收到」的可观测信号）。
  /// 与 delegation_sent（本机落库）区分：sent 成功不代表对方收到了。
  static const delegationDispatched = 'delegation_dispatched';
  /// 对方设备**收到**委托。带 `delivery_ms`（收到时刻 − 下达时刻），
  /// 这才是「60 秒内收到」这条验收口径能用的数。
  static const delegationReceived = 'delegation_received';
  /// 回执回传到发起方。
  static const delegationReceipt = 'delegation_receipt';
  /// 收到但对端签名校验失败 / 路由不对 —— 一律丢弃并留痕（fail-closed）。
  static const delegationDropped = 'delegation_dropped';
  static const intercardGenerated = 'intercard_generated';
  static const intercardApproved = 'intercard_approved';
  /// M3 互介卡的发送 / 到达 / 撤回 / 丢弃留痕。
  static const intercardSent = 'intercard_sent';
  static const intercardReceived = 'intercard_received';
  static const intercardRevoked = 'intercard_revoked';
  static const intercardDropped = 'intercard_dropped';
  static const humanPresenceMarked = 'human_presence_marked';
  static const messageSentHuman = 'message_sent_human';
  /// M4 首次自报身份（一次性披露）与在场信号收发 / 丢弃留痕。
  static const selfIntroSent = 'self_intro_sent';
  static const presenceJudged = 'presence_judged';
  static const presenceDispatched = 'presence_dispatched';
  static const presenceReceived = 'presence_received';
  static const presenceDropped = 'presence_dropped';
  static const handshake = 'handshake';
  static const disclosureVariant = 'disclosure_variant';
  /// **A3 实验**：摘要打开（`digest_opened`）与动作点击（`digest_action_clicked`）。
  /// props：variant（plain/action）、action_clicked。
  static const digestOpened = 'digest_opened';
  static const digestActionClicked = 'digest_action_clicked';
  static const reportFiled = 'report_filed';
  /// **M5 跨圈桥**：房间是跨圈边的唯一出处 —— 采集到的跨圈候选人、
  /// 建成的跨圈边、以及被四条铁律拦下的建边尝试（拦下也要留痕，
  /// 否则"没有假边"这句话没有证据）。
  static const bridgeCandidateSeen = 'bridge_candidate_seen';
  static const bridgeLinkCreated = 'bridge_link_created';
  static const bridgeLinkBlocked = 'bridge_link_blocked';
  /// **M8 试用额度代调**：额度发放 / 拒发 / 吊销、网关放行 / 拒绝、消费记账、
  /// 内容安全拦截。
  ///
  /// 为什么这几条必须存在：代调会让我们从"传话人"变成**内容生产者**
  /// （PRD §9.1：中/欧/美三法域责任落到我们头上）。所以每一次代调都要留痕 ——
  /// 它同时是**计费口径**与**合规审计口径**；没有埋点就等于"说不清花了多少、
  /// 也说不清做过什么"。
  /// `trial_gateway.dart` 的 `_emit` 用的就是这些常量值
  /// （`tool/verify_trial_gateway.dart` 有断言盯住两边不漂移）。
  static const trialQuotaGranted = 'trial_quota_granted';
  static const trialQuotaRefused = 'trial_quota_refused';
  static const trialQuotaRevoked = 'trial_quota_revoked';
  static const trialGatewayAllow = 'trial_gateway_allow';
  static const trialGatewayDeny = 'trial_gateway_deny';
  static const trialUsage = 'trial_usage';
  /// 内容安全拦截（入站注入 / 出站 PII）。
  static const trialSafetyBlocked = 'trial_safety_blocked';

  // ---- M6 网络级信誉（reputation_network.dart / ReputationNetworkEvents） ----
  // ⚠️ 字面量必须与 ReputationNetworkEvents 一一对应（名一漂移埋点就静默丢数据），
  //    verify_reputation_network 有断言盯着。
  static const reputationEndorseAccepted = 'reputation_endorse_accepted';
  static const reputationEndorseRejected = 'reputation_endorse_rejected';
  static const reputationEndorsementRevoked = 'reputation_endorsement_revoked';
  static const reputationQueryKnown = 'reputation_query_known';
  static const reputationQueryUnknown = 'reputation_query_unknown';

  // ---- M10 五件套（contribution_ledger.dart / ContributionEvents） ----
  // ⚠️ 字面量必须与 ContributionEvents 一一对应（名一漂移埋点就静默丢数据），
  //    verify_contribution_ledger 有断言盯着。
  static const contributionRecordAccepted = 'contribution_record_accepted';
  static const contributionRecordRejected = 'contribution_record_rejected';
  static const contributionFoundingDeclared = 'contribution_founding_declared';
  static const contributionPriceLockGranted = 'contribution_price_lock_granted';
  static const contributionScoreQueried = 'contribution_score_queried';
  static const contributionLogAppendFailed = 'contribution_log_append_failed';

  // ---- App → Hub 上行（hub_write_service.dart / hub_outbox.dart） ----
  //
  // ⚠️ 这五条是「上行到底有没有接通」这个问题的**唯一可判定证据**。
  //    在此之前，Hub 侧 5 个写端点只有测试脚本调用过，App 一次都没调过 ——
  //    即"本地记了账，但公开树上没有叶子"。此后看 `hub_push_accepted` 与
  //    `hub_push_enqueued` 的比值，就能知道公示通道是真通还是只是"以为通了"。
  /// Hub 收下了（或幂等重复）。props：endpoint / result。
  static const hubPushAccepted = 'hub_push_accepted';
  /// 暂时发不出去，已入队。props：endpoint / error / pending / dropped。
  static const hubPushEnqueued = 'hub_push_enqueued';
  /// **永久**拒绝：不入队，留痕。props：endpoint / error / http。
  static const hubPushRejected = 'hub_push_rejected';
  /// 队列里的条目重放成功。props：endpoint / attempts / lag_ms。
  static const hubPushFlushed = 'hub_push_flushed';
  /// 队列超容量，丢弃最旧的若干条。props：dropped / cap。
  static const hubOutboxTrimmed = 'hub_outbox_trimmed';
}

/// 一条埋点事件。
///
/// `self` / `peer` 是成对流事件的通用字段：握手、委托、互介都发生在两者之间。
/// 单机事件（如 onboarding_done）只填 `self`。
class TelemetryEvent {
  final String name;
  final int tsMs;
  final Map<String, Object?> props;

  const TelemetryEvent({
    required this.name,
    required this.tsMs,
    this.props = const {},
  });

  Map<String, Object?> toJson() => {
        'name': name,
        'ts': tsMs,
        'props': props,
      };

  factory TelemetryEvent.fromJson(Map<String, dynamic> j) => TelemetryEvent(
        name: j['name'] as String,
        tsMs: j['ts'] as int,
        props: Map<String, Object?>.from(j['props'] as Map? ?? {}),
      );

  @override
  String toString() => '$name@$tsMs ${props.isEmpty ? '' : props}';
}

/// 事件存储抽象。默认内存实现用于测试与"未接线"阶段；
/// 后续接 SQLite（迁移版本 20）或 SharedPreferences 时替换实现即可，业务代码不用改。
abstract class TelemetryStore {
  Future<void> append(TelemetryEvent e);
  Future<List<TelemetryEvent>> all();
  Future<void> clear();

  /// 保留最近 n 条（防止单机无限增长）。
  Future<void> trimTo(int n) async {
    final list = await all();
    if (list.length <= n) return;
    await clear();
    for (final e in list.skip(list.length - n)) {
      await append(e);
    }
  }
}

class MemoryTelemetryStore extends TelemetryStore {
  final List<TelemetryEvent> _buf = [];

  @override
  Future<void> append(TelemetryEvent e) async => _buf.add(e);

  @override
  Future<List<TelemetryEvent>> all() async => List.unmodifiable(_buf);

  @override
  Future<void> clear() async => _buf.clear();
}

class Telemetry {
  final TelemetryStore store;

  /// 超过此条数后自动裁剪，避免长期运行内存膨胀。
  static const int maxBufferedEvents = 5000;

  Telemetry(this.store);

  /// 全局实例。App 启动时用 `Telemetry.bind(store)` 接线；未接线时 track() 静默丢弃。
  static Telemetry? _instance;
  static Telemetry? get instance => _instance;

  static void bind(TelemetryStore store) => _instance = Telemetry(store);
  static void unbind() => _instance = null;

  // ------------------------------------------------------------------
  // 埋点旁路观察者
  // ------------------------------------------------------------------

  /// 想"旁听"业务事件、又不想让埋点反向依赖 UI 的模块挂在这里
  /// （当前唯一使用者：系统通知内核 `notification_service.dart`）。
  ///
  /// ★ 约束：在 [track] 主路径上**同步**调用 ⇒ 观察者必须极轻；
  ///   逐个 try/catch，一个观察者抛错绝不影响埋点本身。
  /// ★ 观察者表是**每个 isolate 各自一份**：Workmanager 心跳 isolate 里那份
  ///   主 isolate 看不见 ⇒ 心跳入口必须**在那个 isolate 内再装一次**旁听器
  ///   （见 `notification_service.dart` 的 `attachInBackgroundIsolate`，0.49.0）。
  static final List<void Function(String name, Map<String, Object?> props)>
      _observers = [];

  static void addObserver(
    void Function(String name, Map<String, Object?> props) observer,
  ) {
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  static void removeObserver(
    void Function(String name, Map<String, Object?> props) observer,
  ) {
    _observers.remove(observer);
  }

  static void _notifyObservers(String name, Map<String, Object?> props) {
    if (_observers.isEmpty) return;
    // 复制一份再遍历：观察者里 detach 自己不会导致并发修改
    for (final o in List.of(_observers)) {
      try {
        o(name, props);
      } catch (_) {
        // 旁路失败不得污染埋点
      }
    }
  }

  /// 记录一条事件。永不抛异常。
  void track(
    String name, {
    Map<String, Object?> props = const {},
    int? tsMs,
  }) {
    try {
      final e = TelemetryEvent(
        name: name,
        tsMs: tsMs ?? DateTime.now().millisecondsSinceEpoch,
        props: Map<String, Object?>.from(props),
      );
      // 埋点不得阻断主流程：失败静默丢弃
      store.append(e).catchError((_) => null);
      // 旁听者（通知等）在**落库之后**收到通知：先保住事实，再谈呈递。
      _notifyObservers(name, e.props);
      _pending++;
      if (_pending >= _trimCheckEvery) {
        _pending = 0;
        store.trimTo(maxBufferedEvents).catchError((_) => null);
      }
    } catch (_) {
      // 埋点失败不应影响业务
    }
  }

  int _pending = 0;
  static const int _trimCheckEvery = 200;

  Future<List<TelemetryEvent>> events() async {
    try {
      return await store.all();
    } catch (_) {
      return const [];
    }
  }

  /// 按事件名计数 —— 最小看板（PRD §7.3）的第一列来源。
  Future<Map<String, int>> countsByName() async {
    final out = <String, int>{};
    for (final e in await events()) {
      out[e.name] = (out[e.name] ?? 0) + 1;
    }
    return out;
  }

  /// 漏斗（PRD §7.3 一行）：下载 → onboarding → 入场进圈 → 委托完成 →
  /// 互介确认 → 握手。返回按顺序的计数，缺失为 0。
  Future<List<int>> funnel() async {
    final c = await countsByName();
    const steps = [
      TelemetryEvents.onboardingDone,
      TelemetryEvents.circleEntered,
      TelemetryEvents.delegationDone,
      TelemetryEvents.intercardApproved,
      TelemetryEvents.handshake,
    ];
    return steps.map((s) => c[s] ?? 0).toList();
  }

  /// 导出 JSON 行（供人工看板/离线分析）。
  Future<String> exportJsonLines() async {
    final list = await events();
    return list.map((e) => jsonEncode(e.toJson())).join('\n');
  }
}

/// PRD §7.1「真人握手」判定结果。
class HandshakeVerdict {
  final bool ok;

  /// 不通过的原因（可二值判定，便于定位数据问题）。
  final String reason;

  /// 24 小时窗口内统计到的真人消息条数。
  final int humanMessages;

  /// 命中的中介来源：alpha（委托）/ beta（互介）/ null。
  final String? mediationSource;

  const HandshakeVerdict({
    required this.ok,
    required this.reason,
    required this.humanMessages,
    this.mediationSource,
  });

  @override
  String toString() =>
      'HandshakeVerdict(ok=$ok, human=$humanMessages, via=$mediationSource, reason=$reason)';
}

/// PRD §7.1 的可执行判定：
///   同一对用户，24 小时内 ≥3 条真人直发消息，且 7 天内存在 α/β 中介事件。
///
/// 中介事件口径：α = delegation_done；β = intercard_approved。
class HandshakeJudge {
  static const Duration messageWindow = Duration(hours: 24);
  static const Duration mediationWindow = Duration(days: 7);
  static const int minHumanMessages = 3;

  /// [a] [b] 为一对用户的 ID；[events] 为候选事件全集；[nowMs] 为判定时刻。
  static HandshakeVerdict judge({
    required String a,
    required String b,
    required List<TelemetryEvent> events,
    required int nowMs,
  }) {
    bool involves(TelemetryEvent e) {
      final s = e.props['self'] as String?;
      final p = e.props['peer'] as String?;
      if (s == null || p == null) return false;
      return (s == a && p == b) || (s == b && p == a);
    }

    // 1) 24 小时内的真人直发消息
    final msgFrom = nowMs - messageWindow.inMilliseconds;
    final human = events.where((e) {
      if (e.name != TelemetryEvents.messageSentHuman) return false;
      if (e.tsMs < msgFrom || e.tsMs > nowMs) return false;
      return involves(e);
    }).length;

    if (human < minHumanMessages) {
      return HandshakeVerdict(
        ok: false,
        reason: 'human_messages_insufficient',
        humanMessages: human,
      );
    }

    // 2) 7 天内的中介事件
    final medFrom = nowMs - mediationWindow.inMilliseconds;
    String? source;
    for (final e in events) {
      if (e.tsMs < medFrom || e.tsMs > nowMs) continue;
      if (!involves(e)) continue;
      if (e.name == TelemetryEvents.delegationDone) {
        source ??= 'alpha';
      } else if (e.name == TelemetryEvents.intercardApproved) {
        source ??= 'beta';
      }
    }

    if (source == null) {
      return HandshakeVerdict(
        ok: false,
        reason: 'no_mediation_event',
        humanMessages: human,
      );
    }

    return HandshakeVerdict(
      ok: true,
      reason: 'ok',
      humanMessages: human,
      mediationSource: source,
    );
  }
}

/// TTFD（首次委托完成时间）统计（PRD §7.1 分阶段口径）。
///
/// B 阶段用**弱口径**（对方分身回执且 24h 内未否认），
/// D 阶段起切**强口径**（对方真人主动确认）。埋点同时记录两种信号，
/// 故这里只做"从 onboarding_done 到首个 delegation_done"的中位数计算，
/// 口径切换不影响历史数据可用性。
class Ttfd {
  /// 返回 [onboardingMs] 之后首个 delegation_done 的耗时（毫秒）；无则 null。
  static int? firstDelegationLatency({
    required String self,
    required List<TelemetryEvent> events,
  }) {
    int? onboarding;
    for (final e in events) {
      if (e.name == TelemetryEvents.onboardingDone &&
          e.props['self'] == self &&
          (onboarding == null || e.tsMs < onboarding)) {
        onboarding = e.tsMs;
      }
    }
    if (onboarding == null) return null;

    int? done;
    for (final e in events) {
      if (e.name != TelemetryEvents.delegationDone) continue;
      if (e.props['self'] != self) continue;
      if (e.tsMs < onboarding) continue;
      if (done == null || e.tsMs < done) done = e.tsMs;
    }
    if (done == null) return null;
    return done - onboarding;
  }

  /// 中位数（输入为空返回 null）。
  static int? median(List<int> values) {
    if (values.isEmpty) return null;
    final s = List<int>.from(values)..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : ((s[mid - 1] + s[mid]) ~/ 2);
  }
}
