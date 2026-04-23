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
  Dumbbell, Plus, Search, RefreshCw, X, Edit2, Trash2,
  Download, Upload, ChevronDown, ChevronUp,
  ChevronLeft, ChevronRight, AlertTriangle, Zap, ZapOff,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Difficulty = "BEGINNER" | "INTERMEDIATE" | "ADVANCED";
type Mechanics  = "COMPOUND" | "ISOLATION";
type Force      = "PUSH" | "PULL" | "HINGE" | "SQUAT" | "CARRY" | "STATIC";

interface Exercise {
  id: string;
  name: string;
  nameKa?: string;
  nameRu?: string;
  primaryMuscle: string;
  secondaryMuscles: string[];
  equipment: string[];
  difficulty: Difficulty;
  mechanics: Mechanics;
  force: Force;
  videoUrl?: string;
  cues: string[];
  commonMistakes: string[];
  metValue: number;
  isActive: boolean;
  createdAt: string;
}

interface ExerciseStats {
  total: number;
  active: number;
  byDifficulty: { difficulty: string; count: number }[];
  byMuscle: { muscle: string; count: number }[];
}

interface FormState {
  name: string; nameKa: string; nameRu: string;
  primaryMuscle: string; secondaryMuscles: string; equipment: string;
  difficulty: Difficulty; mechanics: Mechanics; force: Force;
  videoUrl: string; cues: string; commonMistakes: string; metValue: number;
}

interface ImportError { row: number; name: string; reason: string; }

// ─── Constants ────────────────────────────────────────────────────────────────

const PAGE_SIZE = 50;

const MUSCLES = ["CHEST","BACK","SHOULDERS","BICEPS","TRICEPS","FOREARMS","LEGS","QUADS","HAMSTRINGS","GLUTES","CALVES","ABS","FULL_BODY","CARDIO"];

const DIFFICULTIES: Difficulty[] = ["BEGINNER", "INTERMEDIATE", "ADVANCED"];
const MECHANICS_OPTIONS: Mechanics[] = ["COMPOUND", "ISOLATION"];
const FORCE_OPTIONS: Force[] = ["PUSH", "PULL", "HINGE", "SQUAT", "CARRY", "STATIC"];

const BLANK: FormState = {
  name: "", nameKa: "", nameRu: "",
  primaryMuscle: "CHEST", secondaryMuscles: "", equipment: "BODYWEIGHT",
  difficulty: "BEGINNER", mechanics: "COMPOUND", force: "PUSH",
  videoUrl: "", cues: "", commonMistakes: "", metValue: 3.0,
};

const diffColor = (d: string) => ({
  BEGINNER:     "bg-green-500/10 text-green-400 border-green-500/20",
  INTERMEDIATE: "bg-yellow-500/10 text-yellow-400 border-yellow-500/20",
  ADVANCED:     "bg-red-500/10 text-red-400 border-red-500/20",
}[d] ?? "bg-zinc-500/10 text-zinc-400 border-zinc-500/20");

// ─── CSV helpers ──────────────────────────────────────────────────────────────

