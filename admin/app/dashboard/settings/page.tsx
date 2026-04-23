"use client";

import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { platformApi, PlatformConfig } from "@/lib/api";
import { useState } from "react";
import { Settings, RefreshCw, Check, Globe, Shield, Mail, FileText } from "lucide-react";
import { useRouter } from "next/navigation";
import NextImage from "next/image";
import { PageHeader } from "@/components/ui/PageHeader";

export default function PlatformSettingsPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved">("idle");

  const { data: config, isLoading, error } = useQuery({
    queryKey: ["platform-config"],
    queryFn: () => platformApi.getConfig(token!),
    enabled: !!token,
  });

  const updateMutation = useMutation({
    mutationFn: (data: Partial<PlatformConfig> & { pricePerBranch?: string | number; defaultTrialDays?: number; currency?: string }) =>
      platformApi.updateConfig(data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["platform-config"] });
      setSaveStatus("saved");
      setTimeout(() => setSaveStatus("idle"), 2000);
    },
    onMutate: () => {
      setSaveStatus("saving");
    },
  });

  // Redirect if not super admin
  if (!isSuperAdmin(user?.role)) {
    router.push("/dashboard");
    return null;
  }

  const handleFieldUpdate = (field: string, value: string | boolean | number) => {
    updateMutation.mutate({ [field]: value } as Parameters<typeof updateMutation.mutate>[0]);
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
        Failed to load platform settings
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="Platform Settings"
        description="Configure general platform settings and branding"
        icon={<Settings size={24} />}
        actions={
          <div className="flex items-center gap-4">
            {saveStatus === "saving" && (
              <span className="flex items-center gap-2 text-zinc-400">
                <RefreshCw className="animate-spin" size={16} />
                Saving...
              </span>
            )}
            {saveStatus === "saved" && (
              <span className="flex items-center gap-2 text-green-400">
                <Check size={16} />
                Saved
              </span>
            )}
          </div>
        }
      />

      {/* Maintenance Mode Banner */}
      {config?.maintenanceMode && (
        <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4 flex items-start gap-3">
          <Shield className="text-red-400 flex-shrink-0 mt-0.5" size={20} />
          <div>
            <p className="text-red-400 font-medium">Maintenance Mode Active</p>
            <p className="text-red-400/70 text-sm mt-1">
              The platform is currently in maintenance mode. Users cannot access the system.
            </p>
          </div>
        </div>
      )}

      {/* Branding */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 bg-[#F1C40F]/10 rounded-lg flex items-center justify-center">
            <Globe className="text-[#F1C40F]" size={20} />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-white">Branding</h2>
            <p className="text-sm text-zinc-500">Configure platform name and logo</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Platform Name</label>
            <input
              type="text"
              defaultValue={config?.platformName || "Amirani"}
              onBlur={(e) => handleFieldUpdate("platformName", e.target.value)}
              placeholder="Amirani"
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
            />
          </div>
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Platform Logo URL</label>
            <input
              type="url"
              defaultValue={config?.platformLogoUrl || ""}
              onBlur={(e) => handleFieldUpdate("platformLogoUrl", e.target.value)}
              placeholder="https://example.com/logo.png"
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
            />
          </div>
        </div>

        {config?.platformLogoUrl && (
          <div className="mt-4">
            <label className="block text-sm text-zinc-400 mb-2">Logo Preview</label>
            <div className="relative w-32 h-32 bg-zinc-800 rounded-lg flex items-center justify-center overflow-hidden">
              <NextImage
                src={config.platformLogoUrl}
                alt="Platform Logo"
                fill
                className="object-contain"
              />
            </div>
          </div>
        )}
      </div>

      {/* Contact Information */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 bg-blue-500/10 rounded-lg flex items-center justify-center">
            <Mail className="text-blue-400" size={20} />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-white">Contact Information</h2>
            <p className="text-sm text-zinc-500">Configure support contact details</p>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-4">
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Support Email</label>
            <input
              type="email"
              defaultValue={config?.supportEmail || ""}
              onBlur={(e) => handleFieldUpdate("supportEmail", e.target.value)}
              placeholder="support@amirani.app"
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
            />
          </div>
        </div>
      </div>

      {/* Legal */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 bg-purple-500/10 rounded-lg flex items-center justify-center">
            <FileText className="text-purple-400" size={20} />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-white">Legal Documents</h2>
            <p className="text-sm text-zinc-500">Configure legal document URLs</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Privacy Policy URL</label>
            <input
              type="url"
              defaultValue={config?.privacyPolicyUrl || ""}
              onBlur={(e) => handleFieldUpdate("privacyPolicyUrl", e.target.value)}
              placeholder="https://amirani.app/privacy"
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
            />
          </div>
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Terms of Service URL</label>
            <input
              type="url"
              defaultValue={config?.termsOfServiceUrl || ""}
              onBlur={(e) => handleFieldUpdate("termsOfServiceUrl", e.target.value)}
              placeholder="https://amirani.app/terms"
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
            />
          </div>
        </div>
      </div>

      {/* SaaS Billing */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 bg-emerald-500/10 rounded-lg flex items-center justify-center">
            <Globe className="text-emerald-400" size={20} />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-white">SaaS Billing</h2>
            <p className="text-sm text-zinc-500">Configure gym owner subscription pricing</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Monthly Cost per Branch</label>
            <input
              type="number"
              defaultValue={Number(config?.pricePerBranch || 0)}
              onBlur={(e) => handleFieldUpdate("pricePerBranch", parseFloat(e.target.value))}
              placeholder="0.00"
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
            />
          </div>
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Default Trial Days</label>
            <input
              type="number"
              defaultValue={config?.defaultTrialDays || 14}
              onBlur={(e) => handleFieldUpdate("defaultTrialDays", parseInt(e.target.value))}
              placeholder="14"
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
            />
          </div>
          <div>
            <label className="block text-sm text-zinc-400 mb-2">Billing Currency</label>
            <input
              type="text"
              defaultValue={config?.currency || "USD"}
              onBlur={(e) => handleFieldUpdate("currency", e.target.value)}
              placeholder="USD"
              className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
            />
          </div>
        </div>
      </div>

      {/* System */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 bg-red-500/10 rounded-lg flex items-center justify-center">
            <Shield className="text-red-400" size={20} />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-white">System</h2>
            <p className="text-sm text-zinc-500">System-wide settings</p>
          </div>
        </div>

        <div className="flex items-center justify-between p-4 bg-zinc-800/50 rounded-lg">
          <div>
            <p className="text-white font-medium">Maintenance Mode</p>
            <p className="text-sm text-zinc-400 mt-1">
              When enabled, users will see a maintenance page and cannot access the platform
            </p>
          </div>
          <button
            onClick={() => handleFieldUpdate("maintenanceMode", !config?.maintenanceMode)}
            className={`px-6 py-3 rounded-lg transition-colors ${
              config?.maintenanceMode
                ? "bg-red-500/10 text-red-400 border border-red-500/30"
                : "bg-zinc-700 text-zinc-300 border border-zinc-600"
            }`}
          >
            {config?.maintenanceMode ? "Disable" : "Enable"}
          </button>
        </div>
      </div>

      {/* Info Card */}
      <div className="bg-zinc-800/30 border border-zinc-800 rounded-xl p-6">
        <h3 className="text-sm font-medium text-zinc-400 mb-2">Platform Information</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <p className="text-zinc-500">Created</p>
            <p className="text-white">
              {config?.createdAt ? new Date(config.createdAt).toLocaleDateString() : "-"}
            </p>
          </div>
          <div>
            <p className="text-zinc-500">Last Updated</p>
            <p className="text-white">
              {config?.updatedAt ? new Date(config.updatedAt).toLocaleDateString() : "-"}
            </p>
          </div>
          <div>
            <p className="text-zinc-500">Config ID</p>
            <p className="text-white font-mono">{config?.id || "-"}</p>
          </div>
          <div>
            <p className="text-zinc-500">Version</p>
            <p className="text-white">1.0.0</p>
          </div>
        </div>
      </div>
    </div>
  );
}
