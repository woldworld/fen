'use strict';

const { keyFromBase58, verifyText } = require('./ed25519');

// ============================================================================
// 举报工单（report ticket）—— 客户端举报入口 + 服务端工单接口的协议层。
//
// 这份文件是**跨语言单一事实源**：状态机、事由白名单、签名载荷、转移判定
// 全部只在这里写一份；Dart 端 `lib/core/report_service.dart` 是它的镜像，
// 跨语言逐字节一致性由 `tool/verify_report_hub.js` 钉住。
//
// 为什么必须单源：这些不是"内部实现细节"，而是**对外承诺的语义** ——
// 工单编号怎么算、什么叫"不予处置"、申诉凭什么只能一轮、谁能看见什么。
// 两端各写一份必然漂移，漂移的形态是"客户端说只能申诉一次、服务端让申诉两次"。
//
// ── 四条硬规矩（草案 §3，硬编码在下面的判定里，不是写在注释里）──────────────
//   1. 每个状态变化都必须写审计日志 —— 状态机只管"能不能变"，
//      "变了必须留痕"由调用方（服务端）在同一次事务里写审计记录，
//      而 `auditRecord()` 给出**唯一的记录形状**（两端同构）。
//   2. `rejected`（不予处置）必须带理由 —— 空理由的拒绝等于没有流程，
//      故 `transitionDecision` 在这里是**先于**其他检查的硬闸。
//   3. 被举报人永远看不到举报人身份 —— 见 `publicViewOf()`：它**在结构上**
//      就不含举报人身份与举报内容，只有"有一张针对你的工单被处置了"这一事实。
//      这不是靠"记得别返回"来守的，是靠"返回的对象里根本没有这个字段"。
//   4. 申诉只允许一轮 —— `appeal_count` 闸在 `transitionDecision` 里，
//      且进入 `appealed` 时计数 +1，故第二次申诉必然被拒。
//
// ⚠️ 同族 landmine：Dart 的 `jsonEncode` 与 JS 的 `JSON.stringify` 都产出无空格
//    JSON，但**键序取决于插入顺序**。改动这些对象字面量的顺序 = 让历史签名与
//    对端全部失效，**禁止重排**。
// ============================================================================

/** 举报事由白名单（封闭集合）。⚠️ 不在表内的事由一律拒绝 —— 不是"降级为其他"，
 *  是"拒绝受理"：白名单是防止"自由文本事由"变成无法归类的投诉池。 */
const REASONS = [
  'spam',            // 垃圾广告 / 批量骚扰
  'harassment',      // 骚扰、辱骂、威胁
  'illegal_content', // 违法违规内容
  'fake_identity',   // 虚假身份 / 冒充他人
  'other',           // 其他（需在 detail 里说明）
];

/** 工单状态机（8 态）。顺序即"流程推进顺序"，便于人读。 */
const STATES = [
  'open',        // 已收到，未分诊
  'triaged',     // 已定性（是否属本流程管辖）
  'in_review',   // 处理中
  'actioned',    // 已处置
  'rejected',    // 不予处置（必须带理由）
  'appealed',    // 已申诉（只允许一轮）
  'closed',      // 终局
  'withdrawn',   // 举报人自己撤回
];

/**
 * 合法转移表。
 *
 * 草案 §3 的状态图（ASCII）画的是主干，这里把它**写成表**，因为"哪些边存在"
 * 本身就是承诺的一部分 —— 多一条边就多一种绕过终局的路径。
 *
 * ★ 转移语义（与草案 §3 图逐条对应）：
 *   open       → triaged        （分诊定性）
 *   open       → withdrawn      （举报人自己撤回；草案图上唯一的 withdrawn 入口）
 *   triaged    → in_review      （进入处理）
 *   in_review  → actioned       （已处置）
 *   in_review  → rejected       （不予处置，**必须带理由**）
 *   actioned   → closed         （终局）
 *   actioned   → appealed       （**被处置方**对处置不服，申诉一次）
 *   rejected   → closed         （终局）
 *   rejected   → appealed       （**举报人**对"驳回"不服，申诉一次）
 *   appealed   → in_review      （复核；只走一次）
 *
 * ★ 一处**有意超出草案图**的边：`rejected → closed`。
 *   草案的 ASCII 图只画了 `actioned → closed`，但"被驳回且举报人不再申诉"的
 *   工单若没有终局边，就永远停在 `rejected` —— 而 `closed` 在状态表里的含义是
 *   "终局"。终局必须对两条主干都可达，否则"终局"这个词对驳回路径是假的。
 *   另两条 `appealed` 入口（actioned/rejected）由草案图上 `┴` 的汇合读出。
 */
const TRANSITIONS = {
  open: ['triaged', 'withdrawn'],
  triaged: ['in_review'],
  in_review: ['actioned', 'rejected'],
  actioned: ['closed', 'appealed'],
  rejected: ['closed', 'appealed'],
  appealed: ['in_review'],
  closed: [],
  withdrawn: [],
};

