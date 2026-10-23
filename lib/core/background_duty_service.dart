/// 后台值班（Background Duty）——「息屏后分身仍然活着」的两层地基。
///
/// ---------------------------------------------------------------------------
/// 层 1：值班权限（前台服务能活多久，取决于用户给了什么）
/// ---------------------------------------------------------------------------
/// * **通知权限**（Android 13+）：前台服务的常驻通知不显示 ≠ 服务没跑，
///   但用户看不见的"隐形耗电"只会换来差评与手杀——必须让通知可见；
/// * **电池优化豁免**：原生 Android 上免受 Doze 节流；国产 ROM 另有自己的
///   杀后台逻辑（自启动/省电策略），那属于 ROM 引导页的职责（另做）。
///
/// 两个请求都必须**先讲理由再弹系统框**——裸弹系统权限框的拒绝率极高。
///
/// ---------------------------------------------------------------------------
/// 层 3：值班心跳（Workmanager 周期任务的执行体）
/// ---------------------------------------------------------------------------
/// 社交协议本来就是异步的（邮箱 + 游标 + 节奏闸），分身不需要秒回，
/// 需要的是**定时醒来干活**：补发离线攒下的公示（outbox）→ 拉取 Hub 邮箱
/// → 交给 AgentService 的既有回复管线（安全审查 + LLM 决策）→ 睡觉。
///
/// ★ **跨 isolate 互斥**：Workmanager 在独立 isolate 里跑，与主 isolate 的
///   雷达轮询（`radar_service.dart` 云端分支）可能同时拉邮箱——两边各自的
///   内存去重（60 秒窗口）互相看不见，同一封邮件会被回复两次。所以拉取前
///   必须抢 SharedPreferences 的 **TTL 锁**：抢不到的一方本轮直接放弃。
///   已知边界：check-then-set 不是跨 isolate 原子操作，双抢窗口在毫秒级；
///   心跳周期 15 分钟、主用场景是"App 进程已死"，实际撞车概率可忽略。
///   要彻底封死需要 DB 级消息台账，留给心跳 v2。
///
/// 所有外部依赖（initAgent / init / flush / pull）都以可注入函数暴露：
/// 测试用桩替换，生产用默认真身。
library;

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agent_service.dart';
import 'app_logger.dart';
import 'cloud_service.dart';
import 'db_helper.dart';
import 'wold_runtime.dart';

/// 一次心跳的成果汇报（打点/测试断言用）。
class HeartbeatReport {
  /// 锁被别人持有（前台轮询中/上次心跳未结束）——本轮整场放弃。
  final bool lockSkipped;

  /// 是否执行了 AgentService.initAgent（无 API Key 时跳过，回复管线不工作）。
  final bool agentReady;

  /// WoldRuntime 是否就绪（init 失败不影响邮箱，只影响 outbox）。
  final bool runtimeReady;

  /// outbox 补发成功的条数（-1 = 未尝试）。
  final int outboxSent;

  /// 邮箱是否完成了一轮拉取（未配置 Hub 时 pullMailbox 内部静默早退）。
  final bool mailboxPulled;

  const HeartbeatReport({
    this.lockSkipped = false,
    this.agentReady = false,
    this.runtimeReady = false,
    this.outboxSent = -1,
    this.mailboxPulled = false,
  });

  @override
  String toString() =>
      'HeartbeatReport(lockSkipped: $lockSkipped, agentReady: $agentReady, '
      'runtimeReady: $runtimeReady, outboxSent: $outboxSent, '
      'mailboxPulled: $mailboxPulled)';
}

abstract final class BackgroundDuty {
  // ------------------------------------------------------------------
  // 层 1：值班权限
  // ------------------------------------------------------------------

  /// 通知权限是否已授予（Android 13- 上恒为 true）。
  static Future<bool> get notificationAllowed =>
      Permission.notification.isGranted;

  static Future<bool> requestNotificationPermission() async =>
      (await Permission.notification.request()).isGranted;

  /// 是否已在电池优化白名单（忽略电池优化）。
  static Future<bool> get batteryExempt =>
      Permission.ignoreBatteryOptimizations.isGranted;

  /// 发起系统"忽略电池优化"授权页。**调用方必须先用对话框讲清理由**。
  static Future<bool> requestBatteryExemption() async =>
      (await Permission.ignoreBatteryOptimizations.request()).isGranted;

  /// 两项都齐 = 值班条件完整（ROM 引导另算）。
  static Future<bool> get dutyFullyPermitted async =>
      await notificationAllowed && await batteryExempt;

  // ------------------------------------------------------------------
  // 值班锁（跨 isolate 互斥，见文件头）
  // ------------------------------------------------------------------

  static const String _lockKey = 'duty_heartbeat_lock_until_ms';
  static const String _lockTokenKey = 'duty_heartbeat_lock_token';

  /// 本 isolate 当前持有的锁令牌（isolate 内存态——令牌只用来证明
  /// "锁还是我抢的那把"，不参与跨 isolate 判定）。
  static String? _heldToken;

  /// 抢锁。已有未过期持有者 → false（调用方本轮放弃，**不要**碰锁）。
  ///
  /// ★ 读前必须 `reload()`：legacy SharedPreferences **每个 isolate 缓存
  /// 一份且永不自动刷新**——后台心跳写入的锁，主 isolate 的缓存里根本
  /// 看不见（反之亦然）。不 reload 的锁形同虚设。
  static Future<bool> acquireLock({required Duration ttl}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final now = DateTime.now().millisecondsSinceEpoch;
    final heldUntil = prefs.getInt(_lockKey) ?? 0;
    if (heldUntil > now) return false;
    _heldToken =
        '${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch ^ ttl.inMilliseconds}';
    await prefs.setInt(_lockKey, now + ttl.inMilliseconds);
    await prefs.setString(_lockTokenKey, _heldToken!);
    return true;
  }

