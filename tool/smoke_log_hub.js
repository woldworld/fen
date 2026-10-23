// 活体冒烟：把 §16 透明日志的 **5 个 HTTP 端点**在真实启动的 Hub 上跑一遍。
//
// 为什么纯函数已经跨语言验证过了，还要这一层：
//   上面 18 条断言证明的是"算法算得对"，但用户拿到的入口是 **HTTP**：
//   路由前缀匹配、query 解析、鉴权头解析、JSON 序列化、幂等语义——
//   这些都可能在"算法正确"的前提下单独出错（例如绕开 `startsWith`、
//   把 `to` 缺省值解析错、鉴权失败却返回 200）。单语言纯函数测试照不到这里。
//
// 隔离：整个流程在**临时数据目录**里跑（HUB_DATA_DIR），端口用 3999，
//       结束即杀进程 + 删目录 —— 不碰仓库里的 lib/hub/data。
//
// 运行：node tool/smoke_log_hub.js

'use strict';

const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const hub = require(path.join(__dirname, '..', 'lib', 'hub', 'hub.js'));

let pass = 0;
let fail = 0;
const results = [];
function ck(ok, label) {
  results.push({ ok, label });
  if (ok) {
    pass++;
    console.log('  PASS  ' + label);
  } else {
    fail++;
    console.log('  FAIL  ' + label);
  }
}

const PORT = 3999;
const AGENT = 'smoke-agent';
const SECRET = process.env.SMOKE_SECRET || '0123456789abcdef';
const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'hub-smoke-'));

