#!/usr/bin/env node
/**
 * Compliance placeholder ledger verification.
 *
 * Why this exists: lib/compliance/ holds three drafts that LOOK complete but
 * contain [占位符]. A placeholder that nobody filled is invisible in review -
 * the document reads fine. This script makes the ledger authoritative in both
 * directions:
 *
 *   1. every placeholder found in the drafts must be REGISTERED in the ledger;
 *   2. every placeholder registered in the ledger must still EXIST in the drafts
 *      (so once you fill one and delete the ledger row, the pair stays consistent).
 *
 * Direction 2 is the one that keeps the ledger from rotting: a ledger that
 * lists things already filled is a ledger nobody trusts.
 *
 *   node tool/verify_compliance_placeholders.js
 */

'use strict';

const fs = require('fs');
const path = require('path');

const DIR = path.join(__dirname, '..', 'lib', 'compliance');
const LEDGER = path.join(DIR, '待填清单.md');

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

/**
 * A placeholder is [text] that is NOT a markdown link (not followed by "(")
 * and NOT an empty checkbox ([ ]).
 */
const PH_RE = /\[([^\]]+)\](?!\()/g;

function placeholdersIn(text) {
  const out = new Set();
  let m;
  PH_RE.lastIndex = 0;
  while ((m = PH_RE.exec(text)) !== null) {
    const t = m[1].trim();
    if (!t) continue; // "- [ ]" task checkbox
    out.add(t);
  }
  return out;
}

console.log('=== 合规待填清单双向校验 ===');

// ------------------------------------------------------------ self-check ---

// The scanner is the guard for everything below. If its matcher silently
// breaks, it would find 0 placeholders and report "all clear" - the exact
// failure mode this project has been bitten by before. So: positive control.
console.log('--- 扫描器自检（positive control）---');

const probe = '联系邮箱：`[主邮箱]` 见 [`隐私政策.md`](隐私政策.md) 待办 - [ ] 已读';
const probeFound = placeholdersIn(probe);
check(probeFound.has('主邮箱'), '自检：能扫出 `[主邮箱]`');
check(!probeFound.has('隐私政策.md'), '自检：markdown 链接不算占位符');
check(!probeFound.has(''), '自检：`- [ ]` 勾选框不算占位符');

// ------------------------------------------------------------- collect -----

const files = fs
  .readdirSync(DIR)
  .filter((f) => f.endsWith('.md') && f !== path.basename(LEDGER))
  .sort();

check(files.length >= 3, '合规草稿至少 3 份（实际 ' + files.length + '）');

const sourceTokens = new Map(); // token -> [file, ...]
for (const f of files) {
  const text = fs.readFileSync(path.join(DIR, f), 'utf8');
  for (const t of placeholdersIn(text)) {
    if (!sourceTokens.has(t)) sourceTokens.set(t, []);
    sourceTokens.get(t).push(f);
  }
}

const ledgerText = fs.readFileSync(LEDGER, 'utf8');
const ledgerTokens = placeholdersIn(ledgerText);

console.log('--- 方向①：源文件里的占位符**必须**已登记 ---');

check(sourceTokens.size > 0, '扫描到占位符（' + sourceTokens.size + ' 个不同的）');

const unregistered = [...sourceTokens.keys()].filter((t) => !ledgerTokens.has(t));
check(
  unregistered.length === 0,
  '全部占位符已登记进清单（漏=' + (unregistered.map((t) => '[' + t + ']').join(' ') || '无') + '）'
);

console.log('--- 方向②：清单里的占位符**必须**仍在源文件（填完要删行）---');

const vanished = [...ledgerTokens].filter((t) => !sourceTokens.has(t));
check(
  vanished.length === 0,
  '清单无"已填却未删行"的条目（多余=' + (vanished.map((t) => '[' + t + ']').join(' ') || '无') + '）'
);

console.log('--- 清单结构完整性 ---');

check(/## 0\. 一分钟版/.test(ledgerText), '含 §0 一分钟版（供本人先看）');
check(/## 1\. 逐条清单/.test(ledgerText), '含 §1 逐条清单');
check(/## 2\./.test(ledgerText), '含 §2 律师裁决项');
check(/## 3\. 消项流程/.test(ledgerText), '含 §3 消项流程');

// The substantive questions are NOT placeholders - nothing scans for them, so
// they are the easiest thing to lose during an edit.
const mustKeep = ['30 日', '72 小时', 'GDPR Art.27', '争议解决', '责任限制', '年龄门槛'];
const lost = mustKeep.filter((k) => !ledgerText.includes(k));
check(lost.length === 0, '§2 律师裁决项未被删（缺=' + (lost.join(' / ') || '无') + '）');

// ------------------------------------------------------------- summary -----

console.log('--- 盘点（供参考，非断言）---');
console.log('  占位符种类: ' + sourceTokens.size);
const byFile = {};
for (const [t, fs_] of sourceTokens) for (const f of fs_) byFile[f] = (byFile[f] || 0) + 1;
for (const f of files) console.log('  ' + f + ': ' + (byFile[f] || 0) + ' 处');

console.log('');
console.log('================ 合规待填清单校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
