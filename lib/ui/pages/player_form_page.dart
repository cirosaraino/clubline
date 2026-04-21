import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/player_constants.dart';
import '../../core/player_formatters.dart';
import '../../data/player_repository.dart';
import '../../data/profile_setup_draft_store.dart';
import '../../models/player_profile.dart';
import '../widgets/app_chrome.dart';

class PlayerFormPage extends StatefulWidget {
  const PlayerFormPage({
    super.key,
    this.player,
    this.selfRegistration = false,
    this.draftOnly = false,
  });

  final PlayerProfile? player;
  final bool selfRegistration;
  final bool draftOnly;

  @override
  State<PlayerFormPage> createState() => _PlayerFormPageState();
}

class _PlayerFormPageState extends State<PlayerFormPage> {
  late final PlayerRepository repository;
  final nomeController = TextEditingController();
  final cognomeController = TextEditingController();
  final accountEmailController = TextEditingController();
  final idConsoleController = TextEditingController();

  String? selectedShirtNumber;
  String? selectedPrimaryRole;
  List<String> selectedSecondaryRoles = [];
  String selectedTeamRole = 'player';
  bool isSaving = false;
  String? errorMessage;
  String? accountEmailError;
  String? idConsoleError;
  bool hasCreatedPlayers = false;
  bool hasSeededRegistrationEmail = false;
  bool hasSeededBootstrapRole = false;
  bool hasSeededRegistrationProfile = false;
  bool hasRequestedProfileDraftSeed = false;

  bool get isEditing => widget.player != null;
  bool get isDraftOnly => widget.draftOnly;
  bool get isProfileCompletionFlow =>
      widget.selfRegistration ||
      (widget.player?.needsProfileCompletion ?? false);

  @override
  void initState() {
    super.initState();
    repository = PlayerRepository();
    _populateForm();
  }

  void _populateForm() {
    final player = widget.player;
    if (player == null) return;

    nomeController.text = player.nome;
    cognomeController.text = player.cognome;
    accountEmailController.text = player.accountEmail ?? '';
    selectedShirtNumber = player.shirtNumber == null
        ? null
        : player.shirtNumber == 0
        ? '00'
        : '${player.shirtNumber}';
    idConsoleController.text = player.idConsole ?? '';
    selectedPrimaryRole = player.primaryRole;
    selectedSecondaryRoles = [...player.secondaryRoles];
    selectedTeamRole = player.teamRole;
  }

  @override
  void dispose() {
    nomeController.dispose();
    cognomeController.dispose();
    accountEmailController.dispose();
    idConsoleController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if ((widget.selfRegistration || widget.draftOnly) &&
        !hasSeededRegistrationEmail) {
      final session = AppSessionScope.read(context);
      accountEmailController.text = session.currentUserEmail ?? '';
      hasSeededRegistrationEmail = true;
    }

    if (widget.selfRegistration && !hasSeededBootstrapRole) {
      final session = AppSessionScope.read(context);
      if (session.canBootstrapCaptain) {
        selectedTeamRole = 'captain';
      }
      hasSeededBootstrapRole = true;
    }

    if (widget.selfRegistration && !hasSeededRegistrationProfile) {
      final session = AppSessionScope.read(context);
      final currentUser = session.currentUser;
      if (currentUser != null) {
        if (nomeController.text.trim().isEmpty) {
          nomeController.text = currentUser.nome;
        }
        if (cognomeController.text.trim().isEmpty) {
          cognomeController.text = currentUser.cognome;
        }
        if (idConsoleController.text.trim().isEmpty) {
          idConsoleController.text = currentUser.idConsole ?? '';
        }
        hasSeededRegistrationProfile = true;
      }
    }

    if ((isProfileCompletionFlow || widget.draftOnly) &&
        !hasRequestedProfileDraftSeed) {
      hasRequestedProfileDraftSeed = true;
      unawaited(_seedPendingProfileDraft());
    }
  }

  Future<void> _seedPendingProfileDraft() async {
    final session = AppSessionScope.read(context);
    final draft = await ProfileSetupDraftStore.instance.loadForAccount(
      session.currentUserEmail,
    );
    if (!mounted || draft == null) {
      return;
    }

    if (nomeController.text.trim().isEmpty) {
      nomeController.text = draft.nome;
    }
    if (cognomeController.text.trim().isEmpty) {
      cognomeController.text = draft.cognome;
    }
    if (idConsoleController.text.trim().isEmpty) {
      idConsoleController.text = draft.idConsole;
    }
    if (selectedShirtNumber == null && draft.shirtNumber != null) {
      selectedShirtNumber = draft.shirtNumber == 0
          ? '00'
          : '${draft.shirtNumber}';
    }
    if (selectedPrimaryRole == null &&
        (draft.primaryRole?.trim().isNotEmpty == true)) {
      selectedPrimaryRole = draft.primaryRole;
    }
    if (selectedSecondaryRoles.isEmpty && draft.secondaryRoles.isNotEmpty) {
      selectedSecondaryRoles = normalizeRoleCodes(
        draft.secondaryRoles.where((role) => role != draft.primaryRole),
      );
    }
  }

