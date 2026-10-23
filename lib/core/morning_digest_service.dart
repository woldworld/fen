/// 晨间问候 + 三日回顾（P0 主交付）。
///
/// ---------------------------------------------------------------------------
/// 职责
/// ---------------------------------------------------------------------------
/// 每天清晨（Workmanager 周期任务在"已到清晨且今日未问候"时）主动给用户一份
/// 温暖回顾：活动（委托/圈子/跑腿，复用 [DigestService]）+ 与主智能体的对话统计
/// （[ChatStatsSource]，离线聚合、隐私不出本机）。
///
/// ---------------------------------------------------------------------------
/// 设计边界（沿用既有纪律）
/// ---------------------------------------------------------------------------
/// * **触发靠 Workmanager 周期 + 本地补发**：不申请精确闹钟权限（SCHEDULE_EXACT_ALARM），
///   与 `notification_service.dart` "只立即呈现、不调度" 的纪律一致。清晨准时无法硬保
///   （Workmanager 周期下限 15 分钟、系统可能延迟），靠"今日已问候"去重保证每天至少一次。
/// * **LLM 润色可选、且只走用户自备 Key**：润色调用 [AgentService.completePlain]
///   （设备直连、不经 Hub，符合 R6/R10）。试用 / 无 Key / 任何失败 ⇒ 降级模板。
/// * **每日去重 + 免打扰 + 总开关**：去重键 `morning_greeted_date`；闸门复用
///   [NotificationPolicy.shouldNotify]（与既有通知同一套判定）。
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'agent_report_source.dart';
import 'agent_service.dart';
import 'calendar_service.dart';
import 'chat_stats_source.dart';
import 'digest_service.dart';
import 'l10n_holder.dart';
import 'notification_service.dart';
import 'reminder_service.dart';
import 'user_profile_store.dart';
import 'wold_runtime.dart';

/// 一次晨间回顾的完整产出。
class MorningBriefing {
  final String greeting; // 进 App 后看到的问候（卡片/摘要页顶部）
  final String notificationTitle;
  final String notificationBody;
  final List<String> highlights; // 结构化要点（调试 / 后续卡片用）
  final bool llmPolished; // 问候是否经 LLM 润色

  const MorningBriefing({
    required this.greeting,
    required this.notificationTitle,
    required this.notificationBody,
    this.highlights = const [],
    this.llmPolished = false,
  });
}

class MorningDigestService {
  MorningDigestService._();
  static final MorningDigestService i = MorningDigestService._();

  static const String _greetedKey = 'morning_greeted_date';

  /// 晨间问候时间的 prefs 键与默认值 —— **公开**，因为设置页是它**唯一的写入方**
  /// （0.68.0 修：此前只有 `_shouldEmit` 读它、全项目**无人写** ⇒
  ///  `tool/verify_data_keys.dart` 判为「读了没人写」，该设置永远等于默认值、
  ///  用户改不了也不知道自己改不了 —— 典型的静默失效）。
  static const String morningHourKey = 'morning_hour';
  static const int defaultMorningHour = 7;

