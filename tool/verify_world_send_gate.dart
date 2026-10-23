// 会客厅「发言排队闸」校验（`lib/core/world_send_gate.dart`）。
//
// 为什么值得单独一个脚本：这段逻辑决定"同一房间连着两条发言会不会白撞一次 429"，
// 而它有三个各自都能静默失效的点 ——
//   ① 冷却窗口算错（差 1ms 就白等 / 早发就白撞）；
//   ② 串行化是"看起来排了队、实际并着跑"（Future 链写错时最容易这样）；
//   ③ 接线断掉（闸写了没人用 —— 本仓已有前例：`retry_after_ms` 曾被造出来却从没被消费）。
// 所以按本仓纪律把**纯计算边界 + 注入时钟/睡眠的行为 + 串行化实证 + 接线 + 跨端契约**都钉住。
//
// ★ 关键手法：`WorldSendGate` 的时钟与"睡眠"都可注入 ⇒ 全部断言**离线、零等待、确定性**，
//   不靠 `sleep()` 碰运气（那把测试变成"慢且偶发"）。
//
// 纯 Dart、零平台依赖 ⇒ 可直接 `dart run`。
import 'dart:async';
import 'dart:io';

import 'package:dahuang_ai/core/world_send_gate.dart';

int _pass = 0;
int _fail = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    print('  FAIL: $label');
  }
}

/// 剥掉注释：本仓源码习惯把旧缺陷写进注释当反面教材，
/// 不剥的话"扫源码"型断言会被自己的说明文字污染。
String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// 并发深度探针：进闸后同房间的执行必须**永不重叠** ⇒ 峰值深度恒为 1。
class Depth {
  int now = 0;
  int max = 0;
  void enter() {
    now++;
    if (now > max) max = now;
  }

  void leave() => now--;
}

Future<void> _body(Depth d) async {
  d.enter();
  await Future<void>.delayed(Duration.zero);
  d.leave();
}

