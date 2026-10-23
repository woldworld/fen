import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;

import '../context/compactor.dart';
import '../context/context_manager.dart';
import '../session/agent_reply.dart';
import '../session/session_event.dart';
import '../session/session_store.dart';

/// 一轮对话的产物。
class TurnOutput {
  final String reply;
  final String topic;
  final String keywords;

  /// 是否走了降级路径（结构化失败回退普通 send / 离线本地模型）
  final bool degraded;

  /// 降级原因（观测用；正常轮为 null）
  final String? degradeReason;

  const TurnOutput({
    required this.reply,
    required this.topic,
    required this.keywords,
    this.degraded = false,
    this.degradeReason,
  });
}

/// Agent 运行时（M2）：结构化输出 + 多轮历史 + 超时 + 两级降级 + 轨迹落盘。
///
/// 降级链（每一级都不丢用户消息）：
/// 1. **主路径只发一次请求**：`send(outputSchema: …)`，拿到响应后做**两种解读**——
///    ① 能解成 `AgentReply` 的 JSON ⇒ 结构化结果；② 不是 JSON（模型吐了纯文本）
///    ⇒ **复用同一个响应的原文**当回复。**这一步不补发第二次请求**。
/// 2. 上面在**传输层**就失败了（上游拒绝 schema / 断网 / 超时）⇒ 是否补发一次
///    不带 schema 的普通 `send`，由 [allowPlainRetry] 决定（null = 允许）。
/// 3. 连这一步也失败 ⇒ [fallback]（宿主接本地小模型）。
/// 4. 全部失败 ⇒ rethrow，由宿主 UX 兜底（如"网络被劫持"诊断报告）。
///
/// ★ 为什么主路径不再"结构化失败就重发普通 send"（0.66.0）：
///   试用链路把模型调用经自家服务器转发，代理按「**非工具续跑轮 = 1 次额度**」
///   计数。同一轮若发两次（第一次带 schema、第二次不带），就**扣两次额度**，
///   而主人只看得见 1 条回复 —— 用户明确要求「看得见的才算 1 次」。故改为
///   单请求双解读；试用模式下再关掉 [allowPlainRetry]，把双计彻底堵死。
class AgentRuntime {
  AgentRuntime({
    required this.agentSource,
    this.fallback,
    this.allowPlainRetry,
    this.hasTools,
    this.timeout = const Duration(seconds: 150),
    this.historyMaxChars = 24000,
    this.maxHistoryEvents = 40,
    this.compactor,
  });

  /// 返回当前可用的 dartantic Agent；null = 未配置（无 API Key）。
  /// 每轮调用时取最新值，宿主热重建 Agent 后自动生效。
  final dartantic.Agent? Function() agentSource;

  /// 离线降级钩子（宿主接 LocalModelService 之类的端侧小模型）。
  final Future<String?> Function(String systemPrompt, String message)?
      fallback;

  /// 是否允许「传输层失败 → 再发一次不带 schema 的普通请求」。
  ///
  /// * `null`（默认）= 允许，与历史行为一致；
  /// * 宿主在**计费口径敏感**的链路（大荒的试用代调）传 `() async => false`
  ///   —— 因为同一轮发两次会被自家代理算成 2 次额度。
  final Future<bool> Function()? allowPlainRetry;

  /// 本轮**是否挂了可调工具**（宿主注入；包不反向依赖宿主，故用回调而非类型）。
  ///
  /// ★★ 0.80.0（真机复现的"改主题卡住"根因）：一次请求里**同时**下发
  ///   「严格结构化输出」与「工具」，会被相当一部分 OpenAI 兼容端点**优先满足
  ///   `response_format` 而跳过工具调用** —— 逐个实测/官方文档点名：DeepSeek、
  ///   Kimi（Moonshot）、DashScope(Qwen) 均属此列（AgentScope 的做法
  ///   `nativeStructuredOutputWithTools(false)` 就是同一结论）。后果是
  ///   **`tool_calls` 永不产生**：主人说"改成粉色主题"，分身只回话不动手，
  ///   还自认"忘了真正执行"（真机截图）。
  ///
  /// ★ 故本运行时定一条硬口径：**有工具 ⇒ 工具优先**，这一轮**不下发 schema**
  ///   （"解读②"本就能把纯文本原文当回复，功能不受损，只少一层
  ///   topic/keywords 的自动结构化）。
  ///
  /// * `null`（默认）= 视为"无工具"，保持历史行为（既有单测/其它消费者零改动）；
  /// * 宿主（大荒 `AgentService`）传 `() => _toolRegistry.snapshot().isNotEmpty`。
  final bool Function()? hasTools;

