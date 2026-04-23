"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { X, UserPlus, RefreshCw } from "lucide-react";
import { membershipsApi, gymsApi, RegistrationRequirements, ManualRegistrationRequest } from "@/lib/api";
import { CustomSelect } from "@/components/ui/Select";
import { ThemedDatePicker } from "@/components/ui/ThemedDatePicker";
import { PhotoUploadZone } from "@/components/ui/PhotoUploadZone";

interface RegisterFormData extends Omit<ManualRegistrationRequest, 'phoneNumber' | 'dateOfBirth' | 'personalNumber' | 'address' | 'healthInfo' | 'selfiePhoto' | 'idPhoto'> {
  phoneNumber?: string;
  dateOfBirth?: string;
  personalNumber?: string;
  address?: string;
  healthInfo?: string;
  selfiePhoto?: string;
  idPhoto?: string;
}

interface ManualRegisterModalProps {
  gymId: string;
  token: string;
  onClose: () => void;
  onSuccess?: () => void;
}

export function ManualRegisterModal({ gymId, token, onClose, onSuccess }: ManualRegisterModalProps) {
  const queryClient = useQueryClient();
  const [formData, setFormData] = useState<RegisterFormData>({
    fullName: "",
    email: "",
    phoneNumber: "",
    subscriptionPlanId: "",
    startDate: new Date().toISOString().split('T')[0],
    sendNotification: true,
    dateOfBirth: "",
    personalNumber: "",
    address: "",
    healthInfo: "",
    selfiePhoto: "",
    idPhoto: "",
  });

  // Fetch gym details to get registration requirements
  const { data: gym, isLoading: gymLoading } = useQuery({
    queryKey: ["gym-detail", gymId],
    queryFn: () => gymsApi.getById(gymId, token),
    enabled: !!gymId && !!token,
  });

  const { data: plans } = useQuery({
    queryKey: ["plans", gymId],
    queryFn: () => membershipsApi.getGymPlans(gymId, token),
    enabled: !!gymId && !!token,
  });

  const requirements: RegistrationRequirements = gym?.registrationRequirements || {
    fullName: true,
    phoneNumber: true,
  };

  const registerMutation = useMutation({
    mutationFn: (data: ManualRegistrationRequest) => membershipsApi.manualCreateMember(gymId, data, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["members", gymId] });
      if (onSuccess) onSuccess();
      onClose();
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.fullName || !formData.email || !formData.subscriptionPlanId) return;

    // Filter only required data
    const submitData: ManualRegistrationRequest = {
      fullName: formData.fullName,
      email: formData.email,
      subscriptionPlanId: formData.subscriptionPlanId,
      startDate: formData.startDate,
      sendNotification: formData.sendNotification,
    };

    if (requirements.phoneNumber) submitData.phoneNumber = formData.phoneNumber;
    if (requirements.dateOfBirth) submitData.dateOfBirth = formData.dateOfBirth;
    if (requirements.personalNumber) submitData.personalNumber = formData.personalNumber;
    if (requirements.address) submitData.address = formData.address;
    if (requirements.healthInfo) submitData.healthInfo = formData.healthInfo;
    if (requirements.selfiePhoto) submitData.selfiePhoto = formData.selfiePhoto;
    if (requirements.idPhoto) submitData.idPhoto = formData.idPhoto;

    registerMutation.mutate(submitData);
  };

  const planOptions = plans?.map(plan => ({
    value: plan.id,
    label: `${plan.name} - $${plan.price}/${plan.durationValue}${plan.durationUnit}`
  })) || [];

  if (gymLoading) return null;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-500">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-2xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.8)] overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
          <div>
            <h2 className="text-2xl font-black text-white tracking-tight flex items-center gap-3">
              <UserPlus className="text-[#F1C40F]" size={28} />
              REGISTER MEMBER
            </h2>
            <p className="text-zinc-500 text-xs mt-1 font-bold uppercase tracking-widest leading-none">
              <span className="text-[#F1C40F]/50 mr-2">●</span>
              Manually enroll a new member into {gym?.name}
            </p>
          </div>
          <button onClick={onClose} className="p-3 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-2xl transition-all border border-white/5 shadow-inner">
            <X size={24} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <form onSubmit={handleSubmit} className="space-y-8">
          {/* Photos Section if enabled */}
          {(requirements.selfiePhoto || requirements.idPhoto) && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pb-6 border-b border-white/5">
              {requirements.selfiePhoto && (
                <PhotoUploadZone
                  label="Selfie Photo (Biometric)"
                  value={formData.selfiePhoto}
                  onChange={(url) => setFormData({ ...formData, selfiePhoto: url })}
                  folder="avatars"
                  token={token}
                />
              )}
              {requirements.idPhoto && (
                <PhotoUploadZone
                  label="ID / Passport Photo"
                  value={formData.idPhoto}
                  onChange={(url) => setFormData({ ...formData, idPhoto: url })}
                  folder="avatars"
                  token={token}
                />
              )}
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Standard Required Fields */}
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

            <div>
              <label className="amirani-label font-black">Email Address *</label>
              <input
                type="email"
                required
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                className="amirani-input h-[54px] font-bold"
                placeholder="john@example.com"
              />
            </div>

            {/* Dynamic Fields based on policy */}
            {requirements.phoneNumber && (
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

            {requirements.personalNumber && (
              <div>
                <label className="amirani-label font-black">Personal Number (ID/SSN)</label>
                <input
                  type="text"
                  value={formData.personalNumber}
                  onChange={(e) => setFormData({ ...formData, personalNumber: e.target.value })}
                  className="amirani-input h-[54px] font-bold"
                  placeholder="ID Number"
                />
              </div>
            )}

            {requirements.dateOfBirth && (
              <ThemedDatePicker
                label="Date of Birth"
                value={formData.dateOfBirth || ""}
                onChange={(date) => setFormData({ ...formData, dateOfBirth: date })}
              />
            )}

            <div className="md:col-span-2">
              <CustomSelect
                label="Subscription Plan"
                required
                value={formData.subscriptionPlanId}
                onChange={(val) => setFormData({ ...formData, subscriptionPlanId: val })}
                options={planOptions}
                placeholder="Select a specific plan"
              />
            </div>

            <ThemedDatePicker
              label="Membership Start Date"
              value={formData.startDate || ""}
              onChange={(date) => setFormData({ ...formData, startDate: date })}
              required
            />

            {requirements.address && (
              <div className="md:col-span-2">
                <label className="amirani-label font-black">Home Address</label>
                <textarea
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                  className="amirani-textarea font-bold min-h-[100px] bg-white/[0.02] border-white/5"
                  placeholder="Full residental address (Street, City, Zip)"
                />
              </div>
            )}

            {requirements.healthInfo && (
              <div className="md:col-span-2">
                <label className="amirani-label font-black">Health Problems / Notes</label>
                <textarea
                  value={formData.healthInfo}
                  onChange={(e) => setFormData({ ...formData, healthInfo: e.target.value })}
                  className="amirani-textarea font-bold min-h-[100px] bg-white/[0.02] border-white/5"
                  placeholder="Document any medical conditions, allergies, or physical limitations..."
                />
              </div>
            )}
          </div>

          <div className="flex flex-col gap-6">
            <label className="flex items-center gap-4 cursor-pointer group py-4 px-6 bg-white/[0.02] border border-white/5 rounded-2xl hover:bg-white/[0.04] transition-all">
              <div className={`w-7 h-7 rounded-xl border-2 flex items-center justify-center transition-all ${
                formData.sendNotification 
                  ? "bg-[#F1C40F] border-[#F1C40F] shadow-[0_0_15px_rgba(241,196,15,0.3)]" 
                  : "bg-[#121721] border-white/10 group-hover:border-white/20"
              }`}>
                {formData.sendNotification && <div className="w-3.5 h-3.5 bg-black rounded-lg animate-in zoom-in duration-300" />}
              </div>
              <input
                type="checkbox"
                className="hidden"
                checked={formData.sendNotification}
                onChange={(e) => setFormData({ ...formData, sendNotification: e.target.checked })}
              />
              <div>
                <p className="text-sm font-black text-white tracking-tight uppercase leading-none mb-1">Send welcome notification</p>
                <p className="text-[10px] font-bold text-zinc-600 uppercase tracking-widest">Send automated welcome SMS/Email with member details</p>
              </div>
            </label>

            {registerMutation.error && (
              <div className="p-5 bg-red-500/10 border border-red-500/20 rounded-[1.5rem] text-red-500 text-xs font-black uppercase tracking-widest leading-relaxed flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
                {(registerMutation.error as Error).message}
              </div>
            )}

          </div>
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
              disabled={registerMutation.isPending || !formData.fullName || !formData.email || !formData.subscriptionPlanId}
              className="flex-[2] px-8 py-5 rounded-[2rem] bg-[#F1C40F] !text-black font-black uppercase tracking-widest hover:bg-[#D4AC0D] transition-all shadow-2xl shadow-[#F1C40F]/20 disabled:opacity-50 text-xs flex items-center justify-center gap-3"
            >
              {registerMutation.isPending ? (
                <RefreshCw className="animate-spin" size={20} />
              ) : (
                <>
                  <UserPlus size={20} />
                  REGISTER MEMBER
                </>
              )}
            </button>
          </div>
      </div>
    </div>
  );
}
