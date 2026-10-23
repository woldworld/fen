#!/usr/bin/env node
/**
 * Landing site (landing/) output verification.
 *
 * Why this exists: "it builds" says nothing about whether the pages are
 * correct. A landing page fails silently - wrong canonical, broken JSON-LD,
 * a dead download button, a city card pointing at a page that was never
 * generated - and every one of those is invisible until someone tries to
 * crawl it. This script asserts the OUTPUT, not the generator's intent.
 *
 *   node tool/verify_landing.js
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

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

console.log('=== 落地页静态站校验 ===');

// ---------------------------------------------------------------- build ---

// Build first so this script is a single command, and so a stale dist can
// never masquerade as a passing build. build() wipes dist itself (see
// safeRmDir in build.js); the duplicate fs.rmSync that used to sit here was
// both redundant and the exact call that hung intermittently on 2026-10-13/14.
require(path.join(LANDING, 'build.js'));

const site = JSON.parse(fs.readFileSync(path.join(LANDING, 'data', 'site.json'), 'utf8'));
const siteZh = JSON.parse(fs.readFileSync(path.join(LANDING, 'data', 'site-zh.json'), 'utf8'));
const cities = JSON.parse(fs.readFileSync(path.join(LANDING, 'data', 'cities.json'), 'utf8'));
// 0.98.0: the story is data too - build-critical sources, asserted like any other.
const story = JSON.parse(fs.readFileSync(path.join(LANDING, 'data', 'story.json'), 'utf8'));
const storyZh = JSON.parse(fs.readFileSync(path.join(LANDING, 'data', 'story-zh.json'), 'utf8'));
const DOMAIN = site.brand.domain.replace(/\/+$/, '');

function read(p) {
  return fs.readFileSync(path.join(DIST, p), 'utf8');
}

console.log('--- 产物完整性与 SEO 三件套 ---');

check(fs.existsSync(DIST), 'dist/ 已生成');

const home = read('index.html');
check(home.length > 1000, '首页 HTML 有实质内容（>1000 字节）');

// Every city in the data must have a generated page. A city that exists in
// data but not in dist means a silently skipped page.
const cityPages = {};
let missing = [];
for (const c of cities) {
  const p = path.join(DIST, c.slug, 'index.html');
  if (fs.existsSync(p)) cityPages[c.slug] = fs.readFileSync(p, 'utf8');
  else missing.push(c.slug);
}
check(missing.length === 0, '每个城市都有对应页面（缺=' + (missing.join(',') || '无') + '）');
check(Object.keys(cityPages).length === 6, '城市页数 = 6（收缩后，实际 ' + Object.keys(cityPages).length + '）');

check(fs.existsSync(path.join(DIST, 'style.css')), 'style.css 已产出');
check(fs.existsSync(path.join(DIST, 'robots.txt')), 'robots.txt 已产出');
check(fs.existsSync(path.join(DIST, 'sitemap.xml')), 'sitemap.xml 已产出');

console.log('--- 首页：SEO / 结构化数据 ---');

check(/<html lang="en">/.test(home), '首页 lang="en"（英文优先，PRD §3.3）');
check(/<meta charset="utf-8">/.test(home), '声明 charset');
check(/name="viewport"/.test(home), '有 viewport（移动端）');
check(/name="description"/.test(home), '有 meta description');
check(
  new RegExp('<link rel="canonical" href="' + DOMAIN.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '/">').test(home),
  'canonical 指向 ' + DOMAIN + '/'
);
check(/<meta property="og:title"/.test(home), '有 og:title');
check(/<meta property="og:url"/.test(home), '有 og:url');

// JSON-LD must be parseable AND must not be able to break out of <script>.
const ldBlocks = [...home.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];
check(ldBlocks.length >= 1, '首页含 JSON-LD 块');
let ldOk = false;
let ldType = '';
if (ldBlocks.length) {
  const raw = ldBlocks[0][1];
  try {
    const obj = JSON.parse(raw);
    ldOk = true;
    ldType = obj['@type'] || '';
  } catch (e) {
    ldOk = false;
  }
  check(!/<\/script/i.test(raw), 'JSON-LD 内无 </script>（不会被截断出 script 块）');
  check(!raw.includes('<'), 'JSON-LD 内裸 < 已转义（\u003c）');
}
check(ldOk, '首页 JSON-LD 可被 JSON.parse');
check(ldType === 'SoftwareApplication', '首页 JSON-LD 类型 = SoftwareApplication（实际 ' + ldType + '）');

console.log('--- 首页：内容与诚实性 ---');

check(home.includes(site.tagline), '首页含主标语');
check(home.includes('id="explore"'), '★ 首页是概览：含 #explore 入口区（0.94.0 概览化）');
const entryHrefs = [...home.matchAll(/<a class="entry-card" href="([^"]+)"/g)].map((m) => m[1]);
check(
  entryHrefs.length === (site.entries || []).length && entryHrefs.length >= 3,
  '首页入口卡数 = site.entries 数（' + entryHrefs.length + '）'
);
check(
  entryHrefs.includes('/world/'),
  '★ 入口卡含「大荒世界」入口（/world/）'
);
check(
  entryHrefs
    .filter((h) => h.startsWith('/'))
    .every((h) => h.startsWith('/#') || fs.existsSync(path.join(DIST, h.replace(/^\//, ''), 'index.html'))),
  '每张入口卡都指向真实存在的页面或页内锚点（无死链）'
);
for (const s of site.sections) {
  check(home.includes('id="' + s.id + '"'), '含板块 #' + s.id);
}

// The important one: never ship a download button that goes nowhere.
const hasRelease = !!site.cta.primaryUrl;
if (hasRelease) {
  check(home.includes(site.cta.primaryUrl), '下载地址已渲染');
} else {
  check(
    home.includes('btn-disabled') && home.includes('aria-disabled="true"'),
    '无发布地址时，主 CTA 渲染为**非链接**并标 aria-disabled（不做死链）'
  );
  const btnArea = home.slice(home.indexOf('class="actions"'), home.indexOf('class="actions"') + 600);
  check(!/<a[^>]*btn-primary/.test(btnArea), '无地址时不存在 btn-primary 的 <a>（不会点了没反应）');
}

console.log('--- 城市页 ---');

const laPage = cityPages['los-angeles'] || '';
check(laPage.length > 800, 'los-angeles 页有实质内容');
check(laPage.includes('Just landed in Los Angeles?'), '城市页标题含城市名（不是模板占位符）');
check(
  new RegExp('<link rel="canonical" href="' + DOMAIN.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '/los-angeles/">').test(laPage),
  '城市页 canonical = ' + DOMAIN + '/los-angeles/'
);

// A city page that still says "Other cities" but links to itself is a bug.
// (0.96.0: cards are image-led now, so anchor on the section, not the markup
// that used to directly follow the href.)
const selfLinks = Object.entries(cityPages).filter(([slug, html]) => {
  const seg = html.slice(html.indexOf('id="other-cities"'));
  return new RegExp('href="/' + slug + '/"').test(seg);
});
check(selfLinks.length === 0, '城市页不链到自己');

// Each city page must link back home.
check(
  Object.values(cityPages).every((h) => /class="breadcrumb"/.test(h) && /href="\/"/.test(h)),
  '每个城市页都有回首页的面包屑'
);

// JSON-LD on city pages.
let cityLdOk = true;
let bcOk = true;
for (const [slug, html] of Object.entries(cityPages)) {
  const m = html.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
  if (!m) { cityLdOk = false; continue; }
  try {
    const o = JSON.parse(m[1]);
    if (o['@type'] !== 'WebPage') cityLdOk = false;
    if (!o.breadcrumb || o.breadcrumb['@type'] !== 'BreadcrumbList') bcOk = false;
    if (o.url !== DOMAIN + '/' + slug + '/') cityLdOk = false;
  } catch (e) {
    cityLdOk = false;
  }
}
check(cityLdOk, '全部城市页 JSON-LD 可解析且 url/类型正确');
check(bcOk, '全部城市页带 BreadcrumbList');

// ---------------------------------------------------------------------------
// 0.95.0：城市页「双语半接线」修复断言（0.93 只修了首页，城市页漏网）
// ---------------------------------------------------------------------------

const zhCityPages = {};
const zhCityMissing = [];
for (const c of cities) {
  const p = path.join(DIST, 'zh', c.slug, 'index.html');
  if (fs.existsSync(p)) zhCityPages[c.slug] = fs.readFileSync(p, 'utf8');
  else zhCityMissing.push(c.slug);
}
check(zhCityMissing.length === 0, '中文城市页全部产出（缺=' + (zhCityMissing.join(',') || '无') + '）');

// 中文城市页出现英文国名 = 半接线（0.95.0 修：三处 country 硬读英文）
const englishCountries = [...new Set(cities.map((c) => c.country))];
const zhCountryBad = [];
for (const c of cities) {
  const t = zhCityPages[c.slug] || '';
  for (const e of englishCountries) if (t.includes('>' + e + '<')) zhCountryBad.push(c.slug + ':' + e);
  if (!t.includes(c.zh.country)) zhCountryBad.push(c.slug + ':缺中文国名');
}
check(zhCountryBad.length === 0, '★ 中文城市页无英文国名、含中文国名（错=' + (zhCountryBad.join(',') || '无') + '）');

// ★ CTA 必须用中文文案（0.93 漏网：primaryCta() 未传语言数据源 ⇒ 中文页按钮英文）
const zhCtaBad = cities
  .filter((c) => !(zhCityPages[c.slug] || '').includes(esc(siteZh.cta.primaryLabel)))
  .map((c) => c.slug);
check(zhCtaBad.length === 0, '★ 中文城市页主 CTA 用中文文案（错=' + (zhCtaBad.join(',') || '无') + '）');

// ★ 中文城市页「其他城市」卡必须链到中文页（0.95.0 修复：此前 href 漏 zh 前缀）
const zhOtherBad = [];
for (const c of cities) {
  const t = zhCityPages[c.slug] || '';
  const seg = t.slice(t.indexOf('id="other-cities"'));
  // 该区块内不允许出现指向英文城市页的 href
  for (const o of cities) {
    if (o.slug === c.slug) continue;
    if (new RegExp('href="/' + o.slug + '/"').test(seg)) zhOtherBad.push(c.slug + '->' + o.slug);
  }
}
check(zhOtherBad.length === 0, '★ 中文城市页「其他城市」卡链到中文页（错=' + (zhOtherBad.join(',') || '无') + '）');

// ★ alternate 必须指向「对侧」（0.95.0 修复：此前两种情况都指向自身 ⇒ 完全失效）
const altBad = [];
for (const c of cities) {
  const en = cityPages[c.slug] || '';
  const zhp = zhCityPages[c.slug] || '';
  if (!en.includes('<link rel="alternate" hreflang="zh" href="' + DOMAIN + '/zh/' + c.slug + '/">')) {
    altBad.push(c.slug + ':en');
  }
  if (!zhp.includes('<link rel="alternate" hreflang="en" href="' + DOMAIN + '/' + c.slug + '/">')) {
    altBad.push(c.slug + ':zh');
  }
}
check(altBad.length === 0, '★ 城市页 alternate 互指对侧（错=' + (altBad.join(',') || '无') + '）');

// ★ 中文城市页 JSON-LD inLanguage 必须 zh-CN（0.95.0 修复：硬编码 en）
const zhLdLangBad = cities
  .filter((c) => {
    const m = (zhCityPages[c.slug] || '').match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
    if (!m) return true;
    try {
      return JSON.parse(m[1]).inLanguage !== 'zh-CN';
    } catch (e) {
      return true;
    }
  })
  .map((c) => c.slug);
check(zhLdLangBad.length === 0, '★ 中文城市页 JSON-LD inLanguage = zh-CN（错=' + (zhLdLangBad.join(',') || '无') + '）');

console.log('--- ★ 反「门页」：每个城市页必须有自己的正文 ---');

/**
 * Strip the shared "other cities" block so what is left is the part that
 * should be unique per city. Without this, every page would differ only by
 * city name - the textbook shape of a doorway page, which gets deindexed.
 */
