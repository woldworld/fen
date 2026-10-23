'use strict';

// ============================================================================
// @woldworld/protocol — self-check. `npm test`.
//
// Zero dependencies: keys and trees are generated in-process, so this runs on a
// machine with nothing but Node installed. Read the count on the last line:
// `PASS=n FAIL=m`.
//
// ⚠️ Keep the `PASS=n FAIL=m` format: the project's aggregation tooling greps it,
//    and the numbers must not follow a full-width punctuation mark (console
//    encoding swallows the first digit — a real, already-hit defect).
// ============================================================================

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const P = require('../src/index.js');
const { base58, ed25519, did, envelope, skill, endorsement, contribution, roomRole, log, rotation, report } = P;

let pass = 0;
let fail = 0;
function ck(ok, label) {
  if (ok) {
    pass++;
  } else {
    fail++;
    console.log('  FAIL  ' + label);
  }
}

function keysOf(json) {
  return JSON.stringify(Object.keys(JSON.parse(json)));
}

// A deterministic "keypair" per test run — Ed25519, generated locally.
const kpA = crypto.generateKeyPairSync('ed25519');
const kpB = crypto.generateKeyPairSync('ed25519');
const kpC = crypto.generateKeyPairSync('ed25519');
const pubA = base58.encode(ed25519.rawFromKey(kpA.publicKey));
const pubB = base58.encode(ed25519.rawFromKey(kpB.publicKey));
const pubC = base58.encode(ed25519.rawFromKey(kpC.publicKey));

// ------------------------------------------------------------------ base58
console.log('--- base58 ---');
{
  // Note: the empty buffer is excluded on purpose — its encoding is '' and
  // decode('') is `null` by design ('' is never a valid key).
  const cases = [
    Buffer.from([0]),
    Buffer.from([0, 0, 1]),
    Buffer.from('hello wold', 'utf8'),
    crypto.randomBytes(32),
  ];
  let allRoundTrip = true;
  for (const b of cases) {
    const s = base58.encode(b);
    const back = base58.decode(s);
    if (!back || !back.equals(b)) allRoundTrip = false;
  }
  ck(allRoundTrip, 'base58 encode→decode round-trips (incl. leading zero bytes)');
  ck(base58.encode(Buffer.alloc(0)) === '', 'the empty buffer encodes to the empty string');

  // Leading zeros are encoded as '1' — the classic base58 convention.
  ck(base58.encode(Buffer.from([0, 0, 1])) === '112', "leading zero bytes encode as '1'");

  ck(base58.decode('') === null, 'empty string → null');
  ck(base58.decode('0OIl') === null, "ambiguous glyphs (0/O/I/l) are not in the alphabet → null");
  ck(base58.decode('a'.repeat(65)) === null, 'over-long input → null (no BigInt blow-up)');
  ck(base58.decode(123) === null, 'non-string → null');
  ck(base58.ALPHABET.length === 58, 'alphabet is exactly 58 characters');
}

// ----------------------------------------------------------------- ed25519
console.log('--- ed25519 ---');
{
  ck(ed25519.keyFromBase58(pubA) !== null, 'a 32-byte base58 key wraps into a KeyObject');
  ck(ed25519.keyFromBase58('abc') === null, 'short key → null');
  ck(ed25519.keyFromBase58('') === null, 'empty key → null');
  ck(ed25519.keyFromBase58('!!!not-base58!!!') === null, 'non-alphabet characters → null');
  ck(ed25519.base58OfKey(kpA.publicKey) === pubA, 'rawFromKey/base58OfKey round-trip');

  const text = 'the signed bytes';
  const sig = ed25519.signText(kpA.privateKey, text);
  ck(ed25519.verifyText(pubA, text, sig) === true, 'valid signature verifies');
  ck(ed25519.verifyText(pubA, text + 'X', sig) === false, 'altered text → reject');
  ck(ed25519.verifyText(pubB, text, sig) === false, "another party's signature → reject");
  ck(ed25519.verifyText(pubA, text, 'short') === false, 'signature of the wrong length → reject');
  ck(ed25519.verifyText('abc', text, sig) === false, 'bad public key → reject (fail closed)');
}

// --------------------------------------------------------------------- did
console.log('--- did ---');
{
  const d = did.fromPubkey(pubA);
  ck(d === 'did:wold:' + pubA, 'did:wold:<base58(pubkey)>');
  ck(did.isWoldDid(d) === true, 'isWoldDid recognises it');
  ck(did.toPubkey(d) === pubA, 'toPubkey recovers the key');
  ck(did.isWoldDid('did:wold:') === false, 'bare prefix is not a DID');
  ck(did.toPubkey('did:pocketagent:abc') === null, 'another method → null');
  ck(did.toPubkey(undefined) === null, 'undefined → null');
}

