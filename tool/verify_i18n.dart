// 纯 Dart 校验脚本：i18n 骨架自检 + 交付前乱码自检 + 多语种一致性。
// 运行：dart run tool/verify_i18n.dart
//
// 为什么要有这个脚本：ARB 各语种键不一致 / 占位符对不上 / 文案里出现中英夹杂乱码
// 这几类问题**看编译是看不出来的**（编译只保证 key 存在）。
//
// 为什么仍然用 `dart run` 而不是 `flutter test`（2026-09-27 修正）：
// 本机 `flutter test` 现已可跑通（此前是 HTTP 代理代理掉了 flutter_tester 的
// 本地 WebSocket，见 `test/db_migration_test.dart` 头部）。但本脚本是**纯 Dart、
// 零平台依赖**，挂 CI 时不需要 Flutter SDK 与真机原生库，所以继续用 `dart run`
// 是**刻意选择**，不是"跑不了"的将就。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

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

Map<String, dynamic> _arb(String path) {
  final f = File(path);
  if (!f.existsSync()) throw StateError('missing arb: $path');
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

/// 资源键（排除 `@@locale` 与 `@key` 元信息）
Set<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// 占位符名（从 en 的 @key.placeholders 取）
Set<String> _placeholders(Map<String, dynamic> arb, String key) {
  final meta = arb['@$key'];
  if (meta is! Map) return const {};
  final ph = meta['placeholders'];
  if (ph is! Map) return const {};
  return ph.keys.map((k) => k as String).toSet();
}

Set<String> _braces(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

/// 扫描 lib 下的 Dart，收集 `l10n.xxx` 形式的引用。
///
/// **先剥掉注释再扫**——踩过坑：注释里写 `L10nHolder.l10n.xxx` 这种示例
/// 会被当成本文件真的引用了 `xxx` 键，报"代码里有不存在的 key"。
String _stripComments(String src) {
  final out = StringBuffer();
  var i = 0;
  final n = src.length;
  while (i < n) {
    final c = src[i];
    if (c == '/' && i + 1 < n && src[i + 1] == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

Set<String> _usedKeys(Directory root) {
  final used = <String>{};
  for (final f in root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final src = _stripComments(f.readAsStringSync());
    for (final m in RegExp(r'\bl10n\.([A-Za-z]\w*)').allMatches(src)) {
      used.add(m.group(1)!);
    }
    // 直接内联的写法也要认：AppLocalizations.of(context).key
    for (final m in RegExp(r'AppLocalizations\.of\([^)]*\)\.([A-Za-z]\w*)')
        .allMatches(src)) {
      used.add(m.group(1)!);
    }
  }
  // ★ 0.68.0 修（全量回归抓出的 **0.67.0 遗留误报**）：`localeName` 是
  //   gen-l10n **生成类自带的字段**（`final String localeName;`，见
  //   `lib/l10n/app_localizations.dart`），**不是** ARB 里的键。
  //   0.67.0 的晨间润色 `_polish()` 用了 `L10nHolder.l10n.localeName` 做语种映射，
  //   于是本脚本把它当成"引用了不存在的 key" ⇒ 判据恒红。
  //   ★ 改的是**守卫而不是生产代码**：`localeName` 的用法本身是合法的，
  //   错的是"把生成类成员当成 ARB 键"这个假设。
  used.removeAll(_builtinL10nMembers);
  return used;
}

/// gen-l10n 生成类上**不是** ARB 键的内建成员（`l10n.xxx` 会命中它们）。
const Set<String> _builtinL10nMembers = {'localeName'};

/// 交付前乱码自检：中英夹杂的可疑串（如"即otene"、"有限报社中转"）。
/// 只作**提示**，不判失败——技术缩写（P2P / Mesh / TOFU）是合法夹杂。
List<String> _garbled(Directory root) {
  const whitelist = {
    'P2P', 'Mesh', 'ID', 'UI', 'API', 'TOFU', 'MITM', 'TTFD', 'DID',
    'A2A', 'MCP', 'SQL', 'JSON', 'ARB', 'App', 'Cloud', 'Hub', 'TextField',
    'Wold', 'Fen', 'OpenAI', 'Telegram',
  };
  final hits = <String>[];
  final re = RegExp('[一-鿿]([A-Za-z]{3,})[一-鿿]');
  for (final f in root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.md'))) {
    if (p.basename(f.path).startsWith('app_')) continue; // ARB 天然中英混排
    final lines = f.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      for (final m in re.allMatches(lines[i])) {
        final w = m.group(1)!;
        final up = w.toUpperCase();
        if (whitelist.any((x) => x.toUpperCase() == up)) continue;
        if (!w.contains(RegExp(r'[a-z]'))) continue; // 全大写缩写放行
        hits.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return hits;
}

/// 重复键检测：`jsonDecode` 会**静默保留最后一个**重复键，
/// 所以键集合/占位符校验都发现不了"同一 key 写了两遍"。
/// 这里直接扫原文，把重复项揪出来（本轮就踩过：commonCancel 被写了两遍）。
List<String> _dups(String path) {
  final txt = File(path).readAsStringSync();
  final re = RegExp(r'^\s{2}"([^"]+)":', multiLine: true);
  final seen = <String>{};
  final dup = <String>[];
  for (final m in re.allMatches(txt)) {
    final k = m.group(1)!;
    if (!seen.add(k) && !dup.contains(k)) dup.add(k);
  }
  return dup;
}

/// ============================================================
/// 0.55.0 新增：繁体残留检测
///
/// 只查**简体专属部首**（讠/纟/钅/贝/饣）——这些字在繁体里**必然**写成
/// 言/糹/金/貝/食，不存在"简繁同形"的情况，所以零误报。
/// 刻意**不**去列"常见简体字表"：表里混着 石/知/短/看/真 这类简繁同形字，
/// 一放进去就满屏误报，反而把真正的残留淹没掉。
/// ============================================================
const String _simplifiedOnlyRadicals =
    '说话语译请谁词课调读认计记论设访证评试诚该详谢讽诛询诠诞误诱诵谋谎谐谤谨谬谣谭谱谴'
    '经组细织终练绍给绝统继续维绿编缘缝缠缩绩缴约纪纯纲纵纷纹纺纽线绊绑绒结绕绘络绞绢绣绪绳绵绷绸综缀缅缆缓'
    '针钉钓钙铃铜银铸铺链锁锅锈锋错锡锣锤锦键镇镐镜镣镶'
    '财责败账货质贩贪贫贬购贮贯贱贴贵贷贸费贺贼贿赃资赈赊赋赌赎赐赔赖赘赚赛赞赡贤'
    '饭饮饰饱饲饵饺饼饿馁馆馈馍馏馒';

/// 哨兵：这几个键的繁体写法是**确定**的，用来防"整份复制 zh 忘了转换"
/// （那种情况下差异率也会崩，但哨兵能第一时间指出是哪一类字没转）。
const Map<String, String> _hantSentinels = {
  'onbLangTitle': '選擇',
  'settingsSecMemory': '記憶',
  'commonRetry': '試',
};

void main() {
  final root = Directory('lib');

  // ---------- 语种清单：必须与 l10n.yaml 一致 ----------
  print('--- 语种注册（l10n.yaml ↔ ARB 文件 ↔ LanguageController）---');
  const locales = <String>['en', 'zh', 'zh_Hant', 'ja', 'vi'];
  final yaml = File('l10n.yaml').readAsStringSync();
  final yamlLocales = <String>{};
  var inList = false;
  for (final line in yaml.split('\n')) {
    final t = line.trim();
    if (t.startsWith('supported-locales:')) {
      inList = true;
      continue;
    }
    if (inList && t.startsWith('- ')) {
      yamlLocales.add(t.substring(2).trim());
      continue;
    }
    if (inList && t.isNotEmpty && !t.startsWith('- ') && !t.startsWith('#')) {
      inList = false;
    }
  }
  check(yamlLocales.length == locales.length && yamlLocales.containsAll(locales),
      'l10n.yaml supported-locales = $locales（实际 $yamlLocales）');
  for (final code in locales) {
    check(File('lib/l10n/app_$code.arb').existsSync(),
        'ARB 文件存在：app_$code.arb');
  }
  // ★ Flutter SDK 的文件名硬约束：script 段必须拼在**下划线**后，且长度 ≥4 才被
  //   识别成 scriptCode。写成 app_zh-Hant.arb 会静默失效（编译不报错、运行时丢语种）。
  check(!File('lib/l10n/app_zh-Hant.arb').existsSync(),
      '不存在易混淆的 app_zh-Hant.arb（连字符写法会被解析成语言码 zh-Hant）');

  final ctrl = File('lib/core/language_controller.dart').readAsStringSync();
  for (final code in locales) {
    check(ctrl.contains("'$code'"),
        'LanguageController.selectableCodes 含 $code');
  }
  check(ctrl.contains("'system'"), 'LanguageController 含「跟随系统」策略位');

  final en = _arb('lib/l10n/app_en.arb');
  final enK = _keys(en);
  final others = <String, Map<String, dynamic>>{
    for (final c in locales.where((c) => c != 'en')) c: _arb('lib/l10n/app_$c.arb'),
  };

  print('--- ARB 键集合（en = 唯一模板）---');
  check(enK.isNotEmpty, 'en 有资源键 (${enK.length})');
  final extra = <String>[];
  for (final e in others.entries) {
    final k = _keys(e.value);
    final d = k.difference(enK);
    if (d.isNotEmpty) extra.add('${e.key} 多出 ${d.toList()}');
  }
  check(extra.isEmpty, '非模板 ARB 无 en 之外的键${extra.isEmpty ? '' : ' → $extra'}');

  print('--- 各语种覆盖率（未翻的键回落英文，见 l10n_untranslated.json）---');
  for (final e in others.entries) {
    final k = _keys(e.value);
    final missing = enK.difference(k);
    final pct = 100.0 * k.length / enK.length;
    print('  INFO  ${e.key}: ${k.length}/${enK.length} '
        '(${pct.toStringAsFixed(1)}%)，缺 ${missing.length}');
  }
  // 简体中文是**对照稿**，必须与模板齐平；其余语种允许分批交付
  check(enK.difference(_keys(others['zh']!)).isEmpty, 'zh 与 en 键数齐平');
  check(enK.difference(_keys(others['zh_Hant']!)).isEmpty, 'zh_Hant 与 en 键数齐平');

  print('--- 重复键（jsonDecode 会静默合并）---');
  for (final code in locales) {
    final d = _dups('lib/l10n/app_$code.arb');
    check(d.isEmpty, '$code 无重复键${d.isEmpty ? '' : ' → $d'}');
  }

  print('--- 空值 ---');
  for (final code in locales) {
    final arb = code == 'en' ? en : others[code]!;
    final k = _keys(arb);
    final empty = k.where((x) => (arb[x] as String?)?.trim().isEmpty ?? true);
    check(empty.isEmpty, '$code 无空文案${empty.isEmpty ? '' : ' → $empty'}');
  }

  print('--- 占位符一致性（所有语种对齐 en）---');
  final bad = <String>[];
  for (final k in enK) {
    final declared = _placeholders(en, k);
    final inEn = _braces((en[k] as String?) ?? '');
    if (declared.isNotEmpty && declared.difference(inEn).isNotEmpty) {
      bad.add('$k: 声明了 ${declared.difference(inEn)} 但 en 文案里没有');
    }
    for (final e in others.entries) {
      final v = e.value[k];
      if (v is! String) continue; // 该语种尚未翻译，跳过
      final inX = _braces(v);
      if (inEn.difference(inX).isNotEmpty) {
        bad.add('$k: ${e.key} 少了占位符 ${inEn.difference(inX)}');
      }
      if (inX.difference(inEn).isNotEmpty) {
        bad.add('$k: ${e.key} 多了占位符 ${inX.difference(inEn)}');
      }
    }
  }
  check(bad.isEmpty, '占位符各处一致${bad.isEmpty ? '' : ' → $bad'}');

  print('--- 繁体：不是简体中文的复制品 ---');
  final hant = others['zh_Hant']!;
  final zh = others['zh']!;
  var differ = 0;
  for (final k in _keys(hant)) {
    if (hant[k] != zh[k]) differ++;
  }
  final total = _keys(hant).length;
  final ratio = differ / total;
  // 阈值为什么是 70% 而不是 95%：约一成的键是**简繁同形**的短串
  //（"下一步"、"OK"、"取消"、纯 ASCII 值），它们本来就该一样。
  // 真出事（整份复制 zh 忘了转）时差异率会掉到接近 0，70% 足够兜住。
  check(ratio >= 0.70,
      'zh_Hant 与 zh 存在差异 ${(ratio * 100).toStringAsFixed(1)}% (≥70%)');
  final sentinelBad = <String>[];
  for (final e in _hantSentinels.entries) {
    final v = hant[e.key];
    if (v is! String || !v.contains(e.value)) {
      sentinelBad.add('${e.key} 应含「${e.value}」，实际「$v」');
    }
  }
  check(sentinelBad.isEmpty,
      '繁体哨兵字到位${sentinelBad.isEmpty ? '' : ' → $sentinelBad'}');
  final residue = <String>[];
  for (final k in _keys(hant)) {
    final v = hant[k];
    if (v is! String) continue;
    for (final ch in v.split('')) {
      if (_simplifiedOnlyRadicals.contains(ch)) {
        residue.add('$k → $ch');
        break;
      }
    }
  }
  check(residue.isEmpty,
      'zh_Hant 无简体专属部首残留${residue.isEmpty ? '' : ' → ${residue.take(10)}'}');

  print('--- 代码引用 ---');
  final used = _usedKeys(root);
  final unknown = used.difference(enK);
  check(unknown.isEmpty, '代码里没有不存在的 key${unknown.isEmpty ? '' : ' → $unknown'}');
  final unused = enK.difference(used);
  print('  INFO  已定义但暂未引用：${unused.length} 个'
      '${unused.isEmpty ? '' : ' → ${unused.toList()..sort()}'}');

  print('--- 英文 ARB 值不得含中文（英文为模板的硬约束）---');
  // 为什么单列：本项目**英文为模板**。若某个 key 的 en 值里混进中文
  //（复制 zh 时忘改 / 新增 key 只填了中文），英文用户就会看到中文。
  // 编译、key 集合校验、占位符校验**都发现不了**这种串。
  // ★★ 唯一豁免：产品专名「大荒AI」。它**按设计在英文里也是中文** ——
  //   android 桌面名 `@string/app_name` 定值为「大荒AI」且**按语言不变**（
  //   `values/strings.xml` 明写：市场名与桌面名必须一致）；而 ROM 引导要让用户去
  //   系统设置里找那个图标 ⇒ 英文引导里**必须**写屏幕上真实显示的那个名字。
  //   ⇒ 判据该查的是「有没有**漏翻的中文句子**」，不是「有没有中文字符」
  //   （R34：判据查错对象，比没判据更危险）。剔掉专名后再查，漏翻的句子一个都跑不掉。
  const brandName = '大荒AI';
  final cjk = RegExp('[一-鿿]');
  final enWithCjk = enK.where((k) {
    final v = en[k];
    if (v is! String) return false;
    return cjk.hasMatch(v.replaceAll(brandName, ''));
  }).toList()
    ..sort();
  check(enWithCjk.isEmpty,
      '英文值零中文（产品专名「$brandName」豁免）${enWithCjk.isEmpty ? '' : ' → $enWithCjk'}');
  // ★ 正控：豁免只针对专名，真正漏翻的中文句子必须仍然被抓到
  check(cjk.hasMatch('开启自启动后再试'.replaceAll(brandName, '')),
      '★ 正控：漏翻的中文句子必须被「零中文」判据抓到');

  print('--- 周易：刻意不翻译（用户决策 #4）---');
  // 卦名 / 卦辞 / 爻辞是**专有名词与古文**，翻译成外文即失其义；
  // 用户要的是"预测结果保持中文、AI 解读用所选语言"（后者由 llmSystem 保证）。
  // 这里把"刻意不翻译"钉成断言：防止后人误把它搬进 ARB。
  final zhouyi = File('lib/ui/zhouyi.dart').readAsStringSync();
  final zhouyiSrc = _stripComments(zhouyi);
  check(!zhouyiSrc.contains(RegExp(r'\bl10n\.')),
      'zhouyi.dart 不引用 l10n（卦名/卦辞保持中文）');
  // 只查 `zhouyi` 前缀：**不**用 "gua"/"yao" 做子串匹配 ——
  // `settingsLanguage`、`socialGatewayGuard` 里都含 "gua"，会被误伤；
  // 而 `serendipityOracleLogGua`（"得卦"这一栏的**栏位名**）本身是普通 UI 文案，
  // 该翻译的是栏位名，不是卦辞本身。
  final zhouyiKeys = enK.where((k) => k.toLowerCase().contains('zhouyi'));
  check(zhouyiKeys.isEmpty, 'ARB 无周易相关键${zhouyiKeys.isEmpty ? '' : ' → $zhouyiKeys'}');
  check(File('assets/data/zhouyi.json').existsSync(), '周易数据源仍在（未被拆散）');

  print('--- 乱码自检（提示，不判失败）---');
  final hits = _garbled(root);
  if (hits.isEmpty) {
    print('  PASS  未发现中英夹杂的可疑串');
    _pass++;
  } else {
    print('  WARN  可疑串 ${hits.length} 处（技术缩写已放行，请人工确认）：');
    for (final h in hits.take(20)) {
      print('        $h');
    }
  }

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
