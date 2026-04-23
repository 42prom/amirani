"use client";

import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import { useEffect, useState } from "react";

interface GymState {
  selectedGymId: string | null;
  setSelectedGymId: (id: string | null) => void;
}

// Base store with persist middleware
const useGymStoreBase = create<GymState>()(
  persist(
    (set) => ({
      selectedGymId: null,
      setSelectedGymId: (id) => set({ selectedGymId: id }),
    }),
    {
      name: "amirani-active-gym",
      storage: createJSONStorage(() => localStorage),
    }
  )
);

/**
 * Wrapper hook that handles hydration to prevent SSR/client mismatch.
 * Returns null for selectedGymId until the store is hydrated from localStorage.
 */
export function useGymStore() {
  const store = useGymStoreBase();
  const [isHydrated, setIsHydrated] = useState(false);

  useEffect(() => {
    // Wait for hydration to complete
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setIsHydrated(true);
  }, []);

  return {
    selectedGymId: isHydrated ? store.selectedGymId : null,
    setSelectedGymId: store.setSelectedGymId,
    isHydrated,
  };
}

// Export the raw store for cases where hydration handling is done manually
export { useGymStoreBase };
