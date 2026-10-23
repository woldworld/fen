import 'dart:async';

/// 全局应用命令/事件总线。
/// 方向约束：core 只发事件，UI 负责订阅消费；core 绝不反向 import UI。
sealed class AppCommand {}

/// 清空当前聊天工作区（替代原先的全局 Key hack）
class ClearChatCommand extends AppCommand {}

/// 切换全局主题
class ChangeThemeCommand extends AppCommand {
  final String themeKey;
  ChangeThemeCommand(this.themeKey);
}

/// 社交消息到达事件：由 lan/p2p/cloud 通道发出，AgentService 订阅处理
class SocialMessageReceivedEvent extends AppCommand {
  final String senderAgentId;
  final String message;
  final String channel; // p2p / lan / cloud
  final String? sourceMsgId;
  SocialMessageReceivedEvent({
    required this.senderAgentId,
    required this.message,
    required this.channel,
    this.sourceMsgId,
  });
}

/// 世界房间消息到达事件：由 world-server feed 拉取发出，AgentService 订阅处理。
/// 默认纯观察（日志+记忆），仅当房间开启托管发言时才可能自动回复。
class WorldRoomMessageEvent extends AppCommand {
  final String roomId;
  final String senderAgentId;
  final String nickname;
  final String message;
  final String? sourceMsgId;
  WorldRoomMessageEvent({
    required this.roomId,
    required this.senderAgentId,
    required this.nickname,
    required this.message,
    this.sourceMsgId,
  });
}

/// 「待主人确认」的动作落库事件。
///
/// 由 `DBHelper.insertAgentAction` 在写入 `proactive_suggestion` /
/// `pending_approval` 两类时发出——**这是"分身被卡住、在等放行"唯一的对外信号**。
/// 其余 actionType（`create_tool` / `world_reply` / 审计留痕）是记录不是请求，
/// 不该打扰主人，故不发事件。
///
/// 通知内核订阅它来弹系统通知；UI 也可复用它做小红点，而不必各自轮询数据库。
class AgentActionPendingEvent extends AppCommand {
  /// `proactive_suggestion` / `pending_approval`。
  final String actionType;

  /// 对端分身 ID。
  final String targetId;

  /// 草稿正文（通知里做摘要/去重用）。
  final String detail;

  AgentActionPendingEvent({
    required this.actionType,
    required this.targetId,
    required this.detail,
  });
}

/// 物理节点上线事件：由 lan/p2p 通道发出，AgentService 订阅后恢复聊天
class NodeOnlineEvent extends AppCommand {
  final String agentId;
  NodeOnlineEvent(this.agentId);
}

/// 换机直迁（`FENMIG1`）会话状态变化事件。
///
/// core 只带**稳定码**（角色 / 阶段 / 失败原因），文案由 UI 按当前语言拼装
/// —— core 拿不到 `BuildContext`，这是全项目一致的边界。
///
/// ⚠️ 事件里**不含任何密钥材料**（新种子只在 `DeviceMigrationService` 内存里）。
class MigrationStateChangedEvent extends AppCommand {
  /// 被迁移的身份（`AG-...`）。
  final String agentId;

  /// 对端分身 ID。
  final String peerId;

  /// `MigrationRole` 的名字（`initiator` / `responder`）。
  final String role;

  /// `MigrationPhase` 的名字（`idle` / `offered` / `peerConfirmed` / …）。
  final String phase;

  /// 失败原因码（阶段为 `failed` 时非空）。
  final String? fault;

  /// 两屏要比对的短码（`XXX-XXX`）；尚无票据时为 null。
  final String? compareCode;

  MigrationStateChangedEvent({
    required this.agentId,
    required this.peerId,
    required this.role,
    required this.phase,
    this.fault,
    this.compareCode,
  });
}

/// 智能体**当前在干什么**的阶段码（供 UI 画"忙碌小精灵"，替代通用转圈）。
///
/// ---------------------------------------------------------------------------
/// 为什么必须是**稳定码**而不是直接发枚举/文案
/// ---------------------------------------------------------------------------
/// 与 [MigrationStateChangedEvent] 同一条边界：core 拿不到 `BuildContext`，
/// 也**不该**知道界面长什么样。core 只报"我在检索"，具体画成放大镜还是齿轮
/// 由 UI 决定 ⇒ 换视觉不用动 core，加阶段也不会让 core 依赖 UI 类型。
///
/// ---------------------------------------------------------------------------
/// ⚠️ 只允许发**真实发生**的阶段（R14「UI 不给假状态」）
/// ---------------------------------------------------------------------------
/// 每个码都必须对应代码里**真的跨过了一个里程碑**。禁止"按秒轮换"式假装忙碌
/// —— 那会让主人看到"正在检索"而实际什么都没查，比转圈更糟。
///
/// · [searching]：`AgentService` **真的**进了回忆/记忆检索段；
/// · [thinking]：**真的**把请求交给了模型（`_runtime.turn`）；
/// · [tooling]：**真的**有工具在跑；
/// · [writing]：**为流式输出预留** —— 当前 `sendMessage` 是一次性 await，
///   拿到的就是完整回复，**没有增量输出** ⇒ 这条链路上不会发出它。
///   预先定好码值，等流式管线接上时 UI **不需要再改一行**。
class AgentActivity {
  /// 空闲（任务结束 / 被中断 / 从未开始）。
  static const String idle = 'idle';

  /// 模型推理中。
  static const String thinking = 'thinking';

  /// 检索记忆中。
  static const String searching = 'searching';

  /// 组织输出中（**待流式管线**）。
  static const String writing = 'writing';

  /// 执行工具调用中。
  static const String tooling = 'tooling';

