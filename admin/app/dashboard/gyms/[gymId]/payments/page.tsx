"use client";

import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation } from "@tanstack/react-query";
import { gymOwnerApi, gymsApi, type Payment } from "@/lib/api";
import { useState } from "react";
import { useParams } from "next/navigation";
import NextImage from "next/image";
import {
  Wallet,
  CreditCard,
  RefreshCw,
  ExternalLink,
  Check,
  AlertTriangle,
  DollarSign,
  TrendingUp,
  Calendar,
} from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import { GymSwitcher } from "@/components/GymSwitcher";

export default function GymPaymentsPage() {
  const params = useParams();
  const gymId = params.gymId as string;
  const { token, user } = useAuthStore();
  const userRole = user?.role || "GYM_MEMBER";
  const [isOnboarding, setIsOnboarding] = useState(false);


  const { data: stripeStatus, isLoading: statusLoading } = useQuery({
    queryKey: ["stripe-status", gymId],
    queryFn: () => gymOwnerApi.getStripeStatus(gymId, token!),
    enabled: !!token && !!gymId,
  });

  const { data: earnings, isLoading: earningsLoading } = useQuery({
    queryKey: ["gym-earnings", gymId],
    queryFn: () => gymOwnerApi.getEarnings(gymId, token!),
    enabled: !!token && !!gymId && stripeStatus?.payoutsEnabled,
  });

  const { data: gyms, isLoading: gymsLoading } = useQuery({
    queryKey: ["gyms"],
    queryFn: () => gymsApi.getAll(token!),
    enabled: !!token && (userRole === "GYM_OWNER" || userRole === "SUPER_ADMIN"),
  });

  const onboardMutation = useMutation({
    mutationFn: () => {
      const returnUrl = `${window.location.origin}/dashboard/gyms/${gymId}/payments?onboarding=complete`;
      const refreshUrl = `${window.location.origin}/dashboard/gyms/${gymId}/payments?onboarding=refresh`;
      return gymOwnerApi.startStripeOnboarding(gymId, returnUrl, refreshUrl, token!);
    },
    onSuccess: (data) => {
      window.location.href = data.url;
    },
  });

  const dashboardMutation = useMutation({
    mutationFn: () => gymOwnerApi.getStripeDashboard(gymId, token!),
    onSuccess: (data) => {
      window.open(data.url, "_blank");
    },
  });

  const handleStartOnboarding = () => {
    setIsOnboarding(true);
    onboardMutation.mutate();
  };

  if (statusLoading) {
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
        title="Payments & Earnings"
        description="Manage your Stripe integration and track your revenue."
        icon={<Wallet size={32} />}
        actions={
          <GymSwitcher
            gyms={gyms}
            isLoading={gymsLoading}
            disabled={userRole !== "GYM_OWNER" && userRole !== "SUPER_ADMIN"}
          />
        }
      />

      {/* Stripe Connect Status */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-6">Payment Processing</h2>

        {!stripeStatus?.hasAccount ? (
          // No Account - Show Setup
          <div className="text-center py-8">
            <div className="w-16 h-16 bg-purple-500/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <CreditCard className="text-purple-400" size={32} />
            </div>
            <h3 className="text-xl font-semibold text-white mb-2">
              Accept Google Pay & Apple Pay
            </h3>
            <p className="text-zinc-400 max-w-md mx-auto mb-6">
              Connect your Stripe account to accept payments from members.
              You&apos;ll receive payouts directly to your bank account.
            </p>
            <div className="flex flex-col items-center gap-3">
              <button
                onClick={handleStartOnboarding}
                disabled={onboardMutation.isPending || isOnboarding}
                className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0 disabled:opacity-50"
              >
                {(onboardMutation.isPending || isOnboarding) ? (
                  <RefreshCw className="animate-spin" size={18} />
                ) : (
                  <CreditCard size={18} />
                )}
                Set Up Stripe Payments
              </button>
              <p className="text-xs text-zinc-500">Powered by Stripe Connect</p>
            </div>
          </div>
        ) : stripeStatus.status === "pending" || !stripeStatus.onboardingComplete ? (
          // Pending - Continue Setup
          <div className="text-center py-8">
            <div className="w-16 h-16 bg-yellow-500/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <AlertTriangle className="text-yellow-400" size={32} />
            </div>
            <h3 className="text-xl font-semibold text-white mb-2">
              Complete Your Setup
            </h3>
            <p className="text-zinc-400 max-w-md mx-auto mb-6">
              Your Stripe account setup is incomplete. Please continue to provide
              the required information to start accepting payments.
            </p>
            <button
              onClick={handleStartOnboarding}
              disabled={onboardMutation.isPending || isOnboarding}
              className="px-6 py-3 bg-[#F1C40F] !text-black rounded-lg hover:bg-[#F1C40F]/90 transition-colors disabled:opacity-50 flex items-center gap-2 font-medium"
            >
              {(onboardMutation.isPending || isOnboarding) ? (
                <RefreshCw className="animate-spin" size={18} />
              ) : (
                <ExternalLink size={18} />
              )}
              Continue Setup
            </button>
          </div>
        ) : (
          // Active Account
          <div className="space-y-6">
            {/* Status Badge */}
            <div className="flex items-center justify-between p-4 bg-green-500/10 border border-green-500/30 rounded-lg">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-green-500/20 rounded-full flex items-center justify-center">
                  <Check className="text-green-400" size={20} />
                </div>
                <div>
                  <p className="text-green-400 font-medium">Payments Active</p>
                  <p className="text-sm text-green-400/70">
                    Account ID: {stripeStatus.accountId}
                  </p>
                </div>
              </div>
              <button
                onClick={() => dashboardMutation.mutate()}
                disabled={dashboardMutation.isPending}
                className="px-4 py-2 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors flex items-center gap-2"
              >
                {dashboardMutation.isPending ? (
                  <RefreshCw className="animate-spin" size={16} />
                ) : (
                  <ExternalLink size={16} />
                )}
                Stripe Dashboard
              </button>
            </div>

            {/* Payment Methods */}
            <div>
              <h3 className="text-sm font-medium text-zinc-400 mb-3">Accepted Payment Methods</h3>
              <div className="flex gap-3">
                <div className="px-4 py-2 bg-zinc-800 rounded-lg flex items-center gap-2">
                  <NextImage src="https://upload.wikimedia.org/wikipedia/commons/b/b0/Apple_Pay_logo.svg" alt="Apple Pay" width={40} height={20} className="h-5 w-auto" />
                  <span className="text-white text-sm">Apple Pay</span>
                </div>
                <div className="px-4 py-2 bg-zinc-800 rounded-lg flex items-center gap-2">
                  <NextImage src="https://upload.wikimedia.org/wikipedia/commons/f/f2/Google_Pay_Logo.svg" alt="Google Pay" width={40} height={20} className="h-5 w-auto" />
                  <span className="text-white text-sm">Google Pay</span>
                </div>
                <div className="px-4 py-2 bg-zinc-800 rounded-lg flex items-center gap-2">
                  <CreditCard size={18} className="text-zinc-400" />
                  <span className="text-white text-sm">Cards</span>
                </div>
              </div>
            </div>

            {/* Currency */}
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-zinc-400">Currency</p>
                <p className="text-white font-medium">{stripeStatus.currency.toUpperCase()}</p>
              </div>
              <div>
                <p className="text-sm text-zinc-400">Payouts</p>
                <p className={`font-medium ${stripeStatus.payoutsEnabled ? "text-green-400" : "text-yellow-400"}`}>
                  {stripeStatus.payoutsEnabled ? "Enabled" : "Pending Verification"}
                </p>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Earnings Stats */}
      {stripeStatus?.payoutsEnabled && (
        <div className="space-y-6">
          {earningsLoading ? (
            <div className="flex items-center justify-center h-32">
              <RefreshCw className="animate-spin text-[#F1C40F]" size={24} />
            </div>
          ) : earnings ? (
            <>
              {/* Stats Cards */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
                  <div className="flex items-center justify-between mb-4">
                    <p className="text-sm text-zinc-400">Total Revenue</p>
                    <DollarSign className="text-green-400" size={20} />
                  </div>
                  <p className="text-3xl font-bold text-white">
                    ${earnings.totalRevenue.toFixed(2)}
                  </p>
                  <p className="text-sm text-zinc-500 mt-1">{earnings.currency.toUpperCase()}</p>
                </div>

                <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
                  <div className="flex items-center justify-between mb-4">
                    <p className="text-sm text-zinc-400">Platform Fee ({earnings.platformFeePercent}%)</p>
                    <TrendingUp className="text-orange-400" size={20} />
                  </div>
                  <p className="text-3xl font-bold text-white">
                    ${earnings.platformFees.toFixed(2)}
                  </p>
                  <p className="text-sm text-zinc-500 mt-1">Deducted from payments</p>
                </div>

                <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
                  <div className="flex items-center justify-between mb-4">
                    <p className="text-sm text-zinc-400">Net Earnings</p>
                    <Wallet className="text-[#F1C40F]" size={20} />
                  </div>
                  <p className="text-3xl font-bold text-[#F1C40F]">
                    ${earnings.netEarnings.toFixed(2)}
                  </p>
                  <p className="text-sm text-zinc-500 mt-1">Your payout amount</p>
                </div>
              </div>

              {/* Recent Payments */}
              <div className="bg-[#121721] border border-zinc-800 rounded-xl">
                <div className="p-6 border-b border-zinc-800 flex items-center justify-between">
                  <h2 className="text-lg font-semibold text-white">Recent Payments</h2>
                  <span className="px-3 py-1 bg-zinc-800 rounded-full text-sm text-zinc-400">
                    {earnings.paymentCount} total
                  </span>
                </div>

                {earnings.payments.length > 0 ? (
                  <div className="divide-y divide-zinc-800">
                    {earnings.payments.map((payment: Payment) => (
                      <div key={payment.id} className="p-4 flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                            payment.status === "SUCCEEDED"
                              ? "bg-green-500/10"
                              : "bg-red-500/10"
                          }`}>
                            {payment.status === "SUCCEEDED" ? (
                              <Check className="text-green-400" size={18} />
                            ) : (
                              <AlertTriangle className="text-red-400" size={18} />
                            )}
                          </div>
                          <div>
                            <p className="text-white">{payment.description || "Subscription Payment"}</p>
                            <p className="text-sm text-zinc-500">
                              {new Date(payment.createdAt).toLocaleDateString()}
                            </p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-white font-medium">
                            ${parseFloat(payment.amount).toFixed(2)}
                          </p>
                          <p className={`text-xs ${
                            payment.status === "SUCCEEDED" ? "text-green-400" : "text-red-400"
                          }`}>
                            {payment.status}
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="p-12 text-center">
                    <Calendar className="mx-auto text-zinc-600 mb-3" size={32} />
                    <p className="text-zinc-400">No payments yet</p>
                  </div>
                )}
              </div>
            </>
          ) : null}
        </div>
      )}
    </div>
  );
}
