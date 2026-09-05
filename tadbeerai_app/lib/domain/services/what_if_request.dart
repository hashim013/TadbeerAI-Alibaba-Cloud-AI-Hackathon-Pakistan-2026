/// Guided What-If input — converted into the natural-language request the
/// backend's deterministic scenario parser understands.
///
/// This is pure message formatting: no financial arithmetic happens in
/// Flutter. The backend parses the phrasing, computes every number with
/// Decimal precision and returns the structured scenario result.
library;

/// The scenario families the backend supports.
enum WhatIfKind { saveMore, expenseChange, rateChange }

/// Builds the natural-language question for a guided What-If input.
///
/// The phrasings match the backend parser's patterns ("save PKR … more
/// every month", "expenses increase/decrease by …%", "interest rates
/// increase/decrease by …%") so the deterministic engine picks them up
/// reliably.
String buildWhatIfMessage({
  required WhatIfKind kind,
  required double amount,
  int? months,
  bool increase = true,
}) {
  switch (kind) {
    case WhatIfKind.saveMore:
      final value = _formatNumber(amount);
      final horizon = months == null ? '' : ' for $months months';
      return 'What if I save PKR $value more every month$horizon?';
    case WhatIfKind.expenseChange:
      final direction = increase ? 'increase' : 'decrease';
      return 'What if my expenses $direction by ${_formatNumber(amount)}%?';
    case WhatIfKind.rateChange:
      final direction = increase ? 'increase' : 'decrease';
      return 'What if interest rates $direction by ${_formatNumber(amount)}%?';
  }
}

/// Whole numbers print without decimals; fractional values keep one place.
String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
