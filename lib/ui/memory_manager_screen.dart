import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/db_helper.dart';
import '../core/reminder_service.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';

/// 记忆与提醒管理页（0.70.0 W1）——「分身记得我什么」的一次性交代清楚。
///
/// ---------------------------------------------------------------------------
/// 为什么单独成页
/// ---------------------------------------------------------------------------
/// 长期画像/自动回忆此前**只有开关没有内容**：主人能说"别回忆"，却看不到
/// "它到底记了什么"——看不见就无法验证开关真的有效，也没法删掉具体某条
/// 尴尬的、过时的、错误的记忆。本页把三块内容摊开：
///   ① **提醒/待办**（reminders 表）：完成、删除、手动新建；
///   ② **情景记忆**（memory_events 表）：分身主动记下的事，可单条删除；
///   ③ **会话轨迹**（session_events 按 session 分组）：整段遗忘（软删，
///      画像/统计/轨迹回放三处都不再读到）。
///
/// 边界（诚实登记）：
/// * **只做查看 + 删除，不做编辑**——编辑历史记忆等于篡改事实源，
///   首版刻意不提供（PRD 未决缺口）。
/// * 提醒的触发精度受 Workmanager 心跳周期限制（≥15 分钟），不承诺准时。
/// * 本页是被 `Navigator.push` 出来的路由页：**自备渐变底**（R10 纪律，
///   否则浅色主题下透明 Scaffold 露出窗口黑底，整页看不见）。
class MemoryManagerScreen extends StatefulWidget {
  const MemoryManagerScreen({super.key});

  @override
  State<MemoryManagerScreen> createState() => _MemoryManagerScreenState();
}

class _MemoryManagerScreenState extends State<MemoryManagerScreen> {
  List<Reminder> _reminders = const [];
  List<Map<String, dynamic>> _memories = const [];
  List<Map<String, dynamic>> _sessions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final reminders = await ReminderService.i.list();
      final memories = await DBHelper.getMemoryEvents(limit: 50);
      final sessions = await DBHelper.listSessions(limit: 20);
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _memories = memories;
        _sessions = sessions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmtTime(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (sameDay) return hm;
    return '${d.month}/${d.day} $hm';
  }

