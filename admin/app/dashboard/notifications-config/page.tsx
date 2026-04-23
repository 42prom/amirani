"use client";

import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { platformApi, PushNotificationConfig } from "@/lib/api";
import { useState } from "react";
import { Bell, RefreshCw, Smartphone, Mail, Check, Eye, EyeOff, ShieldCheck } from "lucide-react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/ui/PageHeader";

// ─── Shared UI Components ───────────────────────────────────────────────────

function SecretField({
  label,
  placeholder,
  value,
  onChange,
  hint,
  rows,
}: {
  label: string;
  placeholder: string;
  value: string;
  onChange: (v: string) => void;
  hint?: string;
  rows?: number;
}) {
  const [show, setShow] = useState(false);
  const isMasked = value.startsWith("••••••••");

  return (
    <div>
      <label className="block text-sm font-medium text-zinc-300 mb-1.5">{label}</label>
      <div className="relative">
        {rows ? (
          <textarea
            value={isMasked ? "" : value}
            placeholder={isMasked ? "Already set — enter new value to replace" : placeholder}
            onChange={(e) => onChange(e.target.value)}
            rows={rows}
            className="w-full bg-zinc-900 border border-zinc-700/50 rounded-xl px-4 py-3 text-white text-sm placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/60 font-mono transition-all"
          />
        ) : (
          <div className="relative">
            <input
              type={show ? "text" : "password"}
              value={isMasked ? "" : value}
              placeholder={isMasked ? "Already set — enter new value to replace" : placeholder}
              onChange={(e) => onChange(e.target.value)}
              className="w-full bg-zinc-900 border border-zinc-700/50 rounded-xl px-4 py-3 text-white text-sm placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/60 pr-12 transition-all"
            />
            <button
              type="button"
              onClick={() => setShow(!show)}
              className="absolute right-4 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-zinc-300 transition-colors"
            >
              {show ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>
        )}
      </div>
      {hint && <p className="text-[11px] text-zinc-500 mt-1.5 ml-1">{hint}</p>}
    </div>
  );
}

function TextField({
  label,
  placeholder,
  value,
  onChange,
  hint,
  mono,
  type = "text",
}: {
  label: string;
  placeholder: string;
  value: string;
  onChange: (v: string) => void;
  hint?: string;
  mono?: boolean;
  type?: string;
}) {
  return (
    <div>
      <label className="block text-sm font-medium text-zinc-300 mb-1.5">{label}</label>
      <input
        type={type}
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className={`w-full bg-zinc-900 border border-zinc-700/50 rounded-xl px-4 py-3 text-white text-sm placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/60 transition-all ${
          mono ? "font-mono" : ""
        }`}
      />
      {hint && <p className="text-[11px] text-zinc-500 mt-1.5 ml-1">{hint}</p>}
    </div>
  );
}

// ─── Main Page ───────────────────────────────────────────────────────────────

export default function NotificationsConfigPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved">("idle");

  // Local draft states
  const [fcmDraft, setFcmDraft] = useState<Partial<PushNotificationConfig>>({});
  const [apnsDraft, setApnsDraft] = useState<Partial<PushNotificationConfig>>({});
  const [emailDraft, setEmailDraft] = useState<Partial<PushNotificationConfig>>({});
  const [isInitialized, setIsInitialized] = useState(false);

  const { data: config, isLoading, error } = useQuery({
    queryKey: ["notification-config"],
    queryFn: () => platformApi.getNotificationConfig(token!),
    enabled: !!token && isSuperAdmin(user?.role),
  });

  if (config && !isInitialized) {
    setFcmDraft({
      fcmEnabled: config.fcmEnabled,
      fcmProjectId: config.fcmProjectId || "",
      fcmClientEmail: config.fcmClientEmail || "",
      fcmPrivateKey: config.fcmPrivateKey || "",
    });
    setApnsDraft({
      apnsEnabled: config.apnsEnabled,
      apnsKeyId: config.apnsKeyId || "",
      apnsTeamId: config.apnsTeamId || "",
      apnsBundleId: config.apnsBundleId || "",
      apnsProduction: config.apnsProduction,
      apnsPrivateKey: config.apnsPrivateKey || "",
    });
    setEmailDraft({
      emailEnabled: config.emailEnabled,
      emailProvider: config.emailProvider || "smtp",
      sendgridApiKey: config.sendgridApiKey || "",
      smtpHost: config.smtpHost || "",
      smtpPort: config.smtpPort || 587,
      smtpUser: config.smtpUser || "",
      smtpPassword: config.smtpPassword || "",
      fromEmail: config.fromEmail || "",
      fromName: config.fromName || "",
    });
    setIsInitialized(true);
  }

  const updateMutation = useMutation({
    mutationFn: (data: Partial<PushNotificationConfig>) =>
      platformApi.updateNotificationConfig(data, token!),
    onMutate: () => setSaveStatus("saving"),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notification-config"] });
      setSaveStatus("saved");
      setTimeout(() => setSaveStatus("idle"), 2000);
    },
    onError: () => setSaveStatus("idle"),
  });

  const saveFcm = () => updateMutation.mutate(fcmDraft);
  const saveApns = () => updateMutation.mutate(apnsDraft);
  const saveEmail = () => updateMutation.mutate(emailDraft);

  if (!isSuperAdmin(user?.role)) {
    router.push("/dashboard");
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
      <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-4 text-red-400">
        Failed to load notification configuration
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-10">
      {/* Header */}
      <PageHeader
        title="Push Notification Configuration"
        description="Manage Firebase Cloud Messaging (Android), APNs (iOS), and Email delivery settings"
        icon={<Bell size={28} />}
        actions={
          <div className="flex items-center gap-2">
            {saveStatus === "saving" && (
              <span className="flex items-center gap-2 text-zinc-400 text-sm">
                <RefreshCw className="animate-spin" size={16} /> Saving...
              </span>
            )}
            {saveStatus === "saved" && (
              <span className="flex items-center gap-2 text-green-400 text-sm">
                <Check size={16} /> All changes saved
              </span>
            )}
          </div>
        }
      />

      {/* Firebase Cloud Messaging (FCM) */}
      <section className="bg-[#121721] border border-zinc-800/50 rounded-2xl overflow-hidden shadow-xl">
        <div className="p-6 border-b border-zinc-800/50 flex items-center justify-between bg-zinc-800/10">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-orange-500/10 rounded-xl flex items-center justify-center">
              <Smartphone className="text-orange-400" size={24} />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">Firebase Cloud Messaging (Android)</h2>
              <p className="text-[12px] text-zinc-500">Essential for push notifications on Android devices</p>
            </div>
          </div>
          <button
            onClick={() => setFcmDraft(d => ({ ...d, fcmEnabled: !d.fcmEnabled }))}
            className={`px-5 py-2 rounded-xl text-sm font-semibold transition-all ${
              fcmDraft.fcmEnabled
                ? "bg-green-500/10 text-green-400 border border-green-500/20"
                : "bg-zinc-800/50 text-zinc-500 border border-zinc-700/50"
            }`}
          >
            {fcmDraft.fcmEnabled ? "Enabled" : "Disabled"}
          </button>
        </div>
        
        <div className="p-6 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <TextField
              label="Project ID"
              placeholder="e.g. amirani-fitness-app"
              value={fcmDraft.fcmProjectId || ""}
              onChange={(v) => setFcmDraft(d => ({ ...d, fcmProjectId: v }))}
              mono
            />
            <TextField
              label="Client Email"
              placeholder="firebase-adminsdk-xxxxx@..."
              value={fcmDraft.fcmClientEmail || ""}
              onChange={(v) => setFcmDraft(d => ({ ...d, fcmClientEmail: v }))}
              mono
            />
            <div className="md:col-span-2">
              <SecretField
                label="Private Key"
                placeholder="Paste the full private_key content from your Firebase service account JSON..."
                value={fcmDraft.fcmPrivateKey || ""}
                onChange={(v) => setFcmDraft(d => ({ ...d, fcmPrivateKey: v }))}
                rows={4}
                hint="Important: Must include BEGIN and END PRIVATE KEY markers."
              />
            </div>
          </div>
          <button
            onClick={saveFcm}
            disabled={updateMutation.isPending}
            className="w-full bg-[#F1C40F] hover:bg-[#d4ac0d] !text-black font-bold py-3 rounded-xl transition-all shadow-lg active:scale-[0.98] disabled:opacity-50"
          >
            {updateMutation.isPending ? "Applying Changes..." : "Update Firebase Settings"}
          </button>
        </div>
      </section>

      {/* Apple Push Notification Service (APNs) */}
      <section className="bg-[#121721] border border-zinc-800/50 rounded-2xl overflow-hidden shadow-xl">
        <div className="p-6 border-b border-zinc-800/50 flex items-center justify-between bg-zinc-800/10">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-blue-500/10 rounded-xl flex items-center justify-center">
              <Smartphone className="text-blue-400" size={24} />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">Apple Push Notifications (iOS)</h2>
              <p className="text-[12px] text-zinc-500">Required if sending notifications directly to Apple devices</p>
            </div>
          </div>
          <button
            onClick={() => setApnsDraft(d => ({ ...d, apnsEnabled: !d.apnsEnabled }))}
            className={`px-5 py-2 rounded-xl text-sm font-semibold transition-all ${
              apnsDraft.apnsEnabled
                ? "bg-green-500/10 text-green-400 border border-green-500/20"
                : "bg-zinc-800/50 text-zinc-500 border border-zinc-700/50"
            }`}
          >
            {apnsDraft.apnsEnabled ? "Enabled" : "Disabled"}
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <TextField
              label="Key ID"
              placeholder="ABC123DEFG"
              value={apnsDraft.apnsKeyId || ""}
              onChange={(v) => setApnsDraft(d => ({ ...d, apnsKeyId: v }))}
              mono
            />
            <TextField
              label="Team ID"
              placeholder="XYZ789HIJK"
              value={apnsDraft.apnsTeamId || ""}
              onChange={(v) => setApnsDraft(d => ({ ...d, apnsTeamId: v }))}
              mono
            />
            <TextField
              label="Bundle ID"
              placeholder="com.amirani.app"
              value={apnsDraft.apnsBundleId || ""}
              onChange={(v) => setApnsDraft(d => ({ ...d, apnsBundleId: v }))}
              mono
            />
          </div>
          
          <div className="flex items-center gap-3 bg-zinc-800/20 p-4 rounded-xl border border-zinc-800/50">
            <input
              type="checkbox"
              id="apnsProd"
              checked={apnsDraft.apnsProduction || false}
              onChange={(e) => setApnsDraft(d => ({ ...d, apnsProduction: e.target.checked }))}
              className="w-5 h-5 rounded border-zinc-700 bg-zinc-900 text-[#F1C40F] focus:ring-[#F1C40F]"
            />
            <label htmlFor="apnsProd" className="text-sm text-zinc-300 font-medium cursor-pointer select-none">
              Production Environment — Enable this for App Store builds
            </label>
          </div>

          <SecretField
            label="Private Key (.p8 content)"
            placeholder="-----BEGIN PRIVATE KEY-----&#10;...&#10;-----END PRIVATE KEY-----"
            value={apnsDraft.apnsPrivateKey || ""}
            onChange={(v) => setApnsDraft(d => ({ ...d, apnsPrivateKey: v }))}
            rows={4}
            hint="The full text content of your downloaded APNs authentication key file."
          />
          
          <button
            onClick={saveApns}
            disabled={updateMutation.isPending}
            className="w-full bg-[#F1C40F] hover:bg-[#d4ac0d] !text-black font-bold py-3 rounded-xl transition-all shadow-lg active:scale-[0.98] disabled:opacity-50"
          >
            Save APNs Configuration
          </button>
        </div>
      </section>

      {/* Email Configuration */}
      <section className="bg-[#121721] border border-zinc-800/50 rounded-2xl overflow-hidden shadow-xl">
        <div className="p-6 border-b border-zinc-800/50 flex items-center justify-between bg-zinc-800/10">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-purple-500/10 rounded-xl flex items-center justify-center">
              <Mail className="text-purple-400" size={24} />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">Email Delivery Settings</h2>
              <p className="text-[12px] text-zinc-500">Configure SMTP or SendGrid for all outgoing communications</p>
            </div>
          </div>
          <button
            onClick={() => setEmailDraft(d => ({ ...d, emailEnabled: !d.emailEnabled }))}
            className={`px-5 py-2 rounded-xl text-sm font-semibold transition-all ${
              emailDraft.emailEnabled
                ? "bg-green-500/10 text-green-400 border border-green-500/20"
                : "bg-zinc-800/50 text-zinc-500 border border-zinc-700/50"
            }`}
          >
            {emailDraft.emailEnabled ? "Active" : "Inactive"}
          </button>
        </div>

        <div className="p-6 space-y-8">
          {/* Provider Toggle */}
          <div className="grid grid-cols-2 gap-4 p-1.5 bg-zinc-900 rounded-2xl border border-zinc-800">
            <button
              onClick={() => setEmailDraft(d => ({ ...d, emailProvider: "sendgrid" }))}
              className={`py-3 rounded-xl text-sm font-bold transition-all ${
                emailDraft.emailProvider === "sendgrid"
                  ? "bg-zinc-800 text-[#F1C40F] shadow-lg"
                  : "text-zinc-500 hover:text-zinc-300"
              }`}
            >
              SendGrid API
            </button>
            <button
              onClick={() => setEmailDraft(d => ({ ...d, emailProvider: "smtp" }))}
              className={`py-3 rounded-xl text-sm font-bold transition-all ${
                emailDraft.emailProvider === "smtp"
                  ? "bg-zinc-800 text-[#F1C40F] shadow-lg"
                  : "text-zinc-500 hover:text-zinc-300"
              }`}
            >
              Custom SMTP
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <TextField
              label="Sender Name"
              placeholder="Amirani Fitness"
              value={emailDraft.fromName || ""}
              onChange={(v) => setEmailDraft(d => ({ ...d, fromName: v }))}
            />
            <TextField
              label="Sender Email Address"
              placeholder="support@yourdomain.com"
              value={emailDraft.fromEmail || ""}
              onChange={(v) => setEmailDraft(d => ({ ...d, fromEmail: v }))}
            />

            {emailDraft.emailProvider === "sendgrid" ? (
              <div className="md:col-span-2">
                <SecretField
                  label="SendGrid API Key"
                  placeholder="SG.xxxxxxxxxxxxxx..."
                  value={emailDraft.sendgridApiKey || ""}
                  onChange={(v) => setEmailDraft(d => ({ ...d, sendgridApiKey: v }))}
                  hint="Create this in the SendGrid dashboard under Settings -> API Keys"
                />
              </div>
            ) : (
              <>
                <TextField
                  label="SMTP Host"
                  placeholder="smtp.mailtrap.io"
                  value={emailDraft.smtpHost || ""}
                  onChange={(v) => setEmailDraft(d => ({ ...d, smtpHost: v }))}
                />
                <TextField
                  label="SMTP Port"
                  placeholder="587"
                  value={String(emailDraft.smtpPort || "")}
                  onChange={(v) => setEmailDraft(d => ({ ...d, smtpPort: parseInt(v) || 587 }))}
                  type="number"
                />
                <TextField
                  label="SMTP User"
                  placeholder="username / api_key"
                  value={emailDraft.smtpUser || ""}
                  onChange={(v) => setEmailDraft(d => ({ ...d, smtpUser: v }))}
                />
                <SecretField
                  label="SMTP Password"
                  placeholder="••••••••"
                  value={emailDraft.smtpPassword || ""}
                  onChange={(v) => setEmailDraft(d => ({ ...d, smtpPassword: v }))}
                />
              </>
            )}
          </div>

          <div className="flex items-center gap-3 text-xs text-zinc-500 bg-zinc-800/20 p-3 rounded-xl">
            <ShieldCheck size={16} className="text-[#F1C40F]" />
            Your secrets are encrypted at rest and never shown in the interface after saving.
          </div>

          <button
            onClick={saveEmail}
            className="w-full bg-[#F1C40F] hover:bg-[#d4ac0d] !text-black font-bold py-3 rounded-xl transition-all shadow-lg active:scale-[0.98]"
          >
            Deploy Email Configuration
          </button>
        </div>
      </section>
    </div>
  );
}
