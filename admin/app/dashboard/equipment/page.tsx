"use client";

import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore, isBranchAdminOrAbove } from "@/lib/auth-store";
import { equipmentApi, uploadApi, type CreateEquipmentData, type Equipment, type CatalogItem } from "@/lib/api";
import { useRouter } from "next/navigation";
import {
  Plus,
  Dumbbell,
  Search,
  X,
  RefreshCw,
  CheckCircle2,
  Wrench,
  AlertTriangle,
  Upload,
  Edit2,
  Package,
  ArrowRight,
  Trash2
} from "lucide-react";
import NextImage from "next/image";
import { CustomSelect } from "@/components/ui/Select";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";

const CATEGORIES = [
  { value: "CARDIO", label: "Cardio" },
  { value: "STRENGTH", label: "Strength" },
  { value: "FREE_WEIGHTS", label: "Free Weights" },
  { value: "MACHINES", label: "Machines" },
  { value: "FUNCTIONAL", label: "Functional" },
  { value: "STRETCHING", label: "Stretching" },
  { value: "OTHER", label: "Other" },
];

type StatusFilter = "ALL" | "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER";

const STATUS_OPTIONS: { value: StatusFilter; label: string; color: string; icon: typeof CheckCircle2 }[] = [
  { value: "ALL", label: "All", color: "bg-zinc-500/10 text-zinc-400", icon: Dumbbell },
  { value: "AVAILABLE", label: "Available", color: "bg-green-500/10 text-green-400", icon: CheckCircle2 },
  { value: "MAINTENANCE", label: "Maintenance", color: "bg-yellow-500/10 text-yellow-400", icon: Wrench },
  { value: "OUT_OF_ORDER", label: "Out of Order", color: "bg-red-500/10 text-red-400", icon: AlertTriangle },
];

// Default equipment images by category
const CATEGORY_IMAGES: Record<string, string> = {
  CARDIO: "https://images.unsplash.com/photo-1576678927484-cc907957088c?w=200&h=200&fit=crop",
  STRENGTH: "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=200&h=200&fit=crop",
  FREE_WEIGHTS: "https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=200&h=200&fit=crop",
  MACHINES: "https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=200&h=200&fit=crop",
  FUNCTIONAL: "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=200&h=200&fit=crop",
  STRETCHING: "https://images.unsplash.com/photo-1518611012118-696072aa579a?w=200&h=200&fit=crop",
  OTHER: "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=200&h=200&fit=crop",
};

