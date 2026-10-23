/// 主聊天窗口的常驻悬浮小精灵 —— **柴犬小黄狗**（取自 `assets/app_icon.png`），
/// 用**有语义的犬类体态**替代通用转圈 loading。
///
/// ---------------------------------------------------------------------------
/// 逐条对应需求
/// ---------------------------------------------------------------------------
/// · **形象来自图标**：橙黄背毛 + 米白面罩/胸腹/四爪 + 竖立三角耳 + 圆黑鼻 +
///   吐舌笑口 + 上卷蓬松尾。配色见 [_Dog]，与 `assets/app_icon.png` 对齐。
/// · **轻量**：两个 [AnimationController]（[_ChatSpriteState._ticker] 走姿态循环、
///   [_ChatSpriteState._blend] 走阶段切换插值）+ 一个 [CustomPainter]，不引 Rive/Lottie/
///   图片资源（整个文件只 import `dart:math` 与 `material`，零资产、零额外包体）。
///   ★ 因为用了**两个** controller，State 必须 mix in [TickerProviderStateMixin]；
///   用 [SingleTickerProviderStateMixin] 会在 debug 下直接抛
///   "multiple tickers were created"（由 `tool/verify_chat_sprite.dart` G 组钉住）。
/// · **不遮挡**：待机时整棵子树挂 [IgnorePointer] ⇒ **完全不参与命中测试**，
///   不会吃掉消息区的滚动/点击；只有主人按住它时才接管手势。位置由调用方
///   （`chat_screen`）夹在消息区一角，天然不压输入框。
/// · **有语义**（犬类体态天然适合表达状态，不再靠"换个颜色 + 头顶个道具"）：
///   思考 = **歪头** + 思考泡；检索 = **竖耳前倾 + 双眼左右扫 + 放大镜**；
///   工具 = 前爪举高转齿轮；成功 = **跳起、大张嘴吐舌、尾巴狂摇** + 对勾；
///   出错 = **耳朵全耷、尾巴垂下、闭嘴** + 感叹号；打断 = 变暗、耳朵半耷。
/// · **平滑过渡**：换阶段时在 [_blendMs] 内对**姿态参数**做插值（[Pose._lerp]），
///   不做"先消失再出现"的硬切。
///
/// ---------------------------------------------------------------------------
/// ⚠️ 一条硬纪律：UI 不给假状态（R14）
/// ---------------------------------------------------------------------------
/// 本文件只负责"把阶段画出来"。**谁能进入 `searching` / `tooling` 由真实信号说了算**
/// —— 即 `lib/core/app_events.dart` 的 [AgentActivityEvent]，由 `AgentService`
/// 在**真的**开始检索、**真的**在跑工具时发出。
///
/// 因此：
/// · [SpritePhase.writing] 是**为流式输出预留的**。当前 `AgentService.sendMessage`
///   是一次性 await（拿到的就是完整回复），**没有增量输出** ⇒ 这条链路上
///   `writing` 不会被发出。留着它是因为"能力已实现"与"使用者知道"是两件事，
///   先把绘制能力备好，等流式管线接上时**不需要再改 UI**。
/// · 绝不用"按秒数轮换阶段"来假装忙碌 —— 那会让主人看到"正在检索"而实际什么都没查。
///
/// ★ 改这个文件时的**唯一陷阱**：给 [Pose] 加字段后**必须同步加进 [Pose._lerp]**，
///   否则该参数在阶段切换时永远停在起点值（不报错、不崩溃、只是"这个动作不生效"）。
///   这条由 `tool/verify_chat_sprite.dart` 断言钉住。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 小精灵的语义阶段。
enum SpritePhase {
  /// 待机：没有任务在跑。呼吸 + 眨眼 + 轻摇尾 + 微吐舌。
  idle,

  /// 思考：模型推理中。歪头 + 头顶思考气泡。
  thinking,

  /// 检索：正在查记忆 / 搜索。竖耳前倾 + 双眼扫视 + 放大镜。
  searching,

  /// 写作：正在组织文字输出。前爪持笔书写。（**待流式管线接入**，见文件头）
  writing,

  /// 工具：正在执行工具调用。前爪举高转齿轮。
  tooling,

  /// 成功：任务完成。跳起 + 张嘴吐舌 + 尾巴狂摇 + 对勾。
  success,

  /// 出错：失败。耳朵全耷 + 尾巴垂下 + 闭嘴 + 感叹号。
  error,

  /// 打断：任务被中断。垂手、变暗、耳朵半耷。
  interrupted,
}

/// 附加道具。**按 [Pose._lerp] 的 `t < 0.5` 硬切**（道具是叠加物，
/// 做形状插值只会让它变成一团糊，反而更难看）。
enum SpriteProp { none, thoughtDots, magnifier, pen, gear, check, alert }

/// 柴犬配色。取值对齐 `assets/app_icon.png`（暖橙背毛 / 米白面罩 / 深棕耳内）。
abstract final class _Dog {
  /// 主体背毛（暖橙黄）。
  static const Color fur = Color(0xFFE3A25F);

  /// 背毛暗部（下巴/身侧收边）。
  static const Color furDark = Color(0xFFC8803C);

  /// 背毛高光（头顶受光）。
  static const Color furLight = Color(0xFFF3C88F);

