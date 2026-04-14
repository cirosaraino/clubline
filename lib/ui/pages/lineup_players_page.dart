import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/lineup_constants.dart';
import '../../core/lineup_formatters.dart';
import '../../core/lineup_pitch_layouts.dart';
import '../../core/app_theme.dart';
import '../../core/player_formatters.dart';
import '../../data/attendance_repository.dart';
import '../../data/lineup_repository.dart';
import '../../data/player_repository.dart';
import '../../models/attendance_lineup_filters.dart';
import '../../models/lineup.dart';
import '../../models/lineup_player_assignment.dart';
import '../../models/player_profile.dart';
import '../widgets/app_chrome.dart';
import '../widgets/lineup_pitch_view.dart';
import '../widgets/lineup_player_picker_tile.dart';

class LineupPlayersPage extends StatefulWidget {
  const LineupPlayersPage({
    super.key,
    required this.lineup,
    this.initialAssignments = const [],
    this.readOnly = false,
  });

  final Lineup lineup;
  final List<LineupPlayerAssignment> initialAssignments;
  final bool readOnly;

  @override
  State<LineupPlayersPage> createState() => _LineupPlayersPageState();
}

class _LineupPlayersPageState extends State<LineupPlayersPage> {
  late final LineupRepository lineupRepository;
  late final PlayerRepository playerRepository;
  late final AttendanceRepository attendanceRepository;
  late final List<String> positionCodes;

  List<PlayerProfile> players = [];
  List<PlayerProfile> absentFilteredPlayers = [];
  List<PlayerProfile> pendingFilteredPlayers = [];
  List<PlayerProfile> removedAssignedPlayers = [];
  Map<String, dynamic> selectedPlayerIdsByPosition = {};
  bool isLoading = true;
  bool isSaving = false;
  bool isAttendanceFilterExpanded = false;
  String? errorMessage;

  bool get _canManageLineups {
    return AppSessionScope.read(context).currentUser?.canManageLineups == true;
  }

  bool get _isReadOnly {
    return widget.readOnly || !_canManageLineups;
  }

