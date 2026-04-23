"use client";

import { useQuery } from "@tanstack/react-query";
import { platformApi, type SaaSInvoice } from "@/lib/api";
import { useAuthStore } from "@/lib/auth-store";
import { CreditCard, Calendar, Building2, Receipt, CheckCircle2, Clock } from "lucide-react";
import { format } from "date-fns";
import clsx from "clsx";
import { useState } from "react";
import { BuildingIcon } from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";

export default function BillingPage() {
  const { token } = useAuthStore();
  const [showTransferInstructions, setShowTransferInstructions] = useState(false);

  const { data: status, isLoading: statusLoading } = useQuery({
    queryKey: ["saas-status"],
    queryFn: () => platformApi.getSaaSStatus(token!),
    enabled: !!token,
  });

  const { data: invoices, isLoading: invoicesLoading } = useQuery({
    queryKey: ["saas-invoices"],
    queryFn: () => platformApi.getSaaSInvoices(token!),
    enabled: !!token,
  });

  if (statusLoading || invoicesLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#F1C40F]"></div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto space-y-8">
      <PageHeader
        title="Billing & Subscription"
        description="Manage your platform subscription and view invoices"
        icon={<CreditCard size={24} />}
      />

      {/* Subscription Card */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden">
          <div className="p-6 border-b border-zinc-800 bg-zinc-900/50">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div className="flex items-center gap-3">
                <h2 className="text-lg font-semibold text-white">Current Plan</h2>
                <span className={clsx(
                  "px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider",
                  status?.status === "ACTIVE" ? "bg-green-500/10 text-green-400" : 
                  status?.status === "TRIAL" ? "bg-blue-500/10 text-blue-400" : 
                  "bg-red-500/10 text-red-400"
                )}>
                  {status?.status}
                </span>
              </div>
              <button 
                onClick={() => setShowTransferInstructions(true)}
                className="px-4 py-2 bg-[#F1C40F] hover:bg-[#F1C40F]/90 !text-black font-bold uppercase tracking-wider text-xs rounded-lg transition-all shadow-[0_0_15px_rgba(241,196,15,0.3)] flex items-center gap-2 w-full sm:w-auto justify-center"
              >
                <CreditCard size={16} />
                Pay / Renew Plan
              </button>
            </div>
          </div>
          <div className="p-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
              <div className="space-y-1">
                <p className="text-xs text-zinc-500 uppercase font-black tracking-widest flex items-center gap-2">
                  <CreditCard size={12} /> Monthly Cost
                </p>
                <p className="text-2xl font-bold text-white">${status?.totalCostPerMonth.toFixed(2)}</p>
                <p className="text-xs text-zinc-400">Based on {status?.branchCount} active branches</p>
              </div>
              <div className="space-y-1">
                <p className="text-xs text-zinc-500 uppercase font-black tracking-widest flex items-center gap-2">
                  <Building2 size={12} /> Rate
                </p>
                <p className="text-2xl font-bold text-white">${status?.pricePerBranch.toFixed(2)}</p>
                <p className="text-xs text-zinc-400">Fixed rate per branch</p>
              </div>
              <div className="space-y-1">
                <p className="text-xs text-zinc-500 uppercase font-black tracking-widest flex items-center gap-2">
                  <Calendar size={12} /> Next Billing
                </p>
                <p className="text-2xl font-bold text-white">
                  {status?.nextBillingDate ? format(new Date(status.nextBillingDate), "MMM dd, yyyy") : "N/A"}
                </p>
                <p className="text-xs text-zinc-400">{status?.daysLeft} days remaining in cycle</p>
              </div>
            </div>
          </div>
        </div>

        {/* Quick Info */}
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6 flex flex-col justify-center space-y-4">
          <div className="flex items-center gap-4 text-zinc-300">
            <CheckCircle2 className="text-green-500 shrink-0" size={20} />
            <p className="text-sm">No artificial limits on members or staff</p>
          </div>
          <div className="flex items-center gap-4 text-zinc-300">
            <CheckCircle2 className="text-green-500 shrink-0" size={20} />
            <p className="text-sm">Full access to all platform features</p>
          </div>
          <div className="flex items-center gap-4 text-zinc-300">
            <CheckCircle2 className="text-green-500 shrink-0" size={20} />
            <p className="text-sm">Technical support included</p>
          </div>
        </div>
      </div>

      {/* Invoices List */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden">
        <div className="p-6 border-b border-zinc-800">
          <h2 className="text-lg font-semibold text-white flex items-center gap-2">
            <Receipt size={20} className="text-[#F1C40F]" />
            Billing History
          </h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-zinc-800 text-xs text-zinc-500 uppercase tracking-wider font-black">
                <th className="px-6 py-4">Date</th>
                <th className="px-6 py-4">Invoice #</th>
                <th className="px-6 py-4">Description</th>
                <th className="px-6 py-4">Amount</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800">
              {!invoices || invoices.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center text-zinc-500">
                    No billing history found
                  </td>
                </tr>
              ) : (
                invoices.map((invoice: SaaSInvoice) => (
                  <tr key={invoice.id} className="hover:bg-zinc-800/30 transition-colors">
                    <td className="px-6 py-4 text-sm text-white">
                      {format(new Date(invoice.createdAt), "MMM dd, yyyy")}
                    </td>
                    <td className="px-6 py-4 text-sm font-mono text-zinc-400">
                      {invoice.id.split('-')[0].toUpperCase()}
                    </td>
                    <td className="px-6 py-4 text-sm text-zinc-300">
                      {invoice.description}
                    </td>
                    <td className="px-6 py-4 text-sm font-bold text-white">
                      ${Number(invoice.amount).toFixed(2)}
                    </td>
                    <td className="px-6 py-4">
                      <span className={clsx(
                        "flex items-center gap-1.5 text-xs font-bold uppercase",
                        invoice.status === "SUCCEEDED" ? "text-green-400" : "text-zinc-500"
                      )}>
                        {invoice.status === "SUCCEEDED" ? <CheckCircle2 size={12} /> : <Clock size={12} />}
                        {invoice.status}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <button
                        disabled
                        title="Invoice viewer coming soon"
                        className="text-zinc-600 text-xs font-bold uppercase tracking-wider cursor-not-allowed"
                      >
                        View
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Bank Transfer Instructions Modal */}
      {showTransferInstructions && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
          <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
            {/* Header */}
            <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
              <div>
                <h2 className="text-xl font-black text-white uppercase tracking-tight italic flex items-center gap-2">
                  <BuildingIcon className="text-[#F1C40F]" size={24} />
                  Bank Transfer
                </h2>
                <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Manual Payment Instructions</p>
              </div>
              <button onClick={() => setShowTransferInstructions(false)} className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-all border border-white/5">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
              </button>
            </div>

            {/* Content */}
            <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
              <div className="space-y-6">
                <p className="text-sm text-zinc-300">
                  To continue or extend your SaaS subscription, please wire the total amount to the following bank account. 
                </p>

                <div className="bg-white/[0.03] border border-white/5 rounded-2xl p-6 space-y-4">
                  <div>
                    <span className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] block mb-1">Bank Name</span>
                    <span className="text-sm text-white font-mono">BOG Bank of Georgia</span>
                  </div>
                  <div>
                    <span className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] block mb-1">Account Holder</span>
                    <span className="text-sm text-white font-mono">Amirani Platform LLC</span>
                  </div>
                  <div>
                    <span className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] block mb-1">IBAN / Account Number</span>
                    <span className="text-sm text-[#F1C40F] font-mono select-all">GE00BG0000000123456789</span>
                  </div>
                  <div>
                    <span className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] block mb-1">SWIFT / BIC Code</span>
                    <span className="text-sm text-white font-mono select-all">BOGGE22</span>
                  </div>
                </div>

                <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl p-4 flex gap-3">
                  <div className="mt-0.5">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-blue-400"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>
                  </div>
                  <div className="text-xs text-blue-200 leading-relaxed">
                    <strong>Important:</strong> After transferring the funds, contact our support team or your account manager. A Super Admin will manually verify your payment and extend your subscription.
                  </div>
                </div>
              </div>
            </div>

            {/* Footer */}
            <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3 shrink-0">
              <button
                onClick={() => setShowTransferInstructions(false)}
                className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all flex items-center justify-center gap-2 shadow-xl shadow-[#F1C40F]/20 w-full"
              >
                I Understand
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
