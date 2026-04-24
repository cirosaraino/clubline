import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/club_repository.dart';
import '../../models/player_profile.dart';
import '../../models/team_info.dart';
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
    required this.onOpenTeamInfoSettings,
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
  final VoidCallback onOpenTeamInfoSettings;
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
    final teamInfo = session.teamInfo;
    final canShowProfileMenu = isAuthenticated;
    final canManageVicePermissions =
        currentUser?.isCaptain == true && !needsProfileSetup;
    final isPersonalizedExperience = hasClubMembership;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPersonalizedExperience ? teamInfo.displayTeamName : 'Clubline',
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
                  12,
                  AppResponsive.horizontalPadding(context),
                  28,
                ),
                child: AppAdaptiveColumns(
                  breakpoint: 1080,
                  gap: AppResponsive.sectionGap(context),
                  flex: const [3, 2],
                  children: [
                    _HomeWelcomeCard(
                      teamInfo: teamInfo,
                      currentUser: currentUser,
                      isAuthenticated: isAuthenticated,
                      isPersonalizedExperience: isPersonalizedExperience,
                      currentUserEmail: currentUserEmail,
                      needsProfileSetup: needsProfileSetup,
                      onOpenThemeSettings:
                          isPersonalizedExperience && !needsProfileSetup
                          ? onOpenThemeSettings
                          : null,
                      onOpenTeamInfoSettings:
                          currentUser?.canManageTeamInfo == true &&
                              !needsProfileSetup
                          ? onOpenTeamInfoSettings
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

    final title = isCaptain
        ? 'Dashboard capitano pronta'
        : session.hasPendingLeaveRequest
        ? 'Richiesta di uscita in attesa'
        : 'Club attivo';
    final message = isCaptain
        ? 'Hai $pendingJoin richieste di ingresso e $pendingLeave richieste di uscita da gestire.'
        : 'La tua richiesta di uscita è stata inviata e resta in attesa della decisione del capitano.';

    return AppStatusCard(
      icon: isCaptain
          ? Icons.admin_panel_settings_outlined
          : Icons.hourglass_top_outlined,
      title: title,
      message: message,
      actionLabel: isCaptain ? 'Apri dashboard capitano' : null,
      actionIcon: Icons.arrow_forward_outlined,
      onAction: isCaptain ? onOpenClubManagement : null,
    );
  }
}

class _HomeWelcomeCard extends StatelessWidget {
  const _HomeWelcomeCard({
    required this.teamInfo,
    required this.currentUser,
    required this.isAuthenticated,
    required this.isPersonalizedExperience,
    required this.currentUserEmail,
    required this.needsProfileSetup,
    required this.onOpenThemeSettings,
    required this.onOpenTeamInfoSettings,
    required this.onOpenLink,
  });

  final TeamInfo teamInfo;
  final PlayerProfile? currentUser;
  final bool isAuthenticated;
  final bool isPersonalizedExperience;
  final String? currentUserEmail;
  final bool needsProfileSetup;
  final VoidCallback? onOpenThemeSettings;
  final VoidCallback? onOpenTeamInfoSettings;
  final ValueChanged<String> onOpenLink;

  String _welcomeText() {
    if (!isAuthenticated) {
      return 'Crea il tuo account oppure accedi con le tue credenziali. Dopo il login creerai prima il tuo giocatore, poi sceglierai il club. La grafica personalizzata comparira solo dopo l ingresso in squadra.';
    }

    if (needsProfileSetup) {
      if (currentUser != null) {
        return 'Benvenuto ${currentUser!.fullName}. Sei gia dentro il club, ma per sbloccare Clubline devi completare subito il profilo giocatore.';
      }

      final email = currentUserEmail;
      if (email == null) {
        return 'Sei autenticato, ma manca ancora il profilo club collegato.';
      }

      return 'Benvenuto $email. Prima di usare il club devi completare il profilo giocatore.';
    }

    if (currentUser == null) {
      return 'Accesso completato. Il profilo club verrà sincronizzato appena disponibile.';
    }

    return 'Benvenuto ${currentUser!.fullName}. In questo momento stai usando Clubline come ${currentUser!.teamRoleDisplay.toLowerCase()}.';
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final heroCrestUrl = isPersonalizedExperience ? teamInfo.crestUrl : null;
    final showUsefulLinks = isPersonalizedExperience && teamInfo.hasAnyLinks;
    return AppHeroPanel(
      centered: true,
      eyebrow: isPersonalizedExperience ? 'Club attivo' : 'Clubline',
      title: isPersonalizedExperience ? teamInfo.displayTeamName : 'Clubline',
      subtitle: _welcomeText(),
      media: isPersonalizedExperience
          ? ClubLogoAvatar(
              logoUrl: heroCrestUrl,
              size: compact ? 96 : 126,
              fallbackIcon: Icons.shield_outlined,
            )
          : ClublineBrandLogo(width: compact ? 172 : 224),
      actions: [
        if (onOpenThemeSettings != null)
          AppActionButton(
            label: 'Colori app',
            icon: Icons.palette_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onOpenThemeSettings,
          ),
        if (onOpenTeamInfoSettings != null)
          AppActionButton(
            label: 'Info club',
            icon: Icons.edit_note_outlined,
            onPressed: onOpenTeamInfoSettings,
          ),
      ],
      footer: showUsefulLinks
          ? Wrap(
              alignment: WrapAlignment.center,
              spacing: compact ? 8 : 10,
              runSpacing: compact ? 8 : 10,
              children: [
                for (final link in teamInfo.allLinks)
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
        label: user.canManageTeamInfo ? 'Info club' : 'Info club sola lettura',
      ),
    ];
  }

  String _sessionSubtitle() {
    if (!isAuthenticated) {
      return 'Accedi con email e password. Se sei nuovo, puoi creare un account in pochi secondi.';
    }

    if (needsProfileSetup) {
      if (currentUser != null) {
        return 'Hai gia un profilo collegato al club, ma mancano ancora i dati sportivi finali per completarlo.';
      }

      final email = currentUserEmail;
      if (email == null) {
        return 'Sei autenticato, ma manca il profilo club collegato.';
      }

      return 'Hai eseguito l accesso come $email, ma devi ancora completare il profilo giocatore prima di usare il club.';
    }

    if (currentUser == null) {
      return 'Accesso completato. Ora stiamo sincronizzando il profilo club.';
    }

    if (currentUser!.isCaptain) {
      return 'Permessi da capitano: controllo totale del club, della Home e della configurazione dei vice.';
    }

    if (currentUser!.isViceCaptain) {
      if (!currentUser!.hasAnyManagementPermission) {
        return 'Ruolo da vice con permessi gestionali disattivati: continui a usare l app come giocatore, con il solo accesso al tuo profilo e alle tue presenze.';
      }

      return 'Permessi da vice: puoi gestire solo le aree che il capitano ha scelto di autorizzarti, incluse eventualmente le info club.';
    }

    return 'Permessi da giocatore: puoi consultare tutto, aggiornare solo il tuo profilo e compilare soltanto le tue presenze.';
  }

  @override
  Widget build(BuildContext context) {
    final permissionPills = _permissionPills(currentUser);
    final compact = AppResponsive.isCompact(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              !isAuthenticated
                  ? 'Accesso reale'
                  : needsProfileSetup
                  ? 'Profilo da completare'
                  : currentUser == null
                  ? 'Accesso autenticato'
                  : 'Accesso come ${currentUser!.fullName}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _sessionSubtitle(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClublineAppTheme.textMuted,
                height: 1.35,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (!isAuthenticated) ...[
              Text(
                'Nessun accesso attivo',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Accedi con un account esistente oppure registrane uno nuovo. Dopo il login creerai prima il tuo giocatore e poi potrai creare un club o chiedere l ingresso in uno esistente.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ClublineAppTheme.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
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
                    ? 'Profilo non ancora collegato'
                    : 'Profilo da completare',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Text(
                currentUser == null
                    ? 'Sei autenticato con ${currentUserEmail ?? 'un account valido'}, ma manca ancora il profilo club da compilare.'
                    : 'Sei dentro il club come ${currentUser!.fullName}, ma devi ancora completare il profilo giocatore con maglia, ruolo e dati mancanti.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ClublineAppTheme.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                currentUser == null
                    ? 'Usa l icona profilo in alto a destra per completare il profilo giocatore. Finche non lo fai, gli altri tab restano bloccati.'
                    : 'Usa l icona profilo in alto a destra per aprire il completamento del profilo e salvare i dettagli mancanti. Finche non completi il giocatore, gli altri tab restano bloccati.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ClublineAppTheme.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
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
                  height: 1.35,
                ),
              ),
              if (requiresPasswordRecovery) ...[
                const SizedBox(height: 12),
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
              const SizedBox(height: 14),
              Wrap(
                spacing: compact ? 8 : 10,
                runSpacing: compact ? 8 : 10,
                children: [if (permissionPills.isNotEmpty) ...permissionPills],
              ),
              const SizedBox(height: 12),
              Text(
                'Le azioni account (modifica profilo, password, cancellazione ed uscita) sono nel menu profilo in alto a destra.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ClublineAppTheme.textMuted,
                  height: 1.35,
                ),
              ),
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

  final TeamInfoLinkItem link;
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
