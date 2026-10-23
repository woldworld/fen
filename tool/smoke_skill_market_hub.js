// 活体冒烟：把 **M9 技能市场的 4 个 HTTP 端点**在真实启动的 Hub 上跑一遍。
//
// 为什么需要它（PRD §10.3 记的 M9 缺口就是这一条）：
//   跨语言校验 `verify_skill_hub.js` 证明的是"**Dart 签的字 Node 验得过**"——
//   即两端**载荷算得一样**。但技能市场真正的入口是 **HTTP**：
//   上架/吊销/分账三端点的路由、鉴权头、以及 Hub 侧的**独立复核**
//   （"上架者必须就是作者本人"、"服务器再拦一次逐分守恒"）——
//   这些在纯函数层面**根本不存在**，只能起真进程测。
//
// 本脚本刻意**把 Hub 当黑盒**，只用公开协议包构造载荷
// （它同时也是"第三方实现"的样板，和 smoke_room_role_hub.js 同一路子）。
//
// 隔离：临时数据目录（HUB_DATA_DIR）+ 端口 3997，结束即杀进程 + 删目录。
//
// 运行：node tool/smoke_skill_market_hub.js

'use strict';

const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

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
const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-skill-'));
const SKILL_ID = 'com.example.weather-lite';

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

function authHeader(agentId, kp) {
  return P.envelope.signHeader(
    { proto: 'wold/1', ts: nowSec(), from: agentId },
    { privateKey: kp.privateKey }
  );
}

async function register(agentId, kp, pub) {
  const env = P.envelope.sign(
    { proto: 'wold/1', ts: nowSec(), payload: { agent_id: agentId, pubkey: pub, nickname: agentId } },
    { privateKey: kp.privateKey }
  );
  return call('POST', '/api/register', { body: env });
}

/** 造一条**已签名**的上架清单。 */
function makeListing({ authorId, authorPub, authorKey, version, contentHash, priceCents }) {
  const unsigned = {
    skill_id: SKILL_ID,
    version,
    name: 'Weather Lite',
    description: '轻量天气查询',
    author_id: authorId,
    author_pub: authorPub,
    capabilities: ['net.read', 'clock.read'],
    risk: 'low',
    content_hash: contentHash,
    price_cents: priceCents,
    currency: 'CNY',
    published_at: Date.now(),
  };
  return { ...unsigned, sig: P.ed25519.signText(authorKey, P.skill.canonical(unsigned)) };
}

