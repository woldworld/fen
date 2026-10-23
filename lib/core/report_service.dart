/// 举报工单核心层（客户端举报入口 + 服务端工单接口的**镜像**）。
///
/// ---------------------------------------------------------------------------
/// 定位：这是 npm 包 `@woldworld/protocol` 的 `report` 模块的 Dart 镜像。
/// ---------------------------------------------------------------------------
/// 状态机、事由白名单、签名载荷、转移判定、审计记录形状 —— 全部**只有一份**
/// （在 `packages/protocol/src/report.js`），本文件是它的 Dart 实现。
/// 跨语言逐字节一致性由 `tool/verify_report_hub.js` 钉住：
/// **Dart 签的工单，Node 必须验得过**（反之亦然）。
///
/// 为什么必须单源：这些不是"内部实现细节"，而是**对外承诺的语义** ——
/// 工单编号怎么算、什么叫"不予处置"、申诉凭什么只能一轮、谁能看见什么。
/// 两端各写一份必然漂移，漂移的形态是"客户端说只能申诉一次、服务端让申诉两次"。
///
/// ---------------------------------------------------------------------------
/// 四条硬规矩（草案 §3，硬编码在判定里，不是写在注释里）
/// ---------------------------------------------------------------------------
/// 1. **每个状态变化都必须写审计日志** —— 状态机只管"能不能变"，
///    "变了必须留痕"由调用方在同一次落库里写审计记录，
///    而 [ReportAuditRecord.from] 给出**唯一的记录形状**（两端同构）。
/// 2. **`rejected`（不予处置）必须带理由** —— 空理由的拒绝等于没有流程。
/// 3. **被举报人永远看不到举报人身份** —— 见 [ReportPublicView]：
///    它**在结构上**就不含举报人身份与举报内容，只有"有一张针对你的工单被处置了"。
/// 4. **申诉只允许一轮** —— `appealCount` 闸在转移判定里。
///
/// ---------------------------------------------------------------------------
/// 诚实边界（必读）
/// ---------------------------------------------------------------------------
/// 本模块只实现**工单机制**：提交 → 分诊 → 处理 → 处置/驳回 → 申诉 → 终局。
/// 它**不**实现"处置"本身（警告/限制/下架/封禁的执行），那是 Hub 侧的运营动作；
/// 本模块只保证**工单状态的流转是确定的、可复算的、每一步都留痕的**。
///
/// 本文件**零平台依赖**（不 import flutter / sqflite / shared_preferences），
/// 因此 `dart run tool/verify_report_service.dart` 可离线复算全部判定。
library;

import 'dart:convert';

// 验签**不自己实现**：与 M6 背书 / M9 技能 / M10 房间角色共用 `Ed25519Sig`
// 同一份实现。四处各写一份必然漂移，而漂移的形态是"这边拒的假签名那边却收了"。
import 'ed25519_sig.dart' show Ed25519Sig;

/// 举报事由白名单（**封闭集合**）。
///
/// ⚠️ 不在表内的事由一律**拒绝受理**，不是"降级为其他"：
/// 白名单是防止"自由文本事由"变成无法归类的投诉池 —— 一旦允许自由文本，
/// 运营侧就再也说不出"本周受理的骚扰类举报有 37 起"这种可核对的话。
enum ReportReason {
  /// 垃圾广告 / 批量骚扰。
  spam('spam'),

  /// 骚扰、辱骂、威胁。
  harassment('harassment'),

  /// 违法违规内容。
  illegalContent('illegal_content'),

  /// 虚假身份 / 冒充他人。
  fakeIdentity('fake_identity'),

  /// 其他（必须在 [ReportTicket.detail] 里说明）。
  other('other');

  /// **wire 值**（落库 / 签名载荷 / 传输三者共用这一个）。
  ///
  /// ⚠️ 必须与 `packages/protocol/src/report.js` 的 `REASONS` **逐字相同**。
  ///   曾经这里直接返回 Dart 枚举名（`illegalContent`），而协议包写的是
  ///   `illegal_content` ⇒ 客户端提交这一类事由时，服务端 `REASONS.includes()`
  ///   判否、**整类举报被 400 拒收**（5 个事由死了 2 个），而且**不报错**
  ///   —— 用户只会看到"提交失败"，根本不知道是自己选的事由被拒。
  ///   ⇒ 枚举名是** Dart 内部标识**，wire 值必须**显式**写出来。
  final String id;

