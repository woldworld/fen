#!/usr/bin/env node
/**
 * Security page verification (0.104.0 / 整改方案阶段 E).
 *
 * Why this exists: a security page is the easiest page on the site to lie on.
 * The failure mode is not a crash - it is a sentence nobody can point at in
 * the source, which then gets quoted back to us as a promise. So every claim
 * on /security/ carries a `proof` field of the form "path::keyword", and this
 * script opens that file and checks the keyword is really there.
 *
 * Also pinned:
 *   - the two languages stay structurally identical (the 0.95.0 half-wiring
 *     bug: one locale fixed, the other silently left behind);
 *   - the nav entry points at a file that actually exists (ADR-001 / the
 *     0.99.0 dead-CTA bug);
 *   - the page keeps its "this is not an audit" banner;
 *   - offline self-sufficiency: no external resource, no foreign anchor.
 *
 *   node tool/verify_landing_security.js
 */

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const LANDING = path.join(ROOT, 'landing');
const DIST = path.join(LANDING, 'dist');
const DATA = path.join(LANDING, 'data');

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

const OWN = String(readJsonSafe(path.join(DATA, 'site.json')).brand.domain).replace(/\/+$/, '');

console.log('=== 安全机制页 /security/ 校验 ===');

// -------------------------------------------------------------- data -----

const FILES = [
  { tag: 'EN', rel: 'landing/data/security.json', d: null, p: null },
  { tag: 'ZH', rel: 'landing/data/security-zh.json', d: null, p: null },
];
FILES.forEach((f) => {
  f.p = path.join(ROOT, f.rel);
  check(exists(f.p), f.tag + ' 数据文件存在（' + f.rel + '）');
  if (exists(f.p)) f.d = readJsonSafe(f.p);
});

const TOP_KEYS = ['eyebrow', 'title', 'h1', 'lede', 'notice', 'groups', 'proofNote',
  'boundaryTitle', 'boundary', 'ctaLabel', 'ctaHref'];

FILES.forEach((f) => {
  if (!f.d) return;
  const miss = TOP_KEYS.filter(
    (k) => !(k in f.d) || String(f.d[k] == null ? '' : f.d[k]).trim() === ''
  );
  check(miss.length === 0, f.tag + ' 顶层文案键齐全' + (miss.length ? '（缺 ' + miss.join(',') + '）' : ''));
  check(Array.isArray(f.d.groups) && f.d.groups.length === 4, f.tag + ' 机制分组为 4 组');
  const items = (f.d.groups || []).reduce((n, g) => n + ((g.items || []).length), 0);
  check(items === 8, f.tag + ' 机制条目为 8 条（当前 ' + items + '）');
  const noProof = [];
  (f.d.groups || []).forEach((g) =>
    (g.items || []).forEach((it) => {
      if (!it.proof || it.proof.indexOf('::') === -1) noProof.push(it.title);
    })
  );
  check(noProof.length === 0, f.tag + ' 每条机制都带 proof 锚点' + (noProof.length ? '（缺 ' + noProof.join(',') + '）' : ''));
});

// ------------------------------------------------- proof must be real -----

console.log('');
console.log('--- proof 锚点实证（关键词必须真在文件里）---');

function proofOk(proof) {
  if (!proof || proof.indexOf('::') === -1) return false;
  const i = proof.lastIndexOf('::');
  const rel = proof.slice(0, i);
  const kw = proof.slice(i + 2);
  const abs = path.join(ROOT, rel);
  if (!exists(abs)) return false;
  return fs.readFileSync(abs, 'utf8').indexOf(kw) !== -1;
}

FILES.forEach((f) => {
  if (!f.d) return;
  const seen = new Set();
  const bad = [];
  (f.d.groups || []).forEach((g) =>
    (g.items || []).forEach((it) => {
      if (!it.proof || it.proof.indexOf('::') === -1) return;
      const key = it.proof;
      if (seen.has(key)) return;
      seen.add(key);
      if (!proofOk(it.proof)) bad.push(it.proof);
    })
  );
  check(bad.length === 0, f.tag + ' 全部 proof 关键词命中源码' + (bad.length ? '（' + bad.join(' | ') + '）' : ''));
});

