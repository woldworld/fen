#!/usr/bin/env node
/**
 * Wold / Fen landing site - static generator.
 *
 * Zero dependencies, zero network access. Produces plain HTML so crawlers see
 * real content (the PRD explicitly rules out a client-rendered SPA for this).
 *
 *   node build.js            # writes landing/dist/
 *   node build.js --check    # build, then assert the output (no files written? no - it does write)
 *
 * Design rules baked in here:
 *  - A download button with no release URL is rendered as a NON-link. A button
 *    that goes nowhere is worse than one that admits it is not ready.
 *  - Every page carries schema.org JSON-LD and a canonical URL.
 *  - Fail loudly on malformed data (missing slug) instead of silently skipping.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = __dirname;
const REPO = path.join(ROOT, '..'); // landing/ sits directly under the repo root
const DIST = path.join(ROOT, 'dist');
const DATA = path.join(ROOT, 'data');
const SRC = path.join(ROOT, 'src');

// ---------------------------------------------------------------- helpers ---

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** JSON-LD is embedded in a <script>; `</script>` inside it would break out. */
function jsonLd(obj) {
  return JSON.stringify(obj)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026');
}

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function mkdirp(p) {
  fs.mkdirSync(p, { recursive: true });
}

// ---------------------------------------------------------- safe rm dir ---
//
// 0.105.0 收口：`fs.rmSync(DIST, { recursive: true })` 在本 Windows 主机上是
// **间歇性**卡死——递归走到一半（dist/ 删到一半）后彻底冻结，无 CPU、无 I/O，
// 把单线程的构建整个拖住。同一份 dist 单独跑 rmSync 秒删、dist 为空时构建也秒过，
// 只有「构建进程上下文 + 非空 dist」才偶发 ⇒ 环境级文件锁（AV 过滤驱动 / 索引器
// 持句柄），不是 rmSync 自身的 bug，更不是"一次性的"。
//
// 关键认识：目标是拿到**全新 dist**，不是"把旧目录删掉"。于是把 dist 改名让路
// （原子、O(1)、不遍历目录树），真正的 unlink 交给一个分离的子进程在关键路径之外
// 慢慢做。即便那个清理卡住，它要清理的那次构建早已结束。
function spawnJanitor(target) {
  const script =
    'const fs=require("fs");setTimeout(()=>process.exit(0),30000);' +
    'try{fs.rmSync(process.argv[1],{recursive:true,force:true,maxRetries:2,retryDelay:100});}catch(e){}' +
    'process.exit(0);';
  try {
    const child = spawn(process.execPath, ['-e', script, target], { detached: true, stdio: 'ignore' });
    child.unref();
  } catch (e) { /* 清理不成也安全：下轮开头会再扫一遍残留 */ }
}

/** 扫掉历史遗留的 .trash-dist-*（best-effort，绝不同步阻塞）。 */
function sweepTrash(parent) {
  let names;
  try { names = fs.readdirSync(parent); } catch (e) { return; }
  for (const name of names) {
    if (name.indexOf('.trash-dist-') !== 0) continue;
    spawnJanitor(path.join(parent, name));
  }
}

function safeRmDir(dir) {
  const parent = path.dirname(dir);
  sweepTrash(parent); // 先清遗留，免得把本轮刚改名的也重复交给 janitor
  if (!fs.existsSync(dir)) return;
  const trash = path.join(parent, '.trash-' + path.basename(dir) + '-' + process.pid + '-' + Date.now());
  try {
    fs.renameSync(dir, trash);
  } catch (e) {
    // 改名只在"目录本身被占用"（例如某 shell 正 cwd 在里面）时失败。
    // 退化为带重试的同步删除，宁可慢也别复用一棵陈旧目录树。
    fs.rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
    return;
  }
  spawnJanitor(trash);
}

