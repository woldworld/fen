import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'agent_identity.dart';
import 'agent_protocol.dart';
import 'app_events.dart';
import 'app_logger.dart';
import 'db_helper.dart';
import 'identity_rotation.dart';
import 'l10n_holder.dart';
import 'reputation_network.dart';
import 'rotation_chain.dart';

/// `POST /api/identity/rotate` 的结果。
///
/// ★ 失败时给的是**语言无关的错误码**（`not_current_key` / `bad_signature` /
/// `stale_rotation` / `hub_not_configured` / `network_error`）—— UI 负责翻译成文案。
/// 用一个码而不是一句中文，是因为这些码要能被日志、测试与将来的多语言共用。
class HubRotateResult {
  final bool ok;

  /// 失败原因码（成功时为 null）。
  final String? code;

  /// 成功时服务端回报的**身份锚**（换钥不改变它）。
  final String? did;

  /// 成功时服务端回报的**活跃公钥**（= 新公钥）。
  final String? pubkey;

  const HubRotateResult({required this.ok, this.code, this.did, this.pubkey});

  @override
  String toString() =>
      ok ? 'HubRotateResult(ok, did=$did)' : 'HubRotateResult(fail, code=$code)';
}

/// `GET /api/reputation/<pub>` 的结果 —— **Hub 只回原始记录，判断留给读者**。
///
/// ★ 这里刻意**不解析**任何"Hub 判定这份背书有效"的字段：验签由
/// [ReputationGraph.verifyEndorsement] 在本地做（`reputationNetwork.endorse` 会走）。
/// [aliasKeys] 同理只是 Hub 自报的展开范围，读者可用 `RotationChain.keysOf` 复算核对。
class HubReputationView {
  final List<Endorsement> endorsements;
  final List<EndorsementRevocation> revoked;

  /// Hub 按换钥链展开出的公钥集合（含查询的那把）。**仅作对照**。
  final Set<String> aliasKeys;

  /// Hub 自报的展开状态（[AliasStatus] 之一）。**仅作对照**。
  final String aliasStatus;

  const HubReputationView({
    required this.endorsements,
    required this.revoked,
    this.aliasKeys = const {},
    this.aliasStatus = AliasStatus.noChain,
  });
}

/// 云端 Hub 中继：HTTPS + 请求签名 + 游标幂等。
/// 消息以 pocketagent/1 信封发送；Hub 仅作中继，不参与业务决策。
class CloudService {
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  /// 最近一次 A2A 发现操作的失败原因（供 UI 展示；成功时为 null）
  String? lastError;

  /// prefs 键：中转站访问 Key（ADR-002）。
  ///
  /// ★ 为什么是一个**可有可无**的键：自建 / 局域网中转站不需要 Key（`HUB_REGISTRATION=open`），
  ///   官方站才需要。留空 = 什么都不带 ⇒ 自建用户的行为与以前逐字节一致。
  ///
  /// ★ 显式写 `String` 而不靠类型推断：`tool/verify_data_keys.dart` 的常量表只认
  ///   `const String name = '…'`。省掉 `String` 时该键会被判成"动态键"，
  ///   逼人去 `_expectedDynamic` 里登记 —— 那是**放宽**守卫；补上类型则是**收紧**：
  ///   这个键从此必须满足"有读必有写"。
  static const String prefsHubAccessKey = 'cloud_hub_key';

  /// 最近一次注册失败的**服务端错误码**（成功时为 null）。
  ///
  /// ★ 为什么必须有它：`/api/register` 的 `403` 有两种含义 ——
  ///   `identity_conflict`（该 ID 上绑的是**别的**公钥，处置是走身份恢复/换钥）
  ///   与准入类拒绝（`registration_key_required` / `key_invalid` / `key_revoked`，
  ///   处置是去要 Key）。**只判 HTTP 状态会把这两种完全相反的处置混成一锅**：
  ///   对着"缺 Key"的提示去恢复身份，或者反过来拿旧钥去撞换钥端点。
  String? lastRegisterErrorCode;

