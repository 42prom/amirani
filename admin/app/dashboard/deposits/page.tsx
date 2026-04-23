"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Landmark, RefreshCw, CheckCircle, XCircle, Clock } from "lucide-react";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";
import { api } from "@/lib/api";
import { useAuthStore } from "@/lib/auth-store";

interface Deposit {
  id: string;
  amount: string;
  type: "CASH_ON_HAND" | "BANK_DEPOSIT";
  status: "PENDING" | "APPROVED" | "REJECTED";
  reference: string | null;
  notes: string | null;
  createdAt: string;
  gym: { name: string };
  submittedBy: { fullName: string; email: string };
}

export default function GlobalDepositsPage() {
  const router = useRouter();
  const { token } = useAuthStore();
  const { gyms, selectedGymId, isGymsLoading: gymsLoading } = useGymSelection();
  const [deposits, setDeposits] = useState<Deposit[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  // Redirect to gym-specific deposits if selected (if branch manager / gym owner views it)
  useEffect(() => {
    if (selectedGymId) {
      router.replace(`/dashboard/gyms/${selectedGymId}/deposits`);
    }
  }, [selectedGymId, router]);

  useEffect(() => {
    const fetchDeposits = async () => {
      setIsLoading(true);
      try {
        const data = await api<Deposit[]>('/deposits/admin/all', { token: token! });
        setDeposits(data);
        setFetchError(null);
      } catch (error) {
        setFetchError(error instanceof Error ? error.message : "Failed to load deposits");
      } finally {
        setIsLoading(false);
      }
    };

    if (!selectedGymId) {
      fetchDeposits();
    }
  }, [selectedGymId, token]);

  const updateDepositStatus = async (id: string, status: "APPROVED" | "REJECTED") => {
    try {
      await api(`/deposits/admin/${id}/status`, { method: "PATCH", body: { status }, token: token! });
      setDeposits(prev => prev.map(d => d.id === id ? { ...d, status } : d));
      setActionError(null);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : "Failed to update deposit status");
    }
  };

  if (selectedGymId) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
      </div>
    );
  }

  return (
    <div className="space-y-12">
      <PageHeader
        title="FINANCIAL DEPOSITS"
        description="Manage cash on hand and bank deposits across all facilities"
        icon={<Landmark size={32} />}
        actions={<GymSwitcher gyms={gyms} isLoading={gymsLoading} />}
      />

      {fetchError && (
        <div className="px-4 py-3 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-400 text-sm font-medium">
          {fetchError}
        </div>
      )}
      {actionError && (
        <div className="px-4 py-3 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-400 text-sm font-medium">
          {actionError}
        </div>
      )}
      {isLoading ? (
        <div className="flex justify-center p-12">
          <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
        </div>
      ) : deposits.length === 0 ? (
        <div className="grid grid-cols-1 gap-6">
          <div className="col-span-full p-20 text-center bg-white/[0.02] border border-white/5 rounded-[3rem] backdrop-blur-3xl">
            <div className="w-20 h-20 bg-[#F1C40F]/10 rounded-3xl flex items-center justify-center mx-auto mb-6">
              <Landmark className="text-[#F1C40F]" size={40} />
            </div>
            <h2 className="text-2xl font-black text-white uppercase tracking-tighter mb-4">
              No Deposits Found
            </h2>
            <p className="text-zinc-500 max-w-sm mx-auto mb-8 font-medium">
              There are no pending or history of deposits reported by any branches.
            </p>
          </div>
        </div>
      ) : (
        <div className="bg-white/[0.02] border border-white/5 rounded-[2rem] overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-white/5 bg-white/[0.01]">
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Date</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Gym</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Type</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Amount</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Submitted By</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Status</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {deposits.map((deposit) => (
                  <tr key={deposit.id} className="hover:bg-white/[0.01] transition-colors">
                    <td className="p-4 text-sm text-zinc-300">
                      {new Date(deposit.createdAt).toLocaleDateString()}
                    </td>
                    <td className="p-4 text-sm font-medium text-white">
                      {deposit.gym.name}
                    </td>
                    <td className="p-4 text-sm">
                      <span className="px-2 py-1 rounded-full text-xs font-semibold bg-white/5 text-zinc-300">
                        {deposit.type.replace('_', ' ')}
                      </span>
                    </td>
                    <td className="p-4 text-sm font-bold text-[#F1C40F]">
                      ${Number(deposit.amount).toFixed(2)}
                    </td>
                    <td className="p-4 text-sm text-zinc-400">
                      <div>{deposit.submittedBy.fullName}</div>
                      <div className="text-xs opacity-75">{deposit.submittedBy.email}</div>
                    </td>
                    <td className="p-4 text-sm">
                      {deposit.status === 'PENDING' && (
                        <span className="flex items-center gap-1.5 text-yellow-500 bg-yellow-500/10 px-2 py-1 rounded-full text-xs font-semibold w-fit">
                          <Clock size={14} /> PENDING
                        </span>
                      )}
                      {deposit.status === 'APPROVED' && (
                        <span className="flex items-center gap-1.5 text-emerald-500 bg-emerald-500/10 px-2 py-1 rounded-full text-xs font-semibold w-fit">
                          <CheckCircle size={14} /> APPROVED
                        </span>
                      )}
                      {deposit.status === 'REJECTED' && (
                        <span className="flex items-center gap-1.5 text-red-500 bg-red-500/10 px-2 py-1 rounded-full text-xs font-semibold w-fit">
                          <XCircle size={14} /> REJECTED
                        </span>
                      )}
                    </td>
                    <td className="p-4 text-right">
                      {deposit.status === 'PENDING' && (
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => updateDepositStatus(deposit.id, 'APPROVED')}
                            className="bg-emerald-500/20 text-emerald-500 hover:bg-emerald-500/30 p-2 rounded-xl transition-colors"
                            title="Approve"
                          >
                            <CheckCircle size={18} />
                          </button>
                          <button
                            onClick={() => updateDepositStatus(deposit.id, 'REJECTED')}
                            className="bg-red-500/20 text-red-500 hover:bg-red-500/30 p-2 rounded-xl transition-colors"
                            title="Reject"
                          >
                            <XCircle size={18} />
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
