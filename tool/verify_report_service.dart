// 纯 Dart 校验脚本：举报工单核心层的**可验证性**。
// 运行：dart run tool/verify_report_service.dart
//
// 为什么值得单独一个脚本（与 M10 P1 房间角色同一范式）：
//   举报入口的承诺是**对外可核对的**——工单号、状态、处置结论、申诉轮次。
//   这些语义一旦两端漂移，漂移的形态是"客户端显示已受理、服务端其实还在处理中"，
//   或者"界面说只能申诉一次、服务端让申诉两次"。本脚本盯的就是"两端是否同说"。
//
//   ① **键序断言**：直接读 `packages/protocol/src/report.js` 的 `canonical` 键序，
//      与 Dart `canonical()` 生成的 JSON 键序**逐项比对**。键序漂移的病症是
//      "Dart 签得对、Hub 一律拒"，而本断言**不需要起 Node**就能抓住它。
//   ② **wire 值断言**：事由/状态的 wire 值必须与协议包**逐字相同**
//      （曾写成 Dart 枚举名 `illegalContent` / `inReview` ⇒ 5 个事由死了 2 个、
//      `in_review` 回落成 `open` 显示成假"已受理"）。
//   ③ **拒绝路径**：verify 的每一条 fail-closed 分支都有负例。
//   ④ **四条硬规矩**：留痕 / 驳回必带理由 / 被举报人拿不到举报人 / 申诉只一轮。
//
// 本脚本只 import 纯 Dart 模块（无 Flutter / sqflite），故可离线复算。
//
// ⚠️ 它同时**留下跨语言探针**（tool/_report_probe_*.json）供
//    `tool/verify_report_hub.js` 消费 —— 那是唯一能证明"Dart 签的工单，
//    Node 端真的验得过"的地方（单语言永远发现不了这种漂移）。

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/report_service.dart';

int _pass = 0;
int _fail = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

const int kNow = 1800000000000;

/// 生成一把 Ed25519 密钥，返回 (base58 公钥, 签名函数)。
Future<({String pub, Future<String> Function(List<int>) sign})> _newKey() async {
  final kp = await Ed25519().newKeyPair();
  final pubBytes = await kp.extractPublicKey();
  final pub = AgentProtocol.base58Encode(pubBytes.bytes);
  return (
    pub: pub,
    sign: (List<int> msg) async {
      final s = await Ed25519().sign(msg, keyPair: kp);
      return base64Encode(s.bytes);
    },
  );
}

/// 造一张**只改指定字段**的工单。
///
/// ★ 为什么不用 `copyWith`：`ReportTicket.copyWith` **故意**不开放
///   `reporter_pub` / `target_id` / `reason` / `content_hash` / `detail` /
///   `created_at` —— 那些是**签名载荷字段**，改了签名就失效，
///   而 `copyWith` 的存在意义是「改运营侧字段不用重签」。
///   本守卫要造「改载荷字段 ⇒ 必须验不过」的负例，所以只能直接构造。
ReportTicket _mutate(
  ReportTicket base, {
  String? reporterPub,
  String? targetId,
  ReportReason? reason,
  String? contentHash,
  String? detail,
  int? createdAtMs,
  String? ticketId,
  String? sig,
}) =>
    ReportTicket(
      ticketId: ticketId ?? base.ticketId,
      reporterPub: reporterPub ?? base.reporterPub,
      targetId: targetId ?? base.targetId,
      reason: reason ?? base.reason,
      contentHash: contentHash ?? base.contentHash,
      detail: detail ?? base.detail,
      createdAtMs: createdAtMs ?? base.createdAtMs,
      status: base.status,
      statusNote: base.statusNote,
      action: base.action,
      appealCount: base.appealCount,
      updatedAtMs: base.updatedAtMs,
      sig: sig ?? base.sig,
    );

