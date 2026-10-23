/// 提醒与待办（W1 / 0.70.0）——「分身记得主人交代的事」的最小闭环。
///
/// ---------------------------------------------------------------------------
/// 它是什么
/// ---------------------------------------------------------------------------
/// 一张 `reminders` 表（DB v38）+ 一份服务：主人（或主智能体代劳）记下一件事，
/// 可以带时刻（**提醒**：`due_at` 非 NULL）也可以不带（**待办**：`due_at` NULL）。
/// 到期的提醒在 Workmanager 心跳（≥15 分钟一轮）或晨间问候里被检出并弹通知。
///
/// ---------------------------------------------------------------------------
/// 触发语义（与晨间问候同款：**至少一次**，不承诺准时）
/// ---------------------------------------------------------------------------
/// * **不申请精确闹钟**（SCHEDULE_EXACT_ALARM）——沿用 `notification_service.dart`
///   「只立即呈现、不调度」的纪律，少一份敏感权限申报。
/// * 代价是提醒只精确到心跳周期（系统还可能进一步推迟）⇒ 验收口径 ±30 分钟。
///   用户要"8:00 准时雷打不动"的场景，本版刻意不承诺（PRD 未决缺口）。
/// * 补发去重靠 DB 列 `notified_at`（唯一写入方 = [maybeEmitDue]）：
///   同一条到期提醒被连续两轮心跳看到也只弹一次。语义与晨间问候的
///   `morning_greeted_date` 相同，但事实源在 DB——提醒是业务数据，
///   不散落进 SharedPreferences。
/// * 重复提醒（daily/weekly）触发后**推进 `due_at` 到下一周期**而不是标记完成：
  ///   "每天 8 点吃藥"杀掉一次后明天还得响。App 死了三天才醒来时也只补弹
///   一次、然后把 due_at 推到"下一个尚未过去的周期"，不连续补响三天。
///
/// ---------------------------------------------------------------------------
/// 边界（诚实登记）
/// ---------------------------------------------------------------------------
/// * `repeat_rule` 首版只有 null / daily / weekly，没有 monthly/yearly/CRON。
/// * 待办（due_at NULL）**不会弹通知**——没有时刻就没有"到期"，它只出现在
///   晨间卡片的"今日待办"与列表页里，完成靠主人手动勾掉。
/// * 通知是否真弹出受通知总开关约束；**但不受免打扰窗口约束**——
///   提醒是主人自己定的强意图（"明早 8 点提醒我"），被夜间窗口静默掉
///   就是"我定的事它没办"，比多吵醒一次更伤信任（该取舍登记进 PRD）。
library;

import 'app_logger.dart';
import 'db_helper.dart';
import 'l10n_holder.dart';
import 'notification_service.dart';

/// 一条提醒/待办的不可变快照。
class Reminder {
  final int id;
  final String title;

  /// 到期时刻（ms）；NULL = 纯待办。
  final int? dueAt;

  /// 重复规则：null / 'daily' / 'weekly'（首版仅此三种）。
  final String? repeatRule;

  /// pending / done。
  final String status;

  /// 谁记下的：'user'（界面）或 'agent'（主智能体代劳）。
  final String createdBy;

  /// 补发去重标记：非 NULL = 这一期已经弹过。重复提醒推进周期时会清回 NULL。
  final int? notifiedAt;
  final int createdAt;

  const Reminder({
    required this.id,
    required this.title,
    this.dueAt,
    this.repeatRule,
    this.status = 'pending',
    this.createdBy = 'user',
    this.notifiedAt,
    this.createdAt = 0,
  });

  bool get isTodo => dueAt == null;
  bool get isRepeating => repeatRule != null;

  Map<String, dynamic> toRow() => {
        'id': id,
        'title': title,
        'due_at': dueAt,
        'repeat_rule': repeatRule,
        'status': status,
        'created_by': createdBy,
        'notified_at': notifiedAt,
        'created_at': createdAt,
      };

  static Reminder fromRow(Map<String, dynamic> r) => Reminder(
        id: (r['id'] as int?) ?? 0,
        title: (r['title'] as String?) ?? '',
        dueAt: r['due_at'] as int?,
        repeatRule: r['repeat_rule'] as String?,
        status: (r['status'] as String?) ?? 'pending',
        createdBy: (r['created_by'] as String?) ?? 'user',
        notifiedAt: r['notified_at'] as int?,
        createdAt: (r['created_at'] as int?) ?? 0,
      );
}

/// 通知呈现的接缝：生产走 [NotificationService]，测试注入捕获桩。
typedef ReminderNotifier = Future<void> Function(Reminder reminder);

class ReminderService {
  ReminderService._();
  static final ReminderService i = ReminderService._();

  /// 首版支持的重复规则（白名单制：写进来的别的值一律按 null 处理）。
  static const Set<String> supportedRepeatRules = {'daily', 'weekly'};

  /// 可注入时钟（到期判定的时间源，测试里固定住）。
  DateTime Function() clock = DateTime.now;

