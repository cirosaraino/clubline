import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/club_repository.dart';
import '../../models/club.dart';
import '../widgets/app_chrome.dart';

class ClubJoinPage extends StatefulWidget {
  const ClubJoinPage({super.key});

  @override
  State<ClubJoinPage> createState() => _ClubJoinPageState();
}

class _ClubJoinPageState extends State<ClubJoinPage> {
  final ClubRepository repository = ClubRepository();
  final searchController = TextEditingController();
  final nomeController = TextEditingController();
  final cognomeController = TextEditingController();
  final shirtNumberController = TextEditingController();
  final roleController = TextEditingController();

  List<Club> clubs = const [];
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadClubs());
  }

  @override
  void dispose() {
    searchController.dispose();
    nomeController.dispose();
    cognomeController.dispose();
    shirtNumberController.dispose();
    roleController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs({String? query}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await repository.searchClubs(query: query);
      setState(() {
        clubs = result;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _requestJoin(Club club) async {
    final nome = nomeController.text.trim();
    final cognome = cognomeController.text.trim();
    if (nome.isEmpty || cognome.isEmpty) {
      setState(() {
        errorMessage = 'Inserisci nome e cognome prima di inviare la richiesta.';
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      await repository.requestJoinClub(
        clubId: club.id,
        nome: nome,
        cognome: cognome,
        shirtNumber: int.tryParse(shirtNumberController.text.trim()),
        primaryRole: roleController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Richiesta inviata a ${club.name}.')),
      );
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unisciti a un club'),
      ),
      body: Stack(
        children: [
          const AppPageBackground(child: SizedBox.expand()),
          SafeArea(
            child: SingleChildScrollView(
              padding: AppResponsive.pagePadding(context, top: 16, bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cerca il club giusto',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'La tua richiesta verrà inviata al capitano del club selezionato.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
                      child: Column(
                        children: [
                          TextField(
                            controller: searchController,
                            enabled: !isSubmitting,
                            decoration: _inputDecoration(
                              'Cerca per nome o slug',
                              icon: Icons.search_outlined,
                            ),
                            onSubmitted: (value) => _loadClubs(query: value),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: nomeController,
                                  enabled: !isSubmitting,
                                  decoration: _inputDecoration(
                                    'Nome',
                                    icon: Icons.person_outline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: cognomeController,
                                  enabled: !isSubmitting,
                                  decoration: _inputDecoration(
                                    'Cognome',
                                    icon: Icons.badge_outlined,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: shirtNumberController,
                                  enabled: !isSubmitting,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    'Maglia',
                                    icon: Icons.numbers_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: roleController,
                                  enabled: !isSubmitting,
                                  decoration: _inputDecoration(
                                    'Ruolo',
                                    icon: Icons.sports_soccer_outlined,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: isLoading || isSubmitting
                                  ? null
                                  : () => _loadClubs(query: searchController.text),
                              icon: const Icon(Icons.refresh_outlined),
                              label: const Text('Aggiorna risultati'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (clubs.isEmpty)
                    const AppStatusCard(
                      icon: Icons.shield_outlined,
                      title: 'Nessun club trovato',
                      message: 'Prova con un altro nome oppure crea tu il primo club.',
                    )
                  else
                    Column(
                      children: [
                        for (final club in clubs) ...[
                          Card(
                            child: ListTile(
                              contentPadding: EdgeInsets.all(AppResponsive.cardPadding(context)),
                              leading: CircleAvatar(
                                backgroundImage: (club.logoUrl ?? '').isNotEmpty
                                    ? NetworkImage(club.logoUrl!)
                                    : null,
                                child: (club.logoUrl ?? '').isEmpty
                                    ? const Icon(Icons.shield_outlined)
                                    : null,
                              ),
                              title: Text(club.name),
                              subtitle: Text('/${club.slug}'),
                              trailing: ElevatedButton(
                                onPressed: isSubmitting ? null : () => _requestJoin(club),
                                child: Text(isSubmitting ? 'Invio...' : 'Richiedi'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
