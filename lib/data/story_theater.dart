/// 章回剧场《小荒出世·一梦游大荒》（0.98.0 官网）移植 App 首启引导（0.100.0）的
/// **结构层**：零依赖纯 Dart，可被 `flutter test` 直接单测。
///
/// 分工边界（移植方案 §6）：
/// - 本文件只放结构与算法：蛋精灵三态枚举、性格骰子、SVG 路径解析、几何与画法。
/// - **文案一律走 ARB**（`storyTrait*` 等键），不读 `landing/data/story.json` 资产
///   —— App 五语种与官网双语是两套渲染，刻意不同步。
/// - 几何逐条移植自 `landing/build.js:143-164`（viewBox 0 0 120 130），画法逐条
///   对应 `landing/src/style.css:613-623` 的 `.sp-*` 规则；
///   [SpriteShape.svgElement] 还原的元素串与官网 SVG **逐字节同构**，由
///   `tool/verify_story_prologue.dart` 拿 build.js 原文反向断言（防几何漂移）。
/// - 颜色不在本层：App 侧按 `ThemeProvider` 明暗解析（见 `ui/story_sprite.dart`），
///   承 R27「明暗主题免费」。
library;

/// 蛋 / 精灵三态，承官网 `spriteArt(state)`（landing/build.js:143-164）。
enum StorySpriteState {
  /// 未孵化：蛋壳 + 裂纹，无五官（点它才孵化）。
  egg,

  /// 已孵化：尾 + 本体 + 高光 + 圆眼 + 微笑。
  hatched,

  /// 警觉：撤回演示卡的「坏消息」时刻 —— hatched 壳 + 一字眼 + 倒眉 + 撇嘴。
  alert,
}

/// 序幕可掷的 5 条性格；顺序与 story.json `awaken.traits` 一致。
///
/// UI 按序号取 ARB `storyTrait1..5` 渲染与预填（语气描述词本地化）——
/// 本层不存任何语文案。
enum StoryTrait { curious, chatty, cautious, warm, slowToTrust }

/// 全部性格（掷骰候选池，顺序即 story.json 顺序）。
const List<StoryTrait> storyTraits = StoryTrait.values;

/// 掷性格：`roll ∈ [0,1)` → [storyTraits] 下标（0..4），五等分。
///
/// 纯函数（边界与全覆盖可单测）：越界夹紧到两端；NaN 视作 0（调用方不崩）。
int rollTraitIndex(double roll) {
  if (roll.isNaN) return 0;
  final clamped = roll.clamp(0.0, 0.999999);
  final idx = (clamped * storyTraits.length).floor();
  if (idx < 0) return 0;
  if (idx >= storyTraits.length) return storyTraits.length - 1;
  return idx;
}

/// 一条归一化后的 SVG 路径指令：大写**绝对**坐标。
///
/// `args` 长度随指令定：M/L = 2，C = 6，Q = 4，Z = 0。
class SvgPathCmd {
  const SvgPathCmd(this.op, this.args);

  final String op;
  final List<double> args;
}

/// 路径 token：单个字母（命令）或一个数字（支持 `-9` 连写与科学计数法）。
final RegExp _pathTokenRe = RegExp(r'[A-Za-z]|-?\d*\.?\d+(?:[eE][+-]?\d+)?');
final RegExp _letterRe = RegExp(r'^[A-Za-z]$');

/// 蛋精灵路径允许的命令子集（= 官网实际用到的全部命令）。
const String _supportedCmds = 'MmLlHhVvCcQqZz';

bool _isLetter(String token) => _letterRe.hasMatch(token);

