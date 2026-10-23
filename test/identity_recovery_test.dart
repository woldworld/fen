// 身份恢复**编排层**的真机单元测试（`tool/verify_identity_rotation.dart` 覆盖不到这里）。
//
// 为什么必须放在 `flutter test` 宿主里而不是 `dart run`：
//   `IdentityRecovery.apply()` 会经 `AgentIdentity` → `DBHelper` 落盘，链路里
//   有 `package:sqflite` → `flutter/foundation` → `dart:ui`，
//   独立 Dart VM 没有 `dart:ui`，直接编译失败（见 db_migration_test.dart 文件头的踩坑记录）。
//
// 它盯的是"手机坏了，身份还能活下来"的**编排正确性**：
//   ① 三要素各司其职：口令错了 / 用户 ID 错了 / 恢复码被改了 —— 各自被**不同的**闸拦下；
//   ② ★ **先确认服务端、再换本机**：`prepareFromBackup` **不改动本机任何状态**，
//      只有 `apply()` 才落地 —— 反过来会让新机握着一把没人认的钥匙；
//   ③ `apply()` 必须**同时**做到三件事（只做一件就是"看起来恢复成功、实际收发不通"）：
//      新种子落盘 + `my_agent_id` 接管旧身份 + 接缝表 `agent_pubkeys` 指向新公钥；
//   ④ 换钥声明**由旧钥签**，且重放会被 `not_current_key` 挡（旧设备当场失效的机制）。

import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/agent_identity.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:dahuang_ai/core/identity_recovery.dart';
import 'package:dahuang_ai/core/identity_rotation.dart';
import 'package:dahuang_ai/core/key_backup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kNow = 1800000000000;

late Directory _tmp;
Database? _db;

Future<Database> _open(String path) => databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DBHelper.schemaVersion,
        onCreate: (db, v) => DBHelper.migrate(db, from: 0, to: v),
        onUpgrade: (db, o, n) => DBHelper.migrate(db, from: o, to: n),
      ),
    );

