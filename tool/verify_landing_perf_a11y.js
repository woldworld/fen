#!/usr/bin/env node
/**
 * Performance + accessibility audit for the whole landing site (0.105.0 / E3).
 *
 * Why this exists: "it builds and it looks fine" is not a measurement. The
 * auditor asked for performance and accessibility numbers; this script drives
 * a real headless browser (CDP), walks every emitted HTML file, and reports
 * per-page transfer bytes, request counts, and an accessibility checklist
 * derived from the real DOM - not from reading the source.
 *
 *   node tool/verify_landing_perf_a11y.js
 *
 * Wired into tool/run_all_verify_node.js (OPTIONAL: it needs a headless Edge,
 * which is an external-environment dependency like the Android SDK). On a
 * machine without Edge it SKIPs rather than FAILs.
 *
 * Assertions (fail the run):
 *   - every page has exactly one <h1>
 *   - heading levels never skip (h1 -> h3 is a defect)
 *   - every <img> has a non-empty alt
 *   - every interactive element (a/button) has an accessible name
 *   - lang attribute present and non-empty
 *   - no page emits more than its per-page HTML byte budget
 *   - no page issues more than its per-page request budget
 *     (default PERF_MAX_REQUESTS; demo pages +1 for the video poster)
 *   - WCAG contrast of the two body text pairs >= 4.5 (light and dark)
 */

'use strict';

const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const DIST = path.join(ROOT, 'landing', 'dist');
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const PORT = 9344;
const BASE = 'http://127.0.0.1:8123';

const PERF_MAX_HTML_BYTES = 150 * 1024;
const PERF_MAX_REQUESTS = 8;

// 0.111.0: the demo page carries a self-hosted walkthrough <video> with a
// poster frame. That is +1 request (the poster; the mp4 itself is
// preload="none" and never fetched until the visitor presses play). The cap
// exists to catch accidental bloat, not to ban an intentional video, so the
// demo pages get a bounded +1 - and the video guard pins the mp4 to
// preload="none" so this stays exactly one extra request.
const PERF_PAGE_MAX_REQUESTS = {
  'demo/index.html': PERF_MAX_REQUESTS + 1,
  'zh/demo/index.html': PERF_MAX_REQUESTS + 1,
};
const maxReqsFor = (rel) => PERF_PAGE_MAX_REQUESTS[rel] || PERF_MAX_REQUESTS;

// The changelog page is a deliberate, BOUNDED exception. Its promise is the
// complete public release history ("every release, in the open") - one long
// document by design, 2 requests, zero external assets, no tracking. The
// 150 KB default still guards every other page against accidental bloat (a
// stray base64 image, a dumped data table); this 1 MB hard cap catches
// runaway growth and will eventually force a real pagination decision instead
// of letting the page quietly double every year.
const PERF_PAGE_MAX_HTML_BYTES = {
  'changelog/index.html': 1024 * 1024,
  'zh/changelog/index.html': 1024 * 1024,
};
// 0.115.0: the changelog is paginated, so the archive pages (changelog/pN/)
// are the same kind of page as the first one - the "complete public release
// history" promise, split by byte budget. They get the same 1 MB hard cap.
//
// ★ The rule is a PREFIX match, not a fixed list: a fixed list would need
//   editing on every future page (p3, p4, ...) and would silently fall back
//   to the 150 KB default in the meantime, i.e. the cap would be wrong
//   exactly when it matters.
//
// ★ The cap is NOT raised. The pages stay under it because build.js splits
//   the history by a 400 KB byte budget, not because the limit was relaxed.
const CHANGELOG_ARCHIVE_MAX_HTML_BYTES = 1024 * 1024;
const isChangelogArchive = (rel) =>
  /^changelog\/p\d+\/index\.html$/.test(rel) ||
  /^zh\/changelog\/p\d+\/index\.html$/.test(rel);
const maxHtmlFor = (rel) =>
  PERF_PAGE_MAX_HTML_BYTES[rel] ||
  (isChangelogArchive(rel) ? CHANGELOG_ARCHIVE_MAX_HTML_BYTES : PERF_MAX_HTML_BYTES);

