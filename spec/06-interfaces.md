# 06 — Interfaces (the external seams)

These interfaces are the seams that keep ANID a clean, reusable layer. They define
exactly **what ANID asks of the outside world** (is this caller an engine?) and
**what an engine must hand ANID** (an execution proof), plus a reference-only stub
documenting what an engine *is* — without pulling the policy engine into scope.

Solidity here is illustrative. The authoritative definitions are the
`contracts/src/interfaces/*.sol` files; this document explains intent.

## 1. `IEngineRegistry` / `IEngineSet` — "is the caller in `𝒩`?"

How the Reputation registry asks the membership question.

```solidity
interface IEngineRegistry {
    function isRegistered(address engine) external view returns (bool);

    function register(address engine) external;     // governance-gated
    function deregister(address engine) external;   // governance-gated

    event EngineRegistered(address indexed engine);
    event EngineDeregistered(address indexed engine);
}
```

The Reputation registry depends only on the **read** side (`isRegistered`); a
deployment that wants to swap governance models can do so behind this interface
without touching the Reputation registry. The minimal read-only view is sometimes
referred to as `IEngineSet` — it is the `isRegistered` half alone. See
[03-engine-registry.md](03-engine-registry.md).

## 2. `ExecutionProof` — opaque to ANID

What an engine hands the Reputation registry on every write. ANID **records** it;
the engine **verifies** it.

```solidity
enum ProofKind {
    SettledOnChain,   // tier 1 — settlement txhash / state effect (strongest)
    TeeAttestation,   // tier 2 — TEE attestation digest
    ZkProof,          // tier 3 — zk proof of execution
    EngineReceipt     // tier 4 — signed engine receipt (weakest)
}

struct ExecutionProof {
    ProofKind kind;   // which tier the engine asserts
    bytes32   ref;    // the reference: txhash | digest | proof id | receipt hash
}
```

- `ref == 0x0` **MUST** revert (no-proof-no-write, R-REP-2).
- ANID does not interpret `ref` beyond non-emptiness; it stores `kind` and `ref` so
  readers can weight by tier. *Verifying* that the `ref` is real is out of scope —
  it is the asserting engine's responsibility.

See the proof-tier table in [02-reputation.md](02-reputation.md).

## 3. `IReputationRegistry` — the fork's surface

```solidity
interface IReputationRegistry {
    function recordOutcome(
        uint256 agentId,
        ExecutionProof calldata proof,
        bytes32 counterpartyId,   // enforced independent of agentId
        int256  scoreDelta,       // signed reward, feeds g(oₜ) ∈ [−1,1]
        bytes32 feedbackCommit,   // keccak of off-chain evidence
        bytes32 policyId          // which engine policy was satisfied / violated
    ) external;                   // onlyRegisteredEngine

    function scoreFor(uint256 agentId)
        external view returns (int256 trust, int256 performance, uint64 n, uint16 distinctEngines);

    event OutcomeRecorded(
        uint256 indexed agentId,
        address indexed engine,
        bytes32 counterpartyId,
        ProofKind proofKind,
        int256  scoreDelta,
        bytes32 policyId
    );
}
```

`recordOutcome` is the only mutating entry point and is `onlyRegisteredEngine`
(queries `IEngineRegistry.isRegistered`). `scoreFor` returns aggregate **plus
provenance** (`n`, `distinctEngines`) so consumers can discount cartels (R-REP-8).

## 4. `IIdentityRegistry` — adopted

```solidity
interface IIdentityRegistry {
    function ownerOf(uint256 agentId) external view returns (address);
    event AgentRegistered(uint256 indexed agentId, address indexed owner);
}
```

ERC-721-shaped; the `AgentRegistered` event is preserved for wire-compatibility
with `IdentityLite`. See [01-identity.md](01-identity.md).

## 5. `INomos` — reference-only stub (NOT implemented here)

This stub documents **what an engine is** and the one event ANID consumers may key
on. **Nomos is not implemented in this repo** — it is the out-of-scope policy
engine. Included only so the seam is legible.

```solidity
// Reference only. The policy engine (an element of 𝒩) is out of scope for ANID.
interface INomos {
    // The sole trigger a custody layer co-signs on; ANID consumers may key on it.
    event Approved(bytes32 indexed taskHash, uint256 indexed agentId);

    // Verdict encoding MUST match deployed NomosLite (wire-compat):
    //   0 = EXECUTE, 1 = BLOCK, 2 = ESCALATE, 3 = AUDIT
    event VerdictEmitted(
        bytes32 indexed taskHash,
        uint256 indexed agentId,
        uint8   verdict,
        bytes32 blockingPrimitive,
        bytes32 traceHash
    );
}
```

- An **engine** evaluates a task, emits a verdict, and on `EXECUTE` emits
  `Approved`. A registered engine is *the natural and only writer* to the Reputation
  registry because it already authorizes and observes the outcome.
- ANID consumers **MAY** key on `Approved(taskHash, agentId)` and on the verdict
  encoding; ANID **MUST** keep both wire-compatible (see [SPEC.md §6](../SPEC.md)).
- Everything else about Nomos — `setPolicy`, `policyHash`, divergence `D(x)`,
  primitives, the factory/clone deployment — is **out of scope**.

## Related

- [02-reputation.md](02-reputation.md) — semantics of the reputation surface above.
- [03-engine-registry.md](03-engine-registry.md) — semantics of `𝒩`.
- [07-threat-model.md](07-threat-model.md) — what these seams do and do not defend.
