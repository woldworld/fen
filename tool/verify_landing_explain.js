#!/usr/bin/env node
/**
 * Product explain layer verification (0.102.0).
 *
 * Why this exists: the homepage used to be a chapter theatre and nothing else,
 * so a first-time visitor could not tell what the product IS. We inserted an
 * explain layer (positioning -> 3 steps -> demo door -> honest status ->
 * developer doors) between the hero and the chapters.
 *
 * Two things can go wrong and neither is visible from "it builds":
 *   1. The explain layer quietly disappears (a refactor drops it), and we are
 *      back to a homepage nobody understands.
 *   2. It starts telling stories - 小荒 / Wildland / 大荒AI are theatre and
 *      internal names, not product names, and they must not leak into the part
 *      of the page whose whole job is to explain the product.
 *
 * The demo must also keep its "scripted scenario" label. A demo that looks
 * real is a lie, and R27 says claims have to be checkable.
 *
 *   node tool/verify_landing_explain.js
 */

'use strict';

const fs = require('fs');
const path = require('path');

const LANDING = path.join(__dirname, '..', 'landing');
const DIST = path.join(LANDING, 'dist');

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

console.log('=== 首页产品表达层校验 ===');

// ------------------------------------------------------------- glossary ---

const glossary = JSON.parse(fs.readFileSync(path.join(LANDING, 'data', 'glossary.json'), 'utf8'));
const banned = [];
glossary
  .filter((e) => e.homepageHighlight === false)
  .forEach((e) => {
    [e.term, e.zh].forEach((v) => {
      if (v && banned.indexOf(v) === -1) banned.push(v);
    });
  });
check(
  banned.length >= 3,
  '术语表含 >=3 个「首页不突出」术语（当前 ' + banned.length + '：' + banned.join(' / ') + '）'
);

// ------------------------------------------------------------- helpers ---

function read(f) {
  return fs.readFileSync(path.join(DIST, f), 'utf8');
}

// Explain blocks are flat <section class="explain ..."> ... </section>; there is
// no nesting, so a non-greedy match up to the first closing tag is exact.
function explainBlocks(html) {
  const out = [];
  const re = /<section class="explain[\s\S]*?<\/section>/g;
  let m;
  while ((m = re.exec(html)) !== null) out.push(m[0]);
  return out;
}

function bannedIn(block) {
  return banned.filter((t) => block.indexOf(t) !== -1);
}

function hasDemoNote(block) {
  return /class="demo-note"/.test(block) && /scripted|scenario|剧本|模拟/i.test(block);
}

// ---------------------------------------------------------- both pages ---

const pages = [
  { tag: 'EN', html: read('index.html') },
  { tag: 'ZH', html: read('zh/index.html') },
];

console.log('');
console.log('--- 表达层存在且完整 ---');

pages.forEach((p) => {
  const blocks = explainBlocks(p.html);
  check(blocks.length === 3, p.tag + ' 表达层含 3 个区块（what / status / developers，当前 ' + blocks.length + '）');
  ['what', 'status', 'developers'].forEach((id) => {
    check(p.html.indexOf('id="' + id + '"') !== -1, p.tag + ' 表达层含 #' + id);
  });
  check((p.html.match(/class="step"/g) || []).length === 3, p.tag + ' 三步机制卡为 3 张');
  // Class attributes are compound ("status-list ok-list"), so match by word
  // inside the attribute - an exact 'class="ok-list"' probe would silently
  // pass forever while the real markup changed.
  check(/class="[^"]*\bok-list\b/.test(p.html) && /class="[^"]*\bwip-list\b/.test(p.html),
    p.tag + ' 状态区含「已可用 / 还在做」双栏');
  check((p.html.match(/class="dev-card"/g) || []).length === 3, p.tag + ' 开发者入口卡为 3 张');
});

console.log('');
console.log('--- 术语纪律（故事名/内部名不得进入表达层） ---');

pages.forEach((p) => {
  const blocks = explainBlocks(p.html);
  const hits = [];
  blocks.forEach((b, i) => {
    const h = bannedIn(b);
    if (h.length) hits.push('#' + (i + 1) + ':' + h.join(','));
  });
  check(hits.length === 0, p.tag + ' 表达层内无「首页不突出」术语' + (hits.length ? '（命中 ' + hits.join(' ') + '）' : ''));
  // The theatre keeps its own vocabulary - this asserts we did not "fix" it by
  // deleting the story, which is the other way this could have been broken.
  check(p.html.indexOf('id="awaken"') !== -1 && p.html.indexOf('id="auditable"') !== -1,
    p.tag + ' 章回剧场仍在（#awaken / #auditable 未被删）');
});

console.log('');
console.log('--- 演示标注（不得看起来像真实在线智能体） ---');

pages.forEach((p) => {
  const blocks = explainBlocks(p.html);
  const demo = blocks.filter((b) => b.indexOf('demo-door') !== -1);
  check(demo.length === 1, p.tag + ' 表达层含演示入口区块');
  if (demo.length) {
    check(hasDemoNote(demo[0]), p.tag + ' 演示区带「剧本化情景 / scripted scenario」标注');
    // 0.103.0: the door no longer points at the in-page #audit chapter - it now
    // hands off to the real eight-step demo page. The probe is still an exact
    // literal (not "contains /demo"), because a fuzzy probe would keep passing
    // after someone silently repointed it at a page that does not exist.
    const want = p.tag === 'ZH' ? 'href="/zh/demo/"' : 'href="/demo/"';
    check(demo[0].indexOf(want) !== -1, p.tag + ' 演示按钮指向 ' + want);
    check(!/href="\/nope\/"/.test(demo[0]), p.tag + ' 演示按钮未指向不存在的路径');
  }
});

console.log('');
console.log('--- 正控（证明判据真的会翻红） ---');

check(bannedIn('<section class="explain" id="what">' + banned[0] + '</section>').length > 0,
  '★ 正控：向表达层注入禁用术语「' + banned[0] + '」必须被抓到');
check(bannedIn('<section class="explain" id="what"><p>Fen is the client app.</p></section>').length === 0,
  '★ 正控：干净表达层不得误报');
check(!hasDemoNote('<section class="explain"><div class="demo-door"></div></section>'),
  '★ 正控：演示区缺标注必须被抓到');
check(explainBlocks('<div>no sections here</div>').length === 0,
  '★ 正控：无表达层时区块数为 0（不会假装有）');

console.log('');
console.log('================ 表达层校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
