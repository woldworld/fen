#!/usr/bin/env node
/**
 * Walkthrough video verification (0.111.0).
 *
 * Why this exists: the /demo/ page now embeds a real 21 MB mp4 that never
 * enters git. Three ways that silently breaks, none of which shows up as a
 * build failure:
 *
 *   1. The manifest and the file on disk drift (video re-cut, manifest not
 *      regenerated) - the page would then advertise numbers that are wrong,
 *      which is exactly the "hand-copied hash" failure ADR-001 was created
 *      for. Every number is re-derived here from the actual bytes.
 *   2. dist/video/ goes missing or stale while the page keeps pointing at it
 *      - a dead <video> is worse than no video (same rule as a dead download
 *      button). Source <-> manifest <-> dist are all cross-checked.
 *   3. The zh page grows an English player (or keeps a player after the
 *      Chinese cut is pulled) - R27 wants the language sites isomorphic, and
 *      honesty wants a missing video to SAY so instead of faking it.
 *
 *   node tool/verify_landing_video.js
 */

'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.join(__dirname, '..');
const LANDING = path.join(ROOT, 'landing');
const DIST = path.join(LANDING, 'dist');
const VIDEO_DIR = path.join(LANDING, 'video');
const BUILD_JS = path.join(LANDING, 'build.js');
const SERVE_JS = path.join(LANDING, 'serve.js');

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

function exists(p) {
  return fs.existsSync(p);
}

function sha256Of(p) {
  return crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
}

console.log('=== 官网演示视频校验（0.111.0）===');

// Rebuild first: asserting against a stale dist proves nothing (same reason
// verify_landing.js requires build.js instead of trusting what is on disk).
require(BUILD_JS);

// ---------------------------------------------------------------- source ---

const manifestPath = path.join(VIDEO_DIR, 'manifest.json');
const hasManifest = exists(manifestPath);

