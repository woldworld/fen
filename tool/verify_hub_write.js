// 跨语言 + 活体端到端校验：**App 产出的上行载荷，Hub 真的收得下**。
//
// 为什么需要这一层（`tool/verify_hub_write.dart` 已经断言过纯逻辑了）：
//   上面那层证明的是"退避/分类/字段名**我们这边**是对的"。但上行要成功，
//   还差两件**只能在真 Hub 上验证**的事：
//     ① Dart 产出的线格式，被**协议包**（第三方实现的那份）接受吗？
//        —— 两端字段名漂移的病症是"作者签得对、Hub 一律 bad_kind"，
//        而它**不会**在 Dart 单侧测试里暴露；
//     ② 真发一次 HTTP 之后，Hub **自己复算的叶子哈希**是否等于 Dart 端算的？
//        —— 这才是"§16 第三方可验"的地基：只要有一处口径不同，
//        第三方算出的根就与官方根不一致，那句承诺当场作废。
//
// ★ 本脚本还固定住一条**让 outbox 得以成立**的性质：重复提交是幂等的
//   （第二次 200 + duplicate:true，不是报错）。没有这条，"离线攒下来再重放"
//   就不敢做 —— 重放会变成制造冲突。
//
// 隔离：整个流程在**临时数据目录**里跑（HUB_DATA_DIR），端口 3996，
//       结束即杀进程 + 删目录 —— 不碰仓库里的 lib/hub/data。
//
// 前置：先跑 `dart run tool/verify_hub_write.dart` 生成 tool/.hub_write_probe.json。
// 运行：node tool/verify_hub_write.js

'use strict';

const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

// ⚠️ 刻意只用**公开协议包**（不碰 hub.js 内部字段）—— 本脚本同时是
//    "第三方实现"的样板：把 Hub 当成黑盒服务，只靠协议包说话。
const P = require(path.join(__dirname, '..', 'packages', 'protocol', 'src', 'index.js'));

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

const PORT = 3996;
const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-write-'));
const probePath = path.join(__dirname, '.hub_write_probe.json');

const nowSec = () => Math.floor(Date.now() / 1000);

/// 翻页取**全部**叶子哈希（端点分页之后的"第三方取全量"标准写法）。
/// 返回 null 表示中途失败 —— 调用方据此断言"能取到全量"，而不是拿半棵树去算根。
/// ⚠️ 上限是防呆：翻不完必须**显形**（返回 null），不能靠 `while (next_from)`
///    在没有终点时死循环 —— 而"没有终点"恰恰是要被断言的那种缺陷。
async function fetchAllLeaves(pageSize = 1000) {
  const out = [];
  let from = 0;
  for (let guard = 0; guard < 1000; guard++) {
    const r = await call('GET', '/api/log/leaves?from=' + from + '&limit=' + pageSize);
    if (r.status !== 200 || !r.json || !Array.isArray(r.json.leaves)) return null;
    if (r.json.from !== from) return null;
    out.push(...r.json.leaves);
    if (r.json.chain_ok !== true) return null;
    if (r.json.next_from === null) return out;
    if (!(r.json.next_from > from)) return null; // 不前进了就是坏了，别死循环
    from = r.json.next_from;
  }
  return null;
}

function call(method, p, opts = {}) {
  return new Promise((resolve, reject) => {
    const data = opts.body ? JSON.stringify(opts.body) : null;
    const headers = {};
    if (data) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(data);
    }
    if (opts.sigHeader) headers['x-agent-sig'] = opts.sigHeader;
    const req = http.request(
      { host: '127.0.0.1', port: PORT, path: p, method, headers },
      (res) => {
        let buf = '';
        res.on('data', (d) => (buf += d));
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(buf);
          } catch (_) {
            json = buf;
          }
          resolve({ status: res.statusCode, json });
        });
      }
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

function newEd25519() {
  const kp = crypto.generateKeyPairSync('ed25519');
  const pub = P.base58.encode(P.ed25519.rawFromKey(kp.publicKey));
  return { kp, pub };
}

