import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'ui/app_pages.dart';
import 'ui/serendipity_screen.dart';

import 'l10n/app_localizations.dart';
import 'core/agent_service.dart';
import 'core/app_events.dart';
import 'core/app_logger.dart';
import 'core/app_navigation.dart';
import 'core/agent_identity.dart';
import 'core/backup_nudge_policy.dart';
import 'core/background_duty_service.dart';
import 'core/l10n_holder.dart';
import 'core/language_controller.dart';
import 'core/mode_controller.dart';
import 'core/morning_digest_service.dart';
import 'core/notification_service.dart';
import 'core/radar_service.dart';
import 'core/reminder_service.dart';
import 'core/session_crypto.dart';
import 'core/theme_provider.dart';
import 'core/wold_runtime.dart';
import 'core/neighbor_source.dart';
import 'core/dream_service.dart';
import 'ui/chat_screen.dart';
import 'ui/backup_nudge_screen.dart';
import 'ui/manage_screen.dart';
import 'ui/onboarding_screen.dart';
import 'ui/plugin_labels.dart';
import 'ui/social_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/world_screen.dart';

const String _nightlyTaskName = 'nightly_dream_evolution';

/// 值班心跳：息屏/进程被杀后，分身定期醒来补发 outbox + 拉邮箱 + 回消息。
/// 见 `lib/core/background_duty_service.dart`（跨 isolate 锁与降级纪律）。
const String _heartbeatTaskName = 'dahuang_duty_heartbeat';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task == _nightlyTaskName) {
      try {
        final bool success = await DreamService().triggerNightlyReflection();
        return Future.value(success);
      } catch (e) {
        return Future.value(false);
      }
    }
    if (task == _heartbeatTaskName) {
      // 后台 isolate 里**独立**装一套通知旁听器：本 isolate 的事件（拉邮箱 →
      // AppEvents / 委托埋点）只有本 isolate 的旁听器看得见 —— 事件总线与
      // 观察者表都按 isolate 各存一份，主 isolate 那份够不着。
      // 装失败只降级为"不弹通知"，**绝不能影响心跳结果**（心跳比通知重要）。
      try {
        await NotificationService.i.attachInBackgroundIsolate();
      } catch (_) {
        // 该方法自身已吞异常；这里再兜一层，确保心跳不被打断
      }
      // ★ 语言选择同理：它是**内存态**（SharedPreferences 恢复出来的字段），
      //   不跨 isolate 继承。不在这里 load 一次，后台 isolate 里所有提示词的
      //   「回复语言」会退回跟随系统 —— 夜间造梦 / 后台回复就会说错语言。
      //   同通知：失败只降级，**绝不打断心跳**。
      try {
        await LanguageController.i.load();
      } catch (_) {
        // load() 自身已吞异常；再兜一层
      }
      try {
        await BackgroundDuty.runHeartbeat();
        // 晨间问候 / 三日回顾：独立 try/catch，绝不影响心跳结果（心跳比问候重要）。
        try {
          await MorningDigestService.i.maybeEmit();
        } catch (_) {
          // 静默降级
        }
        // 提醒到期检查（0.70.0）：同样独立 try/catch。提醒补发去重靠
        // reminders.notified_at，连续两轮心跳看到同一条也只弹一次。
        try {
          await ReminderService.i.maybeEmitDue();
        } catch (_) {
          // 静默降级
        }
        return Future.value(true);
      } catch (e) {
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ★ 0.50.0（审计 P2「release 日志未关闭」）：**正式包里关掉控制台打印**。
  //   ⚠️ 关的只是"打印到控制台"（logcat / stdout），**不是"记录"** ——
  //   `AppLogger` 落 `system_logs` 表那一半照旧（那是「设置 → 排障」读取的
  //   功能本身，闸掉它等于把功能删了）。⇒ release 下用户报障仍能在 App 内查到
  //   日志，但设备控制台不再吐字 —— 审计要的正是这一条。
  //   ⚠️ 必须放在全局异常网**之前**：否则 FlutterError 处理函数里的
  //   `presentError` 会抢先把同一份栈打到控制台。
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // ★ 全局异常网：必须在任何异步工作**之前**装好。
  //   在此之前，构建/布局期异常直接进 Flutter 默认处理（release 下表现为白屏/闪退），
  //   而异步里没人 catch 的异常连一行日志都不留 —— 用户报"闪退"时，
  //   设备上没有 system_logs 可查，排障只能靠猜。
  //   两个口子必须**都**接：FlutterError 管构建/布局/绘制，
  //   PlatformDispatcher 管异步 Zone 里漏出来的；只接一个会漏掉另一半。
  FlutterError.onError = (details) {
    // release 不再往控制台喷栈（同上一段的日志闸）；`AppLogger` 仍落库可查。
    if (!kReleaseMode) FlutterError.presentError(details);
    AppLogger.e('flutter', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('async', error, stack);
    // 已记录 ⇒ 不再向上抛：release 下未捕获异常会直接终止进程。
    // 选择"降级继续"而不是"崩"，因为本地已有 system_logs 兜底可查。
    return true;
  };

  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  Workmanager().registerPeriodicTask(
    _nightlyTaskName,
    _nightlyTaskName,
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresCharging: true,
      requiresBatteryNotLow: true,
    ),
  );

  // 值班心跳：Workmanager 周期下限 15 分钟。不要求充电/满电——分身值班
  // 不该挑时机；已有的 TTL 锁保证它与前台雷达轮询互斥，不会双拉邮箱。
  Workmanager().registerPeriodicTask(
    _heartbeatTaskName,
    _heartbeatTaskName,
    frequency: const Duration(minutes: 15),
    initialDelay: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
  );

  final prefs = await SharedPreferences.getInstance();
  // 主题 ID 已是语言中立值（red/orange/...）；这里仍做一次遗留归一化，
  // 兼容老版本把中文色名当 ID 落库的用户。
  final savedTheme =
      legacyThemeIds[prefs.getString('app_theme') ?? ''] ?? 'cyan';
  _applySystemUi(
      savedTheme == 'blue' || savedTheme == 'purple' || savedTheme == 'black');

  // 语言选择恢复（0.55.0）：必须在 runApp 之前 —— MaterialApp.locale 首帧就要
  // 拿到正确语言，否则会先闪一帧系统语言再跳成用户选的。
  await LanguageController.i.load();

  // 模式恢复（0.61.0）：同样必须在 runApp 之前 —— 首帧就要定下社交页签数、
  // 以及管理页/控制中心的进阶项是否收起。晚一步就会先闪一帧错误的界面再跳。
  await ModeController.i.load();

  // 🧭 0.86.0：把**真实页面**注册进 core 的导航表（须在 initAgent 之前 ——
  //   工具描述里的页面清单是注册时拼的）。纯数据 + 同步，无副作用。
  registerAppPages(buildAppPages());

  AgentService().initAgent();

  // M1 入场即进圈 + M2 事务委托的运行时装配（真设备身份 + SQLite + 埋点落盘）。
  // 失败不能挡住启动，但必须可见——否则埋点静默丢弃、验收数据永远为空。
  try {
    await WoldRuntime.i.init();
    // 出站通道在这里注入（core 层之间不互相 import，避免 agent_service ↔ wold_runtime 成环）。
    // 走既有"全通道火力覆盖"策略：近场 / 局域网 / 云端，哪个通算哪个。
    WoldRuntime.i.outbound = AgentService().sendStructuredWire;
    // 兜底来源也在这里注入：近场 / 局域网 / 名册在线，全是真实在线的节点
    // （空数组兜底 = M1 验收过不了；假数据兜底 = 把验收变成演戏，两者都不做）。
    WoldRuntime.i.neighborFallback = NeighborSource.resolve;
  } catch (e, st) {
    // 失败不挡启动，但必须**可见**：落 system_logs + 置 initError，
    // 由 MaterialApp.builder 那条常驻横幅显式呈现给用户。
    WoldRuntime.i.rememberInitFailure(e, st);
  }

  // 🔔 系统通知：委托到达 / 会客厅 @我 / 待我确认三类事件的召回通道。
  //   必须**排在 WoldRuntime.init 之后**——`Telemetry.bind` 就在那里执行，
  //   而"委托/互介卡到达"的信号正是走 Telemetry 旁路；观察者挂早了也没用
  //   （`_track` 走的是 `Telemetry.instance?.track`，instance 为空时整条不跑）。
  //   初始化失败只降级为"不弹通知"，绝不挡启动。
  try {
    await NotificationService.i.init();
    NotificationService.i.attach();
  } catch (e, st) {
    AppLogger.e('notify.boot', e, st);
  }

  // 提醒冷启动补检（0.70.0）：App 刚打开这一刻，上一轮心跳可能已过去
  // 15 分钟——主人现在就在看手机，恰是提醒最该出现的时机。内部全程
  // try/catch 且不抛，这里不再兜一层；unawaited，不挡启动。
  unawaited(ReminderService.i.maybeEmitDue());

  // 出站队列重放：启动即补一次离线攒下的上行，并挂上周期表。
  // 注：`startOutboxDrainer` 内部判 `isReady`，所以 init 失败时是安全的空转，
  // 不会去碰 `late final hubWrites`（那会抛 LateInitializationError）。
  unawaited(WoldRuntime.i.startOutboxDrainer());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final provider = ThemeProvider();
          provider.loadTheme();
          return provider;
        }),
        // 语言：main() 里已 load()，这里只把**同一个实例**挂进树，
        // 让 AppBar 的语言按钮 notifyListeners 时 MaterialApp 能跟着重建。
        ChangeNotifierProvider<LanguageController>.value(
            value: LanguageController.i),
        // 模式（0.61.0）：同上——把**同一个实例**挂进树，顶栏切换模式时
        // 社交页 / 管理页 / 控制中心能一起跟着重建（否则就是“改了不生效”）。
        ChangeNotifierProvider<ModeController>.value(value: ModeController.i),
      ],
      child: const FenApp(),
    ),
  );

  // 进程被杀后自动恢复雷达状态（需要插件已初始化，故放在 runApp 之后）
  unawaited(RadarService.instance.restore());
  // 载入本地通道已固定的对端身份绑定（TOFU 防重启重置）
  unawaited(SessionCrypto.instance.warmUp());
}

