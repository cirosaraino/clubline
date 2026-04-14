import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/lineup.dart';
import 'app_chrome.dart';

class LineupListCard extends StatelessWidget {
  const LineupListCard({
    super.key,
    required this.lineup,
    required this.onOpenDetails,
    this.isManageMode = false,
    this.onDuplicate,
    this.onEdit,
    this.onDelete,
    this.viewerLineupStatusLabel,
    this.viewerLineupStatusPositive,
    this.assignedPlayersCount = 0,
  });

  final Lineup lineup;
  final VoidCallback onOpenDetails;
  final bool isManageMode;
  final VoidCallback? onDuplicate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? viewerLineupStatusLabel;
  final bool? viewerLineupStatusPositive;
  final int assignedPlayersCount;

  @override
  Widget build(BuildContext context) {
    final actionLabel = isManageMode ? 'Giocatori' : 'Apri dettaglio';
    final compact = AppResponsive.isCompact(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              Text(
                lineup.competitionName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _LineupBadge(label: lineup.formationModule),
                  ),
                  if (onEdit != null || onDuplicate != null || onDelete != null)
                    _LineupActionMenu(
                      onEdit: onEdit,
                      onDuplicate: onDuplicate,
                      onDelete: onDelete,
                    ),
                ],
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      lineup.competitionName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LineupBadge(label: lineup.formationModule),
                  if (onEdit != null || onDuplicate != null || onDelete != null) ...[
                    const SizedBox(width: 8),
                    _LineupActionMenu(
                      onEdit: onEdit,
                      onDuplicate: onDuplicate,
                      onDelete: onDelete,
                    ),
                  ],
                ],
              ),
            if (viewerLineupStatusLabel != null) ...[
              const SizedBox(height: 10),
              _ViewerStatusBadge(
                label: viewerLineupStatusLabel!,
                positive: viewerLineupStatusPositive ?? false,
              ),
            ],
            const SizedBox(height: 14),
            _LineupInfoRow(
              icon: Icons.schedule_outlined,
              label: 'Partita',
              value: lineup.matchDateTimeDisplay,
            ),
            if (lineup.hasOpponentName) ...[
              const SizedBox(height: 8),
              _LineupInfoRow(
                icon: Icons.shield_outlined,
                label: 'Avversario',
                value: lineup.opponentName!,
              ),
            ],
            const SizedBox(height: 8),
            _LineupInfoRow(
              icon: Icons.groups_2_outlined,
              label: 'Giocatori assegnati',
              value: '$assignedPlayersCount',
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 14),
            SizedBox(
              width: compact ? double.infinity : null,
              child: ElevatedButton.icon(
                onPressed: onOpenDetails,
                icon: const Icon(Icons.remove_red_eye_outlined),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineupActionMenu extends StatelessWidget {
  const _LineupActionMenu({
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (onEdit == null && onDuplicate == null && onDelete == null) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Azioni formazione',
      onSelected: (value) {
        if (value == 'edit') {
          onEdit?.call();
        } else if (value == 'duplicate') {
          onDuplicate?.call();
        } else if (value == 'delete') {
          onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem<String>(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Modifica'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDuplicate != null)
          const PopupMenuItem<String>(
            value: 'duplicate',
            child: ListTile(
              leading: Icon(Icons.content_copy_outlined),
              title: Text('Duplica'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Cancella',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
      child: const Icon(Icons.more_vert),
    );
  }
}

class _ViewerStatusBadge extends StatelessWidget {
  const _ViewerStatusBadge({
    required this.label,
    required this.positive,
  });

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = positive
        ? UltrasAppTheme.success.withValues(alpha: 0.14)
        : UltrasAppTheme.danger;
    final borderColor = positive
        ? UltrasAppTheme.success
        : UltrasAppTheme.danger;
    final textColor = positive
        ? UltrasAppTheme.successSoft
        : Colors.white;
    final icon = positive ? Icons.check_circle_outline : Icons.cancel_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _LineupBadge extends StatelessWidget {
  const _LineupBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: UltrasAppTheme.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: UltrasAppTheme.outlineStrong),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: UltrasAppTheme.goldSoft,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _LineupInfoRow extends StatelessWidget {
  const _LineupInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: UltrasAppTheme.goldSoft),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: UltrasAppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