  /// 设置晨间问候时间（**唯一写入方** = 设置页）。
  Future<void> setMorningHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(morningHourKey, hour);
  }

  String _todayKey() {
    final t = DateTime.now();
    return '${t.year}-${t.month}-${t.day}';
  }

  /// 是否应当发出：今日已问候 ⇒ 否；通知关 / 免打扰窗口内 ⇒ 否；未到清晨小时 ⇒ 否。
  Future<bool> _shouldEmit() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_greetedKey) ?? '') == _todayKey()) return false;

    final settings = NotificationService.i.settings;
    final hour = DateTime.now().hour;
    if (!NotificationPolicy.shouldNotify(settings: settings, hour: hour)) {
      return false;
    }
    final morningHour = prefs.getInt(morningHourKey) ?? defaultMorningHour;
    if (hour < morningHour) return false;
    return true;
  }

  /// 构建回顾（模板，零成本）。[report] 已是 72h 窗口。
  ///
  /// [profile] 是 P1 的**长期画像**（可空）：给了就在要点里补一条"长期关注"，
  /// 让清晨问候既说"最近三天"也说"你一直关心的事"。
  /// 留空 = 只有三日回顾（老行为不变，便于单测只喂 report）。
  ///
  /// [L10nHolder.l10n] 永远非空，且 5 语种 ARB 均已含本页 16 键，故无需 `??` 兜底。
  ///
  /// [reminders] 是 W1（0.70.0）的**今日提醒/待办**（可空）：给了就在要点里
  /// 补一条，让清晨问候顺带回答"今天有什么要办的"。空列表 = 不出现该要点。
  /// [todayEvents] 是 W5（0.74.0）的**今天日程**（可空/可空表）：系统日历只读，
  /// 未授权 ⇒ 空表 ⇒ 不出现该要点。
  ///
  /// [weekStats] 是 W5（0.74.0）的**周报统计**（可空）：仅周日由 [compose] 传入，
  /// 非周日为 null ⇒ 不出现该要点（保持"周日版附加一段"的节奏）。
  Future<MorningBriefing> build(DigestReport report,
      {UserProfile? profile,
      List<Reminder> reminders = const [],
      List<CalendarEvent> todayEvents = const [],
      AgentActionStats? weekStats}) async {
    final l10n = L10nHolder.l10n;
    final hour = DateTime.now().hour;
    final timeWord = hour < 11
        ? l10n.morningGreetingMorning
        : (hour < 18
            ? l10n.morningGreetingNoon
            : l10n.morningGreetingEvening);

    final highlights = <String>[];
    final pending = report.of(DigestFact.kindPendingInbox);
    final sent = report.of(DigestFact.kindSentNew) +
        report.of(DigestFact.kindSentAnswered) +
        report.of(DigestFact.kindSentDeclined) +
        report.of(DigestFact.kindSentRevoked);
    final circles = report.of(DigestFact.kindCircleJoined);
    final chat = report.of(DigestFact.kindChatSummary);

    if (pending.isNotEmpty) {
      highlights.add(l10n.morningHiPending(pending.length));
    }
    if (sent.isNotEmpty) {
      highlights.add(l10n.morningHiSent(sent.length));
    }
    if (circles.isNotEmpty) {
      highlights.add(l10n.morningHiCircle(circles.length));
    }
    if (chat.isNotEmpty) {
      final c = chat.first.data;
      final sessions = (c['sessions'] as int?) ?? 0;
      final turns = (c['turns'] as int?) ?? 0;
      final days = (c['days'] as int?) ?? 0;
      final topics = (c['topics'] as List?)?.cast<String>() ?? const <String>[];
      highlights.add(l10n.digestChatSummary(sessions, turns, days));
      if (topics.isNotEmpty) {
        highlights.add(l10n.morningHiTopics(topics.take(3).join('、')));
      }
    }
    // P1：长期画像（"你一直关心的事"）—— 与"最近三天"并排，但不覆盖它。
    if (profile != null && profile.topics.isNotEmpty) {
      final longTerm = profile.topics.take(3).map((e) => e.name).join('、');
      highlights.add(l10n.morningHiLongTerm(longTerm));
    }

    // W1（0.70.0）：今日提醒/待办 —— 24h 内到期（含已到期未提醒的）+ 全部
    // 未完成待办。主人早上醒来第一句"今天干嘛"，这里是答案的一半。
    if (reminders.isNotEmpty) {
      highlights.add(l10n.morningHiReminders(reminders.length));
    }

    // W5（0.74.0）：今天日程 —— 系统日历只读（未授权/无日程 ⇒ 空表 ⇒ 不出现）。
    // 回答主人早上醒来第二句"今天要去哪"。
    if (todayEvents.isNotEmpty) {
      final head = todayEvents
          .take(3)
          .map((e) => e.allDay
              ? '${l10n.calendarAllDay} ${e.title}'
              : '${_hhmm(e.beginMs)} ${e.title}')
          .join(l10n.permListSeparator);
      highlights.add(l10n.morningHiCalendar(head));
    }

    // W5（0.74.0）：周报 —— 仅周日附加（非周日 weekStats 为 null）。
    if (weekStats != null && !weekStats.isEmpty) {
      highlights.add(l10n.morningHiWeekly(weekStats.total));
    }

    final joined = highlights.isEmpty
        ? l10n.morningEmpty
        : highlights.join('；');
    final greeting = '$timeWord。${l10n.morningGreetingBody}$joined';

    final title = l10n.notifyMorningTitle;
    final body = pending.isNotEmpty
        ? l10n.notifyMorningBodyPending(pending.length)
        : l10n.notifyMorningBody;

    return MorningBriefing(
      greeting: greeting,
      notificationTitle: title,
      notificationBody: body,
      highlights: highlights,
    );
  }

  /// 生成 LLM 润色后的问候（自备 Key 才调用；失败/空 ⇒ 返回 null）。
  Future<String?> _polish(String factsText) async {
    final svc = AgentService();
    if (!await svc.hasOwnApiKey()) return null;
    final localeName = L10nHolder.l10n.localeName;
    final langName = const {
      'zh': '中文',
      'zh_Hant': '繁體中文',
      'en': 'English',
      'ja': '日本語',
      'vi': 'Tiếng Việt',
    }[localeName] ?? '中文';
    final system = '你是用户的本地分身。用 $langName 写一段亲切的清晨问候，'
        '结合下面最近三天的活动事实做简要回顾。要求：语气温暖自然、不超过 80 字、'
        '不要使用 emoji、不要编造事实、不要调用任何工具。';
    final out = await svc
        .completePlain(system, '最近三天的活动事实：\n$factsText')
        .timeout(const Duration(seconds: 30));
    return out.isNotEmpty ? out : null;
  }

  /// 组装并（按需）润色，返回最终问候文本。
  Future<MorningBriefing> compose() async {
    final rt = WoldRuntime.i;
    final me = await rt.myAgentId();
    final report = await rt.digest.build(selfId: me, hours: 72);

    // P1「沉淀」：每日回顾时强制重算一次长期画像，让画像跟着主人近况走。
    // 画像是**派生值**（对 append-only 事件流的聚合），不落库 ⇒ 这一下只是
    // 刷新进程内缓存；失败返回空画像，下面的 build 会自动略过"长期关注"要点。
    //
    // ★ 0.69.0：晨间卡片那条「长期关注」也受 `profile_enabled` 约束 ——
    //   主人关掉画像时的真实意图是「别再拿我的画像说事」，而不仅仅是
    //   「别注入给模型」。只挡注入、晨间照旧弹出来 ⇒ 主人会看到"我明明关了
    //   却还在" ⇒ 属于**静默不符预期**（比不做开关更伤信任）。
    //   顺带的收益：关掉后连每日这次聚合都不跑了（省一次扫表）；开回来，
    //   下一次晨间（或进程内 30 分钟 TTL 到期）自动补算。
    final prefs = await SharedPreferences.getInstance();
    final profileEnabled = prefs.getBool('profile_enabled') != false;
    final profile = profileEnabled ? await UserProfileStore.i.refresh() : null;

    // W1：今日提醒/待办（失败不影响问候本身——增强不是主流程）。
    List<Reminder> reminders = const [];
    try {
      reminders = await ReminderService.i.dueSoon();
    } catch (_) {}

    // W5/S6：今天日程（只读系统日历）。未授权 / 不支持 ⇒ 空表 ⇒ 不出现要点。
    List<CalendarEvent> todayEvents = const [];
    try {
      final st = await CalendarService.i.status();
      if (st.supported && st.granted) {
        todayEvents = await CalendarService.i.todayEvents();
      }
    } catch (_) {}

    // W5/S7：周报 —— **仅周日**附加（周一到周六不打扰，保持"周日版"节奏）。
    AgentActionStats? weekStats;
    if (DateTime.now().weekday == DateTime.sunday) {
      try {
        final weekAgo = DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch;
        weekStats = await SqliteAgentReportSource().aggregateSince(weekAgo);
      } catch (_) {}
    }

    final base = await build(report,
        profile: profile,
        reminders: reminders,
        todayEvents: todayEvents,
        weekStats: weekStats);

    // 结构化事实文本（给 LLM 润色用，不含正文）。
    final facts = base.highlights.isEmpty
        ? '（最近三天没有新活动）'
        : base.highlights.join('；');
    final polished = await _polish(facts);

    if (polished != null && polished.isNotEmpty) {
      return MorningBriefing(
        greeting: polished,
        notificationTitle: base.notificationTitle,
        notificationBody: base.notificationBody,
        highlights: base.highlights,
        llmPolished: true,
      );
    }
    return base;
  }

  /// 入口：检查闸门 → 生成 → 弹通知 → 写回"今日已问候"。
  /// 任何一步失败都**静默降级**（绝不让晨间问候拖垮心跳/启动）。
  Future<bool> maybeEmit() async {
    try {
      if (!await _shouldEmit()) return false;
      final b = await compose();
      await NotificationService.i.notifyMorning(
        title: b.notificationTitle,
        body: b.notificationBody,
        dedupKey: 'morning-${_todayKey()}',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_greetedKey, _todayKey());
      return true;
    } catch (e) {
      // 晨间问候失败不应影响主流程（心跳等）。
      return false;
    }
  }
}

/// 时间戳 → `HH:mm`（纯数字，无本地化依赖；日程时间在 5 语种下同形）。
String _hhmm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
