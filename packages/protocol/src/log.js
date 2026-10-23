'use strict';

const crypto = require('crypto');
const { encode, decode } = require('./base58');

// ============================================================================
// §16 Transparency log — RFC 6962 (Certificate Transparency) primitives.
//
// The problem this solves: the relay is closed-source and cannot be fully trusted,
// yet it must not be able to lie. The answer is "you don't have to trust me, you
// can check me" — every issuance goes into a public append-only log, anyone can
// download it, recompute the tree, and prove their own record is in it, and prove
// that log N is a continuation of log N-1.
//
// Byte-exact definitions (a re-implementation must match these or proofs won't verify):
//   · leaf hash  = base58(SHA-256(0x00 ‖ leaf_bytes))
//   · node  hash = base58(SHA-256(0x01 ‖ left ‖ right))
//   · chain hash = base58(SHA-256(utf8('WL|idx|leafHash|prevHash')))
//   · empty root = base58(SHA-256(''))        ← not zero, not the empty string
//
// ⚠️ The 0x00 / 0x01 domain separation is not style: without it a leaf and an
//    interior node can hash to the same value, and an attacker can pass an interior
//    node off as a leaf (second-preimage attack).
// ⚠️ This module holds **leaf hashes only, never leaf plaintext**: a third party
//    recomputing the tree or checking any proof needs nothing but the hash list.
// ⚠️ The log does **no interpretation** — it only does arithmetic. Who did what is
//    signed by clients; the log's sole duty is "compute correctly, never rewrite".
// ⚠️ Truncation (dropping the last N entries) is undetectable by the chain alone —
//    that is what external anchoring is for.
// ============================================================================

const LEAF_PREFIX = Buffer.from([0x00]);
const NODE_PREFIX = Buffer.from([0x01]);

function sha256(...bufs) {
  const h = crypto.createHash('sha256');
  for (const b of bufs) h.update(b);
  return h.digest();
}

/** RFC 6962 MTH({}) — the hash of the empty string. */
function emptyRoot() {
  return encode(sha256(Buffer.alloc(0)));
}

/** RFC 6962 leaf hash, given the leaf bytes. */
function leafHashOf(leafBytes) {
  return encode(sha256(LEAF_PREFIX, Buffer.from(leafBytes)));
}

/** RFC 6962 interior node hash. Returns raw bytes (not base58). */
function nodeHash(l, r) {
  return sha256(NODE_PREFIX, l, r);
}

/** Position-binding chain hash — ties a leaf to its index and predecessor. */
function chainHash(idx, leafHash, prevHash) {
  return encode(sha256(Buffer.from(`WL|${idx}|${leafHash}|${prevHash}`, 'utf8')));
}

function decodeLeaves(leafHashes) {
  const out = [];
  for (const h of leafHashes) {
    const b = decode(h);
    if (!b) throw new Error('bad_leaf_hash');
    out.push(b);
  }
  return out;
}

/** Largest power of two **strictly less than** n (RFC 6962's k). Only meaningful for n > 1. */
function largestPowerOfTwoLessThan(n) {
  if (!(n > 1)) throw new Error(`largestPowerOfTwoLessThan requires n > 1, got ${n}`);
  let k = 1;
  while (k * 2 < n) k *= 2;
  return k;
}

// MTH(leaves[lo..hi)), half-open interval. Returns raw bytes.
function mth(leafBufs, lo, hi) {
  if (hi - lo === 1) return leafBufs[lo];
  const k = largestPowerOfTwoLessThan(hi - lo);
  return nodeHash(mth(leafBufs, lo, lo + k), mth(leafBufs, lo + k, hi));
}

/** Merkle tree head over the first `size` leaves. */
function rootAt(leafHashes, size) {
  if (size === 0) return emptyRoot();
  if (size < 0 || size > leafHashes.length) throw new Error('tree_size_out_of_range');
  return encode(mth(decodeLeaves(leafHashes), 0, size));
}

// ---- Inclusion proof (RFC 6962 §2.1.1, PATH) ----
function path(leafBufs, m, lo, hi) {
  const n = hi - lo;
  if (n === 1) return [];
  const k = largestPowerOfTwoLessThan(n);
  if (m < k) {
    const p = path(leafBufs, m, lo, lo + k);
    p.push(mth(leafBufs, lo + k, hi));
    return p;
  }
  const p = path(leafBufs, m - k, lo + k, hi);
  p.push(mth(leafBufs, lo, lo + k));
  return p;
}

function inclusionProof(leafHashes, index) {
  if (index < 0 || index >= leafHashes.length) throw new Error('index_out_of_range');
  const p = path(decodeLeaves(leafHashes), index, 0, leafHashes.length);
  return { index, tree_size: leafHashes.length, path: p.map(encode) };
}

function verifyInclusion(leafBytes, proof, root) {
  const n = proof.tree_size;
  if (!(n > 0) || proof.index < 0 || proof.index >= n) return false;
  const p = proof.path.map((h) => decode(h));
  if (p.some((b) => !b)) return false;
  const r = verifyPath(sha256(LEAF_PREFIX, Buffer.from(leafBytes)), proof.index, n, p);
  return r !== null && encode(r) === root;
}

/**
 * Same as {@link verifyInclusion} but takes the **leaf hash** instead of the leaf
 * bytes — the log's native check, since it never stores plaintext. A third party
 * who downloads `/api/log/leaves` can self-audit without any original content.
 */
