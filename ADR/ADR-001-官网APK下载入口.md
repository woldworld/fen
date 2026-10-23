# ADR-001：官网 APK 下载入口 —— 改为官网自托管（`/download/`）

- **状态**：已接受（Accepted）
- **日期**：2026-10-13
- **作者**：智能体（起草）+ 主人（决策）
- **决策人 / 签字**：主人，2026-10-13 00:0x（口谕："官网自托管 APK"）
- **关联**：PRD §14.2 #15（原「发布 APK＝GitHub Release + SHA-256」）、§14.3 顺序铁律、`landing/README.md`「上线前必须填的四项」、红线 R9（APK 签名）、R13（发布面）、R16（出包判据）、R18（渠道隔离）
- **编号说明**：本仓库首份 ADR，无前序编号承接。

## 1. 背景与问题

### 1.1 触发事实（2026-10-13 取证，全部可复现）

| 事实 | 实证 |
|---|---|
| 官网主 CTA「获取 Android APK」是**死链** | `landing/data/site.json` 的 `cta.primaryUrl = https://github.com/woldworld/dahuang/releases/latest` → **实测 404** |
| 次要 CTA「阅读协议」也是死链 | 同文件 `cta.secondaryUrl = https://github.com/woldworld/protocol` → **实测 404** |
| 全站 34 个外链里**只有**这两条是外部链接且失效 | 其余 32 条均为 `wold.world` 的 canonical/hreflang，站内产物齐备，**零死链** |
| **守卫放过了它们** | `tool/verify_landing.js` 的离线自足判据只禁 `http(s)://` 的**资源引用**（script/img/font/link rel=stylesheet），**不检查 `<a href>` 锚点** ⇒ **152 PASS / 0 FAIL 全绿也照样让死链过审** —— 这是「以为成功不算成功」的同族问题 |

一句话：**0.98.0 把"让人想下载"做到了，但"真能点到下载"这一米还没接上。**

### 1.2 这不是新需求，是改既有决策（所以必须走 ADR）

PRD 里早已定过下载口径，本 ADR 要改的就是这两处：

- **§14.2 #15**：`| 15 | 发布 APK（GitHub Release + SHA-256） |` —— 分发渠道被定为 GitHub Release。
- **§14.3 顺序铁律**：`内容公开 → Landing 上线 → 发布 APK` —— APK 发布**排在 Landing 上线之后**。
- **`landing/README.md`**：「上线前必须填的四项」表格写明 `cta.primaryUrl` 现在为空占位、**上线前应填 GitHub Release 的 APK 地址**。

⇒ 所以冲突不是"自托管好不好"，而是：**§14.2 #15 把 APK 分发绑在 GitHub Release 上，而 GitHub Release 要等 #12（仓库转 Public）/ #13（上传内容）先完成；主人不想把"让用户真能下载"等到那一天。**

### 1.3 落点真相（决定成本的两个实测数）

| 数据 | 实测值 |
|---|---|
| 现成 APK（store flavor） | `build/app/outputs/apk/store/release/app-store-release.apk` **91,209,871 B（≈87 MB）** |
| 现成 APK（sideload flavor） | `build/app/outputs/apk/sideload/release/app-sideload-release.apk` **91,210,135 B** |
| 构建日期 | 2026-10-11，对应最后一个改动 `lib/**/*.dart` 的 commit `8f56fa4`（0.90.0）⇒ **APK 与当前代码一致，无需重出** |
| 签名状态 | `apksigner verify -v` → `Verifies`，`v2 scheme: true`，其余全部 false，**Number of signers: 1** ⇒ 完全符合 R9「只签 v2」 |
| 当前部署包 | `大荒服务器一键部署包.zip` **2,231,111 B**（内含 `site/` 45 文件） |
| flavor 定义 | `android/app/build.gradle.kts:88-99`：`create("store")` 与 `create("sideload")`，**同 `applicationId = world.wold.fen`**；受限权限只在 `src/sideload/` |

**★ 成本真相**：把 91 MB 胖包塞进部署包 ⇒ 体积从 2.2 MB 涨到 **≈93 MB（40 倍）**。原因是 R16 的 CMake 策略按**全部 ABI**（含 x86/x86_64）打包。因此"自托管"必须先解决体积，否则只是换了一个坏处。

## 2. 决策

