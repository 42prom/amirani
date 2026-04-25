"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation } from "@tanstack/react-query";
import {
  Building2, CreditCard, Globe, Dumbbell,
  Users, Bell, PartyPopper, CheckCircle2,
  ChevronRight, ChevronLeft, ExternalLink,
  Copy, Loader2, BadgeCheck, Sparkles,
  AlertCircle, Zap, QrCode,
} from "lucide-react";
import { gymsApi, gymOwnerApi, adminApi } from "@/lib/api";
import type { CreateEnhancedPlanData } from "@/lib/api";

// ─── localStorage helpers ─────────────────────────────────────────────────────

const storageKey = (userId: string) => `amirani_onboarding_v1_${userId}`;

function loadCompleted(userId: string): Set<number> {
  if (typeof window === "undefined") return new Set();
  try {
    const raw = localStorage.getItem(storageKey(userId));
    if (!raw) return new Set();
    return new Set((JSON.parse(raw).completed ?? []) as number[]);
  } catch { return new Set(); }
}

function saveCompleted(userId: string, completed: Set<number>) {
  if (typeof window === "undefined") return;
  localStorage.setItem(
    storageKey(userId),
    JSON.stringify({ completed: Array.from(completed), updatedAt: new Date().toISOString() })
  );
}

export function isOnboardingDone(userId: string): boolean {
  return loadCompleted(userId).has(7);
}

// ─── Step metadata ────────────────────────────────────────────────────────────

const STEPS = [
  { Icon: Building2,   label: "Business",      title: "Your Business Info",    skippable: false },
  { Icon: CreditCard,  label: "Billing",       title: "Billing Setup",         skippable: true  },
  { Icon: Globe,       label: "Language",      title: "Member Language",       skippable: true  },
  { Icon: CreditCard,  label: "Plans",         title: "Membership Plans",      skippable: false },
  { Icon: Dumbbell,    label: "Exercises",     title: "Exercise Library",      skippable: true  },
  { Icon: Users,       label: "Trainers",      title: "Invite a Trainer",      skippable: true  },
  { Icon: Bell,        label: "Notifications", title: "Push Notifications",    skippable: true  },
  { Icon: PartyPopper, label: "Launch",        title: "You’re Ready!",    skippable: false },
] as const;

// ─── Shared input component ───────────────────────────────────────────────────

const inputCls =
  "w-full bg-black/30 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F1C40F]/50 text-sm transition-colors";
const labelCls =
  "block text-[10px] text-white/50 uppercase font-black tracking-widest mb-2";

