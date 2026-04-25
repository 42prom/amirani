"use client";

import {
  Users,
  DollarSign,
  Activity,
  UserCheck,
  ChevronRight,
  MapPin,
  Clock,
  DoorOpen,
  Trophy,
  BarChart3,
} from "lucide-react";
import Link from "next/link";

interface BranchCardProps {
  branch: {
    id: string;
    name: string;
    city: string;
    country: string;
    activeMembers: number;
    trainerCount: number;
    todayCheckins: number;
    monthRevenue: number;
    // Added placeholders for missing requirements to match the design
    visitorsToday?: number;
    doorActivityToday?: number;
    staffPerformance?: number; // percentage
  };
}

export function BranchCard({ branch }: BranchCardProps) {
  return (
    <div>
    <Link
      href={`/dashboard/gyms/${branch.id}`}
      className="block bg-[#121721] border border-zinc-800 rounded-2xl p-6 hover:border-[#F1C40F]/40 transition-all group relative overflow-hidden"
    >
      {/* Background Glow Effect on Hover */}
      <div className="absolute -right-10 -top-10 w-32 h-32 bg-[#F1C40F]/5 rounded-full blur-3xl group-hover:bg-[#F1C40F]/10 transition-all" />
      
      <div className="flex items-start justify-between mb-6 relative z-10">
        <div>
          <h3 className="text-white font-bold text-lg group-hover:text-[#F1C40F] transition-colors flex items-center gap-2">
            {branch.name}
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
          </h3>
          <div className="flex items-center gap-1.5 text-zinc-500 text-sm mt-1">
            <MapPin size={14} className="text-zinc-600" />
            {branch.city}{branch.country ? `, ${branch.country}` : ""}
          </div>
        </div>
        <div className="w-10 h-10 bg-white/5 rounded-xl flex items-center justify-center text-zinc-500 group-hover:text-[#F1C40F] group-hover:bg-[#F1C40F]/10 transition-all">
          <ChevronRight size={20} />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 relative z-10">
        {/* Check-ins */}
        <div className="bg-white/[0.03] rounded-xl p-4 border border-white/5">
          <div className="flex items-center gap-2 text-zinc-400 text-[10px] uppercase tracking-widest font-black mb-2">
            <Activity size={12} className="text-[#F1C40F]" />
            Check-ins Today
          </div>
          <div className="flex items-baseline gap-2">
            <p className="text-white font-bold text-2xl">{branch.todayCheckins}</p>
            <span className="text-green-500 text-[10px] font-bold">+12%</span>
          </div>
        </div>

        {/* Revenue */}
        <div className="bg-white/[0.03] rounded-xl p-4 border border-white/5">
          <div className="flex items-center gap-2 text-zinc-400 text-[10px] uppercase tracking-widest font-black mb-2">
            <DollarSign size={12} className="text-[#F1C40F]" />
            Monthly Revenue
          </div>
          <p className="text-[#F1C40F] font-bold text-2xl">
            ${branch.monthRevenue.toLocaleString()}
          </p>
        </div>

        {/* Door Activity */}
        <div className="bg-white/[0.03] rounded-xl p-4 border border-white/5">
          <div className="flex items-center gap-2 text-zinc-400 text-[10px] uppercase tracking-widest font-black mb-2">
            <DoorOpen size={12} className="text-[#F1C40F]" />
            Door Activity
          </div>
          <p className="text-white font-bold text-xl">{branch.doorActivityToday ?? "—"}</p>
        </div>

        {/* Active Members */}
        <div className="bg-white/[0.03] rounded-xl p-4 border border-white/5">
          <div className="flex items-center gap-2 text-zinc-400 text-[10px] uppercase tracking-widest font-black mb-2">
            <UserCheck size={12} className="text-[#F1C40F]" />
            Members
          </div>
          <p className="text-white font-bold text-xl">{branch.activeMembers}</p>
        </div>

        {/* Staff Performance */}
        <div className="col-span-2 bg-white/[0.03] rounded-xl p-4 border border-white/5 mt-2">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2 text-zinc-400 text-[10px] uppercase tracking-widest font-black">
              <Trophy size={12} className="text-[#F1C40F]" />
              Staff Performance
            </div>
            <span className="text-[#F1C40F] text-xs font-bold">{branch.staffPerformance ?? 0}%</span>
          </div>
          <div className="w-full bg-white/5 h-1.5 rounded-full overflow-hidden">
            <div 
              className="bg-[#F1C40F] h-full rounded-full transition-all duration-1000"
              style={{ width: `${branch.staffPerformance ?? 0}%` }}
            />
          </div>
        </div>
      </div>
      
      {/* Footer Info */}
      <div className="mt-6 pt-4 border-t border-white/5 flex items-center justify-between text-[10px] text-zinc-500 uppercase tracking-widest font-bold">
        <div className="flex items-center gap-1.5">
          <Users size={12} />
          {branch.trainerCount} Staff
        </div>
        <div className="flex items-center gap-1.5">
          <Clock size={12} />
          Live Update
        </div>
      </div>
    </Link>

    <Link
      href={`/dashboard/analytics/${branch.id}`}
      className="mt-2 flex items-center justify-center gap-2 w-full py-2.5 bg-white/[0.02] hover:bg-[#F1C40F]/8 border border-white/5 hover:border-[#F1C40F]/30 rounded-xl text-zinc-500 hover:text-[#F1C40F] transition-all text-[10px] uppercase tracking-widest font-black"
      onClick={e => e.stopPropagation()}
    >
      <BarChart3 size={12} />
      Analytics Deep Dive
    </Link>
    </div>
  );
}
