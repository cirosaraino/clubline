import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_session.dart';
import 'core/app_theme.dart';
import 'core/app_theme_controller.dart';
import 'ui/pages/app_shell_page.dart';
import 'ui/widgets/app_realtime_sync_host.dart';
import 'ui/widgets/mobile_web_install_prompt_host.dart';

class SquadraApp extends StatefulWidget {
  const SquadraApp({super.key});

  @override
  State<SquadraApp> createState() => _SquadraAppState();
}

class _SquadraAppState extends State<SquadraApp> {
  late final AppSessionController sessionController;
  late final AppThemeController themeController;

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
  }

  @override
  void dispose() {
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
            : UltrasAppTheme.defaultPalette;

        return MaterialApp(
          title: 'Clubline',
          debugShowCheckedModeBanner: false,
          theme: UltrasAppTheme.buildTheme(activePalette),
          builder: (context, child) {
            return AppThemeScope(
              controller: themeController,
              child: AppSessionScope(
                controller: sessionController,
                child: AppRealtimeSyncHost(
                  child: MobileWebInstallPromptHost(
                    child: child ?? const SizedBox.shrink(),
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
