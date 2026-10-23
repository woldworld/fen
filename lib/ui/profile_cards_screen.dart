/// 「画像卡」界面：主人查看 / 修改 / 删除系统整理出的长期画像。
///
/// ---------------------------------------------------------------------------
/// 为什么这个页面必须存在（而不是"能注入就够了"）
/// ---------------------------------------------------------------------------
/// 需求原文要求"允许用户在界面上查看和手动修改"。这不是锦上添花：
/// 一个**只有机器能写、主人看不见**的画像，等于主人被单方面画像而没有任何
/// 异议权 —— 而这份画像会被注入进每一轮对话的系统提示词。给主人一支能改的笔，
/// 是这个功能可被接受的前提。
///
/// 三条界面纪律：
/// 1. **来源必须显形**：每条都标"你填写的 / 对话中整理 / 每日整理"。
///    只显示内容而不显示来路，主人无法判断该不该信它。
/// 2. **未知来源不假装**：见 [_sourceLabel] —— 认不出来就原样显示那个码，
///    不猜、不兜底成"系统整理"（"能力降级必须显形"同族）。
/// 3. **历史可回看**：每个主题点进去能看到被取代的旧值。画像不是"只有现在"。
library;

import 'package:flutter/material.dart';

import '../core/profile_card_store.dart';
import '../core/profile_taxonomy.dart';
import '../l10n/app_localizations.dart';

class ProfileCardsScreen extends StatefulWidget {
  const ProfileCardsScreen({super.key});

  @override
  State<ProfileCardsScreen> createState() => _ProfileCardsScreenState();
}

