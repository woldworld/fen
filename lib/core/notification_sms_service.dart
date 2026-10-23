import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'l10n_holder.dart';
import 'pii_detector.dart';

/// ============================================================
/// 通知读取 + 短信读取（只读）——Dart 侧桥接（0.75.0 · W6/G9）
///
/// 设计原则（逐一镜像 `device_control_service.dart`，零架构创新）：
/// 1. **分级可用**：store 渠道构建里原生 `status().supported == false`，
///    所有调用安全降级为"当前版本不支持"，绝不抛异常给用户；
/// 2. **默认关闭**：必须主人在设置页显式打开总开关，工具才会注册；
/// 3. **只读铁律**：本文件只有"读"的入口——没有任何 send / write / reply；
/// 4. **不落库**：通知只在原生侧的内存环缓冲里，短信按需向系统 provider 查；
///    本层不写数据库、不写文件，**永远不持久化通知/短信正文**；
/// 5. **不回外网**：这里一个字节都不发往任何服务器（不查、不缓存、不上传）；
/// 6. **全程可审计**：每次调用只落"条数/时间窗"这类元数据进 agent_actions，
///    正文一律不进任何持久化日志面（与审计脱敏同一条纪律）。
///
/// ★ 与手机控制（无障碍）的关键差异：通知读取靠用户在**系统「通知使用权」**
///   里手动勾选，App 无法代开 ⇒ UI 只能给"去系统设置"，不能给"一键开启"。
/// ============================================================
class NotifySmsStatus {
  /// 本安装包是否带这套能力（= 是否 sideload 渠道构建）
  final bool supported;

  /// 通知监听服务是否在清单里声明（渠道决定，非用户决定）
  final bool listenerDeclared;

  /// 系统设置「通知使用权」里是否已勾选本应用
  final bool listenerEnabled;

  /// 服务是否已被系统绑定（能不能真的收到通知）
  final bool listenerConnected;

  /// READ_SMS 是否在清单里声明（渠道决定）
  final bool smsDeclared;

  /// READ_SMS 是否已获用户授权
  final bool smsGranted;

  final String message;

  const NotifySmsStatus({
    required this.supported,
    required this.listenerDeclared,
    required this.listenerEnabled,
    required this.listenerConnected,
    required this.smsDeclared,
    required this.smsGranted,
    required this.message,
  });

  /// 通知读取是否真的可用（勾选只是前提，服务连上才算能干活）
  bool get notificationsReady => listenerEnabled && listenerConnected;

  /// 短信读取是否真的可用
  bool get smsReady => smsGranted;

  /// 任一通道可用 ⇒ 值得挂载工具
  bool get anyReady => notificationsReady || smsReady;

  static NotifySmsStatus get unsupported => NotifySmsStatus(
        supported: false,
        listenerDeclared: false,
        listenerEnabled: false,
        listenerConnected: false,
        smsDeclared: false,
        smsGranted: false,
        message: L10nHolder.l10n.notifySmsStatusUnsupportedFull,
      );
}

/// 一条通知（内存快照，不含任何持久化身份）
class NotifyItem {
  final String packageName;
  final String appLabel;
  final String title;
  final String text;
  final String subText;
  final String category;
  final int postTimeMs;
  final bool ongoing;

  const NotifyItem({
    required this.packageName,
    required this.appLabel,
    required this.title,
    required this.text,
    required this.subText,
    required this.category,
    required this.postTimeMs,
    required this.ongoing,
  });

