// §16 外部锚定工具：把 Merkle root 钉到日志自己管不到的地方。
//
// 为什么这个工具存在（一句话）：
//   `TransparencyLog.verifyChain()` 查得出"改写"和"中段删除"，**查不出"砍尾巴"**。
//   砍掉末尾的日志依然是一条自洽的链。挡住它的唯一办法，是把某一期的
//   `(size, root)` 写进外部记录（GitHub 签名提交 / OpenTimestamps），
//   之后 Hub 无论怎么改自己的存储都对不上那份记录。
//
// 用法：
//   # 1) 从 Hub 抓当前 (size, root)，按 fail-closed 判据追加一行
//   dart run tool/anchor_log.dart emit --hub http://127.0.0.1:3000
//
//   # 2) 离线模式：直接把 (size, root) 写进去（例如运维从别处抄来）
//   dart run tool/anchor_log.dart emit --size 128 --root <base58> --note "周例行"
//
//   # 3) 校验：离线自检 + （给了 --hub 时）用一致性证明把相邻锚定真正连起来
//   dart run tool/anchor_log.dart verify --hub http://127.0.0.1:3000
//
// 退出码：0 = 成功；1 = fail-closed 触发（回滚/改写/序列损坏）；2 = 用法错误。
//
// ⚠️ 本工具**只写不删**锚定文件：任何"删除某行让它通过"的操作都绕过整套机制，
//    因此不提供任何 remove/rewrite 子命令。

import 'dart:convert';
import 'dart:io';

import 'package:dahuang_ai/core/log_anchor.dart';
import 'package:dahuang_ai/core/transparency_log.dart';

const String _defaultFile = 'anchors/merkle_roots.jsonl';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    exit(2);
  }
  final cmd = args.first;
  final opts = _parseOpts(args.skip(1).toList());

  switch (cmd) {
    case 'emit':
      exit(await _emit(opts));
    case 'verify':
      exit(await _verify(opts));
    case '-h':
    case '--help':
    case 'help':
      _usage();
      exit(0);
    default:
      stderr.writeln('未知子命令: $cmd');
      _usage();
      exit(2);
  }
}

void _usage() {
  stdout.writeln('''
§16 外部锚定工具
  emit   [--hub URL | --size N --root R] [--file PATH] [--note TEXT]
         观测当前 (size, root) 并按 fail-closed 判据追加一行锚定记录。
  verify [--hub URL] [--file PATH]
         离线自检锚定序列；给了 --hub 则进一步用一致性证明连接相邻锚定与当前头。
选项：
  --file PATH   锚定文件（默认 $_defaultFile）
''');
}

Map<String, String> _parseOpts(List<String> a) {
  final m = <String, String>{};
  for (var i = 0; i < a.length; i++) {
    final t = a[i];
    if (t.startsWith('--')) {
      final key = t.substring(2);
      final eq = key.indexOf('=');
      if (eq >= 0) {
        m[key.substring(0, eq)] = key.substring(eq + 1);
      } else if (i + 1 < a.length && !a[i + 1].startsWith('--')) {
        m[key] = a[i + 1];
        i++;
      } else {
        m[key] = 'true';
      }
    }
  }
  return m;
}

File _anchorFile(Map<String, String> o) =>
    File(o['file'] ?? _defaultFile);

List<LogAnchor> _load(File f) {
  if (!f.existsSync()) return <LogAnchor>[];
  return LogAnchor.seriesFromJsonl(f.readAsStringSync());
}

/// 从 Hub 拉当前 (size, root)。
Future<({int size, String root})> _fetchHead(String hub) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('${hub.replaceAll(RegExp(r'/+$'), '')}/api/log');
    final req = await client.getUrl(uri);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw StateError('Hub 返回 ${res.statusCode}: $body');
    }
    final m = jsonDecode(body) as Map<String, dynamic>;
    return (size: (m['size'] as num).toInt(), root: m['root'] as String);
  } finally {
    client.close(force: true);
  }
}

/// 拉一条一致性证明并就地验证：fromRoot 必须等于我们锚定的值。
Future<String?> _checkConnectable(String hub, LogAnchor from, int toSize) async {
  final client = HttpClient();
  try {
    final base = hub.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/log/proof/consistency?from=${from.size}&to=$toSize');
    final req = await client.getUrl(uri);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      return '一致性证明请求失败（${res.statusCode}）: $body';
    }
    final m = jsonDecode(body) as Map<String, dynamic>;
    final fromRoot = m['from_root'] as String;
    final toRoot = m['to_root'] as String;
    if (fromRoot != from.root) {
      return 'Hub 在规模 ${from.size} 处的根与锚定记录不一致 —— 历史被改写';
    }
    final proof = ConsistencyProof.fromMap(m['proof'] as Map<String, dynamic>);
    final ok = await MerkleVerify.consistency(
      proof: proof,
      fromRoot: fromRoot,
      toRoot: toRoot,
    );
    if (!ok) return '规模 ${from.size} → $toSize 的一致性证明验不过';
    return null;
  } finally {
    client.close(force: true);
  }
}