function exportCsv(exercises: Exercise[]) {
  const headers = ["name","nameKa","nameRu","primaryMuscle","secondaryMuscles","equipment","difficulty","mechanics","force","videoUrl","cues","commonMistakes","metValue"];
  const rows = exercises.map(e => [
    e.name, e.nameKa ?? "", e.nameRu ?? "",
    e.primaryMuscle, e.secondaryMuscles.join("|"), e.equipment.join("|"),
    e.difficulty, e.mechanics, e.force, e.videoUrl ?? "",
    e.cues.join("|"), e.commonMistakes.join("|"), e.metValue,
  ]);
  const csv = [headers, ...rows].map(r => r.map(v => `"${String(v).replace(/"/g,'""')}"`).join(",")).join("\n");
  const blob = new Blob([csv], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a"); a.href = url; a.download = "exercise-database.csv"; a.click();
  URL.revokeObjectURL(url);
}

function parseCsvRow(line: string): string[] {
  const result: string[] = [];
  let current = ""; let inQuote = false;
  for (let i = 0; i < line.length; i++) {
    if (line[i] === '"') { inQuote = !inQuote; continue; }
    if (line[i] === "," && !inQuote) { result.push(current.trim()); current = ""; continue; }
    current += line[i];
  }
  result.push(current.trim());
  return result;
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function ExerciseDatabasePage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);

  const [search, setSearch]         = useState("");
  const [muscleFilter, setMF]       = useState("");
  const [diffFilter, setDF]         = useState("");
  const [page, setPage]             = useState(0);
  const [showModal, setShowModal]   = useState(false);
  const [editing, setEditing]       = useState<Exercise | null>(null);
  const [form, setForm]             = useState<FormState>(BLANK);
  const [formError, setFormError]   = useState<string | null>(null);
  const [nameLang, setNameLang]     = useState<"en"|"ka"|"ru">("en");
  const [importing, setImporting]   = useState(false);
  const [importErrors, setIErrors]  = useState<ImportError[]>([]);
  const [expandedId, setExpanded]   = useState<string | null>(null);

  useEffect(() => {
    if (user && !isSuperAdmin(user?.role)) router.push("/dashboard");
  }, [user, router]);

  // Reset to page 0 when filters change
  useEffect(() => { setPage(0); }, [search, muscleFilter, diffFilter]);

  // ── Queries ────────────────────────────────────────────────────────────────

  const { data: exercises, isLoading } = useQuery<Exercise[]>({
    queryKey: ["exercise-db", search, muscleFilter, diffFilter],
    queryFn: () => {
      const params = new URLSearchParams();
      if (search)      params.set("q",      search);
      if (muscleFilter) params.set("muscle", muscleFilter);
      if (diffFilter)   params.set("diff",   diffFilter);
      const qs = params.toString();
      return api<{ exercises: Exercise[] }>(`/admin/exercise-library${qs ? `?${qs}` : ""}`, { token: token! })
        .then(r => (r as { exercises: Exercise[] }).exercises ?? r as unknown as Exercise[]);
    },
    enabled: !!token,
  });

  const { data: stats } = useQuery<ExerciseStats>({
    queryKey: ["exercise-db-stats"],
    queryFn: () => api<ExerciseStats>("/admin/exercise-library/stats", { token: token! }),
    enabled: !!token,
  });

  // ── Mutations ──────────────────────────────────────────────────────────────

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["exercise-db"] });
    queryClient.invalidateQueries({ queryKey: ["exercise-db-stats"] });
  };

  const createMutation = useMutation({
    mutationFn: (data: object) => api("/admin/exercise-library", { method: "POST", body: data, token: token! }),
    onSuccess: () => { invalidate(); closeModal(); toast.success("Exercise added."); },
    onError: (e: Error) => toast.error(e.message),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: object }) =>
      api(`/admin/exercise-library/${id}`, { method: "PATCH", body: data, token: token! }),
    onSuccess: () => { invalidate(); closeModal(); toast.success("Exercise updated."); },
    onError: (e: Error) => toast.error(e.message),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api(`/admin/exercise-library/${id}`, { method: "DELETE", token: token! }),
    onSuccess: () => { invalidate(); toast.success("Exercise removed."); },
    onError: (e: Error) => toast.error(e.message),
  });

  // ── Modal ──────────────────────────────────────────────────────────────────

  const openCreate = () => { setEditing(null); setForm(BLANK); setFormError(null); setNameLang("en"); setShowModal(true); };
  const openEdit = (ex: Exercise) => {
    setEditing(ex);
    setFormError(null);
    setForm({
      name: ex.name, nameKa: ex.nameKa ?? "", nameRu: ex.nameRu ?? "",
      primaryMuscle: ex.primaryMuscle,
      secondaryMuscles: ex.secondaryMuscles.join(", "),
      equipment: ex.equipment.join(", "),
      difficulty: ex.difficulty, mechanics: ex.mechanics, force: ex.force,
      videoUrl: ex.videoUrl ?? "",
      cues: ex.cues.join("\n"), commonMistakes: ex.commonMistakes.join("\n"),
      metValue: ex.metValue,
    });
    setShowModal(true);
  };
  const closeModal = () => { setShowModal(false); setEditing(null); setForm(BLANK); setFormError(null); setNameLang("en"); };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    // Validation
    if (!form.name.trim()) { setFormError("Exercise name is required."); return; }
    if (!form.primaryMuscle) { setFormError("Primary muscle is required."); return; }
    if (!form.difficulty) { setFormError("Difficulty is required."); return; }
    if (!form.mechanics) { setFormError("Mechanics is required."); return; }
    if (!form.force) { setFormError("Force pattern is required."); return; }
    if (isNaN(form.metValue) || form.metValue < 1) { setFormError("MET value must be at least 1."); return; }

    // Duplicate check (create only)
    if (!editing) {
      const exists = (exercises ?? []).some(ex => ex.name.toLowerCase() === form.name.trim().toLowerCase());
      if (exists) { setFormError(`An exercise named "${form.name.trim()}" already exists.`); return; }
    }

    const payload = {
      name: form.name.trim(),
      nameKa: form.nameKa.trim() || undefined,
      nameRu: form.nameRu.trim() || undefined,
      primaryMuscle: form.primaryMuscle,
      secondaryMuscles: form.secondaryMuscles.split(",").map(s => s.trim()).filter(Boolean),
      equipment: form.equipment.split(",").map(s => s.trim()).filter(Boolean),
      difficulty: form.difficulty, mechanics: form.mechanics, force: form.force,
      videoUrl: form.videoUrl.trim() || undefined,
      cues: form.cues.split("\n").map(s => s.trim()).filter(Boolean),
      commonMistakes: form.commonMistakes.split("\n").map(s => s.trim()).filter(Boolean),
      metValue: Number(form.metValue),
    };
    if (editing) updateMutation.mutate({ id: editing.id, data: payload });
    else createMutation.mutate(payload);
  };

  // ── CSV Import ─────────────────────────────────────────────────────────────

  const handleImport = async (file: File) => {
    setImporting(true);
    setIErrors([]);
    try {
      const text = await file.text();
      const lines = text.trim().split("\n");
      if (lines.length < 2) { toast.error("CSV is empty or missing headers."); return; }

      const headers = parseCsvRow(lines[0]).map(h => h.toLowerCase().replace(/\s/g, ""));
      const idx = (key: string) => headers.indexOf(key);
      if (idx("name") === -1) { toast.error("CSV missing required 'name' column."); return; }

      const existingNames = new Set((exercises ?? []).map(e => e.name.toLowerCase()));
      const seenInFile    = new Set<string>();
      const errors: ImportError[] = [];
      const records: object[] = [];

      lines.slice(1).forEach((line, i) => {
        const rowNum = i + 2;
        const r = parseCsvRow(line);
        if (r.length <= 1 && !r[0]) return; // skip empty lines

        const name = r[idx("name")]?.trim();
        if (!name) { errors.push({ row: rowNum, name: "(empty)", reason: "Missing name" }); return; }

        const lower = name.toLowerCase();
        if (existingNames.has(lower)) { errors.push({ row: rowNum, name, reason: "Already exists in database (skipped)" }); return; }
        if (seenInFile.has(lower))    { errors.push({ row: rowNum, name, reason: "Duplicate in CSV file (skipped)" }); return; }

        seenInFile.add(lower);
        records.push({
          name,
          nameKa:           r[idx("nameka")]?.trim() || undefined,
          nameRu:           r[idx("nameru")]?.trim() || undefined,
          primaryMuscle:    r[idx("primarymuscle")]?.trim() || "CHEST",
          secondaryMuscles: (r[idx("secondarymuscles")] || "").split("|").map((s: string) => s.trim()).filter(Boolean),
          equipment:        (r[idx("equipment")] || "BODYWEIGHT").split("|").map((s: string) => s.trim()).filter(Boolean),
          difficulty:       r[idx("difficulty")]?.trim() || "BEGINNER",
          mechanics:        r[idx("mechanics")]?.trim() || "COMPOUND",
          force:            r[idx("force")]?.trim() || "PUSH",
          videoUrl:         r[idx("videourl")]?.trim() || undefined,
          cues:             (r[idx("cues")] || "").split("|").map((s: string) => s.trim()).filter(Boolean),
          commonMistakes:   (r[idx("commonmistakes")] || "").split("|").map((s: string) => s.trim()).filter(Boolean),
          metValue:         parseFloat(r[idx("metvalue")] || "3") || 3,
        });
      });

      if (records.length > 0) {
        await api("/admin/exercise-library/import", { method: "POST", body: { records }, token: token! });
        invalidate();
        toast.success(`Imported ${records.length} exercise${records.length !== 1 ? "s" : ""}.${errors.length > 0 ? ` ${errors.length} skipped.` : ""}`);
      } else {
        toast.error("Nothing to import — all rows were skipped or duplicates.");
      }

      if (errors.length > 0) setIErrors(errors);
    } catch (e: unknown) {
      toast.error(e instanceof Error ? e.message : "Import failed.");
    } finally {
      setImporting(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  };

  // ── Filtered + Paginated ───────────────────────────────────────────────────

  // Filtering is done server-side via query params
  const filtered = exercises ?? [];

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const safePage   = Math.min(page, totalPages - 1);
  const paginated  = filtered.slice(safePage * PAGE_SIZE, (safePage + 1) * PAGE_SIZE);

  return (
    <div className="space-y-8 max-w-[1600px] mx-auto">
      <PageHeader
        title="EXERCISE DATABASE"
        description="Global exercise library — manage names, translations, video links, and coaching cues"
        icon={<Dumbbell size={32} />}
        actions={
          <div className="flex items-center gap-3">
            <input ref={fileRef} type="file" accept=".csv" className="hidden"
              onChange={e => { const f = e.target.files?.[0]; if (f) handleImport(f); }} />
            <button onClick={() => exercises && exportCsv(exercises)}
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
              <Plus size={16} /> Add Exercise
            </button>
          </div>
        }
      />

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: "Total Exercises", value: stats?.total ?? 0,          color: "text-white" },
          { label: "Active",          value: stats?.active ?? 0,         color: "text-green-400" },
          { label: "Muscle Groups",   value: stats?.byMuscle?.length ?? 0, color: "text-[#F1C40F]" },
          { label: "Showing",         value: `${paginated.length} / ${filtered.length}`, color: "text-purple-400" },
        ].map(s => (
          <div key={s.label} className="bg-[#121721] border border-white/5 rounded-2xl p-5">
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">{s.label}</p>
            <p className={`text-3xl font-black mt-1 tracking-tighter ${s.color}`}>{s.value}</p>
          </div>
        ))}
      </div>

      {/* CSV hint */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl px-5 py-3 flex items-start gap-3">
        <Upload size={14} className="text-zinc-500 mt-0.5 shrink-0" />
        <p className="text-[11px] text-zinc-500 font-mono">
          CSV columns: <span className="text-zinc-300">name, nameKa, nameRu, primaryMuscle, secondaryMuscles, equipment, difficulty, mechanics, force, videoUrl, cues, commonMistakes, metValue</span>
          &nbsp;— use <span className="text-zinc-300">|</span> to separate multiple values. Duplicates are automatically skipped.
        </p>
      </div>

      {/* Import errors panel */}
      {importErrors.length > 0 && (
        <div className="bg-yellow-500/5 border border-yellow-500/20 rounded-2xl p-5">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2 text-yellow-400">
              <AlertTriangle size={16} />
              <span className="text-sm font-bold">{importErrors.length} row{importErrors.length !== 1 ? "s" : ""} skipped during import</span>
            </div>
            <button onClick={() => setIErrors([])} className="text-zinc-500 hover:text-white transition-colors"><X size={14}/></button>
          </div>
          <div className="space-y-1 max-h-40 overflow-y-auto">
            {importErrors.map((err, i) => (
              <div key={i} className="flex items-center gap-3 text-xs text-zinc-400">
                <span className="text-zinc-600 font-mono w-12 shrink-0">Row {err.row}</span>
                <span className="text-zinc-300 truncate">{err.name}</span>
                <span className="text-yellow-500/80 shrink-0">— {err.reason}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="flex flex-col lg:flex-row gap-4">
        <div className="relative flex-1">
          <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500 pointer-events-none" />
          <input value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search exercises..." className="amirani-input amirani-input-with-icon" />
        </div>
        <CustomSelect value={muscleFilter} onChange={setMF} className="w-52"
          options={[{ value: "", label: "All Muscles" }, ...MUSCLES.map(m => ({ value: m, label: m.replace(/_/g, " ") }))]} />
        <CustomSelect value={diffFilter} onChange={setDF} className="w-48"
          options={[{ value: "", label: "All Levels" }, ...DIFFICULTIES.map(d => ({ value: d, label: d }))]} />
        <button onClick={() => queryClient.invalidateQueries({ queryKey: ["exercise-db"] })}
          className="amirani-input !w-[48px] !p-0 flex items-center justify-center !bg-zinc-900 group">
          <RefreshCw size={16} className={`text-zinc-500 group-hover:text-[#F1C40F] transition-colors ${isLoading ? "animate-spin" : ""}`} />
        </button>
      </div>

      {/* Table */}
      <div className="bg-[#121721] border border-white/5 rounded-2xl overflow-hidden">
        <div className="grid grid-cols-[2fr_1fr_1fr_1fr_auto] px-6 py-3 border-b border-white/5 text-[10px] font-black uppercase tracking-widest text-zinc-600">
          <span>Exercise</span><span>Muscle</span><span>Difficulty</span><span>Equipment</span><span>Actions</span>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center py-16 text-zinc-500">
            <RefreshCw size={20} className="animate-spin mr-2" /> Loading…
          </div>
        ) : paginated.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-zinc-600 gap-3">
            <Dumbbell size={40} />
            <p className="text-sm font-bold">{filtered.length === 0 ? "No exercises found" : "No results for current filter"}</p>
            {filtered.length === 0 && <button onClick={openCreate} className="text-[#F1C40F] text-xs hover:underline">Add first exercise →</button>}
          </div>
        ) : (
          <div className="divide-y divide-white/[0.04]">
            {paginated.map(ex => (
              <div key={ex.id}>
                <div className={`grid grid-cols-[2fr_1fr_1fr_1fr_auto] px-6 py-4 hover:bg-white/[0.02] transition-colors items-center ${!ex.isActive ? "opacity-50" : ""}`}>
                  <div>
                    <p className="text-sm font-semibold text-white">{ex.name}</p>
                    <div className="flex items-center gap-2 mt-0.5">
                      {ex.nameKa && <span className="text-[10px] text-zinc-500">🇬🇪 {ex.nameKa}</span>}
                      {ex.nameRu && <span className="text-[10px] text-zinc-500">🇷🇺 {ex.nameRu}</span>}
                      {!ex.nameKa && !ex.nameRu && <span className="text-[10px] text-zinc-700 italic">No translations</span>}
                    </div>
                  </div>
                  <span className="text-xs text-zinc-400">{ex.primaryMuscle.replace(/_/g, " ")}</span>
                  <span className={`inline-flex w-fit px-2 py-0.5 rounded-lg border text-[10px] font-black uppercase ${diffColor(ex.difficulty)}`}>{ex.difficulty}</span>
                  <span className="text-xs text-zinc-500">{ex.equipment.slice(0, 2).join(", ")}{ex.equipment.length > 2 ? ` +${ex.equipment.length - 2}` : ""}</span>
                  <div className="flex items-center gap-1">
                    <button onClick={() => setExpanded(expandedId === ex.id ? null : ex.id)}
                      className="p-1.5 rounded-lg hover:bg-zinc-800 text-zinc-500 hover:text-white transition-colors">
                      {expandedId === ex.id ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                    </button>
                    <button onClick={() => openEdit(ex)}
                      className="p-1.5 rounded-lg hover:bg-zinc-800 text-zinc-500 hover:text-[#F1C40F] transition-colors">
                      <Edit2 size={14} />
                    </button>
                    <button onClick={() => updateMutation.mutate({ id: ex.id, data: { isActive: !ex.isActive } })}
                      title={ex.isActive ? "Deactivate Exercise" : "Activate Exercise"}
                      className={`p-1.5 rounded-lg transition-colors ${ex.isActive ? "hover:bg-emerald-500/10 text-emerald-400" : "hover:bg-zinc-500/10 text-zinc-600"}`}>
                      {ex.isActive ? <Zap size={16} /> : <ZapOff size={16} />}
                    </button>
                    <button onClick={() => { if (confirm(`Delete "${ex.name}"?`)) deleteMutation.mutate(ex.id); }}
                      title="Delete"
                      className="p-1.5 rounded-lg hover:bg-red-500/10 text-zinc-500 hover:text-red-400 transition-colors">
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>
                {expandedId === ex.id && (
                  <div className="px-6 pb-4 bg-zinc-900/30 grid grid-cols-3 gap-4 text-xs text-zinc-400">
                    <div><span className="text-zinc-600 uppercase tracking-widest text-[10px] font-black block mb-1">Mechanics / Force</span>{ex.mechanics} · {ex.force}</div>
                    <div><span className="text-zinc-600 uppercase tracking-widest text-[10px] font-black block mb-1">Secondary Muscles</span>{ex.secondaryMuscles.join(", ") || "—"}</div>
                    <div><span className="text-zinc-600 uppercase tracking-widest text-[10px] font-black block mb-1">MET Value</span>{ex.metValue}</div>
                    {ex.cues.length > 0 && <div className="col-span-3"><span className="text-zinc-600 uppercase tracking-widest text-[10px] font-black block mb-1">Coaching Cues</span>{ex.cues.map((c, i) => <span key={i} className="block">• {c}</span>)}</div>}
                    {ex.videoUrl && <div className="col-span-3"><span className="text-zinc-600 uppercase tracking-widest text-[10px] font-black block mb-1">Video</span><a href={ex.videoUrl} target="_blank" className="text-[#F1C40F] hover:underline">{ex.videoUrl}</a></div>}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {/* Pagination */}
        {filtered.length > PAGE_SIZE && (
          <div className="flex items-center justify-between px-6 py-4 border-t border-white/5">
            <span className="text-xs text-zinc-500">
              Showing {safePage * PAGE_SIZE + 1}–{Math.min((safePage + 1) * PAGE_SIZE, filtered.length)} of {filtered.length}
            </span>
            <div className="flex items-center gap-2">
              <button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={safePage === 0}
                className="p-1.5 rounded-lg hover:bg-zinc-800 text-zinc-500 hover:text-white disabled:opacity-30 disabled:cursor-not-allowed transition-colors">
                <ChevronLeft size={16} />
              </button>
              {Array.from({ length: totalPages }, (_, i) => (
                <button key={i} onClick={() => setPage(i)}
                  className={`w-7 h-7 rounded-lg text-xs font-bold transition-colors ${i === safePage ? "bg-[#F1C40F] text-black" : "hover:bg-zinc-800 text-zinc-500 hover:text-white"}`}>
                  {i + 1}
                </button>
              ))}
              <button onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))} disabled={safePage === totalPages - 1}
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
                <h2 className="text-lg font-black text-white uppercase">{editing ? "Edit Exercise" : "Add Exercise"}</h2>
                <p className="text-[10px] text-zinc-500 uppercase tracking-widest mt-0.5">Exercise Database</p>
              </div>
              <button onClick={closeModal} className="p-2 hover:bg-zinc-800 text-zinc-500 hover:text-white rounded-xl transition-colors"><X size={18} /></button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-5 overflow-y-auto max-h-[calc(90vh-88px)] amirani-scrollbar">
              {formError && (
                <div className="flex items-center gap-2 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3 text-red-400 text-xs font-bold">
                  <AlertTriangle size={14} className="shrink-0" /> {formError}
                </div>
              )}

              {/* Language tab switcher */}
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
                    <input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })}
                      className="amirani-input" placeholder="e.g. Push-Up" />
                  </div>
                )}
                {nameLang === "ka" && (
                  <div>
                    <label className="amirani-label">Georgian Name</label>
                    <input value={form.nameKa} onChange={e => setForm({ ...form, nameKa: e.target.value })}
                      className="amirani-input" placeholder="e.g. დაჯახელი" />
                  </div>
                )}
                {nameLang === "ru" && (
                  <div>
                    <label className="amirani-label">Russian Name</label>
                    <input value={form.nameRu} onChange={e => setForm({ ...form, nameRu: e.target.value })}
                      className="amirani-input" placeholder="e.g. Отжимание" />
                  </div>
                )}
              </div>

              {/* MET Value inline */}
              <div>
                <label className="amirani-label">MET Value</label>
                <input type="number" step="0.1" min="1" max="20"
                  value={form.metValue} onChange={e => setForm({ ...form, metValue: parseFloat(e.target.value) })}
                  className="amirani-input" />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <CustomSelect label="Primary Muscle *" value={form.primaryMuscle}
                  onChange={v => setForm({ ...form, primaryMuscle: v })}
                  options={MUSCLES.map(m => ({ value: m, label: m.replace(/_/g, " ") }))} />
                <div>
                  <label className="amirani-label">Secondary Muscles <span className="text-zinc-600">(comma separated)</span></label>
                  <input value={form.secondaryMuscles} onChange={e => setForm({ ...form, secondaryMuscles: e.target.value })}
                    className="amirani-input" placeholder="SHOULDERS, TRICEPS" />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="amirani-label">Equipment <span className="text-zinc-600">(comma separated)</span></label>
                  <input value={form.equipment} onChange={e => setForm({ ...form, equipment: e.target.value })}
                    className="amirani-input" placeholder="BODYWEIGHT, BENCH" />
                </div>
                <CustomSelect label="Difficulty *" value={form.difficulty}
                  onChange={v => setForm({ ...form, difficulty: v as Difficulty })}
                  options={DIFFICULTIES.map(d => ({ value: d, label: d }))} />
                <CustomSelect label="Mechanics *" value={form.mechanics}
                  onChange={v => setForm({ ...form, mechanics: v as Mechanics })}
                  options={MECHANICS_OPTIONS.map(m => ({ value: m, label: m }))} />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <CustomSelect label="Force Pattern *" value={form.force}
                  onChange={v => setForm({ ...form, force: v as Force })}
                  options={FORCE_OPTIONS.map(f => ({ value: f, label: f }))} />
                <div>
                  <label className="amirani-label">Video URL</label>
                  <input value={form.videoUrl} onChange={e => setForm({ ...form, videoUrl: e.target.value })}
                    className="amirani-input" placeholder="https://..." />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="amirani-label">Coaching Cues <span className="text-zinc-600">(one per line)</span></label>
                  <textarea value={form.cues} onChange={e => setForm({ ...form, cues: e.target.value })}
                    rows={3} className="amirani-textarea" placeholder={"Keep core tight\nElbows at 45°"} />
                </div>
                <div>
                  <label className="amirani-label">Common Mistakes <span className="text-zinc-600">(one per line)</span></label>
                  <textarea value={form.commonMistakes} onChange={e => setForm({ ...form, commonMistakes: e.target.value })}
                    rows={3} className="amirani-textarea" placeholder={"Flared elbows\nPartial range"} />
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <button type="button" onClick={closeModal}
                  className="flex-1 py-3 bg-white/5 text-zinc-400 rounded-xl hover:bg-zinc-800 transition-colors font-bold text-xs uppercase tracking-widest border border-white/5">
                  Cancel
                </button>
                <button type="submit" disabled={createMutation.isPending || updateMutation.isPending}
                  className="flex-1 py-3 bg-[#F1C40F] text-black rounded-xl hover:bg-[#F1C40F]/90 transition-colors disabled:opacity-30 font-black text-xs uppercase tracking-widest flex items-center justify-center gap-2">
                  {(createMutation.isPending || updateMutation.isPending) ? <RefreshCw size={14} className="animate-spin" /> : null}
                  {editing ? "Save Changes" : "Add Exercise"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
