// 纯 Dart 校验脚本：验证「主聊天小精灵 = 柴犬小黄狗」的落地与三条不变量。
// 运行：dart run tool/verify_chat_sprite.dart
//
// ---------------------------------------------------------------------------
// 为什么要有这一关
// ---------------------------------------------------------------------------
// `lib/ui/chat_sprite.dart` 是**画**出来的（不是图片、不是 Rive），
// 所以"它是不是变成了柴犬"没法靠运行断言 —— 只能靠源码结构。
// 但源码结构里藏着一条**真会咬人的不变式**：
//
//   ★★ 给 `Pose` 加一个字段、却忘了往 `Pose._lerp` 里加一行 ——
//      编译通过、analyze 通过、运行不崩，只是**那个动作在阶段切换时永远不动**
//      （永远停在起点值）。这是最典型的"静默失效"，肉眼要盯着动画才看得出来。
//
// 因此本脚本用**可执行的纯函数**解析同一个源文件，把这套不变式机械化：
//   A. 零依赖承诺（只许 dart:math + material；禁 Rive/Lottie/图片资源）
//   B. `poseFor` 覆盖**全部** SpritePhase（且不许有 `default:` 兜底 —— 它会吃掉
//      "新增枚举值"的编译期保护）
//   C. `Pose` 构造参数的**每一个**都必须在 `_lerp` 里被插值（或显式处理）
//   D. 柴犬形象确实替换了旧的几何小怪（正向 + **反向**断言），
//      外加一条目视迭代得出的**分区不变式**：尾巴独占右侧、道具靠一次水平镜像让到左侧
//   E. 悬浮层两条"不遮挡"行为仍在
//   G. ★ State 里造了 **多个** AnimationController ⇒ 必须 `TickerProviderStateMixin`
//      （0.106.0 实证：两个 controller + `SingleTickerProviderStateMixin`，
//      release 下"照跑"，debug/`flutter test` 下直接抛
//      "multiple tickers were created" 并让整棵子树挂掉 —— 又一个静默失效）
//   F. 正控：把源码改坏 ⇒ B / C / G 判据必须翻红（证明判据不是恒真）
//
// 风格对齐 `tool/verify_profile_cards.dart`：`check()` 计数 + `PASS=/FAIL=` 收尾。

import 'dart:io';

int _pass = 0;
int _fail = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

/// 去掉整行注释后再扫禁词 —— 文件头里**刻意写了** "Rive/Lottie/图片资源"，
/// 不去注释会把说明文字当成违规。
String _code(String src) {
  final out = <String>[];
  for (final line in src.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    out.add(line);
  }
  return out.join('\n');
}

// ───────────────────────── 可执行的纯解析函数（正控复用） ─────────────────────────

/// `Pose` 构造函数的全部具名参数。
Set<String> ctorFields(String src) {
  final i = src.indexOf('const Pose({');
  if (i < 0) return <String>{};
  final j = src.indexOf('});', i);
  if (j < 0) return <String>{};
  return RegExp(r'this\.(\w+)')
      .allMatches(src.substring(i, j))
      .map((m) => m.group(1)!)
      .toSet();
}

/// `Pose._lerp` 里**真正被处理**的字段（数值插值 + 两个特殊处理）。
Set<String> lerpCovered(String src) {
  final i = src.indexOf('static Pose _lerp(');
  if (i < 0) return <String>{};
  // 截到 _lerp 返回字面量的最后一项（prop 的硬切写法）为止，避免吃到后面的代码。
  final end = src.indexOf('prop: t < 0.5 ? a.prop : b.prop', i);
  final body = end < 0 ? src.substring(i) : src.substring(i, end + 40);
  final out = <String>{};
  for (final m in RegExp(r'(\w+):\s*a\.(\w+)').allMatches(body)) {
    if (m.group(1) == m.group(2)) out.add(m.group(1)!);
  }
  if (body.contains('tint: Color.lerp(a.tint, b.tint, t)')) out.add('tint');
  if (RegExp(r'prop:\s*t < 0\.5 \? a\.prop : b\.prop').hasMatch(body)) {
    out.add('prop');
  }
  return out;
}

/// 构造参数里**没被 [_lerpCovered] 覆盖**的那些（应恒为空）。
List<String> missingFromLerp(String src) =>
    ctorFields(src).difference(lerpCovered(src)).toList()..sort();

