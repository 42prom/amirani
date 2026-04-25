"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { PageHeader } from "@/components/ui/PageHeader";
import {
  Languages,
  Sparkles,
  Globe,
  CheckCircle2,
  EyeOff,
  Loader2,
  AlertCircle,
  RefreshCw,
  X,
  Pencil,
} from "lucide-react";

const PUBLISH_TIMEOUT_MS = 15_000;
const POLL_INTERVAL_MS   = 5_000;
const POLL_TIMEOUT_MS    = 90_000;

// ─── Types ────────────────────────────────────────────────────────────────────

interface LanguagePack {
  code: string;
  displayName: string;
  englishName: string;
  countryCode: string;
  version: number;
  gymCount: number;
  isPublished: boolean;
  isDraft: boolean;
}

// ─── Flag helper ──────────────────────────────────────────────────────────────

function langFlag(code: string, countryCode?: string): string {
  const country = (countryCode || langToCountry[code.toLowerCase()] || code).toUpperCase();
  if (country.length !== 2) return "🌐";
  const cp = (c: string) => 0x1f1e6 + c.charCodeAt(0) - 65;
  return String.fromCodePoint(cp(country[0]), cp(country[1]));
}

const langToCountry: Record<string, string> = {
  ka: "ge", ru: "ru", uk: "ua", de: "de", fr: "fr", es: "es",
  it: "it", pt: "pt", ar: "sa", zh: "cn", ja: "jp", ko: "kr",
  tr: "tr", pl: "pl", nl: "nl", sv: "se", no: "no", da: "dk",
  fi: "fi", cs: "cz", ro: "ro", hu: "hu", el: "gr", he: "il",
  hi: "in", th: "th", vi: "vn", id: "id", ms: "my",
};

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function LanguagePacksPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const [showGenerate, setShowGenerate] = useState(false);
  const [publishingCode, setPublishingCode] = useState<string | null>(null);

  useEffect(() => {
    if (user && !isSuperAdmin(user?.role)) router.push("/dashboard");
  }, [user, router]);

  const { data: packs, isLoading, error, refetch } = useQuery<LanguagePack[]>({
    queryKey: ["language-packs"],
    queryFn: async () => {
      const res = await api<{ packs: LanguagePack[] }>("/admin/language-packs", { token: token! });
      return res.packs;
    },
    enabled: !!token && isSuperAdmin(user?.role),
  });

  const togglePublish = useMutation({
    mutationFn: async ({ code, isPublished }: { code: string; isPublished: boolean }) => {
      setPublishingCode(code);
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), PUBLISH_TIMEOUT_MS);
      try {
        await api(`/admin/language-packs/${code}`, {
          method: "PATCH",
          body: { isPublished },
          token: token!,
        });
      } finally {
        clearTimeout(timer);
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["language-packs"] });
      setPublishingCode(null);
    },
    onError: () => setPublishingCode(null),
  });

  const published = packs?.filter((p) => p.isPublished) ?? [];
  const drafts    = packs?.filter((p) => !p.isPublished) ?? [];

  return (
    <div className="space-y-8">
      <PageHeader
        icon={<Languages size={28} />}
        title="Language Packs"
        description="Create AI-generated translation packs and publish them to Gym Owners."
        actions={
          <button
            onClick={() => setShowGenerate(true)}
            className="flex items-center gap-2 px-4 py-2.5 bg-[#F1C40F] hover:bg-[#F1C40F]/90 text-black text-sm font-bold rounded-xl transition-colors"
          >
            <Sparkles size={15} />
            Generate with AI
          </button>
        }
      />

      {/* ── Stats row ── */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: "Total Packs",   value: packs?.length ?? 0,   color: "text-white" },
          { label: "Published",     value: published.length,      color: "text-green-400" },
          { label: "Drafts",        value: drafts.length,         color: "text-orange-400" },
        ].map((s) => (
          <div key={s.label} className="bg-[#121721] border border-zinc-800 rounded-2xl p-5">
            <p className="text-xs text-zinc-500 uppercase tracking-widest font-black">{s.label}</p>
            <p className={`text-3xl font-bold mt-1 ${s.color}`}>{s.value}</p>
          </div>
        ))}
      </div>

      {/* ── Pack list ── */}
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl overflow-hidden">
        <div className="flex items-center justify-between px-6 py-4 border-b border-zinc-800">
          <h2 className="text-sm font-bold text-white uppercase tracking-widest">All Packs</h2>
          <button
            onClick={() => refetch()}
            className="p-1.5 rounded-lg hover:bg-zinc-800 text-zinc-500 hover:text-white transition-colors"
          >
            <RefreshCw size={14} />
          </button>
        </div>

        {isLoading && (
          <div className="flex items-center justify-center py-16 text-zinc-500">
            <Loader2 size={20} className="animate-spin mr-2" />
            Loading packs…
          </div>
        )}

        {error && (
          <div className="flex items-center gap-2 px-6 py-8 text-red-400">
            <AlertCircle size={16} />
            Failed to load language packs.
          </div>
        )}

        {!isLoading && !error && (!packs || packs.length === 0) && (
          <div className="flex flex-col items-center justify-center py-16 text-zinc-500 gap-3">
            <Globe size={32} className="text-zinc-700" />
            <p className="text-sm">No language packs yet.</p>
            <button
              onClick={() => setShowGenerate(true)}
              className="text-[#F1C40F] text-sm hover:underline"
            >
              Generate your first pack →
            </button>
          </div>
        )}

        {packs && packs.length > 0 && (
          <div className="divide-y divide-zinc-800/60">
            {packs.map((pack) => (
              <PackRow
                key={pack.code}
                pack={pack}
                publishing={publishingCode === pack.code}
                onToggle={() =>
                  togglePublish.mutate({ code: pack.code, isPublished: !pack.isPublished })
                }
              />
            ))}
          </div>
        )}
      </div>

      {/* ── Generate modal ── */}
      {showGenerate && (
        <GenerateModal
          token={token!}
          onClose={() => setShowGenerate(false)}
          onSuccess={() => {
            setShowGenerate(false);
            queryClient.invalidateQueries({ queryKey: ["language-packs"] });
          }}
        />
      )}
    </div>
  );
}

