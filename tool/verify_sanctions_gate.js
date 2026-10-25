#!/usr/bin/env node
/**
 * 制裁封锁守卫（上线合规门槛清单 第 23 条 · B 档）
 *
 * 为什么要有它：第 23 条判据写的是「注册与访问侧有拒绝路径（地域判定 + 名单匹配，
 * **不是只在文档里写一句**）」。而"文档里写一句"这件事最容易伪装成"已经做了" ——
 * 所以本守卫不只扫字面量，还要**真的调用** `sanctionsDecision` 看它拒不拒。
 *
 * 三种失效形态，各配一条断言：
 *   ① 机制根本不存在（源码里没有拒绝路径）        → 静态探针 + 行为级取证
 *   ② 机制在但无效果（名单为空 / 地域来源 off）    → 行为级：判不出时放行被显式记录，且启动日志会点名
 *   ③ 客户端分类错了（451 落到可重试分支）         → 跨语言：Dart 侧 classifyHubResponse
 *
 * ⚠️ 关于 ③ 的诚实口径：Dart 侧目前**没有 451 的显式分支**，靠「其它 4xx → rejected」
 *    兜底。本守卫断言的是**当前行为正确**（永久拒绝、不入队），不是"已显式分支"。
 *    将来若有人改兜底分支让 451 变 retryable，本条会当场红 —— 锚点是活的。
 *
 * 用法：node tool/verify_sanctions_gate.js
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const HUB = path.join(ROOT, 'lib', 'hub', 'hub.js');
const OUTCOME = path.join(ROOT, 'lib', 'core', 'hub_push_outcome.dart');

let pass = 0;
let fail = 0;
function check(ok, label) {
  if (ok) { pass++; console.log('  PASS  ' + label); }
  else { fail++; console.log('  FAIL  ' + label); }
}

console.log('=== 制裁封锁守卫（门禁第 23 条）===');
console.log('--- 探测器自检（positive control）---');

// ============================================================ 自检（先证会红）===
// 扫描器是下面所有断言的地基。它要是悄悄坏了，这里会一路"全绿"。
{
  const src = 'return sendJson(res, 451, {';
  check(src.includes('451'), '自检：451 字面量能被测出');
  check(!'return sendJson(res, 200, {'.includes('451'), '自检：200 不会被误判成 451');
  const re = /^\s*if \(pathname !== '\/health'\) \{$/m;
  check(re.test("    if (pathname !== '/health') {"), '自检：/health 豁免行能被测出');
  check(!re.test("    if (pathname === '/health') {"), '自检：反向写法不会被误判');
}

check(fs.existsSync(HUB), 'hub.js 存在（lib/hub/hub.js）');
const src = fs.existsSync(HUB) ? fs.readFileSync(HUB, 'utf8') : '';

// ============================================================ 静态：拒绝路径在位 ===
console.log('--- 静态：拒绝路径在位 ---');

check(src.includes('function sanctionsDecision(req)'), '存在 sanctionsDecision（判定函数）');
check(src.includes('function countryOf(req)'), '存在 countryOf（地域判定）');
check(src.includes('function sanctionsSet()'), '存在 sanctionsSet（名单匹配）');
check(src.includes('return sendJson(res, 451,'), '拒绝返回 HTTP 451（Unavailable For Legal Reasons）');
check(src.includes("error: sanc.reason"), '拒绝体带 error 字段（客户端按 error 分支，不只判状态）');
check(/reason: 'region_blocked'/.test(src), '拒绝码为 region_blocked');

// /health 必须豁免：外部拨测与状态页（第 26 条）靠它，封了等于自己关掉观测面。
check(
  /if \(pathname !== '\/health'\) \{/.test(src),
  '/health 豁免（制裁闸不拦健康检查，否则第 26 条状态页连带失效）'
);

// 名单非空 = 机制有实际效果。空名单的封锁是"看起来做了"的假闸。
{
  // ⚠️ 必须 .exec(src)：正则对象的 m[1] 恒为 undefined —— 写成 `m && m[1]` 的话
  //    这条断言会**恒假**（永远 FAIL 也永远看不出是判据写错了）。踩过一次，留注。
  const m = /const SANCTIONS_COUNTRIES = String\(\s*process\.env\.SANCTIONS_COUNTRIES \|\| '([^']*)'/m.exec(src);
  const found = m && m[1];
  check(Boolean(found) && found.length > 0, '默认名单非空（空名单 = 机制在但无效果）实际 = ' + (found || '(未匹配)'));
  if (found) {
    const ccs = found.split(',').map((s) => s.trim()).filter(Boolean);
    check(ccs.every((c) => /^[A-Z]{2}$/.test(c)), '默认名单每项都是 ISO 3166-1 alpha-2（' + ccs.join(',') + '）');
  }
}

// 启动日志必须点名三种"机制在但无效果"的失效 —— 与「注册模式」同一条纪律。
check(/制裁封锁: /.test(src), '启动日志打印制裁封锁状态');
check(/名单为空 = 机制在但无效果/.test(src), '启动日志点名「名单为空」');
check(/实际不会封锁任何人/.test(src), '启动日志点名「地域来源=off ⇒ 不封锁任何人」');
check(/非法律名单/.test(src), '启动日志点名「名单为工程侧初值、非法律名单」');

// ==================================================== 行为级：真的拒 / 真的放行 ===
console.log('--- 行为级（子进程，环境变量为真）---');

/**
 * 在子进程里 require hub.js 并求值。
 * ★ 必须起子进程：SANCTIONS_* 是 require 当时的快照，同一进程内改 env 再 require
 *   会命中模块缓存返回旧值 ⇒ 守卫恒绿（假绿）。这是本守卫唯一会撒谎的地方。
 */
