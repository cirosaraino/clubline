import 'package:flutter/material.dart';

@immutable
class UltrasThemePalette {
  const UltrasThemePalette({
    required this.black,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
  });

  final Color black;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;

  bool matches(UltrasThemePalette other) {
    return black.toARGB32() == other.black.toARGB32() &&
        backgroundTop.toARGB32() == other.backgroundTop.toARGB32() &&
        backgroundBottom.toARGB32() == other.backgroundBottom.toARGB32() &&
        surface.toARGB32() == other.surface.toARGB32() &&
        surfaceAlt.toARGB32() == other.surfaceAlt.toARGB32() &&
        accent.toARGB32() == other.accent.toARGB32();
  }

  UltrasThemePalette copyWith({
    Color? black,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? surface,
    Color? surfaceAlt,
    Color? accent,
  }) {
    return UltrasThemePalette(
      black: black ?? this.black,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      accent: accent ?? this.accent,
    );
  }

  Map<String, int> toPrefsMap() {
    return {
      'black': black.toARGB32(),
      'background_top': backgroundTop.toARGB32(),
      'background_bottom': backgroundBottom.toARGB32(),
      'surface': surface.toARGB32(),
      'surface_alt': surfaceAlt.toARGB32(),
      'accent': accent.toARGB32(),
    };
  }

  factory UltrasThemePalette.fromPrefsMap(Map<String, Object?> map) {
    return UltrasThemePalette(
      black: _colorFromValue(map['black']),
      backgroundTop: _colorFromValue(map['background_top']),
      backgroundBottom: _colorFromValue(map['background_bottom']),
      surface: _colorFromValue(map['surface']),
      surfaceAlt: _colorFromValue(map['surface_alt']),
      accent: _colorFromValue(map['accent']),
    );
  }

  static Color _colorFromValue(Object? value, {Color fallback = Colors.black}) {
    if (value is int) {
      return Color(value);
    }

    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return Color(parsed);
      }
    }

    return fallback;
  }

  static Color _mix(Color base, Color overlay, double amount) {
    final normalizedAmount = amount.clamp(0.0, 1.0).toDouble();
    return Color.alphaBlend(overlay.withValues(alpha: normalizedAmount), base);
  }

  Color get gold => accent;

  Color get goldSoft => _mix(accent, Colors.white, 0.42);

  Color get textPrimary => _mix(const Color(0xFFFFFBF0), accent, 0.08);

  Color get textMuted => _mix(const Color(0xFFD5C9A4), accent, 0.18);

  Color get outline => accent.withValues(alpha: 0.2);

  Color get outlineSoft => accent.withValues(alpha: 0.13);

  Color get outlineStrong => accent.withValues(alpha: 0.34);

  Color get shadow => black.withValues(alpha: 0.26);

  Color get surfaceSoft => _mix(surfaceAlt, Colors.white, 0.08);

  Color get surfaceRaised => _mix(surfaceAlt, Colors.white, 0.15);

  Color get success => const Color(0xFF80C697);

  Color get successSoft => const Color(0xFFBFE4CB);

  Color get danger => const Color(0xFFE28E8E);

  Color get dangerSoft => const Color(0xFFF4B9B9);

  Color get warning => const Color(0xFFF0D06A);

  Color get warningSoft => const Color(0xFFFFEDAE);

  LinearGradient get pageGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );

  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      _mix(surfaceAlt, accent, 0.1),
      _mix(_mix(backgroundBottom, surface, 0.6), black, 0.18),
    ],
  );

  Color get onAccent => accent.computeLuminance() > 0.45 ? black : Colors.white;
}

@immutable
class UltrasThemePreset {
  const UltrasThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.palette,
  });

  final String id;
  final String name;
  final String description;
  final UltrasThemePalette palette;
}

class UltrasAppTheme {
  static const UltrasThemePalette defaultPalette = UltrasThemePalette(
    black: Color(0xFF040A1C),
    backgroundTop: Color(0xFF0D2C73),
    backgroundBottom: Color(0xFF040A1C),
    surface: Color(0xFF08142F),
    surfaceAlt: Color(0xFF102247),
    accent: Color(0xFF10E6CB),
  );

  static const List<UltrasThemePreset> curatedPresets = [
    UltrasThemePreset(
      id: 'grafite_oro',
      name: 'Grafite Oro',
      description: 'Più neutra e professionale, con oro più pulito.',
      palette: UltrasThemePalette(
        black: Color(0xFF111214),
        backgroundTop: Color(0xFF1A1C20),
        backgroundBottom: Color(0xFF101114),
        surface: Color(0xFF181A1F),
        surfaceAlt: Color(0xFF23252B),
        accent: Color(0xFFFFC857),
      ),
    ),
    UltrasThemePreset(
      id: 'notte_blu',
      name: 'Notte Blu',
      description: 'Più fredda e moderna, ma sempre intensa.',
      palette: UltrasThemePalette(
        black: Color(0xFF0B1116),
        backgroundTop: Color(0xFF13202B),
        backgroundBottom: Color(0xFF091017),
        surface: Color(0xFF16222D),
        surfaceAlt: Color(0xFF1C2E3C),
        accent: Color(0xFF5BC0EB),
      ),
    ),
    UltrasThemePreset(
      id: 'verde_campo',
      name: 'Verde Campo',
      description: 'Scuro sportivo con un accento verde elegante.',
      palette: UltrasThemePalette(
        black: Color(0xFF0A100C),
        backgroundTop: Color(0xFF122016),
        backgroundBottom: Color(0xFF09120B),
        surface: Color(0xFF142118),
        surfaceAlt: Color(0xFF1C2D21),
        accent: Color(0xFF7CCB92),
      ),
    ),
    UltrasThemePreset(
      id: 'arena',
      name: 'Arena',
      description: 'Più caldo e deciso, con toni da match day.',
      palette: UltrasThemePalette(
        black: Color(0xFF110909),
        backgroundTop: Color(0xFF221010),
        backgroundBottom: Color(0xFF100707),
        surface: Color(0xFF1D1111),
        surfaceAlt: Color(0xFF291818),
        accent: Color(0xFFF08A7A),
      ),
    ),
  ];

