import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/api_client.dart';
import '../../data/club_repository.dart';
import '../../data/profile_setup_draft_store.dart';
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

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'Operazione non riuscita. Riprova tra un attimo.';
    }

    return message;
  }

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

      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text(_errorMessage(error))));
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

  Future<void> _deleteCurrentClub() async {
    final messenger = ScaffoldMessenger.of(context);
    final session = AppSessionScope.read(context);
    final currentUser = session.currentUser;
    setState(() {
      isBusy = true;
    });

    try {
      if (currentUser != null && currentUser.hasConsoleId) {
        await ProfileSetupDraftStore.instance.save(
          ProfileSetupDraft(
            nome: currentUser.nome,
            cognome: currentUser.cognome,
            idConsole: currentUser.idConsole!,
            shirtNumber: currentUser.shirtNumber,
            primaryRole: currentUser.primaryRole,
            secondaryRoles: currentUser.secondaryRoles,
            accountEmail: session.currentUserEmail,
          ),
        );
      }
      await repository.deleteCurrentClub();
      await session.refresh(showLoadingState: false);

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(const SnackBar(content: Text('Club eliminato.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final currentUser = session.currentUser;
    final otherMembers = session.players
        .where(
          (player) =>
              player.membershipId != null && player.id != currentUser?.id,
        )
        .toList();

    return AppPageScaffold(
      title: 'Dashboard capitano',
      wide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPageHeader(
            eyebrow: 'Captain Tools',
            title: 'Gestisci richieste e ruoli del club',
            subtitle:
                'Approva ingressi, gestisci le uscite, trasferisci la fascia e controlla le azioni sensibili del club.',
            trailing: AppResponsiveGrid(
              minChildWidth: 180,
              children: [
                AppCountPill(
                  label: 'Ingressi',
                  value: '${session.captainPendingJoinRequests.length}',
                  icon: Icons.group_add_outlined,
                  emphasized: true,
                ),
                AppCountPill(
                  label: 'Uscite',
                  value: '${session.captainPendingLeaveRequests.length}',
                  icon: Icons.exit_to_app_outlined,
                  emphasized: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppAdaptiveColumns(
            breakpoint: 1080,
            gap: AppResponsive.sectionGap(context),
            flex: const [3, 2],
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Richieste di ingresso',
                    child: session.captainPendingJoinRequests.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.group_add_outlined,
                            title: 'Nessuna richiesta pendente',
                            message:
                                'Quando un giocatore chiederà l ingresso al club la richiesta apparirà qui.',
                          )
                        : Column(
                            children: [
                              for (final request
                                  in session.captainPendingJoinRequests) ...[
                                _RequestTile(
                                  title:
                                      '${request.requestedNome} ${request.requestedCognome}'
                                          .trim(),
                                  subtitle:
                                      request.club?.name ??
                                      'Richiesta ingresso club',
                                  primaryLabel: 'Approva',
                                  secondaryLabel: 'Rifiuta',
                                  busy: isBusy,
                                  onPrimary: () => _approveJoinRequest(request),
                                  onSecondary: () =>
                                      _rejectJoinRequest(request),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'Richieste di uscita',
                    child: session.captainPendingLeaveRequests.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.exit_to_app_outlined,
                            title: 'Nessuna richiesta pendente',
                            message:
                                'Le richieste di uscita approvate o rifiutate spariscono automaticamente da questa lista.',
                          )
                        : Column(
                            children: [
                              for (final request
                                  in session.captainPendingLeaveRequests) ...[
                                _RequestTile(
                                  title: _memberNameForRequest(
                                    session.players,
                                    request,
                                  ),
                                  subtitle: 'Richiesta di uscita dal club',
                                  primaryLabel: 'Approva',
                                  secondaryLabel: 'Rifiuta',
                                  busy: isBusy,
                                  onPrimary: () =>
                                      _approveLeaveRequest(request),
                                  onSecondary: () =>
                                      _rejectLeaveRequest(request),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Trasferisci la fascia',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppBanner(
                          message:
                              'Prima di uscire dal club devi nominare un nuovo capitano.',
                          tone: AppStatusTone.info,
                          icon: Icons.info_outline,
                        ),
                        const SizedBox(height: AppSpacing.md),
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
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppActionButton(
                          label: 'Trasferisci ruolo',
                          icon: Icons.flag_outlined,
                          variant: AppButtonVariant.secondary,
                          expand: true,
                          onPressed:
                              isBusy || selectedCaptainMembershipId == null
                              ? null
                              : _transferCaptain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'Zona sensibile',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppBanner(
                          message:
                              'Puoi eliminare il club solo se sei l unico membro attivo rimasto.',
                          tone: AppStatusTone.warning,
                          icon: Icons.warning_amber_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppActionButton(
                          label: 'Elimina club',
                          icon: Icons.delete_outline,
                          variant: AppButtonVariant.danger,
                          expand: true,
                          onPressed: isBusy ? null : _deleteCurrentClub,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _memberNameForRequest(
    List<PlayerProfile> players,
    LeaveRequest request,
  ) {
    final matchingPlayer = players.firstWhere(
      (player) => '${player.membershipId}' == '${request.membershipId}',
      orElse: () => const PlayerProfile(nome: 'Membro', cognome: 'club'),
    );

    return matchingPlayer.fullName;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(title: title, child: child);
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
        border: Border.all(color: UltrasAppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const AppStatusBadge(
                label: 'Pending',
                tone: AppStatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: UltrasAppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          AppAdaptiveColumns(
            breakpoint: 620,
            gap: 10,
            children: [
              AppActionButton(
                label: primaryLabel,
                icon: Icons.check_outlined,
                expand: true,
                onPressed: busy ? null : onPrimary,
              ),
              AppActionButton(
                label: secondaryLabel,
                icon: Icons.close_outlined,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: busy ? null : onSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
