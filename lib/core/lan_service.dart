import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:nsd/nsd.dart';
import 'app_events.dart';
import 'app_logger.dart';
import 'db_helper.dart';
import 'l10n_holder.dart';
import 'p2p_service.dart';
import 'reputation_service.dart';
import 'session_crypto.dart';

/// 局域网物理节点坐标与活跃度
class _LanNode {
  final String ip;
  int tcpPort;
  int lastSeen;
  _LanNode({required this.ip, required this.tcpPort, required this.lastSeen});
}

/// 局域网引擎：TCP + mDNS + UDP 心跳。
/// 安全改进：BEACON 只广播公开信息；聊天消息走每会话加密（HELLO 交换后 AES-GCM）。
class LanService {
  static final LanService _instance = LanService._internal();
  factory LanService() => _instance;
  LanService._internal();

  HttpServer? _localServer;
  Registration? _registration;
  Discovery? _discovery;

  RawDatagramSocket? _udpSocket;
  Timer? _udpBeaconTimer;
  Timer? _cleanupTimer;

  bool isSearching = false;
  final List<Function()> listeners = [];

  void _notifyListeners() {
    for (var listener in listeners) listener();
  }

  final Map<String, _LanNode> _lanNodes = {};
  List<String> get connectedLanAgents => _lanNodes.keys.toList();

  // 本机身份与本次会话握手报文：BEACON 广播与"发现新节点即握手"共用同一份
  String? _myId;
  String? _myHello;

