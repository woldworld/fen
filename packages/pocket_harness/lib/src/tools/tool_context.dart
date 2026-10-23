import 'dart:io';

/// 工具执行上下文：宿主能力经此注入，harness 不直接碰任何宿主实现。
///
/// 大荒宿主的对应关系（M1 对接时）：
/// - [log]          ← AppLogger.w
/// - [searchMemory] ← DBHelper.searchMessages
/// - [httpClient]   ← AgentService._globalHttpClient（连接池复用）
class ToolContext {
  final void Function(String tag, Object? message) log;
  final Future<String> Function(String keyword) searchMemory;
  final HttpClient httpClient;

  const ToolContext({
    required this.log,
    required this.searchMemory,
    required this.httpClient,
  });
}
