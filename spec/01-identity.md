# 01 — Identity (adopted, with Nien conventions)

ANID **adopts the ERC-8004 Identity registry**. Agent IDs are ERC-721 tokens with
an owner; the A2A / MCP interop story is inherited unchanged. This file pins the
conventions ANID layers on top — id formats, the L0 accountability binding, and the
canonical off-chain record model — none of which alter the ERC-8004 wire format.

## On-chain shape

- Agent IDs are **ERC-721** tokens. The token owner is the agent's controller.
- The registry **MUST** emit `AgentRegistered(uint256 indexed agentId, address
  indexed owner)` on registration. This preserves wire-compatibility with the
  deployed `IdentityLite` receipt, so existing consumers keying on that event keep
  working when they migrate to the full registry.
- The full ERC-721 `IdentityRegistry` **supersedes** `IdentityLite` (which carried
  only `ownerOf` + `AgentRegistered`); the lite event signature is retained.

## Canonical id formats

These formats are pinned from the working implementation (`keygen` / the
`AnidRecord` model) so off-chain tooling is interoperable:

| Field          | Format                                         | Example                          |
| -------------- | ---------------------------------------------- | -------------------------------- |
| **DID**        | `did:nien:<method>:<lowercase-evm-address>`    | `did:nien:zk:0x9a3f…`            |
| **Network id** | `anid:<chain>:<lowercase-evm-address>`         | `anid:bnb:0x9a3f…`               |
| **Public key** | uncompressed secp256k1, `0x04…`                | `0x04a1b2…`                      |

Rules:

- The EVM address component **MUST** be lowercased (no EIP-55 checksum casing) in
  the id strings, so string equality is canonical.
- `<chain>` is a short network label (`bnb`, `bsc`, `opbnb`, …) selecting the chain
  the identity is anchored on.
- `<method>` names the keygen method/namespace (e.g. `zk`).
- The on-chain EVM address bound to the keypair is the **anchor subject** — the
  address that signs the registration anchor.

## L0 — accountability

ANID identity is the on-chain realization of **L0** in the agentic-identity stack:
*WHO is accountable?* A key answers only "who holds this key"; L0 answers "who is
liable for what this key does."

- Every ANID **SHOULD** be bound by a signed **ownership chain** to an accountable
  legal entity, the `publisher`. Conceptually: the entity `E` issues a verifiable
  credential `C_a = Sign_{sk_E}(DID_a ‖ scope ‖ expiry)`.
- The binding makes an **identity costly to discard**: an agent cannot shed a bad
  record by minting a fresh anonymous identity, because a fresh identity carries no
  accountable publisher and therefore no standing.
- The higher layers of that stack — L1 execution attestation, L2 intent binding,
  L3 runtime governance, L4 scoped capability, L5 reputation — are the **engine's**
  concern, not the registry's. ANID's Identity component fixes only L0 plus the id
  conventions; L5 reputation is specified separately in
  [02-reputation.md](02-reputation.md).

## Canonical off-chain record model (`AnidRecord`)

The registry stores the minimal on-chain binding (`agentId → owner`). The richer
identity dossier lives off-chain and is mirrored from the canonical `AnidRecord`
field set so tooling agrees on shape. The fields ANID treats as canonical:

| Group           | Fields                                                                     |
| --------------- | -------------------------------------------------------------------------- |
| **Identity**    | `id` (network id), `did`, `pubkey`, `name`, `address`                      |
| **L0**          | `publisher` (accountable legal entity), `kind` (`first-party`/`ecosystem`) |
| **Capability**  | `capabilities` (granted scopes), `intentManifest` (what it may *want*, L2) |
| **Attestation** | `attested`, `attestation` (vendor, measurement, `verifiedAt`) — opt-in L1  |
| **Reputation**  | `trust ∈ [0,1]`, `performance ∈ [0,1]`, `verifiedExecutions` (`n`)         |
| **Lifecycle**   | `status` (`active`/`sandbox`/`pending`/`revoked`), `tier`, `registeredAt`  |
| **Anchor**      | `onChain`, `txHash`, `explorerUrl`, `anchorSigner` (`agent`/`platform`)    |

Notes:

- `trust` and `performance` are **reads** from the Reputation registry, not
  identity state — they are mirrored into the record for convenience. The chain is
  authoritative. See [02-reputation.md](02-reputation.md).
- `tier` (`tight` / `standard` / `trusted`) is a reputation-gated band of latitude
  consumed by a policy engine; it is **not** ANID state — ANID exposes the scores,
  the engine maps scores to tiers.
- `status` is per-network lifecycle managed by the onboarding enterprise, again
  outside the registry's minimal binding.

## Related

- [02-reputation.md](02-reputation.md) — the scores referenced above.
- [03-engine-registry.md](03-engine-registry.md) — who may write those scores.
- [08-glossary.md](08-glossary.md) — `task`, `intent manifest`, `operating tier`.