  final Duration timeout;


  /// 送入模型的历史字符预算（1 token ≈ 4 字符的粗估）
  final int historyMaxChars;

  /// 历史条数硬上限（字符预算之外的兜底，防单条超长事件挤占）
  final int maxHistoryEvents;

  /// 摘要折叠配置（null = 不折叠）。
  /// 宿主构造 [Compactor] 时注入 summarize 回调——必须用**无工具**的
  /// 辅助 Agent（如大荒的 _createTempAgent），摘要过程绝不能触发工具调用。
  final Compactor? compactor;

  /// 由会话轨迹组装多轮历史（user/assistant 交替，含摘要折叠）。
  /// 公开静态：可离线单测。
  static List<dartantic.ChatMessage> buildHistory({
    required String systemPrompt,
    required List<SessionEvent> events,
    int maxEvents = 40,
    int maxChars = 24000,
  }) {
    final history = <dartantic.ChatMessage>[
      dartantic.ChatMessage.system(systemPrompt),
    ];
    // M4：摘要折叠 + 字符预算选择（新消息优先），替代朴素窗口
    final recent = ContextManager(maxChars: maxChars)
        .selectRecent(events)
        .toList();
    if (recent.length > maxEvents) {
      recent.removeRange(0, recent.length - maxEvents);
    }
    for (final e in recent) {
      final text = e.data['text']?.toString() ?? '';
      if (text.isEmpty) continue;
      if (e.type == 'user_message') {
        history.add(dartantic.ChatMessage.user(text));
      } else if (e.type == 'assistant_message') {
        history.add(dartantic.ChatMessage.model(text));
      } else if (e.type == 'summary') {
        history.add(dartantic.ChatMessage.system('【此前对话摘要】$text'));
      }
    }
    return history;
  }

