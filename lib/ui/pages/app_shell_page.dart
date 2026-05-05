import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_session_gate.dart';
import '../../core/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/auth_password_sheet.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/biometric_unlock_sheet.dart';
import '../widgets/club_info_sheet.dart';
import '../widgets/clubline_brand_logo.dart';
import '../widgets/notifications_bell_button.dart';
import '../widgets/theme_palette_sheet.dart';
import '../widgets/vice_permissions_sheet.dart';
import 'attendance_page.dart';
import 'club_access_hub_page.dart';
import 'club_management_page.dart';
import 'home_page.dart';
import 'lineups_page.dart';
import 'player_form_page.dart';
import 'players_page.dart';
import 'streams_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int selectedIndex = 0;
  bool _hasAutoOpenedRecoverySheet = false;
  final Map<int, Widget> _cachedClubPages = <int, Widget>{};
  final Set<int> _visitedClubTabs = <int>{0};
  String? _lastClubShellCacheKey;

  void _goToTab(int index) {
    setState(() {
      selectedIndex = index;
      _visitedClubTabs.add(index);
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

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AuthSheet(initialMode: initialMode),
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

  Future<void> _signOut() async {
    await AppSessionScope.read(context).signOut();
    if (!mounted) {
      return;
    }

    setState(() {
      selectedIndex = 0;
    });
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

  Future<void> _handleDestinationSelected(int index) async {
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
      MaterialPageRoute(builder: (context) => ClubManagementPage()),
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

    return AppBottomSafeAreaBar(
      backgroundColor: navigationBackground,
      padding: EdgeInsets.zero,
      child: NavigationBar(
        height: AppResponsive.isCompact(context) ? 74 : null,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          unawaited(_handleDestinationSelected(index));
        },
        destinations: _bottomDestinations(),
      ),
    );
  }

  Widget _buildAuthenticatedPageAt(int index) {
    switch (index) {
      case 0:
        return HomePage(
          key: const PageStorageKey<String>('club-home-page'),
          onOpenCreateProfile: _openCreateProfile,
          onOpenEditCurrentProfile: _openEditCurrentProfile,
          onOpenSignIn: () => _openAuthSheet(AuthSheetMode.signIn),
          onOpenSignUp: () => _openAuthSheet(AuthSheetMode.signUp),
          onOpenPasswordSettings: () => _openPasswordSheet(
            isRecoveryFlow: AppSessionScope.read(
              context,
            ).requiresPasswordRecovery,
          ),
          onOpenBiometricSettings: _openBiometricSettings,
          onOpenClubManagement: _openClubManagement,
          onOpenThemeSettings: _openThemeSettings,
          onOpenVicePermissionsSettings: _openVicePermissionsSettings,
          onOpenClubInfoSettings: _openClubInfoSettings,
          onDeleteAccount: _deleteAccount,
        );
      case 1:
        return const PlayersPage(
          key: PageStorageKey<String>('club-players-page'),
        );
      case 2:
        return const LineupsPage(
          key: PageStorageKey<String>('club-lineups-page'),
        );
      case 3:
        return const StreamsPage(
          key: PageStorageKey<String>('club-streams-page'),
        );
      case 4:
        return const AttendancePage(
          key: PageStorageKey<String>('club-attendance-page'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildClubShell(BuildContext context, AppSessionController session) {
    final pages = List<Widget>.generate(5, (index) {
      final shouldInstantiate =
          _visitedClubTabs.contains(index) || selectedIndex == index;
      if (!shouldInstantiate) {
        return SizedBox(key: ValueKey<String>('club-tab-placeholder-$index'));
      }

      return _cachedClubPages.putIfAbsent(
        index,
        () => _buildAuthenticatedPageAt(index),
      );
    });
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
                            tone: AppStatusTone.info,
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

  void _resetSelectedIndexIfNeeded(AppSessionGateKind gateKind) {
    if (gateKind == AppSessionGateKind.authenticatedWithClub ||
        selectedIndex == 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        selectedIndex = 0;
      });
    });
  }

  void _syncClubPageCache(
    AppSessionController session,
    AppSessionGateKind gateKind,
  ) {
    final nextCacheKey = gateKind == AppSessionGateKind.authenticatedWithClub
        ? '${session.currentClub?.id}:${session.currentUser?.id}'
        : null;
    if (_lastClubShellCacheKey == nextCacheKey) {
      return;
    }

    _lastClubShellCacheKey = nextCacheKey;
    _cachedClubPages.clear();
    _visitedClubTabs
      ..clear()
      ..add(0);
    selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final gateKind = session.sessionGateKind;
    _syncClubPageCache(session, gateKind);
    _resetSelectedIndexIfNeeded(gateKind);

    if (gateKind != AppSessionGateKind.resolving &&
        gateKind != AppSessionGateKind.error &&
        session.isAuthenticated) {
      _maybeOpenRecoverySheet(session);
    }

    switch (gateKind) {
      case AppSessionGateKind.resolving:
        return _SessionResolutionPage(session: session);
      case AppSessionGateKind.error:
        return _SessionResolutionErrorPage(
          session: session,
          onRetry: session.retrySessionResolution,
          onSignOut: session.isAuthenticated ? _signOut : null,
        );
      case AppSessionGateKind.unauthenticated:
        return _buildAuthenticatedPageAt(0);
      case AppSessionGateKind.authenticatedNeedsPlayerProfile:
        return _PlayerProfileSetupGatePage(
          session: session,
          onOpenPlayerSetup: _openCreateProfile,
          onDeleteAccount: _deleteAccount,
          onSignOut: _signOut,
        );
      case AppSessionGateKind.authenticatedNeedsClubSelection:
        return ClubAccessHubPage(
          onOpenPlayerSetup: _openCreateProfile,
          onDeleteAccount: _deleteAccount,
        );
      case AppSessionGateKind.authenticatedWithClub:
        return _buildClubShell(context, session);
    }
  }
}

enum _ProfileGateMenuAction { deleteAccount, signOut }

class _SessionResolutionPage extends StatelessWidget {
  const _SessionResolutionPage({required this.session});

  final AppSessionController session;

  String get _title {
    switch (session.resolutionTrigger) {
      case AppSessionResolutionTrigger.signIn:
        return 'Accesso in corso...';
      case AppSessionResolutionTrigger.signUp:
        return 'Creazione account in corso...';
      case AppSessionResolutionTrigger.retry:
        return 'Nuovo tentativo in corso...';
      case AppSessionResolutionTrigger.bootstrap:
      case AppSessionResolutionTrigger.refresh:
        return 'Verifica accesso in corso...';
    }
  }

  String get _subtitle {
    switch (session.resolutionPhase) {
      case AppSessionResolutionPhase.restoringSession:
      case AppSessionResolutionPhase.fetchingSessionState:
        return 'Stiamo verificando sessione, profilo e stato del club. Se il backend si sta riattivando potrebbero volerci alcuni secondi.';
      case AppSessionResolutionPhase.idle:
        return 'Ultimo controllo in corso.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      wide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeroPanel(
            eyebrow: 'Sessione',
            title: _title,
            subtitle: _subtitle,
            media: const ClublineBrandLogo(width: 188),
            badges: [
              if ((session.currentUserEmail ?? '').isNotEmpty)
                AppStatusBadge(
                  label: session.currentUserEmail!,
                  tone: AppStatusTone.info,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppSurfaceCard(
            icon: Icons.sync_outlined,
            title: 'Sincronizzazione in corso',
            subtitle:
                'Una sola transizione controllata fino allo stato finale.',
            child: AppLoadingState(label: 'Attendi ancora un momento...'),
          ),
        ],
      ),
    );
  }
}

class _SessionResolutionErrorPage extends StatelessWidget {
  const _SessionResolutionErrorPage({
    required this.session,
    required this.onRetry,
    this.onSignOut,
  });

  final AppSessionController session;
  final Future<void> Function() onRetry;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      wide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeroPanel(
            eyebrow: 'Sessione',
            title: 'Impossibile completare l accesso',
            subtitle:
                'Non siamo riusciti a confermare sessione, profilo o stato del club. Puoi riprovare senza rifare il login.',
            media: const ClublineBrandLogo(width: 172),
            badges: [
              if ((session.currentUserEmail ?? '').isNotEmpty)
                AppStatusBadge(
                  label: session.currentUserEmail!,
                  tone: AppStatusTone.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppErrorState(
            title: 'Sessione non risolta',
            message:
                session.sessionGateErrorMessage ??
                'Errore sconosciuto durante la verifica della sessione.',
            actionLabel: 'Riprova',
            onAction: () {
              unawaited(onRetry());
            },
          ),
          if (onSignOut != null) ...[
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  unawaited(onSignOut!.call());
                },
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Esci e torna alla Home'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerProfileSetupGatePage extends StatelessWidget {
  const _PlayerProfileSetupGatePage({
    required this.session,
    required this.onOpenPlayerSetup,
    required this.onDeleteAccount,
    required this.onSignOut,
  });

  final AppSessionController session;
  final Future<void> Function() onOpenPlayerSetup;
  final Future<void> Function() onDeleteAccount;
  final Future<void> Function() onSignOut;

  String get _title {
    if (session.hasClubMembership) {
      return session.currentUser == null
          ? 'Collega il tuo giocatore al club'
          : 'Completa il profilo giocatore';
    }

    return 'Prima crea il tuo giocatore';
  }

  String get _subtitle {
    if (session.hasClubMembership) {
      final clubName = session.clubInfo.displayClubName;
      return session.currentUser == null
          ? 'Accesso confermato. Per entrare davvero in $clubName manca ancora il profilo giocatore collegato al tuo account.'
          : 'Sei gia in $clubName. Completa i dati mancanti per rendere stabile l accesso e sbloccare tutte le aree.';
    }

    return 'Prima di creare o cercare un club serve un profilo giocatore completo. Lo useremo poi in tutti i flussi successivi.';
  }

  String get _actionLabel {
    return session.currentUser == null ? 'Crea giocatore' : 'Completa profilo';
  }

  String get _statusLabel {
    if (session.hasClubMembership) {
      return session.currentUser == null
          ? 'Profilo da collegare'
          : 'Profilo da completare';
    }

    return 'Giocatore da creare';
  }

  Future<void> _handleMenuAction(_ProfileGateMenuAction action) async {
    switch (action) {
      case _ProfileGateMenuAction.deleteAccount:
        await onDeleteAccount();
        return;
      case _ProfileGateMenuAction.signOut:
        await onSignOut();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Clubline'),
        actions: [
          const NotificationsBellButton(),
          PopupMenuButton<_ProfileGateMenuAction>(
            tooltip: 'Menu account',
            icon: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person_outline, size: 18),
            ),
            onSelected: (action) {
              unawaited(_handleMenuAction(action));
            },
            itemBuilder: (_) => const [
              PopupMenuItem<_ProfileGateMenuAction>(
                value: _ProfileGateMenuAction.deleteAccount,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_outlined),
                  title: Text('Cancella account'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<_ProfileGateMenuAction>(
                value: _ProfileGateMenuAction.signOut,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_outlined),
                  title: Text('Esci'),
                ),
              ),
            ],
          ),
        ],
      ),
      wide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeroPanel(
            eyebrow: session.hasClubMembership ? 'Profilo club' : 'Onboarding',
            title: _title,
            subtitle: _subtitle,
            media: Center(
              child: session.hasClubMembership
                  ? ClublineBrandLogo(
                      width: AppResponsive.isCompact(context) ? 152 : 196,
                    )
                  : ClublineBrandLogo(
                      width: AppResponsive.isCompact(context) ? 176 : 220,
                    ),
            ),
            badges: [
              if ((session.currentUserEmail ?? '').isNotEmpty)
                AppStatusBadge(
                  label: session.currentUserEmail!,
                  tone: AppStatusTone.info,
                ),
              AppStatusBadge(label: _statusLabel, tone: AppStatusTone.warning),
            ],
            actions: [
              AppActionButton(
                label: _actionLabel,
                icon: Icons.person_add_alt_1_outlined,
                expand: AppResponsive.isCompact(context),
                onPressed: () {
                  unawaited(onOpenPlayerSetup());
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppResponsiveGrid(
            minChildWidth: 280,
            children: [
              AppFeatureCard(
                icon: Icons.person_outline,
                title: 'Profilo richiesto',
                message: session.hasClubMembership
                    ? 'Finche il profilo giocatore non e completo non renderizziamo le aree finali del club, evitando schermate intermedie instabili.'
                    : 'Completa nome, cognome, ID console, maglia e ruolo una sola volta. Poi potrai creare un club o chiedere di entrare in una squadra.',
                actionLabel: _actionLabel,
                onAction: () {
                  unawaited(onOpenPlayerSetup());
                },
                emphasized: true,
              ),
              AppSurfaceCard(
                icon: Icons.verified_user_outlined,
                title: 'Accesso gia confermato',
                subtitle:
                    'L autenticazione e valida. Ora stiamo solo aspettando il profilo corretto prima di sbloccare il resto.',
                child: AppDetailsList(
                  items: [
                    AppDetailItem(
                      label: 'Email',
                      value: session.currentUserEmail ?? '-',
                      emphasized: true,
                    ),
                    AppDetailItem(
                      label: 'Club',
                      value: session.hasClubMembership
                          ? session.clubInfo.displayClubName
                          : 'Nessun club attivo',
                    ),
                    AppDetailItem(
                      label: 'Stato',
                      value: _statusLabel,
                      icon: Icons.hourglass_top_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
