#!/usr/bin/env node
// 活体端到端冒烟：**换钥链「公开读」端点** —— 真起 Hub、真换两次钥、匿名读链。
//
// 为什么必须单独有这一层：
//   `verify_identity_rotation.js` 证明的是"两端算得一样、判定一致"；
//   `smoke_identity_rotate.js` 证明的是"旧设备当场失效"。
//   而本轮的缺口是**第三方还不能独立复核"某 DID 何时换过钥"** ——
//   这件事的判据只有三条，且都只能在真的 HTTP 会话里成立：
//     ① **匿名**就能读（要鉴权才能读，就等于"只有自己人才能监督我"）；
//     ② `did → agent_id` 能解析（否则看着 DID 无从下手）；
//     ③ ★ **链断了必须显形** —— 这是"可监督"里唯一有对手的那一条。
//
// ★ 第 ③ 条刻意**伸手改了数据文件**（本脚本唯一一处碰内部）。理由：
//   库里没有任何"合法接口"能把链改坏，而"改坏之后读得出来"恰恰是要证的东西。
//   改的是 `key_rotations` 的字段，**不碰 `log`** —— 所以 §16 的哈希链仍自检为真，
//   于是这条断言证明的是"换钥链有自己的完整性检查"，不是"日志顺带报了错"。
//
// 隔离：临时数据目录（HUB_DATA_DIR），端口 3996，结束即杀进程 + 删目录。
// 运行：node tool/smoke_identity_rotations.js

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

const PORT = 3996;
const AGENT = 'agent-chain01';
const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-chain-'));
const HUB_JS = path.join(__dirname, '..', 'lib', 'hub', 'hub.js');
const DATA_FILE = path.join(tmpdir, 'hub.json');