  Future<void> _syncProfileDraftForCurrentUser(
    PlayerProfile player,
    PlayerProfile? currentUser,
  ) async {
    final isCurrentUserProfile =
        widget.selfRegistration ||
        widget.draftOnly ||
        currentUser?.id == player.id ||
        widget.player?.id == player.id;
    if (!isCurrentUserProfile || !player.isProfileSetupComplete) {
      return;
    }

    await ProfileSetupDraftStore.instance.save(
      ProfileSetupDraft(
        nome: player.nome,
        cognome: player.cognome,
        idConsole: player.idConsole!,
        shirtNumber: player.shirtNumber,
        primaryRole: player.primaryRole,
        secondaryRoles: player.secondaryRoles,
        accountEmail: accountEmailController.text.trim(),
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    Navigator.pop(context, hasCreatedPlayers);
  }

  void _resetFormAfterCreate() {
    nomeController.clear();
    cognomeController.clear();
    accountEmailController.clear();
    idConsoleController.clear();

    setState(() {
      selectedShirtNumber = null;
      selectedPrimaryRole = null;
      selectedSecondaryRoles = [];
      selectedTeamRole = 'player';
      isSaving = false;
      errorMessage = null;
      accountEmailError = null;
      idConsoleError = null;
      hasCreatedPlayers = true;
    });
  }

  Future<void> _savePlayer() async {
    final session = AppSessionScope.read(context);
    final currentUser = session.currentUser;
    final canManagePlayers = currentUser?.canManagePlayers ?? false;
    final canEditTeamRole =
        currentUser?.canEditTeamRoles == true && !widget.selfRegistration;
    final canEditTarget =
        widget.selfRegistration ||
        (widget.player == null
            ? canManagePlayers
            : currentUser?.canEditPlayer(widget.player!.id) == true);
    final currentAuthUser = session.authUser;

    final nome = normalizePlayerName(nomeController.text);
    final cognome = normalizePlayerName(cognomeController.text);
    final idConsole = idConsoleController.text.trim();

    if (widget.draftOnly) {
      if (currentAuthUser == null) {
        setState(() {
          errorMessage = 'Devi prima accedere con email e password';
        });
        return;
      }

      if (nome.isEmpty || cognome.isEmpty) {
        setState(() {
          errorMessage = 'Nome e cognome sono obbligatori';
          idConsoleError = null;
        });
        return;
      }

      if (idConsole.isEmpty) {
        setState(() {
          errorMessage = null;
          idConsoleError = 'ID console obbligatorio';
        });
        return;
      }

      if (selectedShirtNumber == null) {
        setState(() {
          errorMessage = 'Seleziona il numero maglia del tuo giocatore';
          idConsoleError = null;
        });
        return;
      }

      if (selectedPrimaryRole == null || selectedPrimaryRole!.trim().isEmpty) {
        setState(() {
          errorMessage = 'Seleziona il ruolo principale del tuo giocatore';
          idConsoleError = null;
        });
        return;
      }

      setState(() {
        isSaving = true;
        errorMessage = null;
        accountEmailError = null;
        idConsoleError = null;
      });

      try {
        await ProfileSetupDraftStore.instance.save(
          ProfileSetupDraft(
            nome: nome,
            cognome: cognome,
            idConsole: idConsole,
            shirtNumber: int.tryParse(selectedShirtNumber!),
            primaryRole: selectedPrimaryRole,
            secondaryRoles: normalizeRoleCodes(selectedSecondaryRoles),
            accountEmail: session.currentUserEmail,
          ),
        );
        if (!mounted) {
          return;
        }

        Navigator.pop(context, true);
      } catch (error) {
        setState(() {
          errorMessage = error.toString();
          isSaving = false;
        });
      } finally {
        if (mounted) {
          setState(() {
            isSaving = false;
          });
        }
      }
      return;
    }

    if (!canEditTarget) {
      setState(() {
        errorMessage = 'Non hai i permessi per modificare questo profilo';
      });
      return;
    }

    if (widget.selfRegistration && currentAuthUser == null) {
      setState(() {
        errorMessage = 'Devi prima accedere con email e password';
      });
      return;
    }

    final accountEmail = widget.selfRegistration
        ? normalizePlayerAccountEmail(session.currentUserEmail)
        : isEditing
        ? widget.player?.accountEmail
        : normalizePlayerAccountEmail(accountEmailController.text);

    if (nome.isEmpty || cognome.isEmpty) {
      setState(() {
        errorMessage = 'Nome e cognome sono obbligatori';
        idConsoleError = null;
      });
      return;
    }

    if (idConsole.isEmpty) {
      setState(() {
        errorMessage = null;
        accountEmailError = null;
        idConsoleError = 'ID console obbligatorio';
      });
      return;
    }

    if (!widget.selfRegistration &&
        !isEditing &&
        accountEmailController.text.trim().isNotEmpty &&
        accountEmail == null) {
      setState(() {
        errorMessage = null;
        accountEmailError = 'Inserisci una mail valida';
        idConsoleError = null;
      });
      return;
    }

    try {
      final existingPlayerWithConsoleId = await repository
          .findPlayerByConsoleId(idConsole);
      final isSamePlayer = existingPlayerWithConsoleId?.id == widget.player?.id;
      final hasAnotherPlayerWithSameConsoleId =
          existingPlayerWithConsoleId != null && !isSamePlayer;

      if (hasAnotherPlayerWithSameConsoleId) {
        if (widget.selfRegistration &&
            !isEditing &&
            existingPlayerWithConsoleId.canBeClaimedByAuthenticatedUser) {
          final claimedPlayer = existingPlayerWithConsoleId;
          final playerToClaim = PlayerProfile(
            id: claimedPlayer.id,
            nome: nome,
            cognome: cognome,
            authUserId: currentAuthUser?.id,
            accountEmail: accountEmail,
            shirtNumber: selectedShirtNumber == null
                ? null
                : int.tryParse(selectedShirtNumber!),
            primaryRole: selectedPrimaryRole,
            secondaryRoles: selectedSecondaryRoles,
            idConsole: idConsole,
            teamRole: session.canBootstrapCaptain
                ? 'captain'
                : claimedPlayer.teamRole,
          );

          setState(() {
            isSaving = true;
            errorMessage = null;
            accountEmailError = null;
            idConsoleError = null;
          });

          try {
            await repository.claimPlayer(playerToClaim);
            await _syncProfileDraftForCurrentUser(playerToClaim, currentUser);
            unawaited(session.refresh(showLoadingState: false));
            if (!mounted) return;
            AppDataSync.instance.notifyDataChanged({
              AppDataScope.players,
              AppDataScope.attendance,
            }, reason: 'player_claimed');
            Navigator.pop(context, true);
            return;
          } catch (e) {
            setState(() {
              errorMessage = e.toString();
              accountEmailError = null;
              idConsoleError = null;
              isSaving = false;
            });
            return;
          }
        }

        setState(() {
          errorMessage = null;
          accountEmailError = null;
          idConsoleError = widget.selfRegistration
              ? 'Esiste gia un profilo con questo ID console ed e gia collegato a un account.'
              : 'Player gia esistente';
        });
        return;
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        accountEmailError = null;
        idConsoleError = null;
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
      accountEmailError = null;
      idConsoleError = null;
    });

    final player = PlayerProfile(
      id: widget.player?.id,
      nome: nome,
      cognome: cognome,
      authUserId: widget.selfRegistration
          ? currentAuthUser?.id
          : widget.player?.authUserId,
      accountEmail: accountEmail ?? widget.player?.accountEmail,
      shirtNumber: selectedShirtNumber == null
          ? null
          : int.tryParse(selectedShirtNumber!),
      primaryRole: selectedPrimaryRole,
      secondaryRoles: selectedSecondaryRoles,
      idConsole: idConsole.isEmpty ? null : idConsole,
      teamRole: widget.selfRegistration
          ? (session.canBootstrapCaptain ? 'captain' : 'player')
          : canEditTeamRole
          ? selectedTeamRole
          : widget.player?.teamRole ?? 'player',
    );

    try {
      if (isEditing) {
        await repository.updatePlayer(player);
        await _syncProfileDraftForCurrentUser(player, currentUser);
        unawaited(session.refresh(showLoadingState: false));
        if (!mounted) return;
        AppDataSync.instance.notifyDataChanged({
          AppDataScope.players,
          AppDataScope.attendance,
        }, reason: 'player_updated');
        Navigator.pop(context, true);
        return;
      }

      await repository.createPlayer(player);
      await _syncProfileDraftForCurrentUser(player, currentUser);
      unawaited(session.refresh(showLoadingState: false));

      if (!mounted) return;
      AppDataSync.instance.notifyDataChanged({
        AppDataScope.players,
        AppDataScope.attendance,
      }, reason: 'player_created');

      if (widget.selfRegistration) {
        Navigator.pop(context, true);
        return;
      }
      _resetFormAfterCreate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giocatore salvato. Puoi inserirne un altro.'),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        accountEmailError = null;
        idConsoleError = null;
        isSaving = false;
      });
    }
  }

