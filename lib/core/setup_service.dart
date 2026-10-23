import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// ============================================================
/// 新手接入向导的底层服务：模型预设 + 真实连通性测试 + 错误归类。
///
/// 设计目标（对应《商业落地计划书》Phase 0 的"三分钟接入向导"）：
/// 让完全不懂技术的用户在 3 分钟内完成「选模型 → 填 key → 测通 → 开启社交」，
/// 每一步的错误都说清"哪里错了、怎么办"，绝不抛技术栈给用户。
///
/// ★ 0.110.0（本地化修复）：**本文件只产语言无关的结果码，不再拼用户可见文案**。
/// 此前 `testHub` / `testModel` / `_mapHttpError` 把结论写成硬编码中文字面量，
/// 症状是「英语版引导页测试中转站，弹出的是中文」（用户看演示视频实测）。
/// 现在返回 [SetupTestResult]（ok + [SetupResultCode] + detail/status），
/// 文案由 UI 层 `lib/ui/setup_result_text.dart` **渲染时**按当前语言解析
/// —— 引导页第 1 步可切语言，早先跑完的测试结果必须跟着变语言。
///
/// ⚠️ **本文件必须保持零依赖（只 import `dart:*`）**：`tool/verify_setup_service.dart`
/// 用纯 `dart run` import 它（起本地 HttpServer 离线复算整张错误映射表）。
/// 一旦 import `l10n_holder`（→ flutter / shared_preferences），那条守卫会
/// 直接 `dart:ui is not available` 崩掉 —— "网络路径没法离线验"就是这么来的。
/// ============================================================

/// 模型服务商预设（全部为 OpenAI 兼容接口，可直接被现有引擎使用）。
///
/// ★ 展示文案（label / note / keyHint）**不存常量**：按 `id` 在 UI 层
/// （`lib/ui/setup_result_text.dart` 的 `setupPresetText`）走 ARB 五语种解析。
/// 常量字段只剩 `id` / `baseUrl` / `defaultModel` —— 这三个是**配置事实**，与语言无关。
class ModelPreset {
  final String id;
  final String baseUrl;
  final String defaultModel;

  const ModelPreset({
    required this.id,
    required this.baseUrl,
    required this.defaultModel,
  });
}

/// 测试结果的**语言无关原因码**。UI 文案由 `lib/ui/setup_result_text.dart`
/// 的 `setupResultText(result, l10n)` 解析；落库 / 日志若需记录原因，记 code
/// （不记语言文本 —— 语言文本会随用户切语言而过期）。
enum SetupResultCode {
  // testModel：前置校验
  modelEmptyUrl,
  modelBadUrl,
  modelEmptyKey,
  modelEmptyName,
  // testModel：结果
  modelOk,
  modelTls,
  modelUnreachable,
  modelTimeout,
  modelFail,
  // testHub：前置校验与响应判定
  hubEmpty,
  hubBadUrl,
  hubBadStatus,
  hubOk,
  hubNotOurs,
  hubUnreachable,
  hubTimeout,
  hubFail,
  // _mapHttpError：按状态码归类
  http400,
  http401,
  http402,
  http404,
  http429,
  http5xx,
  httpOther,
}

/// 测试结果：**语言无关**的结论（标题/正文/建议由 UI 层按当前语言渲染）。
class SetupTestResult {
  final bool ok;

  /// 语言无关原因码（见 [SetupResultCode]）。
  final SetupResultCode code;

  /// 服务商返回的错误原文 / 异常摘要（可空；UI 层决定用不用）。
  final String? detail;

  /// HTTP 状态码（仅 http* 与 [SetupResultCode.hubBadStatus] 使用）。
  final int? status;

  const SetupTestResult({
    required this.ok,
    required this.code,
    this.detail,
    this.status,
  });
}

class SetupService {
  SetupService._();

