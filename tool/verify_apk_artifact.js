#!/usr/bin/env node
'use strict';

// ============================================================================
// 出包产物守卫 —— 「APK 里装的到底是不是这次的代码」
//
// 为什么要有这一关（0.106.0 实战踩出来的两个坑，都是"构建 rc=0 却在骗人"）：
//
//   坑 A ★ 陈旧原生库被打进包（AGP 误判 UP-TO-DATE）
//     `flutter build apk` 明明重编了 Dart（`intermediates/flutter/<flavor>Release/jniLibs/
//     <abi>/libapp.so` 的 mtime 是新的、内容含新代码），但紧随其后的 AGP
//     `merge…NativeLibs` / `strip…DebugSymbols` **被判 UP-TO-DATE** 而没重跑，
//     最终 `package…Release` 拿着 **几天前的 stripped libapp.so** 打包。
//     ⇒ 表象极具欺骗性：**APK 的 versionName 是新的**（清单是新生成的）、
//       **体积和上一版逐字节相同**、`apksigner verify` 一样通过、aapt 一切正常，
//       但 **Dart 代码是旧的**。只认版本号 / 体积 = 必被骗（家规 R16 早已记「体积完全不可信」）。
//
//   坑 B ★ llvm-strip 撞 Windows 文件锁（静默失败）
//     `llvm-strip.exe: Permission denied` 只往日志里写一行，构建照样 rc=0 / `√ Built`，
//     结果对应 `.so` **带着调试符号进包**（0.106.0 实测：arm64 libpdfrx.so
//     347,480 B → 2,942,392 B，白胖 2.59 MB）。体积涨了却没人知道。
//
// 本脚本只用**产物内禀证据**判定，不读构建日志、不信体积、不信版本号：
//   ① 新鲜度：APK 的 `lib/<abi>/libapp.so` 必须含**源码里真实存在的字符串常量**
//      （从 `lib/core/*.dart` 的 `static const String _slot… = '…'` 现扫现取，
//        不需要人工维护清单；旧代码的包必然 MISS ⇒ 立刻翻红）。
//   ② 版本：APK 的 `AndroidManifest.xml` 必须含 pubspec 的 version（UTF-16LE）。
//   ③ 已 strip：APK 内**每一个** `.so` 的 ELF 节表都不得出现 `.symtab` / `.debug_*`
//      （直接证据；libpdfium.so / libdatastore_shared_counter.so 本就没有调试节 ⇒ 零误报）。
//   ④ 形态：目标 ABI 存在 + 体积 ≤ 50 MB（ADR-001 只发 store 分包）。
//   ⑤ 正控（判据不是恒真）：把 sentinel 字节抹掉 ⇒ ① 必红；
//      拿 `merged_native_libs`（未 strip）里的 `.so` ⇒ ③ 必红。
//   ⑥ ★ 跨版本：新包的 `libapp.so` 指纹必须 **≠ 上一已发布包**的指纹。
//      治的是「新瓶装旧酒」：pubspec bump 了、`flutter build apk` 也 rc=0、
//      AndroidManifest 里 versionName 确实是新版 —— 但 Dart 快照被 UP-TO-DATE
//      复用成了上一版的，**只有版本号变了**。
//      ★ ① 的探针抓不住这一种：探针取自 `_slot…` 常量，新旧两版都有 ⇒ 恒 HIT。
//      （0.116.0 实证：libapp.so 与已发布 0.115.0 逐字节相同，体积只差 4 字节。）
//
// 用法：
//   node tool/verify_apk_artifact.js [apk路径] [--flavor store]
//   不给路径时自动取 `build/app/outputs/flutter-apk/` 下最新的
//   `app-<abi>-<flavor>-release.apk`（优先 arm64-v8a）。
//
// ⚠️ 依赖构建产物：无产物时明确 SKIP（exit 2），而不是假装通过。
//    已登记进 `run_all_verify_node.js` 的 OPTIONAL ——
//    有产物 ⇒ 正常跑（11 PASS）；无产物 ⇒ 整条回归记 **SKIP** 而非 FAIL
//    （否则干净克隆会让 node 关变红）。**每次出包后也单独跑一次**（收口配方里的一步）。
// ============================================================================

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const ROOT = path.join(__dirname, '..');

let pass = 0, fail = 0, skip = 0;
function ck(ok, label) {
  if (ok) { pass++; console.log('  PASS  ' + label); }
  else { fail++; console.log('  FAIL  ' + label); }
}

