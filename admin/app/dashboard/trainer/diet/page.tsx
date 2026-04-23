"use client";

import { useAuthStore } from "@/lib/auth-store";
import { useQuery } from "@tanstack/react-query";
import { trainerApi } from "@/lib/api";
import { ClipboardList, ChevronRight } from "lucide-react";
import Link from "next/link";

export default function TrainerAllDietsPage() {
  const { token } = useAuthStore();
  const { data: members, isLoading } = useQuery({
    queryKey: ["trainer-members"],
    queryFn: () => trainerApi.getMembers(token!),
    enabled: !!token,
  });

  return (
    <div>
      <div className="flex items-center gap-3 mb-6">
        <ClipboardList size={20} className="text-[#F1C40F]" />
        <h1 className="text-xl font-bold text-white">Diet Plans</h1>
      </div>
      <p className="text-zinc-500 text-sm mb-6">Select a member to view or create diet plans.</p>

      {isLoading ? (
        <p className="text-zinc-500">Loading members...</p>
      ) : !members?.length ? (
        <p className="text-zinc-500">No members assigned.</p>
      ) : (
        <div className="space-y-2">
          {members.map((m) => (
            <Link
              key={m.id}
              href={`/dashboard/trainer/members/${m.user.id}/diet`}
              className="flex items-center justify-between bg-[#121721] border border-zinc-800 rounded-xl px-5 py-4 hover:border-zinc-600 transition-colors group"
            >
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-[#F1C40F]/15 flex items-center justify-center">
                  <span className="text-[#F1C40F] font-bold text-xs">
                    {m.user.fullName.charAt(0).toUpperCase()}
                  </span>
                </div>
                <div>
                  <p className="font-semibold text-white text-sm">{m.user.fullName}</p>
                  <p className="text-xs text-zinc-500">{m.user.email}</p>
                </div>
              </div>
              <ChevronRight size={16} className="text-zinc-600 group-hover:text-[#F1C40F] transition-colors" />
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
