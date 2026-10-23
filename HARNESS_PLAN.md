# pocket_harness 开发计划 v0.2 · 代码核实落地版

版本 v0.2 · 2026-09-02 · 前置：v0.1 框架计划 + 本轮对全部锚点代码的逐行核实
> 与 v0.1 的关系：结构不变（一条铁律 / 五个抽象 / 四个宿主接口 / 六个里程碑），
> 但**每一处假设都对着源码验过**。v0.1 有三个假设被代码修正，见第 1 节。

## 📍 实施进度（2026-09-03）

| 里程碑 | 状态 | 验证 |
|---|---|---|
| M0 包骨架 + 接口定型 | ✅ 完成 | dart test 11/11、依赖树零 flutter |
| M1 可逆工具注册表 | ✅ 完成 | 热注册替换三处全量重建；宿主 38/38 |
| M2 会话 Thread + sendFor | ✅ 完成 | 多轮记忆首次生效；XML 正则删除；降级链离线可测 |
| M3 权限四档统一双轨 | ✅ 完成 | 防篡改不变量钉测试；弹窗/白名单/参数级语义照旧 |
| M4 上下文管理 | ✅ 完成 | 预算选择 + 摘要折叠（重追加修正）；limit:50 退役 |
| M5 MCP 管理器 + 工具检索 | ✅ 完成 | 状态机/命名空间/grantKey 服务级授权；2s 静默失败退役 |

包测试 45/45 · 宿主测试 41/41 · 双端 analyze 0 issue。
**遗留（非阻塞）**：真机验证（M1 热插拔 / M2 sendFor 对 DeepSeek 的实际支持 / M4 长会话）；
MCP 需要真实服务联调；embedding 版工具检索等 provider 明确后再排。

---

## 0. 代码事实清单（全部核实过，计划的承重墙）

| # | 事实 | 锚点 |
|---|---|---|
| F1 | `dartantic_ai` 3.4.2 **零 Flutter 依赖**（依赖表全是纯 Dart SDK：anthropic/googleai/mistral/ollama/openai、http、mcp_dart、rxdart） | pub Cache `dartantic_ai-3.4.2/pubspec.yaml` |
| F2 | `sendFor<T>` **存在**：`Future<ChatResult<TOutput>> sendFor<TOutput extends Object>({required Schema outputSchema, ...})`，配 `outputFromJson` 解码器 | `dartantic_ai/lib/src/agent/agent.dart:235`；官方示例 `example/bin/chat.dart:66-69` |
| F3 | Agent 构造：`Agent.forProvider(provider, chatModelName:, tools:)`；宿主已有两处用法 | `agent_service.dart:787`（带工具）、`:848`（无工具临时 Agent） |
| F4 | `send(prompt, {history})` 是**显式传历史**，Agent 内部不跨调用保留状态。而主聊天每轮只传 `[ChatMessage.system(prompt)]`——**今天的主聊天没有多轮记忆** | `agent_service.dart:794`；`agent.dart:200-216` |
| F5 | `initAgent()` 全貌：9 个内置工具 + DB 工具循环 + MCP 分支 + Agent 构造 | `agent_service.dart:414-788` |
| F6 | 9 个内置工具：inner_monologue / get_current_time / web_search / web_search_in_china / create_custom_tool / open_url_or_app / switch_social_scenario / change_system_settings / record_serendipity_log | `agent_service.dart:433-711` |
| F7 | `Future.delayed(1s, initAgent())` 共 **3 处**：create_custom_tool(498)、change_system_settings(623)、BUILTIN_CREATE_TOOL 遗留路径(757) | 同左 |
| F8 | **prompt 缓存已有版本失效机制**：`_getSystemPromptCached` 比较 `DBHelper.dataRevision`，DB 写路径会 bump | `agent_service.dart:832-841`；`db_helper.dart:278/288/293` |
| F9 | **tools.permissions 列不是闲置**：PluginBus 把能力 JSON 写进该列（stampRow），但**故意不读它做授权**（注释原文：「只信类型+内容，绝不信任库里的 permissions 列，防止攻击者篡改声明字段绕过授权」） | `plugin_bus.dart:139-141, 269` |
| F10 | **授权是双轨制**：① 内置高危工具走 `_requestToolPermission`（`tool_auto_allow` 白名单 + 60s fail-closed 弹窗）② DB 插件走 `PluginBus._guardPluginRun`（能力→风险推导 → 首次授权持久化 → 可吊销） | `agent_service.dart:132-154, 165-211`；`plugin_bus.dart:301-359` |
| F11 | DB 工具加载前**验签 fail-closed**：签名失效的插件绝不进 Tool 列表，且写审计 | `agent_service.dart:728-739` |
| F12 | **skill ≠ tool**：`getLoadedTools`（type≠skill → 可调用工具）与 `getActiveSkills`（type=skill → 注入 System Prompt 的行为技能库）是两条管道 | `db_helper.dart:385-392`；`agent_service.dart:288-289` |
| F13 | 正则抓 XML 三连：`<reply>/<topic>/<keywords>` | `agent_service.dart:798-800` |
| F14 | 断网/超时降级：sendMessage catch 里走 `LocalModelService.chat` 本地小模型兜底 | `agent_service.dart:808-818` |
| F15 | MCP 加载 2s 硬超时静默失败（`_loadMcpTools`），带授权闸的封装是 `_loadMcpToolsGuarded` | `agent_service.dart:258-267, 328-360` |
| F16 | ToolContext 三件套宿主全有现成件：日志=AppLogger、记忆检索=DBHelper.searchMessages、连接池=_globalHttpClient | `agent_service.dart:60, 253` 等 |
| F17 | messages 表（session_id/text/topic/keywords/isUser/timestamp）+ memory_events 表可直接承载 SessionStore | `db_helper.dart:145, 152` |
| F18 | dartantic 的 `Tool<TInput>` 自带 `Schema? inputSchema`（json_schema_builder），`Tool<Map<String,dynamic>>` 直接收原始参数 | `dartantic_interface-4.0.1/lib/src/tool.dart:11-42` |

