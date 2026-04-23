import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_data_sync.dart';
import '../../core/app_theme.dart';
import '../../core/player_constants.dart';
import '../../data/player_repository.dart';
import '../../models/player_profile.dart';
import '../widgets/app_chrome.dart';
import '../widgets/player_list_tile.dart';
import 'player_form_page.dart';

class PlayersPage extends StatefulWidget {
  const PlayersPage({super.key});

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  late final PlayerRepository repository;
  final scrollController = ScrollController();
  final idController = TextEditingController();
  final nomeController = TextEditingController();
  final cognomeController = TextEditingController();
  final Map<dynamic, GlobalKey> playerTileKeys = {};

  List<PlayerProfile> players = [];
  String? selectedMacroRoleFilter;
  String? selectedRoleFilter;
  bool isLoading = true;
  String? errorMessage;
  int lastHandledSyncRevision = 0;
  dynamic pendingScrollPlayerId;
  bool isFiltersExpanded = false;
  bool _isLoadingRequest = false;
  bool _reloadRequested = false;

  @override
  void initState() {
    super.initState();
    repository = PlayerRepository();
    AppDataSync.instance.addListener(_handleAppDataSync);
    _loadPlayers();
  }

  @override
  void dispose() {
    AppDataSync.instance.removeListener(_handleAppDataSync);
    scrollController.dispose();
    idController.dispose();
    nomeController.dispose();
    cognomeController.dispose();
    super.dispose();
  }

  void _handleAppDataSync() {
    final change = AppDataSync.instance.latestChange;
    if (change == null || change.revision == lastHandledSyncRevision) return;
    if (!change.affects({AppDataScope.players})) return;

    lastHandledSyncRevision = change.revision;
    unawaited(_loadPlayers(silent: true));
  }

  Future<void> _loadPlayers({bool silent = false}) async {
    if (!mounted) {
      return;
    }

    if (_isLoadingRequest) {
      _reloadRequested = true;
      return;
    }

    _isLoadingRequest = true;
    final showBlockingLoader = !silent || players.isEmpty;

    setState(() {
      if (showBlockingLoader) {
        isLoading = true;
      }
      errorMessage = null;
    });

    try {
      final response = await repository.fetchPlayers();
      if (!mounted) {
        return;
      }
      setState(() {
        players = response;
        isLoading = false;
      });
      _scrollToPendingPlayer();
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (showBlockingLoader) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    } finally {
      _isLoadingRequest = false;
      if (_reloadRequested) {
        _reloadRequested = false;
        unawaited(_loadPlayers(silent: true));
      }
    }
  }

