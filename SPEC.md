# ANID Specification

**Agentic Network Identity** — a normative specification for an on-chain agent
identity and reputation layer built as a fork of [ERC-8004](https://eips.ethereum.org/EIPS/eip-8004).

- **Status:** Draft
- **Version:** 0.1.0
- **License:** MIT

This document is the canonical entry point. It states the normative requirements
(RFC-2119 keywords) and links into the per-component specifications under
[`spec/`](spec/). Where this document and a component file appear to conflict, the
more specific component file governs the detail and this document governs the
intent; genuine contradictions are defects to be filed against the repo.

## 1. Conformance

The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**,
**SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL** in this
document are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119)
and [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174) when, and only when, they
appear in all capitals.

An implementation is **ANID-conformant** if it satisfies every MUST/MUST NOT in
this document and in the component specifications it claims to implement. The
Foundry reference implementation under [`contracts/`](contracts/) is the
executable witness that these requirements are mutually consistent and
satisfiable; it is normative for *behaviour* (the invariant tests), informative
for *style*.

## 2. The one idea

ERC-8004 ships three registries: Identity, Reputation, Validation. Identity and
Validation are sound and ANID adopts them. The Reputation registry is an
**open-write public forum**: any address may attach a score to any agent, with no
proof of interaction, no stake, and no identity. The ERC-8004 spec concedes this
is Sybil-wide-open and instructs readers to "filter by trusted reviewers" — that
filtering *is* the entire trust model, left as an exercise to the consumer.

ANID inverts the model:

> ERC-8004 reputation is **open-write, trust-the-reader-to-filter**.
> ANID is **restricted-write, trust-the-writer-because-it-is-verifiable**.

A score delta is causally bound to a verified execution plus its proof. **No
execution proof, no write.** Reputation becomes a ledger of receipts, not
opinions. This eliminates the fake-review and Sybil class *by construction* — not
by after-the-fact filtering — because there is no open submit endpoint to spam.

## 3. Component map

| Registry            | ERC-8004      | ANID                                                          | Spec |
| ------------------- | ------------- | ------------------------------------------------------------ | ---- |
| **Identity**        | keep          | ERC-721 agent IDs; A2A / MCP interop; Nien id conventions    | [01](spec/01-identity.md) |
| **Reputation**      | **replace**   | restricted-write, execution-bound, EMA two-score, decaying   | [02](spec/02-reputation.md) |
| **Engine Registry** | **new**       | the on-chain allowlist of authorized writers, the set `𝒩`    | [03](spec/03-engine-registry.md) |
| **Validation**      | keep (opt.)   | TEE / zk validators; may double as an execution-proof source | [04](spec/04-validation.md) |

Cross-cutting: [05 — Guardian challenge](spec/05-guardian-challenge.md) (optimistic
finality), [06 — Interfaces](spec/06-interfaces.md) (the external seams),
[07 — Threat model](spec/07-threat-model.md), [08 — Glossary](spec/08-glossary.md).

## 4. Scope

This repository specifies the **identity layer only**: Identity, Reputation
(forked), the Engine Registry, and Validation. Two adjacent systems are
deliberately **out of scope** and are referenced only by interface, so ANID stays
a clean, reusable primitive:

- **The policy engine (Nomos).** An "engine" is any contract in the set `𝒩`. What
  it computes and how it decides to write is its own concern. ANID specifies *who
  may write* and *what a write must carry*, not *how the writer made its decision*.
- **Custody (MPC / Ceffu / smart-wallet).** How value actually moves under an
  approval is out of scope. ANID records that an execution was proven; it does not
  settle funds.

Concretely: `𝒩` is an abstract "authorized engine set" exposed through
[`IEngineRegistry`](spec/06-interfaces.md), and an **execution proof** is an
abstract write precondition — an opaque reference plus a declared kind — that the
Reputation registry *records* but does not itself *verify*. Verification is the
engine's job.

## 5. Normative requirements

### 5.1 Identity

- **R-ID-1** An ANID-conformant Identity registry **MUST** adopt the ERC-8004
  Identity model: agent IDs are ERC-721 tokens with an owner.
- **R-ID-2** It **MUST** emit `AgentRegistered(uint256 indexed agentId, address
  indexed owner)` on registration, preserving wire-compatibility with deployed
  `IdentityLite`.
- **R-ID-3** Off-chain records **SHOULD** use the canonical id formats in
  [01](spec/01-identity.md): DID `did:nien:<method>:<lowercase-evm-address>` and
  network id `anid:<chain>:<lowercase-evm-address>`.
- **R-ID-4** Every ANID **SHOULD** be bound by a signed ownership chain to an
  accountable legal entity (the `publisher`); an identity is intended to be costly
  to discard (L0 accountability).

