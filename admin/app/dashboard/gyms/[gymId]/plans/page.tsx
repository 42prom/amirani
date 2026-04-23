"use client";

import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { gymOwnerApi, EnhancedSubscriptionPlan, CreateEnhancedPlanData, gymsApi } from "@/lib/api";
import { useState } from "react";
import { useParams } from "next/navigation";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";
import { ThemedTimePicker } from "@/components/ui/ThemedTimePicker";
import {
  CreditCard,
  Plus,
  Edit2,
  Trash2,
  Clock,
  Calendar,
  Users,
  Check,
  X,
  RefreshCw,
  Zap,
  Upload,
  Sun,
  Moon,
  Sunrise,
} from "lucide-react";


const PLAN_TEMPLATES = [
  { id: "full", label: "Full Access", description: "Unlimited 24/7 access" },
  { id: "morning", label: "Morning", description: "6:00 - 12:00" },
  { id: "evening", label: "Evening", description: "17:00 - 22:00" },
  { id: "weekday", label: "Weekday", description: "Mon-Fri only" },
  { id: "weekend", label: "Weekend", description: "Sat-Sun only" },
  { id: "student", label: "Student", description: "Off-peak hours discount" },
];

export default function SubscriptionPlansPage() {
  const params = useParams();
  const gymId = params.gymId as string;
  const { token, user } = useAuthStore();
  const userRole = user?.role || "GYM_MEMBER";
  const queryClient = useQueryClient();

  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showTemplateModal, setShowTemplateModal] = useState(false);
  const [showQuickTimeModal, setShowQuickTimeModal] = useState(false);
  const [showImportModal, setShowImportModal] = useState(false);
  const [editingPlan, setEditingPlan] = useState<EnhancedSubscriptionPlan | null>(null);
  const [formData, setFormData] = useState<CreateEnhancedPlanData>({
    name: "",
    description: "",
    price: 0,
    durationValue: 30,
    durationUnit: "days",
    features: [],
    hasTimeRestriction: false,
    accessStartTime: "06:00",
    accessEndTime: "22:00",
    accessDays: ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"],
    planType: "full",
    displayOrder: 0,
  });
  const [selectedTemplates, setSelectedTemplates] = useState<string[]>([]);
  const [basePrice, setBasePrice] = useState(50);
  const [newFeature, setNewFeature] = useState("");

  const { data: plans, isLoading } = useQuery({
    queryKey: ["gym-plans", gymId],
    queryFn: () => gymOwnerApi.getPlans(gymId, token!),
    enabled: !!token && !!gymId,
  });

  const { data: gyms, isLoading: gymsLoading } = useQuery({
    queryKey: ["gyms"],
    queryFn: () => gymsApi.getAll(token!),
    enabled: !!token && (userRole === "GYM_OWNER" || userRole === "SUPER_ADMIN"),
  });

  const createMutation = useMutation({
    mutationFn: (data: CreateEnhancedPlanData) => gymOwnerApi.createPlan(gymId, data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-plans", gymId] });
      setShowCreateModal(false);
      resetForm();
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ planId, data }: { planId: string; data: Partial<CreateEnhancedPlanData> & { isActive?: boolean } }) =>
      gymOwnerApi.updatePlan(planId, data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-plans", gymId] });
      setEditingPlan(null);
      resetForm();
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (planId: string) => gymOwnerApi.deletePlan(planId, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-plans", gymId] });
    },
  });

  const templateMutation = useMutation({
    mutationFn: () => gymOwnerApi.createPlanTemplates(gymId, selectedTemplates, basePrice, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-plans", gymId] });
      setShowTemplateModal(false);
      setSelectedTemplates([]);
    },
  });

  const resetForm = () => {
    setFormData({
      name: "",
      description: "",
      price: 0,
      durationValue: 30,
      durationUnit: "days",
      features: [],
      hasTimeRestriction: false,
      accessStartTime: "06:00",
      accessEndTime: "22:00",
      accessDays: ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"],
      planType: "full",
      displayOrder: 0,
    });
    setNewFeature("");
  };

  const handleEdit = (plan: EnhancedSubscriptionPlan) => {
    setEditingPlan(plan);
    setFormData({
      name: plan.name,
      description: plan.description || "",
      price: parseFloat(plan.price),
      durationValue: plan.durationValue,
      durationUnit: plan.durationUnit,
      features: plan.features,
      hasTimeRestriction: plan.hasTimeRestriction,
      accessStartTime: plan.accessStartTime || "06:00",
      accessEndTime: plan.accessEndTime || "22:00",
      accessDays: plan.accessDays,
      planType: plan.planType,
      displayOrder: plan.displayOrder,
    });
    setShowCreateModal(true);
  };

  const handleSubmit = () => {
    if (editingPlan) {
      updateMutation.mutate({ planId: editingPlan.id, data: formData });
    } else {
      createMutation.mutate(formData);
    }
  };

  const addFeature = () => {
    if (newFeature.trim()) {
      setFormData({ ...formData, features: [...(formData.features || []), newFeature.trim()] });
      setNewFeature("");
    }
  };

  const removeFeature = (index: number) => {
    setFormData({
      ...formData,
      features: (formData.features || []).filter((_, i) => i !== index),
    });
  };


  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="Subscription Plans"
        description="Manage pricing and access restrictions for your gym"
        icon={<CreditCard size={32} />}
        actions={
          <GymSwitcher 
            gyms={gyms} 
            isLoading={gymsLoading} 
            disabled={userRole !== "GYM_OWNER" && userRole !== "SUPER_ADMIN"} 
          />
        }
      />

      {/* Action Buttons */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <button
          onClick={() => {
            resetForm();
            setEditingPlan(null);
            setShowCreateModal(true);
          }}
          className="p-4 bg-[#F1C40F] !text-black rounded-xl hover:bg-[#F1C40F]/90 transition-all flex flex-col items-center gap-2 hover:-translate-y-1"
        >
          <Plus size={24} />
          <span className="font-bold text-sm">Create Plan</span>
          <span className="text-xs opacity-75">Custom subscription</span>
        </button>
        <button
          onClick={() => setShowTemplateModal(true)}
          className="p-4 bg-zinc-800 text-white rounded-xl hover:bg-zinc-700 transition-all flex flex-col items-center gap-2 border border-zinc-700 hover:-translate-y-1"
        >
          <Zap size={24} className="text-[#F1C40F]" />
          <span className="font-bold text-sm">Quick Templates</span>
          <span className="text-xs text-zinc-400">Pre-built plans</span>
        </button>
        <button
          onClick={() => setShowQuickTimeModal(true)}
          className="p-4 bg-zinc-800 text-white rounded-xl hover:bg-zinc-700 transition-all flex flex-col items-center gap-2 border border-zinc-700 hover:-translate-y-1"
        >
          <Clock size={24} className="text-blue-400" />
          <span className="font-bold text-sm">Time-Based Plans</span>
          <span className="text-xs text-zinc-400">Morning/Evening/Night</span>
        </button>
        <button
          onClick={() => setShowImportModal(true)}
          className="p-4 bg-zinc-800 text-white rounded-xl hover:bg-zinc-700 transition-all flex flex-col items-center gap-2 border border-zinc-700 hover:-translate-y-1"
        >
          <Upload size={24} className="text-green-400" />
          <span className="font-bold text-sm">Import Plans</span>
          <span className="text-xs text-zinc-400">From file or template</span>
        </button>
      </div>

      {/* Plans Grid */}
      {plans && plans.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {plans.map((plan) => (
            <div
              key={plan.id}
              className={`bg-[#121721] border rounded-xl overflow-hidden ${
                plan.isActive ? "border-zinc-800" : "border-red-500/30 opacity-60"
              }`}
            >
              <div className="p-6 border-b border-zinc-800">
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <h3 className="text-lg font-semibold text-white">{plan.name}</h3>
                    <span className={`text-xs px-2 py-0.5 rounded ${
                      plan.planType === "full"
                        ? "bg-green-500/10 text-green-400"
                        : "bg-blue-500/10 text-blue-400"
                    }`}>
                      {plan.planType.toUpperCase()}
                    </span>
                  </div>
                  <div className="flex gap-1">
                    <button
                      onClick={() => handleEdit(plan)}
                      className="p-2 hover:bg-zinc-800 rounded-lg transition-colors"
                    >
                      <Edit2 size={16} className="text-zinc-400" />
                    </button>
                    <button
                      onClick={() => {
                        if (confirm("Are you sure you want to delete this plan?")) {
                          deleteMutation.mutate(plan.id);
                        }
                      }}
                      className="p-2 hover:bg-red-500/10 rounded-lg transition-colors"
                    >
                      <Trash2 size={16} className="text-red-400" />
                    </button>
                  </div>
                </div>
                <div className="mt-4">
                  <span className="text-3xl font-bold text-white">
                    ${parseFloat(plan.price).toFixed(0)}
                  </span>
                  <span className="text-zinc-400">
                    / {plan.durationValue} {plan.durationUnit}
                  </span>
                </div>
              </div>

              <div className="p-4 bg-zinc-800/30">
                {plan.hasTimeRestriction ? (
                  <div className="space-y-2">
                    <div className="flex items-center gap-2 text-sm text-zinc-400">
                      <Clock size={14} />
                      <span>{plan.accessStartTime} - {plan.accessEndTime}</span>
                    </div>
                    <div className="flex items-center gap-2 text-sm text-zinc-400">
                      <Calendar size={14} />
                      <span>{plan.accessDays.length === 7 ? "All days" : plan.accessDays.map(d => d.slice(0, 3)).join(", ")}</span>
                    </div>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 text-sm text-green-400">
                    <Check size={14} />
                    <span>24/7 Full Access</span>
                  </div>
                )}
              </div>

              <div className="p-4">
                <div className="space-y-2">
                  {plan.features.slice(0, 3).map((feature, i) => (
                    <div key={i} className="flex items-center gap-2 text-sm text-zinc-300">
                      <Check size={14} className="text-[#F1C40F]" />
                      {feature}
                    </div>
                  ))}
                  {plan.features.length > 3 && (
                    <p className="text-xs text-zinc-500">+{plan.features.length - 3} more features</p>
                  )}
                </div>
              </div>

              <div className="p-4 border-t border-zinc-800 flex items-center justify-between">
                <div className="flex items-center gap-2 text-sm text-zinc-400">
                  <Users size={14} />
                  <span>{plan._count?.memberships || 0} members</span>
                </div>
                <button
                  onClick={() => updateMutation.mutate({ planId: plan.id, data: { isActive: !plan.isActive } })}
                  className={`px-3 py-1 rounded text-xs font-medium transition-colors ${
                    plan.isActive
                      ? "bg-green-500/10 text-green-400"
                      : "bg-red-500/10 text-red-400"
                  }`}
                >
                  {plan.isActive ? "Active" : "Inactive"}
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-24 bg-[#121721] border border-white/5 rounded-[2.5rem] border-dashed">
          <div className="p-6 bg-zinc-900/50 rounded-3xl border border-white/5 mb-6">
            <CreditCard className="text-zinc-700" size={48} />
          </div>
          <h3 className="text-xl font-black text-white uppercase tracking-tight italic">No subscription plans yet</h3>
          <p className="text-zinc-500 mt-2 max-w-xs font-black text-[10px] uppercase tracking-widest text-center">Deploy your first membership protocol or utilize pre-built templates to begin facility enrollment.</p>
          <div className="flex flex-col sm:flex-row justify-center gap-4 mt-8">
            <button
              onClick={() => setShowTemplateModal(true)}
              className="flex items-center justify-center gap-3 px-8 py-4 bg-white/5 text-white border border-white/10 rounded-xl font-black text-[10px] uppercase tracking-widest hover:bg-white/10 hover:border-[#F1C40F]/50 transition-all"
            >
              <Zap size={16} className="text-[#F1C40F]" />
              Use Templates
            </button>
            <button
              onClick={() => setShowCreateModal(true)}
              className="flex items-center justify-center gap-3 px-8 py-4 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
            >
              <Plus size={16} />
              Create Custom Plan
            </button>
          </div>
        </div>
      )}

      {/* Create/Edit Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
          <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-2xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
            <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
              <div>
                <h2 className="text-2xl font-black text-white uppercase tracking-tighter flex items-center gap-3 italic">
                  <CreditCard className="text-[#F1C40F]" size={24} />
                  {editingPlan ? "Edit Plan" : "Create Subscription Plan"}
                </h2>
                <p className="text-zinc-500 text-[10px] font-black uppercase tracking-[0.2em] mt-1">Configure Membership Access Protocol</p>
              </div>
              <button
                onClick={() => {
                  setShowCreateModal(false);
                  setEditingPlan(null);
                  resetForm();
                }}
                className="p-3 hover:bg-red-500/10 rounded-2xl text-zinc-500 hover:text-red-400 transition-all border border-white/5"
              >
                <X size={20} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
              <div className="space-y-8">
                <div className="grid grid-cols-2 gap-4">
                  <div className="col-span-2">
                    <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Plan Name</label>
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      placeholder="e.g., Premium Monthly"
                      className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
                    />
                  </div>
                  <div className="col-span-1">
                    <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Price ($)</label>
                    <input
                      type="number"
                      min="0"
                      step="0.01"
                      value={formData.price}
                      onChange={(e) => setFormData({ ...formData, price: Math.max(0, parseFloat(e.target.value) || 0) })}
                      className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
                    />
                  </div>
                  <div className="col-span-1">
                    <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Duration Value</label>
                    <input
                      type="number"
                      value={formData.durationValue}
                      onChange={(e) => setFormData({ ...formData, durationValue: parseInt(e.target.value) })}
                      className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
                    />
                  </div>
                  <div className="col-span-2">
                    <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Description</label>
                    <textarea
                      value={formData.description}
                      onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                      rows={2}
                      className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all resize-none"
                    />
                  </div>
                </div>

                <div className="p-4 bg-zinc-800/50 rounded-lg">
                  <label className="flex items-center gap-3 cursor-pointer mb-4">
                    <input
                      type="checkbox"
                      checked={formData.hasTimeRestriction}
                      onChange={(e) => setFormData({ ...formData, hasTimeRestriction: e.target.checked })}
                      className="w-5 h-5 rounded border-zinc-700 bg-zinc-800 text-[#F1C40F]"
                    />
                    <span className="text-white font-medium">Enable Time Restrictions</span>
                  </label>
                  {formData.hasTimeRestriction && (
                    <div className="space-y-6 pt-4">
                      <div className="grid grid-cols-2 gap-4">
                        <ThemedTimePicker
                          label="Start Time"
                          value={formData.accessStartTime}
                          onChange={(val) => setFormData({ ...formData, accessStartTime: val })}
                        />
                        <ThemedTimePicker
                          label="End Time"
                          value={formData.accessEndTime}
                          onChange={(val) => setFormData({ ...formData, accessEndTime: val })}
                        />
                      </div>
                    </div>
                  )}
                </div>

                <div>
                  <label className="block text-sm text-zinc-400 mb-2">Features</label>
                  <div className="flex gap-2 mb-2">
                    <input
                      type="text"
                      value={newFeature}
                      onChange={(e) => setNewFeature(e.target.value)}
                      placeholder="Add a feature..."
                      className="flex-1 bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white"
                    />
                    <button onClick={addFeature} disabled={!newFeature.trim()} className="px-4 py-2 bg-zinc-700 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed">Add</button>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {formData.features?.map((feature, i) => (
                      <span key={i} className="px-3 py-1 bg-zinc-800 rounded-full text-sm text-zinc-300 flex items-center gap-2">
                        {feature}
                        <button onClick={() => removeFeature(i)} className="text-zinc-500 hover:text-red-400"><Trash2 size={12} /></button>
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            </div>

            <div className="p-8 bg-white/[0.02] border-t border-white/5 flex justify-end gap-3 shrink-0">
              <button
                onClick={() => { setShowCreateModal(false); setEditingPlan(null); resetForm(); }}
                className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10"
              >
                Cancel
              </button>
              <button
                onClick={handleSubmit}
                disabled={createMutation.isPending || updateMutation.isPending}
                className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] disabled:opacity-50 flex items-center gap-2"
              >
                {(createMutation.isPending || updateMutation.isPending) && <RefreshCw className="animate-spin" size={16} />}
                {editingPlan ? "Update Plan" : "Create Plan"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Template Modal */}
      {showTemplateModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
          <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
            <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
              <div>
                <h2 className="text-xl font-black text-white uppercase tracking-tight italic">Quick Templates</h2>
                <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Select pre-built plan protocols</p>
              </div>
              <button
                onClick={() => { setShowTemplateModal(false); setSelectedTemplates([]); }}
                className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white border border-white/5"
              >
                <X size={20} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
              <div className="space-y-6">
                <div>
                  <label className="block text-sm text-zinc-400 mb-2">Base Monthly Price ($)</label>
                  <input
                    type="number"
                    value={basePrice}
                    onChange={(e) => setBasePrice(parseFloat(e.target.value))}
                    className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white"
                  />
                </div>
                <div className="space-y-2">
                  {PLAN_TEMPLATES.map((template) => (
                    <label
                      key={template.id}
                      className={`flex items-center gap-3 p-3 rounded-lg cursor-pointer transition-colors ${
                        selectedTemplates.includes(template.id) ? "bg-[#F1C40F]/10 border border-[#F1C40F]" : "bg-zinc-800 border border-transparent"
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={selectedTemplates.includes(template.id)}
                        onChange={(e) => {
                          if (e.target.checked) setSelectedTemplates([...selectedTemplates, template.id]);
                          else setSelectedTemplates(selectedTemplates.filter((t) => t !== template.id));
                        }}
                        className="w-5 h-5 rounded border-zinc-700 bg-zinc-800 text-[#F1C40F]"
                      />
                      <div>
                        <p className="text-white font-medium">{template.label}</p>
                        <p className="text-sm text-zinc-400">{template.description}</p>
                      </div>
                    </label>
                  ))}
                </div>
              </div>
            </div>

            <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3 shrink-0">
              <button onClick={() => { setShowTemplateModal(false); setSelectedTemplates([]); }} className="px-6 py-4 bg-white/[0.03] text-zinc-500 rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10">Cancel</button>
              <button onClick={() => templateMutation.mutate()} disabled={templateMutation.isPending || selectedTemplates.length === 0} className="px-6 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] disabled:opacity-50 flex items-center gap-2">
                {templateMutation.isPending && <RefreshCw className="animate-spin" size={16} />}
                Create {selectedTemplates.length} Plans
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Quick Time-Based Plans Modal */}
      {showQuickTimeModal && (
        <QuickTimeModal
          gymId={gymId}
          token={token!}
          onClose={() => setShowQuickTimeModal(false)}
          onSuccess={() => {
            setShowQuickTimeModal(false);
            queryClient.invalidateQueries({ queryKey: ["gym-plans", gymId] });
          }}
        />
      )}

      {/* Import Plans Modal */}
      {showImportModal && (
        <ImportPlansModal
          gymId={gymId}
          token={token!}
          onClose={() => setShowImportModal(false)}
          onSuccess={() => {
            setShowImportModal(false);
            queryClient.invalidateQueries({ queryKey: ["gym-plans", gymId] });
          }}
        />
      )}
    </div>
  );
}

// ─── Quick Time-Based Plans Modal ─────────────────────────────────────────────

const TIME_BASED_TEMPLATES: Array<{
  id: string;
  label: string;
  icon: typeof Sunrise;
  color: string;
  startTime: string;
  endTime: string;
  description: string;
  discount: number;
  planType: "morning" | "evening" | "custom";
}> = [
  {
    id: "morning",
    label: "Morning Plan",
    icon: Sunrise,
    color: "text-orange-400",
    startTime: "06:00",
    endTime: "12:00",
    description: "Early bird access (6AM - 12PM)",
    discount: 0.7,
    planType: "morning",
  },
  {
    id: "afternoon",
    label: "Afternoon Plan",
    icon: Sun,
    color: "text-yellow-400",
    startTime: "12:00",
    endTime: "17:00",
    description: "Midday access (12PM - 5PM)",
    discount: 0.65,
    planType: "custom",
  },
  {
    id: "evening",
    label: "Evening Plan",
    icon: Moon,
    color: "text-blue-400",
    startTime: "17:00",
    endTime: "23:00",
    description: "After work access (5PM - 11PM)",
    discount: 0.8,
    planType: "evening",
  },
];

function QuickTimeModal({
  gymId,
  token,
  onClose,
  onSuccess,
}: {
  gymId: string;
  token: string;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const [basePrice, setBasePrice] = useState(50);
  const [selectedPlans, setSelectedPlans] = useState<string[]>([]);
  const [isCreating, setIsCreating] = useState(false);
  const [createError, setCreateError] = useState<string | null>(null);

  const handleCreate = async () => {
    if (selectedPlans.length === 0) return;
    setIsCreating(true);
    try {
      for (const planId of selectedPlans) {
        const template = TIME_BASED_TEMPLATES.find((t) => t.id === planId);
        if (!template) continue;
        await gymOwnerApi.createPlan(gymId, {
          name: template.label,
          description: template.description,
          price: Math.round(basePrice * template.discount),
          durationValue: 30,
          durationUnit: "days",
          features: [`Access from ${template.startTime} to ${template.endTime}`, "Full equipment access", "Locker room access"],
          hasTimeRestriction: true,
          accessStartTime: template.startTime,
          accessEndTime: template.endTime,
          accessDays: ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"],
          planType: template.planType,
          displayOrder: 0,
        }, token);
      }
      onSuccess();
    } catch (error) {
      setCreateError(error instanceof Error ? error.message : "Failed to create plans");
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-xl font-black text-white uppercase tracking-tight italic flex items-center gap-2">
              <Clock className="text-blue-400" size={24} />
              Time-Based Plans
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Configure Duration-Specific Access</p>
          </div>
          <button onClick={onClose} className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-colors border border-white/5">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <div className="space-y-6">
            <div>
              <label className="block text-sm text-zinc-400 mb-2">Full Access Price ($)</label>
              <input type="number" value={basePrice} onChange={(e) => setBasePrice(parseFloat(e.target.value))} className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white" />
            </div>
            <div className="space-y-2">
              {TIME_BASED_TEMPLATES.map((template) => {
                const Icon = template.icon;
                const price = Math.round(basePrice * template.discount);
                return (
                  <label key={template.id} className={`flex items-center gap-3 p-4 rounded-lg cursor-pointer transition-colors ${selectedPlans.includes(template.id) ? "bg-[#F1C40F]/10 border border-[#F1C40F]" : "bg-zinc-800 border border-transparent hover:border-zinc-600"}`}>
                    <input type="checkbox" checked={selectedPlans.includes(template.id)} onChange={(e) => { if (e.target.checked) setSelectedPlans([...selectedPlans, template.id]); else setSelectedPlans(selectedPlans.filter((p) => p !== template.id)); }} className="w-5 h-5 rounded border-zinc-700 bg-zinc-800 text-[#F1C40F]" />
                    <Icon size={24} className={template.color} />
                    <div className="flex-1">
                      <p className="text-white font-medium">{template.label}</p>
                      <p className="text-sm text-zinc-400">{template.description}</p>
                    </div>
                    <span className="text-[#F1C40F] font-bold">${price}/mo</span>
                  </label>
                );
              })}
            </div>
          </div>
        </div>

        {createError && (
          <div className="px-8 py-3 bg-red-500/10 border-t border-red-500/20 text-red-400 text-xs font-bold shrink-0">
            {createError}
          </div>
        )}
        <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3 shrink-0">
          <button onClick={onClose} className="px-6 py-4 bg-white/[0.03] text-zinc-500 rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10">Cancel</button>
          <button onClick={handleCreate} disabled={isCreating || selectedPlans.length === 0} className="px-6 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] disabled:opacity-50 flex items-center gap-2">
            {isCreating && <RefreshCw className="animate-spin" size={16} />}
            Create {selectedPlans.length} Plans
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Import Plans Modal ───────────────────────────────────────────────────────

function ImportPlansModal({
  gymId,
  token,
  onClose,
  onSuccess,
}: {
  gymId: string;
  token: string;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const [importMode, setImportMode] = useState<"file" | "clone">("file");
  const [isImporting, setIsImporting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setIsImporting(true);
    setError(null);
    try {
      const text = await file.text();
      const plans = JSON.parse(text);
      if (!Array.isArray(plans)) throw new Error("Invalid format: expected array of plans");
      for (const plan of plans) {
        await gymOwnerApi.createPlan(gymId, {
          name: plan.name,
          description: plan.description || "",
          price: plan.priceMonthly || plan.price || 0,
          durationValue: plan.durationDays || plan.durationValue || 30,
          durationUnit: plan.durationUnit || "days",
          features: plan.features || [],
          hasTimeRestriction: plan.hasTimeRestriction || false,
          accessStartTime: plan.accessStartTime || "06:00",
          accessEndTime: plan.accessEndTime || "22:00",
          accessDays: plan.accessDays || ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"],
          planType: plan.planType || "full",
          displayOrder: plan.displayOrder || 0,
        }, token);
      }
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to import plans");
    } finally {
      setIsImporting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-xl font-black text-white uppercase tracking-tight italic flex items-center gap-2">
              <Upload className="text-green-400" size={24} />
              Import Plans
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Import Membership Protocols</p>
          </div>
          <button onClick={onClose} className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <div className="space-y-6">
            {error && <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-3 text-red-400 text-sm">{error}</div>}
            <div className="flex bg-zinc-800 rounded-lg p-1">
              <button onClick={() => setImportMode("file")} className={`flex-1 py-2 rounded-md text-sm font-medium ${importMode === "file" ? "bg-[#F1C40F] text-black" : "text-zinc-400"}`}>From File</button>
              <button onClick={() => setImportMode("clone")} className={`flex-1 py-2 rounded-md text-sm font-medium ${importMode === "clone" ? "bg-[#F1C40F] text-black" : "text-zinc-400"}`}>Clone Template</button>
            </div>
            {importMode === "file" ? (
              <div className="space-y-4">
                <div className="border-2 border-dashed border-zinc-700 rounded-xl p-8 text-center hover:border-[#F1C40F]/50 transition-colors cursor-pointer relative">
                  <input type="file" accept=".json" onChange={handleFileUpload} disabled={isImporting} className="absolute inset-0 opacity-0 cursor-pointer" />
                  {isImporting ? <RefreshCw className="mx-auto text-[#F1C40F] animate-spin mb-2" size={32} /> : <Upload className="mx-auto text-zinc-500 mb-2" size={32} />}
                  <p className="text-white font-medium">{isImporting ? "Importing..." : "Click to upload JSON file"}</p>
                </div>
              </div>
            ) : (
              <div className="space-y-4">
                <p className="text-xs text-zinc-500 text-center">Clone feature coming soon</p>
              </div>
            )}
          </div>
        </div>

        <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3 shrink-0">
          <button onClick={onClose} className="px-6 py-4 bg-white/[0.03] text-zinc-500 rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10">Cancel</button>
        </div>
      </div>
    </div>
  );
}
