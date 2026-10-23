/// M8 · 试用额度代调网关 + 计费埋点 + 内容安全（PRD §4 M8 / §8 成本 / §9.1 红线）。
///
/// ---------------------------------------------------------------------------
/// 这一层的**立身前提**：代调会把我们的法律身份换掉
/// ---------------------------------------------------------------------------
/// PRD §4 M8 那条警告不是"注意事项"，而是本模块存在的理由：
///
/// > BYOK 时是**用户**调用他们的模型；代调时是**我们**在调用 ——
/// > **我们从"传话人"变成了"内容生产者"**：
/// > 中国（生成式 AI 服务提供者责任）、欧盟（AI Act deployer 义务）、
/// > 美国（AI 披露义务主体）**全部落到我们头上**。
/// > 因此体验额度必须**极小且限定用途**，把合规敞口压到最小。
///
/// 所以本模块的第一条设计不是"怎么代调"，而是"**怎么保证不代调的时候绝对不代调**"：
/// **默认关闭，显式开启；用途白名单；额度落库；单次封顶；全链路留痕。**
/// 这样一来，"额度极小 + 限用途"这条缓释措施就是**代码里的事实**，而不是文档里的承诺。
///
/// ---------------------------------------------------------------------------
/// 四条铁律（本层强制，且全部可离线复算）
/// ---------------------------------------------------------------------------
/// 1. **默认不代调**（fail-closed）。`enabled == false` 时一律拒，且不因为"额度还有"
///    就放行。开关是**显式**的：不打开就没有合规敞口，这是本模块能先于法域决策落地的原因。
/// 2. **限用途**：只有白名单里的用途可代调（onboarding 体验额度 / social_bridge 社交额度）。
///    未知用途 → 拒。每加一个用途 = 扩大一次敞口，必须同步改 PRD §9.1。
/// 3. **额度必须落库，不能只记在内存**。内存计数会在 App 重启时归零 ——
///    那"额度极小"就成了可以靠重启无限刷的空话，缓释措施直接失效。
/// 4. **计费可复算**：`token × 单价 → 分`，且**向上取整**（宁可高估平台成本，也不低报）。
///    真实计费以服务端返回为准，本层估算只用于**上限判定**。
///
/// 本文件**零平台依赖**（不 import `flutter` / `sqflite` / `shared_preferences`；
/// 只用 `dart:convert` + `package:crypto` + `pii_detector.dart`），
/// `dart run tool/verify_trial_gateway.dart` 可直接复算全部判定。

library;

import 'dart:convert';

import 'package:crypto/crypto.dart' as c;

import 'pii_detector.dart';

/// 本模块产生的埋点事件名。
///
/// ⚠️ **取值必须与 `telemetry.dart#TelemetryEvents` 的对应常量逐字相同** ——
/// `_track` 直接把这些字符串当事件名塞进埋点，两边一旦漂移，
/// 计费与合规审计就会**静默丢数据**（不报错，只是查不到）。
/// `tool/verify_trial_gateway.dart` 有断言盯住这个等式。
abstract final class TrialEvents {
  static const String quotaGranted = 'trial_quota_granted';
  static const String quotaRefused = 'trial_quota_refused';
  static const String quotaRevoked = 'trial_quota_revoked';
  static const String gatewayAllow = 'trial_gateway_allow';
  static const String gatewayDeny = 'trial_gateway_deny';
  static const String usage = 'trial_usage';
  static const String safetyBlocked = 'trial_safety_blocked';
}

/// 代调用途（**白名单**，PRD §4 M8 的"限用途"）。
///
/// ⚠️ 这张表的**长度就是合规敞口的大小**。当前刻意**不包含**：
/// - 普通聊天 `chat` —— 敞口无限大，等于把整个产品变成代调产品；
/// - 工具/插件调用 `tool` —— 会把生产内容的能力交给模型，责任更重；
/// - 批量/后台 `bulk` —— 无法做逐条内容安全。
///
/// 要加任何一项，必须先在 PRD §9.1 写清楚缓释措施，再回来改这张表。
abstract final class TrialPurpose {
  /// **体验额度**（PRD：装完即可用，约 20 条对话，用于感受分身质量 + 完成 onboarding）。
  static const String onboarding = 'onboarding';

