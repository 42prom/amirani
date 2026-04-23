"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { User, Role } from "./api";

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  setAuth: (user: User, token: string) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      setAuth: (user, token) =>
        set({ user, token, isAuthenticated: true }),
      logout: () =>
        set({ user: null, token: null, isAuthenticated: false }),
    }),
    {
      name: "amirani-admin-auth",
    }
  )
);

// Helper to check role permissions
export function hasRole(userRole: Role | undefined, allowedRoles: Role[]): boolean {
  if (!userRole) return false;
  return allowedRoles.includes(userRole);
}

export function isSuperAdmin(role?: Role): boolean {
  return role === "SUPER_ADMIN";
}

export function isGymOwnerOrAbove(role?: Role): boolean {
  return role === "SUPER_ADMIN" || role === "GYM_OWNER";
}

export function isBranchAdmin(role?: Role): boolean {
  return role === "BRANCH_ADMIN";
}

export function isBranchAdminOrAbove(role?: Role): boolean {
  return role === "SUPER_ADMIN" || role === "GYM_OWNER" || role === "BRANCH_ADMIN";
}

export function isStaff(role?: Role): boolean {
  return role === "BRANCH_ADMIN" || role === "TRAINER";
}

export function isTrainer(role?: Role): boolean {
  return role === "TRAINER";
}
