#!/usr/bin/env node
// 一次跑完 tool/ 下所有 Node 侧校验/冒烟脚本，并汇总 PASS/FAIL。
//
// 为什么要有它：Node 侧脚本此前只能逐个手敲，漏跑一个看不出来（交付口径却被带偏）。
// 与 dart run tool/run_all_verify.dart 对称：都是"扫目录 + 逐个跑 + 抓读数汇总"。
//
// 用法：
//   node tool/run_all_verify_node.js
//
// 约定：
//   - 扫描 tool/ 下 verify_*.js 与 smoke_*.js（不含本文件）。
//   - 读数从脚本输出的 "N PASS / M FAIL" 抓；抓不到就按 exit code 判（0 → 未知读数但绿）。
//   - OPTIONAL 里的脚本是"发布侧闸门"，依赖外部环境（Android SDK / 备份目录），
//     跑不过只报 SKIP、不算 FAIL —— 否则换台没装 Android Studio 的机器整条回归就红了，
//     那不是代码坏了，是判据写错了。
//
// ⚠️ 多数 verify_*.js 要吃 Dart 探针（tool/_m9_*.txt / .log_probe.json / _m10_role_*.txt /
// .contribution_probe.json / .hub_write_probe.json）。跑之前先跑对应的 Dart 校验生成探针。

'use strict';
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const TOOL = path.join(ROOT, 'tool');

// 依赖外部环境的可选脚本（跑不过 → SKIP，不计 FAIL）。
// verify_landing_perf_a11y.js：CDP 驱动 headless Edge 实测全站性能/无障碍，
// 与 Android SDK 同属"机器上可能没有"的外部依赖；且要求 landing/dist 已构建。
// verify_apk_artifact.js（0.106.0 登记）：依赖**构建产物** APK；无产物时按设计
// `exit 2`（明确 SKIP，不假装通过）。本 runner 是「扫目录自动发现」verify_*.js，
// 所以它天然会被收进来 —— 若不登记在此，干净克隆（build/ 尚未生成 APK）
// 会让整条 node 关**变红**，而那不是代码坏了、是判据写错了（本文件头已写明这条）。
// 有产物 ⇒ 正常跑（11 PASS）；无产物 ⇒ 记 SKIP，不污染 ΣPASS/ΣFAIL。
// verify_deploy_site_freshness.js（0.108.0 登记）：同样依赖**构建产物**
// （`lib/dist/大荒服务器一键部署包.zip`），无产物时按设计 `exit 2`（SKIP）。
// 它是发布侧闸门——**打包后必须再跑一次**，用来抓"包内 site/ 快照比 CHANGELOG 旧"
// 这一此前无人看守的失效模式（verify_landing.js 会自重建 dist，结构上看不到陈旧）。
// 有产物 ⇒ 正常跑（22 PASS）；无产物 ⇒ 记 SKIP（★ 22 = 17 主体 + 第 ④ 组 5 条
// 「《交付记录》§129.8c 的终稿字节 / sha256 == 真实 zip」，含 1 条正控）。
// verify_version_json.js（0.113.0 登记）：依赖**构建产物**（landing/download/ 的
// APK + landing/dist/version.json）。无 APK 时按设计 `exit 2`（SKIP）——干净克隆
// 没有 APK，那不是代码坏了；有 APK 但数字不符 ⇒ FAIL 计入（守卫必须能变红）。
const OPTIONAL = new Set([
  'verify_key_backup_drill.js',
  'verify_landing_perf_a11y.js',
  'verify_apk_artifact.js',
  'verify_deploy_site_freshness.js',
  'verify_version_json.js',
  // verify_opensource_release.js（2026-10-20 A/B 拍板轮登记）：依赖**生成物**
  // `opensource-release/` 导出树（由 opensource_release.ps1 产生），干净克隆本就没有
  // ⇒ 无树时按设计 exit 2（SKIP）。它守的是门禁第 24 条的真判据：
  // 导出树 pubspec version == 主仓 version（陈旧即 FAIL）+ 五件材料在盘 +
  // lib/hub 与 lib/dist 零外泄。★ 有树 ⇒ 正常跑，别把它当"可忽略"。
  'verify_opensource_release.js',
]);

