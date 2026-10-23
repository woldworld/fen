// 纯 Dart 校验脚本：**App → Hub 上行接线**（`hub_write_service.dart` / `hub_outbox.dart`）。
// 运行：dart run tool/verify_hub_write.dart
//
// 为什么值得单独一个脚本：
//   在此之前，Hub 侧 5 个写端点**只有 `tool/*.js` 测试脚本调过，App 一次都没调过** ——
//   本地记账齐全，公开树上却没有叶子。也就是说 §16 那句
//   "你不必相信我，你可以验我"当时**没有数据流可供验证**，属于"宣称大于事实"。
//   本脚本盯的是这条腿**接得对不对**，而且盯的方式不是"我们声明接上了"：
//
//   ① **线格式逐字段断言**：`ContributionRecord.toWireMap()` 必须给出
//      `ctype`/`at`（协议口径），**不能**给出 `kind`/`at_ms`（本地列名）——
//      这两者搞混的病症是"作者签得对、Hub 一律 `bad_kind`"；
//   ② **§9.1 红线结构断言**：上行载荷里**物理上没有**任何承载
//      "余额 / 持有人 / 转让 / 兑现"的字段。红线不靠文档承诺，靠字段清单里没有它；
//   ③ **退避与分类纯函数**：可重试 vs 永久拒绝的判据直接断言，
//      因为"该重试的放弃了 = 丢数据"、"不该重试的死循环 = 队列排不干"，两个都是真事故；
//   ④ **留跨语言探针**：`tool/.hub_write_probe.json` 供 `tool/verify_hub_write.js`
//      用协议包复算，确认 Dart 产出的线格式**Hub 真的收得下**。
//
// 本脚本只 import 纯 Dart 模块（无 Flutter / sqflite 调用），故可离线复算。

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/contribution_ledger.dart';
import 'package:dahuang_ai/core/hub_endpoint.dart';
import 'package:dahuang_ai/core/hub_outbox.dart';
import 'package:dahuang_ai/core/hub_push_outcome.dart';
import 'package:dahuang_ai/core/room_role.dart';
import 'package:dahuang_ai/core/transparency_log.dart';

int _pass = 0;
int _fail = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

const int kNow = 1800000000000;

/// §9.1 红线：这些词一旦出现在**权益类**记录里，就意味着它变成了可转让/可兑现的东西。
/// 扫描是**字段级**的，不是文档级的 —— 文档会被人改，字段清单不会。
const List<String> kForbiddenKeys = [
  'score', 'balance', 'owner', 'owner_id', 'to_pub', 'holder', 'holder_pub',
  'redeem', 'redeem_at', 'transfer', 'transferable', 'payout', 'cash',
  'beneficiary', 'assignee', 'sell_price', 'market_value',
];

List<String> _forbiddenIn(Map<String, Object?> m) =>
    m.keys.where((k) => kForbiddenKeys.contains(k)).toList();

Map<String, Object?> _asMap(String jsonText) =>
    Map<String, Object?>.from(jsonDecode(jsonText) as Map);

Future<({String pub, Future<String> Function(List<int>) sign})> _newKey() async {
  final kp = await Ed25519().newKeyPair();
  final pubBytes = await kp.extractPublicKey();
  return (
    pub: AgentProtocol.base58Encode(pubBytes.bytes),
    sign: (List<int> msg) async {
      final s = await Ed25519().sign(msg, keyPair: kp);
      return base64Encode(s.bytes);
    },
  );
}