// ---------------------------------------------------------------- envelope
console.log('--- envelope ---');
{
  const base = {
    proto: envelope.PROTO,
    alg: 'ed25519',
    type: 'text',
    from: 'AG-A',
    to: 'AG-B',
    ts: Math.floor(Date.now() / 1000),
    nonce: '0123456789abcdef',
    payload: { message: 'hello' },
  };
  const cred = { alg: 'ed25519', pubkey: pubA };
  const signed = envelope.sign(base, kpA.privateKey);

  ck(envelope.verify(signed, cred) === true, 'ed25519: sign → verify');
  ck(
    keysOf(envelope.canonicalize(base)) ===
      JSON.stringify(['proto', 'alg', 'type', 'from', 'to', 'ts', 'nonce', 'payload']),
    'signed field order is proto,alg,type,from,to,ts,nonce,payload (interop contract)'
  );

  ck(
    envelope.verify({ ...signed, payload: { message: 'tampered' } }, cred) === false,
    'altered payload → reject'
  );
  ck(envelope.verify({ ...signed, proto: 'wold/2' }, cred) === false, 'unknown proto → reject');
  ck(envelope.verify({ ...signed, sig: '' }, cred) === false, 'missing signature → reject');
  ck(envelope.verify({ ...signed, sig: 'AAAA' }, cred) === false, 'short signature → reject');
  ck(envelope.verify(signed, { alg: 'ed25519' }) === false, 'receiver lacks the key → reject');
  ck(envelope.verify(signed, null) === false, 'no credential → reject');
  ck(envelope.verify(null, cred) === false, 'no envelope → reject');

  // Transitional protocol is still accepted.
  const legacy = envelope.sign({ ...base, proto: envelope.LEGACY_PROTO }, kpA.privateKey);
  ck(envelope.verify(legacy, cred) === true, 'pocketagent/1 is accepted during the transition');

  // hmac-sha256 bootstrap path.
  const hmacEnv = envelope.sign({ ...base, alg: 'hmac-sha256' }, { secret: 'sh4red' });
  ck(
    envelope.verify(hmacEnv, { alg: 'hmac-sha256', secret: 'sh4red' }) === true,
    'hmac-sha256: sign → verify'
  );
  ck(
    envelope.verify(hmacEnv, { alg: 'hmac-sha256', secret: 'other' }) === false,
    'hmac: wrong secret → reject'
  );
  // A legacy record carries no `alg` field at all — a conforming receiver infers
  // hmac-sha256. Build it by hand, the way pre-`alg` code would have.
  const legacyEnv = {
    proto: envelope.PROTO,
    type: 'mailbox',
    from: 'AG-A',
    to: 'hub',
    ts: Math.floor(Date.now() / 1000),
    nonce: '0123456789abcdef',
    payload: { cursor: 0 },
  };
  const legacySigned = {
    ...legacyEnv,
    sig: envelope.hmacHex('sh4red', envelope.canonicalize(legacyEnv)),
  };
  ck(!('alg' in legacySigned), 'a legacy envelope carries no alg field');
  ck(
    envelope.verify(legacySigned, { secret: 'sh4red' }) === true,
    'absent alg defaults to hmac-sha256 (legacy records)'
  );

  // ★ sign() must never emit an ed25519 envelope without an alg — a conforming
  //   receiver would fall back to hmac-sha256 and reject a valid signature.
  const noAlg = {
    proto: envelope.PROTO,
    type: 'text',
    from: 'AG-A',
    to: 'AG-B',
    ts: Math.floor(Date.now() / 1000),
    nonce: '0123456789abcdef',
    payload: { message: 'hello' },
  };
  const signedNoAlg = envelope.sign(noAlg, kpA.privateKey);
  ck(signedNoAlg.alg === 'ed25519', 'sign infers ed25519 from a KeyObject');
  ck(
    keysOf(envelope.canonicalize(signedNoAlg)) ===
      JSON.stringify(['proto', 'alg', 'type', 'from', 'to', 'ts', 'nonce', 'payload']),
    '★ sign inserts alg in spec position, so the signed bytes stay in the documented order'
  );
  ck(envelope.verify(signedNoAlg, cred) === true, 'and the result verifies');
  ck(
    envelope.sign({ ...noAlg }, { secret: 'sh4red' }).alg === 'hmac-sha256',
    'sign infers hmac-sha256 from a secret'
  );

  ck(envelope.algOf({ alg: 'ed25519' }) === 'ed25519', 'algOf reads an explicit alg');
  ck(envelope.algOf({ secret: 's' }) === 'hmac-sha256', 'algOf infers from secret');
  ck(envelope.algOf({ pubkey: pubA }) === 'ed25519', 'algOf infers from pubkey');
  ck(envelope.algOf({}) === null, 'algOf with nothing → null');
  ck(envelope.algOfKey({ secret: 's' }) === 'hmac-sha256', 'algOfKey reads key material');
  ck(envelope.algOfKey(kpA.privateKey) === 'ed25519', 'algOfKey reads a raw KeyObject');
  ck(envelope.algOfKey(null) === null, 'algOfKey with nothing → null');

  const header = envelope.signHeader(base, kpA.privateKey);
  const parsed = envelope.parseHeader(header);
  ck(parsed !== null && parsed.sig === signed.sig, 'X-Agent-Sig header round-trips');
  ck(envelope.parseHeader('!!!') === null, 'malformed header → null');

  const now = Math.floor(Date.now() / 1000);
  ck(envelope.tsFresh({ ts: now }) === true, 'ts within window is fresh');
  ck(envelope.tsFresh({ ts: now - 301 }) === false, 'ts 301 s old is stale');
  ck(envelope.tsFresh({ ts: now + 301 }) === false, 'ts 301 s in the future is stale');
  ck(envelope.tsFresh({ ts: 0 }) === false, 'ts = 0 is not fresh');
  ck(
    envelope.tsFresh({ ts: now - 10 }, { nowSeconds: now, windowSeconds: 5 }) === false,
    'window is configurable'
  );
}

// ------------------------------------------------------------------- skill
console.log('--- skill ---');
{
  const listing = {
    skill_id: 'SK-1',
    version: '1.0.0',
    name: 'Translator',
    description: 'translates things',
    author_id: 'AG-A',
    author_pub: pubA,
    capabilities: ['tts', 'asr'],
    risk: 'low',
    content_hash: 'HASH1',
    price_cents: 100,
    currency: 'CNY',
    published_at: 1700000000,
  };
  const signed = { ...listing, sig: ed25519.signText(kpA.privateKey, skill.canonical(listing)) };

  ck(skill.sigValid(signed) === true, 'listing signature verifies');
  ck(skill.sigValid({ ...signed, price_cents: 101 }) === false, 'altered price → reject');
  ck(skill.sigValid({ ...signed, content_hash: 'X' }) === false, 'altered content hash → reject');
  ck(skill.sigValid({ ...signed, sig: '' }) === false, 'no signature → reject');
  ck(skill.sigValid({ ...signed, author_pub: 'abc' }) === false, 'bad author key → reject');

  // capabilities is a set: order must not leak into the signed bytes.
  ck(
    skill.canonical({ ...listing, capabilities: ['asr', 'tts'] }) === skill.canonical(listing),
    'capabilities are sorted, so set order cannot change the signature'
  );
  ck(
    keysOf(skill.canonical(listing)).includes('"capabilities"'),
    'listing canonical has an explicit field order'
  );

  ck(skill.compareVersion('1.2.10', '1.2.9') > 0, 'version compare: 1.2.10 > 1.2.9');
  ck(skill.compareVersion('1.0.0', '1.0.0') === 0, 'version compare: equal');
  ck(skill.compareVersion('0.9.0', '1.0.0') < 0, 'version compare: less');

  const existing = [{ ...listing, version: '1.0.0' }];
  ck(skill.publishDecision(listing, []).code === 'accepted', 'first publish → accepted');
  ck(skill.publishDecision(listing, existing).code === 'duplicate', 'same version+content → duplicate');
  ck(
    skill.publishDecision({ ...listing, content_hash: 'X' }, existing).code === 'version_conflict',
    'same version, different content → version_conflict'
  );
  ck(
    skill.publishDecision({ ...listing, version: '0.9.0' }, existing).code ===
      'version_not_increased',
    'older version → version_not_increased'
  );
  ck(
    skill.publishDecision({ ...listing, author_pub: pubB }, existing).code === 'author_changed',
    'a skillId never changes author'
  );
  ck(
    skill.publishDecision({ ...listing, version: '1.0.1' }, existing).code === 'accepted',
    'forward version → accepted'
  );
}

