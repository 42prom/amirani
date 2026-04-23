"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  gymsApi,
  uploadApi,
  doorAccessApi,
  type DoorSystem,
  type AccessLog,
  type CreateGymData,
  type GymDetail,
  type BranchStatsResponse,
  type Role,
  type RegistrationRequirements,
} from "@/lib/api";
import { PhotoUploadZone } from "@/components/ui/PhotoUploadZone";
import { useParams, useRouter } from "next/navigation";
import {
  Building2,
  Users,
  Dumbbell,
  ChevronLeft,
  CreditCard,
  Phone,
  Mail,
  X,
  RefreshCw,
  UserPlus,
  Zap,
  Download,
  TrendingUp,
  TrendingDown,
  Activity,
  Shield,
  Settings,
  QrCode,
  Check,
} from "lucide-react";
import { QRCodeSVG } from "qrcode.react";
import NextImage from "next/image";
import { GymSwitcher } from "@/components/GymSwitcher";
import { ManualRegisterModal } from "@/components/modals/ManualRegisterModal";
import { ManualActivateModal } from "@/components/modals/ManualActivateModal";
import { PageHeader } from "@/components/ui/PageHeader";
import { useGymStore } from "@/lib/gym-store";
import { ThemedDatePicker } from "@/components/ui/ThemedDatePicker";
import { CustomSelect } from "@/components/ui/Select";
import { ActionButton } from "@/components/ui/ActionButton";

// ─── Role-based access helpers ────────────────────────────────────────────────

const isGymOwnerOrAbove = (role: Role) =>
  role === "GYM_OWNER";

const isBranchAdminOrAbove = (role: Role) =>
  role === "GYM_OWNER" || role === "BRANCH_ADMIN";

// ─── Stats Card Component ─────────────────────────────────────────────────────

function StatCard({
  label,
  value,
  icon: Icon,
  trend,
  isLive,
  isLoading,
}: {
  label: string;
  value: number;
  icon: React.ElementType;
  trend?: { value: number; isPositive: boolean };
  isLive?: boolean;
  isLoading?: boolean;
}) {
  return (
    <div className="bg-white/[0.02] backdrop-blur-3xl border border-white/5 rounded-[2rem] p-8 relative overflow-hidden group hover:border-[#F1C40F]/20 transition-all">
      <div className="absolute top-0 right-0 p-6 opacity-[0.03] group-hover:opacity-[0.08] transition-opacity">
        <Icon size={100} />
      </div>
      <div className="flex items-center gap-2 mb-3">
        <p className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500">
          {label}
        </p>
        {isLive && (
          <span className="flex items-center gap-1 px-2 py-0.5 bg-green-500/10 rounded-full">
            <span className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" />
            <span className="text-[8px] font-bold text-green-400 uppercase">
              Live
            </span>
          </span>
        )}
      </div>
      {isLoading ? (
        <div className="h-12 w-24 bg-white/5 rounded-lg animate-pulse" />
      ) : (
        <div className="flex items-baseline gap-3">
          <span className="text-4xl font-black text-white tracking-tighter">
            {value.toLocaleString()}
          </span>
          {trend && (
            <span
              className={`flex items-center gap-1 text-xs font-bold ${
                trend.isPositive ? "text-green-400" : "text-red-400"
              }`}
            >
              {trend.isPositive ? (
                <TrendingUp size={14} />
              ) : (
                <TrendingDown size={14} />
              )}
              {Math.abs(trend.value)}%
            </span>
          )}
        </div>
      )}
    </div>
  );
}

// ─── Trend Period Tabs ────────────────────────────────────────────────────────

type TrendPeriod = "daily" | "weekly" | "monthly";

