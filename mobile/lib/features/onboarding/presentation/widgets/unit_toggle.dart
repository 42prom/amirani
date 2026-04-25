import 'package:flutter/material.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';

class UnitToggle extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  /// Smaller padding and font — use when space is tight
  final bool compact;

  const UnitToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                  : const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppTokens.colorBrand : Colors.transparent,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  color: selected ? Colors.black : AppTokens.colorTextSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
