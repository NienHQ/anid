# 02 — Reputation (the fork)

This is the core of ANID. It **replaces** the ERC-8004 open-write Reputation
registry with a **restricted-write, execution-bound** one. Everything here exists
to make one sentence true on-chain:

> A reputation write succeeds **iff** the writer is an authorized engine **and** it
> supplies a valid execution proof.

## 1. The write rule (the load-bearing invariant)

`recordOutcome(...)` (a.k.a. `giveFeedback`) succeeds **iff both** hold:

1. `msg.sender ∈ 𝒩` — the caller is a registered engine, checked against the
   [Engine Registry](03-engine-registry.md) via `isRegistered(msg.sender)`; **and**
2. a valid **execution proof** is supplied (non-empty `ref`, declared `ProofKind`).

There is **no** open `submitFeedback`, **no** anonymous writers, and **no** raw
star ratings. The ERC-8004 attack surface is gone by construction — there is simply
no endpoint to spam. (Normative: R-REP-1, R-REP-2 in [SPEC.md](../SPEC.md).)

## 2. Execution proof (the write precondition)

A write **MUST** carry an `ExecutionProof { ProofKind kind; bytes32 ref; }`. ANID
records *which kind was asserted* and *the reference*; it does **not** verify the
proof — verification is the engine's job and is out of scope (see
[06-interfaces.md](06-interfaces.md)). Accepted forms, **strongest first**:

| Rank | Proof                                   | Binds to                              |
| ---- | --------------------------------------- | ------------------------------------- |
| 1    | on-chain settled effect (txhash/state)  | the chain itself attests it           |
| 2    | TEE attestation digest (Phala/Marlin)   | L1 execution attestation              |
| 3    | zk proof of execution                   | cryptographic, no trusted party       |
| 4    | signed engine receipt                   | weakest; trust the engine             |

Most agent actions settle on-chain (a trade, a transfer, an escrow release), so the
proof is frequently the **settlement transaction itself** — the cheapest and
strongest form. The settlement tx hash *is* the execution proof written to ANID.

`ProofKind` is an enum; tier 1 is the strongest. A `ref` of `0x0` (empty) **MUST**
revert (no-proof-no-write). Readers **MAY** weight or filter by `ProofKind` — a
score backed by tier-1 settlement proofs is stronger than one backed by tier-4
receipts.

## 3. The score — EMA two-score (matches the whitepaper)

ANID maintains **two** public scores per agent, written exclusively by engines that
have actually evaluated and settled a task:

- **`trust`** ∈ [0,1] — derived from settlement history and counterparty outcomes.
- **`performance`** ∈ [0,1] — the share of an agent's submitted tasks actually
  executed by the engines it faces, aggregated across all its deployed instances.

Both are non-forgeable because only an engine that evaluated and settled a task may
write them.

### Update rule

Let `s_a(t)` be agent `a`'s score (either `trust` or `performance`) at step `t`,
and let `g(oₜ) ∈ [−1, 1]` be a structured map from outcome `oₜ` to a signed reward
(a settled, undisputed payment scores positive; a blocked or reverted task scores
negative). Then:

```
s_a(t+1) = λ · s_a(t) + (1 − λ) · g(oₜ),    λ ∈ (0, 1)
```

The half-life parameter `λ` controls how heavily history weighs against recent
behaviour. (Normative: R-REP-5.)

### On-chain representation

Scores are stored as **fixed-point** integers (e.g. `1e18` scale) so the EMA can be
computed with integer math. The mapping `g(·)` and the precise fixed-point rounding
are implementation detail of the engine + registry; the registry's job is to apply
the EMA atomically and emit the resulting state.

### Non-negotiable properties

- **Signed, not monotonic.** A policy violation or realized loss pushes a score
  *down*. A rating that only goes up is a usage counter, and usage is
  wash-farmable. (R-REP-3.)
- **Staleness / decay.** `λ` decays old evidence; reputation must be kept fresh
  through continued ecosystem work. This is also a deliberate retention lever, not
  only data hygiene. (R-REP-6.)
- **Counterparty independence.** A write whose `counterpartyId` is related to
  `agentId` is rejected or zero-weighted, to stop self-dealing volume. (R-REP-4.)
- **Value-weighting.** Score movement scales with real capital at risk, so grinding
  cheap actions does not move it. (R-REP-7.)

### Supersession (historical note)

Earlier Nien drafts specified a **time-decayed Beta** reputation
`R_a = (α+1)/(α+β+2)` with `α ← ρα + 1[compliant]`, `β ← ρβ + 1[violation]`. That
Beta formulation is the **historical** model. This spec **canonicalizes the EMA
two-score** above to match the whitepaper. The Beta model and the org-doc
weighted-sum divergence are explicitly **superseded** here.

A second whitepaper choice — **cosine intent-divergence** `D(x)` — is *not* a
reputation construct: it lives in the policy engine (Nomos) and is **out of scope**
for ANID. ANID references it only as an external engine concern; the engine may use
divergence to decide whether to write, but the registry neither computes nor stores
it.

## 4. Reads — public and composable

The reason to be on-chain at all (rather than in a database) is composability:
external contracts can gate on a score directly.

```solidity
// Public, composable. Returns aggregate plus provenance.
function scoreFor(uint256 agentId)
    external view returns (int256 trust, int256 performance, uint64 n, uint16 distinctEngines);
```

- `scoreFor` is a public view (R-REP-8).
- **Attribution is part of the read.** A consumer can see *how many* engines wrote
  a score and the distribution behind it (one engine vs forty). A score with no
  provenance is gameable; with provenance the reader discounts cartels itself.
- `n` is the number of observations; `distinctEngines` is how many distinct members
  of `𝒩` contributed. Value, value-decimals, tags, and evidence commitments are
  also public on-chain where stored.

## 5. The write/read surface

```solidity
// Only a registered engine may write. Every write is execution-bound.
function recordOutcome(
    uint256 agentId,
    bytes32 executionProof,   // settled txhash | TEE digest | zk proof id  (ref)
    bytes32 counterpartyId,   // enforced independent of agentId
    int256  scoreDelta,       // signed: rewards AND penalties (feeds g(oₜ))
    bytes32 feedbackCommit,   // keccak of off-chain evidence (e.g. Greenfield CID)
    bytes32 policyId          // which engine policy was satisfied / violated
) external onlyRegisteredEngine;
```

What is **absent** is the point: no open `submitFeedback`, no anonymous writers, no
raw star ratings. See the full interface in [06-interfaces.md](06-interfaces.md) and
the invariant tests under [`contracts/test/`](../contracts/) that hold this section
to its word.

## Related

- [03-engine-registry.md](03-engine-registry.md) — `𝒩`, the writer set this rule
  checks against.
- [05-guardian-challenge.md](05-guardian-challenge.md) — why a fresh write is not
  yet trusted-final.
- [07-threat-model.md](07-threat-model.md) — the attack classes this design closes.
