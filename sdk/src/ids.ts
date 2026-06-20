import {getAddress, toBeHex, zeroPadValue} from "ethers";

/**
 * Canonical ANID id helpers. See spec/01-identity.md:
 *   DID         did:nien:<method>:<lowercase-evm-address>
 *   network id  anid:<chain>:<lowercase-evm-address>
 * The EVM address component is always lowercased (no EIP-55 casing) so string
 * equality is canonical.
 */

/** Build a network id, e.g. `anid:bnb:0x9a3f…`. */
export function toAnid(chain: string, address: string): string {
  return `anid:${chain}:${getAddress(address).toLowerCase()}`;
}

/** Build a DID, e.g. `did:nien:zk:0x…`. */
export function toDid(method: string, address: string): string {
  return `did:nien:${method}:${getAddress(address).toLowerCase()}`;
}

export interface ParsedAnid {
  chain: string;
  address: string;
}

/** Parse a network id; throws if malformed or the address is invalid. */
export function parseAnid(id: string): ParsedAnid {
  const parts = id.split(":");
  if (parts.length !== 3 || parts[0] !== "anid") {
    throw new Error(`invalid anid network id: ${id}`);
  }
  return {chain: parts[1]!, address: getAddress(parts[2]!).toLowerCase()};
}

export interface ParsedDid {
  method: string;
  address: string;
}

/** Parse a DID; throws if malformed or the address is invalid. */
export function parseDid(did: string): ParsedDid {
  const parts = did.split(":");
  if (parts.length !== 4 || parts[0] !== "did" || parts[1] !== "nien") {
    throw new Error(`invalid did:nien did: ${did}`);
  }
  return {method: parts[2]!, address: getAddress(parts[3]!).toLowerCase()};
}

/**
 * Encode an agent id (uint256) as the bytes32 used for `counterpartyId` in
 * `recordOutcome`. The Reputation registry compares `counterpartyId` against
 * `bytes32(agentId)` and resolves owner relations through the Identity registry.
 */
export function agentIdToBytes32(agentId: bigint): string {
  return zeroPadValue(toBeHex(agentId), 32);
}
