"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import { adminApi, uploadApi, type CreateTrainerData, type Trainer } from "@/lib/api";
import { CustomSelect } from "@/components/ui/Select";
import { PageHeader } from "@/components/ui/PageHeader";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import NextImage from "next/image";
import {
  Plus,
  Users,
  X,
  Search,
  RefreshCw,
  Upload,
  Building2,
  Award,
  Trash2
} from "lucide-react";

type AvailabilityFilter = "ALL" | "AVAILABLE" | "OFF_DUTY";

const AVAILABILITY_OPTIONS: { value: AvailabilityFilter; label: string; color: string }[] = [
  { value: "ALL", label: "All Staff", color: "bg-zinc-500/10 text-zinc-400" },
  { value: "AVAILABLE", label: "On Duty", color: "bg-green-500/10 text-green-400" },
  { value: "OFF_DUTY", label: "Off Duty", color: "bg-red-500/10 text-red-400" },
];

export default function TrainersPage() {
  const { token } = useAuthStore();
  const queryClient = useQueryClient();
  const [showModal, setShowModal] = useState(false);
  const [editingTrainer, setEditingTrainer] = useState<Trainer | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [availabilityFilter, setAvailabilityFilter] = useState<AvailabilityFilter>("ALL");

  // Unified gym selection
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, isBranchAdmin } = useGymSelection();

  // Get trainers for selected gym
  const { data: rawTrainers, isLoading: trainersLoading } = useQuery({
    queryKey: ["trainers", selectedGymId],
    queryFn: () => adminApi.getGymTrainers(selectedGymId!, token!),
    enabled: !!token && !!selectedGymId,
  });

  // Use trainers data directly from API (real database data)
  const trainers = rawTrainers || [];

  const createMutation = useMutation({
    mutationFn: async (data: CreateTrainerData & { staffType: "TRAINER" | "BRANCH_ADMIN" }) => {
      const { staffType, ...rest } = data;
      const targetGymId = selectedGymId!;
      if (staffType === "BRANCH_ADMIN") {
        return adminApi.createBranchAdmin({ ...rest, gymId: targetGymId }, token!);
      }
      return adminApi.createTrainer({ ...rest, gymId: targetGymId }, token!);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trainers", selectedGymId] });
      setShowModal(false);
    },
  });

  const updateMutation = useMutation({
    mutationFn: (data: { id: string; updates: Partial<CreateTrainerData> & { isAvailable?: boolean } }) =>
      adminApi.updateTrainer(data.id, data.updates, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trainers", selectedGymId] });
      setEditingTrainer(null);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: ({ id, isBranchAdmin }: { id: string; isBranchAdmin: boolean }) =>
      isBranchAdmin ? adminApi.deleteBranchAdmin(id, token!) : adminApi.deleteTrainer(id, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trainers", selectedGymId] });
    },
  });

  const filteredTrainers = trainers?.filter(t => {
    const matchesSearch = t.fullName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      t.specialization?.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesAvailability = availabilityFilter === "ALL" ||
      (availabilityFilter === "AVAILABLE" && t.isAvailable) ||
      (availabilityFilter === "OFF_DUTY" && !t.isAvailable);
    return matchesSearch && matchesAvailability;
  });

  // Count trainers by availability
  const availabilityCounts = trainers?.reduce(
    (acc, t) => {
      acc.ALL = (acc.ALL || 0) + 1;
      if (t.isAvailable) {
        acc.AVAILABLE = (acc.AVAILABLE || 0) + 1;
      } else {
        acc.OFF_DUTY = (acc.OFF_DUTY || 0) + 1;
      }
      return acc;
    },
    {} as Record<string, number>
  ) || {};

  // isBranchAdmin comes from useGymSelection hook

  return (
    <div className="space-y-12">
      <PageHeader
        title="Staff Management"
        description="Manage trainers, instructors and facility staff members."
        icon={<Users size={32} />}
        actions={
          <>
            <button
              onClick={() => {
                setEditingTrainer(null);
                setShowModal(true);
              }}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
            >
              <Plus size={18} />
              Initialize Commission
            </button>
            <GymSwitcher 
              gyms={gyms} 
              isLoading={gymsLoading} 
              disabled={isBranchAdmin}
            />
          </>
        }
      />

      <div className="grid grid-cols-1 xl:grid-cols-4 gap-8">
        {!isBranchAdmin && (
          <div className="xl:col-span-1">
            <div className="bg-[#121721] border border-white/5 rounded-[2.5rem] p-8 h-full relative overflow-hidden group">
              <div className="absolute top-0 right-0 w-32 h-32 bg-[#F1C40F]/5 blur-3xl -mr-16 -mt-16 group-hover:bg-[#F1C40F]/10 transition-colors" />
              <p className="text-xs font-black text-zinc-500 uppercase tracking-[0.2em] mb-4">Active Facility Pool</p>
              <div className="flex items-center gap-4 p-4 bg-white/5 border border-white/10 rounded-2xl">
                <div className="p-3 bg-[#F1C40F]/10 rounded-xl">
                  <Building2 className="text-[#F1C40F]" size={20} />
                </div>
                <div className="text-left">
                  <p className="text-white font-black uppercase tracking-tighter line-clamp-1">
                    {gyms?.find(g => g.id === selectedGymId)?.name || "Select Facility"}
                  </p>
                  <div className="flex items-center gap-1.5 mt-0.5">
                    <div className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse shadow-[0_0_8px_#22c55e]" />
                    <span className="text-[9px] font-black text-zinc-500 uppercase tracking-widest">Live Monitoring</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Global Staff Overlay */}
        <div className={isBranchAdmin ? "xl:col-span-4 grid grid-cols-1 sm:grid-cols-3 gap-6" : "xl:col-span-3 grid grid-cols-1 sm:grid-cols-3 gap-6"}>
          <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-3xl p-6 transition-all duration-500 hover:border-[#F1C40F]/20">
            <div className="absolute top-0 right-0 w-32 h-32 bg-[#F1C40F]/5 blur-3xl -mr-16 -mt-16 group-hover:bg-[#F1C40F]/10 transition-colors" />
            <p className="text-xs font-black text-zinc-500 uppercase tracking-widest leading-none">Total Staff</p>
            <p className="text-4xl font-black text-white mt-4 tracking-tighter">{trainers?.length || 0}</p>
            <div className="mt-4 flex items-center gap-2 text-[10px] font-black text-zinc-600 uppercase tracking-widest">
              Across Current Unit
            </div>
          </div>
          <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-3xl p-6 transition-all duration-500 hover:border-green-500/20">
            <div className="absolute top-0 right-0 w-32 h-32 bg-green-500/5 blur-3xl -mr-16 -mt-16 group-hover:bg-green-500/10 transition-colors" />
            <p className="text-xs font-black text-zinc-500 uppercase tracking-widest leading-none">Ready for Duty</p>
            <p className="text-4xl font-black text-green-400 mt-4 tracking-tighter">
              {trainers?.filter(t => t.isAvailable).length || 0}
            </p>
            <div className="mt-4 flex items-center gap-2 text-[10px] font-black text-zinc-600 uppercase tracking-widest">
              Available Now
            </div>
          </div>
          <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-3xl p-6 transition-all duration-500 hover:border-blue-500/20">
            <div className="absolute top-0 right-0 w-32 h-32 bg-blue-500/5 blur-3xl -mr-16 -mt-16 group-hover:bg-blue-500/10 transition-colors" />
            <p className="text-xs font-black text-zinc-500 uppercase tracking-widest leading-none">Member Load</p>
            <p className="text-4xl font-black text-blue-400 mt-4 tracking-tighter">
              {trainers?.reduce((acc, t) => acc + (t._count?.assignedMembers || 0), 0) || 0}
            </p>
            <div className="mt-4 flex items-center gap-2 text-[10px] font-black text-zinc-600 uppercase tracking-widest">
              Active Engagements
            </div>
          </div>
        </div>
      </div>

      {/* Control Bar */}
      <div className="flex flex-col lg:flex-row gap-6 lg:items-end mt-8 ml-4">
        <div className="relative group flex-1 max-w-2xl">
          <div className="absolute inset-0 bg-[#F1C40F]/5 blur-2xl opacity-0 group-focus-within:opacity-100 transition-opacity duration-500" />
          <Search className="absolute left-5 text-zinc-600 group-focus-within:text-[#F1C40F] transition-colors" size={20} />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Filter elite roster by name or specialization..."
            className="amirani-input amirani-input-with-icon font-medium"
          />
        </div>

        {/* Availability Filter */}
        <div className="flex flex-col gap-3">
          <label className="block text-[10px] font-black text-[#F1C40F] uppercase tracking-[0.2em] ml-1">
            Filter by Availability
          </label>
          <div className="flex gap-2 overflow-x-auto py-4 px-4 -mx-4 custom-scrollbar">
            {AVAILABILITY_OPTIONS.map((option) => (
              <button
                key={option.value}
                onClick={() => setAvailabilityFilter(option.value)}
                className={`px-4 py-3 rounded-xl text-xs font-black uppercase tracking-widest transition-all whitespace-nowrap flex items-center gap-2 ${
                  availabilityFilter === option.value
                    ? option.color + " ring-2 ring-offset-2 ring-offset-[#0d1117] ring-white/20"
                    : "bg-[#121721] text-zinc-400 border border-white/5 hover:border-white/10 hover:text-zinc-300"
                }`}
              >
                {option.label}
                <span className="text-[10px] opacity-60">({availabilityCounts[option.value] || 0})</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Staff Grid */}
      <div className="relative min-h-[400px]">
        {trainersLoading ? (
          <div className="flex flex-col items-center justify-center py-24 gap-4">
            <RefreshCw className="animate-spin text-[#F1C40F]" size={40} />
            <p className="text-zinc-500 font-bold uppercase tracking-widest animate-pulse">Synchronizing Staff Data</p>
          </div>
        ) : !filteredTrainers || filteredTrainers.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 bg-[#121721] border border-white/5 rounded-[2.5rem] border-dashed">
            <div className="p-6 bg-zinc-900/50 rounded-3xl border border-white/5 mb-6">
              <Users className="text-zinc-700" size={48} />
            </div>
            <h3 className="text-xl font-black text-white uppercase tracking-tight italic">No staff matching criteria</h3>
            <p className="text-zinc-500 mt-2 max-w-xs font-black text-[10px] uppercase tracking-widest text-center">Initialize your first personnel commission to begin facility monitoring.</p>
            <button
              onClick={() => setShowModal(true)}
              className="mt-8 flex items-center justify-center gap-3 px-8 py-4 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
            >
              <Plus size={16} />
              Initialize New Commission
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-3 gap-6">
            {filteredTrainers.map((trainer) => (
              <div
                key={trainer.id}
                className="group relative bg-[#121721] border border-white/5 rounded-[2.5rem] overflow-hidden transition-all duration-500 hover:border-[#F1C40F]/30 hover:shadow-2xl hover:shadow-black/50"
              >
                {/* Visual Header */}
                <div className="h-32 bg-gradient-to-br from-zinc-800 to-zinc-950 relative overflow-hidden">
                  <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(241,196,15,0.05),transparent)] opacity-100" />
                  <div className="absolute top-6 right-6 flex flex-col items-end gap-1">
                    <span
                      className={`px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest backdrop-blur-md border ${
                        trainer.isAvailable
                          ? "bg-green-500/10 text-green-400 border-green-500/20"
                          : "bg-red-500/10 text-red-400 border-red-500/20"
                      }`}
                    >
                      {trainer.isAvailable ? "Duty Active" : "Off Duty"}
                    </span>
                  </div>
                </div>

                {/* Profile Visual */}
                <div className="absolute top-12 left-8">
                  <div className="relative group/avatar">
                    <div className="absolute inset-0 bg-[#F1C40F] blur-xl opacity-0 group-hover/avatar:opacity-20 transition-opacity duration-500 rounded-full" />
                    <div className="w-24 h-24 rounded-3xl overflow-hidden border-4 border-[#121721] shadow-2xl bg-zinc-900 flex items-center justify-center relative z-10">
                      {trainer.avatarUrl ? (
                        <NextImage
                          src={uploadApi.getFullUrl(trainer.avatarUrl)}
                          alt={trainer.fullName}
                          fill
                          unoptimized
                          className="object-cover transition-transform duration-700 group-hover/avatar:scale-110"
                        />
                      ) : (
                        <span className="text-3xl font-black text-[#F1C40F]">{trainer.fullName.charAt(0)}</span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Content */}
                <div className="p-8 pt-12 space-y-6">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="text-2xl font-black text-white tracking-tighter uppercase group-hover:text-[#F1C40F] transition-colors">
                        {trainer.fullName}
                      </h3>
                      <div className="flex items-center gap-2 mt-1">
                        <Award size={14} className="text-[#F1C40F]" />
                        <span className="text-xs font-black text-[#F1C40F] uppercase tracking-[0.2em]">
                          {trainer.userId ? "Branch Administrator" : (trainer.specialization || "ELITE GENERALIST")}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-6 py-2 border-y border-white/5">
                    <div className="flex flex-col">
                      <span className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Age Group</span>
                      <span className="text-white font-bold">{trainer.age || "N/A"}</span>
                    </div>
                    <div className="w-px h-8 bg-white/5" />
                    <div className="flex flex-col">
                      <span className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Client Load</span>
                      <span className="text-white font-bold">{trainer._count?.assignedMembers || 0} Members</span>
                    </div>
                  </div>

                  <p className="text-sm text-zinc-500 leading-relaxed line-clamp-2 italic">
                    {trainer.bio || "Staff specifications pending. Certified professional under amirani global excellence standards."}
                  </p>

                  <div className="flex items-center gap-3 pt-2">
                  </div>

                  {/* Quick Actions */}
                  <div className="pt-2 flex gap-2">
                    <button
                      onClick={() => setEditingTrainer(trainer)}
                      className="flex-1 py-3 bg-white/5 hover:bg-white/10 text-white rounded-2xl flex items-center justify-center gap-2 transition-all font-black text-[10px] uppercase tracking-[0.2em] border border-white/5 group-hover:border-[#F1C40F]/30 shadow-xl shadow-black/20"
                    >
                      EDIT SPECIFICATIONS
                    </button>
                    <button
                      onClick={() => {
                        if (confirm(`Delete ${trainer.fullName}? This action cannot be undone.`)) {
                          deleteMutation.mutate({ id: trainer.id, isBranchAdmin: !!trainer.userId });
                        }
                      }}
                      className="p-3 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-2xl transition-all border border-red-500/20"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Edit Modal */}
      {editingTrainer && (
        <EditTrainerModal
          trainer={editingTrainer}
          onClose={() => setEditingTrainer(null)}
          onSubmit={(updates) => updateMutation.mutate({ id: editingTrainer.id, updates })}
          isLoading={updateMutation.isPending}
          error={updateMutation.error?.message}
          token={token!}
        />
      )}

      {/* Enroll Modal */}
      {showModal && (
        <CreateTrainerModal
          gyms={gyms || []}
          initialGymId={selectedGymId || ""}
          onClose={() => setShowModal(false)}
          onSubmit={(data) => createMutation.mutate(data)}
          isLoading={createMutation.isPending}
          error={createMutation.error?.message}
          token={token!}
          isBranchAdmin={isBranchAdmin}
        />
      )}
    </div>
  );
}

function CreateTrainerModal({
  gyms,
  initialGymId,
  onClose,
  onSubmit,
  isLoading,
  error,
  token,
  isBranchAdmin,
}: {
  gyms: Array<{ id: string; name: string }>;
  initialGymId: string;
  onClose: () => void;
  onSubmit: (data: CreateTrainerData & { staffType: "TRAINER" | "BRANCH_ADMIN" }) => void;
  isLoading: boolean;
  error?: string;
  token: string;
  isBranchAdmin?: boolean;
}) {
  const [formData, setFormData] = useState<CreateTrainerData & { avatarFile?: File | null; staffType: "TRAINER" | "BRANCH_ADMIN" }>({
    fullName: "",
    gymId: initialGymId,
    bio: "",
    age: undefined,
    avatarUrl: "",
    specialization: "",
    certifications: [],
    staffType: "TRAINER",
    email: "",
    password: "",
  });
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const handleFileSelect = async (file: File) => {
    setUploadError(null);
    setUploading(true);

    // Create preview
    const reader = new FileReader();
    reader.onload = (e) => setPreviewUrl(e.target?.result as string);
    reader.readAsDataURL(file);

    try {
      const result = await uploadApi.uploadFile(file, "avatars", token);
      setFormData({ ...formData, avatarUrl: result.url });
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : "Upload failed");
      setPreviewUrl(null);
    } finally {
      setUploading(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
          <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-2xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
            {/* FIXED HEADER */}
            <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
              <div>
                <h2 className="text-3xl font-black text-white tracking-tighter uppercase">Register New Staff</h2>
                <p className="text-white/40 text-[10px] font-black tracking-widest uppercase mt-1">Personnel Induction Protocol</p>
              </div>
              <button
                onClick={onClose}
                className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5"
              >
                <X size={20} />
              </button>
            </div>

            {/* SCROLLABLE CONTENT */}
            <div className="flex-1 overflow-y-auto amirani-scrollbar scroll-smooth">
              <form onSubmit={handleSubmit} className="p-8 space-y-6">
          {error && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-2xl p-4 text-red-400 text-xs font-black uppercase tracking-widest animate-in shake duration-300">
              {error}
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="md:col-span-2">
              <label className="amirani-label">Enrollment Profile Type</label>
              <div className="grid grid-cols-2 gap-2 p-1.5 bg-white/[0.03] border border-white/10 rounded-xl backdrop-blur-md">
                <button
                  type="button"
                  onClick={() => setFormData({ ...formData, staffType: "TRAINER" })}
                  className={`py-3 text-[15px] font-black uppercase tracking-widest transition-all rounded-lg ${
                      formData.staffType === "TRAINER"
                        ? "bg-[#F1C40F] !text-black shadow-lg"
                        : "text-white/40 hover:text-white/80"
                  }`}
                >
                  Personnel Staff
                </button>
                {!isBranchAdmin && (
                  <button
                    type="button"
                    onClick={() => setFormData({ ...formData, staffType: "BRANCH_ADMIN" })}
                    className={`py-3 text-[15px] font-black uppercase tracking-widest transition-all rounded-lg ${
                      formData.staffType === "BRANCH_ADMIN"
                        ? "bg-[#F1C40F] !text-black shadow-lg"
                        : "text-white/40 hover:text-white/80"
                    }`}
                  >
                    Branch Administrator
                  </button>
                )}
              </div>
            </div>

            <div className="md:col-span-2">
              <CustomSelect
                label="Facility Alignment"
                required
                value={formData.gymId}
                onChange={(value) => setFormData({ ...formData, gymId: value })}
                options={gyms.map(gym => ({ value: gym.id, label: gym.name }))}
                placeholder="Select Target Hub"
              />
            </div>

            <div className="md:col-span-2">
              <label className="amirani-label">Staff Designation *</label>
              <input
                type="text"
                value={formData.fullName}
                onChange={(e) => setFormData({ ...formData, fullName: e.target.value })}
                required
                className="amirani-input"
                placeholder={formData.staffType === "TRAINER" ? "e.g., COMMANDER MIKE TYSON" : "e.g., ADMIN SARAH CONNOR"}
              />
            </div>

            {formData.staffType === "BRANCH_ADMIN" && (
              <>
                <div>
                  <label className="amirani-label">Access Email *</label>
                  <input
                    type="email"
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    required
                    className="amirani-input"
                    placeholder="sarah@amirani.app"
                  />
                </div>
                <div>
                  <label className="amirani-label">Induction Password *</label>
                  <input
                    type="password"
                    value={formData.password}
                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    required
                    className="amirani-input"
                    placeholder="••••••••"
                  />
                </div>
              </>
            )}

            {formData.staffType === "TRAINER" && (
              <div>
                <label className="amirani-label">Operational Age</label>
                <input
                  type="number"
                  value={formData.age || ""}
                  onChange={(e) => setFormData({ ...formData, age: parseInt(e.target.value) || undefined })}
                  className="amirani-input"
                  placeholder="25"
                />
              </div>
            )}

            {formData.staffType === "TRAINER" && (
              <div>
                <label className="amirani-label">Specialization Code</label>
                <input
                  type="text"
                  value={formData.specialization || ""}
                  onChange={(e) => setFormData({ ...formData, specialization: e.target.value })}
                  className="amirani-input uppercase"
                  placeholder="STRENGTH & IMPACT"
                />
              </div>
            )}

            <div className="md:col-span-2">
              <label className="amirani-label">Identification Visual (Upload)</label>
              <div className={`group relative h-48 bg-white/[0.02] border-2 border-dashed rounded-xl flex flex-col items-center justify-center transition-all cursor-pointer overflow-hidden backdrop-blur-sm ${
                uploadError ? "border-red-500/50" : previewUrl ? "border-green-500/50" : "border-white/10 hover:bg-white/[0.05] hover:border-[#F1C40F]/50"
              }`}>
                <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,image/gif"
                    className="absolute inset-0 opacity-0 cursor-pointer z-10"
                    disabled={uploading}
                    onChange={(e) => {
                        const file = e.target.files?.[0];
                        if (file) {
                            handleFileSelect(file);
                        }
                    }}
                />
                {uploading ? (
                  <div className="flex flex-col items-center">
                    <RefreshCw size={32} className="text-[#F1C40F] animate-spin mb-3" />
                    <p className="text-xs font-bold text-zinc-400">UPLOADING...</p>
                  </div>
                ) : previewUrl ? (
                  <div className="relative w-full h-full">
                    <NextImage src={previewUrl} alt="Preview" fill className="object-cover" />
                    <div className="absolute inset-0 bg-black/50 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                      <p className="text-xs font-bold text-white">CLICK TO CHANGE</p>
                    </div>
                  </div>
                ) : (
                  <div className="flex flex-col items-center text-zinc-500 transition-all group-hover:text-zinc-300">
                    <div className="w-12 h-12 bg-zinc-900/50 rounded-2xl flex items-center justify-center mb-4 group-hover:scale-110 transition-transform shadow-2xl border border-white/5">
                      <Upload size={24} className="text-[#F1C40F]" />
                    </div>
                    <p className="text-xs font-bold tracking-tight">DRAG PROFILE DATA HERE</p>
                    <p className="text-[10px] font-medium uppercase tracking-[0.1em] mt-2 opacity-40">JPEG, PNG, WebP, GIF (max 5MB)</p>
                  </div>
                )}
              </div>
              {uploadError && (
                <p className="text-red-400 text-xs mt-2">{uploadError}</p>
              )}
            </div>

            <div className="md:col-span-2">
              <label className="amirani-label">Professional Dossier</label>
              <textarea
                value={formData.bio || ""}
                onChange={(e) => setFormData({ ...formData, bio: e.target.value })}
                rows={4}
                className="amirani-textarea"
                placeholder="Outline career history, specialized certifications, and performance metrics..."
              />
            </div>
          </div>

          <div className="flex gap-4 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-4 bg-zinc-800/50 text-zinc-400 rounded-2xl hover:bg-zinc-800 hover:text-white transition-all font-bold uppercase tracking-widest text-xs border border-white/5"
            >
              ABORT INDUCTION
            </button>
            <button
              type="submit"
              disabled={isLoading || !formData.fullName}
              className="flex-1 py-4 bg-[#F1C40F] !text-black rounded-2xl hover:bg-[#F1C40F]/90 transition-all disabled:opacity-30 flex items-center justify-center gap-3 font-black uppercase tracking-tighter shadow-2xl shadow-[#F1C40F]/30"
            >
              {isLoading ? (
                <RefreshCw className="animate-spin" size={20} />
              ) : (
                "COMMISSION STAFF"
              )}
            </button>
          </div>
              </form>
            </div>
          </div>

    </div>
  );
}

function EditTrainerModal({
  trainer,
  onClose,
  onSubmit,
  isLoading,
  error,
  token,
}: {
  trainer: Trainer;
  onClose: () => void;
  onSubmit: (data: Partial<CreateTrainerData> & { isAvailable?: boolean }) => void;
  isLoading: boolean;
  error?: string;
  token: string;
}) {
  const [formData, setFormData] = useState({
    fullName: trainer.fullName,
    age: trainer.age,
    specialization: trainer.specialization || "",
    bio: trainer.bio || "",
    isAvailable: trainer.isAvailable,
    avatarUrl: trainer.avatarUrl || "",
  });
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(trainer.avatarUrl ? uploadApi.getFullUrl(trainer.avatarUrl) : null);

  const handleFileSelect = async (file: File) => {
    setUploadError(null);
    setUploading(true);

    // Create preview
    const reader = new FileReader();
    reader.onload = (e) => setPreviewUrl(e.target?.result as string);
    reader.readAsDataURL(file);

    try {
      const result = await uploadApi.uploadFile(file, "avatars", token);
      setFormData({ ...formData, avatarUrl: result.url });
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : "Upload failed");
      setPreviewUrl(trainer.avatarUrl ? uploadApi.getFullUrl(trainer.avatarUrl) : null);
    } finally {
      setUploading(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
          <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
            {/* FIXED HEADER */}
            <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
              <div>
                <h2 className="text-2xl font-black text-white tracking-tighter uppercase">Edit Staff Profile</h2>
                <p className="text-white/40 text-[10px] font-black tracking-widest uppercase mt-1">Update Specifications</p>
              </div>
              <button
                onClick={onClose}
                className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5"
              >
                <X size={20} />
              </button>
            </div>

            {/* SCROLLABLE CONTENT */}
            <div className="flex-1 overflow-y-auto amirani-scrollbar scroll-smooth">
              <form onSubmit={handleSubmit} className="p-8 space-y-6">
          {error && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-2xl p-4 text-red-400 text-xs font-black uppercase tracking-widest">
              {error}
            </div>
          )}

          <div className="space-y-4">
            <div>
              <label className="amirani-label">Staff Designation *</label>
              <input
                type="text"
                value={formData.fullName}
                onChange={(e) => setFormData({ ...formData, fullName: e.target.value })}
                required
                className="amirani-input"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="amirani-label">Operational Age</label>
                <input
                  type="number"
                  value={formData.age || ""}
                  onChange={(e) => setFormData({ ...formData, age: parseInt(e.target.value) || undefined })}
                  className="amirani-input"
                />
              </div>
              <div>
                <label className="amirani-label">Specialization</label>
                <input
                  type="text"
                  value={formData.specialization}
                  onChange={(e) => setFormData({ ...formData, specialization: e.target.value })}
                  className="amirani-input uppercase"
                />
              </div>
            </div>

            <div>
              <label className="amirani-label">Professional Dossier</label>
              <textarea
                value={formData.bio}
                onChange={(e) => setFormData({ ...formData, bio: e.target.value })}
                rows={3}
                className="amirani-textarea"
              />
            </div>

            <div>
              <label className="amirani-label">Profile Image (Identification Visual)</label>
              <div className={`group relative h-40 bg-white/[0.02] border-2 border-dashed rounded-xl flex flex-col items-center justify-center transition-all cursor-pointer overflow-hidden backdrop-blur-sm ${
                uploadError ? "border-red-500/50" : previewUrl ? "border-green-500/50" : "border-white/10 hover:bg-white/[0.05] hover:border-[#F1C40F]/50"
              }`}>
                <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,image/gif"
                    className="absolute inset-0 opacity-0 cursor-pointer z-10"
                    disabled={uploading}
                    onChange={(e) => {
                        const file = e.target.files?.[0];
                        if (file) {
                            handleFileSelect(file);
                        }
                    }}
                />
                {uploading ? (
                  <div className="flex flex-col items-center">
                    <RefreshCw size={24} className="text-[#F1C40F] animate-spin mb-2" />
                    <p className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Uploading...</p>
                  </div>
                ) : previewUrl ? (
                  <div className="relative w-full h-full">
                    <NextImage src={previewUrl} alt="Preview" fill className="object-cover" unoptimized />
                    <div className="absolute inset-0 bg-black/60 flex flex-col items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                      <Upload size={20} className="text-[#F1C40F] mb-1" />
                      <p className="text-[10px] font-black text-white uppercase tracking-widest">Replace Visual</p>
                    </div>
                  </div>
                ) : (
                  <div className="flex flex-col items-center text-zinc-500 transition-all group-hover:text-zinc-300">
                    <div className="w-10 h-10 bg-zinc-900/50 rounded-xl flex items-center justify-center mb-3 group-hover:scale-110 transition-transform shadow-xl border border-white/5">
                      <Upload size={20} className="text-[#F1C40F]" />
                    </div>
                    <p className="text-[10px] font-black tracking-widest uppercase">Click to Upload</p>
                  </div>
                )}
              </div>
              {uploadError && (
                <p className="text-red-400 text-[10px] font-bold uppercase tracking-widest mt-2">{uploadError}</p>
              )}
            </div>

            <div className="flex items-center justify-between p-4 bg-white/[0.02] rounded-xl border border-white/5">
              <div>
                <p className="text-white font-bold">Availability Status</p>
                <p className="text-xs text-zinc-500">Toggle duty status for this staff member</p>
              </div>
              <button
                type="button"
                onClick={() => setFormData({ ...formData, isAvailable: !formData.isAvailable })}
                className={`px-4 py-2 rounded-xl font-bold text-xs uppercase tracking-widest transition-all ${
                  formData.isAvailable
                    ? "bg-green-500/20 text-green-400 border border-green-500/30"
                    : "bg-red-500/20 text-red-400 border border-red-500/30"
                }`}
              >
                {formData.isAvailable ? "On Duty" : "Off Duty"}
              </button>
            </div>
          </div>

          <div className="flex gap-4 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-4 bg-zinc-800/50 text-zinc-400 rounded-2xl hover:bg-zinc-800 hover:text-white transition-all font-bold uppercase tracking-widest text-xs border border-white/5"
            >
              CANCEL
            </button>
            <button
              type="submit"
              disabled={isLoading || !formData.fullName}
              className="flex-1 py-4 bg-[#F1C40F] !text-black rounded-2xl hover:bg-[#F1C40F]/90 transition-all disabled:opacity-30 flex items-center justify-center gap-3 font-black uppercase tracking-tighter shadow-2xl shadow-[#F1C40F]/30"
            >
              {isLoading ? (
                <RefreshCw className="animate-spin" size={20} />
              ) : (
                "SAVE CHANGES"
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
);
}
