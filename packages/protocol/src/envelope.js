'use strict';

const crypto = require('crypto');
const { keyFromBase58, verifyText, signText } = require('./ed25519');

// ============================================================================
// The wold/1 envelope — the single wire format for every request, over every transport.
//
// ── Interoperability warning (read this before re-implementing) ──────────────
// The signature covers `JSON.stringify(envelope without the sig field)` and the
// **key order of that JSON is the insertion order of the object**. Dart's
// `jsonEncode` and JavaScript's `JSON.stringify` both emit whitespace-free JSON
// but neither sorts keys, so two implementations that build the object in a
// different order produce different bytes — and "a legitimately signed request
// is rejected by the relay" is the failure mode. Both sides of this project
// therefore build the object in one fixed order and prove it with a cross-language
// test. See the spec's §2 warning; v2 will move to canonical (sorted) JSON.
// ============================================================================

const PROTO = 'wold/1';
const LEGACY_PROTO = 'pocketagent/1';
const ACCEPTED_PROTOS = new Set([PROTO, LEGACY_PROTO]);
const TS_WINDOW_SECONDS = 300; // ±5 min replay window

/** HMAC-SHA256, lowercase hex. The bootstrap/legacy signature form. */
function hmacHex(secret, data) {
  return crypto.createHmac('sha256', secret).update(data, 'utf8').digest('hex');
}

// Credential shapes:
//   { alg: 'ed25519', pubkey }     — public-key identity (recommended)
//   { alg: 'hmac-sha256', secret } — shared-secret identity (bootstrap)
// Legacy records carry no `alg`; infer it from whichever field is present.
function algOf(cred) {
  if (cred && cred.alg) return cred.alg;
  if (cred && cred.secret) return 'hmac-sha256';
  if (cred && cred.pubkey) return 'ed25519';
  return null;
}

/** The exact bytes a signature covers: the envelope minus `sig`, insertion order preserved. */
function canonicalize(env) {
  const unsigned = { ...env };
  delete unsigned.sig;
  return JSON.stringify(unsigned);
}

/** Infer the algorithm from the key material, for callers that omit `alg`. */
function algOfKey(key) {
  if (!key) return null;
  if (key.secret) return 'hmac-sha256'; // { secret }
  // { privateKey } | a raw KeyObject (KeyObject exposes `asymmetricKeyType`)
  if (key.privateKey || typeof key.asymmetricKeyType === 'string') return 'ed25519';
  return null;
}

// Insert `alg` directly after `proto` so a signed envelope always matches the
// documented field order, even if the caller forgot the field.
function withAlgAfterProto(env, alg) {
  const out = {};
  let placed = false;
  for (const k of Object.keys(env)) {
    out[k] = env[k];
    if (!placed && k === 'proto') {
      out.alg = alg;
      placed = true;
    }
  }
  if (!placed) out.alg = alg;
  return out;
}

/**
 * Build the signed envelope (the "construct" half of the protocol).
 *
 * The algorithm is taken from `env.alg` when present, otherwise inferred from the
 * key — and written into the result, because an `ed25519` envelope that omits
 * `alg` would be verified as `hmac-sha256` by a conforming receiver and rejected.
 *
 * @param {object} env fields to sign; any existing `sig` is ignored
 * @param {crypto.KeyObject|{privateKey:crypto.KeyObject}|{secret:string}} key
 * @returns {object} a copy of `env` with `alg` resolved and `sig` filled in
 */
function sign(env, key) {
  const alg = env.alg || algOfKey(key) || 'ed25519';
  const out = env.alg ? { ...env } : withAlgAfterProto(env, alg);
  delete out.sig;
  if (alg === 'ed25519') {
    out.sig = signText((key && key.privateKey) || key, canonicalize(out));
  } else {
    out.sig = hmacHex(key && key.secret, canonicalize(out));
  }
  return out;
}

/** Sign and base64url-encode into a value suitable for the `X-Agent-Sig` header. */
function signHeader(env, key) {
  return Buffer.from(JSON.stringify(sign(env, key))).toString('base64url');
}

/** Parse an `X-Agent-Sig` header value. Returns `null` on malformed input. */
function parseHeader(header) {
  try {
    return JSON.parse(Buffer.from(String(header || ''), 'base64url').toString('utf8'));
  } catch (_) {
    return null;
  }
}

/**
 * Verify a signed envelope. **Fail closed** — every unexpected shape returns false,
 * nothing throws, and nothing is ever "accepted best effort".
 * @param {object} env
 * @param {{alg?:string,secret?:string,pubkey?:string}} cred the credential the receiver holds for `env.from`
 * @returns {boolean}
 */
function verify(env, cred) {
  try {
    if (!env || typeof env !== 'object' || !env.sig || !cred) return false;
    if (!ACCEPTED_PROTOS.has(env.proto)) return false;
    const alg = env.alg || 'hmac-sha256';
    if (alg === 'ed25519') {
      if (cred.pubkey == null) return false;
      return verifyText(cred.pubkey, canonicalize(env), env.sig);
    }
    if (!cred.secret) return false;
    return hmacHex(cred.secret, canonicalize(env)) === env.sig;
  } catch (_) {
    return false;
  }
}

/** Alias kept for readers who prefer the explicit name. */
const verifyEnvelope = verify;

/**
 * Replay window check. `ts` is Unix **seconds** (not ms).
 * @param {object} env
 * @param {{nowSeconds?:number, windowSeconds?:number}} [opts]
 * @returns {boolean}
 */
function tsFresh(env, opts) {
  const windowSeconds = (opts && opts.windowSeconds) || TS_WINDOW_SECONDS;
  const nowSeconds = (opts && opts.nowSeconds) || Math.floor(Date.now() / 1000);
  const t = Number((env && env.ts) || 0);
  return t > 0 && Math.abs(nowSeconds - t) <= windowSeconds;
}

module.exports = {
  PROTO,
  LEGACY_PROTO,
  ACCEPTED_PROTOS,
  TS_WINDOW_SECONDS,
  hmacHex,
  algOf,
  algOfKey,
  canonicalize,
  sign,
  signHeader,
  parseHeader,
  verify,
  verifyEnvelope,
  tsFresh,
};