  /// 读取 Hub 地址。未配置时返回空串——调用方必须早退，
  /// 绝不能拿占位域名发请求（那只会制造无意义的 DNS 空转）。
  Future<String> _getHubUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = (prefs.getString('cloud_hub_url') ?? '').trim();
    if (url.isEmpty) return '';
    // 公网强制 HTTPS；本机/模拟器调试与局域网私有网段允许显式 http
    // （与 world_service / god_service 同策略：Hub 也可以跑在自家电脑上）
    if (url.startsWith('http://')) {
      final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
      final isPrivate = _privateHost.hasMatch(host);
      if (!isPrivate) {
        AppLogger.w('cloud.url', '非 HTTPS 且非私有网段的 Hub 地址已被拒绝: $url');
        return '';
      }
    }
    return url;
  }

  // 私有网段判断：192.168.x / 10.x / 172.16-31.x / 127.x / localhost
  static final RegExp _privateHost = RegExp(
      r'^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.|localhost$)');

  /// 注册到 Hub（含 Ed25519 升级链路）：
  /// 1) 优先 Ed25519 公钥注册（新 Hub 直接接受，私钥不出设备）；
  /// 2) 被拒（旧版 Hub / 存量 HMAC 身份）则回退"旧共享密钥签名 + 携带公钥"的迁移注册；
  /// 3) Hub 响应确认公钥已绑定（alg=ed25519）后，后续请求全部切换 Ed25519。
  Future<bool> registerAgent(
      String myAgentId, String nickname, String maskProfile) async {
    lastRegisterErrorCode = null;
    final hubUrl = await _getHubUrl();
    if (hubUrl.isEmpty) {
      lastError = L10nHolder.l10n.cloudHubNotConfigured;
      lastRegisterErrorCode = 'hub_not_configured';
      return false;
    }

    // 访问 Key（可选）：只有用户填了才进 payload。
    // ★ 不塞空串是刻意的 —— 空字段会改变信封内容，让"自建站的老请求"与
    //   历史签名串不一致，回归时很难看出是哪一轮引入的差异。
    final prefs = await SharedPreferences.getInstance();
    final accessKey = (prefs.getString(prefsHubAccessKey) ?? '').trim();

    // 1) Ed25519 公钥注册
    final edStatus = await _registerWith(
      hubUrl,
      myAgentId,
      nickname,
      maskProfile,
      () async {
        final identity = AgentIdentity();
        final payload = <String, dynamic>{
          'agent_id': myAgentId,
          'nickname': nickname,
          'mask_profile': maskProfile,
          'pubkey': await identity.publicKeyBase58(),
          'did': await identity.did(),
          if (accessKey.isNotEmpty) 'key': accessKey,
        };
        return AgentProtocol.buildEd25519Envelope(
          fromId: myAgentId,
          toId: 'hub',
          payload: payload,
          keyPair: await identity.getOrCreateKeyPair(),
        );
      },
    );
    if (edStatus == HttpStatus.ok) return true;

    // ★ 准入类拒绝不该再走 HMAC 回退：Key 就是 Key，换一种签名算法也不会变有效；
    //   而且回退会让服务端多收一条注定失败的请求（日志里看起来像"客户端在乱撞"）。
    if (_isAdmissionRejection(lastRegisterErrorCode)) return false;

    // 2) 回退：旧共享密钥签名 + 携带公钥（存量身份迁移 / 旧版 Hub 兼容）。
    //    旧版 Hub 会忽略 pubkey 按原样注册；新版 Hub 则借此完成公钥绑定。
    final fallbackStatus = await _registerWith(
      hubUrl,
      myAgentId,
      nickname,
      maskProfile,
      () async {
        final secret = await DBHelper.getOrCreateDeviceSecret();
        final payload = <String, dynamic>{
          'agent_id': myAgentId,
          'nickname': nickname,
          'mask_profile': maskProfile,
          'secret': secret,
          'pubkey': await AgentIdentity().publicKeyBase58(),
          if (accessKey.isNotEmpty) 'key': accessKey,
        };
        return AgentProtocol.buildEnvelope(
          fromId: myAgentId,
          toId: 'hub',
          payload: payload,
          secret: secret,
        );
      },
    );
    return fallbackStatus == HttpStatus.ok;
  }

  /// 最近一次注册失败是否属于**准入**类（Key 的问题）。
  ///
  /// UI 据此决定"拦人"还是"放行"：准入类必须当场让用户改对（否则他会在几小时后
  /// 才发现社交发不出去）；网络类不拦（不能因为对方服务器一时不通就让人存不了设置）。
  bool get lastRegisterWasAdmissionRejection =>
      _isAdmissionRejection(lastRegisterErrorCode);

  /// 这些码表示"票的问题"，换签名算法再来一次毫无意义。
  static bool _isAdmissionRejection(String? code) {
    switch (code) {
      case 'registration_key_required':
      case 'key_invalid':
      case 'key_revoked':
      case 'key_already_bound':
      case 'agent_revoked':
      case 'registration_closed':
        return true;
      default:
        return false;
    }
  }

  /// 把注册失败码翻成人话（null = 无错误可展示）。
  ///
  /// ★ 未知码也要有兜底：服务端将来加一个新码时，用户不该看到空白提示。
  String? get lastRegisterErrorText {
    final code = lastRegisterErrorCode;
    if (code == null) return null;
    final l = L10nHolder.l10n;
    switch (code) {
      case 'registration_key_required':
        return l.cloudKeyRequired;
      case 'key_invalid':
        return l.cloudKeyInvalid;
      case 'key_revoked':
        return l.cloudKeyRevoked;
      case 'key_already_bound':
        return l.cloudKeyBound;
      case 'agent_revoked':
        return l.cloudAgentRevoked;
      case 'registration_closed':
        return l.cloudRegisterClosed;
      case 'identity_conflict':
        // 这条不是准入问题：该 ID 上绑的是别的公钥，处置是身份恢复/换钥。
        return l.cloudRegisterIdentityConflict;
      default:
        return l.cloudNetworkError(code);
    }
  }

  /// 执行一次注册请求，返回 HTTP 状态码；Hub 确认公钥绑定时持久化算法偏好
  Future<int> _registerWith(
    String hubUrl,
    String myAgentId,
    String nickname,
    String maskProfile,
    Future<Map<String, dynamic>> Function() buildEnvelope,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final envelope = await buildEnvelope();
      final uri = Uri.parse("$hubUrl/api/register");
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(envelope));
      final response = await request.close();
      final status = response.statusCode;
      // ★ 无论成功失败都先把 body 读出来：失败时 `error` 字段才是**唯一的**分流依据
      //   （403 在注册端点有两种含义，见 `lastRegisterErrorCode` 的注释）。
      final body = await response.transform(utf8.decoder).join();
      if (status != HttpStatus.ok) {
        String? code;
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            code = decoded['error']?.toString();
          }
        } catch (_) {}
        lastRegisterErrorCode = code ?? 'http_$status';
        // 403 identity_conflict：该 agent_id 在 Hub 上已绑定了**别的**公钥。
        // ⚠️ 它不是"换机/重装"的信号 —— 重装会生成一个**新的随机 AG- ID**，不会撞上。
        //    真正会撞上的是：本机换了把私钥（恢复/导入了另一份身份）却仍顶着旧 ID。
        //    正确处置是走 `POST /api/identity/rotate`（旧钥签名换钥），**不是**删身份 ——
        //    删身份会连 §16 留痕与背书一起丢掉（见 lib/身份可携带与恢复方案.md）。
        AppLogger.w(
          'cloud.register',
          'Hub 注册被拒($status) code=$lastRegisterErrorCode。'
          '403 identity_conflict 表示该 ID 上绑的是别的公钥：请走"身份恢复/换钥"，不要删身份。',
        );
        return status;
      }
      try {
        final alg = jsonDecode(body)['alg']?.toString();
        if (alg == AgentProtocol.algEd25519) {
          await AgentIdentity().markEd25519Active();
        }
      } catch (_) {}
      return status;
    } catch (e) {
      AppLogger.w('cloud.register', e);
      return -1;
    } finally {
      client.close();
    }
  }

  /// 身份换钥（"随人不随设备"）—— 把本机的活跃钥在 Hub 上改绑到新公钥。
  ///
  /// 交给 Hub 的就是那条由**旧钥**签好的 ROTATE 声明（见 `identity_rotation.dart`）：
  /// 服务端只做"验旧钥签名 → 改绑"，**它无法代签、也无法替用户恢复**。
  ///
  /// ★ 调用方必须**拿到 ok 之后**才执行 `RestorePlan.apply()`
  ///   （`identity_recovery.dart` 的流程 ③→④）。反过来会让新机握着一把没人认的钥匙。
  Future<HubRotateResult> rotateIdentity(IdentityRotation rotation) async {
    final hubUrl = await _getHubUrl();
    if (hubUrl.isEmpty) {
      lastError = L10nHolder.l10n.cloudHubNotConfigured;
      return const HubRotateResult(ok: false, code: 'hub_not_configured');
    }
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('$hubUrl/api/identity/rotate');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(rotation.toMap()));
      final response = await request.close();
      final status = response.statusCode;
      final body = await response.transform(utf8.decoder).join();
      Map<String, dynamic> json = const {};
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}
      if (status == HttpStatus.ok && json['ok'] == true) {
        return HubRotateResult(
          ok: true,
          did: json['did']?.toString(),
          pubkey: json['pubkey']?.toString(),
        );
      }
      final code = json['error']?.toString() ?? 'http_$status';
      AppLogger.w('cloud.rotate', '换钥被拒($status): $code');
      return HubRotateResult(ok: false, code: code);
    } catch (e) {
      AppLogger.w('cloud.rotate', e);
      return const HubRotateResult(ok: false, code: 'network_error');
    } finally {
      client.close();
    }
  }

  /// 读取某身份的**换钥链**（`GET /api/identity/rotations`）。
  ///
  /// ★ 这是**匿名公开读**——刻意不签名、不要求已注册。
  /// 理由：换钥链的意义就是"**任何人都能独立复核**"。若要求凭注册身份才能读，
  /// "可验证"就退化成"只有圈内人看得见"，第三方面对的是一个打不开的黑箱。
  /// 端点因此不校验 `X-Agent-Sig`（由 `tool/verify_identity_rotation.js` 静态钉住）。
  ///
  /// ⚠️ **Hub 不自证**：它只回原始记录（含 `sig`）。签名有效性与链的拼接
  /// 由 [RotationChain] 在**本地**复算（`verifySignatures` / `verifyLinks`）。
  ///
  /// [agentId] 与 [did] 二者传其一即可（`did` 是身份锚、换钥不改它）；
  /// 都为空时返回 Hub 全量换钥记录（受端点自身的截断策略约束）。
  Future<RotationChain?> fetchIdentityRotations({
    String? agentId,
    String? did,
  }) async {
    final hubUrl = await _getHubUrl();
    if (hubUrl.isEmpty) {
      lastError = L10nHolder.l10n.cloudHubNotConfigured;
      return null;
    }
    final params = <String, String>{};
    if (agentId != null && agentId.trim().isNotEmpty) {
      params['agent_id'] = agentId.trim();
    }
    if (did != null && did.trim().isNotEmpty) {
      params['did'] = did.trim();
    }
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse('$hubUrl/api/identity/rotations')
          .replace(queryParameters: params.isEmpty ? null : params);
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        lastError = L10nHolder.l10n.cloudRosterFailed(response.statusCode, body);
        AppLogger.w('cloud.rotations',
            '换钥链读取失败(${response.statusCode})');
        return null;
      }
      final chain = RotationChain.tryParse(jsonDecode(body));
      if (chain == null) {
        lastError = L10nHolder.l10n.cloudNetworkError('bad_payload');
        AppLogger.w('cloud.rotations', '换钥链回复形状异常，已按不可信丢弃');
        return null;
      }
      lastError = null;
      return chain;
    } catch (e) {
      lastError = L10nHolder.l10n.cloudNetworkError('$e');
      AppLogger.w('cloud.rotations', e);
      return null;
    } finally {
      client.close();
    }
  }

  /// 读取某主体收到的**全部背书 + 吊销**（`GET /api/reputation/<pub>`，需签名）。
  ///
  /// ---------------------------------------------------------------------------
  /// 为什么需要它（缺口的另一半）
  /// ---------------------------------------------------------------------------
  /// 换机恢复后的新机是**一块干净的盘**：收到的背书此前只落在旧机的本地库里，
  /// 本地一条都没有。所以即使 Hub 侧已经按换钥链把履历归并到了新钥名下，
  /// 没有拉取这一步，新机的护照页**照样是一片空白** —— 用户的感受仍然是"履历没了"。
  ///
  /// [subjectPub] 传**当前活跃钥**即可：Hub 会顺着换钥链把历史钥上一并取来
  /// （见 `/api/reputation/<subject>` 的别名展开）。读到之后必须**逐条本地验签**
  /// 再落库（`reputationNetwork.endorse`），绝不能因为"是 Hub 给的"就免检。
  ///
  /// fail-closed：形状不对（`endorsements` 不是数组、元素不是对象）⇒ 返回 null，
  /// **半信半疑地落一半**比不落更坏（本地会留下一份"看起来完整"的残缺履历）。
  Future<HubReputationView?> fetchReputation({
    required String myAgentId,
    required String subjectPub,
  }) async {
    final subject = subjectPub.trim();
    if (myAgentId.trim().isEmpty || subject.isEmpty) return null;
    final hubUrl = await _getHubUrl();
    if (hubUrl.isEmpty) {
      lastError = L10nHolder.l10n.cloudHubNotConfigured;
      return null;
    }
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final sigEnv = await AgentIdentity().buildHubEnvelope(
        fromId: myAgentId,
        toId: 'hub',
        payload: {'reputation_of': subject},
      );
      final sigHeader = base64UrlEncode(utf8.encode(jsonEncode(sigEnv)));
      final uri = Uri.parse('$hubUrl/api/reputation/${Uri.encodeComponent(subject)}');
      final request = await client.getUrl(uri);
      request.headers.set('X-Agent-Sig', sigHeader);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        lastError = L10nHolder.l10n.cloudRosterFailed(response.statusCode, body);
        AppLogger.w('cloud.reputation', '背书读取失败(${response.statusCode})');
        return null;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        lastError = L10nHolder.l10n.cloudNetworkError('bad_payload');
        return null;
      }
      final rawList = decoded['endorsements'];
      if (rawList is! List) {
        lastError = L10nHolder.l10n.cloudNetworkError('bad_payload');
        AppLogger.w('cloud.reputation', '回复缺少 endorsements 数组，已按不可信丢弃');
        return null;
      }
      final endorsements = <Endorsement>[];
      for (final e in rawList) {
        if (e is! Map) {
          lastError = L10nHolder.l10n.cloudNetworkError('bad_payload');
          return null;
        }
        endorsements.add(Endorsement.fromMap(Map<String, dynamic>.from(e)));
      }
      final revoked = <EndorsementRevocation>[];
      final rawRevoked = decoded['revoked'];
      if (rawRevoked is List) {
        for (final r in rawRevoked) {
          if (r is! Map) continue; // 吊销条目坏掉不该拖垮整份履历（它只会让更少人看到）
          revoked.add(
              EndorsementRevocation.fromMap(Map<String, dynamic>.from(r)));
        }
      }
      final aliasKeys = <String>{};
      var aliasStatus = AliasStatus.noChain;
      final rawAlias = decoded['alias'];
      if (rawAlias is Map) {
        aliasStatus = (rawAlias['status'] ?? AliasStatus.noChain).toString();
        final rawKeys = rawAlias['keys'];
        if (rawKeys is List) {
          for (final k in rawKeys) {
            final s = k.toString();
            if (s.isNotEmpty) aliasKeys.add(s);
          }
        }
      }
      lastError = null;
      return HubReputationView(
        endorsements: endorsements,
        revoked: revoked,
        aliasKeys: aliasKeys,
        aliasStatus: aliasStatus,
      );
    } catch (e) {
      lastError = L10nHolder.l10n.cloudNetworkError('$e');
      AppLogger.w('cloud.reputation', e);
      return null;
    } finally {
      client.close();
    }
  }

  /// 拉取邮箱：带游标（after=lastId），只处理新消息，避免重复触发 LLM。
  Future<void> pullMailbox(String myAgentId) async {
    final hubUrl = await _getHubUrl();
    if (hubUrl.isEmpty) return; // 未配置 Hub：心跳里静默早退
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final prefs = await SharedPreferences.getInstance();
      // ★ 读前 reload：legacy SharedPreferences 每 isolate 缓存且永不自动
      //   刷新——后台值班心跳推进的光标，主 isolate 的缓存里看不见。不
      //   reload 就会用陈旧光标重拉整批已回复的消息 → 对端收到双份回复。
      await prefs.reload();
      final cursorKey = 'cloud_cursor_$myAgentId';
      final cursor = prefs.getInt(cursorKey) ?? 0;

      final uri = Uri.parse("$hubUrl/api/mailbox?agent_id=$myAgentId&after=$cursor");
      final request = await client.getUrl(uri);
      final sigEnv = await AgentIdentity().buildHubEnvelope(
        fromId: myAgentId,
        toId: 'hub',
        payload: {'cursor': cursor},
      );
      // 完整信封（base64url）放入头，Hub 可验签 + 校验时间窗
      final sigHeader =
          base64UrlEncode(utf8.encode(jsonEncode(sigEnv)));
      request.headers.set('X-Agent-Sig', sigHeader);
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final String body = await response.transform(utf8.decoder).join();
        final List<dynamic> messages = jsonDecode(body);
        int maxId = cursor;
        for (var msg in messages) {
          final id = (msg['id'] as num?)?.toInt() ?? 0;
          if (id <= cursor) continue;
          final senderId = msg['sender_id'] ?? 'Unknown';
          final senderNickname = msg['nickname'] ?? '云端匿名Agent';
          final message = msg['message'] ?? '';
          final maskProfile = msg['mask_profile'] ?? '神秘人设';
          final avatar = msg['avatar'] ?? '☁️';

          // 仅把云端飘来的节点录入名册
          await DBHelper.insertAgentFriend(senderNickname, "云端Hub发现", senderId, "stranger", "跨国 Cloud 握手", maskProfile, avatar);

          // 交给事件总线，由 AgentService 统一做安全审查与决策
          AppEvents.emit(SocialMessageReceivedEvent(
            senderAgentId: senderId,
            message: message,
            channel: 'cloud',
            sourceMsgId: id.toString(),
          ));
          if (id > maxId) maxId = id;
        }
        if (maxId > cursor) {
          await prefs.setInt(cursorKey, maxId);
        }
      }
    } catch (e) {
      AppLogger.w('cloud.pull', e);
    } finally {
      client.close();
    }
  }

  /// A2A 联邦名册：Hub 上全部注册 Agent（仅凭注册身份可见，不公开匿名爬取）
  Future<List<Map<String, dynamic>>> fetchA2aRoster(String myAgentId) async {
    final hubUrl = await _getHubUrl();
    if (hubUrl.isEmpty) {
      lastError = L10nHolder.l10n.cloudHubNotConfigured;
      return const [];
    }
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final sigEnv = await AgentIdentity().buildHubEnvelope(
        fromId: myAgentId,
        toId: 'hub',
        payload: {'roster': true},
      );
      final sigHeader = base64UrlEncode(utf8.encode(jsonEncode(sigEnv)));
      final uri = Uri.parse("$hubUrl/api/a2a/agents");
      final request = await client.getUrl(uri);
      request.headers.set('X-Agent-Sig', sigHeader);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        final body = await response.transform(utf8.decoder).join();
        lastError = L10nHolder.l10n.cloudRosterFailed(response.statusCode, body);
        AppLogger.w('cloud.roster', '名册获取失败(${response.statusCode})');
        return const [];
      }
      final body = await response.transform(utf8.decoder).join();
      final List<dynamic> agents = (jsonDecode(body)['agents'] as List?) ?? const [];
      lastError = null;
      return agents.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      lastError = L10nHolder.l10n.cloudNetworkError('$e');
      AppLogger.w('cloud.roster', e);
      return const [];
    } finally {
      client.close();
    }
  }

  /// A2A Agent Card：目标 Agent 的公开名片（name/description/capabilities，不含密钥）
  Future<Map<String, dynamic>?> fetchA2aCard(String myAgentId, String targetAgentId) async {
    final hubUrl = await _getHubUrl();
    if (hubUrl.isEmpty) {
      lastError = L10nHolder.l10n.cloudHubNotConfigured;
      return null;
    }
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final sigEnv = await AgentIdentity().buildHubEnvelope(
        fromId: myAgentId,
        toId: 'hub',
        payload: {'card_of': targetAgentId},
      );
      final sigHeader = base64UrlEncode(utf8.encode(jsonEncode(sigEnv)));
      final uri = Uri.parse("$hubUrl/api/a2a/card/$targetAgentId");
      final request = await client.getUrl(uri);
      request.headers.set('X-Agent-Sig', sigHeader);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        lastError = L10nHolder.l10n.cloudCardFailed(response.statusCode);
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      lastError = null;
      return Map<String, dynamic>.from(jsonDecode(body));
    } catch (e) {
      lastError = L10nHolder.l10n.cloudNetworkError('$e');
      AppLogger.w('cloud.card', e);
      return null;
    } finally {
      client.close();
    }
  }

  Future<bool> sendCloudMessage(
      String targetAgentId, String message, String myAgentId) async {
    final hubUrl = await _getHubUrl();
    if (hubUrl.isEmpty) {
      lastError = L10nHolder.l10n.cloudHubNotConfigured;
      return false;
    }
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse("$hubUrl/api/send");
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      // 跨设备报文里报出去的**社交身份三件套同源**：都取 ambassador 表。
      //
      // 曾经这里 nickname/mask_profile 读 prefs、avatar 读 ambassador ——
      // 同一个 payload 两个来源，必然漂移；而且其中 `prefs['soul_mask_profile']`
      // **全项目没有任何写入方**，于是发给 Hub 的马甲永远是兜底值"保密"，
      // 而社交页里设置的马甲（写的是 ambassador `mask_profile`）根本传不出去。
      // 这类"读了一个没人写的键"的缺陷由 `tool/verify_data_keys.dart` 静态守卫。
      final nickname = await DBHelper.getAmbassador('nickname') ?? '超级管家';
      final maskProfile = await DBHelper.getAmbassador('mask_profile') ?? '保密';
      final avatar = await DBHelper.getAmbassador('avatar') ?? '🤖';

      final envelope = await AgentIdentity().buildHubEnvelope(
        fromId: myAgentId,
        toId: targetAgentId,
        payload: {
          'sender_id': myAgentId,
          'nickname': nickname,
          'mask_profile': maskProfile,
          'avatar': avatar,
          'target_id': targetAgentId,
          'message': message,
        },
      );
      request.write(jsonEncode(envelope));
      final response = await request.close();
      return response.statusCode == HttpStatus.ok;
    } catch (e) {
      AppLogger.w('cloud.send', e);
      return false;
    } finally {
      client.close();
    }
  }
}
