import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/api_client.dart';
import '../../data/club_invites_repository.dart';
import '../../data/club_repository.dart';
import '../../data/profile_setup_draft_store.dart';
import '../../models/club_invite.dart';
import '../../models/join_request.dart';
import '../../models/leave_request.dart';
import '../../models/player_profile.dart';
import '../widgets/app_chrome.dart';
import 'invite_player_page.dart';

class ClubManagementPage extends StatefulWidget {
  ClubManagementPage({super.key, ClubInvitesRepository? clubInvitesRepository})
    : clubInvitesRepository = clubInvitesRepository ?? ClubInvitesRepository();

  final ClubInvitesRepository clubInvitesRepository;

  @override
  State<ClubManagementPage> createState() => _ClubManagementPageState();
}

class _ClubManagementPageState extends State<ClubManagementPage> {
  final ClubRepository repository = ClubRepository();
  bool isBusy = false;
  bool _hasRequestedPlayers = false;
  String? _playersLoadError;
  dynamic selectedCaptainMembershipId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasRequestedPlayers) {
      return;
    }

    _hasRequestedPlayers = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_ensurePlayersLoaded());
    });
  }

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

  Future<void> _ensurePlayersLoaded() async {
    try {
      await AppSessionScope.read(context).ensurePlayersLoaded();
      if (!mounted) {
        return;
      }

      setState(() {
        _playersLoadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _playersLoadError = _errorMessage(error);
      });
    }
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
    final isCaptain = session.membership?.isCaptain == true;
    final canManageInvites = session.canManageInvites;
    if (session.isLoadingPlayers && !session.hasResolvedPlayers) {
      return const AppPageScaffold(
        title: 'Gestione club',
        wide: true,
        child: AppLoadingState(label: 'Stiamo caricando i membri del club...'),
      );
    }

    if (_playersLoadError != null && !session.hasResolvedPlayers) {
      return AppPageScaffold(
        title: 'Gestione club',
        wide: true,
        child: AppErrorState(
          title: 'Errore nel caricamento del club',
          message: _playersLoadError!,
          actionLabel: 'Riprova',
          onAction: () {
            unawaited(_ensurePlayersLoaded());
          },
        ),
      );
    }

    final currentUser = session.currentUser;
    final otherMembers = session.players
        .where(
          (player) =>
              player.membershipId != null && player.id != currentUser?.id,
        )
        .toList();
    final primarySections = <Widget>[
      if (canManageInvites)
        _ClubInvitesSectionCard(
          key: const Key('club-management-invites-section'),
          repository: widget.clubInvitesRepository,
        ),
      if (canManageInvites && isCaptain) const SizedBox(height: AppSpacing.md),
      if (isCaptain)
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
    ];
    final secondarySections = <Widget>[
      if (isCaptain)
        _SectionCard(
          icon: Icons.flag_outlined,
          title: 'Trasferisci la fascia',
          subtitle: 'Nomina il nuovo capitano prima di uscire dal club.',
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
                decoration: const InputDecoration(labelText: 'Nuovo capitano'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppActionButton(
                label: 'Trasferisci ruolo',
                icon: Icons.flag_outlined,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: isBusy || selectedCaptainMembershipId == null
                    ? null
                    : _transferCaptain,
              ),
            ],
          ),
        ),
      if (isCaptain) const SizedBox(height: AppSpacing.md),
      if (isCaptain)
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
                    foregroundColor: Theme.of(context).colorScheme.error,
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
    ];

    return AppPageScaffold(
      title: 'Gestione club',
      wide: true,
      child: !isCaptain && !canManageInvites
          ? const AppEmptyState(
              key: Key('club-management-no-access-state'),
              icon: Icons.lock_outline,
              title: 'Nessun permesso gestionale',
              message:
                  'Questo account non ha autorizzazioni staff disponibili in questa area.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClubManagementHeader(
                  title: isCaptain ? 'Gestione club' : 'Gestione inviti club',
                  subtitle: isCaptain
                      ? 'Approva richieste, invita player e gestisci il club.'
                      : 'Qui puoi cercare player registrati, inviare inviti e monitorare quelli pendenti.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (secondarySections.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: primarySections,
                  )
                else
                  AppAdaptiveColumns(
                    breakpoint: 1080,
                    gap: AppResponsive.sectionGap(context),
                    flex: const [3, 2],
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: primarySections,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: secondarySections,
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

String _clubManagementErrorMessage(Object error) {
  if (error is ApiException) {
    final rawMessage = error.message.trim();
    final normalizedMessage = rawMessage.toLowerCase();
    switch (error.code?.trim()) {
      case 'pending_club_invite_exists':
        return 'Esiste gia un invito pendente per questo player nel club.';
      case 'target_user_has_active_membership':
      case 'active_membership_exists':
        return 'Questo utente appartiene gia a un club attivo.';
      case 'pending_join_request_same_club':
        return 'Questo player ha gia una richiesta di ingresso pendente per questo club.';
      case 'pending_join_request_other_club':
        return 'Questo player ha gia una richiesta di ingresso pendente verso un altro club.';
      case 'invite_management_forbidden':
        return 'Non hai i permessi per gestire gli inviti del club.';
      case 'invite_not_found':
        return 'L invito non e piu disponibile.';
      case 'invite_not_pending':
        return 'Questo invito non e piu pendente.';
    }

    if (error.statusCode == 403) {
      return 'Non hai i permessi per gestire gli inviti del club.';
    }
    if (normalizedMessage.contains('gia un invito pendente')) {
      return 'Esiste gia un invito pendente per questo player nel club.';
    }
    if (normalizedMessage.contains('club attivo')) {
      return 'Questo utente appartiene gia a un club attivo.';
    }
    if (normalizedMessage.contains(
      'richiesta di ingresso pendente per questo club',
    )) {
      return 'Questo player ha gia una richiesta di ingresso pendente per questo club.';
    }
    if (normalizedMessage.contains('verso un altro club')) {
      return 'Questo player ha gia una richiesta di ingresso pendente verso un altro club.';
    }
    if (normalizedMessage.contains('non trovato')) {
      return 'L invito non e piu disponibile.';
    }
    if (normalizedMessage.contains('non pendente') ||
        normalizedMessage.contains('gia stata gestita')) {
      return 'Questo invito non e piu pendente.';
    }
    if (rawMessage.isNotEmpty) {
      return rawMessage;
    }
  }

  final fallback = error.toString().trim();
  if (fallback.isEmpty) {
    return 'Operazione non riuscita. Riprova tra un attimo.';
  }

  return fallback;
}

String _clubInviteStatusLabel(ClubInviteStatus status) {
  switch (status) {
    case ClubInviteStatus.accepted:
      return 'Accettato';
    case ClubInviteStatus.declined:
      return 'Rifiutato';
    case ClubInviteStatus.revoked:
      return 'Revocato';
    case ClubInviteStatus.expired:
      return 'Scaduto';
    case ClubInviteStatus.pending:
      return 'In attesa';
  }
}

AppStatusTone _clubInviteStatusTone(ClubInviteStatus status) {
  switch (status) {
    case ClubInviteStatus.accepted:
      return AppStatusTone.success;
    case ClubInviteStatus.declined:
    case ClubInviteStatus.revoked:
    case ClubInviteStatus.expired:
      return AppStatusTone.warning;
    case ClubInviteStatus.pending:
      return AppStatusTone.info;
  }
}

String _formatInviteDateTime(DateTime? value) {
  const monthLabels = [
    'gen',
    'feb',
    'mar',
    'apr',
    'mag',
    'giu',
    'lug',
    'ago',
    'set',
    'ott',
    'nov',
    'dic',
  ];

  if (value == null) {
    return 'Data non disponibile';
  }

  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = monthLabels[localValue.month - 1];
  final year = localValue.year.toString();
  final hours = localValue.hour.toString().padLeft(2, '0');
  final minutes = localValue.minute.toString().padLeft(2, '0');

  return '$day $month $year • $hours:$minutes';
}

class _ClubManagementHeader extends StatelessWidget {
  const _ClubManagementHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      eyebrow: 'Staff tools',
      title: title,
      subtitle: subtitle,
    );
  }
}

