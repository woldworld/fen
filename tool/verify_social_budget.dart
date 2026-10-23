// 预算守卫：**「改了默认值、漏了显式实例」** 这类"只改一半等于没改"。
//
// 运行：dart run tool/verify_social_budget.dart
//
// ============================================================
// 为什么要有它（本仓已经踩过两次，且第二次是用户先发现的）
// ------------------------------------------------------------
// 2026-09-29：用户说"每小时 2 次太少，改成 20 次"。
//   当时的改法是改 `social_budget.dart` 里构造函数的**默认值**（3→20 / 20→200）。
//   对私聊/雷达（`SocialBudget()` 无参）**生效了**。
// 2026-09-30：用户实测反馈「**托管的智能体每小时聊天还是只有 2 条**」。
//   根因：世界房间托管用的是 `SocialBudget(perHourMax: 2, perDayMax: 10)`
//   —— **显式传参**，压根不读默认值 ⇒ 上一轮的"改成 20 条"对它**完全没生效**。
//   ★ 同族的坑本仓还踩过一次（v1.30：每小时 20 次必须"两处同改"，只改一处等于没改）。
//
// ⇒ 结论不是"下次记得 grep"，而是**让漏改在机器上过不去**。
//    这就是本脚本存在的理由：**「改了默认值」≠「改了所有实例」**。
//
// 判据（刻意保守，只拦"确定是错的"那种）：
//   ① 任何**显式传参**的 `SocialBudget(...)`，其 `perHourMax` / `perDayMax`
//      **不得低于同名字段的默认值** —— 默认值是"用户拍过的数"，低于它即与用户口径矛盾。
//      （确有必要更严的通道，请登记进 `_stricter` 并写明理由，而不是默默写个小数字。）
//   ② 面向用户/主人的额度文案里**不得硬编码条数**（`每小时最多 12 条` 这种字面量）。
//      数字必须从 `perHourMax` 派生 —— 否则改完数字、文案还写着旧值，
//      用户看到的是**与自己设置不符的说明**（比不显示更糟：它让人以为没生效）。
//   ③ ★ **跨层一致**：App 端「房间托管」预算 ≤ 服务端 `world.js` 的
//      `CAP_PER_MEMBER_HOUR`（每成员每房间每小时）。App 抬到 20 而服务端还留 8 ⇒
//      **20 条永远到不了，用户看到的还是 8** —— 又是"只改一半"，且**跨了两端**，
//      比同一文件内漏改更难靠人眼发现（两处相距 2000 行、还是两门语言）。
//
// ★ 本脚本自带**正控**（`_selfTest`）：先用合成样例证明"我抓得到违规"，
//   再去扫真实文件。否则匹配式一旦随重构漂移，就会"扫到 0 处 ⇒ 差集恒空 ⇒ 恒绿"
//   —— 这类**恒真守卫**比没有守卫更坏（它给的是假的安全感）。
// ============================================================

import 'dart:io';

int _pass = 0;
int _fail = 0;
final List<String> _failures = [];

void _ok(String what) {
  _pass++;
  print('  ✓ $what');
}

void _bad(String what) {
  _fail++;
  _failures.add(what);
  print('  ✗ $what');
}

/// 允许"比默认更严"的实例（键 = `文件|字段`，值 = 理由）。
/// ★ 当前为空：本仓尚无确需更严的通道。加之前请先问一句"为什么不直接用默认"。
const Map<String, String> _stricter = {};

List<String> _dartFilesUnder(String root) {
  final d = Directory(root);
  if (!d.existsSync()) return [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => !p.startsWith('lib/l10n/'))
      .toList()
    ..sort();
}

/// 一个显式传参的实例化点。
class _Site {
  _Site(this.path, this.line, this.hour, this.day);
  final String path;
  final int line;
  final int? hour; // 显式 perHourMax（null = 未传）
  final int? day; // 显式 perDayMax（null = 未传）
}

