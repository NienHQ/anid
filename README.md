# ANID — Agentic Network Identity

ANID is an agent identity and reputation layer: an **ERC-8004 fork** that keeps the Identity and
Validation registries verbatim, **replaces** the open-write Reputation registry with a
restricted-write, execution-bound one, and **adds** an Engine Registry — the on-chain allowlist of
authorized writers (the set `𝒩`).

The one idea: ERC-8004 reputation is open-write, *trust-the-reader-to-filter*. ANID is
restricted-write, *trust-the-writer-because-it-is-verifiable*. A score delta is causally bound to a
verified execution plus its proof — no execution proof, no write. Reputation becomes a ledger of
receipts, not opinions.

## Component map

| Registry         | ERC-8004     | ANID                                                      |
| ---------------- | ------------ | -------------------------------------------------------- |
| Identity         | keep         | ERC-721 agent IDs; A2A / MCP interop                     |
| Reputation       | **replace**  | restricted-write, execution-bound, decaying, public      |
| Validation       | keep (opt.)  | TEE / zk validators; may double as an execution-proof    |
| Engine Registry  | **new**      | allowlist of authorized writers (`𝒩`) + onboarding gate |

## Repo layout

- `WHITEPAPER.md` — the ANID whitepaper (full design narrative, by Nien Labs).
- `SPEC.md` — the canonical normative spec (entry point; links into `spec/`).
- `spec/` — per-component specification.
- `contracts/` — Foundry reference implementation of the four registries.
- `sdk/` — TypeScript SDK (ethers v6, generated types) for reading/writing the registries.
- `PLAN.md` — working build plan.

## Scope

This repo is the **identity layer only**. The policy engine (Nomos) and custody (MPC / smart-wallet)
are out of scope and referenced only by interface: `𝒩` is an abstract "authorized engine set," and
"execution proof" is an abstract write precondition the registry records but does not itself verify.

## Deployments

ANID is an **exclusive Binance (BNB Chain) primitive** — the reference deployment runs on BNB Chain.

### BNB Smart Chain testnet (chain 97)

| Registry           | Address                                                                                                                          |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| IdentityRegistry   | [`0x24a733f080319F483684f47a15CfF33328c98f31`](https://testnet.bscscan.com/address/0x24a733f080319F483684f47a15CfF33328c98f31) |
| EngineRegistry     | [`0xC866b01C238A5cfd442957C400Cd39aD684B5A77`](https://testnet.bscscan.com/address/0xC866b01C238A5cfd442957C400Cd39aD684B5A77) |
| ReputationRegistry | [`0x16e8394F84614379f606AEfa30dE39f906C0ea00`](https://testnet.bscscan.com/address/0x16e8394F84614379f606AEfa30dE39f906C0ea00) |
| ValidationRegistry | [`0x0Fe9E9fFD9D87B33bE203A52Ad9b38bE068eD455`](https://testnet.bscscan.com/address/0x0Fe9E9fFD9D87B33bE203A52Ad9b38bE068eD455) |

`ReputationRegistry` is wired to the Engine + Identity registries with `λ = 0.9` (9e17). These
addresses are also exported from the SDK as `DEPLOYMENTS[97]`.

## License

MIT — see [LICENSE](LICENSE). © 2026 Nien Labs.
