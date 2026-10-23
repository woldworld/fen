// 会客厅「节奏闸」退避策略校验（`lib/core/world_retry_policy.dart`）。
//
// 为什么值得单独一个脚本：这段判据决定"两个智能体互答时会不会突然哑掉"，
// 而它的输入空间（429 响应体）全是**畸形与边界** —— 服务端将来多一个限流码、
// 或 body 少一个字段，都可能让退避静默失效（那正是它当初的样子：字段从没被消费）。
// 所以按本仓纪律把**边界两侧 + 各种畸形 + fail-closed + 接线**都钉住。
//
// 纯 Dart、零平台依赖 ⇒ 可直接 `dart run`。
import 'dart:io';

import 'package:dahuang_ai/core/world_retry_policy.dart';

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

int backoff(String body) => WorldRetryPolicy.backoffMsFrom429(body);

void main() {
  // ---------- ① 正常路径：服务端给多少就等多少 ----------
  check(backoff('{"error":"room_too_fast","retry_after_ms":725}') == 725,
      '正常：725ms 原样返回（用户实测的那一条）');
  check(backoff('{"error":"room_too_fast","retry_after_ms":8000}') == 8000,
      '正常：整道闸（8000ms）原样返回');

  // ---------- ② 上限：恰好 / 上限-1 / 上限+1 三侧都要断 ----------
  check(WorldRetryPolicy.maxBackoffMs == 10000, '常量钉住：上限 10000ms');
  check(backoff('{"error":"room_too_fast","retry_after_ms":9999}') == 9999,
      '上限-1（9999）不被夹');
  check(backoff('{"error":"room_too_fast","retry_after_ms":10000}') == 10000,
      '恰好等于上限（10000）不封顶');
  check(backoff('{"error":"room_too_fast","retry_after_ms":10001}') == 10000,
      '上限+1 才夹紧到 10000');
  check(backoff('{"error":"room_too_fast","retry_after_ms":999999}') == 10000,
      '离谱大值被夹紧（防服务端误配置把 App 挂住）');

  // ---------- ③ 下界：>0 才重试 ----------
  check(backoff('{"error":"room_too_fast","retry_after_ms":1}') == 1,
      '下界：1ms 仍算"可重试"');
  check(backoff('{"error":"room_too_fast","retry_after_ms":0}') == 0,
      '0 ⇒ 不重试（不把"等 0 毫秒"当承诺）');
  check(backoff('{"error":"room_too_fast","retry_after_ms":-5}') == 0,
      '负数 ⇒ 不重试');

  // ---------- ④ 只认 room_too_fast：别的限流码等再久也没用 ----------
  check(backoff('{"error":"member_cap"}') == 0,
      'member_cap 无字段 ⇒ 不重试');
  check(backoff('{"error":"member_cap","retry_after_ms":5000}') == 0,
      'member_cap 即便**带了** retry_after_ms 也不重试（只认房间节奏闸）');
  check(backoff('{"error":"room_full","retry_after_ms":5000}') == 0,
      'room_full（容量）不重试');
  check(backoff('{"error":"not_your_turn","retry_after_ms":5000}') == 0,
      'not_your_turn（回合制）不重试');
  check(backoff('{"error":"ROOM_TOO_FAST","retry_after_ms":500}') == 0,
      '大小写严格：服务端发的是小写，未知变体一律不重试');

  // ---------- ⑤ 畸形输入穷尽形态：一律 fail-safe 返回 0 ----------
  check(backoff('') == 0, '空 body ⇒ 0');
  check(backoff('   ') == 0, '纯空白 body ⇒ 0');
  check(backoff('not json at all') == 0, '非 JSON ⇒ 0');
  check(backoff('{"error":') == 0, '截断的 JSON ⇒ 0');
  check(backoff('[1,2,3]') == 0, 'JSON 数组（非 Map）⇒ 0');
  check(backoff('"room_too_fast"') == 0, 'JSON 字符串（非 Map）⇒ 0');
  check(backoff('null') == 0, 'null ⇒ 0');
  check(backoff('{"error":"room_too_fast"}') == 0, '缺 retry_after_ms ⇒ 0');
  check(backoff('{"error":"room_too_fast","retry_after_ms":null}') == 0,
      'retry_after_ms 为 null ⇒ 0');
  check(backoff('{"error":"room_too_fast","retry_after_ms":"abc"}') == 0,
      'retry_after_ms 非数字字符串 ⇒ 0');
  check(backoff('{"error":"room_too_fast","retry_after_ms":{}}') == 0,
      'retry_after_ms 是对象 ⇒ 0');

  // ---------- ⑥ 宽松但明确的两种可接受形态 ----------
  check(backoff('{"error":"room_too_fast","retry_after_ms":"300"}') == 300,
      '数字以字符串形式给出（JSON 序列化差异）仍认');
  check(backoff('{"retry_after_ms":400,"error":"room_too_fast"}') == 400,
      '键序无关（与 canonical 无关，纯读字段）');

  // ---------- ⑦ 接线：策略必须真的被 world_service 消费（防"写了没人读"）----------
  final ws = File('lib/core/world_service.dart');
  check(ws.existsSync(), 'world_service.dart 找得到');
  final src = stripComments(ws.readAsStringSync());
  check(src.contains('WorldRetryPolicy.backoffMsFrom429'), '接线：确实调用退避策略');
  check(src.contains('HttpStatus.tooManyRequests'),
      '接线：只在 429 上算退避（不是所有失败都当可重试）');
  check(src.contains('Future.delayed(Duration(milliseconds: first))'),
      '接线：真的按返回毫秒睡了再重试');
  check(RegExp(r'_postEnvelopeOnce').allMatches(src).length >= 3,
      '接线：单次投递被复用（定义 1 次 + 调用 2 次 = 至少 3 处）');

  // ---------- ⑧ 自检（positive control）：扫描器本身有效 ----------
  check(!stripComments('// x\nfinal a = 1;').contains('x'),
      '自检：剥行注释有效');
  check(!stripComments('/* WorldRetryPolicy */ final a = 1;')
          .contains('WorldRetryPolicy'),
      '自检：剥块注释有效（否则注释里的名字会被当成接线证据）');
  check(
      backoff('{"error":"room_too_fast","retry_after_ms":725}') !=
          backoff('{"error":"member_cap"}'),
      '自检：分类器不是恒等函数（正例与反例确实被分开）');

  // ---------- ⑨ 跨端契约：服务端必须真的发这两个字段，且上限不能比它更紧 ----------
  //   这一段拦的是**最阴的一类失效**：客户端升级了、服务端把字段改了名，
  //   解析静默返回 0 ⇒ 退避"永远不触发"，而所有单侧测试照样全绿。
  final worldJs = File('lib/hub/world.js');
  check(worldJs.existsSync(), 'world.js 找得到（跨端契约的另一半）');
  final js = stripComments(worldJs.readAsStringSync());
  check(js.contains('room_too_fast'), '契约：服务端确实会发 room_too_fast');
  check(js.contains('retry_after_ms'), '契约：服务端确实会发 retry_after_ms');
  check(
      RegExp(r'room_too_fast[\s\S]{0,200}retry_after_ms').hasMatch(js),
      '契约：两者出现在同一个 429 响应体里（字段名一旦改名，本断言即红）');

  final m = RegExp(r'WORLD_ROOM_MIN_INTERVAL_MS\s*\|\|\s*(\d+)').firstMatch(js);
  check(m != null, '契约：找得到服务端默认间隔（ROOM_MIN_INTERVAL_MS）');
  final serverDefault = int.tryParse(m?.group(1) ?? '') ?? 0;
  check(serverDefault == 8000, '契约：服务端默认间隔 = 8000ms（实测值）');
  check(WorldRetryPolicy.maxBackoffMs >= serverDefault,
      '契约：客户端退避上限(${WorldRetryPolicy.maxBackoffMs}) ≥ 服务端默认间隔($serverDefault)'
      ' —— 夹得比它还紧就等于"退避了但永远太早"');

  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