// ------------------------------------------------------------- endorsement
console.log('--- endorsement ---');
{
  const now = 1700000000000;
  const e = {
    issuer_pub: pubA,
    subject_pub: pubB,
    tier: 'friend',
    issued_at: now - 1000,
    expires_at: now + 1000 * 60 * 60,
    note: 'we know each other',
  };
  const signed = { ...e, sig: ed25519.signText(kpA.privateKey, endorsement.canonical(e)) };

  ck(endorsement.accept(signed, now).code === 'ok', 'valid endorsement → ok');
  ck(endorsement.accept(signed).code === 'ok', 'expiry ignored when now is not supplied');
  ck(
    endorsement.accept({ ...signed, issuer_pub: pubB, subject_pub: pubB }, now).code ===
      'self_endorsement',
    'self-endorsement → reject (before the signature check)'
  );
  ck(endorsement.accept({ ...signed, tier: 'stranger' }, now).code === 'bad_tier', 'unknown tier → reject');
  ck(
    endorsement.accept({ ...signed, note: 'x'.repeat(141) }, now).code === 'note_too_long',
    'note over 140 chars → reject'
  );
  ck(
    endorsement.accept({ ...signed, expires_at: e.issued_at - 1 }, now).code === 'bad_window',
    'expiry not after issue → reject'
  );
  ck(endorsement.accept({ ...signed, issued_at: 0 }, now).code === 'bad_window', 'issued_at = 0 → reject');
  ck(
    endorsement.accept({ ...signed, sig: 'AAAA' }, now).code === 'bad_signature',
    'bad signature → reject'
  );
  ck(
    endorsement.accept({ ...signed, issuer_pub: 'abc' }, now).code === 'bad_pubkey',
    'bad key → reject'
  );
  ck(endorsement.accept({}, now).code === 'missing_fields', 'empty → missing_fields');
  ck(endorsement.accept(signed, e.expires_at + 1).code === 'expired', 'past expiry → expired');

  const rev = { issuer_pub: pubA, subject_pub: pubB, at_ms: now };
  const signedRev = { ...rev, sig: ed25519.signText(kpA.privateKey, endorsement.revocationCanonical(rev)) };
  ck(endorsement.revocationSigValid(signedRev) === true, 'revocation signature verifies');
  ck(endorsement.revocationSigValid({ ...signedRev, at_ms: now + 1 }) === false, 'altered revocation → reject');
}

// ------------------------------------------------------------ contribution
console.log('--- contribution ---');
{
  const rec = {
    ctype: 'skill',
    subject_pub: pubA,
    attestor_pub: pubB,
    ref: 'SK-1@1.0.0',
    weight: contribution.WEIGHTS.skill,
    at: 1700000000000,
    note: 'published a skill',
  };
  const signed = { ...rec, sig: ed25519.signText(kpB.privateKey, contribution.canonical(rec)) };

  ck(contribution.verify(signed).ok === true, 'valid contribution → ok');
  ck(contribution.sigValid(signed) === true, 'contribution signature verifies');

  // Key order is the wire contract.
  ck(
    keysOf(contribution.canonical(rec)) ===
      JSON.stringify([
        'alg',
        'kind',
        'ctype',
        'subject_pub',
        'attestor_pub',
        'ref',
        'weight',
        'at',
        'note',
      ]),
    'contribution canonical field order'
  );
  ck(
    keysOf(contribution.logBytes(rec).toString('utf8')) ===
      JSON.stringify(['kind', 'ctype', 'subject_pub', 'attestor_pub', 'ref', 'weight', 'at']),
    'log leaf field order (and no note)'
  );

  // The public leaf must not leak free text.
  const withNote = contribution.leafHashOf({ ...rec, note: 'a secret' });
  const withoutNote = contribution.leafHashOf({ ...rec, note: 'something else entirely' });
  ck(withNote === withoutNote, 'note is excluded from the public leaf hash');
  ck(
    contribution.canonical({ ...rec, note: 'a secret' }) !==
      contribution.canonical({ ...rec, note: 'b' }),
    'note IS covered by the signature'
  );
  ck(
    contribution.leafHashOf({ ...rec, weight: 21 }) !== contribution.leafHashOf(rec),
    'weight is in the leaf, so retuning the table cannot rewrite history silently'
  );

  // Every rejection code.
  ck(contribution.verify(null).code === 'missing_fields', 'null → missing_fields');
  ck(
    contribution.verify({ ...signed, sig: '' }).code === 'missing_fields',
    'no signature → missing_fields'
  );
  ck(contribution.verify({ ...signed, ctype: 'nope' }).code === 'bad_kind', 'unknown kind → bad_kind');
  // `ref` is not part of the missing-fields gate: an empty ref on a non-founding
  // kind is a bad_ref, which keeps the two failure modes distinguishable.
  ck(contribution.verify({ ...signed, ref: '' }).code === 'bad_ref', 'empty ref → bad_ref');
  ck(
    contribution.verify({ ...signed, ref: 'x'.repeat(201) }).code === 'bad_ref',
    'over-long ref → bad_ref'
  );
  ck(
    contribution.verify({ ...signed, subject_pub: 'abc' }).code === 'bad_pubkey',
    'bad subject key → bad_pubkey'
  );
  ck(
    contribution.verify({ ...signed, weight: 999 }).code === 'bad_weight',
    'wrong weight → bad_weight'
  );
  ck(contribution.verify({ ...signed, at: 0 }).code === 'bad_window', 'at = 0 → bad_window');
  ck(
    contribution.verify({ ...signed, note: 'x'.repeat(141) }).code === 'note_too_long',
    'over-long note → note_too_long'
  );
  ck(
    contribution.verify({ ...signed, sig: 'AAAA' }).code === 'bad_signature',
    'bad signature → bad_signature'
  );

  // ★ Relationship-type contributions cannot self-report: a valid self-signature
  //   is still refused, because the check runs before the signature.
  const selfInvite = {
    ctype: 'invite',
    subject_pub: pubA,
    attestor_pub: pubA,
    ref: 'AG-X',
    weight: contribution.WEIGHTS.invite,
    at: 1700000000000,
  };
  const selfSigned = { ...selfInvite, sig: ed25519.signText(kpA.privateKey, contribution.canonical(selfInvite)) };
  ck(contribution.sigValid(selfSigned) === true, 'the self-attested record IS signed correctly');
  ck(
    contribution.verify(selfSigned).code === 'self_attestation',
    '★ self-attested invite → rejected anyway (counterparty proof required)'
  );
  // ...but an object-type contribution may self-sign: an independent artifact exists.
  const selfSkill = { ...rec, subject_pub: pubA, attestor_pub: pubA };
  ck(
    contribution.verify({ ...selfSkill, sig: ed25519.signText(kpA.privateKey, contribution.canonical(selfSkill)) })
      .ok === true,
    'object-type contribution may self-sign (the artifact exists on-platform)'
  );

  // Idempotency key: the timestamp is deliberately absent.
  ck(
    contribution.keyOf('invite', pubA, 'AG-X') === 'invite|' + pubA + '|AG-X',
    'key = kind|subject|ref'
  );
  ck(contribution.keyOf('founding', pubA, '') === 'founding|' + pubA, 'founding key = kind|subject');
  ck(
    contribution.keyOf('invite', pubA, 'AG-X') === contribution.keyOf('invite', pubA, 'AG-X'),
    'key is deterministic'
  );

  // Anti-farming tables.
  const kinds = Object.keys(contribution.WEIGHTS).sort();
  ck(
    JSON.stringify(kinds) === JSON.stringify([...contribution.KINDS].sort()),
    'every kind has a weight'
  );
  ck(
    contribution.REQUIRES_COUNTERPARTY.includes('invite') &&
      contribution.REQUIRES_COUNTERPARTY.includes('host'),
    'invite and host require a counterparty'
  );
  ck(
    Object.values(contribution.CAPS).every((v) => typeof v === 'number' && v > 0),
    'every kind has a positive cumulative cap (farming cannot grow the score)'
  );
}

