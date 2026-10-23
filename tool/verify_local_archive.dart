// 纯 Dart 校验脚本：本地加密归档（`.dahuang`）的**格式与纯函数**。
// 运行：dart run tool/verify_local_archive.dart
//
// 为什么值得单独一个脚本（与 verify_identity_rotation.dart 同型）：
//   归档这条链路里最容易悄悄坏掉的是**格式契约**，而它的失败很安静：
//   * 前缀一旦与恢复码相同，"把归档当恢复码喂进恢复流程"会在**格式校验**那层通过，
//     错误要等到很后面才暴露；
//   * 载荷版本一旦不做上限，"看得懂才处理"就变成"尽力而为"；
//   * §16 日志接续一旦不校验，断档是哈希链**原理上查不出来**的失效。
//
// 本脚本只 import**零平台依赖**的模块（`archive_format.dart` / `key_backup.dart`
// / `agent_protocol.dart` / `ed25519_sig.dart`），故可在独立 Dart VM 里离线复算。
// ⚠️ `local_archive.dart` 经 `DBHelper` 依赖 Flutter，**不能**在这里 import；
//    它的落库覆盖在 test/identity_backup_state_test.dart（flutter test）。

import 'dart:convert';
import 'dart:typed_data';

import 'package:dahuang_ai/core/archive_format.dart';
import 'package:dahuang_ai/core/key_backup.dart';

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

