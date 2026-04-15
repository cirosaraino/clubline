import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../data/lineup_repository.dart';
import '../../models/lineup.dart';
import '../../models/lineup_player_assignment.dart';
import '../../models/player_profile.dart';
import '../widgets/app_chrome.dart';
import '../widgets/lineup_list_card.dart';
import 'add_lineup_page.dart';
import 'lineup_players_page.dart';

class LineupsPage extends StatefulWidget {
  const LineupsPage({super.key});

  @override
  State<LineupsPage> createState() => _LineupsPageState();
}

class _LineupsPageState extends State<LineupsPage> {
  late final LineupRepository repository;

  List<Lineup> lineups = [];
  final Set<String> collapsedDayKeys = <String>{};
  Map<dynamic, List<LineupPlayerAssignment>> assignmentsByLineupId = {};
  bool isLoading = true;
  bool isDeletingAll = false;
  String? errorMessage;
  int lastHandledSyncRevision = 0;
  bool _isLoadingRequest = false;
  bool _reloadRequested = false;
  bool _hasInitializedDayCollapses = false;

  @override
  void initState() {
    super.initState();
    repository = LineupRepository();
    AppDataSync.instance.addListener(_handleAppDataSync);
    _loadLineups();
  }

  @override
  void dispose() {
    AppDataSync.instance.removeListener(_handleAppDataSync);
    super.dispose();
  }

  void _handleAppDataSync() {
    final change = AppDataSync.instance.latestChange;
    if (change == null || change.revision == lastHandledSyncRevision) return;
    if (!change.affects({AppDataScope.lineups})) return;

    lastHandledSyncRevision = change.revision;
    unawaited(_loadLineups(silent: true));
  }

