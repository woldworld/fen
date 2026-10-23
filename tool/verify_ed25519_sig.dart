// 纯 Dart 校验脚本：Ed25519 单一验签实现（lib/core/ed25519_sig.dart）。
// 运行：dart run tool/verify_ed25519_sig.dart
//
// 为什么单独验它：这是 M6 背书 / M9 技能 / M10 权益（贡献账本 / 房间角色）
// 共用的**唯一**验签实现（`ed25519_sig.dart` 文件头明写"绝不要复制一份"）。
// 此前它只被 verify_contribution_ledger / verify_reputation_network /
// verify_skill_registry **间接**跑到 —— 那些脚本关心的是"业务载荷签得对不对"，
// **没有一个**在问实现本身：
//   · 它真的是**标准 Ed25519** 吗（还是"自签自验自洽"但对外不兼容）？
//   · 公钥 / 签名**长度不对**时会不会 fail-closed？
//   · 坏 base58 / 坏 base64 会不会把异常抛出去？
//
// 本脚本先用 **RFC 8032 已知答案向量（KAT）** 钉死"标准性"，再穷尽 fail-closed 边界，
// 最后断言它与 `AgentProtocol.verifyRawSignature` **口径完全一致**（两处一旦漂移即红）。

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/ed25519_sig.dart';

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

List<int> _hex(String h) {
  final out = <int>[];
  for (var i = 0; i + 1 < h.length; i += 2) {
    out.add(int.parse(h.substring(i, i + 2), radix: 16));
  }
  return out;
}

