// ============================================================
// 世界服务器「卫生闸」冒烟：幽灵成员 / 回合死锁 / 房间回收 / 上限不假满
//
// 为什么要有它：`lib/hub/test-world.js` 只跑"一切正常"的路径 ——
//   · **全体成员都按时发言、从不离开**（所以 turn 轮转永远转得到人）
//   · **房间数远不到上限**（所以 rooms_full 这条路径从没被跑过）
// ⇒ 那两条真实故障路径（幽灵持有发言权 ⇒ 整间房死锁；32 房死限 ⇒ 再也建不了房）
//   在修复前后**都是绿的**，等于没有断言。本脚本专打这两条路径。
//
// 手法：把世界服务器的各种时间窗用环境变量压到几百毫秒，于是"心跳过期 / 订阅回收 /
//   房间闲置"都能在几秒内真实发生，而不是靠 mock。
//
// 运行：node tool/smoke_world_hygiene.js
//   （由 tool/run_all_verify_node.js 自动收录）
// ============================================================
'use strict';

const { spawn } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const HUB_DIR = path.join(ROOT, 'lib', 'hub');
const PORT = 3210;
const BASE = `http://127.0.0.1:${PORT}`;
const SECRET = process.env.SMOKE_SECRET || 'hygiene-secret-0123456789abcdef';
const DATA_DIR = path.join(HUB_DIR, '.test-world-hygiene-data');

// 时间窗（毫秒）——刻意压到几百毫秒，见文件头
const MS_PRESENCE = 500; // 在场窗口：超过它 = 判为"不在场"（但仍是成员）
const MS_EVICT = 1000; // 订阅回收：超过它 = 从 members 移除
const MS_TURN = 400; // turn 超时：在场但静默超时 ⇒ 允许他人强制轮转
const MS_ROOM_UNUSED = 400; // 空壳房间（0 消息）回收
const MS_ROOM_IDLE = 60000; // 用过而冷掉的房间回收（本脚本内实际不会触发）
const MS_MIN_INTERVAL = 250; // 房间最小发言间隔
const MAX_ROOMS = 8;
const MAX_MEMBERS = 2; // 同时在线上限（压到 2，4 个 Agent 内就能撞到）
const MAX_SUBSCRIBERS = 3; // 订阅上限
// ★ 本脚本测的是**回收与上限**，不是可见性。0.40.0 起个人房默认不进列表，
//   若不把这四个 Agent 声明为"官方"，AG-ALICE 就看不到 AG-BOB 建的房 ⇒
//   `names.length === MAX_ROOMS` 之类的断言会因**可见性**而非**回收**失败。
//   （可见性规则本身由 tool/smoke_world_visibility.js 专门钉住。）
const OFFICIAL_AGENTS = 'AG-ALICE,AG-BOB,AG-CAROL,AG-DAVE';
// 同理：每人建房上限默认 3，而本脚本里 AG-ALICE 一个人要建 7 间去撞全局上限。
const MAX_ROOMS_PER_AGENT = 99;

const AGENTS = ['AG-ALICE', 'AG-BOB', 'AG-CAROL', 'AG-DAVE'];

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
fs.writeFileSync(path.join(DATA_DIR, 'hub.json'), JSON.stringify({ agents, messages: [], seq: 0 }, null, 2));

