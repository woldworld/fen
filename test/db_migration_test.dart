// **真引擎**迁移/stores 验证：在真实 SQLite 上跑一遍生产**同一份**迁移链，
// 并把真实的 `DbAttestationStore` / `DbTransparencyLog` 接到真库上跑端到端。
//
// 运行（★ 一律走这个入口，它会自动剥掉代理，见文末踩坑说明）：
//   dart run tool/run_flutter_test.dart -- test/db_migration_test.dart
//
// ## 为什么这个测试值得存在
// `DBHelper._initDB` 的 `onCreate` 曾经写死 `15..19`，而 `onUpgrade` 写的是全量 ——
// 于是**老用户升级路径正确、新用户全新安装炸**（v20 的 `circles` 表压根没建）。
// 这种缺陷静态分析看不出、肉眼也看不出，**只有"真的从零建一遍库"才能发现**。
//
// 它第一次跑起来就抓到了三处"静态全绿但真机错"的缺陷（都值得记住）：
// ① **迁移单点化**：onCreate/onUpgrade 各写一份 → 漂移。现在共用 `DBHelper.migrate`。
// ② **叶子不带 stage**：`logLeafBytes()` 只用 `state` 时，"已落结果"与"对方追认"
//    算出**同一片叶子** → `appendOnce` 幂等去重 → **追认在公开日志里不留痕**，
//    与"每推进一次留一痕"的承诺不符。修法：叶子里加上 `$stage`。
// ③ **链自检是同义反复**：`DbTransparencyLog.load()` 逐条 `appendLeafHash` 会
//    **重算** hash，于是 `verifyChain()` 两边都由同一份被篡改的 leaf_hash 现算 →
//    恒真 → 改一行/删一行全都查不出来。修法：`TransparencyLog.fromEntries`
//    播种时**保留持久化 hash**。（顺带把"截断查不出"这条能力边界也钉住了。）
//
// ## 为什么不能用 `dart run`（踩过）
// `package:sqflite/sqflite.dart` → `src/factory_impl.dart` → `package:flutter/foundation.dart`
// → `dart:ui`，而独立 Dart VM 没有 `dart:ui`，直接编译失败：
//   `Error: Dart library 'dart:ui' is not available on this platform.`
// 所以凡是要 import 到 `DBHelper` / `Db*Store` 的验证，**必须跑在 flutter test 宿主里**。
// 纯 Dart 能跑的只有"读源码做文本比对"那一路（见 tool/verify_attestation_persistence.dart）。
//
// ## 本机 `flutter test` 必须剥代理（踩过，否则一条都跑不了）
// 环境里的 `HTTP_PROXY/HTTPS_PROXY` 会把 flutter_tester 的**本机 WebSocket**
// 也代理掉，报 `WebSocketException: Invalid WebSocket upgrade request`。
// ★ 0.108.0 起：剥代理**已固化进唯一入库入口** `tool/run_flutter_test.dart`
//   （守卫 `tool/verify_regression_entry.dart` 会真起子进程验证它确实剥干净了）。
//   ⇒ 别再手敲 `env -u ...`：手敲版在 0.89.0 之后**每个版本都要重踩一遍**（0.106/0.107 都踩了）。
//
// ## sqlite3 到底怎么被加载的（踩过，别再去手工找 dll）
// 早期 `sqlite3` 包有 `package:sqlite3/open.dart`（`open.overrideFor(...)`）。
// **3.x 之后这个库被删了**，改成 Dart 的 **native assets**：
// `libsqlite3.g.dart` 上写着 `@ffi.DefaultAsset('package:sqlite3/src/ffi/libsqlite3.g.dart')`，
// 由包自带的构建钩子 `hook/build.dart` 下载/编译出动态库，并落到
//   `.dart_tool/lib/sqlite3.dll`（JIT 模式）+ `.dart_tool/native_assets.yaml`
// 然后 `@Native` 自己在运行时解析。所以在 flutter test 宿主里**什么都不用配**：
// 只要 import 了 `sqflite_common_ffi`，跑一次 `flutter test` 就会把 dll 备好。
// 血的教训：写 `import 'package:sqlite3/open.dart'` 会直接**编译失败**
// （`Error when reading .../sqlite3-3.5.2/lib/open.dart: 系统找不到指定的文件`）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/attestation_service.dart';
import 'package:dahuang_ai/core/attestation_store_db.dart';
import 'package:dahuang_ai/core/circle_service.dart' show Ed25519Signer;
import 'package:dahuang_ai/core/contribution_ledger.dart';
import 'package:dahuang_ai/core/contribution_store_db.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:dahuang_ai/core/transparency_log.dart';
import 'package:dahuang_ai/core/reputation_network.dart';
import 'package:dahuang_ai/core/reputation_network_store_db.dart';
import 'package:dahuang_ai/core/trial_gateway.dart';
import 'package:dahuang_ai/core/trial_store_db.dart';
import 'package:dahuang_ai/core/transparency_store_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kT0 = 1800000000000;

late Directory _tmp;

/// 打开一个库并让 `DBHelper.migrate` 负责建/升 —— 与生产完全同一条路径。
Future<Database> _open(String path, int version) => databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, v) => DBHelper.migrate(db, from: 0, to: v),
        onUpgrade: (db, o, n) => DBHelper.migrate(db, from: o, to: n),
      ),
    );

Future<List<String>> _columns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((r) => (r['name'] ?? '').toString()).toList();
}

Future<List<String>> _tables(Database db) async {
  final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
  return rows.map((r) => (r['name'] ?? '').toString()).toList();
}

Future<int> _userVersion(Database db) async =>
    ((await db.rawQuery('PRAGMA user_version')).first.values.first as int);

/// 复刻护照页 `_loadAnchors()` 的口径：本地分（`agent_friends`）×
/// 接缝表（`agent_pubkeys`）→ 网络锚点。
///
/// 两处口径必须一致：UI 里显示的锚点数与这里算出来的不同，就是"看着有网络、
/// 其实查谁都 unknown"这类静默失效。
Future<Map<String, double>> _anchorsFrom(Database db) async {
  final scoreRows =
      await db.query('agent_friends', columns: ['agent_id', 'reputation']);
  final scoreById = <String, int>{};
  for (final r in scoreRows) {
    final id = (r['agent_id'] as String?) ?? '';
    if (id.isEmpty) continue;
    scoreById[id] = (r['reputation'] as num?)?.toInt() ?? 50;
  }
  final pubRows = await db.query('agent_pubkeys', columns: ['agent_id', 'pubkey']);
  final pubById = <String, String>{};
  for (final r in pubRows) {
    final id = (r['agent_id'] as String?) ?? '';
    final pub = (r['pubkey'] as String?) ?? '';
    if (id.isEmpty || pub.isEmpty) continue;
    pubById[id] = pub;
  }
  return ReputationBridge.anchorsFrom(scoreById: scoreById, pubById: pubById);
}

/// 真签名背书（私钥不出设备，与生产 UI 同款）。
Future<Endorsement> _signedEndorsement(
    Ed25519Signer signer, String issuerPub, String subjectPub, String tier) async {
  final draft = Endorsement(
    issuerPub: issuerPub,
    subjectPub: subjectPub,
    tier: tier,
    issuedAtMs: kT0,
    expiresAtMs: kT0 + ReputationCaps.endorsementValidDays * 86400000,
    note: '',
  );
  return draft.copyWith(sig: await signer.signBytes(draft.canonicalBytes()));
}

