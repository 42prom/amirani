"use client";

import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useAuthStore, isSuperAdmin, isTrainer } from "@/lib/auth-store";
import { useQuery } from "@tanstack/react-query";
import { platformApi } from "@/lib/api";
import {
  LayoutDashboard,
  Building2,
  Users,
  Dumbbell,
  CreditCard,
  DoorOpen,
  Settings,
  LogOut,
  Bot,
  Bell,
  Layers,
  BarChart3,
  Mail,
  Package,
  Wallet,
  Landmark,
  Megaphone,
  AlertTriangle,
  Zap,
  Send,
  Calendar,
  MessageSquare,
  ClipboardList,
  Trophy,
  SlidersHorizontal,
  ChevronDown,
  TrendingUp,
  KeyRound,
  Languages,
  Salad,
} from "lucide-react";
import clsx from "clsx";
import { useGymStore } from "@/lib/gym-store";

// ─── Types ───────────────────────────────────────────────────────────────────

type NavItem = { href: string; label: string; icon: React.ElementType };

type FacilityGroup = {
  id: string;
  label: string;
  icon: React.ElementType;
  color: string;
  items: NavItem[];
  ownerOnly?: boolean;
  /** If true, this group renders its items flat (no toggle header) */
  flat?: boolean;
};

// ─── DONT TOUCH: Super Admin Navigation ──────────────────────────────────────

const superAdminLinks: NavItem[] = [
  { href: "/dashboard",                      label: "Dashboard",          icon: LayoutDashboard },
  { href: "/dashboard/gym-owners",           label: "Gym Owners",         icon: Users },
  { href: "/dashboard/invitations",          label: "Invitations",        icon: Mail },
  { href: "/dashboard/equipment-catalog",    label: "Equipment Catalog",  icon: Package },
  { href: "/dashboard/exercise-database",    label: "Exercise Database",   icon: Dumbbell },
  { href: "/dashboard/ingredient-database",  label: "Ingredient Database", icon: Salad },
  { href: "/dashboard/ai-config",            label: "AI Configuration",   icon: Bot },
  { href: "/dashboard/language-packs",       label: "Language Packs",     icon: Languages },
  { href: "/dashboard/tier-limits",          label: "Tier Limits",        icon: Layers },
  { href: "/dashboard/notifications-config", label: "Push Notifications", icon: Bell },
  { href: "/dashboard/oauth-config",         label: "OAuth / Social Login", icon: KeyRound },
  { href: "/dashboard/stripe-config",        label: "Stripe / Payments",  icon: Wallet },
  { href: "/dashboard/deposits",             label: "Financial Deposits", icon: Landmark },
  { href: "/dashboard/analytics",            label: "Platform Analytics", icon: BarChart3 },
  { href: "/dashboard/saas-subscriptions",   label: "SaaS Management",    icon: CreditCard },
  { href: "/dashboard/settings",             label: "Platform Settings",  icon: Settings },
];

// ─── DONT TOUCH: Gym Owner platform-level links ───────────────────────────────

const gymOwnerPlatformLinks: NavItem[] = [
  { href: "/dashboard",       label: "Dashboard", icon: LayoutDashboard },
  { href: "/dashboard/gyms",  label: "My Gyms",   icon: Building2 },
  { href: "/dashboard/billing", label: "Billing",  icon: CreditCard },
];

// ─── Facility group builder ───────────────────────────────────────────────────

