import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_events.dart';
import '../core/db_helper.dart';
import '../core/lan_service.dart';
import '../core/migration_session.dart';
import '../core/wold_runtime.dart';
import '../l10n/app_localizations.dart';
import 'help_dot.dart';
import 'rotation_chain_screen.dart';

/// 换机直迁（`FENMIG1`）—— 把"身份随人不随设备"做成**用户真的能走完**的一条路。
///
/// ---------------------------------------------------------------------------
/// 这一页守的四条线（与 `device_migration_service.dart` 的三条不变量配套）
/// ---------------------------------------------------------------------------
/// ① **绝不代客同意**：收到对端确认后界面只是**解锁**"确认并迁移"按钮，
///    真正的签名只在用户按下它之后发生。机器可以跑流程，不可以交出身份。
/// ② **两屏短码必须一致**：短码绑定了 `agent_id|old_pub|new_pub|nonce` 四项，
///    中间人换掉任何一个字段，两屏就不再相同 —— 这是"面对面"唯一的安全依据。
/// ③ **私钥不出设备**：老机自己签 ROTATE；新机的种子只在 Hub 确认后才落地。
///    所以界面**必须**写明"不存在复制"这件事，否则用户会误以为有文件被拷来拷去。
/// ④ ★ **履历怎么走，如实说**：换钥退休的是**钥**，不是人 —— 老钥名下收到的背书
///    会沿换钥链归并到新钥（`RotationChain.keysOf` + `WoldRuntime.myIdentityKeys`），
///    新机上再由 `pullMyReputation` 取回并逐条本地验签。这条以前叫"缺口 A"，
///    现已闭合；界面照旧**摆在最上面**，因为"搬不搬得走"是用户最关心的一件事。
/// ⑤ ★★ **两种"失败"分开说、分开做**（2026-09-30）：Hub 拒绝 ⇒ 重新发起；
///    **Hub 已改绑、本机没装上**（`apply_failed`）⇒ **重试落地**。
///    后者若被做成"重新发起"，用户会永久回不到那个身份 —— 所以界面上是两个
///    不同的按钮，文案也各写各的（老机看到的那句还得额外说清"本机也不可用了"）。
class DeviceMigrationScreen extends StatefulWidget {
  const DeviceMigrationScreen({super.key});

  @override
  State<DeviceMigrationScreen> createState() => _DeviceMigrationScreenState();
}

class _DeviceMigrationScreenState extends State<DeviceMigrationScreen> {
  /// null = 还没选角色；'new' = 新机；'old' = 老机。
  String? _role;

  String _myId = '';

  /// 新机：用户填/选的老机 User ID（= 待迁入的身份 ID）。
  final TextEditingController _peerCtl = TextEditingController();

  /// 局域网里能看到的候选（点一下就填进输入框）。
  List<String> _lanPeers = const [];

  /// 当前会话对应的身份 ID。
  String _agentId = '';

  MigrationPhase? _phase;
  String? _fault;
  String? _compareCode;

  bool _busy = false;

  /// 本机是否已经把身份交出去过（老机侧提示用）。
  bool _migratedOut = false;

  StreamSubscription<AppCommand>? _sub;

  /// 兜底窗口的收割节拍（见 `checkTimeouts`）。
  Timer? _sweep;