/// 从一段源码里扫出所有 `SocialBudget(...)` **实例化点**（跳过构造函数定义本身）。
List<_Site> _scanSites(String src, String path) {
  final out = <_Site>[];
  final lines = src.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final at = line.indexOf('SocialBudget(');
    if (at < 0) continue;
    if (line.contains('this.perHourMax')) continue; // 构造签名
    var after = line.substring(at + 'SocialBudget('.length);
    if (after.trimLeft().startsWith('{')) continue; // 定义/文档
    if (after.contains(')')) after = after.substring(0, after.indexOf(')'));
    final hm = RegExp(r'perHourMax\s*:\s*(\d+)').firstMatch(after);
    final dm = RegExp(r'perDayMax\s*:\s*(\d+)').firstMatch(after);
    out.add(_Site(
      path,
      i + 1,
      hm == null ? null : int.parse(hm.group(1)!),
      dm == null ? null : int.parse(dm.group(1)!),
    ));
  }
  return out;
}

/// 额度文案里是否硬编码了条数（`每小时最多 12 条`）。派生写法 `每小时最多 ${x} 条` 不算。
final RegExp _hardcodedCap = RegExp(r'每小时最多\s*\d+');

/// ⚠️ 只认**字符串里**的出现。
///
/// 为什么要有这一层（2026-09-30 实测踩到）：第一版只做 `_hardcodedCap.hasMatch(line)`，
/// 于是它把一段**注释**里的引述（`// 用户实测看到的就是这句：「托管每小时最多 2 条」`）
/// 也判成了违规 —— 那是**误报**。
/// ★ 这和 v1.28 踩过的是同一族：**守卫的锚点错了，比没有守卫更糟** ——
///   它逼着人去删守卫，或者去改一句无害的注释来迎合它。
/// 所以判据收窄为：匹配点**之前**必须已经出现引号（说明它落在字符串字面量里）。
bool _looksHardcoded(String line) {
  final m = _hardcodedCap.firstMatch(line);
  if (m == null) return false;
  final before = line.substring(0, m.start);
  return before.contains("'") || before.contains('"');
}

// ---------- ③ 跨层一致：App 端房间托管预算 ↔ 服务端每房间上限 ----------

/// App 端房间托管的每小时预算（`agent_service.dart` 的 `_worldBudget`）。
final RegExp _worldBudgetRe = RegExp(
  r'_worldBudget\s*=\s*SocialBudget\(\s*perHourMax\s*:\s*(\d+)',
);

/// 服务端每成员每房间每小时上限（`lib/hub/world.js` 的 `CAP_PER_MEMBER_HOUR` 默认值）。
final RegExp _serverCapRe = RegExp(
  r'CAP_PER_MEMBER_HOUR\s*=\s*Number\(\s*process\.env\.WORLD_CAP_PER_MEMBER_HOUR\s*\|\|\s*(\d+)\s*\)',
);

/// ★ 纯函数（便于正控直接调用）：App 预算高于服务端上限即为"只改一半"。
bool _worldCapConsistent(int appHour, int serverCap) => appHour <= serverCap;

