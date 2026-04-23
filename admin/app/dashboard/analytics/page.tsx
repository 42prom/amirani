"use client";

import { useEffect } from "react";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery } from "@tanstack/react-query";
import { platformApi, gymsApi, adminApi } from "@/lib/api";
import {
  BarChart3,
  RefreshCw,
  Users,
  Building2,
  Zap,
  TrendingUp,
  Activity,
} from "lucide-react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/ui/PageHeader";

function StatCard({
  title,
  value,
  icon: Icon,
  trend,
  color = "text-[#F1C40F]",
  bgColor = "bg-[#F1C40F]/10",
}: {
  title: string;
  value: string | number;
  icon: React.ElementType;
  trend?: string;
  color?: string;
  bgColor?: string;
}) {
  return (
    <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-zinc-400">{title}</p>
          <p className="text-3xl font-bold text-white mt-2">{value}</p>
          {trend && (
            <p className="text-sm text-green-400 mt-2 flex items-center gap-1">
              <TrendingUp size={14} />
              {trend}
            </p>
          )}
        </div>
        <div className={`w-12 h-12 ${bgColor} rounded-lg flex items-center justify-center`}>
          <Icon className={color} size={24} />
        </div>
      </div>
    </div>
  );
}

export default function AnalyticsPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();

  const isStaff = isSuperAdmin(user?.role);

  // Redirect if not super admin
  useEffect(() => {
    if (user && !isStaff) {
      router.push("/dashboard");
    }
  }, [user, isStaff, router]);

  const { data: gyms, isLoading: gymsLoading } = useQuery({
    queryKey: ["gyms"],
    queryFn: () => gymsApi.getAll(token!),
    enabled: !!token,
  });

  const { data: gymOwners, isLoading: ownersLoading } = useQuery({
    queryKey: ["gym-owners"],
    queryFn: () => adminApi.getGymOwners(token!),
    enabled: !!token,
  });

  const { data: aiUsage, isLoading: usageLoading } = useQuery({
    queryKey: ["ai-usage"],
    queryFn: () => platformApi.getAIUsage(token!),
    enabled: !!token,
  });

  const { data: tiers } = useQuery({
    queryKey: ["tier-limits"],
    queryFn: () => platformApi.getAllTierLimits(token!),
    enabled: !!token,
  });

  const isLoading = gymsLoading || ownersLoading || usageLoading;

  const totalMembers = gyms?.reduce((acc, gym) => acc + gym._count.memberships, 0) || 0;
  const totalTrainers = gyms?.reduce((acc, gym) => acc + gym._count.trainers, 0) || 0;
  const totalEquipment = gyms?.reduce((acc, gym) => acc + gym._count.equipment, 0) || 0;
  const activeGyms = gyms?.filter((gym) => gym.isActive).length || 0;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
      </div>
    );
  }

  if (!isStaff) return null;

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="Platform Analytics"
        description="Overview of platform-wide metrics and statistics"
        icon={<BarChart3 size={24} />}
      />

      {/* Main Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Gym Owners"
          value={gymOwners?.length || 0}
          icon={Users}
          trend="+2 this month"
        />
        <StatCard
          title="Total Gyms"
          value={gyms?.length || 0}
          icon={Building2}
          color="text-blue-400"
          bgColor="bg-blue-500/10"
        />
        <StatCard
          title="Active Gyms"
          value={activeGyms}
          icon={Activity}
          color="text-green-400"
          bgColor="bg-green-500/10"
        />
        <StatCard
          title="Total Members"
          value={totalMembers.toLocaleString()}
          icon={Users}
          trend="+12% from last month"
          color="text-purple-400"
          bgColor="bg-purple-500/10"
        />
      </div>

      {/* AI Usage Stats */}
      {aiUsage && (
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-6 flex items-center gap-2">
            <Zap className="text-[#F1C40F]" size={20} />
            AI Usage Analytics
          </h2>

          <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-6">
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-sm text-zinc-400">Total Requests</p>
              <p className="text-2xl font-bold text-white">
                {aiUsage.totalRequests.toLocaleString()}
              </p>
            </div>
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-sm text-zinc-400">Total Tokens</p>
              <p className="text-2xl font-bold text-white">
                {aiUsage.totalTokens.toLocaleString()}
              </p>
            </div>
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-sm text-zinc-400">Prompt Tokens</p>
              <p className="text-2xl font-bold text-white">
                {aiUsage.promptTokens.toLocaleString()}
              </p>
            </div>
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-sm text-zinc-400">Completion Tokens</p>
              <p className="text-2xl font-bold text-white">
                {aiUsage.completionTokens.toLocaleString()}
              </p>
            </div>
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-sm text-zinc-400">Estimated Cost</p>
              <p className="text-2xl font-bold text-[#F1C40F]">${aiUsage.estimatedCost}</p>
            </div>
          </div>

          {/* Usage by Provider */}
          {aiUsage.byProvider && aiUsage.byProvider.length > 0 && (
            <div className="mt-6">
              <h3 className="text-sm font-medium text-zinc-400 mb-3">Usage by Provider</h3>
              <div className="space-y-2">
                {aiUsage.byProvider.map((item) => {
                  const percentage = aiUsage.totalTokens
                    ? Math.round(((item._sum.totalTokens || 0) / aiUsage.totalTokens) * 100)
                    : 0;
                  return (
                    <div key={item.provider} className="flex items-center gap-4">
                      <span className="text-white w-32">{item.provider}</span>
                      <div className="flex-1 bg-zinc-800 rounded-full h-2">
                        <div
                          className="bg-[#F1C40F] h-2 rounded-full"
                          style={{ width: `${percentage}%` }}
                        />
                      </div>
                      <span className="text-zinc-400 text-sm w-20 text-right">
                        {(item._sum.totalTokens || 0).toLocaleString()} ({percentage}%)
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Usage by Type */}
          {aiUsage.byType && aiUsage.byType.length > 0 && (
            <div className="mt-6">
              <h3 className="text-sm font-medium text-zinc-400 mb-3">Usage by Request Type</h3>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {aiUsage.byType.map((item) => (
                  <div key={item.requestType} className="bg-zinc-800/50 rounded-lg p-3">
                    <p className="text-xs text-zinc-500 uppercase tracking-wide">
                      {item.requestType}
                    </p>
                    <p className="text-lg font-semibold text-white mt-1">
                      {item._count.toLocaleString()} requests
                    </p>
                    <p className="text-xs text-zinc-400">
                      {(item._sum.totalTokens || 0).toLocaleString()} tokens
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Platform Distribution */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Gym Stats */}
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-6">Gym Statistics</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-zinc-400">Total Gyms</span>
              <span className="text-white font-semibold">{gyms?.length || 0}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-zinc-400">Active Gyms</span>
              <span className="text-green-400 font-semibold">{activeGyms}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-zinc-400">Inactive Gyms</span>
              <span className="text-red-400 font-semibold">
                {(gyms?.length || 0) - activeGyms}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-zinc-400">Total Members</span>
              <span className="text-white font-semibold">{totalMembers.toLocaleString()}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-zinc-400">Total Staff</span>
              <span className="text-white font-semibold">{totalTrainers}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-zinc-400">Total Equipment</span>
              <span className="text-white font-semibold">{totalEquipment.toLocaleString()}</span>
            </div>
          </div>
        </div>

        {/* Tier Distribution */}
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-6">User Tier Limits</h2>
          {tiers && tiers.length > 0 ? (
            <div className="space-y-4">
              {tiers.map((tier) => (
                <div
                  key={tier.tier}
                  className="p-4 bg-zinc-800/50 rounded-lg"
                >
                  <div className="flex items-center justify-between mb-2">
                    <span
                      className={`font-medium ${
                        tier.tier === "FREE"
                          ? "text-zinc-400"
                          : tier.tier === "GYM_MEMBER"
                          ? "text-[#F1C40F]"
                          : "text-purple-400"
                      }`}
                    >
                      {tier.tier.replace("_", " ")}
                    </span>
                    <span className="text-xs text-zinc-500">
                      {tier.aiTokensPerMonth.toLocaleString()} tokens/mo
                    </span>
                  </div>
                  <div className="grid grid-cols-3 gap-2 text-xs">
                    <div>
                      <span className="text-zinc-500">Requests/day</span>
                      <p className="text-white">{tier.aiRequestsPerDay}</p>
                    </div>
                    <div>
                      <span className="text-zinc-500">Workout Plans</span>
                      <p className="text-white">{tier.workoutPlansPerMonth}/mo</p>
                    </div>
                    <div>
                      <span className="text-zinc-500">Diet Plans</span>
                      <p className="text-white">{tier.dietPlansPerMonth}/mo</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-zinc-500">No tier limits configured</p>
          )}
        </div>
      </div>

      {/* Top Gyms by Members */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-6">Top Gyms by Members</h2>
        {gyms && gyms.length > 0 ? (
          <div className="space-y-3">
            {[...gyms]
              .sort((a, b) => b._count.memberships - a._count.memberships)
              .slice(0, 5)
              .map((gym, index) => (
                <div
                  key={gym.id}
                  className="flex items-center gap-4 p-4 bg-zinc-800/50 rounded-lg"
                >
                  <span
                    className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${
                      index === 0
                        ? "bg-[#F1C40F] text-black"
                        : index === 1
                        ? "bg-zinc-400 text-black"
                        : index === 2
                        ? "bg-orange-600 text-white"
                        : "bg-zinc-700 text-white"
                    }`}
                  >
                    {index + 1}
                  </span>
                  <div className="flex-1">
                    <p className="text-white font-medium">{gym.name}</p>
                    <p className="text-xs text-zinc-500">
                      {gym.city}, {gym.country}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-white font-semibold">
                      {gym._count.memberships.toLocaleString()}
                    </p>
                    <p className="text-xs text-zinc-500">members</p>
                  </div>
                </div>
              ))}
          </div>
        ) : (
          <p className="text-zinc-500">No gyms found</p>
        )}
      </div>
    </div>
  );
}