// Calendar red line (R17): READ declared, WRITE must be absent.
const mfPath = path.join(ROOT, 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
const mf = fs.readFileSync(mfPath, 'utf8');
check(mf.indexOf('android.permission.READ_CALENDAR') !== -1, 'R17：Manifest 声明 READ_CALENDAR');
check(mf.indexOf('android.permission.WRITE_CALENDAR') === -1, '★ R17 反向：Manifest 内无 WRITE_CALENDAR 声明');

// ------------------------------------------------------- bilingual parity --

console.log('');
console.log('--- 双语同构 ---');

const E = FILES[0].d;
const Z = FILES[1].d;
if (E && Z) {
  check(JSON.stringify(Object.keys(E).sort()) === JSON.stringify(Object.keys(Z).sort()),
    'EN/ZH 顶层键集合一致');
  check(E.groups.length === Z.groups.length, 'EN/ZH 分组数一致（' + E.groups.length + '）');
  const sig = (d) =>
    d.groups.map((g) => g.items.length + ':' + g.items.map((i) => i.proof || '-').join(',')).join('|');
  check(sig(E) === sig(Z), 'EN/ZH 每组条目数与 proof 锚点一一对应');
  check(E.groups.map((g) => g.title).join('|') !== Z.groups.map((g) => g.title).join('|'),
    'EN/ZH 分组标题已本地化（非英文冒充译文）');
}

// ------------------------------------------------------------- built page ---

console.log('');
console.log('--- 构建产物 ---');

const OUT = [
  { tag: 'EN', rel: 'security/index.html', canon: OWN + '/security/', alt: OWN + '/zh/security/', hreflang: 'zh' },
  { tag: 'ZH', rel: 'zh/security/index.html', canon: OWN + '/zh/security/', alt: OWN + '/security/', hreflang: 'en' },
];

OUT.forEach((o) => {
  const abs = path.join(DIST, o.rel);
  check(exists(abs), o.tag + ' 产物存在：' + o.rel);
  if (!exists(abs)) return;
  const h = fs.readFileSync(abs, 'utf8');
  check((h.match(/class="sec-group"/g) || []).length === 4, o.tag + ' 页面含 4 个机制分组');
  check((h.match(/class="sec-item"/g) || []).length === 8, o.tag + ' 页面含 8 条机制');
  check((h.match(/class="sec-proof"/g) || []).length === 8, o.tag + ' 页面含 8 个 proof 锚点');
  check(/id="security-notice"/.test(h) && /not a third-party audit|不是第三方审计/.test(h),
    o.tag + ' 页面带「不是第三方审计」诚实横幅');
  check(h.indexOf('rel="canonical" href="' + o.canon + '"') !== -1, o.tag + ' canonical 正确');
  check(h.indexOf('hreflang="' + o.hreflang + '" href="' + o.alt + '"') !== -1, o.tag + ' hreflang 互指正确');

  const foreign = [];
  for (const m of h.matchAll(/href="(https?:\/\/[^"]+)"/g)) {
    if (m[1].indexOf(OWN) !== 0) foreign.push(m[1]);
  }
  check(foreign.length === 0, o.tag + ' 无自身域名之外的外部锚点' + (foreign.length ? '（' + foreign.join(',') + '）' : ''));

  const extRes = [];
  for (const m of h.matchAll(/<(?:img|script|link|iframe|source)[^>]*?(?:src|href)="(https?:\/\/[^"]+)"/g)) {
    if (m[1].indexOf(OWN) !== 0) extRes.push(m[1]);
  }
  check(extRes.length === 0, o.tag + ' 无外部资源引用（离线自足）' + (extRes.length ? '（' + extRes.join(',') + '）' : ''));
});

// ------------------------------------------------------------------ nav -----

console.log('');
console.log('--- 导航接线（防 0.99.0 指向不存在的页）---');

const homeEn = exists(path.join(DIST, 'index.html')) ? fs.readFileSync(path.join(DIST, 'index.html'), 'utf8') : '';
const homeZh = exists(path.join(DIST, 'zh', 'index.html')) ? fs.readFileSync(path.join(DIST, 'zh', 'index.html'), 'utf8') : '';

check(homeEn.indexOf('href="/security/"') !== -1, 'EN 导航含 /security/ 入口');
check(homeZh.indexOf('href="/zh/security/"') !== -1, 'ZH 导航含 /zh/security/ 入口');
check(exists(path.join(DIST, 'security', 'index.html')), '★ /security/ 目标文件真实存在');
check(exists(path.join(DIST, 'zh', 'security', 'index.html')), '★ /zh/security/ 目标文件真实存在');

[
  { tag: 'EN', h: homeEn },
  { tag: 'ZH', h: homeZh },
].forEach((p) => {
  const hrefs = [];
  const navm = p.h.match(/<nav class="nav"[^>]*>([\s\S]*?)<\/nav>/);
  if (navm) {
    for (const a of navm[1].matchAll(/href="([^"]+)"/g)) hrefs.push(a[1]);
  }
  const dead = hrefs.filter((x) => {
    const file = x.split('#')[0].replace(/^\//, '');
    if (!file) return false;
    return !exists(path.join(DIST, file, 'index.html'));
  });
  check(hrefs.length === 6, p.tag + ' 导航为 6 项（当前 ' + hrefs.length + '）');
  check(dead.length === 0, p.tag + ' 导航无死链' + (dead.length ? '（' + dead.join(',') + '）' : ''));
});

console.log('');
console.log('--- 正控（证明判据真的会翻红）---');

check(!proofOk('lib/hub/hub.js::TOTALLY_NOT_A_KEYWORD_0104'),
  '★ 正控：编造的 proof 关键词必须被抓到');
check(!proofOk('lib/hub/does_not_exist_0104.js::ROTATE'),
  '★ 正控：指向不存在文件的 proof 必须被抓到');
check(proofOk('lib/hub/hub.js::ROTATE'), '★ 正控：真实 proof 不得误报');
check(mf.indexOf('android.permission.WRITE_CALENDAR') === -1,
  '★ 正控：R17 反向判据在真实 Manifest 上成立');

console.log('');
console.log('================ 安全机制页校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
