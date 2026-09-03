/// A monthly spending limit for one expense category.
class Budget {
  const Budget({
    required this.id,
    required this.category,
    required this.monthlyLimit,
  });

  final String id;
  final String category;
  final double monthlyLimit;

  Budget copyWith({String? id, String? category, double? monthlyLimit}) =>
      Budget(
        id: id ?? this.id,
        category: category ?? this.category,
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'category': category, 'monthlyLimit': monthlyLimit};

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        category: json['category'] as String,
        monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Budget && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Budget($category: $monthlyLimit)';
}
