import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/club_repository.dart';
import '../../models/player_profile.dart';
import '../../models/club_info.dart';
import '../widgets/app_chrome.dart';
import '../widgets/clubline_brand_logo.dart';
import '../widgets/club_logo_avatar.dart';
import '../widgets/notifications_bell_button.dart';

enum _HomeProfileMenuAction {
  completeProfile,
  editProfile,
  changePassword,
  biometricUnlock,
  themeSettings,
  clubInfoSettings,
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

  Future<void> _signOut(AppSessionController session) async {
    await session.signOut();
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
      case _HomeProfileMenuAction.themeSettings:
        onOpenThemeSettings();
        return;
      case _HomeProfileMenuAction.clubInfoSettings:
        onOpenClubInfoSettings();
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
        await _signOut(session);
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
    final canOpenThemeSettings = hasClubMembership && !needsProfileSetup;
    final canOpenClubInfoSettings =
        currentUser?.canManageClubInfo == true && !needsProfileSetup;
    final canManageVicePermissions =
        currentUser?.isCaptain == true && !needsProfileSetup;
    final canOpenClubManagement =
        !needsProfileSetup &&
        (currentUser?.isCaptain == true ||
            currentUser?.canManageInvites == true);
    final isPersonalizedExperience = hasClubMembership;
    final pendingJoinRequests = session.captainPendingJoinRequests.length;
    final pendingLeaveRequests = session.captainPendingLeaveRequests.length;
    final pendingCaptainRequests = pendingJoinRequests + pendingLeaveRequests;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPersonalizedExperience ? clubInfo.displayClubName : 'Clubline',
        ),
        actions: [
          const NotificationsBellButton(),
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
                if (canOpenThemeSettings)
                  const PopupMenuItem<_HomeProfileMenuAction>(
                    value: _HomeProfileMenuAction.themeSettings,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.palette_outlined),
                      title: Text('Aspetto app'),
                    ),
                  ),
                if (canOpenClubInfoSettings)
                  const PopupMenuItem<_HomeProfileMenuAction>(
                    value: _HomeProfileMenuAction.clubInfoSettings,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_note_outlined),
                      title: Text('Info club'),
                    ),
                  ),
                if (canOpenClubManagement)
                  PopupMenuItem<_HomeProfileMenuAction>(
                    value: _HomeProfileMenuAction.manageClub,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(
                        currentUser?.isCaptain == true
                            ? 'Dashboard capitano'
                            : 'Gestione inviti club',
                      ),
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
                      canOpenThemeSettings: canOpenThemeSettings,
                      canOpenClubInfoSettings: canOpenClubInfoSettings,
                      pendingCaptainRequests: pendingCaptainRequests,
                      onOpenCreateProfile: onOpenCreateProfile,
                      onOpenClubManagement: onOpenClubManagement,
                      onOpenThemeSettings: onOpenThemeSettings,
                      onOpenClubInfoSettings: onOpenClubInfoSettings,
                      onOpenLink: (url) => _openExternalLink(context, url),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (currentUser != null &&
                            !needsProfileSetup &&
                            (currentUser.isCaptain &&
                                (session
                                        .captainPendingJoinRequests
                                        .isNotEmpty ||
                                    session
                                        .captainPendingLeaveRequests
                                        .isNotEmpty))) ...[
                          _ClubPulseCard(
                            currentUser: currentUser,
                            session: session,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (!isAuthenticated)
                          _GuestAccessCard(
                            errorMessage: session.errorMessage,
                            onOpenSignIn: onOpenSignIn,
                            onOpenSignUp: onOpenSignUp,
                          )
                        else if (needsProfileSetup ||
                            session.requiresPasswordRecovery ||
                            session.errorMessage != null ||
                            session.hasPendingLeaveRequest ||
                            currentUser == null)
                          _HomeContextCard(
                            currentUser: currentUser,
                            currentUserEmail: currentUserEmail,
                            needsProfileSetup: needsProfileSetup,
                            requiresPasswordRecovery:
                                session.requiresPasswordRecovery,
                            hasPendingLeaveRequest:
                                session.hasPendingLeaveRequest,
                            errorMessage: session.errorMessage,
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
  const _ClubPulseCard({required this.currentUser, required this.session});

  final PlayerProfile currentUser;
  final AppSessionController session;

  @override
  Widget build(BuildContext context) {
    final pendingJoin = session.captainPendingJoinRequests.length;
    final pendingLeave = session.captainPendingLeaveRequests.length;
    final isCaptain = currentUser.isCaptain;
    final compact = AppResponsive.isCompact(context);
    final pendingTotal = pendingJoin + pendingLeave;

    final title = isCaptain
        ? 'Richieste del club'
        : session.hasPendingLeaveRequest
        ? 'Uscita inviata'
        : 'Club attivo';
    final message = isCaptain
        ? '$pendingJoin ingressi e $pendingLeave uscite aspettano la tua decisione.'
        : 'La richiesta di uscita e in attesa della decisione del capitano.';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
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
            if (isCaptain && pendingTotal > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  AppCountPill(
                    label: 'Ingressi',
                    value: '$pendingJoin',
                    emphasized: pendingJoin > 0,
                  ),
                  AppCountPill(
                    label: 'Uscite',
                    value: '$pendingLeave',
                    emphasized: pendingLeave > 0,
                  ),
                ],
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
    required this.canOpenThemeSettings,
    required this.canOpenClubInfoSettings,
    required this.pendingCaptainRequests,
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
  final bool canOpenThemeSettings;
  final bool canOpenClubInfoSettings;
  final int pendingCaptainRequests;
  final VoidCallback onOpenCreateProfile;
  final VoidCallback onOpenClubManagement;
  final VoidCallback onOpenThemeSettings;
  final VoidCallback onOpenClubInfoSettings;
  final ValueChanged<String> onOpenLink;

  String _welcomeText(bool compact) {
    if (!isAuthenticated) {
      return compact
          ? 'Accedi o registrati e inizia dal tuo giocatore.'
          : 'Accedi o registrati. Poi creerai il tuo giocatore e sceglierai il club.';
    }

    if (needsProfileSetup) {
      if (currentUser != null) {
        return compact
            ? 'Completa il profilo per sbloccare tutte le funzioni.'
            : 'Sei gia nel club. Completa il profilo per sbloccare tutto.';
      }

      final email = currentUserEmail;
      if (email == null) {
        return compact
            ? 'Sei autenticato, ma manca ancora il profilo collegato.'
            : 'Sei autenticato, ma manca ancora il profilo club collegato.';
      }

      return compact
          ? 'Completa il profilo giocatore per entrare davvero nel club.'
          : 'Completa il profilo giocatore prima di usare il club.';
    }

    if (currentUser == null) {
      return compact
          ? 'Stiamo sincronizzando il tuo profilo club.'
          : 'Stiamo sincronizzando il tuo profilo club.';
    }

    return compact
        ? '${currentUser!.teamRoleDisplay} attivo.'
        : '${currentUser!.teamRoleDisplay} attivo in questo club.';
  }

  (String, IconData, VoidCallback)? _primaryAction() {
    if (needsProfileSetup) {
      return (
        'Completa profilo',
        Icons.person_add_alt_1_outlined,
        onOpenCreateProfile,
      );
    }

    if (currentUser?.isCaptain == true && pendingCaptainRequests > 0) {
      return (
        pendingCaptainRequests == 1
            ? 'Gestisci 1 richiesta'
            : 'Gestisci richieste ($pendingCaptainRequests)',
        Icons.mark_email_unread_outlined,
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
    final heroCrestStoragePath = isPersonalizedExperience
        ? clubInfo.crestStoragePath
        : null;
    final primaryAction = _primaryAction();
    final visibleLinks = compact
        ? clubInfo.allLinks.take(3).toList(growable: false)
        : clubInfo.allLinks;
    final primaryLink = visibleLinks.isNotEmpty ? visibleLinks.first : null;
    final secondaryVisibleLinks = primaryLink == null
        ? visibleLinks
        : visibleLinks.skip(1).toList(growable: false);
    final showUsefulLinks =
        isPersonalizedExperience && secondaryVisibleLinks.isNotEmpty;
    final hasClubTools =
        canOpenThemeSettings || canOpenClubInfoSettings || primaryLink != null;
    final badges = <Widget>[
      if (isAuthenticated && currentUser != null)
        AppStatusBadge(label: currentUser!.teamRoleDisplay, tone: _roleTone()),
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
              logoStoragePath: heroCrestStoragePath,
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
      ],
      footer: hasClubTools || showUsefulLinks
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasClubTools)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: compact ? 8 : 10,
                    runSpacing: compact ? 8 : 10,
                    children: [
                      if (canOpenThemeSettings)
                        _HomeToolChip(
                          label: 'Aspetto app',
                          icon: Icons.palette_outlined,
                          onTap: onOpenThemeSettings,
                        ),
                      if (canOpenClubInfoSettings)
                        _HomeToolChip(
                          label: 'Info club',
                          icon: Icons.edit_note_outlined,
                          onTap: onOpenClubInfoSettings,
                        ),
                      if (primaryLink != null)
                        _HomeToolChip(
                          label: 'Link club',
                          icon: Icons.link_outlined,
                          onTap: () => onOpenLink(primaryLink.url),
                        ),
                    ],
                  ),
                if (showUsefulLinks) ...[
                  SizedBox(height: hasClubTools ? AppSpacing.sm : 0),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: compact ? 8 : 10,
                    runSpacing: compact ? 8 : 10,
                    children: [
                      for (final link in secondaryVisibleLinks)
                        _UsefulLinkChip(
                          link: link,
                          onTap: () => onOpenLink(link.url),
                        ),
                    ],
                  ),
                ],
              ],
            )
          : null,
    );
  }
}

