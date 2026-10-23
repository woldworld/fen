// ============================================================
// 世界服务器「房间可见性 + 加入审批 + 按房回填历史」冒烟（QQ 群模式）
//
// 为什么要有它（2026-10-03 主人真机反馈）：
//   · "每个人都建一个房间，岂不有无数的房间？" ⇒ 个人房**不该**出现在全员列表里，
//     只能凭房间号（群号）找到 → 申请 → 房主同意 → 才能进；只有官方房全员可见。
//   · "加入房间后，有的手机能加载很多历史，另一台一条都没有" ⇒ feed 用全局单调游标，
//     后进房的人游标早已越过本房历史 id，永远拉不到 ⇒ 必须有**按房**的回填端点。
//   这两条规则此前**一条都没有断言**（列表返回全部房间 / 没有按房端点），
//   改坏了也不会有任何脚本变红 —— 本脚本专打这两条路径。
//
// 手法：与 smoke_world_hygiene.js 同款 harness（压时间窗 + HMAC 签名信封 + 起真服务）。
//
// 运行：node tool/smoke_world_visibility.js
//   （由 tool/run_all_verify_node.js 自动收录）
// ============================================================
'use strict';

const { spawn } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const HUB_DIR = path.join(ROOT, 'lib', 'hub');
const PORT = 3211;
const BASE = `http://127.0.0.1:${PORT}`;
const SECRET = process.env.SMOKE_SECRET || 'visibility-secret-0123456789abcdef';
const DATA_DIR = path.join(HUB_DIR, '.test-world-visibility-data');

const MS_PRESENCE = 3000; // 在场窗口（本脚本不测回收，给宽松值）
const MS_MIN_INTERVAL = 150; // 房间最小发言间隔（压到极小，好连续发言）
const MAX_ROOMS_PER_AGENT = 2; // 每人建房上限（第 15 条就撞它）

const AGENTS = ['AG-ALICE', 'AG-BOB', 'AG-CAROL', 'AG-OFF'];

// ---------- 预置 Hub 注册库（世界服只读复用） ----------
fs.rmSync(DATA_DIR, { recursive: true, force: true });
fs.mkdirSync(DATA_DIR, { recursive: true });
const agents = {};
for (const id of AGENTS) {
  agents[id] = {
    agent_id: id,
    nickname: id.replace('AG-', ''),
    mask_profile: '测试人设',
    secret: SECRET,
    registered_at: Date.now(),
    last_seen: Date.now(),
  };
}
fs.writeFileSync(
  path.join(DATA_DIR, 'hub.json'),
  JSON.stringify({ agents, messages: [], seq: 0 }, null, 2)
);

// ---------- 签名信封（与 App 端 AgentProtocol / test-world.js 同构） ----------
function buildEnvelope(fromId, toId, payload) {
  const body = {
    proto: 'wold/1',
    type: payload.kind || 'text',
    from: fromId,
    to: toId,
    ts: Math.floor(Date.now() / 1000),
    nonce: crypto.randomBytes(8).toString('hex'),
    payload,
  };
  body.sig = crypto.createHmac('sha256', SECRET).update(JSON.stringify(body), 'utf8').digest('hex');
  return body;
}
const sigHeader = (env) => Buffer.from(JSON.stringify(env)).toString('base64url');

const child = spawn(process.execPath, ['world.js'], {
  env: {
    ...process.env,
    WORLD_PORT: String(PORT),
    WORLD_DATA_DIR: DATA_DIR,
    WORLD_ROOM_MIN_INTERVAL_MS: String(MS_MIN_INTERVAL),
    WORLD_CAP_PER_MEMBER_HOUR: '200',
    WORLD_MEMBER_PRESENCE_MS: String(MS_PRESENCE),
    // ★ 只有 AG-OFF 是"官方"：它建的房全员可见，其余人的房一律私有
    WORLD_OFFICIAL_AGENTS: 'AG-OFF',
    WORLD_MAX_ROOMS_PER_AGENT: String(MAX_ROOMS_PER_AGENT),
    WORLD_MAX_ROOMS: '16',
  },
  cwd: HUB_DIR,
  stdio: ['ignore', 'pipe', 'pipe'],
});
let logs = '';
child.stdout.on('data', (d) => (logs += d));
child.stderr.on('data', (d) => (logs += d));

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