let pass = 0;
let fail = 0;
const report = [];
function check(ok, label, detail) {
  if (ok) { pass++; report.push('  PASS  ' + label); }
  else {
    fail++;
    const line = '  FAIL  ' + label + (detail ? '  [' + detail + ']' : '');
    report.push(line);
    console.log(line);
  }
}

function getJson(p) {
  return new Promise((resolve, reject) => {
    http.get({ host: '127.0.0.1', port: PORT, path: p }, (r) => {
      let b = '';
      r.on('data', (d) => (b += d));
      r.on('end', () => { try { resolve(JSON.parse(b)); } catch (e) { reject(e); } });
    }).on('error', reject);
  });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---- 守卫自足的静态服务器：服务 landing/dist -------------------------------
// ★★ 0.109.0 修（假红根治）：本守卫原先**假设** `http://127.0.0.1:8123` 上已有一个
//   静态服务器（全文件无 createServer / listen），但 runner 并不提供它 ⇒ 每页
//   Page.navigate 都落到 Edge 的**错误页**，读数于是**每页完全相同**（Edge 错误页含
//   1 个无 alt 的图形、lang 取 Edge UI 语言 = zh）⇒ 38 页全部假红「图片全有 alt」。
//   判据强度**不变**（仍是"每页真渲染出来的 DOM 里不许有无 alt 的 img"），只是让守卫
//   **自己把被测站点端上来** —— 这样它才第一次真正跑起来（此前 0.105.0 起一直被 SKIP 掩盖）。
const SRV_PORT = Number(new URL(BASE).port);
const MIME = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript', '.json': 'application/json', '.svg': 'image/svg+xml',
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp',
  '.ico': 'image/x-icon', '.txt': 'text/plain; charset=utf-8', '.woff2': 'font/woff2',
};
function startStatic() {
  return new Promise((resolve, reject) => {
    const srv = http.createServer((req, res) => {
      let rel = decodeURIComponent((req.url || '/').split('?')[0]);
      if (rel.endsWith('/')) rel += 'index.html';
      const fp = path.join(DIST, rel);
      if (!fp.startsWith(DIST)) { res.writeHead(403); res.end('forbidden'); return; }
      fs.readFile(fp, (e, d) => {
        if (e) { res.writeHead(404); res.end('not found'); return; }
        res.writeHead(200, { 'Content-Type': MIME[path.extname(fp).toLowerCase()] || 'application/octet-stream' });
        res.end(d);
      });
    });
    srv.on('error', reject);
    srv.listen(SRV_PORT, '127.0.0.1', () => resolve(srv));
  });
}

async function waitPort() {
  for (let i = 0; i < 60; i++) {
    try { return await getJson('/json/list'); } catch (e) { await sleep(250); }
  }
  throw new Error('CDP port never came up');
}

class CDP {
  constructor(ws) { this.ws = ws; this.id = 0; this.pending = new Map(); this.handlers = []; }
  static connect(url) {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(url);
      ws.onopen = () => {
        const c = new CDP(ws);
        ws.onmessage = (e) => c.route(typeof e.data === 'string' ? e.data : String(e.data));
        resolve(c);
      };
      ws.onerror = () => reject(new Error('ws error'));
    });
  }
  send(method, params = {}) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  on(fn) { this.handlers.push(fn); }
  route(msg) {
    const d = JSON.parse(msg);
    if (d.id && this.pending.has(d.id)) {
      const p = this.pending.get(d.id);
      this.pending.delete(d.id);
      if (d.error) p.reject(new Error(d.error.message));
      else p.resolve(d.result);
    } else this.handlers.forEach((h) => h(d));
  }
  eval(expr) {
    return this.send('Runtime.evaluate', { expression: expr, returnByValue: true }).then((r) => r.result.value);
  }
}

// ---- WCAG contrast on the palette variables --------------------------------
function relLum(hex) {
  const m = hex.replace('#', '');
  const rgb = [0, 2, 4].map((i) => parseInt(m.slice(i, i + 2), 16) / 255);
  const lin = rgb.map((c) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)));
  return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
}
function contrast(a, b) {
  const l1 = relLum(a), l2 = relLum(b);
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
}

