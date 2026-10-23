import 'package:flutter/material.dart';

import '../core/cloud_service.dart';
import '../core/db_helper.dart';
import '../core/rotation_chain.dart';
import '../l10n/app_localizations.dart';
import 'help_dot.dart';

/// 「我的换钥链」—— 把"可被第三方独立复核"这件事**摆到用户眼前**。
///
/// ---------------------------------------------------------------------------
/// 这一页的立场
/// ---------------------------------------------------------------------------
/// 端点 `GET /api/identity/rotations` 刻意**匿名、只回原始记录、不回结论**。
/// 所以这一页也必须守住同一条线：
///
/// * **Hub 的话只作对照**（"Hub 自己的说法"卡片），
/// * **结论在本机算**（[RotationChain.verifySignatures] / `verifyLinks` /
///   `tipMatchesActive`）—— 底下那句"我自己的核对"才是主结论。
///
/// 为什么较真到这个程度：如果界面直接把 Hub 回的 `chain_ok` 当成结论展示，
/// 那"可验证"就退化成**Hub 自己说自己没问题**，与不做验证没有区别。
/// 这一条与 §16 透明日志「第三方要能独立复算整棵树」是同一个要求。
class RotationChainScreen extends StatefulWidget {
  /// 省略时看**本机自己**的链（从通讯录里读 `my_agent_id`）。
  final String? agentId;

  const RotationChainScreen({super.key, this.agentId});

  @override
  State<RotationChainScreen> createState() => _RotationChainScreenState();
}

class _RotationChainScreenState extends State<RotationChainScreen> {
  bool _loading = false;
  String? _error;

  /// 本机身份（用于省略 [RotationChainScreen.agentId] 时的自我查询）。
  String _selfId = '';

  RotationChain? _chain;

