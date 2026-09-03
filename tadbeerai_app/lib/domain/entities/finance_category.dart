import 'transaction.dart';

/// A transaction category: stable [id] + display name resolved via l10n.
class FinanceCategory {
  const FinanceCategory(this.id, this.name, this.type);

  final String id;
  final String name;
  final TransactionType type;
}

/// The category catalog shared by every finance feature.
///
/// Ids are stable storage keys; localized display names come from the
/// generated localizations. The UI layer maps ids to icons/colors.
abstract final class FinanceCategories {
  static const salary =
      FinanceCategory('salary', 'Salary', TransactionType.income);
  static const freelance =
      FinanceCategory('freelance', 'Freelance', TransactionType.income);
  static const business =
      FinanceCategory('business', 'Business', TransactionType.income);
  static const otherIncome =
      FinanceCategory('other_income', 'Other income', TransactionType.income);

  static const rent = FinanceCategory('rent', 'Rent', TransactionType.expense);
  static const groceries =
      FinanceCategory('groceries', 'Groceries', TransactionType.expense);
  static const utilities =
      FinanceCategory('utilities', 'Utilities', TransactionType.expense);
  static const transport =
      FinanceCategory('transport', 'Transport', TransactionType.expense);
  static const dining =
      FinanceCategory('dining', 'Food & Dining', TransactionType.expense);
  static const shopping =
      FinanceCategory('shopping', 'Shopping', TransactionType.expense);
  static const health =
      FinanceCategory('health', 'Health', TransactionType.expense);
  static const entertainment = FinanceCategory(
      'entertainment', 'Entertainment', TransactionType.expense);
  static const education =
      FinanceCategory('education', 'Education', TransactionType.expense);
  static const other =
      FinanceCategory('other', 'Other', TransactionType.expense);

  static const List<FinanceCategory> income = [
    salary,
    freelance,
    business,
    otherIncome,
  ];

  static const List<FinanceCategory> expense = [
    rent,
    groceries,
    utilities,
    transport,
    dining,
    shopping,
    health,
    entertainment,
    education,
    other,
  ];

  /// Expense categories that count as discretionary (wants, not needs).
  static const Set<String> discretionaryExpenseIds = {
    'dining',
    'shopping',
    'entertainment',
    'other',
  };

  static FinanceCategory? byId(String id) {
    for (final c in [...income, ...expense]) {
      if (c.id == id) return c;
    }
    return null;
  }
}
