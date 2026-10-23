/// 系统通知（System Notifications）—— 「有人在等你」的唯一可见出口。
///
/// ---------------------------------------------------------------------------
/// 为什么要它（缺口来源）
/// ---------------------------------------------------------------------------
/// 在这之前，本项目**只有值班前台服务那一张常驻通知**。任何"事件到达"都只落在
/// App 内部：委托到了、会客厅有人 @你、分身起草了一条等你批准的建议卡——用户
/// 一退到桌面就再也看不见，只能靠"自己想起来打开 App"。分身越自主这个缺口越
/// 致命：**自主性必须配一条召回通道**。
///
/// ---------------------------------------------------------------------------
/// 设计边界（三条）
/// ---------------------------------------------------------------------------
/// 1. **通知是"旁听者"，不是新的事实源**：所有触发都挂在既有事件上
///    （`AppEvents` 总线 / `Telemetry` 旁路 / `agent_actions` 写入点），不新增
///    任何业务状态机；通知发失败绝不影响主流程（全程 try/catch）。
/// 2. **判断逻辑全是纯函数**（[NotificationPolicy]）：免打扰窗口、总开关、
///    @我 命中——都能在 `dart test` 里钉死。"通知长什么样"只能真机人工看，但
///    "该不该发"是确定性的、必须被机器验证。
/// 3. **只立即呈现、不调度**：用 `show()` 而非 `zonedSchedule`
///    ⇒ 不申请精确闹钟权限（SCHEDULE_EXACT_ALARM），少一份敏感权限申报。
///
/// ---------------------------------------------------------------------------
/// 已知边界（诚实登记，不假装覆盖）
/// ---------------------------------------------------------------------------
/// * **后台 isolate 已接线（0.49.0），但"是否真弹出"仍属真机未验**：值班心跳跑在
///   Workmanager 的独立 isolate，那里的事件总线（`AppEvents`）与观察者表
///   （`Telemetry`）都是**该 isolate 自己的一份** —— 主 isolate 挂的旁听器根本
///   看不见。所以心跳入口会调 [NotificationService.attachInBackgroundIsolate]，
///   在**那个 isolate 里**再装一套（与主 isolate 同一份实现，只是换个调用点）。
///   ★ 平台通道在后台 isolate 可用，有旁证：心跳体本来就在用 `SharedPreferences`
///   与 `permission_handler`（`BackgroundWorker.kt` 建独立 `FlutterEngine`，
///   其构造默认注册插件）。
///   ⚠️ 本机无设备 ⇒ **"后台到底弹没弹出来"无法自动验证**，仍需真机确认。
/// * **系统托盘是否真的画出来**，只能真机确认（本环境无法验证渲染结果）。
/// * **通知渠道名在首次创建时固化**：本 App 跟随系统语言，渠道名按系统语言
///   建一次即可，切换语言不会重建（Android 渠道语义使然）。
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_events.dart';
import 'app_logger.dart';
import 'background_duty_service.dart';
import 'db_helper.dart';
import 'l10n_holder.dart';
import 'telemetry.dart';

// ---------------------------------------------------------------------------
// 通知分类（决定文案与"值不值得打扰"）
// ---------------------------------------------------------------------------

enum NotifyKind {
  /// 分身起草了一条发言，等主人放行（最该打扰的一类：分身被卡住了）。
  suggestion,

  /// 受托：别人把一件事托付给你。
  delegation,

  /// 互介卡到达。
  intercard,

  /// 会客厅里有人点名 @你（房间消息里唯一值得打扰的一类）。
  loungeMention,

  /// 私聊消息到达。
  directMessage,

  /// 晨间问候 / 三日回顾（Workmanager 周期任务在"已到清晨且今日未问候"时触发）。
  morningDigest,

  /// 提醒到期（0.70.0）：主人自己定的时刻到了。
  reminder,
}

// ---------------------------------------------------------------------------
// 设置（值的唯一出处）
// ---------------------------------------------------------------------------

/// 通知偏好的存储键。设置页与内核**共用**这一份，避免键名各写一遍。
abstract final class NotificationKeys {
  static const String enabled = 'notify_enabled';
  static const String quietEnabled = 'notify_quiet_enabled';
  static const String quietStartHour = 'notify_quiet_start_hour';
  static const String quietEndHour = 'notify_quiet_end_hour';
}

/// 通知偏好的**不可变快照**。纯数据，便于喂给 [NotificationPolicy] 做单测。
class NotificationSettings {
  /// 总开关：关掉 = 一条通知都不弹（含建议卡）。
  final bool enabled;