  @override
  void initState() {
    super.initState();
    LanService().listeners.add(_onLan);
    _sub = AppEvents.stream.listen(_onEvent);
    // 输入框内容变了要重算"发起"按钮的可点状态（否则会显示成灰的却其实能点）。
    _peerCtl.addListener(_onPeerChanged);
    // ★ 15 秒一拍：会话的兜底窗口（5 分钟）**必须有人主动收割** ——
    //   没人看管的会话恰恰不会再有报文进来，`route` 里那道守卫永远不会跑。
    _sweep = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sweepTimeouts(),
    );
    _boot();
  }

  void _onPeerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanService().listeners.remove(_onLan);
    _sub?.cancel();
    _sweep?.cancel();
    // ★ 离开这一页 ⇒ 中止还没走完的会话：没有界面就没人能按那个"确认"键了，
    //   留着它只会让新种子继续待在内存里（会话层不变量 5）。
    //   ⚠️ 刻意跳过 `applyPending`（`isTerminal` 为真）—— 那种会话握着的种子是
    //   那个身份**唯一**还活着的载体，清掉就是真砖头（见 `retryApply`）。
    if (_agentId.isNotEmpty && WoldRuntime.i.isReady) {
      final s = WoldRuntime.i.migrations.byAgent(_agentId);
      if (s != null && !s.isTerminal) {
        unawaited(WoldRuntime.i.migrations.cancel(_agentId, reason: 'page_closed'));
      }
    }
    _peerCtl.removeListener(_onPeerChanged);
    _peerCtl.dispose();
    super.dispose();
  }

  void _sweepTimeouts() {
    if (!WoldRuntime.i.isReady) return;
    try {
      // 副作用（阶段变 failed）通过 [MigrationStateChangedEvent] 回到
      // `_onEvent`，所以这里不必自己 setState。
      WoldRuntime.i.migrations.checkTimeouts();
    } catch (_) {
      // 运行时正在起来/正在销毁 —— 静默，下一拍再来。
    }
  }

  void _onLan() {
    if (!mounted) return;
    setState(() => _lanPeers = LanService().connectedLanAgents);
  }

  Future<void> _boot() async {
    final id = await DBHelper.getAmbassador('my_agent_id') ?? '';
    // `migrations` 是 late final：运行时还没起来时碰它会抛 LateInitializationError。
    var out = false;
    var pendingApply = '';
    if (WoldRuntime.i.isReady) {
      try {
        out = await WoldRuntime.i.migrations.isMigratedOut();
        // ★ 上一轮若卡在"Hub 已改绑、本机没装上"，这里必须把它认出来：
        //   否则用户重进这一页只会看到"选角色"，而那颗种子在内存里
        //   等着一次永远不会发生的重试。
        for (final s in WoldRuntime.i.migrations.sessions) {
          if (s.isInitiator && s.applyPending) {
            pendingApply = s.agentId;
            break;
          }
        }
      } catch (_) {
        // 读不到就按"没迁出 / 没有待落地"显示，动作处会再判一次
      }
    }
    if (!mounted) return;
    setState(() {
      _myId = id;
      _migratedOut = out;
      _lanPeers = LanService().connectedLanAgents;
      if (pendingApply.isNotEmpty) {
        _agentId = pendingApply;
        _role = 'new';
        _phase = MigrationPhase.failed;
        _fault = MigrationSessionFault.applyFailed;
      }
    });
  }

  void _onEvent(AppCommand cmd) {
    if (cmd is! MigrationStateChangedEvent) return;
    if (!mounted) return;
    // 只跟"自己这条会话"（老机可能同时被多方请求，UI 只认当前那一条）。
    if (_agentId.isNotEmpty && cmd.agentId != _agentId) return;
    setState(() {
      _agentId = cmd.agentId;
      _phase = _phaseFromName(cmd.phase);
      _fault = cmd.fault;
      _compareCode = cmd.compareCode;
    });
    if (_phase == MigrationPhase.done || _phase == MigrationPhase.failed) {
      _boot(); // 终态：刷新"已迁出"标记
    }
  }

  static MigrationPhase? _phaseFromName(String name) {
    for (final p in MigrationPhase.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 语言无关的失败码 → 可照做的文案。
  String _faultText(AppLocalizations l10n, String? code) {
    switch (code) {
      case MigrationSessionFault.peerMismatch:
        return l10n.dmErrPeerMismatch;
      case MigrationSessionFault.bindingMismatch:
      case MigrationSessionFault.badSignature:
        return l10n.dmErrBadCode;
      case MigrationSessionFault.cancelledByPeer:
        return l10n.dmCancelled;
      case MigrationSessionFault.sessionTimeout:
        return l10n.dmErrSessionTimeout;
      // ★ `apply_failed` **不能**和"Hub 拒绝"共用一句话：
      //   它意味着服务器上已经改绑了，两侧处境完全不同（新机要重试落地，
      //   老机则连自己也不能再用这个身份了）。
      case MigrationSessionFault.applyFailed:
        return _role == 'old'
            ? l10n.dmErrApplyFailedOld
            : l10n.dmErrApplyFailed;
      case MigrationSessionFault.notConfirmed:
      case MigrationSessionFault.wrongPhase:
      case MigrationSessionFault.notSigned:
      case MigrationSessionFault.notAsked:
      case MigrationSessionFault.badWire:
        return l10n.dmErrGeneric(code ?? 'unknown');
      case 'hub_not_configured':
        return l10n.dmNotConfigured;
      case 'network_error':
      case 'timeout':
        return l10n.dmErrTimeout;
      default:
        return l10n.dmErrHubFailed(code ?? 'unknown');
    }
  }

  // ------------------------------------------------------------- 动作

  /// 运行时未就绪时不给"半死"的操作入口 —— 与 `initError` 的可见性纪律一致。
  bool _requireRuntime(AppLocalizations l10n) {
    if (WoldRuntime.i.isReady) return true;
    _toast(l10n.dmErrGeneric('runtime_not_ready'));
    return false;
  }

  Future<void> _startAsNew() async {
    final l10n = AppLocalizations.of(context);
    if (!_requireRuntime(l10n)) return;
    final peer = _peerCtl.text.trim();
    if (peer.isEmpty) {
      // 正常路径上按钮已置灰，这里只是兜底（避免"点了没反应"被当成卡死）。
      _toast(l10n.dmErrGeneric('user_id_required'));
      return;
    }
    setState(() {
      _busy = true;
      _fault = null;
      _compareCode = null;
      _phase = null;
      _agentId = peer;
    });
    try {
      final s = await WoldRuntime.i.migrations.startInitiator(
        agentId: peer,
        targetPeerId: peer,
      );
      if (s == null) {
        _toast(l10n.dmErrGeneric('same_key'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _matchAndContinue() async {
    if (!_requireRuntime(AppLocalizations.of(context))) return;
    await WoldRuntime.i.migrations.userConfirmInitiator(_agentId);
  }

  /// **新机**：Hub 已改绑、本机上次没装上 —— 重试**落地**（补装新钥并补发 ack）。
  ///
  /// ★ 这条路**不能**用旁边的"重试"（= 重新发起）代替：重新发起会生成一把
  ///   全新的钥，而 Hub 上的活跃钥已经是上一把 ⇒ 必被 `not_current_key` 拒 ⇒
  ///   用户从此再也回不到那个身份。两者在界面上必须是两个不同的按钮。
  Future<void> _retryApply() async {
    final l10n = AppLocalizations.of(context);
    if (!_requireRuntime(l10n)) return;
    setState(() => _busy = true);
    try {
      final step = await WoldRuntime.i.migrations.retryApply(_agentId);
      if (!step.ok) _toast(_faultText(l10n, step.fault));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmResponder() async {
    final l10n = AppLocalizations.of(context);
    if (!_requireRuntime(l10n)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dmOldConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.dmOldConfirmBody),
                const SizedBox(height: 12),
                // ★ 履历去向：在**按下确认之前**说清楚，而不是事后。
                //   （以前这里讲的是"履历会归零"，现已闭合 —— 文案随之改成实际情况。）
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.dmGapATitle,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(l10n.dmGapABody),
                      ]),
                ),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.dmCancelAction)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.dmConfirmAction)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await WoldRuntime.i.migrations.userConfirmResponder(_agentId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    if (!_requireRuntime(l10n)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dmCancelConfirmTitle),
        content: Text(l10n.dmCancelConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.dmCancelAction)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonConfirm)),
        ],
      ),
    );
    if (ok != true) return;
    await WoldRuntime.i.migrations.cancel(_agentId);
    _toast(l10n.dmCancelled);
    if (mounted) setState(() => _role = null);
  }

  // ------------------------------------------------------------- 构件

  Widget _idCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.tag),
        title: const Text('User ID'),
        subtitle: SelectableText(_myId.isEmpty ? '—' : _myId),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: _myId.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: _myId));
                  _toast(l10n.idbCopiedToast);
                },
        ),
      ),
    );
  }

  Widget _gapACard(AppLocalizations l10n, ThemeData theme) {
    final color = theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.report_problem_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Text(l10n.dmGapATitle,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color)),
        ]),
        const SizedBox(height: 6),
        Text(l10n.dmGapABody, style: theme.textTheme.bodySmall),
      ]),
    );
  }

  Widget _compareCard(AppLocalizations l10n, ThemeData theme) {
    final code = _compareCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.dmCompareTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Center(
            child: code == null
                ? Text(l10n.dmWaitingPeer, style: theme.textTheme.bodyMedium)
                : SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(l10n.dmCompareBody, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Text(l10n.dmNoKeyLeaves, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _cancel,
                child: Text(l10n.dmCodeNoMatchAction),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed:
                    (_busy || code == null) ? null : _matchAndContinue,
                child: Text(l10n.dmCodeMatchAction),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _phaseLine(AppLocalizations l10n, ThemeData theme) {
    final text = switch (_phase) {
      MigrationPhase.offered => l10n.dmPhaseOffered,
      MigrationPhase.peerConfirmed => l10n.dmCompareTitle,
      MigrationPhase.signed => l10n.dmPhaseSigned,
      MigrationPhase.awaitingHub => l10n.dmPhaseAwaitingHub,
      MigrationPhase.done =>
        _role == 'new' ? l10n.dmDoneNew : l10n.dmDoneOld,
      MigrationPhase.failed => _faultText(l10n, _fault),
      _ => l10n.dmWaitingPeer,
    };
    final failed = _phase == MigrationPhase.failed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_phase == MigrationPhase.done)
          const Icon(Icons.check_circle, color: Colors.green, size: 18)
        else if (failed)
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18)
        else
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ]),
    );
  }

  /// 新机：选/填老机 User ID。
  Widget _newPhoneBody(AppLocalizations l10n, ThemeData theme) {
    final started = _phase != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!started) ...[
        TextField(
          controller: _peerCtl,
          decoration: const InputDecoration(labelText: 'User ID'),
        ),
        const SizedBox(height: 10),
        if (_lanPeers.isNotEmpty) ...[
          Text(l10n.dmPeerFound, style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final p in _lanPeers)
                ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _peerCtl.text = p),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: (_busy || _peerCtl.text.trim().isEmpty)
              ? null
              : _startAsNew,
          icon: const Icon(Icons.send),
          label: Text(l10n.dmRoleNewAction),
        ),
      ] else ...[
        _phaseLine(l10n, theme),
        if (_phase == MigrationPhase.offered ||
            _phase == MigrationPhase.peerConfirmed) ...[
          const SizedBox(height: 4),
          _compareCard(l10n, theme),
        ],
        if (_phase == MigrationPhase.failed) ...[
          const SizedBox(height: 8),
          // ★★ 两种"失败"在动作上是**互斥**的，所以必须是两个按钮：
          //   · `apply_failed`（Hub 已改绑、本机没装上）⇒ **重试落地**
          //     （重新发起会生成一把全新的钥，而 Hub 上的活跃钥已经是上一把，
          //      必被 `not_current_key` 拒 ⇒ 永久卡死）；
          //   · 其它（Hub 拒绝 / 超时 / 短码不符…）⇒ 重新发起一次。
          if (_fault == MigrationSessionFault.applyFailed)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _retryApply,
                icon: const Icon(Icons.download_done),
                label: Text(l10n.dmRetryApplyAction),
              ),
            )
          else
            OutlinedButton(
                onPressed: () => setState(() {
                      _phase = null;
                      _fault = null;
                    }),
                child: Text(l10n.dmRetryAction)),
        ],
      ],
    ]);
  }

  /// 老机：等请求 → 比对 → 确认。
  Widget _oldPhoneBody(AppLocalizations l10n, ThemeData theme) {
    if (_migratedOut) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.dmDoneOld),
          subtitle: Text(l10n.dmDoneOldHint),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_phase == null)
        _phaseLine(l10n, theme)
      else ...[
        _phaseLine(l10n, theme),
        if (_phase == MigrationPhase.awaitingPeerConfirm ||
            _phase == MigrationPhase.peerConfirmed) ...[
          const SizedBox(height: 4),
          _compareCard(l10n, theme),
        ],
        if (_phase == MigrationPhase.peerConfirmed) ...[
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _busy ? null : _confirmResponder,
            icon: const Icon(Icons.key_outlined),
            label: Text(l10n.dmConfirmAction),
          ),
        ],
        if (_phase == MigrationPhase.done) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child:
                  Text(l10n.dmDoneOldHint, style: theme.textTheme.bodySmall),
            ),
          ),
        ],
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dmTitle),
        actions: [
          // 0.51.0：整页玩法（同 Wi-Fi / 搬什么 / 搬完做什么）收进页面级 `?`
          const HelpAction(topic: HelpTopic.deviceMigration),
          IconButton(
            tooltip: l10n.rcTitle,
            onPressed: _myId.isEmpty
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RotationChainScreen(agentId: _myId),
                    )),
            icon: const Icon(Icons.link),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.dmIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          // ★ 履历去向从进入这一页就摆在最上面，而不是藏在确认框里。
          _gapACard(l10n, theme),
          const SizedBox(height: 12),
          _idCard(l10n, theme),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.dmBackupReminderTitle,
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(l10n.dmBackupReminderBody,
                        style: theme.textTheme.bodySmall),
                  ]),
            ),
          ),
          const SizedBox(height: 16),
          if (_role == null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_iphone),
                title: Text(l10n.dmRoleNewTitle),
                subtitle: Text(l10n.dmRoleNewBody),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => setState(() => _role = 'new'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_android),
                title: Text(l10n.dmRoleOldTitle),
                subtitle: Text(l10n.dmRoleOldBody),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => setState(() => _role = 'old'),
              ),
            ),
          ] else ...[
            Row(children: [
              Text(
                _role == 'new' ? l10n.dmRoleNewTitle : l10n.dmRoleOldTitle,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: (_busy || _phase != null) ? null : _cancel,
                child: Text(l10n.dmCancelAction),
              ),
            ]),
            const SizedBox(height: 6),
            _role == 'new'
                ? _newPhoneBody(l10n, theme)
                : _oldPhoneBody(l10n, theme),
          ],
        ],
      ),
    );
  }
}
