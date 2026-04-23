import React from "react";
import { Loader2 } from "lucide-react";

export interface ColumnDef<T> {
  header: string;
  cell: (item: T) => React.ReactNode;
}

interface DataTableProps<T> {
  data: T[] | undefined;
  columns: ColumnDef<T>[];
  isLoading?: boolean;
  keyExtractor: (item: T) => string | number;
}

export function DataTable<T>({
  data,
  columns,
  isLoading,
  keyExtractor,
}: DataTableProps<T>) {
  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center py-20 bg-white/[0.02] border border-white/5 rounded-[2.5rem] animate-pulse">
        <Loader2 className="text-accent animate-spin mb-4" size={32} />
        <p className="text-zinc-500 font-bold uppercase tracking-widest text-[10px]">Synchronizing Secure Data...</p>
      </div>
    );
  }

  if (!data || data.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 bg-white/[0.02] border border-white/5 rounded-[2.5rem]">
        <p className="text-zinc-500 font-bold uppercase tracking-widest text-[10px]">No records found in current protocol</p>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-[2.5rem] border border-white/5 bg-white/[0.02] backdrop-blur-md shadow-2xl">
      <div className="overflow-x-auto amirani-scrollbar">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="border-b border-white/5 bg-white/[0.01]">
              {columns.map((column, idx) => (
                <th
                  key={idx}
                  className="px-6 py-5 text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] italic"
                >
                  {column.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-white/[0.03]">
            {data.map((item) => (
              <tr
                key={keyExtractor(item)}
                className="hover:bg-white/[0.02] transition-all duration-300 group"
              >
                {columns.map((column, idx) => (
                  <td key={idx} className="px-6 py-4">
                    <div className="transition-transform duration-300 group-hover:translate-x-1">
                      {column.cell(item)}
                    </div>
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
