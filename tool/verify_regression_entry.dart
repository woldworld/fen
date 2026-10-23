// 纯 Dart 校验脚本：钉死 0.108.0「`flutter test` 必须走唯一入库入口、且入口必须真剥代理」。
// 运行：dart run tool/verify_regression_entry.dart
//
// ★★ 为什么要有这个脚本（防的是"修复被写进 scratch 就当修好了"）：
//   0.89.0 就把「本机 `flutter test` 假挂」的根因诊断清楚了 —— HTTP(S) 代理环境变量劫持
//   `flutter_tester` 回连 flutter tool 的**本地** WebSocket。但当时只写进文档和
//   `备份/0.94/0.95_scratch/_regression_*.ps1`（**不入库、随时被清**）⇒ 之后每个版本
//   都要重新踩一遍（0.106.0、0.107.0 都又踩了：39 个文件全挂 `Invalid WebSocket upgrade`）。
//   ⇒ 本脚本把「有入口」+「入口真剥代理」两条都钉成可执行断言，并且带**真跑子进程的正控**。
//
// 判据设计（三条硬 + 一条可执行正控）：
//   ① 入口存在，且 8 个代理键变体逐个列全（少一个就漏一种大小写/协议）。
//   ② Windows 分支必须是 `set X=` 且 `&` **紧跟 `=`**（`set X= & ` 会把值设成一个空格
//      —— 0.108.0 实测泄漏 4 个键，是这次真正踩到的坑）。
//   ③ 入口自带静默/半途守卫：没输出判失败、既没 All tests passed 也没 Some tests failed 判失败。
//   ④ **可执行正控**：注入 6 个代理键后真跑 `dart run tool/run_flutter_test.dart --check-env`，
//      断言 `SEEN_PROXY_IN_PARENT>=3`（证明注入真的进去了，正控不是空跑）
//      **且** `PROXY_KEYS_LEFT=0`（证明真的剥干净了）。把 `_wrapWithoutProxy` 改坏 ⇒ 这里立刻变红。

import 'dart:convert';
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

const Utf8Codec kUtf8 = Utf8Codec(allowMalformed: true);

const String kEntry = 'tool/run_flutter_test.dart';

/// 取函数体：从 `String _wrapWithoutProxy` 起到下一个顶层 `\n}`。
/// ★ 反证必须落在**函数体**上：整文件扫描会撞到注释里引用的反例原文（守卫反模式）。
String _fnBody(String src, String sig) {
  final i = src.indexOf(sig);
  if (i < 0) return '';
  final j = src.indexOf('\n}', i);
  if (j < 0) return src.substring(i);
  return src.substring(i, j);
}

