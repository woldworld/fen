# pocket_harness

**Mobile-first agent harness for Dart.** 为移动端 AI 智能体提供"万物皆插件"的
执行底座：可逆工具注册表、四档权限闸、追加式会话轨迹、上下文预算与压缩、
MCP 连接管理、内置会话检索与公网抓取工具。纯 Dart，零 Flutter 依赖。

从「大荒AI」（一个自主社交的移动端个人智能体）的生产代码中抽出，95 个单元
测试守护，已在线上 App 中驱动对话、热插拔与 MCP 工具调用。

## 设计立场

- **mobile-first**：不搬桌面全能框架的重型件（PTC、子代理、配置树），
  为无人值守的手机场景收紧安全默认值。
- **零 Flutter 依赖**：唯一第三方依赖是
  [`dartantic_ai`](https://pub.dev/packages/dartantic_ai)（多 provider LLM 客户端，
  已核实纯 Dart）。所有宿主能力经接口注入，本包可在纯 Dart CLI / 服务端运行。
- **fail-closed**：权限策略异常 = 拒绝；会话未 open 即 append = 抛错；
  插件清单规范化序列化任何字节被改 = 验签失败。宁可少做事，不静默做错事。

## 30 秒上手

```bash
dart run example/pocket_harness_example.dart
```

```dart
import 'package:pocket_harness/pocket_harness.dart';

final registry = InMemoryToolRegistry();

// 1. 注册工具：可逆——register 返回 disposer，卸载即撤销并广播变更
final reg = registry.register(ToolSpec(
  name: 'get_time',
  description: '获取当前时间',
  permission: PermissionLevel.normal,
  handler: (ctx, args) async => DateTime.now().toIso8601String(),
));

// 2. 技能进同一注册表：消费端是 prompt 注入而非函数调用
registry.registerSkill(SkillSpec(name: 'tone', content: '始终用温和的语气'));

// 3. 桥接给 LLM：权限闸前置，异常收口为错误文本
final dartTool = bridgeTool(spec, toolContext, policy: myPolicy);

// 4. 不需要了？可逆卸载
reg.dispose();
```

## 核心抽象

| 抽象 | 职责 | 关键约定 |
|---|---|---|
| `ToolRegistry` | 工具 + 技能同一注册表 | register 返回 disposer（可逆）；重名抛 `ToolNameConflict`；`changes` 流广播增删 |
| `PermissionPolicy` | 四档授权的真实闸门 | normal / sensitive / high / critical × allow / allowAndRemember / deny；策略异常 fail-closed |
| `SessionStore` | append-only 轨迹 | 未 open 即 append 抛错；`replay(after)` 游标幂等；持久化实现在宿主 |
| `ContextManager` | 上下文预算 | newest-first 字符预算选材、上一份摘要折叠、行级截断 |
| `Compactor` | 长会话压缩 | 阈值压缩 + 摘要折叠，保留事件在摘要后重附（防吞没） |
| `AgentRuntime` | 一轮对话的驱动 | sendFor 结构化输出 → send → fallback 三级降级；历史构建走预算 |
| `McpConnectionManager` | MCP 一等公民 | 工具名命名空间化、状态机可观测、超时可配、`grantKey` 整组共享授权 |
| `ToolSearch` | 工具检索 | 关键词 fallback，CJK 二元组加权（名称 ×3 / 描述 ×1） |
| `PluginManifest` / `PluginSigner` / `PluginStore` | 插件契约层 | 规范化序列化 + 防篡改签名；签名算法与存储后端由宿主注入 |

## 内置工具（v0.2）

依赖显式注入（`SessionStore` / `HttpClient` 由调用方提供）：

- **`session_search` / `session_read`** —— 模型侧会话自检索：关键词命中给序号，
  按序号翻页读原文。agent 能回忆早前的约定与事实。
- **`web_fetch`** —— 公网只读抓取：SSRF 防护（拒绝回环/内网/CGNAT/云元数据/
  IPv6 唯一本地与 IPv4 映射）、重定向手动跟随且**每一跳重新校验**、HTML 转纯
  文本、体积与长度双截断。

## DeepSeek Harness 兼容层

[DeepSeek Harness（dsh）](https://github.com/deepseek-ai/deepseek-harness)
的插件是 TypeScript/Cordis 服务，无法在 Dart 内执行；本包提供其**可静态提取
资产**的三条移植通道（`lib/src/plugins/dsh_compat.dart`，零依赖）：

1. **技能直译** —— `DshSkillImporter` 把 dsh 的 `SKILL.md`（frontmatter
   name/description/调用策略）100% 转为技能数据；kebab-case 校验归一，坏名拒绝。
2. **patch 盘点** —— `DshPatch.parseYaml` 解析 dsh 插件包的 `cordis.patch.yml`
   （受限 YAML 子集，超子集快速失败），`DshCompatReport` 自动分诊每行资产：
   技能直译 / MCP 直连 / 需 Dart 重实现 / 平台门控。已用官方 dsh-base 真实
   20KB patch 实测（85 行全过）。
3. **MCP 直连** —— dsh 生态的 HTTP 型 MCP 服务器直接接入
   `McpConnectionManager`；`DshNames` 做 `mcp__server__tool` ↔ `mcp_server_tool`
   双向命名互转。

工具的 execute 是 TS 代码，无法自动移植——`DshToolMap` 给出官方 57 工具的
覆盖对照（等价/部分/缺席），不提供假兼容。

## 开发

```bash
dart pub get
dart analyze   # 0 issue（strict-casts / strict-inference）
dart test      # 95+ 用例全绿
dart run example/pocket_harness_example.dart
```

宿主对接范例（ToolContext 三件套、SQLite SessionStore、HMAC 签名器）见
「大荒AI」仓库的 `lib/harness_host/`。

## License

[MIT](LICENSE)