Future<void> main() async {
  // =========================================================================
  print('--- ① 退避策略：该等多久（纯函数） ---');
  check(HubOutboxPolicy.retryDelayMs(0) == 0, 'attempts=0 → 立即（首次入队不人为延迟）');
  check(HubOutboxPolicy.retryDelayMs(1) == HubOutboxPolicy.baseDelayMs,
      'attempts=1 → baseDelay');
  check(HubOutboxPolicy.retryDelayMs(2) > HubOutboxPolicy.retryDelayMs(1),
      '退避随失败次数递增');
  check(HubOutboxPolicy.retryDelayMs(40) == HubOutboxPolicy.maxDelayMs,
      '★ 退避封顶在 maxDelay（1 小时）—— 不会退避到天文数字');
  check(HubOutboxPolicy.maxDelayMs <= 3600000,
      '★ 封顶值 ≤ 1 小时（不会出现"等一天才重试"）');
  // 不设"尝试次数上限"是刻意设计：次数上限会**真的丢数据**
  // （离线一整天的用户回来时，那批记录已被自己的重试次数判死）。
  check(HubOutboxPolicy.retryDelayMs(200) == HubOutboxPolicy.maxDelayMs,
      '★ 无论失败多少次都不会"放弃"（只会变慢，绝不判死）');

  // =========================================================================
  print('--- ② Hub 地址策略：打到哪儿（纯函数） ---');
  check(HubEndpoint.isAcceptable('https://hub.example.com'), '公网 HTTPS → 接受');
  check(!HubEndpoint.isAcceptable('http://hub.example.com'),
      '★ 公网明文 HTTP → 拒绝（不能把公示数据明文发到公网）');
  check(HubEndpoint.isAcceptable('http://192.168.1.7:8787'),
      '私有网段 192.168.x 允许 http（Hub 可以跑在自家电脑上）');
  check(HubEndpoint.isAcceptable('http://10.0.0.5:8787'), '私有网段 10.x 允许 http');
  check(HubEndpoint.isAcceptable('http://172.16.3.9:8787'), '私有网段 172.16-31.x 允许 http');
  check(HubEndpoint.isAcceptable('http://localhost:8787'), 'localhost 允许 http');
  check(!HubEndpoint.isAcceptable('   '), '★ 空地址 → 拒绝（调用方必须早退，不发 DNS 空转）');
  check(!HubEndpoint.isAcceptable('http://172.32.1.1'), '172.32.x 不在私有网段 → 拒绝');

  // =========================================================================
  print('--- ③ 响应分类：该重试还是该放弃（纯函数） ---');
  // 判据错向两个方向都会出真事故：
  //   该重试的判成永久 → 丢数据；不该重试的判成可重试 → 队列永远排不干。
  check(classifyHubResponse(200, '') == HubPushOutcome.accepted, '200 → accepted');
  check(classifyHubResponse(409, 'duplicate') == HubPushOutcome.duplicate,
      '409 + duplicate（技能上架重复）→ duplicate（**不是失败**）');
  check(classifyHubResponse(409, 'key_conflict') == HubPushOutcome.rejected,
      '★ 409 + key_conflict → rejected（同一件事对应两片不同叶子，重试一万次也不会对）');
  check(classifyHubResponse(0, 'hub_not_configured') == HubPushOutcome.retryable,
      '★ 未配置 Hub → retryable（用户配置后应能补发，不能丢）');
  check(classifyHubResponse(0, 'network') == HubPushOutcome.retryable, '网络不通 → retryable');
  check(classifyHubResponse(429, 'rate_limited') == HubPushOutcome.retryable,
      '限流 429 → retryable（Hub 侧 60 次/分，必然遇到）');
  check(classifyHubResponse(503, '') == HubPushOutcome.retryable, '5xx → retryable');
  check(classifyHubResponse(401, 'agent_not_registered') == HubPushOutcome.retryable,
      '★ 尚未注册 → retryable（注册完成后应当补发）');
  check(classifyHubResponse(401, 'bad_timestamp') == HubPushOutcome.retryable,
      '★ 时间窗不合 → retryable（校时后应能补发）');
  check(classifyHubResponse(401, 'bad_signature') == HubPushOutcome.rejected,
      '★ bad_signature → rejected（这是我们的代码缺陷，重试无意义）');
  check(classifyHubResponse(401, 'signature_required') == HubPushOutcome.rejected,
      '签名头缺失 → rejected（我们总是带头，出现即缺陷）');
  check(classifyHubResponse(400, 'bad_kind') == HubPushOutcome.rejected,
      '载荷非法 400 → rejected');
  check(classifyHubResponse(403, 'granter_pub_mismatch') == HubPushOutcome.rejected,
      '权限不符 403 → rejected');

  // =========================================================================
  print('--- ④ 队列行为：入队 / 到期 / 退避 / 出队（内存实现） ---');
  final store = MemoryHubOutboxStore();
  final id1 = await store.enqueue(HubOutboxItem(
      endpoint: '/api/log/append', payloadJson: '{"a":1}',
      nextAttemptAtMs: 0, createdAtMs: 1));
  await store.enqueue(HubOutboxItem(
      endpoint: '/api/skills/publish', payloadJson: '{"b":2}',
      nextAttemptAtMs: 99999, createdAtMs: 2));
  check(await store.count() == 2, '入队两条 → count=2');

  var due = await store.due(nowMs: 100, limit: 50);
  check(due.length == 1 && due.first.endpoint == '/api/log/append',
      '★ 只取**到期**的（未到期的不发，避免无效请求打 Hub）');

  await store.markAttempt(id1, 'network', 100 + HubOutboxPolicy.retryDelayMs(1));
  due = await store.due(nowMs: 100, limit: 50);
  check(due.isEmpty, '★ 记一次失败后推到退避窗口 → 立刻再取为空（不会疯狂重试）');
  final later = await store.due(nowMs: 999999, limit: 50);
  check(later.length == 2, '退避窗口过后两条都可发');
  check(later.first.endpoint == '/api/log/append',
      '★ 取用顺序 = **入队顺序**（id ASC）—— 房间角色的权威名册在 Hub 侧重放派生，乱序会被误拒');

  final firstId = later.first.id;
  await store.remove(firstId);
  check(await store.count() == 1, '发送成功即删除（队列里没有"既在队列里又已发出"的中间态）');

  // =========================================================================
  print('--- ⑤ 贡献线格式：字段名必须是协议口径 ---');
  final alice = await _newKey();
  final bob = await _newKey();
  final recDraft = ContributionRecord(
    subjectPub: alice.pub,
    attestorPub: bob.pub,
    kind: ContributionKind.invite,
    ref: bob.pub,
    weight: ContributionKind.weightOf(ContributionKind.invite),
    atMs: kNow,
    note: '谢谢你来',
  );
  // ★ 必须**真签**：拿改过字段的假签名去测，只会先撞上 `bad_signature`，
  //   于是测的根本不是字段口径 —— 这是 `verify_contribution_ledger.dart`
  //   已经踩过并写进注释的同一条坑。
  final rec = recDraft.copyWith(sig: await bob.sign(recDraft.canonicalBytes()));
  final wire = rec.toWireMap();
  check(rec.sig.isNotEmpty, '前置：贡献记录已用证明人私钥**真签**（不是占位符）');

  const expectedWireKeys = {
    'ctype', 'subject_pub', 'attestor_pub', 'ref', 'weight', 'at', 'note', 'sig'
  };
  check(
    wire.keys.toSet().difference(expectedWireKeys).isEmpty &&
        expectedWireKeys.difference(wire.keys.toSet()).isEmpty &&
        wire.length == 8,
    '★ toWireMap 字段集**恰好**是协议口径的 8 个（未多未少）',
  );
  check(wire['ctype'] == rec.kind, '★ 类型字段名是 ctype（不是 kind）');
  check(wire['at'] == rec.atMs, '★ 时间字段名是 at（不是 at_ms）');
  check(!wire.containsKey('kind') && !wire.containsKey('at_ms'),
      '★ **不含**本地列名 kind / at_ms —— 提交它们会被 Hub 判 bad_kind');
  check(wire['weight'] == ContributionKind.weightOf(ContributionKind.invite),
      'weight 是该条记录的固定分值（由类型决定，已入签名载荷）');
  check(wire['sig'] == rec.sig, 'sig 逐字透传（Hub 独立验签用的就是它）');
  // 域分隔标签 `kind` 只出现在**签名载荷**里，不出现在线格式里 ——
  // 合并它们等于让"拿定价权声明当贡献去验"的类型混淆重新可行。
  check(
    jsonDecode(rec.canonical())['kind'] == 'contribution' &&
        !wire.containsKey('kind'),
    '★ `kind`（域分隔标签）只在签名载荷里；线格式用 ctype —— 两者不可合并',
  );

  print('--- ⑥ §9.1 红线：上行载荷里**没有**可承载权益的字段 ---');
  final scanned = <String, Map<String, Object?>>{
    'contribution.toMap()': rec.toMap(),
    'contribution.toWireMap()': wire,
    'contribution.logLeafBytes()': _asMap(utf8.decode(rec.logLeafBytes())),
  };
  var allClean = true;
  for (final e in scanned.entries) {
    final bad = _forbiddenIn(e.value);
    if (bad.isNotEmpty) allClean = false;
    check(bad.isEmpty, '${e.key} 无禁区字段');
  }
  check(allClean,
      '★ §9.1 结构断言：上行/落库/叶子 三处的字段清单里都没有 '
      'balance/owner/redeem/transfer/payout 之类的可权益字段');
  check(!wire.containsKey('score'),
      '★ 累计声望是**派生值**，任何一端都不得把它变成可传输字段（否则红线当场失守）');

  // 源码级：贡献账本里不得出现转让/兑现类方法名
  final ledgerSrc = File('lib/core/contribution_ledger.dart').readAsStringSync();
  final transferLike = RegExp(
      r'(Future<[^>]*>|void)\s+(transfer|redeem|payout|sell|cashOut)[A-Za-z]*\s*\(');
  check(!transferLike.hasMatch(ledgerSrc),
      '★ 源码级：contribution_ledger.dart 无 transfer*/redeem*/payout*/sell* 方法');

  // 源码级：新表的 DDL 里不得出现权益类列名
  final dbSrc = File('lib/core/db_helper.dart').readAsStringSync();
  final ddlStart = dbSrc.indexOf('CREATE TABLE IF NOT EXISTS hub_outbox');
  check(ddlStart > 0, 'hub_outbox 建表 DDL 存在（迁移 v33）');
  final ddlClose = dbSrc.indexOf("'''", ddlStart);
  final ddl = ddlClose > ddlStart ? dbSrc.substring(ddlStart, ddlClose) : '';
  final ddlBad = kForbiddenKeys.where((k) => ddl.contains(' $k ')).toList();
  check(ddl.isNotEmpty && ddlBad.isEmpty,
      '★ hub_outbox DDL 无权益类列名（表里物理上装不下"余额"）');

  // =========================================================================
  print('--- ⑦ 房间角色：上行前的签名升级（fail-closed） ---');
  final unsigned = RoomRoleGrant(
    roomId: 'room-alpha',
    agentId: 'bob',
    role: RoomRoleKind.cohost,
    grantedBy: 'alice',
    atMs: kNow,
  );
  check(!unsigned.isSigned, '前置：服务层造出的 grant 是**未签名**的（本地判定不需要签名）');
  check(await RoomRoleAuthority.signGrant(
          g: unsigned, agentPub: null, granterPub: alice.pub,
          sign: alice.sign) ==
      null,
      '★ 拿不到被授予人公钥 → **诚实返回 null**（不用 Agent ID 冒充公钥）');
  check(await RoomRoleAuthority.signGrant(
          g: unsigned, agentPub: '  ', granterPub: alice.pub,
          sign: alice.sign) ==
      null,
      '★ 空白公钥 → 同样拒绝（不做"看起来接上了"的兜底）');
  check(await RoomRoleAuthority.signGrant(
          g: unsigned, agentPub: bob.pub, granterPub: '',
          sign: alice.sign) ==
      null,
      '拿不到授予人公钥 → null');

  final signed = await RoomRoleAuthority.signGrant(
    g: unsigned,
    agentPub: bob.pub,
    granterPub: alice.pub,
    sign: alice.sign,
  );
  check(signed != null && signed.isSigned, '双方公钥齐备 → 升级成可上行的签名 grant');
  check(signed != null && signed.sig.isNotEmpty, '签名非空');
  final v = await RoomRoleAuthority.verify(signed!);
  check(v.ok, '★ 升级后的 grant 能通过本层验签（Hub 侧用同一份协议包会得同一结论）');
  final grantWire = signed.toSignedMap();
  check(grantWire['granter_pub'] == alice.pub && grantWire['agent_pub'] == bob.pub,
      '线格式带上双方公钥（Hub 的 roomRoleVerify 与 granter_pub_mismatch 检查都要用）');
  check(_forbiddenIn(grantWire).isEmpty, '★ 角色线格式同样无禁区字段');
  check(signed.canonical() != signed.toMap().toString(),
      '签名载荷（canonical）与本地列名（toMap）是两套口径，未混用');

  // =========================================================================
  print('--- ⑧ 留跨语言探针（供 tool/verify_hub_write.js 消费） ---');
  final leafHash = await TransparencyLog.leafHashOf(rec.logLeafBytes());
  final probe = {
    'contribution_wire': wire,
    'contribution_canonical': rec.canonical(),
    'contribution_leaf_hash': leafHash,
    'contribution_key': rec.key,
    'contribution_leaf_json': utf8.decode(rec.logLeafBytes()),
    'role_grant_wire': grantWire,
    'role_canonical': signed.canonical(),
    'role_leaf_json': utf8.decode(signed.logBytes()),
    'wire_map_keys': wire.keys.toList(),
    'forbidden_keys_scanned': kForbiddenKeys,
  };
  File('tool/.hub_write_probe.json').writeAsStringSync(jsonEncode(probe));
  check(File('tool/.hub_write_probe.json').existsSync(),
      '探针文件已写出（tool/.hub_write_probe.json）');
  check(leafHash.isNotEmpty, '叶子哈希非空（第三方复算的输入）');

  // =========================================================================
  print('');
  print('================ App→Hub 上行接线校验：$_pass PASS / $_fail FAIL ================');
  // ★ `run_all_verify.dart` 用这个格式解析读数，别改名。
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exit(1);
}