### 5.2 Reputation — the load-bearing invariants

- **R-REP-1 (only-`𝒩` write)** A write to the Reputation registry (`recordOutcome`,
  a.k.a. `giveFeedback`) **MUST** revert unless `msg.sender` is a member of `𝒩` as
  determined by the Engine Registry. There **MUST NOT** be any open, anonymous, or
  star-rating submission path.
- **R-REP-2 (no-proof-no-write)** A write **MUST** carry a non-empty execution
  proof reference and a declared `ProofKind`. A write with a zero/empty proof
  **MUST** revert.
- **R-REP-3 (signed, not monotonic)** A score **MUST** be signed: a negative
  outcome **MUST** be able to lower an agent's `trust` and/or `performance`. A
  reputation that can only increase is a usage counter and **MUST NOT** be
  presented as ANID reputation.
- **R-REP-4 (counterparty independence)** A write whose `counterpartyId` is related
  to `agentId` (self-dealing) **MUST** be rejected or zero-weighted.
- **R-REP-5 (two-score EMA)** Per-agent state **MUST** track a `trust` score and a
  `performance` score, each updated by the exponential-moving-average rule
  `s(t+1) = λ·s(t) + (1−λ)·g(oₜ)` with `λ ∈ (0,1)` and `g(oₜ) ∈ [−1,1]`. See
  [02](spec/02-reputation.md).
- **R-REP-6 (staleness / decay)** Old evidence **MUST** decay; `λ` is the decay
  lever. Reputation **MUST** be refreshable only through continued, proven work.
- **R-REP-7 (value-weighting)** Score movement **SHOULD** scale with real value at
  risk, so that grinding cheap actions does not move the score.
- **R-REP-8 (provenance in reads)** `scoreFor(agentId)` **MUST** be a public view
  and **MUST** expose provenance — at minimum the number of observations `n` and
  the number of `distinctEngines` — so a reader can discount cartels.

### 5.3 Engine Registry (`𝒩`)

- **R-ENG-1** The Engine Registry **MUST** expose `isRegistered(address) → bool`
  used by the Reputation registry to enforce R-REP-1.
- **R-ENG-2** Membership changes (`register` / `deregister`) **MUST** be
  governance-gated (owner or council) and **MUST** emit `EngineRegistered` /
  `EngineDeregistered`.
- **R-ENG-3** Removing an engine from `𝒩` **MUST** immediately revoke its write
  authority on the Reputation registry (live flip).
- **R-ENG-4** v1 governance **MAY** be a curated allowlist; this is intentional and
  closes the client-Sybil attack. An implementation **SHOULD** document its path to
  permissionless onboarding (staking + guardian challenge).

### 5.4 Validation

- **R-VAL-1** An ANID-conformant Validation registry **MUST** adopt the ERC-8004
  Validation hook as-is.
- **R-VAL-2** A registered validator / TEE attestation **MAY** be referenced as an
  execution-proof source for the Reputation registry (proof tier 2).

### 5.5 Guardian challenge (optimistic finality)

- **R-CHL-1** Where a challenge mechanism is implemented, a posted review **MUST
  NOT** be treated as final by external consumers until its challenge window has
  elapsed.
- **R-CHL-2** Challenge resolution **MUST** be rule-based, not discretionary; the
  losing party's stake **MUST** be slashed by rule. The guardian is a *bounded
  challenger*, never a discretionary delete key.

## 6. Wire-compatibility

To let existing Nien deployments migrate onto these contracts without re-plumbing,
ANID-conformant contracts **MUST** preserve the following deployed shapes:

- Verdict encoding `0 = EXECUTE`, `1 = BLOCK`, `2 = ESCALATE`, `3 = AUDIT`.
- `event Approved(bytes32 indexed taskHash, uint256 indexed agentId)`.
- `event AgentRegistered(uint256 indexed agentId, address indexed owner)`.

## 7. What ANID does and does not claim

**Does claim:** every reputation point is backed by a proven execution;
self-review and anonymous-Sybil writes are impossible at the write layer; a fake
rating faces a staked, rule-based challenge before any contract treats it as
final; reputation accrues only through real work and decays without it.

**Does NOT claim:** trustlessness — ANID is a *curated credentialing network*, not
a decentralized one; nor that a high score certifies an agent's reasoning is
correct. ANID never certifies reasoning. See the scope bound in
[07 — Threat model](spec/07-threat-model.md).

## 8. Repository map

```
SPEC.md            this document — normative entry point
spec/              per-component specification (00–08)
contracts/         Foundry reference implementation of the four registries
PLAN.md            working build plan
LICENSE            MIT
```