  /// 米白：面罩 / 胸腹 / 四爪 / 尾尖。
  static const Color cream = Color(0xFFFBF3E6);

  /// 米白暗部（爪与胸腹的转折）。
  static const Color creamShade = Color(0xFFE6D5BC);

  /// 耳内（深棕）。
  static const Color innerEar = Color(0xFF8D5A38);

  /// 眼 / 鼻（近黑暖调）。
  static const Color ink = Color(0xFF2A211C);

  /// 舌头。
  static const Color tongue = Color(0xFFEE8D9A);

  /// 舌中缝。
  static const Color tongueDark = Color(0xFFD2707F);

  /// 口腔。
  static const Color mouth = Color(0xFF5A2E30);
}

/// 一组姿态参数。所有"某个阶段长什么样"都收敛成这张表，
/// 于是过渡只需要对这些**数值**插值，不必写 8×8 种切换分支。
///
/// ★ 加字段 ⇒ **必须同步加进 [Pose._lerp]**（守卫会红）。
@immutable
class Pose {
  const Pose({
    this.bobAmp = 0,
    this.bobSpeed = 1,
    this.lean = 0,
    this.eyeScan = 0,
    this.armSwing = 0,
    this.squash = 0,
    this.blink = 1,
    this.glow = 0,
    this.dim = 1,
    this.earPerk = 1,
    this.earTilt = 0,
    this.headTilt = 0,
    this.tail = 1,
    this.wag = 0.35,
    this.mouthOpen = 0.45,
    this.pawLift = 0,
    this.tint = const Color(0xFF6C8CFF),
    this.prop = SpriteProp.none,
  });

  /// 上下浮动幅度（逻辑像素）。
  final double bobAmp;

  /// 浮动频率倍率（1 = 一个 [_ChatSpriteState._cycle] 走一个来回）。
  final double bobSpeed;

  /// 身体前倾弧度。
  final double lean;

  /// 双眼左右扫动幅度（-1..1 的倍率）。
  final double eyeScan;

  /// 前爪摆动幅度（弧度）。
  final double armSwing;

  /// 呼吸/挤压幅度（0..0.12）。
  final double squash;

  /// 眼睛睁开程度（0=闭，1=全开）。眨眼就是把中间帧压到 0。
  final double blink;

  /// 头顶光晕强度（0..1）。成功/出错时给一点环境反馈。
  final double glow;

  /// 整体不透明度。被打断时降到 0.5（"蔫了"）。
  final double dim;

  /// 耳朵竖立程度：1 = 竖直（警觉/好奇），0 = 完全向后耷拉（认错/低落）。
  final double earPerk;

  /// 耳朵额外外撇弧度（正值 = 向两侧张开，配合警觉）。
  final double earTilt;

  /// 歪头弧度（正 = 向右歪）。思考时的招牌动作。
  final double headTilt;

  /// 尾巴姿态：1 = 上卷（自信/开心），0 = 垂到地面（沮丧）。
  final double tail;

  /// 摇尾幅度（0 = 不摇）。成功时最大。
  final double wag;

  /// 张嘴程度：0 = 闭嘴（含浅浅的 ^ 嘴角），1 = 大张嘴吐长舌。
  final double mouthOpen;

  /// 前爪抬起程度（0 = 落地，1 = 举到胸前）。跳起/持物时用。
  final double pawLift;

  /// 强调色（项圈 / 光晕 / 道具的主色）。
  final Color tint;

  /// 道具。
  final SpriteProp prop;

  /// 姿态插值。用于阶段切换时的平滑过渡。
  ///
  /// ★★ **每个 [Pose] 字段都必须在这里出现一次** —— 漏掉的那个参数会在阶段
  /// 切换时静静地"不动"（既不报错也不崩溃），由 `tool/verify_chat_sprite.dart` 钉住。
  static Pose _lerp(Pose a, Pose b, double t) => Pose(
        bobAmp: a.bobAmp + (b.bobAmp - a.bobAmp) * t,
        bobSpeed: a.bobSpeed + (b.bobSpeed - a.bobSpeed) * t,
        lean: a.lean + (b.lean - a.lean) * t,
        eyeScan: a.eyeScan + (b.eyeScan - a.eyeScan) * t,
        armSwing: a.armSwing + (b.armSwing - a.armSwing) * t,
        squash: a.squash + (b.squash - a.squash) * t,
        blink: a.blink + (b.blink - a.blink) * t,
        glow: a.glow + (b.glow - a.glow) * t,
        dim: a.dim + (b.dim - a.dim) * t,
        earPerk: a.earPerk + (b.earPerk - a.earPerk) * t,
        earTilt: a.earTilt + (b.earTilt - a.earTilt) * t,
        headTilt: a.headTilt + (b.headTilt - a.headTilt) * t,
        tail: a.tail + (b.tail - a.tail) * t,
        wag: a.wag + (b.wag - a.wag) * t,
        mouthOpen: a.mouthOpen + (b.mouthOpen - a.mouthOpen) * t,
        pawLift: a.pawLift + (b.pawLift - a.pawLift) * t,
        tint: Color.lerp(a.tint, b.tint, t) ?? b.tint,
        prop: t < 0.5 ? a.prop : b.prop,
      );
}

