import React from "react";
import { LucideIcon } from "lucide-react";

interface ActionButtonProps {
  icon: LucideIcon;
  label: string;
  onClick: () => void;
  variant?: "default" | "primary";
}

export const ActionButton: React.FC<ActionButtonProps> = ({
  icon: Icon,
  label,
  onClick,
  variant = "default",
}) => {
  return (
    <button
      onClick={onClick}
      className={`
        relative group flex items-center gap-3 px-5 py-3.5 rounded-2xl font-black uppercase tracking-widest text-[10px] transition-all duration-500
        ${
          variant === "primary"
            ? "bg-[#F1C40F] text-black hover:bg-[#F1C40F]/90 shadow-[0_0_20px_rgba(241,196,15,0.1)] hover:shadow-[0_0_30px_rgba(241,196,15,0.3)] border-transparent"
            : "bg-white/[0.02] text-white border border-white/5 hover:border-[#F1C40F]/30 hover:bg-white/[0.05] backdrop-blur-xl"
        }
        active:scale-95 transform
      `}
    >
      {/* Shine effect */}
      <div className="absolute inset-0 bg-gradient-to-tr from-white/10 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity rounded-2xl pointer-events-none" />
      
      <Icon 
        size={16} 
        className={`transition-transform duration-500 group-hover:scale-110 ${variant === "primary" ? "text-black" : "text-[#F1C40F]"}`} 
      />
      <span className="relative z-10">{label}</span>
      
      {/* Bottom Glow */}
      <div className={`absolute -bottom-px left-1/2 -translate-x-1/2 w-3/4 h-px bg-gradient-to-r from-transparent ${variant === 'primary' ? 'via-black/20' : 'via-[#F1C40F]/40'} to-transparent`} />
    </button>
  );
};