  const ReportReason(this.id);

  /// 解析 wire 值；未知 / null → [other]（fail-safe，绝不抛异常）。
  static ReportReason fromId(String? id) {
    for (final r in ReportReason.values) {
      if (r.id == id) return r;
    }
    return ReportReason.other;
  }
}

/// 工单状态机（8 态）。
enum ReportStatus {
  /// 已收到，未分诊。
  open('open'),

  /// 已定性（是否属本流程管辖）。
  triaged('triaged'),

  /// 处理中。
  inReview('in_review'),

  /// 已处置。
  actioned('actioned'),

  /// 不予处置（**必须带理由**）。
  rejected('rejected'),

  /// 已申诉（只允许一轮）。
  appealed('appealed'),

  /// 终局。
  closed('closed'),

  /// 举报人自己撤回。
  withdrawn('withdrawn');

  /// **wire 值**（落库 / 传输 / 界面展示三者共用这一个）。
  ///
  /// ⚠️ 必须与 `packages/protocol/src/report.js` 的 `STATES` **逐字相同**
  ///   （`in_review` 而非 Dart 枚举名 `inReview`）。曾写成 `name` 时，
  ///   服务端返回的 `in_review` 在 Dart 侧解析不到、**回落成 `open`** ——
  ///   界面于是把"核查中"显示成"已受理"，是**假信息**，比不显示更糟。
  final String id;

  const ReportStatus(this.id);

  /// 解析 wire 值；未知 / null → [open]（fail-safe，绝不抛异常）。
  static ReportStatus fromId(String? id) {
    for (final s in ReportStatus.values) {
      if (s.id == id) return s;
    }
    return ReportStatus.open;
  }

  /// 是否已到终局（终局之后没有任何出边）。
  bool get isTerminal => this == ReportStatus.closed || this == ReportStatus.withdrawn;
}

/// 转移的发起方角色。谁能发起哪条边，是硬闸的一部分。
enum ReportActor {
  /// 举报人。
  reporter,

  /// 被举报人（仅在已处置时可申诉）。
  target,

  /// 运营（推进状态机）。
  admin;

  String get id => name;
}

/// 事由附注长度上限（自由文本，越短越好 —— 这不是投诉信）。
const int kReportMaxDetailChars = 280;

/// 工单编号格式：`RPT-` + 12 位大写十六进制。
///
/// ⚠️ 由**客户端生成**：这样"提交"可以离线进行、可以重试而不会产生两张工单
/// （同一张工单的编号即幂等键），且工单从诞生起就带着可核对的编号。
final RegExp kReportTicketIdRe = RegExp(r'^RPT-[0-9A-F]{12}$');

/// 被举报内容哈希：只存哈希，**不存原文**（数据最小化的硬形态）。
final RegExp kReportContentHashRe = RegExp(r'^[0-9a-f]{64}$');

/// 校验结果码。与 `@woldworld/protocol` 的 `report.verify` **逐一对应** ——
/// 两端对同一份工单必须给同一个码，否则"谁说了算"就没了。
abstract final class ReportVerifyCode {
  static const String ok = 'ok';
  static const String missingFields = 'missing_fields';
  static const String badTicketId = 'bad_ticket_id';
  static const String badPubkey = 'bad_pubkey';
  static const String badReason = 'bad_reason';
  static const String badContentHash = 'bad_content_hash';
  static const String detailTooLong = 'detail_too_long';
  static const String badWindow = 'bad_window';
  static const String badSignature = 'bad_signature';
}

/// 转移判定的结果码。与 `report.transitionDecision` **逐一对应**。
abstract final class ReportTransitionCode {
  static const String accepted = 'accepted';
  static const String badState = 'bad_state';
  static const String badTransition = 'bad_transition';

  /// ★ 硬规矩 2：`rejected` 必须带理由。
  static const String reasonRequired = 'reason_required';

  /// ★ 硬规矩 4：申诉只允许一轮。
  static const String appealExhausted = 'appeal_exhausted';

  /// 发起方不对（谁有权走这条边）。
  static const String wrongActor = 'wrong_actor';
}

/// 校验结果。
class ReportVerifyResult {
  final bool ok;
  final String code; // ReportVerifyCode.*