Future<void> main() async {
  var now = 1000000;

  // ---------- ① waitMsFor：纯计算，边界四侧 ----------
  final g1 = WorldSendGate(clock: () => now, sleep: (_) async {});
  check(g1.waitMsFor('r1', now) == 0, '未知房间 ⇒ 0（不凭空等）');
  check(g1.nextAllowedAtMs('r1') == 0, '未知房间的冷却截止 = 0');

  g1.noteSent('r1');
  check(WorldSendGate.defaultMinIntervalMs == 8000, '常量钉住：默认间隔 8000ms');
  check(g1.nextAllowedAtMs('r1') == now + 8000, '成功发送 ⇒ 排到 now+8000');
  check(g1.waitMsFor('r1', now) == 8000, '刚发完：还需等 8000');
  check(g1.waitMsFor('r1', now + 3000) == 5000, '过了 3s：剩余 5000');
  check(g1.waitMsFor('r1', now + 7999) == 1, '到点前 1ms：剩余 1（不是 0）');
  check(g1.waitMsFor('r1', now + 8000) == 0, '恰好到点：0');
  check(g1.waitMsFor('r1', now + 99999) == 0, '过点很久：0（不会算出负数）');
  check(g1.waitMsFor('r2', now) == 0, '★ 闸是按房间的：隔壁房间不受影响');

  // ---------- ② noteRoomTooFast：服务端给的毫秒是权威值 ----------
  final g2 = WorldSendGate(clock: () => now, sleep: (_) async {});
  g2.noteRoomTooFast('r', 0);
  check(g2.nextAllowedAtMs('r') == 0, '0ms ⇒ 不排冷却（不把"等 0 毫秒"当承诺）');
  g2.noteRoomTooFast('r', -5);
  check(g2.nextAllowedAtMs('r') == 0, '负数 ⇒ 不排冷却');
  g2.noteRoomTooFast('r', 725);
  check(g2.nextAllowedAtMs('r') == now + 725, '725ms 原样排（用户实测的那一条）');
  check(WorldSendGate.maxWaitMs == 10000, '常量钉住：单次等待上界 10000ms');
  g2.noteRoomTooFast('r', 10000);
  check(g2.nextAllowedAtMs('r') == now + 10000, '恰好等于上界 ⇒ 不夹');
  g2.noteRoomTooFast('r', 10001);
  check(g2.nextAllowedAtMs('r') == now + 10000, '上界+1 ⇒ 夹到 10000');
  g2.noteRoomTooFast('r', 999999);
  check(g2.nextAllowedAtMs('r') == now + 10000, '离谱大值 ⇒ 夹到 10000（防误配置把队列压死）');

  // ---------- ③ waitTurn：真的让"睡"了该睡的毫秒（注入记录器，零真实等待） ----------
  final slept = <int>[];
  final g3 = WorldSendGate(clock: () => now, sleep: (ms) async => slept.add(ms));
  check(await g3.waitTurn('x') == 0, '无冷却 ⇒ 返回 0');
  check(slept.isEmpty, '无冷却 ⇒ sleep 一次都没被调用（不是空转一圈）');
  g3.noteSent('x');
  check(await g3.waitTurn('x') == 8000, '冷却内 ⇒ 返回实际等待 8000');
  check(slept.length == 1 && slept.single == 8000, '确实睡了 8000（不是"算了但没等"）');
  slept.clear();
  g3.noteRoomTooFast('y', 20000);
  check(await g3.waitTurn('y') == 10000,
      '冷却超过上界 ⇒ 只等 maxWaitMs（超出的部分交给 429 兜底，不把界面挂住）');
  check(slept.single == 10000, '上界确实生效');

  // ---------- ④ 串行化：同一房间先后两条，前者完整跑完前者才轮到后者 ----------
  final g4 = WorldSendGate(clock: () => now, sleep: (_) async {});
  final order = <String>[];
  final aStarted = Completer<void>();
  final releaseA = Completer<void>();
  final fA = g4.run('room', () async {
    order.add('A-start');
    aStarted.complete();
    await releaseA.future;
    order.add('A-end');
    return 1;
  });
  await aStarted.future;
  var bStarted = false;
  final fB = g4.run('room', () async {
    bStarted = true;
    order.add('B-start');
    order.add('B-end');
    return 2;
  });
  // 让事件循环转两圈：B 若没有真的排队，这里早就开始了。
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  check(!bStarted, '★ 同房间：前一条未结束前，后一条的 action 不得开始（串行真生效）');
  releaseA.complete();
  check(await fA == 1, '前一条正常返回');
  check(await fB == 2, '后一条正常返回（未被前者卡死）');
  check(order.join(',') == 'A-start,A-end,B-start,B-end', '顺序：A 完整跑完才轮到 B');

  // ---------- ⑤ 队列不串房间：不同房间可并发（否则会被一个慢房间拖全站） ----------
  final g5 = WorldSendGate(clock: () => now, sleep: (_) async {});
  final xStarted = Completer<void>();
  final releaseX = Completer<void>();
  final fx = g5.run('x', () async {
    xStarted.complete();
    await releaseX.future;
    return 'x';
  });
  await xStarted.future;
  var yRan = false;
  final fy = g5.run('y', () async {
    yRan = true;
    return 'y';
  });
  check(await fy == 'y', '不同房间：不等 x（各自独立）');
  check(yRan, '不同房间确实跑起来了');
  releaseX.complete();
  check(await fx == 'x', 'x 随后正常返回');

  // ---------- ⑥ 失败不卡队列：action 抛异常后，后续仍能进 ----------
  final g6 = WorldSendGate(clock: () => now, sleep: (_) async {});
  var threw = false;
  try {
    await g6.run('z', () async => throw StateError('boom'));
  } catch (_) {
    threw = true;
  }
  check(threw, 'action 抛出的异常向上传播（不吞）');
  check(await g6.run('z', () async => 7) == 7,
      '★ 抛异常后队列不卡死（finally 释放，下一次 run 仍能跑）');

  // ---------- ⑦ 正控（positive control）：探测手段本身有效 ----------
  //   先证明"不用闸时确实重叠"，再证明"用闸后不重叠"——否则 ④⑥ 可能是恒绿的空断言。
  final rawDepth = Depth();
  await Future.wait([_body(rawDepth), _body(rawDepth)]);
  check(rawDepth.max == 2,
      '正控：不排队直跑两次 ⇒ 峰值并发 2（证明"无重叠"不是恒真）');

  final gatedDepth = Depth();
  final g7 = WorldSendGate(clock: () => now, sleep: (_) async {});
  await Future.wait([
    g7.run('same', () => _body(gatedDepth)),
    g7.run('same', () => _body(gatedDepth)),
  ]);
  check(gatedDepth.max == 1, '正控对照：进闸后 ⇒ 峰值并发 1（串行真的把重叠消掉了）');

  check(
      WorldSendGate(clock: () => now, sleep: (_) async {})
              .waitMsFor('r1', now + 8000) ==
          0,
      '正控：闸不是"恒返回正数"的函数（到点确实归零）');

  // ---------- ⑧ 接线：world_service 必须真的用它（防"闸写了没人挂"） ----------
  final ws = File('lib/core/world_service.dart');
  check(ws.existsSync(), 'world_service.dart 找得到');
  final src = stripComments(ws.readAsStringSync());
  check(src.contains('WorldSendGate()'), '接线：确实实例化了排队闸');
  check(RegExp(r'_sendGate\.run\(').hasMatch(src), '接线：发言走按房间串行入口');
  check(RegExp(r"_sendGate\.run\(\s*roomId").hasMatch(src) ||
          RegExp(r'_sendGate\.run\(\s*\n\s*roomId').hasMatch(src),
      '接线：串行的房间 key 就是本次发言的 roomId');
  check(src.contains('_sendGate.noteSent('), '接线：成功发送后记冷却');
  check(src.contains('_sendGate.noteRoomTooFast('), '接线：撞 429 后按服务端毫秒记冷却');
  check(src.contains('/api/world/say'), '接线：发言端点仍在');
  check(RegExp(r"/api/world/say").allMatches(src).length == 1,
      '接线：say 只有一条投递路径（不许绕过闸另开一条）');
  check(
      RegExp(r'Future\.delayed\(Duration\(milliseconds: first\)\)').hasMatch(src),
      '兜底仍在：撞闸仍按服务端毫秒退避重试一次');
  check(RegExp(r'_postEnvelopeOnce').allMatches(src).length >= 3,
      '接线：单次投递被复用（定义 1 次 + 调用 2 次 = 至少 3 处）');

  // ---------- ⑨ 跨端契约：本地预测的间隔必须与服务端默认一致 ----------
  //   拦的是最阴的一类失效：客户端按 8s 预测、服务端却是别的值 ⇒
  //   "事前排队"永远排错点（排早了白撞、排晚了白等），而所有单侧测试照样全绿。
  final worldJs = File('lib/hub/world.js');
  check(worldJs.existsSync(), 'world.js 找得到（跨端契约的另一半）');
  final js = stripComments(worldJs.readAsStringSync());
  final m = RegExp(r'WORLD_ROOM_MIN_INTERVAL_MS\s*\|\|\s*(\d+)').firstMatch(js);
  check(m != null, '契约：找得到服务端默认间隔（ROOM_MIN_INTERVAL_MS）');
  final serverDefault = int.tryParse(m?.group(1) ?? '') ?? 0;
  check(serverDefault == WorldSendGate.defaultMinIntervalMs,
      '契约：客户端预测间隔(${WorldSendGate.defaultMinIntervalMs}) == 服务端默认($serverDefault)'
      ' —— 不一致则"事前排队"排不到正确的点');
  check(WorldSendGate.maxWaitMs >= serverDefault,
      '契约：等待上界(${WorldSendGate.maxWaitMs}) ≥ 服务端默认间隔($serverDefault)');
  check(RegExp(r'room_too_fast[\s\S]{0,220}retry_after_ms').hasMatch(js),
      '契约：服务端确把 room_too_fast 与 retry_after_ms 放在同一响应体（改名字本断言即红）');

  // ---------- ⑩ 自检 ----------
  check(!stripComments('// x\nfinal a = 1;').contains('x'), '自检：剥行注释有效');
  check(!stripComments('/* WorldSendGate */ final a = 1;').contains('WorldSendGate'),
      '自检：剥块注释有效（否则注释里的类名会被当成接线证据）');

  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
