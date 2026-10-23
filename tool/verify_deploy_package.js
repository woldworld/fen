#!/usr/bin/env node
'use strict';

// ============================================================================
// 部署包「半接线」守卫 —— 一键部署必须真的把官网上线。
//
// 为什么要有这一关（0.105.x 实证的缺口）：
//   `1-一键部署.cmd` → install-server.ps1 会把包里的 `site\` 复制到
//   `C:\dahuang-site`，但 `3-开启HTTPS.cmd` → setup-caddy.ps1 生成的
//   Caddyfile **只反代了 3000/3100，没有 file_server** ⇒ 走"一键"这条路，
//   官网这份文件被搬到了服务器上却**没有任何人把它托管出去**。
//   症状：API 全通、`/health` 200、一切自检全绿，**唯独官网打不开** ——
//   最典型的一类"能力已实现 ≠ 使用者用得上"缺陷，而且**此前没有任何守卫盯着**。
//
// 本脚本查的是**结构与同源**，不查运行结果（真跑 Caddy 需要域名/证书，不适合当回归）：
//   ① install-server.ps1 把 site\ 复制到站点目录（源侧）；
//   ② setup-caddy.ps1 **两种模式**生成的 Caddyfile 都配齐
//      `root * <站点目录>` → `try_files {path} /index.html` → `file_server`（托管侧）；
//   ③ 单域名模式的兜底 `handle { … }` 不再把 / 直转 Hub（旧缺陷形态）；
//   ④ 站点目录**三处同源**（install 的 $siteDst == setup 的 $SiteDir 默认值 == Caddyfile.example 的 root）
//      —— 任何一处改了字面量而别处没跟，这里立刻翻红；
//   ⑤ make-package.ps1 真把 landing/dist 打进 site\；
//   ⑥ 正控：抹掉一处 file_server 后，判据必须翻红（证明判据不是恒真）。
//
// 运行：node tool/verify_deploy_package.js
// ============================================================================

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const read = (rel) => fs.readFileSync(path.join(ROOT, rel), 'utf8');

let pass = 0;
let fail = 0;
function ck(ok, label) {
  if (ok) {
    pass++;
    console.log('  PASS  ' + label);
  } else {
    fail++;
    console.log('  FAIL  ' + label);
  }
}

const installSrc = read('lib/hub/deploy/install-server.ps1');
const setupSrc = read('lib/hub/deploy/setup-caddy.ps1');
const exSrc = read('lib/hub/deploy/Caddyfile.example');
const mkSrc = read('lib/hub/deploy/make-package.ps1');

// ---------------------------------------------------------------- ① 源侧：搬文件
console.log('--- ① 一键部署把 site\\ 复制到站点目录（源侧） ---');

ck(/\$siteSrc\s*=\s*Join-Path\s+\$HubDir\s+'site'/.test(installSrc),
  'install-server.ps1 的站点源 = $HubDir\\site（包里的 site\\）');

const mDst = installSrc.match(/\$siteDst\s*=\s*'([^']+)'/);
const siteDst = mDst ? mDst[1] : null;
ck(!!siteDst, 'install-server.ps1 声明了 $siteDst 站点目录' + (siteDst ? '（' + siteDst + '）' : ''));

ck(/\$siteSrc[\s\S]{0,120}?Copy-Item[\s\S]{0,160}?\$siteDst/.test(installSrc),
  '★ install-server.ps1 真的把 site\\ 复制到 $siteDst（不是只声明了变量）');

// ------------------------------------------------------ ② 托管侧：两种模式都托管
console.log('--- ② setup-caddy.ps1 两种模式都托管官网（托管侧） ---');

// 同一个「root → try_files → file_server」三连，且顺序一致、窗口很短。
// 用工厂函数生成（不共享 lastIndex），避免 /g 正则在 match/replace 之间互相污染。
const wiredRe = () => /root \* \$SiteDir[\s\S]{0,60}?try_files \{path\} \/index\.html[\s\S]{0,40}?file_server/g;
const wired = setupSrc.match(wiredRe()) || [];
ck(wired.length === 2,
  '★ setup-caddy.ps1 两种模式都配齐 「root * $SiteDir → try_files {path} /index.html → file_server」（实际 ' +
    wired.length + ' 处；默认双子域 1 + 单域名 1 = 2）');

const mSiteDir = setupSrc.match(/\[string\]\$SiteDir\s*=\s*'([^']+)'/);
ck(!!mSiteDir, 'setup-caddy.ps1 以参数 $SiteDir 指定站点目录（可覆盖，默认值有据）');
const siteDirDefault = mSiteDir ? mSiteDir[1] : null;

// 旧缺陷形态：单域名模式的兜底 handle 直转 Hub ⇒ 官网无人托管。
ck(!/handle\s*\{\s*reverse_proxy 127\.0\.0\.1:\$HubPort\s*\}/.test(setupSrc),
  '★ 单域名模式的兜底 handle 不再直转 Hub（旧缺陷：所有路径进 Hub、官网打不开）');

