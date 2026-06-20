/** Fixed-point (WAD) helpers. Scores and rewards are WAD-scaled (1.0 = 1e18). */

export const WAD = 10n ** 18n;

/**
 * Convert a reward in [-1, 1] to a WAD-scaled bigint for `recordOutcome`.
 * Mirrors the contract's accepted range; throws if out of [-1, 1].
 */
export function toWad(x: number): bigint {
  if (!Number.isFinite(x) || x < -1 || x > 1) {
    throw new RangeError(`reward must be a finite number in [-1, 1], got ${x}`);
  }
  // round to nearest integer WAD unit
  return BigInt(Math.round(x * 1e18));
}

/** Convert a WAD-scaled score/reward back to a float (e.g. for display). */
export function fromWad(x: bigint): number {
  return Number(x) / 1e18;
}