  /// 一轮任务成功完成。
  static const String success = 'success';

  /// 一轮任务失败。
  static const String error = 'error';

  /// 被中断（主人离开 / 主动取消）。
  static const String interrupted = 'interrupted';

  /// 全部合法码。守卫据此断言"UI 侧映射已覆盖每一个码"
  /// —— 加码忘了改 UI 会**当场**被这条钉住，而不是等到主人看不见动画才发现。
  static const List<String> all = <String>[
    idle, thinking, searching, writing, tooling, success, error, interrupted,
  ];
}

/// 智能体活动阶段变化事件。
///
/// 发出方：`AgentService`（真实里程碑）。订阅方：主聊天窗口的悬浮小精灵。
/// 主聊天窗口自己的 `send`/`catch` 也会发出（它同样握有真实事实）。
class AgentActivityEvent extends AppCommand {
  /// [AgentActivity] 之一。
  final String phase;

  /// 触发来源，排障用（如 `agent.turn` / `chat.send`）。
  final String source;

  AgentActivityEvent({required this.phase, this.source = ''});
}

/// 权限弹窗的类型码。
abstract final class PermissionPromptKind {
  /// 插件首次能力授权（PluginBus grant 流）。
  static const String pluginGrant = 'plugin-grant';

  /// 单次高危工具调用确认。
  static const String toolCall = 'tool-call';
}

/// 插件展示名的形态码（[PermissionPrompt.displayCode]）。
abstract final class PermissionDisplay {
  /// 手机控制工具组。
  static const String deviceControl = 'device-control';

  /// MCP 服务（[PermissionPrompt.displayArg] 为服务名）。
  static const String mcp = 'mcp';

  /// 由授权键推导展示名形态码（两条授权通道共用同一推导）。
  static String? ofGrantKey(String key) {
    if (key == 'device_control') return deviceControl;
    if (key.startsWith('mcp:')) return mcp;
    return null;
  }
}

/// 高危工具调用确认的操作码（[PermissionPrompt.actionCode]）。
abstract final class PermissionAction {
  static const String createTool = 'create-tool';
  static const String openUrlOrApp = 'open-url-or-app';
  static const String changeSettings = 'change-settings';

  /// 对外发信（`mail_send`）。[PermissionPrompt.actionArg] = 收件人列表。
  ///
  /// 单独给一个操作码，是因为"弹窗里必须看得见收件人"是这条工具的安全要求：
  /// 只说"要发一封邮件"而不说**发给谁**，主人就没法做有效判断。
  static const String sendMail = 'send-mail';

  static const String generic = 'generic';
}

/// 权限弹窗的**结构化提示**：core 只带码与原始数据，文案由 UI 层按当前
/// 语言拼装（core 拿不到 BuildContext）。
///
/// 这样做的另一个收益：两条授权通道（harness PermissionPolicy 与
/// AgentService 旧的 _guardPluginRun）共用同一份渲染，
/// 不会再出现"同一句文案各写一遍、改一处漏一处"。
class PermissionPrompt {
  /// [PermissionPromptKind] 之一。
  final String kind;

  /// 原始标识：插件授权键（如 `mcp:xxx` / `device_control`）或工具名。
  final String subject;

  /// 插件展示名形态码（[PermissionDisplay]）；null = 直接显示 [subject]。
  final String? displayCode;

  /// 展示名参数（MCP 服务名）。
  final String? displayArg;

  /// 插件 / 工具自身声明的说明（`ToolSpec.description`），原样透传。
  final String declaredDescription;

  /// 能力码列表（`PluginCapability` 常量）。
  final List<String> capabilities;

  /// 操作码（[PermissionAction]）。
  final String actionCode;

  /// 操作参数（url / 被修改的设置键 / 工具名）。
  final String? actionArg;

  const PermissionPrompt.pluginGrant({
    required this.subject,
    this.displayCode,
    this.displayArg,
    required this.declaredDescription,
    required this.capabilities,
  })  : kind = PermissionPromptKind.pluginGrant,
        actionCode = PermissionAction.generic,
        actionArg = null;

  const PermissionPrompt.toolCall({
    required this.subject,
    required this.declaredDescription,
    this.actionCode = PermissionAction.generic,
    this.actionArg,
  })  : kind = PermissionPromptKind.toolCall,
        displayCode = null,
        displayArg = null,
        capabilities = const [];

  /// 由授权键构造插件授权提示（展示名形态自动推导，两条授权通道共用）。
  factory PermissionPrompt.forGrantKey({
    required String grantKey,
    required String declaredDescription,
    required List<String> capabilities,
  }) {
    return PermissionPrompt.pluginGrant(
      subject: grantKey,
      displayCode: PermissionDisplay.ofGrantKey(grantKey),
      displayArg: grantKey.startsWith('mcp:') ? grantKey.substring(4) : null,
      declaredDescription: declaredDescription,
      capabilities: capabilities,
    );
  }
}

/// 高权限工具调用确认请求：UI 弹窗后通过 completer 应答
class ToolPermissionRequest extends AppCommand {
  final String toolName;

  /// 结构化提示（文案由 UI 渲染）。
  final PermissionPrompt prompt;

  final Map<String, dynamic> arguments;
  final Completer<bool> completer;
  ToolPermissionRequest({
    required this.toolName,
    required this.prompt,
    required this.arguments,
    required this.completer,
  });
}

class AppEvents {
  AppEvents._();

  static final StreamController<AppCommand> _bus =
      StreamController<AppCommand>.broadcast();

  static Stream<AppCommand> get stream => _bus.stream;

  static void emit(AppCommand cmd) {
    if (!_bus.isClosed) _bus.add(cmd);
  }
}
