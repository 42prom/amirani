"use client";

import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { platformApi, OAuthConfig } from "@/lib/api";
import { useState } from "react";
import { KeyRound, RefreshCw, Check, Eye, EyeOff, Apple } from "lucide-react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/ui/PageHeader";

// ─── Google Icon SVG ──────────────────────────────────────────────────────────

function GoogleIcon({ size = 20 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
    </svg>
  );
}

// ─── Masked input helper ──────────────────────────────────────────────────────

function SecretField({
  label,
  placeholder,
  value,
  onChange,
  hint,
}: {
  label: string;
  placeholder: string;
  value: string;
  onChange: (v: string) => void;
  hint?: string;
}) {
  const [show, setShow] = useState(false);
  const isMasked = value === "••••••••";

  return (
    <div>
      <label className="block text-sm font-medium text-zinc-300 mb-1">{label}</label>
      <div className="relative">
        <input
          type={show ? "text" : "password"}
          value={isMasked ? "" : value}
          placeholder={isMasked ? "Already set — enter new value to replace" : placeholder}
          onChange={(e) => onChange(e.target.value)}
          className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2.5 text-white text-sm placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/60 pr-10"
        />
        <button
          type="button"
          onClick={() => setShow(!show)}
          className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-zinc-300"
        >
          {show ? <EyeOff size={15} /> : <Eye size={15} />}
        </button>
      </div>
      {hint && <p className="text-xs text-zinc-600 mt-1">{hint}</p>}
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
}: {
  label: string;
  placeholder: string;
  value: string;
  onChange: (v: string) => void;
  hint?: string;
  mono?: boolean;
}) {
  return (
    <div>
      <label className="block text-sm font-medium text-zinc-300 mb-1">{label}</label>
      <input
        type="text"
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className={`w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2.5 text-white text-sm placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/60 ${mono ? "font-mono" : ""}`}
      />
      {hint && <p className="text-xs text-zinc-600 mt-1">{hint}</p>}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function OAuthConfigPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved">("idle");

  // Local draft state — mirrors the DB config
  const [googleDraft, setGoogleDraft] = useState<Partial<OAuthConfig>>({});
  const [appleDraft,  setAppleDraft]  = useState<Partial<OAuthConfig>>({});

  const { data: dataConfig, isLoading, error } = useQuery({
    queryKey: ["oauth-config"],
    queryFn: () => platformApi.getOAuthConfig(token!),
    enabled: !!token && isSuperAdmin(user?.role),
  });

  // Sync draft from query data
  const [isInitialized, setIsInitialized] = useState(false);

  if (dataConfig && !isInitialized) {
    setGoogleDraft({
      googleEnabled:      dataConfig.googleEnabled,
      googleClientId:     dataConfig.googleClientId     ?? "",
      googleClientSecret: dataConfig.googleClientSecret ?? "",
    });
    setAppleDraft({
      appleEnabled:    dataConfig.appleEnabled,
      appleClientId:   dataConfig.appleClientId   ?? "",
      appleTeamId:     dataConfig.appleTeamId     ?? "",
      appleKeyId:      dataConfig.appleKeyId      ?? "",
      applePrivateKey: dataConfig.applePrivateKey ?? "",
    });
    setIsInitialized(true);
  }

  const updateMutation = useMutation({
    mutationFn: (data: Partial<OAuthConfig>) =>
      platformApi.updateOAuthConfig(data, token!),
    onMutate: () => setSaveStatus("saving"),
    onSuccess: (updatedData: OAuthConfig) => {
      queryClient.invalidateQueries({ queryKey: ["oauth-config"] });
      // Update local state immediately with returned (possibly masked) data
      if (updatedData.googleClientId !== undefined) {
         setGoogleDraft({
           googleEnabled:      updatedData.googleEnabled,
           googleClientId:     updatedData.googleClientId     ?? "",
           googleClientSecret: updatedData.googleClientSecret ?? "",
         });
      }
      if (updatedData.appleClientId !== undefined) {
        setAppleDraft({
          appleEnabled:    updatedData.appleEnabled,
          appleClientId:   updatedData.appleClientId   ?? "",
          appleTeamId:     updatedData.appleTeamId     ?? "",
          appleKeyId:      updatedData.appleKeyId      ?? "",
          applePrivateKey: updatedData.applePrivateKey ?? "",
        });
      }
      setSaveStatus("saved");
      setTimeout(() => setSaveStatus("idle"), 2000);
    },
    onError: () => setSaveStatus("idle"),
  });

  const saveGoogle = () => updateMutation.mutate(googleDraft);
  const saveApple  = () => updateMutation.mutate(appleDraft);

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
      <div className="bg-red-500/10 border border-red-500/50 rounded-xl p-4 text-red-400">
        Failed to load OAuth configuration
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="OAuth / Social Login Configuration"
        description="Configure Google and Apple sign-in for the mobile app"
        icon={<KeyRound size={24} />}
        actions={
          <div className="flex items-center gap-2 text-sm">
            {saveStatus === "saving" && (
              <span className="flex items-center gap-2 text-zinc-400">
                <RefreshCw className="animate-spin" size={14} /> Saving…
              </span>
            )}
            {saveStatus === "saved" && (
              <span className="flex items-center gap-2 text-green-400">
                <Check size={14} /> Saved
              </span>
            )}
          </div>
        }
      />

      {/* ── Google ─────────────────────────────────────────────────────── */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6 space-y-5">
        {/* Provider header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-white/5 rounded-lg flex items-center justify-center">
              <GoogleIcon size={20} />
            </div>
            <div>
              <h2 className="text-base font-semibold text-white">Google Sign-In</h2>
              <p className="text-xs text-zinc-500">OAuth 2.0 — Google Cloud Console</p>
            </div>
          </div>
          <button
            onClick={() => setGoogleDraft((d) => ({ ...d, googleEnabled: !d.googleEnabled }))}
            className={`px-4 py-1.5 rounded-lg text-sm font-medium transition-colors ${
              googleDraft.googleEnabled
                ? "bg-green-500/10 text-green-400 border border-green-500/30"
                : "bg-zinc-800 text-zinc-400 border border-zinc-700"
            }`}
          >
            {googleDraft.googleEnabled ? "Enabled" : "Disabled"}
          </button>
        </div>

        <div className="grid grid-cols-1 gap-4">
          <TextField
            label="Client ID"
            placeholder="xxxxxx.apps.googleusercontent.com"
            value={googleDraft.googleClientId ?? ""}
            onChange={(v) => setGoogleDraft((d) => ({ ...d, googleClientId: v }))}
            hint="Found in Google Cloud Console → APIs & Services → Credentials"
            mono
          />
          <SecretField
            label="Client Secret"
            placeholder="GOCSPX-…"
            value={googleDraft.googleClientSecret ?? ""}
            onChange={(v) => setGoogleDraft((d) => ({ ...d, googleClientSecret: v }))}
            hint="Keep this secret — never expose it in client code"
          />
        </div>

        <div className="bg-blue-500/5 border border-blue-500/20 rounded-lg p-3 text-xs text-blue-300 space-y-1">
          <p className="font-semibold">Setup checklist</p>
          <ul className="list-disc list-inside space-y-0.5 text-blue-300/80">
            <li>Create a project in Google Cloud Console</li>
            <li>Enable the <span className="font-mono">People API</span></li>
            <li>Add an <strong>Android OAuth 2.0 Client ID</strong> (SHA-1 of your keystore)</li>
            <li>Add an <strong>iOS OAuth 2.0 Client ID</strong> (bundle ID)</li>
            <li>Paste the <strong>Web client ID</strong> here (used for server-side token verification)</li>
          </ul>
        </div>

        <button
          onClick={saveGoogle}
          disabled={updateMutation.isPending}
          className="w-full py-2.5 rounded-lg bg-[#F1C40F] !text-black font-semibold text-sm hover:bg-[#d4ac0d] transition-colors disabled:opacity-50"
        >
          {updateMutation.isPending ? "Saving…" : "Save Google Config"}
        </button>
      </div>

      {/* ── Apple ──────────────────────────────────────────────────────── */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6 space-y-5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-white/5 rounded-lg flex items-center justify-center">
              <Apple className="text-white" size={20} />
            </div>
            <div>
              <h2 className="text-base font-semibold text-white">Sign in with Apple</h2>
              <p className="text-xs text-zinc-500">Apple Developer Portal — Keys section</p>
            </div>
          </div>
          <button
            onClick={() => setAppleDraft((d) => ({ ...d, appleEnabled: !d.appleEnabled }))}
            className={`px-4 py-1.5 rounded-lg text-sm font-medium transition-colors ${
              appleDraft.appleEnabled
                ? "bg-green-500/10 text-green-400 border border-green-500/30"
                : "bg-zinc-800 text-zinc-400 border border-zinc-700"
            }`}
          >
            {appleDraft.appleEnabled ? "Enabled" : "Disabled"}
          </button>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <TextField
            label="Client ID (Bundle ID / Services ID)"
            placeholder="ge.esme.amirani"
            value={appleDraft.appleClientId ?? ""}
            onChange={(v) => setAppleDraft((d) => ({ ...d, appleClientId: v }))}
            hint="Your app's bundle ID (iOS) or Services ID (web)"
            mono
          />
          <TextField
            label="Team ID"
            placeholder="XXXXXXXXXX"
            value={appleDraft.appleTeamId ?? ""}
            onChange={(v) => setAppleDraft((d) => ({ ...d, appleTeamId: v }))}
            hint="10-character Apple Developer Team ID"
            mono
          />
          <TextField
            label="Key ID"
            placeholder="XXXXXXXXXX"
            value={appleDraft.appleKeyId ?? ""}
            onChange={(v) => setAppleDraft((d) => ({ ...d, appleKeyId: v }))}
            hint="Key ID from Apple Developer Portal → Keys"
            mono
          />
        </div>
        <SecretField
          label="Private Key (.p8 file content)"
          placeholder="-----BEGIN PRIVATE KEY-----\nMIGH…\n-----END PRIVATE KEY-----"
          value={appleDraft.applePrivateKey ?? ""}
          onChange={(v) => setAppleDraft((d) => ({ ...d, applePrivateKey: v }))}
          hint="Paste the full contents of your AuthKey_XXXXXXXXXX.p8 file"
        />

        <div className="bg-zinc-800/40 border border-zinc-700/50 rounded-lg p-3 text-xs text-zinc-400 space-y-1">
          <p className="font-semibold text-zinc-300">Setup checklist</p>
          <ul className="list-disc list-inside space-y-0.5">
            <li>Enable <strong>Sign in with Apple</strong> capability in Xcode</li>
            <li>In Apple Developer Portal → Certificates → Identifiers: enable Sign In with Apple</li>
            <li>Create a key with Sign In with Apple enabled — download the <span className="font-mono">.p8</span> file</li>
            <li>Paste the key content above — note: Apple only lets you download it once</li>
          </ul>
        </div>

        <button
          onClick={saveApple}
          disabled={updateMutation.isPending}
          className="w-full py-2.5 rounded-lg bg-[#F1C40F] !text-black font-semibold text-sm hover:bg-[#d4ac0d] transition-colors disabled:opacity-50"
        >
          {updateMutation.isPending ? "Saving…" : "Save Apple Config"}
        </button>
      </div>
    </div>
  );
}