function copyDir(srcD, dstD) {
  mkdirp(dstD);
  for (const e of fs.readdirSync(srcD, { withFileTypes: true })) {
    const s = path.join(srcD, e.name);
    const d = path.join(dstD, e.name);
    if (e.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

// ------------------------------------------------------------------- data ---

const site = readJson(path.join(DATA, 'site.json'));
const cities = readJson(path.join(DATA, 'cities.json'));
const siteZh = readJson(path.join(DATA, 'site-zh.json'));
// 0.98.0: the story is data, not code. Eight chapters per language; both files
// are build-critical sources (a missing file fails the build, same as site-zh).
const story = readJson(path.join(DATA, 'story.json'));
const storyZh = readJson(path.join(DATA, 'story-zh.json'));

// 0.99.0 / ADR-001: the download page is generated from a REAL apk file.
// Labels live here; every number (hash, byte count, version) is computed at
// build time. Hand-copied hashes always go stale after the next packaging run.
const download = readJson(path.join(DATA, 'download.json'));
const downloadZh = readJson(path.join(DATA, 'download-zh.json'));
// §7.2 self-host page. The referral URLs live in the data files, and they are
// empty on purpose: we do not have an affiliate account yet, and inventing a
// URL would be worse than having no button at all.
const selfHost = readJson(path.join(DATA, 'selfhost.json'));
const selfHostZh = readJson(path.join(DATA, 'selfhost-zh.json'));

// 0.103.0 / 整改方案阶段 D: the eight-step demo is data, not code. Every step
// carries both columns (what happens / what you control) in both languages; a
// step missing either column is a half-wired page, so the demo verifier counts
// them. `simulated` is not decoration - the banner is rendered from it, and the
// verifier pins that the banner cannot be removed.
const demo = readJson(path.join(DATA, 'demo.json'));
const demoZh = readJson(path.join(DATA, 'demo-zh.json'));

// 0.111.0: the demo page can embed a real walkthrough video. The mp4 is a
// binary asset that never enters git (same judgement as landing/download/);
// every number on the page (bytes, duration) is computed from
// landing/video/manifest.json, and the manifest itself is re-verified against
// the file on disk here AND by tool/verify_landing_video.js. A missing video
// directory ships an honest placeholder on both languages - same shape as
// downloadTruth(): a page that lies is worse than no page.
const VIDEO_DIR = path.join(ROOT, 'video');
let _videoInfo = null;
function videoTruth() {
  if (_videoInfo !== null) return _videoInfo;
  const man = path.join(VIDEO_DIR, 'manifest.json');
  if (!fs.existsSync(man)) {
    _videoInfo = null;
    return null;
  }
  const m = readJson(man);
  const abs = path.join(VIDEO_DIR, m.file);
  if (!fs.existsSync(abs)) {
    throw new Error('video: manifest names "' + m.file + '" but it is not in landing/video/');
  }
  const buf = fs.readFileSync(abs);
  if (buf.length !== m.bytes) {
    throw new Error('video: manifest says ' + m.bytes + ' bytes for ' + m.file + ', file is ' + buf.length);
  }
  const sha = crypto.createHash('sha256').update(buf).digest('hex');
  if (sha !== m.sha256) {
    throw new Error('video: manifest sha256 does not match ' + m.file);
  }
  _videoInfo = m;
  return _videoInfo;
}

// 0.104.0 / 整改方案阶段 E: the security page states mechanisms that are
// really implemented, and names the file that implements each one. `proof` is
// "path::keyword" and tool/verify_landing_security.js checks the keyword is
// genuinely present at that path - a claim we cannot point at does not ship.
const security = readJson(path.join(DATA, 'security.json'));
const securityZh = readJson(path.join(DATA, 'security-zh.json'));

// ------------------------------------------------- brand art (inline SVG) ---
// All artwork is inline SVG: it renders with zero network requests, and it is
// styled from CSS (not presentation attributes) so light/dark mode comes for
// free. Nothing here may introduce an external font, script or image: the
// offline-self-sufficient checks in tool/verify_landing.js depend on it.

const SECTION_ICONS = {
  'local-first':
    '<svg viewBox="0 0 24 24" aria-hidden="true">' +
    '<path d="M12 3l7.5 3.2v5.4c0 4.3-3.1 8-7.5 8.9-4.4-.9-7.5-4.6-7.5-8.9V6.2z"/>' +
    '<rect x="10.2" y="11" width="3.6" height="3.6" rx="0.8"/></svg>',
  'auditable':
    '<svg viewBox="0 0 24 24" aria-hidden="true">' +
    '<path d="M2 12s3.8-6.2 10-6.2S22 12 22 12s-3.8 6.2-10 6.2S2 12 2 12z"/>' +
    '<circle cx="12" cy="12" r="2.7"/></svg>',
  'how':
    '<svg viewBox="0 0 24 24" aria-hidden="true">' +
    '<path d="M3.2 8.6h12.4"/><path d="M13 5.9l2.8 2.7-2.8 2.7"/>' +
    '<path d="M20.8 15.4H8.4"/><path d="M11 12.7L8.2 15.4l2.8 2.7"/></svg>',
  'verifiable':
    '<svg viewBox="0 0 24 24" aria-hidden="true">' +
    '<circle cx="12" cy="12" r="8.6"/><path d="M8.2 12.2l2.6 2.6 5-5.4"/></svg>',
};

const BADGES = {
  en: ['Client MIT', 'Public transparency log', 'On-device by default'],
  zh: ['客户端 MIT 开源', '公开透明日志', '默认端上运行'],
};

/** The link the whole product is built on: your agent -> their agent ->
    the two humans. One glance answers the new tagline. Inline SVG, themable. */
function linkArt(lang) {
  const zh = lang === 'zh';
  const t = zh
    ? { you: '你', ya: '你的分身', ta: '对方的分身', tp: '对方的人',
        cap1: '分身先见面', cap2: '值得时，两个真人才见面',
        alt: '你的分身与对方的分身先互相认识，两个真人只在该见面时见面' }
    : { you: 'You', ya: 'Your agent', ta: 'Their agent', tp: 'The person',
        cap1: 'agents meet first', cap2: 'humans meet when it is worth it',
        alt: 'Your agent meets their agent first; the two humans meet only when it is worth it' };
  return '<svg class="hero-link" viewBox="0 0 470 250" role="img" aria-label="' + t.alt + '">' +
    '<path class="lk-line" d="M85 185 L175 75"/>' +
    '<path class="lk-line-hot" d="M175 75 L295 75"/>' +
    '<path class="lk-line" d="M295 75 L385 185"/>' +
    '<circle class="lk-node-h" cx="85" cy="185" r="24"/>' +
    '<circle class="lk-node-a" cx="175" cy="75" r="24"/>' +
    '<circle class="lk-node-a" cx="295" cy="75" r="24"/>' +
    '<circle class="lk-node-h" cx="385" cy="185" r="24"/>' +
    '<text text-anchor="middle" x="85" y="225">' + esc(t.you) + '</text>' +
    '<text text-anchor="middle" class="lk-strong" x="175" y="40">' + esc(t.ya) + '</text>' +
    '<text text-anchor="middle" class="lk-strong" x="295" y="40">' + esc(t.ta) + '</text>' +
    '<text text-anchor="middle" x="385" y="225">' + esc(t.tp) + '</text>' +
    '<text text-anchor="middle" class="lk-cap" x="235" y="110">' + esc(t.cap1) + '</text>' +
    '<text text-anchor="middle" class="lk-cap" x="235" y="150">' + esc(t.cap2) + '</text>' +
    '</svg>';
}

/* 0.98.0: 小荒 - the sprite that walks the visitor through the World, one
   chapter at a time. Three states (egg / hatched / alert), inline SVG only,
   themable from CSS vars. No external art: the offline guard depends on it. */
function spriteArt(state) {
  const s = state || 'hatched';
  const shell =
    s === 'egg'
      ? '<ellipse class="sp-shell" cx="60" cy="66" rx="33" ry="41"/>' +
        '<path class="sp-crack" d="M41 52l13 11-9 12 15 8-11 14"/>'
      : '<path class="sp-tail" d="M62 94c-15 13-24 7-28 20 13-3 20-9 28-20z"/>' +
        '<ellipse class="sp-orb" cx="60" cy="58" rx="37" ry="34"/>' +
        '<ellipse class="sp-shine" cx="45" cy="45" rx="11" ry="7"/>';
  const face =
    s === 'egg'
      ? ''
      : s === 'alert'
        ? '<path class="sp-eye" d="M41 56h14M67 56h14"/><path class="sp-brow" d="M40 46l14 6M68 46l12 6"/>' +
          '<path class="sp-mouth" d="M52 74q8-5 16 0"/>'
        : '<circle class="sp-eye" cx="48" cy="56" r="6"/><circle class="sp-eye" cx="74" cy="56" r="6"/>' +
          '<path class="sp-mouth" d="M52 72q8 6 16 0"/>';
  return (
    '<svg class="sprite-svg sprite-' + s + '" viewBox="0 0 120 130" role="img" aria-hidden="true">' +
    shell + face + '</svg>'
  );
}

/** Story copy carries just one bit of markup: **emphasis**. Escape first,
    then expand - never the other way round. */
function mdLite(s) {
  return esc(s).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
}

/** 0.98.0: the whole theatre runs on ~30 lines of inline JS. No framework, no
    network: naming the sprite, rolling its personality, crossing out the bad
    line, and lighting the current chapter in the table of contents. */
const STORY_SCRIPT = `<script>
(function () {
  var egg = document.getElementById('egg');
  var panel = document.getElementById('awaken-panel');
  var nameIn = document.getElementById('sprite-name');
  var diceBtn = document.getElementById('dice');
  var trait = document.getElementById('trait');
  if (egg && panel) {
    egg.addEventListener('click', function () {
      panel.classList.add('is-open');
      egg.classList.add('is-hatched');
      if (nameIn) nameIn.focus();
    });
  }
  if (nameIn) {
    var out = document.querySelectorAll('.js-sprite-name');
    nameIn.addEventListener('input', function () {
      var v = nameIn.value.trim() || nameIn.getAttribute('data-default');
      for (var i = 0; i < out.length; i++) out[i].textContent = v;
    });
  }
  if (diceBtn && trait) {
    var traits = (trait.getAttribute('data-traits') || '').split('|');
    diceBtn.addEventListener('click', function () {
      var t = traits[Math.floor(Math.random() * traits.length)];
      trait.textContent = t;
      trait.classList.add('is-on');
    });
  }
  var bad = document.getElementById('bad-line');
  var note = document.getElementById('audit-note');
  if (bad) {
    var undo = function () {
      bad.classList.add('is-undone');
      bad.setAttribute('aria-disabled', 'true');
      if (note) { note.hidden = false; note.classList.add('is-on'); }
    };
    bad.addEventListener('click', undo);
    bad.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); undo(); }
    });
  }
  var links = document.querySelectorAll('.toc a');
  if (links.length && 'IntersectionObserver' in window) {
    var map = {};
    for (var j = 0; j < links.length; j++) map[links[j].getAttribute('href').replace('#', '')] = links[j];
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        var a = map[en.target.id];
        if (a && en.isIntersecting) {
          for (var k = 0; k < links.length; k++) links[k].classList.remove('is-active');
          a.classList.add('is-active');
        }
      });
    }, { rootMargin: '-45% 0px -45% 0px' });
    document.querySelectorAll('.chapter').forEach(function (c) { io.observe(c); });
  }
})();
</script>`;

const docsZh = readJson(path.join(DATA, 'docs-zh.json'));
const faqZh = readJson(path.join(DATA, 'site-zh.json')).faq || [];
const css = fs.readFileSync(path.join(SRC, 'style.css'), 'utf8');

const DOMAIN = site.brand.domain.replace(/\/+$/, '');
const TODAY = new Date().toISOString().slice(0, 10);

// Fail loudly rather than emitting a page with a broken URL.
const seen = new Set();
for (const c of cities) {
  if (!c.slug || !c.name || !c.country) {
    throw new Error('city entry missing slug/name/country: ' + JSON.stringify(c));
  }
  if (seen.has(c.slug)) throw new Error('duplicate city slug: ' + c.slug);
  seen.add(c.slug);
  // Each city page needs its own body. Without it every city page is the same
  // page with a different name, which is exactly what a doorway page looks like.
  if (!Array.isArray(c.arc) || c.arc.length < 2 || c.arc.some((p) => !String(p).trim())) {
    throw new Error('city "' + c.slug + '" needs arc: [2 unique paragraphs]');
  }
}

// The arc paragraphs must be genuinely different per city, not reshuffled.
const arcSeen = new Set();
for (const c of cities) {
  for (const p of c.arc) {
    const key = String(p).trim();
    if (arcSeen.has(key)) throw new Error('duplicate city paragraph (doorway-page risk): ' + key.slice(0, 60));
    arcSeen.add(key);
  }
}

// 0.96.0: image-led cards. A city without a local image is a build failure,
// not an empty box on the grid - and only local relative paths are allowed
// (offline self-sufficiency; verify_landing.js still bans every http(s) src).
for (const c of cities) {
  if (!c.image || !/^\/assets\/city\/[a-z0-9-]+\.jpg$/.test(c.image)) {
    throw new Error('city "' + c.slug + '" needs image: /assets/city/<slug>.jpg');
  }
  if (!fs.existsSync(path.join(SRC, c.image))) {
    throw new Error('city "' + c.slug + '" image missing on disk: ' + c.image);
  }
  if (!c.zh || !c.zh.image || c.zh.image !== c.image) {
    throw new Error('city "' + c.slug + '" zh.image must exist and equal image');
  }
}

// /privacy/ and /terms/ are store-submission prerequisites (each needs a
// reachable URL) and both are generated from compliance drafts, so a missing
// source, a renamed file, or an unfilled value is a build failure - never a
// quietly missing (or quietly half-filled) page.
const LEGAL_REQUIRED = [
  'policySource',
  'termsSource',
  'effectiveDate',
  'dataLocation',
  'crossBorderBasis',
  'applicableLaw',
  'disputeResolution',
];
if (!site.legal) throw new Error('site.json is missing the "legal" block (needed for /privacy/ and /terms/)');
for (const k of LEGAL_REQUIRED) {
  if (!site.legal[k] || !String(site.legal[k]).trim()) {
    throw new Error('site.legal.' + k + ' is empty - fill it before building the legal pages');
  }
}
for (const k of ['policySource', 'termsSource']) {
  if (!fs.existsSync(path.resolve(REPO, site.legal[k]))) {
    throw new Error('site.legal.' + k + ' not found: ' + site.legal[k]);
  }
}

// ------------------------------------------------------------- page parts ---

function head({ title, description, canonical, alternates }) {
  const alt = (alternates || [])
    .map((a) => `\n<link rel="alternate" hreflang="${esc(a.hreflang)}" href="${esc(a.href)}">`)
    .join('');
  return `<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<link rel="canonical" href="${esc(canonical)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="${esc(site.brand.platform)}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${esc(canonical)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#b4471f" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0f1115" media="(prefers-color-scheme: dark)">
<link rel="icon" type="image/svg+xml" href="/favicon.svg">
<link rel="stylesheet" href="/style.css">${alt}`;
}

function siteHead(lang = 'en', altUrl) {
  // 页面传进来的 lang 是 BCP-47（'zh-CN'），不能用 === 'zh' 判（0.93.0 目视审查发现：
  // 中文页 nav/语言切换因此一直按英文渲染）。
  const zh = String(lang).toLowerCase().indexOf('zh') === 0;
  // 0.104.0 / stage E: order the nav by the question a stranger asks first -
  // what is it (How it works) -> show me (Demo) -> can I trust it (Security),
  // then the reference material. Changelog and Cities keep their footer /
  // homepage entries; the nav is not a sitemap.
  const links = zh
    ? [['/zh/#how', '怎么运作'], ['/zh/demo/', '演示'], ['/zh/security/', '安全机制'],
       ['/zh/world/', '大荒世界'], ['/zh/docs/', '文档'], ['/zh/faq/', '常见问题']]
    : [['/#how', 'How it works'], ['/demo/', 'Demo'], ['/security/', 'Security'],
       ['/world/', 'World'], ['/docs/', 'Docs'], ['/faq/', 'FAQ']];
  const nav = links.map(([h, t]) => `<a href="${h}">${esc(t)}</a>`).join('');
  // 0.106.0：语言切换跳**当前页的对应语言版**，不回首页。
  // 旧行为（恒指首页）与中文 CTA 指向英文页叠加后是个死循环：中文用户在
  // /download/ 点「中文」→ 落到中文首页 → 点「获取 APK」→ 又回英文
  // /download/ ⇒ 中文用户实际上永远拿不到中文下载页（本站实测 14 个中文页
  // 全都有指向英文路径的可见链接）。altUrl 由 page() 的 counterpartUrl()
  // 按镜像页清单算出；没有镜像的页（法务页自带语种切换）退回首页。
  const altHref = altUrl || (zh ? '/' : '/zh/');
  const alt = zh
    ? `<a class="lang-switch-item" href="${esc(altHref)}">English</a>`
    : `<a class="lang-switch-item" href="${esc(altHref)}">中文</a>`;
  return `<header class="site-head">
  <div class="wrap">
    <a class="brand-mark" href="/${zh ? 'zh/' : ''}">${esc(site.brand.platform)}<span>.</span></a>
    <nav class="nav" aria-label="Primary">${nav}</nav>
    <span class="nav lang-alt">${alt}</span>
  </div>
</header>`;
}

function siteFoot(lang = 'en') {
  const zh = String(lang).toLowerCase().indexOf('zh') === 0;
  const F = zh ? siteZh.footer : site.footer;
  // ★ 链接写成字面量，不用数据表拼接：tool/verify_legal_links.dart 钉
  //   `href="/privacy/"` / `href="/terms/"` 两个源码字面量（0.93.0 实证：
  //   改成 map 拼接后字面量消失 ⇒ 守卫当场红）。改这里时必须保住字面量。
  const links = zh
    ? `<a href="/zh/docs/">文档</a> &middot; <a href="/zh/faq/">常见问题</a> &middot; <a href="/zh/changelog/">更新日志</a> &middot; <a href="/zh/self-host/">自己搭</a> &middot; <a href="/privacy/">隐私</a> &middot; <a href="/terms/">条款</a>`
    : `<a href="/docs/">Docs</a> &middot; <a href="/faq/">FAQ</a> &middot; <a href="/changelog/">Changelog</a> &middot; <a href="/self-host/">Self-host</a> &middot; <a href="/privacy/">Privacy</a> &middot; <a href="/terms/">Terms</a>`;
  return `<footer class="site-foot">
  <div class="wrap">
    <p>${esc(F.license)}</p>
    <p>${esc(F.note)}</p>
    <p>${links} &middot; <a href="${esc((zh ? siteZh : site).cta.secondaryUrl)}">${zh ? '协议' : 'Protocol'}</a> &middot; ${esc(site.brand.protocol)}</p>
  </div>
</footer>`;
}

/** Primary CTA. Empty URL => honest non-link, never a dead href. */
function primaryCta(S) {
  const c = (S || site).cta;
  const url = c.primaryUrl || site.cta.primaryUrl;
  if (url) {
    return `<a class="btn btn-primary" href="${esc(url)}">${esc(c.primaryLabel)}</a>`;
  }
  return `<span class="btn btn-disabled" aria-disabled="true" role="link">${esc(c.primaryFallback || c.primaryLabel)}</span>`;
}

function secondaryCta(S) {
  const c = (S || site).cta;
  const url = c.secondaryUrl || site.cta.secondaryUrl;
  if (!url) return '';
  return `<a class="btn btn-ghost" href="${esc(url)}">${esc(c.secondaryLabel)}</a>`;
}

// ---------- system knowledge portal (/docs, /faq, llms.txt) ----------
// 单一事实源：lib/core/system_knowledge.dart（智能体检索用的同一条目）。
// 解析失败或条目数异常 = 构建失败（与隐私页同纪律：宁可不建站，不发半个站）。

function parseKnowledge() {
  const src = fs.readFileSync(
    path.join(REPO, 'lib', 'core', 'system_knowledge.dart'),
    'utf8'
  );
  const BS = String.fromCharCode(92);
  const marker = "HelpEntry('";  // ★ 只匹配条目（类构造器 HelpEntry(this.id 不带引号，自动跳过）
  const entries = [];
  let i = src.indexOf(marker);
  while (i !== -1) {
    let p = i + marker.length;
    const fields = [];
    for (let f = 0; f < 4 && p < src.length; f++) {
      if (f > 0) {
        while (p < src.length && src[p] !== "'") p++; // 跳到本字段开引号
        p++; // 过开引号
      }
      let val = '';
      while (p < src.length && src[p] !== "'") {
        if (src[p] === BS) { val += src[p] + src[p + 1]; p += 2; continue; }
        val += src[p];
        p++;
      }
      p++; // 过闭引号
      fields.push(val);
    }
    const un = (t) => t.split(BS + "'").join("'");
    entries.push({
      id: un(fields[0]),
      title: un(fields[1]),
      keywords: un(fields[2]),
      steps: un(fields[3]),
    });
    i = src.indexOf(marker, p);
  }
  if (entries.length < 40) {
    throw new Error(
      'system_knowledge parse found only ' + entries.length +
      ' entries (expected >=40) - the Dart file shape changed?'
    );
  }
  const ver = (src.match(/kbVersion = '([^']+)'/) || [])[1] || '0';
  return { entries, version: ver };
}
// FAQ 策展（对账实际 id；条目缺失自动跳过——KB 演进不炸构建）
const FAQ_CURATION = [
  ['What is Fen, in one paragraph?', 'onboarding'],
  ['How do I start socializing with my agent?', 'radar'],
  ['Why did my Wi-Fi turn on by itself?', 'ts_wifi'],
  ['My agent stopped replying. What should I check?', 'ts_no_reply'],
  ['How do I back up my identity?', 'backup_code'],
  ['What happens when the free 20 turns run out?', 'trial_exhausted'],
  ['How do input length limits work?', 'input_limits'],
  ['How do I move to a new phone?', 'device_migration'],
  ['How do I export my chats and memories?', 'export_archive'],
  ['How does trust and reputation work here?', 'reputation'],
  ['Can the agent operate my phone for me?', 'device_control'],
  ['Where is my data stored, and who can read it?', 'privacy_data'],
  ['How do I connect my email?', 'email'],
  ['What are reminders and how do they fire?', 'reminders'],
  ['What will the agent NOT do for me?', 'agent_boundary'],
];

function faqItems(kb) {
  const byId = new Map(kb.entries.map((e) => [e.id, e]));
  const out = [];
  for (const [q, id] of FAQ_CURATION) {
    const e = byId.get(id);
    if (e) out.push({ q, a: e.steps, id: e.id });
  }
  if (out.length < 8) {
    throw new Error('FAQ curation matched only ' + out.length + ' items - KB ids drifted?');
  }
  return out;
}

// --------------------------------------------- 双语镜像页（0.106.0） ------
// 有「同路径中文版」的页面清单。法务页**不在**此列：它们的中文版是
// /zh-Hant/privacy/ 这类独立语种页、且页面内自带语种切换，套 /zh/ 前缀会
// 指向不存在的路径（= 死链，会被「全站无死链」判据抓住）。
const ZH_MIRROR_PATHS = new Set([
  '/', '/world/', '/docs/', '/faq/', '/changelog/', '/download/', '/demo/', '/security/',
  ...cities.map((c) => '/' + c.slug + '/'),
]);

/** 当前页的对应语言版 URL；无镜像时退回对方首页。 */
function counterpartUrl(canonical, zh) {
  let p = String(canonical || '');
  if (p.indexOf(DOMAIN) === 0) p = p.slice(DOMAIN.length);
  if (p.charAt(0) !== '/') p = '/' + p;
  const enPath = zh ? (p.replace(/^\/zh(?=\/|$)/, '') || '/') : p;
  if (!ZH_MIRROR_PATHS.has(enPath)) return zh ? '/' : '/zh/';
  if (zh) return enPath === '/' ? '/' : enPath;
  return '/zh' + (enPath === '/' ? '/' : enPath);
}

function page({ title, description, canonical, body, ld, lang = 'en', alternates }) {
  const zhPage = String(lang).toLowerCase().indexOf('zh') === 0;
  return `<!DOCTYPE html>
<html lang="${esc(lang)}">
<head>
${head({ title, description, canonical, alternates })}
<script type="application/ld+json">${jsonLd(ld)}</script>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
${siteHead(lang, counterpartUrl(canonical, zhPage))}
<main id="main">
${body}
</main>
${siteFoot(lang)}
</body>
</html>
`;
}

// ------------------------------------------------------------ home  page ---

// ------------------------------------------------- product explain layer ---
// 0.102.0: the homepage used to be a theatre and nothing else. An external
// review (2026-10-13) found that a first-time visitor cannot tell what the
// product IS without reading all eight chapters. This is the "product explain
// layer": positioning -> three steps -> demo door -> honest status -> developer
// doors. It is inserted BETWEEN the hero and the chapters, so the theatre
// survives untouched (tool/verify_landing.js asserts the chapter ids remain).
// ★ Two rules this block must never break:
//   1. No claim here may describe a planned feature as shipped - that is what
//      the "still being built" column is for (R27: claims must be checkable).
//   2. No term marked homepageHighlight:false in data/glossary.json may appear
//      here (小荒 / Wildland / 大荒AI are story or internal names, not product
//      names). tool/verify_landing_explain.js asserts both.
function explainHtml(S, zh) {
  const X = S.explain;
  if (!X) return '';

  const steps = (X.steps || [])
    .map(
      (s) => `        <li class="step">
          <span class="step-no">${esc(s.no)}</span>
          <div class="step-body">
            <h3>${esc(s.title)}</h3>
            <p>${esc(s.body)}</p>
          </div>
        </li>`
    )
    .join('\n');

  const ready = (X.ready || []).map((r) => `          <li>${esc(r)}</li>`).join('\n');
  const wip = (X.wip || []).map((r) => `          <li>${esc(r)}</li>`).join('\n');

  const devLinks = (X.devLinks || [])
    .map(
      (d) => `        <a class="dev-card" href="${esc(d.href)}">
          <div class="dev-name">${esc(d.name)}</div>
          <div class="dev-desc">${esc(d.desc)}</div>
          <div class="dev-go">${esc(d.go)} &rarr;</div>
        </a>`
    )
    .join('\n');

  return `  <section class="explain" id="what">
    <div class="wrap">
      <p class="eyebrow">${esc(X.eyebrow)}</p>
      <h2>${esc(X.title)}</h2>
      <p class="explain-lede">${esc(X.lede)}</p>
      <p class="explain-cta">${primaryCta(S)}</p>

      <div class="steps-block">
        <p class="eyebrow">${esc(X.stepsEyebrow)}</p>
        <ol class="steps">
${steps}
        </ol>
      </div>

      <div class="demo-door">
        <div class="demo-text">
          <p class="eyebrow">${esc(X.demoEyebrow)}</p>
          <h3>${esc(X.demoTitle)}</h3>
          <p class="demo-body">${esc(X.demoBody)}</p>
          <p class="demo-note">${esc(X.demoNote)}</p>
        </div>
        <a class="btn btn-ghost" href="${zh ? '/zh/demo/' : '/demo/'}">${esc(X.demoLabel)}</a>
      </div>
    </div>
  </section>

  <section class="explain status" id="status">
    <div class="wrap">
      <p class="eyebrow">${esc(X.statusEyebrow)}</p>
      <h2>${esc(X.statusTitle)}</h2>
      <div class="status-cols">
        <div class="status-col">
          <h3 class="ok-head">${esc(X.readyLabel)}</h3>
          <ul class="status-list ok-list">
${ready}
          </ul>
        </div>
        <div class="status-col">
          <h3 class="wip-head">${esc(X.wipLabel)}</h3>
          <ul class="status-list wip-list">
${wip}
          </ul>
        </div>
      </div>
    </div>
  </section>

  <section class="explain dev" id="developers">
    <div class="wrap">
      <p class="eyebrow">${esc(X.devEyebrow)}</p>
      <h2>${esc(X.devTitle)}</h2>
      <div class="dev-grid">
${devLinks}
      </div>
    </div>
  </section>`;
}

function homeHtml(lang = 'en') {
  const zh = lang === 'zh';
  const S = zh ? siteZh : site;

  const badges = (BADGES[zh ? 'zh' : 'en'] || [])
    .map((b) => `          <li>${esc(b)}</li>`)
    .join('\n');

  // 0.98.0: the homepage is a theatre, not a brochure. Eight chapters, one
  // screen each, each ending on a hook. Four chapters carry the old section
  // ids (local-first / auditable / how / verifiable) so every product anchor
  // survives the rewrite - tool/verify_landing.js asserts those ids.
  const ST = zh ? storyZh : story;
  const defName = zh ? '小荒' : 'Xiaohuang';
  const cityBySlug = {};
  cities.forEach((c) => { cityBySlug[c.slug] = c; });

  const reel = ST.citiesReel
    .map((r) => {
      const c = cityBySlug[r.slug];
      if (!c) throw new Error('story citiesReel: unknown slug "' + r.slug + '"');
      const nm = zh && c.zh ? c.zh.name : c.name;
      const ct = zh && c.zh && c.zh.country ? c.zh.country : c.country;
      const href = (zh ? '/zh/' : '/') + c.slug + '/';
      return `        <a class="city-card has-media reel-card" href="${href}">
          <div class="city-media"><img src="${esc(c.image)}" alt="${esc(nm)}" width="700" height="467" loading="lazy"></div>
          <div class="city-body">
            <div class="city-name">${esc(nm)}</div>
            <div class="city-country">${esc(ct)}</div>
            <p class="reel-line">${mdLite(r.line)}</p>
          </div>
        </a>`;
    })
    .join('\n');

  const U = ST.undo || {};
  const auditBlock = `      <div class="audit" id="audit">
        <p class="audit-label">${esc(U.label || '')}</p>
        <p class="audit-hint">${esc(U.hint || '')}</p>
        <ul class="audit-lines">
${(U.lines || [])
  .map(
    (l) =>
      `          <li class="audit-line${l === U.badLine ? ' audit-bad" id="bad-line" role="button" tabindex="0' : ''}">${mdLite(l)}</li>`
  )
  .join('\n')}
        </ul>
        <p class="audit-note" id="audit-note" hidden>${esc(U.undoneNote || '')}</p>
      </div>`;

  const entries = S.entries
    .map(
      (e) => `        <a class="entry-card" href="${esc(e.href)}">
          <div class="entry-name">${esc(e.name)}</div>
          <div class="entry-desc">${esc(e.desc)}</div>
          <div class="entry-go">${esc(e.go)} &rarr;</div>
        </a>`
    )
    .join('\n');

  function chapterHtml(c) {
    const head = `      <div class="chapter-head">
        <span class="chapter-no">${esc(c.ordinal)}</span>
        <h2>${esc(c.title)}</h2>
        <p class="chapter-sub">${esc(c.subtitle || '')}</p>
      </div>`;
    const bubbles = (c.lines || [])
      .map(
        (l) => `        <div class="bubble">
          <span class="bubble-avatar" aria-hidden="true">${spriteArt('hatched')}</span>
          <div class="bubble-body">
            <span class="bubble-who js-sprite-name">${esc(defName)}</span>
            <p>${mdLite(l)}</p>
            <span class="bubble-sig" aria-hidden="true">${SECTION_ICONS.verifiable || ''}</span>
          </div>
        </div>`
      )
      .join('\n');
    let extra = '';
    if (c.kind === 'cities') extra = `\n      <div class="reel">\n${reel}\n      </div>`;
    if (c.kind === 'undo') extra = '\n' + auditBlock;
    if (c.kind === 'finale') {
      extra =
        `\n      <div class="entry-grid">\n${entries}\n      </div>` +
        `\n      <div class="actions fin-actions">\n        ${primaryCta(S)}\n        ${secondaryCta(S)}\n      </div>`;
    }
    const hook = c.hook ? `\n      <p class="hook">${mdLite(c.hook)}</p>` : '';
    const value = c.value
      ? `\n      <p class="value-tag"><span class="value-main">${esc(c.value)}</span>${c.valueNote ? '<span class="value-note">' + esc(c.valueNote) + '</span>' : ''}</p>`
      : '';
    return `  <section class="chapter chapter-${esc(c.kind)}" id="${esc(c.id)}">
    <div class="wrap chapter-inner">
${head}
      <div class="bubbles">
${bubbles}
      </div>${extra}${hook}${value}
    </div>
  </section>`;
  }

  const aw = ST.chapters.find((c) => c.kind === 'awaken') || {};
  const toc = ST.chapters
    .map((c) => `      <a href="#${esc(c.id)}"><span>${esc(c.ordinal)}</span>${esc(c.title)}</a>`)
    .join('\n');

  const hero = `  <section class="hero chapter-hero" id="awaken" style="--hero-img:url(/assets/city/tokyo.jpg)">
    <div class="hero-bg" aria-hidden="true"></div>
    <div class="wrap hero-stack">
      <p class="story-tag">${esc(ST.storyTag)}</p>
      <h1>${esc(S.tagline).replace('，', '，<br>')}</h1>
      <p class="lede">${esc(S.heroSub)}</p>
      <div class="awaken">
        <button class="egg" id="egg" type="button" aria-label="${esc(aw.eggHint || '')}">
          ${spriteArt('egg')}${spriteArt('hatched')}
          <span class="egg-hint">${esc(aw.eggHint || '')}</span>
        </button>
        <div class="awaken-panel" id="awaken-panel">
          <label class="sr-only" for="sprite-name">${esc(aw.namePlaceholder || '')}</label>
          <input class="name-input" id="sprite-name" type="text" maxlength="8" placeholder="${esc(aw.namePlaceholder || '')}" data-default="${esc(aw.nameDefault || defName)}">
          <button class="btn-dice" id="dice" type="button">${esc(aw.diceLabel || '')}</button>
          <p class="trait" id="trait" data-traits="${esc((aw.traits || []).join('|'))}"></p>
          <p class="dice-note">${esc(aw.diceNote || '')}</p>
        </div>
      </div>
      <div class="actions">
        ${primaryCta(S)}
        ${secondaryCta(S)}
      </div>
      <ul class="trust">
${badges}
      </ul>
      <p class="scroll-hint">${esc(ST.scrollHint || '')}</p>
      <p class="hook">${mdLite(aw.hook || '')}</p>
      <p class="value-tag"><span class="value-main">${esc(aw.value || '')}</span>${aw.valueNote ? '<span class="value-note">' + esc(aw.valueNote) + '</span>' : ''}</p>
    </div>
  </section>`;

  const rest = ST.chapters.filter((c) => c.kind !== 'awaken').map(chapterHtml).join('\n\n');
  const explain = explainHtml(S, zh);

  const body = `${hero}

${explain}

${rest}

  <p class="disclaimer">${mdLite(ST.disclaimer)}</p>

  <nav class="toc" aria-label="${esc(ST.navLabel || '')}">
    <span class="toc-label">${esc(ST.navLabel || '')}</span>
${toc}
  </nav>
${STORY_SCRIPT}`;

  const ld = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: S.brand.app,
    applicationCategory: 'SocialNetworkingApplication',
    operatingSystem: 'Android',
    description: S.heroSub,
    url: DOMAIN + '/',
    publisher: { '@type': 'Organization', name: site.brand.platform, url: DOMAIN + '/' },
    isPartOf: { '@type': 'WebSite', name: site.brand.platform, url: DOMAIN + '/' },
  };

  return page({
    title: `${S.brand.app} - ${S.tagline}`,
    description: S.heroSub,
    canonical: DOMAIN + (zh ? '/zh/' : '/'),
    body,
    ld,
    lang: zh ? 'zh-CN' : 'en',
    alternates: [{ hreflang: zh ? 'en' : 'zh', href: DOMAIN + (zh ? '/' : '/zh/') }],
  });
}

// ------------------------------------------------------- world  page ---
// 大荒世界页：房间图鉴（机制，非实时列表）+ 官方分身 + 隐私设计。
// ★ 实证（0.94.0）：GET /api/world/rooms 要求签名身份（匿名请求 401），
//   个人房刻意不可枚举（房间号=QQ 群号模式）⇒ 官网**不展示**实时房间与真实用户
//   动态，这是协议层的隐私设计，本身就是要讲的卖点。官方分身台词来自
//   lib/hub/seed-rooms.js 台词库（真实存在，非虚构），并标注「非实时」。

function worldHtml(lang = 'en') {
  const zh = lang === 'zh';
  const W = zh ? siteZh.world : site.world;
  const pts = (arr) => (arr || []).map((p) => `        <li>${esc(p)}</li>`).join('\n');
  const roomCards = W.rooms
    .map(
      (r) => `        <div class="city-card">
          <div class="city-name">${esc(r.name)}</div>
          <div class="city-blurb">${esc(r.desc)}</div>
        </div>`
    )
    .join('\n');
  const agentCards = W.agents
    .map(
      (a) => `        <div class="city-card">
          <div class="city-name">${esc(a.name)}</div>
          <div class="agent-id">${esc(a.id)}</div>
          <blockquote class="agent-quote">${esc(a.line)}</blockquote>
        </div>`
    )
    .join('\n');
  const body = `  <section class="hero slim">
    <div class="wrap">
      <h1>${esc(W.title)}</h1>
      <p class="hero-sub">${esc(W.sub)}</p>
    </div>
  </section>

  <section class="block" id="community">
    <div class="wrap">
      <p class="eyebrow">${esc(W.communityEyebrow)}</p>
      <h2>${esc(W.communityTitle)}</h2>
      <p class="body">${esc(W.communityBody)}</p>
      <ul class="points">
${pts(W.communityPoints)}
      </ul>
    </div>
  </section>

  <section class="block alt" id="rooms">
    <div class="wrap">
      <p class="eyebrow">${esc(W.roomsEyebrow)}</p>
      <h2>${esc(W.roomsTitle)}</h2>
      <p class="body">${esc(W.roomsBody)}</p>
      <div class="city-grid">
${roomCards}
      </div>
    </div>
  </section>

  <section class="block" id="agents">
    <div class="wrap">
      <p class="eyebrow">${esc(W.agentsEyebrow)}</p>
      <h2>${esc(W.agentsTitle)}</h2>
      <div class="agent-grid">
${agentCards}
      </div>
      <p class="note">${esc(W.agentsNote)}</p>
    </div>
  </section>

  <section class="block alt" id="design">
    <div class="wrap">
      <p class="eyebrow">${esc(W.designEyebrow)}</p>
      <h2>${esc(W.designTitle)}</h2>
      <p class="body">${esc(W.designBody)}</p>
      <ul class="points">
${pts(W.designPoints)}
      </ul>
      <div class="actions">
        <a class="btn btn-ghost" href="${zh ? '/zh/docs/' : '/docs/'}">${esc(W.docsCta)}</a>
      </div>
    </div>
  </section>`;

  const ld = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: W.title,
    description: W.sub,
    url: DOMAIN + (zh ? '/zh/world/' : '/world/'),
    isPartOf: { '@type': 'WebSite', name: site.brand.platform, url: DOMAIN + '/' },
  };
  return page({
    title: `${W.title} - ${site.brand.app}`,
    description: W.sub,
    canonical: DOMAIN + (zh ? '/zh/world/' : '/world/'),
    body,
    ld, // 传对象：page() 内部已做 jsonLd()，传字符串会被二次序列化成「字符串的 JSON」（0.94.0 守卫实证）
    lang: zh ? 'zh-CN' : 'en',
    alternates: [{ hreflang: zh ? 'en' : 'zh', href: DOMAIN + (zh ? '/world/' : '/zh/world/') }],
  });
}

// ------------------------------------------------------------ demo page ---
// 0.103.0 / 整改方案阶段 D.
//
// The single most common failure of an agent product page is that the reader
// cannot picture what actually happens. This page walks one request through
// eight steps, and every step answers two questions side by side: what
// actually happened, and what the human controls at that moment.
//
// Hard rules baked in here, each pinned by tool/verify_landing_demo.js:
//   1. `simulated` is rendered as a visible banner. A demo that looks like a
//      live system is a lie, and R27 says claims have to be checkable.
//   2. Progressive enhancement: with JS off, all eight steps are visible and
//      the player buttons are disabled. We never ship a control that looks
//      live and does nothing (R14).
//   3. Inline script only - no external resource of any kind (offline
//      self-sufficiency, checked across all of dist/ by verify_landing.js).

function demoScript(D) {
  const P = { prefix: D.progressLabel || '', suffix: D.progressSuffix || '', pause: D.pauseLabel || 'Pause' };
  const cfg = JSON.stringify(P);
  return `<script>
(function () {
  var C = ${cfg};
  var flow = document.getElementById('demo-flow');
  if (!flow) return;
  var steps = Array.prototype.slice.call(flow.querySelectorAll('.demo-step'));
  var dots = Array.prototype.slice.call(document.querySelectorAll('.demo-dot'));
  var label = document.getElementById('demo-progress');
  var play = document.getElementById('demo-play');
  var next = document.getElementById('demo-next');
  var reset = document.getElementById('demo-reset');
  var total = steps.length;
  var cur = 0;
  var timer = null;

  flow.classList.add('js');

  function render() {
    for (var i = 0; i < total; i++) {
      var on = i === cur, done = i < cur;
      steps[i].classList.toggle('is-on', on);
      steps[i].classList.toggle('is-done', done);
      steps[i].setAttribute('aria-hidden', on || done ? 'false' : 'true');
      if (dots[i]) {
        dots[i].classList.toggle('is-on', on);
        dots[i].classList.toggle('is-done', done);
      }
    }
    if (label) label.textContent = C.prefix + (cur + 1) + ' / ' + total + C.suffix;
    var atEnd = cur >= total - 1;
    if (next) { next.disabled = atEnd; }
    // Every control ships disabled in the HTML (no-JS honesty); once the
    // script is running, all of them must come alive - a Reset that stays
    // grey is exactly the dead control R14 forbids.
    if (play) { play.disabled = false; }
    if (reset) { reset.disabled = false; }
    if (play) {
      // At the end the interval is about to be cleared; show the play label
      // immediately instead of leaving "Pause" up for one more tick.
      play.textContent = (timer && !atEnd) ? C.pause : play.getAttribute('data-play');
    }
  }

  function stop() {
    if (timer) { window.clearInterval(timer); timer = null; }
  }

  function advance() {
    if (cur < total - 1) { cur = cur + 1; render(); } else { stop(); render(); }
  }

  if (next) next.addEventListener('click', function () { stop(); advance(); });
  if (reset) reset.addEventListener('click', function () { stop(); cur = 0; render(); });
  if (play) play.addEventListener('click', function () {
    if (timer) { stop(); render(); return; }
    if (cur >= total - 1) cur = 0;
    play.textContent = C.pause;
    render();
    timer = window.setInterval(function () {
      if (cur >= total - 1) { stop(); render(); } else { advance(); }
    }, 2400);
  });

  render();
})();
</script>`;
}

// 0.111.0: walkthrough video block for the demo page. The player renders only
// when a video is packaged AND its manifest language matches this page's
// language - the zh page keeps an honest "in production" notice until a
// Chinese walkthrough is actually recorded, never an English player with a
// Chinese caption bolted on.
function fmtDuration(sec) {
  const s = Math.round(Number(sec) || 0);
  const m = Math.floor(s / 60);
  return m + ':' + String(s % 60).padStart(2, '0');
}

function demoVideoSection(D, zh) {
  const V = videoTruth();
  const vd = D.video || {};
  const forThisLang = V && (V.lang === 'zh') === Boolean(zh);
  if (!forThisLang) {
    return `  <section class="block" id="video">
    <div class="wrap">
      <p class="eyebrow">${esc(vd.eyebrow || 'Video')}</p>
      <h2>${esc(vd.pendingTitle || '')}</h2>
      <p class="demo-video-lede">${esc(vd.pendingLede || '')}</p>
      <p class="demo-note">${esc(vd.note || '')}</p>
    </div>
  </section>`;
  }
  const src = '/video/' + V.file;
  const poster = '/video/' + V.poster;
  const mb = (V.bytes / (1024 * 1024)).toFixed(1) + ' MB';
  return `  <section class="block alt" id="video">
    <div class="wrap">
      <p class="eyebrow">${esc(vd.eyebrow || '')}</p>
      <h2>${esc(vd.title || '')}</h2>
      <p class="demo-video-lede">${esc(vd.lede || '')}</p>
      <div class="demo-video-frame">
        <video class="demo-video" controls preload="none" playsinline poster="${esc(poster)}" aria-label="${esc(vd.ariaLabel || '')}">
          <source src="${esc(src)}" type="video/mp4">
          ${esc(vd.fallback || '')} <a href="${esc(src)}">${esc(vd.downloadLabel || '')}</a>
        </video>
      </div>
      <p class="demo-video-meta">MP4 &middot; ${esc(mb)} &middot; ${esc(fmtDuration(V.durationSeconds))} &middot; <a href="${esc(src)}" download>${esc(vd.downloadLabel || '')}</a></p>
      <p class="demo-note">${esc(vd.note || '')}</p>
    </div>
  </section>`;
}

function demoHtml(lang = 'en') {
  const zh = lang === 'zh';
  const D = zh ? demoZh : demo;
  const total = D.steps.length;

  const stepItems = D.steps
    .map(
      (s, i) => `        <li class="demo-step" data-i="${i}">
          <div class="demo-step-head">
            <span class="demo-step-no">${esc(s.no)}</span>
            <h2>${esc(s.title)}</h2>
          </div>
          <div class="demo-cols">
            <div class="demo-col demo-happened">
              <p class="demo-col-label">${esc(D.happenedLabel)}</p>
              <p class="demo-col-body">${esc(s.happened)}</p>
            </div>
            <div class="demo-col demo-control">
              <p class="demo-col-label">${esc(D.controlLabel)}</p>
              <p class="demo-col-body">${esc(s.control)}</p>
            </div>
          </div>
        </li>`
    )
    .join('\n');

  const dotItems = D.steps
    .map((s) => `        <li class="demo-dot"><span>${esc(s.no)}</span></li>`)
    .join('\n');

  const checkItems = D.checks
    .map(
      (c) => `        <div class="check-item">
          <h3 class="check-q">${esc(c.q)}</h3>
          <p class="check-a">${esc(c.a)}</p>
        </div>`
    )
    .join('\n');

  const body = `  <section class="hero slim">
    <div class="wrap">
      <p class="eyebrow">${esc(D.eyebrow)}</p>
      <h1>${esc(D.h1)}</h1>
      <p class="hero-sub">${esc(D.lede)}</p>
      <p class="demo-banner" id="demo-banner">${esc(D.notice)}</p>
    </div>
  </section>
${demoVideoSection(D, zh)}

  <section class="block" id="intent">
    <div class="wrap">
      <p class="eyebrow">${esc(D.intentLabel)}</p>
      <blockquote class="demo-intent">${esc(D.intent)}</blockquote>
    </div>
  </section>

  <section class="block alt" id="run">
    <div class="wrap">
      <div class="demo-bar">
        <button class="btn btn-primary" type="button" id="demo-play" data-play="${esc(D.playLabel)}" disabled>${esc(D.playLabel)}</button>
        <button class="btn btn-ghost" type="button" id="demo-next" disabled>${esc(D.nextLabel)}</button>
        <button class="btn btn-ghost" type="button" id="demo-reset" disabled>${esc(D.resetLabel)}</button>
        <span class="demo-progress" id="demo-progress" aria-live="polite">${esc(D.progressLabel)}${esc('1')} / ${esc(String(total))}${esc(D.progressSuffix)}</span>
      </div>
      <ol class="demo-dots" aria-hidden="true">
${dotItems}
      </ol>
      <ol class="demo-flow" id="demo-flow">
${stepItems}
      </ol>
    </div>
  </section>

  <section class="block" id="check">
    <div class="wrap">
      <p class="eyebrow">${esc(D.checkEyebrow)}</p>
      <h2>${esc(D.checkTitle)}</h2>
      <div class="check-grid">
${checkItems}
      </div>
    </div>
  </section>

  <section class="block alt" id="next">
    <div class="wrap">
      <div class="actions">
        <a class="btn btn-ghost" href="${esc(D.ctaHref)}">${esc(D.ctaLabel)}</a>
      </div>
    </div>
  </section>
${demoScript(D)}`;

  const canonical = DOMAIN + (zh ? '/zh/demo/' : '/demo/');
  const ld = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: D.title,
    description: D.lede,
    url: canonical,
    isPartOf: { '@type': 'WebSite', name: site.brand.platform, url: DOMAIN + '/' },
  };
  return page({
    title: `${D.title} - ${site.brand.app}`,
    description: D.lede,
    canonical,
    body,
    ld,
    lang: zh ? 'zh-CN' : 'en',
    alternates: [{ hreflang: zh ? 'en' : 'zh', href: DOMAIN + (zh ? '/demo/' : '/zh/demo/') }],
  });
}

