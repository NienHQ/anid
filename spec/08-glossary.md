# 08 — Glossary

The canonical ANID vocabulary, deduped from the Nien key-terms reference and scoped
to this repo. The lifecycle these terms sit in is **Task → Evaluation → Approval →
Settlement**, with one structural property: the deciding authority is an on-chain
contract the enterprise owns, evaluating deterministically with no LLM in the loop.

Terms specific to the out-of-scope policy engine (Nomos) and custody are included
only where an ANID reader meets them at a seam; they are marked *(engine)* or
*(custody)* and specified no further here.

## Identity & reputation (ANID core)

| Term | Meaning |
| --- | --- |
| **ANID** | Agentic Network Identity: an agent's on-chain identity + portable reputation, built as an ERC-8004 fork. |
| **agent ID** (`agentId`) | The ERC-721 token id identifying an agent in the Identity registry. |
| **DID** | Decentralized identifier, `did:nien:<method>:<lowercase-evm-address>`. |
| **network id** | ANID id string, `anid:<chain>:<lowercase-evm-address>`. |
| **publisher** | The accountable legal entity bound to an ANID (L0). "An identity must be costly to discard." |
| **trust score** | Reputation in [0,1] derived from settlement history and counterparty outcomes; EMA-updated, signed, decaying. |
| **performance score** | Reputation in [0,1]: the share of an agent's submitted tasks actually executed by the engines it faces. |
| **`n`** | Number of observations (outcomes) an agent's reputation aggregates. |
| **distinctEngines** | Number of distinct members of `𝒩` that contributed to a score — read-side provenance. |
| **engine set** (`𝒩`) | The on-chain set of authorized engine addresses — the only writers permitted to leave reputation feedback. |
| **engine** | A contract in `𝒩`. It authorizes and observes an agent's actions, and is therefore the natural and only reputation writer. |
| **execution proof** | The write precondition: `{ ProofKind kind; bytes32 ref; }`. ANID records it; the engine verifies it. |
| **ProofKind** | The proof tier asserted: settled-on-chain (1) · TEE attestation (2) · zk proof (3) · engine receipt (4). |
| **operating tier** (`tier`) | Reputation-gated band of latitude (`tight`/`standard`/`trusted`) an engine grants; derived from ANID score, not ANID state. |
| **feedbackCommit** | `keccak` commitment to off-chain evidence behind a write (e.g. a Greenfield CID). |
| **guardian** | A *bounded challenger* (not a delete key) that stakes to challenge a posted review; resolution is rule-based. |
| **challenge window** | The period a review must survive before consumers treat it as final (optimistic finality). |

## Task

| Term | Meaning |
| --- | --- |
| **task** (`task`) | The signed package an agent submits to act on funds. Never carries a payment key. |
| **taskHash** | Unique identifier of a task; binds a verdict to the exact action signed. |
| **action** | The concrete operation requested: amount, recipient, category. |
| **intent manifest** (`intent`) | Signed declaration of an agent's purpose, permitted recipients, and amount/time envelope (L2). |

## Evaluation *(engine)*

| Term | Meaning |
| --- | --- |
| **Nomos** *(engine)* | The enterprise-owned, on-chain deterministic policy engine that evaluates every task. An element of `𝒩`. **Out of scope for ANID.** |
| **verdict** *(engine)* | The engine's determination: `EXECUTE` (0), `BLOCK` (1), `ESCALATE` (2), `AUDIT` (3). Encoding is wire-compat (see [SPEC.md §6](../SPEC.md)). |
| **divergence** (`D(x)`) *(engine)* | Intent-divergence score the engine uses to admit a task (`D ≤ τ`). Computed in the engine; **not** stored by ANID. |
| **policy** (`policyId`) *(engine)* | The composed, versioned ruleset an engine evaluates against; referenced by id on a reputation write. |

## Approval *(engine)*

| Term | Meaning |
| --- | --- |
| **Approved event** | `Approved(taskHash, agentId)` — the on-chain event an engine emits on `EXECUTE`; ANID consumers may key on it. Wire-compat. |
| **escalation mode** *(engine)* | Who must approve an escalated task: `HUMAN` or `SUPERIOR_AGENT`. |

## Settlement *(custody)*

| Term | Meaning |
| --- | --- |
| **settlement transaction** (`settlementTx`) | On-chain hash for a settled action; **doubles as the execution proof** written to ANID (ProofKind tier 1). |
| **settlement status** *(custody)* | `UNSETTLED` / `SIGNED` / `SETTLED` / `FAILED`. Custody concern, out of scope. |
| **MPC custody core** *(custody)* | Threshold-signing system that co-signs only on an observed `Approved` event. Out of scope. |
| **audit record** | Persisted, on-chain, tamper-evident artifact of a decision and its trace. |

## Superseded / out-of-scope formulations

| Term | Status |
| --- | --- |
| **Beta reputation** `R=(α+1)/(α+β+2)` | **Superseded** by the EMA two-score. Historical; see [02 §3](02-reputation.md). |
| **weighted-sum divergence** | **Superseded** by cosine divergence — which itself lives in the engine, **out of scope** here. |
| **cosine divergence** | An *engine* construct; referenced only, never computed or stored by ANID. |

## Related

- [01-identity.md](01-identity.md) · [02-reputation.md](02-reputation.md) ·
  [03-engine-registry.md](03-engine-registry.md) ·
  [06-interfaces.md](06-interfaces.md)
