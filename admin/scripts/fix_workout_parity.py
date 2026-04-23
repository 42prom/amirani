import re
import os

file_path = r"c:\Users\nakem\OneDrive\Desktop\amirani\admin\app\dashboard\trainer\members\[memberId]\workout\page.tsx"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Remove duplicate footer and misplaced div
# We look for the block starting with "{/* Magic Action Footer - 100% Parity" up to the next "</div>"
pattern_footer = r"\{/\* Magic Action Footer - 100% Parity with Diet Builder Flagship \*/\}\s*\{currentPlan && \(\s*<MagicActionFooter[\s\S]*?/>\s*\)\}\s*</div>"
content = re.sub(pattern_footer, "      </div>", content)

# 2. Fix the "Add Session" button
# Look for the button with "Establish Training Session"
pattern_btn = r"(<button onClick=\{\(\) => setShowAddRoutine\(true\)\} className=\")w-full h-16 border border-dashed border-zinc-800 hover:border-\[#F1C40F\]/40 rounded-xl flex items-center justify-center gap-2 text-zinc-600 hover:text-\[#F1C40F\] text-\[10px\] font-black uppercase tracking-\[0.2em\] transition-all(\">\s*<Plus size=\{16\} />) Establish Training Session"
replacement_btn = r'\1w-full h-14 flex items-center justify-center gap-2 border border-dashed border-zinc-700 rounded-xl text-zinc-500 hover:text-[#F1C40F] hover:border-[#F1C40F]/40 hover:bg-[#F1C40F]/5 transition-all text-sm font-medium\2 Add Session to {scheduledDateForDay ? getDayName(scheduledDateForDay) : `Day ${safeDay + 1}`}'
content = re.sub(pattern_btn, replacement_btn, content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Parity fix and structural cleanup applied successfully.")
