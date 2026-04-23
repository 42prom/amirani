import React from "react";

interface PageHeaderProps {
  title: React.ReactNode;
  description?: string;
  icon?: React.ReactNode;
  actions?: React.ReactNode;
}

export const PageHeader: React.FC<PageHeaderProps> = ({
  title,
  description,
  icon,
  actions,
}) => {
  return (
    <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 pb-8 border-b border-white/5 mb-12 relative overflow-visible">
      {/* Background Pattern */}
      <div className="absolute inset-x-0 -top-24 -bottom-10 bg-[radial-gradient(#ffffff05_1px,transparent_1px)] [background-size:20px_20px] [mask-image:linear-gradient(to_bottom,white,transparent)] pointer-events-none" />

      {/* Subtle Bottom Border Glow */}
      <div className="absolute bottom-0 left-0 w-48 h-[2px] bg-gradient-to-r from-accent via-accent/50 to-transparent opacity-40 -mb-[1px]" />
      
      <div className="flex items-center gap-5">
        {icon && (
          <div className="relative group">
            <div className="absolute -inset-2 bg-accent/20 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
            <div className="relative p-3.5 bg-accent/10 rounded-2xl border border-accent/20 shadow-2xl shadow-accent/5 transition-transform duration-500 hover:scale-105">
              <div className="text-accent flex items-center justify-center">
                {React.isValidElement(icon) 
                  ? React.cloneElement(icon as React.ReactElement<{ size?: number }>, { size: 28 })
                  : icon}
              </div>
            </div>
          </div>
        )}
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter uppercase italic leading-none">
            {title}
          </h1>
          {description && (
            <p className="text-zinc-500 mt-2.5 font-medium flex items-center gap-2 text-sm italic tracking-tight">
              <span className="w-1.5 h-1.5 rounded-full bg-accent shadow-[0_0_8px_rgba(241,196,15,0.6)]" />
              {description}
            </p>
          )}
        </div>
      </div>
      
      {actions && (
        <div className="flex flex-wrap items-center gap-4">
          {actions}
        </div>
      )}
    </div>
  );
};
