/// Timezone-neutral date utility for Amirani.
///
/// ## Design principle
/// Calendar dates (scheduledDate, plan start, "today") are treated as
/// YYYY-MM-DD *concepts*, not absolute moments in time. A meal scheduled
/// on "2025-04-14" should appear on April 14 on every device, regardless
/// of the user's UTC offset.
///
/// The backend sends scheduledDate as UTC-midnight ISO strings
/// ("2025-04-14T00:00:00.000Z"). Extracting the date portion "2025-04-14"
/// gives the calendar date the backend intended. The device's local
/// "today" is also expressed as "2025-04-14" (year/month/day from
/// DateTime.now()). String equality — no timezone math, no drift.
///
/// ## Single source of truth
/// All date keys, lookups, and comparisons across diet/workout features
/// must go through this class. Never call .toLocal() or .toUtc() on a
/// scheduledDate before comparing it to a plan date.
class AppDate {
  AppDate._();

  // ── Key extraction ──────────────────────────────────────────────────────────

  /// Canonical YYYY-MM-DD string from any DateTime.
  ///
  /// For UTC DateTimes from the backend ("2025-04-14T00:00:00.000Z"):
  ///   toIso8601String() → "2025-04-14T00:00:00.000Z" → "2025-04-14" ✓
  ///
  /// For local DateTimes from DateTime.now():
  ///   toIso8601String() → "2025-04-14T10:30:00.000" → "2025-04-14" ✓
  ///
  /// No timezone conversion — just string extraction.
  static String toKey(DateTime dt) => dt.toIso8601String().split('T').first;

  /// Today's YYYY-MM-DD key in the device's local timezone.
  static String todayKey() => toKey(DateTime.now());

  // ── DateTime construction ───────────────────────────────────────────────────

  /// Parse a YYYY-MM-DD or ISO-8601 string into a **local-midnight** DateTime.
  /// The time and timezone portions are stripped — only the calendar date
  /// survives, in the device's local context.
  ///
  /// "2025-04-14T00:00:00.000Z" → DateTime(2025, 4, 14)  ✓
  /// "2025-04-14"               → DateTime(2025, 4, 14)  ✓
  static DateTime parseDate(String isoOrDateStr) {
    final dateStr = isoOrDateStr.split('T').first;
    final parts = dateStr.split('-');
    if (parts.length != 3) return today();
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Local-midnight DateTime from any DateTime (strips time & timezone).
  ///
  /// Uses ISO string extraction instead of .toLocal() to avoid timezone
  /// conversion math that drifts UTC-midnight to the previous calendar day
  /// in UTC-negative zones.
  static DateTime localMidnight(DateTime dt) => parseDate(dt.toIso8601String());

  /// Today's local-midnight DateTime (no time component).
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ── Comparisons ─────────────────────────────────────────────────────────────

  /// True when two DateTimes represent the same YYYY-MM-DD, regardless of
  /// timezone, time-of-day, or whether they are UTC or local.
  static bool isSameDay(DateTime a, DateTime b) => toKey(a) == toKey(b);
}
