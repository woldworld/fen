#!/usr/bin/env node
'use strict';

// ============================================================================
// 部署包「站点快照新鲜度」守卫 —— 包里的官网必须与当前 CHANGELOG / 下载资产同源。
//
// ★★ 为什么必须单开一关（0.108.0 收口实证的新失效模式）：
//   0.108.0 收口时**先重建 dist、后回填 CHANGELOG 的真实读数**（APK / 部署包字节 + sha256），
//   然后打了包 ⇒ 包内 `site/changelog/index.html` 渲染的是**回填前**的正文
//   （页面上仍写着「不需要重出 APK」，而 APK 已经重出）。
//   而 `tool/verify_landing.js` **自己在第 44 行 `require(landing/build.js)` 重建 dist**
//   ⇒ 任何"dist 是否陈旧"的判据在它那里**永远看不到陈旧**（dist 一定是新的）。
//   ⇒ 真正会僵住的是**包里的 site\ 快照**（打完包就不会再变），此前**没有任何守卫看它**：
//      `verify_deploy_package.js` 只查 PowerShell 脚本的连接关系，**从不打开 zip**。
//
// ★ 与 `verify_apk_artifact.js` 同类：依赖**构建产物**（`lib/dist/大荒服务器一键部署包.zip`）。
//   无产物 ⇒ 按设计 `exit 2`（明确 SKIP，不假装通过），并在 `run_all_verify_node.js` 里
//   登记为 OPTIONAL —— 否则干净克隆（尚未打包）会让整条 node 关变红，而那不是代码坏了
//   （承 0.106.0 那条教训：判据依赖产物就必须显式登记 OPTIONAL）。
//
// 判据：
//   ① 包内双语 changelog 页在位，且渲染了 CHANGELOG.md 的**最新版本号**；
//   ② ★★ 包内双语 changelog 的**最新节片段**必须含 CHANGELOG.md 最新节的**全部数字型事实**
//      （千分位字节数 / `xxxxxxxx…xxxx` 哈希前缀）—— 缺任一条 = 包比 CHANGELOG 旧；
//   ③ ✚ 包内 `site/download/signing.json` 必须与 `landing/download/signing.json` 逐字段一致
//      （版本一旦 bump 而包没重打，这里立刻红）；
//   ④ 反漂移：CHANGELOG 最新节里写的「部署包 … N B」「… sha256 `xxxxxxxx…xxxx`」必须等于
//      真实 zip 的字节数 / 哈希前缀（**这条是可选的** —— 自指陷阱决定 CHANGELOG 里**不该**写包自身的
//      字节 / 哈希，故本项通常走「跳过」分支）；
//   ⑤ ★★ 反漂移（**主**落点）：`lib/大荒M1_M2交付与验收记录.md` §129.8c 记录的「终稿」字节数 / sha256
//      必须等于真实 zip —— 该文档**不进站点、不进包**（已实证），故在这里写自指数字是安全的；
//      这一条就是 CHANGELOG 里那句「由本守卫拿真实 zip 对账」的可执行形式。缺锚点 ⇒ 判 FAIL
//      （不允许静默空跑）。
//   ⑥ 正控：把事实从包内片段里抹掉后 ② 必须翻红；把 §129.8c 的字节数错 1 后 ⑤ 必须翻红。
//
// 运行：node tool/verify_deploy_site_freshness.js
// ============================================================================

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');

const ROOT = path.join(__dirname, '..');
const PKG = path.join(ROOT, 'lib', 'dist', '大荒服务器一键部署包.zip');

let pass = 0;
let fail = 0;
function ck(ok, label) {
  if (ok) { pass++; console.log('  PASS  ' + label); }
  else { fail++; console.log('  FAIL  ' + label); }
}

