"use client";

import { useState } from "react";
import { useParams } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import { gymsApi } from "@/lib/api";
import { Palette, Check, RefreshCw, Smartphone } from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import clsx from "clsx";

// ─── Preset colors ────────────────────────────────────────────────────────────

const PRESET_COLORS = [
  { label: "Gold",    value: "#F1C40F" },
  { label: "Orange",  value: "#E67E22" },
  { label: "Red",     value: "#E74C3C" },
  { label: "Pink",    value: "#E91E8C" },
  { label: "Purple",  value: "#9B59B6" },
  { label: "Blue",    value: "#3498DB" },
  { label: "Teal",    value: "#1ABC9C" },
  { label: "Green",   value: "#2ECC71" },
  { label: "White",   value: "#FFFFFF" },
];

// ─── Mobile Preview ───────────────────────────────────────────────────────────

function MobilePreview({
  gymName,
  themeColor,
  welcomeMessage,
  logoUrl,
}: {
  gymName: string;
  themeColor: string;
  welcomeMessage: string;
  logoUrl?: string;
}) {
  const safeColor = themeColor || "#F1C40F";

  return (
    <div className="flex flex-col items-center">
      <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-3">Live Preview</p>
      {/* Phone frame */}
      <div className="w-[200px] bg-[#0d1117] rounded-[28px] border-2 border-zinc-700 overflow-hidden shadow-2xl">
        {/* Status bar */}
        <div className="h-6 bg-black flex items-center justify-center">
          <div className="w-16 h-1.5 bg-zinc-700 rounded-full" />
        </div>

        {/* App header */}
        <div className="px-4 pt-4 pb-3" style={{ backgroundColor: safeColor + "18" }}>
          <div className="flex items-center gap-2 mb-2">
            {logoUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={logoUrl} alt="logo" className="w-8 h-8 rounded-full object-cover" />
            ) : (
              <div
                className="w-8 h-8 rounded-full flex items-center justify-center text-black font-bold text-xs"
                style={{ backgroundColor: safeColor }}
              >
                {gymName.charAt(0)}
              </div>
            )}
            <p className="text-white text-xs font-bold truncate">{gymName || "Your Gym"}</p>
          </div>
          {welcomeMessage && (
            <p className="text-[10px] leading-snug" style={{ color: safeColor }}>
              {welcomeMessage.slice(0, 60)}{welcomeMessage.length > 60 ? "…" : ""}
            </p>
          )}
        </div>

        {/* Mock content */}
        <div className="p-3 space-y-2">
          {/* CTA button */}
          <div
            className="w-full py-2 rounded-xl text-center text-[10px] font-bold text-black"
            style={{ backgroundColor: safeColor }}
          >
            Book a Class
          </div>

          {/* Mock cards */}
          {[1, 2].map((i) => (
            <div key={i} className="bg-zinc-800 rounded-xl p-2.5 flex items-center gap-2">
              <div className="w-6 h-6 rounded-lg" style={{ backgroundColor: safeColor + "30" }} />
              <div className="flex-1 space-y-1">
                <div className="h-1.5 bg-zinc-700 rounded w-3/4" />
                <div className="h-1 bg-zinc-700/50 rounded w-1/2" />
              </div>
            </div>
          ))}

          {/* Mock nav */}
          <div className="flex justify-around pt-1 mt-2 border-t border-zinc-800">
            {[0, 1, 2, 3].map((i) => (
              <div
                key={i}
                className="w-6 h-6 rounded-lg"
                style={{ backgroundColor: i === 0 ? safeColor + "30" : "transparent" }}
              >
                <div
                  className="w-2 h-2 mx-auto mt-2 rounded-sm"
                  style={{ backgroundColor: i === 0 ? safeColor : "#3f3f46" }}
                />
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function BrandingPage() {
  const { gymId } = useParams<{ gymId: string }>();
  const { token } = useAuthStore();
  const qc = useQueryClient();

  const { data: gymData, isLoading } = useQuery({
    queryKey: ["gym", gymId],
    queryFn: () => gymsApi.getById(gymId, token!),
    enabled: !!token,
  });

  const gym = gymData;

  const [themeColor, setThemeColor] = useState("#F1C40F");
  const [customColor, setCustomColor] = useState("");
  const [welcomeMessage, setWelcomeMessage] = useState("");
  const [dirty, setDirty] = useState(false);

  // Sync from server - modern React pattern to avoid cascading renders
  const [prevGym, setPrevGym] = useState(gym);
  if (gym !== prevGym) {
    setPrevGym(gym);
    if (gym && !dirty) {
      setThemeColor(gym.themeColor || "#F1C40F");
      setCustomColor(gym.themeColor || "");
      setWelcomeMessage(gym.welcomeMessage || "");
    }
  }

  const save = useMutation({
    mutationFn: () =>
      gymsApi.update(gymId, {
        themeColor: themeColor || undefined,
        welcomeMessage: welcomeMessage || undefined,
      }, token!),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["gym", gymId] });
      setDirty(false);
    },
  });

  function pickColor(c: string) {
    setThemeColor(c);
    setCustomColor(c);
    setDirty(true);
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64 text-zinc-500">
        <RefreshCw size={18} className="animate-spin mr-2" /> Loading…
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Branding"
        description="Customize how your facility appears in the member app"
        icon={<Palette size={32} />}
        actions={
          <button
            onClick={() => save.mutate()}
            disabled={!dirty || save.isPending}
            className={clsx(
              "flex items-center gap-2 px-6 py-3 text-xs font-black rounded-xl transition-all uppercase tracking-widest",
              dirty
                ? "bg-[#F1C40F] !text-black hover:bg-yellow-400 shadow-lg shadow-[#F1C40F]/10"
                : "bg-white/5 text-zinc-500 cursor-not-allowed border border-white/5"
            )}
          >
            {save.isPending ? (
              <RefreshCw size={16} className="animate-spin" />
            ) : (
              <Check size={16} />
            )}
            {save.isPending ? "Saving…" : "Save Changes"}
          </button>
        }
      />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Settings panel */}
        <div className="lg:col-span-2 space-y-6">

          {/* Theme Color */}
          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 space-y-4">
            <div>
              <h2 className="text-sm font-bold text-white">Primary Color</h2>
              <p className="text-xs text-zinc-500 mt-0.5">Used for buttons, accents, and highlights throughout the member app</p>
            </div>

            {/* Presets */}
            <div className="flex flex-wrap gap-2.5">
              {PRESET_COLORS.map((c) => (
                <button
                  key={c.value}
                  onClick={() => pickColor(c.value)}
                  title={c.label}
                  className={clsx(
                    "w-8 h-8 rounded-full border-2 transition-all",
                    themeColor === c.value
                      ? "border-white scale-110"
                      : "border-transparent hover:scale-105"
                  )}
                  style={{ backgroundColor: c.value }}
                />
              ))}
            </div>

            {/* Custom hex */}
            <div className="flex items-center gap-3">
              <div
                className="w-10 h-10 rounded-lg border border-zinc-700 flex-shrink-0"
                style={{ backgroundColor: customColor || "#3f3f46" }}
              />
              <div className="flex-1">
                <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-1">
                  Custom Hex
                </label>
                <input
                  type="text"
                  value={customColor}
                  onChange={(e) => {
                    setCustomColor(e.target.value);
                    if (/^#[0-9A-Fa-f]{6}$/.test(e.target.value)) {
                      setThemeColor(e.target.value);
                      setDirty(true);
                    }
                  }}
                  placeholder="#F1C40F"
                  maxLength={7}
                  className="w-full bg-zinc-800 border border-zinc-700 text-white text-sm font-mono rounded-lg px-3 py-2 focus:outline-none focus:border-[#F1C40F]"
                />
              </div>
              <input
                type="color"
                value={themeColor}
                onChange={(e) => pickColor(e.target.value)}
                className="w-10 h-10 rounded-lg border border-zinc-700 bg-zinc-800 cursor-pointer p-0.5"
                title="Color picker"
              />
            </div>
          </div>

          {/* Welcome Message */}
          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 space-y-4">
            <div>
              <h2 className="text-sm font-bold text-white">Welcome Message</h2>
              <p className="text-xs text-zinc-500 mt-0.5">
                A short greeting shown to members when they open the app at your facility
              </p>
            </div>
            <textarea
              value={welcomeMessage}
              onChange={(e) => { setWelcomeMessage(e.target.value); setDirty(true); }}
              placeholder="Welcome to our gym! Book your next class and crush your goals."
              rows={3}
              maxLength={120}
              className="w-full bg-zinc-800 border border-zinc-700 text-white text-sm rounded-lg px-3 py-2.5 focus:outline-none focus:border-[#F1C40F] resize-none placeholder-zinc-600"
            />
            <p className="text-xs text-zinc-600 text-right">{welcomeMessage.length}/120</p>
          </div>

          {/* Gym info note */}
          <div className="bg-zinc-800/30 border border-zinc-700/50 rounded-xl p-4 text-xs text-zinc-500 flex items-start gap-3">
            <Smartphone size={14} className="text-zinc-400 flex-shrink-0 mt-0.5" />
            <p>
              Logo and banner images can be updated from the <strong className="text-zinc-300">gym detail page</strong>.
              Changes here apply to the member-facing mobile app.
            </p>
          </div>
        </div>

        {/* Preview */}
        <div className="lg:col-span-1 flex justify-center lg:justify-start">
          <MobilePreview
            gymName={gym?.name ?? "Your Gym"}
            themeColor={themeColor}
            welcomeMessage={welcomeMessage}
            logoUrl={gym?.logoUrl}
          />
        </div>
      </div>
    </div>
  );
}
