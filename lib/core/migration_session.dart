/// 换机直迁的**会话层**：双角色状态机 + 报文编解码。
///
/// ---------------------------------------------------------------------------
/// 它和 `device_migration.dart` 的分工
/// ---------------------------------------------------------------------------
///   · `device_migration.dart` —— **票据**的格式与纯函数（要约长什么样、短码怎么算、
///     一次性 nonce 怎么记）。它是**离线可复算**的格式契约。
///   · 本文件 —— **两台设备之间一来一回的次序**：谁先开口、什么时候才允许签、
///     收到的东西和之前说好的**对不对得上**。
///
/// 前者回答"这东西长什么样"，后者回答"**现在能不能往前走**"。
///
/// ---------------------------------------------------------------------------
/// 七条硬约束（都落在本文件的 guard 里，不是注释里的愿望）
/// ---------------------------------------------------------------------------
/// 1. **本方永不持有对方的私钥**，也**永不自己签名** —— 签名由调用方注入
///    （[MigrationSession.signRotation] 收一个 `sign` 函数）。于是"新机拿到私钥"
///    这件事在类型上就不可能发生。
/// 2. ★★ **签之前必须有人按过确认键** —— 收到对端的 `confirm` 只让会话进入
///    `peerConfirmed`，**绝不自动签名**。这与 M6 互介存证的"绝不代客同意"同款：
///    机器可以替用户跑流程，但不可以替用户**交出身份**。
/// 3. ★★ **回签的 ROTATE 必须与本次会话的绑定逐字段对上**（[MigrationSessionFault.bindingMismatch]）：
///    `agent_id`、`old_pub`（= 要约里那把）、`new_pub`（= 本机那把）。
///    少检查 `new_pub` 就等于把"迁往哪把钥"的决定权交给了中间人 ——
///    这与 `device_migration.dart` 里补的那个短码洞是**同一个洞的两个面**。
/// 4. **落盘仍然后置**：会话只在 Hub 确认后进入 [MigrationPhase.done]，
///    在此之前新机不装种子（沿用 `identity_recovery.dart` 的 ③→④ 次序）。
/// 5. ★★ **`ack` 必须由新钥签名**（[MigrationAck]）：老机收到 `ok:true` 会**自锁**，
///    而自锁是"出去就回不来"的单向动作 —— 一条无凭据的 `{"ok":true}`
///    等于把"让老机废掉自己"变成了任何同空间设备都能按的按钮。
///    载荷里同时绑定 `agent_id / old_pub / new_pub / nonce / ok`，
///    于是"重放上一轮的 ack"与"把 ok:false 改成 ok:true"都过不了验签。
/// 6. ★ **会话有兜底窗口**（[MigrationSession.ttlMs]）：过期的会话不再受理任何报文、
///    也不允许签名。它挡的不是攻击者（攻击者要求的签名过不了 Hub 验签），
///    而是"用户走开了、会话还挂在那里握着种子"这种**没人看管的中间态**。
/// 7. ★★ **票据的过期窗口，两侧都要查**：票由**老机**铸（[onRequest]），新机在
///    [onOffer] 里验一次；老机在**签名之前**必须再验一次（[signRotation]）。
///    只在新机侧验 = 铸票后用户走开三分钟再按确认，老机会为一张**早已作废**的票
///    签名；而"会话没过期"完全不能代替它 —— 两件事、两个时钟起点。
///
/// 本文件**零平台依赖**（只用 `dart:convert` 与本地纯逻辑模块），
/// 因此 `dart run tool/verify_migration_session.dart` 可在独立 Dart VM 里跑完整条流程。
library;

import 'dart:convert';

import 'device_migration.dart';
import 'ed25519_sig.dart';
import 'identity_rotation.dart';

/// 报文的种类。**线格式的一部分** —— 用字符串常量而不是 enum（改不动已发出的报文）。
abstract final class MigrationWireKind {
  /// 新机 → 老机：我要接管这个身份，这是**我**的新公钥。
  static const String request = 'request';

  /// 老机 → 新机：这是我的要约（`FENMIG1` 票据）。
  static const String offer = 'offer';

  /// 新机 → 老机：两屏短码比对一致，**请签**。
  static const String confirm = 'confirm';

  /// 老机 → 新机：已签名的换钥声明。
  static const String rotate = 'rotate';

  /// 新机 → 老机：Hub 那边的结果（成功 / 失败原因码）。
  static const String ack = 'ack';

  /// 任一方 → 另一方：中止。
  static const String cancel = 'cancel';

  /// 全部合法种类（解析时按它 fail-closed）。
  static const Set<String> all = {
    request,
    offer,
    confirm,
    rotate,
    ack,
    cancel,
  };
}

/// 会话级失败码（**语言无关的稳定码**，UI 负责翻译）。
///
/// 与 [MigrationFault] 分工：那边是"票据**本身**坏在哪一段"，
/// 这边是"**次序与绑定**出了问题"（票据可能毫无毛病，但这张票不是给这次用的）。
abstract final class MigrationSessionFault {
  /// 报文不是迁移报文 / 结构不合法（会被原样退回聊天流水线）。
  static const String badWire = 'bad_wire';

  /// 报文不是当前对端发来的（或身份对不上）。
  static const String peerMismatch = 'peer_mismatch';

  /// 收到的报文与当前阶段不符（例如尚未出示要约就收到 ROTATE）。
  static const String wrongPhase = 'wrong_phase';

  /// 对端还没确认，本机就想签（⇒ **拒绝**，见文件头约束 2）。
  static const String notConfirmed = 'not_confirmed';