  /// 执行一轮对话。提供 [sessions]+[sessionId] 时自动落轨迹（用户消息先落，
  /// 保证"回复失败也不丢用户输入"）。
  Future<TurnOutput> turn({
    required String systemPrompt,
    required String message,
    List<dartantic.Part> attachments = const [],
    SessionStore? sessions,
    String? sessionId,
  }) async {
    final agent = agentSource();
    if (agent == null) {
      return const TurnOutput(
        reply: '请配置 API Key',
        topic: '未分类',
        keywords: '',
        degraded: true,
        degradeReason: 'no_agent',
      );
    }

    List<dartantic.ChatMessage> history = [
      dartantic.ChatMessage.system(systemPrompt),
    ];
    if (sessions != null && sessionId != null) {
      // M4：轨迹超限先摘要折叠（折叠失败/放弃静默跳过，绝不阻断主流程）
      if (compactor != null) {
        try {
          await compactor!.compactIfNeeded(sessions, sessionId);
        } catch (_) {}
      }
      final events = await sessions.replay(sessionId);
      history = buildHistory(
        systemPrompt: systemPrompt,
        events: events,
        maxEvents: maxHistoryEvents,
        maxChars: historyMaxChars,
      );
      // 用户消息先落盘（append-only，回复失败也不丢输入）
      await sessions.append(
          sessionId, SessionEvent(type: 'user_message', data: {'text': message}));
    }

    // ★★ 0.80.0：**有工具就不发 schema**（见 [hasTools] 注释）。判定抽成静态
    //   纯函数，离线可测、且被 `tool/verify_agent_tools.dart` 源码级钉住。
    final outputSchema =
        chooseOutputSchema(hasTools: hasTools?.call() ?? false);

    // ---- 主路径：**一次请求**，两种解读 ----
    // ★ 0.66.0：这里刻意不再"结构化失败就补发一次普通 send"。旧写法在同一轮
    //   会发两次真实请求（分属两个 HTTP 往返），在按"轮"计费/限次的链路里
    //   就是扣两次 —— 而用户只看得见 1 条回复。
    try {
      final result = await agent
          .send(
            message,
            outputSchema: outputSchema,
            history: history,
            attachments: attachments,
          )
          .timeout(timeout);
      final raw = result.output;

      // 解读 ①：结构化 JSON ⇒ 直接用（口径与旧 `sendFor` 完全一致，含空 reply）
      final structured = tryDecodeReply(raw);
      if (structured != null) {
        await _appendAssistant(
            sessions, sessionId, structured.reply, structured.topic);
        return TurnOutput(
          reply: structured.reply,
          topic: structured.topic,
          keywords: structured.keywords,
        );
      }

      // 解读 ②：不是 JSON（模型吐了纯文本）⇒ **复用同一响应**，不补发请求
      final text = raw.trim();
      if (text.isNotEmpty) {
        await _appendAssistant(sessions, sessionId, text, '日常交流');
        return TurnOutput(
          reply: text,
          topic: '日常交流',
          keywords: '',
          degraded: true,
          degradeReason: 'structured_output_unparsed_reused_response',
        );
      }

      // 响应空内容，视作传输层异常，交给下面的降级链
      throw const FormatException('模型返回了空内容');
    } catch (structuredError) {
      // ---- 传输层失败（拒绝 schema / 断网 / 超时）：是否补发由宿主决定 ----
      final allowPlain = allowPlainRetry == null || await allowPlainRetry!();
      if (allowPlain) {
        try {
          final plain = await agent
              .send(message, history: history, attachments: attachments)
              .timeout(timeout);
          final text = plain.output.trim();
          if (text.isNotEmpty) {
            await _appendAssistant(sessions, sessionId, text, '日常交流');
            return TurnOutput(
              reply: text,
              topic: '日常交流',
              keywords: '',
              degraded: true,
              degradeReason: 'structured_output_failed: $structuredError',
            );
          }
        } catch (_) {
          // 补发也失败 ⇒ 落到离线钩子
        }
      }

      // ---- 降级：完全失败 → 宿主离线钩子 ----
      final local =
          fallback == null ? null : await fallback!(systemPrompt, message);
      if (local != null && local.isNotEmpty) {
        const notice = '🔌 *(离线模式，本地模型回复)*';
        await _appendAssistant(
            sessions, sessionId, '$notice\n$local', '日常交流');
        return TurnOutput(
          reply: '$notice\n$local',
          topic: '日常交流',
          keywords: '',
          degraded: true,
          degradeReason: 'offline_fallback: $structuredError',
        );
      }
      rethrow;
    }
  }

  /// 「结构化输出 vs 工具调用」二选一的**唯一判据**（纯函数，离线可测）。
  ///
  /// ★★ 0.80.0：**有工具 ⇒ 返回 null（不下发 schema）**。
  ///   理由见 [hasTools]：`response_format(json_schema, strict)` 与 `tools`
  ///   同时出现时，DeepSeek/Kimi/DashScope 等会**优先满足 response_format 而
  ///   跳过工具调用** ⇒ `tool_calls` 永不产生，"改主题/发邮件/搜网页"一律
  ///   静默失效，而模型还会一本正经地"汇报完成"。
  ///   `null` 表示"本轮不要求结构化"：调用方 `agent.send(outputSchema: null)`
  ///   即回到纯文本，由"解读②"复用原文当回复 —— **功能不掉，只少一层
  ///   topic/keywords 自动结构化**。
  static dartantic.Schema? chooseOutputSchema({required bool hasTools}) =>
      hasTools ? null : AgentReply.outputSchema;

  /// 把模型原文**尝试**解成 [AgentReply]（纯函数，离线可测）。
  ///
  /// 返回 `null` 表示"这段文本不是结构化 JSON"——调用方应把它**按纯文本复用**，
  /// 而不是再发一次请求（那样会造成同轮双计）。容错口径：
  /// * 空串 ⇒ null；
  /// * 不是合法 JSON（模型回了纯文本）⇒ null；
  /// * 是 JSON 但不是对象（数组 / 数字 / 字符串）⇒ null，当纯文本处理。
  static AgentReply? tryDecodeReply(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(t);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    return AgentReply.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> _appendAssistant(
      SessionStore? sessions, String? sessionId, String text, String topic) async {
    if (sessions == null || sessionId == null) return;
    await sessions.append(
      sessionId,
      SessionEvent(type: 'assistant_message', data: {'text': text, 'topic': topic}),
    );
  }
}
