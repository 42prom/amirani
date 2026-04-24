"use client";

import { useState, useRef } from "react";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import NextImage from "next/image";
import {
  Package,
  Plus,
  RefreshCw,
  Search,
  Edit2,
  X,
  Check,
  Building2,
  Upload,
  Download,
  AlertTriangle,
} from "lucide-react";

interface ImportError {
  row: number;
  name: string;
  reason: string;
}
import { PageHeader } from "@/components/ui/PageHeader";
import { CustomSelect } from "@/components/ui/Select";
import { useToast } from "@/components/ui/Toast";
import { equipmentCatalogApi, CatalogItem, EquipmentCategory, CreateCatalogItemData } from "@/lib/api";

const CATEGORIES: { value: EquipmentCategory; label: string }[] = [
  { value: "CARDIO", label: "Cardio" },
  { value: "STRENGTH", label: "Strength" },
  { value: "FREE_WEIGHTS", label: "Free Weights" },
  { value: "MACHINES", label: "Machines" },
  { value: "FUNCTIONAL", label: "Functional" },
  { value: "STRETCHING", label: "Stretching" },
  { value: "OTHER", label: "Other" },
];

export default function EquipmentCatalogPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);

  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<string>("");
  const [showModal, setShowModal] = useState(false);
  const [editingItem, setEditingItem] = useState<CatalogItem | null>(null);
  const [importing, setImporting] = useState(false);
  const [importErrors, setIErrors] = useState<ImportError[]>([]);
  const [showImportErrors, setShowImportErrors] = useState(false);
  const [formData, setFormData] = useState<CreateCatalogItemData>({
    name: "",
    category: "OTHER",
    model: "",
  });

  const { data: items, isLoading } = useQuery({
    queryKey: ["equipment-catalog", search, categoryFilter],
    queryFn: () =>
      equipmentCatalogApi.getAll(token!, {
        search: search || undefined,
        category: categoryFilter || undefined,
        activeOnly: false,
      }),
    enabled: !!token,
  });

  const { data: stats } = useQuery({
    queryKey: ["equipment-catalog-stats"],
    queryFn: () => equipmentCatalogApi.getStats(token!),
    enabled: !!token,
  });

  const createMutation = useMutation({
    mutationFn: (data: CreateCatalogItemData) =>
      equipmentCatalogApi.create(data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["equipment-catalog"] });
      queryClient.invalidateQueries({ queryKey: ["equipment-catalog-stats"] });
      closeModal();
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<CreateCatalogItemData> & { isActive?: boolean } }) =>
      equipmentCatalogApi.update(id, data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["equipment-catalog"] });
      queryClient.invalidateQueries({ queryKey: ["equipment-catalog-stats"] });
      closeModal();
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => equipmentCatalogApi.delete(id, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["equipment-catalog"] });
      queryClient.invalidateQueries({ queryKey: ["equipment-catalog-stats"] });
    },
  });

  // Redirect if not super admin
  if (!isSuperAdmin(user?.role)) {
    router.push("/dashboard");
    return null;
  }

  const openCreateModal = () => {
    setEditingItem(null);
    setFormData({ name: "", category: "OTHER" });
    setShowModal(true);
  };

  const openEditModal = (item: CatalogItem) => {
    setEditingItem(item);
    setFormData({
      name: item.name,
      category: item.category,
      brand: item.brand || undefined,
      model: item.model || undefined,
      description: item.description || undefined,
      imageUrl: item.imageUrl || undefined,
    });
    setShowModal(true);
  };

  const closeModal = () => {
    setShowModal(false);
    setEditingItem(null);
    setFormData({ name: "", category: "OTHER", model: "" });
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (editingItem) {
      updateMutation.mutate({ id: editingItem.id, data: formData });
    } else {
      createMutation.mutate(formData);
    }
  };

  const getCategoryColor = (category: EquipmentCategory) => {
    switch (category) {
      case "CARDIO": return "bg-red-500/10 text-red-400 border-red-500/20";
      case "STRENGTH": return "bg-blue-500/10 text-blue-400 border-blue-500/20";
      case "FREE_WEIGHTS": return "bg-purple-500/10 text-purple-400 border-purple-500/20";
      case "MACHINES": return "bg-orange-500/10 text-orange-400 border-orange-500/20";
      case "FUNCTIONAL": return "bg-green-500/10 text-green-400 border-green-500/20";
      case "STRETCHING": return "bg-pink-500/10 text-pink-400 border-pink-500/20";
      default: return "bg-zinc-500/10 text-zinc-400 border-zinc-500/20";
    }
  };

  // ── CSV Helpers ────────────────────────────────────────────────────────────

  const exportCsv = (data: CatalogItem[]) => {
    const headers = ["name", "category", "brand", "model", "description", "imageUrl"];
    const rows = data.map(item => [
      item.name,
      item.category,
      item.brand || "",
      item.model || "",
      item.description || "",
      item.imageUrl || ""
    ]);
    const csvContent = [headers, ...rows].map(e => e.map(v => `"${String(v).replace(/"/g, '""')}"`).join(",")).join("\n");
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.setAttribute("download", "equipment-catalog.csv");
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleImport = async (file: File) => {
    setImporting(true);
    setIErrors([]);
    try {
      const text = await file.text();
      const lines = text.split("\n").map(l => l.trim()).filter(Boolean);
      if (lines.length < 2) throw new Error("CSV file is empty or missing headers");

      const parseRow = (line: string) => {
        const result: string[] = [];
        let cur = ""; let inQ = false;
        for (let i = 0; i < line.length; i++) {
          if (line[i] === '"') { inQ = !inQ; continue; }
          if (line[i] === ',' && !inQ) { result.push(cur); cur = ""; continue; }
          cur += line[i];
        }
        result.push(cur);
        return result;
      };

      const headers = parseRow(lines[0]).map(h => h.toLowerCase().replace(/\s/g, ""));
      const records = lines.slice(1).map(line => {
        const row = parseRow(line);
        const find = (key: string) => row[headers.indexOf(key)]?.trim() || "";
        return {
          name: find("name"),
          category: (find("category") || "OTHER") as EquipmentCategory,
          brand: find("brand"),
          model: find("model"),
          description: find("description"),
          imageUrl: find("imageurl")
        };
      }).filter(r => r.name);

      const res = await equipmentCatalogApi.import(records, token!);
      toast.success(`Successfully imported ${res.imported} items!`);
      queryClient.invalidateQueries({ queryKey: ["equipment-catalog"] });
      queryClient.invalidateQueries({ queryKey: ["equipment-catalog-stats"] });
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : "Failed to import CSV";
      toast.error(msg);
    } finally {
      setImporting(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  };

  return (
    <div className="space-y-8 max-w-[1600px] mx-auto">
      {/* Header */}
      <PageHeader
        title="EQUIPMENT CATALOG"
        description="Manage the global machinery master list for all Amirani facilities"
        icon={<Package size={32} />}
        actions={
          <div className="flex items-center gap-3">
            <input 
              ref={fileRef} 
              type="file" 
              accept=".csv" 
              className="hidden"
              onChange={e => { const f = e.target.files?.[0]; if (f) handleImport(f); }} 
            />
            <button 
              onClick={() => items && exportCsv(items)}
              className="flex items-center gap-2 px-4 py-2.5 bg-zinc-800 hover:bg-zinc-700 text-white text-xs font-bold rounded-xl border border-zinc-700 transition-colors uppercase tracking-widest"
            >
              <Download size={14} /> Export CSV
            </button>
            <button 
              onClick={() => fileRef.current?.click()} 
              disabled={importing}
              className="flex items-center gap-2 px-4 py-2.5 bg-zinc-800 hover:bg-zinc-700 text-white text-xs font-bold rounded-xl border border-zinc-700 transition-colors uppercase tracking-widest disabled:opacity-40"
            >
              {importing ? <RefreshCw size={14} className="animate-spin" /> : <Upload size={14} />}
              Import CSV
            </button>
            <button
              onClick={openCreateModal}
              className="flex items-center gap-2 px-5 py-2.5 bg-[#F1C40F] hover:bg-[#F1C40F]/90 text-black text-xs font-black rounded-xl uppercase tracking-widest transition-colors"
            >
              <Plus size={16} /> Add Equipment
            </button>
          </div>
        }
      />

      {/* Stats */}
      {stats && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-3xl p-6 transition-all duration-500 hover:border-[#F1C40F]/20">
            <div className="absolute top-0 right-0 w-32 h-32 bg-[#F1C40F]/5 blur-3xl -mr-16 -mt-16 group-hover:bg-[#F1C40F]/10 transition-colors" />
            <p className="text-xs font-black text-zinc-500 uppercase tracking-widest">Total Master Items</p>
            <p className="text-4xl font-black text-white mt-2 tracking-tighter">{stats.totalItems}</p>
          </div>
          <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-3xl p-6 transition-all duration-500 hover:border-green-500/20">
            <div className="absolute top-0 right-0 w-32 h-32 bg-green-500/5 blur-3xl -mr-16 -mt-16 group-hover:bg-green-500/10 transition-colors" />
            <p className="text-xs font-black text-zinc-500 uppercase tracking-widest">Active Models</p>
            <p className="text-4xl font-black text-green-400 mt-2 tracking-tighter">{stats.activeItems}</p>
          </div>
          <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-3xl p-6 transition-all duration-500 hover:border-purple-500/20">
            <div className="absolute top-0 right-0 w-32 h-32 bg-purple-500/5 blur-3xl -mr-16 -mt-16 group-hover:bg-purple-500/10 transition-colors" />
            <p className="text-xs font-black text-zinc-500 uppercase tracking-widest">Variation Groups</p>
            <p className="text-4xl font-black text-purple-400 mt-2 tracking-tighter">{stats.byCategory.length}</p>
          </div>
          <div className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-3xl p-6 transition-all duration-500 hover:border-[#F1C40F]/20">
            <div className="absolute top-0 right-0 w-32 h-32 bg-[#F1C40F]/5 blur-3xl -mr-16 -mt-16 group-hover:bg-[#F1C40F]/10 transition-colors" />
            <p className="text-xs font-black text-zinc-500 uppercase tracking-widest">Showing</p>
            <p className="text-4xl font-black text-[#F1C40F] mt-2 tracking-tighter">{(items?.length || 0)} / {stats.totalItems}</p>
          </div>
        </div>
      )}

      {/* CSV hint */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl px-5 py-3 flex items-start gap-3">
        <Upload size={14} className="text-zinc-500 mt-0.5 shrink-0" />
        <p className="text-[11px] text-zinc-500 font-mono">
          CSV columns: <span className="text-zinc-300">name, category, brand, model, description, imageUrl</span>
          &nbsp;— use <span className="text-zinc-300">category</span> values like <span className="text-zinc-300">CARDIO, STRENGTH, FREE_WEIGHTS</span>.
        </p>
      </div>

      {/* Import errors panel */}
      {importErrors.length > 0 && (
        <div className="bg-yellow-500/5 border border-yellow-500/20 rounded-xl overflow-hidden">
          <button
            onClick={() => setShowImportErrors(v => !v)}
            className="w-full flex items-center justify-between px-5 py-3 text-left"
          >
            <div className="flex items-center gap-2">
              <AlertTriangle size={14} className="text-yellow-400" />
              <span className="text-[11px] font-black uppercase tracking-widest text-yellow-400">
                {importErrors.length} row{importErrors.length !== 1 ? "s" : ""} skipped during import
              </span>
            </div>
            <span className="text-[10px] text-zinc-500 uppercase tracking-widest">
              {showImportErrors ? "Hide" : "Show"} details
            </span>
          </button>
          {showImportErrors && (
            <div className="border-t border-yellow-500/10 divide-y divide-yellow-500/5">
              {importErrors.map((err, i) => (
                <div key={i} className="flex items-center gap-4 px-5 py-2">
                  <span className="text-[10px] text-zinc-600 font-mono w-12 shrink-0">Row {err.row}</span>
                  <span className="text-[11px] text-zinc-300 flex-1 truncate">{err.name}</span>
                  <span className="text-[10px] text-yellow-500">{err.reason}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Control Bar */}
      <div className="flex flex-col lg:flex-row gap-4 items-stretch lg:items-center">
        <div className="relative group flex-1">
          <div className="absolute inset-0 bg-[#F1C40F]/5 blur-2xl opacity-0 group-focus-within:opacity-100 transition-opacity duration-500 pointer-events-none" />
          <Search className="absolute left-5 text-zinc-600 group-focus-within:text-[#F1C40F] transition-colors pointer-events-none" size={20} />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search equipment..."
            className="amirani-input amirani-input-with-icon font-medium"
          />
        </div>
        <div className="flex gap-4">
          <CustomSelect
            value={categoryFilter}
            onChange={(value) => setCategoryFilter(value)}
            options={[
              { value: "", label: "ALL CLASSIFICATIONS" },
              ...CATEGORIES
            ]}
            className="w-64"
          />
          <button 
            onClick={() => queryClient.invalidateQueries({ queryKey: ["equipment-catalog"] })}
            className="amirani-input !w-[48px] !p-0 flex items-center justify-center !bg-zinc-900 shadow-inner group"
          >
            <RefreshCw size={18} className={`text-zinc-500 group-hover:text-[#F1C40F] transition-all ${isLoading ? "animate-spin" : ""}`} />
          </button>
        </div>
      </div>

      {/* Catalog Grid */}
      <div className="relative min-h-[400px]">
        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-24 gap-4">
            <RefreshCw className="animate-spin text-[#F1C40F]" size={40} />
            <p className="text-zinc-500 font-bold uppercase tracking-widest animate-pulse">Synchronizing Catalog</p>
          </div>
        ) : !items || items.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 bg-[#121721] border border-white/5 rounded-3xl border-dashed">
            <Package className="text-zinc-800 mb-6" size={64} />
            <p className="text-zinc-500 font-bold text-lg">No master items detected</p>
            <button
              onClick={openCreateModal}
              className="mt-6 text-[#F1C40F] font-bold text-sm tracking-widest hover:underline uppercase"
            >
              Initialize First Entry
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-6">
            {items.map((item) => (
              <div
                key={item.id}
                className={`group relative bg-zinc-900/40 backdrop-blur-xl rounded-3xl border border-white/5 overflow-hidden transition-all duration-500 hover:border-[#F1C40F]/30 hover:shadow-2xl hover:shadow-black/50 ${
                  !item.isActive && "grayscale opacity-60"
                }`}
              >
                {/* Visual Area */}
                <div className="relative h-64 overflow-hidden bg-zinc-950">
                  {item.imageUrl ? (
                    <NextImage
                      src={item.imageUrl}
                      alt={item.name}
                      fill
                      className="object-cover group-hover:scale-110 transition-transform duration-700"
                    />
                  ) : (
                    <div className="w-full h-full flex flex-col items-center justify-center text-zinc-800">
                      <Package size={64} className="group-hover:scale-110 transition-transform duration-500" />
                      <span className="text-[10px] font-black uppercase tracking-tighter mt-2 opacity-50">Image Missing</span>
                    </div>
                  )}
                  <div className="absolute inset-x-0 bottom-0 h-1/2 bg-gradient-to-t from-zinc-900 to-transparent" />
                  
                  {/* Category Chip */}
                  <div className="absolute top-4 left-4">
                    <span className={`px-3 py-1.5 rounded-xl border text-[10px] font-black uppercase tracking-widest backdrop-blur-md shadow-2xl ${getCategoryColor(item.category)}`}>
                      {item.category.replace("_", " ")}
                    </span>
                  </div>

                  {/* Deployments Badge */}
                  <div className="absolute bottom-4 right-4 flex items-center gap-2 px-3 py-1.5 bg-black/60 backdrop-blur-md border border-white/10 rounded-xl text-white text-[10px] font-black uppercase tracking-widest transition-transform group-hover:-translate-y-1">
                    <Building2 size={12} className="text-[#F1C40F]" />
                    {item._count?.gymEquipment || 0} DEPLOYMENTS
                  </div>
                </div>

                {/* Info Area */}
                <div className="p-6 pb-20">
                  <div className="flex items-start justify-between mb-3">
                    <h3 className="text-xl font-bold text-white tracking-tight group-hover:text-[#F1C40F] transition-colors">{item.name}</h3>
                  </div>

                  {(item.brand || item.model) && (
                    <p className="text-xs font-black text-[#F1C40F] uppercase tracking-[0.2em] mb-3">
                      {item.brand}{item.brand && item.model && " • "}{item.model}
                    </p>
                  )}

                  <p className="text-sm text-zinc-500 leading-relaxed line-clamp-2 italic">
                    {item.description || "System metadata for high-performance industrial equipment. Optimized for amirani global specifications."}
                  </p>

                  {/* Actions Layer */}
                  <div className="absolute inset-x-0 bottom-0 p-4 border-t border-white/5 flex gap-3 transition-all">
                    <button
                      onClick={() => openEditModal(item)}
                      className="flex-1 py-3 bg-white/5 hover:bg-white/10 text-white rounded-2xl flex items-center justify-center gap-2 transition-all font-bold text-xs uppercase tracking-widest border border-white/5"
                    >
                      <Edit2 size={14} />
                      CONFIGURE
                    </button>
                    <button
                      onClick={() => updateMutation.mutate({ id: item.id, data: { isActive: !item.isActive } })}
                      className={`flex-1 py-3 rounded-2xl flex items-center justify-center gap-2 transition-all font-bold text-xs uppercase tracking-widest border shadow-xl ${
                        item.isActive
                          ? "bg-red-500/10 text-red-400 border-red-500/20 hover:bg-red-500/20"
                          : "bg-green-500/10 text-green-400 border-green-500/20 hover:bg-green-500/20"
                      }`}
                    >
                      {item.isActive ? (
                        <>
                          <X size={14} />
                          RETIRE
                        </>
                      ) : (
                        <>
                          <Check size={14} />
                          REACTIVATE
                        </>
                      )}
                    </button>
                  </div>
                </div>

                {/* Delete Button (Hidden by default) */}
                {(item._count?.gymEquipment === 0) && (
                  <button
                    onClick={() => {
                        if (confirm(`Irreversibly wipe "${item.name}" from the global master catalog?`)) {
                            deleteMutation.mutate(item.id);
                        }
                    }}
                    className="absolute top-4 right-4 p-2 bg-black/40 hover:bg-red-500 text-white/50 hover:text-white rounded-xl transition-all opacity-0 group-hover:opacity-100 backdrop-blur-md border border-white/10"
                  >
                    <X size={14} />
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Modern Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/95 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-500">
          <div className="bg-[#121721] border border-white/10 rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-hidden shadow-[0_0_100px_rgba(0,0,0,0.8)]">
            <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/[0.02]">
              <div>
                <h2 className="text-2xl font-bold text-white tracking-tight uppercase">
                  {editingItem ? "Update Master Asset" : "Register Master Asset"}
                </h2>
                <p className="text-zinc-500 text-[10px] font-bold tracking-widest uppercase mt-1">Catalog Synchronization Protocol</p>
              </div>
              <button 
                onClick={closeModal} 
                className="p-2.5 bg-white/5 text-zinc-500 hover:text-white hover:bg-red-500/80 rounded-xl transition-all border border-white/5"
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-8 space-y-6 overflow-y-auto max-h-[calc(90vh-140px)] amirani-scrollbar">
              {(createMutation.error || updateMutation.error) && (
                <div className="bg-red-500/10 border border-red-500/30 rounded-2xl p-4 text-red-400 text-xs font-black uppercase tracking-widest animate-in shake duration-300">
                  {((createMutation.error || updateMutation.error) as Error).message}
                </div>
              )}

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="md:col-span-2">
                  <label className="amirani-label">Asset Designation *</label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    required
                    className="amirani-input"
                    placeholder="e.g., PRECISION OLYMPIC TREADMILL X"
                  />
                </div>

                <div>
                  <CustomSelect
                    label="Classification"
                    value={formData.category || ""}
                    onChange={(value) => setFormData({ ...formData, category: value as EquipmentCategory })}
                    options={CATEGORIES}
                  />
                </div>

                <div>
                  <label className="amirani-label">Brand Authority</label>
                  <input
                    type="text"
                    value={formData.brand || ""}
                    onChange={(e) => setFormData({ ...formData, brand: e.target.value })}
                    className="amirani-input"
                    placeholder="e.g., TECHNOGYM GLOBAL"
                  />
                </div>

                <div>
                  <label className="amirani-label">Model Designation</label>
                  <input
                    type="text"
                    value={formData.model || ""}
                    onChange={(e) => setFormData({ ...formData, model: e.target.value })}
                    className="amirani-input"
                    placeholder="e.g., SKILLRUN UNITY 7000"
                  />
                </div>

                <div className="md:col-span-2">
                  <label className="amirani-label">Asset Visual (Upload)</label>
                  <div className="group relative h-48 bg-white/[0.02] border-2 border-dashed border-white/10 rounded-xl flex flex-col items-center justify-center transition-all hover:bg-white/[0.05] hover:border-[#F1C40F]/50 group cursor-pointer overflow-hidden backdrop-blur-sm">
                    <input
                        type="file"
                        className="absolute inset-0 opacity-0 cursor-pointer z-10"
                        onChange={(e) => {
                            const file = e.target.files?.[0];
                            if (file) {
                                toast.info(`Bulk import for "${file.name}" is not yet supported.`);
                            }
                        }}
                    />
                    <div className="flex flex-col items-center text-zinc-500 transition-all group-hover:text-zinc-300">
                      <div className="w-12 h-12 bg-zinc-900/50 rounded-xl flex items-center justify-center mb-4 group-hover:scale-110 transition-transform shadow-2xl border border-white/5">
                        <Upload size={24} className="text-[#F1C40F]" />
                      </div>
                      <p className="text-xs font-bold tracking-tight">UPLOAD MASTER ASSET</p>
                      <p className="text-[10px] font-medium uppercase tracking-[0.1em] mt-2 opacity-40">Industrial Resolution Supported</p>
                    </div>
                  </div>
                </div>

                <div className="md:col-span-2">
                  <label className="amirani-label">Asset Specifications</label>
                  <textarea
                    value={formData.description || ""}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    rows={4}
                    className="amirani-textarea"
                    placeholder="Enter detailed equipment performance data and maintenance specifications..."
                  />
                </div>
              </div>

              <div className="flex gap-4 pt-4">
                <button
                  type="button"
                  onClick={closeModal}
                  className="flex-1 py-4 bg-white/5 text-zinc-400 rounded-xl hover:bg-zinc-800 hover:text-white transition-all font-bold uppercase tracking-widest text-[10px] border border-white/5"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createMutation.isPending || updateMutation.isPending || !formData.name}
                  className="flex-1 py-4 bg-[#F1C40F] !text-black rounded-xl hover:bg-[#F1C40F]/90 transition-all disabled:opacity-30 flex items-center justify-center gap-3 font-bold uppercase tracking-tight shadow-2xl shadow-[#F1C40F]/20"
                >
                  {(createMutation.isPending || updateMutation.isPending) ? (
                    <RefreshCw className="animate-spin" size={20} />
                  ) : editingItem ? (
                    "COMMIT CHANGES"
                  ) : (
                    "SYNCHRONIZE TO CORE"
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Custom Scroller Styles */}
    </div>
  );
}
