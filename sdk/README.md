# anid-sdk

TypeScript SDK for the [ANID registries](../contracts), built on **ethers v6** with
**typed contract bindings generated from the Foundry ABIs** (TypeChain).

## Install & build

```bash
pnpm install          # also runs `prepare` → generate + build
# or step by step:
pnpm generate         # forge build + typechain → src/typechain (gitignored)
pnpm build            # generate + tsc → dist
```

> `src/typechain/` and `dist/` are generated and git-ignored; `pnpm build`
> reproduces them. Generation reads `../contracts/out`, so Foundry must be
> installed (`forge`).

## Usage

```ts
import {JsonRpcProvider, Wallet} from "ethers";
import {AnidReader, EngineClient, AdminClient, ProofKind, agentIdToBytes32, toAnid} from "anid-sdk";

const addresses = {
  identity: "0x…",
  engine: "0x…",
  reputation: "0x…",
  validation: "0x…",
};

// Reads — any Provider.
const reader = new AnidReader(addresses, new JsonRpcProvider(RPC));
const score = await reader.scoreFor(1n);
// → { trust, performance, n, distinctEngines, trustFloat, performanceFloat }

// Engine-side write — a Signer whose address is registered in 𝒩.
const engine = new EngineClient(addresses, new Wallet(ENGINE_KEY, provider));
await engine.recordOutcome({
  agentId: 1n,
  proof: {kind: ProofKind.SettledOnChain, ref: settlementTxHash},
  counterpartyId: agentIdToBytes32(2n), // independent of agentId
  trust: 1,        // signed reward in [-1, 1]
  performance: 1,
});

// Governance — the EngineRegistry owner.
const admin = new AdminClient(addresses, ownerSigner);
await admin.registerEngine(engineAddress);
await admin.registerAgent(1n, agentOwner);

// Id helpers (spec/01).
toAnid("bnb", "0x9a3f…"); // "anid:bnb:0x9a3f…"
```

## API

| Export | What |
| --- | --- |
| `AnidReader` | `scoreFor`, `ownerOf`, `exists`, `isRegisteredEngine`; raw typed contracts on `.identity/.engine/.reputation/.validation` |
| `EngineClient` | `recordOutcome(params)` — execution-bound write (rejects empty proof client-side too) |
| `AdminClient` | `registerEngine` / `deregisterEngine` / `registerAgent` |
| `ProofKind` | proof-tier enum (matches on-chain) |
| `toWad` / `fromWad` / `WAD` | fixed-point helpers ([-1,1] ⇄ WAD) |
| `toAnid` / `toDid` / `parseAnid` / `parseDid` / `agentIdToBytes32` | id helpers |
| `CHAIN_IDS` / `DEPLOYMENTS` / `AnidAddresses` | network config |
| `*__factory`, contract types | generated TypeChain bindings (re-exported) |

## End-to-end smoke test

```bash
anvil &                 # local node on :8545
pnpm build && node scripts/smoke.cjs
```

Deploys all four registries via the generated factories and drives them through the
reader/writer/admin, asserting the EMA result (`trustFloat === 0.1` after one +1.0
outcome). See [`scripts/smoke.cjs`](scripts/smoke.cjs).
