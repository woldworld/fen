// 跨语言一致性校验：**Dart 端签的清单，Node Hub 端必须验得过**。
//
// 为什么需要它（M9 最容易埋的雷）：
//   两端各自把上架清单拼成"确定性签名载荷"（canonical JSON）再验签。
//   Dart 的 `jsonEncode` 与 JS 的 `JSON.stringify` 都产出无空格 JSON，但**键序**
//   取决于插入顺序。键序一旦不同，同一条清单两端算出的载荷就不同 ——
//   结果是"作者在自己设备上签得好好的，一提交到 Hub 就被判签名无效"。
//   这种缺陷**单语言测试永远发现不了**，只有真的拿一端的签给另一端验才会暴露。
//
// 运行：node tool/verify_skill_hub.js
// 前提：先跑 `dart run tool/verify_skill_registry.dart` 生成两个探针文件。

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

const listingPath = path.join(__dirname, '_m9_signed_listing.json');
const canonPath = path.join(__dirname, '_m9_canonical.txt');

if (!fs.existsSync(listingPath) || !fs.existsSync(canonPath)) {
  console.error('缺少探针文件 —— 请先运行: dart run tool/verify_skill_registry.dart');
  process.exit(2);
}

const listing = JSON.parse(fs.readFileSync(listingPath, 'utf8'));
const dartCanonical = fs.readFileSync(canonPath, 'utf8');

console.log('--- Dart 签的清单 → Node 验 ---');
ck(typeof listing.sig === 'string' && listing.sig.length > 0, '探针清单带签名');
ck(hub.skillSigValid(listing) === true, 'Node 验签：Dart 签的清单验得过');

// 两端 canonical 必须**逐字节**一致（这才是根因层的检查）
ck(
  hub.skillCanonical(listing) === dartCanonical,
  'canonical 载荷逐字节一致（Dart jsonEncode ↔ Node JSON.stringify）'
);

console.log('--- 跨语言下的 fail-closed ---');
ck(hub.skillSigValid({ ...listing, price_cents: Number(listing.price_cents) + 1 }) === false,
  '改价后 Node 也验不过');
ck(hub.skillSigValid({ ...listing, content_hash: 'TAMPERED' }) === false,
  '换内容哈希后 Node 也验不过');
ck(hub.skillSigValid({ ...listing, sig: '' }) === false, '无签名 → 拒');
ck(hub.skillSigValid({ ...listing, author_pub: 'abc' }) === false, '坏公钥 → 拒');

console.log('--- 上架判定两端同构 ---');
const existing = [{ ...listing, version: '1.0.0' }];
ck(hub.skillPublishDecision({ ...listing, version: '1.0.0' }, existing).code === 'duplicate',
  '同版本同内容 → duplicate');
ck(
  hub.skillPublishDecision({ ...listing, version: '1.0.0', content_hash: 'X' }, existing).code ===
    'version_conflict',
  '同版本换内容 → version_conflict'
);
ck(
  hub.skillPublishDecision({ ...listing, version: '0.9.0' }, existing).code ===
    'version_not_increased',
  '版本倒退 → version_not_increased'
);
ck(hub.skillPublishDecision({ ...listing, version: '1.0.1' }, existing).code === 'accepted',
  '版本前进 → accepted');
ck(hub.compareSkillVersion('1.2.10', '1.2.9') > 0, '版本比较与 Dart 同口径');

console.log('');
console.log(
  '================ Node 侧跨语言校验：' + pass + ' PASS / ' + fail + ' FAIL ================'
);
process.exit(fail === 0 ? 0 : 1);
