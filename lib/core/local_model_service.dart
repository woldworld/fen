import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'setup_service.dart';

/// 端侧小模型兜底的**生效配置**（地址 + 模型名）。
///
/// `disabled` 表示用户在设置页把地址**清空**了 = 显式关闭本地兜底。
class LocalModelConfig {
  const LocalModelConfig(this.baseUrl, this.model);

  /// 生效地址（空串 = 显式关闭）。
  final String baseUrl;

  /// 生效模型名（永不为空：空值时已回落出厂默认）。
  final String model;

  bool get disabled => baseUrl.isEmpty;
}

/// 连通性自检结果。**不用 bool** 是因为要如实回答"为什么不通" ——
/// 地址填得对 ≠ 那儿真有服务在听（`可配 ≠ 可用`），bool 会把这两种情形混成一句"失败"。
class LocalModelTestResult {
  const LocalModelTestResult({
    required this.ok,
    required this.baseUrl,
    required this.model,
    this.reason,
  });

  final bool ok;
  final String baseUrl;
  final String model;

  /// 失败原因（机器可读的短码，UI 负责本地化）：
  ///   `disabled`    —— 地址被清空，本地兜底已关闭
  ///   `unreachable` —— 连不上（没服务在听 / 端口不通 / 超时）
  ///   `http_<code>` —— 有服务应答但状态码非 200
  ///   `not_json`    —— 200 但响应不是 JSON（多半是代理或错误页）
  ///   `no_message`  —— JSON 结构对但取不到 message.content（模型名不对/接口不同）
  final String? reason;
}

/// 端侧小模型兜底（Ollama / llama.cpp REST 接口）。
/// 云端 API 超时、断网或隐私敏感场景下降级到本地模型。
///
/// ★ 0.47.0 起地址与模型名**可在设置页配置**（设置 → 引擎：
/// `local_model_base_url` / `local_model_name`）。解析判据与后端地址一致——
/// **看键是否存在，不看值是否为空**：
///   - 键不存在（从没设过）→ 出厂默认 `127.0.0.1:11434` + `qwen2.5:3b`；
///   - 键存在且为**空串** → 用户显式**关闭**本地兜底（返回 null，不再尝试）。
///
/// ⚠️ 如实说明（`可配 ≠ 可用`）：手机上 `127.0.0.1:11434` 通常**没有**服务在听
/// （Ollama 不随 App 装），所以这条兜底**默认等于空** —— 它真正的用途是：
///   ① 用户自己在电脑/同机跑 Ollama 时把地址指过去；
///   ② 将来接端侧推理引擎时换一个端口。
/// 到底通不通，请用设置页的「测试连接」（[testConnection]），别只看填没填。
/// 失败一律返回 null 并**留一条日志**（此前是静默吞掉，排障无线索）。
class LocalModelService {
  LocalModelService._();

  /// 出厂默认地址（可在设置页覆盖；存空串 = 显式关闭本地兜底）。
  static const String defaultBaseUrl = 'http://127.0.0.1:11434';

  /// 出厂默认模型名（可在设置页覆盖）。
  static const String defaultModel = 'qwen2.5:3b';

  /// 解析**当前生效**的配置。唯一入口 —— `chat` 与 `testConnection` 共用一份，
  /// 避免"设置页显示的地址"与"实际调用的地址"两处各写一套判据后漂移。
  static Future<LocalModelConfig> resolveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    // 判据 = 键是否存在（与 SetupService.resolveStoredOrDefault 同一规则）：
    // 存了空串是用户"我要关掉本地兜底"的显式决定，不能被默认值翻案。
    final baseUrl = SetupService.resolveStoredOrDefault(
      keyPresent: prefs.containsKey('local_model_base_url'),
      stored: prefs.getString('local_model_base_url'),
      fallback: defaultBaseUrl,
    ).trim();
    final storedModel = (prefs.getString('local_model_name') ?? '').trim();
    return LocalModelConfig(
        baseUrl, storedModel.isEmpty ? defaultModel : storedModel);
  }

  /// 返回本地模型回复；不可用时返回 null（调用方自行决定降级策略）
  static Future<String?> chat(
    String systemPrompt,
    String userMessage, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final cfg = await resolveConfig();
    if (cfg.disabled) return null; // 显式关闭
    final baseUrl = cfg.baseUrl;
    final model = cfg.model;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(Uri.parse('$baseUrl/api/chat'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'model': model,
        'stream': false,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
      }));
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) {
        AppLogger.w('local_model', 'HTTP ${res.statusCode} from $baseUrl ($model)');
        return null;
      }
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final msg = (data['message'] as Map<String, dynamic>?)?['content'] as String?;
      return msg?.trim();
    } catch (e) {
      // ★ 失败不再静默：留痕（地址打不通是常态——回环上没服务——但排障要有线索）
      AppLogger.w('local_model', e);
      return null;
    } finally {
      client.close();
    }
  }

  /// 连通性自检：**可配 ≠ 可用** —— 填了地址不代表那儿真有服务在听。
  ///
  /// ★ 可显式传入 `baseUrl` / `model` 以**测试用户刚敲进去、尚未保存**的值：
  ///   否则设置页只能"先保存 → 再发现打不通 → 再改"，把一次配置变成两趟。
  ///   不传则用 [resolveConfig]（与 `chat` 完全同源）。
  /// ★ 与 `chat` 的关键差别：这里连 **200 也要验内容**。有些网关/代理会返回
  ///   200 + HTML 错误页，只看状态码会把"其实不可用"报成绿。
  static Future<LocalModelTestResult> testConnection({
    String? baseUrl,
    String? model,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    String url;
    String name;
    if (baseUrl == null) {
      final cfg = await resolveConfig();
      url = cfg.baseUrl;
      name = model == null || model.trim().isEmpty ? cfg.model : model.trim();
    } else {
      url = baseUrl.trim();
      final m = (model ?? '').trim();
      name = m.isEmpty ? defaultModel : m;
    }
    if (url.isEmpty) {
      return LocalModelTestResult(
          ok: false, baseUrl: url, model: name, reason: 'disabled');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(Uri.parse('$url/api/chat'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'model': name,
        'stream': false,
        // 用最小请求探活：不喂真上下文，也不产生有意义的算力开销
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
      }));
      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        AppLogger.w('local_model', 'test HTTP ${res.statusCode} from $url');
        return LocalModelTestResult(
            ok: false, baseUrl: url, model: name, reason: 'http_${res.statusCode}');
      }
      // 200 也要验内容：非 JSON / 取不到 message.content 都算不通
      try {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final msg = (data['message'] as Map<String, dynamic>?)?['content'] as String?;
        if (msg == null) {
          return LocalModelTestResult(
              ok: false, baseUrl: url, model: name, reason: 'no_message');
        }
      } catch (_) {
        return LocalModelTestResult(
            ok: false, baseUrl: url, model: name, reason: 'not_json');
      }
      return LocalModelTestResult(ok: true, baseUrl: url, model: name);
    } catch (e) {
      // ★ 连不上（SocketException / TimeoutException / DNS…）统一归 `unreachable`：
      //   原始异常文本对用户没有意义，且会泄露本机路径/端口细节 ⇒ 只留日志。
      AppLogger.w('local_model', e);
      return LocalModelTestResult(
          ok: false, baseUrl: url, model: name, reason: 'unreachable');
    } finally {
      client.close();
    }
  }
}
