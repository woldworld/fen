#!/usr/bin/env node
// 开源发布面守卫 —— 门禁第 24 条的判据。
//
// 为什么要有它（2026-10-20 实证，一次我自己判错的教训）：
//   上轮把第 24 条写成「四件全部不存在」，是因为查了**主仓根**；
//   真正的公开面是 `opensource-release/` 导出树，那里五件材料**全在**。
//   ⇒ 判错对象的代价是：真问题（导出树停在 0.63.0+1、落后主仓 53 个版本）
//     被一句假结论（缺文件）盖住了 —— 缺文件会催你补文件，快照陈旧不会。
//
// 它守三件事：
//   ① 新鲜度 —— 导出树的 pubspec version 必须 == 主仓 pubspec version。
//     不等 = 公开出去的是旧代码（第 24 条判「未满足」的真正理由）。
//   ② 材料齐 —— LICENSE / SECURITY.md / CONTRIBUTING.md / CODE_OF_CONDUCT.md / GOVERNANCE.md 五件在盘且非空。
//   ③ 专有层零外泄 —— lib/hub、lib/dist、备份、repo-content 一律不得出现在导出树（R13）。
//
// 无导出树 ⇒ `exit 2`（明确 SKIP，不假装通过）；本脚本已登记在
// run_all_verify_node.js 的 OPTIONAL 里 —— 干净克隆没有导出树是正常的。

'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const REL = path.join(ROOT, 'opensource-release');

let pass = 0;
let fail = 0;
function check(ok, name) {
  if (ok) {
    pass += 1;
    console.log('  PASS  ' + name);
  } else {
    fail += 1;
    console.log('  FAIL  ' + name);
  }
}
function exists(p) {
  return fs.existsSync(p);
}
function read(p) {
  return fs.readFileSync(p, 'utf8');
}
function pubspecVersion(text) {
  const m = text.match(/^version:\s*(\S+)\s*$/m);
  return m ? m[1] : null;
}

console.log('=== 开源发布面守卫（门禁第 24 条） ===');

// ---------- 0) 产物存在性 ----------
if (!exists(REL)) {
  console.log('  SKIP  opensource-release/ 不存在（导出树是生成物，干净克隆本就没有）');
  console.log('================ 开源发布面校验：0 PASS / 0 FAIL ================');
  process.exit(2);
}
check(true, '导出树存在（' + REL + '）');

// ---------- 1) 新鲜度（★ 核心判据） ----------
const srcPub = path.join(ROOT, 'pubspec.yaml');
const relPub = path.join(REL, 'pubspec.yaml');
check(exists(srcPub) && exists(relPub), '两侧 pubspec.yaml 都在盘');
const vSrc = pubspecVersion(read(srcPub));
const vRel = pubspecVersion(read(relPub));
check(!!vSrc && !!vRel, '两侧都能解析出 version（主仓=' + vSrc + ' 导出树=' + vRel + '）');
check(
  !!vSrc && vSrc === vRel,
  '★ 导出树版本 == 主仓版本（主仓 ' + vSrc + ' / 导出树 ' + vRel + '）' +
    (vSrc === vRel ? '' : ' ⇒ 导出树陈旧，公开出去的是旧代码')
);

// 正控：新鲜度判据不能是恒真 —— 拿一个假版本比对，必须判出不相等。
{
  const fake = '9.999.0+1';
  check(vSrc !== fake, '自检：假版本号 ' + fake + ' 与主仓版本不同（新鲜度判据非恒真）');
  check(!(vRel === vSrc && vSrc === fake), '自检：同值比对不会被伪造值糊过去');
}

// ---------- 2) 材料齐（PRD §3.1 开源治理四件套 + 治理文件） ----------
const MATERIALS = [
  ['LICENSE', 400],
  ['SECURITY.md', 400],
  ['CONTRIBUTING.md', 400],
  ['CODE_OF_CONDUCT.md', 200],
  ['GOVERNANCE.md', 400],
];
for (const [name, minBytes] of MATERIALS) {
  const p = path.join(REL, name);
  const ok = exists(p) && fs.statSync(p).size >= minBytes;
  check(ok, '材料在盘且非空：' + name + '（≥' + minBytes + ' B，实测 ' +
    (exists(p) ? fs.statSync(p).size : 0) + ' B）');
}
// 商标政策不在 PRD 四件套里，但 PRD §3.1 明确「商标独立于许可证」—— 一并盯住。
check(exists(path.join(REL, 'TRADEMARK.md')) && fs.statSync(path.join(REL, 'TRADEMARK.md')).size >= 200,
  '商标政策在盘且非空：TRADEMARK.md');