/// 从 JS 源码里抠出 `report.canonical()` 的键序。
///
/// 守卫：段找得到才算数。宁可返回空清单 → 触发下面的 FAIL，
/// 也绝不 substring(-1) 直接抛 RangeError —— 崩掉的脚本看起来像"环境问题"，
/// 而 FAIL 才是指向真正病灶的信号。
List<String> _jsCanonicalKeys(String src) {
  final start = src.indexOf('function canonical(t) {');
  if (start < 0) return const [];
  final end = src.indexOf('}', start);
  if (end <= start) return const [];
  final body = src.substring(start, end);
  final keys = <String>[];
  for (final line in body.split('\n')) {
    final m = RegExp(r'^\s*([a-z_]+)\s*:').firstMatch(line);
    if (m != null) keys.add(m.group(1)!);
  }
  return keys;
}

/// 从 JS 源码里抠出 `REASONS` / `STATES` 数组的字面值。
List<String> _jsArray(String src, String name) {
  final start = src.indexOf('const $name = [');
  if (start < 0) return const [];
  final end = src.indexOf('];', start);
  if (end <= start) return const [];
  final body = src.substring(start, end);
  return RegExp(r"'([a-z_]+)'")
      .allMatches(body)
      .map((m) => m.group(1)!)
      .toList();
}

