# ANID reference contracts

Foundry reference implementation of the four ANID registries. These contracts are
the **executable witness** of [`../SPEC.md`](../SPEC.md): the invariant tests prove
the normative requirements are satisfiable and mutually consistent. The contracts
are normative for *behaviour*, informative for *style*.

## Layout

```
src/
  interfaces/
    IIdentityRegistry.sol     adopted ERC-8004 Identity
    IEngineRegistry.sol       the writer set 𝒩 (isRegistered / register / deregister)
    IReputationRegistry.sol   the fork + ProofKind, ExecutionProof, Outcome
    IValidationRegistry.sol   adopted ERC-8004 Validation (minimal hook)
  IdentityRegistry.sol        ERC-721 agent IDs; keeps AgentRegistered (wire-compat)
  EngineRegistry.sol          owner-governed allowlist 𝒩
  ReputationRegistry.sol      restricted-write, execution-bound, EMA two-score
  ValidationRegistry.sol      minimal validation hook
test/
  ReputationRegistry.t.sol    the invariant suite
  EngineRegistry.t.sol
  IdentityRegistry.t.sol
script/
  Deploy.s.sol                deploys + wires all four (BNB testnet, chain 97)
```

## Quickstart

```bash
forge install        # fetch lib/ submodules (forge-std, openzeppelin-contracts)
forge build
forge test -vvv
```

## The invariants the tests hold

| Test | Requirement |
| --- | --- |
| `test_onlyEngine_*` | R-REP-1 — only `𝒩` may write |
| `test_noProof_reverts` | R-REP-2 — no proof, no write |
| `test_score_isSigned_negativeLowersIt` | R-REP-3 — signed, not monotonic |
| `test_selfDeal_*` | R-REP-4 — counterparty independence |
| `test_ema_decaysTowardSteadyState` | R-REP-5/6 — EMA two-score + decay |
| `test_provenance_*` | R-REP-8 — `n` / `distinctEngines` provenance |
| `test_registryFlip_revokesWriteAuthorityLive` | R-ENG-3 — live authority flip |

## Deploy (BNB Smart Chain testnet, chain 97)

```bash
# simulate
forge script script/Deploy.s.sol --rpc-url bsc_testnet --sender <addr>

# broadcast + verify
forge script script/Deploy.s.sol --rpc-url bsc_testnet \
  --account <keystore> --broadcast --verify
```

Environment (all optional): `BSC_TESTNET_RPC_URL`, `BSCSCAN_API_KEY`,
`ENGINE_REGISTRY_OWNER` (defaults to deployer), `LAMBDA_WAD` (defaults `9e17` = 0.9).
