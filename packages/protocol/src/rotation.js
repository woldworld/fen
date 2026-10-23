'use strict';

const { keyFromBase58, verifyText } = require('./ed25519');
const log = require('./log');

// ============================================================================
// Identity rotation — how an identity moves to a new device.
//
// Why this exists. A `did:wold` identity *is* its keypair. If a user recovers the
// same key onto a second phone, three things break at once:
//
//   1. "one person, one identity" stops holding — the same DID now has two live
//      bodies, and their social actions fork;
//   2. the old device keeps a working key, so a *sold* phone is a sold account;
//   3. nothing detects it — the existing defence (`same_key_both_sides`) only
//      rejects ONE key playing both parties, never TWO devices holding one key.
//
// So recovery is modelled as a **migration, not a copy**:
//
//   the user presents the old key (proving the identity) → signs a ROTATE
//   declaration naming a NEW key → the relay rebinds `agent_id → new_pub` →
//   the new key takes over and the old key is dead everywhere.
//
// Replay safety falls out of the binding check for free: once a rotation has been
// applied, replaying the very same declaration fails `not_current_key`, because
// `old_pub` is no longer what the relay has on file. There is nothing to expire.
//
// What this deliberately does NOT do: stop someone from handing their key to
// another person. That is the same act as handing over the device. It is made
// *visible* instead — every rotation is a signed, append-only, independently
// recomputable record.
// ============================================================================

/** Widened versus the 5-minute envelope window: a freshly set-up phone may have a skewed clock. */
const MAX_SKEW_MS = 15 * 60 * 1000;

/**
 * @param {object} r
 * @param {string} r.agent_id
 * @param {string} r.old_pub base58 — the key being retired
 * @param {string} r.new_pub base58 — the key taking over
 * @param {number} r.rotated_at epoch ms
 * @returns {string} the exact bytes the old key signs
 */
function canonical(r) {
  return JSON.stringify({
    alg: 'ed25519',
    kind: 'identity_rotation',
    agent_id: String(r.agent_id || ''),
    old_pub: String(r.old_pub || ''),
    new_pub: String(r.new_pub || ''),
    rotated_at: Number(r.rotated_at || 0),
  });
}

/**
 * @param {object} r must carry `sig` (base64) alongside the signed fields
 * @returns {boolean} false on any malformed input (never throws)
 */
function sigValid(r) {
  return verifyText(r && r.old_pub, canonical(r), r && r.sig);
}

/**
 * The bytes committed to the §16 Merkle tree.
 *
 * Deliberately a **different** object from `canonical`: `canonical` is what the
 * old key signs (so it carries `alg`), while these bytes are what a third-party
 * monitor recomputes from the published record (so they carry `kind` and no
 * `sig` — Ed25519 signatures are deterministic, so the signature adds nothing
 * the key + message don't already fix). Same split as `contribution.logBytes`.
 *
 * @param {object} r
 * @returns {Buffer}
 */
function logBytes(r) {
  return Buffer.from(JSON.stringify({
    kind: 'identity_rotation',
    agent_id: String(r.agent_id || ''),
    old_pub: String(r.old_pub || ''),
    new_pub: String(r.new_pub || ''),
    rotated_at: Number(r.rotated_at || 0),
  }), 'utf8');
}

/** The §16 leaf hash of a rotation record. */
function leafHashOf(r) {
  return log.leafHashOf(logBytes(r));
}

/**
 * Idempotency key — `agent_id|old_pub`, mirroring the `key_rotations` primary
 * key on both sides. One key may retire itself **once**; a second declaration
 * naming the same `old_pub` is the same event, not a new one.
 *
 * ⚠️ `rotated_at` is **deliberately excluded**, for the same reason as in
 *    `contribution.keyOf`: including it would let a repeated rotation be
 *    re-signed at a new time and enter the append-only log twice.
 */
function keyOf(agentId, oldPub) {
  return `${String(agentId || '')}|${String(oldPub || '')}`;
}

/**
 * Admission check for a rotation declaration.
 *
 * Order is deliberate (cheap checks first, crypto last) and the reported `code`
 * depends on it. `currentPub` is the key the relay currently has bound for
 * `agent_id`; pass an empty string when the agent is unknown.
 *
 * @param {object} r
 * @param {string} currentPub base58 key currently bound to `agent_id`
 * @param {number} [nowMs]
 * @returns {{accept:boolean, code:string}}
 */
function verify(r, currentPub, nowMs) {
  const agentId = String((r && r.agent_id) || '');
  const oldPub = String((r && r.old_pub) || '');
  const newPub = String((r && r.new_pub) || '');
  if (!agentId || !oldPub || !newPub || !String((r && r.sig) || '')) {
    return { accept: false, code: 'missing_fields' };
  }
  if (!keyFromBase58(oldPub) || !keyFromBase58(newPub)) {
    return { accept: false, code: 'bad_pubkey' };
  }
  // Rotating onto the same key would "succeed" while changing nothing, and would
  // be a free way to spam the append-only log. Checked before the signature.
  if (oldPub === newPub) return { accept: false, code: 'noop_rotation' };
  // The crux: only the key **currently on file** may retire itself. A superseded
  // key cannot rotate again, and an attacker cannot rotate someone else's
  // identity by naming it here.
  if (!currentPub || oldPub !== String(currentPub)) {
    return { accept: false, code: 'not_current_key' };
  }
  // Cheap checks before crypto, as everywhere else in this package: a caller that
  // got the shape wrong deserves the shape error, not "bad_signature".
  const at = Number((r && r.rotated_at) || 0);
  if (!Number.isFinite(at) || at <= 0) return { accept: false, code: 'bad_time' };
  if (!sigValid(r)) return { accept: false, code: 'bad_signature' };
  if (typeof nowMs === 'number' && Math.abs(nowMs - at) > MAX_SKEW_MS) {
    return { accept: false, code: 'stale_rotation' };
  }
  return { accept: true, code: 'ok' };
}

module.exports = { MAX_SKEW_MS, canonical, sigValid, logBytes, leafHashOf, keyOf, verify };
