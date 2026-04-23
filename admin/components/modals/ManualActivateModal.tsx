"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { X, Zap, Search, RefreshCw, Users } from "lucide-react";
import { branchApi, MemberSearchResult, ManualActivationRequest } from "@/lib/api";
import { CustomSelect } from "@/components/ui/Select";
import { ThemedDatePicker } from "@/components/ui/ThemedDatePicker";

interface ManualActivateModalProps {
  gymId: string;
  token: string;
  onClose: () => void;
  onSuccess?: () => void;
  members?: MemberSearchResult[]; // Optional pre-loaded members for quick search
}

export function ManualActivateModal({ gymId, token, onClose, onSuccess, members: preloadedMembers }: ManualActivateModalProps) {
  const queryClient = useQueryClient();
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedMember, setSelectedMember] = useState<MemberSearchResult | null>(
    (preloadedMembers && preloadedMembers.length === 1) ? preloadedMembers[0] : null
  );
  const [formData, setFormData] = useState({
    planId: "",
    startDate: new Date().toISOString().split('T')[0],
  });

  // Fetch plans
  const { data: plans } = useQuery({
    queryKey: ["plans", gymId],
    queryFn: () => branchApi.getPlans(gymId, token),
    enabled: !!gymId && !!token,
  });

  // Search members if not preloaded or if search query is active
  const { data: searchResults, isLoading: searching } = useQuery({
    queryKey: ["member-search", gymId, searchQuery],
    queryFn: () => branchApi.searchMembers(gymId, searchQuery, token, 5),
    enabled: !!gymId && !!token && searchQuery.length >= 2 && !selectedMember,
  });

  const activateMutation = useMutation({
    mutationFn: (data: ManualActivationRequest) => branchApi.manualActivate(gymId, data, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["members", gymId] });
      if (onSuccess) onSuccess();
      onClose();
    },
    onError: () => {}
  });

  const filteredMembers = preloadedMembers 
    ? preloadedMembers.filter(m => 
        m.fullName?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        m.email?.toLowerCase().includes(searchQuery.toLowerCase())
      ).slice(0, 5)
    : searchResults;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedMember || !formData.planId) return;
    
    activateMutation.mutate({
      memberId: selectedMember.id,
      planId: formData.planId,
      startDate: formData.startDate,
    });
  };

  const planOptions = plans?.map(plan => ({
    value: plan.id,
    label: `${plan.name} - $${plan.price}/${plan.durationValue}${plan.durationUnit}`
  })) || [];

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-500">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-lg max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.8)] overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
          <div>
            <h2 className="text-2xl font-black text-white tracking-tight flex items-center gap-3">
              <Zap className="text-[#F1C40F]" size={28} />
              ACTIVATE PLAN
            </h2>
            <p className="text-zinc-500 text-xs mt-1 font-bold uppercase tracking-widest leading-none">
              <span className="text-[#F1C40F]/50 mr-2">●</span>
              Manually activate or renew a subscription
            </p>
          </div>
          <button onClick={onClose} className="p-3 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-2xl transition-all border border-white/5 shadow-inner">
            <X size={24} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <form onSubmit={handleSubmit} className="space-y-8">
          <div className="space-y-6">
            <div>
              <label className="amirani-label font-black">Member Selection</label>
              
              {selectedMember ? (
                <div className="bg-[#F1C40F]/5 border border-[#F1C40F]/20 rounded-2xl p-5 flex items-center justify-between group transition-all hover:bg-[#F1C40F]/10">
                  <div className="flex items-center gap-4">
                    <div className="w-14 h-14 bg-[#F1C40F]/10 rounded-2xl flex items-center justify-center shadow-inner">
                      <Users className="text-[#F1C40F]" size={28} />
                    </div>
                    <div>
                      <p className="text-white font-black uppercase tracking-tight text-lg">{selectedMember.fullName}</p>
                      <p className="text-zinc-500 text-xs font-bold uppercase tracking-widest leading-none mt-1">{selectedMember.email}</p>
                    </div>
                  </div>
                  <button 
                    type="button"
                    onClick={() => setSelectedMember(null)}
                    className="p-3 bg-white/5 hover:bg-red-500/20 text-zinc-500 hover:text-red-400 rounded-xl transition-all border border-white/5"
                  >
                    <X size={20} />
                  </button>
                </div>
              ) : (
                <div className="relative group">
                  <div className="absolute left-5 top-1/2 -translate-y-1/2 text-zinc-600 group-focus-within:text-[#F1C40F] transition-colors">
                    <Search size={22} />
                  </div>
                  <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search by name, email or phone..."
                    className="w-full amirani-input amirani-input-with-icon font-bold"
                    autoFocus
                  />
                                    {searchQuery.length >= 2 && filteredMembers && filteredMembers.length > 0 && !selectedMember && (
                    <div className="absolute top-full left-0 right-0 mt-3 bg-[#121721] border border-white/10 rounded-[1.5rem] overflow-hidden shadow-[0_20px_50px_rgba(0,0,0,0.5)] z-[100] max-h-64 overflow-y-auto amirani-scrollbar backdrop-blur-xl">
                      {filteredMembers.map((m: MemberSearchResult) => (
                        <button
                          key={m.id}
                          type="button"
                          onClick={() => {
                            setSelectedMember(m);
                            setSearchQuery("");
                          }}
                          className="w-full px-6 py-4 flex items-center gap-4 hover:bg-white/5 border-b border-white/5 last:border-0 transition-all text-left group"
                        >
                          <div className="w-12 h-12 bg-[#F1C40F]/5 group-hover:bg-[#F1C40F]/10 rounded-xl flex items-center justify-center transition-all">
                            <Users className="text-[#F1C40F]/50 group-hover:text-[#F1C40F]" size={22} />
                          </div>
                          <div>
                            <p className="text-white font-black text-sm tracking-tight uppercase leading-none mb-1 group-hover:text-[#F1C40F] transition-colors">{m.fullName}</p>
                            <p className="text-zinc-500 text-[10px] uppercase font-bold tracking-widest">{m.email}</p>
                          </div>
                        </button>
                      ))}
                    </div>
                  )}
                  
                  {(searching || (searchQuery.length >= 2 && (!filteredMembers || filteredMembers.length === 0) && !searching)) && (
                    <div className="absolute top-full left-0 right-0 mt-3 bg-[#121721] border border-white/10 rounded-[1.5rem] p-8 text-center shadow-2xl z-[100] backdrop-blur-xl">
                      {searching ? (
                        <div className="flex flex-col items-center gap-3">
                          <RefreshCw className="animate-spin text-[#F1C40F]" size={24} />
                          <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Searching Members...</p>
                        </div>
                      ) : (
                        <div className="flex flex-col items-center gap-2">
                          <p className="text-sm font-black text-white uppercase tracking-tight italic">No Results Found</p>
                          <p className="text-[10px] font-bold text-zinc-600 uppercase tracking-widest leading-relaxed">System scan could not identify matching personnel</p>
                        </div>
                      )}
                    </div>
                  )}

                </div>
              )}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="md:col-span-2">
                <CustomSelect
                  label="Subscription Plan"
                  required
                  value={formData.planId}
                  onChange={(val) => setFormData({ ...formData, planId: val })}
                  options={planOptions}
                  placeholder="Select activation plan"
                />
              </div>

              <div className="md:col-span-2">
                <ThemedDatePicker
                  label="Activation Start Date"
                  value={formData.startDate}
                  onChange={(date) => setFormData({ ...formData, startDate: date })}
                  required
                />
              </div>
            </div>
          </div>

          {activateMutation.error && (
            <div className="mt-8 p-5 bg-red-500/10 border border-red-500/20 rounded-[1.5rem] text-red-500 text-xs font-black uppercase tracking-widest leading-relaxed flex items-center gap-3">
              <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
              {(activateMutation.error as Error).message}
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
            disabled={activateMutation.isPending || !selectedMember || !formData.planId}
            className="flex-[2] px-8 py-5 rounded-[2rem] bg-[#F1C40F] !text-black font-black uppercase tracking-widest hover:bg-[#D4AC0D] transition-all shadow-2xl shadow-[#F1C40F]/20 disabled:opacity-50 text-xs flex items-center justify-center gap-3"
          >
            {activateMutation.isPending ? (
              <RefreshCw className="animate-spin" size={20} />
            ) : (
              <>
                <Zap size={20} />
                ACTIVATE MEMBER
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
