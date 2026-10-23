// 活体冒烟：**Hub 的横切健壮性面**（鉴权 / 请求体 / 路由 / 限流），在真实启动的 Hub 上跑。
//
// 为什么单开这一支：既有冒烟脚本都是**按功能纵向切**的
// （`smoke_room_role_hub.js` 管房间角色、`smoke_skill_market_hub.js` 管技能市场、
//  `smoke_log_hub.js` 管 §16 日志 + 贡献）。它们证明了"每个功能算得对"，
// 但**没有一个**系统性地问过这些**每个写端点都会经过**的问题：
//
//   · 信封缺失 / 不是 JSON / 未签名 / 别人签的 → 分别是哪个 401？（**先验签后验时**的顺序）
//   · 时间戳过期、在未来、为 0 → 反重放是否真的拦得住？
//   · 未知协议版本 → 拦住还是放行？
//   · 请求体不是 JSON、或超过 1MB → 是**干净的 4xx** 还是**未捕获异常 500**？
//   · 方法不匹配（GET 打 POST 端点）→ 404 还是 500？
//   · "可监督"必需的**匿名读**是否真的不要鉴权？
//   · 每 Agent 每分钟 60 次的限流，边界是不是**恰好 60 通过 / 第 61 起 429**？
//
// ★ 这些是"编译器与单测都问不到"的东西：只有把服务真起起来、拿真 HTTP 打，
//   才知道失败形态是**受控的 4xx**还是**未捕获的 500**。前者是能力，后者是漏洞。
//
// 隔离：临时数据目录（HUB_DATA_DIR）+ 端口 3996，跑完即杀进程 + 删目录。
// 运行：node tool/smoke_hub_robustness.js

'use strict';

const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

// 只用**公开协议包**说话（本脚本同时是"第三方实现"的样板：把 Hub 当黑盒）。
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

const PORT = 3996;
const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-robust-'));

function newEd25519() {
  const kp = crypto.generateKeyPairSync('ed25519');
  const pub = P.base58.encode(P.ed25519.rawFromKey(kp.publicKey));
  return { kp, pub };
}

function request(method, p, opts = {}) {
  return new Promise((resolve, reject) => {
    let data = null;
    if (opts.raw != null) data = opts.raw;
    else if (opts.body != null) data = JSON.stringify(opts.body);
    const headers = {};
    if (data != null) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(data);
    }
    if (opts.sigHeader) headers['x-agent-sig'] = opts.sigHeader;
    const req = http.request(
      {
        host: '127.0.0.1',
        port: PORT,
        path: p,
        method,
        headers,
        // ⚠️ **必须 `agent:false`**：Node 19+ 的默认 agent 开启 keep-alive，
        //   会复用连接；而"超限请求"被服务端正确处理时会**关闭**这条连接，
        //   于是**下一个**请求复用已关闭的 socket → 客户端 ECONNRESET。
        //   那看起来像"服务端崩了"，其实是测试端复用了被合法关闭的连接。
        //   关掉复用，每个请求一条新连接，读数才只反映服务端行为。
        agent: false,
      },
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
    if (data != null) req.write(data);
    req.end();
  });
}

const nowSec = () => Math.floor(Date.now() / 1000);

/// ★ 匿名配额计数器：**每 IP 的公开读配额是跨 URL 共享的**（限的是"这个来源"，
/// 不是某一个路径），所以凡是被计入配额的读都必须走这里 —— 否则后面那条
/// "边界恰好落在第 121 次"的断言就无从谈起（没有分母）。
let anonReads = 0;
function anonRead(p) {
  anonReads++;
  return request('GET', p);
}

/** 正规签名头。 */
const goodHeader = (agentId, kp, ts = nowSec()) =>
  P.envelope.signHeader({ proto: P.envelope.PROTO, ts, from: agentId }, { privateKey: kp.privateKey });

/** 手工造一个头（用于各种"畸形/未签名"形态）。 */
const rawHeader = (obj) => Buffer.from(JSON.stringify(obj), 'utf8').toString('base64url');

const err = (r) => (r && r.json && r.json.error) || '';

