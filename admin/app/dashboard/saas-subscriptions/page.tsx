"use client";

import { useQuery } from "@tanstack/react-query";
import { platformApi, type SaaSSubscription } from "@/lib/api";
import { useAuthStore } from "@/lib/auth-store";
import { Users, CreditCard, Building2, TrendingUp, Search, ExternalLink } from "lucide-react";
import { format } from "date-fns";
import clsx from "clsx";
import { useState } from "react";
import Link from "next/link";
import { CalendarClock, X, RefreshCw, FileText, CheckCircle2, LayoutDashboard } from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";

export default function SaaSManagementPage() {
  const { token } = useAuthStore();
  const [searchTerm, setSearchTerm] = useState("");
  const [extendingSub, setExtendingSub] = useState<SaaSSubscription | null>(null);

  const { data: subscriptions, isLoading, refetch } = useQuery({
    queryKey: ["all-saas-subscriptions"],
    queryFn: () => platformApi.getAllSaaSSubscriptions(token!),
    enabled: !!token,
  });

  const filteredSubscriptions = subscriptions?.filter(sub => 
    sub.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
    sub.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const stats = subscriptions?.reduce((acc, sub) => ({
    totalMonthlyRevenue: acc.totalMonthlyRevenue + sub.monthlyCost,
    activeOwners: acc.activeOwners + (sub.status === "ACTIVE" ? 1 : 0),
    trialOwners: acc.trialOwners + (sub.status === "TRIAL" ? 1 : 0),
    totalBranches: acc.totalBranches + sub.branchCount,
  }), { totalMonthlyRevenue: 0, activeOwners: 0, trialOwners: 0, totalBranches: 0 });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#F1C40F]"></div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="SaaS Subscription Management"
        description="Monitor and manage all gym owner subscriptions"
        icon={<LayoutDashboard size={24} />}
      />

      {/* Platform Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <p className="text-xs text-zinc-500 uppercase font-black tracking-widest mb-1">Monthly Revenue</p>
          <div className="flex items-center justify-between">
            <p className="text-2xl font-bold text-[#F1C40F]">${stats?.totalMonthlyRevenue.toFixed(2)}</p>
            <div className="p-2 bg-[#F1C40F]/10 rounded-lg text-[#F1C40F]">
              <TrendingUp size={20} />
            </div>
          </div>
        </div>
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <p className="text-xs text-zinc-500 uppercase font-black tracking-widest mb-1">Active Subscriptions</p>
          <div className="flex items-center justify-between">
            <p className="text-2xl font-bold text-white">{stats?.activeOwners}</p>
            <div className="p-2 bg-green-500/10 rounded-lg text-green-400">
              <Users size={20} />
            </div>
          </div>
        </div>
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <p className="text-xs text-zinc-500 uppercase font-black tracking-widest mb-1">Trials Ending Soon</p>
          <div className="flex items-center justify-between">
            <p className="text-2xl font-bold text-white">{stats?.trialOwners}</p>
            <div className="p-2 bg-blue-500/10 rounded-lg text-blue-400">
              <CreditCard size={20} />
            </div>
          </div>
        </div>
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <p className="text-xs text-zinc-500 uppercase font-black tracking-widest mb-1">Managed Branches</p>
          <div className="flex items-center justify-between">
            <p className="text-2xl font-bold text-white">{stats?.totalBranches}</p>
            <div className="p-2 bg-purple-500/10 rounded-lg text-purple-400">
              <Building2 size={20} />
            </div>
          </div>
        </div>
      </div>

      {/* Subscription List */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden">
        <div className="p-6 border-b border-zinc-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
          <h2 className="text-lg font-semibold text-white">Owner Subscriptions</h2>
          <div className="relative w-full md:w-64">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
            <input
              type="text"
              placeholder="Search owners..."
              className="w-full bg-zinc-900 border border-zinc-800 rounded-lg pl-10 pr-4 py-2 text-sm text-white focus:outline-none focus:border-[#F1C40F]"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-zinc-800 text-xs text-zinc-500 uppercase tracking-wider font-black">
                <th className="px-6 py-4">Owner</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4">Branches</th>
                <th className="px-6 py-4">Monthly Bill</th>
                <th className="px-6 py-4">Details</th>
                <th className="px-6 py-4">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800">
              {filteredSubscriptions?.map((sub: SaaSSubscription) => (
                <tr key={sub.ownerId} className="hover:bg-zinc-800/30 transition-colors">
                  <td className="px-6 py-4">
                    <div className="flex flex-col">
                      <span className="text-sm font-medium text-white">{sub.fullName}</span>
                      <span className="text-xs text-zinc-500">{sub.email}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={clsx(
                      "px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider",
                      sub.status === "ACTIVE" ? "bg-green-500/10 text-green-400" :
                      sub.status === "TRIAL" ? "bg-blue-500/10 text-blue-400" :
                      "bg-red-500/10 text-red-400"
                    )}>
                      {sub.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-zinc-300">
                    {sub.branchCount} gyms
                  </td>
                  <td className="px-6 py-4 text-sm font-bold text-white">
                    ${sub.monthlyCost.toFixed(2)}
                  </td>
                  <td className="px-6 py-4 text-[11px] text-zinc-500 italic">
                    {sub.status === "TRIAL" ? `Ends: ${sub.trialEndsAt ? format(new Date(sub.trialEndsAt), "MMM dd") : 'N/A'}` : 
                     `Next: ${sub.nextBillingDate ? format(new Date(sub.nextBillingDate), "MMM dd") : 'N/A'}`}
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => setExtendingSub(sub)}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#F1C40F]/10 text-[#F1C40F] hover:bg-[#F1C40F]/20 rounded-lg text-xs font-bold transition-colors"
                        title="Extend Subscription manually"
                      >
                        <CalendarClock size={14} />
                        Extend
                      </button>
                      <Link
                        href={`/dashboard/gym-owners?search=${encodeURIComponent(sub.email)}`}
                        className="inline-block p-1.5 hover:bg-zinc-800 rounded-lg text-zinc-400 hover:text-white transition-colors"
                        title="Manage Owner"
                      >
                        <ExternalLink size={16} />
                      </Link>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Manual Extension Modal */}
      {extendingSub && token && (
        <ExtendSubscriptionModal 
          sub={extendingSub} 
          token={token}
          onClose={() => setExtendingSub(null)} 
          onSuccess={() => {
            setExtendingSub(null);
            refetch();
          }}
        />
      )}
    </div>
  );
}

function ExtendSubscriptionModal({ 
  sub, 
  token,
  onClose, 
  onSuccess 
}: { 
  sub: SaaSSubscription; 
  token: string;
  onClose: () => void; 
  onSuccess: () => void; 
}) {
  const [days, setDays] = useState("30");
  const [amount, setAmount] = useState(sub.monthlyCost.toString());
  const [notes, setNotes] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError("");

    try {
      await platformApi.extendSaaSSubscription(
        sub.ownerId, 
        {
          days: parseInt(days),
          amount: parseFloat(amount),
          paymentMethod: "Bank Transfer", 
          notes
        },
        token
      );
      onSuccess();
    } catch (err: unknown) {
      if (err instanceof Error) {
        setError(err.message || "Failed to extend subscription");
      } else {
        setError("Failed to extend subscription");
      }
      setIsLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        {/* Header */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-xl font-black text-white uppercase tracking-tight italic flex items-center gap-2">
              <CalendarClock className="text-[#F1C40F]" size={24} />
              Manual Extension
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Log external payment for {sub.fullName}</p>
          </div>
          <button onClick={onClose} className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {error && (
              <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-4 text-red-400 text-xs font-bold uppercase tracking-widest flex items-center gap-3">
                <X size={18} />
                {error}
              </div>
            )}

            <div className="bg-zinc-800/30 p-4 rounded-2xl space-y-2 border border-white/5">
                <div className="flex justify-between items-center text-xs">
                    <span className="text-zinc-500 font-bold uppercase tracking-wider">Current Status</span>
                    <span className={clsx(
                        "px-2 py-0.5 rounded-md font-bold uppercase",
                        sub.status === "ACTIVE" ? "bg-green-500/10 text-green-400" :
                        sub.status === "TRIAL" ? "bg-blue-500/10 text-blue-400" : "bg-red-500/10 text-red-400"
                    )}>{sub.status}</span>
                </div>
                <div className="flex justify-between items-center text-xs">
                    <span className="text-zinc-500 font-bold uppercase tracking-wider">Est. Monthly Cost</span>
                    <span className="text-white font-mono">${sub.monthlyCost.toFixed(2)} ({sub.branchCount} gyms)</span>
                </div>
                 <div className="flex justify-between items-center text-xs">
                    <span className="text-zinc-500 font-bold uppercase tracking-wider">Expiry</span>
                    <span className="text-zinc-300">
                    {sub.status === "TRIAL" ? (sub.trialEndsAt ? format(new Date(sub.trialEndsAt), "MMM dd, yyyy") : "N/A") 
                                            : (sub.nextBillingDate ? format(new Date(sub.nextBillingDate), "MMM dd, yyyy") : "N/A")}
                    </span>
                </div>
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Days to Extend
              </label>
              <input
                type="number"
                min="0"
                step="1"
                value={days}
                onChange={(e) => setDays(e.target.value)}
                required
                className="w-full px-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all font-mono"
                placeholder="e.g. 14, 30, 365"
              />
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Amount Paid (USD)
              </label>
              <div className="relative">
                <span className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-500 font-bold">$</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  required
                  className="w-full pl-10 pr-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all font-mono"
                  placeholder="0.00"
                />
              </div>
            </div>

            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mb-3 ml-1">
                Description / Notes
              </label>
              <div className="relative">
                <FileText className="absolute left-6 top-4 text-zinc-500" size={16} />
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  rows={2}
                  className="w-full pl-14 pr-6 py-4 bg-white/[0.03] border border-white/5 rounded-2xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F] focus:bg-white/[0.05] transition-all resize-none"
                  placeholder="e.g. Bank Transfer Ref: TR-12345"
                />
              </div>
            </div>
          </form>
        </div>

        {/* Footer */}
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
            disabled={isLoading || !amount}
            className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all disabled:opacity-50 flex items-center justify-center gap-2 shadow-xl shadow-[#F1C40F]/20"
          >
            {isLoading ? (
              <><RefreshCw className="animate-spin" size={16} /> Processing...</>
            ) : (
              <><CheckCircle2 size={16} /> Confirm Extension</>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
