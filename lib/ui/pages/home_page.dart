import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/club_repository.dart';
import '../../models/player_profile.dart';
import '../../models/club_info.dart';
import '../widgets/app_chrome.dart';
import '../widgets/clubline_brand_logo.dart';
import '../widgets/club_logo_avatar.dart';

enum _HomeProfileMenuAction {
  completeProfile,
  editProfile,
  changePassword,
  biometricUnlock,
  manageClub,
  requestLeaveClub,
  manageVicePermissions,
  deleteAccount,
  signOut,
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenCreateProfile,
    required this.onOpenEditCurrentProfile,
    required this.onOpenSignIn,
    required this.onOpenSignUp,
    required this.onOpenPasswordSettings,
    required this.onOpenBiometricSettings,
    required this.onOpenClubManagement,
    required this.onOpenThemeSettings,
    required this.onOpenVicePermissionsSettings,
    required this.onOpenClubInfoSettings,
    required this.onDeleteAccount,
  });

  final VoidCallback onOpenCreateProfile;
  final VoidCallback onOpenEditCurrentProfile;
  final VoidCallback onOpenSignIn;
  final VoidCallback onOpenSignUp;
  final VoidCallback onOpenPasswordSettings;
  final VoidCallback onOpenBiometricSettings;
  final VoidCallback onOpenClubManagement;
  final VoidCallback onOpenThemeSettings;
  final VoidCallback onOpenVicePermissionsSettings;
  final VoidCallback onOpenClubInfoSettings;
  final Future<void> Function() onDeleteAccount;

  static final ClubRepository _clubRepository = ClubRepository();

  Future<void> _openExternalLink(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link non valido')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il link')),
      );
    }
  }

  Future<void> _signOut(
    BuildContext context,
    AppSessionController session,
  ) async {
    await session.signOut();

    if (!context.mounted) {
      return;
    }

    await AppSessionScope.read(context).refresh();
  }

  Future<void> _handleProfileMenuAction(
    BuildContext context,
    AppSessionController session,
    _HomeProfileMenuAction action,
  ) async {
    switch (action) {
      case _HomeProfileMenuAction.completeProfile:
        onOpenCreateProfile();
        return;
      case _HomeProfileMenuAction.editProfile:
        onOpenEditCurrentProfile();
        return;
      case _HomeProfileMenuAction.changePassword:
        onOpenPasswordSettings();
        return;
      case _HomeProfileMenuAction.biometricUnlock:
        onOpenBiometricSettings();
        return;
      case _HomeProfileMenuAction.manageClub:
        onOpenClubManagement();
        return;
      case _HomeProfileMenuAction.requestLeaveClub:
        await _requestLeaveClub(context, session);
        return;
      case _HomeProfileMenuAction.manageVicePermissions:
        onOpenVicePermissionsSettings();
        return;
      case _HomeProfileMenuAction.deleteAccount:
        await onDeleteAccount();
        return;
      case _HomeProfileMenuAction.signOut:
        await _signOut(context, session);
        return;
    }
  }

  Future<void> _requestLeaveClub(
    BuildContext context,
    AppSessionController session,
  ) async {
    try {
      await _clubRepository.requestLeaveClub();
      await session.refresh(showLoadingState: false);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Richiesta di uscita inviata al capitano.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final isAuthenticated = session.isAuthenticated;
    final hasClubMembership = session.hasClubMembership;
    final currentUser = session.currentUser;
    final currentUserEmail = session.currentUserEmail;
    final needsProfileSetup = session.needsProfileSetup;
    final clubInfo = session.clubInfo;
    final canShowProfileMenu = isAuthenticated;
    final canManageVicePermissions =
        currentUser?.isCaptain == true && !needsProfileSetup;
    final isPersonalizedExperience = hasClubMembership;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPersonalizedExperience ? clubInfo.displayClubName : 'Clubline',
        ),
        actions: [
          if (canShowProfileMenu)
            PopupMenuButton<_HomeProfileMenuAction>(
              key: const Key('home-profile-menu-button'),
              tooltip: 'Menu profilo',
              icon: const CircleAvatar(
                radius: 16,
                child: Icon(Icons.person_outline, size: 18),
              ),
              onSelected: (action) =>
                  _handleProfileMenuAction(context, session, action),
              itemBuilder: (_) => [
                if (needsProfileSetup)
                  const PopupMenuItem<_HomeProfileMenuAction>(
                    key: Key('home-profile-menu-complete-player'),
                    value: _HomeProfileMenuAction.completeProfile,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_add_alt_1_outlined),
                      title: Text('Completa Profilo giocatore'),
                    ),
                  )
                else if (currentUser != null)
                  const PopupMenuItem<_HomeProfileMenuAction>(
                    key: Key('home-profile-menu-edit-player'),
                    value: _HomeProfileMenuAction.editProfile,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Modifica profilo giocatore'),
                    ),
                  ),
                const PopupMenuItem<_HomeProfileMenuAction>(
                  key: Key('home-profile-menu-biometric-unlock'),
                  value: _HomeProfileMenuAction.biometricUnlock,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.fingerprint_outlined),
                    title: Text('Sblocco biometrico'),
                  ),
                ),
                const PopupMenuItem<_HomeProfileMenuAction>(
                  key: Key('home-profile-menu-change-password'),
                  value: _HomeProfileMenuAction.changePassword,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.password_outlined),
                    title: Text('Cambia password'),
                  ),
                ),
                if (currentUser?.isCaptain == true)
                  if (!needsProfileSetup)
                    const PopupMenuItem<_HomeProfileMenuAction>(
                      value: _HomeProfileMenuAction.manageClub,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.admin_panel_settings_outlined),
                        title: Text('Dashboard capitano'),
                      ),
                    ),
                if (currentUser != null && currentUser.isCaptain != true)
                  if (!needsProfileSetup)
                    const PopupMenuItem<_HomeProfileMenuAction>(
                      value: _HomeProfileMenuAction.requestLeaveClub,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.exit_to_app_outlined),
                        title: Text('Richiedi uscita club'),
                      ),
                    ),
                if (canManageVicePermissions)
                  const PopupMenuItem<_HomeProfileMenuAction>(
                    key: Key('home-profile-menu-manage-vice-permissions'),
                    value: _HomeProfileMenuAction.manageVicePermissions,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.admin_panel_settings_outlined),
                      title: Text('Gestione permessi vice'),
                    ),
                  ),
                const PopupMenuItem<_HomeProfileMenuAction>(
                  key: Key('home-profile-menu-delete-account'),
                  value: _HomeProfileMenuAction.deleteAccount,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_forever_outlined),
                    title: Text('Cancella account'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<_HomeProfileMenuAction>(
                  key: Key('home-profile-menu-sign-out'),
                  value: _HomeProfileMenuAction.signOut,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout_outlined),
                    title: Text('Esci'),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          const AppPageBackground(child: SizedBox.expand()),
          Positioned(
            top: -120,
            right: -70,
            child: _GlowCircle(
              size: 260,
              color: ClublineAppTheme.outlineStrong,
            ),
          ),
          Positioned(
            left: -90,
            bottom: 60,
            child: _GlowCircle(
              size: 220,
              color: ClublineAppTheme.goldSoft.withValues(alpha: 0.16),
            ),
          ),
          SafeArea(
            child: AppContentFrame(
              wide: true,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppResponsive.horizontalPadding(context),
                  AppResponsive.isCompact(context) ? 8 : 12,
                  AppResponsive.horizontalPadding(context),
                  AppResponsive.isCompact(context) ? 18 : 28,
                ),
                child: AppAdaptiveColumns(
                  breakpoint: 1080,
                  gap: AppResponsive.sectionGap(context),
                  flex: const [3, 2],
                  children: [
                    _HomeWelcomeCard(
                      clubInfo: clubInfo,
                      currentUser: currentUser,
                      isAuthenticated: isAuthenticated,
                      isPersonalizedExperience: isPersonalizedExperience,
                      currentUserEmail: currentUserEmail,
                      needsProfileSetup: needsProfileSetup,
                      onOpenCreateProfile: onOpenCreateProfile,
                      onOpenClubManagement: onOpenClubManagement,
                      onOpenThemeSettings:
                          isPersonalizedExperience && !needsProfileSetup
                          ? onOpenThemeSettings
                          : null,
                      onOpenClubInfoSettings:
                          currentUser?.canManageClubInfo == true &&
                              !needsProfileSetup
                          ? onOpenClubInfoSettings
                          : null,
                      onOpenLink: (url) => _openExternalLink(context, url),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (currentUser != null &&
                            !needsProfileSetup &&
                            (currentUser.isCaptain ||
                                session.hasPendingLeaveRequest ||
                                session.captainPendingJoinRequests.isNotEmpty ||
                                session
                                    .captainPendingLeaveRequests
                                    .isNotEmpty)) ...[
                          _ClubPulseCard(
                            currentUser: currentUser,
                            session: session,
                            onOpenClubManagement: onOpenClubManagement,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        _AccessCard(
                          isAuthenticated: isAuthenticated,
                          currentUser: currentUser,
                          currentUserEmail: currentUserEmail,
                          needsProfileSetup: needsProfileSetup,
                          requiresPasswordRecovery:
                              session.requiresPasswordRecovery,
                          isCaptainRegistrationOpen:
                              session.isCaptainRegistrationOpen,
                          errorMessage: session.errorMessage,
                          onCreateProfile: onOpenCreateProfile,
                          onOpenSignIn: onOpenSignIn,
                          onOpenSignUp: onOpenSignUp,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _ClubPulseCard extends StatelessWidget {
  const _ClubPulseCard({
    required this.currentUser,
    required this.session,
    required this.onOpenClubManagement,
  });

  final PlayerProfile currentUser;
  final AppSessionController session;
  final VoidCallback onOpenClubManagement;

  @override
  Widget build(BuildContext context) {
    final pendingJoin = session.captainPendingJoinRequests.length;
    final pendingLeave = session.captainPendingLeaveRequests.length;
    final isCaptain = currentUser.isCaptain;
    final compact = AppResponsive.isCompact(context);
    final pendingTotal = pendingJoin + pendingLeave;

    final title = isCaptain
        ? pendingTotal == 0
              ? 'Dashboard capitano'
              : '$pendingTotal richieste da gestire'
        : session.hasPendingLeaveRequest
        ? 'Uscita inviata'
        : 'Club attivo';
    final message = isCaptain
        ? pendingTotal == 0
              ? 'Hai tutto sotto controllo. Apri la dashboard per richieste, vice e impostazioni club.'
              : '$pendingJoin ingressi e $pendingLeave uscite aspettano la tua decisione.'
        : 'La richiesta di uscita e in attesa della decisione del capitano.';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(
          compact
              ? AppResponsive.cardPadding(context) - 2
              : AppResponsive.cardPadding(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBadge(
                  icon: isCaptain
                      ? Icons.admin_panel_settings_outlined
                      : Icons.hourglass_top_outlined,
                  size: compact ? 52 : 58,
                  iconSize: compact ? 20 : 22,
                  borderRadius: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCaptain && pendingTotal > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: AppStatusBadge(
                            label: 'Da approvare',
                            tone: AppStatusTone.warning,
                          ),
                        ),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ClublineAppTheme.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isCaptain) ...[
              const SizedBox(height: AppSpacing.sm),
              AppActionButton(
                label: 'Vai alla dashboard capitano',
                icon: Icons.arrow_forward_outlined,
                variant: AppButtonVariant.primary,
                expand: true,
                onPressed: onOpenClubManagement,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeWelcomeCard extends StatelessWidget {
  const _HomeWelcomeCard({
    required this.clubInfo,
    required this.currentUser,
    required this.isAuthenticated,
    required this.isPersonalizedExperience,
    required this.currentUserEmail,
    required this.needsProfileSetup,
    required this.onOpenCreateProfile,
    required this.onOpenClubManagement,
    required this.onOpenThemeSettings,
    required this.onOpenClubInfoSettings,
    required this.onOpenLink,
  });

  final ClubInfo clubInfo;
  final PlayerProfile? currentUser;
  final bool isAuthenticated;
  final bool isPersonalizedExperience;
  final String? currentUserEmail;
  final bool needsProfileSetup;
  final VoidCallback onOpenCreateProfile;
  final VoidCallback onOpenClubManagement;
  final VoidCallback? onOpenThemeSettings;
  final VoidCallback? onOpenClubInfoSettings;
  final ValueChanged<String> onOpenLink;

  String _welcomeText(bool compact) {
    if (!isAuthenticated) {
      return compact
          ? 'Accedi o registrati, crea il tuo giocatore e poi scegli il club.'
          : 'Crea il tuo account oppure accedi con le tue credenziali. Dopo il login creerai prima il tuo giocatore, poi sceglierai il club. La grafica personalizzata comparira solo dopo l ingresso in squadra.';
    }

    if (needsProfileSetup) {
      if (currentUser != null) {
        return compact
            ? 'Sei gia nel club. Completa il profilo per sbloccare tutte le funzioni.'
            : 'Benvenuto ${currentUser!.fullName}. Sei gia dentro il club, ma per sbloccare Clubline devi completare subito il profilo giocatore.';
      }

      final email = currentUserEmail;
      if (email == null) {
        return compact
            ? 'Sei autenticato, ma manca ancora il profilo collegato.'
            : 'Sei autenticato, ma manca ancora il profilo club collegato.';
      }

      return compact
          ? 'Benvenuto $email. Completa il profilo giocatore per entrare davvero nel club.'
          : 'Benvenuto $email. Prima di usare il club devi completare il profilo giocatore.';
    }

    if (currentUser == null) {
      return compact
          ? 'Accesso completato. Stiamo sincronizzando il profilo club.'
          : 'Accesso completato. Il profilo club verra sincronizzato appena disponibile.';
    }

    return compact
        ? 'Bentornato ${currentUser!.fullName}. ${currentUser!.teamRoleDisplay} attivo.'
        : 'Benvenuto ${currentUser!.fullName}. In questo momento stai usando Clubline come ${currentUser!.teamRoleDisplay.toLowerCase()}.';
  }

  (String, IconData, VoidCallback)? _primaryAction() {
    if (needsProfileSetup) {
      return (
        'Completa profilo',
        Icons.person_add_alt_1_outlined,
        onOpenCreateProfile,
      );
    }

    if (currentUser?.isCaptain == true) {
      return (
        'Vai alla dashboard',
        Icons.admin_panel_settings_outlined,
        onOpenClubManagement,
      );
    }

    return null;
  }

  AppStatusTone _roleTone() {
    if (needsProfileSetup) {
      return AppStatusTone.warning;
    }

    if (currentUser?.isCaptain == true) {
      return AppStatusTone.info;
    }

    if (currentUser?.isViceCaptain == true) {
      return AppStatusTone.success;
    }

    return AppStatusTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final heroCrestUrl = isPersonalizedExperience ? clubInfo.crestUrl : null;
    final showUsefulLinks = isPersonalizedExperience && clubInfo.hasAnyLinks;
    final primaryAction = _primaryAction();
    final visibleLinks = compact
        ? clubInfo.allLinks.take(3).toList(growable: false)
        : clubInfo.allLinks;
    final badges = <Widget>[
      if (isAuthenticated && currentUser != null)
        AppStatusBadge(
          label: currentUser!.teamRoleDisplay,
          tone: _roleTone(),
        ),
      if (needsProfileSetup)
        const AppStatusBadge(
          label: 'Profilo da completare',
          tone: AppStatusTone.warning,
        ),
    ];

    return AppHeroPanel(
      centered: true,
      eyebrow: isPersonalizedExperience ? 'Club attivo' : 'Clubline',
      title: isPersonalizedExperience ? clubInfo.displayClubName : 'Clubline',
      subtitle: _welcomeText(compact),
      badges: badges,
      media: isPersonalizedExperience
          ? ClubLogoAvatar(
              logoUrl: heroCrestUrl,
              size: compact ? 84 : 126,
              fallbackIcon: Icons.shield_outlined,
            )
          : ClublineBrandLogo(width: compact ? 148 : 224),
      actions: [
        if (primaryAction != null)
          AppActionButton(
            label: primaryAction.$1,
            icon: primaryAction.$2,
            variant: AppButtonVariant.primary,
            expand: compact,
            onPressed: primaryAction.$3,
          ),
        if (onOpenThemeSettings != null)
          AppActionButton(
            label: compact ? 'Aspetto' : 'Personalizza club',
            icon: Icons.palette_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onOpenThemeSettings,
          ),
        if (onOpenClubInfoSettings != null)
          AppActionButton(
            label: compact ? 'Modifica club' : 'Aggiorna club',
            icon: Icons.edit_note_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onOpenClubInfoSettings,
          ),
      ],
      footer: showUsefulLinks
          ? Wrap(
              alignment: WrapAlignment.center,
              spacing: compact ? 8 : 10,
              runSpacing: compact ? 8 : 10,
              children: [
                for (final link in visibleLinks)
                  _UsefulLinkChip(
                    link: link,
                    onTap: () => onOpenLink(link.url),
                  ),
              ],
            )
          : null,
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.isAuthenticated,
    required this.currentUser,
    required this.currentUserEmail,
    required this.needsProfileSetup,
    required this.requiresPasswordRecovery,
    required this.isCaptainRegistrationOpen,
    required this.errorMessage,
    required this.onCreateProfile,
    required this.onOpenSignIn,
    required this.onOpenSignUp,
  });

  final bool isAuthenticated;
  final PlayerProfile? currentUser;
  final String? currentUserEmail;
  final bool needsProfileSetup;
  final bool requiresPasswordRecovery;
  final bool isCaptainRegistrationOpen;
  final String? errorMessage;
  final VoidCallback onCreateProfile;
  final VoidCallback onOpenSignIn;
  final VoidCallback onOpenSignUp;

  List<Widget> _permissionPills(PlayerProfile? user) {
    if (user == null) {
      return const <Widget>[];
    }

    return [
      AppCountPill(
        label: user.canManagePlayers ? 'Gestione rosa' : 'Rosa con filtri',
      ),
      AppCountPill(
        label: user.canManageLineups
            ? 'Gestione formazioni'
            : 'Formazioni solo lettura',
      ),
      AppCountPill(
        label: user.canManageStreams ? 'Gestione live' : 'Live solo lettura',
      ),
      AppCountPill(
        label: user.canManageAttendanceAll
            ? 'Presenze club'
            : 'Presenze personali',
      ),
      AppCountPill(
        label: user.canManageClubInfo ? 'Info club' : 'Info club sola lettura',
      ),
    ];
  }

  String _sessionSubtitle() {
    if (!isAuthenticated) {
      return 'Accedi con email e password oppure crea il tuo account.';
    }

    if (needsProfileSetup) {
      if (currentUser != null) {
        return 'Sei gia nel club, ma mancano ancora gli ultimi dati del giocatore.';
      }

      final email = currentUserEmail;
      if (email == null) {
        return 'Sei autenticato, ma manca il profilo club collegato.';
      }

      return 'Hai eseguito l accesso come $email, ma devi ancora completare il profilo giocatore.';
    }

    if (currentUser == null) {
      return 'Accesso completato. Ora stiamo sincronizzando il profilo club.';
    }

    if (currentUser!.isCaptain) {
      return 'Controllo completo del club, delle richieste e dei permessi vice.';
    }

    if (currentUser!.isViceCaptain) {
      if (!currentUser!.hasAnyManagementPermission) {
        return 'Vice senza permessi gestionali attivi: usi Clubline come giocatore.';
      }

      return 'Vice con permessi mirati definiti dal capitano.';
    }

    return 'Profilo giocatore attivo: aggiorni il tuo profilo e le tue presenze.';
  }

  @override
  Widget build(BuildContext context) {
    final permissionPills = _permissionPills(currentUser);
    final compact = AppResponsive.isCompact(context);
    final sectionSpacing = compact ? 10.0 : 14.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(
          compact
              ? AppResponsive.cardPadding(context) - 2
              : AppResponsive.cardPadding(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              !isAuthenticated
                  ? 'Accedi a Clubline'
                  : needsProfileSetup
                  ? 'Completa il profilo'
                  : currentUser == null
                  ? 'Accesso attivo'
                  : currentUser!.isCaptain
                  ? 'Capitano attivo'
                  : 'Accesso come ${currentUser!.fullName}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _sessionSubtitle(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClublineAppTheme.textMuted,
                height: 1.3,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            SizedBox(height: sectionSpacing),
            if (!isAuthenticated) ...[
              Text(
                'Dopo l accesso creerai il tuo giocatore e poi potrai creare un club o chiedere l ingresso in uno esistente.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ClublineAppTheme.textMuted,
                  height: 1.3,
                ),
              ),
              SizedBox(height: sectionSpacing),
              if (compact) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('home-guest-sign-in-button'),
                    onPressed: onOpenSignIn,
                    icon: const Icon(Icons.login_outlined),
                    label: const Text('Accedi'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('home-guest-sign-up-button'),
                    onPressed: onOpenSignUp,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Registrati'),
                  ),
                ),
              ] else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      key: const Key('home-guest-sign-in-button'),
                      onPressed: onOpenSignIn,
                      icon: const Icon(Icons.login_outlined),
                      label: const Text('Accedi'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('home-guest-sign-up-button'),
                      onPressed: onOpenSignUp,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Registrati'),
                    ),
                  ],
                ),
            ] else if (needsProfileSetup) ...[
              Text(
                currentUser == null
                    ? 'Manca ancora il profilo collegato al club.'
                    : 'Aggiungi maglia, ruolo e dati mancanti per sbloccare rosa, formazioni, live e presenze.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ClublineAppTheme.textMuted,
                  height: 1.3,
                ),
              ),
              SizedBox(height: sectionSpacing),
              _CompleteProfileCtaButton(
                fullWidth: compact,
                onPressed: onCreateProfile,
              ),
            ] else ...[
              Text(
                currentUserEmail == null
                    ? 'Sessione attiva'
                    : 'Sessione attiva: $currentUserEmail',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Hai un profilo collegato e puoi continuare usando Clubline con i tuoi permessi.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ClublineAppTheme.textMuted,
                  height: 1.3,
                ),
              ),
              if (requiresPasswordRecovery) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ClublineAppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: ClublineAppTheme.warning.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    'Sei entrato dal link di recupero password. Impostane una nuova per chiudere il recupero e continuare ad usare Clubline normalmente.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ClublineAppTheme.warningSoft,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              SizedBox(height: sectionSpacing),
              Wrap(
                spacing: compact ? 8 : 10,
                runSpacing: compact ? 8 : 10,
                children: [if (permissionPills.isNotEmpty) ...permissionPills],
              ),
              if (!compact) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Le azioni account sono nel menu profilo in alto a destra.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ClublineAppTheme.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CompleteProfileCtaButton extends StatefulWidget {
  const _CompleteProfileCtaButton({
    required this.onPressed,
    required this.fullWidth,
  });

  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  State<_CompleteProfileCtaButton> createState() =>
      _CompleteProfileCtaButtonState();
}

class _CompleteProfileCtaButtonState extends State<_CompleteProfileCtaButton>
    with SingleTickerProviderStateMixin {
  static const _seenKey = 'home_complete_profile_cta_pulse_seen_v1';

  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _shouldAnimate = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.05,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
    ]).animate(_controller);

    _startPulseIfFirstTime();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startPulseIfFirstTime() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final alreadySeen = preferences.getBool(_seenKey) == true;
      if (alreadySeen || !mounted) {
        return;
      }

      setState(() {
        _shouldAnimate = true;
      });

      await _controller.forward();
      await preferences.setBool(_seenKey, true);

      if (!mounted) {
        return;
      }

      setState(() {
        _shouldAnimate = false;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      key: const Key('home-complete-player-profile-button'),
      onPressed: widget.onPressed,
      icon: const Icon(Icons.person_add_alt_1_outlined),
      label: const Text('Completa Profilo giocatore'),
    );

    final animatedButton = _shouldAnimate
        ? ScaleTransition(scale: _scale, child: button)
        : button;

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: animatedButton);
    }

    return animatedButton;
  }
}

class _UsefulLinkChip extends StatelessWidget {
  const _UsefulLinkChip({required this.link, required this.onTap});

  final ClubInfoLinkItem link;
  final VoidCallback onTap;

  IconData _iconForLink(String key) {
    switch (key) {
      case 'youtube':
        return Icons.smart_display_outlined;
      case 'discord':
        return Icons.forum_outlined;
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.photo_camera_back_outlined;
      case 'twitch':
        return Icons.videocam_outlined;
      case 'tiktok':
        return Icons.music_note_outlined;
      case 'website':
        return Icons.language_outlined;
      default:
        return Icons.link_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(
        _iconForLink(link.key),
        size: 16,
        color: ClublineAppTheme.goldSoft,
      ),
      side: BorderSide(color: ClublineAppTheme.outlineSoft),
      backgroundColor: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.8),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: ClublineAppTheme.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      label: Text(link.label),
    );
  }
}
