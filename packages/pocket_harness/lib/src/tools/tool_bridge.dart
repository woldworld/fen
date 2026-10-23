import 'dart:async';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;

import 'tool_context.dart';
import 'tool_spec.dart';
import '../policy/permission_policy.dart';

/// 把 [ToolSpec] 适配成 dartantic_ai 的 `Tool<Map<String, dynamic>>`。
///
/// - `inputSchema` 零转换透传（null = 无参工具，dartantic 默认空对象 schema）；
/// - 提供可选 [policy] 时，**每次调用先过权限闸**（M3）：Deny 直接拦截并把原因
///   返回给 LLM，handler 不会执行；Allow/AllowAndRemember 放行（记忆的持久化
///   由宿主 policy 实现内部完成——包不存任何授权状态）；
/// - handler 异常在此收口为错误字符串返回给 LLM（fail-soft），不炸整轮对话。
dartantic.Tool<Map<String, dynamic>> bridgeTool(
  ToolSpec spec,
  ToolContext ctx, {
  PermissionPolicy? policy,
}) {
  return dartantic.Tool<Map<String, dynamic>>(
    name: spec.name,
    description: spec.description,
    inputSchema: spec.inputSchema,
    onCall: (args) => _runGuarded(spec, ctx, args, policy),
  );
}

Future<String> _runGuarded(ToolSpec spec, ToolContext ctx,
    Map<String, dynamic> args, PermissionPolicy? policy) async {
  if (policy != null) {
    final PermissionDecision decision;
    try {
      decision = await policy.check(spec, args);
    } catch (e) {
      // 策略本身异常 = fail-closed（与宿主弹窗超时拒绝同一姿态）
      ctx.log('harness.policy.${spec.name}', e);
      return '【权限闸异常】${spec.name} 未获放行（fail-closed），本次调用已中止。';
    }
    if (decision is Deny) {
      return '【权限拒绝】${spec.name}：${decision.reason}';
    }
  }
  try {
    final fut = spec.handler(ctx, args);
    // ★ 0.90.0：工具级整体超时（专家 #2）。null = 不设限，历史行为不变。
    //   到点**如实**告诉模型"超时"，而不是让整轮被拖到宿主层才断（fail-soft，
    //   与下面 handler 异常同一收口姿态）。
    return spec.callTimeout == null
        ? await fut
        : await fut.timeout(spec.callTimeout!);
  } catch (e, st) {
    ctx.log('harness.tool.${spec.name}', e);
    ctx.log('harness.tool.${spec.name}', st);
    // 只有"我们自己加了上限"时才是工具超时；否则 handler 内部抛的 TimeoutException
    // 一律按普通异常如实转述（避免把"内部超时"误报成"工具超时"）。
    if (e is TimeoutException && spec.callTimeout != null) {
      return '【工具超时】${spec.name}：超过 ${spec.callTimeout!.inSeconds} 秒未返回，'
          '本次调用已中止（网络或服务端无响应）。';
    }
    return '【工具执行异常】${spec.name}：$e';
  }
}
