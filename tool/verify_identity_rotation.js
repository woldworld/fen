#!/usr/bin/env node
// 跨语言一致性校验：**Dart 端签的身份换钥，Node Hub 端必须验得过**。
//
// 为什么需要它（M9/M10 里最容易埋的雷，与 skill/roomRole 同型）：
//   两端各自把换钥声明拼成"确定性签名载荷"（canonical JSON）再验签。
//   Dart 的 `jsonEncode` 与 JS 的 `JSON.stringify` 都产出无空格 JSON，但**键序**
//   取决于插入顺序。键序一旦不同，同一条声明两端算出的载荷就不同 ——
//   结果是"用户在旧手机上签得好好的，一提交到 Hub 就被判签名无效"，
//   于是**身份永远换不过去**，而用户看到的是"恢复失败"，不是"两个键序不一样"。
//   这种缺陷**单语言测试永远发现不了**。
//
// 本脚本还验三件事，它们是"可被第三方验证"这句话的实质：
//   ① canonical 与 §16 公开叶子**逐字节**同构（不是"字段一样"，是字节一样）；
//   ② 幂等键同构（一把旧钥只能退休一次）；
//   ③ 拒绝路径在 Node 侧复算出的码与 Dart 侧逐一相同 —— 尤其
//      ★ **重放已被应用的换钥 → not_current_key**，这就是"旧设备当场失效"的机制。
//
// 运行：node tool/verify_identity_rotation.js
// 前提：先跑 `dart run tool/verify_identity_rotation.dart` 生成三个探针文件。

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

const signedPath = path.join(__dirname, '_identity_rotation_signed.json');
const canonPath = path.join(__dirname, '_identity_rotation_canonical.txt');
const leafPath = path.join(__dirname, '_identity_rotation_leaf.txt');

if (!fs.existsSync(signedPath) || !fs.existsSync(canonPath) || !fs.existsSync(leafPath)) {
  console.error('缺少探针文件 —— 请先运行: dart run tool/verify_identity_rotation.dart');
  process.exit(2);
}

const rot = JSON.parse(fs.readFileSync(signedPath, 'utf8'));
const dartCanonical = fs.readFileSync(canonPath, 'utf8');
const dartLeaf = fs.readFileSync(leafPath, 'utf8');
const at = Number(rot.rotated_at);

console.log('--- Dart 签的换钥声明 → Node 验 ---');
ck(typeof rot.sig === 'string' && rot.sig.length > 0, '探针声明带签名');
ck(hub.rotationSigValid(rot) === true, 'Node 验签：Dart 签的换钥声明验得过');
ck(hub.rotationVerify(rot, rot.old_pub, at).accept === true, '完整判定（verify）通过');

// 根因层检查：canonical 必须**逐字节**一致
ck(hub.rotationCanonical(rot) === dartCanonical,
  'canonical 载荷逐字节一致（Dart jsonEncode ↔ Node JSON.stringify）');

// §16 公开叶子也必须逐字节一致 —— 否则两端会算出**两棵不同的树**，
// 而"第三方复算"就变成了"各算各的"。
ck(hub.rotationLogBytes(rot).toString('utf8') === dartLeaf,
  '★ §16 公开叶子字节逐字节一致（否则两端各长出一棵不同的树）');
ck(!JSON.parse(dartLeaf).hasOwnProperty('sig'),
  '★ 公开叶子里没有签名（签名不进公开日志）');

// 叶子哈希与幂等键
ck(typeof hub.rotationLeafHashOf(rot) === 'string' && hub.rotationLeafHashOf(rot).length > 0,
  'Node 能复算 §16 叶子哈希');
ck(hub.rotationKeyOf(rot.agent_id, rot.old_pub) === rot.agent_id + '|' + rot.old_pub,
  '幂等键格式与 Dart 侧同构（agent_id|old_pub）');

console.log('--- 跨语言下的 fail-closed ---');
ck(hub.rotationVerify({ ...rot, sig: '' }, rot.old_pub, at).code === 'missing_fields',
  '无签名 → missing_fields');
ck(hub.rotationVerify({ ...rot, old_pub: 'abc' }, 'abc', at).code === 'bad_pubkey',
  '坏公钥 → bad_pubkey');
ck(hub.rotationVerify({ ...rot, new_pub: rot.old_pub }, rot.old_pub, at).code === 'noop_rotation',
  '换到自己身上 → noop_rotation');
