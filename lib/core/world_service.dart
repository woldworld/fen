import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'agent_identity.dart';
import 'app_events.dart';
import 'app_logger.dart';
import 'l10n_holder.dart';
import 'world_retry_policy.dart';
import 'world_send_gate.dart';

/// 世界服务器（会客厅）客户端：HTTPS + 请求签名 + 全局游标。
/// 与 CloudService 同构：world-server 复用 Hub 注册库验签，App 无需二次注册。
/// 入站房间消息只发事件（WorldRoomMessageEvent），由 AgentService 统一观察/决策。
class WorldService {
  static final WorldService _instance = WorldService._internal();
  factory WorldService() => _instance;
  WorldService._internal();

  String? lastError;
  /// 服务端返回的机器可读错误码（如 `need_approval` / `my_rooms_full` / `room_full`）。
  /// ★ 为什么不能只靠 `lastError` 文案：文案是给人看的、会被本地化；
  ///   UI 要"把按钮从『加入』切成『申请加入』"就必须有一个稳定的码。
  String? lastErrorCode;

  bool _pulling = false;
  // 房间元数据与最近消息缓存（供日志命名、房间页展示与托管发言的上下文）
  final Map<String, String> _roomNames = {};
  final Map<String, List<Map<String, dynamic>>> _roomCache = {};
  final Map<String, String?> _nextSpeakers = {};
  /// 已被房主**手动关闭**（只读留档）的房间 id。来源两处：feed 的 `closed_rooms`、
  /// /room 的 `room.closed` —— 有了它，房间页能在 5s 内自动切成只读，
  /// 托管发言也能提前跳过（而不是反复去撞服务端 403 room_closed）。
  final Set<String> _closedRooms = {};

  /// 会客厅发言的**按房间排队闸**（事前排队 + 同房间串行，见 `WorldSendGate`）。
  /// 只服务 `say` —— 节奏闸只挂在服务端 `/api/world/say` 上。
  final WorldSendGate _sendGate = WorldSendGate();

  // ---------- 房间历史落盘 ----------
  //
  // ★ 为什么要落盘（2026-10-03 真机反馈）：`_roomCache` 此前**纯内存**，App 一被
  //   系统杀进程就整段消失；而 feed 用的是**全局单调游标**（只增），重启后游标早已
  //   越过本房历史消息的 id ⇒ "另一台手机一条历史都没有"。
  //   落盘解决"重启即失"，按房回填端点解决"游标越顶"，两者缺一不可。
  bool _cacheLoaded = false;
  String? _cacheLoadedFor;

  /// 落盘键按 Agent 分开：换身份不该看到上一个人的房间历史。
  String _cacheKey(String myAgentId) => 'world_room_cache_$myAgentId';

