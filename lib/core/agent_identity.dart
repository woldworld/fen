import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'agent_protocol.dart';
import 'db_helper.dart';
import 'key_backup.dart';

/// 设备 Ed25519 身份：私钥（种子）永不出设备，公钥即身份。
///
/// 升级目标（对应 hub.js 注册规则的"身份保护"）：
/// - 身份从随机 AG-XXXX 升级为可自证的 `did:wold:<base58(pubkey)>`；
/// - Hub 上只存公钥，密钥泄露/服务器被拖库不再危及身份；
/// - 旧 HMAC 设备密钥保留作为对旧版服务器的兼容回退（identity_alg 记录当前生效算法）。
class AgentIdentity {
  static final AgentIdentity _instance = AgentIdentity._internal();
  factory AgentIdentity() => _instance;
  AgentIdentity._internal();

  static const String _seedKey = 'device_id_seed';
  static const String _algKey = 'identity_alg';

  /// "当前这把钥已备份过"的落点（存**公钥**，不存布尔值 —— 理由见 [isBackedUp]）。
  static const String _backupPubKey = 'identity_backup_pub';

  /// **身份锚**（身份根 DID）的落点 —— 换机恢复时由服务端确认值写入。
  ///
  /// 为什么必须**落盘**而不是每次现推：身份根是**身份诞生时**的 DID，
  /// 它的签发记录在老设备上；新设备本地根本没有那一条。
  /// 只有 Hub 知道"这个 `agent_id` 的身份锚是什么"（换钥端点返回的 `did`）。
  /// ⇒ 不落盘 ⇒ 新设备只能按新钥现推 ⇒ 界面显示一个 Hub 上查不到的身份地址。
  static const String _rootDidKey = 'identity_root_did';

  /// **我退休过的公钥**的落点（每个 `agent_id` 一条字符串列表，旧的在前）。
  ///
  /// 为什么本地要留一份（而不是只依赖 Hub 的换钥链）：M6 背书按 `subject_pub` 计，
  /// 换钥之后"我收到的背书"仍记在**旧钥**上。若只认当前钥，用户换一次手机就会
  /// 看到自己的履历归零。Hub 的换钥链能给出同一份答案（且可被第三方复算），
  /// 但**离线时、或 Hub 不可达时**本地这份是唯一能让履历不消失的东西。
  /// 两份取并集：多一份证据，不会多出"别人的钥"（写入点只有 [bindSeam]，
  /// [dropSeam] 只做"整行撕掉"，见那里的说明）。
  static const String _retiredPrefix = 'identity_retired_keys_';

  static final Ed25519 _algo = Ed25519();

  SimpleKeyPair? _cachedKeyPair;
  Future<SimpleKeyPair>? _creating;
  String? _cachedPubB58;

