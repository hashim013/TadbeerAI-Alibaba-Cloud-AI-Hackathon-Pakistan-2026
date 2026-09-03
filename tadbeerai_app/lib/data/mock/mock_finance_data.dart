import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_data.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/transaction.dart';

/// The single source of truth for Phase-2 DEMO financial data.
///
/// Widgets never hardcode amounts; everything flows from here through the
/// repository layer. The dataset models a salaried Karachi professional and
/// is deliberately consistent:
///
/// * Current month: income Rs 80,000, expenses Rs 65,000, savings Rs 15,000.
/// * Budgets leave exactly two categories over budget (transport, shopping)
///   so over-budget warnings are demonstrable.
/// * Four goals at 60 / 31 / 24 / 20 percent progress.
///
/// Dates are generated RELATIVE to [now] so the demo always looks current:
/// three fully-elapsed previous months plus the current month compressed
/// into the days elapsed so far (amounts stay exact; no future dates).
abstract final class MockFinanceData {
  /// Savings already set aside before the recorded history begins.
  static const double openingSavingsBalance = 135000;

  static List<Budget> seedBudgets() => const [
        Budget(id: 'budget-rent', category: 'rent', monthlyLimit: 18000),
        Budget(
            id: 'budget-groceries', category: 'groceries', monthlyLimit: 16000),
        Budget(
            id: 'budget-utilities', category: 'utilities', monthlyLimit: 10000),
        Budget(
            id: 'budget-transport', category: 'transport', monthlyLimit: 6500),
        Budget(id: 'budget-dining', category: 'dining', monthlyLimit: 5000),
        Budget(id: 'budget-shopping', category: 'shopping', monthlyLimit: 2500),
        Budget(id: 'budget-health', category: 'health', monthlyLimit: 2500),
        Budget(
            id: 'budget-entertainment',
            category: 'entertainment',
            monthlyLimit: 2500),
        Budget(
            id: 'budget-education', category: 'education', monthlyLimit: 2500),
      ];

  static List<Goal> seedGoals(DateTime now) => [
        Goal(
          id: 'goal-emergency',
          title: 'Emergency Fund',
          targetAmount: 300000,
          savedAmount: 180000,
          targetDate: DateTime(now.year, now.month + 10, now.day),
          icon: 'shield',
        ),
        Goal(
          id: 'goal-laptop',
          title: 'New Laptop',
          targetAmount: 150000,
          savedAmount: 46500,
          targetDate: DateTime(now.year, now.month + 4, now.day),
          icon: 'laptop',
        ),
        Goal(
          id: 'goal-education',
          title: 'Education',
          targetAmount: 200000,
          savedAmount: 48000,
          targetDate: DateTime(now.year, now.month + 12, now.day),
          icon: 'education',
        ),
        Goal(
          id: 'goal-travel',
          title: 'Travel',
          targetAmount: 100000,
          savedAmount: 20000,
          targetDate: DateTime(now.year, now.month + 8, now.day),
          icon: 'travel',
        ),
      ];

  /// All demo transactions for the last four months (3 previous + current).
  static List<Transaction> seedTransactions(DateTime now) {
    final transactions = <Transaction>[];
    var seq = 0;

    // Three fully-elapsed previous months, oldest first.
    for (var offset = 3; offset >= 1; offset--) {
      final month = DateTime(now.year, now.month - offset);
      for (final t in _monthTemplate(month, offset, now)) {
        transactions
            .add(t.copyWith(id: 'tx-${(seq++).toString().padLeft(3, '0')}'));
      }
    }

    // Current month — scheduled days are compressed into elapsed days so
    // the seed never contains future dates while monthly totals stay exact.
    final month = DateTime(now.year, now.month);
    for (final t in _monthTemplate(month, 0, now)) {
      transactions
          .add(t.copyWith(id: 'tx-${(seq++).toString().padLeft(3, '0')}'));
    }

    return transactions;
  }

  static FinanceData seed(DateTime now) => FinanceData(
        transactions: seedTransactions(now),
        budgets: seedBudgets(),
        goals: seedGoals(now),
        openingSavingsBalance: openingSavingsBalance,
      );

  // ── Month templates ─────────────────────────────────────────────────────

