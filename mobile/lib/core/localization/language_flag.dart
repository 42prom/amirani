/// Maps language codes and ISO 3166-1 alpha-2 country codes to Unicode flag emoji.
///
/// Regional indicator symbols: 'A' = 0x1F1E6, offset by char code.
/// Two-letter country code → pair of regional indicators = flag emoji.
///
/// Usage:
///   LanguageFlag.of('en')          // → '🇬🇧'
///   LanguageFlag.fromCountry('ge') // → '🇬🇪'
abstract class LanguageFlag {
  /// Returns the flag emoji for a language code.
  /// Falls back to the 2-letter uppercase code if no mapping exists.
  static String of(String langCode) {
    final country = _langToCountry[langCode.toLowerCase()];
    if (country == null) return langCode.toUpperCase();
    return fromCountry(country);
  }

  /// Returns the flag emoji for an ISO 3166-1 alpha-2 country code.
  /// Falls back to the 2-letter uppercase code if rendering is unsupported.
  static String fromCountry(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return code;
    final a = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  /// Canonical language code → ISO 3166-1 alpha-2 country code.
  /// Covers the most common app languages; extend as needed.
  static const _langToCountry = <String, String>{
    'en':  'gb',  // English → 🇬🇧
    'ka':  'ge',  // Georgian → 🇬🇪
    'ru':  'ru',  // Russian → 🇷🇺
    'ar':  'sa',  // Arabic → 🇸🇦
    'tr':  'tr',  // Turkish → 🇹🇷
    'de':  'de',  // German → 🇩🇪
    'fr':  'fr',  // French → 🇫🇷
    'es':  'es',  // Spanish → 🇪🇸
    'it':  'it',  // Italian → 🇮🇹
    'pt':  'pt',  // Portuguese → 🇵🇹
    'pl':  'pl',  // Polish → 🇵🇱
    'uk':  'ua',  // Ukrainian → 🇺🇦
    'he':  'il',  // Hebrew → 🇮🇱
    'hi':  'in',  // Hindi → 🇮🇳
    'zh':  'cn',  // Chinese → 🇨🇳
    'ja':  'jp',  // Japanese → 🇯🇵
    'ko':  'kr',  // Korean → 🇰🇷
    'nl':  'nl',  // Dutch → 🇳🇱
    'sv':  'se',  // Swedish → 🇸🇪
    'no':  'no',  // Norwegian → 🇳🇴
    'da':  'dk',  // Danish → 🇩🇰
    'fi':  'fi',  // Finnish → 🇫🇮
    'cs':  'cz',  // Czech → 🇨🇿
    'sk':  'sk',  // Slovak → 🇸🇰
    'ro':  'ro',  // Romanian → 🇷🇴
    'hu':  'hu',  // Hungarian → 🇭🇺
    'bg':  'bg',  // Bulgarian → 🇧🇬
    'hr':  'hr',  // Croatian → 🇭🇷
    'sr':  'rs',  // Serbian → 🇷🇸
    'az':  'az',  // Azerbaijani → 🇦🇿
    'hy':  'am',  // Armenian → 🇦🇲
    'fa':  'ir',  // Persian → 🇮🇷
    'th':  'th',  // Thai → 🇹🇭
    'vi':  'vn',  // Vietnamese → 🇻🇳
    'id':  'id',  // Indonesian → 🇮🇩
    'ms':  'my',  // Malay → 🇲🇾
    'am':  'et',  // Amharic → 🇪🇹
    'sw':  'ke',  // Swahili → 🇰🇪
  };
}
