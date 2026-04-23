"use client";

import { X, ZoomIn, Download } from "lucide-react";
import NextImage from "next/image";
import { useEffect } from "react";

interface PhotoViewModalProps {
  url: string;
  alt?: string;
  onClose: () => void;
}

export function PhotoViewModal({ url, alt = "Photo View", onClose }: PhotoViewModalProps) {
  // Prevent scrolling when modal is open
  useEffect(() => {
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = "unset";
    };
  }, []);

  return (
    <div 
      className="fixed inset-0 z-[100] bg-black/95 backdrop-blur-xl flex items-center justify-center p-4 md:p-12 animate-in fade-in duration-300"
      onClick={onClose}
    >
      {/* BACKGROUND DECORATION */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-[#F1C40F]/10 blur-[120px] rounded-full animate-pulse" />
      </div>

      {/* CONTROLS */}
      <div className="absolute top-8 right-8 flex items-center gap-4 z-10" onClick={(e) => e.stopPropagation()}>
        <a 
          href={url} 
          download 
          target="_blank"
          rel="noopener noreferrer"
          className="p-3 bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white rounded-2xl border border-white/5 transition-all flex items-center gap-2 text-[10px] font-black uppercase tracking-widest shadow-2xl"
        >
          <Download size={18} />
          Save Data
        </a>
        <button 
          onClick={onClose}
          className="p-3 bg-white/10 text-white hover:bg-red-500 rounded-2xl border border-white/10 transition-all shadow-2xl group"
        >
          <X size={24} className="group-hover:scale-110 transition-transform" />
        </button>
      </div>

      <div className="absolute top-8 left-8 z-10 hidden md:block">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-[#F1C40F]/20 rounded-xl flex items-center justify-center border border-[#F1C40F]/30">
            <ZoomIn className="text-[#F1C40F]" size={20} />
          </div>
          <div>
            <p className="text-white font-black text-sm tracking-tighter uppercase italic">HD VISUAL DATA</p>
            <p className="text-[#F1C40F] text-[9px] font-black tracking-widest uppercase">Premium Verification Mode</p>
          </div>
        </div>
      </div>

      {/* IMAGE CONTAINER */}
      <div 
        className="relative w-full h-full max-w-5xl max-h-[85vh] group animate-in zoom-in-95 duration-500"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="absolute -inset-1 bg-gradient-to-r from-[#F1C40F]/20 via-transparent to-[#F1C40F]/20 blur-xl opacity-50 group-hover:opacity-100 transition-opacity duration-700" />
        <div className="relative w-full h-full rounded-[2rem] overflow-hidden border border-white/10 shadow-[0_0_80px_rgba(0,0,0,0.8)] bg-zinc-900/50">
          <NextImage 
            src={url} 
            alt={alt} 
            fill 
            className="object-contain p-2"
            unoptimized // Allow full quality viewing
          />
        </div>
      </div>

      {/* FOOTER HINT */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 text-center pointer-events-none">
        <p className="text-zinc-500 text-[9px] font-black uppercase tracking-[0.4em] animate-pulse">
          Click anywhere to exit visual inspection
        </p>
      </div>
    </div>
  );
}
