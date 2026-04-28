import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
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
    this.repository,
  });

  final PlayerProfile? player;
  final bool selfRegistration;
  final bool draftOnly;
  final PlayerRepository? repository;

  @override
  State<PlayerFormPage> createState() => _PlayerFormPageState();
}

class _PlayerFormPageState extends State<PlayerFormPage> {
  late final PlayerRepository _repository;
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
  String? nomeError;
  String? cognomeError;
  String? accountEmailError;
  String? idConsoleError;
  String? shirtNumberError;
  String? primaryRoleError;
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
    _repository = widget.repository ?? PlayerRepository();
    _populateForm();
  }

  String? _shirtNumberSelection(int? shirtNumber) {
    if (shirtNumber == null) {
      return null;
    }

    return shirtNumber == 0 ? '00' : '$shirtNumber';
  }

  int? _parseSelectedShirtNumber(String? value) {
    if (value == null) {
      return null;
    }

    return int.tryParse(value);
  }

  String? _normalizePrimaryRole(String? role) {
    final normalizedRoles = normalizeRoleCodes([role]);
    if (normalizedRoles.isNotEmpty) {
      return normalizedRoles.first;
    }

    final trimmed = role?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  List<String> _normalizeSecondaryRoles(
    Iterable<String?> roles, {
    String? primaryRole,
  }) {
    return normalizeRoleCodes(
      roles,
    ).where((role) => role != primaryRole).toList(growable: false);
  }

  void _populateForm() {
    final player = widget.player;
    if (player == null) return;

    final normalizedPrimaryRole = _normalizePrimaryRole(player.primaryRole);

    nomeController.text = player.nome;
    cognomeController.text = player.cognome;
    accountEmailController.text = player.accountEmail ?? '';
    selectedShirtNumber = _shirtNumberSelection(player.shirtNumber);
    idConsoleController.text = player.idConsole ?? '';
    selectedPrimaryRole = normalizedPrimaryRole;
    selectedSecondaryRoles = _normalizeSecondaryRoles(
      player.secondaryRoles,
      primaryRole: normalizedPrimaryRole,
    );
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
      final currentUserEmail = session.currentUserEmail;
      if (currentUserEmail != null && currentUserEmail.isNotEmpty) {
        accountEmailController.text = currentUserEmail;
        hasSeededRegistrationEmail = true;
      }
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
      final session = AppSessionScope.read(context);
      final currentUserEmail = session.currentUserEmail;
      if (currentUserEmail != null && currentUserEmail.isNotEmpty) {
        hasRequestedProfileDraftSeed = true;
        unawaited(_seedPendingProfileDraft());
      }
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
    final normalizedPrimaryRole = _normalizePrimaryRole(draft.primaryRole);
    final draftShirtNumberSelection = _shirtNumberSelection(draft.shirtNumber);
    final draftSecondaryRoles = _normalizeSecondaryRoles(
      draft.secondaryRoles,
      primaryRole: normalizedPrimaryRole,
    );

    final nextSelectedShirtNumber =
        selectedShirtNumber ?? draftShirtNumberSelection;
    final nextSelectedPrimaryRole =
        selectedPrimaryRole ?? normalizedPrimaryRole;
    final nextSelectedSecondaryRoles = selectedSecondaryRoles.isEmpty
        ? draftSecondaryRoles
        : selectedSecondaryRoles;

    if (nextSelectedShirtNumber != selectedShirtNumber ||
        nextSelectedPrimaryRole != selectedPrimaryRole ||
        !listEquals(nextSelectedSecondaryRoles, selectedSecondaryRoles)) {
      setState(() {
        selectedShirtNumber = nextSelectedShirtNumber;
        selectedPrimaryRole = nextSelectedPrimaryRole;
        selectedSecondaryRoles = nextSelectedSecondaryRoles;
      });
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
      nomeError = null;
      cognomeError = null;
      accountEmailError = null;
      idConsoleError = null;
      shirtNumberError = null;
      primaryRoleError = null;
      hasCreatedPlayers = true;
    });
  }

  void _clearInlineErrors() {
    nomeError = null;
    cognomeError = null;
    accountEmailError = null;
    idConsoleError = null;
    shirtNumberError = null;
    primaryRoleError = null;
  }

  Future<void> _savePlayer() async {
    FocusScope.of(context).unfocus();
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
    final shirtNumber = _parseSelectedShirtNumber(selectedShirtNumber);
    final normalizedPrimaryRole = _normalizePrimaryRole(selectedPrimaryRole);
    final normalizedSecondaryRoles = _normalizeSecondaryRoles(
      selectedSecondaryRoles,
      primaryRole: normalizedPrimaryRole,
    );

    if (widget.draftOnly) {
      if (currentAuthUser == null) {
        setState(() {
          errorMessage = 'Devi prima accedere con email e password';
        });
        return;
      }

      if (nome.isEmpty || cognome.isEmpty) {
        setState(() {
          errorMessage = null;
          _clearInlineErrors();
          nomeError = nome.isEmpty ? 'Inserisci il nome' : null;
          cognomeError = cognome.isEmpty ? 'Inserisci il cognome' : null;
        });
        return;
      }

      if (idConsole.isEmpty) {
        setState(() {
          _clearInlineErrors();
          errorMessage = null;
          idConsoleError = 'ID console obbligatorio';
        });
        return;
      }

      if (selectedShirtNumber == null) {
        setState(() {
          _clearInlineErrors();
          errorMessage = null;
          shirtNumberError = 'Seleziona il numero';
        });
        return;
      }

      if (normalizedPrimaryRole == null) {
        setState(() {
          _clearInlineErrors();
          errorMessage = null;
          primaryRoleError = 'Seleziona il ruolo principale';
        });
        return;
      }

      setState(() {
        isSaving = true;
        errorMessage = null;
        _clearInlineErrors();
      });

      try {
        await ProfileSetupDraftStore.instance.save(
          ProfileSetupDraft(
            nome: nome,
            cognome: cognome,
            idConsole: idConsole,
            shirtNumber: shirtNumber,
            primaryRole: normalizedPrimaryRole,
            secondaryRoles: normalizedSecondaryRoles,
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
        errorMessage = null;
        _clearInlineErrors();
        nomeError = nome.isEmpty ? 'Inserisci il nome' : null;
        cognomeError = cognome.isEmpty ? 'Inserisci il cognome' : null;
      });
      return;
    }

    if (idConsole.isEmpty) {
      setState(() {
        _clearInlineErrors();
        errorMessage = null;
        idConsoleError = 'ID console obbligatorio';
      });
      return;
    }

    if (!widget.selfRegistration &&
        !isEditing &&
        accountEmailController.text.trim().isNotEmpty &&
        accountEmail == null) {
      setState(() {
        _clearInlineErrors();
        errorMessage = null;
        accountEmailError = 'Inserisci una mail valida';
      });
      return;
    }

    if (selectedShirtNumber == null) {
      setState(() {
        _clearInlineErrors();
        errorMessage = null;
        shirtNumberError = 'Seleziona il numero';
      });
      return;
    }

    if (normalizedPrimaryRole == null) {
      setState(() {
        _clearInlineErrors();
        errorMessage = null;
        primaryRoleError = 'Seleziona il ruolo principale';
      });
      return;
    }

    try {
      final existingPlayerWithConsoleId = await _repository
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
            shirtNumber: shirtNumber,
            primaryRole: normalizedPrimaryRole,
            secondaryRoles: normalizedSecondaryRoles,
            idConsole: idConsole,
            teamRole: session.canBootstrapCaptain
                ? 'captain'
                : claimedPlayer.teamRole,
          );

          setState(() {
            isSaving = true;
            errorMessage = null;
            _clearInlineErrors();
          });

          try {
            await _repository.claimPlayer(playerToClaim);
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
              _clearInlineErrors();
              isSaving = false;
            });
            return;
          }
        }

        setState(() {
          _clearInlineErrors();
          errorMessage = null;
          idConsoleError = widget.selfRegistration
              ? 'Esiste gia un profilo con questo ID console ed e gia collegato a un account.'
              : 'Player gia esistente';
        });
        return;
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        _clearInlineErrors();
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
      _clearInlineErrors();
    });

    final player = PlayerProfile(
      id: widget.player?.id,
      nome: nome,
      cognome: cognome,
      authUserId: widget.selfRegistration
          ? currentAuthUser?.id
          : widget.player?.authUserId,
      accountEmail: accountEmail ?? widget.player?.accountEmail,
      shirtNumber: shirtNumber,
      primaryRole: normalizedPrimaryRole,
      secondaryRoles: normalizedSecondaryRoles,
      idConsole: idConsole.isEmpty ? null : idConsole,
      teamRole: widget.selfRegistration
          ? (session.canBootstrapCaptain ? 'captain' : 'player')
          : canEditTeamRole
          ? selectedTeamRole
          : widget.player?.teamRole ?? 'player',
    );

    try {
      if (isEditing) {
        await _repository.updatePlayer(player);
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

      await _repository.createPlayer(player);
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
        _clearInlineErrors();
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
        ? 'Compila il profilo una volta sola.'
        : isProfileCompletionFlow
        ? 'Manca solo il profilo giocatore.'
        : isEditing
        ? 'Aggiorna i dati e salva.'
        : 'Inserisci i dati del nuovo giocatore.';
    final saveLabel = isSaving
        ? 'Salvataggio...'
        : widget.draftOnly
        ? 'Salva e continua'
        : widget.selfRegistration
        ? 'Crea profilo'
        : isEditing
        ? 'Salva modifiche'
        : 'Salva giocatore';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(pageTitle)),
        bottomNavigationBar: canEditTarget
            ? AppBottomSafeAreaBar(
                child: AppActionButton(
                  label: saveLabel,
                  icon: isEditing
                      ? Icons.save_outlined
                      : Icons.arrow_forward_outlined,
                  expand: true,
                  isLoading: isSaving,
                  onPressed: isSaving ? null : _savePlayer,
                ),
              )
            : null,
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
                bottom: false,
                child: AppContentFrame(
                  wide: true,
                  child: SingleChildScrollView(
                    padding: AppResponsive.pagePadding(
                      context,
                      top: AppSpacing.sm,
                      bottom: AppResponsive.bottomActionBarReservedSpace(
                        context,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppPageHeader(
                          eyebrow: widget.draftOnly
                              ? 'Onboarding'
                              : isEditing
                              ? 'Player Editor'
                              : 'Player Setup',
                          title: pageTitle,
                          subtitle: pageSubtitle,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (showCompletionNotice) ...[
                          AppBanner(
                            message: widget.draftOnly
                                ? 'Compila subito i dati del tuo giocatore. Il ruolo club verra assegnato quando sceglierai una squadra.'
                                : bootstrapAsCaptain
                                ? 'Quando completi il profilo entrerai come capitano del nuovo club.'
                                : widget.selfRegistration
                                ? 'Completa il profilo e poi entrerai nel club come giocatore.'
                                : 'Completa i dati mancanti per sbloccare tutto il club.',
                            tone: AppStatusTone.info,
                            icon: Icons.info_outline,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        AppSurfaceCard(
                          icon: Icons.badge_outlined,
                          title: 'Identita',
                          subtitle: 'Dati base e collegamento account',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppAdaptiveColumns(
                                breakpoint: 760,
                                gap: AppSpacing.sm,
                                children: [
                                  TextField(
                                    controller: nomeController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    keyboardType: TextInputType.name,
                                    textInputAction: TextInputAction.next,
                                    decoration: _inputDecoration(
                                      'Nome',
                                      errorText: nomeError,
                                    ),
                                    onChanged: (_) {
                                      if (nomeError == null) return;
                                      setState(() {
                                        nomeError = null;
                                      });
                                    },
                                  ),
                                  TextField(
                                    controller: cognomeController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    keyboardType: TextInputType.name,
                                    textInputAction: TextInputAction.next,
                                    decoration: _inputDecoration(
                                      'Cognome',
                                      errorText: cognomeError,
                                    ),
                                    onChanged: (_) {
                                      if (cognomeError == null) return;
                                      setState(() {
                                        cognomeError = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: accountEmailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
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
                                          ? 'Email dell account con cui stai entrando.'
                                          : widget.selfRegistration
                                          ? 'La mail arriva dall account attuale.'
                                          : isEditing
                                          ? 'Non modificabile da questa schermata.'
                                          : canEditAccountEmail
                                          ? 'Opzionale.'
                                          : 'Gestibile solo da capitano o vice autorizzato.',
                                    ),
                                onChanged: (_) {
                                  if (accountEmailError == null) return;
                                  setState(() {
                                    accountEmailError = null;
                                  });
                                },
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: idConsoleController,
                                textInputAction: TextInputAction.done,
                                decoration:
                                    _inputDecoration(
                                      'ID console',
                                      errorText: idConsoleError,
                                    ).copyWith(
                                      helperText: widget.draftOnly
                                          ? 'Ti riconosceremo quando entrerai in una squadra.'
                                          : widget.selfRegistration
                                          ? 'Se esiste gia un profilo senza account, verra collegato qui.'
                                          : null,
                                    ),
                                onChanged: (_) {
                                  if (idConsoleError == null) return;
                                  setState(() {
                                    idConsoleError = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppSurfaceCard(
                          icon: Icons.sports_soccer_outlined,
                          title: 'Campo',
                          subtitle:
                              'Maglia, ruolo principale e ruoli secondari',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppAdaptiveColumns(
                                breakpoint: 760,
                                gap: AppSpacing.sm,
                                children: [
                                  DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'shirt-number-$selectedShirtNumber',
                                    ),
                                    initialValue: selectedShirtNumber,
                                    hint: const Text('Seleziona un numero'),
                                    decoration: _inputDecoration(
                                      'Numero maglia',
                                      errorText: shirtNumberError,
                                    ),
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
                                              shirtNumberError = null;
                                            });
                                          },
                                  ),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'primary-role-$selectedPrimaryRole',
                                    ),
                                    initialValue: selectedPrimaryRole,
                                    hint: const Text('Seleziona un ruolo'),
                                    decoration: _inputDecoration(
                                      'Ruolo principale',
                                      errorText: primaryRoleError,
                                    ),
                                    items: roleItems,
                                    onChanged: isSaving
                                        ? null
                                        : (value) {
                                            setState(() {
                                              selectedPrimaryRole = value;
                                              primaryRoleError = null;
                                              if (value != null) {
                                                selectedSecondaryRoles =
                                                    _normalizeSecondaryRoles(
                                                      selectedSecondaryRoles,
                                                      primaryRole: value,
                                                    );
                                              }
                                            });
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
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
                                        AppCountPill(
                                          label: secondaryRoleCount == 0
                                              ? 'Nessuno'
                                              : '$secondaryRoleCount selezionati',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Facoltativi. Il ruolo principale viene escluso automaticamente.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
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
                                    const SizedBox(height: AppSpacing.xs),
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
                            ],
                          ),
                        ),
                        if (!widget.draftOnly) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppSurfaceCard(
                            icon: Icons.shield_outlined,
                            title: 'Ruolo club',
                            subtitle: 'Permessi nel club',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (canEditTeamRole)
                                  DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'team-role-$selectedTeamRole',
                                    ),
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
                                  )
                                else if (currentUser?.isViceCaptain == true &&
                                    !widget.selfRegistration)
                                  const AppBanner(
                                    message:
                                        'Il ruolo club puo essere cambiato solo dal capitano.',
                                    tone: AppStatusTone.info,
                                    icon: Icons.lock_outline,
                                  )
                                else
                                  Text(
                                    'Il ruolo club verra assegnato automaticamente nel flusso corrente.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: ClublineAppTheme.textMuted,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppBanner(
                            message: errorMessage!,
                            tone: AppStatusTone.error,
                            icon: Icons.error_outline,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
