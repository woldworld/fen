# pocket_harness × DeepSeek Harness 对齐报告

> 研究日期：2026-09-05。依据：github.com/deepseek-ai/deepseek-harness 主干
> （v0.1.3-alpha.1，2026-09-04 发布）、官方文档站、docs/ 架构文档、
> packages/bundle/base/cordis.patch.yml 真实源文件、docs/tool-catalog 工具目录。

## 一、研究结论（TL;DR）

1. **核心抽象全面对齐**。dsh 的"万物皆插件"五大支柱——可逆注册、追加式
   会话日志、统一工具契约、技能与工具同注册表、MCP 一等公民——pocket_harness
   全部有语义等价实现，且我们的**权限模型比 dsh 更严**（签名防篡改 +
   grant-before-connect 是 dsh 没有的）。
2. **差距在生态与高级层，不在核心**：dsh 的事件瀑布、通用服务容器、
   profile/patch 组合层、PTC、子代理等是"桌面全能框架"的配置；我们刻意
   不搬的是移动端不需要的重型件。
3. **DSH 插件不能直接跑**（TS/Cordis 服务 vs Dart），但可静态提取的资产
   已落地三条移植通道：`dsh_compat.dart`（技能 100% 直译 / patch 盘点 /
   MCP 命名互转），受限 YAML 解析器已用官方 20KB base-patch.yml 实测通过。

## 二、dsh 现状快照

| 项 | 事实 |
|---|---|
| 定位 | DeepSeek 官方开源 agent harness，"Everything is a Plugin" |
| 状态 | 开发者预览，官方明示**将有破坏性变更** |
| 底座 | Cordis（vendor 引入，论文《A Programming Paradigm for Spatiotemporal Composability》） |
| 规模 | 213k+ stars，15,210 commits，MIT，TypeScript/pnpm monorepo，60+ 内核包 |
| 发布节奏 | 2026-08-31 → 09-04 五个 release（alpha/rc 密集迭代） |
| 官方插件 | 160+；社区 GitHub topic `dsh-plugin`；兼容 Pi 生态 npm 插件 |
| 最近更新主题 | Session.events → `seq`/`eventAt()`/`snapshotEvents()` 按需读取；父子代理 `send_message` 取代单向 `report`；ACP 补齐；Python SDK runtime wheels（Windows/macOS）；实验性 Inspector/Web Preview；**移除可选 SQLite Session 后端**；社区 oh-my-dsh 推出插件升级 skill |

**对最近更新的解读**：dsh 迭代极快且自曝 breaking change，追 API 形态意义
不大；值得对齐的是**不变量**（追加式日志、可逆注册、模型可见即已记录），
这正是我们已经对齐的部分。

## 三、dsh 契约拆解

### 3.1 插件分发格式（npm 包）

```
my-dsh-plugin/
  package.json        # "dsh": { "bundle": "./cordis.patch.yml" }
                      # 或 "dsh": { "profile": { "bundles": ["@deepseek-ai/dsh-base"] } }
  cordis.patch.yml    # 插入行：- insert: [{ id, name: npm包, config, disabled }]
  src/index.ts        # Cordis Service 实现（inject + apply(ctx)）
```

- 安装：`dsh plugin --profile <name> add <package>@<version>`
- 组合顺序：bundles 按序叠加 → profile patch → home patch → `--patch` overlay；
  每行整 `config` 替换、最后写胜出
- `disabled: !!js expr` 做平台/环境门控（如 win32 才挂 pwsh）

### 3.2 工具契约（ToolDefinition）

`{ name, description, parameters(ValueSchemaSpec DSL), output(必需：canonical
JSON Schema + render), execute(args, exec), finalizeContent?, timeoutMs?,
isConcurrencySafe?, presentCall/presentResult? }`。模型请求只白名单暴露
name/description/parameters，执行与展示元数据绝不外泄。

执行管线：`tool/call` 落盘 → `tools/pre-execute` 瀑布（allow/deny/ask +
`ctx.approval` 一次性审批）→ 单调守卫 → `tools/execute` 瀑布（超时/重试
包装）→ `fs/*` 意图闸 → `tools/post-execute`（可改写结果）→ `finalizeContent`
→ `tools/result` 不可变权威结果。

### 3.3 技能（skill）

注册表 + 多提供方（项目 `.dsh/skills` 等 4 级优先级）→ 会话目录 → 模型按需
`skill` 工具加载 / 用户 `/name` 直调。文件形态：`<name>/SKILL.md` 或
`<name>.md`；frontmatter 键 `name` / `description` /
`disable-model-invocation` / `user-invocable`；名称 kebab-case 硬约束。

### 3.4 MCP

`@deepseek-ai/dsh-mcp-client`：stdio 子进程 + Streamable HTTP 两种传输；
工具公开名 `mcp__<serverName>__<tool>`；stdio 启动前剥离疑似凭据的环境
变量与全部 `DSH_*` 变量。