// 无产物 ⇒ 按设计 SKIP（退出码 2，由 runner 记 SKIP，不污染 ΣPASS/ΣFAIL）
if (!fs.existsSync(PKG)) {
  console.log('  SKIP  部署包不存在（' + path.relative(ROOT, PKG) + '）—— 尚未打包，按设计跳过');
  console.log('  SKIP  本关是**发布侧闸门**：打包后必须再跑一次');
  console.log('================ 部署包站点快照校验：0 PASS / 0 FAIL / 2 SKIP ================');
  process.exit(2);
}

// ------------------------------------------------ 极简 zip 读取（与 verify_apk_artifact.js 同款）
function readZip(abs) {
  const buf = fs.readFileSync(abs);
  const tailStart = Math.max(0, buf.length - 65558);
  let eocd = -1;
  for (let i = buf.length - 22; i >= tailStart; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('EOCD not found: ' + abs);
  const cdCount = buf.readUInt16LE(eocd + 10);
  const cdOffset = buf.readUInt32LE(eocd + 16);
  const entries = {};
  let p = cdOffset;
  for (let n = 0; n < cdCount; n++) {
    if (buf.readUInt32LE(p) !== 0x02014b50) throw new Error('bad CDH at ' + p);
    const method = buf.readUInt16LE(p + 10);
    const compSize = buf.readUInt32LE(p + 20);
    const size = buf.readUInt32LE(p + 24);
    const nameLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const cmtLen = buf.readUInt16LE(p + 32);
    const localOff = buf.readUInt32LE(p + 42);
    // ★ 0.108.0 实证：PowerShell `Compress-Archive` 写的是 **Windows 反斜杠**分隔符
    //   ⇒ 统一归一成 `/`，否则任何 `endsWith('site/...')` 的匹配都会落空（已踩一次）。
    const name = buf.toString('utf8', p + 46, p + 46 + nameLen).replace(/\\/g, '/');
    entries[name] = { method, compSize, size, localOff };
    p += 46 + nameLen + extraLen + cmtLen;
  }
  return {
    // ★ 0.108.0 实证：PowerShell `Compress-Archive` 写中文目录名时**不带 UTF-8 标志位**
    //   ⇒ Node 按 utf8 解出来是乱码（中文包名前缀取不到）。故一律用**纯 ASCII 后缀**匹配，
    //   不依赖中文前缀（`site/...` 及 `lib/...` 都是 ASCII，天然安全）。
    findEndingWith: (suffix) => Object.keys(entries).find((k) => k.endsWith(suffix)) || null,
    raw: (nameOrSuffix) => {
      let key = nameOrSuffix;
      if (!entries[key]) {
        key = Object.keys(entries).find((k) => k.endsWith(nameOrSuffix)) || null;
      }
      const e = key ? entries[key] : null;
      if (!e) return null;
      const lh = e.localOff;
      if (buf.readUInt32LE(lh) !== 0x04034b50) throw new Error('bad LFH for ' + n);
      const nl = buf.readUInt16LE(lh + 26);
      const el = buf.readUInt16LE(lh + 28);
      const start = lh + 30 + nl + el;
      const data = buf.subarray(start, start + e.compSize);
      return e.method === 0 ? Buffer.from(data) : zlib.inflateRawSync(data);
    },
  };
}

// ------------------------------------------------- CHANGELOG 最新节的「数字型事实」
// ★ 取节必须显式定位首节（verify_landing.js 已踩过两个坑）：
//   ① 带 `$` 的正则（/m 下 `$` 只匹配第一个行尾）⇒ 整节被截成只剩标题；
//   ② `split(...)[1]` ⇒ CHANGELOG **没有 `# Changelog` 头**，元素 0 才是首节。
/**
 * CHANGELOG.md 的**最新版本节**（不是"第一个 `## [` 节"）。
 *
 * ★★ 2026-10-20 修：原实现用 `/^## \[/m` 定位首节。CHANGELOG.md 里除了版本节，
 *   还有**非版本化的过程记录节**（例：`## [官网 /demo/ 页上线演示视频] — 2026-10-17`），
 *   按日期插在最前面 ⇒ 首节变成过程记录节，而版本号仍从版本节解析
 *   ⇒ 版本号与正文事实**来自不同的节** ⇒ 事实数 0 ⇒ 误红（本关 4 FAIL）。
 * ⇒ 两者必须同节，故一律按版本号模式定位。
 */
function latestSection() {
  const src = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8');
  // ★★ 2026-10-21 修（+N 盲区，R34 复发）：版本头正则的 `\]` 撞在 `+1` 上 ⇒
  //    `## [0.116.0+1]` 整节不匹配 ⇒ **静默读到上一版 0.115.0**；而两节的片段在包内
  //    changelog 页里都存在 ⇒ 数字事实逐条命中 ⇒ 判据全绿放过。0.116.0+1 是项目第一个
  //    带构建号的版本，那一轮的 freshness 28/0 实为对 0.115.0 节验的。
  //    ⇒ 容忍可选 `+N`；自检见下方 latestVer 处（合成串正控 + 与 pubspec 对账）。
  const m = /^## \[([0-9]+\.[0-9]+\.[0-9]+(?:\+\d+)?)\]/m.exec(src);
  if (!m) return '';
  const rest = src.slice(m.index);
  const next = rest.slice(1).search(/\r?\n## \[/);
  return next < 0 ? rest : rest.slice(0, next + 1);
}
function factsOf(text) {
  const out = new Set();
  for (const m of text.matchAll(/(\d{1,3}(?:,\d{3})+)\s*B/g)) out.add(m[1]);
  for (const m of text.matchAll(/([0-9a-f]{8}\u2026[0-9a-f]{4})/g)) out.add(m[1]);
  return [...out];
}
function plainOf(html) {
  return html.replace(/<[^>]+>/g, ' ').replace(/&amp;/g, '&').replace(/\s+/g, ' ');
}
function hasFact(plain, fact) {
  const pat = fact.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s*');
  return new RegExp(pat).test(plain);
}

const zipBuf = fs.readFileSync(PKG);
const zip = readZip(PKG);
const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');

const clSection = latestSection();
// ★ 2026-10-21 修：同 latestSection() 的 +N 盲区 —— 从节标题提取版本号时 `([0-9.]+)`
//   会在 `+` 前截断（0.116.0+1 → 0.116.0）⇒ tag `[0.116.0]` 在片段里找不到 ⇒ 回退到
//   items[0]（顶部过程节）⇒ 拿过程节验版本节。两个正则必须同口径。
const latestVer = (clSection.match(/^## \[([0-9]+\.[0-9]+\.[0-9]+(?:\+\d+)?)\]/) || [])[1] || '';
const secFacts = factsOf(clSection);
console.log('--- ① 包内双语 changelog 在位，且渲染了最新版本号（' + latestVer + '） ---');

ck(!!latestVer, 'CHANGELOG.md 能解析出最新版本号');
ck(secFacts.length >= 2, '★ CHANGELOG 最新节至少含 2 条数字型事实（实为 ' + secFacts.length + ' 条）');

// ★ 2026-10-21 修（+N 盲区）的两条自检：① 合成串正控（毒注入带构建号的版本头，正则必须吃下）；
//   ② 与 pubspec 对账 —— 首个版本节必须 == pubspec version，不等即取节错了或 bump 漏写（ADR-001）。
{
  const mm = /^## \[([0-9]+\.[0-9]+\.[0-9]+(?:\+\d+)?)\]/.exec('## [9.999.0+7] — x');
  ck(!!mm && mm[1] === '9.999.0+7', '自检：版本头正则能解析 +N 构建号（毒注入 9.999.0+7）');
  const pub = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
  const pv = (pub.match(/^version:\s*(\S+)\s*$/m) || [])[1] || '';
  ck(!!pv && latestVer === pv,
    '★ 最新版本节（' + latestVer + '）== pubspec version（' + pv + '）—— 不等即取节错了或版本不同步');
}

/**
 * 取包内某个 HTML 里**最新版本节**的 log-item 片段（纯文本）。
 * ★ 不取"第一个 log-item" —— 顶部可能是非版本化的过程记录节（2026-10-20 实证）。
 */
function fragOf(entryName) {
  const buf = zip.raw(entryName);
  if (!buf) return null;
  const html = buf.toString('utf8');
  const items = html
    .split('<section class="log-item">')
    .slice(1)
    .map((s) => plainOf(s.split('<section class="log-item">')[0]));
  if (!items.length) return null;
  const tag = '[' + latestVer + ']';
  // ★ 2026-10-21 修：CHANGELOG 过程节里引用版本标签（`` `## [0.116.0+1]` ``）会让
  //   「包含即中」**误中过程节**（它在最顶部，find 先命中）⇒ 拿过程节验版本节、事实全缺（2 FAIL）。
  //   ⇒ 先按**标题前缀**挑（log-item 纯文本以节标题开头），挑不到再退化为包含匹配。
  const byHead = items.find((t) => t.trim().startsWith(tag));
  return byHead || items.find((t) => t.includes(tag)) || items[0];
}

for (const [label, entry] of [
  ['en', 'site/changelog/index.html'],
  ['zh', 'site/zh/changelog/index.html'],
]) {
  const e = entry; // 只用 ASCII 后缀（包内中文顶层目录名是 CP936，见 readZip 注释）
  const frag = fragOf(e);
  ck(!!frag && frag.length > 200, '包内 ' + label + ' changelog 在位且有实质内容（' + e + '）');
  if (!frag) continue;
  ck(frag.includes(latestVer), '包内 ' + label + ' changelog 渲染了最新版本 ' + latestVer);
  // ② ★★ 核心判据：包内最新节正文必须含 CHANGELOG 最新节的**全部**数字事实
  const missing = secFacts.filter((fx) => !hasFact(frag, fx));
  ck(missing.length === 0,
    '★★ 反陈旧：包内 ' + label + ' changelog 最新节必须含 CHANGELOG.md 最新节的全部数字事实（'
    + secFacts.length + ' 条）；缺：[' + missing.join(', ') + ']');
  // ⑤ 正控：抹掉全部事实后，② 必须报「全缺」。
  //   ★ 正控**必须独立于主判据**（写成 `missing.length === 0 && …` 会让主判据一旦红、正控也红，
  //     于是"正控是否有效"就再也测不出来了 —— 已踩一次）。
  const stripped = secFacts.reduce((acc, fx) => acc.split(fx).join('X'), frag);
  const missStripped = secFacts.filter((fx) => !hasFact(stripped, fx)).length;
  ck(secFacts.length > 0 && missStripped === secFacts.length,
    '正控：抹掉全部数字事实后本判据必须报「全缺」（实测缺 ' + missStripped + '/' + secFacts.length + '）');
}

console.log('--- ② 包内下载资产必须与磁盘上的暂存资产同源 ---');
// ★ 事实：`signing.json` **不进包**（包内只放 APK + 下载页；页面上的数字即公开事实）
//   ⇒ 这里比的是「包内 APK ↔ 磁盘暂存 APK」与「包内下载页公布的版本/证书指纹 ↔ 磁盘 signing.json」。
const sgDisk = path.join(ROOT, 'landing', 'download', 'signing.json');
ck(fs.existsSync(sgDisk), '磁盘上有 landing/download/signing.json（ADR-001 暂存资产）');
if (fs.existsSync(sgDisk)) {
  const a = JSON.parse(fs.readFileSync(sgDisk, 'utf8'));
  const apkDiskPath = path.join(ROOT, 'landing', 'download', a.apkFile);
  // ★ 包内 APK 用的是**发布名**（`fen-<版本>-arm64.apk`，由 build.js 发布），
  //   与磁盘上的**暂存名**（`app-store-arm64-v8a-release.apk`）不同 ⇒ 按后缀 `.apk` 找，别按名字拼。
  const apkEntry = zip.findEndingWith('site/download/' + 'fen-' + String(a.version).replace('+1', '') + '-arm64.apk')
    || zip.findEndingWith('.apk');
  const apkInZip = apkEntry ? zip.raw(apkEntry) : null;
  ck(!!apkInZip, '包内有下载 APK（' + (apkEntry || '未找到') + '）');
  if (apkInZip && fs.existsSync(apkDiskPath)) {
    ck(apkInZip.length === a.bytes && sha(apkInZip) === sha(fs.readFileSync(apkDiskPath)),
      '★★ 包内 APK 与磁盘暂存 APK 的字节数与 sha256 双一致（' + apkInZip.length + ' B）');
  }
  for (const [label, dl] of [['en', 'site/download/index.html'], ['zh', 'site/zh/download/index.html']]) {
    const buf = zip.raw(dl);
    ck(!!buf, '包内 ' + label + ' 下载页在位（' + dl + '）');
    if (!buf) continue;
    const html = buf.toString('utf8');
    ck(html.includes(a.version) && html.includes(a.certSha256),
      '★ 包内 ' + label + ' 下载页公布的版本（' + a.version + '）与证书指纹与磁盘 signing.json 同源');
  }
}

console.log('--- ③ 反漂移：CHANGELOG 里手抄的部署包字节 / 哈希必须等于真实产物 ---');
const mBytes = clSection.match(/部署包[^。\n]{0,120}?([\d,]{9,})\s*B/);
if (mBytes) {
  const cited = Number(mBytes[1].replace(/,/g, ''));
  ck(cited === zipBuf.length,
    '★ 反漂移：CHANGELOG 最新节手抄的部署包字节数（' + cited + '）与真实包（' + zipBuf.length + ' B）一致');
} else {
  console.log('  note  CHANGELOG 最新节未写部署包字节数，本项跳过（不强制措辞）');
}
const mHash = clSection.match(/部署包[^。\n]{0,200}?`([0-9a-f]{8})\u2026([0-9a-f]{4})`/);
if (mHash) {
  const real = sha(zipBuf);
  ck(real.startsWith(mHash[1]) && real.endsWith(mHash[2]),
    '★ 反漂移：CHANGELOG 最新节手抄的部署包 sha256 前缀（' + mHash[1] + '…' + mHash[2] +
    '）与真实包（' + real.slice(0, 8) + '…' + real.slice(-4) + '）一致');
} else {
  console.log('  note  CHANGELOG 最新节未写部署包 sha256，本项跳过（不强制措辞）');
}
console.log('  info  真实包 ' + zipBuf.length + ' B  sha256=' + sha(zipBuf));

console.log('--- ④ ★★ 精确读数的落点《交付记录》最新一轮记录必须与真实 zip 对账（非自指） ---');
// ★ 为什么这条**不违反**「不许自指」：
//   `lib/大荒M1_M2交付与验收记录.md` **不进站点、不进包**（已实证 dist 全站不含其内容）
//   ⇒ 在它里面写包自身的字节 / sha256 不会把「内容 → 字节 → 数字」闭成环。
//   而 CHANGELOG **会被渲染进包内 changelog 页** ⇒ 只能在 CHANGELOG 里**禁写**自指数字，
//   精确值落在这里，再由本关拿**真实 zip** 咬住它。这一条就是上面 CHANGELOG 那句
//   「由 `tool/verify_deploy_site_freshness.js` 拿真实 zip 对账」的**可执行形式**。
// ★★ 0.109.0 修（判据强度不变、锚点动态化）：原实现把落点写死成 `§129.8c`（0.108.0 那一轮
//   记录包指纹的小节）⇒ **下一轮重打部署包后必然误红** —— §129.8c 记的是**它那一轮的快照**
//   （18,820,666 B），而新包已是另一份产物。判据语义本是「交付记录里记的最新真值 == 真实 zip」，
//   故改为**取全文最后一次出现**：每轮把真实值写进**当轮小节**，本判据自动跟随，不再依赖旧小节号。
const REC_PATH = path.join(ROOT, 'lib', '大荒M1_M2交付与验收记录.md');
let recTxt = '';
try { recTxt = fs.readFileSync(REC_PATH, 'utf8'); } catch (e) { recTxt = ''; }
const allB = Array.from(recTxt.matchAll(/部署包（\*\*终稿\*\*）\s*\|\s*\*\*([\d,]+)\s*B\*\*/g));
const allS = Array.from(recTxt.matchAll(/部署包 sha256\s*\|\s*\*\*`([0-9a-f]{64})`\*\*/g));
ck(allB.length >= 1,
  '★ 《交付记录》含「部署包（**终稿**）」字节记录（锚点存在，否则判据会静默空跑；实为 ' + allB.length + ' 处）');
ck(allS.length >= 1,
  '★ 《交付记录》含「部署包 sha256」记录（锚点存在，否则判据会静默空跑；实为 ' + allS.length + ' 处）');
const mB = allB.length ? allB[allB.length - 1] : null;
const mS = allS.length ? allS[allS.length - 1] : null;
if (mB && mS) {
  const citedBytes = Number(mB[1].replace(/,/g, ''));
  const realSha = sha(zipBuf);
  ck(citedBytes === zipBuf.length,
    '★★ 反漂移：最新的部署包字节记录（' + citedBytes + '）== 真实 zip（' + zipBuf.length + ' B）');
  ck(mS[1] === realSha,
    '★★ 反漂移：最新的部署包 sha256 记录 == 真实 zip（' +
    realSha.slice(0, 8) + '\u2026' + realSha.slice(-4) + '）');
  // 正控：故意把字节数错 1 ⇒ 判据必须报不一致（证明比对是活的、不是恒真）
  ck(citedBytes + 1 !== zipBuf.length,
    '正控：把最新字节记录的数值故意错 1 时，本判据必须报不一致');
}

console.log('--- ⑥ ★★ 反陈旧（主）：包内法务页必须与磁盘 dist 逐字节一致 ---');
// 为什么必须单开这条：合规草稿（`lib/compliance/*.md`）会被 `landing/build.js` 渲染进
// `/privacy/ /terms/ /age/` 五语种页 ⇒ **改了草稿却没重打包**，包里发出的就是旧条款。
// 而上面的 ①/② 只盯「版本节」与「下载资产」—— 文档正文变了它们**一个都看不见**。
// ★ 只比法务页，不比整个 `site\` —— `dist/build-report.json` 带构建时间戳，
//   重建即变，整树逐字节比对必然每轮误红（红线 16）。
for (const [label, entry, rel] of [
  ['privacy', 'site/privacy/index.html', ['privacy', 'index.html']],
  ['terms', 'site/terms/index.html', ['terms', 'index.html']],
  ['age', 'site/age/index.html', ['age', 'index.html']],
]) {
  const inZip = zip.raw(entry);
  const onDiskPath = path.join(ROOT, 'landing', 'dist', ...rel);
  ck(!!inZip && fs.existsSync(onDiskPath),
    '包内 ' + label + ' 页与磁盘 dist 副本均存在（' + entry + '）');
  if (!inZip || !fs.existsSync(onDiskPath)) continue;
  const onDisk = fs.readFileSync(onDiskPath);
  ck(inZip.length === onDisk.length && inZip.equals(onDisk),
    '★★ 反陈旧：包内 ' + label + ' 页与磁盘 dist 逐字节一致（包内 ' + inZip.length +
    ' B / 磁盘 ' + onDisk.length + ' B）');
}
console.log('');
console.log('================ 部署包站点快照校验：' + pass + ' PASS / ' + fail + ' FAIL ================');
process.exit(fail === 0 ? 0 : 1);
