import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/lineup_constants.dart';
import '../../core/lineup_formatters.dart';
import '../../data/lineup_repository.dart';
import '../../models/lineup.dart';
import '../../models/lineup_player_assignment.dart';
import '../widgets/app_chrome.dart';
import 'lineup_players_page.dart';

class AddLineupPage extends StatefulWidget {
  const AddLineupPage({
    super.key,
    this.lineup,
    this.duplicateMode = false,
    this.initialAssignments = const [],
  });

  final Lineup? lineup;
  final bool duplicateMode;
  final List<LineupPlayerAssignment> initialAssignments;

  @override
  State<AddLineupPage> createState() => _AddLineupPageState();
}

class _AddLineupPageState extends State<AddLineupPage> {
  late final LineupRepository repository;
  final competitionNameController = TextEditingController();
  final opponentNameController = TextEditingController();
  final notesController = TextEditingController();

  DateTime? selectedMatchDateTime;
  String? selectedFormationModule;
  bool isSaving = false;
  String? errorMessage;
  String? competitionNameError;
  String? matchDateTimeError;
  String? formationModuleError;

  bool get isEditing => widget.lineup?.id != null;
  bool get isDuplicating => widget.duplicateMode;

  @override
  void initState() {
    super.initState();
    repository = LineupRepository();
    _populateForm();
  }

  void _populateForm() {
    final lineup = widget.lineup;
    if (lineup == null) return;

    competitionNameController.text = normalizeCompetitionName(
      lineup.competitionName,
    );
    opponentNameController.text = lineup.opponentName ?? '';
    notesController.text = lineup.notes ?? '';
    selectedMatchDateTime = lineup.matchDateTime.toLocal();
    selectedFormationModule = lineup.formationModule;
  }

  @override
  void dispose() {
    competitionNameController.dispose();
    opponentNameController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _pickMatchDateTime() async {
    final now = DateTime.now();
    final initialDate = selectedMatchDateTime ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedMatchDateTime ?? now),
    );

    if (selectedTime == null) return;

    setState(() {
      selectedMatchDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      matchDateTimeError = null;
    });
  }

  Future<void> _saveLineup() async {
    if (AppSessionScope.read(context).currentUser?.canManageLineups != true) {
      setState(() {
        errorMessage = 'Solo il capitano o un vice autorizzato possono salvare le formazioni';
      });
      return;
    }

    final competitionName = normalizeCompetitionName(
      competitionNameController.text,
    );
    final opponentName = opponentNameController.text.trim();
    final notes = notesController.text.trim();

    var hasError = false;

    if (competitionName.isEmpty) {
      competitionNameError = 'Competizione obbligatoria';
      hasError = true;
    } else {
      competitionNameError = null;
    }

    if (selectedMatchDateTime == null) {
      matchDateTimeError = 'Data e ora obbligatorie';
      hasError = true;
    } else {
      matchDateTimeError = null;
    }

    if (selectedFormationModule == null || selectedFormationModule!.isEmpty) {
      formationModuleError = 'Modulo obbligatorio';
      hasError = true;
    } else {
      formationModuleError = null;
    }

    if (hasError) {
      setState(() {
        errorMessage = null;
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    final lineup = Lineup(
      id: widget.lineup?.id,
      competitionName: competitionName,
      matchDateTime: selectedMatchDateTime!,
      opponentName: opponentName.isEmpty ? null : opponentName,
      formationModule: selectedFormationModule!,
      notes: notes.isEmpty ? null : notes,
    );

    try {
      final savedLineup = isEditing
          ? await repository.updateLineup(lineup)
          : await repository.createLineup(lineup);

      if (!mounted) return;
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.lineups},
        reason: isEditing ? 'lineup_updated' : 'lineup_created',
      );

      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => LineupPlayersPage(
            lineup: savedLineup,
            initialAssignments: isEditing ? const [] : widget.initialAssignments,
          ),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
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

  @override
  Widget build(BuildContext context) {
    final canManageLineups = AppSessionScope.of(context).currentUser?.canManageLineups ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Modifica formazione'
              : isDuplicating
                  ? 'Copia formazione'
                  : 'Nuova formazione',
        ),
      ),
      body: !canManageLineups
          ? AppPageBackground(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(AppResponsive.cardPadding(context) + 8),
                  child: Text(
                    'Solo il capitano o un vice autorizzato possono creare o modificare le formazioni.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            )
          : AppPageBackground(
              child: SingleChildScrollView(
                padding: AppResponsive.pagePadding(context, bottom: 32),
                child: Column(
                  children: [
                    TextField(
                      controller: competitionNameController,
                      decoration: _inputDecoration(
                        'Competizione',
                        errorText: competitionNameError,
                      ),
                      onChanged: (value) {
                        final normalized = normalizeCompetitionName(value);
                        if (value != normalized) {
                          competitionNameController.value = TextEditingValue(
                            text: normalized,
                            selection: TextSelection.collapsed(
                              offset: normalized.length,
                            ),
                          );
                        }

                        if (competitionNameError == null) return;
                        setState(() {
                          competitionNameError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: isSaving ? null : _pickMatchDateTime,
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          'Data e ora partita',
                          errorText: matchDateTimeError,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                selectedMatchDateTime == null
                                    ? 'Seleziona data e ora'
                                    : formatMatchDateTime(selectedMatchDateTime!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.calendar_today_outlined),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: opponentNameController,
                      decoration: _inputDecoration('Avversario'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormationModule,
                      decoration: _inputDecoration(
                        'Modulo',
                        errorText: formationModuleError,
                      ),
                      items: kFormationModules
                          .map(
                            (module) => DropdownMenuItem<String>(
                              value: module,
                              child: Text(module),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setState(() {
                                selectedFormationModule = value;
                                formationModuleError = null;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _inputDecoration('Note'),
                    ),
                    const SizedBox(height: 16),
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
                        onPressed: isSaving ? null : _saveLineup,
                        child: Text(
                          isSaving
                              ? 'Salvataggio...'
                              : isEditing
                                  ? 'Salva e gestisci giocatori'
                                  : isDuplicating
                                      ? 'Crea copia e gestisci giocatori'
                                      : 'Crea e gestisci giocatori',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
