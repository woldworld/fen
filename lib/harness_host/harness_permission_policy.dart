import 'dart:async';

import 'package:pocket_harness/pocket_harness.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_events.dart';
import '../core/db_helper.dart';
import '../core/l10n_holder.dart';
import '../core/plugin_bus.dart';

/// pocket_harness `PermissionPolicy` 的宿主实现（M3）。
///
/// 四档统一原有双轨授权，**行为逐项照旧**：
/// - normal    直行（无闸内置工具 + 低风险 DB 插件）
/// - sensitive 首次弹窗、持久授权、可吊销（原 PluginBus grant/deny/revoke —— DB 插件）
/// - high      tool_auto_allow 白名单 → 60s fail-closed 弹窗（原 _requestToolPermission —— 内置高危）
/// - critical  同 high + 每次调用写审计；保留"参数级确认"语义
///   （change_system_settings 只对 app_theme/social_mode 弹窗，照旧）
///
/// 安全不变量：授权等级只来自 ToolSpec.permission（DB 工具由 PluginBus 从
/// type+content 现场推导），**绝不读取 tools.permissions 列**——该列可被
/// 篡改，仅作签名清单缓存与 UI 展示（防篡改设计见 PluginBus 注释）。
///
/// ------------------------------------------------------------
/// 【i18n 约定】本文件的弹窗文案分两类去处：
/// - **弹窗正文**（能力清单、操作描述）→ 以结构化 [PermissionPrompt] 发出，
///   由 UI 层（`main.dart` 的权限弹窗）按当前语言渲染；
/// - **Deny 理由**（会作为工具结果回灌给模型/展示在对话里）→ 受
///   `PermissionPolicy` 的 `Deny(String)` 契约限制只能是字符串，因此走
///   [L10nHolder]（UI 在 MaterialApp.builder 注入当前语言，英文兜底）。
/// 审计落库文本（`insertAudit` / `insertAgentAction`）属**日志数据**，
/// 保持固定写法，不在 UI 文案范畴。
/// ============================================================
class HarnessPermissionPolicy implements PermissionPolicy {
  /// DB 插件的能力声明解析器（AgentService 注册工具时登记；
  /// 用于复现原 _guardPluginRun 弹窗中的能力清单文案）
  final List<String> Function(String toolName) capabilitiesOf;

  const HarnessPermissionPolicy({required this.capabilitiesOf});

  @override
  Future<PermissionDecision> check(
      ToolSpec tool, Map<String, dynamic> args) async {
    switch (tool.permission) {
      case PermissionLevel.normal:
        return const Allow();
      case PermissionLevel.sensitive:
        return _firstGrantFlow(tool, args);
      case PermissionLevel.high:
        return _confirmFlow(tool, args, critical: false);
      case PermissionLevel.critical:
        return _confirmFlow(tool, args, critical: true);
    }
  }

  // ------------------------------------------------------------------
  // sensitive：PluginBus 首次授权流（原 _guardPluginRun 持久化语义）
  // ------------------------------------------------------------------
  Future<PermissionDecision> _firstGrantFlow(
      ToolSpec tool, Map<String, dynamic> args) async {
    // 授权键：ToolSpec.grantKey 优先（多工具共享一次授权，如 MCP 服务、
    // 手机控制工具组），缺省才退回工具名——与包契约注释一致。
    final key = tool.grantKey ?? tool.name;
    if (await PluginBus.hasGrant(key)) return const Allow();
    if (await PluginBus.isDenied(key)) {
      return Deny(L10nHolder.l10n.permDeniedReask);
    }
    final caps = capabilitiesOf(key);
    // 能力 → 风险：复用 PluginBus 的唯一来源（原为本地重复实现）
    final risk = PluginBus.riskForCapabilities(caps);
    final granted = await _askUser(
      tool,
      PermissionPrompt.forGrantKey(
        grantKey: key,
        declaredDescription: tool.description,
        capabilities: caps,
      ),
      arguments: {
        'plugin_grant': true,
        'capabilities': caps,
        'risk': risk,
      },
    );
    if (!granted) {
      try {
        await PluginBus.deny(key);
      } catch (e) {
        // 记录失败不阻断：拒绝是既定结论，拒绝名单写不进去只影响"下次不再问"
        await DBHelper.insertAgentAction(
          actionType: 'policy_error',
          detail: '拒绝名单持久化失败 [$key]: $e',
        );
      }
      await DBHelper.insertAgentAction(
        actionType: 'plugin_denied',
        detail: '插件 [$key] 首次能力授权被拒绝',
      );
      return Deny(L10nHolder.l10n.permDeniedNoGrant);
    }
    try {
      await PluginBus.grant(key);
    } catch (e) {
      // 主人已经点了"允许"：持久化失败不应把本次调用卡死（下次会再问一次）
      await DBHelper.insertAgentAction(
        actionType: 'policy_error',
        detail: '授权持久化失败 [$key]: $e',
      );
    }
    return const AllowAndRemember();
  }

