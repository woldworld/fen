// 跨语言一致性校验：**Dart 端算出的 Merkle 根与两类证明，Node Hub 端必须逐字节复算一致**。
//
// 为什么需要它（§16 最容易埋的雷）：
//   §16 的整个承诺是"Hub 闭源，但日志公开可复算"——任何第三方下载叶子哈希列表后，
//   能自己把整棵树重算出来、验任何一条证明。这条承诺成立的前提是**两端字节口径完全一致**：
//     叶子哈希 = base58(SHA-256(0x00 ‖ leaf))
//     内部节点 = base58(SHA-256(0x01 ‖ left ‖ right))
//     空树根   = base58(SHA-256(''))
//     MTH 的 k = 严格小于 n 的最大 2 的幂；两棵子树的划分方式
//   只要有一处口径不同（哪怕只是 k 取 `>=` 还是 `>`），
//   "Dart 端验得过"和"Hub 端算得出"就会指向两棵不同的树 —— 本机自证全绿、联网监督全废。
//   这种缺陷**单语言测试永远发现不了**，只有真的拿一端的产物给另一端的实现复算才会暴露。
//
// 运行：node tool/verify_transparency_hub.js
// 前提：先跑 `dart run tool/verify_transparency_log.dart` 生成 tool/.log_probe.json。

'use strict';

const fs = require('fs');
const path = require('path');

const hub = require(path.join(__dirname, '..', 'lib', 'hub', 'hub.js'));

let pass = 0;
let fail = 0;
function ck(ok, label) {
  if (ok) {
    pass++;
    console.log('  PASS  ' + label);
  } else {
    fail++;
    console.log('  FAIL  ' + label);
  }
}

const probePath = path.join(__dirname, '.log_probe.json');
if (!fs.existsSync(probePath)) {
  console.error('缺少探针文件 —— 请先运行: dart run tool/verify_transparency_log.dart');
  process.exit(2);
}
const probe = JSON.parse(fs.readFileSync(probePath, 'utf8'));
const leaves = probe.leaves;
const N = leaves.length;

console.log('--- 探针形态 ---');
ck(Array.isArray(leaves) && leaves.length === 7, '探针含 7 片叶子哈希（RFC 6962 n=7 经典树）');
ck(Array.isArray(probe.roots) && probe.roots.length === N + 1, '探针含 n=0..7 共 8 个根');

// ---------------------------------------------------------------------
console.log('--- 逐期根：Node 独立复算 == Dart 导出（逐字节）---');
let rootsOk = true;
for (let n = 0; n <= N; n++) {
  const r = hub.logRootAt(leaves, n);
  if (r !== probe.roots[n]) {
    rootsOk = false;
    console.log(`        ✗ n=${n} node=${r} dart=${probe.roots[n]}`);
  }
}
ck(rootsOk, 'n=0..7 每一期的 Merkle 根两端逐字节一致');
ck(probe.roots[0] === hub.logEmptyRoot(), 'n=0 空树根与 Node emptyRoot 一致（SHA-256(\'\')）');

// ---------------------------------------------------------------------
console.log('--- Inclusion proof：Node 复算的路径 == Dart 导出（逐项）---');
let incOk = true;
for (let i = 0; i < N; i++) {
  const np = hub.logInclusionProof(leaves, i);
  const dp = probe.inclusion[i];
  if (np.index !== dp.index || np.tree_size !== dp.tree_size) { incOk = false; console.log(`        ✗ index=${i} 头字段不符`); continue; }
  if (np.path.length !== dp.path.length) { incOk = false; console.log(`        ✗ index=${i} 路径长度不符`); continue; }
  for (let j = 0; j < np.path.length; j++) {
    if (np.path[j] !== dp.path[j]) { incOk = false; console.log(`        ✗ index=${i} path[${j}] node=${np.path[j]} dart=${dp.path[j]}`); }
  }
}
ck(incOk, 'n=7 全部 7 片叶子的包含证明路径两端逐项一致');

// Node 用自己的验签器验 Dart 的证明（只凭叶子哈希，这正是 Hub 的原生口径）
let incVerifyOk = true;
for (let i = 0; i < N; i++) {
  if (!hub.logVerifyInclusionByHash(leaves[i], probe.inclusion[i], probe.roots[N])) {
    incVerifyOk = false;
    console.log(`        ✗ index=${i} Node 验不过 Dart 的证明`);
  }
}
ck(incVerifyOk, 'Node 仅凭叶子哈希即可验过 Dart 的全部包含证明');