  /// 本机尚未签名，却要发 ROTATE。
  static const String notSigned = 'not_signed';

  /// ★★ 回签的声明与本次会话的绑定对不上（`agent_id` / `old_pub` / `new_pub` 任一不符）。
  static const String bindingMismatch = 'binding_mismatch';

  /// 声明的签名本地就没验过 —— 不必再送去 Hub 白跑一趟。
  static const String badSignature = 'bad_signature';

  /// 对端在中途取消。
  static const String cancelledByPeer = 'cancelled_by_peer';

  /// 本机尚未向对端发出 `request`。
  static const String notAsked = 'not_asked';

  /// ★ 会话放过了兜底窗口（[MigrationSession.ttlMs]）—— 已作废，不再受理任何报文。
  static const String sessionTimeout = 'session_timeout';

  /// ★★ Hub **已经改绑**，但本机**没能把新钥装好**。
  ///
  /// ⚠️ 它**不是**"什么都没发生"：Hub 上活跃钥已经是新钥、旧钥已作废。
  /// 所以这一条必须与"Hub 拒绝"区分开 —— 前者要**重试落地**，
  /// 后者只需重新发起。界面上把它显示成"完成"或"什么都没改动"都是错的。
  static const String applyFailed = 'apply_failed';
}

/// 会话处在哪一步。
///
/// 刻意做成**一条**枚举而不是每角色一套：两台设备看的是同一件事的两个视角，
/// 用一套阶段名能让"哪一步谁欠谁一个动作"在日志里一眼可读。
enum MigrationPhase {
  /// 尚未收到任何报文。
  idle,

  /// **新机**：已收到要约，等待人眼比对短码。
  offered,

  /// **老机**：票据已出示，等待对端确认。
  awaitingPeerConfirm,

  /// **老机**：对端已确认，**等待本机用户按确认键**（此处绝不自动往下走）。
  peerConfirmed,

  /// **老机**：已签出 ROTATE，等待对端回报 Hub 结果。
  signed,

  /// **新机**：已收到 ROTATE，等待提交 Hub 并落盘。
  awaitingHub,

  /// 走完了。
  done,

  /// 断了（[MigrationSession.fault] 说明原因）。
  failed,
}

/// 一方在本次会话里扮演的角色。
enum MigrationRole {
  /// **新机** —— 发起方，想要接管那个身份。
  initiator,

  /// **老机** —— 当前持有身份的一方。
  responder,
}

/// 解析后的一条迁移报文。
class MigrationPacket {
  final String kind;
  final String agentId;
  final Map<String, Object?> body;

  const MigrationPacket({
    required this.kind,
    required this.agentId,
    this.body = const {},
  });
}

/// 迁移报文的线格式：`{"dm_type":"mig","v":1,"kind":...,"agent_id":...,"body":{...}}`。
///
/// 与 `DelegationWire` / `IntroWire` 同款：**解析失败一律返回 null**
/// （调用方据此把消息交还聊天流水线，绝不"尽力解析"）。
class MigrationWire {
  static const String typeKey = 'dm_type';
  static const String typeValue = 'mig';
  static const String versionKey = 'v';
  static const int version = 1;
  static const String kindKey = 'kind';
  static const String agentKey = 'agent_id';
  static const String bodyKey = 'body';

  /// 报文上限 8 KB：要约与 ROTATE 都很小，超大的一律当垃圾丢掉。
  static const int maxChars = 8 * 1024;

  static String encode({
    required String kind,
    required String agentId,
    Map<String, Object?> body = const {},
  }) =>
      jsonEncode({
        typeKey: typeValue,
        versionKey: version,
        kindKey: kind,
        agentKey: agentId,
        bodyKey: body,
      });

  /// 解析一条报文；不是迁移报文（或结构不合法）返回 null。
  static MigrationPacket? tryParse(String text) {
    final t = text.trim();
    if (t.length > maxChars) return null;
    // 极廉价的前置筛：只有 JSON 对象才继续 jsonDecode（热点路径上的第一道闸）。
    if (!t.startsWith('{') || !t.endsWith('}')) return null;
    try {
      final m = jsonDecode(t);
      if (m is! Map) return null;
      if (m[typeKey] != typeValue) return null;
      if ((m[versionKey] as num?)?.toInt() != version) return null;
      final kind = m[kindKey];
      if (kind is! String || !MigrationWireKind.all.contains(kind)) return null;
      final agentId = m[agentKey];
      if (agentId is! String || agentId.isEmpty) return null;
      final rawBody = m[bodyKey];
      return MigrationPacket(
        kind: kind,
        agentId: agentId,
        body: rawBody is Map
            ? Map<String, Object?>.from(rawBody)
            : const {},
      );
    } catch (_) {
      return null;
    }
  }
}

