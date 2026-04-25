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
          const _CaptainDashboardHeader(),
          const SizedBox(height: AppSpacing.md),
          AppAdaptiveColumns(
            breakpoint: 1080,
            gap: AppResponsive.sectionGap(context),
            flex: const [3, 2],
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RequestsSectionCard(
                    joinRequests: session.captainPendingJoinRequests,
                    leaveRequests: session.captainPendingLeaveRequests,
                    players: session.players,
                    busy: isBusy,
                    onApproveJoin: _approveJoinRequest,
                    onRejectJoin: _rejectJoinRequest,
                    onApproveLeave: _approveLeaveRequest,
                    onRejectLeave: _rejectLeaveRequest,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    icon: Icons.flag_outlined,
                    title: 'Trasferisci la fascia',
                    subtitle:
                        'Nomina il nuovo capitano prima di uscire dal club.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: AppSpacing.sm),
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
                    icon: Icons.warning_amber_outlined,
                    title: 'Zona sensibile',
                    subtitle: 'Usala solo quando resti l unico membro attivo.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppBanner(
                          message:
                              'Puoi eliminare il club solo se sei l unico membro attivo rimasto.',
                          tone: AppStatusTone.warning,
                          icon: Icons.warning_amber_outlined,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isBusy ? null : _deleteCurrentClub,
                            icon: const Icon(Icons.delete_outline),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.34),
                              ),
                            ),
                            label: const Text('Elimina club'),
                          ),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      child: child,
    );
  }
}

class _CaptainDashboardHeader extends StatelessWidget {
  const _CaptainDashboardHeader();

  @override
  Widget build(BuildContext context) {
    return const AppPageHeader(
      eyebrow: 'Captain tools',
      title: 'Dashboard capitano',
      subtitle: 'Approva richieste e gestisci il club.',
    );
  }
}

class _RequestsSectionCard extends StatelessWidget {
  const _RequestsSectionCard({
    required this.joinRequests,
    required this.leaveRequests,
    required this.players,
    required this.busy,
    required this.onApproveJoin,
    required this.onRejectJoin,
    required this.onApproveLeave,
    required this.onRejectLeave,
  });

  final List<JoinRequest> joinRequests;
  final List<LeaveRequest> leaveRequests;
  final List<PlayerProfile> players;
  final bool busy;
  final ValueChanged<JoinRequest> onApproveJoin;
  final ValueChanged<JoinRequest> onRejectJoin;
  final ValueChanged<LeaveRequest> onApproveLeave;
  final ValueChanged<LeaveRequest> onRejectLeave;

  @override
  Widget build(BuildContext context) {
    final pendingTotal = joinRequests.length + leaveRequests.length;

    return _SectionCard(
      icon: Icons.inbox_outlined,
      title: 'Richieste',
      subtitle: pendingTotal == 0
          ? 'Nessuna richiesta pendente.'
          : 'Gestisci ingressi e uscite in attesa.',
      trailing: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          AppCountPill(
            label: 'Ingressi',
            value: '${joinRequests.length}',
            color: joinRequests.isEmpty ? null : ClublineAppTheme.info,
            emphasized: joinRequests.isNotEmpty,
          ),
          AppCountPill(
            label: 'Uscite',
            value: '${leaveRequests.length}',
            color: leaveRequests.isEmpty ? null : ClublineAppTheme.warning,
            emphasized: leaveRequests.isNotEmpty,
          ),
        ],
      ),
      child: pendingTotal == 0
          ? const AppBanner(
              message: 'Nessuna richiesta da gestire in questo momento.',
              tone: AppStatusTone.info,
              icon: Icons.check_circle_outline,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (joinRequests.isNotEmpty) ...[
                  _RequestGroupHeader(
                    label: 'Ingressi',
                    count: joinRequests.length,
                    tone: AppStatusTone.info,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (var index = 0; index < joinRequests.length; index++) ...[
                    _RequestTile(
                      title:
                          '${joinRequests[index].requestedNome} ${joinRequests[index].requestedCognome}'
                              .trim(),
                      subtitle:
                          joinRequests[index].club?.name ??
                          'Richiesta ingresso club',
                      primaryLabel: 'Approva',
                      secondaryLabel: 'Rifiuta',
                      busy: busy,
                      onPrimary: () => onApproveJoin(joinRequests[index]),
                      onSecondary: () => onRejectJoin(joinRequests[index]),
                    ),
                    if (index < joinRequests.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
                if (joinRequests.isNotEmpty && leaveRequests.isNotEmpty)
                  const SizedBox(height: AppSpacing.md),
                if (leaveRequests.isNotEmpty) ...[
                  _RequestGroupHeader(
                    label: 'Uscite',
                    count: leaveRequests.length,
                    tone: AppStatusTone.warning,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (
                    var index = 0;
                    index < leaveRequests.length;
                    index++
                  ) ...[
                    _RequestTile(
                      title: _memberNameForRequest(
                        players,
                        leaveRequests[index],
                      ),
                      subtitle: 'Richiesta di uscita dal club',
                      primaryLabel: 'Approva',
                      secondaryLabel: 'Rifiuta',
                      busy: busy,
                      onPrimary: () => onApproveLeave(leaveRequests[index]),
                      onSecondary: () => onRejectLeave(leaveRequests[index]),
                    ),
                    if (index < leaveRequests.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            ),
    );
  }
}

class _RequestGroupHeader extends StatelessWidget {
  const _RequestGroupHeader({
    required this.label,
    required this.count,
    required this.tone,
  });

  final String label;
  final int count;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: AppSpacing.xs),
        AppStatusBadge(label: '$count', tone: tone),
      ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClublineAppTheme.outlineSoft),
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
                label: 'In attesa',
                tone: AppStatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: ClublineAppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          AppAdaptiveColumns(
            breakpoint: 540,
            gap: 8,
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