  /// **社交额度**（PRD：完成首次入场进圈后发放，用于分身社交）。
  /// 与入场绑定，是因为 PRD 明确"不把付费钩子白送在漏斗顶端"。
  static const String socialBridge = 'social_bridge';

  static const List<String> allowlist = [onboarding, socialBridge];

  static bool isAllowed(String purpose) => allowlist.contains(purpose);
}

/// 额度与封顶常量（PRD §8 成本模型的具体化）。
///
/// 为什么把"极小"写成常量而不是配置：配置可以被运营改大，而**改大 = 扩大合规敞口**。
/// 写成编译期常量后，任何想放大额度的改动都必须**改代码并发版**，
/// 从而强制走一次 PRD §9.1 的复核（这就是把产品红线钉进物理结构的做法，同 M9 的单层分成）。
abstract final class TrialCaps {
  /// 体验额度：20 条对话/人（PRD §8 原文"约 20 条对话"）。
  static const int onboardingTurns = 20;

  /// 社交额度：PRD 只写"较大"且与入场绑定，未给数。
  /// 取 30 的理由：按 PRD §8 的预算反推（¥0.5/人 ≈ 50 分），
  /// 以 3.5 分/条的粗估单价算，50 分只够约 14 条 —— 所以**真正兜底的是 [perUserBudgetCents]，
  /// 不是条数**。条数是体验口径，金额才是合规口径。
  static const int socialBridgeTurns = 30;

  /// **每人预算上限（分）**：¥0.5 = 50 分（PRD §8：1000 人 × ¥0.5 ≈ ¥500 获客预算）。
  /// 这是"额度极小"的**硬口径** —— 条数用完或钱用完，先到者为准。
  static const int perUserBudgetCents = 50;

  /// 单次输入字符上限（超出即拒，不做截断 —— 截断会产生"半截指令"的不可预期行为）。
  static const int maxPromptChars = 4000;

  /// 单次输出 token 上限。
  static const int maxOutputTokens = 700;

  /// 节奏闸：每小时最多代调次数（防短时间烧穿额度，与 App 端 `SocialBudget` 双保险）。
  static const int maxCallsPerHour = 10;

  /// 额度有效期（天）。过期即失效 —— 不设有效期等于"永不回收的敞口"。
  static const int quotaValidDays = 30;
}

/// 一份**已授权的额度**（落库，不是内存计数）。
///
/// 两道闸，先到者为准：
/// - 条数闸 `grantedTurns` —— 体验口径；
/// - 金额闸 `budgetCents` —— **合规口径**（这才是"额度极小"的实体）。
class TrialQuota {
  final String agentId;
  final String purpose;

  final int grantedTurns;
  int usedTurns;

  final int budgetCents;
  int spentCents;

  final int grantedAtMs;
  final int? expiresAtMs;

  /// 非空 = 已被吊销（如用户转 BYOK 后立即收回敞口）。
  final int? revokedAtMs;

  TrialQuota({
    required this.agentId,
    required this.purpose,
    required this.grantedTurns,
    this.usedTurns = 0,
    required this.budgetCents,
    this.spentCents = 0,
    required this.grantedAtMs,
    this.expiresAtMs,
    this.revokedAtMs,
  });

  bool get revoked => revokedAtMs != null;
  bool expiredAt(int nowMs) => expiresAtMs != null && nowMs > expiresAtMs!;
  bool get turnsLeft => usedTurns < grantedTurns;
  bool budgetLeft(int extraCents) => spentCents + extraCents <= budgetCents;

  int get remainingTurns =>
      grantedTurns - usedTurns < 0 ? 0 : grantedTurns - usedTurns;
  int get remainingCents =>
      budgetCents - spentCents < 0 ? 0 : budgetCents - spentCents;

