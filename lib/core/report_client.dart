/// 举报工单的 **Hub 客户端**（客户端举报入口的上行侧）。
///
/// ---------------------------------------------------------------------------
/// 分层：这一层只做「网络 + 序列化」，**不做判定**
/// ---------------------------------------------------------------------------
/// 工单的**状态机、事由白名单、签名载荷、转移判定**全部在
/// `lib/core/report_service.dart`（= 协议包 `report` 模块的 Dart 镜像），
/// 服务端在 `packages/protocol/src/report.js`（同一份实现）。
///
/// 本文件只负责：
///   ① 用**本机设备私钥**给工单签名（客户端生成编号 ⇒ 提交可重试幂等）；
///   ② 把工单 POST 到 Hub / 拉回自己的工单列表 / 提交申诉与撤回；
///   ③ 把**结果**翻译成给 UI 用的错误码（文案由 UI 层按当前语言渲染）。
///
/// ★ 为什么**不**把工单状态存在本地库：
///   条款承诺的是「凭工单编号**可查状态**」—— 状态的**唯一事实源是服务端**。
///   本地再存一份就是两个事实源，必然漂移；而漂移的形态是"本地显示已处置、
///   服务端其实还在处理中"，那是比没有状态更糟的假信息。
///   所以本地**不落库工单表**，只向 Hub 查。
///
/// ---------------------------------------------------------------------------
/// 诚实边界
/// ---------------------------------------------------------------------------
/// · 举报人身份必须是 **ed25519 公钥身份**（Hub 上有 `pubkey` 的那种）。
///   旧版 hmac 身份**无法**提交举报 —— 因为工单签名是 Ed25519 的，
///   没有公钥就签不出可验证的凭证。Hub 会回 `ed25519_required`，
///   UI 如实告知"此身份尚未升级"，**不**悄悄降级成别的提交方式。
/// · 本模块**不**执行处置（警告/限制/下架/封禁）—— 那是运营侧的动作。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'agent_identity.dart';
import 'app_logger.dart';
import 'db_helper.dart';
import 'hub_endpoint.dart';
import 'report_service.dart';
import 'telemetry.dart';

/// 提交结果。
class ReportSubmitResult {
  /// 是否成功受理（含幂等重复）。
  final bool ok;

  /// 失败原因码（成功时为空串）。**语言无关** —— 文案由 UI 层渲染。
  final String code;

  /// 工单编号（`RPT-` + 12 位大写十六进制）。**客户端生成**，故重试不会变成两张。
  final String ticketId;

  /// 受理后的状态（正常是 `open`）。
  final String status;

  /// 是否是**重复提交**（同一张工单已存在，服务端原样返回）。
  final bool duplicate;

  const ReportSubmitResult({
    required this.ok,
    required this.code,
    required this.ticketId,
    required this.status,
    required this.duplicate,
  });

  static const ReportSubmitResult failed = ReportSubmitResult(
      ok: false, code: 'unknown', ticketId: '', status: '', duplicate: false);
}

/// 申诉 / 撤回的结果。
class ReportActionResult {
  final bool ok;
  final String code;
  final String status;
  final int appealCount;

  const ReportActionResult({
    required this.ok,
    required this.code,
    required this.status,
    required this.appealCount,
  });
}

/// 举报工单 Hub 客户端。
class ReportClient {
  static final ReportClient _instance = ReportClient._internal();
  factory ReportClient() => _instance;
  ReportClient._internal();

  static const Duration _connectTimeout = Duration(seconds: 8);
  static const Duration _ioTimeout = Duration(seconds: 15);

  /// 随机源（**安全**随机：工单编号是身份凭据的一部分，撞号等于撞别人的单）。
  static final Random _rng = Random.secure();

  // ------------------------------------------------------------------
  // 提交
  // ------------------------------------------------------------------