// ─── Pack row ─────────────────────────────────────────────────────────────────

function PackRow({
  pack,
  publishing,
  onToggle,
}: {
  pack: LanguagePack;
  publishing: boolean;
  onToggle: () => void;
}) {
  const flag = langFlag(pack.code, pack.countryCode);

  return (
    <div className="flex items-center gap-4 px-6 py-4 hover:bg-zinc-800/30 transition-colors">
      {/* Flag */}
      <span className="text-3xl leading-none w-10 text-center">{flag}</span>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-sm font-semibold text-white">{pack.displayName}</span>
          <span className="text-[10px] font-black uppercase tracking-widest text-zinc-600 bg-zinc-800 px-2 py-0.5 rounded">
            v{pack.version}
          </span>
          <span className="text-[10px] font-bold uppercase tracking-widest text-zinc-600 font-mono">
            {pack.code}
          </span>
          {pack.isDraft && (
            <span className="text-[10px] font-bold text-orange-400 bg-orange-400/10 border border-orange-400/25 px-2 py-0.5 rounded">
              Draft
            </span>
          )}
        </div>
        <p className="text-xs text-zinc-500 mt-0.5">
          {pack.englishName} · {pack.gymCount} gym{pack.gymCount !== 1 ? "s" : ""}
        </p>
      </div>

      {/* Status badge */}
      <div className="flex items-center gap-1.5 mr-2">
        {pack.isPublished ? (
          <span className="flex items-center gap-1 text-xs text-green-400">
            <CheckCircle2 size={12} /> Published
          </span>
        ) : (
          <span className="flex items-center gap-1 text-xs text-zinc-500">
            <EyeOff size={12} /> Unpublished
          </span>
        )}
      </div>

      {/* Edit button */}
      <Link
        href={`/dashboard/language-packs/${pack.code}`}
        className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-zinc-500 hover:text-white border border-zinc-700 hover:border-zinc-600 rounded-xl transition-colors"
      >
        <Pencil size={12} />
        Edit
      </Link>

      {/* Toggle button */}
      <button
        onClick={onToggle}
        disabled={publishing}
        className={`px-4 py-1.5 rounded-xl text-xs font-bold transition-colors border ${
          pack.isPublished
            ? "border-red-500/30 text-red-400 hover:bg-red-500/10"
            : "border-[#F1C40F]/40 text-[#F1C40F] hover:bg-[#F1C40F]/10"
        } disabled:opacity-40`}
      >
        {publishing ? (
          <Loader2 size={12} className="animate-spin" />
        ) : pack.isPublished ? (
          "Unpublish"
        ) : (
          "Publish"
        )}
      </button>
    </div>
  );
}

// ─── Generate modal ───────────────────────────────────────────────────────────

type GeneratePhase = "form" | "polling" | "done";