function stripShared(html) {
  const i = html.indexOf('id="other-cities"');
  if (i < 0) return html;
  const j = html.indexOf('</section>', i);
  return j < 0 ? html : html.slice(0, i) + html.slice(j);
}

const bodies = Object.fromEntries(
  Object.entries(cityPages).map(([slug, html]) => [slug, stripShared(html)])
);

// Compare against the ESCAPED text: the page holds HTML, so "Fen's" is
// rendered as "Fen&#39;s". Comparing raw source text gives a false FAIL.
function esc(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Own copy must be present.
let arcOk = true;
let arcBad = [];
for (const c of cities) {
  const b = bodies[c.slug] || '';
  if (!b.includes(esc(c.arc[0])) || !b.includes(esc(c.arc[1]))) {
    arcOk = false;
    arcBad.push(c.slug);
  }
}
check(arcOk, '每个城市页都渲染了自己的两段正文（缺=' + (arcBad.join(',') || '无') + '）');

// Pairwise uniqueness - the actual anti-doorway assertion.
const bodyHashes = new Set(Object.values(bodies));
check(
  bodyHashes.size === Object.keys(bodies).length,
  '★ 任意两个城市页的正文**不雷同**（唯一 ' + bodyHashes.size + '/' + Object.keys(bodies).length + '）'
);

// And it has to be substantial, not a sentence with the city swapped in.
const shortest = Math.min(...Object.values(bodies).map((b) => b.length));
check(shortest >= 1200, '最短的城市页正文也够长（' + shortest + ' 字符 ≥ 1200）');

// The unique paragraphs themselves must not repeat across the dataset.
const allArc = cities.flatMap((c) => c.arc);
check(new Set(allArc).size === allArc.length, '城市正文段落全局唯一（无复用段落）');

console.log('--- 首页城市卡片与真实页面一一对应 ---');

const cardHrefs = [...home.matchAll(/<a class="city-card[^"]*" href="\/([a-z0-9-]+)\/"/g)].map((m) => m[1]);
check(cardHrefs.length === cities.length, '首页城市卡片数 = 城市数据数（' + cardHrefs.length + '/' + cities.length + '）');
check(
  cardHrefs.every((s) => fs.existsSync(path.join(DIST, s, 'index.html'))),
  '每张卡片都指向真实存在的页面（无死链）'
);

// 0.95.0：中文首页城市卡不得出现英文国名（此前 country 硬读英文）
const zhHome = read('zh/index.html');
const zhHomeCountryBad = englishCountries.filter((e) => zhHome.includes('>' + e + '<'));
const zhHomeNameBad = cities.filter((c) => !zhHome.includes(esc(c.zh.name)));
check(
  zhHomeCountryBad.length === 0 && zhHomeNameBad.length === 0,
  '★ 中文首页城市卡：无英文国名、城市名用中文（错=' +
    ([...zhHomeCountryBad, ...zhHomeNameBad.map((c) => c.slug)].join(',') || '无') + '）'
);
// 中文首页城市卡链到中文城市页
const zhHomeCardBad = cities.filter((c) => !zhHome.includes('href="/zh/' + c.slug + '/"')).map((c) => c.slug);
check(zhHomeCardBad.length === 0, '★ 中文首页城市卡链到中文城市页（错=' + (zhHomeCardBad.join(',') || '无') + '）');

// ---------------------------------------------------------------------------
// 0.96.0：图片为主（image-led）+ 本地资产 + 香港合规命名
// ---------------------------------------------------------------------------

// 每城必须有本地图：数据源齐、文件拷进 dist、且不是坏图（只认字节，体积完全不可信的姊妹判据：太小=坏）。
const imgBad = [];
for (const c of cities) {
  if (!c.image || c.image !== '/assets/city/' + c.slug + '.jpg') imgBad.push(c.slug + ':data');
  const jpg = path.join(DIST, 'assets', 'city', c.slug + '.jpg');
  if (!fs.existsSync(jpg)) imgBad.push(c.slug + ':dist缺文件');
  else if (fs.statSync(jpg).size < 20 * 1024) imgBad.push(c.slug + ':图太小(疑似坏图)');
}
check(imgBad.length === 0, '★ 六城图片：数据齐全且已拷入 dist/assets/city/（错=' + (imgBad.join(',') || '无') + '）');

// 首页（双语）城市卡都是图片卡（media + 本地图 src）。
const homeImgBad = cities
  .filter((c) => {
    const needle = '<div class="city-media"><img src="' + esc(c.image) + '"';
    return !home.includes(needle) || !zhHome.includes(needle);
  })
  .map((c) => c.slug);
check(homeImgBad.length === 0, '★ 首页(双语)城市卡都带本地图（缺=' + (homeImgBad.join(',') || '无') + '）');

// 城市页 hero（双语）都挂了自己的图背景（--city-img 指向本地图）。
const heroImgBad = cities
  .filter((c) => {
    const needle = 'style="--city-img:url(/assets/city/' + c.slug + '.jpg)"';
    return !(cityPages[c.slug] || '').includes(needle) || !(zhCityPages[c.slug] || '').includes(needle);
  })
  .map((c) => c.slug);
check(heroImgBad.length === 0, '★ 城市页(双语) hero 都挂本地图背景（缺=' + (heroImgBad.join(',') || '无') + '）');

// ★ 香港合规命名：英文国名必须是 "Hong Kong, China"，中文必须是「中国香港」。
const hk = cities.find((c) => c.slug === 'hong-kong');
check(!!hk && hk.country === 'Hong Kong, China', '★ 香港数据源国名 = Hong Kong, China');
check(!!hk && !!hk.zh && hk.zh.country === '中国香港', '★ 香港中文国名 = 中国香港');
check(
  !!hk && (cityPages['hong-kong'] || '').includes('Hong Kong, China') &&
    (zhCityPages['hong-kong'] || '').includes('中国香港'),
  '★ 香港城市页(双语)渲染合规命名'
);
check(
  !!hk && !(zhCityPages['hong-kong'] || '').includes('>Hong Kong<') && !zhHome.includes('>Hong Kong<'),
  '★ 中文页不把「Hong Kong」当独立国名/城市名渲染'
);

console.log('--- 大荒世界页（0.94.0：机制图鉴 + 官方分身，非实时） ---');

const worldPages = {
  en: { file: 'world/index.html', lang: 'en', url: '/world/', W: site.world },
  zh: { file: 'zh/world/index.html', lang: 'zh-CN', url: '/zh/world/', W: siteZh.world },
};
let worldOk = true;
let worldCanonBad = [];
let worldLdBad = [];
let worldAgentBad = [];
for (const [k, wp] of Object.entries(worldPages)) {
  if (!fs.existsSync(path.join(DIST, wp.file))) { worldOk = false; continue; }
  const t = read(wp.file);
  if (!t.includes('<html lang="' + wp.lang + '">')) worldCanonBad.push(k + ':lang');
  if (!t.includes('<link rel="canonical" href="' + DOMAIN + wp.url + '">')) worldCanonBad.push(k + ':canonical');
  if (!t.includes('<h1>' + esc(wp.W.title) + '</h1>')) worldCanonBad.push(k + ':h1');
  const mLd = t.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
  if (mLd) {
    try {
      const o = JSON.parse(mLd[1]);
      if (o['@type'] !== 'WebPage' || o.url !== DOMAIN + wp.url) worldLdBad.push(k);
    } catch (e) { worldLdBad.push(k); }
  } else worldLdBad.push(k);
  for (const a of wp.W.agents) {
    if (!t.includes(esc(a.name)) || !t.includes(esc(a.id)) || !t.includes(esc(a.line))) {
      worldAgentBad.push(k + ':' + a.id);
    }
  }
  // 诚实性：必须带「非实时」声明，不得出现"实时/直播房间"之类的暗示。
  if (!t.includes(esc(wp.W.agentsNote))) worldAgentBad.push(k + ':非实时声明缺失');
}
check(worldOk, 'world/index.html 与 zh/world/index.html 均已产出');
check(worldCanonBad.length === 0, '两页 world 页 lang/canonical/H1 正确（错=' + (worldCanonBad.join(',') || '无') + '）');
check(worldLdBad.length === 0, '两页 world 页 JSON-LD 可解析且 url 正确（错=' + (worldLdBad.join(',') || '无') + '）');
check(worldAgentBad.length === 0, '★ 官方分身（名/ID/台词）与非实时声明都渲染到位（错=' + (worldAgentBad.join(',') || '无') + '）');

// 反虚构：中文页的官方分身台词必须逐字出现在 lib/hub/seed-rooms.js 台词库里。
// 台词是"真实存在的库内容"，不是文案手写的——库改了而官网没跟 = 守卫当场红。
const seedSrc = fs.readFileSync(path.join(LANDING, '..', 'lib', 'hub', 'seed-rooms.js'), 'utf8');
const fabricated = (siteZh.world.agents || []).filter((a) => !seedSrc.includes(a.line));
check(
  fabricated.length === 0,
  '★ 中文页官方分身台词逐字来自 seed-rooms.js 台词库（虚构=' + (fabricated.map((a) => a.id).join(',') || '无') + '）'
);

// 两语种 world 页互为 alternate，且首页导航挂了大荒世界入口。
for (const [k, wp] of Object.entries(worldPages)) {
  if (!fs.existsSync(path.join(DIST, wp.file))) continue;
  const t = read(wp.file);
  const other = k === 'en' ? worldPages.zh : worldPages.en;
  if (!t.includes('href="' + DOMAIN + other.url + '"')) worldAgentBad.push(k + ':alternate缺失');
}
check(
  worldAgentBad.filter((x) => x.endsWith(':alternate缺失')).length === 0,
  '两页 world 页互挂 hreflang alternate'
);
check(home.includes('href="/world/"') && read('zh/index.html').includes('href="/zh/world/"'),
  '首页导航（双语）都挂了大荒世界入口');

// 0.115.0：changelog 分页 ⇒ sitemap 里**每多一个归档页就多两条 URL**
//   （en + zh 各一条）。计数**按磁盘上实际产出的页数算**，不写死 ——
//   写死会在下一次分页时误红，而真相就在 dist 里。
const clPageCount = (() => {
  let n = 0;
  for (let i = 1; ; i++) {
    // ★ 页 1 是**文件** changelog/index.html；页 ≥2 是目录 changelog/pN/index.html。
    //   （把 'index.html' 当中间目录段 ⇒ 变成 changelog/index.html/index.html ⇒ 探测恒为 0 页。）
    const p = i === 1
      ? path.join(DIST, 'changelog', 'index.html')
      : path.join(DIST, 'changelog', 'p' + i, 'index.html');
    if (!fs.existsSync(p)) break;
    n++;
  }
  return n;
})();
const CL_ARCHIVE_PAGES = Math.max(0, clPageCount - 1); // 首页之外的分页数
console.log('--- 更新日志：双语（0.95.0 新增 /zh/changelog/） ---');

const clEn = fs.existsSync(path.join(DIST, 'changelog', 'index.html')) ? read('changelog/index.html') : '';
const hasClZh = fs.existsSync(path.join(DIST, 'zh', 'changelog', 'index.html'));
const clZh = hasClZh ? read('zh/changelog/index.html') : '';
check(hasClZh, 'zh/changelog/index.html 已产出（/zh/changelog/ 可访问）');
check(clEn.length > 500 && clZh.length > 500, '两页更新日志都有实质内容');
check(clZh.includes('<html lang="zh-CN">'), '中文更新日志 lang="zh-CN"');
check(
  clZh.includes('<link rel="canonical" href="' + DOMAIN + '/zh/changelog/">'),
  '中文更新日志 canonical = ' + DOMAIN + '/zh/changelog/'
);
check(clZh.includes('更新日志'), '中文更新日志 H1/标题为中文');
// 两页互挂 alternate（各自指向对侧）
check(
  clZh.includes('<link rel="alternate" hreflang="en" href="' + DOMAIN + '/changelog/">') &&
    clEn.includes('<link rel="alternate" hreflang="zh" href="' + DOMAIN + '/zh/changelog/">'),
  '★ 更新日志两页 alternate 互指对侧'
);
// ★ 0.115.0：changelog 分页后的归档页判据 ——
//   ① 归档页真产出（磁盘上）；② canonical 自指（不是首页的 URL）；
//   ③ alternate 指向**对侧语言的同页码**（指向首页 = 宣称两页同内容，错）；
//   ④ 页内有翻页导航（分页不能把历史藏起来）。
for (let i = 2; i <= clPageCount; i++) {
  const enRel = 'changelog/p' + i + '/index.html';
  const zhRel = 'zh/changelog/p' + i + '/index.html';
  const enArch = fs.existsSync(path.join(DIST, 'changelog', 'p' + i, 'index.html')) ? read(enRel) : '';
  const zhArch = fs.existsSync(path.join(DIST, 'zh', 'changelog', 'p' + i, 'index.html')) ? read(zhRel) : '';
  check(!!enArch && !!zhArch, '★ changelog 归档页 p' + i + ' 双语都产出');
  if (!enArch || !zhArch) continue;
  check(enArch.includes('<link rel="canonical" href="' + DOMAIN + '/changelog/p' + i + '/">'),
    '★ 归档页 p' + i + '（en）canonical 自指');
  check(zhArch.includes('<link rel="canonical" href="' + DOMAIN + '/zh/changelog/p' + i + '/">'),
    '★ 归档页 p' + i + '（zh）canonical 自指');
  check(enArch.includes('hreflang="zh" href="' + DOMAIN + '/zh/changelog/p' + i + '/"'),
    '★ 归档页 p' + i + '（en）alternate 指向对侧语言**同页码**');
  check(zhArch.includes('hreflang="en" href="' + DOMAIN + '/changelog/p' + i + '/"'),
    '★ 归档页 p' + i + '（zh）alternate 指向对侧语言**同页码**');
  check(enArch.includes('class="cl-pages"') && zhArch.includes('class="cl-pages"'),
    '★ 归档页 p' + i + ' 有翻页导航（历史不被藏起来）');
}
// 正文必须含最新版本号（读 CHANGELOG.md 首个版本节；库改了官网没跟 = 红）
const clSrc = fs.readFileSync(path.join(LANDING, '..', 'CHANGELOG.md'), 'utf8');
// ★ 2026-10-21 修（第四个坑）：版本头正则吃不下 `+N` 构建号 —— `## [0.116.0+1]` 里 `\]`
//   撞在 `+1` 上 ⇒ 整节不匹配 ⇒ **静默读到上一版**（0.115.0），而两节片段在 dist 里都在
//   ⇒ 数字事实逐条命中、判据全绿放过（R34「判据查错对象」复发）。0.116.0+1 是项目第一个
//   带构建号的版本，bug 从那一轮起潜伏。⇒ 正则容忍可选 `+N`，并配两条自检（见下）。
const VER_HEAD_RE = /^## \[([0-9]+\.[0-9]+\.[0-9]+(?:\+\d+)?)\]/m;
const latestVer = (clSrc.match(VER_HEAD_RE) || [])[1] || '';
check(!!latestVer, 'CHANGELOG.md 能解析出最新版本号（' + latestVer + '）');
// 自检①：正则必须能吃 +N 构建号（本次事故的直接正控 —— 毒注入一个带构建号的版本头）
{
  const mm = VER_HEAD_RE.exec('## [9.999.0+7] — x');
  check(!!mm && mm[1] === '9.999.0+7', '自检：版本头正则能解析 +N 构建号（毒注入 9.999.0+7）');
}
// 自检②：首个版本节必须 == pubspec version —— 不等即取节错了，或 bump / 漏写版本节不同步（ADR-001）
{
  const pub = fs.readFileSync(path.join(LANDING, '..', 'pubspec.yaml'), 'utf8');
  const pv = (pub.match(/^version:\s*(\S+)\s*$/m) || [])[1] || '';
  check(!!pv && latestVer === pv,
    '★ 首个版本节（' + latestVer + '）== pubspec version（' + pv + '）—— 不等即取节错了或版本不同步');
}
check(
  clEn.includes(latestVer) && clZh.includes(latestVer),
  '★ 两页更新日志都渲染了最新版本 ' + latestVer + '（数据源直读 CHANGELOG.md）'
);
// ★★ 0.108.0 收口实证补：**「节标题在 ≠ 节正文是最新的」**。
//   起因：0.108.0 收口时**先重建 dist、后回填 CHANGELOG 的真实读数**
//   ⇒ dist 渲染的是**回填前**的正文：页面上至今写着「不需要重出 APK」，而 APK 已经重出；
//   而上面那条判据只查「最新版本号串在不在」⇒ 标题在、正文陈旧，**照样全绿**。
//   ⇒ 本判据：CHANGELOG.md **最新节**的「数字型事实」（千分位字节数 / `xxxxxxxx…xxxx` 哈希前缀）
//     必须逐条出现在 dist 两页的**最新节片段**里 —— 它钉的是「`build.js` 有没有把 CHANGELOG 的
//     数字事实渲染进 dist」，覆盖面到「**尚未打包 / 无 zip**」的早期回归与 CI 场景。
//   ⚠️ ★ 它**判不了「陈旧」** —— 本文件**自己在第 44 行 `require(landing/build.js)` 重建 dist**
//     ⇒ dist 在判它之前一定是新的。**陈旧判定唯一归 `tool/verify_deploy_site_freshness.js`**
//     （那个守卫打开的是**打完不再变的包内 zip 快照**）。两者是**两个不同对象**各钉一道，不是重复；
//     别把这条当成「dist 已同步」的证据。
//   ★ 之所以挑这两类：它们**不经 markdown 变换**（不会被加粗/换行改写），比对不会脆。
//   ★ 取节必须**显式定位首节**，两个坑都踩过了：
//     ① 带 `$` 的正则（`/m` 下 `$` 只匹配第一个行尾）⇒ 整节被截成只剩标题（事实 0 条）；
//     ② `split(/\r?\n(?=## \[)/)[1]` ⇒ 本文件**没有 `# Changelog` 头**，元素 0 才是首节，`[1]` 是**上一版**。
//   ★★ 2026-10-20 补（第三个坑）：CHANGELOG.md 里除了版本节，还有**非版本化的过程记录节**
//     （例：`## [官网 /demo/ 页上线演示视频] — 2026-10-17`），按日期插在最前面。
//     此时"第一个 `## [` 节"是过程记录节 —— 它没有版本号、也没有千分位数字，
//     而上面 `latestVer` 是按版本号模式从**版本节**解析出来的
//     ⇒ 版本号与正文事实**来自不同的节** ⇒ 事实数 0 ⇒ 误红。
//     ⇒ 版本号与正文事实必须取自**同一个节**：一律按版本号模式定位最新版本节。
//   ★★ 2026-10-21 再补（第四个坑，见上方 VER_HEAD_RE 处注释）：该模式还必须容忍 `+N`
//     构建号，否则又会静默读到上一版。VER_HEAD_RE 已在上面统一定义并带自检。
const verHead = VER_HEAD_RE.exec(clSrc);
const clStart = verHead ? verHead.index : -1;
const clRest = clStart < 0 ? '' : clSrc.slice(clStart);
const clNextIdx = clRest.slice(1).search(/\r?\n## \[/);
const clSection = clNextIdx < 0 ? clRest : clRest.slice(0, clNextIdx + 1);
/** 包内 changelog 页里**最新版本节**对应的 log-item 纯文本（不是"第一个"）。 */
function latestFragOf(html) {
  const items = html
    .split('<section class="log-item">')
    .slice(1)
    .map((s) => plainOf(s.split('<section class="log-item">')[0]));
  if (!items.length) return '';
  const tag = '[' + latestVer + ']';
  // ★ 2026-10-21 修：CHANGELOG 新节里引用版本标签（`` `## [0.116.0+1]` ``）会让
  //   「包含即中」**误中过程节**（它位于最顶部，find 先命中它）⇒ 拿过程节验版本节、事实全缺。
  //   ⇒ 先按**标题前缀**挑（log-item 纯文本以节标题开头），挑不到再退化为包含匹配。
  const byHead = items.find((t) => t.trim().startsWith(tag));
  return byHead || items.find((t) => t.includes(tag)) || items[0];
}
function factsOf(text) {
  const out = new Set();
  for (const m of text.matchAll(/(\d{1,3}(?:,\d{3})+)\s*B/g)) out.add(m[1]);
  for (const m of text.matchAll(/([0-9a-f]{8}\u2026[0-9a-f]{4})/g)) out.add(m[1]);
  return [...out];
}
function plainOf(html) {
  return html.replace(/<[^>]+>/g, ' ').replace(/&amp;/g, '&').replace(/\s+/g, ' ');
}
function hasFact(plain, fact) {
  const pat = fact.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s*');
  return new RegExp(pat).test(plain);
}
const secFacts = factsOf(clSection);
check(secFacts.length >= 2,
  '★ changelog 最新节至少含 2 条数字型事实（可核对项；实为 ' + secFacts.length + ' 条）');
for (const clPair of [['en', clEn], ['zh', clZh]]) {
  // ★ 取**最新版本节**的片段，而不是"第一个 log-item" —— 顶部可能是非版本化的过程记录节。
  const frag = latestFragOf(clPair[1]);
  const missing = secFacts.filter((f) => !hasFact(frag, f));
  check(frag.length > 0 && missing.length === 0,
    '★★ 反陈旧：changelog（' + clPair[0] + '）最新节渲染出的正文必须含 CHANGELOG.md 最新节的'
    + '全部数字事实（' + secFacts.length + ' 条）；缺：[' + missing.join(', ') + ']');
  // ★ 正控：把事实从片段里抹掉后，判据必须变假（否则这条判据是恒真的摆设）
  const stripped = secFacts.reduce((acc, f) => acc.split(f).join('X'), frag);
  const missingOnStripped = secFacts.filter((f) => !hasFact(stripped, f)).length;
  check(secFacts.length > 0 && missingOnStripped === secFacts.length,
    '★★ 正控：抹掉全部数字事实后本判据必须报「全缺」（实测缺 ' + missingOnStripped +
    '/' + secFacts.length + '）');
}
// 中文页导航/页脚必须链到中文 changelog（0.95.0 修复：此前链回英文页）
check(zhHome.includes('href="/zh/changelog/"'), '★ 中文首页 nav/页脚链到 /zh/changelog/（此前链回英文页）');
// JSON-LD
let clZhLdOk = false;
const clZhLd = clZh.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
if (clZhLd) {
  try {
    const o = JSON.parse(clZhLd[1]);
    clZhLdOk = o['@type'] === 'CollectionPage' && o.url === DOMAIN + '/zh/changelog/';
  } catch (e) {
    clZhLdOk = false;
  }
}
check(clZhLdOk, '中文更新日志 JSON-LD 可解析且 url 正确');

console.log('--- 隐私政策页（★ 上架必填：可访问的 URL） ---');

const PRIV_PATH = path.join('privacy', 'index.html');
const hasPriv = fs.existsSync(path.join(DIST, PRIV_PATH));
check(hasPriv, 'privacy/index.html 已产出（/privacy/ 可访问）');
const priv = hasPriv ? read(PRIV_PATH) : '';

check(priv.length > 2000, '隐私页有实质内容（实际 ' + priv.length + ' 字节）');
check(
  new RegExp(
    '<link rel="canonical" href="' + DOMAIN.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '/privacy/">'
  ).test(priv),
  '隐私页 canonical = ' + DOMAIN + '/privacy/'
);
check(/<html lang="zh-CN">/.test(priv), '隐私页 lang="zh-CN"（政策正文为中文）');

// The two that actually decide whether this page helps or hurts a submission.
// A policy that still holds "[数据存储位置]" looks finished while being
// unfinished, and shipping our internal review notes tells the reader about our
// workflow instead of about the policy.
check(!/\[[^\]\n]{1,24}\]/.test(priv), '★ 隐私页无未填占位符（[xxx] 一律 FAIL）');
check(
  !/草稿|给复核者的备注|不构成法律意见|发布前删除/.test(priv),
  '★ 隐私页不含内部流程字样（草稿 / 复核备注 / 发布前删除）'
);

// It also has to actually say the things a reviewer looks for - and the values
// have to be the ones build.js injected from site.legal, not a stale hand-edit
// sitting in dist/ from an earlier build.
const legal = site.legal;
check(/数据存储位置/.test(priv), '含「数据存储位置」条目');
check(priv.includes(esc(legal.dataLocation)), '★ 数据存储位置 = site.legal.dataLocation 注入值');
check(/跨境传输的法律依据/.test(priv), '含「跨境传输的法律依据」条目');
check(priv.includes(esc(legal.crossBorderBasis)), '★ 跨境传输依据 = site.legal.crossBorderBasis 注入值');
check(priv.includes(esc(legal.effectiveDate)), '★ 生效日期 = site.legal.effectiveDate 注入值');
check(/privacy@wold\.world/.test(priv), '含数据主体权利联系邮箱');
check(/不面向儿童/.test(priv), '含儿童条款');

// A policy nobody can find is the same as no policy.
const pagesAll = [home, ...Object.values(cityPages)];
check(
  pagesAll.every((h) => /href="\/privacy\/"/.test(h) && /href="\/terms\/"/.test(h)),
  '★ 首页与全部城市页的页脚都挂了 /privacy/ 与 /terms/ 链接'
);

let privLdOk = false;
const privLd = priv.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
if (privLd) {
  try {
    const o = JSON.parse(privLd[1]);
    privLdOk = o['@type'] === 'WebPage' && o.url === DOMAIN + '/privacy/';
  } catch (e) {
    privLdOk = false;
  }
}
check(privLdOk, '隐私页 JSON-LD 可解析且 url/类型正确');

console.log('--- 服务条款页（★ 上架必填：可访问的 URL） ---');

const TERMS_PATH = path.join('terms', 'index.html');
const hasTerms = fs.existsSync(path.join(DIST, TERMS_PATH));
check(hasTerms, 'terms/index.html 已产出（/terms/ 可访问）');
const terms = hasTerms ? read(TERMS_PATH) : '';

check(terms.length > 2000, '条款页有实质内容（实际 ' + terms.length + ' 字节）');
check(
  new RegExp(
    '<link rel="canonical" href="' + DOMAIN.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '/terms/">'
  ).test(terms),
  '条款页 canonical = ' + DOMAIN + '/terms/'
);
check(/<html lang="zh-CN">/.test(terms), '条款页 lang="zh-CN"（条款正文为中文）');

// Same two that decide whether the page helps or hurts a submission: an
// unfilled "[法域]" reads as finished while being unfinished, and shipping our
// internal review notes tells the reader about our workflow instead of the terms.
check(!/\[[^\]\n]{1,24}\]/.test(terms), '★ 条款页无未填占位符（[xxx] 一律 FAIL）');
check(
  !/草稿|给复核者的备注|不构成法律意见|发布前删除/.test(terms),
  '★ 条款页不含内部流程字样（草稿 / 复核备注 / 发布前删除）'
);

// The values have to be the ones build.js injected from site.legal, not a stale
// hand-edit sitting in dist/ from an earlier build.
check(/适用法律/.test(terms), '含「适用法律」条目');
check(terms.includes(esc(legal.applicableLaw)), '★ 适用法律 = site.legal.applicableLaw 注入值');
check(/争议解决/.test(terms), '含「争议解决」条目');
check(terms.includes(esc(legal.disputeResolution)), '★ 争议解决方式 = site.legal.disputeResolution 注入值');
check(terms.includes(esc(legal.effectiveDate)), '★ 生效日期 = site.legal.effectiveDate 注入值');
check(/legal@wold\.world/.test(terms), '含法务联系邮箱');

// The §9.1 red lines are the product's compliance floor, not optional wording -
// they must survive the markdown render, not get swallowed as "internal notes".
check(/永不出金/.test(terms), '含 PRD §9.1「永不出金」红线');
check(/禁止传销条例/.test(terms), '含 PRD §9.1「禁止传销条例」红线');

let termsLdOk = false;
const termsLd = terms.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
if (termsLd) {
  try {
    const o = JSON.parse(termsLd[1]);
    termsLdOk = o['@type'] === 'WebPage' && o.url === DOMAIN + '/terms/';
  } catch (e) {
    termsLdOk = false;
  }
}
check(termsLdOk, '条款页 JSON-LD 可解析且 url/类型正确');

console.log('--- ★ 法务页多语种：5 语种 × 3 份文档 ---');

// Hardcoded on purpose. The guard's job is to compare the OUTPUT against the
// five languages the App ships (l10n.yaml supported-locales), not to re-read
// the generator's own table - a table that is wrong in both places would
// otherwise agree with itself.
const LEGAL_LOCALES = [
  { seg: '', lang: 'zh-CN', hl: 'zh-Hans', label: '简体中文' },
  { seg: 'en', lang: 'en', hl: 'en', label: 'English' },
  { seg: 'zh-hant', lang: 'zh-Hant', hl: 'zh-Hant', label: '繁體中文' },
  { seg: 'ja', lang: 'ja', hl: 'ja', label: '日本語' },
  { seg: 'vi', lang: 'vi', hl: 'vi', label: 'Tiếng Việt' },
];
// The published H1 per document kind per language. The draft's own H1 calls
// itself a draft; this is what must have replaced it.
const LEGAL_H1 = {
  privacy: {
    'zh-CN': '隐私政策', en: 'Privacy Policy', 'zh-Hant': '隱私政策',
    ja: 'プライバシーポリシー', vi: 'Chính sách quyền riêng tư',
  },
  terms: {
    'zh-CN': '服务条款', en: 'Terms of Service', 'zh-Hant': '服務條款',
    ja: '利用規約', vi: 'Điều khoản dịch vụ',
  },
  age: {
    'zh-CN': '年龄门槛', en: 'Age requirements', 'zh-Hant': '年齡門檻',
    ja: '年齢要件', vi: 'Yêu cầu về độ tuổi',
  },
};
// Every draft's internal banner / reviewer-note opener, in all five languages.
// None may survive into a published page - that is the same class of mistake as
// shipping an unfilled placeholder.
const LEGAL_LEAKS = [
  '本文为工程侧草稿', '给复核者的备注', '本文為工程側草稿', '給複核者的備註',
  'This is an engineering-side draft', 'Reviewer notes',
  '本文はエンジニアリング側のドラフト', 'レビュアー向けメモ',
  'Đây là bản nháp do bộ phận kỹ thuật soạn', 'Ghi chú cho người rà soát',
];

const legalRel = (kind, loc) => kind + '/' + (loc.seg ? loc.seg + '/' : '') + 'index.html';
const legalUrl = (kind, loc) => '/' + kind + '/' + (loc.seg ? loc.seg + '/' : '');

const legalMissing = [];
const legalLangBad = [];
const legalCanonBad = [];
const legalAltBad = [];
const legalH1Bad = [];
const legalLdBad = [];
const legalSwitchBad = [];
const legalLeakBad = [];
const legalPages = [];

for (const kind of ['privacy', 'terms', 'age']) {
  for (const loc of LEGAL_LOCALES) {
    const key = kind + ':' + loc.lang;
    const rel = legalRel(kind, loc);
    if (!fs.existsSync(path.join(DIST, rel))) { legalMissing.push(key); continue; }
    const t = read(rel);
    legalPages.push([rel, t]);

    const wantCanon = DOMAIN + legalUrl(kind, loc);
    if (!t.includes('<html lang="' + loc.lang + '">')) legalLangBad.push(key);
    if (!t.includes('<link rel="canonical" href="' + wantCanon + '">')) legalCanonBad.push(key);

    const alts = [...t.matchAll(/<link rel="alternate" hreflang="([^"]+)" href="([^"]+)">/g)]
      .map((m) => m[1] + '=' + m[2]);
    const wantAlts = LEGAL_LOCALES
      .map((l) => l.hl + '=' + DOMAIN + legalUrl(kind, l))
      .concat(['x-default=' + DOMAIN + '/' + kind + '/']);
    if (JSON.stringify(alts) !== JSON.stringify(wantAlts)) legalAltBad.push(key);

    if (!t.includes('<h1>' + LEGAL_H1[kind][loc.lang] + '</h1>')) legalH1Bad.push(key);
    if (/\[[^\]\n]{1,24}\]/.test(t)) legalH1Bad.push(key + '(残留占位符)');

    for (const o of LEGAL_LOCALES) {
      if (o.seg === loc.seg) continue;
      if (!t.includes('href="' + legalUrl(kind, o) + '"')) legalSwitchBad.push(key + '->' + o.lang);
    }

    // The default page IS the original; every other page must carry the notice
    // that says so. Neither may carry it by accident.
    if (loc.seg === '' && t.includes('class="lang-note"')) legalSwitchBad.push(key + '(默认页不该有译文声明)');
    if (loc.seg !== '' && !t.includes('class="lang-note"')) legalSwitchBad.push(key + '(缺译文声明)');

    for (const leak of LEGAL_LEAKS) if (t.includes(leak)) legalLeakBad.push(key + ':' + leak);

    let ldOkHere = false;
    const mLd = t.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
    if (mLd) {
      try {
        const o = JSON.parse(mLd[1]);
        ldOkHere = o['@type'] === 'WebPage' && o.url === wantCanon && o.inLanguage === loc.lang;
      } catch (e) { ldOkHere = false; }
    }
    if (!ldOkHere) legalLdBad.push(key);
  }
}

