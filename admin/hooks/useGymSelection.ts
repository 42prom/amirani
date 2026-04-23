"use client";

import { useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useAuthStore } from "@/lib/auth-store";
import { useGymStore } from "@/lib/gym-store";
import { gymsApi, type Gym } from "@/lib/api";


interface UseGymSelectionResult {
  // Data
  gyms: Gym[] | undefined;
  selectedGymId: string | null;
  selectedGym: Gym | undefined;

  // Actions
  setSelectedGymId: (id: string | null) => void;

  // Loading states
  isLoading: boolean;
  isGymsLoading: boolean;
  isHydrated: boolean;

  // User info
  userRole: string | undefined;
  isBranchAdmin: boolean;
}

/**
 * Unified hook for gym selection across all pages.
 * Handles:
 * - Fetching gyms list
 * - Auto-selecting gym (from URL or store or default)
 * - Syncing URL with store for gym detail pages
 * - Validating gym selection
 * - Hydration state for SSR/client mismatch
 */
export function useGymSelection(): UseGymSelectionResult {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const { token, user } = useAuthStore();
  const { selectedGymId, setSelectedGymId, isHydrated } = useGymStore();

  const userRole = user?.role;
  const isBranchAdmin = userRole === "BRANCH_ADMIN";

  // Extract gym ID from URL: priority 1: path, priority 2: search params
  const gymPageMatch = pathname.match(/\/dashboard\/gyms\/([a-f0-9-]+)/i);
  const urlGymId = gymPageMatch?.[1] || searchParams.get("gymId");

  // Fetch all gyms
  const { data: gyms, isLoading: isGymsLoading } = useQuery({
    queryKey: ["gyms"],
    queryFn: () => gymsApi.getAll(token!),
    enabled: !!token,
    staleTime: 30000, // Cache for 30 seconds
  });

  // Unified gym selection logic - only run after hydration
  useEffect(() => {
    if (!isHydrated || !gyms || gyms.length === 0) return;

    // Priority 1: URL gym ID (for gym detail pages)
    if (urlGymId && gyms.some((g) => g.id === urlGymId)) {
      if (selectedGymId !== urlGymId) {
        setSelectedGymId(urlGymId);
      }
      return;
    }

    // Priority 2: Branch admin's managed gym
    if (isBranchAdmin && user?.managedGymId) {
      if (selectedGymId !== user.managedGymId) {
        setSelectedGymId(user.managedGymId);
      }
      return;
    }

    // Priority 3: Current selection if valid
    if (selectedGymId && gyms.some((g) => g.id === selectedGymId)) {
      return; // Keep current selection
    }

    // Priority 4: Default to first gym (or Demo Fitness Center)
    const demoGym = gyms.find((g) => g.name === "Demo Fitness Center");
    const defaultGym = demoGym || gyms[0];
    if (defaultGym) {
      setSelectedGymId(defaultGym.id);
    }
  }, [gyms, urlGymId, selectedGymId, setSelectedGymId, isBranchAdmin, user?.managedGymId, isHydrated]);

  // Get the selected gym object
  const selectedGym = gyms?.find((g) => g.id === selectedGymId);

  return {
    gyms,
    selectedGymId,
    selectedGym,
    setSelectedGymId,
    isLoading: !isHydrated || isGymsLoading || (!selectedGymId && !!gyms?.length),
    isGymsLoading,
    isHydrated,
    userRole,
    isBranchAdmin,
  };
}

/**
 * Hook for switching gyms with navigation support
 */
export function useGymSwitcher() {
  const router = useRouter();
  const pathname = usePathname();
  const { selectedGymId, setSelectedGymId } = useGymStore();

  const switchGym = (newGymId: string) => {
    if (newGymId === selectedGymId) return;

    setSelectedGymId(newGymId);

    // Check if on a gym detail page - navigate to new gym
    const gymPageMatch = pathname.match(/\/dashboard\/gyms\/([a-f0-9-]+)/i);
    if (gymPageMatch) {
      const newPath = pathname.replace(
        /\/dashboard\/gyms\/[a-f0-9-]+/i,
        `/dashboard/gyms/${newGymId}`
      );
      router.push(newPath);
    }
  };

  return { switchGym, selectedGymId };
}
