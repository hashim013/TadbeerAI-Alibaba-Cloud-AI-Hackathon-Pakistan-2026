import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Convenient access to generated localizations.
extension L10nContext on BuildContext {
  /// Generated [AppLocalizations] for this context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
