'use strict';

const { keyFromBase58, verifyText } = require('./ed25519');
const log = require('./log');

// ============================================================================
// M10 P1 Room Roles — a Host-layer entitlement expressed as a **verifiable
// grant**, not as a local UI flag.
//
// The Dart client already keeps roles locally (`lib/core/room_role.dart`), and
// that file is honest about the limit: "the server is not involved yet, so
// whether the other side really is the host cannot be checked by a third
// party". This module is the other half of that sentence.
//
// Two iron rules, both enforced by **bytes** rather than by documentation:
//
//   1. A role always belongs to a room. `room_id` is part of the signed payload
//      and a blank one is rejected *before any crypto runs* — so a "global
//      role" has no representable, verifiable form. A grant object carries no
//      `scope` / `global` field at all; you cannot spell account-wide power
//      here even if you wanted to.
//
//   2. Roles are a Host-layer entitlement. Only a member of the host layer may
//      hand a role out, and the first member of a fresh room may only claim
//      host **for themselves**. `grantDecision` replays the room's prior grants
//      so that any observer, given the same list, reaches the same verdict.
//
// Revocation is deliberately **not** a separate record type: revoking is just
// granting `participant`. Two ways to say the same thing would be two ways for
// them to drift apart.
//
// ⚠️ Same landmine as every other canonical in this package: Dart's `jsonEncode`
//    and JS's `JSON.stringify` both produce whitespace-free JSON, but key order
//    comes from **insertion order**. Do not reorder these object literals.
// ============================================================================

/** Room roles. Mirrors `RoomRoleKind` in the Dart client. */
const ROLES = ['participant', 'host', 'cohost', 'guest', 'npc'];

/** The host layer: the only roles that may grant or revoke. */
const HOST_LAYER = ['host', 'cohost'];

/** The implicit role. It is never stored — absence of a record means this. */
const DEFAULT_ROLE = 'participant';

const MAX_ROOM_ID_CHARS = 200;
const MAX_AGENT_ID_CHARS = 200;

/** Signing payload. Must match the Dart `canonicalRoomRole()` byte for byte. */
function canonical(g) {
  return JSON.stringify({
    alg: 'ed25519',
    kind: 'room_role',
    room_id: String(g.room_id || ''),
    agent_id: String(g.agent_id || ''),
    agent_pub: String(g.agent_pub || ''),
    role: String(g.role || ''),
    granted_by: String(g.granted_by || ''),
    granter_pub: String(g.granter_pub || ''),
    at: Number(g.at_ms || 0),
  });
}

/**
 * Public leaf bytes for the §16 transparency log.
 *
 * ⚠️ Human handles (`agent_id` / `granted_by`) are **deliberately excluded** —
 *    exactly the reasoning that keeps a contribution's `note` out. A handle is
 *    free text a person chose; the log is downloadable by anyone. The public
 *    claim is stated over **pubkeys**, which are already pseudonymous:
 *    "pubkey P holds role R in room X, granted by pubkey Q at time T".
 */
function logBytes(g) {
  return Buffer.from(JSON.stringify({
    kind: 'room_role',
    room_id: String(g.room_id || ''),
    agent_pub: String(g.agent_pub || ''),
    role: String(g.role || ''),
    granter_pub: String(g.granter_pub || ''),
    at: Number(g.at_ms || 0),
  }), 'utf8');
}

/** The §16 leaf hash of a room-role grant. */
function leafHashOf(g) {
  return log.leafHashOf(logBytes(g));
}

/**
 * Idempotency key: **one role per (room, agent)**.
 *
 * Mirrors the client's DB primary key `(room_id, agent_id)`. The timestamp is
 * excluded on purpose — including it would let the same grant be re-signed at
 * a different time and counted as a second, conflicting change of role.
 */
function keyOf(roomId, agentId) {
  return `room|${String(roomId || '')}|${String(agentId || '')}`;
}

function sigValid(g) {
  return verifyText(g && g.granter_pub, canonical(g), g && g.sig);
}

/**
 * Full validation in the same order and with the same codes as the Dart side:
 * cheap checks first, cryptography last. Fail closed.
 * @returns {{ok:boolean, code:string}}
 */
