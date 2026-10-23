// 活体冒烟：把 **M10 P1 房间角色（Host 层权益）的 4 个 HTTP 端点**在真实启动的
// Hub 上跑一遍。
//
// 为什么纯函数已经跨语言验证过了（verify_room_role_hub.js），还要这一层：
//   上面那层证明的是"**载荷算得一样**"，但用户与第三方拿到的入口是 **HTTP**：
//   路由前缀匹配、鉴权头解析、`decodeURIComponent` 的房间号、幂等/冲突语义、
//   以及"Hub 会不会**只信客户端**"—— 这些都可能在算法正确的前提下单独出错。
//
// ★ 本脚本特别盯一条**语义陷阱**：房间角色的存储**不能照抄贡献账本**。
//   贡献是"一件事只该有一条记录"，而角色**本来就会随时间变化**（升/降/卸任）。
//   所以服务端存的是**只追加的授予历史**，名册由它重放派生；
//   `key_conflict` 只在"**同一时刻对同一个人说了两套话**"时成立。
//   下面第 13、14 步就是这条的回归证据（合法的角色变更必须被接受）。
//
// 隔离：整个流程在**临时数据目录**里跑（HUB_DATA_DIR），端口 3998，
//       结束即杀进程 + 删目录 —— 不碰仓库里的 lib/hub/data。
//
// 运行：node tool/smoke_room_role_hub.js

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

const PORT = 3998;
const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-roomrole-'));
const T0 = Date.now();

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

