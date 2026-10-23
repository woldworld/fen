import 'dart:async';
import 'package:flutter/foundation.dart';
import 'db_helper.dart';

/// 统一日志系统：控制台 + system_logs 表（自动限量清理，日志系统本身永不崩溃）
class AppLogger {
  AppLogger._();

  static const int _maxRows = 2000;
  static bool _cleaning = false;

  static void d(String tag, String msg) => _log('debug', tag, msg);
  static void i(String tag, String msg) => _log('info', tag, msg);
  static void w(String tag, Object error) => _log('warn', tag, error.toString());
  static void e(String tag, Object error, [StackTrace? stack]) =>
      _log('error', tag, stack == null ? error.toString() : '$error\n$stack');

  static void _log(String level, String tag, String msg) {
    debugPrint('[$level][$tag] $msg');
    unawaited(_persist(level, tag, msg));
  }

  static Future<void> _persist(String level, String tag, String msg) async {
    try {
      final db = await DBHelper.db;
      await db.insert('system_logs', {
        'level': level,
        'tag': tag,
        'message': msg.length > 2000 ? msg.substring(0, 2000) : msg,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await _cleanupIfNeeded(db);
    } catch (_) {
      // 日志系统必须永不崩溃
    }
  }

  static Future<void> _cleanupIfNeeded(dynamic db) async {
    if (_cleaning) return;
    _cleaning = true;
    try {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM system_logs');
      final count = (rows.first['c'] as int?) ?? 0;
      if (count > _maxRows) {
        final ids = await db.query(
          'system_logs',
          columns: ['id'],
          orderBy: 'created_at ASC',
          limit: count - _maxRows,
        );
        final idList = ids.map((r) => r['id']).toList();
        for (var i = 0; i < idList.length; i += 500) {
          final end = (i + 500 < idList.length) ? i + 500 : idList.length;
          final chunk = idList.sublist(i, end);
          await db.delete(
            'system_logs',
            where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
            whereArgs: chunk,
          );
        }
      }
    } catch (_) {
    } finally {
      _cleaning = false;
    }
  }
}
