# 大荒AI 官网设计系统（landing）

> 本文件描述 `landing/src/style.css` 的**真实面貌**，不是愿景文档。
> 每一条结构化声明都被 `tool/verify_landing_design.js` 对着样式表逐字核对：
> 漏写、多写、编造，回归即红；改了样式表不改本文件，同样红。
> 可访问性与性能判据不在这里钉，由 `tool/verify_landing_perf_a11y.js`
> 驱动无头浏览器对全站 38 个产物页逐页实测（见 §6）。

## 0. 事实速查（守卫核对入口）

| 事实 | 值 |
| --- | --- |
| 暗色主题变量数 | 23 |
| 亮色覆盖变量数 | 20 |
| 组件类总数 | 231 |
| 媒体查询种数 | 6 |
| 关键帧 | `sp-float` |
| 外部 `url()` 引用 | 0 |

## 1. 设计原则（五条，按优先级）

1. **离线自足**。零外部资源：不引 web font、不引 CDN，样式表里一个 `url()` 都没有（图标全部内联 SVG）。断网打开，外观与功能不变。
2. **一套变量，明暗双主题**。暗色是默认（`:root` + `color-scheme: dark light`），亮色只在 `prefers-color-scheme: light` 媒体块里覆盖同一批变量。**新颜色必须进 §2 变量表**，不许在规则里裸写十六进制色值——`--on-accent` 就是教训：白字配暗色锈橙实测只有 3.08:1，WCAG AA 要 4.5:1，改成近黑纸色后 6.14:1。
3. **系统字体栈**。没有字体文件往返；`--mono` 统一用于 eyebrow、字段标签、proof 锚点、版本号等等等宽场景。
4. **移动优先断点**：1100px 收网格列数 → 860px 双栏改单栏 → 620px 紧凑间距（见 §4）。
5. **可访问性是判据，不是装饰**。对比度 ≥4.5:1、每页唯一 h1、标题不跳级、图片有 alt、链接/按钮有可访问名——全部实测，不靠读代码（见 §6）。

## 2. 色板（CSS 变量）

暗色列为默认值；亮色列为 `prefers-color-scheme: light` 里的覆盖值，`同左` = 亮色不覆盖。

### 2.1 文字与底色

| 变量 | 暗色（默认） | 亮色 | 用途 |
| --- | --- | --- | --- |
| `--ink` | `#e8eaf0` | `#16181d` | 主文字：标题、强调正文 |
| `--ink-soft` | `#a6abb8` | `#55595f` | 次级文字：描述、列表、卡片正文 |
| `--ink-faint` | `#82879c` | `#676b71` | 三级文字：页脚、面包屑、proof 锚点、字段标签 |
| `--paper` | `#0f1115` | `#ffffff` | 页面底色 |
| `--paper-alt` | `#161a21` | `#f7f5f2` | 卡片 / 交替节底色 |
| `--line` | `#272c35` | `#e4e0da` | 分隔线与边框 |
| `--on-accent` | `#0f1115` | `#ffffff` | accent 填充上的文字色：主按钮、步骤号、进度点 |

### 2.2 品牌强调色

| 变量 | 暗色（默认） | 亮色 | 用途 |
| --- | --- | --- | --- |
| `--accent` | `#e8703f` | `#b4471f` | 品牌锈橙：主按钮底、高亮边框、当前态 |
| `--accent-strong` | `#f2814f` | `#963a19` | 强强调：链接、hover 态、问号标题 |
| `--accent-soft` | `#251a13` | `#fbf1ec` | 强调浅底：徽章、步骤号底、glass 高光 |

### 2.3 氛围层（hero 背景、辉光、玻璃、scrim）

| 变量 | 暗色（默认） | 亮色 | 用途 |
| --- | --- | --- | --- |
| `--hero-bg-1` | `#0b0d13` | `#fdf8f4` | hero 背景层 1（外圈） |
| `--hero-bg-2` | `#0f1115` | `#ffffff` | hero 背景层 2（内圈） |
| `--glow-warm` | `rgba(232, 112, 63, 0.20)` | `rgba(180, 71, 31, 0.12)` | 暖色辉光（主按钮 shadow、hero 光斑） |
| `--glow-cool` | `rgba(96, 128, 255, 0.16)` | `rgba(96, 128, 255, 0.10)` | 冷色辉光 |
| `--glow-teal` | `rgba(64, 224, 208, 0.10)` | `rgba(64, 224, 208, 0.08)` | teal 辉光 |
| `--grid-line` | `rgba(232, 112, 63, 0.07)` | `rgba(180, 71, 31, 0.06)` | hero 背景网格线 |
| `--glass-bg` | `rgba(22, 26, 33, 0.72)` | `rgba(255, 255, 255, 0.82)` | 玻璃面板底（band-glass、control 栏） |
| `--glass-border` | `rgba(232, 112, 63, 0.22)` | `rgba(180, 71, 31, 0.25)` | 玻璃面板边 |
| `--img-scrim` | `linear-gradient(180deg, rgba(15, 17, 21, 0.42) 0%, rgba(15, 17, 21, 0.72) 58%, var(--paper) 100%)` | 同结构、白色分量（渐隐到亮色 `--paper`） | 图片底部渐隐挡 |
| `--photo-scrim` | `linear-gradient(180deg, rgba(11, 13, 19, 0.18) 0%, rgba(11, 13, 19, 0.38) 52%, rgba(11, 13, 19, 0.84) 100%)` | 同结构、暖白分量 | 首页 / 城市页照片 scrim（照片必须可见） |