check(legalMissing.length === 0, '法务页 5 语种 × 3 份全部产出（缺=' + (legalMissing.join(',') || '无') + '）');
check(legalPages.length === 15, '法务页共 15 页（实际 ' + legalPages.length + '）');
check(legalLangBad.length === 0, '每页 <html lang> 与语种一致（错=' + (legalLangBad.join(',') || '无') + '）');
check(legalCanonBad.length === 0, '每页 canonical 指向自身（错=' + (legalCanonBad.join(',') || '无') + '）');
check(legalAltBad.length === 0, '★ 每页 hreflang = 5 语种 + x-default 且顺序固定（错=' + (legalAltBad.join(',') || '无') + '）');
check(legalH1Bad.length === 0, '★ 每页渲染发布版 H1、无残留占位符（错=' + (legalH1Bad.join(',') || '无') + '）');
check(legalSwitchBad.length === 0, '★ 页内切换器完整、译文声明只出现在译文页（错=' + (legalSwitchBad.join(',') || '无') + '）');
check(legalLeakBad.length === 0, '★ 无草稿横幅 / 复核备注泄漏到任何页面（漏=' + (legalLeakBad.join(',') || '无') + '）');
check(legalLdBad.length === 0, '每页 JSON-LD 的 url / inLanguage 正确（错=' + (legalLdBad.join(',') || '无') + '）');

