// 纯 Dart 校验脚本：M6 互介存证的**落库/入站/留痕**三条链路
// + §16 日志的追加口径 + **DDL 与序列化字段的漂移检查**。
// 运行：dart run tool/verify_attestation_persistence.dart
//
// 为什么单独一个脚本（与 verify_attestation.dart 分工）：
//   - verify_attestation.dart 管**密码学判定**（签名、等级、fail-closed）；
//   - 本脚本管**工程链路**：报文进出的路由纪律、只前进不后退的落库纪律、
//     每一步都进 §16 公开日志、以及"表结构没跟序列化字段走散"。
//
// 为什么 DDL 漂移检查放在这里而不是 SQL 集成测试里：
//   `sqflite` 走平台通道，`dart run` 跑不了；引入 `sqflite_common_ffi` 又需要
//   本机 sqlite3 原生库（客户机/CI 不一定有）。而这里要防的**最高风险缺陷**
//   恰恰不是 SQL 语法，而是"加了个 Dart 字段却忘了加列"——那种 bug 在真机上
//   表现为 `no such column`，在离线时完全可以用源文本比对提前抓住。

import 'dart:convert';
import 'dart:io';

import 'package:dahuang_ai/core/attestation_service.dart';
import 'package:dahuang_ai/core/circle_service.dart' show Ed25519Signer;
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

const int kT0 = 1800000000000;
const String kRoom = 'lisbon-night';
const String kCircle = 'cA';

final List<Map<String, Object?>> _events = [];

/// 一台虚拟设备：独立密钥 + 独立账本 + 独立服务 + 独立的 §16 日志视图。
class Device {
  final String id;
  final Ed25519Signer signer;
  final MemoryAttestationStore store = MemoryAttestationStore();

  /// §16 日志视图（内存模拟 `DbTransparencyLog.appendOnce`）。
  final List<String> logLeafHashes = [];

  late final AttestationService svc;
  late final IntroRelay relay;

  Device(this.id, this.signer) {
    svc = AttestationService(
      store: store,
      signer: signer,
      selfId: () async => id,
      onEvent: (n, p) => _events.add({'name': n, 'actor': id, ...p}),
      onAdvance: _appendLog,
    );
    relay = IntroRelay(
      store: store,
      selfId: () async => id,
      onEvent: (n, p) => _events.add({'name': n, 'actor': id, ...p}),
      onAdvance: _appendLog,
      send: (target, wire) async => true, // 本脚本手动投递，不需要真通道
    );
  }

  /// 与 `DbTransparencyLog.appendOnce` 同款：**同哈希只追加一次**。
  Future<void> _appendLog(IntroAttestation a) async {
    final h = await TransparencyLog.leafHashOf(a.logLeafBytes());
    if (!logLeafHashes.contains(h)) logLeafHashes.add(h);
  }

  Future<String> get pub => signer.publicKeyBase58();
}

bool _hasEvent(String name) => _events.any((e) => e['name'] == name);

/// 从源码里抠出 `CREATE TABLE IF NOT EXISTS <table>(...)` 的列名集合。
/// 用它比对"表结构"与"Dart 序列化字段"是否一一对应。
Set<String> _ddlColumns(String src, String table) {
  final m = RegExp('CREATE TABLE IF NOT EXISTS $table\\(([\\s\\S]*?)\\n\\s*\\)\\s*\'\'\'')
      .firstMatch(src);
  if (m == null) return {};
  final out = <String>{};
  for (final raw in m.group(1)!.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    // 表级约束不是列
    if (line.startsWith('PRIMARY KEY ') ||
        line.startsWith('FOREIGN KEY') ||
        line.startsWith('UNIQUE(') ||
        line.startsWith('CHECK')) {
      continue;
    }
    final name = line.split(RegExp(r'\s+')).first;
    if (name.isNotEmpty) out.add(name);
  }
  return out;
}