void _applySystemUi(bool isDark) {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: isDark ? Colors.black : Colors.white,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  ));
}

/// 应用根组件。品牌置换（2026-09-26）：类名由 PocketAgentApp 改为 FenApp。
class FenApp extends StatefulWidget {
  const FenApp({Key? key}) : super(key: key);

  @override
  _FenAppState createState() => _FenAppState();
}

class _FenAppState extends State<FenApp> with WidgetsBindingObserver {
  // 0.86.0：改为**引用 core 的全局键**（`app_navigation.dart`）⇒ `open_app_page`
  //   工具与 UI 共用同一个导航栈 —— 工具 push 的页面就落在主人眼前这个栈上。
  final GlobalKey<NavigatorState> navigatorKey = appNavigatorKey;
  StreamSubscription<AppCommand>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = AppEvents.stream.listen(_onCommand);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  /// 回前台补一次出站队列重放。
  ///
  /// 为什么非要有这一条：Android 在后台会**冻结 Dart 定时器**，
  /// `startOutboxDrainer` 的周期表在后台是停的。于是"退出去放了一整天再切回来"
  /// 这种最典型的用法，恰恰是周期表最该工作、却最不会工作的场景 ——
  /// 不补这一下，攒下的记录要再等满一个周期才发得出去。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(WoldRuntime.i.flushOutbox());
    }
  }

  Future<void> _onCommand(AppCommand cmd) async {
    if (cmd is ChangeThemeCommand) {
      final provider = Provider.of<ThemeProvider>(context, listen: false);
      await provider.setTheme(cmd.themeKey);
      _applySystemUi(provider.isDark);
    } else if (cmd is ToolPermissionRequest) {
      _showToolPermissionDialog(cmd);
    }
  }

  void _showToolPermissionDialog(ToolPermissionRequest req) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      // 无 UI 应答（如后台），fail-closed：拒绝
      req.completer.complete(false);
      return;
    }
    showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final l10n = AppLocalizations.of(dialogCtx);
        return AlertDialog(
          title: Text(l10n.toolPermissionTitle),
          content: SingleChildScrollView(
            child: Text(l10n.toolPermissionMessage(_promptText(l10n, req.prompt))),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(l10n.toolPermissionDeny),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(l10n.toolPermissionAllow),
            ),
          ],
        );
      },
    ).then((ok) => req.completer.complete(ok ?? false));
  }

  // ------------------------------------------------------------------
  // 权限弹窗正文：核心层只给结构化提示，文案在这里按当前语言拼装
  // ------------------------------------------------------------------

  String _promptText(AppLocalizations l10n, PermissionPrompt p) {
    if (p.kind == PermissionPromptKind.pluginGrant) {
      final caps = p.capabilities
          .map((c) => capabilityLabel(l10n, c))
          .join(l10n.permListSeparator);
      return l10n.permPluginGrantBody(
          _pluginDisplayName(l10n, p), caps, p.declaredDescription);
    }
    return _actionText(l10n, p);
  }

  /// 插件展示名：形态码 → 文案（device_control / mcp:<服务名> / 其余用原始键）
  String _pluginDisplayName(AppLocalizations l10n, PermissionPrompt p) {
    switch (p.displayCode) {
      case PermissionDisplay.deviceControl:
        return l10n.permPluginDeviceControl;
      case PermissionDisplay.mcp:
        return l10n.permPluginMcp(p.displayArg ?? '');
      default:
        return p.subject;
    }
  }

  /// 高危工具调用的操作描述
  String _actionText(AppLocalizations l10n, PermissionPrompt p) {
    switch (p.actionCode) {
      case PermissionAction.createTool:
        return l10n.permActionCreateTool(p.actionArg ?? 'tool');
      case PermissionAction.openUrlOrApp:
        return l10n.permActionOpenUrl(p.actionArg ?? '');
      case PermissionAction.changeSettings:
        return l10n.permActionChangeSettings(p.actionArg ?? '');
      case PermissionAction.sendMail:
        // 收件人必须出现在确认文案里（"要发邮件"却不说发给谁 = 无法判断）
        return l10n.permActionSendMail(p.actionArg ?? '');
      default:
        return p.declaredDescription;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      // 品牌置换（2026-09-26）：应用对外名 = Fen（中文名「小荒」）
      title: 'Fen',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      // 国际化（PRD §2.6 英文化骨架）：英文为模板，其余为对照
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // ★ 显式指定语言（0.55.0）。**永不为 null**：'system' 已在
      //   LanguageController 内部折成具体语种（zh-TW → 繁体），
      //   不把歧义留给 Flutter 的默认解析（它会把 zh-TW 折成 zh 简体）。
      locale: Provider.of<LanguageController>(context).locale,
      // 把当前语言注入 core 层：权限弹窗描述、状态回执等文案在 core 层拼装，
      // 那里没有 BuildContext。切换语言时 builder 会重跑，文案随之刷新。
      builder: (context, child) {
        final l10n = AppLocalizations.of(context);
        L10nHolder.install(l10n);
        final content = child ?? const SizedBox.shrink();
        final initError = WoldRuntime.i.initError;
        if (initError == null) return content;
        // 运行时没起来时挂一条**常驻**横幅：失败发生在 runApp 之前，
        // 那时还没有 Navigator、也弹不出 SnackBar；而"功能莫名不可用"的半死界面
        // 正是这里要终结的形态。做成常驻而非一次性提示 —— 它是当前**状态**，不是事件。
        return _RuntimeDegradedHost(
          message: l10n.runtimeInitFailed(initError),
          child: content,
        );
      },
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: themeProvider.colorStart,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
              color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: themeProvider.colorStart,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: const _RootGate(),
    );
  }
}