  /// ============================================================
  /// 大荒官方线上后端地址 —— App 的**内置默认值**（用户无需手敲）
  /// ============================================================
  ///
  /// 为什么必须内置：这两个地址是**产品自己提供的服务**。让新用户从零手输，
  /// 既容易拼错（多一个斜杠 / 少一个字母 → 只会报"连接失败"，看不出错在哪），
  /// 又与《两台真机测试_国内服务器操作单》里让用户**照抄**的地址不一致 ——
  /// 手册写着 `https://hub.wold.world`，App 里却是一片空白。
  ///
  /// ⚠️ **校验日期：2026-10-02**。实查两条 `/health` 均 `HTTP 200 {"ok":true,...}`：
  ///   - `https://hub.wold.world/health`   → agents / messages 计数正常
  ///   - `https://world.wold.world/health` → rooms / members / present 计数正常
  /// 换域名 / 换服务商时**只改这一处**（引导页、设置页、真机手册同源）。
  ///
  /// ★ 注意这里只定义"默认值"，**不改变"未配置 → 空 → 调用方早退"** 的解析策略
  /// （见 `hub_endpoint.dart` / `cloud_service.dart`）：用户把地址清空仍表示
  /// "我不连云端"，那是他显式做的决定，不能被默认值悄悄推翻。
  static const String defaultHubUrl = 'https://hub.wold.world';
  static const String defaultWorldUrl = 'https://world.wold.world';

  /// 官网（landing 静态站）—— 隐私政策 / 服务条款两份**法务文档**的宿主。
  ///
  /// ⚠️ **顶点域 `wold.world` 当前无 A 记录**（2026-10-06 实测：`https://wold.world/`
  /// 解析失败 `ENOTFOUND`，而同源的 `https://hub.wold.world/health` 返回 `200`）。
  /// 即：App 内这两个入口在 **landing 部署 + 顶点记录建起来之前打不开** ——
  /// 这是**刻意留下的诚实状态**，不是漏配（见 CHANGELOG `[0.54.0]` 诚实边界）。
  /// 之所以现在就把入口做进 App：§14.3 顺序铁律保证「Landing 上线」**先于**「发布 APK」，
  /// 所以**真正送出去的构建里这两个链接是有效的**（上架表单也要求隐私政策可达）。
  ///
  /// ★ 与 `defaultHubUrl` / `defaultWorldUrl` **同一纪律：出厂地址只此一处** ——
  ///   换域名时只改这一行（App 侧一律走这个常量，不准出现裸 `https://wold.world`）。
  static const String defaultWebUrl = 'https://wold.world';

  /// 中转站访问 Key 的**申请入口**（ADR-002 准入闸的配套）。
  ///
  /// 为什么必须是常量：官方中转站启用准入（一键部署 `-Registration key`）后，
  /// 新用户唯一的出路就是"去哪申请 Key"。这个渠道由运营方（主人）掌握，App 只
  /// 负责把它显示成一个按钮 —— 与 `defaultHubUrl` 同一纪律：**只此一处**，
  /// 界面里不准内嵌链接（换群 / 换渠道时只改这一行）。
  ///
  /// ⚠️ **空字符串 = 不显示申请按钮**（刻意保留的安全阀）：没有真实可用
  ///   的申请渠道时，宁可不显示按钮，也绝不放一个占位链接 —— 假入口比没有
  ///   入口更坏（用户点进去发现打不开，比压根不出现更失信）。
  ///   填值时机：主人提供真实的群 / 社交渠道链接后，只改这一行。
  static const String hubKeyApplyUrl = '';

  /// 解析"后端地址输入框该显示什么"（**纯函数**，可离线断言）。
  ///
  /// 判据是 **键是否存在**，不是值是否为空 —— 这条规则由引导页与设置页共用，
  /// 所以只能有一份实现：两处一旦分叉，症状就是"设置里清空了、引导里又冒出来"，
  /// 而且这种漂移在界面上极难看出是同一件事。
  ///   - `keyPresent == false`（用户从没设过）→ 出厂官方默认值；
  ///   - `keyPresent == true`（设过，哪怕存的是空串）→ 原样返回。
  ///     "存了空串"是用户**显式清空**（我不连云端）的决定，不能被默认值翻案。
  static String resolveStoredOrDefault({
    required bool keyPresent,
    required String? stored,
    required String fallback,
  }) =>
      keyPresent ? (stored ?? '') : fallback;

