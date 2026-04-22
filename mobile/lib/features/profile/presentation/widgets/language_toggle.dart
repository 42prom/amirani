import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/theme/app_theme.dart';
import 'package:amirani_app/core/localization/l10n_provider.dart';
import 'package:amirani_app/core/localization/l10n_keys.dart';
import 'package:amirani_app/core/localization/l10n_state.dart';

/// Language section for the profile settings modal.
/// Renders nothing when the user has no alternative language configured.
class LanguageToggleSection extends ConsumerWidget {
  const LanguageToggleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    // Show snackbar once when a download error is set, then clear it.
    ref.listen(l10nProvider.select((s) => s.downloadError), (_, error) {
      if (error == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(L10n.settingsLanguageUnavailable),
            backgroundColor: const Color(0xFF2A2A2A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      ref.read(l10nProvider.notifier).clearError();
    });

    // Hide the section entirely when no alternative language is configured.
    if (!l10n.hasAlternative && !l10n.isDownloading) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            L10n.settingsLanguage,
            style: const TextStyle(
              color: AppTheme.primaryBrand,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _LanguageToggleTile(l10n: l10n, ref: ref),
      ],
    );
  }
}

class _LanguageToggleTile extends StatelessWidget {
  final L10nState l10n;
  final WidgetRef ref;

  const _LanguageToggleTile({required this.l10n, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.language_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 10),
              Text(
                L10n.settingsLanguage,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          if (l10n.isDownloading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBrand),
              ),
            )
          else
            _LangPill(
              isEnglish: l10n.isEnglish,
              altLabel: l10n.altLangName ?? '',
              onToggle: (toEnglish) {
                HapticFeedback.lightImpact();
                ref.read(l10nProvider.notifier).switchTo(
                  toEnglish ? 'en' : l10n.lang,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  final bool isEnglish;
  final String altLabel;
  final void Function(bool toEnglish) onToggle;

  const _LangPill({
    required this.isEnglish,
    required this.altLabel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!isEnglish),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(label: 'EN', active: isEnglish),
            const SizedBox(width: 2),
            _Chip(label: altLabel, active: !isEnglish),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;

  const _Chip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryBrand : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.black : Colors.white38,
          fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