  /// Builds one month of activity. [offset] selects the amount variants:
  /// 3 = oldest month, 2 and 1 = middle months, 0 = current month.
  /// Variant lists are ordered oldest→current, so the index is 3 − offset.
  static List<Transaction> _monthTemplate(
      DateTime month, int offset, DateTime now) {
    DateTime day(int scheduled) {
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      var d = scheduled.clamp(1, lastDay);
      if (offset == 0) {
        // Compress into the elapsed part of the current month: day 1 stays
        // day 1, day 28 maps to today, and the mapping is identity once 28+
        // days have elapsed.
        d = 1 + ((d - 1) * (now.day - 1)) ~/ 27;
      }
      return DateTime(month.year, month.month, d.clamp(1, lastDay));
    }

    final salary = [73000.0, 75000.0, 75000.0, 75000.0][3 - offset];
    final groceriesTrip = [3700.0, 4050.0, 3800.0, 3950.0][3 - offset];
    final electricity = [5200.0, 6400.0, 5400.0, 5900.0][3 - offset];
    final gas = [1900.0, 2100.0, 1800.0, 1900.0][3 - offset];
    final fuel = [2300.0, 2600.0, 2350.0, 2500.0][3 - offset];
    final rides = [1600.0, 2400.0, 1800.0, 2000.0][3 - offset];
    final dinner = [1350.0, 1600.0, 1300.0, 1500.0][3 - offset];
    final shopping = [2900.0, 4100.0, 2700.0, 3200.0][3 - offset];
    final health = [1500.0, 2400.0, 1200.0, 2000.0][3 - offset];
    final fun = [750.0, 900.0, 700.0, 800.0][3 - offset];

    final pick = day;

    return [
      Transaction(
        id: '',
        title: 'Monthly salary',
        amount: salary,
        type: TransactionType.income,
        category: 'salary',
        date: pick(1),
      ),
      Transaction(
        id: '',
        title: 'Freelance project',
        amount: 5000,
        type: TransactionType.income,
        category: 'freelance',
        date: pick(12),
      ),
      Transaction(
        id: '',
        title: 'House rent',
        amount: 18000,
        type: TransactionType.expense,
        category: 'rent',
        date: pick(1),
      ),
      Transaction(
        id: '',
        title: 'Grocery run',
        amount: groceriesTrip,
        type: TransactionType.expense,
        category: 'groceries',
        date: pick(2),
      ),
      Transaction(
        id: '',
        title: 'Grocery run',
        amount: groceriesTrip,
        type: TransactionType.expense,
        category: 'groceries',
        date: pick(9),
      ),
      Transaction(
        id: '',
        title: 'Grocery run',
        amount: groceriesTrip,
        type: TransactionType.expense,
        category: 'groceries',
        date: pick(16),
      ),
      Transaction(
        id: '',
        title: 'Grocery run',
        amount: groceriesTrip,
        type: TransactionType.expense,
        category: 'groceries',
        date: pick(23),
      ),
      Transaction(
        id: '',
        title: 'Electricity bill',
        amount: electricity,
        type: TransactionType.expense,
        category: 'utilities',
        date: pick(5),
      ),
      Transaction(
        id: '',
        title: 'Gas bill',
        amount: gas,
        type: TransactionType.expense,
        category: 'utilities',
        date: pick(6),
      ),
      Transaction(
        id: '',
        title: 'Internet & mobile',
        amount: 2000,
        type: TransactionType.expense,
        category: 'utilities',
        date: pick(7),
      ),
      Transaction(
        id: '',
        title: 'Fuel top-up',
        amount: fuel,
        type: TransactionType.expense,
        category: 'transport',
        date: pick(3),
      ),
      Transaction(
        id: '',
        title: 'Fuel top-up',
        amount: fuel,
        type: TransactionType.expense,
        category: 'transport',
        date: pick(17),
      ),
      Transaction(
        id: '',
        title: 'Ride-hailing',
        amount: rides,
        type: TransactionType.expense,
        category: 'transport',
        date: pick(20),
      ),
      Transaction(
        id: '',
        title: 'Dinner out',
        amount: dinner,
        type: TransactionType.expense,
        category: 'dining',
        date: pick(8),
      ),
      Transaction(
        id: '',
        title: 'Dinner out',
        amount: dinner,
        type: TransactionType.expense,
        category: 'dining',
        date: pick(19),
      ),
      Transaction(
        id: '',
        title: 'Dinner out',
        amount: dinner,
        type: TransactionType.expense,
        category: 'dining',
        date: pick(26),
      ),
      Transaction(
        id: '',
        title: 'Shopping — clothes',
        amount: shopping,
        type: TransactionType.expense,
        category: 'shopping',
        date: pick(14),
      ),
      Transaction(
        id: '',
        title: 'Pharmacy — medicines',
        amount: health,
        type: TransactionType.expense,
        category: 'health',
        date: pick(10),
      ),
      Transaction(
        id: '',
        title: 'Streaming subscription',
        amount: fun,
        type: TransactionType.expense,
        category: 'entertainment',
        date: pick(11),
      ),
      Transaction(
        id: '',
        title: 'Movie night',
        amount: fun,
        type: TransactionType.expense,
        category: 'entertainment',
        date: pick(21),
      ),
      Transaction(
        id: '',
        title: 'Movie night',
        amount: fun,
        type: TransactionType.expense,
        category: 'entertainment',
        date: pick(27),
      ),
      Transaction(
        id: '',
        title: 'Online course installment',
        amount: 2300,
        type: TransactionType.expense,
        category: 'education',
        date: pick(13),
      ),
    ];
  }
}
