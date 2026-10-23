#!/usr/bin/env node
/**
 * Eight-step Agent demo verification (0.103.0 / 整改方案阶段 D).
 *
 * Why this exists: the whole point of the /demo/ page is that a stranger can
 * understand what our agents actually DO. Three ways that silently breaks, none
 * of which shows up as a build failure:
 *
 *   1. A step loses one of its two columns. The page still renders, but now it
 *      only tells half the story - "what happened" without "what you control"
 *      is exactly the fear we are trying to answer.
 *   2. The "scripted scenario" banner gets dropped in a redesign. A demo that
 *      looks like a live system is a lie, and R27 says claims must be checkable.
 *   3. The two languages drift apart (one file edited, the other not) - that is
 *      the 0.95.0 half-wiring bug: same component, one locale still broken.
 *
 * The player is also pinned to be honest when JS is off: with no script the
 * buttons must ship disabled rather than looking live and doing nothing (R14).
 *
 *   node tool/verify_landing_demo.js
 */

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const LANDING = path.join(ROOT, 'landing');
const DIST = path.join(LANDING, 'dist');
const DATA = path.join(LANDING, 'data');
const BUILD_JS = path.join(LANDING, 'build.js');

let pass = 0;
let fail = 0;

function check(ok, label) {
  if (ok) {
    pass++;
    console.log('  PASS  ' + label);
  } else {
    fail++;
    console.log('  FAIL  ' + label);
  }
}

