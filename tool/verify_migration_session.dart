// 纯 Dart 校验脚本：换机直迁**会话层**（报文 + 双角色状态机）的离线复算。
// 运行：dart run tool/verify_migration_session.dart
//
// 为什么值得单独一个脚本：
//   直迁这条链路里，**票据格式**（`device_migration.dart`）已经被钉住了；
//   而真正会出人命的失败在**次序与绑定**上，它们都不报错、只静静地走错：
//     · 老机在用户没按确认键之前就把身份签出去了（"机器替用户交出身份"）；
//     · 新机收到一条**指向别人公钥**的 ROTATE 就照单全收
//       （中间人把 `new_pub` 掉包 ⇒ 身份迁进攻击者手里）；
//     · 一张被重放的旧要约在新一轮会话里再次被受理。
//   这三条都**不会**让任何一端崩掉，所以只能靠断言钉住。
//
// 本脚本只 import **零平台依赖**的模块，故可在独立 Dart VM 里跑完整条流程：
// 两个会话对象互相收发报文，全程经过真实的编解码与验签。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dahuang_ai/core/device_migration.dart';
import 'package:dahuang_ai/core/ed25519_sig.dart';
import 'package:dahuang_ai/core/key_backup.dart';
import 'package:dahuang_ai/core/migration_session.dart';

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

