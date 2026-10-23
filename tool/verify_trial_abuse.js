#!/usr/bin/env node
// ============================================================
// 守卫：试用代调（免费 20 轮）的滥用面
//
// 为什么单独一个守卫：2026-10-21 复查发现这条链上的问题**全是"装了闸但形态不对"**，
// 而且都**在开发机上测不出来**：
//   ① `clientIp` 只认 TCP 对端 —— 但官方推荐的部署形态（Caddy / Cloudflare 隧道）
//      对端恒为 127.0.0.1 ⇒ 每 IP 限流退化成"全站一个桶"（实测：三个不同 XFF 的
//      请求共用同一计数键，第 3 个就 429）。原注释还写着"限得松一点好过形同虚设"，
//      方向是反的。
//   ② 试用端点的 Bearer 只做格式正则：不查在册、不查吊销 ⇒ ADR-002 的"吊销覆盖
//      全部消费路径"在旁路上不成立；客户端还回退常量 `AG-TRIAL` ⇒ 全站共用 20 轮。
//   ③ `db.trial_used` 是**持久表**且没人清 ⇒ 每换一个编造 ID 就多一条永不消失的记录。
//   ④ 池里账号被上游判死是**永久标记**，但全仓没有解除入口（换 key 也没用）。
//   ⑤ 池文件写坏只是 console.error，用户端只看到"服务未配置"⇒ 与"没开"不可区分。
//
// 本脚本两组判据：
//   A–D 静态切片（接线是否还在）；
//   E   **真起 hub + 假上游**跑行为（判据非恒真的唯一办法）。
//
// 用法：node tool/verify_trial_abuse.js
// ============================================================
'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const cp = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const HUB = path.join(ROOT, 'lib', 'hub', 'hub.js');
const INSTALL = path.join(ROOT, 'lib', 'hub', 'deploy', 'install-server.ps1');
const README = path.join(ROOT, 'lib', 'hub', 'README.md');

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
function read(p) {
  return fs.readFileSync(p, 'utf8');
}
function slice(text, start, end) {
  const i = text.indexOf(start);
  if (i < 0) return '';
  const j = end ? text.indexOf(end, i) : -1;
  return j < 0 ? text.slice(i) : text.slice(i, j);
}

const hubSrc = read(HUB);
const installSrc = read(INSTALL).replace(/^\uFEFF/, '');
const readmeSrc = read(README);

// ============ A. 来源识别（P0-1：反代后不能退化成全站一个桶） ============
const ipFn = slice(hubSrc, 'const TRUST_PROXY =', 'function anonReadLimit(req)');
ok('A1 有显式开关 HUB_TRUST_PROXY（默认 off）', /process\.env\.HUB_TRUST_PROXY \|\| 'off'/.test(ipFn));
ok(
  'A2 ★ 只在**对端是回环**时才采信转发头（直连公网时伪造 XFF 无效）',
  ipFn.includes('isLoopbackAddr(peer)') && ipFn.includes('forwardedClientIp'),
  '若改成无条件采信 XFF，限流开关就交到攻击者手里了'
);
ok(
  'A3 ★ XFF 取**最右一跳**（反代是追加到末尾的；最左那段客户端可伪造）',
  ipFn.includes('xff[xff.length - 1]'),
  '取最左 = 白送一个绕过'
);
ok('A4 非法取值要吵出来（不许静默当 off）', /不是合法值/.test(ipFn));
ok('A5 启动日志打出当前来源识别模式', hubSrc.includes('来源识别: '));
ok(
  'A6 一键部署生成的 run-hub.cmd 显式写 HUB_TRUST_PROXY=loopback（该包配套 Caddy 反代）',
  /set HUB_TRUST_PROXY=loopback/.test(installSrc)
);
ok(
  'A7 README 有反代说明（7.3 + 变量名），否则运营方不知道要开',
  readmeSrc.includes('HUB_TRUST_PROXY=loopback') && readmeSrc.includes('### 7.3')
);