function readJsonSafe(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function exists(p) {
  return fs.existsSync(p);
}

console.log('=== Agent 八步演示页校验 ===');

// ------------------------------------------------------------- glossary ---

const site = readJsonSafe(path.join(DATA, 'site.json'));
// Trailing slash stripped: our own canonical URLs are all "https://wold.world/…",
// so a bare `indexOf` comparison has to normalise the root first.
const OWN = String(site.brand.domain).replace(/\/+$/, '');

const glossary = readJsonSafe(path.join(DATA, 'glossary.json'));
const banned = [];
glossary
  .filter((e) => e.homepageHighlight === false)
  .forEach((e) => {
    [e.term, e.zh].forEach((v) => {
      if (v && banned.indexOf(v) === -1) banned.push(v);
    });
  });

// ------------------------------------------------------------- helpers ---

const LABEL_KEYS = [
  'eyebrow', 'h1', 'lede', 'notice', 'intentLabel', 'intent',
  'playLabel', 'pauseLabel', 'resetLabel', 'nextLabel',
  'progressLabel', 'progressSuffix', 'happenedLabel', 'controlLabel',
  'checkEyebrow', 'checkTitle', 'ctaLabel', 'ctaHref',
];

const STEP_KEYS = ['no', 'title', 'happened', 'control'];
const CHECK_KEYS = ['q', 'a'];

function keysOf(o) {
  return Object.keys(o).sort();
}

// English needs no suffix after "Step 3 / 8", so progressSuffix is legitimately
// blank there. It must still be PRESENT in both files - a missing key is
// half-wiring; a blank value is just grammar.
const OPTIONAL_EMPTY = new Set(['progressSuffix']);

function missingKeys(o, ks) {
  return ks.filter((k) => {
    if (!(k in (o || {}))) return true;
    const v = String(o[k] == null ? '' : o[k]).trim();
    return v === '' && !OPTIONAL_EMPTY.has(k);
  });
}

const HONEST = /scripted|scenario|剧本|模拟/i;

// Extracted so the positive controls at the bottom exercise the *same*
// predicate the real assertions use - a control that tests its own private
// copy of the rule proves nothing.
function eightSteps(d) {
  return Array.isArray(d && d.steps) && d.steps.length === 8;
}
function hasBanner(html) {
  return /id="demo-banner"/.test(html) && HONEST.test(html);
}

console.log('');
console.log('--- 数据层：两份数据文件齐全且完整 ---');

const files = [
  { tag: 'EN', p: path.join(DATA, 'demo.json'), d: demoEn() },
  { tag: 'ZH', p: path.join(DATA, 'demo-zh.json'), d: demoZh() },
];

function demoEn() {
  return exists(path.join(DATA, 'demo.json')) ? readJsonSafe(path.join(DATA, 'demo.json')) : null;
}
function demoZh() {
  return exists(path.join(DATA, 'demo-zh.json')) ? readJsonSafe(path.join(DATA, 'demo-zh.json')) : null;
}

files.forEach((f) => {
  check(exists(f.p), f.tag + ' 数据文件存在（' + path.relative(ROOT, f.p) + '）');
  if (!f.d) return;
  check(f.d.simulated === true, f.tag + ' simulated === true（演示必须自认是剧本）');
  const missTop = missingKeys(f.d, LABEL_KEYS);
  check(missTop.length === 0, f.tag + ' 文案键齐全' + (missTop.length ? '（缺 ' + missTop.join(',') + '）' : ''));
  check(eightSteps(f.d),
    f.tag + ' 步骤数为 8（当前 ' + (f.d.steps ? f.d.steps.length : 0) + '）');
  const badSteps = (f.d.steps || []).filter((s) => missingKeys(s, STEP_KEYS).length);
  check(badSteps.length === 0,
    f.tag + ' 每步含 no/title/happened/control 四键且非空' + (badSteps.length ? '（' + badSteps.length + ' 步缺列）' : ''));
  check(Array.isArray(f.d.checks) && f.d.checks.length === 5,
    f.tag + ' 验收问题为 5 条（当前 ' + (f.d.checks ? f.d.checks.length : 0) + '）');
  const badChecks = (f.d.checks || []).filter((c) => missingKeys(c, CHECK_KEYS).length);
  check(badChecks.length === 0, f.tag + ' 每条验收含 q/a' + (badChecks.length ? '（' + badChecks.length + ' 条缺）' : ''));
  check(typeof f.d.ctaHref === 'string' && f.d.ctaHref.charAt(0) === '/',
    f.tag + ' ctaHref 为站内绝对路径（当前 ' + f.d.ctaHref + '）');
  check(HONEST.test(String(f.d.notice || '')), f.tag + ' notice 含「剧本化情景」诚实标注');
});

console.log('');
console.log('--- 双语同构（防半接线） ---');

const E = demoEn();
const Z = demoZh();
if (E && Z) {
  const ke = keysOf(E);
  const kz = keysOf(Z);
  const onlyE = ke.filter((k) => kz.indexOf(k) === -1);
  const onlyZ = kz.filter((k) => ke.indexOf(k) === -1);
  check(onlyE.length === 0 && onlyZ.length === 0,
    '两份数据顶层键集合一致' + (onlyE.length || onlyZ.length ? '（差 ' + onlyE.concat(onlyZ).join(',') + '）' : ''));
  check(E.steps.length === Z.steps.length, 'EN/ZH 步骤数一致（' + E.steps.length + ' / ' + Z.steps.length + '）');
  check(E.checks.length === Z.checks.length, 'EN/ZH 验收题数一致（' + E.checks.length + ' / ' + Z.checks.length + '）');
  const stepKeyDiff = [];
  E.steps.forEach((s, i) => {
    const z = Z.steps[i];
    if (!z) return;
    const a = keysOf(s);
    const b = keysOf(z);
    if (a.join('|') !== b.join('|')) stepKeyDiff.push('#' + (i + 1));
  });
  check(stepKeyDiff.length === 0, 'EN/ZH 每步字段一致' + (stepKeyDiff.length ? '（差 ' + stepKeyDiff.join(',') + '）' : ''));
  check(E.steps.map((s) => s.no).join(',') === Z.steps.map((s) => s.no).join(','),
    'EN/ZH 步骤序号一一对应');
}

console.log('');
console.log('--- 构建产物 ---');

const OUT = [
  { tag: 'EN', rel: 'demo/index.html', canon: 'https://wold.world/demo/', alt: 'https://wold.world/zh/demo/', hreflang: 'zh' },
  { tag: 'ZH', rel: 'zh/demo/index.html', canon: 'https://wold.world/zh/demo/', alt: 'https://wold.world/demo/', hreflang: 'en' },
];

const pages = OUT.map((o) => {
  const abs = path.join(DIST, o.rel);
  check(exists(abs), o.tag + ' 产物存在：' + o.rel);
  return { o, html: exists(abs) ? fs.readFileSync(abs, 'utf8') : '' };
});

pages.forEach(({ o, html }) => {
  if (!html) return;
  check((html.match(/class="demo-step"/g) || []).length === 8, o.tag + ' 页面含 8 个步骤块');
  check((html.match(/class="demo-dot"/g) || []).length === 8, o.tag + ' 页面含 8 个进度点');
  const hap = (html.match(/class="demo-col demo-happened"/g) || []).length;
  const ctl = (html.match(/class="demo-col demo-control"/g) || []).length;
  check(hap === 8 && ctl === 8, o.tag + ' 每步双栏齐全（happened ' + hap + ' / control ' + ctl + '，应各 8）');
  check((html.match(/class="check-item"/g) || []).length === 5, o.tag + ' 页面含 5 条验收');
  check(hasBanner(html), o.tag + ' 页面带「剧本化情景」诚实标注横幅');
  check(/<script>/.test(html) && !/<script[^>]+src=/.test(html), o.tag + ' 播放器为内联脚本（无外部 script）');
  ['demo-play', 'demo-next', 'demo-reset'].forEach((id) => {
    check(new RegExp('id="' + id + '"[^>]*disabled').test(html), o.tag + ' #' + id + ' 初始为 disabled（无 JS 不给假状态）');
  });
  check(html.indexOf('rel="canonical" href="' + o.canon + '"') !== -1, o.tag + ' canonical 正确（' + o.canon + '）');
  check(html.indexOf('hreflang="' + o.hreflang + '" href="' + o.alt + '"') !== -1, o.tag + ' hreflang 互指正确');
  // ADR-001: no anchor may point at a host that is not ours.
  const foreign = [];
  for (const m of html.matchAll(/href="(https?:\/\/[^"]+)"/g)) {
    if (m[1].indexOf(OWN) !== 0) foreign.push(m[1]);
  }
  check(foreign.length === 0, o.tag + ' 无自身域名之外的外部锚点' + (foreign.length ? '（' + foreign.join(',') + '）' : ''));
  const extRes = [];
  for (const m of html.matchAll(/<(?:img|script|link|iframe|source)[^>]*?(?:src|href)="(https?:\/\/[^"]+)"/g)) {
    // <link rel="canonical"> points at our own host - that is self-reference,
    // not an external resource. Only foreign hosts break offline rendering.
    if (m[1].indexOf(OWN) !== 0) extRes.push(m[1]);
  }
  check(extRes.length === 0, o.tag + ' 无外部资源引用（离线自足）' + (extRes.length ? '（' + extRes.join(',') + '）' : ''));
});

