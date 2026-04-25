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
    this.isCurrentViewer = false,
    required this.savingEntryKeys,
    required this.onSelectAvailability,
  });

  final AttendancePlayerEntries playerEntries;
  final List<DateTime> weekDates;
  final bool canEdit;
  final bool isCurrentViewer;
  final Set<String> savingEntryKeys;
  final void Function(AttendanceEntry entry, String availability)
  onSelectAvailability;

  @override
  Widget build(BuildContext context) {
    final player = playerEntries.player;
    final completedDays = playerEntries.completedDaysCount(weekDates);
    final pendingDays = weekDates.length - completedDays;
    final compact = AppResponsive.isCompact(context);
    final roleSummary = player == null
        ? 'Presenze giornaliere'
        : '${player.teamRoleDisplay} • ${player.roleCodesDisplay}';

    return Card(
      elevation: isCurrentViewer ? 2 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isCurrentViewer
              ? ClublineAppTheme.info.withValues(alpha: 0.4)
              : ClublineAppTheme.outlineSoft,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
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
                        player?.fullName ?? 'Giocatore',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roleSummary,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ClublineAppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrentViewer)
                  AppCountPill(
                    label: 'Tu',
                    icon: Icons.person_rounded,
                    color: ClublineAppTheme.info,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppCountPill(
                  label: 'Compilate',
                  value: '$completedDays/${weekDates.length}',
                  emphasized: true,
                ),
                if (pendingDays > 0)
                  AppCountPill(
                    label: 'Attesa',
                    value: '$pendingDays',
                    color: ClublineAppTheme.warning,
                  ),
              ],
            ),
            const SizedBox(height: 12),
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
                            isCurrentViewer: isCurrentViewer,
                            isSaving: savingEntryKeys.contains(
                              entry?.entryKey ?? '',
                            ),
                            onSelectAvailability: (availability) {
                              if (entry == null) return;
                              onSelectAvailability(entry, availability);
                            },
                          );
                        },
                      ),
                      if (date != weekDates.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            if (!canEdit) ...[
              const SizedBox(height: 10),
              Text(
                'Solo consultazione.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ClublineAppTheme.textMuted,
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
    this.isCurrentViewer = false,
    required this.isSaving,
    required this.onSelectAvailability,
  });

  final DateTime date;
  final AttendanceEntry? entry;
  final bool canEdit;
  final bool isCurrentViewer;
  final bool isSaving;
  final ValueChanged<String> onSelectAvailability;

  Color get statusColor {
    if (entry == null) return ClublineAppTheme.textMuted;
    if (entry!.isPresent) return ClublineAppTheme.success;
    if (entry!.isAbsent) return ClublineAppTheme.danger;
    return ClublineAppTheme.warning;
  }

  String get statusLabel => entry?.availabilityLabel ?? 'Non disponibile';

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final hasEntry = entry != null;
    final tileBorderColor = isCurrentViewer
        ? ClublineAppTheme.info.withValues(alpha: 0.32)
        : ClublineAppTheme.outlineSoft;

    return Container(
      width: compact ? 174 : 186,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tileBorderColor),
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
                      canEdit ? 'Rispondi ora' : formatAttendanceDayLabel(date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ClublineAppTheme.textMuted,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
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
          if (hasEntry) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AttendanceAvailabilityChip(
                    label: 'Presente',
                    selected: entry!.isPresent,
                    color: ClublineAppTheme.success,
                    enabled: canEdit && !isSaving,
                    onTap: () => onSelectAvailability('yes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AttendanceAvailabilityChip(
                    label: 'Assente',
                    selected: entry!.isAbsent,
                    color: ClublineAppTheme.danger,
                    enabled: canEdit && !isSaving,
                    onTap: () => onSelectAvailability('no'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry!.isPending
                  ? canEdit
                        ? 'Scegli una risposta.'
                        : 'In attesa.'
                  : 'Stato aggiornato.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ClublineAppTheme.textMuted,
                height: 1.25,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Disponibilita non ancora pronta.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ClublineAppTheme.textMuted,
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
    final backgroundColor = selected
        ? color.withValues(alpha: 0.14)
        : ClublineAppTheme.surfaceAlt;
    final foregroundColor = selected ? color : ClublineAppTheme.textMuted;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.4)
                : ClublineAppTheme.outlineSoft,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: enabled
                ? foregroundColor
                : foregroundColor.withValues(alpha: 0.7),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
