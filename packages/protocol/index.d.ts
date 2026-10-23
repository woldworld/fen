// Type definitions for @woldworld/protocol
// The wold/1 agent protocol: envelope, base58 keys, DIDs, signed payloads,
// and RFC 6962 transparency-log verification.

/// <reference types="node" />

import type { KeyObject } from 'node:crypto';

// ---------------------------------------------------------------- base58

declare namespace base58 {
  const ALPHABET: string;
  const MAX_DECODE_CHARS: number;
  /** Encode bytes to base58. */
  function encode(buf: Buffer | Uint8Array): string;
  /** Decode base58 to bytes. Returns `null` (never throws) on anything malformed. */
  function decode(s: string): Buffer | null;
}

// --------------------------------------------------------------- ed25519

declare namespace ed25519 {
  const SPKI_PREFIX: Buffer;
  const RAW_KEY_BYTES: 32;
  const SIG_BYTES: 64;
  /** Wrap 32 raw key bytes into a KeyObject. `null` if the length is wrong. */
  function keyFromRaw(raw: Buffer | Uint8Array): KeyObject | null;
  /** Decode a base58 identity key and wrap it. `null` on anything unexpected. */
  function keyFromBase58(b58: string): KeyObject | null;
  /** The 32 raw bytes behind a KeyObject. */
  function rawFromKey(publicKey: KeyObject): Buffer;
  /** base58 of the raw bytes of a KeyObject — its identity string. */
  function base58OfKey(publicKey: KeyObject): string;
  /** Detached Ed25519 verification over UTF-8 text. Fail closed. */
  function verifyText(publicKeyB58: string, text: string, sigBase64: string): boolean;
  /** Sign UTF-8 text. Returns base64. */
  function signText(privateKey: KeyObject | Buffer | Uint8Array, text: string): string;
}

// ------------------------------------------------------------------- did

declare namespace did {
  const METHOD: 'wold';
  const PREFIX: 'did:wold:';
  function fromPubkey(pubkey: string): string;
  function isWoldDid(did: unknown): boolean;
  /** The base58 key behind a `did:wold:` string, or `null`. */
  function toPubkey(did: unknown): string | null;
}

// -------------------------------------------------------------- envelope

export interface WoldEnvelope {
  proto: string;
  alg?: 'ed25519' | 'hmac-sha256' | string;
  type?: string;
  from: string;
  to: string;
  ts: number;
  nonce?: string;
  payload?: unknown;
  sig?: string;
  [k: string]: unknown;
}

export interface EnvelopeCredential {
  alg?: string;
  secret?: string;
  pubkey?: string;
}

declare namespace envelope {
  const PROTO: 'wold/1';
  const LEGACY_PROTO: 'pocketagent/1';
  const ACCEPTED_PROTOS: Set<string>;
  const TS_WINDOW_SECONDS: 300;
  function hmacHex(secret: string, data: string): string;
  function algOf(cred: EnvelopeCredential | null | undefined): string | null;
  function algOfKey(
    key: KeyObject | { privateKey: KeyObject } | { secret: string } | null | undefined
  ): string | null;
  /** The exact bytes a signature covers: the envelope minus `sig`, insertion order preserved. */
  function canonicalize(env: WoldEnvelope): string;
  function sign(
    env: WoldEnvelope,
    key: KeyObject | { privateKey: KeyObject } | { secret: string }
  ): WoldEnvelope;
  function signHeader(env: WoldEnvelope, key: KeyObject | { secret: string }): string;
  function parseHeader(header: string): WoldEnvelope | null;
  function verify(env: WoldEnvelope, cred: EnvelopeCredential): boolean;
  const verifyEnvelope: typeof verify;
  function tsFresh(env: WoldEnvelope, opts?: { nowSeconds?: number; windowSeconds?: number }): boolean;
}

// ----------------------------------------------------------------- skill

