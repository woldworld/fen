/// 换机直迁（device migration）—— **格式与纯函数**部分，零平台依赖，可离线复算。
///
/// ---------------------------------------------------------------------------
/// 它解决什么
/// ---------------------------------------------------------------------------
/// 「身份随人不随设备」在 v0.26.0 / v0.27.0 已经能给出一条**永远可走**的底线路径：
/// 抄恢复码 `FENBK1` + 输口令 → 新机另生成新钥 → 旧钥签 ROTATE → 数据从 `.dahuang` 归档导入。
/// 那条路径的前提是"**老设备已经不在了**"。
///
/// 但绝大多数换机场景里，**老设备还好好地拿在手上**。此时让用户去抄一串 177 字符的
/// 恢复码、再输一遍口令，是把"能用"变成"愿意用"的障碍。
///
/// 本模块承载的是那条**更短的路径**：老设备出示一份要约、新机接过、两机当面走完。
///
/// ---------------------------------------------------------------------------
/// 三条**不可让步**的约束（都落在本文件的纯函数里）
/// ---------------------------------------------------------------------------
/// 1. **它绝不能成为唯一路径。** 老设备可能已经摔碎、可能进不了系统。
///    恢复码路径必须**永远可走**。所以本模块只产出"要约"，**不替代**任何既有恢复能力。
/// 2. **它仍然是"换钥"而不是"抄钥"。** 直迁只省掉"用户手工抄写"这一环，
///    签名方依然是**旧钥**、结果依然是旧机**当场失效**。
///    若图省事改成"把种子直接递过去"，`did:wold` 的「一个人 = 一个身份」当场破裂
///    —— 见 `identity_rotation.dart` 顶部那三条理由。
/// 3. **它不新增任何服务器角色。** 要约只在**同一局域网内**流转（mDNS / P2P / 二维码），
///    Hub 从头到尾不知道"这两台设备曾经当面见过"。
///
/// ---------------------------------------------------------------------------
/// 为什么这里只有"票据"而没有 ECDH / 二维码 / 相机
/// ---------------------------------------------------------------------------
/// 因为**这两个传输方式（同局域网直连 / 二维码）共享同一份票据**。
/// 把票据的编解码与过期判定先做成**独立纯函数**，好处是可离线单测（本文件 + 配套校验脚本），
/// 且将来无论换哪种传输，**只换 UI 与传输层那一处**，票据本身不动。
///
/// ⚠️ 相机扫码需要引入 `mobile_scanner`，其 Android 实现走 **ML Kit、依赖 Google Play 服务**
/// —— 对国内市场是硬伤，且当前处于**发布冻结**（无法做真机相机验证）。
/// 故第一阶段先用"同局域网 mDNS 自发现 + 两屏人工比对短码"，
/// ★ 安全模型**完全等价**：真正的秘密是那条**已加密的信道 + 短码**，二维码只是省一次手工输入。
///
/// ---------------------------------------------------------------------------
/// 威胁模型（写清楚，因为它和恢复码路径**不一样**）
/// ---------------------------------------------------------------------------
/// 恢复码路径的威胁模型是"**谁拿到纸条谁是主人**"（离线、静态）。
/// 直迁路径的威胁模型是"**同一空间里可能有人在偷看 / 插入**"：
///   * 攻击者可能抢先应答，冒充老设备（⇒ `compareCodeFor` 对不上）；
///   * 攻击者可能同时接两头发起**中继**，把两端都骗过去
///     （⇒ 短码必须覆盖**完整绑定**：`agent_id` + `old_pub` + `new_pub` + nonce，
///     任一处被改动两屏即不一致 —— 尤其 `new_pub`：只绑 nonce 的话，
///     攻击者把"迁往哪把钥"掉包成自己的，两屏仍然一致）；
///   * 攻击者可能**重放**一份刚刚截到的要约（⇒ `MigrationNonceLedger` 一次性登记）。
/// 因此本文件提供 [MigrationTicket.compareCodeFor]（人工比对）与 [MigrationNonceLedger]（防重放），
/// 而**会话密钥的绑定**由既有的 `session_handshake.dart` 承担（阶段二接线）。
///
/// 本文件**不 import Flutter / sqflite / shared_preferences**：
/// 只用 `dart:convert` + `dart:math` + `package:crypto` + [Ed25519Sig]，
/// 因此 `dart run tool/verify_device_migration.dart` 可在独立 Dart VM 里复算。
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;