// --------------------------------------------------------------------- log
console.log('--- log (§16, RFC 6962) ---');
{
  ck(
    log.emptyRoot() === base58.encode(log.sha256(Buffer.alloc(0))),
    "empty root is SHA-256('') (not zero, not the empty string)"
  );

  const leaves = [];
  for (let i = 0; i < 7; i++) leaves.push(log.leafHashOf(Buffer.from('leaf-' + i, 'utf8')));

  ck(log.leafHashOf(Buffer.from('leaf-0', 'utf8')) !== log.leafHashOf(Buffer.from('leaf-0x', 'utf8')),
    'leaf hash binds the content');
  ck(log.rootAt(leaves, 0) === log.emptyRoot(), 'rootAt(...,0) is the empty root');
  ck(log.rootAt(leaves, 1) === leaves[0], 'a one-leaf tree head is that leaf');
  ck(log.rootAt(leaves, 7) === log.rootAt(leaves, 7), 'the tree head is deterministic');
  ck(log.rootAt(leaves, 3) !== log.rootAt(leaves, 4), 'different sizes → different heads');

  let allInclusions = true;
  for (let n = 1; n <= leaves.length; n++) {
    const root = log.rootAt(leaves, n);
    for (let i = 0; i < n; i++) {
      const proof = log.inclusionProof(leaves.slice(0, n), i);
      if (!log.verifyInclusionByHash(leaves[i], proof, root)) allInclusions = false;
      if (!log.verifyInclusion(Buffer.from('leaf-' + i, 'utf8'), proof, root)) allInclusions = false;
    }
  }
  ck(allInclusions, 'every leaf of every tree size (1..7) has a verifiable inclusion proof');

  const p3 = log.inclusionProof(leaves, 3);
  const root7 = log.rootAt(leaves, 7);
  ck(log.verifyInclusionByHash(leaves[3], p3, root7) === true, 'inclusion proof verifies');
  ck(log.verifyInclusionByHash(leaves[2], p3, root7) === false, 'wrong leaf → reject');
  ck(
    log.verifyInclusionByHash(leaves[3], { ...p3, path: p3.path.slice(0, -1) }, root7) === false,
    'truncated proof → reject'
  );
  ck(
    log.verifyInclusionByHash(leaves[3], { ...p3, path: [...p3.path.slice(0, -1), leaves[0]] }, root7) ===
      false,
    'substituted sibling → reject'
  );
  ck(log.verifyInclusionByHash(leaves[3], { ...p3, index: 4 }, root7) === false, 'wrong index → reject');
  ck(
    log.verifyInclusionByHash(leaves[3], p3, log.rootAt(leaves, 6)) === false,
    'proof against the wrong tree head → reject'
  );

  let allConsistency = true;
  for (let n = 1; n <= leaves.length; n++) {
    for (let m = 0; m <= n; m++) {
      const proof = log.consistencyProof(leaves, m, n);
      if (!log.verifyConsistency(proof, log.rootAt(leaves, m), log.rootAt(leaves, n))) {
        allConsistency = false;
      }
    }
  }
  ck(allConsistency, 'every (m,n) pair has a verifiable consistency proof (incl. the m=0 degenerate case)');

  const c27 = log.consistencyProof(leaves, 2, 7);
  ck(log.verifyConsistency(c27, log.rootAt(leaves, 2), root7) === true, 'consistency 2→7 verifies');
  ck(
    log.verifyConsistency({ ...c27, from_size: 3 }, log.rootAt(leaves, 3), root7) === false,
    'a 2→7 proof cannot pass as 3→7'
  );
  ck(
    log.verifyConsistency({ ...c27, path: c27.path.slice(0, -1) }, log.rootAt(leaves, 2), root7) === false,
    'truncated consistency proof → reject'
  );
  ck(
    log.verifyConsistency({ from_size: 2, to_size: 7, path: c27.path }, log.rootAt(leaves, 1), root7) ===
      false,
    'wrong from-root → reject'
  );

  // Chain (append-only, position binding).
  const entries = [];
  for (const h of leaves) entries.push(log.nextEntry(entries, h));
  ck(log.verifyChain(entries) === true, 'an honest chain verifies');
  ck(log.verifyChain([]) === true, 'an empty chain is trivially consistent');
  ck(
    log.verifyChain(entries.map((e, i) => (i === 2 ? { ...e, leaf_hash: leaves[0] } : e))) === false,
    'rewriting a leaf hash breaks the chain'
  );
  ck(
    log.verifyChain(entries.map((e, i) => (i === 4 ? { ...e, hash: 'x' } : e))) === false,
    'rewriting a chain hash breaks the chain'
  );
  ck(log.verifyChain(entries.slice(0, 5).concat(entries.slice(6))) === false, 'deleting a middle entry breaks the chain');
  ck(log.verifyChain(entries.map((e, i) => (i === 1 ? { ...e, idx: 9 } : e))) === false, 'a moved index breaks the chain');
  ck(
    log.chainHash(0, leaves[0], '') !== log.chainHash(0, leaves[0], 'X') &&
      log.chainHash(0, leaves[0], '') !== log.chainHash(1, leaves[0], ''),
    'the chain hash is bound to both index and predecessor'
  );

  // Domain separation: a leaf hash and an interior node over the same 32 bytes differ.
  ck(
    log.leafHashOf(Buffer.concat([log.NODE_PREFIX, Buffer.alloc(0)])) !==
      base58.encode(log.nodeHash(Buffer.alloc(0), Buffer.alloc(0))),
    '0x00/0x01 domain separation prevents leaf/node collisions'
  );
}

