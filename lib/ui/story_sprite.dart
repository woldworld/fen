import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme_provider.dart';
import '../data/story_theater.dart';

/// 官网 `--paper-alt` / `--ink`（landing/src/style.css:11-52）的**中性**取值：
/// 蛋壳与五官不跟主题 accent 跑，只分明暗两档 —— 与任意主题渐变都百搭。
const Color _kPaperLight = Color(0xFFF7F5F2);
const Color _kPaperDark = Color(0xFF161A21);
const Color _kInkLight = Color(0xFF16181D);
const Color _kInkDark = Color(0xFFE8EAF0);

/// 一个部件的落笔方案：画法（[SpritePartSpec]，纯数据）+ 颜色（按主题解析）。
class SpritePaint {
  const SpritePaint({required this.spec, required this.fill, this.stroke});

  final SpritePartSpec spec;
  final Color fill;

  /// [SpritePartSpec.stroke] 为 false 时为 null。
  final Color? stroke;
}

/// 按主题解析每个部件的颜色（官网 CSS 变量 → App 映射：accent 一律取
/// [ThemeProvider.accentColor]，`--accent-soft` / `--glow-warm` 由它派生）。
///
/// 单独成函数（而不是塞进 painter）是为了让单测能直接断言明暗两套取色。
Map<SpritePart, SpritePaint> resolveSpritePaints(
  StorySpriteState state, {
  required bool isDark,
  required Color accent,
}) {
  final paper = isDark ? _kPaperDark : _kPaperLight;
  final ink = isDark ? _kInkDark : _kInkLight;
  // --accent-soft：accent 18% 罩在纸面上；--glow-warm：accent 的暖色薄纱
  //（仅 alert 态本体填充；官网明暗分别 0.20 / 0.12）。
  final accentSoft = Color.alphaBlend(accent.withValues(alpha: 0.18), paper);
  final glowWarm = accent.withValues(alpha: isDark ? 0.20 : 0.12);

  Color fillOf(SpritePart part) {
    switch (part) {
      case SpritePart.shell:
        return paper;
      case SpritePart.crack:
        return accent;
      case SpritePart.orb:
        return state == StorySpriteState.alert ? glowWarm : accentSoft;
      case SpritePart.tail:
        return accent.withValues(alpha: 0.45);
      case SpritePart.shine:
        return const Color(0xFFFFFFFF).withValues(alpha: 0.32);
      case SpritePart.eye:
      case SpritePart.brow:
      case SpritePart.mouth:
        return ink;
    }
  }

  final out = <SpritePart, SpritePaint>{};
  for (final part in SpritePart.values) {
    final spec = spritePartSpec(part, state);
    out[part] = SpritePaint(
      spec: spec,
      fill: fillOf(part),
      // 官网里 shell/crack/orb 的描边是 accent，五官描边是 ink。
      stroke: !spec.stroke
          ? null
          : (part == SpritePart.shell || part == SpritePart.crack || part == SpritePart.orb
              ? accent
              : ink),
    );
  }
  return out;
}

/// 章回剧场蛋精灵（小荒）：0.98.0 官网 → 0.100.0 App 首启序幕的头图。
///
/// - 三态：蛋 →（点击孵化）→ 精灵；alert 供撤回演示卡的坏消息时刻；
/// - 几何与官网 SVG 逐字节同构（[spriteShapes]，守卫反向断言），**零新依赖**：
///   CustomPainter 手绘，不引 flutter_svg / rive / lottie；
/// - 颜色取 [ThemeProvider]（明暗两套，承 R27）；
/// - 孵化 = 蛋放大淡出 + 精灵 pop 淡入（~300ms）；待机浮动承官网 `sp-float`
///   （3.6s 往返 -7px，viewBox 单位），alert 时冻结；系统「移除动画」时全静。
class StorySprite extends StatefulWidget {
  const StorySprite({
    super.key,
    required this.state,
    this.size = 132,
    this.onTap,
  });

  /// 当前三态。
  final StorySpriteState state;

  /// 蛋宽（viewBox 120×130 等比，高 = size × 130/120）。
  final double size;

  /// 点蛋回调（序幕用来孵化 + 聚焦起名框）。
  final VoidCallback? onTap;

  @override
  State<StorySprite> createState() => _StorySpriteState();
}

class _StorySpriteState extends State<StorySprite> with TickerProviderStateMixin {
  /// 孵化 crossfade 进度：0 = 只有蛋，1 = 精灵完全显形。
  late final AnimationController _hatch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// 待机浮动（官网 sp-float：3.6s 往返，repeat + reverse）。
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    // 非蛋态（重跑引导且 soul_* 有回填，见移植方案 F14）直接显形，不重放孵化。
    if (widget.state != StorySpriteState.egg) {
      _hatch.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFloat();
  }

