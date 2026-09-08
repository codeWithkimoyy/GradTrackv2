/// Helpers for the Academic Year Graduated field (YYYY–YYYY format).
class AcademicYearUtils {
  AcademicYearUtils._();

  /// Earliest academic year offered in the dropdown.
  static const int _floorYear = 2019;

  /// All selectable academic years, newest first, e.g.
  /// ['2025–2026', '2024–2025', ..., '2019–2020'].
  ///
  /// The academic year spanning the current calendar year is treated as
  /// the newest (in 2026 the list starts at 2025–2026).
  static List<String> options() {
    final now = DateTime.now();
    final newestStart = now.month >= 6 ? now.year : now.year - 1;
    final years = <String>[];
    for (var start = newestStart; start >= _floorYear; start--) {
      years.add('$start–${start + 1}');
    }
    return years;
  }

  /// True when [value] is one of the selectable academic-year strings.
  static bool isValid(String? value) => value != null && options().contains(value);

  /// Normalizes a stored value for searching: hyphens become en-dashes so
  /// '2025-2026' matches '2025–2026'.
  static String normalize(String? value) =>
      (value ?? '').trim().replaceAll('-', '–').toLowerCase();
}