  InputDecoration _inputDecoration(String label, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      errorText: errorText,
    );
  }

  List<DropdownMenuItem<String>> _roleItems() {
    return kPlayerRoles
        .map(
          (role) => DropdownMenuItem<String>(
            value: role,
            child: Text('$role - ${kRoleCategories[role]}'),
          ),
        )
        .toList();
  }

  List<DropdownMenuItem<String>> _teamRoleItems() {
    return kTeamRoles
        .map(
          (teamRole) => DropdownMenuItem<String>(
            value: teamRole,
            child: Text(teamRoleLabel(teamRole)),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final currentUser = session.currentUser;
    final canManagePlayers = currentUser?.canManagePlayers ?? false;
    final canEditTarget =
        widget.draftOnly ||
        widget.selfRegistration ||
        (widget.player == null
            ? canManagePlayers
            : currentUser?.canEditPlayer(widget.player!.id) == true);
    final canEditTeamRole =
        currentUser?.canEditTeamRoles == true && !widget.selfRegistration;
    final canEditAccountEmail =
        !widget.draftOnly &&
        !widget.selfRegistration &&
        !isEditing &&
        canManagePlayers;
    final roleItems = _roleItems();
    final teamRoleItems = _teamRoleItems();
    final secondaryRoleCount = selectedSecondaryRoles.length;
    final bootstrapAsCaptain =
        widget.selfRegistration && session.canBootstrapCaptain;
    final showCompletionNotice = isProfileCompletionFlow || widget.draftOnly;
    final pageTitle = widget.draftOnly
        ? 'Crea il tuo giocatore'
        : isProfileCompletionFlow
        ? 'Completa il tuo profilo'
        : isEditing
        ? 'Modifica giocatore'
        : 'Aggiungi giocatore';
    final pageSubtitle = widget.draftOnly
        ? 'Compila una volta sola i dati del giocatore. Il ruolo club verra assegnato quando creerai o entrerai in una squadra.'
        : isProfileCompletionFlow
        ? 'Ti manca solo il profilo giocatore per sbloccare tutte le funzioni del club.'
        : isEditing
        ? 'Aggiorna i dati del giocatore e salva le modifiche.'
        : 'Inserisci i dati del nuovo giocatore della rosa.';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(pageTitle)),
        body: Stack(
          children: [
            const AppPageBackground(child: SizedBox.expand()),
            if (!canEditTarget)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Non puoi modificare questo profilo con l utente attualmente autenticato.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            else
              SafeArea(
                child: SingleChildScrollView(
                  padding: AppResponsive.pagePadding(
                    context,
                    top: 16,
                    bottom: 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pageTitle,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pageSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(
                            AppResponsive.cardPadding(context),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showCompletionNotice) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    widget.draftOnly
                                        ? 'Inserisci subito nome, cognome, ID console, maglia e ruolo principale. Quando sceglierai una squadra penseremo noi ad assegnare il ruolo club.'
                                        : bootstrapAsCaptain
                                        ? 'Questo account verra impostato come capitano quando completerai la creazione del club.'
                                        : widget.selfRegistration
                                        ? 'Il ruolo club verra impostato automaticamente come giocatore appena entrerai in una squadra.'
                                        : 'Completa i dati mancanti del giocatore per sbloccare tutta la navigazione del club.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              Text(
                                'Dati base',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: nomeController,
                                decoration: _inputDecoration('Nome'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: cognomeController,
                                decoration: _inputDecoration('Cognome'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: accountEmailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                enableSuggestions: false,
                                readOnly:
                                    widget.draftOnly ||
                                    widget.selfRegistration ||
                                    !canEditAccountEmail,
                                decoration:
                                    _inputDecoration(
                                      'Email accesso',
                                      errorText: accountEmailError,
                                    ).copyWith(
                                      helperText: widget.draftOnly
                                          ? 'Email collegata all account con cui stai entrando.'
                                          : widget.selfRegistration
                                          ? 'Questa mail viene presa dall account con cui hai effettuato l accesso.'
                                          : isEditing
                                          ? 'La mail di accesso non e modificabile da questa schermata.'
                                          : canEditAccountEmail
                                          ? 'Campo opzionale. Se impostato, il login reale del giocatore verra collegato a questa mail.'
                                          : 'La mail di accesso puo essere gestita solo da capitano o vice autorizzato.',
                                    ),
                                onChanged: (_) {
                                  if (accountEmailError == null) return;
                                  setState(() {
                                    accountEmailError = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: idConsoleController,
                                decoration:
                                    _inputDecoration(
                                      'ID console',
                                      errorText: idConsoleError,
                                    ).copyWith(
                                      helperText: widget.draftOnly
                                          ? 'Lo useremo per riconoscerti quando entrerai in una squadra.'
                                          : widget.selfRegistration
                                          ? 'Se questo ID console e gia presente in rosa ma non ha ancora una mail associata, il profilo verra collegato a questo account.'
                                          : null,
                                    ),
                                onChanged: (_) {
                                  if (idConsoleError == null) return;
                                  setState(() {
                                    idConsoleError = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Dettagli sportivi',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'shirt-number-$selectedShirtNumber',
                                ),
                                initialValue: selectedShirtNumber,
                                hint: const Text('Seleziona un numero'),
                                decoration: _inputDecoration('Numero maglia'),
                                items: kShirtNumberOptions
                                    .map(
                                      (number) => DropdownMenuItem<String>(
                                        value: number,
                                        child: Text(number),
                                      ),
                                    )
                                    .toList(),
                                onChanged: isSaving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedShirtNumber = value;
                                        });
                                      },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'primary-role-$selectedPrimaryRole',
                                ),
                                initialValue: selectedPrimaryRole,
                                hint: const Text('Seleziona un ruolo'),
                                decoration: _inputDecoration(
                                  'Ruolo principale',
                                ),
                                items: roleItems,
                                onChanged: isSaving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedPrimaryRole = value;
                                          if (value != null) {
                                            selectedSecondaryRoles =
                                                selectedSecondaryRoles
                                                    .where(
                                                      (role) => role != value,
                                                    )
                                                    .toList();
                                          }
                                        });
                                      },
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Ruoli secondari',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            secondaryRoleCount == 0
                                                ? 'Nessuno'
                                                : '$secondaryRoleCount selezionati',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Facoltativi. Il ruolo principale viene escluso automaticamente.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: kPlayerRoles.map((role) {
                                        final isPrimaryRole =
                                            role == selectedPrimaryRole;
                                        final isSelected =
                                            selectedSecondaryRoles.contains(
                                              role,
                                            );
                                        final category = kRoleCategories[role];

                                        return FilterChip(
                                          label: Text(
                                            category == null
                                                ? role
                                                : '$role - $category',
                                          ),
                                          selected: isSelected,
                                          onSelected:
                                              (isSaving || isPrimaryRole)
                                              ? null
                                              : (selected) {
                                                  setState(() {
                                                    if (selected) {
                                                      selectedSecondaryRoles = [
                                                        ...selectedSecondaryRoles,
                                                        role,
                                                      ];
                                                    } else {
                                                      selectedSecondaryRoles =
                                                          selectedSecondaryRoles
                                                              .where(
                                                                (item) =>
                                                                    item !=
                                                                    role,
                                                              )
                                                              .toList();
                                                    }
                                                    selectedSecondaryRoles =
                                                        normalizeRoleCodes(
                                                          selectedSecondaryRoles,
                                                        );
                                                  });
                                                },
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      secondaryRoleCount == 0
                                          ? 'Nessun ruolo secondario selezionato.'
                                          : 'Selezionati: ${selectedSecondaryRoles.join(', ')}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (!widget.draftOnly && canEditTeamRole) ...[
                                DropdownButtonFormField<String>(
                                  key: ValueKey('team-role-$selectedTeamRole'),
                                  initialValue: selectedTeamRole,
                                  decoration: _inputDecoration('Ruolo club'),
                                  items: teamRoleItems,
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() {
                                            selectedTeamRole = value;
                                          });
                                        },
                                ),
                                const SizedBox(height: 12),
                              ] else if (!widget.draftOnly &&
                                  currentUser?.isViceCaptain == true &&
                                  !widget.selfRegistration) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface
                                        .withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    'Il ruolo club resta modificabile solo dal capitano.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isSaving ? null : _savePlayer,
                                  child: Text(
                                    isSaving
                                        ? 'Salvataggio...'
                                        : widget.draftOnly
                                        ? 'Salva e continua'
                                        : widget.selfRegistration
                                        ? 'Crea profilo'
                                        : isEditing
                                        ? 'Salva modifiche'
                                        : 'Salva giocatore',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