---

## 1. v0.1 三个被代码修正的假设（重要）

### 修正一：M3 的"启用闲置 permissions 字段"——**不能这么做，这是在拆防线**
v0.1 说"permissions 字段一直闲置，M3 直接启用"。事实（F9）是：该列被 PluginBus **写入**（能力声明 JSON）但被**刻意不读**——因为库里的声明字段可被攻击者篡改，授权等级一律从 type+content 现场推导再验签。把等级存进列再读回来，等于把防篡改设计拆了。
**M3 的真实任务改为：统一双轨授权（F10）**。四档映射到现有机制而不是新造机制：

| 四档 | 映射到的现有机制 | 现有等价物 |
|---|---|---|
| normal | 直接执行 | PluginRisk.low 放行（`_guardPluginRun:172`） |
| sensitive | 首次弹窗、持久授权、可吊销 | PluginBus.hasGrant/grant/revoke |
| high | 每次弹窗（60s fail-closed）+ 白名单可免 | `_requestToolPermission` |
| critical | 每次弹窗 + 写 audit_queue | 同上 + `insertAudit` |

permissions 列保持"只写不读"，定位为签名清单的缓存与 UI 展示字段。

### 修正二：M2 的"崩溃可恢复"——实际是**从 0 到 1 补 Thread**
v0.1 把 SessionStore 定位为崩溃恢复。事实（F4）更根本：`send()` 显式收 history，而主聊天每轮只传 `[system]`——**当前主聊天没有多轮记忆**（社交子 Agent 另有 `_getRecentChatContext` 拼上下文，是另一套）。M2 落地后主聊天第一次拥有真正的 Thread，崩溃恢复只是它的一个副产品。

### 修正三：M1 的"三处重建都换热插拔"——其中一处该换成 revision bump
三处 `Future.delayed(1s, initAgent())`（F7）动机不同：`create_custom_tool`(498) 和遗留路径(757) 是**工具变了**，真需要热插拔；`change_system_settings`(623) 是**名字/语气变了要刷 System Prompt**，而 prompt 缓存的 revision 失效机制（F8）早已存在——这里应该改成 `DBHelper.dataRevision++`（或对应 bump 方法），下一轮自动重建 prompt，**连工具都不用动**。热插拔救不了它，硬换反而掩盖了"prompt 缓存与工具注册是两个失效域"这个正确建模。

