# F-Droid 提交材料（world.wold.fen）

> ★ 状态：**材料已备，尚未提交**。本目录是一份待提交的草稿包，不是「已上架」的声明。
> 提交前置条件全部满足之前，`metadata/world.wold.fen.yml` 对 F-Droid 不生效。

## 这个包装了什么

| 文件 | 作用 |
| --- | --- |
| `metadata/world.wold.fen.yml` | 构建配方：版本、tag、flavor、未签名产物路径、Flutter srclib、NonFreeNet 反特性 |
| `metadata/world.wold.fen/en-US/` | 英文标题 / 短描述 / 完整描述 |
| `metadata/world.wold.fen/zh-CN/` | 中文标题 / 短描述 / 完整描述 |

配套的代码侧改动（已入库）：`android/app/build.gradle.kts` 的
`WOLD_UNSIGNED_RELEASE=1` 显式环境变量门 —— 无 key.properties 时出**未签名**
release 包供 F-Droid 自签；不设该变量时缺密钥仍**显式失败**（禁止静默回退
debug 签名的纪律不变）。

## 提交前置条件（缺一不可）

1. **源码仓库公开**。当前开源仍冻结。走 `opensource_release.ps1` 导出发布树、
   推送 GitHub（见《开源发布-一键提交说明.md》）。★ 公开树**必须能构建**——
   `third_party/workmanager_android` 与 `packages/pocket_harness` 是路径依赖，
   必须随仓库公开（发布脚本已保证入库，提交前在公开树上实测一遍：
   `flutter pub get` + `flutter build apk --release --flavor store
   --target-platform android-arm64`）。
2. **打 tag**。配方写的是 `commit: v0.112.0`，当前仓库只有 `0.105.0` 一个 tag。
   提交前 `git tag v0.112.0 && git push origin v0.112.0`。
3. **替换 OWNER 占位符**。yml 里 `SourceCode` / `IssueTracker` / `Repo` 三处的
   `OWNER` 换成真实 GitHub 用户名。
4. **核对 srclibs 的 Flutter tag**。配方用 `flutter@3.44.0`（= 本仓 `.metadata`
   钉的 revision 559ffa3f75，也是官网 APK 实际构建版本）。提交前确认该 tag 在
   flutter/flutter 仓库存在。
5. **截图**。F-Droid 要求每种语言至少 2 张手机截图（`phoneScreenshots/`），
   放到 `metadata/world.wold.fen/<locale>/phoneScreenshots/`。建议用官网
   `/demo/` 同款画面（章回剧场首启 + 会客厅 + 设置页），保持双端一致。

## 提交方式

- **RFP（Request for Packaging）**：在 https://gitlab.com/fdroid/rfp 开 issue，
  附仓库地址；维护者会认领并写配方——也可以直接提交我们这份配方。
- **直接提交配方**：fork `fdroid/fdroiddata`，把 `metadata/world.wold.fen.yml`
  与 `metadata/world.wold.fen/` 放进去，开 merge request。
- 审核关注点（主动说明，别等被问）：
  - **NonFreeNet**：默认 hub 端点是项目自营服务，网络层代码专有不在仓库——
    这是打标签的理由，不是缺陷。
  - **签名**：F-Droid 自签 ⇒ 与官网包签名不同、不能互相覆盖升级。官网
    `/download/` 三渠道页已向用户说明，提交说明里再讲一次。
  - **权限**：store flavor 零受限权限（短信/通知监听只在 sideload，永不分发）。

## 版本更新流程（每次发版）

1. pubspec 升版本（versionName + versionCode）。
2. 打对应 tag 并推送。
3. 更新 yml 的 `versionName` / `versionCode` / `commit` / `CurrentVersion` /
   `CurrentVersionCode`。
4. 描述有实质变化时同步 `full_description.txt`（中英）。
5. 守卫 `tool/verify_fdroid_metadata.js` 会核对配方与仓库事实（flavor、
   产物名、版本号）是否一致——改完先跑它。
