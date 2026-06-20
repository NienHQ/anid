// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Execution-proof tiers, strongest first. ANID records which kind an engine
///         asserts; it does NOT verify it (verification is the engine's job).
///         See spec/02-reputation.md §2.
enum ProofKind {
    SettledOnChain, // tier 1 — settlement txhash / state effect (strongest)
    TeeAttestation, // tier 2 — TEE attestation digest
    ZkProof,        // tier 3 — zk proof of execution
    EngineReceipt   // tier 4 — signed engine receipt (weakest)
}

/// @notice The write precondition. Opaque to ANID: `ref` is recorded, not verified.
///         A zero `ref` MUST revert (no-proof-no-write, R-REP-2).
struct ExecutionProof {
    ProofKind kind; // which tier the engine asserts
    bytes32 ref;    // settlement txhash | TEE digest | zk proof id | receipt hash
}

/// @notice One observation's signed rewards, each g(o) ∈ [-1e18, 1e18] (WAD-scaled).
///         Two-score model: `trust` (settlement/counterparty outcome) and
///         `performance` (executed vs blocked/reverted). See spec/02-reputation.md §3.
struct Outcome {
    int256 trustDelta; // g_trust(o) ∈ [-1e18, 1e18]
    int256 perfDelta;  // g_perf(o)  ∈ [-1e18, 1e18]
}

/// @title IReputationRegistry — the ANID fork
/// @notice Restricted-write, execution-bound reputation. A write succeeds iff the
///         caller is in 𝒩 AND supplies a valid execution proof. Scores are the
///         whitepaper EMA two-score: s(t+1) = λ·s(t) + (1−λ)·g(o).
interface IReputationRegistry {
    /// @notice Record one execution-bound outcome for an agent. onlyRegisteredEngine.
    /// @param agentId        The agent whose reputation is updated.
    /// @param proof          Execution proof (kind + non-zero ref).
    /// @param counterpartyId The counterparty; MUST be independent of `agentId`.
    /// @param outcome        Signed trust/performance rewards, each in [-1e18, 1e18].
    /// @param feedbackCommit keccak commitment to off-chain evidence (e.g. Greenfield CID).
    /// @param policyId       Which engine policy was satisfied / violated.
    function recordOutcome(
        uint256 agentId,
        ExecutionProof calldata proof,
        bytes32 counterpartyId,
        Outcome calldata outcome,
        bytes32 feedbackCommit,
        bytes32 policyId
    ) external;

    /// @notice Public, composable read with provenance so consumers can discount cartels.
    /// @return trust           EMA trust score, WAD-scaled, signed in [-1e18, 1e18].
    /// @return performance     EMA performance score, WAD-scaled, signed in [-1e18, 1e18].
    /// @return n               Number of observations recorded.
    /// @return distinctEngines Number of distinct members of 𝒩 that contributed.
    function scoreFor(uint256 agentId)
        external
        view
        returns (int256 trust, int256 performance, uint64 n, uint16 distinctEngines);

    event OutcomeRecorded(
        uint256 indexed agentId,
        address indexed engine,
        bytes32 counterpartyId,
        ProofKind proofKind,
        bytes32 proofRef,
        int256 trustDelta,
        int256 perfDelta,
        bytes32 feedbackCommit,
        bytes32 policyId
    );
}
