/**
 * anid-sdk — TypeScript SDK for the ANID registries (ethers v6).
 *
 * Typed contract bindings under `./typechain` are generated from the Foundry ABIs
 * (`pnpm generate`). High-level helpers:
 *   - AnidReader   — read scores / ownership / engine membership
 *   - EngineClient — engine-side reputation writes (recordOutcome)
 *   - AdminClient  — manage 𝒩 + register identities
 *   - id helpers   — anid: / did:nien: encoding
 */

export {AnidReader} from "./reader";
export {EngineClient, AdminClient} from "./writer";
export type {RecordOutcomeParams} from "./writer";

export {
  ProofKind,
} from "./record";
export type {
  AnidRecord,
  Attestation,
  Score,
  AnidKind,
  AnidStatus,
  AnidTier,
} from "./record";

export {WAD, toWad, fromWad} from "./fixed";
export {toAnid, toDid, parseAnid, parseDid, agentIdToBytes32} from "./ids";
export type {ParsedAnid, ParsedDid} from "./ids";

export {CHAIN_IDS, DEPLOYMENTS} from "./addresses";
export type {AnidAddresses} from "./addresses";

// Generated typed contract bindings + factories.
export * from "./typechain";