function TrendTabs({
  activePeriod,
  onPeriodChange,
  stats,
  isLoading,
}: {
  activePeriod: TrendPeriod;
  onPeriodChange: (period: TrendPeriod) => void;
  stats: BranchStatsResponse | undefined;
  isLoading: boolean;
}) {
  const periods: { key: TrendPeriod; label: string }[] = [
    { key: "daily", label: "Today" },
    { key: "weekly", label: "This Week" },
    { key: "monthly", label: "This Month" },
  ];

  const currentTrend = stats?.trends[activePeriod];

  return (
    <div className="bg-white/[0.02] border border-white/5 rounded-[2rem] p-8">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-lg font-black text-white uppercase tracking-tight flex items-center gap-3">
          <span className="w-1.5 h-6 bg-[#F1C40F] rounded-full" />
          Attendance Trends
        </h3>
        <div className="flex bg-white/5 rounded-xl p-1">
          {periods.map((period) => (
            <button
              key={period.key}
              onClick={() => onPeriodChange(period.key)}
              className={`px-4 py-2 rounded-lg text-xs font-bold uppercase tracking-wider transition-all ${
                activePeriod === period.key
                  ? "bg-[#F1C40F] !text-black"
                  : "text-zinc-500 hover:text-white"
              }`}
            >
              {period.label}
            </button>
          ))}
        </div>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="h-24 bg-white/5 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : currentTrend ? (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white/[0.03] rounded-xl p-5 border border-white/5">
            <p className="text-[9px] font-black text-zinc-500 uppercase tracking-widest mb-2">
              Attendance
            </p>
            <p className="text-2xl font-black text-white">
              {currentTrend.attendance.count}
            </p>
            <p
              className={`text-xs font-bold mt-1 ${
                currentTrend.attendance.growthRate >= 0
                  ? "text-green-400"
                  : "text-red-400"
              }`}
            >
              {currentTrend.attendance.growthRate >= 0 ? "+" : ""}
              {currentTrend.attendance.growthRate}% vs previous
            </p>
          </div>
          <div className="bg-white/[0.03] rounded-xl p-5 border border-white/5">
            <p className="text-[9px] font-black text-zinc-500 uppercase tracking-widest mb-2">
              Check-ins
            </p>
            <p className="text-2xl font-black text-white">
              {currentTrend.checkIns}
            </p>
          </div>
          <div className="bg-white/[0.03] rounded-xl p-5 border border-white/5">
            <p className="text-[9px] font-black text-zinc-500 uppercase tracking-widest mb-2">
              Retention Rate
            </p>
            <p className="text-2xl font-black text-white">
              {currentTrend.retentionRate}%
            </p>
          </div>
          <div className="bg-white/[0.03] rounded-xl p-5 border border-white/5">
            <p className="text-[9px] font-black text-zinc-500 uppercase tracking-widest mb-2">
              Growth Rate
            </p>
            <p
              className={`text-2xl font-black ${
                currentTrend.growthRate >= 0 ? "text-green-400" : "text-red-400"
              }`}
            >
              {currentTrend.growthRate >= 0 ? "+" : ""}
              {currentTrend.growthRate}%
            </p>
          </div>
        </div>
      ) : (
        <p className="text-zinc-500 text-center py-8">
          No trend data available
        </p>
      )}
    </div>
  );
}

// ─── QR Registration Section ─────────────────────────────────────────────────

const ALL_REG_FIELDS: { key: keyof RegistrationRequirements; label: string }[] = [
  { key: "fullName",       label: "Full Name" },
  { key: "dateOfBirth",    label: "Date of Birth" },
  { key: "personalNumber", label: "Personal / ID Number" },
  { key: "phoneNumber",    label: "Phone Number" },
  { key: "address",        label: "Home Address" },
  { key: "selfiePhoto",    label: "Selfie Photo" },
  { key: "idPhoto",        label: "ID / Passport Photo" },
  { key: "healthInfo",     label: "Health Information" },
];