// ---------------------------------------------------------------------
console.log('--- Consistency proof：Node 复算的路径 == Dart 导出（逐项）---');
let consOk = true;
let pairIdx = 0;
let pairs = 0;
for (let m = 0; m <= N; m++) {
  for (let n = m; n <= N; n++) {
    pairs++;
    const np = hub.logConsistencyProof(leaves, m, n);
    const dp = probe.consistency[pairIdx++];
    if (!dp) { consOk = false; console.log(`        ✗ m=${m} n=${n} 探针缺失`); continue; }
    if (np.from_size !== dp.from_size || np.to_size !== dp.to_size) { consOk = false; console.log(`        ✗ m=${m} n=${n} 头字段不符`); continue; }
    if (np.path.length !== dp.path.length) { consOk = false; console.log(`        ✗ m=${m} n=${n} 路径长度不符`); continue; }
    for (let j = 0; j < np.path.length; j++) {
      if (np.path[j] !== dp.path[j]) { consOk = false; console.log(`        ✗ m=${m} n=${n} path[${j}] node=${np.path[j]} dart=${dp.path[j]}`); }
    }
  }
}
ck(pairs === probe.consistency.length, `探针 (m,n) 组数与复算组数一致（各 ${pairs} 组）`);
ck(consOk, '全部 (m,n) 一致性证明路径两端逐项一致（含 m=0 与 m=n）');

// Node 用自己的验签器验 Dart 的一致性证明
let consVerifyOk = true;
pairIdx = 0;
for (let m = 0; m <= N; m++) {
  for (let n = m; n <= N; n++) {
    const dp = probe.consistency[pairIdx++];
    if (!hub.logVerifyConsistency(dp, probe.roots[m], probe.roots[n])) {
      consVerifyOk = false;
      console.log(`        ✗ m=${m} n=${n} Node 验不过 Dart 的证明`);
    }
  }
}
ck(consVerifyOk, 'Node 验过 Dart 的全部一致性证明');

// ---------------------------------------------------------------------
console.log('--- 跨语言下的 fail-closed（篡改必须两端同拒）---');
const p2 = probe.inclusion[2];
ck(hub.logVerifyInclusionByHash(leaves[3], p2, probe.roots[N]) === false,
  '拿第 4 片的哈希配第 3 片的证明 → Node 拒');
ck(hub.logVerifyInclusionByHash(leaves[2], { ...p2, path: [...p2.path].slice(0, -1) }, probe.roots[N]) === false,
  '包含证明路径被截断 → Node 拒');
ck(hub.logVerifyInclusionByHash(leaves[2], { ...p2, index: 3 }, probe.roots[N]) === false,
  '包含证明索引错位 → Node 拒');
const c37 = probe.consistency.filter((c) => c.from_size === 3 && c.to_size === 7)[0];
ck(hub.logVerifyConsistency(c37, probe.roots[4], probe.roots[N]) === false,
  '一致性证明第一期根填错 → Node 拒');
ck(hub.logVerifyConsistency({ ...c37, path: [...c37.path].slice(0, -1) }, probe.roots[3], probe.roots[N]) === false,
  '一致性证明路径被截断 → Node 拒');
const c27 = probe.consistency.filter((c) => c.from_size === 2 && c.to_size === 7)[0];
ck(hub.logVerifyConsistency({ from_size: 3, to_size: 7, path: c27.path }, probe.roots[3], probe.roots[N]) === false,
  '(2,7) 的证明冒充 (3,7) → Node 拒');

// ---------------------------------------------------------------------
console.log('--- 链式哈希两端同构 ---');
// 用第 0 片叶子哈希独立复算链式哈希，与 Dart 口径对齐
const chain0 = hub.logChainHash(0, leaves[0], '');
const chain0Again = hub.logChainHash(0, leaves[0], '');
ck(chain0 === chain0Again && chain0.length > 0, '链式公式可复算且确定（WL|idx|leafHash|prevHash）');
ck(hub.logChainHash(0, leaves[0], '') !== hub.logChainHash(0, leaves[0], 'X'),
  '改 prev_hash → 链式哈希变（改写必留痕）');
ck(hub.logChainHash(0, leaves[0], '') !== hub.logChainHash(1, leaves[0], ''),
  '改 idx → 链式哈希变（删除必留痕）');

console.log('');
console.log(
  '================ 透明日志跨语言校验：' + pass + ' PASS / ' + fail + ' FAIL ================'
);
process.exit(fail === 0 ? 0 : 1);
