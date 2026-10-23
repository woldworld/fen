#!/usr/bin/env node
// ============================================================================
// tool/verify_hub_privacy_hygiene.js
//
// 缘起（2026-10-20，海外私密通讯 BP 改造复查）：查出两处**只有代码知道、文档不知道**
// 的事实 ——
//   ① 运行日志把**完整来源 IP** 写进标准输出（`req.socket.remoteAddress`）；
//   ② 五张限流表（`hits` / `anonHits` / `trialIpHits` / `trialIpDay` / `reportHits`）
//      **只增不删** —— 窗口过期只重置 count，键永久留着。
// 两件事单独看都是小毛病，合起来却会让隐私政策里任何「短期保留」的承诺变成假话：
// 政策说要短期保留，实现是「进程活着就一直留」。
//
// 本守卫判四件事：
//   ① `maskIp` 对 IPv4 / IPv4 映射 IPv6 / IPv6 / 回环 / 缺省 的行为 —— **并且反断言**
//      「输出不等于原始完整 IP」（否则"截断"这件事可能根本没发生）；
//   ② `sweepRateTables` 真的删过期键、**并且真的留下活跃键**（后者才是防腐关键：
//      误删活跃键会把用户刚攒的配额清零，是比泄漏更严重的功能 bug）；
//      另加**正控**：把 now 往后推，让刚才的"活跃键"变过期 ⇒ 它必须被删，
//      证明「留下活跃键」这条断言不是恒真；
//   ③ 源码层面：日志那行必须走 `maskIp(`，且**不得**再出现裸的 `remoteAddress}` 插值；
//   ④ 源码层面：`sweepRateTables` 函数体必须覆盖**每一张**限流表
//      （加新表不加清扫 = 又变回只增表；这条是给未来的人看的）。
//      ④ 用三份**变异副本**做正控，证明静态判据会红。
//
// 零依赖、不联网、不启端口（只 require 纯函数）。
// ============================================================================

const fs = require('fs');
const path = require('path');

const REPO = path.resolve(__dirname, '..');
const HUB = path.join(REPO, 'lib', 'hub', 'hub.js');

let pass = 0;
let fail = 0;
const failures = [];
function ok(cond, label, detail) {
  if (cond) { pass++; console.log('  PASS  ' + label); }
  else {
    fail++; failures.push(label);
    console.log('  FAIL  ' + label + (detail ? '  -> ' + detail : ''));
  }
}

console.log('=== hub 隐私/运维卫生守卫 ===');

if (!fs.existsSync(HUB)) {
  console.log('SKIP 未找到 lib/hub/hub.js');
  process.exit(2);
}

const src = fs.readFileSync(HUB, 'utf8');
const hub = require(HUB);
const NOW = Date.now();

// ---------------------------------------------------------------- ① maskIp --
console.log('\n[1] maskIp 截断行为');
ok(typeof hub.maskIp === 'function', 'maskIp 已导出');
if (typeof hub.maskIp === 'function') {
  const cases = [
    ['203.0.113.45', '203.0.113.0/24', 'IPv4 -> /24'],
    ['::ffff:198.51.100.7', '198.51.100.0/24', 'IPv4 映射 IPv6 -> /24'],
    ['::1', '::1', 'IPv6 回环不截断（不含用户标识）'],
  ];
  for (const [input, want, label] of cases) {
    const got = hub.maskIp(input);
    ok(got === want, label, 'got ' + got);
  }
  const v6 = hub.maskIp('2001:db8:85a3:1234:5678:9abc:def0:1');
  ok(v6.indexOf('2001:db8:85a3') === 0, 'IPv6 保留前 3 组（/48）', 'got ' + v6);
  ok(v6.indexOf('1234') < 0 && v6.indexOf('5678') < 0,
    'IPv6 主机位被抹掉（不得残留 1234/5678）', 'got ' + v6);
  ok(hub.maskIp(undefined) === 'unknown', '缺省 -> unknown');
  ok(hub.maskIp('') === 'unknown', '空串 -> unknown');
  // ★ 反断言：截断必须真的发生了（否则上面几条可以靠"原样返回"全过）
  ok(hub.maskIp('203.0.113.45') !== '203.0.113.45', '反断言：IPv4 输出 != 原始完整 IP');
  ok(v6 !== '2001:db8:85a3:1234:5678:9abc:def0:1', '反断言：IPv6 输出 != 原始完整 IP');
}

// ------------------------------------------------------ ② sweepRateTables --
console.log('\n[2] sweepRateTables 行为（删过期 / 留活跃 / 正控）');
const T = hub.rateTables || {};
const NAMES = ['hits', 'anonHits', 'trialIpHits', 'trialIpDay', 'reportHits'];
for (const n of NAMES) ok(!!(T[n] && typeof T[n].delete === 'function'), '限流表已导出: ' + n);

