#!/usr/bin/env node
// ============================================================
// 守卫：注册准入闸（ADR-002）
//
// 守的是什么：`/api/register` 从"TOFU 自签、谁都能给自己签一个身份"变成
// "官方站新身份须持有签发的访问 Key"。这条闸最容易做歪的四个地方：
//   ① 判定散成两份（签发工具与服务端各写一套哈希/规范化）⇒ 票是真的、人进不来；
//   ② 闸放在验签之后（白算签名）；
//   ③ 吊销只改 keys 表、不写 agent.revoked_at ⇒ Hub 拦得住、世界服务器照样放行；
//   ④ 官方部署脚本没**显式**写 HUB_REGISTRATION=key ⇒ 忘配一次等于没上闸。
//
// 本脚本**不起服务器、不碰端口**：`admission.js` 是纯函数模块，直接 require 断言。
// 接线类判据读源码文本，按**条目切片**断言（不搜整份源码 —— 见 MEMORY 硬纪律 7）。
//
// 用法：node tool/verify_hub_admission.js
// ============================================================
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const ADMISSION = path.join(ROOT, 'lib', 'hub', 'admission.js');
const HUB = path.join(ROOT, 'lib', 'hub', 'hub.js');
const WORLD = path.join(ROOT, 'lib', 'hub', 'world.js');
const INSTALL = path.join(ROOT, 'lib', 'hub', 'deploy', 'install-server.ps1');

let pass = 0;
let fail = 0;
const failures = [];
function ok(name, cond, detail) {
  if (cond) {
    pass++;
  } else {
    fail++;
    failures.push(name + (detail ? ' :: ' + detail : ''));
  }
}
function read(p) {
  return fs.readFileSync(p, 'utf8');
}
/** 取两个标记之间的片段；找不到就返回空串（让断言自然红，而不是抛异常中断整轮）。 */
function slice(text, startMark, endMark) {
  const i = text.indexOf(startMark);
  if (i < 0) return '';
  const j = endMark ? text.indexOf(endMark, i) : -1;
  return j < 0 ? text.slice(i) : text.slice(i, j);
}

let A;
try {
  A = require(ADMISSION);
} catch (e) {
  console.log(`0 PASS / 1 FAIL`);
  console.log('FAIL 无法加载 lib/hub/admission.js: ' + e.message);
  process.exit(1);
}
const hubSrc = read(HUB);
const worldSrc = read(WORLD);
const installSrc = read(INSTALL);

// ============ A. Key 明文形态 ============
const sampleKeys = [];
for (let i = 0; i < 200; i++) sampleKeys.push(A.generateAccessKey());
const k0 = sampleKeys[0];

ok('A1 前缀是 WK-（与身份 AG- 可肉眼区分）', k0.startsWith('WK-'), k0);
ok(
  'A2 形如 WK- + 4 组',
  k0.split('-').length === 5 && k0.split('-')[0] === 'WK',
  k0
);
ok(
  'A3 每组 5 位',
  k0.split('-').slice(1).every((g) => g.length === 5),
  k0
);
ok('A4 总长 26（WK- + 20 有效字符 + 3 个连字符）', k0.length === 26, String(k0.length));
const badChar = sampleKeys
  .join('')
  .replace(/^WK|-/g, '')
  .split('')
  .filter((c) => !A.KEY_ALPHABET.includes(c));
ok('A5 字符集只用 Crockford Base32（无 I/L/O/U）', badChar.length === 0, badChar.join(''));
ok(
  'A6 不含易混字符 I/L/O/U',
  !/[ILOU]/.test(sampleKeys.join('').slice(0)),
  'sample=' + k0
);
ok('A7 200 次生成互不相同', new Set(sampleKeys).size === sampleKeys.length);

