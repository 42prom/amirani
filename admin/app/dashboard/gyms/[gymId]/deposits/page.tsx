"use client";

import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { gymsApi, api } from "@/lib/api";
import { useState } from "react";
import { useParams } from "next/navigation";
import { Landmark, RefreshCw, CheckCircle, XCircle, Clock, PlusCircle } from "lucide-react";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";

interface Deposit {
  id: string;
  amount: string;
  type: "CASH_ON_HAND" | "BANK_DEPOSIT";
  status: "PENDING" | "APPROVED" | "REJECTED";
  reference: string | null;
  notes: string | null;
  createdAt: string;
}

export default function GymDepositsPage() {
  const params = useParams();
  const gymId = params.gymId as string;
  const { token, user } = useAuthStore();
  const userRole = user?.role || "GYM_MEMBER";
  const queryClient = useQueryClient();

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [amount, setAmount] = useState("");
  const [type, setType] = useState<"CASH_ON_HAND" | "BANK_DEPOSIT">("CASH_ON_HAND");
  const [reference, setReference] = useState("");
  const [notes, setNotes] = useState("");

  const { data: gym } = useQuery({
    queryKey: ["gym", gymId],
    queryFn: () => gymsApi.getById(gymId, token!),
    enabled: !!token && !!gymId,
  });

  const { data: gyms, isLoading: gymsLoading } = useQuery({
    queryKey: ["gyms"],
    queryFn: () => gymsApi.getAll(token!),
    enabled: !!token && (userRole === "GYM_OWNER" || userRole === "SUPER_ADMIN"),
  });

  const { data: deposits, isLoading: depositsLoading } = useQuery<Deposit[]>({
    queryKey: ["gym-deposits", gymId],
    queryFn: () => api<Deposit[]>(`/deposits/gym/${gymId}`, { token: token! }),
    enabled: !!gymId && !!token,
  });

  const submitDepositMutation = useMutation({
    mutationFn: () => api(`/deposits/gym/${gymId}`, {
      method: "POST",
      token: token!,
      body: {
        amount: Number(amount),
        type,
        reference,
        notes,
      }
    }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym-deposits", gymId] });
      setIsModalOpen(false);
      setAmount("");
      setReference("");
      setNotes("");
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    submitDepositMutation.mutate();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="Financial Deposits"
        description={`Manage cash on hand and bank deposits for ${gym?.name || ""}`}
        icon={<Landmark size={32} />}
        actions={
          <div className="flex items-center gap-4">
            <button
              onClick={() => setIsModalOpen(true)}
              className="px-4 py-2 bg-[#F1C40F] !text-black rounded-lg hover:bg-[#F1C40F]/90 transition-colors flex items-center gap-2 font-medium shrink-0"
            >
              <PlusCircle size={20} />
              Report Deposit
            </button>
            <GymSwitcher
              gyms={gyms}
              isLoading={gymsLoading}
              disabled={userRole !== "GYM_OWNER" && userRole !== "SUPER_ADMIN"}
            />
          </div>
        }
      />

      {depositsLoading ? (
        <div className="flex justify-center p-12">
          <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
        </div>
      ) : deposits?.length === 0 ? (
        <div className="grid grid-cols-1 gap-6">
          <div className="col-span-full p-20 text-center bg-white/[0.02] border border-white/5 rounded-[3rem] backdrop-blur-3xl">
            <div className="w-20 h-20 bg-[#F1C40F]/10 rounded-3xl flex items-center justify-center mx-auto mb-6">
              <Landmark className="text-[#F1C40F]" size={40} />
            </div>
            <h2 className="text-2xl font-black text-white uppercase tracking-tighter mb-4">
              No Deposits Found
            </h2>
            <p className="text-zinc-500 max-w-sm mx-auto mb-8 font-medium">
              You haven&apos;t reported any deposits or cash on hand yet.
            </p>
            <button
              onClick={() => setIsModalOpen(true)}
              className="px-6 py-3 bg-[#F1C40F] !text-black rounded-xl font-bold hover:bg-[#e0b60e] transition-colors"
            >
              Report First Deposit
            </button>
          </div>
        </div>
      ) : (
        <div className="bg-white/[0.02] border border-white/5 rounded-[2rem] overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-white/5 bg-white/[0.01]">
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Date</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Type</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Amount</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Reference/Notes</th>
                  <th className="p-4 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {deposits?.map((deposit) => (
                  <tr key={deposit.id} className="hover:bg-white/[0.01] transition-colors">
                    <td className="p-4 text-sm text-zinc-300">
                      {new Date(deposit.createdAt).toLocaleDateString()}
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
                      <div>{deposit.reference || "No reference"}</div>
                      <div className="text-xs opacity-75">{deposit.notes || ""}</div>
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
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Report Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-lg p-6 relative">
            <h2 className="text-2xl font-bold text-white mb-6">Report Deposit</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-zinc-400 mb-1">Type</label>
                <select
                  value={type}
                  onChange={(e) => setType(e.target.value as "CASH_ON_HAND" | "BANK_DEPOSIT")}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#F1C40F]"
                  required
                >
                  <option value="CASH_ON_HAND">Cash on Hand</option>
                  <option value="BANK_DEPOSIT">Bank Deposit</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-zinc-400 mb-1">Amount ($)</label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#F1C40F]"
                  placeholder="0.00"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-zinc-400 mb-1">Reference (Optional)</label>
                <input
                  type="text"
                  value={reference}
                  onChange={(e) => setReference(e.target.value)}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#F1C40F]"
                  placeholder="Bank Receipt #"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-zinc-400 mb-1">Notes (Optional)</label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#F1C40F] resize-none h-24"
                  placeholder="Additional information..."
                />
              </div>

              <div className="flex justify-end gap-3 mt-8">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-6 py-3 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors font-medium"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitDepositMutation.isPending || !amount}
                  className="px-6 py-3 bg-[#F1C40F] !text-black rounded-lg hover:bg-[#e0b60e] transition-colors font-bold disabled:opacity-50 flex items-center gap-2"
                >
                  {submitDepositMutation.isPending && (
                    <RefreshCw className="animate-spin" size={18} />
                  )}
                  Submit Deposit
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