/// `enum SpritePhase` 的成员名。
Set<String> phaseValues(String src) {
  final i = src.indexOf('enum SpritePhase {');
  if (i < 0) return <String>{};
  final j = src.indexOf('\n}', i);
  if (j < 0) return <String>{};
  final out = <String>{};
  for (var line in src.substring(i, j).split('\n')) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('//') || line.startsWith('enum')) {
      continue;
    }
    final m = RegExp(r'^([A-Za-z_]\w*)').firstMatch(line);
    if (m != null) out.add(m.group(1)!);
  }
  return out;
}

/// `poseFor` 里出现的 `case SpritePhase.X:`。
Set<String> poseForCases(String src) {
  final i = src.indexOf('Pose poseFor(SpritePhase phase)');
  if (i < 0) return <String>{};
  final j = src.indexOf('\n}', i);
  final body = src.substring(i, j < 0 ? src.length : j);
  return RegExp(r'case SpritePhase\.(\w+):')
      .allMatches(body)
      .map((m) => m.group(1)!)
      .toSet();
}

/// 道具层是否用一次水平镜像整体让到左侧（尾巴独占右侧）。
bool propMirrored(String code) =>
    RegExp(r'canvas\.scale\(-1,\s*1\)').hasMatch(code);

/// 找出"State 里造了多个 AnimationController、却只 mix in
/// SingleTickerProviderStateMixin"的类。返回问题描述（没问题返回 null）。
///
/// 为什么值钱：`SingleTickerProviderStateMixin.createTicker` 的"只能造一个"
/// 检查是包在 `assert(() {...}())` 里的 ⇒ **只在 debug 生效**。release 包里
/// 第二个 ticker 会静默覆盖第一个，既不崩也不报，等到跑 `flutter test` /
/// 真机 debug 装包时才炸整棵子树。必须靠源码结构提前钉住。
String? tickerMismatch(String src) {
  final cls = RegExp(
    r'class\s+(\w+)\s+extends\s+State<[^>]*>[\s\S]{0,60}?with\s+([\w,\s]+)',
  );
  for (final m in cls.allMatches(src)) {
    final name = m.group(1)!;
    final mixins =
        m.group(2)!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final bodyStart = m.end;
    final bodyEnd = src.indexOf('\n}', bodyStart);
    final body = src.substring(bodyStart, bodyEnd < 0 ? src.length : bodyEnd);
    final n = RegExp(r'AnimationController\(').allMatches(body).length;
    if (n > 1 && mixins.contains('SingleTickerProviderStateMixin')) {
      return '$name 造了 $n 个 AnimationController，却只 mix in '
          'SingleTickerProviderStateMixin（release 静默、debug 抛 '
          '"multiple tickers were created"）';
    }
  }
  return null;
}

// ─────────────────────────────────── main ───────────────────────────────────

