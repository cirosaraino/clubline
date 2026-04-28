import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/club_logo_picker/club_logo_picker_bridge.dart';
import '../../core/club_logo_picker/club_logo_picker_types.dart';
import '../../core/club_logo_resolver.dart';
import '../../core/club_info_formatters.dart';
import '../../core/club_theme_palette_extractor.dart';
import '../../data/club_info_repository.dart';
import '../../models/club_info.dart';
import 'app_chrome.dart';
import 'club_logo_avatar.dart';

class ClubInfoSheet extends StatefulWidget {
  const ClubInfoSheet({super.key});

  @override
  State<ClubInfoSheet> createState() => _ClubInfoSheetState();
}

class _ClubInfoSheetState extends State<ClubInfoSheet> {
  late final ClubInfoRepository repository;
  final clubNameController = TextEditingController();
  final crestUrlController = TextEditingController();
  final websiteUrlController = TextEditingController();
  final youtubeUrlController = TextEditingController();
  final discordUrlController = TextEditingController();
  final facebookUrlController = TextEditingController();
  final instagramUrlController = TextEditingController();
  final twitchUrlController = TextEditingController();
  final tiktokUrlController = TextEditingController();
  final customLinks = <_EditableCustomLink>[];

  ClubInfo? initialClubInfo;
  PickedClubLogo? pickedLogo;
  ClubThemePaletteResult? extractedPalette;
  bool hasInitialized = false;
  bool isSaving = false;
  bool isPickingLogo = false;
  bool isUsingFallbackPalette = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    repository = ClubInfoRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (hasInitialized) {
      return;
    }

