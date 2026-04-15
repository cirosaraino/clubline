import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../data/attendance_repository.dart';
import '../../models/attendance_day_summary.dart';
import '../../models/attendance_entry.dart';
import '../../models/attendance_player_entries.dart';
import '../../models/attendance_week.dart';
import '../../models/attendance_week_draft.dart';
import '../../models/player_profile.dart';
import '../widgets/app_chrome.dart';
import '../widgets/attendance/attendance_overview_cards.dart';
import '../widgets/attendance/attendance_player_cards.dart';
import '../widgets/attendance/attendance_status_card.dart';
import '../widgets/attendance/attendance_week_setup_sheet.dart';
import 'attendance_archive_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final AttendanceRepository attendanceRepository;

  List<AttendanceEntry> entries = [];
  AttendanceWeek? activeWeek;
  bool isLoading = true;
  bool isProcessingWeekAction = false;
  bool isPendingSectionExpanded = false;
  bool isCaptainFiltersExpanded = false;
  String? errorMessage;
  final Set<String> savingEntryKeys = {};
  int lastHandledSyncRevision = 0;
  bool _isLoadingRequest = false;
  bool _reloadRequested = false;
  final captainNomeFilterController = TextEditingController();
  final captainCognomeFilterController = TextEditingController();
  final captainConsoleIdFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    attendanceRepository = AttendanceRepository();
    AppDataSync.instance.addListener(_handleAppDataSync);
    _loadData();
  }

  @override
  void dispose() {
    AppDataSync.instance.removeListener(_handleAppDataSync);
    captainNomeFilterController.dispose();
    captainCognomeFilterController.dispose();
    captainConsoleIdFilterController.dispose();
    super.dispose();
  }

  PlayerProfile? get activeViewer {
    return AppSessionScope.read(context).currentUser;
  }

  bool get canManageAll => activeViewer?.canManageAttendanceAll ?? false;

  bool get canUseCaptainFilters => activeViewer?.isCaptain == true;

  bool get hasCaptainFiltersActive {
    return captainNomeFilterController.text.trim().isNotEmpty ||
        captainCognomeFilterController.text.trim().isNotEmpty ||
        captainConsoleIdFilterController.text.trim().isNotEmpty;
  }

  List<AttendanceEntry> get visibleEntries {
    if (canManageAll) {
      return entries;
    }

    final viewerId = activeViewer?.id;
    return entries.where((entry) => entry.playerId == viewerId).toList();
  }

  List<AttendancePlayerEntries> _applyCaptainFilters(
    List<AttendancePlayerEntries> source,
  ) {
    if (!canUseCaptainFilters) {
      return source;
    }

    final nomeQuery = captainNomeFilterController.text.trim().toLowerCase();
    final cognomeQuery = captainCognomeFilterController.text.trim().toLowerCase();
    final consoleIdQuery = captainConsoleIdFilterController.text.trim().toLowerCase();

    if (nomeQuery.isEmpty && cognomeQuery.isEmpty && consoleIdQuery.isEmpty) {
      return source;
    }

    return source.where((playerEntries) {
      final player = playerEntries.player;
      if (player == null) {
        return false;
      }

      final playerNome = player.nome.toLowerCase();
      final playerCognome = player.cognome.toLowerCase();
      final playerConsoleId = (player.idConsole ?? '').toLowerCase();

      final matchesNome = nomeQuery.isEmpty || playerNome.contains(nomeQuery);
      final matchesCognome = cognomeQuery.isEmpty || playerCognome.contains(cognomeQuery);
      final matchesConsoleId =
          consoleIdQuery.isEmpty || playerConsoleId.contains(consoleIdQuery);

      return matchesNome && matchesCognome && matchesConsoleId;
    }).toList();
  }

  void _clearCaptainFilters() {
    setState(() {
      captainNomeFilterController.clear();
      captainCognomeFilterController.clear();
      captainConsoleIdFilterController.clear();
    });
  }

  void _handleAppDataSync() {
    final change = AppDataSync.instance.latestChange;
    if (change == null || change.revision == lastHandledSyncRevision) {
      return;
    }
    if (!change.affects({AppDataScope.players, AppDataScope.attendance})) {
      return;
    }
    if (change.reason == 'attendance_updated') {
      return;
    }

    lastHandledSyncRevision = change.revision;
    unawaited(_loadData(silent: true));
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) {
      return;
    }

    if (_isLoadingRequest) {
      _reloadRequested = true;
      return;
    }

    _isLoadingRequest = true;
    final showBlockingLoader = !silent || (entries.isEmpty && activeWeek == null);

    setState(() {
      if (showBlockingLoader) {
        isLoading = true;
      }
      errorMessage = null;
    });

    try {
      final loadedWeek = await attendanceRepository.fetchActiveWeek();
      final loadedEntries = await _loadEntriesForWeek(loadedWeek);

      if (!mounted) {
        return;
      }
      setState(() {
        activeWeek = loadedWeek;
        entries = loadedEntries;
        isPendingSectionExpanded = false;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (showBlockingLoader) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    } finally {
      _isLoadingRequest = false;
      if (_reloadRequested) {
        _reloadRequested = false;
        unawaited(_loadData(silent: true));
      }
    }
  }

  Future<List<AttendanceEntry>> _loadEntriesForWeek(AttendanceWeek? week) async {
    if (week == null) {
      return [];
    }

    return attendanceRepository.fetchEntriesForWeek(week.id);
  }

  bool _isSameEntry(AttendanceEntry left, AttendanceEntry right) {
    if (left.id != null && right.id != null) {
      return left.id == right.id;
    }

    return left.entryKey == right.entryKey;
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _updateAvailability(AttendanceEntry entry, String availability) async {
    final viewer = activeViewer;
    final week = activeWeek;
    if (viewer == null || week == null) {
      return;
    }

    final canEditEntry = canManageAll || entry.playerId == viewer.id;
    if (!canEditEntry) {
      return;
    }

    setState(() {
      savingEntryKeys.add(entry.entryKey);
    });

    try {
      await attendanceRepository.saveAvailability(
        weekId: week.id,
        playerId: entry.playerId,
        attendanceDate: entry.attendanceDate,
        availability: availability,
        updatedByPlayerId: viewer.id,
      );

      final updatedEntries = entries
          .map(
            (item) => _isSameEntry(item, entry)
                ? item.copyWith(
                    availability: availability,
                    updatedByPlayerId: viewer.id,
                    updatedAt: DateTime.now(),
                  )
                : item,
          )
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        entries = updatedEntries;
        savingEntryKeys.remove(entry.entryKey);
      });
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.attendance},
        reason: 'attendance_updated',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        savingEntryKeys.remove(entry.entryKey);
      });
      _showSnackBar('Errore nel salvataggio presenza: $e');
    }
  }

  Future<void> _openArchive() async {
    final viewer = activeViewer;
    if (viewer == null || !viewer.canManageAttendanceAll) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceArchivePage(
          excludingWeekId: activeWeek?.id,
        ),
      ),
    );
  }

  Future<void> _openCreateWeekFlow() async {
    final viewer = activeViewer;
    if (viewer == null || !viewer.canManageAttendanceAll || activeWeek != null) {
      return;
    }

    final draft = await showModalBottomSheet<AttendanceWeekDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AttendanceWeekSetupSheet(),
    );

    if (draft == null) {
      return;
    }

    await _createWeek(draft);
  }

  Future<void> _createWeek(AttendanceWeekDraft draft) async {
    final viewer = activeViewer;
    if (viewer == null || !viewer.canManageAttendanceAll || isProcessingWeekAction) {
      return;
    }

    setState(() {
      isProcessingWeekAction = true;
    });

    try {
      final createdWeek = await attendanceRepository.createWeek(
        referenceDate: draft.referenceDate,
        selectedDates: draft.selectedDates,
      );

      await _loadData();

      _showSnackBar(
        createdWeek == null
            ? 'Sondaggio presenze creato.'
            : '${createdWeek.title} creato con ${createdWeek.votingDates.length} giorni.',
      );
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.attendance},
        reason: 'attendance_week_created',
      );
    } catch (e) {
      _showSnackBar('Errore durante la creazione presenze: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessingWeekAction = false;
        });
      }
    }
  }

  Future<void> _archiveActiveWeek() async {
    final viewer = activeViewer;
    final week = activeWeek;
    if (viewer == null ||
        !viewer.canManageAttendanceAll ||
        week == null ||
        isProcessingWeekAction) {
      return;
    }

    final shouldArchive = await _confirmAction(
      title: 'Archivia presenze',
      message:
          'Vuoi archiviare ${week.title}? Dopo l archivio non comparira piu come settimana attiva.',
      confirmLabel: 'Archivia',
    );
    if (!shouldArchive) {
      return;
    }

    setState(() {
      isProcessingWeekAction = true;
    });

    try {
      await attendanceRepository.archiveWeek(week.id);
      await _loadData();

      _showSnackBar('Settimana presenze archiviata con successo.');
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.attendance},
        reason: 'attendance_week_archived',
      );
    } catch (e) {
      _showSnackBar('Errore durante l archivio presenze: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessingWeekAction = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presenze'),
      ),
      body: AppPageBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final session = AppSessionScope.of(context);
    final players = session.players;
    final viewer = session.currentUser;

    if (session.isLoading && players.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context, top: 16, bottom: 32),
          children: [
            AttendanceStatusCard(
              icon: Icons.error_outline,
              title: 'Errore nel caricamento presenze',
              message: errorMessage!,
            ),
          ],
        ),
      );
    }

    if (players.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context, top: 16, bottom: 32),
          children: const [
            AttendanceStatusCard(
              icon: Icons.groups_2_outlined,
              title: 'Nessun giocatore disponibile',
              message:
                  'Aggiungi prima i giocatori alla rosa: solo dopo il capitano o un vice autorizzato potranno aprire il sondaggio presenze.',
            ),
          ],
        ),
      );
    }

    if (viewer == null) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context, top: 16, bottom: 32),
          children: const [
            AttendanceStatusCard(
              icon: Icons.person_outline,
              title: 'Accesso richiesto',
              message:
                  'Accedi e completa il profilo squadra per usare le presenze con i permessi corretti.',
            ),
          ],
        ),
      );
    }

    final weekDates = activeWeek?.votingDates ?? const <DateTime>[];
    final groupedEntries = AttendancePlayerEntries.groupEntries(visibleEntries);
    final filteredGroupedEntries = _applyCaptainFilters(groupedEntries);
    final daySummaries = canManageAll
        ? AttendanceDaySummary.buildForDates(weekDates, entries)
        : const <AttendanceDaySummary>[];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppResponsive.pagePadding(context, bottom: 32),
        children: [
          AttendanceHeroCard(
            viewer: viewer,
            activeWeek: activeWeek,
            daySummaries: daySummaries,
            onOpenArchive: canManageAll ? _openArchive : null,
            onCreateWeek: canManageAll && activeWeek == null ? _openCreateWeekFlow : null,
            onArchiveWeek: canManageAll && activeWeek != null ? _archiveActiveWeek : null,
            isProcessingWeekAction: isProcessingWeekAction,
            showManagerSummary: canManageAll,
          ),
          const SizedBox(height: 16),
          if (canUseCaptainFilters && activeWeek != null) ...[
            _CaptainAttendanceFiltersCard(
              isExpanded: isCaptainFiltersExpanded,
              hasActiveFilters: hasCaptainFiltersActive,
              nomeController: captainNomeFilterController,
              cognomeController: captainCognomeFilterController,
              consoleIdController: captainConsoleIdFilterController,
              onToggle: () {
                setState(() {
                  isCaptainFiltersExpanded = !isCaptainFiltersExpanded;
                });
              },
              onChanged: () {
                setState(() {});
              },
              onClearFilters: _clearCaptainFilters,
            ),
            const SizedBox(height: 16),
          ],
          if (activeWeek == null)
            AttendanceStatusCard(
              icon: Icons.schedule_outlined,
              title: 'Nessun sondaggio attivo in questo momento',
              message: canManageAll
                  ? 'Il sondaggio presenze viene aperto manualmente dal capitano o da un vice autorizzato, scegliendo i giorni della settimana da mettere a voto.'
                  : 'Attendi che il capitano o un vice autorizzato apra il nuovo sondaggio presenze.',
              actionLabel: canManageAll ? 'Crea sondaggio' : null,
              actionIcon: Icons.add_circle_outline,
              actionLoading: isProcessingWeekAction,
              onAction: canManageAll ? _openCreateWeekFlow : null,
            )
          else if (groupedEntries.isEmpty) ...[
            const AttendanceStatusCard(
              icon: Icons.event_busy_outlined,
              title: 'Nessuna presenza disponibile',
              message:
                  'Le presenze giornaliere di questa settimana non sono ancora disponibili. Aggiorna la pagina dopo la migrazione del database o dopo la sincronizzazione.',
            ),
          ] else if (filteredGroupedEntries.isEmpty) ...[
            AttendanceStatusCard(
              icon: Icons.filter_alt_off_outlined,
              title: 'Nessun giocatore trovato con i filtri attivi',
              message:
                  'Rimuovi o modifica i filtri capitano per visualizzare nuovamente la lista completa.',
              actionLabel: hasCaptainFiltersActive ? 'Rimuovi filtri' : null,
              actionIcon: Icons.close_outlined,
              onAction: hasCaptainFiltersActive ? _clearCaptainFilters : null,
            ),
          ] else ...[
            if (canManageAll) ...[
              AttendancePendingSection(
                daySummaries: daySummaries,
                isExpanded: isPendingSectionExpanded,
                onToggle: () {
                  setState(() {
                    isPendingSectionExpanded = !isPendingSectionExpanded;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            for (final playerEntries in filteredGroupedEntries) ...[
              AttendancePlayerCard(
                playerEntries: playerEntries,
                weekDates: weekDates,
                canEdit: canManageAll || playerEntries.playerId == viewer.id,
                savingEntryKeys: savingEntryKeys,
                onSelectAvailability: _updateAvailability,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _CaptainAttendanceFiltersCard extends StatelessWidget {
  const _CaptainAttendanceFiltersCard({
    required this.isExpanded,
    required this.hasActiveFilters,
    required this.nomeController,
    required this.cognomeController,
    required this.consoleIdController,
    required this.onToggle,
    required this.onChanged,
    required this.onClearFilters,
  });

  final bool isExpanded;
  final bool hasActiveFilters;
  final TextEditingController nomeController;
  final TextEditingController cognomeController;
  final TextEditingController consoleIdController;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final VoidCallback onClearFilters;

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Card(
      key: const Key('attendance-captain-filters-card'),
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtri capitano',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (hasActiveFilters)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: AppCountPill(
                          label: 'Attivi',
                          emphasized: true,
                        ),
                      ),
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
              const SizedBox(height: 12),
              TextField(
                key: const Key('attendance-captain-filter-nome-input'),
                controller: nomeController,
                onChanged: (_) => onChanged(),
                decoration: _inputDecoration('Filtra per nome', Icons.person_outline),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('attendance-captain-filter-cognome-input'),
                controller: cognomeController,
                onChanged: (_) => onChanged(),
                decoration: _inputDecoration(
                  'Filtra per cognome',
                  Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('attendance-captain-filter-console-id-input'),
                controller: consoleIdController,
                onChanged: (_) => onChanged(),
                decoration: _inputDecoration(
                  'Filtra per ID console',
                  Icons.sports_esports_outlined,
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: compact ? double.infinity : null,
                  child: OutlinedButton.icon(
                    key: const Key('attendance-captain-filters-clear-button'),
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.close_outlined),
                    label: const Text('Rimuovi filtri'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
