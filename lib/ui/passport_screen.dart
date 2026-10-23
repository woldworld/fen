import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/agent_identity.dart';
import '../core/attestation_service.dart';
import '../core/db_helper.dart';
import '../core/ed25519_sig.dart';
import '../core/reputation_network.dart';
import '../core/theme_provider.dart';
import '../core/wold_did.dart';
import '../core/wold_runtime.dart';
import '../l10n/app_localizations.dart';
import 'help_dot.dart';
import 'identity_backup_screen.dart';

/// M6「护照与信誉」—— 信誉体系的种子，做成一张**可验证**的护照页。
///
/// 这一页只做三件事，但每件都必须是真的：
///
/// | 版块 | 它凭什么可被信任 |
/// |---|---|
/// | **身份** | `did:wold` 从公钥**直接导出** → 公钥即身份，离线可验（§16 的 SCT） |
/// | **履历** | 每条只显示 [IntroVerifier] **实际验过的等级**，不显示记录里的自称 |
/// | **可监督** | 摊开 §16 透明日志的期号与 Merkle 根，并说明"任何人都能复算" |
///
/// ### 刻意的两个"不做"
///
/// ① **不给信誉分**。PRD §5.4 明确：分数与阈值**可后置调整**，而签名与留痕
///    **不可后补**。所以这一页给的是**可验证的事实**，不是我们的评价 ——
///    一旦这里出现一个"信誉 87 分"，它就会变成用户唯一记得住的东西，
///    而它恰恰是唯一没法被第三方复算的东西。
/// ② **不代客同意**。收到别人发来的互介时，这一页只给一个"同意"按钮；
///    自动同意会让"双方同意"这条最关键证据退化成自说自话
///    （与 M1 双向签名圈籍、M3 主人预览确认同款纪律）。
class PassportScreen extends StatefulWidget {
  const PassportScreen({Key? key}) : super(key: key);

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  bool _loading = true;
  bool _busy = false;
  String _myId = '';
  String _did = '';
  int? _issuedAtMs;
  List<(IntroAttestation, IntroVerifyResult)> _ledger = const [];
  IntroFunnel? _funnel;
  int _logSize = 0;
  String _logRoot = '';

  /// 当前这把钥是否已备份 —— 决定护照页入口是否挂**红标**。
  ///
  /// 为什么挂在入口而不是只在备份页里：用户根本不会主动点进去看。
  /// 没备份这件事必须在他**每次翻护照时**都撞见一次。
  bool _backedUp = true;

  // ---- M6 网络级信誉 ----
  String _myPub = '';
  int _anchorCount = 0;
  List<Endorsement> _mine = const [];
  List<Endorsement> _forMe = const [];
  Set<String> _revokedKeys = const {};
  NetworkVerdict? _verdict;

  /// 本次展示把履历归并到了**几把**历史公钥上（1 = 从未换过钥）。
  /// 只是把"为什么旧钥名下的背书也算数"讲清楚；不参与任何判定。
  int _myKeyCount = 1;

  /// 从 Hub 拉回"我的背书"每次进程只尝试一次。
  ///
  /// 它是**补历史**用的（换机恢复后本地是空盘），不是同步 —— 每次翻页都打一次
  /// 网络既没必要，也会在离线时反复白等 5 秒超时。
  static bool _pulledOnce = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final myId = await DBHelper.getAmbassador('my_agent_id') ?? '';

    var did = '';
    int? issuedAt;
    var ledger = <(IntroAttestation, IntroVerifyResult)>[];
    IntroFunnel? funnel;
    var logSize = 0;
    var logRoot = '';

    // M6 网络信誉
    var myPub = '';
    var anchorCount = 0;
    var mine = <Endorsement>[];
    var forMe = <Endorsement>[];
    var revokedKeys = <String>{};
    var myKeyCount = 1;
    NetworkVerdict? verdict;

    /// 默认 true：读不到状态时**不**给用户挂假警告（见下端 setState 处注释）。
    var backed = true;

