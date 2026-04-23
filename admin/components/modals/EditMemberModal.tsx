"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { X, Save, RefreshCw } from "lucide-react";
import { membershipsApi, RegistrationRequirements, Membership, User } from "@/lib/api";
import { ThemedDatePicker } from "@/components/ui/ThemedDatePicker";
import { PhotoUploadZone } from "@/components/ui/PhotoUploadZone";

interface EditMemberModalProps {
  gymId: string;
  token: string;
  membership: Membership;
  requirements?: RegistrationRequirements;
  onClose: () => void;
  onSuccess?: () => void;
}

export function EditMemberModal({ gymId, token, membership, requirements, onClose, onSuccess }: EditMemberModalProps) {
  const queryClient = useQueryClient();
  const user = membership.user;
  
  const [formData, setFormData] = useState<Partial<User>>({
    fullName: user.fullName || "",
    phoneNumber: user.phoneNumber || user.phone || "",
    personalNumber: user.personalNumber || "",
    dob: user.dob || "",
    address: user.address || "",
    idPhotoUrl: user.idPhotoUrl || "",
    avatarUrl: user.avatarUrl || "",
    medicalConditions: user.medicalConditions || "",
  });

  const reqs = requirements || { fullName: true, phoneNumber: true };

  const updateMutation = useMutation({
    mutationFn: (data: Partial<User>) => membershipsApi.updateMemberProfile(gymId, user.id, data, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["members", gymId] });
      if (onSuccess) onSuccess();
      onClose();
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.fullName) return;

    // Filter only required data based on policy
    const submitData: Partial<User> = { fullName: formData.fullName };
    if (reqs.phoneNumber) submitData.phoneNumber = formData.phoneNumber;
    if (reqs.dateOfBirth) submitData.dob = formData.dob;
    if (reqs.personalNumber) submitData.personalNumber = formData.personalNumber;
    if (reqs.selfiePhoto) submitData.avatarUrl = formData.avatarUrl; 
    if (reqs.idPhoto) submitData.idPhotoUrl = formData.idPhotoUrl; 
    if (reqs.healthInfo) submitData.medicalConditions = formData.medicalConditions;

    // The backend updateMemberProfile service method expects:
    // data.idPhoto to map to idPhotoUrl (as we wrote in the service)
    // To update the actual avatar, we could pass avatarUrl directly to user.update.
    // In our backend service, we wrote:
    // const updateData: any = { ...data };
    // if (data.idPhoto) { updateData.idPhotoUrl = data.idPhoto; delete updateData.idPhoto; }
    // Let's pass what's needed:
    if (reqs.selfiePhoto) submitData.avatarUrl = formData.avatarUrl;
    
    updateMutation.mutate(submitData);
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-[70] p-4 transition-all animate-in fade-in duration-500">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-2xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.8)] overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
          <div>
            <h2 className="text-2xl font-black text-white tracking-tight flex items-center gap-3 italic">
              EDIT MEMBER PROFILE
            </h2>
            <p className="text-zinc-500 text-xs mt-1 font-bold uppercase tracking-widest leading-none">
              <span className="text-[#F1C40F]/50 mr-2">●</span>
              {user.email}
            </p>
          </div>
          <button onClick={onClose} className="p-3 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-2xl transition-all border border-white/5 shadow-inner">
            <X size={24} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <form onSubmit={handleSubmit} className="space-y-8">
            {/* Photos Section */}
            {(reqs.selfiePhoto || reqs.idPhoto) && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pb-6 border-b border-white/5">
                {reqs.selfiePhoto && (
                  <PhotoUploadZone
                    label="Selfie Photo (Biometric)"
                    value={formData.avatarUrl}
                    onChange={(url) => setFormData({ ...formData, avatarUrl: url })}
                    folder="avatars"
                    token={token}
                  />
                )}
                {reqs.idPhoto && (
                  <PhotoUploadZone
                    label="ID / Passport Photo"
                    value={formData.idPhotoUrl}
                    onChange={(url) => setFormData({ ...formData, idPhotoUrl: url })}
                    folder="avatars"
                    token={token}
                  />
                )}
              </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="amirani-label font-black">Member Full Name *</label>
                <input
                  type="text"
                  required
                  value={formData.fullName}
                  onChange={(e) => setFormData({ ...formData, fullName: e.target.value })}
                  className="amirani-input h-[54px] font-bold"
                  placeholder="e.g. John Doe"
                />
              </div>

              {reqs.phoneNumber && (
                <div>
                  <label className="amirani-label font-black">Phone Number</label>
                  <input
                    type="text"
                    value={formData.phoneNumber}
                    onChange={(e) => setFormData({ ...formData, phoneNumber: e.target.value })}
                    className="amirani-input h-[54px] font-bold"
                    placeholder="+1 234 567 890"
                  />
                </div>
              )}

              {reqs.personalNumber && (
                <div>
                  <label className="amirani-label font-black">Personal Number (ID/SSN)</label>
                  <input
                    type="text"
                    value={formData.personalNumber}
                    onChange={(e) => setFormData({ ...formData, personalNumber: e.target.value })}
                    className="amirani-input h-[54px] font-bold"
                  />
                </div>
              )}

              {reqs.dateOfBirth && (
                <ThemedDatePicker
                  label="Date of Birth"
                  value={formData.dob || ""}
                  onChange={(date) => setFormData({ ...formData, dob: date })}
                />
              )}

              {reqs.address && (
                <div className="md:col-span-2">
                  <label className="amirani-label font-black">Home Address</label>
                  <textarea
                    value={formData.address}
                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                    className="amirani-textarea font-bold min-h-[100px] bg-white/[0.02] border-white/5"
                  />
                </div>
              )}

              {reqs.healthInfo && (
                <div className="md:col-span-2">
                  <label className="amirani-label font-black text-red-400/80">Medical / Health Information</label>
                  <textarea
                    value={formData.medicalConditions}
                    onChange={(e) => setFormData({ ...formData, medicalConditions: e.target.value })}
                    className="amirani-textarea font-bold min-h-[100px] bg-red-500/5 border-red-500/10 focus:border-red-500/30 text-red-100 placeholder:text-red-900/40"
                    placeholder="Describe any critical medical conditions or health notes..."
                  />
                </div>
              )}
            </div>

            {updateMutation.error && (
              <div className="p-5 bg-red-500/10 border border-red-500/20 rounded-[1.5rem] text-red-500 text-xs font-black uppercase tracking-widest leading-relaxed flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
                {(updateMutation.error as Error).message}
              </div>
            )}
          </form>
        </div>

        {/* FIXED FOOTER */}
        <div className="p-8 border-t border-white/5 bg-white/[0.01] flex gap-4 shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 px-8 py-5 rounded-[2rem] border border-white/10 text-zinc-500 font-black uppercase tracking-widest hover:bg-white/5 hover:text-white transition-all shadow-lg text-xs"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={updateMutation.isPending || !formData.fullName}
            className="flex-[2] px-8 py-5 rounded-[2rem] bg-[#F1C40F] text-black font-black uppercase tracking-widest hover:bg-[#D4AC0D] transition-all shadow-2xl shadow-[#F1C40F]/20 disabled:opacity-50 text-xs flex items-center justify-center gap-3"
          >
            {updateMutation.isPending ? (
              <RefreshCw className="animate-spin" size={20} />
            ) : (
              <>
                <Save size={20} />
                SAVE PROFILE
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
