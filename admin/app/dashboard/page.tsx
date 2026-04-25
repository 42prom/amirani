"use client";

import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import dynamic from "next/dynamic";

// Dynamically import dashboards for better code splitting and to avoid SSR issues with Recharts
const SuperAdminDashboard = dynamic(() => import("@/components/dashboard/SuperAdminDashboard"), { 
  loading: () => <div className="h-screen flex items-center justify-center bg-[#121721] text-[#F1C40F] font-black uppercase tracking-[0.2em]">Initializing Platform...</div>,
  ssr: false 
});

const GymOwnerDashboard = dynamic(() => import("@/components/dashboard/GymOwnerDashboard"), { 
  loading: () => <div className="h-screen flex items-center justify-center bg-[#121721] text-[#F1C40F] font-black uppercase tracking-[0.2em]">Loading Gym Data...</div>,
  ssr: false 
});

export default function DashboardPage() {
  const { user } = useAuthStore();
  const superAdmin = isSuperAdmin(user?.role);

  return (
    <div className="min-h-screen pb-20">
      {/* ── Page Header ────────────────────────────────────────────────── */}
      <div className="mb-10">
        <h1 className="text-3xl font-black text-white tracking-tight uppercase">
          {superAdmin ? "Platform Intelligence" : "Branch Intelligence"}
        </h1>
        <div className="flex items-center gap-2 mt-2">
          <div className="h-1 w-12 bg-[#F1C40F]" />
          <p className="text-zinc-500 text-sm font-medium uppercase tracking-widest">
            Welcome, {user?.fullName?.split(" ")[0]} · {new Date().toLocaleDateString("en-US", { month: "long", year: "numeric" })}
          </p>
        </div>
      </div>

      {/* ── Dashboard Content ───────────────────────────────────────────── */}
      {superAdmin ? <SuperAdminDashboard /> : <GymOwnerDashboard />}
    </div>
  );
}

/* 
  LEGACY CODE PRESERVED FOR SAFETY (SCAFFOLDING)
  If any regression occurs, revert to the previous monolithic version.
  Last known stable monolithic version: 2026-04-25T17:31
*/
