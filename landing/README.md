# Landing site（Wold / Fen 官网落地页）

> ⚠️ **当前状态：本地产物，未上线。** 发布冻结期（不开源 / 不 `npm publish` / 不出 APK）内，
> 落地页**制作**可以照常做，**上线**必须等 §14.2 的 #12（仓库转 Public）/ #13（上传内容）之后 ——
> §14.3 顺序铁律：`… → 内容公开 → Landing 上线 → 发布 APK`。

## 为什么是静态站，不是 SPA

PRD §3.3 明确写了技术前提：**落地页需服务端渲染 / 静态生成（纯客户端 SPA 收录效果差）**，
并带 **schema.org 结构化数据**。所以这里是**构建期生成纯 HTML**，没有客户端渲染、
没有运行时框架、没有 CDN、没有外部字体 —— 离线也能完整渲染。

## 目录

```
landing/
  build.js        零依赖静态生成器（data + src -> dist；含 md -> HTML 渲染）
  serve.js        零依赖预览服务器（只绑 127.0.0.1）
  data/
    site.json     文案 + 品牌 + legal（唯一事实源）
    cities.json   城市数据（每城一条，新增城市只改这里）
  src/
    style.css     样式（系统字体栈，无网络请求）
  dist/           构建产物（**已 gitignore，判据＝生成物**）
                  index.html + 20 城市页 + privacy/index.html + sitemap.xml + robots.txt
```

## 命令

```bash
# 构建
node landing/build.js

# 预览（构建产物用了站点根路径 /style.css，必须走 HTTP，不能 file:// 直开）
node landing/serve.js      # http://127.0.0.1:4173/

# 校验输出（会先自动重新构建，再断言产物）
node tool/verify_landing.js
```

⚠️ 本机 Node 不在 PATH，Git Bash 下要用 **`D:/...`** 形式（`/d/...` 会被解析成 `d:\d\...`）。

## 新增一个城市

只改 `data/cities.json` 加一条：

```json
{ "slug": "osaka", "name": "Osaka", "country": "Japan", "region": "Asia",
  "image": "/assets/city/osaka.jpg",
  "blurb": "一句话讲清'刚落地'那一刻的处境。" }
```

`slug` 会成为 URL（`/osaka/`）与目录名；`image` 必须是 `landing/src/assets/city/<slug>.jpg`
（0.96.0 起构建器遇到缺图直接抛错）。构建器**遇到缺字段或 slug 重复也会直接抛错** ——
宁可构建失败，也不悄悄跳过一个城市。

## 上线前必须填的四项（`data/site.json`）

现在这几项是**空/占位**，构建器会**诚实渲染**（而不是造一个点了没反应的按钮）：

| 项 | 现在 | 上线前 |
|---|---|---|
| `cta.primaryUrl` | `""` → 主按钮渲染为**非链接**并标 `aria-disabled` | ~~填 GitHub Release 的 APK 地址~~ → **已裁决改指向本站 `/download/`**（见 `ADR/ADR-001-官网APK下载入口.md`；原 GitHub Release 地址实测 **404**）。`/download/` 页配 `landing/download/` 里的 `store` flavor arm64 分包，SHA-256 / 字节数 / 版本号 / 证书指纹**由产物实时算出**，禁止手抄 |
| OG 图片 | 无 | 需要品牌素材（当前无 `og:image`） |
| ~~隐私政策链接~~ | ✅ **已挂** `/privacy/`（见下节） | — |
| 等候名单邮箱收集 | 无 | 需要真实后端；**没有就不放表单** |

★ 最后一条是纪律：**没有能收的后端，就不要放一个看起来能收的表单**。
★ 同理（ADR-001 的直接诱因）：**也不要放一个点了是 404 的下载按钮** —— 2026-10-13 实测主/次 CTA
双双 404，而守卫 **152 PASS / 0 FAIL** 照样全绿（离线自足判据原本只禁外部*资源*，不管 `<a href>`
外部*锚点*）。现已补白名单/探活反向判据；**任何 `<a href>` 指向外部前先问：这个地址现在真存在吗？**

## 下载页（`/download/`）

按 `ADR/ADR-001-官网APK下载入口.md`，APK **由官网自托管**，不再依赖 GitHub Release：

1. 把 `flutter build apk --release --flavor store --split-per-abi` 产出的 **arm64 分包**
   （体积必须 ≤ 50 MB；全 ABI 胖包实测 91,209,871 B 不得直接挂）放进 `landing/download/`;
2. 构建器**读真实文件**算出 SHA-256 与字节数、读 `pubspec.yaml` 拿版本号，连同签名证书指纹一起渲染进页面；
3. **数据与产物漂移 ⇒ 构建失败**（哈希/版本不一致直接抛错）——
   这是刻意的：**手抄哈希必然在某次出包后失效**。

## 演示视频（`/demo/`）

按 0.111.0 落地：`/demo/`（与 `/zh/demo/`）内嵌**自托管**演示视频，mp4 **不入库**
（判据同 `landing/download/`：「是不是源码」，不是「有没有被引用」）。换视频 = 三步：