// -------------------------------------------------------- security page ---
// 0.104.0 / 整改方案阶段 E.
//
// The auditor's point was that a product asking for this much trust needs a
// page that explains the mechanism, not adjectives. So: four groups of
// statements, each naming the file that implements it, plus an explicit
// "what this page is not" block (no audit, no certification, not finished).
//
// Pinned by tool/verify_landing_security.js:
//   1. every `proof` keyword must really exist in the named file;
//   2. the two languages must stay structurally identical;
//   3. the nav entry must point at a file that actually exists.

function securityHtml(lang = 'en') {
  const zh = lang === 'zh';
  const S = zh ? securityZh : security;

  const groups = S.groups
    .map(
      (g) => `    <div class="sec-group">
      <h2 class="sec-group-title">${esc(g.title)}</h2>
      <div class="sec-items">
${g.items
  .map(
    (it) => `        <div class="sec-item">
          <h3 class="sec-item-title">${esc(it.title)}</h3>
          <p class="sec-item-body">${esc(it.body)}</p>${it.proof ? '\n          <p class="sec-proof"><code>' + esc(it.proof) + '</code></p>' : ''}
        </div>`
  )
  .join('\n')}
      </div>
    </div>`
    )
    .join('\n');

  const boundary = S.boundary.map((b) => `        <li>${esc(b)}</li>`).join('\n');

  const body = `  <section class="hero slim">
    <div class="wrap">
      <p class="eyebrow">${esc(S.eyebrow)}</p>
      <h1>${esc(S.h1)}</h1>
      <p class="hero-sub">${esc(S.lede)}</p>
      <p class="demo-banner" id="security-notice">${esc(S.notice)}</p>
    </div>
  </section>

  <section class="block" id="mechanisms">
    <div class="wrap">
${groups}
      <p class="sec-proof-note">${esc(S.proofNote)}</p>
    </div>
  </section>

  <section class="block alt" id="boundary">
    <div class="wrap">
      <h2 class="sec-group-title">${esc(S.boundaryTitle)}</h2>
      <ul class="points">
${boundary}
      </ul>
      <div class="actions">
        <a class="btn btn-ghost" href="${esc(S.ctaHref)}">${esc(S.ctaLabel)}</a>
      </div>
    </div>
  </section>`;

  const canonical = DOMAIN + (zh ? '/zh/security/' : '/security/');
  const ld = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: S.title,
    description: S.lede,
    url: canonical,
    isPartOf: { '@type': 'WebSite', name: site.brand.platform, url: DOMAIN + '/' },
  };
  return page({
    title: `${S.title} - ${site.brand.app}`,
    description: S.lede,
    canonical,
    body,
    ld,
    lang: zh ? 'zh-CN' : 'en',
    alternates: [{ hreflang: zh ? 'en' : 'zh', href: DOMAIN + (zh ? '/security/' : '/zh/security/') }],
  });
}