Future<void> main() async {
  final alice = Device('AG-alice', await Ed25519Signer.generate());
  final bob = Device('AG-bob', await Ed25519Signer.generate());
  final evil = Device('AG-evil', await Ed25519Signer.generate());
  final carol = Device('AG-carol', await Ed25519Signer.generate());

  // =====================================================================
  print('--- ① 入站 proposal：解析即验收 → 落库（但绝不同意）---');
  final a0 = await alice.svc.propose(
    counterpartyId: bob.id,
    circleId: kCircle,
    roomId: kRoom,
    topic: '同房间聊得来，都想聊结构风洞',
    nowMs: kT0,
  );

  check(!await bob.relay.onIncoming(bob.id, '今天天气不错'), '不是互介报文 → 返回 false（放行给别的处理器）');
  check(await bob.relay.onIncoming(alice.id, IntroWire.encodeProposal(a0)),
      '对端收到 proposal → 返回 true（已消费）');
  final bStored = await bob.store.byId(a0.id);
  check(bStored != null, '对端账本已落库');
  check(bStored?.state == IntroState.proposed, '落库状态 = proposed');
  check((await bob.store.byId(a0.id))?.consentedAtMs == null,
      '❗入站**绝不代客同意**（consentedAt 仍为空，等你点）');
  check(_hasEvent('intro_received'), '留痕：intro_received');

  // =====================================================================
  print('--- ② 路由纪律：四种冒充/错投都必须消费并丢弃 ---');
  // 2.1 冒充发起方：evil 把 alice 的发起段当作自己发的投过来
  final before = (await bob.store.involving(bob.id)).length;
  check(await bob.relay.onIncoming(evil.id, IntroWire.encodeProposal(a0)),
      '冒充发起方 → 仍返回 true（消费掉，不能变成聊天消息）');
  final aForged = a0.copyWith(); // 造一条"发起方是 alice 但由第三方投递"的等价情形
  check(aForged.initiatorId == alice.id, '（前提）该报文发起方确实是 alice');
  check(await bob.relay.onIncoming(carol.id, IntroWire.encodeProposal(a0)),
      '第三方转发 → 返回 true');
  check((await bob.store.involving(bob.id)).length == before,
      '冒充/转发都没有额外落库（账本行数未变）');

  // 2.2 错投：bob 的记录（对端是 bob）投到 carol
  check(await carol.relay.onIncoming(alice.id, IntroWire.encodeProposal(a0)),
      '错投给无关方 → 返回 true（消费）');
  check(await carol.store.byId(a0.id) == null, '无关方账本**没有**这条记录（misrouted 丢弃）');
  check(_hasEvent('intro_dropped'), '留痕：intro_dropped');

  // 2.3 自回环：alice 收到自己发的 proposal
  check(await alice.relay.onIncoming(alice.id, IntroWire.encodeProposal(a0)),
      '自回环 → 返回 true');
  check(await alice.store.byId(a0.id) != null, '（前提）alice 本地本来就有这条（自己发的）');

  // 2.4 签名被改坏 → 形状像互介报文，但验不过 → 消费并丢弃
  final badJson = jsonDecode(IntroWire.encodeProposal(a0)) as Map<String, dynamic>;
  final inner = Map<String, dynamic>.from(badJson['a'] as Map);
  inner['initiator_sig'] = 'AAAA'; // 破坏发起签名
  badJson['a'] = inner;
  check(await bob.relay.onIncoming(alice.id, jsonEncode(badJson)),
      '验签失败的报文 → 仍返回 true（已消费，不进聊天流水线）');
  check(_events.any((e) => e['name'] == 'intro_dropped' && e['reason'] == 'unverifiable'),
      '留痕：unverifiable');

  // =====================================================================
  print('--- ③ 同意回传 → 发起方账本拿到"双方互允" → 漏斗看得见 ---');
  final consentedOrNull = await bob.svc.consent(a0, nowMs: kT0 + 1000);
  check(consentedOrNull != null, '对端签出同意');
  // 显式定型：不依赖 `!` 的隐式提升，读起来也少一层心智负担。
  final consented = consentedOrNull!;
  check(await alice.relay.onIncoming(bob.id, IntroWire.encodeUpdate(consented)),
      '同意报文回到发起方 → 返回 true');
  final aStored = await alice.store.byId(a0.id);
  check(aStored != null && aStored.consentedAtMs != null,
      '发起方账本已升级为 consented（对端签名回传成功）');
  check(_hasEvent('intro_updated'), '留痕：intro_updated');

  final ledger = await alice.svc.myVerifiedLedger();
  check(ledger.length == 1, '发起方履历 1 条');
  check(ledger.first.$2.trust == IntroTrust.consented,
      '履历里这条的**验证等级** = consented（不是自称）');

  final funnel = await alice.svc.myFunnel();
  check(funnel.proposed == 1 && funnel.consented == 1,
      '漏斗：proposed=1, consented=1（只统计验过双方同意的）');
  check(funnel.settled == 0 && funnel.inFlight == 1, '在途 1 条（还没落结果）');

  // =====================================================================
  print('--- ④ 只前进不后退：重放低阶段报文不得回滚记录 ---');
  // 用一个干净的二人组做这个实验。为什么必须"发起方重放自己的 proposal"：
  // 若由第三方投递，报文会**先**被判 sender_mismatch（见下面补验），
  // 根本走不到 stale_stage 那一关 —— 那样测的就不是这条纪律。
  final dave = Device('AG-dave', await Ed25519Signer.generate());
  final erin = Device('AG-erin', await Ed25519Signer.generate());
  final d0 = await dave.svc.propose(
    counterpartyId: erin.id,
    circleId: kCircle,
    topic: '重放实验',
    nowMs: kT0,
  );
  check(await erin.relay.onIncoming(dave.id, IntroWire.encodeProposal(d0)),
      '（前提）erin 收到 dave 的发起段');
  final e1 = await erin.svc.consent(d0, nowMs: kT0 + 500);
  check(e1 != null, '（前提）erin 已互允');
  final eStored = await erin.store.byId(d0.id);
  check(eStored?.consentedAtMs != null, '（前提）erin 本地记录已到 consented');

  check(await erin.relay.onIncoming(dave.id, IntroWire.encodeProposal(d0)),
      '发起方重放旧的 proposal → 返回 true（消费）');
  final afterReplay = await erin.store.byId(d0.id);
  check(afterReplay?.consentedAtMs != null,
      '❗记录**没有**被打回 proposed（stale_stage 被拒）');
  check(afterReplay?.stage == eStored?.stage, '阶段未回滚');
  check(_events.any((e) => e['name'] == 'intro_dropped' && e['reason'] == 'stale_stage'),
      '留痕：stale_stage');

  // 补验：由**非发起方**投来的 proposal 先被判 sender_mismatch（同样是丢弃）
  check(await alice.relay.onIncoming(bob.id, IntroWire.encodeProposal(a0)),
      '非发起方投来的 proposal → 返回 true（消费）');
  check(_events.any((e) => e['name'] == 'intro_dropped' && e['reason'] == 'sender_mismatch'),
      '留痕：sender_mismatch（冒充发起方更早被拦）');
  check((await alice.store.byId(a0.id))?.consentedAtMs != null,
      'alice 的记录同样未被回滚');

  // 纯函数口径本身也要立得住（所有 store 实现共用这一条）
  check(shouldAcceptUpsert(null, a0), '无既有记录 → 接受');
  check(shouldAcceptUpsert(a0, consented), '低 → 高 → 接受');
  check(!shouldAcceptUpsert(consented, a0), '高 → 低 → **拒绝**');
  check(shouldAcceptUpsert(consented, consented), '同阶段 → 接受（幂等覆盖）');

  // 内存实现也必须真的遵守它（否则"测试过、生产回滚"）
  final mem = MemoryAttestationStore();
  await mem.upsert(consented);
  await mem.upsert(a0);
  check((await mem.byId(a0.id))?.consentedAtMs != null,
      'MemoryAttestationStore 也遵守只前进不后退');

  // =====================================================================
  print('--- ⑤ §16 透明日志：每一步都追加一片叶子（且可独立复算）---');
  check(alice.logLeafHashes.length >= 2,
      '发起 + 互允两步 → 至少 2 片叶子（每推进一次留一痕）');
  check(alice.logLeafHashes.toSet().length == alice.logLeafHashes.length,
      '叶子哈希无重复（appendOnce 幂等）');
  check(bob.logLeafHashes.isNotEmpty, '对端侧也留了痕（收到 proposal 即入日志）');

  // 叶子可由记录独立复算 —— 这是"第三方只凭记录就能验"的前提
  final recomputed = await TransparencyLog.leafHashOf(a0.logLeafBytes());
  check(alice.logLeafHashes.contains(recomputed),
      '发起那一步的叶子哈希，第三方凭记录**可以自己算出来**');
  final recomputed2 = await TransparencyLog.leafHashOf(consented.logLeafBytes());
  check(alice.logLeafHashes.contains(recomputed2),
      '互允那一步的叶子哈希同样可独立复算');

  // 叶子不得包含自由文本（topic）—— 公开账本不承载隐私字段
  final leafText = utf8.decode(a0.logLeafBytes());
  check(!leafText.contains('结构风洞'), '叶子**不含** topic 自由文本（公开账本不做围观）');
  check(!leafText.contains(kRoom), '叶子不含房间 id 之外的私密文本');
  check(leafText.startsWith('IA|${a0.id}|'), '叶子以记录 id 开头（可定位到具体记录）');
  check(leafText.contains('did:wold:'), '叶子含双方 did:wold（身份可被独立验证）');

  // 用真实 Merkle 树验证：这两片叶子确实能验出包含证明
  final log = TransparencyLog();
  for (final h in alice.logLeafHashes) {
    await log.appendLeafHash(h);
  }
  final root = await log.root();
  var okInclusion = true;
  for (var i = 0; i < alice.logLeafHashes.length; i++) {
    final proof = await log.inclusionProof(i);
    final ok = await MerkleVerify.inclusion(
      leaf: a0.logLeafBytes(),
      proof: proof,
      root: root,
    );
    // 只对"叶子确实等于 a0 那一叶"的位置要求通过；其余位置应验不过（内容不同）
    if (alice.logLeafHashes[i] == recomputed) {
      if (!ok) okInclusion = false;
    }
  }
  check(okInclusion, '§16：互介叶子的包含证明在该期根下验得过');

  // =====================================================================
  print('--- ⑥ DDL ↔ 序列化字段：不得漂移 ---');
  final dbSrc = File('lib/core/db_helper.dart').readAsStringSync();

  final attCols = _ddlColumns(dbSrc, 'attestations');
  final attMapKeys = IntroAttestation(
    id: 'ia_x',
    initiatorId: 'a',
    counterpartyId: 'b',
    initiatedAtMs: 1,
    initiatorPub: 'p',
    initiatorSig: 's',
  ).toMap().keys.toSet();
  check(attCols.isNotEmpty, '（前提）解析到 attestations 表结构');
  final missingCols = attMapKeys.difference(attCols);
  final extraCols = attCols.difference(attMapKeys);
  check(missingCols.isEmpty,
      '序列化字段全都有对应列（缺列会在真机报 no such column）→ 缺 ${missingCols.toList()}');
  check(extraCols.isEmpty, '没有多余的死列 → 多 ${extraCols.toList()}');
  check(attCols.length == attMapKeys.length,
      'attestations 列数 = 字段数 = ${attMapKeys.length}');

  final logCols = _ddlColumns(dbSrc, 'log_entries');
  final logKeys = const LogEntry(
    index: 0,
    leafHash: 'l',
    prevHash: '',
    hash: 'h',
  ).toMap().keys.toSet();
  check(logCols.isNotEmpty, '（前提）解析到 log_entries 表结构');
  check(logCols.difference(logKeys).isEmpty && logKeys.difference(logCols).isEmpty,
      'log_entries 表结构与 LogEntry 字段一一对应');
  check(!logCols.contains('leaf') && !logCols.contains('payload'),
      '❗日志**只存哈希**，没有叶子原文列（否则"公开账本"会变成"公开内容"）');

  // 版本号必须与迁移表**最大键**一致。历史上正是这里不一致（`onCreate` 里写死
  // `15..19`，`onUpgrade` 却对），导致 v20 的 `circles` 表在**全新安装**时
  // 根本不会被创建 —— 只在"新用户"身上炸，最难查的那种。
  final verM = RegExp(r'schemaVersion\s*=\s*(\d+)').firstMatch(dbSrc);
  final migKeys = RegExp(r'^\s*(\d+): _migrateV\d+,', multiLine: true)
      .allMatches(dbSrc)
      .map((m) => int.parse(m.group(1)!))
      .toList()
    ..sort();
  check(verM != null, '（前提）解析到 schemaVersion 常量');
  check(migKeys.isNotEmpty, '（前提）解析到迁移表键');
  final declared = int.parse(verM!.group(1)!);
  check(declared == migKeys.last,
      'schemaVersion($declared) == 迁移表最大键(${migKeys.last})');
  check(migKeys.contains(26), 'V26 已注册进迁移表');
  check(migKeys.contains(27), 'V27 已注册进迁移表（M10 房间角色）');

  // 建库/升级只能有一份实现：分开写必然漂移（上面那个缺陷就是这么来的）
  final seedCalls =
      RegExp(r'_createTablesAndSeed\(db\)').allMatches(dbSrc).length;
  check(seedCalls == 1, '建表播种只有一处调用点（onCreate 不再自己实现一遍）');
  check(!dbSrc.contains('for (var v = oldVersion + 1;'),
      'onUpgrade 不再自己写循环（统一走 migrate）');
  check(RegExp(r'onCreate[\s\S]{0,80}?migrate\(db, from: 0, to: version\)')
          .hasMatch(dbSrc) &&
      RegExp(r'onUpgrade[\s\S]{0,80}?migrate\(db, from: oldVersion, to: newVersion\)')
          .hasMatch(dbSrc),
      'onCreate / onUpgrade 都转发到 migrate（三条路径共用一份逻辑）');

  // =====================================================================
  print('--- ⑦ 线格式边界 ---');
  check(!IntroWire.isIntro('x' * (IntroWire.maxWireChars + 1)), '超长报文 → 不算互介报文');
  check(await IntroWire.tryParse('x' * (IntroWire.maxWireChars + 1)) == null,
      '超长报文解析为 null（拒绝）');
  check(await IntroWire.tryParse('{"da_type":"intro_attestation","v":1,"kind":"proposal","a":{}}') ==
          null,
      '字段残缺的报文解析为 null');
  check(await IntroWire.tryParse('{"da_type":"intro_attestation","v":99,"kind":"proposal","a":{}}') ==
          null,
      '版本号不匹配 → 拒绝（向前兼容不靠猜）');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) {
    throw StateError('verification failed');
  }
}