  /// 免打扰开关：开启后，落在夜间窗口内的通知一律不弹。
  final bool quietEnabled;

  /// 免打扰起始小时（0–23，含）。
  final int quietStartHour;

  /// 免打扰结束小时（0–23，不含）。
  final int quietEndHour;

  const NotificationSettings({
    required this.enabled,
    required this.quietEnabled,
    required this.quietStartHour,
    required this.quietEndHour,
  });

  /// 出厂默认：开通知、开免打扰、22:00–07:00。
  ///
  /// 默认开免打扰是刻意的：分身是**后台常驻**的，若默认半夜弹通知，
  /// 用户第一反应是卸载而不是去设置里关——先静音，再让用户自己放宽。
  static const NotificationSettings defaults = NotificationSettings(
    enabled: true,
    quietEnabled: true,
    quietStartHour: 22,
    quietEndHour: 7,
  );

  static Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      enabled: prefs.getBool(NotificationKeys.enabled) ?? defaults.enabled,
      quietEnabled:
          prefs.getBool(NotificationKeys.quietEnabled) ?? defaults.quietEnabled,
      quietStartHour: _clampHour(
        prefs.getInt(NotificationKeys.quietStartHour),
        defaults.quietStartHour,
      ),
      quietEndHour: _clampHour(
        prefs.getInt(NotificationKeys.quietEndHour),
        defaults.quietEndHour,
      ),
    );
  }

  /// 落库值可能被外力写坏（手改 prefs / 老版本残留）⇒ 一律夹到 0–23。
  static int _clampHour(int? raw, int fallback) {
    if (raw == null) return fallback;
    if (raw < 0) return 0;
    if (raw > 23) return 23;
    return raw;
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? quietEnabled,
    int? quietStartHour,
    int? quietEndHour,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        quietEnabled: quietEnabled ?? this.quietEnabled,
        quietStartHour: quietStartHour ?? this.quietStartHour,
        quietEndHour: quietEndHour ?? this.quietEndHour,
      );
}

// ---------------------------------------------------------------------------
// 纯策略：该不该发 + 这条是不是在叫我
// ---------------------------------------------------------------------------

/// **纯函数**集合——没有 IO、没有全局态，故可被 `dart test` 完全覆盖。
///
/// 有意把"决策"从"呈现"里剥出来：真机上通知能不能画出来只能人工看，
/// 但**"该不该画"必须是确定性的**，这部分由单测钉住。
abstract final class NotificationPolicy {
  /// 是否落在免打扰窗口内。
  ///
  /// [startHour] == [endHour] 视为**空窗口**（永不静音）——否则会退化成
  /// "全天静音"，那是用户没表达过的意思。
  /// 支持跨零点（如 22 → 7）。
  static bool inQuietHours({
    required int hour,
    required int startHour,
    required int endHour,
  }) {
    if (startHour == endHour) return false;
    if (startHour < endHour) return hour >= startHour && hour < endHour;
    // 跨零点：窗口是 [start, 24) ∪ [0, end)
    return hour >= startHour || hour < endHour;
  }

  /// 综合闸门：总开关关 ⇒ 不发；免打扰开着且当前落窗口内 ⇒ 不发。
  static bool shouldNotify({
    required NotificationSettings settings,
    required int hour,
  }) {
    if (!settings.enabled) return false;
    if (!settings.quietEnabled) return true;
    return !inQuietHours(
      hour: hour,
      startHour: settings.quietStartHour,
      endHour: settings.quietEndHour,
    );
  }

  /// 这条会客厅消息是不是在叫我。
  ///
  /// 命中条件（任一）：
  ///   * 出现 `@我的分身ID`（大小写不敏感）；
  ///   * 出现 `@我的昵称`（大小写不敏感）；
  ///   * 出现广播式呼叫 `@all` / `@everyone` / `@全体` / `@所有人`。
  ///
  /// ★ 取舍：中文没有词边界，`@老王` 会命中 `@老王二`。这里**刻意宁可多叫一次**
  ///   也不漏叫——漏掉的代价是"用户永远不知道有人找他"，误报的代价只是多看一眼。
  static bool mentionsMe(
    String text, {
    required String myAgentId,
    required String myNickname,
  }) {
    if (text.isEmpty) return false;
    final hay = text.toLowerCase();
    final id = myAgentId.trim().toLowerCase();
    if (id.isNotEmpty && hay.contains('@$id')) return true;
    final nick = myNickname.trim().toLowerCase();
    if (nick.isNotEmpty && hay.contains('@$nick')) return true;
    for (final b in _broadcastMentions) {
      if (hay.contains(b)) return true;
    }
    return false;
  }

