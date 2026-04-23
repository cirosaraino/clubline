import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
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
  static const int _pageSize = 12;

  List<Club> clubs = const [];
  bool isLoading = true;
  bool isSubmitting = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  int currentPage = 1;
  String? activeQuery;
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

  Future<void> _loadClubs({
    String? query,
    int page = 1,
    bool append = false,
  }) async {
    setState(() {
      if (append) {
        isLoadingMore = true;
      } else {
        isLoading = true;
        errorMessage = null;
      }
    });

    try {
      final result = await repository.searchClubs(
        query: query,
        page: page,
        limit: _pageSize,
      );
      setState(() {
        clubs = append ? [...clubs, ...result.clubs] : result.clubs;
        currentPage = result.page;
        hasMore = result.hasMore;
        activeQuery = query?.trim().isEmpty == true ? null : query?.trim();
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          if (append) {
            isLoadingMore = false;
          } else {
            isLoading = false;
          }
        });
      }
    }
  }

  Future<void> _loadMoreClubs() {
    return _loadClubs(query: activeQuery, page: currentPage + 1, append: true);
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

    return AppPageScaffold(
      title: 'Unisciti a un club',
      wide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeroPanel(
            eyebrow: 'Join Flow',
            title: 'Scegli una squadra',
            subtitle:
                'Cerca il club, controlla lo stemma e invia una richiesta con il tuo profilo già pronto. La decisione verrà gestita dal capitano.',
            media: Icon(
              Icons.group_add_outlined,
              size: AppResponsive.isCompact(context) ? 72 : 88,
              color: ClublineAppTheme.goldSoft,
            ),
            badges: [
              const AppStatusBadge(
                label: 'Richiesta al capitano',
                tone: AppStatusTone.info,
              ),
              if (clubs.isNotEmpty)
                AppStatusBadge(
                  label: hasMore
                      ? '${clubs.length}+ risultati'
                      : '${clubs.length} risultati',
                  tone: AppStatusTone.success,
                ),
            ],
            trailing: playerIdentity == null
                ? const AppSurfaceCard(
                    icon: Icons.person_off_outlined,
                    title: 'Giocatore mancante',
                    subtitle:
                        'Prima di inviare una richiesta devi completare il tuo giocatore.',
                    child: SizedBox.shrink(),
                  )
                : AppSurfaceCard(
                    icon: Icons.badge_outlined,
                    title: 'Profilo inviato',
                    subtitle:
                        'Questo è il profilo che accompagnerà la tua richiesta di ingresso.',
                    child: AppDetailsList(
                      items: [
                        AppDetailItem(
                          label: 'Giocatore',
                          value:
                              '${playerIdentity.nome} ${playerIdentity.cognome}',
                          emphasized: true,
                        ),
                        AppDetailItem(
                          label: 'ID console',
                          value: playerIdentity.idConsole,
                          icon: Icons.sports_esports_outlined,
                        ),
                        AppDetailItem(
                          label: 'Maglia',
                          value:
                              '#${playerIdentity.shirtNumber?.toString().padLeft(2, '0') ?? '--'}',
                          icon: Icons.tag_outlined,
                        ),
                        AppDetailItem(
                          label: 'Ruolo',
                          value: playerIdentity.primaryRole ?? '-',
                          icon: Icons.sports_soccer_outlined,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppAdaptiveColumns(
            breakpoint: 980,
            gap: AppResponsive.sectionGap(context),
            flex: const [2, 3],
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSurfaceCard(
                    icon: Icons.search_outlined,
                    title: 'Ricerca club',
                    subtitle: 'Puoi cercare per nome o slug.',
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
                        const SizedBox(height: AppSpacing.md),
                        AppActionButton(
                          label: 'Aggiorna risultati',
                          icon: Icons.refresh_outlined,
                          variant: AppButtonVariant.secondary,
                          expand: true,
                          onPressed: isLoading || isSubmitting || isLoadingMore
                              ? null
                              : () => _loadClubs(query: searchController.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorMessage != null) ...[
                    AppBanner(
                      message: errorMessage!,
                      tone: AppStatusTone.error,
                      icon: Icons.error_outline,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (isLoading)
                    const AppLoadingState(label: 'Stiamo cercando i club...')
                  else if (clubs.isEmpty)
                    const AppEmptyState(
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
                            child: Padding(
                              padding: EdgeInsets.all(
                                AppResponsive.cardPadding(context),
                              ),
                              child: AppAdaptiveColumns(
                                breakpoint: 760,
                                gap: AppSpacing.md,
                                flex: const [3, 2],
                                children: [
                                  Row(
                                    children: [
                                      ClubLogoAvatar(
                                        logoUrl: club.logoUrl,
                                        size: 48,
                                        fallbackIcon: Icons.shield_outlined,
                                        borderWidth: 1.5,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              club.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            Text(
                                              '/${club.slug}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: AppActionButton(
                                      label: isSubmitting
                                          ? 'Invio...'
                                          : 'Invia richiesta',
                                      icon: Icons.arrow_forward_outlined,
                                      expand: AppResponsive.isCompact(context),
                                      onPressed:
                                          isSubmitting ||
                                              isLoadingMore ||
                                              playerIdentity == null
                                          ? null
                                          : () => _requestJoin(club),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (hasMore) ...[
                          const SizedBox(height: AppSpacing.sm),
                          AppActionButton(
                            label: isLoadingMore
                                ? 'Caricamento...'
                                : 'Mostra altri club',
                            icon: Icons.expand_more_outlined,
                            variant: AppButtonVariant.secondary,
                            expand: true,
                            onPressed: isLoadingMore || isSubmitting
                                ? null
                                : _loadMoreClubs,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