// ---------------------------------------------------------------------------
// The three documents point at each other, and every pointer must be a LINK.
//
// What this catches: the privacy policy and the terms both mentioned the age
// requirements while no such page existed, and the renderer papered over it by
// printing the words without an href. A mention the reader cannot follow is the
// dead reference the compliance review flagged - and it looked fine in review,
// because the sentence read perfectly.
//
// The assertion is on the DOCUMENT BODY, not the whole page: every page carries
// a shared footer with /privacy/ and /terms/ in it, so a whole-page match would
// pass on the default locale even with the body reference missing entirely.
const docBody = (t) => {
  const m = t.match(/<article class="doc">([\s\S]*?)<\/article>/);
  return m ? m[1] : '';
};

const legalRefBad = [];
for (const loc of LEGAL_LOCALES) {
  for (const kind of ['privacy', 'terms']) {
    const t = docBody(read(legalRel(kind, loc)));
    if (!t.includes('href="' + legalUrl('age', loc) + '"')) legalRefBad.push(kind + ':' + loc.lang + '->age');
  }
  const a = docBody(read(legalRel('age', loc)));
  if (!a.includes('href="' + legalUrl('privacy', loc) + '"')) legalRefBad.push('age:' + loc.lang + '->privacy');
  if (!a.includes('href="' + legalUrl('terms', loc) + '"')) legalRefBad.push('age:' + loc.lang + '->terms');
}
check(
  legalRefBad.length === 0,
  '★ 三份文档正文互相指向同语种页面（缺=' + (legalRefBad.join(',') || '无') + '）'
);

