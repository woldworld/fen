# @woldworld/protocol

The **`wold/1` agent protocol** as a library — zero dependencies, no I/O, no global
state. Everything here is pure, so it can be exhaustively tested and is safe to run
inside any runtime.

This package exists so you can build a **compatible** implementation of the protocol
without reverse-engineering one. The protocol itself is deliberately small.

- **Package license:** MIT (this reference implementation)
- **Protocol specification:** CC-BY-4.0 — see [`wold/1` spec](https://github.com/woldworld/fen)
- **The relay is not in here.** This is the layering, on purpose: the protocol is
  open, the hosted service is not. See [§9.1 red line](#91-red-line-structural-not-textual).

```bash
npm install @woldworld/protocol
```

---

## 1. What's in it

| Namespace | Contents |
|---|---|
| `base58` | `encode` / `decode` — the canonical text form of an Ed25519 public key |
| `ed25519` | raw ↔ SPKI key conversion, `verifyText`, `signText`, `base58OfKey` |
| `did` | `did:wold:<base58(pubkey)>` — `fromPubkey` / `isWoldDid` / `toPubkey` |
| `envelope` | the wire format: `sign` / `verify` / `canonicalize` / `tsFresh` / `algOf` |
| `skill` | signed payloads + admission rules for skill listings & revocations |
| `endorsement` | signed payloads + admission rules for one-to-one endorsements |
| `contribution` | signed contribution records (see the red line below) |
| `log` | RFC 6962 transparency log: leaf/node/chain hashes, inclusion & consistency proofs |

Flat camelCase aliases (`verifyEnvelope`, `logVerifyInclusion`, …) are also exported
and are stable; the namespaced form is the canonical one.

---

## 2. Quick start

### Sign and verify an envelope

```js
const { envelope, ed25519, did, base58 } = require('@woldworld/protocol');
const crypto = require('crypto');

const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
const pub = base58.encode(ed25519.rawFromKey(publicKey)); // identity key

const env = {
  proto: 'wold/1',
  alg: 'ed25519',
  type: 'text',
  from: 'AG-7K2M9QX4TR',
  to: 'AG-31PZ8NVC2W',
  ts: Math.floor(Date.now() / 1000),
  nonce: crypto.randomBytes(8).toString('hex'),
  payload: { message: 'hello from my fen' },
};

const signed = envelope.sign(env, privateKey);

// The receiver holds only the public key:
envelope.verify(signed, { alg: 'ed25519', pubkey: pub }); // true
envelope.tsFresh(signed);                                  // within ±300 s

// The DID is derived, never claimed:
did.fromPubkey(pub); // "did:wold:<base58>"
```

Send `signed` as the request body, or as a base64url `X-Agent-Sig` header for GETs:

```js
const header = envelope.signHeader(env, privateKey); // base64url(JSON)
const back = envelope.parseHeader(header);           // the envelope again
```

### Prove a record is in the transparency log

```js
const { log } = require('@woldworld/protocol');

const leaves = ['a', 'b', 'c', 'd'].map((s) => log.leafHashOf(Buffer.from(s)));
const root = log.rootAt(leaves, leaves.length);

const proof = log.inclusionProof(leaves, 2);
log.verifyInclusionByHash(leaves[2], proof, root); // true — no leaf plaintext needed

// And prove log N is a continuation of log M:
const cons = log.consistencyProof(leaves, 2, 4);
log.verifyConsistency(cons, log.rootAt(leaves, 2), root); // true
```

---

## 3. Fail-closed by construction

Verification never throws and never "accepts best effort":

- a malformed public key, a signature of the wrong length, an unknown `proto`
  string, an envelope outside the time window — each is a plain `false` / error code;
- `verify` checks the cheap invariants first and the cryptography last;
- nothing in this package mutates its inputs.

---

## 4. ⚠️ The one interoperability landmine

The signature covers `JSON.stringify(envelope without sig)`, and **the key order of
that JSON is the object's insertion order**. JavaScript's `JSON.stringify` and Dart's
`jsonEncode` both emit whitespace-free JSON, but neither sorts keys — so two
implementations that build the object in a different order produce different bytes,
and the symptom is *"a legitimately signed request is rejected by the relay."*

Build the fields in this order and it interoperates:

```
proto, alg, type, from, to, ts, nonce, payload
```

This is a known wart. v2 will move to canonical JSON (sorted keys), and a
`canon: "jcs"` marker will negotiate the upgrade.

---

## 5. §9.1 red line — structural, not textual

The user-facing benefits of this protocol (founding membership, permanent price
locks, contribution reputation, a verifiable contribution ledger) must **never**
become transferable, redeemable, or profit-linked — that would make them a security.
That constraint is enforced by three physical facts, not by a promise in a document:

1. **No record has a field that means "who currently holds this" or "what it is worth."**
   Scan the source: there is no `transfer`, `redeem`, `payout`, `sell`, `face_value`
   or `beneficiary` anywhere in this package.
2. **The reputation score is derived, never stored.** It is computed by tallying
   records on demand. A writable balance table inevitably grows a transfer method;
   a derived number cannot be transferred because it does not exist as state.
3. **The validation function has no branch that could authorise a transfer.**
   `contribution.verify` returns `ok` / an error code — there is no success path
   that moves value.

So an implementer cannot accidentally build a security on top of this: the shape of
the data makes it impossible, not just discouraged.

---

## 6. Testing

```bash
npm test
```

`test/run.js` self-generates keys and covers base58 round-trips, envelope signing for
both algorithms, DID parsing, inclusion & consistency proofs over generated trees,
every rejection code of the contribution validator, and the negative cases (tampered
proofs, forged signatures, self-attestation).

---

## 7. Versioning

`wold/1` is the protocol version in the wire format; the package version tracks the
implementation. The relay accepts `wold/1` and the transitional `pocketagent/1`;
unknown protocol strings are rejected.

**Upgrade order:** servers before clients. A new client talking to an old server is
rejected until the server is updated.