String _b64(List<int> b) => base64Encode(b);

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<void> main() async {
  final ed = Ed25519();

  print('--- ① 常量钉死（写进 canonical 载荷，改动会让全线签名失效）---');
  check(Ed25519Sig.alg == 'ed25519', "alg == 'ed25519'");
  check(Ed25519Sig.alg == AgentProtocol.algEd25519, 'alg 与协议常量一致');
  check(Ed25519Sig.pubkeyBytes == 32, '公钥 32 字节');
  check(Ed25519Sig.signatureBytes == 64, '签名 64 字节');

  print('--- ② RFC 8032 已知答案测试（证明是标准 Ed25519，不是自洽的私货）---');
  // §7.1 TEST 1：种子 → 公钥 → 空消息签名
  final seed1 = _hex(
      '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
  final pub1 = _hex(
      'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a');
  final sig1 = _hex(
      'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b');
  final kp1 = await ed.newKeyPairFromSeed(seed1);
  check(_eq((await kp1.extractPublicKey()).bytes, pub1), 'KAT-1 公钥由种子派生逐字节一致');
  check(_eq((await ed.sign(const <int>[], keyPair: kp1)).bytes, sig1),
      'KAT-1 空消息签名逐字节一致');
  final pub1B58 = AgentProtocol.base58Encode(pub1);
  check(
      await Ed25519Sig.verify(
          message: const <int>[],
          signatureB64: _b64(sig1),
          publicKeyBase58: pub1B58),
      'KAT-1 标准向量 → 本实现验签通过（对外兼容的机器证明）');

  // §7.1 TEST 2：单字节消息 0x72
  final seed2 = _hex(
      '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb');
  final pub2 = _hex(
      '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c');
  final sig2 = _hex(
      '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00');
  final kp2 = await ed.newKeyPairFromSeed(seed2);
  check(_eq((await kp2.extractPublicKey()).bytes, pub2), 'KAT-2 公钥一致');
  check(_eq((await ed.sign(const [0x72], keyPair: kp2)).bytes, sig2),
      'KAT-2 单字节消息签名一致');

  print('--- ③ isPubkey 边界（只认真 32 字节 base58）---');
  final pub2B58 = AgentProtocol.base58Encode(pub2);
  check(Ed25519Sig.isPubkey(pub2B58), '真公钥 → true');
  check(!Ed25519Sig.isPubkey(''), '空串 → false');
  check(!Ed25519Sig.isPubkey('0OIl'), '含 base58 非法字符 → false（不抛）');
  check(
      !Ed25519Sig.isPubkey(AgentProtocol.base58Encode(pub2.sublist(0, 31))),
      '31 字节 → false');
  check(!Ed25519Sig.isPubkey(AgentProtocol.base58Encode([...pub2, 9])),
      '33 字节 → false');
  check(
      !Ed25519Sig.isPubkey(
          AgentProtocol.base58Encode(List<int>.filled(100, 7))),
      '100 字节（合法 base58 但长度不对）→ false');

  print('--- ④ verify 正例（positive control：缺它则下面反例全是"恒假"）---');
  // 固定种子 → 签名确定性 → 结果可复算
  final kpA = await ed.newKeyPairFromSeed(List<int>.generate(32, (i) => i + 1));
  final pubA = (await kpA.extractPublicKey()).bytes;
  final pubAB58 = AgentProtocol.base58Encode(pubA);
  final msg = utf8.encode('wold|M9|skill-signature|canonical-payload');
  final sigA = (await ed.sign(msg, keyPair: kpA)).bytes;
  final sigAB64 = _b64(sigA);

  check(
      await Ed25519Sig.verify(
          message: msg, signatureB64: sigAB64, publicKeyBase58: pubAB58),
      '真签名 → true');
  check(
      await Ed25519Sig.verify(
          message: msg, signatureB64: sigAB64, publicKeyBase58: pubAB58),
      '二次调用仍 true（确定性，可复算）');
  check(Ed25519Sig.isPubkey(pubAB58), '签名者公钥本身合法');

  print('--- ⑤ verify 反例（fail-closed：任何畸形都必须 false，且绝不抛）---');
  check(
      !await Ed25519Sig.verify(
          message: utf8.encode('tampered message'),
          signatureB64: sigAB64,
          publicKeyBase58: pubAB58),
      '消息被改 → false');

  final sigT = base64Decode(sigAB64);
  sigT[0] = sigT[0] ^ 0xFF;
  check(
      !await Ed25519Sig.verify(
          message: msg, signatureB64: _b64(sigT), publicKeyBase58: pubAB58),
      '签名翻一字节 → false');

  final kpB = await ed.newKeyPairFromSeed(List<int>.filled(32, 42));
  final pubBB58 = AgentProtocol.base58Encode((await kpB.extractPublicKey()).bytes);
  check(
      !await Ed25519Sig.verify(
          message: msg, signatureB64: sigAB64, publicKeyBase58: pubBB58),
      '换成另一把**合法**公钥（张冠李戴）→ false');

  check(
      !await Ed25519Sig.verify(
          message: msg, signatureB64: sigAB64, publicKeyBase58: '0OIl!!'),
      '公钥含非法 base58 字符 → false（不抛）');
  check(
      !await Ed25519Sig.verify(
          message: msg, signatureB64: sigAB64, publicKeyBase58: ''),
      '公钥空串 → false');
  check(
      !await Ed25519Sig.verify(
          message: msg,
          signatureB64: sigAB64,
          publicKeyBase58: AgentProtocol.base58Encode(pubA.sublist(0, 31))),
      '公钥 31 字节 → false');
  check(
      !await Ed25519Sig.verify(
          message: msg,
          signatureB64: sigAB64,
          publicKeyBase58: AgentProtocol.base58Encode([...pubA, 9])),
      '公钥 33 字节 → false');

  check(
      !await Ed25519Sig.verify(
          message: msg, signatureB64: '', publicKeyBase58: pubAB58),
      '签名空串 → false');
  check(
      !await Ed25519Sig.verify(
          message: msg,
          signatureB64: 'not base64!!!',
          publicKeyBase58: pubAB58),
      '签名非 base64 → false（不抛）');
  final sig63 = sigA.sublist(0, 63);
  check(
      !await Ed25519Sig.verify(
          message: msg, signatureB64: _b64(sig63), publicKeyBase58: pubAB58),
      '签名 63 字节 → false');
  final sig65 = [...sigA, 0];
  check(
      !await Ed25519Sig.verify(
          message: msg, signatureB64: _b64(sig65), publicKeyBase58: pubAB58),
      '签名 65 字节 → false');
  check(
      !await Ed25519Sig.verify(
          message: msg,
          signatureB64: _b64(List<int>.filled(64, 0)),
          publicKeyBase58: pubAB58),
      '签名长度合法但内容错（全零）→ false');

  print('--- ⑥ 与 AgentProtocol.verifyRawSignature 口径一致（防两处漂移）---');
  check(await AgentProtocol.verifyRawSignature(msg, sigAB64, pubAB58),
      '协议侧对真签名也 true');
  final pairs = <(List<int>, String, String)>[
    (msg, sigAB64, pubAB58), // 正例
    (msg, _b64(sigT), pubAB58), // 签名被改
    (utf8.encode('x'), sigAB64, pubAB58), // 消息不同
    (msg, sigAB64, pubBB58), // 公钥不同
    (msg, _b64(sig63), pubAB58), // 签名长度错
    (msg, '', pubAB58), // 空签名
    (msg, sigAB64, ''), // 空公钥
  ];
  var agree = true;
  var firstDisagree = -1;
  for (var i = 0; i < pairs.length; i++) {
    final (m, s, k) = pairs[i];
    final a = await Ed25519Sig.verify(
        message: m, signatureB64: s, publicKeyBase58: k);
    final b = await AgentProtocol.verifyRawSignature(m, s, k);
    if (a != b) {
      agree = false;
      if (firstDisagree < 0) firstDisagree = i;
    }
  }
  check(agree, '7 组输入上两处实现结果完全一致（漂移即红，首个不一致 #$firstDisagree）');

  print('--- ⑦ base58 往返（公钥编解码无漂移）---');
  check(_eq(AgentProtocol.base58Decode(pubAB58), pubA),
      'decode(encode(pub)) == pub');
  check(AgentProtocol.base58Encode(const <int>[]) == '', '空字节 → 空串');
  check(AgentProtocol.base58Decode('').isEmpty, '空串 → 空字节（不抛）');
  var threw = false;
  try {
    AgentProtocol.base58Decode('0');
  } catch (_) {
    threw = true;
  }
  check(threw, '非法字符 → base58Decode 抛（由调用方 fail-closed 兜住）');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
