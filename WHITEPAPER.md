# ANID: Agentic Network Identity

### An execution-bound reputation layer for autonomous agents, as a fork of ERC-8004

**Nien Labs**
Version 1.0 · June 2026

---

## Abstract

Autonomous agents increasingly hold keys and move value, but the identity systems
built for them authenticate the *key-holder* and authorize a *class of action* —
they say nothing about whether an agent has a track record of behaving well. The
emerging on-chain standard for agent identity, ERC-8004, ships a Reputation
registry that is *open-write*: any address may attach a score to any agent, with no
proof of interaction, no stake, and no identity. The standard concedes this is
Sybil-wide-open and defers the entire trust model to the reader, who is told to
"filter by trusted reviewers."

**ANID (Agentic Network Identity)** is a fork of ERC-8004 that inverts this model.
It keeps the Identity and Validation registries verbatim, **replaces** the Reputation
registry with a *restricted-write, execution-bound* one, and **adds** an Engine
Registry — an on-chain allowlist of authorized writers (the set `𝒩`). The governing
principle is a single sentence enforced on-chain: a reputation write succeeds **if
and only if** the caller is an authorized engine **and** it supplies a valid
execution proof. Reputation becomes a ledger of receipts, not opinions. This
eliminates the fake-review and Sybil class *by construction* rather than by
after-the-fact filtering, because there is no open submit endpoint to spam.

ANID is deliberately scoped to the identity layer. It specifies *who may write* and
*what a write must carry*, not *how the writer decided* — the policy engine and
custody systems are referenced only by interface, keeping ANID a clean, reusable
primitive. This paper describes the full design: the architecture, the
exponential-moving-average two-score reputation model, the execution-proof tiers,
the optimistic-finality guardian challenge, the threat model, and the trust
boundary ANID claims and — just as importantly — the one it does not. It is
accompanied by a normative specification and a Foundry reference implementation of
all four registries, deployed and verified end-to-end on BNB Chain.

---

## 1. Motivation

### 1.1 A key answers only one question

Strong agent identity must answer four questions, where a cryptographic key answers
only the first:

1. **Who is accountable?** — cryptographic identity (the key, and the legal entity behind it).
2. **What is running?** — the model, prompt, tools, and code, untampered.
3. **What is it allowed to want?** — its declared intent and spending envelope.
4. **Is it acting like itself right now?** — runtime governance of each action.

Authentication and authorization cover (1) and a coarse form of (3). They do not
cover behaviour over time. A prompt-injected agent holding a valid key can emit a
cryptographically valid, fully authorized transaction that violates its operator's
intent. Identity that stops at the key cannot distinguish a long-trusted agent from
a freshly minted one with a stolen mandate.

### 1.2 What reputation is supposed to add — and why ERC-8004's doesn't

Reputation is the missing dimension: a portable, public record of how an agent has
actually behaved. ERC-8004 recognizes this and provides a Reputation registry, but
makes it open-write. The consequences are structural, not incidental:

- **Sybil writes.** Any address can submit a score; an attacker mints thousands of
  addresses and inflates its own agent for free.
- **Fake reviews.** A score need not correspond to any real interaction. There is
  no proof that the writer ever transacted with the agent.
- **No attribution that matters.** Even where a writer is identifiable, nothing
  ties the score to a verified outcome, so the identity of the writer buys little.

The standard's answer — "filter by trusted reviewers" — pushes the entire problem
onto every consumer independently, and a consumer with no shared notion of "trusted"
cannot solve it. Open-write reputation is a usage counter wearing the costume of a
trust signal, and usage is wash-farmable.

### 1.3 The inversion

ANID's thesis is one line:

> ERC-8004 reputation is **open-write, trust-the-reader-to-filter**.
> ANID is **restricted-write, trust-the-writer-because-it-is-verifiable**.

A score delta is causally bound to a verified execution plus its proof. No
execution proof, no write. The only parties that may write are contracts that have
*already* authorized and observed an agent's action — they are the natural and only
witnesses to an outcome, and reputation is a side effect of a gate they already run.
The attack surface that ERC-8004 leaves for the reader to filter simply does not
exist at the write layer.

---

## 2. Architecture

ANID is four on-chain registries. Two are adopted from ERC-8004 unchanged, one is
replaced, and one is new.

