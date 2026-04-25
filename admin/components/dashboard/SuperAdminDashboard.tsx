"use client";

import { useAuthStore } from "@/lib/auth-store";
import { useQuery } from "@tanstack/react-query";
import { adminApi, analyticsApi } from "@/lib/api";
import { useState, useMemo } from "react";
import { 
  Users, 
  Building2, 
  DollarSign, 
  TrendingUp, 
  Search, 
  ArrowRight, 
  Sparkles,
  BarChart3,
  Activity
} from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
import { 
  LineChart, 
  Line, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  BarChart,
  Bar,
  Cell
} from 'recharts';

// ── Shared StatCard (Scoped locally or moved to a UI file) ──────────────────

function StatCard({
  title,
  value,
  icon: Icon,
  trend,
}: {
  title: string;
  value: string | number;
  icon: React.ElementType;
  trend?: string;
}) {
  return (
    <div className="bg-[#121721] border border-zinc-800 rounded-2xl p-6 relative overflow-hidden group">
      <div className="absolute right-0 top-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
        <Icon size={64} className="text-[#F1C40F]" />
      </div>
      <div className="flex items-center justify-between relative z-10">
        <div>
          <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest">{title}</p>
          <p className="text-3xl font-bold text-white mt-2">{value}</p>
          {trend && (
            <p className="text-xs text-green-400 mt-2 flex items-center gap-1 font-bold">
              <TrendingUp size={12} />
              {trend}
            </p>
          )}
        </div>
        <div className="w-12 h-12 bg-[#F1C40F]/10 rounded-xl flex items-center justify-center">
          <Icon className="text-[#F1C40F]" size={24} />
        </div>
      </div>
    </div>
  );
}