Future<void> main() async {
  final f = File(kEntry);
  check(f.existsSync(), '① 入口存在：$kEntry');
  if (!f.existsSync()) {
    print('PASS=$_pass FAIL=$_fail');
    exit(_fail == 0 ? 0 : 1);
  }
  final src = f.readAsStringSync();

  // ① 8 个代理键变体逐个列全
  for (final k in <String>[
    'http_proxy',
    'https_proxy',
    'all_proxy',
    'ftp_proxy',
    'HTTP_PROXY',
    'HTTPS_PROXY',
    'ALL_PROXY',
    'FTP_PROXY',
  ]) {
    check(src.contains("'$k',"), '① 代理键列全：$k');
  }

  // ② Windows 分支不留空格（`set X= & ` = 设成空格，不是删除）
  final body = _fnBody(src, 'String _wrapWithoutProxy');
  check(body.isNotEmpty, '② 取到 _wrapWithoutProxy 函数体');
  check(body.contains("join('&')"), '② Windows 分支用 `&` 紧跟 `=`（不留空格）');
  check(!body.contains('= & '), '② 函数体内不得出现 `= & `（会把值设成一个空格，等于没删）');
  check(body.contains('set \$k='), '② Windows 分支确实用 `set X=` 真删');
  check(body.contains('-u \$k'), '② 非 Windows 分支用 `env -u` 真删');

  // ③ 静默 / 半途守卫
  check(src.contains('out.trim().isEmpty'), '③ 有"完全没输出 ⇒ 判失败"的静默守卫');
  check(src.contains('exit(3)'), '③ 静默时以非零码退出');
  check(src.contains('!allPassed && !someFailed'), '③ 有"既没通过也没失败 ⇒ 没跑完"的守卫');
  check(src.contains('exit(4)'), '③ 没跑完时以非零码退出');
  // ★ 0.108.0 当场踩到：flutter 的收尾行是 `+459:`（**没有** `-0:`）⇒ 把 `-N` 写成必选
  //   就会把"459 全过"读成 PASS=0 ⇒ 一句 `OK 0 passed` 的**静默误判**。
  check(src.contains(r'+(\d+)(?:\s+-(\d+))?:'),
      '③ 计数正则必须把 `-N` 写成**可选组**（收尾行只有 `+N:`）');
  check(src.contains('allPassed && passed == 0'),
      '③ 有"说 All tests passed 却读出 0 条 ⇒ 解析失效"的自校验');
  check(src.contains('exit(5)'), '③ 读数解析失效时以非零码退出');

  // ④ 镜像源一个都不许动（删了反而拉不动包）
  check(!src.contains("remove('PUB_HOSTED_URL')"),
      '④ 不得删 PUB_HOSTED_URL（镜像源）');
  check(!src.contains("remove('FLUTTER_STORAGE_BASE_URL')"),
      '④ 不得删 FLUTTER_STORAGE_BASE_URL（镜像源）');

  // ⑤ 陈旧归因必须清掉：别再让"宿主注入 DLL"这种已被推翻的说法继续误导
  final stale = File('tool/verify_trial_switch.dart');
  if (stale.existsSync()) {
    final s2 = stale.readAsStringSync();
    check(!s2.contains('注入 DLL'), '⑤ verify_trial_switch 不得再写已被推翻的"注入 DLL"归因');
    check(s2.contains('run_flutter_test.dart'),
        '⑤ verify_trial_switch 的 flutter test 指路应指向新入口');
  } else {
    check(false, '⑤ verify_trial_switch.dart 存在');
  }

  // ★★ ⑥ 可执行正控：真起子进程，注入代理，看入口能否剥干净
  final injected = <String, String>{};
  for (final e in Platform.environment.entries) {
    injected[e.key] = e.value;
  }
  const poison = 'http://127.0.0.1:9';
  for (final k in <String>[
    'http_proxy',
    'https_proxy',
    'HTTP_PROXY',
    'HTTPS_PROXY',
    'ALL_PROXY',
    'all_proxy',
  ]) {
    injected[k] = poison;
  }
  final r = await Process.run(
    Platform.resolvedExecutable,
    <String>['run', kEntry, '--check-env'],
    environment: injected,
    stdoutEncoding: kUtf8,
    stderrEncoding: kUtf8,
  );
  final out = '${r.stdout}\n${r.stderr}';
  final seen = int.tryParse(
          RegExp(r'SEEN_PROXY_IN_PARENT=(\d+)').firstMatch(out)?.group(1) ?? '') ??
      -1;
  final left = int.tryParse(
          RegExp(r'PROXY_KEYS_LEFT=(\d+)').firstMatch(out)?.group(1) ?? '') ??
      -1;
  check(seen >= 3, '⑥ 正控前置：注入的代理确实进了子进程（SEEN_PROXY_IN_PARENT=$seen ≥ 3）');
  check(left == 0, '⑥ 正控：入口跑完后代理键应被剥干净（PROXY_KEYS_LEFT=$left == 0）');
  check(!out.contains('LEAKED='), '⑥ 正控：不得有任何泄漏键');
  if (left != 0 || seen < 3) {
    print('    ---- --check-env 原始输出 ----');
    for (final l in out.split('\n')) {
      if (l.trim().isNotEmpty) print('    $l');
    }
  }

  print('PASS=$_pass FAIL=$_fail');
  exit(_fail == 0 ? 0 : 1);
}