    if (WoldRuntime.i.isReady) {
      try {
        final pub = await WoldRuntime.i.signer.publicKeyBase58();
        myPub = pub;
        // ★ 展示用**身份根 DID**（不是按当前钥现推的那个）：
        //   换钥之后现推值与 Hub 侧的身份锚分叉，界面就会显示一个
        //   别人在 Hub 上查不到的身份地址。见 AgentIdentity.identityRootDid。
        final candidate = await AgentIdentity().identityRootDid();
        if (WoldDid.isValid(candidate)) did = candidate;
        final db = await DBHelper.db;
        final rows = await db.query('did_issuance',
            where: 'did = ?', whereArgs: [candidate], limit: 1);
        if (rows.isNotEmpty) {
          issuedAt = (rows.first['issued_at'] as num?)?.toInt();
        }
        ledger = await WoldRuntime.i.myIntros();
        funnel = await WoldRuntime.i.myIntroFunnel();
        final snap = await WoldRuntime.i.transparency.snapshot();
        logSize = snap.size;
        logRoot = snap.root;

        // ★ 网络信誉：换钥之后"我"不只对应当前这一把钥（换钥退休的是**钥**，
        //   不是人）。履历按**全部历史公钥**取并集 —— 只认当前钥的话，用户换一次
        //   手机就会看到自己的背书全部归零。见 WoldRuntime.myIdentityKeys。
        final myKeys = await WoldRuntime.i.myIdentityKeys();
        myKeyCount = myKeys.isEmpty ? 1 : myKeys.length;

        // 换机恢复后本地是一块空盘：先把 Hub 上属于我的背书**拉回来**
        // （每条都在本地重新验签，验不过的不落库）。失败静默 —— 离线时照常显示本地已有的部分。
        if (!_pulledOnce) {
          _pulledOnce = true;
          await WoldRuntime.i.pullMyReputation();
        }

        // 网络信誉：我签发的 / 给我的 / 已吊销的
        mine = await WoldRuntime.i.reputationNetwork.issuedBy(myKeys);
        forMe = await WoldRuntime.i.reputationNetwork.receivedBy(myKeys);
        revokedKeys = await WoldRuntime.i.reputationStore.revokedKeys();

        // 锚点 = 本地信誉达标、且我确实拿到过他公钥的人（接缝表 agent_pubkeys）
        anchorCount = (await _loadAnchors()).length;

        // 身份备份状态（决定入口红标）—— 查不动就当"已备份"，
        // 免得因一次读盘失败就给用户挂一个假的警告。
        try {
          backed = await AgentIdentity().isBackedUp();
        } catch (_) {}
      } catch (_) {
        // 任何一步失败都不该让整页白屏：能显示的部分照常显示。
        // 护照页最怕"打不开"——它是用户唯一能拿出来给别人看的东西。
      }
    }

