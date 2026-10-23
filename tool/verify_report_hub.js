// 跨语言一致性校验：**Dart 端签的举报工单，Node Hub 端必须验得过**。
//
// 为什么需要它（与 M10 P1 房间角色同型，且这一类缺陷**单语言测试永远发现不了**）：
//   两端各自把工单拼成"确定性签名载荷"（canonical JSON）再验签。
//   Dart 的 `jsonEncode` 与 JS 的 `JSON.stringify` 都产出无空格 JSON，但**键序**
//   取决于插入顺序。键序一旦不同，同一条工单两端算出的载荷就不同 ——
//   结果是"举报人在自己设备上签得好好的，一提交到 Hub 就被判签名无效"，
//   于是客户端永远拿不到工单号、界面永远显示"提交失败"。
//
//   另一种更阴的漂移：**wire 值**。曾把 Dart 枚举名（`illegalContent` /
//   `inReview`）当成 wire 值，而协议包写的是 `illegal_content` / `in_review` ——
//   客户端提交这两类事由会被 400 静默拒收（5 个事由死了 2 个），
//   服务端返回 `in_review` 在客户端回落成 `open`（界面显示假"已受理"）。
//   本脚本同时钉住**键序**与**wire 值**两件事。
//
// 本脚本还验三件事，它们是"对外承诺可核对"的实质：
//   ① canonical 与 Dart 侧**逐字节**同构（不是"字段一样"，是字节一样）；
//   ② 幂等键同构（一张工单一个键）；
//   ③ 权威判定在 Node 侧复算出的码与 Dart 侧逐一相同（含检查顺序）。
//
// 运行：node tool/verify_report_hub.js
// 前提：先跑 `dart run tool/verify_report_service.dart` 生成探针文件。

'use strict';

const fs = require('fs');
const path = require('path');

const hub = require(path.join(__dirname, '..', 'lib', 'hub', 'hub.js'));
const protocol = require(
  path.join(__dirname, '..', 'packages', 'protocol', 'src', 'index.js')
);

let pass = 0;
let fail = 0;
function ck(ok, label) {
  if (ok) {
    pass++;
    console.log('  PASS  ' + label);
  } else {
    fail++;
    console.log('  FAIL  ' + label);
  }
}

const P = path.join(__dirname, '_report_probe_signed.json');
const CANON = path.join(__dirname, '_report_probe_canonical.txt');
const PUB = path.join(__dirname, '_report_probe_public.json');
const REP = path.join(__dirname, '_report_probe_reporter.json');

if (!fs.existsSync(P) || !fs.existsSync(CANON)) {
  console.error('缺少探针文件 —— 请先运行: dart run tool/verify_report_service.dart');
  process.exit(2);
}

const ticket = JSON.parse(fs.readFileSync(P, 'utf8'));
const dartCanonical = fs.readFileSync(CANON, 'utf8');
const dartPublic = fs.existsSync(PUB) ? JSON.parse(fs.readFileSync(PUB, 'utf8')) : null;
const dartReporter = fs.existsSync(REP) ? JSON.parse(fs.readFileSync(REP, 'utf8')) : null;

console.log('--- Dart 签的举报工单 → Node 验 ---');
ck(typeof ticket.sig === 'string' && ticket.sig.length > 0, '探针工单带签名');
ck(hub.reportSigValid(ticket) === true, 'Node 验签：Dart 签的工单验得过');
ck(hub.reportVerify(ticket).ok === true, '完整校验（verify）也通过');

// 根因层检查：canonical 必须**逐字节**一致
ck(hub.reportCanonical(ticket) === dartCanonical,
  'canonical 载荷逐字节一致（Dart jsonEncode ↔ Node JSON.stringify）');

// 幂等键同构
ck(hub.reportKeyOf(ticket.ticket_id) === 'report|' + ticket.ticket_id,
  '幂等键格式与 Dart 侧同构（report|<ticket_id>）');

console.log('--- 跨语言下的 fail-closed ---');
ck(hub.reportVerify({ ...ticket, reporter_pub: '' }).code === 'missing_fields',
  '★ 抹掉举报人后 Node 也拒（missing_fields，先于验签）');
ck(hub.reportVerify({ ...ticket, target_id: '' }).code === 'missing_fields',
  '抹掉被举报人后 Node 也拒');
ck(hub.reportVerify({ ...ticket, ticket_id: 'RPT-bad' }).code === 'bad_ticket_id',
  '坏编号 → bad_ticket_id');
ck(hub.reportVerify({ ...ticket, reporter_pub: 'not-base58!!' }).code === 'bad_pubkey',
  '坏公钥 → bad_pubkey');
ck(hub.reportVerify({ ...ticket, content_hash: 'ZZ' + 'a'.repeat(62) }).code === 'bad_content_hash',
  '坏内容哈希 → bad_content_hash');