| Registry            | ERC-8004     | ANID                                                          |
| ------------------- | ------------ | ------------------------------------------------------------ |
| **Identity**        | keep         | ERC-721 agent IDs; A2A / MCP interop; id + L0 conventions    |
| **Reputation**      | **replace**  | restricted-write, execution-bound, EMA two-score, decaying   |
| **Engine Registry** | **new**      | the on-chain allowlist of authorized writers, the set `𝒩`    |
| **Validation**      | keep (opt.)  | TEE / zk validators; may double as an execution-proof source |

The data flow is simple. An agent registers an identity. An engine — a contract
authorized in the Engine Registry — evaluates and settles the agent's task, then
calls the Reputation registry to record the outcome, supplying an execution proof.
The Reputation registry checks engine membership and proof presence, applies the
score update, and emits an event. Any external contract or off-chain reader can
then read the agent's score, together with its provenance, directly from the chain.

```
  Agent ──register──▶ IdentityRegistry (ERC-721 agentId)

  Engine (∈ 𝒩) ──recordOutcome(agentId, proof, …)──▶ ReputationRegistry
                                                          │
                            isRegistered(engine)? ────────┤──▶ EngineRegistry (𝒩)
                            proof present? signed? indep.? │
                                                          ▼
                                              EMA two-score update + event

  Reader ──scoreFor(agentId)──▶ (trust, performance, n, distinctEngines)
```

### 2.1 Scope and seams

ANID is the **identity layer only**. The policy engine that decides *what* to write,
and the custody system that moves value under an approval, are out of scope and are
referenced only through interfaces:

- **`𝒩` (the engine set)** is an abstract "authorized writer set." An engine is any
  contract the Engine Registry has admitted. In the Nien stack these are
  per-enterprise Nomos policy contracts, but ANID specifies nothing about their
  internals.
- **The execution proof** is an abstract write precondition — an opaque reference
  plus a declared kind. ANID *records* it; it does not *verify* it. Verification is
  the engine's responsibility.

This separation is what keeps ANID reusable. Any system that can express "this
contract is an authorized writer" and "here is a reference to a proven execution"
can adopt it.

---

## 3. Identity

ANID adopts the ERC-8004 Identity registry verbatim: agent IDs are ERC-721 tokens
with an owner, inheriting the A2A / MCP interoperability story. On top of this it
pins three conventions.

**Canonical id formats.** Off-chain tooling shares a single encoding:

- DID: `did:nien:<method>:<lowercase-evm-address>`
- Network id: `anid:<chain>:<lowercase-evm-address>`
- Public key: uncompressed secp256k1, `0x04…`

The address component is always lowercased (no checksum casing) so string equality
is canonical.

**L0 accountability.** Every ANID should be bound by a signed ownership chain to an
accountable legal entity, the *publisher*. The entity `E` issues a verifiable
credential `C_a = Sign_{sk_E}(DID_a ‖ scope ‖ expiry)`. This binding makes an
**identity costly to discard**: an agent cannot shed a bad record by minting a fresh
anonymous identity, because a fresh identity carries no accountable publisher and
therefore no standing.

**Wire-compatibility.** The registry emits `AgentRegistered(uint256 indexed agentId,
address indexed owner)` in addition to the ERC-721 `Transfer`, preserving
compatibility with prior minimal deployments so existing consumers migrate without
re-plumbing.

---

## 4. Reputation: the core of the fork

### 4.1 The write rule

The load-bearing invariant of the entire system is the precondition on a reputation
write. `recordOutcome(...)` succeeds **if and only if both** hold:

1. **`msg.sender ∈ 𝒩`** — the caller is a registered engine, checked against the
   Engine Registry on every write; and
2. a **valid execution proof** is supplied — a non-empty reference with a declared
   proof kind.

There is no open `submitFeedback`, no anonymous writer, and no raw star rating. The
ERC-8004 attack surface is gone because there is no endpoint to attack.

### 4.2 Execution proof

Every write carries an `ExecutionProof { ProofKind kind; bytes32 ref }`. ANID
records which kind the engine asserted and the reference value; it does not verify
the reference. The accepted forms, strongest first:

| Tier | Proof                                  | Binds to                            |
| ---- | -------------------------------------- | ----------------------------------- |
| 1    | on-chain settled effect (txhash/state) | the chain itself attests it         |
| 2    | TEE attestation digest                 | hardware-rooted execution attestation |
| 3    | zk proof of execution                  | cryptographic, no trusted party     |
| 4    | signed engine receipt                  | weakest; trust the engine           |

