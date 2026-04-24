"use client";

import { useState, useRef, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { PageHeader } from "@/components/ui/PageHeader";
import { CustomSelect } from "@/components/ui/Select";
import { useToast } from "@/components/ui/Toast";
import {
  Salad, Plus, Search, RefreshCw, X, Edit2,
  Download, Upload, Check, ShieldCheck, ChevronLeft, ChevronRight, AlertTriangle,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────

type FoodCategory = "PROTEIN"|"CARBOHYDRATE"|"FAT"|"VEGETABLE"|"FRUIT"|"DAIRY"|"GRAIN"|"LEGUME"|"NUT_SEED"|"BEVERAGE"|"SUPPLEMENT"|"OTHER";

interface Ingredient {
  id: string;
  name: string;
  nameKa?: string;
  nameRu?: string;
  brand?: string;
  barcode?: string;
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
  fiber?: number;
  sugar?: number;
  sodium?: number;
  foodCategory?: FoodCategory;
  isVerified: boolean;
  source: string;
  createdAt: string;
}

interface IngredientStats {
  total: number;
  verified: number;
  byCategory: { category: string; count: number }[];
}

interface FormState {
  name: string; nameKa: string; nameRu: string;
  brand: string; barcode: string;
  calories: string; protein: string; carbs: string; fats: string;
  fiber: string; sugar: string; sodium: string;
  foodCategory: string;
}

interface ImportError {
  row: number;
  name: string;
  reason: string;
}

// ─── Constants ────────────────────────────────────────────────────────────────

const PAGE_SIZE = 50;

const FOOD_CATEGORIES: { value: FoodCategory; label: string }[] = [
  { value: "PROTEIN",      label: "Protein" },
  { value: "CARBOHYDRATE", label: "Carbohydrate" },
  { value: "FAT",          label: "Fat" },
  { value: "VEGETABLE",    label: "Vegetable" },
  { value: "FRUIT",        label: "Fruit" },
  { value: "DAIRY",        label: "Dairy" },
  { value: "GRAIN",        label: "Grain" },
  { value: "LEGUME",       label: "Legume" },
  { value: "NUT_SEED",     label: "Nut & Seed" },
  { value: "BEVERAGE",     label: "Beverage" },
  { value: "SUPPLEMENT",   label: "Supplement" },
  { value: "OTHER",        label: "Other" },
];

const CATEGORY_COLOR: Record<string, string> = {
  PROTEIN:      "bg-red-500/10 text-red-400 border-red-500/20",
  CARBOHYDRATE: "bg-yellow-500/10 text-yellow-400 border-yellow-500/20",
  FAT:          "bg-orange-500/10 text-orange-400 border-orange-500/20",
  VEGETABLE:    "bg-green-500/10 text-green-400 border-green-500/20",
  FRUIT:        "bg-pink-500/10 text-pink-400 border-pink-500/20",
  DAIRY:        "bg-blue-500/10 text-blue-400 border-blue-500/20",
  GRAIN:        "bg-amber-500/10 text-amber-400 border-amber-500/20",
  LEGUME:       "bg-lime-500/10 text-lime-400 border-lime-500/20",
  NUT_SEED:     "bg-teal-500/10 text-teal-400 border-teal-500/20",
  BEVERAGE:     "bg-cyan-500/10 text-cyan-400 border-cyan-500/20",
  SUPPLEMENT:   "bg-purple-500/10 text-purple-400 border-purple-500/20",
  OTHER:        "bg-zinc-500/10 text-zinc-400 border-zinc-500/20",
};

const BLANK: FormState = {
  name: "", nameKa: "", nameRu: "", brand: "", barcode: "",
  calories: "", protein: "", carbs: "", fats: "",
  fiber: "", sugar: "", sodium: "", foodCategory: "OTHER",
};

// ─── CSV helpers ──────────────────────────────────────────────────────────────

function exportCsv(items: Ingredient[]) {
  const headers = ["name","nameKa","nameRu","brand","barcode","calories","protein","carbs","fats","fiber","sugar","sodium","foodCategory","isVerified"];
  const rows = items.map(i => [
    i.name, i.nameKa ?? "", i.nameRu ?? "", i.brand ?? "", i.barcode ?? "",
    i.calories, i.protein, i.carbs, i.fats,
    i.fiber ?? "", i.sugar ?? "", i.sodium ?? "",
    i.foodCategory ?? "OTHER", i.isVerified ? "true" : "false",
  ]);
  const csv = [headers, ...rows].map(r => r.map(v => `"${String(v).replace(/"/g,'""')}"`).join(",")).join("\n");
  const blob = new Blob([csv], { type: "text/csv" });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement("a"); a.href = url; a.download = "ingredient-database.csv"; a.click();
  URL.revokeObjectURL(url);
}

function parseCsvRow(line: string): string[] {
  const result: string[] = [];
  let current = ""; let inQuote = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuote && line[i + 1] === '"') { current += '"'; i++; }
      else { inQuote = !inQuote; }
      continue;
    }
    if (ch === "," && !inQuote) { result.push(current.trim()); current = ""; continue; }
    current += ch;
  }
  result.push(current.trim());
  return result;
}

