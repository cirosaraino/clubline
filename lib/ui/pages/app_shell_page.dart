import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../widgets/app_chrome.dart';
import 'attendance_page.dart';
import 'home_page.dart';
import 'lineups_page.dart';
import 'player_form_page.dart';
import 'players_page.dart';
import 'streams_page.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/auth_password_sheet.dart';
import '../widgets/theme_palette_sheet.dart';
import '../widgets/team_info_sheet.dart';
import '../widgets/vice_permissions_sheet.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  static const Duration _initialAccessOverlayTimeout = Duration(milliseconds: 1500);

  int selectedIndex = 0;
  bool _hasAutoOpenedRecoverySheet = false;
  bool _isInitialAccessOverlayActive = true;
  Timer? _initialAccessOverlayTimer;

  @override
  void initState() {
    super.initState();
    _initialAccessOverlayTimer = Timer(_initialAccessOverlayTimeout, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitialAccessOverlayActive = false;
      });
    });
  }

  @override
  void dispose() {
    _initialAccessOverlayTimer?.cancel();
    super.dispose();
  }

  void _goToTab(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Future<void> _openCreateProfile() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PlayerFormPage(
          selfRegistration: true,
        ),
      ),
    );
  }

  Future<void> _openAuthSheet(AuthSheetMode initialMode) async {
    final session = AppSessionScope.read(context);

    if (session.isAuthenticated) {
      return;
    }

    if (session.isLoading) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stiamo verificando la sessione. Attendi un attimo.'),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AuthSheet(
        initialMode: initialMode,
      ),
    );

    if (result != true || !mounted) {
      return;
    }

    await AppSessionScope.read(context).refresh(showLoadingState: false);
  }

  bool _showInitialAccessOverlay(AppSessionController session) {
    return _isInitialAccessOverlayActive && session.isLoading;
  }

  Widget _wrapHomeWithInitialOverlay({
    required Widget child,
    required AppSessionController session,
  }) {
    if (!_showInitialAccessOverlay(session)) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: AbsorbPointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.22),
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 22),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text('Verifica accesso in corso...'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPasswordSheet({
    bool isRecoveryFlow = false,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AuthPasswordSheet(
        mode: AuthPasswordSheetMode.changePassword,
        isRecoveryFlow: isRecoveryFlow,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );
  }

  void _maybeOpenRecoverySheet(AppSessionController session) {
    if (!session.requiresPasswordRecovery) {
      _hasAutoOpenedRecoverySheet = false;
      return;
    }

    if (_hasAutoOpenedRecoverySheet) {
      return;
    }

    _hasAutoOpenedRecoverySheet = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _openPasswordSheet(isRecoveryFlow: true);
    });
  }

  Future<void> _openThemeSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ThemePaletteSheet(),
    );
  }

  Future<void> _openVicePermissionsSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const VicePermissionsSheet(),
    );
  }

  Future<void> _openTeamInfoSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TeamInfoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    _maybeOpenRecoverySheet(session);
    final pages = [
      HomePage(
        onOpenCreateProfile: _openCreateProfile,
        onOpenSignIn: () => _openAuthSheet(AuthSheetMode.signIn),
        onOpenSignUp: () => _openAuthSheet(AuthSheetMode.signUp),
        onOpenPasswordSettings: () => _openPasswordSheet(
          isRecoveryFlow: session.requiresPasswordRecovery,
        ),
        onOpenThemeSettings: _openThemeSettings,
        onOpenVicePermissionsSettings: _openVicePermissionsSettings,
        onOpenTeamInfoSettings: _openTeamInfoSettings,
      ),
      const PlayersPage(),
      const LineupsPage(),
      const StreamsPage(),
      const AttendancePage(),
    ];

    if (!session.isAuthenticated || session.needsProfileSetup) {
      return Scaffold(
        body: _wrapHomeWithInitialOverlay(
          child: pages.first,
          session: session,
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        height: AppResponsive.isCompact(context) ? 74 : null,
        selectedIndex: selectedIndex,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_2_outlined),
            selectedIcon: Icon(Icons.groups_2),
            label: 'Rosa',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Formazioni',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_display_outlined),
            selectedIcon: Icon(Icons.smart_display),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available),
            label: 'Presenze',
          ),
        ],
      ),
    );
  }
}