### 2.4 尺度与字体（两主题相同，亮色不覆盖）

| 变量 | 值 | 用途 |
| --- | --- | --- |
| `--radius` | `12px` | 全局圆角（卡片、按钮、徽章） |
| `--maxw` | `1080px` | `.wrap` 内容最大宽度 |
| `--mono` | `ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace` | 等宽场景：eyebrow、标签、proof、版本号 |

### 2.5 亮色主题覆盖清单（20 个）

`--ink`、`--ink-soft`、`--ink-faint`、`--paper`、`--paper-alt`、`--line`、`--accent`、`--accent-strong`、`--accent-soft`、`--on-accent`、`--hero-bg-1`、`--hero-bg-2`、`--glow-warm`、`--glow-cool`、`--glow-teal`、`--grid-line`、`--glass-bg`、`--glass-border`、`--img-scrim`、`--photo-scrim`

（--radius、--maxw、--mono 两主题同值，不在覆盖清单里。）

## 3. 字体排印

- 正文字体走系统栈（各平台原生无衬线），零网络往返；等宽场景一律 `--mono`。
- 大标题用 `clamp()` 流体缩放（hero h1 / hero-sub / chapter-sub），不写死 px。
- 正文字号集中在 14–15.5px，标签与元信息 11.5–13px——小字号只允许配 `--ink-soft` 或更深，配 `--ink-faint` 时对比度仍由 §6 的守卫兜底。

## 4. 布局与断点

- 内容容器 `.wrap`（max-width `--maxw`，左右 padding）；节 `.block` 与交替节 `.block.alt`（`--paper-alt` 底）承载全部正文页。
- 媒体查询共 6 种：`prefers-color-scheme: light`、`prefers-reduced-motion: reduce`、`max-width: 1100px`、`max-width: 860px`、`max-width: 620px`、`max-width: 640px`。
- 1100px：首页 / 城市页网格收列；860px：所有双栏（演示双栏、验收网格、安全条目）改单栏；620px：hero 内边距与字号收紧。
- 演示页播放器的进度条与按钮在 860px 下纵向堆叠（`.demo-bar` 允许换行）。
- 640px：`/self-host/` 的「真实需要什么」条目（`.sh-item`）由两栏改单栏，收入卡片网格收到一列。

## 5. 组件类清单（231 个，19 组）

类名即样式表里的真实选择器；新增类必须同批加进本清单，否则 `tool/verify_landing_design.js` 以「文档漏账」判红。

### 5.1 骨架与布局

`wrap`、`hero`、`slim`、`block`、`alt`、`band`、`band-glass`、`band-inner`、`band-line`、`band-scrim`、`site-head`、`site-foot`、`body`、`strong`、`note`、`mono`

### 5.2 导航

`nav`、`brand-mark`、`lang-switch`、`lang-switch-label`、`lang-current`、`lang-note`、`skip`、`sr-only`

### 5.3 按钮

`btn`、`btn-primary`、`btn-ghost`、`btn-disabled`、`btn-dl`、`btn-dice`

### 5.4 行动区

`actions`、`fin-actions`

### 5.5 首页 hero

`hero-bg`、`hero-grid`、`hero-stack`、`hero-phone`、`hero-art`、`hero-link`、`hero-sub`、`hero-note`、`lede`、`eyebrow`、`lk-cap`、`lk-line`、`lk-line-hot`、`lk-node-a`、`lk-node-h`、`lk-strong`、`ph-bar`、`ph-body`、`ph-screen`

### 5.6 特性与 bento

`bento`、`bento-card`、`bento-line`、`bento-warm`、`feature`、`feature-detail`、`feature-head`、`feature-icon`、`entry-card`、`entry-desc`、`entry-go`、`entry-grid`、`entry-name`、`value-main`、`value-note`、`value-tag`、`trait`、`trust`

### 5.7 八步演示页（/demo/）

`demo-banner`、`demo-bar`、`demo-body`、`demo-col`、`demo-col-body`、`demo-col-label`、`demo-cols`、`demo-control`、`demo-door`、`demo-dot`、`demo-dots`、`demo-flow`、`demo-happened`、`demo-intent`、`demo-note`、`demo-progress`、`demo-step`、`demo-step-head`、`demo-step-no`、`demo-text`、`demo-video`、`demo-video-frame`、`demo-video-lede`、`demo-video-meta`、`check-a`、`check-grid`、`check-item`、`check-q`

