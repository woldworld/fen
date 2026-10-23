import 'package:dartantic_ai/dartantic_ai.dart' show Schema;

import 'tool_context.dart';

/// 工具风险四档（宿主实现里映射到既有双轨授权机制，见 HARNESS_PLAN §1 修正一）：
/// - normal   直接执行（现 PluginRisk.low 放行路径）
/// - sensitive 首次弹窗、持久授权、可吊销（现 PluginBus grant/revoke）
/// - high     每次弹窗，白名单可免（现 _requestToolPermission + tool_auto_allow）
/// - critical 每次弹窗 + 写审计（现 high 档 + insertAudit）
enum PermissionLevel {
  normal,
  sensitive,
  high,
  critical;

  static PermissionLevel parse(String? s) {
    switch (s) {
      case 'sensitive':
        return PermissionLevel.sensitive;
      case 'high':
        return PermissionLevel.high;
      case 'critical':
        return PermissionLevel.critical;
      case 'normal':
      default:
        return PermissionLevel.normal;
    }
  }
}

/// 注册名冲突：重名注册必须抛错（fail-closed），绝不静默覆盖。
class ToolNameConflict implements Exception {
  final String name;
  ToolNameConflict(this.name);
  @override
  String toString() => 'ToolNameConflict: 工具「$name」已注册，拒绝覆盖';
}

/// 工具元数据：唯一描述一个工具。
///
/// [inputSchema] 为 null 表示无参工具；非 null 时直接透传给 dartantic 的
/// `Tool<Map<String, dynamic>>`（json_schema_builder `Schema`，零转换）。
class ToolSpec {
  final String name;
  final String description;
  final Schema? inputSchema;
  final PermissionLevel permission;

  /// 授权持久化键（null = 用 [name]）。
  /// 用于"多工具共享一次授权"的场景：MCP 服务器的所有工具共用
  /// 'mcp:<服务名>'，首次授权一次、整组生效、随服务吊销。
  final String? grantKey;

  /// 单次调用的整体上限（null = 不设限，保持历史行为）。
  ///
  /// ★ 为什么是"工具级"而不是"传输级"：像 IMAP 的 `list` 是
  ///   `LOGIN + CAPABILITY + SELECT + SEARCH + 逐封 FETCH` 的**多命令**组合，
  ///   底层"单条命令读超时"叠不出整个工具调用的 deadline（专家 #2：服务端
  ///   半死不活时整轮会被拖到宿主层 150s 才断）。到点由 [bridgeTool] 收口为
  ///   一条**如实**的超时错误返回给模型，不炸整轮、也不再无声挂着。
  final Duration? callTimeout;

  final Future<String> Function(ToolContext ctx, Map<String, dynamic> args)
      handler;

  const ToolSpec({
    required this.name,
    required this.description,
    required this.permission,
    required this.handler,
    this.inputSchema,
    this.grantKey,
    this.callTimeout,
  });

  /// 是否无参工具（用于注册表快照与 prompt 组装时的快速判断）
  bool get hasParameters => inputSchema != null;
}
