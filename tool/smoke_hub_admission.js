#!/usr/bin/env node
// ============================================================
// 活体验证：注册准入闸（ADR-002）
//
// 与 `tool/verify_hub_admission.js` 的分工：
//   · verify_* 证明"代码写得对"（纯函数语义 + 接线）；
//   · smoke_*  证明"跑起来真的拦得住"（起真进程、发真请求）。
// 两条都要有 —— 只有守卫时，一个"闸调了但 key 没从 payload 取"的笔误照样全绿。
//
// 覆盖（每条都是一个 HTTP 往返）：
//   ① key 模式下新身份无票 → 403 registration_key_required
//   ② 无管理员凭据签发 → 403
//   ③ 管理员签发 → 拿到明文票
//   ④ 持票注册 → 200，票被绑定
//   ⑤ 同一张票给另一个身份 → 409 key_already_bound
//   ⑥ 已登记身份重注册（不带票）→ 200（不能把老用户锁在门外）
//   ⑦ 吊销 → 票停用 + 身份同步停用
//   ⑧ 吊销后发消息 → 403 agent_revoked（★ 邮局真的不收他的信了）
//   ⑨ 吊销后再注册 → 403 agent_revoked
//   ⑩ 自助申领默认关 → 404
//   ⑪ open 模式（自建形态）新身份无票 → 200
//   ⑫ world 侧：吊销后发言 → 403（证明"双向落"不是纸面承诺）
//
// 用法：node tool/smoke_hub_admission.js   （自起进程，临时目录，退出即清）
// ============================================================
'use strict';

const { spawn } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const HUB_JS = path.join(ROOT, 'lib', 'hub', 'hub.js');
const WORLD_JS = path.join(ROOT, 'lib', 'hub', 'world.js');
const protocol = require(path.join(ROOT, 'packages', 'protocol', 'src', 'index.js'));

const HUB_PORT = 3123;
const WORLD_PORT = 3124;
const HUB = `http://127.0.0.1:${HUB_PORT}`;
const WORLD = `http://127.0.0.1:${WORLD_PORT}`;
const ADMIN = 'smoke-admin-key-0042';

