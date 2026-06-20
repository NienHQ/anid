# 03 — Engine Registry (`𝒩`)

The Engine Registry is the fourth, **new** component ANID adds to ERC-8004. It is
the on-chain allowlist of authorized writer contracts — the set `𝒩` — and the
single chokepoint where onboarding policy is enforced. It is what exports the
network's trust graph to external readers.

## 1. Why it exists

With execution-binding in place ([02-reputation.md](02-reputation.md)), the
remaining attack is **becoming a fake engine** to mint execution-bound ratings for
your own agent. So integrity reduces to **engine onboarding**. The Engine Registry
is where that gate lives, and `isRegistered` is the function the Reputation registry
calls on every write.

## 2. Interface

```solidity
interface IEngineRegistry {
    function isRegistered(address engine) external view returns (bool);

    function register(address engine) external;     // governance-gated
    function deregister(address engine) external;   // governance-gated

    event EngineRegistered(address indexed engine);
    event EngineDeregistered(address indexed engine);
}
```

- **`isRegistered`** is the membership test for `𝒩`. The Reputation registry's
  `onlyRegisteredEngine` modifier is exactly `require(engineRegistry.isRegistered(
  msg.sender))`. (Normative: R-ENG-1, and R-REP-1 in [02](02-reputation.md).)
- **`register` / `deregister`** mutate `𝒩` and **MUST** be governance-gated and
  emit their events. (R-ENG-2.)

## 3. Live authority flip

Removing an engine from `𝒩` **MUST immediately** revoke its ability to write
reputation — there is no cached authority, no grace window. Because the Reputation
registry queries `isRegistered` on *every* write, a `deregister` in block `N` means
a write from that engine in block `N+1` reverts. (R-ENG-3.) This is one of the
invariant tests: toggling registration flips write authority live.

## 4. Governance

- v1 is a **curated allowlist**: an owner or a *Nien Identity Council* may
  `register` / `deregister`. This is **not permissionless, by design** — manual
  vetting of each engine before issuing write authority is precisely what closes the
  client-Sybil attack for v1. (R-ENG-4.)
- The factory pattern (out of scope here, see Nomos `04-contracts`) registers each
  freshly minted engine clone into the registry at creation time, so onboarding and
  authorization are one atomic step in the larger system. ANID specifies only the
  registry surface, not the factory.

## 5. Path to permissionless

The integrity model does **not** change on the way to permissionless onboarding;
only the **gate** changes:

- **Now:** manual vetting issues a writable engine.
- **Later:** replace manual vetting with **staking** plus the
  [guardian-challenge](05-guardian-challenge.md) mechanism already present — an
  engine stakes to join `𝒩`, and misbehaviour is challenged and slashed by rule.

Because membership is the only trust assumption that scales with the operator, an
implementation **SHOULD** document where on this path it currently sits. A registry
that is curated today and staking-gated tomorrow is the same registry with a
different `register` policy.

## 6. Trust-boundary note

"`N` engines" is only meaningfully decentralized to the degree that engine
authority keys are client-held, the scoring logic is immutable or transparently
governed, and every score is attributable to a specific engine. The Engine Registry
makes the **attributability** property hold on-chain (every write is tied to a known
member of `𝒩`); the other two are operational properties of how engines are run.
See the trust model in [00-overview.md](00-overview.md).

## Related

- [02-reputation.md](02-reputation.md) — the write rule that consumes `isRegistered`.
- [05-guardian-challenge.md](05-guardian-challenge.md) — the slashing mechanism that
  a permissionless onboarding gate reuses.
- [06-interfaces.md](06-interfaces.md) — `IEngineRegistry` / `IEngineSet` seam.