/// ★ 正控：先用合成样例证明"我抓得到违规"。
void _selfTest() {
  print('== ⓿ 守卫自检（正控：先证明抓得到，再去扫真文件） ==');
  // ② 实例化点扫描
  final s = _scanSites(
    'final a = SocialBudget(perHourMax: 2, perDayMax: 10);\n'
    'final b = SocialBudget();\n'
    'SocialBudget({this.perHourMax = 20, this.perDayMax = 200});\n',
    'synthetic.dart',
  );
  if (s.length == 2) {
    _ok('实例化点扫描正确（2 处，已跳过构造签名）');
  } else {
    _bad('实例化点扫描失准：期望 2 处，实得 ${s.length} 处');
  }
  if (s.isNotEmpty && s[0].hour == 2 && s[0].day == 10) {
    _ok('显式传参数值解析正确（perHourMax=2 / perDayMax=10）');
  } else {
    _bad('显式传参数值解析失准（拿到 ${s.isEmpty ? '空' : '${s[0].hour}/${s[0].day}'}）');
  }
  if (s.length > 1 && s[1].hour == null && s[1].day == null) {
    _ok('无参实例被正确识别（不误报为显式传参）');
  } else {
    _bad('无参实例识别失准');
  }
  // ③ 硬编码条数
  if (_looksHardcoded("ok('本小时发言额度已用完（托管每小时最多 2 条）');")) {
    _ok('硬编码条数可被检出（正例）');
  } else {
    _bad('硬编码条数检不出 —— ② 的匹配式已失效');
  }
  if (!_looksHardcoded(r'ok("每月最多 3 次");') &&
      !_looksHardcoded(
          r"ok('本小时额度已用完（每小时最多 ${_worldBudget.perHourMax} 条）');")) {
    _ok('派生写法与无关文案不误报（反例）');
  } else {
    _bad('误报：派生写法或无关文案被判成硬编码');
  }
  // ★ 注释里的引述不算违规（第一版正是栽在这条上）
  if (!_looksHardcoded('  //   用户实测看到的就是这句：「托管每小时最多 2 条」。') &&
      !_looksHardcoded('  /// 历史上写死过 每小时最多 2 条，已修。')) {
    _ok('注释里的引述不误报（锚点只认字符串）');
  } else {
    _bad('误报：注释里引述的条数被判成硬编码 —— 锚点又跑出字符串了');
  }
  // ③ 跨层一致：解析式 + 判据都要有正控
  final m = _worldBudgetRe.firstMatch(
      '  final SocialBudget _worldBudget = SocialBudget(perHourMax: 20, perDayMax: 200);');
  final c = _serverCapRe.firstMatch(
      'const CAP_PER_MEMBER_HOUR = Number(process.env.WORLD_CAP_PER_MEMBER_HOUR || 8);');
  if (m != null && m.group(1) == '20' && c != null && c.group(1) == '8') {
    _ok('跨层两个数字都能解析（App=20 / 服务端=8）');
  } else {
    _bad('跨层解析式失准（App=${m?.group(1)} / 服务端=${c?.group(1)}）—— ③ 的锚点已失效');
  }
  if (!_worldCapConsistent(20, 8) && _worldCapConsistent(20, 20) &&
      _worldCapConsistent(8, 20)) {
    _ok('跨层判据方向正确（App 20 > 服务端 8 判违规；相等/更小判通过）');
  } else {
    _bad('跨层判据方向错误 —— 会把合规配置判成违规，或反之');
  }
}

