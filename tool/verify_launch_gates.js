#!/usr/bin/env node
/**
 * 上线合规门槛清单守卫（lib/compliance/上线合规门槛清单.md）
 *
 * 为什么要有它：这张表的价值全在「每行都有可执行判据」和「状态不能自己变」。
 * 一份纯文字的门禁清单会以三种方式烂掉，本守卫各配一条断言：
 *
 *   ① 条数与自报数字脱钩 —— §0 写着「21 条」，表里改成 19 条，没人看得出来。
 *   ② 状态词漂移 —— 有人把「待裁决」改成「基本满足」「先放着」，表看着还是绿的。
 *   ③ 引一个不存在的守卫当证据 —— 判据列写个听起来很像的脚本名，永远没人跑它。
 *
 * 另外断言「五语种合规文档 15 份真的在盘」与「表格不被正文截断」，把口头承诺变成读数。
 *
 *   ④ 表格被正文截断 —— 以 | 开头的行，若上一行既非空也不以 | 开头，Markdown 不会把它
 *      接回表格，而是原样吐出一串竖线。0.116.0 实证：隐私政策 §5「撤回同意 / 注销」被一段
 *      无序列表挤出表格，**五语种全中**，源文件里肉眼看几乎正常。
 *
 * 本守卫不依赖任何构建产物，不登 run_all_verify_node.js 的 OPTIONAL。
 * 用法：node tool/verify_launch_gates.js
 */

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const DOC = path.join(ROOT, 'lib', 'compliance', '上线合规门槛清单.md');
const COMPLIANCE = path.join(ROOT, 'lib', 'compliance');

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

// --------------------------------------------------------------- parsers ---

/** 从反引号里的路径取「被引用为证据的文件」。只认带扩展名且以已知根开头的。 */
const REF_ROOTS = ['tool/', 'landing/', 'lib/', 'android/'];
const REF_EXT = /\.(js|dart|md|json|ps1)$/;