/// 阶段 → 姿态。**唯一事实源**：加阶段只改这里。
Pose poseFor(SpritePhase phase) {
  switch (phase) {
    case SpritePhase.idle:
      return const Pose(
        bobAmp: 2.5, bobSpeed: 0.5, squash: 0.035,
        earPerk: 0.9, tail: 1.0, wag: 0.35, mouthOpen: 0.45,
        tint: Color(0xFF6C8CFF),
      );
    case SpritePhase.thinking:
      return const Pose(
        bobAmp: 5.0, bobSpeed: 1.0, lean: -0.05, squash: 0.05,
        glow: 0.35, earPerk: 1.0, headTilt: 0.22, tail: 0.92, wag: 0.2,
        mouthOpen: 0.15, tint: Color(0xFF9B6CFF), prop: SpriteProp.thoughtDots,
      );
    case SpritePhase.searching:
      return const Pose(
        bobAmp: 3.0, bobSpeed: 1.6, lean: 0.08, eyeScan: 1.0, squash: 0.03,
        glow: 0.2, earPerk: 1.0, earTilt: 0.28, tail: 1.0, wag: 0.5,
        mouthOpen: 0.12, tint: Color(0xFF2FB6C9), prop: SpriteProp.magnifier,
      );
    case SpritePhase.writing:
      return const Pose(
        bobAmp: 1.6, bobSpeed: 2.2, lean: 0.14, armSwing: 0.5, squash: 0.02,
        earPerk: 0.88, tail: 0.85, wag: 0.3, mouthOpen: 0.08, pawLift: 0.72,
        tint: Color(0xFF3FAE6A), prop: SpriteProp.pen,
      );
    case SpritePhase.tooling:
      return const Pose(
        bobAmp: 2.0, bobSpeed: 2.6, armSwing: 1.0, squash: 0.04,
        glow: 0.25, earPerk: 0.95, tail: 1.0, wag: 0.7, mouthOpen: 0.25,
        pawLift: 0.5, tint: Color(0xFFE0902F), prop: SpriteProp.gear,
      );
    case SpritePhase.success:
      return const Pose(
        bobAmp: 8.0, bobSpeed: 1.2, squash: 0.08,
        glow: 0.6, earPerk: 1.0, earTilt: -0.14, tail: 1.0, wag: 1.6,
        mouthOpen: 1.0, pawLift: 1.0,
        tint: Color(0xFF3FAE6A), prop: SpriteProp.check,
      );
    case SpritePhase.error:
      return const Pose(
        bobAmp: 1.2, bobSpeed: 0.8, lean: -0.2, eyeScan: 0,
        glow: 0.45, dim: 0.85, earPerk: 0.0, earTilt: -0.05,
        tail: 0.0, wag: 0, mouthOpen: 0.0,
        tint: Color(0xFFD8544F), prop: SpriteProp.alert,
      );
    case SpritePhase.interrupted:
      return const Pose(
        bobAmp: 0.6, bobSpeed: 0.4, lean: 0.05, armSwing: -0.35,
        dim: 0.5, earPerk: 0.28, tail: 0.15, wag: 0.12, mouthOpen: 0.05,
        tint: Color(0xFF8A8F98),
      );
  }
}

/// 常驻悬浮小精灵（柴犬）。
///
/// 用法：`ChatSprite(phase: _phase, accent: theme.accentColor)`。
/// 位置/手势由调用方包一层 [ChatSpriteOverlay]（见本文件末尾）决定。
class ChatSprite extends StatefulWidget {
  const ChatSprite({super.key, required this.phase, this.size = 64, this.accent});

  /// 当前语义阶段。变化时会做姿态插值过渡。
  final SpritePhase phase;

  /// 绘制尺寸（逻辑像素，正方形）。
  final double size;

  /// 主题强调色 —— 用在小狗的**项圈**上（让精灵与 App 主题同色）。
  /// 为 null 时用 [_fallbackAccent]。
  final Color? accent;

  static const Color _fallbackAccent = Color(0xFF6C8CFF);

  @override
  State<ChatSprite> createState() => _ChatSpriteState();
}

