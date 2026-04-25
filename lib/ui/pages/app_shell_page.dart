import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
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
import '../widgets/biometric_unlock_sheet.dart';
import '../widgets/auth_password_sheet.dart';
import '../widgets/clubline_brand_logo.dart';
import '../widgets/theme_palette_sheet.dart';
import '../widgets/club_info_sheet.dart';
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
  bool _hasAutoOpenedProfileCompletion = false;
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
    final session = AppSessionScope.read(context);
    final currentUser = session.currentUser;
    final requiresDraftOnly = !session.hasClubMembership;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => requiresDraftOnly
            ? const PlayerFormPage(draftOnly: true)
            : currentUser == null
            ? const PlayerFormPage(selfRegistration: true)
            : PlayerFormPage(player: currentUser),
      ),
    );

    if (updated == true && mounted) {
      await session.refresh(showLoadingState: false);
    }
  }

  Future<void> _openEditCurrentProfile() async {
    final session = AppSessionScope.read(context);
    if (!session.hasClubMembership) {
      await _openCreateProfile();
      return;
    }

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

  Future<void> _deleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancella account'),
        content: const Text(
          'Questa azione elimina il tuo accesso a Clubline. Se fai ancora parte di un club o hai una richiesta di ingresso pendente, dovrai prima chiudere quei flussi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancella account'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppSessionScope.read(context).deleteAccount();
      if (!mounted) {
        return;
      }

      setState(() {
        selectedIndex = 0;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Account eliminato correttamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
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

  void _maybeOpenProfileCompletion(AppSessionController session) {
    if (!session.needsProfileSetup) {
      _hasAutoOpenedProfileCompletion = false;
      return;
    }

    if (selectedIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        setState(() {
          selectedIndex = 0;
        });
      });
    }

    if (_hasAutoOpenedProfileCompletion) {
      return;
    }

    _hasAutoOpenedProfileCompletion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_openCreateProfile());
    });
  }

  Future<void> _handleDestinationSelected(int index) async {
    final session = AppSessionScope.read(context);
    if (session.needsProfileSetup && index != 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa prima il profilo giocatore per sbloccare il resto dell app.',
            ),
          ),
        );
      }
      await _openCreateProfile();
      return;
    }

    _goToTab(index);
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

  Future<void> _openBiometricSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const BiometricUnlockSheet(),
    );
  }

  Future<void> _openVicePermissionsSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const VicePermissionsSheet(),
    );
  }

  Future<void> _openClubInfoSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ClubInfoSheet(),
    );
  }

  Future<void> _openClubManagement() async {
    final deletedClub = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const ClubManagementPage()),
    );

    if (deletedClub == true && mounted) {
      setState(() {
        selectedIndex = 0;
      });
    }
  }

  List<NavigationDestination> _bottomDestinations() {
    return const [
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
    ];
  }

  List<NavigationRailDestination> _railDestinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text('Home'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.groups_2_outlined),
        selectedIcon: Icon(Icons.groups_2),
        label: Text('Rosa'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: Text('Formazioni'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.smart_display_outlined),
        selectedIcon: Icon(Icons.smart_display),
        label: Text('Live'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.event_available_outlined),
        selectedIcon: Icon(Icons.event_available),
        label: Text('Presenze'),
      ),
    ];
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    final navigationBackground =
        theme.navigationBarTheme.backgroundColor ?? theme.colorScheme.surface;

    return ColoredBox(
      color: navigationBackground,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        maintainBottomViewPadding: true,
        child: NavigationBar(
          height: AppResponsive.isCompact(context) ? 74 : null,
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            unawaited(_handleDestinationSelected(index));
          },
          destinations: _bottomDestinations(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    _maybeOpenRecoverySheet(session);
    _maybeOpenProfileCompletion(session);
    final pages = [
      HomePage(
        onOpenCreateProfile: _openCreateProfile,
        onOpenEditCurrentProfile: _openEditCurrentProfile,
        onOpenSignIn: () => _openAuthSheet(AuthSheetMode.signIn),
        onOpenSignUp: () => _openAuthSheet(AuthSheetMode.signUp),
        onOpenPasswordSettings: () => _openPasswordSheet(
          isRecoveryFlow: session.requiresPasswordRecovery,
        ),
        onOpenBiometricSettings: _openBiometricSettings,
        onOpenClubManagement: _openClubManagement,
        onOpenThemeSettings: _openThemeSettings,
        onOpenVicePermissionsSettings: _openVicePermissionsSettings,
        onOpenClubInfoSettings: _openClubInfoSettings,
        onDeleteAccount: _deleteAccount,
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
      return ClubAccessHubPage(
        onOpenPlayerSetup: _openCreateProfile,
        onDeleteAccount: _deleteAccount,
      );
    }

    final useRail = AppResponsive.useNavigationRail(context);

    if (!useRail) {
      return Scaffold(
        body: IndexedStack(index: selectedIndex, children: pages),
        bottomNavigationBar: _buildBottomNavigationBar(context),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: AppResponsive.isDesktop(context) ? 124 : 108,
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: ClublineAppTheme.surfaceAlt.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: ClublineAppTheme.outlineSoft),
                      ),
                      child: Column(
                        children: [
                          const ClublineBrandLogo(width: 76),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            session.clubInfo.displayClubName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppStatusBadge(
                            label:
                                session.currentUser?.teamRoleDisplay ??
                                'Club attivo',
                            tone: session.needsProfileSetup
                                ? AppStatusTone.warning
                                : AppStatusTone.info,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: NavigationRail(
                      selectedIndex: selectedIndex,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (index) {
                        unawaited(_handleDestinationSelected(index));
                      },
                      destinations: _railDestinations(),
                    ),
                  ),
                  if (session.needsProfileSetup)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        0,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      child: AppActionButton(
                        label: 'Profilo',
                        icon: Icons.person_outline,
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        onPressed: () {
                          unawaited(_openCreateProfile());
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: IndexedStack(index: selectedIndex, children: pages),
          ),
        ],
      ),
    );
  }
}