let passed = 0;
let failed = 0;
function check(name, cond, detail) {
  console.log(`${cond ? '✅' : '❌'} ${name}${cond ? '' : '  => ' + JSON.stringify(detail)}`);
  if (cond) passed++;
  else failed++;
}

const jpost = async (p, fromId, payload) => {
  const r = await fetch(`${BASE}${p}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(buildEnvelope(fromId, 'world', payload)),
  });
  let body = null;
  try {
    body = await r.json();
  } catch (_) {
    /* 空响应 */
  }
  return { status: r.status, body };
};
const jget = async (p, fromId) => {
  const r = await fetch(`${BASE}${p}`, {
    headers: { 'X-Agent-Sig': sigHeader(buildEnvelope(fromId, 'world', {})) },
  });
  let body = null;
  try {
    body = await r.json();
  } catch (_) {
    /* 空响应 */
  }
  return { status: r.status, body };
};
const create = (fromId, roomId) =>
  jpost('/api/world/create', fromId, { room_id: roomId, name: roomId, topic: '', mode: 'free' });
const say = (fromId, roomId, message) =>
  jpost('/api/world/say', fromId, { room_id: roomId, message });
const join = (fromId, roomId) => jpost('/api/world/join', fromId, { room_id: roomId });
const request = (fromId, roomId, note) =>
  jpost('/api/world/request', fromId, { room_id: roomId, note: note || '' });
const getRoom = (fromId, roomId) => jget(`/api/world/room?room_id=${roomId}`, fromId);
const rooms = async (fromId) => {
  const r = await jget('/api/world/rooms', fromId);
  return (r.body && r.body.rooms ? r.body.rooms : []);
};
const findRoom = async (fromId, roomId) => (await rooms(fromId)).find((x) => x.id === roomId);

(async () => {
  try {
    // 等待就绪
    let up = false;
    for (let i = 0; i < 40 && !up; i++) {
      try {
        const r = await fetch(`${BASE}/health`);
        up = r.status === 200;
      } catch (_) {
        /* 还没起来 */
      }
      if (!up) await wait(100);
    }
    check('世界服务器已就绪', up, logs.slice(-400));

    // ---------- 0. 基线：默认客厅是官方房，全员可见 ----------
    let lobby = await findRoom('AG-BOB', 'lobby');
    check('默认客厅 lobby 是官方房且对所有人可见', lobby && lobby.official === true, lobby);

    // ---------- 1. 个人房：建房者自己可见，别人不可见 ----------
    let r = await create('AG-ALICE', 'vis_private');
    check('建房成功', r.status === 200, r.body);
    check(
      '★建房者是房主且自动入内（此前建完自己都进不去）',
      r.body && r.body.room && r.body.room.i_am_owner === true && r.body.room.i_am_member === true,
      r.body
    );
    check(
      '★个人房默认不公开（official=false）',
      r.body && r.body.room && r.body.room.official === false,
      r.body
    );

    let aliceSees = await findRoom('AG-ALICE', 'vis_private');
    check('房主自己的列表里能看到它（否则再也回不去自己的房）', !!aliceSees, aliceSees);

    let bobSees = await findRoom('AG-BOB', 'vis_private');
    check(
      '★核心规则：个人房**不出现在其他人**的房间列表里（修复前这里有它）',
      bobSees === undefined,
      bobSees
    );

    // ---------- 2. 凭房间号可以精确找到（QQ 群号） ----------
    r = await getRoom('AG-BOB', 'vis_private');
    check(
      '★按房间号能查到个人房（这是"申请加入"的唯一入口）',
      r.status === 200 && r.body.room.id === 'vis_private',
      r.body
    );
    check(
      '非成员查得到房间，但拿不到历史消息',
      r.status === 200 && Array.isArray(r.body.messages) && r.body.messages.length === 0,
      r.body
    );
    r = await getRoom('AG-BOB', 'no_such_room_zz');
    check('查不到的房间号如实 404（不返回一个空壳）', r.status === 404 && r.body.error === 'room_not_found', r.body);

    // ---------- 3. 直接 join 被拒，必须申请 ----------
    r = await join('AG-BOB', 'vis_private');
    check('★未获批准直接 join ⇒ 403 need_approval', r.status === 403 && r.body.error === 'need_approval', r.body);

    // ---------- 4. 申请 → 房主可见 → 重复申请不占位 ----------
    r = await request('AG-BOB', 'vis_private', '我想进来聊聊');
    check('★申请加入成功（pending）', r.status === 200 && r.body.pending === true, r.body);
    r = await request('AG-BOB', 'vis_private', '再来一次');
    check('重复申请幂等（仍是一条，不报错）', r.status === 200 && r.body.pending === true, r.body);

    let bobPending = await findRoom('AG-BOB', 'vis_private');
    check(
      '★我已申请的房会出现在我的列表里（带 request_pending 标记）',
      bobPending && bobPending.request_pending === true,
      bobPending
    );
    r = await getRoom('AG-ALICE', 'vis_private');
    check('房主看到待审批数 = 1', r.status === 200 && r.body.room.pending_count === 1, r.body && r.body.room);
    r = await getRoom('AG-BOB', 'vis_private');
    check('非房主拿不到待审批数（不给不相干的人报数）', r.status === 200 && r.body.room.pending_count === 0, r.body && r.body.room);

    // ---------- 5. 非房主审批 ⇒ 403 ----------
    r = await jpost('/api/world/handle', 'AG-BOB', {
      room_id: 'vis_private',
      agent_id: 'AG-BOB',
      action: 'approve',
    });
    check('★非房主审批自己 ⇒ 403 not_owner（审批权只认 owner）', r.status === 403 && r.body.error === 'not_owner', r.body);

    // ---------- 6. 房主看到申请列表并同意 ----------
    r = await jget('/api/world/requests', 'AG-ALICE');
    check(
      '房主能列出待审批申请',
      r.status === 200 && r.body.requests.length === 1 && r.body.requests[0].agent_id === 'AG-BOB',
      r.body
    );
    r = await jget('/api/world/requests', 'AG-CAROL');
    check('非房主列不到别人的申请（一条都没有）', r.status === 200 && r.body.requests.length === 0, r.body);

    r = await jpost('/api/world/handle', 'AG-ALICE', {
      room_id: 'vis_private',
      agent_id: 'AG-BOB',
      action: 'approve',
    });
    check('★房主同意 ⇒ 申请人直接成为成员', r.status === 200 && r.body.approved === true, r.body);
    bobPending = await findRoom('AG-BOB', 'vis_private');
    check('同意后申请标记消失、已成为成员', bobPending && bobPending.i_am_member === true && bobPending.request_pending === false, bobPending);

    // ---------- 7. 官方房：全员可见、免审批 ----------
    r = await create('AG-OFF', 'vis_official');
    check('官方 Agent 建的房是官方房', r.status === 200 && r.body.room.official === true, r.body);
    let carolSees = await findRoom('AG-CAROL', 'vis_official');
    check('★官方房对全员可见', !!carolSees && carolSees.official === true, carolSees);
    r = await request('AG-CAROL', 'vis_official');
    check('★官方房免审批：申请即直接进（joined=true）', r.status === 200 && r.body.joined === true, r.body);

    // ---------- 8. 按房回填历史（"另一台手机一条历史都没有"的正面解药） ----------
    await say('AG-ALICE', 'vis_private', '历史第一条');
    await wait(MS_MIN_INTERVAL + 30);
    await say('AG-ALICE', 'vis_private', '历史第二条');

    // 模拟"后进房的人游标已经越顶"：用一个很大的 after
    r = await jget('/api/world/feed?after=999999', 'AG-BOB');
    check(
      '前提成立：全局游标越顶后 feed 一条都拿不到（这正是真机故障的成因）',
      r.status === 200 && r.body.messages.length === 0,
      r.body && r.body.messages
    );
    r = await getRoom('AG-BOB', 'vis_private');
    check(
      '★按房回填拿得到历史（不看游标）',
      r.status === 200 && r.body.messages.length === 2 && r.body.messages[0].message === '历史第一条',
      r.body && r.body.messages
    );
    check(
      '回填如实报保留口径（retained / max_kept / truncated）',
      r.status === 200 &&
        r.body.retained === 2 &&
        typeof r.body.max_kept === 'number' &&
        r.body.truncated === false,
      { retained: r.body && r.body.retained, max_kept: r.body && r.body.max_kept }
    );

    // ---------- 9. 每人建房上限 ----------
    await create('AG-ALICE', 'vis_alice_2'); // 第 2 间（上限 2）
    r = await create('AG-ALICE', 'vis_alice_3');
    check(
      `★每人建房上限生效（${MAX_ROOMS_PER_AGENT}）：第 3 间被拒 my_rooms_full`,
      r.status === 400 && r.body.error === 'my_rooms_full',
      r.body
    );
    r = await create('AG-BOB', 'vis_bob_1');
    check('上限是"每人"而不是"全局"：别人仍能建', r.status === 200, r.body);

    // ---------- 10. 拒绝路径 ----------
    await request('AG-CAROL', 'vis_bob_1');
    r = await jget('/api/world/requests?room_id=vis_bob_1', 'AG-BOB');
    check('房主可按房间过滤申请', r.status === 200 && r.body.requests.length === 1, r.body);
    r = await jpost('/api/world/handle', 'AG-BOB', {
      room_id: 'vis_bob_1',
      agent_id: 'AG-CAROL',
      action: 'reject',
    });
    check('★房主拒绝 ⇒ 申请被删、仍未入内', r.status === 200 && r.body.rejected === true, r.body);
    r = await jget('/api/world/requests?room_id=vis_bob_1', 'AG-BOB');
    check('拒绝后申请列表清空', r.status === 200 && r.body.requests.length === 0, r.body);
    r = await join('AG-CAROL', 'vis_bob_1');
    check('被拒绝后仍然进不去（拒绝不是"静默放行"）', r.status === 403 && r.body.error === 'need_approval', r.body);

    // ---------- 11. 房主手动关闭房间（**仅房主** · 留档只读） ----------
    //
    // 为什么用**官方房**验"退出公开列表"：官方房关闭前对全员可见、关闭后应只对
    // 成员/房主可见 —— 用私有房验不出这条（私有房本来就不可见，关了也还是不可见）。
    await create('AG-OFF', 'vis_close_official');
    let carolBefore = await findRoom('AG-CAROL', 'vis_close_official');
    check('前提成立：官方房关闭前对非成员可见', !!carolBefore && carolBefore.official === true, carolBefore);

    // 关闭权只认 owner：服务端重新查 owner，客户端字段一律不算数
    r = await jpost('/api/world/close', 'AG-CAROL', { room_id: 'vis_close_official' });
    check('★非房主关闭 ⇒ 403 not_owner（关闭权只认 owner）', r.status === 403 && r.body.error === 'not_owner', r.body);
    r = await jpost('/api/world/close', 'AG-CAROL', { room_id: 'vis_private' });
    check('★拿别人的房号也关不掉（房号不能越权）', r.status === 403 && r.body.error === 'not_owner', r.body);
    r = await jpost('/api/world/close', 'AG-OFF', { room_id: 'lobby' });
    check('★内置客厅 lobby 关不掉（owner=system，无任何 Agent 持有）', r.status === 403, r.body);

    // 房主关闭 ⇒ 200，转只读留档；重复关闭幂等
    r = await jpost('/api/world/close', 'AG-OFF', { room_id: 'vis_close_official' });
    check('★房主关闭成功（closed=true）', r.status === 200 && r.body.closed === true, r.body);
    check(
      '关闭后房间摘要带 closed 标记',
      r.body && r.body.room && r.body.room.closed === true && r.body.room.closed_at > 0,
      r.body && r.body.room
    );
    r = await jpost('/api/world/close', 'AG-OFF', { room_id: 'vis_close_official' });
    check('重复关闭幂等（already_closed，不报错）', r.status === 200 && r.body.already_closed === true, r.body);

    // 退出公开列表：非成员看不到，房主/成员仍看得到（留档可回看）
    let carolAfter = await findRoom('AG-CAROL', 'vis_close_official');
    check('★关闭后房间退出公开列表（非成员看不到）', carolAfter === undefined, carolAfter);
    let offSees = await findRoom('AG-OFF', 'vis_close_official');
    check('房主自己的列表里仍看得到（留档可回看）', !!offSees && offSees.closed === true, offSees);

    // 拒收一切产生新动作的写路径：发言 / 加入 / 申请
    r = await jpost('/api/world/say', 'AG-OFF', {
      room_id: 'vis_close_official',
      message: '关闭后不该能说话',
    });
    check('★关闭后拒收发言 ⇒ 403 room_closed', r.status === 403 && r.body.error === 'room_closed', r.body);
    r = await join('AG-CAROL', 'vis_close_official');
    check('★关闭后拒收新加入 ⇒ 403 room_closed', r.status === 403 && r.body.error === 'room_closed', r.body);
    r = await request('AG-CAROL', 'vis_close_official');
    check('关闭后"申请加入"也一并被拒 ⇒ room_closed', r.status === 403 && r.body.error === 'room_closed', r.body);

    // 成员在 feed 里收到"房间已关闭"的系统消息；feed 如实回报 closed_rooms
    r = await jget('/api/world/feed?after=0', 'AG-OFF');
    check(
      '★feed 回报已关闭房间 id（客户端据此 5s 内自动切只读）',
      r.status === 200 &&
        Array.isArray(r.body.closed_rooms) &&
        r.body.closed_rooms.includes('vis_close_official'),
      r.body && r.body.closed_rooms
    );
    const sysMsg = (r.body.messages || []).find((m) => m.kind === 'room_closed');
    check(
      '★成员在 feed 里收到"房间已关闭"系统消息（sender=system，带 kind）',
      !!sysMsg && sysMsg.sender_id === 'system' && sysMsg.room_id === 'vis_close_official',
      sysMsg
    );

    // 留档只读：关闭后成员仍能按房读回历史（这是"留档"二字的正面证据）
    await wait(MS_MIN_INTERVAL + 30);
    await say('AG-ALICE', 'vis_private', '关闭前的最后一条');
    r = await jpost('/api/world/close', 'AG-ALICE', { room_id: 'vis_private' });
    check('房主关闭自己的私有房成功', r.status === 200 && r.body.closed === true, r.body);
    let bobAfter = await findRoom('AG-BOB', 'vis_private');
    check('★关闭后**已加入成员**仍在列表里看到它（留档可回看）', !!bobAfter && bobAfter.closed === true, bobAfter);
    r = await getRoom('AG-BOB', 'vis_private');
    check(
      '★留档只读：成员按房查询仍读得到关闭前的历史',
      r.status === 200 &&
        r.body.room.closed === true &&
        r.body.messages.some((m) => m.message === '关闭前的最后一条'),
      r.body && r.body.room
    );
  } catch (e) {
    console.error('TEST ERROR:', e && e.stack ? e.stack : e);
    failed++;
  } finally {
    child.kill();
    console.log(`\n${passed} PASS / ${failed} FAIL`);
    console.log(failed === 0 ? '🎉 房间可见性与加入审批冒烟全部通过' : `💥 ${failed} 项未通过`);
    console.log('--- world logs（尾部）---');
    console.log(logs.split('\n').slice(-25).join('\n'));
    setTimeout(() => process.exit(failed === 0 ? 0 : 1), 150);
  }
})();
