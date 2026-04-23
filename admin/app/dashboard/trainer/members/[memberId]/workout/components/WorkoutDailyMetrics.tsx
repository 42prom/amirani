"use client";

import { useMemo } from "react";
import { type TrainerWorkoutExercise } from "@/lib/api";

interface MetricBarProps {
  label: string;
  current: number;
  target: number;
  color: string;
  unit?: string;
}

function MetricBar({
  label, current, target, color, unit = "",
}: MetricBarProps) {
  const pct = target > 0 ? Math.min((current / target) * 100, 100) : 0;
  const over = target > 0 && current > target;
  
  // Convert standard lucide/tailwind text-color to bg-color for the bar
  const barColor = color.replace("text-", "bg-");

  return (
    <div className="flex-1 min-w-[140px]">
      <div className="flex items-center justify-between mb-1">
        <span className="text-[9px] text-zinc-500 uppercase font-black tracking-widest">{label}</span>
        <span className={`text-[10px] font-black italic transition-colors ${over ? "text-rose-400" : color}`}>
          {current.toLocaleString()}{unit}
          <span className="text-zinc-600 font-normal ml-0.5 normal-case tracking-normal">/{target}{unit}</span>
        </span>
      </div>
      <div className="h-1.5 bg-zinc-900/50 rounded-full overflow-hidden border border-white/5">
        <div 
          className={`h-full rounded-full transition-all duration-1000 ease-out shadow-[0_0_10px_rgba(255,255,255,0.05)] ${barColor}`} 
          style={{ width: `${pct}%` }} 
        />
      </div>
    </div>
  );
}

interface WorkoutDailySummaryProps {
  exercises: TrainerWorkoutExercise[];
}

export function WorkoutDailySummary({
  exercises
}: WorkoutDailySummaryProps) {
  const stats = useMemo(() => {
    const totalSets = exercises.reduce((s, ex) => s + (ex.targetSets || 0), 0);
    const rpeExercises = exercises.filter(e => e.rpe != null);
    const avgRpe = rpeExercises.length > 0 
      ? rpeExercises.reduce((s, e) => s + (e.rpe as number), 0) / rpeExercises.length 
      : 0;
    
    const estVolume = exercises.reduce((s, ex) => {
      const sets = Number(ex.targetSets) || 0;
      // Handle string reps (e.g. "8-12" -> 8)
      const repsRaw = (ex.targetReps || "10").toString();
      const reps = parseInt(repsRaw.split("-")[0]) || 10;
      const weight = typeof ex.targetWeight === 'number' ? ex.targetWeight : parseFloat((ex.targetWeight || "0").toString()) || 0;
      return s + (sets * reps * weight);
    }, 0);

    return { totalSets, avgRpe, estVolume };
  }, [exercises]);

  if (exercises.length === 0) return null;

  return (
    <div className="bg-zinc-900/40 border border-zinc-800/50 rounded-2xl p-4 mb-4 animate-in fade-in slide-in-from-top-2 duration-500">
       <p className="text-[9px] text-zinc-600 uppercase font-black tracking-widest mb-3 flex items-center gap-2">
          <span className="w-1 h-1 rounded-full bg-[#F1C40F]" />
          Session Performance Metrics
       </p>
       
       <div className="flex flex-col sm:flex-row gap-4 sm:gap-6">
          <MetricBar 
            label="Volume" 
            current={Math.round(stats.estVolume)} 
            target={15000} 
            color="text-emerald-400" 
            unit="lbs"
          />
          
          <MetricBar 
            label="Intensity" 
            current={Math.round(stats.avgRpe * 10)} 
            target={100} 
            color={stats.avgRpe >= 8 ? "text-rose-400" : "text-amber-400"}
            unit="rpe"
          />

          <div className="flex-1 min-w-[140px]">
            <p className="text-[9px] text-zinc-500 font-black uppercase tracking-widest mb-1">Working Sets</p>
            <div className="flex items-center gap-1.5 h-1.5 mt-2.5">
               {Array.from({ length: Math.min(stats.totalSets, 15) }).map((_, i) => (
                 <div key={i} className="flex-1 h-full rounded-full bg-[#F1C40F] shadow-[0_0_8px_rgba(241,196,15,0.3)]" />
               ))}
               {stats.totalSets === 0 && <div className="flex-1 h-full rounded-full bg-zinc-800" />}
               {stats.totalSets > 15 && (
                 <span className="text-[8px] font-black text-zinc-600 ml-1">+{stats.totalSets - 15}</span>
               )}
            </div>
          </div>
       </div>
    </div>
  );
}