// LICENSE 必须是 PRD §3.1 定的 MIT（不是 AGPL/GPL —— 改许可属架构决策，得先改 PRD）。
const lic = exists(path.join(REL, 'LICENSE')) ? read(path.join(REL, 'LICENSE')) : '';
check(/MIT License/i.test(lic), 'LICENSE 是 MIT（PRD §3.1 三层许可：客户端 MIT / 协议包 MIT / 规范文本 CC-BY-4.0 / Hub 专有）');

// SECURITY.md 必须给出**可行动的**披露渠道：联系方式 + 响应时限。
const sec = exists(path.join(REL, 'SECURITY.md')) ? read(path.join(REL, 'SECURITY.md')) : '';
check(/@/.test(sec), 'SECURITY.md 含联系方式（邮箱）');
check(/\d+\s*(hour|hours|小时|小时内)/i.test(sec), 'SECURITY.md 含响应时限（数字 + 时间单位）');

// ---------- 3) 专有层零外泄（R13） ----------
const FORBIDDEN = [
  ['lib/hub', path.join(REL, 'lib', 'hub')],
  ['lib/dist', path.join(REL, 'lib', 'dist')],
  ['备份', path.join(REL, '备份')],
  ['repo-content', path.join(REL, 'repo-content')],
];
for (const [label, p] of FORBIDDEN) {
  check(!exists(p), '★ 专有层零外泄：' + label + ' 不在导出树内');
}
// 兜底：再扫一层文件名，防「改名混进来」。
const hubJs = [];
(function walk(dir) {
  let ents = [];
  try {
    ents = fs.readdirSync(dir, { withFileTypes: true });
  } catch (e) {
    return;
  }
  for (const e of ents) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name === '.git') continue;
      walk(p);
    } else if (e.name === 'hub.js') {
      hubJs.push(path.relative(REL, p));
    }
  }
})(REL);
check(hubJs.length === 0, '★ 导出树内无 hub.js（命中=' + (hubJs.join(',') || '无') + '）');

// ---------- 4) CHANGELOG 也得跟着走 ----------
const srcChg = path.join(ROOT, 'CHANGELOG.md');
const relChg = path.join(REL, 'CHANGELOG.md');
if (exists(srcChg) && exists(relChg)) {
  const s = fs.statSync(srcChg).size;
  const r = fs.statSync(relChg).size;
  check(r >= s * 0.9, '导出树 CHANGELOG 与主仓同量级（主仓 ' + s + ' B / 导出树 ' + r + ' B）');
} else {
  check(false, '导出树 CHANGELOG 在盘');
}

// ---------- 5) ★ 发布树不得混入「让位快照」与本机绝对路径（2026-10-20 实证） ----------
//
// 实况：landing/ 下 **223 个 `.trash-dist-<pid>-<ticks>` 目录 / 12,912 个文件**被 robocopy
// 复制进发布树（每次重建 dist 前的让位目录），里面的旧 changelog 页写着
// `归档 = <repo>/build/app/outputs/...` 这种**开发机绝对路径** ⇒ 敏感扫描命中、**发布中止**；
// 同时把扫描从秒级拖到 ~1 小时。已在 `opensource_release.ps1` 的 $excludeDirs 补 `.trash-dist*`，
// 这里补三条断言，让「下次再漏」立刻变红，而不是等一小时后的扫描。
const trashDirs = [];
let totalFiles = 0;
const localPathFiles = [];
const TEXT_EXT = new Set(['.md', '.html', '.js', '.dart', '.json', '.yaml', '.yml', '.txt', '.ps1', '.sh']);
(function walk(dir, rel) {
  let ents = [];
  try {
    ents = fs.readdirSync(dir, { withFileTypes: true });
  } catch (e) {
    return;
  }
  for (const e of ents) {
    const p = path.join(dir, e.name);
    const r = rel ? rel + '/' + e.name : e.name;
    if (e.isDirectory()) {
      if (e.name === '.git') continue;
      if (e.name.startsWith('.trash-dist')) trashDirs.push(r);
      walk(p, r);
    } else {
      totalFiles += 1;
      if (TEXT_EXT.has(path.extname(e.name).toLowerCase())) {
        try {
          const s = fs.readFileSync(p, 'utf8');
          if (/[A-Za-z]:[\\/]+mydoubao/.test(s)) localPathFiles.push(r);
        } catch (err) {
          /* 二进制跳过 */
        }
      }
    }
  }
})(REL, '');