class _HomeToolChip extends StatelessWidget {
  const _HomeToolChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: ClublineAppTheme.goldSoft),
      side: BorderSide(color: ClublineAppTheme.outlineSoft),
      backgroundColor: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.9),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: ClublineAppTheme.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      label: Text(label),
    );
  }
}

class _GuestAccessCard extends StatelessWidget {
  const _GuestAccessCard({
    required this.onOpenSignIn,
    required this.onOpenSignUp,
    this.errorMessage,
  });

  final String? errorMessage;
  final VoidCallback onOpenSignIn;
  final VoidCallback onOpenSignUp;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accedi a Clubline',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Entra nel tuo account o creane uno nuovo.',
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
            const SizedBox(height: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.sm),
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
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
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
          ],
        ),
      ),
    );
  }
}

class _HomeContextCard extends StatelessWidget {
  const _HomeContextCard({
    required this.currentUser,
    required this.currentUserEmail,
    required this.needsProfileSetup,
    required this.requiresPasswordRecovery,
    required this.hasPendingLeaveRequest,
    this.errorMessage,
  });

  final PlayerProfile? currentUser;
  final String? currentUserEmail;
  final bool needsProfileSetup;
  final bool requiresPasswordRecovery;
  final bool hasPendingLeaveRequest;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (errorMessage != null)
        AppBanner(message: errorMessage!, tone: AppStatusTone.error),
      if (requiresPasswordRecovery)
        const AppBanner(
          message:
              'Sei entrato dal recupero password. Impostane una nuova dal menu profilo.',
          icon: Icons.lock_reset_outlined,
          tone: AppStatusTone.warning,
        ),
      if (needsProfileSetup)
        const AppBanner(
          message:
              'Completa il profilo giocatore per sbloccare tutte le aree del club.',
          icon: Icons.person_add_alt_1_outlined,
          tone: AppStatusTone.warning,
        ),
      if (hasPendingLeaveRequest)
        const AppBanner(
          message:
              'La richiesta di uscita e in attesa della decisione del capitano.',
          icon: Icons.hourglass_top_outlined,
          tone: AppStatusTone.info,
        ),
      if (currentUser == null &&
          !needsProfileSetup &&
          !requiresPasswordRecovery &&
          errorMessage == null)
        AppBanner(
          message: currentUserEmail == null
              ? 'Stiamo sincronizzando il tuo profilo club.'
              : 'Accesso eseguito come $currentUserEmail. Stiamo sincronizzando il profilo club.',
        ),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.sm),
          items[index],
        ],
      ],
    );
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