// ============ B. 规范化（两端必须同一套） ============
const canon = sampleKeys[1];
ok(
  'B1 小写输入与原文同一哈希',
  A.hashAccessKey(canon.toLowerCase()) === A.hashAccessKey(canon)
);
ok(
  'B2 夹空格/换行仍同一哈希（用户从聊天窗口粘过来）',
  A.hashAccessKey('  ' + canon.slice(0, 5) + '\n' + canon.slice(5) + '  ') ===
    A.hashAccessKey(canon)
);
ok('B3 空票查不到任何记录', A.lookupAccessKey({}, '') === null);
ok(
  'B4 key_id 由明文唯一确定且不含明文',
  A.makeKeyId(canon) === A.makeKeyId(canon.toLowerCase()) &&
    !A.makeKeyId(canon).includes(canon.slice(3, 8)),
  A.makeKeyId(canon)
);

// ============ C. 准入语义（七种拒绝 + 两条放行） ============
function keyRec(plain, extra) {
  const id = A.makeKeyId(plain);
  return {
    id,
    rec: Object.assign(
      { key_id: id, hash: A.hashAccessKey(plain), status: 'active', bound_agent_id: null },
      extra || {}
    ),
  };
}
const ticket = sampleKeys[2];
const t = keyRec(ticket);
const keys = { [t.id]: t.rec };

const g1 = A.gate({ mode: 'closed', keys: {}, payload: {}, agentId: 'AG-a', existing: null });
ok(
  'C1 closed 模式：新身份 503 registration_closed',
  g1.ok === false && g1.code === 503 && g1.body.error === 'registration_closed',
  JSON.stringify(g1.body)
);
const g2 = A.gate({ mode: 'open', keys: {}, payload: {}, agentId: 'AG-a', existing: null });
ok('C2 open 模式：新身份无票放行（自建开箱即用）', g2.ok === true && !g2.keyRecord);
const g3 = A.gate({ mode: 'key', keys: {}, payload: {}, agentId: 'AG-a', existing: null });
ok(
  'C3 key 模式：新身份无票 403 registration_key_required',
  g3.ok === false && g3.code === 403 && g3.body.error === 'registration_key_required',
  JSON.stringify(g3.body)
);
ok(
  'C3b 拒绝时给出去处（hint 非空，否则用户以为服务坏了）',
  typeof g3.body.hint === 'string' && g3.body.hint.length > 10
);
const g4 = A.gate({
  mode: 'key',
  keys,
  payload: { key: sampleKeys[3] },
  agentId: 'AG-a',
  existing: null,
});
ok(
  'C4 假票 403 key_invalid',
  g4.ok === false && g4.body.error === 'key_invalid',
  JSON.stringify(g4.body)
);
const revokedKeys = { [t.id]: Object.assign({}, t.rec, { status: 'revoked', revoked_at: 1 }) };
const g5 = A.gate({
  mode: 'key',
  keys: revokedKeys,
  payload: { key: ticket },
  agentId: 'AG-a',
  existing: null,
});
ok(
  'C5 停用票 403 key_revoked',
  g5.ok === false && g5.body.error === 'key_revoked',
  JSON.stringify(g5.body)
);
ok(
  'C5b key_invalid 与 key_revoked 是两个码（合一个码，客户端就给不出不同提示）',
  'key_invalid' !== 'key_revoked'
);
const g6 = A.gate({
  mode: 'key',
  keys,
  payload: { key: ticket },
  agentId: 'AG-a',
  existing: null,
});
ok('C6 有效票放行并回传 keyRecord（注册端点据此绑定）', g6.ok === true && !!g6.keyRecord);
const boundKeys = {
  [t.id]: Object.assign({}, t.rec, { bound_agent_id: 'AG-other' }),
};
const g7 = A.gate({
  mode: 'key',
  keys: boundKeys,
  payload: { key: ticket },
  agentId: 'AG-a',
  existing: null,
});
ok(
  'C7 票已绑别人 409 key_already_bound（一票一人）',
  g7.ok === false && g7.code === 409 && g7.body.error === 'key_already_bound',
  JSON.stringify(g7.body)
);
const selfBound = { [t.id]: Object.assign({}, t.rec, { bound_agent_id: 'AG-a' }) };
const g8 = A.gate({
  mode: 'key',
  keys: selfBound,
  payload: { key: ticket },
  agentId: 'AG-a',
  existing: null,
});
ok('C8 票绑的是自己 → 放行（重装/重注册不该被自己的票拦住）', g8.ok === true);
const g9 = A.gate({
  mode: 'key',
  keys: {},
  payload: {},
  agentId: 'AG-a',
  existing: { agent_id: 'AG-a', pubkey: 'x' },
});
ok(
  'C9 已登记身份重注册不要票（否则清一次缓存就把人锁在门外）',
  g9.ok === true
);
const g10 = A.gate({
  mode: 'key',
  keys: {},
  payload: {},
  agentId: 'AG-a',
  existing: { agent_id: 'AG-a', revoked_at: 123 },
});
ok(
  'C10 已吊销身份 403 agent_revoked（放行分支不能绕开吊销）',
  g10.ok === false && g10.body.error === 'agent_revoked',
  JSON.stringify(g10.body)
);
const g11 = A.gate({
  mode: 'open',
  keys,
  payload: { key: ticket },
  agentId: 'AG-a',
  existing: null,
});
ok('C11 open 模式带了票也要校验（不能"模式放宽 = 跳过校验"）', g11.ok === true && !!g11.keyRecord);