class _ChatSpriteState extends State<ChatSprite>
    with TickerProviderStateMixin {
  /// 姿态循环时长。各阶段靠 `Pose.bobSpeed` 倍率在这个周期内快慢不同。
  static const Duration _cycle = Duration(milliseconds: 2400);

  /// 阶段切换的姿态插值时长。
  static const int _blendMs = 320;

  late final AnimationController _ticker;
  late final AnimationController _blend;

  /// 过渡的起点姿态（切换瞬间冻结住的"现在"）。
  Pose _from = poseFor(SpritePhase.idle);
  Pose _to = poseFor(SpritePhase.idle);

  /// 眨眼调度：下一个眨眼时刻（毫秒，相对 [_ticker] 的累计时间）。
  double _nextBlinkAt = 1.5;

  @override
  void initState() {
    super.initState();
    _to = poseFor(widget.phase);
    _from = _to;
    _ticker = AnimationController(vsync: this, duration: _cycle)..repeat();
    _blend = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _blendMs),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant ChatSprite old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) {
      // 起点取**当前实际姿态**（而不是旧阶段的表值）⇒ 连续快速切换也不会跳。
      _from = _effectivePose();
      _to = poseFor(widget.phase);
      _blend
        ..value = 0
        ..forward();
      // 待机时会话结束：把眨眼节奏重置，避免带着上一阶段的时间戳。
      if (widget.phase == SpritePhase.idle) _nextBlinkAt = 1.5;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _blend.dispose();
    super.dispose();
  }

  /// 当前实际姿态 = 起点与目标按 [_blend] 插值。
  Pose _effectivePose() {
    final t = Curves.easeOutCubic.transform(_blend.value.clamp(0.0, 1.0));
    return t >= 1.0 ? _to : Pose._lerp(_from, _to, t);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? ChatSprite._fallbackAccent;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_ticker, _blend]),
          builder: (context, _) {
            final pose = _effectivePose();
            final blink = _resolveBlink(pose);
            return CustomPaint(
              size: Size.square(widget.size),
              painter: _SpritePainter(
                pose: pose,
                phaseT: _ticker.value,
                blink: blink,
                accent: accent,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 眨眼：只在"眼睛该睁着"的姿态下生效（思考时凝视、出错时半闭都保留姿态语义）。
  double _resolveBlink(Pose pose) {
    final tSec = _ticker.value * (_cycle.inMilliseconds / 1000.0);
    if (tSec >= _nextBlinkAt) {
      _nextBlinkAt = tSec + 2.6 + math.Random(tSec.toInt()).nextDouble() * 2.2;
      return pose.blink;
    }
    // 眨眼窗口 140ms：把前 70ms 闭合、后 70ms 睁开。
    final since = (tSec - (_nextBlinkAt - 2.6));
    if (since >= 0 && since < 0.14) {
      final k = since < 0.07 ? since / 0.07 : (0.14 - since) / 0.07;
      return pose.blink * (1 - k * 0.92);
    }
    return pose.blink;
  }
}

/// 柴犬的画笔。所有几何量都是 `size` 的比例，
/// 原点在**躯干中心**，`+y` 向下。
class _SpritePainter extends CustomPainter {
  _SpritePainter({
    required this.pose,
    required this.phaseT,
    required this.blink,
    required this.accent,
  });

  final Pose pose;

  /// 0..1 的循环进度，乘 `pose.bobSpeed` 得到实际相位。
  final double phaseT;
  final double blink;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s * 0.56;

    // 相位：一个周期走一个来回。
    final w = phaseT * pose.bobSpeed * 2 * math.pi;
    final bob = math.sin(w) * pose.bobAmp;
    final breath = math.sin(w * 1.4);

    // 落地阴影：随浮动变小（离地越高影子越小）。画在世界坐标，不跟着倾斜。
    final lift = (bob / math.max(pose.bobAmp, 0.001)).clamp(-1.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, s * 0.93),
        width: s * 0.40 * (1 - lift * 0.16),
        height: s * 0.058,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.13),
    );

    canvas.save();
    canvas.translate(cx, cy + bob);
    canvas.rotate(pose.lean);

    final sy = 1 - pose.squash * breath;
    final sx = 1 + pose.squash * breath * 0.6;
    canvas.scale(sx, sy);
    canvas.saveLayer(
      Rect.fromCenter(center: Offset.zero, width: s * 2, height: s * 2),
      Paint()..color = Colors.white.withValues(alpha: pose.dim),
    );

    // ── 光晕（成功 / 出错 / 工具期的一点环境反馈） ────────────────────
    if (pose.glow > 0.01) {
      canvas.drawCircle(
        Offset.zero,
        s * 0.44,
        Paint()
          ..color = pose.tint.withValues(alpha: 0.16 * pose.glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.10),
      );
    }

    // 画序（后画者在上）：尾 → 后爪 → 身 → 项圈 → 前爪 → 头 → 耳 → 脸。
    _paintTail(canvas, s, w);
    _paintHindPaws(canvas, s);
    _paintBody(canvas, s);
    _paintCollar(canvas, s);
    _paintFrontLegs(canvas, s, w);
    _paintHead(canvas, s, w);

    canvas.restore(); // saveLayer
    canvas.restore(); // translate/rotate

    _paintProp(canvas, s, cx, cy + bob, w);
  }

  // ────────────────────────────────────────────────────────────── 尾巴
  /// 上卷的蓬松尾（`pose.tail` = 1）↔ 顺后腿垂到地面（0）；`pose.wag` 控制摇动。
  ///
  /// 画在**右侧**（对齐 `assets/app_icon.png` 里那条上卷的米白尾）；
  /// 道具一律放**左侧**（见 [_paintProp]）—— 两边分居，谁也不遮谁。
  ///
  /// ★ 这里唯一要防的观感事故：只"往外抬"的尾巴会被看成**第三条腿**。
  ///   所以尾梢做了**回勾**（cubic 的末段往回走），并用暗边把米白尾从米白后腿上抠出来。
  void _paintTail(Canvas canvas, double s, double w) {
    final t = pose.tail.clamp(0.0, 1.0);
    double mix(double up, double down) => down + (up - down) * t;

    // 尾根贴在后腰右侧。
    final base = Offset(s * 0.134, s * 0.082);
    // 上卷：先甩出去 → 再向上 → 尾梢往回收（这个"回"字是关键）。
    // 垂尾时**不许碰到地面**（碰到了就会被看成第三条腿），所以末段收到 y≈0.22 就停。
    final c1 = Offset(s * mix(0.272, 0.256), s * mix(0.070, 0.132));
    final c2 = Offset(s * mix(0.286, 0.268), s * mix(-0.062, 0.212));
    final tip = Offset(s * mix(0.196, 0.176), s * mix(-0.128, 0.222));

    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, tip.dx, tip.dy);

    canvas.save();
    // 以尾根为轴心摇尾。
    canvas.translate(base.dx, base.dy);
    canvas.rotate(math.sin(w * 3) * pose.wag * 0.26);
    canvas.translate(-base.dx, -base.dy);

    // ① 暗边（把米白尾从米白后腿上"抠"出来）
    canvas.drawPath(
      path,
      Paint()
        ..color = _Dog.furDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.098
        ..strokeCap = StrokeCap.round,
    );
    // ② 主体（米白 —— 柴犬卷尾的招牌色）
    canvas.drawPath(
      path,
      Paint()
        ..color = _Dog.cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.082
        ..strokeCap = StrokeCap.round,
    );
    // ③ 沿尾巴上缘压一道柔光（蓬松感靠"边缘受光"，不靠戳一堆毛球 ——
    //    上一版在曲线外侧点毛团，整条尾巴被点成了毛毛虫）。
    canvas.drawPath(
      path.shift(Offset(-s * 0.009, -s * 0.015)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.026
        ..strokeCap = StrokeCap.round,
    );
    // ④ 尾梢
    canvas.drawCircle(tip, s * 0.044, Paint()..color = _Dog.cream);
    canvas.restore();
  }

  // ────────────────────────────────────────────────────────────── 后爪
  /// 后爪（"白袜子"）放在**外圈**、前腿放在**内圈**，两者不许重叠 ——
  /// 一旦重叠，四条腿就糊成一坨奶油色，看不出是四条。
  void _paintHindPaws(Canvas canvas, double s) {
    for (final side in const [-1.0, 1.0]) {
      final c = Offset(side * s * 0.150, s * 0.254);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: s * 0.118, height: s * 0.096),
        Paint()..color = _Dog.creamShade,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, -s * 0.010),
          width: s * 0.104, height: s * 0.082,
        ),
        Paint()..color = _Dog.cream,
      );
    }
  }

  // ────────────────────────────────────────────────────────────── 躯干
  void _paintBody(Canvas canvas, double s) {
    final rect = Rect.fromCenter(
      center: Offset(0, s * 0.035),
      width: s * 0.330,
      height: s * 0.320,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_Dog.furLight, _Dog.fur, _Dog.furDark],
          stops: <double>[0.0, 0.48, 1.0],
        ).createShader(rect),
    );
    // 米白胸腹（裁进躯干轮廓）
    // 占面积刻意给得大：正视图里**奶油色的胸前+肚子才是主角**，
    // 暖橙留在头、背、两侧 —— 这才对得上 `assets/app_icon.png` 的用色比例。
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * 0.070),
        width: s * 0.246,
        height: s * 0.272,
      ),
      Paint()..color = _Dog.cream,
    );
    canvas.restore();
  }

  // ────────────────────────────────────────────────────────────── 项圈
  /// 用**主题强调色**给小狗戴一条项圈 —— 让精灵与 App 主题同色，
  /// 也让 `accent` 参数保持"真被用上"（不留半接线）。
  void _paintCollar(Canvas canvas, double s) {
    final rect = Rect.fromCenter(
      center: Offset(0, s * -0.048),
      width: s * 0.225,
      height: s * 0.042,
    );
    canvas.drawOval(rect, Paint()..color = Colors.black.withValues(alpha: 0.22));
    canvas.drawOval(
      rect.deflate(s * 0.007),
      Paint()..color = accent,
    );
    // 小圆吊牌
    final tag = Offset(0, s * 0.001);
    canvas.drawCircle(tag, s * 0.026, Paint()..color = const Color(0xFFF5C94A));
    canvas.drawCircle(
      tag,
      s * 0.026,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.007,
    );
  }

  // ────────────────────────────────────────────────────────────── 前爪
  /// 前腿：落地时两列白柱；`pose.pawLift` 抬起时，爪子**向上收 + 略微外张**
  /// （而不是把整条腿缩成一坨）—— 抬到胸前才读得出"举爪"这个动作。
  void _paintFrontLegs(Canvas canvas, double s, double w) {
    final lift = pose.pawLift.clamp(0.0, 1.0);
    final swing = math.sin(w * 2) * pose.armSwing;
    for (final side in const [-1.0, 1.0]) {
      final topX = side * s * 0.062;
      final topY = s * 0.140;
      final pawX = topX + side * s * 0.072 * lift;
      final pawY = s * (0.264 - 0.126 * lift) + swing * s * 0.030;
      // 先描一圈暗边（把米白前腿从米白胸腹上"抠"出来）
      canvas.drawLine(
        Offset(topX, topY),
        Offset(pawX, pawY),
        Paint()
          ..color = _Dog.creamShade
          ..strokeWidth = s * 0.072
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(topX, topY),
        Offset(pawX, pawY),
        Paint()
          ..color = _Dog.cream
          ..strokeWidth = s * 0.056
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ────────────────────────────────────────────────────────────── 头
  void _paintHead(Canvas canvas, double s, double w) {
    canvas.save();
    // 以"脖子"为轴心歪头 + 一点自然的轻摆。
    final pivot = Offset(0, s * -0.060);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(pose.headTilt + math.sin(w * 0.7) * 0.018);
    canvas.translate(-pivot.dx, -pivot.dy);

    _paintEars(canvas, s);
    _paintFace(canvas, s, w);

    canvas.restore();
  }

  /// 三角耳：`pose.earPerk` 1→竖直略外撇，0→向内下耷拉**贴住脑袋**。
  void _paintEars(Canvas canvas, double s) {
    final perk = pose.earPerk.clamp(0.0, 1.0);
    final droop = 1 - perk;
    final h = s * 0.150;
    final halfW = s * 0.058;

    // 圆角三角（尖端收圆、别拉长 —— 拉长了像兔耳）。
    final outer = Path()
      ..moveTo(-halfW, 0)
      ..cubicTo(-halfW * 0.96, -h * 0.60, -halfW * 0.46, -h * 0.94, 0, -h)
      ..cubicTo(halfW * 0.46, -h * 0.94, halfW * 0.96, -h * 0.60, halfW, 0)
      ..close();
    final inner = Path()
      ..moveTo(-halfW * 0.54, -h * 0.13)
      ..cubicTo(-halfW * 0.50, -h * 0.56, -halfW * 0.24, -h * 0.80, 0, -h * 0.84)
      ..cubicTo(halfW * 0.24, -h * 0.80, halfW * 0.50, -h * 0.56, halfW * 0.54, -h * 0.13)
      ..close();

    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      // 耷拉时同时**向内收 + 往下坐**，耳朵才会贴着脑袋（只旋转会张成翅膀）。
      canvas.translate(
        side * s * (0.092 - 0.044 * droop),
        s * (-0.286 + 0.054 * droop),
      );
      canvas.rotate(side * (0.30 + pose.earTilt + 1.05 * droop));
      canvas.drawPath(outer, Paint()..color = _Dog.furDark);
      canvas.drawPath(inner, Paint()..color = _Dog.innerEar);
      canvas.restore();
    }
  }

  /// 脸：头 → 米白面罩 → 眼 → 鼻 → 口/舌。
  void _paintFace(Canvas canvas, double s, double w) {
    final headRect = Rect.fromCenter(
      center: Offset(0, s * -0.215),
      width: s * 0.375,
      height: s * 0.355,
    );
    final head = Path()..addOval(headRect);
    canvas.drawOval(
      headRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_Dog.furLight, _Dog.fur, _Dog.furDark],
          stops: <double>[0.0, 0.52, 1.0],
        ).createShader(headRect),
    );

    // 米白面罩（口鼻 + 两颊），并沿眉间向上收一条窄带 —— 柴犬的招牌分界。
    canvas.save();
    canvas.clipPath(head);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * -0.140),
        width: s * 0.320,
        height: s * 0.200,
      ),
      Paint()..color = _Dog.cream,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-s * 0.028, s * -0.130)
        ..quadraticBezierTo(-s * 0.024, s * -0.215, 0, s * -0.238)
        ..quadraticBezierTo(s * 0.024, s * -0.215, s * 0.028, s * -0.130)
        ..close(),
      Paint()..color = _Dog.cream,
    );
    canvas.restore();

    // ── 眼睛 ────────────────────────────────────────────────────────
    final eyeR = s * 0.028;
    final eyeY = s * -0.246;
    final scan = pose.eyeScan * math.sin(w * 0.9) * s * 0.015;
    for (final side in const [-1.0, 1.0]) {
      final c = Offset(side * s * 0.068 + scan, eyeY);
      if (blink < 0.30) {
        // 闭眼：一条向下的小弧（比"压扁的黑点"更像睡着的狗）。
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - eyeR * 0.95, c.dy)
            ..quadraticBezierTo(c.dx, c.dy + eyeR * 0.95, c.dx + eyeR * 0.95, c.dy),
          Paint()
            ..color = _Dog.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.015
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: c,
            width: eyeR * 2,
            height: eyeR * 2 * blink.clamp(0.30, 1.0),
          ),
          Paint()..color = _Dog.ink,
        );
        canvas.drawCircle(
          c.translate(-eyeR * 0.34, -eyeR * 0.38),
          eyeR * 0.33,
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
      }
    }

    // ── 鼻子（圆角三角） ────────────────────────────────────────────
    final nw = s * 0.064;
    final nh = s * 0.046;
    final nTop = s * -0.198;
    canvas.drawPath(
      Path()
        ..moveTo(-nw / 2, nTop)
        ..quadraticBezierTo(0, nTop - nh * 0.34, nw / 2, nTop)
        ..quadraticBezierTo(nw * 0.32, nTop + nh, 0, nTop + nh)
        ..quadraticBezierTo(-nw * 0.32, nTop + nh, -nw / 2, nTop)
        ..close(),
      Paint()..color = _Dog.ink,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-nw * 0.15, nTop + nh * 0.20),
        width: nw * 0.26,
        height: nh * 0.20,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );

    // ── 口 / 舌 ────────────────────────────────────────────────────
    // 犬科的嘴从鼻子下沿分两瓣（"w"口），张嘴时下缘撑开、露出舌头。
    final mo = pose.mouthOpen.clamp(0.0, 1.0);
    final mTop = s * -0.152;
    final mhw = s * (0.052 + 0.036 * mo);
    final mh = s * (0.032 + 0.058 * mo);
    if (mo < 0.12) {
      // 闭嘴：浅浅的 "w" 嘴角（出错 / 被打断时用）。
      canvas.drawPath(
        Path()
          ..moveTo(-s * 0.050, mTop)
          ..quadraticBezierTo(-s * 0.026, mTop + s * 0.028, 0, mTop + s * 0.004)
          ..quadraticBezierTo(s * 0.026, mTop + s * 0.028, s * 0.050, mTop),
        Paint()
          ..color = _Dog.ink.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.013
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(-mhw, mTop)
          ..quadraticBezierTo(-mhw * 0.88, mTop + mh, 0, mTop + mh)
          ..quadraticBezierTo(mhw * 0.88, mTop + mh, mhw, mTop)
          ..close(),
        Paint()..color = _Dog.mouth,
      );
      // 舌头（长度随张嘴程度；舌尖比舌根略宽一点点）
      final tTop = mTop + mh * 0.30;
      final tH = s * (0.024 + 0.070 * mo);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, tTop + tH * 0.5),
            width: s * (0.052 + 0.014 * mo),
            height: tH,
          ),
          Radius.circular(s * 0.028),
        ),
        Paint()..color = _Dog.tongue,
      );
      canvas.drawLine(
        Offset(0, tTop + tH * 0.24),
        Offset(0, tTop + tH * 0.76),
        Paint()
          ..color = _Dog.tongueDark
          ..strokeWidth = s * 0.010
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// 道具按阶段独立绘制。位置固定在头部周围，不参与浮动（贴在"世界坐标"上更稳）。
  ///
  /// 一律画在**左侧** —— 右侧留给尾巴（[_paintTail]），两边分居不打架。
  /// 实现上用**一次水平镜像**达成，而不是把十几个 offset 逐个取负
  /// （逐个取负一定会漏掉一两个，然后某个道具就悄悄跑到尾巴上去了）。
  void _paintProp(Canvas canvas, double s, double cx, double cy, double w) {
    if (pose.prop == SpriteProp.none) return;
    canvas.save();
    canvas.translate(cx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-cx, 0);
    final c = Offset(cx, cy);

    switch (pose.prop) {
      case SpriteProp.none:
        break;
      case SpriteProp.thoughtDots:
        // 三颗思考泡沿弧线依次亮起（左上，避开耳朵）。
        for (var i = 0; i < 3; i++) {
          final k = ((w / (2 * math.pi)) * 1.0 + i / 3.0) % 1.0;
          final a = 0.25 + 0.75 * (1 - (k * 2 - 1).abs());
          canvas.drawCircle(
            Offset(c.dx + s * (0.16 + i * 0.072), c.dy - s * (0.34 + i * 0.048)),
            s * (0.020 + i * 0.006),
            Paint()..color = pose.tint.withValues(alpha: a.clamp(0.0, 1.0)),
          );
        }
      case SpriteProp.magnifier:
        // 放大镜在脸侧左右扫。
        final scan = math.sin(w * 0.8) * s * 0.10;
        final lens = Offset(c.dx + s * 0.215 + scan, c.dy - s * 0.235);
        canvas.drawCircle(
          lens,
          s * 0.078,
          Paint()
            ..color = pose.tint.withValues(alpha: 0.22)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          lens,
          s * 0.078,
          Paint()
            ..color = pose.tint.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.024,
        );
        canvas.drawLine(
          lens.translate(s * 0.055, s * 0.055),
          lens.translate(s * 0.140, s * 0.140),
          Paint()
            ..color = pose.tint.withValues(alpha: 0.9)
            ..strokeWidth = s * 0.026
            ..strokeCap = StrokeCap.round,
        );
      case SpriteProp.pen:
        // 笔**握在抬起的左前爪里**（不是浮在腰侧 —— 之前那版就飘着）。
        // `writing` 的 pawLift = 0.72 ⇒ 左爪落在躯干 (-0.114, 0.170)；
        // 画笔空间是镜像过的，所以这里写 +0.114 / +0.170。
        final jitter = math.sin(w * 3.4) * s * 0.010;
        final grip = Offset(c.dx + s * 0.114, c.dy + s * 0.170 + jitter);
        canvas.save();
        canvas.translate(grip.dx, grip.dy);
        canvas.rotate(-0.62);
        // 笔身：握点在笔的**上三分之一**，笔尖朝下。
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, s * 0.034), width: s * 0.030, height: s * 0.185),
            Radius.circular(s * 0.012),
          ),
          Paint()..color = pose.tint,
        );
        canvas.drawCircle(
          Offset(0, s * 0.118),
          s * 0.014,
          Paint()..color = _Dog.ink,
        );
        canvas.restore();
        // ★ 握点上再盖一只小爪子 —— 不盖的话笔只是"贴"在腿边，不是"拿"在手里。
        canvas.drawCircle(grip, s * 0.034, Paint()..color = _Dog.creamShade);
        canvas.drawCircle(grip, s * 0.028, Paint()..color = _Dog.cream);
      case SpriteProp.gear:
        // 一个真正在转的齿轮（工具执行）。
        final center = Offset(c.dx + s * 0.255, c.dy - s * 0.205);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(w * 2.2);
        final r = s * 0.072;
        final gear = Paint()..color = pose.tint.withValues(alpha: 0.92);
        for (var i = 0; i < 8; i++) {
          canvas.save();
          canvas.rotate(i * math.pi / 4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(0, -r), width: r * 0.34, height: r * 0.42),
              Radius.circular(r * 0.12),
            ),
            gear,
          );
          canvas.restore();
        }
        canvas.drawCircle(Offset.zero, r * 0.72, gear);
        canvas.drawCircle(
          Offset.zero,
          r * 0.30,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.restore();
      case SpriteProp.check:
        // 对勾，按"写完"的节奏弹出。
        final k = Curves.easeOutBack.transform(
          ((w / (2 * math.pi)) * 1.0 % 1.0).clamp(0.0, 1.0),
        );
        final col = Offset(c.dx + s * 0.235, c.dy - s * 0.315);
        canvas.save();
        canvas.translate(col.dx, col.dy);
        canvas.scale(k.clamp(0.4, 1.15));
        canvas.drawCircle(
          Offset.zero,
          s * 0.082,
          Paint()..color = pose.tint.withValues(alpha: 0.16),
        );
        canvas.drawPath(
          Path()
            ..moveTo(-s * 0.040, 0)
            ..lineTo(-s * 0.010, s * 0.032)
            ..lineTo(s * 0.044, -s * 0.032),
          Paint()
            ..color = pose.tint
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.025
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.restore();
      case SpriteProp.alert:
        // 感叹号（出错）。轻微左右晃，像在说"不行"。
        final shake = math.sin(w * 2.6) * s * 0.012;
        final col = Offset(c.dx + s * 0.245 + shake, c.dy - s * 0.315);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: col.translate(0, -s * 0.008),
              width: s * 0.042,
              height: s * 0.100,
            ),
            Radius.circular(s * 0.021),
          ),
          Paint()..color = pose.tint,
        );
        canvas.drawCircle(
          col.translate(0, s * 0.068),
          s * 0.019,
          Paint()..color = pose.tint,
        );
    }
    canvas.restore(); // 镜像
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) =>
      old.phaseT != phaseT ||
      old.blink != blink ||
      old.accent != accent ||
      old.pose != pose;
}

