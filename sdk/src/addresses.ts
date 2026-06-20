/** Deployed registry addresses for an ANID instance. */
export interface AnidAddresses {
  identity: string;
  engine: string;
  reputation: string;
  validation: string;
}

/** Chain ids ANID targets. BNB Smart Chain testnet (97) is the reference network. */
export const CHAIN_IDS = {
  bscTestnet: 97,
  bsc: 56,
  opBnb: 204,
} as const;

/**
 * Known deployments keyed by chain id. ANID is deployed exclusively on BNB Chain.
 * Populate further networks from `script/Deploy.s.sol` output (or pass
 * `AnidAddresses` directly).
 */
export const DEPLOYMENTS: Partial<Record<number, AnidAddresses>> = {
  // BNB Smart Chain testnet (chain 97)
  [CHAIN_IDS.bscTestnet]: {
    identity: "0x24a733f080319F483684f47a15CfF33328c98f31",
    engine: "0xC866b01C238A5cfd442957C400Cd39aD684B5A77",
    reputation: "0x16e8394F84614379f606AEfa30dE39f906C0ea00",
    validation: "0x0Fe9E9fFD9D87B33bE203A52Ad9b38bE068eD455",
  },
};
