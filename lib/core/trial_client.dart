/// 试用代调（trial proxy）的客户端侧：模式判定、额度余量、**失败分类**。
///
/// 服务端契约（`lib/hub/hub.js` `/api/trial/*`）：
/// - `llm_mode=trial` 时 provider 指向 `<hub>/api/trial`，Bearer = 本机 agent_id；
/// - 额度耗尽返回 **HTTP 402** + `trial_quota_exhausted`；
/// - 余量查询 `GET /api/trial/quota?agent_id=` → `{used, limit}`。
///
/// ★ 0.57.0 起失败是**分类可归因**的（[TrialFailure]）：0.56.0 只认 402，
/// 于是 503/415/429/502/401/413/400 全落进"网络接口发生异常"或离线兜底——
/// 用户看到"分身坏了"，实情是"官方试用还没配 Key"。
///
/// 这里只放**可单测的纯逻辑与薄封装**；引导页的双选项交互在
/// `onboarding_screen.dart`，耗尽引导卡在 `agent_service.sendMessage` 的
/// 降级链上（排在离线兜底之前——"去设置填 Key"才是正确的下一步，
/// 切本地模型会让人误以为分身变笨了）。
library;

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'trial_config.dart';

/// 试用通道一次失败**属于哪一类**。
///
/// 每个值都对应服务端 `/api/trial/chat/completions` 实际会返回的一个状态码
/// （即 `lib/hub/hub.js` 试用地带里的 `sendJson(res, NNN, ...)`）：
///
/// | 值 | 状态码 | 服务端错误码 | 用户能做的事 |
/// |---|---|---|---|
/// | [quotaExhausted] | 402 | `trial_quota_exhausted` | 注册自有 Key（转化点）|
/// | [notConfigured] | 503 | `trial_not_configured` | 同上（官方池还没配）|
/// | [inputUnsupported] | 415 | `input_type_unsupported` | 改用文字输入 |
/// | [rateLimited] | 429 | `rate_limited` / `trial_ip_rate_limited` / `trial_ip_daily_limited` | 等一会儿 |
/// | [poolBusy] | 502 | `trial_uppool_exhausted` | 等一会儿，或自配 Key |
/// | [identityRejected] | 401 | `trial_agent_required` | 本机身份异常 |
/// | [promptTooLarge] | 413 | `prompt_too_large` | 缩短输入 |
/// | [badRequest] | 400 | `messages_required` | （客户端不该发出这种请求）|
///
/// ★ 覆盖关系由 `tool/verify_trial_proxy.dart` 判据⑬**跨语言**钉死：
/// 它扫 `hub.js` 试用地带里所有 `sendJson(res, NNN` 的状态码，
/// 逐个要求本文件能归类 —— 服务端新增一类错误而客户端忘了归类时会红。
enum TrialFailure {
  quotaExhausted,
  notConfigured,
  inputUnsupported,
  rateLimited,
  poolBusy,
  identityRejected,
  promptTooLarge,
  badRequest,
}

abstract final class TrialClient {
  /// ★ 0.82.0：常量的**唯一来源**在 `trial_config.dart`（纯逻辑、零 Flutter 依赖、
  ///   可被 `dart run` 直接执行）；这里转发，对外 API 不变。
  static const String modeKey = TrialConfig.modeKey;

  /// 试用模式的单轮输入硬限（字符）：防大文件/超长粘贴烧 token。
  /// 客户端与引导文案引用同一常量；服务端另有整包长度的独立硬闸。
  static const int trialMaxInputChars = 5000;

  /// 自有 Key 用户的输入确认阈值：超过即弹窗提示（不拦截，用户放行可发）。
  static const int ownKeyWarnChars = 10000;
  static const String trialModeValue = TrialConfig.trialModeValue;

