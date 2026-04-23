"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { Wallet, RefreshCw } from "lucide-react";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";

export default function GlobalPaymentsPage() {
  const router = useRouter();
  const { gyms, selectedGymId, isGymsLoading: gymsLoading } = useGymSelection();

  // Redirect to gym-specific payments if selected
  useEffect(() => {
    if (selectedGymId) {
      router.replace(`/dashboard/gyms/${selectedGymId}/payments`);
    }
  }, [selectedGymId, router]);

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
        title="PAYMENTS & PAYOUTS"
        description="Select a facility to view its financial data and payouts"
        icon={<Wallet size={32} />}
        actions={<GymSwitcher gyms={gyms} isLoading={gymsLoading} />}
      />

      {/* Selector Placeholder */}
      <div className="grid grid-cols-1 gap-6">
        <div className="col-span-full p-20 text-center bg-white/[0.02] border border-white/5 rounded-[3rem] backdrop-blur-3xl">
          <div className="w-20 h-20 bg-[#F1C40F]/10 rounded-3xl flex items-center justify-center mx-auto mb-6">
            <Wallet className="text-[#F1C40F]" size={40} />
          </div>
          <h2 className="text-2xl font-black text-white uppercase tracking-tighter mb-4">
            No Facility Selected
          </h2>
          <p className="text-zinc-500 max-w-sm mx-auto mb-8 font-medium">
            Please use the switcher above to select a facility and access its payments, earnings, and Stripe configuration.
          </p>
        </div>
      </div>
    </div>
  );
}
