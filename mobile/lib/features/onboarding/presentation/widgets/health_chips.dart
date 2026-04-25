import 'package:flutter/material.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';

// ── Condition list ────────────────────────────────────────────────────────────
// Organised in logical groups so the 2-column grid reads naturally.
const _conditions = [
  // Dietary / Intolerances
  ('Lactose Intolerance', '🥛'),
  ('Gluten / Celiac', '🌾'),
  ('Nut Allergy', '🥜'),
  ('IBS / Gut Issues', '🫃'),
  // Metabolic & Hormonal
  ('Diabetes', '🩸'),
  ('Thyroid Disorder', '🦋'),
  ('High Cholesterol', '🧪'),
  ('PCOS', '🔄'),
  // Cardiovascular
  ('Hypertension', '💊'),
  ('Heart Disease', '🫀'),
  // Musculoskeletal
  ('Arthritis', '🦴'),
  ('Osteoporosis', '🪨'),
  ('Back Pain', '🔙'),
  ('Knee Pain', '🦵'),
  // Respiratory & Other
  ('Asthma', '🫁'),
  ('Sleep Apnea', '😴'),
  ('Anxiety / Stress', '🧠'),
  ('Kidney Disease', '🫘'),
];

class HealthChips extends StatelessWidget {
  final List<String> selected;
  final bool noneSelected;
  final ValueChanged<String> onToggle;
  final ValueChanged<bool> onNoneToggle;

  const HealthChips({
    super.key,
    required this.selected,
    required this.noneSelected,
    required this.onToggle,
    required this.onNoneToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rows = (_conditions.length / 2).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2-column card grid
        for (int row = 0; row < rows; row++) ...[
          Row(
            children: [
              for (int col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Builder(builder: (context) {
                  final i = row * 2 + col;
                  if (i >= _conditions.length) return const Expanded(child: SizedBox());
                  final (label, emoji) = _conditions[i];
                  final isSelected = selected.contains(label);
                  return Expanded(
                    child: _ConditionCard(
                      label: label,
                      emoji: emoji,
                      selected: isSelected,
                      onTap: () => onToggle(label),
                    ),
                  );
                }),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 4),

        // "None" full-width option
        GestureDetector(
          onTap: () => onNoneToggle(!noneSelected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: noneSelected
                    ? const Color(0xFF22C55E)
                    : Colors.white.withValues(alpha: 0.08),
                width: noneSelected ? 1.5 : 1.0,
              ),
              color: noneSelected
                  ? const Color(0xFF22C55E).withValues(alpha: 0.10)
                  : AppTokens.colorBgSurface,
            ),
            child: Row(
              children: [
                const Text('✅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'None — I\'m in good health',
                    style: TextStyle(
                      color: AppTokens.colorTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (noneSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Individual condition card ─────────────────────────────────────────────────

class _ConditionCard extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionCard({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppTokens.colorBrand.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1.0,
          ),
          color: selected
              ? AppTokens.colorBrand.withValues(alpha: 0.12)
              : AppTokens.colorBgSurface,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppTokens.colorBrand
                      : AppTokens.colorTextSecondary,
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  height: 1.2,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: AppTokens.colorBrand,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