  static const List<String> _broadcastMentions = [
    '@all',
    '@everyone',
    '@全体',
    '@所有人',
  ];
}

// ---------------------------------------------------------------------------
// 呈现层（生产走插件；测试注入假实现）
// ---------------------------------------------------------------------------

/// 一条待呈现的通知。
class NotificationRequest {
  final int id;
  final String title;
  final String body;

  const NotificationRequest({
    required this.id,
    required this.title,
    required this.body,
  });

  @override
  String toString() => 'NotificationRequest($id, $title, $body)';
}

/// 通知的最终呈现方式。抽成函数类型是为了让"发了什么"可被断言。
typedef NotifyPresenter = Future<void> Function(NotificationRequest request);

// ---------------------------------------------------------------------------
// 服务
// ---------------------------------------------------------------------------

/// 通知内核（单例）。
///
/// 生命周期：`main()` 里 `await init()` → `attach()`；此后全程被动旁听。
class NotificationService {
  NotificationService._();

  static final NotificationService i = NotificationService._();

  /// Android 通知渠道（Android 8+ 不建渠道 = 通知被系统静默丢弃）。
  static const String channelId = 'wold_events';

  /// 去重窗口容量：委托/消息可能被重复投递（近场+局域网+云端三通道），
  /// 同一 `sourceMsgId` 只该弹一次。
  static const int _recentCapacity = 64;

  NotifyPresenter? _presenter;
  bool _attached = false;
  bool _plain = false; // 已尝试过初始化但失败（避免每次刷新都重试插件）
  StreamSubscription<AppCommand>? _busSub;
  void Function(String name, Map<String, Object?> props)? _telemetryObserver;

  NotificationSettings _settings = NotificationSettings.defaults;

  /// 本机身份缓存（@我 判定要用；在 [init] 时取一次，避免每条消息都查库）。
  String _selfAgentId = '';
  String _selfNickname = '';

  /// 可见于设置页与测试。
  NotificationSettings get settings => _settings;

  /// 可注入时钟（免打扰判定的时间源，测试里固定住）。
  DateTime Function() clock = DateTime.now;

  final LinkedHashSet<String> _recent = LinkedHashSet<String>();

  bool get isAttached => _attached;

  /// 初始化：读偏好 + 建插件通道 + 缓存本机身份。
  ///
  /// 传 [presenter] 则跳过插件（测试路径）。任何一步失败都降级为"不弹通知"，
  /// **绝不让通知拖垮启动**。
  Future<void> init({NotifyPresenter? presenter}) async {
    await refreshSettings();
    await _loadSelfIdentity();
    if (presenter != null) {
      _presenter = presenter;
      return;
    }
    _presenter = await _buildPluginPresenter();
  }

  /// 重新读取偏好（设置页保存后调用，让内核立刻生效）。
  Future<void> refreshSettings() async {
    try {
      _settings = await NotificationSettings.load();
    } catch (e) {
      AppLogger.w('notify.settings', e);
      _settings = NotificationSettings.defaults;
    }
  }

  /// 开始旁听事件源。**幂等**：重复调用不会装多个监听器。
  void attach() {
    if (_attached) return;
    _attached = true;
    try {
      _busSub = AppEvents.stream.listen(
        (cmd) => unawaited(_onCommand(cmd)),
        onError: (Object e) => AppLogger.w('notify.bus', e),
      );
    } catch (e) {
      AppLogger.w('notify.attach.bus', e);
    }
    try {
      _telemetryObserver = _onTelemetry;
      Telemetry.addObserver(_telemetryObserver!);
    } catch (e) {
      AppLogger.w('notify.attach.telemetry', e);
    }
  }

  /// 停止旁听（测试收尾 / 热重载）。
  Future<void> detach() async {
    _attached = false;
    final observer = _telemetryObserver;
    if (observer != null) {
      Telemetry.removeObserver(observer);
      _telemetryObserver = null;
    }
    final sub = _busSub;
    _busSub = null;
    if (sub != null) await sub.cancel();
  }

