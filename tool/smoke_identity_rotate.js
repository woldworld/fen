#!/usr/bin/env node
// 活体端到端冒烟：**真起一个 Hub，真换一次钥，证明"旧设备当场失效"**。
//
// 为什么必须有这一层（协议自检与跨语言校验都覆盖不到）：
//   `verify_identity_rotation.js` 证明的是"两端算得一样、验签判定一致"。
//   但"随人不随设备"这句话的**唯一实质收益**是 ——
//     ★ **换钥之后，旧设备手里的钥匙再也发不出被接受的请求。**
//   这条性质只有在真的 HTTP 会话里才成立（要经过 register 的 TOFU、mailbox 的
//   信封鉴权、以及 record.pubkey 的改绑）。它是设计文档 §7 写下的**唯一判据**：
//   "换钥后用旧钥再签名必须被拒"。
//
// 本脚本刻意**只用公开协议包**（不碰 hub.js 内部字段）—— 它同时是"第三方实现"的样板：
// 把 Hub 当黑盒，只靠 `@woldworld/protocol` 说话。
//
// 隔离：整个流程在**临时数据目录**里跑（HUB_DATA_DIR），端口 3997，
//       结束即杀进程 + 删目录 —— 不碰仓库里的 lib/hub/data。
//
// 运行：node tool/smoke_identity_rotate.js

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
const AGENT = 'agent-rotate01';
const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-rotate-'));

const nowSec = () => Math.floor(Date.now() / 1000);

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