Most agent actions settle on-chain — a trade, a transfer, an escrow release — so the
proof is frequently the settlement transaction itself: the cheapest and strongest
form. A reader may weight or filter by tier; a score backed by tier-1 settlement
proofs is stronger than one backed by tier-4 receipts. A write with an empty
reference reverts (*no-proof-no-write*).

### 4.3 The two-score EMA model

ANID maintains **two** public scores per agent, written exclusively by engines that
have actually evaluated and settled a task:

- **Trust** ∈ [−1, 1] — derived from settlement history and counterparty outcomes.
- **Performance** ∈ [−1, 1] — the share of an agent's submitted tasks actually
  executed by the engines it faces, aggregated across all its deployed instances.

Both are non-forgeable because only an engine that evaluated and settled a task may
write them. Let `s_a(t)` denote agent `a`'s score (either trust or performance) at
step `t`, and let `g(o_t) ∈ [−1, 1]` be a structured map from outcome `o_t` to a
signed reward — a settled, undisputed payment scores positive; a blocked or reverted
task scores negative. The update is an exponential moving average:

```
    s_a(t+1) = λ · s_a(t) + (1 − λ) · g(o_t),     λ ∈ (0, 1)
```

The half-life parameter `λ` controls how heavily history weighs against recent
behaviour. On-chain, scores and rewards are stored as fixed-point integers (WAD,
1e18 scale) so the EMA is computed with integer arithmetic; the reference
deployment uses `λ = 0.9`. Because the update is an on-chain engine emitting a
feedback event, an agent's record is portable across every enterprise it touches,
and no single enterprise can reproduce it.

The two-score model is why a write carries one signed reward *per score*: a single
delta cannot drive two independent EMAs. The reference implementation accepts an
`Outcome { int256 trustDelta; int256 perfDelta }`, each in `[−1e18, 1e18]`.

### 4.4 Non-negotiable properties

The score model is constrained by four properties that defeat the obvious gaming
strategies:

- **Signed, not monotonic.** A violation or realized loss pushes a score down. A
  rating that can only rise is a usage counter, and usage is wash-farmable.
- **Staleness / decay.** `λ < 1` decays old evidence; reputation must be kept fresh
  through continued work. This is also a deliberate retention lever, not only data
  hygiene.
- **Counterparty independence.** A write whose counterparty is related to the agent
  — the same agent, or a different agent under the same owner — is rejected as
  self-dealing.
- **Value-weighting.** Score movement scales with real capital at risk, so grinding
  cheap actions does not move the score.

### 4.5 Reads with provenance

The reason to be on-chain rather than in a database is composability: external
contracts can gate on a score directly.

```
    scoreFor(agentId) → (trust, performance, n, distinctEngines)
```

Crucially, **attribution is part of the read**. A consumer sees not only the
aggregate scores but `n`, the number of observations, and `distinctEngines`, how
many distinct members of `𝒩` contributed. A score concentrated in one engine is
discounted differently from one spread across forty. A score with no provenance is
gameable; with provenance, the reader discounts cartels itself.

---

## 5. The Engine Registry (`𝒩`)

With execution-binding in place, the one remaining attack is *becoming a fake
engine* in order to mint execution-bound ratings for one's own agent. Integrity
therefore reduces to engine onboarding, and the Engine Registry is the chokepoint
where that policy is enforced. It exposes the membership test the Reputation
registry calls on every write:

```
    isRegistered(address engine) → bool
    register(address engine)          // governance-gated
    deregister(address engine)        // governance-gated
```

**Live authority.** Because the Reputation registry queries `isRegistered` on every
write, removing an engine immediately revokes its ability to write — there is no
cached authority and no grace window. Deregistering an engine in one block causes
its next write to revert.

**Governance, today.** v1 is a curated allowlist held by a governance owner (in
production, a Nien Identity Council). This is intentional and not permissionless: a
human vetting of each engine before issuing write authority is precisely what closes
client-Sybil for v1.

**The path to permissionless.** The integrity model does not change on the way to
open onboarding; only the gate does. Manual vetting is replaced by staking plus the
guardian-challenge mechanism (§7): an engine stakes to join `𝒩`, and misbehaviour is
challenged and slashed by rule. The same mechanism, two uses.

---

## 6. Validation