  /// 后台 isolate 装配（0.49.0）：在 Workmanager 心跳的独立 isolate 里初始化并旁听。
  ///
  /// **与主 isolate 的 `init() + attach()` 是同一份实现**，唯一的区别是调用点：
  /// 心跳 isolate 没有 `main()`，没人会替它装这套旁听器。而"心跳期间到达的委托 /
  /// 私聊消息"的事件只落在**该 isolate 自己的** `AppEvents` 与 `Telemetry` 上，
  /// 主 isolate 那份看不见 —— 不在这里再装一份，那批通知就永远出不来
  /// （App 进程已死，主 isolate 更不可能补）。
  ///
  /// 返回"是否拿到了可用的呈现器"。**绝不抛**：心跳绝不能因通知而中断。
  /// [presenter] 仅供测试注入（跳过真插件）。
  Future<bool> attachInBackgroundIsolate({NotifyPresenter? presenter}) async {
    try {
      await init(presenter: presenter);
      attach();
      return _presenter != null;
    } catch (e) {
      AppLogger.w('notify.bg', e);
      return false;
    }
  }

  /// 申请通知权限。**复用值班权限的唯一出处**（`BackgroundDuty`），
  /// 不在这里重写一遍 `permission_handler` 调用——同一个能力只该有一份实现。
  Future<bool> requestPermission() => BackgroundDuty.requestNotificationPermission();

  Future<bool> get permissionGranted => BackgroundDuty.notificationAllowed;

  /// 晨间问候 / 三日回顾通知。复用 `_dispatch` 的免打扰 + 总开关 + 去重闸门；
  /// 调用方（MorningDigestService）已做过"今日是否已问候"的去重，这里再兜一层
  /// 去重键避免同一次周期内重复弹出。
  Future<void> notifyMorning({
    required String title,
    required String body,
    String? dedupKey,
  }) async {
    await _dispatch(
      NotifyKind.morningDigest,
      title: title,
      body: body,
      dedupKey: dedupKey ?? 'morning',
    );
  }

  /// 提醒到期（0.70.0）。★ 与晨间问候唯一的不同：**绕过免打扰窗口**——
  /// 提醒是主人自己定的强意图（"明早 8 点提醒我"），被夜间窗口静默掉 =
  /// "我定的事它没办"，比多吵醒一次更伤信任。总开关仍然有效（总开关关 =
  /// 主人明确表示"一条都别弹"，那才是要尊重的意志）。
  Future<void> notifyReminder({
    required String title,
    required String body,
    String? dedupKey,
  }) async {
    await _dispatch(
      NotifyKind.reminder,
      title: title,
      body: body,
      dedupKey: dedupKey,
      bypassQuiet: true,
    );
  }

  // ---------------- 事件源（旁听，不做任何业务决策） ----------------

  Future<void> _onCommand(AppCommand cmd) async {
    final l10n = L10nHolder.l10n;
    switch (cmd) {
      case SocialMessageReceivedEvent():
        final peer = cmd.senderAgentId.isEmpty ? '?' : cmd.senderAgentId;
        await _dispatch(
          NotifyKind.directMessage,
          title: l10n.notifyDirectMessageTitle,
          body: l10n.notifyDirectMessageBody(peer),
          dedupKey: _dedupOf('soc', cmd.sourceMsgId, peer, cmd.message),
        );
      case WorldRoomMessageEvent():
        // 会客厅消息量大：只有**点名 @我**才值得打扰，普通房间发言一律静默。
        if (!NotificationPolicy.mentionsMe(
          cmd.message,
          myAgentId: _selfAgentId,
          myNickname: _selfNickname,
        )) {
          return;
        }
        final who = cmd.nickname.isEmpty ? cmd.senderAgentId : cmd.nickname;
        await _dispatch(
          NotifyKind.loungeMention,
          title: l10n.notifyLoungeMentionTitle,
          body: l10n.notifyLoungeMentionBody(who),
          dedupKey: _dedupOf('room', cmd.sourceMsgId, cmd.roomId, cmd.message),
        );
      case AgentActionPendingEvent():
        await _dispatch(
          NotifyKind.suggestion,
          title: l10n.notifySuggestionTitle,
          body: l10n.notifySuggestionBody,
          dedupKey: _dedupOf('sug', cmd.actionType, cmd.targetId, cmd.detail),
        );
      default:
        break;
    }
  }

