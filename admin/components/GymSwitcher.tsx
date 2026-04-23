"use client";

import { useState } from "react";
import { useRouter, usePathname, useSearchParams } from "next/navigation";
import { Building2, ChevronDown } from "lucide-react";
import { useGymStore } from "@/lib/gym-store";
import { useAuthStore } from "@/lib/auth-store";
import type { Gym } from "@/lib/api";

interface GymSwitcherProps {
  gyms: Gym[] | undefined;
  isLoading: boolean;
  disabled?: boolean;
}

export function GymSwitcher({ gyms, isLoading, disabled }: GymSwitcherProps) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const { user } = useAuthStore();
  const { selectedGymId, setSelectedGymId } = useGymStore();
  const [isOpen, setIsOpen] = useState(false);

  // Branch admins don't see the switcher
  if (user?.role === "BRANCH_ADMIN") {
    return null;
  }

  const activeGym = gyms?.find((g) => g.id === selectedGymId);

  const handleGymSelect = (gym: Gym) => {
    if (gym.id === selectedGymId) {
      setIsOpen(false);
      return;
    }

    // Update store
    setSelectedGymId(gym.id);
    setIsOpen(false);

    // Navigate if on a gym detail page
    const gymPageMatch = pathname.match(/\/dashboard\/gyms\/([a-f0-9-]+)/i);
    if (gymPageMatch) {
      const newPath = pathname.replace(
        /\/dashboard\/gyms\/[a-f0-9-]+/i,
        `/dashboard/gyms/${gym.id}`
      );
      router.push(newPath);
    } else if (searchParams.get("gymId")) {
      // Update query parameter for specialized pages (Staff, Members, etc.)
      const params = new URLSearchParams(searchParams.toString());
      params.set("gymId", gym.id);
      router.push(`${pathname}?${params.toString()}`);
    }
  };

  return (
    <div className="w-full md:w-80">
      <div className="relative">
        <button
          onClick={() => setIsOpen(!isOpen)}
          disabled={isLoading || !gyms?.length || disabled}
          className="w-full flex items-center justify-between px-6 py-4 rounded-[1.5rem] bg-white/[0.03] backdrop-blur-md border border-white/10 hover:border-[#F1C40F]/30 transition-all duration-500 group relative overflow-hidden disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <div className="flex items-center gap-3 relative z-10">
            <div className="w-8 h-8 bg-[#F1C40F]/10 rounded-lg flex items-center justify-center group-hover:bg-[#F1C40F]/20 transition-colors">
              <Building2 className="text-[#F1C40F]" size={16} />
            </div>
            <div className="text-left">
              <p className="text-[11px] font-black text-zinc-500 uppercase tracking-[0.2em] leading-none mb-1">
                Active Facility
              </p>
              <p className="text-white text-sm font-black uppercase tracking-tighter line-clamp-1">
                {isLoading ? "Loading..." : activeGym?.name || "Select Facility"}
              </p>
            </div>
          </div>
          {!disabled && (
            <ChevronDown
              size={16}
              className={`text-zinc-500 transition-transform duration-500 relative z-10 ${
                isOpen ? "rotate-180 text-[#F1C40F]" : "group-hover:text-white"
              }`}
            />
          )}

          <div className="absolute inset-0 bg-gradient-to-br from-[#F1C40F]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700" />
        </button>

        {isOpen && (
          <>
            <div className="fixed inset-0 z-[60]" onClick={() => setIsOpen(false)} />
            <div className="absolute top-[calc(100%+8px)] right-0 w-full bg-[#121721] backdrop-blur-2xl border border-white/10 rounded-2xl overflow-hidden z-[70] shadow-[0_20px_50px_rgba(0,0,0,0.5)] animate-in fade-in slide-in-from-top-4 duration-500">
              <div className="p-2 space-y-1 max-h-[300px] overflow-y-auto">
                {gyms?.map((gym) => (
                  <button
                    key={gym.id}
                    onClick={() => handleGymSelect(gym)}
                    className={`w-full flex items-center justify-between px-4 py-3 rounded-xl transition-all duration-300 group/item
                      ${
                        selectedGymId === gym.id
                          ? "bg-[#F1C40F] text-black"
                          : "text-zinc-400 hover:bg-white/5 hover:text-white"
                      }`}
                  >
                    <span className="text-xs font-black uppercase tracking-tight">{gym.name}</span>
                    {selectedGymId === gym.id && <div className="w-1 h-1 rounded-full bg-black" />}
                  </button>
                ))}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
