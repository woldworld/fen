// 「备份状态 / 身份根 DID / 本地加密归档」的真机单元测试。
//
// 为什么必须放在 `flutter test` 宿主里而不是 `dart run`：
//   这几条链路都会经 `DBHelper`（`package:sqflite` → `dart:ui`），
//   独立 Dart VM 编不出来（见 db_migration_test.dart 文件头的踩坑记录）。
//
// 它盯的是"专家建议的两个缺口"是否真的被堵上：
//   ① 缺口1（恢复码是可选动作）：
//      * `isBackedUp()` **存公钥不存布尔值** ⇒ 换钥后必须**自动**回到"未备份"
//        （否则用户会拿一个对新钥已失效的恢复码，以为自己有退路）；
//      * `identityRootDid()` 必须给出**身份根**且**服务端确认过的锚优先** ——
//        否则换机恢复后客户端显示的 DID 与 Hub 上的分叉（缺口 B）。
//   ② 缺口2（本地数据没有出路）：
//      * 归档**往返**必须成立（导出 → 打开 → 检查 → 导入）；
//      * 口令错 / 被改动 ⇒ **fail-closed**，不得"读出一半"；
//      * 导入**只增不减**且可重跑（幂等）；
//      * ★ §16 日志**接不上就必须拒绝**（断档是哈希链原理上查不出来的失效）。
//
// 纯函数部分（blob 格式、载荷解析、日志比对）另由
// `tool/verify_local_archive.dart` 在独立 Dart VM 里复算。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/agent_identity.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/db_helper.dart';
import 'package:dahuang_ai/core/key_backup.dart';
import 'package:dahuang_ai/core/local_archive.dart';
import 'package:dahuang_ai/core/wold_did.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Directory _tmp;
Database? _db;

const String kPw = 'a-long-enough-password';

