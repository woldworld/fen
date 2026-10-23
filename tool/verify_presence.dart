// 纯 Dart 校验脚本：验证 M4 在场机制最小版（PRD §4 M4 P0 三条"不误判"验收）。
// 运行：dart run tool/verify_presence.dart
//
// P0 验收（二值）：
//   ① 分身自动发言 **不会**被标为"本人在线"；
//   ② 主人亲手打字 **会**被标记；
//   ③ 大段粘贴 **不**触发标记。
// 另验：一次性披露（首次自报身份，之后不重复）+ 签名在场信号（不可伪造、会过期）。

import 'dart:convert';

import 'package:dahuang_ai/core/circle_service.dart';
import 'package:dahuang_ai/core/presence_service.dart';

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

/// 虚拟设备：独立 signer + presence store + selfIntro store。
class Device {
  final String id;
  final Signer signer;
  final MemoryPresenceStore presenceStore = MemoryPresenceStore();
  final MemorySelfIntroStore introStore = MemorySelfIntroStore();
  final List<Map<String, Object?>> events = [];
  late final SelfIntroService intros;
  late final PresenceRelay relay;
  void Function(String target, String wire)? wire;
  bool online = true;

  Device(this.id, this.signer) {
    intros = SelfIntroService(
      store: introStore,
      onEvent: (n, p) => events.add({'name': n, ...p}),
    );
    relay = PresenceRelay(
      store: presenceStore,
      signer: signer,
      selfId: () async => id,
      send: (target, w) async {
        if (!online) return false;
        wire?.call(target, w);
        return true;
      },
      onEvent: (n, p) => events.add({'name': n, ...p}),
    );
  }

  bool hasEvent(String name) => events.any((e) => e['name'] == name);
}

