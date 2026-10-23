'use strict';

const { keyFromBase58, verifyText } = require('./ed25519');
const log = require('./log');

// ============================================================================
// M10 ⑤ Verifiable contribution ledger — signed contribution records.
//
// This merges with §16: a contribution's leaf hash goes into the **same**
// Merkle tree as every other public record, so one monitor covers both.
//
// ── The §9.1 line, expressed as structure rather than as a promise ───────────
// The five user benefits must never become transferable / redeemable /
// profit-linked (that would make them a security). That is enforced by three
// physical facts, not by documentation:
//   1. no record field means "who currently holds this" or "what it is worth";
//   2. the score is **derived by tallying records**, never stored as a balance
//      (a writable balance table inevitably grows a transfer method);
//   3. there is no transfer/redeem/payout function anywhere in the protocol.
// — so `verify` below has no branch that could ever authorise a transfer.
// ============================================================================

/** Contribution kinds. Mirrors `ContributionKind` in the Dart client. */
const KINDS = ['founding', 'invite', 'circle', 'host', 'plugin', 'skill'];

/** Points per single record. The weight is part of the signed payload, so retuning
 *  this table later cannot retroactively rewrite already-signed history. */
const WEIGHTS = { founding: 100, skill: 20, plugin: 15, host: 5, circle: 3, invite: 2 };

/** Relationship-type contributions (the beneficiary must be the one to attest them). */
const REQUIRES_COUNTERPARTY = ['invite', 'host'];

const MAX_NOTE_CHARS = 140;
const MAX_REF_CHARS = 200;

/** Per-subject, per-kind cumulative caps. ★ The core anti-farming device: without
 *  it, "invite 1000 people" would let anyone inflate the score without bound.
 *  With it, farming structurally does not grow the number. */
const CAPS = { founding: 100, invite: 200, circle: 60, host: 100, plugin: 150, skill: 400 };

/** Signing payload: every field including `note`. Must match the Dart `canonical()`. */
function canonical(r) {
  return JSON.stringify({
    alg: 'ed25519',
    kind: 'contribution',
    ctype: String(r.ctype || ''),
    subject_pub: String(r.subject_pub || ''),
    attestor_pub: String(r.attestor_pub || ''),
    ref: String(r.ref || ''),
    weight: Number(r.weight || 0),
    at: Number(r.at || 0),
    note: String(r.note || ''),
  });
}

/** Public leaf bytes: public fields only, **deliberately excluding `note`**
 *  (free text can carry personal information into a log everyone can download). */
function logBytes(r) {
  return Buffer.from(JSON.stringify({
    kind: 'contribution',
    ctype: String(r.ctype || ''),
    subject_pub: String(r.subject_pub || ''),
    attestor_pub: String(r.attestor_pub || ''),
    ref: String(r.ref || ''),
    weight: Number(r.weight || 0),
    at: Number(r.at || 0),
  }), 'utf8');
}

/** The §16 leaf hash of a contribution record. */
function leafHashOf(r) {
  return log.leafHashOf(logBytes(r));
}

/**
 * Idempotency key. `founding` keys on the subject alone (one per lifetime);
 * everything else keys on (kind, subject, referenced object).
 *
 * ⚠️ The timestamp is **deliberately excluded** — including it would let a
 *    duplicate contribution be re-signed at a different time and counted twice.
 */
function keyOf(ctype, subjectPub, ref) {
  return ctype === 'founding'
    ? `founding|${subjectPub}`
    : `${ctype}|${subjectPub}|${ref}`;
}

function sigValid(r) {
  return verifyText(r && r.attestor_pub, canonical(r), r && r.sig);
}

/**
 * Full validation, in the same order and with the same codes as the Dart ledger:
 * cheap checks first, cryptography last. Fail closed.
 * @returns {{ok:boolean, code:string}}
 */
function verify(r) {
  if (!r || typeof r !== 'object') return { ok: false, code: 'missing_fields' };
  const ctype = String(r.ctype || '');
  const subject = String(r.subject_pub || '');
  const attestor = String(r.attestor_pub || '');
  const ref = String(r.ref || '');
  const sig = String(r.sig || '');
  if (!ctype || !subject || !attestor || !sig) {
    return { ok: false, code: 'missing_fields' };
  }
  if (!keyFromBase58(subject) || !keyFromBase58(attestor)) {
    return { ok: false, code: 'bad_pubkey' };
  }
  if (!KINDS.includes(ctype)) return { ok: false, code: 'bad_kind' };
  if (ctype !== 'founding' && (!ref || ref.length > MAX_REF_CHARS)) {
    return { ok: false, code: 'bad_ref' };
  }
  // ★ A relationship-type contribution cannot self-report — checked BEFORE the
  //   signature, so a self-attested "valid signature" is still rejected.
  if (REQUIRES_COUNTERPARTY.includes(ctype) && attestor === subject) {
    return { ok: false, code: 'self_attestation' };
  }
  if (Number(r.weight) !== WEIGHTS[ctype]) return { ok: false, code: 'bad_weight' };
  if (!(Number(r.at) > 0)) return { ok: false, code: 'bad_window' };
  if (String(r.note || '').length > MAX_NOTE_CHARS) {
    return { ok: false, code: 'note_too_long' };
  }
  if (!sigValid(r)) return { ok: false, code: 'bad_signature' };
  return { ok: true, code: 'ok' };
}

module.exports = {
  KINDS,
  WEIGHTS,
  REQUIRES_COUNTERPARTY,
  MAX_NOTE_CHARS,
  MAX_REF_CHARS,
  CAPS,
  canonical,
  logBytes,
  leafHashOf,
  keyOf,
  sigValid,
  verify,
};