void main() {
  const rel = 'lib/ui/chat_sprite.dart';
  final src = _read(rel);
  if (src.isEmpty) {
    print('== 结果：PASS=0  FAIL=1 ==');
    exit(1);
  }
  final code = _code(src);

  // ── A. 零依赖承诺 ────────────────────────────────────────────────
  print('-- A. 零依赖（不引 Rive / Lottie / 图片资源） --');
  final imports = RegExp(r"^import\s+'([^']+)'", multiLine: true)
      .allMatches(code)
      .map((m) => m.group(1)!)
      .toSet();
  check(
    imports.length == 2 &&
        imports.contains('dart:math') &&
        imports.contains('package:flutter/material.dart'),
    'import 恰好 = {dart:math, package:flutter/material.dart}（实际 $imports）',
  );
  const forbidden = <String>[
    'package:rive',
    'package:lottie',
    'rootBundle',
    'AssetImage',
    'Image.asset',
  ];
  final hit = forbidden.where(code.contains).toList();
  check(hit.isEmpty, '未出现 Rive/Lottie/资产加载（违规项：$hit）');

  // ── B. poseFor 覆盖全部阶段 ──────────────────────────────────────
  print('');
  print('-- B. poseFor 覆盖全部 SpritePhase，且不许 default 兜底 --');
  final phases = phaseValues(src);
  final cases = poseForCases(src);
  check(phases.length == 8, 'SpritePhase 共 8 个值（实际 ${phases.length}: $phases）');
  final uncovered = phases.difference(cases).toList()..sort();
  final extra = cases.difference(phases).toList()..sort();
  check(
    uncovered.isEmpty && extra.isEmpty,
    'poseFor 的 case 与枚举值**逐一对应**（缺 $uncovered / 多 $extra）',
  );
  final forBody = src.substring(
    src.indexOf('Pose poseFor(SpritePhase phase)'),
    src.indexOf('\n}', src.indexOf('Pose poseFor(SpritePhase phase)')),
  );
  check(
    !RegExp(r'^\s*default\s*:', multiLine: true).hasMatch(forBody),
    '★ poseFor 里**没有** default 分支（否则新增枚举值会静默走兜底、丢掉编译期保护）',
  );

  // ── C. Pose 字段 ↔ _lerp 同步（本文件最值钱的一条） ───────────────
  print('');
  print('-- C. Pose 每个字段都必须在 _lerp 里被处理（静默失效防线） --');
  final fields = ctorFields(src);
  final covered = lerpCovered(src);
  final missing = missingFromLerp(src);
  check(fields.length >= 18, 'Pose 字段数 ${fields.length}（含柴犬新增的 7 个）');
  check(
    missing.isEmpty,
    '★ 每个构造参数都在 _lerp 里被插值/显式处理'
    '${missing.isEmpty ? '' : '；漏了: $missing ← 这些参数在阶段切换时会永远不动'}',
  );
  // 柴犬专有字段确实进了 lerp（而不是只加了个字段名）
  for (final f in const <String>[
    'earPerk',
    'earTilt',
    'headTilt',
    'tail',
    'wag',
    'mouthOpen',
    'pawLift',
  ]) {
    check(covered.contains(f), '柴犬参数 $f 已被 _lerp 插值');
  }

  // ── D. 柴犬形象真的替换了旧几何小怪 ──────────────────────────────
  print('');
  print('-- D. 柴犬形象（正向 + 反向） --');
  check(code.contains('abstract final class _Dog'), '存在柴犬配色表 _Dog');
  for (final hex in const <String>[
    '0xFFE3A25F', // 背毛暖橙
    '0xFFFBF3E6', // 米白面罩/胸腹/爪
    '0xFF8D5A38', // 耳内深棕
    '0xFFEE8D9A', // 舌头
  ]) {
    check(code.contains(hex), '配色含 $hex（对齐 assets/app_icon.png）');
  }
  for (final fn in const <String>[
    '_paintTail(',
    '_paintEars(',
    '_paintFace(',
    '_paintHindPaws(',
    '_paintCollar(',
  ]) {
    check(code.contains(fn), '画序含 $fn');
  }
  // ★ 反向：旧的"水滴身 + 天线 + 白眼球"几何小怪必须**已不存在**。
  //   注意别把**保留的**东西列进来：`SpriteProp.alert`（感叹号）与
  //   `_Dog.ink` 之类是刻意留下的，列进去会造出假 FAIL。
  for (final gone in const <String>[
    'antennaPaint', // 旧：头顶天线杆
    'bodyPath', // 旧：圆角水滴身
    'RRect.fromRectAndCorners', // 旧：水滴身专用的四角圆角矩形
  ]) {
    check(!code.contains(gone), '反向：旧几何小怪特征 $gone 已移除');
  }
  // 犬类体态承载语义（每类至少一处）
  for (final p in const <String>['earPerk', 'tail', 'wag', 'mouthOpen', 'pawLift']) {
    check(code.contains('pose.$p'), '体态参数 pose.$p 真的被画进画面');
  }
  // ★ 分区不变式：**尾巴占右、道具占左**（道具层用一次水平镜像整体让开）。
  //   这条是 0.106.0 目视迭代的结论：不分开就会"道具压在尾巴上"，
  //   而逐个 offset 取负一定会漏掉一两个。
  check(
    propMirrored(code),
    '★ 道具层用水平镜像整体让到左侧（尾巴独占右侧）',
  );
  check(
    code.indexOf('_paintTail(canvas, s, w)') < code.indexOf('_paintBody(canvas, s)'),
    '★ 画序：尾巴在躯干**之前**（尾巴在后景，不被身体压掉）',
  );

  // ── E. 悬浮层"不遮挡"三条行为仍在 ────────────────────────────────
  print('');
  print('-- E. 悬浮层不遮挡（待机不接管手势 + 拖动夹取） --');
  check(code.contains('IgnorePointer'), '待机时整棵子树挂 IgnorePointer');
  check(
    RegExp(r'_inert\s*=>[\s\S]{0,120}?SpritePhase\.idle').hasMatch(code),
    '★ _inert 判据里含 SpritePhase.idle（待机才不接管手势）',
  );
  check(code.contains('_clamp('), '拖动位置被 _clamp 夹在安全区内');
  check(code.contains('Offset(p.dx.clamp(0.0, maxX)'), '夹取同时约束 x 与 y（不越界）');

  // ── G. ticker 数 ↔ mixin 类型（0.106.0 实测踩过的静默失效） ───────
  print('');
  print('-- G. 多 AnimationController ⇒ 必须 TickerProviderStateMixin --');
  final stateCls = RegExp(
    r'class\s+(\w+)\s+extends\s+State<[^>]*>[\s\S]{0,60}?with\s+([\w,\s]+)',
  );
  final clsNames = stateCls
      .allMatches(src)
      .map((m) => m.group(1)!)
      .toList();
  // 前置条件：解析器真的认出了这个 State（否则下面的"无问题"是假的）。
  check(
    clsNames.contains('_ChatSpriteState'),
    '解析器认出了 _ChatSpriteState（实际 $clsNames）',
  );
  final nCtrl = RegExp(r'AnimationController\(')
      .allMatches(src.substring(
        src.indexOf('class _ChatSpriteState'),
        src.indexOf('\n}', src.indexOf('class _ChatSpriteState')),
      ))
      .length;
  check(nCtrl >= 2, '_ChatSpriteState 造了 $nCtrl 个 AnimationController（循环 + 阶段插值）');
  final mismatch = tickerMismatch(src);
  check(
    mismatch == null,
    '★ controller 数与 mixin 类型匹配${mismatch == null ? '' : '；$mismatch'}',
  );
  check(
    code.contains('with TickerProviderStateMixin'),
    '★ 用的是 TickerProviderStateMixin（不是 Single 版）',
  );

  // ── F. 正控：判据不是恒真 ────────────────────────────────────────
  print('');
  print('-- F. 正控 --');
  final dropLerpLine = src
      .split('\n')
      .where((l) => !l.contains('earPerk: a.earPerk'))
      .join('\n');
  check(
    missingFromLerp(dropLerpLine).contains('earPerk'),
    '正控：抹掉 _lerp 里的 earPerk 后，C 组判据必报出 earPerk',
  );
  check(
    missingFromLerp(src).isEmpty,
    '正控对照：未改动的源码 C 组判据为空（说明上一条不是恒真）',
  );

  final dropCase = src
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('case SpritePhase.error:'))
      .join('\n');
  check(
    phases.difference(poseForCases(dropCase)).isNotEmpty,
    '正控：删掉一个 case 后，B 组"逐一对应"判据必翻红',
  );

  final dropImport = code.replaceFirst("import 'dart:math' as math;", '');
  final imp2 = RegExp(r"^import\s+'([^']+)'", multiLine: true)
      .allMatches(dropImport)
      .map((m) => m.group(1)!)
      .toSet();
  check(imp2.length != 2, '正控：删掉一个 import 后，A 组的"恰好 2 个"判据必翻红');

  // ★ G 的正控：把 mixin 换回 Single 版 ⇒ tickerMismatch 必须报出来。
  final regressed = src.replaceFirst(
    'with TickerProviderStateMixin',
    'with SingleTickerProviderStateMixin',
  );
  check(
    tickerMismatch(regressed) != null,
    '正控：把 mixin 降回 SingleTickerProviderStateMixin 后，G 组判据必翻红'
    '（正是 0.106.0 实测的那次失败）',
  );
  check(
    tickerMismatch(src) == null,
    '正控对照：未改动的源码 G 组判据为空（说明上一条不是恒真）',
  );

  // ★ 镜像判据的正控：抹掉那行 scale(-1,1) ⇒ propMirrored 必须翻假。
  final unmirrored = code.replaceFirst(
    RegExp(r'canvas\.scale\(-1,\s*1\);'),
    '// (removed)',
  );
  check(
    propMirrored(code) && !propMirrored(unmirrored),
    '正控：删掉水平镜像后，"道具让到左侧"判据必翻红',
  );

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