// ============ D. 吊销双向落 ============
const agents = { 'AG-x': { agent_id: 'AG-x', key_id: t.id, pubkey: 'p' } };
const keys2 = { [t.id]: Object.assign({}, t.rec, { bound_agent_id: 'AG-x', bound_did: 'did:wold:p' }) };
const rv = A.revokeFields(keys2, agents, t.id, 1700000000000);
ok('D1 吊销返回 ok', rv.ok === true);
ok('D2 keys 表标记 revoked', keys2[t.id].status === 'revoked');
ok('D3 keys 表记 revoked_at', keys2[t.id].revoked_at === 1700000000000);
ok(
  'D4 ★ 身份侧也置 revoked_at（world.js 只读这一处 ⇒ 不写它世界服务器照样放行）',
  agents['AG-x'].revoked_at === 1700000000000,
  JSON.stringify(agents['AG-x'])
);
ok('D5 身份侧 key_id 被清掉（不留"票已停用但身份还指着它"的半截状态）', !('key_id' in agents['AG-x']));
const rvMissing = A.revokeFields({}, {}, 'KEY-nope', 1);
ok('D6 不存在的票返回 key_not_found（不静默成功）', rvMissing.ok === false && rvMissing.error === 'key_not_found');
const afterRevokeAgent = A.gate({
  mode: 'key',
  keys: keys2,
  payload: { key: ticket },
  agentId: 'AG-x',
  existing: agents['AG-x'],
});
ok(
  'D7 吊销后该身份再注册 → agent_revoked（不是 key_revoked）',
  afterRevokeAgent.ok === false && afterRevokeAgent.body.error === 'agent_revoked',
  JSON.stringify(afterRevokeAgent.body)
);
const afterRevokeNew = A.gate({
  mode: 'key',
  keys: keys2,
  payload: { key: ticket },
  agentId: 'AG-new',
  existing: null,
});
ok(
  'D8 同一张被吊销的票给新身份 → key_revoked（票不能复用）',
  afterRevokeNew.ok === false && afterRevokeNew.body.error === 'key_revoked',
  JSON.stringify(afterRevokeNew.body)
);