1. 把成片 mp4（+ 海报 jpg；或给 `--poster-at` 让 ffmpeg 抽帧）交给生成器：

   ```bash
   node tool/make_video_manifest.js <成片.mp4> --lang en --poster <海报.jpg> \
        --recorded-on "development build before 0.109.0" \
        --disclosure "Recorded on an earlier development build; the interface has changed since."
   ```

   生成器把素材复制成**版本化文件名**（`fen-demo-<lang>-<pubspec版本>.mp4`，同 APK 的
   `fen-<版本>-arm64.apk` 规矩），并用 crypto / ffprobe **实测**写出
   `landing/video/manifest.json`（字节 / sha256 / 时长）——**禁止手抄**。
2. 页面文案在 `landing/data/demo.json`（en）与 `demo-zh.json`（zh）的 `video` 段；
   `manifest.lang` 决定**哪个语言的页面出播放器**，另一种语言渲染「制作中」占位
   （双语同构 + 诚实降级，R27：缺素材就说缺，不放假播放器）。
3. `node landing/build.js` 把 `landing/video/` 整目录 copy 进 `dist/video/`，
   页面上的体积 / 时长全部由 manifest 的字节数算出。

`tool/verify_landing_video.js`（42 断言）三处对账：`landing/video/` 源 ↔ `manifest` ↔
`dist/video/`，外加语言契约 / 零外链 / `preload="none"`（不按播放不拉 20MB）。
manifest 与磁盘不符 ⇒ **构建直接抛错**（宁可构建失败，不放出数字不对的页面）。

⚠️ **manifest 现为单语种契约**（`lang` 一个值）：该语言的页面出播放器、另一个占位。中文片到位时先把 manifest 扩成按语种多条（如 `videos: {en:…, zh:…}`）再生成，否则英文播放器会被语言契约一并摘掉。

⚠️ `landing/serve.js` 预览服务器**不支持 HTTP Range**（生产 nginx 支持）：本地预览
拖动进度条会触发完整重新下载，发布环境不受影响。

## 隐私政策页（`/privacy/`）

上架表单要求填一个**可访问的隐私政策 URL**，所以 `build.js` 从
`lib/compliance/隐私政策.md` 生成 `/privacy/` —— **政策只有一份原文**，
不另抄一份到 `landing/` 里等着漂移。

生成时做三件事，全部**抛错而非静默**：

1. **填占位符**：`[生效日期]` / `[数据存储位置]` / `[跨境传输依据]` 取自
   `site.json` 的 `legal` 块；**任一为空 → 构建失败**（半成品页面上架比没有页面更糟）。
2. **剥内部流程字样**：工程草稿横幅、`给复核者的备注（发布前删除）` 尾注**不上线**。
   匹配是**结构化**的（"以标记开头的那个引用块"），所以横幅内文随便改都不用动代码；
   但**整块删掉会让构建失败** —— 那说明草稿的前提变了，生成器需要重读。
3. **复核状态不进页面**：`legal.reviewStatus` 只出现在 `dist/build-report.json`
   与控制台警告里。页面上是**成品政策文本**，不再出现「草稿」字样。

| `site.json` → `legal.*` | 值 | 来源 |
|---|---|---|
| `policySource` | `lib/compliance/隐私政策.md` | 唯一事实源 |
| `effectiveDate` | `2026-09-28` | **写死**，不用构建日期 —— 生效日期不该每次构建都漂 |
| `dataLocation` | 新加坡（阿里云轻量应用服务器） | 与《海外服务器购买与部署清单》§地域一致 |
| `crossBorderBasis` | 不宣称已签 SCC 的诚实版本 | ⚠️ **正式商用前须法务定稿** |
| `reviewStatus` | `pending-counsel` | 法务签字后改 `approved` |

⚠️ **服务条款页尚未生成** —— `lib/compliance/服务条款.md` 在同一位置，
需要时照 §隐私政策页 再加一段即可（生成器已具备 md→HTML 能力）。

## 诚实性约束（写进校验，不靠人记得）

`tool/verify_landing.js`（**63 断言**）钉住了这些：

- 城市数据 ↔ 生成页面**一一对应**（缺一个城市 = FAIL，不是"少一页看不出来"）
- 首页每张城市卡片**都指向真实存在的页面**（无死链）
- JSON-LD **可被 `JSON.parse`**，且裸 `<` 已转义（不会截断出 `<script>`）
- 每页有 canonical / description / og / BreadcrumbList
- sitemap URL 数 = 2 + 城市数（首页 + 隐私页 + 城市页），且全在本站域名下
- **无发布地址时不得出现 `btn-primary` 的 `<a>`**（不做死链按钮）
- 页面**不引用外部脚本 / 字体 / 图片**（离线自足）
- ★ 隐私页**无未填占位符**、**无内部流程字样**（草稿 / 复核备注 / 发布前删除）
- ★ 首页与**全部**城市页页脚都挂了 `/privacy/` 链接（藏起来的政策 = 没有政策）

