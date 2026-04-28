import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/club_logo_picker/club_logo_picker_bridge.dart';
import '../../core/club_logo_picker/club_logo_picker_types.dart';
import '../../core/club_theme_palette_extractor.dart';
import '../../data/club_repository.dart';
import '../widgets/app_chrome.dart';

class ClubCreatePage extends StatefulWidget {
  const ClubCreatePage({super.key});

  @override
  State<ClubCreatePage> createState() => _ClubCreatePageState();
}

class _ClubCreatePageState extends State<ClubCreatePage> {
  final clubNameController = TextEditingController();
  final ClubRepository repository = ClubRepository();

  PickedClubLogo? pickedLogo;
  ClubThemePaletteResult? extractedPalette;
  bool isUsingFallbackPalette = false;
  bool isSubmitting = false;
  bool isPickingLogo = false;
  String? errorMessage;

  @override
  void dispose() {
    clubNameController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    setState(() {
      isPickingLogo = true;
      errorMessage = null;
    });

    try {
      final result = await pickClubLogo();
      if (!mounted || result == null) {
        return;
      }

      final validationError = validatePickedClubLogo(result);
      if (validationError != null) {
        setState(() {
          errorMessage = validationError;
        });
        return;
      }

      late final ClubThemePaletteResult palette;
      var usedFallbackPalette = false;
      try {
        palette = await extractClubThemePalette(result.bytes);
        usedFallbackPalette = isFallbackClubThemePalette(palette);
      } catch (_) {
        palette = fallbackClubThemePalette();
        usedFallbackPalette = true;
      }

      setState(() {
        pickedLogo = result;
        extractedPalette = palette;
        isUsingFallbackPalette = usedFallbackPalette;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isPickingLogo = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final clubName = clubNameController.text.trim();
    final session = AppSessionScope.read(context);
    final playerIdentity = session.profileSetupDraft;

    if (clubName.isEmpty) {
      setState(() {
        errorMessage = 'Compila il nome del club.';
      });
      return;
    }

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

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.createClub(
        name: clubName,
        ownerNome: playerIdentity.nome,
        ownerCognome: playerIdentity.cognome,
        ownerConsoleId: playerIdentity.idConsole,
        ownerShirtNumber: playerIdentity.shirtNumber,
        ownerPrimaryRole: playerIdentity.primaryRole,
        logoDataUrl: pickedLogo?.dataUrl,
        primaryColor: pickedLogo == null ? null : extractedPalette?.primaryHex,
        accentColor: pickedLogo == null ? null : extractedPalette?.accentHex,
        surfaceColor: pickedLogo == null ? null : extractedPalette?.surfaceHex,
      );
      await session.refresh(showLoadingState: false);

      if (!mounted) {
        return;
      }

      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Club creato correttamente.')),
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
    final session = AppSessionScope.of(context);
    final playerIdentity = session.profileSetupDraft;

    return AppPageScaffold(
      title: 'Crea club',
      wide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeroPanel(
            eyebrow: 'Club Setup',
            title: 'Crea la tua squadra',
            subtitle:
                'Definisci nome e logo del club. Il tuo giocatore entrerà subito come capitano e il tema Stemma partirà automaticamente dal logo.',
            media: Icon(
              Icons.shield_outlined,
              size: AppResponsive.isCompact(context) ? 72 : 88,
              color: ClublineAppTheme.goldSoft,
            ),
            badges: [
              const AppStatusBadge(
                label: 'Capitano automatico',
                tone: AppStatusTone.success,
              ),
              if (pickedLogo != null)
                const AppStatusBadge(
                  label: 'Logo pronto',
                  tone: AppStatusTone.info,
                ),
              if (pickedLogo != null && extractedPalette != null)
                AppStatusBadge(
                  label: isUsingFallbackPalette
                      ? 'Palette fallback'
                      : 'Palette aggiornata',
                  tone: isUsingFallbackPalette
                      ? AppStatusTone.warning
                      : AppStatusTone.success,
                ),
            ],
            trailing: playerIdentity == null
                ? const AppSurfaceCard(
                    icon: Icons.person_off_outlined,
                    title: 'Giocatore mancante',
                    subtitle:
                        'Prima di creare un club devi completare il tuo giocatore.',
                    child: SizedBox.shrink(),
                  )
                : AppSurfaceCard(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Capitano iniziale',
                    subtitle:
                        'Questo profilo entrerà immediatamente nel club con il ruolo di capitano.',
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
            flex: const [3, 2],
            children: [
              AppSurfaceCard(
                icon: Icons.shield_outlined,
                title: 'Dettagli club',
                subtitle:
                    'Le informazioni essenziali per pubblicare subito la squadra.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: clubNameController,
                      enabled: !isSubmitting,
                      decoration: _inputDecoration(
                        'Nome club',
                        icon: Icons.shield_outlined,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppActionButton(
                      label: pickedLogo == null
                          ? 'Carica logo club'
                          : 'Sostituisci logo',
                      icon: isPickingLogo
                          ? Icons.hourglass_top_outlined
                          : Icons.upload_file_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: isSubmitting || isPickingLogo
                          ? null
                          : _pickLogo,
                    ),
                    if (pickedLogo != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _LogoPreviewCard(logo: pickedLogo!),
                    ],
                    if (extractedPalette != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ColorPreviewChip(
                            label: 'Primario',
                            color: extractedPalette!.primaryColor,
                          ),
                          _ColorPreviewChip(
                            label: 'Accento',
                            color: extractedPalette!.accentColor,
                          ),
                          _ColorPreviewChip(
                            label: 'Superficie',
                            color: extractedPalette!.surfaceColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        isUsingFallbackPalette
                            ? 'Il file e stato selezionato ma l estrazione automatica non e riuscita: useremo una palette sicura.'
                            : 'La palette Stemma usera questi colori appena il club viene creato.',
                        style: Theme.of(context).textTheme.bodySmall,
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
                    const SizedBox(height: AppSpacing.lg),
                    AppActionButton(
                      label: isSubmitting
                          ? 'Creazione in corso...'
                          : 'Crea club',
                      icon: Icons.arrow_forward_outlined,
                      expand: true,
                      onPressed: isSubmitting ? null : _submit,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSurfaceCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Tema automatico',
                    subtitle:
                        'Dopo il salvataggio useremo il logo per impostare subito la palette Stemma del club. Se l estrazione non riesce, partirà il tema Clubline.',
                    child: SizedBox.shrink(),
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

class _LogoPreviewCard extends StatelessWidget {
  const _LogoPreviewCard({required this.logo});

  final PickedClubLogo logo;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);
    final previewBackground = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);
    final previewBorder = Theme.of(context).colorScheme.outlineVariant;

    if (logo.isSvg) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: previewBackground,
          border: Border.all(color: previewBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    logo.fileName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SvgPicture.memory(logo.bytes, fit: BoxFit.contain),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: previewBackground,
        border: Border.all(color: previewBorder),
      ),
      child: Container(
        height: 180,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Image.memory(
          logo.bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                'Anteprima non disponibile per questo file.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ColorPreviewChip extends StatelessWidget {
  const _ColorPreviewChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = color.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: onColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
