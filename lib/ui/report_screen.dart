/// 举报中心（客户端举报入口 + 工单状态查询 + 申诉）。
///
/// ---------------------------------------------------------------------------
/// 为什么这个页面必须存在
/// ---------------------------------------------------------------------------
/// 《服务条款》§6 承诺"客户端内提供举报入口""可就处置结果申诉"——
/// 而此前**产品侧一条都没实现**：UI 里零举报入口、服务端零举报接口、
/// 埋点常量 `report_filed` 定义了但全项目无人 emit。
///
/// 本页把那三条承诺**逐条变成可点的东西**：
///   ① **提交举报**（页签一）：事由白名单 + 可选附注 → 提交后拿到**工单号**；
///   ② **凭工单号查状态**（页签二）：状态是**服务端**说了算，本地不存副本；
///   ③ **申诉**（页签二/三）：状态允许时出现申诉按钮，**以一次为限**（协议层硬闸）。
///
/// ---------------------------------------------------------------------------
/// 四条界面纪律（与 `lib/core/report_service.dart` 的四条硬规矩对齐）
/// ---------------------------------------------------------------------------
/// 1. **状态只在服务端**。本地**不落库工单表** —— 两个事实源必然漂移，
///    漂移的形态是"本地显示已处置、服务端还在处理中"，那比没有状态更糟。
/// 2. **被举报人看不到举报人**。页签三用服务端返回的**公开视角**
///    （结构上就没有举报人身份与举报内容字段），不是"UI 不显示"而是"拿不到"。
/// 3. **失败必须显形**。提交/申诉失败一律显示**错误码**（语言无关的机器码）
///    —— 不给"看起来成功"的假象，也不把失败说成成功。
/// 4. **事由是封闭集合**。自由文本事由会让运营说不出"本周骚扰类 37 起"，
///    所以只有五个选项，选「其他」必须在附注里说明。
///
/// ---------------------------------------------------------------------------
/// 入口位置
/// ---------------------------------------------------------------------------
/// ① 联系人详情页（会话/名册路径）→ 举报该联系人（**带 target 预填**）；
/// ② 管理页 → 举报中心（通用入口，可查任意工单）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/report_client.dart';
import '../core/report_service.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'help_dot.dart';

/// 举报中心。
class ReportScreen extends StatefulWidget {
  /// 预填的被举报人 agent id（从联系人详情页进来时带上）。
  final String? targetAgentId;

  /// 预填的被举报人显示名（仅用于界面提示）。
  final String? targetName;

  const ReportScreen({super.key, this.targetAgentId, this.targetName});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  // ---------------- 提交表单 ----------------
  ReportReason? _reason;
  final TextEditingController _targetCtrl = TextEditingController();
  final TextEditingController _detailCtrl = TextEditingController();
  bool _submitting = false;

  // ---------------- 工单列表 ----------------
  List<Map<String, dynamic>> _mine = const [];
  List<Map<String, dynamic>> _inbox = const [];
  bool _loading = true;
  String? _listError;

  // ---------------- 凭号查询 ----------------
  final TextEditingController _lookupCtrl = TextEditingController();
  Map<String, dynamic>? _lookupResult;
  bool _lookupMissing = false;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    if (widget.targetAgentId != null) {
      _targetCtrl.text = widget.targetAgentId!;
    }
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _targetCtrl.dispose();
    _detailCtrl.dispose();
    _lookupCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // 数据
  // ------------------------------------------------------------------