class _ClubInvitesSectionCard extends StatefulWidget {
  const _ClubInvitesSectionCard({super.key, required this.repository});

  final ClubInvitesRepository repository;

  @override
  State<_ClubInvitesSectionCard> createState() =>
      _ClubInvitesSectionCardState();
}

class _ClubInvitesSectionCardState extends State<_ClubInvitesSectionCard> {
  final Set<String> _revokingInviteIds = <String>{};

  List<ClubInvite> invites = const [];
  ClubInviteListStatus selectedStatus = ClubInviteListStatus.pending;
  bool isLoading = true;
  String? errorMessage;
  int _lastHandledSyncRevision = 0;

  @override
  void initState() {
    super.initState();
    AppDataSync.instance.addListener(_handleAppDataSync);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadInvites());
    });
  }

  @override
  void dispose() {
    AppDataSync.instance.removeListener(_handleAppDataSync);
    super.dispose();
  }

  void _handleAppDataSync() {
    final change = AppDataSync.instance.latestChange;
    if (change == null || change.revision == _lastHandledSyncRevision) {
      return;
    }
    if (!change.affects({AppDataScope.invites})) {
      return;
    }

    _lastHandledSyncRevision = change.revision;
    unawaited(_loadInvites());
  }

  Future<void> _loadInvites() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await widget.repository.getSentInvites(
        status: selectedStatus,
        limit: 50,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        invites = result.invites;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = _clubManagementErrorMessage(error);
        isLoading = false;
      });
    }
  }

  Future<void> _changeFilter(ClubInviteListStatus nextStatus) async {
    if (selectedStatus == nextStatus) {
      return;
    }

    setState(() {
      selectedStatus = nextStatus;
    });
    await _loadInvites();
  }

  void _upsertInvite(ClubInvite invite) {
    setState(() {
      if (selectedStatus == ClubInviteListStatus.pending && !invite.isPending) {
        invites = invites
            .where((entry) => '${entry.id}' != '${invite.id}')
            .toList(growable: false);
        return;
      }

      final existingIndex = invites.indexWhere(
        (entry) => '${entry.id}' == '${invite.id}',
      );
      if (existingIndex == -1) {
        invites = [invite, ...invites];
        return;
      }

      final nextInvites = invites.toList(growable: false);
      nextInvites[existingIndex] = invite;
      invites = nextInvites;
    });
  }

  Future<void> _openInvitePlayerPage() async {
    final createdInvite = await Navigator.of(context).push<ClubInvite>(
      MaterialPageRoute(
        builder: (_) => InvitePlayerPage(repository: widget.repository),
      ),
    );

    if (createdInvite == null || !mounted) {
      return;
    }

    _upsertInvite(createdInvite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invito inviato a ${createdInvite.fullName}.')),
    );
    AppDataSync.instance.notifyDataChanged({
      AppDataScope.invites,
    }, reason: 'club_invite_created_local');
  }

  Future<void> _revokeInvite(ClubInvite invite) async {
    final shouldRevoke = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoca invito'),
        content: Text(
          'Vuoi davvero revocare l invito inviato a ${invite.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('club-management-revoke-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revoca'),
          ),
        ],
      ),
    );

    if (shouldRevoke != true) {
      return;
    }

    final inviteId = '${invite.id}';
    setState(() {
      _revokingInviteIds.add(inviteId);
    });

    try {
      final updatedInvite = await widget.repository.revokeInvite(invite.id);
      if (!mounted) {
        return;
      }

      _upsertInvite(updatedInvite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invito revocato per ${updatedInvite.fullName}.'),
        ),
      );
      AppDataSync.instance.notifyDataChanged({
        AppDataScope.invites,
      }, reason: 'club_invite_revoked_local');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _clubManagementErrorMessage(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (error is ApiException && error.statusCode == 409) {
        unawaited(_loadInvites());
      }
    } finally {
      if (mounted) {
        setState(() {
          _revokingInviteIds.remove(inviteId);
        });
      }
    }
  }

  Widget _buildInviteTile(ClubInvite invite) {
    final inviteId = '${invite.id}';
    final isRevoking = _revokingInviteIds.contains(inviteId);

    return Container(
      key: Key('club-management-sent-invite-$inviteId'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  invite.fullName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              AppStatusBadge(
                label: _clubInviteStatusLabel(invite.status),
                tone: _clubInviteStatusTone(invite.status),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            (invite.targetIdConsole ?? '').trim().isNotEmpty
                ? 'ID console: ${invite.targetIdConsole}'
                : 'Invito player nel club.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: ClublineAppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          AppDetailsList(
            items: [
              AppDetailItem(
                label: 'Stato',
                value: _clubInviteStatusLabel(invite.status),
                icon: Icons.mark_email_read_outlined,
              ),
              AppDetailItem(
                label: 'Creato',
                value: _formatInviteDateTime(invite.createdAt),
                icon: Icons.schedule_outlined,
              ),
            ],
          ),
          if (invite.isPending) ...[
            const SizedBox(height: 10),
            AppActionButton(
              key: Key('club-management-revoke-invite-$inviteId'),
              label: isRevoking ? 'Revoca in corso...' : 'Revoca invito',
              icon: Icons.close_outlined,
              variant: AppButtonVariant.secondary,
              expand: true,
              onPressed: isRevoking ? null : () => _revokeInvite(invite),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = invites.where((invite) => invite.isPending).length;

    return _SectionCard(
      icon: Icons.mail_outline,
      title: 'Inviti player',
      subtitle:
          'Cerca player registrati, invia inviti e monitora quelli pendenti.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppCountPill(label: 'Totali', value: '${invites.length}'),
              AppCountPill(
                label: 'Pendenti',
                value: '$pendingCount',
                emphasized: pendingCount > 0,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppAdaptiveColumns(
            breakpoint: 720,
            gap: AppSpacing.sm,
            flex: const [2, 1],
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ClubInviteListStatus>(
                  segments: const [
                    ButtonSegment<ClubInviteListStatus>(
                      value: ClubInviteListStatus.pending,
                      label: Text('Pendenti'),
                      icon: Icon(Icons.schedule_outlined),
                    ),
                    ButtonSegment<ClubInviteListStatus>(
                      value: ClubInviteListStatus.all,
                      label: Text('Tutti'),
                      icon: Icon(Icons.inbox_outlined),
                    ),
                  ],
                  selected: {selectedStatus},
                  onSelectionChanged: isLoading
                      ? null
                      : (selection) {
                          unawaited(_changeFilter(selection.first));
                        },
                ),
              ),
              AppActionButton(
                key: const Key('club-management-open-invite-player'),
                label: 'Invita player',
                icon: Icons.person_add_alt_1_outlined,
                expand: true,
                onPressed: _openInvitePlayerPage,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isLoading)
            const AppLoadingState(
              label: 'Stiamo caricando gli inviti inviati...',
            )
          else if (errorMessage != null)
            AppErrorState(
              title: 'Impossibile caricare gli inviti',
              message: errorMessage!,
              actionLabel: 'Riprova',
              onAction: _loadInvites,
            )
          else if (invites.isEmpty)
            AppEmptyState(
              key: const Key('club-management-sent-invites-empty-state'),
              icon: selectedStatus == ClubInviteListStatus.pending
                  ? Icons.mark_email_read_outlined
                  : Icons.inbox_outlined,
              title: selectedStatus == ClubInviteListStatus.pending
                  ? 'Nessun invito pendente'
                  : 'Nessun invito inviato',
              message: selectedStatus == ClubInviteListStatus.pending
                  ? 'Gli inviti pendenti del club appariranno qui.'
                  : 'Quando inizierai a invitare player troverai qui anche lo storico.',
              actionLabel: 'Invita player',
              actionIcon: Icons.person_add_alt_1_outlined,
              onAction: _openInvitePlayerPage,
            )
          else
            RefreshIndicator(
              onRefresh: _loadInvites,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: invites.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _buildInviteTile(invites[index]),
              ),
            ),
        ],
      ),
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
