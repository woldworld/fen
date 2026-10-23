'use strict';

const { keyFromBase58, verifyText } = require('./ed25519');

// ============================================================================
// M6 network-level reputation — signed, one-to-one endorsements.
//
// Deliberately there is **no global reputation score**: a global score is
// trivially farmable (register a pile of throwaway accounts and praise each
// other). The relay's only job is "is this endorsement real (signature valid)";
// aggregation is each observer's own local business.
//
// Why the subject is a **public key** and not the agent ID: an ID is a name the
// platform hands out — it can be re-issued and re-bound. The key is the root of
// identity. Using the ID would mean "change your ID once and shed every bad
// review" (reputation laundering).
// ============================================================================

const TIERS = ['acquaintance', 'friend', 'family'];
const MAX_NOTE_CHARS = 140;

/** Signing payload for an endorsement. */
function canonical(e) {
  return JSON.stringify({
    alg: 'ed25519',
    kind: 'endorsement',
    issuer_pub: String(e.issuer_pub || ''),
    subject_pub: String(e.subject_pub || ''),
    tier: String(e.tier || ''),
    issued_at: Number(e.issued_at || 0),
    expires_at: Number(e.expires_at || 0),
    note: String(e.note || ''),
  });
}

function sigValid(e) {
  return verifyText(e && e.issuer_pub, canonical(e), e && e.sig);
}

/** Signing payload for revoking an endorsement. */
function revocationCanonical(r) {
  return JSON.stringify({
    alg: 'ed25519',
    kind: 'endorsement_revocation',
    issuer_pub: String(r.issuer_pub || ''),
    subject_pub: String(r.subject_pub || ''),
    at: Number(r.at_ms || 0),
  });
}

function revocationSigValid(r) {
  return verifyText(r && r.issuer_pub, revocationCanonical(r), r && r.sig);
}

/**
 * The relay's endorsement admission check. Cheap checks first, crypto last, and
 * iteration order matters for the reported `code`.
 * @param {object} e
 * @param {number} [nowMs] when supplied, an expired endorsement is rejected
 * @returns {{accept:boolean, code:string}}
 */
function accept(e, nowMs) {
  const issuer = String(e.issuer_pub || '');
  const subject = String(e.subject_pub || '');
  const tier = String(e.tier || '');
  if (!issuer || !subject || !tier || !String(e.sig || '')) return { accept: false, code: 'missing_fields' };
  if (!keyFromBase58(issuer) || !keyFromBase58(subject)) {
    return { accept: false, code: 'bad_pubkey' };
  }
  // Iron rule 3: self-endorsement is void — checked BEFORE the signature, because a
  // self-signed "valid" signature must still not be believed.
  if (issuer === subject) return { accept: false, code: 'self_endorsement' };
  if (!TIERS.includes(tier)) return { accept: false, code: 'bad_tier' };
  if (String(e.note || '').length > MAX_NOTE_CHARS) return { accept: false, code: 'note_too_long' };
  const issuedAt = Number(e.issued_at || 0);
  const expiresAt = Number(e.expires_at || 0);
  if (issuedAt <= 0 || expiresAt <= issuedAt) return { accept: false, code: 'bad_window' };
  if (!sigValid(e)) return { accept: false, code: 'bad_signature' };
  if (typeof nowMs === 'number' && nowMs > expiresAt) return { accept: false, code: 'expired' };
  return { accept: true, code: 'ok' };
}

module.exports = {
  TIERS,
  MAX_NOTE_CHARS,
  canonical,
  sigValid,
  revocationCanonical,
  revocationSigValid,
  accept,
};
