"use client";

import { createContext, useContext, useState, useCallback } from "react";
import { CheckCircle, XCircle, Info, X } from "lucide-react";

type ToastType = "success" | "error" | "info";

interface Toast {
  id: string;
  message: string;
  type: ToastType;
}

interface ToastContextValue {
  success: (message: string) => void;
  error: (message: string) => void;
  info: (message: string) => void;
}

const ToastContext = createContext<ToastContextValue>({
  success: () => {},
  error: () => {},
  info: () => {},
});

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const add = useCallback((message: string, type: ToastType) => {
    const id = Math.random().toString(36).slice(2);
    setToasts((prev) => [...prev, { id, message, type }]);
    setTimeout(
      () => setToasts((prev) => prev.filter((t) => t.id !== id)),
      4000
    );
  }, []);

  const remove = useCallback(
    (id: string) => setToasts((prev) => prev.filter((t) => t.id !== id)),
    []
  );

  const value: ToastContextValue = {
    success: (m) => add(m, "success"),
    error: (m) => add(m, "error"),
    info: (m) => add(m, "info"),
  };

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="fixed bottom-6 right-6 z-[9999] flex flex-col gap-3 pointer-events-none">
        {toasts.map((toast) => (
          <ToastItem key={toast.id} toast={toast} onRemove={remove} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

function ToastItem({
  toast,
  onRemove,
}: {
  toast: Toast;
  onRemove: (id: string) => void;
}) {
  const config = {
    success: {
      icon: <CheckCircle size={16} className="text-green-400 shrink-0 mt-0.5" />,
      border: "border-green-500/20",
      glow: "shadow-green-900/20",
    },
    error: {
      icon: <XCircle size={16} className="text-red-400 shrink-0 mt-0.5" />,
      border: "border-red-500/20",
      glow: "shadow-red-900/20",
    },
    info: {
      icon: <Info size={16} className="text-blue-400 shrink-0 mt-0.5" />,
      border: "border-blue-500/20",
      glow: "shadow-blue-900/20",
    },
  }[toast.type];

  return (
    <div
      className={`pointer-events-auto flex items-start gap-3 px-4 py-3 bg-[#121721] border ${config.border} rounded-2xl shadow-2xl ${config.glow} text-sm text-white max-w-sm animate-in slide-in-from-right-5 duration-300`}
    >
      {config.icon}
      <span className="flex-1 text-sm leading-snug">{toast.message}</span>
      <button
        onClick={() => onRemove(toast.id)}
        className="text-zinc-500 hover:text-white transition-colors shrink-0 mt-0.5"
      >
        <X size={14} />
      </button>
    </div>
  );
}

export function useToast() {
  return useContext(ToastContext);
}
