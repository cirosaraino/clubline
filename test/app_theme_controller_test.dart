import 'package:clubline/core/app_theme.dart';
import 'package:clubline/core/app_theme_controller.dart';
import 'package:clubline/core/club_theme_palette_extractor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitForController(AppThemeController controller) async {
  while (controller.isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'new clubs default to the stemma palette instead of reusing another club local override',
    () async {
      final controller = AppThemeController();
      addTearDown(controller.dispose);
      await _waitForController(controller);

      await controller.syncWithClubTheme(
        clubScope: 'club-a',
        primaryColor: '#1274FF',
        accentColor: '#00D4C6',
        surfaceColor: '#12384E',
        logoUrl: null,
      );

      final customPalette = controller.palette.copyWith(
        accent: const Color(0xFFFFB84C),
        surfaceAlt: const Color(0xFF2C1A12),
      );
      await controller.updatePalette(customPalette);
      expect(controller.palette.matches(customPalette), isTrue);

      await controller.syncWithClubTheme(
        clubScope: 'club-b',
        primaryColor: '#A53DFF',
        accentColor: '#FFB020',
        surfaceColor: '#1E1E2A',
        logoUrl: null,
      );

      expect(controller.palette.matches(customPalette), isFalse);
      expect(controller.palette.matches(controller.clubPalette), isTrue);
      expect(controller.availablePresets.first.id, 'stemma');
      expect(
        controller.availablePresets.first.palette.matches(controller.palette),
        isTrue,
      );
    },
  );

  test(
    'manual theme override is preserved until the user resets back to stemma',
    () async {
      final controller = AppThemeController();
      addTearDown(controller.dispose);
      await _waitForController(controller);

      await controller.syncWithClubTheme(
        clubScope: 'club-c',
        primaryColor: '#1274FF',
        accentColor: '#00D4C6',
        surfaceColor: '#12384E',
        logoUrl: null,
      );

      final customPalette = controller.palette.copyWith(
        accent: const Color(0xFFE57373),
        black: const Color(0xFF101010),
      );
      await controller.updatePalette(customPalette);

      await controller.syncWithClubTheme(
        clubScope: 'club-c',
        primaryColor: '#193B7A',
        accentColor: '#FACC15',
        surfaceColor: '#16263A',
        logoUrl: null,
      );

      expect(controller.clubPalette.matches(customPalette), isFalse);
      expect(controller.palette.matches(customPalette), isTrue);

      await controller.resetToDefault();

      expect(controller.palette.matches(controller.clubPalette), isTrue);
      expect(controller.availablePresets.first.id, 'stemma');
      expect(
        controller.availablePresets.first.palette.matches(controller.palette),
        isTrue,
      );
    },
  );

  test(
    'legacy global custom theme migrates into the current club scope once',
    () async {
      final legacyPalette = ClublineAppTheme.paletteFromClubTheme(
        primaryColor: '#123456',
        accentColor: '#FEDCBA',
        surfaceColor: '#111827',
      );
      final legacyValues = legacyPalette.toPrefsMap();
      SharedPreferences.setMockInitialValues({
        'theme_mode_v2': 'custom',
        'theme_black': legacyValues['black']!,
        'theme_background_top': legacyValues['background_top']!,
        'theme_background_bottom': legacyValues['background_bottom']!,
        'theme_surface': legacyValues['surface']!,
        'theme_surface_alt': legacyValues['surface_alt']!,
        'theme_accent': legacyValues['accent']!,
      });

      final controller = AppThemeController();
      addTearDown(controller.dispose);
      await _waitForController(controller);

      await controller.syncWithClubTheme(
        clubScope: 'club-legacy',
        primaryColor: '#1274FF',
        accentColor: '#00D4C6',
        surfaceColor: '#12384E',
        logoUrl: null,
      );

      expect(controller.palette.matches(legacyPalette), isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('theme_mode_v3_club-legacy'), 'custom');
      expect(preferences.getString('theme_mode_v2'), isNull);
      expect(
        preferences.getInt('theme_accent_club-legacy'),
        legacyValues['accent'],
      );
    },
  );

  test(
    'syncWithClubTheme derives the stemma palette from a storage-backed club logo when explicit colors are missing',
    () async {
      var loaderCalls = 0;
      String? receivedStoragePath;
      String? receivedLogoUrl;
      final controller = AppThemeController(
        paletteLoader: ({logoStoragePath, logoUrl}) async {
          loaderCalls += 1;
          receivedStoragePath = logoStoragePath;
          receivedLogoUrl = logoUrl;
          return const ClubThemePaletteResult(
            primaryColor: Color(0xFF2244AA),
            accentColor: Color(0xFF11CC88),
            surfaceColor: Color(0xFF102030),
          );
        },
      );
      addTearDown(controller.dispose);
      await _waitForController(controller);

      await controller.syncWithClubTheme(
        clubScope: 'club-storage',
        primaryColor: null,
        accentColor: null,
        surfaceColor: null,
        logoStoragePath: 'clubs/7/logo.png',
        logoUrl: null,
      );

      final expectedPalette = ClublineAppTheme.paletteFromClubTheme(
        primaryColor: '#2244AA',
        accentColor: '#11CC88',
        surfaceColor: '#102030',
      );
      expect(loaderCalls, 1);
      expect(receivedStoragePath, 'clubs/7/logo.png');
      expect(receivedLogoUrl, isNull);
      expect(controller.clubPalette.matches(expectedPalette), isTrue);
      expect(controller.palette.matches(expectedPalette), isTrue);
    },
  );

  test(
    'failed stemma extraction from a logo path falls back to the default palette',
    () async {
      final controller = AppThemeController(
        paletteLoader: ({logoStoragePath, logoUrl}) async {
          throw Exception('palette failed');
        },
      );
      addTearDown(controller.dispose);
      await _waitForController(controller);

      await controller.syncWithClubTheme(
        clubScope: 'club-fallback',
        primaryColor: null,
        accentColor: null,
        surfaceColor: null,
        logoStoragePath: 'clubs/9/logo.png',
        logoUrl: null,
      );

      expect(
        controller.clubPalette.matches(ClublineAppTheme.defaultPalette),
        isTrue,
      );
      expect(
        controller.palette.matches(ClublineAppTheme.defaultPalette),
        isTrue,
      );
    },
  );

  test(
    'manual theme override is preserved when the club logo updates the stemma palette from storage',
    () async {
      var paletteVersion = 1;
      final controller = AppThemeController(
        paletteLoader: ({logoStoragePath, logoUrl}) async {
          if (paletteVersion == 1) {
            return const ClubThemePaletteResult(
              primaryColor: Color(0xFF2B5FFF),
              accentColor: Color(0xFF29D3A2),
              surfaceColor: Color(0xFF11263D),
            );
          }

          return const ClubThemePaletteResult(
            primaryColor: Color(0xFF8F2CFF),
            accentColor: Color(0xFFFFB020),
            surfaceColor: Color(0xFF1A1228),
          );
        },
      );
      addTearDown(controller.dispose);
      await _waitForController(controller);

      await controller.syncWithClubTheme(
        clubScope: 'club-storage-override',
        primaryColor: null,
        accentColor: null,
        surfaceColor: null,
        logoStoragePath: 'clubs/10/logo-a.png',
        logoUrl: null,
      );

      final customPalette = controller.palette.copyWith(
        accent: const Color(0xFFFF7A59),
        surfaceAlt: const Color(0xFF25161A),
      );
      await controller.updatePalette(customPalette);

      paletteVersion = 2;
      await controller.syncWithClubTheme(
        clubScope: 'club-storage-override',
        primaryColor: null,
        accentColor: null,
        surfaceColor: null,
        logoStoragePath: 'clubs/10/logo-b.png',
        logoUrl: null,
      );

      final refreshedClubPalette = ClublineAppTheme.paletteFromClubTheme(
        primaryColor: '#8F2CFF',
        accentColor: '#FFB020',
        surfaceColor: '#1A1228',
      );
      expect(controller.clubPalette.matches(refreshedClubPalette), isTrue);
      expect(controller.palette.matches(customPalette), isTrue);
    },
  );
}
