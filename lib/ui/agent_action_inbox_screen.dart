import 'package:flutter/material.dart';

import '../core/agent_service.dart';
import '../core/db_helper.dart';
import '../l10n/app_localizations.dart';

/// 待主人确认的「建议卡」收件箱。
///
/// ★ 2026-09-29 补上的缺口：观察模式下 `AgentService` 会把主动搭讪的草稿写成
///   `proactive_suggestion` / `pending_approval`，而此前**全仓没有任何调用方读它**
///   ⇒ 建议卡落库后既看不见、也无从批准，主人只看到"分身一动不动"。
///   **流水线其实跑到了，死在「产物没人消费」这一半。**
///
/// ★ 本页补的是「**可监督**」这一半，**没有削弱任何一道闸**：
///   - 不批准 = 什么都不发生（默认姿态仍然是观察）；
///   - 批准 **≠ 放行**：发送前仍要走 `_auditDraft` 的 PII 规则 + LLM 网关，
///     与自主搭讪是同一把尺子（family 档才豁免）。
///   ⇒ 主人同意解决的是"**要不要说**"，审查管的是"**能不能说**"，两者互不替代。
class AgentActionInboxScreen extends StatefulWidget {
  const AgentActionInboxScreen({super.key});

  @override
  State<AgentActionInboxScreen> createState() => _AgentActionInboxScreenState();
}

class _AgentActionInboxScreenState extends State<AgentActionInboxScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final Set<int> _busy = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DBHelper.getPendingAgentActions();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _approve(BuildContext ctx, Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    final targetId = (item['target_id'] ?? '').toString();
    final detail = (item['detail'] ?? '').toString();
    if (id == null || targetId.isEmpty || detail.isEmpty) return;

    setState(() => _busy.add(id));
    final ok = await AgentService().approveProactiveSuggestion(id, targetId, detail);
    if (!mounted) return;
    setState(() => _busy.remove(id));

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l10n.suggestionApproved : l10n.suggestionNotSent)),
    );
    await _load();
  }

  Future<void> _ignore(BuildContext ctx, Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    if (id == null) return;
    setState(() => _busy.add(id));
    await AgentService().ignoreProactiveSuggestion(id);
    if (!mounted) return;
    setState(() => _busy.remove(id));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.suggestionInboxTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    l10n.suggestionEmpty,
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final id = item['id'] as int? ?? -1;
                      final targetId = (item['target_id'] ?? '').toString();
                      final detail = (item['detail'] ?? '').toString();
                      final createdAt = item['created_at'] as int? ?? 0;
                      final when = createdAt == 0
                          ? ''
                          : DateTime.fromMillisecondsSinceEpoch(createdAt)
                              .toLocal()
                              .toString()
                              .substring(5, 16);
                      final busy = _busy.contains(id);

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${l10n.suggestionToTarget}$targetId',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white54 : Colors.black54,
                                      ),
                                    ),
                                  ),
                                  if (when.isNotEmpty)
                                    Text(
                                      when,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                detail,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: busy ? null : () => _ignore(context, item),
                                    child: Text(l10n.suggestionIgnore),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: busy ? null : () => _approve(context, item),
                                    style: FilledButton.styleFrom(backgroundColor: accent),
                                    child: busy
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(l10n.suggestionApprove),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
