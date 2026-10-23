// 纯 Dart 校验脚本：**存储键的读写接线守卫**。
// 运行：dart run tool/verify_data_keys.dart
//
// ## 抓的是什么
//
// 一类**编译期无错、运行时不抛、只表现为"某个值永远是默认值/空"**的缺陷：
// **读了一个全项目没有任何写入方的键**。
//
// 真实案例（2026-09-27，两处同时存在、且都活过了四证验收）：
//
// | 读取点 | 实际写入方 | 后果 |
// |---|---|---|
// | `DBHelper.getAmbassador('owner_name')` | **无** | 铁律 1 的首次披露文案永远退化成"我主人" |
// | `prefs.getString('soul_mask_profile')` | **无** | 发给 Hub 的跨设备马甲永远是兜底值"保密" |
//
// 两处都不是笔误，而是**接线接错了存储**：写方用 A 存储，读方查 B 存储。
// 静态分析（analyze）查不出来 —— 它只看类型，不看"这个键有没有人来写"；
// 单元测试也查不出来 —— 除非有人专门断言"这个值真的来过"。
//
// ## 覆盖哪两套存储
//
// ① **ambassador 表**：`getAmbassador(k)` / `saveAmbassador(k, v)`
//    ＋ 播种用的 `insert('ambassador', {'key': k, ...})`；
// ② **SharedPreferences**：`prefs.getString(k)` 等取用 / `prefs.setString(k, v)` 等写入。
//
// ## 四个必须做对的地方（第一版全踩了）
//
// **(a) 必须先剥注释再扫描。** 否则文档里"当反面例子引用"的代码会被算成真实调用：
//     第一版因为注释里写了"曾经读 `getAmbassador('owner_name')`"，
//     把已经修好的缺陷又报了一次红。**判据被自己的说明文字污染**，
//     这种误报比不设守卫更糟 —— 它会让人把整条检查关掉。
//
// **(b) 接收者固定为 `prefs`，不要泛化成 `\w+`。** 泛化会把
//     `List.remove(x)` / `Map.remove(k)` 当成"删 prefs 键"，一次报出 20 个假动态键。
//     已核实全仓 SharedPreferences 调用接收者**都是 `prefs`**。
//
// **(c) 要能解析"限定名常量"与"裸常量"。** `prefs.getBool(DeviceControlService.enabledPref)`
//     第一次被误报成动态键；`_algKey` / `allowKey` 这类则完全不在字面量扫描里。
//     做法：建全局 `常量名 → 字面量集合`，**只在唯一时**解析（歧义即报动态，交人判断）。
//
// **(d) 要排除"方法定义自身"。** `getAmbassador(String key)` 的形参类型 `String`
//     会被参数正则吃成"键名"。凡是解析不出来、且末段是**类型名**的，一律跳过。
//
// ## 盲区（显式声明，不假装覆盖）
//
// 用**变量或字符串插值**拼出的键无法静态穷举。本脚本把这些位置**逐条列出**，
// 并断言其清单与 `_expectedDynamic` 完全一致：新增一处就必须显式登记 ——
// 否则动态键会成为绕过守卫的后门。

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

// ---------------------------------------------------------------------------
// 源码收集与注释剥离
// ---------------------------------------------------------------------------

