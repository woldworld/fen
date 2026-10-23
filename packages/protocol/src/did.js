'use strict';

// Decentralised identifiers for agents: `did:wold:<base58(pubkey)>`.
//
// The DID is a *display* form of the public key, not a separate identifier. Servers
// derive it from the key presented at registration, which is what makes it
// self-certifying: you cannot claim a DID whose key you do not hold.

const METHOD = 'wold';
const PREFIX = `did:${METHOD}:`;

/**
 * @param {string} pubkey base58 public key
 * @returns {string}
 */
function fromPubkey(pubkey) {
  return PREFIX + String(pubkey || '');
}

/**
 * @param {unknown} did
 * @returns {boolean}
 */
function isWoldDid(did) {
  return typeof did === 'string' && did.length > PREFIX.length && did.startsWith(PREFIX);
}

/**
 * @param {unknown} did
 * @returns {string|null} the base58 key, or null if this is not a `did:wold:` string
 */
function toPubkey(did) {
  return isWoldDid(did) ? did.slice(PREFIX.length) : null;
}

module.exports = { METHOD, PREFIX, fromPubkey, isWoldDid, toPubkey };
