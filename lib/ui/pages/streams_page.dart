import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/app_data_sync.dart';
import '../../core/stream_link_formatters.dart';
import '../../data/stream_link_repository.dart';
import '../../models/stream_link.dart';
import '../widgets/app_chrome.dart';
import '../widgets/stream_link_card.dart';
import 'stream_form_page.dart';

class StreamsPage extends StatefulWidget {
  const StreamsPage({super.key});

  @override
  State<StreamsPage> createState() => _StreamsPageState();
}

class _StreamsPageState extends State<StreamsPage> {
  late final StreamLinkRepository repository;

  List<StreamLink> streamLinks = [];
  final Set<String> collapsedDayKeys = {};
  final Set<String> deletingDayKeys = {};
  DateTime? selectedDate;
  bool isLoading = true;
  bool isDeletingAll = false;
  String? errorMessage;
  int lastHandledSyncRevision = 0;
  bool _isLoadingRequest = false;
  bool _reloadRequested = false;

  @override
  void initState() {
    super.initState();
    repository = StreamLinkRepository();
    AppDataSync.instance.addListener(_handleAppDataSync);
    _loadStreamLinks();
  }

  @override
  void dispose() {
    AppDataSync.instance.removeListener(_handleAppDataSync);
    super.dispose();
  }

  void _handleAppDataSync() {
    final change = AppDataSync.instance.latestChange;
    if (change == null || change.revision == lastHandledSyncRevision) return;
    if (!change.affects({AppDataScope.streams})) return;

    lastHandledSyncRevision = change.revision;
    unawaited(_loadStreamLinks(silent: true));
  }