// ---------------------------------------------------------------- 极简 zip 读取
// 只做够用的：EOCD → central directory → 按需 inflate 单个条目。零依赖。
function readZip(abs) {
  const buf = fs.readFileSync(abs);
  // 找 EOCD（PK\x05\x06），从尾部 64KB 内倒着找
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
    const crc = buf.readUInt32LE(p + 16);
    const compSize = buf.readUInt32LE(p + 20);
    const size = buf.readUInt32LE(p + 24);
    const nameLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const cmtLen = buf.readUInt16LE(p + 32);
    const localOff = buf.readUInt32LE(p + 42);
    const name = buf.toString('utf8', p + 46, p + 46 + nameLen);
    entries[name] = { method, crc, compSize, size, localOff };
    p += 46 + nameLen + extraLen + cmtLen;
  }
  const api = {
    names: () => Object.keys(entries),
    info: (n) => entries[n],
    raw: (n) => {
      const e = entries[n];
      if (!e) return null;
      const lh = e.localOff;
      if (buf.readUInt32LE(lh) !== 0x04034b50) throw new Error('bad LFH for ' + n);
      const nameLen = buf.readUInt16LE(lh + 26);
      const extraLen = buf.readUInt16LE(lh + 28);
      const start = lh + 30 + nameLen + extraLen;
      const data = buf.subarray(start, start + e.compSize);
      return e.method === 0 ? Buffer.from(data) : zlib.inflateRawSync(data);
    },
  };
  return api;
}

// ---------------------------------------------------- ELF：有没有调试/符号节
function elfDebugSections(data) {
  if (data.length < 64 || data[0] !== 0x7f || data[1] !== 0x45 || data[2] !== 0x4c || data[3] !== 0x46) return null;
  const cls = data[4];                       // 1=ELF32 2=ELF64
  const le = data[5] === 1;
  const shoff = cls === 2
    ? (le ? data.readBigUInt64LE(0x28) : data.readBigUInt64BE(0x28))
    : BigInt(le ? data.readUInt32LE(0x20) : data.readUInt32BE(0x20));
  const shentsize = le ? data.readUInt16LE(0x3A) : data.readUInt16BE(0x3A);
  const shnum = le ? data.readUInt16LE(0x3C) : data.readUInt16BE(0x3C);
  const shstrndx = le ? data.readUInt16LE(0x3E) : data.readUInt16BE(0x3E);
  if (shoff === 0n || shnum === 0) return [];
  const hoff = Number(shoff) + shstrndx * shentsize;
  let strOff, strSize;
  if (cls === 2) {
    strOff = Number(le ? data.readBigUInt64LE(hoff + 24) : data.readBigUInt64BE(hoff + 24));
    strSize = Number(le ? data.readBigUInt64LE(hoff + 32) : data.readBigUInt64BE(hoff + 32));
  } else {
    strOff = le ? data.readUInt32LE(hoff + 16) : data.readUInt32BE(hoff + 16);
    strSize = le ? data.readUInt32LE(hoff + 20) : data.readUInt32BE(hoff + 20);
  }
  const strtab = data.subarray(strOff, strOff + strSize);
  const bad = [];
  for (let i = 0; i < shnum; i++) {
    const o = Number(shoff) + i * shentsize;
    const nmoff = le ? data.readUInt32LE(o) : data.readUInt32BE(o);
    if (nmoff === 0 || nmoff >= strtab.length) continue;
    const end = strtab.indexOf(0, nmoff);
    const nm = strtab.toString('ascii', nmoff, end < 0 ? strtab.length : end);
    if (nm === '.symtab' || nm.startsWith('.debug_')) bad.push(nm);
  }
  return bad;
}

function sha256(b) { return require('crypto').createHash('sha256').update(b).digest('hex'); }

// ---------------------------------------------------------------------- 入口
const argv = process.argv.slice(2);
let flavor = 'store';
const fi = argv.indexOf('--flavor');
if (fi >= 0) { flavor = argv[fi + 1]; argv.splice(fi, 2); }

