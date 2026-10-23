/// App 内页面注册表（UI 层）：**真实页面 → 键 / 标签**的唯一映射。
///
/// 这是"智能体能打开哪些页面"的**唯一事实源**：core 的 `open_app_page` 只认这里
/// 注册过的键。★ 新增页面时**只改这一个文件** —— 工具描述里的页面清单与校验自动跟上。
///
/// ★★ 只登记**无参可构造**的页面（`builder: (_) => const XScreen()` 或 `XScreen()`）。
///   需要参数的页面（如 `WorldRoomScreen(room:, myAgentId:)`、`TopicDetailScreen(...)`、
///   `DigestScreen(onNavigate:)`、`BackupNudgeScreen(onFinished:)`）**不在此列** ——
///   给它编一个"空参数"的入口，等于让智能体打开一个必然报错的页面。
///
/// ★★ 另一类**刻意不登记**的：带「唯一入口」红线的页面 —— 目前是
///   `AgentActionInboxScreen`（待我确认的建议）。它是审批入口，0.61.0 定死
///   「审批入口唯一且落在日志页内、日志页签恒常显不得门控」（`tool/verify_mode_visibility.dart`
///   正面钉住）。登记它 = 凭空多出一个引用点，**会让那条红线静默失效**（守卫当场变红）。
///   ⇒ 该页**不由智能体代开**，主人从日志页进。
///
/// ★ 调用方**不要**写 `const AppPage(...)`：`builder` 是闭包，闭包不是编译期常量。
// ★ 这里不需要 import `package:flutter/material.dart`：`AppPage` / `WidgetBuilder`
//   都由 `app_navigation.dart` 带出，本文件只引用具体 Screen 类型。
import '../core/app_navigation.dart';
import 'advanced_settings_screen.dart';
import 'dashboard_screen.dart';
import 'device_control_screen.dart';
import 'device_migration_screen.dart';
import 'diagnostics_screen.dart';
import 'dsh_import_screen.dart';
import 'glossary_screen.dart';
import 'identity_backup_screen.dart';
import 'mail_account_screen.dart';
import 'memory_manager_screen.dart';
import 'notification_sms_screen.dart';
import 'passport_screen.dart';
import 'profile_screen.dart';
import 'rotation_chain_screen.dart';
import 'serendipity_screen.dart';
import 'settings_screen.dart';
import 'skill_market_screen.dart';
import 'tool_list_screen.dart';
import 'topic_list_screen.dart';
import 'weekly_report_screen.dart';

/// 构造"真实页面"注册表。
/// ★ 顺序 = 工具描述里的展示顺序（把天天会用的放前面）。
List<AppPage> buildAppPages() => <AppPage>[
      AppPage(key: 'settings', label: 'Settings', builder: (_) => SettingsScreen()),
      AppPage(
          key: 'advanced_settings',
          label: 'Advanced settings',
          builder: (_) => const AdvancedSettingsScreen()),
      AppPage(key: 'passport', label: 'Passport', builder: (_) => const PassportScreen()),
      AppPage(
          key: 'identity_backup',
          label: 'Identity backup',
          builder: (_) => const IdentityBackupScreen()),
      AppPage(
          key: 'device_migration',
          label: 'Device migration',
          builder: (_) => const DeviceMigrationScreen()),
      AppPage(
          key: 'key_rotation',
          label: 'Key rotation history',
          builder: (_) => const RotationChainScreen()),
      AppPage(key: 'mail', label: 'Mail account', builder: (_) => const MailAccountScreen()),
      AppPage(
          key: 'phone_control',
          label: 'Phone control',
          builder: (_) => const DeviceControlScreen()),
      AppPage(
          key: 'notify_sms',
          label: 'Notification & SMS',
          builder: (_) => const NotificationSmsScreen()),
      AppPage(
          key: 'memory', label: 'Memory', builder: (_) => const MemoryManagerScreen()),
      AppPage(
          key: 'diagnostics',
          label: 'Diagnostics',
          builder: (_) => const DiagnosticsScreen()),
      AppPage(key: 'tools', label: 'Tools', builder: (_) => ToolListScreen()),
      AppPage(
          key: 'skill_market',
          label: 'Skill market',
          builder: (_) => const SkillMarketScreen()),
      AppPage(key: 'dsh_import', label: 'DSH import', builder: (_) => const DshImportScreen()),
      AppPage(key: 'profile', label: 'Profile', builder: (_) => ProfileScreen()),
      // ★★ 刻意**不**登记 `AgentActionInboxScreen`（待我确认的建议）：它是审批入口，
      //   带 0.61.0 的「审批入口唯一且落在日志页内」红线（日志页签恒常显、不得门控），
      //   由 `tool/verify_mode_visibility.dart` 正面钉住；把它列进注册表会让那条红线
      //   **静默失效**（守卫②当场变红）。故该页**不由智能体代开** —— 主人从日志页进。
      AppPage(key: 'topics', label: 'Topics', builder: (_) => TopicListScreen()),
      AppPage(key: 'dashboard', label: 'Dashboard', builder: (_) => const DashboardScreen()),
      AppPage(
          key: 'serendipity',
          label: 'Serendipity',
          builder: (_) => const SerendipityScreen()),
      AppPage(
          key: 'glossary', label: 'Glossary', builder: (_) => const GlossaryScreen()),
      AppPage(
          key: 'weekly_report',
          label: 'Weekly report',
          builder: (_) => const WeeklyReportScreen()),
    ];