if (typeof hub.sweepRateTables === 'function' && NAMES.every((n) => T[n])) {
  for (const n of NAMES) T[n].clear();
  const today = new Date(NOW).toISOString().slice(0, 10);

  // 分钟窗三张 + 小时窗一张：各塞一个"很久没访问"的过期键 + 一个"刚访问过"的活跃键
  for (const n of ['hits', 'anonHits', 'trialIpHits']) {
    T[n].set('stale|' + n, { count: 1, windowStart: NOW - 10 * 60000 });
    T[n].set('live|' + n, { count: 1, windowStart: NOW - 1000 });
  }
  T.reportHits.set('stale|report', { count: 1, windowStart: NOW - 10 * 3600000 });
  T.reportHits.set('live|report', { count: 1, windowStart: NOW - 60000 });
  T.trialIpDay.set('stale|day', { day: '2000-01-01', count: 9 });
  T.trialIpDay.set('live|day', { day: today, count: 1 });

  const dropped = hub.sweepRateTables(NOW);
  ok(dropped === 5, '一次清扫移除 5 条过期键', 'got ' + dropped);

  for (const n of ['hits', 'anonHits', 'trialIpHits']) {
    ok(!T[n].has('stale|' + n), n + ' 过期键已删除');
    // ★ 关键防腐断言：活跃键**必须留下**（误删会清零用户刚攒的配额）
    ok(T[n].has('live|' + n), n + ' 活跃键保留');
  }
  ok(!T.reportHits.has('stale|report'), 'reportHits 过期键已删除');
  ok(T.reportHits.has('live|report'), 'reportHits 活跃键保留');
  ok(!T.trialIpDay.has('stale|day'), 'trialIpDay 非今日键已删除');
  ok(T.trialIpDay.has('live|day'), 'trialIpDay 今日键保留');

  // ★ 正控：把 now 推到"刚才的活跃键"也过期 ⇒ 它必须被删。
  //   若这条不红，说明上面"保留"的断言是恒真的（清扫可能根本不看时间）。
  hub.sweepRateTables(NOW + 10 * 60000);
  ok(!T.hits.has('live|hits'), '正控：时间后移后"活跃键"变过期并被删除');

  for (const n of NAMES) T[n].clear();
  ok(NAMES.every((n) => T[n].size === 0), '收尾：五张表已清空（不污染同进程其它用例）');
}

// ------------------------------------------------------------ ③④ 静态判据 --
console.log('\n[3] 源码判据（日志脱敏 / 清扫覆盖面）');

/** 从源码里取出 sweepRateTables 的函数体（按大括号配平，避免正则截断）。 */
function bodyOf(text, fnName) {
  const at = text.indexOf('function ' + fnName);
  if (at < 0) return null;
  const open = text.indexOf('{', at);
  if (open < 0) return null;
  let depth = 0;
  for (let i = open; i < text.length; i++) {
    if (text[i] === '{') depth++;
    else if (text[i] === '}') {
      depth--;
      if (depth === 0) return text.slice(open, i + 1);
    }
  }
  return null;
}

/**
 * 取出**请求访问日志**那条语句。
 *
 * ★ 不能用「含 `console.log(` 且含 `[hub]`」去找 —— 0.116.0 实测：hub.js 里另有
 *   3 条同形状的启动/告警日志（`[hub] 分链路已开启…` 等），会先命中它们
 *   ⇒ 守卫对着**别的**语句判「有没有走 maskIp」，得出假 FAIL。
 *   锚点必须是那条唯一形状：`[hub] ${new Date().toISOString()}`。
 */
function logStmt(text) {
  const lines = text.split('\n');
  const j = lines.findIndex((l) => l.indexOf('[hub] ${new Date().toISOString()}') >= 0);
  if (j < 0) return null;
  // 语句是多行的：往上找 `console.log(`，往下到本语句结束的 `);`
  let start = j;
  while (start > 0 && lines[start].indexOf('console.log(') < 0) start--;
  let end = j;
  while (end < lines.length - 1 && lines[end].indexOf(');') < 0) end++;
  return lines.slice(start, end + 1).join('\n');
}

/** 对一段源码做静态判据，返回 {label: bool}。用作正控（喂变异副本）。 */
function staticChecks(text) {
  const out = {};
  const stmt = logStmt(text);
  out.logExists = !!stmt;
  out.logMasked = !!stmt && stmt.indexOf('maskIp(') >= 0;
  // 裸插值 ${...remoteAddress} 说明没走 maskIp
  out.noRawInterp = !!stmt && !/\$\{[^}]*remoteAddress\s*\}/.test(stmt);

  const body = bodyOf(text, 'sweepRateTables');
  out.bodyExists = !!body;
  out.coversAll = !!body && NAMES.every((n) => new RegExp('\\b' + n + '\\b').test(body));

  out.timerWired = /setInterval\([\s\S]{0,2000}LIMIT_SWEEP_MS/.test(text);
  return out;
}

const real = staticChecks(src);
ok(real.logExists, '找到 [hub] 请求日志语句');
ok(real.logMasked, '日志走 maskIp()');
ok(real.noRawInterp, '日志里无裸的 ${...remoteAddress} 插值');
ok(real.bodyExists, '找到 sweepRateTables 函数体');
ok(real.coversAll, '清扫覆盖全部五张限流表');
ok(real.timerWired, '启用了按 LIMIT_SWEEP_MS 的定时清扫');

// ★ 静态判据的正控：三份变异副本，每份都必须让对应判据变红。
const mutants = [
  ['裸 IP 插值', src.replace('${maskIp(req.socket && req.socket.remoteAddress)}',
    '${req.socket.remoteAddress}'), 'noRawInterp'],
  ['漏扫一张表', src.replace('  sweepByWindow(trialIpHits, RATE_WINDOW_MS);', ''),
    'coversAll'],
  ['拆掉定时器', src.replace('  const sweeper = setInterval(', '  const sweeper = (0 && ('),
    'timerWired'],
];
for (const [label, mutated, key] of mutants) {
  const changed = mutated !== src;
  const res = staticChecks(mutated);
  ok(changed && res[key] === false, '正控（' + label + '）=> ' + key + ' 必须变红',
    'changed=' + changed + ' ' + key + '=' + res[key]);
}

// ------------------------------------------------------------------ 汇总 --
console.log('\n' + pass + ' PASS / ' + fail + ' FAIL');
if (fail > 0) {
  console.log('失败项：\n  - ' + failures.join('\n  - '));
  process.exit(1);
}