function GenerateModal({
  token,
  onClose,
  onSuccess,
}: {
  token: string;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const [name, setName]       = useState("");
  const [code, setCode]       = useState("");
  const [country, setCountry] = useState("");
  const [phase, setPhase]     = useState<GeneratePhase>("form");
  const [error, setError]     = useState<string | null>(null);
  const [elapsed, setElapsed] = useState(0);

  const pollRef    = useRef<ReturnType<typeof setInterval> | null>(null);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const tickRef    = useRef<ReturnType<typeof setInterval> | null>(null);
  const targetCode = useRef("");

  const stopPolling = () => {
    if (pollRef.current)    clearInterval(pollRef.current);
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    if (tickRef.current)    clearInterval(tickRef.current);
  };

  useEffect(() => () => stopPolling(), []);

  const startPolling = (langCode: string) => {
    targetCode.current = langCode;
    setPhase("polling");
    setElapsed(0);

    tickRef.current = setInterval(() => setElapsed(s => s + 1), 1000);

    pollRef.current = setInterval(async () => {
      try {
        const res = await api<{ packs: LanguagePack[] }>("/admin/language-packs", { token });
        const found = res.packs.find(p => p.code === targetCode.current);
        if (found) {
          stopPolling();
          setPhase("done");
          setTimeout(onSuccess, 800);
        }
      } catch {
        // ignore transient poll errors
      }
    }, POLL_INTERVAL_MS);

    timeoutRef.current = setTimeout(() => {
      stopPolling();
      setPhase("form");
      setError("Generation is taking longer than expected. Check the pack list in a moment — it may still appear.");
    }, POLL_TIMEOUT_MS);
  };

  const previewFlag = langFlag(code, country);
  const canSubmit   = phase === "form" && name.trim() && code.trim().length >= 2;

  async function handleGenerate() {
    setError(null);
    const langCode = code.trim().toLowerCase();
    try {
      await api("/admin/language-packs/ai-generate", {
        method: "POST",
        body: {
          targetLanguage: name.trim(),
          languageCode:   langCode,
          countryCode:    country.trim().toLowerCase(),
        },
        token,
      });
      startPolling(langCode);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Generation failed. Check the language code and try again.");
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl w-full max-w-md shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-zinc-800">
          <div className="flex items-center gap-3">
            <Sparkles size={18} className="text-[#F1C40F]" />
            <h2 className="text-base font-bold text-white">Generate Language Pack</h2>
          </div>
          {phase === "form" && (
            <button onClick={onClose} className="text-zinc-500 hover:text-white transition-colors">
              <X size={18} />
            </button>
          )}
        </div>

        <div className="p-6 space-y-5">
          {/* Polling state */}
          {phase === "polling" && (
            <div className="flex flex-col items-center gap-4 py-6">
              <Loader2 size={36} className="animate-spin text-[#F1C40F]" />
              <div className="text-center">
                <p className="text-sm font-bold text-white">AI is generating your pack…</p>
                <p className="text-xs text-zinc-500 mt-1">
                  Translating all app strings into {name}. This usually takes 20–60 seconds.
                </p>
              </div>
              <div className="flex items-center gap-1.5 text-xs text-zinc-600 font-mono">
                <RefreshCw size={11} className="animate-spin" />
                {elapsed}s elapsed · checking every 5s
              </div>
            </div>
          )}

          {/* Done state */}
          {phase === "done" && (
            <div className="flex flex-col items-center gap-3 py-6">
              <span className="text-5xl">{previewFlag}</span>
              <p className="text-sm font-bold text-green-400">Pack created successfully!</p>
              <p className="text-xs text-zinc-500">Redirecting…</p>
            </div>
          )}

          {/* Form state */}
          {phase === "form" && (
            <>
              <div className="flex justify-center">
                <span className="text-6xl">{previewFlag}</span>
              </div>

              <Field label="Language Name" placeholder="e.g. Georgian" value={name} onChange={setName} />

              <div className="grid grid-cols-2 gap-3">
                <Field label="Language Code" placeholder="e.g. ka" value={code} onChange={v => setCode(v.toLowerCase())} />
                <Field label="Country Code"  placeholder="e.g. ge" value={country} onChange={v => setCountry(v.toLowerCase())} />
              </div>

              <p className="text-xs text-zinc-500">
                AI translates all app strings. The pack is saved as a draft — you can review and publish it when ready.
              </p>

              {error && (
                <div className="flex items-center gap-2 text-red-400 text-xs bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">
                  <AlertCircle size={14} />
                  {error}
                </div>
              )}

              <button
                onClick={handleGenerate}
                disabled={!canSubmit}
                className="w-full flex items-center justify-center gap-2 py-3 bg-[#F1C40F] hover:bg-[#F1C40F]/90 disabled:opacity-40 text-black text-sm font-bold rounded-xl transition-colors"
              >
                <Sparkles size={15} />
                Generate Pack
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Field ────────────────────────────────────────────────────────────────────

function Field({
  label,
  placeholder,
  value,
  onChange,
}: {
  label: string;
  placeholder: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="space-y-1.5">
      <label className="text-[11px] font-black uppercase tracking-widest text-zinc-500">{label}</label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full bg-zinc-900 border border-zinc-700 rounded-xl px-4 py-2.5 text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/60 transition-colors"
      />
    </div>
  );
}
