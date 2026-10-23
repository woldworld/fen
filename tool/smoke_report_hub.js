// 活体冒烟：把 **举报工单的 6 个 HTTP 端点**在真实启动的 Hub 上跑一遍。
//
// 为什么纯函数已经跨语言验证过了（verify_report_hub.js），还要这一层：
//   上面那层证明的是"**载荷算得一样**"，但用户与第三方拿到的入口是 **HTTP**：
//   路由分段判定、鉴权头解析、幂等语义、以及"Hub 会不会**只信客户端**"——
//   这些都可能在算法正确的前提下单独出错（例如绕开 split('/')、
//   把 `to` 缺省值解析错、鉴权失败却返回 200）。
//
// ★ 本脚本特别盯三条**语义陷阱**：
//   ① **Hub 必须自己重算 canonical 并重新验签**（不信任客户端算好的任何结论）。
//      下面第 8 步用"签名正确但字段被改"的工单验证它确实会拒。
//   ② **身份与内容分表**：`db.reports` 不含 reporter_pub、举报人身份另存
//      `db.report_identities` —— 下面第 11 步用"举报人看不到自己以外的事由内容"
//      与"被举报人看不到举报人"两个视角验证。
//   ③ **幂等**：同一张工单重试 ⇒ 返回原单（不产生第二张）；
//      同一编号两套内容 ⇒ key_conflict（不可判定 ⇒ 拒）。
//
// 隔离：整个流程在**临时数据目录**里跑（HUB_DATA_DIR），端口 3997，
//       结束即杀进程 + 删目录 —— 不碰仓库里的 lib/hub/data。
//
// 运行：node tool/smoke_report_hub.js

'use strict';

const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

// ⚠️ 本脚本刻意**直接用公开协议包**（而不是 hub.js 的内部字段）——
//    它同时是"第三方实现"的样板：把 Hub 当成一个黑盒服务，只靠协议包说话。
const P = require(path.join(__dirname, '..', 'packages', 'protocol', 'src', 'index.js'));

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

const PORT = 3997;
const ADMIN_KEY = 'smoke-admin-key';
const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-report-'));

function newEd25519() {
  const kp = crypto.generateKeyPairSync('ed25519');
  const pub = P.base58.encode(P.ed25519.rawFromKey(kp.publicKey));
  return { kp, pub };
}

function call(method, p, opts = {}) {
  return new Promise((resolve, reject) => {
    const data = opts.body ? JSON.stringify(opts.body) : null;
    const headers = {};
    if (data) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(data);
    }
    if (opts.sigHeader) headers['x-agent-sig'] = opts.sigHeader;
    if (opts.adminKey) headers['x-admin-key'] = opts.adminKey;
    const req = http.request(
      { host: '127.0.0.1', port: PORT, path: p, method, headers },
      (res) => {
        let buf = '';
        res.on('data', (d) => (buf += d));
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(buf);
          } catch (_) {
            json = buf;
          }
          resolve({ status: res.statusCode, json });
        });
      }
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

const nowSec = () => Math.floor(Date.now() / 1000);

/** 造一个 ed25519 身份的 X-Agent-Sig 头。 */
function authHeader(agentId, kp) {
  return P.envelope.signHeader(
    { proto: 'wold/1', ts: nowSec(), from: agentId },
    { privateKey: kp.privateKey }
  );
}

/** 注册一个 ed25519 身份（公钥进 Hub，私钥不出本地）。 */
async function register(agentId, kp, pub) {
  const env = P.envelope.sign(
    { proto: 'wold/1', ts: nowSec(), payload: { agent_id: agentId, pubkey: pub, nickname: agentId } },
    { privateKey: kp.privateKey }
  );
  return call('POST', '/api/register', { body: env });
}

/** 造一条**已签名**的举报工单。 */
function makeTicket({ ticketId, reporterPub, targetId, reason, reporterKey, detail = '', contentHash = '' }) {
  const unsigned = {
    ticket_id: ticketId,
    reporter_pub: reporterPub,
    target_id: targetId,
    reason,
    content_hash: contentHash,
    detail,
    created_at: Date.now(),
  };
  return { ...unsigned, sig: P.ed25519.signText(reporterKey, P.report.canonical(unsigned)) };
}

