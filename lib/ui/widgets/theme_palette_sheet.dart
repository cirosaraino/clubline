import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/app_theme_controller.dart';

class ThemePaletteSheet extends StatefulWidget {
  const ThemePaletteSheet({super.key});

  @override
  State<ThemePaletteSheet> createState() => _ThemePaletteSheetState();
}

class _ThemePaletteSheetState extends State<ThemePaletteSheet> {
  static const _blackChoices = [
    Color(0xFF090603),
    Color(0xFF111214),
    Color(0xFF0B1116),
    Color(0xFF0A100C),
    Color(0xFF110909),
    Color(0xFF141414),
  ];

  static const _backgroundTopChoices = [
    Color(0xFF171107),
    Color(0xFF1A1C20),
    Color(0xFF13202B),
    Color(0xFF122016),
    Color(0xFF221010),
    Color(0xFF18130C),
  ];

  static const _backgroundBottomChoices = [
    Color(0xFF090603),
    Color(0xFF101114),
    Color(0xFF091017),
    Color(0xFF09120B),
    Color(0xFF100707),
    Color(0xFF0D0D0D),
  ];

  static const _surfaceChoices = [
    Color(0xFF151008),
    Color(0xFF181A1F),
    Color(0xFF16222D),
    Color(0xFF142118),
    Color(0xFF1D1111),
    Color(0xFF1B1B1B),
  ];

  static const _surfaceAltChoices = [
    Color(0xFF20180E),
    Color(0xFF23252B),
    Color(0xFF1C2E3C),
    Color(0xFF1C2D21),
    Color(0xFF291818),
    Color(0xFF242424),
  ];

  static const _accentChoices = [
    Color(0xFFF2D126),
    Color(0xFFFFC857),
    Color(0xFFFFB84C),
    Color(0xFFF08A7A),
    Color(0xFFE57373),
    Color(0xFF7CCB92),
    Color(0xFF4DB6AC),
    Color(0xFF5BC0EB),
    Color(0xFF64B5F6),
    Color(0xFFAED581),
  ];

