import React from "react";
import { MembershipStatus } from "@/lib/api";

interface StatusBadgeProps {
  status: MembershipStatus;
  className?: string;
}

const statusConfig: Record<MembershipStatus, { label: string; classes: string }> = {
  ACTIVE: {
    label: "Active",
    classes: "bg-emerald-500/10 text-emerald-500 border-emerald-500/20",
  },
  EXPIRED: {
    label: "Expired",
    classes: "bg-red-500/10 text-red-500 border-red-500/20",
  },
  PENDING: {
    label: "Pending",
    classes: "bg-amber-500/10 text-amber-500 border-amber-500/20",
  },
  CANCELLED: {
    label: "Cancelled",
    classes: "bg-zinc-500/10 text-zinc-500 border-zinc-500/20",
  },
  SUSPENDED: {
    label: "Suspended",
    classes: "bg-orange-500/10 text-orange-500 border-orange-500/20",
  },
};

const StatusBadge: React.FC<StatusBadgeProps> = ({ status, className = "" }) => {
  const config = statusConfig[status] || {
    label: status,
    classes: "bg-zinc-500/10 text-zinc-500 border-zinc-500/20",
  };

  return (
    <span
      className={`px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider border transition-all ${config.classes} ${className}`}
    >
      {config.label}
    </span>
  );
};

export default StatusBadge;
