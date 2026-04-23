"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { X, ShieldCheck, ZoomIn, Edit3, Trash2 } from "lucide-react";
import { membershipsApi, trainersApi, uploadApi, MembershipStatus, Membership, RegistrationRequirements } from "@/lib/api";
import { CustomSelect } from "@/components/ui/Select";
import { useAuthStore } from "@/lib/auth-store";
import NextImage from "next/image";
import { PhotoViewModal } from "./PhotoViewModal";
import { EditMemberModal } from "./EditMemberModal";

export const STATUS_OPTIONS: { value: MembershipStatus | "ALL"; label: string; color: string }[] = [
  { value: "ALL", label: "All", color: "bg-zinc-500/10 text-zinc-400" },
  { value: "ACTIVE", label: "Active", color: "bg-green-500/10 text-green-400" },
  { value: "SUSPENDED", label: "Suspended", color: "bg-yellow-500/10 text-yellow-400" },
  { value: "CANCELLED", label: "Cancelled", color: "bg-red-500/10 text-red-400" },
  { value: "EXPIRED", label: "Expired", color: "bg-orange-500/10 text-orange-400" },
  { value: "PENDING", label: "Pending", color: "bg-blue-500/10 text-blue-400" },
];

export function getStatusColor(status: string) {
  const option = STATUS_OPTIONS.find((o) => o.value === status);
  return option?.color || "bg-zinc-500/10 text-zinc-400";
}

interface MemberManageModalProps {
  membership: Membership;
  gymId: string;
  token: string;
  registrationRequirements?: RegistrationRequirements;
  onClose: () => void;
}