const RE_READ = /(\d+)\s+PASS\s*\/\s*(\d+)\s+FAIL/;

function main() {
  const names = fs
    .readdirSync(TOOL)
    .filter((f) => /^(verify_|smoke_).*\.js$/.test(f) && f !== 'run_all_verify_node.js')
    .sort();

  console.log('=== Node 侧校验汇总（' + names.length + ' 个脚本）===');

  let tp = 0;
  let tf = 0;
  const rows = [];
  const failed = [];
  const skipped = [];

  for (const n of names) {
    const r = spawnSync(process.execPath, [path.join(TOOL, n)], {
      cwd: ROOT,
      encoding: 'utf8',
      maxBuffer: 64 * 1024 * 1024,
    });
    const out = String(r.stdout || '');
    const err = String(r.stderr || '');
    const m = out.match(RE_READ);
    const pass = m ? Number(m[1]) : -1;
    const fail = m ? Number(m[2]) : -1;
    const code = r.status == null ? -1 : r.status;

    if (code === 0 && fail === 0) {
      tp += pass < 0 ? 0 : pass;
      rows.push('  OK    ' + n + '  ' + pass + ' PASS / ' + fail + ' FAIL');
      continue;
    }

    if (OPTIONAL.has(n)) {
      // ★★ 0.109.0 修：原实现把 OPTIONAL 的**任何**非（exit0+fail0）都记 SKIP ⇒
      //   连**真 FAIL**（脚本自己报出明确的失败条数 fail>0）也被一并吞掉 ⇒ 整关**永不变红**
      //   （等于「守卫已瞎」）。0.108.0 时它恰好全过（22 PASS）故未暴露；0.109.0 因判据真红
      //   才当场抓住。正确语义：OPTIONAL 只吞「环境不可用 / 无产物」这类**没有失败读数**的情形；
      //   一旦脚本报出 fail>0，那是判据真的红了，必须记账（「守卫必须能变红」的硬要求）。
      if (fail > 0) {
        tf += fail;
        failed.push({ n, code, out, err });
        rows.push('  FAIL  ' + n + '  ' + fail + ' FAIL（可选脚本，但断言真红 ⇒ 计入 FAIL）');
      } else {
        skipped.push(n);
        rows.push('  SKIP  ' + n + '  （依赖外部环境：Android SDK / 密钥备份目录；发布侧闸门，不计 FAIL）');
      }
      continue;
    }

    tf += fail < 0 ? 1 : fail;
    failed.push({ n, code, out, err });
    rows.push('  FAIL  ' + n + '  ' + (fail < 0 ? '退出码=' + code + '（无读数，可能崩了）' : fail + ' FAIL'));
  }

  console.log(rows.join('\n'));

  if (failed.length) {
    console.log('\n--- 失败详情（各脚本最后 15 行）---');
    for (const f of failed) {
      const lines = (f.out || '').split('\n').filter((l) => l.trim());
      const tail = lines.slice(-15).join('\n');
      console.log('\n[ ' + f.n + ' ] exit=' + f.code);
      console.log(tail || (f.err || '').slice(0, 1200));
    }
    console.log('\n提示：多数 verify_*.js 需先跑对应 Dart 校验生成探针（见文件头注释）。');
  }

  if (skipped.length) {
    console.log('\n--- 跳过（可选，非代码回归）---');
    skipped.forEach((s) => console.log('  ' + s));
  }

  console.log('\n================ Node 合计：' + tp + ' PASS / ' + tf + ' FAIL ================');
  if (tf > 0) process.exitCode = 1;
}

main();
