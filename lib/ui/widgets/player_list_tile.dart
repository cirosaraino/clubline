import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/player_profile.dart';
import 'app_chrome.dart';

class PlayerListTile extends StatelessWidget {
  const PlayerListTile({
    super.key,
    required this.player,
    this.onEdit,
    this.onRelease,
    this.isCurrentUser = false,
  });

  final PlayerProfile player;
  final VoidCallback? onEdit;
  final VoidCallback? onRelease;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: ClublineAppTheme.textMuted);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppResponsive.cardPadding(context),
          AppResponsive.cardPadding(context) - 2,
          compact ? 12 : 10,
          AppResponsive.cardPadding(context) - 2,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.idConsoleDisplay, style: titleStyle),
                      const SizedBox(height: 4),
                      Text(
                        player.fullName,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (isCurrentUser) ...[
                  const _MetaPill(
                    icon: Icons.person_pin_circle_outlined,
                    label: 'Tu',
                    highlighted: true,
                  ),
                  const SizedBox(width: 6),
                ],
                if (compact && (onEdit != null || onRelease != null))
                  _PlayerTileMenu(onEdit: onEdit, onRelease: onRelease)
                else ...[
                  if (onEdit != null) ...[
                    _ActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Modifica giocatore',
                      onPressed: onEdit!,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (onRelease != null)
                    _ActionButton(
                      icon: Icons.person_remove_outlined,
                      tooltip: 'Svincola dal club',
                      isDestructive: true,
                      onPressed: onRelease!,
                    ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    icon: player.isCaptain
                        ? Icons.workspace_premium_outlined
                        : player.isViceCaptain
                        ? Icons.shield_outlined
                        : Icons.person_outline,
                    label: player.teamRoleDisplay,
                    highlighted: player.isCaptain || player.isViceCaptain,
                  ),
                  _MetaPill(
                    icon: Icons.tag_outlined,
                    label: 'N ${player.shirtNumberDisplay}',
                    highlighted: true,
                  ),
                  if (player.roleCodes.isEmpty)
                    const _MetaPill(
                      icon: Icons.help_outline,
                      label: 'Ruolo non impostato',
                    ),
                  for (final role in player.roleCodes)
                    _MetaPill(
                      icon: role == player.primaryRole
                          ? Icons.stars_rounded
                          : Icons.swap_horiz_rounded,
                      label: role,
                      highlighted: role == player.primaryRole,
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

class _PlayerTileMenu extends StatelessWidget {
  const _PlayerTileMenu({required this.onEdit, required this.onRelease});

  final VoidCallback? onEdit;
  final VoidCallback? onRelease;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Azioni giocatore',
      onSelected: (value) {
        if (value == 'edit') {
          onEdit?.call();
        } else if (value == 'release') {
          onRelease?.call();
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
        if (onRelease != null)
          PopupMenuItem<String>(
            value: 'release',
            child: ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Svincola',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
      child: const _ActionButton(
        icon: Icons.more_vert,
        tooltip: 'Azioni giocatore',
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = highlighted
        ? ClublineAppTheme.gold.withValues(alpha: 0.18)
        : ClublineAppTheme.surfaceAlt;
    final foregroundColor = highlighted
        ? ClublineAppTheme.goldSoft
        : ClublineAppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? ClublineAppTheme.outlineStrong
              : ClublineAppTheme.outlineSoft,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isDestructive
        ? Theme.of(context).colorScheme.error
        : ClublineAppTheme.textPrimary;

    return Material(
      color: ClublineAppTheme.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: foregroundColor),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
