// 纯 Dart 校验脚本：**会话握手的机密性**（X25519 ECDH + HKDF-SHA256）。
// 运行：dart run tool/verify_session_crypto.dart
//
// ## 抓的是什么
//
// 这类缺陷**签名验得出、TOFU 记得住、静态分析全绿**，却把"机密性"整个漏掉：
//
// 旧方案 `session_crypto` / `crypto_utils` 把 AES 密钥与 IV
// （`pocketagent2026supersecretkey123`）**硬编码进客户端**。密钥既然随 App 分发，
// 就等于公开 —— 任何拿到 APK 的**被动窃听者**都能解出 HELLO 里的"会话材料"，
// 再由 `sha256(sorted(双方材料))` 推出**每会话密钥**。
// 结果：业务消息虽为 AES-GCM，**对窃听者不再保密**。
//
// 关键区分：**Ed25519 验签 / TOFU 只保证"对面确实是本人"（认证），
// 不保证"只有对面看得见"（机密性）** —— 这是两件事，签名不提供机密性。
//
// ## 新方案要钉住的性质
//
// 1. 会话密钥 = `HKDF(X25519(myPriv, peerXPub))` —— **必须持有私钥才能算出**；
// 2. 因此会话密钥**不得等于任何"仅由双方公钥算出"的值** ——
//    这正是旧方案的派生形式，是本脚本的**核心反例断言**；
// 3. 静态密钥与 `CryptoUtils` 必须**从源码里彻底消失**（fail-closed：不再有兜底回退）。

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/session_handshake.dart';

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