const apkDir = path.join(ROOT, 'build', 'app', 'outputs', 'flutter-apk');
let apkPath = argv[0];
if (!apkPath) {
  if (!fs.existsSync(apkDir)) { console.log('SKIP  未发现构建产物目录 ' + apkDir); process.exit(2); }
  const want = new RegExp('^app-(arm64-v8a|armeabi-v7a|x86_64)-' + flavor + '-release\\.apk$');
  const cands = fs.readdirSync(apkDir).filter((f) => want.test(f)).map((f) => path.join(apkDir, f));
  // 优先 arm64-v8a（ADR-001 对外只发这一支），其余按 mtime 新→旧
  const rank = (p) => (path.basename(p).includes('arm64-v8a') ? 0 : 1);
  cands.sort((a, b) => rank(a) - rank(b) || fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  apkPath = cands[0];
}
if (!apkPath || !fs.existsSync(apkPath)) {
  console.log('SKIP  未发现 APK（先跑 flutter build apk --release --flavor ' + flavor + '）');
  process.exit(2);
}
const apkName = path.basename(apkPath);
console.log('目标 APK: ' + apkName + '  (' + fs.statSync(apkPath).size + ' B)');
const apk = readZip(apkPath);

// -------------------------------------------------- ① 新鲜度：源码常量必须进包
console.log('--- ① 新鲜度：libapp.so 必须含当前源码里的字符串常量 ---');
const srcDir = path.join(ROOT, 'lib', 'core');
const sentinels = new Set();
for (const f of fs.readdirSync(srcDir).filter((f) => f.endsWith('.dart'))) {
  const src = fs.readFileSync(path.join(srcDir, f), 'utf8');
  const re = /static\s+const\s+String\s+_?slot\w*\s*=\s*'([^']+)'/g;
  let m;
  while ((m = re.exec(src)) !== null) sentinels.add(m[1]);
}
// 兜底：源码扫描不到时退回两个稳定 ASCII 锚点；两者都取不到 ⇒ 判失败，绝不让判据空转。
const SENTINEL_FALLBACK = ['career:job', 'identity:basic'];
ck(sentinels.size > 0, '从 lib/core/*.dart 现扫到 ' + sentinels.size + ' 个 slot 字符串常量（探针来源）');
const probeList = sentinels.size > 0 ? [...sentinels] : SENTINEL_FALLBACK;
ck(probeList.length > 0, '★ 探针集非空（扫描不到时退回硬锚点，判据绝不放空）');

const soEntries = apk.names().filter((n) => /^lib\/[^/]+\/libapp\.so$/.test(n));
ck(soEntries.length > 0, 'APK 内含 lib/<abi>/libapp.so（实际 ' + soEntries.length + ' 个 ABI）');

function hasLiteral(buf, s) {
  return buf.includes(Buffer.from(s, 'utf8')) || buf.includes(Buffer.from(s, 'utf16le'));
}

let freshOk = true;
for (const n of soEntries) {
  const d = apk.raw(n);
  const c = sha256(d);
  const hit = probeList.filter((s) => hasLiteral(d, s));
  console.log('    ' + n + '  sha256=' + c.slice(0, 16) + '  size=' + d.length);
  for (const s of probeList) {
    const ok = hasLiteral(d, s);
    console.log('      ' + (ok ? 'HIT ' : 'MISS') + '  ' + JSON.stringify(s) +
      '  (utf8=' + d.includes(Buffer.from(s, 'utf8')) + ', utf16le=' + d.includes(Buffer.from(s, 'utf16le')) + ')');
    if (!ok) freshOk = false;
  }
}
ck(freshOk, '★ 每个 libapp.so 都含全部源码常量 ⇒ 装的确实是本次代码（旧包必然 MISS）');

// -------------------------------------------------- ② 版本名与 pubspec 一致
console.log('--- ② AndroidManifest versionName == pubspec version ---');
const pub = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
const mv = pub.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+(\d+)/m);
const versionName = mv ? mv[1] : null;
const mf = apk.raw('AndroidManifest.xml');
ck(!!mf, 'APK 内含 AndroidManifest.xml');
if (mf && versionName) {
  const u16 = mf.includes(Buffer.from(versionName, 'utf16le'));
  const u8 = mf.includes(Buffer.from(versionName, 'utf8'));
  ck(u16 || u8, '★ 清单含 pubspec 版本 ' + versionName + '（utf16le=' + u16 + ', utf8=' + u8 + '）');
} else {
  fail++; console.log('  FAIL  无法取到 pubspec 版本或清单');
}

// -------------------------------------------------- ③ 每个 .so 都必须已 strip
console.log('--- ③ APK 内所有 .so 都必须已 strip（无 .symtab/.debug_*） ---');
const allSo = apk.names().filter((n) => /^lib\/[^/]+\/.*\.so$/.test(n));
let stripOk = true;
for (const n of allSo) {
  const d = apk.raw(n);
  const bad = elfDebugSections(d);
  if (bad === null) { ck(false, n + ' 不是合法 ELF'); stripOk = false; continue; }
  const ok = bad.length === 0;
  if (!ok) stripOk = false;
  console.log('    ' + (ok ? 'ok  ' : '★未strip★') + '  ' + n + '  ' + d.length + ' B' +
    (ok ? '' : '  带调试节: ' + bad.join(',')));
}
ck(stripOk, '★ 无任何 .so 携带调试符号（llvm-strip Permission denied 会被这一条抓住）');

// -------------------------------------------------- ④ 形态：ABI + 体积红线
console.log('--- ④ 形态：目标 ABI + 体积 ≤ 50 MB（ADR-001） ---');
const ABI = apkName.match(/^app-(.+?)-(?:store|sideload)-release\.apk$/);
ck(!!ABI, 'APK 名含 ABI 段（' + (ABI ? ABI[1] : '?') + '）');
const sizeMB = fs.statSync(apkPath).size / 1024 / 1024;
ck(sizeMB <= 50, '体积 ' + sizeMB.toFixed(2) + ' MB ≤ 50 MB');