  /// 消费一次（**先判定后扣**，见 `TrialGateway.decide`；调用方拿到 `ok` 才能调这里）。
  void consume(int costCents) {
    usedTurns += 1;
    spentCents += costCents;
  }

  Map<String, Object?> toMap() => {
        'agent_id': agentId,
        'purpose': purpose,
        'granted_turns': grantedTurns,
        'used_turns': usedTurns,
        'budget_cents': budgetCents,
        'spent_cents': spentCents,
        'granted_at': grantedAtMs,
        'expires_at': expiresAtMs,
        'revoked_at': revokedAtMs,
      };

  static TrialQuota fromMap(Map<String, dynamic> m) => TrialQuota(
        agentId: (m['agent_id'] as String?) ?? '',
        purpose: (m['purpose'] as String?) ?? '',
        grantedTurns: (m['granted_turns'] as num?)?.toInt() ?? 0,
        usedTurns: (m['used_turns'] as num?)?.toInt() ?? 0,
        budgetCents: (m['budget_cents'] as num?)?.toInt() ?? 0,
        spentCents: (m['spent_cents'] as num?)?.toInt() ?? 0,
        grantedAtMs: (m['granted_at'] as num?)?.toInt() ?? 0,
        expiresAtMs: (m['expires_at'] as num?)?.toInt(),
        revokedAtMs: (m['revoked_at'] as num?)?.toInt(),
      );
}

/// 网关拒绝码（UI 侧翻译成文案；**每一个码都必须可被审计**）。
abstract final class GatewayCode {
  static const String ok = 'ok';

  /// 代调开关未开 —— **默认状态**（铁律 1）。
  static const String disabled = 'proxy_disabled';

  /// 用途不在白名单（铁律 2）。
  static const String purposeNotAllowed = 'purpose_not_allowed';

  /// 该用途没有授权额度（未发放 / 未入场）。
  static const String noQuota = 'no_quota';

  /// 条数用完。
  static const String quotaExhausted = 'quota_exhausted';

  /// 金额用完（**合规口径**，比条数更硬）。
  static const String overBudget = 'over_budget';

  /// 额度过期。
  static const String quotaExpired = 'quota_expired';

  /// 额度已被吊销。
  static const String quotaRevoked = 'quota_revoked';

  /// 节奏闸：短时间内调用过密。
  static const String rateLimited = 'rate_limited';

  /// 单次输入超过字符上限。
  static const String overCap = 'over_cap';

  /// 服务商不在白名单（防止把用户文本送到未经评估的第三方）。
  static const String providerNotAllowed = 'provider_not_allowed';

  /// 入站提示命中注入模式。
  static const String promptBlocked = 'prompt_blocked';

  /// 出站（模型产出）命中敏感信息 —— 代调时是我们生产内容，绝不把 PII 送进社交网络。
  static const String outputBlocked = 'output_blocked';
}

/// 内容安全判定（`SafetyGate` 的返回）。
class SafetyVerdict {
  final bool allow;
  final String code;

  /// 脱敏后**实际送出**的文本（命中 PII 时会被打码，而不是原样送出去）。
  final String? sanitized;

  /// 是否发生过打码。
  final bool masked;

  const SafetyVerdict({
    required this.allow,
    required this.code,
    this.sanitized,
    this.masked = false,
  });
}

