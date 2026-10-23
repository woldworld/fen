/// 层 2：国产 ROM 保活引导 —— 识别厂商 + 跳转自启动设置页 + 引导状态。
///
/// 为什么必须有这一层：前台服务（FGS）在原生 Android 上够用，但 MIUI/
/// 鸿蒙/ColorOS/OriginOS 有**自己的**杀后台逻辑——没开"自启动 + 省电
/// 无限制"的分身，息屏后几分钟就被 ROM 收走，与权限授权无关。
/// 这是国内市场每一家具保活能力的 App 都要交的学费，本模块把学费变成
/// 一段用户看得懂的引导：检测厂商 → 给分机型步骤 → 一键跳设置页。
///
/// 职责边界：
/// * 厂商分类 [classifyVendor] 是**纯函数**（字符串进，枚举出）——单测钉死；
/// * 跳转走 MethodChannel（`dahuang/rom`），组件候选随 ROM 版本漂移，
///   所以原生侧逐一尝试、失败兜底应用详情页（见 MainActivity.kt）；
/// * 引导展示纪律：**同一厂商只强提醒一次**（用户可"不再提醒"），
///   之后入口常驻 设置 → 值班权限，不反复打扰。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ROM 厂商家族（自启动设置页的组织方式以此为粒度）。
enum RomVendor {
  xiaomi, // 小米 / 红米（MIUI / HyperOS）
  huawei, // 华为（EMUI / HarmonyOS）
  honor, // 荣耀（MagicOS，与华为同源不同包名）
  oppo, // OPPO / realme（ColorOS）
  oneplus, // 一加（ColorOS / OxygenOS）
  vivo, // vivo / iQOO（OriginOS / Funtouch）
  meizu, // 魅族（Flyme）
  samsung, // 三星（One UI，有深度休眠列表，分量较轻）
  generic, // 其他 / 原生 Android（无强杀传统，无引导）
}

abstract final class RomGuide {
  static const MethodChannel _channel = MethodChannel('dahuang/rom');
  static const String _dismissedKeyPrefix = 'rom_guide_dismissed_';

  static RomVendor? _cachedVendor;

  // ------------------------------------------------------------------
  // 厂商分类（纯函数——单测钉死，别让"redmi 算不算小米"在线上现猜）
  // ------------------------------------------------------------------

  /// 把 manufacturer/brand 归到厂商家族。大小写不敏感；brand 主要兜
  /// "manufacturer=Xiaomi 但 brand=Redmi/REDMI_K60" 这类写法。
  static RomVendor classifyVendor(String manufacturer, String brand) {
    final m = manufacturer.toLowerCase();
    final b = brand.toLowerCase();
    bool has(String needle) => m.contains(needle) || b.contains(needle);
    // honor 必须在 huawei 之前：荣耀机的 manufacturer 可能仍报 HUAWEI
    if (has('honor')) return RomVendor.honor;
    if (has('huawei')) return RomVendor.huawei;
    if (has('xiaomi') || has('redmi')) return RomVendor.xiaomi;
    if (has('oneplus')) return RomVendor.oneplus;
    if (has('realme') || has('oppo')) return RomVendor.oppo;
    if (has('iqoo') || has('vivo')) return RomVendor.vivo;
    if (has('meizu')) return RomVendor.meizu;
    if (has('samsung')) return RomVendor.samsung;
    return RomVendor.generic;
  }

  /// 该厂商是否值得引导（原生/海外 ROM 无强杀传统，不打扰）。
  static bool vendorNeedsGuide(RomVendor v) => v != RomVendor.generic;

  // ------------------------------------------------------------------
  // 检测与跳转（MethodChannel）
  // ------------------------------------------------------------------

  /// 检测当前厂商（结果缓存——ROM 不会在进程存活期内变）。
  /// 通道不可用（测试/非 Android 平台）时返回 [RomVendor.generic]。
  static Future<RomVendor> detectVendor() async {
    final cached = _cachedVendor;
    if (cached != null) return cached;
    RomVendor v;
    try {
      final info = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getRomInfo');
      v = classifyVendor(
        (info?['manufacturer'] ?? '').toString(),
        (info?['brand'] ?? '').toString(),
      );
    } on PlatformException {
      v = RomVendor.generic;
    } on MissingPluginException {
      v = RomVendor.generic;
    }
    _cachedVendor = v;
    return v;
  }

  /// 跳转厂商自启动设置页。返回 false = 连兜底页都没打开成。
  static Future<bool> openAutoStartSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAutoStartSettings') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // 引导状态（同一厂商只强提醒一次）
  // ------------------------------------------------------------------

  static Future<bool> shouldShowGuide() async {
    final v = await detectVendor();
    if (!vendorNeedsGuide(v)) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_dismissedKeyPrefix${v.name}') != true;
  }

  static Future<void> markGuideDismissed() async {
    final v = await detectVendor();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_dismissedKeyPrefix${v.name}', true);
  }

  /// 测试辅助：清空厂商缓存（mock 通道换"设备"时用）。
  @visibleForTesting
  static void resetVendorCache() => _cachedVendor = null;
}