import 'ed25519_sig.dart';

/// 直迁相关的失败码（**语言无关的稳定码**，UI 负责翻译）。
///
/// 与 `RotationFault` / `ArchiveFault` 同款纪律：这些码是**线上格式的一部分**，
/// 改不动已经发出去的票据，所以用字符串常量而不是 enum。
abstract final class MigrationFault {
  /// 段数 / 前缀 / base64 任一不合法。
  static const String badFormat = 'bad_format';

  /// 身份 ID 形态不合法。
  static const String badAgentId = 'bad_agent_id';

  /// `old_pub` 不是合法的 32 字节 Ed25519 公钥（base58）。
  static const String badOldPub = 'bad_old_pub';

  /// nonce 不是 16 字节。
  static const String badNonce = 'bad_nonce';

  /// 有效期字段不合法（非数、非正、或远在未来 —— 那不是我们签出的票）。
  static const String badExpiry = 'bad_expiry';

  /// 端点串不合法（有值但不是 `host:port` 形态）。
  static const String badEndpoint = 'bad_endpoint';

  /// 已过期。
  static const String expiredTicket = 'expired_ticket';

  /// 同一个 nonce 被用了第二次（**重放**）。
  static const String replayedTicket = 'replayed_ticket';
}

/// 票据的格式常量与纯函数。
abstract final class MigrationFormat {
  /// 格式版本载体（照抄 `FENBK1` / `FENARC1` 的做法：版本由前缀承载，
  /// 换格式就换前缀，**旧前缀的解析器可以永久保留**）。
  static const String prefix = 'FENMIG1';

  /// 段数：`prefix.agent_id.old_pub.nonce.exp.endpoint`。
  static const int segments = 6;

  /// nonce 字节数（128 位；一次性 + 唯一性都由它承载）。
  static const int nonceBytes = 16;

  /// 要约有效期。★ 用户口径是**60 秒** —— 直迁是"两台设备都在手里、当面进行"的动作，
  /// 时间窗只需要容纳"举起手机 → 看到 → 点确认"，不需要更长。
  /// ★ 窗口越短，被同空间攻击者利用的机会越少，所以这里**不设"够用就好"的余地**。
  static const int ttlMs = 60 * 1000;

  /// 允许旧设备时钟比新机"快"多少（新机判过期只是 UX 预筛；
  /// **最终裁定者是用自己时钟签出 ROTATE 的旧设备**）。
  static const int clockSkewToleranceMs = 2 * 60 * 1000;

  /// 有效期**最多**能落在未来多远。超过即视为"不是我们签出的票"——
  /// 挡住"伪造一份十年有效的要约"这类构造。
  static const int maxAheadMs = 10 * 60 * 1000;

  /// 人工比对短码的字符数。
  ///
  /// ★ 用户提的是"4 位码"，这里取 **6 位**：4 位十进制只有 10^4 种，
  /// 而攻击者可以**反复重试**，10^4 挡不住。6 位 32 进制 = **2^30 ≈ 10.7 亿**，
  /// 既远超暴力重试的可行范围，又仍然"一眼能读完"。
  static const int compareCodeChars = 6;

