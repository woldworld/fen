// ★★ 唯一入库的 `flutter test` 入口 —— 跑之前**真删代理环境变量**。
//
//   运行：dart run tool/run_flutter_test.dart              （= flutter test --no-pub）
//         dart run tool/run_flutter_test.dart -- <任意 flutter test 参数>
//         dart run tool/run_flutter_test.dart --check-env  （只做环境体检，不跑测试）
//
// ★★ 为什么必须有这个入口（0.89.0 实证，0.108.0 固化）：
//   本机常驻 `http_proxy` / `https_proxy` = `http://127.0.0.1:49185`（宿主注入的代理）。
//   `flutter test` 起来的是 `flutter_tester`，它要靠**本地 WebSocket** 回连 flutter tool；
//   这条**本机**连接同样会被上述代理环境变量劫持 ⇒ `Invalid WebSocket upgrade request`
//   ⇒ **39 个测试文件在 loading 期整锅假挂**（实测 `00:00 +0 -39: Some tests failed`）。
//   剥掉 `*_proxy` 并显式设 `no_proxy=127.0.0.1,localhost,::1` 后：**459 / 0 All tests passed**。
//   ⇒ 这不是"测试有问题"，是**环境有问题**。既然是环境，就必须固化进**唯一入口**，
//     不能靠人每次记得手动敲一行 `env -u ...`。
//
// ★ 为什么 0.89.0 就诊断过、却每个版本还要重踩：
//   当时只写进了文档和 `备份/0.94/0.95_scratch/_regression_*.ps1`（不入库、会清）。
//   ⇒ **写在 scratch 里的环境修复 = 没修**。本文件就是为"不再重踩"而存在。
//
// ★ 两个实现上的硬要求（都是踩过的坑）：
//   ① **置空不算清干净**。Windows cmd 里必须 `set http_proxy=`（真删），
//      Dart 侧只把 map 里的值设成 `''` 并不等于删除变量。故下面走 **cmd /c 的 `set X=`**，
//      environment map 只作为第二道保险（显式设 `no_proxy`）。
//   ② **必须自带静默守卫**：一个"完全没输出"的子进程要判失败，
//      否则"测试根本没跑起来"会显示成一片安静的绿。
//
// 注意：`PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL` **一个都不动**（镜像源，删了反而拉不动包）。

import 'dart:convert';
import 'dart:io';

/// 需要真删的代理类环境变量（Windows 环境变量大小写不敏感，但 `set` 与 map 都按原样给，
/// 所以大小写变体逐个列全，不赌大小写折叠）。
const List<String> kProxyKeys = <String>[
  'http_proxy',
  'https_proxy',
  'all_proxy',
  'ftp_proxy',
  'HTTP_PROXY',
  'HTTPS_PROXY',
  'ALL_PROXY',
  'FTP_PROXY',
];

const String kNoProxyValue = '127.0.0.1,localhost,::1';

/// ★ 子进程输出**必须显式按 UTF-8 解码**（否则 Dart 用系统编码 GBK，会吞字节 ⇒ 静默误判）；
/// 但同时**必须容错**：`set` / flutter 的输出里可能夹带非 UTF-8 字节，默认 `utf8` 会直接抛
/// `FormatException` 把脚本崩掉（0.108.0 实证）。故用 `allowMalformed: true` 替换成 U+FFFD。
const Utf8Codec kUtf8 = Utf8Codec(allowMalformed: true);

/// 父环境里还剩几个代理类键（正控用：证明"注入的代理确实进来了"）。
int _countProxyKeys(Map<String, String> env) {
  var n = 0;
  for (final k in env.keys) {
    final l = k.toLowerCase();
    if (l.endsWith('_proxy') && l != 'no_proxy') n++;
  }
  return n;
}

/// 剥掉代理后的环境（第二道保险；第一道是下面 cmd /c 里的 `set X=`）。
Map<String, String> _cleanEnv() {
  final env = <String, String>{};
  for (final e in Platform.environment.entries) {
    env[e.key] = e.value;
  }
  for (final k in kProxyKeys) {
    env.remove(k);
  }
  env['no_proxy'] = kNoProxyValue;
  env['NO_PROXY'] = kNoProxyValue;
  return env;
}

/// 拼出"先真删代理、再执行 [rest]"的命令行。
/// Windows 用 `set X=`（真删），其它平台用 `env -u X`（真删）。
String _wrapWithoutProxy(String rest) {
  if (Platform.isWindows) {
    // ★★ 0.108.0 实证坑：`=` 与 `&` 之间**绝不能留空格** —— 留了空格就变成
    //   "给这个变量设成一个空格的值"，**不是删除** ⇒ 代理环境变量照样生效
    //   （实测泄漏 4 个键：`ALL_PROXY / HTTPS_PROXY / HTTP_PROXY / ftp_proxy`）。
    //   正解：让 `&` 紧跟在 `=` 后面（或写成 `(set X=)`）。这里用前者。
    final deletes = kProxyKeys.map((k) => 'set $k=').join('&');
    return '$deletes&set no_proxy=$kNoProxyValue&set NO_PROXY=$kNoProxyValue&$rest';
  }
  final unsets = kProxyKeys.map((k) => '-u $k').join(' ');
  return 'env $unsets no_proxy=$kNoProxyValue NO_PROXY=$kNoProxyValue $rest';
}

