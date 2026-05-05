import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/api_client.dart';
import '../../data/club_invites_repository.dart';
import '../../models/invite_candidate.dart';
import '../widgets/app_chrome.dart';

class InvitePlayerPage extends StatefulWidget {
  InvitePlayerPage({super.key, ClubInvitesRepository? repository})
    : repository = repository ?? ClubInvitesRepository();

  final ClubInvitesRepository repository;

  @override
  State<InvitePlayerPage> createState() => _InvitePlayerPageState();
}

class _InvitePlayerPageState extends State<InvitePlayerPage> {
  final TextEditingController searchController = TextEditingController();
  final Set<String> _invitingUserIds = <String>{};

  List<InviteCandidate> candidates = const [];
  bool isSearching = false;
  bool hasSearched = false;
  String? errorMessage;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String _errorMessageFrom(Object error) {
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

  String _candidateReasonMessage(InviteCandidateReason? reason) {
    switch (reason) {
      case InviteCandidateReason.pendingJoinRequestSameClub:
        return 'Ha gia una richiesta di ingresso pendente per questo club.';
      case InviteCandidateReason.pendingJoinRequestOtherClub:
        return 'Ha gia una richiesta di ingresso pendente verso un altro club.';
      case null:
        return 'Player invitabile.';
    }
  }

  Future<void> _searchCandidates() async {
    final query = searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        hasSearched = false;
        candidates = const [];
        errorMessage = 'Inserisci almeno 2 caratteri per cercare un player.';
      });
      return;
    }

    setState(() {
      isSearching = true;
      errorMessage = null;
    });

    try {
      final results = await widget.repository.searchCandidates(
        query,
        limit: 20,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        candidates = results;
        hasSearched = true;
        isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = _errorMessageFrom(error);
        isSearching = false;
        hasSearched = true;
      });
    }
  }

  Future<void> _inviteCandidate(InviteCandidate candidate) async {
    final userId = candidate.userId;
    setState(() {
      _invitingUserIds.add(userId);
    });

    try {
      final invite = await widget.repository.createInvite(candidate.userId);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(invite);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessageFrom(error))));
    } finally {
      if (mounted) {
        setState(() {
          _invitingUserIds.remove(userId);
        });
      }
    }
  }

  Widget _buildCandidateCard(InviteCandidate candidate) {
    final isInviting = _invitingUserIds.contains(candidate.userId);

    return Card(
      key: Key('invite-candidate-card-${candidate.userId}'),
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBadge(
                  icon: candidate.invitable
                      ? Icons.person_add_alt_1_outlined
                      : Icons.hourglass_top_outlined,
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
                            label: candidate.invitable
                                ? 'Invitabile'
                                : 'Non invitabile',
                            tone: candidate.invitable
                                ? AppStatusTone.success
                                : AppStatusTone.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        candidate.fullName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _candidateReasonMessage(candidate.reason),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                if ((candidate.idConsole ?? '').trim().isNotEmpty)
                  AppDetailItem(
                    label: 'ID console',
                    value: candidate.idConsole!,
                    icon: Icons.sports_esports_outlined,
                  ),
                if ((candidate.primaryRole ?? '').trim().isNotEmpty)
                  AppDetailItem(
                    label: 'Ruolo principale',
                    value: candidate.primaryRole!,
                    icon: Icons.sports_soccer_outlined,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppActionButton(
              key: Key('invite-candidate-action-${candidate.userId}'),
              label: isInviting ? 'Invio invito...' : 'Invita',
              icon: Icons.mail_outline,
              expand: true,
              onPressed: candidate.invitable && !isInviting
                  ? () => _inviteCandidate(candidate)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (isSearching) {
      return const AppSurfaceCard(
        icon: Icons.search_outlined,
        title: 'Ricerca in corso',
        subtitle: 'Stiamo cercando i player registrati compatibili.',
        child: AppLoadingState(label: 'Caricamento candidati...'),
      );
    }

    if (errorMessage != null) {
      return AppErrorState(
        title: 'Impossibile completare la ricerca',
        message: errorMessage!,
        actionLabel: 'Riprova',
        onAction: _searchCandidates,
      );
    }

    if (!hasSearched) {
      return const AppEmptyState(
        key: Key('invite-player-idle-state'),
        icon: Icons.search_outlined,
        title: 'Cerca un player registrato',
        message:
            'Inserisci almeno 2 caratteri per nome, cognome o ID console e poi avvia la ricerca.',
      );
    }

    if (candidates.isEmpty) {
      return const AppEmptyState(
        key: Key('invite-player-empty-state'),
        icon: Icons.person_search_outlined,
        title: 'Nessun candidato trovato',
        message: 'Prova con un nome diverso o con un ID console piu specifico.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < candidates.length; index++) ...[
          _buildCandidateCard(candidates[index]),
          if (index < candidates.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      key: const Key('invite-player-page'),
      title: 'Invita player',
      wide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPageHeader(
            eyebrow: 'Inviti club',
            title: 'Invita un player registrato',
            subtitle:
                'Cerca per nome, cognome o ID console. Per ora gli inviti funzionano solo verso utenti gia registrati.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSurfaceCard(
            icon: Icons.person_search_outlined,
            title: 'Ricerca candidati',
            subtitle:
                'Mostriamo solo player registrati compatibili con il club.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('invite-player-search-field'),
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Cerca per nome, cognome o ID console',
                    prefixIcon: Icon(Icons.search_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _searchCandidates(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppActionButton(
                  key: const Key('invite-player-search-button'),
                  label: 'Cerca candidati',
                  icon: Icons.search_outlined,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  onPressed: isSearching ? null : _searchCandidates,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildResultsSection(),
        ],
      ),
    );
  }
}
