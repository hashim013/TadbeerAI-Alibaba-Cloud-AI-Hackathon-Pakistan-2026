/// Financial persona — how Tadbeer tailors advice.
enum Persona {
  student,
  salaried,
  businessOwner,
  shopOwner;

  String get storageKey => name;

  static Persona? fromStorageKey(String? key) {
    if (key == null) return null;
    for (final value in values) {
      if (value.name == key) return value;
    }
    return null;
  }
}

/// Primary financial goal the user is working toward.
enum PrimaryGoal {
  emergencyFund,
  saveMore,
  education,
  newDevice,
  businessGrowth,
  reduceSpending,
  other;

  String get storageKey => name;

  static PrimaryGoal? fromStorageKey(String? key) {
    if (key == null) return null;
    for (final value in values) {
      if (value.name == key) return value;
    }
    return null;
  }
}

/// A lightweight financial profile used to personalize Tadbeer's advice.
///
/// Fields are nullable while the user is filling in the form; once
/// [profileCompleted] flips to `true` all of them are expected to be set.
///
/// Validation rules:
/// * [monthlyIncome] ≥ 0 (zero is valid — students often have no income)
/// * [monthlyEssentialExpenses] ≥ 0
/// * Expenses may exceed income — this represents genuine financial pressure
///   and is surfaced as a friendly UI warning, never a hard block.
class FinancialProfile {
  const FinancialProfile({
    this.persona,
    this.monthlyIncome,
    this.monthlyEssentialExpenses,
    this.primaryGoal,
    this.profileCompleted = false,
  });

  final Persona? persona;
  final double? monthlyIncome;
  final double? monthlyEssentialExpenses;
  final PrimaryGoal? primaryGoal;
  final bool profileCompleted;

  FinancialProfile copyWith({
    Persona? persona,
    double? monthlyIncome,
    double? monthlyEssentialExpenses,
    PrimaryGoal? primaryGoal,
    bool? profileCompleted,
  }) =>
      FinancialProfile(
        persona: persona ?? this.persona,
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
        monthlyEssentialExpenses:
            monthlyEssentialExpenses ?? this.monthlyEssentialExpenses,
        primaryGoal: primaryGoal ?? this.primaryGoal,
        profileCompleted: profileCompleted ?? this.profileCompleted,
      );

  Map<String, dynamic> toJson() => {
        'persona': persona?.storageKey,
        'monthlyIncome': monthlyIncome,
        'monthlyEssentialExpenses': monthlyEssentialExpenses,
        'primaryGoal': primaryGoal?.storageKey,
        'profileCompleted': profileCompleted,
      };

  factory FinancialProfile.fromJson(Map<String, dynamic> json) =>
      FinancialProfile(
        persona: Persona.fromStorageKey(json['persona'] as String?),
        monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble(),
        monthlyEssentialExpenses:
            (json['monthlyEssentialExpenses'] as num?)?.toDouble(),
        primaryGoal: PrimaryGoal.fromStorageKey(json['primaryGoal'] as String?),
        profileCompleted: (json['profileCompleted'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialProfile &&
          other.persona == persona &&
          other.monthlyIncome == monthlyIncome &&
          other.monthlyEssentialExpenses == monthlyEssentialExpenses &&
          other.primaryGoal == primaryGoal &&
          other.profileCompleted == profileCompleted;

  @override
  int get hashCode => Object.hash(
        persona,
        monthlyIncome,
        monthlyEssentialExpenses,
        primaryGoal,
        profileCompleted,
      );

  @override
  String toString() => 'FinancialProfile(${persona?.name}, '
      'income: $monthlyIncome, expenses: $monthlyEssentialExpenses, '
      'goal: ${primaryGoal?.name}, completed: $profileCompleted)';
}