  late UltrasThemePalette draftPalette;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    draftPalette = UltrasAppTheme.activePalette;
  }

  Future<void> _applyPalette() async {
    setState(() {
      isSaving = true;
    });

    final controller = AppThemeScope.read(context);
    final messenger = ScaffoldMessenger.of(context);

    await controller.updatePalette(draftPalette);

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Colori app aggiornati')),
    );
    Navigator.pop(context);
  }

  Future<void> _resetPalette() async {
    setState(() {
      isSaving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    await AppThemeScope.read(context).resetToDefault();

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Ripristinati i colori originali del logo club'),
      ),
    );
    Navigator.pop(context);
  }

  void _applyPreset(UltrasThemePreset preset) {
    setState(() {
      draftPalette = preset.palette;
    });
  }

  void _updatePalette(UltrasThemePalette palette) {
    setState(() {
      draftPalette = palette;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppThemeScope.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Colori app',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Di default restano i colori del logo club. Qui puoi scegliere una palette gia pronta oppure combinare i colori con una selezione visuale, senza usare codici.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: UltrasAppTheme.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            _PalettePreviewCard(palette: draftPalette),
            const SizedBox(height: 20),
            Text(
              'Palette suggerite',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: themeController.availablePresets
                  .map(
                    (preset) => _ThemePresetCard(
                      preset: preset,
                      isSelected: preset.palette.matches(draftPalette),
                      onTap: isSaving ? null : () => _applyPreset(preset),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Personalizzazione rapida',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Tocca un colore per aggiornare subito l anteprima qui sopra.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: UltrasAppTheme.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            _ColorChoiceSection(
              title: 'Accento principale',
              subtitle: 'Bottoni, badge, evidenze e dettagli.',
              selectedColor: draftPalette.accent,
              choices: _accentChoices,
              onSelected: (color) =>
                  _updatePalette(draftPalette.copyWith(accent: color)),
            ),
            const SizedBox(height: 12),
            _ColorChoiceSection(
              title: 'Base scura',
              subtitle: 'Il nero principale dell app.',
              selectedColor: draftPalette.black,
              choices: _blackChoices,
              onSelected: (color) =>
                  _updatePalette(draftPalette.copyWith(black: color)),
            ),
            const SizedBox(height: 16),
            _ColorChoiceSection(
              title: 'Sfondo alto',
              subtitle: 'La parte superiore dello sfondo pagina.',
              selectedColor: draftPalette.backgroundTop,
              choices: _backgroundTopChoices,
              onSelected: (color) =>
                  _updatePalette(draftPalette.copyWith(backgroundTop: color)),
            ),
            const SizedBox(height: 16),
            _ColorChoiceSection(
              title: 'Sfondo basso',
              subtitle: 'La chiusura dello sfondo pagina.',
              selectedColor: draftPalette.backgroundBottom,
              choices: _backgroundBottomChoices,
              onSelected: (color) => _updatePalette(
                draftPalette.copyWith(backgroundBottom: color),
              ),
            ),
            const SizedBox(height: 16),
            _ColorChoiceSection(
              title: 'Superficie',
              subtitle: 'Card e contenitori principali.',
              selectedColor: draftPalette.surface,
              choices: _surfaceChoices,
              onSelected: (color) =>
                  _updatePalette(draftPalette.copyWith(surface: color)),
            ),
            const SizedBox(height: 16),
            _ColorChoiceSection(
              title: 'Superficie secondaria',
              subtitle: 'Box secondari, pannelli e supporti.',
              selectedColor: draftPalette.surfaceAlt,
              choices: _surfaceAltChoices,
              onSelected: (color) =>
                  _updatePalette(draftPalette.copyWith(surfaceAlt: color)),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: isSaving || themeController.isLoading
                      ? null
                      : _applyPalette,
                  icon: Icon(
                    isSaving
                        ? Icons.hourglass_top_outlined
                        : Icons.palette_outlined,
                  ),
                  label: Text(isSaving ? 'Salvataggio...' : 'Applica colori'),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving || themeController.isLoading
                      ? null
                      : _resetPalette,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('Ripristina colori club'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PalettePreviewCard extends StatelessWidget {
  const _PalettePreviewCard({required this.palette});

  final UltrasThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: palette.pageGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.outlineStrong),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: palette.heroGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anteprima rapida',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vedi subito come appariranno card, sfondo e colore principale dell app.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PreviewPill(
                  label: 'Accento',
                  backgroundColor: palette.gold,
                  textColor: palette.onAccent,
                ),
                _PreviewPill(
                  label: 'Card',
                  backgroundColor: palette.surfaceRaised,
                  textColor: palette.textPrimary,
                  borderColor: palette.outline,
                ),
                _PreviewPill(
                  label: 'Dettagli',
                  backgroundColor: palette.surfaceSoft,
                  textColor: palette.goldSoft,
                  borderColor: palette.outlineSoft,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePresetCard extends StatelessWidget {
  const _ThemePresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final UltrasThemePreset preset;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = preset.palette;

    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? palette.gold : palette.outline,
                width: isSelected ? 1.8 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: palette.gold.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preset.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, size: 18, color: palette.gold),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  preset.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniSwatch(color: palette.black),
                    const SizedBox(width: 6),
                    _MiniSwatch(color: palette.backgroundTop),
                    const SizedBox(width: 6),
                    _MiniSwatch(color: palette.surfaceAlt),
                    const SizedBox(width: 6),
                    _MiniSwatch(color: palette.accent),
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

class _ColorChoiceSection extends StatelessWidget {
  const _ColorChoiceSection({
    required this.title,
    required this.subtitle,
    required this.selectedColor,
    required this.choices,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final Color selectedColor;
  final List<Color> choices;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: UltrasAppTheme.textMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: choices
              .map(
                (color) => _ColorSwatchButton(
                  color: color,
                  isSelected: color.toARGB32() == selectedColor.toARGB32(),
                  onTap: () => onSelected(color),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : color.withValues(alpha: 0.4),
              width: isSelected ? 3 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isSelected ? 0.4 : 0.2),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isSelected
              ? Icon(
                  Icons.check,
                  size: 18,
                  color: color.computeLuminance() > 0.55
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniSwatch extends StatelessWidget {
  const _MiniSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
    );
  }
}
