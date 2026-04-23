import React from "react";
import { Search, X } from "lucide-react";

interface FilterBarProps {
  searchTerm: string;
  onSearchChange: (value: string) => void;
  statusFilter: string;
  onStatusChange: (value: string) => void;
  statusOptions: { label: string; value: string }[];
  statusCounts?: Record<string, number>;
}

export const FilterBar: React.FC<FilterBarProps> = ({
  searchTerm,
  onSearchChange,
  statusFilter,
  onStatusChange,
  statusOptions,
  statusCounts = {},
}) => {
  return (
    <div className="flex flex-col md:flex-row items-center gap-6 mb-8 group">
      {/* Search Bar */}
      <div className="relative flex-1 w-full">
        <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none transition-colors duration-300 group-hover:text-accent">
          <Search size={18} className="text-zinc-500" />
        </div>
        <input
          type="text"
          value={searchTerm}
          onChange={(e) => onSearchChange(e.target.value)}
          placeholder="Search by name, email, or phone..."
          className="amirani-input amirani-input-with-icon font-medium"
        />
        {searchTerm && (
          <button
            onClick={() => onSearchChange("")}
            className="absolute right-4 top-1/2 -translate-y-1/2 p-1 hover:bg-white/5 rounded-lg text-zinc-500 hover:text-white transition-all shadow-inner border border-white/5"
          >
            <X size={14} />
          </button>
        )}
      </div>

      {/* Filter Options */}
      <div className="flex items-center gap-2 overflow-x-auto pb-2 md:pb-0 amirani-scrollbar w-full md:w-auto shrink-0">
        {statusOptions.map((option) => (
          <button
            key={option.value}
            onClick={() => onStatusChange(option.value)}
            className={`px-4 py-2.5 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all border whitespace-nowrap ${
              statusFilter === option.value
                ? "bg-accent text-black border-accent shadow-lg shadow-accent/20"
                : "bg-white/[0.02] text-zinc-500 border-white/5 hover:border-white/10 hover:text-zinc-300"
            }`}
          >
            {option.label}
            {statusCounts[option.value] !== undefined && (
              <span className={`ml-2 px-1.5 py-0.5 rounded-md text-[9px] ${
                statusFilter === option.value ? "bg-black/20" : "bg-white/5"
              }`}>
                {statusCounts[option.value]}
              </span>
            )}
          </button>
        ))}
      </div>
    </div>
  );
};