void main() {
  setUpAll(() {
    // sqlite3 的动态库由 `sqlite3` 包的构建钩子（native assets）自动备好，
    // 落在 `.dart_tool/lib/sqlite3.dll` —— 这里**不需要**任何手工路径配置。
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _tmp = Directory.systemTemp.createTempSync('wold_db_test_');
  });

  tearDownAll(() {
    try {
      _tmp.deleteSync(recursive: true);
    } catch (_) {
      // 临时目录清理失败不影响结论
    }
  });

  tearDown(() => DBHelper.detachDbForTest());

  // ===================================================================
  test('引擎就绪：真 SQLite，而不是"看起来像"', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    final rows = await db.rawQuery('SELECT sqlite_version() AS v');
    final v = (rows.first['v'] ?? '').toString();
    await db.close();
    expect(v, isNotEmpty);
    // 说明本机的版本高于 Android 10 自带的 3.22；"这里能跑" ≠ "旧机能跑"。
    // 旧机兼容靠的是 DDL 只用 CREATE TABLE/INDEX IF NOT EXISTS + INSERT OR REPLACE。
    print('SQLite 引擎版本：$v');
  });

  test('全新安装（from=0 → 当前 schemaVersion）：所有历史迁移的产物都必须在', () async {
    final db = await _open('${_tmp.path}/fresh.db', DBHelper.schemaVersion);

    expect(await _userVersion(db), DBHelper.schemaVersion);

    final tables = await _tables(db);
    // 每个迁移版本的代表性产物 —— 这就是"onCreate 写死范围"会漏掉的东西
    const expected = <String, String>{
      'circles': 'v20（历史缺陷的受害者，必须仍被覆盖）',
      'did_issuance': 'v22',
      'intercards': 'v23',
      'peer_presence': 'v24',
      'self_intro_ledger': 'v24',
      'room_presences': 'v25',
      'bridge_links': 'v25',
      'attestations': 'v26 ★',
      'log_entries': 'v26 ★',
      'room_roles': 'v27 ★',
      'skill_listings': 'v28 ★',
      'skill_revoked': 'v28 ★',
      'payout_ledger': 'v28 ★',
      'trial_quotas': 'v29 ★ 额度落库',
      'trial_usage': 'v29 ★ 消费账本',
      'endorsements': 'v30 ★ 签名背书',
      'endorsement_revoked': 'v30 ★ 背书吊销',
      'agent_pubkeys': 'v31 ★ 本地信誉↔网络信誉的接缝',
      'contribution_records': 'v32 ★ 可验证贡献账本（只追加）',
      'founding_members': 'v32 ★ 创始成员声明',
      'price_lock_claims': 'v32 ★ 永久价格锁定（定价权）',
      'key_rotations': 'v34 ★ 身份换钥（只追加；旧钥退休记录）',
      'peer_summaries': 'v35 ★ 私聊滚动摘要（按 peer 压缩更早对话）',
      'room_summaries': 'v36 ★ 会客厅滚动摘要（按房间压缩更早对话）',
      'mail_accounts': 'v37 ★ 邮箱账号（**刻意无凭据列**）',
      'mail_seen': 'v37 ★ 邮箱已读游标',
      'mail_outbox': 'v37 ★ 邮箱出站台账（只存摘要）',
    };
    for (final e in expected.entries) {
      expect(tables, contains(e.key), reason: '全新安装缺表 ${e.key}（${e.value}）');
    }

    // v27 房间角色：列必须与 RoomRoleGrant.toMap() 一一对应（缺列 = 真机 no such column）
    final roleCols = await _columns(db, 'room_roles');
    expect(roleCols..sort(), ['agent_id', 'at_ms', 'granted_by', 'role', 'room_id']);
    // 铁律 1 的物理形式：**没有**任何"账号级/全局"角色列
    for (final forbidden in const ['scope', 'global', 'is_global']) {
      expect(roleCols, isNot(contains(forbidden)),
          reason: 'room_roles 不得有 $forbidden 列（角色只能属于房间）');
    }

    // v28 技能注册表：列必须与 toMap() 一一对应（缺列 = 真机 no such column）
    final skillCols = await _columns(db, 'skill_listings');
    expect(skillCols..sort(), [
      'author_id', 'author_pub', 'capabilities', 'content_hash', 'currency',
      'description', 'name', 'price_cents', 'published_at', 'risk', 'sig',
      'skill_id', 'version', //
    ]);
    final revCols = await _columns(db, 'skill_revoked');
    expect(revCols..sort(),
        ['at_ms', 'author_pub', 'reason', 'sig', 'skill_id', 'version']);
    final payCols = await _columns(db, 'payout_ledger');
    expect(payCols..sort(), [
      'amount_cents', 'at_ms', 'author_cents', 'author_pub', 'buyer_id',
      'platform_cents', 'purchase_id', 'referrer_cents', 'referrer_id',
      'skill_id', 'version', //
    ]);
    // PRD §9.1 红线落到字段层：账本**没有**任何多级返利列
    for (final forbidden in const ['level', 'upline', 'parent', 'inviter_chain']) {
      expect(payCols, isNot(contains(forbidden)),
          reason: 'payout_ledger 不得有 $forbidden 列（分成只做一层）');
    }
    expect(payCols, contains('referrer_id'), reason: '至多一个推荐人（一层）');

    // v29 试用额度：列必须与 toMap() 一一对应（缺列 = 真机 no such column）
    final quotaCols = await _columns(db, 'trial_quotas');
    expect(quotaCols..sort(), [
      'agent_id', 'budget_cents', 'expires_at', 'granted_at', 'granted_turns',
      'purpose', 'revoked_at', 'spent_cents', 'used_turns', //
    ]);
    // 金额闸必须落库：只记条数的话，"重启即归零"可以刷穿额度
    expect(quotaCols, contains('spent_cents'),
        reason: '额度表必须有金额口径（PRD §9.1 的缓释措施就是"极小额度"）');
    final usageCols = await _columns(db, 'trial_usage');
    expect(usageCols..sort(), [
      'agent_id', 'at_ms', 'call_id', 'completion_tokens', 'cost_cents',
      'model', 'prompt_tokens', 'provider', 'purpose', //
    ]);

    // v30 网络信誉：列必须与 toMap() 一一对应（缺列 = 真机 no such column）
    final endCols = await _columns(db, 'endorsements');
    expect(endCols..sort(), [
      'expires_at', 'issued_at', 'issuer_pub', 'note', 'sig', 'subject_pub', 'tier', //
    ]);
    // ★ 主体是**公钥**不是 ID：换一次 ID 就能甩掉全部差评的"信誉洗白"写不进去
    expect(endCols, contains('subject_pub'));
    expect(endCols, isNot(contains('subject_id')));
    expect(endCols, contains('expires_at'), reason: '信任必须有终点');
    final endRevCols = await _columns(db, 'endorsement_revoked');
    expect(endRevCols..sort(), ['at_ms', 'issuer_pub', 'sig', 'subject_pub']);

    // v31 接缝表：本地信誉(agent_id) ↔ 网络信誉(pubkey) 唯一的桥。
    // 缺列 = 真机 no such column = 锚点永远空 = 网络背书写了也查不到。
    final keyCols = await _columns(db, 'agent_pubkeys');
    expect(keyCols..sort(), ['agent_id', 'at_ms', 'pubkey', 'source']);
    // ★ agent_id 是主键：一个人**只有一把当前钥匙**。
    //   挂出 N 把钥匙 = 在自己的背书网络里放大 N 倍（Sybil 形态），必须写不进去。
    await db.insert('agent_pubkeys',
        {'agent_id': 'AG-1', 'pubkey': 'P1', 'source': 'passport', 'at_ms': 1});
    expect(
      () => db.insert('agent_pubkeys',
          {'agent_id': 'AG-1', 'pubkey': 'P2', 'source': 'passport', 'at_ms': 2}),
      throwsA(isA<DatabaseException>()),
      reason: '★ 同一 agent_id 不能挂第二把钥匙（主键即不变式）',
    );
    await db.delete('agent_pubkeys', where: 'agent_id = ?', whereArgs: ['AG-1']);

    // v32 M10 五件套：列必须与 toMap() 一一对应（缺列 = 真机 no such column）
    final crCols = await _columns(db, 'contribution_records');
    expect(crCols..sort(), [
      'at_ms', 'attestor_pub', 'kind', 'note', 'ref', 'sig', 'subject_pub',
      'weight', //
    ]);
    // ★ PRD §9.1 / §4 M10 红线落到字段层：账本**没有**任何"转让 / 兑现 / 收益"列。
    //   一旦出现"可变现"，就从"权益"变成"证券"，本条全部作废。
    for (final forbidden in const [
      'owner_id', 'to_pub', 'receiver_pub', 'beneficiary', 'transfer',
      'transferable', 'redeem', 'redeem_at', 'cashout', 'cash_out', 'payout',
      'price_cents', 'face_value', 'yield', 'dividend', 'equity', 'shares',
      'sellable', 'resale', 'liquidate', //
    ]) {
      expect(crCols, isNot(contains(forbidden)),
          reason: 'contribution_records 不得有 $forbidden 列（否则退化成证券）');
    }
    // ★ 分值在列里且被签名覆盖 → 事后改分必被验签拦下（"当年的分永远是当年的分"）
    expect(crCols, contains('weight'));
    expect(crCols, contains('sig'));

    final fmCols = await _columns(db, 'founding_members');
    expect(fmCols..sort(), ['at_ms', 'pledge', 'sig', 'subject_pub']);
    expect(fmCols, contains('pledge'),
        reason: '声明必须绑定**承诺版本**，否则"我同意的是哪一版"无从判定');

    final plCols = await _columns(db, 'price_lock_claims');
    expect(plCols..sort(), [
      'discount_bps', 'effective_from', 'fee_waived', 'issuer_pub',
      'permanent', 'scope', 'sig', 'subject_pub', //
    ]);
    // 定价权**只有价格维度**：作用域 / 折扣 / 是否全免 / 生效时间。
    // 没有面值、没有可变现比例、没有受益人指定 → 结构上不是证券。
    for (final forbidden in const [
      'face_value', 'redeem_at', 'payout', 'beneficiary', 'transferable',
    ]) {
      expect(plCols, isNot(contains(forbidden)),
          reason: 'price_lock_claims 不得有 $forbidden 列（它只能是定价权）');
    }

    // v34 身份换钥：列必须与 IdentityRotation.toMap() 一一对应（缺列 = 真机 no such column）
    final krCols = await _columns(db, 'key_rotations');
    expect(krCols..sort(), [
      'agent_id', 'confirmed_by', 'new_pub', 'old_pub', 'recorded_at',
      'rotated_at', 'sig', //
    ]);
    // ★ §9.1 红线落在字段层：换钥记录里**没有**任何"转让 / 兑现 / 面值 / 受益人"列。
    //   换钥是**迁移**（旧钥自我退休），不是把权益转给别人 —— 这一点必须是结构，
    //   而不是一句"我们不允许转让"的承诺。
    for (final forbidden in const [
      'transferable', 'transferee', 'redeem', 'redeem_at', 'payout',
      'face_value', 'beneficiary', 'owner', 'balance',
    ]) {
      expect(krCols, isNot(contains(forbidden)),
          reason: 'key_rotations 不得有 $forbidden 列（换钥 ≠ 过户）');
    }
    // 主键 (agent_id, old_pub)：一把旧钥只能退休一次（真库验证，不靠代码自觉）。
    await db.insert('key_rotations', {
      'agent_id': 'AG-KR', 'old_pub': 'P-old', 'new_pub': 'P-new',
      'rotated_at': kT0, 'sig': 's', 'recorded_at': kT0, 'confirmed_by': 'local',
    });
    expect(
      () => db.insert('key_rotations', {
        'agent_id': 'AG-KR', 'old_pub': 'P-old', 'new_pub': 'P-newer',
        'rotated_at': kT0 + 1, 'sig': 's2', 'recorded_at': kT0 + 1,
        'confirmed_by': 'local',
      }),
      throwsA(isA<DatabaseException>()),
      reason: '★ 同一把旧钥只能退休一次（换到另一把新钥是冲突，不是覆盖）',
    );
    // 但**同一个身份**可以有多条换钥（旧钥不同 = 不同事件，可连续换钥）。
    await db.insert('key_rotations', {
      'agent_id': 'AG-KR', 'old_pub': 'P-new', 'new_pub': 'P-newest',
      'rotated_at': kT0 + 2, 'sig': 's3', 'recorded_at': kT0 + 2,
      'confirmed_by': 'local',
    });
    final krRows = await db.query('key_rotations',
        where: 'agent_id = ?', whereArgs: ['AG-KR']);
    expect(krRows.length, 2, reason: '★ 换钥是可连续的（第二次换钥的旧钥 = 第一次的新钥）');
    await db.delete('key_rotations', where: 'agent_id = ?', whereArgs: ['AG-KR']);

    // v35 私聊滚动摘要：列必须与 getPeerSummary/upsertPeerSummary 一一对应（缺列 = 真机 no such column）
    final psCols = await _columns(db, 'peer_summaries');
    expect(psCols..sort(),
        ['covered_until_id', 'peer_id', 'summary', 'updated_ms']);
    // 主键 peer_id：一个 peer 只留最新一份（重复摘要是覆盖，不叠出第二行）
    await db.insert('peer_summaries', {
      'peer_id': 'AG-PS', 'summary': 'v1', 'covered_until_id': 1, 'updated_ms': kT0,
    });
    await db.insert(
        'peer_summaries',
        {
          'peer_id': 'AG-PS', 'summary': 'v2', 'covered_until_id': 2,
          'updated_ms': kT0 + 1, //
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    final psRows = await db.query('peer_summaries',
        where: 'peer_id = ?', whereArgs: ['AG-PS']);
    expect(psRows.length, 1, reason: '★ 一个 peer 只留最新一份滚动摘要（主键即不变式）');
    expect(psRows.first['summary'], 'v2', reason: '后一次覆盖前一次');
    expect(psRows.first['covered_until_id'], 2, reason: '游标一并推进');
    await db.delete('peer_summaries', where: 'peer_id = ?', whereArgs: ['AG-PS']);

    // ★ 主键即不变式（真库验证，不靠代码自觉）：
    //   ① 同一件事（kind+subject+ref）写不进第二条；
    //   ② 一个人一辈子只有一条创始记录；
    //   ③ 一作用域一人只有一份定价权。
    await db.insert('contribution_records', {
      'kind': 'invite', 'subject_pub': 'P-a', 'ref': 'P-b',
      'attestor_pub': 'P-b', 'weight': 2, 'at_ms': kT0, 'note': '', 'sig': 's1',
    });
    expect(
      () => db.insert('contribution_records', {
        'kind': 'invite', 'subject_pub': 'P-a', 'ref': 'P-b',
        'attestor_pub': 'P-b', 'weight': 2, 'at_ms': kT0 + 1, 'note': '',
        'sig': 's2',
      }),
      throwsA(isA<DatabaseException>()),
      reason: '★ 同一件事写不进第二条（把一件事记十遍在存储层不成立）',
    );
    await db.insert('founding_members',
        {'subject_pub': 'P-a', 'pledge': 'v1', 'at_ms': kT0, 'sig': 's'});
    expect(
      () => db.insert('founding_members',
          {'subject_pub': 'P-a', 'pledge': 'v1', 'at_ms': kT0 + 1, 'sig': 's'}),
      throwsA(isA<DatabaseException>()),
      reason: '★ 一人只有一条创始记录',
    );
    await db.insert('price_lock_claims', {
      'scope': 'host_fee', 'subject_pub': 'P-a', 'issuer_pub': 'P-plat',
      'discount_bps': 3000, 'fee_waived': 0, 'effective_from': kT0,
      'permanent': 1, 'sig': 's',
    });
    expect(
      () => db.insert('price_lock_claims', {
        'scope': 'host_fee', 'subject_pub': 'P-a', 'issuer_pub': 'P-plat',
        'discount_bps': 9000, 'fee_waived': 0, 'effective_from': kT0,
        'permanent': 1, 'sig': 's2',
      }),
      throwsA(isA<DatabaseException>()),
      reason: '★ 一作用域一份定价权（重复发放是覆盖，不叠加出双倍折扣）',
    );
    await db.delete('contribution_records', where: 'subject_pub = ?', whereArgs: ['P-a']);
    await db.delete('founding_members', where: 'subject_pub = ?', whereArgs: ['P-a']);
    await db.delete('price_lock_claims', where: 'subject_pub = ?', whereArgs: ['P-a']);

    // ★ 声望分**不落库**：库里不存在任何"分数 / 余额"表。
    //   派生 + 只读 = 无处转让；一旦落库成可写的余额表，它立刻会长出转账接口。
    for (final t in tables) {
      expect(RegExp(r'(score|balance|points)').hasMatch(t), isFalse,
          reason: '不得存在"分数/余额"表（got: $t）');
    }

    final attCols = await _columns(db, 'attestations');
    expect(attCols.length, 18);
    for (final c in const [
      'id', 'initiator_id', 'counterparty_id', 'circle_id', 'room_id', 'topic',
      'initiated_at', 'initiator_pub', 'initiator_sig', 'consented_at',
      'counterparty_pub', 'counterparty_sig', 'outcome', 'outcome_by',
      'resolved_at', 'outcome_sig', 'ack_at', 'ack_sig', //
    ]) {
      expect(attCols, contains(c), reason: 'attestations 缺列 $c');
    }

    final idx = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_attest%'");
    expect(idx.length, 2, reason: '两条履历查询索引都要在（发起方侧 / 对端侧）');

    final logCols = await _columns(db, 'log_entries');
    expect(logCols..sort(), ['hash', 'idx', 'leaf_hash', 'prev_hash']);
    // 公开账本不承载内容：**没有**叶子原文列
    expect(logCols, isNot(contains('leaf')));
    expect(logCols, isNot(contains('payload')));

    // 幂等：重复执行迁移不该炸（IF NOT EXISTS 的意义）
    await DBHelper.migrate(db, from: 0, to: DBHelper.schemaVersion);
    expect(await _userVersion(db), DBHelper.schemaVersion);

    await db.close();
  });

  test('老库升级（v25 → v26）：新表建出来 + 老数据不能丢', () async {
    final path = '${_tmp.path}/upgrade.db';
    final v25 = await _open(path, 25);
    final before = await _tables(v25);
    expect(before, isNot(contains('attestations')), reason: '（前提）v25 库里没有它');
    expect(before, isNot(contains('log_entries')), reason: '（前提）v25 库里没有它');

    // 造一条"老用户的历史数据"，升级后必须还在
    await v25.insert('bridge_links', {
      'id': 'AG-a->AG-b',
      'self_id': 'AG-a',
      'peer_id': 'AG-b',
      'room_id': 'legacy-room',
      'my_circle_id': 'cLegacy',
      'at_ms': kT0,
    });
    await v25.close();

    final v26 = await _open(path, 26);
    expect(await _userVersion(v26), 26);
    final after = await _tables(v26);
    expect(after, contains('attestations'));
    expect(after, contains('log_entries'));
    final legacy = await v26.query('bridge_links',
        where: 'room_id = ?', whereArgs: ['legacy-room']);
    expect(legacy.length, 1, reason: '升级不得丢老数据');

    await v26.close();
  });

  test('老库升级（v26 → v27）：room_roles 建出来 + 老数据不能丢', () async {
    final path = '${_tmp.path}/upgrade_v27.db';
    final v26 = await _open(path, 26);
    final before = await _tables(v26);
    expect(before, isNot(contains('room_roles')), reason: '（前提）v26 库里没有它');
    // v26 的产物必须仍在
    expect(before, contains('attestations'));

    // 造一条"老用户的历史数据"（房间出现记录），升级后必须还在
    await v26.insert('room_presences', {
      'room_id': 'legacy-room',
      'agent_id': 'AG-a',
      'nickname': '老用户',
      'msg_count': 3,
      'last_seen': kT0,
    });
    await v26.close();

    final v27 = await _open(path, 27);
    expect(await _userVersion(v27), 27);
    final after = await _tables(v27);
    expect(after, contains('room_roles'), reason: 'v27 新表必须建出来');
    expect(after, contains('attestations'), reason: 'v26 产物不得消失');

    final legacy = await v27.query('room_presences',
        where: 'room_id = ?', whereArgs: ['legacy-room']);
    expect(legacy.length, 1, reason: '升级不得丢老数据');

    // 复合主键 (room_id, agent_id) 生效：同房间再加同一人 → 撞主键
    await v27.insert('room_roles', {
      'room_id': 'legacy-room',
      'agent_id': 'AG-a',
      'role': 'host',
      'granted_by': 'AG-a',
      'at_ms': kT0,
    });
    await expectLater(
      v27.insert('room_roles', {
        'room_id': 'legacy-room',
        'agent_id': 'AG-a',
        'role': 'guest',
        'granted_by': 'AG-a',
        'at_ms': kT0 + 1,
      }),
      throwsA(anything),
      reason: '一人在一个房间里只有一个角色（幂等由主键保证，不靠代码自觉）',
    );

    await v27.close();
  });

  test('老库升级（v27 → v28）：技能三表建出来 + 老数据不能丢', () async {
    final path = '${_tmp.path}/upgrade_v28.db';
    final v27 = await _open(path, 27);
    final before = await _tables(v27);
    expect(before, isNot(contains('skill_listings')), reason: '（前提）v27 库里没有它');
    expect(before, isNot(contains('payout_ledger')), reason: '（前提）v27 库里没有它');
    expect(before, contains('room_roles'), reason: 'v27 产物必须在');

    // 造一条老数据（房间角色），升级后必须还在
    await v27.insert('room_roles', {
      'room_id': 'legacy-room',
      'agent_id': 'AG-a',
      'role': 'host',
      'granted_by': 'AG-a',
      'at_ms': kT0,
    });
    await v27.close();

    final v28 = await _open(path, 28);
    expect(await _userVersion(v28), 28);
    final after = await _tables(v28);
    for (final t in const ['skill_listings', 'skill_revoked', 'payout_ledger']) {
      expect(after, contains(t), reason: 'v28 新表 $t 必须建出来');
    }
    expect(after, contains('room_roles'), reason: 'v27 产物不得消失');
    final legacy = await v28.query('room_roles',
        where: 'room_id = ?', whereArgs: ['legacy-room']);
    expect(legacy.length, 1, reason: '升级不得丢老数据');

    // 复合主键 (skill_id, version)：同版本只能有一份内容（"付过钱后被换内容"写不进去）
    await v28.insert('skill_listings', {
      'skill_id': 'wold.skill.x', 'version': '1.0.0', 'author_pub': 'pub',
      'content_hash': 'h1', 'published_at': kT0,
    });
    await expectLater(
      v28.insert('skill_listings', {
        'skill_id': 'wold.skill.x', 'version': '1.0.0', 'author_pub': 'pub',
        'content_hash': 'h2', 'published_at': kT0 + 1,
      }),
      throwsA(anything),
      reason: '同 (skill_id, version) 只能有一行（PK 幂等，不靠代码自觉）',
    );

    // purchase_id 主键：同一笔购买只落一条分账
    await v28.insert('payout_ledger', {
      'purchase_id': 'P1', 'skill_id': 'wold.skill.x', 'version': '1.0.0',
      'author_pub': 'pub', 'buyer_id': 'AG-b', 'amount_cents': 101,
      'author_cents': 61, 'platform_cents': 30, 'referrer_cents': 10, 'at_ms': kT0,
    });
    await expectLater(
      v28.insert('payout_ledger', {
        'purchase_id': 'P1', 'skill_id': 'wold.skill.x', 'version': '1.0.0',
        'author_pub': 'pub', 'buyer_id': 'AG-b', 'amount_cents': 200,
        'author_cents': 200, 'platform_cents': 0, 'referrer_cents': 0, 'at_ms': kT0 + 1,
      }),
      throwsA(anything),
      reason: '同一 purchaseId 只落一条（幂等由主键保证）',
    );

    await v28.close();
  });

  test('老库升级（v28 → v29）：额度/账本两表建出来 + 老数据不能丢', () async {
    final path = '${_tmp.path}/upgrade_v29.db';
    final v28 = await _open(path, 28);
    final before = await _tables(v28);
    expect(before, isNot(contains('trial_quotas')), reason: '（前提）v28 库里没有它');
    expect(before, isNot(contains('trial_usage')), reason: '（前提）v28 库里没有它');
    expect(before, contains('skill_listings'), reason: 'v28 产物必须在');

    // 造一条老数据（技能上架），升级后必须还在
    await v28.insert('skill_listings', {
      'skill_id': 'wold.skill.legacy', 'version': '1.0.0', 'author_pub': 'pub',
      'content_hash': 'h1', 'published_at': kT0,
    });
    await v28.close();

    final v29 = await _open(path, 29);
    expect(await _userVersion(v29), 29);
    final after = await _tables(v29);
    for (final t in const ['trial_quotas', 'trial_usage']) {
      expect(after, contains(t), reason: 'v29 新表 $t 必须建出来');
    }
    expect(after, contains('skill_listings'), reason: 'v28 产物不得消失');
    final legacy = await v29.query('skill_listings',
        where: 'skill_id = ?', whereArgs: ['wold.skill.legacy']);
    expect(legacy.length, 1, reason: '升级不得丢老数据');

    // 复合主键 (agent_id, purpose)：重复发放是 UPDATE，不会叠加出双倍敞口
    Future<void> putQuota(String agentId, String purpose, int turns) =>
        v29.insert('trial_quotas', {
          'agent_id': agentId, 'purpose': purpose, 'granted_turns': turns,
          'used_turns': 0, 'budget_cents': 50, 'spent_cents': 0,
          'granted_at': kT0,
        });
    await putQuota('AG-a', 'onboarding', 20);
    await expectLater(
      putQuota('AG-a', 'onboarding', 40),
      throwsA(anything),
      reason: '同一 (agent_id, purpose) 只能有一份额度（重复发放不得叠加敞口）',
    );
    // 换个用途是另一份 —— 主键不误伤
    await putQuota('AG-a', 'social_bridge', 30);
    expect((await v29.query('trial_quotas')).length, 2);

    // call_id 主键：同一次调用只落一条（重复记账不会把额度扣两遍）
    Future<void> putUsage(String callId, int cost) => v29.insert('trial_usage', {
          'call_id': callId, 'agent_id': 'AG-a', 'purpose': 'onboarding',
          'provider': 'p1', 'model': 'm', 'prompt_tokens': 10,
          'completion_tokens': 5, 'cost_cents': cost, 'at_ms': kT0,
        });
    await putUsage('CALL-1', 2);
    await expectLater(
      putUsage('CALL-1', 99),
      throwsA(anything),
      reason: '同一 callId 只落一条（幂等由主键保证，不靠代码自觉）',
    );

    await v29.close();
  });

  group('真实 trial store 端到端（真库：额度落库 ≠ 内存计数）', () {
    late Database db;
    late DbTrialStore store;
    late TrialGatewayService svc;

    setUp(() async {
      db = await _open(
          '${_tmp.path}/trial_${DateTime.now().microsecondsSinceEpoch}.db',
          DBHelper.schemaVersion);
      DBHelper.attachDbForTest(db);
      store = DbTrialStore();
      svc = TrialGatewayService(
        store: store,
        enabled: true,
        allowedProviders: {'p1'},
        promptPricePerMTokCents: 100,
        completionPricePerMTokCents: 400,
      );
    });

    tearDown(() async => db.close());

    test('额度记在**库里**：新开一个 store 实例读出来还是同一份', () async {
      // 这一条是整个 M8 的地基：改造前 SocialBudget 是内存计数，重启即归零，
      // 于是"20 条/天"可以靠重启刷穿 —— 缓释措施形同虚设。
      await svc.grantOnboarding('AG-a', kT0);
      await svc.consume(
        callId: 'CALL-1', agentId: 'AG-a',
        req: const GatewayRequest(
            purpose: TrialPurpose.onboarding, provider: 'p1', model: 'm',
            prompt: '你好'),
        promptTokens: 1000, completionTokens: 500, nowMs: kT0,
      );

      // 换一个 store 实例（模拟 App 重启：进程内对象全丢，只剩库）
      final reborn = DbTrialStore();
      final q = await reborn.quota('AG-a', TrialPurpose.onboarding);
      expect(q, isNotNull, reason: '★ 重启后额度仍在（内存计数会在这一步归零）');
      expect(q!.usedTurns, 1, reason: '★ 已用条数落库');
      expect(q.spentCents, 2, reason: '★ 已花金额落库（金额闸才是合规口径）');

      final u = await reborn.usage('CALL-1');
      expect(u, isNotNull);
      expect(u!.costCents, 2);
      expect(u.costMatches(promptPricePerMTokCents: 100,
          completionPricePerMTokCents: 400), isTrue,
          reason: '账本可复算');
    });

    test('重启后**继续被闸住**：不能靠重启刷出第二份额度', () async {
      const req = GatewayRequest(
          purpose: TrialPurpose.onboarding, provider: 'p1', model: 'm',
          prompt: '再来一轮');
      await svc.grantOnboarding('AG-a', kT0);

      // 把条数用光。坑：20 次调用不能落在同一毫秒 —— 那会在第 11 次被**节奏闸**
      // （每小时 10 次）拦下，条数只耗掉 10/20，于是"重启后还有额度"是假绿。
      // 这里每小时只调一次，绕开节奏闸，因为本条要验的是**条数闸**。
      for (var i = 0; i < TrialCaps.onboardingTurns; i++) {
        final at = kT0 + i * 3600000;
        final d = await svc.decide(req, agentId: 'AG-a', nowMs: at);
        expect(d.allow, isTrue, reason: '第 $i 次应仍在额度内（条数 20、金额 50 分）');
        await svc.consume(
            callId: 'CALL-$i', agentId: 'AG-a', req: req,
            promptTokens: 1, completionTokens: 1, nowMs: at);
      }

      final reborn = TrialGatewayService(
          store: DbTrialStore(), enabled: true, allowedProviders: {'p1'},
          promptPricePerMTokCents: 100, completionPricePerMTokCents: 400);
      final after = await reborn.decide(req,
          agentId: 'AG-a',
          nowMs: kT0 + 25 * 3600000); // 隔天 + 已过节奏闸窗口
      expect(after.allow, isFalse,
          reason: '★ 重启/隔天都不能刷新额度（否则"额度极小"这条缓释措施就是假的）');
      expect(after.code, GatewayCode.quotaExhausted);
    });

    test('吊销落库：收回敞口不能只是内存里改个 bool', () async {
      await svc.grantOnboarding('AG-a', kT0);
      await svc.revoke('AG-a', TrialPurpose.onboarding, kT0 + 1);

      final reborn = DbTrialStore();
      final q = await reborn.quota('AG-a', TrialPurpose.onboarding);
      expect(q!.revokedAtMs, isNotNull, reason: '★ 吊销时间落库（重启后依然吊销中）');

      final d = await TrialGatewayService(
              store: reborn, enabled: true, allowedProviders: {'p1'})
          .decide(
        const GatewayRequest(
            purpose: TrialPurpose.onboarding, provider: 'p1', model: 'm',
            prompt: '我还有额度吗'),
        agentId: 'AG-a', nowMs: kT0 + 2,
      );
      expect(d.code, GatewayCode.quotaRevoked);
    });

    test('未入场 → 社交额度不落库（免费资源不白送在漏斗顶端）', () async {
      final got = await svc.grantSocialBridge('AG-b', kT0, enteredCircle: false);
      expect(got, isNull);
      expect(await store.quota('AG-b', TrialPurpose.socialBridge), isNull,
          reason: '未入场时库里**根本不出现**这份额度');
      expect(
        await svc.decide(
          const GatewayRequest(
              purpose: TrialPurpose.socialBridge, provider: 'p1', model: 'm',
              prompt: '帮我破冰'),
          agentId: 'AG-b', nowMs: kT0,
        ).then((d) => d.code),
        GatewayCode.noQuota,
      );
    });
  });

  test('老库升级（v29 → v30）：背书两表建出来 + 老数据不能丢', () async {
    final path = '${_tmp.path}/upgrade_v30.db';
    final v29 = await _open(path, 29);
    final before = await _tables(v29);
    expect(before, isNot(contains('endorsements')), reason: '（前提）v29 库里没有它');
    expect(before, isNot(contains('endorsement_revoked')), reason: '（前提）v29 库里没有它');
    expect(before, contains('trial_quotas'), reason: 'v29 产物必须在');

    await v29.insert('trial_quotas', {
      'agent_id': 'AG-a', 'purpose': 'onboarding', 'granted_turns': 20,
      'used_turns': 0, 'budget_cents': 50, 'spent_cents': 0, 'granted_at': kT0,
    });
    await v29.close();

    final v30 = await _open(path, 30);
    expect(await _userVersion(v30), 30);
    final after = await _tables(v30);
    for (final t in const ['endorsements', 'endorsement_revoked']) {
      expect(after, contains(t), reason: 'v30 新表 $t 必须建出来');
    }
    expect(after, contains('trial_quotas'), reason: 'v29 产物不得消失');
    final legacy = await v30.query('trial_quotas',
        where: 'agent_id = ?', whereArgs: ['AG-a']);
    expect(legacy.length, 1, reason: '升级不得丢老数据');

    // 复合主键 (issuer_pub, subject_pub)：重复签发是 UPDATE，叠加不出第二份背书
    Future<void> put(String issuer, String subject, String tier) =>
        v30.insert('endorsements', {
          'issuer_pub': issuer, 'subject_pub': subject, 'tier': tier,
          'issued_at': kT0, 'expires_at': kT0 + 86400000, 'note': '', 'sig': 's',
        });
    await put('PUB-a', 'PUB-b', 'friend');
    await expectLater(
      put('PUB-a', 'PUB-b', 'family'),
      throwsA(anything),
      reason: '一人对一人只有一份背书（叠加 = 变相放大边权 = 刷分）',
    );
    await put('PUB-a', 'PUB-c', 'family'); // 换个主体是另一份
    expect((await v30.query('endorsements')).length, 2);

    await v30.close();
  });

  test('老库升级（v30 → v31）：接缝表建出来 + 老数据不能丢', () async {
    final path = '${_tmp.path}/upgrade_v31.db';
    final v30 = await _open(path, 30);
    final before = await _tables(v30);
    expect(before, isNot(contains('agent_pubkeys')), reason: '（前提）v30 库里没有它');
    expect(before, contains('endorsements'), reason: 'v30 产物必须在');

    await v30.insert('trial_quotas', {
      'agent_id': 'AG-a', 'purpose': 'onboarding', 'granted_turns': 20,
      'used_turns': 0, 'budget_cents': 50, 'spent_cents': 0, 'granted_at': kT0,
    });
    await v30.close();

    final v31 = await _open(path, 31);
    expect(await _userVersion(v31), 31);
    final after = await _tables(v31);
    expect(after, contains('agent_pubkeys'), reason: 'v31 接缝表必须建出来');
    expect(after, contains('endorsements'), reason: 'v30 产物不得消失');
    expect((await v31.query('trial_quotas')).length, 1, reason: '升级不得丢老数据');

    // 同一个人**换绑 = UPDATE**（主键 agent_id），不是挂出第二把钥匙
    await v31.insert('agent_pubkeys', {
      'agent_id': 'AG-bob', 'pubkey': 'PUB-1', 'source': 'passport', 'at_ms': kT0,
    });
    await v31.update('agent_pubkeys',
        {'pubkey': 'PUB-2', 'source': 'passport', 'at_ms': kT0 + 1},
        where: 'agent_id = ?', whereArgs: ['AG-bob']);
    final rows = await v31
        .query('agent_pubkeys', where: 'agent_id = ?', whereArgs: ['AG-bob']);
    expect(rows.length, 1, reason: '★ 一个人只有一条记录（挂 N 把钥匙 = Sybil 放大）');
    expect(rows.first['pubkey'], 'PUB-2', reason: '换绑生效');
    await v31.close();
  });

  test('老库升级（v31 → 当前）：连跨 v32/v33/v34 三跳，老数据不能丢', () async {
    // 为什么这条值得单独一条：v32/v33 的产物此前只在"全新安装"路径被
    // 断言过——而**真实的 v31 老库用户**升级时要连跨 v32、v33、v34 三跳。
    // 迁移是单点 migrate()，但"跳"的注册（32: / 33: / 34:）漏掉任何一条，
    // 只有"带老数据逐跳升级"的用例照得到：症状是升级后查表
    // `no such table`，且只发生在升级用户身上，新装用户永远复现不了。
    final path = '${_tmp.path}/upgrade_v31_chain.db';
    final v31 = await _open(path, 31);
    expect(await _userVersion(v31), 31);
    final before = await _tables(v31);
    for (final t in const ['contribution_records', 'hub_outbox', 'key_rotations']) {
      expect(before, isNot(contains(t)), reason: '（前提）v31 库里没有 $t');
    }
    expect(before, contains('agent_pubkeys'), reason: 'v31 产物必须在');

    // 三代老数据各放一行：v29 额度 / v30 背书 / v31 接缝
    await v31.insert('trial_quotas', {
      'agent_id': 'AG-a', 'purpose': 'onboarding', 'granted_turns': 20,
      'used_turns': 0, 'budget_cents': 50, 'spent_cents': 0, 'granted_at': kT0,
    });
    await v31.insert('endorsements', {
      'issuer_pub': 'PUB-a', 'subject_pub': 'PUB-b', 'tier': 'friend',
      'issued_at': kT0, 'expires_at': kT0 + 86400000, 'note': '', 'sig': 's',
    });
    await v31.insert('agent_pubkeys', {
      'agent_id': 'AG-a', 'pubkey': 'PUB-A', 'source': 'passport', 'at_ms': kT0,
    });
    await v31.close();

    final vNow = await _open(path, DBHelper.schemaVersion);
    expect(await _userVersion(vNow), DBHelper.schemaVersion);
    final after = await _tables(vNow);
    // 中间三跳的产物全部建出来
    expect(after, contains('contribution_records'), reason: 'v32 产物必须建出来');
    expect(after, contains('founding_members'), reason: 'v32 产物必须建出来');
    expect(after, contains('price_lock_claims'), reason: 'v32 产物必须建出来');
    expect(after, contains('hub_outbox'), reason: 'v33 产物必须建出来');
    expect(after, contains('key_rotations'), reason: 'v34 产物必须建出来');
    // 三代老数据一行不丢
    expect((await vNow.query('trial_quotas')).length, 1, reason: 'v29 时代数据不得丢');
    expect((await vNow.query('endorsements')).length, 1, reason: 'v30 时代数据不得丢');
    expect((await vNow.query('agent_pubkeys')).length, 1, reason: 'v31 时代数据不得丢');

    // v34 新表的列集合（防写入方与表结构漂移——与 v33→v34 用例同口径）
    expect(await _columns(vNow, 'key_rotations'),
        ['agent_id', 'old_pub', 'new_pub', 'rotated_at', 'sig', 'recorded_at', 'confirmed_by']);
    await vNow.close();
  });

  test('老库升级（v33 → v34）：换钥账本建出来 + 老数据不能丢', () async {
    // 为什么这条值得单独一条：v34 的 `key_rotations` 是**身份可携带**的落点，
    // 而它只在全新安装那条路上被验过（见上面"全新安装"里那行列清单）。
    // 只要 `_migrateV34` 忘了注册（或注册成 `33:`），老用户升级后就会
    // `no such column: key_rotations` —— 而升级路径**没有别的测试照得到**。
    //
    // ★ 目标版本**读 schemaVersion 声明值**，不写死数字：写死的话，下次改
    //   schema 只会让这条断言"恰好还绿"，而不是提醒你它已经不在测迁移了。
    expect(DBHelper.schemaVersion >= 34, isTrue,
        reason: '本次断言的前提：v34 之后的 schema（当前 ${DBHelper.schemaVersion}）');

    final path = '${_tmp.path}/upgrade_v34.db';
    final v33 = await _open(path, 33);
    expect(await _userVersion(v33), 33);
    final before = await _tables(v33);
    expect(before, isNot(contains('key_rotations')), reason: '（前提）v33 库里没有它');
    expect(before, contains('hub_outbox'), reason: 'v33 产物必须在');
    expect(before, contains('contribution_records'), reason: 'v32 产物必须在（迁移是累加的）');

    await v33.insert('hub_outbox', {
      'endpoint': '/api/rooms/roles/commit',
      'payload': '{"k":1}',
      'attempts': 0,
      'next_at_ms': 0,
      'created_at_ms': kT0,
      'last_error': '',
    });
    await v33.close();

    final v34 = await _open(path, DBHelper.schemaVersion);
    expect(await _userVersion(v34), DBHelper.schemaVersion);
    final after = await _tables(v34);
    expect(after, contains('key_rotations'), reason: 'v34 换钥账本必须建出来');
    expect(after, contains('hub_outbox'), reason: 'v33 产物不得消失');
    expect(after, contains('agent_pubkeys'), reason: 'v31 产物不得消失');
    expect((await v34.query('hub_outbox')).length, 1, reason: '升级不得丢老数据');

    // 列集合必须与写入方一一对应（缺列 = 真机 no such column）
    expect(await _columns(v34, 'key_rotations'),
        ['agent_id', 'old_pub', 'new_pub', 'rotated_at', 'sig', 'recorded_at', 'confirmed_by'],
        reason: '列集合固定（多了/少了都说明写入方与表结构已经漂移）');

    // ★ §9.1 红线用**结构**表达：表里物理上没有"可转让/可兑现/受益人"一类列。
    //   这条断言的价值不在今天，而在**将来有人想加**的时候：它会当场红。
    final cols = await _columns(v34, 'key_rotations');
    expect(
        cols.any((c) =>
            RegExp(r'transfer|redeem|payout|sell|owner|beneficiary|price|value')
                .hasMatch(c)),
        isFalse,
        reason: '★ 换钥账本不得长出"身份归谁/值多少钱"的列（可迁移 ≠ 可转让）');

    // 主键 `(agent_id, old_pub)` **就是不变式**：同一把旧钥对同一身份只能退休一次。
    Map<String, Object?> rotation(String oldPub, String newPub, int at) => {
          'agent_id': 'AG-carol',
          'old_pub': oldPub,
          'new_pub': newPub,
          'rotated_at': at,
          'sig': 'SIG-$oldPub',
          'recorded_at': kT0,
          'confirmed_by': 'hub',
        };
    await v34.insert('key_rotations', rotation('PUB-1', 'PUB-2', kT0));
    var blocked = false;
    try {
      // 同一把旧钥、换成**另一把**新钥 ⇒ 主键冲突，写不进去
      await v34.insert('key_rotations', rotation('PUB-1', 'PUB-9', kT0 + 1));
    } catch (_) {
      blocked = true;
    }
    expect(blocked, isTrue, reason: '★ 重放同一把旧钥的换钥 ⇒ 主键冲突即拒（想造第二条得先动结构）');
    final chain = await v34.query('key_rotations',
        where: 'agent_id = ?', whereArgs: ['AG-carol'], orderBy: 'rotated_at ASC');
    expect(chain.length, 1, reason: '被拒的那条不落库');
    expect(chain.first['new_pub'], 'PUB-2', reason: '★ 已有的那条**没有被覆盖**');

    // 链式换钥（同一身份、**另一把**旧钥）应当能追加：账本是只追加的
    await v34.insert('key_rotations', rotation('PUB-2', 'PUB-3', kT0 + 2));
    final chain2 = await v34.query('key_rotations',
        where: 'agent_id = ?', whereArgs: ['AG-carol'], orderBy: 'rotated_at ASC');
    expect(chain2.length, 2, reason: '换钥链可继续追加（A→B→C 两条都留痕）');
    expect(chain2.map((r) => r['new_pub']).toList(), ['PUB-2', 'PUB-3']);
    await v34.close();
  });

  test('老库升级（v34 → v35）：私聊摘要表建出来 + 老数据不能丢', () async {
    // v35 的 `peer_summaries` 是"分身记住更早对话"的落点，只在全新安装那条路被验过。
    // 只要 `_migrateV35` 忘了注册（或注册成 `34:`），老用户升级后写摘要就会
    // `no such table: peer_summaries` —— 而升级路径没有别的测试照得到。
    expect(DBHelper.schemaVersion >= 35, isTrue,
        reason: '本次断言的前提：v35 之后的 schema（当前 ${DBHelper.schemaVersion}）');

    final path = '${_tmp.path}/upgrade_v35.db';
    final v34 = await _open(path, 34);
    expect(await _userVersion(v34), 34);
    final before = await _tables(v34);
    expect(before, isNot(contains('peer_summaries')), reason: '（前提）v34 库里没有它');
    expect(before, contains('key_rotations'), reason: 'v34 产物必须在');

    // 造一条老数据（换钥记录），升级后必须还在
    await v34.insert('key_rotations', {
      'agent_id': 'AG-a', 'old_pub': 'PUB-1', 'new_pub': 'PUB-2',
      'rotated_at': kT0, 'sig': 's', 'recorded_at': kT0, 'confirmed_by': 'local',
    });
    await v34.close();

    final v35 = await _open(path, DBHelper.schemaVersion);
    expect(await _userVersion(v35), DBHelper.schemaVersion);
    final after = await _tables(v35);
    expect(after, contains('peer_summaries'), reason: 'v35 私聊摘要表必须建出来');
    expect(after, contains('key_rotations'), reason: 'v34 产物不得消失');
    expect((await v35.query('key_rotations')).length, 1, reason: '升级不得丢老数据');

    // 列集合必须与写入方一一对应（缺列 = 真机 no such column）
    expect(await _columns(v35, 'peer_summaries'),
        ['peer_id', 'summary', 'covered_until_id', 'updated_ms'],
        reason: '列集合固定（多了/少了都说明写入方与表结构已漂移）');

    // 主键 peer_id = 不变式：一个 peer 只留最新一份；重复写是覆盖，不叠出第二行
    Future<void> put(String s, int cursor) => v35.insert(
        'peer_summaries',
        {'peer_id': 'AG-x', 'summary': s, 'covered_until_id': cursor, 'updated_ms': kT0},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await put('第一版', 10);
    await put('第二版', 20);
    final rows =
        await v35.query('peer_summaries', where: 'peer_id = ?', whereArgs: ['AG-x']);
    expect(rows.length, 1, reason: '★ 一个 peer 只留最新一份（主键即不变式）');
    expect(rows.first['summary'], '第二版');
    expect(rows.first['covered_until_id'], 20, reason: '游标一并推进');

    // 不同 peer 各自独立
    await v35.insert('peer_summaries', {
      'peer_id': 'AG-y', 'summary': '乙', 'covered_until_id': 7, 'updated_ms': kT0,
    });
    expect((await v35.query('peer_summaries')).length, 2, reason: '不同 peer 互不干扰');

    await v35.close();
  });

  test('老库升级（v35 → v36）：会客厅摘要表建出来 + 老数据不能丢', () async {
    // v36 的 `room_summaries` 是"托管分身记住房间早先聊过什么"的落点（0.45.0）。
    // 只要 `_migrateV36` 忘了注册（或注册成别的键），老用户升级后写房间摘要就会
    // `no such table: room_summaries` —— 而升级路径没有别的测试照得到。
    expect(DBHelper.schemaVersion >= 36, isTrue,
        reason: '本次断言的前提：v36 之后的 schema（当前 ${DBHelper.schemaVersion}）');

    final path = '${_tmp.path}/upgrade_v36.db';
    final v35 = await _open(path, 35);
    expect(await _userVersion(v35), 35);
    final before = await _tables(v35);
    expect(before, isNot(contains('room_summaries')), reason: '（前提）v35 库里没有它');
    expect(before, contains('peer_summaries'), reason: 'v35 产物必须在');

    // 造一条老数据（私聊摘要），升级后必须还在
    await v35.insert('peer_summaries', {
      'peer_id': 'AG-p', 'summary': '老摘要', 'covered_until_id': 5, 'updated_ms': kT0,
    });
    await v35.close();

    final v36 = await _open(path, DBHelper.schemaVersion);
    expect(await _userVersion(v36), DBHelper.schemaVersion);
    final after = await _tables(v36);
    expect(after, contains('room_summaries'), reason: 'v36 会客厅摘要表必须建出来');
    expect(after, contains('peer_summaries'), reason: 'v35 产物不得消失');
    expect((await v36.query('peer_summaries')).length, 1, reason: '升级不得丢老数据');

    // 列集合必须与写入方一一对应（缺列 = 真机 no such column）
    expect(await _columns(v36, 'room_summaries'),
        ['room_id', 'summary', 'covered_until_id', 'updated_ms'],
        reason: '列集合固定（多了/少了都说明写入方与表结构已漂移）');

    // 主键 room_id = 不变式：一个房间只留最新一份；重复写是覆盖，不叠出第二行
    Future<void> put(String s, int cursor) => v36.insert(
        'room_summaries',
        {'room_id': 'lobby', 'summary': s, 'covered_until_id': cursor, 'updated_ms': kT0},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await put('第一版', 10);
    await put('第二版', 30);
    final rows2 =
        await v36.query('room_summaries', where: 'room_id = ?', whereArgs: ['lobby']);
    expect(rows2.length, 1, reason: '★ 一个房间只留最新一份（主键即不变式）');
    expect(rows2.first['summary'], '第二版');
    expect(rows2.first['covered_until_id'], 30, reason: '游标一并推进');

    // 不同房间各自独立
    await v36.insert('room_summaries', {
      'room_id': 'room-2', 'summary': '二号房', 'covered_until_id': 9, 'updated_ms': kT0,
    });
    expect((await v36.query('room_summaries')).length, 2, reason: '不同房间互不干扰');

    await v36.close();
  });

  test('老库升级（v36 → v37）：邮箱三表建出来 + 红线列一条都不许有', () async {
    // v37 的邮箱三表是"分身代主人收发邮件"的落点（0.64.0）。
    // 忘了注册 `_migrateV37`（或注册成别的键）⇒ 老用户升级后一碰邮箱就
    // `no such table: mail_accounts`，而升级路径没有别的测试照得到。
    expect(DBHelper.schemaVersion >= 37, isTrue,
        reason: '本次断言的前提：v37 之后的 schema（当前 ${DBHelper.schemaVersion}）');

    final path = '${_tmp.path}/upgrade_v37.db';
    final v36 = await _open(path, 36);
    expect(await _userVersion(v36), 36);
    final before = await _tables(v36);
    expect(before, isNot(contains('mail_accounts')), reason: '（前提）v36 库里没有它');
    expect(before, contains('room_summaries'), reason: 'v36 产物必须在');

    // 造一条老数据，升级后必须还在
    await v36.insert('room_summaries', {
      'room_id': 'lobby', 'summary': '老摘要', 'covered_until_id': 5, 'updated_ms': kT0,
    });
    await v36.close();

    final v37 = await _open(path, DBHelper.schemaVersion);
    expect(await _userVersion(v37), DBHelper.schemaVersion);
    final after = await _tables(v37);
    for (final t in const ['mail_accounts', 'mail_seen', 'mail_outbox']) {
      expect(after, contains(t), reason: 'v37 邮箱表 $t 必须建出来');
    }
    expect(after, contains('room_summaries'), reason: 'v36 产物不得消失');
    expect(await v37.query('room_summaries'), hasLength(1), reason: '升级不得丢老数据');

    // 列集合必须与写入方一一对应（缺列 = 真机 no such column）
    expect(await _columns(v37, 'mail_accounts'), [
      'id', 'address', 'display_name', 'imap_host', 'imap_port', 'smtp_host',
      'smtp_port', 'security', 'enabled', 'last_ok_at', 'last_error',
      'created_at',
    ]);
    expect(await _columns(v37, 'mail_seen'), ['account_id', 'uid', 'seen_at']);
    expect(await _columns(v37, 'mail_outbox'), [
      'id', 'account_id', 'status', 'to_addrs', 'subject', 'preview', 'error',
      'created_at', 'sent_at',
    ]);

    // ★★ 红线（结构约束，不是文档约定）：
    //   ① 凭据绝不落库 —— 表里不许出现任何"口令/令牌"列；
    //   ② 邮箱是主人自有资产，不得可转让/兑现/挂钩收益（PRD §9.1）。
    final accountCols = await _columns(v37, 'mail_accounts');
    for (final forbidden in const [
      'password', 'passwd', 'secret', 'token', 'refresh_token', 'access_token',
      'credential', 'app_password', 'private_key',
    ]) {
      expect(accountCols, isNot(contains(forbidden)),
          reason: '凭据绝不落库：mail_accounts 不得有 $forbidden 列');
    }
    final outboxCols = await _columns(v37, 'mail_outbox');
    for (final forbidden in const [
      'owner_id', 'to_pub', 'price_cents', 'redeem_at', 'transfer_to',
      'payout_cents', 'sell_price', 'royalty',
    ]) {
      expect([...accountCols, ...outboxCols], isNot(contains(forbidden)),
          reason: 'PRD §9.1：邮箱不得演化为可转让/可兑现凭证（禁 $forbidden）');
    }

    // mail_seen 主键即不变式：同一 (account, uid) 只可能有一行
    await v37.insert('mail_seen',
        {'account_id': 'a@b.com', 'uid': '42', 'seen_at': kT0},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await v37.insert('mail_seen',
        {'account_id': 'a@b.com', 'uid': '42', 'seen_at': kT0 + 1},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    expect(await v37.query('mail_seen'), hasLength(1),
        reason: '★ 已读游标不得叠行（主键即不变式）');

    await v37.close();
  });

  test('老库升级（v38 → v39）：agent_friends 加 auto_pulled 列 + 旧行默认 0 + 清空只删机器收录项',
      () async {
    // v39 的 `agent_friends.auto_pulled` 是"联邦名册自动收录"的**归属标记**（0.89.0）。
    // 它必须在**升级路径**上也加出来：`_migrateV39` 漏注册 / 裸 ALTER 未过守卫
    // ⇒ 老用户升级后一读该列就 `no such column: auto_pulled`，而升级路径没有
    // 别的测试照得到（v16/v17/v18/v38 同款教训）。
    expect(DBHelper.schemaVersion >= 39, isTrue,
        reason: '本次断言的前提：v39 之后的 schema（当前 ${DBHelper.schemaVersion}）');

    final path = '${_tmp.path}/upgrade_v39.db';
    final v38 = await _open(path, 38);
    expect(await _userVersion(v38), 38);
    // ★★ 真引擎里的"历史库"必须**手工构造**，不能只靠版本号：
    //   本仓的建表语句是**就地编辑**的 —— base `CREATE TABLE agent_friends` 会随
    //   版本演进把后加的列（reputation / gifts_* / auto_pulled）一并写进去。
    //   所以 `_open(path, 38)` 建出来的库**已经带 auto_pulled**，拿它直接断言
    //   "升级后才有该列"是**恒真**的、证明不了升级路径（本条第一版就是这么写错的，
    //   真跑一遍立刻红）。这里显式把列摘掉，还原成 v38 的真实形状
    //   （SQLite ≥ 3.35 支持 `ALTER TABLE ... DROP COLUMN`）。
    expect(await _columns(v38, 'agent_friends'), contains('auto_pulled'),
        reason: '（前提）就地编辑的建表语句已含该列');
    await v38.execute('ALTER TABLE agent_friends DROP COLUMN auto_pulled');
    expect(await _columns(v38, 'agent_friends'), isNot(contains('auto_pulled')),
        reason: '（前提）已还原成 v38 形状：agent_friends 无 auto_pulled 列');

    // 造一条"主人自己收录"的老数据：升级后必须还在，且**默认不属于**自动收录
    await v38.insert('agent_friends', {
      'agent_id': 'AG-manual-old', 'agent_name': '老王', 'reputation': 60,
    });
    await v38.close();

    final v39 = await _open(path, DBHelper.schemaVersion);
    expect(await _userVersion(v39), DBHelper.schemaVersion);
    expect(await _columns(v39, 'agent_friends'), contains('auto_pulled'),
        reason: 'v39 列必须加出来（否则真机 no such column）');
    final legacy = await v39.query('agent_friends',
        where: 'agent_id = ?', whereArgs: ['AG-manual-old']);
    expect(legacy, hasLength(1), reason: '升级不得丢老数据');
    expect(legacy.first['auto_pulled'], 0,
        reason: '★ 老记录默认 auto_pulled=0（机器**不得**把主人既有的名册项据为己有）');

    // 把真库接到 DBHelper，让"唯一写入方 + 清空方法"按**生产同一份**代码跑
    DBHelper.attachDbForTest(v39);

    // 机器拉的（未交往）/ 主人手动收录 / 机器拉的但**已开始交往**
    await DBHelper.insertAgentFriend(
        '机器甲', '某主人', 'AG-auto', 'stranger', '拉取', 'anon', '🌐',
        autoPulled: true);
    await DBHelper.insertAgentFriend(
        '主人乙', '某主人', 'AG-manual', 'stranger', '手动', 'anon', '👤');
    await DBHelper.insertAgentFriend(
        '机器丙', '某主人', 'AG-auto2', 'stranger', '拉取', 'anon', '🌐',
        autoPulled: true);
    await DBHelper.updateAgentHandshakeStatus('AG-auto2', 'accepted');

    final removed = await DBHelper.clearAutoPulledAgents();
    expect(removed, 1,
        reason: '★ 判据两条同时成立才删：auto_pulled=1 **且** handshake_status=none');
    final left =
        (await v39.query('agent_friends')).map((r) => r['agent_id']).toSet();
    expect(left, isNot(contains('AG-auto')), reason: '机器收录且未交往 → 被清掉');
    expect(left, contains('AG-auto2'),
        reason: '★ 已开始交往的自动收录项**不得**被清（那是不可逆的历史）');
    expect(left, contains('AG-manual'), reason: '主人手动收录 → 永不清');
    expect(left, contains('AG-manual-old'), reason: '老记录 → 永不清');

    // ★ 主人手动收录一条此前被机器拉进来的行 ⇒ 该行被"认领"，脱离自动集合
    await DBHelper.insertAgentFriend(
        '机器丁', 'M', 'AG-claim', 'stranger', 'n', 'anon', '🌐',
        autoPulled: true);
    expect(await DBHelper.clearAutoPulledAgents(), 1, reason: '（前提）先清掉它');
    await DBHelper.insertAgentFriend(
        '机器丁', 'M', 'AG-claim', 'stranger', 'n', 'anon', '🌐',
        autoPulled: true);
    await DBHelper.insertAgentFriend(
        '机器丁', 'M', 'AG-claim', 'stranger', 'n', 'anon', '🌐'); // 手动 = 认领
    expect(await DBHelper.clearAutoPulledAgents(), 0,
        reason: '★ 主人认领后 auto_pulled 归零，不再是"机器收录"');

    DBHelper.detachDbForTest();
    await v39.close();
  });

  group('真实 reputation store 端到端（真库：背书落库 ≠ 内存计数）', () {
    late Database db;
    late DbReputationStore store;

    setUp(() async {
      db = await _open(
          '${_tmp.path}/rep_${DateTime.now().microsecondsSinceEpoch}.db',
          DBHelper.schemaVersion);
      DBHelper.attachDbForTest(db);
      store = DbReputationStore();
    });

    tearDown(() async => db.close());

    test('背书存在**库里**：换一个 store 实例读出来还是同一份', () async {
      const e = Endorsement(
          issuerPub: 'PUB-a', subjectPub: 'PUB-b', tier: 'friend',
          issuedAtMs: kT0, expiresAtMs: kT0 + 86400000, note: '靠谱', sig: 'sig');
      await store.upsertEndorsement(e);

      // 换一个实例（模拟 App 重启：进程内对象全丢，只剩库）
      final reborn = DbReputationStore();
      expect(await reborn.endorsement('PUB-a', 'PUB-b'), isNotNull,
          reason: '★ 重启后背书仍在（信誉资产不能重启即失）');
      expect((await reborn.endorsement('PUB-a', 'PUB-b'))!.tier, 'friend');
      expect((await reborn.forSubject('PUB-b')).length, 1, reason: '按主体可查回');
      expect((await reborn.byIssuer('PUB-a')).length, 1, reason: '按签发人可查回');
    });

    test('吊销落库：收回背书不能只是内存里改个 bool', () async {
      await store.upsertEndorsement(const Endorsement(
          issuerPub: 'PUB-a', subjectPub: 'PUB-b', tier: 'friend',
          issuedAtMs: kT0, expiresAtMs: kT0 + 86400000, sig: 'sig'));
      await store.upsertRevocation(const EndorsementRevocation(
          issuerPub: 'PUB-a', subjectPub: 'PUB-b', atMs: kT0 + 1, sig: 'rsig'));

      final reborn = DbReputationStore();
      expect(await reborn.revocation('PUB-a', 'PUB-b'), isNotNull, reason: '★ 吊销落库');
      expect(await reborn.revokedKeys(), contains('PUB-a|PUB-b'));
    });

    test('重复签发是 UPDATE，不会叠加出第二份背书', () async {
      await store.upsertEndorsement(const Endorsement(
          issuerPub: 'PUB-a', subjectPub: 'PUB-b', tier: 'friend',
          issuedAtMs: kT0, expiresAtMs: kT0 + 86400000, sig: 'sig1'));
      await store.upsertEndorsement(const Endorsement(
          issuerPub: 'PUB-a', subjectPub: 'PUB-b', tier: 'family',
          issuedAtMs: kT0, expiresAtMs: kT0 + 86400000, sig: 'sig2'));

      expect((await store.all()).length, 1, reason: '★ 改看法不新增行');
      expect((await store.endorsement('PUB-a', 'PUB-b'))!.tier, 'family',
          reason: '后一次覆盖前一次');
    });
  });

  group('护照页锚点链路端到端（真库：本地信誉 + 接缝表 → 网络判定）', () {
    late Database db;

    setUp(() async {
      db = await _open(
          '${_tmp.path}/anchor_${DateTime.now().microsecondsSinceEpoch}.db',
          DBHelper.schemaVersion);
      DBHelper.attachDbForTest(db);
    });

    tearDown(() async => db.close());

    test('★ 接缝填不上 → 背书再有效也查不到（要防的正是这种静默失效）', () async {
      final bob = await Ed25519Signer.generate();
      final dave = await Ed25519Signer.generate();
      final bobPub = await bob.publicKeyBase58();
      final davePub = await dave.publicKeyBase58();

      // 本地信誉里有这个人、分数也够 —— 但**没有公钥**（接缝空着）
      await db.insert('agent_friends',
          {'agent_id': 'AG-bob', 'agent_name': 'bob', 'reputation': 90});
      final anchors = await _anchorsFrom(db);
      expect(anchors, isEmpty, reason: '★ 有分没公钥 → 进不了锚点（不拿 ID 冒充公钥）');

      final store = DbReputationStore();
      await store.upsertEndorsement(await _signedEndorsement(
          bob, bobPub, davePub, ReputationTier.friend));
      final v = ReputationGraph.evaluate(
        subjectPub: davePub,
        anchors: anchors,
        endorsements: await store.forSubject(davePub),
        nowMs: kT0,
      );
      expect(v.isUnknown, isTrue,
          reason: '★ 起点不存在 → 背书有效也永远 unknown（而页面看上去完全正常）');
    });

    test('★ 接缝填上后，重启也查得到（锚点与背书都在库里，不是内存状态）', () async {
      final bob = await Ed25519Signer.generate();
      final dave = await Ed25519Signer.generate();
      final bobPub = await bob.publicKeyBase58();
      final davePub = await dave.publicKeyBase58();

      await db.insert('agent_friends',
          {'agent_id': 'AG-bob', 'agent_name': 'bob', 'reputation': 90});
      await db.insert('agent_pubkeys', {
        'agent_id': 'AG-bob', 'pubkey': bobPub, 'source': 'passport', 'at_ms': kT0,
      });

      await DbReputationStore().upsertEndorsement(
          await _signedEndorsement(bob, bobPub, davePub, ReputationTier.friend));

      // 全新实例 = 模拟重启（进程内对象全丢，只剩库）
      final anchors = await _anchorsFrom(db);
      final v = ReputationGraph.evaluate(
        subjectPub: davePub,
        anchors: anchors,
        endorsements: await DbReputationStore().forSubject(davePub),
        nowMs: kT0,
      );
      expect(anchors[bobPub], 0.9, reason: '锚点权重 = 本地分 / 100');
      expect(v.known, isTrue, reason: '★ 重启后仍查得到');
      expect(v.path.first, bobPub, reason: '证据链从**我的**锚点起');
      expect(v.path.last, davePub, reason: '到被查主体止（可逐段验签）');
      expect(v.tier, isNot(ReputationTier.family),
          reason: '★ 网络路径到不了 family（0.9 × 0.6 = 0.54 < 0.60）');
    });

    test('吊销即时生效：接缝还在，通路已断', () async {
      final bob = await Ed25519Signer.generate();
      final dave = await Ed25519Signer.generate();
      final bobPub = await bob.publicKeyBase58();
      final davePub = await dave.publicKeyBase58();

      await db.insert('agent_friends',
          {'agent_id': 'AG-bob', 'agent_name': 'bob', 'reputation': 90});
      await db.insert('agent_pubkeys', {
        'agent_id': 'AG-bob', 'pubkey': bobPub, 'source': 'passport', 'at_ms': kT0,
      });
      final store = DbReputationStore();
      await store.upsertEndorsement(
          await _signedEndorsement(bob, bobPub, davePub, ReputationTier.friend));

      final anchors = await _anchorsFrom(db);
      final svc = ReputationNetworkService(store: store, onEvent: (_, __) {});
      expect(
          (await svc.query(
                  subjectPub: davePub, anchors: anchors, nowMs: kT0))
              .known,
          isTrue,
          reason: '（前提）吊销前查得到');

      final revDraft = EndorsementRevocation(
          issuerPub: bobPub, subjectPub: davePub, atMs: kT0 + 1);
      await store.upsertRevocation(EndorsementRevocation(
        issuerPub: bobPub,
        subjectPub: davePub,
        atMs: kT0 + 1,
        sig: await bob.signBytes(revDraft.canonicalBytes()),
      ));

      expect(
          (await svc.query(
                  subjectPub: davePub,
                  anchors: await _anchorsFrom(db),
                  nowMs: kT0 + 2))
              .isUnknown,
          isTrue,
          reason: '★ 收回是即时的：锚点还在，通路必须断');
    });
  });

  group('真实 store 端到端（真库 + 真 SQL + 真事务）', () {
    late Database db;
    late DbAttestationStore attStore;
    late DbTransparencyLog log;
    late AttestationService alice;
    late AttestationService bob;

    setUp(() async {
      db = await _open('${_tmp.path}/e2e_${DateTime.now().microsecondsSinceEpoch}.db',
          DBHelper.schemaVersion);
      DBHelper.attachDbForTest(db);
      attStore = DbAttestationStore();
      log = DbTransparencyLog();

      // §16 日志挂点：与生产 `WoldRuntime._appendToTransparencyLog` 同款
      Future<void> sink(IntroAttestation a) async {
        await log.appendOnce(await TransparencyLog.leafHashOf(a.logLeafBytes()));
      }

      alice = AttestationService(
        store: attStore,
        signer: await Ed25519Signer.generate(),
        selfId: () async => 'AG-alice',
        onAdvance: sink,
      );
      bob = AttestationService(
        store: attStore,
        signer: await Ed25519Signer.generate(),
        selfId: () async => 'AG-bob',
        onAdvance: sink,
      );
    });

    tearDown(() async => db.close());

    test('三段式推进在真库上逐步落同一行，且**只前进不后退**', () async {
      final a0 = await alice.propose(
        counterpartyId: 'AG-bob',
        circleId: 'cA',
        roomId: 'r-1',
        topic: '真库端到端',
        nowMs: kT0,
      );
      var row = await attStore.byId(a0.id);
      expect(row, isNotNull);
      expect(row!.stage, 1, reason: 'propose 落库 stage 1');

      final c1 = await bob.consent(a0, nowMs: kT0 + 1);
      expect(c1, isNotNull);
      row = await attStore.byId(a0.id);
      expect(row!.stage, 2, reason: 'consent 升级**同一行**而不是新插一行');

      // 🔴 回滚攻击：重放低阶段记录。事务内读改写真的挡住了吗
      await attStore.upsert(a0);
      row = await attStore.byId(a0.id);
      expect(row!.stage, 2, reason: '重放 stage1 **不得**把记录打回 proposed');

      final r1 = await alice.resolve(c1!, outcome: IntroOutcome.handshake, nowMs: kT0 + 2);
      expect(r1, isNotNull);
      final k1 = await bob.acknowledge(r1!, nowMs: kT0 + 3);
      expect(k1, isNotNull);

      row = await attStore.byId(a0.id);
      expect(row!.stage, 4);
      expect(row.ackSig, isNotNull);
      expect(row.ackSig, isNotEmpty, reason: '追认签名必须真的持久化');

      // 整表只有一行 —— 三次推进没长出三行
      final all = await db.query('attestations');
      expect(all.length, 1, reason: '同一 id 只应有一行（PK 幂等）');
    });

    test('involving 双向命中、无关方查不到', () async {
      final a0 = await alice.propose(
          counterpartyId: 'AG-bob', circleId: 'cA', nowMs: kT0);
      await bob.consent(a0, nowMs: kT0 + 1);

      expect((await attStore.involving('AG-alice')).length, 1);
      expect((await attStore.involving('AG-bob')).length, 1);
      expect(await attStore.involving('AG-carol'), isEmpty,
          reason: '与我无关的记录不得越界出现在我的履历里');
    });

    test('漏斗：只统计验过双方互允的记录，在途不算失败', () async {
      final a0 = await alice.propose(
          counterpartyId: 'AG-bob', circleId: 'cA', nowMs: kT0);
      final f0 = await alice.myFunnel();
      expect(f0.proposed, 1);
      expect(f0.consented, 0, reason: '还没互允 → 不进分母（诚实口径）');

      await bob.consent(a0, nowMs: kT0 + 1);
      final f1 = await alice.myFunnel();
      expect(f1.proposed, 1);
      expect(f1.consented, 1);
      expect(f1.handshake, 0);
      expect(f1.settled, 0);
      expect(f1.inFlight, 1, reason: '在途必须单列，不能被当成失败压低转化率');
    });

    test('§16 日志：追加/幂等/只凭 leafHash 重放/包含证明', () async {
      final a0 = await alice.propose(
          counterpartyId: 'AG-bob', circleId: 'cA', roomId: 'r-1', nowMs: kT0);
      final c1 = await bob.consent(a0, nowMs: kT0 + 1);
      final r1 = await alice.resolve(c1!, outcome: IntroOutcome.handshake, nowMs: kT0 + 2);
      await bob.acknowledge(r1!, nowMs: kT0 + 3);

      final entries = await db.query('log_entries', orderBy: 'idx ASC');
      expect(entries.length, 4, reason: '四次推进 → 四片叶子（每步都留痕）');
      // 这一条曾经是红的：叶子只带 state 时，"已落结果(resolved)"与
      // "对端已追认"会算出**同一片叶子** → appendOnce 幂等去重 → 追认不留痕。
      // 现在叶子带上 stage（1..4），四步四叶各不相同。
      expect(entries.map((e) => e['leaf_hash']).toSet().length, 4,
          reason: '四片叶子必须两两不同（stage 参与叶子构造）');

      final snap = await log.snapshot();
      expect(snap.size, 4);
      expect(snap.root, isNotEmpty);
      expect(await log.verifyChain(), isTrue);

      // 幂等：同一叶子再追加一次，不应长成 5 片
      await log.appendOnce((entries.first['leaf_hash'] ?? '').toString());
      expect((await log.snapshot()).size, 4, reason: 'appendOnce 必须幂等');

      // 第三方视角：**只凭 leaf_hash 列表**重放 → 同一个根
      final replayed = TransparencyLog();
      for (final e in entries) {
        await replayed.appendLeafHash((e['leaf_hash'] ?? '').toString());
      }
      expect(await replayed.root(), snap.root);

      // 包含证明：propose 那一步在当期根下验得过（第三方只需记录 + 证明）
      expect(
        await MerkleVerify.inclusion(
          leaf: a0.logLeafBytes(),
          proof: await replayed.inclusionProof(0),
          root: snap.root,
        ),
        isTrue,
      );
    });

    test('§16 日志：改 / 删中间断链，但**截断原理上查不出**（能力边界）', () async {
      // 推进三次 → 三片叶子（idx 0/1/2），够做"删中间"的实验
      final a0 = await alice.propose(
          counterpartyId: 'AG-bob', circleId: 'cA', nowMs: kT0);
      final c1 = await bob.consent(a0, nowMs: kT0 + 1);
      await alice.resolve(c1!, outcome: IntroOutcome.handshake, nowMs: kT0 + 2);
      expect((await db.query('log_entries')).length, 3);
      expect(await log.verifyChain(), isTrue, reason: '（前提）未篡改时链自洽');

      // 篡改前先把三条原值抓下来 —— 后面"复原"要用它，而不是靠猜
      final original = await db.query('log_entries', orderBy: 'idx ASC');
      Future<void> setCol(int idx, String col, String? val) async {
        await db.update('log_entries', {col: val},
            where: 'idx = ?', whereArgs: [idx]);
        log.invalidate();
      }

      // ---- ① 改写 leaf_hash → 断链 ----
      await setCol(1, 'leaf_hash', 'TAMPERED');
      expect(await log.verifyChain(), isFalse, reason: '改 leaf_hash 必须断链');

      // 复原 → **必须重新变绿**。这一步是关键：它证明前一条断言不是"恒假"，
      // 而是真的在追踪这条链。（从库里重放出来的日志若用 appendLeafHash
      // 逐条重算 hash，这里就会永远为真 —— 那正是被本用例抓到的缺陷。）
      await setCol(1, 'leaf_hash', '${original[1]['leaf_hash']}');
      expect(await log.verifyChain(), isTrue, reason: '复原后必须重新自洽');

      // ---- ② 改写 prev_hash → 断链 ----
      await setCol(1, 'prev_hash', '${original[1]['hash']}'); // 指向自己
      expect(await log.verifyChain(), isFalse, reason: '改 prev_hash 也必须断链');
      await setCol(1, 'prev_hash', '${original[1]['prev_hash']}');
      expect(await log.verifyChain(), isTrue, reason: '复原后再次自洽');

      // ---- ③ 删**中间**一条 → 序号断档 ----
      await db.delete('log_entries', where: 'idx = ?', whereArgs: [1]);
      log.invalidate();
      expect(await log.verifyChain(), isFalse, reason: '删中间一条必须断链');

      // 把删掉的那条原样塞回去，恢复成完整三条
      await db.insert('log_entries', Map<String, dynamic>.from(original[1]));
      log.invalidate();
      expect(await log.verifyChain(), isTrue, reason: '塞回原条目后重新自洽');

      // ---- ④ 诚实边界：删**末尾**一条 = 截断，哈希链**查不出** ----
      // 剩下的前缀本身就是一条自洽的链（idx 0/1 接得上）。
      // 挡截断只能靠**外部见证**：把每期的 (size, root) 锚定出去
      // （§16：GitHub 签名提交 / OpenTimestamps），下次比对"锚定期不应变短/换根"。
      final full = await log.snapshot();
      await db.delete('log_entries', where: 'idx = ?', whereArgs: [2]);
      log.invalidate();
      expect(await log.verifyChain(), isTrue,
          reason: '截断后剩下的前缀自洽 —— verifyChain **查不出**截断（别把它的能力说大）');
      final truncated = await log.snapshot();
      expect(truncated.size, lessThan(full.size), reason: '截断确实发生了：期号变小');
      // 而"期号变小"这件事，只有拿**锚定出去的旧期号**来比才发现得了 —— 见 §16。
      expect(await log.verifyChain(), isTrue, reason: '链自检对截断始终沉默');
    });
  });

  // ===================================================================
  group('真实 contribution 端到端（真库：贡献账本只追加 + §16 合流）', () {
    late Database db;
    late DbContributionStore store;
    late DbTransparencyLog log;
    late ContributionService svc;
    late Ed25519Signer alice; // 贡献者
    late Ed25519Signer bob; // 被邀请人（关系型贡献的证明人）
    late Ed25519Signer platform; // 定价权签发人

    setUp(() async {
      db = await _open(
          '${_tmp.path}/contrib_${DateTime.now().microsecondsSinceEpoch}.db',
          DBHelper.schemaVersion);
      DBHelper.attachDbForTest(db);
      store = DbContributionStore();
      log = DbTransparencyLog();

      // §16 日志挂点：与生产 `WoldRuntime._appendContributionToLog` 同款
      Future<void> sink(ContributionRecord r) async {
        await log.appendOnce(await TransparencyLog.leafHashOf(r.logLeafBytes()));
      }

      svc = ContributionService(store: store, onAppend: sink);
      alice = await Ed25519Signer.generate();
      bob = await Ed25519Signer.generate();
      platform = await Ed25519Signer.generate();
    });

    tearDown(() async => db.close());

    Future<ContributionRecord> signedInvite(String subjectPub, String ref) async {
      final draft = ContributionRecord(
        subjectPub: subjectPub,
        attestorPub: await bob.publicKeyBase58(),
        kind: ContributionKind.invite,
        ref: ref,
        weight: ContributionKind.weightOf(ContributionKind.invite),
        atMs: kT0,
      );
      return draft.copyWith(sig: await bob.signBytes(draft.canonicalBytes()));
    }

    test('贡献记录落库：换一个 store 实例读出来还是同一份', () async {
      final apub = await alice.publicKeyBase58();
      final bpub = await bob.publicKeyBase58();
      final rec = await signedInvite(apub, bpub);
      expect((await svc.record(rec)).accept, isTrue);

      // 换一个实例（模拟 App 重启：进程内对象全丢，只剩库）
      final reborn = DbContributionStore();
      expect(await reborn.recordByKey(rec.key), isNotNull,
          reason: '★ 重启后贡献记录仍在（可出示的证据不能重启即失）');
      expect((await svc.scoreOf(apub)).total, 2, reason: '★ 声望分从库里现算');
    });

    test('同一件事重复上报 → 幂等：不写第二行、不涨分', () async {
      final apub = await alice.publicKeyBase58();
      final bpub = await bob.publicKeyBase58();
      final rec = await signedInvite(apub, bpub);
      expect((await svc.record(rec)).detail, isEmpty, reason: '首次 → 落库');

      final d2 = await svc.record(rec);
      expect(d2.accept, isTrue);
      expect(d2.isDuplicate, isTrue, reason: '★ 重复上报是幂等，不是覆盖');

      expect((await store.recordsOf(apub)).length, 1, reason: '★ 库里只有一条');
      expect((await svc.scoreOf(apub)).total, 2, reason: '★ 重复上报不涨分');
    });

    test('贡献叶子进了 §16 **同一棵**树（不是第二套账）', () async {
      final apub = await alice.publicKeyBase58();
      final bpub = await bob.publicKeyBase58();
      final rec = await signedInvite(apub, bpub);
      await svc.record(rec);

      expect(await log.size, 1, reason: '★ 贡献记录推了一片叶子进公开日志');
      final want = await TransparencyLog.leafHashOf(rec.logLeafBytes());
      final verifiable = await log.load();
      expect(verifiable.leafHashes, contains(want),
          reason: '★ 叶子哈希 = 记录公开字段的确定性哈希（第三方可独立复算）');
      expect(await log.verifyChain(), isTrue, reason: '日志链自洽');

      // 第三方只需 (记录, 包含证明, 根) 即可验证 —— 不需要信任我们的库
      final proof = await verifiable.inclusionProof(0);
      final root = await log.snapshot();
      expect(
        await MerkleVerify.inclusion(
            leaf: rec.logLeafBytes(), proof: proof, root: root.root),
        isTrue,
        reason: '★ 包含证明可独立验证（"你不必相信我，你可以验我"）',
      );
    });

    test('证明人签名不对 → 不落库（fail-closed）', () async {
      final apub = await alice.publicKeyBase58();
      final bpub = await bob.publicKeyBase58();
      final draft = ContributionRecord(
        subjectPub: apub,
        attestorPub: bpub,
        kind: ContributionKind.invite,
        ref: bpub,
        weight: ContributionKind.weightOf(ContributionKind.invite),
        atMs: kT0,
      );
      // 用 alice 的私钥冒充 bob 签名
      final forged = draft.copyWith(sig: await alice.signBytes(draft.canonicalBytes()));
      final d = await svc.record(forged);
      expect(d.accept, isFalse, reason: '★ 假签名必须被拒');
      expect(d.code, 'bad_signature');
      expect((await store.allRecords()), isEmpty, reason: '★ 验不过就不落库');
      expect(await log.size, 0, reason: '★ 更不会进公开日志');
    });

    test('关系型贡献自报无效（邀请必须由被邀请人签名证明）', () async {
      final apub = await alice.publicKeyBase58();
      final draft = ContributionRecord(
        subjectPub: apub,
        attestorPub: apub, // 自己给自己签
        kind: ContributionKind.invite,
        ref: 'somebody',
        weight: ContributionKind.weightOf(ContributionKind.invite),
        atMs: kT0,
      );
      final selfSigned =
          draft.copyWith(sig: await alice.signBytes(draft.canonicalBytes()));
      final d = await svc.record(selfSigned);
      expect(d.accept, isFalse);
      expect(d.code, 'self_attestation',
          reason: '★ 声望不能靠自吹自擂堆出来');
      expect(await store.allRecords(), isEmpty);
    });

    test('① 创始声明 + ② 定价权：落库后重启仍在，且都是签名绑定的', () async {
      final apub = await alice.publicKeyBase58();
      final ppub = await platform.publicKeyBase58();

      final fd = FoundingDeclaration(subjectPub: apub, declaredAtMs: kT0);
      final fdSigned = fd.copyWith(sig: await alice.signBytes(fd.canonicalBytes()));
      expect((await svc.declareFounding(fdSigned)).accept, isTrue, reason: '① 创始声明收下');

      final lock = PriceLockClaim(
        issuerPub: ppub,
        subjectPub: apub,
        scope: PriceLockScope.hostFee,
        discountBps: 3000,
        effectiveFromMs: kT0,
      );
      final lockSigned =
          lock.copyWith(sig: await platform.signBytes(lock.canonicalBytes()));
      expect((await svc.grantPriceLock(lockSigned)).accept, isTrue, reason: '② 定价权收下');

      // App 重启：换实例读回
      final reborn = DbContributionStore();
      expect(await reborn.founding(apub), isNotNull, reason: '★ 创始声明落库');
      expect(await svc.isFounding(apub), isTrue);
      final locks = await reborn.priceLocksOf(apub);
      expect(locks.length, 1, reason: '★ 定价权落库');
      expect(locks.first.effectiveDiscountBps, 3000, reason: '折扣随记录一起可复算');
      expect(locks.first.permanent, isTrue, reason: 'PRD 明确"永久"锁定');

      // 承诺标识必须匹配 —— 否则"我同意的是哪一版"无从判定
      final badPledge = FoundingDeclaration(
          subjectPub: apub, declaredAtMs: kT0, pledgeId: 'wrong');
      expect(
        (await svc.declareFounding(
                badPledge.copyWith(sig: await alice.signBytes(badPledge.canonicalBytes()))))
            .code,
        'bad_pledge',
      );
    });

    test('声望分**不落库**：库里没有任何"分数/余额"表（派生+只读=无处转让）', () async {
      final apub = await alice.publicKeyBase58();
      final bpub = await bob.publicKeyBase58();
      await svc.record(await signedInvite(apub, bpub));
      // 分数算得出来……
      expect((await svc.scoreOf(apub)).total, 2);
      // ……但库里找不到任何"存分数"的地方 —— 想转让得先有可写余额，而它不存在。
      final tables = await _tables(db);
      for (final t in tables) {
        expect(RegExp(r'(score|balance|points)').hasMatch(t), isFalse,
            reason: '不得存在"分数/余额"表（got: $t）');
      }
      // 台账只追加：DbContributionStore 上没有任何"改分/转让"方法
      expect(store, isA<ContributionStore>());
    });
  });
}
