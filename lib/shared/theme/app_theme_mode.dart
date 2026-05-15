/// Plain-Dart theme mode enum used by [ThemeCubit] state. Mirrors
/// `package:flutter/material.dart`'s `ThemeMode` 1:1, but keeps the
/// bloc/cubit layer Flutter-free per CA-01 in docs/RULES.md.
///
/// Map to / from Flutter's enum via [appThemeModeToFlutter] /
/// [appThemeModeFromFlutter] at the widget-layer boundary in
/// `lib/app.dart`.
enum AppThemeMode { light, dark, system }