/** 转移的发起方角色。谁能发起哪条边，是硬闸的一部分。 */
const ACTORS = {
  reporter: 'reporter', // 举报人
  target: 'target',     // 被举报人（仅在已处置时可申诉）
  admin: 'admin',       // 运营（推进状态机）
};

/** 事由附注长度上限（自由文本，越短越好 —— 这不是投诉信）。 */
const MAX_DETAIL_CHARS = 280;

/** 工单编号格式：`RPT-` + 12 位大写十六进制。客户端生成（可离线、可重试幂等）。 */
const TICKET_ID_RE = /^RPT-[0-9A-F]{12}$/;

/** 被举报内容哈希：只存哈希，**不存原文**（数据最小化的硬形态）。 */
const CONTENT_HASH_RE = /^[0-9a-f]{64}$/;

/**
 * 签名载荷。必须与 Dart `ReportTicket.canonical()` 逐字节同构。
 *
 * 字段集刻意**不含**举报人的人类可读身份（昵称 / agent 名），只有公钥：
 * 签名凭据要能自证身份，但不该把自由文本带进一条会被长期保存的凭证里。
 */
function canonical(t) {
  return JSON.stringify({
    alg: 'ed25519',
    kind: 'report',
    ticket_id: String(t.ticket_id || ''),
    reporter_pub: String(t.reporter_pub || ''),
    target_id: String(t.target_id || ''),
    reason: String(t.reason || ''),
    content_hash: String(t.content_hash || ''),
    detail: String(t.detail || ''),
    created_at: Number(t.created_at || 0),
  });
}

/** 幂等键：一张工单一个键（客户端生成的编号即主键）。 */
function keyOf(ticketId) {
  return `report|${String(ticketId || '')}`;
}

/** 签名是否有效（fail-closed）。 */
function sigValid(t) {
  return verifyText(t && t.reporter_pub, canonical(t), t && t.sig);
}

/**
 * 全量校验：先便宜后昂贵，密码学放最后。返回码与 Dart 端**逐一对应**。
 * @returns {{ok:boolean, code:string}}
 */
function verify(t) {
  if (!t || typeof t !== 'object') return { ok: false, code: 'missing_fields' };
  const ticketId = String(t.ticket_id || '');
  const reporterPub = String(t.reporter_pub || '');
  const targetId = String(t.target_id || '');
  const reason = String(t.reason || '');
  const contentHash = String(t.content_hash || '');
  const detail = String(t.detail || '');
  const sig = String(t.sig || '');

  if (!ticketId || !reporterPub || !targetId || !reason || !sig) {
    return { ok: false, code: 'missing_fields' };
  }
  if (!TICKET_ID_RE.test(ticketId)) return { ok: false, code: 'bad_ticket_id' };
  if (!keyFromBase58(reporterPub)) return { ok: false, code: 'bad_pubkey' };
  if (!REASONS.includes(reason)) return { ok: false, code: 'bad_reason' };
  if (contentHash && !CONTENT_HASH_RE.test(contentHash)) {
    return { ok: false, code: 'bad_content_hash' };
  }
  if (detail.length > MAX_DETAIL_CHARS) return { ok: false, code: 'detail_too_long' };
  if (!(Number(t.created_at) > 0)) return { ok: false, code: 'bad_window' };
  if (!sigValid(t)) return { ok: false, code: 'bad_signature' };
  return { ok: true, code: 'ok' };
}

/** 该状态是否已到终局（closed / withdrawn 之后不再有任何出边）。 */
function isTerminal(state) {
  const outs = TRANSITIONS[String(state || '')];
  return !outs || outs.length === 0;
}

/**
 * 转移判定：这条边**该不该**被允许。
 *
 * 与 `verify` 一样，返回码与 Dart 端逐一对应，且**先便宜后昂贵**。
 * @param {string} from 当前状态
 * @param {string} to   目标状态
 * @param {object} ctx  { appeal_count, reason, actor }
 * @returns {{accept:boolean, code:string}}
 */
