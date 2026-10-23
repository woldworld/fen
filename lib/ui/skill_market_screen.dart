import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/plugin_bus.dart';
import '../core/skill_registry.dart';
import '../core/theme_provider.dart';
import '../core/wold_runtime.dart';
import '../l10n/app_localizations.dart';
import 'help_dot.dart';
import 'plugin_labels.dart';

/// M9 技能市场：**签名上架 + 作者分成 + 可复算校验**的唯一 UI 入口。
///
/// 设计要点（与核心层一一对应）：
/// - 上架按钮只做一件事：用**本机身份私钥**签 `listing.canonicalBytes()`。
///   私钥不出设备；页面里根本没有"手填公钥/签名"的输入框 —— UI 层面就写不出伪造。
/// - 每条技能都带"校验签名"动作：调用与 Hub 相同的 `SkillRegistry.verifyListing`，
///   让"你不必相信我，你可以验我"这句话在界面上是**可点的**。
/// - 收益卡片只统计 `author_pub == 我的公钥` 的分账，且总账来自账本条目的
///   `split.authorCents` 求和 —— 与分账秒级可对。
class SkillMarketScreen extends StatefulWidget {
  const SkillMarketScreen({Key? key}) : super(key: key);

  @override
  State<SkillMarketScreen> createState() => _SkillMarketScreenState();
}