/** 造一条**已签名**的角色授予。 */
function makeGrant({ roomId, agentId, agentPub, role, granterId, granterPub, granterKey, atMs }) {
  const unsigned = {
    room_id: roomId,
    agent_id: agentId,
    agent_pub: agentPub,
    role,
    granted_by: granterId,
    granter_pub: granterPub,
    at_ms: atMs,
  };
  return { ...unsigned, sig: P.ed25519.signText(granterKey, P.roomRole.canonical(unsigned)) };
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

  const commit = (grant, who) =>
    call('POST', '/api/rooms/roles/commit', {
      body: { grant },
      sigHeader: authHeader(who.id, who.kp),
    });

  try {
    const ready = await waitReady();
    ck(ready, 'Hub 在临时数据目录上启动成功（端口 3998）');
    if (!ready) throw new Error('hub 未就绪');

    const A = { id: 'alice', ...newEd25519() };
    const B = { id: 'bob', ...newEd25519() };

    // ---- 注册（角色签名必须是真公钥，hmac 身份做不到）----
    const r1 = await register(A.id, A.kp, A.pub);
    ck(r1.status === 200 && r1.json.alg === 'ed25519', '注册 alice（ed25519）成功');
    const r2 = await register(B.id, B.kp, B.pub);
    ck(r2.status === 200, '注册 bob（ed25519）成功');

    // ---- 未签名写入必须被拒 ----
    const hostGrant = makeGrant({
      roomId: 'rm', agentId: A.id, agentPub: A.pub, role: 'host',
      granterId: A.id, granterPub: A.pub, granterKey: A.kp.privateKey, atMs: T0,
    });
    const noAuth = await call('POST', '/api/rooms/roles/commit', { body: { grant: hostGrant } });
    ck(noAuth.status === 401, '未签名提交 → 401（公开可读 ≠ 公开可写）');

    // ---- 1) 合法：alice 自封 rm 房间的主持人 ----
    const c1 = await commit(hostGrant, A);
    ck(c1.status === 200 && c1.json.authority === 'claimed',
      '空房间自封主持人 → 200 authority=claimed');
    ck(c1.json.appended === true && c1.json.size === 1,
      '该授予的叶子已并进 §16 日志（size=1）');
    ck(c1.json.key === P.roomRole.keyOf('rm', A.id),
      '返回的槽位键与协议包算的一致（room|rm|alice）');

    // ---- 2) 读端点：公开可下载，链完好 ----
    const list = await call('GET', '/api/rooms/roles');
    ck(list.status === 200 && list.json.size === 1, 'GET /api/rooms/roles → 公开列出 1 条');
    ck(list.json.chain_ok === true, '角色授予历史 chain_ok=true');

    // ---- 3) 名册：按历史重放派生 ----
    const roster = await call('GET', '/api/rooms/rm/roles');
    ck(roster.status === 200 && roster.json.roster.alice === 'host',
      'GET /api/rooms/rm/roles → 名册显示 alice=host');
    ck(roster.json.has_host === true && roster.json.host_layer.includes('alice'),
      '名册派生 has_host / host_layer 正确');

    // ---- 4) 包含证明：第三方**只凭协议包**独立验过 ----
    const leafHash = P.roomRole.leafHashOf(hostGrant);
    const proof = await call('GET', '/api/rooms/roles/proof/' + encodeURIComponent(leafHash));
    ck(proof.status === 200, '按**叶子哈希**取包含证明 → 200');
    ck(proof.json.leaf_hash === leafHash, '证明里的叶子哈希与第三方自算的一致');
    ck(P.log.verifyInclusionByHash(leafHash, proof.json.proof, proof.json.root) === true,
      '★ 第三方只用公开协议包就能验过这条授予在树里（不必信任 Hub）');

    // ---- 5) 幂等：同一条再提交一次 ----
    const dup = await commit(hostGrant, A);
    ck(dup.status === 200 && dup.json.duplicate === true && dup.json.appended === false &&
      dup.json.size === 1,
      '重复提交同一条 → duplicate=true 且不重复追加（幂等）');

    // ---- 6) 冲突：**同一时刻**对同一人说了两套话 → 409 ----
    const sameMoment = makeGrant({
      roomId: 'rm', agentId: A.id, agentPub: A.pub, role: 'cohost',
      granterId: A.id, granterPub: A.pub, granterKey: A.kp.privateKey, atMs: T0,
    });
    const conflict = await commit(sameMoment, A);
    ck(conflict.status === 409 && conflict.json.error === 'key_conflict',
      '★ 同一时刻对同一人两套话 → 409 key_conflict（重放顺序不可判定，必须拒）');

    // ---- 7) Hub 不只信客户端：房间已有主持人，bob 再自封 → 403 ----
    const bobClaim = makeGrant({
      roomId: 'rm', agentId: B.id, agentPub: B.pub, role: 'host',
      granterId: B.id, granterPub: B.pub, granterKey: B.kp.privateKey, atMs: T0 + 1000,
    });
    const bobClaimRes = await commit(bobClaim, B);
    ck(bobClaimRes.status === 403 && bobClaimRes.json.error === 'host_exists',
      '★ 房间已有主持人时再自封 → 403 host_exists（Hub 自己重放判定，不听客户端）');

    // ---- 8) 授予人必须就是提交者本人 ----
    const impersonate = await commit(bobClaim, A);
    ck(impersonate.status === 403 && impersonate.json.error === 'granter_pub_mismatch',
      '拿 alice 的身份提交 bob 的授予 → 403 granter_pub_mismatch');

    // ---- 9) 主持人任命联合主持人 ----
    const cohost = makeGrant({
      roomId: 'rm', agentId: B.id, agentPub: B.pub, role: 'cohost',
      granterId: A.id, granterPub: A.pub, granterKey: A.kp.privateKey, atMs: T0 + 2000,
    });
    const cohostRes = await commit(cohost, A);
    ck(cohostRes.status === 200 && cohostRes.json.authority === 'accepted',
      '主持人任命 bob 为联合主持人 → 200 accepted');
    const roster2 = await call('GET', '/api/rooms/rm/roles');
    ck(roster2.json.roster.bob === 'cohost' && roster2.json.has_host === true,
      '名册更新为 bob=cohost');

    // ---- 10) ★ 合法的角色变更必须被接受（不是 409）----
    // 这一条是上面那个语义陷阱的回归证据：同一 (房间, 人) 换个时间换角色
    // 是**正常运营**（升/降/卸任），不是"改口"。
    const aliceDown = makeGrant({
      roomId: 'rm', agentId: A.id, agentPub: A.pub, role: 'participant',
      granterId: A.id, granterPub: A.pub, granterKey: A.kp.privateKey, atMs: T0 + 3000,
    });
    const aliceDownRes = await commit(aliceDown, A);
    ck(aliceDownRes.status === 200 && aliceDownRes.json.authority === 'accepted',
      '★ 换个时间把 alice 从 host 降为 participant → 200 accepted（合法变更不被当改口）');
    const roster3 = await call('GET', '/api/rooms/rm/roles');
    ck(roster3.json.roster.alice === 'participant' && roster3.json.has_host === true,
      '名册重放：alice=participant，而 bob 仍在主持层（has_host=true）');
    ck(roster3.json.grants.length === 3, '历史保留 3 条（只追加，不覆盖）');

    // ---- 11) 撤掉最后一个主持层 → 403 last_host ----
    const bobDown = makeGrant({
      roomId: 'rm', agentId: B.id, agentPub: B.pub, role: 'participant',
      granterId: B.id, granterPub: B.pub, granterKey: B.kp.privateKey, atMs: T0 + 4000,
    });
    const bobDownRes = await commit(bobDown, B);
    ck(bobDownRes.status === 403 && bobDownRes.json.error === 'last_host',
      '★ 撤掉房间最后一个主持层 → 403 last_host（不留"有人能管、没人负责"的悬空态）');

    // ---- 12) 坏签名 / 无房间 ----
    const badSig = { ...makeGrant({
      roomId: 'rm', agentId: B.id, agentPub: B.pub, role: 'guest',
      granterId: A.id, granterPub: A.pub, granterKey: A.kp.privateKey, atMs: T0 + 5000,
    }), sig: 'AAAA' };
    const badSigRes = await commit(badSig, A);
    ck(badSigRes.status === 400 && badSigRes.json.error === 'bad_signature',
      '坏签名 → 400 bad_signature');

    const roomless = makeGrant({
      roomId: '', agentId: B.id, agentPub: B.pub, role: 'guest',
      granterId: A.id, granterPub: A.pub, granterKey: A.kp.privateKey, atMs: T0 + 6000,
    });
    const roomlessRes = await commit(roomless, A);
    ck(roomlessRes.status === 400 && roomlessRes.json.error === 'no_room',
      '★ 抹掉房间号 → 400 no_room（先于验签；账号级角色在字节层就不可表达）');

    // ---- 13) 未知叶子取证明 → 404；空房间名册 → 无主持 ----
    const unknown = await call('GET', '/api/rooms/roles/proof/' + encodeURIComponent('nope'));
    ck(unknown.status === 404, '未知叶子取证明 → 404');
    const emptyRoom = await call('GET', '/api/rooms/never-existed/roles');
    ck(emptyRoom.status === 200 && emptyRoom.json.has_host === false &&
      Object.keys(emptyRoom.json.roster).length === 0,
      '从未有人授予过的房间 → 空名册、has_host=false');
  } catch (e) {
    ck(false, '冒烟过程中抛出异常：' + e.message);
  } finally {
    child.kill();
    try {
      fs.rmSync(tmpdir, { recursive: true, force: true });
    } catch (_) {}
  }

  console.log('');
  console.log('================ 房间角色端点活体冒烟：' + pass + ' PASS / ' + fail + ' FAIL ================');
  process.exit(fail === 0 ? 0 : 1);
}

main();