/// 内容安全闸（**双向**）。
///
/// 为什么代调比 BYOK 更需要它：BYOK 是用户自己把文本送给服务商，
/// 代调是**我们**把用户的文本送给服务商 —— 中间多了一个责任主体（我们）。
/// 所以入站要拦注入、出站要拦 PII，且**两侧都必须留痕**。
abstract final class SafetyGate {
  /// 已知提示注入模式（**启发式**，只拦已知形态）。
  ///
  /// ⚠️ 诚实边界：正则挡不住 paraphrase 的注入。真正的防线是
  /// **用途白名单 + 额度极小 + 输出上限**，不是这套正则。
  /// 把它当成"拦住脚本小子"，不要当成"解决了注入"。
  static final List<RegExp> injectionPatterns = [
    RegExp(r'ignore\s+(all\s+)?(previous|prior|above)\s+instructions',
        caseSensitive: false),
    RegExp(r'disregard\s+(all\s+)?(previous|prior)\s+', caseSensitive: false),
    RegExp(r'忽略(之前|上面|前述|以上)的(所有)?(指令|提示|规则)'),
    RegExp(r'(你现在是|you are now)\s*\S{0,20}(模型|AI|assistant)',
        caseSensitive: false),
    RegExp(r'<\s*/?\s*(system|assistant)\s*>', caseSensitive: false),
    RegExp(r'(reveal|print|output)\s+(your\s+)?(system\s+)?prompt',
        caseSensitive: false),
    RegExp(r'(输出|打印|泄露).{0,6}(系统提示|system\s*prompt)', caseSensitive: false),
  ];

  static bool matchesInjection(String text) {
    for (final p in injectionPatterns) {
      if (p.hasMatch(text)) return true;
    }
    return false;
  }

  /// **入站闸**：判断这段提示能否被送去服务商。
  ///
  /// 顺序：注入 → 长度 → PII（PII **打码放行**而不是拦死：
  /// 一刀切会把正常聊天也堵死，而脱敏已经切断了"把 PII 送给第三方"这条责任链）。
  static SafetyVerdict screenForProvider(
    String text, {
    int maxChars = TrialCaps.maxPromptChars,
  }) {
    if (text.trim().isEmpty) {
      return const SafetyVerdict(allow: false, code: GatewayCode.overCap);
    }
    if (matchesInjection(text)) {
      return const SafetyVerdict(allow: false, code: GatewayCode.promptBlocked);
    }
    if (text.length > maxChars) {
      return const SafetyVerdict(allow: false, code: GatewayCode.overCap);
    }
    if (PiiDetector.containsSensitive(text)) {
      return SafetyVerdict(
        allow: true,
        code: GatewayCode.ok,
        sanitized: PiiDetector.maskSensitive(text),
        masked: true,
      );
    }
    return SafetyVerdict(allow: true, code: GatewayCode.ok, sanitized: text);
  }

  /// **出站闸**：模型产出的文本能否进入社交网络。
  ///
  /// 这里对 PII 是**拦死**而不是打码：模型产出若带 PII，说明上游已经出问题，
  /// 打码放行会把"模型在编造/复述敏感信息"这个信号盖掉。
  static SafetyVerdict screenModelOutput(String text) {
    if (text.trim().isEmpty) {
      return const SafetyVerdict(allow: true, code: GatewayCode.ok, sanitized: '');
    }
    if (PiiDetector.containsSensitive(text)) {
      return const SafetyVerdict(allow: false, code: GatewayCode.outputBlocked);
    }
    return SafetyVerdict(allow: true, code: GatewayCode.ok, sanitized: text);
  }
}

/// 一次代调请求。
class GatewayRequest {
  final String purpose;
  final String provider;
  final String model;
  final String prompt;
  final int maxOutputTokens;

  const GatewayRequest({
    required this.purpose,
    required this.provider,
    required this.model,
    required this.prompt,
    this.maxOutputTokens = TrialCaps.maxOutputTokens,
  });
}

/// 网关判定结果。
class GatewayDecision {
  final bool allow;
  final String code;
  final String detail;

  /// 实际应送出的文本（已脱敏）。被拒时为 null。
  final String? sanitizedPrompt;

  /// 是否发生过脱敏（进埋点，用于观察"多少代调带着 PII"）。
  final bool masked;

  /// 判定通过时预估的本次成本（分），供记账与"是否超预算"判定用。
  final int estimatedCostCents;

  const GatewayDecision({
    required this.allow,
    required this.code,
    this.detail = '',
    this.sanitizedPrompt,
    this.masked = false,
    this.estimatedCostCents = 0,
  });
}

