// 跨语言一致性校验：**Dart 端签的背书，Node Hub 端必须验得过**。
//
// 为什么需要它（与 M9 同源的雷）：
//   两端各自把背书拼成"确定性签名载荷"（canonical JSON）再验签。
//   Dart 的 `jsonEncode` 与 JS 的 `JSON.stringify` 都产出无空格 JSON，但**键序**
//   取决于插入顺序。键序一旦不同，同一份背书两端算出的载荷就不同 ——
//   结果是"用户在自己设备上签得好好的，一提交到 Hub 就被判签名无效"。
//   这种缺陷**单语言测试永远发现不了**。
//
// 额外一层：Hub 侧的**准入判定**（endorsementAccept）也必须两端同构 ——
//   "客户端认为合法的自证，Hub 也得拒"，否则客户端绕一下就能把自证写进网络。
//
// 运行：node tool/verify_reputation_hub.js
// 前提：先跑 `dart run tool/verify_reputation_network.dart` 生成探针文件。

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

const probePath = path.join(__dirname, '.reputation_probe.json');
if (!fs.existsSync(probePath)) {
  console.error('缺少探针文件 —— 请先运行: dart run tool/verify_reputation_network.dart');
  process.exit(2);
}
const probe = JSON.parse(fs.readFileSync(probePath, 'utf8'));

const endorsement = {
  issuer_pub: probe.endorsement_pub,
  sig: probe.endorsement_sig,
  // canonical 里的字段原样还原，供 Node 复算
  ...JSON.parse(probe.endorsement),
};

console.log('--- Dart 签的背书 → Node 验 ---');
ck(typeof endorsement.sig === 'string' && endorsement.sig.length > 0, '探针背书带签名');
ck(hub.endorsementSigValid(endorsement) === true, 'Node 验签：Dart 签的背书验得过');

// 两端 canonical 必须**逐字节**一致（这才是根因层的检查）
ck(
  hub.endorsementCanonical(endorsement) === probe.endorsement,
  'canonical 载荷逐字节一致（Dart jsonEncode ↔ Node JSON.stringify）'
);

console.log('--- 跨语言下的 fail-closed ---');
ck(hub.endorsementSigValid({ ...endorsement, tier: 'family' }) === false, '改档位后 Node 也验不过');
ck(
  hub.endorsementSigValid({ ...endorsement, subject_pub: 'SOMEONE-ELSE' }) === false,
  '换主体后 Node 也验不过'
);
ck(hub.endorsementSigValid({ ...endorsement, sig: '' }) === false, '无签名 → 拒');
ck(hub.endorsementSigValid({ ...endorsement, issuer_pub: 'abc' }) === false, '坏公钥 → 拒');

console.log('--- 吊销声明跨语言 ---');
// 坑：canonical 读的是 `at_ms`，而 probe 里展开出来的是 `at`（canonical 的键名）。
// 直接 `...JSON.parse(probe.revocation)` 会漏掉 at_ms → 算成 at:0 → 逐字节比对必然不等。
const revParsed = JSON.parse(probe.revocation);
const revocation = {
  issuer_pub: probe.revocation_pub,
  subject_pub: revParsed.subject_pub,
  at_ms: revParsed.at,
  sig: probe.revocation_sig,
};
ck(hub.endorsementRevocationSigValid(revocation) === true, 'Node 验签：Dart 签的吊销验得过');
ck(
  hub.endorsementRevocationCanonical(revocation) === probe.revocation,
  '吊销 canonical 逐字节一致'
);
// ★ 拿吊销的签名当背书用 → 必须验不过（这就是 canonical 里带 kind 的意义）
ck(
  hub.endorsementSigValid({ ...revocation, sig: revocation.sig }) === false,
  '拿吊销声明冒充背书 → 验不过（kind 入载荷的作用）'
);

console.log('--- 准入判定两端同构（客户端认为非法的，Hub 也必须拒）---');
const now = Number(endorsement.issued_at || 0) + 1000;
ck(hub.endorsementAccept(endorsement, now).code === 'ok', '合法背书 → ok');
ck(
  hub.endorsementAccept({ ...endorsement, issuer_pub: endorsement.subject_pub }, now).code ===
    'self_endorsement',
  '★ 自证 → self_endorsement（客户端绕一下也写不进网络）'
);
ck(
  hub.endorsementAccept({ ...endorsement, tier: 'stranger' }, now).code === 'bad_tier',
  '背书 stranger → bad_tier（无意义的边）'
);
ck(
  hub.endorsementAccept({ ...endorsement, note: 'x'.repeat(141) }, now).code === 'note_too_long',
  '附言超长 → note_too_long'
);
ck(
  hub.endorsementAccept({ ...endorsement, expires_at: Number(endorsement.issued_at) - 1 }, now)
    .code === 'bad_window',
  '有效期早于签发 → bad_window'
);
ck(
  hub.endorsementAccept(endorsement, Number(endorsement.expires_at) + 1).code === 'expired',
  '★ 过期 → expired（信任必须有终点）'
);
ck(
  hub.endorsementAccept({ ...endorsement, issued_at: 0 }, now).code === 'bad_window',
  'issued_at 为 0 → bad_window'
);

