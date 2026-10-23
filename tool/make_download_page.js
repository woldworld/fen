'use strict';
/**
 * ADR-001 packaging step: stage the real, signed, store-flavour arm64 APK into
 * landing/download/ and write the machine-generated signing metadata beside it.
 *
 * Nothing about the hash, the byte count or the version is typed by hand -
 * they are all derived from the file itself. landing/build.js re-computes every
 * number at build time and throws if this script's metadata ever disagrees.
 *
 *   node tool/make_download_page.js
 */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.join(__dirname, '..');
const OUT = path.join(REPO, 'landing', 'download');
const APK_DIR = path.join(REPO, 'build', 'app', 'outputs', 'apk', 'store', 'release');
const KEY_PROPS = path.join(REPO, 'android', 'key.properties');
const PUBSPEC = path.join(REPO, 'pubspec.yaml');
const MAX_BYTES = 50 * 1024 * 1024;

function fail(msg) {
  console.error('FAIL: ' + msg);
  process.exit(1);
}

// ---- 1. pick the arm64 split (never the sideload flavour, never the fat APK) --
if (!fs.existsSync(APK_DIR)) fail('no build output: ' + APK_DIR + '  (run: flutter build apk --release --flavor store --split-per-abi)');
const apks = fs.readdirSync(APK_DIR).filter((f) => /^app-store-arm64-v8a-release\.apk$/.test(f));
if (!apks.length) {
  const all = fs.readdirSync(APK_DIR).filter((f) => f.endsWith('.apk'));
  fail('no arm64 store APK in ' + APK_DIR + '\n  found: ' + (all.join(', ') || '(none)'));
}
const srcAbs = path.join(APK_DIR, apks[0]);
const size = fs.statSync(srcAbs).size;
console.log('source : ' + apks[0]);
console.log('size   : ' + size + ' bytes (' + (size / 1048576).toFixed(1) + ' MB)');
if (size > MAX_BYTES) fail('over the ADR-001 ceiling of ' + MAX_BYTES + ' bytes');

// ---- 2. signature + certificate fingerprint (apksigner is the only oracle) ---
function findApksigner() {
  const root = path.join(process.env.LOCALAPPDATA || '', 'Android', 'Sdk', 'build-tools');
  if (!fs.existsSync(root)) return null;
  const dirs = fs.readdirSync(root).sort().reverse();
  for (const d of dirs) {
    const p = path.join(root, d, 'apksigner.bat');
    if (fs.existsSync(p)) return p;
  }
  return null;
}
const signer = findApksigner();
if (!signer) fail('apksigner not found under %LOCALAPPDATA%\\Android\\Sdk\\build-tools\\*');
console.log('tool   : ' + signer);

const prevJava = process.env.JAVA_HOME;
// A .bat cannot be spawned directly by execFileSync on Windows - it must go
// through cmd.exe. Without this the call fails with an empty error message.
const JAVA_DIR = 'E:\\Android\\Android Studio\\jbr';
const runSigner = (args) =>
  execFileSync(process.env.ComSpec || 'cmd.exe', ['/c', signer, ...args], {
    encoding: 'utf8',
    env: { ...process.env, JAVA_HOME: JAVA_DIR },
  });
let certOut = '';
try {
  certOut = runSigner(['verify', '--print-certs', '-v', srcAbs]);
} catch (e) {
  fail('apksigner verify failed:\n' + (e.stdout || '') + (e.stderr || ''));
}

if (!/Verifies/.test(certOut)) fail('apksigner did not report "Verifies"');
const v2 = /Verified using v2 scheme \(APK Signature Scheme v2\): true/.test(certOut);
const v1 = /Verified using v1 scheme \(JAR signing\): true/.test(certOut);
const v3 = /Verified using v3 scheme \(APK Signature Scheme v3\): true/.test(certOut);
if (!v2) fail('not signed with v2 (red line R9: v2 only)');
if (v1) fail('package is also JAR-signed (v1) - R9 says v2 only');
if (v3) fail('package carries v3 in addition to v2 - R9 says v2 only');

// apksigner prints "V2 Signer: certificate SHA-256 digest: <hex>". It must be
// the *certificate* line specifically - there is also a public-key SHA-256.
const fp = certOut.match(/certificate SHA-256 digest:\s*([0-9a-fA-F:]+)/);
if (!fp) fail('could not read a SHA-256 certificate fingerprint from apksigner output');
const certSha256 = fp[1].replace(/:/g, '').toLowerCase();
if (!/^[0-9a-f]{64}$/.test(certSha256)) fail('certificate fingerprint is not 64 hex chars: ' + certSha256);
console.log('cert   : ' + certSha256);
console.log('dn     : ' + ((certOut.match(/V2 Signer: certificate DN:\s*(.+)/) || [])[1] || '(unknown)').trim());

// alias: kept out of the fingerprint parsing loop, read straight from key.properties
let alias = 'wold';
if (fs.existsSync(KEY_PROPS)) {
  const m = fs.readFileSync(KEY_PROPS, 'utf8').match(/^\s*keyAlias\s*=\s*(.+?)\s*$/m);
  if (m) alias = m[1];
}
const version = (fs.readFileSync(PUBSPEC, 'utf8').match(/^version:\s*(\S+)\s*$/m) || [])[1];
if (!version) fail('cannot read version from pubspec.yaml');

// ---- 3. stage it -------------------------------------------------------------
fs.mkdirSync(OUT, { recursive: true });
// Clear old/different APKs so a stale file can never be picked up by build.js.
for (const f of fs.readdirSync(OUT)) {
  if (/\.apk$/.test(f)) {
    if (fs.existsSync(path.join(APK_DIR, f)) && f === apks[0]) continue;
    const away = '_prev_' + f + '_' + Date.now();
    fs.renameSync(path.join(OUT, f), path.join(OUT, away));
    console.log('  moved aside: ' + f + ' -> ' + away);
  }
}
fs.copyFileSync(srcAbs, path.join(OUT, apks[0]));
fs.writeFileSync(
  path.join(OUT, 'signing.json'),
  JSON.stringify({ apkFile: apks[0], version, bytes: size, certSha256, scheme: 'v2', alias, generatedBy: 'tool/make_download_page.js' }, null, 2) + '\n',
  'utf8'
);
console.log('staged : landing/download/' + apks[0]);
console.log('OK: ADR-001 download asset staged. Now run: node landing/build.js');
