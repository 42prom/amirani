import os

file_path = r'c:\Users\nakem\OneDrive\Desktop\amirani\admin\app\dashboard\trainer\members\[memberId]\workout\page.tsx'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Reconstruct the section from line 690 (index 689) to line 755 (approx)
# We need to find the specific anchors to be safe.

start_marker = '          <div className="px-5 pt-3 flex items-end justify-between border-b border-zinc-800/50 pb-0 flex-wrap gap-4">'
end_marker = '            <div className="space-y-4">'

start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if start_marker in line:
        start_idx = i
    if end_marker in line and start_idx != -1 and i > start_idx:
        end_idx = i
        break

if start_idx == -1 or end_idx == -1:
    print(f"Error: Markers not found. start_idx={start_idx}, end_idx={end_idx}")
    # Fallback to line numbers based on the last view_file output if markers fail
    # But markers are safer.
    exit(1)

new_content = [
    '          <div className="px-5 pt-3 flex items-end justify-between border-b border-zinc-800/50 pb-0 flex-wrap gap-4">\n',
    '            <div className="flex gap-1.5 flex-wrap">\n',
    '              {Array.from({ length: numWeeks }, (_, i) => i + 1).map(w => {\n',
    '                const isActive = safeWeek === w;\n',
    '                return (\n',
    '                  <button key={w} onClick={() => { setSelectedWeek(w); setSelectedDay(0); setShowAddRoutine(false); }} className={`group relative px-6 py-4 text-xs font-black uppercase tracking-widest transition-all ${isActive ? "text-white" : "text-zinc-500 hover:text-zinc-300"}`}>\n',
    '                    <span className="relative z-10">Week {w}</span>\n',
    '                    {isActive && (\n',
    '                      <>\n',
    '                        <div className="absolute bottom-0 left-0 right-0 h-1 bg-[#F1C40F] shadow-[0_0_20px_rgba(241,196,15,0.5)] rounded-full animate-in fade-in slide-in-from-bottom-2 duration-500" />\n',
    '                        <div className="absolute inset-0 bg-[#F1C40F]/5 rounded-t-2xl animate-in fade-in duration-500" />\n',
    '                      </>\n',
    '                    )}\n',
    '                  </button>\n',
    '                );\n',
    '              })}\n',
    '            </div>\n',
    '            <div className="flex gap-1.5 pb-px flex-wrap justify-end">\n',
    '               <button onClick={() => setShowWeekImport(v => !v)} className={`px-2 py-1 text-[9px] font-bold uppercase rounded-lg transition-colors border ${showWeekImport ? "bg-[#F1C40F]/10 border-[#F1C40F]/30 text-[#F1C40F]" : "bg-zinc-800/80 border-zinc-700/50 text-zinc-500 hover:text-zinc-300"}`}>Import Week {showWeekImport ? "▴" : "▾"}</button>\n',
    '            </div>\n',
    '          </div>\n',
    '\n',
    '          <div className="px-5 pt-3 pb-0 flex gap-1 overflow-x-auto border-b border-zinc-800/30">\n',
    '            {Array.from({ length: 7 }).map((_, idx) => {\n',
    '              const dateStr = getScheduledDate(currentPlan.startDate!, safeWeek, idx);\n',
    '              const isActive = safeDay === idx;\n',
    '              const hasRoutines = currentPlan.routines.some(r => r.scheduledDate && normalizeDate(r.scheduledDate) === dateStr);\n',
    '              return (\n',
    '                <button key={idx} onClick={() => { setSelectedDay(idx); setShowAddRoutine(false); }} className={`group relative flex-shrink-0 px-5 py-4 transition-all ${isActive ? "text-white" : "text-zinc-500 hover:text-zinc-300"}`}>\n',
    '                  <div className="relative z-10">\n',
    '                    <span className="block text-[10px] font-black uppercase tracking-[0.2em] mb-1">{getDayName(dateStr).slice(0, 3)}</span>\n',
    '                    <span className="block text-xs font-bold opacity-60 transition-opacity whitespace-nowrap">{formatDate(dateStr)}</span>\n',
    '                    {hasRoutines && (\n',
    '                      <div className="absolute -top-1 -right-2 w-1 h-1 rounded-full bg-[#F1C40F] shadow-[0_0_5px_rgba(241,196,15,0.8)]" />\n',
    '                    )}\n',
    '                  </div>\n',
    '                  {isActive && (\n',
    '                    <div className="absolute inset-0 bg-white/[0.03] border-x border-white/5 animate-in fade-in duration-300" />\n',
    '                  )}\n',
    '                </button>\n',
    '              )\n',
    '            })}\n',
    '          </div>\n',
    '\n',
    '          <div className="p-6 space-y-8">\n',
    '            {/* Daily Summary - Micro Parity */}\n',
    '            {dayRoutines.length > 0 && (\n',
    '              <div className="bg-zinc-900/40 border border-zinc-800/60 rounded-xl p-5 flex flex-wrap gap-8 items-center">\n',
    '                 <MetricBar label="Physical Load" current={dayTotals.sets} target={20} color="text-white" unit="sets" />\n',
    '                 <div className="w-px h-8 bg-zinc-800/60 hidden sm:block" />\n',
    '                 <MetricBar label="Protocols" current={dayTotals.sessions} target={3} color="text-[#F1C40F]" unit="sessions" />\n',
    '                 <div className="w-px h-8 bg-zinc-800/60 hidden sm:block" />\n',
    '                 <div className="flex-1">\n',
    '                    <p className="text-[9px] text-zinc-600 font-bold uppercase leading-relaxed italic tracking-tighter">\n',
    '                       Integrity check: high volume detected. Ensure intra-workout recovery intervals exceed 90s.\n',
    '                    </p>\n',
    '                 </div>\n',
    '              </div>\n',
    '            )}\n'
]

# Apply replacement
final_lines = lines[:start_idx] + new_content + lines[end_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(final_lines)

print("Parity fix and structural cleanup applied successfully.")