/// 解析官网蛋精灵用到的 SVG 路径**子集**为绝对指令序列。
///
/// 支持 M/m、L/l、H/h、V/v、C/c、Q/q、Z/z，含 SVG 规范的隐式重复
/// （M 之后成对数字是 L、m 之后是 l）。数字个数不合法 ⇒ [FormatException]；
/// 认不出的命令字母**显式抛错**，绝不静默跳过（防几何被悄悄篡改）。
///
/// 不追求完整 SVG 1.1：官网精灵只用到这些命令（build.js:143-164）。
List<SvgPathCmd> parseSvgPath(String d) {
  final tokens = _pathTokenRe.allMatches(d).map((m) => m.group(0)!).toList();
  if (tokens.isEmpty) {
    throw FormatException('empty path data', d);
  }
  final out = <SvgPathCmd>[];
  double x = 0;
  double y = 0;
  double startX = 0;
  double startY = 0;
  String? op;
  String? implicit;
  int p = 0;

  double nextNum() {
    if (p >= tokens.length || _isLetter(tokens[p])) {
      throw FormatException('path expects a number here', d);
    }
    return double.parse(tokens[p++]);
  }

  while (p < tokens.length) {
    final String cmd;
    if (_isLetter(tokens[p])) {
      if (!_supportedCmds.contains(tokens[p])) {
        throw FormatException('unsupported path command "${tokens[p]}"', d);
      }
      cmd = tokens[p++];
      // M/m 的首个坐标对之后，隐式命令变为 L/l；其余命令隐式重复自身。
      implicit = cmd == 'M' ? 'L' : (cmd == 'm' ? 'l' : cmd);
    } else {
      if (op == null) {
        throw FormatException('path must start with a command', d);
      }
      cmd = implicit!;
    }
    op = cmd;
    switch (cmd) {
      case 'M':
      case 'm':
        final nx = nextNum();
        final ny = nextNum();
        if (cmd == 'm') {
          x += nx;
          y += ny;
        } else {
          x = nx;
          y = ny;
        }
        startX = x;
        startY = y;
        out.add(SvgPathCmd('M', [x, y]));
      case 'L':
      case 'l':
        final nx = nextNum();
        final ny = nextNum();
        if (cmd == 'l') {
          x += nx;
          y += ny;
        } else {
          x = nx;
          y = ny;
        }
        out.add(SvgPathCmd('L', [x, y]));
      case 'H':
      case 'h':
        final nx = nextNum();
        x = cmd == 'h' ? x + nx : nx;
        out.add(SvgPathCmd('L', [x, y]));
      case 'V':
      case 'v':
        final ny = nextNum();
        y = cmd == 'v' ? y + ny : ny;
        out.add(SvgPathCmd('L', [x, y]));
      case 'C':
      case 'c':
        final a = <double>[nextNum(), nextNum(), nextNum(), nextNum(), nextNum(), nextNum()];
        if (cmd == 'c') {
          for (var i = 0; i < a.length; i++) {
            a[i] += i.isEven ? x : y;
          }
        }
        x = a[4];
        y = a[5];
        out.add(SvgPathCmd('C', a));
      case 'Q':
      case 'q':
        final a = <double>[nextNum(), nextNum(), nextNum(), nextNum()];
        if (cmd == 'q') {
          a[0] += x;
          a[1] += y;
          a[2] += x;
          a[3] += y;
        }
        x = a[2];
        y = a[3];
        out.add(SvgPathCmd('Q', a));
      case 'Z':
      case 'z':
        out.add(const SvgPathCmd('Z', <double>[]));
        x = startX;
        y = startY;
      default:
        throw FormatException('unsupported path command "$cmd"', d);
    }
  }
  return out;
}

/// 蛋精灵的绘制部件（= 官网 CSS 的 `.sp-*` class 名）。
enum SpritePart { shell, crack, tail, orb, shine, eye, brow, mouth }

enum SpriteShapeKind { ellipse, circle, path }

/// 一个几何部件。数值一律 viewBox 0 0 120 130 单位。
class SpriteShape {
  const SpriteShape({
    required this.part,
    required this.kind,
    this.cx = 0,
    this.cy = 0,
    this.rx = 0,
    this.ry = 0,
    this.d = '',
  });

  final SpritePart part;
  final SpriteShapeKind kind;

  /// ellipse / circle 的中心。
  final double cx;
  final double cy;

  /// ellipse 的 rx；circle 的半径（此时 ry 无意义，置 0）。
  final double rx;

  /// ellipse 的 ry。
  final double ry;

  /// path 的 SVG path data（官网原文，逐字节保留）。
  final String d;

  /// 还原成官网 build.js 里的 SVG 元素串（供守卫拿原文反向断言）。
  String svgElement() {
    final cls = 'sp-${part.name}';
    switch (kind) {
      case SpriteShapeKind.ellipse:
        return '<ellipse class="$cls" cx="${_num(cx)}" cy="${_num(cy)}" rx="${_num(rx)}" ry="${_num(ry)}"/>';
      case SpriteShapeKind.circle:
        return '<circle class="$cls" cx="${_num(cx)}" cy="${_num(cy)}" r="${_num(rx)}"/>';
      case SpriteShapeKind.path:
        return '<path class="$cls" d="$d"/>';
    }
  }
}

/// 整数不带 `.0`：Dart 的 `60.0.toString()` 是 `"60.0"`，与官网 `"60"` 不同构。
String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// viewBox 尺寸（承官网 `sprite-svg` 的 `viewBox="0 0 120 130"`）。
const double spriteViewBoxWidth = 120;
const double spriteViewBoxHeight = 130;