List<int> _sortedConcat(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  var cmp = 0;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) {
      cmp = a[i] - b[i];
      break;
    }
  }
  if (cmp == 0) cmp = a.length - b.length;
  return cmp <= 0 ? [...a, ...b] : [...b, ...a];
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 去注释，但**保留字符串里的 `//` 与 `/* */`**（本仓有大量 `https://`）。
///
/// 必需：源码里的**说明文字**会引用旧静态密钥字面量当反面教材
/// （如 `session_handshake.dart` 文件头），若不过滤，守卫会被自己的注释误报 ——
/// 这种"判据被说明文字污染"的假红比不设守卫更糟（见 `verify_data_keys.dart` 文件头 (a)）。
String _stripComments(String src) {
  final out = StringBuffer();
  final n = src.length;
  var i = 0;
  while (i < n) {
    final ch = src[i];
    if (ch == '/' && i + 1 < n && src[i + 1] == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (ch == '/' && i + 1 < n && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (ch == 'r' && i + 1 < n && (src[i + 1] == "'" || src[i + 1] == '"')) {
      out.write(ch);
      i++;
      continue;
    }
    if (ch == "'" || ch == '"') {
      final q = ch;
      final triple = i + 2 < n && src[i + 1] == q && src[i + 2] == q;
      final delim = triple ? q * 3 : q;
      out.write(delim);
      i += delim.length;
      while (i < n && !src.startsWith(delim, i)) {
        if (src[i] == r'\' && i + 1 < n) {
          out.write(src[i]);
          i++;
        }
        out.write(src[i]);
        i++;
      }
      if (i < n) {
        out.write(delim);
        i += delim.length;
      }
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

Future<void> main() async {
  // ---------------------------------------------------------------------------
  print('--- ① 规范串与公钥编码 ---');
  check(SessionHandshake.canonicalHello('AG-1', 'EDPUB', 'XPUB') ==
      'HELLO|AG-1|EDPUB|XPUB', 'HELLO 规范串格式固定（防迁移漂移）');
  check(SessionHandshake.xPubLength == 32, 'X25519 公钥长度 = 32 字节');

  final a = await SessionHandshake.newEphemeralKeyPair();
  final aPubB58 = await SessionHandshake.ephemeralPubBase58(a);
  final aPub = await a.extractPublicKey();
  check(aPub.bytes.length == 32, '生成的 X25519 公钥为 32 字节');
  check(AgentProtocol.base58Encode(aPub.bytes) == aPubB58, 'base58 编码确定');
  check(
      _eq(SessionHandshake.publicKeyFromBase58(aPubB58).bytes, aPub.bytes),
      'base58 ↔ 公钥往返一致');
  var threw = false;
  try {
    SessionHandshake.publicKeyFromBase58('2short9');
  } catch (_) {
    threw = true;
  }
  check(threw, '长度不符的 base58 公钥 → 抛错（不静默接受）');

  // ---------------------------------------------------------------------------
  print('');
  print('--- ② ECDH 对称性（两端各自算出的密钥必须一致）---');
  final b = await SessionHandshake.newEphemeralKeyPair();
  final bPub = await b.extractPublicKey();

  final keyAB = await SessionHandshake.deriveSessionKey(
      myKeyPair: a, peerPublicKey: bPub);
  final keyBA = await SessionHandshake.deriveSessionKey(
      myKeyPair: b, peerPublicKey: aPub);
  check(keyAB.length == 32, '会话密钥 32 字节');
  check(_eq(keyAB, keyBA), 'A(priv)+B(pub) 与 B(priv)+A(pub) 派生出同一密钥');

  final keyAB2 = await SessionHandshake.deriveSessionKey(
      myKeyPair: a, peerPublicKey: bPub);
  check(_eq(keyAB, keyAB2), '同输入 → 同密钥（HKDF 确定性）');

  // ---------------------------------------------------------------------------
  print('');
  print('--- ③ 机密性：会话密钥不得"仅凭公钥"算出（核心反例）---');
  // 旧方案的派生形式：sha256(sorted(双方"材料"))。材料曾是公开可解的，
  // 于是被动窃听者仅凭公钥/公开数据即可复算同一密钥。
  check(
      !_eq(keyAB, sha256.convert(_sortedConcat(aPub.bytes, bPub.bytes)).bytes),
      '会话密钥 ≠ sha256(sorted(pubA, pubB))（旧方案的派生形式，必须不等）');
  check(
      !_eq(keyAB, sha256.convert([...aPub.bytes, ...bPub.bytes]).bytes),
      '会话密钥 ≠ sha256(pubA || pubB)');
  check(
      !_eq(keyAB, sha256.convert([...bPub.bytes, ...aPub.bytes]).bytes),
      '会话密钥 ≠ sha256(pubB || pubA)');

  // 第三方 C：只拿得到 A、B 的公钥（+ 自己的私钥）
  final c = await SessionHandshake.newEphemeralKeyPair();
  final cPrivPub = await c.extractPublicKey();
  final keyCA = await SessionHandshake.deriveSessionKey(
      myKeyPair: c, peerPublicKey: aPub);
  check(!_eq(keyAB, keyCA), '第三方密钥对推出的值 ≠ 真实会话密钥');
  check(!_eq(keyAB, cPrivPub.bytes), '会话密钥 ≠ 任何暴露的公钥字节');

  // 会话新鲜性：换一对临时密钥 → 密钥必须变（证明依赖私钥材料）
  final a2 = await SessionHandshake.newEphemeralKeyPair();
  final keyA2B = await SessionHandshake.deriveSessionKey(
      myKeyPair: a2, peerPublicKey: bPub);
  check(!_eq(keyAB, keyA2B), '换临时密钥对 → 会话密钥随之改变（前向安全）');

  // ---------------------------------------------------------------------------
  print('');
  print('--- ④ 身份签名：篡改必须被挡住 ---');
  final ed = Ed25519();
  final edKp = await ed.newKeyPair();
  final edPubB58 = AgentProtocol.base58Encode((await edKp.extractPublicKey()).bytes);

  String canon(String id, String xpub) =>
      SessionHandshake.canonicalHello(id, edPubB58, xpub);
  final sig = await ed.sign(utf8.encode(canon('AG-9', aPubB58)), keyPair: edKp);
  final sigB64 = base64Encode(sig.bytes);

  check(
      await AgentProtocol.verifyRawSignature(
          utf8.encode(canon('AG-9', aPubB58)), sigB64, edPubB58),
      '未篡改的 HELLO 规范串验签通过');
  check(
      !(await AgentProtocol.verifyRawSignature(
          utf8.encode(canon('AG-9', await SessionHandshake.ephemeralPubBase58(b))),
          sigB64,
          edPubB58)),
      '替换 xpub → 验签失败（防中间人替换密钥）');
  check(
      !(await AgentProtocol.verifyRawSignature(
          utf8.encode(canon('AG-EVIL', aPubB58)), sigB64, edPubB58)),
      '替换 agentId → 验签失败（防截获重放冒名）');

  // ---------------------------------------------------------------------------
  print('');
  print('--- ⑤ 静态密钥 / CryptoUtils 已从源码彻底移除（fail-closed）---');
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String? keyHit;
  String? ivHit;
  String? cryptoUtilHit;
  for (final f in dartFiles) {
    final src = _stripComments(f.readAsStringSync());
    if (src.contains('pocketagent2026supersecretkey123')) keyHit ??= f.path;
    if (src.contains('pocketagent_iv__')) ivHit ??= f.path;
    if (src.contains('CryptoUtils')) cryptoUtilHit ??= f.path;
  }
  check(keyHit == null,
      '全仓无静态 AES 密钥字面量${keyHit == null ? '' : '（仍存在于 $keyHit）'}');
  check(ivHit == null,
      '全仓无静态 IV 字面量${ivHit == null ? '' : '（仍存在于 $ivHit）'}');
  check(cryptoUtilHit == null,
      '全仓无 CryptoUtils 引用${cryptoUtilHit == null ? '' : '（仍存在于 $cryptoUtilHit）'}');
  check(!File('lib/core/crypto_utils.dart').existsSync(),
      'lib/core/crypto_utils.dart 已删除');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
