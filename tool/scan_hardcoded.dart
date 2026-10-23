// 存量中文硬编码**清单工具**（纯 Dart，零平台依赖）。
// 运行：dart run tool/scan_hardcoded.dart
//
// 为什么要有它：迁移这件事最容易变成"感觉差不多了"。
// 清单必须能随时重算 —— 迁移前/后各跑一次，数字就是证据。
//
// 口径（刻意保守）：
// - 只扫 `lib/` 下的 .dart 文件，**排除** `lib/l10n/`（那里就是词典本身）与 `tool/`
// - **排除注释**（`//`、`///`、`/* */`）——注释里的中文不是 UI 文案
// - 只算**含中日韩统一表意文字（CJK）的字面量**：'...' / "..." / '''...''' / """..."""
// - 逐**文件**统计，并给每个文件列几条例样（便于判断"值不值得迁"）
//
// 不判断"这句是否真的会显示给用户"——工具不做语义判断，
// 判断交给人，工具只保证**没有一个字面量被漏掉**。

import 'dart:io';

int _stringCount = 0;
final Map<String, List<String>> _byFile = {};
final Map<String, int> _counts = {};

bool _hasCjk(String s) {
  for (final r in s.runes) {
    // CJK 统一表意文字 + 全角标点（。，、！？：；（）「」《》）
    if ((r >= 0x4E00 && r <= 0x9FFF) ||
        (r >= 0x3000 && r <= 0x303F) ||
        (r >= 0xFF00 && r <= 0xFFEF)) {
      return true;
    }
  }
  return false;
}

void _record(String path, String lit) {
  _stringCount++;
  _counts[path] = (_counts[path] ?? 0) + 1;
  final list = _byFile.putIfAbsent(path, () => []);
  if (list.length < 3) {
    list.add(lit.length > 48 ? '${lit.substring(0, 48)}…' : lit);
  }
}

/// 极简词法器：把源码切成"代码 / 注释 / 字符串"，只取字符串里的 CJK。
///
/// ⚠️ **必须理解 `${...}` 插值**（2026-09-27 修，此前一直算错）。
/// Dart 字符串里可以嵌套代码，代码里又能再出现任意引号的字符串，例如：
///
/// ```dart
/// return "Hi, I'm $a — $o's assistant agent. I speak on ${x.isEmpty ? 'their' : "$o's"} ";
/// ```
///
/// 只把 `'` / `"` 当纯分隔符的词法器会在插值里的 `"$o's"` 处**失步**：
/// 它以为外层字符串在那对引号处结束了，于是后面整段源码（含注释）被吞成
/// "一个字符串"。后果有两个，都很坏：
/// ① **假阳性**：注释里的中文被当成 UI 文案计进去；
/// ② **计数漂移**：真实字面量被合并进那个假字符串，边界会随**注释文字的标点**
///    变化而增减 —— 本工具的数字是"迁移进度"的证据，飘一个都不可接受。
///    （实例：给一段注释加一句 `prefs['soul_master_name']`，凭空多出 1 个"字面量"。）
///
/// 所以这里用**模式栈**：字符串态遇到 `${` 就压入代码态，代码态遇到配平的 `}`
/// 再弹回字符串态；嵌套字符串各自独立计数（它们确实是各自独立的字面量）。
void scanSource(String src, String path) {
  final n = src.length;
  var i = 0;

  final isStr = <bool>[false]; // 当前上下文是否在字符串里
  final depth = <int>[0]; // 代码态的大括号深度
  final delim = <String>[];
  final raw = <bool>[];
  final buf = <StringBuffer>[];

  while (i < n) {
    // ============================ 代码态 ============================
    if (!isStr.last) {
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

      final isRaw =
          c == 'r' && i + 1 < n && (src[i + 1] == "'" || src[i + 1] == '"');
      if (c == "'" || c == '"' || isRaw) {
        final q = isRaw ? src[i + 1] : c;
        final start = isRaw ? i + 1 : i;
        final triple =
            start + 2 < n && src[start + 1] == q && src[start + 2] == q;
        final d = triple ? q * 3 : q;
        i = start + d.length;
        isStr.add(true);
        delim.add(d);
        raw.add(isRaw);
        buf.add(StringBuffer());
        continue;
      }

      if (c == '{') {
        depth[depth.length - 1]++;
        i++;
        continue;
      }
      if (c == '}') {
        if (depth.last == 0) {
          // 插值结束 → 回到字符串态（顶层没有可弹的代码态）
          if (isStr.length > 1) {
            isStr.removeLast();
            depth.removeLast();
          }
          i++;
          continue;
        }
        depth[depth.length - 1]--;
        i++;
        continue;
      }
      i++;
      continue;
    }

    // ============================ 字符串态 ============================
    final isRaw = raw.last;
    final d = delim.last;

    if (!isRaw && src[i] == r'\') {
      i += 2; // 转义：连同下一个字符一起跳过，`\'` 不算结束
      continue;
    }
    if (src.startsWith(d, i)) {
      i += d.length;
      isStr.removeLast();
      delim.removeLast();
      raw.removeLast();
      final lit = buf.removeLast().toString();
      if (_hasCjk(lit)) _record(path, lit);
      continue;
    }
    if (!isRaw && src[i] == r'$' && i + 1 < n && src[i + 1] == '{') {
      // 进入插值：压一层代码态；里面的字符串会各自被计数
      i += 2;
      isStr.add(false);
      depth.add(0);
      continue;
    }
    buf.last.write(src[i]);
    i++;
  }
}

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    stderr.writeln('在项目根目录运行（找不到 lib/）');
    exitCode = 1;
    return;
  }

  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => !p.startsWith('lib/l10n/'))
      .toList()
    ..sort();

  for (final p in files) {
    scanSource(File(p).readAsStringSync(), p);
  }

  final sorted = _counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  print('== 含中文的字面量：$_stringCount 处，涉及 ${_counts.length}/${files.length} 个文件 ==');
  print('');
  print('按文件（含例样）：');
  for (final e in sorted) {
    print('  ${e.value.toString().padLeft(4)}  ${e.key}');
    for (final s in _byFile[e.key]!) {
      print('        · $s');
    }
  }
  print('');
  print('已清零的文件（${files.length - _counts.length} 个）：');
  final clean = files.where((p) => !_counts.containsKey(p)).toList();
  for (final p in clean) {
    print('  ✅ $p');
  }
}