/// 统一用 `/` 分隔，保证登记表跨平台稳定。
String _norm(String path) => path.replaceAll(r'\', '/');

List<File> _dartFiles() =>
    (Directory('lib').listSync(recursive: true).whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
        .where((f) => f.path.endsWith('.dart'))
        .toList();

/// 去注释，但**保留字符串里的 `//` 与 `/* */`**（本项目有大量 `https://`）。
String _stripComments(String src) {
  final out = StringBuffer();
  final n = src.length;
  var i = 0;
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
    if (c == 'r' && i + 1 < n && (src[i + 1] == "'" || src[i + 1] == '"')) {
      out.write(c);
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      final q = c;
      final triple = i + 2 < n && src[i + 1] == q && src[i + 2] == q;
      final delim = triple ? q * 3 : q;
      out.write(delim);
      i += delim.length;
      while (i < n && !src.startsWith(delim, i)) {
        if (src[i] == r'\' && i + 1 < n) {
          out.write(src[i]);
          i++;
        }
        out.write(src[i]);
        i++;
      }
      if (i < n) {
        out.write(delim);
        i += delim.length;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

final _constDecl =
    RegExp(r"(?:static\s+)?const\s+String\s+(\w+)\s*=\s*'([^']*)'");

/// 形参类型名（这些不是键）。
const _typeNames = {
  'String',
  'int',
  'bool',
  'double',
  'List',
  'Map',
  'Object',
  'dynamic',
  'num',
};

/// 键的来源判定。
class _KeyHit {
  final String? literal; // 非空 = 字面量键
  final String? dynamicDesc; // 非空 = 动态（盲区），附人类可读描述
  const _KeyHit.literal(this.literal) : dynamicDesc = null;
  const _KeyHit.dynamic(this.dynamicDesc) : literal = null;
  const _KeyHit.skip()
      : literal = null,
        dynamicDesc = null;
}

// ---------------------------------------------------------------------------
// 匹配式与分类器（**提到顶层**，唯一的理由是：能被"扫描器自检"直接调用）
//
// 原来它们在 main() 里当局部变量 —— 那意味着**无法对它们做任何断言**：
// 正则写错一个字符、接收者从 `prefs` 被改名、常量解析规则被改坏……
// 本脚本都会安静地扫到 0 处，然后 `read.difference(write).isEmpty` 恒真 → 全绿。
// 这正是"恒假检查"：守卫自己失效时**报的是绿灯**。提到顶层做 positive control 修掉它。
// ---------------------------------------------------------------------------

/// SharedPreferences 调用：接收者固定 `prefs`（见文件头 (b)）。
final _prefsCall = RegExp(
    r"prefs\.(getString|getBool|getInt|getDouble|getStringList|setString|setBool|setInt|setDouble|setStringList|remove)\(\s*(?:'([^']*)'|([\w.]+))");

/// ambassador 表读 / 写 / 播种插入。
final _ambReadRe = RegExp(r"getAmbassador\(\s*(?:'([^']*)'|([\w.]+))");
final _ambWriteRe = RegExp(r"saveAmbassador\(\s*(?:'([^']*)'|([\w.]+))");
final _ambInsertRe = RegExp(r"insert\(\s*'ambassador'\s*,\s*\{([\s\S]{0,400}?)\}");
final _keyFieldRe = RegExp(r"'key'\s*:\s*(?:'([^']*)'|([\w.]+))");

/// 把实参归一化；返回 `skip` 表示"跳过"（如方法定义 `getAmbassador(String key)`）。
_KeyHit _classify(String? literal, String? ident, String filePath,
    Map<String, Set<String>> constByName) {
  if (literal != null) {
    return literal.contains(r'$')
        ? _KeyHit.dynamic(literal)
        : _KeyHit.literal(literal);
  }
  if (ident == null) return const _KeyHit.skip();
  final last = ident.contains('.') ? ident.split('.').last : ident;
  if (_typeNames.contains(last)) return const _KeyHit.skip(); // (d)
  final vals = constByName[last];
  if (vals != null && vals.length == 1) return _KeyHit.literal(vals.first);
  return _KeyHit.dynamic('$ident@$filePath');
}

// ---------------------------------------------------------------------------
// 已知动态键（**显式登记**才放行；新增一处就必须在这里加一行）
// ---------------------------------------------------------------------------

const _expectedDynamic = <String>{
  r'$_pinPrefix$agentId', // session_crypto：TOFU 钉扎键 = 前缀 + agentId
  r'$_retiredPrefix$id', // agent_identity：我退休过的公钥 = 前缀 + agentId
  //   （M6 履历随人走：换钥后旧钥名下收到的背书仍要认领 —— 本地这一份让离线也算得出来）
  r'$_dismissedKeyPrefix${v.name}', // rom_guide_service：ROM 引导"已忽略"标记 = 前缀 + 枚举名
  //   （写入方见 rom_guide_service.dart:117 `setBool` —— 已核：读在 :111、写在 :117，确有写入方。
  //    ★ 本条由 v0.33.0 全量回归**首次扫出**并登记：该模块属工作区中尚未纳入本轮审计的未跟踪文件，
  //      而"动态键必须显式登记"这条守卫**不区分来源** —— 扫到就得过一遍，不能因为是别人的代码就放过。）
  'k@lib/core/session_crypto.dart', // warmUp：k 来自 prefs.getKeys() 过滤
  'cursorKey@lib/core/cloud_service.dart', // 邮箱游标 = cloud_cursor_<agentId>
  'cursorKey@lib/core/world_service.dart', // 世界频道游标（同上拼法）
  'key@lib/core/db_helper.dart', // saveAmbassador 自身实现（insert 时 key 是形参）
  'key@lib/core/radar_service.dart', // 通道开关 setBool(key, value)
  r'world_last_decision_$roomId', // world_service：按房间存最近决策
  r'world_room_autoreply_$_roomId', // world_service：按房间存自动回复开关
  r'world_room_autoreply_${cmd.roomId}', // world_service：同上（另一处拼法）
  '_cacheKey@lib/core/world_service.dart', // ★ 0.40.0 新增：房间历史落盘键
  //   `world_room_cache_<agentId>` —— 读在 `_persistCache` / `loadPersistedCache`，
  //   写在 `_persistCache` 的 `prefs.setString(_cacheKey(myAgentId), …)`，确有写入方。
  //   （本条由 v0.40.0 全量回归**首次扫出**并登记：动态键必须显式登记，新增一处登记一处。）
  '_key@lib/core/mail/mail_credential_store.dart', // ★ 0.64.0 新增：邮箱口令键 `mail_secret_<accountId>`
  //   读（`secretOf` / `has`）与写（`save`）/ 删（`forget`）**同在一个文件、共用同一个
  //   `_key(accountId)` 方法**，确有写入方；`accountId` 是**运行时值** ⇒ 无法静态穷举，
  //   按纪律显式登记。（本条的形态与上面的 `_cacheKey@world_service` 完全同款。）
};

void main() {
  print('--- 扫描源码（已剥注释）---');
  final files = _dartFiles();
  final stripped = <String, String>{
    for (final f in files) _norm(f.path): _stripComments(f.readAsStringSync()),
  };
  print('  ${files.length} 个 Dart 文件');

  // 全局常量表：名字 → 字面量集合（>1 个值 = 歧义，不作解析）
  final constByName = <String, Set<String>>{};
  for (final src in stripped.values) {
    for (final m in _constDecl.allMatches(src)) {
      constByName.putIfAbsent(m.group(1)!, () => <String>{}).add(m.group(2)!);
    }
  }

  // -------------------------------------------------------------------------
  print('');
  print('--- ⓿ 扫描器自检（positive control）---');
  // 这一节存在的唯一理由：本脚本是**其它所有代码的守卫**，但它自己此前**没有任何自检**。
  // 若匹配式 / 分类器因重构而失效，它会扫到 0 处读键 → `difference` 恒空 → 恒绿。
  // 守卫自己失效时**报绿灯**，比没有守卫更危险（错觉式保护）。所以先证明"扫得到"。
  check(files.length >= 50, '扫描到 ${files.length} 个 Dart 文件（≥50，证明 lib/ 树被真正走到）');
  check(stripped.containsKey('lib/core/db_helper.dart'),
      '关键文件 lib/core/db_helper.dart 在扫描集合内（不是扫了个空）');

  // 剥注释必须有效：文档里"当反面教材引用"的调用**不得**被算成真实读写。
  const noteThenCall =
      "// 曾经读 getAmbassador('ghost_key') 是缺陷\nsaveAmbassador('real_key', v);";
  final strippedNote = _stripComments(noteThenCall);
  check(!strippedNote.contains('ghost_key') && strippedNote.contains('real_key'),
      '注释里的引用被剥掉、真实调用被保留（_stripComments 有效）');

  // 分类器正例：植入一处"读了没人写"，必须被认成**字面量读键**。
  final plantedHit = _ambReadRe
      .firstMatch(_stripComments("final w = getAmbassador('PLANTED_ORPHAN_KEY');"));
  final plantedLit = plantedHit == null
      ? null
      : _classify(plantedHit.group(1), plantedHit.group(2), 'synthetic', constByName)
          .literal;
  check(plantedLit == 'PLANTED_ORPHAN_KEY',
      '植入 getAmbassador(…) 被分类为字面量读键（匹配式 + 分类器有效）');

  // 分类器反例：方法定义 `getAmbassador(String key)` 的形参类型名必须被跳过（(d) 规则）。
  final defHit = _ambReadRe.firstMatch('getAmbassador(String key)');
  final defLit = defHit == null
      ? null
      : _classify(defHit.group(1), defHit.group(2), 'synthetic', constByName).literal;
  check(defLit == null, '方法定义 getAmbassador(String key) 被跳过（形参类型名不误报）');

  final ambRead = <String>{};
  final ambWritten = <String>{};
  final prefsRead = <String>{};
  final prefsWritten = <String>{};
  final dynamicKeys = <String>{};

  const getters = {
    'getString',
    'getBool',
    'getInt',
    'getDouble',
    'getStringList',
  };

  void take(_KeyHit hit, void Function(String) onLiteral) {
    if (hit.dynamicDesc != null) {
      dynamicKeys.add(hit.dynamicDesc!);
    } else if (hit.literal != null) {
      onLiteral(hit.literal!);
    }
  }

  stripped.forEach((path, src) {
    for (final m in _prefsCall.allMatches(src)) {
      final method = m.group(1)!;
      take(_classify(m.group(2), m.group(3), path, constByName), (k) {
        (getters.contains(method) ? prefsRead : prefsWritten).add(k);
      });
    }
    for (final m in _ambReadRe.allMatches(src)) {
      take(_classify(m.group(1), m.group(2), path, constByName), ambRead.add);
    }
    for (final m in _ambWriteRe.allMatches(src)) {
      take(_classify(m.group(1), m.group(2), path, constByName), ambWritten.add);
    }
    for (final m in _ambInsertRe.allMatches(src)) {
      for (final k in _keyFieldRe.allMatches(m.group(1)!)) {
        take(_classify(k.group(1), k.group(2), path, constByName), ambWritten.add);
      }
    }
  });

  // -------------------------------------------------------------------------
  print('');
  print('--- ① ambassador 表：读键必须有写方 ---');
  print('  读 ${ambRead.length} 个：${(ambRead.toList()..sort()).join(', ')}');
  print('  写 ${ambWritten.length} 个：${(ambWritten.toList()..sort()).join(', ')}');
  final ambMissing = ambRead.difference(ambWritten).toList()..sort();
  check(ambMissing.isEmpty,
      'ambassador 无"读了没人写"的键${ambMissing.isEmpty ? '' : '（缺写入方：${ambMissing.join(', ')}）'}');

  print('');
  print('--- ② SharedPreferences：读键必须有写方 ---');
  print('  读 ${prefsRead.length} 个：${(prefsRead.toList()..sort()).join(', ')}');
  print('  写 ${prefsWritten.length} 个：${(prefsWritten.toList()..sort()).join(', ')}');
  final prefsMissing = prefsRead.difference(prefsWritten).toList()..sort();
  check(prefsMissing.isEmpty,
      'prefs 无"读了没人写"的键${prefsMissing.isEmpty ? '' : '（缺写入方：${prefsMissing.join(', ')}）'}');

  // -------------------------------------------------------------------------
  print('');
  print('--- ③ 动态键（盲区）必须显式登记，不得偷偷增长 ---');
  final dyn = dynamicKeys.toList()..sort();
  print('  共 ${dyn.length} 处：');
  for (final d in dyn) {
    print('    · $d');
  }
  final unexpected = dyn.toSet().difference(_expectedDynamic).toList()..sort();
  final gone = _expectedDynamic.difference(dyn.toSet()).toList()..sort();
  check(unexpected.isEmpty,
      '没有未登记的动态键${unexpected.isEmpty ? '' : '（新增：${unexpected.join(', ')}）'}');
  check(gone.isEmpty, '登记表没有过期项${gone.isEmpty ? '' : '（已消失：${gone.join(', ')}）'}');

  // -------------------------------------------------------------------------
  print('');
  print('--- ④ 历史死键不得复活（钉住本轮的架构决定）---');
  // 这条不是 ①② 的重复：若有人既恢复了读取、又顺手补了个写入方，①② 会过。
  // 但"主人称呼 / 马甲该存哪儿"是**架构决定**，不能靠"两边都写"来蒙混。
  check(!ambRead.contains('owner_name'),
      "ambassador 'owner_name' 不得再被读取（主人称呼唯一来源 = prefs['soul_master_name']）");
  check(!prefsRead.contains('soul_mask_profile'),
      "prefs 'soul_mask_profile' 不得再被读取（马甲唯一来源 = ambassador 'mask_profile'）");
  check(!ambWritten.contains('owner_name'),
      "ambassador 'owner_name' 也不应有写入方（避免与 prefs 形成双写）");
  check(!prefsWritten.contains('soul_mask_profile'),
      "prefs 'soul_mask_profile' 也不应有写入方（避免与 ambassador 形成双写）");

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
