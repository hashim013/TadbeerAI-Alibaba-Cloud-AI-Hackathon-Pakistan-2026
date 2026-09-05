import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/domain/services/what_if_request.dart';

/// Guided What-If input → natural-language request (spec case 13). The
/// phrasings must match the backend parser's patterns.
void main() {
  test('save-more builds the canonical backend phrasing', () {
    expect(
      buildWhatIfMessage(kind: WhatIfKind.saveMore, amount: 5000),
      'What if I save PKR 5000 more every month?',
    );
  });

  test('save-more with months appends the horizon', () {
    expect(
      buildWhatIfMessage(kind: WhatIfKind.saveMore, amount: 10000, months: 12),
      'What if I save PKR 10000 more every month for 12 months?',
    );
  });

  test('expense change phrases increase and decrease', () {
    expect(
      buildWhatIfMessage(kind: WhatIfKind.expenseChange, amount: 10),
      'What if my expenses increase by 10%?',
    );
    expect(
      buildWhatIfMessage(
          kind: WhatIfKind.expenseChange, amount: 5, increase: false),
      'What if my expenses decrease by 5%?',
    );
  });

  test('rate change phrases increase and decrease', () {
    expect(
      buildWhatIfMessage(kind: WhatIfKind.rateChange, amount: 2),
      'What if interest rates increase by 2%?',
    );
    expect(
      buildWhatIfMessage(
          kind: WhatIfKind.rateChange, amount: 1.5, increase: false),
      'What if interest rates decrease by 1.5%?',
    );
  });

  test('whole numbers format without decimals', () {
    final message =
        buildWhatIfMessage(kind: WhatIfKind.saveMore, amount: 5000.0);
    expect(message, contains('PKR 5000 more'));
    expect(message, isNot(contains('5000.0')));
  });
}
