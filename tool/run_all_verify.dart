// 一次跑完 tool/ 下所有 verify_*.dart，并汇总 PASS/FAIL。
// 运行：dart run tool/run_all_verify.dart
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final dir = Directory('tool');
  final scripts = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('_verify.dart') ||
          (f.path.contains('verify_') && f.path.endsWith('.dart')))
      .map((f) => f.path)
      .toList()
    ..sort();

  var pass = 0;
  var fail = 0;
  var silentScripts = 0; // 0.68.0：完全无输出的脚本（= 没跑起来，判为失败）
  final rows = <String>[];

  for (final s in scripts) {
    if (s.endsWith('run_all_verify.dart')) continue;
    final r = await Process.run(
      Platform.resolvedExecutable,
      ['run', s],
      runInShell: true,
      // ★★ 0.68.0 修（真缺陷，且是"静默"的那类）：
      //   不指定编码时，Dart 按**系统编码**（中文 Windows = GBK/cp936）解码子进程输出；
      //   而脚本 `print` 出来的是 **UTF-8**。若某一行里 `PASS=` 之前有中文，
      //   中文的 UTF-8 字节数若为奇数，GBK 两两配对后会**多出一个前导字节**，
      //   把紧随其后的 ASCII 字符（正是 'P'）当成 low byte 吃掉 ⇒
      //   "== 结果：PASS=18 …" 被解成 "…歅ASS=18" ⇒ 正则找不到 "PASS=" ⇒
      //   该脚本被记成 **0 PASS / 0 FAIL —— 跑了、却像没跑一样静默通过**。
      //   （实证：`verify_morning` / `verify_user_profile` 长期被记成 0/0；
      //     `verify_mail_tools` 因 `PASS=151` 独占一行、前面无中文而侥幸逃过。）
      //   ⇒ 显式按 UTF-8 解码，一次性修掉这一整类"中文 + 计数"的组合陷阱。
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    final out = '${r.stdout}\n${r.stderr}';
    final pm = RegExp(r'PASS=(\d+)').firstMatch(out);
    final fm = RegExp(r'FAIL=(\d+)').firstMatch(out);
    final p = pm == null ? 0 : int.parse(pm.group(1)!);
    final f = fm == null ? 0 : int.parse(fm.group(1)!);
    pass += p;
    fail += f;
    final name = s.split(Platform.pathSeparator).last;
    // ★ 0.68.0：一个**崩溃或被跳过**的脚本会输出 0 行 ⇒ 被当成 "0 PASS / 0 FAIL"
    //   静静地算通过 —— 这正是最危险的一类失效：**守卫自己没跑，却是绿的**。
    //   （实证：`verify_morning` / `verify_user_profile` 长期被记成 0/0。）
    //   故"完全没有输出"必须显形，而不是混进正常计数里。
    final silent = out.trim().isEmpty;
    if (silent) {
      silentScripts++;
      rows.add('  !!    !!  $name  ← 无输出（崩溃/被跳过？判为失败）');
    } else {
      rows.add('${p.toString().padLeft(4)}  ${f.toString().padLeft(3)}  $name');
    }
    if (f > 0) {
      print('!!! $s 有 FAIL，原始输出尾部：');
      final lines = out.split('\n');
      for (final l in lines.length > 20 ? lines.sublist(lines.length - 20) : lines) {
        if (l.contains('FAIL')) print('    $l');
      }
    }
  }

  print('');
  for (final r in rows) {
    print(r);
  }
  print('');
  print('TOTAL PASS=$pass FAIL=$fail (scripts=${rows.length})');
  if (silentScripts > 0) {
    print('!!! 有 $silentScripts 个脚本**完全没有输出**（没跑起来）—— 它们不会被计入 '
        'PASS，必须单独查清：静默的守卫比红灯更危险。');
  }
  // 无输出 = 没跑起来 = 不能算通过（否则"守卫自己没跑"会显示成全绿）
  exit(fail == 0 && silentScripts == 0 ? 0 : 1);
}
