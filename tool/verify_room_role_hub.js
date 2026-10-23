// 跨语言一致性校验：**Dart 端签的房间角色授予，Node Hub 端必须验得过**。
//
// 为什么需要它（M10 P1 最容易埋的雷，与 M9 同型）：
//   两端各自把角色授予拼成"确定性签名载荷"（canonical JSON）再验签。
//   Dart 的 `jsonEncode` 与 JS 的 `JSON.stringify` 都产出无空格 JSON，但**键序**
//   取决于插入顺序。键序一旦不同，同一条授予两端算出的载荷就不同 ——
//   结果是"主持人在自己设备上签得好好的，一提交到 Hub 就被判签名无效"，
//   于是屏幕上的"我是主持人"在别人眼里永远不成立。
//   这种缺陷**单语言测试永远发现不了**。
//
// 本脚本还验三件事，它们是"可被第三方验证"这句话的实质：
//   ① canonical 与 §16 公开叶子**逐字节**同构（不是"字段一样"，是字节一样）；
//   ② 幂等键同构（一个 (房间, 人) 只有一个角色）；
//   ③ 权威判定在 Node 侧复算出的码与 Dart 侧逐一相同。
//
// 运行：node tool/verify_room_role_hub.js
// 前提：先跑 `dart run tool/verify_room_role_host.dart` 生成三个探针文件。

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

const grantPath = path.join(__dirname, '_m10_role_signed_grant.json');
const canonPath = path.join(__dirname, '_m10_role_canonical.txt');
const leafPath = path.join(__dirname, '_m10_role_leaf.txt');

if (!fs.existsSync(grantPath) || !fs.existsSync(canonPath) || !fs.existsSync(leafPath)) {
  console.error('缺少探针文件 —— 请先运行: dart run tool/verify_room_role_host.dart');
  process.exit(2);
}

const grant = JSON.parse(fs.readFileSync(grantPath, 'utf8'));
const dartCanonical = fs.readFileSync(canonPath, 'utf8');
const dartLeaf = fs.readFileSync(leafPath, 'utf8');

console.log('--- Dart 签的角色授予 → Node 验 ---');
ck(typeof grant.sig === 'string' && grant.sig.length > 0, '探针授予带签名');
ck(hub.roomRoleSigValid(grant) === true, 'Node 验签：Dart 签的授予验得过');
ck(hub.roomRoleVerify(grant).ok === true, '完整校验（verify）也通过');

// 根因层检查：canonical 必须**逐字节**一致
ck(hub.roomRoleCanonical(grant) === dartCanonical,
  'canonical 载荷逐字节一致（Dart jsonEncode ↔ Node JSON.stringify）');

// §16 公开叶子也必须逐字节一致 —— 否则两端会算出**两棵不同的树**，
// 而"第三方复算"就变成了"各算各的"。
ck(hub.roomRoleLogBytes(grant).toString('utf8') === dartLeaf,
  '★ §16 公开叶子字节逐字节一致（否则两端各长出一棵不同的树）');

// 幂等键同构
ck(hub.roomRoleKeyOf(grant.room_id, grant.agent_id) === 'room|' + grant.room_id + '|' + grant.agent_id,
  '幂等键格式与 Dart 侧同构（room|roomId|agentId）');

console.log('--- 跨语言下的 fail-closed ---');
ck(hub.roomRoleVerify({ ...grant, room_id: '' }).code === 'no_room',
  '★ 抹掉房间号后 Node 也拒（no_room，先于验签）');
ck(hub.roomRoleSigValid({ ...grant, room_id: '' }) === false, '...且此时签名本身也不再成立');
ck(hub.roomRoleVerify({ ...grant, role: 'cohost' }).code === 'bad_signature',
  '改角色后 Node 也验不过（bad_signature）');
ck(hub.roomRoleVerify({ ...grant, at_ms: Number(grant.at_ms) + 1 }).code === 'bad_signature',
  '改时间后 Node 也验不过');
ck(hub.roomRoleVerify({ ...grant, sig: '' }).code === 'missing_fields', '无签名 → missing_fields');
ck(hub.roomRoleVerify({ ...grant, agent_pub: 'abc' }).code === 'bad_pubkey', '坏公钥 → 拒');
ck(hub.roomRoleVerify({ ...grant, role: 'admin' }).code === 'bad_role', '自创角色 → bad_role');

console.log('--- 公开叶子只关于公钥（隐私口径两端一致） ---');
const leafObj = JSON.parse(hub.roomRoleLogBytes(grant).toString('utf8'));
ck(!('agent_id' in leafObj) && !('granted_by' in leafObj),
  '★ 叶子不含人名（agent_id / granted_by）');
ck('agent_pub' in leafObj && 'granter_pub' in leafObj,
  '叶子只含公钥口径的断言');

console.log('--- 权威判定：Node 复算出的码与 Dart 侧逐一相同 ---');
const hostLayer = hub.ROOM_ROLE_HOST_LAYER;
ck(hostLayer.length === 2 && hostLayer.includes('host') && hostLayer.includes('cohost'),
  '主持层表在包里是唯一一份（Hub 只引用）');
ck(hub.ROOM_ROLE_DEFAULT === 'participant', '缺省角色 = participant');

const prior = [];
ck(hub.roomRoleGrantDecision(grant, prior).code === 'claimed',
  '空房间自封主持人 → claimed');
ck(hub.roomRoleGrantDecision({ ...grant, role: 'cohost' }, prior).code === 'not_host',
  '空房间想直接任命联合主持人 → not_host（没有主持人可任命）');
ck(hub.roomRoleGrantDecision({ ...grant, agent_id: 'bob' }, prior).code === 'not_host',
  '替别人自封主持人 → not_host');

// 房间已有主持人：再来一个自封 → host_exists；主持人任命联合主持人 → accepted
const withHost = [grant];
const secondClaim = { ...grant, agent_id: 'bob', granted_by: 'bob' };
ck(hub.roomRoleGrantDecision(secondClaim, withHost).code === 'host_exists',
  '已有主持人时再自封 → host_exists');
const appoint = { ...grant, agent_id: 'bob', role: 'cohost' };
ck(hub.roomRoleGrantDecision(appoint, withHost).code === 'accepted',
  '主持人任命联合主持人 → accepted');
// 撤掉最后一个主持层 → last_host
const stepDown = { ...grant, role: 'participant' };
ck(hub.roomRoleGrantDecision(stepDown, withHost).code === 'last_host',
  '撤掉最后一个主持层 → last_host');
ck(hub.roomRoleGrantDecision(stepDown, [grant, appoint]).code === 'accepted',
  '还有别的联合主持人时可以卸任 → accepted');

console.log('--- 铁律 1 正向表述：离开房间什么都不是 ---');
ck(hub.roomRoleOf([grant], grant.room_id, grant.agent_id) === 'host', '房间内读到 host');
ck(hub.roomRoleOf([grant], 'some-other-room', grant.agent_id) === 'participant',
  '★ 换个房间问 → participant（角色不跟账号走）');

console.log('');
console.log(
  '================ Node 侧房间角色跨语言校验：' + pass + ' PASS / ' + fail + ' FAIL ================'
);
process.exit(fail === 0 ? 0 : 1);
