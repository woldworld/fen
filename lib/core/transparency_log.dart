/// §16 · 可验证性：闭源信任层的补位机制（PRD 新增章节）。
///
/// **问题**：客户端开源只能覆盖客户端，**覆盖不到真正的信任层**（Hub 闭源）。
/// **解法**：**"你不必相信我，你可以验我。"**
///
/// 参照物是**证书透明度（Certificate Transparency, CT）**——它解决的是完全同构的问题：
/// CA 闭源、不可完全信任，但不能让它作恶。做法是**所有签发都进公开、只可追加的日志**，
/// 任何人都能下载日志、验证自己的记录、检查日志有没有被篡改。
/// 因此本文件**逐条对齐 RFC 6962**（CT 的 Merkle 树定义），而不是自创一套：
///
/// | CT / RFC 6962 | 本文件 |
/// |---|---|
/// | `MTH`（Merkle Tree Hash） | [_mth] |
/// | Inclusion proof（§2.1.1） | [TransparencyLog.inclusionProof] / [MerkleVerify.inclusion] |
/// | Consistency proof（§2.1.2） | [TransparencyLog.consistencyProof] / [MerkleVerify.consistency] |
/// | 公开只追加日志 | [TransparencyLog]（哈希链，任何改动都会断链） |
///
/// **为什么"只发 root 不够"**（PRD §16 原话）：
/// 单独一个 root 无法证明**你自己的账本有没有被事后篡改**；
/// 一致性证明才能证明"第 N 期是第 N−1 期的延续"。
/// 所以本文件把一致性证明作为一等公民，而不是可选项。
///
/// **它同时是商业主张的合法性来源**：我们说"名字、身份、信誉必须回来找我"之所以不流氓，
/// 是因为**"找我可以被公开检验"**。没有这一层，闭源信任层就是一句无法证伪的自我声明。
///
/// **与 M10 的合流**（PRD §16.1）：同一棵树、同一个 monitor、同一期透明报告，
/// 同时承载"身份与信誉记录"与"贡献账本"——所以本文件刻意做成**与业务无关的通用结构**，
/// 叶子的语义由调用方决定。
///
/// 本文件**零平台依赖**（不 import Flutter / sqflite）：
/// `dart run tool/verify_transparency_log.dart` 可离线复算全部证明。

library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'agent_protocol.dart';

// RFC 6962 域分隔字节：叶子用 0x00，内部节点用 0x01。
// 这不是可选的风格问题 —— 没有它，一棵树的叶子与内部节点可能算出相同哈希，
// 攻击者就能用内部节点冒充叶子提交一条"Inclusion proof"（二级原像攻击）。
const int _leafPrefix = 0x00;
const int _nodePrefix = 0x01;

Uint8List _cat(List<int> a, List<int> b) {
  final out = Uint8List(a.length + b.length);
  out.setRange(0, a.length, a);
  out.setRange(a.length, out.length, b);
  return out;
}

/// 日志的一条记录。
///
/// [hash] 把 [prevHash] 一起纳入 —— 于是**改任何一条历史记录都会让它之后
/// 所有记录的 hash 对不上**（哈希链），这是"只可追加"的实现方式。
class LogEntry {
  final int index;

  /// 叶子哈希（RFC 6962：`SHA-256(0x00 || leaf)`），base58。
  final String leafHash;

  /// 前一条的 [hash]；第 0 条为 `''`。
  final String prevHash;

  /// 本条哈希（`SHA-256(index | leafHash | prevHash)`），base58。
  final String hash;

  const LogEntry({
    required this.index,
    required this.leafHash,
    required this.prevHash,
    required this.hash,
  });

  Map<String, Object?> toMap() => {
        'idx': index,
        'leaf_hash': leafHash,
        'prev_hash': prevHash,
        'hash': hash,
      };

  static LogEntry fromMap(Map<String, dynamic> m) => LogEntry(
        index: (m['idx'] as num).toInt(),
        leafHash: (m['leaf_hash'] ?? '').toString(),
        prevHash: (m['prev_hash'] ?? '').toString(),
        hash: (m['hash'] ?? '').toString(),
      );
}

/// 包含证明：某一片叶子在某棵树里的兄弟路径（RFC 6962 §2.1.1 顺序）。
class MerkleProof {
  final int index;
  final int treeSize;
  final List<String> path; // base58，从底往上

  const MerkleProof({
    required this.index,
    required this.treeSize,
    required this.path,
  });