  const ReportVerifyResult({required this.ok, required this.code});
}

/// 转移判定结果。
class ReportTransitionResult {
  final bool accept;
  final String code; // ReportTransitionCode.*

  const ReportTransitionResult({required this.accept, required this.code});
}

/// 一条状态变化留下的审计记录（硬规矩 1）。
///
/// 形状只有这一处定义 —— 服务端与客户端各写一份，迟早出现
/// "服务端记了 from/to，客户端记了 from/to/note"这种对不上的账。
class ReportAuditRecord {
  final String ticketId;
  final String from;
  final String to;
  final int atMs;
  final String actor;
  final String reason;

  const ReportAuditRecord({
    required this.ticketId,
    required this.from,
    required this.to,
    required this.atMs,
    required this.actor,
    required this.reason,
  });

  /// 与 `report.auditRecord` 同序同形（跨语言由 Node 侧校验脚本钉住）。
  Map<String, Object?> toMap() => {
        'ticket_id': ticketId,
        'from': from,
        'to': to,
        'at': atMs,
        'actor': actor,
        'reason': reason,
      };

  static ReportAuditRecord fromMap(Map<String, dynamic> m) => ReportAuditRecord(
        ticketId: (m['ticket_id'] as String?) ?? '',
        from: (m['from'] as String?) ?? '',
        to: (m['to'] as String?) ?? '',
        atMs: (m['at'] as num?)?.toInt() ?? 0,
        actor: (m['actor'] as String?) ?? '',
        reason: (m['reason'] as String?) ?? '',
      );
}

/// 一张举报工单。
///
/// ⚠️ **绝不存被举报内容的原文** —— 只存 [contentHash]（哈希）与举报人自己写的
/// 短附注 [detail]（限长 280）。这既是数据最小化，也是隐私政策的兑现。
class ReportTicket {
  /// 工单编号（`RPT-` + 12 位大写十六进制；客户端生成，兼作幂等键）。
  final String ticketId;

  /// 举报人公钥（base58）。**签名凭据的主体**。
  final String reporterPub;

  /// 被举报人 agent id。
  final String targetId;

  /// 举报事由（白名单内）。
  final ReportReason reason;

  /// 被举报内容的 SHA-256 十六进制（**不存原文**）。
  final String contentHash;

  /// 举报人自写的附注（限长 280）。
  final String detail;

  /// 提交时刻（毫秒）。
  final int createdAtMs;

  /// 当前状态（落库后才有；签名载荷里没有它）。
  final ReportStatus status;

  /// 状态说明（如"不予处置的理由"）。落库字段，**不在签名载荷里**。
  final String statusNote;

  /// 处置动作（如"限制功能"）。落库字段，**不在签名载荷里**。
  final String action;

  /// 已用申诉次数（0 或 1；进 `appealed` 时 +1）。
  final int appealCount;

  /// 最后更新时刻。
  final int updatedAtMs;

  /// 举报人签名（base64）。空串 = 未签名。
  final String sig;

  const ReportTicket({
    required this.ticketId,
    required this.reporterPub,
    required this.targetId,
    required this.reason,
    required this.contentHash,
    required this.detail,
    required this.createdAtMs,
    this.status = ReportStatus.open,
    this.statusNote = '',
    this.action = '',
    this.appealCount = 0,
    this.updatedAtMs = 0,
    this.sig = '',
  });

  /// 幂等键：**一张工单一个键**。
  ///
  /// 与 `report.keyOf` 逐字符同构（跨语言由 Node 侧校验脚本钉住）。
  String get idempotencyKey => ReportAuthority.keyOf(ticketId);

