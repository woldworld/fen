import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'l10n_holder.dart';

/// ============================================================
/// 手机控制通道（无障碍）——Dart 侧桥接
///
/// 设计原则（对齐 dsh 生态 Android 项目的经验，但更保守）：
/// 1. **分级可用**：没装无障碍服务的构建里，所有调用都安全降级为
///    "当前版本不支持"，绝不抛异常给用户；
/// 2. **默认关闭**：必须主人在设置页显式打开总开关，工具才会注册；
/// 3. **危险应用黑名单**：银行/支付类 App 在前台时拒绝执行任何操作；
/// 4. **全程可审计**：每个动作都会写进 agent_actions 供回看。
/// ============================================================
class DeviceControlStatus {
  /// 平台通道是否存在（即当前安装包是否带了无障碍服务）
  final bool supported;

  /// 无障碍服务是否已真正连上（= 能不能干活）
  final bool enabled;

  /// 系统设置里是否已勾选本应用的无障碍服务（排查用，与 [enabled] 解耦）
  final bool systemEnabled;

  final String message;

  const DeviceControlStatus({
    required this.supported,
    required this.enabled,
    this.systemEnabled = false,
    required this.message,
  });

  static DeviceControlStatus get unsupported => DeviceControlStatus(
        supported: false,
        enabled: false,
        systemEnabled: false,
        message: L10nHolder.l10n.deviceControlStatusUnsupportedFull,
      );
}

/// 屏幕上的一个可读/可点元素
class ScreenNode {
  final String text;
  final String className;
  final int x1;
  final int y1;
  final int x2;
  final int y2;
  final bool clickable;
  final bool editable;

  const ScreenNode({
    required this.text,
    required this.className,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.clickable,
    required this.editable,
  });

  int get centerX => (x1 + x2) ~/ 2;
  int get centerY => (y1 + y2) ~/ 2;

  /// 给模型看的一行紧凑描述（坐标即点击点，省 token）
  String toLine() {
    final flags = <String>[
      if (clickable) '可点',
      if (editable) '可输入',
    ].join('/');
    final t = text.length > 60 ? '${text.substring(0, 60)}…' : text;
    return '$t  [$centerX,$centerY]  ${className.split('.').last}'
        '${flags.isEmpty ? '' : '  ($flags)'}';
  }
}

class DeviceControlService {
  DeviceControlService._();

  static const MethodChannel _channel = MethodChannel('dahuang/device_control');

  /// 总开关（主人显式打开后才会注册相关工具）
  static const String enabledPref = 'device_control_enabled';

  /// 危险应用黑名单（命中即拒绝操作）
  static const String denylistPref = 'device_control_denylist';

  /// 默认黑名单：银行 / 支付 / 密码管理器——智能体永远不碰
  static const List<String> defaultDenylist = [
    'com.android.settings', // 系统设置：误操作代价高，默认拦截
    'com.eg.android.AlipayGphone', // 支付宝
    'com.tencent.mm', // 微信（含支付）
    'com.unionpay',
    'com.icbc',
    'com.ccb.longjiLife',
    'com.chinamworld.main',
    'com.bankcomm',
    'com.cmbchina.ccd.pluto.cmbActivity',
    'com.antfortune.wealth',
    'com.tencent.mobileqq',
    'com.onepassword.android',
    'com.lastpass.lpandroid',
  ];

  // ------------------------------------------------------------------
  // 状态与开关
  // ------------------------------------------------------------------