function verify(g) {
  if (!g || typeof g !== 'object') return { ok: false, code: 'missing_fields' };
  const room = String(g.room_id || '');
  const agent = String(g.agent_id || '');
  const agentPub = String(g.agent_pub || '');
  const role = String(g.role || '');
  const granter = String(g.granted_by || '');
  const granterPub = String(g.granter_pub || '');
  const sig = String(g.sig || '');
  if (!sig) return { ok: false, code: 'missing_fields' };
  // ★ Iron rule 1, checked before anything else: a role with no room has no
  //   valid form. This branch is what makes "global role" unrepresentable.
  if (!room) return { ok: false, code: 'no_room' };
  if (room.length > MAX_ROOM_ID_CHARS) return { ok: false, code: 'bad_room' };
  if (!agent) return { ok: false, code: 'no_agent' };
  if (agent.length > MAX_AGENT_ID_CHARS) return { ok: false, code: 'bad_agent' };
  if (!granter) return { ok: false, code: 'no_granter' };
  if (!keyFromBase58(agentPub) || !keyFromBase58(granterPub)) {
    return { ok: false, code: 'bad_pubkey' };
  }
  if (!ROLES.includes(role)) return { ok: false, code: 'bad_role' };
  if (!(Number(g.at_ms) > 0)) return { ok: false, code: 'bad_window' };
  if (!sigValid(g)) return { ok: false, code: 'bad_signature' };
  return { ok: true, code: 'ok' };
}

/** Latest role per agent, as seen by replaying `grants` in chronological order. */
function latestRoles(grants, roomId) {
  const m = new Map();
  for (const p of grants || []) {
    if (String(p.room_id || '') !== String(roomId || '')) continue;
    m.set(String(p.agent_id || ''), String(p.role || DEFAULT_ROLE));
  }
  return m;
}

/** Convenience: a single agent's role in a room, defaulting to `participant`. */
function roleOf(grants, roomId, agentId) {
  return latestRoles(grants, roomId).get(String(agentId || '')) || DEFAULT_ROLE;
}

/**
 * Authority decision for a grant, given the room's **prior** grants.
 *
 * This is the check a third party runs: hand it the same list and it reaches
 * the same verdict, without asking us. Codes mirror the Dart client's
 * `RoomRoleBlockCode`.
 *
 * @param {object} g the candidate grant
 * @param {Array<object>} priorGrants earlier grants, chronological order
 * @returns {{accept:boolean, code:string}}
 */
function grantDecision(g, priorGrants) {
  const room = String(g && g.room_id || '');
  const agent = String(g && g.agent_id || '');
  const granter = String(g && g.granted_by || '');
  const role = String(g && g.role || '');
  if (!room) return { accept: false, code: 'no_room' };
  if (!agent) return { accept: false, code: 'no_agent' };
  if (!granter) return { accept: false, code: 'no_granter' };
  if (!ROLES.includes(role)) return { accept: false, code: 'bad_role' };

  const prior = priorGrants || [];
  const roles = latestRoles(prior, room);
  const granterRole = roles.get(granter) || DEFAULT_ROLE;
  const hostCount = [...roles.values()].filter((r) => HOST_LAYER.includes(r)).length;

  if (!HOST_LAYER.includes(granterRole)) {
    // The one exception: a vacant room, claimed host, for yourself only.
    if (role === 'host' && hostCount === 0 && granter === agent) {
      return { accept: true, code: 'claimed' };
    }
    // A room that already has a host cannot be claimed a second time — that is
    // what stops a latecomer from simply declaring themselves in charge.
    if (role === 'host' && hostCount > 0) {
      return { accept: false, code: 'host_exists' };
    }
    return { accept: false, code: 'not_host' };
  }

  // Refuse to strip the room of its last member of the host layer: that would
  // leave a room with participants and no one accountable for it.
  const currentRole = roles.get(agent) || DEFAULT_ROLE;
  if (HOST_LAYER.includes(currentRole) && !HOST_LAYER.includes(role)) {
    if (hostCount <= 1) return { accept: false, code: 'last_host' };
  }

  return { accept: true, code: 'accepted' };
}

module.exports = {
  ROLES,
  HOST_LAYER,
  DEFAULT_ROLE,
  MAX_ROOM_ID_CHARS,
  MAX_AGENT_ID_CHARS,
  canonical,
  logBytes,
  leafHashOf,
  keyOf,
  sigValid,
  verify,
  latestRoles,
  roleOf,
  grantDecision,
};
