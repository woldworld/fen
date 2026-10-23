// 纯 Dart 校验脚本：换机直迁「要约票据」的**格式契约与 fail-closed** 行为。
// 运行：dart run tool/verify_device_migration.dart
//
// 为什么值得单独一个脚本（与 verify_local_archive.dart 同型）：
//   直迁这条链路里最容易悄悄坏掉的是**格式契约**，而它的失败很安静 ——
//   * 前缀一旦与恢复码 `FENBK1` 或归档 `FENARC1` 撞上，"拿恢复码当迁移票"
//     会在格式校验那层通过，错误要等到很后面才暴露；
//   * 一旦允许"尽力解析"，就会出现"拿 A 的票据去连 B"这类静默错配；
//   * **比对码一旦悄悄改变**（换哈希 / 换字母表 / 换拌入字段），
//     两台不同版本的设备会各自算出不同的码 ⇒ 用户看到"对不上"而不知所措，
//     但两端代码各自跑都是绿的。所以这里钉一条**固定向量**。
//   * ★★ 反过来更危险：**拌入字段少了一项**（v0.29.0 之前漏了 `new_pub`），
//     短码看起来一切正常、两屏也能对上，**却是被掉包过的绑定** ——
//     所以本向量钉住的不只是"算得对"，还有"**拌了哪几样**"。
//
// 本脚本只 import **零平台依赖**的模块，故可在独立 Dart VM 里离线复算。

import 'dart:convert';

import 'package:dahuang_ai/core/agent_protocol.dart';
import 'package:dahuang_ai/core/device_migration.dart';
import 'package:dahuang_ai/core/ed25519_sig.dart';
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

/// 一枚形态合法（32 字节）的 Ed25519 公钥。
///
/// `Ed25519Sig.isPubkey` 只校验长度，不校验它是不是曲线上的点 ——
/// 所以这里用确定性字节即可，**不需要**每次生成真密钥对（那会让校验结果不可复算）。
final String _pub32 = AgentProtocol.base58Encode(
  List<int>.generate(32, (i) => i + 1),
);

/// `_pub32` 的 31 字节版本（用来造"长度不对"的反例）。
final String _pub31 = AgentProtocol.base58Encode(
  List<int>.generate(31, (i) => i + 1),
);

/// 另**一把**形态合法的公钥 —— 代表"迁移要迁往的那把新钥"。
///
/// 同样用确定性字节而不是真密钥对：校验结果必须可复算。
final String _newPub32 = AgentProtocol.base58Encode(
  List<int>.generate(32, (i) => i + 33),
);

const String _aid = 'AG-TEST000000';
const int _now = 1700000000000; // 固定时钟 ⇒ 结果可复算

/// ★ 固定向量：agentId = `AG-TEST000000`、old_pub = 字节 0x01..0x20、
/// new_pub = 字节 0x21..0x40、nonce = 字节 0x01..0x10。
///
/// 期望短码由 sha256(`AG-TEST000000|<old_pub>|<new_pub>|<nonce_b64>`) 的**前 30 位**
/// 按 Crockford base32 展开得到。**这两台设备各自算，必须一模一样。**
///
/// ⚠️ 拌入字段的**清单**本身就是契约的一部分：v0.29.0 之前只拌 `agent_id|nonce`，
/// 于是"掉包 new_pub"能一路骗过两屏比对（详见 `device_migration.dart` 里
/// `deriveCompareCode` 的"为什么必须把 new_pub 也拌进来"）。
/// 本向量同时钉住"**拌了什么**"—— 少拌一项，这里就红。
const String _vecNonceB64 = 'AQIDBAUGBwgJCgsMDQ4PEA';
const String _vecCode = 'FR45A5';

/// 造一份合法票据的编码串，便于逐段替换做反例。
String _encodeWith({
  String? agentId,
  String? oldPub,
  String? nonceB64,
  String? exp,
  String? endpointSeg,
}) =>
    [
      MigrationFormat.prefix,
      agentId ?? _aid,
      oldPub ?? _pub32,
      nonceB64 ?? _vecNonceB64,
      exp ?? '${_now + MigrationFormat.ttlMs}',
      endpointSeg ?? '',
    ].join('.');