function buildFacilityGroups(id: string, isOwner: boolean, isBAdmin: boolean): FacilityGroup[] {
  const groups: FacilityGroup[] = [
    {
      id: "operations",
      label: "Operations",
      icon: LayoutDashboard,
      color: "text-zinc-400",
      flat: true, // always visible, no toggle
      items: [
        ...(isBAdmin ? [{ href: `/dashboard/gyms/${id}`, label: "Dashboard", icon: LayoutDashboard }] : []),
        { href: `/dashboard/members?gymId=${id}`,  label: "Members",   icon: Users },
        { href: `/dashboard/trainers?gymId=${id}`, label: "Staff",     icon: Users },
        { href: `/dashboard/gyms/${id}/sessions`,  label: "Sessions",  icon: Calendar },
        { href: `/dashboard/equipment?gymId=${id}`, label: "Equipment", icon: Dumbbell },
        { href: `/dashboard/gyms/${id}/branches`,  label: "Branches",  icon: Landmark },
      ],
    },
    {
      id: "marketing",
      label: "Marketing",
      icon: Megaphone,
      color: "text-orange-400",
      items: [
        { href: `/dashboard/gyms/${id}/announcements`, label: "Announcements", icon: Megaphone },
        { href: `/dashboard/gyms/${id}/marketing`,     label: "Campaigns",     icon: Send },
        { href: `/dashboard/gyms/${id}/automations`,   label: "Automations",   icon: Zap },
      ],
    },
    {
      id: "engagement",
      label: "Engagement",
      icon: Trophy,
      color: "text-yellow-400",
      items: [
        { href: `/dashboard/gyms/${id}/rooms`, label: "Progress Rooms", icon: Trophy },
        { href: `/dashboard/gyms/${id}/churn`, label: "Churn Risk",     icon: AlertTriangle },
      ],
    },
    {
      id: "support",
      label: "Support & Logs",
      icon: MessageSquare,
      color: "text-blue-400",
      items: [
        { href: `/dashboard/gyms/${id}/support`,    label: "Support Tickets", icon: MessageSquare },
        { href: `/dashboard/gyms/${id}/audit-log`,  label: "Audit Log",       icon: ClipboardList },
      ],
    },
    ...(isOwner ? [{
      id: "finance",
      label: "Finance",
      icon: Wallet,
      color: "text-green-400",
      ownerOnly: true,
      items: [
        { href: `/dashboard/gyms/${id}/revenue`,   label: "Revenue",          icon: TrendingUp },
        { href: `/dashboard/gyms/${id}/plans`,     label: "Plans",            icon: CreditCard },
        { href: `/dashboard/gyms/${id}/payments`,  label: "Payments",         icon: Wallet },
        { href: `/dashboard/gyms/${id}/deposits`,  label: "Deposits",         icon: Landmark },
        { href: `/dashboard/access?gymId=${id}`,   label: "Door Access",      icon: DoorOpen },
      ],
    }] : []),
    {
      id: "settings",
      label: "Settings",
      icon: SlidersHorizontal,
      color: "text-zinc-400",
      items: [
        { href: `/dashboard/gyms/${id}/settings`, label: "Facility Settings", icon: SlidersHorizontal },
      ],
    },
  ];

  return groups;
}

// ─── Helper: is link active ───────────────────────────────────────────────────

function isActive(href: string, pathname: string): boolean {
  const clean = href.split("?")[0];
  // Always match exact path
  if (pathname === clean) return true;
  // Only use prefix matching for deep gym-specific paths (≥4 segments).
  // This prevents /dashboard matching /dashboard/gyms/xxx and
  // /dashboard/gyms matching /dashboard/gyms/xxx/sessions.
  const depth = clean.split("/").filter(Boolean).length;
  if (depth >= 4 && pathname.startsWith(clean + "/")) return true;
  return false;
}

// ─── Flat nav (no toggle) ─────────────────────────────────────────────────────

function FlatNavItems({ items, pathname }: { items: NavItem[]; pathname: string }) {
  return (
    <div className="space-y-0.5">
      {items.map((item) => {
        const Icon = item.icon;
        const active = isActive(item.href, pathname);
        return (
          <Link
            key={item.href}
            href={item.href}
            className={clsx(
              "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
              active ? "bg-[#F1C40F]/10 text-[#F1C40F]" : "text-zinc-400 hover:text-white hover:bg-zinc-800/60"
            )}
          >
            <Icon size={16} />
            {item.label}
          </Link>
        );
      })}
    </div>
  );
}

// ─── Collapsible group ────────────────────────────────────────────────────────

