import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/stream_link_formatters.dart';
import '../../models/stream_link.dart';
import 'app_chrome.dart';

class StreamLinkCard extends StatelessWidget {
  const StreamLinkCard({
    super.key,
    required this.streamLink,
    required this.onOpen,
    required this.onCopy,
    this.onEdit,
    this.onDelete,
  });

  final StreamLink streamLink;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final tags = <Widget>[
      if (streamLink.hasCompetitionName)
        _StreamTag(
          icon: Icons.emoji_events_outlined,
          label: streamLink.competitionName!,
        ),
      if ((streamLink.provider ?? '').trim().isNotEmpty)
        _StreamTag(
          icon: Icons.ondemand_video_outlined,
          label: streamLink.provider!.toUpperCase(),
        ),
      if (streamLink.hasResult)
        _StreamTag(icon: Icons.scoreboard_outlined, label: streamLink.result!),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardLeadingIcon(status: streamLink.streamStatus),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        streamLink.streamTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                      ),
                    ),
                    if (onEdit != null || onDelete != null) ...[
                      const SizedBox(width: 8),
                      _StreamActionMenu(onEdit: onEdit, onDelete: onDelete),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _StreamBadge(
                  label: streamLink.statusLabel,
                  status: streamLink.streamStatus,
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: tags),
                ],
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardLeadingIcon(status: streamLink.streamStatus),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            streamLink.streamTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: tags),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StreamBadge(
                          label: streamLink.statusLabel,
                          status: streamLink.streamStatus,
                        ),
                        if (onEdit != null || onDelete != null) ...[
                          const SizedBox(height: 8),
                          _StreamActionMenu(onEdit: onEdit, onDelete: onDelete),
                        ],
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ClublineAppTheme.outlineSoft),
                ),
                child: Column(
                  children: [
                    if (compact) ...[
                      _StreamFactTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Giorno live',
                        value: streamLink.playedOnDisplay,
                      ),
                      const SizedBox(height: 10),
                      _StreamFactTile(
                        icon: streamLink.hasEndedAt
                            ? Icons.schedule_outlined
                            : Icons.videocam_outlined,
                        label: streamLink.hasEndedAt ? 'Conclusa' : 'Stato',
                        value: streamLink.hasEndedAt
                            ? streamLink.endedAtDisplay!
                            : streamLink.statusLabel,
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: _StreamFactTile(
                              icon: Icons.calendar_today_outlined,
                              label: 'Giorno live',
                              value: streamLink.playedOnDisplay,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StreamFactTile(
                              icon: streamLink.hasEndedAt
                                  ? Icons.schedule_outlined
                                  : Icons.videocam_outlined,
                              label: streamLink.hasEndedAt
                                  ? 'Conclusa'
                                  : 'Stato',
                              value: streamLink.hasEndedAt
                                  ? streamLink.endedAtDisplay!
                                  : streamLink.statusLabel,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    _StreamLinkPanel(url: streamLink.streamUrl),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (compact) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('Apri live'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copia link'),
                  ),
                ),
              ] else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new_outlined),
                      label: const Text('Apri live'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copia link'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamActionMenu extends StatelessWidget {
  const _StreamActionMenu({required this.onEdit, required this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (onEdit == null && onDelete == null) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Azioni live',
      onSelected: (value) {
        if (value == 'edit') {
          onEdit?.call();
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
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Elimina',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
      child: const Icon(Icons.more_vert),
    );
  }
}

class _CardLeadingIcon extends StatelessWidget {
  const _CardLeadingIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = normalizeStreamStatus(status);
    final background = normalizedStatus == 'live'
        ? ClublineAppTheme.danger.withValues(alpha: 0.14)
        : normalizedStatus == 'scheduled'
        ? ClublineAppTheme.info.withValues(alpha: 0.14)
        : normalizedStatus == 'ended'
        ? ClublineAppTheme.surfaceAlt.withValues(alpha: 0.82)
        : ClublineAppTheme.gold.withValues(alpha: 0.12);
    final border = normalizedStatus == 'live'
        ? ClublineAppTheme.danger
        : normalizedStatus == 'scheduled'
        ? ClublineAppTheme.info
        : normalizedStatus == 'ended'
        ? ClublineAppTheme.outlineSoft
        : ClublineAppTheme.outline;
    final iconColor = normalizedStatus == 'live'
        ? ClublineAppTheme.dangerSoft
        : normalizedStatus == 'scheduled'
        ? ClublineAppTheme.infoSoft
        : normalizedStatus == 'ended'
        ? ClublineAppTheme.textMuted
        : ClublineAppTheme.goldSoft;
    final icon = normalizedStatus == 'live'
        ? Icons.radio_button_checked
        : normalizedStatus == 'scheduled'
        ? Icons.event_available_outlined
        : normalizedStatus == 'ended'
        ? Icons.videocam_off_outlined
        : Icons.help_outline;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: iconColor),
    );
  }
}

class _StreamBadge extends StatelessWidget {
  const _StreamBadge({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = normalizeStreamStatus(status);
    final backgroundColor = normalizedStatus == 'live'
        ? ClublineAppTheme.danger.withValues(alpha: 0.14)
        : normalizedStatus == 'scheduled'
        ? ClublineAppTheme.info.withValues(alpha: 0.14)
        : normalizedStatus == 'ended'
        ? ClublineAppTheme.surfaceAlt.withValues(alpha: 0.86)
        : ClublineAppTheme.gold.withValues(alpha: 0.16);
    final borderColor = normalizedStatus == 'live'
        ? ClublineAppTheme.danger
        : normalizedStatus == 'scheduled'
        ? ClublineAppTheme.info
        : normalizedStatus == 'ended'
        ? ClublineAppTheme.outlineSoft
        : ClublineAppTheme.outlineStrong;
    final textColor = normalizedStatus == 'live'
        ? ClublineAppTheme.dangerSoft
        : normalizedStatus == 'scheduled'
        ? ClublineAppTheme.infoSoft
        : normalizedStatus == 'ended'
        ? ClublineAppTheme.textPrimary
        : ClublineAppTheme.goldSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StreamTag extends StatelessWidget {
  const _StreamTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ClublineAppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ClublineAppTheme.outlineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ClublineAppTheme.goldSoft),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ClublineAppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamFactTile extends StatelessWidget {
  const _StreamFactTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClublineAppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClublineAppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: ClublineAppTheme.goldSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ClublineAppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StreamLinkPanel extends StatelessWidget {
  const _StreamLinkPanel({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: ClublineAppTheme.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClublineAppTheme.outlineSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.link_outlined, size: 18, color: ClublineAppTheme.goldSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClublineAppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.open_in_new_outlined,
            size: 18,
            color: ClublineAppTheme.textMuted,
          ),
        ],
      ),
    );
  }
}
