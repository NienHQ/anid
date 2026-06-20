# ANID — Public Spec + Reference Contracts Repo

## Context

ANID (**Agentic Network Identity**) is Nien's agent identity + reputation layer: an
**ERC-8004 fork** that keeps the Identity and Validation registries verbatim, **replaces** the
open-write Reputation registry with a restricted-write, execution-bound one, and **adds** an Engine
Registry (the on-chain allowlist of authorized writers, the set `𝒩`).

The design already exists but is scattered and inconsistent across `~/org/nien/` (org docs +
whitepaper §5), `~/nien/docs/nomos/` + `~/nien/contracts/` (v1 spec + `NomosLite`/`IdentityLite` on
BNB testnet), and `~/nien-zk/lib/anid/` (the working Beta implementation). Two genuine
contradictions live in those sources (reputation: Beta vs EMA; divergence: weighted-sum vs cosine).

**Goal:** stand up a new, standalone, **public** repo at `~/anid` that is the single authoritative
ANID standard — a normative spec **plus** a Foundry reference implementation of the four registries —
so ANID becomes a reusable primitive independent of the rest of the Nien stack. This is a
brainstorm-then-build effort; the user oversees every file and every change.

### Decisions locked (from clarifying questions)
- **Deliverable:** normative spec **+** Foundry Solidity reference contracts (spec is canonical;
  contracts prove it compiles and the invariants hold under test).
- **Scope:** **identity layer only** — Identity, Reputation (forked), Engine Registry, Validation.
  Nomos (policy engine) and custody (MPC/Ceffu/smart-wallet) are **out**, referenced only by
  interface: `𝒩` is an abstract "authorized engine set," and "execution proof" is an abstract write
  precondition. ANID stays a clean, reusable primitive.
- **Math reconciliation → match the whitepaper:** reputation is the **EMA two-score** model
  (`trust` + `performance`, each `s(t+1)=λ·s(t)+(1−λ)·g(oₜ)`, `λ∈(0,1)`, `g∈[−1,1]`). Cosine
  divergence is the other whitepaper choice but it lives in **Nomos**, so it is *out of scope* here —
  the spec only references it as an external engine concern. The older Beta model and weighted-sum
  divergence in the org docs are explicitly superseded.
- **Repo:** `~/anid`, repo name `anid`. **License:** **MIT** across the whole repo.
- **Authorship:** repo is public — **no "authored by Claude" / Co-Authored-By trailers** anywhere
  (commits, files, PRs). No AI-attribution. Plain authorship only.

### Authoritative source material (to cite/port, not re-derive)
- `~/org/nien/anid-reputation-registry.org` — the reputation fork, write-precondition tiers, guardian
  challenge, Engine Registry, the `recordOutcome` / `scoreFor` Solidity shape.
- `~/org/nien/agentic-id.org` — the L0–L5 identity stack and the scope bound ("honesty bound").
- `~/org/nien/wp-build/nien-whitepaper.typ` §5 — canonical prose; the EMA two-score model; the
  `msg.sender ∈ 𝒩` write invariant.
- `~/org/nien/docs/introduction/key-terms.mdx` — the canonical glossary.
- `~/nien/docs/nomos/04-contracts.md` — the `EngineRegistry` / factory / `INomos` interface sketch.
- `~/nien/contracts/src/{NomosLite,IdentityLite}.sol` — existing minimal contracts + event shapes to
  stay wire-compatible with (verdict encoding, `Approved`, `AgentRegistered`).
- `~/nien-zk/lib/anid/types.ts` — the `AnidRecord` schema (DID/ANID id formats, tiers, statuses,
  trust/performance fields) to mirror as the canonical record model.
- ERC-8004 itself (Identity + Validation registries we adopt as-is).

---

## Repo structure

```
~/anid/
  README.md                 # what ANID is, the one-paragraph pitch, repo map, quickstart
  SPEC.md                   # canonical normative spec (RFC-2119 MUST/SHOULD), links into spec/
  LICENSE                   # MIT
  .gitignore                # foundry: out/, cache/, broadcast/ (keep deployed json), node_modules
  spec/
    00-overview.md          # ERC-8004 fork thesis; component map (keep/replace/add); trust model
    01-identity.md          # Identity registry (adopted); DID/ANID id formats; L0 accountability
    02-reputation.md        # the fork: restricted-write, execution-bound; EMA two-score; reads
    03-engine-registry.md   # 𝒩 = authorized writer set; onboarding gate; path to permissionless
    04-validation.md        # Validation registry (adopted); attestation as execution-proof tier
    05-guardian-challenge.md# optimistic finality: challenge window + rule-based slashing
    06-interfaces.md        # the external seams: IEngineSet, ExecutionProof, INomos (reference only)
    07-threat-model.md      # Sybil/wash/self-deal/fake-client; what's claimed vs NOT claimed
    08-glossary.md          # ported & deduped from key-terms.mdx
  contracts/                # Foundry project (solidity ^0.8.24, OZ remap, BNB testnet chain 97)
    foundry.toml
    src/
      interfaces/
        IIdentityRegistry.sol
        IReputationRegistry.sol   # recordOutcome(...) onlyRegisteredEngine; scoreFor(...)
        IEngineRegistry.sol       # isRegistered(addr) -> bool; add/remove governance
        IValidationRegistry.sol
      IdentityRegistry.sol        # ERC-721 agent IDs (adopt 8004 shape); supersedes IdentityLite
      ReputationRegistry.sol      # the fork — write-gated to 𝒩, execution-bound, EMA two-score
      EngineRegistry.sol          # the allowlist 𝒩 + council/owner governance
      ValidationRegistry.sol      # 8004-as-is hook
    test/
      ReputationRegistry.t.sol    # invariant tests: only-𝒩 writes; no-proof-no-write; signed score
      EngineRegistry.t.sol
      IdentityRegistry.t.sol
    script/
      Deploy.s.sol                # deploy the 4 registries to BNB testnet (chain 97)
  sdk/                            # (later phase) TS reader/writer over the registries
```