  static Future<DeviceControlStatus> status() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('status');
      if (result == null) return DeviceControlStatus.unsupported;
      final supported = result['supported'] == true;
      final enabled = result['enabled'] == true;
      final systemEnabled = result['systemEnabled'] == true;
      return DeviceControlStatus(
        supported: supported,
        enabled: enabled,
        systemEnabled: systemEnabled,
        message: enabled
            ? L10nHolder.l10n.deviceControlStatusReady
            : (!supported
                ? L10nHolder.l10n.deviceControlStatusUnsupportedShort
                : (systemEnabled
                    ? L10nHolder.l10n.deviceControlStatusCheckedOffline
                    : L10nHolder.l10n.deviceControlStatusOff)),
      );
    } on MissingPluginException {
      return DeviceControlStatus.unsupported;
    } on PlatformException catch (e) {
      AppLogger.w('device.status', e);
      return DeviceControlStatus(
          supported: false,
          enabled: false,
          systemEnabled: false,
          message: L10nHolder.l10n.deviceControlStatusQueryFailed('${e.message}'));
    } catch (e) {
      AppLogger.w('device.status', e);
      return DeviceControlStatus.unsupported;
    }
  }

  /// 跳转到系统无障碍设置页，让用户手动开启
  static Future<bool> openAccessibilitySettings() async {
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } catch (e) {
      AppLogger.w('device.openSettings', e);
      return false;
    }
  }

  static Future<bool> isUserEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledPref) ?? false;
  }

  static Future<void> setUserEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledPref, value);
  }

  // ------------------------------------------------------------------
  // 屏幕读取与操作
  // ------------------------------------------------------------------

  /// 读取当前屏幕元素（供模型理解界面）
  static Future<List<ScreenNode>> readScreen() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('dumpUi');
      if (raw == null) return const [];
      return raw.whereType<Map<Object?, Object?>>().map((m) {
        int asInt(Object? v) => (v is num) ? v.toInt() : 0;
        return ScreenNode(
          text: (m['text'] ?? '').toString(),
          className: (m['className'] ?? '').toString(),
          x1: asInt(m['x1']),
          y1: asInt(m['y1']),
          x2: asInt(m['x2']),
          y2: asInt(m['y2']),
          clickable: m['clickable'] == true,
          editable: m['editable'] == true,
        );
      }).toList();
    } catch (e) {
      AppLogger.w('device.dumpUi', e);
      return const [];
    }
  }

  static Future<bool> tap({int? x, int? y}) async {
    try {
      return await _channel.invokeMethod<bool>('tap', {'x': x, 'y': y}) ?? false;
    } catch (e) {
      AppLogger.w('device.tap', e);
      return false;
    }
  }

  static Future<bool> swipe({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    int durationMs = 300,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('swipe', {
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
            'durationMs': durationMs,
          }) ??
          false;
    } catch (e) {
      AppLogger.w('device.swipe', e);
      return false;
    }
  }

  static Future<bool> inputText(String text) async {
    try {
      return await _channel
              .invokeMethod<bool>('inputText', {'text': text}) ??
          false;
    } catch (e) {
      AppLogger.w('device.inputText', e);
      return false;
    }
  }

  /// key: back / home / recents / enter
  static Future<bool> pressKey(String key) async {
    try {
      return await _channel.invokeMethod<bool>('pressKey', {'key': key}) ?? false;
    } catch (e) {
      AppLogger.w('device.pressKey', e);
      return false;
    }
  }

  static Future<bool> launchApp(String packageName) async {
    try {
      return await _channel
              .invokeMethod<bool>('launchApp', {'package': packageName}) ??
          false;
    } catch (e) {
      AppLogger.w('device.launchApp', e);
      return false;
    }
  }

  /// 当前前台应用包名（用于危险应用拦截）
  static Future<String> currentPackage() async {
    try {
      return await _channel.invokeMethod<String>('currentPackage') ?? '';
    } catch (e) {
      AppLogger.w('device.currentPackage', e);
      return '';
    }
  }

  // ------------------------------------------------------------------
  // 危险应用黑名单
  // ------------------------------------------------------------------

  static Future<List<String>> denylist() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(denylistPref);
    if (stored == null) return List<String>.from(defaultDenylist);
    return stored;
  }

  static Future<void> setDenylist(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(denylistPref, list);
  }

  static Future<bool> isSensitivePackage(String packageName) async {
    if (packageName.isEmpty) return false;
    final list = await denylist();
    for (final blocked in list) {
      if (packageName == blocked ||
          packageName.startsWith('$blocked.') ||
          packageName.contains(blocked)) {
        return true;
      }
    }
    return false;
  }

  /// 执行任何动作前的守卫：危险应用直接拒绝，并给出可读原因
  static Future<String?> guardCurrentApp() async {
    final pkg = await currentPackage();
    if (pkg.isEmpty) return null;
    if (await isSensitivePackage(pkg)) {
      return L10nHolder.l10n.deviceControlGuardBlocked(pkg);
    }
    return null;
  }
}