/// 悬浮层：把小精灵固定在窗口一角，并**只在主人按住它时**接管手势。
///
/// 三条落点（对应"不遮挡输入框和历史消息"）：
/// 1. 待机态整棵子树 [IgnorePointer] ⇒ 滚动、长按、点消息全都不受影响；
/// 2. 拖动被 [Offset] 夹在 `0..bounds` 内，调用方传进来的 bounds 就是**安全区**
///    （`chat_screen` 传消息区尺寸，天然不含输入框）；
/// 3. 松手后若在右半侧则贴右、左半侧则贴左（"跟到一边去"，不留中间挡视线）。
class ChatSpriteOverlay extends StatefulWidget {
  const ChatSpriteOverlay({
    super.key,
    required this.phase,
    this.size = 64,
    this.accent,
    this.onTap,
  });

  final SpritePhase phase;
  final double size;
  final Color? accent;

  /// 点一下的语义（如"展开/收起"）；为 null 时不响应点击。
  final VoidCallback? onTap;

  @override
  State<ChatSpriteOverlay> createState() => _ChatSpriteOverlayState();
}

class _ChatSpriteOverlayState extends State<ChatSpriteOverlay> {
  /// 相对安全区左上角的偏移；null = 尚未摆放（默认贴右下角）。
  Offset? _pos;
  Size _bounds = Size.zero;
  bool _dragging = false;