function hmacHex(secret, msg) {
  return crypto.createHmac('sha256', secret).update(msg, 'utf8').digest('hex');
}
function b64url(s) {
  return Buffer.from(s, 'utf8').toString('base64url');
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

function signedFrom() {
  const unsigned = {
    proto: 'wold/1',
    alg: 'hmac-sha256',
    from: AGENT,
    ts: Math.floor(Date.now() / 1000),
  };
  return b64url(JSON.stringify({ ...unsigned, sig: hmacHex(SECRET, JSON.stringify(unsigned)) }));
}

function waitReady(tries = 50) {
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
  const child = spawn(process.execPath, [path.join(__dirname, '..', 'lib', 'hub', 'hub.js')], {
    env: { ...process.env, PORT: String(PORT), HUB_DATA_DIR: tmpdir },
    stdio: 'ignore',
  });

  try {
    const ready = await waitReady();
    ck(ready, 'Hub 在临时数据目录上启动成功（端口 3999）');
    if (!ready) throw new Error('hub 未就绪');

    // ---- 注册一个 hmac 身份（写端点需要签名）----
    // ⚠️ 信封必须带 `ts`：Hub 的 tsFresh() 要求时间戳在 300s 窗口内，
    //    缺 ts → 401 bad_timestamp（这是防重放的必要条件，不是可选项）。
    const regUnsigned = {
      proto: 'wold/1',
      alg: 'hmac-sha256',
      ts: Math.floor(Date.now() / 1000),
      payload: { agent_id: AGENT, secret: SECRET, nickname: '冒烟' },
    };
    const regEnv = { ...regUnsigned, sig: hmacHex(SECRET, JSON.stringify(regUnsigned)) };
    const reg = await call('POST', '/api/register', { body: regEnv });
    ck(reg.status === 200, '注册 Agent 成功（写端点前置条件）');

    // ---- 空树读数 ----
    const empty = await call('GET', '/api/log');
    ck(empty.status === 200 && empty.json.size === 0, '空日志 GET /api/log → size=0');
    ck(empty.json.root === hub.logEmptyRoot(), '空日志 root == SHA-256("")');
    ck(empty.json.chain_ok === true, '空日志 chain_ok=true');

    // ---- 未签名写入必须被拒（否则匿名即可灌垃圾）----
    const noAuth = await call('POST', '/api/log/append', { body: { leaf_hash: 'abc' } });
    ck(noAuth.status === 401, '未签名 POST /api/log/append → 401（公开监督≠公开写入）');

    // ---- 签名追加 3 片叶子 ----
    const leafHashes = [0, 1, 2].map((i) => hub.logLeafHashOf(Buffer.from('smoke-leaf-' + i, 'utf8')));
    const expectedRoot = hub.logRootAt(leafHashes, 3);
    let appended = 0;
    for (const lh of leafHashes) {
      const r = await call('POST', '/api/log/append', { body: { leaf_hash: lh }, sigHeader: signedFrom() });
      if (r.status === 200 && r.json.appended === true) appended++;
    }
    ck(appended === 3, '签名追加 3 片叶子都成功');

    // ---- 幂等：同一片再追加一次，size 不变 ----
    const dup = await call('POST', '/api/log/append', { body: { leaf_hash: leafHashes[1] }, sigHeader: signedFrom() });
    ck(dup.status === 200 && dup.json.appended === false && dup.json.size === 3,
      '重复追加同一 leaf_hash → appended=false 且 size 不变（幂等）');

    // ---- 读端点：公开可下载 ----
    const leavesResp = await call('GET', '/api/log/leaves');
    ck(leavesResp.status === 200 && leavesResp.json.size === 3, 'GET /api/log/leaves → size=3');
    ck(JSON.stringify(leavesResp.json.leaves) === JSON.stringify(leafHashes),
      '下载的叶子哈希列表与追加顺序逐项一致');
    ck(leavesResp.json.chain_ok === true, 'GET /api/log/leaves → chain_ok=true');
    // ★ P1-5：分页字段必须齐（不传参时语义与分页之前**完全一致**：
    //   默认页足够大 ⇒ 仍然一次拿到全部，`partial=false`、`next_from=null`）。
    ck(leavesResp.json.total === 3 && leavesResp.json.from === 0 &&
      leavesResp.json.returned === 3 && leavesResp.json.partial === false &&
      leavesResp.json.next_from === null,
      '★ 不传参 → 仍是一次全量、partial=false、next_from=null（默认页够大，老客户端不受影响）');

    const logResp = await call('GET', '/api/log');
    ck(logResp.json.root === expectedRoot, 'GET /api/log 的 root 与本地复算一致');

    // ---- 包含证明 ----
    const inc = await call('GET', '/api/log/proof/inclusion/1');
    ck(inc.status === 200 && inc.json.proof.index === 1 && inc.json.proof.tree_size === 3,
      'GET /api/log/proof/inclusion/1 → 头字段正确');
    ck(hub.logVerifyInclusionByHash(leafHashes[1], inc.json.proof, inc.json.root),
      'Hub 返回的包含证明可被独立验过');
    const incBad = await call('GET', '/api/log/proof/inclusion/9');
    ck(incBad.status === 404, '越界索引 → 404');

    // ---- 一致性证明 ----
    const cons = await call('GET', '/api/log/proof/consistency?from=1&to=3');
    ck(cons.status === 200 && cons.json.proof.from_size === 1 && cons.json.proof.to_size === 3,
      'GET /api/log/proof/consistency?from=1&to=3 → 头字段正确');
    ck(hub.logVerifyConsistency(cons.json.proof, hub.logRootAt(leafHashes, 1), hub.logRootAt(leafHashes, 3)),
      'Hub 返回的一致性证明可被独立验过');
    const consDefault = await call('GET', '/api/log/proof/consistency?from=2');
    ck(consDefault.json.proof.to_size === 3, 'to 缺省 → 取当前期（3）');
    const consBad = await call('GET', '/api/log/proof/consistency?from=3&to=1');
    ck(consBad.status === 400, 'from>to → 400（拒绝回滚式参数）');

    // ================================================================
    // M10 ⑤ 可验证贡献账本（与 §16 合流）
    // ================================================================
    console.log('');
    console.log('--- 跨语言一致性：Dart 端签的记录，Node 端必须验得过 ---');

    // 探针由 `dart run tool/verify_contribution_ledger.dart` 写出。
    // 没有它就只能用 Node 自签自验 —— 那测的是"JS 与 JS 一致"，照不出键序漂移。
    const probePath = path.join(__dirname, '.contribution_probe.json');
    if (!fs.existsSync(probePath)) {
      ck(false, '缺少跨语言探针（先跑 dart run tool/verify_contribution_ledger.dart）');
      throw new Error('probe_missing');
    }
    const probe = JSON.parse(fs.readFileSync(probePath, 'utf8'));

    let canonSame = 0;
    let leafSame = 0;
    let sigOk = 0;
    let verifyOk = 0;
    let keySame = 0;
    for (const item of probe.records) {
      const rec = item.rec;
      if (hub.contributionCanonical(rec) === item.canonical) canonSame++;
      if (hub.contributionLeafHashOf(rec) === item.leaf_hash) leafSame++;
      if (hub.contributionSigValid(rec)) sigOk++;
      if (hub.contributionVerify(rec).ok) verifyOk++;
      if (hub.contributionKeyOf(rec.ctype, rec.subject_pub, rec.ref) === item.key) keySame++;
    }
    const n = probe.records.length;
    ck(canonSame === n, `canonical 逐字节一致（${canonSame}/${n}）—— 键序未漂移，含中文附言`);
    ck(leafSame === n, `叶子哈希逐字节一致（${leafSame}/${n}）—— 公开字段口径一致`);
    ck(sigOk === n, `★ Dart 签的签名在 Node 端验得过（${sigOk}/${n}）—— 跨语言验签成立`);
    ck(verifyOk === n, `Node 端完整判定通过（${verifyOk}/${n}）`);
    ck(keySame === n, `幂等键算法两端一致（${keySame}/${n}）—— 同一件事在两端指向同一条`);

    // 常量表也必须一致（分值/上限/自报规则若两端不同，"算出来的分不一样"）
    let tableOk = true;
    for (const k of probe.kinds) {
      if (hub.CONTRIBUTION_WEIGHTS[k] !== probe.weights[k]) tableOk = false;
      if (hub.CONTRIBUTION_CAPS[k] !== probe.caps[k]) tableOk = false;
    }
    ck(tableOk, '★ 分值表与上限表两端逐项一致（否则同一份记录两端算出不同的分）');
    ck(
      JSON.stringify([...hub.CONTRIBUTION_REQUIRES_COUNTERPARTY].sort()) ===
        JSON.stringify([...probe.requires_counterparty].sort()),
      '自报无效的类型集合两端一致（Hub 与 App 同一口径）'
    );
    ck(
      hub.CONTRIBUTION_MAX_NOTE === probe.max_note_chars &&
        hub.CONTRIBUTION_MAX_REF === probe.max_ref_chars,
      '附言 / 引用对象长度上限两端一致'
    );
    const badWeight = JSON.parse(JSON.stringify(probe.records[0].rec));
    badWeight.weight = 9999;
    ck(hub.contributionVerify(badWeight).code === 'bad_weight',
      '分值不符的记录在 Node 端被拒（bad_weight）');

    // ---- 未签名提交必须被拒 ----
    const cNoAuth = await call('POST', '/api/contributions/commit', {
      body: { ...probe.records[0].rec },
    });
    ck(cNoAuth.status === 401,
      '未签名 POST /api/contributions/commit → 401（读公开、写受限）');

    // ---- 读端点匿名可访问（这是"任何人都能监督"的前提）----
    const cList0 = await call('GET', '/api/contributions');
    ck(cList0.status === 200 && cList0.json.size === 0,
      '空账本 GET /api/contributions → size=0（匿名可读）');

    // ---- 合法提交 ----
    const c1 = await call('POST', '/api/contributions/commit', {
      body: { ...probe.records[0].rec },
      sigHeader: signedFrom(),
    });
    ck(c1.status === 200 && c1.json.appended === true && c1.json.duplicate === false,
      '合法贡献提交成功（Hub 自己重算叶哈希后追加）');
    ck(c1.json.leaf_hash === probe.records[0].leaf_hash,
      '★ Hub 复算的叶子哈希 == Dart 端算的（第三方口径唯一）');
    ck(c1.json.index === 3, '贡献叶子落在既有 3 片之后（与 §16 同一棵树的第 4 片）');

    // ---- 幂等：同一条再提交 → duplicate，size 不变 ----
    const cDup = await call('POST', '/api/contributions/commit', {
      body: { ...probe.records[0].rec },
      sigHeader: signedFrom(),
    });
    ck(cDup.status === 200 && cDup.json.duplicate === true && cDup.json.appended === false,
      '重复提交同一条贡献 → duplicate=true（幂等，不写第二遍）');

    // ---- ★ key_conflict：同一件事换个时间重签 → 409（把一件事记十遍行不通）----
    // ⚠️ 这条必须用**真签名**的变体（probe.fork）：拿改过字段的假签名去测，
    //    只会先撞上 bad_signature，测的根本不是 key_conflict。
    ck(
      hub.contributionSigValid(probe.fork.rec) &&
        hub.contributionLeafHashOf(probe.fork.rec) === probe.fork.leaf_hash,
      '（前提）fork 变体本身是合法签名的记录（只是时间不同）'
    );
    const cFork = await call('POST', '/api/contributions/commit', {
      body: { ...probe.fork.rec },
      sigHeader: signedFrom(),
    });
    ck(cFork.status === 409 && cFork.json.error === 'key_conflict',
      '★ 同一件事换时间重签 → 409 key_conflict（重复计分在 Hub 侧被拦）');

    // ---- 假签名必须被拒 ----
    const cForged = JSON.parse(JSON.stringify(probe.records[0].rec));
    cForged.ref = cForged.ref + 'X'; // 真改一个被签名覆盖的字段 → 验签必失配
    const cForgedR = await call('POST', '/api/contributions/commit', {
      body: cForged,
      sigHeader: signedFrom(),
    });
    ck(cForgedR.status === 400 && cForgedR.json.error === 'bad_signature',
      '★ 改动字段后签名失配 → 400 bad_signature（Hub 独立复核，不只照抄哈希）');

    // ---- 关系型贡献自报无效 ----
    const cSelf = { ...probe.records[0].rec, attestor_pub: probe.records[0].rec.subject_pub };
    const cSelfR = await call('POST', '/api/contributions/commit', {
      body: cSelf,
      sigHeader: signedFrom(),
    });
    ck(cSelfR.status === 400 && cSelfR.json.error === 'self_attestation',
      '★ 邀请类自报 → 400 self_attestation（Hub 与 App 同一口径）');

    // ---- 第二条记录（中文附言）也能提 ----
    const c2 = await call('POST', '/api/contributions/commit', {
      body: { ...probe.records[1].rec },
      sigHeader: signedFrom(),
    });
    ck(c2.status === 200 && c2.json.index === 4, '第二条贡献（中文附言）落在第 5 片');

    // ---- 账本开放下载 ----
    const cList = await call('GET', '/api/contributions');
    ck(cList.status === 200 && cList.json.size === 2 && cList.json.log_size === 5,
      'GET /api/contributions → 2 条承诺、日志共 5 片');
    ck(cList.json.chain_ok === true, '账本接口同时报告 chain_ok');
    const keys = cList.json.contributions.map((c) => c.key);
    ck(keys.includes(probe.records[0].key) && keys.includes(probe.records[1].key),
      '两条贡献的幂等键都在列表里（第三方凭它定位）');

    // ---- 某条贡献的包含证明（第三方只需证明 + 根即可独立验证）----
    const cProof = await call(
      'GET', '/api/contributions/proof/' + encodeURIComponent(probe.records[0].key));
    ck(cProof.status === 200 && cProof.json.index === c1.json.index,
      'GET /api/contributions/proof/<key> → 指回同一片叶子');
    ck(cProof.json.leaf_hash === probe.records[0].leaf_hash,
      '证明里带回了那条贡献的叶子哈希');
    ck(hub.logVerifyInclusionByHash(cProof.json.leaf_hash, cProof.json.proof, cProof.json.root),
      '★ 第三方可用 (记录, 证明, 根) 独立验过 —— 不需要信任 Hub 的库');
    const cProofBad = await call('GET', '/api/contributions/proof/unknown%7Ckey');
    ck(cProofBad.status === 404, '未知 key → 404（不泄露"存在与否"以外的信息）');

    // ---- 日志读数已被贡献推进（合流，不是第二套账）----
    const logAfter = await call('GET', '/api/log');
    ck(logAfter.json.size === 5, '贡献推进了 §16 日志期号 → 5（同一棵树）');
  } catch (e) {
    fail++;
    results.push({ ok: false, label: '冒烟过程异常: ' + e.message });
    console.log('  FAIL  冒烟过程异常: ' + e.message);
  } finally {
    child.kill();
    try {
      fs.rmSync(tmpdir, { recursive: true, force: true });
    } catch (_) {}
  }

  console.log('');
  console.log('================ 透明日志端点活体冒烟：' + pass + ' PASS / ' + fail + ' FAIL ================');
  // 可选：把逐条结果写成 JSON（便于 CI/人工复核；不设则不落盘）
  if (process.env.SMOKE_OUT) {
    fs.writeFileSync(
      process.env.SMOKE_OUT,
      JSON.stringify({ pass, fail, results }, null, 2),
      'utf8'
    );
  }
  process.exit(fail === 0 ? 0 : 1);
}

main();
