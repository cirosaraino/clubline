import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/attendance_formatters.dart';
import '../../../models/attendance_day_summary.dart';
import '../../../models/attendance_week.dart';
import '../../../models/player_profile.dart';
import '../app_chrome.dart';

class AttendanceHeroCard extends StatelessWidget {
  const AttendanceHeroCard({
    super.key,
    required this.viewer,
    required this.activeWeek,
    required this.daySummaries,
    required this.onOpenArchive,
    required this.onCreateWeek,
    required this.onArchiveWeek,
    required this.isProcessingWeekAction,
    required this.showManagerSummary,
  });

  final PlayerProfile viewer;
  final AttendanceWeek? activeWeek;
  final List<AttendanceDaySummary> daySummaries;
  final VoidCallback? onOpenArchive;
  final VoidCallback? onCreateWeek;
  final VoidCallback? onArchiveWeek;
  final bool isProcessingWeekAction;
  final bool showManagerSummary;

  @override
  Widget build(BuildContext context) {
    final title = activeWeek?.title ?? 'Settimana non ancora aperta';
    final compact = AppResponsive.isCompact(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconBadge(
                  icon: Icons.event_available_outlined,
                  size: 42,
                  iconSize: 18,
                  borderRadius: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (onOpenArchive != null)
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: OutlinedButton.icon(
                      onPressed: onOpenArchive,
                      icon: const Icon(Icons.history),
                      label: const Text('Archivio'),
                    ),
                  ),
                if (activeWeek == null && onCreateWeek != null)
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: FilledButton.icon(
                      onPressed: isProcessingWeekAction ? null : onCreateWeek,
                      icon: isProcessingWeekAction
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_circle_outline),
                      label: Text(
                        isProcessingWeekAction ? 'Creazione...' : 'Crea sondaggio',
                      ),
                    ),
                  ),
                if (activeWeek != null && onArchiveWeek != null)
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: OutlinedButton.icon(
                      onPressed: isProcessingWeekAction ? null : onArchiveWeek,
                      icon: isProcessingWeekAction
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.inventory_2_outlined),
                      label: Text(
                        isProcessingWeekAction ? 'Archiviazione...' : 'Archivia settimana',
                      ),
                    ),
                  ),
              ],
            ),
            if (activeWeek != null && showManagerSummary) ...[
              const SizedBox(height: 16),
              Text(
                'Riepilogo per giorno',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final summary in daySummaries) ...[
                      AttendanceDaySummaryCard(summary: summary),
                      if (summary != daySummaries.last) const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AttendanceDaySummaryCard extends StatelessWidget {
  const AttendanceDaySummaryCard({
    super.key,
    required this.summary,
  });

  final AttendanceDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final isComplete =
        summary.totalPlayers > 0 && summary.answeredCount >= summary.totalPlayers;

    return Container(
      width: compact ? 164 : 180,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: UltrasAppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatAttendanceDayWithDate(summary.date),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            formatAttendanceDayLabel(summary.date),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: UltrasAppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppCountPill(
                label: 'Risposte',
                value: '${summary.answeredCount}/${summary.totalPlayers}',
                color: isComplete ? UltrasAppTheme.success : UltrasAppTheme.warning,
                emphasized: true,
              ),
              AppCountPill(
                label: 'Si',
                value: '${summary.presentCount}',
                color: UltrasAppTheme.success,
              ),
              AppCountPill(
                label: 'No',
                value: '${summary.absentCount}',
                color: UltrasAppTheme.danger,
              ),
              AppCountPill(
                label: 'Attesa',
                value: '${summary.pendingCount}',
                color: UltrasAppTheme.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AttendancePendingSection extends StatelessWidget {
  const AttendancePendingSection({
    super.key,
    required this.daySummaries,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<AttendanceDaySummary> daySummaries;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Card(
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
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi manca ancora',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Chi manca ancora',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
              const SizedBox(height: 14),
              for (final summary in daySummaries) ...[
                AttendancePendingDayCard(summary: summary),
                if (summary != daySummaries.last) const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class AttendancePendingDayCard extends StatelessWidget {
  const AttendancePendingDayCard({
    super.key,
    required this.summary,
  });

  final AttendanceDaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
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
                      formatAttendanceDayWithDate(summary.date),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Risposte ${summary.answeredCount}/${summary.totalPlayers}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UltrasAppTheme.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              AppCountPill(
                label: 'Attesa',
                value: '${summary.pendingCount}',
                color: summary.pendingCount == 0
                    ? UltrasAppTheme.success
                    : UltrasAppTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.pendingPlayers.isEmpty)
            Text(
              'Tutti hanno gia votato per questo giorno.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: UltrasAppTheme.successSoft,
                    fontWeight: FontWeight.w700,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final player in summary.pendingPlayers)
                  AppCountPill(
                    label: player.fullName,
                    color: UltrasAppTheme.warning,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class AttendancePermissionsCard extends StatelessWidget {
  const AttendancePermissionsCard({
    super.key,
    required this.viewer,
  });

  final PlayerProfile viewer;

  @override
  Widget build(BuildContext context) {
    final icon = viewer.isCaptain
        ? Icons.workspace_premium_outlined
        : viewer.isViceCaptain
            ? Icons.shield_outlined
            : Icons.person_outline;

    final title = viewer.canManageAttendanceAll
        ? 'Permessi estesi attivi'
        : 'Compilazione personale';
    final message = viewer.canManageAttendanceAll
        ? 'Come ${viewer.teamRoleDisplay.toLowerCase()} puoi creare i sondaggi, scegliere i giorni da votare, archiviare la settimana e correggere le disponibilita della squadra.'
        : 'Come giocatore puoi compilare solo le tue presenze giornaliere, senza vedere riepiloghi o voti degli altri.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconBadge(icon: icon, size: 42, borderRadius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: UltrasAppTheme.textMuted,
                          height: 1.35,
                        ),
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

class AttendanceWeekInfoCard extends StatelessWidget {
  const AttendanceWeekInfoCard({
    super.key,
    required this.week,
  });

  final AttendanceWeek week;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIconBadge(
              icon: Icons.calendar_today_outlined,
              size: 42,
              borderRadius: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    week.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${week.subtitle}. Giorni attivi: ${week.selectedDatesSummary}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: UltrasAppTheme.textMuted,
                          height: 1.35,
                        ),
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
