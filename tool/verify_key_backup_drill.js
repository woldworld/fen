#!/usr/bin/env node
/**
 * Signing key backup - RESTORE DRILL (not an existence check).
 *
 * Why this exists: "the backup file is there" is not "the backup works".
 * A jks nobody has ever opened with the written-down password, or an APK
 * nobody has ever verified, is a file with a reassuring name. The only thing
 * that converts it into a backup is actually using it:
 *
 *   1. the password in the written instructions must actually open the keystore
 *   2. a WRONG password must be rejected (otherwise check 1 proves nothing)
 *   3. the backup jks must be byte-identical to the one the project uses
 *   4. the backup APK must verify, and match the documented SHA-256
 *   5. ★ the backup key must be able to SIGN - re-sign an APK from the backup
 *      keystore and verify the result
 *
 * Secrets are parsed from the backup instructions and android/key.properties.
 * Nothing is hardcoded and no password is ever printed; on failure the message
 * is generic so the password cannot leak through an error dump.
 *
 *   node tool/verify_key_backup_drill.js
 */

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const REPO = path.join(__dirname, '..');
const BACKUP_DIR = 'D:\\大荒AI签名密钥备份';
const PROJECT_JKS = path.join(REPO, 'android', 'wold-release.jks');
const KEY_PROPS = path.join(REPO, 'android', 'key.properties');

let pass = 0;
let fail = 0;
function check(ok, label) {
  if (ok) { pass++; console.log('  PASS  ' + label); }
  else { fail++; console.log('  FAIL  ' + label); }
}

console.log('=== 签名密钥备份 · 恢复演练 ===');

// ------------------------------------------------------------- locate -----

function findJavaBin() {
  const cands = [
    'E:\\Android\\Android Studio\\jbr\\bin',
    'C:\\Program Files\\Android\\Android Studio\\jbr\\bin',
    'C:\\Program Files\\Java\\jdk-17\\bin',
  ];
  for (const d of cands) {
    if (fs.existsSync(path.join(d, 'keytool.exe')) && fs.existsSync(path.join(d, 'java.exe'))) return d;
  }
  // last resort: JAVA_HOME
  if (process.env.JAVA_HOME) {
    const b = path.join(process.env.JAVA_HOME, 'bin');
    if (fs.existsSync(path.join(b, 'keytool.exe'))) return b;
  }
  return null;
}

function findApksigner() {
  const root = path.join(process.env.LOCALAPPDATA || '', 'Android', 'sdk', 'build-tools');
  if (!fs.existsSync(root)) return null;
  const vers = fs.readdirSync(root)
    .filter((v) => fs.existsSync(path.join(root, v, 'lib', 'apksigner.jar')))
    .sort();
  return vers.length ? path.join(root, vers[vers.length - 1], 'lib', 'apksigner.jar') : null;
}

const JAVA_BIN = findJavaBin();
const KEYTOOL = JAVA_BIN ? path.join(JAVA_BIN, 'keytool.exe') : null;
const JAVA = JAVA_BIN ? path.join(JAVA_BIN, 'java.exe') : null;
const APKSIGNER = findApksigner();

check(!!KEYTOOL, '找到 keytool' + (KEYTOOL ? '' : '（设置 JAVA_HOME 或安装 Android Studio）'));
check(!!APKSIGNER, '找到 apksigner' + (APKSIGNER ? '' : '（需 Android SDK build-tools）'));

// --------------------------------------------------------- read inputs -----

const TXT = path.join(BACKUP_DIR, '密钥口令与备份说明.txt');
check(fs.existsSync(BACKUP_DIR), '备份目录存在：' + BACKUP_DIR);
check(fs.existsSync(TXT), '备份说明存在');

if (!fs.existsSync(TXT) || !KEYTOOL || !APKSIGNER) {
  console.log('\n前置条件不足，演练中止。');
  console.log('================ 密钥备份恢复演练：' + pass + ' PASS / ' + fail + ' FAIL ================');
  process.exitCode = 1;
  return;
}

const txt = fs.readFileSync(TXT, 'utf8');
const props = fs.readFileSync(KEY_PROPS, 'utf8');