  /// Crockford base32：**剔除了 I / L / O / U** —— 前三个与 1 / 0 易混，
  /// U 是为了避免拼出冒犯性单词。人眼比对靠的就是"不容易看错"。
  static const String compareAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// 身份 ID 的形态（实际生成的是 `AG-` + 10 位字母数字，见 `db_helper.dart`）。
  /// 这里放宽到"非空、无点、无空白"，因为 ID 是**别人的标识符**，
  /// 我们不该用自己这一代的生成规则去拒绝上一代的数据。
  static final RegExp agentIdPattern = RegExp(r'^[A-Za-z0-9_-]{3,64}$');

  /// 主机名 / IPv4 字面量的字符集（`[` `]` 另行处理，见 [validEndpoint]）。
  static final RegExp _hostPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  /// 端口段：**只允许数字**。
  ///
  /// ⚠️ 这里**必须自己写正则**，不能只靠 `int.tryParse`：
  /// Dart 的 `int.tryParse` **接受首尾空白**（`int.tryParse('80 ')` 就是 80），
  /// 于是 `host:80 `（尾部多一个空格）会被判成合法端点 ——
  /// 这正是首轮校验脚本抓出来的 FAIL。**"能解析"不等于"是我们要的形状"。**
  ///
  /// ★ 刻意**允许前导零**（`08080` = 8080）：意图无歧义，而"多写一个 0"
  /// 是手输时最普通的手误，判成"端点坏了"只会让人困惑。
  static final RegExp _portPattern = RegExp(r'^[0-9]{1,5}$');