  static const double _margin = 8;

  /// 待机且从未被拖动过 ⇒ 不接管手势（这是"不遮挡"的关键）。
  bool get _inert =>
      !_dragging && widget.phase == SpritePhase.idle && widget.onTap == null;

  Offset _clamp(Offset p) {
    final maxX = math.max(0.0, _bounds.width - widget.size - _margin * 2);
    final maxY = math.max(0.0, _bounds.height - widget.size - _margin * 2);
    return Offset(p.dx.clamp(0.0, maxX), p.dy.clamp(0.0, maxY));
  }

  Offset _defaultPos() => Offset(
        math.max(0.0, _bounds.width - widget.size - _margin * 2),
        math.max(0.0, _bounds.height - widget.size - _margin * 2),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _bounds = Size(constraints.maxWidth, constraints.maxHeight);
        var p = _clamp(_pos ?? _defaultPos());
        // 窗口尺寸变化（键盘弹出/旋转）后，原来的位置可能越界 ⇒ 夹回来。
        if (_pos != null && p != _pos) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _pos = p);
          });
        }
        final child = ChatSprite(
          phase: widget.phase,
          size: widget.size,
          accent: widget.accent,
        );
        return Stack(
          children: [
            Positioned(
              left: p.dx + _margin,
              top: p.dy + _margin,
              child: _inert
                  ? IgnorePointer(child: child)
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onTap,
                      onPanStart: (_) => setState(() => _dragging = true),
                      onPanUpdate: (d) => setState(() {
                        _pos = _clamp((_pos ?? _defaultPos()) + d.delta);
                      }),
                      onPanEnd: (_) => setState(() {
                        _dragging = false;
                        // 贴边：右半侧贴右、左半侧贴左，避免停在正中挡视线。
                        final cur = _pos ?? _defaultPos();
                        final maxX = math.max(
                            0.0, _bounds.width - widget.size - _margin * 2);
                        _pos = Offset(cur.dx > maxX / 2 ? maxX : 0, cur.dy);
                      }),
                      child: child,
                    ),
            ),
          ],
        );
      },
    );
  }
}
