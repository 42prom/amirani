"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Plus, Flame, Zap, Check, X, Pencil, Star, Loader2, Trash2 } from "lucide-react";
import { trainerApi, type TrainerWorkoutExercise } from "@/lib/api";

interface ExerciseCardProps {
  ex: TrainerWorkoutExercise;
  token: string;
  memberId: string;
  onSaveToLibrary?: (ex: TrainerWorkoutExercise) => void;
  isFirst?: boolean;
  isLast?: boolean;
  onMoveUp?: () => void;
  onMoveDown?: () => void;
}

export function ExerciseCard({
  ex, token, memberId, onSaveToLibrary, isFirst, isLast, onMoveUp, onMoveDown,
}: ExerciseCardProps) {
  const qc = useQueryClient();
  const [editingNote, setEditingNote] = useState(false);
  const [noteValue, setNoteValue] = useState(ex.progressionNote ?? "");

  const deleteEx = useMutation({
    mutationFn: () => trainerApi.deleteExercise(ex.id, token),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] }),
  });

  const saveNote = useMutation({
    mutationFn: (note: string) => trainerApi.updateExercise(ex.id, { progressionNote: note || undefined }, token),
    onSuccess: () => { 
      qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] }); 
      setEditingNote(false); 
    },
  });

  const rpe = ex.rpe;
  const isChallenge = rpe != null && rpe >= 9;
  const isHard = rpe != null && rpe >= 7 && rpe < 9;

  const intensityStyles = isChallenge
    ? "border-rose-500/30 shadow-[0_0_20px_rgba(244,63,94,0.1)] bg-rose-500/[0.02]"
    : isHard
    ? "border-amber-500/30 shadow-[0_0_20px_rgba(245,158,11,0.1)] bg-amber-500/[0.02]"
    : "border-white/5 hover:border-white/10 bg-zinc-900/40";

  return (
    <div className={`relative group backdrop-blur-sm border rounded-2xl p-4 transition-all duration-300 ${intensityStyles}`}>
      <div className="flex items-start gap-4">
        {/* Reorder buttons */}
        <div className="flex flex-col gap-1 pt-1 flex-shrink-0">
          <button
            onClick={onMoveUp}
            disabled={isFirst}
            className="p-1 text-zinc-700 hover:text-[#F1C40F] disabled:opacity-5 transition-all hover:scale-110"
            title="Move up"
          >
            <Plus size={14} className="rotate-45" />
          </button>
          <div className="w-px h-2 bg-zinc-800 mx-auto" />
          <button
            onClick={onMoveDown}
            disabled={isLast}
            className="p-1 text-zinc-700 hover:text-[#F1C40F] disabled:opacity-5 transition-all hover:scale-110"
            title="Move down"
          >
            <Plus size={14} className="rotate-45" />
          </button>
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap mb-2">
            <h4 className="text-sm font-black text-white italic tracking-tight uppercase">{ex.exerciseName}</h4>
            
            {isChallenge && (
              <span className="inline-flex items-center gap-0.5 px-2 py-0.5 bg-rose-500/10 border border-rose-500/20 text-rose-400 text-[8px] font-black uppercase tracking-wider rounded-lg">
                <Flame size={10} strokeWidth={3} /> PEAK INTENSITY
              </span>
            )}
            
            {!isChallenge && isHard && (
              <span className="inline-flex items-center gap-0.5 px-2 py-0.5 bg-amber-500/10 border border-amber-500/20 text-amber-400 text-[8px] font-black uppercase tracking-wider rounded-lg">
                <Zap size={10} strokeWidth={3} /> HARD SET
              </span>
            )}
            
            {rpe != null && (
              <span className="px-2 py-0.5 bg-zinc-800 text-zinc-500 text-[8px] font-black uppercase tracking-widest rounded-lg border border-white/5">
                RPE {rpe}
              </span>
            )}
          </div>

          <div className="flex items-center gap-4">
             <div className="flex items-center gap-1.5 px-3 py-1.5 bg-zinc-950/40 rounded-xl border border-white/5">
                <div className="flex gap-1">
                  {Array.from({ length: Math.min(ex.targetSets, 5) }).map((_, i) => (
                    <div key={i} className="w-1.5 h-1.5 rounded-full bg-[#F1C40F]" />
                  ))}
                  {ex.targetSets > 5 && <div className="text-[8px] font-black text-[#F1C40F] ml-0.5">+{ex.targetSets-5}</div>}
                </div>
                <div className="w-px h-3 bg-zinc-800 mx-1" />
                <span className="text-[10px] text-zinc-300 font-black tracking-wider uppercase">
                  {ex.targetSets} set{ex.targetSets > 1 ? 's' : ''}
                </span>
             </div>

             <div className="flex items-baseline gap-1">
                <span className="text-lg font-black text-white italic tracking-tighter">{ex.targetReps}</span>
                <span className="text-[8px] text-zinc-600 font-black uppercase tracking-widest">reps</span>
             </div>

             {ex.targetWeight != null && (
               <div className="flex items-baseline gap-1">
                  <span className="text-lg font-black text-[#F1C40F] italic tracking-tighter">{ex.targetWeight}</span>
                  <span className="text-[8px] text-zinc-600 font-black uppercase tracking-widest">kg</span>
               </div>
             )}

             {ex.restSeconds != null && (
               <div className="flex items-center gap-1 text-zinc-600">
                  <span className="text-[10px] font-bold">⏱️ {ex.restSeconds}s</span>
               </div>
             )}
          </div>

          {/* Coaching note */}
          {(ex.progressionNote || editingNote) && (
            <div className="mt-4 pt-3 border-t border-white/[0.03]">
              {editingNote ? (
                <div className="flex gap-2">
                  <input
                    autoFocus
                    value={noteValue}
                    onChange={(e) => setNoteValue(e.target.value)}
                    maxLength={300}
                    placeholder="Coach instructions..."
                    className="flex-1 bg-zinc-950/60 border border-white/10 rounded-xl px-3 py-2 text-xs text-white placeholder-zinc-700 outline-none focus:border-blue-500/40 transition-all font-medium"
                  />
                  <button
                    onClick={() => saveNote.mutate(noteValue)}
                    className="flex items-center justify-center w-10 h-10 bg-blue-500/10 text-blue-400 hover:bg-blue-500/20 rounded-xl border border-blue-500/20 transition-all active:scale-90"
                  >
                    <Check size={16} strokeWidth={3} />
                  </button>
                  <button
                    onClick={() => setEditingNote(false)}
                    className="flex items-center justify-center w-10 h-10 bg-zinc-800 text-zinc-400 hover:bg-zinc-700 rounded-xl border border-white/5 transition-all"
                  >
                    <X size={16} strokeWidth={3} />
                  </button>
                </div>
              ) : (
                <p
                  className="text-[10px] text-blue-400/70 font-medium cursor-pointer hover:text-blue-300 transition-colors leading-relaxed bg-blue-500/5 px-3 py-2 rounded-xl border border-blue-500/10"
                  onClick={() => { setNoteValue(ex.progressionNote ?? ""); setEditingNote(true); }}
                >
                  <span className="font-black mr-2 opacity-50 uppercase tracking-[0.2em]">Note:</span>
                  {ex.progressionNote}
                </p>
              )}
            </div>
          )}
        </div>

        {/* Action Menu (Diet Style) */}
        <div className="flex items-center gap-1.5 opacity-0 group-hover:opacity-100 transition-all duration-300">
          {!ex.progressionNote && !editingNote && (
            <button
              onClick={() => { setNoteValue(""); setEditingNote(true); }}
              className="p-1.5 text-zinc-600 hover:text-blue-400 transition-colors bg-zinc-900/40 rounded-lg hover:bg-blue-400/10"
              title="Add instruction"
            >
              <Pencil size={12} />
            </button>
          )}
          {onSaveToLibrary && (
            <button
              onClick={() => onSaveToLibrary(ex)}
              className="p-1.5 text-zinc-600 hover:text-violet-400 transition-colors bg-zinc-900/40 rounded-lg hover:bg-violet-400/10"
              title="Add to Vault"
            >
              <Star size={12} />
            </button>
          )}
          <button
            onClick={() => { if(confirm("Delete exercise?")) deleteEx.mutate(); }}
            disabled={deleteEx.isPending}
            className="p-1.5 text-zinc-600 hover:text-rose-400 transition-colors bg-zinc-900/40 rounded-lg hover:bg-rose-400/10"
          >
            {deleteEx.isPending ? <Loader2 size={16} className="animate-spin" /> : <Trash2 size={16} />}
          </button>
        </div>
      </div>
    </div>
  );
}