// ------------------------------------------- M10 room roles (Host layer)
console.log('--- M10 room roles: a Host-layer entitlement that a stranger can check ---');
{
  const base = (over) =>
    Object.assign(
      {
        room_id: 'room-alpha',
        agent_id: 'alice',
        agent_pub: pubA,
        role: 'host',
        granted_by: 'alice',
        granter_pub: pubA,
        at_ms: 1700000000000,
      },
      over || {}
    );
  const signWith = (g, kp) =>
    Object.assign({}, g, { sig: ed25519.signText(kp.privateKey, roomRole.canonical(g)) });

  // Key order is the interop contract: Dart's jsonEncode and Node's
  // JSON.stringify both keep *insertion* order. A reorder here means the Dart
  // client's legitimately signed grant is rejected by a conforming relay.
  ck(
    keysOf(roomRole.canonical(base())) ===
      JSON.stringify([
        'alg',
        'kind',
        'room_id',
        'agent_id',
        'agent_pub',
        'role',
        'granted_by',
        'granter_pub',
        'at',
      ]),
    'canonical key order matches the Dart client exactly'
  );
  ck(!/\s/.test(roomRole.canonical(base())), 'canonical is whitespace-free');

  const good = signWith(base(), kpA);
  ck(roomRole.verify(good).ok === true, 'a signed self-claim of host verifies');

  // ★ Iron rule 1: a role with no room has no valid form — and it is rejected
  //   *before* any cryptography runs, so even a perfect signature cannot save it.
  const roomless = signWith(base({ room_id: '' }), kpA);
  ck(roomRole.verify(roomless).code === 'no_room', 'a signature over a roomless role is still rejected (no_room)');
  ck(roomRole.sigValid(roomless) === true, '...and its signature really was valid — the room check is what stops it');
  ck(roomRole.keyOf('', 'alice').startsWith('room||'), 'keyOf keeps the empty room visible rather than hiding it');

  ck(roomRole.verify({ ...good, sig: '' }).code === 'missing_fields', 'a missing signature → missing_fields');
  ck(roomRole.verify({ ...good, role: 'superuser' }).code === 'bad_role', 'an invented role → bad_role');
  ck(roomRole.verify({ ...good, agent_pub: 'not-a-key' }).code === 'bad_pubkey', 'a malformed agent key → bad_pubkey');
  ck(roomRole.verify({ ...good, at_ms: 0 }).code === 'bad_window', 'a missing timestamp → bad_window');

  // Any post-signing edit must break the signature — the whole point of signing.
  ck(
    roomRole.verify({ ...good, role: 'cohost' }).code === 'bad_signature',
    'upgrading your own role after signing → bad_signature'
  );
  ck(
    roomRole.verify({ ...good, agent_id: 'bob' }).code === 'bad_signature',
    're-pointing a grant at someone else → bad_signature'
  );
  ck(
    roomRole.verify({ ...good, at_ms: good.at_ms + 1 }).code === 'bad_signature',
    'back-dating a grant → bad_signature'
  );

  // Idempotency key = the (room, agent) pair, exactly like the client's DB PK.
  // Re-signing the *same* pair at a *different* time must yield the same key but
  // a different leaf — that mismatch is what a relay reports as a conflict.
  const later = signWith(base({ role: 'cohost', at_ms: good.at_ms + 5000 }), kpA);
  ck(roomRole.keyOf('room-alpha', 'alice') === roomRole.keyOf('room-alpha', 'alice'), 'the key is stable for one (room, agent)');
  ck(roomRole.keyOf('room-alpha', 'alice') !== roomRole.keyOf('room-beta', 'alice'), 'the same person in another room is another key');
  ck(
    roomRole.keyOf('room-alpha', 'alice') === roomRole.keyOf('room-alpha', 'alice') &&
      roomRole.leafHashOf(good) !== roomRole.leafHashOf(later),
    'same key + different leaf = a detectable conflict, not a silent second history'
  );
  ck(
    roomRole.leafHashOf({ ...good, at_ms: good.at_ms + 1 }) !== roomRole.leafHashOf(good),
    'the leaf hash binds the timestamp'
  );

  // The public leaf carries pubkeys only. A person's chosen handle must not end
  // up in a log anyone can download — same reasoning as excluding a note.
  ck(
    roomRole.leafHashOf(good) ===
      roomRole.leafHashOf({ ...good, agent_id: 'totally/another/handle', granted_by: 'x' }),
    'the human handle is not part of the public leaf bytes'
  );

  // Authority, replayable by an outsider from the same list of prior grants.
  const hostGrant = signWith(base(), kpA);
  const cohostGrant = signWith(
    base({ agent_id: 'bob', agent_pub: pubB, role: 'cohost', granted_by: 'alice', granter_pub: pubA, at_ms: 1700000001000 }),
    kpA
  );
  ck(
    roomRole.grantDecision(hostGrant, []).code === 'claimed',
    'a vacant room may be claimed — but only for yourself (claimed)'
  );
  ck(
    roomRole.grantDecision(signWith(base({ agent_id: 'bob', agent_pub: pubB }), kpB), []).code === 'not_host',
    'claiming host on a vacant room for somebody else → not_host'
  );
  ck(
    roomRole.grantDecision(
      signWith(
        base({ agent_id: 'bob', agent_pub: pubB, role: 'npc', granted_by: 'carol', granter_pub: pubC }),
        kpC
      ),
      [hostGrant]
    ).code === 'not_host',
    'a participant may not hand out roles → not_host'
  );
  ck(
    roomRole.grantDecision(cohostGrant, [hostGrant]).code === 'accepted',
    'the host may appoint a cohost → accepted'
  );
  ck(
    roomRole.grantDecision(cohostGrant, [hostGrant, cohostGrant]).code === 'accepted',
    'replaying the same list twice reaches the same verdict (idempotent replay)'
  );
  ck(
    roomRole.grantDecision(
      signWith(base({ agent_id: 'alice', agent_pub: pubA, role: 'participant' }), kpA),
      [hostGrant]
    ).code === 'last_host',
    'stripping the room of its last host is refused → last_host'
  );
  ck(
    roomRole.grantDecision(
      signWith(base({ agent_id: 'alice', agent_pub: pubA, role: 'participant', at_ms: 1700000002000 }), kpA),
      [hostGrant, cohostGrant]
    ).code === 'accepted',
    '...but a host may step down when another host-layer member remains'
  );
  ck(roomRole.roleOf([hostGrant], 'room-alpha', 'alice') === 'host', 'roleOf reads a granted role back');
  ck(
    roomRole.roleOf([hostGrant], 'room-beta', 'alice') === 'participant',
    '★ outside the room you are a participant — the role does not follow the account'
  );

  // There is deliberately no account-wide power: no such field, no such role.
  ck(
    !roomRole.ROLES.includes('admin') && !roomRole.ROLES.includes('owner'),
    'the role vocabulary has no account-level role'
  );
  ck(
    roomRole.HOST_LAYER.length === 2 && roomRole.HOST_LAYER.includes('host') && roomRole.HOST_LAYER.includes('cohost'),
    'the host layer is exactly {host, cohost}'
  );
  ck(
    !keysOf(roomRole.canonical(base())).includes('scope') &&
      !keysOf(roomRole.canonical(base())).includes('global') &&
      !keysOf(roomRole.canonical(base())).includes('expires_at'),
    '★ a signed role has no scope/global/lifetime field — account-wide power is not spellable'
  );
  ck(roomRole.DEFAULT_ROLE === 'participant', 'the implicit role is participant (absence of a record means this)');
}

