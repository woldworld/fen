'use strict';

// Base58 (Bitcoin alphabet) — the canonical text encoding of a 32-byte Ed25519 public key.
//
// Why base58 and not hex/base64: the alphabet drops the four glyph pairs that humans
// confuse when copying a key by hand (0/O, I/l), so an identity string survives a
// screenshot. It is the same alphabet every Bitcoin-era tool already understands.
const ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

// An encoding of more than 64 characters cannot be a 32-byte key (32 bytes is at most
// ~44 chars). The cap makes decode() fail fast on junk instead of building a huge BigInt.
const MAX_DECODE_CHARS = 64;

/**
 * Encode bytes to base58.
 * @param {Buffer|Uint8Array} buf
 * @returns {string}
 */
function encode(buf) {
  const bytes = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
  let num = 0n;
  for (const b of bytes) num = num * 256n + BigInt(b);
  let out = '';
  while (num > 0n) {
    out = ALPHABET[Number(num % 58n)] + out;
    num /= 58n;
  }
  // Every leading zero byte is one leading '1' (base58 has no other way to say "zero").
  for (let i = 0; i < bytes.length && bytes[i] === 0; i++) out = '1' + out;
  return out;
}

/**
 * Decode base58 to bytes. Returns `null` (never throws) on anything malformed —
 * callers treat a bad key as a failed verification, which is the fail-closed default.
 * @param {string} s
 * @returns {Buffer|null}
 */
function decode(s) {
  if (typeof s !== 'string' || s.length === 0 || s.length > MAX_DECODE_CHARS) return null;
  let num = 0n;
  for (const ch of s) {
    const idx = ALPHABET.indexOf(ch);
    if (idx < 0) return null;
    num = num * 58n + BigInt(idx);
  }
  const bytes = [];
  while (num > 0n) {
    bytes.unshift(Number(num % 256n));
    num /= 256n;
  }
  for (let i = 0; i < s.length && s[i] === '1'; i++) bytes.unshift(0);
  return Buffer.from(bytes);
}

module.exports = { ALPHABET, MAX_DECODE_CHARS, encode, decode };
