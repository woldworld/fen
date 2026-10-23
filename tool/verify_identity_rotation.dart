// 纯 Dart 校验脚本：身份换钥（identity rotation）+ 恢复码（key backup）。
// 运行：dart run tool/verify_identity_rotation.dart
//
// 为什么值得单独一个脚本（与 verify_room_role_host.dart 同型）：
//   本仓的「可被第三方验证」不是一句声明，而是一条条可执行断言。这里盯的是
//   「**手机坏了，身份还能活下来**」这句话的**实质**：
//
//   ① **结构断言**：换钥载荷里没有 `scope`/`global`/`owner`，也没有任何
//      transfer/redeem 语义 —— 于是"把身份过户给别人"在字节层没有形式；
//   ② **跨语言同序断言**：直接读 `packages/protocol/src/rotation.js` 的 `canonical`
//      与 `logBytes` 键序，与 Dart 生成的 JSON **逐项比对**。键序漂移的病症是
//      "Dart 签得对、Hub 一律拒"，而本断言**不需要起 Node** 就能抓住它；
//   ③ **拒绝路径**：验签的每一条 fail-closed 分支都有负例；
//   ④ **重放安全**（★ 本模块唯一的"安全性质"）：已被取代的旧钥再重放同一条声明
//      必须判 `not_current_key` —— 这正是"旧设备当场失效"的机制，而不是过期时间。
//   ⑤ **恢复码三要素**：口令错 / 用户 ID 不符 / 明文公钥被改 —— 各自被**不同的**闸拦下。
//
// 本脚本只 import 纯 Dart 模块（无 Flutter / sqflite / shared_preferences），故可离线复算。
// ⚠️ `identity_recovery.dart` 经 `agent_identity.dart` 依赖 Flutter，**不能**在这里 import；
//    它的编排覆盖在 test/ 里（flutter test）。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/ed25519_sig.dart';
import 'package:dahuang_ai/core/identity_rotation.dart';
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

/// 固定基准时刻：换钥声明的 `rotated_at` 与 Node 侧的 `nowMs` 都用它，避免时钟耦合。
const int kNow = 1800000000000;

const String kAgentId = 'AG-ROTATE01';

/// 生成一把 Ed25519 密钥：返回 (种子, base58 公钥, 签名函数)。
Future<({Uint8List seed, String pub, Future<String> Function(List<int>) sign})>
    _newKey() async {
  final kp = await Ed25519().newKeyPair();
  final seed = await kp.extractPrivateKeyBytes();
  final pubBytes = await kp.extractPublicKey();
  final pub = AgentProtocol.base58Encode(pubBytes.bytes);
  return (
    seed: Uint8List.fromList(seed),
    pub: pub,
    sign: (List<int> msg) async {
      final s = await Ed25519().sign(msg, keyPair: kp);
      return base64Encode(s.bytes);
    },
  );
}

/// 从 JS 源码里抠出某个函数的**键序**（`^\s*key:` 逐行）。
///
/// 这是本脚本里最值钱的一段：它把"两端必须同序"从"我们希望如此"变成一条
/// 可执行断言，且不依赖 Node（`run_all_verify.dart` 也会跑到它）。
List<String> _jsKeys(String src, String fnSig) {
  final start = src.indexOf(fnSig);
  if (start < 0) return const [];
  final end = src.indexOf('}', start);
  // 守卫：段找得到才算数。宁可返回空清单 → 触发下面的 isNotEmpty FAIL，
  // 也绝不 substring(-1) 直接抛 —— 崩掉的脚本看起来像"环境问题"。
  if (end <= start) return const [];
  final body = src.substring(start, end);
  final keys = <String>[];
  for (final line in body.split('\n')) {
    final m = RegExp(r'^\s*([a-z_]+)\s*:').firstMatch(line);
    if (m != null) keys.add(m.group(1)!);
  }
  return keys;
}

bool _sameOrder(List<String> a, List<String> b) =>
    a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);

IdentityRotation _rot({
  required String oldPub,
  required String newPub,
  String agentId = kAgentId,
  int atMs = kNow,
  String sig = '',
}) =>
    IdentityRotation(
      agentId: agentId,
      oldPub: oldPub,
      newPub: newPub,
      rotatedAtMs: atMs,
      sig: sig,
    );

