import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/finance_category.dart';
import '../../l10n/app_localizations.dart';

/// Icon + tint for a transaction category, mapped in the UI layer so the
/// domain stays free of Flutter dependencies.
class CategoryVisual {
  const CategoryVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}

/// Maps category ids to their visual treatment and localized names.
abstract final class CategoryVisuals {
  static const Map<String, CategoryVisual> _visuals = {
    // Income
    'salary': CategoryVisual(Icons.payments_rounded, AppColors.teal),
    'freelance': CategoryVisual(Icons.laptop_mac_rounded, Color(0xFF60A5FA)),
    'business': CategoryVisual(Icons.storefront_rounded, Color(0xFFFBBF24)),
    'other_income':
        CategoryVisual(Icons.attach_money_rounded, Color(0xFF94A3B8)),
    // Expenses
    'rent': CategoryVisual(Icons.home_rounded, Color(0xFF38BDF8)),
    'groceries':
        CategoryVisual(Icons.shopping_basket_rounded, Color(0xFF34D399)),
    'utilities': CategoryVisual(Icons.bolt_rounded, Color(0xFFFB923C)),
    'transport':
        CategoryVisual(Icons.directions_car_rounded, Color(0xFF818CF8)),
    'dining': CategoryVisual(Icons.restaurant_rounded, Color(0xFFFB7185)),
    'shopping': CategoryVisual(Icons.shopping_bag_rounded, Color(0xFFE879F9)),
    'health': CategoryVisual(Icons.medical_services_rounded, AppColors.danger),
    'entertainment': CategoryVisual(Icons.movie_rounded, Color(0xFFA78BFA)),
    'education': CategoryVisual(Icons.school_rounded, Color(0xFF22D3EE)),
    'other': CategoryVisual(Icons.category_rounded, Color(0xFF94A3B8)),
  };

  static const _fallback =
      CategoryVisual(Icons.category_rounded, AppColors.teal);

  static CategoryVisual of(String categoryId) =>
      _visuals[categoryId] ?? _fallback;

  static IconData goalIcon(String key) => switch (key) {
        'shield' => Icons.shield_rounded,
        'laptop' => Icons.laptop_rounded,
        'education' => Icons.school_rounded,
        'travel' => Icons.flight_rounded,
        'home' => Icons.home_rounded,
        'celebration' => Icons.celebration_rounded,
        _ => Icons.savings_rounded,
      };

  /// Goal icon choices offered when creating a goal.
  static const List<({String key, IconData icon})> goalIconChoices = [
    (key: 'shield', icon: Icons.shield_rounded),
    (key: 'laptop', icon: Icons.laptop_rounded),
    (key: 'education', icon: Icons.school_rounded),
    (key: 'travel', icon: Icons.flight_rounded),
    (key: 'home', icon: Icons.home_rounded),
    (key: 'savings', icon: Icons.savings_rounded),
    (key: 'celebration', icon: Icons.celebration_rounded),
  ];

  /// Localized display name for a category id.
  static String nameOf(AppLocalizations l10n, String categoryId) =>
      switch (categoryId) {
        'salary' => l10n.catSalary,
        'freelance' => l10n.catFreelance,
        'business' => l10n.catBusiness,
        'other_income' => l10n.catOtherIncome,
        'rent' => l10n.catRent,
        'groceries' => l10n.catGroceries,
        'utilities' => l10n.catUtilities,
        'transport' => l10n.catTransport,
        'dining' => l10n.catDining,
        'shopping' => l10n.catShopping,
        'health' => l10n.catHealth,
        'entertainment' => l10n.catEntertainment,
        'education' => l10n.catEducation,
        _ => l10n.catOther,
      };

  /// Chart palette keyed by category id, stable across screens.
  static Color chartColor(String categoryId, int fallbackIndex) {
    const palette = [
      AppColors.teal,
      Color(0xFF60A5FA),
      Color(0xFFFBBF24),
      Color(0xFF38BDF8),
      Color(0xFF34D399),
      Color(0xFF818CF8),
      Color(0xFFFB7185),
      Color(0xFFE879F9),
      Color(0xFF22D3EE),
      Color(0xFF94A3B8),
    ];
    if (_visuals.containsKey(categoryId)) {
      return _visuals[categoryId]!.color;
    }
    return palette[fallbackIndex % palette.length];
  }

  /// Lists of categories for pickers, in display order.
  static List<FinanceCategory> incomeCategories() => FinanceCategories.income;
  static List<FinanceCategory> expenseCategories() => FinanceCategories.expense;
}