  static UltrasThemePreset clubPreset(UltrasThemePalette palette) {
    return UltrasThemePreset(
      id: 'stemma',
      name: 'Stemma',
      description:
          'La palette reale del club, derivata da logo e colori attuali.',
      palette: palette,
    );
  }

  static List<UltrasThemePreset> presetsForClub(
    UltrasThemePalette clubPalette,
  ) {
    return [clubPreset(clubPalette), ...curatedPresets];
  }

  static UltrasThemePalette _activePalette = defaultPalette;

  static UltrasThemePalette get activePalette => _activePalette;

  static void applyPalette(UltrasThemePalette palette) {
    _activePalette = palette;
  }

  static void resetPalette() {
    _activePalette = defaultPalette;
  }

  static UltrasThemePalette paletteFromClubTheme({
    String? primaryColor,
    String? accentColor,
    String? surfaceColor,
  }) {
    final accent =
        _parseHexColor(accentColor) ??
        _parseHexColor(primaryColor) ??
        defaultPalette.accent;
    final surface =
        _parseHexColor(surfaceColor) ??
        _mix(accent, const Color(0xFF0E1118), 0.68);
    final black = _mix(surface, Colors.black, 0.34);
    final backgroundTop = _mix(surface, accent, 0.12);
    final backgroundBottom = _mix(black, accent, 0.08);
    final surfaceAlt = _mix(surface, Colors.white, 0.06);

    return UltrasThemePalette(
      black: black,
      backgroundTop: backgroundTop,
      backgroundBottom: backgroundBottom,
      surface: surface,
      surfaceAlt: surfaceAlt,
      accent: accent,
    );
  }

  static Color? _parseHexColor(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    final hex = normalized.startsWith('#')
        ? normalized.substring(1)
        : normalized;
    if (hex.length != 6) {
      return null;
    }

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      return null;
    }

    return Color(0xFF000000 | parsed);
  }

  static Color _mix(Color base, Color overlay, double amount) {
    return Color.alphaBlend(
      overlay.withValues(alpha: amount.clamp(0.0, 1.0)),
      base,
    );
  }

  static Color get black => activePalette.black;
  static Color get backgroundTop => activePalette.backgroundTop;
  static Color get backgroundBottom => activePalette.backgroundBottom;
  static Color get surface => activePalette.surface;
  static Color get surfaceAlt => activePalette.surfaceAlt;
  static Color get surfaceSoft => activePalette.surfaceSoft;
  static Color get surfaceRaised => activePalette.surfaceRaised;
  static Color get gold => activePalette.gold;
  static Color get goldSoft => activePalette.goldSoft;
  static Color get textPrimary => activePalette.textPrimary;
  static Color get textMuted => activePalette.textMuted;
  static Color get outline => activePalette.outline;
  static Color get outlineSoft => activePalette.outlineSoft;
  static Color get outlineStrong => activePalette.outlineStrong;
  static Color get shadow => activePalette.shadow;
  static Color get success => activePalette.success;
  static Color get successSoft => activePalette.successSoft;
  static Color get danger => activePalette.danger;
  static Color get dangerSoft => activePalette.dangerSoft;
  static Color get warning => activePalette.warning;
  static Color get warningSoft => activePalette.warningSoft;

  static LinearGradient get pageGradient => activePalette.pageGradient;
  static LinearGradient get heroGradient => activePalette.heroGradient;

  static List<BoxShadow> get softShadow => [
    BoxShadow(color: shadow, blurRadius: 18, offset: const Offset(0, 10)),
  ];

  static BoxDecoration heroDecoration({double radius = 28}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: heroGradient,
      border: Border.all(color: outlineStrong),
      boxShadow: softShadow,
    );
  }

  static ThemeData buildTheme([UltrasThemePalette? palette]) {
    final colors = palette ?? activePalette;
    final colorScheme = ColorScheme.dark(
      primary: colors.gold,
      onPrimary: colors.onAccent,
      secondary: colors.goldSoft,
      onSecondary: colors.black,
      error: colors.danger,
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.black,
      canvasColor: colors.black,
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.outline),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.black,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        height: 78,
        indicatorColor: colors.gold.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? colors.gold
                : colors.textMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.gold
                : colors.textMuted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.gold,
        foregroundColor: colors.onAccent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.gold),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.gold,
          foregroundColor: colors.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.gold,
          foregroundColor: colors.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.goldSoft,
          side: BorderSide(color: colors.outlineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.goldSoft,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        labelStyle: TextStyle(color: colors.textMuted),
        floatingLabelStyle: TextStyle(color: colors.goldSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.gold),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineSoft,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceSoft,
        contentTextStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceAlt,
        selectedColor: colors.gold.withValues(alpha: 0.18),
        disabledColor: colors.surfaceAlt,
        labelStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: colors.outlineSoft),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        iconColor: colors.textMuted,
        textColor: colors.textPrimary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.gold,
        selectionColor: colors.gold.withValues(alpha: 0.28),
        selectionHandleColor: colors.gold,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        titleMedium: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: colors.textPrimary),
        bodySmall: TextStyle(color: colors.textMuted),
        labelSmall: TextStyle(
          color: colors.onAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
