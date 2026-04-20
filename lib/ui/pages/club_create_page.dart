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
  final shirtNumberController = TextEditingController();
  final primaryRoleController = TextEditingController();
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
    shirtNumberController.dispose();
    primaryRoleController.dispose();
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
      try {
        palette = await extractClubThemePalette(result.bytes);
      } catch (_) {
        palette = null;
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

    if (clubName.isEmpty || ownerNome.isEmpty || ownerCognome.isEmpty) {
      setState(() {
        errorMessage = 'Compila nome club, nome e cognome.';
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
        ownerShirtNumber: int.tryParse(shirtNumberController.text.trim()),
        ownerPrimaryRole: primaryRoleController.text.trim(),
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
      appBar: AppBar(
        title: const Text('Crea club'),
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
                    'Avvia il tuo club su Clubline',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Il creatore diventa automaticamente capitano. Se carichi un logo, l app ricaverà i colori di base del club.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
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
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: shirtNumberController,
                                  enabled: !isSubmitting,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    'Numero maglia',
                                    icon: Icons.numbers_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: primaryRoleController,
                                  enabled: !isSubmitting,
                                  decoration: _inputDecoration(
                                    'Ruolo principale',
                                    icon: Icons.sports_soccer_outlined,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: isSubmitting || isPickingLogo ? null : _pickLogo,
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.memory(
                                pickedLogo!.bytes,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                                isSubmitting ? 'Creazione in corso...' : 'Crea club',
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

class _ColorPreviewChip extends StatelessWidget {
  const _ColorPreviewChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = color.computeLuminance() > 0.45 ? Colors.black : Colors.white;
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
