/**
 * Payout multipliers by number of picks in an entry.
 * All picks must hit for the entry to pay out.
 */
export const PAYOUT_MULTIPLIERS: Record<number, number> = {
  2: 3,
  3: 5,
  4: 10,
  5: 20,
  6: 37.5,
};

export const MIN_PICKS = 2;
export const MAX_PICKS = 6;

export function getMultiplier(pickCount: number): number {
  return PAYOUT_MULTIPLIERS[pickCount];
}

export function getPotentialPayout(entryAmount: number, pickCount: number): number {
  return entryAmount * getMultiplier(pickCount);
}

export function formatMoney(amount: number): string {
  return `$${amount.toFixed(2)}`;
}