// ---------------------------------------------------------------------------
// The terms must say where the money comes from.
//
// What this catches: section 4 used to promise that the service "involves no
// movement of funds". The moment the operator takes a subscription, a donation
// or an affiliate commission, that sentence becomes a false statement of fact -
// and the build would not have complained, because the page still reads
// perfectly. So the guard pins two things per language: the revenue table is
// there, and the blanket denial is gone for good.
//
// Both lists are output-side strings, hardcoded on purpose: re-reading the
// generator would let a wrong table agree with itself.
const MONEY_OK = {
  'zh-CN': ['收入来源（逐项披露）', '推广链接披露'],
  en: ['Where our money comes from', 'Affiliate disclosure'],
  'zh-Hant': ['收入來源（逐項披露）', '推廣連結披露'],
  ja: ['収入源（項目ごとの開示）', 'アフィリエイト開示'],
  vi: ['Nguồn thu của chúng tôi', 'Công bố liên kết tiếp thị'],
};
// The old blanket denial, in the words each published page used. If any comes
// back, the page is asserting something untrue about how we are funded.
const MONEY_DENIAL = [
  '不涉及任何资金流转',
  '不涉及任何資金流轉',
  'involves no movement of funds',
  '資金の移動を一切伴いません',
  'không liên quan đến bất kỳ dòng chảy tài chính nào',
];

const moneyMissing = [];
const moneyDenial = [];
for (const loc of LEGAL_LOCALES) {
  const body = docBody(read(legalRel('terms', loc)));
  for (const k of MONEY_OK[loc.lang]) {
    if (!body.includes(k)) moneyMissing.push(loc.lang + ':' + k);
  }
  for (const d of MONEY_DENIAL) {
    if (body.includes(d)) moneyDenial.push(loc.lang + ':' + d);
  }
}
check(
  moneyMissing.length === 0,
  '★ 条款 5 语种都逐项披露收入来源与推广佣金（缺=' + (moneyMissing.join(',') || '无') + '）'
);
check(
  moneyDenial.length === 0,
  '★ 条款不再声称「不涉及资金流转」——旧承诺一旦回来就是事实性错误陈述（残留=' +
    (moneyDenial.join(',') || '无') + '）'
);

// ---------------------------------------------------------------------------
// The DPO section exists because PDPA s.11(3) asks for one, and it has to be
// published in every language: a reader who only reads Vietnamese still has to
// be able to find out who is accountable for their data.
//
// The CONTACT is pinned as well, and that is the sharp edge here. The DPO is
// reachable at the EXISTING privacy@ address on purpose - 《本人操作手册》 says
// outright that the forwarding for it still has to be set up, and opening a
// third dpo@ mailbox before then would publish an address nobody reads. A
// published address that bounces is worse than publishing none.
const DPO_TITLE = {
  'zh-CN': '数据保护官', en: 'Data Protection Officer', 'zh-Hant': '資料保護官',
  ja: 'データ保護責任者', vi: 'Người phụ trách bảo vệ dữ liệu',
};
const dpoBad = [];
for (const loc of LEGAL_LOCALES) {
  const t = docBody(read(legalRel('privacy', loc)));
  if (!t.includes(DPO_TITLE[loc.lang])) dpoBad.push(loc.lang + '(缺 DPO 条款)');
  if (!t.includes('privacy@wold.world')) dpoBad.push(loc.lang + '(缺可送达联系地址)');
}
check(
  dpoBad.length === 0,
  '★ 隐私页 5 语种都公开 DPO，且联系地址是已公开的那个（错=' + (dpoBad.join(',') || '无') + '）'
);

// ---------------------------------------------------------------------------
// The trial relay sends prompts to a third party, and the policy has to say
// where - "a model provider and the like" tells the reader nothing they can
// act on.
const ROUTE_OVERSEAS = 'OpenRouter';
const ROUTE_DOMESTIC = {
  'zh-CN': '不离开中国境内', en: 'Stays within the Chinese mainland',
  'zh-Hant': '不離開中國境內', ja: '中国大陸から出ない',
  vi: 'Không rời khỏi Trung Quốc đại lục',
};
// Routing by region is not blocking by region, and a reader has every reason to
// read the two as the same thing. The published text must separate them.
// 按地域选链路 ≠ 按地域屏蔽 —— 读者极容易把两者读成同一件事，文案必须分开写。
const ROUTE_NOT_BLOCK = {
  'zh-CN': '这与「按地区屏蔽访问」不是同一件事',
  en: 'which is not the same thing as blocking access by region',
  'zh-Hant': '這與「按地區屏蔽存取」不是同一件事',
  ja: 'これは「地域でアクセスを遮断すること」とは別の話です',
  vi: 'điều này không giống với việc chặn truy cập theo khu vực',
};
// ★ A 决策（2026-10-20 拍板）：旧的「不因地区拒绝任何人访问」是一句**从未被任何线上行为兑现**的
// 强承诺（Hub 实测零注册零消息、试用代调默认全关）。B 档规则是「声称即须绿，否则删宣称」——
// 我们删的是宣称，不是把义务硬扛下来。新措辞只陈述**当前事实** + **保留权利**，不含无条件的强承诺。
const ROUTE_NEUTRAL = {
  'zh-CN': '当前我们不会因为你所在的地区拒绝你访问，但我们保留在法律要求时限制特定地区访问的权利',
  en: 'We do not currently refuse access because of where you are, but we reserve the right to restrict access in specific regions where the law requires it',
  'zh-Hant': '目前我們不會因為你所在的地區拒絕你存取，但我們保留在法律要求時限制特定地區存取的權利',
  ja: '現在、どの地域にいるかを理由にアクセスを拒否することはありませんが、法令上必要とされる場合は特定の地域からのアクセスを制限する権利を留保します',
  vi: 'Hiện chúng tôi không từ chối truy cập vì lý do bạn ở đâu, nhưng chúng tôi bảo lưu quyền hạn chế truy cập ở những khu vực cụ thể khi pháp luật yêu cầu',
};
// 旧强承诺：必须**消失**。留着 = 还在对外做兑现不了的承诺（B 档违规）。
const ROUTE_OLD_PROMISE = {
  'zh-CN': '我们不因你所在的地区拒绝任何人访问',
  en: 'We do not refuse anyone access because of where they are',
  'zh-Hant': '我們不因你所在的地區拒絕任何人存取',
  ja: 'どの地域にいるかを理由にアクセスを拒否しません',
  vi: 'Chúng tôi không từ chối bất kỳ ai truy cập vì lý do họ ở đâu',
};

