"use client";

import React, { useEffect, useState, useCallback } from "react";
import { useParams } from "next/navigation";
import { useAuthStore } from "@/lib/auth-store";
import { gymsApi, Branch } from "@/lib/api";
import { 
  MapPin, 
  Plus, 
  Store, 
  Trash2, 
  Edit2, 
  RefreshCw, 
  X, 
  Shield
} from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import { ActionButton } from "@/components/ui/ActionButton";

export default function BranchesPage() {
  const { gymId } = useParams();
  const { token } = useAuthStore();
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Form State
  const [newBranch, setNewBranch] = useState({
    name: "",
    address: "",
  });

  const fetchBranches = useCallback(async () => {
    if (!token || !gymId) return;
    try {
      setLoading(true);
      const gym = await gymsApi.getById(gymId as string, token);
      setBranches(gym.branches || []);
    } catch (err) {
      console.error("Failed to fetch branches:", err);
    } finally {
      setLoading(false);
    }
  }, [gymId, token]);

  useEffect(() => {
    fetchBranches();
  }, [fetchBranches]);

  const handleCreate = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!token || !gymId || !newBranch.name) return;

    try {
      setIsSubmitting(true);
      setError(null);
      
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || "http://localhost:3085/api"}/gym-owner/gyms/${gymId}/branches`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(newBranch)
      });

      if (!response.ok) {
        const errData = await response.json().catch(() => ({}));
        throw new Error(errData.message || "Failed to create branch");
      }

      setIsModalOpen(false);
      setNewBranch({ name: "", address: "" });
      fetchBranches();
    } catch (err) {
      console.error("Create error:", err);
      setError(err instanceof Error ? err.message : "Failed to create branch");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center h-[400px] gap-4">
        <RefreshCw className="h-10 w-10 animate-spin text-[#F1C40F]" />
        <p className="text-zinc-500 font-black uppercase text-[10px] tracking-[0.3em]">Synching Locations...</p>
      </div>
    );
  }

  return (
    <div className="space-y-10">
      <PageHeader
        title="GYM BRANCHES"
        description="Physical location management and multi-facility deployment"
        icon={<Store size={32} />}
        actions={
          <ActionButton
            icon={Plus}
            label="ADD BRANCH"
            variant="primary"
            onClick={() => setIsModalOpen(true)}
          />
        }
      />

      <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
        {branches.length === 0 ? (
          <div className="col-span-full py-20 bg-white/[0.01] border border-dashed border-white/10 rounded-[2.5rem] flex flex-col items-center justify-center text-center">
            <div className="w-16 h-16 bg-white/[0.02] border border-white/5 rounded-2xl flex items-center justify-center mb-6">
              <Store className="h-8 w-8 text-zinc-700" />
            </div>
            <h3 className="text-xl font-black text-white italic uppercase tracking-tighter">No branches detected</h3>
            <p className="text-zinc-500 text-xs mt-2 font-bold uppercase tracking-widest max-w-xs">Initialize your first physical facility to begin multi-location management.</p>
            <button 
              onClick={() => setIsModalOpen(true)} 
              className="mt-8 px-8 py-4 bg-white/5 text-white border border-white/5 rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F] hover:text-black hover:border-transparent transition-all"
            >
              CREATE INITIAL BRANCH
            </button>
          </div>
        ) : (
          branches.map((branch) => (
            <div key={branch.id} className="group relative bg-[#121721] border border-white/5 rounded-[2.5rem] overflow-hidden hover:border-[#F1C40F]/30 transition-all duration-500 shadow-2xl">
              <div className="absolute inset-0 bg-gradient-to-br from-[#F1C40F]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
              
              <div className="p-8 space-y-6 relative z-10">
                <div className="flex justify-between items-start">
                  <div className="flex items-center gap-4">
                    <div className="p-4 bg-white/[0.02] border border-white/5 rounded-2xl group-hover:border-[#F1C40F]/30 transition-colors">
                      <Store className="h-6 w-6 text-[#F1C40F]" />
                    </div>
                    <div>
                      <h4 className="text-lg font-black text-white tracking-tight uppercase italic">{branch.name}</h4>
                      <div className="flex items-center gap-1.5 mt-1">
                        <div className="w-1 h-1 rounded-full bg-emerald-500 animate-pulse" />
                        <span className="text-[9px] font-black text-emerald-500 uppercase tracking-widest">Active Facility</span>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <div className="flex items-start gap-3 p-4 bg-white/[0.02] rounded-2xl border border-white/5">
                    <MapPin className="h-4 w-4 text-zinc-500 mt-0.5" />
                    <p className="text-[11px] text-zinc-400 font-bold leading-relaxed">{branch.address || "NO ADDRESS RECORDED"}</p>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div className="bg-black/20 p-4 rounded-2xl border border-white/5 text-center">
                      <p className="text-[8px] font-black text-zinc-600 uppercase tracking-widest mb-1">Total Members</p>
                      <p className="text-xl font-black text-white italic tracking-tighter">--</p>
                    </div>
                    <div className="bg-black/20 p-4 rounded-2xl border border-white/5 text-center">
                      <p className="text-[8px] font-black text-zinc-600 uppercase tracking-widest mb-1">Support Staff</p>
                      <p className="text-xl font-black text-white italic tracking-tighter">--</p>
                    </div>
                  </div>
                </div>

                <div className="flex gap-2 pt-2">
                  <button className="flex-1 px-4 py-3.5 bg-white/[0.02] border border-white/5 rounded-xl text-[9px] font-black uppercase tracking-widest text-zinc-500 hover:text-white hover:bg-white/5 transition-all flex items-center justify-center gap-2">
                    <Edit2 size={12} className="text-[#F1C40F]" />
                    CONFIGURE
                  </button>
                  <button className="px-4 py-3.5 bg-red-500/5 border border-red-500/10 rounded-xl text-red-500 hover:bg-red-500/20 transition-all flex items-center justify-center">
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* CUSTOM MODAL OVERLAY */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
          <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-lg max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.8)] overflow-hidden animate-in zoom-in-95 duration-300">
            {/* MODAL HEADER */}
            <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
              <div>
                <h2 className="text-2xl font-black text-white tracking-tight flex items-center gap-3 italic uppercase">
                  <Shield className="text-[#F1C40F]" size={28} />
                  GENERATE BRANCH
                </h2>
                <p className="text-zinc-500 text-[10px] font-black uppercase tracking-[0.2em] mt-1">Deploy New Physical Facility</p>
              </div>
              <button 
                onClick={() => setIsModalOpen(false)} 
                className="p-3 bg-white/5 text-zinc-500 hover:text-white hover:bg-white/10 rounded-2xl transition-all border border-white/5 shadow-inner"
              >
                <X size={24} />
              </button>
            </div>

            {/* MODAL CONTENT */}
            <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
              <form id="branch-form" onSubmit={handleCreate} className="space-y-6">
                <div className="group">
                  <label className="amirani-label font-black text-[10px] tracking-[0.2em] mb-2 inline-block">FACILITY NAME</label>
                  <input
                    type="text"
                    required
                    value={newBranch.name}
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewBranch({ ...newBranch, name: e.target.value })}
                    className="amirani-input h-[58px] font-black text-sm tracking-tight italic uppercase placeholder:text-zinc-700"
                    placeholder="e.g. BATUMI CENTRAL BRANCH"
                  />
                </div>

                <div className="group">
                  <label className="amirani-label font-black text-[10px] tracking-[0.2em] mb-2 inline-block">PHYSICAL ADDRESS</label>
                  <input
                    type="text"
                    required
                    value={newBranch.address}
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewBranch({ ...newBranch, address: e.target.value })}
                    className="amirani-input h-[58px] font-black text-sm tracking-tight italic uppercase placeholder:text-zinc-700"
                    placeholder="Street, City, Postal Code"
                  />
                </div>

                {error && (
                  <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-500 text-[10px] font-black uppercase tracking-widest leading-relaxed flex items-center gap-3">
                    <div className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />
                    {error}
                  </div>
                )}
              </form>
            </div>

            {/* MODAL FOOTER */}
            <div className="p-8 border-t border-white/5 bg-white/[0.01] flex gap-4 shrink-0">
              <button
                type="button"
                onClick={() => setIsModalOpen(false)}
                className="flex-1 px-8 py-5 rounded-2xl border border-white/10 text-zinc-500 font-black uppercase tracking-widest hover:bg-white/5 hover:text-white transition-all text-[10px]"
              >
                ABORT
              </button>
              <button
                form="branch-form"
                type="submit"
                disabled={isSubmitting || !newBranch.name}
                className="flex-[2] px-8 py-5 rounded-2xl bg-[#F1C40F] !text-black font-black uppercase tracking-widest hover:bg-[#D4AC0D] transition-all shadow-2xl shadow-[#F1C40F]/20 disabled:opacity-50 text-[10px] flex items-center justify-center gap-3"
              >
                {isSubmitting ? (
                  <RefreshCw className="animate-spin" size={18} />
                ) : (
                  <>
                    <Plus size={18} />
                    INITIALIZE FACILITY
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