  /// 生成一个工单编号：`RPT-` + 12 位**大写**十六进制。
  ///
  /// ★ 为什么由**客户端**生成：这样提交可以离线重试而**不会**产生两张工单
  ///   （编号即幂等键），且用户从提交那一刻起就握着可核对的编号。
  static String newTicketId() {
    final bytes = List<int>.generate(6, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'RPT-${hex.toUpperCase()}';
  }

  /// 提交一条举报。
  ///
  /// [targetId] 被举报人 agent id；[reason] 事由（白名单内）；
  /// [detail] 举报人自写附注（限 280 字，**留空也行**）；
  /// [contentHash] 被举报内容的 SHA-256 十六进制（**只给哈希，不给原文**）。
  Future<ReportSubmitResult> submit({
    required String targetId,
    required ReportReason reason,
    String detail = '',
    String contentHash = '',
  }) async {
    final hubUrl = await _hubUrl();
    if (hubUrl.isEmpty) {
      return const ReportSubmitResult(
          ok: false, code: 'hub_not_configured', ticketId: '', status: '', duplicate: false);
    }
    final myAgentId = await DBHelper.getAmbassador('my_agent_id') ?? 'AG-000';
    final identity = AgentIdentity();
    final reporterPub = await identity.publicKeyBase58();

    // 构造工单 → 签名（fail-closed：拿不到公钥就**不签**，绝不签一张不可验证的）
    final service = ReportService();
    ReportTicket ticket;
    try {
      ticket = service.buildTicket(
        ticketId: newTicketId(),
        reporterPub: reporterPub,
        targetId: targetId,
        reason: reason,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        contentHash: contentHash,
        detail: detail,
      );
    } catch (e) {
      AppLogger.w('report.build', e);
      return const ReportSubmitResult(
          ok: false, code: 'bad_ticket', ticketId: '', status: '', duplicate: false);
    }
    final signed = await ReportService.signTicket(
      ticket: ticket,
      reporterPub: reporterPub,
      sign: identity.signBase64,
    );
    if (signed == null) {
      // 拿不到公钥 ⇒ 签不出可验证的凭证 ⇒ 拒（不降级）。
      return const ReportSubmitResult(
          ok: false, code: 'ed25519_required', ticketId: '', status: '', duplicate: false);
    }

    final raw = await _post(
      hubUrl,
      '/api/report',
      body: {'ticket': signed.toMap()},
      fromId: myAgentId,
      payload: {'kind': 'report', 'ticket_id': signed.ticketId},
    );
    if (!raw.ok) {
      return ReportSubmitResult(
          ok: false,
          code: raw.code,
          ticketId: signed.ticketId,
          status: '',
          duplicate: false,
      );
    }
    final j = raw.json;
    final ok = (j['status'] as String?) ?? '';
    final duplicate = j['duplicate'] == true;
    // ★ 埋点：**真的提交成功**才发（不是"点了按钮"）。
    //   这个事件此前"定义了没人 emit" ⇒ 举报率恒为 0，
    //   于是"没人举报"与"没有举报入口"在数据上完全一样。
    //   props 只带事由分类与是否被举报人 —— **不带**附注原文（最小必要）。
    if (ok.isNotEmpty) {
      Telemetry.instance?.track(TelemetryEvents.reportFiled, props: {
        'reason': reason.id,
        'target': targetId,
        'duplicate': duplicate,
      });
    }
    return ReportSubmitResult(
      ok: true,
      code: '',
      ticketId: (j['ticket_id'] as String?) ?? signed.ticketId,
      status: ok,
      duplicate: duplicate,
    );
  }

  // ------------------------------------------------------------------
  // 查询
  // ------------------------------------------------------------------

  /// 我提交过的工单（举报人视角：可见自己写的事由与附注）。
  ///
  /// 返回空列表表示"没有"或"取不到" —— 调用方必须能分辨这两者，
  /// 所以**失败时抛异常**（[StateError]），让 UI 显形，而不是假装"没有工单"。
  Future<List<Map<String, dynamic>>> myReports() async {
    final hubUrl = await _hubUrl();
    if (hubUrl.isEmpty) {
      throw StateError('hub_not_configured');
    }
    final myAgentId = await DBHelper.getAmbassador('my_agent_id') ?? 'AG-000';
    final raw = await _get(hubUrl, '/api/reports/mine', fromId: myAgentId);
    if (!raw.ok) throw StateError(raw.code);
    final list = (raw.json['reports'] as List?) ?? const [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// 针对我的工单（**被举报人视角**）。
  ///
  /// ★ 这里返回的对象**结构上**就不含举报人身份与举报内容
  ///   （服务端用协议包的 `publicViewOf`）—— 不是"UI 不显示"，是拿不到。
  Future<List<Map<String, dynamic>>> inbox() async {
    final hubUrl = await _hubUrl();
    if (hubUrl.isEmpty) {
      throw StateError('hub_not_configured');
    }
    final myAgentId = await DBHelper.getAmbassador('my_agent_id') ?? 'AG-000';
    final raw = await _get(hubUrl, '/api/reports/inbox', fromId: myAgentId);
    if (!raw.ok) throw StateError(raw.code);
    final list = (raw.json['reports'] as List?) ?? const [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ------------------------------------------------------------------
  // 申诉 / 撤回
  // ------------------------------------------------------------------

  /// 提交一次申诉。
  ///
  /// ★ 申诉**以一次为限**（协议层 `appeal_exhausted` 硬闸，服务端执行）。
  ///   谁能申诉由**状态**决定：对"不予处置"不服的是**举报人**，
  ///   对"已处置"不服的是**被举报人** —— 服务端按签名身份反查。
  Future<ReportActionResult> appeal(String ticketId, String note) async {
    return _act('/api/report/$ticketId/appeal', ticketId, note);
  }

  /// 撤回自己提交、尚未分诊的工单。
  Future<ReportActionResult> withdraw(String ticketId) async {
    return _act('/api/report/$ticketId/withdraw', ticketId, '');
  }

  /// ★ [ticketId] 必须显式传进来：信封 payload 里要带它（服务端按工单号反查
  ///   当事人身份），而路径里也有它 —— 两处同源，合成一个参数避免写错。
  Future<ReportActionResult> _act(String path, String ticketId, String note) async {
    final hubUrl = await _hubUrl();
    if (hubUrl.isEmpty) {
      return const ReportActionResult(ok: false, code: 'hub_not_configured', status: '', appealCount: 0);
    }
    final myAgentId = await DBHelper.getAmbassador('my_agent_id') ?? 'AG-000';
    final raw = await _post(
      hubUrl,
      path,
      body: {'note': note},
      fromId: myAgentId,
      payload: {'kind': 'report_action', 'ticket_id': ticketId},
    );
    if (!raw.ok) {
      return ReportActionResult(ok: false, code: raw.code, status: '', appealCount: 0);
    }
    return ReportActionResult(
      ok: true,
      code: '',
      status: (raw.json['status'] as String?) ?? '',
      appealCount: (raw.json['appeal_count'] as num?)?.toInt() ?? 0,
    );
  }

  // ------------------------------------------------------------------
  // 内部
  // ------------------------------------------------------------------

  Future<String> _hubUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return HubEndpoint.resolveFrom(prefs.getString(HubEndpoint.prefsKey));
  }

  /// 造 `X-Agent-Sig` 头（信封**在发送这一刻现构** —— 缓存信封等于缓存过期废纸）。
  Future<String?> _sigHeader(String fromId, Map<String, dynamic> payload) async {
    try {
      final env = await AgentIdentity().buildHubEnvelope(
        fromId: fromId,
        toId: 'hub',
        payload: payload,
      );
      return base64UrlEncode(utf8.encode(jsonEncode(env)));
    } catch (e) {
      AppLogger.w('report.envelope', e);
      return null;
    }
  }

  Future<_Raw> _post(
    String hubUrl,
    String path, {
    required Map<String, dynamic> body,
    required String fromId,
    required Map<String, dynamic> payload,
  }) async {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final header = await _sigHeader(fromId, payload);
      if (header == null) return _Raw(false, 0, 'envelope_failed', const {});
      final req = await client.postUrl(Uri.parse('$hubUrl$path'));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Agent-Sig', header);
      req.write(jsonEncode(body));
      final res = await req.close().timeout(_ioTimeout);
      final text = await res.transform(utf8.decoder).join().timeout(_ioTimeout);
      return _Raw(res.statusCode == 200, res.statusCode, _errorOf(text), _jsonOf(text));
    } catch (e) {
      AppLogger.w('report.post', e);
      return _Raw(false, 0, 'network', const {});
    } finally {
      client.close(force: true);
    }
  }

  Future<_Raw> _get(String hubUrl, String path, {required String fromId}) async {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final header = await _sigHeader(fromId, {'kind': 'report_query'});
      if (header == null) return _Raw(false, 0, 'envelope_failed', const {});
      final req = await client.getUrl(Uri.parse('$hubUrl$path'));
      req.headers.set('X-Agent-Sig', header);
      final res = await req.close().timeout(_ioTimeout);
      final text = await res.transform(utf8.decoder).join().timeout(_ioTimeout);
      return _Raw(res.statusCode == 200, res.statusCode, _errorOf(text), _jsonOf(text));
    } catch (e) {
      AppLogger.w('report.get', e);
      return _Raw(false, 0, 'network', const {});
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, dynamic> _jsonOf(String text) {
    try {
      final j = jsonDecode(text);
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {
      // 非 JSON（网关错误页等）：状态码仍然是有效信息。
    }
    return const {};
  }

  static String _errorOf(String text) {
    final j = _jsonOf(text);
    final e = j['error'];
    return e is String ? e : '';
  }
}

class _Raw {
  final bool ok;
  final int status;
  final String code;
  final Map<String, dynamic> json;
  const _Raw(this.ok, this.status, this.code, this.json);
}
