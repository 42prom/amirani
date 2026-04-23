"use client";

import React, { useState, useEffect } from "react";
import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { trainerApi, assignmentApi, type TrainerAssignedMember, type AssignmentRequest } from "@/lib/api";
import { Users, Dumbbell, ChevronRight, Activity, UserCheck, UserX, Clock } from "lucide-react";
import Link from "next/link";
import Image from "next/image";

function calcAge(dob: string | null, now: number | null): string {
  if (!dob || !now) return "—";
  const diff = now - new Date(dob).getTime();
  return `${Math.floor(diff / 3.156e10)}y`;
}

function MemberCard({ m, now }: { m: TrainerAssignedMember; now: number | null }) {
  const initials = m.user.fullName
    .split(" ")
    .map((w) => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="bg-[#121721] border border-zinc-800 rounded-xl p-5 flex items-center justify-between hover:border-zinc-700 transition-colors group">
      <div className="flex items-center gap-4">
        {m.user.avatarUrl ? (
          <Image
            src={m.user.avatarUrl}
            alt={m.user.fullName}
            width={48}
            height={48}
            className="w-12 h-12 rounded-full object-cover"
          />
        ) : (
          <div className="w-12 h-12 rounded-full bg-[#F1C40F]/15 flex items-center justify-center flex-shrink-0">
            <span className="text-[#F1C40F] font-bold text-sm">{initials}</span>
          </div>
        )}
        <div>
          <p className="font-semibold text-white">{m.user.fullName}</p>
          <p className="text-xs text-zinc-500">{m.user.email}</p>
          <div className="flex items-center gap-3 mt-1">
            {m.user.weight && (
              <span className="text-[10px] text-zinc-600 font-medium">{m.user.weight} kg</span>
            )}
            {m.user.height && (
              <span className="text-[10px] text-zinc-600 font-medium">{m.user.height} cm</span>
            )}
            <span className="text-[10px] text-zinc-600 font-medium">{calcAge(m.user.dob, now)}</span>
            {m.user.gender && (
              <span className="text-[10px] text-zinc-600 font-medium capitalize">{m.user.gender}</span>
            )}
          </div>
        </div>
      </div>

      <div className="flex items-center gap-4">
        {m.plan && (
          <div className="text-right hidden sm:block">
            <p className="text-[9px] font-black uppercase tracking-widest text-zinc-600">Plan</p>
            <p className="text-xs font-medium text-zinc-300 truncate max-w-[120px]">{m.plan.name}</p>
          </div>
        )}
        <Link
          href={`/dashboard/trainer/members/${m.user.id}`}
          className="flex items-center gap-2 px-4 py-2 bg-zinc-800 hover:bg-[#F1C40F]/10 hover:text-[#F1C40F] text-zinc-300 text-xs font-bold uppercase tracking-wider rounded-lg transition-colors"
        >
          Manage
          <ChevronRight size={14} />
        </Link>
      </div>
    </div>
  );
}

function RequestCard({ req, onApprove, onReject, loading, now }: {
  req: AssignmentRequest;
  onApprove: () => void;
  onReject: () => void;
  loading: boolean;
  now: number | null;
}) {
  function calcAge(dob: string | null | undefined): string {
    if (!dob || !now) return "";
    const diff = now - new Date(dob).getTime();
    return `${Math.floor(diff / 3.156e10)}y`;
  }

  return (
    <div className="bg-[#0e1420] border border-amber-500/20 rounded-xl p-4 flex items-center justify-between gap-4">
      <div className="flex items-center gap-3 min-w-0">
        {req.member.avatarUrl ? (
          <Image 
            src={req.member.avatarUrl} 
            alt={req.member.fullName} 
            width={40}
            height={40}
            className="w-10 h-10 rounded-full object-cover flex-shrink-0" 
          />
        ) : (
          <div className="w-10 h-10 rounded-full bg-amber-500/15 flex items-center justify-center flex-shrink-0">
            <span className="text-amber-400 font-bold text-xs">
              {req.member.fullName.split(" ").map(w => w[0]).join("").slice(0, 2).toUpperCase()}
            </span>
          </div>
        )}
        <div className="min-w-0">
          <p className="font-semibold text-white text-sm truncate">{req.member.fullName}</p>
          <div className="flex items-center gap-2 mt-0.5 flex-wrap">
            {req.member.weight && <span className="text-[10px] text-zinc-500">{req.member.weight}kg</span>}
            {req.member.height && <span className="text-[10px] text-zinc-500">{req.member.height}cm</span>}
            {req.member.dob && <span className="text-[10px] text-zinc-500">{calcAge(req.member.dob)}</span>}
            {req.member.gender && <span className="text-[10px] text-zinc-500 capitalize">{req.member.gender}</span>}
          </div>
          {req.message && <p className="text-xs text-zinc-400 mt-1 italic truncate max-w-[200px]">&quot;{req.message}&quot;</p>}
        </div>
      </div>
      <div className="flex items-center gap-2 flex-shrink-0">
        <button
          onClick={onApprove}
          disabled={loading}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-green-600/20 hover:bg-green-600/30 text-green-400 text-xs font-bold rounded-lg border border-green-600/30 transition-colors disabled:opacity-50"
        >
          <UserCheck size={13} />
          Accept
        </button>
        <button
          onClick={onReject}
          disabled={loading}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-red-600/10 hover:bg-red-600/20 text-red-400 text-xs font-bold rounded-lg border border-red-600/20 transition-colors disabled:opacity-50"
        >
          <UserX size={13} />
          Decline
        </button>
      </div>
    </div>
  );
}

