"use client";

import { Dumbbell } from "lucide-react";

interface FlyingExerciseAnimationProps {
  isFlying: boolean;
  onComplete: () => void;
}

export function FlyingExerciseAnimation({ isFlying, onComplete }: FlyingExerciseAnimationProps) {
  if (!isFlying) return null;
  return (
    <div 
      className="fixed inset-0 z-[200] pointer-events-none flex items-center justify-center overflow-hidden"
      onAnimationEnd={onComplete}
    >
      <div className="relative">
        <div className="absolute inset-0 bg-[#F1C40F]/20 blur-[100px] animate-out fade-out zoom-out duration-1000" />
        <div className="relative animate-in slide-in-from-bottom-32 zoom-in-50 fade-in duration-500 ease-out fill-mode-forwards">
          <div className="bg-[#F1C40F] p-8 rounded-[40px] shadow-[0_0_80px_rgba(241,196,15,0.5)] border-4 border-white/20">
            <Dumbbell size={48} className="text-black animate-bounce" />
          </div>
          <div className="absolute -top-12 left-1/2 -translate-x-1/2 whitespace-nowrap">
            <span className="text-2xl font-black text-white italic tracking-tighter drop-shadow-2xl">
              EXERCISE SUMMONED! ✨
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
