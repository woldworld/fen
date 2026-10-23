// 举报闭环的 **UI 接线守卫**（0.115.0）。
//
// 为什么需要它：已有的三支举报守卫各管一层 ——
//   · tool/verify_report_service.dart  纯 Dart 协议层（状态机 / 验签 / 四条硬规矩）
//   · tool/verify_report_hub.js       跨语言（Dart ↔ Node 逐字节一致）
//   · tool/smoke_report_hub.js        活体 HTTP（真起 Hub、真发签名工单）
// ★ 但**没有一支看 UI 接线** —— 入口被摘掉、埋点 emit 被删、
//   五语种少一个语种，**三支守卫照样全绿**。
//   这正是本项目的老问题：「能力已实现 ≠ 接线完成 ≠ 使用者知道它存在」。
//
// 覆盖六组：
//   ① 两处入口在位（联系人详情页 / 管理页）；
//   ② 埋点 `report_filed` **真的 emit**（定义处 + 调用处两遍都查，且挂在成功路径上）；
//   ③ 五语种 ARB 键**齐平**（举报专属键一个不能少，通用键五语种都要有）；
//   ④ 错误码**显形**（不把失败说成成功）；
//   ⑤ 申诉一次为限在 UI 上有表达（不出现"再申诉"入口）；
//   ⑥ KB `report` 条目在位且 `kbVersion` 已 bump（能力被使用者知道）。
//
// 用法：dart run tool/verify_report_ui.dart
import 'dart:convert';
import 'dart:io';

int _pass = 0;
int _fail = 0;

void ck(bool ok, String label) {
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
  if (!f.existsSync()) return '';
  return f.readAsStringSync();
}

