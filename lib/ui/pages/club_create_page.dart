import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
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
  final ownerNomeController = TextEditingController();
  final ownerCognomeController = TextEditingController();
  final ownerConsoleIdController = TextEditingController();
  final ClubRepository repository = ClubRepository();

  PickedClubLogo? pickedLogo;
  ClubThemePaletteResult? extractedPalette;
  bool isSubmitting = false;
  bool isPickingLogo = false;
  String? errorMessage;

  @override
  void dispose() {
    clubNameController.dispose();
    ownerNomeController.dispose();
    ownerCognomeController.dispose();
    ownerConsoleIdController.dispose();
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

      if (!result.mimeType.startsWith('image/')) {
        setState(() {
          errorMessage = 'Seleziona un file immagine valido.';
        });
        return;
      }

      if (result.bytes.length > 5 * 1024 * 1024) {
        setState(() {
          errorMessage = 'Il logo deve essere inferiore a 5 MB.';
        });
        return;
      }

      ClubThemePaletteResult? palette;
      if (!result.isSvg) {
        try {
          palette = await extractClubThemePalette(result.bytes);
        } catch (_) {
          palette = null;
        }
      }

      setState(() {
        pickedLogo = result;
        extractedPalette = palette;
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
    final ownerNome = ownerNomeController.text.trim();
    final ownerCognome = ownerCognomeController.text.trim();
    final ownerConsoleId = ownerConsoleIdController.text.trim();

    if (clubName.isEmpty ||
        ownerNome.isEmpty ||
        ownerCognome.isEmpty ||
        ownerConsoleId.isEmpty) {
      setState(() {
        errorMessage = 'Compila nome club, nome, cognome e ID console.';
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    final session = AppSessionScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.createClub(
        name: clubName,
        ownerNome: ownerNome,
        ownerCognome: ownerCognome,
        ownerConsoleId: ownerConsoleId,
        logoDataUrl: pickedLogo?.dataUrl,
        primaryColor: extractedPalette?.primaryHex,
        accentColor: extractedPalette?.accentHex,
        surfaceColor: extractedPalette?.surfaceHex,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Crea club')),
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
                    'Avvia il tuo club su Clubline',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Il creatore diventa automaticamente capitano. Qui servono solo i dati essenziali: il resto del profilo lo completerai dopo.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(
                        AppResponsive.cardPadding(context),
                      ),
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
                          const SizedBox(height: 14),
                          TextField(
                            controller: ownerNomeController,
                            enabled: !isSubmitting,
                            decoration: _inputDecoration(
                              'Il tuo nome',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: ownerCognomeController,
                            enabled: !isSubmitting,
                            decoration: _inputDecoration(
                              'Il tuo cognome',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: ownerConsoleIdController,
                            enabled: !isSubmitting,
                            decoration: _inputDecoration(
                              'ID console',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: isSubmitting || isPickingLogo
                                ? null
                                : _pickLogo,
                            icon: Icon(
                              isPickingLogo
                                  ? Icons.hourglass_top_outlined
                                  : Icons.upload_file_outlined,
                            ),
                            label: Text(
                              pickedLogo == null
                                  ? 'Carica logo club'
                                  : 'Sostituisci logo',
                            ),
                          ),
                          if (pickedLogo != null) ...[
                            const SizedBox(height: 14),
                            _LogoPreviewCard(logo: pickedLogo!),
                          ],
                          if (extractedPalette != null) ...[
                            const SizedBox(height: 14),
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
                          ],
                          if (errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSubmitting ? null : _submit,
                              child: Text(
                                isSubmitting
                                    ? 'Creazione in corso...'
                                    : 'Crea club',
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
    );
  }
}

class _LogoPreviewCard extends StatelessWidget {
  const _LogoPreviewCard({required this.logo});

  final PickedClubLogo logo;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);

    if (logo.isSvg) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
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
            const SizedBox(height: 10),
            Text(
              'Logo SVG caricato correttamente. L anteprima completa sarà visibile dopo il salvataggio del club.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.memory(
        logo.bytes,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 180,
            width: double.infinity,
            alignment: Alignment.center,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
            child: Text(
              'Anteprima non disponibile per questo file.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          );
        },
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