    _populate(AppSessionScope.read(context).clubInfo);
    hasInitialized = true;
  }

  @override
  void dispose() {
    clubNameController.dispose();
    crestUrlController.dispose();
    websiteUrlController.dispose();
    youtubeUrlController.dispose();
    discordUrlController.dispose();
    facebookUrlController.dispose();
    instagramUrlController.dispose();
    twitchUrlController.dispose();
    tiktokUrlController.dispose();
    for (final customLink in customLinks) {
      customLink.dispose();
    }
    super.dispose();
  }

  void _populate(ClubInfo clubInfo) {
    initialClubInfo = clubInfo;
    clubNameController.text = clubInfo.displayClubName;
    crestUrlController.text = clubInfo.hasStoredCrestAsset
        ? ''
        : clubInfo.crestUrl ?? '';
    websiteUrlController.text = clubInfo.websiteUrl ?? '';
    youtubeUrlController.text = clubInfo.youtubeUrl ?? '';
    discordUrlController.text = clubInfo.discordUrl ?? '';
    facebookUrlController.text = clubInfo.facebookUrl ?? '';
    instagramUrlController.text = clubInfo.instagramUrl ?? '';
    twitchUrlController.text = clubInfo.twitchUrl ?? '';
    tiktokUrlController.text = clubInfo.tiktokUrl ?? '';

    for (final customLink in customLinks) {
      customLink.dispose();
    }
    customLinks
      ..clear()
      ..addAll(
        clubInfo.customLinks.map(
          (link) => _EditableCustomLink(label: link.label, url: link.url),
        ),
      );
    pickedLogo = null;
    extractedPalette = null;
    isUsingFallbackPalette = false;
  }

  InputDecoration _inputDecoration(
    String label, {
    String? helperText,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  void _addCustomLink() {
    setState(() {
      customLinks.add(_EditableCustomLink());
    });
  }

  void _removeCustomLink(_EditableCustomLink customLink) {
    setState(() {
      customLinks.remove(customLink);
      customLink.dispose();
    });
  }

  String? _normalizeFieldUrl(TextEditingController controller) {
    return normalizeOptionalClubUrl(controller.text);
  }

  ClubInfo get _currentClubInfo => initialClubInfo ?? ClubInfo.defaults;

  bool get _hasPendingLogoUpload => pickedLogo != null;

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
        crestUrlController.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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

  ClubThemePaletteResult? _paletteForDraft({
    ClubThemePaletteResult? paletteOverride,
  }) {
    return paletteOverride ?? extractedPalette;
  }

  bool _isUsingCustomCrestUrl(String? crestUrl) {
    return crestUrl != null && crestUrl.isNotEmpty;
  }

  bool _isChangingCrestSource(String? crestUrl) {
    final currentClubInfo = _currentClubInfo;
    if (_hasPendingLogoUpload) {
      return true;
    }

    if (!_isUsingCustomCrestUrl(crestUrl)) {
      return false;
    }

    return currentClubInfo.hasStoredCrestAsset ||
        crestUrl != currentClubInfo.crestUrl;
  }

  String? _previewCrestUrl() {
    if (_hasPendingLogoUpload) {
      return null;
    }

    final customCrestUrl = _normalizeFieldUrl(crestUrlController);
    if (customCrestUrl != null) {
      return customCrestUrl;
    }

    return _currentClubInfo.crestUrl;
  }

  String? _previewCrestStoragePath() {
    if (_hasPendingLogoUpload ||
        _normalizeFieldUrl(crestUrlController) != null) {
      return null;
    }

    return _currentClubInfo.crestStoragePath;
  }

  void _restoreCurrentLogoReference() {
    setState(() {
      pickedLogo = null;
      extractedPalette = null;
      isUsingFallbackPalette = false;
      errorMessage = null;
      crestUrlController.clear();
    });
  }

  Future<_PreparedClubInfoSave> _prepareClubInfoSave(ClubInfo draft) async {
    if (_hasPendingLogoUpload) {
      final palette = _paletteForDraft() ?? fallbackClubThemePalette();
      return _PreparedClubInfoSave(
        clubInfo: draft.copyWith(
          primaryColor: palette.primaryHex,
          accentColor: palette.accentHex,
          surfaceColor: palette.surfaceHex,
        ),
        logoDataUrl: pickedLogo?.dataUrl,
        palette: palette,
        usedFallbackPalette: isUsingFallbackPalette || extractedPalette == null,
        changedLogo: true,
      );
    }

    final crestUrl = draft.crestUrl;
    if (!_isChangingCrestSource(crestUrl) ||
        !_isUsingCustomCrestUrl(crestUrl)) {
      return _PreparedClubInfoSave(
        clubInfo: draft,
        logoDataUrl: null,
        palette: null,
        usedFallbackPalette: false,
        changedLogo: false,
      );
    }

    late final ClubThemePaletteResult palette;
    var usedFallbackPalette = false;
    try {
      palette = await extractClubThemePaletteFromUrl(crestUrl!);
      usedFallbackPalette = isFallbackClubThemePalette(palette);
    } catch (_) {
      palette = fallbackClubThemePalette();
      usedFallbackPalette = true;
    }

    return _PreparedClubInfoSave(
      clubInfo: draft.copyWith(
        primaryColor: palette.primaryHex,
        accentColor: palette.accentHex,
        surfaceColor: palette.surfaceHex,
      ),
      logoDataUrl: null,
      palette: palette,
      usedFallbackPalette: usedFallbackPalette,
      changedLogo: true,
    );
  }

  List<String> _collectInvalidFields() {
    final invalidFields = <String>[];
    final urlFields = <MapEntry<String, TextEditingController>>[
      MapEntry('stemma', crestUrlController),
      MapEntry('sito', websiteUrlController),
      MapEntry('YouTube', youtubeUrlController),
      MapEntry('Discord', discordUrlController),
      MapEntry('Facebook', facebookUrlController),
      MapEntry('Instagram', instagramUrlController),
      MapEntry('Twitch', twitchUrlController),
      MapEntry('TikTok', tiktokUrlController),
    ];

    for (final field in urlFields) {
      final hasText = field.value.text.trim().isNotEmpty;
      if (hasText && _normalizeFieldUrl(field.value) == null) {
        invalidFields.add(field.key);
      }
    }

    for (var index = 0; index < customLinks.length; index += 1) {
      final entry = customLinks[index];
      final label = normalizeClubLinkLabel(entry.labelController.text);
      final url = normalizeOptionalClubUrl(entry.urlController.text);
      final hasAnyValue =
          label.isNotEmpty || entry.urlController.text.trim().isNotEmpty;

      if (hasAnyValue && (label.isEmpty || url == null)) {
        invalidFields.add('link extra ${index + 1}');
      }
    }

    return invalidFields;
  }

  ClubInfo _buildDraft() {
    return ClubInfo(
      clubName: normalizeClubName(clubNameController.text),
      crestUrl: _normalizeFieldUrl(crestUrlController),
      websiteUrl: _normalizeFieldUrl(websiteUrlController),
      youtubeUrl: _normalizeFieldUrl(youtubeUrlController),
      discordUrl: _normalizeFieldUrl(discordUrlController),
      facebookUrl: _normalizeFieldUrl(facebookUrlController),
      instagramUrl: _normalizeFieldUrl(instagramUrlController),
      twitchUrl: _normalizeFieldUrl(twitchUrlController),
      tiktokUrl: _normalizeFieldUrl(tiktokUrlController),
      customLinks: customLinks
          .map(
            (entry) => ClubCustomLink(
              label: normalizeClubLinkLabel(entry.labelController.text),
              url: normalizeOptionalClubUrl(entry.urlController.text) ?? '',
            ),
          )
          .where((link) => link.isValid)
          .toList(),
    );
  }

  Future<void> _save() async {
    final session = AppSessionScope.read(context);
    final currentUser = session.currentUser;

    if (currentUser?.canManageClubInfo != true) {
      setState(() {
        errorMessage =
            'Solo il capitano o un vice autorizzato possono modificare le info club.';
      });
      return;
    }

    final invalidFields = _collectInvalidFields();
    if (invalidFields.isNotEmpty) {
      setState(() {
        errorMessage =
            'Controlla questi campi prima di salvare: ${invalidFields.join(', ')}.';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final draft = _buildDraft();
      final preparedSave = await _prepareClubInfoSave(draft);
      if (mounted && preparedSave.palette != null) {
        setState(() {
          extractedPalette = preparedSave.palette;
          isUsingFallbackPalette = preparedSave.usedFallbackPalette;
        });
      }

      await repository.saveClubInfo(
        preparedSave.clubInfo,
        logoDataUrl: preparedSave.logoDataUrl,
      );
      if (preparedSave.changedLogo) {
        ClubLogoResolver.instance.clearCache();
      }
      unawaited(session.refresh(showLoadingState: false));
      AppDataSync.instance.notifyDataChanged({
        AppDataScope.clubInfo,
      }, reason: 'club_info_updated');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preparedSave.changedLogo
                ? preparedSave.usedFallbackPalette
                      ? 'Info club aggiornate. Logo salvato con palette Stemma di fallback.'
                      : 'Info club aggiornate. Logo e palette Stemma salvati.'
                : 'Info club aggiornate',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        isSaving = false;
        errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final currentUser = session.currentUser;
    final canManage = currentUser?.canManageClubInfo == true;
    final clubNamePreview = normalizeClubName(clubNameController.text);
    final crestUrlPreview = _previewCrestUrl();
    final crestStoragePathPreview = _previewCrestStoragePath();
    final compact = AppResponsive.isCompact(context);
    final horizontalPadding = AppResponsive.horizontalPadding(context) + 4;
    final hasCustomCrestUrlDraft =
        !_hasPendingLogoUpload &&
        _isUsingCustomCrestUrl(_normalizeFieldUrl(crestUrlController));
    final willUpdateThemeFromExternalUrl =
        hasCustomCrestUrlDraft && _isChangingCrestSource(crestUrlPreview);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Info club',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  tooltip: 'Chiudi',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ClubPreviewCard(
              clubName: clubNamePreview,
              crestUrl: crestUrlPreview,
              crestStoragePath: crestStoragePathPreview,
              pendingLogo: pickedLogo,
            ),
            const SizedBox(height: 18),
            _ClubSectionCard(
              title: 'Identità club',
              child: Column(
                children: [
                  TextField(
                    controller: clubNameController,
                    enabled: canManage && !isSaving,
                    decoration: _inputDecoration(
                      'Nome club',
                      helperText: 'Questo nome verra mostrato nella Home.',
                      icon: Icons.groups_2_outlined,
                    ),
                    onChanged: (_) {
                      setState(() {
                        errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: crestUrlController,
                    enabled: canManage && !isSaving,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      'URL logo esterno',
                      helperText:
                          'Lascia vuoto per mantenere il logo attuale. Seleziona un file per caricarlo nello storage del club.',
                      icon: Icons.shield_outlined,
                    ),
                    onChanged: (_) {
                      setState(() {
                        if (pickedLogo != null) {
                          pickedLogo = null;
                        }
                        extractedPalette = null;
                        isUsingFallbackPalette = false;
                        errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: canManage && !isSaving && !isPickingLogo
                            ? _pickLogo
                            : null,
                        icon: Icon(
                          isPickingLogo
                              ? Icons.hourglass_top_outlined
                              : Icons.upload_file_outlined,
                        ),
                        label: Text(
                          isPickingLogo
                              ? 'Selezione logo...'
                              : pickedLogo == null
                              ? 'Carica logo'
                              : 'Sostituisci file',
                        ),
                      ),
                      if ((pickedLogo != null ||
                              crestUrlController.text.trim().isNotEmpty) &&
                          canManage)
                        TextButton.icon(
                          onPressed: isSaving
                              ? null
                              : _restoreCurrentLogoReference,
                          icon: const Icon(Icons.restore_outlined),
                          label: const Text('Ripristina logo attuale'),
                        ),
                    ],
                  ),
                  if (_currentClubInfo.hasStoredCrestAsset &&
                      pickedLogo == null &&
                      crestUrlController.text.trim().isEmpty) ...[
                    const SizedBox(height: 12),
                    const AppStatusBadge(
                      label: 'Logo gestito da storage',
                      tone: AppStatusTone.info,
                    ),
                  ],
                  if (pickedLogo != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        const AppStatusBadge(
                          label: 'Logo selezionato',
                          tone: AppStatusTone.success,
                        ),
                        if (extractedPalette != null)
                          AppStatusBadge(
                            label: isUsingFallbackPalette
                                ? 'Palette fallback'
                                : 'Palette pronta',
                            tone: isUsingFallbackPalette
                                ? AppStatusTone.warning
                                : AppStatusTone.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SelectedLogoCard(logo: pickedLogo!),
                  ] else if (willUpdateThemeFromExternalUrl) ...[
                    const SizedBox(height: 12),
                    const AppBanner(
                      message:
                          'Al salvataggio useremo questo URL esterno anche per ricalcolare la palette Stemma. Se l estrazione non riesce, useremo una palette sicura.',
                      tone: AppStatusTone.info,
                      icon: Icons.auto_awesome_outlined,
                    ),
                  ],
                  if (extractedPalette != null &&
                      (pickedLogo != null ||
                          willUpdateThemeFromExternalUrl)) ...[
                    const SizedBox(height: 12),
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
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ClubSectionCard(
              title: 'Link utili principali',
              child: Column(
                children: [
                  TextField(
                    controller: websiteUrlController,
                    enabled: canManage && !isSaving,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      'Sito o link principale',
                      icon: Icons.language_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: youtubeUrlController,
                    enabled: canManage && !isSaving,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      'YouTube',
                      icon: Icons.smart_display_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: twitchUrlController,
                    enabled: canManage && !isSaving,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      'Twitch',
                      icon: Icons.videocam_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: discordUrlController,
                    enabled: canManage && !isSaving,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      'Discord',
                      icon: Icons.forum_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instagramUrlController,
                    enabled: canManage && !isSaving,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      'Instagram',
                      icon: Icons.photo_camera_back_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: facebookUrlController,
                    enabled: canManage && !isSaving,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      'Facebook',
                      icon: Icons.facebook,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tiktokUrlController,
                    enabled: canManage && !isSaving,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      'TikTok',
                      icon: Icons.music_note_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ClubSectionCard(
              title: 'Link extra',
              trailing: canManage
                  ? OutlinedButton.icon(
                      onPressed: isSaving ? null : _addCustomLink,
                      icon: const Icon(Icons.add_link_outlined),
                      label: const Text('Aggiungi'),
                    )
                  : null,
              child: Column(
                children: [
                  if (customLinks.isEmpty)
                    Text(
                      'Nessun link extra configurato. Qui puoi aggiungere sponsor, canali secondari o riferimenti utili.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ClublineAppTheme.textMuted,
                        height: 1.35,
                      ),
                    ),
                  for (final customLink in customLinks) ...[
                    _CustomLinkRow(
                      customLink: customLink,
                      enabled: canManage && !isSaving,
                      onRemove: () => _removeCustomLink(customLink),
                    ),
                    if (customLink != customLinks.last)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: compact ? double.infinity : null,
                  child: ElevatedButton.icon(
                    onPressed: canManage && !isSaving ? _save : null,
                    icon: Icon(
                      isSaving
                          ? Icons.hourglass_top_outlined
                          : Icons.save_outlined,
                    ),
                    label: Text(
                      isSaving ? 'Salvataggio...' : 'Salva info club',
                    ),
                  ),
                ),
                SizedBox(
                  width: compact ? double.infinity : null,
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_outlined),
                    label: const Text('Chiudi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubPreviewCard extends StatelessWidget {
  const _ClubPreviewCard({
    required this.clubName,
    required this.crestUrl,
    required this.crestStoragePath,
    this.pendingLogo,
  });

  final String clubName;
  final String? crestUrl;
  final String? crestStoragePath;
  final PickedClubLogo? pendingLogo;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: ClublineAppTheme.heroGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ClublineAppTheme.outlineStrong),
      ),
      child: Column(
        children: [
          _ClubCrestPreview(
            crestUrl: crestUrl,
            crestStoragePath: crestStoragePath,
            pendingLogo: pendingLogo,
            size: compact ? 88 : 104,
          ),
          const SizedBox(height: 14),
          Text(
            clubName,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Anteprima Home del club',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: ClublineAppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ClubSectionCard extends StatelessWidget {
  const _ClubSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact && trailing != null) ...[
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: trailing!),
            ] else
              Row(
                children: trailing == null
                    ? [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ]
                    : [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        trailing!,
                      ],
              ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _CustomLinkRow extends StatelessWidget {
  const _CustomLinkRow({
    required this.customLink,
    required this.enabled,
    required this.onRemove,
  });

  final _EditableCustomLink customLink;
  final bool enabled;
  final VoidCallback onRemove;

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Column(
      children: [
        TextField(
          controller: customLink.labelController,
          enabled: enabled,
          decoration: _decoration('Etichetta link', Icons.label_outline),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: customLink.urlController,
          enabled: enabled,
          keyboardType: TextInputType.url,
          decoration: _decoration('URL link', Icons.link_outlined),
        ),
        const SizedBox(height: 12),
        compact
            ? SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: enabled ? onRemove : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ClublineAppTheme.dangerSoft,
                    side: BorderSide(
                      color: ClublineAppTheme.danger.withValues(alpha: 0.34),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Rimuovi link'),
                ),
              )
            : Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: enabled ? onRemove : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ClublineAppTheme.dangerSoft,
                    side: BorderSide(
                      color: ClublineAppTheme.danger.withValues(alpha: 0.34),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Rimuovi link'),
                ),
              ),
      ],
    );
  }
}

class _ClubCrestPreview extends StatelessWidget {
  const _ClubCrestPreview({
    required this.crestUrl,
    required this.crestStoragePath,
    required this.size,
    this.pendingLogo,
  });

  final String? crestUrl;
  final String? crestStoragePath;
  final double size;
  final PickedClubLogo? pendingLogo;

  @override
  Widget build(BuildContext context) {
    if (pendingLogo != null) {
      return _LocalClubLogoAvatar(logo: pendingLogo!, size: size);
    }

    return ClubLogoAvatar(
      logoUrl: crestUrl,
      logoStoragePath: crestStoragePath,
      size: size,
      fallbackIcon: Icons.shield_outlined,
    );
  }
}

class _SelectedLogoCard extends StatelessWidget {
  const _SelectedLogoCard({required this.logo});

  final PickedClubLogo logo;

  @override
  Widget build(BuildContext context) {
    final fileSizeKb = (logo.bytes.length / 1024).toStringAsFixed(1);
    final borderRadius = BorderRadius.circular(18);
    final previewBackground = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);
    final previewBorder = Theme.of(context).colorScheme.outlineVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${logo.mimeType} • $fileSizeKb KB',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ClublineAppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
            ),
            child: logo.isSvg
                ? SvgPicture.memory(logo.bytes, fit: BoxFit.contain)
                : Image.memory(
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
        ],
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

class _LocalClubLogoAvatar extends StatelessWidget {
  const _LocalClubLogoAvatar({required this.logo, required this.size});

  final PickedClubLogo logo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.82),
        border: Border.all(color: ClublineAppTheme.outlineStrong, width: 2),
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: logo.isSvg
                ? SvgPicture.memory(logo.bytes, fit: BoxFit.contain)
                : Image.memory(
                    logo.bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.shield_outlined,
                          color: ClublineAppTheme.goldSoft,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _EditableCustomLink {
  _EditableCustomLink({String label = '', String url = ''})
    : labelController = TextEditingController(text: label),
      urlController = TextEditingController(text: url);

  final TextEditingController labelController;
  final TextEditingController urlController;

  void dispose() {
    labelController.dispose();
    urlController.dispose();
  }
}

class _PreparedClubInfoSave {
  const _PreparedClubInfoSave({
    required this.clubInfo,
    required this.logoDataUrl,
    required this.palette,
    required this.usedFallbackPalette,
    required this.changedLogo,
  });

  final ClubInfo clubInfo;
  final String? logoDataUrl;
  final ClubThemePaletteResult? palette;
  final bool usedFallbackPalette;
  final bool changedLogo;
}

@Deprecated('Use ClubInfoSheet instead.')
class TeamInfoSheet extends ClubInfoSheet {
  const TeamInfoSheet({super.key});
}
