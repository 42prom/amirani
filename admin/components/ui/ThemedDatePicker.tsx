"use client";

import { useState, useRef, useEffect } from "react";
import { Calendar, ChevronLeft, ChevronRight, ChevronDown } from "lucide-react";

interface ThemedDatePickerProps {
  label?: string;
  value: string; // YYYY-MM-DD
  onChange: (date: string) => void;
  required?: boolean;
  className?: string;
}

export function ThemedDatePicker({
  label,
  value,
  onChange,
  required,
  className = "",
}: ThemedDatePickerProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [isMonthSelectorOpen, setIsMonthSelectorOpen] = useState(false);
  const [isYearSelectorOpen, setIsYearSelectorOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const yearScrollRef = useRef<HTMLDivElement>(null);
  const [viewDate, setViewDate] = useState(() => new Date(value || Date.now()));

  const [openUp, setOpenUp] = useState(false);

  const toggleOpen = () => {
    if (!isOpen && containerRef.current) {
      const rect = containerRef.current.getBoundingClientRect();
      const spaceBelow = window.innerHeight - rect.bottom;
      const spaceAbove = rect.top;
      
      // If there's less than 400px below and more space above, open upwards
      setOpenUp(spaceBelow < 400 && spaceAbove > spaceBelow);
    }
    setIsOpen(!isOpen);
  };

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
        setIsMonthSelectorOpen(false);
        setIsYearSelectorOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  // Scroll to current year when year selector opens
  useEffect(() => {
    if (isYearSelectorOpen && yearScrollRef.current) {
      const currentYear = viewDate.getFullYear();
      const yearElement = yearScrollRef.current.querySelector(`[data-year="${currentYear}"]`);
      if (yearElement) {
        yearElement.scrollIntoView({ block: "center" });
      }
    }
  }, [isYearSelectorOpen, viewDate]);

  const formatDate = (date: Date) => {
    const d = new Date(date);
    let month = "" + (d.getMonth() + 1);
    let day = "" + d.getDate();
    const year = d.getFullYear();

    if (month.length < 2) month = "0" + month;
    if (day.length < 2) day = "0" + day;

    return [year, month, day].join("-");
  };

  const getDaysInMonth = (year: number, month: number) => {
    return new Date(year, month + 1, 0).getDate();
  };

  const getFirstDayOfMonth = (year: number, month: number) => {
    return new Date(year, month, 1).getDay();
  };

  const months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  const days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];

  // Generate years from 1920 to current year + 10
  const currentYear = new Date().getFullYear();
  const years = Array.from({ length: currentYear + 11 - 1920 }, (_, i) => 1920 + i).reverse();

  const renderCalendar = () => {
    const year = viewDate.getFullYear();
    const month = viewDate.getMonth();
    const daysInMonth = getDaysInMonth(year, month);
    const firstDay = getFirstDayOfMonth(year, month);
    const calendarDays = [];

    // Empty spots before the first day
    for (let i = 0; i < firstDay; i++) {
      calendarDays.push(<div key={`empty-${i}`} className="h-9 w-9" />);
    }

    // Days of the month
    for (let d = 1; d <= daysInMonth; d++) {
      const dateStr = formatDate(new Date(year, month, d));
      const isSelected = dateStr === value;
      const isToday = formatDate(new Date()) === dateStr;

      calendarDays.push(
        <button
          key={d}
          type="button"
          onClick={() => {
            onChange(dateStr);
            setIsOpen(false);
          }}
          className={`h-9 w-9 rounded-xl text-xs font-bold transition-all flex items-center justify-center
            ${isSelected 
              ? "bg-[#F1C40F] text-black shadow-[0_0_15px_rgba(241,196,15,0.3)]" 
              : isToday 
              ? "border border-[#F1C40F]/30 text-[#F1C40F]" 
              : "text-white/60 hover:bg-white/5 hover:text-white"}`}
        >
          {d}
        </button>
      );
    }

    return calendarDays;
  };

  const changeMonth = (offset: number) => {
    const newDate = new Date(viewDate);
    newDate.setMonth(newDate.getMonth() + offset);
    setViewDate(newDate);
  };

  const selectMonth = (monthIndex: number) => {
    const newDate = new Date(viewDate);
    newDate.setMonth(monthIndex);
    setViewDate(newDate);
    setIsMonthSelectorOpen(false);
  };

  const selectYear = (year: number) => {
    const newDate = new Date(viewDate);
    newDate.setFullYear(year);
    setViewDate(newDate);
    setIsYearSelectorOpen(false);
  };

  const displayValue = value ? new Date(value).toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric"
  }) : "SELECT DATE";

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
          {displayValue}
        </span>
        <Calendar 
          size={16} 
          className={`text-zinc-500 transition-colors ${isOpen ? "text-[#F1C40F]" : "group-hover:text-zinc-300"}`} 
        />
      </button>

      {isOpen && (
        <div className={`absolute left-0 w-80 bg-[#121721] border border-white/10 rounded-2xl overflow-hidden z-[60] shadow-[0_20px_50px_rgba(0,0,0,0.8)] animate-in fade-in duration-300 backdrop-blur-xl p-4
          ${openUp ? "bottom-full mb-3 slide-in-from-bottom-2" : "top-full mt-2 slide-in-from-top-2"}`}>
          <div className="flex items-center justify-between mb-4 px-1">
            <div className="flex items-center gap-1">
              <button
                type="button"
                onClick={() => {
                  setIsMonthSelectorOpen(!isMonthSelectorOpen);
                  setIsYearSelectorOpen(false);
                }}
                className={`text-[11px] font-black uppercase tracking-widest px-2 py-1 rounded-lg transition-all flex items-center gap-1
                  ${isMonthSelectorOpen ? "bg-[#F1C40F] text-black" : "text-white hover:bg-white/5"}`}
              >
                {months[viewDate.getMonth()]}
                <ChevronDown size={12} className={isMonthSelectorOpen ? "rotate-180" : ""} />
              </button>
              <button
                type="button"
                onClick={() => {
                  setIsYearSelectorOpen(!isYearSelectorOpen);
                  setIsMonthSelectorOpen(false);
                }}
                className={`text-[11px] font-black uppercase tracking-widest px-2 py-1 rounded-lg transition-all flex items-center gap-1
                  ${isYearSelectorOpen ? "bg-[#F1C40F] text-black" : "text-white hover:bg-white/5"}`}
              >
                {viewDate.getFullYear()}
                <ChevronDown size={12} className={isYearSelectorOpen ? "rotate-180" : ""} />
              </button>
            </div>
            
            <div className="flex gap-1">
              <button
                type="button"
                onClick={() => changeMonth(-1)}
                className="p-2 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-colors border border-white/5 shadow-inner"
              >
                <ChevronLeft size={16} />
              </button>
              <button
                type="button"
                onClick={() => changeMonth(1)}
                className="p-2 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-colors border border-white/5 shadow-inner"
              >
                <ChevronRight size={16} />
              </button>
            </div>
          </div>

          <div className="relative min-h-[240px]">
            {isMonthSelectorOpen && (
              <div className="absolute inset-0 bg-[#121721] z-10 grid grid-cols-3 gap-2 animate-in fade-in zoom-in-95 duration-200">
                {months.map((m, idx) => (
                  <button
                    key={m}
                    type="button"
                    onClick={() => selectMonth(idx)}
                    className={`px-2 py-4 rounded-xl text-[10px] font-black uppercase tracking-tight transition-all
                      ${viewDate.getMonth() === idx 
                        ? "bg-[#F1C40F] text-black" 
                        : "text-zinc-500 hover:bg-white/5 hover:text-white"}`}
                  >
                    {m.substring(0, 3)}
                  </button>
                ))}
              </div>
            )}

            {isYearSelectorOpen && (
              <div 
                ref={yearScrollRef}
                className="absolute inset-0 bg-[#121721] z-10 grid grid-cols-3 gap-2 overflow-y-auto custom-scrollbar pr-1 animate-in fade-in zoom-in-95 duration-200"
              >
                {years.map((y) => (
                  <button
                    key={y}
                    data-year={y}
                    type="button"
                    onClick={() => selectYear(y)}
                    className={`px-2 py-4 rounded-xl text-[10px] font-black uppercase tracking-tight transition-all
                      ${viewDate.getFullYear() === y 
                        ? "bg-[#F1C40F] text-black shadow-[0_0_15px_rgba(241,196,15,0.2)]" 
                        : "text-zinc-500 hover:bg-white/5 hover:text-white"}`}
                  >
                    {y}
                  </button>
                ))}
              </div>
            )}

            <div className={`transition-opacity duration-200 ${(isMonthSelectorOpen || isYearSelectorOpen) ? "opacity-0 pointer-events-none" : "opacity-100"}`}>
              <div className="grid grid-cols-7 gap-1 mb-2">
                {days.map(day => (
                  <div key={day} className="h-9 w-9 flex items-center justify-center text-[10px] font-bold text-zinc-600 uppercase">
                    {day}
                  </div>
                ))}
              </div>

              <div className="grid grid-cols-7 gap-1">
                {renderCalendar()}
              </div>
            </div>
          </div>
          
          <div className="mt-4 pt-4 border-t border-white/5 flex justify-between">
            <button
              type="button"
              onClick={() => {
                onChange("");
                setIsOpen(false);
              }}
              className="px-4 py-2 text-[9px] font-black uppercase text-red-500/70 hover:text-red-500 hover:bg-red-500/5 rounded-lg transition-all"
            >
              Clear
            </button>
            <button
              type="button"
              onClick={() => {
                const today = formatDate(new Date());
                onChange(today);
                setIsOpen(false);
              }}
              className="px-4 py-2 text-[9px] font-black uppercase text-[#F1C40F]/70 hover:text-[#F1C40F] hover:bg-[#F1C40F]/5 rounded-lg transition-all"
            >
              Today
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