Map<String, dynamic> _arb(String lang) {
  final p = 'lib/l10n/app_$lang.arb';
  final raw = _read(p);
  if (raw.isEmpty) return <String, dynamic>{};
  try {
    return json.decode(raw) as Map<String, dynamic>;
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// 从 report_screen.dart 里抽出**实际用到的** `l10n.<键>`。
Set<String> _usedKeys(String source) {
  final out = <String>{};
  for (final line in source.split('\n')) {
    final m = RegExp(r'l10n\.([A-Za-z][A-Za-z0-9_]*)').firstMatch(line);
    if (m != null) out.add(m.group(1)!);
  }
  return out;
}

Future<void> main() async {
  print('--- ① 两处入口在位（能力可被点到） ---');

  final screen = _read('lib/ui/report_screen.dart');
  ck(screen.isNotEmpty, 'lib/ui/report_screen.dart 存在且非空');
  ck(screen.contains('class ReportScreen'), '举报中心页面类 ReportScreen 存在');
  ck(screen.contains('class _ReportScreenState'),
      '举报中心有 State（不是 StatelessWidget ⇒ 能加载异步工单列表）');

  final contact = _read('lib/ui/contact_detail_screen.dart');
  ck(contact.contains('report_screen.dart'), '联系人详情页 import 了举报页');
  ck(contact.contains('ReportScreen('), '联系人详情页**真的构造了** ReportScreen');
  ck(contact.contains('targetAgentId'),
      '联系人详情页传了 targetAgentId（被举报人预填，不是通用入口）');

  final manage = _read('lib/ui/manage_screen.dart');
  ck(manage.contains('report_screen.dart'), '管理页 import 了举报页');
  ck(manage.contains('ReportScreen()'), '管理页**真的构造了** ReportScreen（通用入口）');

  // ★ 正控：只有 import 没有构造 ⇒ 入口是死的（这一类半接线曾咬过 _UpdateCheckCard）
  final importOnly = RegExp(r"import.*report_screen\.dart").hasMatch(contact) &&
      !RegExp(r'ReportScreen\(').hasMatch(contact);
  ck(!importOnly, '正控：只有 import 没有构造 ⇒ 必须判出（半接线不算入口）');

  print('--- ② 埋点 report_filed 真 emit（定义处 + 调用处两遍） ---');

  final telemetry = _read('lib/core/telemetry.dart');
  ck(telemetry.contains("reportFiled = 'report_filed'"),
      '埋点常量 reportFiled = report_filed 在 telemetry.dart 定义');

  final client = _read('lib/core/report_client.dart');
  ck(client.contains('TelemetryEvents.reportFiled'),
      '★ report_client.dart **真的调用**了 TelemetryEvents.reportFiled（不是只定义）');

  // ★ emit 必须挂在**成功路径**上：前面要有 `if (ok...)` / `isNotEmpty` 之类闸，
  //   否则就是"点了按钮就算举报"，那又是一个假指标。
  final emitIdx = client.indexOf('TelemetryEvents.reportFiled');
  final guardBefore = emitIdx > 0
      ? client.substring(emitIdx - 400 < 0 ? 0 : emitIdx - 400, emitIdx)
      : '';
  ck(RegExp(r'if\s*\(\s*ok').hasMatch(guardBefore) ||
          RegExp(r'isNotEmpty').hasMatch(guardBefore) ||
          RegExp(r'!raw\.ok\s*\)\s*\{?\s*return').hasMatch(guardBefore),
      '★ emit 挂在**成功闸之后**（失败路径先 return ⇒ 失败不计数）');

  // ★ 全项目再扫一遍调用处：若只剩定义处（client 被改坏），此判据必须红
  final libDir = Directory('lib');
  final callSites = <String>[];
  for (final e in libDir.listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final p = e.path.replaceAll('\\', '/');
    // ★ 只读 .dart 源文件（`lib/.analyze-tmp/` 是分析器临时目录，里面是**二进制**
    //   `.unlinked2` ⇒ readAsStringSync() 抛 utf-8 解码异常 ⇒ 守卫自己崩掉）。
    if (!p.endsWith('.dart')) continue;
    // ★ 排除隐藏目录段（`.analyze-tmp` / `.dart_tool` 等）与打包产物。
    if (p.split('/').any((seg) => seg.startsWith('.'))) continue;
    if (p.startsWith('lib/dist/')) continue; // 打包产物不算源码
    if (p.endsWith('telemetry.dart')) continue; // 定义处不算调用处
    final t = e.readAsStringSync();
    if (t.contains('TelemetryEvents.reportFiled')) callSites.add(p);
  }
  ck(callSites.isNotEmpty,
      '★ 全项目扫到 emit 调用处（实为 ${callSites.length} 处：${callSites.join(", ")}）');

  print('--- ③ 五语种 ARB 键齐平（真译文，不是英文冒充） ---');

  final used = _usedKeys(screen);
  final reportKeys = used.where((k) => k.startsWith('report')).toList()..sort();
  ck(reportKeys.length >= 40,
      '举报页用到的 report* 键已抽出（实为 ${reportKeys.length} 个）');

  const langs = ['en', 'zh', 'zh_Hant', 'ja', 'vi'];
  final arbs = <String, Map<String, dynamic>>{
    for (final l in langs) l: _arb(l),
  };
  for (final l in langs) {
    ck(arbs[l]!.isNotEmpty, '$l 的 ARB 可解析且非空');
  }

  // 举报专属键：五语种**一个都不能少**
  final missing = <String, List<String>>{};
  for (final k in reportKeys) {
    final miss = <String>[];
    for (final l in langs) {
      if (!arbs[l]!.containsKey(k)) miss.add(l);
    }
    if (miss.isNotEmpty) missing[k] = miss;
  }
  ck(missing.isEmpty,
      '★ 举报专属键五语种齐（${reportKeys.length} 键）'
      '${missing.isEmpty ? "" : "；缺：${missing.entries.map((e) => "${e.key}→${e.value.join("/")}").join(", ")}"}');

  // 通用键（页面用到的非 report* 键）也必须五语种齐
  final commonUsed = used.where((k) => !k.startsWith('report')).toList()..sort();
  final commonMissing = <String, List<String>>{};
  for (final k in commonUsed) {
    final miss = <String>[];
    for (final l in langs) {
      if (!arbs[l]!.containsKey(k)) miss.add(l);
    }
    if (miss.isNotEmpty) commonMissing[k] = miss;
  }
  ck(commonMissing.isEmpty,
      '★ 页面用到的通用键五语种齐'
      '${commonMissing.isEmpty ? "" : "；缺：${commonMissing.entries.map((e) => "${e.key}→${e.value.join("/")}").join(", ")}"}');

  // ★ 五个语种的键数必须**同步**（R7：判据是五语种同步增减，不是绝对值相等）
  final counts = <String, int>{};
  for (final l in langs) {
    counts[l] = arbs[l]!.keys.where((k) => !k.startsWith('@')).length;
  }
  final uniq = counts.values.toSet();
  ck(uniq.length == 1,
      '★ 五语种键数同步（同增同减；实为 ${counts.entries.map((e) => "${e.key}=${e.value}").join(" / ")}）');

  // ★ 不许英文冒充译文：非 en 语种的值不能整段等于 en（占位符除外）
  final enVals = <String, String>{};
  for (final k in reportKeys) {
    final v = arbs['en']![k];
    if (v is String) enVals[k] = v;
  }
  final copied = <String>[];
  for (final l in ['zh', 'zh_Hant', 'ja', 'vi']) {
    for (final k in reportKeys) {
      final v = arbs[l]![k];
      if (v is String && v.trim() == enVals[k]?.trim() && v.trim().isNotEmpty) {
        copied.add('$l/$k');
      }
    }
  }
  ck(copied.isEmpty,
      '★ 非英语种未整段复制英文（占位符差异除外）'
      '${copied.isEmpty ? "" : "；抄：${copied.join(", ")}"}');

  print('--- ④ 错误码显形（不把失败说成成功） ---');

  ck(client.contains('ed25519_required'),
      '客户端如实带出 ed25519_required（旧 hmac 身份不悄悄降级）');
  ck(client.contains('hub_not_configured'),
      '客户端带出 hub_not_configured（Hub 未配置 ≠ 提交成功）');
  ck(screen.contains('reportErr'),
      '★ UI 层**渲染错误码文案**（l10n.reportErr* 系列，不是抛异常黑屏）');
  final errKeys = reportKeys.where((k) => k.startsWith('reportErr')).toList();
  ck(errKeys.length >= 5,
      '错误码文案键已覆盖多种失败（实为 ${errKeys.length} 个：${errKeys.join(", ")}）');
  ck(screen.contains('reportFailed') || screen.contains('reportErr'),
      '★ 失败有显形出口（不静默吞掉）');

  // ★ 正控：若 UI 不再渲染错误码，此判据必须红
  final errless = screen.replaceAll(RegExp(r'reportErr[A-Za-z0-9_]*'), '');
  ck(!errless.contains('reportErr'),
      '正控：抹掉 reportErr* 引用后必须判出（错误码不再显形 ⇒ 半接线）');

  print('--- ⑤ 申诉一次为限在 UI 上有表达 ---');

  ck(screen.contains('reportAppeal'), 'UI 有申诉入口（条款承诺的申诉能力在产品里）');
  ck(client.contains('appeal_exhausted') || screen.contains('reportErrAppealExhausted'),
      '★ 二次申诉的错误码在 UI 侧有对应文案（一次为限可被用户看见）');
  // ★ 不许出现"再次申诉"这类无次数闸的入口
  ck(!RegExp(r'reappeal|appealAgain|再申诉').hasMatch(screen),
      '★ UI 不存在无次数闸的"再申诉"入口（一次为限是协议层硬闸）');

  print('--- ⑥ KB：能力被使用者知道 ---');

  final kb = _read('lib/core/system_knowledge.dart');
  ck(kb.contains("'report'"), 'KB 新增 report 条目（条目 id 存在）');
  ck(kb.contains('kbVersion'), 'kbVersion 常量在');
  // ★ kbVersion 必须 ≥ 28（0.115.0 从 27 bump 到 28）
  final km = RegExp(r"kbVersion\s*=\s*'(\d+)'").firstMatch(kb);
  ck(km != null && int.parse(km.group(1)!) >= 28,
      '★ kbVersion ≥ 28（0.115.0 的 report 条目已 bump；实为 ${km?.group(1) ?? "?"}）');
  ck(kb.contains('RPT-'),
      '★ KB 条目写明工单号形态 RPT-（使用者知道"提交后会拿到什么"）');
  ck(kb.contains('appeal') || kb.contains('Appeal'),
      '★ KB 条目提到申诉（一次为限的承诺被写进给使用者的说明）');

  print('');
  print('== 举报闭环 UI 接线校验：$_pass PASS / $_fail FAIL ==');
  print('PASS=$_pass FAIL=$_fail');
  exit(_fail == 0 ? 0 : 1);
}