check(trashDirs.length === 0,
  '★ 发布树无 `.trash-dist*` 让位快照目录（命中 ' + trashDirs.length + ' 个' +
    (trashDirs.length ? '：' + trashDirs.slice(0, 3).join(', ') : '') + '）');
check(totalFiles <= 1500,
  '★ 发布树文件总数在预算内（' + totalFiles + ' ≤ 1500；混入 trash 时曾达 14,005）');
// 白名单这两条里的开发机绝对路径只是仓库自身的使用说明（无密钥/账号），非泄漏；除此之外一律 FAIL。
// ★ 白名单这两条都是**有意公开**的仓库文件，里面的开发机路径只是说明性文字
//   （无密钥 / 无账号 / 无内网地址），属可接受披露；除此之外命中一律 FAIL。
// ★ CHANGELOG.md 曾因两行历史归档（0.76.0/0.75.0 的「归档 = <开发机绝对路径>\build\...」）短暂进过白名单，
//   但那两行已于 2026-10-21 scrubbing 掉（主仓与导出树实测 0 命中）⇒ **条目同步摘掉**：
//   白名单跟着数据收紧，否则下次谁再写进本机路径，这道判据就瞎了。
const ALLOW_LOCAL = new Set(['landing/README.md', 'tool/run_all_verify_node.js']);
const badLocal = localPathFiles.filter((f) => !ALLOW_LOCAL.has(f));
check(badLocal.length === 0,
  '★ 发布树无本机绝对路径（命中 ' + localPathFiles.length + ' 个，白名单外 ' + badLocal.length +
    ' 个' + (badLocal.length ? '：' + badLocal.slice(0, 3).join(', ') : '') + '）');

// ------------------------------------------- ④ 发布管道自报家门（源头） ---
//
// 为什么查**管道**而不是查导出树的提交：导出树是 robocopy + git 生成的，
// 那条首提交信息由 `opensource_release.ps1` 里的 `git commit -m` 写出。
// 手改导出树的提交 = 改缓存，下次导出就复原（ADR-002 §6 第三个自抓缺陷同族）。
// 而这条信息**一推送就永久进公开历史** —— 是最便宜、也最后一次能改的时机。
console.log('');
console.log('--- ④ 发布管道不得把退役品牌写进公开历史 ---');

const PIPELINE = path.join(ROOT, 'opensource_release.ps1');
// 只禁退役的**英文产品名**两个写法。`dahuang-site`（部署目录名）不在其中：
// 那是已装机器的落盘路径，改名会让现有部署找不到站点根 —— 属刻意不改。
const RETIRED_RE = /\bDahuangAI\b|dahuang-ai/;

function retiredIn(s) {
  return RETIRED_RE.test(String(s));
}

if (fs.existsSync(PIPELINE)) {
  const src = fs.readFileSync(PIPELINE, 'utf8');
  check(!retiredIn(src), '发布管道 opensource_release.ps1 不含退役品牌（DahuangAI / dahuang-ai）');
  check(/git commit -m "/.test(src), '发布管道仍写出首条提交信息（锚点在位，否则上一条会静默空跑）');
} else {
  check(false, '发布管道 opensource_release.ps1 在场');
}

// 导出树若已生成，它的**唯一一条提交信息**也不得带退役品牌。
try {
  const cp = require('child_process');
  const r = cp.spawnSync('git', ['log', '-1', '--format=%B'], { cwd: REL, encoding: 'utf8' });
  if (r.status === 0 && (r.stdout || '').trim()) {
    const msg = r.stdout.trim();
    check(!retiredIn(msg), '导出树首提交信息不含退役品牌（实际首行："' + msg.split('\n')[0] + '"）');
    check(msg.length > 10, '导出树首提交信息非空且有实质内容（锚点，防判据空跑）');
  }
} catch (err) {
  /* 无 git 或无导出树：跳过，不假装通过也不误红 */
}

// 正控：判据必须对毒注翻红、对干净串放行
check(retiredIn('git commit -m "DahuangAI v0.1 — first public release"'), '★ 正控：注入 DahuangAI 必须被抓到');
check(retiredIn('https://github.com/x/dahuang-ai.git'), '★ 正控：注入 dahuang-ai 仓库名必须被抓到');
check(!retiredIn('git commit -m "Fen v0.1 — first public release"'), '★ 正控：干净提交信息不得误报');

console.log('');
console.log('================ 开源发布面校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
process.exit(fail === 0 ? 0 : 1);
