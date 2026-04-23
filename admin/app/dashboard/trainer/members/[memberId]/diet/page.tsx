"use client";

import { useState, useMemo, use, useEffect } from "react";
import { useAuthStore } from "@/lib/auth-store";
import {
  useQuery, useMutation, useQueryClient,
} from "@tanstack/react-query";
import {
  trainerApi,
  type TrainerDietPlan,
  type TrainerMeal,
  type TrainerMealIngredient,
  type TrainerMealItems,
  type TrainerAssignedMember,
  type TrainerFoodItem,
  type TrainerDraftTemplate,
  type TrainerTemplateMeal,
} from "@/lib/api";
import {
  ArrowLeft, Plus, ClipboardList, X, Calendar,
  Search, Check, Pencil, Trash2, Flame,
  Clock, Star, Loader2, Droplets, Settings, Zap,
} from "lucide-react";
import Link from "next/link";
import { ThemedDatePicker } from "@/components/ui/ThemedDatePicker";
import { ThemedTimePicker } from "@/components/ui/ThemedTimePicker";
import { CustomSelect } from "@/components/ui/Select";
import { MagicActionFooter } from "../workout/components/MagicActionFooter";

// ─── Constants ────────────────────────────────────────────────────────────────

const WEEK_OPTIONS = [1, 2, 3, 4] as const;

const MEAL_SLOTS = [
  { key: "BREAKFAST",       label: "Breakfast",       emoji: "🌅", hour: 7  },
  { key: "MORNING_SNACK",   label: "Morning Snack",   emoji: "🍎", hour: 10 },
  { key: "LUNCH",           label: "Lunch",           emoji: "🥗", hour: 12 },
  { key: "AFTERNOON_SNACK", label: "Afternoon Snack", emoji: "🥤", hour: 15 },
  { key: "DINNER",          label: "Dinner",          emoji: "🍽️", hour: 19 },
] as const;

type MealSlotKey = (typeof MEAL_SLOTS)[number]["key"];

const UNITS = ["g", "oz", "cup", "tbsp", "tsp", "piece", "cap", "scoop"] as const;
type UnitType = (typeof UNITS)[number];

const UNIT_TO_GRAMS: Record<UnitType, number> = {
  g: 1, oz: 28.35, cup: 240, tbsp: 15, tsp: 5, piece: 100, cap: 0.5, scoop: 30,
};

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


function getMealSlot(key: string | null) {
  return MEAL_SLOTS.find((s) => s.key === key) ?? {
    key: key ?? "", label: key?.replace(/_/g, " ") ?? "Meal", emoji: "🍴", hour: 12,
  };
}

function slotOrder(key: string | null): number {
  const idx = MEAL_SLOTS.findIndex((s) => s.key === key);
  return idx === -1 ? 99 : idx;
}

function toGrams(amount: number, unit: UnitType): number {
  return Math.round(amount * (UNIT_TO_GRAMS[unit] ?? 1) * 100) / 100;
}



function formatDate(dateStr: string): string {
  if (!dateStr) return "";
  const norm = normalizeDate(dateStr);
  const dateObj = new Date(norm + "T00:00:00");
  if (isNaN(dateObj.getTime())) return "";
  return dateObj.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}



// MagicActionFooter imported from shared component above

// ─── Ingredient row state ─────────────────────────────────────────────────────

interface IngRow {
  id: string;
  name: string;
  nameEn?: string;   // English name for cross-language audit trail
  foodItemId?: string;
  amount: string;
  unit: UnitType;
  foodItem?: TrainerFoodItem;
  manualCals: string;
  manualProtein: string;
  manualCarbs: string;
  manualFats: string;
}

function emptyRow(unitPref: 'METRIC' | 'IMPERIAL' = 'METRIC'): IngRow {
  return {
    id: Math.random().toString(36).slice(2),
    name: "", amount: "", unit: unitPref === 'IMPERIAL' ? "oz" : "g",
    manualCals: "", manualProtein: "", manualCarbs: "", manualFats: "",
  };
}

function rowMacros(r: IngRow) {
  return {
    calories: parseFloat(r.manualCals) || 0,
    protein: parseFloat(r.manualProtein) || 0,
    carbs: parseFloat(r.manualCarbs) || 0,
    fats: parseFloat(r.manualFats) || 0,
  };
}

function rowToIngredient(r: IngRow): TrainerMealIngredient {
  const amt = parseFloat(r.amount) || 0;
  const macros = rowMacros(r);
  return {
    item: r.name,
    ...(r.nameEn && r.nameEn !== r.name && { itemEn: r.nameEn }),
    ...(r.foodItemId && { foodItemId: r.foodItemId }),
    amount: amt,
    unit: r.unit,
    grams: toGrams(amt, r.unit),
    calories: macros.calories,
    protein: macros.protein,
    carbs: macros.carbs,
    fats: macros.fats,
  };
}

function ingredientToRow(ing: TrainerMealIngredient): IngRow {
  return {
    id: Math.random().toString(36).slice(2),
    name: ing.item,
    ...(ing.itemEn   && { nameEn: ing.itemEn }),
    ...(ing.foodItemId && { foodItemId: ing.foodItemId }),
    amount: String(ing.amount ?? ""),
    unit: ing.unit ?? "g",
    manualCals: String(ing.calories ?? ""),
    manualProtein: String(ing.protein ?? ""),
    manualCarbs: String(ing.carbs ?? ""),
    manualFats: String(ing.fats ?? ""),
  };
}

// ─── Macro progress bar ───────────────────────────────────────────────────────