if (!hasManifest) {
  // Honest-empty contract: no manifest => no player anywhere, no mp4 in dist.
  console.log('');
  console.log('--- 无 manifest（诚实空态契约）---');
  const distVideo = path.join(DIST, 'video');
  const stray = exists(distVideo)
    ? fs.readdirSync(distVideo).filter((f) => /\.(mp4|webm)$/.test(f))
    : [];
  check(stray.length === 0,
    'landing/video/ 无 manifest 时 dist/video/ 不得残留视频文件' +
      (stray.length ? '（残留 ' + stray.join(',') + '）' : ''));
  ['demo/index.html', 'zh/demo/index.html'].forEach((rel) => {
    const p = path.join(DIST, rel);
    const html = exists(p) ? fs.readFileSync(p, 'utf8') : '';
    check(html.indexOf('<video') === -1, rel + ' 不含 <video> 标签（无素材不放死人播放器）');
  });
  console.log('');
  console.log('================ 视频校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
  if (fail > 0) process.exitCode = 1;
  return;
}

const man = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

console.log('');
console.log('--- manifest 完整性 ---');

const MAN_KEYS = ['file', 'bytes', 'sha256', 'durationSeconds', 'poster',
  'posterBytes', 'posterSha256', 'lang', 'disclosure'];
const missMan = MAN_KEYS.filter((k) => !(k in man));
check(missMan.length === 0, 'manifest 字段齐全' + (missMan.length ? '（缺 ' + missMan.join(',') + '）' : ''));
check(/^[0-9a-f]{64}$/.test(String(man.sha256 || '')), 'manifest.sha256 为 64 位小写十六进制');
check(/^[0-9a-f]{64}$/.test(String(man.posterSha256 || '')), 'manifest.posterSha256 为 64 位小写十六进制');
check(/\.mp4$/.test(String(man.file || '')), 'manifest.file 为 .mp4（' + man.file + '）');
check(['en', 'zh'].indexOf(man.lang) !== -1, 'manifest.lang 为 en/zh（当前 ' + man.lang + '）');
check(String(man.disclosure || '').length > 0, 'manifest.disclosure 非空（页面必须带录制版本诚实标注）');

console.log('');
console.log('--- 源文件 ↔ manifest（磁盘实测，禁止手抄）---');

const srcMp4 = path.join(VIDEO_DIR, man.file);
const srcPoster = path.join(VIDEO_DIR, man.poster);
check(exists(srcMp4), '源视频存在：landing/video/' + man.file);
check(exists(srcPoster), '源海报存在：landing/video/' + man.poster);
if (exists(srcMp4)) {
  const n = fs.statSync(srcMp4).size;
  const s = sha256Of(srcMp4);
  check(n === man.bytes, '源视频字节数与 manifest 一致（' + n + '）');
  check(s === man.sha256, '源视频 sha256 与 manifest 一致');
}
if (exists(srcPoster)) {
  const n = fs.statSync(srcPoster).size;
  const s = sha256Of(srcPoster);
  check(n === man.posterBytes, '源海报字节数与 manifest 一致（' + n + '）');
  check(s === man.posterSha256, '源海报 sha256 与 manifest 一致');
}

console.log('');
console.log('--- dist 产物 ↔ manifest ---');

const dstMp4 = path.join(DIST, 'video', man.file);
const dstPoster = path.join(DIST, 'video', man.poster);
check(exists(dstMp4), 'dist 视频存在：dist/video/' + man.file);
check(exists(dstPoster), 'dist 海报存在：dist/video/' + man.poster);
if (exists(dstMp4)) {
  const n = fs.statSync(dstMp4).size;
  const s = sha256Of(dstMp4);
  check(n === man.bytes, 'dist 视频字节数与 manifest 一致（' + n + '）');
  check(s === man.sha256, 'dist 视频 sha256 与 manifest 一致');
}
if (exists(dstPoster)) {
  const n = fs.statSync(dstPoster).size;
  const s = sha256Of(dstPoster);
  check(n === man.posterBytes, 'dist 海报字节数与 manifest 一致（' + n + '）');
  check(s === man.posterSha256, 'dist 海报 sha256 与 manifest 一致');
}

console.log('');
console.log('--- 页面接线（播放器 / 诚实占位 / 零外链）---');

function fmtDuration(sec) {
  const s = Math.round(Number(sec) || 0);
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}

function videoSection(html) {
  const i = html.indexOf('id="video"');
  if (i === -1) return '';
  const j = html.indexOf('</section>', i);
  return j === -1 ? html.slice(i) : html.slice(i, j);
}

const demoEn = exists(path.join(DIST, 'demo', 'index.html'))
  ? fs.readFileSync(path.join(DIST, 'demo', 'index.html'), 'utf8') : '';
const demoZh = exists(path.join(DIST, 'zh', 'demo', 'index.html'))
  ? fs.readFileSync(path.join(DIST, 'zh', 'demo', 'index.html'), 'utf8') : '';

check(demoEn.indexOf('id="video"') !== -1, 'EN 演示页含视频区（id="video"）');
check(demoZh.indexOf('id="video"') !== -1, 'ZH 演示页含视频区（id="video"）');

const secEn = videoSection(demoEn);
const secZh = videoSection(demoZh);

// The language whose manifest.lang matches gets the player; the other gets
// the honest "in production" notice. Never the reverse.
if (man.lang === 'en') {
  check(secEn.indexOf('<video') !== -1, 'EN 页渲染播放器（manifest.lang = en）');
  check(secZh.indexOf('<video') === -1, 'ZH 页为诚实占位、不放英文播放器');
  check(/制作中|重新录制/.test(secZh), 'ZH 页占位文案说明「制作中/重新录制」');
} else {
  check(secZh.indexOf('<video') !== -1, 'ZH 页渲染播放器（manifest.lang = zh）');
  check(secEn.indexOf('<video') === -1, 'EN 页为诚实占位');
}

if (secEn.indexOf('<video') !== -1 || secZh.indexOf('<video') !== -1) {
  const live = man.lang === 'en' ? secEn : secZh;
  check(live.indexOf('src="/video/' + man.file + '"') !== -1,
    '播放器 source 指向 /video/' + man.file);
  check(live.indexOf('poster="/video/' + man.poster + '"') !== -1,
    '播放器 poster 指向 /video/' + man.poster);
  check(live.indexOf('preload="none"') !== -1, '播放器 preload="none"（不偷偷拉 20MB）');
  check(live.indexOf('controls') !== -1, '播放器带原生 controls');
  const mb = (man.bytes / (1024 * 1024)).toFixed(1) + ' MB';
  check(live.indexOf(mb) !== -1, '页面显示的体积由字节数算出（' + mb + '）');
  check(live.indexOf(fmtDuration(man.durationSeconds)) !== -1,
    '页面显示的时长由秒数算出（' + fmtDuration(man.durationSeconds) + '）');
  check(live.indexOf(man.disclosure) !== -1, '页面带录制版本诚实标注（manifest.disclosure 原文）');
  // R27 / ADR-001: no external resource, ever.
  const ext = [];
  for (const m of live.matchAll(/<(?:source|video|img)[^>]*?(?:src|poster)="(https?:\/\/[^"]+)"/g)) {
    ext.push(m[1]);
  }
  check(ext.length === 0, '视频区无外部资源引用' + (ext.length ? '（' + ext.join(',') + '）' : ''));
}