console.log('');
console.log('--- 术语纪律（故事名/内部名不得进入演示正文） ---');

pages.forEach(({ o, html }) => {
  const blocks = [];
  const grab = (cls) => {
    const re = new RegExp('<(?:ol|div) class="' + cls + '"[\\s\\S]*?<\\/(?:ol|div)>', 'g');
    let m;
    while ((m = re.exec(html)) !== null) blocks.push(m[0]);
  };
  grab('demo-flow');
  grab('check-grid');
  const hits = [];
  blocks.forEach((b) => {
    banned.forEach((t) => {
      if (b.indexOf(t) !== -1 && hits.indexOf(t) === -1) hits.push(t);
    });
  });
  check(blocks.length >= 2, o.tag + ' 取到演示正文区块（' + blocks.length + ' 块）');
  check(hits.length === 0, o.tag + ' 演示正文无「首页不突出」术语' + (hits.length ? '（命中 ' + hits.join(',') + '）' : ''));
});

console.log('');
console.log('--- 首页演示门接线（防 0.99.0 指向不存在的页） ---');

const homeEn = exists(path.join(DIST, 'index.html')) ? fs.readFileSync(path.join(DIST, 'index.html'), 'utf8') : '';
const homeZh = exists(path.join(DIST, 'zh', 'index.html')) ? fs.readFileSync(path.join(DIST, 'zh', 'index.html'), 'utf8') : '';

check(homeEn.indexOf('href="/demo/"') !== -1, 'EN 首页演示门指向 /demo/');
check(homeZh.indexOf('href="/zh/demo/"') !== -1, 'ZH 首页演示门指向 /zh/demo/');
check(exists(path.join(DIST, 'demo', 'index.html')), '★ /demo/ 目标文件真实存在（不是又一个 404）');
check(exists(path.join(DIST, 'zh', 'demo', 'index.html')), '★ /zh/demo/ 目标文件真实存在');

console.log('');
console.log('--- 源码钉（构建注册不可被折叠掉） ---');

const bsrc = fs.readFileSync(BUILD_JS, 'utf8');
check(bsrc.indexOf("written.push('demo/index.html')") !== -1, "build.js 含字面量 written.push('demo/index.html')");
check(bsrc.indexOf("written.push('zh/demo/index.html')") !== -1, "build.js 含字面量 written.push('zh/demo/index.html')");
check(bsrc.indexOf("readJson(path.join(DATA, 'demo.json'))") !== -1, 'build.js 读取 demo.json');
check(bsrc.indexOf("readJson(path.join(DATA, 'demo-zh.json'))") !== -1, 'build.js 读取 demo-zh.json');

console.log('');
console.log('--- 正控（证明判据真的会翻红） ---');

function bannedIn(block) {
  return banned.filter((t) => block.indexOf(t) !== -1);
}

check(bannedIn('<ol class="demo-flow">' + banned[0] + '</ol>').length > 0,
  '★ 正控：向演示正文注入禁用术语「' + banned[0] + '」必须被抓到');
check(bannedIn('<ol class="demo-flow">Fen talks to another agent.</ol>').length === 0,
  '★ 正控：干净演示正文不得误报');
check(!hasBanner('<div>Interactive demo with sample data.</div>'),
  '★ 正控：去掉「scripted scenario」标注的页面必须被抓到');
check(!eightSteps({ steps: new Array(7).fill({}) }),
  '★ 正控：步数为 7 的数据必须被「步骤数为 8」判据抓到');
check(missingKeys({ no: '1', title: 't', happened: 'h' }, STEP_KEYS).length > 0,
  '★ 正控：缺 control 列的步骤必须被抓到');

console.log('');
console.log('================ 演示页校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