function NavGroup({
  group,
  pathname,
  isOpen,
  onToggle,
}: {
  group: FacilityGroup;
  pathname: string;
  isOpen: boolean;
  onToggle: () => void;
}) {
  const Icon = group.icon;
  const hasActive = group.items.some((item) => isActive(item.href, pathname));

  // Single-item groups render as flat link (no toggle)
  if (group.items.length === 1) {
    const item = group.items[0];
    const ItemIcon = item.icon;
    const active = isActive(item.href, pathname);
    return (
      <Link
        href={item.href}
        className={clsx(
          "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
          active ? "bg-[#F1C40F]/10 text-[#F1C40F]" : "text-zinc-400 hover:text-white hover:bg-zinc-800/60"
        )}
      >
        <ItemIcon size={16} />
        {group.label}
      </Link>
    );
  }

  return (
    <div>
      {/* Group header */}
      <button
        onClick={onToggle}
        className={clsx(
          "w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-black uppercase tracking-widest transition-colors",
          hasActive
            ? `${group.color} bg-white/5`
            : "text-zinc-600 hover:text-zinc-400 hover:bg-zinc-800/40"
        )}
      >
        <div className="flex items-center gap-2">
          <Icon size={13} className={hasActive ? group.color : ""} />
          {group.label}
        </div>
        <ChevronDown
          size={12}
          className={clsx("transition-transform duration-200", isOpen ? "rotate-180" : "")}
        />
      </button>

      {/* Collapsible items */}
      {isOpen && (
        <div className="mt-0.5 ml-3 pl-3 border-l border-zinc-800 space-y-0.5">
          {group.items.map((item) => {
            const ItemIcon = item.icon;
            const active = isActive(item.href, pathname);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={clsx(
                  "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                  active ? "bg-[#F1C40F]/10 text-[#F1C40F]" : "text-zinc-400 hover:text-white hover:bg-zinc-800/60"
                )}
              >
                <ItemIcon size={15} />
                {item.label}
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ─── Flat section (super admin / owner platform links) ─────────────────────────

function renderFlatSection(items: NavItem[], pathname: string) {
  return (
    <div className="space-y-0.5">
      {items.map((link) => {
        const Icon = link.icon;
        // Platform-level links use exact match only — prevents /dashboard lighting
        // up on every gym sub-page.
        const clean = link.href.split("?")[0];
        const active = pathname === clean;
        return (
          <Link
            key={link.href}
            href={link.href}
            className={clsx(
              "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
              active ? "bg-[#F1C40F]/10 text-[#F1C40F]" : "text-zinc-400 hover:text-white hover:bg-zinc-800/60"
            )}
          >
            <Icon size={16} />
            {link.label}
          </Link>
        );
      })}
    </div>
  );
}

// ─── Main Sidebar ─────────────────────────────────────────────────────────────

export function Sidebar() {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const { user, token, logout } = useAuthStore();
  const { selectedGymId, setSelectedGymId } = useGymStore();

  const isOwner = user?.role === "GYM_OWNER";
  const isSAdmin = isSuperAdmin(user?.role);
  const isBAdmin = user?.role === "BRANCH_ADMIN";
  const isTrainerRole = isTrainer(user?.role);

  const activeContextId = selectedGymId || (isBAdmin ? user?.managedGymId : null);

  // Auto-sync gym context from URL
  useEffect(() => {
    if (user?.role === "BRANCH_ADMIN" && user.managedGymId) {
      if (selectedGymId !== user.managedGymId) setSelectedGymId(user.managedGymId);
      return;
    }
    const pathParts = pathname.split("/");
    const gymsIdx = pathParts.indexOf("gyms");
    if (gymsIdx !== -1 && pathParts[gymsIdx + 1] && pathParts[gymsIdx + 1] !== "page") {
      const pathGymId = pathParts[gymsIdx + 1];
      if (selectedGymId !== pathGymId) setSelectedGymId(pathGymId);
      return;
    }
    const queryGymId = searchParams.get("gymId");
    if (queryGymId && selectedGymId !== queryGymId) setSelectedGymId(queryGymId);
  }, [pathname, searchParams, user, selectedGymId, setSelectedGymId]);

  // Build facility groups
  const facilityGroups = activeContextId && (isOwner || isBAdmin)
    ? buildFacilityGroups(activeContextId, isOwner, isBAdmin)
    : [];

  // Track which groups are open — auto-open the group that has the active link
  const [openGroups, setOpenGroups] = useState<Set<string>>(() => {
    const open = new Set<string>();
    // Default: marketing + the group that would be active
    open.add("marketing");
    return open;
  });

  // When pathname changes, auto-open the group that has the active link
  useEffect(() => {
    if (facilityGroups.length === 0) return;
    setOpenGroups((prev) => {
      const next = new Set(prev);
      facilityGroups.forEach((g) => {
        if (!g.flat && g.items.some((item) => isActive(item.href, pathname))) {
          next.add(g.id);
        }
      });
      return next;
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname, activeContextId]);

  function toggleGroup(id: string) {
    setOpenGroups((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  }

  return (
    <aside className="w-64 bg-[#121721] border-r border-zinc-800 min-h-screen flex flex-col">
      {/* Logo */}
      <div className="p-6 border-b border-zinc-800 h-[72px] flex flex-col justify-center">
        <h1 className="text-xl font-bold text-white tracking-tighter uppercase italic">
          <span className="text-[#F1C40F]">Amirani</span> Admin
        </h1>
        <p className="text-[10px] font-black uppercase tracking-[0.15em] text-zinc-600 mt-0.5">
          {isSAdmin ? "Platform Control" : isOwner ? "Gym Owner" : isTrainerRole ? "Trainer" : "Branch Manager"}
        </p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-3 overflow-y-auto space-y-1">

        {/* ── SUPER ADMIN ── */}
        {isSAdmin && renderFlatSection(superAdminLinks, pathname)}

        {/* ── GYM OWNER platform links ── */}
        {isOwner && (
          <>
            {renderFlatSection(gymOwnerPlatformLinks, pathname)}
          </>
        )}

        {/* ── TRAINER ── */}
        {isTrainerRole && renderFlatSection([
          { href: "/dashboard/trainer",           label: "My Members",   icon: Users },
          { href: "/dashboard/trainer/workout",   label: "Workout Plans", icon: Dumbbell },
          { href: "/dashboard/trainer/diet",      label: "Diet Plans",   icon: ClipboardList },
          { href: "/dashboard/trainer/messages",  label: "Messages",     icon: MessageSquare },
        ], pathname)}

        {/* ── FACILITY CONTEXT ── */}
        {facilityGroups.length > 0 && (
          <>
            {/* Divider with active facility label */}
            {isOwner && (
              <div className="pt-3 pb-1">
                <div className="flex items-center gap-2 px-3">
                  <div className="flex-1 h-px bg-zinc-800" />
                  <span className="text-[9px] font-black uppercase tracking-[0.25em] text-zinc-600">
                    Active Facility
                  </span>
                  <div className="flex-1 h-px bg-zinc-800" />
                </div>
              </div>
            )}

            {/* Operations — always flat/visible */}
            {facilityGroups
              .filter((g) => g.flat)
              .map((g) => (
                <FlatNavItems key={g.id} items={g.items} pathname={pathname} />
              ))}

            {/* Separator */}
            <div className="h-px bg-zinc-800 mx-2 my-1" />

            {/* Collapsible groups */}
            {facilityGroups
              .filter((g) => !g.flat)
              .map((g) => (
                <NavGroup
                  key={g.id}
                  group={g}
                  pathname={pathname}
                  isOpen={openGroups.has(g.id)}
                  onToggle={() => toggleGroup(g.id)}
                />
              ))}
          </>
        )}
      </nav>

      {/* SaaS Status Widget */}
      {isOwner && !!token && <SaaSStatusWidget token={token} />}

      {/* User section */}
      <div className="p-3 border-t border-zinc-800">
        <div className="flex items-center gap-3 px-3 py-2 mb-1">
          <div className="w-8 h-8 rounded-full bg-[#F1C40F]/20 flex items-center justify-center flex-shrink-0">
            <span className="text-[#F1C40F] font-bold text-sm">
              {user?.fullName?.charAt(0) || "A"}
            </span>
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-white truncate">{user?.fullName}</p>
            <p className="text-xs text-zinc-500 truncate">{user?.email}</p>
          </div>
        </div>
        <button
          onClick={() => { logout(); window.location.href = "/login"; }}
          className="flex items-center gap-3 w-full px-3 py-2 rounded-lg text-sm font-medium text-zinc-500 hover:text-red-400 hover:bg-red-500/10 transition-colors"
        >
          <LogOut size={16} />
          Sign Out
        </button>
      </div>
    </aside>
  );
}

// ─── SaaS Status Widget ───────────────────────────────────────────────────────

function SaaSStatusWidget({ token }: { token: string }) {
  const { data: saas, isLoading } = useQuery({
    queryKey: ["saas-status"],
    queryFn: () => platformApi.getSaaSStatus(token),
    refetchInterval: 300000,
  });

  if (isLoading || !saas) return null;

  const isTrial = saas.status === "TRIAL";
  const isPastDue = saas.status === "PAST_DUE";
  const isOff = saas.status === "OFF";

  return (
    <div className="mx-3 mb-3 p-3 bg-zinc-800/50 border border-zinc-700/50 rounded-xl space-y-2">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-[9px] font-black uppercase tracking-widest text-zinc-600">Subscription</p>
          <p className={clsx(
            "text-xs font-bold mt-0.5",
            isTrial ? "text-blue-400" : isPastDue || isOff ? "text-red-400" : "text-green-400"
          )}>
            {saas.status}
          </p>
        </div>
        <CreditCard size={14} className="text-zinc-600" />
      </div>
      <div className="space-y-1">
        <div className="flex justify-between text-[10px] text-zinc-400">
          <span>{isTrial ? "Trial days left" : "Days to billing"}</span>
          <span className="text-white font-medium">{saas.daysLeft}d</span>
        </div>
        <div className="w-full bg-zinc-700 h-1 rounded-full overflow-hidden">
          <div
            className={clsx("h-full transition-all", isTrial ? "bg-blue-500" : isPastDue || isOff ? "bg-red-500" : "bg-green-500")}
            style={{ width: `${Math.min(100, (saas.daysLeft / (isTrial ? 14 : 30)) * 100)}%` }}
          />
        </div>
      </div>
      <div className="flex justify-between items-center text-[10px]">
        <span className="text-zinc-500">Monthly Est.</span>
        <span className="text-white font-mono">${saas.totalCostPerMonth.toFixed(2)}</span>
      </div>
    </div>
  );
}
