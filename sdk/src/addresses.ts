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
 * Known deployments keyed by chain id. Empty until the registries are broadcast;
 * populate from `script/Deploy.s.sol` output (or pass `AnidAddresses` directly).
 */
export const DEPLOYMENTS: Partial<Record<number, AnidAddresses>> = {};
