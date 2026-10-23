'use strict';

const rotation = require('./rotation');

// ============================================================================
// Identity aliases — which public keys are the same person?
//
// Why this file exists. Network reputation (M6 endorsements) is indexed by
// **public key**, not by agent id, and that is deliberate: an agent id is a
// name the platform hands out, and indexing reputation by a name would let
// anyone shed their history by renaming themselves. The key is the root.
//
// The price of that choice is paid here. A key can be *retired* by a signed
// ROTATE declaration (`rotation.js`) — the person survives, the key does not.
// Without alias resolution every endorsement that person ever received stays
// welded to the dead key, so "your history follows you" quietly becomes false
// the first time a user changes phone. Verified history is the whole point of
// the reputation layer, so silently zeroing it is worse than having none.
//
// So: given the *public* rotation records, answer "which keys belong to the
// same identity as this one?". Every uncertainty resolves to "only the key you
// asked about", because a wrong alias hands one person another person's
// history — the single most damaging failure this function could have.
//
// Note what this deliberately does NOT do: it does not decide *reputation*.
// It resolves *identity*. The caller still has to verify each endorsement; an
// alias only says "these records are about the same person".
// ============================================================================

/** Why alias resolution stopped — a stable, language-neutral code. */
const STATUS = {
  /** Chain is contiguous and every link carries a valid signature. */
  OK: 'ok',
  /** This key appears in no rotation record: it *is* its whole identity. */
  NO_CHAIN: 'no_chain',
  /** The key sits in two different identities' chains — refuse to pick one. */
  AMBIGUOUS: 'ambiguous',
  /** At least one link is not signed by the key it retires. */
  UNSIGNED: 'unsigned',
  /** Records carry no usable append order, so the links cannot be checked. */
  UNORDERED: 'unordered',
  /** Links do not join up: a rotation is missing, or records were tampered with. */
  BROKEN: 'broken',
};

/**
 * Resolve `subjectPub` to every public key of the identity that owns it.
 *
 * @param {Array<object>} records public rotation records
 *        (`{agent_id, old_pub, new_pub, rotated_at, idx, sig}`); extra fields ignored
 * @param {string} subjectPub base58 key to resolve
 * @returns {{agent_id: (string|null), keys: string[], tip: string,
 *            status: string, chain: object[]}}
 *          `keys` is every key this identity has used, de-duplicated; `tip` is
 *          the **active** key (the last link's `new_pub`), which is *not* always
 *          `keys[keys.length - 1]` — rotating back to an earlier key is legal.
 *          `status !== 'ok'` means the caller must treat `keys` as
 *          `[subjectPub]`-only: `chain` is then returned purely as evidence for
 *          why it gave up.
 */
function identityKeysOf(records, subjectPub) {
  const subject = String(subjectPub || '');
  if (!subject) {
    return { agent_id: null, keys: [], tip: '', status: STATUS.NO_CHAIN, chain: [] };
  }

  const list = (Array.isArray(records) ? records : []).filter(
    (r) => r && typeof r === 'object'
  );

  // The declared `agent_id` is itself signed (it is inside `canonical`), so
  // grouping by it is grouping by a *claimed* owner. We group **before**
  // verifying on purpose: if a forged record were filtered out first, the
  // remaining records could form a chain that merely *looks* tidy.
  const groups = new Map();
  for (const r of list) {
    const aid = String(r.agent_id || '');
    if (!aid) continue;
    if (!groups.has(aid)) groups.set(aid, []);
    groups.get(aid).push(r);
  }

  const owners = [];
  for (const [aid, chain] of groups) {
    if (chain.some((r) => r.old_pub === subject || r.new_pub === subject)) owners.push(aid);
  }
  if (owners.length === 0) {
    // The common case: this key never rotated, so it is its own identity.
    return { agent_id: null, keys: [subject], tip: subject, status: STATUS.NO_CHAIN, chain: [] };
  }
  if (owners.length > 1) {
    // One key claimed by two identities. One of them is lying (or the store is
    // inconsistent) and we cannot tell which — so we credit neither.
    return { agent_id: null, keys: [subject], tip: subject, status: STATUS.AMBIGUOUS, chain: [] };
  }

  const agentId = owners[0];
  const chain = groups.get(agentId).slice();

  // Append order (`idx`, written by the relay) is authoritative. `rotated_at`
  // is self-reported by the client and can be back-dated, so it is never used
  // for ordering — same discipline as the relay's own rotations endpoint.
  if (chain.some((r) => !Number.isFinite(Number(r.idx)))) {
    return { agent_id: agentId, keys: [subject], tip: subject, status: STATUS.UNORDERED, chain };
  }
  chain.sort((a, b) => Number(a.idx) - Number(b.idx));

  // The cryptographic gate. A retiring key signs its own retirement, and
  // nothing else can produce that signature — so a fully signed chain *is* the
  // proof that these keys belong to one person. Any bad link invalidates the
  // whole chain rather than just that link: we cannot know which side of a
  // forged link is real.
  for (const r of chain) {
    if (!rotation.sigValid(r)) {
      return { agent_id: agentId, keys: [subject], tip: subject, status: STATUS.UNSIGNED, chain };
    }
  }

  for (let i = 1; i < chain.length; i++) {
    if (String(chain[i].old_pub) !== String(chain[i - 1].new_pub)) {
      return { agent_id: agentId, keys: [subject], tip: subject, status: STATUS.BROKEN, chain };
    }
  }

  // Every key this identity has used, de-duplicated (first-seen order). A valid
  // chain cannot repeat a key, but a caller passing hand-written records is not
  // required to be valid — and rotating *back* to an earlier key is legal, so
  // this list is a SET of keys used, not a walkable path.
  const keys = [];
  const seen = new Set();
  for (const k of [String(chain[0].old_pub), ...chain.map((r) => String(r.new_pub))]) {
    if (!seen.has(k)) {
      seen.add(k);
      keys.push(k);
    }
  }
  // ⚠️ `tip` is the **active** key, and the active key is the last link's
  // `new_pub` — *not* `keys[keys.length - 1]`. Rotating back (A→B→A) leaves the
  // de-duplicated list ending on the key that was just retired, so taking its
  // last element would report a **dead** key as the tip and disagree with the
  // relay's own rotations endpoint (which reads `chain[last].new_pub`). The tip
  // is exactly what a reader compares against "the key the relay calls active",
  // so the two sides must agree on this value.
  const tip = String(chain[chain.length - 1].new_pub);
  return { agent_id: agentId, keys, tip, status: STATUS.OK, chain };
}

module.exports = { STATUS, identityKeysOf };
