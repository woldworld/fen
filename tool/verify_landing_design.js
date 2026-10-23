#!/usr/bin/env node
/**
 * Design-system documentation guard (0.105.0 / 整改方案阶段 C).
 *
 * Why this exists: landing/DESIGN.md claims to describe the REAL stylesheet,
 * and a design doc that drifts from the CSS is worse than no doc - it teaches
 * the next person variables and classes that do not exist. This guard derives
 * every structural fact from landing/src/style.css itself (comments stripped:
 * a `.md` inside a prose comment is not a selector) and demands DESIGN.md
 * match EXACTLY, in both directions:
 *
 *   1. §2 variable table  == the dark :root variable set
 *   2. §2.5 override list == the light-theme :root overrides
 *   3. §5 class inventory == every class selector in the stylesheet
 *      (no duplicates, nothing missing, nothing fabricated)
 *   4. §4 media-query list == the distinct @media queries
 *   5. §0 fact table numbers == measured counts (vars, classes, queries,
 *      keyframes, url() references)
 *
 * Positive controls exercise the SAME predicates the real assertions use:
 * a fabricated variable, a dropped class and a fabricated class must each be
 * caught, and the untouched doc must not false-positive.
 *
 *   node tool/verify_landing_design.js
 */

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const CSS_PATH = path.join(ROOT, 'landing', 'src', 'style.css');
const DOC_PATH = path.join(ROOT, 'landing', 'DESIGN.md');

let pass = 0;
let fail = 0;

function check(ok, label, detail) {
  if (ok) {
    pass++;
    console.log('  PASS  ' + label);
  } else {
    fail++;
    console.log('  FAIL  ' + label + (detail ? '  [' + detail + ']' : ''));
  }
}

// ---------------------------------------------------------------- CSS side --

