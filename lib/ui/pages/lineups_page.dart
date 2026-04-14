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
  Map<dynamic, List<LineupPlayerAssignment>> assignmentsByLineupId = {};
  bool isLoading = true;
  String? errorMessage;
  int lastHandledSyncRevision = 0;

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
    _loadLineups();
  }

  Future<void> _loadLineups() async {
    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = true;
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
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final currentUser = AppSessionScope.of(context).currentUser;
    final canManageLineups = currentUser?.canManageLineups ?? false;
    final compact = AppResponsive.isCompact(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formazioni'),
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

    return _buildScrollableBody([
      for (final lineup in lineups)
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