/// 新机 → 老机的**最终回报**（`ack`）的签名载荷。
///
/// ---------------------------------------------------------------------------
/// 为什么 ack 必须签名（2026-09-30 补的洞）
/// ---------------------------------------------------------------------------
/// 老机收到 `ack(ok:true)` 会**自锁**（`migration_migrated_out_at`，此后不再把
/// 该身份当自己的用）。自锁是"出去就回不来"的单向动作，而原实现里这条 ack
/// 只是一句**没有任何凭据的 JSON**：同一空间里的任何设备发一条 `{"ok":true}`
/// 就能让老机把自己废掉，而新机那边**根本没办成** ——
/// 用户同时失去新旧两台机器，且**无从追责**（那条报文谁都能发）。
///
/// 所以 ack 由**新钥**（即将成为该身份的那把钥）签名。两个性质随之成立：
///   ① 只有真正拿到新种子的那一端才发得出合法 ack（服务端与中间人都做不到）；
///   ② 载荷绑定了 `agent_id / old_pub / new_pub / ticket_nonce`，于是
///      "把上一轮的 ack 拿到本轮来用"与"把 ok:false 改成 ok:true"都过不了验签 ——
///      后者尤其要紧：**伪造失败为成功 = 骗老机自锁**。
///
/// ⚠️ 本类**不含任何私钥材料**，只定义"签什么"。签名由调用方注入
/// （新机侧用 `KeyBackup.signWithSeed`，老机侧用 `Ed25519Sig.verify` 验）。
class MigrationAck {
  /// 被迁移的身份（防串到别的身份上）。
  final String agentId;

  /// 被退休的旧公钥（= 老机当前活跃钥）。
  final String oldPub;

  /// 接管的新公钥 —— **签名方就是它**。
  final String newPub;

  /// 本次会话那枚一次性 nonce（把 ack 钉在**这一轮**，而不是"任意一轮"）。
  final String ticketNonceB64;

  /// 结果。★ 它也进签名 —— 否则中间人能把"失败"翻成"成功"骗老机自锁。
  final bool ok;

  /// 成功时 Hub 回报的身份锚；失败时为空串。
  final String did;

  /// 失败码（[MigrationSessionFault] / [RotationFault] / Hub 的码）；成功时为空串。
  ///
  /// ★ 同样进签名：否则中间人可以把"为什么失败"改成另一个原因，
  /// 让用户去查一条根本不对的线索。
  final String fault;

  /// base64 签名，由 [newPub] 对应的私钥签出。未签时为空串。
  final String sig;

  const MigrationAck({
    required this.agentId,
    required this.oldPub,
    required this.newPub,
    required this.ticketNonceB64,
    required this.ok,
    this.did = '',
    this.fault = '',
    this.sig = '',
  });