Future<void> main() async {
  final oldKey = await _newKey(); // 旧设备 / 备份里的钥（签名方）
  final newKey = await _newKey(); // 新机将要接管的钥
  final attacker = await _newKey(); // 第三方

  final jsSrc = File('packages/protocol/src/rotation.js').readAsStringSync();

  // =========================================================================
  print('--- ① 签名载荷：键序与协议包逐项同构（跨语言漂移的探针） ---');
  final jsCanonKeys = _jsKeys(jsSrc, 'function canonical(r) {');
  final jsLeafKeys = _jsKeys(jsSrc, 'function logBytes(r) {');
  final dartCanonKeys = (jsonDecode(_rot(oldPub: oldKey.pub, newPub: newKey.pub)
              .canonical()) as Map<String, dynamic>)
      .keys
      .toList();
  final dartLeafKeys = (jsonDecode(utf8.decode(
              _rot(oldPub: oldKey.pub, newPub: newKey.pub).logBytes()))
          as Map<String, dynamic>)
      .keys
      .toList();

  check(jsCanonKeys.isNotEmpty && jsLeafKeys.isNotEmpty, '能在 rotation.js 里找到 canonical / logBytes 键序（段找得到）');
  check(_sameOrder(jsCanonKeys, dartCanonKeys),
      '★ canonical 键序 Dart ↔ JS 逐项相同（${jsCanonKeys.join(',')}）');
  check(_sameOrder(jsLeafKeys, dartLeafKeys),
      '★ logBytes 键序 Dart ↔ JS 逐项相同（${jsLeafKeys.join(',')}）');

  check(
    !dartCanonKeys.contains('scope') &&
        !dartCanonKeys.contains('global') &&
        !dartCanonKeys.contains('owner'),
    '★ 载荷里没有 scope/global/owner —— "账号级换钥"无处表达',
  );
  check(
    !dartLeafKeys.contains('sig') && !dartLeafKeys.contains('alg'),
    '★ logBytes 不含 sig/alg（它是 monitor 复算的对象，不是旧钥签的对象）',
  );
  check(
    dartCanonKeys.contains('kind') && dartCanonKeys.contains('alg'),
    '载荷带 kind + alg（挡"拿签发记录冒充换钥"与算法混淆）',
  );

  // =========================================================================
  print('--- ② 接受路径 + 拒绝路径（每条 fail-closed 都有负例） ---');
  final good = _rot(
    oldPub: oldKey.pub,
    newPub: newKey.pub,
  ).copyWith(sig: await oldKey.sign(
        _rot(oldPub: oldKey.pub, newPub: newKey.pub).canonicalBytes(),
      ));

  var v = await IdentityRotation.verify(good, currentPub: oldKey.pub, nowMs: kNow);
  check(v.accept && v.code == 'ok', '旧钥自签的换钥声明 → ok');

  v = await IdentityRotation.verify(good,
      currentPub: oldKey.pub, nowMs: kNow + IdentityRotation.maxSkewMs);
  check(v.accept, '...在时钟偏移窗口的边界上仍接受');

  v = await IdentityRotation.verify(good,
      currentPub: oldKey.pub, nowMs: kNow + IdentityRotation.maxSkewMs + 1);
  check(v.code == RotationFault.staleRotation, '...越界 1ms → stale_rotation');

  v = await IdentityRotation.verify(good.copyWith(sig: ''), currentPub: oldKey.pub);
  check(v.code == RotationFault.missingFields, '缺签名 → missing_fields');

  v = await IdentityRotation.verify(
      _rot(oldPub: 'not-a-key', newPub: newKey.pub, sig: 'x'),
      currentPub: 'not-a-key');
  check(v.code == RotationFault.badPubkey, '坏公钥 → bad_pubkey');

  v = await IdentityRotation.verify(
      _rot(oldPub: oldKey.pub, newPub: oldKey.pub, sig: 'x'),
      currentPub: oldKey.pub);
  check(v.code == RotationFault.noopRotation, '换到自己身上 → noop_rotation（验签之前就拒）');

  v = await IdentityRotation.verify(
      _rot(oldPub: oldKey.pub, newPub: newKey.pub, atMs: 0, sig: 'x'),
      currentPub: oldKey.pub, nowMs: 0);
  check(v.code == RotationFault.badTime, '时间为 0 → bad_time（先于验签）');

  v = await IdentityRotation.verify(good.copyWith(newPub: attacker.pub),
      currentPub: oldKey.pub, nowMs: kNow);
  check(v.code == RotationFault.badSignature, '签完再改 new_pub → bad_signature');

  final forged = _rot(oldPub: oldKey.pub, newPub: newKey.pub).copyWith(
      sig: await attacker.sign(
          _rot(oldPub: oldKey.pub, newPub: newKey.pub).canonicalBytes()));
  v = await IdentityRotation.verify(forged, currentPub: oldKey.pub, nowMs: kNow);
  check(v.code == RotationFault.badSignature, '拿第三方的私钥冒名签 → bad_signature');

  // =========================================================================
  print('--- ③ ★ 重放安全：旧钥退休后再重放同一条声明必须被拒 ---');
  v = await IdentityRotation.verify(good,
      currentPub: newKey.pub, nowMs: kNow);
  check(v.code == RotationFault.notCurrentKey,
      '★ 换钥生效后重放同一条声明 → not_current_key（这正是"旧设备当场失效"）');
  v = await IdentityRotation.verify(good, currentPub: '', nowMs: kNow);
  check(v.code == RotationFault.notCurrentKey, '未登记的身份不能被"换钥"出来');

  // =========================================================================
  print('--- ④ 幂等键：一把旧钥只能退休一次 ---');
  check(IdentityRotation.keyOf(kAgentId, oldKey.pub) == '$kAgentId|${oldKey.pub}',
      'keyOf 形如 agent_id|old_pub（与两边 key_rotations 主键同构）');
  check(
      IdentityRotation.keyOf(kAgentId, oldKey.pub) !=
          IdentityRotation.keyOf(kAgentId, newKey.pub),
      '★ 换到另一把旧钥 = 另一次事件（不会被去重掉）');

  // =========================================================================
  print('--- ⑤ 恢复码三要素：口令错 / ID 不符 / 明文公钥被改 各自被不同的闸拦下 ---');
  const String pw = 'correct horse battery staple';
  final code = await KeyBackup.seal(
    seed: oldKey.seed,
    agentId: kAgentId,
    pubB58: oldKey.pub,
    password: pw,
  );

  final parts = code.split('.');
  check(parts.length == 7 && parts[0] == KeyBackup.prefix, '恢复码前缀/分段正确（FENBK1 + 7 段）');
  check(parts[1] == kAgentId && parts[2] == oldKey.pub,
      '★ 身份与公钥**明文**在码里（输口令前就能核对"这是谁的备份"）');

  final opened = await KeyBackup.open(code, password: pw, expectedAgentId: kAgentId);
  check(opened is BackupOpen, '口令 + ID 正确 → 解出');
  if (opened is BackupOpen) {
    check(opened.agentId == kAgentId, '解出的 agent_id 与输入一致');
    check(opened.pubB58 == oldKey.pub, '解出的公钥与输入一致');
    check(opened.seed.length == Ed25519Sig.pubkeyBytes, '解出的种子是 32 字节');
    // ⚠️ 逐字节比较（不能走 utf8.decode：随机种子不是合法 UTF-8，会抛 FormatException）。
    check(
        opened.seed.length == oldKey.seed.length &&
            List.generate(opened.seed.length, (i) => opened.seed[i] == oldKey.seed[i])
                .every((x) => x),
        '★★ 解出的种子与封进去的种子**逐字节相同**（"备份了" ≠ "能恢复"）');
    check(await KeyBackup.pubFromSeed(opened.seed) == oldKey.pub,
        '★ 由解出的种子重新推导公钥 == 原公钥（换钥声明签得出来）');
  }

  final badPw = await KeyBackup.open(code, password: 'wrong-password-x', expectedAgentId: kAgentId);
  check(badPw is BackupError && badPw.code == BackupFault.badPassword,
      '★ 错口令 → bad_password（GCM 认证失败，fail-closed）');

  final badId = await KeyBackup.open(code, password: pw, expectedAgentId: 'AG-SOMEONEELSE');
  check(badId is BackupError && badId.code == BackupFault.idMismatch,
      '★ 用户 ID 不符 → id_mismatch（且**先于解密**，不浪费一次 KDF）');

  // 改明文段的公钥（不触碰密文）—— GCM 察觉不到，必须由"种子↔公钥配套"这一闸拦住。
  final tampered = [
    parts[0], parts[1], attacker.pub, parts[3], parts[4], parts[5], parts[6],
  ].join('.');
  final pubBad = await KeyBackup.open(tampered, password: pw, expectedAgentId: kAgentId);
  check(pubBad is BackupError && pubBad.code == BackupFault.pubMismatch,
      '★ 改掉明文公钥（密文没动）→ pub_mismatch（否则会静默恢复成另一个身份）');

  final fmtBad = await KeyBackup.open('FENBK1.only.two', password: pw, expectedAgentId: kAgentId);
  check(fmtBad is BackupError && fmtBad.code == BackupFault.badFormat, '分段数不对 → bad_format');

  check(!KeyBackup.isPasswordAcceptable('short'), '短口令不合格（长度门槛成立）');
  check(KeyBackup.isPasswordAcceptable(pw), '长口令合格');

  var threw = false;
  try {
    await KeyBackup.seal(seed: [1, 2, 3], agentId: kAgentId, pubB58: oldKey.pub, password: pw);
  } catch (_) {
    threw = true;
  }
  check(threw, '种子长度非 32 字节 → 直接拒绝（不产出坏码）');

  // =========================================================================
  print('--- ⑥ 留跨语言探针（供 tool/verify_identity_rotation.js 消费） ---');
  File('tool/_identity_rotation_signed.json').writeAsStringSync(jsonEncode(good.toMap()));
  File('tool/_identity_rotation_canonical.txt').writeAsStringSync(good.canonical());
  File('tool/_identity_rotation_leaf.txt').writeAsStringSync(utf8.decode(good.logBytes()));
  check(
    File('tool/_identity_rotation_signed.json').existsSync() &&
        File('tool/_identity_rotation_canonical.txt').existsSync() &&
        File('tool/_identity_rotation_leaf.txt').existsSync(),
    '探针文件已写出（_identity_rotation_signed.json / canonical / leaf）',
  );

  // =========================================================================
  print('');
  print('================ 身份换钥 + 恢复码可验证性校验：$_pass PASS / $_fail FAIL ================');
  // ★ `run_all_verify.dart` 用这个格式解析读数，别改名。
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exit(1);
}