// ------------------------------------------------------------ city  page ---

function cityHtml(c, lang = 'en') {
  const zh = lang === 'zh';
  const Z = zh && c.zh ? c.zh : null;
  const name = Z ? Z.name : c.name;
  const blurb = Z ? Z.blurb : c.blurb;
  const arc = Z ? Z.arc : c.arc;
  const title = zh
    ? `刚落地${name}？- ${site.brand.app}`
    : `Just landed in ${c.name}? - ${site.brand.app}`;
  const desc = blurb;
  const canonical = zh ? `${DOMAIN}/zh/${c.slug}/` : `${DOMAIN}/${c.slug}/`;
  const h1 = zh ? `刚落地${name}？` : `Just landed in ${c.name}?`;

  const body = `  <section class="city-hero" style="--city-img:url(${esc(c.image)})">
    <div class="wrap">
      <p class="breadcrumb"><a href="/${zh ? 'zh/' : ''}">${esc(site.brand.platform)}</a> &middot; ${esc(Z && Z.country ? Z.country : c.country)}</p>
      <h1>${esc(h1)}</h1>
      <p>${esc(blurb)}</p>
      <div class="actions">
        ${primaryCta(Z ? siteZh : site)}
        ${secondaryCta(Z ? siteZh : site)}
      </div>
    </div>
  </section>

  <section class="block" id="first-month">
    <div class="wrap">
      <p class="eyebrow">${zh ? '第一个月' : 'The first month'}</p>
      <h2>${zh ? `刚落地${name}，这座城实际是什么样` : `What ${esc(c.name)} is actually like when you have just arrived`}</h2>
      <p class="body">${esc(arc[0])}</p>
    </div>
  </section>

  <section class="block alt" id="going-first">
    <div class="wrap">
      <p class="eyebrow">${zh ? '「先出去」意味着什么' : 'What going first means here'}</p>
      <h2>${zh ? '你的代表先被介绍，你之后出场' : 'Your representative is introduced before you are'}</h2>
      <p class="body">${esc(arc[1])}</p>
      <ul class="points">
        <li>${zh ? '数据留在你的设备上，钥匙归你所有' : 'Your data stays on your device; your keys stay yours'}</li>
        <li>${zh ? '观察模式、完整审计轨迹与撤销' : 'Watch-only mode, a full audit trail, and undo'}</li>
        <li>${zh ? '公开的只追加日志：可以核验，不必信任' : 'A public append-only log, so you can check rather than trust'}</li>
      </ul>
    </div>
  </section>

  <section class="block" id="other-cities">
    <div class="wrap">
      <p class="eyebrow">${zh ? '也覆盖这些城市' : 'Also covered'}</p>
      <h2>${zh ? '其他城市' : 'Other cities'}</h2>
      <div class="city-grid">
${cities
  .filter((o) => o.slug !== c.slug)
  .slice(0, 6)
  .map(
    (o) => `        <a class="city-card has-media" href="/${zh ? 'zh/' : ''}${esc(o.slug)}/">
          <div class="city-media"><img src="${esc(o.image)}" alt="${esc(o.name)}" loading="lazy" width="700" height="467"></div>
          <div class="city-body">
            <div class="city-name">${esc(zh && o.zh ? o.zh.name : o.name)}</div>
            <div class="city-country">${esc(zh && o.zh && o.zh.country ? o.zh.country : o.country)}</div>
          </div>
        </a>`
  )
  .join('\n')}
      </div>
    </div>
  </section>`;

  const ld = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: title,
    description: desc,
    url: canonical,
    inLanguage: zh ? 'zh-CN' : 'en',
    breadcrumb: {
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: site.brand.platform, item: DOMAIN + '/' },
        { '@type': 'ListItem', position: 2, name: name, item: canonical },
      ],
    },
    isPartOf: { '@type': 'WebSite', name: site.brand.platform, url: DOMAIN + '/' },
  };

  return page({
    title,
    description: desc,
    canonical,
    body,
    ld,
    lang: zh ? 'zh-CN' : 'en',
    // ★ 0.95.0 修复：此前两种情况都指向自身（`/zh/x/` → `/zh/x/`），alternate 完全失效。
    alternates: [{ hreflang: zh ? 'en' : 'zh', href: zh ? `${DOMAIN}/${c.slug}/` : `${DOMAIN}/zh/${c.slug}/` }],
  });
}

// --------------------------------------------------------- markdown ------
//
// Minimal Markdown -> HTML, zero dependencies like the rest of this file.
// It supports exactly the constructs the compliance drafts use (headings,
// bold, inline code, links, GFM tables, blockquotes, ordered/unordered lists,
// rules, paragraphs). Anything unrecognised falls through as an escaped
// paragraph rather than being silently dropped - a dropped clause in a privacy
// policy is worse than an ugly one.