> **官网自托管 APK。** CTA 不再直指任何尚未存在的外部地址，一律指向本站 `/download/`；对外只分发 **`store` flavor 的 arm64 分包**（或其 ≤50 MB 的等价形态），并在下载页公布可核对的哈希与签名指纹。GitHub Release 不取消，将来 #15 生效时作为**镜像**，不作为唯一入口。

### 2.1 硬规则（每条都要能写成断言）

1. **CTA 不得直指外部下载域**：官网 `/`、`/zh/`、`/download/` 上任何「下载 APK」的 `<a href>` 必须指向**本站相对路径**（`/download/...` 或 `.apk` 本地相对路径）；**出现任何 `https://` 的 APK 直链即 FAIL**。
2. **下载页四项必须在位**：`/download/` 必须同版面公布 **① SHA-256 ② 精确字节数 ③ 版本号 ④ 签名证书指纹**；四项缺一即构建失败。
3. **哈希必须是"算出来的"，不是"写下来的"**：bootstrap 数据里**不得出现手抄哈希**，构建时**读真实 APK 文件实时计算**并注入页面 ⇒ 从根上杜绝"数据与产物漂移"（0.98.0 已实证：静态串会被 markdown 渲染改写而永不匹配）。
4. **版本号必须与 `pubspec.yaml` 逐字一致**：下载页展示的版本 != `pubspec.yaml` 的 version ⇒ FAIL。
5. **对外只挂 `store` flavor**：`/download/` 只允许引用 `app-store-release-*.apk`；**`sideload` 包不得出现在官网产物里**（R18：受限权限只存在于侧载渠道），由断言钉死。
6. **体积硬上限**：对外分发的单个 APK **≤ 50 MB**。当前 87 MB 全 ABI 胖包**不得直接挂上官网**，必须先做 `--split-per-abi`（arm64 单包）。若拆分后仍 > 50 MB，需在实施时回来改本条门限并记录实测值。
7. **失效外链必须显式处理**：`cta.secondaryUrl`（protocol 仓库）在 #12 完成前不可能存在 ⇒ 要么改为指向站内页（如 `/docs/`），要么进**守卫白名单**并在 ADR 记录"待 #12 恢复"。**不允许继续让它静默 404。**
8. **守卫必须补反向判据：外部锚点白名单/探活** —— 现有离线自足判据只管资源不管 `<a href>`；「所有 `<a href="http(s)://...">` 必须落在白名单内；白名单外的必须先过探活或显式豁免并注明恢复条件」。
9. **APK 不进 git**：产物留在 `landing/dist/`（已 gitignore）。**禁止**为了"方便"把 APK 放进 `landing/src/assets/`（那会让它变成入库资产）。

## 3. 备选方案

| 方案 | 判断 | 理由（落到 ADR 编号 / 实证） |
|---|---|---|
| **A′ 官网自托管 arm64 分包** | ✅ **采纳**（决策人 2026-10-13 选定） | Landing 上线那一刻就有真下载，不必等 #12/#13；自托管保持离线自足、零外部依赖；配合 §2.1 规则 2–5，可验证性不降反升（哈希+指纹+版本号全部由产物算出） |
| A 官网自托管 91 MB 全 ABI 胖包 | ❌ 否决 | 部署包 2.2 MB → **≈93 MB（40×）**；单用户下载 87 MB 不必要地包含 x86/x86_64（真机是 arm64）。违反本次硬规则 6 |
| B 维持 §14.2 #15「GitHub Release + SHA-256」 | ❌ 否决 | 依赖 #12 仓库转 Public 先完成；在此之前 **CTA 继续是 404**，等于用户的下载欲被当场打断。与主人"上线即能下载"目标冲突 |
| C 诚实降级（暂不提供下载） | ❌ 否决（决策人已裁） | 与"让人看完就有下载试用的强烈愿望"**直接冲突**；且 §14.2 #15 说明下载是既定项，只是渠道待定，不是"要不要"的问题 |
| D 混合（自托管 + 将来 GitHub Release 镜像） | 🟡 后续兼容，不冲突 | 本 ADR 不取消 #15；#15 生效后 GitHub Release 作为第二入口，/download/ 保持为权威源（哈希以本站为准） |

## 4. 影响面

起草阶段为**预计落点**（未经实施验证，见 §7）：

