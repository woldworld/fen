'use strict';

const crypto = require('crypto');
const { decode, encode } = require('./base58');

// RFC 8410 / RFC 8032: a 32-byte raw Ed25519 public key is not usable on its own —
// Node's crypto layer wants a DER SubjectPublicKeyInfo. This is the fixed 12-byte
// prefix that turns the two into each other.
const SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');
const RAW_KEY_BYTES = 32;
const SIG_BYTES = 64;

/**
 * Wrap 32 raw key bytes into a Node KeyObject.
 * @param {Buffer|Uint8Array} raw
 * @returns {crypto.KeyObject|null}
 */
function keyFromRaw(raw) {
  const bytes = Buffer.isBuffer(raw) ? raw : Buffer.from(raw);
  if (bytes.length !== RAW_KEY_BYTES) return null;
  try {
    return crypto.createPublicKey({
      key: Buffer.concat([SPKI_PREFIX, bytes]),
      format: 'der',
      type: 'spki',
    });
  } catch (_) {
    return null; // fail closed
  }
}

/**
 * Decode a base58 identity key and wrap it. `null` on anything unexpected.
 * @param {string} b58
 * @returns {crypto.KeyObject|null}
 */
function keyFromBase58(b58) {
  const raw = decode(b58);
  if (!raw || raw.length !== RAW_KEY_BYTES) return null;
  return keyFromRaw(raw);
}

/**
 * The inverse of {@link keyFromRaw}: pull the 32 raw bytes back out of a KeyObject.
 * Useful when producing a DID from a freshly generated key.
 * @param {crypto.KeyObject} publicKey
 * @returns {Buffer}
 */
function rawFromKey(publicKey) {
  const der = publicKey.export({ type: 'spki', format: 'der' });
  return der.subarray(der.length - RAW_KEY_BYTES);
}

/**
 * base58 of the raw bytes of a KeyObject — i.e. the identity string of a public key.
 * @param {crypto.KeyObject} publicKey
 * @returns {string}
 */
function base58OfKey(publicKey) {
  return encode(rawFromKey(publicKey));
}

/**
 * Verify a detached Ed25519 signature over UTF-8 text.
 * @param {string} publicKeyB58
 * @param {string} text
 * @param {string} sigBase64
 * @returns {boolean} false on any malformed input (never throws)
 */
function verifyText(publicKeyB58, text, sigBase64) {
  try {
    const key = keyFromBase58(String(publicKeyB58 || ''));
    if (!key) return false;
    const sig = Buffer.from(String(sigBase64 || ''), 'base64');
    if (sig.length !== SIG_BYTES) return false;
    return crypto.verify(null, Buffer.from(String(text), 'utf8'), key, sig);
  } catch (_) {
    return false;
  }
}

/**
 * Sign UTF-8 text with an Ed25519 private key (or a raw 32-byte seed).
 * @param {crypto.KeyObject|Buffer|Uint8Array} privateKey
 * @param {string} text
 * @returns {string} base64 signature
 */
function signText(privateKey, text) {
  return crypto.sign(null, Buffer.from(String(text), 'utf8'), privateKey).toString('base64');
}

module.exports = {
  SPKI_PREFIX,
  RAW_KEY_BYTES,
  SIG_BYTES,
  keyFromRaw,
  keyFromBase58,
  rawFromKey,
  base58OfKey,
  verifyText,
  signText,
};
