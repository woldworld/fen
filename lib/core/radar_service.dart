import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'agent_service.dart';
import 'app_logger.dart';
import 'background_duty_service.dart';
import 'cloud_service.dart';
import 'db_helper.dart';
import 'lan_service.dart';
import 'l10n_holder.dart';
import 'p2p_service.dart';
import 'social_budget.dart';
import 'world_service.dart';

/// 雷达/心跳/保活总控。
/// 从 social_screen 的 UI State 中抽离：App 进程被杀后可由 main() 自动恢复。
class RadarService with ChangeNotifier {
  RadarService._();

  static final RadarService instance = RadarService._();

  bool _isPatrolling = false;
  bool _isProcessing = false;
  int _endTime = 0;
  Timer? _heartbeat;
  int _failures = 0;

  bool _isNearFieldEnabled = false;
  bool _isLanEnabled = false;
  bool _isCloudEnabled = false;

  final SocialBudget _budget = SocialBudget();

  bool get isPatrolling => _isPatrolling;
  bool get isProcessing => _isProcessing;
  int get endTime => _endTime;
  bool get isNearFieldEnabled => _isNearFieldEnabled;
  bool get isLanEnabled => _isLanEnabled;
  bool get isCloudEnabled => _isCloudEnabled;

  int get remainingMs {
    if (_endTime <= 0) return 0;
    final r = _endTime - DateTime.now().millisecondsSinceEpoch;
    return r < 0 ? 0 : r;
  }