ANID adopts the ERC-8004 Validation registry as-is, and treats it as optional: a
deployment may run Identity + Reputation + Engine Registry without it. Its one
connection to the rest of ANID is that a registered validator or TEE attestation may
double as a **tier-2 execution-proof source** for the Reputation registry. The
engine presents the attestation digest as the proof reference; ANID records it,
without itself verifying the TEE quote. The attestation machinery — measurement
`M_a = H(model_id ‖ system_prompt ‖ tool_manifest ‖ code)`, quote verification,
hardware roots — is an engine/validator concern, referenced only by this hook.

---

## 7. Guardian challenge: optimistic finality

Restricted writes and a curated writer set close the open-Sybil and fake-engine
classes. The guardian challenge handles the residual case: a *registered* engine
writes a score that is wrong, stale, or disputed. The mechanism is optimistic
finality.

The single most important constraint is what the guardian is **not**:

> The guardian is a **bounded challenger**, not a discretionary delete key.

A delete key would re-introduce exactly the tamper-trust the chain was meant to
remove, and add a single high-value compromise surface. So the guardian cannot erase
a score; it can only challenge one under a rule, stake on the outcome, and let
rule-based resolution decide.

The mechanism:

1. **Post, but not final.** A write posts on-chain immediately, but is not
   trusted-final until its challenge window elapses.
2. **Anyone may challenge.** Within the window, the guardian — and anyone — may
   challenge by staking. There is no privileged challenger role at the protocol
   level.
3. **Rule-based resolution.** The challenge is resolved mechanically, by rule. The
   losing party's stake is slashed.
4. **Consumers act only on survivors.** External consumers act only on reviews that
   survived the window, so there is no real-time window in which a fake score can be
   acted on before cleanup.

The trust profile of any acted-upon score is therefore "survived a staked challenge
under a rule," not "trust that no one quietly deleted it." During bootstrap the Nien
monitor is the primary challenger; this is the same operation as the permissionless
end state, only the population of challengers differs. The mechanical nature of the
slashing is also what makes the rating-agency liability posture defensible — no
operator is personally authoring each verdict.

---

## 8. Threat model

ANID's security argument is that it closes a class of attacks by construction at the
write layer.

| Attack                        | Closed by                                                            |
| ----------------------------- | ------------------------------------------------------------------- |
| Open-write Sybil              | No open submit endpoint; only `𝒩` may write                          |
| Anonymous fake reviews        | Every write is attributable to a registered engine                  |
| Fabricated outcomes           | No-proof-no-write: a write must carry an execution proof            |
| Wash / grinding               | Value-weighting + decay; cheap repeated actions don't move the score |
| Self-dealing                  | Counterparty independence; related-counterparty writes rejected     |
| Monotonic inflation           | Signed score: violations push it down                               |
| Fake-engine minting           | Engine Registry onboarding gate + guardian challenge                |
| Acting on a fake score        | Optimistic finality; consumers act only on survivors                |
| Discretionary tampering       | Guardian is a bounded challenger, not a delete key                  |

**Residual risks, acknowledged.** Engine collusion is mitigated — not eliminated —
by making provenance part of the read; the onboarding gate is the primary control.
Engine key compromise is bounded in time by the live authority flip and in effect by
the guardian challenge. The challenge-window length is a documented trade-off between
read safety and finality latency. And whether engine authority keys are client-held
or operator-upgradeable determines how "semi"-decentralized the system actually is —
ANID states this boundary rather than hiding it.

---

## 9. Trust model: what ANID does and does not claim

ANID is explicit about its boundary, because a reputation system that overclaims is
worse than none.

**ANID is not trustless.** It is a *curated credentialing network*: vetted engines
issue execution-bound credentials, and the chain makes those credentials public,
portable, attributable, and tamper-evident. What the chain buys is composability,
portability, attribution, and tamper-evidence. It does not buy decentralization, and
ANID does not claim it does.

**Does claim:**

- every reputation point is backed by a proven execution;
- self-review and anonymous-Sybil writes are impossible at the write layer;
- a fake rating faces a staked, rule-based challenge before any contract treats it
  as final;
- reputation accrues only through real work and decays without it.

**Does NOT claim:**

- trustlessness;
- that a high score means the agent's reasoning is correct. ANID never certifies
  reasoning — that is unprovable. A score certifies a *track record of proven,
  settled outcomes*, nothing about the correctness of the model's next decision.

---

## 10. Reference implementation and deployment

