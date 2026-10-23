#!/usr/bin/env node
/**
 * Machine-readable surface verification (llms.txt / llms-full.txt / /docs /faq /changelog meta).
 *
 * Why this exists — two real defects, both invisible from "the site builds":
 *
 *   1. DEAD BRAND. `landing/build.js` had `DahuangAI` hardcoded in exactly the
 *      four places an agent reads first (llms.txt H1, /docs/ meta, /faq/ meta,
 *      /changelog/ meta) while EVERY other page took its name from
 *      `site.json.brand` (platform "Wold" / app "Fen"). So the human-facing
 *      site said "Wold / Fen" and the agent-facing site said "DahuangAI" — a
 *      retired brand. `build.js:632` already states the rule: 大荒AI is a
 *      story/internal name, not a product name.
 *
 *   2. DEAD LINK. llms.txt line 3 pointed at `github.com/woldworld/dahuang`
 *      (retired brand) — both that repo and `woldworld/fen` return 404, so
 *      every agent reading llms.txt learned that our source is "published"
 *      at an address that does not exist.
 *
 * This guard asserts the OUTPUT in `landing/dist`, not the source. Judging the
 * source would let a change sit in `build.js` unshipped and still read green.
 *
 *   node tool/verify_landing_machinereadable.js
 */

'use strict';

const fs = require('fs');
const path = require('path');

const LANDING = path.join(__dirname, '..', 'landing');
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

// ------------------------------------------------------------- helpers ---

// The retired ENGLISH product name. Word-bounded on purpose: `Dahuang` (no AI)
// is the WORLD name — "The World of Dahuang" ↔ "大荒世界" — which is a
// deliberate, still-current piece of worldbuilding. A bare `includes('Dahuang')`
// would wrongly ban the world name too; that is the exact "judgment aimed at the
// wrong object" failure this project keeps hitting (see R34 / R35).
const RETIRED_RE = /\bDahuangAI\b/g;

function retiredHits(text) {
  return (String(text).match(RETIRED_RE) || []);
}

// URL must stop at punctuation that closes a sentence or a markdown link.
// `https://;` shows up in real KB prose ("Hub address starts with https://; 2)")
// — without the `;` exclusion the extractor invents a broken URL.
const URL_RE = /https?:\/\/[^\s)\]>,;"'》]+/g;

function urlsIn(text) {
  return String(text).match(URL_RE) || [];
}

function metaOf(html) {
  const title = (html.match(/<title>([\s\S]*?)<\/title>/) || [])[1] || '';
  const desc = (html.match(/<meta\s+name="description"\s+content="([^"]*)"/) || [])[1] || '';
  return { title: title, desc: desc };
}

function readIf(p) {
  try {
    return fs.readFileSync(p, 'utf8');
  } catch (e) {
    return null;
  }
}

console.log('=== 官网机器可读面校验（llms / docs / faq / changelog） ===');

// ------------------------------------------------------ authoritative ---

const site = JSON.parse(fs.readFileSync(path.join(DATA, 'site.json'), 'utf8'));
const brand = site.brand || {};
const DOMAIN = String(brand.domain || '').replace(/\/+$/, '');

check(!!brand.platform && !!brand.app, 'site.json 权威品牌定义齐备（platform=' + brand.platform + ' / app=' + brand.app + '）');
check(!!DOMAIN, 'site.json 权威域名非空（' + DOMAIN + '）');

// ------------------------------------------------------------ 产物存在 ---

const llms = readIf(path.join(DIST, 'llms.txt'));
const llmsFull = readIf(path.join(DIST, 'llms-full.txt'));
const docsHtml = readIf(path.join(DIST, 'docs', 'index.html'));
const faqHtml = readIf(path.join(DIST, 'faq', 'index.html'));
const logHtml = readIf(path.join(DIST, 'changelog', 'index.html'));
const worldHtml = readIf(path.join(DIST, 'world', 'index.html'));
const zhDocsHtml = readIf(path.join(DIST, 'zh', 'docs', 'index.html'));

check(!!llms, '产物存在：llms.txt');
check(!!llmsFull, '产物存在：llms-full.txt');
check(!!docsHtml, '产物存在：/docs/');
check(!!faqHtml, '产物存在：/faq/');
check(!!logHtml, '产物存在：/changelog/');

if (!llms || !llmsFull || !docsHtml || !faqHtml || !logHtml) {
  console.log('\n!! 产物缺失，先跑 `node landing/build.js` 再校验');
  process.exitCode = 1;
  return;
}

// ------------------------------------------ ① 品牌自报家门（英文机器面） ---