  Future<void> _loadStreamLinks({bool silent = false}) async {
    if (!mounted) {
      return;
    }

    if (_isLoadingRequest) {
      _reloadRequested = true;
      return;
    }

    _isLoadingRequest = true;
    final showBlockingLoader = !silent || streamLinks.isEmpty;

    setState(() {
      if (showBlockingLoader) {
        isLoading = true;
      }
      errorMessage = null;
    });

    try {
      final response = await repository.fetchStreamLinks();
      final collapsedKeys = response
          .map((stream) => _dayKey(stream.playedOn))
          .toSet();

      if (selectedDate != null) {
        collapsedKeys.remove(_dayKey(selectedDate!));
      }

      if (!mounted) {
        return;
      }
      setState(() {
        streamLinks = response;
        collapsedDayKeys
          ..clear()
          ..addAll(collapsedKeys);
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
        unawaited(_loadStreamLinks(silent: true));
      }
    }
  }

  Future<void> _openStreamForm({StreamLink? streamLink}) async {
    final currentUser = AppSessionScope.read(context).currentUser;
    if (currentUser?.canManageStreams != true) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StreamFormPage(streamLink: streamLink),
      ),
    );
  }

  Future<void> _openStreamLink(StreamLink streamLink) async {
    final uri = Uri.tryParse(streamLink.streamUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link non valido')),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il link')),
      );
    }
  }

  Future<void> _copyStreamLink(StreamLink streamLink) async {
    await Clipboard.setData(ClipboardData(text: streamLink.streamUrl));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiato negli appunti')),
    );
  }

  Future<void> _deleteStreamLink(StreamLink streamLink) async {
    if (AppSessionScope.read(context).currentUser?.canManageStreams != true) {
      return;
    }

    if (streamLink.id == null) {
      setState(() {
        errorMessage = 'Impossibile cancellare il link live: ID mancante';
      });
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancella live'),
        content: Text('Vuoi davvero cancellare ${streamLink.streamTitle}?'),
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
      await repository.deleteStreamLink(streamLink.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live cancellata')),
      );
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.streams},
        reason: 'stream_deleted',
      );
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _deleteAllStreamLinks() async {
    if (AppSessionScope.read(context).currentUser?.canManageStreams != true || isDeletingAll) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina tutte le live'),
        content: const Text(
          'Vuoi davvero cancellare tutte le live archiviate? Questa azione rimuovera l intero storico.',
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

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      isDeletingAll = true;
      errorMessage = null;
    });

    try {
      await repository.deleteAllStreamLinks();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutte le live sono state cancellate')),
      );
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.streams},
        reason: 'stream_deleted_all',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isDeletingAll = false;
        });
      }
    }
  }

  Future<void> _deleteStreamLinksForDay(DateTime date, int count) async {
    final currentUser = AppSessionScope.read(context).currentUser;
    final dayKey = _dayKey(date);
    if (currentUser?.canManageStreams != true || deletingDayKeys.contains(dayKey)) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina live del giorno'),
        content: Text(
          'Vuoi davvero cancellare $count ${count == 1 ? 'contenuto' : 'contenuti'} del ${formatPlayedOnDate(date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina giorno'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      deletingDayKeys.add(dayKey);
      errorMessage = null;
    });

    try {
      await repository.deleteStreamLinksForDay(date);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Live del ${formatPlayedOnDate(date)} cancellate')),
      );
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.streams},
        reason: 'stream_deleted_day',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          deletingDayKeys.remove(dayKey);
        });
      }
    }
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final initialDate = selectedDate ?? streamLinks.first.playedOn;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: normalizePlayedOnDate(initialDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Filtra per giorno',
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = normalizePlayedOnDate(pickedDate);
      collapsedDayKeys.remove(_dayKey(selectedDate!));
    });
  }

  void _clearDateFilter() {
    if (selectedDate == null) return;

    setState(() {
      selectedDate = null;
    });
  }

  String _dayKey(DateTime value) {
    final normalized = normalizePlayedOnDate(value);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  bool _isDayExpanded(DateTime value) {
    return !collapsedDayKeys.contains(_dayKey(value));
  }

  void _toggleDayExpansion(DateTime value) {
    final key = _dayKey(value);

    setState(() {
      if (collapsedDayKeys.contains(key)) {
        collapsedDayKeys.remove(key);
      } else {
        collapsedDayKeys.add(key);
      }
    });
  }

  int _compareStreamLinks(StreamLink a, StreamLink b) {
    final dayCompare = normalizePlayedOnDate(b.playedOn).compareTo(
      normalizePlayedOnDate(a.playedOn),
    );
    if (dayCompare != 0) return dayCompare;

    if (a.isLive != b.isLive) {
      return a.isLive ? -1 : 1;
    }

    final aReference = a.streamEndedAt ?? a.createdAt ?? a.playedOn;
    final bReference = b.streamEndedAt ?? b.createdAt ?? b.playedOn;
    return bReference.compareTo(aReference);
  }

  List<StreamLink> get _filteredStreamLinks {
    final streams = [...streamLinks]..sort(_compareStreamLinks);

    if (selectedDate == null) return streams;

    final normalizedSelectedDate = normalizePlayedOnDate(selectedDate!);
    return streams
        .where(
          (stream) => normalizePlayedOnDate(stream.playedOn) == normalizedSelectedDate,
        )
        .toList();
  }

  Map<DateTime, List<StreamLink>> _buildGroupedStreamLinks(
    List<StreamLink> streams,
  ) {
    final grouped = <DateTime, List<StreamLink>>{};

    for (final stream in streams) {
      final day = normalizePlayedOnDate(stream.playedOn);
      grouped.putIfAbsent(day, () => []).add(stream);
    }

    return grouped;
  }

  Widget _buildScrollableBody(List<Widget> children) {
    return AppPageBackground(
      child: RefreshIndicator(
        onRefresh: _loadStreamLinks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context, bottom: 112),
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AppSessionScope.of(context).currentUser;
    final canManageStreams = currentUser?.canManageStreams ?? false;
    final compact = AppResponsive.isCompact(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live'),
        actions: [
          if (canManageStreams && streamLinks.isNotEmpty)
            IconButton(
              onPressed: isDeletingAll ? null : _deleteAllStreamLinks,
              tooltip: 'Elimina tutte le live',
              icon: Icon(
                isDeletingAll
                    ? Icons.hourglass_top_outlined
                    : Icons.delete_sweep_outlined,
              ),
            ),
        ],
      ),
      floatingActionButton: canManageStreams
          ? compact
              ? FloatingActionButton(
                  heroTag: 'streams_page_fab',
                  onPressed: () => _openStreamForm(),
                  child: const Icon(Icons.add),
                )
              : FloatingActionButton.extended(
                  heroTag: 'streams_page_fab',
                  onPressed: () => _openStreamForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuova live'),
                )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final currentUser = AppSessionScope.of(context).currentUser;
    final canManageStreams = currentUser?.canManageStreams ?? false;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return _buildScrollableBody([
        const SizedBox(height: 12),
        _StreamsStatusCard(
          icon: Icons.error_outline,
          eyebrow: 'ERRORE',
          title: 'Non siamo riusciti a caricare le live',
          message: errorMessage!,
        ),
      ]);
    }

    if (streamLinks.isEmpty) {
      return _buildScrollableBody([
        _StreamsStatusCard(
          icon: Icons.smart_display_outlined,
          eyebrow: 'ARCHIVIO VUOTO',
          title: 'Nessuna live caricata',
          message:
              'Ancora nessuna live. In un app mobile la via piu veloce resta il pulsante + in basso.',
        ),
      ]);
    }

    final filteredStreamLinks = _filteredStreamLinks;
    final groupedStreamLinks = _buildGroupedStreamLinks(filteredStreamLinks);

    if (filteredStreamLinks.isEmpty) {
      return _buildScrollableBody([
        _StreamsFilterCard(
          selectedDate: selectedDate,
          visibleCount: 0,
          onPickDate: _pickFilterDate,
          onClearDate: _clearDateFilter,
          onDeleteAll: canManageStreams ? _deleteAllStreamLinks : null,
          isDeletingAll: isDeletingAll,
        ),
        const SizedBox(height: 18),
        _StreamsStatusCard(
          icon: Icons.filter_alt_off_outlined,
          eyebrow: 'NESSUN RISULTATO',
          title: 'Nessuna live per questa data',
          message:
              'Non risultano live il ${formatPlayedOnDate(selectedDate!)}. Prova a cambiare filtro o rimuoverlo.',
        ),
      ]);
    }

    return _buildScrollableBody([
      _StreamsFilterCard(
        selectedDate: selectedDate,
        visibleCount: filteredStreamLinks.length,
        onPickDate: _pickFilterDate,
        onClearDate: _clearDateFilter,
        onDeleteAll: canManageStreams ? _deleteAllStreamLinks : null,
        isDeletingAll: isDeletingAll,
      ),
      const SizedBox(height: 18),
      for (final entry in groupedStreamLinks.entries) ...[
        _StreamsDaySectionCard(
          date: entry.key,
          count: entry.value.length,
          isExpanded: _isDayExpanded(entry.key),
          onToggle: () => _toggleDayExpansion(entry.key),
          onDeleteDay: canManageStreams
              ? () => _deleteStreamLinksForDay(entry.key, entry.value.length)
              : null,
          isDeletingDay: deletingDayKeys.contains(_dayKey(entry.key)),
          children: [
            for (final streamLink in entry.value)
              StreamLinkCard(
                streamLink: streamLink,
                onOpen: () => _openStreamLink(streamLink),
                onCopy: () => _copyStreamLink(streamLink),
                onEdit: canManageStreams ? () => _openStreamForm(streamLink: streamLink) : null,
                onDelete: canManageStreams ? () => _deleteStreamLink(streamLink) : null,
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    ]);
  }
}

class _StreamsFilterCard extends StatelessWidget {
  const _StreamsFilterCard({
    required this.selectedDate,
    required this.visibleCount,
    required this.onPickDate,
    required this.onClearDate,
    required this.onDeleteAll,
    required this.isDeletingAll,
  });

  final DateTime? selectedDate;
  final int visibleCount;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final VoidCallback? onDeleteAll;
  final bool isDeletingAll;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppIconBadge(icon: Icons.filter_alt_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Filtro data',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FilterCountBadge(visibleCount: visibleCount),
                  const SizedBox(height: 10),
                  AppCountPill(
                    label: selectedDate == null
                        ? 'Tutte le live'
                        : formatPlayedOnDate(selectedDate!),
                    emphasized: selectedDate != null,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onPickDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        selectedDate == null ? 'Scegli data' : 'Cambia data',
                      ),
                    ),
                  ),
                  if (selectedDate != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onClearDate,
                        icon: const Icon(Icons.close_outlined),
                        label: const Text('Rimuovi filtro'),
                      ),
                    ),
                  ],
                  if (onDeleteAll != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isDeletingAll ? null : onDeleteAll,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UltrasAppTheme.dangerSoft,
                          side: BorderSide(
                            color: UltrasAppTheme.danger.withValues(alpha: 0.35),
                          ),
                        ),
                        icon: Icon(
                          isDeletingAll
                              ? Icons.hourglass_top_outlined
                              : Icons.delete_sweep_outlined,
                        ),
                        label: Text(
                          isDeletingAll ? 'Eliminazione...' : 'Elimina tutto',
                        ),
                      ),
                    ),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIconBadge(icon: Icons.filter_alt_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Filtro data',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _FilterCountBadge(visibleCount: visibleCount),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AppCountPill(
                          label: selectedDate == null
                              ? 'Tutte le live'
                              : formatPlayedOnDate(selectedDate!),
                          emphasized: selectedDate != null,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: onPickDate,
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                selectedDate == null ? 'Scegli data' : 'Cambia data',
                              ),
                            ),
                            if (selectedDate != null)
                              OutlinedButton.icon(
                                onPressed: onClearDate,
                                icon: const Icon(Icons.close_outlined),
                                label: const Text('Rimuovi filtro'),
                              ),
                            if (onDeleteAll != null)
                              OutlinedButton.icon(
                                onPressed: isDeletingAll ? null : onDeleteAll,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: UltrasAppTheme.dangerSoft,
                                  side: BorderSide(
                                    color: UltrasAppTheme.danger.withValues(alpha: 0.35),
                                  ),
                                ),
                                icon: Icon(
                                  isDeletingAll
                                      ? Icons.hourglass_top_outlined
                                      : Icons.delete_sweep_outlined,
                                ),
                                label: Text(
                                  isDeletingAll ? 'Eliminazione...' : 'Elimina tutto',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FilterCountBadge extends StatelessWidget {
  const _FilterCountBadge({required this.visibleCount});

  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    return AppCountPill(
      label: '$visibleCount ${visibleCount == 1 ? 'risultato' : 'risultati'}',
    );
  }
}

