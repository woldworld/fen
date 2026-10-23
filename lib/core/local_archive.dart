/// 本地数据加密导出 / 导入（`.dahuang`）——「数据也随人走」的 P1 落点。
///
/// 见 `lib/身份可携带与恢复方案.md` §P1 与 PRD §9.1「本地优先、**可导出可删除**」。
///
/// ---------------------------------------------------------------------------
/// ★ 定位：**归档 ≠ 身份**，这是两个不同的东西（别混）
/// ---------------------------------------------------------------------------
/// | 文件 | 里面装什么 | 决定什么 | 谁生成 |
/// |---|---|---|---|
/// | **恢复码**（`FENBK1`，`key_backup.dart`） | **种子**（身份本身） | "你还是不是你" | 备份身份 |
/// | **归档 `.dahuang`**（`FENARC1`，本文件） | **数据**（身份记录 / 社交图 / 日志锚点 …） | "你的记录还在不在" | 导出本地数据 |
///
/// ⇒ **归档里刻意不放种子**。理由不是省事，是**责任边界**：
/// "数据可携带"与"身份可恢复"本来就是两件事（方案文档 §1），
/// 把种子塞进归档会让**一个凭证同时决定两件事** ——
/// 于是"我只想导个记录"就等于"我把身份也交了出去"。
/// 两者分开后，各自的丢失后果各自可控。
///
/// ---------------------------------------------------------------------------
/// 为什么是"**全量（动态枚举）减去一张诊断黑名单**"，而不是写死一张表清单
/// ---------------------------------------------------------------------------
/// 写死清单有个隐蔽的失败形态：**以后新增的用户表会被静默漏掉** ——
/// 用户以为导出了全部，实际少了一块，而且**看不出来**。
/// 所以这里反过来：用 `sqlite_master` **动态枚举**（新表自动纳入），
/// 再减去一张**显式的**「诊断 / 瞬态」黑名单（见 [ArchiveFormat.excludedTables]）。
/// 风险方向因此变成"多带一点"（可接受）而不是"少带一块"（不可接受）。
///
/// ---------------------------------------------------------------------------
/// 导入是**先校验、再接续**，不是"解压即覆盖"
/// ---------------------------------------------------------------------------
/// ★ §16 透明日志的硬约束：叶子与 `(size, root)` 必须能**接续** ——
/// 断档恰恰是哈希链**原理上查不出来**的那类失效。
/// 所以导入前先把本机日志与归档逐条比对（[ArchiveFormat.logContinuity]）：
/// 本机必须是归档的**前缀**，否则拒绝导入并报 `log_mismatch`，由人决定怎么办。
///
/// ★ **格式与纯函数在 `archive_format.dart`**（零平台依赖、可离线复算）；
/// 本文件只负责**落库那半边**（`DBHelper` → `sqflite` → Flutter，CLI 里编不出来）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'archive_format.dart';
import 'db_helper.dart';
import 'key_backup.dart';

export 'archive_format.dart'
    show ArchiveFault, ArchiveFormat, ArchiveInspection;

abstract final class LocalArchive {
  /// 归档格式版本（= [ArchiveFormat.version]，转发一份便于调用方少记一个名字）。
  static const int formatVersion = ArchiveFormat.version;

  /// 归档 kind 标记。
  static const String kind = ArchiveFormat.kind;

  /// 不进归档的诊断 / 瞬态表。
  static Set<String> get excludedTables => ArchiveFormat.excludedTables;

  // ---------------------------------------------------------------- 落库

  /// 本机实际存在、且**应当**进归档的表（动态枚举 − 黑名单）。
  ///
  /// 动态枚举的好处：**以后新增的用户表自动纳入** ——
  /// 否则"导出了全部"这句话会在某次加表之后悄悄变成假话。
  static Future<List<String>> archiveTables() async {
    final db = await DBHelper.db;
    final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    final names = rows
        .map((r) => (r['name'] ?? '').toString())
        .where(
            (n) => n.isNotEmpty && !ArchiveFormat.excludedTables.contains(n))
        .toList()
      ..sort();
    return names;
  }

