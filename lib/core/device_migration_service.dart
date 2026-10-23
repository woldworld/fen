/// 换机直迁的**服务层**：把会话层接到真实世界里。
///
/// ---------------------------------------------------------------------------
/// 它接的四条线
/// ---------------------------------------------------------------------------
/// ① **网络**：出站走既有 `outbound`（近场 / 局域网 / 云端全通道），
///    入站由 `agent_service` 的 `_interceptStructuredMessage` 交进来 ——
///    与委托 / 互介卡 / 在场 / 互介存证**同一条**截获链。
///    ⚠️ 因此这里**不新增任何服务器角色**：报文只在既有通道上跑。
/// ② **身份**：旧机用自己的活跃私钥签 ROTATE（`AgentIdentity.signBase64`），
///    新机的种子由本层生成并**只在 Hub 确认之后**才装进本机。
/// ③ **UI**：只发 [MigrationStateChangedEvent]（带阶段码），文案由 UI 按当前语言拼装。
/// ④ **留痕**：`migration_*` 埋点，与其它模块同款（"发出去没回音"与"压根没发出去"必须可分）。
///
/// ---------------------------------------------------------------------------
/// 五条不变量
/// ---------------------------------------------------------------------------
/// 1. ★★ **绝不代客同意**：收到对端的 `confirm` 只让会话进入 `peerConfirmed`，
///    签名必须由 UI 在用户按下确认键之后调 [userConfirmResponder]。
///    这条与 M6 互介存证的"绝不代客同意"是同一条：机器可以跑流程，不可以交出身份。
/// 2. ★★ **落盘在前、回报在后**：`submitToHub` 的次序是
///    `Hub ok → RestorePlan.apply 成功 → 才发 ack(ok:true)`。两个方向都踩过/差点踩：
///    · 先 apply 后 ack：服务端一旦拒绝，这台机器就握着一把没人认的钥匙；
///    · **先 ack 后 apply**（本次修掉的实现）：老机已经自锁、新机却没装上新钥 ——
///      用户同时失去新旧两台机器。
///    落盘失败一律回报 `ack(ok:false, apply_failed)`，且**保留种子**可重试
///    （见 [retryApply]：那条路**不能**用"重新发起"代替）。
/// 3. ★ **旧机不自锁到事情办成**：只有收到 **验签通过的** `ack(ok:true)` 才写
///    "身份已迁出"标记；Hub 拒绝 / ack 验签不过 / 落盘失败时，旧机必须仍然可用。
/// 4. ★★ **ack 由新钥签名**（`MigrationAck`）：老机收到 `ok:true` 就自锁，
///    而自锁是单向动作 —— 一条无凭据的 ack 等于把"废掉老机"变成任何人可点的按钮。
///    签名由 `KeyBackup.signWithSeed` 出（此刻本机只有种子，活跃身份还是旧的）。
/// 5. ★ **兜底窗口与终态清理**：会话存活上限见 `MigrationSession.ttlMs`，
///    由 [checkTimeouts] 主动收割（不能只等报文来触发 —— 没人看管的会话
///    恰恰是"不会再有报文"的那一种）；走完（`done`）即 [forget]，
///    种子随之出内存。
library;

import 'dart:math';
import 'dart:typed_data';

import 'agent_identity.dart';
import 'app_events.dart';
import 'app_logger.dart';
import 'cloud_service.dart';
import 'db_helper.dart';
import 'device_migration.dart';
import 'identity_recovery.dart';
import 'identity_rotation.dart';
import 'key_backup.dart';
import 'migration_session.dart';

/// 出站通道：`(对方分身 ID, 线格式文本) → 是否投递成功`。
/// 与 `DelegationSender` 同款签名，便于共用 `WoldRuntime.outbound`。
typedef MigrationSender = Future<bool> Function(
    String targetAgentId, String wire);

class DeviceMigrationService {
  /// 出站通道（由 `WoldRuntime` 注入，与其它 relay 共用同一条）。
  final MigrationSender send;

  /// 我的分身 ID。
  final Future<String> Function() selfId;

  /// 埋点回调（`WoldRuntime._track`）。
  final void Function(String name, Map<String, Object?> props)? onEvent;

  DeviceMigrationService({
    required this.send,
    required this.selfId,
    this.onEvent,
  });

