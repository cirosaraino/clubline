import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/player_profile.dart';
import 'app_chrome.dart';

class LineupPlayerPickerTile extends StatelessWidget {
  const LineupPlayerPickerTile({
    super.key,
    required this.player,
    required this.isRecommended,
    required this.isSelected,
    required this.onTap,
  });

  final PlayerProfile player;
  final bool isRecommended;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppResponsive.horizontalPadding(context),
        vertical: 4,
      ),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.65)
          : null,
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 6 : 8,
        ),
        title: Text(
          player.fullName,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${player.shirtNumberDisplay} • ${player.idConsoleDisplay}',
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ClublineAppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: player.roleCodes
                    .map(
                      (role) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          role,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.greenAccent)
            : isRecommended
            ? const Icon(Icons.auto_awesome_outlined)
            : const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
