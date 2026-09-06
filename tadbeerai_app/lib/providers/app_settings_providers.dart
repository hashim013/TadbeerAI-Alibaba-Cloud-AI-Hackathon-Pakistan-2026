import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import '../core/constants/app_constants.dart';
import '../features/auth/auth_controller.dart';
import 'repository_providers.dart';

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

/// Reactive controller managing active ThemeMode with persistence and backend sync.
class AppThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    try {
      final prefs = ref.watch(sharedPrefsProvider);
      final saved = prefs.getString(AppConstants.prefThemeMode);
      if (saved == 'light') return ThemeMode.light;
      if (saved == 'dark') return ThemeMode.dark;
      if (saved == 'system') return ThemeMode.system;
    } catch (_) {
      final settingsRepo = ref.watch(settingsRepositoryProvider);
      settingsRepo.readThemeMode().then((saved) {
        if (saved != null) {
          if (saved == 'light' && state != ThemeMode.light) {
            state = ThemeMode.light;
          } else if (saved == 'dark' && state != ThemeMode.dark) {
            state = ThemeMode.dark;
          } else if (saved == 'system' && state != ThemeMode.system) {
            state = ThemeMode.system;
          }
        }
      });
    }
    return ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode, {String? userId}) async {
    state = mode;
    try {
      await ref.read(settingsRepositoryProvider).writeThemeMode(mode.name);
    } catch (_) {}

    final effectiveUserId = userId ?? ref.read(authControllerProvider)?.id;
    if (effectiveUserId != null &&
        !effectiveUserId.startsWith('guest') &&
        effectiveUserId.isNotEmpty) {
      _syncThemeToBackend(effectiveUserId, mode.name);
    }
  }

  void _syncThemeToBackend(String userId, String themeMode) {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      dio.put(
        '/users/$userId',
        data: {'theme_mode': themeMode},
      ).catchError((_) {
        return Response(requestOptions: RequestOptions(path: ''));
      });
    } catch (_) {}
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
