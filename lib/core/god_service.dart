import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'agent_identity.dart';
import 'app_logger.dart';
import 'l10n_holder.dart';

/// GOD 控制室客户端（Step 4）：把 App 变成 GOD 小镇（XiaoLuoLYG/GOD）的远程控制台。
/// 上游是跑在 GOD 同机的 god-bridge.js（pocketagent/1 签名协议，默认 127.0.0.1:3300），
/// 只读状态走签名 GET；控制指令（暂停/单步/提问/注入）走签名 POST，桥接侧留审计日志。
/// 安全边界：GOD 是局域网本机服务，允许对私有网段走 http；公网地址必须 HTTPS 门面。
class GodService {
  static final GodService _instance = GodService._internal();
  factory GodService() => _instance;
  GodService._internal();

  String? lastError;

  /// 私有网段判断（桥接通常跑在家庭/办公室局域网的电脑上）
  static final RegExp _privateHost = RegExp(
      r'^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.|localhost$)');

  Future<String> _getGodUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var url = (prefs.getString('god_hub_url') ?? '').trim();
    if (url.isEmpty) {
      lastError = null; // 未配置 = 控制室功能关闭，不算错误
      return '';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.startsWith('http://')) {
      final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
      final isPrivate =
          host == '10.0.2.2' || host == 'localhost' || _privateHost.hasMatch(host);
      if (!isPrivate) {
        AppLogger.w('god.url', '非 HTTPS 且非私有网段的 GOD 地址已被拒绝: $url');
        lastError = L10nHolder.l10n.godSvcMustBeHttps;
        return '';
      }
    }
    lastError = null;
    return url;
  }

  /// 是否已配置 GOD 桥接（控制室入口显隐）
  Future<bool> isConfigured() async => (await _getGodUrl()).isNotEmpty;

  Future<String> _sigValue(String myAgentId, Map<String, dynamic> payload) async {
    final env = await AgentIdentity().buildHubEnvelope(
      fromId: myAgentId,
      toId: 'god',
      payload: payload,
    );
    return base64UrlEncode(utf8.encode(jsonEncode(env)));
  }

  /// 实时状态：返回 {experiment: {...}, status: {上游原始字段}}
  Future<Map<String, dynamic>?> fetchStatus(String myAgentId,
      {String? hypothesisId, String? experimentId}) async {
    final url = await _getGodUrl();
    if (url.isEmpty) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final qs = (hypothesisId == null || experimentId == null)
          ? ''
          : '?hypothesis_id=$hypothesisId&experiment_id=$experimentId';
      final request = await client.getUrl(Uri.parse("$url/api/god/status$qs"));
      request.headers.set('X-Agent-Sig', await _sigValue(myAgentId, const {}));
      final response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        lastError = L10nHolder.l10n
            .godSvcStatusFailed('${response.statusCode}', body);
        return null;
      }
      lastError = null;
      return Map<String, dynamic>.from(jsonDecode(body));
    } catch (e) {
      AppLogger.w('god.status', e);
      lastError = L10nHolder.l10n.commonNetworkError('$e');
      return null;
    } finally {
      client.close();
    }
  }

  /// 通用控制指令：action ∈ start/pause/auto/run-step/stop/intervene/ask
  ///
  /// 注意：桥接侧上游（GOD FastAPI）超时是 15s，这里必须等得更久（20s），
  /// 否则 App 先放弃而指令实际已在小镇执行，造成"显示失败但已生效"的错觉。
  Future<bool> command(String myAgentId, String action,
      {Map<String, dynamic> fields = const {}}) async {
    final url = await _getGodUrl();
    if (url.isEmpty) {
      lastError = L10nHolder.l10n.godSvcNoBridge;
      return false;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final env = await AgentIdentity().buildHubEnvelope(
        fromId: myAgentId,
        toId: 'god',
        payload: {'action': action, ...fields},
      );
      final request = await client.postUrl(Uri.parse("$url/api/god/command"));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(env));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        final String body = await response.transform(utf8.decoder).join();
        lastError = L10nHolder.l10n
            .godSvcCmdFailed('${response.statusCode}', body);
        return false;
      }
      lastError = null;
      return true;
    } catch (e) {
      AppLogger.w('god.command', e);
      lastError = L10nHolder.l10n.commonNetworkError('$e');
      return false;
    } finally {
      client.close();
    }
  }

  Future<bool> start(String myAgentId) => command(myAgentId, 'start');
  Future<bool> pause(String myAgentId) => command(myAgentId, 'pause');
  Future<bool> resumeAuto(String myAgentId) => command(myAgentId, 'auto');
  Future<bool> runStep(String myAgentId) => command(myAgentId, 'run-step');
  Future<bool> stop(String myAgentId) => command(myAgentId, 'stop');

  /// 定向提问：target 留空 = 全镇；传居民名 = 指定单人
  Future<bool> ask(String myAgentId, String question, {String? targetAgentId}) =>
      command(myAgentId, 'ask', fields: {
        'question': question,
        if (targetAgentId != null && targetAgentId.trim().isNotEmpty)
          'target': targetAgentId.trim(),
      });

  /// 注入干预：内容将进入小镇的下一步（next step）
  Future<bool> intervene(String myAgentId, String instructions) =>
      command(myAgentId, 'intervene', fields: {'instructions': instructions});
}