function Field({
  label, value, onChange, placeholder, type = "text", rows,
}: {
  label: string; value: string;
  onChange: (v: string) => void;
  placeholder?: string; type?: string; rows?: number;
}) {
  if (rows) {
    return (
      <div>
        <label className={labelCls}>{label}</label>
        <textarea
          value={value} onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder} rows={rows}
          className={inputCls + " resize-none"}
        />
      </div>
    );
  }
  return (
    <div>
      <label className={labelCls}>{label}</label>
      <input
        type={type} value={value} onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder} className={inputCls}
      />
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function OnboardingPage() {
  const { user, token } = useAuthStore();
  const router = useRouter();

  const [step, setStep] = useState(0);
  const [completed, setCompleted] = useState<Set<number>>(new Set());
  const [err, setErr] = useState("");
  const [copied, setCopied] = useState(false);

  // Forms
  const [biz, setBiz] = useState({ name: "", address: "", city: "", country: "", phone: "", description: "" });
  const [plan, setPlan] = useState({ name: "Monthly Membership", price: "50", duration: "1", description: "" });
  const [trainer, setTrainer] = useState({ fullName: "", email: "", password: "" });

  // Hydrate from localStorage
  useEffect(() => {
    if (user?.id) setCompleted(loadCompleted(user.id));
  }, [user?.id]);

  // Gym data
  const { data: gyms } = useQuery({
    queryKey: ["my-gyms"],
    queryFn: () => gymsApi.getAll(token!),
    enabled: !!token,
  });
  const gym = gyms?.[0];
  const gymId = gym?.id;

  // Pre-fill from gym
  useEffect(() => {
    if (!gym) return;
    setBiz({
      name: gym.name ?? "",
      address: gym.address ?? "",
      city: gym.city ?? "",
      country: gym.country ?? "",
      phone: gym.phone ?? "",
      description: gym.description ?? "",
    });
  }, [gym?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  // Stripe status (only fetched when on step 1)
  const { data: stripeStatus } = useQuery({
    queryKey: ["stripe-status", gymId],
    queryFn: () => gymOwnerApi.getStripeStatus(gymId!, token!),
    enabled: !!gymId && !!token && step === 1,
  });

  // QR code (only fetched on final step)
  const { data: qrData } = useQuery({
    queryKey: ["reg-qr", gymId],
    queryFn: () => gymsApi.getRegistrationQr(gymId!, token!),
    enabled: !!gymId && !!token && step === 7,
  });

  // Mutations
  const updateGym = useMutation({
    mutationFn: (d: Record<string, unknown>) => gymsApi.update(gymId!, d as any, token!),
  });
  const createPlan = useMutation({
    mutationFn: (d: CreateEnhancedPlanData) => gymOwnerApi.createPlan(gymId!, d, token!),
  });
  const inviteTrainer = useMutation({
    mutationFn: (d: { fullName: string; email: string; password: string }) =>
      adminApi.createTrainer({ ...d, gymId: gymId! }, token!),
  });
  const stripeOnboard = useMutation({
    mutationFn: () => gymOwnerApi.startStripeOnboarding(
      gymId!,
      `${window.location.origin}/dashboard/onboarding?step=2`,
      `${window.location.origin}/dashboard/onboarding?step=1`,
      token!
    ),
    onSuccess: (d) => { if (d.url) window.location.href = d.url; },
  });

  const isLoading = updateGym.isPending || createPlan.isPending ||
    inviteTrainer.isPending || stripeOnboard.isPending;

  // ─── Navigation helpers ───────────────────────────────────────────��───────────

  const advance = (idx: number = step) => {
    const next = new Set(completed);
    next.add(idx);
    setCompleted(next);
    if (user?.id) saveCompleted(user.id, next);
    setErr("");
    if (idx < STEPS.length - 1) setStep(idx + 1);
  };

  const skip = () => { setErr(""); setStep(s => Math.min(s + 1, STEPS.length - 1)); };
  const back = () => { setErr(""); setStep(s => Math.max(s - 1, 0)); };

  // ─── Per-step action handlers ─────────────────────────────────────────────────

  const handleContinue = async () => {
    setErr("");
    try {
      switch (step) {
        case 0: {
          if (!biz.name.trim()) { setErr("Gym name is required."); return; }
          if (gymId) await updateGym.mutateAsync({
            name: biz.name, address: biz.address, city: biz.city,
            country: biz.country, phone: biz.phone || undefined,
            description: biz.description || undefined,
          });
          advance(); break;
        }
        case 3: {
          const price = parseFloat(plan.price);
          const dur   = parseInt(plan.duration);
          if (!plan.name || isNaN(price)) { setErr("Name and price are required."); return; }
          if (gymId) await createPlan.mutateAsync({
            name: plan.name, price,
            durationValue: isNaN(dur) ? 1 : dur,
            durationUnit: "MONTHS",
            description: plan.description || undefined,
          });
          advance(); break;
        }
        case 5: {
          if (trainer.fullName && trainer.email && trainer.password) {
            if (gymId) await inviteTrainer.mutateAsync(trainer);
          }
          advance(); break;
        }
        default:
          advance();
      }
    } catch (e: any) {
      setErr(e.message ?? "Something went wrong.");
    }
  };

  const finish = () => {
    advance(7);
    router.push("/dashboard");
  };

  // ─── Step content ─────────────────────────────────────────────────────────────

  function renderStep() {
    switch (step) {
      case 0:
        return (
          <div className="space-y-4">
            <p className="text-zinc-400 text-sm">Confirm your gym details — these appear on your member-facing registration page.</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Field label="Gym Name" value={biz.name} onChange={v => setBiz(p => ({ ...p, name: v }))} placeholder="My Gym" />
              <Field label="City" value={biz.city} onChange={v => setBiz(p => ({ ...p, city: v }))} placeholder="Tbilisi" />
              <Field label="Address" value={biz.address} onChange={v => setBiz(p => ({ ...p, address: v }))} placeholder="123 Main St" />
              <Field label="Country (2-letter)" value={biz.country} onChange={v => setBiz(p => ({ ...p, country: v }))} placeholder="GE" />
              <Field label="Phone" value={biz.phone} onChange={v => setBiz(p => ({ ...p, phone: v }))} placeholder="+995 555 000 000" />
            </div>
            <Field label="Description" value={biz.description} onChange={v => setBiz(p => ({ ...p, description: v }))} placeholder="Tell members about your gym..." rows={3} />
          </div>
        );

      case 1:
        return (
          <div className="space-y-6">
            <p className="text-zinc-400 text-sm">Connect Stripe to accept online payments. You can skip and connect later from the Billing page.</p>
            {stripeStatus?.onboardingComplete ? (
              <div className="flex items-center gap-4 p-5 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl">
                <BadgeCheck size={32} className="text-emerald-400 flex-shrink-0" />
                <div>
                  <p className="text-white font-bold">Stripe Connected</p>
                  <p className="text-zinc-400 text-sm mt-0.5">Members can pay online. Revenue flows to your account.</p>
                </div>
              </div>
            ) : (
              <div className="space-y-4">
                <div className="p-5 bg-white/[0.03] border border-zinc-800 rounded-2xl">
                  <p className="text-white/60 text-sm">No Stripe account connected yet.</p>
                  <p className="text-white/30 text-xs mt-1">You&apos;ll be redirected to Stripe to complete setup.</p>
                </div>
                <button
                  onClick={() => stripeOnboard.mutate()}
                  disabled={!gymId || stripeOnboard.isPending}
                  className="flex items-center gap-2 px-6 py-3 bg-[#F1C40F] hover:bg-[#D4AC0D] text-black font-bold rounded-xl transition-all disabled:opacity-50 text-sm uppercase tracking-widest"
                >
                  {stripeOnboard.isPending ? <Loader2 size={16} className="animate-spin" /> : <ExternalLink size={16} />}
                  Connect Stripe
                </button>
              </div>
            )}
          </div>
        );

      case 2:
        return (
          <div className="space-y-6">
            <p className="text-zinc-400 text-sm">Choose a second language for your members. English is always the default and fallback.</p>
            <div className="p-5 bg-[#F1C40F]/5 border border-[#F1C40F]/20 rounded-2xl space-y-3">
              <div className="flex items-start gap-3">
                <Sparkles size={18} className="text-[#F1C40F] mt-0.5 flex-shrink-0" />
                <p className="text-white/70 text-sm">Language packs are managed in the Language Packs section. Once published, your approved members can switch to it in-app.</p>
              </div>
            </div>
            <div className="p-5 bg-white/[0.03] border border-zinc-800 rounded-2xl space-y-3">
              <p className="text-xs text-zinc-500 uppercase font-bold tracking-widest">Available now</p>
              <div className="flex flex-wrap gap-2">
                {["🇬🇧 English (default)", "🇬🇪 Georgian", "🇷🇺 Russian"].map(l => (
                  <span key={l} className="px-3 py-1.5 bg-white/5 border border-white/10 rounded-full text-xs text-white/70">{l}</span>
                ))}
              </div>
            </div>
            <button onClick={() => router.push("/dashboard/language-packs")} className="flex items-center gap-2 text-[#F1C40F] text-sm font-bold hover:underline">
              <ExternalLink size={13} /> Manage Language Packs
            </button>
          </div>
        );

      case 3:
        return (
          <div className="space-y-4">
            <p className="text-zinc-400 text-sm">Create your first plan. You can add more pricing tiers later from the Plans page.</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Field label="Plan Name" value={plan.name} onChange={v => setPlan(p => ({ ...p, name: v }))} placeholder="Monthly Membership" />
              <Field label="Price (USD)" value={plan.price} onChange={v => setPlan(p => ({ ...p, price: v }))} placeholder="50" type="number" />
              <Field label="Duration (months)" value={plan.duration} onChange={v => setPlan(p => ({ ...p, duration: v }))} placeholder="1" type="number" />
            </div>
            <Field label="Description (optional)" value={plan.description} onChange={v => setPlan(p => ({ ...p, description: v }))} placeholder="Full gym access, unlimited classes..." rows={2} />
          </div>
        );

      case 4:
        return (
          <div className="space-y-6">
            <p className="text-zinc-400 text-sm">Your exercise library is pre-loaded and ready. Browse and extend it from the Exercise Database.</p>
            <div className="grid grid-cols-2 gap-4">
              {[
                { label: "Push", count: "40+", detail: "Bench, push-ups, dips..." },
                { label: "Pull", count: "35+", detail: "Pull-ups, rows, cables..." },
                { label: "Lower body", count: "45+", detail: "Squats, deadlifts..." },
                { label: "Core & Cardio", count: "30+", detail: "Plank, HIIT, crunches..." },
              ].map(item => (
                <div key={item.label} className="p-4 bg-white/[0.03] border border-zinc-800 rounded-xl">
                  <div className="flex items-center justify-between">
                    <p className="text-white text-sm font-bold">{item.label}</p>
                    <span className="text-[#F1C40F] font-black">{item.count}</span>
                  </div>
                  <p className="text-zinc-500 text-xs mt-1">{item.detail}</p>
                </div>
              ))}
            </div>
            <button onClick={() => router.push("/dashboard/exercise-database")} className="flex items-center gap-2 text-[#F1C40F] text-sm font-bold hover:underline">
              <ExternalLink size={13} /> Open Exercise Database
            </button>
          </div>
        );

      case 5:
        return (
          <div className="space-y-4">
            <p className="text-zinc-400 text-sm">Add your first trainer. They can log in immediately and start building workout plans. Skip if you&apos;re adding trainers later.</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Field label="Full Name" value={trainer.fullName} onChange={v => setTrainer(p => ({ ...p, fullName: v }))} placeholder="John Smith" />
              <Field label="Email" value={trainer.email} onChange={v => setTrainer(p => ({ ...p, email: v }))} placeholder="trainer@mygym.com" type="email" />
              <div className="sm:col-span-2">
                <Field label="Temporary Password" value={trainer.password} onChange={v => setTrainer(p => ({ ...p, password: v }))} placeholder="Min 8 characters" type="password" />
              </div>
            </div>
          </div>
        );

      case 6:
        return (
          <div className="space-y-4">
            <p className="text-zinc-400 text-sm">Set up FCM push notifications so your members receive reminders and achievements.</p>
            {[
              { n: "1", text: "Go to console.firebase.google.com and create or select your project." },
              { n: "2", text: "Navigate to Project Settings → Cloud Messaging tab." },
              { n: "3", text: "Copy your Server Key (legacy) or generate a new service account JSON." },
              { n: "4", text: "Paste it in Amirani Admin → Platform → Push Notification Config." },
            ].map(s => (
              <div key={s.n} className="flex items-start gap-3 p-4 bg-white/[0.03] border border-zinc-800 rounded-xl">
                <span className="w-6 h-6 rounded-full bg-[#F1C40F]/15 text-[#F1C40F] text-[10px] font-black flex items-center justify-center flex-shrink-0 mt-0.5">{s.n}</span>
                <p className="text-white/60 text-sm">{s.text}</p>
              </div>
            ))}
            <button onClick={() => router.push("/dashboard/platform")} className="flex items-center gap-2 text-[#F1C40F] text-sm font-bold hover:underline">
              <ExternalLink size={13} /> Go to Platform Config
            </button>
          </div>
        );

      case 7:
        return (
          <div className="space-y-6 text-center">
            <div className="flex justify-center">
              <div className="w-20 h-20 bg-[#F1C40F] rounded-2xl flex items-center justify-center shadow-[0_0_40px_rgba(241,196,15,0.4)] rotate-3">
                <PartyPopper size={40} className="text-black" />
              </div>
            </div>
            <div>
              <h3 className="text-white font-black text-2xl">Your gym is live!</h3>
              <p className="text-zinc-400 text-sm mt-2">Share this QR code so members can register to your gym instantly.</p>
            </div>
            {qrData ? (
              <div className="flex flex-col items-center gap-4">
                <div className="p-4 bg-white rounded-2xl inline-flex">
                  <QrCode size={100} className="text-black" />
                </div>
                <div className="flex items-center gap-3 bg-white/5 border border-white/10 rounded-xl px-4 py-3 w-full max-w-sm text-left">
                  <code className="text-[#F1C40F] text-xs flex-1 truncate">{qrData.qrContent}</code>
                  <button
                    onClick={() => {
                      navigator.clipboard.writeText(qrData.qrContent);
                      setCopied(true);
                      setTimeout(() => setCopied(false), 2000);
                    }}
                    className="text-zinc-400 hover:text-white transition-colors flex-shrink-0"
                  >
                    {copied ? <CheckCircle2 size={16} className="text-emerald-400" /> : <Copy size={16} />}
                  </button>
                </div>
              </div>
            ) : (
              <div className="flex justify-center py-4">
                <Loader2 size={24} className="animate-spin text-[#F1C40F]" />
              </div>
            )}
          </div>
        );

      default: return null;
    }
  }

  if (!user) return null;

  return (
    <div className="min-h-screen bg-[#0A0E17] flex flex-col">
      {/* Top bar */}
      <div className="border-b border-zinc-800/50 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-[#F1C40F] rounded-lg flex items-center justify-center">
            <Zap size={16} className="text-black" />
          </div>
          <span className="text-white font-black text-sm uppercase tracking-widest">Gym Setup Wizard</span>
        </div>
        <button
          onClick={() => router.push("/dashboard")}
          className="text-zinc-500 hover:text-zinc-300 text-xs uppercase tracking-widest transition-colors"
        >
          Skip setup →
        </button>
      </div>

      <div className="flex-1 flex flex-col items-center py-10 px-4">
        <div className="w-full max-w-2xl space-y-6">
          {/* Step rail */}
          <div className="flex items-center gap-1 overflow-x-auto pb-2">
            {STEPS.map(({ Icon, label }, i) => {
              const done = completed.has(i);
              const active = step === i;
              return (
                <div key={i} className="flex items-center gap-1 min-w-0">
                  <button
                    onClick={() => i <= step && setStep(i)}
                    disabled={i > step && !done}
                    className="flex flex-col items-center gap-1 disabled:cursor-default"
                  >
                    <div className={`w-9 h-9 rounded-xl flex items-center justify-center transition-all ${
                      done    ? "bg-emerald-500/20 border border-emerald-500/40" :
                      active  ? "bg-[#F1C40F] shadow-[0_0_20px_rgba(241,196,15,0.35)]" :
                                "bg-white/5 border border-white/10"
                    }`}>
                      {done
                        ? <CheckCircle2 size={16} className="text-emerald-400" />
                        : <Icon size={16} className={active ? "text-black" : "text-zinc-500"} />
                      }
                    </div>
                    <span className={`text-[9px] uppercase font-black tracking-widest hidden sm:block ${
                      active ? "text-[#F1C40F]" : done ? "text-emerald-400" : "text-zinc-600"
                    }`}>{label}</span>
                  </button>
                  {i < STEPS.length - 1 && (
                    <div className={`h-px flex-1 min-w-[8px] transition-colors ${done ? "bg-emerald-500/30" : "bg-white/5"}`} />
                  )}
                </div>
              );
            })}
          </div>

          {/* Card */}
          <div className="bg-[#121721] border border-zinc-800 rounded-2xl overflow-hidden">
            {/* Card header */}
            <div className="px-7 py-5 border-b border-zinc-800/60 flex items-center gap-4">
              {(() => {
                const { Icon } = STEPS[step];
                return (
                  <div className="w-10 h-10 bg-[#F1C40F]/10 border border-[#F1C40F]/20 rounded-xl flex items-center justify-center flex-shrink-0">
                    <Icon size={20} className="text-[#F1C40F]" />
                  </div>
                );
              })()}
              <div>
                <p className="text-[9px] text-zinc-500 uppercase font-black tracking-widest">
                  Step {step + 1} of {STEPS.length}
                </p>
                <h2 className="text-white font-black text-xl">{STEPS[step].title}</h2>
              </div>
            </div>

            {/* Card body */}
            <div className="px-7 py-6">
              {renderStep()}
              {err && (
                <div className="flex items-center gap-2 mt-5 p-3 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-sm">
                  <AlertCircle size={15} className="flex-shrink-0" />
                  {err}
                </div>
              )}
            </div>

            {/* Card footer */}
            <div className="px-7 py-5 border-t border-zinc-800/60 flex items-center justify-between">
              <button
                onClick={back} disabled={step === 0}
                className="flex items-center gap-2 px-5 py-2.5 bg-white/5 hover:bg-white/10 border border-zinc-800 text-white/70 rounded-xl transition-all disabled:opacity-30 text-sm font-bold"
              >
                <ChevronLeft size={16} /> Back
              </button>

              <div className="flex items-center gap-3">
                {STEPS[step].skippable && (
                  <button
                    onClick={skip}
                    className="flex items-center gap-1 text-zinc-500 hover:text-zinc-300 text-sm transition-colors"
                  >
                    Skip <ChevronRight size={14} />
                  </button>
                )}

                {step === 7 ? (
                  <button
                    onClick={finish}
                    className="flex items-center gap-2 px-7 py-2.5 bg-[#F1C40F] hover:bg-[#D4AC0D] text-black font-black rounded-xl transition-all text-sm uppercase tracking-widest shadow-lg shadow-[#F1C40F]/20"
                  >
                    Go to Dashboard <ChevronRight size={16} />
                  </button>
                ) : (
                  <button
                    onClick={handleContinue} disabled={isLoading}
                    className="flex items-center gap-2 px-7 py-2.5 bg-[#F1C40F] hover:bg-[#D4AC0D] text-black font-black rounded-xl transition-all disabled:opacity-60 text-sm uppercase tracking-widest shadow-lg shadow-[#F1C40F]/20"
                  >
                    {isLoading && <Loader2 size={15} className="animate-spin" />}
                    Continue <ChevronRight size={16} />
                  </button>
                )}
              </div>
            </div>
          </div>

          {/* Progress dots */}
          <div className="flex justify-center gap-1.5">
            {STEPS.map((_, i) => (
              <div key={i} className={`h-1.5 rounded-full transition-all ${
                i === step ? "w-6 bg-[#F1C40F]" :
                completed.has(i) ? "w-3 bg-emerald-500/40" :
                "w-1.5 bg-white/10"
              }`} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
