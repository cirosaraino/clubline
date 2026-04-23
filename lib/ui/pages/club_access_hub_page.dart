import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../data/club_repository.dart';
import '../../data/profile_setup_draft_store.dart';
import '../widgets/app_chrome.dart';
import '../widgets/clubline_brand_logo.dart';
import 'club_create_page.dart';
import 'club_join_page.dart';

enum _ClubAccessMenuAction { editPlayer, deleteAccount, signOut }

class ClubAccessHubPage extends StatefulWidget {
  const ClubAccessHubPage({
    super.key,
    required this.onOpenPlayerSetup,
    required this.onDeleteAccount,
  });

  final Future<void> Function() onOpenPlayerSetup;
  final Future<void> Function() onDeleteAccount;

  @override
  State<ClubAccessHubPage> createState() => _ClubAccessHubPageState();
}

class _ClubAccessHubPageState extends State<ClubAccessHubPage> {
  final ClubRepository repository = ClubRepository();
  bool isCancellingJoinRequest = false;

  Future<void> _openCreateClub() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ClubCreatePage()),
    );

    if (created == true && mounted) {
      await AppSessionScope.read(context).refresh(showLoadingState: false);
    }
  }

  Future<void> _openJoinClub() async {
    final requested = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ClubJoinPage()),
    );

    if (requested == true && mounted) {
      await AppSessionScope.read(context).refresh(showLoadingState: false);
    }
  }

  Future<void> _openPlayerSetup() {
    return widget.onOpenPlayerSetup();
  }

  void _openPlayerSetupAction() {
    unawaited(_openPlayerSetup());
  }

  Future<void> _cancelPendingJoinRequest() async {
    final session = AppSessionScope.read(context);
    final pendingJoinRequest = session.pendingJoinRequest;
    if (pendingJoinRequest == null) {
      return;
    }

    setState(() {
      isCancellingJoinRequest = true;
    });

    try {
      await repository.cancelJoinRequest(pendingJoinRequest.id);
      await session.refresh(showLoadingState: false);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Richiesta annullata.')));
    } finally {
      if (mounted) {
        setState(() {
          isCancellingJoinRequest = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await AppSessionScope.read(context).signOut();
  }

  Future<void> _handleMenuAction(_ClubAccessMenuAction action) async {
    switch (action) {
      case _ClubAccessMenuAction.editPlayer:
        await _openPlayerSetup();
        return;
      case _ClubAccessMenuAction.deleteAccount:
        await widget.onDeleteAccount();
        return;
      case _ClubAccessMenuAction.signOut:
        await _signOut();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final pendingJoinRequest = session.pendingJoinRequest;
    final email = session.currentUserEmail;
    final playerIdentity = session.profileSetupDraft;
    final hasPlayerIdentity = playerIdentity != null;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Clubline'),
        actions: [
          PopupMenuButton<_ClubAccessMenuAction>(
            tooltip: 'Menu account',
            icon: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person_outline, size: 18),
            ),
            onSelected: _handleMenuAction,
            itemBuilder: (_) => [
              PopupMenuItem<_ClubAccessMenuAction>(
                value: _ClubAccessMenuAction.editPlayer,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    hasPlayerIdentity ? 'Modifica giocatore' : 'Crea giocatore',
                  ),
                ),
              ),
              const PopupMenuItem<_ClubAccessMenuAction>(
                value: _ClubAccessMenuAction.deleteAccount,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_outlined),
                  title: Text('Cancella account'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<_ClubAccessMenuAction>(
                value: _ClubAccessMenuAction.signOut,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeroPanel(
            eyebrow: 'Onboarding',
            title: hasPlayerIdentity
                ? 'Il tuo giocatore è pronto'
                : 'Prima crea il tuo giocatore',
            subtitle: hasPlayerIdentity
                ? 'Ora puoi creare un club oppure chiedere di entrare in una squadra già esistente.'
                : 'Completa una sola volta il profilo giocatore. Clubline riuserà quei dati in tutti i flussi successivi.',
            media: Center(
              child: ClublineBrandLogo(
                width: AppResponsive.isCompact(context) ? 176 : 220,
              ),
            ),
            badges: [
              if (email != null && email.isNotEmpty)
                AppStatusBadge(label: email, tone: AppStatusTone.info),
              AppStatusBadge(
                label: hasPlayerIdentity
                    ? 'Giocatore pronto'
                    : 'Giocatore da creare',
                tone: hasPlayerIdentity
                    ? AppStatusTone.success
                    : AppStatusTone.warning,
              ),
            ],
            trailing: hasPlayerIdentity
                ? AppSurfaceCard(
                    icon: Icons.badge_outlined,
                    title: 'Profilo salvato',
                    subtitle: 'Identità riusabile per club e richieste.',
                    child: AppDetailsList(
                      items: [
                        AppDetailItem(
                          label: 'Giocatore',
                          value:
                              '${playerIdentity.nome} ${playerIdentity.cognome}',
                          emphasized: true,
                        ),
                        AppDetailItem(
                          label: 'ID console',
                          value: playerIdentity.idConsole,
                          icon: Icons.sports_esports_outlined,
                        ),
                        AppDetailItem(
                          label: 'Maglia',
                          value:
                              '#${playerIdentity.shirtNumber?.toString().padLeft(2, '0') ?? '--'}',
                          icon: Icons.tag_outlined,
                        ),
                        AppDetailItem(
                          label: 'Ruolo',
                          value: playerIdentity.primaryRole ?? '-',
                          icon: Icons.sports_soccer_outlined,
                        ),
                      ],
                    ),
                  )
                : AppSurfaceCard(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Step richiesto',
                    subtitle: 'Senza questo passaggio non puoi proseguire.',
                    child: AppActionButton(
                      label: 'Crea giocatore',
                      icon: Icons.arrow_forward_outlined,
                      expand: true,
                      onPressed: _openPlayerSetupAction,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppResponsiveGrid(
            minChildWidth: 280,
            children: [
              if (!hasPlayerIdentity)
                AppFeatureCard(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Crea il tuo giocatore',
                  message:
                      'Compila identità, maglia e dettagli sportivi una sola volta.',
                  actionLabel: 'Crea giocatore',
                  onAction: _openPlayerSetupAction,
                  emphasized: true,
                )
              else
                _PlayerIdentityCard(
                  draft: playerIdentity,
                  onEdit: _openPlayerSetupAction,
                ),
              if (pendingJoinRequest != null && pendingJoinRequest.isPending)
                AppFeatureCard(
                  icon: Icons.hourglass_top_outlined,
                  title: 'Richiesta in attesa',
                  message: pendingJoinRequest.club == null
                      ? 'La tua richiesta di ingresso è in revisione.'
                      : 'Richiesta inviata a ${pendingJoinRequest.club!.name}.',
                  badge: const AppStatusBadge(
                    label: 'Pending',
                    tone: AppStatusTone.warning,
                  ),
                  actionLabel: isCancellingJoinRequest
                      ? 'Annullamento...'
                      : 'Annulla richiesta',
                  actionIcon: Icons.close_outlined,
                  onAction: isCancellingJoinRequest
                      ? null
                      : _cancelPendingJoinRequest,
                )
              else if (hasPlayerIdentity) ...[
                _HubActionCard(
                  icon: Icons.add_business_outlined,
                  title: 'Crea una squadra',
                  message:
                      'Definisci nome e logo del club. Entrerai subito come capitano.',
                  actionLabel: 'Crea club',
                  onAction: _openCreateClub,
                ),
                _HubActionCard(
                  icon: Icons.group_add_outlined,
                  title: 'Unisciti a una squadra',
                  message:
                      'Cerca il club e invia una richiesta con il giocatore già pronto.',
                  actionLabel: 'Cerca club',
                  onAction: _openJoinClub,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HubActionCard extends StatelessWidget {
  const _HubActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return AppFeatureCard(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      actionIcon: Icons.arrow_forward_outlined,
      onAction: onAction,
      emphasized: true,
    );
  }
}

class _PlayerIdentityCard extends StatelessWidget {
  const _PlayerIdentityCard({required this.draft, required this.onEdit});

  final ProfileSetupDraft draft;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      icon: Icons.badge_outlined,
      title: 'Giocatore pronto',
      subtitle: 'Il tuo profilo è già completo e pronto da usare nei club.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDetailsList(
            items: [
              AppDetailItem(
                label: 'Giocatore',
                value: '${draft.nome} ${draft.cognome}',
                emphasized: true,
              ),
              AppDetailItem(
                label: 'ID console',
                value: draft.idConsole,
                icon: Icons.sports_esports_outlined,
              ),
              AppDetailItem(
                label: 'Maglia',
                value:
                    '#${draft.shirtNumber?.toString().padLeft(2, '0') ?? '--'}',
                icon: Icons.tag_outlined,
              ),
              AppDetailItem(
                label: 'Ruolo principale',
                value: draft.primaryRole ?? '-',
                icon: Icons.sports_soccer_outlined,
              ),
            ],
          ),
          if (draft.secondaryRoles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Secondari: ${draft.secondaryRoles.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppActionButton(
            label: 'Modifica giocatore',
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.secondary,
            expand: AppResponsive.isCompact(context),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}