export function MemberManageModal({ membership, gymId, token, registrationRequirements, onClose }: MemberManageModalProps) {
  const queryClient = useQueryClient();
  const { user } = useAuthStore();
  const isOwner = user?.role === "GYM_OWNER";
  
  const [selectedStatus, setSelectedStatus] = useState<MembershipStatus>(membership.status);
  const [selectedTrainerId, setSelectedTrainerId] = useState<string | null>(membership.trainerId || null);
  const [viewingPhoto, setViewingPhoto] = useState<{ url: string; alt: string } | null>(null);
  const [showEditModal, setShowEditModal] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Get trainers for this gym
  const { data: trainers } = useQuery({
    queryKey: ["trainers", gymId],
    queryFn: () => trainersApi.getByGym(gymId, token),
    enabled: !!gymId,
  });

  const updateStatusMutation = useMutation({
    mutationFn: (status: MembershipStatus) => membershipsApi.updateStatus(membership.id, status, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["members", gymId] });
      queryClient.invalidateQueries({ queryKey: ["access-logs", gymId] }); // Also invalidate logs as status might affect appearance
    },
  });

  const assignTrainerMutation = useMutation({
    mutationFn: (trainerId: string | null) => membershipsApi.assignTrainer(membership.id, trainerId, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["members", gymId] });
    },
  });

  const removeMemberMutation = useMutation({
    mutationFn: () => membershipsApi.removeMemberFromGym(gymId, membership.user.id, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["members", gymId] });
      onClose();
    },
  });

  const handleSave = async () => {
    try {
      if (selectedStatus !== membership.status) {
        await updateStatusMutation.mutateAsync(selectedStatus);
      }
      if (selectedTrainerId !== membership.trainerId) {
        await assignTrainerMutation.mutateAsync(selectedTrainerId);
      }
      onClose();
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : "Failed to update membership");
    }
  };

  const isLoading = updateStatusMutation.isPending || assignTrainerMutation.isPending;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-[60] animate-in fade-in duration-300 p-4">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-lg max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden animate-in zoom-in-95 duration-300">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <h2 className="text-xl font-black text-white uppercase tracking-tight italic">
            {isOwner ? "Member Details" : "Manage Member"}
          </h2>
          <button onClick={onClose} className="text-zinc-500 hover:text-white transition-colors p-2.5 hover:bg-white/5 border border-white/5 rounded-xl">
            <X size={20} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar scroll-smooth">
          <div className="p-8 space-y-6">

        {/* Member Info - 50/50 Split Layout */}
        <div className="bg-white/[0.02] border border-white/5 rounded-3xl overflow-hidden mb-6">
          <div className="grid grid-cols-2">
            {/* Left: Images & ID Info */}
            <div className="flex flex-col border-r border-white/5">
              <div 
                className="aspect-square bg-zinc-900 flex items-center justify-center relative cursor-zoom-in group/avatar overflow-hidden"
                onClick={() => membership.user?.avatarUrl && setViewingPhoto({ url: uploadApi.getFullUrl(membership.user.avatarUrl), alt: membership.user.fullName })}
              >
                {membership.user?.avatarUrl ? (
                  <>
                    <NextImage
                      src={uploadApi.getFullUrl(membership.user.avatarUrl)}
                      alt={membership.user.fullName}
                      fill
                      className="object-cover transition-transform duration-500 group-hover/avatar:scale-110"
                    />
                    <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover/avatar:opacity-100 transition-opacity">
                      <ZoomIn size={24} className="text-white" />
                    </div>
                  </>
                ) : (
                  <div className="flex flex-col items-center gap-2">
                    <span className="text-[#F1C40F] text-5xl font-black italic">{membership.user?.fullName?.charAt(0) || "M"}</span>
                    <p className="text-[10px] font-black text-[#F1C40F]/40 uppercase tracking-[0.2em]">No Photo</p>
                  </div>
                )}
              </div>

              {/* ID Info & Photo (under main photo) */}
              {(registrationRequirements?.idPhoto || registrationRequirements?.personalNumber || membership.user?.idPhotoUrl || membership.user?.personalNumber) && (
                <div className="p-4 border-t border-white/5 bg-white/[0.01] space-y-3">
                  <div className="flex items-center gap-2">
                    <ShieldCheck size={12} className="text-[#F1C40F]" />
                    <p className="text-[10px] font-black text-white uppercase tracking-widest">Additional Info</p>
                  </div>
                  
                  {membership.user?.personalNumber && (
                    <div>
                      <p className="text-[8px] font-black text-zinc-500 uppercase tracking-widest mb-0.5">ID / Personal Number</p>
                      <p className="text-xs text-white font-mono tracking-tighter">{membership.user.personalNumber}</p>
                    </div>
                  )}

                  {membership.user?.idPhotoUrl && (
                    <div 
                      className="relative aspect-[16/10] rounded-lg overflow-hidden border border-white/10 bg-black/40 group cursor-zoom-in"
                      onClick={(e) => {
                        e.stopPropagation();
                        setViewingPhoto({ url: uploadApi.getFullUrl(membership.user.idPhotoUrl!), alt: "ID Document" });
                      }}
                    >
                      <NextImage 
                        src={uploadApi.getFullUrl(membership.user.idPhotoUrl)} 
                        alt="ID Photo" 
                        fill 
                        className="object-cover transition-transform group-hover:scale-105"
                      />
                      <div className="absolute inset-0 bg-black/20 group-hover:bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                        <ZoomIn size={14} className="text-white" />
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* Right: Personal Details */}
            <div className="p-6 flex flex-col justify-center space-y-4 bg-gradient-to-br from-white/[0.02] to-transparent">
              <div>
                <p className="text-[10px] font-black text-[#F1C40F] uppercase tracking-[0.2em] mb-1">Full Name</p>
                <p className="text-xl font-black text-white tracking-tight leading-tight italic uppercase">{membership.user?.fullName || "Member"}</p>
              </div>

              {membership.user?.dob && (
                <div>
                  <p className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-1">Date of Birth</p>
                  <p className="text-sm text-zinc-300 font-medium">{new Date(membership.user.dob).toLocaleDateString()}</p>
                </div>
              )}

              <div>
                <p className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-1">Email Address</p>
                <p className="text-sm text-zinc-300 font-medium break-all">{membership.user?.email}</p>
              </div>
              
              {(membership.user?.phoneNumber || membership.user?.phone) && (
                <div>
                  <p className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-1">Phone Number</p>
                  <p className="text-sm text-zinc-300 font-medium">{membership.user.phoneNumber || membership.user.phone}</p>
                </div>
              )}
              
              {membership.user?.address && (
                <div>
                  <p className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-1">Home Address</p>
                  <p className="text-sm text-zinc-300 font-medium leading-tight">{membership.user.address}</p>
                </div>
              )}

              {membership.user?.medicalConditions && (
                <div className="p-3 bg-red-500/5 border border-red-500/10 rounded-2xl">
                  <p className="text-[10px] font-black text-red-400/80 uppercase tracking-[0.2em] mb-1">Health Information</p>
                  <p className="text-xs text-red-200/60 font-medium leading-relaxed italic">&quot;{membership.user.medicalConditions}&quot;</p>
                </div>
              )}
            </div>
          </div>

          {/* Bottom Row: Plan Quick Stats */}
          <div className="grid grid-cols-4 border-t border-white/5 bg-black/20">
            <div className="p-4 border-r border-white/5 text-center">
              <p className="text-[9px] font-black text-zinc-500 uppercase tracking-widest mb-1">Plan</p>
              <p className="text-[11px] text-white font-bold truncate">{membership.plan.name}</p>
            </div>
            <div className="p-4 border-r border-white/5 text-center">
              <p className="text-[9px] font-black text-zinc-500 uppercase tracking-widest mb-1">Price</p>
              <p className="text-[11px] text-[#F1C40F] font-black">${membership.plan.price}/mo</p>
            </div>
            <div className="p-4 border-r border-white/5 text-center">
              <p className="text-[9px] font-black text-zinc-500 uppercase tracking-widest mb-1">Start</p>
              <p className="text-[11px] text-white font-medium">{new Date(membership.startDate).toLocaleDateString()}</p>
            </div>
            <div className="p-4 text-center">
              <p className="text-[9px] font-black text-zinc-500 uppercase tracking-widest mb-1">End</p>
              <p className="text-[11px] text-white font-medium">{new Date(membership.endDate).toLocaleDateString()}</p>
            </div>
          </div>
        </div>

        {/* Weight Progress Section */}
        {membership.user.weightHistory && membership.user.weightHistory.length > 0 && (
          <div className="px-8 mt-0 mb-8 animate-in fade-in slide-in-from-top-4 duration-500">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <div className="w-1 h-1 rounded-full bg-[#F1C40F] animate-pulse" />
                <h3 className="text-[10px] font-black text-[#F1C40F] uppercase tracking-[0.2em] italic">Body Composition Progress</h3>
              </div>
              <div className="px-2.5 py-1 bg-[#F1C40F]/10 rounded-lg border border-[#F1C40F]/20">
                <p className="text-[10px] text-[#F1C40F] font-black italic tracking-tighter tabular-nums uppercase">
                  Current: {membership.user.weightHistory[0].weight} KG
                </p>
              </div>
            </div>

            <div className="bg-white/[0.01] border border-white/5 rounded-3xl overflow-hidden shadow-2xl backdrop-blur-sm">
              <div className="divide-y divide-white/5 p-2">
                {membership.user.weightHistory.slice(0, 5).map((record, index, array) => {
                  const nextRecord = array[index + 1];
                  const diff = nextRecord ? Math.abs(record.weight - nextRecord.weight) : 0;
                  const isLoss = nextRecord ? record.weight < nextRecord.weight : false;
                  const isGain = nextRecord ? record.weight > nextRecord.weight : false;
                  
                  return (
                    <div key={record.id} className="p-4 flex items-center justify-between group hover:bg-white/[0.02] transition-all rounded-2xl">
                      <div className="flex items-center gap-4">
                        <div className="flex flex-col">
                          <span className="text-[10px] text-zinc-500 font-black uppercase tracking-widest leading-none mb-1">
                            {new Date(record.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                          </span>
                          <span className="text-[8px] text-zinc-600 font-bold uppercase tracking-tighter">
                            {new Date(record.date).toLocaleDateString('en-US', { year: 'numeric' })}
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center gap-6">
                        {nextRecord && (
                          <div className={`flex items-center gap-1.5 px-2 py-0.5 rounded-full border ${
                            isLoss ? 'bg-emerald-500/5 border-emerald-500/10 text-emerald-400' : 
                            isGain ? 'bg-red-500/5 border-red-500/10 text-red-400' : 
                            'bg-zinc-500/5 border-zinc-500/10 text-zinc-500'
                          }`}>
                            <span className="text-[9px] font-black italic tracking-widest uppercase">
                              {isLoss ? '📉 DOWN' : isGain ? '📈 UP' : 'STABLE'}
                            </span>
                            {diff !== 0 && (
                              <span className="text-[10px] font-black tabular-nums border-l border-current/20 pl-1.5 ml-0.5">
                                {isGain ? '+' : '-'}{diff.toFixed(1)}
                              </span>
                            )}
                          </div>
                        )}
                        <div className="text-right">
                          <span className="text-sm text-white font-black italic tracking-tighter tabular-nums drop-shadow-[0_0_8px_rgba(255,255,255,0.1)]">
                            {record.weight} <span className="text-[8px] text-zinc-600 not-italic uppercase font-bold ml-0.5">KG</span>
                          </span>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
              
              {/* Footer indicator - Progress summary */}
              <div className="bg-black/40 p-3 flex items-center justify-center border-t border-white/5">
                <p className="text-[8px] font-black text-zinc-600 uppercase tracking-[0.3em]">
                  Physical Evolution Tracking Active
                </p>
              </div>
            </div>
          </div>
        )}


        {!isOwner && (
          <>
            {/* Status Selection */}
            <div className="mb-6">
              <label className="amirani-label mb-3">Membership Status</label>
              <div className="grid grid-cols-3 gap-2">
                {STATUS_OPTIONS.filter((o) => o.value !== "ALL").map((option) => (
                  <button
                    key={option.value}
                    onClick={() => setSelectedStatus(option.value as MembershipStatus)}
                    className={`px-3 py-2.5 rounded-xl text-xs font-bold transition-all ${
                      selectedStatus === option.value
                        ? option.color + " ring-2 ring-[#F1C40F]/20"
                        : "bg-[#121721] text-zinc-500 border border-zinc-800 hover:border-zinc-700 hover:text-zinc-300"
                    }`}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Identity Verification Legend */}
            <div className="p-3 bg-green-500/5 border border-green-500/10 rounded-xl flex items-start gap-3">
              <div className="mt-0.5 w-1.5 h-1.5 rounded-full bg-green-500" />
              <p className="text-[10px] text-green-400 font-medium leading-relaxed">
                Induction protocol: Verify that the biometric selfie matches the government identification documents.
              </p>
            </div>

            {/* Trainer Assignment */}
            <div className="mb-6">
              <CustomSelect
                label="Assigned Trainer"
                value={selectedTrainerId || ""}
                onChange={(value) => setSelectedTrainerId(value || null)}
                options={[
                  { value: "", label: "No trainer assigned" },
                  ...(trainers?.map((t) => ({
                    value: t.id,
                    label: `${t.fullName}${t.specialization ? ` - ${t.specialization}` : ""}`,
                  })) || []),
                ]}
              />
            </div>
          </>
        )}

        {!isOwner && (
          <div className="mb-8">
            <label className="amirani-label mb-3">Quick Actions</label>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <button
                onClick={() => setShowEditModal(true)}
                className="flex items-center justify-center gap-2 px-4 py-4 bg-[#F1C40F]/10 text-[#F1C40F] rounded-2xl text-sm font-black uppercase tracking-widest hover:bg-[#F1C40F]/20 transition-all border border-[#F1C40F]/20 shadow-lg shadow-[#F1C40F]/5"
              >
                <Edit3 size={18} />
                Edit Profile
              </button>
              <button
                onClick={() => {
                  if (window.confirm("Are you sure you want to completely remove this member from the branch?")) {
                    removeMemberMutation.mutate();
                  }
                }}
                disabled={removeMemberMutation.isPending}
                className="flex items-center justify-center gap-2 px-4 py-4 bg-red-500/10 text-red-500 rounded-2xl text-sm font-black uppercase tracking-widest hover:bg-red-500/20 transition-all border border-red-500/20 shadow-lg shadow-red-500/5 disabled:opacity-50"
              >
                <Trash2 size={18} />
                {removeMemberMutation.isPending ? "REMOVING..." : "REMOVE MEMBER"}
              </button>
            </div>
          </div>
        )}

        {/* Error Display */}
        {(updateStatusMutation.isError || assignTrainerMutation.isError) && (
          <div className="mb-4 p-4 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-xs font-bold">
            Failed to update membership. Please verify your connection.
          </div>
        )}

        {/* Actions */}
          </div>
        </div>

        {/* FIXED FOOTER */}
        <div className="px-8 pt-0 pb-0 shrink-0">
          {submitError && (
            <div className="mx-0 mb-0 mt-4 px-4 py-3 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-400 text-xs font-bold">
              {submitError}
            </div>
          )}
        </div>
        <div className="p-8 bg-white/[0.02] border-t border-white/5 flex gap-3 shrink-0">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-4 border border-white/10 text-zinc-500 rounded-2xl hover:bg-white/5 hover:text-white transition-all font-black text-[10px] uppercase tracking-widest"
          >
            Cancel
          </button>
          {!isOwner && (
            <button
              onClick={handleSave}
              disabled={isLoading}
              className="flex-[2] px-4 py-4 bg-[#F1C40F] text-black font-black rounded-2xl hover:bg-[#F1C40F]/90 transition-all shadow-xl shadow-[#F1C40F]/20 disabled:opacity-50 text-[10px] uppercase tracking-widest"
            >
              {isLoading ? "SAVING..." : "SAVE CHANGES"}
            </button>
          )}
        </div>
      </div>

      {/* Photo Viewer Lightbox */}
      {viewingPhoto && (
        <PhotoViewModal
          url={viewingPhoto.url}
          alt={viewingPhoto.alt}
          onClose={() => setViewingPhoto(null)}
        />
      )}

      {/* Edit Profile Modal */}
      {showEditModal && (
        <EditMemberModal
          gymId={gymId}
          token={token}
          membership={membership}
          requirements={registrationRequirements}
          onClose={() => setShowEditModal(false)}
        />
      )}
    </div>
  );
}
