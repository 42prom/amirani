"use client";

import { useRouter } from "next/navigation";
import { Plus, Sparkles, RefreshCcw, Rocket, ChevronRight } from "lucide-react";
import { useAuthStore } from "@/lib/auth-store";
import { useQuery } from "@tanstack/react-query";
import { analyticsApi } from "@/lib/api";
import { useState, useEffect } from "react";
import { BranchCard } from "../ui/BranchCard";
import clsx from "clsx";

function useOnboardingBanner(userId?: string): boolean {
  const [show, setShow] = useState(false);
  useEffect(() => {
    if (!userId) return;
    try {
      const raw = localStorage.getItem(`amirani_onboarding_v1_${userId}`);
      const done = raw ? (JSON.parse(raw).completed ?? []).includes(7) : false;
      setShow(!done);
    } catch {
      setShow(true);
    }
  }, [userId]);
  return show;
}

export default function GymOwnerDashboard() {
  const { token, user } = useAuthStore();
  const router = useRouter();
  const [days, setDays] = useState(30);
  const showOnboarding = useOnboardingBanner(user?.id);

  const { data: branches, isLoading, refetch, isRefetching } = useQuery({
    queryKey: ["gym-owner-dashboard", days],
    queryFn: () => analyticsApi.getGymOwnerDashboard(token!, days),
    enabled: !!token,
    refetchInterval: 60_000,
  });

  const branchData = branches ?? [];
  const totalRevenue = branchData.reduce((sum, b) => sum + b.monthRevenue, 0);
  const totalMembers = branchData.reduce((sum, b) => sum + b.activeMembers, 0);

  return (
    <div className="space-y-8 animate-in fade-in duration-700">
      {/* Onboarding Banner */}
      {showOnboarding && (
        <button
          onClick={() => router.push("/dashboard/onboarding")}
          className="w-full flex items-center justify-between gap-4 p-5 bg-[#F1C40F]/8 border border-[#F1C40F]/30 rounded-2xl hover:bg-[#F1C40F]/12 transition-all text-left group"
        >
          <div className="flex items-center gap-4">
            <div className="w-10 h-10 bg-[#F1C40F] rounded-xl flex items-center justify-center flex-shrink-0 shadow-[0_0_16px_rgba(241,196,15,0.35)]">
              <Rocket size={20} className="text-black" />
            </div>
            <div>
              <p className="text-white font-bold text-sm">Complete your gym setup</p>
              <p className="text-zinc-400 text-xs mt-0.5">Billing, membership plans, trainers and more — takes under 5 minutes.</p>
            </div>
          </div>
          <ChevronRight size={20} className="text-[#F1C40F] flex-shrink-0 group-hover:translate-x-0.5 transition-transform" />
        </button>
      )}

      {/* AI Summary Box */}
      <div className="bg-gradient-to-r from-[#F1C40F]/10 via-[#F1C40F]/5 to-transparent border border-[#F1C40F]/20 rounded-2xl p-6 relative overflow-hidden group">
        <div className="absolute right-0 top-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
          <Sparkles size={80} className="text-[#F1C40F]" />
        </div>
        <div className="flex items-start gap-4 relative z-10">
          <div className="w-12 h-12 bg-[#F1C40F] rounded-xl flex items-center justify-center text-black shadow-[0_0_20px_rgba(241,196,15,0.3)]">
            <Sparkles size={24} />
          </div>
          <div>
            <h2 className="text-white font-bold text-lg">AI Business Insight</h2>
            <p className="text-zinc-400 text-sm mt-1 leading-relaxed max-w-2xl">
              You currently manage <span className="text-white font-medium">{totalMembers.toLocaleString()} active members</span> across {branchData.length} branches. 
              Top performing branch is <span className="text-[#F1C40F] font-bold">{branchData.sort((a,b) => b.monthRevenue - a.monthRevenue)[0]?.name || "N/A"}</span>. 
              Network-wide check-ins are {branchData.reduce((s,b) => s+b.todayCheckins, 0) > 0 ? "active" : "pending"} for today.
            </p>
          </div>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-white flex items-center gap-3">
            Your Branches
            <span className="px-2 py-0.5 bg-white/5 border border-white/10 rounded text-[10px] text-zinc-500 uppercase tracking-widest">
              {branchData.length} Total
            </span>
          </h2>
          <p className="text-zinc-500 text-sm mt-1">Real-time performance tracking per location</p>
        </div>

        <div className="flex items-center gap-3">
          <button 
            onClick={() => router.push("/dashboard/gyms")}
            className="flex items-center gap-2 px-6 py-3 bg-[#F1C40F] hover:bg-[#D4AC0D] text-black font-bold rounded-xl transition-all shadow-lg shadow-[#F1C40F]/10 uppercase text-[10px] tracking-widest"
          >
            <Plus size={18} />
            New Branch
          </button>

          <button 
            onClick={() => refetch()}
            disabled={isRefetching}
            className="p-3 bg-white/5 hover:bg-white/10 border border-zinc-800 rounded-xl text-zinc-400 transition-all disabled:opacity-50"
          >
            <RefreshCcw size={18} className={isRefetching ? "animate-spin text-[#F1C40F]" : ""} />
          </button>
          
          <select 
            value={days}
            onChange={(e) => setDays(Number(e.target.value))}
            className="bg-[#121721] border border-zinc-800 rounded-xl px-4 py-2.5 text-[10px] text-zinc-400 uppercase font-black tracking-widest outline-none cursor-pointer hover:border-[#F1C40F]/50 transition-colors"
          >
            <option value={30}>Last 30 Days</option>
            <option value={90}>Last 90 Days</option>
          </select>
        </div>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {[1, 2, 3].map((i) => (
            <div key={i} className="bg-[#121721] border border-zinc-800 rounded-2xl p-6 h-64 animate-pulse" />
          ))}
        </div>
      ) : branchData.length === 0 ? (
        <div className="bg-[#121721] border border-zinc-800 rounded-2xl p-16 text-center">
          <div className="w-20 h-20 bg-white/5 rounded-full flex items-center justify-center mx-auto mb-6">
            <RefreshCcw size={32} className="text-zinc-700" />
          </div>
          <h3 className="text-white font-bold text-lg">No branches found</h3>
          <p className="text-zinc-500 text-sm mt-2">You haven&apos;t added any branches to your gym yet.</p>
        </div>
      ) : (
        <div className={clsx(
          "grid gap-6",
          branchData.length === 1 ? "grid-cols-1" : 
          branchData.length === 2 ? "grid-cols-1 md:grid-cols-2" : 
          "grid-cols-1 md:grid-cols-2 xl:grid-cols-3"
        )}>
          {branchData.map((branch, index) => (
            <div 
              key={branch.id} 
              className={clsx(
                "transition-all duration-500",
                branchData.length === 4 && index === 3 ? "xl:col-span-3 lg:col-span-2" : ""
              )}
            >
              <BranchCard branch={branch} />
            </div>
          ))}
        </div>
      )}

      {/* Mini Summary Footer */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mt-12">
        <div className="p-4 bg-white/[0.02] border border-white/5 rounded-xl">
          <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest mb-1">Total Portfolio Revenue</p>
          <p className="text-white font-bold text-xl">${totalRevenue.toLocaleString()}</p>
        </div>
        <div className="p-4 bg-white/[0.02] border border-white/5 rounded-xl">
          <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest mb-1">Total Active Members</p>
          <p className="text-white font-bold text-xl">{totalMembers.toLocaleString()}</p>
        </div>
      </div>
    </div>
  );
}
