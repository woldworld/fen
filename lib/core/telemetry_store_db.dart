import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'telemetry.dart';

/// [TelemetryStore] 的 SQLite 实现（迁移版本 21，见 DBHelper._migrateV21）。
///
/// 存在的理由：埋点**必须落盘**。之前只有 MemoryTelemetryStore 且没人 bind，
/// M1 进圈、M2 委托完成、TTFD 这些验收指标一退出进程就没了，等于没埋。
class DbTelemetryStore extends TelemetryStore {
  Future<Database> get _db => DBHelper.db;

  @override
  Future<void> append(TelemetryEvent e) async {
    final db = await _db;
    await db.insert('telemetry_events', {
      'name': e.name,
      'ts': e.tsMs,
      'props': jsonEncode(e.props),
    });
  }

  @override
  Future<List<TelemetryEvent>> all() async {
    final db = await _db;
    final rows =
        await db.query('telemetry_events', orderBy: 'id ASC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> clear() async {
    final db = await _db;
    await db.delete('telemetry_events');
  }

  /// 只保留最近 n 条（默认实现会全量读出再重写一遍，这里用一条 SQL 搞定）。
  @override
  Future<void> trimTo(int n) async {
    final db = await _db;
    await db.rawDelete(
      'DELETE FROM telemetry_events WHERE id NOT IN '
      '(SELECT id FROM telemetry_events ORDER BY id DESC LIMIT ?)',
      [n],
    );
  }

  /// 各事件计数（验收表用：进圈数 / 委托完成数 / 握手数…）。
  Future<Map<String, int>> counts() async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT name, COUNT(*) AS c FROM telemetry_events GROUP BY name');
    return {
      for (final r in rows) r['name'] as String: (r['c'] as num).toInt(),
    };
  }

  /// 按名字取事件（判定握手/TTFD 时只读需要的那几类）。
  Future<List<TelemetryEvent>> byName(String name, {int? sinceMs}) async {
    final db = await _db;
    final rows = await db.query(
      'telemetry_events',
      where: sinceMs == null ? 'name = ?' : 'name = ? AND ts >= ?',
      whereArgs: sinceMs == null ? [name] : [name, sinceMs],
      orderBy: 'ts ASC',
    );
    return rows.map(_fromRow).toList();
  }

  TelemetryEvent _fromRow(Map<String, Object?> r) => TelemetryEvent(
        name: r['name'] as String,
        tsMs: (r['ts'] as num).toInt(),
        props: Map<String, Object?>.from(
          (jsonDecode(r['props'] as String) as Map?) ?? {},
        ),
      );
}
