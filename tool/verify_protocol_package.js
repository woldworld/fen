'use strict';

// ============================================================================
// `@woldworld/protocol`（packages/protocol）抽取后的**结构校验**。
//
// 为什么需要这一关：把协议算法从 hub.js / world.js 搬进包，最容易出的错不是
// 算错，而是"**悄悄搬留下第二份实现**" —— 某个函数在两处都存在，于是又回到
// 两端各写一份、迟早漂移的老路。跨语言校验（verify_*_hub.js）只能发现"算得不一样"，
// 发现不了"还没搬完"。
//
// 所以本脚本查的是**结构**：
//   ① 包本身零依赖、能被 require、导出面完整；
//   ② hub.js / world.js / 部署探针里**不再有**任何协议实现（源文本断言）；
//   ③ 它们导出的协议函数与包内**是同一个函数对象**（同一性，而非"结果恰好相等"）；
//   ④ make-package.ps1 真的把包打进了一键部署包。
//
// 运行：node tool/verify_protocol_package.js
// ============================================================================

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const PKG_DIR = path.join(ROOT, 'packages', 'protocol');
const read = (rel) => fs.readFileSync(path.join(ROOT, rel), 'utf8');

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

const pkgSrc = (f) => fs.readFileSync(path.join(PKG_DIR, 'src', f), 'utf8');

// ---------------------------------------------------------------- ① 包结构
console.log('--- ① 包结构（零依赖 / 可 require / 导出面） ---');

const pkgJson = JSON.parse(fs.readFileSync(path.join(PKG_DIR, 'package.json'), 'utf8'));
ck(pkgJson.name === '@woldworld/protocol', 'package.json name = @woldworld/protocol（作用域已注册）');
ck(/^\d+\.\d+\.\d+/.test(pkgJson.version), 'package.json 有语义化版本号');
ck(pkgJson.license === 'MIT', '参考实现是 MIT（协议包 MIT / 规范文本 CC-BY-4.0 / Hub 专有）');
ck(pkgJson.main === 'src/index.js' && pkgJson.type === 'commonjs', 'main/type 指向 CommonJS 入口');
ck(!!pkgJson.types, '带 TypeScript 声明（index.d.ts）');
ck(Array.isArray(pkgJson.files) && pkgJson.files.includes('src/'), 'files 白名单只放协议层（不放 Hub 实现）');
ck(!!(pkgJson.engines && pkgJson.engines.node), '声明了 Node engines');
ck(pkgJson.dependencies === undefined || Object.keys(pkgJson.dependencies).length === 0,
  '★ 运行时零依赖（dependencies 为空或不存在）');
ck(pkgJson.scripts && /node test\/run\.js/.test(pkgJson.scripts.test), 'npm test 指向自带自检');

const srcFiles = fs.readdirSync(path.join(PKG_DIR, 'src')).filter((f) => f.endsWith('.js'));
ck(srcFiles.length >= 9, `src/ 至少 9 个模块（实际 ${srcFiles.length} 个）`);