function field(src, re) {
  const m = src.match(re);
  return m ? m[1].trim() : null;
}

const alias = field(txt, /别名\(alias\)\s*[:：]\s*(\S+)/) || field(props, /keyAlias\s*=\s*(\S+)/);
const docStorePass = field(txt, /库口令\s*[:：]\s*(\S+)/);
const docKeyPass = field(txt, /密钥口令\s*[:：]\s*(\S+)/);
const docCertSha = field(txt, /证书 SHA-256\s*[:：]\s*([0-9A-Fa-f:]+)/);
const docApkSha = field(txt, /SHA-256\s*[:：]\s*([0-9a-f]{64})/);

const propStorePass = field(props, /storePassword\s*=\s*(\S+)/);
const propKeyPass = field(props, /keyPassword\s*=\s*(\S+)/);
const propAlias = field(props, /keyAlias\s*=\s*(\S+)/);

check(!!alias, '解析出别名 alias');
check(!!docStorePass && !!docKeyPass, '解析出备份说明里的口令');
check(!!docCertSha, '解析出备份说明里的证书 SHA-256');
check(!!docApkSha, '解析出备份说明里的 APK SHA-256');

console.log('--- ① 说明写下的口令 == 项目实际配置 ---');
check(docStorePass === propStorePass, '库口令：备份说明 == android/key.properties');
check(docKeyPass === propKeyPass, '密钥口令：备份说明 == android/key.properties');
check(alias === propAlias, '别名：备份说明 == android/key.properties');

// ---------------------------------------------- ② 口令真的能打开密钥库 -----

const BACKUP_JKS = path.join(BACKUP_DIR, 'wold-release.jks');
check(fs.existsSync(BACKUP_JKS), '备份 jks 存在');

function keytoolList(jks, pwd) {
  const r = spawnSync(KEYTOOL, ['-list', '-v', '-keystore', jks, '-storepass', pwd], {
    encoding: 'utf8',
    windowsHide: true,
  });
  return { ok: r.status === 0, out: (r.stdout || '') + (r.stderr || '') };
}

console.log('--- ② 口令能打开密钥库（含负向对照）---');

const good = keytoolList(BACKUP_JKS, docStorePass);
check(good.ok, '★ 用说明里写下的口令成功打开备份 jks');

// Negative control: a wrong password MUST be rejected. Without this, the
// check above could pass for the wrong reason (e.g. keytool ignoring -storepass).
const bad = keytoolList(BACKUP_JKS, docStorePass + '_WRONG_');
check(!bad.ok, '★ 负向对照：错误口令被拒绝（证明上一条不是恒真）');

// Certificate fingerprint must match what the instructions claim.
const norm = (s) => String(s).replace(/:/g, '').toUpperCase();
const mSha = good.out.match(/SHA256:\s*([0-9A-Fa-f:]+)/);
const actualCertSha = mSha ? mSha[1] : null;
check(
  !!actualCertSha && norm(actualCertSha) === norm(docCertSha),
  '证书 SHA-256 与备份说明一致（实际 ' + (actualCertSha ? actualCertSha.slice(0, 19) : '未取到') + '…）'
);
check(/CN=The Wold/.test(good.out), '证书主题含 CN=The Wold');

// ------------------------------------------- ③ 备份 jks == 项目用的 jks -----

console.log('--- ③ 备份的 jks 就是项目在用的那把 ---');

function sha256File(p) {
  return crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
}

if (fs.existsSync(PROJECT_JKS)) {
  check(
    sha256File(BACKUP_JKS) === sha256File(PROJECT_JKS),
    '备份 jks 与 android/wold-release.jks 逐字节一致（不是旧版本/另一把键）'
  );
} else {
  check(false, '项目内 jks 存在（android/wold-release.jks 缺失）');
}

// ------------------------------------------------- ④ 备份 APK 验签通过 -----

console.log('--- ④ 备份里的 APK 验签 ---');

const BACKUP_APK = path.join(BACKUP_DIR, 'app-release-已签名.apk');
check(fs.existsSync(BACKUP_APK), '备份 APK 存在');