    if (!mounted) return;
    setState(() {
      _myId = myId;
      _did = did;
      _issuedAtMs = issuedAt;
      _ledger = ledger;
      _funnel = funnel;
      _logSize = logSize;
      _logRoot = logRoot;
      _myPub = myPub;
      _anchorCount = anchorCount;
      _mine = mine;
      _forMe = forMe;
      _revokedKeys = revokedKeys;
      _verdict = verdict;
      _myKeyCount = myKeyCount;
      _backedUp = backed;
      _loading = false;
    });
  }

  // ------------------------------------------------------------------
  // M6 网络信誉：锚点 / 签发 / 收回 / 验签 / 追溯
  // ------------------------------------------------------------------

  /// 把名册（按 agent_id 记的本地信誉）折成网络锚点（按 pubkey）。
  ///
  /// 这两个体系索引键不同，接缝就是 DB v31 的 `agent_pubkeys`。
  /// 拿不到公钥的人诚实跳过 —— 接不上网络就是接不上，不能拿 ID 冒充。
  Future<Map<String, double>> _loadAnchors() async {
    final db = await DBHelper.db;
    final rows = await db.query('agent_friends',
        columns: ['agent_id', 'reputation']);
    final scoreById = <String, int>{};
    for (final r in rows) {
      final id = (r['agent_id'] as String?) ?? '';
      if (id.isEmpty) continue;
      scoreById[id] = (r['reputation'] as num?)?.toInt() ?? 50;
    }
    final mapRows = await db.query('agent_pubkeys');
    final pubById = <String, String>{};
    for (final r in mapRows) {
      final id = (r['agent_id'] as String?) ?? '';
      final pub = (r['pubkey'] as String?) ?? '';
      if (id.isEmpty || pub.isEmpty) continue;
      pubById[id] = pub;
    }
    return ReputationBridge.anchorsFrom(scoreById: scoreById, pubById: pubById);
  }

  /// 记住某人的公钥（本地信誉 ↔ 网络信誉的接缝就在这一步被填上）。
  ///
  /// ★ 写库**不在这里**：全部经 [AgentIdentity.bindSeam]（接缝表的唯一写入点，
  /// 外部审计 P2② 修复）。这里原先自己 insert/update 一次，问题是它**只覆盖、
  /// 不把被顶掉的旧钥抄进退休表**，也**不拦**把一把已退休的钥写回来 ——
  /// 于是"换钥必先留痕"只在恢复那条路上成立，接缝表成了第二条不收约束的口子。
  ///
  /// 返回 `true` = 值确实变了（调用方据此决定要不要提示）。
  Future<bool> _bindPubkey(String agentId, String pub) {
    // `source: 'passport'` + 默认 `viaConfirmedRotation: false`：
    // 这里拿到的是**用户手填/粘贴**的公钥，不是 Hub 确认过的换钥，
    // 因此退休闸在这里**必须生效**（退休不可撤销）。
    return AgentIdentity().bindSeam(agentId: agentId, pubB58: pub);
  }

  /// 把用户粘贴的 DID / 公钥统一解析成公钥。
  String _resolveSubject(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.startsWith(WoldDid.prefix)) return WoldDid.pubOf(t) ?? '';
    return t;
  }

  Future<void> _issueEndorsement() async {
    final l10n = AppLocalizations.of(context);
    if (!WoldRuntime.i.isReady || _myPub.isEmpty) return;

    final subjectCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    var tier = ReputationTier.friend;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setLocal) => AlertDialog(
          title: Text(l10n.repNetIssueTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectCtrl,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: l10n.repNetIssueSubjectLabel),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tier,
                decoration:
                    InputDecoration(labelText: l10n.repNetIssueTierLabel),
                items: [
                  DropdownMenuItem(
                      value: ReputationTier.acquaintance,
                      child: Text(l10n.repNetTierAcquaintance)),
                  DropdownMenuItem(
                      value: ReputationTier.friend,
                      child: Text(l10n.repNetTierFriend)),
                  DropdownMenuItem(
                      value: ReputationTier.family,
                      child: Text(l10n.repNetTierFamily)),
                ],
                onChanged: (v) {
                  if (v != null) setLocal(() => tier = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration:
                    InputDecoration(labelText: l10n.repNetIssueNoteLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idCtrl,
                decoration:
                    InputDecoration(labelText: l10n.repNetIssueBindLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: Text(l10n.commonCancel)),
            ElevatedButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: Text(l10n.repNetIssueAction)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final raw = subjectCtrl.text.trim();
    if (raw.isEmpty) {
      _toast(l10n.repNetIssueNeedSubject);
      return;
    }
    final subject = _resolveSubject(raw);
    if (!Ed25519Sig.isPubkey(subject)) {
      _toast(l10n.repNetIssueBadSubject);
      return;
    }
    if (subject == _myPub) {
      _toast(l10n.repNetSelfReject);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final draft = Endorsement(
      issuerPub: _myPub,
      subjectPub: subject,
      tier: tier,
      issuedAtMs: now,
      expiresAtMs: now + ReputationCaps.endorsementValidDays * 86400000,
      note: noteCtrl.text.trim(),
    );
    // 私钥不出设备：与 M9 上架同款 —— UI 里没有"手填签名"的输入框
    final sig = await WoldRuntime.i.signer.signBytes(draft.canonicalBytes());
    final signed = draft.copyWith(sig: sig);

    final d = await WoldRuntime.i.reputationNetwork.endorse(signed, nowMs: now);
    if (!mounted) return;
    _toast(d.accept
        ? l10n.repNetIssuedToast
        : l10n.repNetFailedToast(d.code));

    // 顺手把"这个人 ↔ 这把公钥"记住 —— 这是本地信誉（按 agent_id）与
    // 网络信誉（按公钥）之间**唯一的桥**：不记住的话，下次做信任传播时
    // 他仍然接不上网络，追溯只会回答"我不知道"。留空即不绑定（不撒谎）。
    final bindId = idCtrl.text.trim();
    if (d.accept && bindId.isNotEmpty) {
      final bound = await _bindPubkey(bindId, subject);
      if (mounted) {
        // 没绑上**不是**成功：接缝闸会拒掉"把已退休的钥写回来"这种写回
        // （见 AgentIdentity.bindSeam ②）。绝不能照旧弹"已记住" ——
        // 那正是一次静默失效最典型的骗法。
        _toast(bound
            ? l10n.repNetBoundToast(bindId)
            : l10n.repNetFailedToast('seam_rejected'));
      }
    }

    await _refresh();
  }

  Future<void> _revoke(Endorsement e) async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;
    final draft = EndorsementRevocation(
        issuerPub: e.issuerPub, subjectPub: e.subjectPub, atMs: now);
    final sig = await WoldRuntime.i.signer.signBytes(draft.canonicalBytes());
    final d = await WoldRuntime.i.reputationNetwork.revoke(
      EndorsementRevocation(
          issuerPub: e.issuerPub,
          subjectPub: e.subjectPub,
          atMs: now,
          sig: sig),
    );
    if (!mounted) return;
    _toast(d.accept ? l10n.repNetRevokedToast : l10n.repNetFailedToast(d.code));
    await _refresh();
  }

  Future<void> _verify(Endorsement e) async {
    final l10n = AppLocalizations.of(context);
    final v = await ReputationGraph.verifyEndorsement(e,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        revokedKeys: _revokedKeys);
    if (!mounted) return;
    _toast(v.accept ? l10n.repNetVerifiedToast : l10n.repNetBadSignatureToast);
  }

  Future<void> _trace(String subjectPub) async {
    final l10n = AppLocalizations.of(context);
    final subject = _resolveSubject(subjectPub);
    if (!Ed25519Sig.isPubkey(subject)) {
      _toast(l10n.repNetIssueBadSubject);
      return;
    }
    final anchors = await _loadAnchors();
    final v = await WoldRuntime.i.reputationNetwork.query(
      subjectPub: subject,
      anchors: anchors,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() => _verdict = v);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------------
  // 状态推进（同意 / 结果 / 追认）
  // ------------------------------------------------------------------

  /// 统一的三段式推进：**先签名落库，再投递给对端**。
  ///
  /// 顺序不能反：先投递后落库的话，一旦投递成功而落库失败，
  /// 对方账本有、我这边没有 —— 而"对方有你没有"是没法事后补齐的
  /// （签名不可补录）。先落库至少保证我不丢证据。
  Future<void> _advance(
    Future<IntroAttestation?> Function() op, {
    required String toId,
  }) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);

    IntroAttestation? out;
    try {
      out = await op();
    } catch (_) {
      out = null;
    }

    var delivered = false;
    if (out != null) {
      try {
        delivered =
            await WoldRuntime.i.introRelay.dispatchUpdate(out, toId: toId);
      } catch (_) {
        delivered = false;
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);
    final msg = out == null
        ? l10n.passportActionRejected
        : (delivered ? l10n.passportActionDelivered : l10n.passportActionOffline);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    await _refresh();
  }

  Future<void> _consent(IntroAttestation a) => _advance(
        () => WoldRuntime.i.attestations.consent(a),
        toId: a.initiatorId,
      );

  Future<void> _resolve(IntroAttestation a, String outcome) => _advance(
        () => WoldRuntime.i.attestations.resolve(a, outcome: outcome),
        toId: a.isInitiator(_myId) ? a.counterpartyId : a.initiatorId,
      );

  Future<void> _ack(IntroAttestation a) => _advance(
        () => WoldRuntime.i.attestations.acknowledge(a),
        toId: a.isInitiator(_myId) ? a.counterpartyId : a.initiatorId,
      );

  Future<void> _pickOutcome(IntroAttestation a) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.passportResolveTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final o in const [
              IntroOutcome.handshake,
              IntroOutcome.declined,
              IntroOutcome.noResponse,
              IntroOutcome.withdrawn,
            ])
              ListTile(
                title: Text(_outcomeLabel(l10n, o)),
                onTap: () => Navigator.pop(ctx, o),
              ),
          ],
        ),
      ),
    );
    if (choice != null && mounted) await _resolve(a, choice);
  }

  // ------------------------------------------------------------------
  // 发起互介
  // ------------------------------------------------------------------

  Future<void> _newIntro() async {
    final l10n = AppLocalizations.of(context);
    if (!WoldRuntime.i.isReady) return;

    // 互介必须有圈归属（M5 的纪律：卡与边都挂在"我的某个圈"上），
    // 没有圈就不让发起 —— 否则这条记录事后无法归属、无法追溯。
    final circle = await WoldRuntime.i.primaryCircle(_myId);
    if (circle == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.passportNewIntroNoCircle)));
      return;
    }

    final peerCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.passportNewIntroAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: peerCtrl,
              autofocus: true,
              decoration:
                  InputDecoration(labelText: l10n.passportNewIntroPeerLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: topicCtrl,
              decoration:
                  InputDecoration(labelText: l10n.passportNewIntroTopicLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(l10n.commonCancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(l10n.passportNewIntroSubmit)),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final peer = peerCtrl.text.trim();
    if (peer.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.passportNewIntroNeedPeer)));
      return;
    }

    // 发起即签名落库（同时自动追加一片 §16 日志叶子）；
    // 投递失败不影响记账 —— 对端的同意会经由入站拦截再回来。
    var delivered = false;
    try {
      final a = await WoldRuntime.i.attestations.propose(
        counterpartyId: peer,
        circleId: circle.id,
        topic: topicCtrl.text.trim(),
      );
      delivered = await WoldRuntime.i.introRelay.dispatchProposal(a);
    } catch (_) {
      delivered = false;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          delivered ? l10n.passportNewIntroDone(peer) : l10n.passportActionOffline),
    ));
    await _refresh();
  }

  Future<void> _copy(String value) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.passportCopiedToast)));
  }

  // ------------------------------------------------------------------
  // 码 → 文案 / 颜色
  // ------------------------------------------------------------------

  static String _trustLabel(AppLocalizations l10n, String trust) =>
      switch (trust) {
        IntroTrust.acknowledged => l10n.passportTrustAcknowledged,
        IntroTrust.resolved => l10n.passportTrustResolved,
        IntroTrust.consented => l10n.passportTrustConsented,
        IntroTrust.initiated => l10n.passportTrustInitiated,
        _ => l10n.passportTrustNone,
      };

  /// 等级越高颜色越"暖"：未验证是红，最强档是金。
  /// 刻意不用单一色相做深浅 —— 那在深色主题下几乎分不出来。
  static Color _trustColor(String trust) => switch (trust) {
        IntroTrust.acknowledged => const Color(0xFFF59E0B),
        IntroTrust.resolved => const Color(0xFF0D9488),
        IntroTrust.consented => const Color(0xFF16A34A),
        IntroTrust.initiated => const Color(0xFF64748B),
        _ => const Color(0xFFDC2626),
      };

  static String _outcomeLabel(AppLocalizations l10n, String? code) =>
      switch (code) {
        IntroOutcome.handshake => l10n.passportOutcomeHandshake,
        IntroOutcome.declined => l10n.passportOutcomeDeclined,
        IntroOutcome.noResponse => l10n.passportOutcomeNoResponse,
        IntroOutcome.withdrawn => l10n.passportOutcomeWithdrawn,
        _ => '',
      };

  /// 手写格式化而不是引 intl：`intl` 只是 flutter_localizations 的传递依赖，
  /// 直接 import 会触发 depend_on_referenced_packages。格式固定为 ISO 风格，
  /// 与"可验证记录"的语境也更搭。
  static String _fmtTime(int? ms) {
    if (ms == null || ms <= 0) return '-';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  static String _pct(double v) => '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(l10n.passportTitle),
        actions: const [HelpAction(topic: HelpTopic.passportOverview)],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: theme.accentColor))
          : Container(
              decoration: theme.backgroundDecoration,
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _passportCard(theme, isDark, l10n),
                    const SizedBox(height: 16),
                    _identityBackupTile(theme, isDark, l10n),
                    const SizedBox(height: 16),
                    _funnelCard(theme, isDark, l10n),
                    const SizedBox(height: 16),
                    _networkCard(theme, isDark, l10n),
                    const SizedBox(height: 16),
                    _ledgerHeader(theme, isDark, l10n),
                    if (_ledger.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            l10n.passportLedgerEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < _ledger.length; i++)
                        _entryCard(theme, isDark, l10n, _ledger[i].$1, _ledger[i].$2,
                            index: i),
                    const SizedBox(height: 16),
                    _logCard(theme, isDark, l10n),
                  ],
                ),
              ),
            ),
    );
  }

  // ------------------------------------------------------------------
  // ① 护照卡
  // ------------------------------------------------------------------

  /// 身份备份与恢复的入口。
  ///
  /// 为什么放在护照页而不是塞进"设置"：**手机丢了就是身份永久灭失**（PRD §9.1），
  /// 这是身份的一部分，不是一条配置项 —— 藏进设置里等于用户永远想不起来它存在，
  /// 而想起它的时候通常已经太晚了。
  Widget _identityBackupTile(
      ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    // ★ 未备份 = 常驻红标。用户不会主动点进去看，所以状态必须长在**入口**上。
    final warn = !_backedUp;
    final accent = warn ? Colors.redAccent : theme.accentColor;
    return Card(
      color: warn
          ? Colors.redAccent.withValues(alpha: isDark ? 0.16 : 0.08)
          : (isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: warn
            ? BorderSide(color: Colors.redAccent.withValues(alpha: 0.6))
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(warn ? Icons.gpp_maybe_outlined : Icons.shield_moon_outlined,
            color: accent),
        title: Row(children: [
          Expanded(child: Text(l10n.idbEntry)),
          if (warn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.idbStatusNotBackedUp,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ]),
        subtitle: Text(
          warn ? l10n.idbStatusNotBackedUpHint : l10n.idbNoScreenshotShort,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const IdentityBackupScreen()),
          );
          // 回来立刻刷新状态：用户很可能刚刚做完备份，红标应当马上熄灭。
          if (mounted) await _refresh();
        },
      ),
    );
  }

  Widget _passportCard(ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_outlined, color: theme.accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.passportCardHeader,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                if (_busy)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 12),
            _kv(isDark, l10n.passportStatLine(l10n.passportPeerLabel, _myId.isEmpty ? '-' : _myId)),
            const SizedBox(height: 6),
            _kv(isDark, l10n.passportStatLine(l10n.passportIssuedLabel, _fmtTime(_issuedAtMs))),
            const SizedBox(height: 12),
            SelectableText(
              _did.isEmpty ? '-' : _did,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.accentColor,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: HelpDot(topic: HelpTopic.passportOffline, color: theme.accentColor),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _did.isEmpty ? null : () => _copy(_did),
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(l10n.passportCopyAction),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.passportRefreshAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(bool isDark, String text) => Text(
        text,
        style: TextStyle(
            fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
      );

  // ------------------------------------------------------------------
  // ② 漏斗（口径由 core 定义，这里只负责显示）
  // ------------------------------------------------------------------

  Widget _funnelCard(ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    final f = _funnel;
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.passportFunnelHeader,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            if (f == null)
              Text('-',
                  style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38))
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statChip(theme, isDark, l10n.passportFunnelProposedLabel, '${f.proposed}'),
                  _statChip(theme, isDark, l10n.passportFunnelConsentedLabel, '${f.consented}'),
                  _statChip(theme, isDark, l10n.passportFunnelHandshakeLabel, '${f.handshake}',
                      highlight: const Color(0xFF16A34A)),
                  _statChip(theme, isDark, l10n.passportFunnelSettledLabel, '${f.settled}'),
                  _statChip(theme, isDark, l10n.passportFunnelInFlightLabel, '${f.inFlight}',
                      highlight: const Color(0xFF64748B)),
                ],
              ),
              const SizedBox(height: 12),
              _kv(isDark, l10n.passportStatLine(
                  l10n.passportFunnelConsentRateLabel, _pct(f.consentRate))),
              const SizedBox(height: 6),
              _kv(isDark, l10n.passportStatLine(
                  l10n.passportFunnelConversionLabel, _pct(f.handshakeConversion))),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: HelpDot(topic: HelpTopic.passportFunnel, color: theme.accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(ThemeProvider theme, bool isDark, String label, String value,
      {Color? highlight}) {
    final c = highlight ?? theme.accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // ③′ M6 网络级信誉
  //
  // 这一块延续本页的两条纪律：
  //   ① **不给信誉分** —— 展示的是证据链（可逐跳验签），不是我们的评价；
  //   ② **不代客同意** —— 签发/收回/追溯都要用户自己点。
  // 另外还有一条本模块特有的：查不到就**说"我不知道"**，绝不显示 0。
  // ------------------------------------------------------------------

  Widget _networkCard(ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_outlined, color: theme.accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.repNetHeader,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: HelpDot(topic: HelpTopic.passportReputation, color: theme.accentColor),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statChip(theme, isDark, l10n.repNetAnchors(
                    _anchorCount, ReputationCaps.minAnchorScore), ''),
                _statChip(theme, isDark, l10n.repNetMineLabel, '${_mine.length}'),
                _statChip(theme, isDark, l10n.repNetForMeLabel, '${_forMe.length}'),
              ],
            ),
            // 0.51.0：「泛泛之交不做传播起点」原为 _anchorCount==0 时的条件小字，
            //   已并入本页信誉卡的 `?`（HelpTopic.passportReputation）——搬家不叠加。
            // 换过钥才解释：履历是**按换钥链归并**出来的，不是凭空多出来的。
            if (_myKeyCount > 1) ...[
              const SizedBox(height: 6),
              Text(l10n.repNetKeysMerged(_myKeyCount),
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _issueEndorsement,
              icon: const Icon(Icons.draw_outlined, size: 16),
              label: Text(l10n.repNetIssueAction),
            ),
            const SizedBox(height: 14),
            _endorsementList(theme, isDark, l10n, l10n.repNetMineLabel, _mine,
                outgoing: true),
            const SizedBox(height: 10),
            _endorsementList(theme, isDark, l10n, l10n.repNetForMeLabel, _forMe,
                outgoing: false),
            const SizedBox(height: 14),
            _traceBox(theme, isDark, l10n),
          ],
        ),
      ),
    );
  }

  Widget _endorsementList(ThemeProvider theme, bool isDark,
      AppLocalizations l10n, String title, List<Endorsement> items,
      {required bool outgoing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(l10n.repNetEmpty,
              style: TextStyle(
                  fontSize: 11, color: isDark ? Colors.white38 : Colors.black38))
        else
          for (final e in items) _endorsementRow(isDark, l10n, e, outgoing),
      ],
    );
  }

  Widget _endorsementRow(
      bool isDark, AppLocalizations l10n, Endorsement e, bool outgoing) {
    final c = _tierColor(e.tier);
    final peer = outgoing ? e.subjectPub : e.issuerPub;
    final revoked = _revokedKeys.contains(e.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6)),
            child: Text(_tierLabel(l10n, e.tier),
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold, color: c)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_short(peer),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
          if (revoked)
            Text(l10n.repNetStatusRevoked,
                style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626)))
          else
            Text(l10n.repNetExpiresLabel,
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(width: 4),
          Text(_fmtTime(e.expiresAtMs).substring(0, 10),
              style: TextStyle(
                  fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
          if (!outgoing)
            TextButton(
                onPressed: () => _verify(e), child: Text(l10n.repNetVerifyAction)),
          if (outgoing && !revoked)
            TextButton(
                onPressed: () => _revoke(e), child: Text(l10n.repNetRevokeAction)),
        ],
      ),
    );
  }

  /// 追溯：输入对方的 DID/公钥 → 摊开**证据链**而不是给一个分数。
  Widget _traceBox(ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    final ctrl = TextEditingController();
    final v = _verdict;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                    labelText: l10n.repNetQueryLabel, isDense: true),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
                onPressed: () => _trace(ctrl.text),
                child: Text(l10n.repNetQueryAction)),
          ],
        ),
        if (v != null) ...[
          const SizedBox(height: 10),
          if (v.isUnknown) ...[
            Text(l10n.repNetQueryUnknown,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54)),
            // 0.51.0：「这不是 0 分 —— 是真的不知道」已并入本页信誉卡的 `?`
          ] else ...[
            Text(
              l10n.repNetQueryKnown(_tierLabel(l10n, v.tier), v.depth,
                  v.confidence.toStringAsFixed(2), v.paths),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _tierColor(v.tier)),
            ),
            const SizedBox(height: 8),
            Text(l10n.repNetPathLabel,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 4),
            for (var i = 0; i < v.path.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${i == 0 ? l10n.repNetPathStart : l10n.repNetPathHop} ${_short(v.path[i])}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
          ],
        ],
      ],
    );
  }

  static String _tierLabel(AppLocalizations l10n, String tier) => switch (tier) {
        ReputationTier.family => l10n.repNetTierFamily,
        ReputationTier.friend => l10n.repNetTierFriend,
        ReputationTier.acquaintance => l10n.repNetTierAcquaintance,
        _ => l10n.passportTrustNone,
      };

  static Color _tierColor(String tier) => switch (tier) {
        ReputationTier.family => const Color(0xFFF59E0B),
        ReputationTier.friend => const Color(0xFF16A34A),
        ReputationTier.acquaintance => const Color(0xFF0D9488),
        _ => const Color(0xFF64748B),
      };

  /// 公钥太长，UI 上只显示首尾（完整值仍可复制/选中）。
  static String _short(String pub) =>
      pub.length <= 16 ? pub : '${pub.substring(0, 8)}…${pub.substring(pub.length - 6)}';

  // ------------------------------------------------------------------
  // ③ 履历
  // ------------------------------------------------------------------

  Widget _ledgerHeader(ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.passportLedgerHeader,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87)),
        ElevatedButton.icon(
          onPressed: _busy ? null : _newIntro,
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: Text(l10n.passportNewIntroAction,
              style: const TextStyle(fontSize: 12, color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 10)),
        ),
      ],
    );
  }

  Widget _entryCard(ThemeProvider theme, bool isDark, AppLocalizations l10n,
      IntroAttestation a, IntroVerifyResult v,
      {required int index}) {
    final mine = a.isInitiator(_myId);
    final peer = mine ? a.counterpartyId : a.initiatorId;
    final trustColor = _trustColor(v.trust);
    final outcome = _outcomeLabel(l10n, a.outcome);

    // 我该做什么：**只列真正做得了的那一个动作**。
    // 显示一堆灰按钮会让用户以为"这页坏了"，而实际是时序未到。
    final canConsent = !mine && a.consentedAtMs == null;
    final canResolve = a.consentedAtMs != null && a.resolvedAtMs == null;
    final canAck = a.resolvedAtMs != null &&
        a.ackAtMs == null &&
        a.outcomeBy != null &&
        a.outcomeBy != _myId;

    return Card(
      key: ValueKey('passport-entry-$index'),
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: trustColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _trustLabel(l10n, v.trust),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: trustColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mine ? l10n.passportDirectionOut : l10n.passportDirectionIn,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                if (outcome.isNotEmpty)
                  Text(outcome,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: trustColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              peer,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87),
            ),
            if (a.topic.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l10n.passportStatLine(l10n.passportTopicLabel, a.topic),
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54)),
            ],
            const SizedBox(height: 4),
            Text(
              l10n.passportStatLine(
                  l10n.passportRoomLabel,
                  a.roomBacked ? a.roomId : '-'),
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 10),
            _verifyDetails(isDark, l10n, v),
            if (canConsent || canResolve || canAck) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (canConsent)
                    ElevatedButton(
                        onPressed: _busy ? null : () => _consent(a),
                        child: Text(l10n.passportConsentAction)),
                  if (canResolve)
                    OutlinedButton(
                        onPressed: _busy ? null : () => _pickOutcome(a),
                        child: Text(l10n.passportResolveAction)),
                  if (canAck)
                    OutlinedButton(
                        onPressed: _busy ? null : () => _ack(a),
                        child: Text(l10n.passportAckAction)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 验证明细：把 [IntroVerifyResult] 的 checks / faults 原样摊开。
  ///
  /// **刻意显示原始代码**（`initiator_sig_valid` 这种）而不是翻译成漂亮文案：
  /// 这一栏的读者是"想核对我有没有骗他"的人，给他代码他能去 `attestation_service.dart`
  /// 对着找；给他一句"签名有效 ✅"，他除了相信我还是只能相信我 ——
  /// 那就把这一栏的意义抵消掉了。
  Widget _verifyDetails(bool isDark, AppLocalizations l10n, IntroVerifyResult v) {
    Widget line(String label, List<String> codes, Color c) {
      if (codes.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '$label: ${codes.join(', ')}',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: c),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.passportVerifyDetails,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.black54)),
        line(l10n.passportChecksLabel, v.checks,
            isDark ? Colors.white54 : Colors.black54),
        line(l10n.passportFaultsLabel, v.faults, const Color(0xFFDC2626)),
      ],
    );
  }

  // ------------------------------------------------------------------
  // ④ §16 透明日志
  // ------------------------------------------------------------------

  Widget _logCard(ThemeProvider theme, bool isDark, AppLocalizations l10n) {
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: theme.accentColor),
                const SizedBox(width: 8),
                Text(l10n.passportLogHeader,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
            const SizedBox(height: 10),
            _kv(isDark, l10n.passportStatLine(
                l10n.passportLogSizeLabel, '$_logSize')),
            const SizedBox(height: 8),
            SelectableText(
              _logRoot.isEmpty ? '-' : _logRoot,
              maxLines: 3,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11, color: theme.accentColor),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: HelpDot(topic: HelpTopic.passportLog, color: theme.accentColor),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _logRoot.isEmpty ? null : () => _copy(_logRoot),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l10n.passportLogCopyAction),
            ),
          ],
        ),
      ),
    );
  }
}