### 3.5 会话日志

仅追加 JSONL（v0 `session.jsonl` / v1+ `session.vN.jsonl[.zstd]`），generation
选择 + 相邻迁移链；**"模型可见即已记录"** 运行时不变量。

## 四、逐项对齐表

| # | dsh 机制 | pocket_harness 对应 | 判定 |
|---|---|---|---|
| 1 | Cordis 可逆注册（`ctx.effect()` 返回 disposer，teardown 撤销） | `ToolRegistry.register/registerSkill → ToolRegistration disposer` + `changes` 流 | ✅ 等价 |
| 2 | 仅追加 SessionEvent 日志 + "模型可见即已记录" | `SessionEvent`/`SessionStore`（append/replay(after)/close）+ 宿主 SqliteSessionStore | ✅ 等价（差异：他们有 generation 迁移链，我们 v19 起步无需历史包袱） |
| 3 | ToolDefinition{parameters→JSON Schema} | `ToolSpec{inputSchema: Schema}`（dartantic json_schema_builder，同为 JSON Schema） | ✅ 等价 |
| 4 | 工具/展示元数据不外泄给模型 | `schemas()` 白名单思想一致：我们只在 `_rebuildAgent` 桥接 name/description/inputSchema | ✅ 等价 |
| 5 | `tools/pre-execute` allow/deny/ask + `ctx.approval` + 单调守卫 | `PermissionPolicy.check` → `Allow/AllowAndRemember/Deny` + `bridgeTool` fail-closed + 宿主四档风险（normal/sensitive/high/critical） | ✅ 等价且更严（签名防篡改、授权从可信来源推导、**绝不**信任声明字段） |
| 6 | skill 注册表 + 目录 + 按需加载 + `/name` | `SkillSpec` + 同注册表同事件流 + 宿主 prompt 注入（fitLines 3000 预算） | ✅ 等价（机制取舍：他们省 token 靠懒加载，我们靠预算截断；移动端无斜杠 UI，prompt 注入更合适） |
| 7 | `mcp__<server>__<tool>` 命名 + stdio/HTTP + 凭据剥离 | `McpConnectionManager`：`mcp_<server>_<tool>`（清洗+64 截断）+ HTTP + grant-before-connect + `grantKey` 整组共享授权 | ✅ 等价（HTTP-only 是移动端取舍；stdio 在 PC 宿主可补） |
| 8 | `packages/compaction` | `Compactor`（阈值 60/保留 20、摘要折叠、kept 重附） | ✅ 等价 |
| 9 | 事件域：session/agent/capability × 5 种分发（emit/waterfall/parallel/serial/bail） | `changes`/`updates` 单 broadcast 流 | ⚠️ 部分（我们只有"可观察"，没有"可拦截"。对应缺口见第 5 行差距分析） |
| 10 | `agent/pre-step` 瀑布（模型可见前改写/拒绝消息） | 宿主 `_interceptStructuredMessage`（gift/reco 硬编码拦截） | ⚠️ 部分（我们是硬编码点，他们是可组合事件；规模到了再泛化） |
| 11 | `ToolRestriction`（per-scope allow/deny，子代理保底工具） | 宿主 `_dbToolCaps` + 权限档 + `ToolSearch` 显式 minScore | ⚠️ 部分（无 per-agent 作用域，单 agent 场景够用） |
| 12 | profile/bundle/patch 组合层（行级覆盖、平台门控、热重载） | 无。宿主侧 = DB 插件工具 + MCP 配置 + 设置项 | ❌ 缺（移动端无"配置树"需求，DB 插件即我们的组合单元） |
| 13 | PTC（`run_code` 程序化工具调用） | 无 | ❌ 缺（桌面重型特性，移动端 token 成本不划算；记入未来看板） |
| 14 | 子代理/Agent Teams/workflow/jobs/终端/LSP | 无（宿主有 `_createTempAgent` 仅用于压缩摘要） | ❌ 缺（同上，非移动端核心） |
| 15 | `SessionPersistence` 多后端 + 导出 | `SessionStore` 接口 + InMemory/Sqlite 双实现 | ✅ 接口面等价 |
| 16 | sessionProjections 投影 seam | 无（UI 直读宿主 DB） | ❌ 缺（Web 远程消费方才有此需求） |

**总评：16 项中 8 项等价、3 项部分、5 项缺失；缺失项全部属于桌面全能
框架的高级编排/组合层，无一属于 agent harness 核心闭环。**

### 4.1 我们独有、dsh 没有的

| 机制 | 为什么 dsh 没有 |
|---|---|
| `PluginSigner`/`PluginStore` 签名防篡改 + canonical 序列化 | dsh 信任 npm 源 + 本机 profile 文件；移动端插件来源不可信（蓝牙/DB 注入），必须 fail-closed |
| `grantKey` 整组共享授权 + grant-before-connect | dsh 逐次 `ctx.approval`；移动端无人值守场景需要"一次授权、随服务吊销" |
| 技能变更 `bumpRevision` → prompt 缓存刷新联动 | 对应 dsh 热重载的移动端等价物 |
| 身份指纹 / HELLO 防重放（社交协议层） | dsh 是单机 harness，没有 P2P 社交面 |