Future<void> main() async {
  const aliceId = 'alice';
  const bobId = 'bob';

  final alice = Device(aliceId, await Ed25519Signer.generate());
  final bob = Device(bobId, await Ed25519Signer.generate());
  final onWire = <String>[];
  alice.wire = (t, w) => onWire.add(w); // alice → bob 只暂存，手动投递以免自身回环
  bob.wire = (t, w) => onWire.add(w);

  // ------------------------------------------------ ① 分身自动发言不标记
  print('--- 验收①：分身自动发言不标"本人在线" ---');
  final vAgent = PresenceJudge.judge(const ComposeEvidence.agent(totalChars: 30));
  check(!vAgent.humanPresent, '分身自动发言 → 不标记');
  check(vAgent.path == PresencePath.agent, '路径标为 agent');
  check(vAgent.reason == 'agent_generated', '依据 = agent_generated');
  // 分身写得很长也不标记（不看内容，只看路径）
  final vAgentLong =
      PresenceJudge.judge(const ComposeEvidence.agent(totalChars: 500));
  check(!vAgentLong.humanPresent, '分身长文 → 仍不标记');
  // 快捷芯片路径同样走 agent
  check(!PresenceJudge.judge(const ComposeEvidence.agent(totalChars: 12))
      .humanPresent, '快捷芯片（agent 路径）→ 不标记');

  // ------------------------------------------------ ② 主人亲手打字会标记
  print('--- 验收②：主人亲手打字 → 标记 ---');
  final vTyped = PresenceJudge.judge(
      const ComposeEvidence.typed(totalChars: 18, composeMs: 6400));
  check(vTyped.humanPresent, '亲手打字 → 标记本人在线');
  check(vTyped.path == PresencePath.typed, '路径标为 typed');
  check(vTyped.reason == 'typed', '依据 = typed');
  check(PresenceJudge.judge(const ComposeEvidence.typed(totalChars: 1)).humanPresent,
      '只敲 1 个字也算到场');

  // ------------------------------------------------ ③ 大段粘贴不触发
  print('--- 验收③：大段粘贴 → 不触发 ---');
  final vPaste = PresenceJudge.judge(const ComposeEvidence.pasted(totalChars: 240));
  check(!vPaste.humanPresent, '剪贴板粘贴 → 不标记');
  check(vPaste.path == PresencePath.pasted, '路径标为 pasted');
  check(vPaste.reason == 'clipboard', '依据 = clipboard');
  // 观测不到剪贴板事件时的兜底：单次插入过大
  final vBulk = PresenceJudge.judge(const ComposeEvidence(
    source: PresenceSource.composer,
    totalChars: 120,
    largestInsertionChars: 120,
  ));
  check(!vBulk.humanPresent, '单次插入 120 字（无剪贴板标记）→ 不标记');
  check(vBulk.reason == 'bulk_insert', '依据 = bulk_insert');
  // 边界：39 字逐次插入仍算亲手打字；40 字一次插入判为粘贴
  check(PresenceJudge.judge(const ComposeEvidence(
    source: PresenceSource.composer,
    totalChars: 39,
    largestInsertionChars: 39,
  )).humanPresent, '39 字单次插入 → 仍算亲手打字（阈值边界内）');
  check(!PresenceJudge.judge(const ComposeEvidence(
    source: PresenceSource.composer,
    totalChars: 40,
    largestInsertionChars: 40,
  )).humanPresent, '40 字单次插入 → 判为粘贴（阈值边界）');
  // fail-closed：空消息不标记
  check(!PresenceJudge.judge(const ComposeEvidence.typed(totalChars: 0)).humanPresent,
      '空消息 → 不标记（fail-closed）');

  // ------------------------------------------------ 一次性披露（首次自报）
  print('--- 铁律 1：首次自报身份（一次性披露）---');
  check(await alice.intros.needsSelfIntro(bobId), '第一次接触 → 需要自报身份');
  check(await alice.intros.markIntroduced(bobId), '首次记账返回 true');
  check(alice.hasEvent('self_intro_sent'), '产出 self_intro_sent 埋点');
  check(!await alice.intros.needsSelfIntro(bobId), '第二次接触 → 不再自报');
  check(!await alice.intros.markIntroduced(bobId), '重复记账返回 false');
  check(alice.events.where((e) => e['name'] == 'self_intro_sent').length == 1,
      'self_intro_sent 只产一次（不重复披露）');
  check(await alice.intros.needsSelfIntro('carol'), '换新对象 → 仍要自报');
  check(!await alice.intros.needsSelfIntro(bobId, noIntro: true),
      '对方声明"只接受真人" → 不自报（铁律 3 优先）');
  check(!await alice.intros.needsSelfIntro(''), '空 ID → 不自报');
  check(await alice.intros.introducedCount() == 1, '账本计数正确（1 个对象）');

  // ------------------------------------------------ 签名在场信号
  print('--- 在场信号：发出 → 对方收到 ---');
  check(await alice.relay.dispatch(toId: bobId, path: 'typed'), '在场信号投递成功');
  check(onWire.length == 1, '线上出现一条在场报文');
  check(await bob.relay.onIncoming(aliceId, onWire.last), 'Bob 认领在场报文');
  check(bob.hasEvent('presence_received'), '产出 presence_received 埋点');
  check(await bob.relay.peerIsPresent(aliceId), 'Bob 侧显示 Alice「本人在线」');
  check(!await bob.relay.peerIsPresent('carol'), '从未收到信号的 peer → 不在线');

  print('--- 在场所不可伪造 ---');
  final tampered = PresenceWire.encode(PresenceSignal(
    fromId: aliceId,
    toId: bobId,
    path: 'typed',
    atMs: DateTime.now().millisecondsSinceEpoch,
    expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
    sig: 'ZmFrZQ==', // 伪造签名
    fromPub: (await alice.signer.publicKeyBase58()),
  ));
  check(await bob.relay.onIncoming(aliceId, tampered), '伪造签名报文仍被认领（不漏进聊天流水线）');
  check(bob.hasEvent('presence_dropped'), '伪造 → 丢弃并留痕');
  check(
      bob.events.any((e) => e['name'] == 'presence_dropped' && e['reason'] == 'bad_signature'),
      '丢弃原因 = bad_signature');

  final impersonated = PresenceWire.encode(PresenceSignal(
    fromId: 'carol',
    toId: bobId,
    path: 'typed',
    atMs: DateTime.now().millisecondsSinceEpoch,
    expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
    sig: 'ZmFrZQ==',
    fromPub: await bob.signer.publicKeyBase58(),
  ));
  await bob.relay.onIncoming(aliceId, impersonated); // 声称来自 carol，实际 carol 发给 bob 但 from 与发送者不符
  check(
      bob.events.any((e) => e['name'] == 'presence_dropped' && e['reason'] == 'sender_mismatch'),
      '冒名（from ≠ 发送者）→ sender_mismatch');

  print('--- 在场信号会过期（假信号比没信号更糟）---');
  final now = DateTime.now().millisecondsSinceEpoch;
  final stale = PresenceSignal(
    fromId: aliceId,
    toId: bobId,
    path: 'typed',
    atMs: now - PresenceSignal.validWindow.inMilliseconds - 1000,
    expiresAtMs: now - 1000,
  );
  check(!stale.isFreshAt(now), '超窗口 → isFreshAt=false');
  // 过期信号即使验签通过也不落库
  final fresh = PresenceSignal(
    fromId: aliceId,
    toId: bobId,
    path: 'typed',
    atMs: now - PresenceSignal.validWindow.inMilliseconds - 1000,
    expiresAtMs: now - 1000,
  );
  final sig = await alice.signer.signBytes(
      utf8Encode(fresh.canonical()));
  final signed = PresenceSignal(
    fromId: fresh.fromId,
    toId: fresh.toId,
    path: fresh.path,
    atMs: fresh.atMs,
    expiresAtMs: fresh.expiresAtMs,
    sig: sig,
    fromPub: await alice.signer.publicKeyBase58(),
  );
  await bob.relay.onIncoming(aliceId, PresenceWire.encode(signed));
  check(
      bob.events
          .where((e) => e['name'] == 'presence_dropped')
          .any((e) => e['reason'] == 'expired'),
      '过期信号 → 丢弃（不落库，不显示假"在线"）');

  print('--- 通道不通 ---');
  alice.online = false;
  check(!await alice.relay.dispatch(toId: bobId, path: 'typed'), '无通道 → dispatch false');
  check(alice.hasEvent('presence_dropped'), '无通道 → 留痕 presence_dropped');
  alice.online = true;

  print('--- 非在场报文不认领 ---');
  check(!await bob.relay.onIncoming(aliceId, '今天天气不错'), '普通聊天不认领');
  check(!await bob.relay.onIncoming(aliceId, '{"da_type":"deleg","v":1,"d":{}}'),
      '委托报文不认领（交给委托 relay）');
  check(!await bob.relay.onIncoming(aliceId, '{"da_type":"presence","v":2,"d":{}}'),
      '版本不符不认领');

  print('--- 输入采集器（逐键 vs 整段粘贴）---');
  final t1 = ComposeTracker();
  for (final s in ['你', '你好', '你好世', '你好世界']) {
    t1.onChanged(s);
  }
  final e1 = t1.evidence(totalChars: 4);
  check(e1.largestInsertionChars == 1, '逐键输入 → 单次插入 1 字');
  check(PresenceJudge.judge(e1).humanPresent, '逐键输入 → 判定为亲手打字');
  t1.reset();
  check(t1.evidence(totalChars: 0).largestInsertionChars == 0, 'reset 后清零');

  final t2 = ComposeTracker();
  final longText = '这是一段一百二十个字的长文本' * 10; // 一次粘贴进来
  t2.onChanged(longText);
  final e2 = t2.evidence(totalChars: longText.length);
  check(e2.largestInsertionChars == longText.length, '整段粘贴 → 单次插入 = 全文长度');
  check(!PresenceJudge.judge(e2).humanPresent, '整段粘贴 → 不标记（验收③）');
  // 先手打一句，再粘一段：仍然不算（最脏的那次插入说了算）
  final t3 = ComposeTracker();
  t3.onChanged('好的');
  t3.onChanged('好的这是一大段黏贴内容' * 8);
  check(!PresenceJudge.judge(t3.evidence(totalChars: 88)).humanPresent,
      '手打 + 粘贴混合 → 仍不标记（按最大单次插入判）');

  print('--- 在场集合（UI 名册一次取完）---');
  check((await bob.relay.freshPeers()).contains(aliceId), '未过期 peer 出现在在场集合里');
  check(!(await bob.relay.freshPeers()).contains('carol'), '无信号 peer 不在集合里');

  // =====================================================================
  print('--- 铁律 1：首次披露文案（PRD §4 铁律 1）---');
  // 为什么单列一组：这段文案是产品里**唯一直接发给陌生人的法律/伦理声明**
  // （"对面是 AI，不是本人"），却一直没有离线断言盯着它。
  // 2026-09-27 修掉的那个缺陷（主人称呼读了一个全项目无人写入的键 → 永远为空）
  // 正是"文案静默退化"的典型：四证全绿，用户实际收到的是"我主人"。
  // 所以这里对**两条路径**都断言：给得出名字必须用真名；给不出才允许退化。

  final withOwner =
      SelfIntroService.declaration(agentName: '小荒', ownerName: '张三', lang: 'zh');
  check(withOwner.contains('小荒'), '中文：出现分身名');
  check(withOwner.contains('张三'), '中文：**真的用上了主人称呼**（不是退化文案）');
  check(!withOwner.contains('我主人'), '中文：给了名字就不该再出现"我主人"');
  check(withOwner.contains('分身'), '中文：必须自报"分身"（铁律 1 的实质）');

  final noOwner =
      SelfIntroService.declaration(agentName: '小荒', ownerName: '', lang: 'zh');
  check(noOwner.contains('我主人'), '中文：没给名字 → 退化用"我主人"，**不编造名字**');
  check(noOwner.contains('分身'), '中文：退化文案仍须自报"分身"');

  final blankAgent =
      SelfIntroService.declaration(agentName: '', ownerName: '张三', lang: 'zh');
  check(blankAgent.contains('分身'), '中文：分身名为空 → 兜底为"分身"');

  final enWithOwner =
      SelfIntroService.declaration(agentName: 'Wold', ownerName: 'Alice', lang: 'en');
  check(enWithOwner.contains('Alice'), '英文：用上主人称呼');
  check(enWithOwner.contains('assistant agent'), '英文：声明是个 assistant agent');
  check(!enWithOwner.contains('my owner'), '英文：给了名字就不该用"my owner"');
  check(!enWithOwner.contains('我主人'), '英文：不得混入中文退化文案');

  final enNoOwner =
      SelfIntroService.declaration(agentName: 'Wold', ownerName: '', lang: 'en');
  check(enNoOwner.contains('my owner'), '英文：没给名字 → "my owner"');

  // ⚠️ 英文披露**整串不得含任何 CJK**。
  // 2026-09-27 修掉的缺陷：兜底名 `agentName.isEmpty ? '分身' : ...` 算在 lang 分支**之前**，
  // 于是 `lang:'en'` 且没昵称时，英文披露掺进中文「分身」——
  // 对只懂英文的收件人这一句等于**没披露**（铁律 1 的三道护栏同时失效）。
  final enBlankAgent =
      SelfIntroService.declaration(agentName: '', ownerName: 'Alice', lang: 'en');
  check(!RegExp(r'[\u4e00-\u9fff]').hasMatch(enBlankAgent),
      '英文：分身名为空 → 兜底名也不得是中文（曾漏成「分身」）');
  check(enBlankAgent.contains('digital agent'), '英文：分身名为空 → 有英文兜底名');

  final enAll = [enWithOwner, enNoOwner, enBlankAgent].join('\n');
  check(!RegExp(r'[\u4e00-\u9fff]').hasMatch(enAll),
      '英文披露整串不含 CJK（名字本身是数据、这里都是 ASCII 名）');

  // 披露文案是发给陌生人的，不得夹带隐私字段
  final allDecl =
      [withOwner, noOwner, blankAgent, enWithOwner, enNoOwner, enBlankAgent].join('\n');
  check(!allDecl.contains('AG-'), '披露文案不含 agentId');
  check(!allDecl.contains('did:wold:'), '披露文案不含 did');

  print('\nPASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('存在失败项：$_fail');
}

List<int> utf8Encode(String s) => const Utf8Encoder().convert(s);