// ============ B. 试用身份（P0-2：吊销 / 占位常量 / 编造 ID） ============
const resolveFn = slice(hubSrc, 'function resolveTrialIdentity(req)', '// ---------- 任意注册 Agent 的签名头鉴权');
ok('B1 身份判定有唯一实现 resolveTrialIdentity', resolveFn.length > 800, String(resolveFn.length));
ok(
  'B2 ★ 已登记身份要查吊销（ADR-002「吊销覆盖全部消费路径」）',
  /\bif \(isRevoked\(known\)\)/.test(resolveFn) && resolveFn.includes("error: 'agent_revoked'")
);
// ★ 身份解析层返回的每个状态码都必须在客户端 statusToFailure 的 8 类里，
//   否则那一类失败会退化成「网络接口发生异常」（吊销曾误用 403 就是这个坑）。
//   ⚠️ 必须是**独立**的 ok()：写成上一个 ok() 的第三个参数会变成 detail，
//   只被求值不断言 —— 本脚本上一版就这么错过一次。
const RESOLVE_CODES = [...resolveFn.matchAll(/code: (\d{3})/g)].map((m) => m[1]);
const CLIENT_CODES = ['400', '401', '402', '413', '415', '429', '502', '503'];
ok(
  'B2b ★ 身份解析层的状态码全部在客户端 8 类表内',
  RESOLVE_CODES.length > 0 && RESOLVE_CODES.every((c) => CLIENT_CODES.includes(c)),
  RESOLVE_CODES.join(',')
);
ok(
  'B3 ★ 占位常量 AG-TRIAL 按出口 IP 哈希分桶，不再当"一个用户"',
  resolveFn.includes("claim === 'AG-TRIAL'") && resolveFn.includes('ipQuotaKey(clientIp(req))')
);
ok(
  'B4 ★ 未登记身份自动建档 + 每网段每日上限（编造 ID 不再是零成本）',
  resolveFn.includes('db.trial_enrolled[claim]') &&
    resolveFn.includes('TRIAL_IDS_PER_IP') &&
    resolveFn.includes("error: 'trial_identity_limited'")
);
ok(
  'B5 建档只落网段（maskIp），不落完整 IP',
  resolveFn.includes('maskIp(clientIp(req))') && !/db\.trial_enrolled\[claim\] = \{[^}]*ip:/.test(resolveFn)
);
const regBlock = slice(hubSrc, "pathname === '/api/trial/chat/completions'", '// 额度余量查询');
ok(
  'B6 ★ 端点只从 resolveTrialIdentity 取身份（不许再就地做正则判定，两处判定迟早分叉）',
  regBlock.includes('resolveTrialIdentity(req)') && !/\^AG-\[A-Za-z0-9\]\{4,32\}\$/.test(regBlock)
);
ok(
  'B7 端点按 quotaKey 计数与写回（不是原始 Bearer 串）',
  regBlock.includes('db.trial_used[trialId.quotaKey]') && !regBlock.includes('db.trial_used[trialAgent]')
);
const quotaBlock = slice(hubSrc, "pathname === '/api/trial/quota'", 'return sendJson(res, 404');
ok(
  'B8 ★ 余量查询与计数同口径（AG-TRIAL 也走 ipQuotaKey，否则永远读 0）',
  quotaBlock.includes("trialAgent === 'AG-TRIAL' ? ipQuotaKey(clientIp(req))")
);

// ============ C. 持久表不能只增 ============
ok(
  'C1 清扫函数里接上了持久表清理',
  hubSrc.includes('sweepPersistentTrialTables(now)') && hubSrc.includes('function sweepPersistentTrialTables')
);
ok(
  'C2 TTL 与条数上限双闸都在',
  /TRIAL_USED_TTL_DAYS/.test(hubSrc) && /TRIAL_USED_MAX/.test(hubSrc) &&
    hubSrc.includes('overflow')
);
ok(
  'C3 ★ 清完要落盘（否则内存删了、文件里还在，重启又长回来）',
  slice(hubSrc, 'const sweeper = setInterval', '}, LIMIT_SWEEP_MS);').includes('saveSoon()')
);
ok('C4 trial_enrolled 有加载兜底（老 hub.json 不该崩）', hubSrc.includes('if (!db.trial_enrolled) db.trial_enrolled = {};'));

