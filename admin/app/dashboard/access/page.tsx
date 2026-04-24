"use client";

import { useState, useEffect, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore, isBranchAdminOrAbove } from "@/lib/auth-store";
import { doorAccessApi, gymLiveApi, DoorSystemType, CreateDoorSystemData, hardwareApi, HardwareGateway, branchApi, MemberSearchResult, CardCredential } from "@/lib/api";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";
import { useRouter } from "next/navigation";
import { QRCodeSVG } from "qrcode.react";
import Image from "next/image";
import {
  LogIn,
  ShieldCheck,
  ShieldAlert,
  Cpu,
  MapPin,
  Clock,
  Plus,
  X,
  Edit2,
  Trash2,
  RefreshCw,
  QrCode,
  Smartphone,
  Key,
  Bluetooth,
  Fingerprint,
  Power,
  Download,
  Printer,
  Users,
  Activity,
  TrendingUp,
  UserCheck,
  Wifi,
  WifiOff,
  Unlock,
  CreditCard,
  Server,
  ChevronDown,
  ChevronUp,
  Copy,
  Check,
  BookOpen,
  Zap,
  Search,
  UserPlus,
} from "lucide-react";

// ─── Integration Guides ───────────────────────────────────────────────────────

const SYSTEM_GUIDES: Record<string, {
  tagline: string;
  difficulty: "Easy" | "Medium" | "Advanced";
  hardware: string;
  steps: string[];
  tip?: string;
}> = {
  QR_CODE: {
    tagline: "Zero hardware — works in minutes",
    difficulty: "Easy",
    hardware: "None required",
    steps: [
      'Click "Show QR" on this card to open the printable QR code',
      "Print it and post at your gym entrance (A4 or bigger)",
      'Members open the Amirani app → tap "Scan to Enter"',
      "App verifies membership instantly — door opens if valid",
    ],
    tip: "Laminate the printout or put it in a frame to prevent wear.",
  },
  NFC: {
    tagline: "Tap phone or card — sub-second entry",
    difficulty: "Easy",
    hardware: "Raspberry Pi Zero 2W + MFRC522 reader + relay (~$25 total)",
    steps: [
      "Register a Hardware Gateway above (HTTP Relay protocol) — copy the API key",
      "Buy: Raspberry Pi Zero 2W (~$15) + MFRC522 RFID module (~$3) + 5V relay (~$3)",
      "Connect MFRC522 to Pi SPI0 pins, relay to GPIO18, LED to GPIO23/24",
      'Copy gateway/amirani_gateway.py to the Pi, run install.sh — paste API key into config.json',
      "sudo systemctl start amirani-gateway — LED turns green when online",
      "Enroll member cards in Hardware Gateways → register cards per member",
    ],
    tip: "Android phones with NFC act as virtual cards (HCE) — no physical card needed. iPhone requires iOS 17+ with background NFC.",
  },
  PIN_CODE: {
    tagline: "No phone, no card — just a number",
    difficulty: "Easy",
    hardware: "Raspberry Pi Zero 2W + 4x4 keypad + relay (~$25 total)",
    steps: [
      "Register a Hardware Gateway above (HTTP Relay protocol) — copy the API key",
      "Buy: Raspberry Pi Zero 2W (~$15) + 4x4 keypad matrix (~$3) + 5V relay (~$3)",
      "Wire keypad rows to GPIO 5,6,13,19 and cols to GPIO 26,16,20,21",
      'In config.json set "use_nfc": false, "use_keypad": true — paste API key',
      "Run install.sh — member types PIN + # to submit",
      'Enroll each member PIN as a card with UID "PIN-123456" from the Cards section',
    ],
    tip: "Use 6-digit PINs minimum. Enable both NFC + keypad for dual-mode entry on one device.",
  },
  BLUETOOTH: {
    tagline: "Hands-free — unlocks as you walk up",
    difficulty: "Medium",
    hardware: "Raspberry Pi Zero 2W with built-in BLE",
    steps: [
      "Register a Hardware Gateway above (HTTP Relay protocol) — copy the API key",
      "Raspberry Pi Zero 2W has BLE built-in — no extra hardware needed",
      "Enable BLE scanning mode in config.json (coming soon — use NFC or PIN for now)",
      "App broadcasts BLE UUID when within range — Pi detects and calls validate",
      "Connect relay to turnstile dry-contact input",
    ],
    tip: "Pi Zero 2W has Bluetooth 4.2 built-in. BLE mode in gateway firmware is in progress.",
  },
  BIOMETRIC: {
    tagline: "Fingerprint or face — most secure",
    difficulty: "Advanced",
    hardware: "ZKTeco / Suprema device + Raspberry Pi gateway bridge",
    steps: [
      "Install biometric device (ZKTeco K40 ~$150 or Suprema BioEntry ~$300)",
      "Register a Hardware Gateway above using ZKTeco TCP protocol — copy API key",
      "Run gateway firmware on a Pi connected to same LAN as the ZKTeco device",
      "Configure ZKTeco push-SDK to point to Pi IP — Pi forwards events to Amirani",
      "Enroll member biometrics on the ZKTeco device via its admin app",
    ],
    tip: "ZKTeco K40 supports push-SDK (HTTP) — the Pi gateway bridge receives the event and calls /hardware/gw/validate on behalf of the device.",
  },
};

const DOOR_SYSTEM_TYPES: { value: DoorSystemType; label: string; icon: typeof QrCode; description: string; manual: boolean }[] = [
  { value: "QR_CODE",   label: "QR Code",   icon: QrCode,       description: "Scan QR codes for entry — no hardware",     manual: true  },
  { value: "NFC",       label: "NFC",       icon: Smartphone,   description: "Auto-created when you register a Gateway",   manual: false },
  { value: "PIN_CODE",  label: "PIN Code",  icon: Key,          description: "Auto-created when you register a Gateway",   manual: false },
  { value: "BLUETOOTH", label: "Bluetooth", icon: Bluetooth,    description: "Auto-created when you register a Gateway",   manual: false },
  { value: "BIOMETRIC", label: "Biometric", icon: Fingerprint,  description: "Auto-created when you register a Gateway",   manual: false },
];

function getTypeIcon(type: string) {
  const option = DOOR_SYSTEM_TYPES.find((t) => t.value === type);
  return option?.icon || Cpu;
}

interface DoorSystem {
  id: string;
  name: string;
  type: string;
  location?: string;
  isActive: boolean;
  isHealthy?: boolean;
  config?: Record<string, unknown>;
}

interface DoorSystemModalProps {
  gymId: string;
  token: string;
  system?: DoorSystem | null;
  onClose: () => void;
}

