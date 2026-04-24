"use client";

import { useState, use } from "react";
import { useAuthStore } from "@/lib/auth-store";
import {
  useQuery, useMutation, useQueryClient,
} from "@tanstack/react-query";
import {
  trainerApi,
  type TrainerWorkoutRoutine,
  type ExerciseLibraryItem,
  type TrainerTemplateWorkoutDayData,
  type TrainerTemplateWorkoutWeekData,
  type TrainerTemplateExercise,
  type TrainerWorkoutPlan,
} from "@/lib/api";
import {
  ArrowLeft, Plus, X,
  Search, Pencil, Trash2, Dumbbell,
  Clock, Star, Loader2, Calendar
} from "lucide-react";
import Link from "next/link";
import { ThemedDatePicker } from "@/components/ui/ThemedDatePicker";
import { MagicActionFooter } from "./components/MagicActionFooter";

// ─── Constants ────────────────────────────────────────────────────────────────

const WEEK_OPTIONS = [1, 2, 3, 4] as const;
const LBS_PER_KG = 2.20462;

const ROUTINE_SLOTS = [
  { key: "WEIGHTS",  label: "Weights",  emoji: "🏋️", hour: 10 },
  { key: "CARDIO",   label: "Cardio",   emoji: "🏃", hour: 8  },
  { key: "MOBILITY", label: "Mobility", emoji: "🧘", hour: 18 },
  { key: "RECOVERY", label: "Recovery", emoji: "🧊", hour: 20 },
] as const;

const DAYS_OF_WEEK = ["M", "T", "W", "T", "F", "S", "S"];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function normalizeDate(d: string): string {
  return d.split("T")[0];
}