### 补充修正（不计入 v0.1 错误，属建模补全）
- **skill ≠ tool**（F12）：技能是注入 prompt 的文本，工具是可调用函数。ToolRegistry 只管后者；skills 管道在 M4 归入 ContextManager 的 prompt 组装，不要混进注册表。
- **离线降级要成为一等公民**（F14）：`LocalModelService` 兜底是大荒 mobile-first 的卖点，进 `AgentRuntime` 的可选 `fallback` 钩子，不是宿主私货。
- **无工具轮次**：网关审查/社交子 Agent 用的是无工具临时 Agent（F3 `:848`）。Harness 要提供 `runAuxiliary()`（无工具、短历史、快超时），网关迁移到 M2 后才能彻底归位。

---

## 2. 铁律（核实后成立，附一条注意）

`pocket_harness` 只依赖 `dartantic_ai`（纯 Dart，F1 已核实）+ 标准库。
禁止 import Flutter、SharedPreferences、sqflite、url_launcher、DBHelper、AppEvents、PluginBus。

> 注意：**PluginBus 不进包**。验签/授权持久化是宿主安全策略（依赖设备密钥与 prefs），
> 包里只定义 `PermissionPolicy` 接口；宿主用一个"把 PluginBus + _requestToolPermission 统起来的实现"去接。

---

## 3. 核心抽象（对 v0.1 的微调，含对接映射）

```dart
// 工具风险四档（宿主实现里映射到 F10 的双轨机制）
enum PermissionLevel { normal, sensitive, high, critical }

/// 工具元数据。inputSchema 直接用 dartantic_interface 再导出的
/// json_schema_builder `Schema`（F18），零转换透传给 Tool 构造。
class ToolSpec {
  final String name;
  final String description;
  final Schema? inputSchema;                  // null = 无参工具（S.object() 空对象）
  final PermissionLevel permission;
  final Future<String> Function(ToolContext ctx, Map<String, dynamic> args) handler;
}

/// 工具执行上下文：宿主能力经此注入（F16 三件套全有现成件）
class ToolContext {
  final void Function(String tag, Object msg) log;            // ← AppLogger.w
  final Future<String> Function(String keyword) searchMemory; // ← DBHelper.searchMessages
  final HttpClient httpClient;                                // ← _globalHttpClient
}

/// 可逆注册表：register 返回 disposer；name 冲突抛 ToolNameConflict；
/// changes 事件流供"运行中 Agent 的工具列表重建"订阅。
abstract class ToolRegistry {
  ToolRegistration register(ToolSpec spec);
  ToolSpec? lookup(String name);
  List<ToolSpec> snapshot();
  Stream<ToolRegistryChange> get changes;
}

/// 权限策略：宿主实现里统一双轨（见第 1 节修正一）
abstract class PermissionPolicy {
  Future<Decision> check(ToolSpec tool, Map<String, dynamic> args);
  // Decision.allow / deny(reason) / allowAndRemember（宿主落 PluginBus.grant 或 tool_auto_allow）
}

/// 会话与轨迹（append-only）
abstract class SessionStore {
  Future<Session> open(String id);
  Future<void> append(String id, SessionEvent event);
  Future<List<SessionEvent>> replay(String id, {int? after});
  Future<void> close(String id);
}

/// 顶层运行时。fallback 是 mobile-first 卖点（F14 的 LocalModelService）。
class Harness {
  Future<TurnOutput> run(TurnInput input);      // 主脑轮次（带工具、带 Thread）
  Future<String> runAuxiliary(AuxInput input);  // 无工具轮次（网关/子 Agent 模式，F3:848）
}

class TurnOutput {
  final String reply; final String topic; final String keywords;
  final List<SessionEvent> transcript;          // 本轮全轨迹，宿主落盘
}
```

宿主对接清单（每行都有现成代码承接）：

| 宿主要实现 | 承接的现有代码 |
|---|---|
| `ToolSpec` × 9 内置 | `agent_service.dart:433-711` 原样搬运，handler 体不改逻辑 |
| DB 工具桥（type=local/mcp） | `agent_service.dart:717-781` + PluginBus 验签（:728-739 保留宿主侧） |
| `PermissionPolicy` | 统一 `_requestToolPermission`(132-154) + `_guardPluginRun`(165-211)，双轨收编 |
| `SessionStore`（SQLite） | messages 表 + memory_events（F17），新建 `session_events` 表或复用 |
| `ConfigSource` | SharedPreferences 包一层 |
| `ToolContext` | AppLogger / DBHelper.searchMessages / _globalHttpClient |
| `fallback` | LocalModelService.chat（808-818 的逻辑上移） |

---

## 4. 目录结构（同 v0.1，增加两文件）

