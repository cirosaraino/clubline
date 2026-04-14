import 'package:flutter/material.dart';

import '../../models/player_profile.dart';

class LineupPositionAssignmentTile extends StatelessWidget {
  const LineupPositionAssignmentTile({
    super.key,
    required this.positionCode,
    required this.players,
    required this.selectedPlayerId,
    required this.onChanged,
    required this.enabled,
  });

  final String positionCode;
  final List<PlayerProfile> players;
  final dynamic selectedPlayerId;
  final ValueChanged<dynamic> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final dropdownItems = [
      const DropdownMenuItem<dynamic>(
        value: null,
        child: Text('Nessuno'),
      ),
      ...players.map(
        (player) => DropdownMenuItem<dynamic>(
          value: player.id,
          child: _PlayerDropdownItem(player: player),
        ),
      ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              positionCode,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<dynamic>(
              initialValue: selectedPlayerId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Giocatore',
                border: OutlineInputBorder(),
              ),
              items: dropdownItems,
              selectedItemBuilder: (context) {
                return [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Nessuno'),
                  ),
                  ...players.map(
                    (player) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        player.lineupSelectionSummary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ];
              },
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerDropdownItem extends StatelessWidget {
  const _PlayerDropdownItem({required this.player});

  final PlayerProfile player;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: player.roleCodes
              .map(
                (role) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        const SizedBox(height: 6),
        Text(
          '${player.idConsoleDisplay} • ${player.fullName}',
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