  Future<void> _confirmAndRun(
      BuildContext ctx, String body, Future<void> Function() run) async {
    final l10n = AppLocalizations.of(ctx);
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.commonConfirm),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(l10n.commonConfirm)),
        ],
      ),
    );
    if (ok != true) return;
    await run();
    await _reload();
  }

  // ---------------- 提醒/待办 ----------------

  Future<void> _addReminder(BuildContext ctx) async {
    final l10n = AppLocalizations.of(ctx);
    final controller = TextEditingController();
    DateTime? due;
    String? repeat;
    final saved = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(l10n.reminderAdd),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.reminderTitleHint),
                onSubmitted: (_) => Navigator.pop(dialogCtx, true),
              ),
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(due == null
                      ? l10n.reminderOptionalTime
                      : _fmtTime(due!.millisecondsSinceEpoch)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: dialogCtx,
                      initialDate: due ?? now,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365 * 2)),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: dialogCtx,
                      initialTime: TimeOfDay.fromDateTime(due ?? now),
                    );
                    if (time == null) return;
                    setDialogState(() {
                      due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                    });
                  },
                ),
                if (due != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setDialogState(() => due = null),
                  ),
              ]),
              // 重复规则只有选了时刻才有意义（纯待办没有"周期"）。
              if (due != null)
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.reminderNoRepeat),
                      selected: repeat == null,
                      onSelected: (_) => setDialogState(() => repeat = null),
                    ),
                    ChoiceChip(
                      label: Text(l10n.reminderRepeatDaily),
                      selected: repeat == 'daily',
                      onSelected: (_) => setDialogState(() => repeat = 'daily'),
                    ),
                    ChoiceChip(
                      label: Text(l10n.reminderRepeatWeekly),
                      selected: repeat == 'weekly',
                      onSelected: (_) => setDialogState(() => repeat = 'weekly'),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(l10n.commonCancel)),
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: Text(l10n.commonConfirm)),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final title = controller.text.trim();
    if (title.isEmpty) return;
    try {
      await ReminderService.i.create(
          title: title, dueAt: due?.millisecondsSinceEpoch, repeatRule: repeat);
    } catch (_) {}
    await _reload();
  }

  // ---------------- 构建 ----------------

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    final cardColor = isDark ? Colors.black54 : Colors.white.withOpacity(0.9);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      decoration: theme.backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(elevation: 0, title: Text(l10n.memoryManagerTitle)),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addReminder(context),
          icon: const Icon(Icons.add_alarm),
          label: Text(l10n.reminderAdd),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Text(l10n.memoryManagerIntro,
                      style: TextStyle(fontSize: 12, color: subColor)),
                  const SizedBox(height: 16),

                  // ① 提醒/待办
                  _sectionTitle(l10n.reminderSectionTitle, theme.accentColor),
                  _card(
                    cardColor: cardColor,
                    child: _reminders.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(l10n.reminderEmpty,
                                style: TextStyle(fontSize: 13, color: subColor)))
                        : Column(
                            children: [
                              for (final r in _reminders)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    r.isTodo
                                        ? Icons.check_circle_outline
                                        : Icons.alarm,
                                    color: theme.accentColor,
                                  ),
                                  title: Text(r.title,
                                      style: TextStyle(
                                          fontSize: 14, color: textColor)),
                                  subtitle: Text(
                                    r.isTodo
                                        ? l10n.reminderTodoTag
                                        : '${_fmtTime(r.dueAt!)}'
                                            '${r.repeatRule == 'daily' ? ' · ${l10n.reminderRepeatDaily}' : ''}'
                                            '${r.repeatRule == 'weekly' ? ' · ${l10n.reminderRepeatWeekly}' : ''}',
                                    style: TextStyle(fontSize: 12, color: subColor),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: l10n.commonDone,
                                        icon: const Icon(Icons.done, size: 20),
                                        onPressed: () async {
                                          await ReminderService.i.complete(r.id);
                                          await _reload();
                                        },
                                      ),
                                      IconButton(
                                        tooltip: l10n.commonDelete,
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20),
                                        onPressed: () async {
                                          await ReminderService.i.delete(r.id);
                                          await _reload();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ② 情景记忆
                  _sectionTitle(l10n.memorySectionTitle, theme.accentColor),
                  _card(
                    cardColor: cardColor,
                    child: _memories.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(l10n.memoryEmpty,
                                style: TextStyle(fontSize: 13, color: subColor)))
                        : Column(
                            children: [
                              for (final m in _memories)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.auto_stories,
                                      color: theme.accentColor, size: 20),
                                  title: Text(
                                    (m['summary']?.toString() ?? '').trim(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13, color: textColor),
                                  ),
                                  subtitle: Text(
                                    _fmtTime((m['created_at'] as int?) ?? 0),
                                    style:
                                        TextStyle(fontSize: 12, color: subColor),
                                  ),
                                  trailing: IconButton(
                                    tooltip: l10n.commonDelete,
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    onPressed: () => _confirmAndRun(
                                      context,
                                      l10n.memoryDeleteConfirm,
                                      () => DBHelper
                                          .deleteMemoryEvent(
                                              (m['id'] as int?) ?? 0),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ③ 会话轨迹
                  _sectionTitle(l10n.sessionSectionTitle, theme.accentColor),
                  _card(
                    cardColor: cardColor,
                    child: _sessions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(l10n.sessionEmpty,
                                style: TextStyle(fontSize: 13, color: subColor)))
                        : Column(
                            children: [
                              for (final s in _sessions)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.forum_outlined,
                                      color: theme.accentColor, size: 20),
                                  title: Text(
                                    _fmtTime((s['last_ts'] as int?) ?? 0),
                                    style: TextStyle(
                                        fontSize: 13, color: textColor),
                                  ),
                                  subtitle: Text(
                                    l10n.sessionEventsCount(
                                        (s['cnt'] as int?) ?? 0),
                                    style:
                                        TextStyle(fontSize: 12, color: subColor),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () {
                                      final sid =
                                          (s['session_id']?.toString() ?? '');
                                      _confirmAndRun(
                                        context,
                                        l10n.sessionForgetConfirm,
                                        () => DBHelper.forgetSession(sid),
                                      );
                                    },
                                    child: Text(l10n.sessionForget),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color accent) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: accent)),
      );

  Widget _card({required Widget child, required Color cardColor}) => Card(
        color: cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: child,
        ),
      );
}