const num = (v: string) => v ? parseFloat(v) : undefined;

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function IngredientDatabasePage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);

  const [search, setSearch]         = useState("");
  const [catFilter, setCatFilter]   = useState("");
  const [verFilter, setVerFilter]   = useState("");
  const [page, setPage]             = useState(0);
  const [showModal, setShowModal]   = useState(false);
  const [editing, setEditing]       = useState<Ingredient | null>(null);
  const [form, setForm]             = useState<FormState>(BLANK);
  const [formError, setFormError]   = useState("");
  const [nameLang, setNameLang]     = useState<"en"|"ka"|"ru">("en");
  const [importing, setImporting]   = useState(false);
  const [importErrors, setImportErrors] = useState<ImportError[]>([]);
  const [showImportErrors, setShowImportErrors] = useState(false);

  useEffect(() => {
    if (user && !isSuperAdmin(user?.role)) router.push("/dashboard");
  }, [user, router]);

  useEffect(() => { setPage(0); }, [search, catFilter, verFilter]);

  // ── Queries ────────────────────────────────────────────────────────────────

  const { data: ingredients, isLoading } = useQuery<Ingredient[]>({
    queryKey: ["ingredient-db", search, catFilter, verFilter],
    queryFn: () => {
      const params = new URLSearchParams();
      if (search)    params.set("q",        search);
      if (catFilter) params.set("category", catFilter);
      if (verFilter === "verified")   params.set("verified", "true");
      if (verFilter === "unverified") params.set("verified", "false");
      const qs = params.toString();
      return api<{ ingredients: Ingredient[] }>(`/admin/ingredient-library${qs ? `?${qs}` : ""}`, { token: token! })
        .then(r => (r as { ingredients: Ingredient[] }).ingredients ?? r as unknown as Ingredient[]);
    },
    enabled: !!token,
  });

  const { data: stats } = useQuery<IngredientStats>({
    queryKey: ["ingredient-db-stats"],
    queryFn: () => api<IngredientStats>("/admin/ingredient-library/stats", { token: token! }),
    enabled: !!token,
  });

  // ── Mutations ──────────────────────────────────────────────────────────────

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["ingredient-db"] });
    queryClient.invalidateQueries({ queryKey: ["ingredient-db-stats"] });
  };

  const createMutation = useMutation({
    mutationFn: (data: object) => api("/admin/ingredient-library", { method: "POST", body: data, token: token! }),
    onSuccess: () => { invalidate(); closeModal(); toast.success("Ingredient added."); },
    onError: (e: Error) => toast.error(e.message),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: object }) =>
      api(`/admin/ingredient-library/${id}`, { method: "PATCH", body: data, token: token! }),
    onSuccess: () => { invalidate(); closeModal(); toast.success("Ingredient updated."); },
    onError: (e: Error) => toast.error(e.message),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api(`/admin/ingredient-library/${id}`, { method: "DELETE", token: token! }),
    onSuccess: () => { invalidate(); toast.success("Ingredient removed."); },
    onError: (e: Error) => toast.error(e.message),
  });

  const verifyMutation = useMutation({
    mutationFn: (id: string) => api(`/admin/ingredient-library/${id}/verify`, { method: "PATCH", token: token! }),
    onSuccess: () => { invalidate(); toast.success("Ingredient verified."); },
    onError: (e: Error) => toast.error(e.message),
  });

  // ── Modal ──────────────────────────────────────────────────────────────────

  const openCreate = () => { setEditing(null); setForm(BLANK); setFormError(""); setNameLang("en"); setShowModal(true); };
  const openEdit = (ing: Ingredient) => {
    setEditing(ing);
    setFormError("");
    setForm({
      name: ing.name, nameKa: ing.nameKa ?? "", nameRu: ing.nameRu ?? "",
      brand: ing.brand ?? "", barcode: ing.barcode ?? "",
      calories: String(ing.calories), protein: String(ing.protein),
      carbs: String(ing.carbs), fats: String(ing.fats),
      fiber: ing.fiber != null ? String(ing.fiber) : "",
      sugar: ing.sugar != null ? String(ing.sugar) : "",
      sodium: ing.sodium != null ? String(ing.sodium) : "",
      foodCategory: ing.foodCategory ?? "OTHER",
    });
    setShowModal(true);
  };
  const closeModal = () => { setShowModal(false); setEditing(null); setForm(BLANK); setFormError(""); setNameLang("en"); };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError("");

    const trimmedName = form.name.trim();
    if (!trimmedName) { setFormError("English name is required."); return; }
    if (!form.calories || isNaN(parseFloat(form.calories))) { setFormError("Calories is required and must be a number."); return; }
    if (!form.protein || isNaN(parseFloat(form.protein))) { setFormError("Protein is required and must be a number."); return; }
    if (!form.carbs || isNaN(parseFloat(form.carbs))) { setFormError("Carbs is required and must be a number."); return; }
    if (!form.fats || isNaN(parseFloat(form.fats))) { setFormError("Fats is required and must be a number."); return; }

    // Duplicate check for new ingredients
    if (!editing) {
      const nameLower = trimmedName.toLowerCase();
      const duplicate = (ingredients ?? []).find(i => i.name.toLowerCase() === nameLower);
      if (duplicate) { setFormError(`An ingredient named "${duplicate.name}" already exists.`); return; }
    }

    const payload = {
      name: trimmedName,
      nameKa: form.nameKa.trim() || undefined,
      nameRu: form.nameRu.trim() || undefined,
      brand: form.brand.trim() || undefined,
      barcode: form.barcode.trim() || undefined,
      calories: parseFloat(form.calories),
      protein: parseFloat(form.protein),
      carbs: parseFloat(form.carbs),
      fats: parseFloat(form.fats),
      fiber: num(form.fiber),
      sugar: num(form.sugar),
      sodium: num(form.sodium),
      foodCategory: form.foodCategory || undefined,
      source: "ADMIN",
    };
    if (editing) updateMutation.mutate({ id: editing.id, data: payload });
    else createMutation.mutate(payload);
  };

  // ── CSV Import ─────────────────────────────────────────────────────────────

  const handleImport = async (file: File) => {
    setImporting(true);
    setImportErrors([]);
    setShowImportErrors(false);
    try {
      const text = await file.text();
      const lines = text.trim().split("\n");
      if (lines.length < 2) { toast.error("CSV is empty or has no data rows."); return; }

      const headers = parseCsvRow(lines[0]).map(h => h.toLowerCase().replace(/\s/g, ""));
      const idx = (key: string) => headers.indexOf(key);

      const existingNames = new Set((ingredients ?? []).map(i => i.name.toLowerCase()));
      const seenInFile = new Set<string>();
      const errors: ImportError[] = [];
      const records: object[] = [];

      lines.slice(1).forEach((line, i) => {
        const rowNum = i + 2;
        const r = parseCsvRow(line);
        if (r.length <= 1 && !r[0]) return;

        const name = r[idx("name")]?.trim();
        if (!name) {
          errors.push({ row: rowNum, name: "(blank)", reason: "Missing name" });
          return;
        }

        const nameLower = name.toLowerCase();
        if (existingNames.has(nameLower)) {
          errors.push({ row: rowNum, name, reason: "Already exists in database" });
          return;
        }
        if (seenInFile.has(nameLower)) {
          errors.push({ row: rowNum, name, reason: "Duplicate within this CSV file" });
          return;
        }

        const calsRaw = r[idx("calories")] || "";
        const protRaw = r[idx("protein")] || "";
        const carbRaw = r[idx("carbs")] || "";
        const fatsRaw = r[idx("fats")] || "";
        if (!calsRaw || isNaN(parseFloat(calsRaw))) {
          errors.push({ row: rowNum, name, reason: "Invalid or missing calories" });
          return;
        }
        if (!protRaw || isNaN(parseFloat(protRaw))) {
          errors.push({ row: rowNum, name, reason: "Invalid or missing protein" });
          return;
        }
        if (!carbRaw || isNaN(parseFloat(carbRaw))) {
          errors.push({ row: rowNum, name, reason: "Invalid or missing carbs" });
          return;
        }
        if (!fatsRaw || isNaN(parseFloat(fatsRaw))) {
          errors.push({ row: rowNum, name, reason: "Invalid or missing fats" });
          return;
        }

        seenInFile.add(nameLower);
        records.push({
          name,
          nameKa:       r[idx("nameka")] || undefined,
          nameRu:       r[idx("nameru")] || undefined,
          brand:        r[idx("brand")] || undefined,
          barcode:      r[idx("barcode")] || undefined,
          calories:     parseFloat(calsRaw),
          protein:      parseFloat(protRaw),
          carbs:        parseFloat(carbRaw),
          fats:         parseFloat(fatsRaw),
          fiber:        num(r[idx("fiber")]),
          sugar:        num(r[idx("sugar")]),
          sodium:       num(r[idx("sodium")]),
          foodCategory: r[idx("foodcategory")] || "OTHER",
          isVerified:   r[idx("isverified")] === "true",
          source:       "ADMIN",
        });
      });

      if (errors.length > 0) {
        setImportErrors(errors);
        setShowImportErrors(true);
      }

      if (records.length === 0) {
        toast.error("No valid rows to import.");
        return;
      }

      await api("/admin/ingredient-library/import", {
        method: "POST", body: { records }, token: token!,
      });
      invalidate();
      toast.success(`Imported ${records.length} ingredient${records.length !== 1 ? "s" : ""}${errors.length > 0 ? ` (${errors.length} skipped)` : ""}.`);
    } catch (e: unknown) {
      toast.error(e instanceof Error ? e.message : "Import failed. Check CSV format.");
    } finally {
      setImporting(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  };

  // ── Filtered + paginated list ──────────────────────────────────────────────

  // Filtering is done server-side via query params
  const filtered = ingredients ?? [];

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const safePage   = Math.min(page, totalPages - 1);
  const paginated  = filtered.slice(safePage * PAGE_SIZE, (safePage + 1) * PAGE_SIZE);

  return (
    <div className="space-y-8 max-w-[1600px] mx-auto">
      <PageHeader
        title="INGREDIENT DATABASE"
        description="Global food & ingredient library — manage macros, translations, and verification status"
        icon={<Salad size={32} />}
        actions={
          <div className="flex items-center gap-3">
            <input ref={fileRef} type="file" accept=".csv" className="hidden"
              onChange={e => { const f = e.target.files?.[0]; if (f) handleImport(f); }} />
            <button onClick={() => ingredients && exportCsv(ingredients)}
              className="flex items-center gap-2 px-4 py-2.5 bg-zinc-800 hover:bg-zinc-700 text-white text-xs font-bold rounded-xl border border-zinc-700 transition-colors uppercase tracking-widest">
              <Download size={14} /> Export CSV
            </button>
            <button onClick={() => fileRef.current?.click()} disabled={importing}
              className="flex items-center gap-2 px-4 py-2.5 bg-zinc-800 hover:bg-zinc-700 text-white text-xs font-bold rounded-xl border border-zinc-700 transition-colors uppercase tracking-widest disabled:opacity-40">
              {importing ? <RefreshCw size={14} className="animate-spin" /> : <Upload size={14} />}
              Import CSV
            </button>
            <button onClick={openCreate}
              className="flex items-center gap-2 px-5 py-2.5 bg-[#F1C40F] hover:bg-[#F1C40F]/90 text-black text-xs font-black rounded-xl uppercase tracking-widest transition-colors">
              <Plus size={16} /> Add Ingredient
            </button>
          </div>
        }
      />

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: "Total Items",    value: stats?.total ?? 0,    color: "text-white" },
          { label: "Verified",       value: stats?.verified ?? 0, color: "text-green-400" },
          { label: "Unverified",     value: (stats?.total ?? 0) - (stats?.verified ?? 0), color: "text-yellow-400" },
          { label: "Categories",     value: stats?.byCategory?.length ?? 0, color: "text-purple-400" },
        ].map(s => (
          <div key={s.label} className="bg-[#121721] border border-white/5 rounded-2xl p-5">
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">{s.label}</p>
            <p className={`text-3xl font-black mt-1 tracking-tighter ${s.color}`}>{s.value}</p>
          </div>
        ))}
      </div>

      {/* CSV format hint */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl px-5 py-3 flex items-start gap-3">
        <Upload size={14} className="text-zinc-500 mt-0.5 shrink-0" />
        <p className="text-[11px] text-zinc-500 font-mono">
          CSV columns: <span className="text-zinc-300">name, nameKa, nameRu, brand, barcode, calories*, protein*, carbs*, fats*, fiber, sugar, sodium, foodCategory, isVerified</span>
          &nbsp;— values per 100g · * required
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

      {/* Filters */}
      <div className="flex flex-col lg:flex-row gap-4">
        <div className="relative flex-1">
          <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500 pointer-events-none" />
          <input value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search ingredients..."
            className="amirani-input amirani-input-with-icon" />
        </div>
        <CustomSelect value={catFilter} onChange={setCatFilter} className="w-52"
          options={[{ value: "", label: "All Categories" }, ...FOOD_CATEGORIES]} />
        <CustomSelect value={verFilter} onChange={setVerFilter} className="w-44"
          options={[{ value: "", label: "All Status" }, { value: "verified", label: "✓ Verified" }, { value: "unverified", label: "⚠ Unverified" }]} />
        <button onClick={() => queryClient.invalidateQueries({ queryKey: ["ingredient-db"] })}
          className="amirani-input !w-[48px] !p-0 flex items-center justify-center !bg-zinc-900 group">
          <RefreshCw size={16} className={`text-zinc-500 group-hover:text-[#F1C40F] transition-colors ${isLoading ? "animate-spin" : ""}`} />
        </button>
      </div>

      {/* Table */}
      <div className="bg-[#121721] border border-white/5 rounded-2xl overflow-hidden">
        <div className="grid grid-cols-[2fr_1fr_repeat(4,_0.7fr)_auto] gap-0 px-6 py-3 border-b border-white/5 text-[10px] font-black uppercase tracking-widest text-zinc-600">
          <span>Ingredient</span><span>Category</span><span>Cal</span><span>Prot</span><span>Carbs</span><span>Fats</span><span>Actions</span>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center py-16 text-zinc-500">
            <RefreshCw size={20} className="animate-spin mr-2" /> Loading…
          </div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-zinc-600 gap-3">
            <Salad size={40} />
            <p className="text-sm font-bold">No ingredients found</p>
            <button onClick={openCreate} className="text-[#F1C40F] text-xs hover:underline">Add first ingredient →</button>
          </div>
        ) : (
          <div className="divide-y divide-white/[0.04]">
            {paginated.map(ing => (
              <div key={ing.id}
                className="grid grid-cols-[2fr_1fr_repeat(4,_0.7fr)_auto] gap-0 px-6 py-3.5 hover:bg-white/[0.02] transition-colors items-center">
                {/* Name + translations */}
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-white">{ing.name}</p>
                    {ing.isVerified && <ShieldCheck size={12} className="text-green-400 shrink-0" />}
                  </div>
                  <div className="flex items-center gap-2 mt-0.5">
                    {ing.nameKa && <span className="text-[10px] text-zinc-500">🇬🇪 {ing.nameKa}</span>}
                    {ing.nameRu && <span className="text-[10px] text-zinc-500">🇷🇺 {ing.nameRu}</span>}
                    {!ing.nameKa && !ing.nameRu && <span className="text-[10px] text-zinc-700 italic">No translations</span>}
                    {ing.brand && <span className="text-[10px] text-zinc-600">· {ing.brand}</span>}
                  </div>
                </div>
                {/* Category */}
                <span className={`inline-flex w-fit px-2 py-0.5 rounded-lg border text-[10px] font-black uppercase ${CATEGORY_COLOR[ing.foodCategory ?? "OTHER"]}`}>
                  {(ing.foodCategory ?? "OTHER").replace(/_/g," ")}
                </span>
                {/* Macros */}
                <span className="text-xs text-zinc-300 font-mono">{ing.calories}</span>
                <span className="text-xs text-red-400 font-mono">{ing.protein}g</span>
                <span className="text-xs text-yellow-400 font-mono">{ing.carbs}g</span>
                <span className="text-xs text-orange-400 font-mono">{ing.fats}g</span>
                {/* Actions */}
                <div className="flex items-center gap-1">
                  {!ing.isVerified && (
                    <button onClick={() => verifyMutation.mutate(ing.id)}
                      title="Verify"
                      className="p-1.5 rounded-lg hover:bg-green-500/10 text-zinc-600 hover:text-green-400 transition-colors">
                      <Check size={13}/>
                    </button>
                  )}
                  <button onClick={() => openEdit(ing)}
                    className="p-1.5 rounded-lg hover:bg-zinc-800 text-zinc-500 hover:text-[#F1C40F] transition-colors">
                    <Edit2 size={13}/>
                  </button>
                  <button onClick={() => { if (confirm(`Delete "${ing.name}"?`)) deleteMutation.mutate(ing.id); }}
                    className="p-1.5 rounded-lg hover:bg-red-500/10 text-zinc-700 hover:text-red-400 transition-colors">
                    <X size={12}/>
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Pagination footer */}
        {filtered.length > 0 && (
          <div className="px-6 py-4 border-t border-white/5 flex items-center justify-between">
            <p className="text-[11px] text-zinc-500">
              Showing <span className="text-white font-bold">{safePage * PAGE_SIZE + 1}–{Math.min((safePage + 1) * PAGE_SIZE, filtered.length)}</span> of <span className="text-white font-bold">{filtered.length}</span> ingredients
            </p>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setPage(p => Math.max(0, p - 1))}
                disabled={safePage === 0}
                className="p-1.5 rounded-lg hover:bg-zinc-800 text-zinc-500 hover:text-white disabled:opacity-30 disabled:cursor-not-allowed transition-colors">
                <ChevronLeft size={16} />
              </button>
              <span className="text-[11px] text-zinc-400 font-mono px-2">
                {safePage + 1} / {totalPages}
              </span>
              <button
                onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))}
                disabled={safePage >= totalPages - 1}
                className="p-1.5 rounded-lg hover:bg-zinc-800 text-zinc-500 hover:text-white disabled:opacity-30 disabled:cursor-not-allowed transition-colors">
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/90 backdrop-blur-md flex items-center justify-center z-50 p-4">
          <div className="bg-[#121721] border border-white/10 rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-hidden shadow-2xl">
            <div className="p-6 border-b border-white/5 flex items-center justify-between">
              <div>
                <h2 className="text-lg font-black text-white uppercase tracking-tight">
                  {editing ? "Edit Ingredient" : "Add Ingredient"}
                </h2>
                <p className="text-[10px] text-zinc-500 uppercase tracking-widest mt-0.5">Values per 100g</p>
              </div>
              <button onClick={closeModal} className="p-2 hover:bg-zinc-800 text-zinc-500 hover:text-white rounded-xl transition-colors">
                <X size={18}/>
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-5 overflow-y-auto max-h-[calc(90vh-88px)] amirani-scrollbar">
              {/* Form error */}
              {formError && (
                <div className="flex items-center gap-2 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">
                  <AlertTriangle size={14} className="text-red-400 shrink-0" />
                  <p className="text-xs text-red-400">{formError}</p>
                </div>
              )}

              {/* Names — language tab switcher */}
              <div className="space-y-3">
                <div className="flex gap-1 bg-zinc-800/60 rounded-xl p-1">
                  {([
                    { code: "en", flag: "🇬🇧", label: "English" },
                    { code: "ka", flag: "🇬🇪", label: "Georgian" },
                    { code: "ru", flag: "🇷🇺", label: "Russian" },
                  ] as { code: "en"|"ka"|"ru"; flag: string; label: string }[]).map(t => (
                    <button key={t.code} type="button"
                      onClick={() => setNameLang(t.code)}
                      className={`flex-1 flex items-center justify-center gap-1.5 py-2 rounded-lg text-[11px] font-black uppercase tracking-widest transition-all ${
                        nameLang === t.code
                          ? "bg-[#F1C40F] text-black shadow-sm"
                          : "text-zinc-500 hover:text-white"
                      }`}>
                      <span>{t.flag}</span> {t.label}
                    </button>
                  ))}
                </div>
                {nameLang === "en" && (
                  <div>
                    <label className="amirani-label">English Name *</label>
                    <input value={form.name} onChange={e => setForm({...form, name: e.target.value})}
                      className="amirani-input" placeholder="e.g. Chicken Breast" />
                  </div>
                )}
                {nameLang === "ka" && (
                  <div>
                    <label className="amirani-label">Georgian Name</label>
                    <input value={form.nameKa} onChange={e => setForm({...form, nameKa: e.target.value})}
                      className="amirani-input" placeholder="e.g. წიწილის მკერდი" />
                  </div>
                )}
                {nameLang === "ru" && (
                  <div>
                    <label className="amirani-label">Russian Name</label>
                    <input value={form.nameRu} onChange={e => setForm({...form, nameRu: e.target.value})}
                      className="amirani-input" placeholder="e.g. Куриная грудка" />
                  </div>
                )}
              </div>

              {/* Category */}
              <CustomSelect label="Category" value={form.foodCategory}
                onChange={v => setForm({...form, foodCategory: v})}
                options={FOOD_CATEGORIES} />

              {/* Brand + Barcode */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="amirani-label">Brand <span className="text-zinc-600">(optional)</span></label>
                  <input value={form.brand} onChange={e => setForm({...form, brand: e.target.value})}
                    className="amirani-input" placeholder="e.g. Organic Valley" />
                </div>
                <div>
                  <label className="amirani-label">Barcode <span className="text-zinc-600">(optional)</span></label>
                  <input value={form.barcode} onChange={e => setForm({...form, barcode: e.target.value})}
                    className="amirani-input" placeholder="e.g. 012345678901" />
                </div>
              </div>

              {/* Primary macros */}
              <div>
                <p className="amirani-label mb-3">Macronutrients per 100g *</p>
                <div className="grid grid-cols-4 gap-3">
                  {([
                    ["Calories (kcal)", "calories", "text-white"],
                    ["Protein (g)", "protein", "text-red-400"],
                    ["Carbs (g)", "carbs", "text-yellow-400"],
                    ["Fats (g)", "fats", "text-orange-400"],
                  ] as [string, keyof FormState, string][]).map(([label, key, color]) => (
                    <div key={key}>
                      <label className={`text-[10px] font-black uppercase tracking-widest ${color} block mb-1.5`}>{label}</label>
                      <input type="number" step="0.1" min="0"
                        value={form[key]} onChange={e => setForm({...form, [key]: e.target.value})}
                        className="amirani-input" placeholder="0" />
                    </div>
                  ))}
                </div>
              </div>

              {/* Secondary macros */}
              <div>
                <p className="amirani-label mb-3">Additional Nutrients <span className="text-zinc-600">(optional)</span></p>
                <div className="grid grid-cols-3 gap-3">
                  {([
                    ["Fiber (g)", "fiber"],
                    ["Sugar (g)", "sugar"],
                    ["Sodium (mg)", "sodium"],
                  ] as [string, keyof FormState][]).map(([label, key]) => (
                    <div key={key}>
                      <label className="text-[10px] font-black uppercase tracking-widest text-zinc-500 block mb-1.5">{label}</label>
                      <input type="number" step="0.1" min="0"
                        value={form[key]} onChange={e => setForm({...form, [key]: e.target.value})}
                        className="amirani-input" placeholder="0" />
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <button type="button" onClick={closeModal}
                  className="flex-1 py-3 bg-white/5 text-zinc-400 rounded-xl hover:bg-zinc-800 transition-colors font-bold text-xs uppercase tracking-widest border border-white/5">
                  Cancel
                </button>
                <button type="submit"
                  disabled={createMutation.isPending || updateMutation.isPending}
                  className="flex-1 py-3 bg-[#F1C40F] text-black rounded-xl hover:bg-[#F1C40F]/90 transition-colors disabled:opacity-30 font-black text-xs uppercase tracking-widest flex items-center justify-center gap-2">
                  {(createMutation.isPending || updateMutation.isPending) ? <RefreshCw size={14} className="animate-spin"/> : null}
                  {editing ? "Save Changes" : "Add Ingredient"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