void main() {
  if (!Directory('lib').existsSync()) {
    stderr.writeln('在项目根目录运行（找不到 lib/）');
    print('PASS=0 FAIL=1');
    exitCode = 1;
    return;
  }

  _selfTest();

  // ---------- ① 读出"默认值"（单一事实源 = 构造签名那一行） ----------
  print('');
  print('== ① 默认值（来自 SocialBudget 的构造签名） ==');
  final defSrc = File('lib/core/social_budget.dart').readAsStringSync();
  final defMatch = RegExp(
    r'SocialBudget\(\{this\.perHourMax\s*=\s*(\d+)\s*,\s*this\.perDayMax\s*=\s*(\d+)\}',
  ).firstMatch(defSrc);
  if (defMatch == null) {
    _bad('无法从 lib/core/social_budget.dart 解析默认值 —— 构造签名变了？'
        '（守卫已失效应立即修，否则它会"扫到 0 处 ⇒ 恒绿"）');
    print('');
    print('PASS=$_pass FAIL=$_fail');
    exitCode = 1;
    return;
  }
  final defHour = int.parse(defMatch.group(1)!);
  final defDay = int.parse(defMatch.group(2)!);
  _ok('默认值可解析（perHourMax=$defHour / perDayMax=$defDay）');

  // ---------- ② 扫全部实例化点，比较显式传参 ----------
  print('');
  print('== ② 全部 SocialBudget(...) 实例化点 ==');
  final files = _dartFilesUnder('lib');
  var sites = 0;
  for (final path in files) {
    final src = File(path).readAsStringSync();
    for (final site in _scanSites(src, path)) {
      sites++;
      final where = '${site.path}:${site.line}';
      if (site.hour == null && site.day == null) {
        _ok('$where 无显式传参（用默认 $defHour/$defDay）');
        continue;
      }
      final explicit =
          'perHourMax=${site.hour ?? '(默认)'} perDayMax=${site.day ?? '(默认)'}';
      final allowed = _stricter.containsKey('$path|hour') ||
          _stricter.containsKey('$path|day');
      if (site.hour != null && site.hour! < defHour && !allowed) {
        _bad('$where 显式 perHourMax=${site.hour} **低于默认 $defHour**（$explicit）'
            ' —— 这正是"改了默认值、漏了这个实例"的形态；'
            '确需更严请登记进 _stricter 并写明理由');
      } else if (site.day != null && site.day! < defDay && !allowed) {
        _bad('$where 显式 perDayMax=${site.day} **低于默认 $defDay**（$explicit）'
            ' —— 同上：低于用户拍过的口径');
      } else {
        _ok('$where $explicit（≥ 默认，口径一致）');
      }
    }
  }
  if (sites == 0) {
    _bad('全仓扫到 0 个实例化点 —— 守卫很可能已失效（恒真守卫比没有更坏）');
  } else {
    _ok('扫到 $sites 个实例化点（>0 ⇒ 本项守卫确实在工作）');
  }

  // ---------- ③ 额度文案不得硬编码条数 ----------
  print('');
  print('== ③ 额度文案不得硬编码条数 ==');
  var hardcoded = 0;
  for (final path in files) {
    final lines = File(path).readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (!_looksHardcoded(lines[i])) continue;
      hardcoded++;
      final t = lines[i].trim();
      _bad('$path:${i + 1} 额度文案硬编码条数：'
          '`${t.length > 62 ? '${t.substring(0, 62)}…' : t}`'
          ' —— 改成从 `perHourMax` 派生，否则数字与文案必然漂移');
    }
  }
  if (hardcoded == 0) {
    _ok('未发现硬编码条数的额度文案（数字均由 perHourMax 派生）');
  }

  // ---------- ④ 跨层一致：App 端房间托管预算 ≤ 服务端每房间上限 ----------
  print('');
  print('== ④ 跨层一致（App 房间托管预算 ↔ 服务端 world.js 每房间上限） ==');
  final appSrc = File('lib/core/agent_service.dart').readAsStringSync();
  final srvSrc = File('lib/hub/world.js').readAsStringSync();
  final appM = _worldBudgetRe.firstMatch(appSrc);
  final srvM = _serverCapRe.firstMatch(srvSrc);
  if (appM == null || srvM == null) {
    _bad('跨层数字解析失败（App=${appM?.group(1) ?? '未找到'} / '
        '服务端=${srvM?.group(1) ?? '未找到'}）—— 变量名或写法变了？'
        '守卫失效应立即修，否则这一项会静默恒绿');
  } else {
    final appHour = int.parse(appM.group(1)!);
    final serverCap = int.parse(srvM.group(1)!);
    if (_worldCapConsistent(appHour, serverCap)) {
      _ok('App 端房间托管 $appHour 条/小时 ≤ 服务端每房间上限 $serverCap 条'
          '（20 条不会在半路被截断）');
    } else {
      _bad('App 端房间托管 **$appHour** 条/小时 > 服务端每房间上限 **$serverCap** 条'
          ' —— 用户看到的仍是 $serverCap 条（"说好的 $appHour 条"永远到不了）；'
          '两条闸必须同改：`lib/hub/world.js` 的 CAP_PER_MEMBER_HOUR 默认值 / '
          '环境变量 WORLD_CAP_PER_MEMBER_HOUR');
    }
  }

  // ---------- 汇总 ----------
  print('');
  if (_failures.isNotEmpty) {
    print('--- 失败明细 ---');
    for (final f in _failures) {
      print('  • $f');
    }
    print('');
  }
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