  // ------------------------------------------------------------------
  // high / critical：白名单 + 60s fail-closed 弹窗（原 _requestToolPermission）
  // ------------------------------------------------------------------
  /// **绝不允许加入免弹窗白名单**的工具。
  ///
  /// 起因（0.64.0 施工时核实）：`_confirmFlow` 原先对 `high` 与 `critical` **共用**
  /// 一张 `tool_auto_allow` 白名单，于是"critical = 每次弹窗"这条承诺是**假的** ——
  /// 一旦用户（或某条引导话术）把某个 critical 工具写进白名单，此后它再也不过闸。
  /// 对"只是改个主题"这无所谓，但对**代表主人对外发信**是不可接受的：
  /// 那等于一次性把"以后随便发"的权利交出去了。
  ///
  /// 所以：凡是**不可撤销的对外动作**，一律钉在这个集合里，永远每次问。
  static const Set<String> neverAllowlist = {'mail_send'};

  Future<PermissionDecision> _confirmFlow(
    ToolSpec tool,
    Map<String, dynamic> args, {
    required bool critical,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final allowlist = prefs.getStringList('tool_auto_allow') ?? const [];
    if (!neverAllowlist.contains(tool.name) && allowlist.contains(tool.name)) {
      return const Allow();
    }

    // 参数级校验（照旧）：change_system_settings 只对真正高危的键弹窗
    if (critical && tool.name == 'change_system_settings') {
      final needsConfirm =
          args.containsKey('app_theme') || args.containsKey('social_mode');
      if (!needsConfirm) return const Allow();
    }

    final granted = await _askUser(tool, _promptFor(tool, args),
        arguments: args);
    if (critical) {
      // M3 新增：critical 档每次调用写审计（原行为无审计）
      //
      // ★ 0.64.0 修正：原先直接写 `'${tool.name} $args'` —— 把**整份参数**原样落库。
      // 对 `mail_send` 而言，那意味着**整封邮件正文与收件人**明文进审计表，
      // 与"正文不进任何持久化日志面"的纪律直接冲突。改为先过 [_redactForAudit]。
      await DBHelper.insertAudit(
        targetAgent: 'policy',
        draftText: '${tool.name} ${_redactForAudit(tool, args)}',
        riskLevel: 'medium',
        reason: granted ? 'critical 工具调用已确认放行' : 'critical 工具调用被拒绝',
        status: 0,
      );
    }
    if (!granted) return Deny(_denyText(tool));
    return const Allow();
  }

  // ------------------------------------------------------------------
  // 弹窗提示（结构化；渲染在 UI 层，与原内联实现逐字对齐，UX 无感知）
  // ------------------------------------------------------------------
  static PermissionPrompt _promptFor(ToolSpec tool, Map<String, dynamic> args) {
    switch (tool.name) {
      case 'create_custom_tool':
        return PermissionPrompt.toolCall(
          subject: tool.name,
          actionCode: PermissionAction.createTool,
          actionArg: args['name']?.toString() ?? 'tool',
          declaredDescription: tool.description,
        );
      case 'open_url_or_app':
        return PermissionPrompt.toolCall(
          subject: tool.name,
          actionCode: PermissionAction.openUrlOrApp,
          actionArg: args['url']?.toString() ?? '',
          declaredDescription: tool.description,
        );
      case 'change_system_settings':
        final keys = [
          if (args.containsKey('app_theme')) 'app_theme',
          if (args.containsKey('social_mode')) 'social_mode',
        ];
        return PermissionPrompt.toolCall(
          subject: tool.name,
          actionCode: PermissionAction.changeSettings,
          actionArg: keys.join(', '),
          declaredDescription: tool.description,
        );
      case 'mail_send':
        // 弹窗里**必须看得见收件人** —— "要发一封邮件"而不说发给谁，
        // 主人无法做出有效判断。草稿路径下收件人来自台账，由工具层回填。
        final recips = (args['to']?.toString() ?? '').trim();
        final draft = args['draft_id']?.toString() ?? '';
        return PermissionPrompt.toolCall(
          subject: tool.name,
          actionCode: PermissionAction.sendMail,
          actionArg: recips.isNotEmpty
              ? recips
              : (draft.isNotEmpty ? '草稿 #$draft' : '（未给出收件人）'),
          declaredDescription: tool.description,
        );
      default:
        return PermissionPrompt.toolCall(
          subject: tool.name,
          declaredDescription: tool.description,
        );
    }
  }

  /// 审计落库前的**参数脱敏**。
  ///
  /// 规则（刻意保守，宁可审计少几个字段，也不让主人隐私进日志）：
  /// - 命名单里的话题性字段一律只留**长度**，不留值（正文、口令、令牌、提示词…）；
  /// - 其余字段截断到 [_auditValueMaxChars]，避免长文本把审计表撑成大文本仓库；
  /// - `to` / `subject` **保留** —— 审计的意义就是"它到底替我做了什么"，
  ///   只说"发了一封邮件"等于没审计。
  static const Set<String> _auditSensitiveKeys = {
    'body',
    'text',
    'content',
    'draft_text',
    'password',
    'passwd',
    'secret',
    'token',
    'passphrase',
    'api_key',
    'apikey',
    'credential',
    'private_key',
    'prompt',
  };

  static const int _auditValueMaxChars = 120;

  static String _redactForAudit(ToolSpec tool, Map<String, dynamic> args) {
    if (args.isEmpty) return '(无参数)';
    final parts = <String>[];
    for (final e in args.entries) {
      final key = e.key;
      final value = e.value;
      if (_auditSensitiveKeys.contains(key.toLowerCase())) {
        final len = value is String ? value.length : 0;
        parts.add('$key=<已脱敏${len > 0 ? '，$len 字' : ''}>');
        continue;
      }
      var s = value?.toString() ?? 'null';
      if (s.length > _auditValueMaxChars) {
        s = '${s.substring(0, _auditValueMaxChars)}…(共 ${s.length} 字)';
      }
      if (s.contains('\n') || s.contains('\r')) s = s.replaceAll(RegExp(r'[\r\n]+'), '⏎');
      parts.add('$key=$s');
    }
    return parts.join(' ');
  }

  /// 拒绝理由（受 `Deny(String)` 契约限制，只能取当前语言的字符串）
  String _denyText(ToolSpec tool) {
    final l10n = L10nHolder.l10n;
    switch (tool.name) {
      case 'create_custom_tool':
        return l10n.permDenyCreateTool;
      case 'open_url_or_app':
        return l10n.permDenyOpenUrl;
      case 'change_system_settings':
        return l10n.permDenyChangeSettings;
      case 'mail_send':
        return l10n.permDenySendMail;
      default:
        return l10n.permDenyGeneric;
    }
  }

  /// 弹窗确认（fail-closed：超时 / 无 UI 应答一律拒绝）
  Future<bool> _askUser(ToolSpec tool, PermissionPrompt prompt,
      {Map<String, dynamic> arguments = const {}}) async {
    final completer = Completer<bool>();
    AppEvents.emit(ToolPermissionRequest(
      toolName: tool.name,
      prompt: prompt,
      arguments: arguments,
      completer: completer,
    ));
    try {
      return await completer.future
          .timeout(const Duration(seconds: 60), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }
}