function getScheduledDate(startDate: string, weekNum: number, dayIdx: number): string {
  const base = new Date(normalizeDate(startDate) + "T00:00:00");
  if (isNaN(base.getTime())) return "";
  base.setDate(base.getDate() + (weekNum - 1) * 7 + dayIdx);
  const yyyy = base.getFullYear();
  const mm = String(base.getMonth() + 1).padStart(2, '0');
  const dd = String(base.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function getDayName(dateStr: string): string {
  const norm = normalizeDate(dateStr);
  const dateObj = new Date(norm + "T00:00:00");
  if (isNaN(dateObj.getTime())) return "Day " + (parseInt(dateStr) || 1);
  return dateObj.toLocaleDateString("en-US", { weekday: "long" });
}

function formatDate(dateStr: string): string {
  if (!dateStr) return "";
  const norm = normalizeDate(dateStr);
  const dateObj = new Date(norm + "T00:00:00");
  if (isNaN(dateObj.getTime())) return "";
  return dateObj.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function getRoutineSlot(key: string | null) {
  return ROUTINE_SLOTS.find((s) => s.key === key) ?? {
    key: key ?? "", label: key?.replace(/_/g, " ") ?? "Session", emoji: "⚡", hour: 12,
  };
}

// ─── Metric progress bar (Shared Pattern) ──────────────────────────────────────

function MetricBar({
  label, current, target, color, unit = "sets",
}: {
  label: string; current: number; target: number; color: string; unit?: string;
}) {
  const pct = target > 0 ? Math.min((current / target) * 100, 100) : 0;
  const over = target > 0 && current > target;
  const barColor = over ? "bg-red-500" : color.replace("text-", "bg-").replace(/\d+$/, "500");

  return (
    <div className="flex-1 min-w-[120px]">
      <div className="flex items-center justify-between mb-1.5 px-0.5">
        <span className="text-[9px] text-zinc-500 uppercase font-black tracking-widest leading-none">{label}</span>
        <span className={`text-[10px] font-bold leading-none ${over ? "text-red-400" : color}`}>
          {Math.round(current)}{unit}
          <span className="text-zinc-600 font-normal ml-0.5">/{target}{unit}</span>
        </span>
      </div>
      <div className="h-1.5 bg-zinc-800 rounded-full overflow-hidden">
        <div className={`h-full rounded-full transition-all duration-500 ${barColor}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

// ─── Exercise row state models ──────────────────────────────────────────────────

interface ExRow {
  id: string;
  name: string;
  /** true when name was confirmed from the library (shows chip) */
  confirmedFromLibrary: boolean;
  /** populated when exercise was selected from the library search */
  exerciseLibraryId?: string;
  sets: string;
  reps: string; // Supports "8-12"
  weight: string;
  rest: string;
  rpe: string;
  progressionNote: string;
}

function emptyExRow(): ExRow {
  return {
    id: Math.random().toString(36).slice(2),
    name: "", confirmedFromLibrary: false, sets: "3", reps: "10", weight: "", rest: "60", rpe: "", progressionNote: "",
  };
}

// ─── Exercise Search component ──────────────────────────────────────────────────

function ExerciseSearchDropdown({
  token, lang = 'EN', onSelect, onManualEntry,
}: {
  token: string;
  lang?: 'EN' | 'KA' | 'RU';
  onSelect: (ex: ExerciseLibraryItem) => void;
  /** Called when user confirms a custom name not found in library */
  onManualEntry: (name: string) => void;
}) {
  const [q, setQ] = useState("");
  const [open, setOpen] = useState(false);

  const { data: results = [], isFetching } = useQuery({
    queryKey: ["exercise-search", q, lang],
    queryFn: () => trainerApi.searchExercises(q, token, lang),
    enabled: q.length >= 2,
    staleTime: 60_000,
  });

  const noResults = q.length >= 2 && !isFetching && results.length === 0;

  return (
    <div className="relative flex-1">
      <div className="relative">
        <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" />
        <input
          value={q}
          onChange={(e) => { setQ(e.target.value); setOpen(e.target.value.length >= 2); }}
          onFocus={() => setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 300)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && q.trim().length >= 2) {
              onManualEntry(q.trim());
              setOpen(false);
            }
          }}
          placeholder="Search or type movement name…"
          className="w-full h-11 bg-zinc-950 border border-zinc-800 rounded-xl pl-9 pr-4 text-sm text-white outline-none focus:border-[#F1C40F]/40 transition-colors"
        />
        {isFetching && (
          <Loader2 size={12} className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-500 animate-spin" />
        )}
      </div>

      {open && q.length >= 2 && (
        <div className="absolute z-[300] top-full mt-2 left-0 right-0 bg-[#0e1420] border border-zinc-800 rounded-xl shadow-2xl overflow-hidden max-h-72 overflow-y-auto animate-in fade-in slide-in-from-top-2 duration-200">
          {/* "Use this name" option when no DB match */}
          {noResults && (
            <button
              onMouseDown={() => { onManualEntry(q.trim()); setOpen(false); }}
              className="w-full text-left px-4 py-3 hover:bg-[#F1C40F]/10 transition-colors border-b border-zinc-800/40 flex items-center gap-2"
            >
              <Plus size={12} className="text-[#F1C40F] shrink-0" />
              <span className="text-sm text-[#F1C40F] font-bold">Use &quot;{q}&quot;</span>
              <span className="text-[10px] text-zinc-600 ml-auto">custom</span>
            </button>
          )}
          {results.map((ex) => (
            <button
              key={ex.id}
              onMouseDown={() => { onSelect(ex); setQ(ex.name); setOpen(false); }}
              className="w-full text-left px-4 py-3 hover:bg-zinc-800/50 transition-colors border-b border-zinc-800/40 last:border-0"
            >
              <p className="text-sm font-bold text-white mb-0.5">{ex.name}</p>
              <div className="flex gap-2 text-[8px] font-black uppercase tracking-widest text-zinc-500">
                <span className="text-[#F1C40F]">{ex.primaryMuscle}</span>
                <span>{ex.difficulty}</span>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// ─── Exercise Row Editor ────────────────────────────────────────────────────────

function ExerciseEditor({
  rows, onChange, token, unitPref = 'METRIC', lang = 'EN',
}: {
  rows: ExRow[];
  onChange: (rows: ExRow[]) => void;
  token: string;
  unitPref?: 'METRIC' | 'IMPERIAL';
  lang?: 'EN' | 'KA' | 'RU';
}) {
  function update(id: string, patch: Partial<ExRow>) {
    onChange(rows.map((r) => (r.id === id ? { ...r, ...patch } : r)));
  }
  function remove(id: string) {
    onChange(rows.filter((r) => r.id !== id));
  }

  return (
    <div className="space-y-3">
      {rows.map((row, idx) => (
        <div key={row.id} className="bg-zinc-900 border border-zinc-800 rounded-xl p-4 space-y-4 animate-in slide-in-from-bottom-2 duration-300">
          <div className="flex items-center gap-3">
             <span className="text-[10px] font-black text-zinc-700 w-4 select-none italic">#{idx + 1}</span>

             {/* Name — locked chip when confirmed, search dropdown otherwise */}
             {row.name && row.confirmedFromLibrary ? (
               <div className="flex-1 flex items-center gap-1.5 bg-zinc-800 border border-[#F1C40F]/30 rounded-xl px-3 py-2.5 h-11">
                 <Dumbbell size={12} className="text-[#F1C40F] shrink-0" />
                 <span className="text-sm text-white truncate flex-1">{row.name}</span>
                 <button onClick={() => update(row.id, { name: "", confirmedFromLibrary: false, exerciseLibraryId: undefined })} className="text-zinc-600 hover:text-red-400">
                   <X size={11} />
                 </button>
               </div>
             ) : (
               <ExerciseSearchDropdown
                 token={token}
                 lang={lang}
                 onSelect={(ex) => update(row.id, { name: ex.name, confirmedFromLibrary: true, exerciseLibraryId: ex.id })}
                 onManualEntry={(name) => update(row.id, { name, confirmedFromLibrary: true, exerciseLibraryId: undefined })}
               />
             )}

             <button onClick={() => remove(row.id)} className="p-2.5 text-zinc-700 hover:text-red-500 transition-colors">
                <X size={16} />
             </button>
          </div>

          <div className="pl-7 pr-1 grid grid-cols-5 gap-3">
              {(
                [
                  ["Sets", "sets", "text-white"],
                  ["Reps", "reps", "text-[#F1C40F]"],
                  [unitPref === 'IMPERIAL' ? "Lbs" : "Kg", "weight", "text-blue-400"],
                  ["Rest", "rest", "text-violet-400"],
                  ["RPE", "rpe", "text-red-400"],
                ] as [string, keyof ExRow, string][]
              ).map(([label, field, color]) => (
                <div key={field}>
                  <p className={`text-[8px] font-black uppercase mb-1.5 tracking-widest ${color}`}>{label}</p>
                  <input
                    value={row[field] as string}
                    onChange={(e) => update(row.id, { [field]: e.target.value })}
                    className="w-full h-9 bg-zinc-950 border border-zinc-800 rounded-lg px-2 text-xs text-white text-center outline-none focus:border-[#F1C40F]/40 transition-colors"
                  />
                </div>
              ))}
          </div>

          <div className="pl-7 pr-1">
             <input
                value={row.progressionNote}
                onChange={(e) => update(row.id, { progressionNote: e.target.value })}
                placeholder="Progression notes (e.g. Add 2.5kg next cycle)"
                className="w-full h-9 bg-zinc-950 border border-zinc-800 rounded-lg px-3 text-[10px] text-zinc-400 placeholder-zinc-700 outline-none focus:border-[#F1C40F]/20 transition-colors"
             />
          </div>
        </div>
      ))}
      <button
        onClick={() => onChange([...rows, emptyExRow()])}
        className="w-full flex items-center justify-center gap-2 py-4 border border-dashed border-zinc-800 rounded-xl text-zinc-600 hover:text-[#F1C40F] hover:border-[#F1C40F]/30 text-[10px] font-black uppercase tracking-widest transition-all"
      >
        <Plus size={14} /> Add Movement Row
      </button>
    </div>
  );
}

// ─── Edit Routine Modal ────────────────────────────────────────────────────────

function EditRoutineModal({
  routine, token, memberId, onDone, unitPref = 'METRIC', lang = 'EN',
}: {
  routine: TrainerWorkoutRoutine; token: string; memberId: string; onDone: () => void;
  unitPref?: 'METRIC' | 'IMPERIAL'; lang?: 'EN' | 'KA' | 'RU';
}) {
  const qc = useQueryClient();
  const [name, setName] = useState(routine.name);
  const [rows, setRows] = useState<ExRow[]>(() =>
    routine.exercises
      .slice()
      .sort((a, b) => a.orderIndex - b.orderIndex)
      .map(e => {
        const displayWeight = e.targetWeight != null
          ? (unitPref === 'IMPERIAL'
              ? String(parseFloat((e.targetWeight * LBS_PER_KG).toFixed(1)))
              : String(e.targetWeight))
          : "";
        return {
          id:                e.id,
          name:              e.exerciseName,
          confirmedFromLibrary: true,
          exerciseLibraryId: e.exerciseLibraryId ?? undefined,
          sets:              String(e.targetSets ?? "3"),
          reps:              String(e.targetReps ?? "10"),
          weight:            displayWeight,
          rest:              e.restSeconds != null ? String(e.restSeconds) : "60",
          rpe:               e.rpe != null ? String(e.rpe) : "",
          progressionNote:   e.progressionNote ?? "",
        };
      })
  );
  const [saving, setSaving] = useState(false);

  async function handleSave() {
    const valid = rows.filter(r => r.name.trim());
    if (valid.length === 0) return;
    setSaving(true);
    try {
      await trainerApi.updateRoutine(routine.id, { name: name.trim() || routine.name }, token);

      const originalIds = new Set(routine.exercises.map(e => e.id));
      const toUpdate = valid.filter(r => originalIds.has(r.id));
      const toDelete = routine.exercises.filter(e => !valid.find(r => r.id === e.id));
      const toAdd    = valid.filter(r => !originalIds.has(r.id));

      function rowPayload(r: ExRow, idx: number) {
        const rawWeight = parseFloat(r.weight);
        const weightKg = rawWeight
          ? (unitPref === 'IMPERIAL' ? parseFloat((rawWeight / LBS_PER_KG).toFixed(2)) : rawWeight)
          : undefined;
        return {
          exerciseName:      r.name,
          exerciseLibraryId: r.exerciseLibraryId,
          targetSets:        parseInt(r.sets)  || 0,
          targetReps:        parseInt(r.reps)  || 10,
          targetWeight:      weightKg,
          restSeconds:       parseInt(r.rest)  || undefined,
          rpe:               parseInt(r.rpe)   || undefined,
          progressionNote:   r.progressionNote || undefined,
          orderIndex:        idx,
        };
      }

      await Promise.all([
        ...toDelete.map(e => trainerApi.deleteExercise(e.id, token)),
        ...toUpdate.map(r => {
          const idx = valid.findIndex(v => v.id === r.id);
          return trainerApi.updateExercise(r.id, rowPayload(r, idx), token);
        }),
      ]);

      if (toAdd.length > 0) {
        const baseIdx = toUpdate.length;
        await trainerApi.addExercises(routine.id, toAdd.map((r, i) => rowPayload(r, baseIdx + i)), token);
      }

      await qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
      onDone();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-[150] flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/80 backdrop-blur-sm animate-in fade-in duration-300" onClick={onDone} />
      <div className="relative w-full max-w-3xl animate-in zoom-in-95 fade-in duration-300 max-h-[90vh] overflow-y-auto rounded-xl bg-[#0e1420] border border-zinc-800">
        <div className="flex items-center justify-between px-6 py-4 border-b border-zinc-800">
          <h3 className="text-sm font-black uppercase tracking-widest text-white">Edit Session</h3>
          <button onClick={onDone} className="p-2 text-zinc-500 hover:text-white rounded-lg hover:bg-white/5 transition-all">
            <X size={16} />
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div>
            <label className="text-[10px] font-black uppercase text-zinc-500 tracking-widest block mb-3">Session Name</label>
            <input
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Session name"
              className="w-full h-11 bg-zinc-950 border border-zinc-800 rounded-xl px-4 text-sm text-white outline-none focus:border-[#F1C40F]/40 transition-colors"
            />
          </div>

          <div>
            <label className="text-[10px] font-black uppercase text-zinc-500 tracking-widest block mb-3">Movements & Target Metrics</label>
            <ExerciseEditor rows={rows} onChange={setRows} token={token} unitPref={unitPref} lang={lang} />
          </div>

          <div className="flex gap-2 pt-2">
            <button onClick={handleSave} disabled={saving} className="flex-1 h-12 bg-[#F1C40F] text-black text-[10px] font-black uppercase tracking-widest rounded-xl hover:bg-[#F4D03F] shadow-xl disabled:opacity-50 transition-all active:scale-95">
              {saving ? "Saving..." : "Save Changes"}
            </button>
            <button onClick={onDone} disabled={saving} className="px-8 h-12 bg-zinc-800/50 text-zinc-400 text-[10px] font-black uppercase tracking-widest rounded-xl border border-zinc-800 hover:text-white transition-all active:scale-95">
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Add Routine Form (Matching AddMealForm structure) ─────────────────────────

type SlotData = { name: string; rows: ExRow[] };

function AddRoutineForm({
  planId, scheduledDate, token, memberId, onDone, unitPref = 'METRIC', lang = 'EN',
}: {
  planId: string; scheduledDate: string;
  token: string; memberId: string; onDone: () => void;
  unitPref?: 'METRIC' | 'IMPERIAL'; lang?: 'EN' | 'KA' | 'RU';
}) {
  const qc = useQueryClient();
  const [activeSlot, setActiveSlot] = useState<string>("WEIGHTS");
  const [slotData, setSlotData] = useState<Record<string, SlotData>>(() => {
    const init = {} as Record<string, SlotData>;
    ROUTINE_SLOTS.forEach(s => {
      init[s.key] = { 
        name: "", 
        rows: [emptyExRow()] 
      };
    });
    return init;
  });
  const [saving, setSaving] = useState(false);

  function updateSlot(patch: Partial<SlotData>) {
    setSlotData(prev => ({ ...prev, [activeSlot]: { ...prev[activeSlot], ...patch } }));
  }

  const SLOT_TO_EXERCISE_TYPE: Record<string, string> = {
    WEIGHTS: "STRENGTH",
    CARDIO: "CARDIO",
    MOBILITY: "FLEXIBILITY",
    RECOVERY: "FLEXIBILITY",
  };

  async function handleSave(isDraft = false) {
    const current = slotData[activeSlot];
    const exercises = current.rows.filter(r => r.name.trim()).map((r, idx) => {
      const rawWeight = parseFloat(r.weight);
      const weightKg = rawWeight
        ? (unitPref === 'IMPERIAL' ? parseFloat((rawWeight / LBS_PER_KG).toFixed(2)) : rawWeight)
        : undefined;
      return {
        exerciseName:      r.name,
        exerciseLibraryId: r.exerciseLibraryId,
        targetSets:        parseInt(r.sets) || 0,
        targetReps:        parseInt(r.reps) || 10,
        targetWeight:      weightKg,
        restSeconds:       parseInt(r.rest) || undefined,
        rpe:               parseInt(r.rpe) || undefined,
        progressionNote:   r.progressionNote || undefined,
        exerciseType:      SLOT_TO_EXERCISE_TYPE[activeSlot] ?? "STRENGTH",
        orderIndex:        idx,
      };
    });
    if (exercises.length === 0) return;

    setSaving(true);
    try {
      const res = await trainerApi.addRoutine(planId, {
        name: current.name || getRoutineSlot(activeSlot).label,
        scheduledDate,
        isDraft,
      }, token);
      await trainerApi.addExercises(res.id, exercises, token);
      await qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
      onDone();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="bg-[#0e1420] border-t border-zinc-800 animate-in slide-in-from-bottom-4 duration-500 overflow-hidden">
      <div className="flex border-b border-zinc-800">
        {ROUTINE_SLOTS.map(s => (
          <button
            key={s.key}
            onClick={() => setActiveSlot(s.key)}
            className={`flex-1 py-4 text-[10px] font-black uppercase tracking-widest transition-all ${activeSlot === s.key ? "text-[#F1C40F] bg-[#F1C40F]/5 shadow-[inset_0_-2px_0_#F1C40F]" : "text-zinc-600 hover:text-zinc-400"}`}
          >
            {s.label}
          </button>
        ))}
      </div>
      
      <div className="p-6 space-y-6">
        <div>
           <label className="text-[10px] font-black uppercase text-zinc-500 tracking-widest block mb-3">Session Name</label>
           <input
             value={slotData[activeSlot].name}
             onChange={(e) => updateSlot({ name: e.target.value })}
             placeholder={`e.g. ${getRoutineSlot(activeSlot).label} Alpha`}
             className="w-full h-11 bg-zinc-950 border border-zinc-800 rounded-xl px-4 text-sm text-white outline-none focus:border-[#F1C40F]/40 transition-colors"
           />
        </div>

        <div>
           <label className="text-[10px] font-black uppercase text-zinc-500 tracking-widest block mb-3">Movements & Target Metrics</label>
           <ExerciseEditor rows={slotData[activeSlot].rows} onChange={rows => updateSlot({ rows })} token={token} unitPref={unitPref} lang={lang} />
        </div>

        <div className="flex gap-2 pt-4">
           <button onClick={() => handleSave(false)} disabled={saving} className="flex-1 h-12 bg-[#F1C40F] text-black text-[10px] font-black uppercase tracking-widest rounded-xl hover:bg-[#F4D03F] shadow-xl disabled:opacity-50 transition-all active:scale-95">
              {saving ? "Saving..." : "Save"}
           </button>
           <button onClick={() => handleSave(true)} disabled={saving} className="px-8 h-12 bg-zinc-800/50 text-zinc-400 text-[10px] font-black uppercase tracking-widest rounded-xl border border-zinc-800 hover:text-white transition-all active:scale-95">
              Draft
           </button>
           <button onClick={onDone} className="p-3 bg-zinc-900 border border-zinc-800 text-zinc-600 hover:text-white rounded-xl transition-all">
              <X size={18} />
           </button>
        </div>
      </div>
    </div>
  );
}

function ExerciseDisplayCard({
  routine, token, memberId, onSaveToLibrary, onEdit,
  isFirst, isLast, onMoveUp, onMoveDown, unitPref,
}: {
  routine: TrainerWorkoutRoutine; token: string; memberId: string;
  onSaveToLibrary?: (r: TrainerWorkoutRoutine) => void;
  onEdit?: (r: TrainerWorkoutRoutine) => void;
  isFirst?: boolean; isLast?: boolean;
  onMoveUp?: () => void; onMoveDown?: () => void;
  unitPref?: 'METRIC' | 'IMPERIAL';
}) {
  const qc = useQueryClient();
  const slot = getRoutineSlot(routine.name);

  const deleteRoutine = useMutation({
    mutationFn: () => trainerApi.deleteRoutine(routine.id, token),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] }),
  });

  return (
    <div className={`peer group/card border rounded-2xl p-4 transition-all duration-300 ${routine.isDraft ? "bg-zinc-900/30 border-zinc-800/50 opacity-60" : "bg-zinc-900/60 border-zinc-800 hover:border-[#F1C40F]/30 hover:bg-zinc-900/80 shadow-lg"}`}>
      <div className="flex items-start gap-4">
        {/* Reorder Stack */}
        <div className="flex flex-col gap-1 pt-1 opacity-0 group-hover/card:opacity-100 transition-opacity">
          <button onClick={onMoveUp} disabled={isFirst} className="p-1 text-zinc-700 hover:text-[#F1C40F] disabled:opacity-10"><Plus size={12} className="rotate-45" /></button>
          <button onClick={onMoveDown} disabled={isLast} className="p-1 text-zinc-700 hover:text-[#F1C40F] disabled:opacity-10"><Plus size={12} className="rotate-[225deg]" /></button>
        </div>

        <div className="w-12 h-12 rounded-xl bg-zinc-950 border border-white/5 flex items-center justify-center text-2xl shrink-0 shadow-inner">
          {slot.emoji}
        </div>

        <div className="flex-1 min-w-0 pt-0.5">
          <div className="flex items-center gap-2 mb-1.5">
            <h4 className="font-bold text-white text-base italic tracking-tight truncate">{routine.name}</h4>
            {routine.isDraft && (
              <span className="px-1.5 py-0.5 bg-amber-500/10 border border-amber-500/20 text-amber-500 text-[8px] font-black uppercase tracking-widest rounded">Draft</span>
            )}
          </div>

          <div className="flex items-center gap-4 text-[10px] font-black uppercase tracking-widest mb-3">
             <span className="text-[#F1C40F] flex items-center gap-1.5"><Dumbbell size={12} /> {routine.exercises?.length || 0} Movements</span>
             <span className="text-zinc-500 flex items-center gap-1.5"><Clock size={12} /> {routine.exercises?.reduce((s, e) => s + (e.targetSets || 0), 0)} Sets Total</span>
          </div>

          {routine.exercises?.length > 0 && !routine.isDraft && (
             <p className="text-[10px] text-zinc-600 line-clamp-1 italic">
                {routine.exercises.map(e => {
                  const wt = e.targetWeight
                    ? ` @ ${unitPref === 'IMPERIAL' ? (e.targetWeight * LBS_PER_KG).toFixed(1) + 'lbs' : e.targetWeight + 'kg'}`
                    : '';
                  return `${e.exerciseName} (${e.targetSets}×${e.targetReps}${wt})`;
                }).join(", ")}
             </p>
          )}
        </div>

        <div className="flex items-center gap-1 opacity-0 group-hover/card:opacity-100 transition-opacity">
           <button onClick={() => onEdit?.(routine)} title="Edit session" className="p-2.5 text-zinc-600 hover:text-white rounded-xl hover:bg-white/5 transition-all"><Pencil size={14} /></button>
           {onSaveToLibrary && <button onClick={() => onSaveToLibrary(routine)} className="p-2.5 text-zinc-600 hover:text-violet-400 rounded-xl hover:bg-violet-400/5 transition-all"><Star size={14} /></button>}
           <button onClick={() => deleteRoutine.mutate()} disabled={deleteRoutine.isPending} className="p-2.5 text-zinc-600 hover:text-red-500 rounded-xl hover:bg-red-500/5 transition-all"><Trash2 size={14} /></button>
        </div>
      </div>
    </div>
  );
}

// ─── Main Builder Page ───────────────────────────────────────────────────────

export default function WorkoutBuilderPage({
  params,
}: {
  params: Promise<{ memberId: string }>;
}) {
  const { memberId } = use(params);
  const { token } = useAuthStore();

  const { data: memberProfile } = useQuery({
    queryKey: ["trainer-member-profile", memberId],
    queryFn: () => trainerApi.getMemberProfile(memberId, token!),
    enabled: !!token,
    staleTime: 5 * 60_000,
  });

  if (!memberProfile) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <Loader2 size={32} className="text-[#F1C40F] animate-spin" />
        <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Retrieving Vault Data...</p>
      </div>
    );
  }

  // Use the member ID as a key to force component reset when switching members.
  // This avoids useEffect synchronization for unitPref and other local states.
  return <WorkoutBuilderContent key={memberProfile.member.id} memberProfile={memberProfile} token={token!} />;
}

interface TrainerMemberProfile {
  member: {
    id: string;
    fullName: string;
    unitPreference: 'METRIC' | 'IMPERIAL';
    languagePreference: 'EN' | 'KA' | 'RU';
  };
}

function WorkoutBuilderContent({
  memberProfile, token,
}: {
  memberProfile: TrainerMemberProfile; token: string;
}) {
  const memberId = memberProfile.member.id;
  const qc = useQueryClient();

  const { data: plans } = useQuery({
    queryKey: ["trainer-workout-plans", memberId],
    queryFn: () => trainerApi.getMemberWorkoutPlans(memberId, token),
    enabled: !!token,
  });

  const { data: draftTemplates = [] } = useQuery({
    queryKey: ["trainer-draft-templates"],
    queryFn: () => trainerApi.getDraftTemplates(token),
    enabled: !!token,
  });

  // Unit preference: initialized directly from member profile
  const [unitPref, setUnitPref] = useState<'METRIC' | 'IMPERIAL'>(() => {
    return (memberProfile?.member?.unitPreference as 'METRIC' | 'IMPERIAL') ?? 'METRIC';
  });
  
  const memberLangPref = memberProfile?.member?.languagePreference ?? 'EN';

  const [selectedPlanId, setSelectedPlanId] = useState<string | null>(null);
  const currentPlan = (selectedPlanId ? plans?.find((p: TrainerWorkoutPlan) => p.id === selectedPlanId) : null) ?? plans?.[0];

  const [selectedWeek, setSelectedWeek] = useState(1);
  const [selectedDay, setSelectedDay] = useState(0);

  const [showNewPlan, setShowNewPlan] = useState(false);
  const [showAddRoutine, setShowAddRoutine] = useState(false);
  const [editingRoutine, setEditingRoutine] = useState<TrainerWorkoutRoutine | null>(null);
  const [showDayImport, setShowDayImport] = useState(false);
  const [showWeekImport, setShowWeekImport] = useState(false);
  const [showTemplateLibrary, setShowTemplateLibrary] = useState(false);
  const [saveDayDialog, setSaveDayDialog] = useState(false);
  const [showCopyDay, setShowCopyDay] = useState(false);
  const [libraryNameInput, setLibraryNameInput] = useState("");

  const numWeeks = currentPlan?.numWeeks ?? 1;
  const safeWeek = Math.min(selectedWeek, numWeeks);
  const safeDay = Math.min(selectedDay, 6);
  const scheduledDateForDay = currentPlan?.startDate ? getScheduledDate(currentPlan.startDate, safeWeek, safeDay) : null;

  const planRoutines = currentPlan?.routines;
  const planStartDate = currentPlan?.startDate;

  const dayRoutines = (() => {
    if (!planStartDate) return [];
    const target = getScheduledDate(planStartDate, safeWeek, safeDay);
    return [...(planRoutines ?? [])]
      .filter((r) => r.scheduledDate && normalizeDate(r.scheduledDate) === target)
      .sort((a, b) => a.orderIndex - b.orderIndex);
  })();

  const routineTemplates = draftTemplates.filter((t) => t.type === "workout_day");
  const weekTemplates    = draftTemplates.filter((t) => t.type === "workout_week");

  const dayTotals = {
    sets: dayRoutines.reduce((s, r) => s + r.exercises.reduce((es, e) => es + (e.targetSets || 0), 0), 0),
    sessions: dayRoutines.length,
  };

  // Mutations
  const deletePlan = useMutation({
    mutationFn: (id: string) => trainerApi.deleteWorkoutPlan(id, token!),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] }),
  });

  const activatePlan = useMutation({
    mutationFn: (id: string) => trainerApi.activateWorkoutPlan(id, token!),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] }),
  });

  const [selectedRoutineForLibrary, setSelectedRoutineForLibrary] = useState<TrainerWorkoutRoutine | null>(null);

  const saveDayToLibrary = useMutation({
    mutationFn: async ({ name, routine }: { name: string; routine: TrainerWorkoutRoutine }) => {
      const exercises: TrainerTemplateExercise[] = routine.exercises.map(e => ({
        exerciseName: e.exerciseName,
        targetSets: e.targetSets,
        targetReps: String(e.targetReps || '10'),
        targetWeight: e.targetWeight ?? undefined,
        restSeconds: e.restSeconds ?? undefined,
        rpe: e.rpe ?? undefined,
      }));
      await trainerApi.createDraftTemplate({
        type: "workout_day",
        name,
        data: { routineName: routine.name, exercises } as TrainerTemplateWorkoutDayData
      }, token!);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-draft-templates"] });
      setSaveDayDialog(false);
      setLibraryNameInput("");
      setSelectedRoutineForLibrary(null);
      showToast("Saved to vault ✓");
    }
  });

  const [copyTargetWeek, setCopyTargetWeek] = useState(1);
  const [copyTargetDay, setCopyTargetDay] = useState(0);

  const copyDayMutation = useMutation({
    mutationFn: async ({ fromWeek, fromDay, toWeek, toDay }: { fromWeek: number; fromDay: number; toWeek: number; toDay: number }) => {
      const fromTarget = getScheduledDate(currentPlan!.startDate!, fromWeek, fromDay);
      const toTarget   = getScheduledDate(currentPlan!.startDate!, toWeek, toDay);
      const sourceRoutines = currentPlan!.routines.filter(r => r.scheduledDate && normalizeDate(r.scheduledDate) === fromTarget);
      
      for (const r of sourceRoutines) {
        const res = await trainerApi.addRoutine(currentPlan!.id, { name: r.name, scheduledDate: toTarget, isDraft: r.isDraft }, token!);
        await trainerApi.addExercises(res.id, r.exercises.map(e => ({
          exerciseName: e.exerciseName,
          targetSets: e.targetSets,
          targetReps: parseInt(String(e.targetReps || '10')) || 10,
          targetWeight: Number(e.targetWeight) || undefined,
          restSeconds: Number(e.restSeconds) || undefined,
          rpe: Number(e.rpe) || undefined,
          progressionNote: e.progressionNote ?? undefined,
        })), token!);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
      setShowCopyDay(false);
    }
  });

  const copyDayToAllWeeksMutation = useMutation({
    mutationFn: async () => {
      for (let w = 1; w <= numWeeks; w++) {
        if (w === safeWeek) continue;
        await copyDayMutation.mutateAsync({ fromWeek: safeWeek, fromDay: safeDay, toWeek: w, toDay: safeDay });
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
      setShowCopyDay(false);
    }
  });

  const moveRoutine = useMutation({
    mutationFn: async ({ id, direction }: { id: string; direction: "up" | "down" }) => {
      const sorted = [...currentPlan!.routines].sort((a, b) => a.orderIndex - b.orderIndex);
      const idx = sorted.findIndex(r => r.id === id);
      if (idx === -1) return;
      const swapIdx = direction === "up" ? idx - 1 : idx + 1;
      if (swapIdx < 0 || swapIdx >= sorted.length) return;
      // Swap and re-assign contiguous orderIndex to avoid collision
      const reindexed = sorted.map((r, i) => ({ ...r, orderIndex: i }));
      const tmp = reindexed[idx].orderIndex;
      reindexed[idx].orderIndex = reindexed[swapIdx].orderIndex;
      reindexed[swapIdx].orderIndex = tmp;
      await Promise.all([
        trainerApi.updateRoutine(reindexed[idx].id, { orderIndex: reindexed[idx].orderIndex }, token!),
        trainerApi.updateRoutine(reindexed[swapIdx].id, { orderIndex: reindexed[swapIdx].orderIndex }, token!),
      ]);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] }),
  });

  const [planName, setPlanName] = useState("");
  const [startDate, setStartDate] = useState(() => new Date().toISOString().split("T")[0]);
  const [newPlanWeeks, setNewPlanWeeks] = useState<number>(4);
  const [planDifficulty, setPlanDifficulty] = useState<"BEGINNER" | "INTERMEDIATE" | "ADVANCED">("INTERMEDIATE");
  const [selectedTrainingDays, setSelectedTrainingDays] = useState<number[]>([0, 2, 4]);

  // Rest days (per plan session — visual only)
  const [restDays, setRestDays] = useState<Set<string>>(new Set());
  function toggleRestDay(dateStr: string) {
    setRestDays(prev => {
      const next = new Set(prev);
      if (next.has(dateStr)) next.delete(dateStr); else next.add(dateStr);
      return next;
    });
  }

  // Toast
  const [toastMsg, setToastMsg] = useState<string | null>(null);
  function showToast(msg: string) {
    setToastMsg(msg);
    setTimeout(() => setToastMsg(null), 2500);
  }

  const handleCreatePlan = async () => {
    if (!planName.trim()) return;
    await trainerApi.createWorkoutPlan(memberId, { name: planName, startDate, numWeeks: newPlanWeeks, difficulty: planDifficulty }, token!);
    await qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
    setShowNewPlan(false);
    setPlanName("");
  };

  return (
    <div>
      <div className="max-w-5xl mx-auto px-6 pt-4 pb-12">
        <Link href={`/dashboard/trainer/members/${memberId}`} className="inline-flex items-center gap-2 text-zinc-500 hover:text-white text-sm mb-6 transition-colors group">
          <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" /> Back to Member
        </Link>

      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <Dumbbell size={20} className="text-[#F1C40F]" />
          <h1 className="text-xl font-bold text-white uppercase tracking-tight leading-none">Workout Builder</h1>
        </div>
        {!showNewPlan && (
          <button onClick={() => setShowNewPlan(true)} className="flex items-center gap-1.5 px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 text-xs font-bold rounded-lg transition-colors">
            <Plus size={13} /> New Plan
          </button>
        )}
      </div>

      {showNewPlan && (
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-5 mb-6 space-y-4 animate-in slide-in-from-top-4 duration-300">
          <h2 className="text-sm font-bold text-white flex items-center gap-2 uppercase tracking-widest">
            <Calendar size={14} className="text-[#F1C40F]" />
            New Workout Plan
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="space-y-4">
              <div>
                <label className="amirani-label !mb-2.5">Plan Name</label>
                <input value={planName} onChange={(e) => setPlanName(e.target.value)} placeholder="e.g. Hypertrophy Block A" className="amirani-input h-10" />
              </div>
              <div>
                <ThemedDatePicker label="Launch Date" value={startDate} onChange={(val) => setStartDate(val)} />
              </div>
            </div>
            <div className="space-y-4">
              <div>
                <label className="amirani-label !mb-2.5">Cycle Duration</label>
                <div className="flex gap-2">
                  {WEEK_OPTIONS.map((w) => (
                    <button key={w} onClick={() => setNewPlanWeeks(w)} className={`flex-1 py-1.5 text-xs font-bold rounded-lg border transition-colors ${newPlanWeeks === w ? "bg-[#F1C40F]/15 border-[#F1C40F]/40 text-[#F1C40F]" : "bg-zinc-950 border-zinc-700 text-zinc-600"}`}>
                      {w}w
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="amirani-label !mb-2.5">Difficulty</label>
                <div className="flex gap-2">
                  {(["BEGINNER", "INTERMEDIATE", "ADVANCED"] as const).map((d) => (
                    <button
                      key={d}
                      onClick={() => setPlanDifficulty(d)}
                      className={`flex-1 py-1.5 text-xs font-bold rounded-lg border transition-colors ${planDifficulty === d ? "bg-[#F1C40F]/15 border-[#F1C40F]/40 text-[#F1C40F]" : "bg-zinc-950 border-zinc-700 text-zinc-600"}`}
                    >
                      {d.charAt(0) + d.slice(1).toLowerCase()}
                    </button>
                  ))}
                </div>
              </div>
            </div>
            <div className="space-y-4">
              <div>
                <label className="amirani-label !mb-2.5">Execution Days</label>
                <div className="flex gap-1 justify-between">
                   {DAYS_OF_WEEK.map((d, i) => (
                     <button key={i} onClick={() => setSelectedTrainingDays(prev => prev.includes(i) ? prev.filter((x: number) => x !== i) : [...prev, i])} className={`w-8 h-8 rounded-lg border flex items-center justify-center text-[10px] font-black transition-all ${selectedTrainingDays.includes(i) ? "bg-[#F1C40F] text-black border-[#F1C40F]" : "bg-zinc-950 border-zinc-800 text-zinc-600 hover:text-zinc-400"}`}>
                       {d}
                     </button>
                   ))}
                </div>
              </div>
            </div>
          </div>
          <div className="flex gap-2 pt-2 border-t border-zinc-800/50">
            <button onClick={handleCreatePlan} disabled={!planName.trim()} className="flex items-center gap-2 px-6 py-2 bg-[#F1C40F] text-black text-xs font-bold rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 transition-colors">Create Plan</button>
            <button onClick={() => setShowNewPlan(false)} className="px-5 py-2 bg-zinc-800 text-zinc-400 text-xs font-bold rounded-lg hover:bg-zinc-700 transition-colors">Cancel</button>
          </div>
        </div>
      )}

      {plans && plans.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mb-5 items-center">
          {plans.map((p) => (
            <div key={p.id} className="flex items-center gap-0.5">
              <button
                onClick={() => { setSelectedPlanId(p.id); setSelectedWeek(1); setSelectedDay(0); setShowAddRoutine(false); }}
                className={`px-3 h-9 text-xs font-bold rounded-l-lg border flex items-center transition-colors ${currentPlan?.id === p.id ? "bg-[#F1C40F]/15 border-[#F1C40F]/40 text-[#F1C40F]" : "bg-zinc-900 border-zinc-700 text-zinc-400 hover:text-white"}`}
              >
                {p.name} {p.isActive && <span className="ml-1.5 text-emerald-400">●</span>}
              </button>
              <button onClick={() => deletePlan.mutate(p.id)} disabled={deletePlan.isPending} className={`px-2.5 h-9 border-y border-r rounded-r-lg flex items-center transition-colors text-zinc-700 hover:text-red-500 ${currentPlan?.id === p.id ? "border-[#F1C40F]/40" : "bg-zinc-900 border-zinc-700"}`}>
                <Trash2 size={13} />
              </button>
            </div>
          ))}
        </div>
      )}

      {currentPlan && (
        <div className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden shadow-2xl animate-in fade-in duration-500">
          <div className="px-6 py-5 border-b border-zinc-800/80 bg-zinc-900/20 flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap mb-1">
                <h2 className="font-bold text-white uppercase tracking-tight italic">{currentPlan.name}</h2>
                <span className={`px-1.5 py-0.5 text-[9px] font-black uppercase tracking-wider rounded border ${currentPlan.isActive ? "bg-emerald-500/15 border-emerald-500/25 text-emerald-400" : "bg-amber-500/15 border-amber-500/25 text-amber-400"}`}>
                   {currentPlan.isActive ? "Active ●" : "Draft 🛠️"}
                </span>
                <span className="px-1.5 py-0.5 bg-[#F1C40F]/10 border border-[#F1C40F]/25 text-[#F1C40F] text-[9px] font-black uppercase tracking-wider rounded">
                  Trainer Plan
                </span>
              </div>
              <p className="text-xs text-zinc-500">
                {currentPlan.numWeeks} Weeks Duration  ·  Starts {formatDate(currentPlan.startDate!)}
              </p>
            </div>
            <div className="flex items-center gap-1.5 flex-shrink-0">
               <button onClick={() => setShowTemplateLibrary(true)} className="px-3 py-1.5 bg-violet-900/20 border border-violet-700/30 text-violet-400 text-[10px] font-black uppercase tracking-wider rounded-lg hover:bg-violet-800/30 transition-colors">★ Library</button>
               {!currentPlan.isActive && <button onClick={() => activatePlan.mutate(currentPlan.id)} className="px-3 py-1.5 bg-[#F1C40F] text-black text-[10px] font-black uppercase tracking-wider rounded-lg hover:bg-[#F4D03F] transition-colors">Activate Protocol</button>}
            </div>
          </div>

          <div className="px-5 pt-3 flex items-end justify-between border-b border-zinc-800/50 pb-0 flex-wrap gap-4">
            <div className="flex gap-1.5 flex-wrap">
              {Array.from({ length: numWeeks }, (_, i) => i + 1).map(w => {
                const isActive = safeWeek === w;
                return (
                  <button key={w} onClick={() => { setSelectedWeek(w); setSelectedDay(0); setShowAddRoutine(false); }} className={`group relative px-6 py-4 text-xs font-black uppercase tracking-widest transition-all ${isActive ? "text-white" : "text-zinc-500 hover:text-zinc-300"}`}>
                    <span className="relative z-10">Week {w}</span>
                    {isActive && (
                      <>
                        <div className="absolute bottom-0 left-0 right-0 h-1 bg-[#F1C40F] shadow-[0_0_20px_rgba(241,196,15,0.5)] rounded-full animate-in fade-in slide-in-from-bottom-2 duration-500" />
                        <div className="absolute inset-0 bg-[#F1C40F]/5 rounded-t-2xl animate-in fade-in duration-500" />
                      </>
                    )}
                  </button>
                );
              })}
            </div>
            <div className="flex gap-1.5 pb-px flex-wrap justify-end">
               <button onClick={() => setShowWeekImport(v => !v)} className={`px-2 py-1 text-[9px] font-bold uppercase rounded-lg transition-colors border ${showWeekImport ? "bg-[#F1C40F]/10 border-[#F1C40F]/30 text-[#F1C40F]" : "bg-zinc-800/80 border-zinc-700/50 text-zinc-500 hover:text-zinc-300"}`}>Import Week {showWeekImport ? "▴" : "▾"}</button>
            </div>
          </div>

          <div className="px-5 pt-3 pb-0 flex gap-1 overflow-x-auto border-b border-zinc-800/30">
            {Array.from({ length: 7 }).map((_, idx) => {
              const dateStr = getScheduledDate(currentPlan.startDate!, safeWeek, idx);
              const isActive = safeDay === idx;
              const hasContent = currentPlan.routines.some(r => r.scheduledDate && normalizeDate(r.scheduledDate) === dateStr);
              const isRest = !hasContent && restDays.has(dateStr);
              return (
                <button key={idx} onClick={() => { setSelectedDay(idx); setShowAddRoutine(false); }} className={`group relative flex-shrink-0 px-5 py-4 transition-all ${isActive ? "text-white" : "text-zinc-500 hover:text-zinc-300"}`}>
                  <div className="relative z-10">
                    <span className="block text-[10px] font-black uppercase tracking-[0.2em] mb-1">{getDayName(dateStr).slice(0, 3)}</span>
                    <span className="block text-xs font-bold opacity-60 transition-opacity whitespace-nowrap">{formatDate(dateStr)}</span>
                    {hasContent ? (
                      <div className="absolute -top-1 -right-2 w-1 h-1 rounded-full bg-[#F1C40F] shadow-[0_0_5px_rgba(241,196,15,0.8)]" />
                    ) : isRest ? (
                      <div className="absolute -top-1.5 -right-2 text-[10px] leading-none">🛌</div>
                    ) : (
                      <div className="absolute -top-1 -right-2 w-1.5 h-1.5 rounded-full border border-zinc-700 opacity-40" />
                    )}
                  </div>
                  {isActive && (
                    <div className="absolute inset-0 bg-white/[0.03] border-x border-white/5 animate-in fade-in duration-300" />
                  )}
                </button>
              )
            })}
          </div>

          <div className="p-6 space-y-8">
            {/* Daily Summary - Micro Parity */}
            {dayRoutines.length > 0 && (
              <div className="bg-zinc-900/40 border border-zinc-800/60 rounded-xl p-5 flex flex-wrap gap-8 items-center">
                 <MetricBar label="Physical Load" current={dayTotals.sets} target={20} color="text-white" unit="sets" />
                 <div className="w-px h-8 bg-zinc-800/60 hidden sm:block" />
                 <MetricBar label="Protocols" current={dayTotals.sessions} target={3} color="text-[#F1C40F]" unit="sessions" />
                 <div className="w-px h-8 bg-zinc-800/60 hidden sm:block" />
                 <div className="flex-1">
                    <p className="text-[9px] text-zinc-600 font-bold uppercase leading-relaxed italic tracking-tighter">
                       Integrity check: high volume detected. Ensure intra-workout recovery intervals exceed 90s.
                    </p>
                 </div>
              </div>
            )}
            <div className="space-y-4">
              <div className="flex items-center justify-between gap-2">
                 <p className="text-[10px] text-zinc-600 font-black uppercase tracking-widest">
                   {scheduledDateForDay ? getDayName(scheduledDateForDay) : `Day ${safeDay + 1}`}
                   <span className="font-normal normal-case ml-1 text-zinc-700">— {formatDate(scheduledDateForDay ?? "")}</span>
                 </p>
                 <div className="flex items-center gap-1.5 flex-wrap justify-end">
                   {/* Unit toggle */}
                   <div className="flex bg-zinc-900 border border-zinc-800 rounded-lg overflow-hidden">
                     <button
                       onClick={() => setUnitPref('METRIC')}
                       className={`px-2.5 py-1 text-[9px] font-black uppercase tracking-widest transition-all ${unitPref === 'METRIC' ? 'bg-[#F1C40F] text-black' : 'text-zinc-500 hover:text-white'}`}
                     >kg</button>
                     <button
                       onClick={() => setUnitPref('IMPERIAL')}
                       className={`px-2.5 py-1 text-[9px] font-black uppercase tracking-widest transition-all ${unitPref === 'IMPERIAL' ? 'bg-[#F1C40F] text-black' : 'text-zinc-500 hover:text-white'}`}
                     >lbs</button>
                   </div>
                   <button onClick={() => setShowDayImport(v => !v)} className={`px-2 py-1 text-[9px] font-bold uppercase rounded-lg transition-colors border ${showDayImport ? "bg-[#F1C40F]/10 border-[#F1C40F]/30 text-[#F1C40F]" : "bg-zinc-800/80 border-zinc-700/50 text-zinc-500 hover:text-zinc-300"}`}>Import Day {showDayImport ? "▴" : "▾"}</button>
                 </div>
              </div>

              {showWeekImport && (
                 <div className="bg-[#0e1420] border border-zinc-800/80 rounded-2xl overflow-hidden animate-in zoom-in-95 duration-300 shadow-2xl mb-8">
                    <div className="p-4 border-b border-zinc-800 bg-zinc-900/40 flex items-center justify-between">
                       <span className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Select Weekly Performance Block</span>
                       <button onClick={() => setShowWeekImport(false)} className="text-zinc-600 hover:text-white"><X size={14} /></button>
                    </div>
                    <div className="max-h-64 overflow-y-auto divide-y divide-zinc-800/40">
                       {weekTemplates.length === 0 && <p className="p-8 text-center text-xs text-zinc-700 italic">No weekly blocks in vault.</p>}
                       {weekTemplates.map(tpl => {
                          const data = tpl.data as TrainerTemplateWorkoutWeekData;
                          return (
                             <div key={tpl.id} className="flex items-center justify-between px-6 py-4 hover:bg-white/5 transition-colors">
                                <div>
                                   <p className="text-sm font-bold text-zinc-200">{tpl.name}</p>
                                   <p className="text-[9px] text-zinc-600 font-black uppercase mt-0.5 tracking-widest">{data.days?.length || 0} Scheduled Sessions</p>
                                </div>
                                <button 
                                  onClick={async () => {
                                     for (const d of data.days) {
                                        const date = getScheduledDate(currentPlan!.startDate!, safeWeek, d.dayIdx);
                                        const res = await trainerApi.addRoutine(currentPlan!.id, { name: d.routineName, scheduledDate: date }, token!);
                                        await trainerApi.addExercises(res.id, d.exercises.map(e => ({
                                          ...e,
                                          targetReps: parseInt(String(e.targetReps || '10')) || 10
                                        })), token!);
                                     }
                                     qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
                                     setShowWeekImport(false);
                                  }}
                                  className="h-9 px-6 bg-violet-600 text-white text-[10px] font-black uppercase rounded-xl hover:bg-violet-500 transition-all shadow-lg active:scale-95"
                                >
                                   Apply to Week {safeWeek}
                                </button>
                             </div>
                          );
                       })}
                    </div>
                 </div>
              )}

              {showDayImport && (
                 <div className="bg-[#0e1420] border border-zinc-800/80 rounded-2xl overflow-hidden animate-in zoom-in-95 duration-300 shadow-2xl mb-8">
                    <div className="p-4 border-b border-zinc-800 bg-zinc-900/40 flex items-center justify-between">
                       <span className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Pick Movement Stack</span>
                       <button onClick={() => setShowDayImport(false)} className="text-zinc-600 hover:text-white"><X size={14} /></button>
                    </div>
                    <div className="max-h-64 overflow-y-auto divide-y divide-zinc-800/40">
                       {routineTemplates.length === 0 && <p className="p-8 text-center text-xs text-zinc-700 italic">No movement stacks in vault.</p>}
                       {routineTemplates.map(tpl => {
                          const data = tpl.data as TrainerTemplateWorkoutDayData;
                          return (
                             <div key={tpl.id} className="flex items-center justify-between px-6 py-4 hover:bg-white/5 transition-colors">
                                <div>
                                   <p className="text-sm font-bold text-zinc-200">{tpl.name}</p>
                                   <p className="text-[9px] text-zinc-600 font-black uppercase mt-0.5 tracking-widest">{data.exercises?.length || 0} Movements</p>
                                </div>
                                <button 
                                  onClick={async () => {
                                     const res = await trainerApi.addRoutine(currentPlan!.id, { name: data.routineName, scheduledDate: scheduledDateForDay!, isDraft: false }, token!);
                                     await trainerApi.addExercises(res.id, data.exercises.map(e => ({
                                        ...e,
                                        targetReps: parseInt(String(e.targetReps || '10')) || 10
                                     })), token!);
                                     qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
                                     setShowDayImport(false);
                                  }}
                                  className="h-9 px-6 bg-[#F1C40F] text-black text-[10px] font-black uppercase rounded-xl hover:bg-[#F4D03F] transition-all shadow-lg active:scale-95"
                                >
                                   Apply Stack
                                </button>
                             </div>
                          );
                       })}
                    </div>
                 </div>
              )}

              <div className="space-y-4">
                 {/* Copy Day panel - Parity with Diet */}
                 {showCopyDay && (
                   <div className="bg-zinc-950/60 border border-zinc-700/50 rounded-2xl p-6 space-y-6 animate-in slide-in-from-top-2 duration-300">
                     <p className="text-[10px] font-black uppercase tracking-widest text-[#F1C40F] italic">
                       Duplicate {scheduledDateForDay ? getDayName(scheduledDateForDay) : "Day"} (Week {safeWeek}) to…
                     </p>
                     <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                       <div>
                         <label className="block text-[9px] text-zinc-500 uppercase font-black mb-3 tracking-widest">Target Week</label>
                         <div className="flex gap-2 flex-wrap">
                           {Array.from({ length: numWeeks }, (_, i) => i + 1).map((w) => (
                             <button
                               key={w}
                               onClick={() => setCopyTargetWeek(w)}
                               className={`px-4 py-2 text-[10px] font-black rounded-lg border transition-all ${
                                 copyTargetWeek === w
                                   ? "bg-[#F1C40F]/15 border-[#F1C40F]/50 text-[#F1C40F]"
                                   : "bg-zinc-900 border-zinc-800 text-zinc-600 hover:text-zinc-400"
                               }`}
                             >
                               W{w}
                             </button>
                           ))}
                         </div>
                       </div>
                       <div>
                         <label className="block text-[9px] text-zinc-500 uppercase font-black mb-3 tracking-widest">Target Day</label>
                         <div className="flex gap-1.5 flex-wrap">
                           {DAYS_OF_WEEK.map((d, idx) => (
                               <button
                                 key={idx}
                                 onClick={() => setCopyTargetDay(idx)}
                                 className={`w-9 h-9 text-[10px] font-black rounded-lg border flex items-center justify-center transition-all ${
                                   copyTargetDay === idx
                                     ? "bg-[#F1C40F] text-black border-[#F1C40F]"
                                     : "bg-zinc-900 border-zinc-800 text-zinc-600 hover:text-zinc-400"
                                 }`}
                               >
                                 {d}
                               </button>
                           ))}
                         </div>
                       </div>
                     </div>
                     <div className="flex flex-wrap gap-2 pt-2">
                       <button
                         onClick={() => copyDayMutation.mutate({ fromWeek: safeWeek, fromDay: safeDay, toWeek: copyTargetWeek, toDay: copyTargetDay })}
                         disabled={copyDayMutation.isPending || copyDayToAllWeeksMutation.isPending || (copyTargetWeek === safeWeek && copyTargetDay === safeDay)}
                         className="flex-1 min-w-[140px] h-11 bg-[#F1C40F] text-black text-[10px] font-black uppercase tracking-widest rounded-xl hover:bg-[#F4D03F] shadow-xl disabled:opacity-50 transition-all"
                       >
                         {copyDayMutation.isPending ? "Copying..." : "Copy to this Day"}
                       </button>
                       {numWeeks > 1 && (
                         <button
                           onClick={() => copyDayToAllWeeksMutation.mutate()}
                           disabled={copyDayMutation.isPending || copyDayToAllWeeksMutation.isPending}
                           className="flex-1 min-w-[140px] h-11 bg-blue-600 text-white text-[10px] font-black uppercase tracking-widest rounded-xl hover:bg-blue-500 shadow-[0_8px_30px_rgba(37,99,235,0.2)] disabled:opacity-50 transition-all"
                         >
                           {copyDayToAllWeeksMutation.isPending ? "Replicating..." : `Copy to all ${numWeeks - 1} week${numWeeks - 1 !== 1 ? "s" : ""}`}
                         </button>
                       )}
                       <button
                         onClick={() => setShowCopyDay(false)}
                         className="px-6 h-11 bg-zinc-900 text-zinc-600 text-[10px] font-black uppercase rounded-xl border border-zinc-800 hover:text-white transition-all"
                       >
                         Dismiss
                       </button>
                     </div>
                   </div>
                 )}

                 {dayRoutines.map((r, idx) => (
                    <ExerciseDisplayCard
                      key={r.id}
                      routine={r}
                      token={token!}
                      memberId={memberId}
                      onSaveToLibrary={(r) => { setSelectedRoutineForLibrary(r); setLibraryNameInput(r.name); setSaveDayDialog(true); }}
                      onEdit={setEditingRoutine}
                      unitPref={unitPref}
                      isFirst={idx === 0}
                      isLast={idx === dayRoutines.length - 1}
                      onMoveUp={() => moveRoutine.mutate({ id: r.id, direction: "up" })}
                      onMoveDown={() => moveRoutine.mutate({ id: r.id, direction: "down" })}
                    />
                 ))}
                 {!showAddRoutine && (
                    <button onClick={() => setShowAddRoutine(true)} className="w-full h-14 flex items-center justify-center gap-2 border border-dashed border-zinc-700 rounded-xl text-zinc-500 hover:text-[#F1C40F] hover:border-[#F1C40F]/40 hover:bg-[#F1C40F]/5 transition-all text-sm font-medium">
                       <Plus size={16} /> Add Session to {scheduledDateForDay ? getDayName(scheduledDateForDay) : `Day ${safeDay + 1}`}
                    </button>
                 )}
                 {dayRoutines.length === 0 && scheduledDateForDay && (
                    <button
                      onClick={() => toggleRestDay(scheduledDateForDay)}
                      className={`w-full h-9 flex items-center justify-center gap-2 rounded-xl text-xs font-bold transition-all border ${
                        restDays.has(scheduledDateForDay)
                          ? "bg-zinc-800/60 border-zinc-700 text-zinc-400 hover:border-red-500/30 hover:text-red-400"
                          : "bg-transparent border-zinc-800/50 text-zinc-700 hover:text-zinc-400 hover:border-zinc-700"
                      }`}
                    >
                      {restDays.has(scheduledDateForDay) ? "🛌 Rest Day — click to clear" : "Mark as Rest Day"}
                    </button>
                 )}
              </div>

            </div>
          </div>
        </div>
      )}

      {/* Template Library Modal - 100% Parity with Diet Library */}
      {showTemplateLibrary && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center p-4">
           <div className="absolute inset-0 bg-black/90 backdrop-blur-md animate-in fade-in duration-500" onClick={() => setShowTemplateLibrary(false)} />
           <div className="relative w-full max-w-6xl h-[85vh] bg-[#121721] border border-zinc-800 rounded-[32px] overflow-hidden shadow-2xl animate-in zoom-in-95 duration-500 border-t-[#F1C40F]/20 flex flex-col">
              <div className="p-8 border-b border-zinc-800 bg-zinc-900/40 flex items-center justify-between">
                <div>
                   <h2 className="text-2xl font-black text-white italic uppercase tracking-tighter">My Protocol Library</h2>
                   <p className="text-[10px] text-zinc-500 font-bold uppercase tracking-widest mt-1">Global Training Templates</p>
                </div>
                <button onClick={() => setShowTemplateLibrary(false)} className="w-12 h-12 flex items-center justify-center bg-zinc-800 border border-white/5 text-zinc-400 hover:text-white rounded-full hover:rotate-90 transition-all"><X size={20} /></button>
              </div>
              
              <div className="p-8 flex-1 overflow-y-auto pb-20 scrollbar-hide">
                 <div className="space-y-12">
                   {weekTemplates.length === 0 && <p className="text-center py-20 text-zinc-600 italic">No cycle templates found in your library.</p>}
                   {weekTemplates.map((tpl, wIdx) => {
                     const data = tpl.data as TrainerTemplateWorkoutWeekData;
                     return (
                        <div key={tpl.id} className="relative">
                           <h3 className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.3em] mb-8 flex items-center gap-4">
                              <span>Series {wIdx + 1}: {tpl.name}</span>
                              <div className="h-px flex-1 bg-zinc-800/40" />
                           </h3>
                           <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                              {data.days?.map((d, dIdx) => (
                                 <div key={dIdx} className="bg-zinc-900/40 border border-zinc-800/50 rounded-2xl p-5 group hover:border-[#F1C40F]/30 transition-all relative">
                                    <div className="absolute top-4 right-4 text-[9px] font-black text-zinc-800 uppercase italic">ENTRY {dIdx + 1}</div>
                                    <p className="text-[10px] font-black text-zinc-500 uppercase mb-4 tracking-widest truncate">{d.routineName}</p>
                                    <div className="h-28 flex flex-col items-center justify-center border border-dashed border-zinc-800 rounded-xl mb-5 group-hover:bg-[#F1C40F]/5 transition-all text-zinc-700">
                                       <Dumbbell size={20} className="mb-2 group-hover:text-[#F1C40F] transition-colors" />
                                       <span className="text-[9px] font-bold uppercase">{d.exercises?.length || 0} Movements</span>
                                    </div>
                                    <button 
                                      onClick={async () => {
                                        const res = await trainerApi.addRoutine(currentPlan!.id, { name: d.routineName, scheduledDate: scheduledDateForDay!, isDraft: false }, token!);
                                        await trainerApi.addExercises(res.id, d.exercises.map(e => ({
                                          ...e,
                                          targetReps: parseInt(String(e.targetReps || '10')) || 10
                                        })), token!);
                                        qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
                                        setShowTemplateLibrary(false);
                                      }}
                                      className="w-full py-3 bg-zinc-800 text-[10px] font-black uppercase text-zinc-500 rounded-xl group-hover:bg-[#F1C40F] group-hover:text-black transition-all shadow-xl"
                                    >
                                      Apply Block
                                    </button>
                                 </div>
                              ))}
                           </div>
                        </div>
                     );
                   })}
                 </div>
              </div>
           </div>
        </div>
      )}

      {saveDayDialog && (
         <div className="fixed inset-0 z-[250] flex items-center justify-center p-4">
            <div className="absolute inset-0 bg-black/80 backdrop-blur-sm" onClick={() => setSaveDayDialog(false)} />
            <div className="relative bg-[#0e1420] border border-zinc-800 rounded-xl p-6 w-full max-w-sm shadow-2xl animate-in zoom-in-95 duration-200">
               <h3 className="text-lg font-black text-white italic uppercase tracking-widest mb-4">Archive to Library</h3>
               <p className="text-xs text-zinc-500 mb-6">Archive this daily protocol for reuse across all members.</p>
               <input autoFocus value={libraryNameInput} onChange={(e) => setLibraryNameInput(e.target.value)} placeholder="Entry label..." className="w-full h-11 bg-zinc-950 border border-zinc-800 rounded-xl px-4 text-sm text-white mb-6 outline-none focus:border-[#F1C40F]/40" />
               <div className="flex gap-2">
                  <button onClick={() => { if (selectedRoutineForLibrary) saveDayToLibrary.mutate({ name: libraryNameInput, routine: selectedRoutineForLibrary }); }} disabled={saveDayToLibrary.isPending || !libraryNameInput.trim() || !selectedRoutineForLibrary} className="flex-1 h-11 bg-violet-600 text-white text-[10px] font-black uppercase rounded-lg disabled:opacity-50">Save Entry</button>
                  <button onClick={() => setSaveDayDialog(false)} className="px-6 h-11 bg-zinc-800 text-zinc-400 text-[10px] font-black uppercase rounded-lg">Cancel</button>
               </div>
            </div>
         </div>
      )}

            </div>

      {/* Toast */}
      {toastMsg && (
        <div className="fixed bottom-28 left-1/2 -translate-x-1/2 z-[500] px-5 py-2.5 bg-zinc-900 border border-[#F1C40F]/30 text-white text-xs font-bold rounded-xl shadow-2xl animate-in slide-in-from-bottom-4 duration-300 whitespace-nowrap">
          {toastMsg}
        </div>
      )}

      {/* Magic Action Footer */}
      {currentPlan && (
        <MagicActionFooter
          addLabel="Add Session"
          onAdd={() => setShowAddRoutine(true)}
          onImport={() => setShowDayImport(v => !v)}
          onLibrary={() => setShowTemplateLibrary(true)}
          onCopy={dayRoutines.length > 0 ? () => setShowCopyDay(v => !v) : undefined}
          hasItems={dayRoutines.length > 0}
          isDraft={!currentPlan.isActive}
          onActivate={!currentPlan.isActive ? () => activatePlan.mutate(currentPlan.id) : undefined}
        />
      )}

      {/* Add Routine Modal Overlay - 100% Parity with AddMeal Modal */}
      {showAddRoutine && currentPlan && (
        <div className="fixed inset-0 z-[150] flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/80 backdrop-blur-sm animate-in fade-in duration-300" onClick={() => setShowAddRoutine(false)} />
          <div className="relative w-full max-w-3xl animate-in zoom-in-95 fade-in duration-300 max-h-[90vh] overflow-y-auto rounded-xl">
            <AddRoutineForm
              planId={currentPlan.id}
              scheduledDate={scheduledDateForDay!}
              token={token!}
              memberId={memberId}
              unitPref={unitPref}
              lang={memberLangPref}
              onDone={() => {
                setShowAddRoutine(false);
                qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
              }}
            />
          </div>
        </div>
      )}

      {/* Edit Routine Modal */}
      {editingRoutine && (
        <EditRoutineModal
          routine={editingRoutine}
          token={token!}
          memberId={memberId}
          unitPref={unitPref}
          lang={memberLangPref}
          onDone={() => setEditingRoutine(null)}
        />
      )}

      {/* AI Gen: disabled — button is greyed out in footer, modal removed */}
    </div>
  );
}