```
packages/pocket_harness/
├── pubspec.yaml            # 唯一依赖 dartantic_ai ^3.4.2
├── lib/pocket_harness.dart # 公开导出
└── lib/src/
    ├── harness.dart              # Harness + TurnInput/TurnOutput + runAuxiliary
    ├── runtime/agent_runtime.dart     # 包装 Agent.forProvider + fallback 钩子
    ├── tools/{tool_spec,tool_registry,tool_context}.dart
    ├── policy/{permission_level,permission_policy}.dart
    ├── session/{session,session_event,session_store}.dart  # + 默认 sqflite 实现?
    └── context/{context_manager,compactor}.dart
└── test/…
```

> **sqflite 依赖的例外讨论**：默认 SessionStore 实现若用 sqflite，就破"零 Flutter 生态"了吗？——sqflite 有 `sqflite_common_ffi` 纯 Dart 后端，且接口层本就允许宿主自实现。决定：**v0.1 包内只出接口 + 内存实现（InMemorySessionStore，测试用）**，SQLite 实现放宿主（`lib/harness_host/`），包保持纯净。M5 再评估是否出官方 sqlite 适配包。

---

## 5. 里程碑（每个 = 包内完成 + 宿主改一处锚点 + 产品仍可用）

### M0 · 包骨架 + 接口定型（1~2 天）
- 建 `packages/pocket_harness`，写第 3 节接口 + InMemorySessionStore + 名字冲突/事件流单测。
- 验收：`dart analyze` 0 error；`dart test` 绿；`dart pub deps` 确认唯一三方依赖 dartantic_ai。
- 宿主：**零改动**（App 此里程碑全程可跑）。

### M1 · 可逆工具注册表（2~3 天）——唯一"立刻有感"的里程碑
- 包内：ToolRegistry（register/disposer/冲突检测/changes 流）+ ToolSpec→dartantic `Tool<Map<String,dynamic>>` 桥（F18）。
- 宿主：
  1. 把 9 个内置工具（`:433-711`）逐个搬成 ToolSpec 注册（handler 逻辑一行不改，只换壳）；
  2. DB 工具循环（`:717-781`）改为查注册表 + PluginBus 验签后 register；
  3. `create_custom_tool`(498) 与遗留路径(757)：`Future.delayed(1s, initAgent())` → `registry.register(...)`；
  4. `change_system_settings`(623)：改为 bump `DBHelper.dataRevision`（F8，prompt 下一轮自动刷新）；
  5. `initAgent()` 收缩为「订阅 registry.changes → 重建 Agent.forProvider 的 tools 参数」。
- 验收：造工具后**当轮对话内**即可调用（不再"系统自动重启"）；工具页关开关即时失效；重名注册报错不崩溃；`switch_social_scenario`/主题切换不回归。
- 风险：MCP 分支(778-786) 是异步批量加载，M1 先保持"启动时一次加载"不动，M5 再治理。

### M2 · 会话 Thread + 结构化输出（3~4 天）
- 包内：SessionStore 接口 + InMemorySessionStore；AgentRuntime 集成 `sendFor<AgentReply>(outputSchema:)`（F2），AgentReply 是包内 DTO（reply/topic/keywords）。
- 宿主：SQLite SessionStore 实现（messages 表 + 新 session_events 轨迹表）；`sendMessage`(790-823) 改为：open session → 组 history（system + replay 的轨迹）→ sendFor → 轨迹 append → TurnOutput；**删除 798-800 的三条正则**；LocalModelService 降级(808-818)移入 runtime fallback。
- 验收：主聊天多轮连贯（历史真实生效）；杀进程重启后继续上一话题；XML 正则零残留；150s 超时与离线降级不回归。
- 注意：社交子 Agent 流水线（`_getRecentChatContext`）本里程碑**不动**，M4 才收编。

### M3 · 权限四档统一双轨（2~3 天）
- 包内：PermissionPolicy 接口 + Decision 三态；Harness.run 在 tool onCall 前强制过闸（含 critical 写审计回调）。
- 宿主：一个实现类收编双轨——normal 直行 / sensitive 走 PluginBus.hasGrant→grant（持久）/ high 走 _requestToolPermission（tool_auto_allow 白名单仍生效）/ critical 加 insertAudit；技能控制中心的吊销逻辑对接 disposer。
- 验收：三个内置高危工具照旧弹窗；DB 插件首次授权照旧持久；白名单工具不再弹窗；**permissions 列保持只写不读**（写一条测试钉住这个安全不变量）。
- 风险：`change_system_settings` 的参数级确认（只对 app_theme/social_mode 弹窗，`:572-583`）要在 Policy 里保留"按参数升级档位"的能力。