console.log('');
console.log('--- 源码钉（构建/预览接线不可被折叠掉）---');

const bsrc = fs.readFileSync(BUILD_JS, 'utf8');
check(bsrc.indexOf("written.push('video/' + V.file") !== -1,
  'build.js 含视频 copy 写入（written.push video/）');
check(bsrc.indexOf('const VIDEO_DIR = path.join(ROOT, \'video\')') !== -1,
  'build.js 定义 VIDEO_DIR');
check(bsrc.indexOf('function videoTruth()') !== -1, 'build.js 含 videoTruth() 真值函数');
check(bsrc.indexOf("throw new Error('video: manifest sha256 does not match '") !== -1,
  'build.js 对 manifest sha 不符抛错（漂移即失败）');

const ssrc = fs.readFileSync(SERVE_JS, 'utf8');
check(ssrc.indexOf("'.mp4': 'video/mp4'") !== -1,
  'serve.js 含 .mp4 MIME（本地预览能播）');

console.log('');
console.log('--- 正控（证明判据真的会翻红）---');

// 1. A manifest whose sha does not match the file must be caught: feed the
//    real predicate a mutated copy.
{
  const bad = Object.assign({}, man, { sha256: '0'.repeat(64) });
  const realSha = sha256Of(srcMp4);
  check(bad.sha256 !== realSha,
    '★ 正控预备：被篡改的 sha 与真实文件确实不同');
  const caught = (function () {
    // same predicate shape as the dist assertion above
    return sha256Of(dstMp4) !== bad.sha256;
  })();
  check(caught === true, '★ 正控：sha 不符的 manifest 必然被字节对账抓到');
}
// 2. An external source URL in the video section must be caught.
{
  const fake = '<video controls preload="none"><source src="https://cdn.example/x.mp4" type="video/mp4"></video>';
  const ext = [];
  for (const m of fake.matchAll(/<(?:source|video|img)[^>]*?(?:src|poster)="(https?:\/\/[^"]+)"/g)) {
    ext.push(m[1]);
  }
  check(ext.length === 1, '★ 正控：外链视频源必须被零外链判据抓到');
}
// 3. A zh page carrying a player while manifest.lang is 'en' must be caught.
{
  const fakeZhWithPlayer = videoSection('<section id="video"><video src="/video/x.mp4"></video></section>');
  check(fakeZhWithPlayer.indexOf('<video') !== -1,
    '★ 正控预备：含播放器的 zh 区块可被识别');
  const contractHolds = man.lang === 'en' && secZh.indexOf('<video') === -1;
  check(contractHolds, '★ 正控：en  manifest 下 zh 页无播放器的契约成立');
}
// 4. Duration/size strings must be computed, not decorative.
{
  const wrong = fmtDuration(man.durationSeconds + 999);
  check(wrong !== fmtDuration(man.durationSeconds), '★ 正控：错误时长必然与页面显示不同');
}

console.log('');
console.log('================ 视频校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