  /// 收集本机数据成归档载荷（**只读**，不改任何状态）。
  static Future<Map<String, Object?>> collect({int? nowMs}) async {
    final db = await DBHelper.db;
    final tables = <String, Object?>{};
    for (final name in await archiveTables()) {
      final rows = await db.query(name);
      tables[name] =
          rows.map((r) => Map<String, Object?>.from(r)).toList(growable: false);
    }

    final logRows = await db.query('log_entries', orderBy: 'idx ASC');
    final size = logRows.length;
    final root = logRows.isEmpty ? '' : (logRows.last['hash'] ?? '').toString();

    return {
      'kind': kind,
      'version': formatVersion,
      'exported_at': nowMs ?? DateTime.now().millisecondsSinceEpoch,
      'tables': tables,
      // ★ 日志锚点单独再放一份：第三方只看这两个数就能判断"这份归档是不是接得上"
      'log_anchors': {'size': size, 'root': root},
    };
  }

  /// 导出成口令加密的 `.dahuang` 文本。
  static Future<String> export({
    required String password,
    int? nowMs,
  }) async {
    final payload = await collect(nowMs: nowMs);
    final bytes = utf8.encode(ArchiveFormat.encode(payload));
    return KeyBackup.sealBlob(payload: bytes, password: password);
  }

  /// 打开归档文本 → 载荷（Map），或 [BackupError] / [ArchiveFault] 码。
  ///
  /// 返回值的三种形态都要处理：
  ///   * `Map` ⇒ 成功；
  ///   * `BackupError` ⇒ 口令错 / 格式不是 blob；
  ///   * `String`（[ArchiveFault] 码）⇒ blob 解开了，但内容不是归档。
  static Future<Object> open(String blob, {required String password}) async {
    final opened = await KeyBackup.openBlob(blob, password: password);
    if (opened is! Uint8List) return opened; // BackupError 原样透出
    final text = utf8.decode(opened, allowMalformed: false);
    return ArchiveFormat.decode(text);
  }

  /// 导入前检查（**不改本机任何状态**）—— 供 UI 先给用户看"将写入什么"。
  static Future<Object> inspect(Map<String, Object?> payload) async {
    final tables = Map<String, Object?>.from(payload['tables'] as Map);
    final counts = <String, int>{};
    tables.forEach((k, v) {
      if (v is List) counts[k] = v.length;
    });

    final anchors = payload['log_anchors'];
    final logSize =
        anchors is Map ? ((anchors['size'] as num?)?.toInt() ?? 0) : 0;
    final logRoot = anchors is Map ? (anchors['root'] ?? '').toString() : '';

    final db = await DBHelper.db;
    final localLog = await db.query('log_entries', orderBy: 'idx ASC');
    final archiveLog = <Map<String, Object?>>[
      if (tables['log_entries'] is List)
        ...(tables['log_entries'] as List)
            .map((e) => Map<String, Object?>.from(e as Map)),
    ];
    final fault = ArchiveFormat.logContinuity(localLog, archiveLog);

    return ArchiveInspection(
      version: (payload['version'] as num?)?.toInt() ?? 0,
      exportedAt: (payload['exported_at'] as num?)?.toInt() ?? 0,
      counts: counts,
      logSize: logSize,
      logRoot: logRoot,
      localLogEmpty: localLog.isEmpty,
      logFault: fault,
    );
  }

  /// 真正写入。**调用方必须先经 [inspect] 且确认 [ArchiveInspection.importable]**。
  ///
  /// 写入纪律：
  ///   * 逐表 `INSERT OR IGNORE` —— **冲突即保留本机已有**（不覆盖、不删除）；
  ///   * `log_entries` 最后写：它是"可监督"的承诺所在，宁可少写不可写错；
  ///   * ⚠️ **不做任何 DELETE** —— 导入永远只增不减，用户想删应当显式删除。
  static Future<Map<String, int>> apply(Map<String, Object?> payload) async {
    final db = await DBHelper.db;
    final tables = Map<String, Object?>.from(payload['tables'] as Map);
    final written = <String, int>{};

    // log_entries 放最后（先把数据写进去，最后接续日志）
    final names = tables.keys.toList()
      ..sort((a, b) => a == 'log_entries'
          ? 1
          : (b == 'log_entries' ? -1 : a.compareTo(b)));

    for (final name in names) {
      final rows = tables[name];
      if (rows is! List) continue;
      var n = 0;
      for (final row in rows) {
        if (row is! Map) continue;
        try {
          await db.insert(
            name,
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          n++;
        } catch (_) {
          // 单行写不进去（结构变更导致列不匹配等）不该中断整次导入 ——
          // 但也不静默：written 记的是"尝试通过的行数"，
          // 差异可由调用方用 inspect().counts 对照发现。
        }
      }
      written[name] = n;
    }
    return written;
  }
}
