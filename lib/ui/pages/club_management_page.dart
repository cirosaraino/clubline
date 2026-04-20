import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../data/club_repository.dart';
import '../../models/join_request.dart';
import '../../models/leave_request.dart';
import '../../models/player_profile.dart';
import '../widgets/app_chrome.dart';

class ClubManagementPage extends StatefulWidget {
  const ClubManagementPage({super.key});

  @override
  State<ClubManagementPage> createState() => _ClubManagementPageState();
}

class _ClubManagementPageState extends State<ClubManagementPage> {
  final ClubRepository repository = ClubRepository();
  bool isBusy = false;
  dynamic selectedCaptainMembershipId;

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final session = AppSessionScope.read(context);
    setState(() {
      isBusy = true;
    });

    try {
      await action();
      await session.refresh(showLoadingState: false);

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  Future<void> _approveJoinRequest(JoinRequest request) {
    return _runAction(
      () => repository.approveJoinRequest(request.id),
      successMessage: 'Richiesta approvata.',
    );
  }

  Future<void> _rejectJoinRequest(JoinRequest request) {
    return _runAction(
      () => repository.rejectJoinRequest(request.id),
      successMessage: 'Richiesta rifiutata.',
    );
  }

  Future<void> _approveLeaveRequest(LeaveRequest request) {
    return _runAction(
      () => repository.approveLeaveRequest(request.id),
      successMessage: 'Uscita approvata.',
    );
  }

  Future<void> _rejectLeaveRequest(LeaveRequest request) {
    return _runAction(
      () => repository.rejectLeaveRequest(request.id),
      successMessage: 'Richiesta di uscita rifiutata.',
    );
  }

  Future<void> _transferCaptain() async {
    if (selectedCaptainMembershipId == null) {
      return;
    }

    final navigator = Navigator.of(context);
    await _runAction(
      () => repository.transferCaptain(selectedCaptainMembershipId),
      successMessage: 'Ruolo di capitano trasferito.',
    );

    if (mounted) {
      navigator.pop();
    }
  }

  Future<void> _deleteCurrentClub() {
    return _runAction(
      () => repository.deleteCurrentClub(),
      successMessage: 'Club eliminato.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final currentUser = session.currentUser;
    final otherMembers = session.players
        .where(
          (player) =>
              player.membershipId != null &&
              player.id != currentUser?.id,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard capitano'),
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
                  _SectionCard(
                    title: 'Richieste di ingresso',
                    child: session.captainPendingJoinRequests.isEmpty
                        ? const Text('Nessuna richiesta pendente.')
                        : Column(
                            children: [
                              for (final request in session.captainPendingJoinRequests) ...[
                                _RequestTile(
                                  title: '${request.requestedNome} ${request.requestedCognome}'.trim(),
                                  subtitle: request.club?.name ?? 'Richiesta ingresso club',
                                  primaryLabel: 'Approva',
                                  secondaryLabel: 'Rifiuta',
                                  busy: isBusy,
                                  onPrimary: () => _approveJoinRequest(request),
                                  onSecondary: () => _rejectJoinRequest(request),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Richieste di uscita',
                    child: session.captainPendingLeaveRequests.isEmpty
                        ? const Text('Nessuna richiesta pendente.')
                        : Column(
                            children: [
                              for (final request in session.captainPendingLeaveRequests) ...[
                                _RequestTile(
                                  title: _memberNameForRequest(session.players, request),
                                  subtitle: 'Richiesta di uscita dal club',
                                  primaryLabel: 'Approva',
                                  secondaryLabel: 'Rifiuta',
                                  busy: isBusy,
                                  onPrimary: () => _approveLeaveRequest(request),
                                  onSecondary: () => _rejectLeaveRequest(request),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Trasferisci la fascia',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prima di uscire dal club devi nominare un nuovo capitano.',
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<dynamic>(
                          initialValue: selectedCaptainMembershipId,
                          items: [
                            for (final player in otherMembers)
                              DropdownMenuItem<dynamic>(
                                value: player.membershipId,
                                child: Text(player.fullName),
                              ),
                          ],
                          onChanged: isBusy
                              ? null
                              : (value) {
                                  setState(() {
                                    selectedCaptainMembershipId = value;
                                  });
                                },
                          decoration: const InputDecoration(
                            labelText: 'Nuovo capitano',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isBusy || selectedCaptainMembershipId == null
                                ? null
                                : _transferCaptain,
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Trasferisci ruolo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Zona sensibile',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Puoi eliminare il club solo se sei l unico membro attivo rimasto.',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isBusy ? null : _deleteCurrentClub,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Elimina club'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _memberNameForRequest(List<PlayerProfile> players, LeaveRequest request) {
    final matchingPlayer = players.firstWhere(
      (player) => '${player.membershipId}' == '${request.membershipId}',
      orElse: () => const PlayerProfile(
        nome: 'Membro',
        cognome: 'club',
      ),
    );

    return matchingPlayer.fullName;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.busy,
  });

  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onPrimary,
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onSecondary,
                  child: Text(secondaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