function waitReady(tries = 50) {
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
    env: { ...process.env, PORT: String(PORT), HUB_DATA_DIR: tmpdir },
    stdio: 'ignore',
  });

  // 写端点统一取房间角色 commit 当"探针端点"（它先鉴权、后读体，覆盖面最全）。
  const WRITE = '/api/rooms/roles/commit';
  const post = (opts) => request('POST', WRITE, opts);

  try {
    const ready = await waitReady();
    ck(ready, 'Hub 在临时数据目录上启动成功（端口 3996）');
    if (!ready) throw new Error('hub 未就绪');

    const A = { id: 'alice', ...newEd25519() };
    const M = { id: 'mallory', ...newEd25519() };

    // 注册（ed25519：公钥进 Hub，私钥不出本地）
    const regA = await request('POST', '/api/register', {
      body: P.envelope.sign(
        { proto: 'wold/1', ts: nowSec(), payload: { agent_id: A.id, pubkey: A.pub, nickname: A.id } },
        { privateKey: A.kp.privateKey }
      ),
    });
    ck(regA.status === 200, '注册 alice（ed25519）成功');
    // mallory 只用来"用别人的钥匙签"，**故意不注册**
    ck(true, 'mallory 持有密钥但**未注册**（用于伪造他人签名）');

    // =========================================================================
    console.log('');
    console.log('--- ① 鉴权面：五种失败必须落在**不同的、受控的** 401 上 ---');
    // =========================================================================
    const noSig = await post({ body: {} });
    ck(noSig.status === 401 && err(noSig) === 'signature_required',
      '完全无鉴权头 → 401 signature_required');

    const badB64 = await post({ body: {}, sigHeader: '!!!not-base64-json!!!' });
    ck(badB64.status === 401 && err(badB64) === 'signature_required',
      '鉴权头不是合法 base64url-JSON → 401 signature_required（解析失败即拒）');

    const ghost = await post({
      body: {},
      sigHeader: rawHeader({ proto: 'wold/1', ts: nowSec(), from: 'nobody' }),
    });
    ck(ghost.status === 401 && err(ghost) === 'agent_not_registered',
      '声明的身份未注册 → 401 agent_not_registered（★ 先看"你是谁"，早于验签）');

    const forged = await post({ body: {}, sigHeader: goodHeader(A.id, M.kp) });
    ck(forged.status === 401 && err(forged) === 'bad_signature',
      '★ 冒用 alice 的身份、却用**别人**的私钥签 → 401 bad_signature');

    const unsigned = await post({
      body: {},
      sigHeader: rawHeader({ proto: 'wold/1', ts: nowSec(), from: A.id }),
    });
    ck(unsigned.status === 401 && err(unsigned) === 'bad_signature',
      '头里 from=alice 但**根本没有 sig 字段** → 401 bad_signature');

    // =========================================================================
    console.log('');
    console.log('--- ② 反重放：±300s 窗口，过期/未来/零值都在**验签之后**被单独拦下 ---');
    // =========================================================================
    const stale = await post({ body: {}, sigHeader: goodHeader(A.id, A.kp, nowSec() - 600) });
    ck(stale.status === 401 && err(stale) === 'bad_timestamp',
      '★ 签名**完全正确**但时间戳早了 10 分钟 → 401 bad_timestamp（反重放：过期）');

    const future = await post({ body: {}, sigHeader: goodHeader(A.id, A.kp, nowSec() + 600) });
    ck(future.status === 401 && err(future) === 'bad_timestamp',
      '★ 时间戳在未来 10 分钟 → 401 bad_timestamp（反重放：未来）');

    const zero = await post({ body: {}, sigHeader: goodHeader(A.id, A.kp, 0) });
    ck(zero.status === 401 && err(zero) === 'bad_timestamp',
      '时间戳为 0（缺失的典型形态）→ 401 bad_timestamp');

    const wrongProto = await post({
      body: {},
      sigHeader: P.envelope.signHeader(
        { proto: 'wold/9', ts: nowSec(), from: A.id },
        { privateKey: A.kp.privateKey }
      ),
    });
    ck(wrongProto.status === 401 && err(wrongProto) === 'bad_signature',
      '★ 未知协议版本 wold/9（签名自洽）→ 401 bad_signature：**未知 proto 被拒而非放行**');

    // =========================================================================
    console.log('');
    console.log('--- ③ 请求体健壮性：畸形/超限/空体一律**受控 4xx**，绝不 500 ---');
    // =========================================================================
    const malformed = await post({ raw: '{oops', sigHeader: goodHeader(A.id, A.kp) });
    ck(malformed.status === 400 && err(malformed) === 'bad_request',
      '★ 请求体不是合法 JSON → 400 bad_request（是**干净的 400**，不是未捕获 500）');

    const huge = await post({
      raw: 'x'.repeat(1024 * 1024 + 2048),
      sigHeader: goodHeader(A.id, A.kp),
    });
    ck(huge.status === 413 && err(huge) === 'body_too_large',
      '★ 请求体 > 1MB → 413 body_too_large（在读体阶段截断，不 OOM）');

    const emptyRoom = await post({ body: {}, sigHeader: goodHeader(A.id, A.kp) });
    ck(emptyRoom.status === 400 && !!err(emptyRoom),
      '空 grant 提交 → 400 且带错误码（fail-closed，未落入 200）');

    const emptyContrib = await request('POST', '/api/contributions/commit', {
      body: {},
      sigHeader: goodHeader(A.id, A.kp),
    });
    ck(emptyContrib.status === 400 && !!err(emptyContrib),
      '空贡献提交 → 400 且带错误码（fail-closed）');

    const emptySkill = await request('POST', '/api/skills/publish', {
      body: {},
      sigHeader: goodHeader(A.id, A.kp),
    });
    ck(emptySkill.status >= 400 && emptySkill.status < 500,
      '空技能清单提交 → 4xx（★ 关键不是"哪个码"，而是**没有掉进 5xx**）');

    // =========================================================================
    console.log('');
    console.log('--- ④ 路由面：未知路径 / 方法不匹配 → 404，不是 500 ---');
    // =========================================================================
    const nope = await request('GET', '/api/nope');
    ck(nope.status === 404 && err(nope) === 'not_found', '未知路径 → 404 not_found');

    // ⚠️ 别拿 `/api/skills/publish` 试"方法不匹配"：`GET /api/skills/*` 是**另一条合法路由**
    //   （查某技能的各版本），打上去只会落到它自己的鉴权分支。要试真·无路由，用 GET-only 端点配 DELETE。
    const wrongMethod = await request('DELETE', '/api/log');
    ck(wrongMethod.status === 404 && err(wrongMethod) === 'not_found',
      'DELETE 打 GET-only 端点 → 404（方法不匹配即"无此路由"，非 500）');

    const postToGet = await request('POST', '/api/log', {
      body: {},
      sigHeader: goodHeader(A.id, A.kp),
    });
    ck(postToGet.status === 404 && err(postToGet) === 'not_found',
      'POST 打 GET-only 端点 → 404（同上）');

    // =========================================================================
    console.log('');
    console.log('--- ⑤ 「可监督」必需的**匿名读**必须真的不要鉴权 ---');
    // =========================================================================
    for (const p of ['/api/log', '/api/rooms/roles', '/api/contributions']) {
      const r = await anonRead(p);
      ck(r.status === 200, '匿名 GET ' + p + ' → 200（读匿名开放：要鉴权才能读＝"只有自己人才能监督我"）');
    }
    // ★ 反例（**故意的不对称**，不是缺陷）：技能目录**不**开放匿名爬取 ——
    //   "可监督的账本" ≠ "可批量爬取的名录"：前者必须人人可验，后者是资源（与 A2A 注册表同口径）。
    const anonSkills = await request('GET', '/api/skills');
    ck(anonSkills.status === 401 && err(anonSkills) === 'signature_required',
      '★ 匿名 GET /api/skills → 401（技能目录**故意**不开放匿名爬取，与 A2A 同口径）');
    const authSkills = await request('GET', '/api/skills', { sigHeader: goodHeader(A.id, A.kp) });
    ck(authSkills.status === 200,
      '已注册 Agent GET /api/skills → 200（鉴权后可查全量注册表 —— 同一路由，鉴权决定开合）');

    // =========================================================================
    console.log('');
    console.log('--- ⑥ 限流：每 Agent 每分钟 60 次，边界须**恰好 60 过 / 第 61 起 429** ---');
    // =========================================================================
    const Q = { id: 'quota-probe', ...newEd25519() };
    const regQ = await request('POST', '/api/register', {
      body: P.envelope.sign(
        { proto: 'wold/1', ts: nowSec(), payload: { agent_id: Q.id, pubkey: Q.pub, nickname: Q.id } },
        { privateKey: Q.kp.privateKey }
      ),
    });
    ck(regQ.status === 200, '注册限流探针身份 quota-probe');

    const N = 65;
    const statuses = [];
    for (let i = 0; i < N; i++) {
      // 每次单独造头（避免任何"同头复用"被别的机制挡下而混淆限流读数）
      const r = await post({ body: {}, sigHeader: goodHeader(Q.id, Q.kp) });
      statuses.push(r.status);
    }
    const passed = statuses.filter((s) => s !== 429).length;
    const limited = statuses.filter((s) => s === 429).length;
    ck(passed === 60, '前 60 次请求全部未被限流（实测通过 ' + passed + ' 次）');
    ck(limited === N - 60, '第 61 次起全部 429（实测被限 ' + limited + ' 次）');
    ck(statuses[59] !== 429 && statuses[60] === 429,
      '★ 限流边界**恰好落在第 61 次**（第 60 次仍过、第 61 次被拒）');

    // 限流只作用于**已通过鉴权**的请求：匿名读不应被计入（否则公开监督会被自家限流打断）
    const anonAfterLimit = await anonRead('/api/log');
    ck(anonAfterLimit.status === 200,
      '★ 探针被限流后，**匿名读仍 200**（限流按身份计，不影响公开可监督）');

    // =========================================================================
    console.log('');
    console.log('--- ⑦ ★ 匿名读**另有**一道按 IP 的配额（P1-5：公开读不能是免费的） ---');
    // =========================================================================
    // 上面那道按 **agent_id** 计，而公开读端点**根本不鉴权** ——
    // 它们连身份都没有，自然一次也不会被计入 ⇒ 对匿名爬取零约束。
    // "读匿名开放"这条正确设计，就被实现成了"匿名侧无成本、可无限刷"。
    // 这里把"另有一道"钉住：边界恰好落在**累计第 121 次**（MAX_ANON_REQ_PER_MIN = 120）。
    const ANON_CAP = 120;
    const anonStatuses = [];
    for (let i = 0; i < ANON_CAP + 60; i++) {
      const r = await anonRead('/api/log');
      anonStatuses.push(r.status);
      if (r.status === 429) break; // 见到第一个 429 就停：要的是**边界位置**
    }
    ck(anonStatuses[anonStatuses.length - 1] === 429,
      '★ 匿名读**确实**会被限流（不是"设计了但从不生效"）');
    ck(anonReads === ANON_CAP + 1,
      '★★ 边界**恰好**落在累计第 ' + (ANON_CAP + 1) + ' 次匿名读（实测第 ' + anonReads +
        ' 次；前 ' + ANON_CAP + ' 次全过、第 ' + (ANON_CAP + 1) + ' 次起 429）');
    ck(ANON_CAP > 60,
      '★ 匿名上限（' + ANON_CAP + '）**高于**按身份那道（60）：monitor 定期拉取是正当高频读，' +
        '限得比普通用户还紧等于自断可监督性');

    const anon429 = await request('GET', '/api/log/leaves');
    ck(anon429.status === 429 && err(anon429) === 'rate_limited',
      '★ 同一 IP 的其它公开读端点**一并**受限（限的是"这个来源"，不是某一个 URL）');

    // ★ 两道闸**互相独立**：匿名侧被刷爆，不该波及"按身份计"的写端点配额。
    //   这正是把它们放在两张表（且键加前缀）的原因 —— 合成一个 Map 连断言都写不清。
    const authedAfterAnon = await post({ body: {}, sigHeader: goodHeader(A.id, A.kp) });
    ck(authedAfterAnon.status !== 429,
      '★★ 匿名侧被限之后，**按身份计的请求不受影响**（两道闸彼此独立）');
  } catch (e) {
    ck(false, '冒烟过程中抛出异常：' + e.message);
  } finally {
    child.kill();
    try {
      fs.rmSync(tmpdir, { recursive: true, force: true });
    } catch (_) {}
  }

  console.log('');
  console.log('================ Hub 横切健壮性冒烟：' + pass + ' PASS / ' + fail + ' FAIL ================');
  process.exit(fail === 0 ? 0 : 1);
}

main();