/// 计费模型（**可复算**，单位：分）。
abstract final class CostModel {
  /// ⚠️ token 估算只是"粗估"：真实分词各家不同，且中文与英文差异极大。
  /// 它的**唯一用途是上限判定与预算预估**；真实计费以服务端返回的 usage 为准。
  /// 绝不拿它去跟用户对账 —— 那会变成"凭估算收钱"。
  static int estimateTokens(String text) =>
      text.trim().isEmpty ? 0 : (text.length / 3).ceil();

  /// 计费（分）：`token × 单价(分/百万 token)`，**向上取整**。
  ///
  /// 为什么向上取整：向下取整会系统性低报平台成本，
  /// 而 PRD §8 的 ¥500 预算是靠这个数守住的 —— 少报就是超支。
  static int costCents({
    required int promptTokens,
    required int completionTokens,
    required int promptPricePerMTokCents,
    required int completionPricePerMTokCents,
  }) {
    if (promptTokens < 0 ||
        completionTokens < 0 ||
        promptPricePerMTokCents < 0 ||
        completionPricePerMTokCents < 0) {
      throw ArgumentError('token 与单价必须 >= 0');
    }
    const unit = 1000000;
    final p = (promptTokens * promptPricePerMTokCents + unit - 1) ~/ unit;
    final cc = (completionTokens * completionPricePerMTokCents + unit - 1) ~/ unit;
    return p + cc;
  }
}

/// 一条**消费账本**条目（可被第三方独立复算，进 §16 公开只追加日志）。
class UsageLedgerEntry {
  /// 幂等键（同一次调用只落一条）。
  final String callId;

  final String agentId;
  final String purpose;
  final String provider;
  final String model;

  final int promptTokens;
  final int completionTokens;

  /// 本次成本（分）。
  final int costCents;

  final int atMs;

  const UsageLedgerEntry({
    required this.callId,
    required this.agentId,
    required this.purpose,
    required this.provider,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.costCents,
    required this.atMs,
  });

  /// 用给定单价**复算**本条成本是否对得上（第三方独立验账的入口）。
  bool costMatches({
    required int promptPricePerMTokCents,
    required int completionPricePerMTokCents,
  }) =>
      costCents ==
      CostModel.costCents(
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        promptPricePerMTokCents: promptPricePerMTokCents,
        completionPricePerMTokCents: completionPricePerMTokCents,
      );

  /// 叶子字节：只含公开字段、顺序固定 —— 任何第三方都能独立算出同一个哈希。
  List<int> logLeafBytes() => utf8.encode(jsonEncode({
        'kind': 'trial_usage',
        'call_id': callId,
        'agent_id': agentId,
        'purpose': purpose,
        'provider': provider,
        'model': model,
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'cost_cents': costCents,
        'at': atMs,
      }));

  String entryHash() => c.sha256.convert(logLeafBytes()).toString();

  Map<String, Object?> toMap() => {
        'call_id': callId,
        'agent_id': agentId,
        'purpose': purpose,
        'provider': provider,
        'model': model,
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'cost_cents': costCents,
        'at_ms': atMs,
      };

  static UsageLedgerEntry fromMap(Map<String, dynamic> m) => UsageLedgerEntry(
        callId: (m['call_id'] as String?) ?? '',
        agentId: (m['agent_id'] as String?) ?? '',
        purpose: (m['purpose'] as String?) ?? '',
        provider: (m['provider'] as String?) ?? '',
        model: (m['model'] as String?) ?? '',
        promptTokens: (m['prompt_tokens'] as num?)?.toInt() ?? 0,
        completionTokens: (m['completion_tokens'] as num?)?.toInt() ?? 0,
        costCents: (m['cost_cents'] as num?)?.toInt() ?? 0,
        atMs: (m['at_ms'] as num?)?.toInt() ?? 0,
      );
}