---

## Spec content (the substance to write)

### `spec/00-overview.md` — the fork thesis
- The one idea (quote-port from `anid-reputation-registry.org`): *8004 reputation is open-write,
  trust-the-reader-to-filter; ANID is restricted-write, trust-the-writer-because-it-is-verifiable.*
- Component map table: Identity **keep** · Reputation **replace** · Validation **keep (opt.)** ·
  Engine Registry **new**.
- Trust model stated plainly: **not trustless** — a curated credentialing network. The chain buys
  composability/portability/attribution/tamper-evidence, not decentralization.

### `spec/01-identity.md` — adopted, with Nien conventions
- Adopt ERC-8004 Identity (ERC-721 agent IDs, A2A/MCP interop) verbatim.
- Pin the canonical id formats (from `lib/anid/types.ts` / `keygen`):
  - DID: `did:nien:<method>:<lowercase-evm-address>`
  - ANID network id: `anid:<chain>:<lowercase-evm-address>`
  - pubkey: uncompressed secp256k1 `0x04…`
- L0 accountability: every ANID bound by a signed ownership chain to an accountable legal entity
  (the `publisher`); "an identity must be costly to discard."
- Mirror the `AnidRecord` field set as the canonical off-chain record model.

### `spec/02-reputation.md` — the core of the repo
- **Write rule (the load-bearing invariant):** `recordOutcome(...)` (a.k.a. `giveFeedback`) succeeds
  **iff** `msg.sender ∈ 𝒩` **and** a valid execution proof is supplied. No open submit, no anonymous
  writers, no raw star ratings.
- **Execution-proof tiers** (strongest first): on-chain settled effect → TEE attestation digest →
  zk proof → signed engine receipt. The proof is an opaque `bytes32` + a `ProofKind` enum here;
  *verifying* it is the engine's job (out of scope), the registry records which kind was asserted.
- **The score = whitepaper EMA two-score:**
  - `trust` ∈ [0,1] — settlement history + counterparty outcomes.
  - `performance` ∈ [0,1] — share of submitted tasks actually executed.
  - update `s(t+1)=λ·s(t)+(1−λ)·g(oₜ)`, `λ∈(0,1)`, `g(oₜ)∈[−1,1]`.
  - Non-negotiable properties carried over: **signed not monotonic**, **staleness/decay**
    (`λ` is the decay lever), **counterparty-independence** (self-deal rejected/zero-weighted),
    **value-weighting**.
  - Note the supersession explicitly: the org-doc Beta model `R=(α+1)/(α+β+2)` is the historical
    formulation; this spec canonicalizes the EMA two-score.
- **Reads:** public + composable. `scoreFor(agentId) → (trust, performance, n, distinctEngines)`;
  attribution (which/how many engines) is part of the read so consumers discount cartels.

### `spec/03-engine-registry.md` — `𝒩`
- On-chain allowlist of authorized writer contracts; the onboarding chokepoint that exports Nien's
  trust graph to external readers.
- Governance: owner / "Nien Identity Council" can add/remove; **v1 is curated, not permissionless,
  by design** (closes client-Sybil).
- Path to permissionless: replace manual vetting with staking + the guardian-challenge mechanism.

### `spec/04-validation.md`
- Adopt ERC-8004 Validation as-is; a registered validator/TEE attestation can double as an
  execution-proof source for the Reputation registry (tier 2).

### `spec/05-guardian-challenge.md` — optimistic finality
- A review posts but is **not trusted-final** until a challenge window elapses.
- Anyone may challenge by staking; resolution is **rule-based**; loser's stake is slashed. The
  guardian is *a bounded challenger, not a discretionary delete key.*
- External consumers act only on reviews that survived the window.
- v1: Nien monitor is the primary challenger during bootstrap.

### `spec/06-interfaces.md` — the external seams (keeps ANID a clean layer)
- `IEngineSet` / `IEngineRegistry.isRegistered(addr)` — how the Reputation registry asks "is the
  caller in `𝒩`."