  @override
  void initState() {
    super.initState();
    lineupRepository = LineupRepository();
    playerRepository = PlayerRepository();
    attendanceRepository = AttendanceRepository();
    positionCodes = lineupPositionCodesFor(widget.lineup.formationModule);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    if (widget.lineup.id == null) {
      setState(() {
        errorMessage = 'Impossibile caricare i giocatori: formazione senza ID';
        isLoading = false;
      });
      return;
    }

    try {
      final loadedPlayers = await playerRepository.fetchPlayers();
      final lineupFilters = _canManageLineups
          ? await attendanceRepository.fetchLineupFiltersForDate(
              widget.lineup.matchDateTime,
            )
          : const AttendanceLineupFilters();
      final loadedAssignments = await lineupRepository.fetchLineupPlayers(
        widget.lineup.id,
      );
      final unavailablePlayerIds = lineupFilters.unavailablePlayerIds;
      final availablePlayers = loadedPlayers
          .where((player) => !unavailablePlayerIds.contains(player.id))
          .toList();
      final hiddenAbsentPlayers = loadedPlayers
          .where((player) => lineupFilters.absentPlayerIds.contains(player.id))
          .toList();
      final hiddenPendingPlayers = loadedPlayers
          .where((player) => lineupFilters.pendingPlayerIds.contains(player.id))
          .toList();

      final Map<String, dynamic> selectedValues = {
        for (final positionCode in positionCodes) positionCode: null,
      };
      final removedPlayers = <PlayerProfile>[];

      final assignmentsToApply = loadedAssignments.isNotEmpty
          ? loadedAssignments
          : widget.initialAssignments;

      for (final assignment in assignmentsToApply) {
        if (selectedValues.containsKey(assignment.positionCode)) {
          if (unavailablePlayerIds.contains(assignment.playerId)) {
            final removedPlayer = assignment.player ??
                _playerByIdFromList(loadedPlayers, assignment.playerId);
            if (removedPlayer != null) {
              removedPlayers.add(removedPlayer);
            }
            continue;
          }

          selectedValues[assignment.positionCode] = assignment.playerId;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        players = availablePlayers;
        absentFilteredPlayers = hiddenAbsentPlayers;
        pendingFilteredPlayers = hiddenPendingPlayers;
        removedAssignedPlayers = removedPlayers;
        selectedPlayerIdsByPosition = selectedValues;
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

  PlayerProfile? _playerByIdFromList(
    List<PlayerProfile> sourcePlayers,
    dynamic playerId,
  ) {
    for (final player in sourcePlayers) {
      if (player.id == playerId) return player;
    }

    return null;
  }

  Future<void> _saveAssignments() async {
    if (_isReadOnly) {
      return;
    }

    final selectedPlayerIds = selectedPlayerIdsByPosition.values
        .where((playerId) => playerId != null)
        .toList();

    if (selectedPlayerIds.length != selectedPlayerIds.toSet().length) {
      setState(() {
        errorMessage = 'Lo stesso giocatore non puo essere selezionato due volte';
      });
      return;
    }

    if (widget.lineup.id == null) {
      setState(() {
        errorMessage = 'Impossibile salvare i giocatori: formazione senza ID';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    final assignments = selectedPlayerIdsByPosition.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) => LineupPlayerAssignment(
            lineupId: widget.lineup.id,
            playerId: entry.value,
            positionCode: entry.key,
          ),
        )
        .toList();

    try {
      await lineupRepository.replaceLineupPlayers(widget.lineup.id, assignments);

      if (!mounted) return;
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.lineups},
        reason: 'lineup_players_updated',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giocatori formazione salvati')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isSaving = false;
      });
    }
  }

  PlayerProfile? _playerById(dynamic playerId) {
    for (final player in players) {
      if (player.id == playerId) return player;
    }

    return null;
  }

  Map<String, PlayerProfile?> _selectedPlayersByPosition() {
    return {
      for (final positionCode in positionCodes)
        positionCode: _playerById(selectedPlayerIdsByPosition[positionCode]),
    };
  }

  List<PlayerProfile> _sortedPlayersForPosition(String positionCode) {
    final currentPlayerId = selectedPlayerIdsByPosition[positionCode];
    final usedPlayerIds = selectedPlayerIdsByPosition.entries
        .where((entry) => entry.key != positionCode && entry.value != null)
        .map((entry) => entry.value)
        .toSet();

    final preferredRole = preferredRoleForPositionCode(positionCode);
    final preferredMacroRole = roleCategoryLabel(preferredRole);
    final availablePlayers = players
        .where(
          (player) => !usedPlayerIds.contains(player.id) || player.id == currentPlayerId,
        )
        .toList();

    availablePlayers.sort((a, b) {
      final aPriority = _playerPriorityForPosition(
        player: a,
        preferredRole: preferredRole,
        preferredMacroRole: preferredMacroRole,
      );
      final bPriority = _playerPriorityForPosition(
        player: b,
        preferredRole: preferredRole,
        preferredMacroRole: preferredMacroRole,
      );
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      if (aPriority < 2) {
        return a.fullName.compareTo(b.fullName);
      }

      final primaryRoleOrder = a.primaryRoleSortIndex.compareTo(b.primaryRoleSortIndex);
      if (primaryRoleOrder != 0) return primaryRoleOrder;

      return a.fullName.compareTo(b.fullName);
    });

    return availablePlayers;
  }

  int _playerPriorityForPosition({
    required PlayerProfile player,
    required String preferredRole,
    required String? preferredMacroRole,
  }) {
    if (player.roleCodes.contains(preferredRole)) {
      return 0;
    }
    final matchesMacroRole = preferredMacroRole != null &&
        player.roleCodes.any(
          (role) => roleCategoryLabel(role) == preferredMacroRole,
        );
    if (matchesMacroRole) {
      return 1;
    }

    return 2;
  }

  Future<void> _openPlayerPicker(String positionCode) async {
    if (isSaving || _isReadOnly) return;

    final currentPlayerId = selectedPlayerIdsByPosition[positionCode];
    final preferredRole = preferredRoleForPositionCode(positionCode);
    final preferredMacroRole = roleCategoryLabel(preferredRole);
    final availablePlayers = _sortedPlayersForPosition(positionCode);
    final clearSelectionToken = Object();

    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height *
                (AppResponsive.isCompact(context) ? 0.86 : 0.78),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppResponsive.horizontalPadding(context) + 4,
                    8,
                    AppResponsive.horizontalPadding(context) + 4,
                    4,
                  ),
                  child: Text(
                    'Seleziona giocatore per $positionCode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppResponsive.horizontalPadding(context) + 4,
                    0,
                    AppResponsive.horizontalPadding(context) + 4,
                    12,
                  ),
                  child: Text(
                    preferredMacroRole == null
                        ? 'Ruolo consigliato: $preferredRole'
                        : 'Ruolo consigliato: $preferredRole • Macroruolo: $preferredMacroRole',
                  ),
                ),
                if (currentPlayerId != null)
                  ListTile(
                    leading: const Icon(Icons.clear),
                    title: const Text('Rimuovi assegnazione'),
                    onTap: () => Navigator.pop(context, clearSelectionToken),
                  ),
                if (availablePlayers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Nessun giocatore disponibile per questo slot'),
                  ),
                if (availablePlayers.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: availablePlayers.length,
                      itemBuilder: (context, index) {
                        final player = availablePlayers[index];
                        final isRecommended = player.roleCodes.contains(preferredRole);
                        final isSelected = player.id == currentPlayerId;

                        return LineupPlayerPickerTile(
                          player: player,
                          isRecommended: isRecommended,
                          isSelected: isSelected,
                          onTap: () => Navigator.pop(context, player.id),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (result == null) return;

    setState(() {
      if (identical(result, clearSelectionToken)) {
        selectedPlayerIdsByPosition[positionCode] = null;
      } else {
        selectedPlayerIdsByPosition[positionCode] = result;
      }
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AppSessionScope.of(context).currentUser;
    final isReadOnly = _isReadOnly;
    final canViewManagerFilters = _canManageLineups;
    final compact = AppResponsive.isCompact(context);
    final horizontalPadding = AppResponsive.horizontalPadding(context);
    final isViewerIncluded = currentUser != null &&
        selectedPlayerIdsByPosition.values.any((playerId) => playerId == currentUser.id);
    final readOnlyDescription = currentUser == null
        ? 'Vista sola lettura della formazione.'
        : isViewerIncluded
            ? 'Vista sola lettura della formazione. Sei presente in questa formazione.'
            : 'Vista sola lettura della formazione. Non sei presente in questa formazione.';

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Giocatori formazione'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (positionCodes.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Giocatori formazione'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Modulo non supportato'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isReadOnly ? 'Dettaglio formazione' : 'Giocatori formazione'),
      ),
      body: AppPageBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Card(
                margin: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 12),
                child: Padding(
                  padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lineup.competitionName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppCountPill(
                            label: 'Modulo',
                            value: widget.lineup.formationModule,
                            emphasized: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 18,
                            color: UltrasAppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.lineup.matchDateTimeDisplay,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: UltrasAppTheme.textMuted,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isReadOnly
                            ? readOnlyDescription
                            : 'Tocca uno slot sul campo per assegnare il giocatore.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: UltrasAppTheme.textMuted,
                              height: 1.35,
                            ),
                      ),
                      if (currentUser != null) ...[
                        const SizedBox(height: 10),
                        _ViewerPresenceBanner(isIncluded: isViewerIncluded),
                      ],
                      if (canViewManagerFilters &&
                          (absentFilteredPlayers.isNotEmpty ||
                              pendingFilteredPlayers.isNotEmpty)) ...[
                        const SizedBox(height: 12),
                        _AttendanceFilterNotice(
                          matchDateTime: widget.lineup.matchDateTime,
                          absentPlayers: absentFilteredPlayers,
                          pendingPlayers: pendingFilteredPlayers,
                          removedAssignedPlayers: removedAssignedPlayers,
                          isExpanded: isAttendanceFilterExpanded,
                          onToggle: () {
                            setState(() {
                              isAttendanceFilterExpanded =
                                  !isAttendanceFilterExpanded;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (errorMessage != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12),
                  child: LineupPitchView(
                    formationModule: widget.lineup.formationModule,
                    selectedPlayersByPosition: _selectedPlayersByPosition(),
                    onTapPosition: _openPlayerPicker,
                    enabled: !isSaving && !isReadOnly,
                  ),
                ),
              ),
              if (!isReadOnly)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      compact ? 8 : 12,
                      horizontalPadding,
                      16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _saveAssignments,
                        child: Text(isSaving ? 'Salvataggio...' : 'Salva giocatori'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerPresenceBanner extends StatelessWidget {
  const _ViewerPresenceBanner({
    required this.isIncluded,
  });

  final bool isIncluded;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isIncluded
        ? UltrasAppTheme.success.withValues(alpha: 0.12)
        : UltrasAppTheme.danger;
    final borderColor = isIncluded
        ? UltrasAppTheme.success.withValues(alpha: 0.3)
        : UltrasAppTheme.danger;
    final contentColor = isIncluded ? UltrasAppTheme.success : Colors.white;
    final icon = isIncluded ? Icons.check_circle_outline : Icons.cancel_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: contentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isIncluded
                  ? 'Sei gia inserito in questa formazione.'
                  : 'In questa formazione non sei stato inserito.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceFilterNotice extends StatelessWidget {
  const _AttendanceFilterNotice({
    required this.matchDateTime,
    required this.absentPlayers,
    required this.pendingPlayers,
    required this.removedAssignedPlayers,
    required this.isExpanded,
    required this.onToggle,
  });

  final DateTime matchDateTime;
  final List<PlayerProfile> absentPlayers;
  final List<PlayerProfile> pendingPlayers;
  final List<PlayerProfile> removedAssignedPlayers;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final subtitle = removedAssignedPlayers.isEmpty
        ? 'Assenti e giocatori ancora in attesa non compaiono tra quelli selezionabili per questa data.'
        : 'Alcuni giocatori gia assegnati sono stati rimossi automaticamente perche assenti o ancora in attesa.';
    final totalFilteredPlayers = absentPlayers.length + pendingPlayers.length;
    final collapsedLabel = totalFilteredPlayers == 1
        ? '1 giocatore filtrato'
        : '$totalFilteredPlayers giocatori filtrati';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UltrasAppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: UltrasAppTheme.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.event_busy_outlined,
                      color: UltrasAppTheme.goldSoft,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disponibilita filtrate',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatMatchDateTime(matchDateTime),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: UltrasAppTheme.textMuted,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SummaryPill(
                              label: collapsedLabel,
                              color: UltrasAppTheme.gold,
                              textColor: UltrasAppTheme.goldSoft,
                            ),
                            if (absentPlayers.isNotEmpty)
                              _SummaryPill(
                                label: absentPlayers.length == 1
                                    ? '1 assente'
                                    : '${absentPlayers.length} assenti',
                                color: UltrasAppTheme.danger,
                                textColor: UltrasAppTheme.dangerSoft,
                              ),
                            if (pendingPlayers.isNotEmpty)
                              _SummaryPill(
                                label: pendingPlayers.length == 1
                                    ? '1 in attesa'
                                    : '${pendingPlayers.length} in attesa',
                                color: UltrasAppTheme.warning,
                                textColor: UltrasAppTheme.warningSoft,
                              ),
                          ],
                        ),
                        if (!isExpanded) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Tocca per vedere chi e stato filtrato.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: UltrasAppTheme.textMuted,
                                      height: 1.3,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: UltrasAppTheme.textMuted,
                    size: compact ? 24 : 26,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: UltrasAppTheme.outlineSoft,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: UltrasAppTheme.textMuted,
                          height: 1.35,
                        ),
                  ),
                  if (absentPlayers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Assenti filtrati',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UltrasAppTheme.dangerSoft,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: absentPlayers
                          .map(
                            (player) => _FilteredPlayerChip(
                              label: player.fullName,
                              color: UltrasAppTheme.danger,
                              textColor: UltrasAppTheme.dangerSoft,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (absentPlayers.isNotEmpty && pendingPlayers.isNotEmpty)
                    const SizedBox(height: 12),
                  if (pendingPlayers.isNotEmpty) ...[
                    Text(
                      'In attesa filtrati',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UltrasAppTheme.warningSoft,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pendingPlayers
                          .map(
                            (player) => _FilteredPlayerChip(
                              label: player.fullName,
                              color: UltrasAppTheme.warning,
                              textColor: UltrasAppTheme.warningSoft,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _FilteredPlayerChip extends StatelessWidget {
  const _FilteredPlayerChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