### 5.8 怎么运作（/explain 门）

`explain`、`explain-cta`、`explain-lede`、`step`、`step-body`、`step-no`、`steps`、`steps-block`、`story-tag`

### 5.9 安全机制页（/security/）

`sec-group`、`sec-group-title`、`sec-item`、`sec-item-body`、`sec-item-title`、`sec-items`、`sec-proof`、`sec-proof-note`

### 5.10 审计与状态展示

`audit`、`audit-bad`、`audit-hint`、`audit-label`、`audit-line`、`audit-lines`、`audit-note`、`status-col`、`status-cols`、`status-list`、`ok-head`、`ok-list`、`scroll-hint`、`wip-head`、`wip-list`、`disclaimer`、`dice-note`、`points`、`name-input`、`hook`

### 5.11 文档 / FAQ / 更新日志

`doc`、`doc-body`、`doc-entry`、`kb-toc`、`toc`、`toc-label`、`faq-body`、`faq-item`、`log-body`、`log-item`、`log-ver`、`cl-pages`、`cl-page-link`、`is-disabled`、`cl-page-counter`、`md-table`、`breadcrumb`

### 5.12 下载页（/download/）

`dl-actions`、`dl-btn-main`、`dl-btn-sub`、`dl-cmd`、`dl-fact`、`dl-facts`、`dl-version`、`dl-channels`、`dl-channel`、`dl-channel-status`、`dl-channel-live`、`dl-channel-pending`、`dl-channel-warn`

### 5.13 城市页与章回

`city-blurb`、`city-body`、`city-card`、`city-country`、`city-grid`、`city-hero`、`city-media`、`city-name`、`chapter`、`chapter-cities`、`chapter-finale`、`chapter-head`、`chapter-no`、`chapter-sub`、`chapter-undo`

### 5.14 世界观、精灵与彩蛋

`egg`、`egg-hint`、`sprite-alert`、`sprite-egg`、`sprite-hatched`、`sprite-svg`、`sp-brow`、`sp-crack`、`sp-eye`、`sp-mouth`、`sp-orb`、`sp-shell`、`sp-shine`、`sp-tail`、`awaken`、`awaken-panel`、`reel`、`reel-card`、`reel-line`

### 5.15 对话气泡

`bubble`、`bubble-avatar`、`bubble-body`、`bubble-in`、`bubble-out`、`bubble-sig`、`bubble-who`、`bubbles`

### 5.16 Agent 卡片

`agent-grid`、`agent-id`、`agent-note`、`agent-quote`

### 5.17 状态挂钩（JS 加/摘的类）

`is-active`、`is-done`、`is-hatched`、`is-on`、`is-open`、`is-undone`、`js`、`has-media`

### 5.18 开发者页

`dev-card`、`dev-desc`、`dev-go`、`dev-grid`、`dev-name`

### 5.19 自托管页（/self-host/）

`sh-need`、`sh-item`、`sh-not`、`sh-table`、`sh-support`、`sh-card`、`sh-pending`、`sh-disc`

★ 这一组承载「收入来源披露」：`.sh-card` 是三条变现入口的卡片，**只有两态** —— 要么里面是
`<a rel="sponsored">`（链接已开通），要么是 btn-disabled 样式的灰片 + `.sh-pending` 说明（未开通）。
不存在第三种形态；`tool/verify_landing.js` 正是按这个二态判红（「既非链接又非禁用」= 假按钮）。

## 6. 动效与可访问性（判据在隔壁脚本）

- 全站唯一关键帧：`sp-float`（世界页精灵悬浮）；`prefers-reduced-motion: reduce` 下动画全部关闭（两个媒体块都写了）。
- 可访问性 / 性能判据不在本文件钉，由 `tool/verify_landing_perf_a11y.js` 实测：每页唯一 h1、标题不跳级（h1→h3 即红）、图片全有 alt、链接/按钮全有可访问名、lang 非空、HTML 体积预算（普通页 ≤150KB，changelog 双语页 ≤1MB 且有注释说明的例外）、请求数 ≤8、§2 全部文字/底色配对（含 `--paper-alt` 卡片底与 `--on-accent` 按钮底）对比度 ≥4.5:1。

## 7. 修改纪律

1. 加颜色 → 先进 §2 变量表（两主题各一行），再在规则里 `var()` 引用；禁止裸十六进制。
2. 加组件类 → 同批加进 §5 对应组；守卫按「集合精确相等」核对，漏一个即红。
3. 加断点 → §4 的 5 种清单同步更新。
4. 任何 `style.css` 改动 → 重跑 `node landing/build.js` + `node tool/verify_landing_perf_a11y.js` + `node tool/verify_landing_design.js`；Node 回归汇总（`run_all_verify_node.js`）会替你把后两个跑掉。