class _ProfileCardsScreenState extends State<ProfileCardsScreen> {
  bool _loading = true;
  List<ProfileCard> _active = const [];
  List<ProfileCard> _pending = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final store = ProfileCardStore.i;
    final active = await store.listActive();
    final pending = await store.listPending();
    if (!mounted) return;
    setState(() {
      _active = active;
      _pending = pending;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileCardsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCard(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.profileCardsAdd),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                Text(l10n.profileCardsSubtitle, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                if (_pending.isNotEmpty) ...[
                  _pendingBanner(l10n, theme),
                  const SizedBox(height: 12),
                ],
                if (_active.isEmpty && _pending.isEmpty)
                  _empty(theme, l10n)
                else
                  ..._groupedCards(l10n, theme),
                const SizedBox(height: 24),
                // ⚠️ 槽位说明不是装饰：它解释了"为什么我改了一条旧的就不见了"
                //   （同一个主题只留一条，旧的进了历史）。不给这个解释，
                //   主人会以为系统把他的信息弄丢了。
                Text(l10n.profileCardsSlotHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    )),
              ],
            ),
    );
  }

  Widget _empty(ThemeData theme, AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.badge_outlined,
                size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(l10n.profileCardsEmpty,
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ],
        ),
      );

  /// 待裁决横幅：与主人自述冲突的新信息。**必须主人点一下才算数**。
  Widget _pendingBanner(AppLocalizations l10n, ThemeData theme) => Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.profileCardsPendingHint(_pending.length),
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final c in _pending)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.statement),
                  subtitle: Text(
                      '${_catLabel(l10n, c.category)} · ${_sourceLabel(l10n, c.source)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await ProfileCardStore.i.acceptPending(c.id);
                          await _reload();
                        },
                        child: Text(l10n.profileCardsAdopt),
                      ),
                      TextButton(
                        onPressed: () async {
                          await ProfileCardStore.i.rejectPending(c.id);
                          await _reload();
                        },
                        child: Text(l10n.profileCardsDismiss),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  /// 按分类分组（分类顺序 = [ProfileCategory.all]，稳定 ⇒ 每次进来位置一样）。
  List<Widget> _groupedCards(AppLocalizations l10n, ThemeData theme) {
    final out = <Widget>[];
    for (final cat in ProfileCategory.all) {
      final items = _active.where((c) => c.category == cat).toList();
      if (items.isEmpty) continue;
      out.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(_catLabel(l10n, cat),
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.primary)),
      ));
      for (final c in items) {
        out.add(_cardTile(c, l10n, theme));
      }
    }
    return out;
  }

  Widget _cardTile(ProfileCard c, AppLocalizations l10n, ThemeData theme) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(c.statement),
          subtitle: Text(
            '${_sourceLabel(l10n, c.source)} · '
            '${l10n.profileCardsUpdatedAt(_fmtDate(c.updatedAt))}',
            style: theme.textTheme.bodySmall,
          ),
          onTap: () => _showDetail(c, l10n),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                await _editCard(c);
              } else if (v == 'delete') {
                await ProfileCardStore.i.deleteCard(c.id);
                await _reload();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.commonSave)),
              PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
            ],
          ),
        ),
      );

  /// 详情：历史（被取代的旧值）+ 证据。
  Future<void> _showDetail(ProfileCard c, AppLocalizations l10n) async {
    final history = await ProfileCardStore.i.historyOfSlot(c.slot);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(c.statement, style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('${l10n.profileCardsFieldSlot}: ${c.slot}',
              style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 16),
          Text(l10n.profileCardsHistory,
              style: Theme.of(ctx).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final h in history) ...[
            ListTile(
              dense: true,
              leading: Icon(
                h.isActive ? Icons.check_circle : Icons.history,
                size: 18,
                color: h.isActive
                    ? Theme.of(ctx).colorScheme.primary
                    : Theme.of(ctx).colorScheme.outline,
              ),
              title: Text(h.statement),
              subtitle: Text(
                '${_sourceLabel(l10n, h.source)} · '
                '${l10n.profileCardsUpdatedAt(_fmtDate(h.updatedAt))}'
                '${h.evidence == null || h.evidence!.isEmpty ? '' : '\n${h.evidence}'}',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 新增 / 编辑对话框。[existing] 为 null 时是新增。
  Future<void> _editCard(ProfileCard? existing) async {
    final l10n = AppLocalizations.of(context);
    final statementCtl = TextEditingController(text: existing?.statement ?? '');
    final slotCtl = TextEditingController(text: existing?.slot ?? '');
    var cat = existing?.category ?? ProfileCategory.identity;
    // 编辑已有卡时**锁定槽位**：改槽位等于把这条挪到另一个主题去，
    // 会让旧主题的卡莫名其妙消失 —— 那是"静默不符预期"。
    final slotLocked = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? l10n.profileCardsAdd : l10n.commonSave),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  decoration: InputDecoration(labelText: l10n.profileCardsFieldSlot),
                  items: [
                    for (final c in ProfileCategory.all)
                      DropdownMenuItem(value: c, child: Text(_catLabel(l10n, c))),
                  ],
                  onChanged: (v) => setLocal(() => cat = v ?? cat),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slotCtl,
                  enabled: !slotLocked,
                  decoration:
                      InputDecoration(labelText: l10n.profileCardsFieldSlot),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: statementCtl,
                  maxLines: 3,
                  decoration: InputDecoration(
                      labelText: l10n.profileCardsFieldStatement,
                      hintText: l10n.profileCardsSlotHint),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.commonSave)),
          ],
        ),
      ),
    );
    if (ok != true) {
      statementCtl.dispose();
      slotCtl.dispose();
      return;
    }

    final statement = statementCtl.text.trim();
    final slot = existing?.slot ?? slotCtl.text.trim();
    statementCtl.dispose();
    slotCtl.dispose();
    if (statement.isEmpty || slot.isEmpty) return;

    if (existing == null) {
      await ProfileCardStore.i.upsertByOwner(
          slot: slot, statement: statement, category: cat);
    } else {
      await ProfileCardStore.i.editStatement(existing.id, statement);
    }
    await _reload();
  }

  // ── 文案映射 ────────────────────────────────────────────────────────

  static String _catLabel(AppLocalizations l10n, String c) => switch (c) {
        ProfileCategory.identity => l10n.profileCardsCatIdentity,
        ProfileCategory.career => l10n.profileCardsCatCareer,
        ProfileCategory.preference => l10n.profileCardsCatPreference,
        ProfileCategory.goal => l10n.profileCardsCatGoal,
        ProfileCategory.habit => l10n.profileCardsCatHabit,
        ProfileCategory.constraint => l10n.profileCardsCatConstraint,
        _ => l10n.profileCardsCatContext,
      };

  /// 来源标签。**认不出来就原样显示那个码** —— 不猜、不兜底成"系统整理"，
  /// 否则主人会把一个来路不明的条目当成可靠的系统整理结果。
  static String _sourceLabel(AppLocalizations l10n, String source) {
    if (ProfileSource.isOwner(source)) return l10n.profileCardsSourceOwner;
    if (source.startsWith(ProfileSource.digestPrefix)) {
      return l10n.profileCardsSourceDigest;
    }
    if (source.startsWith(ProfileSource.agentPrefix)) {
      return l10n.profileCardsSourceAgent;
    }
    return source;
  }

  static String _fmtDate(int ms) {
    if (ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