// -------------------------------------------------------- identity rotation
console.log('--- identity rotation ---');
{
  const at = 1_700_000_000_000;
  const baseRec = { agent_id: 'AG-AAAA', old_pub: pubA, new_pub: pubB, rotated_at: at };
  const signWith = (r, kp) => ({ ...r, sig: ed25519.signText(kp.privateKey, rotation.canonical(r)) });
  const good = signWith(baseRec, kpA);

  ck(
    keysOf(rotation.canonical(baseRec)) ===
      JSON.stringify(['alg', 'kind', 'agent_id', 'old_pub', 'new_pub', 'rotated_at']),
    'canonical has exactly the declared fields, in a fixed order'
  );
  ck(!/\s/.test(rotation.canonical(baseRec)), 'canonical is whitespace-free');
  ck(rotation.canonical(baseRec) === rotation.canonical({ ...baseRec }), 'canonical is deterministic');
  ck(
    !keysOf(rotation.canonical(baseRec)).includes('scope') &&
      !keysOf(rotation.canonical(baseRec)).includes('global'),
    "the payload has no scope/global field — a rotation can never be 'account-wide' by accident"
  );

  ck(rotation.verify(good, pubA, at).accept === true, 'a rotation signed by the current key is accepted');
  ck(
    rotation.verify(good, pubA, at + rotation.MAX_SKEW_MS).accept === true,
    '...and is still accepted at the edge of the skew window'
  );
  ck(
    rotation.verify(good, pubA, at + rotation.MAX_SKEW_MS + 1).code === 'stale_rotation',
    '...but one millisecond past the window → stale_rotation'
  );
  ck(
    rotation.MAX_SKEW_MS > envelope.TS_WINDOW_SECONDS * 1000,
    'the skew window is wider than the envelope window (a just-set-up phone may be skewed)'
  );

  // The crux: only the key currently on file may retire itself.
  ck(
    rotation.verify(good, pubC, at).code === 'not_current_key',
    "a key that is not the one on file cannot rotate that identity"
  );
  ck(
    rotation.verify(good, '', at).code === 'not_current_key',
    'an unknown agent cannot be rotated into existence'
  );
  ck(
    rotation.verify(signWith({ ...baseRec, new_pub: pubA }, kpA), pubA, at).code === 'noop_rotation',
    'rotating onto the same key is refused (it would change nothing and cost a log entry)'
  );

  // Replay safety comes from the binding check, not from an expiry.
  ck(
    rotation.verify(good, pubB, at).code === 'not_current_key',
    '★ replaying an applied rotation fails: old_pub is no longer the current key'
  );

  ck(rotation.verify({ ...baseRec, sig: '' }, pubA, at).code === 'missing_fields', 'a missing signature → missing_fields');
  ck(rotation.verify({ ...baseRec, old_pub: 'not-a-key', sig: 'x' }, pubA, at).code === 'bad_pubkey', 'a malformed key → bad_pubkey');
  ck(rotation.verify({ ...baseRec, rotated_at: 0, sig: 'x' }, pubA, 0).code === 'bad_time', 'a missing timestamp → bad_time');

  // Every signed field must be covered by the signature.
  ck(
    rotation.verify({ ...good, new_pub: pubC }, pubA, at).code === 'bad_signature',
    'swapping new_pub after signing → bad_signature'
  );
  ck(
    rotation.verify({ ...good, agent_id: 'AG-BBBB' }, pubA, at).code === 'bad_signature',
    'swapping agent_id after signing → bad_signature'
  );
  ck(
    rotation.verify({ ...good, rotated_at: at + 1 }, pubA, at + 1).code === 'bad_signature',
    'shifting rotated_at after signing → bad_signature'
  );
  ck(
    rotation.sigValid({ ...baseRec, sig: ed25519.signText(kpC.privateKey, rotation.canonical(baseRec)) }) === false,
    "someone else's key cannot sign a rotation for this identity"
  );

  // ---- the §16 log leaf: committed bytes are a *different* object from canonical ----
  ck(
    keysOf(rotation.logBytes(baseRec).toString('utf8')) ===
      JSON.stringify(['kind', 'agent_id', 'old_pub', 'new_pub', 'rotated_at']),
    'logBytes carries exactly kind/agent_id/old_pub/new_pub/rotated_at, in a fixed order'
  );
  ck(
    !keysOf(rotation.logBytes(baseRec).toString('utf8')).includes('sig'),
    'logBytes excludes the signature (deterministic Ed25519 adds nothing the key+message do not fix)'
  );
  ck(
    !keysOf(rotation.logBytes(baseRec).toString('utf8')).includes('alg'),
    'logBytes carries `kind`, not `alg` — it is what a monitor recomputes, not what the key signs'
  );
  ck(
    rotation.leafHashOf(baseRec) === rotation.leafHashOf({ ...baseRec }),
    'leafHashOf is deterministic'
  );
  ck(
    rotation.leafHashOf(baseRec) !== rotation.leafHashOf({ ...baseRec, new_pub: pubC }),
    'changing new_pub yields a different §16 leaf (the record is actually committed)'
  );

  // ---- idempotency key mirrors the key_rotations primary key (agent_id, old_pub) ----
  ck(
    rotation.keyOf('AG-AAAA', pubA) === 'AG-AAAA|' + pubA,
    'keyOf is `agent_id|old_pub` (mirrors the key_rotations primary key)'
  );
  ck(
    rotation.keyOf('AG-AAAA', pubA) === rotation.keyOf('AG-AAAA', pubA),
    'keyOf is stable for the same event'
  );
  ck(
    rotation.keyOf('AG-AAAA', pubA) !== rotation.keyOf('AG-AAAA', pubB),
    '★ a different old key is a different event — a second rotation is not deduped away'
  );
}