function waitReady(tries = 60) {
  return new Promise((resolve) => {
    const tick = (n) => {
      const req = http.get({ host: '127.0.0.1', port: PORT, path: '/health' }, (res) => {
        res.resume();
        resolve(true);
      });
      req.on('error', () => {
        if (n <= 0) resolve(false);
        else setTimeout(() => tick(n - 1), 100);
      });
    };
    tick(tries);
  });
}

async function main() {
  const child = spawn(process.execPath, [path.join(__dirname, '..', 'lib', 'hub', 'hub.js')], {
    env: {
      ...process.env,
      PORT: String(PORT),
      HUB_DATA_DIR: tmpdir,
      HUB_ADMIN_KEY: ADMIN_KEY,
    },
    stdio: 'ignore',
  });

  try {
    const ready = await waitReady();
    ck(ready, 'Hub 在临时数据目录上启动成功（端口 3997）');
    if (!ready) throw new Error('hub 未就绪');

    const A = { id: 'reporter-agent', ...newEd25519() }; // 举报人
    const B = { id: 'target-agent', ...newEd25519() };   // 被举报人
    const C = { id: 'stranger-agent', ...newEd25519() }; // 无关第三方

    // ---- 注册（举报签名必须是真公钥，hmac 身份做不到）----
    const r1 = await register(A.id, A.kp, A.pub);
    ck(r1.status === 200, '举报人注册成功（ed25519 身份）');
    const r2 = await register(B.id, B.kp, B.pub);
    ck(r2.status === 200, '被举报人注册成功');
    const r3 = await register(C.id, C.kp, C.pub);
    ck(r3.status === 200, '第三方注册成功');

    // ---- 1. 提交举报 ----
    const ticket = makeTicket({
      ticketId: 'RPT-000000000001',
      reporterPub: A.pub,
      targetId: B.id,
      reason: 'harassment',
      reporterKey: A.kp.privateKey,
      detail: '多次发送骚扰内容',
    });
    const submit = await call('POST', '/api/report', {
      body: { ticket },
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(submit.status === 200, 'POST /api/report → 200');
    ck(submit.json.ticket_id === 'RPT-000000000001', '返回工单号');
    ck(submit.json.status === 'open', '受理后状态 = open');
    ck(submit.json.duplicate === false, '首次提交不是重复');
    ck(submit.json.appeal_count === 0, '受理时申诉计数 = 0');

    // ---- 2. 幂等：同一张工单重试 ⇒ 返回原单，不产生第二张 ----
    const again = await call('POST', '/api/report', {
      body: { ticket },
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(again.status === 200, '重试同一张工单 → 200（不是 409）');
    ck(again.json.duplicate === true, '★ 重试被识别为 duplicate');
    ck(again.json.ticket_id === 'RPT-000000000001', '重试返回同一张工单');

    // ---- 3. key_conflict：同一编号两套内容 ⇒ 不可判定 ⇒ 拒 ----
    const conflict = makeTicket({
      ticketId: 'RPT-000000000001',
      reporterPub: A.pub,
      targetId: B.id,
      reason: 'spam', // 内容变了
      reporterKey: A.kp.privateKey,
      detail: '多次发送骚扰内容',
    });
    const conf = await call('POST', '/api/report', {
      body: { ticket: conflict },
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(conf.status === 409, '★ 同一编号两套内容 → 409');
    ck(conf.json.error === 'key_conflict', '★ 错误码 = key_conflict');

    // ---- 4. Hub 自己重算并验签（不信任客户端算好的结论）----
    const tampered = { ...ticket, detail: '被改过的附注' };
    const tam = await call('POST', '/api/report', {
      body: { ticket: tampered },
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(tam.status === 400, '★ 改了字段后 Hub 拒收（自己重算并验签）');
    ck(tam.json.error === 'bad_signature', '★ 错误码 = bad_signature');

    // ---- 5. 举报自己 ⇒ 拒 ----
    const self = makeTicket({
      ticketId: 'RPT-000000000002',
      reporterPub: A.pub,
      targetId: A.id,
      reason: 'spam',
      reporterKey: A.kp.privateKey,
    });
    const selfRes = await call('POST', '/api/report', {
      body: { ticket: self },
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(selfRes.status === 400, '★ 举报自己 → 400');
    ck(selfRes.json.error === 'self_report', '★ 错误码 = self_report');

    // ---- 6. 白名单外的事由 ⇒ 拒 ----
    const badReason = makeTicket({
      ticketId: 'RPT-000000000003',
      reporterPub: A.pub,
      targetId: B.id,
      reason: 'illegalContent', // ★ Dart 枚举名，不是 wire 值
      reporterKey: A.kp.privateKey,
    });
    const badRes = await call('POST', '/api/report', {
      body: { ticket: badReason },
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(badRes.status === 400, '★ 白名单外的事由 → 400');
    ck(badRes.json.error === 'bad_reason', '★ 错误码 = bad_reason（wire 值必须 snake_case）');

    // ---- 7. 鉴权：没签名 ⇒ 401 ----
    const noSig = await call('POST', '/api/report', { body: { ticket } });
    ck(noSig.status === 401, '★ 没签名 → 401');
    ck(noSig.json.error === 'signature_required', '★ 错误码 = signature_required');

    // ---- 8. 举报人视角：我的工单 ----
    const mine = await call('GET', '/api/reports/mine', { sigHeader: authHeader(A.id, A.kp) });
    ck(mine.status === 200, 'GET /api/reports/mine → 200');
    ck(mine.json.reports.length === 1, '我的工单只有 1 张（前面被拒的没建单）');
    const myTicket = mine.json.reports[0];
    ck(myTicket.ticket_id === 'RPT-000000000001', '工单号一致');
    ck(myTicket.detail === '多次发送骚扰内容', '★ 举报人看得回自己写的附注');
    ck(myTicket.reason === 'harassment', '★ 举报人看得回自己写的事由');
    ck(!('reporter_pub' in myTicket), '举报人视角也不含自己的公钥字段（不外泄）');

    // ---- 9. 被举报人视角：结构上拿不到举报人 ----
    const inbox = await call('GET', '/api/reports/inbox', { sigHeader: authHeader(B.id, B.kp) });
    ck(inbox.status === 200, 'GET /api/reports/inbox → 200');
    ck(inbox.json.reports.length === 1, '被举报人看到 1 张针对自己的工单');
    const theirView = inbox.json.reports[0];
    ck(!('reporter_pub' in theirView), '★ 公开视角**没有** reporter_pub 字段');
    ck(!('reporter_id' in theirView), '★ 公开视角**没有** reporter_id 字段');
    ck(!('detail' in theirView), '★ 公开视角**没有** detail（拿不到举报内容）');
    ck(!('content_hash' in theirView), '★ 公开视角**没有** content_hash');
    ck(theirView.status === 'open', '公开视角仍给出状态');

    // ---- 10. 第三方视角：既不是举报人也不是被举报人 ⇒ 看不到 ----
    const stranger = await call('GET', '/api/reports/inbox', { sigHeader: authHeader(C.id, C.kp) });
    ck(stranger.status === 200, '第三方查 inbox → 200');
    ck(stranger.json.reports.length === 0, '★ 第三方看不到任何工单（不是当事人）');
    const strangerMine = await call('GET', '/api/reports/mine', { sigHeader: authHeader(C.id, C.kp) });
    ck(strangerMine.json.reports.length === 0, '★ 第三方没有"我的工单"');

    // ---- 11. 凭工单号查单：非当事人 ⇒ 404（不泄露工单是否存在）----
    const notParty = await call('GET', '/api/report/RPT-000000000001', {
      sigHeader: authHeader(C.id, C.kp),
    });
    ck(notParty.status === 404, '★ 非当事人凭号查单 → 404（不区分"不存在"与"不归你"）');
    ck(notParty.json.error === 'unknown_ticket',
      '★ 错误码 = unknown_ticket（**故意**不用 403：403 会泄露"这个编号存在"）');

    // ---- 12. 运营推进状态机 ----
    const asTarget = await call('POST', '/api/admin/report/RPT-000000000001/transition', {
      body: { to: 'triaged' },
      adminKey: ADMIN_KEY,
    });
    ck(asTarget.status === 200, '运营 open → triaged → 200');
    ck(asTarget.json.status === 'triaged', '状态已推进');

    const noAdmin = await call('POST', '/api/admin/report/RPT-000000000001/transition', {
      body: { to: 'in_review' },
    });
    ck(noAdmin.status === 403, '★ 没有 admin key → 403（运营端点受保护）');

    // 运营不能自己制造 appealed
    const asAdminAppeal = await call('POST', '/api/admin/report/RPT-000000000001/transition', {
      body: { to: 'appealed' },
      adminKey: ADMIN_KEY,
    });
    ck(asAdminAppeal.status === 409, '★ 运营不能自己制造 appealed → 409');
    ck(asAdminAppeal.json.error === 'bad_transition',
      '★ 错误码 = bad_transition（此刻状态是 triaged，压根没有指向 appealed 的边）');

    // 驳回必须带理由（硬规矩 2）
    await call('POST', '/api/admin/report/RPT-000000000001/transition', {
      body: { to: 'in_review' },
      adminKey: ADMIN_KEY,
    });
    const noReason = await call('POST', '/api/admin/report/RPT-000000000001/transition', {
      body: { to: 'rejected' },
      adminKey: ADMIN_KEY,
    });
    ck(noReason.status === 409, '★ 驳回不带理由 → 409');
    ck(noReason.json.error === 'reason_required', '★ 错误码 = reason_required（硬规矩 2）');

    const withReason = await call('POST', '/api/admin/report/RPT-000000000001/transition', {
      body: { to: 'rejected', reason: '经核实不构成本流程管辖的举报' },
      adminKey: ADMIN_KEY,
    });
    ck(withReason.status === 200, '带理由的驳回 → 200');
    ck(withReason.json.status === 'rejected', '状态 = rejected');

    // ---- 13. 申诉：只有举报人（对"驳回"不服），只一轮 ----
    //
    // ★ 顺序要紧：**先测被举报人申诉**（此刻状态还是 rejected），
    //   再测举报人申诉 —— 否则工单已是 `appealed`，而 `appealed` 的出边
    //   只有 `in_review`，"再申诉"会落到 bad_transition（边不存在），
    //   测出来的就不是"发起方不对"这件事了。
    const targetAppeal = await call('POST', '/api/report/RPT-000000000001/appeal', {
      body: { note: '我也想申诉' },
      sigHeader: authHeader(B.id, B.kp),
    });
    ck(targetAppeal.status === 409, '★ 被举报人对"驳回"申诉 → 409');
    ck(targetAppeal.json.error === 'wrong_actor',
      '★ 错误码 = wrong_actor（驳回不是对他的处置，他无权申诉）');

    const appeal = await call('POST', '/api/report/RPT-000000000001/appeal', {
      body: { note: '我坚持这是骚扰' },
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(appeal.status === 200, '举报人对"驳回"申诉 → 200');
    ck(appeal.json.status === 'appealed', '状态 = appealed');
    ck(appeal.json.appeal_count === 1, '★ 申诉计数 = 1');
    ck(!('detail' in appeal.json.ticket), '★ 申诉回执里也没有举报内容字段');

    const appeal2 = await call('POST', '/api/report/RPT-000000000001/appeal', {
      body: { note: '再来一次' },
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(appeal2.status === 409, '★ 第二次申诉 → 409（硬规矩 4：只允许一轮）');
    ck(appeal2.json.error === 'appeal_exhausted',
      '★ 错误码 = appeal_exhausted（不是 bad_transition：这条码是对外承诺的语义）');

    // ---- 14. 撤回：只有举报人，且只能未分诊的工单 ----
    const withdrawable = makeTicket({
      ticketId: 'RPT-00000000000A',
      reporterPub: A.pub,
      targetId: B.id,
      reason: 'spam',
      reporterKey: A.kp.privateKey,
    });
    await call('POST', '/api/report', {
      body: { ticket: withdrawable },
      sigHeader: authHeader(A.id, A.kp),
    });
    const withdraw = await call('POST', '/api/report/RPT-00000000000A/withdraw', {
      body: {},
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(withdraw.status === 200, '举报人撤回自己的工单 → 200');
    ck(withdraw.json.status === 'withdrawn', '状态 = withdrawn');

    const strangerWithdraw = await call('POST', '/api/report/RPT-00000000000A/withdraw', {
      body: {},
      sigHeader: authHeader(C.id, C.kp),
    });
    ck(strangerWithdraw.status === 403, '★ 第三方撤回 → 403（不是当事人）');
    ck(strangerWithdraw.json.error === 'not_a_party', '★ 错误码 = not_a_party');

    // ---- 15. 工单号格式非法 ⇒ 400 ----
    const badId = await call('GET', '/api/report/not-a-ticket', {
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(badId.status === 400, '★ 非法工单号 → 400（服务端自己校验格式，不依赖客户端）');
    ck(badId.json.error === 'bad_ticket_id', '★ 错误码 = bad_ticket_id');

    // 格式合法但不存在的工单号 → 404（不泄露"存在性"，也不误报格式错）
    const missing = await call('GET', '/api/report/RPT-FFFFFFFFFFFF', {
      sigHeader: authHeader(A.id, A.kp),
    });
    ck(missing.status === 404, '★ 格式合法但不存在的工单号 → 404');
    ck(missing.json.error === 'unknown_ticket', '★ 错误码 = unknown_ticket');

    // ---- 16. 数据最小化：落库文件里**没有**消息原文 ----
    // ★ `saveSoon()` 有 500ms 防抖 —— 立刻读会读到"还没落盘"，
    //   那不是"没存"，是"还没写"。等一下再读。
    await new Promise((r) => setTimeout(r, 900));
    const dataFile = path.join(tmpdir, 'hub.json');
    ck(fs.existsSync(dataFile), 'Hub 数据文件已落盘');
    if (fs.existsSync(dataFile)) {
      const raw = fs.readFileSync(dataFile, 'utf8');
      const db = JSON.parse(raw);
      ck(db.reports && db.report_identities, '★ 内容表与身份表**分表**存放');
      const rec = db.reports['RPT-000000000001'];
      ck(!!rec, '工单已落库');
      ck(rec && !('reporter_pub' in rec), '★ 内容表里**没有** reporter_pub');
      ck(db.report_identities['RPT-000000000001'].reporter_pub === A.pub,
        '★ 举报人公钥在身份表里（身份与内容分离）');
      ck(Array.isArray(db.report_audit) && db.report_audit.length >= 3,
        '★ 审计流水有记录（硬规矩 1：每次状态变化都留痕）');
      const auditOk = db.report_audit.every(
        (a) =>
          typeof a.ticket_id === 'string' &&
          typeof a.from === 'string' &&
          typeof a.to === 'string' &&
          typeof a.at === 'number' &&
          typeof a.actor === 'string' &&
          typeof a.reason === 'string'
      );
      ck(auditOk, '★ 每条审计记录形状完整（六个字段）');
      // 审计里出现过 appealed ⇒ 状态变化确实被记录了
      ck(db.report_audit.some((a) => a.to === 'appealed'), '审计里有 appealed 这条变化');
    }
  } finally {
    child.kill();
    try {
      fs.rmSync(tmpdir, { recursive: true, force: true });
    } catch (_) {
      // 清理失败不掩盖主结果
    }
  }

  console.log('');
  console.log(
    '================ 举报工单活体冒烟：' + pass + ' PASS / ' + fail + ' FAIL ================'
  );
  process.exit(fail === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
