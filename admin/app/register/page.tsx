"use client";

import { useState, useEffect, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { authApi } from "@/lib/api";
import { useAuthStore } from "@/lib/auth-store";
import { RefreshCw, AlertTriangle, CheckCircle, Mail } from "lucide-react";

function RegisterContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const setAuth = useAuthStore((state) => state.setAuth);

  const token = searchParams.get("token");

  const [fullName, setFullName] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  // Invitation validation state
  const [validating, setValidating] = useState(true);
  const [invitation, setInvitation] = useState<{
    valid: boolean;
    email: string;
    expiresAt: string;
  } | null>(null);
  const [validationError, setValidationError] = useState("");

  // Validate token on mount
  useEffect(() => {
    if (!token) {
      setValidating(false);
      setValidationError("No invitation token provided");
      return;
    }

    authApi
      .validateInvitation(token)
      .then((data) => {
        setInvitation(data);
        setValidating(false);
      })
      .catch((err) => {
        setValidationError(err.message || "Invalid or expired invitation");
        setValidating(false);
      });
  }, [token]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (password !== confirmPassword) {
      setError("Passwords do not match");
      return;
    }

    if (password.length < 8) {
      setError("Password must be at least 8 characters");
      return;
    }

    setLoading(true);

    try {
      const { user, token: authToken } = await authApi.registerWithInvitation(
        token!,
        password,
        fullName
      );

      setAuth(user, authToken);
      router.push("/dashboard");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Registration failed");
    } finally {
      setLoading(false);
    }
  };

  // Loading state
  if (validating) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#121721] to-[#0a0d14]">
        <div className="text-center">
          <RefreshCw className="animate-spin text-[#F1C40F] mx-auto mb-4" size={48} />
          <p className="text-zinc-400">Validating invitation...</p>
        </div>
      </div>
    );
  }

  // Invalid token state
  if (validationError || !invitation) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#121721] to-[#0a0d14]">
        <div className="w-full max-w-md p-8 text-center">
          <div className="w-20 h-20 bg-red-500/10 rounded-full flex items-center justify-center mx-auto mb-6">
            <AlertTriangle className="text-red-400" size={40} />
          </div>
          <h1 className="text-2xl font-bold text-white mb-2">Invalid Invitation</h1>
          <p className="text-zinc-400 mb-6">
            {validationError || "This invitation link is invalid or has expired."}
          </p>
          <button
            onClick={() => router.push("/login")}
            className="px-6 py-3 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors"
          >
            Go to Login
          </button>
        </div>
      </div>
    );
  }

  // Registration form
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#121721] to-[#0a0d14]">
      <div className="w-full max-w-md p-8">
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-green-500/10 rounded-full flex items-center justify-center mx-auto mb-4">
            <CheckCircle className="text-green-400" size={32} />
          </div>
          <h1 className="text-3xl font-bold text-white mb-2">
            Welcome to Amirani
          </h1>
          <p className="text-zinc-400">Complete your Gym Owner registration</p>
        </div>

        {/* Invitation Info */}
        <div className="bg-[#1a2035] border border-zinc-700 rounded-lg p-4 mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-[#F1C40F]/10 rounded-full flex items-center justify-center">
              <Mail className="text-[#F1C40F]" size={20} />
            </div>
            <div>
              <p className="text-sm text-zinc-400">Registering as</p>
              <p className="text-white font-medium">{invitation.email}</p>
            </div>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {error && (
            <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4 text-red-400 text-sm">
              {error}
            </div>
          )}

          <div>
            <label
              htmlFor="fullName"
              className="block text-sm font-medium text-zinc-300 mb-2"
            >
              Full Name
            </label>
            <input
              id="fullName"
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              required
              minLength={2}
              className="w-full px-4 py-3 bg-[#1a2035] border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F] focus:ring-1 focus:ring-[#F1C40F]"
              placeholder="John Smith"
            />
          </div>

          <div>
            <label
              htmlFor="password"
              className="block text-sm font-medium text-zinc-300 mb-2"
            >
              Password
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={8}
              className="w-full px-4 py-3 bg-[#1a2035] border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F] focus:ring-1 focus:ring-[#F1C40F]"
              placeholder="Min 8 characters"
            />
          </div>

          <div>
            <label
              htmlFor="confirmPassword"
              className="block text-sm font-medium text-zinc-300 mb-2"
            >
              Confirm Password
            </label>
            <input
              id="confirmPassword"
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              required
              className="w-full px-4 py-3 bg-[#1a2035] border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F] focus:ring-1 focus:ring-[#F1C40F]"
              placeholder="Confirm your password"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-[#F1C40F] text-black font-semibold rounded-full hover:bg-[#F4D03F] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? "Creating Account..." : "Create Account"}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-zinc-500">
          Already have an account?{" "}
          <button
            onClick={() => router.push("/login")}
            className="text-[#F1C40F] hover:underline"
          >
            Sign in
          </button>
        </p>

        <p className="mt-4 text-center text-xs text-zinc-600">
          Invitation expires on{" "}
          {new Date(invitation.expiresAt).toLocaleDateString()}
        </p>
      </div>
    </div>
  );
}

export default function RegisterPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#121721] to-[#0a0d14]">
          <div className="text-center">
            <RefreshCw className="animate-spin text-[#F1C40F] mx-auto mb-4" size={48} />
            <p className="text-zinc-400">Loading...</p>
          </div>
        </div>
      }
    >
      <RegisterContent />
    </Suspense>
  );
}