## 五、DSH 插件快速适配方案（已落地：`packages/pocket_harness/lib/src/plugins/dsh_compat.dart`）

三条通道，按适配成本排序：

### 通道 1：技能直译（100% 自动，覆盖生态最大面）

dsh skill 是纯 markdown（SKILL.md frontmatter），无代码依赖，可全自动转换：

```dart
final import = DshSkillImporter.import({
  'web-research/SKILL.md': skillText,
  'code-review.md': otherText,
});
for (final s in import.accepted) {
  await registry.registerSkill(SkillSpec(
    name: s.name,
    content: s.description.isEmpty ? s.body : '${s.description}\n\n${s.body}',
  ));
}
// import.rejected：坏名/重名清单，宿主提示用户（本层拒绝静默改写）
```

语义保留：`disable-model-invocation`/`user-invocable` 解析为布尔（默认值与
dsh 一致）；名称强制 kebab-case（宽松名自动归一，归不动就拒绝）；未知
frontmatter 键透传 `extraMetadata` 不解读。

### 通道 2：patch 资产盘点（自动分诊，指明人工边界）

```dart
final pkg = DshBundleReader.fromPackageJson(packageJsonText);
final patch = DshPatch.parseYaml(await File(pkg.bundlePatchPath!).readAsString());
final report = DshCompatReport.analyze(pkg.packageName, patch);
// report.rowVerdicts: 每行 direct-skill / mcp-server / needs-dart-tool /
//                     config-only / platform-gated
```

- `direct-skill` 行 → 通道 1 处理；
- `mcp-server` 行 → 通道 3 处理；
- `needs-dart-tool` 行 → **诚实边界**：execute 是 TS 代码，无法自动移植，
  用 `DshToolMap.classify(toolName)` 查官方 57 工具的覆盖判定
  （equivalent/partial/absent + 中文说明）决定重实现或放弃；
- `platform-gated` 行（`!!js`）→ 表达式原文捕获不求值，宿主在目标平台重估。

受限 YAML 解析器零依赖，只支持 cordis.patch.yml 实际子集（嵌套映射、单行
流式序列、`|` 块标量、`!!js` 捕获、行内注释），超子集**立即抛
DshFormatException 而非静默解析错**。已用官方 `dsh-base` 真实 20KB patch
实测：85 行全部解析，4 个平台门控行（bash/pwsh 沙箱对）与官方文档一致。

### 通道 3：MCP 直连（dsh 生态里的 MCP 服务器零适配）

```dart
final ours = DshNames.dshMcpToolToOurs('mcp__memorix__search');
// → 'mcp_memorix_search'（与 McpConnectionManager.namespace 同规则）
await mcpManager.loadServer(name: 'memorix', url: httpUrl, ctx: ctx,
    grantKey: 'mcp:memorix');
```

dsh 生态的 HTTP 传输 MCP 服务器（官方文档已给出记忆类等参考配置）改个
URL 即接入；stdio 型在移动端不可用（无进程模型），PC 宿主可后续补 stdio
传输。命名差异（`mcp__` vs `mcp_`）由 `DshNames` 双向互转兜底。

### 落地验证

- `test/dsh_compat_test.dart` 20 用例全过（skill frontmatter/归一/重名分流、
  YAML 子集含块标量与 `!!js`、超子集快速失败、MCP 互转与 64 截断、行归类、
  工具覆盖表）；
- 包全套 73/73 通过（原 53 + 新 20），零新增依赖，铁律不破。

## 六、后续建议（按 ROI）

> **2026-09-05 更新**：建议 2 的 `session_*` 检索工具与 `web_fetch` 已落地——
> 包内置 `builtin_tools.dart`（`buildSessionSearchTool` / `buildSessionReadTool`
> / `buildWebFetchTool`，含 SSRF 防护、重定向逐跳校验、HTML 转文本），宿主
> initAgent 已注册。对齐表相应项 partial → equivalent（DshToolMap 已同步）。
> 包 95/95、宿主 46/46、双端 analyze 零告警。

1. **短期**：用通道 1 引入 dsh 社区高星 skill 包做种子内容（纯文本、零风险）；
   宿主加一个"从剪贴板导入 dsh 技能"入口即可先用起来。
2. **中期**：PC 宿主补 MCP stdio 传输，打通 dsh 生态 stdio 型服务器。
3. **观察项**（dsh 明示 breaking change 期，不急着跟）：
   - 事件瀑布（对齐表 #9/#10）：单 agent 移动端暂无组合需求，出现第二个
     拦截点时再抽象；
   - PTC：等 dsh 稳定后评估移动端 token 成本；
   - 会话格式迁移链：等我们真有 v2 格式需求再说。
