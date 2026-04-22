import 'package:freezed_annotation/freezed_annotation.dart';

part 'l10n_state.freezed.dart';

/// Lightweight language state — the translation Map lives in L10nNotifier,
/// not here, so freezed equality never iterates hundreds of strings.
@freezed
class L10nState with _$L10nState {
  const factory L10nState({
    /// Active language code: 'en' or whatever the gym configured (e.g. 'ka').
    @Default('en') String lang,

    /// Integer version of the cached alternative pack (0 = none cached).
    @Default(0) int version,

    /// Language CODE of the alternative language, e.g. 'ka'.
    /// Preserved when the user switches back to English so the flag pill
    /// always knows which alt flag to display.
    String? altLangCode,

    /// Native-script display name for the alternative language, e.g. 'ქართული'.
    /// Null when no alternative language is configured.
    String? altLangName,

    /// True while the language pack is downloading in the background.
    @Default(false) bool isDownloading,

    /// Set when a download attempt fails. Cleared by clearError().
    String? downloadError,

    /// True once a valid alternative pack is loaded in the notifier.
    /// Drives visibility of the language toggle in Settings.
    @Default(false) bool hasAlternative,
  }) = _L10nState;

  const L10nState._();

  /// Convenience — avoids `state.lang == 'en'` scattered across the UI.
  bool get isEnglish => lang == 'en';
}