/// 本地运行时启动失败时的**常驻提示条**。
///
/// 位置在 `MaterialApp.builder`（压在 Navigator 之上），因为失败发生在
/// `runApp` 之前 —— 那时既没有页面也没有 Navigator，弹不出也挂不上任何提示。
/// 它显示的是"当前处于降级状态"这个**事实**，所以不可关闭：真正的恢复方式是
/// 重启 App（或让 init 那一步的失败原因消失），不是把提示点掉。
class _RuntimeDegradedHost extends StatelessWidget {
  const _RuntimeDegradedHost({required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Material(
          color: theme.colorScheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// 首次启动闸门：
/// - 已经配置过（设置里已有 API Key）的老用户 → 直接进主界面，不打扰；
/// - 全新安装的用户 → 先走「三分钟接入向导」，配好模型再进入。
class _RootGate extends StatefulWidget {
  const _RootGate({Key? key}) : super(key: key);

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _loading = true;
  bool _showOnboarding = false;
  bool _showBackupNudge = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyConfigured = (prefs.getString('api_key') ?? '').trim().isNotEmpty;
    final done = prefs.getBool('onboarding_done') ?? alreadyConfigured;

    // 备份补课：引导走完/老用户跳过 ≠ 有退路。当前钥没备份过 + 不在
    // 免打扰期 ⇒ 冷启动先补一面（isBackedUp 按公钥比对，换钥后自动复位）。
    // 身份不可用（init 失败等）⇒ 不拦启动，下次再说。
    var showNudge = false;
    if (done) {
      try {
        showNudge = await BackupNudgePolicy.shouldShow(
          prefs,
          isBackedUpFn: AgentIdentity().isBackedUp,
        );
      } catch (e) {
        AppLogger.w('root.backupNudge', e);
      }
    }

    if (!mounted) return;
    setState(() {
      _showOnboarding = !done;
      _showBackupNudge = showNudge;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_showOnboarding) {
      return OnboardingScreen(
        onFinished: () => setState(() => _showOnboarding = false),
      );
    }
    if (_showBackupNudge) {
      return BackupNudgeScreen(
        onFinished: () => setState(() => _showBackupNudge = false),
      );
    }
    return const MainNavigator();
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({Key? key}) : super(key: key);

  @override
  _MainNavigatorState createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _pages = [
    ChatScreen(),
    SocialScreen(),
    const WorldScreen(),
    const SerendipityScreen(),
    ManageScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final l10n = AppLocalizations.of(context);
    // 订阅模式：切换时本页重建，顶栏图标随之切换。
    final mode = Provider.of<ModeController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: Icon(Icons.cleaning_services_rounded,
                  color: isDark ? Colors.white : Colors.black87),
              tooltip: l10n.mainClearSession,
              onPressed: () => AppEvents.emit(ClearChatCommand()),
            ),

          PopupMenuButton<String>(
            icon: Icon(Icons.palette,
                color: isDark ? Colors.white : Colors.black87),
            onSelected: (String key) {
              // 主题切换统一走事件总线（_onCommand 里 setTheme），避免双重调用
              AppEvents.emit(ChangeThemeCommand(key));
            },
            itemBuilder: (BuildContext context) {
              return THEMES.keys.map((String key) {
                final config = THEMES[key]!;
                return PopupMenuItem<String>(
                  value: key,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: [config.start, config.end]),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(themeLabel(l10n, key)),
                    ],
                  ),
                );
              }).toList();
            },
          ),

          // ★ 语言选择（0.55.0）：**紧挨主题按钮** —— 两者都是"外观偏好"，
          //   分开放用户就找不到。选项一律用各语言**自称**（简体中文 / English /
          //   日本語 / …），刻意不随界面语言翻译：英文界面下的中文用户若看到
          //   "Chinese" 反而认不出自己的语言。
          PopupMenuButton<String>(
            icon: Icon(Icons.translate,
                color: isDark ? Colors.white : Colors.black87),
            tooltip: l10n.langPickerTooltip,
            onSelected: (String code) {
              unawaited(LanguageController.i.setCode(code));
            },
            itemBuilder: (BuildContext context) {
              final current = LanguageController.i.code;
              return LanguageController.selectableCodes.map((String code) {
                final label = code == LanguageController.followSystem
                    ? l10n.langFollowSystem
                    : LanguageController.endonyms[code]!;
                return CheckedPopupMenuItem<String>(
                  value: code,
                  checked: code == current,
                  child: Text(label),
                );
              }).toList();
            },
          ),

          // ★ 模式切换（0.61.0）：**紧挨语言按钮**，与主题 / 语言 / 设置同排 ——
          //   入门模式（收起进阶页签与参数）↔ 进阶模式一键切换。
          //   图标随模式变（入门=学校 / 进阶=调节），不点开也知道当前在哪一档。
          PopupMenuButton<bool>(
            icon: Icon(mode.simpleMode ? Icons.school_outlined : Icons.tune,
                color: isDark ? Colors.white : Colors.black87),
            tooltip: l10n.modePickerTooltip,
            onSelected: (bool wantSimple) {
              unawaited(ModeController.i.setSimpleMode(wantSimple));
            },
            itemBuilder: (BuildContext context) {
              final isSimple = ModeController.i.simpleMode;
              return <PopupMenuEntry<bool>>[
                CheckedPopupMenuItem<bool>(
                  value: true,
                  checked: isSimple,
                  child: Text(l10n.modeBeginnerTitle),
                ),
                CheckedPopupMenuItem<bool>(
                  value: false,
                  checked: !isSimple,
                  child: Text(l10n.modeAdvancedTitle),
                ),
              ];
            },
          ),

          IconButton(
            icon: Icon(Icons.settings,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => SettingsScreen())),
          ),
        ],
      ),
      body: Container(
        decoration: themeProvider.backgroundDecoration,
        child: SafeArea(
          top: true,
          bottom: false,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: _pages,
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedItemColor: themeProvider.accentColor,
        unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
        backgroundColor:
            isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.9),
        elevation: 8,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_outline),
              activeIcon: const Icon(Icons.chat_bubble),
              label: l10n.mainNavChat),
          BottomNavigationBarItem(
              icon: const Icon(Icons.public),
              activeIcon: const Icon(Icons.public),
              label: l10n.mainNavSocial),
          BottomNavigationBarItem(
              icon: const Icon(Icons.travel_explore),
              activeIcon: const Icon(Icons.travel_explore),
              label: l10n.mainNavWorld),
          BottomNavigationBarItem(
              icon: const Icon(Icons.auto_awesome_mosaic_outlined),
              activeIcon: const Icon(Icons.auto_awesome_mosaic),
              label: l10n.mainNavSerendipity),
          BottomNavigationBarItem(
              icon: const Icon(Icons.folder_open),
              activeIcon: const Icon(Icons.folder),
              label: l10n.mainNavManage),
        ],
      ),
    );
  }
}