### M4 · 上下文管理（3~4 天）
- 包内：ContextManager（token 预算按 chars/4 估算起步）+ Compactor（超限把旧轨迹摘要折叠，摘要调用 runAuxiliary）。
- 宿主：`_getRecentChatContext`(811-831) 的 `limit: 50` 硬截断替换为 ContextManager；`_buildDynamicSystemPrompt`(269-312) 与 skills 管道（F12）归入 prompt 组装；`_getSystemPromptCached` 的 revision 失效语义保留。
- 验收：50 轮以上长会话关键信息不丢（固定问答脚本验证）；token 用量对比下降；摘要触发可观测（日志）。

### M5 · 可选增强（按需，每项 2~3 天）
- MCP 连接管理器：mcp_dart 已在 dartantic_ai 依赖内（F1），替掉 `_loadMcpToolsGuarded`(328-360) 的 2s 硬超时静默失败——命名空间化（mcp:服务名:工具名）、连接状态机、失败可观测、授权闸对接 M3 的 Policy。
- 工具语义检索：**前置风险——DeepSeek 无 embeddings API**（早年评估结论仍成立），要么接 Jina/本地小模型，要么降级为"描述关键词 BM25"。先做降级版（纯 Dart 可实现），embedding 版等 provider 明确再排。

---

## 6. 迁移映射总表（v0.2 修正版，行号全部核实）

| 现有代码（锚点） | 去向 | 里程碑 |
|---|---|---|
| 9 内置工具硬编码 `agent_service.dart:433-711` | 拆 ToolSpec → ToolRegistry | M1 |
| `existingToolNames` 去重 `:714-725` | ToolRegistry 名字冲突检测 | M1 |
| `Future.delayed(1s, initAgent())` `:498, :757` | `registry.register()` 热插拔 | M1 |
| `Future.delayed(1s, initAgent())` `:623`（prompt 刷新） | `dataRevision` bump（F8 机制已存在） | M1 |
| Agent 构造 `:787` / 临时 Agent `:848` | AgentRuntime / runAuxiliary | M1 / M2 |
| 正则抓 XML `:798-800` | `sendFor<AgentReply>` + Transcript | M2 |
| 主聊天无历史（`:794` 只传 [system]） | SessionStore Thread（0→1） | M2 |
| 离线降级 `:808-818` | runtime fallback 钩子 | M2 |
| `_requestToolPermission` `:132-154` | PermissionPolicy 宿主实现（high 档） | M3 |
| `_guardPluginRun` `:165-211` + PluginBus 授权 | 同上（sensitive 档，复用 grant/revoke） | M3 |
| PluginBus 验签 `:728-739` | **留在宿主**（设备密钥），注册前闸门 | M1（不迁移） |
| `_getRecentChatContext` limit:50 `:811-831` | ContextManager | M4 |
| `_buildDynamicSystemPrompt` + skills `:269-312` | ContextManager prompt 组装 | M4 |
| `_loadMcpToolsGuarded` `:328-360` | MCP 连接管理器（mcp_dart 已在内） | M5 |
| tools.permissions 列 | **只写不读不变**（F9 防篡改），仅作签名缓存/UI | 不迁移 |

## 7. 验收军规（沿用）

1. 每里程碑：包 `dart analyze`/`dart test` 0 error 全绿；宿主 `flutter analyze` 0 error。
2. 宿主每里程碑结束仍可：收发消息、造工具即用、切主题、社交雷达正常——改一处验一处，不做一次性大迁移。
3. 安全不变量测试化：permissions 列只写不读、插件验签 fail-closed、弹窗 60s 超时拒绝——三条各有一条测试钉住。
4. 铁律测试化：包的 `dart pub deps` 不得出现 flutter/sqflite/shared_preferences。

## 8. 明确不做什么（同 v0.1，追加两条）

- 不把 PluginBus 搬进包（依赖设备密钥与 prefs，属宿主安全策略）。
- 不在包内做 SQLite 强依赖（默认给 InMemorySessionStore，SQLite 放宿主适配层）。
- v0.1 的其余"不做什么"全部维持：不做 UI、不做多 provider、不做 OS 沙箱、不引重依赖、不做历史兼容抽象。
