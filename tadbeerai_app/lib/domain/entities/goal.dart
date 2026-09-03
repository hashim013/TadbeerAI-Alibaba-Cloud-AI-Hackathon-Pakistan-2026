/// A savings goal the user is working toward.
class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.targetDate,
    this.icon = 'savings',
  });

  final String id;
  final String title;
  final double targetAmount;

  /// Money set aside for this goal so far. Never negative.
  final double savedAmount;

  /// When the user intends to reach the target.
  final DateTime targetDate;

  /// Visual key resolved by the UI layer ('shield', 'laptop', 'education',
  /// 'travel', 'savings', 'home', 'celebration').
  final String icon;

  Goal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
    String? icon,
  }) =>
      Goal(
        id: id ?? this.id,
        title: title ?? this.title,
        targetAmount: targetAmount ?? this.targetAmount,
        savedAmount: savedAmount ?? this.savedAmount,
        targetDate: targetDate ?? this.targetDate,
        icon: icon ?? this.icon,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'targetDate': targetDate.toIso8601String(),
        'icon': icon,
      };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        title: json['title'] as String,
        targetAmount: (json['targetAmount'] as num).toDouble(),
        savedAmount: (json['savedAmount'] as num).toDouble(),
        targetDate: DateTime.parse(json['targetDate'] as String),
        icon: (json['icon'] as String?) ?? 'savings',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Goal && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Goal($title $savedAmount/$targetAmount)';
}
