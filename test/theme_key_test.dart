// 主题色名归一（0.80.0）。
//
// 真机复现的缺陷：主人说「改成粉色主题」，而色板里没有"粉" ⇒ 旧实现把脏值
// 照写 prefs、照回"已改好"，`setTheme` 对未知键**静默 return** ⇒ 主题没变、
// 系统谎报成功。本文件钉住**唯一的判据** `themeKeyOrNull`：
//   · 认得的（含中文名与等价别名）→ 稳定 key；
//   · 认不出的 → **null**（调用方据此报错，绝不静默近似）。
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/theme_provider.dart';

void main() {
  group('themeKeyOrNull / themeKeys（色名归一唯一事实源）', () {
    test('稳定 key 逐一同名解析', () {
      for (final k in themeKeys) {
        expect(themeKeyOrNull(k), k, reason: '稳定键 $k 必须原样认得');
      }
    });

    test('色板稳定 key 恰为 9 个（别名不进色板）', () {
      expect(themeKeys.length, 9);
      expect(themeKeys, containsAll(<String>[
        'red', 'orange', 'yellow', 'green', 'cyan', 'blue', 'purple', 'white', 'black',
      ]));
    });

    test('遗留中文色名归一', () {
      expect(themeKeyOrNull('红'), 'red');
      expect(themeKeyOrNull('橙'), 'orange');
      expect(themeKeyOrNull('黄'), 'yellow');
      expect(themeKeyOrNull('绿'), 'green');
      expect(themeKeyOrNull('青'), 'cyan');
      expect(themeKeyOrNull('蓝'), 'blue');
      expect(themeKeyOrNull('紫'), 'purple');
      expect(themeKeyOrNull('白'), 'white');
      expect(themeKeyOrNull('黑'), 'black');
    });

    test('★ 粉色别名 → red（真机用例：主人要的就是"粉色"）', () {
      expect(themeKeyOrNull('粉'), 'red');
      expect(themeKeyOrNull('粉色'), 'red');
      expect(themeKeyOrNull('pink'), 'red');
      expect(themeKeyOrNull('PINK'), 'red');
      expect(themeKeyOrNull(' rose '), 'red');
    });

    test('大小写与空白容错（英文键名）', () {
      expect(themeKeyOrNull('  Blue '), 'blue');
      expect(themeKeyOrNull('WHITE'), 'white');
    });

    test('★ 认不出必须是 null —— 不许悄悄兜底成某个色', () {
      expect(themeKeyOrNull('青色'), isNull); // 只是"青"才认
      expect(themeKeyOrNull('teal'), isNull);
      expect(themeKeyOrNull('彩虹色'), isNull);
      expect(themeKeyOrNull(''), isNull);
      expect(themeKeyOrNull('   '), isNull);
    });
  });
}
