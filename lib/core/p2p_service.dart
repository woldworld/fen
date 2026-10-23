import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_events.dart';
import 'app_logger.dart';
import 'db_helper.dart';
import 'l10n_holder.dart';
import 'lan_service.dart';
import 'reputation_service.dart';
import 'session_crypto.dart';

/// 近场 P2P 引擎（蓝牙 Nearby Connections）。
/// 改进：与 AgentService 解耦（只发事件）；会话加密优先；
/// 收到 HELLO 握手后升级为每会话 AES-GCM。
class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  // 品牌置换（2026-09-26）：对外可见的通道标识随之更名。
  // ⚠️ 新旧版本无法互相发现——两端必须同时更新。
  final String _serviceId = "world.wold.fen.mesh";
  final Strategy _strategy = Strategy.P2P_CLUSTER;

  bool isPatrolling = false;
  final List<Function()> listeners = [];

  void _notifyListeners() {
    for (var listener in listeners) listener();
  }

  // AgentID <-> 物理 EndpointID 双向映射
  final Map<String, String> _agentToEndpoint = {};
  List<String> get connectedAgents => _agentToEndpoint.keys.toList();

  // 已向该对端发过 HELLO（防 HELLO 乒乓：双方都"收到就回"会无限来回）
  final Set<String> _helloSent = {};

  int _getAndroidSDK() {
    try {
      if (!Platform.isAndroid) return 0;
      final String osVersion = Platform.operatingSystemVersion.toLowerCase();
      if (osVersion.contains("android 14") || osVersion.contains("api 34")) return 34;
      if (osVersion.contains("android 13") || osVersion.contains("api 33")) return 33;
      if (osVersion.contains("android 12") ||
          osVersion.contains("api 31") ||
          osVersion.contains("api 32")) return 31;
      if (osVersion.contains("android 11") || osVersion.contains("api 30")) return 30;
      if (osVersion.contains("android 10") || osVersion.contains("api 29")) return 29;
      final RegExp regExp = RegExp(r'android\s+([0-9]+)');
      final match = regExp.firstMatch(osVersion);
      if (match != null) return int.tryParse(match.group(1) ?? '') ?? 33;
    } catch (e) {
      AppLogger.w('p2p.sdk', e);
    }
    return 33;
  }

  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;

    final int sdkInt = _getAndroidSDK();
    final List<Permission> permissionsToRequest = [Permission.location];

    if (sdkInt >= 31) {
      permissionsToRequest.add(Permission.bluetoothScan);
      permissionsToRequest.add(Permission.bluetoothAdvertise);
      permissionsToRequest.add(Permission.bluetoothConnect);
    } else {
      permissionsToRequest.add(Permission.bluetooth);
    }

    if (sdkInt >= 33) {
      permissionsToRequest.add(Permission.nearbyWifiDevices);
    }

    final Map<Permission, PermissionStatus> statuses =
        await permissionsToRequest.request();

    bool allRequiredGranted = true;
    statuses.forEach((permission, status) {
      if (status != PermissionStatus.granted) allRequiredGranted = false;
    });

    // 安卓 10+ 需要"始终允许定位"，否则息屏后蓝牙扫描被系统切断
    if (allRequiredGranted && sdkInt >= 29) {
      if (!await Permission.locationAlways.isGranted) {
        await Permission.locationAlways.request();
      }
    }

    if (allRequiredGranted) {
      final bool isLocationServiceEnabled =
          await Permission.location.serviceStatus.isEnabled;
      if (!isLocationServiceEnabled) return false;
    }

    return allRequiredGranted;
  }

  Future<bool> startPatrolling(String myAgentId, String myNickname) async {
    if (!await _requestPermissions()) return false;
    try {
      final String myPayloadName = "$myAgentId|$myNickname";
      final hello = await SessionCrypto.instance.buildHello(myAgentId);

      await Nearby().startAdvertising(
        myPayloadName,
        _strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      await Nearby().startDiscovery(
        myAgentId,
        _strategy,
        onEndpointFound: (endpointId, endpointName, serviceId) async {
          final parts = endpointName.split('|');
          final agentId = parts[0];
          final agentName = parts.length > 1 ? parts[1] : "野生 Agent";
          if (agentId == myAgentId) return;

          _agentToEndpoint[agentId] = endpointId;

          await DBHelper.insertAgentFriend(
              agentName, "物理探测", agentId, "stranger", "Nearby 雷达探测", "未知", "🤖");
          _notifyListeners();

          Nearby().requestConnection(
            myPayloadName,
            endpointId,
            onConnectionInitiated: _onConnectionInit,
            onConnectionResult: _onConnectionResult,
            onDisconnected: _onDisconnected,
          );
        },
        onEndpointLost: (endpointId) async {
          String? lostAgentId;
          _agentToEndpoint.forEach((key, val) {
            if (val == endpointId) lostAgentId = key;
          });

          _agentToEndpoint.removeWhere((key, value) => value == endpointId);

          if (lostAgentId != null &&
              !LanService().connectedLanAgents.contains(lostAgentId)) {
            await DBHelper.updateAgentOnlineStatusByAgentId(lostAgentId!, false);
          }
          _notifyListeners();
        },
        serviceId: _serviceId,
      );

      isPatrolling = true;
      // 尝试向已连接节点发送 HELLO 建立会话
      _sendHelloToConnected(myAgentId, hello);
      return true;
    } catch (e) {
      AppLogger.w('p2p.start', e);
      return false;
    }
  }

  void _sendHelloToConnected(String myAgentId, String hello) {
    for (final entry in _agentToEndpoint.entries) {
      final target = entry.value;
      try {
        // 明文转发完整 HELLO（只含公钥 + 身份签名），接收端验签 + TOFU 固定
        _helloSent.add(entry.key);
        Nearby().sendBytesPayload(target, utf8.encode(jsonEncode({
          'sender_id': myAgentId,
          'hello': hello,
        })));
      } catch (e) {
        AppLogger.w('p2p.hello', e);
      }
    }
  }

  Future<void> stopPatrolling() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (e) {
      AppLogger.w('p2p.stop', e);
    }
    _agentToEndpoint.clear();
    isPatrolling = false;
  }

  void _onConnectionInit(String endpointId, ConnectionInfo info) {
    final parts = info.endpointName.split('|');
    final agentId = parts[0];
    _agentToEndpoint[agentId] = endpointId;
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (endId, payload) => _onPayloadReceived(endId, payload),
      onPayloadTransferUpdate: (endId, payloadTransferUpdate) {},
    );
  }

  void _onConnectionResult(String endpointId, Status status) async {
    if (status == Status.CONNECTED) {
      String? connectedAgentId;
      _agentToEndpoint.forEach((key, val) {
        if (val == endpointId) connectedAgentId = key;
      });
      if (connectedAgentId != null) {
        await DBHelper.updateAgentOnlineStatusByAgentId(connectedAgentId!, true);
        await DBHelper.insertSocialLog("system", connectedAgentId!,
            "🔗 P2P 原生蓝牙/Wi-Fi 直连隧道已连通！");
        _notifyListeners();
        AppEvents.emit(NodeOnlineEvent(connectedAgentId!));
      }
    }
  }

  void _onDisconnected(String endpointId) async {
    String? disconnectedAgentId;
    _agentToEndpoint.forEach((key, val) {
      if (val == endpointId) disconnectedAgentId = key;
    });
    if (disconnectedAgentId != null) {
      _agentToEndpoint.remove(disconnectedAgentId);
      if (!LanService().connectedLanAgents.contains(disconnectedAgentId)) {
        await DBHelper.updateAgentOnlineStatusByAgentId(disconnectedAgentId!, false);
        await DBHelper.insertSocialLog(
            "system", disconnectedAgentId!, L10nHolder.l10n.p2pBtDisconnected);
      }
    }
    _notifyListeners();
  }

  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type != PayloadType.BYTES) return;
    try {
      final rawText = utf8.decode(payload.bytes!);
      final outer = jsonDecode(rawText) as Map<String, dynamic>;
      final senderId = outer['sender_id'] as String? ?? '';
      if (senderId.isEmpty) return;

      // ① 明文 HELLO：只含公钥 + 身份签名（公钥非机密，只需防篡改/防重放）
      final helloStr = outer['hello'] as String?;
      if (helloStr != null) {
        final helloOk = await SessionCrypto.instance.handleHello(senderId, helloStr);
        // 身份突变（验签通过但公钥与历史固定不符）：记为身份攻击，信誉直接归零
        if (!helloOk && SessionCrypto.instance.consumeIdentityAttack(senderId)) {
          await ReputationService.instance.recordEvent(senderId, 'identity_attack');
          await DBHelper.insertSocialLog(
              "system", senderId, L10nHolder.l10n.identityChangedWarning);
        }
        // 回一次自己的 HELLO，让双方都能派生会话密钥；每对端只回一次，避免乒乓
        if (_helloSent.add(senderId)) {
          try {
            final endpoint = _agentToEndpoint[senderId];
            final myId = await DBHelper.getAmbassador('my_agent_id') ?? '';
            if (endpoint != null && myId.isNotEmpty) {
              Nearby().sendBytesPayload(endpoint, utf8.encode(jsonEncode({
                'sender_id': myId,
                'hello': await SessionCrypto.instance.buildHello(myId),
              })));
            }
          } catch (_) {}
        }
        return;
      }

      // ② 会话加密业务报文：未建会话即丢弃（fail-closed）
      final bodyEnc = outer['body'] as String?;
      if (bodyEnc == null) return;
      final bodyJson = SessionCrypto.instance.decryptFrom(senderId, bodyEnc);
      if (bodyJson == null) return;
      final data = jsonDecode(bodyJson);

      final message = data['message'];
      final avatar = data['avatar'] ?? '🤖';

      await DBHelper.db.then((db) => db.update(
          'agent_friends', {'avatar': avatar},
          where: 'agent_id = ?', whereArgs: [senderId]));
      _notifyListeners();

      AppEvents.emit(SocialMessageReceivedEvent(
        senderAgentId: senderId,
        message: message,
        channel: 'p2p',
      ));
    } catch (e) {
      AppLogger.w('p2p.payload', e);
    }
  }

  /// 发送业务消息：**fail-closed**——未建安全会话即拒发（返回 false）
  Future<bool> sendSecureMessage(String targetAgentId, String message,
      String myAgentId, String avatar) async {
    final endpointId = _agentToEndpoint[targetAgentId];
    if (endpointId == null) return false;
    if (!SessionCrypto.instance.hasSession(targetAgentId)) return false;

    final payloadMap = {
      'type': 'CHAT',
      'avatar': avatar,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final String body =
        SessionCrypto.instance.encryptFor(targetAgentId, jsonEncode(payloadMap));
    final Uint8List bytes = utf8.encode(jsonEncode({
      'sender_id': myAgentId,
      'body': body,
    }));
    try {
      await Nearby().sendBytesPayload(endpointId, bytes);
      return true;
    } catch (e) {
      AppLogger.w('p2p.send', e);
      return false;
    }
  }
}