  /// 签名载荷 —— 与 `packages/protocol/src/report.js` 的 `canonical()` **同序同形**。
  ///
  /// ⚠️ 键序 = 插入序（Dart `jsonEncode` 与 JS `JSON.stringify` 都不排序）。
  /// 改动这里的顺序 = 让历史签名与对端全部失效，**禁止重排**。
  ///
  /// ★ 刻意**不含**状态 / 状态说明 / 处置动作 / 申诉次数 ——
  ///   那些是**运营侧**写的字段，不该由举报人的签名担保；
  ///   担保了反而会让"状态变了但签名没变"变成"签名失效"。
  String canonical() => jsonEncode({
        'alg': Ed25519Sig.alg,
        'kind': 'report',
        'ticket_id': ticketId,
        'reporter_pub': reporterPub,
        'target_id': targetId,
        'reason': reason.id,
        'content_hash': contentHash,
        'detail': detail,
        'created_at': createdAtMs,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  ReportTicket copyWith({
    ReportStatus? status,
    String? statusNote,
    String? action,
    int? appealCount,
    int? updatedAtMs,
    String? sig,
  }) =>
      ReportTicket(
        ticketId: ticketId,
        reporterPub: reporterPub,
        targetId: targetId,
        reason: reason,
        contentHash: contentHash,
        detail: detail,
        createdAtMs: createdAtMs,
        status: status ?? this.status,
        statusNote: statusNote ?? this.statusNote,
        action: action ?? this.action,
        appealCount: appealCount ?? this.appealCount,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        sig: sig ?? this.sig,
      );

  Map<String, Object?> toMap() => {
        'ticket_id': ticketId,
        'reporter_pub': reporterPub,
        'target_id': targetId,
        'reason': reason.id,
        'content_hash': contentHash,
        'detail': detail,
        'created_at': createdAtMs,
        'status': status.id,
        'status_note': statusNote,
        'action': action,
        'appeal_count': appealCount,
        'updated_at': updatedAtMs,
        'sig': sig,
      };

  static ReportTicket fromMap(Map<String, dynamic> m) => ReportTicket(
        ticketId: (m['ticket_id'] as String?) ?? '',
        reporterPub: (m['reporter_pub'] as String?) ?? '',
        targetId: (m['target_id'] as String?) ?? '',
        reason: ReportReason.fromId(m['reason'] as String?),
        contentHash: (m['content_hash'] as String?) ?? '',
        detail: (m['detail'] as String?) ?? '',
        createdAtMs: (m['at_ms'] ?? m['created_at'] as num?)?.toInt() ?? 0,
        status: ReportStatus.fromId(m['status'] as String?),
        statusNote: (m['status_note'] as String?) ?? '',
        action: (m['action'] as String?) ?? '',
        appealCount: (m['appeal_count'] as num?)?.toInt() ?? 0,
        updatedAtMs: (m['updated_at'] as num?)?.toInt() ?? 0,
        sig: (m['sig'] as String?) ?? '',
      );

  /// 举报人视角：本人提交的工单，**可以看到自己写的原因与附注**。
  Map<String, Object?> toReporterView() => {
        'ticket_id': ticketId,
        'target_id': targetId,
        'reason': reason.id,
        'content_hash': contentHash,
        'detail': detail,
        'status': status.id,
        'status_note': statusNote,
        'appeal_count': appealCount,
        'created_at': createdAtMs,
        'updated_at': updatedAtMs,
      };
}

/// 被举报人视角（硬规矩 3）。
///
/// ★ 这里**只列字段**，不列"要排除什么" —— 排除法是写错了就会漏的写法。
///   本类**根本不存在** reporterPub / detail / contentHash 这类可回指举报人
///   身份或举报内容的字段，所以"漏返回"在结构上不可能发生。
///
///   被举报人需要知道的只有：有一张针对我的工单、结论是什么、能不能申诉。
///   举报内容与举报人身份**与被举报人无关**（草案 §5 的两条不许妥协之一）。
class ReportPublicView {
  final String ticketId;
  final String status;
  final String action;
  final int appealCount;
  final int updatedAtMs;

  const ReportPublicView({
    required this.ticketId,
    required this.status,
    required this.action,
    required this.appealCount,
    required this.updatedAtMs,
  });

  Map<String, Object?> toMap() => {
        'ticket_id': ticketId,
        'status': status,
        'action': action,
        'appeal_count': appealCount,
        'updated_at': updatedAtMs,
      };

  static ReportPublicView fromMap(Map<String, dynamic> m) => ReportPublicView(
        ticketId: (m['ticket_id'] as String?) ?? '',
        status: (m['status'] as String?) ?? '',
        action: (m['action'] as String?) ?? '',
        appealCount: (m['appeal_count'] as num?)?.toInt() ?? 0,
        updatedAtMs: (m['updated_at'] as num?)?.toInt() ?? 0,
      );
}

/// 举报核心服务（纯逻辑，可离线复算）。
///
/// 它只做三件事：**构造工单 / 判定状态转移 / 产出审计记录**。
/// 它**不做**：网络、存储、UI 文案、运营处置动作本身。
class ReportService {
  /// 状态变化回调（供调用方在同一次落库里写审计记录 —— 硬规矩 1）。
  final void Function(ReportAuditRecord record)? onEvent;

  ReportService({this.onEvent});

  /// 构造一张**待提交**的工单（未签名）。
  ///
  /// 事由不在白名单 ⇒ 抛 [ArgumentError]：这是**程序错误**（客户端不该产生
  /// 白名单外的事由），不是用户错误，所以不上报成"受理失败"。
  ReportTicket buildTicket({
    required String ticketId,
    required String reporterPub,
    required String targetId,
    required ReportReason reason,
    required int createdAtMs,
    String contentHash = '',
    String detail = '',
  }) {
    if (!kReportTicketIdRe.hasMatch(ticketId)) {
      throw ArgumentError.value(ticketId, 'ticketId', '工单编号格式必须是 RPT- + 12 位大写十六进制');
    }
    if (detail.length > kReportMaxDetailChars) {
      throw ArgumentError.value(detail.length, 'detail', '附注超过 $kReportMaxDetailChars 字');
    }
    if (contentHash.isNotEmpty && !kReportContentHashRe.hasMatch(contentHash)) {
      throw ArgumentError.value(contentHash, 'contentHash', '内容哈希必须是 64 位小写十六进制');
    }
    return ReportTicket(
      ticketId: ticketId,
      reporterPub: reporterPub,
      targetId: targetId,
      reason: reason,
      contentHash: contentHash,
      detail: detail,
      createdAtMs: createdAtMs,
    );
  }

  /// 给工单补上签名（用本机身份私钥）。
  ///
  /// fail-closed 返回 `null` 的唯一情形：拿不到举报人公钥。
  /// 绝不用空公钥"签一张"—— 那等于造出一张不可验证的凭证。
  static Future<ReportTicket?> signTicket({
    required ReportTicket ticket,
    required String? reporterPub,
    required Future<String> Function(List<int> bytes) sign,
  }) async {
    final pub = (reporterPub ?? '').trim();
    if (pub.isEmpty) return null;
    final sig = await sign(ticket.canonicalBytes());
    return ticket.copyWith(sig: sig);
  }

  /// 判定一次状态转移是否被允许。
  ///
  /// [actor] 是发起方（[ReportActor]），[reason] 是状态说明
  /// （进 `rejected` 时**必填**，否则 `reason_required`）。
  ///
  /// ★ 本方法**不自己实现**判定 —— 它转调 [ReportAuthority.transitionDecision]。
  ///   同一件事只允许一份实现：判定规则写在权威层，客户端与服务端读同一张表。
  ///   （早期这里与权威层各写了一份判定，两份的**检查顺序还不一样** ——
  ///     同一输入两端给出不同码，"谁说了算"当场失效。）
  ReportTransitionResult canTransition({
    required ReportStatus from,
    required ReportStatus to,
    required ReportActor actor,
    int appealCount = 0,
    String reason = '',
  }) =>
      ReportAuthority.transitionDecision(
        from: from,
        to: to,
        actor: actor,
        appealCount: appealCount,
        reason: reason,
      );

  /// 执行一次状态转移：**判定 + 产出审计记录**（硬规矩 1）。
  ///
  /// 判定不通过 ⇒ 返回 `null` 且**不写审计**（没发生的事不留痕）。
  /// 判定通过 ⇒ 返回 (新工单, 审计记录) 二元组，调用方必须在同一次落库里
  /// 一起写入 —— 分两次写就会出现"状态变了但审计没写"的破洞。
  (ReportTicket, ReportAuditRecord)? applyTransition({
    required ReportTicket ticket,
    required ReportStatus to,
    required ReportActor actor,
    required int atMs,
    String reason = '',
  }) {
    final decision = canTransition(
      from: ticket.status,
      to: to,
      actor: actor,
      appealCount: ticket.appealCount,
      reason: reason,
    );
    if (!decision.accept) {
      // ★ 没发生的事不留痕：判定不通过 ⇒ **不写审计**。
      //   （早期版本这里会写一条"被拒的转移"，那是把"没做过的动作"记成做过了 ——
      //     审计日志会从"事实记录"退化成"意图记录"，与硬规矩 1 的目的正好相反。）
      return null;
    }
    final next = ticket.copyWith(
      status: to,
      statusNote: reason.isEmpty ? ticket.statusNote : reason,
      appealCount:
          to == ReportStatus.appealed ? ticket.appealCount + 1 : ticket.appealCount,
      updatedAtMs: atMs,
    );
    final record = ReportAuditRecord(
      ticketId: ticket.ticketId,
      from: ticket.status.id,
      to: to.id,
      atMs: atMs,
      actor: actor.id,
      reason: reason,
    );
    onEvent?.call(record);
    return (next, record);
  }

  /// 合法转移表（与 `report.TRANSITIONS` 同形）。
  ///
  /// ★ 返回**枚举**而不是字符串 —— 字符串表是"wire 值漂移"的第二个温床：
  ///   本表原来写的是 `['in_review']`（wire 值），而调用方比的是 `to.id`，
  ///   一旦枚举的 `id` 改了、这里没改，边就会**静默消失**
  ///   （转移被判 `bad_transition`，用户看到"状态不变"，没有任何报错）。
  ///   改成枚举比较后，`id` 改了这里也跟着走，比对的是**同一个东西**。
  static List<ReportStatus> _edges(ReportStatus from) {
    switch (from) {
      case ReportStatus.open:
        return const [ReportStatus.triaged, ReportStatus.withdrawn];
      case ReportStatus.triaged:
        return const [ReportStatus.inReview];
      case ReportStatus.inReview:
        return const [ReportStatus.actioned, ReportStatus.rejected];
      case ReportStatus.actioned:
        return const [ReportStatus.closed, ReportStatus.appealed];
      case ReportStatus.rejected:
        return const [ReportStatus.closed, ReportStatus.appealed];
      case ReportStatus.appealed:
        return const [ReportStatus.inReview];
      case ReportStatus.closed:
        return const [];
      case ReportStatus.withdrawn:
        return const [];
    }
  }
}

/// 可验证层：**任何人可独立复算**的判定。
///
/// 纯静态、无状态、零平台依赖，因此 `dart run tool/verify_report_service.dart`
/// 可离线复算全部判定。
abstract final class ReportAuthority {
  /// 幂等键：**一张工单一个键**。与 `report.keyOf` 逐字符同构。
  static String keyOf(String ticketId) => 'report|$ticketId';

  /// 校验一张工单**形式上合法且签名有效**。fail-closed。
  ///
  /// 检查顺序与返回码刻意与 `report.verify` **逐条对齐**（先便宜后昂贵、
  /// 密码学放最后）—— 两端给同一个码，才有"同一个判定"可言。
  static Future<ReportVerifyResult> verify(ReportTicket t) async {
    if (t.ticketId.isEmpty ||
        t.reporterPub.isEmpty ||
        t.targetId.isEmpty ||
        t.reason.id.isEmpty ||
        t.sig.isEmpty) {
      return const ReportVerifyResult(
          ok: false, code: ReportVerifyCode.missingFields);
    }
    if (!kReportTicketIdRe.hasMatch(t.ticketId)) {
      return const ReportVerifyResult(
          ok: false, code: ReportVerifyCode.badTicketId);
    }
    if (!Ed25519Sig.isPubkey(t.reporterPub)) {
      return const ReportVerifyResult(ok: false, code: ReportVerifyCode.badPubkey);
    }
    if (!ReportReason.values.any((r) => r.id == t.reason.id)) {
      return const ReportVerifyResult(ok: false, code: ReportVerifyCode.badReason);
    }
    if (t.contentHash.isNotEmpty && !kReportContentHashRe.hasMatch(t.contentHash)) {
      return const ReportVerifyResult(
          ok: false, code: ReportVerifyCode.badContentHash);
    }
    if (t.detail.length > kReportMaxDetailChars) {
      return const ReportVerifyResult(
          ok: false, code: ReportVerifyCode.detailTooLong);
    }
    if (t.createdAtMs <= 0) {
      return const ReportVerifyResult(ok: false, code: ReportVerifyCode.badWindow);
    }
    final ok = await Ed25519Sig.verify(
      message: t.canonicalBytes(),
      signatureB64: t.sig,
      publicKeyBase58: t.reporterPub,
    );
    return ReportVerifyResult(
      ok: ok,
      code: ok ? ReportVerifyCode.ok : ReportVerifyCode.badSignature,
    );
  }

  /// 状态机判定（与 `report.transitionDecision` **同码同序**）。
  ///
  /// ★ 检查顺序**必须**与 `packages/protocol/src/report.js` 的
  ///   `transitionDecision` 逐条对齐 —— 否则同一个输入两端给出不同的码，
  ///   "同一个判定"就成了空话。现行顺序（两端一致）：
  ///     ① 边是否存在（bad_transition）
  ///     ② 拒绝是否带理由（reason_required）—— 硬规矩 2
  ///     ③ 申诉是否已用尽（appeal_exhausted）—— 硬规矩 4
  ///     ④ 发起方是否有权走这条边（wrong_actor）
  ///   ⚠️ `bad_state` 在 Dart 侧不可达（状态是枚举），保留仅为码表同形。
  static ReportTransitionResult transitionDecision({
    required ReportStatus from,
    required ReportStatus to,
    required ReportActor actor,
    int appealCount = 0,
    String reason = '',
  }) {
    // ★ 窄特判：已经是 `appealed` 还来申诉 ⇒ 申诉机会已用完（硬规矩 4 显形）。
    //   与 `packages/protocol/src/report.js` 的 `transitionDecision` **逐条对齐**：
    //   放在边检查**之前**是有意的 —— `appealed` 的出边只有 `in_review`，
    //   所以"再申诉一次"本来会落到 `bad_transition`（状态机没这条边），
    //   而调用方需要读到的是"你的申诉机会已经用过了"（`appeal_exhausted`）。
    //   ⚠️ 只覆盖 from==appealed && to==appealed 这一种组合。
    if (from == ReportStatus.appealed && to == ReportStatus.appealed) {
      return const ReportTransitionResult(
          accept: false, code: ReportTransitionCode.appealExhausted);
    }
    if (!ReportService._edges(from).contains(to)) {
      return const ReportTransitionResult(
          accept: false, code: ReportTransitionCode.badTransition);
    }
    if (!ReportService._edges(from).contains(to)) {
      return const ReportTransitionResult(
          accept: false, code: ReportTransitionCode.badTransition);
    }
    // ★ 硬规矩 2：`rejected` 必须带理由 —— 空理由的拒绝等于没有流程。
    if (to == ReportStatus.rejected && reason.trim().isEmpty) {
      return const ReportTransitionResult(
          accept: false, code: ReportTransitionCode.reasonRequired);
    }
    // ★ 硬规矩 4：申诉只允许一轮。
    if (to == ReportStatus.appealed && appealCount >= 1) {
      return const ReportTransitionResult(
          accept: false, code: ReportTransitionCode.appealExhausted);
    }
    final actorId = actor.id;
    if (to == ReportStatus.withdrawn && actorId != ReportActor.reporter.id) {
      return const ReportTransitionResult(
          accept: false, code: ReportTransitionCode.wrongActor);
    }
    if (to == ReportStatus.appealed &&
        from == ReportStatus.rejected &&
        actorId != ReportActor.reporter.id) {
      return const ReportTransitionResult(
          accept: false, code: ReportTransitionCode.wrongActor);
    }
    if (to == ReportStatus.appealed &&
        from == ReportStatus.actioned &&
        actorId != ReportActor.target.id) {
      return const ReportTransitionResult(
          accept: false, code: ReportTransitionCode.wrongActor);
    }
    if (from == ReportStatus.appealed && to == ReportStatus.inReview) {
      if (actorId != ReportActor.admin.id) {
        return const ReportTransitionResult(
            accept: false, code: ReportTransitionCode.wrongActor);
      }
    } else if (to != ReportStatus.appealed && to != ReportStatus.withdrawn) {
      if (actorId != ReportActor.admin.id) {
        return const ReportTransitionResult(
            accept: false, code: ReportTransitionCode.wrongActor);
      }
    }
    return const ReportTransitionResult(
        accept: true, code: ReportTransitionCode.accepted);
  }

  /// 被举报人视角（与 `report.publicViewOf` 同形）。
  static ReportPublicView publicViewOf(ReportTicket t) => ReportPublicView(
        ticketId: t.ticketId,
        status: t.status.id,
        action: t.action,
        appealCount: t.appealCount,
        updatedAtMs: t.updatedAtMs,
      );
}