// 探测器抽成函数，才能做毒注入正控（否则「旧句已消失」可能是恒真）。
function routeViolations(text, lang) {
  const bad = [];
  if (!text.includes(ROUTE_OVERSEAS)) bad.push(lang + '(未写明境外代调方)');
  if (!text.includes(ROUTE_DOMESTIC[lang])) bad.push(lang + '(缺境内不出境的承诺)');
  if (!text.includes(ROUTE_NOT_BLOCK[lang])) bad.push(lang + '(未声明按地域路由≠按地域屏蔽)');
  if (!text.includes(ROUTE_NEUTRAL[lang])) bad.push(lang + '(缺中性措辞：当前事实+保留权利)');
  if (text.includes(ROUTE_OLD_PROMISE[lang])) bad.push(lang + '(旧强承诺未删除)');
  return bad;
}

// 正控 1：新中性句里不能含旧强承诺的片段，否则「旧句已消失」这条会因新句而假绿。
for (const loc of LEGAL_LOCALES) {
  check(
    !ROUTE_NEUTRAL[loc.lang].includes(ROUTE_OLD_PROMISE[loc.lang]) &&
      !ROUTE_NOT_BLOCK[loc.lang].includes(ROUTE_OLD_PROMISE[loc.lang]),
    '自检：' + loc.lang + ' 新措辞不含旧强承诺片段（否则「旧句已消失」是假绿）'
  );
}
// 正控 2：毒注入 —— 把旧强承诺塞回一段合规文本，探测器必须报出来。
{
  const clean = 'x ' + ROUTE_OVERSEAS + ' ' + ROUTE_DOMESTIC.en + ' ' +
    ROUTE_NOT_BLOCK.en + ' ' + ROUTE_NEUTRAL.en + ' y';
  const poisoned = clean + ' ' + ROUTE_OLD_PROMISE.en + ' z';
  check(routeViolations(clean, 'en').length === 0, '自检：合规样本零违规（探测器不误报）');
  check(
    routeViolations(poisoned, 'en').some((s) => s.includes('旧强承诺未删除')),
    '自检：毒注入旧强承诺能被判出（探测器不漏报）'
  );
}

const routeBad = [];
for (const loc of LEGAL_LOCALES) {
  routeBad.push(...routeViolations(docBody(read(legalRel('privacy', loc))), loc.lang));
}
check(
  routeBad.length === 0,
  '★ 隐私页 5 语种都写明分链路代调方、境内不出境、路由≠屏蔽，且已删旧强承诺、改中性措辞（错=' +
    (routeBad.join(',') || '无') + '）'
);

// ---------------------------------------------------------------------------
// §7.2 /self-host/ - the page that explains how money reaches the project.
//
// What this catches: two failure modes that both look fine on screen.
//  (a) An affiliate button with no URL behind it. There is no referral account
//      yet, so the cards must render as disabled chips with the reason printed
//      beside them; the moment a URL exists the same card must become an
//      <a rel="sponsored">. A card that is neither is a dead button wearing a
//      button's clothes.
//  (b) A referral link that is not marked as one. The disclosure paragraph is
//      decoration unless the link itself carries a machine-checkable marker.
const SH_LOCALES = [
  { rel: 'self-host/index.html', url: '/self-host/', lang: 'en',
    h1: 'Run your own', disc: 'Affiliate disclosure' },
  { rel: 'zh/self-host/index.html', url: '/zh/self-host/', lang: 'zh-CN',
    h1: '自己搭一台', disc: '推广披露' },
];
const shBad = [];
const shCards = [];
for (const p of SH_LOCALES) {
  if (!fs.existsSync(path.join(DIST, p.rel))) { shBad.push(p.url + '(缺页)'); continue; }
  const t = read(p.rel);
  if (!t.includes('<html lang="' + p.lang + '">')) shBad.push(p.url + '(lang)');
  if (!t.includes('<link rel="canonical" href="' + DOMAIN + p.url + '">')) shBad.push(p.url + '(canonical)');
  if (!t.includes('<h1>' + p.h1 + '</h1>')) shBad.push(p.url + '(h1)');
  if (!t.includes(p.disc)) shBad.push(p.url + '(缺推广披露)');
  if (/\[[^\]\n]{1,24}\]/.test(t)) shBad.push(p.url + '(残留占位符)');

  const cards = [...t.matchAll(/<div class="sh-card" data-support="([a-z]+)">([\s\S]*?)<\/div>/g)];
  if (cards.length !== 3) shBad.push(p.url + '(收入卡片 ' + cards.length + '/3)');
  for (const c of cards) {
    const id = c[1];
    const html = c[2];
    const live = /<a\b[^>]*rel="sponsored[^"]*"[^>]*>/.test(html);
    const off = /class="btn btn-disabled"/.test(html) && /class="note sh-pending"/.test(html);
    if (!live && !off) shBad.push(p.url + '#' + id + '(既没开通也没说明为什么不能点)');
    if (live && off) shBad.push(p.url + '#' + id + '(同时是链接又是禁用态)');
    if (live && !/target="_blank"/.test(html)) shBad.push(p.url + '#' + id + '(外链缺 target)');
    shCards.push(p.url + '#' + id + '=' + (live ? 'live' : 'off'));
  }
}
check(
  shBad.length === 0,
  '★ §7.2 /self-host/ 双语页完整，三张收入卡片各自"要么能点、要么说清为什么不能点"（错=' +
    (shBad.join(',') || '无') + '）'
);
console.log('  note  收入卡片实况：' + shCards.join(' / '));

console.log('--- sitemap / robots ---');

const sitemap = read('sitemap.xml');
check(sitemap.startsWith('<?xml'), 'sitemap 有 XML 声明');
const locs = [...sitemap.matchAll(/<loc>(.*?)<\/loc>/g)].map((m) => m[1]);
// 1 home + cities + (5 locales x 3 legal documents) + 3 双语增量页（/world/ /zh/world/ /zh/changelog/，0.94→0.95）
// + 2 下载页（/download/ 与 /zh/download/，ADR-001 自托管下载）
const DL_PAGES = 2; // ADR-001；新增更多语言的下载页时改这里，并同步 landing/build.js 的 urls 数组
const SH_PAGES = 2; // §7.2 自托管页：/self-host/ 与 /zh/self-host/
const wantSitemap = cities.length + 1 + 3 + (cities.length + 3) + LEGAL_LOCALES.length * 3 + 3 + DL_PAGES + SH_PAGES + CL_ARCHIVE_PAGES * 2; // + docs/faq/changelog + zh 版（首页+6城+docs+faq）+ world 双语 + zh changelog + 下载页双语 + 分页归档（双语）
check(locs.length === wantSitemap, 'sitemap URL 数 = ' + wantSitemap + '（实际 ' + locs.length + '；含 changelog 归档页 ' + CL_ARCHIVE_PAGES + ' 组）');
// ★ 0.115.0：每个 changelog 归档页的双语 URL 都必须真在 sitemap 里
//   （放这里而不是 changelog 段：locs 在 sitemap 段才定义，提前用会撞 const 的 TDZ）。
for (let i = 2; i <= clPageCount; i++) {
  check(locs.includes(DOMAIN + '/changelog/p' + i + '/') && locs.includes(DOMAIN + '/zh/changelog/p' + i + '/'),
    '★ 归档页 p' + i + ' 双语都在 sitemap 里');
}
check(new Set(locs).size === locs.length, 'sitemap 无重复 URL');
check(locs.includes(DOMAIN + '/'), 'sitemap 含首页');
check(locs.includes(DOMAIN + '/world/'), 'sitemap 含大荒世界页（/world/）');
check(locs.includes(DOMAIN + '/zh/world/'), 'sitemap 含中文大荒世界页（/zh/world/）');
check(locs.includes(DOMAIN + '/zh/changelog/'), 'sitemap 含中文更新日志（/zh/changelog/）');
check(locs.includes(DOMAIN + '/privacy/'), 'sitemap 含隐私页');
check(locs.includes(DOMAIN + '/terms/'), 'sitemap 含条款页');
let smLegalMissing = [];
for (const kind of ['privacy', 'terms', 'age']) {
  for (const loc of LEGAL_LOCALES) {
    if (!locs.includes(DOMAIN + legalUrl(kind, loc))) smLegalMissing.push(kind + ':' + loc.lang);
  }
}
check(smLegalMissing.length === 0, '★ sitemap 收全 15 条法务 URL（缺=' + (smLegalMissing.join(',') || '无') + '）');
check(locs.every((u) => u.startsWith(DOMAIN)), 'sitemap 全部 URL 都在本站域名下');
const smParsable = locs.length > 0 && !/<loc>\s*<\/loc>/.test(sitemap);
check(smParsable, 'sitemap 无空 <loc>');

const robots = read('robots.txt');
check(/User-agent: \*/.test(robots), 'robots 含 User-agent');
check(robots.includes('Sitemap: ' + DOMAIN + '/sitemap.xml'), 'robots 指向 sitemap');

console.log('--- ★ 0.98.0 首页章回剧场（八回 —— 每回必留钩子、必锚定价值）---');

check(story.chapters.length === 8 && storyZh.chapters.length === 8,
  '八回剧本双语各 8 回（' + story.chapters.length + '/' + storyZh.chapters.length + '）');