  /// base64url 编码，**去掉 `=` 填充**（票据要放进二维码与 mDNS TXT，填充符是噪声）。
  static String b64u(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// base64url 解码，**任何异常都返回 null**（fail-closed）。
  ///
  /// 空串**刻意不算合法载荷**（返回 null 而不是空列表）：
  /// 否则"忘了填 nonce"与"nonce 是空的"会走同一个分支，而它们该被区分对待。
  static List<int>? unb64u(String s) {
    if (s.isEmpty) return null;
    try {
      // `normalize` 把 base64url 的 `-`/`_` 转成标准字母表并补齐填充，
      // 于是 `decode` 不必猜调用方用的是哪种字母表。
      return base64.decode(base64.normalize(s));
    } catch (_) {
      return null;
    }
  }

  /// 生成一枚 nonce（`Random.secure()` —— 这是一次性凭据，不能用可预测的伪随机）。
  static List<int> newNonceBytes() {
    final r = Random.secure();
    return List<int>.generate(nonceBytes, (_) => r.nextInt(256));
  }

  /// ★ **两机人工比对短码** —— 由**这次迁移的完整绑定**确定性派生。
  ///
  /// 关键性质是"**两台设备各自算得出同一串，无需任何额外传输**"：
  /// 老设备据自己的 nonce 算出、新机据收到的票据算出，中间那条信道**不必可信**。
  ///
  /// ---------------------------------------------------------------------------
  /// ⚠️ 为什么必须把 `new_pub` 也拌进来（这是 v0.29.0 抓出的一个**真洞**）
  /// ---------------------------------------------------------------------------
  /// 只绑 `agent_id | nonce` 会漏掉一次**能成功**的中间人攻击：
  ///   ① 新机发出"这是我的新公钥 X"，中间人把 X **掉包成自己的 Y** 再转发；
  ///   ② 老机铸票据（nonce 由**老机**生成、原样穿过中间人）⇒ 两端算出的短码**完全一致**；
  ///   ③ 老机签出的 ROTATE 指向 Y ⇒ **身份落进攻击者手里**，而两屏比对一路绿灯。
  ///
  /// 短码的全部意义是"把不可信信道上**每一处改动**变成两屏不一致"，所以它必须覆盖
  /// "**在动谁、迁去哪把钥**"这两个问题：
  ///   · `old_pub` —— 换的是不是我以为的那个身份；
  ///   · `new_pub` —— 那把钥**是不是我的**（上面这个洞就出在这里）。
  /// 把 `agent_id` 也拌进去，是为了让"同一枚 nonce 被两个身份复用"也产生不同短码。
  static String deriveCompareCode({
    required String agentId,
    required String oldPub,
    required String newPub,
    required String nonceB64,
  }) {
    final digest = crypto
        .sha256
        .convert(utf8.encode('$agentId|$oldPub|$newPub|$nonceB64'))
        .bytes;
    final out = StringBuffer();
    var acc = 0;
    var bits = 0;
    var i = 0;
    while (out.length < compareCodeChars) {
      acc = (acc << 8) | digest[i % digest.length];
      i++;
      bits += 8;
      while (bits >= 5 && out.length < compareCodeChars) {
        bits -= 5;
        out.write(compareAlphabet[(acc >> bits) & 31]);
      }
    }
    return out.toString();
  }

  /// `XXXXXX` → `XXX-XXX`（分两段只是为了好读、好念）。
  static String displayCode(String code) =>
      code.length <= 3 ? code : '${code.substring(0, 3)}-${code.substring(3)}';

  /// `host:port` 是否合法。端口必须落在 1..65535（0 与 65536 都是"写错了"，
  /// 而不是"某种特殊含义"，故一律拒）。
  ///
  /// 形态：IPv4 字面量 / 主机名（`192.168.1.5`、`myhost.local`），
  /// 或**带方括号的 IPv6 字面量**（`[fe80::1]:8080` —— 方括号是必需的，
  /// 否则 `::1:8080` 根本无法切分）。
  static bool validEndpoint(String endpoint) {
    final at = endpoint.lastIndexOf(':');
    if (at <= 0 || at == endpoint.length - 1) return false;
    final host = endpoint.substring(0, at);
    final portStr = endpoint.substring(at + 1);
    if (!_portPattern.hasMatch(portStr)) return false;
    final port = int.parse(portStr);
    if (port < 1 || port > 65535) return false;
    if (host.startsWith('[') || host.endsWith(']')) {
      // 半个方括号 = 写坏了；`[]` 也不是合法字面量。
      return host.startsWith('[') && host.endsWith(']') && host.length > 2;
    }
    if (!_hostPattern.hasMatch(host)) return false;
    // 首尾的点会让"主机名"看起来像别的东西（`.host` / `host.`），一律拒。
    return !host.startsWith('.') && !host.endsWith('.');
  }

  /// 有效期的可接受性（`null` = 可接受）。
  ///
  /// ⚠️ 这里**只用本机时钟做预筛**。真正的过期裁定在旧设备那一侧
  /// （它才是用自己时钟签出 ROTATE 的一方），所以对时钟偏差留了
  /// [clockSkewToleranceMs] 的余量 —— 刚装好的手机时钟偏几分钟是常态。
  static String? expiryFault(int expMs, int nowMs) {
    if (expMs <= 0) return MigrationFault.badExpiry;
    if (expMs - nowMs > maxAheadMs) return MigrationFault.badExpiry;
    if (nowMs > expMs + clockSkewToleranceMs) return MigrationFault.expiredTicket;
    return null;
  }
}

/// 一份**换机直迁要约**：老设备出示、新机接过。
///
/// 它**不是**凭据 —— 单独拿到它做不成任何事（票据没有签名，也不含任何私钥材料）。
/// 它的作用只有两个：① 告诉新机"对面是谁、往哪连"；② 提供一枚**一次性 nonce**，
/// 让两端能各自算出同一个 [compareCodeFor] 供人眼比对。
///
/// ★ **真正的授权始终是旧钥对 ROTATE 的签名**（阶段二接线，复用 `identity_rotation.dart`）。
/// 攻击者可以伪造本票据，但**伪造不出一条能通过 Hub 验签的 ROTATE** ——
/// 因此伪造票据的危害上限是"让人白忙一场"，不是"盗走身份"。
class MigrationTicket {
  /// 出示方（老设备）的身份 ID。
  final String agentId;