class _SkillMarketScreenState extends State<SkillMarketScreen> {
  bool _loading = true;
  String _myPub = '';
  String _myId = '';
  List<SkillListing> _listings = const [];
  List<PayoutLedgerEntry> _payouts = const [];
  Set<String> _revoked = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rt = WoldRuntime.i;
    if (!rt.isReady) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final myPub = await rt.signer.publicKeyBase58();
    final myId = await rt.myAgentId();
    final listings = await rt.skillStore.allListings();
    final payouts = await rt.skillStore.allPayouts();
    final revoked = await rt.skillStore.revokedKeys();
    if (!mounted) return;
    setState(() {
      _myPub = myPub;
      _myId = myId;
      _listings = listings;
      _payouts = payouts;
      _revoked = revoked;
      _loading = false;
    });
  }

  // ---- 只按 skillId 折叠出"每技能一行"（展示最新版本 + 版本数） ----
  List<_SkillRow> _rows() {
    final bySkill = <String, List<SkillListing>>{};
    for (final l in _listings) {
      bySkill.putIfAbsent(l.skillId, () => []).add(l);
    }
    final rows = <_SkillRow>[];
    bySkill.forEach((sid, versions) {
      versions.sort((a, b) => SkillRegistry.compareVersion(b.version, a.version));
      rows.add(_SkillRow(latest: versions.first, versionCount: versions.length));
    });
    rows.sort((a, b) => b.latest.publishedAtMs.compareTo(a.latest.publishedAtMs));
    return rows;
  }

  int get _myAuthorCents => _payouts
      .where((p) => p.authorPub == _myPub)
      .fold(0, (sum, p) => sum + p.split.authorCents);

  int get _myPayoutCount => _payouts.where((p) => p.authorPub == _myPub).length;

  String _yuan(int cents) => (cents / 100).toStringAsFixed(2);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------- 上架

  Future<void> _openPublishSheet() async {
    final l10n = AppLocalizations.of(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final idCtrl = TextEditingController(text: 'wold.skill.');
    final verCtrl = TextEditingController(text: '1.0.0');
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    final contentCtrl = TextEditingController();
    var risk = SkillRisk.low;
    final caps = <String>{};

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          Widget field(TextEditingController c, String label,
              {int maxLines = 1, TextInputType? keyboard}) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: c,
                maxLines: maxLines,
                keyboardType: keyboard,
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(l10n.skillPublishTitle,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      // 「?」：「风险档 / 能力声明 / 作者分成 / 签名上架」这几个名词一次说清
                      const HelpDot(topic: HelpTopic.skillMarket),
                    ],
                  ),
                  const SizedBox(height: 16),
                  field(idCtrl, l10n.skillFieldId),
                  field(verCtrl, l10n.skillFieldVersion),
                  field(nameCtrl, l10n.skillFieldName),
                  field(descCtrl, l10n.skillFieldDesc, maxLines: 2),
                  field(priceCtrl, l10n.skillFieldPrice,
                      keyboard: TextInputType.number),
                  field(contentCtrl, l10n.skillFieldContent, maxLines: 4),
                  const SizedBox(height: 4),
                  Text(l10n.skillFieldRisk,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.isDark ? Colors.white54 : Colors.black54)),
                  Wrap(
                    spacing: 8,
                    children: [SkillRisk.low, SkillRisk.medium, SkillRisk.high]
                        .map((r) => ChoiceChip(
                              label: Text(riskLabel(l10n, r)),
                              selected: risk == r,
                              onSelected: (_) => setSheet(() => risk = r),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.skillFieldCaps,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.isDark ? Colors.white54 : Colors.black54)),
                  Wrap(
                    spacing: 8,
                    children: [
                      PluginCapability.network,
                      PluginCapability.launchApp,
                      PluginCapability.device,
                      PluginCapability.screenControl,
                      PluginCapability.memory,
                      PluginCapability.settings,
                      PluginCapability.social,
                      PluginCapability.local,
                    ]
                        .map((c) => FilterChip(
                              label: Text(capabilityLabel(l10n, c)),
                              selected: caps.contains(c),
                              onSelected: (v) => setSheet(() {
                                v ? caps.add(c) : caps.remove(c);
                              }),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.verified_user),
                      label: Text(l10n.skillSubmit),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (ok != true) return;

    final sid = idCtrl.text.trim();
    final ver = verCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final content = contentCtrl.text;
    if (sid.isEmpty || ver.isEmpty || name.isEmpty || content.isEmpty) {
      _toast(l10n.skillNeedFields);
      return;
    }
    final yuan = double.tryParse(priceCtrl.text.trim()) ?? 0;
    final pricing = SkillPricing(priceCents: (yuan * 100).round());

    final rt = WoldRuntime.i;
    final base = SkillListing(
      skillId: sid,
      version: ver,
      name: name,
      description: descCtrl.text.trim(),
      authorId: _myId,
      authorPub: _myPub,
      capabilities: caps.toList(),
      risk: risk,
      contentHash: SkillRegistry.contentHashOf(content),
      pricing: pricing,
      publishedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    // 关键：签名在**本机**用身份私钥完成，私钥不出设备。
    final sig = await rt.signer.signBytes(base.canonicalBytes());
    final decision = await rt.skills.publish(base.copyWith(signatureB64: sig));

    _toast(_publishMessage(l10n, decision, base.key));
    await _load();
  }

  String _publishMessage(AppLocalizations l10n, PublishDecision d, String key) {
    switch (d.code) {
      case PublishCode.accepted:
        return l10n.skillPublishedOk(key);
      case PublishCode.duplicate:
        return l10n.skillPublishDuplicate;
      case PublishCode.versionConflict:
        return l10n.skillPublishVersionConflict;
      case PublishCode.authorChanged:
        return l10n.skillPublishAuthorChanged;
      case PublishCode.versionNotIncreased:
        return l10n.skillPublishVersionNotIncreased;
      default:
        return l10n.skillPublishUnverified;
    }
  }

  // ---------------------------------------------------------------- 吊销

  Future<void> _revoke(SkillListing l) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.skillRevokeConfirm(l.key)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.skillRevokeAction)),
        ],
      ),
    );
    if (yes != true) return;

    final rt = WoldRuntime.i;
    final base = SkillRevocation(
      skillId: l.skillId,
      version: l.version,
      authorPub: _myPub,
      reason: 'author_revoked',
      atMs: DateTime.now().millisecondsSinceEpoch,
    );
    final sig = await rt.signer.signBytes(base.canonicalBytes());
    final res = await rt.skills.revoke(SkillRevocation(
      skillId: l.skillId,
      version: l.version,
      authorPub: _myPub,
      reason: 'author_revoked',
      atMs: base.atMs,
      signatureB64: sig,
    ));

    _toast(res.ok ? l10n.skillRevokedOk(l.key) : l10n.skillRevokeRejected);
    await _load();
  }

  // ---------------------------------------------------------------- 校验

  Future<void> _verify(SkillListing l) async {
    final l10n = AppLocalizations.of(context);
    final res = await SkillRegistry.verifyListing(l, revokedKeys: _revoked);
    _toast(res.ok ? l10n.skillVerifyOk : l10n.skillVerifyFail(res.code));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    final rows = _rows();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(title: Text(l10n.skillMarketTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: WoldRuntime.i.isReady ? _openPublishSheet : null,
        icon: const Icon(Icons.upload_file),
        label: Text(l10n.skillPublishAction),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: theme.accentColor))
          : Container(
              decoration: theme.backgroundDecoration,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _revenueCard(theme, isDark, l10n),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(l10n.skillNoListings,
                            style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54)),
                      ),
                    )
                  else
                    for (final r in rows) _skillCard(theme, isDark, l10n, r),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _revenueCard(ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    return Card(
      color: isDark ? Colors.black87 : Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings, color: theme.accentColor, size: 30),
                const SizedBox(width: 12),
                Text(l10n.skillRevenueTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (_myPayoutCount > 0)
                  Text(l10n.skillRevenueCount(_myPayoutCount),
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
            const SizedBox(height: 12),
            if (_myPayoutCount == 0)
              Text(l10n.skillRevenueEmpty,
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54))
            else
              Text(
                l10n.skillRevenueTotal('¥${_yuan(_myAuthorCents)}'),
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: theme.accentColor),
              ),
            const SizedBox(height: 10),
            Text('${l10n.skillAuthorKey}: ${_short(_myPub)}',
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      ),
    );
  }

  Widget _skillCard(
      ThemeProvider theme, bool isDark, AppLocalizations l10n, _SkillRow row) {
    final l = row.latest;
    final mine = l.authorPub == _myPub;
    final revoked = _revoked.contains(l.key) || _revoked.contains('${l.skillId}@');
    return Card(
      color: isDark ? Colors.black.withOpacity(0.6) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.name.isEmpty ? l.skillId : l.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (mine)
                  _tag(l10n.skillMineTag, theme.accentColor, isDark),
                const SizedBox(width: 6),
                _tag(riskLabel(l10n, l.risk),
                    l.risk == SkillRisk.high ? Colors.redAccent : Colors.orange,
                    isDark),
              ],
            ),
            const SizedBox(height: 6),
            Text('${l.skillId} · v${l.version}'
                '${row.versionCount > 1 ? ' · ${l10n.skillVersionHistory(row.versionCount)}' : ''}',
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white54 : Colors.black54)),
            if (l.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l.description,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  l.pricing.isFree
                      ? l10n.skillFree
                      : l10n.skillPriceYuan(_yuan(l.pricing.priceCents)),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: l.pricing.isFree
                          ? (isDark ? Colors.white54 : Colors.black54)
                          : theme.accentColor),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.fact_check, size: 16),
                  label: Text(l10n.skillVerifyAction,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => _verify(l),
                ),
                if (mine && !revoked)
                  TextButton.icon(
                    icon: const Icon(Icons.block, size: 16, color: Colors.redAccent),
                    label: Text(l10n.skillRevokeAction,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.redAccent)),
                    onPressed: () => _revoke(l),
                  ),
                if (revoked)
                  _tag(l10n.skillRevokedTag, Colors.redAccent, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      );

  String _short(String s) => s.length <= 12 ? s : '${s.substring(0, 6)}…${s.substring(s.length - 4)}';
}

class _SkillRow {
  final SkillListing latest;
  final int versionCount;
  _SkillRow({required this.latest, required this.versionCount});
}