/// 三态几何：逐条对应 `landing/build.js` 的 `spriteArt(state)`。
/// 列表顺序 = 绘制顺序（尾在本体之前，先铺底再画五官）。
List<SpriteShape> spriteShapes(StorySpriteState state) {
  switch (state) {
    case StorySpriteState.egg:
      return const [
        SpriteShape(
          part: SpritePart.shell,
          kind: SpriteShapeKind.ellipse,
          cx: 60,
          cy: 66,
          rx: 33,
          ry: 41,
        ),
        SpriteShape(
          part: SpritePart.crack,
          kind: SpriteShapeKind.path,
          d: 'M41 52l13 11-9 12 15 8-11 14',
        ),
      ];
    case StorySpriteState.hatched:
      return const [
        SpriteShape(
          part: SpritePart.tail,
          kind: SpriteShapeKind.path,
          d: 'M62 94c-15 13-24 7-28 20 13-3 20-9 28-20z',
        ),
        SpriteShape(
          part: SpritePart.orb,
          kind: SpriteShapeKind.ellipse,
          cx: 60,
          cy: 58,
          rx: 37,
          ry: 34,
        ),
        SpriteShape(
          part: SpritePart.shine,
          kind: SpriteShapeKind.ellipse,
          cx: 45,
          cy: 45,
          rx: 11,
          ry: 7,
        ),
        SpriteShape(part: SpritePart.eye, kind: SpriteShapeKind.circle, cx: 48, cy: 56, rx: 6),
        SpriteShape(part: SpritePart.eye, kind: SpriteShapeKind.circle, cx: 74, cy: 56, rx: 6),
        SpriteShape(
          part: SpritePart.mouth,
          kind: SpriteShapeKind.path,
          d: 'M52 72q8 6 16 0',
        ),
      ];
    case StorySpriteState.alert:
      return const [
        SpriteShape(
          part: SpritePart.tail,
          kind: SpriteShapeKind.path,
          d: 'M62 94c-15 13-24 7-28 20 13-3 20-9 28-20z',
        ),
        SpriteShape(
          part: SpritePart.orb,
          kind: SpriteShapeKind.ellipse,
          cx: 60,
          cy: 58,
          rx: 37,
          ry: 34,
        ),
        SpriteShape(
          part: SpritePart.shine,
          kind: SpriteShapeKind.ellipse,
          cx: 45,
          cy: 45,
          rx: 11,
          ry: 7,
        ),
        SpriteShape(
          part: SpritePart.eye,
          kind: SpriteShapeKind.path,
          d: 'M41 56h14M67 56h14',
        ),
        SpriteShape(
          part: SpritePart.brow,
          kind: SpriteShapeKind.path,
          d: 'M40 46l14 6M68 46l12 6',
        ),
        SpriteShape(
          part: SpritePart.mouth,
          kind: SpriteShapeKind.path,
          d: 'M52 74q8-5 16 0',
        ),
      ];
  }
}

/// 某部件的画法（fill/stroke 与否、描边宽度、端/接风格），逐条对应
/// `landing/src/style.css:613-623` 的 `.sp-*` 规则；颜色由 UI 层按主题解析。
class SpritePartSpec {
  const SpritePartSpec({
    this.fill = true,
    required this.stroke,
    required this.strokeWidth,
    this.roundCap = false,
    this.roundJoin = false,
  });

  final bool fill;
  final bool stroke;
  final double strokeWidth;
  final bool roundCap;
  final bool roundJoin;
}

SpritePartSpec spritePartSpec(SpritePart part, StorySpriteState state) {
  switch (part) {
    case SpritePart.shell:
      return const SpritePartSpec(stroke: true, strokeWidth: 2);
    case SpritePart.crack:
      return const SpritePartSpec(fill: false, stroke: true, strokeWidth: 2.4, roundJoin: true);
    case SpritePart.orb:
      return const SpritePartSpec(stroke: true, strokeWidth: 2);
    case SpritePart.tail:
      return const SpritePartSpec(stroke: false, strokeWidth: 0);
    case SpritePart.shine:
      return const SpritePartSpec(stroke: false, strokeWidth: 0);
    case SpritePart.eye:
      // alert 态眼从「填充圆」改成「一字描边」（官网 .sprite-alert .sp-eye）。
      return state == StorySpriteState.alert
          ? const SpritePartSpec(fill: false, stroke: true, strokeWidth: 3.4, roundCap: true)
          : const SpritePartSpec(stroke: false, strokeWidth: 0);
    case SpritePart.brow:
      return const SpritePartSpec(fill: false, stroke: true, strokeWidth: 3, roundCap: true);
    case SpritePart.mouth:
      return const SpritePartSpec(fill: false, stroke: true, strokeWidth: 2.6, roundCap: true);
  }
}

/// 撤回演示卡的「坏消息」行下标：story.json `undo.lines[1]` 即 `undo.badLine`。
/// App 版文案走 ARB（`storyUndoLine1/2` + `storyUndoBad`），这里只钉**语义下标**，
/// 防批次③把好坏行写反。
const int storyUndoBadLineIndex = 1;