function MacroBar({
  label, current, target, color, unit = "g",
}: {
  label: string; current: number; target: number; color: string; unit?: string;
}) {
  const pct = target > 0 ? Math.min((current / target) * 100, 100) : 0;
  const over = target > 0 && current > target;
  const barColor = over
    ? "bg-red-500"
    : color.replace("text-", "bg-").replace(/\d+$/, "500");

  return (
    <div>
      <div className="flex items-center justify-between mb-1">
        <span className="text-[9px] text-zinc-500 uppercase font-black tracking-widest">{label}</span>
        <span className={`text-[10px] font-bold ${over ? "text-red-400" : color}`}>
          {Math.round(current)}{unit}
          <span className="text-zinc-600 font-normal ml-0.5">/{target}{unit}</span>
        </span>
      </div>
      <div className="h-1.5 bg-zinc-800 rounded-full overflow-hidden">
        <div className={`h-full rounded-full transition-all ${barColor}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

// ─── Ingredient editor with food search + custom food save ───────────────────

function FoodSearchDropdown({
  token, onSelect, lang = 'EN',
}: {
  token: string;
  onSelect: (food: import("@/lib/api").TrainerFoodItem) => void;
  lang?: 'EN' | 'KA' | 'RU';
}) {
  const [q, setQ] = useState("");
  const [open, setOpen] = useState(false);

  const { data: results = [], isFetching } = useQuery({
    queryKey: ["food-search", q, lang],
    queryFn: () => trainerApi.searchFood(q, token, lang),
    enabled: q.length >= 2,
    staleTime: 30_000,
  });

  const { data: myFoods = [] } = useQuery({
    queryKey: ["food-mine"],
    queryFn: () => trainerApi.getMyCustomFoods(token),
    staleTime: 60_000,
  });


  function handleInput(val: string) {
    setQ(val);
    setOpen(val.length >= 2);
  }

  // Merge custom foods first if they match query
  const filtered = q.length >= 2
    ? [
        ...myFoods.filter((f) => f.name.toLowerCase().includes(q.toLowerCase())),
        ...results.filter((r) => !myFoods.some((f) => f.id === r.id)),
      ].slice(0, 12)
    : myFoods.slice(0, 8);

  return (
    <div className="relative flex-1">
      <div className="relative">
        <Search size={14} className="pointer-events-none" />
        <input
          value={q}
          onChange={(e) => handleInput(e.target.value)}
          onFocus={() => setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 300)}
          placeholder="Search food database…"
          className="amirani-input amirani-input-with-icon"
        />
        {isFetching && (
          <Loader2 size={11} className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-500 animate-spin" />
        )}
      </div>

      {open && (q.length >= 2 || myFoods.length > 0) && (
        <div className="absolute z-50 top-full mt-1 left-0 right-0 bg-zinc-900 border border-zinc-700 rounded-xl shadow-xl overflow-hidden max-h-72 overflow-y-auto">
          {myFoods.length > 0 && q.length < 2 && (
            <p className="px-3 py-1.5 text-[9px] text-zinc-500 font-black uppercase tracking-widest border-b border-zinc-800">My Custom Foods</p>
          )}
          {filtered.length === 0 && !isFetching && (
            <p className="px-3 py-2.5 text-xs text-zinc-500 text-center">No results — fill macros manually below</p>
          )}
          {filtered.map((food) => (
            <button
              key={food.id ?? food.name}
              onMouseDown={() => {
                onSelect(food);
                setQ(food.name);
                setOpen(false);
              }}
              className="w-full text-left px-3 py-2 hover:bg-zinc-800 transition-colors border-b border-zinc-800/60 last:border-0"
            >
              <div className="flex items-center justify-between gap-2">
                <div className="min-w-0">
                  <p className="text-xs text-white font-medium truncate">{food.name}</p>
                  {food.brand && <p className="text-[10px] text-zinc-500 truncate">{food.brand}</p>}
                </div>
                <div className="flex gap-2 shrink-0 text-[10px]">
                  <span className="text-white font-bold">{food.calories}<span className="text-zinc-500 font-normal">kcal</span></span>
                  <span className="text-blue-400">{food.protein}P</span>
                  <span className="text-yellow-400">{food.carbs}C</span>
                  <span className="text-red-400">{food.fats}F</span>
                  {food.source === "TRAINER" && <Star size={9} className="text-[#F1C40F] self-center" />}
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function SaveCustomFoodButton({
  row, token,
}: {
  row: IngRow;
  token: string;
}) {
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const qc = useQueryClient();

  const canSave = row.name.trim().length > 0
    && parseFloat(row.manualCals) > 0
    && parseFloat(row.manualProtein) >= 0
    && parseFloat(row.manualCarbs) >= 0
    && parseFloat(row.manualFats) >= 0;

  async function handleSave() {
    if (!canSave || saving) return;
    setSaving(true);
    try {
      await trainerApi.createCustomFood({
        name: row.name.trim(),
        calories: parseFloat(row.manualCals),
        protein: parseFloat(row.manualProtein),
        carbs: parseFloat(row.manualCarbs),
        fats: parseFloat(row.manualFats),
      }, token);
      qc.invalidateQueries({ queryKey: ["food-mine"] });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } finally {
      setSaving(false);
    }
  }

  if (!canSave) return null;

  return (
    <button
      onClick={handleSave}
      title="Save as my custom food for reuse"
      className={`flex items-center gap-1 px-2 py-1 rounded-lg text-[10px] font-semibold transition-colors ${
        saved
          ? "bg-[#F1C40F]/20 text-[#F1C40F]"
          : "bg-zinc-800 text-zinc-400 hover:text-[#F1C40F] hover:bg-[#F1C40F]/10"
      }`}
    >
      {saving ? <Loader2 size={10} className="animate-spin" /> : <Star size={10} />}
      {saved ? "Saved!" : "Save food"}
    </button>
  );
}

function IngredientEditor({
  rows, onChange, token, lang = 'EN', unitPref = 'METRIC',
}: {
  rows: IngRow[];
  onChange: (rows: IngRow[]) => void;
  token: string;
  lang?: 'EN' | 'KA' | 'RU';
  unitPref?: 'METRIC' | 'IMPERIAL';
}) {
  function update(id: string, patch: Partial<IngRow>) {
    onChange(rows.map((r) => {
      if (r.id !== id) return r;
      const updated = { ...r, ...patch };
      // When amount or unit changes and a food item is linked, recalculate macros from per-100g baseline
      if (('amount' in patch || 'unit' in patch) && updated.foodItem) {
        const food = updated.foodItem;
        const grams = toGrams(parseFloat(updated.amount) || 0, updated.unit);
        updated.manualCals    = String(Math.round((food.calories / 100) * grams));
        updated.manualProtein = String(Math.round((food.protein  / 100) * grams * 10) / 10);
        updated.manualCarbs   = String(Math.round((food.carbs    / 100) * grams * 10) / 10);
        updated.manualFats    = String(Math.round((food.fats     / 100) * grams * 10) / 10);
      }
      return updated;
    }));
  }
  function remove(id: string) {
    onChange(rows.filter((r) => r.id !== id));
  }
  function applyFood(id: string, food: import("@/lib/api").TrainerFoodItem) {
    // Macros are per 100g — pre-fill amount as 100g and auto-calculate
    const grams = 100;
    update(id, {
      name: food.name,
      nameEn: food.nameEn ?? food.name,
      foodItemId: food.id,
      amount: String(grams),
      unit: "g",
      foodItem: food,
      manualCals:    String(Math.round(food.calories)),
      manualProtein: String(Math.round(food.protein * 10) / 10),
      manualCarbs:   String(Math.round(food.carbs * 10) / 10),
      manualFats:    String(Math.round(food.fats * 10) / 10),
    });
  }

  return (
    <div className="space-y-2">
      {rows.map((row, idx) => (
        <div key={row.id} className="bg-zinc-900/80 border border-zinc-700/60 rounded-xl p-3 space-y-2">
          {/* Row header: search or name input */}
          <div className="flex items-center gap-2">
            <span className="text-[9px] text-zinc-600 font-black w-4 h-[48px] flex items-center justify-center shrink-0">{idx + 1}</span>
            {row.foodItem ? (
              // Food selected from DB — show name + clear button
              <div className="flex-1 flex items-center gap-1.5 bg-zinc-800 border border-[#F1C40F]/30 rounded-lg px-2.5 py-1.5">
                <Star size={10} className="text-[#F1C40F] shrink-0" />
                <span className="text-sm text-white truncate flex-1">{row.name}</span>
                <button onClick={() => update(row.id, { foodItem: undefined, foodItemId: undefined, name: "", manualCals: "", manualProtein: "", manualCarbs: "", manualFats: "" })} className="text-zinc-600 hover:text-red-400">
                  <X size={11} />
                </button>
              </div>
            ) : (
              // Search dropdown
              <FoodSearchDropdown
                token={token}
                lang={lang}
                onSelect={(food) => applyFood(row.id, food)}
              />
            )}
            <input
              type="number" min="0"
              value={row.amount}
              onChange={(e) => update(row.id, { amount: e.target.value })}
              placeholder="0"
              className="amirani-input !w-20 text-center shrink-0"
            />
            <CustomSelect
              value={row.unit}
              onChange={(val) => update(row.id, { unit: val as UnitType })}
              options={UNITS.map(u => ({ value: u, label: u }))}
              className="w-40 shrink-0"
            />
            <button 
              onClick={() => remove(row.id)} 
              className="h-[48px] px-2 text-zinc-700 hover:text-red-400 transition-colors ml-1 shrink-0 flex items-center justify-center"
            >
              <Trash2 size={16} />
            </button>
          </div>

          {/* Manual name input when no foodItem */}
          {!row.foodItem && (
            <div className="pl-6 pr-1">
              <input
                value={row.name}
                onChange={(e) => update(row.id, { name: e.target.value })}
                placeholder="Or type ingredient name manually…"
                className="w-full bg-zinc-800/60 border border-zinc-700/50 rounded-lg px-2.5 py-1.5 text-xs text-white placeholder-zinc-600 outline-none focus:border-[#F1C40F]/60"
              />
            </div>
          )}

          {/* Macro inputs */}
          <div className="pl-6 pr-1 space-y-1.5">
            <div className="grid grid-cols-4 gap-1.5">
              {(
                [
                  ["kcal", "manualCals", "text-white"],
                  ["P g", "manualProtein", "text-blue-400"],
                  ["C g", "manualCarbs", "text-yellow-400"],
                  ["F g", "manualFats", "text-red-400"],
                ] as [string, keyof IngRow, string][]
              ).map(([label, field, color]) => (
                <div key={field}>
                  <p className={`text-[8px] font-black uppercase mb-0.5 ${color}`}>{label}</p>
                  <input
                    type="number" min="0"
                    value={row[field] as string}
                    onChange={(e) => update(row.id, { [field]: e.target.value })}
                    placeholder="0"
                    className="w-full bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-xs text-white outline-none focus:border-[#F1C40F] text-center"
                  />
                </div>
              ))}
            </div>
            {/* Save as custom food — shown only when manually filled */}
            {!row.foodItem && (
              <div className="flex justify-end">
                <SaveCustomFoodButton row={row} token={token} />
              </div>
            )}
          </div>
        </div>
      ))}

      <button
        onClick={() => onChange([...rows, emptyRow(unitPref)])}
        className="w-full flex items-center justify-center gap-1.5 py-2 border border-dashed border-zinc-700 rounded-lg text-zinc-500 hover:text-[#F1C40F] hover:border-[#F1C40F]/40 text-xs transition-colors"
      >
        <Plus size={12} />
        Add ingredient
      </button>
    </div>
  );
}

// ─── Add meal form — per-slot independent state ────────────────────────────────

type SlotData = { 
  name: string; 
  notifTime: string; 
  isReminderEnabled: boolean; 
  rows: IngRow[];
  instructions: string; // New field for meal prep
};

function initSlotData(): Record<MealSlotKey, SlotData> {
  const out = {} as Record<MealSlotKey, SlotData>;
  MEAL_SLOTS.forEach((s) => {
    out[s.key as MealSlotKey] = {
      name: "",
      notifTime: `${String(s.hour).padStart(2, "0")}:00`,
      isReminderEnabled: true,
      rows: [],
      instructions: "",
    };
  });
  return out;
}

function slotHasIngredients(data: SlotData) {
  return data.rows.some((r) => r.name.trim() !== "");
}

function AddMealForm({
  planId, scheduledDate, unitPref = 'METRIC', lang = 'EN', token, memberId, onDone,
}: {
  planId: string; scheduledDate: string; unitPref?: 'METRIC' | 'IMPERIAL'; lang?: 'EN' | 'KA' | 'RU';
  token: string; memberId: string; onDone: () => void;
}) {
  const qc = useQueryClient();
  const [activeSlot, setActiveSlot] = useState<MealSlotKey>("BREAKFAST");
  const [slotData, setSlotData] = useState<Record<MealSlotKey, SlotData>>(initSlotData);
  const [saving, setSaving] = useState(false);

  const current = slotData[activeSlot];
  const slot = getMealSlot(activeSlot);

  function updateCurrent(patch: Partial<SlotData>) {
    setSlotData((prev) => ({ ...prev, [activeSlot]: { ...prev[activeSlot], ...patch } }));
  }

  const filledSlots = MEAL_SLOTS.filter((s) => slotHasIngredients(slotData[s.key as MealSlotKey]));

  const totalCals = current.rows.reduce((s, r) => s + rowMacros(r).calories, 0);
  const totalP    = current.rows.reduce((s, r) => s + rowMacros(r).protein, 0);
  const totalC    = current.rows.reduce((s, r) => s + rowMacros(r).carbs, 0);
  const totalF    = current.rows.reduce((s, r) => s + rowMacros(r).fats, 0);

  async function handleSave(asDraft = false) {
    if (filledSlots.length === 0) return;
    setSaving(true);
    try {
      for (const s of filledSlots) {
        const d = slotData[s.key as MealSlotKey];
        const ingredients = d.rows
          .filter((r) => r.name.trim())
          .map(rowToIngredient);
        const totals = d.rows.reduce(
          (acc, r) => {
            const m = rowMacros(r);
            return { cals: acc.cals + m.calories, p: acc.p + m.protein, c: acc.c + m.carbs, f: acc.f + m.fats };
          },
          { cals: 0, p: 0, c: 0, f: 0 }
        );
        await trainerApi.addMeal(
          planId,
          {
            name: d.name || s.label,
            timeOfDay: s.key as MealSlotKey,
            scheduledDate,
            totalCalories: Math.round(totals.cals),
            protein: Math.round(totals.p),
            carbs: Math.round(totals.c),
            fats: Math.round(totals.f),
            isDraft: asDraft,
            notificationTime: d.notifTime,
            isReminderEnabled: d.isReminderEnabled,
            items: {
              ingredients: ingredients as unknown as TrainerMealIngredient[],
              instructions: d.instructions,
              isDraft: asDraft
            } as unknown as TrainerMealItems,
          },
          token
        );
      }
      await qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      onDone();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="bg-[#0d1219] border border-zinc-700 rounded-xl overflow-hidden">
      {/* Header */}
      <div className="px-4 py-3 border-b border-zinc-800 flex items-center justify-between">
        <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">
          Plan Meals — {formatDate(scheduledDate)}
        </p>
        {filledSlots.length > 0 && (
          <span className="text-[9px] text-[#F1C40F] font-bold">
            {filledSlots.length} meal{filledSlots.length > 1 ? "s" : ""} ready
          </span>
        )}
      </div>

      {/* Slot tabs */}
      <div className="flex overflow-x-auto border-b border-zinc-800 bg-zinc-900/30">
        {MEAL_SLOTS.map((s) => {
          const filled = slotHasIngredients(slotData[s.key as MealSlotKey]);
          const active = activeSlot === s.key;
          return (
            <button
              key={s.key}
              onClick={() => setActiveSlot(s.key as MealSlotKey)}
              className={`relative flex-shrink-0 flex items-center gap-1.5 px-3 py-2.5 text-xs font-semibold border-b-2 transition-colors ${
                active
                  ? "border-[#F1C40F] text-[#F1C40F] bg-[#F1C40F]/5"
                  : "border-transparent text-zinc-500 hover:text-zinc-300"
              }`}
            >
              <span>{s.emoji}</span>
              <span>{s.label}</span>
              {filled && (
                <span className={`w-1.5 h-1.5 rounded-full ${active ? "bg-[#F1C40F]" : "bg-emerald-500"}`} />
              )}
            </button>
          );
        })}
      </div>

      {/* Active slot content */}
      <div className="p-4 space-y-4">
        {/* Name + time */}
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="amirani-label !mb-3">
              {slot.label} Name <span className="text-zinc-700 normal-case font-normal">(optional)</span>
            </label>
            <input
              value={current.name}
              onChange={(e) => updateCurrent({ name: e.target.value })}
              placeholder={slot.label}
              className="amirani-input"
            />
          </div>
          <div>
            <ThemedTimePicker
              label="Notification Time"
              value={current.notifTime}
              onChange={(val) => updateCurrent({ notifTime: val })}
            />
            <div className="flex items-center gap-2 mt-2 ml-1">
              <input 
                type="checkbox" 
                id="reminder" 
                checked={current.isReminderEnabled}
                onChange={(e) => updateCurrent({ isReminderEnabled: e.target.checked })}
                className="w-3 h-3 accent-[#F1C40F] rounded-sm bg-zinc-800 border-zinc-700" 
              />
              <label htmlFor="reminder" className="text-[10px] text-zinc-400 font-semibold cursor-pointer select-none">
                Send Push Reminder
              </label>
            </div>
          </div>
        </div>

        {/* Instructions */}
        <div>
          <label className="amirani-label !mb-3">
            Preparation Instructions <span className="text-zinc-700 normal-case font-normal">(optional)</span>
          </label>
          <textarea
            value={current.instructions}
            onChange={(e) => updateCurrent({ instructions: e.target.value })}
            placeholder="e.g. Scramble eggs with spinach. Serve with avocado on the side."
            className="w-full h-20 bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-xs text-white placeholder-zinc-700 outline-none focus:border-[#F1C40F]/40 transition-colors resize-none"
          />
        </div>

        {/* Ingredients */}
        <div>
          <label className="amirani-label !mb-3">
            Ingredients{" "}
            <span className="text-zinc-600 normal-case font-normal">
              ({unitPref === 'METRIC' ? "metric — g/ml" : "imperial — oz/cups"})
            </span>
          </label>
          <IngredientEditor
            rows={current.rows.length > 0 ? current.rows : [emptyRow(unitPref)]}
            onChange={(r) => updateCurrent({ rows: r })}
            token={token}
            lang={lang}
            unitPref={unitPref}
          />
        </div>

        {/* Macro summary for this slot */}
        {totalCals > 0 && (
          <div className="flex items-center gap-4 px-3 py-2 bg-zinc-900/60 border border-zinc-800 rounded-lg text-[11px]">
            <span className="font-bold text-white">{Math.round(totalCals)} kcal</span>
            <span className="text-blue-400">P {Math.round(totalP)}g</span>
            <span className="text-yellow-400">C {Math.round(totalC)}g</span>
            <span className="text-red-400">F {Math.round(totalF)}g</span>
          </div>
        )}
      </div>

      {/* Footer */}
      <div className="px-4 pb-4 flex gap-2 flex-wrap">
        <button
          onClick={() => handleSave(false)}
          disabled={filledSlots.length === 0 || saving}
          className="flex items-center gap-1.5 px-4 py-2 bg-[#F1C40F] text-black text-xs font-bold rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 transition-colors"
        >
          <Check size={12} />
          {saving ? "Saving…" : filledSlots.length > 1 ? `Publish ${filledSlots.length} Meals` : "Publish Meal"}
        </button>
        <button
          onClick={() => handleSave(true)}
          disabled={filledSlots.length === 0 || saving}
          className="flex items-center gap-1.5 px-4 py-2 bg-zinc-800 text-zinc-300 text-xs font-bold rounded-lg hover:bg-zinc-700 disabled:opacity-50 transition-colors"
        >
          Save as Draft
        </button>
        <button
          onClick={onDone}
          className="px-4 py-2 bg-zinc-900 text-zinc-500 text-xs font-bold rounded-lg hover:bg-zinc-800 transition-colors ml-auto"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}

// ─── Meal display card ────────────────────────────────────────────────────────

function MealDisplayCard({
  meal, token, memberId, planTargetCalories, onSaveToLibrary,
  isFirst, isLast, onMoveUp, onMoveDown, unitPref = 'METRIC', lang = 'EN',
}: {
  meal: TrainerMeal; token: string; memberId: string; planTargetCalories: number;
  onSaveToLibrary?: (meal: TrainerMeal) => void;
  isFirst?: boolean; isLast?: boolean;
  onMoveUp?: () => void; onMoveDown?: () => void;
  unitPref?: 'METRIC' | 'IMPERIAL'; lang?: 'EN' | 'KA' | 'RU';
}) {
  const qc = useQueryClient();
  const slot = getMealSlot(meal.timeOfDay);
  const items = meal.items as TrainerMealItems | null;
  const isDraft = meal.isDraft === true;
  const notifTime = items?.notificationTime;
  const ingredients = items?.ingredients ?? [];

  const isChallenge = !isDraft && planTargetCalories > 0 && meal.totalCalories / (planTargetCalories || 2000) > 0.4;

  // Edit state
  const [editing, setEditing] = useState(false);
  const [editName, setEditName] = useState(meal.name);
  const [editNotif, setEditNotif] = useState(notifTime ?? "");
  const [editRows, setEditRows] = useState<IngRow[]>(() =>
    ingredients.length > 0 ? ingredients.map(ingredientToRow) : [emptyRow(unitPref)]
  );
  const [editInstructions, setEditInstructions] = useState(items?.instructions ?? "");

  const deleteMeal = useMutation({
    mutationFn: () => trainerApi.deleteMeal(meal.id, token),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] }),
  });

  const updateMeal = useMutation({
    mutationFn: (asDraft: boolean) => {
      const filteredRows = editRows.filter((r) => r.name.trim());
      const newIngredients = filteredRows.map(rowToIngredient);
      const totals = filteredRows.reduce(
        (acc, r) => { const m = rowMacros(r); return { cals: acc.cals + m.calories, p: acc.p + m.protein, c: acc.c + m.carbs, f: acc.f + m.fats }; },
        { cals: 0, p: 0, c: 0, f: 0 }
      );
      return trainerApi.updateMeal(meal.id, {
        name: editName || slot.label,
        totalCalories: Math.round(totals.cals),
        protein: Math.round(totals.p),
        carbs: Math.round(totals.c),
        fats: Math.round(totals.f),
        isDraft: asDraft,
        items: { 
          notificationTime: editNotif, 
          ingredients: newIngredients,
          instructions: editInstructions,
        },
      }, token);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      setEditing(false);
    },
  });

  if (editing) {
    const totalCals = editRows.reduce((s, r) => s + rowMacros(r).calories, 0);
    const totalP    = editRows.reduce((s, r) => s + rowMacros(r).protein, 0);
    const totalC    = editRows.reduce((s, r) => s + rowMacros(r).carbs, 0);
    const totalF    = editRows.reduce((s, r) => s + rowMacros(r).fats, 0);

    return (
      <div className="bg-[#0d1219] border border-[#F1C40F]/30 rounded-xl overflow-hidden">
        {/* Edit header */}
        <div className="flex items-center gap-2 px-4 py-2.5 border-b border-zinc-800 bg-[#F1C40F]/5">
          <span className="text-base">{slot.emoji}</span>
          <span className="text-xs font-black uppercase tracking-widest text-[#F1C40F]">Edit {slot.label}</span>
        </div>
        <div className="p-4 space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-[9px] text-zinc-500 uppercase font-black mb-1">Name</label>
              <input value={editName} onChange={(e) => setEditName(e.target.value)} placeholder={slot.label}
                className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-white outline-none focus:border-[#F1C40F]" />
            </div>
            <div className="space-y-4">
              <ThemedTimePicker
                label="Notification Time"
                value={editNotif}
                onChange={(val) => setEditNotif(val)}
              />
            </div>
          </div>

          <IngredientEditor rows={editRows} onChange={setEditRows} token={token} unitPref={unitPref} lang={lang} />

          <div>
            <p className="text-[9px] text-zinc-500 uppercase font-black mb-1.5 tracking-widest text-violet-400">Preparation Instructions</p>
            <textarea
              value={editInstructions}
              onChange={(e) => setEditInstructions(e.target.value)}
              placeholder="e.g. Cook until golden brown..."
              className="w-full h-20 bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-xs text-white placeholder-zinc-700 outline-none focus:border-[#F1C40F]/40 transition-colors resize-none"
            />
          </div>

          {totalCals > 0 && (
            <div className="flex items-center gap-4 px-3 py-2 bg-zinc-900/60 border border-zinc-800 rounded-lg text-[11px]">
              <span className="font-bold text-white">{Math.round(totalCals)} kcal</span>
              <span className="text-blue-400">P {Math.round(totalP)}g</span>
              <span className="text-yellow-400">C {Math.round(totalC)}g</span>
              <span className="text-red-400">F {Math.round(totalF)}g</span>
            </div>
          )}

          <div className="flex gap-2 flex-wrap">
            <button onClick={() => updateMeal.mutate(false)} disabled={updateMeal.isPending}
              className="flex items-center gap-1.5 px-4 py-2 bg-[#F1C40F] text-black text-xs font-bold rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 transition-colors">
              <Check size={12} />
              {updateMeal.isPending ? "Saving…" : "Save"}
            </button>
            <button onClick={() => updateMeal.mutate(true)} disabled={updateMeal.isPending}
              className="flex items-center gap-1.5 px-4 py-2 bg-zinc-800 text-zinc-300 text-xs font-bold rounded-lg hover:bg-zinc-700 disabled:opacity-50 transition-colors">
              Save as Draft
            </button>
            <button onClick={() => setEditing(false)}
              className="px-4 py-2 bg-zinc-900 text-zinc-500 text-xs font-bold rounded-lg hover:bg-zinc-800 transition-colors ml-auto">
              Cancel
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={`group/card border rounded-xl p-3 transition-all ${isDraft ? "bg-zinc-900/30 border-zinc-700/50 opacity-70" : "bg-zinc-900/50 border-zinc-800"}`}>
      <div className="flex items-start gap-3">
        {/* Reorder buttons */}
        <div className="flex flex-col gap-0.5 pt-0.5 flex-shrink-0 opacity-0 group-hover/card:opacity-100 transition-opacity">
          <button
            onClick={onMoveUp}
            disabled={isFirst}
            className="p-0.5 text-zinc-700 hover:text-[#F1C40F] disabled:opacity-20 disabled:cursor-not-allowed transition-colors"
            title="Move up"
          >
            <Plus size={12} className="rotate-45" /> 
          </button>
          <button
            onClick={onMoveDown}
            disabled={isLast}
            className="p-0.5 text-zinc-700 hover:text-[#F1C40F] disabled:opacity-20 disabled:cursor-not-allowed transition-colors"
            title="Move down"
          >
             <Plus size={12} className="rotate-[225deg]" />
          </button>
        </div>

        <div className="w-10 h-10 rounded-lg bg-zinc-800/70 flex items-center justify-center flex-shrink-0 text-xl border border-white/5">
          {slot.emoji}
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5 flex-wrap mb-1">
            <p className="text-sm font-bold text-white">{meal.name || slot.label}</p>
            {isDraft && (
              <span className="flex items-center gap-0.5 px-1.5 py-0.5 bg-zinc-700/60 border border-zinc-600/40 text-zinc-400 text-[9px] font-black uppercase tracking-wider rounded">
                Draft
              </span>
            )}
            {notifTime && !isDraft && (
              <span className="flex items-center gap-0.5 text-[9px] text-zinc-500 bg-zinc-800/60 px-1.5 py-0.5 rounded ml-auto">
                <Clock size={8} />{notifTime}
              </span>
            )}
            {isChallenge && (
              <span className="flex items-center gap-0.5 px-1.5 py-0.5 bg-orange-500/10 border border-orange-500/20 text-orange-400 text-[9px] font-black uppercase tracking-wider rounded">
                <Flame size={8} /> Challenge
              </span>
            )}
          </div>

          <div className="flex items-center gap-3 text-[11px] mb-1.5">
            <span className="font-bold text-white italic">{meal.totalCalories} kcal</span>
            <div className="flex items-center gap-2 opacity-60">
               <span className="text-blue-400">P {meal.protein}g</span>
               <span className="text-yellow-400">C {meal.carbs}g</span>
               <span className="text-red-400">F {meal.fats}g</span>
            </div>
          </div>

          {ingredients.length > 0 && !isDraft && (
            <p className="text-[10px] text-zinc-500 line-clamp-1 italic">
              {ingredients.map(i => `${i.item} (${i.amount}${i.unit})`).join(", ")}
            </p>
          )}

          {isDraft && (
            <p className="text-[10px] text-zinc-600 italic">{ingredients.length} ingredient{ingredients.length !== 1 ? "s" : ""} — not visible to member</p>
          )}
        </div>

        <div className="flex items-center gap-1 flex-shrink-0">
          <button
            onClick={() => setEditing(true)}
            className="p-1.5 text-zinc-600 hover:text-white hover:bg-white/5 transition-all rounded-lg"
            title="Edit meal"
          >
            <Pencil size={12} />
          </button>
          
          {onSaveToLibrary && (
            <button
              onClick={() => onSaveToLibrary(meal)}
              className="p-1.5 text-zinc-600 hover:text-violet-400 hover:bg-violet-400/5 transition-all rounded-lg"
              title="Save to Vault"
            >
              <Star size={12} />
            </button>
          )}

          <button
            onClick={() => deleteMeal.mutate()}
            disabled={deleteMeal.isPending}
            className="p-1.5 text-zinc-600 hover:text-red-400 hover:bg-red-400/5 transition-all rounded-lg"
          >
            <Trash2 size={16} />
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Draft Library Modal ─────────────────────────────────────────────────────

function DraftLibraryModal({
  plan,
  token,
  memberId,
  currentScheduledDate,
  onClose,
}: {
  plan: TrainerDietPlan;
  token: string;
  memberId: string;
  currentScheduledDate: string;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const [tab, setTab] = useState<"days" | "meals">("days");
  const [applying, setApplying] = useState<string | null>(null);

  const draftMeals = useMemo(
    () => plan.meals.filter((m) => m.isDraft),
    [plan.meals]
  );

  const draftByDate = useMemo(() => {
    const map = new Map<string, TrainerMeal[]>();
    draftMeals.forEach((m) => {
      if (m.scheduledDate) {
        const d = normalizeDate(m.scheduledDate);
        map.set(d, [...(map.get(d) ?? []), m]);
      }
    });
    return Array.from(map.entries())
      .map(([date, meals]) => ({
        date,
        meals: meals.sort((a, b) => slotOrder(a.timeOfDay) - slotOrder(b.timeOfDay)),
        totalCals: meals.reduce((s, m) => s + m.totalCalories, 0),
      }))
      .sort((a, b) => a.date.localeCompare(b.date));
  }, [draftMeals]);

  async function applyMeals(meals: TrainerMeal[], key: string) {
    setApplying(key);
    try {
      for (const m of meals) {
        await trainerApi.addMeal(
          plan.id,
          {
            name: m.name,
            timeOfDay: m.timeOfDay ?? undefined,
            scheduledDate: currentScheduledDate,
            totalCalories: m.totalCalories,
            protein: m.protein,
            carbs: m.carbs,
            fats: m.fats,
            isDraft: false,
            items: (m.items as TrainerMealItems) ?? undefined,
          },
          token
        );
      }
      await qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      onClose();
    } finally {
      setApplying(null);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/70 backdrop-blur-sm p-4">
      <div className="bg-[#121721] border border-zinc-700 rounded-2xl w-full max-w-lg overflow-hidden max-h-[80vh] flex flex-col">
        {/* Header */}
        <div className="px-5 py-4 border-b border-zinc-800 flex items-center justify-between flex-shrink-0">
          <div>
            <h3 className="font-bold text-white text-sm">Draft Library</h3>
            <p className="text-[10px] text-zinc-500 mt-0.5">
              Applying to{" "}
              <span className="text-[#F1C40F] font-bold">{formatDate(currentScheduledDate)}</span>
            </p>
          </div>
          <button onClick={onClose} className="text-zinc-500 hover:text-white p-1 rounded">
            <X size={16} />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-zinc-800 flex-shrink-0">
          {(
            [
              ["days", `Draft Days (${draftByDate.length})`],
              ["meals", `Draft Meals (${draftMeals.length})`],
            ] as const
          ).map(([t, label]) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`flex-1 py-2.5 text-xs font-bold border-b-2 transition-colors ${
                tab === t
                  ? "border-[#F1C40F] text-[#F1C40F]"
                  : "border-transparent text-zinc-500 hover:text-zinc-300"
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="overflow-y-auto flex-1 p-4 space-y-3">
          {draftMeals.length === 0 && (
            <div className="text-center py-10">
              <p className="text-zinc-500 text-sm">No draft meals yet.</p>
              <p className="text-zinc-600 text-xs mt-1">
                Save meals or days as drafts to build a reusable library.
              </p>
            </div>
          )}

          {tab === "days" &&
            draftByDate.map(({ date, meals, totalCals }) => (
              <div key={date} className="border border-zinc-700/60 rounded-xl overflow-hidden">
                <div className="px-4 py-3 bg-zinc-900/60 flex items-center justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-bold text-white">{formatDate(date)}</p>
                    <p className="text-[10px] text-zinc-500">
                      {meals.length} meal{meals.length !== 1 ? "s" : ""} · {totalCals} kcal total
                    </p>
                  </div>
                  <button
                    onClick={() => applyMeals(meals, date)}
                    disabled={applying !== null}
                    className="px-3 py-1.5 bg-[#F1C40F] text-black text-[10px] font-black uppercase rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 whitespace-nowrap flex-shrink-0"
                  >
                    {applying === date ? "Applying…" : "Apply Day Here"}
                  </button>
                </div>
                <div className="divide-y divide-zinc-800/40">
                  {meals.map((m) => {
                    const slot = getMealSlot(m.timeOfDay);
                    const ingredients =
                      (m.items as TrainerMealItems | null)?.ingredients ?? [];
                    return (
                      <div key={m.id} className="flex items-center gap-3 px-4 py-2.5">
                        <span className="text-base flex-shrink-0">{slot.emoji}</span>
                        <div className="flex-1 min-w-0">
                          <p className="text-xs font-semibold text-zinc-200">{m.name}</p>
                          <p className="text-[10px] text-zinc-500">
                            {m.totalCalories} kcal · P{m.protein}g C{m.carbs}g F{m.fats}g
                            {ingredients.length > 0 &&
                              ` · ${ingredients.length} ingredient${ingredients.length !== 1 ? "s" : ""}`}
                          </p>
                        </div>
                        <button
                          onClick={() => applyMeals([m], m.id)}
                          disabled={applying !== null}
                          className="px-2 py-1 bg-zinc-700 text-zinc-300 text-[9px] font-bold uppercase rounded hover:bg-zinc-600 disabled:opacity-50 flex-shrink-0"
                        >
                          {applying === m.id ? "…" : "Use"}
                        </button>
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}

          {tab === "meals" && (
            <div className="space-y-2">
              {[...draftMeals]
                .sort((a, b) => slotOrder(a.timeOfDay) - slotOrder(b.timeOfDay))
                .map((m) => {
                  const slot = getMealSlot(m.timeOfDay);
                  return (
                    <div
                      key={m.id}
                      className="flex items-center gap-3 p-3 border border-zinc-700/60 rounded-xl"
                    >
                      <span className="text-xl flex-shrink-0">{slot.emoji}</span>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-bold text-white">{m.name}</p>
                        <p className="text-[10px] text-zinc-500">
                          {m.scheduledDate
                            ? formatDate(normalizeDate(m.scheduledDate))
                            : "No date"}{" "}
                          · {m.totalCalories} kcal · P{m.protein}g C{m.carbs}g F{m.fats}g
                        </p>
                      </div>
                      <button
                        onClick={() => applyMeals([m], m.id)}
                        disabled={applying !== null}
                        className="px-3 py-1.5 bg-[#F1C40F] text-black text-[10px] font-black uppercase rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 flex-shrink-0"
                      >
                        {applying === m.id ? "…" : "Use Here"}
                      </button>
                    </div>
                  );
                })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function DietBuilderPage({
  params,
}: {
  params: Promise<{ memberId: string }>;
}) {
  const { memberId } = use(params);
  const { token } = useAuthStore();
  const qc = useQueryClient();

  // Member data (for unit detection)
  const { data: members } = useQuery({
    queryKey: ["trainer-members"],
    queryFn: () => trainerApi.getMembers(token!),
    enabled: !!token,
  });
  const member: TrainerAssignedMember | undefined = members?.find(
    (m) => m.user.id === memberId
  );
  const [unitPref, setUnitPref] = useState<'METRIC' | 'IMPERIAL'>('METRIC');
  const [langPref, setLangPref] = useState<'EN' | 'KA' | 'RU'>('EN');
  const userUnitPref = member?.user?.unitPreference;
  const userLangPref = member?.user?.languagePreference;

  useEffect(() => {
    if (userUnitPref) setUnitPref(userUnitPref);
    if (userLangPref) setLangPref(userLangPref);
  }, [userUnitPref, userLangPref]);

  // Plans
  const { data: plans, isLoading } = useQuery({
    queryKey: ["trainer-diet-plans", memberId],
    queryFn: () => trainerApi.getMemberDietPlans(memberId, token!),
    enabled: !!token,
  });

  // Trainer-level draft template library (shared across all members)
  const { data: draftTemplates = [] } = useQuery({
    queryKey: ["trainer-draft-templates"],
    queryFn: () => trainerApi.getDraftTemplates(token!),
    enabled: !!token,
  });
  const mealTemplates = useMemo(() => draftTemplates.filter((t) => t.type === "meal"), [draftTemplates]);
  const dayTemplates  = useMemo(() => draftTemplates.filter((t) => t.type === "day"),  [draftTemplates]);
  const weekTemplates = useMemo(() => draftTemplates.filter((t) => t.type === "week"), [draftTemplates]);

  const [selectedPlanId, setSelectedPlanId] = useState<string | null>(null);
  const currentPlan: TrainerDietPlan | undefined =
    (selectedPlanId ? plans?.find((p) => p.id === selectedPlanId) : null) ??
    plans?.[0];

  // Week / day nav
  const [selectedWeek, setSelectedWeek] = useState(1);
  const [selectedDay, setSelectedDay] = useState(0);

  // numWeeks comes from the DB — no local state needed
  const numWeeks = currentPlan?.numWeeks ?? 1;
  const safeWeek = Math.min(selectedWeek, numWeeks);
  const safeDay = Math.min(selectedDay, 6);

  // Meals for current day
  const dayMeals = useMemo((): TrainerMeal[] => {
    if (!currentPlan?.startDate) return [];
    const target = getScheduledDate(currentPlan.startDate, safeWeek, safeDay);
    return [...currentPlan.meals]
      .filter((m) => m.scheduledDate && normalizeDate(m.scheduledDate) === target)
      .sort((a, b) => slotOrder(a.timeOfDay) - slotOrder(b.timeOfDay));
  }, [currentPlan, safeWeek, safeDay]);

  const dayTotals = useMemo(() => ({
    calories: dayMeals.reduce((s, m) => s + m.totalCalories, 0),
    protein: dayMeals.reduce((s, m) => s + m.protein, 0),
    carbs: dayMeals.reduce((s, m) => s + m.carbs, 0),
    fat: dayMeals.reduce((s, m) => s + m.fats, 0),
  }), [dayMeals]);

  // New plan form
  const [showNewPlan, setShowNewPlan] = useState(false);
  const [planName, setPlanName] = useState("");
  const [startDate, setStartDate] = useState(
    () => new Date().toISOString().split("T")[0]
  );
  const [newPlanWeeks, setNewPlanWeeks] = useState<(typeof WEEK_OPTIONS)[number]>(4);
  const [hydrationTargetMl, setHydrationTargetMl] = useState("2000");
  const [keyNutritionInsights, setKeyNutritionInsights] = useState("");
  
  // Per-week macro targets: index 0 = week 1, etc.
  const defaultWeekMacros = () => ({ calories: "2000", protein: "150", carbs: "200", fats: "65" });
  const [weekMacros, setWeekMacros] = useState<{ calories: string; protein: string; carbs: string; fats: string }[]>(
    Array.from({ length: 4 }, defaultWeekMacros)
  );
  const [creating, setCreating] = useState(false);

  function updateWeekMacro(weekIdx: number, field: "calories" | "protein" | "carbs" | "fats", value: string) {
    setWeekMacros((prev) => prev.map((w, i) => i === weekIdx ? { ...w, [field]: value } : w));
  }

  const [showAddMeal, setShowAddMeal] = useState(false);
  // Rest days (per-session visual state — per plan)
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

  // Draft library (plan-level drafts modal — member-scoped)
  const [showDraftLibrary, setShowDraftLibrary] = useState(false);
  // Trainer-level template library modal
  const [showTemplateLibrary, setShowTemplateLibrary] = useState(false);
  const [renamingTemplateId, setRenamingTemplateId] = useState<string | null>(null);
  const [renameValue, setRenameValue] = useState("");

  // Inline import panels (contextual per level)
  const [showDayImport, setShowDayImport] = useState(false);
  const [showWeekImport, setShowWeekImport] = useState(false);
  const [slotImportOpen, setSlotImportOpen] = useState<string | null>(null);

  // Copy day
  const [showCopyDay, setShowCopyDay] = useState(false);
  const [copyTargetWeek, setCopyTargetWeek] = useState(1);
  const [copyTargetDay, setCopyTargetDay] = useState(0);

  // Edit Plan Metadata
  const [showEditPlan, setShowEditPlan] = useState(false);
  const [editPlanId, setEditPlanId] = useState<string | null>(null);

  // Activate confirmation
  const [confirmActivate, setConfirmActivate] = useState<string | null>(null);

  // Mutations
  const deletePlan = useMutation({
    mutationFn: (id: string) => trainerApi.deleteDietPlan(id, token!),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] }),
  });

  const activatePlan = useMutation({
    mutationFn: (id: string) => trainerApi.activateDietPlan(id, token!),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] }),
  });

  const publishPlan = useMutation({
    mutationFn: (id: string) => trainerApi.publishDietPlan(id, token!),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] }),
  });

  const updatePlan = useMutation({
    mutationFn: (data: Partial<{ name: string; targetCalories: number; targetProtein: number; targetCarbs: number; targetFats: number; hydrationTargetMl: number; keyNutritionInsights: string }>) =>
      trainerApi.updateDietPlan(editPlanId!, data, token!),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      setShowEditPlan(false);
    },
  });

  // Draft counts (for toolbar visibility)
  const draftCount = useMemo(
    () => currentPlan?.meals.filter((m) => m.isDraft).length ?? 0,
    [currentPlan]
  );
  const weekPublishedCount = useMemo(() => {
    if (!currentPlan?.startDate) return 0;
    const weekDates = new Set(
      Array.from({ length: 7 }, (_, d) =>
        getScheduledDate(currentPlan.startDate!, safeWeek, d)
      )
    );
    return currentPlan.meals.filter(
      (m) => !m.isDraft && m.scheduledDate && weekDates.has(normalizeDate(m.scheduledDate))
    ).length;
  }, [currentPlan, safeWeek]);
  
  const publishDayDraftsMutation = useMutation({
    mutationFn: async () => {
      for (const m of dayMeals.filter((m) => m.isDraft)) {
        await trainerApi.updateMeal(m.id, { isDraft: false }, token!);
      }
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] }),
  });


  // ── Trainer template library mutations ─────────────────────────────────────

  /** Save one meal as a named template */
  const saveMealToLibraryMutation = useMutation({
    mutationFn: async ({ meal, name }: { meal: TrainerMeal; name: string }) => {
      const templateMeal: TrainerTemplateMeal = {
        name: meal.name,
        timeOfDay: meal.timeOfDay ?? undefined,
        totalCalories: meal.totalCalories,
        protein: meal.protein,
        carbs: meal.carbs,
        fats: meal.fats,
        items: meal.items ?? undefined,
      };
      await trainerApi.createDraftTemplate({ type: "meal", name, data: { meals: [templateMeal] } }, token!);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-draft-templates"] });
      setSaveMealDialog(null);
      setLibraryNameInput("");
      showToast("Meal saved to vault ✓");
    },
  });

  /** Save current day's meals (published + draft) as a named day template */
  const saveDayToLibraryMutation = useMutation({
    mutationFn: async (name: string) => {
      const meals: TrainerTemplateMeal[] = dayMeals.map((m) => ({
        name: m.name,
        timeOfDay: m.timeOfDay ?? undefined,
        totalCalories: m.totalCalories,
        protein: m.protein,
        carbs: m.carbs,
        fats: m.fats,
        items: m.items ?? undefined,
      }));
      await trainerApi.createDraftTemplate({ type: "day", name, data: { meals } }, token!);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-draft-templates"] });
      setSaveDayDialog(false);
      setLibraryNameInput("");
      showToast("Day saved to vault ✓");
    },
  });

  /** Save current week's meals (all days) as a named week template */
  const saveWeekToLibraryMutation = useMutation({
    mutationFn: async (name: string) => {
      if (!currentPlan?.startDate) return;
      const days = Array.from({ length: 7 }, (_, dayIdx) => {
        const date = getScheduledDate(currentPlan.startDate!, safeWeek, dayIdx);
        const meals: TrainerTemplateMeal[] = currentPlan.meals
          .filter((m) => m.scheduledDate && normalizeDate(m.scheduledDate) === date)
          .map((m) => ({
            name: m.name,
            timeOfDay: m.timeOfDay ?? undefined,
            totalCalories: m.totalCalories,
            protein: m.protein,
            carbs: m.carbs,
            fats: m.fats,
            items: m.items ?? undefined,
          }));
        return { dayIdx, meals };
      }).filter((d) => d.meals.length > 0);
      await trainerApi.createDraftTemplate({ type: "week", name, data: { days } }, token!);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-draft-templates"] });
      setSaveWeekDialog(false);
      setLibraryNameInput("");
      showToast("Week saved to vault ✓");
    },
  });

  /** Apply a template's meals to the current day */
  const applyTemplateToDay = useMutation({
    mutationFn: async ({ template, targetDate }: { template: TrainerDraftTemplate; targetDate: string }) => {
      const data = template.data as { meals?: TrainerTemplateMeal[]; days?: { dayIdx: number; meals: TrainerTemplateMeal[] }[] };
      const meals = data.meals ?? [];
      for (const m of meals) {
        await trainerApi.addMeal(currentPlan!.id, { ...m, scheduledDate: targetDate, isDraft: false }, token!);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      setShowDayImport(false);
      setSlotImportOpen(null);
    },
  });

  /** Apply a week template — maps days by dayIdx to the current week */
  const applyTemplateToWeek = useMutation({
    mutationFn: async (template: TrainerDraftTemplate) => {
      if (!currentPlan?.startDate) return;
      const data = template.data as { days: { dayIdx: number; meals: TrainerTemplateMeal[] }[] };
      for (const { dayIdx, meals } of data.days) {
        const targetDate = getScheduledDate(currentPlan.startDate, safeWeek, dayIdx);
        for (const m of meals) {
          await trainerApi.addMeal(currentPlan.id, { ...m, scheduledDate: targetDate, isDraft: false }, token!);
        }
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      setShowWeekImport(false);
    },
  });

  /** Delete a template from the library */
  const deleteTemplateMutation = useMutation({
    mutationFn: (id: string) => trainerApi.deleteDraftTemplate(id, token!),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-draft-templates"] }),
  });

  /** Rename a template */
  const renameTemplateMutation = useMutation({
    mutationFn: ({ id, name }: { id: string; name: string }) =>
      trainerApi.updateDraftTemplate(id, { name }, token!),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-draft-templates"] });
      setRenamingTemplateId(null);
    },
  });

  // State for naming dialogs (save to library)
  const [saveMealDialog, setSaveMealDialog] = useState<{ meal: TrainerMeal } | null>(null);
  const [saveDayDialog, setSaveDayDialog] = useState(false);
  const [saveWeekDialog, setSaveWeekDialog] = useState(false);
  const [libraryNameInput, setLibraryNameInput] = useState("");

  const saveWeekAsDraftMutation = useMutation({
    mutationFn: async () => {
      if (!currentPlan?.startDate) return;
      const weekDates = new Set(
        Array.from({ length: 7 }, (_, d) =>
          getScheduledDate(currentPlan.startDate!, safeWeek, d)
        )
      );
      const published = currentPlan.meals.filter(
        (m) => !m.isDraft && m.scheduledDate && weekDates.has(normalizeDate(m.scheduledDate))
      );
      for (const m of published) {
        await trainerApi.updateMeal(m.id, { isDraft: true }, token!);
      }
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] }),
  });

  // Draft grouped data for contextual import panels
  const allDraftMeals = useMemo(
    () => currentPlan?.meals.filter((m) => m.isDraft) ?? [],
    [currentPlan]
  );

  const draftByDate = useMemo(() => {
    const map = new Map<string, TrainerMeal[]>();
    allDraftMeals.forEach((m) => {
      if (m.scheduledDate) {
        const d = normalizeDate(m.scheduledDate);
        map.set(d, [...(map.get(d) ?? []), m]);
      }
    });
    return Array.from(map.entries())
      .map(([date, meals]) => ({
        date,
        meals: meals.sort((a, b) => slotOrder(a.timeOfDay) - slotOrder(b.timeOfDay)),
        totalCals: meals.reduce((s, m) => s + m.totalCalories, 0),
      }))
      .sort((a, b) => a.date.localeCompare(b.date));
  }, [allDraftMeals]);

  const draftByWeek = useMemo(() => {
    if (!currentPlan?.startDate) return [];
    const weekMap = new Map<number, { dayIdx: number; date: string; meals: TrainerMeal[] }[]>();
    draftByDate.forEach(({ date, meals }) => {
      for (let w = 1; w <= numWeeks; w++) {
        for (let d = 0; d < 7; d++) {
          if (getScheduledDate(currentPlan.startDate!, w, d) === date) {
            weekMap.set(w, [...(weekMap.get(w) ?? []), { dayIdx: d, date, meals }]);
            return;
          }
        }
      }
    });
    return Array.from(weekMap.entries())
      .map(([weekNum, days]) => ({
        weekNum,
        days: days.sort((a, b) => a.dayIdx - b.dayIdx),
        totalMeals: days.reduce((s, d) => s + d.meals.length, 0),
      }))
      .sort((a, b) => a.weekNum - b.weekNum);
  }, [currentPlan, draftByDate, numWeeks]);

  const draftBySlot = useMemo(() => {
    const map = new Map<string, TrainerMeal[]>();
    allDraftMeals.forEach((m) => {
      if (m.timeOfDay) {
        map.set(m.timeOfDay, [...(map.get(m.timeOfDay) ?? []), m]);
      }
    });
    return map;
  }, [allDraftMeals]);

  const applyDraftMutation = useMutation({
    mutationFn: async ({ meals, targetDate }: { meals: TrainerMeal[]; targetDate: string }) => {
      if (!currentPlan) return;
      for (const m of meals) {
        await trainerApi.addMeal(currentPlan.id, {
          name: m.name,
          timeOfDay: m.timeOfDay ?? undefined,
          scheduledDate: targetDate,
          totalCalories: m.totalCalories,
          protein: m.protein,
          carbs: m.carbs,
          fats: m.fats,
          isDraft: false,
          items: m.items ?? undefined,
        }, token!);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      setShowDayImport(false);
      setSlotImportOpen(null);
    },
  });

  const applyDraftWeekMutation = useMutation({
    mutationFn: async ({ fromWeekNum }: { fromWeekNum: number }) => {
      if (!currentPlan?.startDate) return;
      const sourceDays = draftByWeek.find((w) => w.weekNum === fromWeekNum)?.days ?? [];
      for (const { dayIdx, meals } of sourceDays) {
        const targetDate = getScheduledDate(currentPlan.startDate, safeWeek, dayIdx);
        for (const m of meals) {
          await trainerApi.addMeal(currentPlan.id, {
            name: m.name,
            timeOfDay: m.timeOfDay ?? undefined,
            scheduledDate: targetDate,
            totalCalories: m.totalCalories,
            protein: m.protein,
            carbs: m.carbs,
            fats: m.fats,
            isDraft: false,
            items: m.items ?? undefined,
          }, token!);
        }
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      setShowWeekImport(false);
    },
  });

  const copyDayToAllWeeksMutation = useMutation({
    mutationFn: async () => {
      if (!currentPlan?.startDate) return;
      const fromDate = getScheduledDate(currentPlan.startDate, safeWeek, safeDay);
      const toClone = currentPlan.meals.filter(
        (m) => m.scheduledDate && normalizeDate(m.scheduledDate) === fromDate
      );
      if (toClone.length === 0) return;
      for (let w = 1; w <= numWeeks; w++) {
        if (w === safeWeek) continue;
        const toDate = getScheduledDate(currentPlan.startDate, w, safeDay);
        for (const m of toClone) {
          await trainerApi.addMeal(currentPlan.id, {
            name: m.name,
            timeOfDay: m.timeOfDay ?? undefined,
            scheduledDate: toDate,
            totalCalories: m.totalCalories,
            protein: m.protein,
            carbs: m.carbs,
            fats: m.fats,
            isDraft: m.isDraft,
            items: m.items ?? undefined,
          }, token!);
        }
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      setShowCopyDay(false);
    },
  });

  const moveMealMutation = useMutation({
    mutationFn: async ({ mealId, newSlot }: { mealId: string; newSlot: string }) => {
      await trainerApi.updateMeal(mealId, { timeOfDay: newSlot }, token!);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] }),
  });

  const handleMoveMeal = (mealId: string, direction: "up" | "down") => {
    const meal = dayMeals.find((m) => m.id === mealId);
    if (!meal) return;
    const currentIdx = MEAL_SLOTS.findIndex((s) => s.key === meal.timeOfDay);
    if (currentIdx === -1) return;

    const newIdx = direction === "up" ? currentIdx - 1 : currentIdx + 1;
    if (newIdx < 0 || newIdx >= MEAL_SLOTS.length) return;

    moveMealMutation.mutate({ mealId, newSlot: MEAL_SLOTS[newIdx].key });
  };

  const copyDayMutation = useMutation({
    mutationFn: async ({ fromWeek, fromDay, toWeek, toDay }: {
      fromWeek: number; fromDay: number; toWeek: number; toDay: number;
    }) => {
      if (!currentPlan?.startDate) return;
      const fromDate = getScheduledDate(currentPlan.startDate, fromWeek, fromDay);
      const toDate = getScheduledDate(currentPlan.startDate, toWeek, toDay);
      const toClone = currentPlan.meals.filter(
        (m) => m.scheduledDate && normalizeDate(m.scheduledDate) === fromDate
      );
      for (const m of toClone) {
        await trainerApi.addMeal(currentPlan.id, {
          name: m.name,
          timeOfDay: m.timeOfDay ?? undefined,
          scheduledDate: toDate,
          totalCalories: m.totalCalories,
          protein: m.protein,
          carbs: m.carbs,
          fats: m.fats,
          isDraft: m.isDraft,
          items: m.items ?? undefined,
        }, token!);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      setShowCopyDay(false);
    },
  });

  async function handleCreatePlan() {
    if (!planName.trim()) return;
    setCreating(true);
    try {
      const weekTargets = Array.from({ length: newPlanWeeks }, (_, i) => ({
        calories: parseInt(weekMacros[i].calories),
        protein: parseFloat(weekMacros[i].protein),
        carbs: parseFloat(weekMacros[i].carbs),
        fats: parseFloat(weekMacros[i].fats),
      }));
      await trainerApi.createDietPlan(
        memberId,
        {
          name: planName,
          targetCalories: weekTargets[0].calories,
          targetProtein: weekTargets[0].protein,
          targetCarbs: weekTargets[0].carbs,
          targetFats: weekTargets[0].fats,
          startDate,
          numWeeks: newPlanWeeks,
          hydrationTargetMl: parseInt(hydrationTargetMl) || 2000,
          keyNutritionInsights: keyNutritionInsights.trim() || undefined,
          weekTargets,
        },
        token!
      );
    } finally {
      setCreating(false);
      await qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
      setShowNewPlan(false);
      setPlanName("");
    }
  }

  const scheduledDateForDay = currentPlan?.startDate
    ? getScheduledDate(currentPlan.startDate, selectedWeek, selectedDay)
    : null;

  // Clamp week / day when plan changes

  // Per-week macro targets (falls back to plan baseline for week 1)
  const weekTargetsForSelected = currentPlan ? (
    currentPlan.weekTargets?.[safeWeek - 1] ?? {
      calories: currentPlan.targetCalories,
      protein: currentPlan.targetProtein,
      carbs: currentPlan.targetCarbs,
      fats: currentPlan.targetFats,
    }
  ) : { calories: 0, protein: 0, carbs: 0, fats: 0 };

  return (
    <div>
      <Link
        href={`/dashboard/trainer/members/${memberId}`}
        className="inline-flex items-center gap-2 text-zinc-500 hover:text-white text-sm mb-6 transition-colors"
      >
        <ArrowLeft size={16} />
        Back to Member
      </Link>

      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <ClipboardList size={20} className="text-[#F1C40F]" />
          <h1 className="text-xl font-bold text-white">Diet Plans</h1>
          {unitPref === 'IMPERIAL' && (
            <span className="text-[9px] font-black uppercase tracking-widest text-orange-400 bg-orange-500/10 border border-orange-500/20 px-2 py-0.5 rounded">
              Imperial
            </span>
          )}
        </div>
        {!showNewPlan && (
          <button
            onClick={() => setShowNewPlan(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 text-xs font-bold rounded-lg transition-colors"
          >
            <Plus size={13} />
            New Plan
          </button>
        )}
      </div>

      {/* New plan form */}
      {showNewPlan && (
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-5 mb-6 space-y-4">
          <h2 className="text-sm font-bold text-white flex items-center gap-2">
            <Calendar size={14} className="text-[#F1C40F]" />
            New Diet Plan
          </h2>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="amirani-label !mb-3">
                Plan Name
              </label>
              <input
                value={planName}
                onChange={(e) => setPlanName(e.target.value)}
                placeholder="e.g. Cutting Phase"
                className="amirani-input"
              />
            </div>
            <div>
              <ThemedDatePicker
                label="Start Date"
                value={startDate}
                onChange={(val) => setStartDate(val)}
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="amirani-label !mb-3">
                Hydration Target <span className="text-zinc-600 lowercase font-normal">(ml)</span>
              </label>
              <input
                type="number"
                value={hydrationTargetMl}
                onChange={(e) => setHydrationTargetMl(e.target.value)}
                placeholder="2000"
                className="amirani-input"
              />
            </div>
            <div className="sm:row-span-2">
              <label className="amirani-label !mb-3">
                Key Nutrition Insights
              </label>
              <textarea
                value={keyNutritionInsights}
                onChange={(e) => setKeyNutritionInsights(e.target.value)}
                placeholder="e.g. Focus on high protein intake and fiber-rich vegetables..."
                className="w-full h-[104px] bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2.5 text-sm text-white placeholder-zinc-700 outline-none focus:border-[#F1C40F]/40 transition-colors resize-none"
              />
            </div>
          </div>

          {/* Duration */}
          <div>
            <label className="amirani-label !mb-3">
              Duration
            </label>
            <div className="flex gap-2">
              {WEEK_OPTIONS.map((w) => (
                <button
                  key={w}
                  onClick={() => setNewPlanWeeks(w)}
                  className={`flex-1 py-2 text-xs font-bold rounded-lg border transition-colors ${
                    newPlanWeeks === w
                      ? "bg-[#F1C40F]/15 border-[#F1C40F]/50 text-[#F1C40F]"
                      : "bg-zinc-900 border-zinc-700 text-zinc-500 hover:text-zinc-300"
                  }`}
                >
                  {w} Week{w > 1 ? "s" : ""}
                </button>
              ))}
            </div>
            <p className="mt-1.5 text-[10px] text-zinc-500 flex items-center gap-1">
              <Zap size={10} className="text-[#F1C40F]" />
              One plan with{" "}
              <strong className="text-white">{newPlanWeeks} week{newPlanWeeks > 1 ? "s" : ""}</strong>,
              each week has its own macro targets
            </p>
          </div>

          {/* Per-week macro targets */}
          <div className="space-y-3">
            {Array.from({ length: newPlanWeeks }, (_, wi) => (
              <div key={wi} className="rounded-xl border border-zinc-700/60 bg-zinc-900/50 p-3">
                <p className="text-[10px] text-[#F1C40F] font-black uppercase tracking-widest mb-2">
                  Week {wi + 1} Targets
                </p>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                  {(
                    [
                      ["Calories", "calories", "kcal"],
                      ["Protein", "protein", "g"],
                      ["Carbs", "carbs", "g"],
                      ["Fat", "fats", "g"],
                    ] as [string, "calories" | "protein" | "carbs" | "fats", string][]
                  ).map(([label, field, unit]) => (
                    <div key={field}>
                      <label className="amirani-label !mb-3 !text-[9px]">
                        {label} <span className="text-zinc-600 lowercase font-normal">({unit})</span>
                      </label>
                      <input
                        type="number" min="0"
                        value={weekMacros[wi][field]}
                        onChange={(e) => updateWeekMacro(wi, field, e.target.value)}
                        className="w-full bg-zinc-950 border border-zinc-700 rounded-lg px-2 py-1.5 text-sm text-white outline-none focus:border-[#F1C40F]"
                      />
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>

          <div className="flex gap-2 pt-1">
            <button
              onClick={handleCreatePlan}
              disabled={!planName.trim() || creating}
              className="flex items-center gap-2 px-5 py-2 bg-[#F1C40F] text-black text-xs font-bold rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 transition-colors"
            >
              {creating ? (
                <>
                  <span className="w-3 h-3 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                  Creating…
                </>
              ) : (
                <>
                  <Calendar size={12} />
                  Create Plan
                </>
              )}
            </button>
            <button
              onClick={() => { setShowNewPlan(false); setPlanName(""); }}
              className="px-4 py-2 bg-zinc-800 text-zinc-400 text-xs font-bold rounded-lg hover:bg-zinc-700 transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Plan tabs */}
      {plans && plans.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mb-5 items-center">
          {plans.map((p) => (
            <div key={p.id} className="flex items-center gap-0.5">
              <button
                onClick={() => {
                  setSelectedPlanId(p.id);
                  setSelectedWeek(1);
                  setSelectedDay(0);
                  setShowAddMeal(false);
                }}
                className={`px-3 h-9 text-xs font-bold rounded-l-lg border flex items-center transition-colors ${
                  currentPlan?.id === p.id
                    ? "bg-[#F1C40F]/15 border-[#F1C40F]/40 text-[#F1C40F]"
                    : "bg-zinc-900 border-zinc-700 text-zinc-400 hover:text-white"
                }`}
              >
                {p.name}
                {p.isActive && <span className="ml-1.5 text-green-400">●</span>}
              </button>
              <button
                onClick={() => deletePlan.mutate(p.id)}
                disabled={deletePlan.isPending}
                className={`px-2.5 h-9 border-y border-r rounded-r-lg flex items-center transition-colors text-zinc-700 hover:text-red-500 ${
                  currentPlan?.id === p.id ? "border-[#F1C40F]/40" : "bg-zinc-900 border-zinc-700"
                }`}
              >
                <Trash2 size={16} />
              </button>
            </div>
          ))}
        </div>
      )}

      {isLoading && (
        <p className="text-zinc-500 text-sm py-8 text-center">Loading plans…</p>
      )}

      {/* Current plan view */}
      {currentPlan && (
        <div className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden">
          {/* Plan header */}
          <div className="px-5 py-4 border-b border-zinc-800">
            <div className="flex items-start justify-between gap-4">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap mb-1">
                  <h2 className="font-bold text-white">{currentPlan.name}</h2>
                  {!currentPlan.isPublished ? (
                    <span className="px-1.5 py-0.5 bg-orange-500/15 border border-orange-500/25 text-orange-400 text-[9px] font-black uppercase tracking-wider rounded">
                      Draft 🛠️
                    </span>
                  ) : currentPlan.isActive && (
                    <span className="px-1.5 py-0.5 bg-green-500/15 border border-green-500/25 text-green-400 text-[9px] font-black uppercase tracking-wider rounded">
                      Active
                    </span>
                  )}
                  <span className={`px-1.5 py-0.5 text-[9px] font-black uppercase tracking-wider rounded border ${
                    currentPlan.isAIGenerated
                      ? "bg-blue-500/10 border-blue-500/25 text-blue-400"
                      : "bg-[#F1C40F]/10 border-[#F1C40F]/25 text-[#F1C40F]"
                  }`}>
                    {currentPlan.isAIGenerated ? "AI" : "Trainer"}
                  </span>
                </div>
                <p className="text-xs text-zinc-500 mb-2">
                  {currentPlan.targetCalories} kcal ·{" "}
                  P {currentPlan.targetProtein}g ·{" "}
                  C {currentPlan.targetCarbs}g ·{" "}
                  F {currentPlan.targetFats}g
                  {currentPlan.startDate && (
                    <> · Starts {formatDate(currentPlan.startDate)}</>
                  )}
                </p>

                {(currentPlan.hydrationTargetMl || currentPlan.keyNutritionInsights) && (
                  <div className="flex gap-4 p-3 bg-zinc-950/50 border border-zinc-800/50 rounded-xl">
                    {currentPlan.hydrationTargetMl && (
                      <div className="flex items-center gap-2">
                         <Droplets size={14} className="text-blue-400" />
                         <span className="text-[11px] font-bold text-white">{currentPlan.hydrationTargetMl}ml <span className="text-zinc-500 font-normal">hydration</span></span>
                      </div>
                    )}
                    {currentPlan.keyNutritionInsights && (
                      <div className="flex items-center gap-2 flex-1 min-w-0">
                         <Zap size={14} className="text-[#F1C40F]" />
                         <p className="text-[11px] text-zinc-400 italic line-clamp-1 truncate">{currentPlan.keyNutritionInsights}</p>
                      </div>
                    )}
                  </div>
                )}
              </div>
              <div className="flex items-center gap-1.5 flex-shrink-0">
                <button
                  onClick={() => setShowTemplateLibrary(true)}
                  className="px-3 py-1.5 bg-violet-900/20 border border-violet-700/30 text-violet-400 text-[10px] font-black uppercase tracking-wider rounded-lg hover:bg-violet-800/30 transition-colors"
                  title="Manage your reusable template library"
                >
                  ★ Library {draftTemplates.length > 0 && `(${draftTemplates.length})`}
                </button>
                <button
                  onClick={() => {
                    setEditPlanId(currentPlan.id);
                    setPlanName(currentPlan.name);
                    setHydrationTargetMl(String(currentPlan.hydrationTargetMl ?? "2000"));
                    setKeyNutritionInsights(currentPlan.keyNutritionInsights ?? "");
                    setShowEditPlan(true);
                  }}
                  className="p-1.5 bg-zinc-800 border border-zinc-700 text-zinc-400 rounded-lg hover:text-white"
                  title="Plan Settings"
                >
                  <Settings size={14} />
                </button>
                {!currentPlan.isPublished && (
                  <button
                    onClick={() => publishPlan.mutate(currentPlan.id)}
                    disabled={publishPlan.isPending}
                    className="px-3 py-1.5 bg-emerald-900/20 border border-emerald-700/30 text-emerald-400 text-[10px] font-black uppercase tracking-wider rounded-lg hover:bg-emerald-800/30 transition-colors"
                  >
                    {publishPlan.isPending ? "Publishing…" : "Publish Plan"}
                  </button>
                )}
                {!currentPlan.isActive && currentPlan.isPublished && (
                  <button
                    onClick={() => setConfirmActivate(currentPlan.id)}
                    disabled={activatePlan.isPending}
                    className="px-3 py-1.5 bg-zinc-800 text-zinc-400 text-[10px] font-black uppercase tracking-wider rounded-lg hover:bg-[#F1C40F]/10 hover:text-[#F1C40F] transition-colors"
                  >
                    Set Active
                  </button>
                )}
              </div>
            </div>
          </div>

          {/* Week + day navigation (only if startDate exists) */}
          {currentPlan.startDate ? (
            <>
              {/* Week tabs */}
              {numWeeks > 1 && (
                <>
                  <div className="px-5 pt-3 flex items-end justify-between gap-2 border-b border-zinc-800/50 pb-0">
                    <div className="flex gap-1.5 flex-wrap">
                      {Array.from({ length: numWeeks }, (_, i) => i + 1).map((w) => {
                        const isActive = safeWeek === w;
                        return (
                          <button
                            key={w}
                            onClick={() => { setSelectedWeek(w); setSelectedDay(0); setShowAddMeal(false); setShowWeekImport(false); }}
                            className={`group relative px-6 py-4 text-xs font-black uppercase tracking-widest transition-all ${
                              isActive
                                ? "text-white"
                                : "text-zinc-500 hover:text-zinc-300"
                            }`}
                          >
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
                      {weekPublishedCount > 0 && (
                        <button
                          onClick={() => saveWeekAsDraftMutation.mutate()}
                          disabled={saveWeekAsDraftMutation.isPending}
                          className="px-2 py-1 text-[9px] font-bold uppercase text-zinc-600 hover:text-zinc-300 bg-zinc-800/80 rounded-lg transition-colors disabled:opacity-50"
                        >
                          {saveWeekAsDraftMutation.isPending ? "Saving…" : "Save Week Draft"}
                        </button>
                      )}
                      {weekPublishedCount > 0 && (
                        <button
                          onClick={() => { setSaveWeekDialog(true); setLibraryNameInput(`Week ${safeWeek} — ${currentPlan.name}`); }}
                          className="px-2 py-1 text-[9px] font-bold uppercase text-violet-500 hover:text-violet-300 bg-violet-900/20 border border-violet-700/30 rounded-lg transition-colors"
                          title="Save week to your library"
                        >
                          + Library
                        </button>
                      )}
                      {(draftByWeek.length > 0 || weekTemplates.length > 0) && (
                        <button
                          onClick={() => setShowWeekImport((v) => !v)}
                          className={`px-2 py-1 text-[9px] font-bold uppercase rounded-lg transition-colors border ${
                            showWeekImport
                              ? "bg-[#F1C40F]/10 border-[#F1C40F]/30 text-[#F1C40F]"
                              : "bg-zinc-800/80 border-zinc-700/50 text-zinc-500 hover:text-zinc-300"
                          }`}
                        >
                          Import Week {showWeekImport ? "▴" : "▾"}
                        </button>
                      )}
                    </div>
                  </div>
                  {showWeekImport && (draftByWeek.length > 0 || weekTemplates.length > 0) && (
                    <div className="mx-5 mt-2 bg-zinc-900/50 border border-zinc-700/50 rounded-xl overflow-hidden">
                      {draftByWeek.length > 0 && (
                        <>
                          <p className="px-3 py-2 text-[9px] text-zinc-500 font-black uppercase tracking-widest border-b border-zinc-800/60">
                            Draft weeks (this plan)
                          </p>
                          {draftByWeek.map(({ weekNum, days, totalMeals }) => (
                            <div key={weekNum} className="flex items-center gap-3 px-3 py-2.5 hover:bg-zinc-800/30 border-b border-zinc-800/40 last:border-0">
                              <div className="flex-1 min-w-0">
                                <p className="text-xs font-semibold text-zinc-200">Week {weekNum} draft</p>
                                <p className="text-[10px] text-zinc-500">
                                  {totalMeals} meal{totalMeals !== 1 ? "s" : ""} · {days.map((d) => getDayName(d.date)).join(", ")}
                                </p>
                              </div>
                              <button
                                onClick={() => applyDraftWeekMutation.mutate({ fromWeekNum: weekNum })}
                                disabled={applyDraftWeekMutation.isPending || weekNum === safeWeek}
                                className="px-3 py-1.5 bg-[#F1C40F] text-black text-[10px] font-black uppercase rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 flex-shrink-0"
                              >
                                {applyDraftWeekMutation.isPending ? "…" : `Apply to W${safeWeek}`}
                              </button>
                            </div>
                          ))}
                        </>
                      )}
                      {weekTemplates.length > 0 && (
                        <>
                          <p className="px-3 py-2 text-[9px] text-violet-400 font-black uppercase tracking-widest border-b border-zinc-800/60">
                            My Library
                          </p>
                          {weekTemplates.map((tpl) => {
                            const data = tpl.data as { days: { dayIdx: number; meals: unknown[] }[] };
                            const totalMeals = data.days.reduce((s, d) => s + d.meals.length, 0);
                            const activeDays = data.days.map((d) => {
                              const dDate = getScheduledDate(currentPlan.startDate!, safeWeek, d.dayIdx);
                              return getDayName(dDate);
                            }).join(", ");
                            return (
                              <div key={tpl.id} className="flex items-center gap-3 px-3 py-2.5 hover:bg-zinc-800/30 border-b border-zinc-800/40 last:border-0">
                                <div className="flex-1 min-w-0">
                                  <p className="text-xs font-semibold text-violet-300">{tpl.name}</p>
                                  <p className="text-[10px] text-zinc-500">{totalMeals} meals · {activeDays}</p>
                                </div>
                                <button
                                  onClick={() => applyTemplateToWeek.mutate(tpl)}
                                  disabled={applyTemplateToWeek.isPending}
                                  className="px-3 py-1.5 bg-violet-600 text-white text-[10px] font-black uppercase rounded-lg hover:bg-violet-500 disabled:opacity-50 flex-shrink-0"
                                >
                                  {applyTemplateToWeek.isPending ? "…" : `Apply to W${safeWeek}`}
                                </button>
                              </div>
                            );
                          })}
                        </>
                      )}
                    </div>
                  )}
                </>
              )}

              {/* Day tabs */}
              <div className="px-5 pt-3 pb-0 flex gap-1 overflow-x-auto border-b border-zinc-800/30">
                {Array.from({ length: 7 }).map((_, idx) => {
                  const dateStr = getScheduledDate(currentPlan.startDate!, safeWeek, idx);
                  const dayLabel = getDayName(dateStr);
                  const mealCount = currentPlan.meals.filter(
                    (m) => m.scheduledDate === dateStr
                  ).length;
                  const isActive = safeDay === idx;
                  const isRest = mealCount === 0 && restDays.has(dateStr);

                  return (
                    <button
                      key={idx}
                      onClick={() => { setSelectedDay(idx); setShowAddMeal(false); }}
                      className={`group relative flex-shrink-0 px-5 py-4 transition-all ${
                        isActive ? "text-white" : "text-zinc-500 hover:text-zinc-300"
                      }`}
                    >
                      <div className="relative z-10">
                        <span className="block text-[10px] font-black uppercase tracking-[0.2em] mb-1">
                          {dayLabel.slice(0, 3)}
                        </span>
                        <span className="block text-xs font-bold opacity-60 group-hover:opacity-100 transition-opacity whitespace-nowrap">
                          {formatDate(dateStr)}
                        </span>
                        {mealCount > 0 ? (
                          <div className="absolute -top-1 -right-2 flex gap-0.5">
                            {Array.from({ length: Math.min(mealCount, 3) }).map((_, i) => (
                              <div key={i} className="w-1 h-1 rounded-full bg-[#F1C40F] shadow-[0_0_5px_rgba(241,196,15,0.8)]" />
                            ))}
                          </div>
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
                  );
                })}
              </div>

              {/* Day content */}
              <div className="p-5 space-y-4">
                {/* Day header with save/import actions */}
                <div className="flex items-center justify-between gap-2">
                  <p className="text-[10px] text-zinc-600 font-black uppercase tracking-widest">
                    {scheduledDateForDay ? getDayName(scheduledDateForDay) : `Day ${safeDay + 1}`}
                    {scheduledDateForDay && (
                      <span className="font-normal normal-case ml-1 text-zinc-700">
                        — {formatDate(scheduledDateForDay)}
                      </span>
                    )}
                  </p>
                  <div className="flex items-center gap-1.5 flex-wrap justify-end">
                    {dayMeals.some((m) => m.isDraft) && (
                      <button
                        onClick={() => publishDayDraftsMutation.mutate()}
                        disabled={publishDayDraftsMutation.isPending}
                        className="px-2 py-1 text-[9px] font-bold uppercase text-emerald-600 hover:text-emerald-400 bg-emerald-900/20 border border-emerald-700/30 rounded-lg transition-colors disabled:opacity-50"
                      >
                        {publishDayDraftsMutation.isPending
                          ? "Publishing…"
                          : `Publish (${dayMeals.filter((m) => m.isDraft).length})`}
                      </button>
                    )}
                    {dayMeals.length > 0 && (
                      <button
                        onClick={() => { setSaveDayDialog(true); setLibraryNameInput(`${scheduledDateForDay ? getDayName(scheduledDateForDay) : "Day"} W${safeWeek} — ${currentPlan.name}`); }}
                        className="px-2 py-1 text-[9px] font-bold uppercase text-violet-500 hover:text-violet-300 bg-violet-900/20 border border-violet-700/30 rounded-lg transition-colors"
                        title="Save day to your library"
                      >
                        + Library
                      </button>
                    )}
                    {(draftByDate.length > 0 || dayTemplates.length > 0) && (
                      <button
                        onClick={() => { setShowDayImport((v) => !v); setSlotImportOpen(null); }}
                        className={`px-2 py-1 text-[9px] font-bold uppercase rounded-lg transition-colors border ${
                          showDayImport
                            ? "bg-[#F1C40F]/10 border-[#F1C40F]/30 text-[#F1C40F]"
                            : "bg-zinc-800/80 border-zinc-700/50 text-zinc-500 hover:text-zinc-300"
                        }`}
                      >
                        Import Day {showDayImport ? "▴" : "▾"}
                      </button>
                    )}
                    {draftCount > 0 && (
                      <button
                        onClick={() => setShowDraftLibrary(true)}
                        className="px-2 py-1 text-[9px] font-bold uppercase text-zinc-600 hover:text-[#F1C40F] bg-zinc-800/80 rounded-lg transition-colors"
                      >
                        All Drafts ({draftCount})
                      </button>
                    )}
                  </div>
                </div>

                {/* Inline day import panel — drafts + library */}
                {showDayImport && scheduledDateForDay && (draftByDate.length > 0 || dayTemplates.length > 0) && (
                  <div className="bg-zinc-900/50 border border-zinc-700/50 rounded-xl overflow-hidden -mt-1">
                    {draftByDate.length > 0 && (
                      <>
                        <p className="px-3 py-2 text-[9px] text-zinc-500 font-black uppercase tracking-widest border-b border-zinc-800/60">
                          Draft days (this plan) → {formatDate(scheduledDateForDay)}
                        </p>
                        {draftByDate.map(({ date, meals, totalCals }) => (
                          <div key={date} className="flex items-center gap-3 px-3 py-2.5 hover:bg-zinc-800/30 border-b border-zinc-800/40 last:border-0">
                            <div className="flex-1 min-w-0">
                              <p className="text-xs font-semibold text-zinc-200">{formatDate(date)}</p>
                              <p className="text-[10px] text-zinc-500">
                                {meals.length} meal{meals.length !== 1 ? "s" : ""} · {totalCals} kcal
                                <span className="ml-1.5">
                                  {meals.slice(0, 4).map((m) => getMealSlot(m.timeOfDay).emoji).join(" ")}
                                  {meals.length > 4 && ` +${meals.length - 4}`}
                                </span>
                              </p>
                            </div>
                            <button
                              onClick={() => applyDraftMutation.mutate({ meals, targetDate: scheduledDateForDay })}
                              disabled={applyDraftMutation.isPending}
                              className="px-3 py-1.5 bg-[#F1C40F] text-black text-[10px] font-black uppercase rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 flex-shrink-0"
                            >
                              {applyDraftMutation.isPending ? "…" : "Apply"}
                            </button>
                          </div>
                        ))}
                      </>
                    )}
                    {dayTemplates.length > 0 && (
                      <>
                        <p className="px-3 py-2 text-[9px] text-violet-400 font-black uppercase tracking-widest border-b border-zinc-800/60">
                          My Library
                        </p>
                        {dayTemplates.map((tpl) => {
                          const meals = (tpl.data as { meals: TrainerTemplateMeal[] }).meals;
                          const totalCals = meals.reduce((s, m) => s + m.totalCalories, 0);
                          return (
                            <div key={tpl.id} className="flex items-center gap-3 px-3 py-2.5 hover:bg-zinc-800/30 border-b border-zinc-800/40 last:border-0">
                              <div className="flex-1 min-w-0">
                                <p className="text-xs font-semibold text-violet-300">{tpl.name}</p>
                                <p className="text-[10px] text-zinc-500">
                                  {meals.length} meal{meals.length !== 1 ? "s" : ""} · {totalCals} kcal
                                </p>
                              </div>
                              <button
                                onClick={() => applyTemplateToDay.mutate({ template: tpl, targetDate: scheduledDateForDay })}
                                disabled={applyTemplateToDay.isPending}
                                className="px-3 py-1.5 bg-violet-600 text-white text-[10px] font-black uppercase rounded-lg hover:bg-violet-500 disabled:opacity-50 flex-shrink-0"
                              >
                                {applyTemplateToDay.isPending ? "…" : "Apply"}
                              </button>
                            </div>
                          );
                        })}
                      </>
                    )}
                  </div>
                )}

                {/* Day macro bars */}
                {dayMeals.length > 0 && (
                  <div className="bg-zinc-900/50 border border-zinc-800/50 rounded-xl p-4 space-y-2">
                    <p className="text-[9px] text-zinc-600 uppercase font-black tracking-widest mb-2">
                      {scheduledDateForDay ? getDayName(scheduledDateForDay) : `Day ${safeDay + 1}`} — Daily Totals
                    </p>
                    <MacroBar
                      label="Calories"
                      current={dayTotals.calories}
                      target={weekTargetsForSelected.calories}
                      color="text-white"
                      unit="kcal"
                    />
                    <div className="grid grid-cols-3 gap-3">
                      <MacroBar label="Protein" current={dayTotals.protein} target={weekTargetsForSelected.protein} color="text-blue-400" />
                      <MacroBar label="Carbs" current={dayTotals.carbs} target={weekTargetsForSelected.carbs} color="text-yellow-400" />
                      <MacroBar label="Fats" current={dayTotals.fat} target={weekTargetsForSelected.fats} color="text-red-400" />
                    </div>
                  </div>
                )}

                {/* Meal list — grouped by slot */}
                {dayMeals.length > 0 ? (
                  <div className="space-y-4">
                    {MEAL_SLOTS.filter((s) => dayMeals.some((m) => m.timeOfDay === s.key)).map((slot) => {
                      const slotMeals = dayMeals.filter((m) => m.timeOfDay === slot.key);
                      const slotDrafts = draftBySlot.get(slot.key) ?? [];
                      const slotLibrary = mealTemplates.filter((t) => {
                        const d = t.data as { meals: TrainerTemplateMeal[] };
                        return d.meals[0]?.timeOfDay === slot.key;
                      });
                      const hasSlotImports = slotDrafts.length > 0 || slotLibrary.length > 0;
                      const slotImportActive = slotImportOpen === slot.key;
                      return (
                        <div key={slot.key}>
                          {/* Slot header */}
                          <div className="flex items-center gap-2 mb-2">
                            <span className="text-base">{slot.emoji}</span>
                            <span className="text-xs font-black uppercase tracking-widest text-zinc-400">{slot.label}</span>
                            <div className="flex-1 h-px bg-zinc-800" />
                            {hasSlotImports && (
                              <button
                                onClick={() => { setSlotImportOpen(slotImportActive ? null : slot.key); setShowDayImport(false); }}
                                className={`flex items-center gap-1 px-2 py-0.5 text-[9px] font-bold uppercase rounded border transition-colors flex-shrink-0 ${
                                  slotImportActive
                                    ? "bg-[#F1C40F]/10 border-[#F1C40F]/30 text-[#F1C40F]"
                                    : "border-zinc-700/50 text-zinc-600 hover:text-[#F1C40F] hover:border-[#F1C40F]/30"
                                }`}
                              >
                                Import ({slotDrafts.length + slotLibrary.length})
                              </button>
                            )}
                          </div>
                          {/* Slot import panel — plan drafts + library meals */}
                          {slotImportActive && scheduledDateForDay && (
                            <div className="mb-3 bg-zinc-900/60 border border-zinc-700/40 rounded-xl overflow-hidden">
                              {slotDrafts.length > 0 && (
                                <>
                                  <p className="px-3 py-1.5 text-[9px] text-zinc-500 font-black uppercase tracking-widest border-b border-zinc-800/60">
                                    Draft {slot.label}s → add to {formatDate(scheduledDateForDay)}
                                  </p>
                                  {slotDrafts.map((dm) => {
                                    const ingredients = (dm.items as TrainerMealItems | null)?.ingredients ?? [];
                                    return (
                                      <div key={dm.id} className="flex items-center gap-3 px-3 py-2.5 hover:bg-zinc-800/40 border-b border-zinc-800/30 last:border-0">
                                        <div className="flex-1 min-w-0">
                                          <p className="text-xs font-semibold text-zinc-200">{dm.name}</p>
                                          <p className="text-[10px] text-zinc-500">
                                            {dm.totalCalories} kcal · P{dm.protein}g C{dm.carbs}g F{dm.fats}g
                                            {ingredients.length > 0 && ` · ${ingredients.length} ing.`}
                                          </p>
                                        </div>
                                        <button
                                          onClick={() => applyDraftMutation.mutate({ meals: [dm], targetDate: scheduledDateForDay })}
                                          disabled={applyDraftMutation.isPending}
                                          className="px-2.5 py-1 bg-[#F1C40F] text-black text-[9px] font-black uppercase rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 flex-shrink-0"
                                        >
                                          {applyDraftMutation.isPending ? "…" : "Use"}
                                        </button>
                                      </div>
                                    );
                                  })}
                                </>
                              )}
                              {slotLibrary.length > 0 && (
                                <>
                                  <p className="px-3 py-1.5 text-[9px] text-violet-400 font-black uppercase tracking-widest border-b border-zinc-800/60">
                                    My Library
                                  </p>
                                  {slotLibrary.map((tpl) => {
                                    const m = (tpl.data as { meals: TrainerTemplateMeal[] }).meals[0];
                                    if (!m) return null;
                                    return (
                                      <div key={tpl.id} className="flex items-center gap-3 px-3 py-2.5 hover:bg-zinc-800/40 border-b border-zinc-800/30 last:border-0">
                                        <div className="flex-1 min-w-0">
                                          <p className="text-xs font-semibold text-violet-300">{tpl.name}</p>
                                          <p className="text-[10px] text-zinc-500">
                                            {m.totalCalories} kcal · P{m.protein}g C{m.carbs}g F{m.fats}g
                                          </p>
                                        </div>
                                        <button
                                          onClick={() => applyTemplateToDay.mutate({ template: tpl, targetDate: scheduledDateForDay })}
                                          disabled={applyTemplateToDay.isPending}
                                          className="px-2.5 py-1 bg-violet-600 text-white text-[9px] font-black uppercase rounded-lg hover:bg-violet-500 disabled:opacity-50 flex-shrink-0"
                                        >
                                          {applyTemplateToDay.isPending ? "…" : "Use"}
                                        </button>
                                      </div>
                                    );
                                  })}
                                </>
                              )}
                            </div>
                          )}
                          <div className="space-y-2 pl-1">
                            {slotMeals.map((meal, idx) => {
                              const isFirst = slotOrder(meal.timeOfDay) === 0 && idx === 0;
                              const isLast = slotOrder(meal.timeOfDay) === MEAL_SLOTS.length - 1 && idx === slotMeals.length - 1;
                              return (
                                <MealDisplayCard
                                  key={meal.id}
                                  meal={meal}
                                  token={token!}
                                  memberId={memberId}
                                  planTargetCalories={currentPlan.targetCalories}
                                  onSaveToLibrary={(m) => { setSaveMealDialog({ meal: m }); setLibraryNameInput(m.name); }}
                                  isFirst={isFirst}
                                  isLast={isLast}
                                  onMoveUp={() => handleMoveMeal(meal.id, "up")}
                                  onMoveDown={() => handleMoveMeal(meal.id, "down")}
                                  unitPref={unitPref}
                                  lang={langPref}
                                />
                              );
                            })}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  !showAddMeal && scheduledDateForDay && (
                    <div className="space-y-2 py-4">
                      <p className="text-zinc-600 text-sm text-center">
                        No meals planned for this day yet.
                      </p>
                      <div className="flex justify-center">
                        <button
                          onClick={() => toggleRestDay(scheduledDateForDay)}
                          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all border ${
                            restDays.has(scheduledDateForDay)
                              ? "bg-zinc-800/60 border-zinc-700 text-zinc-400 hover:border-red-500/30 hover:text-red-400"
                              : "bg-transparent border-zinc-800/50 text-zinc-700 hover:text-zinc-400 hover:border-zinc-700"
                          }`}
                        >
                          {restDays.has(scheduledDateForDay) ? "🛌 Rest Day — click to clear" : "Mark as Rest Day"}
                        </button>
                      </div>
                    </div>
                  )
                )}

                {/* Copy Day panel */}
                {showCopyDay && (
                  <div className="bg-zinc-900/60 border border-zinc-700 rounded-xl p-4 space-y-3">
                    <p className="text-[10px] font-black uppercase tracking-widest text-zinc-400">
                      Copy {scheduledDateForDay ? getDayName(scheduledDateForDay) : "Day"} (Week {safeWeek}) to…
                    </p>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[9px] text-zinc-500 uppercase font-black mb-1">Target Week</label>
                        <div className="flex gap-1 flex-wrap">
                          {Array.from({ length: numWeeks }, (_, i) => i + 1).map((w) => (
                            <button
                              key={w}
                              onClick={() => setCopyTargetWeek(w)}
                              className={`px-3 py-1 text-xs font-bold rounded-lg border transition-colors ${
                                copyTargetWeek === w
                                  ? "bg-[#F1C40F]/15 border-[#F1C40F]/50 text-[#F1C40F]"
                                  : "bg-zinc-800 border-zinc-700 text-zinc-500 hover:text-zinc-300"
                              }`}
                            >
                              W{w}
                            </button>
                          ))}
                        </div>
                      </div>
                      <div>
                        <label className="block text-[9px] text-zinc-500 uppercase font-black mb-1">Target Day</label>
                        <div className="flex gap-1 flex-wrap">
                          {Array.from({ length: 7 }).map((_, idx) => {
                            const dummyDate = getScheduledDate(currentPlan.startDate!, 1, idx);
                            const label = getDayName(dummyDate);
                            return (
                              <button
                                key={idx}
                                onClick={() => setCopyTargetDay(idx)}
                                className={`px-2 py-1 text-xs font-bold rounded-lg border transition-colors ${
                                  copyTargetDay === idx
                                    ? "bg-[#F1C40F]/15 border-[#F1C40F]/50 text-[#F1C40F]"
                                    : "bg-zinc-800 border-zinc-700 text-zinc-500 hover:text-zinc-300"
                                }`}
                              >
                                {label}
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    </div>
                    {copyTargetWeek === safeWeek && copyTargetDay === safeDay && (
                      <p className="text-[10px] text-orange-400">Select a different target day/week.</p>
                    )}
                    <div className="flex gap-2 flex-wrap">
                      <button
                        onClick={() => copyDayMutation.mutate({ fromWeek: safeWeek, fromDay: safeDay, toWeek: copyTargetWeek, toDay: copyTargetDay })}
                        disabled={copyDayMutation.isPending || copyDayToAllWeeksMutation.isPending || (copyTargetWeek === safeWeek && copyTargetDay === safeDay)}
                        className="flex items-center gap-1.5 px-4 py-2 bg-[#F1C40F] text-black text-xs font-bold rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 transition-colors"
                      >
                        {copyDayMutation.isPending ? "Copying…" : "Copy Meals"}
                      </button>
                      {numWeeks > 1 && (
                        <button
                          onClick={() => copyDayToAllWeeksMutation.mutate()}
                          disabled={copyDayMutation.isPending || copyDayToAllWeeksMutation.isPending}
                          className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white text-xs font-bold rounded-lg hover:bg-blue-500 disabled:opacity-50 transition-colors"
                        >
                          {copyDayToAllWeeksMutation.isPending ? "Copying…" : `Copy to all ${numWeeks - 1} other week${numWeeks - 1 !== 1 ? "s" : ""}`}
                        </button>
                      )}
                      <button
                        onClick={() => setShowCopyDay(false)}
                        className="px-4 py-2 bg-zinc-800 text-zinc-400 text-xs font-bold rounded-lg hover:bg-zinc-700 transition-colors"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                )}

                {/* Add meal / Copy day actions */}
                <div className="flex gap-2">
                  <button
                    onClick={() => { setShowAddMeal(true); setShowCopyDay(false); }}
                    className="flex-1 flex items-center justify-center gap-2 py-3 border border-dashed border-zinc-700 rounded-xl text-zinc-500 hover:text-[#F1C40F] hover:border-[#F1C40F]/40 transition-colors text-sm"
                  >
                    <Plus size={15} />
                    Add Meal to {scheduledDateForDay ? getDayName(scheduledDateForDay) : `Day ${safeDay + 1}`}
                  </button>
                  {dayMeals.length > 0 && !showCopyDay && (
                    <button
                      onClick={() => { setShowCopyDay(true); setCopyTargetWeek(safeWeek); setCopyTargetDay((safeDay + 1) % 7); }}
                      className="flex items-center gap-1.5 px-3 py-2 border border-dashed border-zinc-700 rounded-xl text-zinc-500 hover:text-blue-400 hover:border-blue-400/40 transition-colors text-xs"
                    >
                      <Calendar size={13} />
                      Copy Day
                    </button>
                  )}
                </div>
              </div>
            </>
          ) : (
            /* Legacy plans without startDate — flat meal list */
            <div className="p-5 space-y-4">
              <div className="bg-zinc-900/50 border border-zinc-800/50 rounded-xl p-4 space-y-2">
                <MacroBar label="Calories" current={currentPlan.meals.reduce((s, m) => s + m.totalCalories, 0)} target={currentPlan.targetCalories} color="text-white" unit="kcal" />
                <div className="grid grid-cols-3 gap-3">
                  <MacroBar label="Protein" current={currentPlan.meals.reduce((s, m) => s + m.protein, 0)} target={currentPlan.targetProtein} color="text-blue-400" />
                  <MacroBar label="Carbs" current={currentPlan.meals.reduce((s, m) => s + m.carbs, 0)} target={currentPlan.targetCarbs} color="text-yellow-400" />
                  <MacroBar label="Fat" current={currentPlan.meals.reduce((s, m) => s + m.fats, 0)} target={currentPlan.targetFats} color="text-red-400" />
                </div>
              </div>

              <div className="space-y-4">
                {MEAL_SLOTS.filter((s) => currentPlan.meals.some((m) => m.timeOfDay === s.key)).map((slot) => {
                  const slotMeals = [...currentPlan.meals]
                    .filter((m) => m.timeOfDay === slot.key);
                  return (
                    <div key={slot.key}>
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-base">{slot.emoji}</span>
                        <span className="text-xs font-black uppercase tracking-widest text-zinc-400">{slot.label}</span>
                        <div className="flex-1 h-px bg-zinc-800" />
                      </div>
                      <div className="space-y-2 pl-1">
                        {slotMeals.map((m) => (
                          <MealDisplayCard
                            key={m.id}
                            meal={m}
                            token={token!}
                            memberId={memberId}
                            planTargetCalories={currentPlan.targetCalories}
                            unitPref={unitPref}
                            lang={langPref}
                          />
                        ))}
                      </div>
                    </div>
                  );
                })}
              </div>

              <p className="text-[10px] text-zinc-600 text-center">
                This plan has no start date. Create a new plan to use the weekly day builder.
              </p>
            </div>
          )}
        </div>
      )}

      {!currentPlan && !isLoading && !showNewPlan && (
        <div className="text-center py-16 text-zinc-500">
          <ClipboardList size={32} className="mx-auto mb-3 opacity-20" />
          <p>No diet plans yet. Create one to get started.</p>
        </div>
      )}

      {/* Draft Library Modal */}
      {showDraftLibrary && currentPlan && scheduledDateForDay && (
        <DraftLibraryModal
          plan={currentPlan}
          token={token!}
          memberId={memberId}
          currentScheduledDate={scheduledDateForDay}
          onClose={() => setShowDraftLibrary(false)}
        />
      )}

      {/* ── Save Meal to Library dialog ── */}
      {saveMealDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
          <div className="bg-[#121721] border border-zinc-700 rounded-2xl p-6 w-full max-w-sm mx-4 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-white text-base">Save Meal to Library</h3>
              <button onClick={() => setSaveMealDialog(null)} className="text-zinc-500 hover:text-white"><X size={16}/></button>
            </div>
            <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest">
              Template name <span className="text-violet-400">({mealTemplates.length}/10 used)</span>
            </p>
            <input
              autoFocus
              value={libraryNameInput}
              onChange={(e) => setLibraryNameInput(e.target.value)}
              className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-white outline-none focus:border-violet-500"
              placeholder="e.g. High-protein breakfast"
              onKeyDown={(e) => {
                if (e.key === "Enter" && libraryNameInput.trim()) {
                  saveMealToLibraryMutation.mutate({ meal: saveMealDialog.meal, name: libraryNameInput.trim() });
                  setSaveMealDialog(null);
                }
              }}
            />
            <div className="flex gap-2">
              <button
                onClick={() => {
                  if (!libraryNameInput.trim()) return;
                  saveMealToLibraryMutation.mutate({ meal: saveMealDialog.meal, name: libraryNameInput.trim() });
                  setSaveMealDialog(null);
                }}
                disabled={!libraryNameInput.trim() || saveMealToLibraryMutation.isPending || mealTemplates.length >= 10}
                className="flex-1 py-2.5 bg-violet-600 text-white text-sm font-bold rounded-lg hover:bg-violet-500 disabled:opacity-50 transition-colors"
              >
                {mealTemplates.length >= 10 ? "Library Full (10/10)" : "Save to Library"}
              </button>
              <button onClick={() => setSaveMealDialog(null)} className="px-4 py-2.5 bg-zinc-800 text-zinc-400 text-sm font-bold rounded-lg hover:bg-zinc-700">Cancel</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Save Day to Library dialog ── */}
      {saveDayDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
          <div className="bg-[#121721] border border-zinc-700 rounded-2xl p-6 w-full max-w-sm mx-4 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-white text-base">Save Day to Library</h3>
              <button onClick={() => setSaveDayDialog(false)} className="text-zinc-500 hover:text-white"><X size={16}/></button>
            </div>
            <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest">
              {dayMeals.length} meal{dayMeals.length !== 1 ? "s" : ""} · Template name <span className="text-violet-400">({dayTemplates.length}/5 used)</span>
            </p>
            <input
              autoFocus
              value={libraryNameInput}
              onChange={(e) => setLibraryNameInput(e.target.value)}
              className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-white outline-none focus:border-violet-500"
              placeholder="e.g. Rest day low-carb"
              onKeyDown={(e) => {
                if (e.key === "Enter" && libraryNameInput.trim()) {
                  saveDayToLibraryMutation.mutate(libraryNameInput.trim());
                  setSaveDayDialog(false);
                }
              }}
            />
            <div className="flex gap-2">
              <button
                onClick={() => {
                  if (!libraryNameInput.trim()) return;
                  saveDayToLibraryMutation.mutate(libraryNameInput.trim());
                  setSaveDayDialog(false);
                }}
                disabled={!libraryNameInput.trim() || saveDayToLibraryMutation.isPending || dayTemplates.length >= 5}
                className="flex-1 py-2.5 bg-violet-600 text-white text-sm font-bold rounded-lg hover:bg-violet-500 disabled:opacity-50 transition-colors"
              >
                {dayTemplates.length >= 5 ? "Library Full (5/5)" : "Save to Library"}
              </button>
              <button onClick={() => setSaveDayDialog(false)} className="px-4 py-2.5 bg-zinc-800 text-zinc-400 text-sm font-bold rounded-lg hover:bg-zinc-700">Cancel</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Save Week to Library dialog ── */}
      {saveWeekDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
          <div className="bg-[#121721] border border-zinc-700 rounded-2xl p-6 w-full max-w-sm mx-4 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-white text-base">Save Week to Library</h3>
              <button onClick={() => setSaveWeekDialog(false)} className="text-zinc-500 hover:text-white"><X size={16}/></button>
            </div>
            <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest">
              Week {safeWeek} template name <span className="text-violet-400">({weekTemplates.length}/2 used)</span>
            </p>
            <input
              autoFocus
              value={libraryNameInput}
              onChange={(e) => setLibraryNameInput(e.target.value)}
              className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-white outline-none focus:border-violet-500"
              placeholder="e.g. Bulk week high-cal"
              onKeyDown={(e) => {
                if (e.key === "Enter" && libraryNameInput.trim()) {
                  saveWeekToLibraryMutation.mutate(libraryNameInput.trim());
                  setSaveWeekDialog(false);
                }
              }}
            />
            <div className="flex gap-2">
              <button
                onClick={() => {
                  if (!libraryNameInput.trim()) return;
                  saveWeekToLibraryMutation.mutate(libraryNameInput.trim());
                  setSaveWeekDialog(false);
                }}
                disabled={!libraryNameInput.trim() || saveWeekToLibraryMutation.isPending || weekTemplates.length >= 2}
                className="flex-1 py-2.5 bg-violet-600 text-white text-sm font-bold rounded-lg hover:bg-violet-500 disabled:opacity-50 transition-colors"
              >
                {weekTemplates.length >= 2 ? "Library Full (2/2)" : "Save to Library"}
              </button>
              <button onClick={() => setSaveWeekDialog(false)} className="px-4 py-2.5 bg-zinc-800 text-zinc-400 text-sm font-bold rounded-lg hover:bg-zinc-700">Cancel</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Template Library Management Modal ── */}
      {showTemplateLibrary && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          <div className="bg-[#121721] border border-zinc-700 rounded-2xl w-full max-w-lg mx-auto overflow-hidden flex flex-col max-h-[85vh]">
            <div className="flex items-center justify-between p-5 border-b border-zinc-800">
              <div>
                <h3 className="font-bold text-white text-base">My Template Library</h3>
                <p className="text-[10px] text-zinc-500 mt-0.5">Reusable across all members · Meals 10 · Days 5 · Weeks 2</p>
              </div>
              <button onClick={() => setShowTemplateLibrary(false)} className="text-zinc-500 hover:text-white"><X size={16}/></button>
            </div>
            <div className="overflow-y-auto flex-1 divide-y divide-zinc-800/60">
              {draftTemplates.length === 0 && (
                <div className="p-8 text-center text-zinc-500">
                  <p className="text-sm">No templates saved yet.</p>
                  <p className="text-[10px] mt-1">Use ★ on meals, or + Library on days/weeks to build your library.</p>
                </div>
              )}
              {(["meal", "day", "week"] as const).map((type) => {
                const group = draftTemplates.filter((t) => t.type === type);
                if (group.length === 0) return null;
                const limits = { meal: 10, day: 5, week: 2 };
                return (
                  <div key={type}>
                    <p className="px-5 py-2 text-[9px] text-violet-400 font-black uppercase tracking-widest bg-zinc-900/40">
                      {type === "meal" ? "Meal Templates" : type === "day" ? "Day Templates" : "Week Templates"} ({group.length}/{limits[type]})
                    </p>
                    {group.map((tpl) => (
                      <div key={tpl.id} className="flex items-center gap-3 px-5 py-3 hover:bg-zinc-800/30">
                        {renamingTemplateId === tpl.id ? (
                          <input
                            autoFocus
                            value={renameValue}
                            onChange={(e) => setRenameValue(e.target.value)}
                            onKeyDown={(e) => {
                              if (e.key === "Enter" && renameValue.trim()) renameTemplateMutation.mutate({ id: tpl.id, name: renameValue.trim() });
                              if (e.key === "Escape") setRenamingTemplateId(null);
                            }}
                            className="flex-1 bg-zinc-900 border border-violet-600 rounded-lg px-2 py-1 text-sm text-white outline-none"
                          />
                        ) : (
                          <p className="flex-1 text-sm text-zinc-200 font-medium">{tpl.name}</p>
                        )}
                        <div className="flex gap-1.5 flex-shrink-0">
                          {renamingTemplateId === tpl.id ? (
                            <>
                              <button
                                onClick={() => { if (renameValue.trim()) renameTemplateMutation.mutate({ id: tpl.id, name: renameValue.trim() }); }}
                                className="px-2 py-1 text-[9px] font-bold uppercase bg-violet-600 text-white rounded hover:bg-violet-500"
                              >Save</button>
                              <button onClick={() => setRenamingTemplateId(null)} className="px-2 py-1 text-[9px] font-bold uppercase bg-zinc-700 text-zinc-300 rounded">Cancel</button>
                            </>
                          ) : (
                            <>
                              <button
                                onClick={() => { setRenamingTemplateId(tpl.id); setRenameValue(tpl.name); }}
                                className="p-1.5 text-zinc-600 hover:text-violet-400 transition-colors rounded"
                                title="Rename"
                              >
                                <Pencil size={12} />
                              </button>
                              <button
                                onClick={() => deleteTemplateMutation.mutate(tpl.id)}
                                disabled={deleteTemplateMutation.isPending}
                                className="p-1.5 text-zinc-600 hover:text-red-400 transition-colors rounded"
                                title="Delete"
                              >
                                <Trash2 size={16} />
                              </button>
                            </>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}


      {/* Activate plan confirmation modal */}
      {confirmActivate && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
          <div className="bg-[#121721] border border-zinc-700 rounded-2xl p-6 w-full max-w-sm mx-4 space-y-4">
            <h3 className="font-bold text-white text-base">Activate Plan?</h3>
            <p className="text-sm text-zinc-400">
              This will deactivate the current active plan and set{" "}
              <span className="font-bold text-white">
                {plans?.find((p) => p.id === confirmActivate)?.name}
              </span>{" "}
              as the member&apos;s active diet plan. The member will see this plan on their phone.
            </p>
            <div className="flex gap-3 pt-1">
              <button
                onClick={() => {
                  activatePlan.mutate(confirmActivate);
                  setConfirmActivate(null);
                }}
                disabled={activatePlan.isPending}
                className="flex-1 py-2.5 bg-[#F1C40F] text-black text-sm font-bold rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 transition-colors"
              >
                Yes, Activate
              </button>
              <button
                onClick={() => setConfirmActivate(null)}
                className="flex-1 py-2.5 bg-zinc-800 text-zinc-300 text-sm font-bold rounded-lg hover:bg-zinc-700 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Meal Overlay */}
      {showAddMeal && currentPlan && (
        <div className="fixed inset-0 z-[150] flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/80 backdrop-blur-sm animate-in fade-in duration-300" onClick={() => setShowAddMeal(false)} />
          <div className="relative w-full max-w-3xl animate-in zoom-in-95 fade-in duration-300 max-h-[90vh] overflow-y-auto rounded-xl">
            <AddMealForm
              planId={currentPlan.id}
              scheduledDate={getScheduledDate(currentPlan.startDate!, safeWeek, safeDay)}
              unitPref={unitPref}
              lang={langPref}
              token={token!}
              memberId={memberId}
              onDone={() => {
                setShowAddMeal(false);
                qc.invalidateQueries({ queryKey: ["trainer-diet-plans", memberId] });
              }}
            />
          </div>
        </div>
      )}

      {/* Fixed Action Footer */}
      {currentPlan && (
        <MagicActionFooter
          addLabel="Add Meal"
          onAdd={() => setShowAddMeal(true)}
          onImport={() => setShowDayImport(v => !v)}
          onLibrary={() => setShowTemplateLibrary(true)}
          onCopy={dayMeals.length > 0 ? () => setShowCopyDay(v => !v) : undefined}
          hasItems={dayMeals.length > 0}
          isDraft={!currentPlan.isPublished}
          onToggleDraft={!currentPlan.isPublished ? () => publishPlan.mutate(currentPlan.id) : undefined}
        />
      )}

      {/* Toast */}
      {toastMsg && (
        <div className="fixed bottom-28 left-1/2 -translate-x-1/2 z-[500] px-5 py-2.5 bg-zinc-900 border border-[#F1C40F]/30 text-white text-xs font-bold rounded-xl shadow-2xl animate-in slide-in-from-bottom-4 duration-300 whitespace-nowrap">
          {toastMsg}
        </div>
      )}

      {/* AI Gen: disabled — button is greyed out in footer, modal removed */}
      {/* Edit Plan Modal */}
      {showEditPlan && currentPlan && (
        <div className="fixed inset-0 z-[250] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          <div className="bg-[#121721] border border-zinc-700 rounded-2xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-200">
            <div className="flex items-center justify-between p-5 border-b border-zinc-800">
              <h3 className="font-bold text-white text-base">Plan Settings</h3>
              <button onClick={() => setShowEditPlan(false)} className="text-zinc-500 hover:text-white"><X size={16}/></button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <label className="amirani-label !mb-2">Plan Name</label>
                <input
                  value={planName}
                  onChange={(e) => setPlanName(e.target.value)}
                  className="amirani-input"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="amirani-label !mb-2">Hydration Target (ml)</label>
                  <input
                    type="number"
                    value={hydrationTargetMl}
                    onChange={(e) => setHydrationTargetMl(e.target.value)}
                    className="amirani-input"
                  />
                </div>
              </div>

              <div>
                <label className="amirani-label !mb-2">Key Nutrition Insights</label>
                <textarea
                  value={keyNutritionInsights}
                  onChange={(e) => setKeyNutritionInsights(e.target.value)}
                  placeholder="Premium dietary guidance..."
                  className="w-full h-24 bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-sm text-white placeholder-zinc-700 outline-none focus:border-[#F1C40F]/40 transition-colors resize-none"
                />
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  onClick={() => updatePlan.mutate({
                    name: planName,
                    hydrationTargetMl: parseInt(hydrationTargetMl),
                    keyNutritionInsights: keyNutritionInsights.trim() || "",
                  })}
                  disabled={updatePlan.isPending}
                  className="flex-1 py-2.5 bg-[#F1C40F] text-black text-sm font-bold rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 transition-colors"
                >
                  {updatePlan.isPending ? "Saving…" : "Save Changes"}
                </button>
                <button onClick={() => setShowEditPlan(false)} className="px-4 py-2 bg-zinc-800 text-zinc-300 text-sm font-bold rounded-lg hover:bg-zinc-700">Cancel</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
