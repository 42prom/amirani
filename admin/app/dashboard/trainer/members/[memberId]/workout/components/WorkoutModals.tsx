"use client";

import React, { useState } from "react";
import { 
  type TrainerDraftTemplate, 
} from "@/lib/api";
import { X, Pencil, Trash2, Zap } from "lucide-react";

interface SaveToLibraryModalProps {
  title: string;
  isOpen: boolean;
  onClose: () => void;
  onSave: (name: string) => void;
  inputValue: string;
  onInputChange: (val: string) => void;
  placeholder?: string;
  infoText?: string; // Optional — e.g. "Save as reusable template to Vault"
  isFull?: boolean;
  limitText?: string;
}

export function SaveToLibraryModal({
  title, isOpen, onClose, onSave, inputValue, onInputChange, placeholder, infoText, isFull, limitText
}: SaveToLibraryModalProps) {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
      <div className="bg-[#121721] border border-zinc-700 shadow-2xl rounded-2xl p-6 w-full max-w-sm mx-4 space-y-4 relative overflow-hidden">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h3 className="font-bold text-white text-base">{title}</h3>
          </div>
          <button onClick={onClose} className="text-zinc-500 hover:text-white transition-colors"><X size={18} /></button>
        </div>

        <div className="space-y-1.5">
          <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest flex items-center justify-between">
             {infoText || "Template Name"}
             <span className="text-violet-400 ml-1.5">{limitText}</span>
          </p>
          <input
            autoFocus value={inputValue}
            onChange={(e) => onInputChange(e.target.value)}
            className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-white outline-none focus:border-violet-500 transition-all placeholder:text-zinc-700"
            placeholder={placeholder || "e.g. Morning Burn"}
          />
        </div>

        <div className="flex flex-col gap-2 pt-1">
          <button
            onClick={() => onSave(inputValue)}
            disabled={!inputValue.trim() || isFull}
            className="w-full py-2.5 bg-violet-600 text-white text-sm font-bold rounded-lg hover:bg-violet-500 transition-all disabled:opacity-50 active:scale-95 shadow-lg shadow-violet-600/10"
          >
            {isFull ? `Vault Full ${limitText}` : "Save to Library"}
          </button>
          <button onClick={onClose} className="w-full py-2 bg-zinc-800 text-zinc-400 text-sm font-bold rounded-lg hover:bg-zinc-700 transition-all">
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
}

interface TemplateLibraryModalProps {
  isOpen: boolean;
  onClose: () => void;
  allTemplates: TrainerDraftTemplate[];
  renamingTemplateId: string | null;
  renameValue: string;
  setRenamingTemplateId: (id: string | null) => void;
  setRenameValue: (val: string) => void;
  onRename: (id: string, name: string) => void;
  onDelete: (id: string) => void;
  onApply: (tpl: TrainerDraftTemplate) => void;
  isDeleting: boolean;
}

