import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../widgets/app_chrome.dart';
import 'attendance_page.dart';
import 'club_access_hub_page.dart';
import 'club_management_page.dart';
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
  static const Duration _initialAccessOverlayTimeout = Duration(
    milliseconds: 1500,
  );
  static const Duration _postVerificationGuardDuration = Duration(
    milliseconds: 1000,
  );
  static const Duration _accessConfirmedLabelLeadTime = Duration(
    milliseconds: 300,
  );
  static const Duration _initialAccessTransitionDuration = Duration(
    milliseconds: 420,
  );

  int selectedIndex = 0;
  bool _hasAutoOpenedRecoverySheet = false;
  bool _isInitialAccessOverlayActive = true;
  bool _isPostVerificationGuardActive = true;
  bool _showAccessConfirmedLabel = false;
  Timer? _initialAccessOverlayTimer;
  Timer? _postVerificationGuardTimer;
  Timer? _accessConfirmedLabelTimer;

  @override
  void initState() {
    super.initState();
    _initialAccessOverlayTimer = Timer(_initialAccessOverlayTimeout, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitialAccessOverlayActive = false;
        _showAccessConfirmedLabel = false;
      });

      final accessConfirmedDelay =
          _postVerificationGuardDuration - _accessConfirmedLabelLeadTime;
      _accessConfirmedLabelTimer = Timer(accessConfirmedDelay, () {
        if (!mounted) {
          return;
        }

        setState(() {
          _showAccessConfirmedLabel = true;
        });
      });

      _postVerificationGuardTimer = Timer(_postVerificationGuardDuration, () {
        if (!mounted) {
          return;
        }

        setState(() {
          _isPostVerificationGuardActive = false;
          _showAccessConfirmedLabel = false;
        });
      });
    });
  }

  @override
  void dispose() {
    _initialAccessOverlayTimer?.cancel();
    _postVerificationGuardTimer?.cancel();
    _accessConfirmedLabelTimer?.cancel();
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
        builder: (context) => const PlayerFormPage(selfRegistration: true),
      ),
    );
  }

  Future<void> _openEditCurrentProfile() async {
    final session = AppSessionScope.read(context);
    final currentUser = session.currentUser;
    if (currentUser == null) {
      await _openCreateProfile();
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerFormPage(player: currentUser),
      ),
    );
  }

  Future<void> _openAuthSheet(AuthSheetMode initialMode) async {
    final session = AppSessionScope.read(context);

    if (session.isAuthenticated) {
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AuthSheet(initialMode: initialMode),
    );

    if (result != true || !mounted) {
      return;
    }

    await AppSessionScope.read(context).refresh(showLoadingState: false);
  }

  bool _showInitialAccessOverlay(AppSessionController session) {
    return _isInitialAccessOverlayActive && session.isLoading;
  }

  bool _showSyncProfileOverlay(AppSessionController session) {
    if (_showInitialAccessOverlay(session)) {
      return false;
    }

    if (_isPostVerificationGuardActive && session.isAuthenticated) {
      return true;
    }

    return false;
  }

  Widget _wrapHomeWithInitialOverlay({
    required Widget child,
    required AppSessionController session,
  }) {
    if (!session.isAuthenticated) {
      return child;
    }

    final showInitialOverlay = _showInitialAccessOverlay(session);
    final showSyncOverlay = _showSyncProfileOverlay(session);
    final overlayVisible = showInitialOverlay || showSyncOverlay;
    final overlayMessage = showInitialOverlay
        ? 'Verifica accesso in corso...'
        : _showAccessConfirmedLabel && session.isAuthenticated
        ? 'Accesso confermato'
        : 'Sincronizzazione profilo...';
    final shouldBlockTouches = overlayVisible && session.isAuthenticated;
    final overlayBackgroundAlpha = showInitialOverlay ? 0.22 : 0.14;
    final panelPadding = showInitialOverlay
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    final spinnerSize = showInitialOverlay ? 18.0 : 14.0;

    return Stack(
      children: [
        AnimatedSlide(
          duration: _initialAccessTransitionDuration,
          curve: Curves.easeOutCubic,
          offset: overlayVisible ? const Offset(0, 0.018) : Offset.zero,
          child: AnimatedOpacity(
            duration: _initialAccessTransitionDuration,
            curve: Curves.easeOutCubic,
            opacity: overlayVisible ? 0.92 : 1,
            child: child,
          ),
        ),
        if (overlayVisible)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !shouldBlockTouches,
              child: AnimatedOpacity(
                duration: _initialAccessTransitionDuration,
                curve: Curves.easeOutCubic,
                opacity: 1,
                child: Container(
                  color: Colors.black.withValues(alpha: overlayBackgroundAlpha),
                  alignment: Alignment.center,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    padding: panelPadding,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: spinnerSize,
                          height: spinnerSize,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(child: Text(overlayMessage)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openPasswordSheet({bool isRecoveryFlow = false}) async {
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

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
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
    final session = AppSessionScope.read(context);
    if (!session.hasClubMembership) {
      return;
    }

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

  Future<void> _openClubManagement() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => const ClubManagementPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    _maybeOpenRecoverySheet(session);
    final pages = [
      HomePage(
        onOpenCreateProfile: _openCreateProfile,
        onOpenEditCurrentProfile: _openEditCurrentProfile,
        onOpenSignIn: () => _openAuthSheet(AuthSheetMode.signIn),
        onOpenSignUp: () => _openAuthSheet(AuthSheetMode.signUp),
        onOpenPasswordSettings: () => _openPasswordSheet(
          isRecoveryFlow: session.requiresPasswordRecovery,
        ),
        onOpenClubManagement: _openClubManagement,
        onOpenThemeSettings: _openThemeSettings,
        onOpenVicePermissionsSettings: _openVicePermissionsSettings,
        onOpenTeamInfoSettings: _openTeamInfoSettings,
      ),
      const PlayersPage(),
      const LineupsPage(),
      const StreamsPage(),
      const AttendancePage(),
    ];

    if (!session.isAuthenticated) {
      return Scaffold(
        body: _wrapHomeWithInitialOverlay(child: pages.first, session: session),
      );
    }

    if (!session.hasClubMembership) {
      return const ClubAccessHubPage();
    }

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
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
