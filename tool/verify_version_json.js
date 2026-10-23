#!/usr/bin/env node
/**
 * version.json 三处对账守卫（0.113.0）。
 *
 * Why this exists: 侧载分发没有应用商店，App 内「检查更新」读的唯一事实源
 * 就是官网 version.json。这个文件里的每个数字（版本 / versionCode / 字节 /
 * SHA-256 / 证书指纹 / 下载地址）都必须在构建时从真实产物现算 —— 手写一个
 * 数字，迟早与产物漂移，而漂移的版本公告比没有公告更糟（用户拿着旧哈希
 * 去核对新包，会以为官方包被篡改）。
 *
 * 判据（全部指向可重算的事实源）：
 *   1. version.json.version        == pubspec.yaml 的 version 行
 *   2. version.json.versionCode    == pubspec version 的 +N 部分
 *   3. version.json.bytes/sha256   == landing/download/ 里真实 APK 的字节与哈希
 *   4. version.json.certSha256     == signing.json 的证书指纹
 *   5. version.json.url            == DOMAIN + '/download/' + pubName，
 *      且 dist/download/<pubName> 真实存在
 *   6. App 侧接线：服务用 SetupService.defaultWebUrl（无裸域名硬编码），
 *      设置页 import 了服务，五语种 ARB 九个键齐，pubspec 里
 *      package_info_plus 是**直接**依赖
 *
 * 无 APK 产物（干净克隆）⇒ exit 2（SKIP，由 run_all_verify_node.js 的
 * OPTIONAL 名单吞掉）；有产物但数字不符 ⇒ FAIL 计入（守卫必须能变红）。
 *
 *   node tool/verify_version_json.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.join(__dirname, '..');
const LANDING = path.join(ROOT, 'landing');
const DIST = path.join(LANDING, 'dist');
const DL_DIR = path.join(LANDING, 'download');

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

console.log('=== version.json 三处对账（0.113.0）===');

// Build first: single command, and a stale dist can never masquerade as
// a passing build (same discipline as verify_landing.js).
require(path.join(LANDING, 'build.js'));

const site = JSON.parse(fs.readFileSync(path.join(LANDING, 'data', 'site.json'), 'utf8'));
const DOMAIN = site.brand.domain.replace(/\/+$/, '');

// ---------------------------------------------------------------- 产物在不在 ---
const vjPath = path.join(DIST, 'version.json');
if (!fs.existsSync(vjPath)) {
  // 没有 APK 时 build.js 不写 version.json（诚实留白）⇒ 环境不可用，SKIP。
  console.log('  SKIP  landing/dist/version.json 不存在（无 APK 产物，非代码回归）');
  process.exit(2);
}
const vj = JSON.parse(fs.readFileSync(vjPath, 'utf8'));

// ---------------------------------------------------------------- 事实源 ---
const pubspec = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
const pubVersion = (pubspec.match(/^version:\s*(\S+)\s*$/m) || [])[1] || '';
const pubCode = Number(String(pubVersion).split('+')[1] || 0);

const apks = fs.existsSync(DL_DIR)
  ? fs.readdirSync(DL_DIR).filter((f) => /\.apk$/.test(f))
  : [];
if (!apks.length) {
  console.log('  SKIP  landing/download/ 无 APK（无产物，非代码回归）');
  process.exit(2);
}
const apkName = apks[0];
const apkBuf = fs.readFileSync(path.join(DL_DIR, apkName));
const apkSha = crypto.createHash('sha256').update(apkBuf).digest('hex');
const signing = JSON.parse(fs.readFileSync(path.join(DL_DIR, 'signing.json'), 'utf8'));

// ---------------------------------------------------------------- 对账 ---
console.log('--- version.json ↔ pubspec / APK / signing.json ---');

check(vj.version === pubVersion,
  '★ version.json.version == pubspec（' + pubVersion + '）');
check(vj.versionCode === pubCode,
  '★ version.json.versionCode == pubspec 的 +N（' + pubCode + '）');
check(vj.bytes === apkBuf.length,
  '★ version.json.bytes == 真实 APK 字节（' + apkBuf.length + '）');
check(vj.sha256 === apkSha,
  '★ version.json.sha256 == 真实 APK 哈希（防手抄漂移）');
check(vj.certSha256 === signing.certSha256,
  '★ version.json.certSha256 == signing.json 证书指纹');
check(vj.scheme === signing.scheme,
  '★ version.json.scheme == signing.json 签名方案');
check(vj.app === 'world.wold.fen',
  '★ version.json.app == applicationId（world.wold.fen）');

const expectPubName = 'fen-' + pubVersion + '-arm64.apk';
const expectUrl = DOMAIN + '/download/' + expectPubName;
check(vj.url === expectUrl,
  '★ version.json.url == ' + expectUrl);
check(fs.existsSync(path.join(DIST, 'download', expectPubName)),
  '★ dist/download/' + expectPubName + ' 真实存在（url 指到的文件真的在）');

// ---------------------------------------------------------------- App 侧接线 ---
console.log('--- App 侧接线（服务 / 设置页 / ARB / pubspec）---');

const svc = fs.readFileSync(path.join(ROOT, 'lib', 'core', 'update_check_service.dart'), 'utf8');
check(svc.includes("SetupService.defaultWebUrl + versionJsonPath"),
  '★ 服务地址走 SetupService.defaultWebUrl（换域名只改那一处）');
check(!/['"]https:\/\/wold\.world/.test(svc),
  '★ 服务里没有裸 https://wold.world 硬编码（唯一来源纪律）');
check(svc.includes('compareVersionNames') && svc.includes('isNewer'),
  '★ 服务含版本名逐段比较（versionCode 长期停在 +1，只比它会漏判）');
check(/static const String versionJsonPath = '\/version\.json';/.test(svc),
  '★ versionJsonPath 与 build.js 写出位置一致（/version.json）');

const settings = fs.readFileSync(path.join(ROOT, 'lib', 'ui', 'settings_screen.dart'), 'utf8');
check(settings.includes("import '../core/update_check_service.dart';"),
  '★ 设置页 import 了更新检查服务');
check(settings.includes('_UpdateCheckCard(onOpenDownload:'),
  '★ 设置页真的挂了 _UpdateCheckCard（不是只 import 不用）');
check(settings.includes('UpdateCheckService().check(force: true)'),
  '★ 手动检查走 force（跳过 24h 节流）');

// 五语种 ARB 九个键齐（判据是五语种同步增减，不是各语种绝对数相等）
const KEYS = [
  'settingsUpdateTitle', 'settingsUpdateHint', 'settingsUpdateButton',
  'settingsUpdateChecking', 'settingsUpdateUpToDate', 'settingsUpdateAvailable',
  'settingsUpdateOpenDownload', 'settingsUpdateNetworkError',
  'settingsUpdateBadResponse',
];
for (const arb of ['app_en.arb', 'app_zh.arb', 'app_zh_Hant.arb', 'app_ja.arb', 'app_vi.arb']) {
  const txt = fs.readFileSync(path.join(ROOT, 'lib', 'l10n', arb), 'utf8');
  const missing = KEYS.filter((k) => !txt.includes('"' + k + '"'));
  check(missing.length === 0,
    '★ ' + arb + ' 九个更新检查键齐（缺=' + (missing.join(',') || '无') + '）');
}
// 占位符对齐：en 声明 {version} 的键，各语种文案里也得有 {version}
for (const arb of ['app_zh.arb', 'app_zh_Hant.arb', 'app_ja.arb', 'app_vi.arb']) {
  const obj = JSON.parse(fs.readFileSync(path.join(ROOT, 'lib', 'l10n', arb), 'utf8'));
  const okPh = KEYS.filter((k) => /\{version\}/.test(String(obj[k] || '')));
  check(okPh.length === 2,
    '★ ' + arb + ' 两个 {version} 占位符键都在（hint + available）');
}

check(/^  package_info_plus:/m.test(pubspec),
  '★ pubspec.yaml 里 package_info_plus 是**直接**依赖（本机版本读取）');

// ---------------------------------------------------------------- 生成器 ---
console.log('--- 生成器（build.js）---');
const buildJs = fs.readFileSync(path.join(LANDING, 'build.js'), 'utf8');
check(buildJs.includes("path.join(DIST, 'version.json')"),
  '★ build.js 真的写 dist/version.json（不是只在文档里说）');
check(buildJs.includes('versionCode: Number(String(I.version)'),
  '★ versionCode 从 pubspec 版本现算（无手写）');

console.log('\n================ ' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
