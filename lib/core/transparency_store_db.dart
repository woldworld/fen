import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'transparency_log.dart';

/// §16 公开只追加日志的 SQLite 承载（迁移版本 26，见 `DBHelper._migrateV26`）。
///
/// **它只做三件事**，一件也不多做：
/// ① **appendOnce**：把一个叶子哈希追加进日志（同哈希只追加一次）；
/// ② **load**：把整条日志重放成一个可验证的 [TransparencyLog]；
/// ③ **snapshot**：给出当前期号（size）与 Merkle 根，供"定期锚定"用。
///
/// 刻意**不提供更新/删除接口** —— §16 的全部意义是"只可追加"。
/// 若将来有人加一个 `deleteEntry`，请在 PRD 里先删掉 §16 再动手。
///
/// 内存缓存 [TransparencyLog] 的理由：每次追加都重新 `load()` 是 O(n²)，
/// 而日志会随每条互介推进持续增长。缓存只在进程内有效，冷启动仍以库为准。
class DbTransparencyLog {
  TransparencyLog? _cache;

  Future<Database> get _db => DBHelper.db;

  /// 库中已有的叶子哈希条数（= 当前期号）。
  Future<int> get size async {
    if (_cache != null) return _cache!.size;
    final db = await _db;
    final rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM log_entries');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  /// 把整条日志**重放**成一个可验证对象。
  ///
  /// 重放依赖的只有 `leaf_hash` 列 —— 这正是 §16 想要的性质：
  /// 第三方拿到叶子哈希列表就能复算整棵树与两种证明，
  /// 不需要原始记录、不需要信任我们的数据库。
  ///
  /// ⚠️ 用 [TransparencyLog.fromEntries] 而不是逐条 `appendLeafHash`：
  /// 后者会**重算**每条 hash，使 [TransparencyLog.verifyChain] 变成同义反复
  /// （改写 leaf_hash 也查不出来）。这里必须**保留持久化时算出的 hash**，
  /// 链自检才是真的在自检。见 `TransparencyLog.fromEntries` 的说明。
  Future<TransparencyLog> load() async {
    if (_cache != null) return _cache!;
    final db = await _db;
    final rows = await db.query('log_entries', orderBy: 'idx ASC');
    final log = TransparencyLog.fromEntries(
        [for (final r in rows) LogEntry.fromMap(Map<String, dynamic>.from(r))]);
    _cache = log;
    return log;
  }

  /// 追加一个**叶子哈希**（幂等：已存在则原样返回已有条目）。
  ///
  /// 幂等很重要：同一条互介在"发起→互允→结果→追认"四步各推进一次，
  /// 若第三步的叶子哈希与第一步恰好相同（理论上不会，但接口必须自洽），
  /// 也不该在公开日志里出现两条一样的叶子。
  Future<LogEntry> appendOnce(String leafHash) async {
    final log = await load();
    final existing = await _findByLeafHash(leafHash);
    if (existing != null) return existing;
    final e = await log.appendLeafHash(leafHash);
    final db = await _db;
    await db.insert('log_entries', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return e;
  }

  /// 当前期号 + Merkle 根（"定期锚定"只需这两个值）。
  ///
  /// 锚定方式见 PRD §16：把 root 发布到 **GitHub 签名提交**（时间戳由提交
  /// 历史提供）或 OpenTimestamps。本方法只负责产出待锚定的值。
  Future<({int size, String root})> snapshot() async {
    final log = await load();
    return (size: log.size, root: await log.root());
  }

  /// 哈希链自检：任一条被改写/删除/插入都会返回 false。
  Future<bool> verifyChain() async => (await load()).verifyChain();

  /// 清空内存缓存（库被外部改动后强制重新加载）。
  void invalidate() => _cache = null;

  Future<LogEntry?> _findByLeafHash(String leafHash) async {
    // 先查内存缓存里的条目（绝大多数命中都在这里，省一次 DB 往返）
    final cached = _cache;
    if (cached != null) {
      for (final e in cached.entries) {
        if (e.leafHash == leafHash) return e;
      }
      return null;
    }
    final db = await _db;
    final rows = await db.query('log_entries',
        where: 'leaf_hash = ?', whereArgs: [leafHash], limit: 1);
    if (rows.isEmpty) return null;
    return LogEntry.fromMap(rows.first);
  }
}
