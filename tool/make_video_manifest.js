#!/usr/bin/env node
/**
 * Regenerate landing/video/manifest.json from a real mp4 (0.111.0).
 *
 * Why this exists: the manifest feeds every number the /demo/ page prints
 * (bytes, duration) and tool/verify_landing_video.js re-derives all of them
 * from the actual file. Hand-editing a manifest is the "hand-copied hash"
 * failure ADR-001 was created for - a re-cut video with a stale manifest
 * would make the page advertise numbers that are simply wrong.
 *
 *   node tool/make_video_manifest.js <file.mp4> --lang en \
 *        [--poster <file.jpg>] [--poster-at <seconds>] \
 *        [--recorded-on "..."] [--disclosure "..."]
 *
 * - bytes / sha256 are computed with node crypto (no hand-typed values).
 * - duration comes from ffprobe (same tool the narration pipeline used).
 * - --poster-at extracts a frame with ffmpeg when no --poster is given.
 * - The versioned file name is derived from pubspec.yaml, so a stale asset
 *   can never be served under a URL someone bookmarked (same rule as the
 *   APK: fen-<version>-arm64.apk).
 */

'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const VIDEO_DIR = path.join(ROOT, 'landing', 'video');

function argOf(flag) {
  const i = process.argv.indexOf(flag);
  return i === -1 ? null : process.argv[i + 1];
}

const src = process.argv[2];
if (!src || !/\.mp4$/.test(src)) {
  console.error('usage: node tool/make_video_manifest.js <file.mp4> --lang en|zh [--poster f.jpg] [--poster-at 25] [--recorded-on "..."] [--disclosure "..."]');
  process.exit(1);
}
const lang = argOf('--lang');
if (lang !== 'en' && lang !== 'zh') {
  console.error('--lang must be en or zh (the language site this video is for)');
  process.exit(1);
}
if (!fs.existsSync(src)) {
  console.error('file not found: ' + src);
  process.exit(1);
}

// ---- version from pubspec (single source of truth for the published name) --
const pubspec = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
const ver = (pubspec.match(/^version:\s*(\S+)/m) || [])[1];
if (!ver) throw new Error('pubspec.yaml: no version line');
const base = 'fen-demo-' + lang + '-' + ver;
const mp4Name = base + '.mp4';
const posterName = base + '.jpg';

// ---- copy the asset under its versioned name ------------------------------
fs.mkdirSync(VIDEO_DIR, { recursive: true });
const dst = path.join(VIDEO_DIR, mp4Name);
fs.copyFileSync(src, dst);
const buf = fs.readFileSync(dst);
const sha256 = crypto.createHash('sha256').update(buf).digest('hex');

// ---- duration via ffprobe --------------------------------------------------
function ffprobeDuration(file) {
  const r = spawnSync('ffprobe', ['-v', 'quiet', '-show_entries', 'format=duration', '-of', 'csv=p=0', file], {
    encoding: 'utf8',
  });
  if (r.status !== 0 || !r.stdout) {
    throw new Error('ffprobe failed for ' + file + ': ' + String(r.stderr || '').slice(0, 200));
  }
  return Math.round(parseFloat(r.stdout.trim()) * 1000) / 1000;
}
const durationSeconds = ffprobeDuration(dst);

// ---- poster: given, or extracted at --poster-at ----------------------------
let posterSrc = argOf('--poster');
if (!posterSrc) {
  const at = argOf('--poster-at') || '25';
  posterSrc = path.join(VIDEO_DIR, '_poster_tmp.jpg');
  const r = spawnSync('ffmpeg', ['-y', '-v', 'quiet', '-ss', String(at), '-i', dst, '-frames:v', '1', '-q:v', '3', posterSrc], {
    encoding: 'utf8',
  });
  if (r.status !== 0 || !fs.existsSync(posterSrc)) {
    throw new Error('ffmpeg poster extraction failed: ' + String(r.stderr || '').slice(0, 200));
  }
}
const posterDst = path.join(VIDEO_DIR, posterName);
fs.copyFileSync(posterSrc, posterDst);
const pbuf = fs.readFileSync(posterDst);
const posterSha256 = crypto.createHash('sha256').update(pbuf).digest('hex');
if (posterSrc.indexOf('_poster_tmp') !== -1) fs.unlinkSync(posterSrc);

// ---- manifest --------------------------------------------------------------
const manifest = {
  file: mp4Name,
  bytes: buf.length,
  sha256,
  durationSeconds,
  poster: posterName,
  posterBytes: pbuf.length,
  posterSha256,
  lang,
  recordedOn: argOf('--recorded-on') || 'unknown build',
  disclosure: argOf('--disclosure') || 'Recorded on an earlier development build; the interface has changed since.',
};
fs.writeFileSync(path.join(VIDEO_DIR, 'manifest.json'),
  JSON.stringify(manifest, null, 2) + '\n', 'utf8');

console.log('manifest written: landing/video/manifest.json');
console.log('  ' + mp4Name + '  ' + buf.length + ' B  ' + durationSeconds + ' s');
console.log('  ' + posterName + '  ' + pbuf.length + ' B');
console.log('  sha256 ' + sha256);
