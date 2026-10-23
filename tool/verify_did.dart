// 纯 Dart 校验脚本：验证 did:wold 身份签发（PRD §5.4 不可补录项）。
// 运行：dart run tool/verify_did.dart

import 'package:dahuang_ai/core/circle_service.dart';
import 'package:dahuang_ai/core/wold_did.dart';

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
  print('--- DID 格式 ---');
  final signer = await Ed25519Signer.generate();
  final pub = await signer.publicKeyBase58();
  final did = WoldDid.fromPub(pub);

  check(did.startsWith('did:wold:'), '前缀 did:wold:');
  check(WoldDid.isValid(did), '自产 DID 合法');
  check(WoldDid.pubOf(did) == pub, 'DID 里能取回公钥');
  check(!WoldDid.isValid('did:pocketagent:abc'), '旧体系 DID 不认');
  check(!WoldDid.isValid('did:wold:'), '空公钥不认');
  check(!WoldDid.isValid('did:wold:!!!not-base58!!!'), '非 base58 不认');
  check(!WoldDid.isValid('did:wold:2short9'), '公钥不是 32 字节不认');

  print('--- 签发凭证 ---');
  final t = DateTime.now().millisecondsSinceEpoch;
  final canonical = WoldDid.issuanceCanonical(did: did, pub: pub, issuedAtMs: t);
  check(canonical == 'ISSUE|$did|$pub|$t', '规范串格式固定（防迁移漂移）');

  final sig = await signer.signBytes(canonical.codeUnits);
  check(
      await WoldDid.verifyIssuance(
          did: did, pub: pub, issuedAtMs: t, sigBase64: sig),
      '自签名可验证');

  print('--- 篡改检测 ---');
  check(
      !(await WoldDid.verifyIssuance(
          did: did, pub: pub, issuedAtMs: t + 1, sigBase64: sig)),
      '改签发时刻 → 签名失效');

  final other = await Ed25519Signer.generate();
  final otherPub = await other.publicKeyBase58();
  check(
      !(await WoldDid.verifyIssuance(
          did: did, pub: otherPub, issuedAtMs: t, sigBase64: sig)),
      'DID 与公钥不配套 → 拒绝（张冠李戴检测）');

  // 用别人的钥签同一份 canonical → 验签应失败（签名者公钥 = 记录里的 pub）
  check(
      !(await WoldDid.verifyIssuance(
          did: did,
          pub: pub,
          issuedAtMs: t,
          sigBase64: await other.signBytes(canonical.codeUnits))),
      '他人签名 → 验签失败');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