export default function TrainerDashboardPage() {
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();

  const [now, setNow] = useState<number | null>(null);
  useEffect(() => {
    const handle = requestAnimationFrame(() => {
      setNow(Date.now());
    });
    return () => cancelAnimationFrame(handle);
  }, []);

  const { data: members, isLoading } = useQuery({
    queryKey: ["trainer-members"],
    queryFn: () => trainerApi.getMembers(token!),
    enabled: !!token,
  });

  const { data: stats } = useQuery({
    queryKey: ["trainer-dashboard"],
    queryFn: () => trainerApi.getDashboard(token!),
    enabled: !!token,
  });

  const { data: pendingRequests } = useQuery({
    queryKey: ["trainer-pending-requests"],
    queryFn: () => assignmentApi.getPendingRequests(token!),
    enabled: !!token,
    refetchInterval: 30_000,
  });

  const approveMutation = useMutation({
    mutationFn: (requestId: string) => assignmentApi.approveRequest(requestId, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trainer-pending-requests"] });
      queryClient.invalidateQueries({ queryKey: ["trainer-members"] });
      queryClient.invalidateQueries({ queryKey: ["trainer-dashboard"] });
    },
  });

  const rejectMutation = useMutation({
    mutationFn: (requestId: string) => assignmentApi.rejectRequest(requestId, token!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["trainer-pending-requests"] }),
  });

  return (
    <div>
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-white">
          Welcome, {user?.fullName?.split(" ")[0]}
        </h1>
        <p className="text-zinc-400 mt-1">Manage your assigned members and their plans</p>
      </div>

      {/* Pending Requests Panel */}
      {pendingRequests && pendingRequests.length > 0 && (
        <div className="bg-[#121721] border border-amber-500/25 rounded-xl overflow-hidden mb-6">
          <div className="px-6 py-4 border-b border-amber-500/15 flex items-center gap-2">
            <Clock size={16} className="text-amber-400" />
            <h2 className="font-semibold text-white">Assignment Requests</h2>
            <span className="ml-auto text-xs bg-amber-500/20 text-amber-400 font-bold px-2 py-0.5 rounded-full">
              {pendingRequests.length} pending
            </span>
          </div>
          <div className="p-4 space-y-3">
            {pendingRequests.map((req) => (
              <RequestCard
                key={req.id}
                req={req}
                loading={approveMutation.isPending || rejectMutation.isPending}
                onApprove={() => approveMutation.mutate(req.id)}
                onReject={() => rejectMutation.mutate(req.id)}
                now={now}
              />
            ))}
          </div>
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-5 flex items-center justify-between">
          <div>
            <p className="text-xs text-zinc-500 uppercase tracking-widest font-black">Total Members</p>
            <p className="text-3xl font-bold text-white mt-1">{stats?.totalMembers ?? members?.length ?? "—"}</p>
          </div>
          <Users size={24} className="text-[#F1C40F] opacity-60" />
        </div>
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-5 flex items-center justify-between">
          <div>
            <p className="text-xs text-zinc-500 uppercase tracking-widest font-black">Active Members</p>
            <p className="text-3xl font-bold text-white mt-1">{stats?.activeMembers ?? "—"}</p>
          </div>
          <Dumbbell size={24} className="text-[#F1C40F] opacity-60" />
        </div>
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-5 flex items-center justify-between">
          <div>
            <p className="text-xs text-zinc-500 uppercase tracking-widest font-black">Today&apos;s Check-ins</p>
            <p className="text-3xl font-bold text-white mt-1">{stats?.todayCheckIns ?? "—"}</p>
          </div>
          <Activity size={24} className="text-[#F1C40F] opacity-60" />
        </div>
      </div>

      {/* Member list */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden">
        <div className="px-6 py-4 border-b border-zinc-800 flex items-center justify-between">
          <h2 className="font-semibold text-white flex items-center gap-2">
            <Users size={16} className="text-[#F1C40F]" />
            Assigned Members
          </h2>
          <span className="text-xs text-zinc-500">{members?.length ?? 0} total</span>
        </div>

        {isLoading ? (
          <div className="p-12 text-center text-zinc-500">Loading members...</div>
        ) : !members?.length ? (
          <div className="p-12 text-center text-zinc-500">
            No members assigned to you yet.
          </div>
        ) : (
          <div className="p-4 space-y-2">
            {members.map((m) => (
              <MemberCard key={m.id} m={m} now={now} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
