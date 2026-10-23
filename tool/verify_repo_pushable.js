#!/usr/bin/env node
// ============================================================
// 守卫：**仓库可推**（把 R46 的判据钉成脚本）
//
// 为什么单独一个守卫：2026-10-21 实测，仓库「看着完全正常」——
//   `git log -1` 有输出、`git archive HEAD` 正常（15,820,800 B）、四关全绿、
//   `git status` 干净 —— 但 `git pack-objects` 直接 rc=128：
//   历史最底部的提交引用了 5 个**已丢失**的对象 ⇒ **推不上去**。
//   这类缺口不会让任何一条现有判据变红（它们全读文件，不读对象图），
//   只会在真正 push 的那一刻爆炸 ⇒ 必须有一条专门盯着对象图的守卫。
//
// 判据：
//   ① `echo main | git pack-objects --revs --stdout` rc=0（= 可推）
//   ② `git fsck --connectivity-only` 无 broken link
//   ③ 历史最底部那个提交的快照能完整展开（`ls-tree -r` 不缺子树）
//   ④ HEAD 的快照能完整展开
//
// 用法：node tool/verify_repo_pushable.js
// ============================================================
'use strict';

const cp = require('child_process');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');

function git(args, opts) {
  return cp.spawnSync('git', args, Object.assign({ cwd: ROOT, encoding: 'utf8' }, opts || {}));
}

// ── 纯函数（可被负控直接喂脏输入） ──
function pushable(rc) { return rc === 0; }
function hasBrokenLink(text) { return /broken link/.test(String(text || '')); }
function missingFromList(errText) {
  // ls-tree 遇缺子树报 "error: Could not read <oid>"
  const m = String(errText || '').match(/Could not read ([0-9a-f]{40})/g) || [];
  return m.length;
}

let pass = 0, fail = 0;
function ok(name, cond, detail) {
  if (cond) { pass += 1; console.log('  PASS  ' + name + (detail ? ' :: ' + detail : '')); }
  else { fail += 1; console.log('  FAIL  ' + name + (detail ? ' :: ' + detail : '')); }
}

console.log('=== 仓库可推（对象图完整性）===');

// ① 可打包 = 可推（stdout 直接丢弃，pack 可能有几十 MB）
const pack = git(['pack-objects', '--revs', '--stdout'], { input: 'main\n', stdio: ['pipe', 'ignore', 'pipe'] });
ok('① ★ main 能完整打包（rc=0 才推得上去）', pushable(pack.status), 'rc=' + pack.status);

// ② fsck 无断链
const fsck = git(['fsck', '--connectivity-only'], { stdio: ['pipe', 'pipe', 'pipe'] });
ok('② ★ 对象图无 broken link', !hasBrokenLink(fsck.stderr + fsck.stdout),
  hasBrokenLink(fsck.stderr + fsck.stdout) ? '有断链' : 'clean');

// ③ 最底部提交的快照完整
const log = git(['log', '--format=%H', 'main'], { stdio: ['pipe', 'pipe', 'pipe'] });
const tips = String(log.stdout || '').split('\n').map((x) => x.trim()).filter(Boolean);
const oldest = tips[tips.length - 1];
const oldestTree = git(['ls-tree', '-r', oldest], { stdio: ['pipe', 'pipe', 'pipe'] });
ok('③ ★ 历史最底部的快照能完整展开（缺子树 = 推不出去）',
  oldestTree.status === 0 && missingFromList(oldestTree.stderr) === 0,
  (oldest || '?').slice(0, 10) + ' rc=' + oldestTree.status + ' 缺 ' + missingFromList(oldestTree.stderr));

// ④ HEAD 快照完整
const headTree = git(['ls-tree', '-r', 'HEAD'], { stdio: ['pipe', 'pipe', 'pipe'] });
ok('④ HEAD 快照能完整展开', headTree.status === 0 && missingFromList(headTree.stderr) === 0,
  'rc=' + headTree.status);

// ── 负控（判据必须能红，否则等于没装） ──
ok('自检①：rc=128 必须判为不可推', pushable(128) === false);
ok('自检②：fsck 输出里出现 broken link 必须被抓到',
  hasBrokenLink('broken link from commit aaaa to commit bbbb') === true);
ok('自检③：ls-tree 报 "Could not read <oid>" 必须被数出来',
  missingFromList('error: Could not read c8aacfc2336dac30b9c51d09db306c2990d60903') === 1);

console.log('\n================ 仓库可推：' + pass + ' PASS / ' + fail + ' FAIL ================');
process.exit(fail ? 1 : 0);
