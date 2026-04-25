import 'package:clubline/core/app_theme.dart';
import 'package:clubline/core/app_theme_controller.dart';
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
}
