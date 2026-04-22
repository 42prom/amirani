import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../providers/recovery_provider.dart';

class RecoveryCheckInSheet extends ConsumerStatefulWidget {
  const RecoveryCheckInSheet({super.key});

  @override
  ConsumerState<RecoveryCheckInSheet> createState() =>
      _RecoveryCheckInSheetState();
}

class _RecoveryCheckInSheetState extends ConsumerState<RecoveryCheckInSheet> {
  int _sleepHours = 7;
  int _energyLevel = 3;
  int _sorenessLevel = 2;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    final success = await ref.read(recoveryProvider.notifier).logRecovery(
          sleepHours: _sleepHours,
          energyLevel: _energyLevel,
          sorenessLevel: _sorenessLevel,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(recoveryProvider).isSubmitting;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.self_improvement_rounded,
                      color: AppTheme.primaryBrand, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Recovery Check-in',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text('How are you feeling today?',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Sleep hours
            _buildSectionLabel('Sleep Hours', '$_sleepHours h'),
            Slider(
              value: _sleepHours.toDouble(),
              min: 3,
              max: 12,
              divisions: 9,
              activeColor: AppTheme.primaryBrand,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _sleepHours = v.round()),
            ),
            const SizedBox(height: 16),

            // Energy level
            _buildSectionLabel('Energy Level', _energyLabel(_energyLevel)),
            _buildDotSelector(
              value: _energyLevel,
              count: 5,
              activeColor: _energyColor(_energyLevel),
              onChanged: (v) => setState(() => _energyLevel = v),
            ),
            const SizedBox(height: 16),

            // Soreness level
            _buildSectionLabel('Muscle Soreness', _sorenessLabel(_sorenessLevel)),
            _buildDotSelector(
              value: _sorenessLevel,
              count: 5,
              activeColor: _sorenessColor(_sorenessLevel),
              onChanged: (v) => setState(() => _sorenessLevel = v),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Optional notes (injuries, stress, etc.)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBrand),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBrand,
                  disabledBackgroundColor:
                      AppTheme.primaryBrand.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Save Check-in',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(
                color: AppTheme.primaryBrand,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDotSelector({
    required int value,
    required int count,
    required Color activeColor,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(count, (i) {
        final idx = i + 1;
        final isActive = idx <= value;
        return GestureDetector(
          onTap: () => onChanged(idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? activeColor.withValues(alpha: 0.5)
                    : Colors.white12,
              ),
            ),
            child: Center(
              child: Text('$idx',
                  style: TextStyle(
                      color: isActive ? activeColor : Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }),
    );
  }

  String _energyLabel(int v) =>
      ['', 'Exhausted', 'Low', 'Moderate', 'Good', 'Excellent'][v];
  Color _energyColor(int v) {
    if (v <= 2) return Colors.redAccent;
    if (v == 3) return Colors.orangeAccent;
    return const Color(0xFF2ECC71);
  }

  String _sorenessLabel(int v) =>
      ['', 'None', 'Mild', 'Moderate', 'Sore', 'Very Sore'][v];
  Color _sorenessColor(int v) {
    if (v <= 2) return const Color(0xFF2ECC71);
    if (v == 3) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