/// 剥掉注释再扫源码（本项目正文刻意引用旧写法作反面教材，注释里也有同样的词）。
String _noComments(String src) {
  final out = StringBuffer();
  var i = 0;
  final n = src.length;
  while (i < n) {
    final c = src[i];
    if (c == '/' && i + 1 < n && src[i + 1] == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

const String _agent = 'AG-MIGRATE001';
const String _peerA = 'AG-NEWOWNER1'; // 新机自己的分身 ID（仅用于路由）
const String _peerB = 'AG-OLDOWNER1'; // 老机自己的分身 ID

int _now = 1700000000000;

/// 用**种子**签一段字节（等价于设备私钥签名；本脚本只碰公钥推导与签名结果）。
Future<String> _signWith(List<int> seed, List<int> message) async {
  final kp = await Ed25519().newKeyPairFromSeed(Uint8List.fromList(seed));
  final sig = await Ed25519().sign(message, keyPair: kp);
  return base64Encode(sig.bytes);
}

/// 把一端发出来的报文投递给另一端（**真的走一遍编解码**）。
Future<MigrationStep> _deliver(String? wire, MigrationSession to) async {
  if (wire == null) return MigrationStep.failed('no_outbound');
  final p = MigrationWire.tryParse(wire);
  if (p == null) return MigrationStep.failed(MigrationSessionFault.badWire);
  return to.route(p, nowMs: _now);
}

/// 复刻"老机收到 request 后铸票"这一步，便于单独测它的反例。
MigrationStep _responderOnRequest(MigrationSession b, String wire) {
  final p = MigrationWire.tryParse(wire)!;
  return b.onRequest(p, nowMs: _now);
}

Future<void> main() async {
  print('== 换机直迁（会话层：报文 + 双角色状态机） ==');

  final newSeed = List<int>.generate(32, (i) => i + 11); // 新机自己的新种子
  final oldSeed = List<int>.generate(32, (i) => i + 21); // 老机当前持有的种子
  final evilSeed = List<int>.generate(32, (i) => i + 31); // 中间人

  final newPub = await KeyBackup.pubFromSeed(newSeed);
  final oldPub = await KeyBackup.pubFromSeed(oldSeed);
  final evilPub = await KeyBackup.pubFromSeed(evilSeed);

  // ------------------------------------------------------------- 报文层
  print('-- 报文线格式（fail-closed） --');
  final good = MigrationWire.encode(
    kind: MigrationWireKind.request,
    agentId: _agent,
    body: {'new_pub': newPub},
  );
  final parsed = MigrationWire.tryParse(good);
  check(parsed != null, '自己编的报文能解析回来');
  check(parsed!.kind == MigrationWireKind.request && parsed.agentId == _agent,
      'kind / agent_id 往返一致');
  check(parsed.body['new_pub'] == newPub, 'body 往返一致');
  check(MigrationWire.tryParse('') == null, '空串 → null');
  check(MigrationWire.tryParse('not json') == null, '非 JSON → null');
  check(MigrationWire.tryParse('[]') == null, 'JSON 数组 → null');
  check(
      MigrationWire.tryParse(
              '{"dm_type":"mig","v":1,"kind":"nope","agent_id":"x"}') ==
          null,
      '未知 kind → null（不做"尽量解析"）');
  check(
      MigrationWire.tryParse(
              '{"dm_type":"mig","v":2,"kind":"request","agent_id":"x"}') ==
          null,
      '版本不符 → null');
  check(
      MigrationWire.tryParse(
              '{"dm_type":"deleg","v":1,"kind":"request","agent_id":"x"}') ==
          null,
      '别家的报文（deleg）→ null（不会误吞别人的消息）');
  check(
      MigrationWire.tryParse(
              '{"dm_type":"mig","v":1,"kind":"request","agent_id":""}') ==
          null,
      '空 agent_id → null');
  final pad = 'a'.padRight(MigrationWire.maxChars + 20, 'a');
  check(
      MigrationWire.tryParse(
              '{"dm_type":"mig","v":1,"kind":"request","agent_id":"x","body":{"pad":"$pad"}}') ==
          null,
      '超过 ${MigrationWire.maxChars} 字节 → null（不对超大报文做解析）');
  check(MigrationWire.version == 1 && MigrationWire.typeValue == 'mig',
      '版本与类型常量 = v1 / mig');

  // ------------------------------------------------------------- 正常全程
  print('-- 正常全程：request → offer → confirm → rotate → ack --');
  final ledger = MigrationNonceLedger();
  final a = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now, ledger: ledger);
  final b = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);

  check(a.role == MigrationRole.initiator && b.role == MigrationRole.responder,
      '两个角色就位');
  check(a.compareCodeDisplay == null, '还没有票据时**不给**短码（而不是给空串）');

  final req = a.beginRequest();
  check(req.ok && req.outbound != null, '① 新机发出 request');
  check(MigrationWire.tryParse(req.outbound!)!.kind == MigrationWireKind.request,
      '   报文 kind = request');
  check(a.phase == MigrationPhase.idle, '   发出 request 后阶段仍为 idle（还没拿到要约）');
  check(!a.beginRequest().ok, '   同一会话不得重复发 request（wrongPhase）');

  final offerStep = _responderOnRequest(b, req.outbound!);
  check(offerStep.ok && offerStep.outbound != null, '② 老机收到 request → 铸票回 offer');
  check(b.ticket != null && b.phase == MigrationPhase.awaitingPeerConfirm,
      '   老机阶段 = awaitingPeerConfirm');
  check(b.peerNewPub == newPub, '   老机记住了对端那把新公钥');
  check(b.ticket!.oldPub == oldPub, '   票据里的 old_pub = 老机当前活跃钥');
  check(b.ticket!.agentId == _agent, '   票据身份一致');

  final offerBack = await _deliver(offerStep.outbound, a);
  check(offerBack.ok, '③ 新机收到 offer');
  check(a.phase == MigrationPhase.offered && a.ticket != null, '   新机阶段 = offered');
  check(a.ticket!.nonceB64 == b.ticket!.nonceB64, '   两端看到同一枚 nonce');
  check(
      a.compareCodeDisplay != null &&
          a.compareCodeDisplay == b.compareCodeDisplay,
      '★★ 两屏短码一致（"${a.compareCodeDisplay}"）—— 这是人眼比对能成立的前提');
  check(a.compareCodeDisplay!.contains('-') && a.compareCodeDisplay!.length == 7,
      '   展示形态为 XXX-XXX');

  // 中间人掉包 new_pub ⇒ 两屏短码必须不同
  final evilA = MigrationSession.startAsInitiator(
      agentId: _agent,
      peerId: _peerB,
      newPub: evilPub,
      nowMs: _now,
      ledger: MigrationNonceLedger());
  evilA.beginRequest();
  // `onOffer` 是纯同步函数（返回 `MigrationStep`，不是 Future）——
  // 顺手去掉一个多写的 `await`（`await_only_futures`）。
  evilA.onOffer(
      MigrationWire.tryParse(offerStep.outbound!)!, nowMs: _now);
  check(evilA.compareCodeDisplay != b.compareCodeDisplay,
      '★★ 攻击者换掉 new_pub ⇒ 短码不同（掉包无法骗过两屏比对）');

  final conf = await _deliver(a.confirm().outbound, b);
  check(conf.ok, '④ 新机确认 → 老机收到 confirm');
  check(b.phase == MigrationPhase.peerConfirmed, '   老机阶段 = peerConfirmed');
  check(b.rotation == null, '★★ 此时**还没有签**（收到网络上的确认 ≠ 用户同意）');
  check(!b.migratedOut, '   此时尚未迁出');

  // 未经"用户拍板"的签名请求必须被拒，且**失败路径不碰私钥**
  var signCalls = 0;
  final fresh = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  _responderOnRequest(fresh, req.outbound!);
  final premature = await fresh.signRotation(
    sign: (m) async {
      signCalls++;
      return _signWith(oldSeed, m);
    },
    nowMs: _now,
  );
  check(!premature.ok && premature.fault == MigrationSessionFault.notConfirmed,
      '★★ 对端还没确认就想签 → notConfirmed');
  check(signCalls == 0, '★★ 被拒时签名器**零调用**（失败路径不碰私钥）');

  // 用户按了确认键 ⇒ 才允许签
  final signedStep = await b.signRotation(
    sign: (m) async {
      signCalls++;
      return _signWith(oldSeed, m);
    },
    nowMs: _now,
  );
  check(signedStep.ok && signedStep.outbound != null, '⑤ 用户拍板 → 老机签出 ROTATE');
  check(signCalls == 1, '   签名器恰好被调用 1 次');
  check(b.phase == MigrationPhase.signed, '   老机阶段 = signed');
  check(b.rotation != null && b.rotation!.newPub == newPub,
      '★ 签出的声明里 new_pub = **新机那把**（不是别处的）');
  check(b.rotation!.oldPub == oldPub && b.rotation!.agentId == _agent,
      '   签出的声明里 old_pub / agent_id 都对');
  check(utf8.encode(b.rotation!.canonical()).isNotEmpty, '   canonical 非空');
  check(await b.rotation!.sigValid(), '   签名本地自验通过');

  final rotStep = await _deliver(signedStep.outbound, a);
  check(rotStep.ok, '⑥ 新机收到 ROTATE');
  check(a.phase == MigrationPhase.awaitingHub && a.readyToSubmitHub,
      '   新机阶段 = awaitingHub（**尚未**装种子）');
  check(a.rotation!.newPub == newPub, '   新机确认声明指向自己');

  final ack = await a.hubResult(
    ok: true,
    did: 'did:wold:$oldPub',
    sign: (m) => _signWith(newSeed, m),
  );
  check(ack.ok && a.phase == MigrationPhase.done, '⑦ Hub 成功 → 新机 done');
  check(a.hubDid == 'did:wold:$oldPub', '   身份锚被记下（供落盘时用）');

  final ackBack = await _deliver(ack.outbound, b);
  check(ackBack.ok && b.phase == MigrationPhase.done, '⑧ 老机收到 ack → done');
  check(b.migratedOut, '★★ 老机置 migratedOut（同一身份不再作为本机身份使用）');

  // ------------------------------------------------------------- 反例：绑定
  print('-- ★★ 绑定不符必须被拒（中间人掉包"迁往哪把钥"） --');
  final a2 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final b2 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final off2 = _responderOnRequest(b2, a2.beginRequest().outbound!);
  await _deliver(off2.outbound, a2);
  await _deliver(a2.confirm().outbound, b2);
  await b2.signRotation(sign: (m) => _signWith(oldSeed, m), nowMs: _now);

  // 最坏情形：老机被骗着签了**攻击者的公钥** —— 签名本身完全合法。
  final forged = b2.rotation!.copyWith(newPub: evilPub);
  final forgedSigned =
      forged.copyWith(sig: await _signWith(oldSeed, forged.canonicalBytes()));
  check(await forgedSigned.sigValid(), '（前置）伪造声明的签名**是合法的**（老机签的）');
  final forgedWire = MigrationWire.encode(
    kind: MigrationWireKind.rotate,
    agentId: _agent,
    body: {'rotation': forgedSigned.toMap()},
  );
  final rejected = await _deliver(forgedWire, a2);
  check(!rejected.ok && rejected.fault == MigrationSessionFault.bindingMismatch,
      '★★ 新机拒收：new_pub 不是自己那把 → bindingMismatch');
  check(a2.phase == MigrationPhase.offered && a2.rotation == null,
      '   被拒后状态**没有推进**（不会"部分接受"）');

  // old_pub 不符
  final a3 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final b3 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final off3 = _responderOnRequest(b3, a3.beginRequest().outbound!);
  await _deliver(off3.outbound, a3);
  final wrongOld = MigrationWire.encode(
    kind: MigrationWireKind.rotate,
    agentId: _agent,
    body: {
      'rotation': {
        'agent_id': _agent,
        'old_pub': evilPub,
        'new_pub': newPub,
        'rotated_at': _now,
        'sig': 'AAAA',
      }
    },
  );
  final r3 = await _deliver(wrongOld, a3);
  check(!r3.ok && r3.fault == MigrationSessionFault.bindingMismatch,
      '★ old_pub 与要约不符 → bindingMismatch');

  // 签名是假的（绑定都对）
  final a4 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final b4 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final off4 = _responderOnRequest(b4, a4.beginRequest().outbound!);
  await _deliver(off4.outbound, a4);
  final badSig = MigrationWire.encode(
    kind: MigrationWireKind.rotate,
    agentId: _agent,
    body: {
      'rotation': {
        'agent_id': _agent,
        'old_pub': oldPub,
        'new_pub': newPub,
        'rotated_at': _now,
        // 形态合法（64 字节）但内容是假的 → 走到验签才被拒
        'sig': base64Encode(List<int>.filled(Ed25519Sig.signatureBytes, 9)),
      }
    },
  );
  final r4 = await _deliver(badSig, a4);
  check(!r4.ok && r4.fault == MigrationSessionFault.badSignature,
      '★ 绑定都对、签名伪造 → badSignature（**本地**先拦住，不必送 Hub 白跑）');

  // ------------------------------------------------------------- 反例：次序与重放
  print('-- 反例：次序、身份、重放、过期 --');
  final a5 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final b5 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final rotEarly = MigrationWire.encode(
    kind: MigrationWireKind.rotate,
    agentId: _agent,
    body: {
      'rotation': {
        'agent_id': _agent,
        'old_pub': oldPub,
        'new_pub': newPub,
        'rotated_at': _now
      }
    },
  );
  final early = await _deliver(rotEarly, a5);
  check(!early.ok && early.fault == MigrationSessionFault.wrongPhase,
      '★ 还没收到要约就收到 ROTATE → wrongPhase');
  final bEarly = await _deliver(rotEarly, b5);
  check(!bEarly.ok && bEarly.fault == MigrationSessionFault.wrongPhase,
      '★ 老机收到 ROTATE（方向反了）→ wrongPhase');

  final off5 = _responderOnRequest(b5, a5.beginRequest().outbound!);
  await _deliver(off5.outbound, a5);
  final dup = await _deliver(off5.outbound, a5);
  check(!dup.ok && dup.fault == MigrationSessionFault.wrongPhase,
      '★ 同一会话重复投同一份 offer → wrongPhase（不覆盖已有要约）');

  // ★ 跨会话重放：共享同一本账时，旧要约在新会话里也必须被拒
  final sharedLedger = MigrationNonceLedger();
  final a6 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now,
      ledger: sharedLedger);
  final b6 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final off6 = _responderOnRequest(b6, a6.beginRequest().outbound!);
  check((await _deliver(off6.outbound, a6)).ok, '（前置）第一轮会话正常收到要约');

  final a7 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now,
      ledger: sharedLedger);
  a7.beginRequest();
  final replay = await _deliver(off6.outbound, a7);
  check(!replay.ok && replay.fault == MigrationFault.replayedTicket,
      '★★ 换一轮会话重放旧要约 → replayedTicket（账必须跨会话，否则形同虚设）');
  check(a7.phase == MigrationPhase.idle && a7.ticket == null,
      '   被拒后新会话干净（不留下半张票）');

  final aliveLedger = MigrationNonceLedger();
  final a6b = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now,
      ledger: aliveLedger);
  a6b.beginRequest();
  await _deliver(off6.outbound, a6b);
  check(a6b.ticket != null,
      '★ 换一本**没记过**的账时同一份要约仍可受理（说明上一条拒的是"记过"，不是"票坏了"）');

  // 身份不符
  final a8 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  a8.beginRequest();
  final foreign = MigrationTicket.mint(
      agentId: 'AG-SOMEONEELSE', oldPub: oldPub, nowMs: _now);
  final rf = await _deliver(
    MigrationWire.encode(
        kind: MigrationWireKind.offer,
        agentId: _agent,
        body: {'ticket': foreign.encode()}),
    a8,
  );
  check(!rf.ok && rf.fault == MigrationSessionFault.peerMismatch,
      '★ 要约是给另一个身份的 → peerMismatch（"拿 B 的票接管 A"被挡）');

  // 过期票据
  final staleTicket =
      MigrationTicket.mint(agentId: _agent, oldPub: oldPub, nowMs: _now);
  final staleWire = MigrationWire.encode(
    kind: MigrationWireKind.offer,
    agentId: _agent,
    body: {'ticket': staleTicket.encode()},
  );
  final a9 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  a9.beginRequest();
  check((await _deliver(staleWire, a9)).ok, '（前置）刚铸的票在窗口内可受理');
  final a10 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  a10.beginRequest();
  _now += MigrationFormat.ttlMs + MigrationFormat.clockSkewToleranceMs + 1;
  final rExpired = await _deliver(staleWire, a10);
  check(!rExpired.ok && rExpired.fault == MigrationFault.expiredTicket,
      '★ 过期票据 → expiredTicket');
  _now -= MigrationFormat.ttlMs + MigrationFormat.clockSkewToleranceMs + 1;

  // 有效期离谱（伪造一份"长期有效"的票）
  final a11 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  a11.beginRequest();
  final farFuture = MigrationTicket(
    agentId: _agent,
    oldPub: oldPub,
    nonceB64: MigrationFormat.b64u(MigrationFormat.newNonceBytes()),
    expMs: _now + MigrationFormat.maxAheadMs + 60 * 1000,
  );
  final rFar = await _deliver(
    MigrationWire.encode(
        kind: MigrationWireKind.offer,
        agentId: _agent,
        body: {'ticket': farFuture.encode()}),
    a11,
  );
  check(!rFar.ok && rFar.fault == MigrationFault.badExpiry,
      '★ 有效期远在未来 → badExpiry（伪造"长期有效"的要约没用）');

  // ★ 没人开口要过票，却有人送票来 —— "抢先应答 / 主动投递"的形状
  final silent = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  check(!silent.asked, '新会话初始为"还没开口"');
  final rUnsolicited = await _deliver(staleWire, silent);
  check(!rUnsolicited.ok && rUnsolicited.fault == MigrationSessionFault.notAsked,
      '★ 没发过 request 就收到 offer → notAsked（老机只在被要过之后才铸票）');

  // 老机侧：对端塞一把坏公钥 / 一把与自己相同的公钥
  final b12 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final rBad = b12.onRequest(
      MigrationWire.tryParse(MigrationWire.encode(
          kind: MigrationWireKind.request,
          agentId: _agent,
          body: {'new_pub': 'not-a-pub'}))!,
      nowMs: _now);
  check(!rBad.ok && rBad.fault == MigrationSessionFault.badWire,
      '★ 对端给的 new_pub 形态非法 → badWire（不铸票）');
  final b13 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final rSelf = b13.onRequest(
      MigrationWire.tryParse(MigrationWire.encode(
          kind: MigrationWireKind.request,
          agentId: _agent,
          body: {'new_pub': oldPub}))!,
      nowMs: _now);
  check(
      !rSelf.ok && rSelf.fault == MigrationSessionFault.bindingMismatch,
      '★ 对端要求"用我这把钥接管我自己" → bindingMismatch（也就是 Hub 的 noop_rotation）');

  // ------------------------------------------------------------- 取消与 Hub 失败
  print('-- 取消 / Hub 失败 --');
  final a14 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final b14 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final off14 = _responderOnRequest(b14, a14.beginRequest().outbound!);
  await _deliver(off14.outbound, a14);
  final cancelPacket =
      MigrationWire.tryParse(a14.cancelWire(reason: 'user_abort'))!;
  final rc = await b14.route(cancelPacket, nowMs: _now);
  check(
      rc.ok &&
          b14.phase == MigrationPhase.failed &&
          b14.fault == MigrationSessionFault.cancelledByPeer,
      '★ 对端取消 → 本端 failed + cancelledByPeer（不会永远挂着等）');
  check(!b14.migratedOut, '   取消后**没有**迁出（只有 ack ok 才算数）');

  final a15 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final b15 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final off15 = _responderOnRequest(b15, a15.beginRequest().outbound!);
  await _deliver(off15.outbound, a15);
  await _deliver(a15.confirm().outbound, b15);
  final s15 =
      await b15.signRotation(sign: (m) => _signWith(oldSeed, m), nowMs: _now);
  await _deliver(s15.outbound, a15);
  final failAck = await a15.hubResult(
    ok: false,
    faultCode: 'not_current_key',
    sign: (m) => _signWith(newSeed, m),
  );
  check(failAck.ok && a15.phase == MigrationPhase.failed,
      '★ Hub 拒绝 → 新机 failed（**绝不落盘**）');
  check(a15.fault == 'not_current_key', '   失败码原样保留（供 UI 翻译）');
  final backFail = await _deliver(failAck.outbound, b15);
  check(backFail.ok && b15.phase == MigrationPhase.failed && !b15.migratedOut,
      '★ 老机收到 ack(ok:false) → failed 且**不**自锁（旧机没退休成功，还能用）');

  final a16 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  a16.abortLocal('user_cancel');
  check(a16.phase == MigrationPhase.failed && a16.fault == 'user_cancel',
      '★ 本机主动中止落地（不必等对端回话）');

  // ------------------------------------------------------------- ★★ ack 必须签名
  print('-- ★★ ack 必须由新钥签名（伪造 / 重放 / 篡改都要被拒） --');

  /// 把"两台设备走到老机已签出 ROTATE"这段前戏跑一遍，便于给 ack 那一环做反例。
  Future<(MigrationSession, MigrationSession)> prelude() async {
    final na = MigrationSession.startAsInitiator(
        agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
    final ob = MigrationSession.startAsResponder(
        agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
    final off = _responderOnRequest(ob, na.beginRequest().outbound!);
    await _deliver(off.outbound, na);
    await _deliver(na.confirm().outbound, ob);
    final s =
        await ob.signRotation(sign: (m) => _signWith(oldSeed, m), nowMs: _now);
    await _deliver(s.outbound, na);
    return (na, ob);
  }

  Future<MigrationStep> ackSignedBy(
    (MigrationSession, MigrationSession) p,
    MigrationAck ack,
    List<int> seed,
  ) async {
    final sig = await _signWith(seed, ack.canonicalBytes());
    final wire = MigrationWire.encode(
      kind: MigrationWireKind.ack,
      agentId: _agent,
      body: ack.copyWith(sig: sig).toMap(),
    );
    return _deliver(wire, p.$2);
  }

  MigrationAck ackFor(
    (MigrationSession, MigrationSession) p, {
    required bool ok,
    String fault = '',
  }) =>
      MigrationAck(
        agentId: _agent,
        oldPub: oldPub,
        newPub: newPub,
        ticketNonceB64: p.$2.ticket!.nonceB64,
        ok: ok,
        fault: fault,
      );

  final p1 = await prelude();

  // ① 完全没有签名
  final bareAck = await _deliver(
    MigrationWire.encode(
        kind: MigrationWireKind.ack, agentId: _agent, body: {'ok': true}),
    p1.$2,
  );
  check(!bareAck.ok && bareAck.fault == MigrationSessionFault.badSignature,
      '★★ 无签名的 ack(ok:true) → badSignature（**不许**凭一句话自锁）');
  check(!p1.$2.migratedOut && p1.$2.phase == MigrationPhase.signed,
      '   被拒后状态**没有推进**（后面一条合法 ack 仍能把流程走完）');

  // ② 签名者搞错了：用**旧钥**签（老机自己那把）
  final wrongSigner = await ackSignedBy(p1, ackFor(p1, ok: true), oldSeed);
  check(!wrongSigner.ok && wrongSigner.fault == MigrationSessionFault.badSignature,
      '★ 用旧钥签的 ack → badSignature（签名方必须是**接管那把新钥**）');

  // ③ 中间人自己造一把钥来签
  final evilSigned = await ackSignedBy(p1, ackFor(p1, ok: true), evilSeed);
  check(!evilSigned.ok && evilSigned.fault == MigrationSessionFault.badSignature,
      '★ 中间人用自己的钥签 ack → badSignature');

  // ④ ★ 把"失败"翻成"成功"（= 骗老机自锁）
  final honestFail = ackFor(p1, ok: false, fault: 'hub_rejected');
  final honestSig = await _signWith(newSeed, honestFail.canonicalBytes());
  final flipped = await _deliver(
    MigrationWire.encode(kind: MigrationWireKind.ack, agentId: _agent, body: {
      'ok': true, // ← 被改成"成功"
      'did': '',
      'fault': '',
      'sig': honestSig, // ← 签名还是"失败"那条的
    }),
    p1.$2,
  );
  check(!flipped.ok && flipped.fault == MigrationSessionFault.badSignature,
      '★★ 把 ok:false 篡改成 ok:true → badSignature（**这一条就是"骗老机自锁"**）');
  check(!p1.$2.migratedOut, '   老机**没有**自锁');

  // ⑤ 绑定了**别一轮**的 nonce（重放另一场会话的 ack）
  final p2 = await prelude();
  final crossSession = await ackSignedBy(
    p1,
    ackFor(p2, ok: true), // ← 签名有效，但 nonce 是 p2 那一轮的
    newSeed,
  );
  check(
      !crossSession.ok &&
          crossSession.fault == MigrationSessionFault.badSignature,
      '★★ 拿别一轮的 ack 重放 → badSignature（nonce 进了签名载荷）');

  // ⑥ ★ 正控：合法 ack 必须**真的**能通过 —— 否则"全部拒绝"也能让上面五条全绿
  final realAck = await p1.$1.hubResult(
    ok: true,
    did: 'did:wold:$oldPub',
    sign: (m) => _signWith(newSeed, m),
  );
  check(realAck.ok, '（正控）新机签得出合法 ack');
  final realBack = await _deliver(realAck.outbound, p1.$2);
  check(realBack.ok && p1.$2.phase == MigrationPhase.done && p1.$2.migratedOut,
      '★★（正控）合法 ack → 老机 done + 自锁（说明上面拒的是"假"，不是"全都拒"）');

  // ------------------------------------------------------------- ★★ 兜底窗口
  print('-- ★★ 兜底窗口：过期会话不许被推动，也不许签名 --');
  final tA = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final tB = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final tOff = _responderOnRequest(tB, tA.beginRequest().outbound!);
  await _deliver(tOff.outbound, tA);
  await _deliver(tA.confirm().outbound, tB);
  check(tB.canSign, '（前置）窗口内老机具备签名资格');
  check(tB.expireIfStale(_now + MigrationSession.ttlMs) == null,
      '   `ttlMs` 之内不过期（边界取闭区间）');

  final later = _now + MigrationSession.ttlMs + 1;
  check(tB.expireIfStale(later) == MigrationSessionFault.sessionTimeout,
      '★★ 超过 ttlMs → sessionTimeout');
  check(tB.phase == MigrationPhase.failed && !tB.canSign,
      '   过期后不再具备签名资格');
  check(tB.expireIfStale(later) == null, '   再判一次 → null（幂等，不重复改写）');

  var lateSignCalls = 0;
  final lateSign = await tB.signRotation(
    sign: (m) async {
      lateSignCalls++;
      return _signWith(oldSeed, m);
    },
    nowMs: later,
  );
  check(!lateSign.ok && lateSign.fault == MigrationSessionFault.sessionTimeout,
      '★★ 过期后 signRotation → sessionTimeout');
  check(lateSignCalls == 0, '★★ 且签名器**零调用**（过期路径同样不碰私钥）');

  // 迟到的报文不再推动会话
  final tC = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  tC.beginRequest();
  _now += MigrationSession.ttlMs + 1;
  final lateWire = await _deliver(staleWire, tC);
  check(!lateWire.ok && lateWire.fault == MigrationSessionFault.sessionTimeout,
      '★★ 迟到 5 分钟的报文 → sessionTimeout（超时守卫先于内容校验）');
  check(tC.phase == MigrationPhase.failed && tC.ticket == null,
      '   会话被判死，且没有受理那张票');
  _now -= MigrationSession.ttlMs + 1;

  // ------------------------------------------- ★★ 票据过期：**两侧**都要查
  // 票由**老机自己铸**（60s 窗口），新机在 `onOffer` 里验过一次。老机在**签名之前**
  // 必须再验一次：铸票后用户走开三分钟才按"交出身份"，这张票早该作废 ——
  // 而"会话还没过期（5min）"完全不能代替它（两件事、两个时钟起点）。
  print('-- ★★ 票据过期：老机签之前也必须查（不能只在新机侧查） --');
  final tA2 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final tB2 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final tOff2 = _responderOnRequest(tB2, tA2.beginRequest().outbound!);
  await _deliver(tOff2.outbound, tA2);
  await _deliver(tA2.confirm().outbound, tB2);
  check(tB2.canSign, '（前置）票未过期时老机具备签名资格');
  // 关键一刻：**票的窗口已过、会话的窗口还没过**。只查会话的实现会在这里放行。
  final afterTicket =
      _now + MigrationFormat.ttlMs + MigrationFormat.clockSkewToleranceMs + 1;
  check(afterTicket < _now + MigrationSession.ttlMs,
      '   取的时刻夹在「票过期」与「会话过期」之间（两个窗口确实不是一回事）');
  check(tB2.expireIfStale(afterTicket) == null,
      '   （对照）此刻会话**尚未**超时 —— 所以拦下它的只能是票据判据');
  var expiredSignCalls = 0;
  final expiredSign = await tB2.signRotation(
    sign: (m) async {
      expiredSignCalls++;
      return _signWith(oldSeed, m);
    },
    nowMs: afterTicket,
  );
  check(!expiredSign.ok && expiredSign.fault == MigrationFault.expiredTicket,
      '★★ 票过期（会话未过期）→ 老机**拒签**（expiredTicket）');
  check(expiredSignCalls == 0, '★★ 且签名器**零调用**（失败路径不碰私钥）');
  check(tB2.phase == MigrationPhase.failed && !tB2.canSign,
      '   会话就此判死 —— 不会在下一拍又被推起来签一次');
  // 正控：同一会话在**票还有效**时是签得出来的（否则上面那条是"恒拒"）。
  final tA3 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final tB3 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final tOff3 = _responderOnRequest(tB3, tA3.beginRequest().outbound!);
  await _deliver(tOff3.outbound, tA3);
  await _deliver(tA3.confirm().outbound, tB3);
  final okSign = await tB3.signRotation(
      sign: (m) => _signWith(oldSeed, m), nowMs: _now + 1000);
  check(okSign.ok && okSign.outbound != null,
      '★ 正控：票未过期（+1s）→ 照常签出 ROTATE');

  // 已完成的会话**不会**被超时改写（"办成了但挂太久"不该降级成失败）
  check(p1.$1.expireIfStale(later) == null &&
          p1.$1.phase == MigrationPhase.done,
      '★ done 是终点：超时不改写已完成的会话');

  // ------------------------------------------- ★★ apply_failed（两侧都没有别的路）
  print('-- ★★ Hub 已改绑、本机没装上：只能"重试落地" --');
  final q = await prelude();
  final badApply = await q.$1.hubResult(
    ok: false,
    faultCode: MigrationSessionFault.applyFailed,
    sign: (m) => _signWith(newSeed, m),
  );
  check(badApply.ok && q.$1.phase == MigrationPhase.failed,
      '★ 新机 failed（**不假装成功**）');
  check(q.$1.fault == MigrationSessionFault.applyFailed,
      '   失败码 = apply_failed（不能混进"Hub 拒绝"，两者处置完全不同）');
  check(q.$1.applyPending && q.$1.retryableApply,
      '★★ 置 applyPending ⇒ 允许"重试落地"');
  final notReadyAck =
      await q.$1.hubResult(ok: true, did: 'x', sign: (m) => _signWith(newSeed, m));
  check(!notReadyAck.ok && notReadyAck.fault == MigrationSessionFault.wrongPhase,
      '★ 已离开 awaitingHub 后不许再走 hubResult（避免绕过落盘次序）');

  final peerSawApplyFail = await _deliver(badApply.outbound, q.$2);
  check(
      peerSawApplyFail.ok &&
          q.$2.phase == MigrationPhase.failed &&
          !q.$2.migratedOut,
      '★★ 老机收到 apply_failed → failed 且**不自锁**（事情还没办成，它必须还能用）');

  final reAck = await q.$1.ackAfterApplyRetry(
      did: 'did:wold:$oldPub', sign: (m) => _signWith(newSeed, m));
  check(reAck.ok && q.$1.phase == MigrationPhase.done && !q.$1.applyPending,
      '★★ 重试落地成功 → done（从 failed 回到 done 是**刻意**开的窗口）');
  final peerSawRetry = await _deliver(reAck.outbound, q.$2);
  check(peerSawRetry.ok && q.$2.phase == MigrationPhase.done && q.$2.migratedOut,
      '★★ 老机收到**补发**的 ok:true → 这才自锁（否则新机落地了、老机还在用 ⇒ 分叉）');

  final zA = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final zR =
      await zA.ackAfterApplyRetry(sign: (m) => _signWith(newSeed, m));
  check(!zR.ok && zR.fault == MigrationSessionFault.wrongPhase,
      '★ 没卡过落地却来"补发 ok:true" → wrongPhase（这个窗口不开给别的场合）');

  // ------------------------------------------------------------- 常量与角色守卫
  print('-- 常量与角色守卫 --');
  check(
      MigrationWireKind.all.length == 6 &&
          MigrationWireKind.all.containsAll(
              ['request', 'offer', 'confirm', 'rotate', 'ack', 'cancel']),
      '六种报文种类齐全');

  final i1 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final r1 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  check(!i1.canSign && !r1.canSign, '初始时双方都不具备签名资格');
  check(!i1.readyToSubmitHub, '初始时新机不可提交 Hub');

  final i2 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final iSign = await i2.signRotation(
      sign: (m) => _signWith(oldSeed, m), nowMs: _now);
  check(!iSign.ok && iSign.fault == MigrationSessionFault.wrongPhase,
      '★ 新机侧调用签名 → 直接拒（角色不对就不该有这条路）');

  final r2 = MigrationSession.startAsResponder(
      agentId: _agent, peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final rOnOffer = r2.onOffer(
      MigrationWire.tryParse(MigrationWire.encode(
          kind: MigrationWireKind.offer,
          agentId: _agent,
          body: {'ticket': 'FENMIG1.x'}))!,
      nowMs: _now);
  check(!rOnOffer.ok && rOnOffer.fault == MigrationSessionFault.wrongPhase,
      '★ 老机侧收到 offer → 拒（方向反了）');

  final a17 = MigrationSession.startAsInitiator(
      agentId: _agent, peerId: _peerB, newPub: newPub, nowMs: _now);
  final foreignAgent = MigrationSession.startAsResponder(
      agentId: 'AG-OTHER99999', peerId: _peerA, oldPub: oldPub, nowMs: _now);
  final off17 = _responderOnRequest(foreignAgent, a17.beginRequest().outbound!);
  final rMis = await _deliver(off17.outbound, a17);
  check(!rMis.ok && rMis.fault == MigrationSessionFault.peerMismatch,
      '★ 报文身份与会话身份不一致 → peerMismatch（不误吞别的身份的消息）');

  // =========================================================================
  print('--- ★ 源码级：老机自锁之后必须**擦除本机身份**（P2⑤(b)）---');
  // =========================================================================
  // 服务层（`device_migration_service.dart`）依赖 SharedPreferences + sqflite，
  // 在独立 Dart VM 里跑不起来 —— 所以这一段改用**源文本**钉住"顺序与动作"。
  // 它盯的不是"能不能跑"，而是"自锁之后旧私钥还在不在本机"：
  //   自锁（`migration_migrated_out_at`）只是一个**标记**，私钥仍在钥匙串里 ——
  //   那就不算移交。手上有旧私钥 + Hub 上那个身份 = "同一身份两台活体"的物理条件
  //   依然成立，唯一还拦着它的是 Hub 侧那道 `not_current_key`（单点）。
  final svcSrc = _noComments(
      File('lib/core/device_migration_service.dart').readAsStringSync());
  check(svcSrc.contains('_wipeSeveredIdentity'), '擦除方法存在');
  final iLock = svcSrc.indexOf('await _lockOut(');
  final iWipe = svcSrc.indexOf('await _wipeSeveredIdentity(');
  check(iLock > 0 && iWipe > 0 && iLock < iWipe,
      '★ 顺序：**先自锁、后擦除**（反了会在身份还没交给新机时就把自己清空）');

  final wipeAt = svcSrc.indexOf('Future<void> _wipeSeveredIdentity(');
  check(wipeAt > 0, '找得到擦除方法体');
  if (wipeAt > 0) {
    final body =
        svcSrc.substring(wipeAt, (wipeAt + 3200).clamp(0, svcSrc.length));
    final iSeed = body.indexOf('installSeed(');
    final iNewId = body.indexOf('newAgentId()');
    final iDrop = body.indexOf('dropSeam(');
    final iDid = body.indexOf('clearRootDid()');
    check(iSeed > 0 && iDrop > 0 && iDid > 0,
        '① 换种子 ② 换身份 ID ③ 撕接缝行 ④ 清身份锚 —— 四件都在');
    check(iNewId > 0 && iSeed < iNewId,
        '★ 先换种子：它是唯一真正**解决**问题的一步（旧私钥当场消失）');
    check(!body.contains('_seedKey'),
        '★ **不删**种子（删了会撞上"无钥状态"，全机调用点一起崩）');
    check(body.contains('migration_severed_wipe_failed'),
        '★ 擦除失败**必须留痕**（静默失败 = 旧私钥还留着，却以为做完了）');
    check(!body.contains('migratedOutAtKey'),
        '★ 擦除**不得**抹掉"已迁出"标记（UI 与"第二次迁移"的闸都靠它）');
  }
  check(!svcSrc.contains('prefs.clear()'),
      '擦除不搞"清空整个 prefs"（那会连无关设置一起炸）');

  // 身份 ID 的生成点**唯一**：两处各写一份 ⇒ 迟早与形态校验漂移。
  final dbSrc = _noComments(File('lib/core/db_helper.dart').readAsStringSync());
  check((RegExp(r"'AG-' \+").allMatches(dbSrc).length) == 1 &&
          dbSrc.contains('static String newAgentId()'),
      '★ 身份 ID 只有**一个**生成点（DBHelper.newAgentId）');

  print('');
  print('================ 换机直迁会话层：$_pass PASS / $_fail FAIL ================');
  // ★ 这行是给 `tool/run_all_verify.dart` 汇总用的**机器可读**口径。
  //   少了它，本脚本会被汇总器静默跳过（读数里就少了一个脚本，看不出来）。
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) {
    throw StateError('$_fail 条断言失败');
  }
}