export default function EquipmentPage() {
  const { token, user } = useAuthStore();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingEquipment, setEditingEquipment] = useState<Equipment | null>(null);
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("ALL");
  const [showCatalogModal, setShowCatalogModal] = useState(false);

  // Unified gym selection
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole } = useGymSelection();

  // Role guard - redirect if not branch admin or above
  useEffect(() => {
    if (user && !isBranchAdminOrAbove(user.role)) {
      router.push("/dashboard");
    }
  }, [user, router]);

  // Get equipment for the gym
  const { data: equipment, isLoading: equipmentLoading } = useQuery({
    queryKey: ["equipment", selectedGymId, search, statusFilter],
    queryFn: () => equipmentApi.getByGym(selectedGymId!, token!, {
      search: search || undefined,
      status: statusFilter === "ALL" ? undefined : statusFilter,
    }),
    enabled: !!token && !!selectedGymId,
  });

  // Get stats
  const { data: stats } = useQuery({
    queryKey: ["equipment-stats", selectedGymId],
    queryFn: () => equipmentApi.getStats(selectedGymId!, token!),
    enabled: !!token && !!selectedGymId,
  });

  const createMutation = useMutation({
    mutationFn: (data: CreateEquipmentData) =>
      equipmentApi.create(selectedGymId!, data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["equipment", selectedGymId] });
      queryClient.invalidateQueries({ queryKey: ["equipment-stats", selectedGymId] });
      setShowAddModal(false);
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<CreateEquipmentData> }) =>
      equipmentApi.update(id, data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["equipment", selectedGymId] });
      queryClient.invalidateQueries({ queryKey: ["equipment-stats", selectedGymId] });
      setEditingEquipment(null);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => equipmentApi.delete(id, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["equipment", selectedGymId] });
      queryClient.invalidateQueries({ queryKey: ["equipment-stats", selectedGymId] });
    },
  });

  const createFromCatalogMutation = useMutation({
    mutationFn: (catalogItemId: string) =>
      equipmentApi.createFromCatalog(selectedGymId!, catalogItemId, {}, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["equipment", selectedGymId] });
      queryClient.invalidateQueries({ queryKey: ["equipment-stats", selectedGymId] });
      setShowCatalogModal(false);
    },
  });

  // We now use backend filtering, so filteredEquipment is just the equipment data
  const filteredEquipment = equipment;

  const cycleStatus = (currentStatus: "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER"): "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER" => {
    const statuses: ("AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER")[] = ["AVAILABLE", "MAINTENANCE", "OUT_OF_ORDER"];
    const currentIndex = statuses.indexOf(currentStatus);
    return statuses[(currentIndex + 1) % statuses.length];
  };

  if (gymsLoading && !selectedGymId) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-4">
        <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
        <p className="text-zinc-500 text-[10px] font-bold tracking-widest uppercase">Initializing Inventory Systems</p>
      </div>
    );
  }

  if (!selectedGymId && (!gyms || gyms.length === 0)) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-center">
        <div className="p-6 bg-zinc-900/50 rounded-3xl border border-white/5 mb-6">
          <Dumbbell className="text-zinc-700 mx-auto" size={48} />
        </div>
        <h2 className="text-xl font-bold text-white uppercase tracking-tight">No Facility Context</h2>
        <p className="text-zinc-500 mt-2 max-w-xs mx-auto text-sm">Please select a gym to manage machinery inventory and maintenance logs.</p>
      </div>
    );
  }

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <PageHeader
        title="EQUIPMENT INVENTORY"
        description="Manage high-performance gear and facility maintenance protocols"
        icon={<Dumbbell size={32} />}
        actions={
          <>
            <button
              onClick={() => setShowCatalogModal(true)}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-zinc-800 text-white font-black rounded-xl hover:bg-zinc-700 transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-black/20 shrink-0 border border-white/5"
            >
              <Package size={18} />
              Browse Catalog
            </button>

            <button
              onClick={() => setShowAddModal(true)}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
            >
              <Plus size={18} />
              Add Custom
            </button>

            <GymSwitcher 
              gyms={gyms} 
              isLoading={gymsLoading} 
              disabled={userRole === "BRANCH_ADMIN"}
            />
          </>
        }
      />

      {/* Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-2xl p-5 hover:border-[#F1C40F]/30 transition-all duration-300">
          <div className="absolute top-0 right-0 w-24 h-24 bg-blue-500/5 blur-3xl -mr-12 -mt-12 group-hover:bg-blue-500/10 transition-colors" />
          <div className="relative flex items-center gap-4">
            <div className="p-3 bg-blue-500/10 rounded-xl group-hover:scale-110 transition-transform duration-300">
              <Dumbbell className="text-blue-400" size={24} />
            </div>
            <div>
              <p className="text-xs font-medium text-zinc-500 uppercase tracking-wider">Total Inventory</p>
              <p className="text-3xl font-bold text-white mt-1">{stats?.total || 0}</p>
            </div>
          </div>
        </div>

        <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-2xl p-5 hover:border-green-500/30 transition-all duration-300">
          <div className="absolute top-0 right-0 w-24 h-24 bg-green-500/5 blur-3xl -mr-12 -mt-12 group-hover:bg-green-500/10 transition-colors" />
          <div className="relative flex items-center gap-4">
            <div className="p-3 bg-green-500/10 rounded-xl group-hover:scale-110 transition-transform duration-300">
              <CheckCircle2 className="text-green-400" size={24} />
            </div>
            <div>
              <p className="text-xs font-medium text-zinc-500 uppercase tracking-wider">Available Now</p>
              <p className="text-3xl font-bold text-white mt-1">{stats?.available || 0}</p>
            </div>
          </div>
        </div>

        <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-2xl p-5 hover:border-yellow-500/30 transition-all duration-300">
          <div className="absolute top-0 right-0 w-24 h-24 bg-yellow-500/5 blur-3xl -mr-12 -mt-12 group-hover:bg-yellow-500/10 transition-colors" />
          <div className="relative flex items-center gap-4">
            <div className="p-3 bg-yellow-500/10 rounded-xl group-hover:scale-110 transition-transform duration-300">
              <Wrench className="text-yellow-400" size={24} />
            </div>
            <div>
              <p className="text-xs font-medium text-zinc-500 uppercase tracking-wider">Maintenance</p>
              <p className="text-3xl font-bold text-white mt-1">{stats?.maintenance || 0}</p>
            </div>
          </div>
        </div>

        <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-2xl p-5 hover:border-red-500/30 transition-all duration-300">
          <div className="absolute top-0 right-0 w-24 h-24 bg-red-500/5 blur-3xl -mr-12 -mt-12 group-hover:bg-red-500/10 transition-colors" />
          <div className="relative flex items-center gap-4">
            <div className="p-3 bg-red-500/10 rounded-xl group-hover:scale-110 transition-transform duration-300">
              <AlertTriangle className="text-red-400" size={24} />
            </div>
            <div>
              <p className="text-xs font-medium text-zinc-500 uppercase tracking-wider">Out of Order</p>
              <p className="text-3xl font-bold text-white mt-1">{stats?.outOfOrder || 0}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Status Filters */}
      <div className="flex gap-2 overflow-x-auto py-4 px-4 -mx-4 custom-scrollbar">
        {STATUS_OPTIONS.map((option) => {
          const Icon = option.icon;
          return (
            <button
              key={option.value}
              onClick={() => setStatusFilter(option.value)}
              className={`px-4 py-3 rounded-xl text-xs font-bold uppercase tracking-wider transition-all whitespace-nowrap flex items-center gap-2 ${
                statusFilter === option.value
                  ? option.color + " ring-2 ring-offset-2 ring-offset-[#0d1117] ring-white/20"
                  : "bg-[#121721] text-zinc-500 border border-white/5 hover:border-white/10 hover:text-zinc-300"
              }`}
            >
              <Icon size={14} />
              {option.label}
              <span className="text-[10px] opacity-60">
                ({option.value === "ALL" ? stats?.total || 0 :
                  option.value === "AVAILABLE" ? stats?.available || 0 :
                  option.value === "MAINTENANCE" ? stats?.maintenance || 0 :
                  stats?.outOfOrder || 0})
              </span>
            </button>
          );
        })}
      </div>

      {/* Search */}
      <div className="flex gap-4">
        <div className="relative flex-1 group">
          <div className="absolute inset-0 bg-[#F1C40F]/5 blur-xl group-focus-within:bg-[#F1C40F]/10 transition-all duration-500 rounded-2xl opacity-0 group-focus-within:opacity-100" />
          <div className="relative">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500 group-focus-within:text-[#F1C40F] transition-colors" size={18} />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search Brand / Name"
              className="amirani-input amirani-input-with-icon font-medium"
            />
          </div>
        </div>
      </div>

      {/* Existing Inventory */}
      <div>
        <h2 className="text-lg font-semibold text-white mb-4">Existing Inventory</h2>

        {equipmentLoading ? (
          <div className="flex items-center justify-center py-12">
            <RefreshCw className="animate-spin text-[#F1C40F]" size={24} />
          </div>
        ) : !filteredEquipment || filteredEquipment.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 bg-[#121721] border border-white/5 rounded-[2.5rem] border-dashed">
            <div className="p-6 bg-zinc-900/50 rounded-3xl border border-white/5 mb-6">
              <Dumbbell className="text-zinc-700" size={48} />
            </div>
            <h3 className="text-xl font-black text-white uppercase tracking-tight italic">{search ? "No direct matches found" : "No equipment found"}</h3>
            <p className="text-zinc-500 mt-2 max-w-xs font-black text-[10px] uppercase tracking-widest text-center">
              {search ? "Refine your search parameters or add a new asset to the machinery catalog." : "Register your first high-performance asset to begin facility deployment."}
            </p>
            {!search && (
              <button
                onClick={() => setShowAddModal(true)}
                className="mt-8 flex items-center justify-center gap-3 px-8 py-4 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
              >
                <Plus size={16} />
                Enroll New Equipment
              </button>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {filteredEquipment.map((item) => (
              <div
                key={item.id}
                className="group relative bg-zinc-900/40 backdrop-blur-sm border border-white/5 rounded-2xl overflow-hidden hover:border-[#F1C40F]/30 transition-all duration-500 hover:shadow-2xl hover:shadow-[#F1C40F]/5"
              >
                {/* Image Section */}
                <div className="relative h-48 overflow-hidden bg-zinc-950">
                  <NextImage
                    src={item.imageUrl ? uploadApi.getFullUrl(item.imageUrl) : (CATEGORY_IMAGES[item.category] || CATEGORY_IMAGES.OTHER)}
                    alt={item.name}
                    fill
                    unoptimized
                    className="object-cover group-hover:scale-105 transition-transform duration-700 opacity-60 group-hover:opacity-100"
                    onError={(e) => {
                      const target = e.target as HTMLImageElement;
                      target.src = CATEGORY_IMAGES[item.category] || CATEGORY_IMAGES.OTHER;
                    }}
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-[#121721] via-transparent to-transparent opacity-80" />
                  
                  {/* Status Badge */}
                  <div className="absolute top-4 right-4 z-10">
                    <button
                      onClick={() => updateMutation.mutate({
                        id: item.id,
                        data: { status: cycleStatus(item.status) as "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER" }
                      })}
                      className={`p-3 rounded-2xl backdrop-blur-md border shadow-2xl transition-all hover:scale-110 flex items-center justify-center ${
                        item.status === "AVAILABLE" ? "bg-green-500/10 text-green-400 border-green-500/20" :
                        item.status === "MAINTENANCE" ? "bg-[#F1C40F]/10 text-[#F1C40F] border-[#F1C40F]/20" :
                        "bg-red-500/10 text-red-400 border-red-500/20"
                      }`}
                    >
                      {item.status === "AVAILABLE" ? <CheckCircle2 size={18} /> :
                       item.status === "MAINTENANCE" ? <Wrench size={18} /> :
                       <AlertTriangle size={18} />}
                    </button>
                  </div>
                </div>

                {/* Content Section */}
                <div className="relative p-6 pt-4">
                  <div className="flex items-start justify-between gap-2 mb-2">
                    <h3 className="font-black text-white text-xl tracking-tight leading-tight group-hover:text-[#F1C40F] transition-colors uppercase italic">{item.name}</h3>
                  </div>
                  
                  <div className="flex items-center gap-2 mb-4">
                    <span className="px-2.5 py-1 bg-white/5 border border-white/10 rounded-lg text-[9px] font-black text-zinc-500 uppercase tracking-widest leading-none">
                      {item.category.replace("_", " ")}
                    </span>
                    {item.brand && (
                      <span className="text-[10px] font-black text-[#F1C40F] uppercase tracking-[0.15em] leading-none px-2 border-l border-white/10">
                        {item.brand}
                      </span>
                    )}
                  </div>

                  <p className="text-zinc-500 text-xs font-medium leading-relaxed line-clamp-2 min-h-[3rem] italic">
                    {item.notes || `Professional grade ${item.category.toLowerCase()} equipment optimized for high-performance durability and member safety.`}
                  </p>
                  
                  <div className="mt-4 pt-4 border-t border-white/5 flex items-center justify-between text-[10px] font-black text-zinc-500 uppercase tracking-widest">
                    <span>Qty: {String(item.quantity ?? 0).padStart(2, '0')}</span>
                    <span className="flex items-center gap-1.5 text-zinc-600">
                      ID: {item.id.slice(0, 8)}
                    </span>
                  </div>

                  {/* Explicit Actions (Profile Style) */}
                  <div className="mt-6 flex flex-col gap-3">
                    <button
                      onClick={() => setEditingEquipment(item)}
                      className="w-full py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F4D03F] transition-all flex items-center justify-center gap-3 shadow-xl shadow-[#F1C40F]/10 hover:shadow-[#F1C40F]/20 active:scale-[0.98]"
                    >
                      <Edit2 size={14} />
                      Specifications
                    </button>
                    <button
                      onClick={() => {
                        if (confirm("Permanently decommission this equipment?")) {
                          deleteMutation.mutate(item.id);
                        }
                      }}
                      className="w-full py-3 bg-red-500/5 text-red-500/60 hover:bg-red-500 hover:text-white border border-red-500/10 rounded-2xl transition-all flex items-center justify-center gap-2 font-black uppercase tracking-widest text-[9px] group/del active:scale-[0.98]"
                    >
                      <Trash2 size={16} className="group-hover/del:scale-110 transition-transform" />
                      Decommission
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Add Equipment Modal */}
      {showAddModal && (
        <AddEquipmentModal
          onClose={() => setShowAddModal(false)}
          onSubmit={(data) => createMutation.mutate(data)}
          isLoading={createMutation.isPending}
          error={createMutation.error?.message}
          token={token!}
        />
      )}

      {/* Edit Equipment Modal */}
      {editingEquipment && (
        <EditEquipmentModal
          equipment={editingEquipment}
          onClose={() => setEditingEquipment(null)}
          onSubmit={(data) => updateMutation.mutate({ id: editingEquipment.id, data })}
          isLoading={updateMutation.isPending}
          error={updateMutation.error?.message}
        />
      )}

      {/* Catalog Browse Modal */}
      {showCatalogModal && (
        <CatalogBrowseModal
          onClose={() => setShowCatalogModal(false)}
          onAdd={(catalogItem: CatalogItem) => {
            createFromCatalogMutation.mutate(catalogItem.id);
          }}
          isLoading={createFromCatalogMutation.isPending}
          token={token!}
        />
      )}
    </div>
  );
}

function AddEquipmentModal({
  onClose,
  onSubmit,
  isLoading,
  error,
  token,
}: {
  onClose: () => void;
  onSubmit: (data: CreateEquipmentData) => void;
  isLoading: boolean;
  error?: string;
  token: string;
}) {
  const [formData, setFormData] = useState<CreateEquipmentData>({
    name: "",
    category: "OTHER",
    brand: "",
    quantity: 1,
    notes: "",
    imageUrl: "",
  });
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const handleFileSelect = async (file: File) => {
    setUploadError(null);
    setUploading(true);

    // Create preview
    const reader = new FileReader();
    reader.onload = (e) => setPreviewUrl(e.target?.result as string);
    reader.readAsDataURL(file);

    try {
      const result = await uploadApi.uploadFile(file, "equipment", token);
      setFormData({ ...formData, imageUrl: result.url });
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : "Upload failed");
      setPreviewUrl(null);
    } finally {
      setUploading(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 bg-black/95 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-500">
      <div className="bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.8)] flex flex-col overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
          <h2 className="text-xl font-bold text-white uppercase tracking-tight italic">Enroll New Equipment</h2>
          <button onClick={onClose} className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {error && (
              <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-3 text-red-400 text-sm">
                {error}
              </div>
            )}

            <div>
              <label className="amirani-label">Equipment Name *</label>
              <input
                type="text"
                required
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                className="amirani-input"
                placeholder="e.g., Treadmill, Dumbbell Set"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <CustomSelect
                  label="Category"
                  required
                  value={formData.category}
                  onChange={(value) => setFormData({ ...formData, category: value })}
                  options={CATEGORIES}
                />
              </div>
              <div>
                <label className="amirani-label">Quantity</label>
                <input
                  type="number"
                  min="1"
                  value={formData.quantity}
                  onChange={(e) =>
                    setFormData({ ...formData, quantity: parseInt(e.target.value) || 1 })
                  }
                  className="amirani-input"
                />
              </div>
            </div>

            <div>
              <label className="amirani-label">Brand</label>
              <input
                type="text"
                value={formData.brand}
                onChange={(e) => setFormData({ ...formData, brand: e.target.value })}
                className="amirani-input"
                placeholder="e.g., Life Fitness"
              />
            </div>

            <div>
              <label className="amirani-label">Equipment Image</label>
              <div className={`group relative h-40 bg-white/[0.02] border-2 border-dashed rounded-xl flex flex-col items-center justify-center transition-all overflow-hidden backdrop-blur-sm cursor-pointer ${
                uploadError ? "border-red-500/50" : previewUrl ? "border-green-500/50" : "border-white/10 hover:bg-white/[0.05] hover:border-[#F1C40F]/50"
              }`}>
                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp,image/gif"
                  className="absolute inset-0 opacity-0 cursor-pointer z-10"
                  disabled={uploading}
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      handleFileSelect(file);
                    }
                  }}
                />
                {uploading ? (
                  <div className="flex flex-col items-center">
                    <RefreshCw size={24} className="text-[#F1C40F] animate-spin mb-2" />
                    <p className="text-xs font-bold text-zinc-400">UPLOADING...</p>
                  </div>
                ) : previewUrl ? (
                  <div className="relative w-full h-full">
                    <NextImage src={previewUrl} alt="Preview" fill className="object-cover" unoptimized />
                    <div className="absolute inset-0 bg-black/60 flex flex-col items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                      <Upload size={20} className="text-[#F1C40F] mb-1" />
                      <p className="text-[10px] font-black text-white uppercase tracking-widest">Replace Visual</p>
                    </div>
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        setPreviewUrl(null);
                        setFormData({ ...formData, imageUrl: "" });
                      }}
                      className="absolute top-3 right-3 p-1.5 bg-red-500/80 text-white rounded-lg hover:bg-red-600 transition-all z-20 shadow-xl"
                    >
                      <X size={14} />
                    </button>
                  </div>
                ) : (
                  <div className="flex flex-col items-center text-zinc-500 transition-all group-hover:text-zinc-300">
                    <div className="w-10 h-10 bg-zinc-900/50 rounded-xl flex items-center justify-center mb-3 group-hover:scale-110 transition-transform border border-white/5">
                      <Upload size={20} className="text-[#F1C40F]" />
                    </div>
                    <p className="text-[11px] font-bold tracking-tight text-white uppercase italic">UPLOAD VISUAL DATA</p>
                    <p className="text-[9px] text-zinc-600 mt-1 uppercase font-black tracking-widest">JPEG, PNG, WebP (MAX 5MB)</p>
                  </div>
                )}
              </div>
              {uploadError && (
                <p className="text-red-400 text-xs mt-2">{uploadError}</p>
              )}
            </div>

            <div>
              <label className="amirani-label">Description</label>
              <textarea
                value={formData.notes}
                onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                rows={3}
                className="amirani-textarea"
                placeholder="Professional performance equipment for..."
              />
            </div>
          </form>
        </div>

        {/* FIXED FOOTER */}
        <div className="p-8 border-t border-white/5 flex gap-4 shrink-0 bg-white/[0.01]">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl hover:bg-zinc-800 transition-all font-black uppercase tracking-widest text-[10px] border border-white/10"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={isLoading || !formData.name}
            className="flex-1 py-4 bg-[#F1C40F] !text-black rounded-2xl hover:bg-[#F1C40F]/90 transition-all disabled:opacity-30 flex items-center justify-center gap-3 font-black uppercase tracking-widest text-[10px] shadow-2xl shadow-[#F1C40F]/20"
          >
            {isLoading ? (
              <RefreshCw className="animate-spin" size={18} />
            ) : (
              <>
                <Plus size={18} />
                Confirm Addition
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

function EditEquipmentModal({
  equipment,
  onClose,
  onSubmit,
  isLoading,
  error,
}: {
  equipment: Equipment;
  onClose: () => void;
  onSubmit: (data: Partial<CreateEquipmentData>) => void;
  isLoading: boolean;
  error?: string;
}) {
  const [formData, setFormData] = useState<Partial<CreateEquipmentData>>({
    name: equipment.name,
    category: equipment.category,
    brand: equipment.brand || "",
    quantity: equipment.quantity || 1,
    notes: equipment.notes || "",
    status: equipment.status,
    imageUrl: equipment.imageUrl || "",
  });

  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(equipment.imageUrl ? uploadApi.getFullUrl(equipment.imageUrl) : null);
  const { token } = useAuthStore();

  const handleFileSelect = async (file: File) => {
    setUploadError(null);
    setUploading(true);

    // Create preview
    const reader = new FileReader();
    reader.onload = (e) => setPreviewUrl(e.target?.result as string);
    reader.readAsDataURL(file);

    try {
      const result = await uploadApi.uploadFile(file, "equipment", token!);
      setFormData({ ...formData, imageUrl: result.url });
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : "Upload failed");
      setPreviewUrl(null);
    } finally {
      setUploading(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 bg-black/95 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-500">
      <div className="bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.8)] flex flex-col overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
          <h2 className="text-xl font-bold text-white uppercase tracking-tight italic">Refine Asset Details</h2>
          <button onClick={onClose} className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {error && (
              <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-3 text-red-400 text-sm">
                {error}
              </div>
            )}

            <div>
              <label className="amirani-label">Equipment Name *</label>
              <input
                type="text"
                required
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                className="amirani-input"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <CustomSelect
                  label="Category"
                  required
                  value={formData.category || "OTHER"}
                  onChange={(value) => setFormData({ ...formData, category: value })}
                  options={CATEGORIES}
                />
              </div>
              <div>
                <CustomSelect
                  label="Status"
                  required
                  value={formData.status || "AVAILABLE"}
                  onChange={(value) => setFormData({ ...formData, status: value as "AVAILABLE" | "MAINTENANCE" | "OUT_OF_ORDER" })}
                  options={[
                    { value: "AVAILABLE", label: "Available" },
                    { value: "MAINTENANCE", label: "Maintenance" },
                    { value: "OUT_OF_ORDER", label: "Out of Order" },
                  ]}
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="amirani-label">Brand</label>
                <input
                  type="text"
                  value={formData.brand}
                  onChange={(e) => setFormData({ ...formData, brand: e.target.value })}
                  className="amirani-input"
                />
              </div>
              <div>
                <label className="amirani-label">Quantity</label>
                <input
                  type="number"
                  min="1"
                  value={formData.quantity}
                  onChange={(e) => setFormData({ ...formData, quantity: parseInt(e.target.value) || 1 })}
                  className="amirani-input"
                />
              </div>
            </div>

            <div>
              <label className="amirani-label">Equipment Image</label>
              <div className={`group relative h-40 bg-white/[0.02] border-2 border-dashed rounded-xl flex flex-col items-center justify-center transition-all overflow-hidden backdrop-blur-sm cursor-pointer ${
                uploadError ? "border-red-500/50" : previewUrl ? "border-green-500/50" : "border-white/10 hover:bg-white/[0.05] hover:border-[#F1C40F]/50"
              }`}>
                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp,image/gif"
                  className="absolute inset-0 opacity-0 cursor-pointer z-10"
                  disabled={uploading}
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      handleFileSelect(file);
                    }
                  }}
                />
                {uploading ? (
                  <div className="flex flex-col items-center">
                    <RefreshCw size={24} className="text-[#F1C40F] animate-spin mb-2" />
                    <p className="text-xs font-bold text-zinc-400">UPLOADING...</p>
                  </div>
                ) : previewUrl ? (
                  <div className="relative w-full h-full">
                    <NextImage src={previewUrl} alt="Preview" fill className="object-cover" unoptimized />
                    <div className="absolute inset-0 bg-black/60 flex flex-col items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                      <Upload size={20} className="text-[#F1C40F] mb-1" />
                      <p className="text-[10px] font-black text-white uppercase tracking-widest">Replace Visual</p>
                    </div>
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        setPreviewUrl(null);
                        setFormData({ ...formData, imageUrl: "" });
                      }}
                      className="absolute top-3 right-3 p-1.5 bg-red-500/80 text-white rounded-lg hover:bg-red-600 transition-all z-20 shadow-xl"
                    >
                      <X size={14} />
                    </button>
                  </div>
                ) : (
                  <div className="flex flex-col items-center text-zinc-500 transition-all group-hover:text-zinc-300">
                    <div className="w-10 h-10 bg-zinc-900/50 rounded-xl flex items-center justify-center mb-3 group-hover:scale-110 transition-transform border border-white/5">
                      <Upload size={20} className="text-[#F1C40F]" />
                    </div>
                    <p className="text-[11px] font-bold tracking-tight text-white uppercase italic">UPLOAD VISUAL DATA</p>
                    <p className="text-[9px] text-zinc-600 mt-1 uppercase font-black tracking-widest">JPEG, PNG, WebP (MAX 5MB)</p>
                  </div>
                )}
              </div>
              {uploadError && (
                <p className="text-red-400 text-xs mt-2">{uploadError}</p>
              )}
            </div>

            <div>
              <label className="amirani-label">Description</label>
              <textarea
                value={formData.notes}
                onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                rows={3}
                className="amirani-textarea"
              />
            </div>
          </form>
        </div>

        {/* FIXED FOOTER */}
        <div className="p-8 border-t border-white/5 flex gap-4 shrink-0 bg-white/[0.01]">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl hover:bg-zinc-800 transition-all font-black uppercase tracking-widest text-[10px] border border-white/10"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={isLoading || !formData.name}
            className="flex-1 py-4 bg-[#F1C40F] !text-black rounded-2xl hover:bg-[#F1C40F]/90 transition-all disabled:opacity-30 flex items-center justify-center gap-3 font-black uppercase tracking-widest text-[10px] shadow-2xl shadow-[#F1C40F]/20"
          >
            {isLoading ? (
              <RefreshCw className="animate-spin" size={18} />
            ) : (
              "Apply Modifications"
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

function CatalogBrowseModal({
  onClose,
  onAdd,
  isLoading,
  token,
}: {
  onClose: () => void;
  onAdd: (item: CatalogItem) => void;
  isLoading: boolean;
  token: string;
}) {
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("");

  const { data: items, isLoading: itemsLoading } = useQuery({
    queryKey: ["equipment-catalog-browse", search, category],
    queryFn: () => equipmentApi.getCatalog(token, {
      search: search || undefined,
      category: category || undefined,
    }),
  });

  return (
    <div className="fixed inset-0 bg-black/95 backdrop-blur-md flex items-center justify-center z-[60] p-4 transition-all animate-in fade-in duration-500">
      <div className="bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-4xl max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.8)] flex flex-col overflow-hidden">
        {/* FIXED HEADER */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02] shrink-0">
          <div>
            <h2 className="text-2xl font-black text-white uppercase tracking-tighter italic">Master Machinery Catalog</h2>
            <p className="text-zinc-500 text-[10px] font-black tracking-widest uppercase mt-1">Select high-performance assets for facility deployment</p>
          </div>
          <button onClick={onClose} className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* SEARCH & FILTERS (STILL FIXED) */}
        <div className="p-6 border-b border-white/5 bg-black/20 flex gap-4 shrink-0">
          <div className="relative flex-1 group">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500" size={18} />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search master records..."
              className="w-full pl-12 pr-4 py-3 bg-zinc-900/50 border border-white/5 rounded-xl text-white placeholder-zinc-600 focus:outline-none focus:border-[#F1C40F]/50 transition-all text-sm"
            />
          </div>
          <CustomSelect
            value={category}
            onChange={(v) => setCategory(v)}
            options={[
              { value: "", label: "All Categories" },
              { value: "CARDIO", label: "Cardio" },
              { value: "STRENGTH", label: "Strength" },
              { value: "FREE_WEIGHTS", label: "Free Weights" },
              { value: "MACHINES", label: "Machines" },
              { value: "FUNCTIONAL", label: "Functional" },
              { value: "STRETCHING", label: "Stretching" },
              { value: "OTHER", label: "Other" },
            ]}
            className="w-48"
          />
        </div>

        {/* SCROLLABLE CONTENT */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
          {itemsLoading ? (
            <div className="flex flex-col items-center justify-center h-64 gap-4">
              <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
              <p className="text-zinc-500 text-[10px] font-bold tracking-widest uppercase">Syncing Master Models</p>
            </div>
          ) : !items || items.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-64 text-zinc-600 border-2 border-dashed border-white/5 rounded-2xl">
              <Package size={48} className="mb-4 opacity-20" />
              <p className="font-bold text-sm">No master records found</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {items.map((item: CatalogItem) => (
                <div key={item.id} className="group relative bg-white/[0.02] border border-white/5 rounded-2xl p-4 hover:border-[#F1C40F]/30 transition-all">
                  <div className="flex gap-4">
                    <div className="w-20 h-20 bg-zinc-950 rounded-xl overflow-hidden flex-shrink-0 border border-white/5">
                      {item.imageUrl ? (
                        <div className="relative w-full h-full">
                          <NextImage src={item.imageUrl} alt={item.name} fill className="object-cover group-hover:scale-110 transition-transform duration-500" />
                        </div>
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-zinc-800">
                          <Package size={24} />
                        </div>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between">
                        <div>
                          <h4 className="font-bold text-white text-sm truncate uppercase tracking-tight italic">{item.name}</h4>
                          <p className="text-[10px] font-black text-[#F1C40F] uppercase tracking-widest mt-0.5 tracking-tighter">{item.brand || "UNBRANDED"}</p>
                        </div>
                        <span className="text-[9px] px-2 py-0.5 bg-zinc-800 border border-white/5 rounded text-zinc-500 font-bold uppercase tracking-tighter">
                          {item.category}
                        </span>
                      </div>
                      <p className="text-xs text-zinc-500 mt-2 line-clamp-1 italic opacity-60 font-medium font-black">
                        {item.description || "System standard specification model."}
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={() => onAdd(item)}
                    disabled={isLoading}
                    className="mt-4 w-full py-3 bg-white/[0.03] border border-white/5 rounded-xl text-white text-[10px] font-black uppercase tracking-widest hover:bg-[#F1C40F] hover:text-black transition-all flex items-center justify-center gap-2 group/btn disabled:opacity-50"
                  >
                    {isLoading ? (
                      <RefreshCw size={14} className="animate-spin" />
                    ) : (
                      <>
                        Deploy Asset
                        <ArrowRight size={14} className="group-hover/btn:translate-x-1 transition-transform" />
                      </>
                    )}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* FIXED FOOTER */}
        <div className="p-6 border-t border-white/5 bg-white/[0.01] shrink-0 flex justify-between items-center">
           <p className="text-[9px] text-zinc-600 font-black uppercase tracking-[0.3em]">Amirani Global Logistics Protocol</p>
           <button 
             onClick={onClose}
             className="px-6 py-2 bg-white/5 text-zinc-500 hover:text-white rounded-xl text-[10px] font-black uppercase tracking-widest border border-white/5 transition-all"
           >
             Close Catalog
           </button>
        </div>
      </div>
    </div>
  );
}