  /// 本机自算的结论（不是 Hub 说的）。
  RotationSignatureReport? _sigs;
  List<ChainBreak> _links = const [];
  bool _linkChecked = false;
  bool _tipOk = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (widget.agentId == null) {
      _selfId = await DBHelper.getAmbassador('my_agent_id') ?? '';
    }
    await _fetch();
  }

  String get _target => widget.agentId ?? _selfId;

  Future<void> _fetch() async {
    final l10n = AppLocalizations.of(context);
    if (_target.isEmpty) {
      setState(() {
        _error = l10n.rcUnknownIdentity;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      // 每次重新取回都把上一次的结论清掉：**旧结论不能贴在新数据上**。
      _sigs = null;
      _links = const [];
      _linkChecked = false;
      _tipOk = true;
    });
    final chain = await CloudService().fetchIdentityRotations(agentId: _target);
    if (!mounted) return;
    setState(() {
      _chain = chain;
      _loading = false;
      if (chain == null) {
        _error = CloudService().lastError ?? l10n.rcFetchFail('unknown');
      }
    });
    if (chain != null) await _selfCheck(chain);
  }

  /// ★ 本地独立复算 —— 结论完全由本机算出，Hub 的话不参与。
  Future<void> _selfCheck(RotationChain chain) async {
    final sigs = await chain.verifySignatures();
    if (!mounted) return;
    setState(() {
      _sigs = sigs;
      _links = chain.verifyLinks();
      _tipOk = chain.tipMatchesActive();
      _linkChecked = true;
    });
  }

  String _short(String? s) {
    if (s == null || s.isEmpty) return '—';
    if (s.length <= 22) return s;
    return '${s.substring(0, 12)}…${s.substring(s.length - 8)}';
  }

  // ------------------------------------------------------------ 结论横幅

  /// 把三项自算结果翻成一条**主结论**。
  Widget _verdictBanner(AppLocalizations l10n, ThemeData theme) {
    if (_sigs == null || !_linkChecked) return const SizedBox.shrink();
    final code = RotationChain.summarize(
      sigs: _sigs!,
      links: _links,
      tipOk: _tipOk,
    );
    final ok = code == 'ok';
    final color = ok ? Colors.green : theme.colorScheme.error;
    final text = switch (code) {
      'sig_invalid' => l10n.rcVerdictSigInvalid(_sigs!.invalidIndices.length),
      'link_mismatch' => l10n.rcVerdictLinkMismatch,
      'tip_not_active' => l10n.rcVerdictTipNotActive,
      _ => l10n.rcVerdictOk,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.verified_outlined : Icons.report_problem_outlined,
            color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.rcVerdictTitle,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            const SizedBox(height: 4),
            Text(text, style: theme.textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }

  Widget _keyRow(String label, String? value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.labelSmall),
        SelectableText(
          _short(value),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ]),
    );
  }

  Widget _subjectCard(AppLocalizations l10n, ThemeData theme) {
    final s = _chain?.subject;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.rcSubjectTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          _keyRow(l10n.rcAgentLabel, s?.agentId, theme),
          _keyRow(l10n.rcDidLabel, s?.did, theme),
          _keyRow(l10n.rcCurrentKey, s?.currentPubkey, theme),
          const SizedBox(height: 4),
          Row(children: [
            Icon(
              (s?.registered ?? false)
                  ? Icons.check_circle_outline
                  : Icons.help_outline,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              (s?.registered ?? false)
                  ? l10n.rcRegisteredYes
                  : l10n.rcRegisteredNo,
              style: theme.textTheme.bodySmall,
            ),
          ]),
        ]),
      ),
    );
  }

  /// Hub 的自述 —— 单独一张卡，并明确写"只作对照"。
  Widget _hubClaimCard(AppLocalizations l10n, ThemeData theme) {
    final c = _chain;
    if (c == null) return const SizedBox.shrink();
    final broken = c.brokenAgents.length;
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HelpTitle(
            text: l10n.rcHubClaimTitle,
            topic: HelpTopic.rotationChainAuthority,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            c.chainLinksOk
                ? l10n.rcHubClaimOk
                : l10n.rcHubClaimBroken(broken),
            style: theme.textTheme.bodyMedium,
          ),
        ]),
      ),
    );
  }

  Widget _recordsCard(AppLocalizations l10n, ThemeData theme) {
    final c = _chain;
    if (c == null || c.rotations.isEmpty) return const SizedBox.shrink();
    final sigs = _sigs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.rcRecordsTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          for (var i = 0; i < c.rotations.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(l10n.rcRecordSeq(i + 1),
                          style: theme.textTheme.labelLarge),
                      const Spacer(),
                      if (sigs != null)
                        _sigBadge(
                          l10n,
                          theme,
                          valid: !sigs.invalidIndices.contains(i),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    _keyRow(l10n.rcRecordFrom, c.rotations[i].oldPub, theme),
                    _keyRow(l10n.rcRecordTo, c.rotations[i].newPub, theme),
                    Text(
                      DateTime.fromMillisecondsSinceEpoch(
                              c.rotations[i].rotatedAtMs)
                          .toLocal()
                          .toString(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ]),
            ),
        ]),
      ),
    );
  }

  Widget _sigBadge(AppLocalizations l10n, ThemeData theme,
      {required bool valid}) {
    final color = valid ? Colors.green : theme.colorScheme.error;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(valid ? Icons.check : Icons.close, size: 14, color: color),
      const SizedBox(width: 4),
      Text(
        valid ? l10n.rcRecordSigOk : l10n.rcRecordSigBad,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    ]);
  }

  Widget _anchorCard(AppLocalizations l10n, ThemeData theme) {
    final c = _chain;
    if (c == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.rcAnchorTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            l10n.rcAnchorNote(c.logSize, _short(c.root)),
            style: theme.textTheme.bodySmall,
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = _chain;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rcTitle),
        actions: [
          IconButton(
            tooltip: l10n.rcRefreshAction,
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.rcIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null && !_loading)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_error!),
              ),
            ),
          if (c != null && !_loading) ...[
            if ((c.subject?.unknownIdentity ?? false))
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: Text(l10n.rcUnknownIdentity),
                ),
              )
            else ...[
              _subjectCard(l10n, theme),
              const SizedBox(height: 8),
              if (c.rotations.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.history_toggle_off),
                    title: Text(l10n.rcNoRotations),
                  ),
                )
              else ...[
                _verdictBanner(l10n, theme),
                const SizedBox(height: 8),
                _recordsCard(l10n, theme),
                const SizedBox(height: 8),
                _hubClaimCard(l10n, theme),
                const SizedBox(height: 8),
                _anchorCard(l10n, theme),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