Future<Database> _open(String path) => databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DBHelper.schemaVersion,
        onCreate: (db, v) => DBHelper.migrate(db, from: 0, to: v),
        onUpgrade: (db, o, n) => DBHelper.migrate(db, from: o, to: n),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _tmp = Directory.systemTemp.createTempSync('wold_backup_state_test_');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AgentIdentity.debugInjectSeedForTest(
        List<int>.generate(32, (i) => (i * 5 + 11) & 0xff));
    _db = await _open(
        '${_tmp.path}/b_${DateTime.now().microsecondsSinceEpoch}.db');
    DBHelper.attachDbForTest(_db!);
  });

  tearDown(() async {
    DBHelper.detachDbForTest();
    await _db?.close();
    _db = null;
  });

  group('缺口1 · 备份状态（存公钥，不存布尔值）', () {
    test('① 默认未备份；markBackedUp 后已备份', () async {
      expect(await AgentIdentity().isBackedUp(), isFalse,
          reason: '新装用户从没生成过恢复码 ⇒ 必须是"未备份"');
      await AgentIdentity().markBackedUp();
      expect(await AgentIdentity().isBackedUp(), isTrue);
    });

    test('② ★ 换钥后自动回到"未备份"（旧恢复码对新钥已失效）', () async {
      await AgentIdentity().markBackedUp();
      expect(await AgentIdentity().isBackedUp(), isTrue);

      // 换一把钥（等价于换机恢复之后的本机状态）
      await AgentIdentity()
          .installSeed(List<int>.generate(32, (i) => (i * 7 + 3) & 0xff));

      expect(await AgentIdentity().isBackedUp(), isFalse,
          reason: '★ 存的是公钥 ⇒ 换钥后比对自然失败，红标必须自己回来。'
              '若这条挂了，说明有人把它改成了布尔值。');
    });

    test('③ 重新备份后再次为"已备份"', () async {
      await AgentIdentity()
          .installSeed(List<int>.generate(32, (i) => (i * 7 + 3) & 0xff));
      expect(await AgentIdentity().isBackedUp(), isFalse);
      await AgentIdentity().markBackedUp();
      expect(await AgentIdentity().isBackedUp(), isTrue);
    });
  });

  group('缺口B · 身份根 DID', () {
    test('④ 无签发记录时退回"按当前钥现推"', () async {
      final root = await AgentIdentity().identityRootDid();
      expect(root, await AgentIdentity().did());
      expect(WoldDid.isValid(root), isTrue);
    });

    test('⑤ 有签发记录时取**最早**那条（身份根不随新记录漂移）', () async {
      final agentId = await DBHelper.getAmbassador('my_agent_id') ?? '';
      expect(agentId, isNotEmpty, reason: '库初始化应当写入 my_agent_id');
      final genesis = 'did:wold:${AgentProtocol.base58Encode(List<int>.filled(32, 9))}';
      final later = 'did:wold:${AgentProtocol.base58Encode(List<int>.filled(32, 8))}';
      for (final (i, d) in [(1, genesis), (2, later)]) {
        await _db!.insert('did_issuance', {
          'did': d,
          'pub': 'p$i',
          'agent_id': agentId,
          'issued_at': 1000 + i,
          'sig': 's',
        });
      }
      expect(await AgentIdentity().identityRootDid(), genesis,
          reason: '★ 身份根 = 最早的那条；取最新会让换钥后再签发时地址漂移');
    });

    test('⑥ 服务端确认过的身份锚**优先**于本地历史（换机恢复的关键）', () async {
      await AgentIdentity().adoptAgentId(
        agentId: 'AG-RESTORED1',
        pubB58: 'newpub',
        didAnchor: 'did:wold:THE-ANCHOR',
      );
      expect(await AgentIdentity().identityRootDid(), 'did:wold:THE-ANCHOR',
          reason: '★ 新设备本地没有身份根的签发记录，只能靠 Hub 确认值 —— '
              '不落盘就会退回"按新钥现推"，界面显示一个 Hub 上查不到的地址');
      // 接缝表也要指向新钥（一个身份只有一把当前钥）
      final seam = await _db!.query('agent_pubkeys',
          where: 'agent_id = ?', whereArgs: ['AG-RESTORED1']);
      expect(seam.length, 1);
      expect(seam.first['pubkey'], 'newpub');
    });
  });

  group('缺口2 · 本地加密归档', () {
    test('⑦ ★ 往返：导出 → 打开 → 检查 → 导入（且导入只增不减、可重跑）', () async {
      // 造一条用户数据，确认它真的被带进归档
      await _db!.insert('ambassador', {'key': 'nickname', 'value': '小荒'},
          conflictAlgorithm: ConflictAlgorithm.replace);

      final blob = await LocalArchive.export(password: kPw, nowMs: 1700000000000);
      expect(blob.startsWith('${KeyBackup.archivePrefix}.'), isTrue,
          reason: '归档前缀必须与恢复码不同 —— 否则"把归档当恢复码"能过格式校验');

      final opened = await LocalArchive.open(blob, password: kPw);
      expect(opened, isA<Map>(), reason: '口令对 + 格式对 ⇒ 应当拿到载荷');
      final payload = Map<String, Object?>.from(opened as Map);
      expect(payload['kind'], LocalArchive.kind);
      expect(payload['version'], LocalArchive.formatVersion);

      // 诊断类表**不该**进归档（判据是"是不是用户资产"）
      final tables = Map<String, Object?>.from(payload['tables'] as Map);
      for (final t in LocalArchive.excludedTables) {
        expect(tables.containsKey(t), isFalse, reason: '$t 属于诊断/瞬态，不该进归档');
      }
      expect(tables.containsKey('ambassador'), isTrue);

      final inspect = await LocalArchive.inspect(payload);
      expect(inspect, isA<ArchiveInspection>());
      final insp = inspect as ArchiveInspection;
      expect(insp.importable, isTrue, reason: '本机日志为空 ⇒ 首次接管，应当可导入');
      expect(insp.totalRows, greaterThan(0));

      final written = await LocalArchive.apply(payload);
      final total = written.values.fold<int>(0, (a, b) => a + b);
      expect(total, greaterThan(0));

      // 再导一次：冲突即保留本机 ⇒ 行数不得增长（幂等，且**不做 DELETE**）
      final ambBefore = (await _db!.query('ambassador')).length;
      await LocalArchive.apply(payload);
      expect((await _db!.query('ambassador')).length, ambBefore,
          reason: '★ 导入只增不减：重跑不得写出重复行');
      expect(await DBHelper.getAmbassador('nickname'), '小荒');
    });

    test('⑧ 口令错 / 被改动 ⇒ fail-closed（不报"部分成功"）', () async {
      final blob = await LocalArchive.export(password: kPw);
      final wrong = await LocalArchive.open(blob, password: 'wrong-password-xx');
      expect(wrong, isA<BackupError>());
      expect((wrong as BackupError).code, BackupFault.badPassword);

      // 改掉密文段**中间**的一个字符：
      //   ★ 不要动最后一个字符 —— 它可能正落在 base64 padding 上，
      //     那样会先撞成 bad_format（结构非法），而不是 GCM 认证失败；
      //     这一条要钉的恰恰是"认证标签拦住内容改动"。
      final parts = blob.split('.');
      final ct = parts[3];
      final mid = ct.length ~/ 2;
      parts[3] = ct.substring(0, mid) +
          (ct[mid] == 'A' ? 'B' : 'A') +
          ct.substring(mid + 1);
      final tampered = await LocalArchive.open(parts.join('.'), password: kPw);
      expect(tampered, isA<BackupError>());
      expect((tampered as BackupError).code, BackupFault.badPassword,
          reason: 'GCM 认证标签必须拦住任何改动，绝不能"读出一半"');
    });

    test('⑨ ★ §16 日志接不上 ⇒ 拒绝导入（断档是哈希链查不出来的失效）', () async {
      // 本机写一条日志
      await _db!.insert('log_entries',
          {'idx': 0, 'leaf_hash': 'L0', 'prev_hash': 'GENESIS', 'hash': 'H0'});
      final local = await _db!.query('log_entries', orderBy: 'idx ASC');

      // 归档里的第 0 条与本机不一致
      final diverged = [
        {'idx': 0, 'leaf_hash': 'L0-DIFFERENT', 'prev_hash': 'GENESIS', 'hash': 'H9'}
      ];
      expect(ArchiveFormat.logContinuity(local, diverged),
          ArchiveFault.logMismatch);

      // 归档缺少本机已有的条目
      expect(ArchiveFormat.logContinuity(local, const []),
          ArchiveFault.logMismatch);

      // 本机是归档的**前缀** ⇒ 可以接续
      final continued = [
        {'idx': 0, 'leaf_hash': 'L0', 'prev_hash': 'GENESIS', 'hash': 'H0'},
        {'idx': 1, 'leaf_hash': 'L1', 'prev_hash': 'H0', 'hash': 'H1'},
      ];
      expect(ArchiveFormat.logContinuity(local, continued), isNull);

      // 本机为空 ⇒ 首次接管，允许
      expect(ArchiveFormat.logContinuity(const [], continued), isNull);
    });

    test('⑩ 载荷解析 fail-closed：非归档 / 未来版本一律拒', () {
      expect(ArchiveFormat.decode('not json at all'),
          ArchiveFault.notArchive);
      expect(ArchiveFormat.decode('{"kind":"something_else","version":1}'),
          ArchiveFault.notArchive);
      expect(
          ArchiveFormat.decode(
              '{"kind":"${LocalArchive.kind}","version":999,"tables":{}}'),
          ArchiveFault.futureVersion,
          reason: '★ 看得懂才处理：版本更高时必须拒绝，而不是"尽力而为"');
      expect(
          ArchiveFormat.decode(
              '{"kind":"${LocalArchive.kind}","version":1,"tables":{}}'),
          isA<Map>());
    });

    test('⑪ 归档表集动态枚举（新表自动纳入，不漏用户数据）', () async {
      final tables = await LocalArchive.archiveTables();
      expect(tables.contains('ambassador'), isTrue);
      expect(tables.contains('did_issuance'), isTrue);
      expect(tables.contains('key_rotations'), isTrue);
      for (final t in LocalArchive.excludedTables) {
        expect(tables.contains(t), isFalse);
      }
      expect(tables, equals(List<String>.from(tables)..sort()),
          reason: '排序后输出 ⇒ 生成物可逐字节复算');
    });
  });
}
