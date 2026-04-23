"use client";

import { useState, useRef, useEffect } from "react";
import { Clock } from "lucide-react";

interface ThemedTimePickerProps {
  label?: string;
  value?: string; // HH:mm (24h format)
  onChange: (time: string) => void;
  required?: boolean;
  className?: string;
}

export function ThemedTimePicker({
  label,
  value,
  onChange,
  required,
  className = "",
}: ThemedTimePickerProps) {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const [openUp, setOpenUp] = useState(false);

  // Parse current value
  const [hour, setHour] = useState(() => {
    if (!value) return 12;
    const h = parseInt(value.split(":")[0]);
    return h === 0 || h === 12 ? 12 : h % 12;
  });
  const [minute, setMinute] = useState(() => {
    if (!value) return 0;
    return parseInt(value.split(":")[1]);
  });
  const [isPM, setIsPM] = useState(() => {
    if (!value) return false;
    return parseInt(value.split(":")[0]) >= 12;
  });

  const toggleOpen = () => {
    if (!isOpen && containerRef.current) {
      const rect = containerRef.current.getBoundingClientRect();
      const spaceBelow = window.innerHeight - rect.bottom;
      const spaceAbove = rect.top;
      setOpenUp(spaceBelow < 300 && spaceAbove > spaceBelow);
    }
    setIsOpen(!isOpen);
  };

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const updateTime = (newHour: number, newMin: number, newIsPM: boolean) => {
    setHour(newHour);
    setMinute(newMin);
    setIsPM(newIsPM);
    
    let h24 = newHour;
    if (newIsPM && newHour < 12) h24 += 12;
    if (!newIsPM && newHour === 12) h24 = 0;
    
    const timeStr = `${h24.toString().padStart(2, "0")}:${newMin.toString().padStart(2, "0")}`;
    onChange(timeStr);
  };

  const hours = Array.from({ length: 12 }, (_, i) => i + 1);
  const minutes = Array.from({ length: 60 }, (_, i) => i);

  const displayTime = value ? (() => {
    const [hStr, mStr] = value.split(":");
    let h = parseInt(hStr);
    const m = parseInt(mStr);
    const ampm = h >= 12 ? "PM" : "AM";
    h = h % 12 || 12;
    return `${h}:${m.toString().padStart(2, "0")} ${ampm}`;
  })() : "SELECT TIME";

  return (
    <div className={`relative ${className}`} ref={containerRef}>
      {label && (
        <label className="amirani-label !mb-3">
          {label} {required && <span className="text-[#F1C40F]">*</span>}
        </label>
      )}

      <button
        type="button"
        onClick={toggleOpen}
        className={`amirani-input transition-all flex items-center justify-between group
          ${isOpen ? "!border-[#F1C40F]/50 ring-1 ring-[#F1C40F]/20" : "hover:!border-white/20"}`}
      >
        <span className={`text-sm font-semibold transition-colors tracking-tight ${value ? "text-white" : "text-zinc-600"}`}>
          {displayTime}
        </span>
        <Clock 
          size={16} 
          className={`text-zinc-500 transition-colors ${isOpen ? "text-[#F1C40F]" : "group-hover:text-zinc-300"}`} 
        />
      </button>

      {isOpen && (
        <div className={`absolute left-0 w-64 bg-[#121721]/95 border border-white/10 rounded-2xl overflow-hidden z-[60] shadow-[0_20px_50px_rgba(0,0,0,0.8)] animate-in fade-in zoom-in-95 duration-300 backdrop-blur-3xl p-4
          ${openUp ? "bottom-full mb-3 slide-in-from-bottom-2" : "top-full mt-2 slide-in-from-top-2"}`}>
          
          <div className="flex gap-4">
            {/* Hours */}
            <div className="flex-1">
              <p className="text-[10px] font-black text-zinc-600 uppercase tracking-widest mb-3 text-center">Hour</p>
              <div className="h-48 overflow-y-auto amirani-scrollbar pr-1">
                {hours.map((h) => (
                  <button
                    key={h}
                    type="button"
                    onClick={() => updateTime(h, minute, isPM)}
                    className={`w-full py-2.5 rounded-xl text-xs font-black transition-all mb-1
                      ${hour === h 
                        ? "bg-[#F1C40F] text-black shadow-[0_0_15px_rgba(241,196,15,0.2)]" 
                        : "text-zinc-500 hover:bg-white/5 hover:text-white"}`}
                  >
                    {h}
                  </button>
                ))}
              </div>
            </div>

            {/* Minutes */}
            <div className="flex-1">
              <p className="text-[10px] font-black text-zinc-600 uppercase tracking-widest mb-3 text-center">Min</p>
              <div className="h-48 overflow-y-auto amirani-scrollbar pr-1">
                {minutes.map((m) => (
                  <button
                    key={m}
                    type="button"
                    onClick={() => updateTime(hour, m, isPM)}
                    className={`w-full py-2.5 rounded-xl text-xs font-black transition-all mb-1
                      ${minute === m 
                        ? "bg-[#F1C40F] text-black shadow-[0_0_15px_rgba(241,196,15,0.2)]" 
                        : "text-zinc-500 hover:bg-white/5 hover:text-white"}`}
                  >
                    {m.toString().padStart(2, "0")}
                  </button>
                ))}
              </div>
            </div>

            {/* AM/PM */}
            <div className="flex flex-col gap-2 pt-6">
              <button
                type="button"
                onClick={() => updateTime(hour, minute, false)}
                className={`px-3 py-4 rounded-xl text-[10px] font-black transition-all
                  ${!isPM 
                    ? "bg-[#F1C40F] text-black shadow-[0_0_15px_rgba(241,196,15,0.2)]" 
                    : "bg-white/[0.03] text-zinc-500 hover:text-white"}`}
              >
                AM
              </button>
              <button
                type="button"
                onClick={() => updateTime(hour, minute, true)}
                className={`px-3 py-4 rounded-xl text-[10px] font-black transition-all
                  ${isPM 
                    ? "bg-[#F1C40F] text-black shadow-[0_0_15px_rgba(241,196,15,0.2)]" 
                    : "bg-white/[0.03] text-zinc-500 hover:text-white"}`}
              >
                PM
              </button>
            </div>
          </div>

          <div className="mt-4 pt-3 border-t border-white/5 flex justify-center">
            <button
              type="button"
              onClick={() => setIsOpen(false)}
              className="w-full py-2 text-[10px] font-black uppercase text-[#F1C40F]/70 hover:text-[#F1C40F] hover:bg-[#F1C40F]/5 rounded-xl transition-all tracking-widest"
            >
              Confirm
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