  @override
  void didUpdateWidget(covariant StorySprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == widget.state) return;
    if (widget.state == StorySpriteState.egg) {
      _hatch.value = 0;
    } else if (oldWidget.state == StorySpriteState.egg) {
      // egg → 任何非蛋态（hatched / alert）都播放孵化 crossfade。
      _hatch.forward(from: 0);
    } else {
      // hatched ↔ alert：瞬间切换，不重放孵化。
      _hatch.value = 1;
    }
    _syncFloat();
  }

  void _syncFloat() {
    final frozen = widget.state == StorySpriteState.alert ||
        MediaQuery.of(context).disableAnimations;
    if (frozen) {
      if (_float.isAnimating) _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _hatch.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final paints = resolveSpritePaints(
      widget.state,
      isDark: theme.isDark,
      accent: theme.accentColor,
    );
    final frozen = widget.state == StorySpriteState.alert ||
        MediaQuery.of(context).disableAnimations;
    final sprite = AnimatedBuilder(
      animation: Listenable.merge([_hatch, _float]),
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size * spriteViewBoxHeight / spriteViewBoxWidth),
        painter: _StorySpritePainter(
          state: widget.state,
          hatch: _hatch.value,
          floatT: frozen ? 0 : Curves.easeInOut.transform(_float.value),
          paints: paints,
        ),
      ),
    );
    if (widget.onTap == null) return sprite;
    return GestureDetector(onTap: widget.onTap, child: sprite);
  }
}

class _StorySpritePainter extends CustomPainter {
  const _StorySpritePainter({
    required this.state,
    required this.hatch,
    required this.floatT,
    required this.paints,
  });

  final StorySpriteState state;

  /// 孵化 crossfade 进度（0..1）。
  final double hatch;

  /// 浮动进度（0..1，已过 easeInOut；冻结时为 0）。
  final double floatT;

  final Map<SpritePart, SpritePaint> paints;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / spriteViewBoxWidth;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final floatDy = -7 * floatT; // 官网 sp-float：translateY(0 → -7px)
    switch (state) {
      case StorySpriteState.egg:
        _paintLayer(canvas, scale, cx, cy + floatDy, 1, 1, StorySpriteState.egg);
      case StorySpriteState.hatched:
      case StorySpriteState.alert:
        // hatched 与 alert 共用壳（尾+本体+高光），差别在五官（spriteShapes 分层）。
        if (hatch < 1) {
          // 蛋：随孵化放大并淡出。
          _paintLayer(
            canvas,
            scale,
            cx,
            cy + floatDy * (1 - hatch),
            1 + 0.12 * hatch,
            1 - hatch,
            StorySpriteState.egg,
          );
        }
        // 精灵：pop 入场（elasticOut 收尾）。
        _paintLayer(
          canvas,
          scale,
          cx,
          cy + floatDy,
          0.55 + 0.45 * Curves.elasticOut.transform(hatch),
          hatch,
          state,
        );
    }
  }

  void _paintLayer(
    Canvas canvas,
    double scale,
    double cx,
    double cy,
    double layerScale,
    double alpha,
    StorySpriteState layerState,
  ) {
    if (alpha <= 0.01) return;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale * layerScale);
    canvas.translate(-spriteViewBoxWidth / 2, -spriteViewBoxHeight / 2);
    for (final shape in spriteShapes(layerState)) {
      final paint = paints[shape.part];
      if (paint == null) continue;
      final spec = paint.spec;
      final path = _shapePath(shape);
      if (spec.fill) {
        canvas.drawPath(path, Paint()..color = _alpha(paint.fill, alpha));
      }
      if (spec.stroke && paint.stroke != null) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = spec.strokeWidth
            ..strokeCap = spec.roundCap ? StrokeCap.round : StrokeCap.butt
            ..strokeJoin = spec.roundJoin ? StrokeJoin.round : StrokeJoin.miter
            ..color = _alpha(paint.stroke!, alpha),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StorySpritePainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.hatch != hatch ||
      oldDelegate.floatT != floatT ||
      oldDelegate.paints != paints;
}

/// 几何 → dart:ui Path（viewBox 单位，缩放交给 canvas transform）。
Path _shapePath(SpriteShape shape) {
  switch (shape.kind) {
    case SpriteShapeKind.ellipse:
      return Path()
        ..addOval(Rect.fromLTRB(
          shape.cx - shape.rx,
          shape.cy - shape.ry,
          shape.cx + shape.rx,
          shape.cy + shape.ry,
        ));
    case SpriteShapeKind.circle:
      return Path()..addOval(Rect.fromCircle(center: Offset(shape.cx, shape.cy), radius: shape.rx));
    case SpriteShapeKind.path:
      final path = Path();
      for (final cmd in parseSvgPath(shape.d)) {
        switch (cmd.op) {
          case 'M':
            path.moveTo(cmd.args[0], cmd.args[1]);
          case 'L':
            path.lineTo(cmd.args[0], cmd.args[1]);
          case 'C':
            path.cubicTo(cmd.args[0], cmd.args[1], cmd.args[2], cmd.args[3], cmd.args[4], cmd.args[5]);
          case 'Q':
            path.quadraticBezierTo(cmd.args[0], cmd.args[1], cmd.args[2], cmd.args[3]);
          case 'Z':
            path.close();
        }
      }
      return path;
  }
}

/// 显式按 alpha 通道相乘（`withValues(alpha:)` 是绝对赋值，
/// 这里先取现值再乘，保证 0.45 的尾鳍再叠 0.5 淡出 = 0.225）。
Color _alpha(Color color, double alpha) =>
    color.withValues(alpha: (color.a * alpha).clamp(0.0, 1.0));
