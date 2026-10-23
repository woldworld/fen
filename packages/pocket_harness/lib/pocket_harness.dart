/// pocket_harness — mobile-first agent harness for Dart.
///
/// v0.1（M0）公开面：工具注册表、权限策略接口、会话存储接口。
/// AgentRuntime / ContextManager 在 M2 / M4 里程碑加入。
///
/// 铁律：本包零 Flutter 依赖，宿主能力一律经接口注入
/// （ToolContext / PermissionPolicy / SessionStore）。
library;

// 宿主写 ToolSpec.inputSchema 需要 Schema 构造器，从伞库精选再导出。
// 注意：只 show 这两个类型，不把 dartantic 全家桶漏给宿主命名空间。
export 'package:dartantic_ai/dartantic_ai.dart' show S, Schema;

export 'src/context/compactor.dart';
export 'src/context/context_manager.dart';
export 'src/mcp/mcp_manager.dart';
export 'src/plugins/dsh_compat.dart';
export 'src/plugins/plugin_contract.dart';
export 'src/policy/permission_policy.dart';
export 'src/runtime/agent_runtime.dart';
export 'src/session/agent_reply.dart';
export 'src/session/session_event.dart';
export 'src/session/session_store.dart';
export 'src/tools/builtin_tools.dart';
export 'src/tools/skill_spec.dart';
export 'src/tools/tool_bridge.dart';
export 'src/tools/tool_context.dart';
export 'src/tools/tool_registry.dart';
export 'src/tools/tool_search.dart';
export 'src/tools/tool_spec.dart';
