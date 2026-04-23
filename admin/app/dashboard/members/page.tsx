"use client";

import { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import { membershipsApi, gymsApi, uploadApi, MembershipStatus, Membership, Gym, RegistrationRequirements, MemberSearchResult } from "@/lib/api";
import { Calendar, X, UserCog, Shield, Users, UserPlus, Zap } from "lucide-react";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { ManualRegisterModal } from "@/components/modals/ManualRegisterModal";
import { ManualActivateModal } from "@/components/modals/ManualActivateModal";
import NextImage from "next/image";

import { MemberManageModal, STATUS_OPTIONS } from "@/components/modals/MemberManageModal";
import { PageHeader } from "@/components/ui/PageHeader";
import { FilterBar } from "@/components/ui/FilterBar";
import { DataTable, ColumnDef } from "@/components/ui/DataTable";
import StatusBadge from "../../../components/ui/StatusBadge";

interface RegistrationPolicyModalProps {
  gym: Gym;
  token: string;
  onClose: () => void;
}

const REGISTRATION_SECTIONS = [
  {
    title: "Basic Information",
    fields: [
      { key: "fullName", label: "Full Name (First & Last)", description: "Always required for login" },
      { key: "dateOfBirth", label: "Date of Birth" },
      { key: "personalNumber", label: "Personal Number (ID/SSN)" },
      { key: "phoneNumber", label: "Phone Number" },
      { key: "address", label: "Home Address" },
    ],
  },
  {
    title: "Security & Verification",
    fields: [
      { key: "selfiePhoto", label: "Selfie Photo", description: "Biometric verification" },
      { key: "idPhoto", label: "ID / Passport Photo", description: "Identity verification" },
    ],
  },
  {
    title: "Medical & Health (Optional)",
    fields: [
      { key: "healthInfo", label: "Member Health Problems", description: "Members will input their health info during registration" },
    ],
  },
];

function RegistrationPolicyModal({ gym, token, onClose }: RegistrationPolicyModalProps) {
  const queryClient = useQueryClient();
  const [requirements, setRequirements] = useState<RegistrationRequirements>(
    gym.registrationRequirements || {
      fullName: true,
      phoneNumber: true,
      healthInfo: false,
    }
  );

  const updateMutation = useMutation({
    mutationFn: (newRequirements: RegistrationRequirements) =>
      gymsApi.update(gym.id, { registrationRequirements: newRequirements }, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gyms"] });
      onClose();
    },
  });

  const toggleField = (field: keyof RegistrationRequirements) => {
    setRequirements((prev: RegistrationRequirements) => ({ ...prev, [field]: !prev[field] }));
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-2xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-2xl font-black text-white tracking-tight flex items-center gap-3 italic uppercase">
              <Shield className="text-[#F1C40F]" size={28} />
              Registration Policy
            </h2>
            <p className="text-zinc-500 text-[10px] font-black uppercase tracking-[0.2em] mt-1">Configure Membership Induction Protocol</p>
          </div>
          <button onClick={onClose} className="p-3 hover:bg-white/5 rounded-2xl transition-colors text-zinc-500 hover:text-white border border-white/5">
            <X size={24} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar scroll-smooth">
          <div className="p-8 space-y-8">
          {REGISTRATION_SECTIONS.map((section) => (
            <div key={section.title} className="space-y-4">
              <h3 className="text-xs font-bold text-[#F1C40F] uppercase tracking-widest">{section.title}</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {section.fields.map((field) => {
                  const isActive = !!requirements[field.key as keyof RegistrationRequirements];
                  const isEmail = field.key === "fullName";

                  return (
                    <button
                      key={field.key}
                      onClick={() => toggleField(field.key as keyof RegistrationRequirements)}
                      disabled={isEmail}
                      className={`flex items-start gap-4 p-4 rounded-2xl border transition-all text-left group ${
                        isActive
                          ? "bg-[#F1C40F] border-[#F1C40F] !text-black"
                          : "bg-white/[0.02] border-white/5 text-zinc-500 hover:border-white/10"
                      } ${isEmail ? "opacity-50 cursor-not-allowed" : ""}`}
                    >
                      <div className={`mt-1 w-5 h-5 rounded-md border flex items-center justify-center transition-colors ${
                        isActive ? "bg-black/20 border-black/20" : "border-zinc-700 group-hover:border-zinc-500"
                      }`}>
                        {isActive && <div className="w-2 h-2 bg-black rounded-sm" />}
                      </div>
                      <div>
                        <p className="font-bold text-sm tracking-tight">{field.label}</p>
                        {field.description && <p className="text-[10px] opacity-60 mt-0.5 line-clamp-1">{field.description}</p>}
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>

        </div>

        {/* FIXED FOOTER */}
        <div className="p-8 bg-white/[0.02] border-t border-white/5 flex gap-4 shrink-0">
          <button
            onClick={onClose}
            className="flex-1 px-6 py-4 rounded-2xl border border-white/10 text-zinc-500 font-black uppercase tracking-widest hover:bg-white/5 hover:text-white transition-all text-[10px]"
          >
            Cancel
          </button>
          <button
            onClick={() => updateMutation.mutate(requirements)}
            disabled={updateMutation.isPending}
            className="flex-[2] px-6 py-4 rounded-2xl bg-[#F1C40F] !text-black font-black uppercase tracking-widest hover:bg-[#F1C40F]/90 transition-all shadow-xl shadow-[#F1C40F]/20 disabled:opacity-50 text-[10px]"
          >
            {updateMutation.isPending ? "SAVING..." : "SAVE REGISTRATION POLICY"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function MembersPage() {
  const { token } = useAuthStore();
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState<MembershipStatus | "ALL">("ALL");
  const [managingMember, setManagingMember] = useState<Membership | null>(null);
  const [showRegistrationModal, setShowRegistrationModal] = useState(false);
  const [showManualRegisterModal, setShowManualRegisterModal] = useState(false);
  const [showManualActivateModal, setShowManualActivateModal] = useState(false);
  const [activatingMembers, setActivatingMembers] = useState<MemberSearchResult[] | undefined>(undefined);

  // Unified gym selection
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole, isBranchAdmin } = useGymSelection();

  // Get members for selected gym
  const { data: members, isLoading: membersLoading } = useQuery({
    queryKey: ["members", selectedGymId],
    queryFn: () => membershipsApi.getGymMembers(selectedGymId!, token!),
    enabled: !!token && !!selectedGymId,
  });

  const columns = useMemo<ColumnDef<Membership>[]>(() => [
    {
      header: 'Member',
      cell: (membership) => (
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full overflow-hidden border border-white/10 bg-zinc-900 flex items-center justify-center shrink-0">
            {membership.user.avatarUrl ? (
              <NextImage src={uploadApi.getFullUrl(membership.user.avatarUrl)} alt={membership.user.fullName} width={40} height={40} className="w-full h-full object-cover" />
            ) : (
              <span className="text-[#F1C40F] text-xs font-bold">{membership.user.fullName.charAt(0)}</span>
            )}
          </div>
          <div>
            <p className="text-sm font-medium text-white">{membership.user.fullName}</p>
            <p className="text-xs text-zinc-500">{membership.user.email}</p>
          </div>
        </div>
      ),
    },
    {
      header: 'Plan',
      cell: (membership) => (
        <>
          <p className="text-sm text-zinc-300">{membership.plan.name}</p>
          <p className="text-xs text-zinc-500">${membership.plan.price}/mo</p>
        </>
      ),
    },
    {
      header: 'Status',
      cell: (membership) => <StatusBadge status={membership.status} />,
    },
    {
      header: 'Trainer',
      cell: (membership) => membership.trainer ? (
        <div className="flex items-center gap-2">
          <Shield size={14} className="text-[#F1C40F]" />
          <span className="text-sm text-zinc-300">{membership.trainer.user?.fullName || 'Staff'}</span>
        </div>
      ) : (
        <span className="text-sm text-zinc-500">Not assigned</span>
      ),
    },
    {
      header: 'Expiry',
      cell: (membership) => (
        <div className="flex items-center gap-2 text-sm text-zinc-300">
          <Calendar size={14} className="text-zinc-500" />
          {new Date(membership.endDate).toLocaleDateString()}
        </div>
      ),
    },
    {
      header: 'Actions',
      cell: (membership) => (
        <div className="flex items-center gap-2">
          <button
            onClick={() => {
              setActivatingMembers([{
                id: membership.user.id,
                fullName: membership.user.fullName,
                email: membership.user.email,
                phoneNumber: membership.user.phone || null,
                memberships: [{
                  id: membership.id,
                  status: membership.status,
                  endDate: membership.endDate,
                  plan: { id: membership.plan.id, name: membership.plan.name }
                }]
              }]);
              setShowManualActivateModal(true);
            }}
            className="flex items-center gap-2 px-3 py-1.5 bg-emerald-500/10 text-emerald-500 rounded-lg text-sm hover:bg-emerald-500/20 transition-colors"
            title="Quick Renew"
          >
            <Zap size={14} />
          </button>
          <button
            onClick={() => setManagingMember(membership)}
            className="flex items-center gap-2 px-3 py-1.5 bg-[#F1C40F]/10 text-[#F1C40F] rounded-lg text-sm hover:bg-[#F1C40F]/20 transition-colors"
          >
            <UserCog size={14} />
            Manage
          </button>
        </div>
      ),
    },
  ], []);

  const filteredMembers = members?.filter((m) => {
    const matchesSearch =
      m.user.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      m.user.email.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesStatus = statusFilter === "ALL" || m.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  // Count members by status
  const statusCounts = members?.reduce(
    (acc, m) => {
      acc[m.status] = (acc[m.status] || 0) + 1;
      acc.ALL = (acc.ALL || 0) + 1;
      return acc;
    },
    {} as Record<string, number>
  ) || {};

  return (
    <div className="space-y-8">
      <PageHeader
        title="MEMBERS"
        description="Manage memberships and member details across your facilities"
        icon={<Users size={32} />}
        actions={
          <>
            {isBranchAdmin ? (
              <>
                <button
                  onClick={() => setShowManualRegisterModal(true)}
                  className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
                >
                  <UserPlus size={18} />
                  Register Member
                </button>
                <button
                  onClick={() => {
                    setActivatingMembers(undefined);
                    setShowManualActivateModal(true);
                  }}
                  className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F]/10 text-[#F1C40F] border border-[#F1C40F]/20 rounded-xl hover:bg-[#F1C40F]/20 transition-all font-black uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/5 shrink-0"
                >
                  <Zap size={18} />
                  Activate Subscription
                </button>
              </>
            ) : (
              <button
                onClick={() => setShowRegistrationModal(true)}
                className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
              >
                <Shield size={18} />
                Registration Policy
              </button>
            )}
            <GymSwitcher 
              gyms={gyms} 
              isLoading={gymsLoading} 
              disabled={userRole === "BRANCH_ADMIN"}
            />
          </>
        }
      />

      <FilterBar
        searchTerm={searchTerm}
        onSearchChange={setSearchTerm}
        statusFilter={statusFilter}
        onStatusChange={(val) => setStatusFilter(val as MembershipStatus | "ALL")}
        statusOptions={STATUS_OPTIONS}
        statusCounts={statusCounts}
      />

      <DataTable 
        data={filteredMembers} 
        columns={columns} 
        isLoading={membersLoading || gymsLoading}
        keyExtractor={(m) => m.id}
      />

      {/* Member Management Modal */}
      {managingMember && token && selectedGymId && gyms && (
        <MemberManageModal
          membership={managingMember}
          gymId={selectedGymId}
          token={token}
          registrationRequirements={gyms.find(g => g.id === selectedGymId)?.registrationRequirements}
          onClose={() => setManagingMember(null)}
        />
      )}

      {showRegistrationModal && selectedGymId && gyms && (
        <RegistrationPolicyModal
          gym={gyms.find(g => g.id === selectedGymId)!}
          token={token!}
          onClose={() => setShowRegistrationModal(false)}
        />
      )}

      {/* Manual Register Modal */}
      {showManualRegisterModal && selectedGymId && (
        <ManualRegisterModal
          gymId={selectedGymId}
          token={token!}
          onClose={() => setShowManualRegisterModal(false)}
        />
      )}

      {/* Manual Activate Modal */}
      {showManualActivateModal && selectedGymId && (
        <ManualActivateModal
          gymId={selectedGymId}
          token={token!}
          onClose={() => {
            setShowManualActivateModal(false);
            setActivatingMembers(undefined);
          }}
          members={activatingMembers}
        />
      )}
    </div>
  );
}