function QRRegistrationSection({
  gymId,
  token,
  gym,
  onConfigurePolicy,
}: {
  gymId: string;
  token: string;
  gym: GymDetail;
  onConfigurePolicy: () => void;
}) {
  const qrRef = useRef<HTMLDivElement>(null);

  // api() auto-unwraps result.data — qrData is the inner object directly
  const { data: qr, isLoading: qrLoading } = useQuery({
    queryKey: ["registration-qr", gymId],
    queryFn: () => gymsApi.getRegistrationQr(gymId, token),
    enabled: !!token && !!gymId,
    staleTime: Infinity,
  });

  const reqs: RegistrationRequirements = gym.registrationRequirements ?? {};
  const activeFields = ALL_REG_FIELDS.filter(f => !!reqs[f.key]);

  const downloadQR = useCallback(() => {
    if (!qrRef.current || !qr) return;
    const svg = qrRef.current.querySelector("svg");
    if (!svg) return;
    const svgData = new XMLSerializer().serializeToString(svg);
    const canvas = document.createElement("canvas");
    canvas.width = 400;
    canvas.height = 400;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const img = new Image();
    img.onload = () => {
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, 400, 400);
      ctx.drawImage(img, 0, 0, 400, 400);
      const link = document.createElement("a");
      link.download = `${qr.gymName.replace(/\s+/g, "-")}-registration-qr.png`;
      link.href = canvas.toDataURL("image/png");
      link.click();
    };
    img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)));
  }, [qr]);

  return (
    <div className="bg-white/[0.02] border border-white/5 rounded-[2rem] p-8">
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-3">
          <span className="w-1.5 h-6 bg-[#F1C40F] rounded-full" />
          <h3 className="text-lg font-black text-white uppercase tracking-tight">
            Member Registration QR
          </h3>
        </div>
        <button
          onClick={onConfigurePolicy}
          className="flex items-center gap-2 px-4 py-2 bg-white/5 hover:bg-white/10 rounded-xl text-xs font-bold text-zinc-400 hover:text-white transition-all border border-white/10"
        >
          <Shield size={12} />
          Registration Policy
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* QR Code Display */}
        <div className="flex flex-col items-center gap-5">
          {qrLoading ? (
            <div className="w-48 h-48 bg-white/5 rounded-2xl animate-pulse" />
          ) : qr ? (
            <>
              <div
                ref={qrRef}
                className="bg-white p-4 rounded-2xl shadow-lg shadow-[#F1C40F]/5"
              >
                <QRCodeSVG
                  value={qr.qrContent}
                  size={176}
                  bgColor="#ffffff"
                  fgColor="#000000"
                  level="H"
                />
              </div>
              <div className="text-center">
                <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-1">
                  Registration Code
                </p>
                <p className="text-sm font-mono text-zinc-300 tracking-widest">
                  {qr.registrationCode}
                </p>
              </div>
              <button
                onClick={downloadQR}
                className="flex items-center gap-2 px-5 py-2.5 bg-[#F1C40F] !text-black text-sm font-bold rounded-xl hover:bg-yellow-400 transition-colors"
              >
                <Download size={14} />
                Download QR Code
              </button>
              <p className="text-[11px] text-zinc-600 text-center max-w-[220px]">
                Print and display at your entrance. Members scan with the Amirani app to register.
              </p>
            </>
          ) : (
            <div className="flex flex-col items-center gap-3 py-8 text-zinc-600">
              <QrCode size={40} className="opacity-20" />
              <p className="text-xs">QR code unavailable</p>
            </div>
          )}
        </div>

        {/* Active Registration Requirements (read-only — managed via Registration Policy) */}
        <div className="space-y-4">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-1">
              Active Requirements
            </p>
            <p className="text-xs text-zinc-600">
              Fields members must fill when registering via QR scan.
              Configure in <button onClick={onConfigurePolicy} className="text-[#F1C40F] hover:underline">Registration Policy</button>.
            </p>
          </div>

          <div className="space-y-2">
            {/* Always-required */}
            {["Full Name", "Email Address"].map(label => (
              <div key={label} className="flex items-center justify-between px-4 py-3 rounded-xl border border-[#F1C40F] bg-[#F1C40F]">
                <p className="text-xs font-bold !text-black">{label}</p>
                <span className="text-[9px] font-black uppercase tracking-widest !text-black/60">Always</span>
              </div>
            ))}

            {activeFields.length > 0 ? (
              activeFields.map(({ label }) => (
                <div key={label} className="flex items-center justify-between px-4 py-3 rounded-xl border border-white/5 bg-white/[0.02]">
                  <p className="text-xs font-bold text-zinc-300">{label}</p>
                  <Check size={12} className="text-green-400" />
                </div>
              ))
            ) : (
              <p className="text-xs text-zinc-600 px-1">
                No additional fields required. Click <span className="text-[#F1C40F]">Registration Policy</span> to add.
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Registration Policy Modal ───────────────────────────────────────────────

function RegistrationPolicyModal({
  gym,
  token,
  onClose,
}: {
  gym: GymDetail;
  token: string;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const [requirements, setRequirements] = useState<RegistrationRequirements>(
    gym.registrationRequirements || { fullName: true, phoneNumber: true, healthInfo: false }
  );

  const updateMutation = useMutation({
    mutationFn: (newRequirements: RegistrationRequirements) =>
      gymsApi.update(gym.id, { registrationRequirements: newRequirements }, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym", gym.id] });
      queryClient.invalidateQueries({ queryKey: ["gyms"] });
      onClose();
    },
  });

  const toggleField = (field: keyof RegistrationRequirements) => {
    setRequirements((prev) => ({ ...prev, [field]: !prev[field] }));
  };

  const sections: { title: string; fields: { key: string; label: string; description?: string }[] }[] = [
    {
      title: "Basic Information",
      fields: [
        { key: "fullName", label: "Full Name (First & Last)", description: "Always required for login" },
        { key: "dateOfBirth", label: "Date of Birth" },
        { key: "personalNumber", label: "Personal Number (ID/SSN)" },
        { key: "phoneNumber", label: "Phone Number" },
        { key: "address", label: "Home Address" },
      ],
    },
    {
      title: "Security & Verification",
      fields: [
        { key: "selfiePhoto", label: "Selfie Photo", description: "Biometric verification" },
        { key: "idPhoto", label: "ID / Passport Photo", description: "Identity verification" },
      ],
    },
    {
      title: "Medical & Health (Optional)",
      fields: [
        { key: "healthInfo", label: "Member Health Problems", description: "Members input their health info during registration" },
      ],
    },
  ];

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-2xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-2xl font-black text-white tracking-tight flex items-center gap-3 italic uppercase">
              <Shield className="text-[#F1C40F]" size={28} />
              Registration Policy
            </h2>
            <p className="text-zinc-500 text-[10px] font-black uppercase tracking-[0.2em] mt-1">Configure Membership Induction Protocol</p>
          </div>
          <button onClick={onClose} className="p-3 hover:bg-white/5 rounded-2xl transition-colors text-zinc-500 hover:text-white border border-white/5">
            <X size={24} />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto amirani-scrollbar scroll-smooth">
          <div className="p-8 space-y-8">
            {sections.map((section) => (
              <div key={section.title} className="space-y-4">
                <h3 className="text-xs font-bold text-[#F1C40F] uppercase tracking-widest">{section.title}</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  {section.fields.map((field) => {
                    const isActive = !!requirements[field.key as keyof RegistrationRequirements];
                    const isLocked = field.key === "fullName";
                    return (
                      <button
                        key={field.key}
                        onClick={() => toggleField(field.key as keyof RegistrationRequirements)}
                        disabled={isLocked}
                        className={`flex items-start gap-4 p-4 rounded-2xl border transition-all text-left group ${
                          isActive
                            ? "bg-[#F1C40F] border-[#F1C40F] !text-black"
                            : "bg-white/[0.02] border-white/5 text-zinc-500 hover:border-white/10"
                        } ${isLocked ? "opacity-50 cursor-not-allowed" : ""}`}
                      >
                        <div className={`mt-1 w-5 h-5 rounded-md border flex items-center justify-center transition-colors ${
                          isActive ? "bg-black/20 border-black/20" : "border-zinc-700 group-hover:border-zinc-500"
                        }`}>
                          {isActive && <div className="w-2 h-2 bg-black rounded-sm" />}
                        </div>
                        <div>
                          <p className="font-bold text-sm tracking-tight">{field.label}</p>
                          {field.description && <p className="text-[10px] opacity-60 mt-0.5 line-clamp-1">{field.description}</p>}
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </div>
        <div className="p-8 bg-white/[0.02] border-t border-white/5 flex gap-4 shrink-0">
          <button
            onClick={onClose}
            className="flex-1 px-6 py-4 rounded-2xl border border-white/10 text-zinc-500 font-black uppercase tracking-widest hover:bg-white/5 hover:text-white transition-all text-[10px]"
          >
            Cancel
          </button>
          <button
            onClick={() => updateMutation.mutate(requirements)}
            disabled={updateMutation.isPending}
            className="flex-[2] px-6 py-4 rounded-2xl bg-[#F1C40F] !text-black font-black uppercase tracking-widest hover:bg-[#F1C40F]/90 transition-all shadow-xl shadow-[#F1C40F]/20 disabled:opacity-50 text-[10px]"
          >
            {updateMutation.isPending ? "SAVING..." : "SAVE REGISTRATION POLICY"}
          </button>
        </div>
      </div>
    </div>
  );
}


// ─── Main Page Component ──────────────────────────────────────────────────────

export default function BranchDashboardPage() {
  const params = useParams();
  const router = useRouter();
  const queryClient = useQueryClient();
  const gymId = params.gymId as string;
  const { token, user } = useAuthStore();
  const { setSelectedGymId } = useGymStore();
  const userRole = user?.role || "GYM_MEMBER";

  // State
  const [showEditModal, setShowEditModal] = useState(false);
  const [showRegistrationModal, setShowRegistrationModal] = useState(false);
  const [showActivationModal, setShowActivationModal] = useState(false);
  const [showExportModal, setShowExportModal] = useState(false);
  const [showRegPolicyModal, setShowRegPolicyModal] = useState(false);
  const [trendPeriod, setTrendPeriod] = useState<TrendPeriod>("daily");

  // Access check
  useEffect(() => {
    if (user && !isBranchAdminOrAbove(user.role)) {
      router.push("/dashboard");
    }
  }, [user, router]);

  // Sync store with URL gymId
  useEffect(() => {
    if (gymId) {
      setSelectedGymId(gymId);
    }
  }, [gymId, setSelectedGymId]);

  // Queries
  const { data: gym, isLoading: gymLoading } = useQuery({
    queryKey: ["gym", gymId],
    queryFn: () => gymsApi.getById(gymId, token!),
    enabled: !!token && !!gymId,
  });

  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ["branch-stats", gymId],
    queryFn: () => gymsApi.getStats(gymId, token!),
    enabled: !!token && !!gymId,
    refetchInterval: 30000, // Refetch every 30 seconds for occupancy
  });

  // Get all gyms for switcher
  const { data: gyms, isLoading: gymsLoading } = useQuery({
    queryKey: ["gyms"],
    queryFn: () => gymsApi.getAll(token!),
    enabled: !!token && isGymOwnerOrAbove(userRole),
  });

  const { data: doorSystems, isLoading: systemsLoading } = useQuery({
    queryKey: ["door-systems", gymId],
    queryFn: () => doorAccessApi.getGymSystems(gymId, token!),
    enabled: !!token && !!gymId && isBranchAdminOrAbove(userRole),
  });

  const unlockMutation = useMutation({
    mutationFn: (systemId: string) => doorAccessApi.unlock(systemId, token!),
    onSuccess: (data) => {
      if (data.success) {
        // Option to show a success toast or vibration
      }
    },
  });

  const { data: accessLogs, isLoading: logsLoading } = useQuery({
    queryKey: ["access-logs", gymId],
    queryFn: () => doorAccessApi.getGymLogs(gymId, token!),
    enabled: !!token && !!gymId && isBranchAdminOrAbove(userRole),
    refetchInterval: 5000, // Poll every 5 seconds for live feed
  });

  // Mutations
  const updateMutation = useMutation({
    mutationFn: (data: Partial<CreateGymData>) =>
      gymsApi.update(gymId, data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gym", gymId] });
      queryClient.invalidateQueries({ queryKey: ["gyms"] });
      setShowEditModal(false);
    },
  });

  // Loading state
  if (gymLoading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="relative w-16 h-16">
          <div className="absolute inset-0 border-4 border-[#F1C40F]/20 rounded-full" />
          <div className="absolute inset-0 border-4 border-[#F1C40F] rounded-full border-t-transparent animate-spin" />
        </div>
      </div>
    );
  }

  // Not found
  if (!gym) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-center px-4">
        <h2 className="text-3xl font-black text-white mb-4">
          BRANCH NOT FOUND
        </h2>
        <p className="text-zinc-500 mb-8 max-w-md">
          The requested branch could not be found or you don&apos;t have access.
        </p>
        <button
          onClick={() => router.push("/dashboard/gyms")}
          className="px-8 py-3 bg-[#F1C40F] !text-black rounded-xl font-bold flex items-center gap-2 hover:-translate-y-1 transition-all"
        >
          <ChevronLeft size={20} />
          RETURN TO OVERVIEW
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-8 max-w-[1600px] mx-auto pb-20">
      <PageHeader
        title={
          <span className="tracking-tighter uppercase leading-[0.9]">{gym.name}</span>
        }
        description={`${gym.city}, ${gym.country}`}
        icon={<Building2 size={32} />}
        actions={
          <div className="flex items-center gap-2 flex-nowrap whitespace-nowrap">
            {/* Status & Role Badges */}
            <div className={`flex items-center gap-2 px-3 py-2 rounded-2xl border transition-all duration-500 bg-white/[0.02] backdrop-blur-md ${
              gym.isActive ? 'border-emerald-500/20 shadow-[0_0_20px_rgba(16,185,129,0.05)]' : 'border-red-500/20 shadow-[0_0_20px_rgba(239,68,68,0.05)]'
            }`}>
              <div className={`w-1.5 h-1.5 rounded-full ${gym.isActive ? 'bg-emerald-500 animate-pulse shadow-[0_0_8px_rgba(16,185,129,0.6)]' : 'bg-red-500'}`} />
              <span className={`text-[9px] font-black uppercase tracking-widest ${gym.isActive ? 'text-emerald-400' : 'text-red-400'}`}>
                {gym.isActive ? "Active" : "Offline"}
              </span>
            </div>

            <div className="flex items-center gap-2 px-3 py-2 rounded-2xl border border-[#F1C40F]/10 bg-white/[0.02] backdrop-blur-md shadow-[0_0_20px_rgba(241,196,15,0.03)]">
              <Shield size={10} className="text-[#F1C40F]" />
              <span className="text-[9px] font-black uppercase tracking-widest text-[#F1C40F]">
                {userRole.replace("_", " ")}
              </span>
            </div>

            {userRole !== "GYM_OWNER" && (
              <GymSwitcher
                gyms={gyms}
                isLoading={gymsLoading}
                disabled={userRole === "BRANCH_ADMIN"}
              />
            )}
            
            {/* Door Controls */}
            {doorSystems?.map((system: DoorSystem) => (
              <ActionButton
                key={system.id}
                icon={Zap}
                label={`Open ${system.name}`}
                onClick={() => unlockMutation.mutate(system.id)}
                variant="primary"
              />
            ))}
            {systemsLoading && (
              <div className="w-40 h-[58px] bg-white/5 rounded-2xl animate-pulse border border-white/10" />
            )}

            {/* Operational Buttons */}
            {userRole !== "GYM_OWNER" && (
              <>
                <ActionButton
                  icon={UserPlus}
                  label="Register Member"
                  onClick={() => setShowRegistrationModal(true)}
                />
                <ActionButton
                  icon={Zap}
                  label="Activate Subscription"
                  onClick={() => setShowActivationModal(true)}
                  variant="primary"
                />
              </>
            )}

            {isGymOwnerOrAbove(userRole) && (
              <>
                <ActionButton
                  icon={RefreshCw}
                  label="Refresh Stats"
                  onClick={() => {
                    queryClient.invalidateQueries({
                      queryKey: ["branch-stats", gymId],
                    });
                    queryClient.invalidateQueries({
                      queryKey: ["access-logs", gymId],
                    });
                  }}
                />
                <ActionButton
                  icon={Download}
                  label="Export Logs"
                  onClick={() => setShowExportModal(true)}
                />
              </>
            )}
          </div>
        }
      />

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
        {/* Main Content */}
        <div className="lg:col-span-3 space-y-8">
          {/* Stats Grid */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <StatCard
              label="Active Subscriptions"
              value={stats?.activeSubscriptions ?? 0}
              icon={CreditCard}
              trend={
                stats?.trends.monthly
                  ? {
                      value: stats.trends.monthly.growthRate,
                      isPositive: stats.trends.monthly.growthRate >= 0,
                    }
                  : undefined
              }
              isLoading={statsLoading}
            />
            <StatCard
              label="Registered Customers"
              value={stats?.registeredCustomers ?? 0}
              icon={Users}
              isLoading={statsLoading}
            />
            <StatCard
              label="Hall Occupancy"
              value={stats?.currentHallOccupancy ?? 0}
              icon={Activity}
              isLive
              isLoading={statsLoading}
            />
            <StatCard
              label="Trainers"
              value={stats?.trainersCount ?? 0}
              icon={Dumbbell}
              isLoading={statsLoading}
            />
          </div>

          {/* Trends Section */}
          <TrendTabs
            activePeriod={trendPeriod}
            onPeriodChange={setTrendPeriod}
            stats={stats}
            isLoading={statsLoading}
          />

          {/* Branch Info */}
          <div className="bg-white/[0.02] border border-white/5 rounded-[2rem] p-8">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-black text-white uppercase tracking-tight flex items-center gap-3">
                <span className="w-1.5 h-6 bg-[#F1C40F] rounded-full" />
                Branch Information
              </h3>
              <button
                onClick={() => setShowEditModal(true)}
                className="px-4 py-2 bg-white/5 hover:bg-white/10 rounded-xl text-xs font-bold text-zinc-400 hover:text-white transition-all flex items-center gap-2"
              >
                <Settings size={14} />
                Edit
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <p className="text-[9px] font-black text-[#F1C40F] uppercase tracking-widest mb-1">
                  Address
                </p>
                <p className="text-white font-medium">{gym.address}</p>
                <p className="text-zinc-500 text-sm">
                  {gym.city}, {gym.country}
                </p>
              </div>
              <div className="space-y-4">
                <div>
                  <p className="text-[9px] font-black text-[#F1C40F] uppercase tracking-widest mb-1">
                    Phone
                  </p>
                  <p className="text-white font-medium flex items-center gap-2">
                    <Phone size={14} className="text-zinc-500" />
                    {gym.phone || "Not set"}
                  </p>
                </div>
                <div>
                  <p className="text-[9px] font-black text-[#F1C40F] uppercase tracking-widest mb-1">
                    Email
                  </p>
                  <p className="text-white font-medium flex items-center gap-2">
                    <Mail size={14} className="text-zinc-500" />
                    {gym.email || "Not set"}
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* QR Registration Section */}
          <QRRegistrationSection
            gymId={gymId}
            token={token!}
            gym={gym}
            onConfigurePolicy={() => setShowRegPolicyModal(true)}
          />
        </div>

        {/* Sidebar - Live Activity Feed */}
        <div className="space-y-6">
          <div className="bg-white/[0.02] border border-white/5 rounded-[2rem] p-6 h-[800px] flex flex-col">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-sm font-black text-white uppercase tracking-tight flex items-center gap-2">
                <span className="w-1.5 h-4 bg-[#F1C40F] rounded-full" />
                Live Activity
              </h3>
              <div className="flex items-center gap-1.5">
                <div className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" />
                <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">
                  Live
                </span>
              </div>
            </div>

            <div className="flex-1 overflow-y-auto space-y-4 pr-2 amirani-scrollbar">
              {logsLoading ? (
                Array.from({ length: 6 }).map((_, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-3 p-3 bg-white/[0.02] border border-white/5 rounded-2xl animate-pulse"
                  >
                    <div className="w-10 h-10 bg-white/5 rounded-full" />
                    <div className="flex-1 space-y-2">
                      <div className="h-3 w-24 bg-white/5 rounded" />
                      <div className="h-2 w-16 bg-white/5 rounded" />
                    </div>
                  </div>
                ))
              ) : accessLogs?.length === 0 ? (
                <div className="flex flex-col items-center justify-center h-full text-center space-y-3 opacity-50">
                  <Activity size={32} className="text-zinc-700" />
                  <p className="text-xs font-bold text-zinc-500 uppercase tracking-widest">
                    No recent activity
                  </p>
                </div>
              ) : (
                accessLogs?.map((log: AccessLog) => (
                  <div
                    key={log.id}
                    className={`flex items-center gap-3 p-3 rounded-2xl border ${
                      log.accessGranted
                        ? "bg-white/[0.02] border-white/5"
                        : "bg-red-500/5 border-red-500/10"
                    }`}
                  >
                    <div className="relative">
                      {log.user.avatarUrl ? (
                        <div className="w-10 h-10 rounded-full border border-white/10 overflow-hidden">
                          <NextImage
                            src={uploadApi.getFullUrl(log.user.avatarUrl)}
                            alt={log.user.fullName}
                            width={40}
                            height={40}
                            className="w-full h-full object-cover"
                          />
                        </div>
                      ) : (
                        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-zinc-800 to-zinc-900 border border-white/10 flex items-center justify-center text-xs font-black text-zinc-500 uppercase tracking-widest">
                          {log.user.fullName.charAt(0)}
                        </div>
                      )}
                      <div
                        className={`absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-[#121721] flex items-center justify-center ${
                          log.accessGranted ? "bg-green-500" : "bg-red-500"
                        }`}
                      >
                        {log.accessGranted ? (
                          <Zap size={8} className="text-white fill-white" />
                        ) : (
                          <X size={8} className="text-white" />
                        )}
                      </div>
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-2">
                        <p className="text-xs font-black text-white truncate uppercase tracking-tight">
                          {log.user.fullName}
                        </p>
                        <span className="text-[9px] font-black text-zinc-500 uppercase tracking-widest whitespace-nowrap">
                          {new Date(log.accessTime).toLocaleTimeString([], {
                            hour: "2-digit",
                            minute: "2-digit",
                          })}
                        </span>
                      </div>
                      <p
                        className={`text-[9px] font-bold uppercase tracking-wider truncate mb-1 ${
                          log.accessGranted ? "text-[#F1C40F]" : "text-red-500"
                        }`}
                      >
                        {log.accessGranted ? "Access Granted" : "Access Denied"}
                      </p>
                      <div className="flex items-center gap-1.5 opacity-40">
                        <span className="text-[9px] font-black text-zinc-500 uppercase tracking-widest truncate">
                          {log.doorSystem?.name}
                        </span>
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Modals */}
      {showEditModal && gym && (
        <EditGymModal
          gym={gym}
          onClose={() => setShowEditModal(false)}
          onSubmit={(data) => updateMutation.mutate(data)}
          isLoading={updateMutation.isPending}
          error={updateMutation.error?.message}
          token={token!}
        />
      )}

      {showRegistrationModal && (
        <ManualRegisterModal
          gymId={gymId}
          token={token!}
          onClose={() => setShowRegistrationModal(false)}
          onSuccess={() => {
            queryClient.invalidateQueries({
              queryKey: ["branch-stats", gymId],
            });
          }}
        />
      )}

      {showActivationModal && (
        <ManualActivateModal
          gymId={gymId}
          token={token!}
          onClose={() => setShowActivationModal(false)}
          onSuccess={() => {
            queryClient.invalidateQueries({
              queryKey: ["branch-stats", gymId],
            });
          }}
        />
      )}

      {showExportModal && (
        <ExportLogsModal
          gymId={gymId}
          token={token!}
          onClose={() => setShowExportModal(false)}
        />
      )}

      {showRegPolicyModal && gym && (
        <RegistrationPolicyModal
          gym={gym}
          token={token!}
          onClose={() => setShowRegPolicyModal(false)}
        />
      )}
    </div>
  );
}

// ─── Edit Gym Modal ───────────────────────────────────────────────────────────

function EditGymModal({
  gym,
  onClose,
  onSubmit,
  isLoading,
  error,
  token,
}: {
  gym: GymDetail;
  onClose: () => void;
  onSubmit: (data: Partial<CreateGymData>) => void;
  isLoading: boolean;
  error?: string;
  token: string;
}) {
  const [formData, setFormData] = useState({
    name: gym.name,
    address: gym.address,
    city: gym.city,
    country: gym.country,
    phone: gym.phone || "",
    email: gym.email || "",
    logoUrl: gym.logoUrl || "",
    bannerUrl: gym.bannerUrl || "",
  });
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-2xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden animate-in zoom-in-95 duration-300">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-2xl font-black text-white uppercase tracking-tighter flex items-center gap-3 italic">
              <Settings className="text-[#F1C40F]" size={24} />
              Edit Branch
            </h2>
            <p className="text-zinc-500 text-[10px] font-black uppercase tracking-[0.2em] mt-1">Configure Gym Node Parameters</p>
          </div>
          <button
            onClick={onClose}
            className="p-3 hover:bg-red-500/10 rounded-2xl text-zinc-500 hover:text-red-400 transition-all border border-white/5"
          >
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
          {/* SCROLLABLE CONTENT */}
          <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
            <div className="space-y-8">
            {error && (
              <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4 text-red-400 text-sm">
                {error}
              </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div className="md:col-span-2">
                <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                  Branch Name *
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) =>
                    setFormData({ ...formData, name: e.target.value })
                  }
                  required
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl text-white focus:border-[#F1C40F]/50 focus:outline-none transition-all"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                  Address *
                </label>
                <input
                  type="text"
                  value={formData.address}
                  onChange={(e) =>
                    setFormData({ ...formData, address: e.target.value })
                  }
                  required
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl text-white focus:border-[#F1C40F]/50 focus:outline-none transition-all"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                  City *
                </label>
                <input
                  type="text"
                  value={formData.city}
                  onChange={(e) =>
                    setFormData({ ...formData, city: e.target.value })
                  }
                  required
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl text-white focus:border-[#F1C40F]/50 focus:outline-none transition-all"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                  Country *
                </label>
                <input
                  type="text"
                  value={formData.country}
                  onChange={(e) =>
                    setFormData({ ...formData, country: e.target.value })
                  }
                  required
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl text-white focus:border-[#F1C40F]/50 focus:outline-none transition-all"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                  Phone
                </label>
                <input
                  type="tel"
                  value={formData.phone}
                  onChange={(e) =>
                    setFormData({ ...formData, phone: e.target.value })
                  }
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl text-white focus:border-[#F1C40F]/50 focus:outline-none transition-all"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
                  Email
                </label>
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) =>
                    setFormData({ ...formData, email: e.target.value })
                  }
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl text-white focus:border-[#F1C40F]/50 focus:outline-none transition-all"
                />
              </div>

              <div>
                <PhotoUploadZone
                  label="Gym Logo"
                  value={formData.logoUrl}
                  onChange={(url: string) =>
                    setFormData({ ...formData, logoUrl: url })
                  }
                  folder="gyms"
                  token={token}
                  aspectRatio="square"
                />
              </div>

              <div>
                <PhotoUploadZone
                  label="Gym Banner"
                  value={formData.bannerUrl}
                  onChange={(url: string) =>
                    setFormData({ ...formData, bannerUrl: url })
                  }
                  folder="gyms"
                  token={token}
                  aspectRatio="video"
                />
            </div>
          </div>
        </div>
      </div>

      {/* FIXED FOOTER */}
        <div className="p-8 bg-white/[0.02] border-t border-white/5 flex justify-end gap-3 shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-all"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={isLoading || !formData.name}
            className="px-8 py-4 bg-[#F1C40F] text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all disabled:opacity-50 flex items-center justify-center gap-2 shadow-xl shadow-[#F1C40F]/20"
          >
            {isLoading ? (
              <RefreshCw className="animate-spin" size={16} />
            ) : (
              "Save Changes"
            )}
          </button>
        </div>
        </form>
      </div>
    </div>
  );
}

// ─── Placeholder Modals (to be implemented in separate tasks) ─────────────────

function ExportLogsModal({
  gymId,
  token,
  onClose,
}: {
  gymId: string;
  token: string;
  onClose: () => void;
}) {
  const [filters, setFilters] = useState({
    startDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
      .toISOString()
      .split("T")[0],
    endDate: new Date().toISOString().split("T")[0],
    logType: "",
    format: "json" as "json" | "csv",
  });
  const [isExporting, setIsExporting] = useState(false);
  const [exportResult, setExportResult] = useState<{
    success: boolean;
    message: string;
    totalRecords?: number;
  } | null>(null);

  const logTypes = [
    { value: "", label: "All Types" },
    { value: "QR_CODE", label: "QR Code" },
    { value: "NFC", label: "NFC" },
    { value: "PIN_CODE", label: "PIN Code" },
    { value: "BLUETOOTH", label: "Bluetooth" },
  ];

  const handleExport = async () => {
    setIsExporting(true);
    setExportResult(null);

    try {
      const params = new URLSearchParams();
      if (filters.startDate) params.append("startDate", filters.startDate);
      if (filters.endDate) params.append("endDate", filters.endDate);
      if (filters.logType) params.append("logType", filters.logType);
      params.append("format", filters.format);

      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:3085"}/branch/${gymId}/export-logs?${params.toString()}`,
        { headers: { Authorization: `Bearer ${token}` } },
      );

      if (!response.ok) {
        throw new Error("Failed to export logs");
      }

      if (filters.format === "csv") {
        // Download CSV file
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `access-logs-${gymId}-${new Date().toISOString().split("T")[0]}.csv`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
        setExportResult({
          success: true,
          message: "CSV file downloaded successfully!",
        });
      } else {
        // JSON export
        const data = await response.json();
        const exportData = data.data || data;

        // Download JSON file
        const blob = new Blob([JSON.stringify(exportData, null, 2)], {
          type: "application/json",
        });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `access-logs-${gymId}-${new Date().toISOString().split("T")[0]}.json`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);

        setExportResult({
          success: true,
          message: "JSON file downloaded successfully!",
          totalRecords: exportData.totalRecords || exportData.logs?.length,
        });
      }
    } catch (err) {
      setExportResult({
        success: false,
        message: err instanceof Error ? err.message : "Export failed",
      });
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
      <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-lg max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden animate-in zoom-in-95 duration-300">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-xl font-black text-white uppercase tracking-tight italic flex items-center gap-2">
              <Download className="text-[#F1C40F]" size={24} />
              Export Access Logs
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Initialize Data Extraction Protocol</p>
          </div>
          <button
            onClick={onClose}
            className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-all border border-white/5"
          >
            <X size={20} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <div className="space-y-6">
          {exportResult && (
            <div
              className={`rounded-xl p-4 text-sm ${
                exportResult.success
                  ? "bg-green-500/10 border border-green-500/30 text-green-400"
                  : "bg-red-500/10 border border-red-500/30 text-red-400"
              }`}
            >
              {exportResult.message}
              {exportResult.totalRecords !== undefined && (
                <span className="block mt-1 text-xs opacity-75">
                  {exportResult.totalRecords} records exported
                </span>
              )}
            </div>
          )}

          {/* Date Range */}
          <div className="grid grid-cols-2 gap-4">
            <ThemedDatePicker
              label="Start Date"
              value={filters.startDate}
              onChange={(date) => setFilters({ ...filters, startDate: date })}
            />
            <ThemedDatePicker
              label="End Date"
              value={filters.endDate}
              onChange={(date) => setFilters({ ...filters, endDate: date })}
            />
          </div>

          {/* Log Type Filter */}
          <CustomSelect
            label="Log Type"
            value={filters.logType}
            onChange={(value) => setFilters({ ...filters, logType: value })}
            options={logTypes}
          />

          {/* Format Selection */}
          <div>
            <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2">
              Export Format
            </label>
            <div className="flex gap-3">
              <button
                type="button"
                onClick={() => setFilters({ ...filters, format: "json" })}
                className={`flex-1 py-3 rounded-xl font-bold text-sm transition-all ${
                  filters.format === "json"
                    ? "bg-[#F1C40F] text-black"
                    : "bg-white/5 text-zinc-400 hover:bg-white/10"
                }`}
              >
                JSON
              </button>
              <button
                type="button"
                onClick={() => setFilters({ ...filters, format: "csv" })}
                className={`flex-1 py-3 rounded-xl font-bold text-sm transition-all ${
                  filters.format === "csv"
                    ? "bg-[#F1C40F] text-black"
                    : "bg-white/5 text-zinc-400 hover:bg-white/10"
                }`}
              >
                CSV
              </button>
            </div>
          </div>

          </div>
        </div>

        {/* FIXED FOOTER */}
        <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3 shrink-0">
          <button
            type="button"
            onClick={onClose}
            disabled={isExporting}
            className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-all disabled:opacity-50"
          >
            Close
          </button>
          <button
            type="button"
            onClick={handleExport}
            disabled={isExporting}
            className="px-8 py-4 bg-[#F1C40F] text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all disabled:opacity-50 flex items-center justify-center gap-2 shadow-xl shadow-[#F1C40F]/20"
          >
            {isExporting ? (
              <RefreshCw className="animate-spin" size={18} />
            ) : (
              <>
                <Download size={18} />
                Export Data
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
