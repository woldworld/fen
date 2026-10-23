'use strict';

const { verifyText } = require('./ed25519');

// ============================================================================
// M9 skill registry — deterministic signed payloads for listings and revocations.
//
// ⚠️ Same landmine as every other canonical in this package: Dart's `jsonEncode`
//    and JS's `JSON.stringify` both produce whitespace-free JSON, but **key order
//    comes from insertion order**. Differ in order and "an author's legitimately
//    signed listing is rejected by the relay". Do not reorder these object literals.
// ============================================================================

/** Signing payload for a skill listing. `capabilities` is sorted so set order can't leak into bytes. */
function canonical(l) {
  const caps = Array.isArray(l.capabilities) ? [...l.capabilities].map(String).sort() : [];
  return JSON.stringify({
    alg: 'ed25519',
    skill_id: String(l.skill_id || ''),
    version: String(l.version || ''),
    name: String(l.name || ''),
    description: String(l.description || ''),
    author_id: String(l.author_id || ''),
    author_pub: String(l.author_pub || ''),
    capabilities: caps,
    risk: String(l.risk || 'low'),
    content_hash: String(l.content_hash || ''),
    price_cents: Number(l.price_cents || 0),
    currency: String(l.currency || 'CNY'),
    published_at: Number(l.published_at || 0),
  });
}

/** Verify a listing signature. Fail closed. */
function sigValid(l) {
  return verifyText(l && l.author_pub, canonical(l), l && l.sig);
}

/** Signing payload for a skill revocation. */
function revocationCanonical(r) {
  return JSON.stringify({
    alg: 'ed25519',
    kind: 'skill_revocation',
    skill_id: String(r.skill_id || ''),
    version: String(r.version || ''),
    author_pub: String(r.author_pub || ''),
    reason: String(r.reason || ''),
    at: Number(r.at_ms || 0),
  });
}

function revocationSigValid(r) {
  return verifyText(r && r.author_pub, revocationCanonical(r), r && r.sig);
}

/** Lenient `major.minor.patch` parse — a non-numeric segment counts as 0. */
function parseVersion(v) {
  const out = [0, 0, 0];
  const parts = String(v || '').split('.');
  for (let i = 0; i < 3 && i < parts.length; i++) {
    const m = /^\d+/.exec(String(parts[i]).trim());
    out[i] = m ? parseInt(m[0], 10) : 0;
  }
  return out;
}

/** @returns {number} -1 / 0 / 1 */
function compareVersion(a, b) {
  const pa = parseVersion(a);
  const pb = parseVersion(b);
  for (let i = 0; i < 3; i++) {
    if (pa[i] !== pb[i]) return pa[i] < pb[i] ? -1 : 1;
  }
  return 0;
}

// Iron rule: a skillId never changes author, a version never changes content,
// and versions only move forward.
function publishDecision(incoming, existing) {
  if (!existing.length) return { accept: true, code: 'accepted' };
  if (existing.some((e) => e.author_pub !== incoming.author_pub)) {
    return { accept: false, code: 'author_changed' };
  }
  const sameVersion = existing.filter((e) => e.version === incoming.version);
  if (sameVersion.length) {
    const identical = sameVersion.some(
      (e) =>
        e.content_hash === incoming.content_hash &&
        Number(e.price_cents || 0) === Number(incoming.price_cents || 0)
    );
    return identical
      ? { accept: false, code: 'duplicate' }
      : { accept: false, code: 'version_conflict' };
  }
  let maxV = existing[0].version;
  for (const e of existing) if (compareVersion(e.version, maxV) > 0) maxV = e.version;
  if (compareVersion(incoming.version, maxV) <= 0) {
    return { accept: false, code: 'version_not_increased' };
  }
  return { accept: true, code: 'accepted' };
}

module.exports = {
  canonical,
  sigValid,
  revocationCanonical,
  revocationSigValid,
  parseVersion,
  compareVersion,
  publishDecision,
};