/// `--check-env`：真起一个子进程，在**剥完之后**把环境列出来数一遍代理键。
/// 这不是 Dart 侧的字符串游戏 —— 它读的是子进程的**真实环境**。
Future<int> _checkEnv() async {
  final parentCount = _countProxyKeys(Platform.environment);
  final cmd = Platform.isWindows ? _wrapWithoutProxy('set') : _wrapWithoutProxy('env');
  final r = await Process.run(
    Platform.isWindows ? 'cmd' : '/bin/sh',
    Platform.isWindows ? <String>['/c', cmd] : <String>['-c', cmd],
    environment: _cleanEnv(),
    stdoutEncoding: kUtf8,
    stderrEncoding: kUtf8,
  );
  final out = '${r.stdout}\n${r.stderr}';

  final seen = <String, String>{};
  final re = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$');
  for (final rawLine in out.split('\n')) {
    final line = rawLine.trimRight();
    final m = re.firstMatch(line);
    if (m == null) continue;
    final k = m.group(1)!;
    if (k.toLowerCase().endsWith('_proxy') && k.toLowerCase() != 'no_proxy') {
      seen[k] = m.group(2)!;
    }
  }
  final left = seen.keys.toList()..sort();
  print('SEEN_PROXY_IN_PARENT=$parentCount');
  print('PROXY_KEYS_LEFT=${left.length}');
  if (left.isNotEmpty) print('LEAKED=${left.join(',')}');
  print('NO_PROXY=${seen.containsKey('no_proxy') ? seen['no_proxy'] : kNoProxyValue}');
  print('CHECK_ENV_OK=1');
  return left.isEmpty ? 0 : 1;
}

Future<void> main(List<String> args) async {
  if (args.contains('--check-env')) {
    exit(await _checkEnv());
  }

  final passthrough = args.where((a) => a != '--').toList();
  final testArgs = <String>['test'];
  if (!passthrough.contains('--no-pub')) {
    testArgs.add('--no-pub'); // 依赖早已 resolved；避免 pub 走网络（代理已被剥）
  }
  testArgs.addAll(passthrough);

  final parentCount = _countProxyKeys(Platform.environment);
  print('>> flutter ${testArgs.join(' ')}');
  print('>> 代理已剥（父环境原有 $parentCount 个 *_proxy 键）'
      '${parentCount == 0 ? '；本次父环境本来就没有代理，本入口仍是唯一入口，别绕过它' : ''}');

  final cmd = _wrapWithoutProxy('flutter ${testArgs.join(' ')}');
  final sw = Stopwatch()..start();
  final r = await Process.run(
    Platform.isWindows ? 'cmd' : '/bin/sh',
    Platform.isWindows ? <String>['/c', cmd] : <String>['-c', cmd],
    environment: _cleanEnv(),
    stdoutEncoding: kUtf8,
    stderrEncoding: kUtf8,
  );
  sw.stop();
  final out = '${r.stdout}\n${r.stderr}';

  // ★ 静默守卫：一条输出都没有 = 根本没跑起来（比红灯更危险）
  if (out.trim().isEmpty) {
    print('!!! flutter 完全没有输出（exit=${r.exitCode}）—— 测试**没跑起来**，判为失败。');
    print('FLUTTER_TEST_PASS=0 FAIL=0');
    exit(3);
  }
  print(out.trim().isEmpty ? '' : out.trim());

  // ★★ 0.108.0 当场踩到的第三个坑：**收尾行是 `+459:` 而不是 `+459 -0:`**
  //   （只有出现失败时才会写成 `+457 -2:`）⇒ 若把 `-(\d+)` 写成必选，最后一行**匹配不上**，
  //   于是"459 全过"被读成 **PASS=0 FAIL=0** —— 一句 `OK ... 0 passed` 的**静默误判**，
  //   比红灯危险得多。故 `-N` 必须写成**可选组**。
  final counts = RegExp(r'\+(\d+)(?:\s+-(\d+))?:').allMatches(out);
  final last = counts.isEmpty ? null : counts.last;
  final passed = last == null ? 0 : int.parse(last.group(1)!);
  final failed = last == null
      ? 0
      : int.parse(last.group(2) ?? '0'); // 没有 `-N` 就是 0 个失败
  final allPassed = out.contains('All tests passed');
  final someFailed = out.contains('Some tests failed');

  print('');
  print('FLUTTER_TEST_PASS=$passed FAIL=$failed  (${sw.elapsed.inSeconds}s, exit=${r.exitCode})');

  // ★ 自校验：说了"全过"却数出 0 条通过 ⇒ 是**读数解析坏了**，不是真的全过。
  if (allPassed && passed == 0) {
    print('!!! 输出说 "All tests passed"，但解析出的通过数是 0 —— '
        '这是**读数解析失效**（不是真的零用例），判为失败（承"静默误判比红灯危险"）。');
    exit(5);
  }

  if (!allPassed && !someFailed) {
    print('!!! 输出里既没有 "All tests passed" 也没有 "Some tests failed" —— '
        '测试**没跑完**（很可能又是环境劫持），必须查清，不能当通过。');
    exit(4);
  }
  if (r.exitCode != 0) {
    print('!!! flutter test 未通过（exit=${r.exitCode}）。'
        '若报 WebSocket / upgrade 相关错误，先确认没绕过本入口。');
    exit(r.exitCode);
  }
  print('OK  flutter test 通过：$passed passed / $failed failed');
}
