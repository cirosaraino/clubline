import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/vice_permissions_repository.dart';
import '../../models/player_profile.dart';
import '../../models/vice_permissions.dart';
import 'app_chrome.dart';

class VicePermissionsSheet extends StatefulWidget {
  const VicePermissionsSheet({super.key});

  @override
  State<VicePermissionsSheet> createState() => _VicePermissionsSheetState();
}

class _VicePermissionsSheetState extends State<VicePermissionsSheet> {
  late final VicePermissionsRepository repository;
  late VicePermissions draftPermissions;
  bool hasInitializedDraft = false;

  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    repository = VicePermissionsRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (hasInitializedDraft) {
      return;
    }

    draftPermissions = AppSessionScope.read(context).vicePermissions;
    hasInitializedDraft = true;
  }

  Future<void> _save() async {
    final session = AppSessionScope.read(context);
    final currentUser = session.currentUser;
    if (currentUser?.canConfigureVicePermissions != true) {
      setState(() {
        errorMessage = 'Solo il capitano puo modificare i permessi dei vice.';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await repository.savePermissions(draftPermissions);
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.vicePermissions},
        reason: 'vice_permissions_updated',
      );
      unawaited(session.refresh(showLoadingState: false));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permessi vice aggiornati')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        isSaving = false;
        errorMessage = error.toString();
      });
    }
  }

  void _resetToFullAccess() {
    setState(() {
      draftPermissions = VicePermissions.fullAccess;
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final currentUser = session.currentUser;
    final vicePlayers = session.players.where((player) => player.isViceCaptain).toList();

    final isCaptain = currentUser?.canConfigureVicePermissions == true;
    final compact = AppResponsive.isCompact(context);
    final horizontalPadding = AppResponsive.horizontalPadding(context) + 4;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Permessi vice capitani',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  tooltip: 'Chiudi',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ViceScopeSummaryCard(
              vicePlayers: vicePlayers,
              permissions: draftPermissions,
            ),
            const SizedBox(height: 18),
            _PermissionSwitchCard(
              title: 'Rosa club',
              description:
                  'Aggiungere, modificare e cancellare giocatori dalla rosa. La modifica del ruolo club resta comunque solo al capitano.',
              value: draftPermissions.managePlayers,
              enabled: isCaptain && !isSaving,
              onChanged: (value) {
                setState(() {
                  draftPermissions = draftPermissions.copyWith(
                    managePlayers: value,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            _PermissionSwitchCard(
              title: 'Formazioni',
              description:
                  'Creare, modificare, duplicare e cancellare le formazioni.',
              value: draftPermissions.manageLineups,
              enabled: isCaptain && !isSaving,
              onChanged: (value) {
                setState(() {
                  draftPermissions = draftPermissions.copyWith(
                    manageLineups: value,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            _PermissionSwitchCard(
              title: 'Live',
              description:
                  'Creare, modificare e cancellare le live del club.',
              value: draftPermissions.manageStreams,
              enabled: isCaptain && !isSaving,
              onChanged: (value) {
                setState(() {
                  draftPermissions = draftPermissions.copyWith(
                    manageStreams: value,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            _PermissionSwitchCard(
              title: 'Presenze club',
              description:
                  'Aprire, archiviare, ripristinare le presenze e vedere o modificare le disponibilita di tutti.',
              value: draftPermissions.manageAttendance,
              enabled: isCaptain && !isSaving,
              onChanged: (value) {
                setState(() {
                  draftPermissions = draftPermissions.copyWith(
                    manageAttendance: value,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            _PermissionSwitchCard(
              title: 'Info club',
              description:
                  'Aggiornare nome club, logo e link utili della Home.',
              value: draftPermissions.manageTeamInfo,
              enabled: isCaptain && !isSaving,
              onChanged: (value) {
                setState(() {
                  draftPermissions = draftPermissions.copyWith(
                    manageTeamInfo: value,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: compact ? double.infinity : null,
                  child: ElevatedButton.icon(
                    onPressed: isCaptain && !isSaving ? _save : null,
                    icon: Icon(
                      isSaving ? Icons.hourglass_top_outlined : Icons.save_outlined,
                    ),
                    label: Text(isSaving ? 'Salvataggio...' : 'Salva permessi'),
                  ),
                ),
                SizedBox(
                  width: compact ? double.infinity : null,
                  child: OutlinedButton.icon(
                    onPressed: isCaptain && !isSaving ? _resetToFullAccess : null,
                    icon: const Icon(Icons.restart_alt_outlined),
                    label: const Text('Abilita tutto'),
                  ),
                ),
                SizedBox(
                  width: compact ? double.infinity : null,
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_outlined),
                    label: const Text('Chiudi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ViceScopeSummaryCard extends StatelessWidget {
  const _ViceScopeSummaryCard({
    required this.vicePlayers,
    required this.permissions,
  });

  final List<PlayerProfile> vicePlayers;
  final VicePermissions permissions;

  @override
  Widget build(BuildContext context) {
    final viceNames = vicePlayers.map((player) => player.fullName).toList();
    final compact = AppResponsive.isCompact(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ClublineAppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vicePlayers.isEmpty
                ? 'Nessun vice capitano assegnato'
                : vicePlayers.length == 1
                    ? 'Vice attuale'
                    : 'Vice attuali',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            viceNames.isEmpty
                ? 'Quando assegnerai uno o piu vice, i permessi qui sotto varranno per tutti loro.'
                : viceNames.join(' • '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ClublineAppTheme.textMuted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PermissionPill(
                label: 'Rosa',
                enabled: permissions.managePlayers,
              ),
              _PermissionPill(
                label: 'Formazioni',
                enabled: permissions.manageLineups,
              ),
              _PermissionPill(
                label: 'Live',
                enabled: permissions.manageStreams,
              ),
              _PermissionPill(
                label: 'Presenze',
                enabled: permissions.manageAttendance,
              ),
              _PermissionPill(
                label: 'Info club',
                enabled: permissions.manageTeamInfo,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionSwitchCard extends StatelessWidget {
  const _PermissionSwitchCard({
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ClublineAppTheme.textMuted,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionPill extends StatelessWidget {
  const _PermissionPill({
    required this.label,
    required this.enabled,
  });

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled
        ? ClublineAppTheme.success.withValues(alpha: 0.16)
        : ClublineAppTheme.surface;
    final borderColor = enabled
        ? ClublineAppTheme.success.withValues(alpha: 0.34)
        : ClublineAppTheme.outlineSoft;
    final foregroundColor = enabled
        ? ClublineAppTheme.successSoft
        : ClublineAppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 15,
            color: foregroundColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
