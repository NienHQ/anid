# 07 — Threat model

ANID's security argument is that it closes a class of attacks **by construction** at
the write layer, rather than asking readers to filter after the fact. This file
lists which attacks are closed and how, and — just as important — what ANID does
**not** claim, so it is not mistaken for snake oil.

## 1. Attacks closed by construction

| Attack                         | Closed by                                                                 | Where |
| ------------------------------ | ------------------------------------------------------------------------- | ----- |
| **Open-write Sybil**           | No open submit endpoint; only `𝒩` may write                               | [02](02-reputation.md), [03](03-engine-registry.md) |
| **Anonymous fake reviews**     | Every write is attributable to a registered engine                        | [02](02-reputation.md) |
| **Fabricated outcomes**        | No-proof-no-write: a write must carry an execution proof                  | [02 §2](02-reputation.md) |
| **Wash / grinding**            | Value-weighting + decay (`λ`): cheap repeated actions don't move the score | [02 §3](02-reputation.md) |
| **Self-dealing**               | Counterparty independence: related-counterparty writes rejected/zero-wt   | [02 §3](02-reputation.md) |
| **Monotonic inflation**        | Signed score: violations push it down                                     | [02 §3](02-reputation.md) |
| **Fake-client / fake-engine**  | Engine Registry onboarding gate + guardian challenge                      | [03](03-engine-registry.md), [05](05-guardian-challenge.md) |
| **Acting on a fake score**     | Optimistic finality: consumers act only on writes that survived a window  | [05](05-guardian-challenge.md) |
| **Discretionary tampering**    | Guardian is a bounded challenger, not a delete key; rule-based slashing   | [05](05-guardian-challenge.md) |

The throughline: there is **no open submit endpoint to spam**, every write is
**attributable** and **execution-bound**, and the score itself is **signed and
decaying**, so the cheap attacks have nowhere to land.

## 2. Residual risks (acknowledged, not eliminated)

ANID is honest about what remains:

- **Engine collusion / cartels.** A set of registered engines could collude. ANID
  mitigates — not eliminates — this by making **provenance part of the read**
  (`distinctEngines`), so a reader can discount a score concentrated in few engines.
  The onboarding gate ([03](03-engine-registry.md)) is the primary control.
- **Engine key compromise.** If an engine's authority key is stolen, the attacker
  can write within that engine's authority until it is deregistered. The live
  authority flip ([03 §3](03-engine-registry.md)) bounds the blast radius in time;
  the guardian challenge ([05](05-guardian-challenge.md)) bounds it in effect.
- **Challenge-window latency vs safety.** A short window finalizes fast but gives
  challengers less time; a long window is safer but slower. This is a documented
  deployment trade-off, not a solved problem ([05 §4](05-guardian-challenge.md)).
- **Custody of engine authority.** Client-held keys vs an operator-upgradeable proxy
  determines how "semi"-decentralized the trust actually is. ANID states the
  boundary; it does not pretend the boundary is elsewhere.

## 3. The scope bound — what ANID does NOT claim

ANID inherits the **honesty bound** from the agentic-identity design. It is critical
to avoid overclaiming:

### Do claim

- Every reputation point is backed by a **proven execution**.
- **Self-review and anonymous-Sybil writes are impossible at the write layer.**
- A fake rating faces a **staked, rule-based challenge** before any contract treats
  it as final.
- Reputation accrues **only through real work** for ecosystem clients, and **decays**
  without it.

### Do NOT claim

- **Trustlessness.** ANID is a *curated credentialing network*, not a decentralized
  one. The chain buys composability, portability, attribution, and tamper-evidence —
  not decentralization. (See [00-overview.md](00-overview.md).)
- **That a high score means the agent's reasoning is correct.** ANID **never
  certifies reasoning** — that is unprovable. A score certifies a *track record of
  proven, settled outcomes*, nothing about the correctness of the model's internal
  reasoning on the next task.

### The underlying identity bound

The broader system this reputation layer sits in claims exactly three things, and
ANID does not exceed them: (i) **provenance/integrity** — which model+prompt+tools+
code ran; (ii) **bounded blast radius** — intent + policy + scoped capability cap a
hijacked agent's damage; (iii) **divergence detection** — out-of-intent behaviour is
flagged and blocked. Reputation is the durable, public record of how an identity has
behaved under those controls — not a certificate of correctness.

## Related

- [02-reputation.md](02-reputation.md) — the write rule and score properties.
- [03-engine-registry.md](03-engine-registry.md) — the onboarding chokepoint.
- [05-guardian-challenge.md](05-guardian-challenge.md) — optimistic finality.