  static NotifyItem fromMap(Map<Object?, Object?> m) => NotifyItem(
        packageName: (m['packageName'] ?? '').toString(),
        appLabel: (m['appLabel'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        text: (m['text'] ?? '').toString(),
        subText: (m['subText'] ?? '').toString(),
        category: (m['category'] ?? '').toString(),
        postTimeMs: (m['postTime'] is num)
            ? (m['postTime'] as num).toInt()
            : 0,
        ongoing: m['ongoing'] == true,
      );

  /// 给模型看的一行紧凑描述（时间戳由工具层按当前时区渲染）
  String toLine({required String time}) {
    final who = appLabel.isNotEmpty ? appLabel : packageName;
    final body = [title, text]
        .where((s) => s.trim().isNotEmpty)
        .join(' · ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final t = body.length > 120 ? '${body.substring(0, 120)}…' : body;
    return '[$time] $who: $t${subText.isEmpty ? '' : '（$subText）'}';
  }
}

/// 一条短信（按需从系统 provider 读出，本层不留存）
class SmsItem {
  final String address;
  final String body;
  final int dateMs;
  final bool read;

  /// 1=收件箱 2=已发送 3=草稿 4=发件箱 5=失败 6=待发
  final int type;

  const SmsItem({
    required this.address,
    required this.body,
    required this.dateMs,
    required this.read,
    required this.type,
  });

  static SmsItem fromMap(Map<Object?, Object?> m) => SmsItem(
        address: (m['address'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        dateMs: (m['dateMs'] is num) ? (m['dateMs'] as num).toInt() : 0,
        read: m['read'] == true,
        type: (m['type'] is num) ? (m['type'] as num).toInt() : 0,
      );

  String get boxLabel {
    switch (type) {
      case 2:
        return '已发送';
      case 3:
        return '草稿';
      case 4:
        return '发件箱';
      case 5:
        return '发送失败';
      case 6:
        return '待发送';
      default:
        return read ? '收件箱' : '未读';
    }
  }

  String toLine({required String time}) {
    final who = address.trim().isEmpty ? '(未知号码)' : address.trim();
    final t = body.length > 160 ? '${body.substring(0, 160)}…' : body;
    return '[$time] $who · $boxLabel：${t.replaceAll(RegExp(r'\s+'), ' ')}';
  }
}

class NotificationSmsService {
  NotificationSmsService._();

  static const MethodChannel _channel = MethodChannel('dahuang/notify_sms');

  /// 总开关（主人显式打开后才会注册相关工具）。
  ///
  /// ★ 常量名刻意**不叫** `enabledPref`：`DeviceControlService` 已占用了这个名字。
  ///   两个类各有一个 `enabledPref` 会在 `verify_data_keys`（存储键接线守卫）里
  ///   撞出"常量名歧义" —— 守卫的规则是"名字唯一才解析，否则记为盲区"，
  ///   歧义会把**既有** device_control 的解析一起打回盲区 ⇒ 等于悄悄削弱既有守卫。
  ///   改名消歧既让守卫保持最强，也免去两个同名常量在 grep 时互相干扰。
  static const String notifySmsEnabledPref = 'notify_sms_enabled';

  /// 单次读取的最大条数上限（防一次读回整台手机的短信把上下文撑爆）
  static const int maxLimit = 100;

  // ------------------------------------------------------------------
  // 状态与开关
  // ------------------------------------------------------------------

  static Future<NotifySmsStatus> status() async {
    final l10n = L10nHolder.l10n;
    try {
      final r = await _channel.invokeMethod<Map<Object?, Object?>>('status');
      if (r == null) return NotifySmsStatus.unsupported;
      final supported = r['supported'] == true;
      final listenerDeclared = r['listenerDeclared'] == true;
      final listenerEnabled = r['listenerEnabled'] == true;
      final listenerConnected = r['listenerConnected'] == true;
      final smsDeclared = r['smsDeclared'] == true;
      final smsGranted = r['smsGranted'] == true;

      final bool notifyReady = listenerEnabled && listenerConnected;
      final String message;
      if (!supported) {
        message = l10n.notifySmsStatusUnsupportedFull;
      } else if (notifyReady && smsGranted) {
        message = l10n.notifySmsStatusReady;
      } else if (notifyReady || smsGranted) {
        message = l10n.notifySmsStatusPartial;
      } else {
        message = l10n.notifySmsStatusOff;
      }

      return NotifySmsStatus(
        supported: supported,
        listenerDeclared: listenerDeclared,
        listenerEnabled: listenerEnabled,
        listenerConnected: listenerConnected,
        smsDeclared: smsDeclared,
        smsGranted: smsGranted,
        message: message,
      );
    } on MissingPluginException {
      // 通道不存在（例如某些平台的构建里没编进原生代码）⇒ 安全降级
      return NotifySmsStatus.unsupported;
    } on PlatformException catch (e) {
      AppLogger.w('notify_sms.status', e);
      return NotifySmsStatus(
        supported: false,
        listenerDeclared: false,
        listenerEnabled: false,
        listenerConnected: false,
        smsDeclared: false,
        smsGranted: false,
        message: l10n.notifySmsStatusQueryFailed('${e.message}'),
      );
    } catch (e) {
      AppLogger.w('notify_sms.status', e);
      return NotifySmsStatus.unsupported;
    }
  }

  /// 跳转系统「通知使用权」设置页（**无法在 App 内代开**，只能跳转）
  static Future<bool> openListenerSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } catch (e) {
      AppLogger.w('notify_sms.openSettings', e);
      return false;
    }
  }

  /// 申请 READ_SMS 运行时权限（仅 sideload 渠道会真的弹窗；其余返回 false）
  static Future<bool> requestSms() async {
    try {
      return await _channel.invokeMethod<bool>('requestSms') ?? false;
    } catch (e) {
      AppLogger.w('notify_sms.requestSms', e);
      return false;
    }
  }

  static Future<bool> isUserEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notifySmsEnabledPref) ?? false;
  }

  static Future<void> setUserEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notifySmsEnabledPref, value);
    // 关闭时顺手清空原生侧的内存缓冲 —— 贯彻"按需读取、不留痕"
    if (!value) await clearNotifications();
  }

  // ------------------------------------------------------------------
  // 只读读取（本文件**没有**任何写/发入口，这是刻意的）
  // ------------------------------------------------------------------

  /// 读取最近的通知（来自原生内存环缓冲；未连上 ⇒ 空表）
  static Future<List<NotifyItem>> listNotifications({
    int sinceMs = 0,
    int limit = 50,
  }) async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'listNotifications',
        {'sinceMs': sinceMs, 'limit': limit.clamp(1, maxLimit)},
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(NotifyItem.fromMap)
          .toList();
    } catch (e) {
      AppLogger.w('notify_sms.listNotifications', e);
      return const [];
    }
  }

  /// 读取短信（按需向系统 provider 查；未授权 ⇒ 空表）
  static Future<List<SmsItem>> listSms({
    int sinceMs = 0,
    int limit = 50,
  }) async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'listSms',
        {'sinceMs': sinceMs, 'limit': limit.clamp(1, maxLimit)},
      );
      if (raw == null) return const [];
      return raw.whereType<Map<Object?, Object?>>().map(SmsItem.fromMap).toList();
    } catch (e) {
      AppLogger.w('notify_sms.listSms', e);
      return const [];
    }
  }

  /// 清空原生侧的内存环缓冲（关闭开关 / 用户主动清理时调用）
  static Future<void> clearNotifications() async {
    try {
      await _channel.invokeMethod<bool>('clearNotifications');
    } catch (e) {
      AppLogger.w('notify_sms.clear', e);
    }
  }

  // ------------------------------------------------------------------
  // 脱敏（纯函数，供工具层与单测共用）
  // ------------------------------------------------------------------

  /// 验证码打码：**必须带标签前缀**才判定，绝不裸匹配连续数字。
  ///
  /// ★ 与 `PiiDetector` 修"裸 6 位数字误杀邮编"同一条教训（2026-10-07）：
  ///   短信里到处都是数字（快递单号、金额、日期），裸 `\d{4,8}` 会把正常
  ///   内容全打码 ⇒ 工具输出对模型毫无价值。故只认"标签 + 数字"。
  static final RegExp _otpLabeled = RegExp(
    r'(?:验证码|校验码|动态码|验证代码|verification\s*code|verify\s*code|'
    r'one[-\s]?time\s*(?:code|password)|otp|security\s*code)'
    r'[^\d\n]{0,8}(\d{4,8})(?!\d)',
    caseSensitive: false,
  );

  /// 通知/短信正文出站前的脱敏：
  /// ① 复用全局 `PiiDetector.maskSensitive`（手机号/邮箱/身份证/银行卡/微信号）；
  /// ② 追加验证码打码（短信场景特有，且同样遵循"标签+数字"纪律）。
  static String redactSensitive(String raw) {
    if (raw.isEmpty) return raw;
    var text = PiiDetector.maskSensitive(raw);
    text = text.replaceAllMapped(_otpLabeled, (m) {
      final g = m.group(0)!;
      final code = m.group(1)!;
      final idx = g.lastIndexOf(code);
      if (idx < 0) return '****';
      return '${g.substring(0, idx)}****';
    });
    return text;
  }
}