Future<({Uint8List seed, String pub})> _newKey() async {
  final kp = await Ed25519().newKeyPair();
  final seed = await kp.extractPrivateKeyBytes();
  final pub = await kp.extractPublicKey();
  return (seed: Uint8List.fromList(seed), pub: AgentProtocol.base58Encode(pub.bytes));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _tmp = Directory.systemTemp.createTempSync('wold_irecovery_test_');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // 本机先有一个"新装"的身份（随机种子 + 一个随机 my_agent_id）。
    await AgentIdentity.debugInjectSeedForTest(
        List<int>.generate(32, (i) => (i * 3 + 7) & 0xff));
    _db = await _open(
        '${_tmp.path}/r_${DateTime.now().microsecondsSinceEpoch}.db');
    DBHelper.attachDbForTest(_db!);
  });

  tearDown(() async {
    DBHelper.detachDbForTest();
    await _db?.close();
    _db = null;
  });

  group('身份恢复编排（随人不随设备）', () {
    test('① 三要素齐全 → 拿到一份可执行的迁移计划，且**本机未被改动**', () async {
      final oldKey = await _newKey(); // 备份里的旧身份
      const agentId = 'AG-OLDBODY01';
      const pw = 'correct horse battery staple';

      final code = await KeyBackup.seal(
        seed: oldKey.seed,
        agentId: agentId,
        pubB58: oldKey.pub,
        password: pw,
      );

      final beforeSeed = await AgentIdentity().publicKeyBase58();
      final newKey = await _newKey();

      final plan = await IdentityRecovery.prepareFromBackup(
        code: code,
        password: pw,
        agentId: agentId,
        nowMs: kNow,
        newSeed: newKey.seed,
      );

      expect(plan, isA<RestorePlan>(),
          reason: '口令与 ID 都对 → 应当拿到计划；拿到 BackupError 说明闸门放错了');
      final p = plan as RestorePlan;
      expect(p.agentId, agentId);
      expect(p.oldPub, oldKey.pub);
      expect(p.oldDid, 'did:wold:${oldKey.pub}');
      expect(p.newPub, newKey.pub);
      expect(p.newPub, isNot(p.oldPub), reason: '换钥必须换到**另一把**钥');

      // ★ 声明必须由**旧钥**签：没有旧私钥就签不出来（服务端无法代签）。
      expect(await p.rotation.sigValid(), isTrue);
      final v = await IdentityRotation.verify(p.rotation,
          currentPub: oldKey.pub, nowMs: kNow);
      expect(v.accept, isTrue, reason: '服务端按"当前钥=旧钥"判定应当接受');
      // 换成新钥作为当前钥 → 说明这是一次**尚未生效**的迁移，而不是已完成的。
      final v2 = await IdentityRotation.verify(p.rotation,
          currentPub: newKey.pub, nowMs: kNow);
      expect(v2.code, RotationFault.notCurrentKey);

      // ★ 本机此刻必须**毫无变化**（只有 apply() 才落地）。
      expect(await AgentIdentity().publicKeyBase58(), beforeSeed,
          reason: '★ prepareFromBackup 不得改动本机状态（否则服务端一拒就两头空）');
      final rows = await _db!.query('key_rotations');
      expect(rows, isEmpty, reason: '还没落地，本地不该有换钥记录');
    });

    test('② 口令错 → bad_password；ID 不符 → id_mismatch（且先于解密）', () async {
      final oldKey = await _newKey();
      const agentId = 'AG-OLDBODY02';
      const pw = 'another long password here';
      final code = await KeyBackup.seal(
        seed: oldKey.seed,
        agentId: agentId,
        pubB58: oldKey.pub,
        password: pw,
      );

      final badPw = await IdentityRecovery.prepareFromBackup(
        code: code,
        password: 'definitely-wrong',
        agentId: agentId,
        nowMs: kNow,
      );
      expect(badPw, isA<BackupError>());
      expect((badPw as BackupError).code, BackupFault.badPassword);

      final badId = await IdentityRecovery.prepareFromBackup(
        code: code,
        password: pw,
        agentId: 'AG-NOTMINE',
        nowMs: kNow,
      );
      expect(badId, isA<BackupError>());
      expect((badId as BackupError).code, BackupFault.idMismatch,
          reason: '★ 用户 ID 不符必须**先于解密**被拦（不能拿别人的备份恢复成本机身份）');
    });

    test('③ 注入的新种子 == 旧种子 → degenerate_keys（不产出会被服务端拒的声明）', () async {
      final oldKey = await _newKey();
      const agentId = 'AG-OLDBODY03';
      const pw = 'password-long-enough';
      final code = await KeyBackup.seal(
        seed: oldKey.seed,
        agentId: agentId,
        pubB58: oldKey.pub,
        password: pw,
      );

      final plan = await IdentityRecovery.prepareFromBackup(
        code: code,
        password: pw,
        agentId: agentId,
        nowMs: kNow,
        newSeed: oldKey.seed, // 与旧种子相同 → 新旧公钥相同
      );
      expect(plan, isA<BackupError>());
      expect((plan as BackupError).code, RecoverFault.degenerateKeys);
    });

    test('④ ★ apply()：新种子落盘 + 接管旧 agent_id + 接缝表指向新公钥 + 留痕', () async {
      final oldKey = await _newKey();
      const agentId = 'AG-OLDBODY04';
      const pw = 'password-long-enough';
      final code = await KeyBackup.seal(
        seed: oldKey.seed,
        agentId: agentId,
        pubB58: oldKey.pub,
        password: pw,
      );

      final newKey = await _newKey();
      final plan = await IdentityRecovery.prepareFromBackup(
        code: code,
        password: pw,
        agentId: agentId,
        nowMs: kNow,
        newSeed: newKey.seed,
      ) as RestorePlan;

      await plan.apply();

      // ① 新种子落盘：本机从此用**新钥**签名
      expect(await AgentIdentity().publicKeyBase58(), newKey.pub);
      // ② 接管旧身份：my_agent_id 必须是**旧 ID**，而不是装机时那个随机 ID
      expect(await DBHelper.getAmbassador('my_agent_id'), agentId,
          reason: '★ 不接管旧 ID 就会"恢复成功、收发不通"（Hub 改绑的是旧 ID）');
      // ③ 接缝表：身份 ↔ 当前公钥指向新钥，否则网络信誉/背书按旧公钥索引立刻错位
      final seam = await _db!.query('agent_pubkeys',
          where: 'agent_id = ?', whereArgs: [agentId]);
      expect(seam.length, 1);
      expect(seam.first['pubkey'], newKey.pub);
      // ④ 本地只追加留痕（权威在 Hub 与 §16 日志，这里只是离线可见）
      final rows = await DBHelper.keyRotationsOf(agentId);
      expect(rows.length, 1);
      expect(rows.first['old_pub'], oldKey.pub);
      expect(rows.first['new_pub'], newKey.pub);
      expect(rows.first['confirmed_by'], 'hub');
    });

    test('⑤ apply() 可重跑（三步都幂等）：不会写出第二条换钥、接缝仍只有一行', () async {
      final oldKey = await _newKey();
      const agentId = 'AG-OLDBODY05';
      const pw = 'password-long-enough';
      final code = await KeyBackup.seal(
        seed: oldKey.seed,
        agentId: agentId,
        pubB58: oldKey.pub,
        password: pw,
      );
      final newKey = await _newKey();

      for (var i = 0; i < 2; i++) {
        final plan = await IdentityRecovery.prepareFromBackup(
          code: code,
          password: pw,
          agentId: agentId,
          nowMs: kNow,
          newSeed: newKey.seed,
        ) as RestorePlan;
        await plan.apply();
      }

      expect((await DBHelper.keyRotationsOf(agentId)).length, 1,
          reason: '★ 主键 (agent_id, old_pub) + ignore：重放写不进第二条');
      final seam = await _db!.query('agent_pubkeys',
          where: 'agent_id = ?', whereArgs: [agentId]);
      expect(seam.length, 1, reason: '接缝表是"当前视图"（replace），不是历史');
      expect(await AgentIdentity().publicKeyBase58(), newKey.pub);
    });

    test('⑥ 本机身份可导出为恢复码，且能解回同一把钥', () async {
      const agentId = 'AG-EXPORT01';
      const pw = 'export password long';
      // setUp 里注入过种子，先把它记下来
      final pub = await AgentIdentity().publicKeyBase58();
      final seed = await AgentIdentity().currentSeed();

      final code = await AgentIdentity().exportBackupCode(
        password: pw,
        agentId: agentId,
      );
      final opened = await KeyBackup.open(code,
          password: pw, expectedAgentId: agentId);
      expect(opened, isA<BackupOpen>());
      final o = opened as BackupOpen;
      expect(o.pubB58, pub);
      expect(o.seed.length, seed.length);
      for (var i = 0; i < seed.length; i++) {
        expect(o.seed[i], seed[i], reason: '第 $i 字节必须相同');
      }
    });

    test('⑦ 弱口令被拒（长度门槛是这份备份的唯一保护）', () async {
      expect(KeyBackup.isPasswordAcceptable('short'), isFalse);
      expect(KeyBackup.isPasswordAcceptable('long-enough-password'), isTrue);
    });
  });
}
