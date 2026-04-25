import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../l10n_keys.dart';
import '../l10n_provider.dart';
import '../l10n_state.dart';
import '../language_flag.dart';

/// Wraps a language section with consistent top spacing.
class L10nSection extends StatelessWidget {
  final Widget child;
  const L10nSection({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [const SizedBox(height: 32), child],
  );
}

/// Yellow bold section header matching the existing modal style.
class L10nSectionHeader extends StatelessWidget {
  final String title;
  const L10nSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title,
        style: const TextStyle(
            color: AppTokens.colorBrand, fontWeight: FontWeight.bold)),
  );
}

/// Muted info card — used when a feature is locked or unavailable.
class L10nInfoCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const L10nInfoCard({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Row(children: [
      Icon(icon, color: Colors.white38, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(message,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ),
    ]),
  );
}

/// Spinner row shown while a language pack is downloading.
class L10nDownloadingRow extends StatelessWidget {
  const L10nDownloadingRow({super.key});

  @override
  Widget build(BuildContext context) => _tile(
    child: Row(children: [
      const Icon(Icons.language_rounded, color: Colors.white38, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(L10n.settingsDownloadingLanguage,
            style: const TextStyle(color: Colors.white54, fontSize: 14)),
      ),
      const SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTokens.colorBrand),
        ),
      ),
    ]),
  );
}

/// EN ↔ alternative language toggle tile.
class L10nToggleTile extends StatelessWidget {
  final L10nState l10n;
  final WidgetRef ref;
  const L10nToggleTile({super.key, required this.l10n, required this.ref});

  @override
  Widget build(BuildContext context) => _tile(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const Icon(Icons.language_rounded, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          Text(L10n.settingsLanguage,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
        L10nLangPill(
          isEnglish: l10n.isEnglish,
          altCode:   l10n.altLangCode ?? l10n.lang,
          onToggle: (toEnglish) {
            HapticFeedback.lightImpact();
            ref.read(l10nProvider.notifier).switchTo(
              toEnglish ? 'en' : (l10n.altLangCode ?? l10n.lang),
            );
          },
        ),
      ],
    ),
  );
}

/// Animated flag pill selector — shows two flag emoji chips.
///
/// [enCode] and [altCode] are language codes passed to [LanguageFlag.of].
class L10nLangPill extends StatelessWidget {
  final bool isEnglish;
  final String altCode;   // language code for alt language e.g. 'ka'
  final void Function(bool toEnglish) onToggle;
  const L10nLangPill({
    super.key,
    required this.isEnglish,
    required this.altCode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onToggle(!isEnglish),
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        L10nChip(langCode: 'en',     active: isEnglish),
        const SizedBox(width: 2),
        L10nChip(langCode: altCode,  active: !isEnglish),
      ]),
    ),
  );
}

/// Single animated flag chip inside [L10nLangPill].
class L10nChip extends StatelessWidget {
  final String langCode;
  final bool active;
  const L10nChip({super.key, required this.langCode, required this.active});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeInOut,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: active ? AppTokens.colorBrand : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      LanguageFlag.of(langCode),
      style: const TextStyle(fontSize: 18, height: 1.2),
    ),
  );
}

/// Standard error snackbar for language download failures.
SnackBar l10nErrorSnackBar(String message) => SnackBar(
  content: Text(message),
  backgroundColor: const Color(0xFF2A2A2A),
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

// ─── Internal helper ─────────────────────────────────────────────────────────

Widget _tile({required Widget child}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  decoration: BoxDecoration(
    color: Colors.black.withValues(alpha: 0.3),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
  ),
  child: child,
);
