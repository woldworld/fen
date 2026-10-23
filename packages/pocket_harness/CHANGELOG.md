# Changelog

所有显著变更记录在本文件。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## 0.2.0 (2026-09-06)

### 新增

- **内置工具集**（`lib/src/tools/builtin_tools.dart`，依赖显式注入）：
  - `session_search` / `session_read`：模型侧会话自检索（关键词命中 → 序号 → 翻页读原文）；
  - `web_fetch`：公网只读抓取。SSRF 防护（回环/内网/CGNAT/云元数据/IPv6 唯一本地与
    IPv4 映射全部拒绝）、重定向手动跟随逐跳校验、HTML 转纯文本、体积与长度双截断；
  - `WebFetchGuard.isPublicHttpUrl` 独立公开，宿主可复用。
- **DeepSeek Harness 兼容层**（`lib/src/plugins/dsh_compat.dart`，零依赖）：
  - `DshSkillImporter`：dsh `SKILL.md`（frontmatter name/description/调用策略键）
    100% 直译为技能数据，kebab-case 校验与归一、坏名拒绝不静默改写；
  - `DshPatch.parseYaml` / `DshBundleReader` / `DshCompatReport`：解析 dsh 插件包的
    `cordis.patch.yml`（受限 YAML 子集，超子集快速失败）并自动分诊每行资产的
    适配路径；已用官方 dsh-base 真实 20KB patch 实测通过；
  - `DshNames`：dsh MCP 工具命名 `mcp__<server>__<tool>` 与本包
    `mcp_<server>_<tool>` 双向互转；
  - `DshToolMap`：dsh 官方工具覆盖对照表（等价/部分/缺席）。

## 0.1.0 (2026-09-03)

首个可用版本（M0–M5 里程碑）。

### 新增

- `ToolRegistry`：**工具与技能同一注册表**——可逆注册（register 返回 disposer）、
  重名冲突抛错（fail-closed）、统一变更事件流（EntryKind 分流）；
- `PermissionPolicy` 契约：四档风险（normal/sensitive/high/critical）、三态决策
  （allow / allowAndRemember / deny）、策略自身异常一律 fail-closed；
- `SessionStore` append-only 契约 + 内存实现：未 open 即 append 抛错、
  游标幂等回放；持久化实现由宿主提供；
- `ContextManager`：字符预算 newest-first 选材、上一份摘要折叠、行级截断；
  `Compactor`：阈值压缩、保留事件在摘要后重附（修复摘要吞没保留事件的缺陷）；
- `AgentRuntime`：`sendFor` 结构化输出 → 普通 `send` → 离线 fallback 三级降级链，
  历史构建走 ContextManager 预算；
- MCP 连接管理器：工具名命名空间化（清洗 + 64 截断）、每台服务器状态机可观测
  （connecting/ready/failed + 更新流）、超时可配、`grantKey` 整组共享授权；
- 工具检索关键词 fallback（CJK 二元组加权，名称×3 / 描述×1）；
- 插件契约层：`PluginManifest` 规范化序列化（键序固定、能力排序）+
  `PluginSigner` / `PluginStore` 抽象（签名算法与存储后端由宿主注入）；
- `ToolSearch` 工具检索、`bridgeTool` 桥接（权限闸前置 + 异常收口）。