  /// 预设列表：国内用户优先 DeepSeek（便宜、直连稳定），海外用户可选 OpenAI。
  ///
  /// ⚠️ **各家模型名会被官方下线（不是"过时"而是"调用直接报错"）**，所以下面每一项都
  /// 钉住"核对日期 + 官方出处"。下次复核请逐条对照官方文档，不要凭印象改：
  ///   - DeepSeek  ：api-docs.deepseek.com/updates
  ///                 （deepseek-chat / deepseek-reasoner 已于 2026-07-24 停用）
  ///   - OpenAI    ：platform.openai.com/docs/models
  ///   - Kimi 月之暗面：platform.moonshot.cn/docs/pricing
  ///                 （moonshot-v1 全系 + kimi-k2.5 已于 2026-08-31 下线）
  ///   - 智谱 GLM  ：docs.bigmodel.cn/cn/guide/start/model-overview
  ///   - 通义千问  ：help.aliyun.com/zh/model-studio（OpenAI 兼容模式支持的模型列表）
  ///   - 硅基流动  ：siliconflow.cn 模型广场 / siliconflow.com/models
  ///
  /// ★ 选型规则：**保持每个预设原有的档位不变，只把型号升到该档位的最新一代**。
  ///   原来给的是免费/便宜档（新用户第一次点"测试连接"不该先付费），升级后仍是免费/便宜档。
  ///   要改旗舰档请连同 ARB 里 `setupPreset*Note` 的价格说明一起改。
  ///
  /// 最后核对：2026-10-02。
  static const List<ModelPreset> presets = [
    ModelPreset(
      id: 'deepseek',
      baseUrl: 'https://api.deepseek.com',
      // 旧值 deepseek-chat 已于 2026-07-24 停用（调用直接 HTTP 报错）；
      // 换 V4 系列的经济档（284B/13B，1M 上下文，官方推荐的高性价比默认）
      defaultModel: 'deepseek-v4-flash',
    ),
    ModelPreset(
      id: 'openai',
      baseUrl: 'https://api.openai.com/v1',
      // 旧值 gpt-4o-mini 属 4o 世代；换 5.6 世代里"成本敏感"档（官方原话 cost-sensitive workloads）
      defaultModel: 'gpt-5.6-luna',
    ),
    ModelPreset(
      id: 'kimi',
      baseUrl: 'https://api.moonshot.cn/v1',
      // 旧值 moonshot-v1-8k 已于 2026-08-31 下线（返回 404）；kimi-k3 是官方通知里的迁移目标
      defaultModel: 'kimi-k3',
    ),
    ModelPreset(
      id: 'glm',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      // 旧值 glm-4-flash 是免费档；换最新的免费文本档（200K 上下文），保住"有免费档位"的承诺
      defaultModel: 'glm-4.7-flash',
    ),
    ModelPreset(
      id: 'qwen',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      // 旧值 qwen-plus 是滚动别名（仍可用）；钉成 Plus 档最新具体型号，避免"名字看着一样、背后偷偷换代"
      defaultModel: 'qwen3.7-plus',
    ),
    ModelPreset(
      id: 'siliconflow',
      baseUrl: 'https://api.siliconflow.cn/v1',
      // 旧值 DeepSeek-V3；V3.2 是硅基流动已上架（serverless 可用）的最新 DeepSeek 系
      defaultModel: 'deepseek-ai/DeepSeek-V3.2',
    ),
    ModelPreset(
      id: 'custom',
      baseUrl: '',
      defaultModel: '',
    ),
  ];

  static ModelPreset presetById(String id) {
    return presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
  }