// ------------------------------------------------------- identity aliases
// Reputation is indexed by public key (an id can be re-issued, a key cannot be
// renamed) — so a retired key would otherwise take the person's whole history
// with it. `identityKeysOf` answers "which keys are the same person?", and it
// must fail CLOSED: a wrong alias hands one person another person's history.
console.log('--- identity aliases (which keys are the same person?) ---');
{
  const sign = (r, kp) => ({
    ...r,
    sig: ed25519.signText(kp.privateKey, rotation.canonical(r)),
  });
  // A three-key identity: A retires itself into B, B retires itself into C.
  // Only a key can sign its own retirement, so the fully signed chain *is* the
  // proof that A, B and C are one person — no registry statement involved.
  const r1 = sign({ agent_id: 'AG-AAAA', old_pub: pubA, new_pub: pubB, rotated_at: 1700000000000, idx: 0 }, kpA);
  const r2 = sign({ agent_id: 'AG-AAAA', old_pub: pubB, new_pub: pubC, rotated_at: 1700000100000, idx: 1 }, kpB);
  const chain = [r1, r2];

  const fromTip = P.identityKeysOf(chain, pubC);
  ck(fromTip.status === 'ok', 'a fully signed, contiguous chain resolves to ok');
  ck(
    fromTip.keys.length === 3 && fromTip.keys[0] === pubA && fromTip.keys[2] === pubC,
    '★ querying the CURRENT key returns the whole history, genesis → tip'
  );

  const fromOld = P.identityKeysOf(chain, pubA);
  ck(
    fromOld.status === 'ok' && fromOld.keys.length === 3,
    '★ querying a RETIRED key resolves to the same identity (the direction the history gap needs)'
  );
  ck(
    fromOld.keys.join('|') === fromTip.keys.join('|'),
    'resolving from either end yields the same set'
  );
  ck(
    P.identityKeysOf(JSON.parse(JSON.stringify(chain)), pubB).keys.length === 3,
    'resolution depends only on the public records (deep copy → same answer)'
  );

  // ★ Rotating BACK to an earlier key (A→B→A) is legal, and it is exactly where
  // the tip is easy to get wrong: de-duplicating [A,B,A] yields [A,B], so the
  // last element is the key that was just *retired*. The tip must still be the
  // ACTIVE key (the last link's `new_pub` = A) — that is the value a reader
  // compares against "the key the relay calls active", so both sides must agree.
  const rBack = sign({ agent_id: 'AG-AAAA', old_pub: pubB, new_pub: pubA, rotated_at: 1700000100000, idx: 1 }, kpB);
  const back = P.identityKeysOf([r1, rBack], pubA);
  ck(back.status === 'ok', 'a rotate-BACK chain (A→B→A) still resolves to ok');
  ck(
    back.keys.join('|') === [pubA, pubB].join('|'),
    'rotate-back: `keys` is the de-duplicated SET of keys used (A,B)'
  );
  ck(
    back.keys[back.keys.length - 1] !== back.tip,
    '★ rotate-back: keys.last is the RETIRED key ⇒ it must not be readable as the tip'
  );
  ck(back.tip === pubA, '★★ rotate-back: tip = the ACTIVE key (A), NOT keys.last (B)');
  // Positive control: on a straight chain tip happens to equal keys.last, so the
  // assertions above are not vacuously true.
  ck(
    fromTip.tip === pubC && fromTip.tip === fromTip.keys[fromTip.keys.length - 1],
    '★ control: on a straight chain, tip = current key = keys.last'
  );

  // ---- fail-closed: every uncertainty must collapse to "just this key" ----
  const noChain = P.identityKeysOf([r1], pubC);
  ck(
    noChain.status === 'no_chain' && noChain.keys.length === 1 && noChain.keys[0] === pubC,
    '★ a key in no rotation record is its own identity (no_chain)'
  );
  ck(
    P.identityKeysOf(chain, 'SOMEONE-ELSE').keys.join() === 'SOMEONE-ELSE',
    "an unknown key never inherits anyone else's history"
  );

  // A link signed by the wrong key. One bad link invalidates the WHOLE chain:
  // we cannot tell which side of a forged link is the real one.
  const forged = [r1, sign({ agent_id: 'AG-AAAA', old_pub: pubB, new_pub: pubC, rotated_at: 1700000100000, idx: 1 }, kpC)];
  const forgedOut = P.identityKeysOf(forged, pubC);
  ck(
    forgedOut.status === 'unsigned' && forgedOut.keys.length === 1,
    '★ a link signed by the wrong key collapses the chain to a single key (unsigned)'
  );

  // A gap: B→C is recorded but A→B never was, so B→C looks contiguous *and*
  // signed. It must still refuse to hand pubC the keys it cannot account for.
  ck(P.identityKeysOf([r2], pubC).status === 'ok', 'a single-link chain is trivially contiguous');
  const forked = [r1, sign({ agent_id: 'AG-AAAA', old_pub: pubA, new_pub: pubC, rotated_at: 1700000100000, idx: 1 }, kpA)];
  const forkedOut = P.identityKeysOf(forked, pubC);
  ck(
    forkedOut.status === 'broken' && forkedOut.keys.length === 1,
    '★ links that do not join up (A→B then A→C) collapse to a single key (broken)'
  );

  // One key claimed by two identities: refuse to guess which claim is real.
  const other = sign({ agent_id: 'AG-BBBB', old_pub: pubC, new_pub: pubB, rotated_at: 1700000200000, idx: 2 }, kpC);
  ck(
    P.identityKeysOf([r1, r2, other], pubC).status === 'ambiguous',
    '★ one key claimed by two identities resolves to ambiguous, not to a guess'
  );

  // Ordering: `rotated_at` is client-reported and could be back-dated, so the
  // relay's append index is the only order we are willing to walk.
  ck(
    P.identityKeysOf([r2, r1], pubA).keys[2] === pubC,
    '★ records are ordered by relay `idx`, not by array position'
  );
  ck(
    P.identityKeysOf([{ ...r1, idx: undefined }, r2], pubA).status === 'unordered',
    'records without an append index cannot be ordered → fail closed'
  );

  ck(P.identityKeysOf([], pubA).status === 'no_chain', 'an empty record set → no_chain');
  ck(P.identityKeysOf(null, pubA).status === 'no_chain', 'a malformed record set never throws (fail-closed)');
  ck(P.identityKeysOf(chain, '').keys.length === 0, 'an empty subject resolves to nothing');
  ck(
    P.IDENTITY_KEY_STATUS.OK === 'ok' && P.IDENTITY_KEY_STATUS.BROKEN === 'broken',
    'status codes are exported (callers must not re-spell them)'
  );
}

