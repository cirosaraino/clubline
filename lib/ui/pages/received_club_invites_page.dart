import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/api_client.dart';
import '../../data/club_invites_repository.dart';
import '../../models/club_invite.dart';
import '../widgets/app_chrome.dart';

class ReceivedClubInvitesPage extends StatefulWidget {
  ReceivedClubInvitesPage({
    super.key,
    ClubInvitesRepository? repository,
    this.initialStatus = ClubInviteListStatus.pending,
    this.highlightedInviteId,
  }) : repository = repository ?? ClubInvitesRepository();

  final ClubInvitesRepository repository;
  final ClubInviteListStatus initialStatus;
  final dynamic highlightedInviteId;

  @override
  State<ReceivedClubInvitesPage> createState() =>
      _ReceivedClubInvitesPageState();
}

class _ReceivedClubInvitesPageState extends State<ReceivedClubInvitesPage> {
  static const List<String> _monthLabels = [
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

  final Set<String> _acceptingInviteIds = <String>{};
  final Set<String> _decliningInviteIds = <String>{};
  final Map<String, GlobalKey> _inviteKeys = <String, GlobalKey>{};

  List<ClubInvite> invites = const [];
  ClubInviteListStatus selectedStatus = ClubInviteListStatus.pending;
  bool isLoading = true;
  String? errorMessage;
  int _lastHandledSyncRevision = 0;
  bool _hasScrolledToHighlightedInvite = false;

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.initialStatus;
    AppDataSync.instance.addListener(_handleAppDataSync);
    unawaited(_loadInvites());
  }

  @override
  void dispose() {
    AppDataSync.instance.removeListener(_handleAppDataSync);
    super.dispose();
  }