/// 代调网关判定（**纯函数、fail-closed**）。
abstract final class TrialGateway {
  /// 判定一次代调能否放行。
  ///
  /// 检查顺序是刻意的：**便宜的先、合规的先** ——
  /// 开关与用途在最前，额度其次，内容安全最后（它最贵）。
  /// 任何一步不过直接返回，绝不"部分通过"。
  ///
  /// [allowedProviders] 为空集 = 一个都不放行（fail-closed 的默认值）。
  /// [recentCalls] 用于节奏闸：近一小时内已发生的调用。
  static GatewayDecision decide({
    required bool enabled,
    required GatewayRequest req,
    required int nowMs,
    TrialQuota? quota,
    Set<String> allowedProviders = const {},
    List<UsageLedgerEntry> recentCalls = const [],
    int promptPricePerMTokCents = 0,
    int completionPricePerMTokCents = 0,
  }) {
    // 铁律 1：默认不代调。这一条必须先于一切 —— 包括"额度还很充裕"。
    if (!enabled) {
      return const GatewayDecision(
          allow: false, code: GatewayCode.disabled, detail: '代调未开启（默认状态）');
    }

    // 铁律 2：限用途
    if (!TrialPurpose.isAllowed(req.purpose)) {
      return GatewayDecision(
          allow: false,
          code: GatewayCode.purposeNotAllowed,
          detail: '用途 ${req.purpose} 不在白名单');
    }

    if (!allowedProviders.contains(req.provider)) {
      return GatewayDecision(
          allow: false,
          code: GatewayCode.providerNotAllowed,
          detail: '服务商 ${req.provider} 不在白名单');
    }

    if (quota == null) {
      return const GatewayDecision(
          allow: false, code: GatewayCode.noQuota, detail: '该用途没有授权额度');
    }
    if (quota.purpose != req.purpose) {
      return const GatewayDecision(
          allow: false, code: GatewayCode.noQuota, detail: '额度用途与请求用途不符');
    }
    if (quota.revoked) {
      return const GatewayDecision(allow: false, code: GatewayCode.quotaRevoked);
    }
    if (quota.expiredAt(nowMs)) {
      return const GatewayDecision(allow: false, code: GatewayCode.quotaExpired);
    }
    if (!quota.turnsLeft) {
      return const GatewayDecision(allow: false, code: GatewayCode.quotaExhausted);
    }

    // 内容安全闸（入站）
    final v = SafetyGate.screenForProvider(req.prompt);
    if (!v.allow) {
      return GatewayDecision(allow: false, code: v.code, detail: '入站内容安全拦截');
    }

    // 预估成本 → 金额闸（合规口径，比条数更硬）
    final estPrompt = CostModel.estimateTokens(v.sanitized ?? req.prompt);
    final est = CostModel.costCents(
      promptTokens: estPrompt,
      completionTokens: req.maxOutputTokens,
      promptPricePerMTokCents: promptPricePerMTokCents,
      completionPricePerMTokCents: completionPricePerMTokCents,
    );
    if (!quota.budgetLeft(est)) {
      return GatewayDecision(
          allow: false, code: GatewayCode.overBudget, detail: '本次预估 $est 分超出剩余预算');
    }

    // 节奏闸
    final inHour =
        recentCalls.where((e) => nowMs - e.atMs < 3600000).length;
    if (inHour >= TrialCaps.maxCallsPerHour) {
      return const GatewayDecision(allow: false, code: GatewayCode.rateLimited);
    }

    return GatewayDecision(
      allow: true,
      code: GatewayCode.ok,
      sanitizedPrompt: v.sanitized,
      masked: v.masked,
      estimatedCostCents: est,
    );
  }

  /// 造一份**体验额度**（装完即可用）。
  static TrialQuota onboardingQuota(String agentId, int nowMs) => TrialQuota(
        agentId: agentId,
        purpose: TrialPurpose.onboarding,
        grantedTurns: TrialCaps.onboardingTurns,
        budgetCents: TrialCaps.perUserBudgetCents,
        grantedAtMs: nowMs,
        expiresAtMs: nowMs + TrialCaps.quotaValidDays * 86400000,
      );