function auditCssContrast() {
  const css = fs.readFileSync(path.join(ROOT, 'landing', 'src', 'style.css'), 'utf8');
  const root = css.match(/:root \{([\s\S]*?)\}/)[1];
  const lightBlock = css.match(/@media \(prefers-color-scheme: light\) \{[\s\S]*?:root \{([\s\S]*?)\}/);
  const val = (block, name) => {
    const m = block.match(new RegExp('--' + name + ':\\s*(#[0-9a-fA-F]{6})'));
    return m ? m[1] : null;
  };
  // Pairs are (foreground, background) variable NAMES. --paper-alt is in the
  // list because that is where most faint text actually lives (cards, footer,
  // breadcrumbs, proof anchors); --accent-soft is the badge background;
  // --on-accent is the text colour on accent fills (buttons, step numbers,
  // progress dots). Checking only --paper would have missed the fact that
  // --ink-faint measured 3.23:1 on card backgrounds.
  const darkPairs = [
    ['ink', 'paper'], ['ink-soft', 'paper'], ['ink-soft', 'paper-alt'],
    ['ink-faint', 'paper'], ['accent-strong', 'paper'],
    ['ink', 'paper-alt'], ['ink-faint', 'paper-alt'], ['accent-strong', 'paper-alt'],
    ['accent-strong', 'accent-soft'],
    ['on-accent', 'accent'], ['on-accent', 'accent-strong'],
  ];
  darkPairs.forEach(([fg, bg]) => {
    const a = val(root, fg), b = val(root, bg);
    if (!a || !b) return;
    const c = contrast(a, b);
    check(c >= 4.5, '暗色对比度 ' + fg + ' / ' + bg + ' = ' + c.toFixed(2) + ':1 (>=4.5)', a + ' on ' + b);
  });
  if (lightBlock) {
    const lb = lightBlock[1];
    const lightPairs = [
      ['ink', 'paper'], ['ink-soft', 'paper'], ['ink-soft', 'paper-alt'],
      ['ink-faint', 'paper'], ['accent-strong', 'paper'],
      ['ink', 'paper-alt'], ['ink-faint', 'paper-alt'], ['accent-strong', 'paper-alt'],
      ['accent-strong', 'accent-soft'],
      ['on-accent', 'accent'], ['on-accent', 'accent-strong'],
    ];
    lightPairs.forEach(([fg, bg]) => {
      const a = val(lb, fg), b = val(lb, bg);
      if (!a || !b) return;
      const c = contrast(a, b);
      check(c >= 4.5, '亮色对比度 ' + fg + ' / ' + bg + ' = ' + c.toFixed(2) + ':1 (>=4.5)', a + ' on ' + b);
    });
  } else {
    check(false, '亮色主题 :root 覆盖块存在');
  }
}

async function main() {
  fs.writeFileSync(path.join(__dirname, '_audit_report.txt'), '');
  auditCssContrast();

  const srv = await startStatic();   // ★ 先端上被测站点，否则 Page.navigate 落到 Edge 错误页（见上）

  const pages = [];
  const walk = (d, pre) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      if (e.isDirectory()) walk(path.join(d, e.name), pre + e.name + '/');
      else if (e.name.endsWith('.html')) pages.push(pre + e.name);
    }
  };
  walk(DIST, '');
  console.log('auditing ' + pages.length + ' html pages');
  check(pages.length > 0, '发现 HTML 页面（' + pages.length + ' 个）');

  const edge = spawn(EDGE, [
    '--headless=new', '--disable-gpu', '--remote-debugging-port=' + PORT,
    '--no-first-run', '--no-default-browser-check',
    '--user-data-dir=' + process.env.TEMP + '/edge_audit_0105',
    'about:blank',
  ], { stdio: 'ignore' });

  try {
    const list = await waitPort();
    const page = list.find((t) => t.type === 'page');
    const cdp = await CDP.connect(page.webSocketDebuggerUrl);

    const reqs = [];
    let transfer = 0;
    cdp.on((d) => {
      if (d.method === 'Network.requestWillBeSent' && !/favicon/i.test(d.params.request.url)) {
        reqs.push({ type: d.params.type, url: d.params.request.url });
      }
      if (d.method === 'Network.loadingFinished') {
        transfer += d.params.encodedDataLength || 0;
      }
    });
    await cdp.send('Network.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Page.enable');

    const rows = [];
    for (const rel of pages) {
      reqs.length = 0; transfer = 0;
      await cdp.send('Page.navigate', { url: BASE + '/' + rel });
      await sleep(700);

      const a = await cdp.eval(`(() => {
        const imgs = [...document.images].filter(i => !i.alt || !i.alt.trim()).length;
        const h1 = document.querySelectorAll('h1').length;
        const levels = [...document.querySelectorAll('h1,h2,h3,h4,h5,h6')].map(h => +h.tagName[1]);
        let skip = 1;
        for (let i = 1; i < levels.length; i++) {
          if (levels[i] > levels[i-1] + 1) { skip = 0; break; }
        }
        const unnamed = [...document.querySelectorAll('a[href], button')].filter(el => {
          const n = (el.textContent || '').trim() || el.getAttribute('aria-label') || el.title;
          return !n;
        }).length;
        const lang = document.documentElement.getAttribute('lang');
        return { imgs, h1, skip, unnamed, lang };
      })()`);

      const htmlBytes = fs.statSync(path.join(DIST, rel)).size;
      rows.push({ rel, htmlBytes, reqs: reqs.length, transfer, ...a });
    }

    console.log('\n--- 每页性能与无障碍 ---');
    rows.forEach((r) => {
      console.log(
        '  ' + r.rel.padEnd(28) +
        ' html=' + String(r.htmlBytes).padStart(7) +
        ' reqs=' + String(r.reqs).padStart(2) +
        ' xfer=' + String(r.transfer).padStart(7) +
        ' h1=' + r.h1 + ' imgNoAlt=' + r.imgs + ' skip=' + (r.skip ? 'ok' : 'BAD') +
        ' unnamed=' + r.unnamed + ' lang=' + r.lang
      );
    });

    console.log('\n--- 判据 ---');
    rows.forEach((r) => {
      check(r.h1 === 1, r.rel + '：唯一 h1', 'h1=' + r.h1);
      check(r.skip === 1, r.rel + '：标题层级无跳级');
      check(r.imgs === 0, r.rel + '：图片全有 alt', 'no-alt=' + r.imgs);
      check(r.unnamed === 0, r.rel + '：链接/按钮全有可访问名', 'unnamed=' + r.unnamed);
      check(!!r.lang, r.rel + '：lang 属性非空');
      const maxB = maxHtmlFor(r.rel);
      check(r.htmlBytes <= maxB, r.rel + '：HTML 体积 <= ' + maxB + ' B', r.htmlBytes + ' B');
      check(r.reqs <= maxReqsFor(r.rel), r.rel + '：请求数 <= ' + maxReqsFor(r.rel), r.reqs + ' 个');
    });

    fs.writeFileSync(path.join(__dirname, '_audit_report.txt'),
      'perf/a11y audit 0.105.0\n' + rows.map((r) =>
        [r.rel, 'html=' + r.htmlBytes, 'reqs=' + r.reqs, 'xfer=' + r.transfer,
         'h1=' + r.h1, 'imgNoAlt=' + r.imgs, 'skip=' + r.skip, 'unnamed=' + r.unnamed, 'lang=' + r.lang]
          .join(' ')
      ).join('\n'), 'utf8');

    cdp.ws.close();
  } finally {
    edge.kill();
    srv.close();
  }

  console.log('\n================ 性能/无障碍审计：' + pass + ' PASS / ' + fail + ' FAIL ================');
  if (fail > 0) process.exitCode = 1;
}

main().catch((e) => { console.log('FATAL ' + (e && e.message)); process.exitCode = 1; });