  /// 出示方**当前的活跃公钥**（base58）。
  ///
  /// ⚠️ 这是"当前活跃钥"而不是"身份根钥"：换过钥的身份，活跃钥已经变过，
  /// 而 ROTATE **必须由当前活跃钥签**（否则 Hub 判 `not_current_key`）。
  final String oldPub;

  /// 一次性 nonce（base64url，无填充），16 字节。
  final String nonceB64;

  /// 有效期（毫秒时间戳）。
  final int expMs;

  /// 出示方在同一局域网里的 `host:port`。
  ///
  /// **空串是合法值**，含义是"**请用 mDNS 自发现**"——
  /// 这正是第一阶段（无相机依赖）的默认形态：地址由 mDNS 给出，票据由发现结果带来。
  /// 只有走二维码时才会把地址填进来（二维码解决的是"mDNS 不通"的场景）。
  final String endpoint;

  const MigrationTicket({
    required this.agentId,
    required this.oldPub,
    required this.nonceB64,
    required this.expMs,
    this.endpoint = '',
  });

  /// 一次性登记的键：同一身份 + 同一 nonce = 同一份要约。
  String get id => '$agentId|$nonceB64';

  /// 两机人工比对的短码（`XXX-XXX`）。
  ///
  /// ⚠️ **必须传入本次迁移要迁往的那把新公钥**：票据本身**不含** `new_pub`
  /// （新钥是新机生出来的，不在老机的要约里），而短码若不覆盖它，
  /// "掉包 `new_pub`"的中间人就无法被人眼发现 —— 详情见
  /// [MigrationFormat.deriveCompareCode] 的"为什么必须把 new_pub 也拌进来"。
  ///
  /// 把它做成**必需参数**而不是带默认值的可选参数，正是为了让"忘了绑"编译不过。
  String compareCodeFor(String newPub) => MigrationFormat.deriveCompareCode(
        agentId: agentId,
        oldPub: oldPub,
        newPub: newPub,
        nonceB64: nonceB64,
      );

  /// 同上，带分隔符的展示形态。
  String compareCodeDisplayFor(String newPub) =>
      MigrationFormat.displayCode(compareCodeFor(newPub));

  /// 本机时钟看，是否已过期（容忍另一台设备的时钟偏差）。
  bool expiredAt(int nowMs) =>
      MigrationFormat.expiryFault(expMs, nowMs) ==
      MigrationFault.expiredTicket;

  /// 本机时钟看，有效期字段是否可信（`null` = 可接受）。
  String? faultAt(int nowMs) => MigrationFormat.expiryFault(expMs, nowMs);

  /// 编码成一行文本：`FENMIG1.<agent_id>.<old_pub>.<nonce>.<exp>.<endpoint>`。
  ///
  /// 各段**都不含 `.`**（`agent_id` 的字符集排除了它，公钥是 base58，
  /// 后三段是十进制或 base64url），所以按 `.` 切分是安全的 —— 这条性质由
  /// [decode] 的形态校验反向钉住。
  String encode() => [
        MigrationFormat.prefix,
        agentId,
        oldPub,
        nonceB64,
        '$expMs',
        endpoint.isEmpty ? '' : MigrationFormat.b64u(utf8.encode(endpoint)),
      ].join('.');

