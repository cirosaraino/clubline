import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../data/attendance_repository.dart';
import '../../models/attendance_entry.dart';
import '../../models/attendance_week.dart';
import '../widgets/app_chrome.dart';
import '../widgets/attendance/attendance_archive_sections.dart';
import '../widgets/attendance/attendance_status_card.dart';

class AttendanceArchivePage extends StatefulWidget {
  const AttendanceArchivePage({
    super.key,
    this.excludingWeekId,
  });

  final dynamic excludingWeekId;

  @override
  State<AttendanceArchivePage> createState() => _AttendanceArchivePageState();
}

class _AttendanceArchivePageState extends State<AttendanceArchivePage> {
  late final AttendanceRepository repository;

  List<AttendanceWeek> weeks = [];
  final Map<dynamic, List<AttendanceEntry>> entriesByWeekId = {};
  final Set<dynamic> loadingWeekIds = {};
  final Set<dynamic> deletingWeekIds = {};
  final Set<dynamic> restoringWeekIds = {};
  bool hasActiveWeek = false;
  bool isLoading = true;
  String? errorMessage;
  int lastHandledSyncRevision = 0;
  bool _isLoadingRequest = false;
  bool _reloadRequested = false;

  @override
  void initState() {
    super.initState();
    repository = AttendanceRepository();
    AppDataSync.instance.addListener(_handleAppDataSync);
    _loadArchive();
  }

  @override
  void dispose() {
    AppDataSync.instance.removeListener(_handleAppDataSync);
    super.dispose();
  }

  void _handleAppDataSync() {
    final change = AppDataSync.instance.latestChange;
    if (change == null || change.revision == lastHandledSyncRevision) {
      return;
    }
    if (!change.affects({AppDataScope.players, AppDataScope.attendance})) {
      return;
    }

    lastHandledSyncRevision = change.revision;
    entriesByWeekId.clear();
    unawaited(_loadArchive(silent: true));
  }

  Future<void> _loadArchive({bool silent = false}) async {
    if (!mounted) {
      return;
    }

    if (_isLoadingRequest) {
      _reloadRequested = true;
      return;
    }

    _isLoadingRequest = true;
    final showBlockingLoader = !silent || weeks.isEmpty;

    setState(() {
      if (showBlockingLoader) {
        isLoading = true;
      }
      errorMessage = null;
    });

    try {
      final activeWeek = await repository.fetchActiveWeek();
      final loadedWeeks = await repository.fetchArchivedWeeks(
        excludingWeekId: widget.excludingWeekId,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        hasActiveWeek = activeWeek != null;
        weeks = loadedWeeks;
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
        unawaited(_loadArchive(silent: true));
      }
    }
  }

  Future<void> _loadWeekEntries(dynamic weekId) async {
    if (entriesByWeekId.containsKey(weekId) || loadingWeekIds.contains(weekId)) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      loadingWeekIds.add(weekId);
    });

    try {
      final entries = await repository.fetchEntriesForWeek(weekId);
      if (!mounted) {
        return;
      }
      setState(() {
        entriesByWeekId[weekId] = entries;
        loadingWeekIds.remove(weekId);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        loadingWeekIds.remove(weekId);
      });
    }
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

  Future<void> _restoreArchivedWeek(AttendanceWeek week) async {
    if (restoringWeekIds.contains(week.id) || hasActiveWeek) {
      return;
    }

    final shouldRestore = await _confirmAction(
      title: 'Ripristina settimana presenze',
      message:
          'Vuoi rimettere ${week.title} come settimana attiva? Potrai farlo solo se non esiste gia un altra settimana aperta.',
      confirmLabel: 'Ripristina',
    );
    if (!shouldRestore) {
      return;
    }

    setState(() {
      restoringWeekIds.add(week.id);
    });

    try {
      await repository.restoreArchivedWeek(week.id);
      entriesByWeekId.remove(week.id);
      await _loadArchive();

      _showSnackBar('${week.title} e di nuovo la settimana presenze attiva.');
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.attendance},
        reason: 'attendance_week_restored',
      );
    } catch (e) {
      _showSnackBar('Errore durante il ripristino della settimana: $e');
    } finally {
      if (mounted) {
        setState(() {
          restoringWeekIds.remove(week.id);
        });
      }
    }
  }

  Future<void> _deleteArchivedWeek(AttendanceWeek week) async {
    if (deletingWeekIds.contains(week.id)) {
      return;
    }

    final shouldDelete = await _confirmAction(
      title: 'Elimina archivio presenze',
      message:
          'Vuoi eliminare definitivamente ${week.title}? Verranno rimosse anche tutte le presenze archiviate di quella settimana.',
      confirmLabel: 'Elimina',
      destructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    setState(() {
      deletingWeekIds.add(week.id);
    });

    try {
      await repository.deleteArchivedWeek(week.id);
      entriesByWeekId.remove(week.id);
      await _loadArchive();

      _showSnackBar('Archivio ${week.title} eliminato con successo.');
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.attendance},
        reason: 'attendance_archive_deleted',
      );
    } catch (e) {
      _showSnackBar('Errore durante l eliminazione dell archivio: $e');
    } finally {
      if (mounted) {
        setState(() {
          deletingWeekIds.remove(week.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final viewer = session.currentUser;
    if (session.isLoading && viewer == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Archivio presenze'),
        ),
        body: const AppPageBackground(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (viewer == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Archivio presenze'),
        ),
        body: const AppPageBackground(
          child: Center(
            child: AttendanceStatusCard(
              icon: Icons.person_outline,
              title: 'Accesso richiesto',
              message:
                  'Accedi e completa il profilo squadra per consultare l archivio con i permessi corretti.',
            ),
          ),
        ),
      );
    }

    if (!viewer.canManageAttendanceAll) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Archivio presenze'),
        ),
        body: const AppPageBackground(
          child: Center(
            child: AttendanceStatusCard(
              icon: Icons.lock_outline,
              title: 'Archivio riservato',
              message:
                  'Solo il capitano e i vice autorizzati possono consultare lo storico delle presenze.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivio presenze'),
      ),
      body: AppPageBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadArchive,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context, top: 16, bottom: 32),
          children: [
            AttendanceStatusCard(
              icon: Icons.error_outline,
              title: 'Errore nel caricamento archivio',
              message: errorMessage!,
            ),
          ],
        ),
      );
    }

    if (weeks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadArchive,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context, top: 16, bottom: 32),
          children: const [
            AttendanceStatusCard(
              icon: Icons.history_toggle_off,
              title: 'Nessuno storico disponibile',
              message:
                  'Le settimane concluse compariranno qui man mano che le presenze verranno archiviate.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadArchive,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppResponsive.pagePadding(context, top: 16, bottom: 32),
        children: [
          for (final week in weeks) ...[
            AttendanceArchiveWeekCard(
              week: week,
              entries: entriesByWeekId[week.id],
              isLoadingEntries: loadingWeekIds.contains(week.id),
              isDeleting: deletingWeekIds.contains(week.id),
              isRestoring: restoringWeekIds.contains(week.id),
              hasActiveWeek: hasActiveWeek,
              onExpand: () => _loadWeekEntries(week.id),
              onRestore: () => _restoreArchivedWeek(week),
              onDelete: () => _deleteArchivedWeek(week),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
