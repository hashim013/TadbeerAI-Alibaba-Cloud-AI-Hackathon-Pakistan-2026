import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported locales in Tadbeer AI.
enum AppLanguage {
  english(Locale('en'), 'English', 'English'),
  urdu(Locale('ur'), 'اردو', 'Urdu (Nastaliq)'),
  romanUrdu(
    Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn'),
    'Roman Urdu',
    'Urdu (Latin script)',
  );

  const AppLanguage(this.locale, this.displayName, this.nativeSubtitle);

  final Locale locale;
  final String displayName;
  final String nativeSubtitle;

  static AppLanguage fromLocale(Locale locale) {
    if (locale.languageCode == 'ur') {
      if (locale.scriptCode == 'Latn') return AppLanguage.romanUrdu;
      return AppLanguage.urdu;
    }
    return AppLanguage.english;
  }
}

/// Reactive controller managing active App Locale.
class AppLocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');

  void setLocale(Locale newLocale) {
    state = newLocale;
  }

  void setLanguage(AppLanguage language) {
    state = language.locale;
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(
  AppLocaleNotifier.new,
);

/// Reactive controller managing active ThemeMode.
class AppThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

final appThemeModeProvider = NotifierProvider<AppThemeModeNotifier, ThemeMode>(
  AppThemeModeNotifier.new,
);

/// Push notifications master toggle.
class PushNotificationsNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void set(bool val) => state = val;
}

final pushNotificationsProvider =
    NotifierProvider<PushNotificationsNotifier, bool>(
  PushNotificationsNotifier.new,
);

/// Market & essential commodity real-time alerts toggle.
class MarketAlertsNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void set(bool val) => state = val;
}

final marketAlertsProvider = NotifierProvider<MarketAlertsNotifier, bool>(
  MarketAlertsNotifier.new,
);

/// Sound & tactile haptics toggle.
class HapticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void set(bool val) => state = val;
}

final hapticsEnabledProvider = NotifierProvider<HapticsEnabledNotifier, bool>(
  HapticsEnabledNotifier.new,
);