let pass = 0;
let fail = 0;
const failures = [];
function ok(name, cond, detail) {
  if (cond) pass++;
  else {
    fail++;
    failures.push(name + (detail ? ' :: ' + detail : ''));
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------- 签名工具（与 Dart 端同构：信封 + alg 字段 + base58 公钥） ----------
const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
function base58Encode(buf) {
  let num = 0n;
  for (const b of buf) num = (num << 8n) | BigInt(b);
  let out = '';
  while (num > 0n) {
    out = B58[Number(num % 58n)] + out;
    num /= 58n;
  }
  for (const b of buf) {
    if (b === 0) out = '1' + out;
    else break;
  }
  return out;
}
function rawPubB58(publicKey) {
  const der = publicKey.export({ type: 'spki', format: 'der' });
  return base58Encode(der.subarray(der.length - 32));
}
function newIdentity(agentId) {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  return { agentId, publicKey, privateKey, pubkey: rawPubB58(publicKey) };
}
/** 造一个已签名的信封。payload 里放什么都进签名 ⇒ 测试"改 payload 必须失效"同理。 */
function signed(id, to, payload) {
  const env = {
    proto: 'wold/1',
    type: 'text',
    from: id.agentId,
    to,
    ts: Math.floor(Date.now() / 1000),
    nonce: crypto.randomBytes(8).toString('hex'),
    payload,
    alg: 'ed25519',
  };
  return protocol.envelope.sign(env, { privateKey: id.privateKey });
}
function sigHeader(env) {
  return Buffer.from(JSON.stringify(env)).toString('base64url');
}

async function post(url, env, headers) {
  const r = await fetch(url, {
    method: 'POST',
    headers: Object.assign({ 'Content-Type': 'application/json' }, headers || {}),
    body: JSON.stringify(env),
  });
  const text = await r.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch (_) {}
  return { status: r.status, json, text };
}
async function del(url, headers) {
  const r = await fetch(url, { method: 'DELETE', headers: headers || {} });
  const text = await r.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch (_) {}
  return { status: r.status, json, text };
}
async function getJson(url, headers) {
  const r = await fetch(url, { headers: headers || {} });
  const text = await r.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch (_) {}
  return { status: r.status, json, text };
}
async function waitUp(url, ms) {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline) {
    try {
      const r = await fetch(url);
      if (r.ok) return true;
    } catch (_) {}
    await sleep(120);
  }
  return false;
}

function spawnHub(dataDir, registration) {
  const child = spawn(process.execPath, [HUB_JS], {
    env: Object.assign({}, process.env, {
      PORT: String(HUB_PORT),
      HUB_DATA_DIR: dataDir,
      HUB_ADMIN_KEY: ADMIN,
      HUB_REGISTRATION: registration,
      // 显式清掉：这台机器上若有人设了这个变量，会让"默认关"的断言假红/假绿。
      HUB_KEY_SELF_SERVE: '',
      TRIAL_POOL_FILE: '',
    }),
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.stdout.on('data', () => {});
  child.stderr.on('data', () => {});
  return child;
}
function spawnWorld(dataDir) {
  const child = spawn(process.execPath, [WORLD_JS], {
    env: Object.assign({}, process.env, {
      WORLD_PORT: String(WORLD_PORT),
      WORLD_DATA_DIR: dataDir,
      HUB_DATA_DIR: dataDir,
    }),
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.stdout.on('data', () => {});
  child.stderr.on('data', () => {});
  return child;
}

async function main() {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-adm-'));
  const procs = [];
  try {
    // ============ 第一段：key 模式（官方站形态） ============
    const hub = spawnHub(dataDir, 'key');
    procs.push(hub);
    const up = await waitUp(HUB + '/health', 8000);
    ok('A0 hub 以 key 模式起来了', up);

    const alice = newIdentity('AG-smoke-alice');
    const bob = newIdentity('AG-smoke-bob');

    // ① 无票注册
    const r1 = await post(HUB + '/api/register', signed(alice, 'hub', {
      agent_id: alice.agentId,
      nickname: 'Alice',
      mask_profile: '',
      pubkey: alice.pubkey,
      did: 'did:wold:' + alice.pubkey,
    }));
    ok(
      '① 无票注册被拒（403 registration_key_required）',
      r1.status === 403 && r1.json && r1.json.error === 'registration_key_required',
      r1.status + ' ' + r1.text.slice(0, 120)
    );

    // ② 无管理员凭据签发
    const r2 = await post(HUB + '/api/admin/keys', { n: 1 });
    ok(
      '② 无凭据签发被拒（403 forbidden）',
      r2.status === 403 && r2.json && r2.json.error === 'forbidden',
      r2.status + ' ' + r2.text.slice(0, 120)
    );

    // ③ 管理员签发
    const r3 = await post(HUB + '/api/admin/keys', { n: 1, label: 'smoke' }, { 'X-Admin-Key': ADMIN });
    const issued = r3.json && Array.isArray(r3.json.keys) ? r3.json.keys[0] : null;
    ok(
      '③ 管理员签发成功且返回明文票',
      r3.status === 200 && !!issued && /^WK-/.test(issued.key || ''),
      r3.status + ' ' + r3.text.slice(0, 160)
    );

    // ④ 持票注册
    const r4 = await post(HUB + '/api/register', signed(alice, 'hub', {
      agent_id: alice.agentId,
      nickname: 'Alice',
      mask_profile: '',
      pubkey: alice.pubkey,
      did: 'did:wold:' + alice.pubkey,
      key: issued ? issued.key : '',
    }));
    ok('④ 持票注册成功（200）', r4.status === 200 && r4.json && r4.json.ok === true, r4.status + ' ' + r4.text.slice(0, 160));

    // ⑤ 同一张票给另一个身份
    const r5 = await post(HUB + '/api/register', signed(bob, 'hub', {
      agent_id: bob.agentId,
      nickname: 'Bob',
      mask_profile: '',
      pubkey: bob.pubkey,
      did: 'did:wold:' + bob.pubkey,
      key: issued ? issued.key : '',
    }));
    ok(
      '⑤ 一票一人：同一张票给第二个身份 → 409 key_already_bound',
      r5.status === 409 && r5.json && r5.json.error === 'key_already_bound',
      r5.status + ' ' + r5.text.slice(0, 160)
    );

    // ⑥ 已登记身份重注册（不带票）
    const r6 = await post(HUB + '/api/register', signed(alice, 'hub', {
      agent_id: alice.agentId,
      nickname: 'Alice2',
      mask_profile: '',
      pubkey: alice.pubkey,
      did: 'did:wold:' + alice.pubkey,
    }));
    ok(
      '⑥ 已登记身份不带票重注册 → 200（老用户不会被锁在门外）',
      r6.status === 200,
      r6.status + ' ' + r6.text.slice(0, 160)
    );

    // 票确实被绑到 Alice 身上
    const lst = await getJson(HUB + '/api/admin/keys', { 'X-Admin-Key': ADMIN });
    const rec = lst.json && lst.json.keys ? lst.json.keys[0] : null;
    ok(
      '⑦ 票已绑定到 Alice 且状态可用',
      !!rec && rec.bound_agent_id === alice.agentId && rec.status === 'active',
      JSON.stringify(rec)
    );
    ok(
      '⑦b 列表不回传 hash（凭据影子不外泄）',
      !!lst.json && JSON.stringify(lst.json).indexOf('"hash"') < 0
    );

    // ⑧ 正常发消息（先证明这条链路本来是通的，否则吊销后的 403 说明不了问题）
    const r8 = await post(HUB + '/api/send', signed(alice, bob.agentId, {
      target_id: bob.agentId,
      message: '准入闸冒烟：吊销前的一条',
    }));
    ok('⑧ 吊销前发消息 → 200（基线）', r8.status === 200, r8.status + ' ' + r8.text.slice(0, 160));

    // ⑨ 吊销
    const r9 = await del(HUB + '/api/admin/keys/' + encodeURIComponent(issued ? issued.key_id : ''), {
      'X-Admin-Key': ADMIN,
    });
    ok(
      '⑨ 吊销成功且连带停用绑定身份',
      r9.status === 200 && r9.json && r9.json.ok === true && r9.json.agent_revoked === alice.agentId,
      r9.status + ' ' + r9.text.slice(0, 160)
    );

    // ⑩ 吊销后发消息
    const r10 = await post(HUB + '/api/send', signed(alice, bob.agentId, {
      target_id: bob.agentId,
      message: '准入闸冒烟：吊销后的一条（必须被拒）',
    }));
    ok(
      '⑩ ★ 吊销后发消息 → 403 agent_revoked（邮局真的不收信了）',
      r10.status === 403 && r10.json && r10.json.error === 'agent_revoked',
      r10.status + ' ' + r10.text.slice(0, 160)
    );

    // ⑪ 吊销后再注册
    const r11 = await post(HUB + '/api/register', signed(alice, 'hub', {
      agent_id: alice.agentId,
      nickname: 'Alice',
      mask_profile: '',
      pubkey: alice.pubkey,
      did: 'did:wold:' + alice.pubkey,
    }));
    ok(
      '⑪ 吊销后再注册 → 403 agent_revoked',
      r11.status === 403 && r11.json && r11.json.error === 'agent_revoked',
      r11.status + ' ' + r11.text.slice(0, 160)
    );

    // ⑫ 自助申领默认关
    const r12 = await post(HUB + '/api/key/apply', {});
    ok(
      '⑫ 自助申领默认关闭 → 404（不告诉扫描器"这有个开关"）',
      r12.status === 404,
      r12.status + ' ' + r12.text.slice(0, 120)
    );

    // ============ 第二段：world 侧是否也拦（"双向落"的活体证据） ============
    const carol = newIdentity('AG-smoke-carol');
    const r13 = await post(HUB + '/api/admin/keys', { n: 1, label: 'world' }, { 'X-Admin-Key': ADMIN });
    const wKey = r13.json && r13.json.keys ? r13.json.keys[0] : null;
    const r14 = await post(HUB + '/api/register', signed(carol, 'hub', {
      agent_id: carol.agentId,
      nickname: 'Carol',
      mask_profile: '',
      pubkey: carol.pubkey,
      did: 'did:wold:' + carol.pubkey,
      key: wKey ? wKey.key : '',
    }));
    ok('⑬ Carol 持第二张票注册成功', r14.status === 200, r14.status + ' ' + r14.text.slice(0, 160));

    // hub 的 saveSoon 是 500ms 防抖；world 只读 hub.json ⇒ 必须等它真的落盘再起。
    // （不等会出现"world 起来时文件还不存在"，那不是闸的问题，是这个测试的时序问题。）
    await sleep(900);
    try {
      const raw = JSON.parse(fs.readFileSync(path.join(dataDir, 'hub.json'), 'utf8'));
      ok(
        '⑬b hub.json 已落盘且含 Carol',
        !!raw.agents[carol.agentId],
        Object.keys(raw.agents).join(',')
      );
    } catch (e) {
      ok('⑬b hub.json 可读', false, e.message);
    }

    const world = spawnWorld(dataDir);
    procs.push(world);
    const wUp = await waitUp(WORLD + '/health', 8000);
    ok('A1 world 服务起来了', wUp);

    if (wUp) {
      const joinBody = signed(carol, 'world', { room_id: 'lobby' });
      const r15 = await post(WORLD + '/api/world/join', joinBody);
      ok(
        '⑭ world 加入官方房成功（吊销前基线）',
        r15.status === 200,
        r15.status + ' ' + r15.text.slice(0, 160)
      );
      const r16 = await post(WORLD + '/api/world/say', signed(carol, 'world', {
        room_id: 'lobby',
        message: '准入闸冒烟：吊销前的一句',
      }));
      ok('⑮ world 发言成功（吊销前基线）', r16.status === 200, r16.status + ' ' + r16.text.slice(0, 160));

      const rv = await del(HUB + '/api/admin/keys/' + encodeURIComponent(wKey ? wKey.key_id : ''), {
        'X-Admin-Key': ADMIN,
      });
      ok('⑯ 吊销 Carol 的票', rv.status === 200, rv.status + ' ' + rv.text.slice(0, 120));
      // hub 的 saveSoon 是 500ms 防抖；world 靠 mtime 重读 —— 等它落盘。
      await sleep(900);

      const r17 = await post(WORLD + '/api/world/say', signed(carol, 'world', {
        room_id: 'lobby',
        message: '准入闸冒烟：吊销后的一句（必须被拒）',
      }));
      ok(
        '⑰ ★ world 侧吊销后发言 → 403 agent_revoked（双向落真的生效了）',
        r17.status === 403 && r17.json && r17.json.error === 'agent_revoked',
        r17.status + ' ' + r17.text.slice(0, 160)
      );
    } else {
      ok('⑭ world 起不来 ⇒ 后面三条无从验证', false);
    }
  } finally {
    for (const p of procs) {
      try {
        p.kill('SIGKILL');
      } catch (_) {}
    }
    await sleep(200);
    try {
      fs.rmSync(dataDir, { recursive: true, force: true });
    } catch (_) {}
  }

  // ============ 第三段：open 模式（自建形态）不该被闸挡住 ============
  const dataDir2 = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-adm-open-'));
  let hub2 = null;
  try {
    hub2 = spawnHub(dataDir2, 'open');
    const up = await waitUp(HUB + '/health', 8000);
    ok('A2 以 open 模式（自建形态）起得来', up);
    const dave = newIdentity('AG-smoke-dave');
    const r = await post(HUB + '/api/register', signed(dave, 'hub', {
      agent_id: dave.agentId,
      nickname: 'Dave',
      mask_profile: '',
      pubkey: dave.pubkey,
      did: 'did:wold:' + dave.pubkey,
    }));
    ok(
      '⑱ ★ open 模式新身份免票 → 200（自建开箱即用，闸只加在公共面）',
      r.status === 200,
      r.status + ' ' + r.text.slice(0, 160)
    );
  } finally {
    if (hub2) {
      try {
        hub2.kill('SIGKILL');
      } catch (_) {}
    }
    await sleep(200);
    try {
      fs.rmSync(dataDir2, { recursive: true, force: true });
    } catch (_) {}
  }

  console.log('=== 注册准入闸活体冒烟（ADR-002）===');
  for (const f of failures) console.log('FAIL ' + f);
  console.log(`${pass} PASS / ${fail} FAIL`);
  process.exit(fail === 0 ? 0 : 1);
}

main().catch((e) => {
  console.log('=== 注册准入闸活体冒烟（ADR-002）===');
  console.log('FAIL 冒烟自身异常: ' + (e && e.stack ? e.stack : e));
  console.log(`0 PASS / 1 FAIL`);
  process.exit(1);
});