  Map<String, Object?> toMap() =>
      {'index': index, 'tree_size': treeSize, 'path': path};

  static MerkleProof fromMap(Map<String, dynamic> m) => MerkleProof(
        index: (m['index'] as num).toInt(),
        treeSize: (m['tree_size'] as num).toInt(),
        path: ((m['path'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}

/// 一致性证明：证明"第 [fromSize] 期是第 [toSize] 期的前缀延续"。
class ConsistencyProof {
  final int fromSize;
  final int toSize;
  final List<String> path;

  const ConsistencyProof({
    required this.fromSize,
    required this.toSize,
    required this.path,
  });

  Map<String, Object?> toMap() => {
        'from_size': fromSize,
        'to_size': toSize,
        'path': path,
      };

  static ConsistencyProof fromMap(Map<String, dynamic> m) => ConsistencyProof(
        fromSize: (m['from_size'] as num).toInt(),
        toSize: (m['to_size'] as num).toInt(),
        path: ((m['path'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}

/// 只追加日志（RFC 6962 Merkle 树）。
///
/// **只保存叶子哈希，不保存叶子原文** —— 这是刻意的：
/// ① 第三方要复算整棵树、验任何一条证明，只需要 `leafHash` 列表（§16 的 monitor）；
/// ② 若同时保存原文，重放路径与本地路径会算出不同结果（原文缺失时只能传空），
///    那才是真正的 bug 源头。哈希是唯一的权威。
class TransparencyLog {
  final List<String> _leafHashes = [];
  final List<LogEntry> _entries = [];

  TransparencyLog();

  /// 用**已持久化的条目**播种（把库里的日志重放成可验证对象时用）。
  ///
  /// ⚠️ 与逐条 [appendLeafHash] 的**关键区别**：这里**沿用每条自带的 `hash`**，
  /// 而不是拿 `leaf_hash` 现算一遍。
  ///
  /// 为什么这一点是硬要求（真机用例抓到过）：若重放时重算，则
  /// [verifyChain] 的"应有值"和"记录值"**都由同一份（可能已被篡改的）
  /// `leaf_hash` 现算**，两边必然相等 → 链自检退化成**同义反复**，
  /// 于是"改一行 `leaf_hash`、删一行、改 `prev_hash`"全都查不出来。
  /// 只有保留持久化时的 hash，重算值才可能与它不等，[verifyChain] 才有意义。
  factory TransparencyLog.fromEntries(Iterable<LogEntry> entries) {
    final log = TransparencyLog();
    for (final e in entries) {
      log._entries.add(e);
      log._leafHashes.add(e.leafHash);
    }
    return log;
  }

  int get size => _leafHashes.length;
  bool get isEmpty => _leafHashes.isEmpty;
  List<LogEntry> get entries => List.unmodifiable(_entries);
  List<String> get leafHashes => List.unmodifiable(_leafHashes);
  LogEntry? get last => _entries.isEmpty ? null : _entries.last;

  // ---- 哈希原语（全部按 RFC 6962）----

  static Future<List<int>> _sha256(List<int> bytes) async =>
      (await Sha256().hash(bytes)).bytes;

  static List<int> _dec(String b58) => AgentProtocol.base58Decode(b58);

  /// `MTH({}) = SHA-256()` —— 空树根（不是零、不是空串）。
  static Future<String> emptyRoot() async =>
      AgentProtocol.base58Encode(await _sha256(const []));

  static Future<List<int>> _leafHash(List<int> leaf) =>
      _sha256(_cat(const [_leafPrefix], leaf));

  /// 计算某片叶子的哈希（第三方可独立复算）。
  static Future<String> leafHashOf(List<int> leaf) async =>
      AgentProtocol.base58Encode(await _leafHash(leaf));

  static Future<List<int>> _nodeHash(List<int> l, List<int> r) =>
      _sha256(_cat(const [_nodePrefix], _cat(l, r)));

  /// 最大的、**严格小于** n 的 2 的幂（RFC 6962 的 k）。
  ///
  /// 只在 `n > 1` 时有意义 —— RFC 的 `D[n]` 分解假设 `n ≥ 2`。
  static int largestPowerOfTwoLessThan(int n) {
    if (n <= 1) {
      throw ArgumentError('largestPowerOfTwoLessThan requires n > 1, got $n');
    }
    var k = 1;
    while (k << 1 < n) {
      k <<= 1;
    }
    return k;
  }

  /// `MTH(leaves[lo..hi))`（半开区间）。叶子哈希取自 [_leafHashes]。
  Future<List<int>> _mth(int lo, int hi) async {
    if (hi - lo == 1) return _dec(_leafHashes[lo]);
    final k = largestPowerOfTwoLessThan(hi - lo);
    final l = await _mth(lo, lo + k);
    final r = await _mth(lo + k, hi);
    return _nodeHash(l, r);
  }

  // ---- 追加 ----

  /// 追加一片叶子（传原文，由本层算哈希）。
  Future<LogEntry> append(List<int> leaf) async =>
      _appendLeafHash(AgentProtocol.base58Encode(await _leafHash(leaf)));

  /// 追加一片**已有哈希**的叶子（重放第三方日志时用）。
  Future<LogEntry> appendLeafHash(String leafHash) => _appendLeafHash(leafHash);

  Future<LogEntry> _appendLeafHash(String leafHash) async {
    final prev = _entries.isEmpty ? '' : _entries.last.hash;
    final idx = _entries.length;
    // 哈希链：把序号与前一条的 hash 一起纳入 → 插入/删除/改写都会断链
    final h = AgentProtocol.base58Encode(
        await _sha256(utf8.encode('WL|$idx|$leafHash|$prev')));
    final e =
        LogEntry(index: idx, leafHash: leafHash, prevHash: prev, hash: h);
    _leafHashes.add(leafHash);
    _entries.add(e);
    return e;
  }

  // ---- Merkle 根 ----

  /// 当前树的 Merkle 根（base58）。空树返回 [emptyRoot]。
  Future<String> root() async {
    if (_leafHashes.isEmpty) return emptyRoot();
    return AgentProtocol.base58Encode(await _mth(0, _leafHashes.length));
  }

  /// 指定规模时的 Merkle 根（用于历史期比对）。
  Future<String> rootAt(int treeSize) async {
    if (treeSize == 0) return emptyRoot();
    if (treeSize < 0 || treeSize > _leafHashes.length) {
      throw RangeError('treeSize $treeSize out of range 0..${_leafHashes.length}');
    }
    return AgentProtocol.base58Encode(await _mth(0, treeSize));
  }

  /// 哈希链自检：任一条被**改写 / 改前驱 / 删中间一条**，这里都会返回 false。
  ///
  /// ⚠️ **它能查什么、不能查什么**（别把它的能力说大了）：
  /// - ✅ 改写任一条的 `leaf_hash` / `hash` / `prev_hash`；
  /// - ✅ 在中间插入或**删掉中间**一条（序号断档或 prev 接不上）；
  /// - ❌ **截断**（把**末尾**若干条删掉）—— 剩下的前缀依然是一条自洽的链，
  ///   哈希链**原理上查不出**。挡截断靠的是**外部见证**：把每期的
  ///   `(size, root)` 锚定出去（GitHub 签名提交 / OpenTimestamps，
  ///   见 [TransparencyLog.rootAt] 与 §16），下次比对"锚定期不应变短/换根"。
  ///   这两条边界由 `test/db_migration_test.dart` 的真库用例分别钉住。
  ///
  /// ⚠️ 要在"从库里重放出来的日志"上做这个检查，必须用
  /// [TransparencyLog.fromEntries] 播种（保留持久化 hash）；
  /// 若用 [appendLeafHash] 逐条重算，本方法会退化成同义反复。
  Future<bool> verifyChain() async {
    if (_entries.isEmpty) return true;
    if (_entries.first.prevHash != '') return false;
    var expectedIdx = 0;
    var prev = '';
    for (final e in _entries) {
      if (e.index != expectedIdx) return false;
      if (e.prevHash != prev) return false;
      final want = AgentProtocol.base58Encode(
          await _sha256(utf8.encode('WL|${e.index}|${e.leafHash}|${e.prevHash}')));
      if (want != e.hash) return false;
      prev = e.hash;
      expectedIdx++;
    }
    return true;
  }

  // ---- 包含证明（RFC 6962 §2.1.1 的 PATH）----

  Future<List<List<int>>> _path(int m, int lo, int hi) async {
    final n = hi - lo;
    if (n == 1) return <List<int>>[];
    final k = largestPowerOfTwoLessThan(n);
    if (m < k) {
      final p = await _path(m, lo, lo + k);
      p.add(await _mth(lo + k, hi));
      return p;
    }
    final p = await _path(m - k, lo + k, hi);
    p.add(await _mth(lo, lo + k));
    return p;
  }

  Future<MerkleProof> inclusionProof(int index) async {
    if (index < 0 || index >= _leafHashes.length) {
      throw RangeError('index $index out of range');
    }
    final p = await _path(index, 0, _leafHashes.length);
    return MerkleProof(
      index: index,
      treeSize: _leafHashes.length,
      path: [for (final h in p) AgentProtocol.base58Encode(h)],
    );
  }

  // ---- 一致性证明（RFC 6962 §2.1.2 的 SUBPROOF）----

  /// `SUBPROOF(m, D[lo..hi), b)`（RFC 6962 §2.1.2）。
  ///
  /// ⚠️ 两处**容易写死循环**的地方，必须显式挡住：
  /// ① RFC 只定义了 `0 < m < n`。`m == 0`（空树前缀）是退化情形，
  ///    在顶层 [consistencyProof] 直接短路，不进这里；这里的 `n == 1` 分支
  ///    是对"递归到单叶"的兜底 —— 若不挡，`m=0, n=1` 会算出 `k=1` 并
  ///    以完全相同的参数再递归一次，无限下钻。
  /// ② `largestPowerOfTwoLessThan` 在 `n <= 1` 时无意义（会抛）。
  Future<List<List<int>>> _subproof(int m, int lo, int hi, bool b) async {
    final n = hi - lo;
    if (m == n) {
      // 完全一致时：b=true 不再需要内嵌根（调用方已持有），b=false 必须带上
      return b ? <List<int>>[] : [await _mth(lo, hi)];
    }
    if (n == 1) {
      // 走到单叶而 m != n → m 只能是 0（零长度前缀），无需任何证明材料
      return <List<int>>[];
    }
    final k = largestPowerOfTwoLessThan(n);
    if (m <= k) {
      final p = await _subproof(m, lo, lo + k, b);
      p.add(await _mth(lo + k, hi));
      return p;
    }
    final p = await _subproof(m - k, lo + k, hi, false);
    p.add(await _mth(lo, lo + k));
    return p;
  }

  Future<ConsistencyProof> consistencyProof(int fromSize, int toSize) async {
    if (fromSize < 0 || toSize < fromSize || toSize > _leafHashes.length) {
      throw RangeError(
          'bad sizes from=$fromSize to=$toSize len=${_leafHashes.length}');
    }
    // m == 0：空树是任何树的前缀，属于退化情形（RFC 未定义），
    // 证明材料为空 —— 与 [MerkleVerify.consistency] 的 m==0 分支一致。
    if (fromSize == 0) {
      return ConsistencyProof(fromSize: 0, toSize: toSize, path: const []);
    }
    final p = await _subproof(fromSize, 0, toSize, true);
    return ConsistencyProof(
      fromSize: fromSize,
      toSize: toSize,
      path: [for (final h in p) AgentProtocol.base58Encode(h)],
    );
  }
}

/// 证明验证器：**静态**，因为它必须能在一个**没有日志、没有数据库**的
/// 第三方机器上运行 —— 这正是 §16"任何人可监督"的意思。
class MerkleVerify {
  static Future<List<int>> _sha256(List<int> bytes) async =>
      (await Sha256().hash(bytes)).bytes;

  static Future<List<int>> _leafHash(List<int> leaf) =>
      _sha256(_cat(const [_leafPrefix], leaf));

  static Future<List<int>> _nodeHash(List<int> l, List<int> r) =>
      _sha256(_cat(const [_nodePrefix], _cat(l, r)));

  static List<int> _dec(String b58) => AgentProtocol.base58Decode(b58);

  /// 验证"叶子 [leaf] 在 [proof].index 位置、且树规模为 [proof].treeSize、
  /// 根为 [root]"。**只需叶子本体 + 路径 + 根**，不需要整棵树。
  static Future<bool> inclusion({
    required List<int> leaf,
    required MerkleProof proof,
    required String root,
  }) async {
    final n = proof.treeSize;
    if (n <= 0 || proof.index < 0 || proof.index >= n) return false;
    final path = [for (final h in proof.path) _dec(h)];
    final r = await _verifyPath(
        await _leafHash(leaf), proof.index, n, List<List<int>>.from(path));
    if (r == null) return false;
    return AgentProtocol.base58Encode(r) == root;
  }

  /// RFC 6962 §2.1.1 的验证递归：从路径**末端**往回剥。
  static Future<List<int>?> _verifyPath(
      List<int> leafHash, int m, int n, List<List<int>> path) async {
    if (n == 1) {
      if (path.isNotEmpty) return null;
      return leafHash;
    }
    if (path.isEmpty) return null;
    final k = TransparencyLog.largestPowerOfTwoLessThan(n);
    final sib = path.removeLast();
    if (m < k) {
      final r = await _verifyPath(leafHash, m, k, path);
      if (r == null) return null;
      return _nodeHash(r, sib);
    }
    final r = await _verifyPath(leafHash, m - k, n - k, path);
    if (r == null) return null;
    return _nodeHash(sib, r);
  }

  /// 验证一致性证明：**[fromRoot] 是 [toRoot] 的前缀树**。
  ///
  /// 实现**逐句镜像生成侧的 SUBPROOF 递归**（而不是套用某份迭代实现）——
  /// 迭代版依赖证明元素的"反向读取顺序"，非常容易与生成侧错位却又"看起来能跑"。
  /// 递归镜像的好处是：**生成与验证共用同一套分解规则**，任何顺序错误会在
  /// 参数不匹配处直接暴露，而不是悄悄算出一个错根。
  ///
  /// 递归同时重建两个根：
  /// - 返回值 `$1` = 这一子树里的**前缀树根**（`MTH(D[lo..lo+m))`）；
  /// - 返回值 `$2` = 这一子树的**完整根**（`MTH(D[lo..hi))`）。
  ///
  /// `b == true` 表示"前缀根调用方已持有"（[known1] 传入），故不在证明里出现；
  /// 顶层就是 `SUBPROOF(m, D[n], true)`，[known1] = [fromRoot]。
  static Future<bool> consistency({
    required ConsistencyProof proof,
    required String fromRoot,
    required String toRoot,
  }) async {
    final m = proof.fromSize;
    final n = proof.toSize;
    if (m < 0 || n < m) return false;

    // 规模相同：证明必须为空，且两个根必须相等（RFC：SUBPROOF(m,D[m],true) = {}）
    if (m == n) {
      return proof.path.isEmpty && fromRoot == toRoot;
    }
    // 空树到任何树都是平凡一致的（RFC 未定义，取空证明）
    if (m == 0) {
      return proof.path.isEmpty;
    }

    final p = [for (final h in proof.path) _dec(h)];
    if (p.isEmpty) return false;

    final res = await _verifySubproof(m, n, true, _dec(fromRoot), p, 0);
    if (res == null) return false;
    // 必须恰好消费完整个证明（多塞元素 = 拒绝）
    return res.$3 == p.length &&
        AgentProtocol.base58Encode(res.$1) == fromRoot &&
        AgentProtocol.base58Encode(res.$2) == toRoot;
  }

  /// 递归验证 `SUBPROOF(m, D[lo..hi), b)`，从 [pos] 起消费 [proof]。
  ///
  /// 返回 `(前缀根, 子树完整根, 下一个待消费位置)`；结构不符一律返回 `null`。
  static Future<(List<int>, List<int>, int)?> _verifySubproof(
    int m,
    int n,
    bool b,
    List<int>? known1,
    List<List<int>> proof,
    int pos,
  ) async {
    // 生成侧：m == n 时 b=true 不产出（调用方已有），b=false 产出 {MTH(D[n])}
    if (m == n) {
      if (b) {
        if (known1 == null) return null;
        return (known1, known1, pos);
      }
      if (pos >= proof.length) return null;
      final h = proof[pos];
      return (h, h, pos + 1);
    }
    // m != n 且 n == 1 ⇒ m == 0，顶层已短路，此处为安全兜底
    if (n <= 1) return null;

    final k = TransparencyLog.largestPowerOfTwoLessThan(n);
    if (m <= k) {
      // 生成侧：SUBPROOF(m, D[0:k], b) : MTH(D[k:n])
      final left = await _verifySubproof(m, k, b, known1, proof, pos);
      if (left == null) return null;
      final p1 = left.$3;
      if (p1 >= proof.length) return null;
      return (left.$1, await _nodeHash(left.$2, proof[p1]), p1 + 1);
    }
    // 生成侧：SUBPROOF(m-k, D[k:n], false) : MTH(D[0:k])
    final right = await _verifySubproof(m - k, n - k, false, null, proof, pos);
    if (right == null) return null;
    final p1 = right.$3;
    if (p1 >= proof.length) return null;
    final l = proof[p1];
    return (
      await _nodeHash(l, right.$1),
      await _nodeHash(l, right.$2),
      p1 + 1,
    );
  }
}
