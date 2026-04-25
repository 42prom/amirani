"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { authApi } from "@/lib/api";
import { useAuthStore } from "@/lib/auth-store";

export default function LoginPage() {
  const router = useRouter();
  const setAuth = useAuthStore((state) => state.setAuth);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const { user, token } = await authApi.login(email, password);

      // Only allow staff roles
      const allowedRoles = ["SUPER_ADMIN", "GYM_OWNER", "BRANCH_ADMIN", "TRAINER"];
      if (!allowedRoles.includes(user.role)) {
        setError("Access denied. Staff accounts only.");
        setLoading(false);
        return;
      }

      setAuth(user, token);
      router.push(user.role === "TRAINER" ? "/dashboard/trainer" : "/dashboard");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#121721] to-[#0a0d14]">
      <div className="w-full max-w-md p-8">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">Amirani Admin</h1>
          <p className="text-zinc-400">Sign in to manage your gyms</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {error && (
            <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4 text-red-400 text-sm">
              {error}
            </div>
          )}

          <div>
            <label htmlFor="email" className="block text-sm font-medium text-zinc-300 mb-2">
              Email
            </label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="w-full px-4 py-3 bg-[#1a2035] border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F] focus:ring-1 focus:ring-[#F1C40F]"
              placeholder="admin@example.com"
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-zinc-300 mb-2">
              Password
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full px-4 py-3 bg-[#1a2035] border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F] focus:ring-1 focus:ring-[#F1C40F]"
              placeholder="••••••••"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-[#F1C40F] text-black font-semibold rounded-full hover:bg-[#F4D03F] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? "Signing in..." : "Sign In"}
          </button>

          {(process.env.NODE_ENV === "development" || process.env.NEXT_PUBLIC_ENABLE_QUICK_LOGIN === "true") && <div className="pt-4 border-t border-zinc-800 space-y-3">
            <p className="text-center text-xs text-zinc-500 uppercase tracking-widest font-bold">Development Quick Login</p>
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                disabled={loading}
                onClick={async () => {
                  setLoading(true);
                  setError("");
                  try {
                    const { user, token } = await authApi.login("super@amirani.dev", "SuperAdmin123!");
                    setAuth(user, token);
                    router.push("/dashboard");
                  } catch (err: unknown) {
                    const message = err instanceof Error ? err.message : "Super Admin login failed";
                    setError(`${message}. (Check if DB/Backend are running or run npm run db:seed)`);
                  } finally {
                    setLoading(false);
                  }
                }}
                className="py-2 bg-purple-500/20 text-purple-400 border border-purple-500/30 rounded-lg text-xs font-semibold hover:bg-purple-500/30 transition-colors disabled:opacity-50"
              >
                Super Admin
              </button>
              <button
                type="button"
                disabled={loading}
                onClick={async () => {
                  setLoading(true);
                  setError("");
                  try {
                    const { user, token } = await authApi.login("owner@amirani.dev", "GymOwner123!");
                    setAuth(user, token);
                    router.push("/dashboard");
                  } catch (err: unknown) {
                    const message = err instanceof Error ? err.message : "Gym Owner login failed";
                    setError(`${message}. (Check if DB/Backend are running or run npm run db:seed)`);
                  } finally {
                    setLoading(false);
                  }
                }}
                className="py-2 bg-blue-500/20 text-blue-400 border border-blue-500/30 rounded-lg text-xs font-semibold hover:bg-blue-500/30 transition-colors disabled:opacity-50"
              >
                Gym Owner
              </button>
            </div>

            <button
              type="button"
              disabled={loading}
              onClick={async () => {
                setLoading(true);
                setError("");
                try {
                  const { user, token } = await authApi.login("branch@amirani.dev", "BranchAdmin123!");
                  setAuth(user, token);
                  // Navigate to the branch admin's managed gym
                  if (user.managedGymId) {
                    router.push(`/dashboard/gyms/${user.managedGymId}`);
                  } else {
                    router.push("/dashboard");
                  }
                } catch (err: unknown) {
                  const message = err instanceof Error ? err.message : "Branch Admin login failed";
                  setError(`${message}. (Check if DB/Backend are running or run npm run db:seed)`);
                } finally {
                  setLoading(false);
                }
              }}
              className="w-full py-2 bg-orange-500/20 text-orange-400 border border-orange-500/30 rounded-lg text-xs font-semibold hover:bg-orange-500/30 transition-colors disabled:opacity-50"
            >
              Branch Admin
            </button>
            <button
              type="button"
              disabled={loading}
              onClick={async () => {
                setLoading(true);
                setError("");
                try {
                  const { user, token } = await authApi.login("trainer@amirani.dev", "Trainer123!");
                  setAuth(user, token);
                  router.push("/dashboard/trainer");
                } catch (err: unknown) {
                  const message = err instanceof Error ? err.message : "Trainer login failed";
                  setError(`${message}. (Check if DB/Backend are running or run npm run db:seed)`);
                } finally {
                  setLoading(false);
                }
              }}
              className="w-full py-2 bg-green-500/20 text-green-400 border border-green-500/30 rounded-lg text-xs font-semibold hover:bg-green-500/30 transition-colors disabled:opacity-50"
            >
              Trainer
            </button>
          </div>}
        </form>

        <p className="mt-8 text-center text-sm text-zinc-500">
          Super Admin, Gym Owner, Branch Admin, and Trainer accounts can access this dashboard.
        </p>
      </div>
    </div>
  );
}
