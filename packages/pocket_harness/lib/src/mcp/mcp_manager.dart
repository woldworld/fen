import 'dart:async';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;

import '../tools/tool_context.dart';
import '../tools/tool_spec.dart';

/// MCP 服务器连接状态机
enum McpState { disconnected, connecting, ready, failed }

/// 单台服务器的可观测状态
class McpServerStatus {
  final String name;
  final McpState state;
  final String? lastError;
  final DateTime? readyAt;
  final int toolCount;

  const McpServerStatus(this.name, this.state,
      {this.lastError, this.readyAt, this.toolCount = 0});
}

class McpServerUpdate {
  final String name;
  final McpState state;
  final String? detail;
  const McpServerUpdate(this.name, this.state, {this.detail});
}

/// 一次加载的产物
class McpLoadResult {
  final List<ToolSpec> tools;
  final McpState state;
  final String? error;
  final int toolCount;
  const McpLoadResult(this.tools, this.state,
      {this.error, this.toolCount = 0});
}

/// MCP 连接管理器（M5）：替代"2 秒硬超时 + 静默失败"的旧加载。
///
/// - **可观测**：每台服务器有状态机（connecting/ready/failed）+ 最后错误 +
///   更新事件流，失败原因可查可看，不再无声消失；
/// - **超时可配**（默认 10s，替代硬编码 2s）；
/// - **命名空间化**：工具名统一为 `mcp_<服务名>_<工具名>`（清洗非法字符、
///   截断 64 字符），跨服务重名互不打架；
/// - **统一管线**：产出的 ToolSpec 注册进 ToolRegistry 后，权限闸（M3）、
///   热插拔（M1）、桥接与异常收口全部复用，MCP 不再是旁路。
class McpConnectionManager {
  final Map<String, _McpRecord> _records = {};
  final StreamController<McpServerUpdate> _updates =
      StreamController<McpServerUpdate>.broadcast();

  Stream<McpServerUpdate> get updates => _updates.stream;

  McpServerStatus statusOf(String name) {
    final r = _records[name];
    return r == null
        ? McpServerStatus(name, McpState.disconnected)
        : McpServerStatus(name, r.state,
            lastError: r.lastError, readyAt: r.readyAt, toolCount: r.toolCount);
  }

  List<McpServerStatus> statusSnapshot() =>
      [for (final n in _records.keys) statusOf(n)];

  /// 连接一台 MCP 服务器并列出工具，转为命名空间化的 ToolSpec。
  ///
  /// [grantKey] 透传给每个 ToolSpec（如 'mcp:<服务名>'）——整组工具共享一次
  /// 首次授权，随服务吊销。
  Future<McpLoadResult> loadServer({
    required String name,
    required Uri url,
    required ToolContext ctx,
    String? grantKey,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _emit(name, McpState.connecting);
    try {
      final client = dartantic.McpClient.remote(name, url: url);
      final tools =
          await client.listTools().timeout(timeout);

      final specs = <ToolSpec>[];
      for (final t in tools) {
        final ns = namespace(name, t.name);
        final origin = t;
        specs.add(ToolSpec(
          name: ns,
          description: '[MCP:$name] ${t.description}',
          permission: PermissionLevel.sensitive, // 网络能力：首次调用授权持久化
          grantKey: grantKey,
          handler: (ctx, args) async {
            final out = await origin.call(args);
            return out?.toString() ?? 'ok';
          },
        ));
      }
      _records[name] = _McpRecord(
        state: McpState.ready,
        readyAt: DateTime.now(),
        toolCount: specs.length,
      );
      _emit(name, McpState.ready, detail: '${specs.length} tools');
      return McpLoadResult(specs, McpState.ready, toolCount: specs.length);
    } catch (e) {
      _records[name] = _McpRecord(state: McpState.failed, lastError: '$e');
      _emit(name, McpState.failed, detail: '$e');
      ctx.log('harness.mcp.$name', e);
      return McpLoadResult(const [], McpState.failed, error: '$e');
    }
  }

  /// 工具名命名空间化：`mcp_<服务>_<工具>`，非法字符清洗，截断 64
  ///（OpenAI 系 provider 的函数名上限）。
  static String namespace(String server, String toolName) {
    final raw = 'mcp_${server}_$toolName'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return raw.length > 64 ? raw.substring(0, 64) : raw;
  }

  void _emit(String name, McpState state, {String? detail}) {
    _updates.add(McpServerUpdate(name, state, detail: detail));
  }
}

class _McpRecord {
  final McpState state;
  final String? lastError;
  final DateTime? readyAt;
  final int toolCount;
  const _McpRecord(
      {required this.state, this.lastError, this.readyAt, this.toolCount = 0});
}