  /// 埋点旁路：委托 / 互介卡到达走的是 `Telemetry.track`（
  /// `delegation_received` / `intercard_received`），这里按事件名过滤。
  void _onTelemetry(String name, Map<String, Object?> props) {
    final l10n = L10nHolder.l10n;
    switch (name) {
      case 'delegation_received':
        final peer = (props['peer'] ?? '').toString();
        unawaited(_dispatch(
          NotifyKind.delegation,
          title: l10n.notifyDelegationTitle,
          body: l10n.notifyDelegationBody(peer.isEmpty ? '?' : peer),
          dedupKey: _dedupOf('dlg', props['delegation_id'], peer),
        ));
      case 'intercard_received':
        final peer = (props['peer'] ?? '').toString();
        unawaited(_dispatch(
          NotifyKind.intercard,
          title: l10n.notifyIntercardTitle,
          body: l10n.notifyIntercardBody(peer.isEmpty ? '?' : peer),
          dedupKey: _dedupOf('icd', props['intercard_id'], peer),
        ));
      default:
        break;
    }
  }

  // ---------------- 闸门 + 呈现 ----------------

  Future<void> _dispatch(
    NotifyKind kind, {
    required String title,
    required String body,
    String? dedupKey,
    bool bypassQuiet = false,
  }) async {
    final presenter = _presenter;
    if (presenter == null) return; // 初始化失败/未初始化 ⇒ 静默降级
    if (!bypassQuiet &&
        !NotificationPolicy.shouldNotify(
          settings: _settings,
          hour: clock().hour,
        )) {
      return;
    }
    if (dedupKey != null && !_rememberOnce(dedupKey)) return;
    try {
      await presenter(NotificationRequest(
        id: _idOf(dedupKey ?? '$kind|$title|$body'),
        title: title,
        body: body,
      ));
    } catch (e) {
      AppLogger.w('notify.show', e);
    }
  }

  /// 首次见到该键返回 true；重复返回 false。容量满时淘汰最旧的一条。
  bool _rememberOnce(String key) {
    if (_recent.contains(key)) return false;
    _recent.add(key);
    while (_recent.length > _recentCapacity) {
      _recent.remove(_recent.first);
    }
    return true;
  }

  /// 通知 ID 必须稳定：同一件事重复投递时覆盖同一条，而不是刷屏。
  static int _idOf(String key) => key.hashCode & 0x7fffffff;

  /// 组装去重键。`sourceMsgId` 缺失时退化为内容指纹。
  static String _dedupOf(String ns, Object? id, Object? a, [Object? b]) {
    final key = (id ?? '').toString();
    if (key.isNotEmpty) return '$ns:$key';
    return '$ns:${a ?? ''}|${b ?? ''}'.hashCode.toString();
  }

  // ---------------- 身份缓存 ----------------

  Future<void> _loadSelfIdentity() async {
    try {
      _selfAgentId = await DBHelper.getAmbassador('my_agent_id') ?? '';
      _selfNickname = await DBHelper.getAmbassador('nickname') ?? '';
    } catch (e) {
      AppLogger.w('notify.identity', e);
    }
  }

  /// 身份可能在建号后才出现（首次引导）⇒ 让 UI 在合适时机重取一次。
  Future<void> refreshSelfIdentity() => _loadSelfIdentity();

  /// 仅测试用：直接注入本机身份，免得为了一条 @我 断言去起一个 SQLite。
  @visibleForTesting
  void debugSetSelfIdentity({String? agentId, String? nickname}) {
    if (agentId != null) _selfAgentId = agentId;
    if (nickname != null) _selfNickname = nickname;
  }

  // ---------------- 插件装配 ----------------

  Future<NotifyPresenter?> _buildPluginPresenter() async {
    if (_plain) return null;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // iOS/macOS 的权限**不在这里静默申请**——与 Android 一致，
        // 先讲理由再由用户点，故三个 request* 全置 false。
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      // ⚠️ v22 起 `initialize` / `show` 全部改成**具名参数**（旧版是位置参数），
      //    照旧版写法会在编译期直接报 missing_required_argument。
      await plugin.initialize(settings: init);

      final channelName = L10nHolder.l10n.notifyChannelName;
      final android =
          plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      // Android 8+ 不预先建渠道 ⇒ 通知会被系统**静默丢弃**（不报错，只是不出现）。
      await android?.createNotificationChannel(AndroidNotificationChannel(
        channelId,
        channelName,
        description: L10nHolder.l10n.notifyChannelDescription,
        importance: Importance.high,
      ));

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: L10nHolder.l10n.notifyChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      );

      AppLogger.i('notify.init', 'system notifications ready');
      return (request) => plugin.show(
            id: request.id,
            title: request.title,
            body: request.body,
            notificationDetails: details,
          );
    } catch (e) {
      _plain = true;
      AppLogger.w('notify.init', e);
      return null;
    }
  }
}
