export interface ErrorDetail {
  message: string;
  field?: string;
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3085/api";

type RequestOptions = {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  body?: unknown;
  token?: string;
};

export async function api<T>(
  endpoint: string,
  options: RequestOptions = {}
): Promise<T> {
  const { method = "GET", body, token } = options;

  const headers: HeadersInit = {
    "Content-Type": "application/json",
  };

  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const errorBody = await response.json().catch(() => ({}));
    let errorMessage = errorBody.error?.message || errorBody.message || "Request failed";
    
    if (errorBody.error?.details && Array.isArray(errorBody.error.details)) {
      const details = errorBody.error.details.map((d: ErrorDetail) => d.message).join(", ");
      errorMessage = `${errorMessage}: ${details}`;
    }
    
    throw new Error(errorMessage);
  }

  // Handle 204 No Content
  if (response.status === 204) {
    return {} as T;
  }

  const result = await response.json();
  return result.data !== undefined ? result.data : result;
}

// Auth API
export const authApi = {
  login: (email: string, password: string) =>
    api<{ user: User; token: string }>("/auth/login", {
      method: "POST",
      body: { email, password },
    }),
  registerWithInvitation: (token: string, password: string, fullName: string) =>
    api<{ user: User; token: string }>("/auth/register-invite", {
      method: "POST",
      body: { token, password, fullName },
    }),
  validateInvitation: (token: string) =>
    api<{ valid: boolean; email: string; expiresAt: string }>(`/admin/invitations/validate/${token}`),
};

// Gyms API
export const gymsApi = {
  getAll: (token: string) => api<Gym[]>("/gym-management", { token }),
  getById: (id: string, token: string) => api<GymDetail>(`/gym-management/${id}`, { token }),
  create: (data: CreateGymData, token: string) =>
    api<Gym>("/gym-management", { method: "POST", body: data, token }),
  update: (id: string, data: Partial<CreateGymData>, token: string) =>
    api<Gym>(`/gym-management/${id}`, { method: "PATCH", body: data, token }),
  delete: (id: string, token: string) =>
    api(`/gym-management/${id}`, { method: "DELETE", token }),
  getStats: (id: string, token: string) =>
    api<BranchStatsResponse>(`/gym-management/${id}/stats`, { token }),
  getRegistrationQr: (id: string, token: string) =>
    api<{ registrationCode: string; qrContent: string; gymId: string; gymName: string }>(
      `/gym-management/${id}/registration-qr`, { token }
    ),
};

// Admin API
export const adminApi = {
  getGymOwners: (token: string) => api<GymOwner[]>("/admin/gym-owners", { token }),
  createGymOwner: (data: CreateUserData, token: string) =>
    api<User>("/admin/gym-owners", { method: "POST", body: data, token }),
  updateGymOwner: (id: string, data: Partial<CreateUserData> & { isActive?: boolean }, token: string) =>
    api<User>(`/admin/gym-owners/${id}`, { method: "PATCH", body: data, token }),
  createTrainer: (data: CreateTrainerData, token: string) =>
    api<Trainer>("/admin/trainers", { method: "POST", body: data, token }),
  updateTrainer: (id: string, data: Partial<CreateTrainerData> & { isAvailable?: boolean }, token: string) =>
    api<Trainer>(`/admin/trainers/${id}`, { method: "PATCH", body: data, token }),
  deleteTrainer: (id: string, token: string) =>
    api(`/admin/trainers/${id}`, { method: "DELETE", token }),
  deleteBranchAdmin: (id: string, token: string) =>
    api(`/admin/branch-admins/${id}`, { method: "DELETE", token }),
  createBranchAdmin: (data: CreateTrainerData, token: string) =>
    api<User>("/admin/branch-admins", { method: "POST", body: data, token }),
  getGymTrainers: (gymId: string, token: string) =>
    api<Trainer[]>(`/admin/gyms/${gymId}/trainers`, { token }),
  deactivateUser: (id: string, token: string) =>
    api<User>(`/admin/users/${id}/deactivate`, { method: "POST", token }),
  activateUser: (id: string, token: string) =>
    api<User>(`/admin/users/${id}/activate`, { method: "POST", token }),
  extendSaaSTrial: (ownerId: string, days: number, token: string) =>
    api<{ id: string; saasTrialEndsAt: string }>(`/admin/gym-owners/${ownerId}/extend-saas-trial`, {
      method: "POST",
      body: { days },
      token,
    }),
};

// Trainers API (alias for convenience)
export const trainersApi = {
  getByGym: (gymId: string, token: string) =>
    api<Trainer[]>(`/admin/gyms/${gymId}/trainers`, { token }),
};

// Memberships API
export const membershipsApi = {
  getGymMembers: (gymId: string, token: string) =>
    api<Membership[]>(`/memberships/gyms/${gymId}/members`, { token }),
  getGymPlans: (gymId: string, token: string) =>
    api<SubscriptionPlan[]>(`/memberships/gyms/${gymId}/subscription-plans`, { token }),
  createPlan: (gymId: string, data: CreatePlanData, token: string) =>
    api<SubscriptionPlan>(`/memberships/gyms/${gymId}/subscription-plans`, {
      method: "POST",
      body: data,
      token,
    }),
  updateStatus: (id: string, status: MembershipStatus, token: string) =>
    api<Membership>(`/memberships/${id}/status`, {
      method: "PATCH",
      body: { status },
      token,
    }),
  assignTrainer: (id: string, trainerId: string | null, token: string) =>
    api<Membership>(`/memberships/${id}/assign-trainer`, {
      method: "POST",
      body: { trainerId },
      token,
    }),
  manualCreateMember: (gymId: string, data: ManualRegistrationRequest, token: string) =>
    api<{ user: User; membership: Membership }>(`/memberships/gyms/${gymId}/manual-register`, {
      method: "POST",
      body: data,
      token,
    }),
  manualActivateMember: (gymId: string, data: ManualActivationRequest, token: string) =>
    api<{ membership: Membership }>(`/memberships/gyms/${gymId}/manual-activate`, {
      method: "POST",
      body: data,
      token,
    }),
  updateMemberProfile: (gymId: string, userId: string, data: Partial<User>, token: string) =>
    api<User>(`/memberships/gyms/${gymId}/members/${userId}`, {
      method: "PATCH",
      body: data,
      token,
    }),
  removeMemberFromGym: (gymId: string, userId: string, token: string) =>
    api<{ success: boolean; message: string }>(`/memberships/gyms/${gymId}/members/${userId}`, {
      method: "DELETE",
      token,
    }),
};

export type MembershipStatus = "ACTIVE" | "EXPIRED" | "CANCELLED" | "PENDING" | "SUSPENDED";

// Equipment API (uses gym-owner routes)
export const equipmentApi = {
  getByGym: (gymId: string, token: string, options?: { category?: string; status?: string; search?: string }) => {
    const params = new URLSearchParams();
    if (options?.category) params.append("category", options.category);
    if (options?.status) params.append("status", options.status);
    if (options?.search) params.append("search", options.search);
    const queryString = params.toString();
    return api<Equipment[]>(`/gym-owner/gyms/${gymId}/equipment${queryString ? `?${queryString}` : ""}`, { token });
  },
  create: (gymId: string, data: CreateEquipmentData, token: string) =>
    api<Equipment>(`/gym-owner/gyms/${gymId}/equipment`, { method: "POST", body: data, token }),
  update: (id: string, data: Partial<CreateEquipmentData>, token: string) =>
    api<Equipment>(`/gym-owner/equipment/${id}`, { method: "PATCH", body: data, token }),
  delete: (id: string, token: string) =>
    api(`/gym-owner/equipment/${id}`, { method: "DELETE", token }),
  getStats: (gymId: string, token: string) =>
    api<EquipmentStats>(`/gym-owner/gyms/${gymId}/equipment/stats`, { token }),

  // Catalog Browse for Gym Owners
  getCatalog: (token: string, options?: { category?: string; brand?: string; search?: string }) => {
    const params = new URLSearchParams();
    if (options?.category) params.append("category", options.category);
    if (options?.brand) params.append("brand", options.brand);
    if (options?.search) params.append("search", options.search);
    const queryString = params.toString();
    return api<CatalogItem[]>(`/gym-owner/catalog${queryString ? `?${queryString}` : ""}`, { token });
  },
  createFromCatalog: (gymId: string, catalogItemId: string, data: Partial<CreateEquipmentData>, token: string) =>
    api<Equipment>(`/gym-owner/gyms/${gymId}/equipment/from-catalog/${catalogItemId}`, {
      method: "POST",
      body: data,
      token,
    }),
};

// Door Access API
export const doorAccessApi = {
  getGymLogs: (gymId: string, token: string) =>
    api<AccessLog[]>(`/door-access/gyms/${gymId}/logs`, { token }),
  getGymSystems: (gymId: string, token: string) =>
    api<DoorSystem[]>(`/door-access/gyms/${gymId}/systems`, { token }),
  checkHealth: (gymId: string, token: string) =>
    api<DoorHealth[]>(`/door-access/gyms/${gymId}/systems/health`, { token }),
  createSystem: (gymId: string, data: CreateDoorSystemData, token: string) =>
    api<DoorSystem>(`/door-access/gyms/${gymId}/systems`, {
      method: "POST",
      body: data,
      token,
    }),
  updateSystem: (id: string, data: Partial<CreateDoorSystemData> & { isActive?: boolean }, token: string) =>
    api<DoorSystem>(`/door-access/systems/${id}`, {
      method: "PATCH",
      body: data,
      token,
    }),
  deleteSystem: (id: string, token: string) =>
    api(`/door-access/systems/${id}`, { method: "DELETE", token }),
  unlock: (id: string, token: string) =>
    api<{ success: boolean; code?: string }>(`/door-access/systems/${id}/unlock`, { 
      method: "POST", 
      token 
    }),
};

// ─── Gym Live / Entry API ─────────────────────────────────────────────────────

export interface LiveMember {
  attendanceId: string;
  userId: string;
  fullName: string;
  avatarUrl: string | null;
  planName: string;
  checkInTime: string;
  minutesInGym: number;
}

export interface GymLiveData {
  gymId: string;
  gymName: string;
  currentOccupancy: number;
  maxCapacity: number;
  occupancyPercent: number | null;
  todayCheckIns: number;
  currentlyIn: LiveMember[];
}

export const gymLiveApi = {
  getLive: (gymId: string, token: string) =>
    api<GymLiveData>(`/gym-entry/live/${gymId}`, { token }),
};

export type DoorSystemType = "QR_CODE" | "NFC" | "PIN_CODE" | "BLUETOOTH" | "BIOMETRIC";

export interface CreateDoorSystemData {
  name: string;
  type: DoorSystemType;
  location?: string;
  config?: Record<string, unknown>;
}

