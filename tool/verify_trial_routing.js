#!/usr/bin/env node
'use strict';

// ============================================================================
// 试用代调「分链路」守卫 —— 隐私政策 §3 承诺「按来源地区选链路」，这个脚本证明它真的发生。
//
// 为什么必须是**行为**守卫而不是源码扫描：
//   源码里写下 `if (region === 'cn')` 不能证明任何事——阈值写反、过滤条件写漏、
//   上游拿错一条，源码看起来都一模一样。唯一能分辨的是"发一个请求，看它打到谁"。
//   故本脚本自起一个假上游（把收到的路径写进回复正文）与一个真 hub.js，用真 HTTP 打。
//
// 判据（每条都能单独红）：
//   ① 来源 CN        → 打到 cn 那条条目
//   ② 来源 JP        → 打到 intl 那条条目
//   ③ 无来源头        → 503 trial_region_unknown（**绝不猜链路**：猜错的方向是跨境事故）
//   ④ /api/trial/pool → 公开 region 与 region_routing（降级/配置可见）
//
// ★ 自起服务：端口随机取空闲、退出时必杀子进程。不依赖任何外部环境，
//   故**不进 OPTIONAL**——起不来就该红，那是代码或环境坏了，不是"没产物"。
//
// 运行：node tool/verify_trial_routing.js
// ============================================================================

const { spawn } = require('child_process');
const fs = require('fs');
const net = require('net');
const os = require('os');
const path = require('path');
const http = require('http');

const ROOT = path.join(__dirname, '..');
const HUB = path.join(ROOT, 'lib', 'hub', 'hub.js');

let pass = 0;
let fail = 0;
function ck(ok, label) {
  if (ok) { pass++; console.log('  PASS  ' + label); }
  else { fail++; console.log('  FAIL  ' + label); }
}

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'wold-route-'));
const FAKE = path.join(TMP, 'fake-upstream.js');
const POOL = path.join(TMP, 'pool.json');

function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.once('error', reject);
    s.listen(0, '127.0.0.1', () => {
      const p = s.address().port;
      s.close(() => resolve(p));
    });
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** 等端口能连上 + 返回 false 表示超时。 */
async function waitPort(port, timeoutMs) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const ok = await new Promise((resolve) => {
      const s = net.connect(port, '127.0.0.1');
      s.once('connect', () => { s.destroy(); resolve(true); });
      s.once('error', () => { s.destroy(); resolve(false); });
      setTimeout(() => { s.destroy(); resolve(false); }, 400);
    });
    if (ok) return true;
    await sleep(150);
  }
  return false;
}

function request(port, method, p, headers, body) {
  return new Promise((resolve) => {
    const data = body === undefined ? null : Buffer.from(JSON.stringify(body));
    const req = http.request(
      { host: '127.0.0.1', port, method, path: p, headers: Object.assign({}, headers,
        data ? { 'Content-Type': 'application/json', 'Content-Length': data.length } : {}) },
      (res) => {
        let out = '';
        res.on('data', (c) => { out += c; });
        res.on('end', () => resolve({ status: res.statusCode, body: out }));
      }
    );
    req.on('error', (e) => resolve({ status: 0, body: String(e.message) }));
    if (data) req.write(data);
    req.end();
  });
}