  Future<void> _openPlayerForm({PlayerProfile? player}) async {
    final session = AppSessionScope.read(context);
    final currentUser = session.currentUser;
    final canOpen = player == null
        ? currentUser?.canManagePlayers == true
        : currentUser?.canEditPlayer(player.id) == true;
    if (!canOpen) return;

    final editedPlayerId = player?.id;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => PlayerFormPage(player: player)),
    );

    if (result == true && editedPlayerId != null) {
      pendingScrollPlayerId = editedPlayerId;
      await _loadPlayers();
    }
  }

  bool _canReleasePlayer(PlayerProfile player, PlayerProfile? currentUser) {
    if (currentUser?.canManagePlayers != true) {
      return false;
    }

    if (player.isCaptain) {
      return false;
    }

    return currentUser?.id != player.id;
  }

  Future<void> _releasePlayer(PlayerProfile player) async {
    final session = AppSessionScope.read(context);
    if (session.currentUser?.canManagePlayers != true) {
      return;
    }

    if (player.id == null) {
      setState(() {
        errorMessage = 'Impossibile svincolare il giocatore: ID mancante';
      });
      return;
    }

    final shouldRelease = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Svincola giocatore'),
        content: Text(
          'Vuoi davvero rimuovere ${player.fullName} dalla squadra?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Svincola'),
          ),
        ],
      ),
    );

    if (shouldRelease != true) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await repository.releasePlayerFromClub(player.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${player.fullName} svincolato dal club')),
      );
      AppDataSync.instance.notifyDataChanged({
        AppDataScope.players,
        AppDataScope.attendance,
      }, reason: 'player_released');
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String _normalizedFilterValue(String value) {
    return value.trim().toLowerCase();
  }

  List<PlayerProfile> get _filteredPlayers {
    final macroRoleFilter = selectedMacroRoleFilter;
    final roleFilter = selectedRoleFilter;
    final idFilter = _normalizedFilterValue(idController.text);
    final nomeFilter = _normalizedFilterValue(nomeController.text);
    final cognomeFilter = _normalizedFilterValue(cognomeController.text);

    return players.where((player) {
      if (macroRoleFilter != null &&
          player.primaryRoleCategory != macroRoleFilter) {
        return false;
      }

      if (roleFilter != null && !player.roleCodes.contains(roleFilter)) {
        return false;
      }

      final playerIdConsole = _normalizedFilterValue(player.idConsole ?? '');
      if (idFilter.isNotEmpty && !playerIdConsole.contains(idFilter)) {
        return false;
      }

      if (nomeFilter.isNotEmpty &&
          !_normalizedFilterValue(player.nome).contains(nomeFilter)) {
        return false;
      }

      if (cognomeFilter.isNotEmpty &&
          !_normalizedFilterValue(player.cognome).contains(cognomeFilter)) {
        return false;
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    idController.clear();
    nomeController.clear();
    cognomeController.clear();

    setState(() {
      selectedMacroRoleFilter = null;
      selectedRoleFilter = null;
    });
  }

  GlobalKey _keyForPlayer(dynamic playerId) {
    return playerTileKeys.putIfAbsent(playerId, () => GlobalKey());
  }

  Widget _buildTopPanel({
    required Map<String, int> totalsByCategory,
    required int visiblePlayers,
    required int totalPlayers,
  }) {
    return AppAdaptiveColumns(
      breakpoint: 980,
      gap: AppResponsive.sectionGap(context),
      flex: const [2, 3],
      children: [
        _PlayersMacroRoleRecapCard(
          totalPlayers: players.length,
          totalsByCategory: totalsByCategory,
        ),
        _PlayersFilterCard(
          isExpanded: isFiltersExpanded,
          onToggle: () {
            setState(() {
              isFiltersExpanded = !isFiltersExpanded;
            });
          },
          selectedMacroRoleFilter: selectedMacroRoleFilter,
          selectedRoleFilter: selectedRoleFilter,
          idController: idController,
          nomeController: nomeController,
          cognomeController: cognomeController,
          totalPlayers: totalPlayers,
          visiblePlayers: visiblePlayers,
          onMacroRoleChanged: (value) {
            setState(() {
              selectedMacroRoleFilter = value;
            });
          },
          onRoleChanged: (value) {
            setState(() {
              selectedRoleFilter = value;
            });
          },
          onFiltersChanged: () {
            setState(() {});
          },
          onClearFilters: _clearFilters,
        ),
      ],
    );
  }

  void _scrollToPendingPlayer() {
    final playerId = pendingScrollPlayerId;
    if (playerId == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final context = playerTileKeys[playerId]?.currentContext;
      pendingScrollPlayerId = null;

      if (context == null) {
        return;
      }

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

  List<_PlayerSectionData> _buildSections(List<PlayerProfile> sourcePlayers) {
    final groupedPlayers = {
      for (final category in kPrimaryRoleCategoryOrder)
        category: <PlayerProfile>[],
    };
    final unassignedPlayers = <PlayerProfile>[];

    for (final player in sourcePlayers) {
      final category = player.primaryRoleCategory;
      if (category != null && groupedPlayers.containsKey(category)) {
        groupedPlayers[category]!.add(player);
      } else {
        unassignedPlayers.add(player);
      }
    }

    final sections = <_PlayerSectionData>[
      for (final category in kPrimaryRoleCategoryOrder)
        if (groupedPlayers[category]!.isNotEmpty)
          _PlayerSectionData(
            title: kRoleCategorySectionTitles[category]!,
            players: groupedPlayers[category]!,
            icon: _iconForCategory(category),
          ),
    ];

    if (unassignedPlayers.isNotEmpty) {
      sections.add(
        _PlayerSectionData(
          title: kUnassignedRoleSectionTitle,
          players: unassignedPlayers,
          icon: Icons.help_outline_rounded,
        ),
      );
    }

    return sections;
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Portiere':
        return Icons.sports_handball_outlined;
      case 'Difensore':
        return Icons.shield_outlined;
      case 'Centrocampista':
        return Icons.hub_outlined;
      case 'Attaccante':
        return Icons.bolt_outlined;
      default:
        return Icons.groups_2_outlined;
    }
  }

  Map<String, int> _primaryRoleCategoryTotals(
    List<PlayerProfile> sourcePlayers,
  ) {
    final totals = {
      for (final category in kPrimaryRoleCategoryOrder) category: 0,
    };

    for (final player in sourcePlayers) {
      final category = player.primaryRoleCategory;
      if (category == null || !totals.containsKey(category)) {
        continue;
      }

      totals[category] = (totals[category] ?? 0) + 1;
    }

    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AppSessionScope.of(context).currentUser;
    final canManagePlayers = currentUser?.canManagePlayers ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Rosa club')),
      floatingActionButton: canManagePlayers
          ? FloatingActionButton(
              heroTag: 'players_page_fab',
              onPressed: () => _openPlayerForm(),
              child: const Icon(Icons.add),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildScrollableBody(
    List<Widget> children, {
    EdgeInsetsGeometry? padding,
  }) {
    return AppPageBackground(
      child: RefreshIndicator(
        onRefresh: _loadPlayers,
        child: AppContentFrame(
          wide: true,
          child: ListView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding ?? AppResponsive.pagePadding(context),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final currentUser = AppSessionScope.of(context).currentUser;

    if (isLoading) {
      return const AppPageBackground(
        child: AppLoadingState(label: 'Stiamo caricando la rosa...'),
      );
    }

    if (errorMessage != null) {
      return _buildScrollableBody([
        const AppPageHeader(
          eyebrow: 'Rosa',
          title: 'Gestisci giocatori e ruoli',
          subtitle:
              'Consulta la rosa, filtra per ruolo e aggiorna i profili dei giocatori del club.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppErrorState(
          title: 'Errore nel caricamento della rosa',
          message: errorMessage!,
          actionLabel: 'Riprova',
          onAction: _loadPlayers,
        ),
      ], padding: AppResponsive.pagePadding(context, top: 24));
    }

    if (players.isEmpty) {
      return _buildScrollableBody(const [
        AppPageHeader(
          eyebrow: 'Rosa',
          title: 'Gestisci giocatori e ruoli',
          subtitle:
              'Consulta la rosa, filtra per ruolo e aggiorna i profili dei giocatori del club.',
        ),
        SizedBox(height: AppSpacing.lg),
        AppEmptyState(
          icon: Icons.groups_2_outlined,
          title: 'Nessun giocatore trovato',
          message:
              'Aggiungi i primi giocatori per iniziare a costruire la rosa del club.',
        ),
      ], padding: AppResponsive.pagePadding(context, top: 24));
    }

    final filteredPlayers = _filteredPlayers;
    final sections = _buildSections(filteredPlayers);
    final totalsByCategory = _primaryRoleCategoryTotals(players);

    if (filteredPlayers.isEmpty) {
      return _buildScrollableBody([
        const AppPageHeader(
          eyebrow: 'Rosa',
          title: 'Gestisci giocatori e ruoli',
          subtitle:
              'Consulta la rosa, filtra per ruolo e aggiorna i profili dei giocatori del club.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildTopPanel(
          totalsByCategory: totalsByCategory,
          visiblePlayers: 0,
          totalPlayers: players.length,
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppEmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Nessun giocatore trovato',
          message:
              'Nessun elemento corrisponde ai filtri impostati. Prova a cambiare ruolo o a svuotare uno dei campi di ricerca.',
        ),
      ]);
    }

    return _buildScrollableBody([
      const AppPageHeader(
        eyebrow: 'Rosa',
        title: 'Gestisci giocatori e ruoli',
        subtitle:
            'Consulta la rosa, filtra per ruolo e aggiorna i profili dei giocatori del club.',
      ),
      const SizedBox(height: AppSpacing.lg),
      _buildTopPanel(
        totalsByCategory: totalsByCategory,
        visiblePlayers: filteredPlayers.length,
        totalPlayers: players.length,
      ),
      const SizedBox(height: AppSpacing.lg),
      for (final section in sections) ...[
        AppSectionHeader(
          title: section.title,
          count: section.players.length,
          icon: section.icon,
          showCount: false,
        ),
        const SizedBox(height: 8),
        for (final player in section.players)
          PlayerListTile(
            key: _keyForPlayer(player.id),
            player: player,
            isCurrentUser: currentUser?.id == player.id,
            onEdit: currentUser?.canEditPlayer(player.id) == true
                ? () => _openPlayerForm(player: player)
                : null,
            onRelease: _canReleasePlayer(player, currentUser)
                ? () => _releasePlayer(player)
                : null,
          ),
        const SizedBox(height: 16),
      ],
    ]);
  }
}

class _PlayerSectionData {
  const _PlayerSectionData({
    required this.title,
    required this.players,
    required this.icon,
  });

  final String title;
  final List<PlayerProfile> players;
  final IconData icon;
}

class _PlayersMacroRoleRecapCard extends StatelessWidget {
  const _PlayersMacroRoleRecapCard({
    required this.totalPlayers,
    required this.totalsByCategory,
  });

  final int totalPlayers;
  final Map<String, int> totalsByCategory;

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Portiere':
        return Icons.sports_handball_outlined;
      case 'Difensore':
        return Icons.shield_outlined;
      case 'Centrocampista':
        return Icons.hub_outlined;
      case 'Attaccante':
        return Icons.bolt_outlined;
      default:
        return Icons.groups_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      icon: Icons.groups_2_outlined,
      title: 'Rosa totale',
      subtitle: '$totalPlayers giocatori attivi nel club.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final category in kPrimaryRoleCategoryOrder)
            AppCountPill(
              label: category,
              value: '${totalsByCategory[category] ?? 0}',
              icon: _iconForCategory(category),
              emphasized: true,
            ),
        ],
      ),
    );
  }
}

class _PlayersFilterCard extends StatelessWidget {
  const _PlayersFilterCard({
    required this.isExpanded,
    required this.onToggle,
    required this.selectedMacroRoleFilter,
    required this.selectedRoleFilter,
    required this.idController,
    required this.nomeController,
    required this.cognomeController,
    required this.totalPlayers,
    required this.visiblePlayers,
    required this.onMacroRoleChanged,
    required this.onRoleChanged,
    required this.onFiltersChanged,
    required this.onClearFilters,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final String? selectedMacroRoleFilter;
  final String? selectedRoleFilter;
  final TextEditingController idController;
  final TextEditingController nomeController;
  final TextEditingController cognomeController;
  final int totalPlayers;
  final int visiblePlayers;
  final ValueChanged<String?> onMacroRoleChanged;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onFiltersChanged;
  final VoidCallback onClearFilters;

  bool get hasActiveFilters {
    return selectedMacroRoleFilter != null ||
        selectedRoleFilter != null ||
        idController.text.trim().isNotEmpty ||
        nomeController.text.trim().isNotEmpty ||
        cognomeController.text.trim().isNotEmpty;
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    final filtersForm = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('players-filter-macro-$selectedMacroRoleFilter'),
          initialValue: selectedMacroRoleFilter,
          decoration: _inputDecoration('Macroruolo', Icons.category_outlined),
          hint: const Text('Tutti i macroruoli'),
          items: kPrimaryRoleCategoryOrder
              .map(
                (category) => DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                ),
              )
              .toList(),
          onChanged: onMacroRoleChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('players-filter-role-$selectedRoleFilter'),
          initialValue: selectedRoleFilter,
          decoration: _inputDecoration('Ruolo', Icons.swap_horiz_rounded),
          hint: const Text('Tutti i ruoli'),
          items: kPlayerRoles
              .map(
                (role) => DropdownMenuItem<String>(
                  value: role,
                  child: Text('$role - ${kRoleCategories[role]}'),
                ),
              )
              .toList(),
          onChanged: onRoleChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: idController,
          onChanged: (_) => onFiltersChanged(),
          decoration: _inputDecoration('ID console', Icons.badge_outlined),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: nomeController,
          onChanged: (_) => onFiltersChanged(),
          decoration: _inputDecoration('Nome', Icons.person_outline),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cognomeController,
          onChanged: (_) => onFiltersChanged(),
          decoration: _inputDecoration('Cognome', Icons.person_search_outlined),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: compact ? double.infinity : null,
            child: OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.close_outlined),
              label: const Text('Rimuovi filtri'),
            ),
          ),
        ],
      ],
    );

    return AppSurfaceCard(
      icon: Icons.filter_list_outlined,
      title: 'Filtri rosa',
      trailing: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppCountPill(
                label: '$visiblePlayers / $totalPlayers',
                emphasized: true,
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ],
          ),
        ),
      ),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 220),
        crossFadeState: isExpanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: Text(
          hasActiveFilters
              ? 'Filtri attivi: apri il pannello per modificarli o ripulirli.'
              : 'Apri i filtri per restringere la rosa per ruolo, nome o ID console.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: hasActiveFilters
                ? Theme.of(context).colorScheme.primary
                : ClublineAppTheme.textMuted,
            fontWeight: hasActiveFilters ? FontWeight.w700 : null,
          ),
        ),
        secondChild: filtersForm,
      ),
    );
  }
}
