/**
 * Canonical off-chain ANID record model and shared enums, mirrored from
 * spec/01-identity.md (the `AnidRecord` field set) and spec/02-reputation.md.
 */

/** Execution-proof tiers, strongest first. Matches the on-chain ProofKind enum. */
export enum ProofKind {
  SettledOnChain = 0, // tier 1 — settlement txhash / state effect (strongest)
  TeeAttestation = 1, // tier 2 — TEE attestation digest
  ZkProof = 2, // tier 3 — zk proof of execution
  EngineReceipt = 3, // tier 4 — signed engine receipt (weakest)
}

export type AnidKind = "first-party" | "ecosystem";
export type AnidStatus = "active" | "sandbox" | "pending" | "revoked";
export type AnidTier = "tight" | "standard" | "trusted";

/** Public reputation read with provenance (from `scoreFor`). */
export interface Score {
  /** EMA trust score, WAD-scaled, signed in [-1e18, 1e18]. */
  trust: bigint;
  /** EMA performance score, WAD-scaled, signed in [-1e18, 1e18]. */
  performance: bigint;
  /** Number of observations recorded. */
  n: number;
  /** Number of distinct engines (members of 𝒩) that contributed. */
  distinctEngines: number;
  /** `trust` as a float in [-1, 1] (convenience). */
  trustFloat: number;
  /** `performance` as a float in [-1, 1] (convenience). */
  performanceFloat: number;
}

/** Opt-in L1 runtime attestation (TEE measurement + vendor-signed quote). */
export interface Attestation {
  vendor: "Intel TDX" | "AMD SEV-SNP" | "AWS Nitro" | "NVIDIA CC";
  measurement: string;
  verifiedAt: number;
}

/** The canonical off-chain identity dossier (see spec/01-identity.md §"record model"). */
export interface AnidRecord {
  /** Network id, e.g. "anid:bnb:0x9a3f…". */
  id: string;
  /** DID, e.g. "did:nien:zk:0x…". */
  did: string;
  /** Uncompressed secp256k1 public key, 0x04…. */
  pubkey: string;
  name: string;
  /** The accountable legal entity (L0). */
  publisher: string;
  kind: AnidKind;
  /** Granted capability scopes (MCP tools / API verbs). */
  capabilities: string[];
  /** What the agent is allowed to want — the intent manifest (L2). */
  intentManifest: string[];
  attested: boolean;
  attestation?: Attestation;
  /** Execution-bound trust score, float in [-1, 1]. */
  trust: number;
  /** Execution-bound performance score, float in [-1, 1]. */
  performance: number;
  /** Number of verdicts this identity has accrued reputation from (= Score.n). */
  verifiedExecutions: number;
  tier: AnidTier;
  status: AnidStatus;
  registeredAt: number;
  /** On-chain EVM address bound to this identity's keypair (the anchor subject). */
  address: string;
}
