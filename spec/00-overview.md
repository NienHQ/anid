# 00 — Overview: the fork thesis

> ERC-8004 reputation is **open-write, trust-the-reader-to-filter**.
> ANID is **restricted-write, trust-the-writer-because-it-is-verifiable**.

## The position: what ANID forks, what it changes

ERC-8004 ships three registries: Identity, Reputation, Validation. Identity and
Validation are sound. The Reputation registry is an open-write public forum: any
address can attach a score to any agent, with no proof of interaction, no stake,
and no identity. The spec itself concedes it is Sybil-wide-open and tells readers
to "filter by trusted reviewers." That filtering is the whole trust model, left as
an exercise.

ANID keeps Identity (ERC-721 agent IDs, A2A/MCP interop) and the Validation hook
**verbatim**. It **replaces** the Reputation registry with a permissioned-writer,
execution-bound model, and **adds** a fourth component — the Engine Registry — to
hold the set of authorized writers. This repository specifies that replacement and
that addition.

## The core inversion (the one idea)

A score delta is causally bound to a verified execution plus its proof. **No
execution proof, no write.** Reputation becomes a ledger of receipts, not opinions.
This kills the fake-review and Sybil class *by construction*, not by after-the-fact
filtering: there is no open submit endpoint to spam.

The corollary is that the writers are not arbitrary addresses. The only addresses
that may write are **registered engines** — contracts that already authorize and
observe an agent's actions, and therefore are the natural and only parties able to
witness an outcome. Reputation is a side effect of a gate the engine already runs.

This is **not single-writer**. Authority is distributed to the degree that
(i) clients hold their engine's authority keys, (ii) the scoring logic is immutable
or transparently governed, and (iii) every score is attributable to a specific
engine. Absent those three, "N engines" is just one operator sharded N ways. ANID
states the trust boundary explicitly rather than claim decentralization it has not
earned.

## Component map

| Registry            | ERC-8004      | ANID                                                       |
| ------------------- | ------------- | --------------------------------------------------------- |
| **Identity**        | keep          | ERC-721 agent IDs; A2A / MCP interop                      |
| **Reputation**      | **replace**   | restricted-write, execution-bound, decaying, public       |
| **Validation**      | keep (opt.)   | TEE / zk validators; an engine may double as a validator  |
| **Engine Registry** | **new**       | allowlist of authorized writers (`𝒩`) + onboarding gate   |

- **Identity — keep.** See [01-identity.md](01-identity.md).
- **Reputation — replace.** The core of this repo. See [02-reputation.md](02-reputation.md).
- **Validation — keep (optional).** See [04-validation.md](04-validation.md).
- **Engine Registry — new.** See [03-engine-registry.md](03-engine-registry.md).

## Trust model, stated plainly

ANID is **NOT trustless**, and this spec does not market it as such. It is a
**curated credentialing network**: a set of vetted engines issue execution-bound
credentials, and the chain makes those credentials public, portable, attributable,
and tamper-evident.

What the chain buys:

- **Composability** — external contracts (lending pools, escrow, routers) can gate
  on a score directly, on-chain.
- **Portability** — an agent's standing is built across every enterprise it
  touches and is verifiable by anyone with an RPC endpoint.
- **Attribution** — every score is traceable to the engine that wrote it.
- **Tamper-evidence** — the record is append-only and publicly auditable.

What the chain does **not** buy: decentralization. ANID does not claim it.

**Liability posture.** Curating ratings that third parties trade on is a
rating-agency posture with regulatory weight. The defensible form is **rule-based
mechanical slashing** (see [05-guardian-challenge.md](05-guardian-challenge.md)),
not discretionary admin judgment — because no operator is personally authoring each
verdict.

## How to read this spec

- [SPEC.md](../SPEC.md) is the normative entry point (RFC-2119 requirements).
- Each `spec/0x-*.md` file details one component or cross-cutting concern.
- [`contracts/`](../contracts/) is the executable witness: the invariant tests
  prove the requirements in [02-reputation.md](02-reputation.md) and
  [03-engine-registry.md](03-engine-registry.md) are satisfiable and mutually
  consistent.