  /// 当前与 Hub 通信使用的算法：'ed25519'（Hub 已确认绑定公钥）或 'hmac-sha256'（回退）。
  Future<String> activeAlg() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_algKey) ?? 'hmac-sha256';
  }

  /// 仅在 Hub 明确确认接受公钥注册后调用（见 CloudService.registerAgent）
  Future<void> markEd25519Active() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_algKey, 'ed25519');
  }

  /// 获取或首次生成设备身份密钥（并发安全：只生成一次）
  Future<SimpleKeyPair> getOrCreateKeyPair() async {
    if (_cachedKeyPair != null) return _cachedKeyPair!;
    if (_creating != null) return _creating!;
    final completer = _create();
    _creating = completer;
    try {
      return await completer;
    } finally {
      _creating = null;
    }
  }

  Future<SimpleKeyPair> _create() async {
    final prefs = await SharedPreferences.getInstance();
    final seedHex = prefs.getString(_seedKey);
    SimpleKeyPair kp;
    if (seedHex != null && seedHex.length == 64) {
      kp = await _algo.newKeyPairFromSeed(_hexDecode(seedHex));
    } else {
      kp = await _algo.newKeyPair();
      final seed = await kp.extractPrivateKeyBytes();
      await prefs.setString(_seedKey, _hexEncode(seed));
    }
    _cachedKeyPair = kp;
    return kp;
  }

  /// base58(Bitcoin 字母表) 编码的 32 字节公钥
  Future<String> publicKeyBase58() async {
    if (_cachedPubB58 != null) return _cachedPubB58!;
    final kp = await getOrCreateKeyPair();
    final pub = await kp.extractPublicKey();
    _cachedPubB58 = AgentProtocol.base58Encode(pub.bytes);
    return _cachedPubB58!;
  }

  /// 自证身份：did:wold:<base58(pubkey)>（v1.2 起；旧值 did:pocketagent: 仍被接受）
  Future<String> did() async {
    return 'did:wold:${await publicKeyBase58()}';
  }

  // ------------------------------------------------------------------
  // 身份可携带（"随人不随设备"）—— 见 lib/身份可携带与恢复方案.md
  // ------------------------------------------------------------------

  /// 取出本机身份的 **32 字节种子**。
  ///
  /// ⚠️ 调用方拿到的是**账号本身**：不要落库、不要写日志、不要进异常信息。
  /// 只有 [exportBackupCode] 与恢复编排层需要它。
  Future<List<int>> currentSeed() async {
    final kp = await getOrCreateKeyPair();
    return kp.extractPrivateKeyBytes();
  }

  /// 把身份备份成一个**恢复码**（口令加密，见 [KeyBackup]）。
  ///
  /// 口令**不经过网络、不落任何地方** —— 解得开 = 口令对，我们既不需要存它，
  /// 也没有能力验证它。这是"身份归用户持有"的具体形态。
  Future<String> exportBackupCode({
    required String password,
    required String agentId,
  }) async {
    return KeyBackup.seal(
      seed: await currentSeed(),
      agentId: agentId,
      pubB58: await publicKeyBase58(),
      password: password,
    );
  }

  /// ★ **当前生效的这把钥是否已备份过**（决定"未备份"红标显不显示）。
  ///
  /// 存的是**公钥**而不是一个布尔值，这一条是有意的：
  /// 恢复码是**对着某一把钥**签发的。换钥（换机恢复）之后本机换了钥，
  /// 旧恢复码对新钥**无效** —— 此时"已备份"必须自动变回"未备份"，
  /// 否则用户会拿着一个已经不生效的码，以为自己有退路。
  /// 存公钥 ⇒ 换钥后比对自然失败 ⇒ 红标自己回来。**不需要任何清理代码。**
  Future<bool> isBackedUp() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_backupPubKey);
    if (saved == null || saved.isEmpty) return false;
    return saved == await publicKeyBase58();
  }

  /// 记下"当前这把钥已经备份好了"（备份页在显示完恢复码、用户勾选已抄下之后调用）。
  Future<void> markBackedUp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupPubKey, await publicKeyBase58());
  }

  /// **身份根 DID** —— 本机所属身份**诞生时**的那个 `did:wold`。
  ///
  /// ⚠️ 与 [did] 的区别（★ 这是"随人不随设备"的关键之一）：
  /// [did] 是**从当前公钥现推**的（`did:wold:<当前钥>`）。换钥之后它会变，
  /// 而 Hub 侧的身份锚**不变**（`lib/hub/hub.js` 换钥端点只改绑活跃钥）。
  /// 于是"客户端现推的 DID"与"Hub 记的 DID"会**分叉**，界面就会显示一个
  /// 别人在 Hub 上查不到的身份地址。
  ///
  /// 所以凡是**要展示、要落库、要拿去核对**的地方，一律用本方法：
  /// 从 `did_issuance` 里取本 `agent_id` **最早**的一条 —— 那才是身份根
  /// （该表 append-only，重装/换钥都不会改写它）。
  ///
  /// 兜底：查不到任何签发记录时退回 [did]（全新安装、尚未签发的情形）。
  Future<String> identityRootDid() async {
    // ① 服务端确认过的身份锚最权威（换机恢复后就是靠它对齐 Hub）。
    final prefs = await SharedPreferences.getInstance();
    final anchor = prefs.getString(_rootDidKey);
    if (anchor != null && anchor.isNotEmpty) return anchor;

    // ② 其次看本机自己的签发历史（append-only，最早那一条 = 身份根）。
    final agentId = await DBHelper.getAmbassador('my_agent_id');
    if (agentId != null && agentId.isNotEmpty) {
      final db = await DBHelper.db;
      final rows = await db.query(
        'did_issuance',
        where: 'agent_id = ?',
        whereArgs: [agentId],
        orderBy: 'issued_at ASC',
        limit: 1,
      );
      final stored = rows.isEmpty ? null : rows.first['did'] as String?;
      if (stored != null && stored.isNotEmpty) return stored;
    }
    // ③ 全新安装：尚未签发，按当前钥现推即可（随后 _issueDidIfNeeded 会落库）。
    return did();
  }

  /// 把一份种子**装回本机**（仅在换钥已被服务端确认后调用）。
  ///
  /// ★ 本方法只改"本机用哪把钥"，**不负责让旧设备失效** —— 那是换钥声明的职责
  /// （见 `identity_recovery.dart` 与 `IdentityRotation`）。
  /// 两者分开是有意的：**先确认服务端改绑成功，再装新钥**；
  /// 反过来的话，一旦服务端拒绝，这台机器就成了一把没人认的钥匙。
  Future<void> installSeed(List<int> seed) async {
    if (seed.length != 32) {
      throw ArgumentError('seed must be 32 bytes, got ${seed.length}');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seedKey, _hexEncode(seed));
    // 缓存必须一起清 —— 只改 prefs 而不清 `_cachedKeyPair`，
    // 本进程后续仍会用旧钥签名（"装回去了但还是旧身份"这种最难查的形态）。
    _cachedKeyPair = null;
    _cachedPubB58 = null;
  }

  /// 恢复后让本机**接管**一个既有身份（`agent_id` + 当前公钥）。
  ///
  /// ★ 为什么必须与 [installSeed] 分开、又必须一起调：
  ///   `my_agent_id` 是装机时随机生成、且写入用的是 `ConflictAlgorithm.ignore`
  ///   （一辈子只写一次）。换机恢复时若只装种子不改它，本机就会**顶着新随机 ID**，
  ///   而 Hub 改绑的是**旧身份** —— 用户会看到"恢复成功"，然后什么都收发不通。
  ///   所以三件事必须同时成立：
  ///     ① 新种子落盘（[installSeed]）；
  ///     ② `my_agent_id` 覆盖为**旧身份**；
  ///     ③ 接缝表 `agent_pubkeys`（身份 ↔ 当前公钥）指向**新公钥** ——
  ///        否则网络信誉/背书仍按旧公钥索引，改绑后立刻对不上；
  ///     ④ **身份锚** `identity_root_did` 落盘（`didAnchor`）——
  ///        ★ 这一步以前漏了：Hub 换钥**不改** `did`，而本机只会按新钥现推，
  ///        于是恢复后界面显示的身份地址**与 Hub 上的不一致**（见 [identityRootDid]）。
  ///        传空则不覆盖（兼容未配 Hub / 离线本地记录）。
  ///
  /// ⚠️ 同样只在**服务端确认改绑之后**调用。
  Future<void> adoptAgentId({
    required String agentId,
    required String pubB58,
    String? didAnchor,
  }) async {
    await DBHelper.saveAmbassador('my_agent_id', agentId);
    if (didAnchor != null && didAnchor.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rootDidKey, didAnchor);
    }
    // 接缝表的写入**全部**经 [bindSeam]（唯一写入点）。
    // 本路径是"服务端已确认改绑"的权威路径，故 `viaConfirmedRotation: true`：
    // 一条**合法**的换钥链理论上可以回到一把更早的钥（A→B→A），
    // 那不是"偷偷复活退休钥"，而是 Hub 的当前活跃钥就是这样，客户端必须跟上。
    // 即便如此，被顶掉的那把钥仍然**先留痕再覆盖**（见 bindSeam ③）。
    await bindSeam(
      agentId: agentId,
      pubB58: pubB58,
      source: 'rotation',
      viaConfirmedRotation: true,
    );
  }

  /// ★★ 接缝表 `agent_pubkeys` 的**唯一写入点**（外部审计 P2② 修复）。
  ///
  /// 这张表是「本地信誉（按 `agent_id`）↔ 网络信誉（按 `pubkey`）」之间**唯一的桥**，
  /// 而"一个身份只有一把当前钥 + 换钥必先留痕"是身份可携带方案的立身之本。
  /// 原先有两个写入者：[adoptAgentId]（会先把旧钥抄进退休表）与护照页的
  /// `_bindPubkey`（**直接覆盖、旧钥不留痕**，也**不拦**把退休钥写回来）。同一条
  /// 不变式在两条路径上强度不同 —— 于是"必先留痕"只在自己那条路上成立，
  /// 而"退休"在另一条路上变成可撤销的。故收敛成这一个方法，两条路都必须走它。
  ///
  /// 规格（四件事一次办完，调用方不必各记一遍）：
  ///  ① 空 `agentId` / 空 `pub` ⇒ 什么都不做；
  ///  ② 是否**已退休**：[retiredKeys]（本地那份）命中且 `viaConfirmedRotation` 为假
  ///     ⇒ **拒绝**（退休不可撤销）；权威换钥路径传 `true` 放行，但仍走 ③；
  ///  ③ 目标与现值**相同** ⇒ 不写（幂等，不刷新 `at_ms`、不重复留痕）；
  ///  ④ 值要变 ⇒ **先把被顶掉的旧钥抄进退休表**，再覆盖。
  ///
  /// 返回 `true` = 值确实变了；`false` = 被 ①②③ 任一挡下。
  Future<bool> bindSeam({
    required String agentId,
    required String pubB58,
    String source = 'passport',
    bool viaConfirmedRotation = false,
  }) async {
    final id = agentId.trim();
    final p = pubB58.trim();
    if (id.isEmpty || p.isEmpty) return false; // ①

    // ② 退休闸：只在**非权威**路径上生效。authoritative 的那条路（Hub 已确认改绑）
    //    放行是因为"当前活跃钥"这句话的最终解释权在 Hub，客户端不能替它否掉。
    if (!viaConfirmedRotation) {
      final retired = await retiredKeys(id);
      if (retired.contains(p)) return false;
    }

    final db = await DBHelper.db;
    final prior = await db.query('agent_pubkeys',
        columns: ['pubkey'], where: 'agent_id = ?', whereArgs: [id], limit: 1);
    final priorPub = prior.isEmpty ? '' : ((prior.first['pubkey'] as String?) ?? '');
    if (priorPub == p) return false; // ③ 已经是它

    // ④ ★ 退休留痕：这张表每个身份只留**一行**，改绑即覆盖
    //   （一个人挂 N 把钥 = 在自己的背书网络里放大 N 倍，正是要堵的 Sybil 形态）。
    //   所以被覆盖掉的那把旧钥必须先抄出来 —— 否则本机再也说不出"我曾经是谁"，
    //   而那些钥名下收着的背书（M6 履历）就再也没人能认领。
    if (priorPub.isNotEmpty) {
      await _recordRetiredKey(id, priorPub);
    }
    // 不用 ON CONFLICT（Android 10 自带 SQLite 3.22 不支持）；`replace` 只是保险，
    // 上面已经查过一次，正常走的是"无行则插入、有行则覆盖"。
    await db.insert(
      'agent_pubkeys',
      {
        'agent_id': id,
        'pubkey': p,
        'source': source,
        'at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DBHelper.dataRevision++;
    return true;
  }

  /// 记下"这把钥已被我退休"（幂等；只追加，不删）。
  ///
  /// ⚠️ 键写成**内联字面量**（不先赋给局部变量）：`tool/verify_data_keys.dart` 会
  /// 把"变量拼出的键"列为盲区、要求逐条登记 —— 内联拼法能解析成同一个来源，
  /// 少一处需要人工判断的盲区。
  Future<void> _recordRetiredKey(String agentId, String pub) async {
    final id = agentId.trim();
    final p = pub.trim();
    if (id.isEmpty || p.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_retiredPrefix$id') ?? <String>[];
    if (list.contains(p)) return;
    list.add(p);
    await prefs.setStringList('$_retiredPrefix$id', list);
  }

  /// 我退休过的公钥（**本地**那一份；Hub 的换钥链是另一份，两边取并集）。
  Future<List<String>> retiredKeys(String agentId) async {
    final id = agentId.trim();
    if (id.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_retiredPrefix$id') ?? const [];
  }

  /// **撕掉接缝行**：只有一种合法场景 —— 本机把身份交出去之后的擦除
  /// （`DeviceMigrationService` 收到验签通过的 `ack(ok:true)` 之后）。
  ///
  /// 它**不是**改绑，所以刻意不走 [bindSeam]：改绑是"换个值"，擦除是
  /// "我从此不再是这个身份"。两者混淆会让"换钥必先留痕"看起来只是权限变松。
  ///
  /// ★ 刻意**保留** [retiredKeys] 里那份清单：里面只有**公钥**，不含任何私钥，
  ///   是"这台机器曾经是谁"的历史证据；留着它不构成任何签名能力。
  Future<void> dropSeam(String agentId) async {
    final id = agentId.trim();
    if (id.isEmpty) return;
    final db = await DBHelper.db;
    await db.delete('agent_pubkeys', where: 'agent_id = ?', whereArgs: [id]);
    DBHelper.dataRevision++;
  }

  /// 清掉**身份锚**（[identityRootDid] 的落盘值）。
  ///
  /// 只在"本机已经不再是那个身份"时调用 —— 留着它，界面会把**别人的**身份锚
  /// 当成"我的"，而那个锚指向的私钥早已不在本机（显示得越像真的越有害）。
  Future<void> clearRootDid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rootDidKey);
  }

  /// 用设备身份私钥对任意字节签名（base64）。本地通道 HELLO 等场景使用。
  Future<String> signBase64(List<int> message) async {
    final sig = await _algo.sign(message, keyPair: await getOrCreateKeyPair());
    return base64Encode(sig.bytes);
  }

  /// 按当前生效算法构造 Hub 信封（Cloud/World 通道统一入口）
  Future<Map<String, dynamic>> buildHubEnvelope({
    required String fromId,
    required String toId,
    required Map<String, dynamic> payload,
  }) async {
    if (await activeAlg() == 'ed25519') {
      return AgentProtocol.buildEd25519Envelope(
        fromId: fromId,
        toId: toId,
        payload: payload,
        keyPair: await getOrCreateKeyPair(),
      );
    }
    return AgentProtocol.buildEnvelope(
      fromId: fromId,
      toId: toId,
      payload: payload,
      secret: await DBHelper.getOrCreateDeviceSecret(),
    );
  }

  // ---------- hex ----------

  static String _hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _hexDecode(String hex) {
    final out = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  /// 测试辅助：注入固定种子，使公钥/签名可复现
  static Future<void> debugInjectSeedForTest(List<int> seed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seedKey, _hexEncode(seed));
    _instance._cachedKeyPair = null;
    _instance._cachedPubB58 = null;
  }
}