// 反代只走显式路径：Hub 4 处（单域名 3 + 双子域 1）、World 2 处（单域名 1 + 双子域 1）。
const hubProxy = (setupSrc.match(/reverse_proxy 127\.0\.0\.1:\$HubPort/g) || []).length;
const worldProxy = (setupSrc.match(/reverse_proxy 127\.0\.0\.1:\$WorldPort/g) || []).length;
ck(hubProxy === 4, 'Hub 反代只挂在显式路径上（$HubPort 反代 4 处 = 单域名 /api/·/health·/a2a/ + 双子域 hub.）实际 ' + hubProxy);
ck(worldProxy === 2, 'World 反代只挂 /world/ 前缀（$WorldPort 反代 2 处 = 单域名 handle_path + 双子域 world.）实际 ' + worldProxy);

// ------------------------------------------------- ③ Caddyfile.example 同款
console.log('--- ③ Caddyfile.example 也是「官网 + API + 房间」三合一 ---');

const exWired = exSrc.match(/root \* (\S+)[\s\S]{0,60}?try_files \{path\} \/index\.html[\s\S]{0,40}?file_server/);
ck(!!exWired, 'Caddyfile.example 含 root → try_files → file_server（手工路线也托管官网）');
const exRoot = exWired ? exWired[1] : null;
ck(/handle \/api\/\*/.test(exSrc) && /handle_path \/world\/\*/.test(exSrc),
  'Caddyfile.example 把 /api/ 与 /world/ 分流到服务（静态站不吞掉 API）');

// --------------------------------------------------- ④ 站点目录三处同源
console.log('--- ④ 站点目录三处同源（改一处漏一处即红） ---');

ck(!!siteDst && !!siteDirDefault && !!exRoot,
  '三处站点目录都能取到：install $siteDst=' + siteDst + ' / setup $SiteDir=' + siteDirDefault + ' / example root=' + exRoot);
ck(siteDst === siteDirDefault && siteDirDefault === exRoot,
  '★ install-server.ps1 的 $siteDst == setup-caddy.ps1 的 $SiteDir 默认值 == Caddyfile.example 的 root（同一份字面量）');

// ------------------------------------------------------- ⑤ 打包侧：site\ 进包
console.log('--- ⑤ 一键部署包必须带上 site\\ ---');

ck(/landing\\dist/.test(mkSrc), 'make-package.ps1 从 landing\\dist 取官网静态文件');
ck(/'site'/.test(mkSrc) && /siteDst/.test(mkSrc), 'make-package.ps1 把官网放进部署包的 site\\ 目录');
ck(/Copy-Item[\s\S]{0,120}?landingDist[\s\S]{0,160}?\$siteDst/.test(mkSrc),
  '★ make-package.ps1 真的把 landing\\dist 复制到 site\\（不是只声明了路径）');

// ---------------------------------------------------------------- ⑥ 正控
console.log('--- ⑥ 正控：判据不是恒真 ---');

// 正控 A：只拆掉**第一处三连**里的 file_server ⇒ 计数 2 → 1。
//   ★ 不能用朴素 setupSrc.replace('file_server', …)：文件里那句注释
//     （「…而不是悄悄配一个指向空目录的 file_server…」）也含这个词，
//     朴素替换会先命中注释、两处三连原样保留 ⇒ 出现"删了却还是 2"的假失败。
//     正控连写测试的人一起抓 —— 这一版的第一稿就是这样被它抓出来的。
let firstOnly = true;
const oneLess = setupSrc.replace(wiredRe(), (m) => {
  if (firstOnly) {
    firstOnly = false;
    return m.replace('file_server', '');
  }
  return m;
});
ck((oneLess.match(wiredRe()) || []).length === 1,
  '正控：只拆一处 file_server 后三连计数 2 → 1（判据对"少配一处"敏感）');

// 正控 B：两处三连的 file_server 全拆 ⇒ 计数归 0。
const noneWired = setupSrc.replace(wiredRe(), (m) => m.replace('file_server', ''));
ck((noneWired.match(wiredRe()) || []).length === 0,
  '正控：两处都拆掉后三连计数归 0（判据对"完全不管官网"敏感）');

const stripped2 = setupSrc.replace(/root \* \$SiteDir/g, 'root * C:\\other-site');
ck((stripped2.match(wiredRe()) || []).length === 0,
  '正控：站点根挪走后三连计数归 0（判据对"指错目录"敏感）');

const badSameSource = setupSrc.replace(/\[string\]\$SiteDir\s*=\s*'([^']+)'/, "[string]$SiteDir   = 'C:\\elsewhere'");
const mBad = badSameSource.match(/\[string\]\$SiteDir\s*=\s*'([^']+)'/);
ck(!mBad || mBad[1] !== exRoot,
  '正控：把 setup 的站点目录改成别处后，三处同源判据会翻红（判据对"字面量漂移"敏感）');