  /// **确定性签名载荷**（JSON，键序固定）。
  ///
  /// ⚠️ `alg` 必须入载荷（挡"算法混淆"），`kind` 必须入载荷（挡
  /// "拿一份别的签名记录当作 ack 去验"）—— 与 `IdentityRotation.canonical()` 同款纪律。
  /// 与 `sig` **刻意不在载荷里**：签名不覆盖自己（Ed25519 是确定性的，
  /// 校验方拿"钥 + 消息"就能复算，多带一个 sig 只会制造第二个事实源）。
  String canonical() => jsonEncode({
        'alg': Ed25519Sig.alg,
        'kind': 'migration_ack',
        'agent_id': agentId,
        'old_pub': oldPub,
        'new_pub': newPub,
        'ticket_nonce': ticketNonceB64,
        'ok': ok,
        'did': did,
        'fault': fault,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  MigrationAck copyWith({String? sig}) => MigrationAck(
        agentId: agentId,
        oldPub: oldPub,
        newPub: newPub,
        ticketNonceB64: ticketNonceB64,
        ok: ok,
        did: did,
        fault: fault,
        sig: sig ?? this.sig,
      );

  /// 线格式的 `body`。**只带"结论 + 签名"** —— 绑定项由**收方自己**从会话里取，
  /// 不从报文里读：让收方照抄报文字段去做绑定核对，等于让攻击者自己填核对答案。
  Map<String, Object?> toMap() => {
        'ok': ok,
        'did': did,
        'fault': fault,
        'sig': sig,
      };

  /// 按**收方自己**的会话绑定拼出一份待验签的 ack。
  ///
  /// 返回 null = `body` 里连 `ok` 都没有（形态就不对）。
  static MigrationAck? fromBody(
    Map<String, Object?> body, {
    required String agentId,
    required String oldPub,
    required String newPub,
    required String ticketNonceB64,
  }) {
    final ok = body['ok'];
    if (ok is! bool) return null;
    return MigrationAck(
      agentId: agentId,
      oldPub: oldPub,
      newPub: newPub,
      ticketNonceB64: ticketNonceB64,
      ok: ok,
      did: (body['did'] ?? '').toString(),
      fault: (body['fault'] ?? '').toString(),
      sig: (body['sig'] ?? '').toString(),
    );
  }

  /// 签名是否有效（签名方 = [newPub]）。
  ///
  /// **任何异常都返回 false**（`Ed25519Sig.verify` 的 fail-closed 语义）：
  /// 坏 base58 / 坏 base64 / 长度不对 / 空签名 —— 一律"不算数"。
  Future<bool> sigValid() => Ed25519Sig.verify(
        message: canonicalBytes(),
        signatureB64: sig,
        publicKeyBase58: newPub,
      );

  @override
  String toString() => 'MigrationAck(ok=$ok${fault.isEmpty ? '' : ', fault=$fault'})';
}

/// 一次状态迁移的结果：**该不该继续**、**要不要回一句话**。
class MigrationStep {
  final bool ok;

  /// 失败原因码（[MigrationSessionFault] 或 [MigrationFault]）。
  final String? fault;

  /// 需要发给对端的报文（已编码）。`null` = 本步没有出站。
  final String? outbound;

  const MigrationStep({required this.ok, this.fault, this.outbound});

  static const MigrationStep pass = MigrationStep(ok: true);

  factory MigrationStep.failed(String fault) =>
      MigrationStep(ok: false, fault: fault);

  /// 成功的"要回一句话"。
  factory MigrationStep.reply(String wire) =>
      MigrationStep(ok: true, outbound: wire);

  @override
  String toString() => ok
      ? 'MigrationStep(ok${outbound == null ? '' : ', out=${outbound!.length}B'})'
      : 'MigrationStep($fault)';
}

/// 一次**换机直迁会话**（两台设备各持一个，方向相反）。
///
/// 调用方（`device_migration_service.dart`）负责三件事，本类一概不做：
///   · 把 [MigrationStep.outbound] 真的送出去；
///   · 在 `peerConfirmed` 之后**向用户要一个确认**；
///   · Hub 提交与落盘。
class MigrationSession {
  final MigrationRole role;

  /// 被迁移的那个身份（`AG-...`）。
  final String agentId;

  /// 对端的分身 ID（路由用）。
  final String peerId;

  /// **新机**将用来接管身份的那把新公钥（只有 [MigrationRole.initiator] 有值）。
  ///
  /// ⚠️ 这里**只有公钥**：对应的种子在服务层，会话层**从不需要**它
  /// （需要它的时刻，是 Hub 已经确认之后）。
  final String? newPub;

  /// **老机**当前活跃、将被退休的那把公钥（只有 [MigrationRole.responder] 有值）。
  final String? oldPub;

  /// 一次性 nonce 账。
  ///
  /// ⚠️ **不能只做成本会话私有的**：会话内的重放已经被阶段 guard 挡住了，
  /// 真正的重放场景是"用户重开一次迁移，攻击者把上一轮截到的要约塞进新会话"。
  /// 因此生产里由服务层**按身份持有一份**、跨会话复用（见 `device_migration_service.dart`）；
  /// 这里保留可注入，正是为了让那条性质**可被离线断言**，也便于测试隔离。
  final MigrationNonceLedger ledger;

  MigrationPhase phase = MigrationPhase.idle;
  String? fault;

  /// 新机是否已经开口要过票（`beginRequest` 只许成功一次）。
  ///
  /// 它挡住的是两件事：① 上层误把 `beginRequest` 放进 build 里重复调用；
  /// ② ★ **没人要过票却有人送票来**（抢先应答 / 主动投递）—— 见 [onOffer]。
  bool _asked = false;

  /// 收到的要约（**老机**是它自己铸的，**新机**是收到的）。
  MigrationTicket? ticket;

  /// 对端说它要用哪把新钥（**老机**在自己这边保存，签 ROTATE 时要核对）。
  String? peerNewPub;

  /// 已签出的换钥声明（两台设备各自在合适的时刻持有）。
  IdentityRotation? rotation;

  /// 已由服务层提交给 Hub 的结果（成功时的**身份锚**）。
  String? hubDid;

  /// 老机同一身份只能被迁出一次；迁完就锁，防止两台活体分叉。
  bool migratedOut = false;

  /// ★★ Hub **已改绑**、本机落盘却失败 —— 此后**只允许**"重试落地"，
  /// 不允许重新发起（重新发起会生成一把全新的钥，而 Hub 上的活跃钥已经是
  /// 上一次那把 ⇒ 新的 ROTATE 必被 `not_current_key` 拒 ⇒ 永久卡死）。
  bool applyPending = false;

  /// 会话创建时刻（毫秒）。
  ///
  /// ⚠️ **必需参数、由服务层给**：本文件刻意不读系统时钟（零平台依赖 + 可复算），
  /// 时间只有一个来源，测试才能把"过期"这件事真的钉住。
  final int startedAtMs;

  /// ★ 兜底窗口：**绝对**从会话创建算起的 5 分钟。
  ///
  /// 为什么是绝对值而不是"最后一次活动的滑动窗口"：滑动窗口可以被任何一条
  /// 报文续命（包括垃圾报文），于是"没人看管的会话握着种子"这件本要防的事
  /// 反而永远结束不了。绝对值把上界钉成 5 分钟，代价是"用户在确认框上犹豫超过
  /// 5 分钟要重来一次" —— 这个代价是**显式选定的**：恢复码路径永远可走，
  /// 而一个挂着种子的会话没有第二次机会的余地。
  ///
  /// 窗口里还要放下：60 秒票据有效期 → 两屏比对短码 → 老机用户按确认 →
  /// 押 ROTATE → 新机提交 Hub → 落盘。真人操作各步合计远低于 5 分钟。
  static const int ttlMs = 5 * 60 * 1000;

  MigrationSession._({
    required this.role,
    required this.agentId,
    required this.peerId,
    required this.startedAtMs,
    this.newPub,
    this.oldPub,
    MigrationNonceLedger? ledger,
  }) : ledger = ledger ?? MigrationNonceLedger();

  /// **新机**：开始一次接管。
  ///
  /// [newPub] 由服务层用**自己新生成的种子**推出（会话层不碰种子）。
  /// [ledger] 传生产里那份跨会话的账；不传则新建一份（测试/单次场景）。
  /// [nowMs] **必需**：会话兜底窗口（[ttlMs]）的起点，见 `startedAtMs` 的说明。
  static MigrationSession startAsInitiator({
    required String agentId,
    required String peerId,
    required String newPub,
    required int nowMs,
    MigrationNonceLedger? ledger,
  }) {
    return MigrationSession._(
      role: MigrationRole.initiator,
      agentId: agentId,
      peerId: peerId,
      startedAtMs: nowMs,
      newPub: newPub,
      ledger: ledger,
    );
  }

  /// **老机**：准备把身份交出去。
  ///
  /// [oldPub] 必须是**本机当前活跃公钥** —— 不是身份根钥：
  /// ROTATE 要求签名方是"记录在案的那把钥"，换过钥的身份，活跃钥已经变过。
  static MigrationSession startAsResponder({
    required String agentId,
    required String peerId,
    required String oldPub,
    required int nowMs,
    MigrationNonceLedger? ledger,
  }) {
    return MigrationSession._(
      role: MigrationRole.responder,
      agentId: agentId,
      peerId: peerId,
      startedAtMs: nowMs,
      oldPub: oldPub,
      ledger: ledger,
    );
  }

  bool get isInitiator => role == MigrationRole.initiator;

  /// 会话是否已到终点（[MigrationPhase.done] / [MigrationPhase.failed]）。
  bool get isTerminal =>
      phase == MigrationPhase.done || phase == MigrationPhase.failed;

  /// 本机是否还有"重试落地"的资格（= 新机、Hub 已改绑、但上次落盘失败）。
  bool get retryableApply =>
      isInitiator && applyPending && rotation != null;

  /// 会话已经活了多久（毫秒）。
  int ageMs(int nowMs) => nowMs - startedAtMs;

  /// ★ 兜底窗口：过期就把会话判死并返回稳定码；没到期返回 null。
  ///
  /// **幂等**：已到终点的会话不会再被改（`done` 不能被超时改写 ——
  /// "办成了但挂太久"不该被降级成失败）。
  ///
  /// 调用点有两处，缺一不可：
  ///   · [route] 入口 —— 挡住"过期的会话还被一条迟到报文推动"；
  ///   · 服务层的 `checkTimeouts()` —— 挡住"根本没有报文来，于是永远不会被判定"
  ///     （这正是兜底窗口要防的那一半）。
  String? expireIfStale(int nowMs) {
    if (isTerminal) return null;
    if (ageMs(nowMs) <= ttlMs) return null;
    fault = MigrationSessionFault.sessionTimeout;
    phase = MigrationPhase.failed;
    return fault;
  }

  /// 新机是否已经开口要过票（UI 用它决定"还能不能再点一次发起"）。
  bool get asked => _asked;

  /// 本机是否已经可以向 Hub 提交（= 新机已收到并**本地验过**的 ROTATE）。
  bool get readyToSubmitHub =>
      isInitiator && phase == MigrationPhase.awaitingHub && rotation != null;

  /// 本机是否**有资格**签名（= 老机、且对端已确认、且本机用户已拍板）。
  bool get canSign => role == MigrationRole.responder &&
      phase == MigrationPhase.peerConfirmed;

  /// 两屏要比对的短码（`XXX-XXX`）。两台设备各自算，**必须一模一样**。
  ///
  /// 未持有票据或对端新钥时返回 null（此时**没有可比的东西**，
  /// 而不是"比一个空串" —— 后者会让"忘了传参数"变成"比对通过"）。
  String? get compareCodeDisplay {
    final t = ticket;
    final peer = isInitiator ? newPub : peerNewPub;
    if (t == null || peer == null) return null;
    return t.compareCodeDisplayFor(peer);
  }

  // ==========================================================================
  // 新机侧
  // ==========================================================================

  /// 新机：把"我要接管、这是我的新公钥"发出去。
  MigrationStep beginRequest() {
    if (!isInitiator) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (phase != MigrationPhase.idle || _asked) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    _asked = true;
    return MigrationStep.reply(MigrationWire.encode(
      kind: MigrationWireKind.request,
      agentId: agentId,
      body: {'new_pub': newPub},
    ));
  }

  /// 新机：收到老机的要约。
  MigrationStep onOffer(MigrationPacket p, {required int nowMs}) {
    if (!isInitiator) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (p.kind != MigrationWireKind.offer) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    // ★ 没人开口要过票，却有人送票来 —— 这正是"抢先应答 / 主动投递"的形状。
    //   合法路径上老机只在收到 `request` 之后才铸票，所以这里可以严格到"没问过就拒"。
    if (!_asked) {
      return MigrationStep.failed(MigrationSessionFault.notAsked);
    }
    if (phase != MigrationPhase.idle) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    final wire = p.body['ticket'];
    if (wire is! String || wire.isEmpty) {
      return MigrationStep.failed(MigrationSessionFault.badWire);
    }
    final parsed = MigrationTicket.decode(wire);
    if (parsed is! MigrationTicket) {
      // 原样透出 `MigrationFault` 的码（bad_format / expired_ticket …）。
      return MigrationStep.failed(
          parsed is String ? parsed : MigrationSessionFault.badWire);
    }
    // 要约必须是**发给这个身份**的：否则"拿 B 的票去接管 A"会静默错配。
    if (parsed.agentId != agentId) {
      return MigrationStep.failed(MigrationSessionFault.peerMismatch);
    }
    final expFault = parsed.faultAt(nowMs);
    if (expFault != null) return MigrationStep.failed(expFault);
    // ★ 一次性：同一枚 nonce 用过就不再受理（重放要在这里被挡住，
    //   而不是等 Hub 那边的 `not_current_key` 兜底 —— 那是另一个洞的兜底）。
    if (!ledger.register(parsed.id, nowMs)) {
      return MigrationStep.failed(MigrationFault.replayedTicket);
    }
    ticket = parsed;
    phase = MigrationPhase.offered;
    return MigrationStep.pass;
  }

  /// 新机：两屏短码比对一致后，向老机确认"请签"。
  MigrationStep confirm() {
    if (!isInitiator || phase != MigrationPhase.offered) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    return MigrationStep.reply(MigrationWire.encode(
      kind: MigrationWireKind.confirm,
      agentId: agentId,
    ));
  }

  /// 新机：收到老机签出的 ROTATE —— **本机先自己验一遍绑定与签名**，再送 Hub。
  Future<MigrationStep> onRotate(MigrationPacket p) async {
    if (!isInitiator) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (p.kind != MigrationWireKind.rotate) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (phase != MigrationPhase.offered) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    final raw = p.body['rotation'];
    if (raw is! Map) return MigrationStep.failed(MigrationSessionFault.badWire);
    final signed = IdentityRotation.fromMap(Map<String, dynamic>.from(raw));
    final t = ticket;
    if (t == null) return MigrationStep.failed(MigrationSessionFault.wrongPhase);

    // ★★ 绑定核对：三者缺一不可。
    //   · agent_id —— 换的是不是这个身份；
    //   · old_pub  —— 退休的是不是要约里那把（= 老机真正持有的）；
    //   · new_pub  —— 接管的**是不是本机这把**（漏了这条，中间人就能把身份迁走）。
    if (signed.agentId != agentId ||
        signed.oldPub != t.oldPub ||
        signed.newPub != newPub) {
      return MigrationStep.failed(MigrationSessionFault.bindingMismatch);
    }
    if (signed.sig.isEmpty || !await signed.sigValid()) {
      return MigrationStep.failed(MigrationSessionFault.badSignature);
    }
    rotation = signed;
    phase = MigrationPhase.awaitingHub;
    return MigrationStep.pass;
  }

  /// 新机：把 Hub 的结果回报给老机（老机据此决定"我该不该自锁"）。
  ///
  /// ★★ 两条约束都在这里落地：
  ///   ① **签名方是新钥**（[MigrationAck]）；签不出来就**不发 ack** ——
  ///      老机因此不会自锁，而"两边都还能用"正是失败时该掉向的那一边。
  ///   ② **调用方必须已经落盘成功**才允许传 `ok: true`。这一条由服务层的
  ///      次序保证（`submitToHub`：先 `apply` 再回报）；本层负责"说了就必须是真话"：
  ///      一旦 `ok:false` 且 `faultCode == applyFailed`，会话进入 [applyPending]，
  ///      此后**只**接受 [ackAfterApplyRetry] 的补救，不再接受重新发起。
  ///
  /// 返回的 `outbound` 才是那条要发出去的 ack；`step.ok == false` 时**必须**
  /// 当作"没有通知过老机"处理（服务层据此不去清种子）。
  Future<MigrationStep> hubResult({
    required bool ok,
    String? faultCode,
    String? did,
    required Future<String> Function(List<int> message) sign,
  }) async {
    if (!isInitiator || phase != MigrationPhase.awaitingHub) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    final step =
        await _emitAck(ok: ok, faultCode: faultCode, did: did, sign: sign);
    if (!step.ok) return step; // 不推进、不回报（失败的默认方向 = 两边都还能用）
    if (ok) {
      hubDid = did;
      phase = MigrationPhase.done;
    } else {
      fault = faultCode ?? MigrationSessionFault.badWire;
      phase = MigrationPhase.failed;
      // ★ Hub 改绑成功、只是本机没装上 ⇒ 记住"还欠一次落地"（见 applyPending）。
      if (faultCode == MigrationSessionFault.applyFailed) applyPending = true;
    }
    return step;
  }

  /// 新机：**落盘重试成功之后**补发一条 `ok:true` 的签名 ack。
  ///
  /// ★ 它**刻意**允许从 `failed` 回到 `done` —— 那个 `failed` 不是"流程结束"，
  /// 而是"还差本机这一步"（[MigrationSessionFault.applyFailed]）。
  /// 若不给这条路，用户只剩"重新发起"，而重新发起会生成一把**全新的钥**，
  /// 与 Hub 上已经改绑的那把对不上 ⇒ 必被 `not_current_key` 拒 ⇒ **永久卡死**。
  Future<MigrationStep> ackAfterApplyRetry({
    String? did,
    required Future<String> Function(List<int> message) sign,
  }) async {
    if (!retryableApply) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    final step = await _emitAck(ok: true, did: did ?? hubDid, sign: sign);
    if (!step.ok) return step;
    hubDid = did ?? hubDid;
    applyPending = false;
    fault = null;
    phase = MigrationPhase.done;
    return step;
  }

  /// 构造并**本地自验**一条签名 ack（[hubResult] 与 [ackAfterApplyRetry] 共用）。
  ///
  /// ⚠️ 绑定项全部取自**本会话**（`rotation` 与 `ticket`），不从任何报文里读 ——
  /// 否则"绑定了哪次会话"就成了攻击者自己填的答案。
  ///
  /// 本地自验不是多此一举：签名器由调用方注入，"注入了一个签不出东西的签名器"
  /// 必须在这里被挡住，而不是让老机收到一条验不过的 ack 后干等到超时。
  Future<MigrationStep> _emitAck({
    required bool ok,
    String? faultCode,
    String? did,
    required Future<String> Function(List<int> message) sign,
  }) async {
    final r = rotation;
    final t = ticket;
    if (!isInitiator || r == null || t == null) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    final unsigned = MigrationAck(
      agentId: agentId,
      oldPub: r.oldPub,
      newPub: r.newPub,
      ticketNonceB64: t.nonceB64,
      ok: ok,
      did: ok ? (did ?? '') : '',
      fault: ok ? '' : (faultCode ?? MigrationSessionFault.badWire),
    );
    final sig = await sign(unsigned.canonicalBytes());
    if (sig.isEmpty) {
      return MigrationStep.failed(MigrationSessionFault.notSigned);
    }
    final ack = unsigned.copyWith(sig: sig);
    if (!await ack.sigValid()) {
      return MigrationStep.failed(MigrationSessionFault.badSignature);
    }
    return MigrationStep.reply(MigrationWire.encode(
      kind: MigrationWireKind.ack,
      agentId: agentId,
      body: ack.toMap(),
    ));
  }

  // ==========================================================================
  // 老机侧
  // ==========================================================================

  /// 老机：收到新机的接管请求 → **铸一张票据**回过去。
  ///
  /// [nowMs] 与 [endpoint] 由服务层给（时钟与地址都是"设备"的事，不是协议的事）。
  MigrationStep onRequest(
    MigrationPacket p, {
    required int nowMs,
    String endpoint = '',
  }) {
    if (isInitiator) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (p.kind != MigrationWireKind.request) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (phase != MigrationPhase.idle) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    final their = p.body['new_pub'];
    if (their is! String || !Ed25519Sig.isPubkey(their)) {
      return MigrationStep.failed(MigrationSessionFault.badWire);
    }
    final mine = oldPub;
    if (mine == null) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    // 对端"用我自己来接管我自己"没有任何意义，且会撞上 Hub 的 `noop_rotation`。
    if (their == mine) {
      return MigrationStep.failed(MigrationSessionFault.bindingMismatch);
    }
    peerNewPub = their;
    ticket = MigrationTicket.mint(
      agentId: agentId,
      oldPub: mine,
      nowMs: nowMs,
      endpoint: endpoint,
    );
    phase = MigrationPhase.awaitingPeerConfirm;
    return MigrationStep.reply(MigrationWire.encode(
      kind: MigrationWireKind.offer,
      agentId: agentId,
      body: {'ticket': ticket!.encode()},
    ));
  }

  /// 老机：收到对端的确认 —— 只把状态推进到"**待本机用户拍板**"，**绝不自动签**。
  ///
  /// 这条 guard 就是文件头约束 2 的落点。收到网络上的一句话不等于用户的同意。
  MigrationStep onConfirm(MigrationPacket p) {
    if (isInitiator) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (p.kind != MigrationWireKind.confirm) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (phase != MigrationPhase.awaitingPeerConfirm) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    phase = MigrationPhase.peerConfirmed;
    return MigrationStep.pass;
  }

  /// 老机：**用户按了确认键**之后，用注入的签名器签出 ROTATE。
  ///
  /// ⚠️ 签名器由调用方给（本类**不持有私钥**）。这一层不变量保证了
  /// "新机永远拿不到私钥"在类型上成立，而不是靠自觉。
  Future<MigrationStep> signRotation({
    required Future<String> Function(List<int> message) sign,
    required int nowMs,
  }) async {
    if (role != MigrationRole.responder) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    // ★ 过期会话**不许签**（[ttlMs]）：票据早已作废，签出去只会让新机白等一场；
    //   更要紧的是"用户走开了、会话却还握着一把能签的活跃钥"这种中间态，
    //   必须有一条**不依赖对端配合**的路自己结束。
    final stale = expireIfStale(nowMs);
    if (stale != null) return MigrationStep.failed(stale);
    if (phase != MigrationPhase.peerConfirmed) {
      // 已经判死过的会话（超时 / 对端取消 / 上一次签名失败）——
      // 报**它自己那个原因**，而不是一句含糊的 `not_confirmed`：
      // 否则"为什么签不了"这个最重要的信息在第二次查询时就被吞掉了。
      return MigrationStep.failed(
          isTerminal && fault != null ? fault! : MigrationSessionFault.notConfirmed);
    }
    final mine = oldPub;
    final their = peerNewPub;
    if (mine == null || their == null) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    // ★★ 票据自身的过期窗口**必须在这里再查一次**（外部审计 P2⑥）。
    //   票是老机**自己铸的**（见 [onRequest] 的 `MigrationTicket.mint`），
    //   而此前只有**新机**在 [onOffer] 里验过它的 60 秒窗口 ——
    //   于是"铸票之后用户走开了三分钟，回来才按交出身份"这条路上，老机会为一张
    //   **早已作废**的票签名。此时唯一还拦着的只剩 5 分钟的**会话**兜底窗口，
    //   而那是另一件事（它管的是"这次会话还活着吗"，不是"这张票还有效吗"）。
    //   判据一句话：**签之前，票必须还没过期。**
    //   这一步不依赖对端配合，也不依赖用户及时回来。
    final t = ticket;
    if (t != null) {
      final expFault = t.faultAt(nowMs);
      if (expFault != null) {
        abortLocal(expFault);
        return MigrationStep.failed(expFault);
      }
    }
    final unsigned = IdentityRotation(
      agentId: agentId,
      oldPub: mine,
      newPub: their,
      rotatedAtMs: nowMs,
    );
    final sig = await sign(unsigned.canonicalBytes());
    if (sig.isEmpty) {
      return MigrationStep.failed(MigrationSessionFault.notSigned);
    }
    final signed = unsigned.copyWith(sig: sig);
    // 自己先验一遍：签不出来的东西送出去只会让对端白等一场。
    if (!await signed.sigValid()) {
      return MigrationStep.failed(MigrationSessionFault.badSignature);
    }
    rotation = signed;
    phase = MigrationPhase.signed;
    return MigrationStep.reply(MigrationWire.encode(
      kind: MigrationWireKind.rotate,
      agentId: agentId,
      body: {'rotation': signed.toMap()},
    ));
  }

  /// 老机：收到对端回报的 Hub 结果。**成功且验签通过**才自锁。
  ///
  /// ★★ 验签在这里，而且**失败方向是"什么都不做"**（2026-09-30 补）：
  ///   · 签名必须由 [MigrationAck] 里绑定的**那把新钥**签（`peerNewPub`）；
  ///   · 载荷必须覆盖本会话的 `agent_id / old_pub / new_pub / ticket nonce / ok`。
  ///
  /// 验不过一律 [MigrationSessionFault.badSignature] 并且**不推进状态** ——
  /// 会话留在 `signed`，一条**合法**的 ack 之后还能把流程走完。
  /// （不把状态打成 `failed`：收到一条垃圾报文就毁掉整个会话，等于给攻击者
  /// 一个"随手打乱用户迁移"的按钮。）
  ///
  /// ⚠️ 绑定项取自**本会话**，不从报文的 `body` 里读：`body` 里只有
  /// `ok / did / fault / sig`，见 [MigrationAck.toMap]。
  Future<MigrationStep> onAck(MigrationPacket p) async {
    if (role != MigrationRole.responder) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (p.kind != MigrationWireKind.ack) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    if (phase != MigrationPhase.signed &&
        // ★★ 还留着一个窗口：上一轮报的是 `apply_failed`。
        //    那不是"流程结束"，而是"新机还欠一次落地"—— 老机必须能收到
        //    新机补救之后补发的那条 `ok:true` 并自锁；否则新机落地成功了，
        //    老机却永远停留在"还能用"的状态 ⇒ 正是要防的两台活体分叉。
        !(phase == MigrationPhase.failed &&
            fault == MigrationSessionFault.applyFailed)) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    final mine = oldPub;
    final their = peerNewPub;
    final t = ticket;
    if (mine == null || their == null || t == null) {
      return MigrationStep.failed(MigrationSessionFault.wrongPhase);
    }
    final ack = MigrationAck.fromBody(
      p.body,
      agentId: agentId,
      oldPub: mine,
      newPub: their,
      ticketNonceB64: t.nonceB64,
    );
    if (ack == null || ack.sig.isEmpty || !await ack.sigValid()) {
      // ★ 到这里的是"有人想让我自锁"或"对端实现坏了"，两种都不该按成功处理。
      return MigrationStep.failed(MigrationSessionFault.badSignature);
    }
    if (ack.ok) {
      migratedOut = true;
      if (ack.did.isNotEmpty) hubDid = ack.did;
      phase = MigrationPhase.done;
      return MigrationStep.pass;
    }
    fault = ack.fault.isEmpty ? 'hub_rejected' : ack.fault;
    phase = MigrationPhase.failed;
    return MigrationStep.pass;
  }

  // ==========================================================================
  // 两方共用
  // ==========================================================================

  /// 收一条报文并推进状态机。**这是唯一的入口** —— 调用方不必知道阶段细节。
  ///
  /// ⚠️ 前置判断（"这到底是不是迁移报文"）由调用方用 [MigrationWire.tryParse] 做：
  /// 解析不出来就说明对端根本没在迁移，报文该**原样交还**聊天流水线。
  /// 到了这里就只有一个问题："**它能不能推动这次会话**"。
  Future<MigrationStep> route(MigrationPacket p, {required int nowMs}) async {
    // 路由校验：报文里写的身份必须就是本次会话谈的那个身份。
    // 不通过 = "这不是给本会话的迁移报文"，交还聊天流水线（而不是判它坏）。
    if (p.agentId != agentId) {
      return MigrationStep.failed(MigrationSessionFault.peerMismatch);
    }
    // ★ 兜底窗口（[ttlMs]）：过期的会话**不再受理任何报文**，也不再有任何出站。
    //   放在最前面：一条迟到 10 分钟的 ROTATE 不该还能把流程推下去。
    final stale = expireIfStale(nowMs);
    if (stale != null) return MigrationStep.failed(stale);
    switch (p.kind) {
      case MigrationWireKind.request:
        return onRequest(p, nowMs: nowMs);
      case MigrationWireKind.offer:
        return onOffer(p, nowMs: nowMs);
      case MigrationWireKind.confirm:
        return onConfirm(p);
      case MigrationWireKind.rotate:
        return onRotate(p);
      case MigrationWireKind.ack:
        return onAck(p);
      case MigrationWireKind.cancel:
        fault = MigrationSessionFault.cancelledByPeer;
        phase = MigrationPhase.failed;
        return MigrationStep.pass;
      default:
        return MigrationStep.failed(MigrationSessionFault.badWire);
    }
  }

  /// 编一条"我不干了"发出去。
  String cancelWire({String reason = ''}) => MigrationWire.encode(
        kind: MigrationWireKind.cancel,
        agentId: agentId,
        body: reason.isEmpty ? const {} : {'reason': reason},
      );

  /// 本机主动中止（对端未必收得到，所以本地状态也要落地）。
  void abortLocal(String reason) {
    if (phase == MigrationPhase.done) return;
    fault = reason;
    phase = MigrationPhase.failed;
  }

  @override
  String toString() =>
      'MigrationSession(${role.name}, $agentId, peer=$peerId, ${phase.name}'
      '${fault == null ? '' : ', fault=$fault'})';
}
