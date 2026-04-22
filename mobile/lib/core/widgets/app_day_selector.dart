import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';

class AppDaySelector extends StatelessWidget {
  final int activeDay;
  final ValueChanged<int> onDaySelected;
  final Set<int> daysWithTasks;

  const AppDaySelector({
    super.key,
    required this.activeDay,
    required this.onDaySelected,
    this.daysWithTasks = const {},
  });

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final isActive = index == activeDay;
          final isToday = index == todayIndex;
          final hasTasks = daysWithTasks.contains(index);

          return GestureDetector(
            onTap: () => onDaySelected(index),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  dayLabels[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isActive
                        ? (isToday ? AppTheme.primaryBrand : Colors.white)
                        : isToday
                            ? AppTheme.primaryBrand.withValues(alpha: 0.85)
                            : Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: isActive ? 10 : 6,
                  height: isActive ? 10 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppTheme.primaryBrand
                        : hasTasks
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.transparent,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryBrand.withValues(alpha: 0.8),
                              blurRadius: 12,
                            )
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