  /// 开启雷达（minutes 为限时分钟数）
  Future<bool> start({int minutes = 60}) async {
    if (_isProcessing) return false;
    _isProcessing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _endTime = DateTime.now().millisecondsSinceEpoch + minutes * 60 * 1000;
      await prefs.setInt('radar_end_time', _endTime);
      await prefs.setBool('radar_wrapping_up', false);
      await prefs.setBool('agent_is_patrolling', true);

      // 与旧行为一致：雷达开启时默认所有信道关闭，由用户手动选择
      _setChannels(nearField: false, lan: false, cloud: false);
      await _writeChannelPrefs(false);

      await _keepAlive(true);
      await _syncHardwareEngine();
      _startHeartbeat();
      _isPatrolling = true;
      await DBHelper.insertSocialLog("system", "all",
          L10nHolder.l10n.radarNoticeStarted(minutes));
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.w('radar.start', e);
      return false;
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> stop() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      _heartbeat?.cancel();
      _heartbeat = null;
      await P2PService().stopPatrolling();
      await LanService().stopLanEngine();
      await _keepAlive(false);

      final prefs = await SharedPreferences.getInstance();
      _endTime = 0;
      await prefs.setInt('radar_end_time', 0);
      await prefs.setBool('agent_is_patrolling', false);
      _isPatrolling = false;
      await DBHelper.insertSocialLog(
          "system", "all", L10nHolder.l10n.radarNoticeStopped);
      notifyListeners();
    } catch (e) {
      AppLogger.w('radar.stop', e);
    } finally {
      _isProcessing = false;
    }
  }

  /// 信道开关（UI 调用）
  Future<void> setChannel(String key, bool value) async {
    if (_isProcessing) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (key == 'link_near_field_enabled') _isNearFieldEnabled = value;
    if (key == 'link_lan_enabled') _isLanEnabled = value;
    if (key == 'link_cloud_enabled') _isCloudEnabled = value;
    // 开启云端通道时主动向 Hub 注册（幂等）
    if (key == 'link_cloud_enabled' && value) {
      final myId = await DBHelper.getAmbassador('my_agent_id') ?? '';
      final nickname = await DBHelper.getAmbassador('nickname') ?? '';
      final maskProfile = await DBHelper.getAmbassador('mask_profile') ?? '';
      if (myId.isNotEmpty) {
        await CloudService().registerAgent(myId, nickname, maskProfile);
      }
    }
    if (_isPatrolling) await _syncHardwareEngine();
    notifyListeners();
  }

  /// App 启动恢复：进程被杀后雷达自动复活
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isNearFieldEnabled = prefs.getBool('link_near_field_enabled') ?? false;
      _isLanEnabled = prefs.getBool('link_lan_enabled') ?? false;
      _isCloudEnabled = prefs.getBool('link_cloud_enabled') ?? false;

      if (prefs.getBool('agent_is_patrolling') == true) {
        _endTime = prefs.getInt('radar_end_time') ?? 0;
        if (_endTime > DateTime.now().millisecondsSinceEpoch) {
          await _keepAlive(true);
          await _syncHardwareEngine();
          _startHeartbeat();
          _isPatrolling = true;
          notifyListeners();
        } else {
          await prefs.setBool('agent_is_patrolling', false);
        }
      }
    } catch (e) {
      AppLogger.w('radar.restore', e);
    }
  }

  void _setChannels({
    required bool nearField,
    required bool lan,
    required bool cloud,
  }) {
    _isNearFieldEnabled = nearField;
    _isLanEnabled = lan;
    _isCloudEnabled = cloud;
  }

  Future<void> _writeChannelPrefs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('link_near_field_enabled', value);
    await prefs.setBool('link_lan_enabled', value);
    await prefs.setBool('link_cloud_enabled', value);
  }

  Future<void> _keepAlive(bool enable) async {
    try {
      if (enable) {
        WakelockPlus.enable();
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
        try {
          if (!await Permission.ignoreBatteryOptimizations.isGranted) {
            await Permission.ignoreBatteryOptimizations.request();
          }
        } catch (e) {
          AppLogger.w('radar.battery', e);
        }
        final androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: L10nHolder.l10n.radarNotifTitle,
          notificationText: L10nHolder.l10n.radarNotifText,
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        );
        final ok = await FlutterBackground.initialize(androidConfig: androidConfig);
        if (ok) await FlutterBackground.enableBackgroundExecution();
      } else {
        WakelockPlus.disable();
        if (FlutterBackground.isBackgroundExecutionEnabled) {
          await FlutterBackground.disableBackgroundExecution();
        }
      }
    } catch (e) {
      AppLogger.w('radar.keepalive', e);
    }
  }

  Future<void> _syncHardwareEngine() async {
    final myId = await DBHelper.getAmbassador('my_agent_id') ?? 'AG-XXXXXX';
    final nick = await DBHelper.getAmbassador('nickname') ?? '外交代驾-阿尔法';

    try {
      if (_isNearFieldEnabled && !P2PService().isPatrolling) {
        await P2PService().startPatrolling(myId, nick);
      }
      if (!_isNearFieldEnabled && P2PService().isPatrolling) {
        await P2PService().stopPatrolling();
      }
    } catch (e) {
      AppLogger.w('radar.p2p', e);
    }

    try {
      if (_isLanEnabled && !LanService().isSearching) {
        await LanService().startLanEngine(myId, nick);
      }
      if (!_isLanEnabled && LanService().isSearching) {
        await LanService().stopLanEngine();
      }
    } catch (e) {
      AppLogger.w('radar.lan', e);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  Future<void> _tick() async {
    if (!_isPatrolling) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_endTime > 0 && now > _endTime) {
        await DBHelper.insertSocialLog(
            "system", "all", L10nHolder.l10n.radarNoticePartyEnded);
        await stop();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (_endTime > 0 && (_endTime - now) < 600000) {
        if (prefs.getBool('radar_wrapping_up') != true) {
          await prefs.setBool('radar_wrapping_up', true);
          await DBHelper.insertSocialLog(
              "system", "all", L10nHolder.l10n.radarNoticeWrappingUp);
        }
      } else {
        await prefs.setBool('radar_wrapping_up', false);
      }

      // 硬件通道自愈
      await _syncHardwareEngine();

      if (_isCloudEnabled) {
        final myId = await DBHelper.getAmbassador('my_agent_id') ?? '';
        if (myId.isNotEmpty) {
          // 值班锁：与后台心跳（Workmanager isolate）互斥——两边的内存去重
          // 互相看不见，同一封邮箱消息会被回复两次。抢不到锁说明后台心跳
          // 正在处理，本轮直接跳过（邮箱消息不会丢，只是晚一个轮询周期）。
          // 世界 feed 不抢锁：后台心跳不拉 feed，无撞车面。
          if (await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2))) {
            try {
              await CloudService().pullMailbox(myId);
            } finally {
              await BackgroundDuty.releaseLock();
            }
          }
          // 世界房间 feed：入站消息只进观察日志/记忆流，决策在 AgentService
          await WorldService().pullFeed(myId);
        }
      }

      // 主动搭讪：只受「有人在线 + 预算」约束（绝不找被拉黑/rejected 的节点）
      // ★ 2026-09-29 用户指令：**取消 23:00–07:00 夜间静默**。
      //   原先 `hour >= 23 || hour < 7` 会让整整 8 小时零搭讪，而这个静默在界面上
      //   **没有任何可见出口** ⇒ 用户只会体感成"分身不活跃"，却查不到原因。
      //   ★ 保留的仍是"主人可控"的那部分：通道开关 / 观察模式 / 安全审查，一道都没动。
      final onlineCount = await DBHelper.getOnlineAgentCount();
      if (onlineCount > 0 && _budget.allow()) {
        final dbClient = await DBHelper.db;
        final nodes = await dbClient.query('agent_friends',
            where: 'is_online = ? AND handshake_status != ?',
            whereArgs: [1, 'rejected']);
        if (nodes.isNotEmpty && Random().nextInt(100) < 60) {
          final target = nodes[Random().nextInt(nodes.length)];
          await AgentService().evaluateAndProactiveMessage(target['agent_id'] as String);
        }
      }

      _failures = 0;
      notifyListeners();
      await _rescheduleHeartbeat();
    } catch (e) {
      _failures++;
      AppLogger.w('radar.tick', e);
      await _rescheduleHeartbeat();
    }
  }

  Future<void> _rescheduleHeartbeat() async {
    final online = await DBHelper.getOnlineAgentCount();
    final base = online > 0
        ? const Duration(seconds: 30)
        : const Duration(minutes: 2);
    final interval = _failures >= 3
        ? const Duration(minutes: 5)
        : _failures >= 1
            ? const Duration(minutes: 1)
            : base;
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(interval, (_) => _tick());
  }
}