// ★ 这里要求 platform 与 app **同时**出现，而不是「二者之一」。
//   端到端毒注（注入 "# DahuangAI (Fen)"）暴露过：用 OR 判据时，退役品牌那一行
//   因为带着 "(Fen)" 而照样命中 `brand.app` ⇒ 首行判据对毒注完全免疫，
//   只剩"不得含 DahuangAI"那一条在扛。判据查错了对象的又一种形式：
//   不是查错文件，是查错**强度** —— 一条恒真的断言比没有断言更危险，
//   因为它让人以为这里有人看着。
const firstLine = llms.split(/\r?\n/)[0] || '';
check(
  firstLine.indexOf(brand.app) !== -1 && firstLine.indexOf(brand.platform) !== -1,
  'llms.txt 首行同时含权威 platform 与 app（实际："' + firstLine + '"）'
);

check(retiredHits(llms).length === 0, 'llms.txt 无退役品牌 DahuangAI（命中 ' + retiredHits(llms).length + '）');
check(retiredHits(llmsFull).length === 0, 'llms-full.txt 无退役品牌 DahuangAI（命中 ' + retiredHits(llmsFull).length + '）');

[
  ['/docs/ meta', docsHtml],
  ['/faq/ meta', faqHtml],
  ['/changelog/ meta', logHtml],
].forEach(function (row) {
  const m = metaOf(row[1]);
  const n = retiredHits(m.title).length + retiredHits(m.desc).length;
  check(n === 0, row[0] + ' 无退役品牌 DahuangAI（命中 ' + n + '）');
  check(
    m.desc.indexOf(brand.app) !== -1 || m.title.indexOf(brand.app) !== -1 || row[0] === '/changelog/ meta',
    row[0] + ' 述及权威产品名 ' + brand.app
  );
});

// ---------------------------------------------- ② 反向锚点（防误删） ---
//
// These two assert that things we DELIBERATELY kept are still there. If a
// future brand decision retires them, change these lines *on purpose* — that is
// the point of the assertion, not an inconvenience.

check(
  !!zhDocsHtml && zhDocsHtml.indexOf('大荒AI') !== -1,
  '反向锚点：中文别名「大荒AI」仍在（site-zh.json.brand.app 既定；若改品牌须同步改本条）'
);
check(
  !!worldHtml && (worldHtml.indexOf('Dahuang') !== -1 || worldHtml.indexOf('大荒世界') !== -1),
  '反向锚点：世界观命名「The World of Dahuang / 大荒世界」仍在（非产品名，勿误删）'
);

// ------------------------------------- ③ 死链与外站（ADR-001 规则①） ---

const allUrls = urlsIn(llms).concat(urlsIn(llmsFull));
const offSite = allUrls.filter(function (u) {
  return u.indexOf(DOMAIN) !== 0;
});
check(
  offSite.length === 0,
  'llms 两个文件全部 URL 均为站内（' + DOMAIN + '）；站外 ' + offSite.length + ' 个' +
    (offSite.length ? '：' + offSite.slice(0, 3).join(' , ') : '')
);

check(
  llms.indexOf('github.com/woldworld') === -1,
  'llms.txt 不再指向未发布的 GitHub 仓库（实测 404）'
);

const srcLine = (llms.split(/\r?\n/).filter(function (l) {
  return /^Source:/.test(l);
})[0]) || '';
check(srcLine.length > 0, 'llms.txt 含 Source 行（告诉 Agent 源码在哪 / 没有就明说）');
check(srcLine.indexOf(DOMAIN + '/docs/') !== -1, 'Source 行指向站内 /docs/（永远可达，不指外站）');

// --------------------------------------------------------- 正控（会红） ---

console.log('');
console.log('--- 正控（证明判据真的会翻红，不是恒绿） ---');

check(retiredHits('# DahuangAI (Fen)').length === 1, '★ 正控：注入退役品牌必须被抓到');
check(retiredHits('The World of Dahuang').length === 0, '★ 正控：世界观名「Dahuang」不得被误杀');
check(retiredHits('# Wold (Fen)').length === 0, '★ 正控：正确品牌不得误报');
check(
  urlsIn('see https://github.com/woldworld/fen for source').filter(function (u) {
    return u.indexOf(DOMAIN) !== 0;
  }).length === 1,
  '★ 正控：站外 URL 必须被「全部站内」判据抓到'
);
check(
  urlsIn('1) Hub address starts with https://; 2) the network works').filter(function (u) {
    return u.indexOf(DOMAIN) !== 0;
  }).length === 0,
  '★ 正控：正文里的 "https://;" 不得被误判成站外 URL'
);
check(
  '# Wold (Fen)'.indexOf(brand.app) !== -1 && '# Wold (Fen)'.indexOf(brand.platform) !== -1,
  '★ 正控：正确首行（platform + app 同在）必须放行'
);
check(
  !('# DahuangAI (Fen)'.indexOf(brand.app) !== -1 && '# DahuangAI (Fen)'.indexOf(brand.platform) !== -1),
  '★ 正控：带退役品牌的首行（只含 app、不含 platform）必须被首行判据翻红（OR 判据会漏）'
);

console.log('');
console.log('================ 机器可读面校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