ANID ships with a normative specification and a Foundry reference implementation of
all four registries. The contracts are the executable witness of the specification:
an invariant test suite proves the normative requirements are satisfiable and
mutually consistent — only-`𝒩` writes, no-proof-no-write, signed (non-monotonic)
scores, self-deal rejection, the live registry flip, EMA decay, and provenance
counting all hold under test.

A TypeScript SDK, built on ethers with contract bindings generated from the contract
ABIs, provides a typed reader (`scoreFor`, `ownerOf`, `isRegistered`), an engine-side
writer (`recordOutcome`), and governance helpers, along with the canonical id
encoders.

The full flow has been demonstrated end-to-end on **BNB Smart Chain testnet (chain
97)**: an agent is created, an engine is authorized into `𝒩`, the engine records an
execution-bound outcome, and the resulting score is read back from the chain. The
reference deployment:

| Registry           | Address (BNB Smart Chain testnet, chain 97)  |
| ------------------ | -------------------------------------------- |
| IdentityRegistry   | `0x24a733f080319F483684f47a15CfF33328c98f31` |
| EngineRegistry     | `0xC866b01C238A5cfd442957C400Cd39aD684B5A77` |
| ReputationRegistry | `0x16e8394F84614379f606AEfa30dE39f906C0ea00` |
| ValidationRegistry | `0x0Fe9E9fFD9D87B33bE203A52Ad9b38bE068eD455` |

`ReputationRegistry` is wired to the Engine and Identity registries with `λ = 0.9`.
ANID is deployed as an **exclusive Binance (BNB Chain) primitive**: BNB Chain's low
fees and sub-second blocks are what make per-task on-chain reputation viable, where a
high-gas regime would force the writes off-chain and break the transparency property
that is the entire point.

---

## 11. Why ANID compounds

ANID is not a feature but a network. Four effects strengthen as it grows:

- **Portable reputation.** An agent's standing is built across every enterprise it
  touches and verifiable by anyone with an RPC endpoint.
- **Two-sided acceptance.** Every counterparty that checks an ANID before transacting
  makes holding one more useful, and every holder makes verifying more useful.
- **Shared fraud signal.** A cross-network record of bad actors grows stronger with
  every member, contributed without exposing anything proprietary.
- **Underwriting on top.** Once cross-network history exists, the operator can do
  what no single participant can alone: extend credit to agents, guarantee
  settlement, price counterparty risk, and arbitrate disputes.

For any of this to hold, an identity must be costly to discard — which is why L0
accountability and decay are load-bearing, not decorative.

---

## 12. Conclusion

ERC-8004 correctly identifies that agents need on-chain identity and reputation, but
its open-write Reputation registry exports the hard problem to the reader. ANID
solves it at the write layer with one rule — *no authorized engine and no execution
proof, no write* — and a score model that is signed, decaying, value-weighted, and
attributable. The result is a reputation that is a ledger of receipts rather than
opinions: Sybil-resistant and fake-review-resistant by construction, composable and
portable by virtue of being on-chain, and honest about being a curated credentialing
network rather than a trustless one. The specification, the reference contracts, and
the live BNB Chain deployment together make ANID a reusable primitive that any agent
ecosystem can adopt without taking on the rest of the stack.

---

## Appendix A — Specification and source

The normative specification (RFC-2119 requirements) and the Foundry reference
implementation accompany this paper in the same repository:

- `SPEC.md` and `spec/00`–`08` — the normative specification.
- `contracts/` — the Foundry reference implementation and invariant test suite.
- `sdk/` — the TypeScript SDK (ethers, generated types).

## Appendix B — Glossary

- **ANID** — Agentic Network Identity; an agent's on-chain identity plus portable,
  execution-bound reputation.
- **Engine** — a contract in `𝒩`; it authorizes and observes an agent's actions and
  is therefore the only natural reputation writer.
- **`𝒩` (engine set)** — the on-chain set of authorized writer addresses, held in the
  Engine Registry.
- **Execution proof** — the write precondition: a proof kind plus an opaque
  reference, recorded by ANID and verified by the engine.
- **Trust score** — EMA reputation derived from settlement history and counterparty
  outcomes.
- **Performance score** — EMA reputation: the share of submitted tasks actually
  executed.
- **Guardian** — a bounded challenger that stakes to challenge a posted review;
  resolution is rule-based.
- **Provenance** — the `(n, distinctEngines)` returned with every score, so readers
  can discount cartels.

---

*© 2026 Nien Labs. ANID is an exclusive Binance (BNB Chain) primitive. Released
under the MIT License; see `LICENSE`.*