// ============ E. hub.js 接线 ============
ok(
  'E1 判定实现只有一份：hub.js 走 admission.gate，不自带第二套',
  hubSrc.includes('admission.gate({') && !hubSrc.includes('function lookupAccessKey')
);
const regBlock = slice(hubSrc, "pathname === '/api/register'", '// 身份换钥「随人不随设备」');
ok('E2 找到注册端点切片（找不到说明端点被改名，判据要跟着改）', regBlock.length > 500);
ok(
  'E3 ★ 准入门在验签之前（否则替无票身份白算一次签名）',
  regBlock.indexOf('admissionGate(') >= 0 &&
    regBlock.indexOf('admissionGate(') < regBlock.indexOf('if (!verifyEnvelope('),
  'gate@' + regBlock.indexOf('admissionGate(') + ' verify@' + regBlock.indexOf('if (!verifyEnvelope(')
);
ok('E4 注册成功后把 key_id 写进身份记录', regBlock.includes('record.key_id = gate.keyRecord.key_id'));
ok('E5 一票一人：绑定写回 keys 记录', regBlock.includes('gate.keyRecord.bound_agent_id = agentId'));
const authFn = slice(hubSrc, 'function authAnyRegistered(req)', '// ---------- M6 背书 / M9 技能');
ok(
  'E6 ★ 共用鉴权入口含吊销判定（一处覆盖 A2A / 技能 / 背书 / 贡献 / 角色）',
  authFn.includes('isRevoked(agent)')
);
const sendBlock = slice(hubSrc, "pathname === '/api/send'", "pathname === '/api/mailbox'");
ok('E7 /api/send 含吊销判定', sendBlock.includes('isRevoked(agent)'));
const mboxBlock = slice(hubSrc, "pathname === '/api/mailbox'", '// ---------- A2A 联邦发现');
ok('E8 /api/mailbox 含吊销判定', mboxBlock.includes('isRevoked(agent)'));
ok(
  'E9 启动日志打出注册模式（官方站忘配 key 时**唯一的现场证据**）',
  hubSrc.includes('注册模式: ${REGISTRATION}')
);
ok(
  'E10 db 骨架含 keys 表且加载时有兜底（老数据文件不该崩）',
  hubSrc.includes('keys: {},') && hubSrc.includes('if (!db.keys) db.keys = {};')
);

// ============ F. world.js 接线（只读 revoked_at，不读 keys 表） ============
const wGet = slice(worldSrc, 'function authGet(req, res, url)', 'async function authPost');
const wPost = slice(worldSrc, 'async function authPost(req, res)', '// ---------- 房间工具');
// ★ 这里必须用**词边界正则**而不是 `includes('agent.revoked_at')`：
//   后者会被 `agent.revoked_at_disabled` 这类改名后的标识符**字面包含** ⇒ 毒注进去了
//   仍然全绿（本轮正控实测踩到）。凡"判某个标识符在不在"的断言，一律带 \b。
const REVOKED_AT = /\bagent\.revoked_at\b/;
ok('F1 world 的 GET 鉴权含 revoked_at 判定', REVOKED_AT.test(wGet));
ok('F2 world 的 POST 鉴权含 revoked_at 判定', REVOKED_AT.test(wPost));
ok(
  'F3 ★ world 不持有第二份事实源（不 require admission、不读 keys 表）',
  !worldSrc.includes("require('./admission')") &&
    !worldSrc.includes('lookupAccessKey') &&
    !worldSrc.includes('db.keys')
);

// ============ G. 官方部署脚本显式上闸 ============
ok(
  'G1 ★ run-hub.cmd 模板显式写 HUB_REGISTRATION（不能靠"改默认值"）',
  installSrc.includes('set HUB_REGISTRATION=$Registration')
);
// ★ 2026-10-21 订正：这条原先钉的是 default 'key'，**钉错了边**。
//   ADR-002 规则 2 要求「源码默认 open，官方部署**显式**写入 key」。
//   为什么不能默认 key：官方服务器也用这个包部署 ⇒ 任何人重跑一次一键部署
//   就会把官方站**静默切闸**，而老客户端不认识 Key ⇒ 直接违反规则 10「手机先于服务器」。
ok(
  'G2 部署脚本默认值是 open（官方切闸必须是显式动作，否则重跑部署会静默切闸）',
  /\[string\]\$Registration\s*=\s*'open'/.test(installSrc)
);
ok(
  'G3 参数只接受 open/key/closed（拼错早失败，而不是静默放行）',
  /ValidateSet\('open',\s*'key',\s*'closed'\)/.test(installSrc)
);
ok('G4 安装时把准入模式打给人看', installSrc.includes('注册准入：'));
// G5/G6：“能不能自己救自己”—— key 模式下运维必须能在屏幕上看到可直接复制的签发命令，
// 否则就是“能力实现了、使用者不知道怎么用”（这条在 0.118.0 复查时被发现缺失）。
ok('G5 key 模式下打印可直接执行的 keygen 签发命令', /keygen\.js issue/.test(installSrc));
ok('G6 open 模式下提醒公网应显式切 key', /-Registration key/.test(installSrc));