// ─── Hardware Gateway API ─────────────────────────────────────────────────────

export interface HardwareGateway {
  id: string;
  name: string;
  gymId: string;
  apiKey: string;
  location?: string;
  protocol: string;
  isOnline: boolean;
  lastSeenAt?: string;
  createdAt: string;
  _count?: { commands: number };
}

export interface CardCredential {
  id: string;
  userId: string;
  gymId: string;
  cardUid: string;
  cardType: string;
  label?: string;
  isActive: boolean;
  createdAt: string;
  user?: { id: string; fullName: string; avatarUrl?: string };
}

export const hardwareApi = {
  // Gateways
  getGateways: (gymId: string, token: string) =>
    api<HardwareGateway[]>(`/hardware/gateways?gymId=${gymId}`, { token }),

  createGateway: (data: { gymId: string; name: string; location?: string; protocol: string }, token: string) =>
    api<HardwareGateway>("/hardware/gateways", { method: "POST", body: data, token }),

  // Remote unlock — branch manager presses button
  remoteUnlock: (gatewayId: string, doorId: string | undefined, token: string, durationMs = 3000) =>
    api<{ id: string; status: string }>("/hardware/commands/unlock", {
      method: "POST",
      body: { gatewayId, doorId, durationMs },
      token,
    }),

  // Card credentials
  getCards: (gymId: string, token: string, userId?: string) =>
    api<CardCredential[]>(`/hardware/cards?gymId=${gymId}${userId ? `&userId=${userId}` : ""}`, { token }),

  enrollCard: (data: { gymId: string; userId: string; cardUid: string; cardType: string; label?: string }, token: string) =>
    api<CardCredential>("/hardware/cards", { method: "POST", body: data, token }),

  revokeCard: (id: string, gymId: string, token: string) =>
    api<{ revoked: boolean }>(`/hardware/cards/${id}?gymId=${gymId}`, { method: "DELETE", token }),

  deleteGateway: (id: string, gymId: string, token: string) =>
    api<{ deleted: boolean }>(`/hardware/gateways/${id}?gymId=${gymId}`, { method: "DELETE", token }),

  getStats: (gymId: string, token: string) =>
    api<{
      total: number; granted: number; denied: number; grantRate: number;
      today: number; week: number;
      peakHours: { hour: number; count: number }[];
      dailyTrend: { date: string; granted: number; denied: number }[];
      topMembers: { userId: string; fullName: string; avatarUrl?: string; count: number }[];
    }>(`/hardware/stats?gymId=${gymId}`, { token }),
};

// Upload API (uses FormData)
export type UploadCategory = "avatars" | "equipment" | "gyms";

export interface UploadResponse {
  filename: string;
  url: string;
  originalName: string;
  size: number;
  mimetype: string;
}