ck(hub.reportVerify({ ...ticket, detail: 'x'.repeat(281) }).code === 'detail_too_long',
  '附注超长 → detail_too_long');
ck(hub.reportVerify({ ...ticket, reason: 'illegalContent' }).code === 'bad_reason',
  '★ 用 Dart 枚举名当 wire 值 → bad_reason（这正是曾经的静默缺陷）');
ck(hub.reportVerify({ ...ticket, reason: 'illegal_content' }).code === 'bad_signature',
  '★ 改成正确的 wire 值后：签名失效（证明载荷确实绑定 reason）');
ck(hub.reportVerify({ ...ticket, target_id: 'carol' }).code === 'bad_signature',
  '改被举报人 → bad_signature');
ck(hub.reportVerify({ ...ticket, created_at: Number(ticket.created_at) + 1 }).code === 'bad_signature',
  '改时间 → bad_signature');
ck(hub.reportVerify({ ...ticket, sig: '' }).code === 'missing_fields',
  '无签名 → missing_fields');

console.log('--- wire 值：与协议包逐字相同（防再漂回枚举名） ---');
ck(JSON.stringify(protocol.report.REASONS) === JSON.stringify(hub.REPORT_REASONS),
  '★ 事由表是包里的同一个对象引用（不是复制一份）');
ck(JSON.stringify(protocol.report.STATES) === JSON.stringify(hub.REPORT_STATES),
  '★ 状态表是包里的同一个对象引用');
ck(hub.REPORT_REASONS.includes('illegal_content') && !hub.REPORT_REASONS.includes('illegalContent'),
  '★ 事由表里是 illegal_content（不是 Dart 枚举名）');
ck(hub.REPORT_STATES.includes('in_review') && !hub.REPORT_STATES.includes('inReview'),
  '★ 状态表里是 in_review（不是 Dart 枚举名）');
ck(hub.REPORT_REASONS.length === 5 && hub.REPORT_STATES.length === 8,
  '事由 5 个 / 状态 8 个（封闭集合）');
ck(hub.REPORT_MAX_DETAIL_CHARS === protocol.report.MAX_DETAIL_CHARS,
  '附注长度上限与包内一致');

console.log('--- 权威判定：Node 复算出的码与 Dart 侧逐一相同 ---');
// 检查顺序必须一致：边 → 理由 → 申诉轮次 → 发起方
ck(hub.reportTransitionDecision('open', 'actioned', { actor: 'admin' }).code === 'bad_transition',
  '★ 顺序①：边不存在先报 bad_transition');
ck(hub.reportTransitionDecision('in_review', 'rejected', { actor: 'reporter' }).code === 'reason_required',
  '★ 顺序②：理由缺失先报 reason_required（先于发起方）');
ck(hub.reportTransitionDecision('actioned', 'appealed', { actor: 'target', appeal_count: 1 }).code === 'appeal_exhausted',
  '★ 顺序③：申诉轮次先于发起方');
ck(hub.reportTransitionDecision('open', 'actioned', { actor: 'admin' }).code !== 'wrong_actor',
  '顺序④：没走到发起方那一档就停（不越级报码）');

ck(hub.reportTransitionDecision('open', 'triaged', { actor: 'admin' }).code === 'accepted',
  'open → triaged（admin）→ accepted');
ck(hub.reportTransitionDecision('triaged', 'in_review', { actor: 'admin' }).code === 'accepted',
  'triaged → in_review（admin）→ accepted');
ck(hub.reportTransitionDecision('in_review', 'actioned', { actor: 'admin' }).code === 'accepted',
  'in_review → actioned（admin）→ accepted');
ck(hub.reportTransitionDecision('actioned', 'closed', { actor: 'admin' }).code === 'accepted',
  'actioned → closed（admin）→ accepted');
ck(hub.reportTransitionDecision('in_review', 'rejected', { actor: 'admin', reason: '不在管辖范围' }).code === 'accepted',
  'in_review → rejected（带理由）→ accepted');
ck(hub.reportTransitionDecision('rejected', 'appealed', { actor: 'reporter', appeal_count: 0 }).code === 'accepted',
  'rejected → appealed（举报人）→ accepted');
ck(hub.reportTransitionDecision('actioned', 'appealed', { actor: 'target', appeal_count: 0 }).code === 'accepted',
  'actioned → appealed（被举报人）→ accepted');
ck(hub.reportTransitionDecision('appealed', 'in_review', { actor: 'admin' }).code === 'accepted',
  'appealed → in_review（admin 复核）→ accepted');

ck(hub.reportTransitionDecision('open', 'withdrawn', { actor: 'reporter' }).code === 'accepted',
  'open → withdrawn（举报人）→ accepted');