for (const g of [{ label: '英文', html: home, st: story }, { label: '中文', html: zhHome, st: storyZh }]) {
  const missing = g.st.chapters.filter((c) => !g.html.includes('id="' + c.id + '"')).map((c) => c.id);
  check(missing.length === 0, g.label + '首页八回锚点齐全（缺=' + (missing.join(',') || '无') + '）');

  const secs = [...g.html.matchAll(/<section class="chapter[^"]*"/g)].length +
    (/class="hero chapter-hero"/.test(g.html) ? 1 : 0);
  check(secs === 8, g.label + '首页章回区块数 = 8（实际 ' + secs + '）');

  // The story is a staged demo: the disclaimer is the difference between
  // immersion and a false claim about real rooms.
  // Compare a prefix that carries no **emphasis** markup: the page renders
  // **x** as <strong>x</strong>, so any slice crossing a bold span can never
  // match the raw source.
  const disc = esc(g.st.disclaimer.split('**')[0].slice(0, 40));
  check(g.html.includes(disc), g.label + '首页含「情景演绎」真实声明');

  check(g.html.includes('class="sprite-svg sprite-egg"') && g.html.includes('class="sprite-svg sprite-hatched"'),
    g.label + '含小荒双态 sprite（壳 + 已孵化，破壳动画可用）');

  const hooks = [...g.html.matchAll(/<p class="hook">/g)].length;
  check(hooks === 8, g.label + '每回都有悬念钩子（' + hooks + '/8）');

  const vals = [...g.html.matchAll(/<p class="value-tag">/g)].length;
  check(vals === 8, g.label + '每回都锚定一个产品价值（' + vals + '/8）');

  check(g.html.includes('id="bad-line"') && g.html.includes('id="audit-note"'),
    g.label + '撤销剧本含可划除行 + 撤销回执（可审计体感化）');

  const tocCount = [...g.html.matchAll(/<nav class="toc"/g)].length;
  check(tocCount === 1, g.label + '含唯一回目导航（可跳章）');
  check(/<a href="#explore">/.test(g.html), g.label + '回目导航可直达终章（不想看剧的人有出路）');
}

check([...home.matchAll(/class="city-card[^"]*reel-card"/g)].length === cities.length,
  '六城卷轴卡数 = 城市数据数（' + cities.length + '）');
check([...home.matchAll(/<p class="reel-line">/g)].length === cities.length,
  '六城卷轴每城都有故事一行（图不是空壳）');
check((story.citiesReel || []).length === cities.length && (storyZh.citiesReel || []).length === cities.length,
  '六城卷轴数据双语各 ' + cities.length + ' 条');
check(/<script>/.test(home) && !/<script[^>]+src=/.test(home),
  '★ 剧场交互脚本内联、无外部 src（离线仍可玩）');


console.log('--- ADR-001：自托管下载（最后一米必须真的能点开） ---');

const crypto = require('crypto');
const dlEn = fs.existsSync(path.join(DIST, 'download', 'index.html')) ? read('download/index.html') : '';
const dlZh = fs.existsSync(path.join(DIST, 'zh', 'download', 'index.html')) ? read('zh/download/index.html') : '';
check(!!dlEn && !!dlZh, '下载页双语都在（/download/ + /zh/download/）');

const pubspecTxt = fs.readFileSync(path.join(__dirname, '..', 'pubspec.yaml'), 'utf8');
const pubVersion = (pubspecTxt.match(/^version:\s*(\S+)\s*$/m) || [])[1] || '';

// The whole point of ADR-001: the numbers printed on the page must match the
// bytes we actually ship. Nothing here may be typed by a human.
let apkName = null;
const dlDir = path.join(DIST, 'download');
if (fs.existsSync(dlDir)) {
  const apks = fs.readdirSync(dlDir).filter((f) => /\.apk$/.test(f));
  check(apks.length <= 1, '发布的 APK 至多一个（多了就是陈旧文件堆积）');
  apkName = apks[0] || null;
}
check(!!apkName, 'dist/download/ 里有真实的 APK 产物');
if (apkName) {
  const apkBuf = fs.readFileSync(path.join(dlDir, apkName));
  const sha = crypto.createHash('sha256').update(apkBuf).digest('hex');
  // rule 5: never hand out the sideload flavour (its perms live in src/sideload/)
  check(!/sideload/i.test(apkName), '★ 发布的不是 sideload 包（受限权限不得对外分发）');
  // rule 6: arm64 split only, <= 50 MB
  check(/arm64/i.test(apkName), '★ 发布的必须是 arm64 分包（非全 ABI 胖包）');
  check(apkBuf.length <= 50 * 1024 * 1024,
    '★ 单包不超过 50 MB（实测 ' + apkBuf.length + ' 字节）');
  // rule 3/4: version + hash are computed from this very file
  check(apkName.indexOf(pubVersion) !== -1,
    '★ APK 文件名含 pubspec 版本号（' + pubVersion + '）⇒ 陈旧文件不可能被书签命中');
  check(dlEn.indexOf(sha) !== -1 && dlZh.indexOf(sha) !== -1,
    '★★ 页面上公布的 SHA-256 与真实文件逐字节一致（防数据与产物漂移）');
  check(dlEn.indexOf(String(apkBuf.length)) !== -1 || (() => {
    const m = dlEn.match(/(\d+(?:\.\d+)?)\s*MB/); return !!m;
  })(), '页面公布了文件体积');
  check(dlEn.indexOf(pubVersion) !== -1 && dlZh.indexOf(pubVersion) !== -1,
    '★ 页面显示的版本号与 pubspec.yaml 逐字一致（' + pubVersion + '）');
  // rule 2: the signing fingerprint has to be there and be a real 64-hex
  const certs = [...dlEn.matchAll(/>([0-9a-f]{64})</g)].map((m) => m[1]);
  check(certs.length >= 2, '★ 下载页公布 SHA-256 与证书指纹两个可核对值（缺一不可）');
  const signPath = path.join(LANDING, 'download', 'signing.json');
  if (fs.existsSync(signPath)) {
    const sg = JSON.parse(fs.readFileSync(signPath, 'utf8'));
    check(sg.certSha256 === certs[1] || certs.indexOf(sg.certSha256) !== -1,
      '★ 页面证书指纹 == apksigner 实测证书（不是手写串）');
    check(sg.version === pubVersion, '★ signing.json 的版本与 pubspec 一致');
    check(sg.bytes === apkBuf.length, '★ signing.json 的字节数与真实产物一致');
  }
  // ★ 反漂移（0.99.0 实证补，0.100.0 修 scope）：CHANGELOG 里**手抄**的产物字节数会随重打包漂移
  //   （0.98.0 旧包 33,169,585 B → 0.99.0 重出后 33,169,581 B，文档差 4 字节没人发现）
  //   ⇒ 只要**最新版本节**里出现「arm64 单包 N B」写法，N 必须等于真实字节数；
  //     写法不存在则跳过（不强制未来版本沿用该措辞）。
  //   ★ 0.100.0 实证补 scope：整页第一个匹配会被**历史版本节**命中 —— 0.99.0 节
  //     合法记录着它当时的真实字节（33,169,581 B），与 0.100.0 新产物
  //     （33,169,701 B）比对 ⇒ 误报 2 FAIL。历史节的数字是**当时**的事实，
  //     不该被今天的产物判成漂移 ⇒ 只扫第一个 log-item（= 最新版本节）。
  for (const clPair of [['en', clEn], ['zh', clZh]]) {
    // ★ 同上：取最新版本节，不是第一个 log-item。
    const latestSection = latestFragOf(clPair[1]);
    const mDrift = latestSection.match(/arm64 单包\s*([\d,]+)\s*B/);
    if (mDrift) {
      const cited = Number(mDrift[1].replace(/,/g, ''));
      check(cited === apkBuf.length,
        '★ 反漂移：changelog（' + clPair[0] + '）最新节手抄的 APK 字节数（' + cited +
        '）与真实产物（' + apkBuf.length + ' B）一致');
    }
  }
  check(/<a class="btn btn-primary btn-dl" href="\/download\/[^"]+" download>/.test(dlEn),
    '下载按钮是真锚点且带 download 属性（不是装饰）');

  // ★ 0.113.0：三渠道安装说明区（侧载 / F-Droid / 源码构建）。
  // 为什么钉：F-Droid 渠道**尚未提交**，页面必须把它渲染成「筹备中」灰片
  // 而不是链接 —— 一个点了 404 的渠道入口比没有入口更糟（与 APK 按钮同纪律）。
  // 签名不可混装警告是跨渠道升级安全的底线，双语都必须显形。
  const dlChannelsEn = (dlEn.match(/<div class="dl-channel">/g) || []).length;
  const dlChannelsZh = (dlZh.match(/<div class="dl-channel">/g) || []).length;
  check(dlChannelsEn === 3 && dlChannelsZh === 3,
    '★ 三渠道安装区双语各 3 张卡（官网 / F-Droid / 源码构建；实测 en=' +
      dlChannelsEn + ' zh=' + dlChannelsZh + '）');
  check(dlEn.includes('dl-channel-pending') && dlZh.includes('dl-channel-pending'),
    '★ F-Droid 渠道双语都是「筹备中」灰片（未提交就不装成链接）');
  check(!/href="[^"]*f-droid\.org/i.test(dlEn) && !/href="[^"]*f-droid\.org/i.test(dlZh),
    '★ 页面没有虚构的 F-Droid 链接（渠道不存在之前不给 URL）');
  check(/Signatures do not mix/.test(dlEn) && /签名不能混装/.test(dlZh),
    '★ 「签名不能混装」跨渠道警告双语都在（换渠道必须先卸载，本地数据不保）');
  check(dlEn.includes('version.json') && dlZh.includes('version.json'),
    '★ 双语都说明 App 更新检查读 version.json（机器可读事实源）');
  // 数据层二态：渠道 status 只许 live / pending 两种（防第三种假状态）
  const dlData = JSON.parse(fs.readFileSync(path.join(LANDING, 'data', 'download.json'), 'utf8'));
  const dlDataZh = JSON.parse(fs.readFileSync(path.join(LANDING, 'data', 'download-zh.json'), 'utf8'));
  const badStatus = [...dlData.channels, ...dlDataZh.channels]
    .filter((c) => c.status !== 'live' && c.status !== 'pending');
  check(badStatus.length === 0,
    '★ 渠道数据 status 只有 live/pending 两种（实测异常=' + badStatus.length + '）');
  check(dlData.channels.length === dlDataZh.channels.length,
    '★ 双语渠道数一致（en=' + dlData.channels.length + ' zh=' + dlDataZh.channels.length + '）');
}