/// 把纯逻辑层的英文 token 判据渲染成面向操作者的中文说明（本地化只在这一层做）。
String _verdictZh(AnchorDecision d) {
  switch (d.verdict) {
    case AnchorVerdict.append:
      return '可追加（${d.detail}）';
    case AnchorVerdict.duplicate:
      return '无需追加：同期同根（幂等）';
    case AnchorVerdict.rollback:
      return '拒绝：日志被回滚/截断（${d.detail}）—— 哈希链原理上查不出截断，靠锚定拦住';
    case AnchorVerdict.fork:
      return '拒绝：同期换根 = 历史被改写（${d.detail}）';
    case AnchorVerdict.invalid:
      return '拒绝：输入非法（${d.detail}）';
  }
}

Future<int> _emit(Map<String, String> o) async {
  final file = _anchorFile(o);
  final series = _load(file);

  final seriesErr = AnchorPolicy.validateSeries(series);
  if (seriesErr != null) {
    stderr.writeln('✗ 现有锚定文件已损坏，拒绝继续写入：$seriesErr');
    return 1;
  }
  final last = series.isEmpty ? null : series.last;

  final int size;
  final String root;
  if (o.containsKey('hub')) {
    final h = await _fetchHead(o['hub']!);
    size = h.size;
    root = h.root;
  } else if (o.containsKey('size') && o.containsKey('root')) {
    size = int.parse(o['size']!);
    root = o['root']!;
  } else {
    stderr.writeln('需要 --hub URL 或 --size N --root R 之一');
    return 2;
  }

  final d = AnchorPolicy.decide(last: last, size: size, root: root);
  stdout.writeln('判定：${_verdictZh(d)}');

  switch (d.verdict) {
    case AnchorVerdict.append:
      final anchor = LogAnchor(
        size: size,
        root: root,
        anchoredAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        note: o['note'],
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('${anchor.toJsonl()}\n', mode: FileMode.append);
      stdout.writeln('✓ 已追加锚定：${anchor.iso}  size=${anchor.size}');
      stdout.writeln('');
      stdout.writeln('---- 锚定收据（粘贴进 GitHub 签名提交）----');
      stdout.write(AnchorReceipt.build(anchor: anchor, prevRoot: last?.root));
      return 0;
    case AnchorVerdict.duplicate:
      stdout.writeln('· 无需追加（同期同根，幂等）');
      return 0;
    case AnchorVerdict.rollback:
    case AnchorVerdict.fork:
    case AnchorVerdict.invalid:
      stderr.writeln('✗ fail-closed：拒绝写入（${_verdictZh(d)}）');
      return 1;
  }
}

Future<int> _verify(Map<String, String> o) async {
  final file = _anchorFile(o);
  final series = _load(file);
  if (series.isEmpty) {
    stdout.writeln('· 锚定文件为空或不存在：${file.path}（尚无锚定，无需校验）');
    return 0;
  }

  final err = AnchorPolicy.validateSeries(series);
  if (err != null) {
    stderr.writeln('✗ 锚定序列自检不过：$err');
    return 1;
  }
  stdout.writeln('✓ 锚定序列自检通过（${series.length} 条，规模 ${series.first.size} → ${series.last.size}）');

  if (!o.containsKey('hub')) {
    stdout.writeln('· 未提供 --hub，仅完成离线自检（要连通性证明请加 --hub）');
    return 0;
  }

  final head = await _fetchHead(o['hub']!);
  stdout.writeln('· Hub 当前：size=${head.size} root=${head.root}');

  if (head.size < series.last.size) {
    stderr.writeln('✗ fail-closed：Hub 规模（${head.size}）小于最后一条锚定（${series.last.size}）—— 回滚/截断');
    return 1;
  }

  // 相邻锚定之间 + 最后一条到当前头，全部用一致性证明连接。
  var allOk = true;
  for (var i = 1; i < series.length; i++) {
    final e = await _checkConnectable(o['hub']!, series[i - 1], series[i].size);
    if (e != null) {
      allOk = false;
      stderr.writeln('✗ 锚定 #${i - 1}→#$i 连接失败：$e');
    } else {
      stdout.writeln('✓ 锚定 #${i - 1}(size=${series[i - 1].size}) → #$i(size=${series[i].size}) 一致性证明通过');
    }
  }
  final tailErr = await _checkConnectable(o['hub']!, series.last, head.size);
  if (tailErr != null) {
    allOk = false;
    stderr.writeln('✗ 最后一条锚定 → 当前头 连接失败：$tailErr');
  } else {
    stdout.writeln('✓ 最后一条锚定(size=${series.last.size}) → 当前头(size=${head.size}) 一致性证明通过');
  }

  if (!allOk) return 1;
  stdout.writeln('✓ 全部锚定与当前日志构成一条连续、未被改写的历史');
  return 0;
}
