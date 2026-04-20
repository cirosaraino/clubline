import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController() {
    UltrasAppTheme.applyPalette(_palette);
    _loadPalette();
  }

  static const _prefKeys = <String, String>{
    'black': 'theme_black',
    'background_top': 'theme_background_top',
    'background_bottom': 'theme_background_bottom',
    'surface': 'theme_surface',
    'surface_alt': 'theme_surface_alt',
    'accent': 'theme_accent',
  };

  UltrasThemePalette _palette = UltrasAppTheme.defaultPalette;
  UltrasThemePalette _clubPalette = UltrasAppTheme.defaultPalette;
  bool _isLoading = true;
  bool _hasLocalOverride = false;

  UltrasThemePalette get palette => _palette;
  bool get isLoading => _isLoading;

  Future<void> _loadPalette() async {
    final preferences = await SharedPreferences.getInstance();
    final storedValues = <String, Object?>{};

    for (final entry in _prefKeys.entries) {
      final value = preferences.getInt(entry.value);
      if (value != null) {
        storedValues[entry.key] = value;
      }
    }

    _hasLocalOverride = storedValues.length == _prefKeys.length;

    if (_hasLocalOverride) {
      _palette = UltrasThemePalette.fromPrefsMap(storedValues);
    } else {
      _palette = _clubPalette;
    }

    UltrasAppTheme.applyPalette(_palette);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updatePalette(UltrasThemePalette palette) async {
    _hasLocalOverride = true;
    _palette = palette;
    UltrasAppTheme.applyPalette(palette);
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    final values = palette.toPrefsMap();
    for (final entry in _prefKeys.entries) {
      final value = values[entry.key];
      if (value != null) {
        await preferences.setInt(entry.value, value);
      }
    }
  }

  void syncWithClubTheme({
    required String? primaryColor,
    required String? accentColor,
    required String? surfaceColor,
  }) {
    _clubPalette = UltrasAppTheme.paletteFromClubTheme(
      primaryColor: primaryColor,
      accentColor: accentColor,
      surfaceColor: surfaceColor,
    );

    if (_hasLocalOverride) {
      return;
    }

    _palette = _clubPalette;
    UltrasAppTheme.applyPalette(_palette);
    notifyListeners();
  }

  Future<void> resetToDefault() async {
    _hasLocalOverride = false;
    _palette = _clubPalette;
    UltrasAppTheme.applyPalette(_palette);
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    for (final key in _prefKeys.values) {
      await preferences.remove(key);
    }
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(
          notifier: controller,
        );

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope non trovato nel widget tree.');
    return scope!.notifier!;
  }

  static AppThemeController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppThemeScope>();
    final scope = element?.widget as AppThemeScope?;
    assert(scope != null, 'AppThemeScope non trovato nel widget tree.');
    return scope!.notifier!;
  }
}