export default function SuperAdminDashboard() {
  const { token } = useAuthStore();
  const [search, setSearch] = useState("");
  const [sortBy, setSortBy] = useState<"revenue" | "members" | "gyms">("revenue");
  const [days, setDays] = useState(30);

  // ── Queries ──────────────────────────────────────────────────────────────
  const { data: kpis } = useQuery({
    queryKey: ["platform-kpis"],
    queryFn: () => analyticsApi.getPlatformKpis(token!),
    enabled: !!token,
  });

  const { data: platformStats } = useQuery({
    queryKey: ["platform-stats"],
    queryFn: () => analyticsApi.getPlatformStats(token!),
    enabled: !!token,
  });

  const { data: topOwnersData } = useQuery({
    queryKey: ["top-owners"],
    queryFn: () => analyticsApi.getTopOwners(token!, 10),
    enabled: !!token,
  });

  const { data: gymOwners } = useQuery({
    queryKey: ["gym-owners"],
    queryFn: () => adminApi.getGymOwners(token!),
    enabled: !!token,
  });

  const { data: revenueTrend } = useQuery({
    queryKey: ["platform-revenue-trend", days],
    queryFn: () => analyticsApi.getPlatformRevenueTrend(token!, days),
    enabled: !!token,
  });

  // ── Derived Data ─────────────────────────────────────────────────────────
  const revenueMap = useMemo(() => {
    const m: Record<string, number> = {};
    (topOwnersData ?? []).forEach((o) => { m[o.id] = o.revenueThisMonth; });
    return m;
  }, [topOwnersData]);

  const filteredOwners = useMemo(() => {
    const list = (gymOwners ?? []).map((o) => ({
      ...o,
      revenueThisMonth: revenueMap[o.id] ?? 0,
      totalMembers: o.ownedGyms.reduce((s, g) => s + (g._count?.memberships ?? 0), 0),
    }));

    const q = search.toLowerCase();
    const filtered = q
      ? list.filter((o) => o.fullName.toLowerCase().includes(q) || o.email.toLowerCase().includes(q))
      : list;

    return [...filtered].sort((a, b) => {
      if (sortBy === "revenue") return b.revenueThisMonth - a.revenueThisMonth;
      if (sortBy === "members") return b.totalMembers - a.totalMembers;
      return b.ownedGyms.length - a.ownedGyms.length;
    });
  }, [gymOwners, revenueMap, search, sortBy]);

  const chartData = useMemo(() => {
    return (revenueTrend ?? []).map((d) => ({
      date: new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      revenue: d.revenue,
    }));
  }, [revenueTrend]);

  const topOwnersChart = useMemo(() => {
    return (topOwnersData ?? []).slice(0, 5).map((o) => ({
      name: o.fullName.split(' ')[0],
      revenue: o.revenueThisMonth
    }));
  }, [topOwnersData]);

  const router = useRouter();

  return (
    <div className="space-y-8 animate-in fade-in duration-700">
      {/* AI Summary Box */}
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl p-6 flex flex-col md:flex-row items-center justify-between gap-6">
        <div className="flex flex-col sm:flex-row items-center gap-6 w-full">
          <div className="flex items-center gap-4 flex-1">
            <div className="w-12 h-12 bg-[#F1C40F]/10 rounded-xl flex items-center justify-center text-[#F1C40F]">
              <Sparkles size={24} />
            </div>
            <div>
              <h2 className="text-white font-bold">Platform AI Summary</h2>
              <p className="text-zinc-500 text-sm">
                Monthly revenue is {platformStats?.revenueGrowth ?? 0 >= 0 ? "up" : "down"} {Math.abs(platformStats?.revenueGrowth ?? 0)}% while network grew by {platformStats?.newPartners ?? 0} partners.
              </p>
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            <div className={`px-4 py-2 rounded-lg border text-xs font-bold ${
              (platformStats?.revenueGrowth ?? 0) >= 0 
                ? "bg-green-500/10 border-green-500/20 text-green-400" 
                : "bg-red-500/10 border-red-500/20 text-red-400"
            }`}>
              {(platformStats?.revenueGrowth ?? 0) >= 0 ? "+" : ""}{platformStats?.revenueGrowth ?? 0}% Revenue
            </div>
            <div className="px-4 py-2 bg-blue-500/10 rounded-lg border border-blue-500/20 text-blue-400 text-xs font-bold">
              +{platformStats?.newPartners ?? 0} New Partners
            </div>
            <button 
              onClick={() => router.push("/dashboard/gym-owners")}
              className="flex items-center gap-2 px-6 py-2.5 bg-[#F1C40F] hover:bg-[#D4AC0D] text-black font-black rounded-xl transition-all shadow-lg shadow-[#F1C40F]/10 uppercase text-[10px] tracking-widest ml-4"
            >
              <Plus size={18} />
              Add Gym Partner
            </button>
          </div>
        </div>
      </div>

      {/* KPI Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Partners"
          value={kpis?.ownerCount ?? gymOwners?.length ?? "—"}
          icon={Users}
          trend="+2 this week"
        />
        <StatCard
          title="Active Branches"
          value={kpis?.gymCount ?? "—"}
          icon={Building2}
          trend="+5.2% MoM"
        />
        <StatCard
          title="Total Revenue"
          value={kpis ? `$${kpis.totalRevenueThisMonth.toLocaleString()}` : "—"}
          icon={DollarSign}
          trend="+18% growth"
        />
        <StatCard
          title="Avg Rev / Owner"
          value={kpis ? `$${kpis.avgRevenuePerOwner.toLocaleString()}` : "—"}
          icon={TrendingUp}
          trend="Stable"
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Revenue Trend Line Chart */}
        <div className="lg:col-span-2 bg-[#121721] border border-zinc-800 rounded-2xl p-6">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-white font-bold flex items-center gap-2">
              <Activity size={18} className="text-[#F1C40F]" />
              Platform Revenue Trend
            </h3>
            <select 
              value={days}
              onChange={(e) => setDays(Number(e.target.value))}
              className="bg-white/5 border border-zinc-800 rounded-lg px-3 py-1 text-[10px] text-zinc-400 uppercase font-black tracking-widest outline-none cursor-pointer hover:border-[#F1C40F]/50 transition-colors"
            >
              <option value={30}>Last 30 Days</option>
              <option value={90}>Last 90 Days</option>
            </select>
          </div>
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1f2937" vertical={false} />
                <XAxis 
                  dataKey="date" 
                  stroke="#6b7280" 
                  fontSize={10} 
                  tickLine={false} 
                  axisLine={false}
                  dy={10}
                />
                <YAxis 
                  stroke="#6b7280" 
                  fontSize={10} 
                  tickLine={false} 
                  axisLine={false}
                  tickFormatter={(val) => `$${val}`}
                />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#121721', border: '1px solid #374151', borderRadius: '12px' }}
                  itemStyle={{ color: '#F1C40F', fontWeight: 'bold' }}
                />
                <Line 
                  type="monotone" 
                  dataKey="revenue" 
                  stroke="#F1C40F" 
                  strokeWidth={3} 
                  dot={false}
                  activeDot={{ r: 6, stroke: '#121721', strokeWidth: 2 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Top Owners Bar Chart */}
        <div className="bg-[#121721] border border-zinc-800 rounded-2xl p-6">
          <h3 className="text-white font-bold flex items-center gap-2 mb-8">
            <BarChart3 size={18} className="text-[#F1C40F]" />
            Top 5 Performers
          </h3>
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={topOwnersChart} layout="vertical">
                <XAxis type="number" hide />
                <YAxis 
                  dataKey="name" 
                  type="category" 
                  stroke="#6b7280" 
                  fontSize={10} 
                  tickLine={false} 
                  axisLine={false}
                  width={60}
                />
                <Tooltip 
                   cursor={{ fill: 'rgba(255,255,255,0.05)' }}
                   contentStyle={{ backgroundColor: '#121721', border: '1px solid #374151', borderRadius: '12px' }}
                />
                <Bar dataKey="revenue" radius={[0, 4, 4, 0]} barSize={20}>
                  {topOwnersChart.map((_, index) => (
                    <Cell key={`cell-${index}`} fill={index === 0 ? '#F1C40F' : '#F1C40F80'} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Partner Table */}
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl overflow-hidden">
        <div className="p-6 border-b border-zinc-800 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <h2 className="text-lg font-bold text-white">Platform Partners</h2>
          <div className="flex items-center gap-3 w-full sm:w-auto">
            <div className="relative flex-1 sm:w-64">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search by name or email..."
                className="w-full bg-white/5 border border-zinc-800 rounded-lg pl-8 pr-3 py-2 text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]/50"
              />
            </div>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value as "revenue" | "members" | "gyms")}
              className="bg-white/5 border border-zinc-800 rounded-lg px-3 py-2 text-xs text-zinc-400 outline-none focus:border-[#F1C40F]/50"
            >
              <option value="revenue">Sort: Revenue</option>
              <option value="members">Sort: Members</option>
              <option value="gyms">Sort: Branches</option>
            </select>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead className="bg-white/[0.02] border-b border-zinc-800">
              <tr>
                <th className="px-6 py-4 text-[10px] text-zinc-500 uppercase font-black tracking-widest">Partner</th>
                <th className="px-6 py-4 text-[10px] text-zinc-500 uppercase font-black tracking-widest hidden md:table-cell">Branches</th>
                <th className="px-6 py-4 text-[10px] text-zinc-500 uppercase font-black tracking-widest hidden md:table-cell">Total Members</th>
                <th className="px-6 py-4 text-[10px] text-zinc-500 uppercase font-black tracking-widest">Revenue</th>
                <th className="px-6 py-4 text-[10px] text-zinc-500 uppercase font-black tracking-widest text-right">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800">
              {filteredOwners.map((owner) => (
                <tr key={owner.id} className="hover:bg-white/[0.02] transition-colors group cursor-pointer">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 bg-[#F1C40F]/10 rounded-full flex items-center justify-center text-[#F1C40F] font-bold text-xs">
                        {owner.fullName.charAt(0)}
                      </div>
                      <div>
                        <p className="text-sm font-bold text-white group-hover:text-[#F1C40F] transition-colors">{owner.fullName}</p>
                        <p className="text-[10px] text-zinc-500">{owner.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 hidden md:table-cell">
                    <span className="text-zinc-300 text-sm font-medium">{owner.ownedGyms.length}</span>
                  </td>
                  <td className="px-6 py-4 hidden md:table-cell">
                    <span className="text-zinc-300 text-sm font-medium">{owner.totalMembers.toLocaleString()}</span>
                  </td>
                  <td className="px-6 py-4">
                    <span className="text-[#F1C40F] text-sm font-bold">${owner.revenueThisMonth.toLocaleString()}</span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                      owner.isActive ? "bg-green-500/10 text-green-500" : "bg-red-500/10 text-red-500"
                    }`}>
                      {owner.isActive ? "Active" : "Inactive"}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        
        <div className="p-6 border-t border-zinc-800 bg-white/[0.01] flex items-center justify-between">
          <p className="text-[10px] text-zinc-500 uppercase font-bold">Showing {filteredOwners.length} partners</p>
          <Link href="/dashboard/gym-owners" className="text-[#F1C40F] text-[10px] font-black uppercase tracking-widest flex items-center gap-1 hover:underline">
            Manage All Partners
            <ArrowRight size={12} />
          </Link>
        </div>
      </div>
    </div>
  );
}
