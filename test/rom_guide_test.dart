import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/rom_guide_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RomGuide.classifyVendor（纯函数——厂商分类是引导正确性的地基）', () {
    test('主流国产厂商各归各家', () {
      expect(RomGuide.classifyVendor('Xiaomi', 'Mi 13'), RomVendor.xiaomi);
      expect(RomGuide.classifyVendor('Xiaomi', '221113C'), RomVendor.xiaomi);
      expect(RomGuide.classifyVendor('Redmi', 'M2012K11AC'), RomVendor.xiaomi,
          reason: '红米机的 manufacturer 常直接报 Redmi');
      expect(RomGuide.classifyVendor('HUAWEI', 'Mate60'), RomVendor.huawei);
      expect(RomGuide.classifyVendor('HONOR', 'Magic5'), RomVendor.honor);
      expect(RomGuide.classifyVendor('OPPO', 'Find X7'), RomVendor.oppo);
      expect(RomGuide.classifyVendor('realme', 'GT5'), RomVendor.oppo,
          reason: 'realme 用 ColorOS，归 OPPO 家族');
      expect(RomGuide.classifyVendor('OnePlus', 'Ace3'), RomVendor.oneplus);
      expect(RomGuide.classifyVendor('vivo', 'X100'), RomVendor.vivo);
      expect(RomGuide.classifyVendor('iQOO', 'Neo9'), RomVendor.vivo);
      expect(RomGuide.classifyVendor('Meizu', '21'), RomVendor.meizu);
      expect(RomGuide.classifyVendor('samsung', 'S24'), RomVendor.samsung);
    });

    test('大小写与乱序不敏感', () {
      expect(RomGuide.classifyVendor('xiaomi', 'REDMI K60'), RomVendor.xiaomi);
      expect(RomGuide.classifyVendor('HUAWEI', 'HONOR'), RomVendor.honor,
          reason: '荣耀机的 manufacturer 可能仍报 HUAWEI——honor 判定必须在前');
    });

    test('未知厂商与空值归 generic（不引导、不打扰）', () {
      expect(RomGuide.classifyVendor('Google', 'Pixel 9'), RomVendor.generic);
      expect(RomGuide.classifyVendor('Sony', 'XQ'), RomVendor.generic);
      expect(RomGuide.classifyVendor('', ''), RomVendor.generic);
      expect(RomGuide.vendorNeedsGuide(RomVendor.generic), isFalse);
      expect(RomGuide.vendorNeedsGuide(RomVendor.xiaomi), isTrue);
    });
  });

  group('RomGuide 引导状态（同一厂商只强提醒一次）', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      RomGuide.resetVendorCache();
      // 测试桩：模拟一台小米机（分类走真实代码，通道只桩 ROM 信息）
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dahuang/rom'), (call) async {
        if (call.method == 'getRomInfo') {
          return {'manufacturer': 'Xiaomi', 'brand': 'M2012K11AC', 'model': 'K60'};
        }
        if (call.method == 'openAutoStartSettings') return true;
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dahuang/rom'), null);
      RomGuide.resetVendorCache();
    });

    test('未提醒过 → shouldShow 为 true；markDismissed 后为 false', () async {
      expect(await RomGuide.shouldShowGuide(), isTrue);
      await RomGuide.markGuideDismissed();
      expect(await RomGuide.shouldShowGuide(), isFalse);
    });

    test('dismiss 标记按厂商隔离：小米的 dismiss 不影响华为键', () async {
      await RomGuide.markGuideDismissed();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('rom_guide_dismissed_xiaomi'), isTrue);
      expect(prefs.getBool('rom_guide_dismissed_huawei'), isNull);
    });

    test('generic 厂商（如 Pixel）不触发引导', () async {
      RomGuide.resetVendorCache();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dahuang/rom'), (call) async {
        if (call.method == 'getRomInfo') {
          return {'manufacturer': 'Google', 'brand': 'Pixel 9', 'model': 'Pixel 9'};
        }
        return null;
      });
      expect(await RomGuide.shouldShowGuide(), isFalse);
    });

    test('通道不可用（非 Android 平台）→ generic，不引导不崩', () async {
      RomGuide.resetVendorCache();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dahuang/rom'), (call) async {
        throw MissingPluginException();
      });
      expect(await RomGuide.detectVendor(), RomVendor.generic);
      expect(await RomGuide.shouldShowGuide(), isFalse);
    });
  });
}