  /// 造一份**社交额度**（PRD：完成首次入场进圈后发放 —— 不白送在漏斗顶端）。
  static TrialQuota socialBridgeQuota(String agentId, int nowMs) => TrialQuota(
        agentId: agentId,
        purpose: TrialPurpose.socialBridge,
        grantedTurns: TrialCaps.socialBridgeTurns,
        budgetCents: TrialCaps.perUserBudgetCents,
        grantedAtMs: nowMs,
        expiresAtMs: nowMs + TrialCaps.quotaValidDays * 86400000,
      );
}

// ---------------------------------------------------------------------------
// 存储抽象（零依赖；SQLite 实现在 trial_store_db.dart）
// ---------------------------------------------------------------------------

/// 额度 + 消费账本的持久化抽象。
///
/// 抽出来只有一个目的 —— 但也正是本模块**最关键**的一条铁律：
/// **额度必须落库**。内存实现（[MemoryTrialStore]）只用于单测与离线复算，
/// 生产实现见 `trial_store_db.dart`；若哪天有人把额度改回内存计数，
/// `verify_trial_gateway` 里"额度落库"的断言会红。
abstract class TrialStore {
  Future<void> upsertQuota(TrialQuota q);
  Future<TrialQuota?> quota(String agentId, String purpose);
  Future<List<TrialQuota>> quotasOf(String agentId);

  Future<void> addUsage(UsageLedgerEntry e);
  Future<UsageLedgerEntry?> usage(String callId);
  Future<List<UsageLedgerEntry>> usageOf(String agentId, {int? sinceMs});
}

/// 内存实现（单测 / 离线复算用；**不落盘，重启即失** —— 正因如此它不能用于生产额度）。
class MemoryTrialStore implements TrialStore {
  final Map<String, TrialQuota> _quotas = {};
  final Map<String, UsageLedgerEntry> _usage = {};

  String _k(String a, String p) => '$a::$p';

  @override
  Future<void> upsertQuota(TrialQuota q) async => _quotas[_k(q.agentId, q.purpose)] = q;

  @override
  Future<TrialQuota?> quota(String agentId, String purpose) async =>
      _quotas[_k(agentId, purpose)];

  @override
  Future<List<TrialQuota>> quotasOf(String agentId) async => _quotas.values
      .where((q) => q.agentId == agentId)
      .toList();

  @override
  Future<void> addUsage(UsageLedgerEntry e) async => _usage[e.callId] = e;

  @override
  Future<UsageLedgerEntry?> usage(String callId) async => _usage[callId];

  @override
  Future<List<UsageLedgerEntry>> usageOf(String agentId, {int? sinceMs}) async =>
      _usage.values
          .where((e) => e.agentId == agentId && (sinceMs == null || e.atMs >= sinceMs))
          .toList();
}

// ---------------------------------------------------------------------------
// 服务层：把"纯判定"和"落库/埋点"串起来
// ---------------------------------------------------------------------------

/// 代调网关服务。
///
/// 刻意**不做**的事：不真的发 HTTP 去调服务商（那需要我方 API key，
/// 属"是否上线代调"的合规决策）。这里只保证**"能不能调、调了记多少"**这两件事
/// 算得对、算得可复算、且**默认一律不调**。
class TrialGatewayService {
  final TrialStore store;

  /// 代调总开关。**默认 false** —— 这是本模块的合规地基。
  bool enabled;

  /// 允许的服务商（空 = 一个都不放行）。
  Set<String> allowedProviders;

  final int promptPricePerMTokCents;
  final int completionPricePerMTokCents;

  final void Function(String kind, Map<String, Object?> data)? onEvent;

  TrialGatewayService({
    required this.store,
    this.enabled = false,
    this.allowedProviders = const {},
    this.promptPricePerMTokCents = 0,
    this.completionPricePerMTokCents = 0,
    this.onEvent,
  });

