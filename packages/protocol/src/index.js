'use strict';

// ============================================================================
// @woldworld/protocol — the wold/1 wire protocol, as a library.
//
// Zero dependencies. Every function here is pure: no I/O, no global state, no
// clock reads (time is passed in). That is on purpose — a protocol library that
// cannot be exhaustively tested is not a protocol library.
//
// The **canonical API is namespaced** (`base58`, `envelope`, `log`, …). The flat
// camelCase names below are stable aliases, kept because the reference relay and
// its cross-language test suite consume them.
//
// Note what is deliberately absent: there is no transfer / redeem / payout
// function, and no persisted balance. See `contribution.js` for why that is a
// structural guarantee rather than a policy statement.
// ============================================================================

const base58 = require('./base58');
const ed25519 = require('./ed25519');
const did = require('./did');
const envelope = require('./envelope');
const skill = require('./skill');
const endorsement = require('./endorsement');
const contribution = require('./contribution');
const roomRole = require('./roomRole');
const log = require('./log');
const rotation = require('./rotation');
const alias = require('./alias');
const report = require('./report');

module.exports = {
  // ---- namespaced (canonical) API ----
  base58,
  ed25519,
  did,
  envelope,
  skill,
  endorsement,
  contribution,
  roomRole,
  log,
  rotation,
  alias,
  report,

  // ---- flat aliases ----
  base58Encode: base58.encode,
  base58Decode: base58.decode,
  ed25519KeyFromBase58: ed25519.keyFromBase58,
  ed25519RawFromKey: ed25519.rawFromKey,
  didFromPubkey: did.fromPubkey,
  isWoldDid: did.isWoldDid,
  pubkeyFromDid: did.toPubkey,

  PROTO: envelope.PROTO,
  LEGACY_PROTO: envelope.LEGACY_PROTO,
  ACCEPTED_PROTOS: envelope.ACCEPTED_PROTOS,
  TS_WINDOW_SECONDS: envelope.TS_WINDOW_SECONDS,
  hmacHex: envelope.hmacHex,
  algOf: envelope.algOf,
  algOfKey: envelope.algOfKey,
  canonicalizeEnvelope: envelope.canonicalize,
  signEnvelope: envelope.sign,
  signEnvelopeHeader: envelope.signHeader,
  parseEnvelopeHeader: envelope.parseHeader,
  verifyEnvelope: envelope.verify,
  tsFresh: envelope.tsFresh,

  skillCanonical: skill.canonical,
  skillSigValid: skill.sigValid,
  revocationCanonical: skill.revocationCanonical,
  revocationSigValid: skill.revocationSigValid,
  skillPublishDecision: skill.publishDecision,
  compareSkillVersion: skill.compareVersion,

  endorsementCanonical: endorsement.canonical,
  endorsementSigValid: endorsement.sigValid,
  endorsementRevocationCanonical: endorsement.revocationCanonical,
  endorsementRevocationSigValid: endorsement.revocationSigValid,
  endorsementAccept: endorsement.accept,

  contributionCanonical: contribution.canonical,
  contributionLogBytes: contribution.logBytes,
  contributionLeafHashOf: contribution.leafHashOf,
  contributionKeyOf: contribution.keyOf,
  contributionSigValid: contribution.sigValid,
  contributionVerify: contribution.verify,

  roomRoleCanonical: roomRole.canonical,
  roomRoleLogBytes: roomRole.logBytes,
  roomRoleLeafHashOf: roomRole.leafHashOf,
  roomRoleKeyOf: roomRole.keyOf,
  roomRoleSigValid: roomRole.sigValid,
  roomRoleVerify: roomRole.verify,
  roomRoleGrantDecision: roomRole.grantDecision,
  roomRoleOf: roomRole.roleOf,

  logEmptyRoot: log.emptyRoot,
  logLeafHashOf: log.leafHashOf,
  logChainHash: log.chainHash,
  logRootAt: log.rootAt,
  logInclusionProof: log.inclusionProof,
  logVerifyInclusion: log.verifyInclusion,
  logVerifyInclusionByHash: log.verifyInclusionByHash,
  logConsistencyProof: log.consistencyProof,
  logVerifyConsistency: log.verifyConsistency,
  verifyChain: log.verifyChain,

  rotationCanonical: rotation.canonical,
  rotationSigValid: rotation.sigValid,
  rotationLogBytes: rotation.logBytes,
  rotationLeafHashOf: rotation.leafHashOf,
  rotationKeyOf: rotation.keyOf,
  rotationVerify: rotation.verify,
  ROTATION_MAX_SKEW_MS: rotation.MAX_SKEW_MS,

  identityKeysOf: alias.identityKeysOf,
  IDENTITY_KEY_STATUS: alias.STATUS,

  // 举报工单（客户端举报入口 + 服务端工单接口）—— 状态机 / 事由白名单 /
  // 转移判定 / 审计记录形状全在包里，Dart 端只是它的镜像。
  reportCanonical: report.canonical,
  reportKeyOf: report.keyOf,
  reportSigValid: report.sigValid,
  reportVerify: report.verify,
  reportIsTerminal: report.isTerminal,
  reportTransitionDecision: report.transitionDecision,
  reportAuditRecord: report.auditRecord,
  reportReporterViewOf: report.reporterViewOf,
  reportPublicViewOf: report.publicViewOf,
  REPORT_REASONS: report.REASONS,
  REPORT_STATES: report.STATES,
  REPORT_TRANSITIONS: report.TRANSITIONS,
  REPORT_ACTORS: report.ACTORS,
  REPORT_MAX_DETAIL_CHARS: report.MAX_DETAIL_CHARS,
  // 工单号格式（`RPT-` + 12 位大写十六进制）—— **协议包里那一份**。
  // Hub 用它做路径参数的 fail-closed 校验（不依赖客户端自觉）。
  REPORT_TICKET_ID_RE: report.TICKET_ID_RE,
};
