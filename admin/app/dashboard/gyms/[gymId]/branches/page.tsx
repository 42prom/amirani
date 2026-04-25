"use client";

import React, { useState, useCallback } from "react";
import { useParams } from "next/navigation";
import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { branchesApi, Branch } from "@/lib/api";
import {
  MapPin,
  Plus,
  Store,
  Trash2,
  Edit2,
  RefreshCw,
  X,
  Shield,
  Users,
  Clock,
  Phone,
  CheckCircle,
  UserPlus,
} from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import { ActionButton } from "@/components/ui/ActionButton";

const EMPTY_FORM = {
  name: "",
  address: "",
  city: "",
  phone: "",
  maxCapacity: 50,
  openTime: "08:00",
  closeTime: "22:00",
};

export default function BranchesPage() {
  const { gymId } = useParams<{ gymId: string }>();
  const { token } = useAuthStore();
  const qc = useQueryClient();

  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editingBranch, setEditingBranch] = useState<Branch | null>(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [assignBranchId, setAssignBranchId] = useState<string | null>(null);
  const [adminEmail, setAdminEmail] = useState("");
  const [formError, setFormError] = useState<string | null>(null);

  const { data: branches = [], isLoading } = useQuery({
    queryKey: ["branches", gymId],
    queryFn: () => branchesApi.list(gymId, token!),
    enabled: !!token && !!gymId,
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ["branches", gymId] });

  const createMutation = useMutation({
    mutationFn: (data: typeof EMPTY_FORM) => branchesApi.create(gymId, token!, data),
    onSuccess: () => { setIsCreateOpen(false); setForm(EMPTY_FORM); invalidate(); },
    onError: (e: any) => setFormError(e.message ?? "Failed to create branch"),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<typeof EMPTY_FORM> }) =>
      branchesApi.update(gymId, id, token!, data),
    onSuccess: () => { setEditingBranch(null); invalidate(); },
    onError: (e: any) => setFormError(e.message ?? "Failed to update branch"),
  });

  const deleteMutation = useMutation({
    mutationFn: (branchId: string) => branchesApi.deactivate(gymId, branchId, token!),
    onSuccess: () => invalidate(),
  });

  const openEdit = useCallback((branch: Branch) => {
    setEditingBranch(branch);
    setForm({
      name: branch.name,
      address: branch.address ?? "",
      city: branch.city ?? "",
      phone: branch.phone ?? "",
      maxCapacity: branch.maxCapacity,
      openTime: branch.openTime ?? "08:00",
      closeTime: branch.closeTime ?? "22:00",
    });
    setFormError(null);
  }, []);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    if (editingBranch) {
      updateMutation.mutate({ id: editingBranch.id, data: form });
    } else {
      createMutation.mutate(form);
    }
  };

  const isSubmitting = createMutation.isPending || updateMutation.isPending;

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center h-[400px] gap-4">
        <RefreshCw className="h-10 w-10 animate-spin text-[#F1C40F]" />
        <p className="text-zinc-500 font-black uppercase text-[10px] tracking-[0.3em]">Synching Locations...</p>
      </div>
    );
  }

  const activeBranches = branches.filter((b) => b.isActive !== false);

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
            onClick={() => { setForm(EMPTY_FORM); setEditingBranch(null); setFormError(null); setIsCreateOpen(true); }}
          />
        }
      />

      <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
        {activeBranches.length === 0 ? (
          <div className="col-span-full py-20 bg-white/[0.01] border border-dashed border-white/10 rounded-[2.5rem] flex flex-col items-center justify-center text-center">
            <div className="w-16 h-16 bg-white/[0.02] border border-white/5 rounded-2xl flex items-center justify-center mb-6">
              <Store className="h-8 w-8 text-zinc-700" />
            </div>
            <h3 className="text-xl font-black text-white italic uppercase tracking-tighter">No branches detected</h3>
            <p className="text-zinc-500 text-xs mt-2 font-bold uppercase tracking-widest max-w-xs">Initialize your first physical facility to begin multi-location management.</p>
            <button
              onClick={() => { setForm(EMPTY_FORM); setIsCreateOpen(true); }}
              className="mt-8 px-8 py-4 bg-white/5 text-white border border-white/5 rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F] hover:text-black hover:border-transparent transition-all"
            >
              CREATE INITIAL BRANCH
            </button>
          </div>
        ) : (
          activeBranches.map((branch) => (
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

                <div className="space-y-3">
                  {(branch.address || branch.city) && (
                    <div className="flex items-start gap-3 p-3 bg-white/[0.02] rounded-2xl border border-white/5">
                      <MapPin className="h-4 w-4 text-zinc-500 mt-0.5 shrink-0" />
                      <p className="text-[11px] text-zinc-400 font-bold leading-relaxed">
                        {[branch.address, branch.city].filter(Boolean).join(", ") || "NO ADDRESS RECORDED"}
                      </p>
                    </div>
                  )}
                  {(branch.openTime || branch.closeTime) && (
                    <div className="flex items-center gap-3 p-3 bg-white/[0.02] rounded-2xl border border-white/5">
                      <Clock className="h-4 w-4 text-zinc-500 shrink-0" />
                      <p className="text-[11px] text-zinc-400 font-bold">{branch.openTime ?? "--"} – {branch.closeTime ?? "--"}</p>
                    </div>
                  )}
                  {branch.phone && (
                    <div className="flex items-center gap-3 p-3 bg-white/[0.02] rounded-2xl border border-white/5">
                      <Phone className="h-4 w-4 text-zinc-500 shrink-0" />
                      <p className="text-[11px] text-zinc-400 font-bold">{branch.phone}</p>
                    </div>
                  )}

                  <div className="grid grid-cols-3 gap-2">
                    <div className="bg-black/20 p-3 rounded-2xl border border-white/5 text-center">
                      <p className="text-[8px] font-black text-zinc-600 uppercase tracking-widest mb-1">Members</p>
                      <p className="text-xl font-black text-white italic tracking-tighter">{branch.activeMembers ?? "—"}</p>
                    </div>
                    <div className="bg-black/20 p-3 rounded-2xl border border-white/5 text-center">
                      <p className="text-[8px] font-black text-zinc-600 uppercase tracking-widest mb-1">Trainers</p>
                      <p className="text-xl font-black text-white italic tracking-tighter">{branch.trainerCount ?? "—"}</p>
                    </div>
                    <div className="bg-black/20 p-3 rounded-2xl border border-white/5 text-center">
                      <p className="text-[8px] font-black text-zinc-600 uppercase tracking-widest mb-1">Today</p>
                      <p className="text-xl font-black text-[#F1C40F] italic tracking-tighter">{branch.todayCheckins ?? "—"}</p>
                    </div>
                  </div>

                  {branch.admins && branch.admins.length > 0 && (
                    <div className="p-3 bg-white/[0.02] rounded-2xl border border-white/5">
                      <p className="text-[8px] font-black text-zinc-600 uppercase tracking-widest mb-2">Branch Admin</p>
                      {branch.admins.map((a) => (
                        <p key={a.id} className="text-[11px] text-zinc-400 font-bold">{a.fullName}</p>
                      ))}
                    </div>
                  )}
                </div>

                <div className="flex gap-2 pt-2">
                  <button
                    onClick={() => openEdit(branch)}
                    className="flex-1 px-4 py-3.5 bg-white/[0.02] border border-white/5 rounded-xl text-[9px] font-black uppercase tracking-widest text-zinc-500 hover:text-white hover:bg-white/5 transition-all flex items-center justify-center gap-2"
                  >
                    <Edit2 size={12} className="text-[#F1C40F]" />
                    CONFIGURE
                  </button>
                  <button
                    onClick={() => setAssignBranchId(branch.id)}
                    className="px-4 py-3.5 bg-blue-500/5 border border-blue-500/10 rounded-xl text-blue-400 hover:bg-blue-500/20 transition-all flex items-center justify-center"
                    title="Assign Admin"
                  >
                    <UserPlus size={14} />
                  </button>
                  <button
                    onClick={() => {
                      if (confirm(`Deactivate "${branch.name}"?`)) deleteMutation.mutate(branch.id);
                    }}
                    className="px-4 py-3.5 bg-red-500/5 border border-red-500/10 rounded-xl text-red-500 hover:bg-red-500/20 transition-all flex items-center justify-center"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* CREATE / EDIT MODAL */}
      {(isCreateOpen || editingBranch) && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
          <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-lg max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.8)] overflow-hidden animate-in zoom-in-95 duration-300">
            <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
              <div>
                <h2 className="text-2xl font-black text-white tracking-tight flex items-center gap-3 italic uppercase">
                  <Shield className="text-[#F1C40F]" size={28} />
                  {editingBranch ? "CONFIGURE BRANCH" : "GENERATE BRANCH"}
                </h2>
                <p className="text-zinc-500 text-[10px] font-black uppercase tracking-[0.2em] mt-1">
                  {editingBranch ? "Update Facility Details" : "Deploy New Physical Facility"}
                </p>
              </div>
              <button
                onClick={() => { setIsCreateOpen(false); setEditingBranch(null); }}
                className="p-3 bg-white/5 text-zinc-500 hover:text-white hover:bg-white/10 rounded-2xl transition-all border border-white/5 shadow-inner"
              >
                <X size={24} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-8">
              <form id="branch-form" onSubmit={handleSubmit} className="space-y-5">
                {[
                  { key: "name", label: "FACILITY NAME", placeholder: "e.g. BATUMI CENTRAL BRANCH", required: true },
                  { key: "address", label: "PHYSICAL ADDRESS", placeholder: "Street, Postal Code" },
                  { key: "city", label: "CITY", placeholder: "Tbilisi" },
                  { key: "phone", label: "PHONE", placeholder: "+995 555 000000" },
                ].map(({ key, label, placeholder, required }) => (
                  <div key={key}>
                    <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500 mb-2 block">{label}</label>
                    <input
                      type="text"
                      required={required}
                      value={(form as any)[key]}
                      onChange={(e) => setForm({ ...form, [key]: e.target.value })}
                      className="amirani-input h-[52px] font-bold text-sm"
                      placeholder={placeholder}
                    />
                  </div>
                ))}

                <div className="grid grid-cols-3 gap-4">
                  <div>
                    <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500 mb-2 block">MAX CAPACITY</label>
                    <input
                      type="number"
                      min={1}
                      value={form.maxCapacity}
                      onChange={(e) => setForm({ ...form, maxCapacity: Number(e.target.value) })}
                      className="amirani-input h-[52px] font-bold text-sm"
                    />
                  </div>
                  <div>
                    <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500 mb-2 block">OPEN</label>
                    <input
                      type="time"
                      value={form.openTime}
                      onChange={(e) => setForm({ ...form, openTime: e.target.value })}
                      className="amirani-input h-[52px] font-bold text-sm"
                    />
                  </div>
                  <div>
                    <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500 mb-2 block">CLOSE</label>
                    <input
                      type="time"
                      value={form.closeTime}
                      onChange={(e) => setForm({ ...form, closeTime: e.target.value })}
                      className="amirani-input h-[52px] font-bold text-sm"
                    />
                  </div>
                </div>

                {formError && (
                  <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-500 text-[10px] font-black uppercase tracking-widest flex items-center gap-3">
                    <div className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />
                    {formError}
                  </div>
                )}
              </form>
            </div>

            <div className="p-8 border-t border-white/5 bg-white/[0.01] flex gap-4 shrink-0">
              <button
                type="button"
                onClick={() => { setIsCreateOpen(false); setEditingBranch(null); }}
                className="flex-1 px-8 py-5 rounded-2xl border border-white/10 text-zinc-500 font-black uppercase tracking-widest hover:bg-white/5 hover:text-white transition-all text-[10px]"
              >
                ABORT
              </button>
              <button
                form="branch-form"
                type="submit"
                disabled={isSubmitting}
                className="flex-[2] px-8 py-5 rounded-2xl bg-[#F1C40F] !text-black font-black uppercase tracking-widest hover:bg-[#D4AC0D] transition-all shadow-2xl shadow-[#F1C40F]/20 disabled:opacity-50 text-[10px] flex items-center justify-center gap-3"
              >
                {isSubmitting ? (
                  <RefreshCw className="animate-spin" size={18} />
                ) : (
                  <>
                    <CheckCircle size={18} />
                    {editingBranch ? "SAVE CHANGES" : "INITIALIZE FACILITY"}
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ASSIGN ADMIN MODAL */}
      {assignBranchId && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4">
          <div className="bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md p-8 space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-black text-white uppercase italic flex items-center gap-3">
                <Users className="text-blue-400" size={24} />
                ASSIGN BRANCH ADMIN
              </h2>
              <button onClick={() => { setAssignBranchId(null); setAdminEmail(""); setFormError(null); }} className="p-2 text-zinc-500 hover:text-white">
                <X size={20} />
              </button>
            </div>
            <p className="text-zinc-500 text-xs">Enter the user ID of the Branch Admin to assign to this branch.</p>
            <input
              type="text"
              value={adminEmail}
              onChange={(e) => setAdminEmail(e.target.value)}
              className="amirani-input h-[52px] font-bold text-sm w-full"
              placeholder="Branch Admin User ID"
            />
            {formError && <p className="text-red-500 text-xs font-bold">{formError}</p>}
            <div className="flex gap-4">
              <button onClick={() => { setAssignBranchId(null); setAdminEmail(""); }} className="flex-1 py-4 rounded-2xl border border-white/10 text-zinc-500 font-black uppercase text-[10px] tracking-widest">CANCEL</button>
              <button
                onClick={async () => {
                  if (!adminEmail.trim()) return;
                  try {
                    await branchesApi.assignAdmin(gymId, assignBranchId, adminEmail.trim(), token!);
                    setAssignBranchId(null);
                    setAdminEmail("");
                    invalidate();
                  } catch (e: any) {
                    setFormError(e.message ?? "Failed to assign admin");
                  }
                }}
                className="flex-[2] py-4 rounded-2xl bg-blue-500 text-white font-black uppercase text-[10px] tracking-widest hover:bg-blue-400 transition-all"
              >
                ASSIGN
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