// ============ D. 出口与观测 ============
const resetBlock = slice(hubSrc, "pathname === '/api/admin/trial/reset'", "// ---------- M9 技能注册表");
ok(
  'D1 ★ 永久标记有解除入口，且只在 admin 凭据之下',
  resetBlock.includes('adminOk') && resetBlock.includes('delete db.trial_pool_state.exhausted')
);
ok('D2 池列表回传 exhausted_at（能看出"是不是还没清标记"）', hubSrc.includes('exhausted_at:'));
ok(
  'D3 /health 区分"没开"与"配坏了"',
  slice(hubSrc, "pathname === '/health'", '// 注册：首次为信任引导').includes('config_issues')
);
ok(
  'D4 池解析的失败与缺字段都要留痕（不是只 console.error）',
  hubSrc.includes('issues.push') && hubSrc.includes("'TRIAL_POOL_FILE 解析失败：'")
);
ok('D5 README 有试用代调专章且列出旋钮', readmeSrc.includes('## 7. 试用代调') && readmeSrc.includes('TRIAL_IDS_PER_IP'));

// ============================================================
// E. 真起 hub + 假上游（行为判据）
// ============================================================
const NODE = process.execPath;
const HUBJS = path.join(ROOT, 'lib', 'hub', 'hub.js');
const TMP = path.join(ROOT, 'build', '_verify_trial_abuse');

/** 假上游：永远 200 一个最小 OpenAI 响应，让"成功透传"这条路真的走通。 */
function startUpstream() {
  const srv = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => { body += c; });
    req.on('end', () => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        id: 'fake', object: 'chat.completion',
        choices: [{ index: 0, message: { role: 'assistant', content: 'ok' }, finish_reason: 'stop' }],
        usage: { prompt_tokens: 1, completion_tokens: 1, total_tokens: 2 },
      }));
    });
  });
  return new Promise((r) => srv.listen(0, '127.0.0.1', () => r(srv)));
}

function prepDir(name, hubJson) {
  const dir = path.join(TMP, name);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  if (hubJson) fs.writeFileSync(path.join(dir, 'hub.json'), JSON.stringify(hubJson), 'utf8');
  return dir;
}

