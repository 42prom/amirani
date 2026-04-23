"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore, isBranchAdminOrAbove } from "@/lib/auth-store";

export default function Home() {
  const router = useRouter();
  const { isAuthenticated, user } = useAuthStore();

  useEffect(() => {
    if (isAuthenticated && isBranchAdminOrAbove(user?.role)) {
      router.push("/dashboard");
    } else {
      router.push("/login");
    }
  }, [isAuthenticated, user, router]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#0a0d14]">
      <div className="text-zinc-400">Redirecting...</div>
    </div>
  );
}