// ★ 反漂移二连（0.105.0 收口自查实证补，承 0.99.0 APK 字节判据）：changelog 最新节里
//   **手抄的自我描述数字**同样会漂移——本轮 closeout 自查实证两例：
//   ① 交付记录把重建后的 dist 写成「46 页」（实为 52 文件 / 38 个 HTML）；
//   ② 删除行字节误记 15 B（实为 `# Changelog`+空行两行 CRLF = 16 B），还把 HEAD
//      总体量误作「删除前一刻」的体量（详见《交付记录》§126.1 自查事件三）。
//   ⇒ 最新节若出现这两种写法，数字必须与**可重算的事实源**吻合：
//     页数 = dist 下 .html 实际计数（每次构建现算，永不过期）；
//     删除字节 = 字面块 `# Changelog\r\n\r\n` 的算术值，且 git HEAD 仍含该块时加强校验
//     （本次提交删掉残留行后 HEAD 不再含该块 ⇒ 自动退为算术校验，不会因提交而误红）。
//     写法不存在则跳过（不强制未来版本沿用该措辞）；git 不可用则显形 SKIP。
const countHtmlFiles = (dir) => {
  let n = 0;
  const walk = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      if (e.isDirectory()) walk(path.join(d, e.name));
      else if (e.name.endsWith('.html')) n++;
    }
  };
  walk(dir);
  return n;
};
const delBlock = Buffer.from('# Changelog\r\n\r\n');
for (const clPair of [['en', clEn], ['zh', clZh]]) {
  const firstItem = clPair[1].split('<section class="log-item">')[1] || '';
  const latestSection = firstItem.split('<section class="log-item">')[0];
  const htmlCount = countHtmlFiles(DIST);
  for (const m of latestSection.matchAll(/(\d+) 个(?: ?HTML ?页?|产物页)/g)) {
    const cited = Number(m[1]);
    check(cited === htmlCount,
      '★ 反漂移：changelog（' + clPair[0] + '）最新节手抄的页数（' + cited +
      ' 个）与 dist 实际 HTML 数（' + htmlCount + '）一致');
  }
  const mDel = latestSection.match(/连同空行，共两行 CRLF = (\d+) B/);
  if (mDel) {
    const cited = Number(mDel[1]);
    let head = null;
    try {
      head = execFileSync('git', ['show', 'HEAD:CHANGELOG.md'], {
        cwd: path.join(__dirname, '..'), maxBuffer: 64 * 1024 * 1024,
      });
    } catch (e) {
      head = null;
    }
    if (!head) {
      console.log('  SKIP  changelog（' + clPair[0] +
        '）删除字节 git 加强校验：git 不可用（仍以算术值核对，见下）');
      check(cited === delBlock.length,
        '★ 反漂移：changelog（' + clPair[0] + '）最新节手抄的删除字节数（' + cited +
        ' B）== `# Changelog`+空行两行 CRLF 算术值（' + delBlock.length + ' B）');
      continue;
    }
    // 0.105.0 收口实证：原判据用朴素子串 `indexOf('# Changelog')` 来判
    // "残留标题行是否已随提交消失" —— 但 CHANGELOG 正文本身就会**提到**
    // `# Changelog`（0.105.0 这次修复的描述就是），于是提交后子串仍在
    // ⇒ inHead=false 且 strayGone=false ⇒ **守卫在提交后必然误红**
    // （工作区绿、HEAD 红 —— 最隐蔽的一类缺陷）。
    // 修正：判定只看**算术值**（手抄数 == 字面块字节数）；"HEAD 里是否还有
    // 独立成行的残留标题行" 降级为**提示行**，不参与 pass/fail。
    const citedOk = cited === delBlock.length;
    const headLines = head.toString('utf8').split('\n').map((l) => l.replace(/\r$/, ''));
    const strayLineInHead = headLines.some((l) => l.trim() === '# Changelog');
    check(citedOk,
      '★ 反漂移：changelog（' + clPair[0] + '）最新节手抄的删除字节数（' + cited +
      ' B）== `# Changelog`+空行两行 CRLF 算术值（' + delBlock.length + ' B）');
    console.log('  note  changelog（' + clPair[0] + '）git HEAD 里独立成行的 `# Changelog` 残留：' +
      (strayLineInHead ? '仍在（本次改动尚未提交）' : '已无（已随提交消失）') +
      ' —— 提示，不参与判定');
  }
}

// rule 1 + 8: nothing may be handed off to an address that does not exist yet.
// This is the check that would have caught today's bug - the offline checks
// above only police *resources* (js/css/img/font), never an <a href>.
{
  const own = site.brand.domain.replace(/\/+$/, '');
  const every = []; // { u, sponsored, https, blank, noopener }
  const walkHtml = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walkHtml(p);
      else if (e.name.endsWith('.html')) {
        const t = fs.readFileSync(p, 'utf8');
        // Walk <a ...> tags rather than bare hrefs: whether a link is an
        // affiliate link is decided by its rel, and that lives on the tag.
        for (const m of t.matchAll(/<a\b([^>]*)>/g)) {
          const attrs = m[1];
          const h = /href="(https?:\/\/[^"]+)"/.exec(attrs);
          if (!h) continue;
          every.push({
            u: h[1],
            sponsored: /rel="[^"]*\bsponsored\b/.test(attrs),
            https: h[1].indexOf('https://') === 0,
            blank: /target="_blank"/.test(attrs),
            noopener: /rel="[^"]*\bnoopener\b/.test(attrs),
          });
        }
      }
    }
  };
  walkHtml(DIST);

  // An affiliate link is the one legitimate exception to "no external anchors":
  // /self-host/ has to point at a hosting provider. It is exempt from the rule
  // only when it is *marked* as sponsored, so an unmarked external link - the
  // 2026-10-13 failure - still fails.
  const outside = [...new Set(every.filter((x) => !x.sponsored && x.u.indexOf(own) !== 0).map((x) => x.u))];
  const aff = [...new Set(every.filter((x) => x.sponsored && x.u.indexOf(own) !== 0).map((x) => x.u))];
  check(outside.length === 0,
    '★★ 全站没有未标记的站外锚点（当前 ' + outside.length + ' 个：' + outside.slice(0, 3).join(' / ') + '）——' +
    '这是 2026-10-13 实测主次 CTA 双双 404 的那条判据，离线自足管资源、这条管 <a href>');
  // 推广位不是后门：豁免只换"允许存在"，不换"可以不安全"。
  const affBad = every
    .filter((x) => x.sponsored && x.u.indexOf(own) !== 0)
    .filter((x) => !x.https || !x.blank || !x.noopener)
    .map((x) => x.u);
  check(affBad.length === 0,
    '★ 推广链接必须 https + target=_blank + rel 含 noopener（错=' + ([...new Set(affBad)].join(',') || '无') + '）');
  console.log('  note  已标记的站外推广链接：' + aff.length + ' 个' + (aff.length ? '（' + aff.join(' / ') + '）' : ''));
  const apkExternal = /href="https?:\/\/[^"]+\.apk"/.test(dlEn + dlZh);
  check(!apkExternal, '★ APK 下载入口不指向外部站点（自托管，ADR-001 规则 1）');
  check(site.cta.primaryUrl === '/download/' || (site.cta.primaryUrl || '').indexOf('/') === 0,
    '★ CTA 主按钮指向站内路径（当前 ' + site.cta.primaryUrl + '）');
  // ★ 反半接线（0.95.0 纪律，0.99.0 实证补）：中文数据源必须显式携带 URL，
  // 不许靠 build.js 的 `c.primaryUrl || site.cta.primaryUrl` 英文兜底
  // （site-zh.json 的 cta 原本没有 primaryUrl/secondaryUrl 键，渲染结果全靠
  //  英文兜底才正确 —— 数据层是半接线的，英文一改中文就静默跟坏）
  // ★ 0.106.0 实证更正：这一条原本钉的是 '/download/' + '/docs/' —— **英文路径**。
  // 它守住了「中文数据源必须显式带 URL」（0.99.0 的初衷），却把「中文站的 CTA
  // 指向英文页」这个缺陷当成了正确值钉死 ⇒ 中文用户点「获取 APK」进的是英文
  // /download/。中文站的 CTA 必须指向**中文**页。
  const zhCtaOk = (u1, u2) => u1 === '/zh/download/' && u2 === '/zh/docs/';
  check(zhCtaOk(siteZh.cta.primaryUrl, siteZh.cta.secondaryUrl),
    '★ 中文数据源 cta 显式携带**中文**站内 URL（不靠英文兜底；当前 ' +
    siteZh.cta.primaryUrl + ' / ' + siteZh.cta.secondaryUrl + '）');
  check(!zhCtaOk('/download/', '/zh/docs/'),
    '正控：中文 CTA 退回英文路径 /download/ 必须判出（判据非恒真）');
  check(!zhCtaOk('/zh/download/', '/docs/'),
    '正控：中文次级 CTA 退回英文路径 /docs/ 必须判出');

  // ★ 反半接线（0.106.0 实证）：中文页的可见链接必须全部指向中文路径。
  // 本站实测 14 个中文页全都有指向英文路径的链接（页脚 /docs/ + CTA /download/）。
  // 豁免：语言切换（它**本该**指向对方语言）、法务页（独立语种）、静态资源、APK。
  function walkZh(dir, out) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walkZh(p, out);
      else if (e.name.endsWith('.html')) out.push(p);
    }
    return out;
  }
  const zhFiles = fs.existsSync(path.join(DIST, 'zh')) ? walkZh(path.join(DIST, 'zh'), []) : [];
  const badZhLinks = [];
  for (const f of zhFiles) {
    const t = fs.readFileSync(f, 'utf8');
    const body = t.replace(/<head[\s\S]*?<\/head>/, '');
    const noSwitch = body.replace(/<span class="nav lang-alt">[\s\S]*?<\/span>/g, '');
    for (const m of noSwitch.matchAll(/<a[^>]*href="(\/[^"]*)"/g)) {
      const h = m[1];
      if (h.endsWith('.apk')) continue;
      if (h.startsWith('/assets/') || h === '/style.css' || h === '/favicon.svg') continue;
      if (h.startsWith('/privacy/') || h.startsWith('/terms/')) continue;
      if (!h.startsWith('/zh/')) badZhLinks.push(path.relative(DIST, f) + ' -> ' + h);
    }
  }
  check(badZhLinks.length === 0,
    '★ 反半接线：中文页可见链接全部指向中文路径（语言切换 / 法务 / 静态资源豁免）；' +
    '当前越界 ' + badZhLinks.length + ' 条' +
    (badZhLinks.length ? '：' + badZhLinks.slice(0, 4).join(' / ') : ''));

  // ★ 语言切换跳**当前页的对应语言版**，不回首页（否则中文用户拿不到中文下载页）
  check(/<a class="lang-switch-item" href="\/zh\/download\/">/.test(dlEn),
    '★ 英文下载页的语言切换指向 /zh/download/（跳当前页对应语言版，不回首页）');
  check(/<a class="lang-switch-item" href="\/download\/">/.test(dlZh),
    '★ 中文下载页的语言切换指向 /download/');
}


console.log('--- 离线自足（不依赖外部网络） ---');

const worldHtmlAll = Object.keys(worldPages)
  .map((k) => (fs.existsSync(path.join(DIST, worldPages[k].file)) ? read(worldPages[k].file) : ''))
  .join('');
const allHtml =
  home + priv + terms + Object.values(cityPages).join('') + legalPages.map((p) => p[1]).join('') +
  worldHtmlAll + Object.values(zhCityPages).join('') + clEn + clZh + zhHome;
check(!/https?:\/\/(?!wold\.world|www\.w3\.org|schema\.org|github\.com)[^"'\s]+\.(js|css|woff2?|ttf)/.test(allHtml),
  '页面不引用外部脚本/字体/样式（离线可完整渲染）');
check(!/<img[^>]+src="https?:/.test(allHtml), '页面无外部图片依赖');

console.log('');
console.log('================ 落地页校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