/** 起一个 hub 实例，等到 /health 可访问。 */
async function startHub(dir, port, env, upstreamPort) {
  const pool = path.join(dir, 'pool.json');
  fs.writeFileSync(pool, JSON.stringify([{
    name: 'probe',
    url: 'http://127.0.0.1:' + upstreamPort + '/v1/chat/completions',
    key: 'sk-probe', model: 'probe', type: 'text',
  }]), 'utf8');
  const child = cp.spawn(NODE, [HUBJS], {
    cwd: path.dirname(HUBJS),
    env: Object.assign({}, process.env, {
      PORT: String(port),
      HUB_DATA_DIR: dir,
      TRIAL_POOL_FILE: pool,
      HUB_REGISTRATION: 'open',
    }, env),
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let log = '';
  child.stdout.on('data', (d) => { log += d; });
  child.stderr.on('data', (d) => { log += d; });
  for (let i = 0; i < 60; i++) {
    const up = await new Promise((res) => {
      const r = http.get({ host: '127.0.0.1', port, path: '/health', timeout: 400 }, (x) => {
        x.resume();
        res(x.statusCode === 200);
      });
      r.on('error', () => res(false));
      r.on('timeout', () => { r.destroy(); res(false); });
    });
    if (up) return { child, log: () => log };
    await new Promise((r) => setTimeout(r, 120));
  }
  throw new Error('hub 未就绪（port ' + port + '）\n' + log.slice(-800));
}

function request(port, pathname, { method = 'POST', headers = {}, body } = {}) {
  return new Promise((resolve) => {
    const data = body === undefined ? null : JSON.stringify(body);
    const req = http.request(
      { host: '127.0.0.1', port, path: pathname, method,
        headers: Object.assign({ 'Content-Type': 'application/json' }, headers) },
      (res) => {
        let b = '';
        res.on('data', (c) => { b += c; });
        res.on('end', () => {
          let json = null;
          try { json = JSON.parse(b); } catch (_) { /* 非 JSON */ }
          resolve({ status: res.statusCode, body: b, json, headers: res.headers });
        });
      }
    );
    req.on('error', (e) => resolve({ status: 0, body: String(e), json: null, headers: {} }));
    if (data) req.write(data);
    req.end();
  });
}
const chat = (port, agent, xff, extra) =>
  request(port, '/api/trial/chat/completions', {
    headers: Object.assign(
      { Authorization: 'Bearer ' + agent, 'X-Forwarded-For': xff },
      extra || {}
    ),
    body: { messages: [{ role: 'user', content: 'hi' }] },
  });

async function stop(h) {
  if (!h || !h.child) return;
  h.child.kill();
  await new Promise((r) => {
    const t = setTimeout(() => { try { h.child.kill('SIGKILL'); } catch (_) {} r(); }, 3000);
    h.child.on('exit', () => { clearTimeout(t); r(); });
  });
}

(async () => {
  fs.rmSync(TMP, { recursive: true, force: true });
  fs.mkdirSync(TMP, { recursive: true });
  const up = await startUpstream();
  const upPort = up.address().port;
  const started = [];
  try {
    // ---------- E1 direct 模式：两个不同 XFF 共用同一个桶（旧行为的证据） ----------
    {
      const dir = prepDir('direct');
      const h = await startHub(dir, 3941, { TRIAL_IP_PER_MIN: '1', TRIAL_IP_PER_DAY: '400' }, upPort);
      started.push(h);
      const a = await chat(3941, 'AG-d1aa', '203.0.113.11');
      const b = await chat(3941, 'AG-d1bb', '203.0.113.12');
      ok(
        'E1 direct 模式：不同 XFF 仍共用一个 IP 桶（第 2 个 429）—— 所以反代形态必须开开关',
        a.status === 200 && b.status === 429 && b.json && b.json.error === 'trial_ip_rate_limited',
        `a=${a.status} b=${b.status} ${b.body.slice(0, 80)}`
      );
      await stop(h);
    }

    // ---------- E2 loopback 模式：不同 XFF 各自独立（P0-1 的正面判据） ----------
    {
      const dir = prepDir('loopback');
      const h = await startHub(dir, 3942, {
        HUB_TRUST_PROXY: 'loopback', TRIAL_IP_PER_MIN: '1', TRIAL_IP_PER_DAY: '400',
      }, upPort);
      started.push(h);
      const a = await chat(3942, 'AG-lb1aa', '203.0.113.21');
      const b = await chat(3942, 'AG-lb1bb', '203.0.113.22');
      ok(
        'E2 ★ loopback 模式：两个不同来源各算各的（都 200，不再全站抢一个桶）',
        a.status === 200 && b.status === 200,
        `a=${a.status} b=${b.status} ${b.body.slice(0, 80)}`
      );
      // 同一来源的第 2 次仍应被分钟闸拦住（闸没有因此失效）
      const again = await chat(3942, 'AG-lb1aa', '203.0.113.21');
      ok(
        'E2b loopback 模式：同一来源的第 2 次请求仍被限（闸没被放空）',
        again.status === 429 && again.json && again.json.error === 'trial_ip_rate_limited',
        `${again.status} ${again.body.slice(0, 80)}`
      );
      await stop(h);
    }

    // ---------- E3 AG-TRIAL 按出口分桶；E4 吊销拦截 ----------
    {
      const dir = prepDir('identity', {
        agents: {
          'AG-revoked1': { agent_id: 'AG-revoked1', pubkey: 'x', revoked_at: 1700000000000 },
        },
        messages: [], seq: 0, skills: {}, skill_revoked: {}, payouts: {}, endorsements: {},
        endorsement_revoked: {}, contributions: {}, room_roles: [], key_rotations: [], log: [],
        trial_used: {}, trial_enrolled: {}, trial_pool_state: { exhausted: {} },
        reports: {}, report_identities: {}, report_audit: [], keys: {},
      });
      const h = await startHub(dir, 3943, {
        HUB_TRUST_PROXY: 'loopback', TRIAL_TURN_LIMIT: '1',
        TRIAL_IP_PER_MIN: '1000', TRIAL_IP_PER_DAY: '100000',
      }, upPort);
      started.push(h);
      const a1 = await chat(3943, 'AG-TRIAL', '198.51.100.31');
      const a2 = await chat(3943, 'AG-TRIAL', '198.51.100.31');
      const b1 = await chat(3943, 'AG-TRIAL', '198.51.100.32');
      ok(
        'E3 ★ AG-TRIAL 按出口分桶：A 出口用尽（402），B 出口仍有额度（200）',
        a1.status === 200 && a2.status === 402 && b1.status === 200,
        `a1=${a1.status} a2=${a2.status} b1=${b1.status}`
      );
      const rv = await chat(3943, 'AG-revoked1', '198.51.100.33');
      ok(
        'E4 ★ 被吊销身份 401 agent_revoked（试用通道不再是吊销的法外之地）',
        rv.status === 401 && rv.json && rv.json.error === 'agent_revoked',
        `${rv.status} ${rv.body.slice(0, 80)}`
      );
      await stop(h);
    }

    // ---------- E5 未登记身份每网段上限 ----------
    {
      const dir = prepDir('enroll');
      const h = await startHub(dir, 3944, {
        HUB_TRUST_PROXY: 'loopback', TRIAL_IDS_PER_IP: '2',
        TRIAL_IP_PER_MIN: '1000', TRIAL_IP_PER_DAY: '100000', TRIAL_TURN_LIMIT: '20',
      }, upPort);
      started.push(h);
      const x1 = await chat(3944, 'AG-newid01', '192.0.2.61');
      const x2 = await chat(3944, 'AG-newid02', '192.0.2.61');
      const x3 = await chat(3944, 'AG-newid03', '192.0.2.61');
      ok(
        'E5 ★ 同一网段每天只准新建 N 个未登记身份（第 3 个 429 trial_identity_limited）',
        x1.status === 200 && x2.status === 200 && x3.status === 429 &&
          x3.json && x3.json.error === 'trial_identity_limited',
        `x1=${x1.status} x2=${x2.status} x3=${x3.status} ${x3.body.slice(0, 80)}`
      );
      // 已建档的身份换出口仍然认（不算新身份）
      const x1b = await chat(3944, 'AG-newid01', '192.0.2.99');
      ok('E5b 已建档身份换出口仍放行（不按 IP 重复计数）', x1b.status === 200, String(x1b.status));
      await stop(h);
    }

    // ---------- E6 永久标记的解除入口；E7 池配置问题可见 ----------
    {
      const dir = prepDir('reset', {
        agents: {}, messages: [], seq: 0, skills: {}, skill_revoked: {}, payouts: {},
        endorsements: {}, endorsement_revoked: {}, contributions: {}, room_roles: [],
        key_rotations: [], log: [], trial_used: {}, trial_enrolled: {},
        trial_pool_state: { exhausted: { probe: { at: 1710000000000, status: 402 } } },
        reports: {}, report_identities: {}, report_audit: [], keys: {},
      });
      const h = await startHub(dir, 3945, {
        HUB_TRUST_PROXY: 'loopback', HUB_ADMIN_KEY: 'verify-admin',
      }, upPort);
      started.push(h);
      const before = await request(3945, '/api/trial/pool', { method: 'GET' });
      const beforeEx = before.json && before.json.pool && before.json.pool[0] &&
        before.json.pool[0].exhausted === true && typeof before.json.pool[0].exhausted_at === 'number';
      ok('E6a 池列表能看到 exhausted + exhausted_at', beforeEx, before.body.slice(0, 120));
      const noAuth = await request(3945, '/api/admin/trial/reset', { body: {} });
      ok('E6b 无管理密钥不许清标记', noAuth.status === 403, String(noAuth.status));
      const done = await request(3945, '/api/admin/trial/reset', {
        headers: { 'X-Admin-Key': 'verify-admin' }, body: { name: 'probe' },
      });
      const after = await request(3945, '/api/trial/pool', { method: 'GET' });
      ok(
        'E6c ★ admin reset 真能清掉永久标记（换 key 后有出口）',
        done.status === 200 && done.json && done.json.cleared.length === 1 &&
          after.json.pool[0].exhausted === false,
        `${done.status} ${done.body.slice(0, 80)}`
      );
      const health = await request(3945, '/health', { method: 'GET' });
      ok(
        'E7 /health 露出口径：trial.configured / config_issues',
        health.json && health.json.trial && health.json.trial.configured === true &&
          typeof health.json.trial.config_issues === 'number',
        health.body.slice(0, 120)
      );
      await stop(h);
    }

    // ---------- E8 坏池：config_issues 必须是 1（"配坏了"与"没开"可区分） ----------
    {
      const dir = prepDir('badpool');
      const bad = path.join(dir, 'pool.json');
      fs.writeFileSync(bad, '[{"name":"x","model":"m"}]', 'utf8'); // 缺 url/key
      const child = cp.spawn(NODE, [HUBJS], {
        cwd: path.dirname(HUBJS),
        env: Object.assign({}, process.env, {
          PORT: '3946', HUB_DATA_DIR: dir, TRIAL_POOL_FILE: bad, HUB_REGISTRATION: 'open',
        }),
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      let log = '';
      child.stdout.on('data', (d) => { log += d; });
      child.stderr.on('data', (d) => { log += d; });
      let up2 = false;
      for (let i = 0; i < 60 && !up2; i++) {
        up2 = await new Promise((res) => {
          const r = http.get({ host: '127.0.0.1', port: 3946, path: '/health', timeout: 400 },
            (x) => { x.resume(); res(x.statusCode === 200); });
          r.on('error', () => res(false));
          r.on('timeout', () => { r.destroy(); res(false); });
        });
        if (!up2) await new Promise((r) => setTimeout(r, 120));
      }
      const h2 = { child };
      started.push(h2);
      if (up2) {
        const health = await request(3946, '/health', { method: 'GET' });
        ok(
          'E8 ★ 池文件缺字段 ⇒ /health 的 config_issues ≥ 1（不是静默"没开"）',
          health.json && health.json.trial && health.json.trial.config_issues >= 1 &&
            health.json.trial.configured === false,
          health.body.slice(0, 120)
        );
        ok(
          'E8b 启动日志点名"试用池配置有 N 处问题"',
          /试用池配置有 \d+ 处问题/.test(log),
          log.split('\n').filter((l) => l.includes('试用池')).join(' | ').slice(0, 160)
        );
      } else {
        ok('E8 ★ 坏池实例能起（否则无从观测）', false, log.slice(-300));
      }
      await stop(h2);
    }
  } catch (e) {
    ok('E 组整体执行（异常即红）', false, e && e.message ? e.message : String(e));
  } finally {
    for (const h of started) await stop(h);
    await new Promise((r) => up.close(r));
    fs.rmSync(TMP, { recursive: true, force: true });
  }

  // ============ 汇总 ============
  console.log('=== 试用代调滥用面（免费 20 轮）===');
  if (failures.length) for (const f of failures) console.log('FAIL ' + f);
  console.log(`${pass} PASS / ${fail} FAIL`);
  process.exit(fail === 0 ? 0 : 1);
})();
