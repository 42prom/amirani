"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { gymsApi, uploadApi, type CreateGymData, type Gym } from "@/lib/api";
import { Building2, MapPin, Search, CheckCircle, Plus, LayoutGrid, X, Phone, Mail, Info, Globe, RefreshCw, Upload, Edit2, Trash2 } from "lucide-react";
import Link from "next/link";
import NextImage from "next/image";
import { useGymSelection } from "@/hooks/useGymSelection";
import { useGymStore } from "@/lib/gym-store";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";

export default function GymsPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const { setSelectedGymId } = useGymStore();
  
  // Use the unified gym selection hook
  const { gyms, isLoading, isGymsLoading, isBranchAdmin } = useGymSelection();
  const queryClient = useQueryClient();
  const superAdmin = isSuperAdmin(user?.role);

  // Redirect Super Admin away from branch list
  useEffect(() => {
    if (superAdmin) {
      router.push("/dashboard");
    }
  }, [superAdmin, router]);

  const [searchQuery, setSearchQuery] = useState("");
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingGym, setEditingGym] = useState<Gym | null>(null);
  const [formData, setFormData] = useState({
    name: "",
    address: "",
    city: "",
    country: "",
    phone: "",
    email: "",
    description: "",
    ownerId: "",
  });
  const [logoUrl, setLogoUrl] = useState("");
  const [logoPreview, setLogoPreview] = useState<string | null>(null);
  const [logoUploading, setLogoUploading] = useState(false);
  const [logoError, setLogoError] = useState<string | null>(null);

  const handleLogoUpload = async (file: File) => {
    if (!token) return;
    setLogoError(null);
    setLogoUploading(true);

    // Create preview
    const reader = new FileReader();
    reader.onload = (e) => setLogoPreview(e.target?.result as string);
    reader.readAsDataURL(file);

    try {
      const result = await uploadApi.uploadFile(file, "gyms", token);
      setLogoUrl(result.url);
    } catch (err) {
      setLogoError(err instanceof Error ? err.message : "Upload failed");
      setLogoPreview(null);
    } finally {
      setLogoUploading(false);
    }
  };

  const createGymMutation = useMutation({
    mutationFn: (data: Omit<CreateGymData, "ownerId">) =>
      gymsApi.create({ ...data, ownerId: user!.id }, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gyms"] });
      setShowAddModal(false);
      resetForm();
    },
  });

  const updateGymMutation = useMutation({
    mutationFn: (data: Partial<CreateGymData>) =>
      gymsApi.update(editingGym!.id, data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gyms"] });
      setEditingGym(null);
      resetForm();
    },
  });

  const deleteGymMutation = useMutation({
    mutationFn: (id: string) => gymsApi.delete(id, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gyms"] });
    },
  });

  const resetForm = () => {
    setFormData({
      name: "",
      address: "",
      city: "",
      country: "",
      phone: "",
      email: "",
      description: "",
      ownerId: "",
    });
    setLogoUrl("");
    setLogoPreview(null);
    setLogoError(null);
  };

  const handleEdit = (e: React.MouseEvent, gym: Gym) => {
    e.preventDefault();
    e.stopPropagation();
    setEditingGym(gym);
    setFormData({
      name: gym.name,
      address: gym.address,
      city: gym.city,
      country: gym.country,
      ownerId: gym.owner.id,
      phone: gym.phone || "",
      email: gym.email || "",
      description: gym.description || "",
    });
    setLogoUrl(gym.logoUrl || "");
    setLogoPreview(gym.logoUrl ? uploadApi.getFullUrl(gym.logoUrl) : null);
  };

  const handleDelete = async (e: React.MouseEvent, gym: Gym) => {
    e.preventDefault();
    e.stopPropagation();
    if (confirm(`Are you sure you want to delete ${gym.name}? This will delete all associated data (staff, gear, members) and cannot be undone.`)) {
      deleteGymMutation.mutate(gym.id);
    }
  };


  const filteredGyms = gyms?.filter(
    (gym) =>
      gym.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      gym.city.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Super Admin View - Summary only, no drill-down
  if (superAdmin) {
    return (
      <div>
      <PageHeader
        title="GYMS OVERVIEW"
        description="High-level summary of all gyms on the platform"
        icon={<LayoutGrid size={32} />}
      />

        {/* Search */}
        <div className="mb-6">
          <div className="relative max-w-md">
            <Search className="absolute left-4 text-zinc-500" size={18} />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search by name or city..."
              className="amirani-input amirani-input-with-icon font-medium"
            />
          </div>
        </div>

        {/* Summary Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
            <p className="text-sm text-zinc-400">Total Gyms</p>
            <p className="text-3xl font-bold text-white mt-2">{gyms?.length || 0}</p>
          </div>
          <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
            <p className="text-sm text-zinc-400">Active Gyms</p>
            <p className="text-3xl font-bold text-green-400 mt-2">
              {gyms?.filter((g) => g.isActive).length || 0}
            </p>
          </div>
          <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
            <p className="text-sm text-zinc-400">Inactive Gyms</p>
            <p className="text-3xl font-bold text-red-400 mt-2">
              {gyms?.filter((g) => !g.isActive).length || 0}
            </p>
          </div>
        </div>

        {/* Gyms List - No drill-down for Super Admin */}
        <div className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden">
          <div className="p-4 border-b border-zinc-800">
            <h2 className="text-lg font-semibold text-white">All Gyms</h2>
          </div>

          {isLoading ? (
            <div className="text-center text-zinc-400 py-12">Loading gyms...</div>
          ) : filteredGyms?.length === 0 ? (
            <div className="text-center text-zinc-400 py-12">
              {searchQuery ? "No gyms match your search" : "No gyms registered yet"}
            </div>
          ) : (
            <div className="divide-y divide-zinc-800">
              {filteredGyms?.map((gym) => (
                <div
                  key={gym.id}
                  className="p-4 flex items-center justify-between"
                >
                  <div className="flex items-center gap-4">
                    <div className="w-10 h-10 bg-[#F1C40F]/10 rounded-lg flex items-center justify-center">
                      <Building2 className="text-[#F1C40F]" size={20} />
                    </div>
                    <div>
                      <p className="font-medium text-white">{gym.name}</p>
                      <p className="flex items-center gap-1 text-sm text-zinc-500">
                        <MapPin size={12} />
                        {gym.city}, {gym.country}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-6">
                    {/* Subscription Status - Mock for now */}
                    <div className="text-center">
                      <div className="flex items-center gap-1">
                        <CheckCircle size={14} className="text-green-400" />
                        <span className="text-sm text-green-400">Subscribed</span>
                      </div>
                    </div>

                    {/* Active Status */}
                    <div className="text-center">
                      {gym.isActive ? (
                        <span className="px-3 py-1 bg-green-500/10 text-green-400 rounded-full text-xs font-medium">
                          Active
                        </span>
                      ) : (
                        <span className="px-3 py-1 bg-red-500/10 text-red-400 rounded-full text-xs font-medium">
                          Inactive
                        </span>
                      )}
                    </div>

                    {/* Owner */}
                    <div className="text-right min-w-[150px]">
                      <p className="text-sm text-zinc-400">{gym.owner.fullName}</p>
                      <p className="text-xs text-zinc-600">{gym.owner.email}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <p className="text-xs text-zinc-600 mt-4 text-center">
          Super Admin view is read-only. Gym details are managed by their respective owners.
        </p>
      </div>
    );
  }

  // Gym Owner View - Full access with drill-down
  return (
    <div className="space-y-12">
      <PageHeader
        title="Facility Overview"
        description="Manage and monitor all gym branches across your network."
        icon={<Building2 size={32} />}
        actions={
          <GymSwitcher 
            gyms={gyms} 
            isLoading={isGymsLoading} 
            disabled={isBranchAdmin}
          />
        }
      />
      {/* Gyms Grid */}
      {isLoading ? (
        <div className="text-center text-zinc-400 py-12">Loading gyms...</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {/* Add Branch Card */}
          <button
            onClick={() => setShowAddModal(true)}
            className="group relative bg-white/[0.02] border-2 border-dashed border-white/10 rounded-[2.5rem] p-8 flex flex-col items-center justify-center transition-all duration-500 hover:bg-white/[0.05] hover:border-[#F1C40F]/50 group h-full min-h-[300px]"
          >
            <div className="w-16 h-16 bg-[#F1C40F]/10 rounded-2xl flex items-center justify-center mb-6 group-hover:scale-110 group-hover:bg-[#F1C40F]/20 transition-all duration-500">
              <Plus className="text-[#F1C40F] transition-transform duration-500 group-hover:rotate-90" size={32} />
            </div>
            <h3 className="text-xl font-black text-white uppercase tracking-tighter">Add New Branch</h3>
            <p className="text-zinc-500 text-[11px] font-bold tracking-widest uppercase mt-2">Expand Your Network</p>
          </button>

          {gyms?.map((gym) => (
            <Link
              key={gym.id}
              href={`/dashboard/gyms/${gym.id}`}
              onClick={() => setSelectedGymId(gym.id)}
              className="group relative bg-white/[0.03] backdrop-blur-md border border-white/10 rounded-[2.5rem] p-8 transition-all duration-500 hover:-translate-y-2 hover:bg-white/[0.08] hover:border-[#F1C40F]/30 overflow-hidden"
            >
              {/* Card Glow Effect */}
              <div className="absolute -top-24 -right-24 w-48 h-48 bg-[#F1C40F]/5 rounded-full blur-[80px] group-hover:bg-[#F1C40F]/10 transition-all duration-700" />
              
              <div className="flex items-start justify-between mb-8 relative z-10">
                <div className="w-16 h-16 bg-[#F1C40F]/10 rounded-2xl flex items-center justify-center shadow-inner">
                  <Building2 className="text-[#F1C40F]" size={28} />
                </div>
                <div className="flex flex-col items-end gap-2">
                  <span
                    className={`px-4 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest backdrop-blur-md shadow-lg ${
                      gym.isActive
                        ? "bg-green-500/10 text-green-400 border border-green-500/20"
                        : "bg-red-500/10 text-red-400 border border-red-500/20"
                    }`}
                  >
                    {gym.isActive ? "Active" : "Inactive"}
                  </span>
                  <div className="flex gap-2">
                    <button
                      onClick={(e) => handleEdit(e, gym)}
                      className="p-2 bg-white/5 text-zinc-500 hover:text-[#F1C40F] hover:bg-[#F1C40F]/10 rounded-lg transition-all border border-white/5"
                    >
                      <Edit2 size={14} />
                    </button>
                    <button
                      onClick={(e) => handleDelete(e, gym)}
                      className="p-2 bg-white/5 text-zinc-500 hover:text-red-400 hover:bg-red-400/10 rounded-lg transition-all border border-white/5"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              </div>

              <div className="relative z-10">
                <h3 className="text-2xl font-black text-white uppercase tracking-tighter group-hover:text-[#F1C40F] transition-colors line-clamp-1">
                  {gym.name}
                </h3>
                <p className="flex items-center gap-1.5 text-xs font-bold text-zinc-500 uppercase tracking-widest mt-2">
                  <MapPin size={14} className="text-[#F1C40F]/60" />
                  {gym.city}, {gym.country}
                </p>
              </div>

              <div className="grid grid-cols-3 gap-6 mt-10 pt-8 border-t border-white/5 relative z-10">
                <div className="text-center group/stat">
                  <p className="text-2xl font-black text-white tracking-tighter group-hover/stat:text-[#F1C40F] transition-colors">
                    {gym._count.memberships}
                  </p>
                  <p className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.2em] mt-1.5">Members</p>
                </div>
                <div className="text-center group/stat border-x border-white/5 px-4">
                  <p className="text-2xl font-black text-white tracking-tighter group-hover/stat:text-[#F1C40F] transition-colors">
                    {gym._count.trainers}
                  </p>
                  <p className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.2em] mt-1.5">Staff</p>
                </div>
                <div className="text-center group/stat">
                  <p className="text-2xl font-black text-white tracking-tighter group-hover/stat:text-[#F1C40F] transition-colors">
                    {gym._count.equipment}
                  </p>
                  <p className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.2em] mt-1.5">Gear</p>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}

      {/* Create Gym Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="flex flex-col bg-[#121721] border border-white/10 w-full max-w-2xl max-h-[90vh] rounded-[2.5rem] shadow-2xl animate-in fade-in zoom-in duration-300 overflow-hidden">
            {/* FIXED HEADER */}
            <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
              <div>
                <h2 className="text-3xl font-black text-white tracking-tighter italic uppercase">
                  Register New Branch
                </h2>
                <p className="text-zinc-500 text-[10px] font-black uppercase tracking-[0.2em] mt-1">
                  Facility Induction Protocol
                </p>
              </div>
              <button
                onClick={() => setShowAddModal(false)}
                className="p-3 hover:bg-white/5 rounded-2xl transition-colors text-zinc-500 hover:text-white"
              >
                <X size={24} />
              </button>
            </div>

            {/* SCROLLABLE CONTENT */}
            <div className="flex-1 overflow-y-auto amirani-scrollbar">
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  createGymMutation.mutate({ ...formData, logoUrl: logoUrl || undefined });
                }}
                className="p-8 space-y-6"
              >
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-2">
                  <label className="amirani-label">Branch Name</label>
                  <div className="relative">
                    <Building2 className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      required
                      type="text"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="Amirani Elite North"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">Contact Email</label>
                  <div className="relative">
                    <Mail className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      type="email"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="north@amirani.com"
                      value={formData.email}
                      onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">Physical Address</label>
                  <div className="relative">
                    <MapPin className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      required
                      type="text"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="123 Industrial Way"
                      value={formData.address}
                      onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">City/District</label>
                  <div className="relative">
                    <Globe className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      required
                      type="text"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="Tbilisi"
                      value={formData.city}
                      onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">Country</label>
                  <div className="relative">
                    <Info className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      required
                      type="text"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="Georgia"
                      value={formData.country}
                      onChange={(e) => setFormData({ ...formData, country: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">Contact Phone</label>
                  <div className="relative">
                    <Phone className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      type="tel"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="+995 ..."
                      value={formData.phone}
                      onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    />
                  </div>
                </div>
              </div>

              <div className="space-y-2">
                <label className="amirani-label">Brief Description</label>
                <textarea
                  rows={3}
                  className="amirani-textarea"
                  placeholder="Describe the facility's unique equipment or focus..."
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                />
              </div>

              <div className="space-y-2">
                <label className="amirani-label">Branch Logo</label>
                <div className={`group relative h-32 bg-white/[0.02] border-2 border-dashed rounded-xl flex items-center justify-center transition-all overflow-hidden cursor-pointer ${
                  logoError ? "border-red-500/50" : logoPreview ? "border-green-500/50" : "border-white/10 hover:bg-white/[0.05] hover:border-[#F1C40F]/50"
                }`}>
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,image/gif"
                    className="absolute inset-0 opacity-0 cursor-pointer z-10"
                    disabled={logoUploading}
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) handleLogoUpload(file);
                    }}
                  />
                  {logoUploading ? (
                    <div className="flex items-center gap-3">
                      <RefreshCw size={20} className="text-[#F1C40F] animate-spin" />
                      <p className="text-xs font-bold text-zinc-400">UPLOADING...</p>
                    </div>
                  ) : logoPreview ? (
                    <div className="relative w-full h-full flex items-center justify-center p-4">
                      <NextImage src={logoPreview} alt="Logo Preview" fill className="object-contain" />
                      <div className="absolute inset-0 bg-black/50 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                        <p className="text-xs font-bold text-white">CLICK TO CHANGE</p>
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-center gap-4 text-zinc-500 group-hover:text-zinc-300 transition-all">
                      <div className="w-10 h-10 bg-zinc-900/50 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform border border-white/5">
                        <Upload size={20} className="text-[#F1C40F]" />
                      </div>
                      <div>
                        <p className="text-xs font-bold">UPLOAD LOGO</p>
                        <p className="text-[9px] text-zinc-600">JPEG, PNG, WebP (max 5MB)</p>
                      </div>
                    </div>
                  )}
                </div>
                {logoError && <p className="text-red-400 text-xs">{logoError}</p>}
              </div>

              <div className="pt-6 flex gap-4">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="flex-1 py-4 bg-white/5 hover:bg-white/10 text-white rounded-2xl font-black uppercase tracking-widest text-[10px] transition-all border border-white/5"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createGymMutation.isPending}
                  className="flex-[2] py-4 bg-[#F1C40F] hover:bg-[#F1C40F]/90 !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] transition-all shadow-xl shadow-[#F1C40F]/20 flex items-center justify-center gap-2"
                >
                  {createGymMutation.isPending ? (
                    <RefreshCw size={18} className="animate-spin" />
                  ) : (
                    "Initialize Branch"
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    )}

      {/* Edit Gym Modal */}
      {editingGym && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="flex flex-col bg-[#121721] border border-white/10 w-full max-w-2xl max-h-[90vh] rounded-[2.5rem] shadow-2xl animate-in fade-in zoom-in duration-300 overflow-hidden">
            {/* FIXED HEADER */}
            <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
              <div>
                <h2 className="text-3xl font-black text-white tracking-tighter italic uppercase">
                  Edit Branch Specifications
                </h2>
                <p className="text-zinc-500 text-[10px] font-black uppercase tracking-[0.2em] mt-1">
                  Update Facility Protocols
                </p>
              </div>
              <button
                onClick={() => {
                  setEditingGym(null);
                  resetForm();
                }}
                className="p-3 hover:bg-white/5 rounded-2xl transition-colors text-zinc-500 hover:text-white"
              >
                <X size={24} />
              </button>
            </div>

            {/* SCROLLABLE CONTENT */}
            <div className="flex-1 overflow-y-auto amirani-scrollbar">
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  updateGymMutation.mutate({ ...formData, logoUrl: logoUrl || undefined });
                }}
                className="p-8 space-y-6"
              >
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-2">
                  <label className="amirani-label">Branch Name</label>
                  <div className="relative">
                    <Building2 className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      required
                      type="text"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="Amirani Elite North"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">Contact Email</label>
                  <div className="relative">
                    <Mail className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      type="email"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="north@amirani.com"
                      value={formData.email}
                      onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">Physical Address</label>
                  <div className="relative">
                    <MapPin className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      required
                      type="text"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="123 Industrial Way"
                      value={formData.address}
                      onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">City/District</label>
                  <div className="relative">
                    <Globe className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      required
                      type="text"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="Tbilisi"
                      value={formData.city}
                      onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">Country</label>
                  <div className="relative">
                    <Info className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      required
                      type="text"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="Georgia"
                      value={formData.country}
                      onChange={(e) => setFormData({ ...formData, country: e.target.value })}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="amirani-label">Contact Phone</label>
                  <div className="relative">
                    <Phone className="absolute left-4 text-zinc-500" size={18} />
                    <input
                      type="tel"
                      className="amirani-input amirani-input-with-icon"
                      placeholder="+995 ..."
                      value={formData.phone}
                      onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    />
                  </div>
                </div>
              </div>

              <div className="space-y-2">
                <label className="amirani-label">Brief Description</label>
                <textarea
                  rows={3}
                  className="amirani-textarea"
                  placeholder="Describe the facility's unique equipment or focus..."
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                />
              </div>

              <div className="space-y-2">
                <label className="amirani-label">Branch Logo</label>
                <div className={`group relative h-32 bg-white/[0.02] border-2 border-dashed rounded-xl flex items-center justify-center transition-all overflow-hidden cursor-pointer ${
                  logoError ? "border-red-500/50" : logoPreview ? "border-green-500/50" : "border-white/10 hover:bg-white/[0.05] hover:border-[#F1C40F]/50"
                }`}>
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,image/gif"
                    className="absolute inset-0 opacity-0 cursor-pointer z-10"
                    disabled={logoUploading}
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) handleLogoUpload(file);
                    }}
                  />
                  {logoUploading ? (
                    <div className="flex items-center gap-3">
                      <RefreshCw size={20} className="text-[#F1C40F] animate-spin" />
                      <p className="text-xs font-bold text-zinc-400">UPLOADING...</p>
                    </div>
                  ) : logoPreview ? (
                    <div className="relative w-full h-full flex items-center justify-center p-4">
                      <NextImage src={logoPreview} alt="Logo Preview" fill className="object-contain" />
                      <div className="absolute inset-0 bg-black/50 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                        <p className="text-xs font-bold text-white">CLICK TO CHANGE</p>
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-center gap-4 text-zinc-500 group-hover:text-zinc-300 transition-all">
                      <div className="w-10 h-10 bg-zinc-900/50 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform border border-white/5">
                        <Upload size={20} className="text-[#F1C40F]" />
                      </div>
                      <div>
                        <p className="text-xs font-bold">UPLOAD LOGO</p>
                        <p className="text-[9px] text-zinc-600">JPEG, PNG, WebP (max 5MB)</p>
                      </div>
                    </div>
                  )}
                </div>
                {logoError && <p className="text-red-400 text-xs">{logoError}</p>}
              </div>

              <div className="pt-6 flex gap-4">
                <button
                  type="button"
                  onClick={() => {
                    setEditingGym(null);
                    resetForm();
                  }}
                  className="flex-1 py-4 bg-white/5 hover:bg-white/10 text-white rounded-2xl font-black uppercase tracking-widest text-[10px] transition-all border border-white/5"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={updateGymMutation.isPending}
                  className="flex-[2] py-4 bg-[#F1C40F] hover:bg-[#F1C40F]/90 !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] transition-all shadow-xl shadow-[#F1C40F]/20 flex items-center justify-center gap-2"
                >
                  {updateGymMutation.isPending ? (
                    <RefreshCw size={18} className="animate-spin" />
                  ) : (
                    "Save Changes"
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    )}
    </div>
  );
}
