import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'en_strings.dart';
import 'l10n_state.dart';

class L10nNotifier extends StateNotifier<L10nState> {
  final SharedPreferences _prefs;
  final Dio _dio;

  // Private translation map — never in state so freezed equality is cheap.
  Map<String, String> _translations = {};

  static const _kPack        = '_l10n_pack';
  static const _kVersion     = '_l10n_version';
  static const _kLang        = '_l10n_lang';
  static const _kDisplayName = '_l10n_name';

  L10nNotifier(this._prefs, this._dio) : super(const L10nState()) {
    _restoreFromCache();
  }

  // ─── Public API ─────────────────────────────────────────────────────────

  /// Resolves a key: alternative → English const → bare key.
  String tr(String key) {
    if (state.lang == 'en') return kEn[key] ?? key;
    return _translations[key] ?? kEn[key] ?? key;
  }

  /// Resolves a key with named placeholder substitution.
  /// e.g. trArgs('workout.log_set', {'n': '2', 'total': '4'})
  /// kEn entry: 'workout.log_set': 'Log Set {n} of {total}'
  String trArgs(String key, Map<String, String> args) {
    var s = tr(key);
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  /// Called by membership/gym provider after a successful fetch.
  /// Downloads the pack only when the cached version is outdated, missing,
  /// or the backend forces a refresh via [forceRefresh].
  Future<void> ensureLanguage({
    required String lang,
    required int version,
    String? displayName,
    bool forceRefresh = false,
  }) async {
    if (lang == 'en') {
      _switchToEnglish();
      return;
    }

    final cachedLang    = _prefs.getString(_kLang);
    final cachedVersion = _prefs.getInt(_kVersion) ?? 0;

    // Cache hit — skip download unless backend explicitly forces a refresh.
    if (!forceRefresh &&
        cachedLang == lang &&
        cachedVersion >= version &&
        _translations.isNotEmpty) {
      if (state.lang != lang) {
        state = state.copyWith(
          lang:           lang,
          altLangCode:    lang,
          version:        cachedVersion,
          altLangName:    displayName ?? _prefs.getString(_kDisplayName),
          hasAlternative: true,
        );
      }
      return;
    }

    state = state.copyWith(isDownloading: true, downloadError: null);

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/language-packs/$lang/$version',
      );

      final raw = res.data?['translations'];
      if (raw == null || raw is! Map) throw const FormatException('missing translations');

      // Type-safe parse — reject packs with non-string values.
      final pack = <String, String>{};
      for (final entry in raw.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw FormatException('bad entry type: ${entry.key}');
        }
        pack[entry.key as String] = entry.value as String;
      }
      if (pack.isEmpty) throw const FormatException('empty pack');

      // Atomic commit — only after full successful parse.
      await Future.wait([
        _prefs.setString(_kPack, jsonEncode(pack)),
        _prefs.setInt(_kVersion, version),
        _prefs.setString(_kLang, lang),
        if (displayName != null) _prefs.setString(_kDisplayName, displayName),
      ]);

      _translations = pack;
      state = L10nState(
        lang:           lang,
        altLangCode:    lang,
        version:        version,
        altLangName:    displayName ?? _prefs.getString(_kDisplayName),
        hasAlternative: true,
      );
    } catch (_) {
      state = state.copyWith(
        isDownloading: false,
        downloadError: 'settings.language_unavailable',
      );
    }
  }

  /// Instant toggle — no network call.
  void switchTo(String lang) {
    if (lang == 'en') {
      _switchToEnglish();
    } else if (_translations.isNotEmpty) {
      state = state.copyWith(lang: lang, downloadError: null);
    }
  }

  void clearError() => state = state.copyWith(downloadError: null);

  void resetToEnglish() => _switchToEnglish();

  Future<void> clearCache() async {
    await Future.wait([
      _prefs.remove(_kPack),
      _prefs.remove(_kVersion),
      _prefs.remove(_kLang),
      _prefs.remove(_kDisplayName),
    ]);
    _translations = {};
    state = const L10nState();
  }

  // ─── Private ────────────────────────────────────────────────────────────

  void _restoreFromCache() {
    final packed  = _prefs.getString(_kPack);
    final lang    = _prefs.getString(_kLang);
    final version = _prefs.getInt(_kVersion) ?? 0;

    if (packed == null || lang == null || lang == 'en') return;

    try {
      final decoded = jsonDecode(packed);
      if (decoded is! Map) throw const FormatException('not a map');

      final map = <String, String>{};
      for (final entry in decoded.entries) {
        if (entry.key is String && entry.value is String) {
          map[entry.key as String] = entry.value as String;
        }
      }

      // Corrupt but parseable (zero valid entries) — wipe and stay English.
      if (map.isEmpty) {
        _wipeCacheSync();
        return;
      }

      _translations = map;
      state = L10nState(
        lang:           lang,
        altLangCode:    lang,
        version:        version,
        altLangName:    _prefs.getString(_kDisplayName),
        hasAlternative: true,
      );
    } catch (_) {
      // Fully corrupted — wipe so next fetch starts clean.
      _wipeCacheSync();
    }
  }

  void _wipeCacheSync() {
    _prefs.remove(_kPack);
    _prefs.remove(_kVersion);
    _prefs.remove(_kLang);
    _prefs.remove(_kDisplayName);
  }

  void _switchToEnglish() {
    // Preserve altLangCode so the flag pill still shows the correct alt flag.
    state = state.copyWith(lang: 'en', isDownloading: false, downloadError: null);
  }
}