declare namespace skill {
  interface Listing {
    skill_id?: string;
    version?: string;
    name?: string;
    description?: string;
    author_id?: string;
    author_pub?: string;
    capabilities?: string[];
    risk?: string;
    content_hash?: string;
    price_cents?: number;
    currency?: string;
    published_at?: number;
    sig?: string;
  }
  interface Revocation {
    skill_id?: string;
    version?: string;
    author_pub?: string;
    reason?: string;
    at_ms?: number;
    sig?: string;
  }
  interface Decision {
    accept: boolean;
    code: string;
  }
  function canonical(l: Listing): string;
  function sigValid(l: Listing): boolean;
  function revocationCanonical(r: Revocation): string;
  function revocationSigValid(r: Revocation): boolean;
  function parseVersion(v: string): [number, number, number];
  function compareVersion(a: string, b: string): -1 | 0 | 1;
  function publishDecision(incoming: Listing, existing: Listing[]): Decision;
}

// ----------------------------------------------------------- endorsement

declare namespace endorsement {
  type Tier = 'acquaintance' | 'friend' | 'family';
  const TIERS: Tier[];
  const MAX_NOTE_CHARS: 140;
  interface Endorsement {
    issuer_pub?: string;
    subject_pub?: string;
    tier?: Tier | string;
    issued_at?: number;
    expires_at?: number;
    note?: string;
    sig?: string;
  }
  interface Revocation {
    issuer_pub?: string;
    subject_pub?: string;
    at_ms?: number;
    sig?: string;
  }
  function canonical(e: Endorsement): string;
  function sigValid(e: Endorsement): boolean;
  function revocationCanonical(r: Revocation): string;
  function revocationSigValid(r: Revocation): boolean;
  function accept(e: Endorsement, nowMs?: number): { accept: boolean; code: string };
}

// ---------------------------------------------------------- contribution

export type ContributionKind =
  | 'founding'
  | 'invite'
  | 'circle'
  | 'host'
  | 'plugin'
  | 'skill';

declare namespace contribution {
  const KINDS: ContributionKind[];
  const WEIGHTS: Record<ContributionKind, number>;
  const REQUIRES_COUNTERPARTY: ContributionKind[];
  const MAX_NOTE_CHARS: 140;
  const MAX_REF_CHARS: 200;
  const CAPS: Record<ContributionKind, number>;

  interface Record {
    ctype?: ContributionKind | string;
    subject_pub?: string;
    attestor_pub?: string;
    ref?: string;
    weight?: number;
    at?: number;
    note?: string;
    sig?: string;
  }

  function canonical(r: Record): string;
  function logBytes(r: Record): Buffer;
  function leafHashOf(r: Record): string;
  function keyOf(ctype: string, subjectPub: string, ref: string): string;
  function sigValid(r: Record): boolean;
  function verify(r: Record): { ok: boolean; code: string };
}

// -------------------------------------------------------------- roomRole

export type RoomRoleKind = 'participant' | 'host' | 'cohost' | 'guest' | 'npc';

/**
 * A Host-layer entitlement for one (room, agent) pair.
 *
 * There is deliberately no `scope` / `global` field: a role that is not tied to
 * a room has no representable form here.
 */
export interface RoomRoleGrantLike {
  room_id?: string;
  agent_id?: string;
  agent_pub?: string;
  role?: RoomRoleKind | string;
  granted_by?: string;
  granter_pub?: string;
  at_ms?: number;
  sig?: string;
}

declare namespace roomRole {
  const ROLES: RoomRoleKind[];
  const HOST_LAYER: RoomRoleKind[];
  const DEFAULT_ROLE: 'participant';
  const MAX_ROOM_ID_CHARS: 200;
  const MAX_AGENT_ID_CHARS: 200;

  function canonical(g: RoomRoleGrantLike): string;
  function logBytes(g: RoomRoleGrantLike): Buffer;
  function leafHashOf(g: RoomRoleGrantLike): string;
  function keyOf(roomId: string, agentId: string): string;
  function sigValid(g: RoomRoleGrantLike): boolean;
  function verify(g: RoomRoleGrantLike): { ok: boolean; code: string };
  function latestRoles(
    grants: RoomRoleGrantLike[],
    roomId: string
  ): Map<string, string>;
  function roleOf(
    grants: RoomRoleGrantLike[],
    roomId: string,
    agentId: string
  ): string;
  function grantDecision(
    g: RoomRoleGrantLike,
    priorGrants: RoomRoleGrantLike[]
  ): { accept: boolean; code: string };
}

