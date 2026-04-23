"use client";

import { useState } from "react";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery } from "@tanstack/react-query";
import { gymsApi, adminApi } from "@/lib/api";
import {
  Building2,
  Users,
  Dumbbell,
  TrendingUp,
  Activity,
  ArrowRight,
} from "lucide-react";
import Link from "next/link";
import { type GymOwner } from "@/lib/api";
import { X, Phone, MapPin, Building, ChevronRight } from "lucide-react";


function StatCard({
  title,
  value,
  icon: Icon,
  trend,
}: {
  title: string;
  value: string | number;
  icon: React.ElementType;
  trend?: string;
}) {
  return (
    <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-zinc-400">{title}</p>
          <p className="text-3xl font-bold text-white mt-2">{value}</p>
          {trend && (
            <p className="text-sm text-green-400 mt-2 flex items-center gap-1">
              <TrendingUp size={14} />
              {trend}
            </p>
          )}
        </div>
        <div className="w-12 h-12 bg-[#F1C40F]/10 rounded-lg flex items-center justify-center">
          <Icon className="text-[#F1C40F]" size={24} />
        </div>
      </div>
    </div>
  );
}

function GymOwnerDetailsModal({
  owner,
  onClose,
}: {
  owner: GymOwner;
  onClose: () => void;
}) {
  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden animate-in zoom-in duration-200">
        <div className="p-6 border-b border-zinc-800 flex items-center justify-between bg-white/[0.02]">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-[#F1C40F]/10 rounded-full flex items-center justify-center text-[#F1C40F] font-bold text-lg">
              {owner.fullName.charAt(0)}
            </div>
            <div>
              <h3 className="text-xl font-bold text-white">{owner.fullName}</h3>
              <p className="text-sm text-zinc-500">{owner.email}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-white/5 rounded-lg text-zinc-500 hover:text-white transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 bg-white/5 rounded-xl border border-white/5">
              <div className="flex items-center gap-2 text-zinc-400 text-xs uppercase tracking-widest font-bold mb-2">
                <Phone size={14} className="text-[#F1C40F]" />
                Contact Info
              </div>
              <p className="text-white font-medium">{owner.phoneNumber || "Not provided"}</p>
            </div>
            <div className="p-4 bg-white/5 rounded-xl border border-white/5">
              <div className="flex items-center gap-2 text-zinc-400 text-xs uppercase tracking-widest font-bold mb-2">
                <MapPin size={14} className="text-[#F1C40F]" />
                HQ Address
              </div>
              <p className="text-white font-medium truncate">{owner.address || "Not provided"}</p>
            </div>
          </div>

          <div>
            <div className="flex items-center justify-between mb-4">
              <h4 className="text-sm font-bold text-white uppercase tracking-widest flex items-center gap-2">
                <Building size={16} className="text-[#F1C40F]" />
                Managed Branches ({owner.ownedGyms.length})
              </h4>
            </div>
            <div className="space-y-2 max-h-48 overflow-y-auto pr-2 amirani-scrollbar">
              {owner.ownedGyms.map((gym) => (
                <div
                  key={gym.id}
                  className="p-3 bg-white/[0.02] border border-white/5 rounded-lg flex items-center justify-between"
                >
                  <div>
                    <p className="text-sm font-medium text-white">{gym.name}</p>
                    <p className="text-xs text-zinc-500">{gym.city}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <div className="text-right">
                      <p className="text-[10px] text-zinc-500 uppercase font-black">Members</p>
                      <p className="text-xs font-bold text-[#F1C40F]">{gym._count.memberships}</p>
                    </div>
                    <span className={`w-2 h-2 rounded-full ${gym.isActive ? "bg-green-500" : "bg-red-500"}`} />
                  </div>
                </div>
              ))}
              {owner.ownedGyms.length === 0 && (
                <p className="text-center text-zinc-500 text-sm py-4">No branches registered yet</p>
              )}
            </div>
          </div>
        </div>

        <div className="p-6 border-t border-zinc-800 bg-white/[0.02] flex justify-end">
          <button
            onClick={onClose}
            className="px-6 py-2 bg-[#F1C40F] !text-black font-bold uppercase tracking-widest text-[10px] rounded-lg hover:bg-[#F4D03F] transition-colors"
          >
            Close Profile
          </button>
        </div>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const { user, token } = useAuthStore();
  const [selectedOwner, setSelectedOwner] = useState<GymOwner | null>(null);
  const superAdmin = isSuperAdmin(user?.role);

  const { data: gyms, isLoading: gymsLoading } = useQuery({
    queryKey: ["gyms"],
    queryFn: () => gymsApi.getAll(token!),
    enabled: !!token,
  });

  const { data: gymOwners } = useQuery({
    queryKey: ["gym-owners"],
    queryFn: () => adminApi.getGymOwners(token!),
    enabled: !!token && superAdmin,
  });


  const totalMembers = gyms?.reduce((acc, gym) => acc + gym._count.memberships, 0) || 0;
  const totalTrainers = gyms?.reduce((acc, gym) => acc + gym._count.trainers, 0) || 0;
  const totalEquipment = gyms?.reduce((acc, gym) => acc + gym._count.equipment, 0) || 0;

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-white">
          Welcome back, {user?.fullName?.split(" ")[0]}
        </h1>
        <p className="text-zinc-400 mt-1">
          {superAdmin
            ? "Here's an overview of the entire platform"
            : "Here's an overview of your gyms"}
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {superAdmin ? (
          <>
            <StatCard
              title="Gym Owners"
              value={gymOwners?.length || 0}
              icon={Users}
              trend="+2 this month"
            />
            <StatCard
              title="Total Gyms"
              value={gyms?.length || 0}
              icon={Building2}
            />
          </>
        ) : (
          <>
            <StatCard
              title="Your Gyms"
              value={gyms?.length || 0}
              icon={Building2}
            />
            <StatCard
              title="Total Members"
              value={totalMembers}
              icon={Users}
              trend="+12% from last month"
            />
            <StatCard
              title="Total Staff"
              value={totalTrainers}
              icon={Activity}
            />
            <StatCard
              title="Equipment Items"
              value={totalEquipment}
              icon={Dumbbell}
            />
          </>
        )}
      </div>

      {/* Gym Owners List - Only for Super Admin */}
      {superAdmin && (
        <div className="bg-[#121721] border border-zinc-800 rounded-xl">
          <div className="p-6 border-b border-zinc-800 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-white">Platform Partners (Gym Owners)</h2>
            <Link 
              href="/dashboard/gym-owners"
              className="text-[#F1C40F] text-xs font-bold uppercase tracking-wider hover:underline flex items-center gap-1"
            >
              Manage All
              <ArrowRight size={14} />
            </Link>
          </div>

          {!gymOwners ? (
            <div className="p-12 text-center text-zinc-400">Loading partners...</div>
          ) : gymOwners.length === 0 ? (
            <div className="p-12 text-center text-zinc-400">No gym owners registered yet</div>
          ) : (
            <div className="divide-y divide-zinc-800">
              {gymOwners.slice(0, 5).map((owner) => (
                <div
                  key={owner.id}
                  className="p-6 flex items-center justify-between hover:bg-zinc-800/50 transition-colors cursor-pointer group"
                  onClick={() => setSelectedOwner(owner)}
                >
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 bg-[#F1C40F]/10 rounded-full flex items-center justify-center text-[#F1C40F] font-bold">
                      {owner.fullName.charAt(0)}
                    </div>
                    <div>
                      <p className="font-medium text-white group-hover:text-[#F1C40F] transition-colors">{owner.fullName}</p>
                      <p className="text-sm text-zinc-500">{owner.email}</p>
                    </div>
                  </div>
                  
                  <div className="flex items-center gap-10">
                    <div className="text-center">
                      <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest mb-1">Branches</p>
                      <div className="flex items-center gap-2 justify-center">
                        <Building2 size={14} className="text-zinc-400" />
                        <span className="text-white font-bold">{owner.ownedGyms.length}</span>
                      </div>
                    </div>
                    
                    <div className="text-center">
                      <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest mb-1">Total Members</p>
                      <div className="flex items-center gap-2 justify-center">
                        <Users size={14} className="text-zinc-400" />
                        <span className="text-white font-bold">
                          {owner.ownedGyms.reduce((acc, g) => acc + g._count.memberships, 0)}
                        </span>
                      </div>
                    </div>

                    <div className="flex items-center gap-3 pl-6 border-l border-zinc-800">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-black uppercase tracking-tighter ${
                        owner.isActive ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"
                      }`}>
                        {owner.isActive ? "Active" : "Inactive"}
                      </span>
                      <div className="p-2 bg-white/5 rounded-lg text-zinc-500 group-hover:text-[#F1C40F] group-hover:bg-[#F1C40F]/10 transition-all">
                        <ChevronRight size={18} />
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Gyms List - Only for Gym Owners */}
      {!superAdmin && (
        <div className="bg-[#121721] border border-zinc-800 rounded-xl">
          <div className="p-6 border-b border-zinc-800">
            <h2 className="text-lg font-semibold text-white">Your Gyms</h2>
          </div>

          {gymsLoading ? (
            <div className="p-6 text-center text-zinc-400">Loading gyms...</div>
          ) : gyms?.length === 0 ? (
            <div className="p-6 text-center text-zinc-400">No gyms found</div>
          ) : (
            <div className="divide-y divide-zinc-800">
              {gyms?.map((gym) => (
                <div
                  key={gym.id}
                  className="p-6 flex items-center justify-between hover:bg-zinc-800/50 transition-colors"
                >
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 bg-[#F1C40F]/10 rounded-lg flex items-center justify-center">
                      <Building2 className="text-[#F1C40F]" size={24} />
                    </div>
                    <div>
                      <p className="font-medium text-white">{gym.name}</p>
                      <p className="text-sm text-zinc-400">
                        {gym.city}, {gym.country}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-8 text-sm">
                    <div className="text-center">
                      <p className="text-zinc-400">Members</p>
                      <p className="font-semibold text-white">{gym._count.memberships}</p>
                    </div>
                    <div className="text-center">
                      <p className="text-zinc-400">Staff</p>
                      <p className="font-semibold text-white">{gym._count.trainers}</p>
                    </div>
                    <div className="text-center">
                      <p className="text-zinc-400">Equipment</p>
                      <p className="font-semibold text-white">{gym._count.equipment}</p>
                    </div>
                    <span
                      className={`px-3 py-1 rounded-full text-xs font-medium ${
                        gym.isActive
                          ? "bg-green-500/10 text-green-400"
                          : "bg-red-500/10 text-red-400"
                      }`}
                    >
                      {gym.isActive ? "Active" : "Inactive"}
                    </span>
                    
                    {/* Actions */}
                    <div className="flex items-center gap-2 border-l border-zinc-800 pl-6 ml-2">
                      <Link
                        href={`/dashboard/gyms/${gym.id}`}
                        className="inline-flex items-center gap-2 px-4 py-2 bg-white/5 hover:bg-white/10 text-white text-xs font-bold uppercase tracking-wider rounded-lg transition-colors"
                      >
                        View
                        <ArrowRight size={14} />
                      </Link>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Details Modal */}
      {selectedOwner && (
        <GymOwnerDetailsModal
          owner={selectedOwner}
          onClose={() => setSelectedOwner(null)}
        />
      )}
    </div>
  );
}