function transitionDecision(from, to, ctx) {
  const c = ctx || {};
  const f = String(from || '');
  const t = String(to || '');
  const actor = String(c.actor || '');
  const appealCount = Number(c.appeal_count || 0);

  if (!STATES.includes(f)) return { accept: false, code: 'bad_state' };
  if (!STATES.includes(t)) return { accept: false, code: 'bad_state' };
  // ★ 窄特判：已经是 `appealed` 还来申诉 ⇒ 申诉机会已用完（硬规矩 4 显形）。
  //   放在边检查**之前**是有意的：`appealed` 的出边只有 `in_review`，
  //   所以"再申诉一次"本来会落到 `bad_transition`（状态机没这条边）——
  //   而调用方需要读到的是"你的申诉机会已经用过了"（`appeal_exhausted`），
  //   那才是**对外承诺的语义**。`bad_transition` 会被读成"状态机坏了"。
  //   ⚠️ 只覆盖 f==='appealed' && t==='appealed' 这一种组合 ——
  //   不动其它任何组合的码（`closed→appealed` 之类仍是 bad_transition）。
  if (f === 'appealed' && t === 'appealed') {
    return { accept: false, code: 'appeal_exhausted' };
  }

  if (!(TRANSITIONS[f] || []).includes(t)) {
    return { accept: false, code: 'bad_transition' };
  }

  // ★ 硬规矩 2：`rejected` 必须带理由 —— 空理由的拒绝等于没有流程。
  //   闸在**边存在性之后、发起方之前**：先确认这条边合法，再问"理由给了没"，
  //   最后才问"你够不够格走这条边"。
  //   ⚠️ 这个顺序与 Dart 端 `ReportAuthority.transitionDecision` **逐条对齐** ——
  //     两端对同一输入必须给同一个码，否则"谁说了算"就没了。
  if (t === 'rejected' && !String(c.reason || '').trim()) {
    return { accept: false, code: 'reason_required' };
  }

  // ★ 硬规矩 4：申诉只允许一轮。
  if (t === 'appealed' && appealCount >= 1) {
    return { accept: false, code: 'appeal_exhausted' };
  }

  // 谁能发起哪条边。
  if (t === 'withdrawn' && actor !== ACTORS.reporter) {
    return { accept: false, code: 'wrong_actor' };
  }
  if (t === 'appealed' && f === 'rejected' && actor !== ACTORS.reporter) {
    return { accept: false, code: 'wrong_actor' };
  }
  if (t === 'appealed' && f === 'actioned' && actor !== ACTORS.target) {
    return { accept: false, code: 'wrong_actor' };
  }
  if (f !== 'appealed' && t !== 'appealed' && t !== 'withdrawn' && actor !== ACTORS.admin) {
    return { accept: false, code: 'wrong_actor' };
  }
  if (f === 'appealed' && t === 'in_review' && actor !== ACTORS.admin) {
    return { accept: false, code: 'wrong_actor' };
  }

  return { accept: true, code: 'accepted' };
}

/**
 * 审计记录（硬规矩 1：每个状态变化都必须写一条）。
 *
 * ★ 形状只有这一处定义 —— 服务端与客户端各写一份，迟早出现"服务端记了
 *   from/to，客户端记了 from/to/note"这种对不上的账。
 * @returns {{ticket_id:string, from:string, to:string, at:number, actor:string, reason:string}}
 */
function auditRecord(ticketId, from, to, atMs, actor, reason) {
  return {
    ticket_id: String(ticketId || ''),
    from: String(from || ''),
    to: String(to || ''),
    at: Number(atMs || 0),
    actor: String(actor || ''),
    reason: String(reason || ''),
  };
}

/**
 * 举报人视角：本人提交的工单，**可以看到自己写的原因与附注**。
 */
function reporterViewOf(t) {
  return {
    ticket_id: String(t.ticket_id || ''),
    target_id: String(t.target_id || ''),
    reason: String(t.reason || ''),
    content_hash: String(t.content_hash || ''),
    detail: String(t.detail || ''),
    status: String(t.status || ''),
    status_note: String(t.status_note || ''),
    appeal_count: Number(t.appeal_count || 0),
    created_at: Number(t.created_at || 0),
    updated_at: Number(t.updated_at || 0),
  };
}

/**
 * 被举报人视角（硬规矩 3）。
 *
 * ★ 这里**只列字段**，不列"要排除什么"—— 排除法是写错了就会漏的写法。
 *   本函数返回的对象里**根本不存在** reporter_pub / reporter_id / detail /
 *   content_hash / status_note 这类可回指举报人身份或举报内容的字段，
 *   所以"漏返回"这件事在结构上不可能发生。
 *
 *   被举报人需要知道的只有：有一张针对我的工单、结论是什么、能不能申诉。
 *   举报内容与举报人身份**与被举报人无关**（草案 §5 的两条不许妥协之一）。
 */
function publicViewOf(t) {
  return {
    ticket_id: String(t.ticket_id || ''),
    status: String(t.status || ''),
    action: String(t.action || ''),
    appeal_count: Number(t.appeal_count || 0),
    updated_at: Number(t.updated_at || 0),
  };
}

module.exports = {
  REASONS,
  STATES,
  TRANSITIONS,
  ACTORS,
  MAX_DETAIL_CHARS,
  TICKET_ID_RE,
  CONTENT_HASH_RE,
  canonical,
  keyOf,
  sigValid,
  verify,
  isTerminal,
  transitionDecision,
  auditRecord,
  reporterViewOf,
  publicViewOf,
};