  /// 放锁。带**属主令牌**校验：锁超时被别人抢走后，迟到的释放不得放掉
  /// 别人的锁（无属主的 remove 是级联并发的放大器）。
  static Future<void> releaseLock() async {
    final prefs = await SharedPreferences.getInstance();
    final mine = _heldToken;
    _heldToken = null;
    if (mine == null) return; // 没抢到过锁的人不该走到这里
    await prefs.reload();
    if (prefs.getString(_lockTokenKey) != mine) return; // 锁已易主
    await prefs.remove(_lockKey);
    await prefs.remove(_lockTokenKey);
  }

  // ------------------------------------------------------------------
  // 层 3：值班心跳
  // ------------------------------------------------------------------

  /// 心跳执行体。在 Workmanager 的后台 isolate 里跑，也可测试直调。
  ///
  /// 步骤：抢锁 → initAgent（有 Key 才做，喂饱回复管线）→ WoldRuntime.init
  /// （幂等，喂饱 outbox）→ flushOutbox → pullMailbox → 放锁。
  /// 每一步独立 try/catch：梦境Reflection那条 Workmanager 任务已经证明
  /// "后台 isolate 里任何一步都可能因环境缺失而死"，值班不能被一步带崩。
  static Future<HeartbeatReport> runHeartbeat({
    Duration lockTtl = const Duration(minutes: 5),
    Future<void> Function()? initAgentFn,
    Future<void> Function()? initRuntimeFn,
    Future<int> Function()? flushOutboxFn,
    Future<void> Function(String agentId)? pullMailboxFn,
    Future<String?> Function()? agentIdFn,
    Future<bool> Function()? hasApiKeyFn,
    Future<bool> Function()? cloudChannelOnFn,
    Future<void> Function()? drainRepliesFn,
  }) async {
    if (!await acquireLock(ttl: lockTtl)) {
      return const HeartbeatReport(lockSkipped: true);
    }
    var agentReady = false;
    var runtimeReady = false;
    var outboxSent = -1;
    var mailboxPulled = false;
    try {
      // ① 回复管线：没有 API Key 就没有"处理消息"，后面的邮箱拉取只会
      //    把光标推走却不回复——宁可这轮不拉，邮件留给下次有 Key 时。
      final hasKey = await (hasApiKeyFn?.call() ?? _hasApiKey());
      if (hasKey) {
        try {
          final svc = AgentService();
          svc.headless = true; // 无 UI isolate：权限请求只拒本次，不持久 deny
          await (initAgentFn?.call() ?? svc.initAgent());
          agentReady = true;
        } catch (e) {
          AppLogger.w('duty.initAgent', e);
        }
      }

      // ② 运行时（幂等）：outbox 的前提。失败不拦邮箱。
      //    注入 initRuntimeFn 时 readiness 由"桩没抛"决定——测试环境里没有
      //    真库，不该去读真实的 WoldRuntime 单例。
      try {
        if (initRuntimeFn != null) {
          await initRuntimeFn();
          runtimeReady = true;
        } else {
          if (!WoldRuntime.i.isReady) await WoldRuntime.i.init();
          runtimeReady = WoldRuntime.i.isReady;
        }
      } catch (e) {
        AppLogger.w('duty.initRuntime', e);
      }

      // ③ outbox 补发：flushOutbox 自带 isReady 守卫（未就绪返回 0）。
      if (runtimeReady) {
        try {
          outboxSent = await (flushOutboxFn?.call() ??
              WoldRuntime.i.flushOutbox());
        } catch (e) {
          AppLogger.w('duty.flushOutbox', e);
        }
      }

      // ④ 邮箱：游标式拉取 → AppEvents → AgentService 回复管线。
      //    两个闸缺一不可：
      //    a. agentReady——没有回复管线就拉，等于把光标推走、消息吞掉；
      //    b. **用户意志**——云端通道被用户关掉 ⇒ 回复发不出去（三通道
      //       全关），拉了同样是吞信，还绕过了用户的隐私选择。
      if (agentReady) {
        final cloudOn =
            await (cloudChannelOnFn?.call() ?? _isCloudChannelOn());
        if (cloudOn) {
          try {
            final myId = await (agentIdFn?.call() ??
                DBHelper.getAmbassador('my_agent_id'));
            if (myId != null && myId.isNotEmpty) {
              await (pullMailboxFn?.call(myId) ??
                  CloudService().pullMailbox(myId));
              mailboxPulled = true;
              // ★ P0 修复：Workmanager 引擎在本 future 返回后**立即销毁**。
              //   回复是 1 秒防抖 + LLM 往返（fire-and-forget），不等落定 =
              //   拉走的邮件永远没有回复。硬顶 90 秒防失控。
              await (drainRepliesFn?.call() ??
                  AgentService().drainPendingReplies());
            }
          } catch (e) {
            AppLogger.w('duty.mailbox', e);
          }
        }
      }
    } finally {
      await releaseLock();
    }
    final report = HeartbeatReport(
      agentReady: agentReady,
      runtimeReady: runtimeReady,
      outboxSent: outboxSent,
      mailboxPulled: mailboxPulled,
    );
    AppLogger.w('duty.heartbeat', report);
    return report;
  }

  static Future<bool> _hasApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('api_key') ?? '').isNotEmpty;
  }

  /// 用户的云端通道开关（值班心跳的意志闸）。后台引擎是全新 isolate，
  /// getInstance 即最新平台状态——但仍 reload 一次，把假设变成保证。
  static Future<bool> _isCloudChannelOn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool('link_cloud_enabled') ?? false;
  }
}
