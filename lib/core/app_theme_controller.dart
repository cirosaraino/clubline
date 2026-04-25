import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'club_theme_palette_extractor.dart';

class _StoredThemeState {
  const _StoredThemeState({required this.hasLocalOverride, this.palette});

  final bool hasLocalOverride;
  final ClublineThemePalette? palette;
}

class AppThemeController extends ChangeNotifier {
  AppThemeController() {
    ClublineAppTheme.applyPalette(_palette);
    _initialize();
  }

  static const _prefKeys = <String, String>{
    'black': 'theme_black',
    'background_top': 'theme_background_top',
    'background_bottom': 'theme_background_bottom',
    'surface': 'theme_surface',
    'surface_alt': 'theme_surface_alt',
    'accent': 'theme_accent',
  };
  static const _legacyThemeModeKey = 'theme_mode_v2';
  static const _themeModePrefix = 'theme_mode_v3';
  static const _themeModeStemma = 'stemma';
  static const _themeModeCustom = 'custom';

  ClublineThemePalette _palette = ClublineAppTheme.defaultPalette;
  ClublineThemePalette _clubPalette = ClublineAppTheme.defaultPalette;
  bool _isLoading = true;
  bool _hasLocalOverride = false;
  int _themeSyncRevision = 0;
  String? _currentClubScopeKey;
  bool _legacyPreferencesMigrated = false;

  ClublineThemePalette get palette => _palette;
  ClublineThemePalette get clubPalette => _clubPalette;
  bool get isLoading => _isLoading;
  List<ClublineThemePreset> get availablePresets =>
      ClublineAppTheme.presetsForClub(_clubPalette);

  Future<void> _initialize() async {
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updatePalette(ClublineThemePalette palette) async {
    _hasLocalOverride = true;
    _palette = palette;
    ClublineAppTheme.applyPalette(palette);
    notifyListeners();

    final scopeKey = _currentClubScopeKey;
    if (scopeKey == null) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _scopedThemeModeKey(scopeKey),
      _themeModeCustom,
    );
    final values = palette.toPrefsMap();
    for (final entry in _prefKeys.entries) {
      final value = values[entry.key];
      if (value != null) {
        await preferences.setInt(
          _scopedPaletteKey(scopeKey, entry.value),
          value,
        );
      }
    }
  }

  Future<void> syncWithClubTheme({
    required String? clubScope,
    required String? primaryColor,
    required String? accentColor,
    required String? surfaceColor,
    String? logoUrl,
  }) async {
    final revision = ++_themeSyncRevision;
    final normalizedScope = _normalizeClubScopeKey(clubScope);
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
    if (normalizedScope != _currentClubScopeKey) {
      _currentClubScopeKey = normalizedScope;
      final storedState = normalizedScope == null
          ? const _StoredThemeState(hasLocalOverride: false)
          : await _loadStoredThemeState(normalizedScope);
      if (revision != _themeSyncRevision) {
        return;
      }

      _hasLocalOverride = storedState.hasLocalOverride;
      if (_hasLocalOverride && storedState.palette != null) {
        _palette = storedState.palette!;
        ClublineAppTheme.applyPalette(_palette);
      }
    }

    if (!_hasLocalOverride) {
      _palette = _clubPalette;
      ClublineAppTheme.applyPalette(_palette);
    }

    notifyListeners();
  }

  Future<void> resetToDefault() async {
    _hasLocalOverride = false;
    _palette = _clubPalette;
    ClublineAppTheme.applyPalette(_palette);
    notifyListeners();

    final scopeKey = _currentClubScopeKey;
    if (scopeKey == null) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _scopedThemeModeKey(scopeKey),
      _themeModeStemma,
    );
    for (final key in _prefKeys.values) {
      await preferences.remove(_scopedPaletteKey(scopeKey, key));
    }
  }

  Future<ClublineThemePalette> _resolveClubPalette({
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
      return ClublineAppTheme.paletteFromClubTheme(
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
        return ClublineAppTheme.paletteFromClubTheme(
          primaryColor: extracted.primaryHex,
          accentColor: extracted.accentHex,
          surfaceColor: extracted.surfaceHex,
        );
      } catch (_) {
        return ClublineAppTheme.defaultPalette;
      }
    }

    return ClublineAppTheme.defaultPalette;
  }

  String? _normalizeClubScopeKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String _scopedThemeModeKey(String scopeKey) =>
      '${_themeModePrefix}_$scopeKey';

  String _scopedPaletteKey(String scopeKey, String baseKey) =>
      '${baseKey}_$scopeKey';

  Future<_StoredThemeState> _loadStoredThemeState(String scopeKey) async {
    final preferences = await SharedPreferences.getInstance();
    final storedMode = preferences.getString(_scopedThemeModeKey(scopeKey));
    final storedValues = _readStoredPalette(
      valueFor: (baseKey) =>
          preferences.getInt(_scopedPaletteKey(scopeKey, baseKey)),
    );

    if (storedMode == _themeModeCustom &&
        storedValues.length == _prefKeys.length) {
      return _StoredThemeState(
        hasLocalOverride: true,
        palette: ClublineThemePalette.fromPrefsMap(storedValues),
      );
    }

    final migratedState = await _migrateLegacyPreferencesIfNeeded(
      preferences,
      scopeKey,
    );
    if (migratedState != null) {
      return migratedState;
    }

    return const _StoredThemeState(hasLocalOverride: false);
  }

  Future<_StoredThemeState?> _migrateLegacyPreferencesIfNeeded(
    SharedPreferences preferences,
    String scopeKey,
  ) async {
    if (_legacyPreferencesMigrated) {
      return null;
    }

    final legacyMode = preferences.getString(_legacyThemeModeKey);
    final legacyValues = _readStoredPalette(valueFor: preferences.getInt);
    final hasLegacyCustom =
        legacyMode == _themeModeCustom &&
        legacyValues.length == _prefKeys.length;
    _legacyPreferencesMigrated = true;

    if (!hasLegacyCustom) {
      return null;
    }

    await preferences.setString(
      _scopedThemeModeKey(scopeKey),
      _themeModeCustom,
    );
    for (final entry in _prefKeys.entries) {
      final value = legacyValues[entry.key];
      if (value is int) {
        await preferences.setInt(
          _scopedPaletteKey(scopeKey, entry.value),
          value,
        );
      }
      await preferences.remove(entry.value);
    }
    await preferences.remove(_legacyThemeModeKey);

    return _StoredThemeState(
      hasLocalOverride: true,
      palette: ClublineThemePalette.fromPrefsMap(legacyValues),
    );
  }

  Map<String, Object?> _readStoredPalette({
    required int? Function(String key) valueFor,
  }) {
    final storedValues = <String, Object?>{};
    for (final entry in _prefKeys.entries) {
      final value = valueFor(entry.value);
      if (value != null) {
        storedValues[entry.key] = value;
      }
    }
    return storedValues;
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
