import 'package:intl/intl.dart';

/// PKR amount formatting used across all finance features.
abstract final class CurrencyFormat {
  static final NumberFormat _grouped = NumberFormat('#,##0');

  /// "15,000" — grouped digits, no symbol.
  static String amount(double value) => _grouped.format(value);

  /// "Rs 15,000" — the standard money label in the app.
  static String pkr(double value) {
    final sign = value < 0 ? '- ' : '';
    return '${sign}Rs ${_grouped.format(value.abs())}';
  }

  /// "Rs 80K" — compact form for chart axis labels and tight spaces.
  static String pkrCompact(double value) {
    final compact = NumberFormat.compact().format(value);
    return 'Rs $compact';
  }
}
