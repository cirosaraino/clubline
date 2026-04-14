import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../models/player_profile.dart';
import '../../models/team_info.dart';
import '../widgets/app_chrome.dart';

const String kUltrasLogoAsset = 'assets/images/ultras_mentality_logo.jpg';

enum _HomeProfileMenuAction {
  completeProfile,
  editProfile,
  changePassword,
  manageVicePermissions,
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
    required this.onOpenThemeSettings,
    required this.onOpenVicePermissionsSettings,
    required this.onOpenTeamInfoSettings,
  });

  final VoidCallback onOpenCreateProfile;
  final VoidCallback onOpenEditCurrentProfile;
  final VoidCallback onOpenSignIn;
  final VoidCallback onOpenSignUp;
  final VoidCallback onOpenPasswordSettings;
  final VoidCallback onOpenThemeSettings;
  final VoidCallback onOpenVicePermissionsSettings;
  final VoidCallback onOpenTeamInfoSettings;

  Future<void> _openExternalLink(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link non valido')),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il link')),
      );
    }
  }

  Future<void> _signOut(BuildContext context, AppSessionController session) async {
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
      case _HomeProfileMenuAction.manageVicePermissions:
        onOpenVicePermissionsSettings();
        return;
      case _HomeProfileMenuAction.signOut:
        await _signOut(context, session);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final isAuthenticated = session.isAuthenticated;
    final currentUser = session.currentUser;
    final currentUserEmail = session.currentUserEmail;
    final needsProfileSetup = session.needsProfileSetup;
    final teamInfo = session.teamInfo;
    final canShowProfileMenu = isAuthenticated;
    final canManageVicePermissions = currentUser?.isCaptain == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(teamInfo.displayTeamName),
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
                if (currentUser != null)
                  const PopupMenuItem<_HomeProfileMenuAction>(
                    key: Key('home-profile-menu-edit-player'),
                    value: _HomeProfileMenuAction.editProfile,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Modifica profilo giocatore'),
                    ),
                  )
                else
                  const PopupMenuItem<_HomeProfileMenuAction>(
                    key: Key('home-profile-menu-complete-player'),
                    value: _HomeProfileMenuAction.completeProfile,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_add_alt_1_outlined),
                      title: Text('Completa Profilo giocatore'),
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
            child: _GlowCircle(size: 260, color: UltrasAppTheme.outlineStrong),
          ),
          Positioned(
            left: -90,
            bottom: 60,
            child: _GlowCircle(
              size: 220,
              color: UltrasAppTheme.goldSoft.withValues(alpha: 0.16),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppResponsive.horizontalPadding(context),
                12,
                AppResponsive.horizontalPadding(context),
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeWelcomeCard(
                    teamInfo: teamInfo,
                    currentUser: currentUser,
                    isAuthenticated: isAuthenticated,
                    currentUserEmail: currentUserEmail,
                    needsProfileSetup: needsProfileSetup,
                    onOpenThemeSettings: onOpenThemeSettings,
                    onOpenTeamInfoSettings:
                        currentUser?.canManageTeamInfo == true ? onOpenTeamInfoSettings : null,
                    onOpenLink: (url) => _openExternalLink(context, url),
                  ),
                  const SizedBox(height: 18),
                  _AccessCard(
                    isAuthenticated: isAuthenticated,
                    currentUser: currentUser,
                    currentUserEmail: currentUserEmail,
                    needsProfileSetup: needsProfileSetup,
                    requiresPasswordRecovery: session.requiresPasswordRecovery,
                    isCaptainRegistrationOpen:
                        !session.players.any((player) => player.hasLinkedAuthAccount),
                    errorMessage: session.errorMessage,
                    onCreateProfile: onOpenCreateProfile,
                    onOpenSignIn: onOpenSignIn,
                    onOpenSignUp: onOpenSignUp,
                  ),
                ],
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
          gradient: RadialGradient(
            colors: [
              color,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeWelcomeCard extends StatelessWidget {
  const _HomeWelcomeCard({
    required this.teamInfo,
    required this.currentUser,
    required this.isAuthenticated,
    required this.currentUserEmail,
    required this.needsProfileSetup,
    required this.onOpenThemeSettings,
    required this.onOpenTeamInfoSettings,
    required this.onOpenLink,
  });

  final TeamInfo teamInfo;
  final PlayerProfile? currentUser;
  final bool isAuthenticated;
  final String? currentUserEmail;
  final bool needsProfileSetup;
  final VoidCallback onOpenThemeSettings;
  final VoidCallback? onOpenTeamInfoSettings;
  final ValueChanged<String> onOpenLink;

  String _welcomeText() {
    if (!isAuthenticated) {
      return 'Benvenuto. Accedi o registrati per entrare nell app e vedere subito cosa puoi fare da giocatore, vice o capitano.';
    }

    if (needsProfileSetup) {
      final email = currentUserEmail;
      if (email == null) {
        return 'Sei autenticato, ma manca ancora il profilo squadra collegato.';
      }

      return 'Benvenuto $email. Ora manca solo il profilo squadra per completare l accesso.';
    }

    if (currentUser == null) {
      return 'Accesso completato. Il profilo squadra verra sincronizzato appena disponibile.';
    }

    return 'Benvenuto ${currentUser!.fullName}. In questo momento stai usando l app come ${currentUser!.teamRoleDisplay.toLowerCase()}.';
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final cardPadding = AppResponsive.cardPadding(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: UltrasAppTheme.heroGradient,
        borderRadius: BorderRadius.circular(compact ? 26 : 30),
        border: Border.all(color: UltrasAppTheme.outlineStrong),
        boxShadow: UltrasAppTheme.softShadow,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(cardPadding, compact ? 18 : 24, cardPadding, cardPadding),
        child: Column(
          children: [
            _TeamCrestAvatar(
              crestUrl: teamInfo.crestUrl,
              size: compact ? 96 : 126,
            ),
            SizedBox(height: compact ? 14 : 18),
            Text(
              teamInfo.displayTeamName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    fontSize: compact ? 28 : null,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _welcomeText(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: UltrasAppTheme.textMuted,
                    height: 1.4,
                  ),
            ),
            if (teamInfo.hasAnyLinks) ...[
              SizedBox(height: compact ? 14 : 18),
              Wrap(
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
              ),
            ],
            SizedBox(height: compact ? 14 : 18),
            if (compact) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenThemeSettings,
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('Colori app'),
                ),
              ),
              if (onOpenTeamInfoSettings != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onOpenTeamInfoSettings,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Info squadra'),
                  ),
                ),
              ],
            ] else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onOpenThemeSettings,
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Colori app'),
                  ),
                  if (onOpenTeamInfoSettings != null)
                    ElevatedButton.icon(
                      onPressed: onOpenTeamInfoSettings,
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Info squadra'),
                    ),
                ],
              ),
          ],
        ),
      ),
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
        label: user.canManageLineups ? 'Gestione formazioni' : 'Formazioni solo lettura',
      ),
      AppCountPill(
        label: user.canManageStreams ? 'Gestione live' : 'Live solo lettura',
      ),
      AppCountPill(
        label: user.canManageAttendanceAll ? 'Presenze squadra' : 'Presenze personali',
      ),
      AppCountPill(
        label: user.canManageTeamInfo ? 'Info squadra' : 'Info squadra sola lettura',
      ),
    ];
  }

  String _sessionSubtitle() {
    if (!isAuthenticated) {
      return 'Accedi con email e password. Se sei nuovo, puoi creare un account in pochi secondi.';
    }

    if (needsProfileSetup) {
      final email = currentUserEmail;
      if (email == null) {
        return 'Sei autenticato, ma manca il profilo squadra collegato.';
      }

      return 'Hai eseguito l accesso come $email, ma devi ancora completare il profilo squadra.';
    }

    if (currentUser == null) {
      return 'Accesso completato. Ora stiamo sincronizzando il profilo squadra.';
    }

    if (currentUser!.isCaptain) {
      return 'Permessi da capitano: controllo totale della squadra, delle info Home e della configurazione dei vice.';
    }

    if (currentUser!.isViceCaptain) {
      if (!currentUser!.hasAnyManagementPermission) {
        return 'Ruolo da vice con permessi gestionali disattivati: continui a usare l app come giocatore, con il solo accesso al tuo profilo e alle tue presenze.';
      }

      return 'Permessi da vice: puoi gestire solo le aree che il capitano ha scelto di autorizzarti, incluse eventualmente le info squadra.';
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _sessionSubtitle(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: UltrasAppTheme.textMuted,
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Accedi con un account esistente oppure registrane uno nuovo. Dopo il login puoi completare il profilo squadra.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: UltrasAppTheme.textMuted,
                      height: 1.35,
                    ),
              ),
              if (isCaptainRegistrationOpen) ...[
                const SizedBox(height: 10),
                Text(
                  'Registrazione capitano iniziale aperta: il primo account che completa il primo profilo squadra verra impostato come capitano.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
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
                'Profilo non ancora collegato',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sei autenticato con ${currentUserEmail ?? 'un account valido'}, ma manca ancora il profilo squadra da compilare.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: UltrasAppTheme.textMuted,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                'Usa l icona profilo in alto a destra per completare il profilo giocatore, cambiare password o uscire.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: UltrasAppTheme.textMuted,
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hai un profilo collegato e puoi continuare usando l app con i tuoi permessi.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: UltrasAppTheme.textMuted,
                      height: 1.35,
                    ),
              ),
              if (requiresPasswordRecovery) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: UltrasAppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: UltrasAppTheme.warning.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    'Sei entrato dal link di recupero password. Impostane una nuova per chiudere il recupero e continuare ad usare l app normalmente.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: UltrasAppTheme.warningSoft,
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
                children: [
                  if (permissionPills.isNotEmpty) ...permissionPills,
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Le azioni account (modifica profilo, password ed uscita) sono nel menu profilo in alto a destra.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: UltrasAppTheme.textMuted,
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
        tween: Tween<double>(begin: 1, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
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
        ? ScaleTransition(
            scale: _scale,
            child: button,
          )
        : button;

    if (widget.fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: animatedButton,
      );
    }

    return animatedButton;
  }
}

class _UsefulLinkChip extends StatelessWidget {
  const _UsefulLinkChip({
    required this.link,
    required this.onTap,
  });

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
        color: UltrasAppTheme.goldSoft,
      ),
      side: BorderSide(color: UltrasAppTheme.outlineSoft),
      backgroundColor: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.8),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: UltrasAppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
      label: Text(link.label),
    );
  }
}

class _TeamCrestAvatar extends StatelessWidget {
  const _TeamCrestAvatar({
    required this.crestUrl,
    required this.size,
  });

  final String? crestUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.82),
        border: Border.all(
          color: UltrasAppTheme.outlineStrong,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: crestUrl == null
            ? Image.asset(
                kUltrasLogoAsset,
                fit: BoxFit.cover,
              )
            : Image.network(
                crestUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) {
                  return Image.asset(
                    kUltrasLogoAsset,
                    fit: BoxFit.cover,
                  );
                },
              ),
      ),
    );
  }
}