console.log('--- Hub 端点齐备（源文本比对）---');
const hubSrc = fs.readFileSync(path.join(__dirname, '..', 'lib', 'hub', 'hub.js'), 'utf8');
for (const p of ['/api/reputation/endorse', '/api/reputation/revoke', '/api/reputation/']) {
  ck(hubSrc.includes(p), `Hub 暴露端点 ${p}`);
}
ck(
  hubSrc.includes('issuer_pub_mismatch'),
  '★ Hub 拦住"替别人背书"（提交者必须就是签发人）'
);
ck(hubSrc.includes('not_issuer'), '★ Hub 拦住"非签发人吊销"');
// 关键：Hub **不做**聚合打分（全局信誉分天然可刷）
ck(
  /Hub \*\*不做\*\*聚合打分/.test(hubSrc),
  'Hub 侧明确不做聚合打分（全局分可刷，聚合留给观察者本地）'
);

console.log('--- 身份别名：换钥后履历仍归本人（Gap A）---');
{
  // 背书按 `subject_pub` 计（不用 agent_id：名字可被重发 ⇒ "改个名就能甩掉差评"）。
  // 于是换钥退休旧公钥之后，他此前收到的背书全都留在那把死钥上 ——
  // "履历随人走"退化成"随钥走"（换一次手机履历归零）。
  // 别名规则与换钥 canonical 同源（协议包 `alias.js`），Hub 只是调用。
  const crypto = require('crypto');
  const kp = () => crypto.generateKeyPairSync('ed25519');
  const pubOf = (k) =>
    hub.base58Encode(k.publicKey.export({ type: 'spki', format: 'der' }).subarray(-32));
  const sign = (k, r) => ({
    ...r,
    sig: crypto
      .sign(null, Buffer.from(hub.rotationCanonical(r), 'utf8'), k.privateKey)
      .toString('base64'),
  });

  const A = kp();
  const B = kp();
  const C = kp();
  const pa = pubOf(A);
  const pb = pubOf(B);
  const pc = pubOf(C);
  const r1 = sign(A, { agent_id: 'AG-ALIAS01', old_pub: pa, new_pub: pb, rotated_at: 1700000000000, idx: 0 });
  const r2 = sign(B, { agent_id: 'AG-ALIAS01', old_pub: pb, new_pub: pc, rotated_at: 1700000100000, idx: 1 });

  const atTip = hub.identityKeysOf([r1, r2], pc);
  ck(
    atTip.status === 'ok' && atTip.keys.length === 3 && atTip.keys[0] === pa && atTip.keys[2] === pc,
    '★ 查当前钥 → 解出整条历史（换钥前收到的背书仍归本人）'
  );
  ck(
    hub.identityKeysOf([r1, r2], pa).keys.length === 3,
    '★ 查已退休的钥 → 解出同一个身份（履历需要的正是这个方向）'
  );
  ck(
    hub.identityKeysOf([r1, r2], pa).keys.join('|') === atTip.keys.join('|'),
    '两个方向得到同一个集合（别名是对称并集）'
  );
  ck(
    hub.identityKeysOf([r1, r2], 'SOMEONE-ELSE').status === 'no_chain',
    '不在任何换钥记录里的钥 → no_chain（不继承任何人的履历）'
  );
  const forged = [
    r1,
    sign(C, { agent_id: 'AG-ALIAS01', old_pub: pb, new_pub: pc, rotated_at: 1700000100000, idx: 1 }),
  ];
  ck(
    hub.identityKeysOf(forged, pc).status === 'unsigned' &&
      hub.identityKeysOf(forged, pc).keys.length === 1,
    '★ 一环坏签名 → 整条链作废、收敛成单钥（fail-closed）'
  );
  const gapped = [r1, sign(A, { agent_id: 'AG-ALIAS01', old_pub: pa, new_pub: pc, rotated_at: 1700000100000, idx: 1 })];
  ck(hub.identityKeysOf(gapped, pc).status === 'broken', '★ 环接不上 → broken（fail-closed）');
  ck(
    hub.identityKeysOf([r1, r2], '').keys.length === 0,
    '空主体 → 解不出任何钥'
  );

  // 端点必须**真的**用这条规则，而不是退回"逐字相等"
  ck(
    /identityKeysOf\(Object\.values\(db\.key_rotations\), subject\)/.test(hubSrc),
    '★ 背书查询端点按换钥链展开别名（不是按逐字相等过滤）'
  );
  ck(
    /alias:\s*\{[\s\S]{0,240}chain_records/.test(hubSrc),
    '★ 展开所依据的原始记录一并交出（读者可复算 —— Hub 不自证）'
  );
  ck(
    !/filter\(\(e\) => e\.subject_pub === subject\)/.test(hubSrc),
    '★ 旧的逐字相等过滤已不再出现（哪天改回去，这一条会抓住）'
  );
}

console.log('');
console.log(
  '================ Node 侧跨语言校验（M6）：' + pass + ' PASS / ' + fail + ' FAIL ================'
);
process.exit(fail === 0 ? 0 : 1);