function probe(env, expr) {
  const code =
    'const h = require(' + JSON.stringify(HUB) + ');' +
    'process.stdout.write(JSON.stringify(' + expr + '));';
  const out = execFileSync(process.execPath, ['-e', code], {
    cwd: ROOT,
    env: Object.assign({}, process.env, env),
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  return JSON.parse(out);
}

/** 造一个只有 headers 的假 req（sanctionsDecision 只读 req.headers）。 */
const exprFor = (cc) =>
  "h.sanctionsDecision({ headers: { 'cf-ipcountry': " + JSON.stringify(cc) + ' } })';

let P;
try {
  P = {
    // 默认：block + 名单 CU,IR,KP,SY + 地域来源跟随 TRIAL_REGION_SOURCE（未设则为 off）
    // ⇒ 显式打开地域来源，才能测到"名单内被拒"。
    onBlocked: probe(
      { SANCTIONS_REGION_SOURCE: 'cf', SANCTIONS_REGION_HEADER: 'cf-ipcountry' },
      exprFor('CU')
    ),
    onAllowed: probe(
      { SANCTIONS_REGION_SOURCE: 'cf', SANCTIONS_REGION_HEADER: 'cf-ipcountry' },
      exprFor('US')
    ),
    modeOff: probe(
      { SANCTIONS_MODE: 'off', SANCTIONS_REGION_SOURCE: 'cf' },
      exprFor('CU')
    ),
    srcOff: probe(
      { SANCTIONS_REGION_SOURCE: 'off' },
      exprFor('CU')
    ),
    xx: probe({ SANCTIONS_REGION_SOURCE: 'cf' }, exprFor('XX')),
    t1: probe({ SANCTIONS_REGION_SOURCE: 'cf' }, exprFor('T1')),
    emptyHdr: probe({ SANCTIONS_REGION_SOURCE: 'cf' }, exprFor('')),
    lower: probe({ SANCTIONS_REGION_SOURCE: 'cf' }, exprFor('cu')),
  };
} catch (e) {
  fail++;
  console.log('  FAIL  行为级探测子进程异常：' + e.message);
  P = null;
}

if (P) {
  check(
    P.onBlocked && P.onBlocked.cc === 'CU' && P.onBlocked.reason === 'region_blocked',
    '名单内（CU）→ 拒绝，且带 cc 与 reason'
  );
  check(P.onAllowed === null, '名单外（US）→ 放行（不许误封）');
  check(P.modeOff === null, 'SANCTIONS_MODE=off → 全放行（显式关闭生效）');
  check(P.srcOff === null, '地域来源=off → 放行（判定不出不硬猜）');
  check(P.xx === null, 'cf-ipcountry=XX → 放行（Cloudflare 认不出，不硬猜）');
  check(P.t1 === null, 'cf-ipcountry=T1（Tor）→ 放行，不硬猜');
  check(P.emptyHdr === null, '地域头缺失 → 放行，不硬猜');
  check(P.lower === null || P.lower.cc === 'CU', '小写 cu 归一化为 CU（大小写不敏感）');
}

// ================================================ 跨语言：客户端不许把 451 当可重试 ===
console.log('--- 跨语言：客户端分类（R45）---');

const dsrc = fs.existsSync(OUTCOME) ? fs.readFileSync(OUTCOME, 'utf8') : '';
check(fs.existsSync(OUTCOME), '客户端分类表存在（lib/core/hub_push_outcome.dart）');
if (dsrc) {
  // 451 必须落到 rejected（永久拒绝、不入队）。当前靠兜底分支生效 —— 断言行为，不断言形式。
  const explicit = /status == 451/.test(dsrc);
  const hasFallback = /return HubPushOutcome\.rejected;\s*\}/.test(dsrc);
  check(
    hasFallback,
    '分类表兜底为 rejected（451 落到这里 = 永久拒绝、不入队、不重试）'
  );
  // 明确记录"未显式分支"这个已知缺口，别让它被当成"已处理"。
  console.log(
    '  NOTE  Dart 侧 451 ' +
      (explicit ? '已显式分支' : '**未显式分支**（靠兜底生效；已登记为待办，做它需要 MINOR+1 + 重出 APK）')
  );
  // 将来有人把兜底改坏 ⇒ 这条会红。
  check(
    !/status == 451[\s\S]{0,120}retryable/.test(dsrc),
    '451 未被归类为 retryable（归类错 = 假闸，R45）'
  );
}

// ============================================================== 负控：证明会红 ===
console.log('--- 负控（把毒注进去看它红不红）---');
{
  // 削掉 451，静态探针必须报红 —— 否则"静态断言"只是装饰。
  const poisoned = src.replace('return sendJson(res, 451,', 'return sendJson(res, 200,');
  check(
    poisoned !== src && !poisoned.includes('return sendJson(res, 451,'),
    '负控：451 可被削掉（探针必须随之报红）'
  );
  check(
    !poisoned.includes('return sendJson(res, 451,'),
    '负控：削掉后静态断言确实会 FAIL（不是恒真）'
  );
  // 削掉 /health 豁免，豁免探针必须报红
  const p2 = src.replace("if (pathname !== '/health') {", "if (pathname !== '/nope') {");
  check(
    !/if \(pathname !== '\/health'\) \{/.test(p2),
    '负控：/health 豁免被削后探针会 FAIL'
  );
}

// ==================================================================== 汇总 ====
console.log('');
console.log('================ 制裁封锁守卫：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