- 新增：`ADR/ADR-001-官网APK下载入口.md`（本文件）
- 新增：`landing/data/download.json` + `download-zh.json`（下载页文案骨架；不含哈希）
- 修改：`landing/build.js` —— 新增 `/download/` 页生成：读真实 APK → 算 SHA-256 与字节数 → 读 `pubspec.yaml` 版本号 → 注入页面；**产物缺 Fat jarlim ⇒ 构建失败**
- 修改：`landing/src/style.css` —— 下载页样式（沿用既有 CSS 变量，明暗双主题零 JS）
- 修改：`landing/data/site.json` / `site-zh.json` —— `cta.primaryUrl` → `/download/`；`secondaryUrl` 按 §2.1 规则 7 处置
- 修改：`tool/verify_landing.js` —— 新增下载页 + 外部锚点白名单 + flavor 正确性 + 版本/哈希一致性断言
- 修改：PRD（§14.2 #15 划改 + 新建 §14.4 ADR 登记簿 + 决策 #61）
- 产物：`landing/dist/download/…`（APK 副本，**不入库**）；部署包重打
- **零**：新表 / 新依赖 / Schema 变更 / `lib/**/*.dart` 改动 / 既有端点语义变更

## 5. 风险与回滚

| 风险 | 处置 |
|---|---|
| 部署包涨到数十 MB | 须先 `--split-per-abi`；若实测 arm64 单包仍 > 50 MB，回头修订硬规则 6 门限并记录实测值 |
| 哈希/版本与产物漂移（最容易"一次做对、下次就歪"的缺陷） | 硬规则 3、4：哈希与版本号**全部从真实产物/ YAML 读出**再渲染，数据层不允许留手抄值；守卫逐项断言 |
| 误挂 `sideload` 包（把受限权限发给陌生人） | 硬规则 5 + 断言：只有 `store` 产物允许出现在 `/download/`；`src/sideload/` 权限面不变 |
| APK 可被反编译暴露 Hub 地址等 | 已知且可接受：APK 内**无密钥**（R6 真 Key 不入库）；列为 §7 诚实边界，不在本 ADR 治理范围 |
| 将来 #15（GitHub Release）上线后双源不一致 | 本 ADR 声明：本站 `/download/` 为**权威源**，Release 仅为镜像；届时在 Release 说明里指向本站哈希 |
| 回滚 | `/download/` 是新增页，删除即回退；CTA 复原为外部链接需再走一份 ADR（不得静默回退到 404 形态） |

## 6. 实现证据

**无 —— 本文件处于「已接受、未实施」状态，从未进入过代码编写阶段。**

本 ADR 的产出是"裁决"，不产生任何实现证据；**不得在将来被读成「做了但没记录」**。
实测数据（§1.1 / §1.3 的 404、APK 体积、签名状态、flavor 定义）属于**取证**，不属于实现。

## 7. 诚实边界

1. **尚未写一行业务代码**：`landing/`、`tool/`、`lib/` 均未改动；90 MB APK 也尚未构建 arm64 分包。
2. **arm64 分包体积是推算不是实测**：50 MB 门限是基于 Flutter arm64 分包常见区间的**估计值**，实际需 `flutter build apk --split-per-abi` 后才知道；可能落在 30–45 MB，也可能超门限。
3. **次要外链（`protocol` 仓库）的最终形态尚未选定** —— 规则 7 给了两条路，尚未选定，取决于是否愿意增加站内跳转。
4. **APK 反编译面未审计**：未做字符串级扫描确认 APK 内确实不含内部主机名/路径；如需，应单独立项。
5. 本 ADR 不涉及 P1（App 首启引导移植），该改动是否需独立 ADR 另行判定（初判：属增强层，四问全"是"，不需 ADR —— 见会话内的逐条实证）。

## 8. 决策

| 项 | 内容 |
|---|---|
| **裁定** | ✅ **接受** —— 官网自托管 APK（arm64 分包），CTA 指向 `/download/`，GitHub Release 降为将来镜像 |
| 决策人 + 日期 | 主人，2026-10-13 |
| 同时否决 | A（91 MB 胖包，体积）、B（维持 GitHub Release，继续 404）、C（诚实降级，与目标冲突） |
| 生效前提 | §2.1 九条硬规则**全部**写成守卫断言并跑绿，方算「落地」（光有页面不算） |
| 阶段收口 | 下载入口路线至此定案：自托管 ✅ / 胖包 ❌ / GitHub 独占 ❌ / 降级 ❌ |