function authHeader(agentId, kp) {
  return P.envelope.signHeader(
    { proto: P.PROTO, ts: nowSec(), from: agentId },
    { privateKey: kp.privateKey }
  );
}

async function register(agentId, kp, pub) {
  const env = P.envelope.sign(
    {
      proto: P.PROTO,
      ts: nowSec(),
      payload: { agent_id: agentId, pubkey: pub, nickname: agentId },
    },
    { privateKey: kp.privateKey }
  );
  return call('POST', '/api/register', { body: env });
}

function waitReady(tries = 60) {
  return new Promise((resolve) => {
    const tick = (n) => {
      const req = http.get({ host: '127.0.0.1', port: PORT, path: '/health' }, (res) => {
        res.resume();
        resolve(true);
      });
      req.on('error', () => {
        if (n <= 0) resolve(false);
        else setTimeout(() => tick(n - 1), 100);
      });
    };
    tick(tries);
  });
}

async function main() {
  // ======================================================================
  console.log('--- ① 探针存在性 ---');
  if (!fs.existsSync(probePath)) {
    ck(false, '缺少跨语言探针（先跑 dart run tool/verify_hub_write.dart）');
    throw new Error('probe_missing');
  }
  const probe = JSON.parse(fs.readFileSync(probePath, 'utf8'));
  ck(true, '探针已读到（tool/.hub_write_probe.json）');

  // ======================================================================
  console.log('');
  console.log('--- ② Dart 的贡献线格式，协议包必须认 ---');
  const cw = probe.contribution_wire;

  ck(
    P.contributionCanonical(cw) === probe.contribution_canonical,
    '★ canonical 逐字节一致（键序未漂移）—— 键序漂移的病症是"签得对、Hub 一律拒"'
  );
  ck(P.contributionVerify(cw).ok === true,
    '★ 协议包完整判定通过（bad_kind / bad_weight / bad_signature 全不触发）');
  ck(P.contributionLeafHashOf(cw) === probe.contribution_leaf_hash,
    '★ 叶子哈希两端一致 —— 第三方算出的根才会与官方根相同');
  ck(
    P.contributionKeyOf(cw.ctype, cw.subject_pub, cw.ref) === probe.contribution_key,
    '幂等键算法两端一致（同一件事在两端指向同一条）'
  );
  ck(
    P.contributionLogBytes(cw).toString('utf8') === probe.contribution_leaf_json,
    '★ 叶子字节逐字节一致（含中文附言不参与、公开字段口径一致）'
  );

  console.log('--- ③ 字段名护栏：协议口径 vs 本地列名 ---');
  ck(typeof cw.ctype === 'string' && cw.ctype.length > 0,
    '线格式的类型字段是 ctype');
  ck(cw.kind === undefined,
    '★ 线格式**没有** kind 字段（kind 是域分隔标签，只在签名载荷里）');
  ck(typeof cw.at === 'number' && cw.at > 0, '线格式的时间字段是 at');
  ck(cw.at_ms === undefined,
    '★ 线格式**没有** at_ms（提交落库列名会被 Hub 判 bad_kind）');
  ck(probe.wire_map_keys.length === 8,
    '线格式字段数 = 8（未夹带任何额外字段）');

  // ======================================================================
  console.log('');
  console.log('--- ④ Dart 的角色线格式，协议包必须认 ---');
  const gw = probe.role_grant_wire;
  ck(P.roomRoleCanonical(gw) === probe.role_canonical,
    '★ 角色 canonical 逐字节一致');
  ck(P.roomRoleVerify(gw).ok === true,
    '★ 角色完整判定通过（granter_pub / agent_pub / 签名齐备）');
  ck(P.roomRoleLogBytes(gw).toString('utf8') === probe.role_leaf_json,
    '★ 角色叶子字节逐字节一致');

  // ======================================================================
  console.log('');
  console.log('--- ⑤ §9.1 红线：上行载荷里没有可权益字段 ---');
  const forbidden = probe.forbidden_keys_scanned || [];
  const scan = (m, name) => {
    const hit = Object.keys(m).filter((k) => forbidden.includes(k));
    ck(hit.length === 0, name + ' 无禁区字段');
    return hit;
  };
  scan(cw, '贡献线格式');
  scan(gw, '角色线格式');
  ck(!('score' in cw) && !('balance' in cw),
    '★ 线格式里没有 score / balance —— 累计声望是派生值，任何一端都不得把它变成可传输字段');

  // ======================================================================
  console.log('');
  console.log('--- ⑥ 活体：真 Hub 上发一次（含鉴权头） ---');
  const child = spawn(process.execPath, [path.join(__dirname, '..', 'lib', 'hub', 'hub.js')], {
    env: { ...process.env, PORT: String(PORT), HUB_DATA_DIR: tmpdir },
    stdio: 'ignore',
  });

  try {
    const ready = await waitReady();
    ck(ready, 'Hub 已就绪（临时数据目录，端口 ' + PORT + '）');
    if (!ready) throw new Error('hub_not_ready');

    const me = newEd25519();
    const reg = await register('agent-writer', me.kp, me.pub);
    ck(reg.status === 200, '注册一个上行身份成功');

    // ---- /api/log/append：裸叶子（互介记录那条路走这里） ----
    const lh = P.log.leafHashOf(Buffer.from('hello-uplink', 'utf8'));
    const a1 = await call('POST', '/api/log/append', {
      body: { leaf_hash: lh },
      sigHeader: authHeader('agent-writer', me.kp),
    });
    ck(a1.status === 200 && a1.json.appended === true, 'POST /api/log/append → 200 且已追加');
    const a2 = await call('POST', '/api/log/append', {
      body: { leaf_hash: lh },
      sigHeader: authHeader('agent-writer', me.kp),
    });
    ck(a2.status === 200 && a2.json.appended === false,
      '★ 同一叶子再发一次 → 200 但 appended=false（幂等，重放安全）');

    // ---- /api/contributions/commit：Dart 产的线格式 ----
    const c1 = await call('POST', '/api/contributions/commit', {
      body: cw,
      sigHeader: authHeader('agent-writer', me.kp),
    });
    ck(c1.status === 200 && c1.json.duplicate === false,
      '★ Dart 产的贡献线格式被真 Hub 接受（200，非重复）');
    ck(c1.json.leaf_hash === probe.contribution_leaf_hash,
      '★★ Hub **自己复算**的叶子哈希 == Dart 端算的 —— §16 第三方可验的地基');
    ck(c1.json.key === probe.contribution_key, 'Hub 复算的幂等键 == Dart 端的');

    const c2 = await call('POST', '/api/contributions/commit', {
      body: cw,
      sigHeader: authHeader('agent-writer', me.kp),
    });
    ck(c2.status === 200 && c2.json.duplicate === true && c2.json.appended === false,
      '★★ 同一贡献再发一次 → duplicate=true（**幂等**：outbox 重放不会制造冲突）');

    // ---- 未签名提交必须被拒（读公开、写受限） ----
    const cNoAuth = await call('POST', '/api/contributions/commit', { body: cw });
    ck(cNoAuth.status === 401,
      '★ 未签名提交 → 401（"任何人都能监督"的前提是读公开，而不是写公开）');

    // ====================================================================
    console.log('');
    console.log('--- ⑦ 第三方独立复算：只凭公开数据，不信任 Hub ---');
    // ★ 端点已改为**分页**（P1-5）：第三方要复算整棵树，就得**自己翻页取全量** ——
    //   这正是"分页"必须配 `next_from` 的原因：没有它，第三方拿到的是一半的树，
    //   自己算出来的根必然与 Hub 不一致，而它**看不出来**是哪一边错了。
    const leaves = await fetchAllLeaves();
    ck(leaves !== null, 'GET /api/log/leaves 可分页取全量（含 chain_ok 自检通过）');
    const myRoot = P.log.rootAt(leaves, leaves.length);
    ck(myRoot === c1.json.root,
      '★★ 第三方凭叶子列表**自己算的根** == Hub 给的根（有分歧就说明口径漂了）');

    // 分页本身的行为也必须可断言（否则"能取全量"可能只是**默认页恰好够大**）
    // ⚠️ 页大小取 1 而不是 2：本脚本的日志很短，写死 2 会让"有没有下一页"
    //    取决于测试数据长度 —— 那种断言在数据一变就悄悄失去意义。
    ck(leaves.length >= 1, '（前提）日志里至少有 1 片叶子可供分页');
    const p1 = await call('GET', '/api/log/leaves?from=0&limit=1');
    ck(p1.status === 200 && p1.json.returned === 1 && p1.json.from === 0 &&
      p1.json.leaves.length === 1,
      '分页：from=0&limit=1 → 恰好 1 片');
    ck(p1.json.total === leaves.length && p1.json.size === leaves.length,
      '★ 分页回包里的 total/size 仍是**整棵树**的规模（不是这一页的长度）');
    const more = leaves.length > 1;
    ck(p1.json.partial === more && p1.json.next_from === (more ? 1 : null),
      '★ 还有下一页时给出 next_from=1 且 partial=true（第三方据此继续翻）');
    const pLast = await call('GET', '/api/log/leaves?from=' + (leaves.length - 1) + '&limit=1');
    ck(pLast.json.returned === 1 && pLast.json.next_from === null && pLast.json.partial === false,
      '★ 取到末尾时 next_from=null 且 partial=false（有终点，才不会无限翻）');
    const pBad = await call('GET', '/api/log/leaves?from=-1');
    ck(pBad.status === 400 && pBad.json.error === 'bad_from',
      '非法 from → 400 bad_from（不猜、不静默替换成默认值）');
    const pBad2 = await call('GET', '/api/log/leaves?limit=0');
    ck(pBad2.status === 400 && pBad2.json.error === 'bad_limit',
      '非法 limit → 400 bad_limit（limit=0 不该看起来像"正常返回空页"）');
    const pBig = await call('GET', '/api/log/leaves?limit=999999');
    ck(pBig.status === 200 && pBig.json.limit === 5000 && pBig.json.returned === leaves.length,
      '★ 超上限的 limit 被**夹紧**到 5000（要"尽可能多"是合理诉求，不报错）');

    const proofRes = await call(
      'GET',
      '/api/contributions/proof/' + encodeURIComponent(probe.contribution_key)
    );
    ck(proofRes.status === 200 && proofRes.json && proofRes.json.proof &&
      typeof proofRes.json.proof.tree_size === 'number',
    'GET /api/contributions/proof/<key> 匿名可读（第三方手上有记录本体即可定位）');
    ck(proofRes.json.leaf_hash === probe.contribution_leaf_hash,
      '证明里的叶子哈希 == Dart 端算的');
    const proof = proofRes.json.proof || {};
    ck(
      proof.tree_size === leaves.length,
      '★ 证明自报的树规模 == 公开叶子列表的规模（第三方不需要信"我们说是第几期"）'
    );
    ck(
      P.log.verifyInclusionByHash(proofRes.json.leaf_hash, proof, myRoot) === true,
      '★★ 第三方**仅凭公开叶子列表与证明**即可验证包含关系（不需要信任我们）'
    );
    ck(proofRes.json.root === myRoot, '证明所依据的根 == 第三方自算的根');
  } finally {
    child.kill();
    try {
      fs.rmSync(tmpdir, { recursive: true, force: true });
    } catch (_) {}
  }

  // ======================================================================
  console.log('');
  console.log('================ App→Hub 上行端到端校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
  // ★ `run_all_verify.dart` 只跑 *.dart；本脚本由 Node 侧清单调用，格式保持一致。
  console.log('PASS=' + pass + ' FAIL=' + fail);
  if (fail > 0) process.exit(1);
}

main().catch((e) => {
  console.error('异常终止: ' + (e && e.stack ? e.stack : e));
  process.exit(1);
});