// ⚠️ 篡改必须用**格式合法**的第三把钥，否则会先撞上 bad_pubkey（廉价检查在前），
//    验的就成了坏公钥而不是签名 —— 那样这条断言就是假绿。
const thirdPub = hub.base58Encode(Buffer.from(Array.from({ length: 32 }, (_, i) => (i * 7 + 3) & 0xff)));
ck(hub.rotationVerify({ ...rot, new_pub: thirdPub }, rot.old_pub, at).code === 'bad_signature',
  '改 new_pub（换成另一把**合法**公钥）后 Node 也验不过（bad_signature）');
ck(hub.rotationVerify({ ...rot, agent_id: 'AG-TAMPERED' }, rot.old_pub, at).code === 'bad_signature',
  '改身份后 Node 也验不过');
ck(hub.rotationVerify({ ...rot, rotated_at: at + 1 }, rot.old_pub, at + 1).code === 'bad_signature',
  '改时间后 Node 也验不过');
ck(hub.rotationVerify(rot, rot.old_pub, at + hub.ROTATION_MAX_SKEW_MS + 1).code === 'stale_rotation',
  '超出时钟偏移窗口 → stale_rotation');

console.log('--- ★ 旧设备失效：旧钥退休后重放同一条声明 ---');
ck(hub.rotationVerify(rot, rot.new_pub, at).code === 'not_current_key',
  '★ 已应用的换钥被重放 → not_current_key（旧钥在任何地方都失效）');
ck(hub.rotationVerify(rot, '', at).code === 'not_current_key',
  '未登记的身份不能被"换钥"出来');

console.log('--- 端点已挂上 ---');
const hubSrc = fs.readFileSync(path.join(__dirname, '..', 'lib', 'hub', 'hub.js'), 'utf8');
ck(hubSrc.includes("'/api/identity/rotate'"), 'hub.js 注册了 POST /api/identity/rotate');
ck(/identity\/rotate[\s\S]{0,4000}agent\.pubkey = newPub/.test(hubSrc),
  '端点在通过判定后把 record.pubkey 改绑到 new_pub');
ck(/key_rotations/.test(hubSrc), '端点在 Hub 侧留下只追加的 key_rotations 记录');

console.log('--- ★ 换钥链「公开读」端点（第三方独立复核的唯一入口） ---');
ck(hubSrc.includes("'/api/identity/rotations'"),
  'hub.js 注册了 GET /api/identity/rotations');
// ★ 匿名性必须在**源码层**钉住：`authAnyRegistered` 一旦被写进去，
//   "任何人都能查"就退回成"只有自己人能查"，而这句话恰恰是整个可监督性的前提。
//   取路由体（从该端点起、到下一个路由注释止）再断言其中**没有**鉴权调用。
const routeBody = hubSrc.slice(
  hubSrc.indexOf("'/api/identity/rotations'"),
  hubSrc.indexOf('// 发送：把消息投递到对方邮箱'));
ck(routeBody.length > 0 && !/authAnyRegistered/.test(routeBody),
  '★ 该路由体里**没有** authAnyRegistered —— 匿名可读是结构性的，不是口头承诺');
ck(/chain_links_ok/.test(routeBody) && /broken_agents/.test(routeBody),
  '路由对链的**拼接关系**做检查并报出涉及身份（改坏链必须显形）');
ck(/tip_not_active/.test(routeBody),
  '路由检查"链末端是否仍等于当前活跃钥"（漏记一次换钥也会显形）');
// ★ 锚点纪律（v0.33.0 踩到）：这里要钉的是「响应里带着 §16 当前根」这件**事**，
//   而不是某个具体表达式。P1-5 把 `logRootAt(logLeafHashes(...))` 换成
//   `logRootCached(size)`（加缓存）之后，**行为一点没变**（root 照旧随响应返回），
//   但锚在字面量上的断言会**假红** —— 红的原因只是源码那串字变了。
//   ★★ 守卫的锚点错了比没有守卫更糟：它会逼后来的人去删守卫。
//   故改为双条件：`root:` 字段在 + 取值来自某个求根函数（直算或缓存都算）。
ck(/root:/.test(routeBody) && /logRootAt\(|logRootCached\(/.test(routeBody),
  '路由随响应给出 §16 当前根（第三方据此对公开日志做一致性证明）');
// ⚠️ 反向断言：Hub **不得**在响应里对签名下结论（那样就成了"本店自查"）。
//   它只能交出 `sig`，由读的人用协议包自己验。
ck(!/sig_ok|sigValid|sig_valid/.test(routeBody),
  '★ 响应不下"签名是否有效"的结论（只交原始 sig，验证是读的人自己的事）');

console.log('');
console.log('================ 身份换钥跨语言一致性：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