// ------------------------------------------------------------------- log

export interface LogInclusionProof {
  index: number;
  tree_size: number;
  path: string[];
}

export interface LogConsistencyProof {
  from_size: number;
  to_size: number;
  path: string[];
}

export interface LogEntry {
  idx: number;
  leaf_hash: string;
  prev_hash: string;
  hash: string;
}

declare namespace log {
  const LEAF_PREFIX: Buffer;
  const NODE_PREFIX: Buffer;
  function sha256(...bufs: Buffer[]): Buffer;
  function emptyRoot(): string;
  function leafHashOf(leafBytes: Buffer | Uint8Array): string;
  function nodeHash(l: Buffer, r: Buffer): Buffer;
  function chainHash(idx: number, leafHash: string, prevHash: string): string;
  function rootAt(leafHashes: string[], size: number): string;
  function inclusionProof(leafHashes: string[], index: number): LogInclusionProof;
  function verifyInclusion(leafBytes: Buffer | Uint8Array, proof: LogInclusionProof, root: string): boolean;
  function verifyInclusionByHash(leafHash: string, proof: LogInclusionProof, root: string): boolean;
  function consistencyProof(leafHashes: string[], fromSize: number, toSize: number): LogConsistencyProof;
  function verifyConsistency(proof: LogConsistencyProof, fromRoot: string, toRoot: string): boolean;
  function verifyChain(entries: LogEntry[]): boolean;
  function nextEntry(entries: LogEntry[], leafHash: string): LogEntry;
  function largestPowerOfTwoLessThan(n: number): number;
}

// -------------------------------------------------------------- rotation

/** A signed declaration that retires `old_pub` in favour of `new_pub`. */
export interface IdentityRotationLike {
  agent_id: string;
  old_pub: string;
  new_pub: string;
  rotated_at: number;
  sig?: string;
}

declare namespace rotation {
  /** Widened versus the 5-minute envelope window: a freshly set up phone may be skewed. */
  const MAX_SKEW_MS: number;
  function canonical(r: IdentityRotationLike): string;
  function sigValid(r: IdentityRotationLike): boolean;
  /** The exact bytes committed to the §16 Merkle tree (distinct from `canonical`). */
  function logBytes(r: IdentityRotationLike): Uint8Array;
  /** The §16 leaf hash of a rotation record. */
  function leafHashOf(r: IdentityRotationLike): string;
  /** Idempotency key `agent_id|old_pub` (mirrors the `key_rotations` primary key). */
  function keyOf(agentId: string, oldPub: string): string;
  function verify(
    r: IdentityRotationLike,
    currentPub: string,
    nowMs?: number,
  ): { accept: boolean; code: string };
}

// ----------------------------------------------------------------- alias

/** Why alias resolution stopped. Anything other than `ok` means "this key only". */
export type IdentityKeyStatus =
  | 'ok'
  | 'no_chain'
  | 'ambiguous'
  | 'unsigned'
  | 'unordered'
  | 'broken';

/** A public rotation record as the relay stores it (`idx` is the relay's append order). */
export interface AliasRotationRecord extends IdentityRotationLike {
  idx?: number;
}

export interface IdentityKeys {
  agent_id: string | null;
  /** Every key of this identity, ordered genesis → current. */
  keys: string[];
  tip: string;
  status: IdentityKeyStatus;
  /** The records the resolution was derived from, so a reader can re-derive it. */
  chain: AliasRotationRecord[];
}

/**
 * Which public keys belong to the same person as `subjectPub`?
 *
 * Reputation is indexed by key, so a retired key would otherwise take the
 * person's whole history with it. Fails closed: any doubt (forged link,
 * missing link, unordered records, two identities claiming one key) resolves
 * to `[subjectPub]` alone, because a wrong alias hands one person another
 * person's history.
 */
