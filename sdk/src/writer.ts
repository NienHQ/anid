import {ZeroHash} from "ethers";
import type {BigNumberish, ContractTransactionResponse, Signer} from "ethers";
import {
  EngineRegistry,
  EngineRegistry__factory,
  IdentityRegistry,
  IdentityRegistry__factory,
  ReputationRegistry,
  ReputationRegistry__factory,
} from "./typechain";
import type {AnidAddresses} from "./addresses";
import {ProofKind} from "./record";
import {toWad} from "./fixed";

/** Parameters for an execution-bound reputation write. */
export interface RecordOutcomeParams {
  /** The agent whose reputation is updated. */
  agentId: BigNumberish;
  /** Execution proof: tier + a non-zero reference (txhash | digest | proof id). */
  proof: {kind: ProofKind; ref: string};
  /** Counterparty id (bytes32); MUST be independent of `agentId`. */
  counterpartyId: string;
  /** Signed trust reward in [-1, 1] (settlement / counterparty outcome). */
  trust: number;
  /** Signed performance reward in [-1, 1] (executed vs blocked/reverted). */
  performance: number;
  /** keccak commitment to off-chain evidence (bytes32). Defaults to zero. */
  feedbackCommit?: string;
  /** Which engine policy was satisfied/violated (bytes32). Defaults to zero. */
  policyId?: string;
}

/**
 * Engine-side writer. Only an address in 𝒩 can successfully call `recordOutcome`;
 * the registry enforces only-𝒩, no-proof-no-write, signed bounds, and counterparty
 * independence. Construct with a `Signer` whose address is the registered engine.
 */
export class EngineClient {
  readonly reputation: ReputationRegistry;

  constructor(addresses: AnidAddresses, signer: Signer) {
    this.reputation = ReputationRegistry__factory.connect(addresses.reputation, signer);
  }

  /** Record one execution-bound outcome. Throws (reverts) if preconditions fail. */
  recordOutcome(p: RecordOutcomeParams): Promise<ContractTransactionResponse> {
    if (p.proof.ref === ZeroHash || /^0x0{64}$/.test(p.proof.ref)) {
      throw new Error("execution proof ref must be non-zero (no-proof-no-write)");
    }
    return this.reputation.recordOutcome(
      p.agentId,
      {kind: p.proof.kind, ref: p.proof.ref},
      p.counterpartyId,
      {trustDelta: toWad(p.trust), perfDelta: toWad(p.performance)},
      p.feedbackCommit ?? ZeroHash,
      p.policyId ?? ZeroHash,
    );
  }
}

/**
 * Governance-side client: manage the engine set 𝒩 and register agent identities.
 * `register`/`deregister` require the EngineRegistry owner; `registerAgent` is open.
 */
export class AdminClient {
  readonly engine: EngineRegistry;
  readonly identity: IdentityRegistry;

  constructor(addresses: AnidAddresses, signer: Signer) {
    this.engine = EngineRegistry__factory.connect(addresses.engine, signer);
    this.identity = IdentityRegistry__factory.connect(addresses.identity, signer);
  }

  /** Add an engine to 𝒩 (owner only). */
  registerEngine(engine: string): Promise<ContractTransactionResponse> {
    return this.engine.register(engine);
  }

  /** Remove an engine from 𝒩 (owner only). Revokes write authority live. */
  deregisterEngine(engine: string): Promise<ContractTransactionResponse> {
    return this.engine.deregister(engine);
  }

  /** Register (mint) an agent id to an owner. */
  registerAgent(agentId: BigNumberish, owner: string): Promise<ContractTransactionResponse> {
    return this.identity.register(agentId, owner);
  }
}