if (fs.existsSync(BACKUP_APK)) {
  check(sha256File(BACKUP_APK) === docApkSha.toLowerCase(), 'APK SHA-256 与备份说明一致');

  const v = spawnSync(JAVA, ['-jar', APKSIGNER, 'verify', '--print-certs', BACKUP_APK], {
    encoding: 'utf8',
    windowsHide: true,
  });
  const vout = (v.stdout || '') + (v.stderr || '');
  check(v.status === 0, 'apksigner verify 通过（备份 APK 的签名有效）');
  check(/CN=The Wold/.test(vout), '签名者 = CN=The Wold（不是调试签名）');
  check(!/CN=Android Debug/.test(vout), '非 Android Debug 调试签名');
  // NOTE: apksigner 37.x prints "V2 Signer: certificate DN: ..." - the older
  // "Verified using v2 scheme ...: true" line is gone. Assert what the tool
  // actually outputs, and let the exit code carry "verification passed".
  check(/V2 Signer:/.test(vout), 'APK Signature Scheme v2 签名存在且通过（输出含 "V2 Signer:"）');
  const dSha = vout.match(/V2 Signer:\s*certificate SHA-256 digest:\s*([0-9a-f]+)/i);
  check(
    !!dSha && dSha[1].toUpperCase() === norm(docCertSha),
    'V2 签名证书摘要 == 备份说明里的证书 SHA-256（确实是同一把键签的）'
  );
}

// ---------------------------------- ⑤ ★ 真恢复：用备份密钥重新签一次 -----

console.log('--- ⑤ ★ 真恢复：用备份的密钥重新签出一个 APK ---');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'wold-key-drill-'));
const tmpJks = path.join(tmp, 'restored.jks');
const tmpIn = path.join(tmp, 'in.apk');
const tmpOut = path.join(tmp, 'resigned.apk');

// Restore step, done the way a real recovery would do it: copy the backup
// keystore out, then use it. Never touch the project's copy.
fs.copyFileSync(BACKUP_JKS, tmpJks);
check(fs.existsSync(tmpJks), '从备份复制出 jks 到临时目录（模拟换机恢复）');

let resigned = false;
if (fs.existsSync(BACKUP_APK)) {
  fs.copyFileSync(BACKUP_APK, tmpIn);
  const s = spawnSync(
    JAVA,
    ['-jar', APKSIGNER, 'sign',
      '--ks', tmpJks, '--ks-key-alias', alias,
      '--ks-pass', 'pass:' + docStorePass,
      '--key-pass', 'pass:' + docKeyPass,
      '--out', tmpOut, tmpIn],
    { encoding: 'utf8', windowsHide: true }
  );
  resigned = s.status === 0 && fs.existsSync(tmpOut);
  check(resigned, '★ 用备份密钥成功签出 APK（失败时详情不打印，避免口令外泄）');

  if (resigned) {
    const v2 = spawnSync(JAVA, ['-jar', APKSIGNER, 'verify', '--print-certs', tmpOut], {
      encoding: 'utf8',
      windowsHide: true,
    });
    const o2 = (v2.stdout || '') + (v2.stderr || '');
    check(v2.status === 0, '★ 重签后的 APK 验签通过');
    check(/CN=The Wold/.test(o2), '★ 重签后的签名者仍是 CN=The Wold');
    // NOTE: re-signing with build-tools 37.x produces a **V3.0** signature,
    // not V2 (observed). Accept either - the point is that it is not v1-only.
    check(/V[23](\.\d)? Signer:/.test(o2), '★ 重签产物带 v2/v3 签名（不是只签了 v1）');
    check(
      sha256File(tmpOut) !== sha256File(tmpIn),
      '重签产物与输入不同（确实重新签了，不是原样复制）'
    );
  }
}

// cleanup
try {
  fs.rmSync(tmp, { recursive: true, force: true });
} catch (e) { /* ignore */ }

console.log('');
console.log('================ 密钥备份恢复演练：' + pass + ' PASS / ' + fail + ' FAIL ================');
if (fail > 0) process.exitCode = 1;
