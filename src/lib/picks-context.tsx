import { createContext, useCallback, useContext, useMemo, useState } from 'react';
import type { PropLine } from '../data/board';
import { MAX_PICKS } from './payouts';

export type Direction = 'more' | 'less';

export type Pick = {
  prop: PropLine;
  direction: Direction;
};

type PicksContextValue = {
  picks: Pick[];
  togglePick: (prop: PropLine, direction: Direction) => void;
  removePick: (propId: string) => void;
  clearPicks: () => void;
  getDirection: (propId: string) => Direction | null;
};

const PicksContext = createContext<PicksContextValue | null>(null);

export function PicksProvider({ children }: { children: React.ReactNode }) {
  const [picks, setPicks] = useState<Pick[]>([]);

  const togglePick = useCallback((prop: PropLine, direction: Direction) => {
    setPicks((prev) => {
      const existing = prev.find((p) => p.prop.id === prop.id);
      if (existing && existing.direction === direction) {
        return prev.filter((p) => p.prop.id !== prop.id);
      }
      if (existing) {
        return prev.map((p) => (p.prop.id === prop.id ? { prop, direction } : p));
      }
      if (prev.length >= MAX_PICKS) {
        return prev;
      }
      return [...prev, { prop, direction }];
    });
  }, []);

  const removePick = useCallback((propId: string) => {
    setPicks((prev) => prev.filter((p) => p.prop.id !== propId));
  }, []);

  const clearPicks = useCallback(() => setPicks([]), []);

  const getDirection = useCallback(
    (propId: string) => picks.find((p) => p.prop.id === propId)?.direction ?? null,
    [picks]
  );

  const value = useMemo(
    () => ({ picks, togglePick, removePick, clearPicks, getDirection }),
    [picks, togglePick, removePick, clearPicks, getDirection]
  );

  return <PicksContext.Provider value={value}>{children}</PicksContext.Provider>;
}

export function usePicks() {
  const ctx = useContext(PicksContext);
  if (!ctx) {
    throw new Error('usePicks must be used within PicksProvider');
  }
  return ctx;
}
