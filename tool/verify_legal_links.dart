// 跨端「法务文档链接」守卫（0.54.0 新增）。
//
// 背景：隐私政策 / 服务条款两份法务文档由 **landing 静态站**（`landing/build.js`）
// 生成在 `/privacy/` 与 `/terms/`；App 内（设置页「法律与关于」）给它们挂浏览器入口。
// 这是**跨端、跨语言（Dart ↔ Node）**的一根链子，任一端单独改动都不会报错，
// 症状却是「App 里点开 404」或「上架表单说隐私政策不可达」——上线前才发现。
//
// 它钉三件事：
//   ① **单源域名**：App 的 `SetupService.defaultWebUrl` 必须等于 landing 的
//      `site.json → brand.domain`（去尾斜杠）。换域名时两端只改一处、这里当场报警。
//   ② **路径一致**：设置页 `_openLegal(x)` 用的路径，必须正好是 build.js 会写出的页面
//      （`/privacy/` → `privacy/index.html`）。列表里还有几个路径、就要求 build.js 写几份。
//   ③ **界面显示的地址 = 实际打开的地址**：ListTile 的 subtitle 与 onTap 必须同路径，
//      防"改了一处忘了另一处"（用户看到 A、点开 B）。
//
// 另附两条纪律断言：App 侧**不得出现裸域名**（一律走常量）；build.js 的 DOMAIN 必须
// 派生自 site.json（不许写死），否则①②的"单源"是假的。
//
// ★ 与 `verify_help_topics.dart` 同款：源文本扫描脚本必须带**正向自检**，
//   匹配式一坏就会"扫到 0 处 → 恒绿"。下面的判据抽成纯函数，末尾对人为改坏的副本断言。
import 'dart:convert';
import 'dart:io';

int _pass = 0;
int _fail = 0;
void check(bool ok, String label) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    print('  FAIL: $label');
  }
}

String _stripComments(String s) {
  // ★ 行注释用**负向后顾** `(?<!:)//` —— 只剥"真正的注释 `//`"，**不剥 URL 里的 `://`**。
  //   通行的 `//.*$` 写法会把 `'https://wold.world'` 截成 `'https:`，本守卫全篇是 URL，
  //   一旦被截，①'setup 常量正则'与⑦'裸域名扫描'都会**恒绿**（静默失效）—— 这是本仓
  //   源文本扫描型脚本的既有坑，此处显式避开。
  final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
  return noBlock
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'(?<!:)//.*$'), ''))
      .join('\n');
}

String _read(String p) => File(p).readAsStringSync();

/// 递归收集 lib 下的 .dart（排除生成物 l10n）。
List<String> _dartFilesUnder(String dir) {
  final out = <String>[];
  final d = Directory(dir);
  if (!d.existsSync()) return out;
  for (final e in d.listSync(recursive: true)) {
    if (e is! File) continue;
    final p = e.path.replaceAll('\\', '/');
    if (!p.endsWith('.dart')) continue;
    if (p.contains('/lib/l10n/')) continue;
    out.add(p);
  }
  out.sort();
  return out;
}

// ── 判据（纯函数，供自检复用）──────────────────────────────────────────
class Rule {
  Rule({
    required this.settings,
    required this.setup,
    required this.buildJs,
    required this.siteDomainRaw,
    required this.appDartFiles,
  });

  final String settings; // lib/ui/settings_screen.dart（已剥注释）
  final String setup; // lib/core/setup_service.dart（已剥注释）
  final String buildJs; // landing/build.js（原文）
  final String? siteDomainRaw; // landing/data/site.json 的 brand.domain（原文）
  final Map<String, String> appDartFiles; // lib 下所有 .dart（已剥注释）
}

String _norm(String u) => u.replaceFirst(RegExp(r'/+$'), '');