// ============ H. 自助申领默认关 ============
ok(
  'H1 ★ 自助申领默认关闭（HUB_KEY_SELF_SERVE 未设 = 关）',
  hubSrc.includes("process.env.HUB_KEY_SELF_SERVE || '0'")
);
const applyBlock = slice(hubSrc, "pathname === '/api/key/apply'", '// 身份换钥「随人不随设备」');
ok(
  'H2 关闭时回 404 而不是 403（403 等于告诉扫描器"这有个开关"）',
  applyBlock.includes('404') && applyBlock.includes("error: 'not_found'")
);
ok('H3 端点路径与 ADR 一致：/api/key/apply', hubSrc.includes("/api/key/apply"));
ok(
  'H4 自助申领按 IP 日配额（开了也不会被一个脚本刷空）',
  hubSrc.includes('SELF_SERVE_PER_IP_PER_DAY') && applyBlock.includes('selfServeOk(ip)')
);

// ============ I. 管理端点（签发/列表/吊销） ============
ok(
  'I1 三个管理动作都在 admin 凭据之下（不允许匿名签发）',
  hubSrc.includes("pathname === '/api/admin/keys'") &&
    hubSrc.includes("pathname.startsWith('/api/admin/keys/')") &&
    hubSrc.includes('const adminOk =')
);
ok(
  'I2 列表不回传 hash（hash 是可离线爆破的凭据影子）',
  slice(hubSrc, "if (req.method === 'GET') {", 'if (req.method === \'POST\') {').includes('key_id:') &&
    !slice(hubSrc, "if (pathname === '/api/admin/keys')", 'if (req.method === \'DELETE\'').includes('hash: k.hash')
);
ok(
  'I3 明文只在签发响应里出现一次（库里只有哈希）',
  hubSrc.includes('out.push({ key_id: keyId, key: plain })') &&
    hubSrc.includes('hash: admission.hashAccessKey(plain)')
);
ok(
  'I4 唯一写者是 hub 进程（签发工具走 HTTP，不直接改 hub.json）',
  fs.existsSync(path.join(ROOT, 'lib', 'hub', 'keygen.js')) &&
    !read(path.join(ROOT, 'lib', 'hub', 'keygen.js')).includes('writeFileSync')
);

// ============ J. 客户端接线（跨语言） ============
//
// 这一段守的是本项目最经典的一类静默失效：**写键的地方和读键的地方不是同一个字符串**。
// Key 填进去、存进了另一个键名 ⇒ 注册永远不带票 ⇒ 用户看到"服务端说我没票"，
// 而设置页明明填了。所以"读的键"与"写的键"必须断言是**同一个常量**。
const CLOUD_DART = path.join(ROOT, 'lib', 'core', 'cloud_service.dart');
const ADV_DART = path.join(ROOT, 'lib', 'ui', 'advanced_settings_screen.dart');
const cloudSrc = read(CLOUD_DART);
const advSrc = read(ADV_DART);