const nowSec = () => Math.floor(Date.now() / 1000);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function call(method, p, opts = {}) {
  return new Promise((resolve, reject) => {
    const data = opts.body ? JSON.stringify(opts.body) : null;
    const headers = {};
    if (data) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(data);
    }
    if (opts.sigHeader) headers['x-agent-sig'] = opts.sigHeader;
    // ★ 匿名标记：任何一次带签名的调用都会被记下来，末尾统一断言"读链那几次真没带"。
    if (opts.sigHeader) usedAuthOnRead = true;
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
let usedAuthOnRead = false;

/** 匿名读（**刻意不带任何鉴权头**）—— 端点若要求签名，这里就会拿到 401。 */
const readChain = (query = '') =>
  call('GET', '/api/identity/rotations' + query);

function newEd25519() {
  const kp = crypto.generateKeyPairSync('ed25519');
  const pub = P.base58.encode(P.ed25519.rawFromKey(kp.publicKey));
  return { kp, pub };
}

function authHeader(agentId, kp) {
  return P.envelope.signHeader(
    { proto: P.PROTO, ts: nowSec(), from: agentId },
    { privateKey: kp.privateKey }
  );
}

function register(agentId, kp, pub) {
  const env = P.envelope.sign(
    { proto: P.PROTO, ts: nowSec(), payload: { agent_id: agentId, pubkey: pub, nickname: agentId } },
    { privateKey: kp.privateKey }
  );
  return call('POST', '/api/register', { body: env });
}

function signRotation(agentId, oldKey, newPub, atMs) {
  const decl = { agent_id: agentId, old_pub: oldKey.pub, new_pub: newPub, rotated_at: atMs };
  return { ...decl, sig: P.ed25519.signText(oldKey.kp.privateKey, P.rotationCanonical(decl)) };
}

function spawnHub() {
  return spawn(process.execPath, [HUB_JS], {
    env: { ...process.env, PORT: String(PORT), HUB_DATA_DIR: tmpdir },
    stdio: 'ignore',
  });
}

function waitReady(tries = 80) {
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

function exited(child) {
  return new Promise((resolve) => child.once('exit', () => resolve(true)));
}

/** 轮询等待数据文件满足条件（Hub 的落盘是 500ms 去抖，不能靠"猜"）。 */
async function waitForData(pred, timeoutMs = 6000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const raw = fs.readFileSync(DATA_FILE, 'utf8');
      const db = JSON.parse(raw);
      if (pred(db)) return db;
    } catch (_) {}
    await sleep(120);
  }
  return null;
}

async function main() {
  const first = spawnHub();

  try {
    ck(await waitReady(), 'Hub 已就绪（临时数据目录，端口 ' + PORT + '）');

    const oldKey = newEd25519();
    const midKey = newEd25519();
    const finalKey = newEd25519();

    const reg = await register(AGENT, oldKey.kp, oldKey.pub);
    ck(reg.status === 200, '身份注册成功');
    const genesisDid = reg.json && reg.json.did;
    ck(genesisDid === 'did:wold:' + oldKey.pub, '注册返回的 DID = did:wold:<创世公钥>');

    // ---- ① 还没换过钥：应当是"一条都没有"，而不是 404 ----
    console.log('--- ① 空链：从没换过钥是一个有意义的答案 ---');
    const empty = await readChain();
    ck(empty.status === 200, '★ 匿名 GET /api/identity/rotations → 200（**没有**任何鉴权头）');
    ck(empty.json && empty.json.total === 0 && Array.isArray(empty.json.rotations)
        && empty.json.rotations.length === 0, '未换钥时 total=0、rotations=[]');
    ck(empty.json && empty.json.chain_links_ok === true, '空库链拼接关系为真');
    ck(empty.json && typeof empty.json.root === 'string' && empty.json.root.length > 0,
      '响应带 §16 当前根（第三方据此对日志做一致性证明）');
    ck(empty.json && empty.json.subject === null, '未指定主体时不产出 subject（不臆造）');

    const unknownBefore = await readChain('?agent_id=' + AGENT);
    ck(unknownBefore.status === 200 && unknownBefore.json.subject
        && unknownBefore.json.subject.registered === true
        && unknownBefore.json.subject.rotations === 0,
      '★ 指定已注册但未换钥的身份 → 200 + registered=true + rotations=0（**不是 404**）');
    ck(unknownBefore.json.subject.current_pubkey === oldKey.pub,
      '未换钥时 current_pubkey = 创世公钥');

    // ---- ② 换一次钥，再匿名读 ----
    console.log('--- ② 换钥后匿名读：记录与身份锚都能对上 ---');
    const decl1 = signRotation(AGENT, oldKey, midKey.pub, Date.now());
    const rot1 = await call('POST', '/api/identity/rotate', { body: decl1 });
    ck(rot1.status === 200, '第一跳换钥：old → mid');

    const one = await readChain('?agent_id=' + AGENT);
    const rec1 = one.json.rotations[0];
    ck(one.json.total === 1 && one.json.size === 1, '换一次后 total=1');
    ck(rec1.agent_id === AGENT && rec1.old_pub === oldKey.pub && rec1.new_pub === midKey.pub,
      '★ 记录里 old_pub / new_pub 与真实换钥一致');
    ck(rec1.sig === decl1.sig, '★ 记录带**原始签名**（验证方自己验，Hub 不下结论）');
    ck(rec1.leaf_hash === P.rotationLeafHashOf(decl1),
      '★ 记录里的 leaf_hash == 第三方用协议包独立算出的（可据此取包含证明）');
    ck(Number.isInteger(rec1.idx) && rec1.idx >= 0, '记录带 §16 叶子下标 idx');
    ck(one.json.subject.registered === true && one.json.subject.did === genesisDid,
      '★ subject.did === 身份锚（换钥不改 did）');
    ck(one.json.subject.current_pubkey === midKey.pub, '★ subject.current_pubkey = 当前活跃钥（=mid）');
    ck(one.json.subject.chain_ok === true, '一跳的链自洽');

    // did → agent_id 解析：第三方手里只有 DID 时也得能用
    const byDid = await readChain('?did=' + encodeURIComponent(genesisDid));
    ck(byDid.status === 200 && byDid.json.subject
        && byDid.json.subject.agent_id === AGENT,
      '★ 用 did 查：did → agent_id 解析成功（看着 DID 也能下手）');
    ck(byDid.json.subject.rotations === 1 && byDid.json.rotations.length === 1,
      '按 did 查与按 agent_id 查得到同一份链');

    // 查无此人 ≠ 404
    const ghost = await readChain('?agent_id=AG-NOBODY-AT-ALL');
    ck(ghost.status === 200 && ghost.json.subject
        && ghost.json.subject.registered === false
        && ghost.json.subject.rotations === 0,
      '★ Hub 不认识的身份 → 200 + registered=false（"查无此身份"与"有身份但没换过钥"可分）');

    // ---- ③ 换第二次：链要串起来 ----
    console.log('--- ③ 第二跳：链必须串得上 ---');
    const decl2 = signRotation(AGENT, midKey, finalKey.pub, Date.now());
    const rot2 = await call('POST', '/api/identity/rotate', { body: decl2 });
    ck(rot2.status === 200, '第二跳换钥：mid → final');

    const two = await readChain('?agent_id=' + AGENT);
    const chain = two.json.rotations;
    ck(two.json.total === 2 && chain.length === 2, '两跳后 total=2');
    ck(chain[0].idx < chain[1].idx, '★ 按 idx 升序返回（追加顺序 = 权威顺序，不按客户端自报时间排）');
    ck(chain[1].old_pub === chain[0].new_pub,
      '★★ 链串上了：后一条的 old_pub === 前一条的 new_pub');
    ck(two.json.subject.current_pubkey === finalKey.pub && chain[1].new_pub === finalKey.pub,
      '★ 链末端 === 当前活跃钥');
    ck(two.json.subject.chain_ok === true && two.json.chain_links_ok === true,
      '两跳的链与全库拼接关系都自洽');

    // ---- ④ ★ 改坏链 → 必须显形 ----
    console.log('--- ④ ★ 篡改必显形（本脚本唯一一处碰内部数据文件） ---');
    const saved = await waitForData(
      (db) => db && db.key_rotations && Object.keys(db.key_rotations).length === 2);
    ck(!!saved, '换钥记录已落盘（等去抖落盘，不靠猜）');

    first.kill();
    await exited(first);

    // 同时制造两种破坏，一次重启把两个分支都覆盖：
    //   · 改**第一条**的 new_pub ⇒ 后一条的 old_pub 对不上 ⇒ link_mismatch
    //   · 改**最后一条**的 new_pub ⇒ 末端不再等于当前活跃钥 ⇒ tip_not_active
    const tampered = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    const rows = Object.values(tampered.key_rotations).sort((a, b) => a.idx - b.idx);
    const other1 = P.base58.encode(Buffer.from(Array.from({ length: 32 }, (_, i) => (i * 11 + 5) & 0xff)));
    const other2 = P.base58.encode(Buffer.from(Array.from({ length: 32 }, (_, i) => (i * 13 + 7) & 0xff)));
    rows[0].new_pub = other1;
    rows[1].new_pub = other2;
    fs.writeFileSync(DATA_FILE, JSON.stringify(tampered, null, 2));

    const second = spawnHub();
    try {
      ck(await waitReady(), 'Hub 重启（在读被改坏的数据）');

      const bad = await readChain('?agent_id=' + AGENT);
      const reasons = (bad.json.subject.chain_breaks || []).map((b) => b.reason).sort();
      ck(bad.json.subject.chain_ok === false, '★★ 链被改坏 → subject.chain_ok = false（**显形**）');
      ck(reasons.indexOf('link_mismatch') >= 0,
        '★★ 断链原因含 link_mismatch（上一条 new_pub 与下一条 old_pub 对不上）');
      ck(reasons.indexOf('tip_not_active') >= 0,
        '★★ 断链原因含 tip_not_active（末端不再等于当前活跃钥 = 中间漏了一次换钥）');
      ck(bad.json.chain_links_ok === false
          && (bad.json.broken_agents || []).indexOf(AGENT) >= 0,
        '★★ 全库拼接关系也为假，且 broken_agents 点出了是哪个身份');
      ck(bad.json.subject.current_pubkey === finalKey.pub,
        '当前活跃钥仍照实报（**不因为链坏了就隐瞒**，隐瞒才是真危险）');

      // §16 日志本体没被动过：它的自检必须仍为真 —— 证明上面那些是"换钥链自己的检查"
      const logRes = await call('GET', '/api/log');
      ck(logRes.json && logRes.json.chain_ok === true,
        '★ §16 日志自检仍为真（本轮改的是换钥链，不是日志 —— 两条检查互不代劳）');
    } finally {
      second.kill();
      await exited(second);
    }
  } finally {
    try {
      fs.rmSync(tmpdir, { recursive: true, force: true });
    } catch (_) {}
  }

  console.log('');
  ck(usedAuthOnRead === false,
    '★ 全程**没有**任何一次带鉴权头去读链（"匿名可读"是被证过的，不是被声称的）');
  console.log('================ 换钥链公开读活体端到端：' + pass + ' PASS / ' + fail + ' FAIL ================');
  if (fail > 0) process.exit(1);
}

main().catch((e) => {
  console.error('异常终止: ' + (e && e.stack ? e.stack : e));
  console.log('================ 换钥链公开读活体端到端：' + pass + ' PASS / ' + fail + ' FAIL ================');
  process.exit(1);
});
