"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Search, X, Dumbbell, Plus } from "lucide-react";
import { trainerApi, type ExerciseLibraryItem } from "@/lib/api";

interface ExerciseSearchProps {
  token: string;
  onSelect: (name: string) => void;
  className?: string;
}

export function ExerciseSearch({ token, onSelect, className }: ExerciseSearchProps) {
  const [q, setQ] = useState("");

  const { data: results, isLoading } = useQuery({
    queryKey: ["exercise-search", q],
    queryFn: () => q.length >= 2 ? trainerApi.searchExercises(q, token) : Promise.resolve([]),
    enabled: q.length >= 2,
  });

  return (
    <div className={`relative ${className}`}>
      <div className="flex items-center gap-3 bg-zinc-950/50 border border-white/5 rounded-2xl px-4 py-3.5 focus-within:border-[#F1C40F]/40 transition-all shadow-inner group">
        <Search size={16} className="text-zinc-600 group-focus-within:text-[#F1C40F] transition-colors flex-shrink-0" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Summon an exercise from the library…"
          className="flex-1 bg-transparent text-sm text-white placeholder-zinc-700 outline-none font-medium"
        />
        {q && (
          <button onClick={() => setQ("")} className="text-zinc-700 hover:text-white transition-colors p-1 hover:bg-white/5 rounded-full">
            <X size={14} />
          </button>
        )}
      </div>
      
      {q.length >= 2 && (
        <div className="absolute z-[110] top-full left-0 right-0 mt-3 bg-[#0e1420]/95 border border-white/10 rounded-3xl max-h-[400px] overflow-y-auto shadow-[0_30px_70px_rgba(0,0,0,0.7)] backdrop-blur-3xl animate-in fade-in slide-in-from-top-4 duration-300">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center p-12 space-y-4">
               <div className="flex gap-2">
                 <div className="w-2.5 h-2.5 bg-[#F1C40F] rounded-full animate-bounce [animation-duration:0.8s]" />
                 <div className="w-2.5 h-2.5 bg-[#F1C40F] rounded-full animate-bounce [animation-duration:0.8s] [animation-delay:0.15s]" />
                 <div className="w-2.5 h-2.5 bg-[#F1C40F] rounded-full animate-bounce [animation-duration:0.8s] [animation-delay:0.3s]" />
               </div>
               <p className="text-[10px] text-zinc-500 font-black uppercase tracking-[0.2em]">Consulting the Archive</p>
            </div>
          ) : !results?.length ? (
            <div className="p-12 text-center">
              <div className="w-16 h-16 bg-zinc-900/50 rounded-full flex items-center justify-center mx-auto mb-4 border border-white/5">
                 <Search size={24} className="text-zinc-700" />
              </div>
              <p className="text-zinc-400 text-sm font-bold">No results for &ldquo;{q}&rdquo;</p>
              <p className="text-zinc-600 text-xs mt-2 mb-6">Create a unique custom movement instead?</p>
              <button 
                onClick={() => { onSelect(q); setQ(""); }}
                className="px-6 py-3 bg-zinc-800 hover:bg-zinc-700 text-white text-[10px] font-black uppercase tracking-wider rounded-2xl transition-all active:scale-95 shadow-xl"
              >
                + Add Custom: {q}
              </button>
            </div>
          ) : (
            <div className="p-2 space-y-1">
              <p className="px-4 py-2 text-[9px] text-zinc-600 font-black uppercase tracking-widest">Global Library matches</p>
              {results.map((ex: ExerciseLibraryItem, idx: number) => (
                <button
                  key={ex.id}
                  onClick={() => { onSelect(ex.name); setQ(""); }}
                  className="w-full text-left px-5 py-4 hover:bg-white/[0.03] rounded-2xl transition-all group border border-transparent hover:border-white/5"
                  style={{ animationDelay: `${idx * 40}ms` }}
                >
                  <div className="flex items-center justify-between gap-4">
                    <div className="min-w-0">
                      <p className="text-sm text-zinc-200 font-bold group-hover:text-[#F1C40F] transition-colors">{ex.name}</p>
                      <div className="flex items-center gap-2 mt-2">
                        <span className="flex items-center gap-1 text-[10px] text-zinc-500 font-black uppercase tracking-wider bg-white/5 px-2 py-0.5 rounded-full">
                          <Dumbbell size={10} className="text-zinc-600" />
                          {ex.primaryMuscle}
                        </span>
                        {ex.secondaryMuscles && ex.secondaryMuscles.length > 0 && (
                          <span className="text-[9px] text-zinc-600 font-medium">
                            + {ex.secondaryMuscles.slice(0, 2).join(', ')}
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-2 flex-shrink-0">
                      <span className={`text-[9px] px-2 py-0.5 rounded-full font-black uppercase tracking-tighter shadow-sm ${
                        ex.difficulty === 'BEGINNER' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' :
                        ex.difficulty === 'INTERMEDIATE' ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20' :
                        'bg-rose-500/10 text-rose-400 border border-rose-500/20'
                      }`}>
                        {ex.difficulty}
                      </span>
                      <div className="w-8 h-8 rounded-full bg-white/5 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity border border-white/5">
                        <Plus size={16} className="text-[#F1C40F]" />
                      </div>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