/** Inline Markdown. Escapes first, so no source text can inject markup. */
function mdInline(s) {
  let t = esc(s);
  // A link to another internal .md cannot be published on the website - keep
  // the visible words, drop the href that would 404.
  t = t.replace(
    /\[([^\]]+)\]\(([^)\s]+)\)/g,
    (m, txt, href) => (/\.md$/i.test(href) ? txt : `<a href="${/^(https?:\/\/|mailto:|\/)/.test(href) ? href : '#'}">${txt}</a>`)
  );
  t = t.replace(/`([^`]+)`/g, '<code>$1</code>');
  t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  return t;
}

function mdToHtml(md) {
  const lines = md.replace(/\r\n/g, '\n').split('\n');
  const out = [];
  let list = null;
  let i = 0;

  const closeList = () => {
    if (list) {
      out.push('</' + list + '>');
      list = null;
    }
  };
  const isRow = (l) => /^\s*\|.*\|\s*$/.test(l);
  const cells = (l) =>
    l.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());
  // A GFM separator row is `|---|:--:|`. Checking it cell-by-cell is the only
  // reliable form: a single regex over the whole row cannot work, because the
  // character class can never cross the `|` that separates the columns.
  const isSep = (l) => {
    if (!isRow(l)) return false;
    const cs = cells(l);
    return cs.length >= 1 && cs.every((c) => /^:?-+:?$/.test(c));
  };
  const isBlockStart = (l) =>
    !l ||
    isRow(l) ||
    /^(#{1,6}\s|>|[-*+]\s|\d+\.\s)/.test(l) ||
    /^(-{3,}|\*{3,}|_{3,})$/.test(l);

  while (i < lines.length) {
    const raw = lines[i];
    const line = raw.trim();

    if (!line) {
      closeList();
      i++;
      continue;
    }

    // GFM table: a header row followed by a separator row.
    if (isRow(raw) && i + 1 < lines.length && isSep(lines[i + 1])) {
      closeList();
      const head = cells(raw);
      i += 2;
      const rows = [];
      while (i < lines.length && isRow(lines[i])) {
        rows.push(cells(lines[i]));
        i++;
      }
      out.push(
        '<div class="md-table"><table><thead><tr>' +
          head.map((c) => '<th>' + mdInline(c) + '</th>').join('') +
          '</tr></thead><tbody>' +
          rows
            .map(
              (r) =>
                '<tr>' +
                head.map((_, k) => '<td>' + mdInline(r[k] || '') + '</td>').join('') +
                '</tr>'
            )
            .join('') +
          '</tbody></table></div>'
      );
      continue;
    }

    if (/^(-{3,}|\*{3,}|_{3,})$/.test(line)) {
      closeList();
      out.push('<hr>');
      i++;
      continue;
    }

    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) {
      closeList();
      out.push(`<h${h[1].length}>${mdInline(h[2])}</h${h[1].length}>`);
      i++;
      continue;
    }

    if (line.startsWith('>')) {
      closeList();
      const buf = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        buf.push(lines[i].trim().replace(/^>\s?/, ''));
        i++;
      }
      out.push(
        '<blockquote>' +
          buf
            .filter(Boolean)
            .map((p) => '<p>' + mdInline(p) + '</p>')
            .join('') +
          '</blockquote>'
      );
      continue;
    }

    const li = line.match(/^([-*+]|\d+\.)\s+(.*)$/);
    if (li) {
      const want = /^\d+\.$/.test(li[1]) ? 'ol' : 'ul';
      if (list !== want) {
        closeList();
        out.push('<' + want + '>');
        list = want;
      }
      out.push('<li>' + mdInline(li[2]) + '</li>');
      i++;
      continue;
    }

    closeList();
    const buf = [line];
    i++;
    while (i < lines.length && !isBlockStart(lines[i].trim())) {
      buf.push(lines[i].trim());
      i++;
    }
    out.push('<p>' + mdInline(buf.join(' ')) + '</p>');
  }

  closeList();
  return out.join('\n');
}

// ------------------------------------------------------- legal pages ------
//
// /privacy/ and /terms/ are store-submission prerequisites; each needs a
// reachable URL, and both are generated from the compliance drafts in
// `lib/compliance/` so the published text has ONE source of truth instead of a
// second copy that drifts. The two drafts share their shape - an
// engineering-draft banner at the top, a "给复核者的备注（发布前删除）" block at
// the bottom, and an H1 that calls itself a draft - so the stripping is a
// single implementation here, not two that can quietly disagree.

/**
 * Turn one compliance draft into publishable HTML.
 *
 * Three things are deliberately removed, and the renderer refuses to run if any
 * expected shape is missing - a silently changed draft must not turn into a
 * silently different published document:
 *   - the engineering-draft banner,
 *   - the "给复核者的备注（发布前删除）" tail,
 *   - the "（草稿）" wording in the H1.
 * All are internal process notes. Publishing them is the same class of mistake
 * as shipping an unfilled placeholder: the reader learns about our workflow
 * instead of about the document.
 *
 * The markers are matched STRUCTURALLY - the banner is "the blockquote that
 * opens with the marker", the note is "the closing blockquote" - so routine
 * wording edits inside them do not force a code change, while deleting them
 * outright fails the build, because that means the draft's own assumptions
 * moved and a human should look.
 *
 * @param {string} relPath  draft path relative to the repo root
 * @param {object} o
 * @param {string} o.label      short name used in error messages ("privacy"/"terms"/"privacy:en")
 * @param {RegExp} o.bannerRe   matches the draft's engineering-draft banner
 * @param {RegExp} o.noteRe     matches the draft's reviewer-note block
 * @param {RegExp} o.h1Re       matches the draft H1 (must be `m`-anchored)
 * @param {string} o.h1To       the published H1
 * @param {Array<[string,string]>} o.subs  placeholder -> value, in order
 */
function renderLegalDoc(relPath, { label, bannerRe, noteRe, h1Re, h1To, subs, loc }) {
  const lines = fs.readFileSync(path.resolve(REPO, relPath), 'utf8').replace(/\r\n/g, '\n').split('\n');

  const bannerAt = lines.findIndex((l) => bannerRe.test(l));
  if (bannerAt < 0) throw new Error(label + ' source lost its draft banner - refusing to publish it verbatim');
  let bannerEnd = bannerAt;
  while (bannerEnd + 1 < lines.length && lines[bannerEnd + 1].trim().startsWith('>')) bannerEnd++;

  const noteAt = lines.findIndex((l) => noteRe.test(l));
  if (noteAt < 0 || noteAt <= bannerEnd) {
    throw new Error(label + ' source lost its reviewer-note marker - refusing to publish it verbatim');
  }

  let doc = lines.slice(0, bannerAt).concat(lines.slice(bannerEnd + 1, noteAt)).join('\n');

  // A published document must not call itself a draft.
  if (!h1Re.test(doc)) throw new Error(label + ' source h1 changed shape - refusing to publish it verbatim');
  doc = doc.replace(h1Re, h1To);

  // Placeholders -> values from site.legal (presence already enforced above).
  // The backticked spellings come FIRST on purpose: the drafts wrap the
  // placeholders in `code`, so replacing the bare form first would leave the
  // backticks behind and render a real value as monospace.
  for (const [k, v] of subs) doc = doc.split(k).join(v);

  // Cross-references last, after the placeholders: their targets are URLs, and
  // a URL must not go through the placeholder substitution.
  doc = rewriteDocLinks(doc, loc);

  const html = mdToHtml(doc);

  // Belt and braces: nothing that still looks like a placeholder may ship.
  const leftover = [...html.matchAll(/\[[^\]\n]{1,24}\]/g)].map((m) => m[0]);
  if (leftover.length) {
    throw new Error(label + ' page still contains placeholders: ' + leftover.join(' '));
  }
  return html;
}

// -------------------------------------------------------- legal locales ------
//
// Which languages exist, and the per-language shape of a draft. Kept in code
// rather than JSON because the draft markers are regexes - and because the
// cross-end guard (tool/verify_legal_links.dart) reads this file as text.

/**
 * Must mirror `l10n.yaml` `supported-locales` (en / zh / zh_Hant / ja / vi):
 * the App ships in five languages, and a policy a reader cannot read is a
 * policy they cannot consent to.
 *
 * SIMPLIFIED CHINESE IS THE ORIGINAL, and it keeps the two canonical URLs -
 * `/privacy/` and `/terms/` - that the App opens and a store submission
 * requires. Every other language lives in a sibling directory
 * (`/privacy/en/`, ...) and is a REFERENCE TRANSLATION: the page says so, in
 * the reader's own language, and points at the Chinese original as the text
 * that prevails. That notice is the reason these pages are publishable at all -
 * without it a translation nobody has reviewed would read as if it were the
 * authoritative text.
 *
 *   seg    URL directory segment. Lower case on purpose: URLs are case
 *          sensitive and the build host is not, so the case is fixed once, here.
 *   lang   BCP-47 tag: <html lang>, JSON-LD inLanguage, and draft file suffix.
 *   hl     hreflang value in the alternates block.
 *   label  endonym shown in the page-level language switcher.
 *   banner / note   opening text of the draft banner / reviewer note in this
 *          language; `renderLegalDoc` refuses to publish when either is gone.
 *   h1 / desc       published H1 and meta description, per document kind.
 */
const LEGAL_LOCALES = [
  {
    seg: '', lang: 'zh-CN', hl: 'zh-Hans', label: '简体中文', def: true, switchLabel: '语言',
    banner: '**本文为工程侧草稿', note: '**给复核者的备注',
    h1: { privacy: '隐私政策', terms: '服务条款', age: '年龄门槛' },
    desc: {
      privacy: `${site.brand.app} 隐私政策：我们收集什么、存在哪里、如何删除。`,
      terms: `${site.brand.app} 服务条款：你的密钥与身份、可接受使用，以及维持平台可用的规则。`,
      age: `${site.brand.app} 年龄门槛：最低年龄、地区差异，以及我们不向未成年人开放什么。`,
    },
  },
  {
    seg: 'en', lang: 'en', hl: 'en', label: 'English', switchLabel: 'Language',
    banner: '**This is an engineering-side draft', note: '**Reviewer notes',
    h1: { privacy: 'Privacy Policy', terms: 'Terms of Service', age: 'Age requirements' },
    desc: {
      privacy: `${site.brand.app} privacy policy: what is collected, where it is stored, and how to have it removed.`,
      terms: `${site.brand.app} terms of service: your keys, your identity, acceptable use, and the rules that keep the platform usable.`,
      age: `${site.brand.app} age requirements: the minimum age, how it differs by region, and what we do not offer to minors.`,
    },
  },
  {
    seg: 'zh-hant', lang: 'zh-Hant', hl: 'zh-Hant', label: '繁體中文', switchLabel: '語言',
    banner: '**本文為工程側草稿', note: '**給複核者的備註',
    h1: { privacy: '隱私政策', terms: '服務條款', age: '年齡門檻' },
    desc: {
      privacy: `${site.brand.app} 隱私政策：我們收集什麼、存在哪裡、如何刪除。`,
      terms: `${site.brand.app} 服務條款：你的金鑰與身分、可接受使用，以及維持平台可用的規則。`,
      age: `${site.brand.app} 年齡門檻：最低年齡、地區差異，以及我們不向未成年人開放什麼。`,
    },
  },
  {
    seg: 'ja', lang: 'ja', hl: 'ja', label: '日本語', switchLabel: '言語',
    banner: '**本文はエンジニアリング側のドラフト', note: '**レビュアー向けメモ',
    h1: { privacy: 'プライバシーポリシー', terms: '利用規約', age: '年齢要件' },
    desc: {
      privacy: `${site.brand.app} のプライバシーポリシー：収集する情報、保管場所、削除の方法。`,
      terms: `${site.brand.app} の利用規約：鍵と身元、禁止される行為、プラットフォームを維持するためのルール。`,
      age: `${site.brand.app} の年齢要件：最低年齢、地域による違い、未成年者に開放しないもの。`,
    },
  },
  {
    seg: 'vi', lang: 'vi', hl: 'vi', label: 'Tiếng Việt', switchLabel: 'Ngôn ngữ',
    banner: '**Đây là bản nháp do bộ phận kỹ thuật soạn', note: '**Ghi chú cho người rà soát',
    h1: { privacy: 'Chính sách quyền riêng tư', terms: 'Điều khoản dịch vụ', age: 'Yêu cầu về độ tuổi' },
    desc: {
      privacy: `Chính sách quyền riêng tư của ${site.brand.app}: thu thập những gì, lưu ở đâu và cách xoá.`,
      terms: `Điều khoản dịch vụ của ${site.brand.app}: khoá và danh tính của bạn, hành vi bị cấm và các quy tắc giữ nền tảng hoạt động được.`,
      age: `Yêu cầu về độ tuổi của ${site.brand.app}: độ tuổi tối thiểu, khác biệt theo khu vực và những gì chúng tôi không mở cho người chưa thành niên.`,
    },
  },
];

/**
 * The three published compliance documents. `file` is the Chinese filename the
 * drafts use when they point at each other; `url` is where each is published.
 *
 * AGE REQUIREMENTS is the third document here. The privacy policy and the
 * terms both mentioned it for a long time while no page existed behind the
 * mention - the renderer kept the words and dropped the href, so the reader
 * read "see the age requirements" and had nowhere to click. Publishing it is
 * what turns those mentions into links; being reachable is the whole point.
 * (The version it ships in is stamped in CHANGELOG at release, not here: a
 * version number in a comment would outrun the release it belongs to.)
 */
const LEGAL_KINDS = ['privacy', 'terms', 'age'];
const LEGAL_DOCS = {
  privacy: { file: '隐私政策.md', url: '/privacy/' },
  terms: { file: '服务条款.md', url: '/terms/' },
  age: { file: '年龄门槛.md', url: '/age/' },
};

/**
 * The block that makes an unreviewed translation safe to publish: it states, in
 * the reader's language, that this is a translation and that the Chinese
 * original prevails. Injected here rather than authored per draft, so it cannot
 * be forgotten and cannot drift between documents.
 */
const LEGAL_NOTICE = {
  en: (k) =>
    `      <p class="lang-note"><strong>Reference translation.</strong> This page is a translation of the Chinese original. In case of any discrepancy, the Chinese original at <a href="/${k}/">/${k}/</a> prevails.</p>`,
  'zh-Hant': (k) =>
    `      <p class="lang-note"><strong>參考譯文。</strong>本頁為簡體中文原文之譯本；如遇歧異，以 <a href="/${k}/">/${k}/</a> 之簡體中文原文為準。</p>`,
  ja: (k) =>
    `      <p class="lang-note"><strong>参考訳です。</strong>本ページは中国語原文の翻訳です。相違がある場合は、<a href="/${k}/">/${k}/</a> の中国語原文が優先します。</p>`,
  vi: (k) =>
    `      <p class="lang-note"><strong>Bản dịch tham khảo.</strong> Trang này là bản dịch của nguyên bản tiếng Trung. Nếu có khác biệt, nguyên bản tiếng Trung tại <a href="/${k}/">/${k}/</a> sẽ được ưu tiên áp dụng.</p>`,
};

/** Escape a literal for use inside a RegExp. */
function reEsc(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** `lib/compliance/隐私政策.md` -> `lib/compliance/隐私政策.en.md` for a locale. */
function legalSource(kind, loc) {
  const base = LEGAL_DOCS[kind].file;
  if (loc.def) return 'lib/compliance/' + base;
  return 'lib/compliance/' + base.replace(/\.md$/, '.' + loc.lang + '.md');
}

/** `/privacy/` for the default locale, `/privacy/en/` for every other one. */
function legalUrlFor(kind, loc) {
  return LEGAL_DOCS[kind].url + (loc.def ? '' : loc.seg + '/');
}

/**
 * Internal cross-references -> published URLs, in the READER's language.
 *
 * The drafts point at each other by filename (`[`年龄门槛.md`](年龄门槛.md)`),
 * because a filename is what stays stable before the page exists. Once the
 * pages do exist those filenames have to become URLs, or the reader reads
 * "see the age requirements" and there is nothing to click.
 *
 * Both halves of the link are rewritten: the href becomes the URL, and a link
 * whose TEXT is just the source filename becomes that document's published
 * title in this language - a reader should never be shown "隐私政策.md".
 *
 * A suffix we do not ship (.fr, say) throws. A reference to a language we do
 * not publish must fail the build, not quietly fall back to the Chinese page.
 */
// A regex LITERAL, not a string handed to `new RegExp`: in a JS string literal
// `\[` is not an escape sequence at all and silently collapses to `[`, which
// turns the pattern into something that matches the wrong thing rather than
// failing. Literals keep the backslashes where they were written.
const DOC_LINK_RE = /\[(`?)([^`\]]{1,60})\1\]\((隐私政策|服务条款|年龄门槛)(\.[A-Za-z-]+)?\.md\)/g;
const DOC_LINK_KIND = { '隐私政策': 'privacy', '服务条款': 'terms', '年龄门槛': 'age' };

function rewriteDocLinks(doc, loc) {
  return doc.replace(DOC_LINK_RE, (m, _tick, text, base, suffix) => {
    const kind = DOC_LINK_KIND[base];
    const target = suffix ? LEGAL_LOCALES.find((l) => l.lang === suffix.slice(1)) : loc;
    if (!kind) throw new Error('legal cross-reference names an unknown document: ' + base);
    if (!target) throw new Error('legal cross-reference names an unknown locale: ' + suffix);
    // A link whose text is only the source filename becomes that document's
    // published title in this language - nobody should be shown "隐私政策.md".
    const label = /\.md$/.test(text) ? target.h1[kind] : text;
    return '[' + label + '](' + legalUrlFor(kind, target) + ')';
  });
}

/**
 * Placeholder -> value, per document kind. The backticked spellings come FIRST
 * on purpose: the drafts wrap the placeholders in `code`, so replacing the bare
 * form first would leave the backticks behind and render a real value as
 * monospace. The values themselves are the jurisdiction-specific facts from
 * site.legal and stay in the original wording on every language: translating
 * "中华人民共和国法律" is translating a term of art, and the notice says the
 * Chinese original prevails - so the honest thing is to quote it verbatim.
 */
function legalSubs(kind, legal) {
  const date = ['`[生效日期]`', legal.effectiveDate];
  const dateBare = ['[生效日期]', legal.effectiveDate];
  // The age document's only `[法域]` sits in its draft banner, which is
  // stripped - so it carries no jurisdiction values. The date pairs stay so
  // the page picks up the effective date the moment one is added to it.
  if (kind === 'age') return [date, dateBare];
  if (kind === 'privacy') {
    return [
      date,
      ['`[数据存储位置]`', legal.dataLocation],
      ['`[跨境传输依据]`', legal.crossBorderBasis],
      dateBare,
      ['[数据存储位置]', legal.dataLocation],
      ['[跨境传输依据]', legal.crossBorderBasis],
          ];
  }
  return [
    date,
    ['`[法域]`', legal.applicableLaw],
    ['`[争议解决方式]`', legal.disputeResolution],
    dateBare,
    ['[法域]', legal.applicableLaw],
    ['[争议解决方式]', legal.disputeResolution],
      ];
}

/** All five locales plus x-default - the <link rel="alternate"> set. */
function legalAlternates(kind) {
  const base = DOMAIN + '/' + kind + '/';
  const out = LEGAL_LOCALES.map((l) => ({
    hreflang: l.hl,
    href: base + (l.seg ? l.seg + '/' : ''),
  }));
  out.push({ hreflang: 'x-default', href: base });
  return out;
}

/** Page-level language switcher. The current language renders as a non-link. */
function legalSwitcher(kind, cur) {
  const items = LEGAL_LOCALES.map((l) => {
    const href = '/' + kind + '/' + (l.seg ? l.seg + '/' : '');
    return l === cur
      ? `      <span class="lang-current" aria-current="page" lang="${esc(l.lang)}">${esc(l.label)}</span>`
      : `      <a href="${esc(href)}" hreflang="${esc(l.hl)}" lang="${esc(l.lang)}">${esc(l.label)}</a>`;
  }).join('\n');
  return `    <nav class="lang-switch" aria-label="${esc(cur.switchLabel)}">
      <span class="lang-switch-label">${esc(cur.switchLabel)}:</span>
${items}
    </nav>`;
}

/** One legal page (privacy or terms), in one language. */
function legalHtml(kind, loc) {
  const legal = site.legal;
  const html = renderLegalDoc(legalSource(kind, loc), {
    label: kind + (loc.def ? '' : ':' + loc.lang),
    // Structural and per language: the banner is "the blockquote that opens
    // with the marker", so wording edits inside it do not force a code change,
    // while deleting it fails the build.
    bannerRe: new RegExp('^>[ \\t]*⚠️ ' + reEsc(loc.banner)),
    noteRe: new RegExp('^>[ \\t]*' + reEsc(loc.note)),
    // The H1 must still call itself a draft - in whatever language - or the
    // draft's own assumptions moved and a human should look.
    h1Re: new RegExp(
      '^# ' + reEsc(loc.h1[kind]) + '\\s*[（(][^）)]*(?:草稿|Draft|ドラフト|Bản nháp)[^）)]*[）)]\\s*$',
      // 'i' because the draft wording is capitalised in English and Vietnamese
      // and not in Japanese or Chinese. Whether a page is publishable must not
      // depend on whether the translator held Shift.
      'mi'
    ),
    h1To: '# ' + loc.h1[kind],
    subs: legalSubs(kind, legal),
    loc,
  });

  const base = DOMAIN + '/' + kind + '/';
  const canonical = loc.def ? base : base + loc.seg + '/';
  const notice = loc.def ? '' : LEGAL_NOTICE[loc.lang](kind) + '\n';
  const title = `${loc.h1[kind]} - ${site.brand.app}`;
  const description = loc.desc[kind];

  const body = `  <section class="block" id="${kind}">
    <div class="wrap">
      <p class="breadcrumb"><a href="/">${esc(site.brand.platform)}</a> &middot; ${esc(loc.h1[kind])}</p>
${legalSwitcher(kind, loc)}
${notice}      <article class="doc">
${html}
      </article>
    </div>
  </section>`;

  const ld = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: title,
    description,
    url: canonical,
    inLanguage: loc.lang,
    isPartOf: { '@type': 'WebSite', name: site.brand.platform, url: DOMAIN + '/' },
  };

  return page({
    title,
    description,
    canonical,
    body,
    ld,
    lang: loc.lang,
    alternates: legalAlternates(kind),
  });
}

// ----------------------------------------------------------------- build ---

// ---------- portal pages (/docs, /faq, /changelog, llms.txt) ----------

function docsHtml(kb, lang = 'en') {
  const title = 'Docs — every feature, how it works';
  const description =
    'Complete user documentation for ' + site.brand.app + ': identity backup, social ' +
    'radar, world rooms, delegations, troubleshooting and more. Same source ' +
    'the in-app agent reads.';
  const toc = kb.entries
    .map((e) => '<a href="#' + esc(e.id) + '">' + esc(e.title) + '</a>')
    .join('');
  const sections = kb.entries
    .map(
      (e) =>
        '<section class="doc-entry" id="' + esc(e.id) + '">' +
        '<h2>' + esc(e.title) + '</h2><p>' + esc(e.steps) + '</p></section>'
    )
    .join('');
  const ld = {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name: site.brand.app + ' documentation',
    numberOfItems: kb.entries.length,
    itemListElement: kb.entries.map((e, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: e.title,
      url: DOMAIN + '/docs/#' + e.id,
    })),
  };
  return page({
    title,
    description,
    canonical: DOMAIN + '/docs/',
    body:
      '<section class="hero slim"><h1>' + esc(title) + '</h1>' +
      '<p class="hero-sub">' + esc(description) + '</p></section>' +
      '<nav class="kb-toc wrap" aria-label="Documentation topics">' + toc + '</nav>' +
      '<div class="wrap doc-body">' + sections + '</div>',
    ld, // 存量修复：此前传 jsonLd(ld) 字符串，docs 页 JSON-LD 一直是双重序列化的坏结构
    lang,
    alternates: [{ hreflang: lang === 'zh' ? 'en' : 'zh', href: DOMAIN + (lang === 'zh' ? '/docs/' : '/zh/docs/') }],
  });
}

function faqHtml(faq) {
  const title = 'Frequently asked questions';
  const description =
    'Straight answers about ' + site.brand.app + ': identity backup, free trial limits, ' +
    'channels, privacy and troubleshooting.';
  const body =
    '<section class="hero slim"><h1>' + esc(title) + '</h1>' +
    '<p class="hero-sub">' + esc(description) + '</p></section>' +
    '<div class="wrap faq-body">' +
    faq
      .map(
        (f) =>
          '<section class="faq-item" id="' + esc(f.id) + '"><h2>' + esc(f.q) + '</h2>' +
          '<p>' + esc(f.a) + '</p></section>'
      )
      .join('') +
    '</div>';
  const ld = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faq.map((f) => ({
      '@type': 'Question',
      name: f.q,
      acceptedAnswer: { '@type': 'Answer', text: f.a },
    })),
  };
  return page({ title, description, canonical: DOMAIN + '/faq/', body, ld });
}

// 0.115.0: the changelog page is paginated BY BYTES, not by entry count.
//
// Why: CHANGELOG.md is append-only and had reached 798 KB, so rendering all
// of it produced a 1,052,627 B page - over the 1 MB hard cap the perf/a11y
// audit enforces. That cap's own comment says it exists to "force a real
// pagination decision instead of letting the page quietly double every
// year", so raising the cap would silence the alarm instead of answering it.
//
// A byte budget (not a count of entries) is what makes the cap hold: one
// outsized entry can never blow a single page past the limit, and pages stay
// roughly the same size as the history keeps growing.
const CHANGELOG_PAGE_BUDGET = 400 * 1024; // 409,600 B - far below the 1 MB cap

/** Split CHANGELOG.md into pages of at most CHANGELOG_PAGE_BUDGET bytes. */
function changelogPages() {
  const md = fs.readFileSync(path.join(REPO, 'CHANGELOG.md'), 'utf8');
  const blocks = md
    .split(/^## /m)
    .filter((b) => b.trim())
    .map((b) => '## ' + b);
  const pages = [];
  let cur = [];
  let curBytes = 0;
  for (const b of blocks) {
    const n = Buffer.byteLength(b, 'utf8');
    if (cur.length && curBytes + n > CHANGELOG_PAGE_BUDGET) {
      pages.push(cur);
      cur = [];
      curBytes = 0;
    }
    cur.push(b);
    curBytes += n;
  }
  if (cur.length) pages.push(cur);
  return pages;
}

/** The URL of one changelog page. Page 1 keeps the landing URL; later pages are /pN/. */
function changelogUrl(lang, page) {
  const zh = String(lang).toLowerCase().indexOf('zh') === 0;
  const base = zh ? '/zh/changelog/' : '/changelog/';
  return page <= 1 ? base : base + 'p' + page + '/';
}

function changelogHtml(lang = 'en', pg = 1) {
  const zh = String(lang).toLowerCase().indexOf('zh') === 0;
  const title = zh ? '更新日志 —— 每一次发布，都公开' : 'Changelog — every release, in the open';
  const description = zh
    ? '大荒AI 的完整发布历史，逐版本记录，随发布同步公开。'
    : 'The complete release history of ' + site.brand.app + ', version by version, ' +
      'published as it ships.';
  const all = changelogPages();
  const pageNo = Math.min(Math.max(1, pg), all.length);
  const blocks = all[pageNo - 1] || [];
  // The page's only <h1> is the hero title. CHANGELOG.md once carried a stray
  // "# Changelog" line left over from merging two changelog files (at the
  // 0.29.0 boundary); it rendered as a SECOND h1 and broke the a11y audit.
  // The line is deleted at the source, and demoted here as a structural
  // fallback: no future "# " line may ever add a second h1 to this page.
  // ---- 翻页导航：分页不能把「完整历史」藏起来 ----
  const total = all.length;
  let nav = '';
  if (total > 1) {
    const prevNo = pageNo - 1;
    const nextNo = pageNo + 1;
    const link = (no, label) =>
      '<a class="cl-page-link" href="' + esc(DOMAIN + changelogUrl(lang, no)) + '">' + esc(label) + '</a>';
    const newer = prevNo >= 1
      ? link(prevNo, zh ? '← 较新' : '← Newer')
      : '<span class="cl-page-link is-disabled">' + (zh ? '← 较新' : '← Newer') + '</span>';
    const older = nextNo <= total
      ? link(nextNo, zh ? '较旧 →' : 'Older →')
      : '<span class="cl-page-link is-disabled">' + (zh ? '较旧 →' : 'Older →') + '</span>';
    const counter = zh ? '第 ' + pageNo + ' / ' + total + ' 页' : 'Page ' + pageNo + ' of ' + total;
    nav =
      '<nav class="cl-pages" aria-label="' + (zh ? '更新日志分页' : 'Changelog pages') + '">' +
      newer +
      '<span class="cl-page-counter">' + esc(counter) + '</span>' +
      older +
      '</nav>';
  }
  const body =
    '<section class="hero slim"><h1>' + esc(title) + '</h1>' +
    '<p class="hero-sub">' + esc(description) + '</p></section>' +
    nav +
    '<div class="wrap log-body">' +
    blocks
      .map(
        (b) =>
          '<section class="log-item">' +
          mdToHtml(b)
            .replace('<h2>', '<h2 class="log-ver">')
            .replace(/<h1>/g, '<h2>')
            .replace(/<\/h1>/g, '</h2>') +
          '</section>'
      )
      .join('') +
    '</div>';
  const ld = {
    '@context': 'https://schema.org',
    '@type': 'CollectionPage',
    name: zh ? '大荒AI 更新日志' : site.brand.app + ' changelog',
    url: DOMAIN + changelogUrl(lang, pageNo),
  };
  const selfUrl = DOMAIN + changelogUrl(lang, pageNo);
  return page({
    title,
    description,
    canonical: selfUrl,
    body,
    ld, // 存量修复：同 docs，传对象而非 jsonLd() 后的字符串
    lang: zh ? 'zh-CN' : 'en',
    // ★ hreflang 指向**对侧语言的同页码**：归档页的 alternate 必须也落在
    //   归档页上（指向首页等于宣称「这两页是同一内容」——那是错的）。
    alternates: [{ hreflang: zh ? 'en' : 'zh', href: DOMAIN + changelogUrl(zh ? 'en' : 'zh', pageNo) }],
  });
}

function llmsFiles(kb, faq) {
  const one = (e) => '- [' + e.title + '](' + DOMAIN + '/docs/#' + e.id + '): ' + e.steps.split('. ')[0] + '.';
  let head = '# ' + site.brand.platform + ' (' + site.brand.app + ')\n';
  head += '> An autonomous social agent that lives on your phone, with a self-sovereign identity (did:wold), verifiable trust and local-first data.\n';
  // ★ ADR-001 规则①「CTA 不指外站」+ §1.1 先例（死链一律换站内可达页）：
  //   源码发布通道（GitHub 仓库 / npm 包）实测均 404（尚未发布），
  //   指过去等于让每个读 llms.txt 的 Agent 学到我们「死了或吹牛」。
  //   ⇒ 只陈述事实 + 指向站内确实覆盖「协议与可验证性」的 /docs/（永远可达）。
  head += 'Source: not publicly published yet (publication pending) · protocol & verifiability: ' + DOMAIN + '/docs/\n';
  let docs = '## Docs (how the app works)\n';
  for (const e of kb.entries) docs += one(e) + '\n';
  let pages = '## Pages\n';
  pages += '- [Home](' + DOMAIN + '/): product overview\n';
  pages += '- [World](' + DOMAIN + '/world/): rooms, official agents, and how socializing works here\n';
  pages += '- [FAQ](' + DOMAIN + '/faq/): ' + faq.length + ' straight answers\n';
  pages += '- [Changelog](' + DOMAIN + '/changelog/): every release since v0.1\n';
  pages += '- [Privacy policy](' + DOMAIN + '/privacy/): local-first, disclosed relay\n';
  const txt = head + '\n' + docs + '\n' + pages;
  let full = txt + '\n# Full documentation\n';
  for (const e of kb.entries) {
    full += '### ' + e.title + '\n' + e.steps + '\n\n';
  }
  full += '## FAQ\n';
  for (const f of faq) full += '### ' + f.q + '\n' + f.a + '\n\n';
  return { txt, full };
}


// ---------- 中文版页面（/zh/…）----------
function docsZhHtml() {
  const entries = docsZh.docs; // {id, title, steps} 精选人工翻译
  // title/description 提成变量：hero 的 h1/副标题与 <title>/meta 必须是同一份
  // 字面量，手抄两份必漂移（0.99.0 文档手抄字节漂移的同类坑）。
  const title = '文档 — 每个功能怎么用';
  const description =
    '大荒AI 完整用户文档：身份备份、社交雷达、大荒世界房间、托办、排查与更多。与 App 内分身检索同源。';
  const toc = entries.map((e) => '<a href="#' + esc(e.id) + '">' + esc(e.title) + '</a>').join('');
  const sections = entries
    .map((e) => '<section class="doc-entry" id="' + esc(e.id) + '"><h2>' + esc(e.title) + '</h2><p>' + esc(e.steps) + '</p></section>')
    .join('');
  return page({
    title,
    description,
    canonical: DOMAIN + '/zh/docs/',
    body:
      '<section class="hero slim"><h1>' + esc(title) + '</h1>' +
      '<p class="hero-sub">' + esc(description) + '</p></section>' +
      '<nav class="kb-toc wrap" aria-label="文档目录">' + toc + '</nav>' +
      '<div class="wrap doc-body">' + sections + '</div>',
    ld: { // 存量修复：传对象而非 jsonLd() 后的字符串（page() 内部统一序列化）
      '@context': 'https://schema.org',
      '@type': 'ItemList',
      name: '大荒AI 文档',
      numberOfItems: docsZh.docs.length,
    },
    lang: 'zh-CN',
    alternates: [{ hreflang: 'en', href: DOMAIN + '/docs/' }],
  });
}

function faqZhHtml() {
  const faqZhAll = siteZh.faq || [];
  const byId = new Map(docsZh.docs.map((e) => [e.id, e]));
  const items = faqZhAll
    .map((f) => ({ q: f.q, a: byId.get(f.id) ? byId.get(f.id).steps : null, id: f.id }))
    .filter((f) => f.a);
  const body =
    '<section class="hero slim"><h1>常见问题</h1>' +
    '<p class="hero-sub">关于大荒AI 的直接回答：身份备份、试用额度、通道与排查。</p></section>' +
    '<div class="wrap faq-body">' +
    items
      .map(
        (f) =>
          '<section class="faq-item" id="' + esc(f.id) + '"><h2>' + esc(f.q) + '</h2>' +
          '<p>' + esc(f.a) + '</p></section>'
      )
      .join('') +
    '</div>';
  return page({
    title: '常见问题 — 大荒AI',
    canonical: DOMAIN + '/zh/faq/',
    body,
    ld: { // 存量修复：传对象而非 jsonLd() 后的字符串
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      mainEntity: siteZh.faq.map((f) => ({
        '@type': 'Question',
        name: f.q,
        acceptedAnswer: { '@type': 'Answer', text: (docsZh.docs.find((e) => e.id === f.id) || {}).steps || '' },
      })),
    },
    lang: 'zh-CN',
  });
}

function homeZhHtml() {
  return homeHtml('zh');
}

function cityZhHtml(c) {
  return cityHtml(c, 'zh');
}

// --------------------------------------------------------- download page ---
//
// ADR-001: the APK is self-hosted, and every published number is COMPUTED from
// the real file rather than typed into a data table. Three habits are baked in:
//
//   1. No hash is ever written by hand - it is hashed from the bytes we ship.
//   2. The published version is read from pubspec.yaml, so it cannot drift.
//   3. Anything short (missing file, wrong flavour, too big, stale signing
//      metadata) throws. A download page that lies is worse than no page.
//
const DL_DIR = path.join(ROOT, 'download');
const PUBSPEC = path.join(REPO, 'pubspec.yaml');
const DL_MAX_BYTES = 50 * 1024 * 1024; // ADR-001 hard rule 6

let _dlInfo = null;
let _dlTruthDone = false;

/**
 * Same as downloadInfo(), but answers "is there anything publishable?" instead
 * of throwing. Used by build() so a release with no packaged APK still ships an
 * honest empty download page instead of nothing at all.
 */
function downloadTruth() {
  if (_dlTruthDone) return _dlInfo;
  _dlTruthDone = true;
  try {
    _dlInfo = downloadInfo();
  } catch (e) {
    if (!/ADR-001|no \.apk|version line/.test(e.message)) throw e;
    console.log('  download: nothing packaged yet -', e.message);
    _dlInfo = null;
  }
  return _dlInfo;
}

function downloadInfo() {
  if (_dlInfo) return _dlInfo;

  if (!fs.existsSync(DL_DIR)) {
    throw new Error(
      'ADR-001: landing/download/ does not exist - put a store-flavour arm64 APK there (see landing/README.md, section 下载页)'
    );
  }
  const all = fs.readdirSync(DL_DIR).filter((f) => /\.apk$/.test(f));
  if (!all.length) throw new Error('ADR-001: no .apk found in landing/download/');

  // Rule 5: the sideload flavour carries extra permissions (src/sideload/).
  // It may be installed by hand; it must never be handed out to strangers.
  const illegal = all.filter((f) => /sideload/i.test(f));
  if (illegal.length) {
    throw new Error('ADR-001 rule 5: sideload APK must never be published: ' + illegal.join(', '));
  }

  // Rule 6: only the arm64 split is published - the all-ABI fat APK is ~87 MB.
  const arm = all.filter((f) => /arm64|v8a/i.test(f));
  if (!arm.length) {
    throw new Error(
      'ADR-001 rule 6: nothing to publish - only arm64 split APKs may be served, found: ' + all.join(', ')
    );
  }
  arm.sort((a, b) => fs.statSync(path.join(DL_DIR, b)).mtimeMs - fs.statSync(path.join(DL_DIR, a)).mtimeMs);

  const srcName = arm[0];
  const abs = path.join(DL_DIR, srcName);
  const buf = fs.readFileSync(abs);
  if (buf.length > DL_MAX_BYTES) {
    throw new Error(
      'ADR-001 rule 6: ' + srcName + ' is ' + buf.length + ' bytes, over the ' + DL_MAX_BYTES + ' byte ceiling'
    );
  }

  const pv = fs.readFileSync(PUBSPEC, 'utf8').match(/^version:\s*(\S+)\s*$/m);
  if (!pv) throw new Error('pubspec.yaml: cannot read the version line');

  // Rule 2: four things must be publishable. The certificate fingerprint cannot
  // be computed with zero dependencies, so it comes from a file written by
  // tool/make_download_page.js - and its own sanity is checked here.
  const signPath = path.join(DL_DIR, 'signing.json');
  if (!fs.existsSync(signPath)) {
    throw new Error('ADR-001 rule 2: landing/download/signing.json missing - generate it with tool/make_download_page.js');
  }
  const signing = readJson(signPath);
  for (const f of ['certSha256', 'scheme', 'alias']) {
    if (!signing[f]) throw new Error('ADR-001 rule 2: signing.json is missing "' + f + '"');
  }
  if (!/^[0-9a-f]{64}$/.test(signing.certSha256)) {
    throw new Error('ADR-001 rule 2: signing.json certSha256 must be 64 lowercase hex chars');
  }
  if (signing.apkFile && signing.apkFile !== srcName) {
    throw new Error('ADR-001 rule 3: signing.json describes "' + signing.apkFile + '" but "' + srcName + '" is being published');
  }

  const version = pv[1].trim();
  _dlInfo = {
    srcName,
    abs,
    size: buf.length,
    sha256: crypto.createHash('sha256').update(buf).digest('hex'),
    version,
    signing,
    pubName: 'fen-' + version + '-arm64.apk',
  };
  return _dlInfo;
}

function humanSize(n) {
  const mb = n / (1024 * 1024);
  return mb.toFixed(1) + ' MB (' + n.toLocaleString('en-US').replace(/,/g, ',') + ' bytes)';
}

function downloadHtml(lang = 'en') {
  const zh = String(lang).toLowerCase().indexOf('zh') === 0;
  const D = zh ? downloadZh : download;
  const I = downloadTruth();
  if (!I) {
    const canon = DOMAIN + (zh ? '/zh/download/' : '/download/');
    const empty = `<section class="hero slim">
  <div class="wrap">
    <h1>${esc(D.h1)}</h1>
    <p class="lede">${esc(D.lede)}</p>
    <p class="dl-actions"><span class="btn btn-disabled" aria-disabled="true" role="link">${esc(D.btnDownload)}</span></p>
    <p class="note">${esc(D.notReady)}</p>
  </div>
</section>`;
    return page({
      title: D.title,
      description: D.description,
      canonical: canon,
      lang: zh ? 'zh-CN' : 'en',
      alternates: [
        { hreflang: 'en', href: DOMAIN + '/download/' },
        { hreflang: 'zh-CN', href: DOMAIN + '/zh/download/' },
      ],
      body: empty,
      ld: { '@context': 'https://schema.org', '@type': 'WebPage', name: D.title, url: canon },
    });
  }
  const href = '/download/' + I.pubName;
  const size = humanSize(I.size);
  const fact = (k, v, mono) => `          <div class="dl-fact">
            <dt>${esc(D.facts[k])}</dt>
            <dd${mono ? ' class="mono"' : ''}>${esc(v)}</dd>
          </div>`;
  const body = `<section class="hero slim">
  <div class="wrap">
    <h1>${esc(D.h1)}</h1>
    <p class="lede">${esc(D.lede)}</p>
    <p class="dl-actions">
      <a class="btn btn-primary btn-dl" href="${esc(href)}" download>
        <span class="dl-btn-main">${esc(D.btnDownload)}</span>
        <span class="dl-btn-sub">${esc(D.btnDownloadSub)} &middot; ${esc(size)}</span>
      </a>
    </p>
    <p class="dl-version">${esc(D.facts.version)} ${esc(I.version)}</p>
  </div>
</section>

<section class="block">
  <div class="wrap">
    <h2>${esc(D.factsTitle)}</h2>
    <dl class="dl-facts">
${fact('version', I.version, true)}
${fact('size', size, true)}
${fact('sha256', I.sha256, true)}
${fact('cert', I.signing.certSha256, true)}
${fact('scheme', I.signing.scheme, false)}
${fact('arch', D.archValue, false)}
    </dl>

    <h2>${esc(D.verifyTitle)}</h2>
    <p>${mdLite(D.verifyNote)}</p>
    <pre class="dl-cmd"><code>sha256sum ${esc(I.pubName)}</code></pre>

    <h2>${esc(D.channelsTitle)}</h2>
    <div class="dl-channels">
${(D.channels || [])
  .map((ch) => {
    const live = ch.status === 'live';
    const steps = (ch.steps || []).length
      ? '        <ol>' + ch.steps.map((s) => '<li>' + esc(s) + '</li>').join('') + '</ol>'
      : '';
    const warn = ch.warn ? '        <p class="dl-channel-warn">' + mdLite(ch.warn) + '</p>' : '';
    return (
      '      <div class="dl-channel">\n' +
      '        <h3>' + esc(ch.name) +
      '<span class="dl-channel-status ' + (live ? 'dl-channel-live' : 'dl-channel-pending') + '">' +
      esc(live ? D.channelLive : D.channelPending) + '</span></h3>\n' +
      '        <p>' + esc(ch.desc) + '</p>\n' +
      (steps ? steps + '\n' : '') +
      (warn ? warn + '\n' : '') +
      '      </div>'
    );
  })
  .join('\n')}
    </div>
    <p class="note">${mdLite(D.versionFeedNote.replace('{feedUrl}', DOMAIN + '/version.json'))}</p>

    <h2>${esc(D.mirrorTitle)}</h2>
    <p>${mdLite(D.mirrorNote)}</p>

    <p class="note">${esc(D.disclaimer)}</p>
  </div>
</section>`;

  const canon = DOMAIN + (zh ? '/zh/download/' : '/download/');
  return page({
    title: D.title,
    description: D.description,
    canonical: canon,
    lang: zh ? 'zh-CN' : 'en',
    alternates: [
      { hreflang: 'en', href: DOMAIN + '/download/' },
      { hreflang: 'zh-CN', href: DOMAIN + '/zh/download/' },
    ],
    body,
    ld: {
      '@context': 'https://schema.org',
      '@type': 'SoftwareApplication',
      name: site.brand.platform,
      operatingSystem: 'Android',
      applicationCategory: 'UtilitiesApplication',
      softwareVersion: I.version,
      fileSize: String(I.size),
      downloadUrl: canon,
      softwareRequirements: 'Android arm64-v8a',
    },
  });
}

// --------------------------------------------------- self-host page --------
//
// Two rules shaped this page:
//  1. No invented URLs. A referral link we do not actually hold renders as a
//     disabled chip with the reason printed beside it - the same judgement as
//     the APK button. A button that 404s is worse than an honest empty slot.
//  2. The disclosure is body text, not a footnote. A material connection has
//     to be unavoidable; a sentence at the very bottom that nobody scrolls to
//     is not a disclosure.
function selfHostHtml(lang = 'en') {
  const zh = String(lang).toLowerCase().indexOf('zh') === 0;
  const D = zh ? selfHostZh : selfHost;

  const need = D.need
    .map(
      ([t, d]) => `      <div class="sh-item">
        <dt>${esc(t)}</dt>
        <dd>${mdLite(d)}</dd>
      </div>`
    )
    .join('\n');

  const notList = D.not.map((s) => `      <li>${mdLite(s)}</li>`).join('\n');

  const routeHead = D.routesHead
    .map((h, i) => (i === 0 ? '<th scope="col" class="sh-corner"></th>' : `<th scope="col">${esc(h)}</th>`))
    .join('');
  const routeRows = D.routes
    .map(
      (r) => `        <tr>
          <th scope="row">${esc(r[0])}</th>
          <td>${mdLite(r[1])}</td>
          <td>${mdLite(r[2])}</td>
        </tr>`
    )
    .join('\n');

  const cards = D.support
    .map((s) => {
      // rel="sponsored" is not decoration: tool/verify_landing.js exempts a
      // link from the "no external anchor" rule only when it carries that
      // attribute, and it also refuses any external anchor whose host is not
      // declared in this data file. Both come from here, never by hand.
      const action = s.url
        ? `<a class="btn btn-primary sh-cta" href="${esc(s.url)}" rel="sponsored noopener" target="_blank">${esc(s.cta)}</a>`
        : `<span class="btn btn-disabled" aria-disabled="true" role="link">${esc(s.cta)}</span>
        <p class="note sh-pending">${esc(s.pending)}</p>`;
      return `      <div class="sh-card" data-support="${esc(s.id)}">
        <h3>${esc(s.title)}</h3>
        <p>${mdLite(s.body)}</p>
        ${action}
      </div>`;
    })
    .join('\n');

  const body = `<section class="hero slim">
  <div class="wrap">
    <h1>${esc(D.h1)}</h1>
    <p class="lede">${esc(D.lede)}</p>
  </div>
</section>

<section class="block">
  <div class="wrap">
    <h2>${esc(D.needTitle)}</h2>
    <dl class="sh-need">
${need}
    </dl>

    <h2>${esc(D.notTitle)}</h2>
    <ul class="sh-not">
${notList}
    </ul>

    <h2>${esc(D.routesTitle)}</h2>
    <table class="sh-table">
      <thead><tr>${routeHead}</tr></thead>
      <tbody>
${routeRows}
      </tbody>
    </table>

    <h2>${esc(D.supportTitle)}</h2>
    <p>${mdLite(D.supportLede)}</p>
    <div class="sh-support">
${cards}
    </div>

    <h2>${esc(D.discTitle)}</h2>
    <p class="sh-disc">${mdLite(D.disc)}</p>

    <h2>${esc(D.freeTitle)}</h2>
    <p>${mdLite(D.free)}</p>
  </div>
</section>`;

  const canon = DOMAIN + (zh ? '/zh/self-host/' : '/self-host/');
  return page({
    title: D.title,
    description: D.description,
    canonical: canon,
    lang: zh ? 'zh-CN' : 'en',
    alternates: [
      { hreflang: 'en', href: DOMAIN + '/self-host/' },
      { hreflang: 'zh-CN', href: DOMAIN + '/zh/self-host/' },
    ],
    body,
    ld: { '@context': 'https://schema.org', '@type': 'WebPage', name: D.title, url: canon },
  });
}

function build() {
  // 0.106.0 实证补线：safeRmDir() 在 0.105.0 就写好了，但这里一直是原始
  // `fs.rmSync(DIST, { recursive: true })` —— 半接线。后果不是理论上的：
  // 2026-10-14 跑 run_all_verify_node.js 时（verify_landing.js 导入即
  // require 本文件），构建进程里的 rmSync 删到一半冻结 15 分钟，dist 长时间
  // 不存在。改名让路 + 分离子进程异步删，构建路径上不再有递归删除。
  safeRmDir(DIST);
  mkdirp(DIST);

  const written = [];

  fs.writeFileSync(path.join(DIST, 'style.css'), css, 'utf8');
  written.push('style.css');

  // 0.96.0: copy local imagery (landing/src/assets -> dist/assets). Local
  // relative paths only; the offline checks in verify_landing.js cover the
  // rest by asserting no http(s) image src ever appears.
  copyDir(path.join(SRC, 'assets'), path.join(DIST, 'assets'));
  written.push('assets/');

  fs.writeFileSync(path.join(DIST, 'index.html'), homeHtml(), 'utf8');
  written.push('index.html');

  for (const c of cities) {
    const dir = path.join(DIST, c.slug);
    mkdirp(dir);
    fs.writeFileSync(path.join(dir, 'index.html'), cityHtml(c), 'utf8');
    written.push(`${c.slug}/index.html`);
  }

  // Privacy policy. A store submission needs a reachable privacy URL, so this
  // is a first-class page, not an afterthought bolted onto dist by hand.
  //
  // ⚠️ These two pushes stay LITERAL strings: tool/verify_legal_links.dart pins
  // the App-openable paths by matching `written.push('privacy/index.html')` as
  // text. Folding them into the loop below would produce the same files while
  // silently unpinning the cross-end check.
  const defLocale = LEGAL_LOCALES.find((l) => l.def);
  if (!defLocale) throw new Error('LEGAL_LOCALES has no default locale (the one at /privacy/ and /terms/)');

  mkdirp(path.join(DIST, 'privacy'));
  fs.writeFileSync(path.join(DIST, 'privacy', 'index.html'), legalHtml('privacy', defLocale), 'utf8');
  written.push('privacy/index.html');

  // Terms of service. Same reasoning: a store submission also needs a reachable
  // terms URL, and it is generated from the same compliance directory.
  mkdirp(path.join(DIST, 'terms'));
  fs.writeFileSync(path.join(DIST, 'terms', 'index.html'), legalHtml('terms', defLocale), 'utf8');
  written.push('terms/index.html');

  // Reference translations: one directory per language, for both documents.
  // The Chinese original above is the text that prevails, so these are additive
  // - removing one never removes a URL the App or a store submission relies on.
  for (const loc of LEGAL_LOCALES) {
    if (loc.def) continue;
    for (const kind of ['privacy', 'terms']) {
      mkdirp(path.join(DIST, kind, loc.seg));
      fs.writeFileSync(path.join(DIST, kind, loc.seg, 'index.html'), legalHtml(kind, loc), 'utf8');
      written.push(`${kind}/${loc.seg}/index.html`);
    }
  }

  // Age requirements, in all five languages. Both documents above mention it,
  // so it needs a URL of its own: a mention with nowhere to go is the dead
  // reference the compliance review flagged.
  for (const loc of LEGAL_LOCALES) {
    mkdirp(path.join(DIST, 'age', loc.seg));
    fs.writeFileSync(path.join(DIST, 'age', loc.seg, 'index.html'), legalHtml('age', loc), 'utf8');
    written.push('age/' + (loc.seg ? loc.seg + '/' : '') + 'index.html');
  }

  // The two literal entries below are also pinned by verify_legal_links.dart.
  // ---------- system knowledge portal ----------
  const kb = parseKnowledge();
  const faq = faqItems(kb);

  mkdirp(path.join(DIST, 'docs'));
  fs.writeFileSync(path.join(DIST, 'docs', 'index.html'), docsHtml(kb), 'utf8');
  written.push('docs/index.html');
  mkdirp(path.join(DIST, 'faq'));
  fs.writeFileSync(path.join(DIST, 'faq', 'index.html'), faqHtml(faq), 'utf8');
  written.push('faq/index.html');

  // 0.115.0: emit every changelog page, not just the first one.
  const clPages = changelogPages();
  mkdirp(path.join(DIST, 'changelog'));
  for (let i = 0; i < clPages.length; i++) {
    const no = i + 1;
    const rel = no === 1 ? 'changelog/index.html' : 'changelog/p' + no + '/index.html';
    // ★ 页 1 是**文件** `changelog/index.html`；页 ≥2 是目录 `changelog/pN/index.html`。
    //   （把 'index.html' 当中间目录段会产出 `changelog/index.html/index.html`。）
    const out = no === 1
      ? path.join(DIST, 'changelog', 'index.html')
      : path.join(DIST, 'changelog', 'p' + no, 'index.html');
    mkdirp(path.dirname(out));
    fs.writeFileSync(out, changelogHtml('en', no), 'utf8');
    written.push(rel);
  }

  mkdirp(path.join(DIST, 'world'));
  fs.writeFileSync(path.join(DIST, 'world', 'index.html'), worldHtml(), 'utf8');
  written.push('world/index.html');
  mkdirp(path.join(DIST, 'zh', 'world'));
  fs.writeFileSync(path.join(DIST, 'zh', 'world', 'index.html'), worldHtml('zh'), 'utf8');
  written.push('zh/world/index.html');

  // ---------- 0.103.0: eight-step Agent demo ----------
  // Both pushes stay LITERAL strings: tool/verify_legal_links.dart-style
  // cross-end checks need a stable text to pin; see also
  // tool/verify_landing_demo.js, which asserts the built files exist.
  mkdirp(path.join(DIST, 'demo'));
  fs.writeFileSync(path.join(DIST, 'demo', 'index.html'), demoHtml(), 'utf8');
  written.push('demo/index.html');
  mkdirp(path.join(DIST, 'zh', 'demo'));
  fs.writeFileSync(path.join(DIST, 'zh', 'demo', 'index.html'), demoHtml('zh'), 'utf8');
  written.push('zh/demo/index.html');

  // ---------- 0.104.0: security mechanism page (stage E) ----------
  // Literal pushes again, for the same reason as the demo entries.
  mkdirp(path.join(DIST, 'security'));
  fs.writeFileSync(path.join(DIST, 'security', 'index.html'), securityHtml(), 'utf8');
  written.push('security/index.html');
  mkdirp(path.join(DIST, 'zh', 'security'));
  fs.writeFileSync(path.join(DIST, 'zh', 'security', 'index.html'), securityHtml('zh'), 'utf8');
  written.push('zh/security/index.html');

  const llm = llmsFiles(kb, faq);
  fs.writeFileSync(path.join(DIST, 'llms.txt'), llm.txt, 'utf8');
  written.push('llms.txt');
  fs.writeFileSync(path.join(DIST, 'llms-full.txt'), llm.full, 'utf8');
  written.push('llms-full.txt');

  // ---------- 中文版页面（/zh/…）----------
  mkdirp(path.join(DIST, 'zh'));
  fs.writeFileSync(path.join(DIST, 'zh', 'index.html'), homeHtml('zh'), 'utf8');
  written.push('zh/index.html');
  for (const c of cities) {
    const dir = path.join(DIST, 'zh', c.slug);
    mkdirp(dir);
    fs.writeFileSync(path.join(dir, 'index.html'), cityHtml(c, 'zh'), 'utf8');
    written.push('zh/' + c.slug + '/index.html');
  }
  mkdirp(path.join(DIST, 'zh', 'docs'));
  fs.writeFileSync(path.join(DIST, 'zh', 'docs', 'index.html'), docsZhHtml(), 'utf8');
  written.push('zh/docs/index.html');
  mkdirp(path.join(DIST, 'zh', 'faq'));
  fs.writeFileSync(path.join(DIST, 'zh', 'faq', 'index.html'), faqZhHtml(), 'utf8');
  written.push('zh/faq/index.html');
  mkdirp(path.join(DIST, 'zh', 'changelog'));
  for (let i = 0; i < clPages.length; i++) {
    const no = i + 1;
    const rel = no === 1 ? 'zh/changelog/index.html' : 'zh/changelog/p' + no + '/index.html';
    const out = no === 1
      ? path.join(DIST, 'zh', 'changelog', 'index.html')
      : path.join(DIST, 'zh', 'changelog', 'p' + no, 'index.html');
    mkdirp(path.dirname(out));
    fs.writeFileSync(out, changelogHtml('zh', no), 'utf8');
    written.push(rel);
  }

  // ---------- ADR-001: self-hosted download ----------
  // The APK is copied under its versioned name, so a stale file can never be
  // served under a URL someone bookmarked last release.
  {
    const I = downloadTruth();
    mkdirp(path.join(DIST, 'download'));
    if (I) {
      fs.copyFileSync(I.abs, path.join(DIST, 'download', I.pubName));
      written.push('download/' + I.pubName);
    }
    fs.writeFileSync(path.join(DIST, 'download', 'index.html'), downloadHtml(), 'utf8');
    written.push('download/index.html');
    mkdirp(path.join(DIST, 'zh', 'download'));
    fs.writeFileSync(path.join(DIST, 'zh', 'download', 'index.html'), downloadHtml('zh'), 'utf8');
    written.push('zh/download/index.html');

    // ---------- version.json（0.113.0：App 内更新检查的唯一事实源） ----------
    // 侧载分发没有应用商店 ⇒ 版本公告只能来自官网。这个文件里的每个数字
    // （版本 / versionCode / 字节 / SHA-256 / 证书指纹）都从 downloadInfo()
    // 现算 —— 与下载页同一事实源，不允许任何手写值。
    if (I) {
      const vj = {
        app: 'world.wold.fen',
        version: I.version,
        versionCode: Number(String(I.version).split('+')[1] || 0),
        url: DOMAIN + '/download/' + I.pubName,
        bytes: I.size,
        sha256: I.sha256,
        certSha256: I.signing.certSha256,
        scheme: I.signing.scheme,
        generatedAt: new Date().toISOString(),
      };
      fs.writeFileSync(path.join(DIST, 'version.json'), JSON.stringify(vj, null, 2) + '\n', 'utf8');
      written.push('version.json');
    }
  }

  // ---------- §7.2 self-host (en + zh) ----------
  mkdirp(path.join(DIST, 'self-host'));
  fs.writeFileSync(path.join(DIST, 'self-host', 'index.html'), selfHostHtml(), 'utf8');
  written.push('self-host/index.html');
  mkdirp(path.join(DIST, 'zh', 'self-host'));
  fs.writeFileSync(path.join(DIST, 'zh', 'self-host', 'index.html'), selfHostHtml('zh'), 'utf8');
  written.push('zh/self-host/index.html');

  // ---------- self-hosted walkthrough video (0.111.0) ----------
  // Same judgement as the APK: a binary asset under a versioned name, copied
  // at build time from landing/video/ (gitignored, manifest-verified). A
  // missing directory leaves dist/video/ empty and the demo pages render
  // their honest placeholder - no dead <video> can ever ship.
  {
    const V = videoTruth();
    mkdirp(path.join(DIST, 'video'));
    if (V) {
      fs.copyFileSync(path.join(VIDEO_DIR, V.file), path.join(DIST, 'video', V.file));
      fs.copyFileSync(path.join(VIDEO_DIR, V.poster), path.join(DIST, 'video', V.poster));
      written.push('video/' + V.file, 'video/' + V.poster);
    }
  }

  const legalUrls = [];
  for (const kind of LEGAL_KINDS) {
    for (const loc of LEGAL_LOCALES) legalUrls.push(legalUrlFor(kind, loc));
  }
  const zhUrls = ['/zh/', '/zh/world/', '/zh/docs/', '/zh/faq/', '/zh/changelog/', ...cities.map((c) => '/zh/' + c.slug + '/'), '/zh/download/', '/zh/self-host/'];
  // 0.115.0: the changelog is paginated - every archive page belongs in the
  // sitemap too, otherwise the older history is reachable only by clicking
  // through the pager (crawlers would never see it).
  const clPageCount = changelogPages().length;
  const clArchiveUrls = [];
  for (let no = 2; no <= clPageCount; no++) {
    clArchiveUrls.push('/changelog/p' + no + '/', '/zh/changelog/p' + no + '/');
  }
  const urls = ['/', '/world/', '/docs/', '/faq/', '/changelog/', '/download/', '/self-host/', ...zhUrls, ...cities.map((c) => '/' + c.slug + '/'), ...legalUrls, ...clArchiveUrls];
  const sitemap =
    `<?xml version="1.0" encoding="UTF-8"?>\n` +
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
    urls
      .map(
        (u) =>
          `  <url><loc>${esc(DOMAIN + u)}</loc><lastmod>${TODAY}</lastmod></url>`
      )
      .join('\n') +
    `\n</urlset>\n`;
  fs.writeFileSync(path.join(DIST, 'sitemap.xml'), sitemap, 'utf8');
  written.push('sitemap.xml');

  const aiCrawlers = [
    'GPTBot', 'OAI-SearchBot', 'ChatGPT-User', 'ClaudeBot', 'anthropic-ai',
    'PerplexityBot', 'Google-Extended', 'Applebot-Extended',
  ];
  const aiBlock = aiCrawlers.map((a) => 'User-agent: ' + a + '\nAllow: /').join('\n\n');
  fs.writeFileSync(
    path.join(DIST, 'robots.txt'),
    'User-agent: *\nAllow: /\n\n' + aiBlock + '\n\nSitemap: ' + DOMAIN + '/sitemap.xml\n',
    'utf8'
  );
  written.push('robots.txt');

  // favicon：Wold 橙点 mark（内联 SVG 文件，零外部请求；深浅色都成立）
  fs.writeFileSync(
    path.join(DIST, 'favicon.svg'),
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">' +
      '<rect width="64" height="64" rx="14" fill="#16181d"/>' +
      '<circle cx="32" cy="32" r="13" fill="#d95f2f"/>' +
      '<circle cx="32" cy="32" r="5" fill="#0f1115"/>' +
    '</svg>',
    'utf8'
  );
  written.push('favicon.svg');

  const report = {
    builtAt: new Date().toISOString(),
    domain: DOMAIN,
    pages: written.length,
    home: 1,
    cities: cities.length,
    privacy: LEGAL_LOCALES.length,
    terms: LEGAL_LOCALES.length,
    age: LEGAL_LOCALES.length,
    selfHost: 2,
    legalLocales: LEGAL_LOCALES.map((l) => l.lang),
    legalDefault: defLocale.lang,
    legalUrls: legalUrls.length,
    sitemapUrls: urls.length,
    docsEntries: kb.entries.length,
    kbVersion: kb.version,
    faqItems: faq.length,
    releaseUrl: site.cta.primaryUrl || null,
    // Not rendered into any page: the published policy is finished text. This
    // is the machine-readable record of whether counsel has signed off yet.
    legalReviewStatus: site.legal.reviewStatus || 'unknown',
    termsReviewStatus: site.legal.termsReviewStatus || 'unknown',
    files: written,
  };
  fs.writeFileSync(path.join(DIST, 'build-report.json'), JSON.stringify(report, null, 2), 'utf8');

  return report;
}

function countDistFiles(dir) {
  let n = 0;
  const walk = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      if (e.isDirectory()) walk(path.join(d, e.name));
      else n++;
    }
  };
  walk(dir);
  return n;
}

const report = build();
console.log('landing build OK');
console.log('  domain      : ' + report.domain);
console.log('  home        : 1');
console.log('  city pages  : ' + report.cities);
console.log('  privacy     : /privacy/ zh-CN +' + (report.privacy - 1) + ' 语种参考译文 (' + report.legalReviewStatus + ')');
console.log('  terms       : /terms/   zh-CN +' + (report.terms - 1) + ' 语种参考译文 (' + report.termsReviewStatus + ')');
console.log('  age         : /age/     zh-CN +' + (report.age - 1) + ' 语种参考译文');
// 0.105.0 收口自查：原此行打 "total files : N"（N = written.length：assets/ 整个目录
// 只记 1 条、build-report.json 后写未计），曾害《交付记录》把重建结果抄成「46 页」
// （磁盘实测 52 文件 / 38 个 HTML）⇒ 标签正名 + 补一条磁盘实测数，两个数都摆出来，
// 杜绝「报告数 ≠ 实际数」这类漂移再有下一个受害者。
console.log('  written     : ' + report.pages + ' 条（生成器写入条目；assets/ 整目录记 1 条，build-report.json 未计入）');
console.log('  dist files  : ' + countDistFiles(DIST) + ' 个（磁盘实测；与 written 的差值 = assets 展开的图片数 + build-report.json）');
console.log(
  '  primary CTA : ' +
    (report.releaseUrl ? report.releaseUrl : '(none -> rendered as non-link)')
);
if (report.legalReviewStatus !== 'approved' || report.termsReviewStatus !== 'approved') {
  console.log('');
  console.log('  !! legal review status = privacy:' + report.legalReviewStatus + ' terms:' + report.termsReviewStatus);
  console.log('     /privacy/ and /terms/ are live text with no "draft" wording in them.');
  console.log('     Have counsel sign off, then set site.legal.reviewStatus / termsReviewStatus = "approved".');
}

