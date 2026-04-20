import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../data/club_repository.dart';
import '../widgets/app_chrome.dart';
import 'club_create_page.dart';
import 'club_join_page.dart';

class ClubAccessHubPage extends StatefulWidget {
  const ClubAccessHubPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final pendingJoinRequest = session.pendingJoinRequest;
    final email = session.currentUserEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubline'),
        actions: [
          IconButton(
            tooltip: 'Esci',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_outlined),
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
                  Text(
                    'Benvenuto su Clubline',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    email == null || email.isEmpty
                        ? 'Per continuare devi creare un club o chiedere di entrare in un club esistente.'
                        : 'Account attivo: $email. Ora scegli se creare il tuo club o chiedere l ingresso in uno esistente.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  if (pendingJoinRequest != null &&
                      pendingJoinRequest.isPending) ...[
                    AppStatusCard(
                      icon: Icons.hourglass_top_outlined,
                      title: 'Richiesta in attesa',
                      message: pendingJoinRequest.club == null
                          ? 'La tua richiesta di ingresso è in revisione.'
                          : 'Hai inviato una richiesta per ${pendingJoinRequest.club!.name}. Appena il capitano la gestirà, ti porteremo dentro il club.',
                      actionLabel: isCancellingJoinRequest
                          ? 'Annullamento...'
                          : 'Annulla richiesta',
                      actionIcon: Icons.close_outlined,
                      actionLoading: isCancellingJoinRequest,
                      onAction: isCancellingJoinRequest
                          ? null
                          : _cancelPendingJoinRequest,
                    ),
                  ] else ...[
                    _HubActionCard(
                      icon: Icons.add_business_outlined,
                      title: 'Crea un nuovo club',
                      message:
                          'Scegli nome e logo del club, poi completa i dati essenziali del capitano. Il resto lo potrai aggiungere dopo.',
                      actionLabel: 'Crea club',
                      onAction: _openCreateClub,
                    ),
                    const SizedBox(height: 14),
                    _HubActionCard(
                      icon: Icons.group_add_outlined,
                      title: 'Unisciti a un club esistente',
                      message:
                          'Cerca un club, invia la tua richiesta di ingresso e attendi l approvazione del capitano.',
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
