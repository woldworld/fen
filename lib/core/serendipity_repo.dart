import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// 遇幸实验室数据仓库：从 SharedPreferences 大 JSON 迁移到 sqflite。
/// 内存 cache 仅作读取视图，save 时按模块增量落库。
class SerendipityRepository {
  SerendipityRepository._();

  static final SerendipityRepository instance = SerendipityRepository._();

  static const List<String> modules = [
    'morning_logs',
    'challenge_logs',
    'reframed_events',
    'night_logs',
    'free_diary_logs',
    'oracle_logs',
  ];

  Database? _db;
  Map<String, dynamic> cache = {};

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final database = await DBHelper.db;
    await database.execute('''
      CREATE TABLE IF NOT EXISTS serendipity_meta(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS serendipity_daily_energy(
        date TEXT PRIMARY KEY,
        energy INTEGER
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS serendipity_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module TEXT NOT NULL,
        content_json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS serendipity_followups(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module TEXT NOT NULL,
        ref_id INTEGER,
        due_at INTEGER NOT NULL,
        prompt TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        created_at INTEGER NOT NULL
      )
    ''');
    return database;
  }

  int get luckEnergy => (cache['luck_energy'] as int?) ?? 0;

  Map<String, dynamic> get dailyEnergy =>
      (cache['daily_energy'] as Map<String, dynamic>?) ?? {};

  /// 初始化：迁移旧 prefs 数据 + 从 DB 载入内存视图
  Future<void> init() async {
    final database = await db;
    await _migrateFromPrefs(database);
    cache = {
      'luck_energy': 0,
      'daily_energy': <String, int>{},
      for (final m in modules) m: <Map<String, dynamic>>[],
    };

    final metaRows = await database.query('serendipity_meta');
    for (final row in metaRows) {
      if (row['key'] == 'luck_energy') {
        cache['luck_energy'] = int.tryParse(row['value'] as String? ?? '0') ?? 0;
      }
    }
    final energyRows = await database.query('serendipity_daily_energy');
    cache['daily_energy'] = {
      for (final row in energyRows)
        row['date'] as String: (row['energy'] as int?) ?? 0,
    };
    for (final m in modules) {
      final rows = await database.query(
        'serendipity_logs',
        where: 'module = ?',
        whereArgs: [m],
        orderBy: 'id ASC',
      );
      cache[m] = [
        for (final row in rows)
          jsonDecode(row['content_json'] as String) as Map<String, dynamic>,
      ];
    }
  }

  /// 追加一条日志并落库（只写该模块）
  Future<void> appendLog(String module, Map<String, dynamic> entry) async {
    final list = (cache[module] as List?) ?? [];
    list.add(entry);
    await save(module);
  }

  /// 增加幸运能量（Lp）
  void addEnergy(int amount) {
    cache['luck_energy'] = luckEnergy + amount;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final daily = cache['daily_energy'] as Map<String, dynamic>;
    daily[today] = ((daily[today] as int?) ?? 0) + amount;
  }

  /// 按模块（或全量）落库
  Future<void> save([String? module]) async {
    final database = await db;
    await database.transaction((txn) async {
      final targets =
          module == null ? modules : (modules.contains(module) ? [module] : <String>[]);
      for (final m in targets) {
        await txn.delete('serendipity_logs', where: 'module = ?', whereArgs: [m]);
        final list = (cache[m] as List?) ?? const [];
        for (final item in list.cast<Map<String, dynamic>>()) {
          await txn.insert('serendipity_logs', {
            'module': m,
            'content_json': jsonEncode(item),
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
      await _writeMeta(txn);
      await _writeDailyEnergy(txn);
    });
  }

  Future<void> _writeMeta(DatabaseExecutor txn) async {
    await txn.delete('serendipity_meta');
    await txn.insert('serendipity_meta', {
      'key': 'luck_energy',
      'value': luckEnergy.toString(),
    });
  }

  Future<void> _writeDailyEnergy(DatabaseExecutor txn) async {
    await txn.delete('serendipity_daily_energy');
    for (final entry in dailyEnergy.entries) {
      await txn.insert('serendipity_daily_energy', {
        'date': entry.key,
        'energy': (entry.value as int?) ?? 0,
      });
    }
  }

  // ------- 人生实验引擎：自动回访 -------

  /// 为某条实验创建回访任务
  Future<void> createFollowup({
    required String module,
    required int refId,
    required DateTime dueAt,
    required String prompt,
  }) async {
    final database = await db;
    await database.insert('serendipity_followups', {
      'module': module,
      'ref_id': refId,
      'due_at': dueAt.millisecondsSinceEpoch,
      'prompt': prompt,
      'status': 'pending',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 查询到期的回访任务
  Future<List<Map<String, dynamic>>> getDueFollowups() async {
    final database = await db;
    return database.query(
      'serendipity_followups',
      where: 'status = ? AND due_at <= ?',
      whereArgs: ['pending', DateTime.now().millisecondsSinceEpoch],
      orderBy: 'due_at ASC',
    );
  }

  Future<void> completeFollowup(int id) async {
    final database = await db;
    await database.update(
      'serendipity_followups',
      {'status': 'done'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ------- 旧数据一次性迁移 -------

  Future<void> _migrateFromPrefs(Database database) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('serendipity_app_db');
    if (raw == null || raw.isEmpty) return;
    try {
      final old = jsonDecode(raw) as Map<String, dynamic>;
      await database.transaction((txn) async {
        await txn.insert(
          'serendipity_meta',
          {
            'key': 'luck_energy',
            'value': (old['luck_energy'] ?? 0).toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        final daily = old['daily_energy'] as Map<String, dynamic>? ?? {};
        for (final entry in daily.entries) {
          await txn.insert(
            'serendipity_daily_energy',
            {'date': entry.key, 'energy': (entry.value as int?) ?? 0},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final m in modules) {
          final list = (old[m] as List?) ?? const [];
          for (final item in list) {
            txn.insert('serendipity_logs', {
              'module': m,
              'content_json': jsonEncode(item),
              'created_at': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
      });
      await prefs.remove('serendipity_app_db');
    } catch (_) {
      // 迁移失败保留旧数据，下次再试
    }
  }
}