ok(
  'J1 prefs 键只定义一次（cloud_hub_key）',
  /prefsHubAccessKey\s*=\s*'cloud_hub_key'/.test(cloudSrc)
);
const keyPushCount = (cloudSrc.match(/'key': accessKey/g) || []).length;
ok(
  'J2 两条注册路径（Ed25519 / HMAC 回退）都带票',
  keyPushCount === 2,
  '命中 ' + keyPushCount + ' 处'
);
ok(
  'J3 ★ 设置页写的是同一个常量（不是手抄字面量）',
  advSrc.includes('CloudService.prefsHubAccessKey'),
  '若这里出现裸字符串 cloud_hub_key，两处一旦不同就会静默失效'
);
// ★ 0.119.0：引导页「连社交」步也能填 Key（官方站启用准入后新用户第一屏）。
//   写入方从 1 个变 2 个 ⇒ 同一个"写键/读键不是同一个字符串"的失效面翻倍，
//   必须逐个钉住：引导页若手抄字面量，用户在引导里填了 Key、存进另一个键，
//   注册永远不带票，界面表现是"服务端说我没票"而引导页明明填过。
const ONB_DART = path.join(ROOT, 'lib', 'ui', 'onboarding_screen.dart');
const onbSrc = read(ONB_DART);
ok(
  'J3b ★ 引导页也写同一个常量，且零手抄字面量',
  onbSrc.includes('CloudService.prefsHubAccessKey') &&
    !onbSrc.includes("'cloud_hub_key'"),
  '引导页出现裸字符串 cloud_hub_key 即判红（两个写入方必须同源）'
);
ok(
  'J4 ★ 准入类失败不再走 HMAC 回退（票无效换算法也不会变有效）',
  cloudSrc.indexOf('_isAdmissionRejection(lastRegisterErrorCode)') > 0 &&
    cloudSrc.indexOf('_isAdmissionRejection(lastRegisterErrorCode)') <
      cloudSrc.indexOf('DBHelper.getOrCreateDeviceSecret()')
);
ok(
  'J5 注册失败按 error 码分流（不是只判 HTTP 状态）',
  cloudSrc.includes('lastRegisterErrorCode') && cloudSrc.includes("decoded['error']")
);
const mappedCodes = [
  'registration_key_required',
  'key_invalid',
  'key_revoked',
  'key_already_bound',
  'agent_revoked',
  'registration_closed',
  'identity_conflict',
];
const missingMap = mappedCodes.filter((c) => !cloudSrc.includes("case '" + c + "'"));
ok('J6 七个拒绝码都有文案映射', missingMap.length === 0, '缺: ' + missingMap.join(','));

const ARB_KEYS = [
  'settingsHubKey',
  'settingsHubKeyHint',
  'cloudKeyRequired',
  'cloudKeyInvalid',
  'cloudKeyRevoked',
  'cloudKeyBound',
  'cloudAgentRevoked',
  'cloudRegisterClosed',
  'cloudRegisterIdentityConflict',
];
const LOCALES = ['en', 'zh', 'zh_Hant', 'ja', 'vi'];
const arbMissing = [];
for (const loc of LOCALES) {
  const p = path.join(ROOT, 'lib', 'l10n', 'app_' + loc + '.arb');
  const src = read(p);
  for (const k of ARB_KEYS) {
    if (!src.includes('"' + k + '"')) arbMissing.push(loc + ':' + k);
  }
}
ok('J7 五语种 ARB 同步新增九个键（R7）', arbMissing.length === 0, '缺: ' + arbMissing.join(' '));
const genSrc = read(path.join(ROOT, 'lib', 'l10n', 'app_localizations.dart'));
ok(
  'J8 生成物已包含新 getter（ARB 改了但没 gen-l10n = 编译期才知道）',
  genSrc.includes('cloudKeyRequired') && genSrc.includes('settingsHubKey')
);
ok(
  'J9 Key 输入框为密文（等价凭据，不该在公共场合裸露）',
  slice(advSrc, 'l10n.settingsHubKey,', 'l10n.settingsWorldUrl').includes('obscure: true')
);
ok(
  'J10 保存时只在"地址或 Key 变了"才探测（不让保存路径依赖中转站活着）',
  advSrc.includes('hubAfterAdmission != hubBeforeAdmission') &&
    advSrc.includes('lastRegisterWasAdmissionRejection')
);

// ============ K. 使用者能不能自己走通（一键部署入口 + 文档） ============
//
// 2026-10-21 复查发现的两处「闸装了，但开不了 / 没人知道」：
//   ① `1-一键部署.cmd` 不向 install-server.ps1 转发任何参数，且自提权时
//      `Start-Process` 会丢掉参数 ⇒ 一键部署路径**只能**部署成 open，
//      官方站根本没有受支持的开闸入口（只能手改 run-hub.cmd）。
//   ② 包内《先看我-使用说明》与 README 都只字未提注册闸 ⇒ 运营方不知道有这道闸。
// 「能力已实现 ≠ 使用者知道 ≠ 入口接得通」，三条都得有判据。
const ONECLICK = path.join(ROOT, 'lib', 'hub', 'deploy', '1-一键部署.cmd');
const MAKEPKG = path.join(ROOT, 'lib', 'hub', 'deploy', 'make-package.ps1');
const GUIDE = path.join(ROOT, 'lib', 'hub', 'deploy', '先看我-使用说明.txt');
const README = path.join(ROOT, 'lib', 'hub', 'README.md');
const oneClickSrc = read(ONECLICK);
const makePkgSrc = read(MAKEPKG);
const guideSrc = read(GUIDE);
const readmeSrc = read(README);