  Future<void> startLanEngine(String myAgentId, String myNickname) async {
    try {
      // 一次性生成本次会话握手报文（签名绑定本机 agentId，防重放冒名）
      final hello = await SessionCrypto.instance.buildHello(myAgentId);
      _myId = myAgentId;
      _myHello = hello;

      // ========== 引擎 A：TCP + mDNS ==========
      _localServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      final int tcpPort = _localServer!.port;

      _localServer!.listen((HttpRequest request) async {
        if (request.uri.path == '/mcp_p2p' && request.method == 'POST') {
          try {
            final String rawBody = await utf8.decoder.bind(request).join();
            final outer = jsonDecode(rawBody) as Map<String, dynamic>;
            final senderId = outer['sender_id'] as String? ?? '';
            if (senderId.isEmpty) return;

            // ① 明文 HELLO：只携带公钥 + 身份签名（公钥本非机密，只需防篡改/防重放）
            final helloStr = outer['hello'] as String?;
            if (helloStr != null) {
              await _onHello(senderId, helloStr);
              return;
            }

            // ② 会话加密业务报文：未建会话即丢弃（fail-closed，绝不回退明文/静态密钥）
            final bodyEnc = outer['body'] as String?;
            if (bodyEnc == null) return;
            final bodyJson = SessionCrypto.instance.decryptFrom(senderId, bodyEnc);
            if (bodyJson == null) return;
            final data = jsonDecode(bodyJson);

            if (senderId == myAgentId) return;
            final message = data['message'];
            final senderNickname = data['nickname'] ?? '邻居Agent';
            final avatar = data['avatar'] ?? '🤖';
            final senderIp = request.connectionInfo?.remoteAddress.address ?? '';

            _updateNode(senderId, senderIp, data['port'] as int? ?? 0, senderNickname, avatar);
            AppEvents.emit(SocialMessageReceivedEvent(
              senderAgentId: senderId,
              message: message,
              channel: 'lan',
            ));
          } catch (e) {
            AppLogger.w('lan.tcp', e);
          }
        }
        request.response.statusCode = HttpStatus.ok;
        request.response.close();
      });

      _registration = await register(Service(
        name: '$myAgentId-$myNickname',
        // 品牌置换（2026-09-26）：服务类型随之更名。
        // ⚠️ 新旧版本互不可见——两端必须同时更新。
        type: '_wold._tcp',
        port: tcpPort,
        txt: {
          'agent_id': Uint8List.fromList(utf8.encode(myAgentId)),
          'nickname': Uint8List.fromList(utf8.encode(myNickname)),
          'port': Uint8List.fromList(utf8.encode(tcpPort.toString())),
        },
      ));

      _discovery = await startDiscovery('_wold._tcp');
      _discovery!.addListener(() {
        for (var service in _discovery!.services) {
          final name = service.name ?? '';
          if (!name.contains('-')) continue;

          final ip = service.addresses?.isNotEmpty == true
              ? service.addresses!.first.address
              : null;
          final agentIdBytes = service.txt?['agent_id'];
          final nicknameBytes = service.txt?['nickname'];
          final portBytes = service.txt?['port'];

          if (ip != null && portBytes != null && agentIdBytes != null) {
            final agentId = utf8.decode(agentIdBytes);
            if (agentId == myAgentId) continue;

            final nickname =
                nicknameBytes != null ? utf8.decode(nicknameBytes) : '局域网Agent';
            final int portVal = int.parse(utf8.decode(portBytes));
            _updateNode(agentId, ip, portVal, nickname, '🤖');
          }
        }
      });

      // ========== 引擎 B：UDP 物理广播 ==========
      _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, 8899,
          reuseAddress: true, reusePort: true);
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final Datagram? datagram = _udpSocket!.receive();
          if (datagram != null) {
            _handleIncomingUDP(datagram, myAgentId);
          }
        }
      });

      // 心跳波：5 秒一次（原 2 秒，省电且够用）
      _udpBeaconTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _broadcastUDP(myAgentId, myNickname, tcpPort, hello);
      });

      _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _checkOfflineNodes();
      });

      isSearching = true;
    } catch (e) {
      AppLogger.e('lan.start', e);
    }
  }

  void _updateNode(String agentId, String ip, int port, String nickname,
      String avatar) async {
    final isNewNode = !_lanNodes.containsKey(agentId);
    _lanNodes[agentId] =
        _LanNode(ip: ip, tcpPort: port, lastSeen: DateTime.now().millisecondsSinceEpoch);

    await DBHelper.updateAgentOnlineStatusByAgentId(agentId, true);

    if (isNewNode) {
      await DBHelper.insertAgentFriend(
          nickname, "Wi-Fi雷达", agentId, "stranger", "局域网混合通道", "未知", avatar);
      await DBHelper.insertSocialLog("system", agentId, L10nHolder.l10n.lanTunnelOpen);
      _notifyListeners();
      AppEvents.emit(NodeOnlineEvent(agentId));
      // 发现新节点即主动握手：把"要等下一次 BEACON（≤5s）才有会话"的窗口压到 0。
      // fail-closed 下未建会话无法发消息，这一步对首个消息的可用性很关键。
      if (!SessionCrypto.instance.hasSession(agentId)) {
        unawaited(_sendHelloTo(ip, port));
      }
    } else {
      _notifyListeners();
    }
  }

  /// 向指定节点 POST 本机 HELLO（明文 + 身份签名）以促成会话建立
  Future<void> _sendHelloTo(String ip, int port) async {
    final myId = _myId;
    final hello = _myHello;
    if (myId == null || hello == null || port <= 0) return;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    try {
      final uri = Uri.parse("http://$ip:$port/mcp_p2p");
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.text;
      request.write(jsonEncode({'sender_id': myId, 'hello': hello}));
      await request.close();
    } catch (e) {
      AppLogger.w('lan.hello_send', e);
    } finally {
      client.close();
    }
  }

  /// 处理对端 HELLO（验签 + TOFU）；被 TOFU 判定为身份替换时记一次攻击事件
  Future<void> _onHello(String senderId, String helloJson) async {
    final helloOk = await SessionCrypto.instance.handleHello(senderId, helloJson);
    if (!helloOk && SessionCrypto.instance.consumeIdentityAttack(senderId)) {
      await ReputationService.instance.recordEvent(senderId, 'identity_attack');
      await DBHelper.insertSocialLog(
          "system", senderId, L10nHolder.l10n.identityChangedWarning);
    }
  }

  Future<void> _broadcastUDP(
      String myId, String myNickname, int tcpPort, String hello) async {
    try {
      final payload = jsonEncode({
        'type': 'BEACON',
        'agent_id': myId,
        'nickname': myNickname,
        'tcp_port': tcpPort,
        'hello': hello,
      });
      // BEACON 只含公开信息（身份标识 + 已签名 HELLO），明文广播即可；
      // 机密性由 HELLO 里公钥派生的会话密钥提供，不依赖任何静态密钥。
      final bytes = utf8.encode(payload);

      // 对每个网卡发一次定向广播（不再叠加全局广播，减少重复包）
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final broadcastIp = "${parts[0]}.${parts[1]}.${parts[2]}.255";
            _udpSocket?.send(bytes, InternetAddress(broadcastIp), 8899);
          }
        }
      }
      if (interfaces.isEmpty) {
        _udpSocket?.send(bytes, InternetAddress("255.255.255.255"), 8899);
      }
    } catch (e) {
      // 自愈触发器：标记引擎挂掉，让心跳层来重启
      AppLogger.w('lan.broadcast', e);
      isSearching = false;
    }
  }

  void _handleIncomingUDP(Datagram datagram, String myAgentId) async {
    try {
      final rawText = utf8.decode(datagram.data);
      final Map<String, dynamic> data = jsonDecode(rawText) as Map<String, dynamic>;
      final type = data['type'];

      // ① 明文 BEACON：携带公开身份 + 已签名 HELLO
      if (type == 'BEACON') {
        final senderId = data['agent_id'] as String? ?? '';
        if (senderId.isEmpty || senderId == myAgentId) return;
        final hello = data['hello'] as String?;
        if (hello != null) await _onHello(senderId, hello);
        final nickname = data['nickname'] ?? '局域网节点';
        final port = data['tcp_port'] as int? ?? 0;
        _updateNode(senderId, datagram.address.address, port, nickname, '🤖');
        return;
      }

      // ② 会话加密 CHAT 信封 {sender_id, body}：未建会话即丢弃（fail-closed）
      final senderId = data['sender_id'] as String? ?? '';
      final bodyEnc = data['body'] as String?;
      if (senderId.isEmpty || senderId == myAgentId || bodyEnc == null) return;
      final bodyJson = SessionCrypto.instance.decryptFrom(senderId, bodyEnc);
      if (bodyJson == null) return;
      final chat = jsonDecode(bodyJson);

      final message = chat['message'];
      final avatar = chat['avatar'] ?? '🤖';

      if (_lanNodes.containsKey(senderId)) {
        _lanNodes[senderId]!.lastSeen = DateTime.now().millisecondsSinceEpoch;
      }
      await DBHelper.db.then((db) => db.update(
          'agent_friends', {'avatar': avatar},
          where: 'agent_id = ?', whereArgs: [senderId]));
      _notifyListeners();

      AppEvents.emit(SocialMessageReceivedEvent(
        senderAgentId: senderId,
        message: message,
        channel: 'lan',
      ));
    } catch (e) {
      AppLogger.w('lan.udp', e);
    }
  }

  void _checkOfflineNodes() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final keysToRemove = <String>[];
    for (var entry in _lanNodes.entries) {
      if (now - entry.value.lastSeen > 15000) keysToRemove.add(entry.key);
    }
    for (var key in keysToRemove) {
      _lanNodes.remove(key);
      // 蓝牙还连着时不能标记离线
      if (!P2PService().connectedAgents.contains(key)) {
        await DBHelper.updateAgentOnlineStatusByAgentId(key, false);
        await DBHelper.insertSocialLog("system", key, L10nHolder.l10n.lanTargetLost);
      }
    }
    if (keysToRemove.isNotEmpty) _notifyListeners();
  }

  Future<void> stopLanEngine() async {
    try {
      if (_registration != null) await unregister(_registration!);
      if (_discovery != null) await stopDiscovery(_discovery!);
      await _localServer?.close();

      _udpBeaconTimer?.cancel();
      _cleanupTimer?.cancel();
      _udpSocket?.close();
    } catch (e) {
      AppLogger.w('lan.stop', e);
    }

    _lanNodes.clear();
    isSearching = false;
  }

  /// 发送：TCP 优先，失败降级 UDP。
  ///
  /// **fail-closed**：未建立安全会话时**拒发**（返回 false），绝不回退明文或静态密钥；
  /// 同时顺手向目标发一次 HELLO，把会话建起来（下次即可发）。
  Future<bool> sendLanMessage(String targetAgentId, String message,
      String myAgentId, String myNickname, String avatar) async {
    final node = _lanNodes[targetAgentId];
    if (node == null) return false;

    if (!SessionCrypto.instance.hasSession(targetAgentId)) {
      unawaited(_sendHelloTo(node.ip, node.tcpPort));
      return false;
    }

    bool tcpSuccess = false;
    if (node.tcpPort > 0) {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      try {
        final uri = Uri.parse("http://${node.ip}:${node.tcpPort}/mcp_p2p");
        final request = await client.postUrl(uri);
        final payloadMap = {
          'type': 'CHAT',
          'avatar': avatar,
          'message': message,
          'port': _localServer?.port ?? 0,
        };
        request.headers.contentType = ContentType.text;
        request.write(jsonEncode({
          'sender_id': myAgentId,
          'body': SessionCrypto.instance
              .encryptFor(targetAgentId, jsonEncode(payloadMap)),
        }));
        final response = await request.close();
        tcpSuccess = (response.statusCode == HttpStatus.ok);
      } catch (e) {
        AppLogger.w('lan.tcp_send', e);
        tcpSuccess = false;
      } finally {
        client.close();
      }
    }

    if (tcpSuccess) return true;

    try {
      final payloadMap = {
        'type': 'CHAT',
        'avatar': avatar,
        'message': message,
      };
      _udpSocket?.send(
          utf8.encode(jsonEncode({
            'sender_id': myAgentId,
            'body': SessionCrypto.instance
                .encryptFor(targetAgentId, jsonEncode(payloadMap)),
          })),
          InternetAddress(node.ip), 8899);
      return true;
    } catch (e) {
      AppLogger.w('lan.udp_send', e);
      return false;
    }
  }
}