function extractCss(css) {
  // Comments are stripped FIRST: `隐私政策.md` in a prose comment is a file
  // name, not a `.md` class selector. Trusting the raw text once shipped a
  // phantom class into the doc's inventory.
  const stripped = css.replace(/\/\*[\s\S]*?\*\//g, '');
  const darkRoot = stripped.match(/:root \{([\s\S]*?)\n\}/);
  const lightRoot = stripped.match(
    /@media \(prefers-color-scheme: light\) \{[\s\S]*?:root \{([\s\S]*?)\n\}/
  );
  const varsOf = (m) => {
    const set = new Set();
    if (!m) return set;
    for (const x of m[1].matchAll(/(--[\w-]+)\s*:/g)) set.add(x[1]);
    return set;
  };
  return {
    darkVars: varsOf(darkRoot),
    lightVars: varsOf(lightRoot),
    classes: new Set([...stripped.matchAll(/\.([a-zA-Z][\w-]*)/g)].map((m) => m[1])),
    media: new Set(
      [...stripped.matchAll(/@media ([^{]+)/g)].map((m) =>
        m[1].replace(/\s+/g, ' ').replace(/[()]/g, '').trim()
      )
    ),
    keyframes: [...stripped.matchAll(/@keyframes\s+([\w-]+)/g)].map((m) => m[1]),
    urlCount: (stripped.match(/url\(/g) || []).length,
  };
}

// ---------------------------------------------------------------- doc side --

function slice(text, startRe, endRe) {
  const s = text.search(startRe);
  if (s < 0) return null;
  const from = text.indexOf('\n', s) + 1;
  const rest = text.slice(from);
  const e = rest.search(endRe);
  return e < 0 ? rest : rest.slice(0, e);
}

function backtickTokens(text, filterRe) {
  const out = [];
  for (const m of text.matchAll(/`([^`]+)`/g)) {
    const t = m[1].trim();
    if (!filterRe || filterRe.test(t)) out.push(t);
  }
  return out;
}

function extractDoc(md) {
  // §0 fact table: | 事实 | 值 |
  const facts = {};
  const s0 = slice(md, /^## 0\./m, /^## 1\./m) || '';
  for (const m of s0.matchAll(/^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*$/gm)) {
    facts[m[1].replace(/`/g, '').trim()] = m[2].replace(/`/g, '').trim();
  }
  // §2 variable table: the first cell of every table row
  const s2 = slice(md, /^## 2\./m, /^## 3\./m) || '';
  const darkVars = new Set();
  for (const line of s2.split('\n')) {
    if (line.charAt(0) !== '|') continue;
    const first = line.split('|')[1] || '';
    const m = first.match(/`(--[\w-]+)`/);
    if (m) darkVars.add(m[1]);
  }
  // §2.5 light-theme override list
  const s25 = slice(md, /^### 2\.5/m, /^## 3\./m) || '';
  const lightVars = new Set(backtickTokens(s25, /^--[\w-]+$/));
  // §4 media queries
  const s4 = slice(md, /^## 4\./m, /^## 5\./m) || '';
  const media = new Set(
    backtickTokens(s4, /^(max-width|prefers-)/).map((t) => t.replace(/[()]/g, '').trim())
  );
  // §5 class inventory
  const s5 = slice(md, /^## 5\./m, /^## 6\./m) || '';
  const classes = backtickTokens(s5, /^[a-z][a-z0-9-]*$/);
  return { facts, darkVars, lightVars, media, classes };
}

// ------------------------------------------------------------ diff engine --

function diffDoc(doc, css) {
  const d = {
    varsMissing: [...css.darkVars].filter((v) => !doc.darkVars.has(v)),
    varsExtra: [...doc.darkVars].filter((v) => !css.darkVars.has(v)),
    lightMissing: [...css.lightVars].filter((v) => !doc.lightVars.has(v)),
    lightExtra: [...doc.lightVars].filter((v) => !css.lightVars.has(v)),
    classMissing: [...css.classes].filter((c) => doc.classes.indexOf(c) === -1),
    classExtra: doc.classes.filter((c) => !css.classes.has(c)),
    mediaMissing: [...css.media].filter((q) => !doc.media.has(q)),
    mediaExtra: [...doc.media].filter((q) => !css.media.has(q)),
  };
  const seen = new Set();
  d.classDups = doc.classes.filter((c) => (seen.has(c) ? true : (seen.add(c), false)));
  return d;
}

function isClean(d) {
  return Object.keys(d).every((k) => d[k].length === 0);
}

function fmt(list) {
  return list.length ? '（' + list.join(', ') + '）' : '';
}

// -------------------------------------------------------------------- main --

console.log('=== 设计系统文档校验（DESIGN.md × style.css）===');

const cssRaw = fs.existsSync(CSS_PATH) ? fs.readFileSync(CSS_PATH, 'utf8') : '';
const md = fs.existsSync(DOC_PATH) ? fs.readFileSync(DOC_PATH, 'utf8') : '';
check(cssRaw.length > 0, 'landing/src/style.css 存在且非空');
check(md.length > 0, 'landing/DESIGN.md 存在且非空');

if (cssRaw && md) {
  const css = extractCss(cssRaw);
  const doc = extractDoc(md);
  const F = doc.facts;

  // ---- §0 fact table ----
  const factRows = [
    ['暗色主题变量数', css.darkVars.size],
    ['亮色覆盖变量数', css.lightVars.size],
    ['组件类总数', css.classes.size],
    ['媒体查询种数', css.media.size],
  ];
  factRows.forEach(([k, real]) => {
    const v = F[k];
    check(v !== undefined && Number(v) === real, '事实表：' + k + ' = ' + real + '（文档写：' + (v === undefined ? '缺行' : v) + '）');
  });
  check(
    F['关键帧'] === css.keyframes.join(','),
    '事实表：关键帧 = ' + css.keyframes.join(',') + '（文档写：' + (F['关键帧'] || '缺行') + '）'
  );
  check(
    F['外部 url() 引用'] !== undefined && Number(F['外部 url() 引用']) === 0 && css.urlCount === 0,
    '事实表：外部 url() 引用 = 0（实测 ' + css.urlCount + '，文档写：' + (F['外部 url() 引用'] === undefined ? '缺行' : F['外部 url() 引用']) + '）'
  );

  // ---- deep set equality ----
  const d = diffDoc(doc, css);
  check(
    d.varsMissing.length === 0 && d.varsExtra.length === 0,
    '§2 变量集合与样式表精确相等（暗色 :root ' + css.darkVars.size + ' 个）',
    '漏 ' + fmt(d.varsMissing) + ' 多 ' + fmt(d.varsExtra)
  );
  check(
    d.lightMissing.length === 0 && d.lightExtra.length === 0,
    '§2.5 亮色覆盖清单与样式表精确相等（' + css.lightVars.size + ' 个）',
    '漏 ' + fmt(d.lightMissing) + ' 多 ' + fmt(d.lightExtra)
  );
  check(
    d.classMissing.length === 0 && d.classExtra.length === 0,
    '§5 组件类清单与样式表精确相等（' + css.classes.size + ' 个）',
    '漏 ' + fmt(d.classMissing) + ' 多 ' + fmt(d.classExtra)
  );
  check(d.classDups.length === 0, '§5 组件类清单无重复', '重复 ' + fmt(d.classDups));
  check(
    d.mediaMissing.length === 0 && d.mediaExtra.length === 0,
    '§4 媒体查询清单与样式表精确相等（' + css.media.size + ' 种）',
    '漏 ' + fmt(d.mediaMissing) + ' 多 ' + fmt(d.mediaExtra)
  );

  // ---- positive controls (same predicates, doctored doc) ----
  console.log('');
  console.log('--- 正控（证明判据真的会翻红）---');

  // Surgery is anchored on SECTION HEADINGS - the very anchors the slicing
  // depends on - so a future reordering of rows inside a section cannot
  // silently no-op a control into a false PASS.
  const afterHeading = (text, re, extra) => text.replace(re, (m) => m + '\n\n' + extra);

  const docAddVar = afterHeading(
    md,
    /^## 2\.[^\n]*$/m,
    '| `--fabricate-xyz` | `#000000` | `#000000` | 编造变量 |'
  );
  check(
    docAddVar !== md && !isClean(diffDoc(extractDoc(docAddVar), css)),
    '★ 正控：文档多写一个变量必须被抓到'
  );

  const docDropClass = md.replace(/`wrap`/, '');
  check(
    docDropClass !== md && !isClean(diffDoc(extractDoc(docDropClass), css)),
    '★ 正控：文档漏掉一个真实类必须被抓到'
  );

  const docFakeClass = afterHeading(md, /^## 5\.[^\n]*$/m, '`fake-class-zzz`');
  check(
    docFakeClass !== md && !isClean(diffDoc(extractDoc(docFakeClass), css)),
    '★ 正控：文档编造一个不存在的类必须被抓到'
  );

  const docFakeMedia = afterHeading(md, /^## 4\.[^\n]*$/m, '`max-width: 4000px`');
  check(
    docFakeMedia !== md && !isClean(diffDoc(extractDoc(docFakeMedia), css)),
    '★ 正控：文档编造一个媒体查询必须被抓到'
  );

  check(
    isClean(diffDoc(extractDoc(md), css)),
    '★ 正控：未动手的文档不得误报'
  );
}

console.log('');
console.log('================ 设计系统文档校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
