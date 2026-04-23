"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore, isGymOwnerOrAbove, isBranchAdmin, isTrainer } from "@/lib/auth-store";
import { Sidebar } from "@/components/sidebar";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const { isAuthenticated, user } = useAuthStore();

  useEffect(() => {
    if (!isAuthenticated) {
      router.push("/login");
      return;
    }

    const canAccess =
      isGymOwnerOrAbove(user?.role) ||
      isBranchAdmin(user?.role) ||
      isTrainer(user?.role);

    if (!canAccess) {
      router.push("/login");
    }
  }, [isAuthenticated, user, router]);

  const canAccess =
    isGymOwnerOrAbove(user?.role) ||
    isBranchAdmin(user?.role) ||
    isTrainer(user?.role);

  if (!isAuthenticated || !canAccess) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#0a0d14]">
        <div className="text-zinc-400">Loading...</div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-[#0a0d14]">
      <Sidebar />
      <main className="flex-1 p-8">{children}</main>
    </div>
  );
}