List<String> checkAll(Rule r) {
  final bad = <String>[];

  // ── ① App 出厂域名 ──
  final m = RegExp(r"static const String defaultWebUrl = '([^']+)';").firstMatch(r.setup);
  if (m == null) {
    bad.add('setup_service.dart 找不到 defaultWebUrl 常量');
  }
  final appWeb = m?.group(1);

  // ── ② landing 域名（site.json，单一来源）──
  if (r.siteDomainRaw == null) {
    bad.add('landing/data/site.json 缺少 brand.domain');
  }
  final landWeb = r.siteDomainRaw == null ? null : _norm(r.siteDomainRaw!);

  if (appWeb != null && landWeb != null && _norm(appWeb) != landWeb) {
    bad.add('域名不一致：App=$appWeb landing=$landWeb');
  }

  // ── ③ build.js 的 DOMAIN 必须派生自 site.json（不许写死）──
  if (!RegExp(r'const DOMAIN\s*=\s*site\.brand\.domain').hasMatch(r.buildJs)) {
    bad.add('build.js 的 DOMAIN 未派生自 site.brand.domain（疑似写死）');
  }

  // ── ④ 设置页打开的路径集合 ──
  final openPaths = RegExp(r"_openLegal\('([^']+)'\)")
      .allMatches(r.settings)
      .map((e) => e.group(1)!)
      .toList();
  if (openPaths.isEmpty) {
    bad.add('settings_screen.dart 没有任何 _openLegal(...) 调用（入口被删？）');
  }
  final openSet = openPaths.toSet();
  for (final p in openSet) {
    if (!p.startsWith('/') || !p.endsWith('/')) {
      bad.add('路径不规范（应以 / 开头、/ 结尾）：$p');
    }
  }
  // 每个路径恰好一个入口（重复 = 复制粘贴事故）
  for (final p in openSet) {
    final n = openPaths.where((x) => x == p).length;
    if (n != 1) bad.add('路径 $p 在设置页出现 $n 次（应恰好 1 次）');
  }
  // 已知必需的两份法务文档
  for (final must in const ['/privacy/', '/terms/']) {
    if (!openSet.contains(must)) bad.add('设置页缺少法务入口：$must');
  }

  // ── ⑤ build.js 必须为每个路径写出对应页面 ──
  //   约定：/privacy/ → privacy/index.html
  for (final p in openSet) {
    final artifact = '${p.substring(1)}index.html';
    if (!r.buildJs.contains("written.push('$artifact')")) {
      bad.add('build.js 未写出页面 $artifact（App 路径 $p 会 404）');
    }
    if (!r.buildJs.contains("'$p'")) {
      bad.add('build.js 未把 $p 收进 sitemap（urls 列表）');
    }
  }
  // 页脚两条链接并列（首页可跳转）
  for (final p in const ['/privacy/', '/terms/']) {
    if (!r.buildJs.contains('href="$p"')) bad.add('build.js 页脚缺少链接 href="$p"');
  }

  // ── ⑥ 界面显示的地址 = 实际打开的地址 ──
  //    subtitle 用 '${SetupService.defaultWebUrl}/privacy/'，其尾部路径应与 onTap 同源。
  final shownPaths = RegExp(r"\$\{SetupService\.defaultWebUrl\}(/[^']*)")
      .allMatches(r.settings)
      .map((e) => e.group(1)!)
      .toSet();
  for (final p in openSet) {
    if (!shownPaths.contains(p)) {
      bad.add('设置页显示路径与打开路径不一致：未见显示 $p');
    }
  }
  for (final p in shownPaths) {
    if (!openSet.contains(p)) bad.add('设置页显示了 $p 但无处打开（悬空展示）');
  }

  // ── ⑦ App 侧不得出现裸域名（一律走常量）──
  for (final e in r.appDartFiles.entries) {
    if (e.key == 'lib/core/setup_service.dart') continue; // 常量定义处
    if (e.value.contains('https://wold.world') || e.value.contains('http://wold.world')) {
      bad.add('${e.key} 出现裸域名（应走 SetupService.defaultWebUrl）');
    }
  }

  return bad;
}

// ── 加载 ───────────────────────────────────────────────────────────────
Rule _load() {
  final dart = <String, String>{
    for (final p in _dartFilesUnder('lib')) p: _stripComments(_read(p)),
  };
  String? siteDomain;
  final siteRaw = _read('landing/data/site.json');
  final site = jsonDecode(siteRaw) as Map;
  final brand = site['brand'];
  if (brand is Map && brand['domain'] is String) {
    siteDomain = brand['domain'] as String;
  }
  return Rule(
    settings: dart['lib/ui/settings_screen.dart'] ?? '',
    setup: dart['lib/core/setup_service.dart'] ?? '',
    buildJs: _read('landing/build.js'),
    siteDomainRaw: siteDomain,
    appDartFiles: dart,
  );
}

