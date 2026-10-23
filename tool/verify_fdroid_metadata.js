#!/usr/bin/env node
/**
 * F-Droid 提交材料结构守卫（0.113.0）。
 *
 * Why this exists: fdroid/ 是一份「备好但未提交」的草稿包。草稿最怕两件事：
 *   ① 结构残缺——提交时才发现缺字段 / 缺描述文件，白跑一轮审核；
 *   ② 与仓库事实漂移——pubspec 升了版本，配方里的 versionName/versionCode/
 *      commit 没跟着动，F-Droid 构建直接失败。
 * 本脚本把配方拆成可判定的断言（含正控：毒注入必须能判出）。
 *
 * 注意：本守卫**不**断言「已提交」——提交前置条件（仓库公开 / tag / OWNER
 * 替换 / 截图）是人工清单，见 fdroid/README.md。
 *
 *   node tool/verify_fdroid_metadata.js
 */
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const FDROID = path.join(ROOT, 'fdroid');
const YML = path.join(FDROID, 'metadata', 'world.wold.fen.yml');
const META_DIR = path.join(FDROID, 'metadata', 'world.wold.fen');

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

console.log('=== F-Droid 提交材料结构校验（0.113.0）===');

// ---------------------------------------------------------------- 扫描器自检 ---
// 守卫的判据自己要先能被证伪：一个缺 output 的假配方必须判出。
console.log('--- 扫描器自检（positive control）---');
const probeBad = 'Builds:\n  - versionName: 1.0.0\n    commit: v1.0.0\n';
check(!/output:/.test(probeBad), '自检：缺 output 的配方能被判出（判据非恒真）');
const probeGood = 'Builds:\n  - versionName: 1.0.0\n    output: build/app/outputs/apk/store/release/app-store-arm64-v8a-release-unsigned.apk\n';
check(/output:.*app-store-arm64-v8a-release-unsigned\.apk/.test(probeGood),
  '自检：合法 output 行能通过（判据非恒假）');

// ---------------------------------------------------------------- 文件齐备 ---
console.log('--- 文件齐备 ---');
check(fs.existsSync(YML), 'metadata/world.wold.fen.yml 存在');
check(fs.existsSync(path.join(FDROID, 'README.md')), 'fdroid/README.md（前置条件清单）存在');
for (const loc of ['en-US', 'zh-CN']) {
  for (const f of ['title.txt', 'short_description.txt', 'full_description.txt']) {
    const p = path.join(META_DIR, loc, f);
    let ok = false;
    if (fs.existsSync(p)) {
      const txt = fs.readFileSync(p, 'utf8').trim();
      ok = txt.length > 0;
    }
    check(ok, loc + '/' + f + ' 存在且非空');
  }
}

if (!fs.existsSync(YML)) {
  console.log('\n================ ' + pass + ' PASS / ' + fail + ' FAIL ================');
  if (fail > 0) process.exitCode = 1;
  return;
}

const yml = fs.readFileSync(YML, 'utf8');

// ---------------------------------------------------------------- 顶层字段 ---
console.log('--- 配方顶层字段 ---');
for (const field of ['Categories:', 'License:', 'AuthorName:', 'WebSite:', 'SourceCode:',
  'IssueTracker:', 'RepoType:', 'Repo:', 'Builds:', 'AntiFeatures:', 'Summary:',
  'Description:', 'AutoUpdateMode:', 'UpdateCheckMode:', 'CurrentVersion:',
  'CurrentVersionCode:']) {
  check(yml.includes('\n' + field) || yml.startsWith(field), '含字段 ' + field.replace(':', ''));
}
check(/AntiFeatures:\s*\n\s*-\s*NonFreeNet/.test(yml),
  '★ AntiFeatures 含 NonFreeNet（默认 hub 是项目自营服务，网络层专有）');
check(/License:\s*MIT/.test(yml), '★ License = MIT（客户端许可，与 opensource/LICENSE 一致）');

// ---------------------------------------------------------------- 与仓库事实对账 ---
console.log('--- 配方 ↔ 仓库事实（防漂移）---');
const pubspec = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
const pubVersion = (pubspec.match(/^version:\s*(\S+)\s*$/m) || [])[1] || '';
const pubName = pubVersion.split('+')[0];
const pubCode = String(pubVersion).split('+')[1] || '0';

