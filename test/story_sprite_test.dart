// 章回剧场蛋精灵（0.98.0 官网 → 0.100.0 App 首启序幕）批次①单测。
//
// 三类判据：
// ① **几何同构**：`spriteShapes()` 还原的元素串与 landing/build.js:143-164 的
//    `spriteArt()` 逐字节一致（下面期望值是钉死的原文；运行时还有
//    `tool/verify_story_prologue.dart` 拿 build.js 活原文反向断言）；
// ② **解析器正确**：隐式重复 / 负号连写 / 相对命令 / 多子路径 / z 回起点；
// ③ **三态与主题可构造**：egg/hatched/alert 都能画出，明暗两套取色不同，
//    孵化动画可推进、点蛋回调透传。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dahuang_ai/core/theme_provider.dart';
import 'package:dahuang_ai/data/story_theater.dart';
import 'package:dahuang_ai/ui/story_sprite.dart';

const Color _kAccent = Color(0xFFd81b60);

Widget _wrap(Widget child, {ThemeProvider? theme}) {
  return ChangeNotifierProvider<ThemeProvider>.value(
    value: theme ?? ThemeProvider(),
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

/// 期望值按官网原文的整数写法（Dart 的 41.0.toString() 是 "41.0"）。
String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

void main() {
  group('① 几何同构（与官网 build.js spriteArt 逐字节一致）', () {
    test('egg：蛋壳 + 裂纹', () {
      expect(
        spriteShapes(StorySpriteState.egg).map((s) => s.svgElement()).toList(),
        <String>[
          '<ellipse class="sp-shell" cx="60" cy="66" rx="33" ry="41"/>',
          '<path class="sp-crack" d="M41 52l13 11-9 12 15 8-11 14"/>',
        ],
      );
    });

    test('hatched：尾 + 本体 + 高光 + 圆眼×2 + 微笑', () {
      expect(
        spriteShapes(StorySpriteState.hatched).map((s) => s.svgElement()).toList(),
        <String>[
          '<path class="sp-tail" d="M62 94c-15 13-24 7-28 20 13-3 20-9 28-20z"/>',
          '<ellipse class="sp-orb" cx="60" cy="58" rx="37" ry="34"/>',
          '<ellipse class="sp-shine" cx="45" cy="45" rx="11" ry="7"/>',
          '<circle class="sp-eye" cx="48" cy="56" r="6"/>',
          '<circle class="sp-eye" cx="74" cy="56" r="6"/>',
          '<path class="sp-mouth" d="M52 72q8 6 16 0"/>',
        ],
      );
    });

    test('alert：hatched 壳 + 一字眼 + 倒眉 + 撇嘴', () {
      expect(
        spriteShapes(StorySpriteState.alert).map((s) => s.svgElement()).toList(),
        <String>[
          '<path class="sp-tail" d="M62 94c-15 13-24 7-28 20 13-3 20-9 28-20z"/>',
          '<ellipse class="sp-orb" cx="60" cy="58" rx="37" ry="34"/>',
          '<ellipse class="sp-shine" cx="45" cy="45" rx="11" ry="7"/>',
          '<path class="sp-eye" d="M41 56h14M67 56h14"/>',
          '<path class="sp-brow" d="M40 46l14 6M68 46l12 6"/>',
          '<path class="sp-mouth" d="M52 74q8-5 16 0"/>',
        ],
      );
    });

    test('整数坐标不带 .0（同构前提：Dart 60.0.toString() 是 "60.0"）', () {
      for (final state in StorySpriteState.values) {
        for (final shape in spriteShapes(state)) {
          expect(shape.svgElement(), isNot(contains('.0"')));
        }
      }
    });

    test('viewBox 常量承官网 120×130', () {
      expect(spriteViewBoxWidth, 120);
      expect(spriteViewBoxHeight, 130);
    });
  });

  group('② SVG 路径解析（官网用到的命令子集）', () {
    String fmt(SvgPathCmd c) => '${c.op}(${c.args.map(_n).join(',')})';

    test('裂纹：负号连写的隐式 l 重复', () {
      final cmds = parseSvgPath('M41 52l13 11-9 12 15 8-11 14');
      expect(cmds.map(fmt).toList(), <String>[
        'M(41,52)',
        'L(54,63)',
        'L(45,75)',
        'L(60,83)',
        'L(49,97)',
      ]);
    });

    test('尾：隐式 c 重复 + z 回子路径起点', () {
      final cmds = parseSvgPath('M62 94c-15 13-24 7-28 20 13-3 20-9 28-20z');
      expect(cmds.map(fmt).toList(), <String>[
        'M(62,94)',
        'C(47,107,38,101,34,114)',
        'C(47,111,54,105,62,94)',
        'Z()',
      ]);
    });

    test('微笑/撇嘴：相对 q', () {
      expect(parseSvgPath('M52 72q8 6 16 0').map(fmt).toList(), ['M(52,72)', 'Q(60,78,68,72)']);
      expect(parseSvgPath('M52 74q8-5 16 0').map(fmt).toList(), ['M(52,74)', 'Q(60,69,68,74)']);
    });

    test('一字眼 / 倒眉：h 绝对化 + 多 M 子路径', () {
      expect(parseSvgPath('M41 56h14M67 56h14').map(fmt).toList(), [
        'M(41,56)',
        'L(55,56)',
        'M(67,56)',
        'L(81,56)',
      ]);
      expect(parseSvgPath('M40 46l14 6M68 46l12 6').map(fmt).toList(), [
        'M(40,46)',
        'L(54,52)',
        'M(68,46)',
        'L(80,52)',
      ]);
    });

    test('每个部件的 d 都能被解析且非空', () {
      for (final state in StorySpriteState.values) {
        for (final shape in spriteShapes(state)) {
          if (shape.kind != SpriteShapeKind.path) continue;
          final cmds = parseSvgPath(shape.d);
          expect(cmds, isNotEmpty, reason: '${shape.svgElement()} 应解析出指令');
          expect(cmds.first.op, 'M');
        }
      }
    });

    test('坏输入显式抛错，绝不静默跳过', () {
      expect(() => parseSvgPath(''), throwsFormatException);
      expect(() => parseSvgPath('12 34'), throwsFormatException); // 缺起始命令
      expect(() => parseSvgPath('M10'), throwsFormatException); // 数字个数不整（缺 y）
      expect(() => parseSvgPath('M10 10A5 5 0 0 1 20 20'), throwsFormatException); // 不支持的 A
      expect(() => parseSvgPath('M10 10 L'), throwsFormatException); // 字母顶替数字
    });
  });

  group('③ 性格骰子（纯函数）', () {
    test('五等分 + 边界 + 越界夹紧 + NaN 兜底', () {
      expect(rollTraitIndex(0.0), 0);
      expect(rollTraitIndex(0.199), 0);
      expect(rollTraitIndex(0.2), 1);
      expect(rollTraitIndex(0.4), 2);
      expect(rollTraitIndex(0.6), 3);
      expect(rollTraitIndex(0.8), 4);
      expect(rollTraitIndex(0.999), 4);
      expect(rollTraitIndex(1.0), 4);
      expect(rollTraitIndex(-0.5), 0);
      expect(rollTraitIndex(double.nan), 0);
    });

    test('千次穷举：5 条性格都掷得到（无死档）', () {
      final seen = <int>{};
      for (var i = 0; i < 1000; i++) {
        seen.add(rollTraitIndex(i / 1000));
      }
      expect(seen.length, storyTraits.length);
    });
  });

  group('④ 画法承官网 CSS（.sp-* 规则）', () {
    test('shell/crack/orb 填充+描边；tail/shine 只填充', () {
      expect(spritePartSpec(SpritePart.shell, StorySpriteState.egg).fill, isTrue);
      expect(spritePartSpec(SpritePart.shell, StorySpriteState.egg).strokeWidth, 2);
      expect(spritePartSpec(SpritePart.crack, StorySpriteState.egg).fill, isFalse);
      expect(spritePartSpec(SpritePart.crack, StorySpriteState.egg).strokeWidth, 2.4);
      expect(spritePartSpec(SpritePart.crack, StorySpriteState.egg).roundJoin, isTrue);
      expect(spritePartSpec(SpritePart.orb, StorySpriteState.hatched).strokeWidth, 2);
      expect(spritePartSpec(SpritePart.tail, StorySpriteState.hatched).stroke, isFalse);
      expect(spritePartSpec(SpritePart.shine, StorySpriteState.hatched).stroke, isFalse);
    });

    test('hatched 圆眼填充；alert 一字眼/倒眉改描边圆帽', () {
      expect(spritePartSpec(SpritePart.eye, StorySpriteState.hatched).fill, isTrue);
      expect(spritePartSpec(SpritePart.eye, StorySpriteState.hatched).stroke, isFalse);
      expect(spritePartSpec(SpritePart.eye, StorySpriteState.alert).fill, isFalse);
      expect(spritePartSpec(SpritePart.eye, StorySpriteState.alert).strokeWidth, 3.4);
      expect(spritePartSpec(SpritePart.eye, StorySpriteState.alert).roundCap, isTrue);
      expect(spritePartSpec(SpritePart.brow, StorySpriteState.alert).strokeWidth, 3);
      expect(spritePartSpec(SpritePart.mouth, StorySpriteState.hatched).roundCap, isTrue);
    });
  });

  group('⑤ 主题取色（明暗两套，accent 派生）', () {
    test('纸/墨分明暗；裂纹描边走 accent', () {
      final light = resolveSpritePaints(StorySpriteState.hatched, isDark: false, accent: _kAccent);
      final dark = resolveSpritePaints(StorySpriteState.hatched, isDark: true, accent: _kAccent);
      expect(light[SpritePart.shell]!.fill, const Color(0xFFF7F5F2));
      expect(dark[SpritePart.shell]!.fill, const Color(0xFF161A21));
      expect(light[SpritePart.eye]!.fill, const Color(0xFF16181D));
      expect(dark[SpritePart.eye]!.fill, const Color(0xFFE8EAF0));
      expect(light[SpritePart.crack]!.stroke, _kAccent);
      expect(light[SpritePart.orb]!.stroke, _kAccent);
      // 尾 = accent 45% 薄纱（alpha 折半）。
      expect((light[SpritePart.tail]!.fill.a * 255).round(), (_kAccent.a * 255 * 0.45).round());
      // 高光 = 白 32%。
      expect((light[SpritePart.shine]!.fill.a * 255).round(), (255 * 0.32).round());
    });

    test('alert 态 orb 换暖色薄纱，且与 hatched 不同', () {
      final hatched = resolveSpritePaints(StorySpriteState.hatched, isDark: false, accent: _kAccent);
      final alert = resolveSpritePaints(StorySpriteState.alert, isDark: false, accent: _kAccent);
      expect(alert[SpritePart.orb]!.fill, isNot(hatched[SpritePart.orb]!.fill));
      // 官网明暗 alpha 0.20 / 0.12。
      final darkAlert = resolveSpritePaints(StorySpriteState.alert, isDark: true, accent: _kAccent);
      expect((darkAlert[SpritePart.orb]!.fill.a * 255).round(), (_kAccent.a * 255 * 0.20).round());
      expect((alert[SpritePart.orb]!.fill.a * 255).round(), (_kAccent.a * 255 * 0.12).round());
    });

    test('stroke 为 false 的部件 stroke 解析为 null', () {
      final p = resolveSpritePaints(StorySpriteState.hatched, isDark: false, accent: _kAccent);
      expect(p[SpritePart.tail]!.stroke, isNull);
      expect(p[SpritePart.shine]!.stroke, isNull);
      expect(p[SpritePart.eye]!.stroke, isNull); // hatched 圆眼只填充
    });
  });

  group('⑥ 撤回演示卡语义下标', () {
    test('坏消息行下标 = 1（story.json undo.badLine = lines[1]）', () {
      expect(storyUndoBadLineIndex, 1);
    });
  });

  group('⑦ 控件：三态可构造 / 孵化动画 / 点蛋回调 / 暗色 / 移除动画', () {
    testWidgets('三态均可绘制，无异常', (tester) async {
      for (final state in StorySpriteState.values) {
        await tester.pumpWidget(_wrap(StorySprite(state: state)));
        expect(tester.takeException(), isNull, reason: '$state 绘制不得抛错');
      }
      await tester.pumpWidget(const SizedBox()); // 卸载，停掉浮动 ticker
    });

    testWidgets('egg → hatched 触发 ~300ms crossfade 并可推进到稳定', (tester) async {
      await tester.pumpWidget(_wrap(const StorySprite(state: StorySpriteState.egg)));
      await tester.pumpWidget(_wrap(const StorySprite(state: StorySpriteState.hatched)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      // hatched → alert → hatched：直接显形，不重放孵化。
      await tester.pumpWidget(_wrap(const StorySprite(state: StorySpriteState.alert)));
      await tester.pump();
      await tester.pumpWidget(_wrap(const StorySprite(state: StorySpriteState.hatched)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('onTap 透传（点蛋孵化由序幕接线）', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(StorySprite(
        state: StorySpriteState.egg,
        onTap: () => taps++,
      )));
      await tester.tap(find.byType(StorySprite));
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('暗色主题下蛋可绘制', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final theme = ThemeProvider();
      await theme.setTheme('blue'); // blue = dark 主题
      expect(theme.isDark, isTrue);
      await tester.pumpWidget(_wrap(
        const StorySprite(state: StorySpriteState.hatched),
        theme: theme,
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('系统移除动画时 float 冻结、仍可绘制', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: ChangeNotifierProvider<ThemeProvider>.value(
          value: ThemeProvider(),
          child: MaterialApp(
            home: Scaffold(body: StorySprite(state: StorySpriteState.hatched)),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