  /// ★★ 一次性 nonce 账**跨会话共享**（按设备一份）。
  ///
  /// 只做成本会话私有的账是**没用的**：会话内的重放已被阶段 guard 挡住，
  /// 真正的重放场景是"用户重开一次迁移，攻击者把上一轮截到的要约塞进新会话"。
  final MigrationNonceLedger _ledger = MigrationNonceLedger();

  /// 进行中的会话（键 = 被迁移的身份 ID）。
  final Map<String, MigrationSession> _sessions = {};

  /// 新机侧待安装的新种子。
  ///
  /// ⚠️ **绝不落库、绝不进日志、绝不出现在报文里** —— 它只在这台设备的内存里
  /// 存活到 Hub 确认那一刻，然后交给 `RestorePlan.apply`。
  final Map<String, List<int>> _pendingSeeds = {};

  // ---------------- 落盘的"已迁出"标记 ----------------

  /// 身份已迁出的时间戳（毫秒）。**读了就必须有人写** ——
  /// 本文件的 [userConfirmResponder] / [onIncoming] 是唯一写入方。
  static const String migratedOutAtKey = 'migration_migrated_out_at';

  /// 已迁出的身份 ID（用于 UI 显示"这条路已经走过了"，而不是一个光秃秃的时间）。
  static const String migratedOutAgentKey = 'migration_migrated_out_agent';

  /// 本机身份是否**已经交出去过**。
  Future<bool> isMigratedOut() async =>
      (await DBHelper.getAmbassador(migratedOutAtKey)) != null;