  Future<void> loadPersistedCache(String myAgentId) async {
    if (_cacheLoaded && _cacheLoadedFor == myAgentId) return;
    _cacheLoaded = true;
    _cacheLoadedFor = myAgentId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(myAgentId));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final e in decoded.entries) {
        final list = (e.value as List?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (list != null && list.isNotEmpty) {
          _roomCache[e.key.toString()] = list;
        }
      }
    } catch (e) {
      AppLogger.w('world.cache', e);
    }
  }

  int _lastId(List<Map<String, dynamic>> l) =>
      l.isEmpty ? 0 : ((l.last['id'] as num?)?.toInt() ?? 0);

  Future<void> _persistCache(String myAgentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ★ prefs 不是数据库：只留最近 8 个房间 × 每房 100 条（与内存缓存同口径），
      //   否则 world.json 会被整个搬进 SharedPreferences。
      final keys = _roomCache.keys.toList()
        ..sort((a, b) =>
            _lastId(_roomCache[b]!).compareTo(_lastId(_roomCache[a]!)));
      final trimmed = <String, dynamic>{};
      for (final k in keys.take(8)) {
        final l = _roomCache[k]!;
        trimmed[k] = l.length > 100 ? l.sublist(l.length - 100) : l;
      }
      await prefs.setString(_cacheKey(myAgentId), jsonEncode(trimmed));
    } catch (e) {
      AppLogger.w('world.cache', e);
    }
  }

  /// 回填历史入缓存：**按 id 去重后并入并排序**，绝不整段覆盖 ——
  /// 覆盖会把刚收到的新消息冲掉（表现为"历史一拉，最新那条没了"）。
  int _mergeIntoCache(String roomId, List<dynamic> msgs) {
    final cache = _roomCache.putIfAbsent(roomId, () => <Map<String, dynamic>>[]);
    final seen = <int>{
      for (final m in cache) (m['id'] as num?)?.toInt() ?? -1
    };
    var added = 0;
    for (final m in msgs) {
      if (m is! Map) continue;
      final id = (m['id'] as num?)?.toInt() ?? 0;
      if (id <= 0 || seen.contains(id)) continue;
      seen.add(id);
      cache.add(Map<String, dynamic>.from(m));
      added++;
    }
    if (added == 0) return 0;
    cache.sort((a, b) =>
        ((a['id'] as num?)?.toInt() ?? 0).compareTo((b['id'] as num?)?.toInt() ?? 0));
    if (cache.length > 100) cache.removeRange(0, cache.length - 100);
    return added;
  }

  /// 从响应体里取机器可读错误码（取不到就返回 null，UI 只能退回文案）。
  String? _errorCodeOf(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map && d['error'] != null) return d['error'].toString();
    } catch (_) {
      /* 非 JSON 响应（如网关 HTML 错误页）：没有码可用 */
    }
    return null;
  }

  String? roomName(String roomId) => _roomNames[roomId];
  List<Map<String, dynamic>> recentRoomMessages(String roomId) =>
      List.unmodifiable(_roomCache[roomId] ?? const []);
  String? nextSpeakerOf(String roomId) => _nextSpeakers[roomId];

  /// 该房间是否已被房主关闭（只读留档）。**只反映最近一次服务端事实** ——
  /// 客户端不做任何推断，也无法自行关闭它。
  bool isRoomClosed(String roomId) => _closedRooms.contains(roomId);

  // 局域网私有网段：世界服务器也可能跑在自家电脑上（与 god_service 同策略）
  static final RegExp _privateHost =
      RegExp(r'^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.)');

  Future<String> _getWorldUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var url = (prefs.getString('world_hub_url') ?? '').trim();
    if (url.isEmpty) {
      // 未单独配置时，默认走 Hub 同域的 /world 路径（Caddy 同域转发方案）
      final hub = (prefs.getString('cloud_hub_url') ?? '').trim();
      if (hub.isEmpty) {
        lastError = L10nHolder.l10n.worldSvcNoHub;
        return '';
      }
      url = hub.endsWith('/') ? '${hub}world' : '$hub/world';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // 公网强制 HTTPS；本机/模拟器调试与局域网私有网段允许显式 http
    if (url.startsWith('http://')) {
      final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
      final isPrivate = host == '10.0.2.2' ||
          host == 'localhost' ||
          _privateHost.hasMatch(host);
      if (!isPrivate) {
        AppLogger.w('world.url', '非 HTTPS 且非私有网段的世界地址已被拒绝: $url');
        lastError = L10nHolder.l10n.worldSvcMustBeHttps;
        return '';
      }
    }
    lastError = null;
    return url;
  }

  // 签名头：按当前生效算法（Ed25519 / HMAC 兼容回退）构造信封
  Future<String> _sigValue(String myAgentId, Map<String, dynamic> payload) async {
    final env = await AgentIdentity().buildHubEnvelope(
      fromId: myAgentId,
      toId: 'world',
      payload: payload,
    );
    return base64UrlEncode(utf8.encode(jsonEncode(env)));
  }

  /// 房间列表
  Future<List<Map<String, dynamic>>> fetchRooms(String myAgentId) async {
    final url = await _getWorldUrl();
    if (url.isEmpty) return const [];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse("$url/api/world/rooms"));
      request.headers.set('X-Agent-Sig', await _sigValue(myAgentId, const {}));
      final response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        lastError = L10nHolder.l10n
            .worldSvcRoomsFailed('${response.statusCode}', body);
        return const [];
      }
      final List<dynamic> rooms = (jsonDecode(body)['rooms'] as List?) ?? const [];
      final out = rooms.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      for (final r in out) {
        if (r['id'] != null) _roomNames[r['id'].toString()] = r['name']?.toString() ?? '';
      }
      return out;
    } catch (e) {
      AppLogger.w('world.rooms', e);
      lastError = L10nHolder.l10n.commonNetworkError('$e');
      return const [];
    } finally {
      client.close();
    }
  }

  /// 按房间号查询（QQ 群号模式）+ **成员**回填本房最近历史。
  ///
  /// ★ 这个端点是"另一台手机一条历史都没有"的正面解药：feed 用全局单调游标，
  ///   后进房的人游标早已越过本房历史 id ⇒ 永远拉不到；本端点按房间取，不看游标。
  /// ★ 非成员也能查到房间（为了"凭号找到并申请"），但拿不到消息。
  Future<Map<String, dynamic>?> fetchRoom(String myAgentId, String roomId) async {
    final url = await _getWorldUrl();
    if (url.isEmpty) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse(
          "$url/api/world/room?room_id=${Uri.encodeQueryComponent(roomId)}"));
      request.headers.set('X-Agent-Sig', await _sigValue(myAgentId, {'room_id': roomId}));
      final response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        lastErrorCode = _errorCodeOf(body) ?? '${response.statusCode}';
        lastError = L10nHolder.l10n
            .worldSvcRoomsFailed('${response.statusCode}', body);
        return null;
      }
      final data = Map<String, dynamic>.from(jsonDecode(body));
      final room = data['room'];
      if (room is Map) {
        final id = room['id']?.toString();
        if (id != null) {
          _roomNames[id] = room['name']?.toString() ?? '';
          // 关闭状态以服务端为准（每次按房查询都刷新一遍，双向同步）
          if (room['closed'] == true) {
            _closedRooms.add(id);
          } else {
            _closedRooms.remove(id);
          }
        }
      }
      final msgs = (data['messages'] as List?) ?? const [];
      if (msgs.isNotEmpty && _mergeIntoCache(roomId, msgs) > 0) {
        await _persistCache(myAgentId);
      }
      lastErrorCode = null;
      return data;
    } catch (e) {
      AppLogger.w('world.room', e);
      lastError = L10nHolder.l10n.commonNetworkError('$e');
      return null;
    } finally {
      client.close();
    }
  }

  /// 申请加入（个人房）/ 直接加入（官方房，免审批）。
  /// 返回 `'joined'` / `'pending'`；`null` = 失败（原因见 `lastError` + `lastErrorCode`）。
  Future<String?> requestJoin(String myAgentId, String roomId,
      {String note = ''}) async {
    final body = await _postEnvelopeJson(
        myAgentId, '/api/world/request', {'room_id': roomId, 'note': note});
    if (body == null) return null;
    if (body['joined'] == true) return 'joined';
    if (body['pending'] == true) return 'pending';
    return null;
  }

  /// 待审批列表（**房主视角**：服务端只回我名下房间的申请）
  Future<List<Map<String, dynamic>>> fetchJoinRequests(String myAgentId,
      {String? roomId}) async {
    final url = await _getWorldUrl();
    if (url.isEmpty) return const [];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final qs = roomId == null
          ? ''
          : '?room_id=${Uri.encodeQueryComponent(roomId)}';
      final request =
          await client.getUrl(Uri.parse("$url/api/world/requests$qs"));
      request.headers.set('X-Agent-Sig', await _sigValue(myAgentId, const {}));
      final response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        lastErrorCode = _errorCodeOf(body) ?? '${response.statusCode}';
        lastError = L10nHolder.l10n
            .worldSvcRoomsFailed('${response.statusCode}', body);
        return const [];
      }
      final list = (jsonDecode(body)['requests'] as List?) ?? const [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      AppLogger.w('world.requests', e);
      lastError = L10nHolder.l10n.commonNetworkError('$e');
      return const [];
    } finally {
      client.close();
    }
  }

  /// 房主审批：`approve` = 同意并直接入内，`false` = 拒绝并删除申请。
  Future<bool> handleJoinRequest(
      String myAgentId, String roomId, String targetAgentId, bool approve) async {
    final body = await _postEnvelopeJson(myAgentId, '/api/world/handle', {
      'room_id': roomId,
      'agent_id': targetAgentId,
      'action': approve ? 'approve' : 'reject',
    });
    if (body == null) return false;
    return approve ? body['approved'] == true : body['rejected'] == true;
  }

  /// 单次签名 POST 并解析响应体（申请/审批这类"要看回执"的调用用）。
  /// 失败返回 null 并写好 `lastError` / `lastErrorCode`。
  Future<Map<String, dynamic>?> _postEnvelopeJson(
      String myAgentId, String path, Map<String, dynamic> payload) async {
    final url = await _getWorldUrl();
    if (url.isEmpty) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final env = await AgentIdentity().buildHubEnvelope(
        fromId: myAgentId,
        toId: 'world',
        payload: payload,
      );
      final request = await client.postUrl(Uri.parse("$url$path"));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(env));
      final response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        lastErrorCode = _errorCodeOf(body) ?? '${response.statusCode}';
        lastError = L10nHolder.l10n
            .worldSvcOpFailed('${response.statusCode}', body);
        return null;
      }
      lastErrorCode = null;
      lastError = null;
      final d = jsonDecode(body);
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } catch (e) {
      AppLogger.w('world.postjson', e);
      lastError = L10nHolder.l10n.commonNetworkError('$e');
      return null;
    } finally {
      client.close();
    }
  }

  /// 通用签名信封 POST（join/leave/create/close 共用；`say` 走带**房间闸**的那条路）。
  ///
  /// ★ 撞上**限流**（`429`）时，按服务端给的 `retry_after_ms` **退避后重试一次**
  ///   （策略见 `WorldRetryPolicy`）。只重试 `room_too_fast`（同房间节奏闸 —— 一定是
  ///   **暂时的**）；`member_cap` 之类等再久也没用 ⇒ 如实报错。
  Future<bool> _postEnvelope(String myAgentId, String path, Map<String, dynamic> payload) =>
      _deliverWithRetry(myAgentId, path, payload);

  /// 带"一次退避重试"的投递。
  ///
  /// `onSuccess` / `onRetryable` 是留给会客厅**房间闸**的观察点：`say` 借它们把
  /// "这次成功了 / 服务端要求再等多久"记进 `WorldSendGate`，从而让**下一次**发言
  /// 能事前排队（而不是再撞一次 429）。
  Future<bool> _deliverWithRetry(
    String myAgentId,
    String path,
    Map<String, dynamic> payload, {
    void Function()? onSuccess,
    void Function(int retryAfterMs)? onRetryable,
  }) async {
    final first = await _postEnvelopeOnce(myAgentId, path, payload);
    if (first == null) {
      onSuccess?.call();
      return true;
    }
    if (first <= 0) return false; // 不该重试；`lastError` 已写明原因
    onRetryable?.call(first);
    await Future.delayed(Duration(milliseconds: first));
    final second = await _postEnvelopeOnce(myAgentId, path, payload);
    if (second == null) {
      onSuccess?.call();
      return true;
    }
    if (second > 0) onRetryable?.call(second);
    return false;
  }

  /// 单次投递。`null` = 成功；`> 0` = **可重试**，值为服务端要求的等待毫秒；`0` = 不应重试。
  Future<int?> _postEnvelopeOnce(
      String myAgentId, String path, Map<String, dynamic> payload) async {
    final url = await _getWorldUrl();
    if (url.isEmpty) return 0;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final env = await AgentIdentity().buildHubEnvelope(
        fromId: myAgentId,
        toId: 'world',
        payload: payload,
      );
      final request = await client.postUrl(Uri.parse("$url$path"));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(env));
      final response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode == HttpStatus.ok) {
        lastErrorCode = null;
        return null;
      }
      lastError = L10nHolder.l10n
          .worldSvcOpFailed('${response.statusCode}', body);
      lastErrorCode = _errorCodeOf(body) ?? '${response.statusCode}';
      if (response.statusCode == HttpStatus.tooManyRequests) {
        return WorldRetryPolicy.backoffMsFrom429(body);
      }
      return 0;
    } catch (e) {
      AppLogger.w('world.post', e);
      lastError = L10nHolder.l10n.commonNetworkError('$e');
      return 0;
    } finally {
      client.close();
    }
  }

  /// 创建房间（room_id 需匹配 ^[a-z0-9_-]{1,32}$）
  ///
  /// ★ 建房**默认私有**：服务端只把官方房（部署方配置）放进全员可见的列表，
  ///   个人房只能凭房间号找到并申请加入。`visibility` 只是给客户端表达意图，
  ///   是否真的公开由服务端按配置裁定（客户端说了不算）。
  Future<bool> createRoom(String myAgentId, String roomId, String name,
          String topic, String mode) =>
      _postEnvelope(myAgentId, '/api/world/create',
          {'room_id': roomId, 'name': name, 'topic': topic, 'mode': mode});

  Future<bool> joinRoom(String myAgentId, String roomId) =>
      _postEnvelope(myAgentId, '/api/world/join', {'room_id': roomId});

  Future<bool> leaveRoom(String myAgentId, String roomId) =>
      _postEnvelope(myAgentId, '/api/world/leave', {'room_id': roomId});

  /// 房主手动关闭房间（**仅房主**可成功；关闭后转"只读留档"：保留全部消息、
  /// 退出公开列表、拒收新发言）。成功后本地立即标记，不必等下一轮 feed。
  Future<bool> closeRoom(String myAgentId, String roomId) async {
    final ok = await _postEnvelope(myAgentId, '/api/world/close', {'room_id': roomId});
    if (ok) {
      _closedRooms.add(roomId);
      // 房间已关 ⇒ 这个房间的发言不会再发生，闸里的记忆作废（别把冷却留给未来）。
      _sendGate.forget(roomId);
    }
    return ok;
  }

  /// 直接向房间发言（主人手动发言 / 托管发言共用；是否审查由调用方决定）。
  ///
  /// ★ **按房间事前排队**（`WorldSendGate`）：同一房间的两次发言不会重叠，且会先等过
  ///   已知的冷却窗口 —— 三处调用方（托管发言 / 手动触发的分身发言 / 房间页直接发送）
  ///   共用这一个入口，所以排队对它们一律生效。
  ///   服务端在成功时才写 `room.last_msg_at`（`world.js`）⇒ 本地预测只能**减少**碰撞；
  ///   别台设备的发言推动的那部分，仍由 429 的 `retry_after_ms` 兜底。
  Future<bool> say(String myAgentId, String roomId, String message) => _sendGate.run(
        roomId,
        () => _deliverWithRetry(
          myAgentId,
          '/api/world/say',
          {'room_id': roomId, 'message': message},
          onSuccess: () => _sendGate.noteSent(roomId),
          onRetryable: (retryAfterMs) => _sendGate.noteRoomTooFast(roomId, retryAfterMs),
        ),
      );

  /// 拉取房间消息流：全局游标幂等；每条新消息只发事件，不在此做业务决策。
  Future<void> pullFeed(String myAgentId) async {
    final url = await _getWorldUrl();
    if (url.isEmpty || _pulling) return;
    _pulling = true;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final prefs = await SharedPreferences.getInstance();
      await loadPersistedCache(myAgentId);
      final cursorKey = 'world_cursor_$myAgentId';
      final cursor = prefs.getInt(cursorKey) ?? 0;

      final request = await client.getUrl(Uri.parse("$url/api/world/feed?after=$cursor"));
      request.headers.set('X-Agent-Sig', await _sigValue(myAgentId, {'cursor': cursor}));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return;
      final String body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      final List<dynamic> messages = (data['messages'] as List?) ?? const [];

      // 记录各房间下一发言者（turn 模式提示用）
      final next = data['next_speakers'];
      if (next is Map) {
        next.forEach((k, v) => _nextSpeakers[k.toString()] = v?.toString());
      }

      // 记录已关闭（只读留档）的房间。服务端每次都会带上**全量**列表，
      // 故在此整体覆盖（而不是只增）——这样"我已退出/房间已删"的情况也能被清掉。
      // ⚠️ 老服务端没有这个字段时不覆盖：仍以 /room 拿到的状态为准，不至于把
      //    已知的关闭态误清空。
      final closed = data['closed_rooms'];
      if (closed is List) {
        _closedRooms
          ..clear()
          ..addAll(closed.map((e) => e.toString()));
      }

      int maxId = cursor;
      var dirtyCache = false;
      for (var msg in messages) {
        final id = (msg['id'] as num?)?.toInt() ?? 0;
        if (id <= cursor) continue;
        final roomId = msg['room_id']?.toString() ?? '';
        final senderId = msg['sender_id']?.toString() ?? '';
        final nickname =
            msg['nickname']?.toString() ?? L10nHolder.l10n.worldAnonAgent;
        final message = msg['message']?.toString() ?? '';

        // 入房间缓存（房间页展示 + 托管发言的上下文）
        if (roomId.isNotEmpty) {
          final cache = _roomCache.putIfAbsent(roomId, () => []);
          cache.add(Map<String, dynamic>.from(msg));
          if (cache.length > 100) cache.removeRange(0, cache.length - 100);
          dirtyCache = true;
        }

        AppEvents.emit(WorldRoomMessageEvent(
          roomId: roomId,
          senderAgentId: senderId,
          nickname: nickname,
          message: message,
          sourceMsgId: id.toString(),
        ));
        if (id > maxId) maxId = id;
      }
      if (maxId > cursor) {
        await prefs.setInt(cursorKey, maxId);
      }
      // ★ 内存里刚攒下的历史立刻落盘：App 被杀进程后回来，房间页仍看得到上次的内容
      if (dirtyCache) await _persistCache(myAgentId);
    } catch (e) {
      AppLogger.w('world.pull', e);
    } finally {
      client.close();
      _pulling = false;
    }
  }

  /// 世界日报（date 为空则取当天 UTC）
  Future<Map<String, dynamic>?> fetchReport(String myAgentId, {String? date}) async {
    final url = await _getWorldUrl();
    if (url.isEmpty) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final qs = date == null ? '' : '?date=$date';
      final request = await client.getUrl(Uri.parse("$url/api/world/report$qs"));
      request.headers.set('X-Agent-Sig', await _sigValue(myAgentId, const {}));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        lastError = L10nHolder.l10n
            .worldSvcReportFailed('${response.statusCode}');
        return null;
      }
      final String body = await response.transform(utf8.decoder).join();
      return Map<String, dynamic>.from(jsonDecode(body));
    } catch (e) {
      AppLogger.w('world.report', e);
      lastError = L10nHolder.l10n.commonNetworkError('$e');
      return null;
    } finally {
      client.close();
    }
  }
}
