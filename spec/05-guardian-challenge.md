# 05 — Guardian challenge (optimistic finality)

Restricted writes ([02](02-reputation.md)) and a curated writer set
([03](03-engine-registry.md)) close the open-Sybil and fake-engine classes. The
guardian challenge handles the residual case: a *registered* engine writes a score
that is wrong, stale, or disputed. The mechanism is **optimistic finality** — a
write posts immediately but is not *trusted-final* until it survives a challenge
window.

## 1. The guardian is a bounded challenger, not a delete key

The single most important design constraint:

> The guardian is a **bounded challenger**, not a discretionary delete key.

A discretionary delete key would re-introduce exactly the tamper-trust the chain was
supposed to remove, and add a single high-value compromise surface. So the guardian
cannot *erase* a score; it can only *challenge* one under a rule, stake on the
outcome, and let rule-based resolution decide. (Normative: R-CHL-2.)

## 2. The mechanism

1. **Post, but not final.** A review (a `recordOutcome` write) posts on-chain
   immediately, but it is **not trusted-final** until its challenge window elapses.
2. **Anyone may challenge.** Within the window, the guardian — and **anyone** — may
   challenge the write by **staking**. There is no privileged challenger role at the
   protocol level.
3. **Rule-based resolution.** The challenge is resolved by **rule**, not by
   discretion. The **loser's stake is slashed**. (R-CHL-2.)
4. **Consumers act only on survivors.** External consumers **MUST** act only on
   reviews that **survived** the window. (R-CHL-1.) So there is no real-time window
   in which a fake score can be acted on before cleanup.

The resulting trust profile of any acted-upon score is *"survived a staked
challenge under a rule,"* not *"trust that the operator did not quietly delete it."*

## 3. Bootstrap

During bootstrap, the **Nien monitor is the primary challenger** — it is the party
watching for bad writes and staking against them. This is the *same operation* as
the permissionless end state; only the population of challengers differs. As the
network matures, independent challengers stake against bad writes for the slashing
reward, and the operator's role recedes.

## 4. Parameters (implementation-defined)

These are deployment knobs, not fixed by this spec:

- **Challenge-window length.** A longer window means safer reads but slower
  finality (composability latency). An implementation **MUST** document its window
  and external consumers **MUST** respect it.
- **Stake size and slashing schedule.** Must be large enough to deter frivolous
  challenges and frivolous bad writes, by rule.
- **The resolution rule** itself. Must be mechanical and publicly specified — its
  mechanical nature is what makes the rating-agency liability posture defensible
  (see [00-overview.md](00-overview.md)).

## 5. Reuse for permissionless onboarding

The same staking-plus-challenge machinery is what
[03-engine-registry.md](03-engine-registry.md) reuses to move engine onboarding from
curated to permissionless: an engine stakes to join `𝒩`, and a rule-based challenge
can slash and eject it. One mechanism, two uses.

## Related

- [02-reputation.md](02-reputation.md) — the writes this finalizes.
- [03-engine-registry.md](03-engine-registry.md) — the onboarding path that reuses
  this mechanism.
- [07-threat-model.md](07-threat-model.md) — where this sits in the attack table.
