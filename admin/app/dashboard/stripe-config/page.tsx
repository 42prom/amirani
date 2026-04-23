"use client";

import { useState, useEffect } from "react";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { platformApi, type StripeConfig } from "@/lib/api";
import { Wallet, RefreshCw, Check, CreditCard, Link, AlertTriangle } from "lucide-react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/ui/PageHeader";
import { CustomSelect } from "@/components/ui/Select";

const CURRENCIES = [
  { value: "usd", label: "USD ($)" },
  { value: "eur", label: "EUR (€)" },
  { value: "gbp", label: "GBP (£)" },
  { value: "cad", label: "CAD ($)" },
  { value: "aud", label: "AUD ($)" },
];

export default function StripeConfigPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved">("idle");

  const { data: config, isLoading, error } = useQuery({
    queryKey: ["stripe-config"],
    queryFn: () => platformApi.getStripeConfig(token!),
    enabled: !!token && isSuperAdmin(user?.role),
  });

  const updateMutation = useMutation({
    mutationFn: (data: Partial<StripeConfig>) =>
      platformApi.updateStripeConfig(data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["stripe-config"] });
      setSaveStatus("saved");
      setTimeout(() => setSaveStatus("idle"), 2000);
    },
    onMutate: () => {
      setSaveStatus("saving");
    },
  });

  // Redirect if not super admin
  useEffect(() => {
    if (user && !isSuperAdmin(user?.role)) {
      router.push("/dashboard");
    }
  }, [user, router]);

  const handleFieldUpdate = (field: keyof StripeConfig, value: string | number | boolean) => {
    updateMutation.mutate({ [field]: value });
  };

  if (!isSuperAdmin(user?.role)) {
    return null;
  }

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
        Failed to load Stripe configuration
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="Stripe Configuration"
        description="Configure Stripe payment processing and Connect payouts"
        icon={<Wallet size={24} />}
        actions={
          <div className="flex items-center gap-4">
            {saveStatus === "saving" && (
              <span className="flex items-center gap-2 text-zinc-400 text-sm">
                <RefreshCw className="animate-spin" size={16} />
                Saving...
              </span>
            )}
            {saveStatus === "saved" && (
              <span className="flex items-center gap-2 text-green-400 text-sm">
                <Check size={16} />
                Saved
              </span>
            )}
            <span
              className={`px-3 py-1 rounded-full text-xs font-medium ${
                config?.testMode ? "bg-yellow-500/10 text-yellow-400" : "bg-green-500/10 text-green-400"
              }`}
            >
              {config?.testMode ? "Test Mode" : "Live Mode"}
            </span>
          </div>
        }
      />

      {/* Test Mode Warning */}
      {config?.testMode && (
        <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 flex items-start gap-3">
          <AlertTriangle className="text-yellow-400 flex-shrink-0 mt-0.5" size={20} />
          <div>
            <p className="text-yellow-400 font-medium">Test Mode Active</p>
            <p className="text-yellow-400/70 text-sm mt-1">
              Stripe is running in test mode. No real charges will be made. Switch to live mode before going to production.
            </p>
          </div>
        </div>
      )}

      {/* API Keys */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 bg-purple-500/10 rounded-lg flex items-center justify-center">
            <CreditCard className="text-purple-400" size={20} />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-white">API Keys</h2>
            <p className="text-sm text-zinc-500">Configure your Stripe API credentials</p>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-4">
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Publishable Key</label>
            <input
              type="text"
              defaultValue={config?.publishableKey || ""}
              onBlur={(e) => handleFieldUpdate("publishableKey", e.target.value)}
              placeholder={config?.testMode ? "pk_test_..." : "pk_live_..."}
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F] font-mono"
            />
          </div>
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Secret Key</label>
            <input
              type="password"
              defaultValue={config?.secretKey || ""}
              onBlur={(e) => {
                if (e.target.value && !e.target.value.startsWith("••••")) {
                  handleFieldUpdate("secretKey", e.target.value);
                }
              }}
              placeholder={config?.testMode ? "sk_test_..." : "sk_live_..."}
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F] font-mono"
            />
          </div>
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Webhook Secret</label>
            <input
              type="password"
              defaultValue={config?.webhookSecret ? "••••••••" : ""}
              onBlur={(e) => {
                if (e.target.value && e.target.value !== "••••••••") {
                  handleFieldUpdate("webhookSecret", e.target.value);
                }
              }}
              placeholder="whsec_..."
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F] font-mono"
            />
            <p className="text-xs text-zinc-500 mt-2">
              Found in your Stripe Dashboard under Developers → Webhooks
            </p>
          </div>
        </div>
      </div>

      {/* Stripe Connect */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-blue-500/10 rounded-lg flex items-center justify-center">
              <Link className="text-blue-400" size={20} />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-white">Stripe Connect</h2>
              <p className="text-sm text-zinc-500">Enable gym owners to receive direct payouts</p>
            </div>
          </div>
          <button
            onClick={() => handleFieldUpdate("connectEnabled", !config?.connectEnabled)}
            className={`px-4 py-2 rounded-lg transition-colors ${
              config?.connectEnabled
                ? "bg-green-500/10 text-green-400 border border-green-500/30"
                : "bg-zinc-800 text-zinc-400 border border-zinc-700"
            }`}
          >
            {config?.connectEnabled ? "Enabled" : "Disabled"}
          </button>
        </div>

        {config?.connectEnabled && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-zinc-400 mb-2">Platform Fee (%)</label>
              <input
                type="number"
                step="0.1"
                min="0"
                max="100"
                defaultValue={config?.platformFeePercent || 10}
                onBlur={(e) => handleFieldUpdate("platformFeePercent", parseFloat(e.target.value))}
                className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-[#F1C40F]"
              />
              <p className="text-xs text-zinc-500 mt-2">
                Percentage of each payment that goes to the platform
              </p>
            </div>
          </div>
        )}
      </div>

      {/* Payment Settings */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-6">Payment Settings</h2>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <CustomSelect
            label="Default Currency"
            value={config?.defaultCurrency || "usd"}
            onChange={(value) => handleFieldUpdate("defaultCurrency", value)}
            options={CURRENCIES}
          />

          <div>
            <label className="block text-sm text-zinc-400 mb-2">Environment</label>
            <div className="flex gap-4">
              <button
                onClick={() => handleFieldUpdate("testMode", true)}
                className={`flex-1 px-4 py-3 rounded-lg border-2 transition-all ${
                  config?.testMode
                    ? "border-yellow-500 bg-yellow-500/10 text-yellow-400"
                    : "border-zinc-700 text-zinc-400 hover:border-zinc-600"
                }`}
              >
                Test Mode
              </button>
              <button
                onClick={() => handleFieldUpdate("testMode", false)}
                className={`flex-1 px-4 py-3 rounded-lg border-2 transition-all ${
                  !config?.testMode
                    ? "border-green-500 bg-green-500/10 text-green-400"
                    : "border-zinc-700 text-zinc-400 hover:border-zinc-600"
                }`}
              >
                Live Mode
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Webhook Info */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-4">Webhook Configuration</h2>
        <p className="text-zinc-400 text-sm mb-4">
          Configure your Stripe webhook endpoint in the Stripe Dashboard to handle payment events.
        </p>
        <div className="bg-zinc-800 rounded-lg p-4">
          <label className="block text-sm text-zinc-400 mb-2">Webhook URL</label>
          <code className="text-[#F1C40F] text-sm">
            {typeof window !== "undefined" ? `${window.location.origin}/api/webhooks/stripe` : "https://your-domain.com/api/webhooks/stripe"}
          </code>
        </div>
        <div className="mt-4">
          <p className="text-sm text-zinc-400 mb-2">Required Events:</p>
          <div className="flex flex-wrap gap-2">
            {[
              "payment_intent.succeeded",
              "payment_intent.payment_failed",
              "customer.subscription.created",
              "customer.subscription.updated",
              "customer.subscription.deleted",
              "invoice.payment_succeeded",
              "invoice.payment_failed",
            ].map((event) => (
              <span
                key={event}
                className="px-2 py-1 bg-zinc-800 rounded text-xs text-zinc-400 font-mono"
              >
                {event}
              </span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