  Future<void> _loadInvites() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await widget.repository.getReceivedInvites(
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
      _maybeRevealHighlightedInvite();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
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

  Future<void> _refreshSessionCounts() async {
    try {
      await AppSessionScope.read(context).refresh(showLoadingState: false);
    } catch (_) {
      // Keep invite actions resilient even if the background session refresh fails.
    }
  }

  void _maybeRevealHighlightedInvite() {
    final highlightedInviteId = widget.highlightedInviteId;
    if (_hasScrolledToHighlightedInvite || highlightedInviteId == null) {
      return;
    }

    _hasScrolledToHighlightedInvite = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final key = _inviteKeys['$highlightedInviteId'];
      final context = key?.currentContext;
      if (context == null) {
        _hasScrolledToHighlightedInvite = false;
        return;
      }

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    });
  }

  Future<void> _changeFilter(ClubInviteListStatus nextStatus) async {
    if (selectedStatus == nextStatus) {
      return;
    }

    setState(() {
      selectedStatus = nextStatus;
      _hasScrolledToHighlightedInvite = false;
    });
    await _loadInvites();
  }

  Future<void> _acceptInvite(ClubInvite invite) async {
    final shouldAccept = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accetta invito'),
        content: Text(
          'Entrerai in ${invite.clubDisplayName} come giocatore attivo. Vuoi continuare?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('received-invite-accept-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accetta'),
          ),
        ],
      ),
    );

    if (shouldAccept != true) {
      return;
    }

    final inviteKey = '${invite.id}';
    setState(() {
      _acceptingInviteIds.add(inviteKey);
    });

    try {
      final result = await widget.repository.acceptInvite(invite.id);
      await _refreshSessionCounts();
      if (!mounted) {
        return;
      }

      final session = AppSessionScope.read(context);
      _applyInviteUpdate(result.invite);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invito accettato. Ora fai parte di ${result.invite.clubDisplayName}.',
          ),
        ),
      );

      if (session.hasClubMembership) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.statusCode == 409
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (error.statusCode == 409) {
        unawaited(_refreshSessionCounts());
        unawaited(_loadInvites());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _acceptingInviteIds.remove(inviteKey);
        });
      }
    }
  }

  Future<void> _declineInvite(ClubInvite invite) async {
    final inviteKey = '${invite.id}';
    setState(() {
      _decliningInviteIds.add(inviteKey);
    });

    try {
      final result = await widget.repository.declineInvite(invite.id);
      await _refreshSessionCounts();
      if (!mounted) {
        return;
      }

      _applyInviteUpdate(result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invito rifiutato.')));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      if (error.statusCode == 409) {
        unawaited(_refreshSessionCounts());
        unawaited(_loadInvites());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _decliningInviteIds.remove(inviteKey);
        });
      }
    }
  }

  void _applyInviteUpdate(ClubInvite updatedInvite) {
    setState(() {
      if (selectedStatus == ClubInviteListStatus.pending &&
          !updatedInvite.isPending) {
        invites = invites
            .where((invite) => '${invite.id}' != '${updatedInvite.id}')
            .toList(growable: false);
        return;
      }

      invites = invites
          .map(
            (invite) => '${invite.id}' == '${updatedInvite.id}'
                ? updatedInvite
                : invite,
          )
          .toList(growable: false);
    });
  }

  AppStatusTone _statusTone(ClubInviteStatus status) {
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

  String _statusLabel(ClubInviteStatus status) {
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

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Data non disponibile';
    }

    final localValue = value.toLocal();
    final day = localValue.day.toString().padLeft(2, '0');
    final month = _monthLabels[localValue.month - 1];
    final year = localValue.year.toString();
    final hours = localValue.hour.toString().padLeft(2, '0');
    final minutes = localValue.minute.toString().padLeft(2, '0');

    return '$day $month $year • $hours:$minutes';
  }

  Widget _buildScrollableBody(List<Widget> children) {
    return AppPageBackground(
      child: RefreshIndicator(
        onRefresh: _loadInvites,
        child: AppContentFrame(
          wide: true,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppResponsive.pagePadding(context, top: 24),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final pendingCount = invites.where((invite) => invite.isPending).length;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(ClubInvite invite) {
    final inviteId = '${invite.id}';
    final isHighlighted =
        widget.highlightedInviteId != null &&
        '${widget.highlightedInviteId}' == inviteId;
    final isAccepting = _acceptingInviteIds.contains(inviteId);
    final isDeclining = _decliningInviteIds.contains(inviteId);
    final canActOnInvite = invite.isPending && !isAccepting && !isDeclining;

    final cardKey = _inviteKeys.putIfAbsent(inviteId, GlobalKey.new);

    return KeyedSubtree(
      key: Key('received-invite-card-$inviteId'),
      child: Card(
        key: cardKey,
        color: isHighlighted
            ? ClublineAppTheme.surfaceRaised
            : Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isHighlighted
                ? ClublineAppTheme.goldSoft.withValues(alpha: 0.55)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
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
                    icon: invite.isPending
                        ? Icons.mail_outline
                        : Icons.mark_email_read_outlined,
                    backgroundColor: isHighlighted
                        ? ClublineAppTheme.gold.withValues(alpha: 0.18)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            AppStatusBadge(
                              label: _statusLabel(invite.status),
                              tone: _statusTone(invite.status),
                            ),
                            if (isHighlighted)
                              const AppStatusBadge(
                                label: 'Nuovo',
                                tone: AppStatusTone.success,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          invite.clubDisplayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invite.targetPrimaryRole?.trim().isNotEmpty == true
                              ? 'Ruolo proposto: ${invite.targetPrimaryRole}'
                              : 'Invito ricevuto per entrare nel club.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: ClublineAppTheme.textMuted,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDetailsList(
                items: [
                  AppDetailItem(
                    label: 'Invito creato',
                    value: _formatDateTime(invite.createdAt),
                    icon: Icons.schedule_outlined,
                  ),
                ],
              ),
              if (invite.isPending) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppActionButton(
                      key: Key('received-invite-accept-$inviteId'),
                      label: isAccepting ? 'Accettazione...' : 'Accetta',
                      icon: Icons.check_circle_outline,
                      onPressed: canActOnInvite
                          ? () => _acceptInvite(invite)
                          : null,
                    ),
                    AppActionButton(
                      key: Key('received-invite-decline-$inviteId'),
                      label: isDeclining ? 'Rifiuto...' : 'Rifiuta',
                      icon: Icons.close_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: canActOnInvite
                          ? () => _declineInvite(invite)
                          : null,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final header = const AppPageHeader(
      eyebrow: 'Accesso club',
      title: 'Inviti ricevuti',
      subtitle:
          'Qui trovi gli inviti che puoi ancora accettare o rifiutare direttamente dall app.',
    );

    if (isLoading) {
      return const AppPageBackground(
        child: AppLoadingState(label: 'Stiamo caricando gli inviti...'),
      );
    }

    if (errorMessage != null) {
      return _buildScrollableBody([
        header,
        const SizedBox(height: AppSpacing.lg),
        _buildHeaderCard(),
        const SizedBox(height: AppSpacing.lg),
        AppErrorState(
          title: 'Impossibile caricare gli inviti',
          message: errorMessage!,
          actionLabel: 'Riprova',
          onAction: _loadInvites,
        ),
      ]);
    }

    if (invites.isEmpty) {
      return _buildScrollableBody([
        header,
        const SizedBox(height: AppSpacing.lg),
        _buildHeaderCard(),
        const SizedBox(height: AppSpacing.lg),
        AppEmptyState(
          key: const Key('received-invites-empty-state'),
          icon: selectedStatus == ClubInviteListStatus.pending
              ? Icons.mark_email_read_outlined
              : Icons.inbox_outlined,
          title: selectedStatus == ClubInviteListStatus.pending
              ? 'Nessun invito pendente'
              : 'Nessun invito ricevuto',
          message: selectedStatus == ClubInviteListStatus.pending
              ? 'Quando riceverai nuovi inviti li troverai qui, pronti da accettare o rifiutare.'
              : 'Lo storico inviti apparira qui appena il tuo account ricevera i primi inviti.',
        ),
      ]);
    }

    return _buildScrollableBody([
      header,
      const SizedBox(height: AppSpacing.lg),
      _buildHeaderCard(),
      const SizedBox(height: AppSpacing.lg),
      for (final invite in invites) ...[
        _buildInviteCard(invite),
        const SizedBox(height: AppSpacing.md),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('received-invites-page'),
      appBar: AppBar(title: const Text('Inviti ricevuti')),
      body: _buildBody(),
    );
  }
}