check(yml.includes('versionName: ' + pubName),
  '★ 配方 versionName == pubspec versionName（' + pubName + '）');
check(yml.includes('versionCode: ' + pubCode),
  '★ 配方 versionCode == pubspec +N（' + pubCode + '）');
check(yml.includes('commit: v' + pubName),
  '★ 配方 commit == v' + pubName + '（tag 必须与版本同名）');
check(yml.includes('CurrentVersion: ' + pubName) && yml.includes('CurrentVersionCode: ' + pubCode),
  '★ CurrentVersion/CurrentVersionCode 与版本一致');

// 构建命令：store flavor + split-per-abi 取 arm64 单包（与官网分发口径一致）
check(/flutter build apk --release --flavor store/.test(yml),
  '★ 构建命令带 --flavor store（零受限权限 flavor；sideload 永不对外）');
check(/--split-per-abi/.test(yml),
  '★ 构建命令带 --split-per-abi（按 ABI 拆分；output 取 arm64 单包，与官网分发口径一致）');
check(/--no-pub/.test(yml),
  '★ 构建命令带 --no-pub（pub get 在 prebuild 用同一个 Flutter 跑）');

// 产物路径：AGP 对未签名 release 的命名惯例（*-unsigned.apk）+ split-per-abi 单 ABI 路径
check(/output:\s*build\/app\/outputs\/apk\/store\/release\/app-store-arm64-v8a-release-unsigned\.apk/.test(yml),
  '★ output = apk/store/release/app-store-arm64-v8a-release-unsigned.apk（AGP 未签名命名 + split-per-abi 单 ABI 路径，F-Droid 自签）');

// srclibs：必须带 flutter，且 README 钉了版本核对这一步
check(/srclibs:\s*\n\s*-\s*flutter@\d+\.\d+\.\d+/.test(yml),
  '★ srclibs 带 flutter@X.Y.Z（F-Droid 构建机不预装 Flutter，自备 SDK）');
const readme = fs.readFileSync(path.join(FDROID, 'README.md'), 'utf8');
check(readme.includes('flutter@3.44.0') || /核对 srclibs 的 Flutter tag/.test(readme),
  '★ README 钉了 Flutter tag 核对步骤（srclibs 版本必须与 .metadata 对应）');

// URL 结构：三个 github URL 齐（OWNER 占位符的替换是提交前人工步骤）
for (const field of ['SourceCode', 'IssueTracker', 'Repo']) {
  const m = yml.match(new RegExp('^' + field + ':\\s*(\\S+)$', 'm'));
  check(!!m && /^https:\/\/github\.com\//.test(m[1]),
    '★ ' + field + ' 是 https://github.com/ 开头的地址（当前 ' + (m ? m[1] : '缺失') + '）');
}

// README 前置条件关键词
for (const kw of ['源码仓库公开', '打 tag', 'OWNER', '截图', 'NonFreeNet']) {
  check(readme.includes(kw), '★ README 前置条件含「' + kw + '」');
}

// ---------------------------------------------------------------- 代码侧门 ---
console.log('--- 代码侧：未签名 release 通道（build.gradle.kts）---');
const gradle = fs.readFileSync(path.join(ROOT, 'android', 'app', 'build.gradle.kts'), 'utf8');
check(gradle.includes('WOLD_UNSIGNED_RELEASE'),
  '★ build.gradle.kts 含 WOLD_UNSIGNED_RELEASE 环境变量门');
check(/System\.getenv\("WOLD_UNSIGNED_RELEASE"\)\s*==\s*"1"/.test(gradle),
  '★ 门是显式环境变量判断（不是默认放行）');
check(/wantsReleaseBuild && !wantsUnsignedRelease/.test(gradle),
  '★ 无密钥 + 无门 ⇒ 仍显式失败（禁止静默回退 debug 签名的纪律不变）');
check(/wantsUnsignedRelease ⇒ 不设 signingConfig/.test(gradle),
  '★ 注释钉死「不设 signingConfig ⇒ 未签名产物」的因果');

console.log('\n================ ' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