  /// 地址规范化：去掉末尾斜杠和多余空格，避免用户多打一个 / 就失败。
  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// 真实调用一次模型接口，验证「地址 + 密钥 + 模型名」三者是否可用。
  static Future<SetupTestResult> testModel({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    final base = normalizeBaseUrl(baseUrl);
    final key = apiKey.trim();
    final modelName = model.trim();

    if (base.isEmpty) {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.modelEmptyUrl);
    }
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.modelBadUrl);
    }
    if (key.isEmpty) {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.modelEmptyKey);
    }
    if (modelName.isEmpty) {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.modelEmptyName);
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.parse('$base/chat/completions');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $key');
      request.write(jsonEncode({
        'model': modelName,
        'messages': [
          {'role': 'user', 'content': '你好'}
        ],
        'max_tokens': 8,
        'stream': false,
      }));

      final response =
          await request.close().timeout(const Duration(seconds: 25));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == HttpStatus.ok) {
        return const SetupTestResult(ok: true, code: SetupResultCode.modelOk);
      }
      return _mapHttpError(response.statusCode, body);
    } on HandshakeException {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.modelTls);
    } on SocketException {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.modelUnreachable);
    } on TimeoutException {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.modelTimeout);
    } catch (e) {
      return SetupTestResult(
        ok: false,
        code: SetupResultCode.modelFail,
        detail: _short(e.toString()),
      );
    } finally {
      client.close();
    }
  }

  /// 测试中转站（Hub）是否可用。
  static Future<SetupTestResult> testHub(String hubUrl) async {
    final base = normalizeBaseUrl(hubUrl);
    if (base.isEmpty) {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.hubEmpty);
    }
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.hubBadUrl);
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('$base/health');
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != HttpStatus.ok) {
        return SetupTestResult(
          ok: false,
          code: SetupResultCode.hubBadStatus,
          status: response.statusCode,
        );
      }
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['ok'] == true) {
          return const SetupTestResult(ok: true, code: SetupResultCode.hubOk);
        }
      } catch (_) {
        // 不是 JSON，继续走下面的"不是我们的服务"分支
      }
      return const SetupTestResult(
          ok: false, code: SetupResultCode.hubNotOurs);
    } on SocketException {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.hubUnreachable);
    } on TimeoutException {
      return const SetupTestResult(
          ok: false, code: SetupResultCode.hubTimeout);
    } catch (e) {
      return SetupTestResult(
        ok: false,
        code: SetupResultCode.hubFail,
        detail: _short(e.toString()),
      );
    } finally {
      client.close();
    }
  }

  // ------------------------------------------------------------------
  // 内部工具
  // ------------------------------------------------------------------

  /// 把 HTTP 错误归类成用户能看懂的原因（**只归类**，文案见 ARB `setupHttp*` 键）。
  static SetupTestResult _mapHttpError(int status, String body) {
    final detail = _extractApiMessage(body);
    switch (status) {
      case 400:
        return SetupTestResult(
          ok: false,
          code: SetupResultCode.http400,
          detail: detail,
          status: status,
        );
      case 401:
      case 403:
        return SetupTestResult(
          ok: false,
          code: SetupResultCode.http401,
          detail: detail,
          status: status,
        );
      case 402:
        return SetupTestResult(
          ok: false,
          code: SetupResultCode.http402,
          detail: detail,
          status: status,
        );
      case 404:
        return SetupTestResult(
          ok: false,
          code: SetupResultCode.http404,
          detail: detail,
          status: status,
        );
      case 429:
        return SetupTestResult(
          ok: false,
          code: SetupResultCode.http429,
          detail: detail,
          status: status,
        );
      default:
        if (status >= 500) {
          return SetupTestResult(
            ok: false,
            code: SetupResultCode.http5xx,
            detail: detail,
            status: status,
          );
        }
        return SetupTestResult(
          ok: false,
          code: SetupResultCode.httpOther,
          detail: detail,
          status: status,
        );
    }
  }

  /// 从服务商返回的 JSON / 文本里提取人类可读的错误说明
  static String? _extractApiMessage(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] is String) {
          return _short(err['message'] as String);
        }
        if (decoded['message'] is String) {
          return _short(decoded['message'] as String);
        }
      }
    } catch (_) {
      // 非 JSON：直接截断原文
    }
    return _short(body);
  }

  static String _short(String s) {
    final oneLine = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length > 160 ? '${oneLine.substring(0, 160)}…' : oneLine;
  }
}
