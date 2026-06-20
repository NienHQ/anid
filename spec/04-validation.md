# 04 — Validation (adopted)

ANID **adopts the ERC-8004 Validation registry as-is**. It is kept verbatim; this
repo adds no new requirements to its wire format. This file states only the two
facts an ANID reader needs: that Validation is optional, and how it connects to the
Reputation registry's execution-proof tiers.

## 1. Adopted, optional

- An ANID-conformant Validation registry **MUST** adopt the ERC-8004 Validation
  hook unchanged. (Normative: R-VAL-1.)
- Validation is **optional** for an ANID deployment. A deployment may run Identity +
  Reputation + Engine Registry without Validation and still be conformant; Validation
  is the place to plug richer validator / attestation flows when wanted.

## 2. Validation as an execution-proof source

A registered validator or a TEE attestation **MAY** double as an **execution-proof
source** for the Reputation registry — specifically **tier 2** (TEE attestation
digest) in the proof table of [02-reputation.md](02-reputation.md). (R-VAL-2.)

The connection is one-directional and loose by design:

- An engine that has a validator attestation for an execution **MAY** present that
  attestation's digest as the `ExecutionProof.ref` with `ProofKind` = tier 2.
- ANID's Reputation registry still does **not** verify the attestation; it records
  that a tier-2 proof of that digest was asserted. *Verifying* the TEE quote is the
  engine's / validator's job. ANID's separation of concerns (record vs verify)
  holds here exactly as it does for the other proof tiers.

## 3. What stays out

The L1 execution-attestation machinery itself — TEE roots (Phala, Marlin Oyster,
AWS Nitro, Intel TDX, AMD SEV-SNP, NVIDIA CC), measurement `M_a = H(model_id ‖
system_prompt ‖ tool_manifest ‖ code)`, quote verification — is an **engine /
validator** concern, not an ANID registry concern. ANID references it only by the
proof-tier hook above.

## Related

- [02-reputation.md](02-reputation.md) — the execution-proof tiers this feeds.
- [06-interfaces.md](06-interfaces.md) — `ExecutionProof` shape.
- [01-identity.md](01-identity.md) — the optional `attestation` field on `AnidRecord`.