// ------------------------------------------------- report tickets (举报工单)
console.log('--- report tickets: the state machine is the promise ---');
{
  const base = {
    ticket_id: 'RPT-0123456789AB',
    reporter_pub: pubA,
    target_id: 'AG-TARGET',
    reason: 'harassment',
    content_hash: 'a'.repeat(64),
    detail: 'this account keeps sending abusive messages',
    created_at: 1700000000000,
  };
  const signWith = (t, kp) => ({ ...t, sig: ed25519.signText(kp.privateKey, report.canonical(t)) });
  const good = signWith(base, kpA);

  // The wire contract: key order is insertion order, and Dart must match byte
  // for byte (a reorder here means a legitimately signed report is rejected).
  ck(
    keysOf(report.canonical(base)) ===
      JSON.stringify([
        'alg',
        'kind',
        'ticket_id',
        'reporter_pub',
        'target_id',
        'reason',
        'content_hash',
        'detail',
        'created_at',
      ]),
    'canonical key order matches the Dart client exactly'
  );
  // ★ 序列化不得引入任何格式化空白（换行/制表）—— 键之间的空格会让两端
  //   的字节口径在跨语言时差一个字符。注意 detail 里的**空格是内容**，
  //   不是序列化空白，所以这里只查控制空白。
  ck(!/[\n\r\t]/.test(report.canonical(base)), 'canonical carries no formatting whitespace');
  ck(report.canonical(base) === report.canonical({ ...base }), 'canonical is deterministic');

  ck(report.verify(good).ok === true, 'a signed report verifies');
  ck(report.sigValid(good) === true, 'report signature verifies');

  // Rejection codes, one by one.
  ck(report.verify(null).code === 'missing_fields', 'null → missing_fields');
  ck(report.verify({ ...good, sig: '' }).code === 'missing_fields', 'no signature → missing_fields');
  ck(report.verify({ ...good, ticket_id: 'nope' }).code === 'bad_ticket_id', 'a malformed ticket id → bad_ticket_id');
  ck(report.verify({ ...good, reporter_pub: 'abc' }).code === 'bad_pubkey', 'a malformed key → bad_pubkey');
  ck(report.verify({ ...good, reason: 'because' }).code === 'bad_reason', 'an invented reason → bad_reason');
  ck(report.verify({ ...good, content_hash: 'zz' }).code === 'bad_content_hash', 'a malformed content hash → bad_content_hash');
  ck(report.verify({ ...good, detail: 'x'.repeat(281) }).code === 'detail_too_long', 'over-long detail → detail_too_long');
  ck(report.verify({ ...good, created_at: 0 }).code === 'bad_window', 'created_at = 0 → bad_window');
  ck(report.verify({ ...good, sig: 'AAAA' }).code === 'bad_signature', 'a bad signature → bad_signature');

  // Every signed field must be covered by the signature.
  ck(report.verify({ ...good, reason: 'spam' }).code === 'bad_signature', 'changing the reason after signing → bad_signature');
  ck(report.verify({ ...good, target_id: 'AG-OTHER' }).code === 'bad_signature', 're-pointing the report after signing → bad_signature');
  ck(report.verify({ ...good, detail: 'different' }).code === 'bad_signature', 'editing the note after signing → bad_signature');

  // The reason whitelist is closed: an unknown reason is refused, not coerced.
  ck(report.REASONS.length === 5, 'the reason whitelist has exactly five entries');
  ck(!report.REASONS.includes('because'), 'the whitelist has no free-text reason slot');
  ck(report.STATES.length === 8, 'the state machine has exactly eight states');

  // --- the four hard rules ---
  // (2) `rejected` must carry a reason — and the check runs FIRST.
  ck(
    report.transitionDecision('in_review', 'rejected', { actor: 'admin' }).code === 'reason_required',
    '★ a rejection without a reason is refused (reason_required)'
  );
  ck(
    report.transitionDecision('in_review', 'rejected', { actor: 'admin', reason: 'not a violation' }).accept === true,
    'a rejection WITH a reason is accepted'
  );
  ck(
    report.transitionDecision('in_review', 'rejected', { actor: 'admin', reason: '   ' }).code === 'reason_required',
    'a whitespace-only reason is not a reason'
  );

  // (4) appeal only once.
  ck(
    report.transitionDecision('actioned', 'appealed', { actor: 'target', appeal_count: 1 }).code === 'appeal_exhausted',
    '★ a second appeal is refused (appeal_exhausted)'
  );
  ck(
    report.transitionDecision('actioned', 'appealed', { actor: 'target', appeal_count: 0 }).accept === true,
    'the first appeal is accepted'
  );
  // Narrow rule: appealing again while the ticket is ALREADY `appealed` must
  // report `appeal_exhausted` — the promised code for rule (4) — not
  // `bad_transition` (which reads as "the state machine is broken").
  ck(
    report.transitionDecision('appealed', 'appealed', { actor: 'reporter', appeal_count: 1 }).code === 'appeal_exhausted',
    '★ appealing again while already appealed is refused (appeal_exhausted)'
  );
  // The narrow rule must not leak into other combinations.
  ck(
    report.transitionDecision('closed', 'appealed', { actor: 'reporter', appeal_count: 1 }).code === 'bad_transition',
    '★ the narrow rule does not leak (closed → appealed is still bad_transition)'
  );

  // Who may start which edge.
  ck(
    report.transitionDecision('open', 'withdrawn', { actor: 'admin' }).code === 'wrong_actor',
    'only the reporter may withdraw their own report'
  );
  ck(report.transitionDecision('open', 'withdrawn', { actor: 'reporter' }).accept === true, 'the reporter may withdraw');
  ck(
    report.transitionDecision('rejected', 'appealed', { actor: 'target' }).code === 'wrong_actor',
    'the reported party cannot appeal a rejection (that is the reporter\'s edge)'
  );
  ck(
    report.transitionDecision('actioned', 'appealed', { actor: 'reporter' }).code === 'wrong_actor',
    'the reporter cannot appeal their own report being acted on'
  );
  ck(
    report.transitionDecision('open', 'triaged', { actor: 'reporter' }).code === 'wrong_actor',
    'only the operator advances the machine (except withdrawal / appeal)'
  );
  ck(report.transitionDecision('open', 'triaged', { actor: 'admin' }).accept === true, 'the operator may triage');

  // Illegal edges are refused, and terminal states have no way out.
  ck(report.transitionDecision('open', 'closed', { actor: 'admin' }).code === 'bad_transition', 'open → closed is not an edge');
  ck(report.transitionDecision('closed', 'in_review', { actor: 'admin' }).code === 'bad_transition', 'a closed ticket cannot be reopened');
  ck(report.transitionDecision('withdrawn', 'triaged', { actor: 'admin' }).code === 'bad_transition', 'a withdrawn ticket cannot be reopened');
  ck(report.isTerminal('closed') === true && report.isTerminal('withdrawn') === true, 'closed and withdrawn are terminal');
  ck(report.isTerminal('open') === false, 'open is not terminal');

  // ★ Both rejection paths must be able to reach a final state, otherwise
  //   "终局" would be a lie for the rejection branch.
  ck(report.TRANSITIONS.rejected.includes('closed'), 'a rejected ticket can be closed');
  ck(report.TRANSITIONS.actioned.includes('closed'), 'an actioned ticket can be closed');

  // (1) every transition leaves exactly one audit record, of one shape.
  const rec = report.auditRecord('RPT-0123456789AB', 'open', 'triaged', 1700000000001, 'admin', 'in scope');
  ck(
    keysOf(JSON.stringify(rec)) ===
      JSON.stringify(['ticket_id', 'from', 'to', 'at', 'actor', 'reason']),
    'the audit record has exactly one shape (two writers cannot disagree)'
  );

  // (3) the reported party's view structurally cannot leak the reporter.
  const pub = report.publicViewOf({
    ...good,
    status: 'actioned',
    action: 'restrict',
    reporter_pub: pubA,
    reporter_id: 'alice',
    detail: 'private note from the reporter',
    content_hash: 'a'.repeat(64),
  });
  const pubKeys = Object.keys(pub);
  ck(
    !pubKeys.includes('reporter_pub') &&
      !pubKeys.includes('reporter_id') &&
      !pubKeys.includes('detail') &&
      !pubKeys.includes('content_hash'),
    '★ the reported-party view has no reporter identity and no report content'
  );
  ck(pub.ticket_id === 'RPT-0123456789AB' && pub.status === 'actioned', 'the reported party still learns the outcome');
  ck(
    Object.keys(report.reporterViewOf(good)).includes('detail'),
    'the reporter does get their own note back'
  );

  // Idempotency key: one ticket, one key.
  ck(report.keyOf('RPT-0123456789AB') === 'report|RPT-0123456789AB', 'the key is `report|<ticket_id>`');
  ck(report.keyOf('RPT-0123456789AB') === report.keyOf('RPT-0123456789AB'), 'the key is stable');
  ck(report.keyOf('RPT-0123456789AB') !== report.keyOf('RPT-0123456789ABC'), 'a different ticket is a different key');
}

// ------------------------------------------------------ §9.1 red line (src)
console.log('--- §9.1 red line (structural scan of src/) ---');
{
  const srcDir = path.join(__dirname, '..', 'src');
  const files = fs.readdirSync(srcDir).filter((f) => f.endsWith('.js'));
  const src = files.map((f) => fs.readFileSync(path.join(srcDir, f), 'utf8')).join('\n');

  // We scan for *syntax that could move value*, not for the words themselves —
  // the comments document why the capability must not exist, so a naive word
  // scan would flag its own rationale.
  const forbiddenMethod = /\b(transfer|redeem|payout|sell|mint|burn)[A-Za-z_]*\s*\(/;
  const forbiddenField = /["'](transfer|redeem|payout|sell|face_value|beneficiary|dividend)["']\s*[:(]/;

  ck(!forbiddenMethod.test(src), 'no transfer/redeem/payout/sell/mint/burn callable anywhere in src/');
  ck(!forbiddenField.test(src), 'no transfer/redeem/face_value/beneficiary/dividend field anywhere in src/');
  ck(
    files.length >= 8,
    'the protocol is split into modules (base58/ed25519/did/envelope/skill/endorsement/contribution/log)'
  );
  ck(
    !/module\.exports\s*=\s*\{[^}]*\bsetBalance\b/.test(src),
    'there is no writable balance anywhere (the score is derived, not stored)'
  );
}

// ------------------------------------------------------------------ report
console.log('');
console.log('================ @woldworld/protocol self-check: ' + pass + ' PASS / ' + fail + ' FAIL ================');
process.exit(fail === 0 ? 0 : 1);