declare namespace alias {
  const STATUS: Record<'OK' | 'NO_CHAIN' | 'AMBIGUOUS' | 'UNSIGNED' | 'UNORDERED' | 'BROKEN', IdentityKeyStatus>;
  function identityKeysOf(records: AliasRotationRecord[] | null, subjectPub: string): IdentityKeys;
}

// ----------------------------------------------------------------- report

/** 举报事由白名单（封闭集合）。不在表内 ⇒ 拒绝受理。 */
export type ReportReason =
  | 'spam'
  | 'harassment'
  | 'illegal_content'
  | 'fake_identity'
  | 'other';

/** 工单状态机（8 态）。 */
export type ReportStatus =
  | 'open'
  | 'triaged'
  | 'in_review'
  | 'actioned'
  | 'rejected'
  | 'appealed'
  | 'closed'
  | 'withdrawn';

/** 转移的发起方角色。 */
export type ReportActor = 'reporter' | 'target' | 'admin';

/**
 * 一张举报工单。
 *
 * 签名覆盖 `canonical()` 的全部字段；`detail` 是举报人自己写的附注，
 * `content_hash` 是被举报内容的哈希（**不存原文**）。
 */
export interface ReportTicketLike {
  ticket_id?: string;
  reporter_pub?: string;
  target_id?: string;
  reason?: ReportReason | string;
  content_hash?: string;
  detail?: string;
  created_at?: number;
  /** 落库后的运行时字段（不在签名载荷里）。 */
  status?: ReportStatus | string;
  status_note?: string;
  action?: string;
  appeal_count?: number;
  updated_at?: number;
  sig?: string;
}

export interface ReportTransitionContext {
  appeal_count?: number;
  reason?: string;
  actor?: ReportActor | string;
}

export interface ReportAuditRecord {
  ticket_id: string;
  from: string;
  to: string;
  at: number;
  actor: string;
  reason: string;
}

declare namespace report {
  const REASONS: ReportReason[];
  const STATES: ReportStatus[];
  const TRANSITIONS: Record<ReportStatus, ReportStatus[]>;
  const ACTORS: Record<'REPORTER' | 'TARGET' | 'ADMIN', ReportActor>;
  const MAX_DETAIL_CHARS: number;
  const TICKET_ID_RE: RegExp;
  const CONTENT_HASH_RE: RegExp;

  function canonical(t: ReportTicketLike): string;
  function keyOf(ticketId: string): string;
  function sigValid(t: ReportTicketLike): boolean;
  function verify(t: ReportTicketLike): { ok: boolean; code: string };
  function isTerminal(state: string): boolean;
  function transitionDecision(
    from: string,
    to: string,
    ctx?: ReportTransitionContext
  ): { accept: boolean; code: string };
  function auditRecord(
    ticketId: string,
    from: string,
    to: string,
    atMs: number,
    actor: string,
    reason: string
  ): ReportAuditRecord;
  function reporterViewOf(t: ReportTicketLike): Record<string, unknown>;
  /**
   * The **reported party's** view. Structurally free of any field that could
   * identify the reporter or expose the report content.
   */
  function publicViewOf(t: ReportTicketLike): Record<string, unknown>;
}

// ---------------------------------------------------------------- exports

export { base58, ed25519, did, envelope, skill, endorsement, contribution, roomRole, log, rotation, alias, report };

export const base58Encode: typeof base58.encode;
export const base58Decode: typeof base58.decode;
export const ed25519KeyFromBase58: typeof ed25519.keyFromBase58;
export const ed25519RawFromKey: typeof ed25519.rawFromKey;
export const didFromPubkey: typeof did.fromPubkey;
export const isWoldDid: typeof did.isWoldDid;
export const pubkeyFromDid: typeof did.toPubkey;