function verifyInclusionByHash(leafHash, proof, root) {
  const n = proof.tree_size;
  if (!(n > 0) || proof.index < 0 || proof.index >= n) return false;
  const lh = decode(leafHash);
  if (!lh) return false;
  const p = proof.path.map((h) => decode(h));
  if (p.some((b) => !b)) return false;
  const r = verifyPath(lh, proof.index, n, p);
  return r !== null && encode(r) === root;
}

function verifyPath(leafHash, m, n, p) {
  if (n === 1) return p.length === 0 ? leafHash : null;
  if (p.length === 0) return null;
  const k = largestPowerOfTwoLessThan(n);
  const sib = p.pop();
  if (m < k) {
    const r = verifyPath(leafHash, m, k, p);
    return r === null ? null : nodeHash(r, sib);
  }
  const r = verifyPath(leafHash, m - k, n - k, p);
  return r === null ? null : nodeHash(sib, r);
}

// ---- Consistency proof (RFC 6962 §2.1.2, SUBPROOF) ----
//
// ⚠️ `m == 0` (empty-tree prefix) is a degenerate case the RFC does not define →
//    short-circuit at the top, empty proof. And `n == 1` needs an explicit guard,
//    otherwise `m=0, n=1` recurses forever with identical arguments.
function subproof(leafBufs, m, lo, hi, b) {
  const n = hi - lo;
  if (m === n) return b ? [] : [mth(leafBufs, lo, hi)];
  if (n === 1) return [];
  const k = largestPowerOfTwoLessThan(n);
  if (m <= k) {
    const p = subproof(leafBufs, m, lo, lo + k, b);
    p.push(mth(leafBufs, lo + k, hi));
    return p;
  }
  const p = subproof(leafBufs, m - k, lo + k, hi, false);
  p.push(mth(leafBufs, lo, lo + k));
  return p;
}

function consistencyProof(leafHashes, fromSize, toSize) {
  if (fromSize < 0 || toSize < fromSize || toSize > leafHashes.length) {
    throw new Error('bad_sizes');
  }
  if (fromSize === 0) return { from_size: 0, to_size: toSize, path: [] };
  const p = subproof(decodeLeaves(leafHashes), fromSize, 0, toSize, true);
  return { from_size: fromSize, to_size: toSize, path: p.map(encode) };
}

function verifyConsistency(proof, fromRoot, toRoot) {
  const m = proof.from_size;
  const n = proof.to_size;
  if (m < 0 || n < m) return false;
  if (m === n) return proof.path.length === 0 && fromRoot === toRoot;
  if (m === 0) return proof.path.length === 0;
  const p = proof.path.map((h) => decode(h));
  if (p.length === 0 || p.some((b) => !b)) return false;
  const from = decode(fromRoot);
  const to = decode(toRoot);
  if (!from || !to) return false;
  const res = verifySubproof(m, n, true, from, p, 0);
  if (res === null) return false;
  return res[2] === p.length && encode(res[0]) === fromRoot && encode(res[1]) === toRoot;
}

// Returns [prefix root, subtree root, next unconsumed position]; null if malformed.
function verifySubproof(m, n, b, known1, proof, pos) {
  if (m === n) {
    if (b) return known1 === null ? null : [known1, known1, pos];
    if (pos >= proof.length) return null;
    return [proof[pos], proof[pos], pos + 1];
  }
  if (n <= 1) return null;
  const k = largestPowerOfTwoLessThan(n);
  if (m <= k) {
    const left = verifySubproof(m, k, b, known1, proof, pos);
    if (left === null) return null;
    const p1 = left[2];
    if (p1 >= proof.length) return null;
    return [left[0], nodeHash(left[1], proof[p1]), p1 + 1];
  }
  const right = verifySubproof(m - k, n - k, false, null, proof, pos);
  if (right === null) return null;
  const p1 = right[2];
  if (p1 >= proof.length) return null;
  const l = proof[p1];
  return [nodeHash(l, right[0]), nodeHash(l, right[1]), p1 + 1];
}

/**
 * Verify a chain of log entries. Rewriting any `leaf_hash` / `hash` / `prev_hash`
 * (or reordering, or deleting a middle entry) makes this return false.
 * @param {Array<{idx:number,leaf_hash:string,prev_hash:string,hash:string}>} entries
 * @returns {boolean}
 */
function verifyChain(entries) {
  let prev = '';
  for (let i = 0; i < entries.length; i++) {
    const e = entries[i];
    if (!e || e.idx !== i) return false;
    if (e.prev_hash !== prev) return false;
    if (chainHash(i, e.leaf_hash, e.prev_hash) !== e.hash) return false;
    prev = e.hash;
  }
  return true;
}

/** Build the next chain entry for `leafHash` (pure — the caller owns the list). */
function nextEntry(entries, leafHash) {
  const prev = entries.length === 0 ? '' : entries[entries.length - 1].hash;
  const i = entries.length;
  return { idx: i, leaf_hash: leafHash, prev_hash: prev, hash: chainHash(i, leafHash, prev) };
}

module.exports = {
  LEAF_PREFIX,
  NODE_PREFIX,
  sha256,
  emptyRoot,
  leafHashOf,
  nodeHash,
  chainHash,
  rootAt,
  inclusionProof,
  verifyInclusion,
  verifyInclusionByHash,
  consistencyProof,
  verifyConsistency,
  verifyChain,
  nextEntry,
  largestPowerOfTwoLessThan,
};
