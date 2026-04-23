"use client";

import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { platformApi, UserTier, TierLimits } from "@/lib/api";
import { useState } from "react";
import { Layers, Save, RefreshCw, Check, X, Zap, Image as ImageIcon, FileText } from "lucide-react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/ui/PageHeader";

const TIER_INFO: Record<UserTier, { label: string; color: string; description: string }> = {
  FREE: {
    label: "Free Tier",
    color: "text-zinc-400",
    description: "Basic access with limited AI features"
  },
  GYM_MEMBER: {
    label: "Gym Member",
    color: "text-[#F1C40F]",
    description: "Full access for active gym members"
  },
  HOME_PREMIUM: {
    label: "Home Premium",
    color: "text-purple-400",
    description: "Premium subscription for home users"
  },
};

export default function TierLimitsPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const [editingTier, setEditingTier] = useState<UserTier | null>(null);
  const [editValues, setEditValues] = useState<Partial<TierLimits>>({});

  const { data: tiers, isLoading, error } = useQuery({
    queryKey: ["tier-limits"],
    queryFn: () => platformApi.getAllTierLimits(token!),
    enabled: !!token && isSuperAdmin(user?.role),
  });

  const updateMutation = useMutation({
    mutationFn: ({ tier, data }: { tier: UserTier; data: Partial<TierLimits> }) =>
      platformApi.updateTierLimits(tier, data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tier-limits"] });
      setEditingTier(null);
      setEditValues({});
    },
  });

  const initMutation = useMutation({
    mutationFn: () => platformApi.initializeTierLimits(token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tier-limits"] });
    },
  });

  // Redirect if not super admin
  if (!isSuperAdmin(user?.role)) {
    router.push("/dashboard");
    return null;
  }

  const startEditing = (tier: TierLimits) => {
    setEditingTier(tier.tier);
    setEditValues(tier);
  };

  const cancelEditing = () => {
    setEditingTier(null);
    setEditValues({});
  };

  const saveEditing = () => {
    if (editingTier) {
      updateMutation.mutate({ tier: editingTier, data: editValues });
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-4 text-red-400">
        Failed to load tier limits
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="User Tier Limits"
        description="Configure AI token limits and feature access for each user tier"
        icon={<Layers size={24} />}
        actions={
          (!tiers || tiers.length === 0) && (
            <button
              onClick={() => initMutation.mutate()}
              disabled={initMutation.isPending}
              className="px-4 py-2 bg-[#F1C40F] !text-black rounded-lg hover:bg-[#F1C40F]/90 transition-colors disabled:opacity-50 flex items-center gap-2 text-sm font-bold"
            >
              {initMutation.isPending ? (
                <RefreshCw className="animate-spin" size={16} />
              ) : (
                <Zap size={16} />
              )}
              Initialize Default Limits
            </button>
          )
        }
      />

      {/* Tier Cards */}
      <div className="space-y-6">
        {(["FREE", "GYM_MEMBER", "HOME_PREMIUM"] as UserTier[]).map((tierKey) => {
          const tier = tiers?.find((t) => t.tier === tierKey);
          const info = TIER_INFO[tierKey];
          const isEditing = editingTier === tierKey;

          return (
            <div
              key={tierKey}
              className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden"
            >
              {/* Tier Header */}
              <div className="p-6 border-b border-zinc-800 flex items-center justify-between">
                <div>
                  <h2 className={`text-xl font-semibold ${info.color}`}>{info.label}</h2>
                  <p className="text-sm text-zinc-500 mt-1">{tier?.description || info.description}</p>
                </div>
                {!isEditing ? (
                  <button
                    onClick={() => tier && startEditing(tier)}
                    disabled={!tier}
                    className="px-4 py-2 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors disabled:opacity-50"
                  >
                    Edit Limits
                  </button>
                ) : (
                  <div className="flex gap-2">
                    <button
                      onClick={cancelEditing}
                      className="px-4 py-2 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors flex items-center gap-2"
                    >
                      <X size={16} />
                      Cancel
                    </button>
                    <button
                      onClick={saveEditing}
                      disabled={updateMutation.isPending}
                      className="px-4 py-2 bg-[#F1C40F] !text-black rounded-lg hover:bg-[#F1C40F]/90 transition-colors disabled:opacity-50 flex items-center gap-2 font-bold"
                    >
                      {updateMutation.isPending ? (
                        <RefreshCw className="animate-spin" size={16} />
                      ) : (
                        <Save size={16} />
                      )}
                      Save
                    </button>
                  </div>
                )}
              </div>

              {/* Tier Content */}
              <div className="p-6">
                {tier ? (
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                    {/* AI Tokens */}
                    <div className="space-y-3">
                      <div className="flex items-center gap-2 text-zinc-400">
                        <Zap size={16} />
                        <span className="text-sm">AI Tokens / Month</span>
                      </div>
                      {isEditing ? (
                        <input
                          type="number"
                          value={editValues.aiTokensPerMonth || 0}
                          onChange={(e) =>
                            setEditValues({ ...editValues, aiTokensPerMonth: parseInt(e.target.value) })
                          }
                          className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-[#F1C40F]"
                        />
                      ) : (
                        <p className="text-2xl font-bold text-white">
                          {tier.aiTokensPerMonth.toLocaleString()}
                        </p>
                      )}
                    </div>

                    {/* AI Requests */}
                    <div className="space-y-3">
                      <div className="flex items-center gap-2 text-zinc-400">
                        <Zap size={16} />
                        <span className="text-sm">AI Requests / Day</span>
                      </div>
                      {isEditing ? (
                        <input
                          type="number"
                          value={editValues.aiRequestsPerDay || 0}
                          onChange={(e) =>
                            setEditValues({ ...editValues, aiRequestsPerDay: parseInt(e.target.value) })
                          }
                          className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-[#F1C40F]"
                        />
                      ) : (
                        <p className="text-2xl font-bold text-white">{tier.aiRequestsPerDay}</p>
                      )}
                    </div>

                    {/* Workout Plans */}
                    <div className="space-y-3">
                      <div className="flex items-center gap-2 text-zinc-400">
                        <FileText size={16} />
                        <span className="text-sm">Workout Plans / Month</span>
                      </div>
                      {isEditing ? (
                        <input
                          type="number"
                          value={editValues.workoutPlansPerMonth || 0}
                          onChange={(e) =>
                            setEditValues({ ...editValues, workoutPlansPerMonth: parseInt(e.target.value) })
                          }
                          className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-[#F1C40F]"
                        />
                      ) : (
                        <p className="text-2xl font-bold text-white">{tier.workoutPlansPerMonth}</p>
                      )}
                    </div>

                    {/* Diet Plans */}
                    <div className="space-y-3">
                      <div className="flex items-center gap-2 text-zinc-400">
                        <FileText size={16} />
                        <span className="text-sm">Diet Plans / Month</span>
                      </div>
                      {isEditing ? (
                        <input
                          type="number"
                          value={editValues.dietPlansPerMonth || 0}
                          onChange={(e) =>
                            setEditValues({ ...editValues, dietPlansPerMonth: parseInt(e.target.value) })
                          }
                          className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-[#F1C40F]"
                        />
                      ) : (
                        <p className="text-2xl font-bold text-white">{tier.dietPlansPerMonth}</p>
                      )}
                    </div>

                    {/* Progress Photos */}
                    <div className="space-y-3">
                      <div className="flex items-center gap-2 text-zinc-400">
                        <ImageIcon size={16} />
                        <span className="text-sm">Max Progress Photos</span>
                      </div>
                      {isEditing ? (
                        <input
                          type="number"
                          value={editValues.maxProgressPhotos || 0}
                          onChange={(e) =>
                            setEditValues({ ...editValues, maxProgressPhotos: parseInt(e.target.value) })
                          }
                          className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-[#F1C40F]"
                        />
                      ) : (
                        <p className="text-2xl font-bold text-white">{tier.maxProgressPhotos}</p>
                      )}
                    </div>
                  </div>
                ) : (
                  <p className="text-zinc-500">Tier not configured. Click &quot;Initialize Default Limits&quot; to set up.</p>
                )}

                {/* Feature Toggles */}
                {tier && (
                  <div className="mt-6 pt-6 border-t border-zinc-800">
                    <h3 className="text-sm font-medium text-zinc-400 mb-4">Feature Access</h3>
                    <div className="flex flex-wrap gap-3">
                      {[
                        { key: "canAccessAICoach", label: "AI Coach" },
                        { key: "canAccessDietPlanner", label: "Diet Planner" },
                        { key: "canAccessAdvancedStats", label: "Advanced Stats" },
                        { key: "canExportData", label: "Export Data" },
                      ].map((feature) => {
                        const enabled = tier[feature.key as keyof TierLimits] as boolean;
                        const editEnabled = isEditing
                          ? (editValues[feature.key as keyof TierLimits] as boolean | undefined) ?? enabled
                          : enabled;

                        return (
                          <button
                            key={feature.key}
                            onClick={() => {
                              if (isEditing) {
                                setEditValues({ ...editValues, [feature.key]: !editEnabled });
                              }
                            }}
                            disabled={!isEditing}
                            className={`px-4 py-2 rounded-lg flex items-center gap-2 transition-colors ${
                              editEnabled
                                ? "bg-green-500/10 text-green-400 border border-green-500/30"
                                : "bg-zinc-800 text-zinc-500 border border-zinc-700"
                            } ${isEditing ? "cursor-pointer hover:opacity-80" : "cursor-default"}`}
                          >
                            {editEnabled ? <Check size={16} /> : <X size={16} />}
                            {feature.label}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
