import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/attendance_formatters.dart';
import '../../../models/attendance_entry.dart';
import '../../../models/attendance_player_entries.dart';
import '../../../models/attendance_week.dart';
import '../app_chrome.dart';

class AttendanceArchiveWeekCard extends StatelessWidget {
  const AttendanceArchiveWeekCard({
    super.key,
    required this.week,
    required this.entries,
    required this.isLoadingEntries,
    required this.isDeleting,
    required this.isRestoring,
    required this.hasActiveWeek,
    required this.onExpand,
    required this.onRestore,
    required this.onDelete,
  });

  final AttendanceWeek week;
  final List<AttendanceEntry>? entries;
  final bool isLoadingEntries;
  final bool isDeleting;
  final bool isRestoring;
  final bool hasActiveWeek;
  final VoidCallback onExpand;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final presentCount = entries?.where((entry) => entry.isPresent).length ?? 0;
    final absentCount = entries?.where((entry) => entry.isAbsent).length ?? 0;
    final pendingCount = entries?.where((entry) => entry.isPending).length ?? 0;
    final compact = AppResponsive.isCompact(context);
    final groupedEntries = entries == null
        ? null
        : AttendancePlayerEntries.groupEntries(entries!);
    final weekDates = week.votingDates;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) onExpand();
        },
        tilePadding: EdgeInsets.symmetric(
          horizontal: AppResponsive.cardPadding(context),
          vertical: compact ? 4 : 6,
        ),
        childrenPadding: EdgeInsets.fromLTRB(
          AppResponsive.cardPadding(context),
          0,
          AppResponsive.cardPadding(context),
          AppResponsive.cardPadding(context),
        ),
        title: Text(
          week.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${week.subtitle} • ${week.selectedDatesSummary}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: UltrasAppTheme.textMuted,
                ),
          ),
        ),
        trailing: isLoadingEntries
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more_outlined),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: compact ? double.infinity : null,
                child: OutlinedButton.icon(
                  onPressed: (isDeleting || isRestoring || hasActiveWeek) ? null : onRestore,
                  icon: isRestoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore_outlined),
                  label: Text(
                    isRestoring ? 'Ripristino...' : 'Ripristina',
                  ),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : null,
                child: OutlinedButton.icon(
                  onPressed: (isDeleting || isRestoring) ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UltrasAppTheme.danger,
                    side: BorderSide(
                      color: UltrasAppTheme.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(
                    isDeleting ? 'Eliminazione...' : 'Elimina archivio',
                  ),
                ),
              ),
            ],
          ),
          if (hasActiveWeek) ...[
            const SizedBox(height: 10),
            Text(
              'Ripristino non disponibile: esiste gia una settimana presenze attiva.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: UltrasAppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          if (entries != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppCountPill(
                  label: 'Si',
                  value: '$presentCount',
                  color: UltrasAppTheme.success,
                ),
                AppCountPill(
                  label: 'No',
                  value: '$absentCount',
                  color: UltrasAppTheme.danger,
                ),
                AppCountPill(
                  label: 'Attesa',
                  value: '$pendingCount',
                  color: UltrasAppTheme.warning,
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final playerEntries in groupedEntries!) ...[
              AttendanceArchivePlayerRow(
                playerEntries: playerEntries,
                weekDates: weekDates,
              ),
              const SizedBox(height: 8),
            ],
          ] else if (!isLoadingEntries)
            Text(
              'Apri la settimana per caricare le presenze archiviate.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: UltrasAppTheme.textMuted,
                  ),
            ),
        ],
      ),
    );
  }
}

class AttendanceArchivePlayerRow extends StatelessWidget {
  const AttendanceArchivePlayerRow({
    super.key,
    required this.playerEntries,
    required this.weekDates,
  });

  final AttendancePlayerEntries playerEntries;
  final List<DateTime> weekDates;

  Color _statusColor(String availability) {
    switch (availability) {
      case 'yes':
        return UltrasAppTheme.success;
      case 'no':
        return UltrasAppTheme.danger;
      case 'pending':
      default:
        return UltrasAppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UltrasAppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            playerEntries.player?.fullName ?? 'Giocatore non disponibile',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final date in weekDates)
                Builder(
                  builder: (context) {
                    final entry = playerEntries.entryForDate(date);
                    final availability = entry?.availability ?? 'pending';
                    final statusColor = _statusColor(availability);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '${formatAttendanceDayShortLabel(date)}: ${attendanceAvailabilityShortLabel(availability)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    );
                  },
                ),
            ],
          ),
          if (playerEntries.player != null) ...[
            const SizedBox(height: 8),
            Text(
              playerEntries.player!.teamRoleDisplay,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: UltrasAppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