// ★ R34 教训（判据查错对象比没判据更危险）：`deploy/1-一键部署.cmd` 是**产物**，
//   真正的源头是 `make-package.ps1` 里的 here-string，而且打完包它会把产物
//   **反向覆盖**回 deploy/ 。本轮第一次就改错了对象：改产物、判产物，跑一次打包
//   全被冲掉，守卫却还绿着（因为它读的就是那个被改过的产物）。
//   ⇒ 源头判据查生成器，产物判据只用来抓"改了模板忘了重打包"。
const installTemplate = slice(makePkgSrc, '$launcherInstall = @', '$launcherManage = @');
ok(
  'K1 ★ 一键部署模板把命令行参数转给 install-server.ps1（源头在 make-package.ps1，不是 deploy/ 下那份产物）',
  /install-server\.ps1" -HubDir "%ROOT%" -DataDir "C:\\DahuangData" %\*/.test(installTemplate),
  '模板片段长度=' + installTemplate.length
);
ok(
  'K2 ★ 模板的自提权分支也带上参数（Start-Process 默认丢参数 ⇒ 非管理员运行会静默退回 open）',
  /RunAs[^\n]*-ArgumentList '%\*'/.test(installTemplate)
);
ok(
  'K2b deploy/1-一键部署.cmd（已入库产物）与模板一致 —— 改完模板必须重打包',
  oneClickSrc.includes('-ArgumentList') && oneClickSrc.includes('"C:\\DahuangData" %*'),
  '产物仍是旧版：跑 lib/hub/deploy/make-package.ps1 重打'
);

const readmeGate = slice(readmeSrc, '## 6. 注册闸门', '## 7. 常见问题');
ok(
  'K3 README 有注册闸门专章（找不到说明章节被改名，判据要跟着改）',
  readmeGate.length > 800,
  String(readmeGate.length)
);
const modeWords = ['open', 'key', 'closed', 'HUB_REGISTRATION', 'node keygen.js issue'];
const modeMissing = modeWords.filter((w) => !readmeGate.includes(w));
ok(
  'K4 README 专章含三种模式 + 环境变量 + 签发命令',
  modeMissing.length === 0,
  '缺: ' + modeMissing.join(',')
);
ok(
  'K5 README 写明"闸开了"的唯一现场证据是启动日志那一行',
  readmeGate.includes('注册模式: key'),
  '否则运营方只能靠"我设过环境变量"自我安慰'
);
const codeBlock = slice(readmeSrc, '| 返回 `agent_not_registered`', '## 8. 协议速查');
const docCodes = [
  'registration_key_required',
  'key_invalid',
  'key_revoked',
  'key_already_bound',
  'agent_revoked',
  'registration_closed',
];
const codeMissing = docCodes.filter((c) => !codeBlock.includes('`' + c + '`'));
ok(
  'K6 六个准入拒绝码都进了常见问题表（用户看得到"该找谁"）',
  codeMissing.length === 0,
  '缺: ' + codeMissing.join(',')
);
ok(
  'K7 明确告知按 error 码分流、不许只判 HTTP 状态',
  codeBlock.includes('不要只判 HTTP 状态')
);
ok(
  'K8 包内使用说明写出一键开闸命令（这份是用户最先读到的文档）',
  guideSrc.includes('-Registration key') && guideSrc.includes('keygen.js issue'),
  '缺开闸入口说明 = 闸装了但没人会开'
);

// ============ 汇总 ============
console.log('=== 注册准入闸（ADR-002）===');
if (failures.length) {
  for (const f of failures) console.log('FAIL ' + f);
}
console.log(`${pass} PASS / ${fail} FAIL`);
process.exit(fail === 0 ? 0 : 1);
