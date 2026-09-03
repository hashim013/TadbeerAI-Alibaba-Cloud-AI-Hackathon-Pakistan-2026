import 'budget.dart';
import 'goal.dart';
import 'transaction.dart';

/// The complete finance snapshot exposed to the UI through the repository
/// layer: everything the finance features render is derived from this.
class FinanceData {
  const FinanceData({
    required this.transactions,
    required this.budgets,
    required this.goals,
    required this.openingSavingsBalance,
  });

  /// All money movements; order is not guaranteed — sort on use.
  final List<Transaction> transactions;

  /// Monthly category limits.
  final List<Budget> budgets;

  /// Active savings goals.
  final List<Goal> goals;

  /// Savings the user already had before the recorded history began.
  /// Current savings = openingSavingsBalance + sum(income) − sum(expenses).
  final double openingSavingsBalance;

  FinanceData copyWith({
    List<Transaction>? transactions,
    List<Budget>? budgets,
    List<Goal>? goals,
    double? openingSavingsBalance,
  }) =>
      FinanceData(
        transactions: transactions ?? this.transactions,
        budgets: budgets ?? this.budgets,
        goals: goals ?? this.goals,
        openingSavingsBalance:
            openingSavingsBalance ?? this.openingSavingsBalance,
      );

  Map<String, dynamic> toJson() => {
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'budgets': budgets.map((b) => b.toJson()).toList(),
        'goals': goals.map((g) => g.toJson()).toList(),
        'openingSavingsBalance': openingSavingsBalance,
      };

  factory FinanceData.fromJson(Map<String, dynamic> json) => FinanceData(
        transactions: (json['transactions'] as List<dynamic>)
            .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        budgets: (json['budgets'] as List<dynamic>)
            .map((e) => Budget.fromJson(e as Map<String, dynamic>))
            .toList(),
        goals: (json['goals'] as List<dynamic>)
            .map((e) => Goal.fromJson(e as Map<String, dynamic>))
            .toList(),
        openingSavingsBalance:
            (json['openingSavingsBalance'] as num?)?.toDouble() ?? 0,
      );
}
