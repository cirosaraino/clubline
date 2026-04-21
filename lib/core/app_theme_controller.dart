import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'club_theme_palette_extractor.dart';

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
  static const _themeModeKey = 'theme_mode_v2';
  static const _themeModeClub = 'club';
  static const _themeModeCustom = 'custom';

  UltrasThemePalette _palette = UltrasAppTheme.defaultPalette;
  UltrasThemePalette _clubPalette = UltrasAppTheme.defaultPalette;
  bool _isLoading = true;
  bool _hasLocalOverride = false;
  int _themeSyncRevision = 0;

  UltrasThemePalette get palette => _palette;
  UltrasThemePalette get clubPalette => _clubPalette;
  bool get isLoading => _isLoading;
  List<UltrasThemePreset> get availablePresets =>
      UltrasAppTheme.presetsForClub(_clubPalette);

  Future<void> _loadPalette() async {
    final preferences = await SharedPreferences.getInstance();
    final storedValues = <String, Object?>{};

    for (final entry in _prefKeys.entries) {
      final value = preferences.getInt(entry.value);
      if (value != null) {
        storedValues[entry.key] = value;
      }
    }

    final storedMode = preferences.getString(_themeModeKey);
    _hasLocalOverride =
        storedMode == _themeModeCustom &&
        storedValues.length == _prefKeys.length;

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
    await preferences.setString(_themeModeKey, _themeModeCustom);
    final values = palette.toPrefsMap();
    for (final entry in _prefKeys.entries) {
      final value = values[entry.key];
      if (value != null) {
        await preferences.setInt(entry.value, value);
      }
    }
  }

  Future<void> syncWithClubTheme({
    required String? primaryColor,
    required String? accentColor,
    required String? surfaceColor,
    String? logoUrl,
  }) async {
    final revision = ++_themeSyncRevision;
    final nextClubPalette = await _resolveClubPalette(
      primaryColor: primaryColor,
      accentColor: accentColor,
      surfaceColor: surfaceColor,
      logoUrl: logoUrl,
    );
    if (revision != _themeSyncRevision) {
      return;
    }

    _clubPalette = nextClubPalette;

    if (!_hasLocalOverride) {
      _palette = _clubPalette;
      UltrasAppTheme.applyPalette(_palette);
    }

    notifyListeners();
  }

  Future<void> resetToDefault() async {
    _hasLocalOverride = false;
    _palette = _clubPalette;
    UltrasAppTheme.applyPalette(_palette);
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, _themeModeClub);
    for (final key in _prefKeys.values) {
      await preferences.remove(key);
    }
  }

  Future<UltrasThemePalette> _resolveClubPalette({
    required String? primaryColor,
    required String? accentColor,
    required String? surfaceColor,
    required String? logoUrl,
  }) async {
    final hasExplicitClubColors = [
      primaryColor,
      accentColor,
      surfaceColor,
    ].any((value) => (value ?? '').trim().isNotEmpty);

    if (hasExplicitClubColors) {
      return UltrasAppTheme.paletteFromClubTheme(
        primaryColor: primaryColor,
        accentColor: accentColor,
        surfaceColor: surfaceColor,
      );
    }

    final normalizedLogoUrl = logoUrl?.trim();
    if (normalizedLogoUrl != null && normalizedLogoUrl.isNotEmpty) {
      try {
        final extracted = await extractClubThemePaletteFromUrl(
          normalizedLogoUrl,
        );
        return UltrasAppTheme.paletteFromClubTheme(
          primaryColor: extracted.primaryHex,
          accentColor: extracted.accentHex,
          surfaceColor: extracted.surfaceHex,
        );
      } catch (_) {
        return UltrasAppTheme.defaultPalette;
      }
    }

    return UltrasAppTheme.defaultPalette;
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope non trovato nel widget tree.');
    return scope!.notifier!;
  }

  static AppThemeController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppThemeScope>();
    final scope = element?.widget as AppThemeScope?;
    assert(scope != null, 'AppThemeScope non trovato nel widget tree.');
    return scope!.notifier!;
  }
}
