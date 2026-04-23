import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/attendance_formatters.dart';
import '../../../models/attendance_week_draft.dart';

class AttendanceWeekSetupSheet extends StatefulWidget {
  const AttendanceWeekSetupSheet({super.key});

  @override
  State<AttendanceWeekSetupSheet> createState() => _AttendanceWeekSetupSheetState();
}

class _AttendanceWeekSetupSheetState extends State<AttendanceWeekSetupSheet> {
  late DateTime referenceDate;
  final Set<int> selectedWeekdays = {1, 2, 3, 4};

  @override
  void initState() {
    super.initState();
    referenceDate = DateTime.now();
  }

  List<DateTime> get weekDates => attendanceCalendarWeekDates(referenceDate);

  List<DateTime> get selectedDates => weekDates
      .where((date) => selectedWeekdays.contains(date.weekday))
      .toList();

  Future<void> _pickWeekDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: referenceDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032, 12, 31),
      helpText: 'Scegli una data della settimana',
    );

    if (pickedDate == null) return;

    setState(() {
      referenceDate = pickedDate;
    });
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (selectedWeekdays.contains(weekday)) {
        selectedWeekdays.remove(weekday);
      } else {
        selectedWeekdays.add(weekday);
      }
    });
  }

  void _submit() {
    if (selectedDates.isEmpty) return;

    Navigator.pop(
      context,
      AttendanceWeekDraft(
        referenceDate: referenceDate,
        selectedDates: selectedDates,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarWeekStart = attendanceCalendarWeekStart(referenceDate);
    final calendarWeekEnd = weekDates.last;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nuovo sondaggio presenze',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scegli la settimana e poi seleziona solo i giorni che vuoi mettere a voto.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ClublineAppTheme.textMuted,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickWeekDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    'Settimana ${formatAttendanceDate(calendarWeekStart)} - ${formatAttendanceDate(calendarWeekEnd)}',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Giorni da mettere a voto',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final date in weekDates)
                      FilterChip(
                        selected: selectedWeekdays.contains(date.weekday),
                        label: Text(formatAttendanceDayWithDate(date)),
                        onSelected: (_) => _toggleWeekday(date.weekday),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ClublineAppTheme.outlineSoft),
                  ),
                  child: Text(
                    selectedDates.isEmpty
                        ? 'Seleziona almeno un giorno per poter creare il sondaggio.'
                        : 'Giorni selezionati: ${formatAttendanceSelectedDatesSummary(selectedDates)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ClublineAppTheme.textMuted,
                        ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: selectedDates.isEmpty ? null : _submit,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Crea'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
