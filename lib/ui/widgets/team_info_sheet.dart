import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/team_info_formatters.dart';
import '../../data/team_info_repository.dart';
import '../../models/team_info.dart';
import 'app_chrome.dart';
import 'club_logo_avatar.dart';

class TeamInfoSheet extends StatefulWidget {
  const TeamInfoSheet({super.key});

  @override
  State<TeamInfoSheet> createState() => _TeamInfoSheetState();
}

class _TeamInfoSheetState extends State<TeamInfoSheet> {
  late final TeamInfoRepository repository;
  final teamNameController = TextEditingController();
  final crestUrlController = TextEditingController();
  final websiteUrlController = TextEditingController();
  final youtubeUrlController = TextEditingController();
  final discordUrlController = TextEditingController();
  final facebookUrlController = TextEditingController();
  final instagramUrlController = TextEditingController();
  final twitchUrlController = TextEditingController();
  final tiktokUrlController = TextEditingController();
  final customLinks = <_EditableCustomLink>[];

  bool hasInitialized = false;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    repository = TeamInfoRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (hasInitialized) {
      return;
    }

    _populate(AppSessionScope.read(context).teamInfo);
    hasInitialized = true;
  }

  @override
  void dispose() {
    teamNameController.dispose();
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

  void _populate(TeamInfo teamInfo) {
    teamNameController.text = teamInfo.displayTeamName;
    crestUrlController.text = teamInfo.crestUrl ?? '';
    websiteUrlController.text = teamInfo.websiteUrl ?? '';
    youtubeUrlController.text = teamInfo.youtubeUrl ?? '';
    discordUrlController.text = teamInfo.discordUrl ?? '';
    facebookUrlController.text = teamInfo.facebookUrl ?? '';
    instagramUrlController.text = teamInfo.instagramUrl ?? '';
    twitchUrlController.text = teamInfo.twitchUrl ?? '';
    tiktokUrlController.text = teamInfo.tiktokUrl ?? '';

    for (final customLink in customLinks) {
      customLink.dispose();
    }
    customLinks
      ..clear()
      ..addAll(
        teamInfo.customLinks.map(
          (link) => _EditableCustomLink(label: link.label, url: link.url),
        ),
      );
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
    return normalizeOptionalTeamUrl(controller.text);
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
      final label = normalizeTeamLinkLabel(entry.labelController.text);
      final url = normalizeOptionalTeamUrl(entry.urlController.text);
      final hasAnyValue =
          label.isNotEmpty || entry.urlController.text.trim().isNotEmpty;

      if (hasAnyValue && (label.isEmpty || url == null)) {
        invalidFields.add('link extra ${index + 1}');
      }
    }

    return invalidFields;
  }

  TeamInfo _buildDraft() {
    return TeamInfo(
      teamName: normalizeTeamName(teamNameController.text),
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
            (entry) => TeamCustomLink(
              label: normalizeTeamLinkLabel(entry.labelController.text),
              url: normalizeOptionalTeamUrl(entry.urlController.text) ?? '',
            ),
          )
          .where((link) => link.isValid)
          .toList(),
    );
  }

  Future<void> _save() async {
    final session = AppSessionScope.read(context);
    final currentUser = session.currentUser;

    if (currentUser?.canManageTeamInfo != true) {
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
      await repository.saveTeamInfo(_buildDraft());
      unawaited(session.refresh(showLoadingState: false));
      AppDataSync.instance.notifyDataChanged({
        AppDataScope.teamInfo,
      }, reason: 'team_info_updated');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Info club aggiornate')));
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
    final canManage = currentUser?.canManageTeamInfo == true;
    final teamNamePreview = normalizeTeamName(teamNameController.text);
    final crestUrlPreview = normalizeOptionalTeamUrl(crestUrlController.text);
    final compact = AppResponsive.isCompact(context);
    final horizontalPadding = AppResponsive.horizontalPadding(context) + 4;

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
            _TeamPreviewCard(
              teamName: teamNamePreview,
              crestUrl: crestUrlPreview,
            ),
            const SizedBox(height: 18),
            _TeamSectionCard(
              title: 'Identità club',
              child: Column(
                children: [
                  TextField(
                    controller: teamNameController,
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
                      'URL logo personalizzato',
                      helperText:
                          'Lascia vuoto per usare il logo attuale del club o il fallback grafico dell app.',
                      icon: Icons.shield_outlined,
                    ),
                    onChanged: (_) {
                      setState(() {
                        errorMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _TeamSectionCard(
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
            _TeamSectionCard(
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

class _TeamPreviewCard extends StatelessWidget {
  const _TeamPreviewCard({required this.teamName, required this.crestUrl});

  final String teamName;
  final String? crestUrl;

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
          _TeamCrestPreview(crestUrl: crestUrl, size: compact ? 88 : 104),
          const SizedBox(height: 14),
          Text(
            teamName,
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

class _TeamSectionCard extends StatelessWidget {
  const _TeamSectionCard({
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

class _TeamCrestPreview extends StatelessWidget {
  const _TeamCrestPreview({required this.crestUrl, required this.size});

  final String? crestUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClubLogoAvatar(
      logoUrl: crestUrl,
      size: size,
      fallbackIcon: Icons.shield_outlined,
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