  Future<GatewayDecision> decide(
    GatewayRequest req, {
    required String agentId,
    required int nowMs,
  }) async {
    final quota = await store.quota(agentId, req.purpose);
    final recent = await store.usageOf(agentId, sinceMs: nowMs - 3600000);
    final d = TrialGateway.decide(
      enabled: enabled,
      req: req,
      nowMs: nowMs,
      quota: quota,
      allowedProviders: allowedProviders,
      recentCalls: recent,
      promptPricePerMTokCents: promptPricePerMTokCents,
      completionPricePerMTokCents: completionPricePerMTokCents,
    );
    _emit(d.allow ? TrialEvents.gatewayAllow : TrialEvents.gatewayDeny, {
      'purpose': req.purpose,
      'provider': req.provider,
      'code': d.code,
      'masked': d.masked,
      'est_cents': d.estimatedCostCents,
    });
    return d;
  }

  /// **记账并扣额度**。必须先拿到 `allow == true` 的 `GatewayDecision` 才能调。
  ///
  /// 幂等：同一 `callId` 只记一次（重复调用不会把额度扣两遍）。
  Future<UsageLedgerEntry?> consume({
    required String callId,
    required String agentId,
    required GatewayRequest req,
    required int promptTokens,
    required int completionTokens,
    required int nowMs,
  }) async {
    if (await store.usage(callId) != null) {
      return null; // 幂等
    }
    final entry = UsageLedgerEntry(
      callId: callId,
      agentId: agentId,
      purpose: req.purpose,
      provider: req.provider,
      model: req.model,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      costCents: CostModel.costCents(
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        promptPricePerMTokCents: promptPricePerMTokCents,
        completionPricePerMTokCents: completionPricePerMTokCents,
      ),
      atMs: nowMs,
    );
    await store.addUsage(entry);

    final q = await store.quota(agentId, req.purpose);
    if (q != null) {
      q.consume(entry.costCents);
      await store.upsertQuota(q);
    }
    _emit(TrialEvents.usage, {
      'call_id': callId,
      'purpose': req.purpose,
      'cost_cents': entry.costCents,
      'hash': entry.entryHash(),
    });
    return entry;
  }

  /// 发放体验额度（装完即可用）。
  Future<TrialQuota> grantOnboarding(String agentId, int nowMs) async {
    final q = TrialGateway.onboardingQuota(agentId, nowMs);
    await store.upsertQuota(q);
    _emit(TrialEvents.quotaGranted, {'purpose': q.purpose, 'turns': q.grantedTurns});
    return q;
  }

  /// 发放社交额度 —— **必须**在完成首次入场进圈之后调用（PRD §4 M8）。
  ///
  /// `enteredCircle` 为 false 时拒绝发放：免费资源要用在"我们要验证的行为"上，
  /// 不能白送在漏斗顶端。这是把 PRD 的一句产品判断写成**参数即约束**。
  Future<TrialQuota?> grantSocialBridge(
    String agentId,
    int nowMs, {
    required bool enteredCircle,
  }) async {
    if (!enteredCircle) {
      _emit(TrialEvents.quotaRefused,
          {'purpose': TrialPurpose.socialBridge, 'why': 'not_entered'});
      return null;
    }
    final q = TrialGateway.socialBridgeQuota(agentId, nowMs);
    await store.upsertQuota(q);
    _emit(TrialEvents.quotaGranted, {'purpose': q.purpose, 'turns': q.grantedTurns});
    return q;
  }

  /// 吊销额度（如用户转为 BYOK 后立即收回敞口）。
  Future<void> revoke(String agentId, String purpose, int nowMs) async {
    final q = await store.quota(agentId, purpose);
    if (q == null) return;
    final revoked = TrialQuota(
      agentId: q.agentId,
      purpose: q.purpose,
      grantedTurns: q.grantedTurns,
      usedTurns: q.usedTurns,
      budgetCents: q.budgetCents,
      spentCents: q.spentCents,
      grantedAtMs: q.grantedAtMs,
      expiresAtMs: q.expiresAtMs,
      revokedAtMs: nowMs,
    );
    await store.upsertQuota(revoked);
    _emit(TrialEvents.quotaRevoked, {'purpose': purpose});
  }

  void _emit(String kind, Map<String, Object?> data) => onEvent?.call(kind, data);
}
