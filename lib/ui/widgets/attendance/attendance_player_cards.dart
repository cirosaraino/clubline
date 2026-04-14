import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/attendance_formatters.dart';
import '../../../models/attendance_entry.dart';
import '../../../models/attendance_player_entries.dart';
import '../app_chrome.dart';

class AttendancePlayerCard extends StatelessWidget {
  const AttendancePlayerCard({
    super.key,
    required this.playerEntries,
    required this.weekDates,
    required this.canEdit,
    required this.savingEntryKeys,
    required this.onSelectAvailability,
  });

  final AttendancePlayerEntries playerEntries;
  final List<DateTime> weekDates;
  final bool canEdit;
  final Set<String> savingEntryKeys;
  final void Function(AttendanceEntry entry, String availability) onSelectAvailability;

  @override
  Widget build(BuildContext context) {
    final player = playerEntries.player;
    final completedDays = playerEntries.completedDaysCount(weekDates);
    final compact = AppResponsive.isCompact(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              Text(
                player?.fullName ?? 'Giocatore',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                player == null
                    ? 'Presenze giornaliere'
                    : '${player.teamRoleDisplay} • ${player.roleCodesDisplay}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: UltrasAppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: UltrasAppTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: UltrasAppTheme.outlineSoft),
                ),
                child: Text(
                  '$completedDays/${weekDates.length} compilati',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: UltrasAppTheme.goldSoft,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player?.fullName ?? 'Giocatore',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          player == null
                              ? 'Presenze giornaliere'
                              : '${player.teamRoleDisplay} • ${player.roleCodesDisplay}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: UltrasAppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: UltrasAppTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: UltrasAppTheme.outlineSoft),
                    ),
                    child: Text(
                      '$completedDays/${weekDates.length} compilati',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UltrasAppTheme.goldSoft,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final date in weekDates) ...[
                      Builder(
                        builder: (context) {
                          final entry = playerEntries.entryForDate(date);

                          return AttendanceDayTile(
                            date: date,
                            entry: entry,
                            canEdit: canEdit,
                            isSaving: savingEntryKeys.contains(entry?.entryKey ?? ''),
                            onSelectAvailability: (availability) {
                              if (entry == null) return;
                              onSelectAvailability(entry, availability);
                            },
                          );
                        },
                      ),
                      if (date != weekDates.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
            if (!canEdit) ...[
              const SizedBox(height: 12),
              Text(
                'Questo profilo puo solo consultare queste presenze giornaliere.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: UltrasAppTheme.textMuted,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AttendanceDayTile extends StatelessWidget {
  const AttendanceDayTile({
    super.key,
    required this.date,
    required this.entry,
    required this.canEdit,
    required this.isSaving,
    required this.onSelectAvailability,
  });

  final DateTime date;
  final AttendanceEntry? entry;
  final bool canEdit;
  final bool isSaving;
  final ValueChanged<String> onSelectAvailability;

  Color get statusColor {
    if (entry == null) return UltrasAppTheme.textMuted;
    if (entry!.isPresent) return UltrasAppTheme.success;
    if (entry!.isAbsent) return UltrasAppTheme.danger;
    return UltrasAppTheme.warning;
  }

  String get statusLabel => entry?.availabilityLabel ?? 'Non disponibile';

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Container(
      width: compact ? 188 : 210,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: UltrasAppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatAttendanceDayWithDate(date),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canEdit
                          ? 'Seleziona la disponibilita'
                          : formatAttendanceDayLabel(date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UltrasAppTheme.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 11 : null,
                        ),
                  ),
                ),
            ],
          ),
          if (entry != null) ...[
            const SizedBox(height: 12),
            if (compact) ...[
              AttendanceAvailabilityChip(
                label: 'Presente',
                selected: entry!.isPresent,
                color: UltrasAppTheme.success,
                enabled: canEdit && !isSaving,
                onTap: () => onSelectAvailability('yes'),
              ),
              const SizedBox(height: 8),
              AttendanceAvailabilityChip(
                label: 'Assente',
                selected: entry!.isAbsent,
                color: UltrasAppTheme.danger,
                enabled: canEdit && !isSaving,
                onTap: () => onSelectAvailability('no'),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: AttendanceAvailabilityChip(
                      label: 'Presente',
                      selected: entry!.isPresent,
                      color: UltrasAppTheme.success,
                      enabled: canEdit && !isSaving,
                      onTap: () => onSelectAvailability('yes'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AttendanceAvailabilityChip(
                      label: 'Assente',
                      selected: entry!.isAbsent,
                      color: UltrasAppTheme.danger,
                      enabled: canEdit && !isSaving,
                      onTap: () => onSelectAvailability('no'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              entry!.isPending
                  ? canEdit
                      ? 'Nessuna risposta ancora inserita.'
                      : 'Disponibilita ancora in attesa.'
                  : 'Stato aggiornato per ${formatAttendanceDayShortLabel(date)}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: UltrasAppTheme.textMuted,
                    height: 1.3,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class AttendanceAvailabilityChip extends StatelessWidget {
  const AttendanceAvailabilityChip({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected ? color.withValues(alpha: 0.14) : UltrasAppTheme.surfaceAlt;
    final foregroundColor = selected ? color : UltrasAppTheme.textMuted;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : UltrasAppTheme.outlineSoft,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: enabled ? foregroundColor : foregroundColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
