import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../data/club_repository.dart';
import '../../models/club.dart';
import '../widgets/app_chrome.dart';
import '../widgets/club_logo_avatar.dart';

class ClubJoinPage extends StatefulWidget {
  const ClubJoinPage({super.key});

  @override
  State<ClubJoinPage> createState() => _ClubJoinPageState();
}

class _ClubJoinPageState extends State<ClubJoinPage> {
  final ClubRepository repository = ClubRepository();
  final searchController = TextEditingController();

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
    final session = AppSessionScope.read(context);
    final playerIdentity = session.profileSetupDraft;
    if (playerIdentity == null) {
      setState(() {
        errorMessage = 'Prima completa il tuo giocatore.';
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
        nome: playerIdentity.nome,
        cognome: playerIdentity.cognome,
        shirtNumber: playerIdentity.shirtNumber,
        primaryRole: playerIdentity.primaryRole,
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
    final playerIdentity = AppSessionScope.of(context).profileSetupDraft;

    return Scaffold(
      appBar: AppBar(title: const Text('Unisciti a un club')),
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
                    'Scegli una squadra',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Invieremo la tua richiesta al capitano del club selezionato con il profilo che hai già preparato.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  if (playerIdentity == null)
                    const AppStatusCard(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'Giocatore mancante',
                      message:
                          'Prima di inviare una richiesta devi completare il tuo giocatore.',
                    )
                  else
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(
                          AppResponsive.cardPadding(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profilo inviato',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${playerIdentity.nome} ${playerIdentity.cognome}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                AppCountPill(
                                  label: 'ID',
                                  value: playerIdentity.idConsole,
                                  icon: Icons.sports_esports_outlined,
                                ),
                                AppCountPill(
                                  label: 'Maglia',
                                  value:
                                      '#${playerIdentity.shirtNumber?.toString().padLeft(2, '0') ?? '--'}',
                                  icon: Icons.tag_outlined,
                                ),
                                AppCountPill(
                                  label: 'Ruolo',
                                  value: playerIdentity.primaryRole,
                                  icon: Icons.sports_soccer_outlined,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(
                        AppResponsive.cardPadding(context),
                      ),
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
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: isLoading || isSubmitting
                                  ? null
                                  : () => _loadClubs(
                                      query: searchController.text,
                                    ),
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
                      message:
                          'Prova con un altro nome oppure crea tu il primo club.',
                    )
                  else
                    Column(
                      children: [
                        for (final club in clubs) ...[
                          Card(
                            child: ListTile(
                              contentPadding: EdgeInsets.all(
                                AppResponsive.cardPadding(context),
                              ),
                              leading: ClubLogoAvatar(
                                logoUrl: club.logoUrl,
                                size: 40,
                                fallbackIcon: Icons.shield_outlined,
                                borderWidth: 1.5,
                              ),
                              title: Text(club.name),
                              subtitle: Text('/${club.slug}'),
                              trailing: ElevatedButton(
                                onPressed:
                                    isSubmitting || playerIdentity == null
                                    ? null
                                    : () => _requestJoin(club),
                                child: Text(
                                  isSubmitting ? 'Invio...' : 'Invia richiesta',
                                ),
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