class _StreamsDaySectionCard extends StatelessWidget {
  const _StreamsDaySectionCard({
    required this.date,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    required this.onDeleteDay,
    required this.isDeletingDay,
    required this.children,
  });

  final DateTime date;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onDeleteDay;
  final bool isDeletingDay;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final toggleLabel = isExpanded ? 'Nascondi contenuti' : 'Mostra contenuti';
    final compact = AppResponsive.isCompact(context);

    return Container(
      decoration: BoxDecoration(
        color: UltrasAppTheme.surface.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: UltrasAppTheme.outlineSoft),
        boxShadow: UltrasAppTheme.softShadow,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppResponsive.cardPadding(context),
                14,
                AppResponsive.cardPadding(context),
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact) ...[
                    Row(
                      children: [
                        const AppIconBadge(
                          icon: Icons.calendar_today_outlined,
                          size: 42,
                          iconSize: 18,
                          borderRadius: 14,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatPlayedOnSectionLabel(date),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatPlayedOnDate(date),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: UltrasAppTheme.textMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppCountPill(
                      label: '$count ${count == 1 ? 'contenuto' : 'contenuti'}',
                    ),
                  ] else
                    Row(
                      children: [
                        const AppIconBadge(
                          icon: Icons.calendar_today_outlined,
                          size: 42,
                          iconSize: 18,
                          borderRadius: 14,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatPlayedOnSectionLabel(date),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatPlayedOnDate(date),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: UltrasAppTheme.textMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        AppCountPill(
                          label: '$count ${count == 1 ? 'contenuto' : 'contenuti'}',
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: UltrasAppTheme.outlineSoft),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            toggleLabel,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: UltrasAppTheme.textMuted,
                        ),
                      ],
                    ),
                  ),
                  if (onDeleteDay != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: compact ? double.infinity : null,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: isDeletingDay ? null : onDeleteDay,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: UltrasAppTheme.dangerSoft,
                            side: BorderSide(
                              color: UltrasAppTheme.danger.withValues(alpha: 0.35),
                            ),
                          ),
                          icon: Icon(
                            isDeletingDay
                                ? Icons.hourglass_top_outlined
                                : Icons.delete_outline,
                          ),
                          label: Text(
                            isDeletingDay ? 'Eliminazione...' : 'Elimina giorno',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    height: 1,
                    color: UltrasAppTheme.outlineSoft,
                  ),
                  ...children,
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}

class _StreamsStatusCard extends StatelessWidget {
  const _StreamsStatusCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppStatusCard(
      icon: icon,
      eyebrow: eyebrow,
      title: title,
      message: message,
    );
  }
}