function extractRefs(text) {
  const out = new Set();
  const re = /`([^`\n]+)`/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    // 单元格里常写成「node tool/x.js」或「dart run tool/y.dart」——
    // 按空白切开逐段试，命令前缀不参与路径判定。
    for (const piece of m[1].trim().split(/\s+/)) {
      if (!REF_ROOTS.some((r) => piece.startsWith(r))) continue;
      if (!REF_EXT.test(piece)) continue;
      out.add(piece);
    }
  }
  return out;
}

/** 表格主行：首列必须是纯数字。返回 [{no, cells, raw}]。 */
function parseRows(text) {
  const rows = [];
  for (const line of text.split('\n')) {
    const m = /^\|\s*(\d+)\s*\|/.exec(line);
    if (!m) continue;
    const parts = line.split('|');
    const cells = parts.slice(1, parts.length - 1).map((s) => s.trim());
    rows.push({ no: Number(m[1]), cells, raw: line });
  }
  return rows;
}

const WAYS = new Set(['自动', '人工', '自动+人工']);
const TIERS = new Set(['A', 'B', 'C']);
const STATES = new Set(['已满足', '未满足', '待裁决']);

function langFiles(base) {
  return ['.md', '.en.md', '.zh-Hant.md', '.ja.md', '.vi.md'].map((s) => base + s);
}

/** 「孤立表格行」的 1-based 行号：以 | 开头，但上一行既非空、也不以 | 开头。 */
function orphanTableRows(text) {
  const lines = text.split('\n');
  const out = [];
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].startsWith('|')) continue;
    const prev = lines[i - 1];
    if (prev.trim() === '' || prev.startsWith('|')) continue;
    out.push(i + 1);
  }
  return out;
}

// =========================================================== 正控（先自检）===
// 扫描器是下面所有断言的地基。它要是悄悄坏了，这里会一路"全绿"——本项目被这种
// 形态咬过，所以每条探测器都先证明自己会红。

console.log('=== 上线合规门槛清单守卫 ===');
console.log('--- 探测器自检（positive control）---');

const fakeRefs = extractRefs('参见 `tool/verify_not_a_real_guard.js` 与 `landing/dist` 目录');
check(fakeRefs.has('tool/verify_not_a_real_guard.js'), '自检：幻影路径能被提取（`tool/…js`）');
check(!fakeRefs.has('landing/dist'), '自检：不带扩展名的目录引用不当成文件');

const badRows = parseRows('| 99 | x | y | 半自动 | A | 大概行了 |');
check(badRows.length === 1, '自检：表格主行能被解析（1 行）');
check(
  badRows.length === 1 && !WAYS.has(badRows[0].cells[3]),
  '自检：非词表内的「方式」值会被判出（半自动）'
);
check(
  badRows.length === 1 && !STATES.has(badRows[0].cells[5]),
  '自检：非词表内的「状态」值会被判出（大概行了）'
);

check(langFiles('__不存在的基础名__').length === 5, '自检：五语种文件名展开器输出 5 个');
check(
  orphanTableRows('段首\n\n| a | b |\n|---|---|\n| 1 | 2 |').length === 0,
  '自检：正常表格（空行后开头）不算孤立行'
);
check(
  orphanTableRows('一段正文\n| **撤回** | 提交申请 |').length === 1,
  '自检：被正文截断的表格行能被判出（1 行）'
);

// ================================================================ 读文档 ====

check(fs.existsSync(DOC), '门槛清单文件存在（lib/compliance/上线合规门槛清单.md）');

const text = fs.existsSync(DOC) ? fs.readFileSync(DOC, 'utf8') : '';
const rows = parseRows(text);

// ============================================================== 结构完整 ====

const SECTIONS = [
  ['## 0. 一分钟版', '§0 一分钟版'],
  ['## 1. 三个档位', '§1 三个档位'],
  ['## 2. 门禁表', '§2 门禁表'],
  ['## 3. 阻断判定', '§3 阻断判定'],
  ['## 4. 每次发版的复核顺序', '§4 复核顺序'],
  ['## 5. 与其它文档的关系', '§5 文档关系'],
  ['## 6. 变更记录', '§6 变更记录'],
];
for (const [needle, label] of SECTIONS) check(text.includes(needle), '结构：含 ' + label);

// ============================================================ 表格完整性 ====

check(rows.length >= 15, '门禁条数下限（实际 ' + rows.length + ' 条）');

const numbering = rows.map((r) => r.no);
const expectSeq = rows.map((_, i) => i + 1);
check(
  numbering.join(',') === expectSeq.join(','),
  '编号从 1 起连续无跳号（实际 ' + numbering.join(',') + '）'
);

const shortRow = rows.filter((r) => r.cells.length !== 6 || r.cells.some((c) => !c));
check(
  shortRow.length === 0,
  '每行 6 列且无空格（坏行=' + (shortRow.map((r) => '#' + r.no).join(' ') || '无') + '）'
);

// ============================================================ 词表封闭 ====

const badWay = rows.filter((r) => !WAYS.has(r.cells[3]));
check(
  badWay.length === 0,
  '「方式」只用 自动 / 人工 / 自动+人工（越界=' + (badWay.map((r) => '#' + r.no).join(' ') || '无') + '）'
);

const badTier = rows.filter((r) => !TIERS.has(r.cells[4]));
check(
  badTier.length === 0,
  '「档」只用 A / B / C（越界=' + (badTier.map((r) => '#' + r.no).join(' ') || '无') + '）'
);

const badState = rows.filter((r) => !STATES.has(r.cells[5]));
check(
  badState.length === 0,
  '「现状态」只用 已满足 / 未满足 / 待裁决（越界=' + (badState.map((r) => '#' + r.no).join(' ') || '无') + '）'
);

// ================================================== §0 自报数字 == 实际统计 ====
// 汇总不许手敲：§0 的每个数字都必须能从表里算出来。改表不改 §0 ⇒ 当场红。

const tally = (idx, keys) => {
  const out = {};
  for (const k of keys) out[k] = rows.filter((r) => r.cells[idx] === k).length;
  return out;
};

const wayCount = tally(3, ['自动', '人工', '自动+人工']);
const tierCount = tally(4, ['A', 'B', 'C']);
const stateCount = tally(5, ['已满足', '待裁决', '未满足']);

const mWay = /门禁 \*\*(\d+)\*\* 条：自动 \*\*(\d+)\*\* \/ 人工 \*\*(\d+)\*\* \/ 自动\+人工 \*\*(\d+)\*\*/.exec(text);
check(Boolean(mWay), '§0 含「门禁 N 条：自动 / 人工 / 自动+人工」自报行');
if (mWay) {
  check(Number(mWay[1]) === rows.length, '§0 总条数与表格行数相等（' + mWay[1] + ' vs ' + rows.length + '）');
  check(
    Number(mWay[2]) === wayCount['自动'] &&
      Number(mWay[3]) === wayCount['人工'] &&
      Number(mWay[4]) === wayCount['自动+人工'],
    '§0 方式分布与表格相等（自报 ' +
      [mWay[2], mWay[3], mWay[4]].join('/') +
      '，实际 ' +
      [wayCount['自动'], wayCount['人工'], wayCount['自动+人工']].join('/') +
      '）'
  );
}

const mTier = /档位：A \*\*(\d+)\*\* \/ B \*\*(\d+)\*\* \/ C \*\*(\d+)\*\*/.exec(text);
check(Boolean(mTier), '§0 含「档位：A / B / C」自报行');
if (mTier) {
  check(
    Number(mTier[1]) === tierCount['A'] &&
      Number(mTier[2]) === tierCount['B'] &&
      Number(mTier[3]) === tierCount['C'],
    '§0 档位分布与表格相等（自报 ' +
      [mTier[1], mTier[2], mTier[3]].join('/') +
      '，实际 ' +
      [tierCount['A'], tierCount['B'], tierCount['C']].join('/') +
      '）'
  );
}

const mState = /状态：已满足 \*\*(\d+)\*\* \/ 待裁决 \*\*(\d+)\*\* \/ 未满足 \*\*(\d+)\*\*/.exec(text);
check(Boolean(mState), '§0 含「状态：已满足 / 待裁决 / 未满足」自报行');
if (mState) {
  check(
    Number(mState[1]) === stateCount['已满足'] &&
      Number(mState[2]) === stateCount['待裁决'] &&
      Number(mState[3]) === stateCount['未满足'],
    '§0 状态分布与表格相等（自报 ' +
      [mState[1], mState[2], mState[3]].join('/') +
      '，实际 ' +
      [stateCount['已满足'], stateCount['待裁决'], stateCount['未满足']].join('/') +
      '）'
  );
  check(
    Number(mState[1]) + Number(mState[2]) + Number(mState[3]) === rows.length,
    '§0 状态三项之和 == 总条数（防"少算一条"）'
  );
}

// ============================================== 判据列不许是空话（最小长度）====

const thin = rows.filter((r) => r.cells[2].length < 12);
check(
  thin.length === 0,
  '每行判据非空话（≥12 字，可疑=' + (thin.map((r) => '#' + r.no).join(' ') || '无') + '）'
);

// =========================================== 文中引用的证据文件必须真实存在 ====

const refs = [...extractRefs(text)].sort();
check(refs.length >= 6, '文中引用的证据文件数量下限（实际 ' + refs.length + ' 个）');

const phantom = refs.filter((r) => !fs.existsSync(path.join(ROOT, r)));
check(
  phantom.length === 0,
  '零幻影证据：引用的路径全部真实存在（不存在=' + (phantom.join(' ') || '无') + '）'
);

// ============================================ 五语种合规文档 15 份真的在盘 ====

let langMissing = [];
for (const base of ['服务条款', '隐私政策', '年龄门槛']) {
  for (const f of langFiles(base)) {
    if (!fs.existsSync(path.join(COMPLIANCE, f))) langMissing.push(f);
  }
}
check(
  langMissing.length === 0,
  '五语种合规文档 15 份齐（缺=' + (langMissing.join(' ') || '无') + '）'
);

// 表格不许被正文截断（0.116.0 实证：隐私政策 §5 五语种同时踩中）。
const orphanHits = [];
for (const base of ['服务条款', '隐私政策', '年龄门槛']) {
  for (const f of langFiles(base)) {
    const fp = path.join(COMPLIANCE, f);
    if (!fs.existsSync(fp)) continue;
    const at = orphanTableRows(fs.readFileSync(fp, 'utf8'));
    if (at.length) orphanHits.push(f + ' L' + at.join(',L'));
  }
}
check(
  orphanHits.length === 0,
  '五语种合规文档零孤立表格行（可疑=' + (orphanHits.join(' ') || '无') + '）'
);

// ================================================= 阻断判定必须三档都说清 ====

const blockIdx = text.indexOf('## 3. 阻断判定');
const blockEnd = text.indexOf('## 4. 每次发版的复核顺序');
const blockText = blockIdx >= 0 && blockEnd > blockIdx ? text.slice(blockIdx, blockEnd) : '';
check(/A 档任一行不是「已满足」/.test(blockText), '§3 写明 A 档阻断（不许出任何产物）');
check(/B 档任一行不是「已满足」/.test(blockText), '§3 写明 B 档阻断（不许对外宣称 / 上架）');
check(/C 档任一行不是「已满足」/.test(blockText), '§3 写明 C 档阻断（不许收费）');
check(/「待裁决」不等于「已满足」/.test(blockText), '§3 写明「待裁决 ≠ 已满足」');
check(/没有读数.*不等于.*通过/.test(blockText), '§3 写明「没有读数 ≠ 通过」');

// ================================================================ 汇总 =====

console.log('');
console.log('--- 盘点（供参考，非断言）---');
console.log('  门禁 ' + rows.length + ' 条；自动 ' + wayCount['自动'] + ' / 人工 ' + wayCount['人工'] + ' / 自动+人工 ' + wayCount['自动+人工']);
console.log('  档位 A ' + tierCount['A'] + ' / B ' + tierCount['B'] + ' / C ' + tierCount['C']);
console.log('  状态 已满足 ' + stateCount['已满足'] + ' / 待裁决 ' + stateCount['待裁决'] + ' / 未满足 ' + stateCount['未满足']);
console.log('  引用证据文件 ' + refs.length + ' 个');

console.log('');
console.log('================ 上线合规门槛清单校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