function DoorSystemModal({ gymId, token, system, onClose }: DoorSystemModalProps) {
  const queryClient = useQueryClient();
  const isEditing = !!system;

  const [formData, setFormData] = useState<CreateDoorSystemData & { isActive?: boolean }>({
    name: system?.name || "",
    type: (system?.type as DoorSystemType) || "QR_CODE",
    location: system?.location || "",
    config: system?.config || {},
    isActive: system?.isActive ?? true,
  });

  const createMutation = useMutation({
    mutationFn: (data: CreateDoorSystemData) => doorAccessApi.createSystem(gymId, data, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["door-systems", gymId] });
      queryClient.invalidateQueries({ queryKey: ["door-health", gymId] });
      onClose();
    },
  });

  const updateMutation = useMutation({
    mutationFn: (data: Partial<CreateDoorSystemData> & { isActive?: boolean }) =>
      doorAccessApi.updateSystem(system!.id, data, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["door-systems", gymId] });
      queryClient.invalidateQueries({ queryKey: ["door-health", gymId] });
      onClose();
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (isEditing) {
      updateMutation.mutate(formData);
    } else {
      createMutation.mutate(formData);
    }
  };

  const isLoading = createMutation.isPending || updateMutation.isPending;
  const error = createMutation.error?.message || updateMutation.error?.message;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-lg max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] flex flex-col overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
          <div>
            <h2 className="text-xl font-bold text-white uppercase tracking-tight italic">
              {isEditing ? "Edit Access Point" : "Add QR Code Access Point"}
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">
              {isEditing ? "Update configuration" : "No hardware required — members scan with the app"}
            </p>
          </div>
          <button onClick={onClose} className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {error && (
              <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-sm">
                {error}
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-zinc-400 mb-2">System Designation *</label>
              <input
                type="text"
                required
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                className="w-full px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-xl text-white focus:outline-none focus:border-[#F1C40F] transition-all"
                placeholder="e.g., Main Entrance, Side Door"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-zinc-400 mb-2">Type</label>
              {/* When creating: only QR (hardware types are auto-created by Gateways).
                  When editing: show all so existing gateway-linked systems can be renamed/relocated. */}
              <div className="grid grid-cols-2 gap-3">
                {(isEditing ? DOOR_SYSTEM_TYPES : DOOR_SYSTEM_TYPES.filter((t) => t.manual)).map((option) => {
                  const Icon = option.icon;
                  return (
                    <button
                      key={option.value}
                      type="button"
                      onClick={() => setFormData({ ...formData, type: option.value })}
                      className={`p-4 rounded-2xl text-left transition-all relative overflow-hidden group ${
                        formData.type === option.value
                          ? "bg-[#F1C40F] border-2 border-[#F1C40F] !text-black"
                          : "bg-zinc-800 border border-transparent text-zinc-400 hover:border-zinc-700"
                      }`}
                    >
                      <div className="flex items-center gap-3 mb-2">
                        <div className={`p-2 rounded-lg ${formData.type === option.value ? "bg-black/10 text-black" : "bg-zinc-900 text-zinc-500"}`}>
                          <Icon size={18} />
                        </div>
                        <span className="text-sm font-black uppercase tracking-tight">{option.label}</span>
                      </div>
                      <p className="text-[10px] text-zinc-500 leading-tight">{option.description}</p>
                    </button>
                  );
                })}
              </div>
              {!isEditing && (
                <p className="text-[10px] text-zinc-600 mt-2 flex items-center gap-1.5">
                  <Server size={10} className="shrink-0" />
                  NFC, PIN, Bluetooth and Biometric systems are <span className="text-zinc-400 font-bold">auto-created</span> when you register a Hardware Gateway.
                </p>
              )}

              {/* Integration guide for selected type */}
              {SYSTEM_GUIDES[formData.type] && (() => {
                const guide = SYSTEM_GUIDES[formData.type];
                return (
                  <div className="mt-4 p-4 bg-zinc-900/80 rounded-2xl border border-zinc-800 space-y-3">
                    <div className="flex items-center justify-between">
                      <p className="text-[10px] font-black text-zinc-400 uppercase tracking-widest flex items-center gap-1.5">
                        <BookOpen size={10} className="text-[#F1C40F]" /> How to integrate
                      </p>
                      <div className="flex items-center gap-2">
                        <span className={`text-[9px] font-black uppercase px-2 py-0.5 rounded-full ${
                          guide.difficulty === "Easy" ? "bg-green-500/20 text-green-400" :
                          guide.difficulty === "Medium" ? "bg-yellow-500/20 text-yellow-400" :
                          "bg-red-500/20 text-red-400"
                        }`}>{guide.difficulty}</span>
                      </div>
                    </div>
                    <p className="text-[10px] text-zinc-500 flex items-center gap-1.5">
                      <Cpu size={9} className="shrink-0" />
                      <span className="font-bold text-zinc-400">Hardware:</span> {guide.hardware}
                    </p>
                    <ol className="space-y-1.5">
                      {guide.steps.map((step, i) => (
                        <li key={i} className="flex gap-2 text-[10px] text-zinc-400 leading-relaxed">
                          <span className="shrink-0 w-4 h-4 rounded-full bg-zinc-800 text-zinc-500 flex items-center justify-center font-black text-[9px]">{i + 1}</span>
                          {step}
                        </li>
                      ))}
                    </ol>
                    {guide.tip && (
                      <div className="flex gap-2 p-2.5 bg-[#F1C40F]/5 border border-[#F1C40F]/10 rounded-xl">
                        <Zap size={10} className="text-[#F1C40F] shrink-0 mt-0.5" />
                        <p className="text-[10px] text-zinc-400 leading-relaxed">{guide.tip}</p>
                      </div>
                    )}
                  </div>
                );
              })()}
            </div>

            <div>
              <label className="block text-sm font-medium text-zinc-400 mb-2">Physical Location</label>
              <input
                type="text"
                value={formData.location}
                onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                className="w-full px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-xl text-white focus:outline-none focus:border-[#F1C40F] transition-all"
                placeholder="e.g., Front lobby, Back entrance"
              />
            </div>

            {isEditing && (
              <div className="flex items-center justify-between p-5 bg-white/[0.02] rounded-2xl border border-white/5">
                <div>
                  <p className="text-white font-bold text-sm uppercase italic">Operational Status</p>
                  <p className="text-[10px] text-zinc-500 uppercase tracking-widest mt-1">Live toggle for security nodes</p>
                </div>
                <button
                  type="button"
                  onClick={() => setFormData({ ...formData, isActive: !formData.isActive })}
                  className={`px-4 py-2 rounded-xl font-black text-[10px] uppercase tracking-widest transition-all ${
                    formData.isActive
                      ? "bg-green-500/20 text-green-400 border border-green-500/30 shadow-[0_0_15px_rgba(34,197,94,0.2)]"
                      : "bg-red-500/20 text-red-400 border border-red-500/30"
                  }`}
                >
                  {formData.isActive ? "Online" : "Offline"}
                </button>
              </div>
            )}
          </form>
        </div>

        {/* FIXED FOOTER */}
        <div className="p-8 border-t border-white/5 bg-white/[0.01] flex gap-4 shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 hover:bg-zinc-800 transition-all"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={isLoading || !formData.name}
            className="flex-1 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F4D03F] transition-all disabled:opacity-30 flex items-center justify-center gap-3 shadow-2xl shadow-[#F1C40F]/20"
          >
            {isLoading ? (
              <RefreshCw className="animate-spin" size={18} />
            ) : isEditing ? (
              "Update Node"
            ) : (
              <>
                <ShieldCheck size={18} />
                Deploy System
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Live Occupancy Panel ─────────────────────────────────────────────────────

function LiveOccupancyPanel({ gymId, token }: { gymId: string; token: string }) {
  const { data: live, isLoading } = useQuery({
    queryKey: ["gym-live", gymId],
    queryFn: () => gymLiveApi.getLive(gymId, token),
    refetchInterval: 10000, // refresh every 10s
    retry: false,
  });

  const occupancyColor =
    !live?.occupancyPercent ? "text-zinc-400" :
    live.occupancyPercent >= 90 ? "text-red-400" :
    live.occupancyPercent >= 70 ? "text-yellow-400" :
    "text-green-400";

  const barColor =
    !live?.occupancyPercent ? "bg-zinc-700" :
    live.occupancyPercent >= 90 ? "bg-red-500" :
    live.occupancyPercent >= 70 ? "bg-yellow-400" :
    "bg-green-500";

  return (
    <div className="bg-[#0e1420] border border-white/5 rounded-2xl p-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="relative">
            <Activity size={18} className="text-[#F1C40F]" />
            <span className="absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full bg-green-500 animate-pulse" />
          </div>
          <span className="text-white font-black uppercase text-sm tracking-tight italic">Live</span>
        </div>
        <span className="text-[10px] font-bold text-zinc-600 uppercase tracking-widest not-italic">updates every 10s</span>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-6">
          <RefreshCw className="animate-spin text-[#F1C40F]" size={20} />
        </div>
      ) : !live ? (
        <p className="text-zinc-600 text-xs text-center py-4">No live data available</p>
      ) : (
        <>
          {/* Stat cards */}
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-white/[0.03] rounded-xl p-4 border border-white/5">
              <div className="flex items-center gap-2 mb-2">
                <Users size={14} className="text-[#F1C40F]" />
                <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Now In</span>
              </div>
              <div className={`text-3xl font-black ${occupancyColor}`}>{live.currentOccupancy}</div>
              {live.maxCapacity > 0 && (
                <div className="text-[10px] text-zinc-600 mt-1">of {live.maxCapacity} capacity</div>
              )}
            </div>
            <div className="bg-white/[0.03] rounded-xl p-4 border border-white/5">
              <div className="flex items-center gap-2 mb-2">
                <TrendingUp size={14} className="text-[#F1C40F]" />
                <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Today</span>
              </div>
              <div className="text-3xl font-black text-white">{live.todayCheckIns}</div>
              <div className="text-[10px] text-zinc-600 mt-1">total check-ins</div>
            </div>
          </div>

          {/* Capacity bar */}
          {live.maxCapacity > 0 && live.occupancyPercent !== null && (
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Occupancy</span>
                <span className={`text-xs font-black ${occupancyColor}`}>{live.occupancyPercent}%</span>
              </div>
              <div className="h-2 bg-zinc-800 rounded-full overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all duration-700 ${barColor}`}
                  style={{ width: `${Math.min(live.occupancyPercent, 100)}%` }}
                />
              </div>
              {live.occupancyPercent >= 90 && (
                <p className="text-red-400 text-[10px] font-bold mt-1.5 uppercase tracking-wider">⚠ Near capacity</p>
              )}
            </div>
          )}

          {/* Members currently in */}
          {live.currentlyIn.length > 0 && (
            <div>
              <div className="flex items-center gap-2 mb-3">
                <UserCheck size={14} className="text-zinc-500" />
                <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Currently Inside</span>
              </div>
              <div className="space-y-2 max-h-48 overflow-y-auto amirani-scrollbar">
                {live.currentlyIn.map((m) => (
                  <div key={m.attendanceId} className="flex items-center justify-between py-2 px-3 bg-white/[0.02] rounded-xl border border-white/5">
                    <div className="flex items-center gap-3">
                      <div className="w-7 h-7 rounded-full bg-[#F1C40F]/10 border border-[#F1C40F]/20 flex items-center justify-center overflow-hidden">
                        {m.avatarUrl ? (
                          <Image 
                            src={m.avatarUrl} 
                            alt={m.fullName} 
                            width={28} 
                            height={28} 
                            className="w-full h-full object-cover" 
                            unoptimized
                          />
                        ) : (
                          <span className="text-[#F1C40F] text-[10px] font-black">
                            {m.fullName.charAt(0).toUpperCase()}
                          </span>
                        )}
                      </div>
                      <div>
                        <p className="text-white text-xs font-bold leading-tight">{m.fullName}</p>
                        <p className="text-zinc-600 text-[10px]">{m.planName}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-zinc-400 text-[10px] font-bold">{m.minutesInGym}m</p>
                      <div className="w-1.5 h-1.5 rounded-full bg-green-500 shadow-[0_0_6px_rgba(34,197,94,0.6)] ml-auto mt-1" />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {live.currentlyIn.length === 0 && (
            <div className="text-center py-4">
              <p className="text-zinc-600 text-xs">No members currently in gym</p>
            </div>
          )}
        </>
      )}
    </div>
  );
}

// ─── QR Code Display Modal ────────────────────────────────────────────────────

interface QrCodeDisplayModalProps {
  system: DoorSystem;
  gymId: string;
  onClose: () => void;
}

function QrCodeDisplayModal({ system, gymId, onClose }: QrCodeDisplayModalProps) {
  const qrRef = useRef<HTMLDivElement>(null);
  const qrValue = `amirani://checkin?gymId=${gymId}&token=${system.id}`;

  const handlePrint = () => {
    const svg = qrRef.current?.querySelector("svg");
    if (!svg) return;
    const svgData = new XMLSerializer().serializeToString(svg);
    const printWindow = window.open("", "_blank");
    if (!printWindow) return;
    printWindow.document.write(`
      <html><head><title>QR Code – ${system.name}</title>
      <style>
        body { display:flex; flex-direction:column; align-items:center; justify-content:center; min-height:100vh; margin:0; background:#fff; font-family:sans-serif; }
        .label { font-size:22px; font-weight:bold; margin-bottom:12px; }
        .sub { font-size:14px; color:#666; margin-bottom:24px; }
        @media print { button { display:none; } }
      </style></head>
      <body>
        <div class="label">${system.name}</div>
        <div class="sub">${system.location || "Gym Entrance"} · Scan to enter</div>
        ${svgData}
        <script>window.onload=()=>{ window.print(); window.close(); }</script>
      </body></html>
    `);
    printWindow.document.close();
  };

  const handleDownload = () => {
    const svg = qrRef.current?.querySelector("svg");
    if (!svg) return;
    const svgData = new XMLSerializer().serializeToString(svg);
    const blob = new Blob([svgData], { type: "image/svg+xml" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `qr-${system.name.toLowerCase().replace(/\s+/g, "-")}.svg`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
      <div className="bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-sm shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        {/* Header */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02]">
          <div>
            <h2 className="text-xl font-bold text-white uppercase tracking-tight italic">Entrance QR Code</h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">{system.name} · {system.location || "Gym Entrance"}</p>
          </div>
          <button onClick={onClose} className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* QR Code */}
        <div className="p-8 flex flex-col items-center gap-6">
          <div ref={qrRef} className="bg-white p-5 rounded-2xl shadow-2xl">
            <QRCodeSVG
              value={qrValue}
              size={220}
              bgColor="#ffffff"
              fgColor="#000000"
              level="H"
              includeMargin={false}
            />
          </div>

          <div className="text-center space-y-1">
            <p className="text-white font-bold text-sm">Place this at your gym entrance</p>
            <p className="text-zinc-500 text-xs">Members scan this with the Amirani app to check in</p>
          </div>

          <div className="w-full p-3 bg-zinc-900 rounded-xl border border-zinc-800">
            <p className="text-[10px] font-mono text-zinc-500 break-all text-center">{qrValue}</p>
          </div>

          {/* Actions */}
          <div className="flex gap-3 w-full">
            <button
              onClick={handleDownload}
              className="flex-1 py-3 bg-zinc-800 text-zinc-300 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-zinc-700 hover:bg-zinc-700 transition-all flex items-center justify-center gap-2"
            >
              <Download size={14} />
              Download
            </button>
            <button
              onClick={handlePrint}
              className="flex-1 py-3 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all flex items-center justify-center gap-2 shadow-lg shadow-[#F1C40F]/20"
            >
              <Printer size={14} />
              Print
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Register Gateway Modal ───────────────────────────────────────────────────

interface RegisterGatewayModalProps {
  gymId: string;
  token: string;
  onClose: () => void;
}

function RegisterGatewayModal({ gymId, token, onClose }: RegisterGatewayModalProps) {
  const queryClient = useQueryClient();
  const [formData, setFormData] = useState({
    name: "",
    location: "",
    protocol: "RELAY_HTTP",
  });
  const [copiedKey, setCopiedKey] = useState(false);
  const [createdGateway, setCreatedGateway] = useState<HardwareGateway | null>(null);

  const createMutation = useMutation({
    mutationFn: () =>
      hardwareApi.createGateway(
        { gymId, name: formData.name, location: formData.location || undefined, protocol: formData.protocol },
        token
      ),
    onSuccess: (gw) => {
      setCreatedGateway(gw);
      queryClient.invalidateQueries({ queryKey: ["hardware-gateways", gymId] });
    },
  });

  const handleCopy = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(true);
    setTimeout(() => setCopiedKey(false), 2000);
  };

  const PROTOCOLS = [
    { value: "RELAY_HTTP", label: "HTTP Relay", desc: "Raspberry Pi / ESP32 with REST + WebSocket" },
    { value: "WIEGAND", label: "Wiegand", desc: "Standard 26/34-bit card reader protocol" },
    { value: "OSDP_V2", label: "OSDP v2", desc: "Secure, bi-directional RS-485 protocol" },
    { value: "ZKTECO_TCP", label: "ZKTeco TCP", desc: "ZKTeco compatible turnstiles & readers" },
    { value: "MQTT", label: "MQTT", desc: "IoT message broker for remote devices" },
  ];

  if (createdGateway) {
    const backendUrl = process.env.NEXT_PUBLIC_API_URL?.replace("/api", "") || "https://amirani.esme.ge";
    const configJson = JSON.stringify(
      {
        api_key: createdGateway.apiKey,
        backend_url: backendUrl,
        relay_pin: 18,
        led_green_pin: 23,
        led_red_pin: 24,
        buzzer_pin: 27,
        unlock_duration_ms: 3000,
        use_nfc: true,
        nfc_reader: "mfrc522",
        use_keypad: false,
        use_display: false,
      },
      null,
      2
    );

    return (
      <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4">
        <div className="bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-lg shadow-[0_0_100px_rgba(0,0,0,0.5)] flex flex-col max-h-[90vh] overflow-hidden">
          <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-green-500/20 flex items-center justify-center">
                <Check size={16} className="text-green-400" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-white uppercase tracking-tight italic">Gateway Registered</h2>
                <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-0.5">Copy your config — shown only once</p>
              </div>
            </div>
            <button onClick={onClose} className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5">
              <X size={20} />
            </button>
          </div>

          <div className="flex-1 overflow-y-auto p-8 space-y-5">
            {/* API Key */}
            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 flex items-center gap-2">
                <span className="w-1.5 h-1.5 rounded-full bg-[#F1C40F]" /> API Key
                <span className="text-red-400 normal-case font-normal ml-1">— copy and keep safe</span>
              </label>
              <div className="flex items-center gap-2">
                <div className="flex-1 px-4 py-3 bg-zinc-900 border border-[#F1C40F]/30 rounded-xl font-mono text-xs text-[#F1C40F] break-all select-all">
                  {createdGateway.apiKey}
                </div>
                <button
                  onClick={() => handleCopy(createdGateway.apiKey)}
                  className={`p-3 rounded-xl transition-all border shrink-0 ${copiedKey ? "bg-green-500/20 border-green-500/40 text-green-400" : "bg-zinc-800 border-zinc-700 text-zinc-400 hover:bg-zinc-700"}`}
                >
                  {copiedKey ? <Check size={16} /> : <Copy size={16} />}
                </button>
              </div>
            </div>

            {/* Ready-to-flash config.json */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="text-[10px] font-black text-zinc-500 uppercase tracking-widest flex items-center gap-2">
                  <Zap size={10} className="text-[#F1C40F]" /> Ready-to-flash config.json
                </label>
                <button
                  onClick={() => handleCopy(configJson)}
                  className="flex items-center gap-1.5 px-3 py-1 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-[10px] text-zinc-400 font-bold transition-colors"
                >
                  <Copy size={10} /> Copy
                </button>
              </div>
              <pre className="p-4 bg-zinc-900 border border-zinc-800 rounded-2xl text-[10px] font-mono text-zinc-400 overflow-x-auto leading-relaxed">
                {configJson}
              </pre>
            </div>

            {/* Setup steps */}
            <div className="p-4 bg-zinc-900/50 rounded-2xl border border-zinc-800 space-y-3">
              <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Quick Setup Steps</p>
              {[
                "On your Raspberry Pi, run: curl -sSL https://amirani.esme.ge/gateway/install.sh | bash",
                "When prompted, paste config.json above (or: nano config.json)",
                "Run: sudo systemctl start amirani-gateway",
                "Watch status: sudo journalctl -fu amirani-gateway",
                "Gateway will appear Online in this dashboard within 30 seconds",
              ].map((step, i) => (
                <div key={i} className="flex gap-3 items-start">
                  <span className="shrink-0 w-5 h-5 rounded-full bg-zinc-800 text-zinc-500 flex items-center justify-center font-black text-[9px] mt-0.5">{i + 1}</span>
                  <p className="text-[11px] text-zinc-400 leading-relaxed">{step}</p>
                </div>
              ))}
            </div>
          </div>

          <div className="p-8 pt-4 shrink-0">
            <button
              onClick={onClose}
              className="w-full py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all shadow-lg shadow-[#F1C40F]/20"
            >
              Done — Gateway is Ready
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
      <div className="bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-lg shadow-[0_0_100px_rgba(0,0,0,0.5)] flex flex-col overflow-hidden max-h-[90vh]">
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
          <div>
            <h2 className="text-xl font-bold text-white uppercase tracking-tight italic">Register Hardware Gateway</h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Connect physical turnstile / reader</p>
          </div>
          <button onClick={onClose} className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8 space-y-6">
          {createMutation.error && (
            <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-sm">
              {(createMutation.error as Error)?.message || "Failed to register gateway"}
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-zinc-400 mb-2">Gateway Name *</label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              className="w-full px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-xl text-white focus:outline-none focus:border-[#F1C40F] transition-all"
              placeholder="e.g., Main Entrance Turnstile"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-zinc-400 mb-2">Location</label>
            <input
              type="text"
              value={formData.location}
              onChange={(e) => setFormData({ ...formData, location: e.target.value })}
              className="w-full px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-xl text-white focus:outline-none focus:border-[#F1C40F] transition-all"
              placeholder="e.g., Front lobby"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-zinc-400 mb-3">Hardware Protocol *</label>
            <div className="space-y-2">
              {PROTOCOLS.map((p) => (
                <button
                  key={p.value}
                  type="button"
                  onClick={() => setFormData({ ...formData, protocol: p.value })}
                  className={`w-full p-4 rounded-2xl text-left transition-all flex items-center gap-4 ${
                    formData.protocol === p.value
                      ? "bg-[#F1C40F]/10 border-2 border-[#F1C40F]"
                      : "bg-zinc-800 border border-transparent hover:border-zinc-700"
                  }`}
                >
                  <div className={`w-3 h-3 rounded-full border-2 shrink-0 ${
                    formData.protocol === p.value ? "border-[#F1C40F] bg-[#F1C40F]" : "border-zinc-600"
                  }`} />
                  <div>
                    <p className={`text-sm font-black uppercase tracking-tight ${formData.protocol === p.value ? "text-[#F1C40F]" : "text-zinc-300"}`}>{p.label}</p>
                    <p className="text-[10px] text-zinc-500 mt-0.5">{p.desc}</p>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="p-8 border-t border-white/5 bg-white/[0.01] flex gap-4 shrink-0">
          <button
            onClick={onClose}
            className="flex-1 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 hover:bg-zinc-800 transition-all"
          >
            Cancel
          </button>
          <button
            onClick={() => createMutation.mutate()}
            disabled={createMutation.isPending || !formData.name}
            className="flex-1 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F4D03F] transition-all disabled:opacity-30 flex items-center justify-center gap-3 shadow-2xl shadow-[#F1C40F]/20"
          >
            {createMutation.isPending ? <RefreshCw className="animate-spin" size={18} /> : (
              <><Server size={16} /> Register Gateway</>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Hardware Gateway Panel ───────────────────────────────────────────────────

function HardwareGatewayPanel({ gymId, token }: { gymId: string; token: string }) {
  const queryClient = useQueryClient();
  const [showRegisterModal, setShowRegisterModal] = useState(false);
  const [expandedGateway, setExpandedGateway] = useState<string | null>(null);
  const [unlockingId, setUnlockingId] = useState<string | null>(null);
  const [unlockSuccess, setUnlockSuccess] = useState<string | null>(null);

  const { data: gateways, isLoading } = useQuery({
    queryKey: ["hardware-gateways", gymId],
    queryFn: () => hardwareApi.getGateways(gymId, token),
    refetchInterval: 15000,
    retry: false,
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => hardwareApi.deleteGateway(id, gymId, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["hardware-gateways", gymId] });
      queryClient.invalidateQueries({ queryKey: ["door-systems", gymId] });
    },
  });

  const handleDelete = (gateway: HardwareGateway) => {
    if (confirm(`Remove gateway "${gateway.name}"? This will also deactivate its linked door system.`)) {
      deleteMutation.mutate(gateway.id);
    }
  };

  const handleRemoteUnlock = async (gateway: HardwareGateway) => {
    setUnlockingId(gateway.id);
    try {
      await hardwareApi.remoteUnlock(gateway.id, undefined, token);
      setUnlockSuccess(gateway.id);
      setTimeout(() => setUnlockSuccess(null), 3000);
    } catch {
      // error shown inline
    } finally {
      setUnlockingId(null);
    }
  };

  const protocolLabel: Record<string, string> = {
    RELAY_HTTP: "HTTP Relay",
    WIEGAND: "Wiegand",
    OSDP_V2: "OSDP v2",
    ZKTECO_TCP: "ZKTeco",
    SALTO_OSDP: "Salto",
    MQTT: "MQTT",
  };

  return (
    <div className="bg-[#0e1420] border border-white/5 rounded-2xl p-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Server size={18} className="text-[#F1C40F]" />
          <span className="text-white font-black uppercase text-sm tracking-tight italic">Hardware Gateways</span>
          {gateways && gateways.length > 0 && (
            <span className="px-2 py-0.5 bg-zinc-800 rounded-full text-[10px] font-bold text-zinc-400">
              {gateways.filter((g) => g.isOnline).length}/{gateways.length} online
            </span>
          )}
        </div>
        <button
          onClick={() => setShowRegisterModal(true)}
          className="flex items-center justify-center gap-2 px-6 py-2.5 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
        >
          <Plus size={15} />
          Register
        </button>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-6">
          <RefreshCw className="animate-spin text-[#F1C40F]" size={20} />
        </div>
      ) : !gateways || gateways.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-8 gap-3 text-center">
          <div className="p-4 bg-zinc-800/50 rounded-2xl border border-zinc-700 border-dashed">
            <Server size={28} className="text-zinc-600 mx-auto mb-2" />
            <p className="text-zinc-500 text-sm font-medium">No gateways registered</p>
            <p className="text-zinc-600 text-xs mt-1">Register a Raspberry Pi, ESP32, or ZKTeco device</p>
          </div>
          <button
            onClick={() => setShowRegisterModal(true)}
            className="px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
          >
            + Register your first gateway
          </button>
        </div>
      ) : (
        <div className="space-y-3">
          {gateways.map((gateway) => {
            const isExpanded = expandedGateway === gateway.id;
            const isUnlocking = unlockingId === gateway.id;
            const didUnlock = unlockSuccess === gateway.id;

            return (
              <div
                key={gateway.id}
                className={`rounded-2xl border transition-all ${
                  gateway.isOnline
                    ? "bg-white/[0.03] border-white/10"
                    : "bg-zinc-900/50 border-zinc-800 opacity-70"
                }`}
              >
                {/* Gateway row */}
                <div className="flex items-center gap-3 p-4">
                  {/* Status indicator */}
                  <div className={`w-2.5 h-2.5 rounded-full shrink-0 ${
                    gateway.isOnline
                      ? "bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.6)] animate-pulse"
                      : "bg-zinc-600"
                  }`} />

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="text-white text-sm font-bold truncate">{gateway.name}</p>
                      <span className="text-[10px] px-2 py-0.5 bg-zinc-800 rounded-full text-zinc-500 font-bold shrink-0">
                        {protocolLabel[gateway.protocol] || gateway.protocol}
                      </span>
                    </div>
                    <div className="flex items-center gap-3 mt-0.5">
                      {gateway.location && (
                        <span className="flex items-center gap-1 text-[10px] text-zinc-600">
                          <MapPin size={10} />
                          {gateway.location}
                        </span>
                      )}
                      <span className={`flex items-center gap-1 text-[10px] font-bold ${gateway.isOnline ? "text-green-500" : "text-zinc-600"}`}>
                        {gateway.isOnline ? <Wifi size={10} /> : <WifiOff size={10} />}
                        {gateway.isOnline ? "Online" : "Offline"}
                      </span>
                      {gateway.lastSeenAt && (
                        <span className="text-[10px] text-zinc-700">
                          {new Date(gateway.lastSeenAt).toLocaleTimeString()}
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Open Door button */}
                  <button
                    onClick={() => handleRemoteUnlock(gateway)}
                    disabled={isUnlocking || !gateway.isOnline}
                    className={`flex items-center gap-2 px-4 py-2.5 rounded-xl font-black text-[10px] uppercase tracking-widest transition-all shrink-0 shadow-lg ${
                      didUnlock
                        ? "bg-green-500 text-white shadow-green-500/20"
                        : gateway.isOnline
                        ? "bg-[#F1C40F] !text-black hover:bg-[#F4D03F] shadow-[#F1C40F]/10 active:scale-95"
                        : "bg-zinc-800 text-zinc-600 cursor-not-allowed"
                    }`}
                    title={gateway.isOnline ? "Send remote unlock command" : "Gateway offline"}
                  >
                    {isUnlocking ? (
                      <RefreshCw size={14} className="animate-spin" />
                    ) : didUnlock ? (
                      <><Check size={14} /> Unlocked</>
                    ) : (
                      <><Unlock size={14} /> Open Door</>
                    )}
                  </button>

                  {/* Delete */}
                  <button
                    onClick={() => handleDelete(gateway)}
                    disabled={deleteMutation.isPending}
                    className="p-1.5 text-zinc-700 hover:text-red-400 transition-colors rounded-lg hover:bg-red-500/10"
                    title="Remove gateway"
                  >
                    <Trash2 size={14} />
                  </button>

                  {/* Expand toggle */}
                  <button
                    onClick={() => setExpandedGateway(isExpanded ? null : gateway.id)}
                    className="p-1.5 text-zinc-600 hover:text-zinc-400 transition-colors"
                  >
                    {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                  </button>
                </div>

                {/* Expanded details */}
                {isExpanded && (
                  <div className="px-4 pb-4 pt-0 border-t border-white/5 mt-1 space-y-3">
                    <div className="grid grid-cols-2 gap-3 pt-3">
                      <div className="bg-zinc-900 rounded-xl p-3">
                        <p className="text-[10px] font-black text-zinc-600 uppercase tracking-widest mb-1">Gateway ID</p>
                        <p className="text-xs font-mono text-zinc-400 break-all">{gateway.id}</p>
                      </div>
                      <div className="bg-zinc-900 rounded-xl p-3">
                        <p className="text-[10px] font-black text-zinc-600 uppercase tracking-widest mb-1">Commands Sent</p>
                        <p className="text-2xl font-black text-white">{gateway._count?.commands ?? 0}</p>
                      </div>
                    </div>
                    <div className="bg-zinc-900/50 rounded-xl p-3 border border-zinc-800">
                      <p className="text-[10px] font-black text-zinc-600 uppercase tracking-widest mb-2">API Integration</p>
                      <p className="text-[10px] font-mono text-zinc-500">POST /api/hardware/gw/validate</p>
                      <p className="text-[10px] font-mono text-zinc-500">Header: X-Gateway-Key: &lt;api-key&gt;</p>
                      <p className="text-[10px] text-zinc-600 mt-1">Body: {"{ cardUid, doorId? }"}</p>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {showRegisterModal && (
        <RegisterGatewayModal
          gymId={gymId}
          token={token}
          onClose={() => setShowRegisterModal(false)}
        />
      )}
    </div>
  );
}

// ─── Card Type Config ─────────────────────────────────────────────────────────

const CARD_TYPES: Record<string, { label: string; shortLabel: string; color: string; bg: string; border: string; description: string }> = {
  NFC_MIFARE: {
    label: "MIFARE Classic",
    shortLabel: "MIFARE",
    color: "text-blue-400",
    bg: "bg-blue-500/10",
    border: "border-blue-500/20",
    description: "13.56MHz — most gym fobs & key cards",
  },
  NFC_DESFIRE: {
    label: "MIFARE DESFire",
    shortLabel: "DESFire",
    color: "text-purple-400",
    bg: "bg-purple-500/10",
    border: "border-purple-500/20",
    description: "13.56MHz — high-security smart card",
  },
  PHONE_HCE: {
    label: "Phone HCE",
    shortLabel: "HCE",
    color: "text-green-400",
    bg: "bg-green-500/10",
    border: "border-green-500/20",
    description: "Android/iOS NFC virtual card",
  },
  RFID_125KHZ: {
    label: "RFID 125kHz",
    shortLabel: "125kHz",
    color: "text-orange-400",
    bg: "bg-orange-500/10",
    border: "border-orange-500/20",
    description: "EM4100/HID Prox (legacy readers)",
  },
};

// ─── EnrollCardModal ──────────────────────────────────────────────────────────

function EnrollCardModal({
  gymId,
  token,
  onClose,
}: {
  gymId: string;
  token: string;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const [memberQuery, setMemberQuery] = useState("");
  const [selectedMember, setSelectedMember] = useState<MemberSearchResult | null>(null);
  const [cardUid, setCardUid] = useState("");
  const [cardType, setCardType] = useState("NFC_MIFARE");
  const [label, setLabel] = useState("");
  const [showDropdown, setShowDropdown] = useState(false);
  const searchRef = useRef<HTMLDivElement>(null);

  const { data: searchResults, isFetching: isSearching } = useQuery({
    queryKey: ["member-search", gymId, memberQuery],
    queryFn: () => branchApi.searchMembers(gymId, memberQuery, token, 8),
    enabled: !!memberQuery && memberQuery.length >= 2,
    staleTime: 10_000,
  });

  const enrollMutation = useMutation({
    mutationFn: () =>
      hardwareApi.enrollCard(
        { gymId, userId: selectedMember!.id, cardUid: cardUid.trim().toUpperCase(), cardType, label: label.trim() || undefined },
        token
      ),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["cards", gymId] });
      onClose();
    },
  });

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setShowDropdown(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  const canSubmit = selectedMember && cardUid.trim().length >= 4 && !enrollMutation.isPending;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-[#0D1117] border border-zinc-800 rounded-2xl w-full max-w-lg shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-zinc-800/60">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-[#F1C40F]/10 rounded-xl">
              <CreditCard size={18} className="text-[#F1C40F]" />
            </div>
            <div>
              <h3 className="font-black text-white text-base">Enroll NFC Card / Fob</h3>
              <p className="text-[11px] text-zinc-500 mt-0.5">Link a physical card to a member</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 text-zinc-600 hover:text-white transition-colors rounded-lg hover:bg-zinc-800">
            <X size={18} />
          </button>
        </div>

        <div className="p-6 space-y-5">
          {/* Member Search */}
          <div ref={searchRef} className="relative">
            <label className="block text-[11px] font-black text-zinc-500 uppercase tracking-widest mb-2">Member</label>
            {selectedMember ? (
              <div className="flex items-center gap-3 p-3 bg-zinc-900 border border-zinc-700 rounded-xl">
                <div className="w-8 h-8 rounded-full bg-[#F1C40F]/10 flex items-center justify-center text-[#F1C40F] font-black text-sm shrink-0">
                  {selectedMember.fullName.charAt(0).toUpperCase()}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-white text-sm font-bold truncate">{selectedMember.fullName}</p>
                  <p className="text-zinc-500 text-[11px] truncate">{selectedMember.email}</p>
                </div>
                <button
                  onClick={() => { setSelectedMember(null); setMemberQuery(""); }}
                  className="p-1 text-zinc-600 hover:text-white rounded"
                >
                  <X size={14} />
                </button>
              </div>
            ) : (
              <div className="relative">
                <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-600 pointer-events-none" />
                <input
                  type="text"
                  value={memberQuery}
                  onChange={(e) => { setMemberQuery(e.target.value); setShowDropdown(true); }}
                  onFocus={() => memberQuery.length >= 2 && setShowDropdown(true)}
                  placeholder="Search by name or email..."
                  className="w-full pl-9 pr-4 py-3 bg-zinc-900 border border-zinc-800 rounded-xl text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/50 transition-colors"
                />
                {isSearching && (
                  <RefreshCw size={14} className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-600 animate-spin" />
                )}
              </div>
            )}

            {/* Dropdown */}
            {showDropdown && !selectedMember && memberQuery.length >= 2 && (
              <div className="absolute top-full left-0 right-0 mt-1 bg-[#0D1117] border border-zinc-800 rounded-xl shadow-xl z-50 overflow-hidden">
                {searchResults && searchResults.length > 0 ? (
                  searchResults.map((member) => (
                    <button
                      key={member.id}
                      onClick={() => { setSelectedMember(member); setMemberQuery(""); setShowDropdown(false); }}
                      className="w-full flex items-center gap-3 px-4 py-3 hover:bg-zinc-800/60 transition-colors text-left"
                    >
                      <div className="w-7 h-7 rounded-full bg-zinc-800 flex items-center justify-center text-zinc-300 font-black text-xs shrink-0">
                        {member.fullName.charAt(0).toUpperCase()}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-white text-sm font-medium truncate">{member.fullName}</p>
                        <p className="text-zinc-600 text-[11px] truncate">{member.email}</p>
                      </div>
                      {member.memberships?.[0] && (
                        <span className="text-[10px] px-2 py-0.5 bg-green-500/10 text-green-400 rounded-full shrink-0 font-bold">
                          Active
                        </span>
                      )}
                    </button>
                  ))
                ) : !isSearching ? (
                  <div className="px-4 py-4 text-sm text-zinc-500 text-center">No members found</div>
                ) : null}
              </div>
            )}
          </div>

          {/* Card UID */}
          <div>
            <label className="block text-[11px] font-black text-zinc-500 uppercase tracking-widest mb-2">Card UID / Serial Number</label>
            <input
              type="text"
              value={cardUid}
              onChange={(e) => setCardUid(e.target.value)}
              placeholder="e.g. A3 F2 90 1C or 04:A3:F2:90:1C:2B:80"
              className="w-full px-4 py-3 bg-zinc-900 border border-zinc-800 rounded-xl text-sm font-mono text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/50 transition-colors"
            />
            <p className="text-[10px] text-zinc-600 mt-1.5">Tap the card on the MFRC522 reader — the UID is printed in the Amirani gateway logs.</p>
          </div>

          {/* Card Type */}
          <div>
            <label className="block text-[11px] font-black text-zinc-500 uppercase tracking-widest mb-2">Card Type</label>
            <div className="grid grid-cols-2 gap-2">
              {Object.entries(CARD_TYPES).map(([key, ct]) => (
                <button
                  key={key}
                  onClick={() => setCardType(key)}
                  className={`flex flex-col items-start p-3 rounded-xl border transition-all text-left ${
                    cardType === key
                      ? `${ct.bg} ${ct.border} border`
                      : "bg-zinc-900 border-zinc-800 hover:border-zinc-700"
                  }`}
                >
                  <div className="flex items-center gap-2 mb-0.5">
                    <div className={`w-2 h-2 rounded-full ${cardType === key ? ct.color.replace("text-", "bg-") : "bg-zinc-700"}`} />
                    <span className={`text-xs font-black ${cardType === key ? ct.color : "text-zinc-400"}`}>{ct.label}</span>
                  </div>
                  <p className="text-[10px] text-zinc-600 leading-tight">{ct.description}</p>
                </button>
              ))}
            </div>
          </div>

          {/* Label (optional) */}
          <div>
            <label className="block text-[11px] font-black text-zinc-500 uppercase tracking-widest mb-2">
              Label <span className="text-zinc-700 normal-case font-normal">(optional)</span>
            </label>
            <input
              type="text"
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              placeholder="e.g. Blue key fob, Main entrance card..."
              className="w-full px-4 py-3 bg-zinc-900 border border-zinc-800 rounded-xl text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/50 transition-colors"
            />
          </div>

          {enrollMutation.isError && (
            <div className="p-3 bg-red-500/10 border border-red-500/20 rounded-xl text-sm text-red-400">
              Failed to enroll card. Check the UID format and try again.
            </div>
          )}
        </div>

        <div className="flex gap-3 p-6 pt-0">
          <button
            onClick={onClose}
            className="flex-1 py-3 bg-zinc-800 text-zinc-300 font-black rounded-xl hover:bg-zinc-700 transition-all text-[10px] uppercase tracking-widest border border-white/5"
          >
            Cancel
          </button>
          <button
            onClick={() => enrollMutation.mutate()}
            disabled={!canSubmit}
            className={`flex-1 py-3 font-black rounded-xl text-sm flex items-center justify-center gap-2 transition-all uppercase tracking-widest ${
              canSubmit
                ? "bg-[#F1C40F] !text-black hover:bg-[#F4D03F] shadow-lg shadow-[#F1C40F]/10"
                : "bg-zinc-800 text-zinc-600 cursor-not-allowed"
            }`}
          >
            {enrollMutation.isPending ? (
              <><RefreshCw size={14} className="animate-spin" /> Enrolling...</>
            ) : (
              <><CreditCard size={14} /> Enroll Card</>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── CardManagementPanel ──────────────────────────────────────────────────────

function CardManagementPanel({ gymId, token }: { gymId: string; token: string }) {
  const queryClient = useQueryClient();
  const [showEnrollModal, setShowEnrollModal] = useState(false);
  const [filterQuery, setFilterQuery] = useState("");
  const [filterType, setFilterType] = useState<string>("ALL");

  const { data: cards, isLoading } = useQuery({
    queryKey: ["cards", gymId],
    queryFn: () => hardwareApi.getCards(gymId, token),
    refetchInterval: 30_000,
  });

  const revokeMutation = useMutation({
    mutationFn: (cardId: string) => hardwareApi.revokeCard(cardId, gymId, token),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["cards", gymId] }),
  });

  const handleRevoke = (card: CardCredential) => {
    const name = card.user?.fullName || "this member";
    if (confirm(`Revoke card "${card.label || card.cardUid}" for ${name}? They will no longer be able to access the gym with this card.`)) {
      revokeMutation.mutate(card.id);
    }
  };

  const filtered = cards?.filter((c) => {
    const matchesType = filterType === "ALL" || c.cardType === filterType;
    const q = filterQuery.toLowerCase();
    const matchesQuery = !q || (
      c.user?.fullName?.toLowerCase().includes(q) ||
      c.cardUid.toLowerCase().includes(q) ||
      c.label?.toLowerCase().includes(q)
    );
    return matchesType && matchesQuery;
  }) ?? [];

  const activeCount = cards?.filter((c) => c.isActive).length ?? 0;
  const typeBreakdown = Object.keys(CARD_TYPES).map((k) => ({
    key: k,
    count: cards?.filter((c) => c.cardType === k && c.isActive).length ?? 0,
  })).filter((x) => x.count > 0);

  return (
    <div className="space-y-6">
      {/* Section Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-white/5">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-[#F1C40F]/10 rounded-2xl">
            <CreditCard size={22} className="text-[#F1C40F]" />
          </div>
          <div>
            <h2 className="text-xl font-black text-white tracking-tight flex items-center gap-2 italic">
              NFC CARD MANAGEMENT
              {!isLoading && (
                <span className="text-sm font-medium text-zinc-500 normal-case not-italic">
                  {activeCount} active {activeCount === 1 ? "card" : "cards"}
                </span>
              )}
            </h2>
            <p className="text-xs text-zinc-500 mt-0.5">Enroll MIFARE fobs, DESFire cards, and Phone HCE virtual credentials</p>
          </div>
        </div>
        <button
          onClick={() => setShowEnrollModal(true)}
          className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all text-[10px] uppercase tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
        >
          <UserPlus size={15} />
          Enroll Card
        </button>
      </div>

      {/* Stats row */}
      {typeBreakdown.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {typeBreakdown.map(({ key, count }) => {
            const ct = CARD_TYPES[key];
            return (
              <button
                key={key}
                onClick={() => setFilterType(filterType === key ? "ALL" : key)}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-[11px] font-bold transition-all ${
                  filterType === key ? `${ct.bg} ${ct.border} ${ct.color}` : "bg-zinc-900 border-zinc-800 text-zinc-500 hover:border-zinc-700"
                }`}
              >
                <span className={`w-1.5 h-1.5 rounded-full ${filterType === key ? ct.color.replace("text-", "bg-") : "bg-zinc-600"}`} />
                {ct.label}
                <span className={`px-1.5 py-0.5 rounded-full text-[9px] font-black ${filterType === key ? "bg-white/10" : "bg-zinc-800"}`}>
                  {count}
                </span>
              </button>
            );
          })}
        </div>
      )}

      {/* Search filter */}
      <div className="relative">
        <Search size={14} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600 pointer-events-none" />
        <input
          type="text"
          value={filterQuery}
          onChange={(e) => setFilterQuery(e.target.value)}
          placeholder="Search by member name, card UID, or label..."
          className="w-full pl-10 pr-4 py-3 bg-[#121721] border border-zinc-800 rounded-xl text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-zinc-700 transition-colors"
        />
      </div>

      {/* Card list */}
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl overflow-hidden">
        {isLoading ? (
          <div className="py-16 flex flex-col items-center gap-3 text-zinc-500">
            <RefreshCw size={28} className="animate-spin text-[#F1C40F]" />
            <span className="text-sm">Loading cards...</span>
          </div>
        ) : filtered.length === 0 ? (
          <div className="py-16 flex flex-col items-center gap-4 text-center px-6">
            <div className="p-4 bg-zinc-900 rounded-2xl">
              <CreditCard size={36} className="text-zinc-600" />
            </div>
            <div>
              <p className="text-zinc-300 font-bold text-sm">
                {cards?.length === 0 ? "No cards enrolled yet" : "No cards match your search"}
              </p>
              <p className="text-zinc-600 text-xs mt-1">
                {cards?.length === 0
                  ? "Enroll MIFARE fobs or NFC cards to allow members to tap into the gym."
                  : "Try a different name, UID, or clear the filter."}
              </p>
            </div>
            {cards?.length === 0 && (
              <button
                onClick={() => setShowEnrollModal(true)}
                className="px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
              >
                Enroll First Card
              </button>
            )}
          </div>
        ) : (
          <div className="divide-y divide-zinc-800/60">
            {/* Table header */}
            <div className="grid grid-cols-[auto_1fr_auto_auto_auto] gap-4 px-5 py-2.5 items-center">
              <div className="w-9" />
              <div className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Member / Label</div>
              <div className="text-[10px] font-black text-zinc-600 uppercase tracking-widest w-28 text-center hidden sm:block">Type</div>
              <div className="text-[10px] font-black text-zinc-600 uppercase tracking-widest w-32 hidden md:block">Card UID</div>
              <div className="w-20" />
            </div>

            {filtered.map((card) => {
              const ct = CARD_TYPES[card.cardType] ?? CARD_TYPES.NFC_MIFARE;
              const isRevoking = revokeMutation.isPending && revokeMutation.variables === card.id;
              return (
                <div
                  key={card.id}
                  className={`grid grid-cols-[auto_1fr_auto_auto_auto] gap-4 px-5 py-4 items-center hover:bg-zinc-800/20 transition-colors ${
                    !card.isActive ? "opacity-50" : ""
                  }`}
                >
                  {/* Avatar */}
                  <div className="w-9 h-9 rounded-full bg-zinc-800 flex items-center justify-center text-zinc-300 font-black text-sm shrink-0">
                    {card.user?.fullName?.charAt(0)?.toUpperCase() ?? <CreditCard size={14} />}
                  </div>

                  {/* Name + label */}
                  <div className="min-w-0">
                    <p className="text-white text-sm font-bold truncate">
                      {card.user?.fullName ?? "Unknown Member"}
                    </p>
                    {card.label ? (
                      <p className="text-zinc-500 text-xs truncate">{card.label}</p>
                    ) : (
                      <p className="text-zinc-700 text-xs truncate font-mono">{card.cardUid}</p>
                    )}
                  </div>

                  {/* Type badge */}
                  <div className={`hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-full border w-28 justify-center ${ct.bg} ${ct.border}`}>
                    <span className={`w-1.5 h-1.5 rounded-full ${ct.color.replace("text-", "bg-")}`} />
                    <span className={`text-[10px] font-black ${ct.color}`}>{ct.shortLabel}</span>
                  </div>

                  {/* Card UID */}
                  <div className="hidden md:block w-32">
                    <span className="text-[10px] font-mono text-zinc-600 bg-zinc-900 px-2 py-1 rounded-lg block text-center truncate">
                      {card.cardUid.length > 14 ? card.cardUid.slice(0, 14) + "…" : card.cardUid}
                    </span>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-1 w-20 justify-end">
                    {!card.isActive ? (
                      <span className="text-[10px] text-red-500 font-bold uppercase">Revoked</span>
                    ) : (
                      <button
                        onClick={() => handleRevoke(card)}
                        disabled={isRevoking}
                        title="Revoke access for this card"
                        className="flex items-center gap-1.5 px-3 py-1.5 bg-red-500/10 text-red-400 border border-red-500/20 rounded-lg text-[10px] font-black uppercase tracking-widest hover:bg-red-500/20 transition-all disabled:opacity-50"
                      >
                        {isRevoking ? <RefreshCw size={10} className="animate-spin" /> : <X size={10} />}
                        Revoke
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {showEnrollModal && (
        <EnrollCardModal gymId={gymId} token={token} onClose={() => setShowEnrollModal(false)} />
      )}
    </div>
  );
}

// ─── AccessStatsPanel ─────────────────────────────────────────────────────────

function AccessStatsPanel({ gymId, token }: { gymId: string; token: string }) {
  const { data: stats, isLoading } = useQuery({
    queryKey: ["access-stats", gymId],
    queryFn: () => hardwareApi.getStats(gymId, token),
    refetchInterval: 60_000,
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-20 gap-3 text-zinc-500">
        <RefreshCw size={22} className="animate-spin text-[#F1C40F]" />
        <span className="text-sm">Loading statistics...</span>
      </div>
    );
  }

  if (!stats || stats.total === 0) {
    return (
      <div className="py-20 flex flex-col items-center gap-4 text-center">
        <div className="p-4 bg-zinc-900 rounded-2xl"><TrendingUp size={36} className="text-zinc-600" /></div>
        <div>
          <p className="text-zinc-300 font-bold text-sm">No access data yet</p>
          <p className="text-zinc-600 text-xs mt-1">Statistics will appear once members start scanning in</p>
        </div>
      </div>
    );
  }

  const peakHour = stats.peakHours.reduce((a, b) => (b.count > a.count ? b : a), { hour: 0, count: 0 });
  const peakMax = Math.max(...stats.peakHours.map((h) => h.count), 1);
  const dailyMax = Math.max(...stats.dailyTrend.map((d) => d.granted + d.denied), 1);

  return (
    <div className="space-y-8">
      {/* KPI row */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: "Total Scans", value: stats.total, color: "text-white", sub: "last 30 days" },
          { label: "Access Granted", value: stats.granted, color: "text-green-400", sub: `${stats.grantRate}% success rate` },
          { label: "Access Denied", value: stats.denied, color: "text-red-400", sub: "unauthorized attempts" },
          { label: "Peak Hour", value: `${peakHour.hour}:00`, color: "text-[#F1C40F]", sub: `${peakHour.count} entries` },
        ].map(({ label, value, color, sub }) => (
          <div key={label} className="bg-[#121721] border border-zinc-800 rounded-2xl p-5">
            <p className="text-[10px] font-black text-zinc-600 uppercase tracking-widest mb-2">{label}</p>
            <p className={`text-3xl font-black ${color}`}>{value}</p>
            <p className="text-[10px] text-zinc-600 mt-1">{sub}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Daily trend — last 14 days */}
        <div className="lg:col-span-2 bg-[#121721] border border-zinc-800 rounded-2xl p-5 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-black text-white flex items-center gap-2 italic">
              <TrendingUp size={14} className="text-[#F1C40F]" /> 14-Day Trend
            </h3>
            <div className="flex items-center gap-3 text-[10px]">
              <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-green-500 inline-block" /> Granted</span>
              <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-red-500 inline-block" /> Denied</span>
            </div>
          </div>
          <div className="flex items-end gap-1 h-32">
            {stats.dailyTrend.map((day) => {
              const total = day.granted + day.denied;
              const grantedH = total > 0 ? (day.granted / dailyMax) * 100 : 0;
              const deniedH = total > 0 ? (day.denied / dailyMax) * 100 : 0;
              return (
                <div key={day.date} className="flex-1 flex flex-col items-center gap-0.5 group relative">
                  <div className="absolute bottom-6 left-1/2 -translate-x-1/2 bg-zinc-900 border border-zinc-700 rounded-lg px-2 py-1 text-[9px] text-white whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-10">
                    {day.date.slice(5)}: {day.granted}✓ {day.denied}✗
                  </div>
                  <div className="w-full flex flex-col-reverse gap-0.5" style={{ height: "100px" }}>
                    <div className="w-full rounded-sm bg-green-500/70 transition-all" style={{ height: `${grantedH}%`, minHeight: total > 0 ? "2px" : 0 }} />
                    <div className="w-full rounded-sm bg-red-500/50 transition-all" style={{ height: `${deniedH}%`, minHeight: day.denied > 0 ? "2px" : 0 }} />
                  </div>
                  <span className="text-[8px] text-zinc-700 mt-1">{day.date.slice(8)}</span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Top members */}
        <div className="bg-[#121721] border border-zinc-800 rounded-2xl p-5 space-y-3">
          <h3 className="text-sm font-black text-white flex items-center gap-2 italic">
            <UserCheck size={14} className="text-[#F1C40F]" /> Top Members
            <span className="text-[10px] text-zinc-600 font-normal normal-case not-italic">last 30 days</span>
          </h3>
          {stats.topMembers.length === 0 ? (
            <p className="text-zinc-600 text-xs py-4 text-center">No data yet</p>
          ) : (
            <div className="space-y-2">
              {stats.topMembers.slice(0, 6).map((m, i) => (
                <div key={m.userId} className="flex items-center gap-3">
                  <span className="text-[10px] text-zinc-600 w-4 text-right shrink-0">{i + 1}</span>
                  <div className="w-7 h-7 rounded-full bg-zinc-800 flex items-center justify-center text-zinc-400 font-black text-xs shrink-0">
                    {m.fullName.charAt(0).toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-white text-xs font-bold truncate">{m.fullName}</p>
                  </div>
                  <span className="text-[10px] font-black text-[#F1C40F] shrink-0">{m.count}×</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Peak hours heatmap */}
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl p-5 space-y-4">
        <h3 className="text-sm font-black text-white flex items-center gap-2 italic">
          <Clock size={14} className="text-[#F1C40F]" /> Peak Hours
          <span className="text-[10px] text-zinc-600 font-normal normal-case not-italic">granted entries by hour · last 30 days</span>
        </h3>
        <div className="flex items-end gap-1 h-16">
          {stats.peakHours.map(({ hour, count }) => (
            <div key={hour} className="flex-1 flex flex-col items-center gap-1 group relative">
              {count > 0 && (
                <div className="absolute bottom-8 left-1/2 -translate-x-1/2 bg-zinc-900 border border-zinc-700 rounded-lg px-2 py-1 text-[9px] text-white whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity z-10">
                  {hour}:00 — {count} entries
                </div>
              )}
              <div
                className="w-full rounded-sm transition-all"
                style={{
                  height: `${Math.max((count / peakMax) * 48, count > 0 ? 4 : 2)}px`,
                  background: count > 0
                    ? `rgba(241,196,15,${0.2 + (count / peakMax) * 0.8})`
                    : "rgba(39,39,42,0.5)",
                }}
              />
              <span className="text-[8px] text-zinc-700">{hour === 0 ? "12a" : hour === 12 ? "12p" : hour < 12 ? `${hour}a` : `${hour - 12}p`}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function AccessPage() {
  const { token, user } = useAuthStore();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [showModal, setShowModal] = useState(false);
  const [editingSystem, setEditingSystem] = useState<DoorSystem | null>(null);
  const [qrSystem, setQrSystem] = useState<DoorSystem | null>(null);
  const [guideSystemId, setGuideSystemId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<"overview" | "access-points" | "gateways" | "cards" | "stats">("overview");

  // Unified gym selection
  const { gyms, selectedGymId, isGymsLoading: gymsLoading } = useGymSelection();

  // Role guard - redirect if not branch admin or above
  useEffect(() => {
    if (user && !isBranchAdminOrAbove(user.role)) {
      router.push("/dashboard");
    }
  }, [user, router]);

  // Get door systems for selected gym
  const { data: doorSystems, isLoading: systemsLoading } = useQuery({
    queryKey: ["door-systems", selectedGymId],
    queryFn: () => doorAccessApi.getGymSystems(selectedGymId!, token!),
    enabled: !!token && !!selectedGymId,
  });

  // Get access logs for selected gym
  const { data: logs, isLoading: logsLoading } = useQuery({
    queryKey: ["access-logs", selectedGymId],
    queryFn: () => doorAccessApi.getGymLogs(selectedGymId!, token!),
    enabled: !!token && !!selectedGymId,
    refetchInterval: 5000, // Refresh every 5 seconds for real-time feel
  });

  // Get door systems health
  const { data: systemsHealth } = useQuery({
    queryKey: ["door-health", selectedGymId],
    queryFn: () => doorAccessApi.checkHealth(selectedGymId!, token!),
    enabled: !!token && !!selectedGymId,
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => doorAccessApi.deleteSystem(id, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["door-systems", selectedGymId] });
      queryClient.invalidateQueries({ queryKey: ["door-health", selectedGymId] });
    },
  });

  const toggleSystemMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      doorAccessApi.updateSystem(id, { isActive }, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["door-systems", selectedGymId] });
      queryClient.invalidateQueries({ queryKey: ["door-health", selectedGymId] });
    },
  });

  // Shared stat queries (cache-shared with sub-components)
  const { data: liveStats } = useQuery({
    queryKey: ["gym-live", selectedGymId],
    queryFn: () => gymLiveApi.getLive(selectedGymId!, token!),
    enabled: !!token && !!selectedGymId,
    refetchInterval: 10_000,
    retry: false,
  });
  const { data: cardsStats } = useQuery({
    queryKey: ["cards", selectedGymId],
    queryFn: () => hardwareApi.getCards(selectedGymId!, token!),
    enabled: !!token && !!selectedGymId,
    refetchInterval: 30_000,
  });
  const { data: gatewaysStats } = useQuery({
    queryKey: ["hardware-gateways", selectedGymId],
    queryFn: () => hardwareApi.getGateways(selectedGymId!, token!),
    enabled: !!token && !!selectedGymId,
    refetchInterval: 30_000,
  });

  // Merge systems with health data
  const systemsWithHealth = doorSystems?.map((system) => {
    const health = systemsHealth?.find((h) => h.id === system.id);
    return { ...system, isHealthy: health?.isHealthy ?? true };
  });

  const handleDeleteSystem = (system: DoorSystem) => {
    if (confirm(`Delete "${system.name}"? This action cannot be undone.`)) {
      deleteMutation.mutate(system.id);
    }
  };

  const onlineGateways = gatewaysStats?.filter((g) => g.isOnline).length ?? 0;
  const totalGateways = gatewaysStats?.length ?? 0;
  const activeCards = cardsStats?.filter((c) => c.isActive).length ?? 0;

  const TABS = [
    { key: "overview" as const,       label: "Overview",      icon: Activity },
    { key: "access-points" as const,  label: "Access Points", icon: Cpu,        badge: systemsWithHealth?.length },
    { key: "gateways" as const,       label: "Gateways",      icon: Server,     badge: totalGateways },
    { key: "cards" as const,          label: "NFC Cards",     icon: CreditCard, badge: activeCards },
    { key: "stats" as const,          label: "Statistics",    icon: TrendingUp },
  ];

  return (
    <div className="space-y-8">
      <PageHeader
        title="DOOR ACCESS"
        description="Manage door systems and monitor real-time entry logs"
        icon={<LogIn size={32} />}
        actions={<GymSwitcher gyms={gyms} isLoading={gymsLoading} />}
      />

      {selectedGymId && token ? (
        <>
          {/* ── Stats row ───────────────────────────────────────────────── */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {[
              {
                icon: Users,
                label: "Now In",
                value: liveStats?.currentOccupancy ?? "—",
                color: !liveStats ? "text-zinc-500" : (liveStats.occupancyPercent ?? 0) >= 90 ? "text-red-400" : (liveStats.occupancyPercent ?? 0) >= 70 ? "text-yellow-400" : "text-green-400",
                sub: liveStats?.maxCapacity ? `of ${liveStats.maxCapacity} capacity` : "real-time",
                pulse: true,
              },
              {
                icon: TrendingUp,
                label: "Today's Entries",
                value: liveStats?.todayCheckIns ?? "—",
                color: "text-blue-400",
                sub: "total check-ins",
                pulse: false,
              },
              {
                icon: CreditCard,
                label: "Active Cards",
                value: activeCards || (cardsStats ? "0" : "—"),
                color: activeCards > 0 ? "text-purple-400" : "text-zinc-500",
                sub: "enrolled credentials",
                pulse: false,
              },
              {
                icon: Server,
                label: "Gateways",
                value: totalGateways === 0 ? "—" : `${onlineGateways}/${totalGateways}`,
                color: onlineGateways > 0 ? "text-green-400" : totalGateways > 0 ? "text-red-400" : "text-zinc-500",
                sub: onlineGateways > 0 ? "online" : totalGateways > 0 ? "all offline" : "none registered",
                pulse: onlineGateways > 0,
              },
            ].map(({ icon: Icon, label, value, color, sub, pulse }) => (
              <div key={label} className="bg-[#0e1420] border border-white/5 rounded-2xl p-5 relative overflow-hidden">
                <div className="flex items-center gap-2 mb-3">
                  <Icon size={13} className="text-zinc-600" />
                  <span className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">{label}</span>
                  {pulse && <span className="ml-auto w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />}
                </div>
                <div className={`text-3xl font-black ${color}`}>{value}</div>
                <div className="text-[10px] text-zinc-700 mt-1">{sub}</div>
              </div>
            ))}
          </div>

          {/* ── Unified panel ───────────────────────────────────────────── */}
          <div className="bg-[#0e1420] border border-white/5 rounded-2xl overflow-hidden">
            {/* Tab bar */}
            <div className="flex items-center border-b border-white/5 px-2 overflow-x-auto">
              {TABS.map(({ key, label, icon: Icon, badge }) => (
                <button
                  key={key}
                  onClick={() => setActiveTab(key)}
                  className={`flex items-center gap-2.5 px-6 py-4 text-[11px] font-black uppercase tracking-widest border-b-2 transition-all -mb-px whitespace-nowrap ${
                    activeTab === key
                      ? "border-[#F1C40F] text-[#F1C40F]"
                      : "border-transparent text-zinc-600 hover:text-zinc-300"
                  }`}
                >
                  <Icon size={13} />
                  {label}
                  {badge !== undefined && badge > 0 && (
                    <span className={`text-[9px] px-1.5 py-0.5 rounded-full font-black ${
                      activeTab === key ? "bg-[#F1C40F]/20 text-[#F1C40F]" : "bg-zinc-800 text-zinc-500"
                    }`}>
                      {badge}
                    </span>
                  )}
                </button>
              ))}

              {/* Context-aware CTA */}
              <div className="ml-auto pr-4 shrink-0">
                {activeTab === "access-points" && (
                  <button
                    onClick={() => { setEditingSystem(null); setShowModal(true); }}
                    className="flex items-center justify-center gap-2 px-6 py-2.5 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
                  >
                    <QrCode size={14} /> Add QR System
                  </button>
                )}
              </div>
            </div>

            {/* Tab content */}
            <div className="p-6">

              {/* ─ Overview ─ */}
              {activeTab === "overview" && (
                <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
                  {/* Live panel (compacted) */}
                  <div className="lg:col-span-2">
                    <LiveOccupancyPanel gymId={selectedGymId} token={token} />
                  </div>

                  {/* Activity feed */}
                  <div className="lg:col-span-3 space-y-3">
                    <h3 className="text-sm font-black text-white flex items-center gap-2 italic">
                      <Clock size={14} className="text-[#F1C40F]" />
                      Recent Activity
                      <span className="text-[10px] text-zinc-600 font-normal normal-case ml-1 not-italic">live · refreshes every 5s</span>
                    </h3>
                    <div className="bg-[#121721] border border-zinc-800/60 rounded-2xl overflow-hidden max-h-[480px] overflow-y-auto">
                      <div className="divide-y divide-zinc-800/60">
                        {logsLoading ? (
                          <div className="p-10 flex items-center justify-center gap-3 text-zinc-500">
                            <RefreshCw size={18} className="animate-spin text-[#F1C40F]" />
                            <span className="text-sm">Loading activity...</span>
                          </div>
                        ) : !logs?.length ? (
                          <div className="p-10 text-center">
                            <LogIn className="mx-auto text-zinc-700 mb-3" size={36} />
                            <p className="text-zinc-500 text-sm">No access events yet</p>
                            <p className="text-zinc-700 text-xs mt-1">Entry events will appear here as members scan in</p>
                          </div>
                        ) : (
                          logs.map((log) => (
                            <div key={log.id} className="px-5 py-3.5 flex items-center gap-4 hover:bg-zinc-800/20 transition-colors">
                              <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${
                                log.accessGranted ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"
                              }`}>
                                {log.accessGranted ? <ShieldCheck size={15} /> : <ShieldAlert size={15} />}
                              </div>
                              <div className="flex-1 min-w-0">
                                <div className="flex items-center gap-2 flex-wrap">
                                  <span className="font-bold text-white text-sm truncate">{log.user?.fullName || "Unknown"}</span>
                                  <span className="text-[10px] text-zinc-600">·</span>
                                  <span className="text-[11px] text-zinc-500 truncate">{log.doorSystem.name}</span>
                                </div>
                                <div className="text-[10px] text-zinc-600 mt-0.5 flex items-center gap-2">
                                  <span>{new Date(log.accessTime).toLocaleTimeString()}</span>
                                  <span>·</span>
                                  <span className="uppercase">{log.method.replace("_", " ")}</span>
                                </div>
                              </div>
                              <span className={`text-[10px] font-black uppercase shrink-0 ${
                                log.accessGranted ? "text-green-400" : "text-red-400"
                              }`}>
                                {log.accessGranted ? "Granted" : "Denied"}
                              </span>
                            </div>
                          ))
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* ─ Access Points ─ */}
              {activeTab === "access-points" && (
                <div className="space-y-5">
                  {/* Explanation banner */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div className="flex items-start gap-3 p-4 bg-[#F1C40F]/5 border border-[#F1C40F]/10 rounded-2xl">
                      <QrCode size={18} className="text-[#F1C40F] shrink-0 mt-0.5" />
                      <div>
                        <p className="text-xs font-black text-white">QR Code — No Hardware</p>
                        <p className="text-[11px] text-zinc-500 mt-0.5">Print the QR, members scan with the Amirani app. Add manually here.</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-3 p-4 bg-zinc-900 border border-zinc-800 rounded-2xl">
                      <Server size={18} className="text-zinc-500 shrink-0 mt-0.5" />
                      <div>
                        <p className="text-xs font-black text-zinc-300">NFC / PIN / BT — Hardware</p>
                        <p className="text-[11px] text-zinc-600 mt-0.5">Auto-created when you register a Gateway. Manage those in the Gateways tab.</p>
                      </div>
                    </div>
                  </div>

                  {systemsLoading ? (
                    <div className="flex items-center justify-center py-16">
                      <RefreshCw className="animate-spin text-[#F1C40F]" size={24} />
                    </div>
                  ) : !systemsWithHealth?.length ? (
                    <div className="py-12 flex flex-col items-center gap-4 text-center">
                      <div className="p-4 bg-zinc-900 rounded-2xl">
                        <QrCode size={36} className="text-zinc-600" />
                      </div>
                      <div>
                        <p className="text-zinc-300 font-bold text-sm">No QR access points yet</p>
                        <p className="text-zinc-600 text-xs mt-1">Add a QR code entry — no hardware required</p>
                      </div>
                      <button
                        onClick={() => { setEditingSystem(null); setShowModal(true); }}
                        className="px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
                      >
                        Add QR System
                      </button>
                    </div>
                  ) : (
                    <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
                      {systemsWithHealth.map((system) => {
                        const TypeIcon = getTypeIcon(system.type);
                        return (
                          <div
                            key={system.id}
                            className={`bg-[#121721] border rounded-2xl p-5 transition-colors ${
                              system.isActive ? "border-zinc-800" : "border-red-500/30 opacity-60"
                            }`}
                          >
                            {/* Gateway-managed badge */}
                            {system.type !== "QR_CODE" && (
                              <div className="flex items-center gap-1.5 mb-3 px-2.5 py-1 bg-zinc-900 rounded-lg border border-zinc-800 w-fit">
                                <Server size={9} className="text-zinc-500" />
                                <span className="text-[10px] text-zinc-500 font-bold">Managed by Gateway</span>
                              </div>
                            )}
                            <div className="flex items-start justify-between mb-4">
                              <div className="flex items-center gap-3">
                                <div className={`p-2 rounded-xl ${system.type === "QR_CODE" ? "bg-[#F1C40F]/10" : "bg-zinc-800"}`}>
                                  <TypeIcon size={16} className={system.type === "QR_CODE" ? "text-[#F1C40F]" : "text-zinc-400"} />
                                </div>
                                <div>
                                  <p className="font-bold text-white text-sm">{system.name}</p>
                                  <p className="text-[11px] text-zinc-500 flex items-center gap-1 mt-0.5">
                                    <MapPin size={10} />
                                    {system.location || "Location not set"}
                                  </p>
                                </div>
                              </div>
                              <div className="flex items-center gap-1.5">
                                <span className="text-[10px] font-bold text-zinc-600 uppercase bg-zinc-900 px-2 py-1 rounded-lg">
                                  {system.type.replace("_", " ")}
                                </span>
                                {system.isActive && (
                                  <span className={`w-2 h-2 rounded-full ${
                                    system.isHealthy
                                      ? "bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.5)]"
                                      : "bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.5)]"
                                  }`} />
                                )}
                              </div>
                            </div>

                            <div className="flex gap-2 flex-wrap">
                              {system.type === "QR_CODE" && (
                                  <button
                                    onClick={() => setQrSystem(system)}
                                    className="flex items-center gap-1.5 px-3 py-1.5 bg-[#F1C40F]/10 text-[#F1C40F] rounded-lg text-[10px] font-black uppercase tracking-widest hover:bg-[#F1C40F]/20 transition-all border border-[#F1C40F]/20"
                                  >
                                    <QrCode size={12} /> Show QR
                                  </button>
                              )}
                              <button
                                onClick={() => toggleSystemMutation.mutate({ id: system.id, isActive: !system.isActive })}
                                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all border ${
                                  system.isActive
                                    ? "bg-red-500/10 text-red-400 border-red-500/20 hover:bg-red-500/20"
                                    : "bg-green-500/10 text-green-400 border-green-500/20 hover:bg-green-500/20"
                                }`}
                              >
                                <Power size={12} />
                                {system.isActive ? "Disable" : "Enable"}
                              </button>
                              <button
                                onClick={() => setGuideSystemId(guideSystemId === system.id ? null : system.id)}
                                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all border ${
                                  guideSystemId === system.id
                                    ? "bg-[#F1C40F]/20 text-[#F1C40F] border-[#F1C40F]/30"
                                    : "bg-zinc-800 text-zinc-400 border-transparent hover:border-zinc-700 hover:text-zinc-300"
                                }`}
                              >
                                <BookOpen size={12} /> Guide
                              </button>
                              <button
                                onClick={() => { setEditingSystem(system); setShowModal(true); }}
                                className="p-1.5 bg-zinc-800 text-zinc-400 rounded-lg hover:text-white transition-colors ml-auto"
                              >
                                <Edit2 size={13} />
                              </button>
                              <button
                                onClick={() => handleDeleteSystem(system)}
                                className="p-1.5 bg-zinc-800 text-zinc-400 rounded-lg hover:text-red-400 transition-colors"
                              >
                                <Trash2 size={13} />
                              </button>
                            </div>

                            {/* Inline Setup Guide */}
                            {guideSystemId === system.id && SYSTEM_GUIDES[system.type] && (() => {
                              const guide = SYSTEM_GUIDES[system.type];
                              return (
                                <div className="mt-4 pt-4 border-t border-blue-500/20 space-y-3">
                                  <div className="flex items-center justify-between">
                                    <p className="text-[10px] font-black text-blue-400 uppercase tracking-widest flex items-center gap-1">
                                      <BookOpen size={10} /> Setup Guide
                                    </p>
                                    <span className={`text-[9px] font-black uppercase px-2 py-0.5 rounded-full ${
                                      guide.difficulty === "Easy" ? "bg-green-500/20 text-green-400" :
                                      guide.difficulty === "Medium" ? "bg-yellow-500/20 text-yellow-400" :
                                      "bg-red-500/20 text-red-400"
                                    }`}>{guide.difficulty}</span>
                                  </div>
                                  <p className="text-[10px] text-zinc-500 italic">{guide.tagline}</p>
                                  <div className="text-[10px] text-zinc-500 flex items-center gap-1">
                                    <Cpu size={10} className="shrink-0" />
                                    <span className="font-bold text-zinc-400">Hardware:</span> {guide.hardware}
                                  </div>
                                  <ol className="space-y-1.5">
                                    {guide.steps.map((step, i) => (
                                      <li key={i} className="flex gap-2 text-[10px] text-zinc-400 leading-relaxed">
                                        <span className="shrink-0 w-4 h-4 rounded-full bg-zinc-800 text-zinc-500 flex items-center justify-center font-black text-[9px]">{i + 1}</span>
                                        {step}
                                      </li>
                                    ))}
                                  </ol>
                                  {guide.tip && (
                                    <div className="flex gap-2 p-2.5 bg-[#F1C40F]/5 border border-[#F1C40F]/10 rounded-xl">
                                      <Zap size={10} className="text-[#F1C40F] shrink-0 mt-0.5" />
                                      <p className="text-[10px] text-zinc-400 leading-relaxed">{guide.tip}</p>
                                    </div>
                                  )}
                                </div>
                              );
                            })()}
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              )}

              {/* ─ Gateways ─ */}
              {activeTab === "gateways" && (
                <HardwareGatewayPanel gymId={selectedGymId} token={token} />
              )}

              {/* ─ NFC Cards ─ */}
              {activeTab === "cards" && (
                <CardManagementPanel gymId={selectedGymId} token={token} />
              )}

              {/* ─ Statistics ─ */}
              {activeTab === "stats" && (
                <AccessStatsPanel gymId={selectedGymId} token={token} />
              )}

            </div>
          </div>
        </>
      ) : (
        <div className="py-24 flex flex-col items-center gap-4 text-zinc-500">
          <LogIn size={40} className="text-zinc-700" />
          <p className="text-sm">Select a gym to manage door access</p>
        </div>
      )}

      {/* Door System Modal */}
      {showModal && token && selectedGymId && (
        <DoorSystemModal
          gymId={selectedGymId}
          token={token}
          system={editingSystem}
          onClose={() => {
            setShowModal(false);
            setEditingSystem(null);
          }}
        />
      )}

      {/* QR Code Display Modal */}
      {qrSystem && selectedGymId && (
        <QrCodeDisplayModal
          system={qrSystem}
          gymId={selectedGymId}
          onClose={() => setQrSystem(null)}
        />
      )}
    </div>
  );
}