  /// 新建一条。`dueAt` 为 NULL = 纯待办；`repeatRule` 不在白名单 ⇒ 按 null。
  /// 标题去掉首尾空白后为空 ⇒ 抛 ArgumentError（调用方是界面/工具，能接住）。
  Future<Reminder> create({
    required String title,
    int? dueAt,
    String? repeatRule,
    String createdBy = 'user',
  }) async {
    final t = title.trim();
    if (t.isEmpty) throw ArgumentError.value(title, 'title', 'empty');
    final rule =
        (repeatRule != null && supportedRepeatRules.contains(repeatRule))
            ? repeatRule
            : null;
    final now = clock().millisecondsSinceEpoch;
    final db = await DBHelper.db;
    final id = await db.insert('reminders', {
      'title': t,
      'due_at': dueAt,
      'repeat_rule': rule,
      'status': 'pending',
      'created_by': createdBy,
      'notified_at': null,
      'created_at': now,
    });
    return Reminder(
      id: id,
      title: t,
      dueAt: dueAt,
      repeatRule: rule,
      createdBy: createdBy,
      createdAt: now,
    );
  }

  /// 列表。默认只取未完成；到期/定时的排前面，纯待办排后面，各按时间升序。
  Future<List<Reminder>> list({bool includeDone = false}) async {
    final db = await DBHelper.db;
    final rows = await db.query(
      'reminders',
      where: includeDone ? null : "status = 'pending'",
      orderBy: "due_at IS NULL, due_at ASC, created_at ASC",
    );
    return rows.map(Reminder.fromRow).toList();
  }

  /// 手动标记完成（重复提醒也算完成——"这个疗程结束了"）。
  Future<int> complete(int id) async {
    final db = await DBHelper.db;
    return db.update(
      'reminders',
      {'status': 'done'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除（首版硬删：提醒不是记忆，没有"主人忘掉它但系统留着"的语义）。
  Future<int> delete(int id) async {
    final db = await DBHelper.db;
    return db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  /// 晨间卡片用：未来 [window] 内将到期的提醒 + 全部未完成待办。
  /// 已完成的不出现（主人已经办完的事不该再占卡片）。
  Future<List<Reminder>> dueSoon({Duration window = const Duration(hours: 24)}) async {
    final now = clock().millisecondsSinceEpoch;
    final db = await DBHelper.db;
    final rows = await db.query(
      'reminders',
      where: "status = 'pending' AND (due_at IS NULL OR due_at <= ?)",
      whereArgs: [now + window.inMilliseconds],
      // ★ SQLite 里 NULL 在 ASC 时排最前 —— 与 list() 同款写法把待办垫底。
      orderBy: "due_at IS NULL, due_at ASC",
    );
    return rows.map(Reminder.fromRow).toList();
  }

  /// 心跳入口：检出到期未提醒的 → 逐条弹通知 → 写回去重标记/推进周期。
  ///
  /// 任何一条失败都不拖垮其余条目，也**绝不抛**（与晨间问候同纪律：
  /// 提醒不能拖垮心跳）。返回本轮实际弹出的条数。
  Future<int> maybeEmitDue({ReminderNotifier? notifyFn}) async {
    try {
      final now = clock();
      final nowMs = now.millisecondsSinceEpoch;
      final db = await DBHelper.db;
      final rows = await db.query(
        'reminders',
        where:
            "status = 'pending' AND due_at IS NOT NULL AND due_at <= ? AND notified_at IS NULL",
        whereArgs: [nowMs],
        orderBy: 'due_at ASC',
      );
      var fired = 0;
      for (final row in rows) {
        final r = Reminder.fromRow(row);
        try {
          final notify = notifyFn ?? _defaultNotify;
          await notify(r);
          fired++;
        } catch (e) {
          AppLogger.w('reminder.notify', e);
          continue; // 弹失败：不写标记，留给下一轮心跳重试
        }
        if (r.isRepeating) {
          // 推进到"下一个尚未过去的周期"（补响一次，不连补多期），并清回
          // notified_at —— 下一期到点后才允许再弹。
          final next = _nextOccurrence(r.dueAt!, r.repeatRule!, now);
          await db.update(
            'reminders',
            {'due_at': next, 'notified_at': null},
            where: 'id = ?',
            whereArgs: [r.id],
          );
        } else {
          await db.update(
            'reminders',
            {'notified_at': nowMs},
            where: 'id = ?',
            whereArgs: [r.id],
          );
        }
      }
      return fired;
    } catch (e) {
      AppLogger.w('reminder.emit', e);
      return 0;
    }
  }

  Future<void> _defaultNotify(Reminder r) async {
    final l10n = L10nHolder.l10n;
    await NotificationService.i.notifyReminder(
      title: l10n.notifyReminderTitle,
      body: l10n.notifyReminderBody(r.title),
      dedupKey: 'reminder-${r.id}-${r.dueAt}',
    );
  }

  /// 从 [fromMs] 起、严格晚于 [now] 的下一个周期点。
  /// 死了三天醒来时：due_at 一路翻倍推进直到超过 now —— 只响这一次，
  /// 下一次是明天的同一时刻，不把错过的每一期都补响。
  static int _nextOccurrence(int fromMs, String rule, DateTime now) {
    final step = rule == 'weekly' ? const Duration(days: 7) : const Duration(days: 1);
    var t = DateTime.fromMillisecondsSinceEpoch(fromMs);
    final n = DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch);
    while (!t.isAfter(n)) {
      t = t.add(step);
    }
    return t.millisecondsSinceEpoch;
  }
}