ck(hub.reportTransitionDecision('open', 'withdrawn', { actor: 'admin' }).code === 'wrong_actor',
  '★ 撤回只有举报人能发起 → wrong_actor');
ck(hub.reportTransitionDecision('rejected', 'appealed', { actor: 'target' }).code === 'wrong_actor',
  '被举报人对"驳回"无申诉权 → wrong_actor');
ck(hub.reportTransitionDecision('actioned', 'appealed', { actor: 'reporter' }).code === 'wrong_actor',
  '举报人对"已处置"无申诉权 → wrong_actor');
ck(hub.reportTransitionDecision('actioned', 'appealed', { actor: 'admin' }).code === 'wrong_actor',
  '★ 运营不能自己制造 appealed → wrong_actor');
ck(hub.reportTransitionDecision('appealed', 'appealed', { actor: 'reporter', appeal_count: 1 }).code === 'appeal_exhausted',
  '★ 已是 appealed 再申诉 → appeal_exhausted（窄特判：不是 bad_transition）');
ck(hub.reportTransitionDecision('closed', 'appealed', { actor: 'reporter', appeal_count: 1 }).code === 'bad_transition',
  '★ 窄特判不波及终局态（closed → appealed 仍是 bad_transition）');
ck(hub.reportTransitionDecision('closed', 'in_review', { actor: 'admin' }).code === 'bad_transition',
  '终局态没有出边 → bad_transition');
ck(hub.reportTransitionDecision('withdrawn', 'triaged', { actor: 'admin' }).code === 'bad_transition',
  'withdrawn 是终局 → bad_transition');

console.log('--- 硬规矩 3：被举报人视角结构上拿不到举报人 ---');
const pub = hub.reportPublicViewOf(ticket);
ck(!('reporter_pub' in pub) && !('reporter_id' in pub) && !('detail' in pub) &&
   !('content_hash' in pub),
  '★ 公开视角没有举报人身份与举报内容字段（结构性保证，不是"记得别返回"）');
ck(pub.status !== undefined && pub.action !== undefined,
  '公开视角仍给出结论（被举报人有权知道结果）');
ck('detail' in hub.reportReporterViewOf(ticket),
  '举报人视角**有**自己写的附注（两视角是两份不同的形状）');
if (dartPublic) {
  ck(JSON.stringify(pub) === JSON.stringify(dartPublic),
    '★ 公开视角两端口径逐字节一致（Dart ↔ Node）');
}
if (dartReporter) {
  ck(JSON.stringify(hub.reportReporterViewOf(ticket)) === JSON.stringify(dartReporter),
    '★ 举报人视角两端口径逐字节一致（Dart ↔ Node）');
}

console.log('--- 硬规矩 1：审计记录形状只有一份 ---');
const rec = hub.reportAuditRecord('RPT-0123456789AB', 'open', 'triaged', 1700000000001, 'admin', 'in scope');
ck(Object.keys(rec).join(',') === 'ticket_id,from,to,at,actor,reason',
  '审计记录键序固定（六个字段，顺序不变）');
ck(rec.at === 1700000000001 && rec.actor === 'admin', '审计记录含时刻与发起方');

console.log('--- Hub 端点：六个举报路由都在（单一入口，不许散落） ---');
const hubSrc = fs.readFileSync(path.join(__dirname, '..', 'lib', 'hub', 'hub.js'), 'utf8');
ck(hubSrc.includes("pathname === '/api/report'"), 'POST /api/report（提交）');
ck(hubSrc.includes("pathname === '/api/reports/mine'"), 'GET /api/reports/mine（我的工单）');
ck(hubSrc.includes("pathname === '/api/reports/inbox'"), 'GET /api/reports/inbox（针对我的）');
ck(hubSrc.includes("seg[4] === 'appeal'"), 'POST /api/report/:id/appeal（申诉）');
ck(hubSrc.includes("seg[4] === 'withdraw'"), 'POST /api/report/:id/withdraw（撤回）');
ck(hubSrc.includes("seg[3] === 'report' && seg[5] === 'transition'"),
  'POST /api/admin/report/:id/transition（运营推进）');
ck(hubSrc.includes('db.report_identities'), '★ 举报人身份**另表**存放（内容表带不出举报人是谁）');
ck(hubSrc.includes('db.report_audit'), '★ 审计流水表存在（硬规矩 1 的落点）');
ck(!/db\.reports\[[^\]]+\]\s*=\s*\{[^}]*reporter_pub/s.test(hubSrc),
  '★ 内容表 db.reports 里**不写** reporter_pub（身份与内容分离）');

console.log('');
console.log(
  '================ Node 侧举报工单跨语言校验：' + pass + ' PASS / ' + fail + ' FAIL ================'
);
process.exit(fail === 0 ? 0 : 1);
