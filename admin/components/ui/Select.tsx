"use client";

import { useState, useRef, useEffect } from "react";
import { ChevronDown } from "lucide-react";

interface Option {
  value: string;
  label: string;
}

interface SelectProps {
  value: string;
  onChange: (value: string) => void;
  options: Option[];
  placeholder?: string;
  label?: string;
  required?: boolean;
  className?: string;
}

export function CustomSelect({
  value,
  onChange,
  options,
  placeholder = "Select Option",
  label,
  required,
  className = "",
}: SelectProps) {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const selectedOption = options.find((opt) => opt.value === value);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <div className={`relative ${className}`} ref={containerRef}>
      {label && (
        <label className="amirani-label !mb-3">
          {label} {required && <span className="text-[#F1C40F]">*</span>}
        </label>
      )}
      
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className={`amirani-input transition-all flex items-center justify-between group
          ${isOpen ? "!border-[#F1C40F]/50 ring-1 ring-[#F1C40F]/20" : "hover:!border-white/20"}`}
      >
        <span className={`text-sm font-semibold transition-colors truncate ${selectedOption ? "text-white" : "text-zinc-600"}`}>
          {selectedOption ? selectedOption.label : placeholder}
        </span>
        <ChevronDown 
          size={16} 
          className={`text-zinc-500 group-hover:text-[#F1C40F] transition-all duration-300 ${isOpen ? "rotate-180 text-[#F1C40F]" : ""}`} 
        />
      </button>
 
      {isOpen && (
        <div className="absolute top-[calc(100%+6px)] left-0 w-full bg-[#121721]/95 backdrop-blur-3xl border border-white/10 rounded-2xl overflow-hidden z-[60] shadow-[0_20px_50px_rgba(0,0,0,0.5)] animate-in fade-in slide-in-from-top-2 duration-300">
          <div className="max-h-64 overflow-y-auto amirani-scrollbar py-2">
            {options.map((option) => (
              <button
                key={option.value}
                type="button"
                onClick={() => {
                  onChange(option.value);
                  setIsOpen(false);
                }}
                className={`w-full text-left px-5 py-3 text-xs font-bold transition-all flex items-center justify-between border-l-2
                  ${option.value === value 
                    ? "bg-[#F1C40F]/5 text-[#F1C40F] border-[#F1C40F]" 
                    : "text-zinc-400 border-transparent hover:bg-white/5 hover:text-white"}`}
              >
                <span className="truncate pr-4 uppercase tracking-wider">{option.label}</span>
                {option.value === value && (
                  <div className="w-1.5 h-1.5 rounded-full bg-[#F1C40F] shadow-[0_0_8px_rgba(241,196,15,0.6)] flex-shrink-0" />
                )}
              </button>
            ))}
            {options.length === 0 && (
              <div className="px-5 py-4 text-center">
                <p className="text-[10px] font-black text-zinc-600 uppercase tracking-widest italic">No Data Available</p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