  /// 当前是否试用模式（未显式设置 = 老用户的自有 Key 路径）。
  static Future<bool> isTrialMode([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getString(modeKey) == trialModeValue;
  }

  // ======================= 试用配置的四件套：**只此一处** =======================
  // ★★ 0.82.0。缘起＝真机事故：主人在设置页（**无条件覆盖** base_url/api_key）
  //   里按提示"填入自己的 Key"，把试用身份（Bearer = 本机 agent_id）覆盖掉，
  //   而 `llm_mode` 仍是 trial ⇒ 每条消息都在服务端撞 401 `trial_agent_required`
  //   ⇒ 界面显示「免费试用暂时不可用，请前往设置填入自己的 Key」⇒ 主人又去填一次
  //   —— **死循环**。根因有二：① 保存不看模式；② 切模式的写入**只存在于引导页**。
  //   故把"写试用配置 / 判该不该切自有"收成**一处**，引导页与设置页**共用**（R8）。
  //
  //   ★★ 实现落在 `trial_config.dart`（`TrialConfig`，**零 Flutter 依赖**）—— 好处：
  //     ① 纯逻辑与 Flutter 解耦，可被 `dart run tool/verify_trial_switch.dart`
  //        **真跑**（本机 `flutter test` 被宿主注入 DLL 阻塞，这是唯一能做实测的路径）；
  //     ② 单一事实源更硬（连常量一起搬走）。
  //   本类只保留**同名 static 转发** ⇒ 对外 API 完全不变。

  static const String baseUrlKey = TrialConfig.baseUrlKey;
  static const String apiKeyKey = TrialConfig.apiKeyKey;
  static const String modelNameKey = TrialConfig.modelNameKey;
  static const String trialModelName = TrialConfig.trialModelName;
  static const String defaultOwnBaseUrl = TrialConfig.defaultOwnBaseUrl;

  /// 官方代调端点 = `<hub>/api/trial`（拼接规则**只此一处**，见 `TrialConfig`）。
  static String trialApiBase(String hub) => TrialConfig.trialApiBase(hub);

  /// 判定：本次保存是否命中"主人改了自己的 Key ⇒ 该把试用切成自有模式"。
  static bool shouldSwitchToOwn({
    required String? currentMode,
    required String previousKey,
    required String newKey,
  }) =>
      TrialConfig.shouldSwitchToOwn(
          currentMode: currentMode, previousKey: previousKey, newKey: newKey);

  /// 切自有模式时**必须**一起纠正端点（仍指向 `/api/trial` → 直连默认值）。
  static String? ownBaseUrlFix(String baseUrl, {String? fallback}) =>
      TrialConfig.ownBaseUrlFix(baseUrl, fallback: fallback);

  /// 一键写回试用配置（引导页"免费体验"与设置页"恢复免费试用"**共用**）。
  static Future<void> applyTrialConfig(
    SharedPreferences prefs, {
    required String hubUrl,
    required String agentId,
  }) async {
    await prefs.setString(modeKey, trialModeValue);
    await prefs.setString(baseUrlKey, trialApiBase(hubUrl));
    await prefs.setString(
        apiKeyKey, agentId.trim().isEmpty ? 'AG-TRIAL' : agentId.trim());
    await prefs.setString(modelNameKey, trialModelName);
  }

  /// 裸状态码 → 类别（异常文案里只带 `Status NNN` 时用）。
  ///
  /// 键集合 = 服务端试用地带可能产出的**全部**状态码。判据⑬ 拿它跟
  /// `hub.js` 里扫出来的状态码比对，双向缺口都会红。
  static const Map<int, TrialFailure> statusToFailure = {
    400: TrialFailure.badRequest,
    401: TrialFailure.identityRejected,
    402: TrialFailure.quotaExhausted,
    413: TrialFailure.promptTooLarge,
    415: TrialFailure.inputUnsupported,
    429: TrialFailure.rateLimited,
    502: TrialFailure.poolBusy,
    503: TrialFailure.notConfigured,
  };

  /// 服务端错误码串 → 类别。**优先于裸状态码**：
  /// 状态码可能被 SDK 的异常包装吃掉，错误码串更可靠；
  /// 且 `trial_ip_rate_limited` 与 `rate_limited` 都被认下来（同一类）。
  static const Map<String, TrialFailure> errorCodeToFailure = {
    'trial_quota_exhausted': TrialFailure.quotaExhausted,
    'trial_not_configured': TrialFailure.notConfigured,
    'input_type_unsupported': TrialFailure.inputUnsupported,
    'trial_ip_rate_limited': TrialFailure.rateLimited,
    'trial_ip_daily_limited': TrialFailure.rateLimited,
    'rate_limited': TrialFailure.rateLimited,
    'trial_uppool_exhausted': TrialFailure.poolBusy,
    'trial_agent_required': TrialFailure.identityRejected,
    'prompt_too_large': TrialFailure.promptTooLarge,
    'messages_required': TrialFailure.badRequest,
  };

  /// 把异常文案归类；认不出来返回 null（调用方按普通故障继续走）。
  ///
  /// 两级判定：① 先认**服务端错误码串**；② 退一步认**裸状态码**。
  /// `\b` 词边界是必须的：否则 `1402` / `1202` 这类数字会被误判成 402
  /// （0.56.0 的单测已经钉过这一条，不能回退）。
  static TrialFailure? classifyTrialError(String errorText) {
    if (errorText.isEmpty) return null;
    for (final e in errorCodeToFailure.entries) {
      if (errorText.contains(e.key)) return e.value;
    }
    for (final e in statusToFailure.entries) {
      if (RegExp('\\b${e.key}\\b').hasMatch(errorText)) return e.value;
    }
    return null;
  }

  /// 402/额度耗尽的错误识别（0.56.0 的旧入口，保留为薄封装）。
  ///
  /// 语义**收窄为"只认耗尽"**：识别到限流 / 未配置等其它类别时返回 false，
  /// 由 [classifyTrialError] 的分支去给对应文案 —— 否则"20 轮用完"和
  /// "服务器限流"会被同一张引导卡吞掉，用户会以为充值能解决限流。
  static bool isQuotaExhaustedError(String errorText) =>
      classifyTrialError(errorText) == TrialFailure.quotaExhausted;

  /// 向官方 Hub 查询剩余试用轮数（`GET /api/trial/quota`）。
  /// 非 trial 模式 / 未配置 / 网络异常 → null（UI 显示"未知"）。
  static Future<int?> fetchRemainingTurns([SharedPreferences? prefs]) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      if (p.getString(modeKey) != trialModeValue) return null;
      final hub = p.getString('base_url') ?? '';
      final agentId = p.getString('api_key') ?? '';
      if (hub.isEmpty || agentId.isEmpty) return null;
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final req = await client.getUrl(
            Uri.parse('$hub/quota?agent_id=$agentId'));
        final res = await req.close().timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) return null;
        final body = await res.transform(utf8.decoder).join();
        return parseRemaining(body);
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// 解析余量查询响应（`{used, limit}`）→ 剩余轮数；任何异常返回 null
  ///（UI 对 null 显示"未知"而不是 0——网络抖动不该伪装成额度用完）。
  /// 数字以字符串形态出现也算数（宽松解析，端点数据形态变化时 UI 不崩）。
  static int? parseRemaining(String body) {
    try {
      final Map<String, dynamic> j =
          jsonDecode(body) as Map<String, dynamic>;
      final used = int.tryParse('${j['used']}');
      final limit = int.tryParse('${j['limit']}');
      if (used == null || limit == null) return null;
      final remaining = limit - used;
      return remaining < 0 ? 0 : remaining;
    } catch (_) {
      return null;
    }
  }
}