  /// UI 展示用：已迁出的时间戳（毫秒），未迁出为 null。
  Future<int?> migratedOutAt() async {
    final raw = await DBHelper.getAmbassador(migratedOutAtKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> _lockOut(String agentId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await DBHelper.saveAmbassador(migratedOutAtKey, '$now');
    await DBHelper.saveAmbassador(migratedOutAgentKey, agentId);
    onEvent?.call('migration_migrated_out', {'agent_id': agentId, 'at': now});
  }

  /// ★★ 老机自锁之后**擦除本机身份**（外部审计 P2⑤(b) 修复）。
  ///
  /// 病根：[isMigratedOut] 只是"这台手机以后不再用这个身份"的一个**标记**，
  ///   **私钥仍然躺在钥匙串里**。于是"同一身份、两台活体"的物理条件并没有消失：
  ///   只要本机被回滚（备份还原 / 卸载重装旧包 / 改系统时间），旧钥照样签得出来，
  ///   而 Hub 侧那道 `not_current_key` 是**唯一**还拦着它的东西 —— 单点。
  ///   **移交身份却把旧钥匙留在手里，等于交房不交钥匙。**
  ///
  /// 做什么（顺序有讲究，且**刻意不"删掉种子"**）：
  ///   ① **换**一枚全新随机种子 —— 换而不是删：删了会让所有取身份的调用点撞上
  ///      "无钥状态"（`publicKeyBase58()` 抛错），那是人为制造的全机故障；
  ///      放在第一步是因为它是唯一真正**解决**问题的一步（旧私钥当场消失）；
  ///   ② 换一个全新 `my_agent_id` —— 本机从此是**另一个身份**，
  ///      与 Hub 上那个身份再无关系（这才是"擦除"的实质）；
  ///   ③ 撕掉接缝表里**旧身份**那一行（否则本机仍宣称"我是旧身份的当前钥持有者"）；
  ///   ④ 清掉**身份锚** `identity_root_did`（那是旧身份的锚）。
  ///
  /// ⚠️ 若 ①②之间中断，本机处在"新钥 + 旧 agent_id"的半成品上：这种状态
  ///   **恰好被 P2⑤(a) 的服务端闸挡住**（旧身份已是 ed25519，声明的新钥 ≠ 现活跃钥
  ///   ⇒ 409 `key_change_requires_rotation`）—— 它**不能**冒充旧身份干任何事，
  ///   而用户可以重试擦除。这是刻意选的失败方向：宁可半成品也不留旧钥。
  ///
  /// 刻意**保留**：[migratedOutAtKey] / [migratedOutAgentKey] 两个标记
  ///   （UI 靠它说清"这条路已经走过了"，也挡住第二次迁移），以及本地只追加的
  ///   `key_rotations` 历史（那是证据，不含任何私钥）。
  Future<void> _wipeSeveredIdentity(String oldAgentId) async {
    final identity = AgentIdentity();
    try {
      await identity.installSeed(_secureSeed());
      await DBHelper.saveAmbassador('my_agent_id', DBHelper.newAgentId());
      await identity.dropSeam(oldAgentId);
      await identity.clearRootDid();
      onEvent?.call('migration_severed_local_identity', {'agent_id': oldAgentId});
    } catch (e) {
      // 擦除失败**必须可见**：它意味着旧私钥还留在本机，而这正是
      // "两台活体分叉"的物理条件 —— 静默失败等于这件事根本没做。
      AppLogger.w('migration.wipe_severed_identity', e);
      onEvent?.call('migration_severed_wipe_failed', {
        'agent_id': oldAgentId,
        'error': e.toString(),
      });
    }
  }

  // ---------------- 会话查询（UI 用） ----------------

  List<MigrationSession> get sessions =>
      _sessions.values.toList(growable: false);

  MigrationSession? byAgent(String agentId) => _sessions[agentId];

  /// 结束并丢弃一个会话（用户点了"取消"、终态清理、或超时收割）。
  ///
  /// ★ 它**同时清掉待装种子** —— 这是"新种子只在内存里活一段"那条承诺的落点：
  ///   会话没了，种子就不能还留在内存里。
  void forget(String agentId) {
    _sessions.remove(agentId);
    _pendingSeeds.remove(agentId);
  }

  /// ★ 主动收割超时会话（UI 定时调用）。返回被判作废的身份 ID 列表。
  ///
  /// 为什么不能只靠 `route()` 里那道守卫：**没人看管的会话恰恰不再有报文**，
  /// 那条路永远不会被触发 —— 兜底窗口会退化成一个"写在代码里但从不生效"的常量。
  ///
  /// ⚠️ 唯一的例外是 `applyPending`（Hub 已改绑、本机落盘失败）那种终态：
  ///    `expireIfStale` 对终态一律不判，所以它**不会**被这里清掉 ——
  ///    它握着的种子是那个身份**唯一**还活着的载体（旧钥在 Hub 上已作废），
  ///    只能由用户 [retryApply] 或显式 [cancel] 来结束。这是刻意留的出口。
  List<String> checkTimeouts() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = <String>[];
    for (final s in _sessions.values.toList(growable: false)) {
      if (s.expireIfStale(now) == null) continue;
      expired.add(s.agentId);
      onEvent?.call('migration_timeout', {
        'agent_id': s.agentId,
        'role': s.role.name,
        'age_ms': s.ageMs(now),
      });
      _notify(s);
    }
    // 第二趟再清：`_settle` 会改 `_sessions`，不能在遍历里做。
    for (final id in expired) {
      final s = _sessions[id];
      if (s != null) _settle(s);
    }
    return expired;
  }

  // ---------------- 新机侧 ----------------

  /// **新机**：发起一次接管。
  ///
  /// [agentId] 要被接管的身份（用户从恢复页确认过的那个）；
  /// [targetPeerId] 老机的分身 ID（局域网里选出来的对端）；
  /// [newSeed] 可注入 —— 让测试可复现，生产不传即安全随机。
  ///
  /// 返回会话，或 null（已迁出过的身份不接受再发起）。
  Future<MigrationSession?> startInitiator({
    required String agentId,
    required String targetPeerId,
    List<int>? newSeed,
  }) async {
    final seed = newSeed ?? _secureSeed();
    final pub = await KeyBackup.pubFromSeed(seed);
    // 与老机"用我自己接管我自己"同样无意义：本地先挡一道，省一次往返。
    if (pub == await _myPubOrEmpty()) return null;

    final s = MigrationSession.startAsInitiator(
      agentId: agentId,
      peerId: targetPeerId,
      newPub: pub,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      ledger: _ledger,
    );
    _sessions[agentId] = s;
    _pendingSeeds[agentId] = seed;
    await _sendStep(s, s.beginRequest());
    _notify(s);
    onEvent?.call('migration_started', {
      'role': s.role.name,
      'agent_id': agentId,
      'peer': targetPeerId,
    });
    return s;
  }

  /// **新机**：用户在看到两屏短码一致后按下"继续"。
  Future<MigrationStep> userConfirmInitiator(String agentId) async {
    final s = _sessions[agentId];
    if (s == null) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    final step = s.confirm();
    await _sendStep(s, step);
    _notify(s);
    return step;
  }

  /// **新机**：把已签名的 ROTATE 交给 Hub；Hub 确认后**先落盘**，落盘成功才回报老机。
  ///
  /// 这是"③ 必须在 ④ 之前"那条次序的落点（见 `identity_recovery.dart` 文件头），
  /// 且比它多一条：**ack 必须排在本机落盘之后**（见文件头不变量 2）。
  Future<HubRotateResult> submitToHub(String agentId) async {
    final s = _sessions[agentId];
    if (s == null || !s.readyToSubmitHub) {
      return const HubRotateResult(
          ok: false, code: MigrationSessionFault.wrongPhase);
    }
    final rotation = s.rotation!;
    final res = await CloudService().rotateIdentity(rotation);

    // ---------- ① 先落盘：世界真的变了，才有资格对外宣称 ----------
    var ok = res.ok;
    var code = res.code;
    if (ok) {
      final seed = _pendingSeeds[agentId];
      if (seed == null) {
        // Hub 说成功、本机却没有待装的种子 —— 只可能是一次重复提交
        // （上一轮已经装过）。记一条，并**照旧回报 ok:true**：
        // 本机活跃钥此刻就是新钥，ack 仍签得出来，老机该自锁。
        onEvent?.call('migration_apply_skipped', {
          'agent_id': agentId,
          'reason': 'no_pending_seed',
        });
      } else {
        // 先记下身份锚：落盘失败要重试时，didAnchor 必须还是这一个。
        s.hubDid = res.did;
        try {
          await _restorePlanFor(s, rotation, seed).apply(didAnchor: res.did);
          onEvent?.call('migration_applied', {'agent_id': agentId});
        } catch (e) {
          // ★★ 落盘失败 ⇒ **绝不**回报 ok:true，且**保留种子**（可重试落地）。
          //    Hub 那边活跃钥已经改绑，所以这**不是**"什么都没发生"：
          //    本机若不把新钥装上，旧钥已废、新钥没装 —— 两边都够不着。
          //    救回它的唯一办法是 [retryApply]（**重新发起是错的**，见那里的说明）。
          ok = false;
          code = MigrationSessionFault.applyFailed;
          AppLogger.w('migration.apply', e);
          onEvent?.call('migration_apply_failed', {
            'agent_id': agentId,
            'error': e.toString(),
          });
        }
      }
    }

    // ---------- ② 再回报：ack 由**新钥**签名，老机据此才敢自锁 ----------
    // ⚠️ 顺序上这里**必须**在 `_pendingSeeds.remove` **之前**取签名器：
    //    此刻本机只有种子（活跃身份还是旧的），签名靠的就是它。
    final step = await s.hubResult(
      ok: ok,
      faultCode: code,
      did: res.did,
      sign: _ackSigner(agentId),
    );
    final delivered = await _sendStep(s, step);
    if (ok && step.ok && !delivered) {
      // ack 没送到 ⇒ 老机不会自锁，两台活体分叉的口子又开了。
      // 这里**如实留痕**：新机改不了这个事实，至少别让它静默发生。
      //（可指望的兜底：老机下次与 Hub 做任何签名交互都会吃到 `not_current_key`。）
      onEvent?.call('migration_ack_undelivered', {
        'agent_id': agentId,
        'peer': s.peerId,
      });
    }
    if (ok && step.ok) {
      // 回报已成 ⇒ 种子使命完成（`apply` 已经把它写进钥匙串）。
      _pendingSeeds.remove(agentId);
    }
    _notify(s);
    _settle(s);
    return ok ? res : HubRotateResult(ok: false, code: code, did: res.did);
  }

  /// **新机**：落盘失败后的**重试落地** —— 只有这一种情况可用，也只有它能救。
  ///
  /// ★ 为什么必须有这条路：Hub 已经改绑到新钥，而本机没装上 ⇒
  ///   旧钥在 Hub 上作废、新钥又没落进钥匙串。**不重试就是砖头。**
  ///
  /// ⚠️ 它**不能**被"重新发起"代替：重新发起会生成一把**全新的钥**，
  ///    而 Hub 上的活跃钥已经是上一把 ⇒ 新的 ROTATE 必被 `not_current_key` 拒，
  ///    用户从此再也回不到那个身份。这正是把 `apply_failed` 单独做成一个
  ///    稳定码、而不是混在"Hub 失败"里的全部理由。
  ///
  /// `RestorePlan.apply` 三步都是幂等的（见 `identity_recovery.dart` 的注释），
  /// 所以重复调用是安全的；成功之后才补发 `ack(ok:true)`。
  Future<MigrationStep> retryApply(String agentId) async {
    final s = _sessions[agentId];
    final rotation = s?.rotation;
    final seed = _pendingSeeds[agentId];
    if (s == null || rotation == null || seed == null || !s.retryableApply) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    try {
      await _restorePlanFor(s, rotation, seed).apply(didAnchor: s.hubDid);
      onEvent?.call('migration_applied', {'agent_id': agentId, 'retry': true});
    } catch (e) {
      AppLogger.w('migration.apply', e);
      onEvent?.call('migration_apply_failed', {
        'agent_id': agentId,
        'retry': true,
        'error': e.toString(),
      });
      _notify(s);
      return MigrationStep.failed(MigrationSessionFault.applyFailed);
    }
    // 落地成功 ⇒ 补发 **ok:true** 的签名 ack，老机到这一刻才该自锁。
    final step = await s.ackAfterApplyRetry(did: s.hubDid, sign: _ackSigner(agentId));
    final delivered = await _sendStep(s, step);
    if (step.ok && !delivered) {
      onEvent?.call('migration_ack_undelivered', {
        'agent_id': agentId,
        'peer': s.peerId,
      });
    }
    if (step.ok) _pendingSeeds.remove(agentId);
    _notify(s);
    _settle(s);
    return step;
  }

  // ---------------- 老机侧 ----------------

  /// **老机**：用户在确认对话框里按下"交出身份"。
  ///
  /// ★ 这是全项目**唯一**一处"把身份签出去"的动作，因此它只由 UI 在
  /// 用户明确确认后调用。会话层自己**没有任何路径**能走到签名。
  Future<MigrationStep> userConfirmResponder(String agentId) async {
    final s = _sessions[agentId];
    if (s == null) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    // ★ 过期会话**不许签**：这里先收割一次兜底窗口，再谈"能不能签"。
    final stale = s.expireIfStale(DateTime.now().millisecondsSinceEpoch);
    if (stale != null) {
      onEvent?.call('migration_signed', {
        'agent_id': agentId,
        'ok': false,
        'fault': stale,
      });
      _notify(s);
      return MigrationStep.failed(stale);
    }
    if (!s.canSign) {
      // 对端还没确认、或已过这一步 —— 一律不许签。
      return MigrationStep.failed(MigrationSessionFault.notConfirmed);
    }
    final identity = AgentIdentity();
    final step = await s.signRotation(
      sign: (m) => identity.signBase64(m),
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _sendStep(s, step);
    _notify(s);
    onEvent?.call('migration_signed', {
      'agent_id': agentId,
      'ok': step.ok,
      if (!step.ok) 'fault': step.fault,
    });
    return step;
  }

  // ---------------- 入站（relay 入口） ----------------

  /// 截获链入口：返回 **true 表示"这是迁移报文，已被消费"**。
  ///
  /// 返回 false 交给聊天流水线（它根本不是迁移报文）。
  ///
  /// ⚠️ **解析不出来 ≠ 交给聊天**：解析出来了但不是给本机会话的，也照样消费掉并丢弃
  /// （与 `DelegationRelay.onIncoming` 同款）。否则一条伪造的迁移报文会被当成
  /// 一句用户消息送进大模型。
  Future<bool> onIncoming(String fromAgentId, String text) async {
    final packet = MigrationWire.tryParse(text);
    if (packet == null) return false;

    // 一次入站只取一次时钟：会话开建、路由判定、超时收割都用它，
    // 免得"同一条报文在不同分支里看到不同时间"。
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    var s = _sessions[packet.agentId];
    if (s == null) {
      s = await _maybeAcceptRequest(packet, fromAgentId, nowMs);
      if (s == null) {
        onEvent?.call('migration_dropped', {
          'from': fromAgentId,
          'kind': packet.kind,
          'reason': 'no_session',
        });
        return true;
      }
    }
    // 会话的对端必须就是这条报文的来源（防"第三方替对端说话"）。
    if (s.peerId != fromAgentId) {
      onEvent?.call('migration_dropped', {
        'from': fromAgentId,
        'reason': 'peer_mismatch',
        'expect': s.peerId,
      });
      return true;
    }

    final step = await s.route(packet, nowMs: nowMs);
    if (!step.ok) {
      onEvent?.call('migration_step_rejected', {
        'agent_id': packet.agentId,
        'kind': packet.kind,
        'fault': step.fault,
      });
    }
    await _sendStep(s, step);

    // 新机收到合法的 ROTATE ⇒ 用户此前已经按过确认，这里把流程续跑完
    // （Hub 提交 + **落盘** + 回报）。**不是**新增一次用户决策，所以不必再问一次。
    if (s.isInitiator && step.ok && s.readyToSubmitHub) {
      await submitToHub(packet.agentId);
    }
    // 老机收到**验签通过的** ack(ok:true) ⇒ 事情办成了，这才自锁。
    // ⚠️ `migratedOut` 只在 `onAck` 验签通过后才可能为真（见 `migration_session.dart`）；
    //    这里再加一道"库里没写过"的判断，避免重复 ack 把时间戳改写一遍。
    if (!s.isInitiator && s.migratedOut && !await isMigratedOut()) {
      await _lockOut(packet.agentId);
      // ★★ 自锁只是"以后不用这个身份"，**私钥还在本机**就不是真正的移交。
      //    手上有旧私钥 + Hub 上那个身份 ⇒ "同一身份两台活体"的**物理条件**仍在，
      //    此时唯一还拦着它的东西是 Hub 侧的 `not_current_key`。
      await _wipeSeveredIdentity(packet.agentId);
    }
    _notify(s);
    _settle(s);
    return true;
  }

  /// 只有"这条 request 指向的正是本机当前身份"时，才开一个**老机侧**会话。
  ///
  /// 别的身份来请求，本机既不是那个身份、也没有它的钥匙 —— 直接丢弃并留痕。
  Future<MigrationSession?> _maybeAcceptRequest(
    MigrationPacket p,
    String fromAgentId,
    int nowMs,
  ) async {
    if (p.kind != MigrationWireKind.request) return null;
    final me = await selfId();
    if (p.agentId != me) return null;
    // 已经交出去过的身份不再有第二次（否则"两台活体分叉"就有了口子）。
    if (await isMigratedOut()) {
      onEvent?.call('migration_dropped', {
        'from': fromAgentId,
        'reason': 'already_migrated_out',
      });
      return null;
    }
    final pub = await _myPubOrEmpty();
    if (pub.isEmpty) return null;
    final s = MigrationSession.startAsResponder(
      agentId: p.agentId,
      peerId: fromAgentId,
      oldPub: pub,
      nowMs: nowMs,
      ledger: _ledger,
    );
    _sessions[p.agentId] = s;
    return s;
  }

  /// 任一方主动中止。
  ///
  /// ★ 中止即**丢掉会话**（[forget]）：用户按了"取消"，那条会话就没有第二次了 ——
  /// 留着它只会让种子继续待在内存里（见文件头不变量 5）。
  Future<void> cancel(String agentId, {String reason = 'user_cancel'}) async {
    final s = _sessions[agentId];
    if (s == null) return;
    await send(s.peerId, s.cancelWire(reason: reason));
    s.abortLocal(reason);
    _notify(s);
    forget(agentId);
  }

  // ---------------- 内部 ----------------

  /// 把一步的出站真的送出去。返回 **true = 已送达（或这一步本来就没有出站）**。
  ///
  /// ★ 返回值不是"装饰"：`ack` 送不到 ⇒ 老机不会自锁 ⇒ 两台活体分叉的口子又开了，
  ///   调用方必须能知道这件事（见 `submitToHub` / `retryApply` 里的留痕）。
  Future<bool> _sendStep(MigrationSession s, MigrationStep step) async {
    final out = step.outbound;
    if (!step.ok || out == null) return true;
    final ok = await send(s.peerId, out);
    if (!ok) {
      // 送达失败要靠埋点留痕，否则"发出去没回音"与"压根没发出去"分不清。
      onEvent?.call('migration_dropped', {
        'reason': 'no_channel',
        'peer': s.peerId,
      });
    }
    return ok;
  }

  /// 装配一次恢复落盘（[submitToHub] 与 [retryApply] 共用**同一份**构造）。
  ///
  /// ⚠️ 抽出来的理由不是"少写几行"：落盘失败后重试时，参数必须与第一次**完全一致**
  ///   （尤其 `didAnchor`）—— 两处各写一份，迟早会出现"重试时用错锚"这种只有
  ///   在失败路径上才暴露的缺陷。
  RestorePlan _restorePlanFor(
    MigrationSession s,
    IdentityRotation rotation,
    List<int> seed,
  ) =>
      RestorePlan(
        agentId: s.agentId,
        oldPub: rotation.oldPub,
        // ⚠️ 这个 `oldDid` 只在"恢复码里的 old_pub 就是创世钥"时才等于身份锚；
        //    真正的锚以 Hub 回的 `did` 为准（`apply` 的 didAnchor 就是干这个的）。
        oldDid: 'did:wold:${rotation.oldPub}',
        newPub: rotation.newPub,
        newDid: rotation.newDid,
        rotation: rotation,
        newSeed: Uint8List.fromList(seed),
      );

  /// `ack` 的签名器 —— **新钥签**（见 `MigrationAck` 的"为什么必须签名"）。
  ///
  /// 优先用待装种子签：那一刻本机活跃身份还是旧的，只有种子能代表新钥。
  /// 种子的注入点只此一处，且**绝不落库、绝不进日志**。
  ///
  /// 走不到种子（= 本进程已消费过、这次是重复提交）时退回"用当前活跃钥签"：
  /// 此时活跃钥**应该**就是新钥；若不是，签名验不过 ⇒ 老机不自锁 ——
  /// 退化的方向恰好是安全的那一侧。
  Future<String> Function(List<int> message) _ackSigner(String agentId) {
    final seed = _pendingSeeds[agentId];
    if (seed != null) {
      return (message) => KeyBackup.signWithSeed(seed, message);
    }
    return (message) => AgentIdentity().signBase64(message);
  }

  /// 终态清理：**能清的立刻清**，只有"还欠一次落地"的失败态留着。
  ///
  /// · `done` —— 走完了，种子已经进了钥匙串，会话没有留着的理由；
  /// · `failed` 且**不可补救**（Hub 拒绝 / 对方取消 / 超时）—— 同样清掉：
  ///   用户要重来就是**新的一次会话**，留着旧对象只会让它继续握着种子；
  /// · `failed` 且 `fault == apply_failed` —— **留着，而且两侧都要留**：
  ///   新机要留着它才能 [retryApply]（"重新发起"会永久卡死，见那里的说明）；
  ///   老机要留着它才能收到新机补救后**补发的那条 `ok:true`** 并自锁
  ///   （会话层的 [MigrationSession] 为此专门开了这个阶段窗口）。
  ///   代价是内存里留着一个很小的对象，且这类终态不参与超时收割 ——
  ///   刻意如此：对"新机已改绑、本地没装"这种半成品，宁可占一点内存。
  void _settle(MigrationSession s) {
    if (s.phase == MigrationPhase.done) {
      forget(s.agentId);
      return;
    }
    if (s.phase == MigrationPhase.failed &&
        s.fault != MigrationSessionFault.applyFailed) {
      forget(s.agentId);
    }
  }

  void _notify(MigrationSession s, [MigrationStep? step]) {
    AppEvents.emit(MigrationStateChangedEvent(
      agentId: s.agentId,
      peerId: s.peerId,
      role: s.role.name,
      phase: s.phase.name,
      fault: s.fault ?? (step != null && !step.ok ? step.fault : null),
      compareCode: s.compareCodeDisplay,
    ));
  }

  Future<String> _myPubOrEmpty() async {
    try {
      return await AgentIdentity().publicKeyBase58();
    } catch (e) {
      AppLogger.w('migration.my_pub', e);
      return '';
    }
  }

  static List<int> _secureSeed() {
    final rnd = Random.secure();
    return List<int>.generate(32, (_) => rnd.nextInt(256));
  }
}