  Future<void> _loadLineups({bool silent = false}) async {
    if (!mounted) {
      return;
    }

    if (_isLoadingRequest) {
      _reloadRequested = true;
      return;
    }

    _isLoadingRequest = true;
    final showBlockingLoader = !silent || lineups.isEmpty;

    setState(() {
      if (showBlockingLoader) {
        isLoading = true;
      }
      errorMessage = null;
    });

    try {
      final response = await repository.fetchLineups();
      final assignments = await repository.fetchAssignmentsForLineups(
        response.map((lineup) => lineup.id).whereType<dynamic>().toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        lineups = response;
        assignmentsByLineupId = assignments;
        _syncCollapsedDayKeys(response);
        isLoading = false;
        isDeletingAll = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (showBlockingLoader) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
          isDeletingAll = false;
        });
      }
    } finally {
      _isLoadingRequest = false;
      if (_reloadRequested) {
        _reloadRequested = false;
        unawaited(_loadLineups(silent: true));
      }
    }
  }

  String _dayKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _formatDayLabel(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }

  void _syncCollapsedDayKeys(List<Lineup> nextLineups) {
    final allDayKeys = nextLineups.map((lineup) => _dayKey(lineup.matchDateTime)).toSet();

    if (!_hasInitializedDayCollapses) {
      collapsedDayKeys
        ..clear()
        ..addAll(allDayKeys);

      final todayKey = _dayKey(DateTime.now());
      if (collapsedDayKeys.contains(todayKey)) {
        collapsedDayKeys.remove(todayKey);
      }

      _hasInitializedDayCollapses = true;
      return;
    }

    collapsedDayKeys.removeWhere((dayKey) => !allDayKeys.contains(dayKey));
    for (final dayKey in allDayKeys) {
      if (!collapsedDayKeys.contains(dayKey)) {
        collapsedDayKeys.add(dayKey);
      }
    }
  }

  Future<void> _openLineupForm({Lineup? lineup}) async {
    final currentUser = AppSessionScope.read(context).currentUser;
    if (currentUser?.canManageLineups != true) return;

    await _openLineupFormWithOptions(lineup: lineup);
  }

  Future<bool?> _openLineupFormWithOptions({
    Lineup? lineup,
    bool duplicateMode = false,
    List<LineupPlayerAssignment> initialAssignments = const [],
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddLineupPage(
          lineup: lineup,
          duplicateMode: duplicateMode,
          initialAssignments: initialAssignments,
        ),
      ),
    );
    return result;
  }

  Future<void> _openLineupPlayers(Lineup lineup) async {
    final currentUser = AppSessionScope.read(context).currentUser;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => LineupPlayersPage(
          lineup: lineup,
          readOnly: currentUser?.canManageLineups != true,
        ),
      ),
    );
  }

  Future<void> _duplicateLineup(Lineup lineup) async {
    final currentUser = AppSessionScope.read(context).currentUser;
    if (currentUser?.canManageLineups != true) return;

    if (lineup.id == null) {
      setState(() {
        errorMessage = 'Impossibile duplicare la formazione: ID mancante';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final copiedAssignments = await repository.fetchLineupPlayers(lineup.id);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      final duplicatedLineup = Lineup(
        competitionName: lineup.competitionName,
        matchDateTime: lineup.matchDateTime,
        opponentName: lineup.opponentName,
        formationModule: lineup.formationModule,
        notes: lineup.notes,
      );

      await _openLineupFormWithOptions(
        lineup: duplicatedLineup,
        duplicateMode: true,
        initialAssignments: copiedAssignments,
      );
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _deleteLineup(Lineup lineup) async {
    final currentUser = AppSessionScope.read(context).currentUser;
    if (currentUser?.canManageLineups != true) return;

    if (lineup.id == null) {
      setState(() {
        errorMessage = 'Impossibile cancellare la formazione: ID mancante';
      });
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancella formazione'),
        content: Text(
          'Vuoi davvero cancellare la formazione ${lineup.competitionName} (${lineup.formationModule})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await repository.deleteLineup(lineup.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formazione cancellata')),
      );
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.lineups},
        reason: 'lineup_deleted',
      );
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _deleteAllLineups() async {
    final currentUser = AppSessionScope.read(context).currentUser;
    if (currentUser?.canManageLineups != true) return;
    if (lineups.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminazione totale formazioni'),
        content: const Text(
          'Vuoi davvero eliminare tutte le formazioni create? Questa azione non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina tutto'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      isDeletingAll = true;
      errorMessage = null;
    });

    try {
      await repository.deleteAllLineups();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutte le formazioni sono state eliminate')),
      );
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.lineups},
        reason: 'lineup_deleted_all',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isDeletingAll = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AppSessionScope.of(context).currentUser;
    final canManageLineups = currentUser?.canManageLineups ?? false;
    final compact = AppResponsive.isCompact(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formazioni'),
        actions: [
          if (canManageLineups && lineups.isNotEmpty)
            IconButton(
              tooltip: 'Elimina tutte le formazioni',
              onPressed: isDeletingAll ? null : _deleteAllLineups,
              icon: isDeletingAll
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      floatingActionButton: canManageLineups
          ? compact
              ? FloatingActionButton(
                  heroTag: 'lineups_page_fab',
                  onPressed: () => _openLineupForm(),
                  child: const Icon(Icons.add),
                )
              : FloatingActionButton.extended(
                  heroTag: 'lineups_page_fab',
                  onPressed: () => _openLineupForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuova formazione'),
                )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildScrollableBody(
    List<Widget> children, {
    EdgeInsetsGeometry? padding,
  }) {
    return AppPageBackground(
      child: RefreshIndicator(
        onRefresh: _loadLineups,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding ?? AppResponsive.pagePadding(context),
          children: children,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final currentUser = AppSessionScope.of(context).currentUser;
    final canManageLineups = currentUser?.canManageLineups ?? false;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return _buildScrollableBody(
        [
          _LineupsStatusCard(
            icon: Icons.error_outline,
            title: 'Errore nel caricamento delle formazioni',
            message: errorMessage!,
          ),
        ],
        padding: AppResponsive.pagePadding(context, top: 24),
      );
    }

    if (lineups.isEmpty) {
      return _buildScrollableBody(
        const [
          _LineupsStatusCard(
            icon: Icons.stadium_outlined,
            title: 'Nessuna formazione trovata',
            message:
                'Crea la prima formazione e assegna subito i titolari direttamente sul campo.',
          ),
        ],
        padding: AppResponsive.pagePadding(context, top: 24),
      );
    }

    final groupedByDay = <String, List<Lineup>>{};
    final dayDateByKey = <String, DateTime>{};
    final sortedLineups = [...lineups]
      ..sort((first, second) => first.matchDateTime.compareTo(second.matchDateTime));

    for (final lineup in sortedLineups) {
      final key = _dayKey(lineup.matchDateTime);
      groupedByDay.putIfAbsent(key, () => []).add(lineup);
      dayDateByKey.putIfAbsent(
        key,
        () {
          final local = lineup.matchDateTime.toLocal();
          return DateTime(local.year, local.month, local.day);
        },
      );
    }

    final orderedDayKeys = groupedByDay.keys.toList()
      ..sort((first, second) {
        final firstDate = dayDateByKey[first] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final secondDate = dayDateByKey[second] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return secondDate.compareTo(firstDate);
      });

    return _buildScrollableBody([
      for (final dayKey in orderedDayKeys)
        _LineupsDayGroupCard(
          dayLabel: _formatDayLabel(dayDateByKey[dayKey]!),
          lineupsCount: groupedByDay[dayKey]!.length,
          isExpanded: !collapsedDayKeys.contains(dayKey),
          onToggle: () {
            setState(() {
              if (collapsedDayKeys.contains(dayKey)) {
                collapsedDayKeys.remove(dayKey);
              } else {
                collapsedDayKeys.add(dayKey);
              }
            });
          },
          child: Column(
            children: [
              for (final lineup in groupedByDay[dayKey]!)
                LineupListCard(
                  lineup: lineup,
                  onOpenDetails: () => _openLineupPlayers(lineup),
                  isManageMode: canManageLineups,
                  onDuplicate: canManageLineups ? () => _duplicateLineup(lineup) : null,
                  onEdit: canManageLineups ? () => _openLineupForm(lineup: lineup) : null,
                  onDelete: canManageLineups ? () => _deleteLineup(lineup) : null,
                  assignedPlayersCount: assignmentsByLineupId[lineup.id]?.length ?? 0,
                  viewerLineupStatusLabel: _viewerLineupStatusLabel(
                    currentUser,
                    assignmentsByLineupId[lineup.id] ?? const [],
                  ),
                  viewerLineupStatusPositive: _isViewerInLineup(
                    currentUser,
                    assignmentsByLineupId[lineup.id] ?? const [],
                  ),
                ),
            ],
          ),
        ),
    ]);
  }

  bool _isViewerInLineup(
    PlayerProfile? viewer,
    List<LineupPlayerAssignment> assignments,
  ) {
    if (viewer == null) {
      return false;
    }

    for (final assignment in assignments) {
      if (assignment.playerId == viewer.id) {
        return true;
      }
    }

    return false;
  }

  String? _viewerLineupStatusLabel(
    PlayerProfile? viewer,
    List<LineupPlayerAssignment> assignments,
  ) {
    if (viewer == null) {
      return null;
    }
    if (assignments.isEmpty) {
      return 'Formazione ancora da completare';
    }

    return _isViewerInLineup(viewer, assignments)
        ? 'Sei in formazione'
        : 'Non sei in formazione';
  }
}

class _LineupsStatusCard extends StatelessWidget {
  const _LineupsStatusCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppStatusCard(
      icon: icon,
      title: title,
      message: message,
    );
  }
}

class _LineupsDayGroupCard extends StatelessWidget {
  const _LineupsDayGroupCard({
    required this.dayLabel,
    required this.lineupsCount,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  final String dayLabel;
  final int lineupsCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dayLabel,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    AppCountPill(
                      label: '$lineupsCount',
                      emphasized: true,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 8),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