// -------------------------------------------------- ⑤ 正控：判据不是恒真
console.log('--- ⑤ 正控：判据对缺陷敏感 ---');
if (soEntries.length > 0) {
  const d = apk.raw(soEntries[0]);
  const s = probeList[0];
  if (s) {
    // 造一个"旧包"：把 sentinel 字节整体替换掉
    const mutated = Buffer.from(d);
    const needle = Buffer.from(s, 'utf8');
    let idx = mutated.indexOf(needle);
    if (idx >= 0) {
      for (let k = 0; k < needle.length; k++) mutated[idx + k] = 0x00;
    }
    ck(!hasLiteral(mutated, s), '正控：抹掉 ' + JSON.stringify(s) + ' 后探针必 MISS（判据非恒真）');
  }
}
// 用 merged（未 strip）的原生库证明 ③ 的判据能看出调试节
const mergedRoot = path.join(ROOT, 'build', 'app', 'intermediates', 'merged_native_libs');
function walkSo(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walkSo(p, out);
    else if (e.name.endsWith('.so')) out.push(p);
  }
  return out;
}
const mergedSo = walkSo(mergedRoot);
const flagged = mergedSo.filter((p) => {
  const b = elfDebugSections(fs.readFileSync(p));
  return Array.isArray(b) && b.length > 0;
});
if (mergedSo.length === 0) {
  skip++; console.log('  SKIP  无 merged_native_libs 可比（正控 ③ 略过）');
} else {
  ck(flagged.length > 0,
    '正控：未 strip 的 merged 原生库里有 ' + flagged.length + '/' + mergedSo.length +
    ' 个被 ③ 的判据识别出调试节（说明 ③ 不是恒真）');
}

// ------------------------------- ⑥ 跨版本：新快照必须 ≠ 已发布快照
// 理由见文件头 ⑥。判据用**产物内禀证据**（libapp.so 的 sha256），不看体积、不看版本号。
console.log('--- ⑥ 跨版本：新快照必须 ≠ 已发布快照（防 UP-TO-DATE 复用旧 AOT） ---');
const crypto = require('crypto');
const PUBLISHED = path.join(ROOT, 'landing', 'download', 'app-store-arm64-v8a-release.apk');
const SIGNING = path.join(ROOT, 'landing', 'download', 'signing.json');
const curVersion = mv ? mv[1] + '+' + mv[2] : '';
let pubVersion = '';
try {
  if (fs.existsSync(SIGNING)) pubVersion = JSON.parse(fs.readFileSync(SIGNING, 'utf8')).version || '';
} catch (_) {
  pubVersion = '';
}
const soNameOf = (z) => z.names().find((n) => /^lib\/arm64-v8a\/libapp\.so$/.test(n)) || null;
const curSoName = soNameOf(apk);
if (!fs.existsSync(PUBLISHED)) {
  skip++;
  console.log('  SKIP  没有已发布包可比（landing/download 缺 arm64 store 包）⇒ 无读数，不记绿');
} else if (path.resolve(PUBLISHED) === path.resolve(apkPath)) {
  skip++;
  console.log('  SKIP  目标就是已发布包本身（还没出新包）⇒ 无可比');
} else if (!curSoName) {
  fail++;
  console.log('  FAIL  当前包里找不到 lib/arm64-v8a/libapp.so');
} else if (pubVersion && curVersion && pubVersion === curVersion) {
  skip++;
  console.log('  SKIP  同一版本号重编（' + curVersion + '）⇒ 快照相同是预期');
} else {
  const prevZip = readZip(PUBLISHED);
  const prevSoName = soNameOf(prevZip);
  if (!prevSoName) {
    skip++;
    console.log('  SKIP  已发布包里没有 libapp.so（形态不同，无可比）');
  } else {
    const h = (b) => crypto.createHash('sha256').update(b).digest('hex');
    const curHash = h(apk.raw(curSoName));
    const prevHash = h(prevZip.raw(prevSoName));
    console.log('      当前 ' + curHash.slice(0, 20) + '…  ' + apk.raw(curSoName).length + ' B');
    console.log('      已发布(' + (pubVersion || '?') + ') ' + prevHash.slice(0, 20) + '…  ' + prevZip.raw(prevSoName).length + ' B');
    ck(curHash !== prevHash,
      '★ 新包 libapp.so 指纹 ≠ 已发布包 ' + (pubVersion || '?') + '（相同 ⇒ Dart 快照没重编，只有版本号变了）');
  }
}

console.log('');
console.log('=========== APK 产物校验：' + pass + ' PASS / ' + fail + ' FAIL / ' + skip + ' SKIP ===========');
process.exit(fail === 0 ? 0 : 1);