async function register(agentId, kp, pub) {
  const env = P.envelope.sign(
    { proto: P.PROTO, ts: nowSec(), payload: { agent_id: agentId, pubkey: pub, nickname: agentId } },
    { privateKey: kp.privateKey }
  );
  return call('POST', '/api/register', { body: env });
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

/// 用**旧钥**签一条 ROTATE 声明（canonical 走公开协议包 —— 第三方也能照做）。
function signRotation(agentId, oldKey, newPub, atMs) {
  const decl = { agent_id: agentId, old_pub: oldKey.pub, new_pub: newPub, rotated_at: atMs };
  return { ...decl, sig: P.ed25519.signText(oldKey.kp.privateKey, P.rotationCanonical(decl)) };
}

/// `/api/log/leaves` 的叶子**总数**。
/// ★ 刻意写成"两种形状都认"：分页落地后回包变成 `{leaves, total, ...}`，
///   而"总数有没有变"这条断言与"怎么分页"无关 —— 它要在两种形状下都成立。
function leafCount(res) {
  const j = res && res.json;
  if (j && typeof j.total === 'number') return j.total;
  const arr = Array.isArray(j) ? j : ((j && j.leaves) || []);
  return arr.length;
}

async function main() {
  const child = spawn(process.execPath, [path.join(__dirname, '..', 'lib', 'hub', 'hub.js')], {
    env: { ...process.env, PORT: String(PORT), HUB_DATA_DIR: tmpdir },
    stdio: 'ignore',
  });

  try {
    const ready = await waitReady();
    ck(ready, 'Hub 已就绪（临时数据目录，端口 ' + PORT + '）');
    if (!ready) throw new Error('hub_not_ready');

    const oldKey = newEd25519(); // 旧设备
    const newKey = newEd25519(); // 换机后的新设备
    const stranger = newEd25519(); // 第三方

    const reg = await register(AGENT, oldKey.kp, oldKey.pub);
    ck(reg.status === 200, '旧设备注册身份成功');
    const genesisDid = reg.json && reg.json.did;
    ck(genesisDid === 'did:wold:' + oldKey.pub, '注册返回的 DID = did:wold:<旧公钥>');

    // ---- 控制组：换钥之前，旧钥匙是能用的 ----
    console.log('--- ① 控制组：换钥之前旧钥可用 ---');
    const before = await call('GET', '/api/mailbox?agent_id=' + AGENT + '&after=0', {
      sigHeader: authHeader(AGENT, oldKey.kp),
    });
    ck(before.status === 200, '★ 控制组：换钥前用旧钥签名 → 200（否则下面的 401 说明不了问题）');

    // ---- 换钥 ----
    console.log('--- ② 换钥：旧钥签 ROTATE → 活跃钥改绑 ---');
    const decl = signRotation(AGENT, oldKey, newKey.pub, Date.now());
    ck(P.rotationVerify(decl, oldKey.pub, decl.rotated_at).accept === true,
      '本地先自检：声明是合法的（旧钥签的）');
    const rot = await call('POST', '/api/identity/rotate', { body: decl });
    ck(rot.status === 200 && rot.json && rot.json.ok === true, 'POST /api/identity/rotate → 200');
    ck(rot.json && rot.json.pubkey === newKey.pub, '★ 活跃钥已改绑到新公钥');
    ck(rot.json && rot.json.did === genesisDid,
      '★ 身份锚（did）保持不变 —— 换钥不是换身份（否则历次背书对不上）');
    ck(rot.json && rot.json.appended === true, '换钥记录已追加进 §16 日志');

    // ---- ★ 唯一的实质收益：旧设备失效 ----
    console.log('--- ③ ★ 旧设备失效（本功能的唯一实质收益） ---');
    const oldAfter = await call('GET', '/api/mailbox?agent_id=' + AGENT + '&after=0', {
      sigHeader: authHeader(AGENT, oldKey.kp),
    });
    ck(oldAfter.status === 401 && oldAfter.json && oldAfter.json.error === 'bad_signature',
      '★★ 换钥后用**旧钥**再签名 → 401 bad_signature（旧手机从此发不出被接受的请求）');

    const newAfter = await call('GET', '/api/mailbox?agent_id=' + AGENT + '&after=0', {
      sigHeader: authHeader(AGENT, newKey.kp),
    });
    ck(newAfter.status === 200, '★ 用**新钥**签名 → 200（新手机接管了同一个 agent_id）');

    // ---- 重放安全 ----
    console.log('--- ④ 重放同一条声明 → not_current_key ---');
    const replay = await call('POST', '/api/identity/rotate', { body: decl });
    ck(replay.status === 409 && replay.json && replay.json.error === 'not_current_key',
      '★ 重放已生效的换钥声明 → 409 not_current_key（重放安全是白送的，不需要过期时间）');

    // ---- 别人的钥不能换掉你的身份 ----
    // ⚠️ old_pub 必须是**当前活跃钥**（=已接管的新钥）：否则会先撞上 not_current_key，
    //    验的就成了"旧钥不能二次退休"，而不是"没有私钥签不出声明"。
    const forgedDecl = {
      agent_id: AGENT,
      old_pub: newKey.pub,
      new_pub: stranger.pub,
      rotated_at: Date.now(),
    };
    forgedDecl.sig = P.ed25519.signText(stranger.kp.privateKey, P.rotationCanonical(forgedDecl));
    const forged = await call('POST', '/api/identity/rotate', { body: forgedDecl });
    ck(forged.status === 401 && forged.json && forged.json.error === 'bad_signature',
      '★ 拿第三方私钥冒名签换钥 → 401 bad_signature（没有办法替别人换钥）');

    // ---- 未注册身份不能被"换钥"出来 ----
    const ghost = signRotation('AG-NOBODY', newEd25519(), newKey.pub, Date.now());
    const ghostRes = await call('POST', '/api/identity/rotate', { body: ghost });
    ck(ghostRes.status === 404, '未登记的身份 → 404 agent_not_registered');

    // ---- §16 日志：换钥叶子匿名可查 ----
    console.log('--- ⑤ §16 公开日志：换钥留痕可被第三方复算 ---');
    const leavesRes = await call('GET', '/api/log/leaves');
    const leaves = (leavesRes.json && leavesRes.json.leaves) || leavesRes.json || [];
    const wantLeaf = P.rotationLeafHashOf(decl);
    ck(Array.isArray(leaves) && leaves.indexOf(wantLeaf) >= 0,
      '★ 换钥的叶子哈希出现在公开叶子列表里（第三方可据此做包含证明）');
    ck(rot.json && rot.json.leaf_hash === wantLeaf, '端点回报的叶子哈希 == 第三方用协议包算的');

    // ---- 改绑后重注册不得改写身份锚 ----
    console.log('--- ⑥ 重注册（新钥）不得改写身份锚 ---');
    const rereg = await register(AGENT, newKey.kp, newKey.pub);
    ck(rereg.status === 200, '新钥重注册成功（信封以**当前**活跃钥验签）');
    ck(rereg.json && rereg.json.did === genesisDid,
      '★ 重注册后 did 仍是原身份锚（不被 did:wold:<新钥> 覆盖）');

    // ---- ★ P2⑤(a)：换钥**不能**从 /api/register 悄悄溜过去 ----
    // 缺口原状：`verify()` 按 `env.alg` 派发 ⇒ 对已存在的 ed25519 身份，验签用的仍是
    // `existing.pubkey`，于是**拿着旧/当前钥就能把活跃钥换掉**，而且这条路
    // 不写 `key_rotations`、不进 §16 日志、不给旧钥留退休痕 ——
    // "换钥必然留痕""可被第三方复算"当场作废。
    console.log('--- ⑦ ★ 换钥只能走 ROTATE：register 不得静默改绑 ---');
    const leavesBefore = leafCount(await call('GET', '/api/log/leaves'));
    const sneakyKey = newEd25519();
    const sneakyEnv = P.envelope.sign(
      {
        proto: P.PROTO,
        ts: nowSec(),
        payload: { agent_id: AGENT, pubkey: sneakyKey.pub, nickname: AGENT },
      },
      { privateKey: newKey.kp.privateKey } // 用**当前活跃钥**签
    );
    const sneaky = await call('POST', '/api/register', { body: sneakyEnv });
    ck(
      sneaky.status === 409 && sneaky.json && sneaky.json.error === 'key_change_requires_rotation',
      '★★ 用当前钥重注册**另一把公钥** → 409 key_change_requires_rotation（换钥无法绕过留痕）'
    );
    const stillNew = await call('GET', '/api/mailbox?agent_id=' + AGENT + '&after=0', {
      sigHeader: authHeader(AGENT, newKey.kp),
    });
    ck(stillNew.status === 200,
      '★ 被拒之后活跃钥**一点没变**（409 是拒绝，不是"改了才报错"）');
    ck(leafCount(await call('GET', '/api/log/leaves')) === leavesBefore,
      '★ 被拒的换钥**没有**进 §16 日志（没发生过就是没发生过）');
  } finally {
    child.kill();
    try {
      fs.rmSync(tmpdir, { recursive: true, force: true });
    } catch (_) {}
  }

  console.log('');
  console.log('================ 身份换钥活体端到端：' + pass + ' PASS / ' + fail + ' FAIL ================');
  console.log('PASS=' + pass + ' FAIL=' + fail);
  if (fail > 0) process.exit(1);
}

main().catch((e) => {
  console.error('异常终止: ' + (e && e.stack ? e.stack : e));
  console.log('================ 身份换钥活体端到端：' + pass + ' PASS / ' + fail + ' FAIL ================');
  console.log('PASS=' + pass + ' FAIL=' + fail);
  process.exit(1);
});