export function TemplateLibraryModal({
  isOpen, onClose, allTemplates, renamingTemplateId, renameValue, setRenamingTemplateId, setRenameValue, onRename, onDelete, onApply, isDeleting
}: TemplateLibraryModalProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 animate-in fade-in duration-500">
      <div className="bg-[#121721] border border-zinc-700 shadow-2xl rounded-2xl w-full max-w-lg mx-auto overflow-hidden flex flex-col max-h-[85vh]">
        <div className="flex items-center justify-between p-6 border-b border-zinc-800">
          <div className="flex items-center gap-4">
             <div>
                <h3 className="font-bold text-white text-base tracking-tight uppercase">Trainer Vault</h3>
                <p className="text-[10px] text-zinc-500 font-bold uppercase tracking-widest mt-0.5 opacity-60">Reusable components · Workspace system</p>
             </div>
          </div>
          <button onClick={onClose} className="text-zinc-500 hover:text-white transition-colors"><X size={20} /></button>
        </div>

        <div className="overflow-y-auto flex-1 divide-y divide-zinc-800/60 scrollbar-hide">
          {allTemplates.length === 0 && (
            <div className="p-16 text-center text-zinc-500">
              <p className="text-sm font-bold uppercase tracking-widest opacity-40">Your Vault is Empty</p>
              <p className="text-[10px] mt-2 uppercase tracking-[0.2em]">Save your favorite routines or exercises first</p>
            </div>
          )}

          {(["workout_exercise", "workout_day", "workout_week"] as const).map((type) => {
            const group = allTemplates.filter((t) => t.type === type);
            if (group.length === 0) return null;
            const labels = { workout_exercise: "SINGLE EXERCISES", workout_day: "DAILY ROUTINES", workout_week: "WEEKLY CYCLES" };
            const limits = { workout_exercise: 10, workout_day: 5, workout_week: 2 };

            return (
              <div key={type} className="animate-in fade-in duration-500">
                <div className="px-6 py-2 bg-zinc-900/40 border-y border-zinc-800/40 flex items-center justify-between">
                  <p className="text-[9px] text-violet-400 font-black uppercase tracking-[0.3em]">
                    {labels[type]}
                  </p>
                  <span className="text-[9px] text-zinc-600 font-black tracking-widest">{group.length} / {limits[type]}</span>
                </div>
                {group.map((tpl) => (
                  <div key={tpl.id} className="flex items-center gap-4 px-6 py-4 hover:bg-white/[0.01] group transition-all duration-300">
                    <div className="flex-1 min-w-0">
                      {renamingTemplateId === tpl.id ? (
                        <div className="flex gap-2">
                           <input
                            autoFocus value={renameValue}
                            onChange={(e) => setRenameValue(e.target.value)}
                            onKeyDown={(e) => {
                              if (e.key === "Enter" && renameValue.trim()) onRename(tpl.id, renameValue.trim());
                              if (e.key === "Escape") setRenamingTemplateId(null);
                            }}
                            className="w-full bg-zinc-900 border border-violet-600/50 rounded-lg px-3 py-1.5 text-sm text-white outline-none"
                          />
                        </div>
                      ) : (
                        <div className="flex items-center gap-3">
                           <div>
                              <p className="text-sm text-zinc-200 font-bold group-hover:text-white transition-colors">{tpl.name}</p>
                              <p className="text-[9px] text-zinc-600 uppercase font-black tracking-[0.1em] mt-0.5 opacity-60">
                                 {type === "workout_week" ? "Performance Cycle" : type === "workout_day" ? "Complete Session" : "Exercise Block"}
                              </p>
                           </div>
                        </div>
                      )}
                    </div>
                    
                    <div className="flex items-center gap-1.5 flex-shrink-0">
                      {renamingTemplateId === tpl.id ? (
                        <>
                          <button onClick={() => { if (renameValue.trim()) onRename(tpl.id, renameValue.trim()); }} className="h-8 px-3 text-[9px] font-black uppercase tracking-widest bg-violet-600 text-white rounded-lg hover:bg-violet-500 transition-colors">Save</button>
                          <button onClick={() => setRenamingTemplateId(null)} className="h-8 px-3 text-[9px] font-black uppercase tracking-widest bg-zinc-800 text-zinc-400 rounded-lg hover:text-white transition-colors">Cancel</button>
                        </>
                      ) : (
                        <>
                          <button
                            onClick={() => onApply(tpl)}
                            className="h-8 px-4 bg-[#F1C40F] text-black text-[9px] font-black uppercase tracking-widest rounded-lg hover:bg-[#F4D03F] transition-all transform active:scale-95 shadow-lg shadow-[#F1C40F]/10 mr-1"
                          >
                            Apply
                          </button>
                          <button onClick={() => { setRenamingTemplateId(tpl.id); setRenameValue(tpl.name); }} className="p-2 text-zinc-600 hover:text-violet-400 transition-colors hover:bg-violet-400/10 rounded-lg"><Pencil size={12} /></button>
                          <button onClick={() => onDelete(tpl.id)} disabled={isDeleting} className="p-2 text-zinc-600 hover:text-rose-400 transition-colors hover:bg-rose-400/10 rounded-lg"><Trash2 size={12} /></button>
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
  );
}

interface AiGenModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function AiGenModal({ isOpen, onClose }: AiGenModalProps) {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/95 backdrop-blur-xl animate-in fade-in duration-700" onClick={onClose} />
      <div className="relative bg-[#0e1420] border border-[#F1C40F]/20 rounded-[48px] p-16 max-w-2xl text-center shadow-[0_0_150px_rgba(241,196,15,0.2)] animate-in zoom-in-95 duration-500 overflow-hidden group">
         <div className="absolute inset-0 bg-gradient-to-br from-[#F1C40F]/5 via-transparent to-transparent opacity-50" />
         <div className="w-32 h-32 bg-gradient-to-tr from-[#F1C40F] via-orange-500 to-rose-500 rounded-[40px] flex items-center justify-center mx-auto mb-10 shadow-[0_20px_60px_rgba(241,196,15,0.4)] relative overflow-hidden ring-4 ring-white/10 group">
            <Zap size={56} className="text-black relative z-10 drop-shadow-lg" fill="black" />
            <div className="absolute inset-0 bg-white/20 translate-x-full group-hover:translate-x-0 transition-transform duration-1000 ease-in-out" />
         </div>
         <h2 className="text-4xl font-black text-white italic tracking-tighter mb-6 uppercase">AI Session Evolution</h2>
         <p className="text-zinc-400 text-xl mb-12 leading-relaxed font-semibold italic opacity-80 max-w-md mx-auto">The Deep-Space Workout Oracle is currently being harmonized for flagship generation.</p>
         <button 
            onClick={onClose}
            className="px-16 py-6 bg-white text-black text-sm font-black uppercase tracking-widest rounded-full hover:bg-zinc-100 transition-all active:scale-95 shadow-2xl relative z-10"
          >
            Close Portal
         </button>
      </div>
    </div>
  );
}

interface CopyTargetModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCopy: (targetWeek: number, targetDay: number) => void;
  onCopyAll: () => void;
  numWeeks: number;
}

export function CopyTargetModal({ isOpen, onClose, onCopy, onCopyAll, numWeeks }: CopyTargetModalProps) {
  const [selectedWeek, setSelectedWeek] = useState(1);
  const [selectedDay, setSelectedDay] = useState(0);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
      <div className="bg-[#121721] border border-zinc-700 shadow-2xl rounded-2xl p-6 w-full max-w-sm mx-4 space-y-5">
        <div className="flex items-center justify-between">
          <h3 className="font-bold text-white text-base uppercase tracking-tight">Duplicate Session</h3>
          <button onClick={onClose} className="text-zinc-500 hover:text-white transition-colors"><X size={18} /></button>
        </div>

        <div className="space-y-4">
           <div className="space-y-2">
              <label className="text-[10px] text-zinc-500 font-black uppercase tracking-widest">Target Week</label>
              <div className="flex gap-2">
                 {Array.from({ length: numWeeks }).map((_, i) => (
                    <button 
                      key={i} onClick={() => setSelectedWeek(i + 1)} 
                      className={`flex-1 py-1.5 text-xs font-bold rounded-lg border transition-all ${selectedWeek === i + 1 ? "bg-[#F1C40F]/15 border-[#F1C40F]/50 text-[#F1C40F]" : "bg-zinc-900 border-zinc-800 text-zinc-500"}`}
                    >
                      W{i + 1}
                    </button>
                 ))}
              </div>
           </div>

           <div className="space-y-2">
              <label className="text-[10px] text-zinc-500 font-black uppercase tracking-widest">Target Day</label>
              <div className="grid grid-cols-4 gap-2">
                 {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((day, i) => (
                    <button 
                      key={i} onClick={() => setSelectedDay(i)} 
                      className={`py-1.5 text-[10px] font-bold rounded-lg border transition-all ${selectedDay === i ? "bg-[#F1C40F]/15 border-[#F1C40F]/50 text-[#F1C40F]" : "bg-zinc-900 border-zinc-800 text-zinc-500"}`}
                    >
                      {day}
                    </button>
                 ))}
              </div>
           </div>
        </div>

        <div className="flex flex-col gap-2 pt-2">
           <button onClick={() => onCopy(selectedWeek, selectedDay)} className="w-full py-2.5 bg-[#F1C40F] text-black text-xs font-black uppercase tracking-widest rounded-lg hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10">
              Apply to Target
           </button>
           <button onClick={onCopyAll} className="w-full py-2 text-white/80 text-[10px] font-black uppercase tracking-widest border border-white/10 rounded-lg hover:bg-white/5 transition-all">
              Copy to All Weeks
           </button>
           <button onClick={onClose} className="w-full py-2 text-zinc-500 text-[10px] font-black uppercase tracking-widest hover:text-white transition-all">
              Cancel
           </button>
        </div>
      </div>
    </div>
  );
}