- `ExecutionProof { ProofKind kind; bytes32 ref; }` — opaque to ANID; engine asserts, registry
  records.
- `INomos` (reference-only stub, ported from `04-contracts.md`): documents what an engine is and
  the `Approved(taskHash, agentId)` event ANID consumers may key on — but Nomos is **not**
  implemented in this repo.

### `spec/07-threat-model.md`
- Attacks closed by construction: open-write Sybil, anonymous fake reviews, wash/grind (value-
  weighting + decay), self-dealing (counterparty independence), fake-client minting (Engine Registry
  onboarding + guardian challenge).
- **Do claim / do NOT claim** lists ported verbatim from `anid-reputation-registry.org` (notably:
  not trustless; never certifies reasoning correctness — the scope bound).

---

## Reference contracts (what they must prove)

Stay **wire-compatible** with the existing deployed shapes so `nien-zk` can migrate onto these
without re-plumbing: keep verdict encoding `0=EXECUTE,1=BLOCK,2=ESCALATE,3=AUDIT`, the
`Approved(taskHash, agentId)` event, and `AgentRegistered(agentId, owner)`.

- **`EngineRegistry.sol`** — `mapping(address => bool) isRegistered`; owner-gated `register` /
  `deregister`; `EngineRegistered` / `EngineDeregistered` events.
- **`ReputationRegistry.sol`** — the fork. `recordOutcome(agentId, proof, counterpartyId,
  scoreDelta…, feedbackCommit, policyId)` guarded by `onlyRegisteredEngine` (queries
  `EngineRegistry`); stores per-agent `trust`/`performance` (fixed-point, e.g. 1e18 scale), `n`,
  `distinctEngines`; rejects `counterpartyId` related to `agentId`; `scoreFor` view.
- **`IdentityRegistry.sol`** — adopt the ERC-8004 Identity (ERC-721) shape; supersede the minimal
  `IdentityLite` (keep its `AgentRegistered` event for compatibility).
- **`ValidationRegistry.sol`** — 8004 hook, minimal.
- **`Deploy.s.sol`** — deploy all four to BNB testnet (chain 97), wire `ReputationRegistry` →
  `EngineRegistry`.

### Key invariant tests (the contracts *are* the spec's proof)
- `recordOutcome` reverts when `msg.sender ∉ 𝒩` (only-engine write).
- `recordOutcome` reverts with no/zero execution proof (no-proof-no-write).
- score is **signed** — a negative `scoreDelta` lowers `trust`/`performance` (not monotonic).
- self-dealing: `counterpartyId == agentId`'s owner-related id is rejected or zero-weighted.
- `EngineRegistry` add/remove flips write authority live.

---

## Build phases (incremental; user reviews each)

1. **Scaffold** — `~/anid` with `git init`, MIT `LICENSE`, `README.md`, `.gitignore`, empty
   `spec/` + Foundry `contracts/` skeleton (`forge init`-style, OZ remap). Configure git so commits
   carry **no Claude attribution**. *No first commit until the user okays the tree.*
2. **Spec text** — write `SPEC.md` + `spec/00…08`, porting/deduping from the source docs and
   resolving the two reconciliations the chosen way (EMA two-score; divergence noted as external).
3. **Interfaces** — `src/interfaces/*.sol` matching the spec's `06-interfaces.md`.
4. **Contracts** — `EngineRegistry` → `ReputationRegistry` → `IdentityRegistry` → `ValidationRegistry`.
5. **Tests** — the invariant suite above; `forge test` green.
6. **Deploy script** — `Deploy.s.sol` for BNB testnet (chain 97), reusing the existing RPC/explorer
   config pattern from `~/nien/contracts`.
7. **(Later) SDK** — TS reader/writer in `sdk/`, lifted/hardened from `~/nien-zk/lib/anid`.

---

## Verification

- **Contracts compile & invariants hold:** `cd ~/anid/contracts && forge build && forge test -vvv`
  — all invariant tests green (only-𝒩 write, no-proof-no-write, signed score, self-deal rejection,
  live registry flip).
- **Deploy dry-run:** `forge script script/Deploy.s.sol --rpc-url <bsc-testnet> --sender …`
  simulates cleanly; optional broadcast to chain 97 and confirm on `testnet.bscscan.com`.
- **Spec coherence:** `SPEC.md` cross-links resolve; the component map, the `msg.sender ∈ 𝒩`
  invariant, and the EMA two-score appear identically in spec text and contract behavior (no drift
  between `02-reputation.md` and `ReputationRegistry.sol`).
- **Public-safety check:** `git log` and a repo-wide grep show **no** Claude/Co-Authored-By/AI
  attribution anywhere before anything is pushed.
- **Wire-compatibility:** event signatures (`Approved`, `AgentRegistered`, verdict encoding) match
  the existing `NomosLite`/`IdentityLite` so `nien-zk` can point at the new contracts unchanged.