(async () => {
  // 假上游：把收到的路径写进回复正文 —— 回复本身即为"打到了谁"的证据。
  fs.writeFileSync(FAKE, [
    "const http = require('http');",
    'const port = Number(process.argv[2]);',
    "http.createServer((req, res) => {",
    "  let b = '';",
    "  req.on('data', (c) => { b += c; });",
    "  req.on('end', () => {",
    "    const vendor = req.url.replace(/^\\//, '').split('?')[0] || 'root';",
    "    res.writeHead(200, { 'Content-Type': 'application/json' });",
    '    res.end(JSON.stringify({',
    "      id: 'x', object: 'chat.completion', created: 0, model: 'fake',",
    "      choices: [{ index: 0, message: { role: 'assistant', content: 'VENDOR:' + vendor }, finish_reason: 'stop' }],",
    '      usage: { prompt_tokens: 1, completion_tokens: 1, total_tokens: 2 },',
    '    }));',
    '  });',
    '}).listen(port, "127.0.0.1");',
  ].join('\n'), 'utf8');

  const up = await freePort();
  const hubPort = await freePort();

  fs.writeFileSync(POOL, JSON.stringify([
    { name: 'cn-vendor', url: 'http://127.0.0.1:' + up + '/cn', key: 'sk-cn',
      model: 'qwen-plus', type: 'text', region: 'cn' },
    { name: 'intl-vendor', url: 'http://127.0.0.1:' + up + '/intl', key: 'sk-intl',
      model: 'openrouter/auto', type: 'text', region: 'intl' },
  ], null, 2), 'utf8');

  const env = Object.assign({}, process.env, {
    PORT: String(hubPort),
    HUB_DATA_DIR: path.join(TMP, 'data'),
    TRIAL_POOL_FILE: POOL,
    TRIAL_REGION_SOURCE: 'header',
    TRIAL_REGION_HEADER: 'x-test-country',
    TRIAL_TURN_LIMIT: '999',
  });
  delete env.TRIAL_UPSTREAM_URL;
  delete env.TRIAL_UPSTREAM_KEY;

  const logs = [];
  const kids = [];
  const spawnOne = (cmd, args, opts) => {
    const p = spawn(cmd, args, Object.assign({ stdio: ['ignore', 'pipe', 'pipe'] }, opts));
    p.stdout.on('data', (c) => logs.push(String(c)));
    p.stderr.on('data', (c) => logs.push(String(c)));
    kids.push(p);
    return p;
  };

  try {
    console.log('=== 试用代调分链路守卫 ===');
    spawnOne(process.execPath, [FAKE, String(up)], {});
    spawnOne(process.execPath, [HUB], { cwd: path.join(ROOT, 'lib', 'hub'), env });

    const ready = (await waitPort(up, 10000)) && (await waitPort(hubPort, 20000));
    ck(ready, '假上游与 hub 都已监听（up=' + up + ' hub=' + hubPort + '）');
    if (!ready) {
      console.log('  --- hub 输出 ---');
      console.log(logs.join('').split('\n').slice(-20).join('\n'));
      throw new Error('setup');
    }

    const BODY = { model: 'ignored', messages: [{ role: 'user', content: 'hi' }], stream: false };
    const auth = { Authorization: 'Bearer AG-test1234' };
    const ENDPOINT = '/api/trial/chat/completions';

    let r = await request(hubPort, 'POST', ENDPOINT, Object.assign({ 'x-test-country': 'CN' }, auth), BODY);
    ck(r.status === 200 && r.body.includes('VENDOR:cn'),
      '① 来源 CN 走境内链路（实测 ' + r.status + ' / '
        + (r.body.includes('VENDOR:cn') ? 'VENDOR:cn' : r.body.slice(0, 120)) + '）');

    r = await request(hubPort, 'POST', ENDPOINT, Object.assign({ 'x-test-country': 'JP' }, auth), BODY);
    ck(r.status === 200 && r.body.includes('VENDOR:intl'),
      '② 来源 JP 走境外链路（实测 ' + r.status + ' / '
        + (r.body.includes('VENDOR:intl') ? 'VENDOR:intl' : r.body.slice(0, 120)) + '）');

    r = await request(hubPort, 'POST', ENDPOINT, auth, BODY);
    ck(r.status === 503 && r.body.includes('trial_region_unknown'),
      '③ 判定不出地区时**拒绝**而非猜测（实测 ' + r.status + ' / ' + r.body.slice(0, 120) + '）');

    r = await request(hubPort, 'GET', '/api/trial/pool', {}, undefined);
    let poolOk = false;
    let detail = '';
    try {
      const o = JSON.parse(r.body);
      const regions = (o.pool || []).map((e) => e.region).sort().join(',');
      poolOk = o.region_routing === 'header' && regions === 'cn,intl';
      detail = 'region_routing=' + o.region_routing + ' regions=' + regions;
    } catch (e) {
      detail = 'JSON 解析失败';
    }
    ck(poolOk, '④ /api/trial/pool 公开地域标注与路由模式（实测 ' + detail + '）');

    // ⑤ 模板池必须两条链路都有：只列境内厂商的模板，照着配就永远出不了境外链路，
    //   而隐私政策已经对外写明境外走 OpenRouter。
    let ex = [];
    try {
      ex = JSON.parse(fs.readFileSync(path.join(ROOT, 'lib', 'hub', 'trial-pool.example.json'), 'utf8'));
    } catch (e) {
      ex = [];
    }
    const exCn = ex.filter((e) => e.region === 'cn').length;
    const exIntl = ex.filter((e) => e.region === 'intl').length;
    ck(exCn > 0 && exIntl > 0,
      '⑤ 模板池两条链路都有（实测 ' + ex.length + ' 条：cn=' + exCn + ' intl=' + exIntl + '）');
  } catch (e) {
    if (e.message !== 'setup') {
      console.log('  FAIL  守卫自身异常: ' + e.message);
      fail++;
    }
  } finally {
    for (const p of kids) {
      try { p.kill(); } catch (e) { /* 已退出 */ }
    }
    try { fs.rmSync(TMP, { recursive: true, force: true }); } catch (e) { /* 尽力而为 */ }
  }

  console.log('');
  console.log('================ 试用分链路校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
  process.exit(fail === 0 ? 0 : 1);
})();