Future<void> main() async {
  print('== 本地加密归档（格式与纯函数） ==');

  final payload = Uint8List.fromList(
      utf8.encode(ArchiveFormat.encode(_samplePayload())));
  const pw = 'a-long-enough-password';

  // ---------------------------------------------------------------- blob
  print('-- blob（口令加密） --');

  check(KeyBackup.archivePrefix != KeyBackup.prefix,
      '★ 归档前缀与恢复码前缀必须不同（否则"拿归档当恢复码"能过格式校验）');
  check(KeyBackup.archivePrefix == 'FENARC1',
      '归档前缀 = FENARC1（格式版本由前缀承载）');

  final blob = await KeyBackup.sealBlob(payload: payload, password: pw);
  check(blob.startsWith('${KeyBackup.archivePrefix}.'),
      'sealBlob 输出以前缀开头');
  check(blob.split('.').length == 5, 'blob 是 5 段：prefix.salt.nonce.ct.mac');

  final opened = await KeyBackup.openBlob(blob, password: pw);
  check(opened is Uint8List, '口令对 ⇒ 解得开');
  if (opened is Uint8List) {
    check(opened.length == payload.length, '明文长度与原文一致');
    var same = true;
    for (var i = 0; i < payload.length; i++) {
      if (opened[i] != payload[i]) same = false;
    }
    check(same, '明文与原文**逐字节**一致');
  }

  final badPw = await KeyBackup.openBlob(blob, password: 'wrong-password-xx');
  check(badPw is BackupError && badPw.code == BackupFault.badPassword,
      '口令错 ⇒ bad_password（fail-closed）');

  // 改掉密文**中间**的一个字符：末位可能是 base64 padding，
  // 先撞 bad_format（结构非法）就测不到 GCM 认证标签这条了。
  final parts = blob.split('.');
  final ct = parts[3];
  final mid = ct.length ~/ 2;
  parts[3] = ct.substring(0, mid) +
      (ct[mid] == 'A' ? 'B' : 'A') +
      ct.substring(mid + 1);
  final tampered = await KeyBackup.openBlob(parts.join('.'), password: pw);
  check(tampered is BackupError && tampered.code == BackupFault.badPassword,
      '★ 密文被改一个字符 ⇒ bad_password（GCM 标签拦住，绝不"读出一半"）');

  // 改掉前缀
  final wrongPrefix = ['FENBK1', ...blob.split('.').skip(1)].join('.');
  final wrongPrefixOut =
      await KeyBackup.openBlob(wrongPrefix, password: pw);
  check(wrongPrefixOut is BackupError &&
          wrongPrefixOut.code == BackupFault.badFormat,
      '★ 前缀不对（如把归档当恢复码）⇒ bad_format，不做任何解密尝试');

  check((await KeyBackup.openBlob('garbage', password: pw)) is BackupError,
      '非 blob 文本 ⇒ BackupError（不抛异常）');

  final blob2 = await KeyBackup.sealBlob(payload: payload, password: pw);
  check(blob2 != blob,
      '同一载荷封两次 **密文不同**（随机 salt/nonce ⇒ 相同明文不产生相同密文）');

  var emptyRejected = false;
  try {
    await KeyBackup.sealBlob(payload: const [], password: pw);
  } catch (_) {
    emptyRejected = true;
  }
  check(emptyRejected, '空载荷被拒（不产出"能解开但没内容"的文件）');

  // ---------------------------------------------------------------- 载荷
  print('-- 载荷（解析 fail-closed） --');

  check(ArchiveFormat.decode('not json') == ArchiveFault.notArchive,
      '非 JSON ⇒ not_archive');
  check(ArchiveFormat.decode('{"kind":"other","version":1,"tables":{}}') ==
          ArchiveFault.notArchive,
      'kind 不对 ⇒ not_archive（挡住"把别的 JSON 当归档"）');
  check(ArchiveFormat.decode('{"kind":"${ArchiveFormat.kind}","version":0}') ==
          ArchiveFault.notArchive,
      '版本 ≤ 0 ⇒ not_archive');
  check(
      ArchiveFormat.decode(
              '{"kind":"${ArchiveFormat.kind}","version":999,"tables":{}}') ==
          ArchiveFault.futureVersion,
      '★ 版本高于本机 ⇒ future_version（看得懂才处理，不许"尽力而为"）');
  check(ArchiveFormat.decode('{"kind":"${ArchiveFormat.kind}","version":1}') ==
          ArchiveFault.notArchive,
      '缺 tables ⇒ not_archive');

  final decoded = ArchiveFormat.decode(ArchiveFormat.encode(_samplePayload()));
  check(decoded is Map, '合法载荷 ⇒ 解析成 Map');
  final p = decoded as Map;
  check(p['kind'] == ArchiveFormat.kind && p['version'] == 1,
      'kind/version 往返一致');
  check(ArchiveFormat.encode(_samplePayload()) ==
          ArchiveFormat.encode(_samplePayload()),
      '编码是**确定性**的（同输入同字节 ⇒ 可离线复算）');

  // ---------------------------------------------------------------- 表集
  print('-- 表集（诊断类排除，判据是"是不是用户资产"） --');

  const diagnostics = [
    'telemetry_events',
    'system_logs',
    'session_events',
    'hub_outbox',
    'audit_queue',
  ];
  for (final t in diagnostics) {
    check(ArchiveFormat.excludedTables.contains(t), '$t 被排除（诊断/瞬态）');
  }
  for (final t in ['messages', 'did_issuance', 'attestations', 'log_entries']) {
    check(!ArchiveFormat.excludedTables.contains(t),
        '$t **不**被排除（这是用户资产，必须跟着走）');
  }

  // ---------------------------------------------------------------- §16
  print('-- §16 日志接续（硬约束） --');

  final archiveLog = <Map<String, Object?>>[
    {'idx': 0, 'leaf_hash': 'L0', 'prev_hash': 'G', 'hash': 'H0'},
    {'idx': 1, 'leaf_hash': 'L1', 'prev_hash': 'H0', 'hash': 'H1'},
    {'idx': 2, 'leaf_hash': 'L2', 'prev_hash': 'H1', 'hash': 'H2'},
  ];
  check(ArchiveFormat.logContinuity(const [], archiveLog) == null,
      '本机日志为空 ⇒ 首次接管，可接续');
  check(
      ArchiveFormat.logContinuity(archiveLog.take(2).toList(), archiveLog) ==
          null,
      '本机是归档的**前缀** ⇒ 可接续');
  check(
      ArchiveFormat.logContinuity(archiveLog, archiveLog) == null,
      '本机与归档完全相同 ⇒ 可接续（幂等导入）');
  check(
      ArchiveFormat.logContinuity(archiveLog, const []) ==
          ArchiveFault.logMismatch,
      '★ 归档里没有日志而本机有 ⇒ 拒绝（否则日志凭空消失）');
  check(
      ArchiveFormat.logContinuity(archiveLog.take(2).toList(),
              archiveLog.where((r) => r['idx'] != 1).toList()) ==
          ArchiveFault.logMismatch,
      '★ 归档缺了本机有的那一节 ⇒ 拒绝（断档）');
  check(
      ArchiveFormat.logContinuity(
              archiveLog.take(1).toList(),
              [
                {'idx': 0, 'leaf_hash': 'L0-TAMPERED', 'prev_hash': 'G', 'hash': 'H0'},
                ...archiveLog.skip(1),
              ]) ==
          ArchiveFault.logMismatch,
      '★ 同样 idx 但内容不同 ⇒ 拒绝（两条链已经分叉，硬接会静默断裂）');

  print('');
  print('TOTAL PASS=$_pass FAIL=$_fail');
  if (_fail > 0) {
    throw StateError('verify_local_archive failed: $_fail');
  }
}

Map<String, Object?> _samplePayload() => {
      'kind': ArchiveFormat.kind,
      'version': ArchiveFormat.version,
      'exported_at': 1700000000000,
      'tables': {
        'did_issuance': [
          {
            'did': 'did:wold:abc',
            'pub': 'abc',
            'agent_id': 'AG-1',
            'issued_at': 1,
            'sig': 's'
          }
        ],
        'log_entries': [
          {'idx': 0, 'leaf_hash': 'L0', 'prev_hash': 'G', 'hash': 'H0'}
        ],
      },
      'log_anchors': {'size': 1, 'root': 'H0'},
    };