  /// 解析一行文本。返回 [MigrationTicket]，或 [MigrationFault] 的码。
  ///
  /// **全程 fail-closed**：任何一段不合法都返回码，绝不"尽力解析出一个看起来还行的东西"
  /// （那正是"拿 A 的票据去连 B"这类故障的温床）。
  static Object decode(String text) {
    final parts = text.split('.');
    if (parts.length != MigrationFormat.segments) {
      return MigrationFault.badFormat;
    }
    if (parts[0] != MigrationFormat.prefix) return MigrationFault.badFormat;

    final agentId = parts[1];
    if (!MigrationFormat.agentIdPattern.hasMatch(agentId)) {
      return MigrationFault.badAgentId;
    }

    final oldPub = parts[2];
    // ★ 复用 `Ed25519Sig` 而不是另写一遍长度检查：它是本项目**唯一**的
    //   公钥形态实现，两处各写一份必然在某次放宽里漂移。
    if (!Ed25519Sig.isPubkey(oldPub)) return MigrationFault.badOldPub;

    final nonceB64 = parts[3];
    final nonce = MigrationFormat.unb64u(nonceB64);
    if (nonce == null || nonce.length != MigrationFormat.nonceBytes) {
      return MigrationFault.badNonce;
    }

    final expMs = int.tryParse(parts[4]);
    if (expMs == null || expMs <= 0) return MigrationFault.badExpiry;

    final rawEndpoint = parts[5];
    var endpoint = '';
    if (rawEndpoint.isNotEmpty) {
      final bytes = MigrationFormat.unb64u(rawEndpoint);
      if (bytes == null) return MigrationFault.badEndpoint;
      String decoded;
      try {
        decoded = utf8.decode(bytes);
      } catch (_) {
        return MigrationFault.badEndpoint;
      }
      if (!MigrationFormat.validEndpoint(decoded)) {
        return MigrationFault.badEndpoint;
      }
      endpoint = decoded;
    }

    return MigrationTicket(
      agentId: agentId,
      oldPub: oldPub,
      nonceB64: nonceB64,
      expMs: expMs,
      endpoint: endpoint,
    );
  }

  /// 由一段随机 nonce 铸出一份要约（老设备侧调用）。
  static MigrationTicket mint({
    required String agentId,
    required String oldPub,
    required int nowMs,
    String endpoint = '',
    List<int>? nonceBytes,
  }) =>
      MigrationTicket(
        agentId: agentId,
        oldPub: oldPub,
        nonceB64: MigrationFormat.b64u(
            nonceBytes ?? MigrationFormat.newNonceBytes()),
        expMs: nowMs + MigrationFormat.ttlMs,
        endpoint: endpoint,
      );

  @override
  String toString() =>
      'MigrationTicket($agentId, exp=$expMs, endpoint=${endpoint.isEmpty ? 'mDNS' : endpoint})';
}

/// ★ 「**一次性 nonce**」的本机账。
///
/// 为什么需要一个**有状态**的东西：nonce 的"一次性"无法靠纯函数表达 ——
/// 它需要记住"这一枚用过了"。而这件事**只能在本机做**：
/// 让服务器去记就等于把"这两台设备当面见过"告诉了 Hub，违反本模块的约束 3。
///
/// 保留期取 [retainMs]，**远长于**票据的 60 秒有效期：过期票据本来就已被
/// [MigrationFormat.expiryFault] 拒掉，本账要防的是"窗口内的重放"，
/// 留长一点只是让账不必频繁清理。
class MigrationNonceLedger {
  final Map<String, int> _seenAtMs = {};

  /// 保留多久（30 分钟）。
  static const int retainMs = 30 * 60 * 1000;

  /// 登记一份要约。**已见过 ⇒ 返回 false**（= 重放）。
  ///
  /// 返回 `bool` 而不是故障码，因为调用方只有两个分支（继续 / 拒绝），
  /// 而"为什么拒绝"已经由 `MigrationFault.replayedTicket` 定死。
  bool register(String ticketId, int nowMs) {
    _prune(nowMs);
    if (_seenAtMs.containsKey(ticketId)) return false;
    _seenAtMs[ticketId] = nowMs;
    return true;
  }

  /// 这份要约是否已被用过（只读，不登记）。
  bool seen(String ticketId, int nowMs) {
    _prune(nowMs);
    return _seenAtMs.containsKey(ticketId);
  }

  /// 当前记着多少条（测试用）。
  int get size => _seenAtMs.length;

  /// 丢弃超过保留期的记录。**先清再查**，否则"很久以前用过"会永久占着内存。
  void _prune(int nowMs) {
    _seenAtMs.removeWhere((_, at) => nowMs - at > retainMs);
  }
}