void main() {
  final r = _load();
  final bad = checkAll(r);

  // ── 正向断言 ──
  check(r.settings.isNotEmpty, 'settings_screen.dart 真被读到');
  check(r.setup.contains('defaultWebUrl'), 'setup_service.dart 含 defaultWebUrl');
  check(r.buildJs.length > 1000, 'build.js 真被读到（${r.buildJs.length} 字节）');
  check(r.siteDomainRaw != null, 'site.json 的 brand.domain 被解析到（${r.siteDomainRaw}）');
  check(r.appDartFiles.length >= 60, 'lib 源码树真被走到（${r.appDartFiles.length} 个文件）');
  check(bad.isEmpty, '判据全过${bad.isEmpty ? '' : ' — 见下方逐条'}');
  for (final b in bad) {
    print('    · $b');
  }

  // ── ★ 自检（positive control）：改坏副本，每份都必须被判出 ──
  // ① 域名漂移
  final m1 = Rule(
    settings: r.settings,
    setup: r.setup.replaceFirst("defaultWebUrl = 'https://wold.world'", "defaultWebUrl = 'https://wold.example'"),
    buildJs: r.buildJs,
    siteDomainRaw: r.siteDomainRaw,
    appDartFiles: r.appDartFiles,
  );
  check(checkAll(m1).isNotEmpty, '自检①：App 域名漂移必须被判出');

  // ② 路径写错（界面点开 404）
  final m2 = Rule(
    settings: r.settings.replaceFirst("_openLegal('/terms/')", "_openLegal('/tos/')"),
    setup: r.setup,
    buildJs: r.buildJs,
    siteDomainRaw: r.siteDomainRaw,
    appDartFiles: r.appDartFiles,
  );
  check(checkAll(m2).isNotEmpty, '自检②：设置页路径改错必须被判出');

  // ③ build.js 少写一份页面
  final m3 = Rule(
    settings: r.settings,
    setup: r.setup,
    buildJs: r.buildJs.replaceFirst("written.push('terms/index.html')", "written.push('x/index.html')"),
    siteDomainRaw: r.siteDomainRaw,
    appDartFiles: r.appDartFiles,
  );
  check(checkAll(m3).isNotEmpty, '自检③：build.js 漏写页面必须被判出');

  // ④ 界面显示与打开不一致
  final m4 = Rule(
    settings: r.settings.replaceFirst(
      "\${SetupService.defaultWebUrl}/privacy/",
      "\${SetupService.defaultWebUrl}/privacyx/",
    ),
    setup: r.setup,
    buildJs: r.buildJs,
    siteDomainRaw: r.siteDomainRaw,
    appDartFiles: r.appDartFiles,
  );
  check(checkAll(m4).isNotEmpty, '自检④：显示路径与打开路径不一致必须被判出');

  // ⑤ 裸域名回流
  final m5Files = Map<String, String>.from(r.appDartFiles)
    ..['lib/ui/dashboard_screen.dart'] =
        '${r.appDartFiles['lib/ui/dashboard_screen.dart'] ?? ''} const u = "https://wold.world/x"; ';
  final m5 = Rule(
    settings: r.settings,
    setup: r.setup,
    buildJs: r.buildJs,
    siteDomainRaw: r.siteDomainRaw,
    appDartFiles: m5Files,
  );
  check(checkAll(m5).isNotEmpty, '自检⑤：裸域名回流必须被判出');

  // ⑥ DOMAIN 写死
  final m6 = Rule(
    settings: r.settings,
    setup: r.setup,
    buildJs: r.buildJs.replaceFirst('site.brand.domain', "'https://wold.world'"),
    siteDomainRaw: r.siteDomainRaw,
    appDartFiles: r.appDartFiles,
  );
  check(checkAll(m6).isNotEmpty, '自检⑥：build.js DOMAIN 写死必须被判出');

  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
