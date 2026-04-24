import 'dart:async';

import 'package:flutter/material.dart';

import 'core/biometric_auth/biometric_unlock_controller.dart';
import 'core/app_session.dart';
import 'core/app_theme.dart';
import 'core/app_theme_controller.dart';
import 'ui/pages/app_shell_page.dart';
import 'ui/widgets/app_realtime_sync_host.dart';
import 'ui/widgets/biometric_unlock_host.dart';
import 'ui/widgets/mobile_web_install_prompt_host.dart';

class ClublineApp extends StatefulWidget {
  const ClublineApp({super.key});

  @override
  State<ClublineApp> createState() => _ClublineAppState();
}

class _ClublineAppState extends State<ClublineApp> {
  late final AppSessionController sessionController;
  late final AppThemeController themeController;
  late final BiometricUnlockController biometricUnlockController;

  @override
  void initState() {
    super.initState();
    themeController = AppThemeController();
    sessionController = AppSessionController(
      onTeamInfoChanged: (teamInfo) {
        unawaited(
          themeController.syncWithClubTheme(
            primaryColor: teamInfo.primaryColor,
            accentColor: teamInfo.accentColor,
            surfaceColor: teamInfo.surfaceColor,
            logoUrl: teamInfo.crestUrl,
          ),
        );
      },
    );
    biometricUnlockController = BiometricUnlockController(
      sessionController: sessionController,
    );
  }

  @override
  void dispose() {
    biometricUnlockController.dispose();
    sessionController.dispose();
    themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeController, sessionController]),
      builder: (context, _) {
        final activePalette = sessionController.hasClubMembership
            ? themeController.palette
            : ClublineAppTheme.defaultPalette;

        return MaterialApp(
          title: 'Clubline',
          debugShowCheckedModeBanner: false,
          theme: ClublineAppTheme.buildTheme(activePalette),
          builder: (context, child) {
            return AppThemeScope(
              controller: themeController,
              child: AppSessionScope(
                controller: sessionController,
                child: BiometricUnlockScope(
                  controller: biometricUnlockController,
                  child: BiometricUnlockHost(
                    child: AppRealtimeSyncHost(
                      child: MobileWebInstallPromptHost(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          home: const AppShellPage(),
        );
      },
    );
  }
}

@Deprecated('Use ClublineApp instead.')
class SquadraApp extends ClublineApp {
  const SquadraApp({super.key});
}
