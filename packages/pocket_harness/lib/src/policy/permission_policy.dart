import '../tools/tool_spec.dart';

/// 权限决策三态。
sealed class PermissionDecision {
  const PermissionDecision();
}

/// 放行本次调用。
class Allow extends PermissionDecision {
  const Allow();
}

/// 放行并持久记忆（宿主落 PluginBus.grant 或 tool_auto_allow 白名单）。
class AllowAndRemember extends PermissionDecision {
  const AllowAndRemember();
}

/// 拒绝（含原因，返回给 LLM 作为工具结果，让它知道为何失败）。
class Deny extends PermissionDecision {
  final String reason;
  const Deny(this.reason);
}

/// 权限策略：宿主实现里统一既有双轨授权
/// （_requestToolPermission 60s fail-closed 弹窗 + PluginBus 能力推导）。
///
/// 包内绝不持久化任何授权状态——记住/吊销全部由宿主实现承担。
abstract class PermissionPolicy {
  /// 每次工具调用前必过此闸。
  ///
  /// [args] 供"参数级升级"判断（如 change_system_settings 只对
  /// app_theme/social_mode 键弹窗——这个语义要在宿主实现里保留）。
  Future<PermissionDecision> check(
      ToolSpec tool, Map<String, dynamic> args);
}

/// 全放行的空策略（测试/本地实验用；生产宿主绝不能用）。
class AllowAllPolicy implements PermissionPolicy {
  const AllowAllPolicy();
  @override
  Future<PermissionDecision> check(
          ToolSpec tool, Map<String, dynamic> args) async =>
      const Allow();
}