export const uploadApi = {
  uploadFile: async (file: File, category: UploadCategory, token: string): Promise<UploadResponse> => {
    const formData = new FormData();
    formData.append("file", file);

    const response = await fetch(`${API_BASE_URL}/upload/${category}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
      },
      body: formData,
    });

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      console.error("[UploadAPI] Upload failed:", errorBody);
      throw new Error(errorBody.error?.message || errorBody.message || "Upload failed");
    }

    const result = await response.json();
    console.log("[UploadAPI] Upload success:", result.data);
    return result.data;
  },

  deleteFile: async (filename: string, category: UploadCategory, token: string): Promise<void> => {
    const response = await fetch(`${API_BASE_URL}/upload/${category}/${filename}`, {
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      throw new Error(errorBody.error?.message || errorBody.message || "Delete failed");
    }
  },

  getFullUrl: (url: string | undefined | null): string => {
    if (!url) return "";
    if (url.startsWith("http")) return url;
    if (url.startsWith("/assets")) return url;
    
    // Static files in /uploads are served from the root, not under /api
    if (url.startsWith("/uploads")) {
      const baseUrl = API_BASE_URL.replace(/\/api$/, "");
      return `${baseUrl}${url}`;
    }
    
    return `${API_BASE_URL}${url}`;
  },
};

// Types
export type Role = "SUPER_ADMIN" | "GYM_OWNER" | "BRANCH_ADMIN" | "TRAINER" | "GYM_MEMBER" | "HOME_USER";

export interface User {
  id: string;
  email: string;
  fullName: string;
  role: Role;
  phoneNumber?: string;
  address?: string;
  avatarUrl?: string;
  idPhotoUrl?: string;
  dob?: string;
  weight?: string;
  height?: string;
  gender?: string;
  targetWeightKg?: string;
  personalNumber?: string;
  isVerified: boolean;
  isActive: boolean;
  managedGymId?: string;
  saasTrialEndsAt?: string;
  saasSubscriptionStatus?: "TRIAL" | "ACTIVE" | "PAST_DUE" | "OFF";
  saasNextBillingDate?: string;
  medicalConditions?: string;
  noMedicalConditions?: boolean;
  createdAt: string;
  weightHistory?: UserWeightHistory[];
}

export interface UserWeightHistory {
  id: string;
  userId: string;
  weight: number;
  date: string;
}

export interface GymOwner extends User {
  ownedGyms: { 
    id: string; 
    name: string; 
    city: string; 
    isActive: boolean;
    _count: { memberships: number };
  }[];
  isLifetimeFree?: boolean;
  customPricePerBranch?: number | null;
  customPlatformFeePercent?: number | null;
}

export interface RegistrationRequirements {
  fullName?: boolean;
  dateOfBirth?: boolean;
  personalNumber?: boolean;
  phoneNumber?: boolean;
  address?: boolean;
  selfiePhoto?: boolean;
  idPhoto?: boolean;
  healthInfo?: boolean;
}

export interface Gym {
  id: string;
  name: string;
  address: string;
  city: string;
  country: string;
  phone?: string;
  email?: string;
  logoUrl?: string;
  bannerUrl?: string;
  description?: string;
  themeColor?: string;
  welcomeMessage?: string;
  isActive: boolean;
  owner: { id: string; email: string; fullName: string };
  branches: Branch[];
  _count: { memberships: number; trainers: number; equipment: number };
  registrationRequirements?: RegistrationRequirements;
}

export interface Branch {
  id: string;
  name: string;
  address?: string;
  city?: string;
  phone?: string;
  maxCapacity: number;
  openTime?: string;
  closeTime?: string;
  gymId: string;
  isActive: boolean;
  createdAt: string;
  admins?: Array<{ id: string; fullName: string; email: string; avatarUrl: string | null }>;
  activeMembers?: number;
  trainerCount?: number;
  todayCheckins?: number;
}

export interface GymDetail extends Gym {
  trainers: Trainer[];
  subscriptionPlans: SubscriptionPlan[];
}

export interface Trainer {
  id: string;
  fullName: string;
  avatarUrl?: string;
  age?: number;
  specialization?: string;
  bio?: string;
  certifications: string[];
  isAvailable: boolean;
  gymId: string;
  userId?: string;
  email?: string;
  role?: Role;
  _count?: { assignedMembers: number };
  // Nested user relation returned by GymService.findById (trainer's linked account)
  user?: { id: string; email: string; fullName: string; avatarUrl?: string };
}

export interface Membership {
  id: string;
  startDate: string;
  endDate: string;
  status: MembershipStatus;
  trainerId?: string | null;
  user: { 
    id: string; 
    email: string; 
    fullName: string; 
    phone?: string; 
    phoneNumber?: string;
    avatarUrl?: string; 
    idPhotoUrl?: string;
    dob?: string;
    personalNumber?: string;
    address?: string;
    medicalConditions?: string;
    weightHistory?: UserWeightHistory[];
  };
  plan: { id: string; name: string; price: string };
  trainer?: { id: string; user: { fullName: string } } | null;
}

export interface SubscriptionPlan {
  id: string;
  name: string;
  description?: string;
  price: string;
  durationValue: number;
  durationUnit: string;
  features: string[];
  isActive: boolean;
}

export interface Equipment {
  id: string;
  name: string;
  category: string;
  brand?: string;
  model?: string;
  quantity: number;
  status: "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER";
  description?: string;
  imageUrl?: string;
  serialNumber?: string;
  purchasePrice?: string;
  purchaseDate?: string;
  warrantyExpiry?: string;
  location?: string;
  notes?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface DoorSystem {
  id: string;
  name: string;
  type: string;
  location?: string;
  isActive: boolean;
}

export interface AccessLog {
  id: string;
  accessTime: string;
  accessGranted: boolean;
  method: string;
  deviceInfo?: string;
  doorSystem: {
    name: string;
    location?: string;
  };
  user: {
    fullName: string;
    email: string;
    avatarUrl?: string | null;
  };
}

export interface DoorHealth {
  id: string;
  name: string;
  type: string;
  location?: string;
  isHealthy: boolean;
}

export interface EquipmentStats {
  total: number;
  available: number;
  maintenance: number;
  outOfOrder: number;
}

export interface CreateGymData {
  name: string;
  address: string;
  city: string;
  country: string;
  ownerId: string;
  phone?: string;
  email?: string;
  description?: string;
  logoUrl?: string;
  bannerUrl?: string;
  themeColor?: string;
  welcomeMessage?: string;
  registrationRequirements?: RegistrationRequirements;
}

export interface CreateUserData {
  email: string;
  password?: string;
  fullName: string;
  phoneNumber?: string;
  address?: string;
}

export interface CreateTrainerData {
  fullName: string;
  avatarUrl?: string;
  age?: number;
  gymId: string;
  specialization?: string;
  bio?: string;
  certifications?: string[];
  email?: string;
  password?: string;
}

export interface CreatePlanData {
  name: string;
  description?: string;
  price: number;
  durationValue?: number;
  durationUnit?: string;
  features?: string[];
}

export interface CreateEquipmentData {
  name: string;
  category: string;
  brand?: string;
  model?: string;
  quantity?: number;
  status?: "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER";
  description?: string;
  imageUrl?: string;
  serialNumber?: string;
  purchasePrice?: number;
  purchaseDate?: string;
  warrantyExpiry?: string;
  location?: string;
  notes?: string;
}

// ─── Platform Configuration Types ─────────────────────────────────────────────

export type AIProvider = "OPENAI" | "ANTHROPIC" | "GOOGLE_GEMINI" | "AZURE_OPENAI" | "DEEPSEEK";
export type UserTier = "FREE" | "GYM_MEMBER" | "HOME_PREMIUM";

export interface PlatformConfig {
  id: string;
  platformName: string;
  platformLogoUrl?: string;
  supportEmail?: string;
  privacyPolicyUrl?: string;
  termsOfServiceUrl?: string;
  maintenanceMode: boolean;
  pricePerBranch?: string | number;
  defaultTrialDays?: number;
  currency?: string;
  createdAt: string;
  updatedAt: string;
}

export interface SaaSStatusResponse {
  status: "TRIAL" | "ACTIVE" | "PAST_DUE" | "OFF";
  daysLeft: number;
  pricePerBranch: number;
  totalCostPerMonth: number;
  branchCount: number;
  nextBillingDate: string | null;
  isLifetimeFree?: boolean;
  customPricePerBranch?: number | null;
  customPlatformFeePercent?: number | null;
}

export interface AIConfig {
  id: string;
  activeProvider: AIProvider;
  openaiApiKey?: string;
  openaiModel: string;
  openaiOrgId?: string;
  anthropicApiKey?: string;
  anthropicModel: string;
  googleApiKey?: string;
  googleModel: string;
  azureApiKey?: string;
  azureEndpoint?: string;
  azureDeploymentName?: string;
  deepseekApiKey?: string;
  deepseekModel: string;
  deepseekBaseUrl: string;
  maxTokensPerRequest: number;
  temperature: number;
  isEnabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface PushNotificationConfig {
  id: string;
  fcmEnabled: boolean;
  fcmProjectId?: string;
  fcmPrivateKey?: string;
  fcmClientEmail?: string;
  apnsEnabled: boolean;
  apnsKeyId?: string;
  apnsTeamId?: string;
  apnsPrivateKey?: string;
  apnsBundleId?: string;
  apnsProduction: boolean;
  emailEnabled: boolean;
  emailProvider: string;
  sendgridApiKey?: string;
  smtpHost?: string;
  smtpPort?: number;
  smtpUser?: string;
  smtpPassword?: string;
  fromEmail?: string;
  fromName?: string;
  createdAt: string;
  updatedAt: string;
}

export interface StripeConfig {
  id: string;
  publishableKey?: string;
  secretKey?: string;
  webhookSecret?: string;
  connectEnabled: boolean;
  platformFeePercent: number;
  defaultCurrency: string;
  testMode: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface OAuthConfig {
  id: string;
  googleEnabled: boolean;
  googleClientId?: string;
  googleClientSecret?: string;
  appleEnabled: boolean;
  appleClientId?: string;
  appleTeamId?: string;
  appleKeyId?: string;
  applePrivateKey?: string;
  createdAt: string;
  updatedAt: string;
}

export interface TierLimits {
  tier: UserTier;
  aiTokensPerMonth: number;
  aiRequestsPerDay: number;
  workoutPlansPerMonth: number;
  dietPlansPerMonth: number;
  canAccessAICoach: boolean;
  canAccessDietPlanner: boolean;
  canAccessAdvancedStats: boolean;
  canExportData: boolean;
  maxProgressPhotos: number;
  description?: string;
  createdAt: string;
  updatedAt: string;
}

export interface AIUsageStats {
  totalRequests: number;
  totalTokens: number;
  promptTokens: number;
  completionTokens: number;
  estimatedCost: string;
  byProvider: Array<{ provider: AIProvider; _sum: { totalTokens: number }; _count: number }>;
  byType: Array<{ requestType: string; _sum: { totalTokens: number }; _count: number }>;
}

// ─── SaaS Types ─────────────────────────────────────────────────────────────

export interface SaaSInvoice {
  id: string;
  amount: string | number;
  currency: string;
  status: string;
  description: string;
  createdAt: string;
}

export interface SaaSSubscription {
  ownerId: string;
  email: string;
  fullName: string;
  status: string;
  trialEndsAt: string | null;
  nextBillingDate: string | null;
  branchCount: number;
  monthlyCost: number;
  isLifetimeFree?: boolean;
  customPricePerBranch?: number | null;
  customPlatformFeePercent?: number | null;
}

// ─── Platform Configuration API (Super Admin only) ───────────────────────────

export const platformApi = {
  // Platform Config
  getConfig: (token: string) =>
    api<PlatformConfig>("/platform/config", { token }),
  updateConfig: (data: Partial<PlatformConfig> & { pricePerBranch?: string | number; defaultTrialDays?: number; currency?: string }, token: string) =>
    api<PlatformConfig>("/platform/config", { method: "PATCH", body: data, token }),

  // SaaS Status
  getSaaSStatus: (token: string) =>
    api<SaaSStatusResponse>("/platform/saas/status", { token }),
  getSaaSInvoices: (token: string) =>
    api<SaaSInvoice[]>("/platform/saas/invoices", { token }),
  getAllSaaSSubscriptions: (token: string) =>
    api<SaaSSubscription[]>("/platform/saas/subscriptions", { token }),

  // Extend a Gym Owner's SaaS subscription manually (Super Admin only)
  extendSaaSSubscription: (ownerId: string, data: { days: number, amount: number, paymentMethod: string, notes?: string }, token: string) =>
    api<{ paymentId: string, status: string, nextBillingDate: string }>(`/platform/saas/subscriptions/${ownerId}/extend`, {
      method: "POST",
      body: data,
      token,
    }),

  // Update a Gym Owner's SaaS pricing overrides (Super Admin only)
  updateSaaSPricing: (ownerId: string, data: { isLifetimeFree?: boolean, customPricePerBranch?: number | null, customPlatformFeePercent?: number | null }, token: string) =>
    api<{ id: string, isLifetimeFree: boolean, customPricePerBranch: number | null, customPlatformFeePercent: number | null }>(`/platform/saas/subscriptions/${ownerId}/pricing`, {
      method: "PATCH",
      body: data,
      token,
    }),

  // AI Config
  getAIConfig: (token: string) =>
    api<AIConfig>("/platform/ai", { token }),
  updateAIConfig: (data: Partial<AIConfig>, token: string) =>
    api<AIConfig>("/platform/ai", { method: "PATCH", body: data, token }),
  testAIConnection: (provider: AIProvider, token: string) =>
    api<{ success: boolean; provider: AIProvider; message: string }>("/platform/ai/test", {
      method: "POST",
      body: { provider },
      token,
    }),
  getAIUsage: (token: string, startDate?: string, endDate?: string) => {
    const params = new URLSearchParams();
    if (startDate) params.append("startDate", startDate);
    if (endDate) params.append("endDate", endDate);
    const queryString = params.toString();
    return api<AIUsageStats>(`/platform/ai/usage${queryString ? `?${queryString}` : ""}`, { token });
  },

  // Push Notification Config
  getNotificationConfig: (token: string) =>
    api<PushNotificationConfig>("/platform/notifications", { token }),
  updateNotificationConfig: (data: Partial<PushNotificationConfig>, token: string) =>
    api<PushNotificationConfig>("/platform/notifications", { method: "PATCH", body: data, token }),

  // OAuth Config
  getOAuthConfig: (token: string) =>
    api<OAuthConfig>("/platform/oauth", { token }),
  updateOAuthConfig: (data: Partial<OAuthConfig>, token: string) =>
    api<OAuthConfig>("/platform/oauth", { method: "PATCH", body: data, token }),

  // Stripe Config
  getStripeConfig: (token: string) =>
    api<StripeConfig>("/platform/stripe", { token }),
  updateStripeConfig: (data: Partial<StripeConfig>, token: string) =>
    api<StripeConfig>("/platform/stripe", { method: "PATCH", body: data, token }),

  // Tier Limits
  getAllTierLimits: (token: string) =>
    api<TierLimits[]>("/platform/tiers", { token }),
  getTierLimits: (tier: UserTier, token: string) =>
    api<TierLimits>(`/platform/tiers/${tier}`, { token }),
  updateTierLimits: (tier: UserTier, data: Partial<TierLimits>, token: string) =>
    api<TierLimits>(`/platform/tiers/${tier}`, { method: "PATCH", body: data, token }),
  initializeTierLimits: (token: string) =>
    api<TierLimits[]>("/platform/tiers/initialize", { method: "POST", token }),
}

// ─── Gym Owner Types ──────────────────────────────────────────────────────────

export type DayOfWeek = "MONDAY" | "TUESDAY" | "WEDNESDAY" | "THURSDAY" | "FRIDAY" | "SATURDAY" | "SUNDAY";
export type PlanType = "full" | "morning" | "evening" | "weekend" | "weekday" | "custom";

export interface StripeConnectStatus {
  hasAccount: boolean;
  accountId?: string;
  status: string;
  onboardingComplete: boolean;
  payoutsEnabled: boolean;
  currency: string;
}

export interface Payment {
  id: string;
  amount: string;
  currency: string;
  status: "SUCCEEDED" | "FAILED" | "PENDING";
  description?: string;
  createdAt: string;
}

export interface OnboardingLink {
  url: string;
  expiresAt: string;
}

export interface GymEarnings {
  totalRevenue: number;
  platformFees: number;
  netEarnings: number;
  platformFeePercent: number;
  paymentCount: number;
  currency: string;
  payments: Payment[];
}

export interface EnhancedSubscriptionPlan {
  id: string;
  name: string;
  description?: string;
  price: string;
  durationValue: number;
  durationUnit: string;
  features: string[];
  isActive: boolean;
  hasTimeRestriction: boolean;
  accessStartTime?: string;
  accessEndTime?: string;
  accessDays: DayOfWeek[];
  planType: PlanType;
  displayOrder: number;
  createdAt: string;
  updatedAt: string;
  _count?: { memberships: number };
}

export interface CreateEnhancedPlanData {
  name: string;
  description?: string;
  price: number;
  durationValue?: number;
  durationUnit?: string;
  features?: string[];
  hasTimeRestriction?: boolean;
  accessStartTime?: string;
  accessEndTime?: string;
  accessDays?: DayOfWeek[];
  planType?: PlanType;
  displayOrder?: number;
}

export interface EnhancedEquipment {
  id: string;
  name: string;
  category: string;
  brand?: string;
  quantity: number;
  status: "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER";
  description?: string;
  imageUrl?: string;
  serialNumber?: string;
  purchasePrice?: string;
  purchaseDate?: string;
  warrantyExpiry?: string;
  location?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateEnhancedEquipmentData {
  name: string;
  category: string;
  brand?: string;
  quantity?: number;
  status?: "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER";
  description?: string;
  imageUrl?: string;
  serialNumber?: string;
  purchasePrice?: number;
  purchaseDate?: string;
  warrantyExpiry?: string;
  location?: string;
  notes?: string;
}

// ─── Gym Owner API ────────────────────────────────────────────────────────────

export const gymOwnerApi = {
  // Stripe Connect
  getStripeStatus: (gymId: string, token: string) =>
    api<StripeConnectStatus>(`/gym-owner/gyms/${gymId}/stripe/status`, { token }),
  startStripeOnboarding: (gymId: string, returnUrl: string, refreshUrl: string, token: string) =>
    api<OnboardingLink>(`/gym-owner/gyms/${gymId}/stripe/onboard`, {
      method: "POST",
      body: { returnUrl, refreshUrl },
      token,
    }),
  getStripeDashboard: (gymId: string, token: string) =>
    api<{ url: string }>(`/gym-owner/gyms/${gymId}/stripe/dashboard`, { token }),
  getEarnings: (gymId: string, token: string, startDate?: string, endDate?: string) => {
    const params = new URLSearchParams();
    if (startDate) params.append("startDate", startDate);
    if (endDate) params.append("endDate", endDate);
    const queryString = params.toString();
    return api<GymEarnings>(`/gym-owner/gyms/${gymId}/earnings${queryString ? `?${queryString}` : ""}`, { token });
  },

  // Subscription Plans
  getPlans: (gymId: string, token: string) =>
    api<EnhancedSubscriptionPlan[]>(`/gym-owner/gyms/${gymId}/plans`, { token }),
  createPlan: (gymId: string, data: CreateEnhancedPlanData, token: string) =>
    api<EnhancedSubscriptionPlan>(`/gym-owner/gyms/${gymId}/plans`, {
      method: "POST",
      body: data,
      token,
    }),
  updatePlan: (planId: string, data: Partial<CreateEnhancedPlanData> & { isActive?: boolean }, token: string) =>
    api<EnhancedSubscriptionPlan>(`/gym-owner/plans/${planId}`, {
      method: "PATCH",
      body: data,
      token,
    }),
  deletePlan: (planId: string, token: string) =>
    api(`/gym-owner/plans/${planId}`, { method: "DELETE", token }),
  createPlanTemplates: (gymId: string, templates: string[], basePriceMonthly: number, token: string) =>
    api<EnhancedSubscriptionPlan[]>(`/gym-owner/gyms/${gymId}/plans/templates`, {
      method: "POST",
      body: { templates, basePriceMonthly },
      token,
    }),

  // Equipment
  getEquipment: (gymId: string, token: string, category?: string, status?: string) => {
    const params = new URLSearchParams();
    if (category) params.append("category", category);
    if (status) params.append("status", status);
    const queryString = params.toString();
    return api<EnhancedEquipment[]>(`/gym-owner/gyms/${gymId}/equipment${queryString ? `?${queryString}` : ""}`, { token });
  },
  createEquipment: (gymId: string, data: CreateEnhancedEquipmentData, token: string) =>
    api<EnhancedEquipment>(`/gym-owner/gyms/${gymId}/equipment`, {
      method: "POST",
      body: data,
      token,
    }),
  updateEquipment: (equipmentId: string, data: Partial<CreateEnhancedEquipmentData>, token: string) =>
    api<EnhancedEquipment>(`/gym-owner/equipment/${equipmentId}`, {
      method: "PATCH",
      body: data,
      token,
    }),
  deleteEquipment: (equipmentId: string, token: string) =>
    api(`/gym-owner/equipment/${equipmentId}`, { method: "DELETE", token }),
  getEquipmentCategories: (gymId: string, token: string) =>
    api<Array<{ category: string; _count: { id: number }; _sum: { quantity: number } }>>(`/gym-owner/gyms/${gymId}/equipment/categories`, { token }),
}

// ─── Equipment Catalog Types (Super Admin) ───────────────────────────────────

export type EquipmentCategory = "CARDIO" | "STRENGTH" | "FREE_WEIGHTS" | "MACHINES" | "FUNCTIONAL" | "STRETCHING" | "OTHER";

export interface CatalogItem {
  id: string;
  name: string;
  category: EquipmentCategory;
  brand?: string;
  model?: string;
  description?: string;
  imageUrl?: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  _count?: { gymEquipment: number };
}

export interface CreateCatalogItemData {
  name: string;
  category?: EquipmentCategory;
  brand?: string;
  model?: string;
  description?: string;
  imageUrl?: string;
}

export interface CatalogStats {
  totalItems: number;
  activeItems: number;
  totalGymsUsing: number;
  byCategory: Array<{ category: EquipmentCategory; _count: { id: number } }>;
}

// ─── Equipment Catalog API (Super Admin only) ────────────────────────────────

export const equipmentCatalogApi = {
  getAll: (token: string, options?: { category?: string; brand?: string; search?: string; activeOnly?: boolean }) => {
    const params = new URLSearchParams();
    if (options?.category) params.append("category", options.category);
    if (options?.brand) params.append("brand", options.brand);
    if (options?.search) params.append("search", options.search);
    if (options?.activeOnly !== undefined) params.append("activeOnly", String(options.activeOnly));
    const queryString = params.toString();
    return api<CatalogItem[]>(`/equipment-catalog${queryString ? `?${queryString}` : ""}`, { token });
  },
  getById: (id: string, token: string) =>
    api<CatalogItem>(`/equipment-catalog/${id}`, { token }),
  create: (data: CreateCatalogItemData, token: string) =>
    api<CatalogItem>("/equipment-catalog", { method: "POST", body: data, token }),
  update: (id: string, data: Partial<CreateCatalogItemData> & { isActive?: boolean }, token: string) =>
    api<CatalogItem>(`/equipment-catalog/${id}`, { method: "PATCH", body: data, token }),
  delete: (id: string, token: string) =>
    api(`/equipment-catalog/${id}`, { method: "DELETE", token }),
  getStats: (token: string) =>
    api<CatalogStats>("/equipment-catalog/stats", { token }),
  getCategories: (token: string) =>
    api<Array<{ category: EquipmentCategory; _count: { id: number } }>>("/equipment-catalog/categories", { token }),
  getBrands: (token: string) =>
    api<string[]>("/equipment-catalog/brands", { token }),
  import: (records: Record<string, unknown>[], token: string) =>
    api<{ imported: number }>("/equipment-catalog/import", { method: "POST", body: { records }, token }),
}

// ─── Branch Dashboard Types ───────────────────────────────────────────────────

export interface TrendData {
  count: number;
  previousCount: number;
  growthRate: number;
}

export interface TrendPeriod {
  attendance: TrendData;
  checkIns: number;
  retentionRate: number;
  growthRate: number;
}

export interface BranchStatsResponse {
  activeSubscriptions: number;
  registeredCustomers: number;
  currentHallOccupancy: number;
  trainersCount: number;
  trends: {
    daily: TrendPeriod;
    weekly: TrendPeriod;
    monthly: TrendPeriod;
    custom?: TrendPeriod;
  };
}

export interface ManualRegistrationRequest {
  fullName: string;
  email: string;
  phoneNumber?: string;
  subscriptionPlanId: string;
  startDate?: string;
  sendNotification?: boolean;
  dateOfBirth?: string;
  personalNumber?: string;
  address?: string;
  healthInfo?: string;
  selfiePhoto?: string;
  idPhoto?: string;
}

export interface ManualRegistrationResponse {
  user: {
    id: string;
    email: string;
    fullName: string;
    phoneNumber: string | null;
  };
  membership: {
    id: string;
    status: MembershipStatus;
    startDate: string;
    endDate: string;
    plan: {
      id: string;
      name: string;
    };
  };
}

export interface ManualActivationRequest {
  memberId: string;
  planId: string;
  durationDays?: number;
  startDate?: string;
}

export interface ManualActivationResponse {
  membership: {
    id: string;
    status: MembershipStatus;
    startDate: string;
    endDate: string;
    previousEndDate?: string;
    plan: {
      id: string;
      name: string;
    };
  };
  user: {
    id: string;
    fullName: string;
    email: string;
  };
}

export interface MemberSearchResult {
  id: string;
  email: string;
  fullName: string;
  phoneNumber: string | null;
  memberships: Array<{
    id: string;
    status: MembershipStatus;
    endDate: string;
    plan: {
      id: string;
      name: string;
    };
  }>;
}

export interface ExportLogsRequest {
  startDate?: string;
  endDate?: string;
  logType?: string;
  format?: "json" | "csv";
}

export interface ExportLogEntry {
  timestamp: string;
  userName: string;
  userEmail: string;
  doorName: string;
  doorLocation: string;
  method: string;
  granted: boolean;
  deviceInfo: string;
}

export interface ExportLogsResponse {
  gymId: string;
  exportDate: string;
  filters: {
    startDate?: string;
    endDate?: string;
    logType?: string;
  };
  totalRecords: number;
  logs: ExportLogEntry[];
}

// ─── Branch Manager API ───────────────────────────────────────────────────────

export const branchApi = {
  /**
   * Get branch statistics with trends
   */
  getStats: (branchId: string, token: string) =>
    api<BranchStatsResponse>(`/gyms/${branchId}/stats`, { token }),

  /**
   * Get real-time hall occupancy
   */
  getOccupancy: (branchId: string, token: string) =>
    api<{ occupancy: number }>(`/gyms/${branchId}/occupancy`, { token }),

  /**
   * Manual member registration
   */
  manualCreate: (branchId: string, data: ManualRegistrationRequest, token: string) =>
    api<ManualRegistrationResponse>(`/branch/${branchId}/manual-create`, {
      method: "POST",
      body: data,
      token,
    }),

  /**
   * Manual membership activation/renewal
   */
  manualActivate: (branchId: string, data: ManualActivationRequest, token: string) =>
    api<ManualActivationResponse>(`/branch/${branchId}/manual-activate`, {
      method: "POST",
      body: data,
      token,
    }),

  /**
   * Search members for activation dropdown
   */
  searchMembers: (branchId: string, query: string, token: string, limit?: number) => {
    const params = new URLSearchParams();
    params.append("q", query);
    if (limit) params.append("limit", String(limit));
    return api<MemberSearchResult[]>(`/branch/${branchId}/search-members?${params.toString()}`, { token });
  },

  /**
   * Export access logs (GYM_OWNER only)
   */
  exportLogs: (branchId: string, options: ExportLogsRequest, token: string) => {
    const params = new URLSearchParams();
    if (options.startDate) params.append("startDate", options.startDate);
    if (options.endDate) params.append("endDate", options.endDate);
    if (options.logType) params.append("logType", options.logType);
    if (options.format) params.append("format", options.format);
    const queryString = params.toString();
    return api<ExportLogsResponse>(`/branch/${branchId}/export-logs${queryString ? `?${queryString}` : ""}`, { token });
  },

  /**
   * Download logs as CSV file (GYM_OWNER only)
   */
  downloadLogsCSV: async (branchId: string, options: ExportLogsRequest, token: string): Promise<Blob> => {
    const params = new URLSearchParams();
    if (options.startDate) params.append("startDate", options.startDate);
    if (options.endDate) params.append("endDate", options.endDate);
    if (options.logType) params.append("logType", options.logType);
    params.append("format", "csv");
    const queryString = params.toString();

    const response = await fetch(`${API_BASE_URL}/branch/${branchId}/export-logs?${queryString}`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      throw new Error("Failed to download logs");
    }

    return response.blob();
  },

  /**
   * Get subscription plans for the branch
   */
  getPlans: (branchId: string, token: string) =>
    api<EnhancedSubscriptionPlan[]>(`/gym-owner/gyms/${branchId}/plans`, { token }),
}

// ─── Marketing Campaign API ───────────────────────────────────────────────────

export type CampaignAudience =
  | "ALL"
  | "ACTIVE"
  | "EXPIRED"
  | "PENDING"
  | "INACTIVE_30D"
  | "INACTIVE_60D";

export type CampaignStatus = "DRAFT" | "SENDING" | "SENT" | "FAILED";

export interface MarketingCampaign {
  id: string;
  gymId: string;
  createdById: string;
  name: string;
  subject: string | null;
  body: string;
  imageUrl: string | null;
  channels: string[];
  targetAudience: CampaignAudience;
  targetPlanId: string | null;
  status: CampaignStatus;
  scheduledAt: string | null;
  sentAt: string | null;
  totalTargeted: number;
  totalDelivered: number;
  createdAt: string;
  createdBy: { id: string; fullName: string };
}

export interface CreateCampaignData {
  name: string;
  subject?: string;
  body: string;
  imageUrl?: string;
  channels: string[];
  targetAudience: CampaignAudience;
  targetPlanId?: string;
}

export const marketingApi = {
  list: (gymId: string, token: string) =>
    api<MarketingCampaign[]>(`/marketing/gyms/${gymId}/campaigns`, { token }),

  create: (gymId: string, data: CreateCampaignData, token: string) =>
    api<MarketingCampaign>(`/marketing/gyms/${gymId}/campaigns`, {
      method: "POST",
      body: data,
      token,
    }),

  previewAudience: (gymId: string, audience: CampaignAudience, token: string, targetPlanId?: string) => {
    const qs = new URLSearchParams({ audience });
    if (targetPlanId) qs.set("targetPlanId", targetPlanId);
    return api<{ count: number; audience: string }>(
      `/marketing/gyms/${gymId}/campaigns/preview-audience?${qs}`,
      { token }
    );
  },

  send: (gymId: string, campaignId: string, token: string) =>
    api<{ sent: number; total: number }>(
      `/marketing/gyms/${gymId}/campaigns/${campaignId}/send`,
      { method: "POST", token }
    ),

  delete: (gymId: string, campaignId: string, token: string) =>
    api<void>(`/marketing/gyms/${gymId}/campaigns/${campaignId}`, {
      method: "DELETE",
      token,
    }),
}

// ─── Analytics / Churn API ────────────────────────────────────────────────────

export type RiskLevel = "SAFE" | "AT_RISK" | "HIGH_RISK" | "CHURNING";

export interface MemberChurnScore {
  userId: string;
  membershipId: string;
  fullName: string;
  email: string;
  avatarUrl: string | null;
  planName: string;
  membershipEndDate: string;
  status: string;
  score: number;
  riskLevel: RiskLevel;
  daysSinceLastCheckIn: number | null;
  checkInsLast30Days: number;
  checkInsPrev30Days: number;
  daysUntilExpiry: number;
}

export interface ChurnSummary {
  total: number;
  safe: number;
  atRisk: number;
  highRisk: number;
  churning: number;
  avgScore: number;
}

export const analyticsApi = {
  getChurnAll: (gymId: string, token: string) =>
    api<MemberChurnScore[]>(`/analytics/gyms/${gymId}/churn`, { token }),

  getAtRisk: (gymId: string, token: string) =>
    api<MemberChurnScore[]>(`/analytics/gyms/${gymId}/churn/at-risk`, { token }),

  getChurnSummary: (gymId: string, token: string) =>
    api<ChurnSummary>(`/analytics/gyms/${gymId}/churn/summary`, { token }),

  getPlatformKpis: (token: string) =>
    api<{ ownerCount: number; gymCount: number; totalRevenueThisMonth: number; avgRevenuePerOwner: number }>(
      '/analytics/platform-kpis', { token }
    ),

  getTopOwners: (token: string, limit = 10) =>
    api<Array<{ id: string; fullName: string; email: string; gymCount: number; activeMembers: number; revenueThisMonth: number }>>(
      `/analytics/top-owners?limit=${limit}`, { token }
    ),

  getGymOwnerDashboard: (token: string, days = 30) =>
    api<Array<{ id: string; name: string; city: string; country: string; activeMembers: number; trainerCount: number; todayCheckins: number; monthRevenue: number }>>(
      `/analytics/gym-owner/dashboard?days=${days}`, { token }
    ),

  getMemberGrowth: (token: string, days = 30) =>
    api<{ totalNewThisPeriod: number; retentionRate: number; byDay: Array<{ date: string; count: number }>; byMonth: Array<{ month: string; count: number }> }>(
      `/analytics/member-growth?days=${days}`, { token }
    ),

  getEngagement: (token: string) =>
    api<{ dau: number; mau: number; dauMauRatio: number; avgWorkoutsPerWeek: number; featureUsage: { workoutsToday: number; foodLogsToday: number; checkinsToday: number; workoutUsersThisMonth: number; foodLogUsersThisMonth: number; checkinUsersThisMonth: number } }>(
      '/analytics/engagement', { token }
    ),

  getWorkoutCompletion: (token: string, days = 30) =>
    api<{ totalPlannedRoutines: number; completionsInPeriod: number; avgSessionDurationMinutes: number; byDayOfWeek: Array<{ day: string; count: number }> }>(
      `/analytics/workout-completion?days=${days}`, { token }
    ),

  getDietAdherence: (token: string, days = 30) =>
    api<{ activeDietPlanUsers: number; usersLoggedMeals: number; mealLogRate: number; totalMealLogsInPeriod: number; avgDailyCaloriesLogged: number }>(
      `/analytics/diet-adherence?days=${days}`, { token }
    ),

  getLeaderboardHealth: (token: string) =>
    api<{ pointsBuckets: { beginner: number; active: number; champion: number }; totalUsersWithPoints: number; inactiveLast7d: number; inactiveLast30d: number; neverActive: number }>(
      '/analytics/leaderboard-health', { token }
    ),

  getPlatformRevenueTrend: (token: string, days = 30) =>
    api<Array<{ date: string; revenue: number }>>(
      `/analytics/platform-revenue-trend?days=${days}`, { token }
    ),

  getPlatformStats: (token: string) =>
    api<{ revenueGrowth: number; newPartners: number; totalActiveMembers: number; topGymName: string }>(
      '/analytics/platform-stats', { token }
    ),

  // Gym owner deep-dive (P3-5)
  getGymPulse: (gymId: string, token: string) =>
    api<{ activeNow: number; todayTotal: number; yesterdayTotal: number; vsYesterday: number; hourlyCheckins: Array<{ hour: number; count: number }> }>(
      `/analytics/gyms/${gymId}/pulse`, { token }
    ),

  getRetentionHeatmap: (gymId: string, token: string) =>
    api<{ byDayOfWeek: Array<{ day: string; count: number; avgPerWeek: number }>; periodWeeks: number; totalCheckins: number }>(
      `/analytics/gyms/${gymId}/retention-heatmap`, { token }
    ),

  getTopTrainers: (gymId: string, token: string) =>
    api<Array<{ trainerId: string; fullName: string; assignedMembers: number; sessionsThisMonth: number; completionRate: number }>>(
      `/analytics/gyms/${gymId}/top-trainers`, { token }
    ),

  getPlanMix: (gymId: string, token: string) =>
    api<{ plans: Array<{ planId: string; name: string; price: number; activeCount: number; pendingCount: number; cancelledCount: number; frozenCount: number; percentage: number }>; totalActiveMembers: number }>(
      `/analytics/gyms/${gymId}/plan-mix`, { token }
    ),

  getGymRevenue: (gymId: string, token: string) =>
    api<{ kpis: { mrr: number; arr: number; revenueAtRisk: number; revenueAtRiskPct: number; avgRevenuePerMember: number; activeMembers: number; newMembersThisMonth: number; realizedThisMonth: number; realizedLastMonth: number; momGrowthPct: number }; monthlyTrend: Array<{ month: string; realized: number; projected: number }>; planBreakdown: Array<{ planName: string; activeMembers: number; monthlyValue: number; percentage: number }> }>(
      `/analytics/gyms/${gymId}/revenue`, { token }
    ),
}

// ─── Branch Management ────────────────────────────────────────────────────────

export interface BranchStats {
  activeMembers: number;
  trainerCount: number;
  todayCheckins: number;
  monthCheckins: number;
  expiringSoon: number;
}

export const branchesApi = {
  list: (gymId: string, token: string) =>
    api<Branch[]>(`/gym-owner/gyms/${gymId}/branches`, { token }),

  create: (gymId: string, token: string, data: { name: string; address?: string; city?: string; phone?: string; maxCapacity?: number; openTime?: string; closeTime?: string }) =>
    api<Branch>(`/gym-owner/gyms/${gymId}/branches`, { method: 'POST', body: data, token }),

  update: (gymId: string, branchId: string, token: string, data: Partial<{ name: string; address: string; city: string; phone: string; maxCapacity: number; openTime: string; closeTime: string; isActive: boolean }>) =>
    api<Branch>(`/gym-owner/gyms/${gymId}/branches/${branchId}`, { method: 'PATCH', body: data, token }),

  deactivate: (gymId: string, branchId: string, token: string) =>
    api<{ message: string }>(`/gym-owner/gyms/${gymId}/branches/${branchId}`, { method: 'DELETE', token }),

  getStats: (gymId: string, branchId: string, token: string) =>
    api<{ branch: Branch; stats: BranchStats }>(`/gym-owner/gyms/${gymId}/branches/${branchId}/stats`, { token }),

  assignAdmin: (gymId: string, branchId: string, adminId: string, token: string) =>
    api<{ message: string }>(`/gym-owner/gyms/${gymId}/branches/${branchId}/assign-admin`, { method: 'POST', body: { adminId }, token }),
}

// ─── Automation Rules ──────────────────────────────────────────────────────────

export type AutomationTrigger =
  | 'INACTIVE_14D'
  | 'INACTIVE_30D'
  | 'EXPIRY_5D'
  | 'EXPIRY_1D'
  | 'JUST_EXPIRED'
  | 'NEW_MEMBER_DAY1'
  | 'NEW_MEMBER_DAY3'
  | 'NEW_MEMBER_DAY7';

export const TRIGGER_LABELS: Record<AutomationTrigger, string> = {
  INACTIVE_14D: '14-Day Inactivity Win-Back',
  INACTIVE_30D: '30-Day Inactivity Win-Back',
  EXPIRY_5D: 'Membership Expiring in 5 Days',
  EXPIRY_1D: 'Membership Expiring Tomorrow',
  JUST_EXPIRED: 'Membership Just Expired',
  NEW_MEMBER_DAY1: 'Welcome – Day 1',
  NEW_MEMBER_DAY3: 'Onboarding – Day 3',
  NEW_MEMBER_DAY7: 'Onboarding – Day 7',
};

export const TRIGGER_DESCRIPTIONS: Record<AutomationTrigger, string> = {
  INACTIVE_14D: 'Sent when a member has not checked in for 14 days',
  INACTIVE_30D: 'Sent when a member has not checked in for 30 days',
  EXPIRY_5D: 'Sent 5 days before a membership expires',
  EXPIRY_1D: 'Sent 1 day before a membership expires',
  JUST_EXPIRED: 'Sent when a membership expires',
  NEW_MEMBER_DAY1: 'Sent on day 1 after a new member joins',
  NEW_MEMBER_DAY3: 'Sent on day 3 after a new member joins',
  NEW_MEMBER_DAY7: 'Sent on day 7 after a new member joins',
};

export interface AutomationRule {
  id: string;
  gymId: string;
  name: string;
  trigger: AutomationTrigger;
  subject: string | null;
  body: string;
  channels: string[];
  isActive: boolean;
  lastRunAt: string | null;
  totalFired: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateAutomationRuleData {
  name: string;
  trigger: AutomationTrigger;
  subject?: string;
  body: string;
  channels: string[];
}

export const automationsApi = {
  list: (gymId: string, token: string) =>
    api<{ data: AutomationRule[] }>(`/automations/gyms/${gymId}/rules`, { token }),

  create: (gymId: string, data: CreateAutomationRuleData, token: string) =>
    api<{ data: AutomationRule }>(`/automations/gyms/${gymId}/rules`, {
      method: "POST",
      body: data,
      token,
    }),

  update: (gymId: string, id: string, data: Partial<CreateAutomationRuleData> & { isActive?: boolean }, token: string) =>
    api<{ data: AutomationRule }>(`/automations/gyms/${gymId}/rules/${id}`, {
      method: "PATCH",
      body: data,
      token,
    }),

  delete: (gymId: string, id: string, token: string) =>
    api(`/automations/gyms/${gymId}/rules/${id}`, { method: "DELETE", token }),

  runNow: (gymId: string, id: string, token: string) =>
    api<{ data: { fired: number } }>(`/automations/gyms/${gymId}/rules/${id}/run`, {
      method: "POST",
      token,
    }),
}

// ─── Gym Announcements ─────────────────────────────────────────────────────────

export interface GymAnnouncement {
  id: string;
  gymId: string;
  authorId: string;
  title: string;
  body: string;
  imageUrl: string | null;
  isPinned: boolean;
  targetAudience: string;
  channels: string[];
  totalDelivered: number;
  publishedAt: string;
  createdAt: string;
  author: { id: string; fullName: string };
}

export interface PublishAnnouncementData {
  title: string;
  body: string;
  imageUrl?: string;
  isPinned?: boolean;
  targetAudience: string;
  channels: string[];
}

export const announcementsApi = {
  list: (gymId: string, token: string) =>
    api<{ data: GymAnnouncement[] }>(`/announcements/gyms/${gymId}`, { token }),

  publish: (gymId: string, data: PublishAnnouncementData, token: string) =>
    api<{ data: GymAnnouncement }>(`/announcements/gyms/${gymId}`, {
      method: "POST",
      body: data,
      token,
    }),

  togglePin: (gymId: string, id: string, token: string) =>
    api<{ data: GymAnnouncement }>(`/announcements/gyms/${gymId}/${id}/pin`, {
      method: "PATCH",
      token,
    }),

  delete: (gymId: string, id: string, token: string) =>
    api(`/announcements/gyms/${gymId}/${id}`, { method: "DELETE", token }),
}

// ─── Revenue Intelligence ──────────────────────────────────────────────────────

export interface RevenueKPIs {
  mrr: number;
  arr: number;
  revenueAtRisk: number;
  revenueAtRiskPct: number;
  avgRevenuePerMember: number;
  activeMembers: number;
  newMembersThisMonth: number;
  realizedThisMonth: number;
  realizedLastMonth: number;
  momGrowthPct: number;
}

export interface MonthlyRevenue {
  month: string;
  year: number;
  monthNum: number;
  realized: number;
  projected: number;
}

export interface PlanRevenue {
  planId: string;
  planName: string;
  price: number;
  activeMembers: number;
  monthlyValue: number;
  percentage: number;
}

export interface PeakHourBucket {
  hour: number;
  count: number;
}

export interface RecentPayment {
  id: string;
  amount: number;
  description: string | null;
  createdAt: string;
  userFullName: string;
  userEmail: string;
}

export interface RevenueIntelligence {
  kpis: RevenueKPIs;
  monthlyTrend: MonthlyRevenue[];
  planBreakdown: PlanRevenue[];
  peakHours: PeakHourBucket[];
  recentPayments: RecentPayment[];
}

export const revenueApi = {
  getIntelligence: (gymId: string, token: string) =>
    api<RevenueIntelligence>(`/analytics/gyms/${gymId}/revenue`, { token }),

  getKPIs: (gymId: string, token: string) =>
    api<RevenueKPIs>(`/analytics/gyms/${gymId}/revenue/kpis`, { token }),
}

// ─── Training Sessions ─────────────────────────────────────────────────────────

export type SessionType = "GROUP_CLASS" | "ONE_ON_ONE" | "WORKSHOP";
export type SessionStatus = "SCHEDULED" | "CANCELLED" | "COMPLETED";
export type BookingStatus = "CONFIRMED" | "CANCELLED" | "ATTENDED" | "NO_SHOW";

export interface TrainerSummary {
  id: string;
  fullName: string;
  avatarUrl: string | null;
  specialization: string | null;
}

export interface TrainingSession {
  id: string;
  gymId: string;
  trainerId: string;
  title: string;
  description: string | null;
  type: SessionType;
  startTime: string;
  endTime: string;
  maxCapacity: number;
  location: string | null;
  status: SessionStatus;
  color: string | null;
  createdAt: string;
  trainer: TrainerSummary;
  bookingCount: number;
  attendedCount: number;
  availableSpots: number;
}

export interface SessionBooking {
  id: string;
  sessionId: string;
  userId: string;
  status: BookingStatus;
  bookedAt: string;
  user: { id: string; fullName: string; email: string; avatarUrl: string | null };
}

export interface TrainerStats {
  id: string;
  fullName: string;
  avatarUrl: string | null;
  specialization: string | null;
  totalSessions: number;
  completedSessions: number;
  totalBookings: number;
}

export interface CreateSessionData {
  trainerId: string;
  title: string;
  description?: string;
  type: SessionType;
  startTime: string;
  endTime: string;
  maxCapacity: number;
  location?: string;
  color?: string;
}

export const sessionsApi = {
  list: (gymId: string, params: { from?: string; to?: string; trainerId?: string; status?: string }, token: string) => {
    const q = new URLSearchParams();
    if (params.from)      q.set("from", params.from);
    if (params.to)        q.set("to", params.to);
    if (params.trainerId) q.set("trainerId", params.trainerId);
    if (params.status)    q.set("status", params.status);
    const qs = q.toString();
    return api<{ data: TrainingSession[] }>(`/sessions/gyms/${gymId}${qs ? `?${qs}` : ""}`, { token });
  },

  create: (gymId: string, data: CreateSessionData, token: string) =>
    api<{ data: TrainingSession }>(`/sessions/gyms/${gymId}`, { method: "POST", body: data, token }),

  update: (gymId: string, id: string, data: Partial<CreateSessionData> & { status?: SessionStatus }, token: string) =>
    api<{ data: TrainingSession }>(`/sessions/gyms/${gymId}/${id}`, { method: "PATCH", body: data, token }),

  delete: (gymId: string, id: string, token: string) =>
    api(`/sessions/gyms/${gymId}/${id}`, { method: "DELETE", token }),

  getBookings: (gymId: string, id: string, token: string) =>
    api<{ data: SessionBooking[] }>(`/sessions/gyms/${gymId}/${id}/bookings`, { token }),

  markAttendance: (gymId: string, sessionId: string, memberId: string, status: BookingStatus, token: string) =>
    api<{ data: SessionBooking }>(`/sessions/gyms/${gymId}/${sessionId}/bookings/${memberId}`, {
      method: "PATCH",
      body: { status },
      token,
    }),

  getTrainerStats: (gymId: string, token: string) =>
    api<{ data: TrainerStats[] }>(`/sessions/gyms/${gymId}/trainers/stats`, { token }),
}

// ─── Membership Freeze ─────────────────────────────────────────────────────────

export const freezeApi = {
  freeze: (gymId: string, membershipId: string, days: number, reason: string | undefined, token: string) =>
    api(`/memberships/gyms/${gymId}/${membershipId}/freeze`, { method: "POST", body: { days, reason }, token }),

  unfreeze: (gymId: string, membershipId: string, token: string) =>
    api(`/memberships/gyms/${gymId}/${membershipId}/unfreeze`, { method: "POST", token }),
}

// ─── Support Tickets ───────────────────────────────────────────────────────────

export type TicketStatus   = "OPEN" | "IN_PROGRESS" | "RESOLVED" | "CLOSED";
export type TicketPriority = "LOW" | "MEDIUM" | "HIGH" | "URGENT";

export interface TicketMessage {
  id: string;
  ticketId: string;
  senderId: string;
  body: string;
  isStaff: boolean;
  readAt: string | null;
  createdAt: string;
  sender: { id: string; fullName: string; avatarUrl: string | null };
}

export interface SupportTicket {
  id: string;
  gymId: string;
  userId: string;
  subject: string;
  status: TicketStatus;
  priority: TicketPriority;
  createdAt: string;
  updatedAt: string;
  user: { id: string; fullName: string; email: string; avatarUrl: string | null };
  messages?: TicketMessage[];
  _count?: { messages: number };
}

export interface TicketStats {
  open: number;
  inProgress: number;
  resolved: number;
  closed: number;
  urgent: number;
  total: number;
}

export const trainerConversationApi = {
  /** Trainer: list all member conversations */
  listConversations: (token: string) =>
    api<SupportTicket[]>(`/support/trainer-conversations`, { token }),

  /** Get full thread for a conversation */
  getThread: (gymId: string, ticketId: string, token: string) =>
    api<SupportTicket>(`/support/gyms/${gymId}/tickets/${ticketId}`, { token }),

  /** Reply to a conversation */
  reply: (gymId: string, ticketId: string, body: string, token: string) =>
    api<TicketMessage>(`/support/gyms/${gymId}/tickets/${ticketId}/reply`, {
      method: "POST", body: { body }, token,
    }),
};

export const supportApi = {
  list: (gymId: string, params: { status?: string; priority?: string }, token: string) => {
    const q = new URLSearchParams();
    if (params.status)   q.set("status", params.status);
    if (params.priority) q.set("priority", params.priority);
    const qs = q.toString();
    return api<SupportTicket[]>(`/support/gyms/${gymId}/tickets${qs ? `?${qs}` : ""}`, { token });
  },

  getStats: (gymId: string, token: string) =>
    api<TicketStats>(`/support/gyms/${gymId}/stats`, { token }),

  getTicket: (gymId: string, id: string, token: string) =>
    api<SupportTicket>(`/support/gyms/${gymId}/tickets/${id}`, { token }),

  reply: (gymId: string, id: string, body: string, token: string) =>
    api<TicketMessage>(`/support/gyms/${gymId}/tickets/${id}/reply`, {
      method: "POST", body: { body }, token,
    }),

  updateStatus: (gymId: string, id: string, status: TicketStatus, token: string) =>
    api<SupportTicket>(`/support/gyms/${gymId}/tickets/${id}/status`, {
      method: "PATCH", body: { status }, token,
    }),
}

// ─── Audit Log ────────────────────────────────────────────────────────────────

export interface AuditLog {
  id: string;
  gymId: string;
  actorId: string;
  action: string;
  entity: string;
  entityId: string | null;
  label: string;
  metadata: Record<string, unknown> | null;
  createdAt: string;
  actor: {
    id: string;
    fullName: string;
    email: string;
    avatarUrl: string | null;
    role: string;
  };
}

export interface AuditLogPage {
  logs: AuditLog[];
  total: number;
  page: number;
  pages: number;
}

export const auditApi = {
  list: (gymId: string, params: { action?: string; from?: string; to?: string; page?: number }, token: string) => {
    const q = new URLSearchParams();
    if (params.action) q.set("action", params.action);
    if (params.from)   q.set("from", params.from);
    if (params.to)     q.set("to", params.to);
    if (params.page)   q.set("page", String(params.page));
    const qs = q.toString();
    return api<{ data: AuditLogPage }>(`/audit/gyms/${gymId}${qs ? `?${qs}` : ""}`, { token });
  },
};

// ─── Webhooks ─────────────────────────────────────────────────────────────────

export const WEBHOOK_EVENTS = [
  'member.created',
  'member.cancelled',
  'membership.frozen',
  'membership.unfrozen',
  'payment.received',
  'session.created',
  'session.cancelled',
  'checkin.recorded',
  'support.ticket_created',
] as const;

export type WebhookEvent = typeof WEBHOOK_EVENTS[number];

export interface WebhookEndpoint {
  id: string;
  gymId: string;
  url: string;
  secret: string;
  events: WebhookEvent[];
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  _count: { deliveries: number };
}

export interface WebhookDelivery {
  id: string;
  endpointId: string;
  event: string;
  payload: Record<string, unknown>;
  statusCode: number | null;
  responseBody: string | null;
  success: boolean;
  duration: number | null;
  attemptedAt: string;
}

export interface WebhookDeliveryPage {
  deliveries: WebhookDelivery[];
  total: number;
  page: number;
  pages: number;
}

export const webhooksApi = {
  list: (gymId: string, token: string) =>
    api<{ data: WebhookEndpoint[] }>(`/webhooks/gyms/${gymId}`, { token }),

  create: (gymId: string, data: { url: string; events: string[] }, token: string) =>
    api<{ data: WebhookEndpoint }>(`/webhooks/gyms/${gymId}`, {
      method: "POST", body: data, token,
    }),

  update: (gymId: string, id: string, data: { url?: string; events?: string[]; isActive?: boolean }, token: string) =>
    api<{ data: WebhookEndpoint }>(`/webhooks/gyms/${gymId}/${id}`, {
      method: "PATCH", body: data, token,
    }),

  delete: (gymId: string, id: string, token: string) =>
    api<{ data: { deleted: boolean } }>(`/webhooks/gyms/${gymId}/${id}`, {
      method: "DELETE", token,
    }),

  rotateSecret: (gymId: string, id: string, token: string) =>
    api<{ data: WebhookEndpoint }>(`/webhooks/gyms/${gymId}/${id}/rotate-secret`, {
      method: "POST", token,
    }),

  getDeliveries: (gymId: string, id: string, page: number, token: string) =>
    api<{ data: WebhookDeliveryPage }>(`/webhooks/gyms/${gymId}/${id}/deliveries?page=${page}`, { token }),
};

// ─── Progress Rooms ───────────────────────────────────────────────────────────

export type RoomMetric = 'CHECKINS' | 'SESSIONS' | 'STREAK';
export type RoomPeriod = 'WEEKLY' | 'MONTHLY' | 'ONGOING' | 'CUSTOM';

export interface ProgressRoom {
  id: string;
  gymId: string;
  creatorId: string;
  name: string;
  description: string | null;
  metric: RoomMetric;
  period: RoomPeriod;
  startDate: string;
  endDate: string | null;
  isPublic: boolean;
  inviteCode: string;
  maxMembers: number;
  isActive: boolean;
  createdAt: string;
  creator: { id: string; fullName: string; avatarUrl: string | null };
  _count: { members: number };
}

export const roomsAdminApi = {
  list: (gymId: string, token: string) =>
    api<{ data: ProgressRoom[] }>(`/rooms/gyms/${gymId}`, { token }),

  create: (gymId: string, data: {
    name: string; description?: string; metric: RoomMetric;
    period: RoomPeriod; startDate?: string; endDate?: string;
    isPublic?: boolean; maxMembers?: number;
  }, token: string) =>
    api<{ data: ProgressRoom }>(`/rooms/gyms/${gymId}`, { method: "POST", body: data, token }),

  delete: (gymId: string, id: string, token: string) =>
    api<{ data: { deleted: boolean } }>(`/rooms/gyms/${gymId}/${id}`, { method: "DELETE", token }),
};

// ─── Trainer Self-Service API ─────────────────────────────────────────────────

export interface TrainerAssignedMember {
  id: string;
  userId: string;
  user: {
    id: string;
    email: string;
    fullName: string;
    phoneNumber: string | null;
    avatarUrl: string | null;
    weight: string | null;
    height: string | null;       // legacy string field e.g. "183cm"
    heightCm: number | null;     // numeric cm — preferred
    dob: string | null;
    gender: string | null;
    medicalConditions: string | null;
    noMedicalConditions: boolean | null;
    targetWeightKg: string | null;
    unitPreference: 'METRIC' | 'IMPERIAL';
    languagePreference: 'EN' | 'KA' | 'RU';
  };
  plan: { id: string; name: string } | null;
}

/** Matches ExerciseSet DB model */
export interface TrainerWorkoutExercise {
  id: string;
  exerciseName: string;
  exerciseLibraryId: string | null;
  targetSets: number;
  targetReps: string; // Changed to string for "8-12" support
  targetWeight: number | null;
  restSeconds: number | null;
  orderIndex: number;
  rpe: number | null;
  progressionNote: string | null;
  tempoEccentric?: string;
  tempoPause?: string;
  tempoConcentric?: string;
}

/** Matches WorkoutRoutine DB model */
export interface TrainerWorkoutRoutine {
  id: string;
  name: string;
  scheduledDate: string | null;
  estimatedMinutes: number | null;
  orderIndex: number;
  isDraft: boolean;
  exercises: TrainerWorkoutExercise[];
}

/** Matches WorkoutPlan DB model */
export interface TrainerWorkoutPlan {
  id: string;
  name: string;
  description: string | null;
  difficulty: string;
  isActive: boolean;
  isAIGenerated: boolean;
  createdAt: string;
  startDate: string | null;
  endDate: string | null;
  numWeeks: number;
  routines: TrainerWorkoutRoutine[];
}

/** One food ingredient inside a trainer meal */
export interface TrainerMealIngredient {
  item: string;       // display name (may be translated)
  itemEn?: string;    // English fallback — preserved for cross-language meal display
  foodItemId?: string;
  amount: number;
  unit: "g" | "oz" | "cup" | "tbsp" | "tsp" | "piece" | "cap" | "scoop";
  grams: number;
  calories: number;
  protein: number;
  carbs: number;
  fats: number; // Standardized to plural
}

/** JSON stored in Meal.items for trainer-built plans */
export interface TrainerMealItems {
  notificationTime?: string;
  ingredients: TrainerMealIngredient[];
  isDraft?: boolean;
  instructions?: string; // New field for meal prep
}

/** Matches Meal DB model */
export interface TrainerMeal {
  id: string;
  name: string;
  timeOfDay: string | null;
  scheduledDate: string | null;
  totalCalories: number;
  protein: number;
  carbs: number;
  fats: number;
  isDraft: boolean;
  items: TrainerMealItems | null;
}

/** A reusable template saved in the trainer's personal library (diet or workout) */
export interface TrainerDraftTemplate {
  id: string;
  type: string; // "meal" | "day" | "week" | "workout_exercise" | "workout_day" | "workout_week"
  name: string;
  data: unknown;
  createdAt: string;
  updatedAt: string;
}

export interface TrainerTemplateMeal {
  name: string;
  timeOfDay?: string;
  totalCalories: number;
  protein: number;
  carbs: number;
  fats: number;
  items?: TrainerMealItems;
}

export interface TrainerTemplateMealData { meals: TrainerTemplateMeal[] }
export interface TrainerTemplateDayData  { meals: TrainerTemplateMeal[] }
export interface TrainerTemplateWeekData { days: { dayIdx: number; meals: TrainerTemplateMeal[] }[] }

export interface TrainerTemplateExercise {
  exerciseName: string;
  exerciseType?: string; // STRENGTH | CARDIO | FLEXIBILITY
  targetSets: number;
  targetReps: string; // Range support
  targetWeight?: number;
  restSeconds?: number;
  rpe?: number;
  tempoEccentric?: string;
  tempoPause?: string;
  tempoConcentric?: string;
}
export interface TrainerTemplateWorkoutExerciseData { exercises: TrainerTemplateExercise[] }
export interface TrainerTemplateWorkoutDayData { routineName: string; exercises: TrainerTemplateExercise[] }
export interface TrainerTemplateWorkoutWeekData { days: { dayIdx: number; routineName: string; exercises: TrainerTemplateExercise[] }[] }

/** Matches DietPlan DB model */
export interface TrainerDietPlan {
  id: string;
  name: string;
  targetCalories: number;
  targetProtein: number;
  targetCarbs: number;
  targetFats: number;
  isActive: boolean;
  isPublished: boolean;
  isAIGenerated: boolean;
  startDate: string | null;
  numWeeks: number;
  weekTargets: Array<{ calories: number; protein: number; carbs: number; fats: number }> | null;
  createdAt: string;
  meals: TrainerMeal[];
  hydrationTargetMl?: number; // New field
  keyNutritionInsights?: string; // Long text insight
}

/** Food item from the food database (per-100g macros) */
export interface TrainerFoodItem {
  id?: string;
  name: string;
  brand?: string;
  calories: number;
  protein: number;
  carbs: number;
  fats: number; // Changed to plural
  fiber?: number;
  source: string;
  createdBy?: string;
  createdAt?: string;
}

/** Matches ExerciseLibrary DB model */
export interface ExerciseLibraryItem {
  id: string;
  name: string;
  primaryMuscle: string;
  secondaryMuscles: string[];
  difficulty: string;
}

// ─── Assignment API ───────────────────────────────────────────────────────────

export interface AssignmentRequest {
  id: string;
  gymId: string;
  memberId: string;
  trainerId: string;
  status: string;
  message?: string;
  createdAt: string;
  member: {
    id: string;
    fullName: string;
    email: string;
    avatarUrl?: string;
    weight?: string;
    height?: string;
    dob?: string;
    gender?: string;
  };
  gym: { id: string; name: string };
}

export const assignmentApi = {
  getPendingRequests: (token: string) =>
    api<AssignmentRequest[]>("/assignment/me/pending-requests", { token }),

  approveRequest: (requestId: string, token: string) =>
    api<AssignmentRequest>(`/assignment/requests/${requestId}/approve`, { token, method: "POST" }),

  rejectRequest: (requestId: string, token: string) =>
    api<AssignmentRequest>(`/assignment/requests/${requestId}/reject`, { token, method: "POST" }),

  removeAssignment: (gymId: string, memberId: string, token: string) =>
    api<{ success: boolean }>(`/assignment/gyms/${gymId}/members/${memberId}/remove`, { token, method: "DELETE" }),
};

export const trainerApi = {
  // Profile & members
  getProfile: (token: string) =>
    api<TrainerAssignedMember>("/trainers/me", { token }),

  getDashboard: (token: string) =>
    api<{ totalMembers: number; activeMembers: number; todayCheckIns: number }>("/trainers/me/dashboard", { token }),

  getMembers: (token: string) =>
    api<TrainerAssignedMember[]>("/trainers/me/members", { token }),

  // Member profile (unit + language preference)
  getMemberProfile: (memberId: string, token: string) =>
    api<{ member: { id: string; fullName: string; unitPreference: 'METRIC' | 'IMPERIAL'; languagePreference: 'EN' | 'KA' | 'RU' } }>(`/trainers/me/members/${memberId}/stats`, { token }),

  updateMemberPreferences: (memberId: string, data: { unitPreference?: 'METRIC' | 'IMPERIAL'; languagePreference?: 'EN' | 'KA' | 'RU' }, token: string) =>
    api<{ id: string; unitPreference: string; languagePreference: string }>(`/trainers/me/members/${memberId}/preferences`, { method: 'PATCH', body: data, token }),

  // Exercise library
  searchExercises: (q: string, token: string, lang?: string) =>
    api<ExerciseLibraryItem[]>(`/trainers/exercise-library?q=${encodeURIComponent(q)}${lang ? `&lang=${lang}` : ''}`, { token }),

  // Workout plans
  getMemberWorkoutPlans: (memberId: string, token: string) =>
    api<TrainerWorkoutPlan[]>(`/trainers/me/members/${memberId}/workout-plans`, { token }),

  createWorkoutPlan: (memberId: string, data: {
    name: string; difficulty: string; description?: string;
    startDate?: string; numWeeks?: number;
  }, token: string) =>
    api<TrainerWorkoutPlan>(`/trainers/me/members/${memberId}/workout-plans`, { method: "POST", body: data, token }),

  updateWorkoutPlan: (planId: string, data: Partial<{
    name: string; difficulty: string; isActive: boolean;
    startDate: string; numWeeks: number;
  }>, token: string) =>
    api<TrainerWorkoutPlan>(`/trainers/me/workout-plans/${planId}`, { method: "PUT", body: data, token }),

  activateWorkoutPlan: (planId: string, token: string) =>
    api<TrainerWorkoutPlan>(`/trainers/me/workout-plans/${planId}/activate`, { method: "POST", token }),

  deactivateWorkoutPlan: (planId: string, token: string) =>
    api<TrainerWorkoutPlan>(`/trainers/me/workout-plans/${planId}/deactivate`, { method: "POST", token }),

  deleteWorkoutPlan: (planId: string, token: string) =>
    api(`/trainers/me/workout-plans/${planId}`, { method: "DELETE", token }),

  // Routines
  addRoutine: (planId: string, data: {
    name: string; scheduledDate?: string; estimatedMinutes?: number; isDraft?: boolean;
  }, token: string) =>
    api<TrainerWorkoutRoutine>(`/trainers/me/workout-plans/${planId}/routines`, { method: "POST", body: data, token }),

  updateRoutine: (routineId: string, data: Partial<{
    name: string; estimatedMinutes: number; isDraft: boolean; scheduledDate: string; orderIndex: number;
  }>, token: string) =>
    api<TrainerWorkoutRoutine>(`/trainers/me/routines/${routineId}`, { method: "PUT", body: data, token }),

  deleteRoutine: (routineId: string, token: string) =>
    api(`/trainers/me/routines/${routineId}`, { method: "DELETE", token }),

  // Exercises
  addExercises: (routineId: string, exercises: Array<{
    exerciseName: string; targetSets?: number; targetReps?: number; targetWeight?: number; restSeconds?: number; rpe?: number; progressionNote?: string;
  }>, token: string) =>
    api<TrainerWorkoutExercise[]>(`/trainers/me/routines/${routineId}/exercises`, { method: "POST", body: { exercises }, token }),

  updateExercise: (exerciseId: string, data: Partial<{ exerciseName: string; targetSets: number; targetReps: number; targetWeight: number; restSeconds: number; rpe: number; progressionNote: string; orderIndex: number }>, token: string) =>
    api<TrainerWorkoutExercise>(`/trainers/me/exercises/${exerciseId}`, { method: "PUT", body: data, token }),

  deleteExercise: (exerciseId: string, token: string) =>
    api(`/trainers/me/exercises/${exerciseId}`, { method: "DELETE", token }),

  // Food search + custom foods
  searchFood: (q: string, token: string, lang: 'EN' | 'KA' | 'RU' = 'EN') =>
    api<TrainerFoodItem[]>(`/trainers/food-search?q=${encodeURIComponent(q)}&lang=${lang}`, { token }),

  createCustomFood: (data: {
    name: string; brand?: string; calories: number; protein: number;
    carbs: number; fats: number; fiber?: number;
  }, token: string) =>
    api<TrainerFoodItem>("/trainers/food-custom", { method: "POST", body: data, token }),

  getMyCustomFoods: (token: string) =>
    api<TrainerFoodItem[]>("/trainers/food-mine", { token }),

  deleteCustomFood: (foodId: string, token: string) =>
    api(`/trainers/food-custom/${foodId}`, { method: "DELETE", token }),

  // Diet plans
  getMemberDietPlans: (memberId: string, token: string) =>
    api<TrainerDietPlan[]>(`/trainers/me/members/${memberId}/diet-plans`, { token }),

  createDietPlan: (memberId: string, data: {
    name: string; targetCalories: number; targetProtein: number;
    targetCarbs: number; targetFats: number; startDate?: string;
    numWeeks?: number;
    hydrationTargetMl?: number;
    keyNutritionInsights?: string;
    weekTargets?: Array<{ calories: number; protein: number; carbs: number; fats: number }>;
  }, token: string) =>
    api<TrainerDietPlan>(`/trainers/me/members/${memberId}/diet-plans`, { method: "POST", body: data, token }),

  updateDietPlan: (planId: string, data: Partial<{
    name: string; targetCalories: number; targetProtein: number;
    targetCarbs: number; targetFats: number; isActive: boolean;
    hydrationTargetMl: number;
    keyNutritionInsights: string;
  }>, token: string) =>
    api<TrainerDietPlan>(`/trainers/me/diet-plans/${planId}`, { method: "PUT", body: data, token }),

  activateDietPlan: (planId: string, token: string) =>
    api<TrainerDietPlan>(`/trainers/me/diet-plans/${planId}/activate`, { method: "POST", token }),

  deactivateDietPlan: (planId: string, token: string) =>
    api<TrainerDietPlan>(`/trainers/me/diet-plans/${planId}/deactivate`, { method: "POST", token }),

  publishDietPlan: (planId: string, token: string) =>
    api<TrainerDietPlan>(`/trainers/me/diet-plans/${planId}/publish`, { method: "POST", token }),

  deleteDietPlan: (planId: string, token: string) =>
    api(`/trainers/me/diet-plans/${planId}`, { method: "DELETE", token }),

  // Meals
  addMeal: (planId: string, data: {
    name: string;
    timeOfDay?: string;
    scheduledDate?: string;
    totalCalories: number;
    protein: number;
    carbs: number;
    fats: number;
    items?: unknown;
    isDraft?: boolean;
    notificationTime?: string;
    isReminderEnabled?: boolean;
  }, token: string) =>
    api<TrainerMeal>(`/trainers/me/diet-plans/${planId}/meals`, { method: "POST", body: data, token }),

  updateMeal: (mealId: string, data: Partial<{
    name: string; timeOfDay: string; scheduledDate: string;
    totalCalories: number; protein: number; carbs: number; fats: number;
    items: TrainerMealItems; isDraft: boolean;
  }>, token: string) =>
    api<TrainerMeal>(`/trainers/me/meals/${mealId}`, { method: "PUT", body: data, token }),

  deleteMeal: (mealId: string, token: string) =>
    api(`/trainers/me/meals/${mealId}`, { method: "DELETE", token }),

  // Draft template library (trainer-level, shared across all members)
  getDraftTemplates: (token: string) =>
    api<TrainerDraftTemplate[]>("/trainers/me/draft-templates", { token }),

  createDraftTemplate: (data: {
    type: "meal" | "day" | "week" | "workout_exercise" | "workout_day" | "workout_week";
    name: string;
    data: TrainerTemplateMealData | TrainerTemplateDayData | TrainerTemplateWeekData | TrainerTemplateWorkoutExerciseData | TrainerTemplateWorkoutDayData | TrainerTemplateWorkoutWeekData;
  }, token: string) =>
    api<TrainerDraftTemplate>("/trainers/me/draft-templates", { method: "POST", body: data, token }),

  updateDraftTemplate: (templateId: string, patch: { name?: string; data?: unknown }, token: string) =>
    api<TrainerDraftTemplate>(`/trainers/me/draft-templates/${templateId}`, { method: "PATCH", body: patch, token }),

  deleteDraftTemplate: (templateId: string, token: string) =>
    api(`/trainers/me/draft-templates/${templateId}`, { method: "DELETE", token }),
};