// 只允许 require 内置模块或包内相对路径 —— 出现裸包名就是引入了依赖。
const BARE = /require\(\s*(['"])(?!\.)([^'"]+)\1\s*\)/g;
const builtins = new Set(['crypto', 'http', 'fs', 'path', 'url', 'util', 'os', 'assert', 'buffer']);
let bareDeps = [];
for (const f of srcFiles) {
  const s = pkgSrc(f);
  let m;
  while ((m = BARE.exec(s))) {
    if (!builtins.has(m[2])) bareDeps.push(f + ' -> ' + m[2]);
  }
}
ck(bareDeps.length === 0, '★ 包内只 require Node 内置模块与自身文件（无第三方依赖）' + (bareDeps.length ? '：' + bareDeps.join(', ') : ''));

// 子集优先：包只应在 src/ 内互引，不得反向依赖 lib/ 或 tool/。
ck(!/require\([^)]*(hub|world|lib\/|\/tool\/)/.test(srcFiles.map(pkgSrc).join('\n')),
  '★ 依赖方向单向：包不引用 lib/ 或 tool/（可被独立发布）');

const protocol = require(path.join(PKG_DIR, 'src', 'index.js'));
ck(typeof protocol.verifyEnvelope === 'function', '包导出 verifyEnvelope');
ck(typeof protocol.contributionVerify === 'function', '包导出 contributionVerify');
ck(typeof protocol.roomRoleVerify === 'function' && typeof protocol.roomRoleGrantDecision === 'function',
  '包导出 roomRole 校验与权威判定（M10 P1 Host 层权益）');
ck(typeof protocol.log.inclusionProof === 'function', '包导出 log 命名空间（§16）');
ck(protocol.PROTO === 'wold/1' && protocol.LEGACY_PROTO === 'pocketagent/1', '协议版本常量在包内定义');
ck(typeof protocol.did.fromPubkey === 'function' && protocol.did.fromPubkey('X') === 'did:wold:X',
  'DID 构造在包内（did:wold:<pubkey>）');

// ------------------------------------------------------- ② 服务里不再有实现
console.log('--- ② 服务里不再有协议实现（源文本断言） ---');

const REMOVED_SYMBOLS = [
  'function base58Decode',
  'function base58Encode',
  'function hmacHex',
  'function ed25519KeyFromBase58',
  'function verifyEnvelope',
  'function tsFresh',
  'function endorsementCanonical',
  'function endorsementAccept',
  'function skillCanonical',
  'function skillPublishDecision',
  'function compareSkillVersion',
  'function contributionCanonical',
  'function contributionVerify',
  'function logLeafHashOf',
  'function logRootAt',
  'function logInclusionProof',
  'function logConsistencyProof',
  'function logChainHash',
  'const B58_ALPHABET',
  'const ED25519_SPKI_PREFIX',
  'const ACCEPTED_PROTOS',
];

const hubSrc = read('lib/hub/hub.js');
const worldSrc = read('lib/hub/world.js');
const probeSrc = read('lib/hub/deploy/probe-protocol.js');

for (const [name, src] of [['lib/hub/hub.js', hubSrc], ['lib/hub/world.js', worldSrc]]) {
  const leftovers = REMOVED_SYMBOLS.filter((s) => src.includes(s));
  ck(leftovers.length === 0,
    `${name} 里没有残留的协议实现${leftovers.length ? '（残留：' + leftovers.join(' | ') + '）' : ''}`);
  ck(/loadProtocol\(\)/.test(src) && /packages\/protocol\/src\/index\.js/.test(src),
    `${name} 通过 loadProtocol() 加载协议包（含仓库路径候选）`);
  ck(/\.\/protocol\/src\/index\.js/.test(src),
    `${name} 留了一键部署包路径候选（./protocol/src/index.js）`);
}

ck(!/function base58Encode/.test(probeSrc) && !/function rawPubB58[\s\S]{0,200}export\(/.test(probeSrc),
  '部署探针不再手写 base58（改成用协议包 —— 它是"第三方实现"的样板）');
ck(/protocol\.envelope\.sign/.test(probeSrc) && /protocol\.did\.fromPubkey/.test(probeSrc),
  '部署探针用包里的 envelope.sign 与 did.fromPubkey');
ck(/packages\/protocol\/src\/index\.js/.test(probeSrc) && /'\.\.\/protocol\/src\/index\.js'/.test(probeSrc),
  '部署探针同时支持仓库路径与部署包路径');

// ------------------------------------------------- ③ 同一性：同一个函数对象
console.log('--- ③ 同一性校验（导出的是包里的那个函数，不是"另一份"） ---');

const hub = require(path.join(ROOT, 'lib', 'hub', 'hub.js'));
const IDENTICAL = [
  'base58Encode',
  'base58Decode',
  'skillCanonical',
  'skillSigValid',
  'revocationCanonical',
  'revocationSigValid',
  'skillPublishDecision',
  'compareSkillVersion',
  'endorsementCanonical',
  'endorsementSigValid',
  'endorsementRevocationCanonical',
  'endorsementRevocationSigValid',
  'endorsementAccept',
  'logEmptyRoot',
  'logLeafHashOf',
  'logChainHash',
  'logRootAt',
  'logInclusionProof',
  'logVerifyInclusion',
  'logVerifyInclusionByHash',
  'logConsistencyProof',
  'logVerifyConsistency',
  'contributionCanonical',
  'contributionLogBytes',
  'contributionLeafHashOf',
  'contributionKeyOf',
  'contributionSigValid',
  'contributionVerify',
  'roomRoleCanonical',
  'roomRoleLogBytes',
  'roomRoleLeafHashOf',
  'roomRoleKeyOf',
  'roomRoleSigValid',
  'roomRoleVerify',
  'roomRoleGrantDecision',
  'roomRoleOf',
  // 身份换钥「随人不随设备」
  'rotationCanonical',
  'rotationSigValid',
  'rotationLogBytes',
  'rotationLeafHashOf',
  'rotationKeyOf',
  'rotationVerify',
  // 身份别名（换钥链 → 同一身份的全部历史公钥）—— M6 履历随人走
  'identityKeysOf',
  // 举报工单：状态机 / 事由白名单 / 转移判定 / 审计形状 —— 客户端举报入口
  // 与服务端工单接口共用同一份实现（两端各写一份必然漂移）
  'reportCanonical',
  'reportKeyOf',
  'reportSigValid',
  'reportVerify',
  'reportIsTerminal',
  'reportTransitionDecision',
  'reportAuditRecord',
  'reportReporterViewOf',
  'reportPublicViewOf',
];
const same = IDENTICAL.filter((k) => hub[k] === protocol[k]);
ck(same.length === IDENTICAL.length,
  `★ hub.js 导出的 ${IDENTICAL.length} 个协议函数与包内是同一个函数对象（等价于"只有一份实现"）`);
// 常量表也要同源（值相等 + 是同一个对象引用）
ck(hub.CONTRIBUTION_WEIGHTS === protocol.contribution.WEIGHTS &&
  hub.CONTRIBUTION_CAPS === protocol.contribution.CAPS &&
  hub.CONTRIBUTION_KINDS === protocol.contribution.KINDS,
  '★ M10 分值/上限/类型表是包里的同一个对象（不是复制一份）');
ck(hub.CONTRIBUTION_MAX_NOTE === protocol.contribution.MAX_NOTE_CHARS &&
  hub.CONTRIBUTION_MAX_REF === protocol.contribution.MAX_REF_CHARS,
  'M10 长度上限与包内一致');
ck(hub.ROOM_ROLE_KINDS === protocol.roomRole.ROLES &&
  hub.ROOM_ROLE_HOST_LAYER === protocol.roomRole.HOST_LAYER &&
  hub.ROOM_ROLE_DEFAULT === protocol.roomRole.DEFAULT_ROLE,
  '★ M10 P1 房间角色取值表/主持层表是包里的同一个对象（不是复制一份）');
ck(hub.REPORT_REASONS === protocol.report.REASONS &&
  hub.REPORT_STATES === protocol.report.STATES &&
  hub.REPORT_TRANSITIONS === protocol.report.TRANSITIONS &&
  hub.REPORT_ACTORS === protocol.report.ACTORS,
  '★ 举报工单的事由/状态/转移表/角色表是包里的同一个对象（不是复制一份）');
ck(hub.REPORT_MAX_DETAIL_CHARS === protocol.report.MAX_DETAIL_CHARS,
  '举报附注长度上限与包内一致');
ck(typeof protocol.reportVerify === 'function' && typeof protocol.reportTransitionDecision === 'function',
  '包导出举报工单校验与状态机判定（客户端举报入口）');

// hub.js 仍然只暴露既有端点（抽取不能改变对外契约）
const ENDPOINTS = [
  '/api/register',
  '/api/send',
  '/api/mailbox',
  '/api/a2a/agents',
  '/api/skills/publish',
  '/api/skills/revoke',
  '/api/reputation/endorse',
  '/api/log',
  '/api/log/leaves',
  '/api/contributions',
  // M10 P1 房间角色：读公开、写签名、附包含证明、可按房间取名册
  '/api/rooms/roles/commit',
  '/api/rooms/roles',
  '/api/rooms/roles/proof/',
  '/api/rooms/',
  // 身份换钥「随人不随设备」：旧钥签名 → 改绑活跃钥 → append-only 留痕
  '/api/identity/rotate',
];
const missingEndpoints = ENDPOINTS.filter((e) => !hubSrc.includes(`'${e}`));
ck(missingEndpoints.length === 0,
  `Hub 对外端点未变（${ENDPOINTS.length} 个${missingEndpoints.length ? '，缺：' + missingEndpoints.join(',') : ''}）`);

// ---------------------------------------------------------------- ④ 打包
console.log('--- ④ 一键部署包必须带上协议包 ---');
const mkSrc = read('lib/hub/deploy/make-package.ps1');
ck(/packages\\protocol/.test(mkSrc), 'make-package.ps1 复制 packages\\protocol');
ck(/'protocol'/.test(mkSrc) && /protoDst/.test(mkSrc), 'make-package.ps1 把包放进部署包的 protocol\\ 目录');
ck(/throw/.test(mkSrc) && /找不到协议包/.test(mkSrc),
  '★ 找不到协议包时打包**报错中止**（而不是打出一个起不来的包）');
ck(fs.readFileSync(path.join(ROOT, 'lib', 'hub', 'deploy', 'make-package.ps1')).slice(0, 3).toString('hex') === 'efbbbf',
  'make-package.ps1 带 UTF-8 BOM（PowerShell 5.1 读中文必需，否则解析直接崩）');

// ------------------------------------------------------- ⑤ §9.1 红线（包级）
console.log('--- ⑤ §9.1 红线（包级：没有任何可转让的东西） ---');
let pkgAll = srcFiles.map(pkgSrc).join('\n');
// 只查"语法上能转移价值"的形态，不查解释性文字（注释里正说明它不该存在）。
ck(!/\b(transfer|redeem|payout|sell|mint|burn)[A-Za-z_]*\s*\(/.test(pkgAll),
  '★ 包里不存在 transfer/redeem/payout/sell/mint/burn 可调用物');
ck(!/\b(balance|share|dividend|face_value|beneficiary)\b\s*[:=]/.test(pkgAll),
  '★ 包记录类型里没有余额/股份/面值/受益人字段');
ck(!/setBalance|addBalance|credit\(/.test(pkgAll), '★ 没有任何"写余额"的入口（分值是现算的）');

// ---------------------------------------------------------------- 报告
console.log('');
console.log('================ 协议包结构校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
process.exit(fail === 0 ? 0 : 1);