void main() {
  print('== 换机直迁（票据格式与纯函数） ==');

  // ------------------------------------------------------------- 格式常量
  print('-- 格式常量 --');

  check(MigrationFormat.prefix == 'FENMIG1', '前缀 = FENMIG1');
  check(
      MigrationFormat.prefix != KeyBackup.prefix &&
          MigrationFormat.prefix != KeyBackup.archivePrefix,
      '★ 前缀与恢复码 FENBK1 / 归档 FENARC1 **都不同**（否则可互相冒充）');
  check(MigrationFormat.segments == 6,
      '段数 = 6：prefix.agent_id.old_pub.nonce.exp.endpoint');
  check(MigrationFormat.nonceBytes == 16, 'nonce = 16 字节（128 位）');
  check(MigrationFormat.ttlMs == 60 * 1000, '有效期 = 60 秒（用户口径）');
  check(MigrationFormat.compareCodeChars == 6,
      '比对码 = 6 字符（★ 强于"4 位数字"：4 位只有 10^4，挡不住重试）');
  check(MigrationFormat.compareAlphabet.length == 32,
      'Crockford base32 字母表 = 32 字符');
  for (final c in ['I', 'L', 'O', 'U']) {
    check(!MigrationFormat.compareAlphabet.contains(c),
        '字母表**不含** $c（前三个与 1/0 易混，U 为避开拼出冒犯词）');
  }

  // ------------------------------------------------------------- 编码往返
  print('-- 编码 / 解码往返 --');

  final t = MigrationTicket(
    agentId: _aid,
    oldPub: _pub32,
    nonceB64: _vecNonceB64,
    expMs: _now + MigrationFormat.ttlMs,
    endpoint: '192.168.1.5:38471',
  );

  final enc = t.encode();
  check(enc.split('.').length == MigrationFormat.segments,
      '编码结果恰好 6 段（可安全按 `.` 切分）');
  check(!enc.contains('='), '编码结果**不含** base64 填充符（放进二维码/mDNS 更干净）');

  final back = MigrationTicket.decode(enc);
  check(back is MigrationTicket, '合法票据 ⇒ 解析成 MigrationTicket');
  if (back is MigrationTicket) {
    check(back.agentId == t.agentId, 'agent_id 往返一致');
    check(back.oldPub == t.oldPub, 'old_pub 往返一致');
    check(back.nonceB64 == t.nonceB64, 'nonce 往返一致');
    check(back.expMs == t.expMs, 'exp 往返一致');
    check(back.endpoint == t.endpoint,
        '★ endpoint 往返一致 —— **主机名里的点号被 base64 段编码掉了**，'
        '不会破坏按 `.` 的切分（`192.168.1.5` 就是这条的实证）');
  }

  check(t.encode() == t.encode(), '编码是**确定性**的（同输入同字节 ⇒ 可离线复算）');
  check(t.endpoint == '192.168.1.5:38471', '原对象未被解码过程改动');

  // endpoint 省略 ⇒ mDNS 自发现
  final tNoEp = MigrationTicket(
    agentId: _aid,
    oldPub: _pub32,
    nonceB64: _vecNonceB64,
    expMs: _now + MigrationFormat.ttlMs,
  );
  check(tNoEp.encode().endsWith('.'),
      '端点为空 ⇒ 第 6 段是空串（字符串以 `.` 收尾）');
  final backNoEp = MigrationTicket.decode(tNoEp.encode());
  check(backNoEp is MigrationTicket && backNoEp.endpoint == '',
      '★ 空端点往返为**空串**（含义 = "请用 mDNS 自发现"，不是"解析失败"）');

  // mint
  final minted = MigrationTicket.mint(
    agentId: _aid,
    oldPub: _pub32,
    nowMs: _now,
  );
  check(minted.expMs == _now + MigrationFormat.ttlMs, 'mint：exp = now + 60s');
  check(minted.endpoint == '', 'mint：默认不填端点（走 mDNS）');
  final minted2 = MigrationTicket.mint(
    agentId: _aid,
    oldPub: _pub32,
    nowMs: _now,
  );
  check(minted2.nonceB64 != minted.nonceB64,
      '★ mint 每次给**新 nonce**（`Random.secure()`，不是可预测伪随机）');
  check(MigrationFormat.b64u(minted.nonceB64.isEmpty
          ? const []
          : MigrationFormat.unb64u(minted.nonceB64)!) ==
      minted.nonceB64, 'mint 的 nonce 编解码自洽');

  // ------------------------------------------------------------- 端点形态
  print('-- 端点形态（host:port） --');

  for (final ok in [
    '10.0.0.1:1',
    '127.0.0.1:8080',
    '192.168.1.5:65535',
    'myhost.local:38471',
    '[fe80::1]:8080',
    '[::1]:38471',
    // ★ 刻意**允许**端口带前导零：`08080` 的意图无歧义（= 8080），
    //   而"多写一个 0"是手输时最普通的手误，不该被判成"端点坏了"。
    'host:08080',
  ]) {
    check(MigrationFormat.validEndpoint(ok), '合法端点：$ok');
  }
  for (final bad in [
    'host:0',
    'host:65536',
    'host:',
    ':8080',
    'host',
    'a:b:8080',
    ' host:80',
    'host:80 ',
    'host:\t80',
    'host:abc',
    'host:99999',
    'host:123456',
    '.host:80',
    'host.:80',
    '[fe80::1:8080',
    '[]:80',
  ]) {
    check(!MigrationFormat.validEndpoint(bad), '非法端点被拒：$bad');
  }

  // ------------------------------------------------------------- fail-closed
  print('-- 解析 fail-closed（每一段各造一个反例） --');

  final cases = <String, String>{
    '段数不足（5 段）': _encodeWith().split('.').take(5).join('.'),
    '段数过多（7 段）': '${_encodeWith()}.extra',
    '前缀不对（拿恢复码冒充）': [
      KeyBackup.prefix,
      _aid,
      _pub32,
      _vecNonceB64,
      '${_now + MigrationFormat.ttlMs}',
      '',
    ].join('.'),
    'agent_id 为空': _encodeWith(agentId: ''),
    'agent_id 含空格': _encodeWith(agentId: 'AG TEST'),
    '★ agent_id 含点号（点号多切出一段 ⇒ 段数不对）':
        _encodeWith(agentId: 'AG.TEST'),
    'old_pub 长度 31 字节': _encodeWith(oldPub: _pub31),
    'old_pub 含非 base58 字符': _encodeWith(oldPub: '0OIl0OIl0OIl0OIl0OIl0OIl0OIl0OIl'),
    'nonce 段为空': _encodeWith(nonceB64: ''),
    'nonce 只有 8 字节': _encodeWith(nonceB64: 'AQIDBAUGBwg'),
    'nonce 非 base64': _encodeWith(nonceB64: '***'),
    'exp 非数值': _encodeWith(exp: 'abc'),
    'exp 为 0': _encodeWith(exp: '0'),
    'exp 为负': _encodeWith(exp: '-1'),
    '端点段非 base64': _encodeWith(endpointSeg: '@@@'),
    '端点解出来不是 host:port':
        _encodeWith(endpointSeg: MigrationFormat.b64u(utf8.encode('not-an-endpoint'))),
    '端点端口越界（65536）':
        _encodeWith(endpointSeg: MigrationFormat.b64u(utf8.encode('h:65536'))),
  };

  final expect = <String, String>{
    '段数不足（5 段）': MigrationFault.badFormat,
    '段数过多（7 段）': MigrationFault.badFormat,
    '前缀不对（拿恢复码冒充）': MigrationFault.badFormat,
    'agent_id 为空': MigrationFault.badAgentId,
    'agent_id 含空格': MigrationFault.badAgentId,
    '★ agent_id 含点号（点号多切出一段 ⇒ 段数不对）': MigrationFault.badFormat,
    'old_pub 长度 31 字节': MigrationFault.badOldPub,
    'old_pub 含非 base58 字符': MigrationFault.badOldPub,
    'nonce 段为空': MigrationFault.badNonce,
    'nonce 只有 8 字节': MigrationFault.badNonce,
    'nonce 非 base64': MigrationFault.badNonce,
    'exp 非数值': MigrationFault.badExpiry,
    'exp 为 0': MigrationFault.badExpiry,
    'exp 为负': MigrationFault.badExpiry,
    '端点段非 base64': MigrationFault.badEndpoint,
    '端点解出来不是 host:port': MigrationFault.badEndpoint,
    '端点端口越界（65536）': MigrationFault.badEndpoint,
  };

  cases.forEach((label, text) {
    final out = MigrationTicket.decode(text);
    check(out is! MigrationTicket && out == expect[label],
        '$label ⇒ ${expect[label]}（实得 $out）');
  });

  var threw = false;
  for (final junk in ['', 'garbage', '.', 'FENMIG1', '.....', 'FENMIG1......']) {
    try {
      final out = MigrationTicket.decode(junk);
      if (out is MigrationTicket) threw = true; // 垃圾被"解析成功"也算失败
    } catch (_) {
      threw = true; // 抛异常同样是失败：解析器必须 fail-closed 而不是炸掉
    }
  }
  check(!threw, '★ 垃圾输入一律返回错误码、**不抛异常**也不假成功');

  // ------------------------------------------------------------- 时间窗
  print('-- 有效期窗口 --');

  final exp = _now + MigrationFormat.ttlMs;
  check(MigrationFormat.expiryFault(exp, exp - 1) == null, '未到期 ⇒ 可接受');
  check(MigrationFormat.expiryFault(exp, exp) == null,
      '**恰好到期那一刻**仍可接受（判据是 `>` 不是 `>=`）');
  check(MigrationFormat.expiryFault(exp, exp + 1) == null,
      '超出 1ms 仍在时钟容忍内（容忍 = ${MigrationFormat.clockSkewToleranceMs}ms）');
  check(
      MigrationFormat.expiryFault(exp, exp + MigrationFormat.clockSkewToleranceMs) ==
          null,
      '恰好用完容忍 ⇒ 仍可接受');
  check(
      MigrationFormat.expiryFault(
              exp, exp + MigrationFormat.clockSkewToleranceMs + 1) ==
          MigrationFault.expiredTicket,
      '超出容忍 1ms ⇒ expired_ticket');
  check(MigrationFormat.expiryFault(0, _now) == MigrationFault.badExpiry,
      'exp ≤ 0 ⇒ bad_expiry');
  check(
      MigrationFormat.expiryFault(_now + MigrationFormat.maxAheadMs, _now) == null,
      '有效期恰好落在上限 ⇒ 可接受');
  check(
      MigrationFormat.expiryFault(_now + MigrationFormat.maxAheadMs + 1, _now) ==
          MigrationFault.badExpiry,
      '★ 有效期**远在未来** ⇒ bad_expiry（挡住"伪造一份十年有效的要约"）');

  check(t.faultAt(t.expMs - 1) == null && t.expiredAt(t.expMs - 1) == false,
      '票据对象：未到期 ⇒ faultAt=null');
  check(
      t.expiredAt(t.expMs + MigrationFormat.clockSkewToleranceMs + 1) == true,
      '票据对象：超容忍 ⇒ expiredAt=true');

  // ------------------------------------------------------------- 比对码
  print('-- 两机人工比对短码 --');

  check(
      MigrationFormat.deriveCompareCode(
            agentId: _aid,
            oldPub: _pub32,
            newPub: _newPub32,
            nonceB64: _vecNonceB64,
          ) ==
          _vecCode,
      '★ 固定向量：sha256("$_aid|$_pub32|$_newPub32|$_vecNonceB64") 前 30 位 ⇒ $_vecCode');
  check(t.compareCodeFor(_newPub32) == _vecCode,
      '票据上的 compareCodeFor(newPub) 与向量一致');
  check(t.compareCodeDisplayFor(_newPub32) == 'FR4-5A5',
      '展示形态 = XXX-XXX（分两段只是好读好念）');

  final c1 = MigrationFormat.deriveCompareCode(
      agentId: _aid, oldPub: _pub32, newPub: _newPub32, nonceB64: _vecNonceB64);
  final c2 = MigrationFormat.deriveCompareCode(
      agentId: _aid, oldPub: _pub32, newPub: _newPub32, nonceB64: _vecNonceB64);
  check(c1 == c2, '派生是确定性的（两端各算一次，必须相同）');
  check(
      c1.length == MigrationFormat.compareCodeChars &&
          c1.split('').every(MigrationFormat.compareAlphabet.contains),
      '长度与字母表都受限（只出现 Crockford 字符）');
  check(
      MigrationFormat.deriveCompareCode(
            agentId: _aid,
            oldPub: _pub32,
            newPub: _newPub32,
            nonceB64: MigrationFormat.b64u(List<int>.filled(16, 7)),
          ) !=
          c1,
      '★ nonce 不同 ⇒ 短码不同（"中继接两条腿"能被人眼发现）');
  check(
      MigrationFormat.deriveCompareCode(
            agentId: 'AG-OTHER00000',
            oldPub: _pub32,
            newPub: _newPub32,
            nonceB64: _vecNonceB64,
          ) !=
          c1,
      '同一枚 nonce 换个身份 ⇒ 短码不同（拌入了 agent_id）');
  check(
      MigrationFormat.deriveCompareCode(
            agentId: _aid,
            oldPub: _pub31,
            newPub: _newPub32,
            nonceB64: _vecNonceB64,
          ) !=
          c1,
      '★ 换一把 old_pub ⇒ 短码不同（"换的是不是我以为的那个身份"可见）');
  // ★★ 这一条补的是 v0.29.0 抓出的**真洞**：只绑 `agent_id|nonce` 时，
  //    攻击者把"迁往哪把钥"掉包成自己的公钥，两端短码**仍然一致**，
  //    而老机签出的 ROTATE 已经指向攻击者的钥 ⇒ 一次能成功的中间人攻击。
  check(
      MigrationFormat.deriveCompareCode(
            agentId: _aid,
            oldPub: _pub32,
            newPub: _pub31,
            nonceB64: _vecNonceB64,
          ) !=
          c1,
      '★★ 换一把 new_pub ⇒ 短码不同（掉包"迁往哪把钥"再无法骗过两屏比对）');
  check(MigrationFormat.displayCode('ABC') == 'ABC',
      '短码不足 4 字符时不插分隔符（不崩）');
  check(MigrationFormat.displayCode('') == '', '空串安全');

  // ------------------------------------------------------------- 一次性账
  print('-- 一次性 nonce 账（防重放） --');

  final ledger = MigrationNonceLedger();
  check(ledger.register(t.id, _now), '首次登记 ⇒ true');
  check(!ledger.register(t.id, _now), '★ 同一张票再登记 ⇒ false（重放）');
  check(ledger.seen(t.id, _now), 'seen 可用作只读预检');
  check(!ledger.seen('AG-NEVER|nothing', _now), '没见过的票 ⇒ seen = false');

  final t2 = MigrationTicket.mint(agentId: _aid, oldPub: _pub32, nowMs: _now);
  check(t2.id != t.id, '★ 不同票的 id 不同（id = agent_id|nonce）');
  check(ledger.register(t2.id, _now), '另一张票可登记');
  check(ledger.size == 2, '账上现有 2 条');
  check(ledger.seen(t2.id, _now + MigrationNonceLedger.retainMs),
      '保留期内仍记得');
  check(!ledger.seen(t2.id, _now + MigrationNonceLedger.retainMs + 1),
      '超出保留期 ⇒ 不再记得（此时票据本身早已过期，被 expiryFault 拦住）');
  check(ledger.size == 0, '查询时顺手清理，账不会无限增长');

  // ------------------------------------------------------------- 边界
  print('-- 边界 --');

  check(Ed25519Sig.isPubkey(_pub32) && !Ed25519Sig.isPubkey(_pub31),
      '★ 公钥形态校验复用 `Ed25519Sig`（全项目唯一实现，不在这里另写一份长度检查）');
  check(MigrationFormat.unb64u('') == null,
      '★ 空串解码返回 null（**刻意**：不与"解码出空列表"混为一谈）');
  check(MigrationFormat.unb64u('***') == null, '非法 base64 ⇒ null（不抛）');
  check(MigrationFormat.b64u(const [1, 2, 3]) == 'AQID', 'base64url 去填充');
  check(
      MigrationFormat.unb64u(MigrationFormat.b64u(const [1, 2, 3]))!.length == 3,
      '编解码往返');

  print('');
  print('TOTAL PASS=$_pass FAIL=$_fail');
  if (_fail > 0) {
    throw StateError('verify_device_migration failed: $_fail');
  }
}
