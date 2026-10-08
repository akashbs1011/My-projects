import 'package:intl/intl.dart';

/// Display formatting helpers.
class Formatters {
  const Formatters._();

  /// Scores arrive from the API as 0.0-1.0 and are always shown as whole
  /// percentages so two results can be compared at a glance.
  static String percent(double? value) => '${((value ?? 0) * 100).round()}%';

  static String dateTime(DateTime? value, String localeCode) {
    if (value == null) return '—';
    try {
      return DateFormat.yMMMd(localeCode).add_jm().format(value.toLocal());
    } catch (_) {
      // A locale without loaded date symbols falls back rather than throwing.
      return DateFormat.yMMMd().add_jm().format(value.toLocal());
    }
  }

  static String date(DateTime? value) =>
      value == null ? '—' : DateFormat.yMMMd().format(value.toLocal());

  /// Dataset symptoms are stored lowercase; labels read better capitalised.
  static String symptomLabel(String raw) =>
      raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
}
