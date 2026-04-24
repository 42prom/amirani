"use client";

import { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { adminApi, platformApi, type CreateUserData, type GymOwner } from "@/lib/api";
import { Plus, UserCog, Building2, X, Edit2, RefreshCw, Search, DollarSign, Users } from "lucide-react";
import { useRouter, useSearchParams } from "next/navigation";
import { PageHeader } from "@/components/ui/PageHeader";
import { useToast } from "@/components/ui/Toast";

export default function GymOwnersPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const searchParams = useSearchParams();
  const initialSearch = searchParams.get("search") || "";
  
  const toast = useToast();
  const [showModal, setShowModal] = useState(false);
  const [editingOwner, setEditingOwner] = useState<GymOwner | null>(null);
  const [pricingOwner, setPricingOwner] = useState<GymOwner | null>(null);
  const [extendTrialOwner, setExtendTrialOwner] = useState<GymOwner | null>(null);
  const [searchTerm, setSearchTerm] = useState(initialSearch);
  const now = useMemo(() => new Date().getTime(), []);

  const { data: gymOwners, isLoading, error } = useQuery({
    queryKey: ["gym-owners"],
    queryFn: () => adminApi.getGymOwners(token!),
    enabled: !!token,
  });

  const filteredOwners = useMemo(() => {
    if (!gymOwners) return [];
    if (!searchTerm) return gymOwners;
    const lower = searchTerm.toLowerCase();
    return gymOwners.filter(
      (o) =>
        o.fullName.toLowerCase().includes(lower) ||
        o.email.toLowerCase().includes(lower)
    );
  }, [gymOwners, searchTerm]);

  const createMutation = useMutation({
    mutationFn: (data: CreateUserData) => adminApi.createGymOwner(data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-owners"] });
      setShowModal(false);
    },
  });

  const updateMutation = useMutation({
    mutationFn: (data: { id: string; updates: Partial<CreateUserData> & { isActive?: boolean } }) =>
      adminApi.updateGymOwner(data.id, data.updates, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-owners"] });
      setEditingOwner(null);
    },
  });

  const extendSubscriptionMutation = useMutation({
    mutationFn: (data: { id: string; days: number; amount: number; paymentMethod: string; notes?: string }) =>
      platformApi.extendSaaSSubscription(data.id, {
        days: data.days,
        amount: data.amount,
        paymentMethod: data.paymentMethod,
        notes: data.notes
      }, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-owners"] });
      queryClient.invalidateQueries({ queryKey: ["saas-subscriptions"] });
      setPricingOwner(null);
      toast.success("Subscription extended successfully");
    },
    onError: (err: Error) => toast.error(err.message || "Failed to extend subscription"),
  });

  const toggleActiveMutation = useMutation({
    mutationFn: (owner: GymOwner) =>
      owner.isActive
        ? adminApi.deactivateUser(owner.id, token!)
        : adminApi.activateUser(owner.id, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-owners"] });
    },
  });

  const extendTrialMutation = useMutation({
    mutationFn: (data: { id: string; days: number }) =>
      adminApi.extendSaaSTrial(data.id, data.days, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-owners"] });
      setExtendTrialOwner(null);
      toast.success("Trial extended successfully");
    },
    onError: (err: Error) => toast.error(err.message || "Failed to extend trial"),
  });

  // Redirect if not super admin
  if (!isSuperAdmin(user?.role)) {
    router.push("/dashboard");
    return null;
  }

  return (
    <div>
      <PageHeader
        title="Gym Owners"
        description="Manage gym owner accounts"
        icon={<UserCog size={32} />}
        actions={
          <div className="flex flex-col md:flex-row items-center gap-4">
            <div className="relative w-full md:w-64">
              <Search className="absolute left-3 text-zinc-500" size={18} />
              <input
                type="text"
                placeholder="Search..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="amirani-input amirani-input-with-icon !bg-white/[0.03] !border-white/10"
              />
            </div>
            <button
              onClick={() => setShowModal(true)}
              className="w-full md:w-auto flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10"
            >
              <Plus size={18} />
              Add Gym Owner
            </button>
          </div>
        }
      />

      {/* Gym Owners List */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl">
        {isLoading ? (
          <div className="p-12 flex flex-col items-center gap-3 text-zinc-500">
            <RefreshCw className="animate-spin" size={28} />
            <span className="text-sm">Loading gym owners…</span>
          </div>
        ) : error ? (
          <div className="p-12 text-center">
            <p className="text-red-400 text-sm">{(error as Error).message || "Failed to load gym owners"}</p>
          </div>
        ) : gymOwners?.length === 0 ? (
          <div className="p-12 text-center">
            <UserCog className="mx-auto text-zinc-600 mb-4" size={48} />
            <p className="text-zinc-400">No gym owners yet</p>
            <button
              onClick={() => setShowModal(true)}
              className="mt-4 text-[#F1C40F] hover:underline"
            >
              Add your first gym owner
            </button>
          </div>
        ) : (
          <div className="divide-y divide-zinc-800">
            {filteredOwners?.map((owner) => (
              <div
                key={owner.id}
                className="p-6 flex items-center justify-between hover:bg-zinc-800/50 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 bg-[#F1C40F]/10 rounded-full flex items-center justify-center">
                    <span className="text-[#F1C40F] font-semibold">
                      {(owner.fullName || owner.email || "?").charAt(0).toUpperCase()}
                    </span>
                  </div>
                  <div>
                    <p className="font-medium text-white">{owner.fullName}</p>
                    <p className="text-sm text-zinc-400">{owner.email}</p>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <div className="flex flex-col gap-1 text-sm text-zinc-400">
                    <div className="flex items-center gap-2">
                      <Building2 size={14} className="text-[#F1C40F]" />
                      <span>{owner.ownedGyms.length} branches</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <Users size={14} className="text-[#F1C40F]" />
                      <span>{owner.ownedGyms.reduce((acc, g) => acc + g._count.memberships, 0)} members</span>
                    </div>
                  </div>
                  <button
                    onClick={() => toggleActiveMutation.mutate(owner)}
                    disabled={toggleActiveMutation.isPending}
                    className={`px-3 py-1 rounded-full text-xs font-medium transition-colors ${
                      owner.isActive
                        ? "bg-green-500/10 text-green-400 hover:bg-red-500/10 hover:text-red-400"
                        : "bg-red-500/10 text-red-400 hover:bg-green-500/10 hover:text-green-400"
                    }`}
                  >
                    {owner.isActive ? "Active" : "Inactive"}
                  </button>
                  <button
                    onClick={() => setExtendTrialOwner(owner)}
                    className="p-2 bg-zinc-800 text-blue-400 hover:text-blue-300 rounded-lg transition-colors flex items-center gap-1"
                    title="Extend Trial"
                  >
                    <RefreshCw size={16} />
                    {owner.saasTrialEndsAt && (
                      <span className="text-[10px]">
                        {(() => {
                          const ends = new Date(owner.saasTrialEndsAt).getTime();
                          return Math.ceil((ends - now) / (1000 * 60 * 60 * 24));
                        })()}d left
                      </span>
                    )}
                  </button>
                  <button
                    onClick={() => setEditingOwner(owner)}
                    className="p-2 bg-zinc-800 text-zinc-400 hover:text-white rounded-lg transition-colors"
                    title="Edit Details"
                  >
                    <Edit2 size={16} />
                  </button>
                  <button
                    onClick={() => setPricingOwner(owner)}
                    className="p-2 bg-zinc-800 text-[#F1C40F]/70 hover:text-[#F1C40F] rounded-lg transition-colors flex items-center gap-2"
                    title="Subscription & Pricing"
                  >
                    <DollarSign size={16} />
                    <span className="text-[10px] uppercase font-black tracking-widest">Billing</span>
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Edit Modal */}
      {editingOwner && (
        <EditGymOwnerModal
          owner={editingOwner}
          onClose={() => setEditingOwner(null)}
          onSubmit={(updates) => updateMutation.mutate({ id: editingOwner.id, updates })}
          isLoading={updateMutation.isPending}
          error={updateMutation.error?.message}
        />
      )}

      {/* Subscription & Pricing Modal */}
      {pricingOwner && (
        <SubscriptionAndPricingModal
          owner={pricingOwner}
          onClose={() => setPricingOwner(null)}
          onUpdatePricing={async (updates: { isLifetimeFree?: boolean; customPricePerBranch?: number | null; customPlatformFeePercent?: number | null }) => {
            await platformApi.updateSaaSPricing(pricingOwner.id, updates, token!);
            queryClient.invalidateQueries({ queryKey: ["gym-owners"] });
          }}
          onExtendSubscription={(data) => extendSubscriptionMutation.mutate({ id: pricingOwner.id, ...data })}
          isLoading={extendSubscriptionMutation.isPending}
        />
      )}

      {/* Extend Trial Modal */}
      {extendTrialOwner && (
        <ExtendTrialModal
          owner={extendTrialOwner}
          onClose={() => setExtendTrialOwner(null)}
          onSubmit={(days: number) => extendTrialMutation.mutate({ id: extendTrialOwner.id, days })}
          isLoading={extendTrialMutation.isPending}
        />
      )}


      {/* Create Modal */}
      {showModal && (
        <CreateGymOwnerModal
          onClose={() => setShowModal(false)}
          onSubmit={(data) => createMutation.mutate(data)}
          isLoading={createMutation.isPending}
          error={createMutation.error?.message}
        />
      )}
    </div>
  );
}

function CreateGymOwnerModal({
  onClose,
  onSubmit,
  isLoading,
  error,
}: {
  onClose: () => void;
  onSubmit: (data: CreateUserData) => void;
  isLoading: boolean;
  error?: string;
}) {
  const [formData, setFormData] = useState<CreateUserData>({
    email: "",
    password: "",
    fullName: "",
    phoneNumber: "",
    address: "",
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-xl font-black text-white uppercase tracking-tight italic flex items-center gap-2">
              <UserCog className="text-[#F1C40F]" size={24} />
              Add Gym Owner
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Register New Management Entity</p>
          </div>
          <button onClick={onClose} className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {error && (
              <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-4 text-red-400 text-xs font-bold uppercase tracking-widest flex items-center gap-3">
                <X size={18} />
                {error}
              </div>
            )}

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Full Name
              </label>
              <input
                type="text"
                value={formData.fullName}
                onChange={(e) =>
                  setFormData({ ...formData, fullName: e.target.value })
                }
                required
                className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all"
                placeholder="John Doe"
              />
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Email Address
              </label>
              <input
                type="email"
                value={formData.email}
                onChange={(e) =>
                  setFormData({ ...formData, email: e.target.value })
                }
                required
                className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all"
                placeholder="owner@gym.com"
              />
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Access Password
              </label>
              <input
                type="password"
                value={formData.password}
                onChange={(e) =>
                  setFormData({ ...formData, password: e.target.value })
                }
                required
                minLength={6}
                className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all"
                placeholder="••••••••"
              />
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Contact Number (Optional)
              </label>
              <input
                type="tel"
                value={formData.phoneNumber}
                onChange={(e) =>
                  setFormData({ ...formData, phoneNumber: e.target.value })
                }
                className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all"
                placeholder="+1 234 567 8900"
              />
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Physical Address (Optional)
              </label>
              <textarea
                value={formData.address}
                onChange={(e) =>
                  setFormData({ ...formData, address: e.target.value })
                }
                className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all min-h-[100px] resize-none"
                placeholder="Street name, City, Country"
              />
            </div>
          </form>
        </div>

        {/* FIXED FOOTER */}
        <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3 shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={isLoading}
            className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all disabled:opacity-50 flex items-center justify-center gap-2 shadow-xl shadow-[#F1C40F]/20"
          >
            {isLoading && <RefreshCw className="animate-spin" size={16} />}
            {isLoading ? "Synchronizing..." : "Initialize Owner"}
          </button>
        </div>
      </div>
    </div>
  );
}

function EditGymOwnerModal({
  owner,
  onClose,
  onSubmit,
  isLoading,
  error,
}: {
  owner: GymOwner;
  onClose: () => void;
  onSubmit: (data: Partial<CreateUserData> & { isActive?: boolean }) => void;
  isLoading: boolean;
  error?: string;
}) {
  const [formData, setFormData] = useState({
    fullName: owner.fullName,
    phoneNumber: owner.phoneNumber || "",
    address: owner.address || "",
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-xl font-black text-white uppercase tracking-tight italic flex items-center gap-2">
              <UserCog className="text-[#F1C40F]" size={24} />
              Edit Gym Owner
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Modify Management Entity Credentials</p>
          </div>
          <button onClick={onClose} className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {error && (
              <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-4 text-red-400 text-xs font-bold uppercase tracking-widest flex items-center gap-3">
                <X size={18} />
                {error}
              </div>
            )}

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Full Name
              </label>
              <input
                type="text"
                value={formData.fullName}
                onChange={(e) =>
                  setFormData({ ...formData, fullName: e.target.value })
                }
                required
                className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all"
              />
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Security Credentials (Read Only)
              </label>
              <input
                type="email"
                value={owner.email}
                disabled
                className="w-full px-6 py-4 bg-white/[0.02] border border-white/5 rounded-2xl text-zinc-600 cursor-not-allowed italic"
              />
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Contact Protocol
              </label>
              <input
                type="tel"
                value={formData.phoneNumber}
                onChange={(e) =>
                  setFormData({ ...formData, phoneNumber: e.target.value })
                }
                className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all"
                placeholder="+1 234 567 8900"
              />
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Location Details
              </label>
              <textarea
                value={formData.address}
                onChange={(e) =>
                  setFormData({ ...formData, address: e.target.value })
                }
                className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all min-h-[100px] resize-none"
                placeholder="Street name, City, Country"
              />
            </div>
          </form>
        </div>

        {/* FIXED FOOTER */}
        <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3 shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={isLoading || !formData.fullName}
            className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all disabled:opacity-50 flex items-center justify-center gap-2 shadow-xl shadow-[#F1C40F]/20"
          >
            {isLoading && <RefreshCw className="animate-spin" size={16} />}
            {isLoading ? "Updating..." : "Persist Changes"}
          </button>
        </div>
      </div>
    </div>
  );
}

interface SubscriptionAndPricingModalProps {
  owner: GymOwner;
  onClose: () => void;
  onUpdatePricing: (data: { isLifetimeFree?: boolean; customPricePerBranch?: number | null; customPlatformFeePercent?: number | null }) => Promise<void>;
  onExtendSubscription: (data: { days: number; amount: number; paymentMethod: string; notes?: string }) => void;
  isLoading: boolean;
}

function SubscriptionAndPricingModal({
  owner,
  onClose,
  onUpdatePricing,
  onExtendSubscription,
  isLoading,
}: SubscriptionAndPricingModalProps) {
  const toast = useToast();
  const [activeTab, setActiveTab] = useState<"pricing" | "billing">("pricing");
  const [pricingData, setPricingData] = useState({
    isLifetimeFree: owner.isLifetimeFree || false,
    customPricePerBranch: owner.customPricePerBranch?.toString() || "",
    customPlatformFeePercent: owner.customPlatformFeePercent?.toString() || "",
  });

  const [billingData, setBillingData] = useState({
    amount: "",
    paymentMethod: "BANK_TRANSFER",
    extensionValue: "1",
    extensionUnit: "MONTHS" as "DAYS" | "MONTHS",
    notes: "",
  });

  const handleUpdatePricing = async () => {
    try {
      await onUpdatePricing({
        isLifetimeFree: pricingData.isLifetimeFree,
        customPricePerBranch: pricingData.customPricePerBranch === "" ? null : Number(pricingData.customPricePerBranch),
        customPlatformFeePercent: pricingData.customPlatformFeePercent === "" ? null : Number(pricingData.customPlatformFeePercent),
      });
      toast.success("Pricing overrides updated");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to update pricing");
    }
  };

  const handleExtend = () => {
    const days = billingData.extensionUnit === "MONTHS" 
      ? Number(billingData.extensionValue) * 30 
      : Number(billingData.extensionValue);
    
    onExtendSubscription({
      days,
      amount: Number(billingData.amount),
      paymentMethod: billingData.paymentMethod,
      notes: billingData.notes,
    });
  };

  const now = new Date().getTime();
  const daysLeft = owner.saasTrialEndsAt 
    ? Math.ceil((new Date(owner.saasTrialEndsAt).getTime() - now) / (1000 * 60 * 60 * 24))
    : 0;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        {/* HEADER */}
        <div className="p-8 border-b border-white/5 bg-white/[0.02] shrink-0">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-[#F1C40F]/10 rounded-2xl flex items-center justify-center text-[#F1C40F]">
                <DollarSign size={24} />
              </div>
              <div>
                <h2 className="text-xl font-black text-white uppercase italic tracking-tight">Subscription</h2>
                <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">{owner.fullName}</p>
              </div>
            </div>
            <button onClick={onClose} className="p-2 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-all">
              <X size={20} />
            </button>
          </div>

          <div className="flex gap-2">
            <button
              onClick={() => setActiveTab("pricing")}
              className={`flex-1 py-3 px-4 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
                activeTab === "pricing" ? "bg-[#F1C40F] text-black" : "bg-white/5 text-zinc-400 hover:bg-white/10"
              }`}
            >
              Pricing Overrides
            </button>
            <button
              onClick={() => setActiveTab("billing")}
              className={`flex-1 py-3 px-4 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
                activeTab === "billing" ? "bg-[#F1C40F] text-black" : "bg-white/5 text-zinc-400 hover:bg-white/10"
              }`}
            >
              Manual Billing
            </button>
          </div>
        </div>

        {/* CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          {activeTab === "pricing" ? (
            <div className="space-y-6">
              <div className="p-6 bg-white/[0.02] border border-white/5 rounded-2xl">
                <div className="flex items-center justify-between mb-4">
                  <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Account Status</span>
                  <span className={`px-2 py-0.5 rounded-full text-[10px] font-black uppercase ${
                    daysLeft > 0 ? "bg-blue-500/10 text-blue-400" : "bg-green-500/10 text-green-400"
                  }`}>
                    {daysLeft > 0 ? `Trial: ${daysLeft} days left` : owner.saasSubscriptionStatus || "Active"}
                  </span>
                </div>
                <label className="flex items-center gap-4 p-4 bg-[#F1C40F]/5 border border-[#F1C40F]/10 rounded-xl cursor-pointer hover:bg-[#F1C40F]/10 transition-all">
                  <input
                    type="checkbox"
                    checked={pricingData.isLifetimeFree}
                    onChange={(e) => setPricingData({ ...pricingData, isLifetimeFree: e.target.checked })}
                    className="w-5 h-5 rounded border-white/10 bg-black/50 text-[#F1C40F] focus:ring-[#F1C40F]"
                  />
                  <div>
                    <p className="text-xs font-black text-white uppercase tracking-widest">Lifetime Free Access</p>
                    <p className="text-[10px] text-zinc-500 mt-0.5 uppercase tracking-tighter italic">Bypasses all subscription fees</p>
                  </div>
                </label>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-zinc-500 uppercase tracking-widest ml-1 italic">Price / Branch ($)</label>
                  <input
                    type="number"
                    value={pricingData.customPricePerBranch}
                    onChange={(e) => setPricingData({ ...pricingData, customPricePerBranch: e.target.value })}
                    disabled={pricingData.isLifetimeFree}
                    className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white focus:border-[#F1C40F] disabled:opacity-30 outline-none"
                    placeholder="Global default"
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-zinc-500 uppercase tracking-widest ml-1 italic">Platform Fee (%)</label>
                  <input
                    type="number"
                    value={pricingData.customPlatformFeePercent}
                    onChange={(e) => setPricingData({ ...pricingData, customPlatformFeePercent: e.target.value })}
                    className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white focus:border-[#F1C40F] outline-none"
                    placeholder="Global default"
                  />
                </div>
              </div>
              <button
                onClick={handleUpdatePricing}
                className="w-full py-4 bg-white/5 hover:bg-white/10 text-white rounded-2xl text-[10px] font-black uppercase tracking-widest border border-white/5 transition-all"
              >
                Persist Custom Pricing
              </button>
            </div>
          ) : (
            <div className="space-y-6">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-zinc-500 uppercase tracking-widest ml-1 italic">Extension Period</label>
                  <div className="flex items-center bg-white/[0.03] border border-white/5 rounded-2xl focus-within:border-[#F1C40F] transition-all overflow-hidden">
                    <input
                      type="number"
                      min="1"
                      value={billingData.extensionValue}
                      onChange={(e) => setBillingData({ ...billingData, extensionValue: e.target.value })}
                      className="w-20 px-4 py-4 bg-transparent text-white border-r border-white/5 outline-none text-center font-bold"
                    />
                    <select
                      value={billingData.extensionUnit}
                      onChange={(e) => setBillingData({ ...billingData, extensionUnit: e.target.value as "DAYS" | "MONTHS" })}
                      className="flex-1 px-4 py-4 bg-transparent text-white text-[10px] font-black uppercase outline-none cursor-pointer appearance-none"
                    >
                      <option value="MONTHS" className="bg-[#121721] text-white">Month{Number(billingData.extensionValue) !== 1 ? 's' : ''}</option>
                      <option value="DAYS" className="bg-[#121721] text-white">Day{Number(billingData.extensionValue) !== 1 ? 's' : ''}</option>
                    </select>
                    <div className="pr-4 pointer-events-none text-zinc-500 font-bold text-xs">
                      &#9662;
                    </div>
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-zinc-500 uppercase tracking-widest ml-1 italic text-right block">Collection Amount ($)</label>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    placeholder="0.00"
                    value={billingData.amount}
                    onChange={(e) => setBillingData({ ...billingData, amount: e.target.value })}
                    className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white focus:border-[#F1C40F] outline-none text-right font-bold text-[#F1C40F]"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-black text-zinc-500 uppercase tracking-widest ml-1 italic">Payment Protocol</label>
                <select
                  value={billingData.paymentMethod}
                  onChange={(e) => setBillingData({ ...billingData, paymentMethod: e.target.value })}
                  className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white outline-none focus:border-[#F1C40F] cursor-pointer"
                >
                  <option value="BANK_TRANSFER" className="bg-[#121721] text-white">Bank Transfer (Manual)</option>
                  <option value="CASH" className="bg-[#121721] text-white">Cash (Office)</option>
                  <option value="STRIPE" className="bg-[#121721] text-white">Stripe Link (Manual)</option>
                  <option value="OTHER" className="bg-[#121721] text-white">Other Protocol</option>
                </select>
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-black text-zinc-500 uppercase tracking-widest ml-1 italic">System Notes</label>
                <textarea
                  value={billingData.notes}
                  onChange={(e) => setBillingData({ ...billingData, notes: e.target.value })}
                  placeholder="Reference number, bank details, etc."
                  className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white outline-none focus:border-[#F1C40F] min-h-[100px] resize-none"
                />
              </div>
            </div>
          )}
        </div>

        {/* FOOTER */}
        <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3 shrink-0">
          <button onClick={onClose} className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-colors">
            Close Panel
          </button>
          {activeTab === "billing" && (
            <button
              onClick={handleExtend}
              disabled={isLoading}
              className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all disabled:opacity-50 flex items-center justify-center gap-2 shadow-xl shadow-[#F1C40F]/20"
            >
              {isLoading ? <RefreshCw className="animate-spin" size={16} /> : <Plus size={16} />}
              Record & Extend
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function ExtendTrialModal({
  owner,
  onClose,
  onSubmit,
  isLoading,
}: {
  owner: GymOwner;
  onClose: () => void;
  onSubmit: (days: number) => void;
  isLoading: boolean;
}) {
  const [days, setDays] = useState("30");
  const parsed = parseInt(days, 10);
  const valid = !isNaN(parsed) && parsed > 0;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-sm shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02]">
          <div>
            <h2 className="text-xl font-black text-white uppercase tracking-tight italic flex items-center gap-2">
              <RefreshCw className="text-blue-400" size={22} />
              Extend Trial
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">
              {owner.fullName || owner.email}
            </p>
          </div>
          <button onClick={onClose} className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        <div className="p-8 space-y-4">
          <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
            Number of Days
          </label>
          <input
            type="number"
            min="1"
            value={days}
            onChange={(e) => setDays(e.target.value)}
            autoFocus
            className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white focus:outline-none focus:border-[#F1C40F] transition-all text-center text-2xl font-bold"
          />
        </div>

        <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={() => valid && onSubmit(parsed)}
            disabled={isLoading || !valid}
            className="px-8 py-4 bg-blue-500 text-white rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-blue-400 transition-all disabled:opacity-50 flex items-center gap-2"
          >
            {isLoading && <RefreshCw className="animate-spin" size={16} />}
            {isLoading ? "Extending..." : `Extend ${valid ? parsed : "–"} Days`}
          </button>
        </div>
      </div>
    </div>
  );
}