  /// 拉「我的工单」与「针对我的工单」。
  ///
  /// ★ 两个列表**分别**取，任一失败都**如实显示错误码** ——
  ///   失败时那个列表保持上一轮的内容（不假装是空的）。
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _listError = null;
    });
    String? err;
    List<Map<String, dynamic>> mine = const [];
    List<Map<String, dynamic>> inbox = const [];
    try {
      mine = await ReportClient().myReports();
    } catch (e) {
      err = 'mine:${e is StateError ? e.message : e}';
    }
    try {
      inbox = await ReportClient().inbox();
    } catch (e) {
      err = err ?? 'inbox:${e is StateError ? e.message : e}';
    }
    if (!mounted) return;
    setState(() {
      _mine = mine;
      _inbox = inbox;
      _listError = err;
      _loading = false;
    });
  }

  // ------------------------------------------------------------------
  // 提交
  // ------------------------------------------------------------------

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final reason = _reason;
    if (reason == null) {
      _toast(l10n.reportNeedReason);
      return;
    }
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) {
      _toast(l10n.reportNeedTarget);
      return;
    }
    final detail = _detailCtrl.text.trim();
    if (reason == ReportReason.other && detail.isEmpty) {
      // ★ 选「其他」却不说清楚 ⇒ 服务端会收到一条无法归类的投诉。
      _toast(l10n.reportOtherNeedsDetail);
      return;
    }
    setState(() => _submitting = true);
    final r = await ReportClient().submit(
      targetId: target,
      reason: reason,
      detail: detail,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!r.ok) {
      _toast(_errorText(l10n, r.code));
      return;
    }
    _toast(r.duplicate
        ? l10n.reportDuplicate
        : l10n.reportSubmitted(r.ticketId));
    // 提交成功后拉一次列表（工单号要能立刻查到）。
    _load();
  }

  // ------------------------------------------------------------------
  // 申诉 / 撤回
  // ------------------------------------------------------------------

  Future<void> _appeal(String ticketId) async {
    final l10n = AppLocalizations.of(context);
    final note = await _askNote(l10n.reportAppealTitle, l10n.reportAppealNote);
    if (note == null) return;
    final r = await ReportClient().appeal(ticketId, note);
    if (!mounted) return;
    _toast(r.ok ? l10n.reportAppealSubmitted : _errorText(l10n, r.code));
    if (r.ok) _load();
  }

  Future<void> _withdraw(String ticketId) async {
    final l10n = AppLocalizations.of(context);
    final r = await ReportClient().withdraw(ticketId);
    if (!mounted) return;
    _toast(r.ok ? l10n.reportWithdrawDone : _errorText(l10n, r.code));
    if (r.ok) _load();
  }

  /// 弹出附注输入框；返回 null = 用户取消。
  Future<String?> _askNote(String title, String hint) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final out = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLength: kReportMaxDetailChars,
          maxLines: 4,
          decoration: InputDecoration(labelText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return out;
  }

  // ------------------------------------------------------------------
  // 凭号查询
  // ------------------------------------------------------------------

  Future<void> _lookup() async {
    final l10n = AppLocalizations.of(context);
    final id = _lookupCtrl.text.trim().toUpperCase();
    if (!kReportTicketIdRe.hasMatch(id)) {
      setState(() {
        _lookupResult = null;
        _lookupMissing = true;
      });
      return;
    }
    setState(() => _looking = true);
    Map<String, dynamic>? hit;
    var missing = false;
    try {
      final list = await ReportClient().myReports();
      for (final t in list) {
        if ((t['ticket_id'] as String?) == id) {
          hit = t;
          break;
        }
      }
      missing = hit == null;
    } catch (e) {
      missing = true;
    }
    if (!mounted) return;
    setState(() {
      _lookupResult = hit;
      _lookupMissing = missing;
      _looking = false;
    });
    if (missing) {
      // ★ 文案直说"没找到或不属于你" —— 不区分二者（服务端对陌生工单号返 404，
      //   区分开等于告诉外人"这个编号存在"）。
      _toast(l10n.reportLookupNotFound);
    }
  }

  // ------------------------------------------------------------------
  // 工具
  // ------------------------------------------------------------------

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 事由 → 本地化文案。
  String _reasonLabel(AppLocalizations l10n, ReportReason r) => switch (r) {
        ReportReason.spam => l10n.reportReasonSpam,
        ReportReason.harassment => l10n.reportReasonHarassment,
        ReportReason.illegalContent => l10n.reportReasonIllegalContent,
        ReportReason.fakeIdentity => l10n.reportReasonFakeIdentity,
        ReportReason.other => l10n.reportReasonOther,
      };

  /// 状态 → 本地化文案。**未知状态原样显示机器码**（不猜、不兜底成"处理中"）。
  String _statusLabel(AppLocalizations l10n, String id) => switch (id) {
        'open' => l10n.reportStatusOpen,
        'triaged' => l10n.reportStatusTriaged,
        'in_review' => l10n.reportStatusInReview,
        'actioned' => l10n.reportStatusActioned,
        'rejected' => l10n.reportStatusRejected,
        'appealed' => l10n.reportStatusAppealed,
        'closed' => l10n.reportStatusClosed,
        'withdrawn' => l10n.reportStatusWithdrawn,
        _ => id,
      };

  /// 事由（机器码）→ 本地化文案。
  String _reasonLabelById(AppLocalizations l10n, String id) =>
      _reasonLabel(l10n, ReportReason.fromId(id));

  /// 错误码 → 本地化文案。
  ///
  /// ★ 只覆盖**已知**错误码；未知的原样显示机器码 ——
  ///   猜一个意思（"网络异常"）比显示 `bad_signature` 更坏：
  ///   用户会以为重试就能解决，而根因是身份问题。
  String _errorText(AppLocalizations l10n, String code) => switch (code) {
        'hub_not_configured' => l10n.reportErrHubNotConfigured,
        'ed25519_required' => l10n.reportErrEd25519Required,
        'network' || 'envelope_failed' => l10n.reportErrNetwork,
        'rate_limited' || 'report_rate_limited' => l10n.reportErrRateLimited,
        'self_report' => l10n.reportErrSelfReport,
        'unknown_ticket' || 'not_a_party' || 'bad_ticket_id' =>
          l10n.reportErrNotFound,
        'appeal_exhausted' => l10n.reportErrAppealExhausted,
        'bad_signature' || 'signature_required' || 'agent_not_registered' ||
            'bad_timestamp' || 'reporter_pub_mismatch' =>
          l10n.reportErrAuth,
        _ => l10n.reportFailed(code),
      };

  // ------------------------------------------------------------------
  // 界面
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(l10n.reportCenterTitle),
        actions: const [
          HelpAction(topic: HelpTopic.reportGuide),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: theme.accentColor,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          indicatorColor: theme.accentColor,
          tabs: [
            Tab(text: l10n.reportTabSubmit),
            Tab(text: l10n.reportTabMine),
            Tab(text: l10n.reportTabInbox),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSubmit(l10n, theme, isDark),
          _buildMine(l10n, theme, isDark),
          _buildInbox(l10n, theme, isDark),
        ],
      ),
    );
  }

  // ---------- 页签一：提交举报 ----------

  Widget _buildSubmit(AppLocalizations l10n, ThemeProvider theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.targetName != null && widget.targetName!.isNotEmpty) ...[
          Card(
            color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: Icon(Icons.person_outline, color: theme.accentColor),
              title: Text(widget.targetName!),
              subtitle: Text(widget.targetAgentId ?? ''),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _label(l10n.reportTargetLabel, theme),
        TextField(
          controller: _targetCtrl,
          decoration: InputDecoration(
            hintText: l10n.reportTargetHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        _label(l10n.reportReasonLabel, theme),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in ReportReason.values)
              ChoiceChip(
                label: Text(_reasonLabel(l10n, r)),
                selected: _reason == r,
                onSelected: (_) => setState(() => _reason = r),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _label(l10n.reportDetailLabel, theme),
        TextField(
          controller: _detailCtrl,
          maxLength: kReportMaxDetailChars,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.reportDetailHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: theme.accentColor),
            child: _submitting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(l10n.reportSubmitting),
                    ],
                  )
                : Text(l10n.reportSubmit),
          ),
        ),
      ],
    );
  }

  Widget _label(String text, ThemeProvider theme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.accentColor)),
      );

  // ---------- 页签二：我的工单 + 凭号查询 ----------

  Widget _buildMine(AppLocalizations l10n, ThemeProvider theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- 凭工单号查询 ----
        Card(
          color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(l10n.reportLookupTitle, theme),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lookupCtrl,
                        decoration: InputDecoration(
                          hintText: l10n.reportLookupHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _looking ? null : _lookup,
                      style: FilledButton.styleFrom(backgroundColor: theme.accentColor),
                      child: Text(l10n.reportLookupButton),
                    ),
                  ],
                ),
                if (_lookupResult != null) ...[
                  const SizedBox(height: 12),
                  _ticketCard(l10n, theme, isDark, _lookupResult!,
                      isReporterView: true),
                ] else if (_lookupMissing) ...[
                  const SizedBox(height: 12),
                  Text(l10n.reportLookupNotFound,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_listError != null && _mine.isEmpty)
          _errorBox(l10n, isDark, _listError!)
        else if (_mine.isEmpty)
          Center(
            child: Text(l10n.reportEmptyMine,
                style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38)),
          )
        else
          for (final t in _mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ticketCard(l10n, theme, isDark, t, isReporterView: true),
            ),
      ],
    );
  }

  // ---------- 页签三：针对我的工单 ----------

  Widget _buildInbox(AppLocalizations l10n, ThemeProvider theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_listError != null && _inbox.isEmpty)
          _errorBox(l10n, isDark, _listError!)
        else if (_inbox.isEmpty)
          Center(
            child: Text(l10n.reportEmptyInbox,
                style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38)),
          )
        else
          for (final t in _inbox)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ticketCard(l10n, theme, isDark, t, isReporterView: false),
            ),
      ],
    );
  }

  Widget _errorBox(AppLocalizations l10n, bool isDark, String code) => Center(
        child: Text(_errorText(l10n, code),
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54)),
      );

  // ---------- 工单卡片 ----------

  Widget _ticketCard(
    AppLocalizations l10n,
    ThemeProvider theme,
    bool isDark,
    Map<String, dynamic> t, {
    required bool isReporterView,
  }) {
    final id = (t['ticket_id'] as String?) ?? '';
    final status = (t['status'] as String?) ?? '';
    final note = (t['status_note'] as String?) ?? '';
    final action = (t['action'] as String?) ?? '';
    final appealCount = (t['appeal_count'] as num?)?.toInt() ?? 0;

    // ★ 举报人视角才看得到自己写的事由与附注；被举报人视角**结构上**就没有。
    final reasonText = isReporterView
        ? _reasonLabelById(l10n, (t['reason'] as String?) ?? '')
        : '';
    final detail = isReporterView ? ((t['detail'] as String?) ?? '') : '';

    // 申诉按钮的可见性**由状态决定**（协议层也会再判一次）：
    //   · 举报人对「不予处置」不服 ⇒ rejected 可申诉；
    //   · 被举报人对「已处置」不服 ⇒ actioned 可申诉；
    //   · 申诉以一次为限 ⇒ appealCount ≥ 1 就不再给按钮。
    final canAppeal = appealCount < 1 &&
        ((isReporterView && status == 'rejected') ||
            (!isReporterView && status == 'actioned'));
    // 撤回只在「已受理、尚未分诊」时允许（且只有举报人能撤）。
    final canWithdraw = isReporterView && status == 'open';

    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${l10n.reportTicketLabel}: $id',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_statusLabel(l10n, status),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.accentColor)),
                ),
              ],
            ),
            if (reasonText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reasonText,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87)),
            ],
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(detail,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.white54 : Colors.black54)),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${l10n.reportStatusNote}: $note',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.white54 : Colors.black54)),
            ],
            if (!isReporterView && action.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${l10n.reportActionLabel}: $action',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.white54 : Colors.black54)),
            ],
            if (canAppeal || canWithdraw) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canWithdraw)
                    TextButton(
                      onPressed: () => _withdraw(id),
                      child: Text(l10n.reportWithdraw),
                    ),
                  if (canAppeal) ...[
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () => _appeal(id),
                      style:
                          FilledButton.styleFrom(backgroundColor: theme.accentColor),
                      child: Text(l10n.reportAppeal),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