// ---------------------------------------------------------------- 报告
console.log('');
// ------------------------------------ ④ 包内可运行性：相对 require 必须闭合
// ★ 2026-10-21 实证（本组存在的原因）：make-package.ps1 的服务端文件清单是**硬编码数组**，
//   本轮新增的 admission.js 没被列进去 ⇒ 包里没有它，而 hub.js 顶层就 require('./admission')
//   ⇒ 部署包解压后 hub **一启动就 MODULE_NOT_FOUND**。而包校验当时 19 条全绿 ——
//   因为它只认旧清单，"文件少了"它根本不可能知道。
//   ⇒ 判据不能靠清单，必须**从代码里反查**：凡相对 require，目标必须在包内。
//   （与 R34「判据查错对象」同族：查的是"清单里写了什么"，不是"代码要什么"。）
console.log('--- ④ 包内可运行性：相对 require 必须闭合（硬清单一定会漏新模块） ---');

const STAGE = path.join(ROOT, 'lib', 'dist', '\u5927\u8352\u670d\u52a1\u5668\u4e00\u952e\u90e8\u7f72\u5305');
ck(fs.existsSync(STAGE), '展开目录在盘：lib/dist/\u5927\u8352\u670d\u52a1\u5668\u4e00\u952e\u90e8\u7f72\u5305');
if (!fs.existsSync(STAGE)) {
  console.log('  (展开目录不在，本组只能记一条 FAIL —— 先跑 make-package.ps1)');
} else {
  const relReq = (src) => [...src.matchAll(/require\(\s*['"](\.[^'"]+)['"]\s*\)/g)].map((m) => m[1]);

  /** 返回给定源码里**解析不到**的相对依赖（相对 fileAbs 所在目录）。 */
  function missingDeps(fileAbs, srcText) {
    const out = [];
    for (const rel of relReq(srcText)) {
      const want = path.resolve(path.dirname(fileAbs), rel.endsWith('.js') ? rel : rel + '.js');
      if (!fs.existsSync(want)) out.push(rel);
    }
    return out;
  }

  // 正控：合成一条引用不存在模块的语句，解析器必须把它报出来（否则本组是恒真）。
  const synth = missingDeps(path.join(STAGE, 'hub.js'), "const _x = require('./__definitely_missing__');");
  ck(synth.length === 1 && synth[0] === './__definitely_missing__',
    '正控：解析器能报出 ./__definitely_missing__（判据非恒真）');

  const closure = [];
  for (const entry of ['hub.js', 'world.js', 'seed-rooms.js', 'keygen.js']) {
    const p = path.join(STAGE, entry);
    if (!fs.existsSync(p)) { closure.push(entry + '（入口自缺）'); continue; }
    for (const rel of missingDeps(p, fs.readFileSync(p, 'utf8'))) closure.push(entry + ' -> ' + rel);
  }
  ck(closure.length === 0,
    '★ 包内 hub.js / world.js / seed-rooms.js / keygen.js 的相对 require 全部可解析（缺：' +
      (closure.join('; ') || '无') + '）');

  ck(fs.existsSync(path.join(STAGE, 'admission.js')),
    '★ 准入判定内核 admission.js 在包内（hub.js 顶层 require 它，缺了服务起不来）');
  ck(fs.existsSync(path.join(STAGE, 'keygen.js')),
    '★ 签发工具 keygen.js 在包内（官方站切成 key 模式后，运维只能靠它签 Key）');
  ck(/HUB_REGISTRATION/.test(fs.readFileSync(path.join(STAGE, 'deploy', 'install-server.ps1'), 'utf8')),
    '★ 包内 install-server.ps1 带 HUB_REGISTRATION 开关（不是仓库源码独有）');

  // ★ 包内启动器必须能**透传参数**：官方站开闸的唯一受支持入口就是
  //   `1-一键部署.cmd -Registration key`。少了 %* 或少了自提权的 -ArgumentList，
  //   非管理员双击就会静默退回 open —— "以为开了，其实敞着"，而包校验全绿。
  //   启动器由 make-package.ps1 的 here-string 生成（deploy/ 下那份是产物），
  //   所以这里查**包内产物**，源头查 verify_hub_admission.js 的 K1/K2。
  const launcherPath = path.join(STAGE, '1-\u4e00\u952e\u90e8\u7f72.cmd');
  const launcher = fs.existsSync(launcherPath) ? fs.readFileSync(launcherPath, 'utf8') : '';
  ck(launcher.includes('-ArgumentList') && /-DataDir "C:\\DahuangData" %\*/.test(launcher),
    '★ 包内 1-一键部署.cmd 透传参数（否则官方站没有受支持的开闸入口）');
  ck(!/[^\x00-\x7F]/.test(launcher),
    '包内启动器仍是纯 ASCII（批处理跨代码页不乱码）');
}

console.log('================ 部署包半接线校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
process.exit(fail === 0 ? 0 : 1);