// ---------- 签名信封（与 App 端 AgentProtocol / test-world.js 同构） ----------
function buildEnvelope(fromId, toId, payload, { proto = 'wold/1' } = {}) {
  const body = {
    proto,
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
    WORLD_MEMBER_EVICT_MS: String(MS_EVICT),
    WORLD_TURN_TIMEOUT_MS: String(MS_TURN),
    WORLD_ROOM_UNUSED_TTL_MS: String(MS_ROOM_UNUSED),
    WORLD_ROOM_IDLE_TTL_MS: String(MS_ROOM_IDLE),
    WORLD_MAX_ROOMS: String(MAX_ROOMS),
    WORLD_MAX_MEMBERS: String(MAX_MEMBERS),
    WORLD_MAX_SUBSCRIBERS: String(MAX_SUBSCRIBERS),
    WORLD_OFFICIAL_AGENTS: OFFICIAL_AGENTS,
    WORLD_MAX_ROOMS_PER_AGENT: String(MAX_ROOMS_PER_AGENT),
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

const post = (p, fromId, payload) =>
  fetch(`${BASE}${p}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(buildEnvelope(fromId, 'world', payload)),
  });
const get = (p, fromId) =>
  fetch(`${BASE}${p}`, { headers: { 'X-Agent-Sig': sigHeader(buildEnvelope(fromId, 'world', {})) } });
const jpost = async (p, fromId, payload) => {
  const r = await post(p, fromId, payload);
  let body = null;
  try {
    body = await r.json();
  } catch (_) {
    /* 空响应 */
  }
  return { status: r.status, body };
};
const jget = async (p, fromId) => {
  const r = await get(p, fromId);
  let body = null;
  try {
    body = await r.json();
  } catch (_) {
    /* 空响应 */
  }
  return { status: r.status, body };
};
const createRoom = (id, mode) =>
  jpost('/api/world/create', 'AG-ALICE', { room_id: id, name: id, topic: '', mode });
const say = (fromId, roomId, message) => jpost('/api/world/say', fromId, { room_id: roomId, message });
const join = (fromId, roomId) => jpost('/api/world/join', fromId, { room_id: roomId });
const roomNames = async (fromId = 'AG-ALICE') => {
  const r = await jget('/api/world/rooms', fromId);
  return (r.body && r.body.rooms ? r.body.rooms : []).map((x) => x.id);
};

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

    // ---------- 0. 基线：health 报"在场"数 ----------
    let r = await jget('/health', 'AG-ALICE');
    check('health 上报在场数 present', r.status === 200 && typeof r.body.present === 'number', r.body);

    // ---------- 1. turn 幽灵死锁：由 feed（每 5s 轮询）自愈 ----------
    await createRoom('hyg_dead_feed', 'turn');
    await join('AG-ALICE', 'hyg_dead_feed');
    await join('AG-BOB', 'hyg_dead_feed');
    let s = await say('AG-ALICE', 'hyg_dead_feed', '我先开题');
    check('turn 首条发言把发言权交给 Bob', s.status === 200 && s.body.next_speaker === 'AG-BOB', s.body);

    // ★ Bob 静默离线（**不发 leave** —— 这正是 App 被杀进程时的真实状态）
    await wait(MS_PRESENCE + 200);
    r = await jget('/api/world/feed?after=0', 'AG-ALICE');
    check(
      '★幽灵死锁：feed 把发言权自愈给在场者（修复前恒为 AG-BOB，整间房卡死）',
      r.status === 200 && r.body.next_speakers['hyg_dead_feed'] === 'AG-ALICE',
      r.body.next_speakers
    );

    // ---------- 2. turn 幽灵死锁：由 say 自愈（不依赖 feed） ----------
    await createRoom('hyg_dead_say', 'turn');
    await join('AG-ALICE', 'hyg_dead_say');
    await join('AG-BOB', 'hyg_dead_say');
    await say('AG-ALICE', 'hyg_dead_say', '开题');
    await wait(MS_PRESENCE + 200);
    await join('AG-ALICE', 'hyg_dead_say'); // 回到房间页 = 心跳（App 的真实行为）
    s = await say('AG-ALICE', 'hyg_dead_say', 'Bob 不在，我接着说');
    check(
      '★幽灵死锁：say 当场改派并放行（修复前恒 409 not_your_turn）',
      s.status === 200 && s.body.next_speaker === 'AG-ALICE',
      s.body
    );

    // ---------- 3. turn AFK：人在场但一直不说话 ----------
    await createRoom('hyg_afk', 'turn');
    await join('AG-ALICE', 'hyg_afk');
    await join('AG-BOB', 'hyg_afk');
    await say('AG-ALICE', 'hyg_afk', '开题');
    await wait(200);
    await join('AG-BOB', 'hyg_afk'); // 双方心跳：都保持在场
    await join('AG-ALICE', 'hyg_afk');
    await wait(MS_TURN - 100); // 静默已超 TURN_TIMEOUT，但两边都还在场
    // ★ 先钉住前提："双方都在场"。否则这条断言会退化成和第 1/2 条一样
    //   （分不清救场的到底是"在场自愈"还是"AFK 超时"，两个机制都没被独立证到）
    const afkRoom = (await jget('/api/world/rooms', 'AG-ALICE')).body.rooms.find((x) => x.id === 'hyg_afk');
    check(
      'AFK 场景前提成立：双方都【在场】（所以救场的是"超时"，不是"离场"）',
      afkRoom && afkRoom.present_count === 2,
      afkRoom
    );
    s = await say('AG-ALICE', 'hyg_afk', '轮到 Bob 但他一直不说话，我强制轮转');
    // ⚠️ 这里只断言"被放行"：turn 模式下**发言成功后还会再轮转一次**，
    //    所以响应里的 next_speaker 是"我的下一位"，不是"当场被改派给谁"。
    check(
      '★AFK 占位：在场但静默超时 ⇒ 强制轮转放行（修复前恒 409，一张椅子占死整间房）',
      s.status === 200,
      s.body
    );

    // ---------- 4. 上限：同时在线 vs 订阅（幽灵不占位） ----------
    await createRoom('hyg_cap', 'free');
    await join('AG-ALICE', 'hyg_cap');
    await join('AG-BOB', 'hyg_cap');
    await say('AG-ALICE', 'hyg_cap', '留一条消息，让本房间走"冷房"TTL 而不是"空壳"TTL');
    r = await join('AG-CAROL', 'hyg_cap');
    check(
      `room_full：${MAX_MEMBERS} 人同时在线即拒绝新人`,
      r.status === 400 && r.body.error === 'room_full',
      r.body
    );

    await wait(MS_PRESENCE + 200); // Alice/Bob 变成"不在场"（但仍是订阅者）
    r = await join('AG-CAROL', 'hyg_cap');
    check(
      '★幽灵不占位：离线订阅者不再把房间对新人锁死',
      r.status === 200 && r.body.room.present_count === 1,
      r.body
    );
    r = await join('AG-DAVE', 'hyg_cap');
    check(
      `subscribers_full：订阅数达 ${MAX_SUBSCRIBERS} 时另给一码（成本边界，与"在线满"区分开）`,
      r.status === 400 && r.body.error === 'subscribers_full',
      r.body
    );

    await wait(MS_EVICT + 300); // 订阅超期
    await roomNames(); // /rooms 触发 gcRooms（回收弃用订阅）
    r = await join('AG-DAVE', 'hyg_cap');
    check('★弃用订阅被回收后，房间重新可加入（不是死房间）', r.status === 200, r.body);

    // ---------- 5. 房间回收：空壳快清 / 用过留久 / lobby 不死 ----------
    await createRoom('hyg_junk', 'free'); // 无消息、无人加入
    await createRoom('hyg_used', 'free');
    await join('AG-ALICE', 'hyg_used');
    await say('AG-ALICE', 'hyg_used', '这条消息让本房间进入"冷房"TTL');
    await wait(MS_ROOM_UNUSED + 300);
    let names = await roomNames();
    check('★空壳房间（从没人用过）已被回收', !names.includes('hyg_junk'), names);
    check('用过而冷掉的房间保留（TTL 更长，回来还能看历史）', names.includes('hyg_used'), names);
    check('默认客厅 lobby 永不回收', names.includes('lobby'), names);

    // ---------- 6. rooms_full 不是死限（唯一的删房路径就是回收） ----------
    let full = false;
    let lastErr = null;
    for (let i = 0; i < MAX_ROOMS + 6 && !full; i++) {
      const filler = i % 2 === 0 ? 'AG-ALICE' : 'AG-BOB';
      const rid = `hyg_fill_${i}`;
      const rr = await jpost('/api/world/create', filler, {
        room_id: rid,
        name: 'fill',
        topic: '',
        mode: 'free',
      });
      if (rr.status === 200) {
        // ★ 建房者真的进房在场：这样这批房间不会被"空壳 TTL"随机提前回收，
        //   上限判定就只由 MAX_ROOMS 决定（否则计数随 GC 抖动，断言本身就不稳）
        await join(filler, rid);
        continue;
      }
      lastErr = rr.body;
      if (rr.body && rr.body.error === 'rooms_full') full = true;
      else check(`建房未预期失败: ${JSON.stringify(rr.body)}`, false, rr.body);
    }
    check(`rooms_full 上限确实生效（上限 ${MAX_ROOMS}）`, full, { full, lastErr });
    names = await roomNames();
    // 此刻计数恰好顶到上限 —— 这就是"满"的定义。真正的回归断言是下一条：
    // 同一个请求在闲置房间被回收后必须重新成功（修复前是**永久** 400）。
    check(`✱ 上限按真实计数生效（此刻房间数 = ${MAX_ROOMS}）`, names.length === MAX_ROOMS, {
      n: names.length,
      names,
    });

    await wait(MS_PRESENCE + MS_ROOM_UNUSED + 300); // 建房者离场 + 空壳超 TTL
    r = await createRoom('hyg_after_gc', 'free');
    check(
      '★rooms_full 不是死限：闲置空壳回收后建房立刻恢复（修复前永远 400）',
      r.status === 200,
      r.body
    );
  } catch (e) {
    console.error('TEST ERROR:', e && e.stack ? e.stack : e);
    failed++;
  } finally {
    child.kill();
    console.log(`\n${passed} PASS / ${failed} FAIL`);
    console.log(failed === 0 ? '🎉 世界服务器卫生闸冒烟全部通过' : `💥 ${failed} 项未通过`);
    console.log('--- world logs（尾部）---');
    console.log(logs.split('\n').slice(-25).join('\n'));
    setTimeout(() => process.exit(failed === 0 ? 0 : 1), 150);
  }
})();