Future<void> main() async {
  final alice = await _newKey(); // 举报人
  final bob = await _newKey(); // 被举报人
  final carol = await _newKey(); // 旁观者 / 冒名者

  final jsSrc = File('packages/protocol/src/report.js').readAsStringSync();

  // =========================================================================
  print('--- ① wire 值：事由/状态必须与协议包**逐字相同** ---');
  // ⚠️ 这组断言守的是一个**静默**缺陷：曾把 Dart 枚举名当 wire 值，
  //   ⇒ 客户端提交 `illegal_content` / `fake_identity` 被服务端 400 拒收，
  //   而界面只显示"提交失败"，用户根本不知道是自己选的事由被拒。
  final jsReasons = _jsArray(jsSrc, 'REASONS');
  final jsStates = _jsArray(jsSrc, 'STATES');
  check(jsReasons.isNotEmpty, '能在 report.js 里找到 REASONS（段找得到）');
  check(jsStates.isNotEmpty, '能在 report.js 里找到 STATES（段找得到）');
  check(
    jsReasons.length == ReportReason.values.length &&
        List.generate(jsReasons.length, (i) => jsReasons[i] == ReportReason.values[i].id)
            .every((x) => x),
    '★ 事由 wire 值逐项相同（${jsReasons.join(',')}）',
  );
  check(
    jsStates.length == ReportStatus.values.length &&
        List.generate(jsStates.length, (i) => jsStates[i] == ReportStatus.values[i].id)
            .every((x) => x),
    '★ 状态 wire 值逐项相同（${jsStates.join(',')}）',
  );
  // 反向：wire 值必须是**小写 snake_case**。
  //
  // ★ 注意：**单词**枚举（open / spam / closed …）的 wire 值与枚举名**本来就相同**
  //   —— wire 值本来就是小写单词。真正的漂移风险只在**多词**枚举
  //   （illegalContent → illegal_content / inReview → in_review）。
  //   所以判据是两条：① wire 值全小写；② 多词枚举的 wire 值必含下划线。
  // ★ 两种枚举**不能**混成一个列表（Dart 会推断成 `_Enum`，拿不到 `id`）——
  //   故抽成 (name, id) 对再判。
  final allWire = <({String name, String id})>[
    for (final e in ReportReason.values) (name: e.name, id: e.id),
    for (final e in ReportStatus.values) (name: e.name, id: e.id),
  ];
  check(
    allWire.every((e) => RegExp(r'^[a-z0-9_]+$').hasMatch(e.id)),
    '★ 所有 wire 值都是小写（不含大写字母）',
  );
  final multiWord =
      allWire.where((e) => e.name != e.name.toLowerCase()).toList();
  check(multiWord.isNotEmpty, '存在多词枚举（多词才有 snake_case 漂移风险）');
  check(
    multiWord.every((e) => e.id.contains('_') && !e.id.contains(RegExp(r'[A-Z]'))),
    '★ 多词枚举的 wire 值必含下划线且无大写（防改回 camelCase）',
  );

  // =========================================================================
  print('--- ② 签名载荷：键序与协议包逐项同构 ---');
  final svc = ReportService();
  final ticket = svc.buildTicket(
    ticketId: 'RPT-0123456789AB',
    reporterPub: alice.pub,
    targetId: 'bob',
    reason: ReportReason.harassment,
    createdAtMs: kNow,
    contentHash: 'a' * 64,
    detail: '多次发送骚扰内容',
  );
  final jsKeys = _jsCanonicalKeys(jsSrc);
  final dartKeys =
      (jsonDecode(ticket.canonical()) as Map<String, dynamic>).keys.toList();
  check(jsKeys.isNotEmpty, '能在 report.js 里找到 canonical 键序（段找得到）');
  check(
    jsKeys.length == dartKeys.length &&
        List.generate(jsKeys.length, (i) => jsKeys[i] == dartKeys[i]).every((x) => x),
    '★ canonical 键序**逐项相同**（${jsKeys.join(',')}）',
  );
  check(
    !dartKeys.contains('status') &&
        !dartKeys.contains('status_note') &&
        !dartKeys.contains('action') &&
        !dartKeys.contains('appeal_count'),
    '★ 载荷里**不含**运营侧字段（状态/处置/申诉次数不该由举报人担保）',
  );

  // =========================================================================
  print('--- ③ 验签 fail-closed 的每一条拒绝路径 ---');
  final signed = ticket.copyWith(sig: await alice.sign(ticket.canonicalBytes()));
  var v = await ReportAuthority.verify(signed);
  check(v.ok && v.code == ReportVerifyCode.ok, '合法的工单 → ok');

  v = await ReportAuthority.verify(_mutate(signed, sig: ''));
  check(v.code == ReportVerifyCode.missingFields, '缺签名 → missing_fields');

  v = await ReportAuthority.verify(_mutate(signed, reporterPub: ''));
  check(v.code == ReportVerifyCode.missingFields, '缺举报人 → missing_fields');

  v = await ReportAuthority.verify(_mutate(signed, targetId: ''));
  check(v.code == ReportVerifyCode.missingFields, '缺被举报人 → missing_fields');

  v = await ReportAuthority.verify(_mutate(signed, ticketId: 'RPT-bad'));
  check(v.code == ReportVerifyCode.badTicketId, '编号格式错 → bad_ticket_id');

  v = await ReportAuthority.verify(_mutate(signed, reporterPub: 'not-base58!!'));
  check(v.code == ReportVerifyCode.badPubkey, '坏公钥 → bad_pubkey');

  v = await ReportAuthority.verify(_mutate(signed, contentHash: 'ZZ' + 'a' * 62));
  check(v.code == ReportVerifyCode.badContentHash, '坏内容哈希 → bad_content_hash');

  v = await ReportAuthority.verify(_mutate(signed, detail: 'x' * 281));
  check(v.code == ReportVerifyCode.detailTooLong, '附注超长 → detail_too_long');

  // 签完再改字段 ⇒ 验签必须失败（载荷变了）
  v = await ReportAuthority.verify(_mutate(signed, targetId: 'carol'));
  check(v.code == ReportVerifyCode.badSignature, '签完改被举报人 → bad_signature');

  v = await ReportAuthority.verify(_mutate(signed, createdAtMs: kNow + 1));
  check(v.code == ReportVerifyCode.badSignature, '签完改时间 → bad_signature');

  v = await ReportAuthority.verify(_mutate(signed, reason: ReportReason.spam));
  check(v.code == ReportVerifyCode.badSignature, '签完改事由 → bad_signature');

  // 冒名：拿第三方的私钥签
  final forged = _mutate(ticket, sig: await carol.sign(ticket.canonicalBytes()));
  v = await ReportAuthority.verify(forged);
  check(v.code == ReportVerifyCode.badSignature, '第三方私钥冒名签 → bad_signature');

  // 换举报人公钥（把 alice 的签名挂到 bob 的公钥上）
  final swapped = _mutate(ticket, reporterPub: bob.pub, sig: signed.sig);
  v = await ReportAuthority.verify(swapped);
  check(v.code == ReportVerifyCode.badSignature, '签名挂到别人公钥上 → bad_signature');

  // =========================================================================
  print('--- ④ 四条硬规矩 ---');

  // 规矩 1：没发生的转移不留痕
  final events = <ReportAuditRecord>[];
  final svc2 = ReportService(onEvent: events.add);
  final rejected = svc2.applyTransition(
    ticket: ticket,
    to: ReportStatus.actioned,
    actor: ReportActor.admin,
    atMs: 1,
  );
  check(rejected == null, '非法转移被拒（open → actioned）');
  check(events.isEmpty, '★ 规矩 1：判定不通过 ⇒ **不写审计**（没发生的事不留痕）');

  final applied = svc2.applyTransition(
    ticket: ticket,
    to: ReportStatus.triaged,
    actor: ReportActor.admin,
    atMs: 2,
    reason: '属本流程管辖',
  );
  check(applied != null, '合法转移被接受（open → triaged）');
  check(events.length == 1, '★ 规矩 1：状态变化必须留痕');
  check(events.single.from == 'open' && events.single.to == 'triaged',
      '审计记录含 from / to');
  check(events.single.atMs == 2 && events.single.actor == 'admin',
      '审计记录含时刻与发起方');

  // 规矩 2：驳回必带理由
  var d = ReportAuthority.transitionDecision(
    from: ReportStatus.inReview,
    to: ReportStatus.rejected,
    actor: ReportActor.admin,
  );
  check(!d.accept && d.code == ReportTransitionCode.reasonRequired,
      '★ 规矩 2：驳回不带理由 → reason_required');
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.inReview,
    to: ReportStatus.rejected,
    actor: ReportActor.admin,
    reason: '不属于本流程管辖',
  );
  check(d.accept, '规矩 2：带理由的驳回被接受');

  // 规矩 3：被举报人视角结构上拿不到举报人
  final pubView = ReportAuthority.publicViewOf(signed).toMap();
  check(
    !pubView.containsKey('reporter_pub') &&
        !pubView.containsKey('detail') &&
        !pubView.containsKey('content_hash'),
    '★ 规矩 3：公开视角**没有**举报人身份与举报内容字段（结构性，不是"记得别返回"）',
  );
  check(pubView.containsKey('status') && pubView.containsKey('action'),
      '规矩 3：公开视角仍给出结论（被举报人有权知道结果）');
  check(signed.toReporterView()['detail'] == '多次发送骚扰内容',
      '规矩 3：举报人**自己**看得回自己写的附注');

  // 规矩 4：申诉只一轮
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.rejected,
    to: ReportStatus.appealed,
    actor: ReportActor.reporter,
    appealCount: 0,
  );
  check(d.accept, '规矩 4：第一次申诉被接受');
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.rejected,
    to: ReportStatus.appealed,
    actor: ReportActor.reporter,
    appealCount: 1,
  );
  check(!d.accept && d.code == ReportTransitionCode.appealExhausted,
      '★ 规矩 4：第二次申诉 → appeal_exhausted');

  // =========================================================================
  print('--- ⑤ 状态机：边与发起方 ---');
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.closed,
    to: ReportStatus.inReview,
    actor: ReportActor.admin,
  );
  check(!d.accept && d.code == ReportTransitionCode.badTransition,
      '终局态没有出边 → bad_transition');
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.open,
    to: ReportStatus.withdrawn,
    actor: ReportActor.admin,
  );
  check(!d.accept && d.code == ReportTransitionCode.wrongActor,
      '撤回只有举报人能发起 → wrong_actor');
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.actioned,
    to: ReportStatus.appealed,
    actor: ReportActor.reporter,
  );
  check(!d.accept && d.code == ReportTransitionCode.wrongActor,
      '举报人对"已处置"无申诉权（那是被举报人的权利）');
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.rejected,
    to: ReportStatus.appealed,
    actor: ReportActor.target,
  );
  check(!d.accept && d.code == ReportTransitionCode.wrongActor,
      '被举报人对"驳回"无申诉权（驳回不是对他的处置）');
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.actioned,
    to: ReportStatus.appealed,
    actor: ReportActor.admin,
  );
  check(!d.accept && d.code == ReportTransitionCode.wrongActor,
      '运营不能自己制造 appealed');

  // ★ 窄特判：已是 `appealed` 还来申诉 ⇒ **申诉机会已用完**（不是 bad_transition）。
  //   `appealed` 的出边只有 `in_review`，所以"再申诉一次"本来会落到
  //   bad_transition（状态机没这条边）—— 但 `appeal_exhausted` 才是
  //   **对外承诺的语义**（硬规矩 4 的公开错误码）。
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.appealed,
    to: ReportStatus.appealed,
    actor: ReportActor.reporter,
    appealCount: 1,
  );
  check(!d.accept && d.code == ReportTransitionCode.appealExhausted,
      '★ 已是 appealed 再申诉 → appeal_exhausted（窄特判，不落到 bad_transition）');
  // ⚠️ 窄特判**不得**波及其它组合：终局态往 appealed 仍应是 bad_transition。
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.closed,
    to: ReportStatus.appealed,
    actor: ReportActor.reporter,
    appealCount: 1,
  );
  check(!d.accept && d.code == ReportTransitionCode.badTransition,
      '★ 窄特判不波及终局态（closed → appealed 仍是 bad_transition）');

  // 检查顺序：边 → 理由 → 申诉轮次 → 发起方
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.open,
    to: ReportStatus.actioned,
    actor: ReportActor.admin,
  );
  check(d.code == ReportTransitionCode.badTransition,
      '★ 检查顺序 ①：边不存在先报 bad_transition');
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.inReview,
    to: ReportStatus.rejected,
    actor: ReportActor.reporter,
  );
  check(d.code == ReportTransitionCode.reasonRequired,
      '★ 检查顺序 ②：理由缺失先报 reason_required（先于发起方）');
  d = ReportAuthority.transitionDecision(
    from: ReportStatus.actioned,
    to: ReportStatus.appealed,
    actor: ReportActor.target,
    appealCount: 1,
  );
  check(d.code == ReportTransitionCode.appealExhausted,
      '★ 检查顺序 ③：申诉轮次先于发起方');

  // =========================================================================
  print('--- ⑥ 幂等键：一张工单一个键 ---');
  check(ReportAuthority.keyOf('RPT-0123456789AB') == 'report|RPT-0123456789AB',
      '幂等键格式 = report|<ticket_id>');
  check(ReportAuthority.keyOf('RPT-0123456789AB') !=
          ReportAuthority.keyOf('RPT-0123456789AC'),
      '不同工单 = 不同键');

  // =========================================================================
  print('--- ⑦ 留跨语言探针（供 tool/verify_report_hub.js 消费） ---');
  File('tool/_report_probe_signed.json')
      .writeAsStringSync(jsonEncode(signed.toMap()));
  File('tool/_report_probe_canonical.txt').writeAsStringSync(signed.canonical());
  File('tool/_report_probe_public.json')
      .writeAsStringSync(jsonEncode(ReportAuthority.publicViewOf(signed).toMap()));
  File('tool/_report_probe_reporter.json')
      .writeAsStringSync(jsonEncode(signed.toReporterView()));
  check(
    File('tool/_report_probe_signed.json').existsSync(),
    '探针文件已写出（_report_probe_signed / canonical / public / reporter）',
  );

  // =========================================================================
  print('');
  print('================ 举报工单可验证性校验：$_pass PASS / $_fail FAIL ================');
  // ★ `run_all_verify.dart` 用这个格式解析读数，别改名。
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exit(1);
}
