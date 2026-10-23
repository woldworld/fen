import 'tool_spec.dart';

/// 技能：注入 System Prompt 的"行为知识"——不是可调用函数。
///
/// "万物皆插件"的另一半：技能与工具共享同一注册表、同一变更事件流、
/// 同一热插拔管线，但消费端不同——
/// - 工具（[ToolSpec]）经 bridgeTool 暴露给模型调用；
/// - 技能（[SkillSpec]）由宿主的 prompt 组装读取（配 fitLines 防溢出），
///   变更时刷新 prompt 缓存而非重建 Agent 工具表。
///
/// 安全模型差异是有意保留的：工具动的是"行为"（走四档权限闸），
/// 技能改的是"人格"（走签名验证 + 主人审批），不可混为一谈。
class SkillSpec {
  final String name;
  final String content;

  const SkillSpec({required this.name, required this.content});
}
