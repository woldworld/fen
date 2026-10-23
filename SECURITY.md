# Security Policy / 安全策略

## Reporting a vulnerability / 报告漏洞

**Do not open a public issue for security problems.**
Email **privacy@wold.world** with: affected component (app / protocol package /
trial relay), a reproduction path, and impact assessment.

We aim to acknowledge within 72 hours and publish a fix + credit (if desired)
after the fix ships.

中文：安全问题**不要开公开 issue**，请发邮件至 privacy@wold.world（附组件、
复现路径与影响评估）。确认后 72 小时内响应；修复发布后致谢（如你愿意）。

## Scope / 范围

In scope:
- Identity & key handling (`lib/core/agent_identity.dart`, `key_backup.dart`,
  `identity_recovery.dart`, `identity_rotation.dart`, `device_migration*.dart`)
- Signature verification (`packages/protocol`: envelope / DID / rotation)
- The trial relay (`/api/trial/*`) — auth, quota, content handling
- Permission gates in the agent runtime (`bridgeTool`, `HarnessPermissionPolicy`)

Out of scope:
- The landing site (static, no backend)
- Rate-limit tuning suggestions without a working bypass
- Reports from compromised devices (rooted/emulator) involving keys that left
  the device by design (e.g., user-shared recovery codes)

## Design invariants / 设计不变量（violations = vulnerabilities）

1. Private keys never leave the device; backups are passphrase-encrypted seeds.
2. Server never stores prompt content; the trial relay forwards and forgets.
3. All write endpoints require signature verification (TOFU registration);
   anonymous read endpoints are rate-limited and never expose keys.
4. Agent permission gates fail closed — policy errors deny.
5. The transparency log is append-only and publicly recomputable.

## Device-permission surfaces / 设备权限面

This repository is an **agent runtime**, not a monitoring product. Three Android
capability surfaces are involved, and each is bounded by code — not only by
policy.

| Surface | What it can reach | What bounds it |
|---|---|---|
| Accessibility service (`DahuangAccessibilityService`, declared in `main`) | window node text + coordinates; tap / swipe / text input / key / app launch | app-level master switch defaults **off** (`device_control_enabled ?? false`); every action is logged; **danger-app denylist hard-refuses to act** |
| Notification listener (`DahuangNotificationListener`) | notification title / text / bigText (ring buffer) | the service is **declared only in the `sideload` flavor** — the `store` build ships zero restricted permissions and zero extra services |
| SMS (sideload only) | `READ_SMS` + `RECEIVE_SMS` | never `SEND_SMS` / `WRITE_SMS` / `READ_CALL_LOG` / `WRITE_CALL_LOG` (asserted by `tool/verify_notify_sms.dart`) |

Default denylist — 13 packages, `lib/core/device_control_service.dart`: system
Settings, Alipay, WeChat, UnionPay, ICBC, CCB, BOC, BCM, CMB, Ant Fortune, QQ,
1Password, LastPass. With any of them in the foreground the service **returns
an error instead of performing the gesture**.

Explicit boundaries:

1. **Do not run this on a device you do not own.** Reading another person's
   screen or notifications without their informed consent is unlawful in most
   jurisdictions and is not a supported use of this code.
2. Publishing this source is a **capability disclosure**, not an endorsement of
   surveillance tooling. A fork that strips the denylist, the default-off
   switch or the audit log is **not** `wold/1 compatible` and may not use the
   project marks (see [TRADEMARK.md](TRADEMARK.md) §4).
3. The `sideload` flavor is **never publicly distributed**; public builds use
   `store`.

中文：本仓是**智能体运行时**，不是监控产品。无障碍服务能读取窗口节点文字/坐标并
模拟点击输入，但 ① App 级总开关默认**关闭**、每步操作留痕；② **危险应用黑名单硬拒绝
执行**——系统设置 / 支付宝 / 微信 / 银联 / 工行 / 建行 / 中行 / 交行 / 招行 / 蚂蚁财富 /
QQ / 1Password / LastPass，共 13 个。通知监听与短信读取**只存在于 `sideload` 侧载清单**，
`store` 公开构建零受限权限、零新增服务；短信只读（`READ_SMS` / `RECEIVE_SMS`），绝不声明
发送与写入。

**请勿部署在你并不拥有的设备上**——未经知情同意读取他人屏幕或通知，在多数法域属违法。
摘掉黑名单 / 默认关闭 / 审计日志的魔改分支不算 `wold/1 compatible`，也不得使用项目标识
（见 [TRADEMARK.md](TRADEMARK.md) §4）。

## Deployment notes / 部署者注意

如果你照 `packages/protocol` 自建服务端：
- **不要把任何含服务商 API Key 的配置文件提交进仓库**（本项目称之为
  trial pool；模板见协议包，真文件必须留在服务器本地并加入 `.gitignore`）。
- 管理密钥（admin key）应在**安装时生成**、只存服务器本地，绝不随代码分发。
- 写接口一律要求签名验证（TOFU 注册），匿名读接口必须限流且永不暴露密钥。