function makeRevocation({ authorPub, authorKey, version, reason }) {
  const unsigned = {
    skill_id: SKILL_ID,
    version,
    author_pub: authorPub,
    reason,
    at_ms: Date.now(),
  };
  return { ...unsigned, sig: P.ed25519.signText(authorKey, P.skill.revocationCanonical(unsigned)) };
}

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

  try {
    const ready = await waitReady();
    ck(ready, 'Hub 在临时数据目录上启动成功（端口 3997）');
    if (!ready) throw new Error('hub 未就绪');

    const A = { id: 'author-a', ...newEd25519() };
    const B = { id: 'author-b', ...newEd25519() };

    const r1 = await register(A.id, A.kp, A.pub);
    ck(r1.status === 200 && r1.json.alg === 'ed25519', '注册作者 A（ed25519）成功');
    const r2 = await register(B.id, B.kp, B.pub);
    ck(r2.status === 200, '注册作者 B（ed25519）成功');

    // ---- 未签名查询必须被拒（注册表不开放匿名爬取）----
    const anon = await call('GET', '/api/skills');
    ck(anon.status === 401, '未签名 GET /api/skills → 401（注册表不开放匿名爬取）');

    // ---- 上架 v1.0.0 ----
    const v100 = makeListing({ authorId: A.id, authorPub: A.pub, authorKey: A.kp.privateKey, version: '1.0.0', contentHash: 'H1', priceCents: 500 });
    const p1 = await call('POST', '/api/skills/publish', { body: { listing: v100 }, sigHeader: authHeader(A.id, A.kp) });
    ck(p1.status === 200 && p1.json.key === SKILL_ID + '@1.0.0', '上架 v1.0.0 → 200 且返回 skill_id@version');

    // ---- 同版本同内容 → duplicate ----
    const dup = await call('POST', '/api/skills/publish', { body: { listing: v100 }, sigHeader: authHeader(A.id, A.kp) });
    ck(dup.status === 409 && dup.json.error === 'duplicate', '同版本同内容重上架 → 409 duplicate');

    // ---- 同版本换内容 → version_conflict（想偷偷改已发布的内容）----
    const sameV = makeListing({ authorId: A.id, authorPub: A.pub, authorKey: A.kp.privateKey, version: '1.0.0', contentHash: 'H2', priceCents: 500 });
    const conflict = await call('POST', '/api/skills/publish', { body: { listing: sameV }, sigHeader: authHeader(A.id, A.kp) });
    ck(conflict.status === 409 && conflict.json.error === 'version_conflict',
      '★ 同版本换内容 → 409 version_conflict（已发布的内容不可被悄悄替换）');

    // ---- 版本倒退 → version_not_increased ----
    const older = makeListing({ authorId: A.id, authorPub: A.pub, authorKey: A.kp.privateKey, version: '0.9.0', contentHash: 'H0', priceCents: 500 });
    const backward = await call('POST', '/api/skills/publish', { body: { listing: older }, sigHeader: authHeader(A.id, A.kp) });
    ck(backward.status === 409 && backward.json.error === 'version_not_increased', '版本倒退 → 409 version_not_increased');

    // ---- 版本前进 → 200 ----
    const v101 = makeListing({ authorId: A.id, authorPub: A.pub, authorKey: A.kp.privateKey, version: '1.0.1', contentHash: 'H3', priceCents: 600 });
    const p2 = await call('POST', '/api/skills/publish', { body: { listing: v101 }, sigHeader: authHeader(A.id, A.kp) });
    ck(p2.status === 200, '版本前进 v1.0.1 → 200 accepted');

    // ---- 替别人上架 → 403 ----
    const stolen = makeListing({ authorId: B.id, authorPub: B.pub, authorKey: B.kp.privateKey, version: '9.9.9', contentHash: 'X', priceCents: 100 });
    const impersonate = await call('POST', '/api/skills/publish', { body: { listing: stolen }, sigHeader: authHeader(A.id, A.kp) });
    ck(impersonate.status === 403 && impersonate.json.error === 'author_pub_mismatch',
      '★ 拿自己的身份替别人上架 → 403 author_pub_mismatch（防抢注别人 ID）');

    // ---- 坏签名 → 401 ----
    const badSig = { ...makeListing({ authorId: A.id, authorPub: A.pub, authorKey: A.kp.privateKey, version: '1.0.2', contentHash: 'H4', priceCents: 600 }), sig: 'AAAA' };
    const badRes = await call('POST', '/api/skills/publish', { body: { listing: badSig }, sigHeader: authHeader(A.id, A.kp) });
    ck(badRes.status === 401 && badRes.json.error === 'bad_signature', '坏签名上架 → 401 bad_signature');

    // ---- 缺版本号 → 400 ----
    const noVer = { ...makeListing({ authorId: A.id, authorPub: A.pub, authorKey: A.kp.privateKey, version: '1.0.3', contentHash: 'H5', priceCents: 600 }) };
    delete noVer.version;
    noVer.sig = P.ed25519.signText(A.kp.privateKey, P.skill.canonical(noVer));
    const noVerRes = await call('POST', '/api/skills/publish', { body: { listing: noVer }, sigHeader: authHeader(A.id, A.kp) });
    ck(noVerRes.status === 400 && noVerRes.json.error === 'skill_id_required', '缺版本号 → 400 skill_id_required');

    // ---- 查询：全量注册表 ----
    const all = await call('GET', '/api/skills', { sigHeader: authHeader(A.id, A.kp) });
    ck(all.status === 200 && all.json.skills.length === 2, 'GET /api/skills → 2 个版本（1.0.0 / 1.0.1）');
    ck(Array.isArray(all.json.revoked) && all.json.revoked.length === 0, '尚未有吊销记录');

    const one = await call('GET', '/api/skills/' + encodeURIComponent(SKILL_ID), { sigHeader: authHeader(A.id, A.kp) });
    ck(one.status === 200 && one.json.versions.length === 2, 'GET /api/skills/<id> → 该技能 2 个版本');

    const missing = await call('GET', '/api/skills/' + encodeURIComponent('com.nope'), { sigHeader: authHeader(A.id, A.kp) });
    ck(missing.status === 404, '查询不存在的技能 → 404');

    // ---- 吊销：非作者不能吊 ----
    const revByB = makeRevocation({ authorPub: B.pub, authorKey: B.kp.privateKey, version: '1.0.1', reason: 'not mine' });
    const revByBRes = await call('POST', '/api/skills/revoke', { body: { revocation: revByB }, sigHeader: authHeader(B.id, B.kp) });
    ck(revByBRes.status === 403 && revByBRes.json.error === 'not_author',
      '★ 非作者吊销别人的技能 → 403 not_author');

    const revBad = { ...makeRevocation({ authorPub: A.pub, authorKey: A.kp.privateKey, version: '1.0.1', reason: 'x' }), sig: 'AAAA' };
    const revBadRes = await call('POST', '/api/skills/revoke', { body: { revocation: revBad }, sigHeader: authHeader(A.id, A.kp) });
    ck(revBadRes.status === 401 && revBadRes.json.error === 'bad_signature', '吊销带坏签名 → 401 bad_signature');

    const rev = makeRevocation({ authorPub: A.pub, authorKey: A.kp.privateKey, version: '1.0.1', reason: 'security fix' });
    const revRes = await call('POST', '/api/skills/revoke', { body: { revocation: rev }, sigHeader: authHeader(A.id, A.kp) });
    ck(revRes.status === 200, '作者本人吊销 v1.0.1 → 200');

    const all2 = await call('GET', '/api/skills', { sigHeader: authHeader(A.id, A.kp) });
    ck(all2.json.revoked.length === 1 && all2.json.revoked[0].skill_id === SKILL_ID,
      '吊销记录出现在注册表（app 侧据此下架）');

    // ---- 分账：服务器再拦一次"逐分守恒" ----
    const unbalanced = {
      purchase_id: 'pur-1',
      author_cents: 400,
      platform_cents: 100,
      referrer_cents: 0,
      amount_cents: 600, // 400+100+0 = 500 ≠ 600
    };
    const ub = await call('POST', '/api/skills/payout', { body: { entry: unbalanced }, sigHeader: authHeader(A.id, A.kp) });
    ck(ub.status === 400 && ub.json.error === 'unbalanced_split',
      '★ 分账不守恒 → 400 unbalanced_split（Hub 不只信客户端报的总额）');

    const noPid = await call('POST', '/api/skills/payout', { body: { entry: { amount_cents: 500 } }, sigHeader: authHeader(A.id, A.kp) });
    ck(noPid.status === 400 && noPid.json.error === 'purchase_id_required', '缺 purchase_id → 400');

    const balanced = {
      purchase_id: 'pur-1',
      author_cents: 400,
      platform_cents: 100,
      referrer_cents: 0,
      amount_cents: 500,
    };
    const okPay = await call('POST', '/api/skills/payout', { body: { entry: balanced }, sigHeader: authHeader(A.id, A.kp) });
    ck(okPay.status === 200 && okPay.json.ok === true, '分账守恒（400+100+0=500）→ 200');

    // 同一 purchase_id 重复记账：不重复落，也不报错（幂等）
    const dupPay = await call('POST', '/api/skills/payout', { body: { entry: balanced }, sigHeader: authHeader(A.id, A.kp) });
    ck(dupPay.status === 200 && dupPay.json.ok === true, '同一 purchase_id 重复记账 → 200（幂等，不重复落）');

    // 换一个 purchase_id 但金额不守恒 → 仍被拒（说明拦的是守恒，不是重复）
    const bal2 = { ...balanced, purchase_id: 'pur-2', amount_cents: 999 };
    const ub2 = await call('POST', '/api/skills/payout', { body: { entry: bal2 }, sigHeader: authHeader(A.id, A.kp) });
    ck(ub2.status === 400 && ub2.json.error === 'unbalanced_split', '另一个 purchase_id 仍不守恒 → 400（拦的是守恒本身）');
  } catch (e) {
    ck(false, '冒烟过程中抛出异常：' + e.message);
  } finally {
    child.kill();
    try {
      fs.rmSync(tmpdir, { recursive: true, force: true });
    } catch (_) {}
  }

  console.log('');
  console.log('================ 技能市场端点活体冒烟：' + pass + ' PASS / ' + fail + ' FAIL ================');
  process.exit(fail === 0 ? 0 : 1);
}

main();