export const PROTO: typeof envelope.PROTO;
export const LEGACY_PROTO: typeof envelope.LEGACY_PROTO;
export const ACCEPTED_PROTOS: typeof envelope.ACCEPTED_PROTOS;
export const TS_WINDOW_SECONDS: typeof envelope.TS_WINDOW_SECONDS;
export const hmacHex: typeof envelope.hmacHex;
export const algOf: typeof envelope.algOf;
export const algOfKey: typeof envelope.algOfKey;
export const canonicalizeEnvelope: typeof envelope.canonicalize;
export const signEnvelope: typeof envelope.sign;
export const signEnvelopeHeader: typeof envelope.signHeader;
export const parseEnvelopeHeader: typeof envelope.parseHeader;
export const verifyEnvelope: typeof envelope.verify;
export const tsFresh: typeof envelope.tsFresh;

export const skillCanonical: typeof skill.canonical;
export const skillSigValid: typeof skill.sigValid;
export const revocationCanonical: typeof skill.revocationCanonical;
export const revocationSigValid: typeof skill.revocationSigValid;
export const skillPublishDecision: typeof skill.publishDecision;
export const compareSkillVersion: typeof skill.compareVersion;

export const endorsementCanonical: typeof endorsement.canonical;
export const endorsementSigValid: typeof endorsement.sigValid;
export const endorsementRevocationCanonical: typeof endorsement.revocationCanonical;
export const endorsementRevocationSigValid: typeof endorsement.revocationSigValid;
export const endorsementAccept: typeof endorsement.accept;

export const contributionCanonical: typeof contribution.canonical;
export const contributionLogBytes: typeof contribution.logBytes;
export const contributionLeafHashOf: typeof contribution.leafHashOf;
export const contributionKeyOf: typeof contribution.keyOf;
export const contributionSigValid: typeof contribution.sigValid;
export const contributionVerify: typeof contribution.verify;

export const roomRoleCanonical: typeof roomRole.canonical;
export const roomRoleLogBytes: typeof roomRole.logBytes;
export const roomRoleLeafHashOf: typeof roomRole.leafHashOf;
export const roomRoleKeyOf: typeof roomRole.keyOf;
export const roomRoleSigValid: typeof roomRole.sigValid;
export const roomRoleVerify: typeof roomRole.verify;
export const roomRoleGrantDecision: typeof roomRole.grantDecision;
export const roomRoleOf: typeof roomRole.roleOf;

export const logEmptyRoot: typeof log.emptyRoot;
export const logLeafHashOf: typeof log.leafHashOf;
export const logChainHash: typeof log.chainHash;
export const logRootAt: typeof log.rootAt;
export const logInclusionProof: typeof log.inclusionProof;
export const logVerifyInclusion: typeof log.verifyInclusion;
export const logVerifyInclusionByHash: typeof log.verifyInclusionByHash;
export const logConsistencyProof: typeof log.consistencyProof;
export const logVerifyConsistency: typeof log.verifyConsistency;
export const verifyChain: typeof log.verifyChain;

export const rotationCanonical: typeof rotation.canonical;
export const rotationSigValid: typeof rotation.sigValid;
export const rotationLogBytes: typeof rotation.logBytes;
export const rotationLeafHashOf: typeof rotation.leafHashOf;
export const rotationKeyOf: typeof rotation.keyOf;
export const rotationVerify: typeof rotation.verify;
export const ROTATION_MAX_SKEW_MS: typeof rotation.MAX_SKEW_MS;

export const identityKeysOf: typeof alias.identityKeysOf;
export const IDENTITY_KEY_STATUS: typeof alias.STATUS;

export const reportCanonical: typeof report.canonical;
export const reportKeyOf: typeof report.keyOf;
export const reportSigValid: typeof report.sigValid;
export const reportVerify: typeof report.verify;
export const reportIsTerminal: typeof report.isTerminal;
export const reportTransitionDecision: typeof report.transitionDecision;
export const reportAuditRecord: typeof report.auditRecord;
export const reportReporterViewOf: typeof report.reporterViewOf;
export const reportPublicViewOf: typeof report.publicViewOf;
export const REPORT_REASONS: typeof report.REASONS;
export const REPORT_STATES: typeof report.STATES;
export const REPORT_TRANSITIONS: typeof report.TRANSITIONS;
export const REPORT_ACTORS: typeof report.ACTORS;
export const REPORT_MAX_DETAIL_CHARS: typeof report.MAX_DETAIL_CHARS;
