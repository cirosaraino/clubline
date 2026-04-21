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
    final compact = AppResponsive.isCompact(context);
    final session = AppSessionScope.of(context);
    final pendingJoinRequest = session.pendingJoinRequest;
    final email = session.currentUserEmail;
    final playerIdentity = session.profileSetupDraft;
    final hasPlayerIdentity = playerIdentity != null;

    return Scaffold(
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
      body: Stack(
        children: [
          const AppPageBackground(child: SizedBox.expand()),
          SafeArea(
            child: SingleChildScrollView(
              padding: AppResponsive.pagePadding(context, top: 16, bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: ClublineBrandLogo(width: compact ? 176 : 228)),
                  const SizedBox(height: 18),
                  Text(
                    hasPlayerIdentity
                        ? 'Scegli il prossimo passo'
                        : 'Prepara il tuo giocatore',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    email == null || email.isEmpty
                        ? 'Completa il profilo del giocatore e poi scegli se creare una squadra o unirti a una esistente.'
                        : 'Account attivo: $email.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  if (!hasPlayerIdentity) ...[
                    AppStatusCard(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'Prima crea il tuo giocatore',
                      message:
                          'Inserisci una volta sola i dati del giocatore. Dopo potrai scegliere liberamente il club.',
                      actionLabel: 'Crea giocatore',
                      actionIcon: Icons.arrow_forward_outlined,
                      onAction: _openPlayerSetupAction,
                    ),
                  ] else ...[
                    _PlayerIdentityCard(
                      draft: playerIdentity,
                      onEdit: _openPlayerSetupAction,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (pendingJoinRequest != null &&
                      pendingJoinRequest.isPending) ...[
                    AppStatusCard(
                      icon: Icons.hourglass_top_outlined,
                      title: 'Richiesta in attesa',
                      message: pendingJoinRequest.club == null
                          ? 'La tua richiesta di ingresso è in revisione.'
                          : 'Richiesta inviata a ${pendingJoinRequest.club!.name}.',
                      actionLabel: isCancellingJoinRequest
                          ? 'Annullamento...'
                          : 'Annulla richiesta',
                      actionIcon: Icons.close_outlined,
                      actionLoading: isCancellingJoinRequest,
                      onAction: isCancellingJoinRequest
                          ? null
                          : _cancelPendingJoinRequest,
                    ),
                  ] else if (hasPlayerIdentity) ...[
                    _HubActionCard(
                      icon: Icons.add_business_outlined,
                      title: 'Crea una squadra',
                      message:
                          'Imposta nome e logo. Entrerai subito come capitano.',
                      actionLabel: 'Crea club',
                      onAction: _openCreateClub,
                    ),
                    const SizedBox(height: 14),
                    _HubActionCard(
                      icon: Icons.group_add_outlined,
                      title: 'Unisciti a una squadra',
                      message:
                          'Cerca il club e invia la richiesta con il profilo già pronto.',
                      actionLabel: 'Cerca club',
                      onAction: _openJoinClub,
                    ),
                  ],
                ],
              ),
            ),
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
    return AppStatusCard(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      actionIcon: Icons.arrow_forward_outlined,
      onAction: onAction,
    );
  }
}

class _PlayerIdentityCard extends StatelessWidget {
  const _PlayerIdentityCard({required this.draft, required this.onEdit});

  final ProfileSetupDraft draft;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Giocatore pronto',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${draft.nome} ${draft.cognome}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppCountPill(
                  label: 'ID',
                  value: draft.idConsole,
                  icon: Icons.sports_esports_outlined,
                ),
                AppCountPill(
                  label: 'Maglia',
                  value:
                      '#${draft.shirtNumber?.toString().padLeft(2, '0') ?? '--'}',
                  icon: Icons.tag_outlined,
                ),
                AppCountPill(
                  label: 'Ruolo',
                  value: draft.primaryRole,
                  icon: Icons.sports_soccer_outlined,
                ),
              ],
            ),
            if (draft.secondaryRoles.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Secondari: ${draft.secondaryRoles.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica giocatore'),
            ),
          ],
        ),
      ),
    );
  }
}
