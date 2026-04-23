import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/stream_link_formatters.dart';
import '../../data/stream_link_repository.dart';
import '../../data/stream_metadata_service.dart';
import '../../models/stream_link.dart';
import '../../models/stream_link_metadata.dart';

class StreamFormPage extends StatefulWidget {
  const StreamFormPage({super.key, this.streamLink});

  final StreamLink? streamLink;

  @override
  State<StreamFormPage> createState() => _StreamFormPageState();
}

class _StreamFormPageState extends State<StreamFormPage> {
  late final StreamLinkRepository repository;
  late final StreamMetadataService metadataService;
  final streamTitleController = TextEditingController();
  final competitionNameController = TextEditingController();
  final streamUrlController = TextEditingController();
  final resultController = TextEditingController();

  DateTime? selectedPlayedOn;
  DateTime? selectedEndedAt;
  String? selectedStreamStatus;
  String? detectedProvider;
  bool isFetchingMetadata = false;
  bool isSaving = false;
  bool hasCreatedStreams = false;
  String? errorMessage;
  String? streamTitleError;
  String? playedOnError;
  String? streamUrlError;
  String? metadataError;
  String? lastFetchedUrl;
  String? lastFetchedTitle;

  bool get isEditing => widget.streamLink?.id != null;

  @override
  void initState() {
    super.initState();
    repository = StreamLinkRepository();
    metadataService = StreamMetadataService();
    _populateForm();
  }

  void _populateForm() {
    final streamLink = widget.streamLink;
    if (streamLink == null) return;

    streamTitleController.text = streamLink.streamTitle;
    competitionNameController.text = streamLink.competitionName ?? '';
    streamUrlController.text = streamLink.streamUrl;
    resultController.text = streamLink.result ?? '';
    selectedPlayedOn = normalizePlayedOnDate(streamLink.playedOn);
    selectedEndedAt = streamLink.streamEndedAt?.toLocal();
    selectedStreamStatus = streamLink.streamStatus;
    detectedProvider = streamLink.provider;
    lastFetchedUrl = streamLink.streamUrl;
    lastFetchedTitle = streamLink.streamTitle;
  }

  @override
  void dispose() {
    streamTitleController.dispose();
    competitionNameController.dispose();
    streamUrlController.dispose();
    resultController.dispose();
    super.dispose();
  }

  Future<void> _handleBackNavigation() async {
    Navigator.pop(context, hasCreatedStreams);
  }

  void _resetFormAfterCreate() {
    streamTitleController.clear();
    competitionNameController.clear();
    streamUrlController.clear();
    resultController.clear();

    setState(() {
      selectedPlayedOn = null;
      selectedEndedAt = null;
      selectedStreamStatus = null;
      detectedProvider = null;
      isFetchingMetadata = false;
      isSaving = false;
      errorMessage = null;
      streamTitleError = null;
      playedOnError = null;
      streamUrlError = null;
      metadataError = null;
      lastFetchedUrl = null;
      lastFetchedTitle = null;
      hasCreatedStreams = true;
    });
  }

  InputDecoration _inputDecoration(
    String label, {
    String? errorText,
    String? hintText,
    String? helperText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      border: const OutlineInputBorder(),
      errorText: errorText,
    );
  }

  Future<void> _pickPlayedOnDate() async {
    final now = DateTime.now();
    final initialDate = selectedPlayedOn ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (selectedDate == null) return;

    setState(() {
      selectedPlayedOn = normalizePlayedOnDate(selectedDate);
      playedOnError = null;
    });
  }

  Future<void> _fetchMetadata() async {
    final streamUrl = normalizeStreamUrl(streamUrlController.text);

    if (streamUrl.isEmpty) {
      setState(() {
        streamUrlError = 'Link obbligatorio';
      });
      return;
    }

    if (!isValidStreamUrl(streamUrl)) {
      setState(() {
        streamUrlError = 'Inserisci un link valido';
      });
      return;
    }

    setState(() {
      isFetchingMetadata = true;
      streamUrlError = null;
      metadataError = null;
      errorMessage = null;
    });

    try {
      final metadata = await metadataService.fetchMetadata(streamUrl);
      _applyMetadata(metadata);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dati live recuperati dal link')),
      );
    } catch (_) {
      final providerGuess = _guessProviderFromUrl(streamUrl);
      final fallbackStatus = _guessStatusFromUrl(streamUrl);

      setState(() {
        metadataError =
            'Recupero automatico non disponibile. Compila o verifica i campi prima di salvare.';
        isFetchingMetadata = false;
        detectedProvider ??= providerGuess;
        selectedStreamStatus ??= fallbackStatus;
        selectedPlayedOn ??= normalizePlayedOnDate(DateTime.now());
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dati automatici non disponibili: puoi completare manualmente.'),
        ),
      );
    }
  }

  String? _guessProviderFromUrl(String url) {
    final parsed = Uri.tryParse(url);
    final host = (parsed?.host ?? '').toLowerCase();

    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return 'YOUTUBE';
    }

    if (host.contains('twitch.tv')) {
      return 'TWITCH';
    }

    return null;
  }

  String _guessStatusFromUrl(String url) {
    final parsed = Uri.tryParse(url);
    final host = (parsed?.host ?? '').toLowerCase();
    final path = (parsed?.path ?? '').toLowerCase();

    if (host.contains('twitch.tv') && !path.contains('/videos/')) {
      return 'live';
    }

    return 'ended';
  }

  void _applyMetadata(StreamLinkMetadata metadata) {
    final normalizedPlayedOn = normalizePlayedOnDate(metadata.suggestedPlayedOn);

    setState(() {
      streamTitleController.text = metadata.title;
      streamUrlController.text = metadata.normalizedUrl;
      selectedStreamStatus = metadata.status;
      selectedEndedAt = metadata.endedAt?.toLocal();
      detectedProvider = metadata.providerDisplay;
      selectedPlayedOn = normalizedPlayedOn;
      lastFetchedUrl = metadata.normalizedUrl;
      lastFetchedTitle = metadata.title;
      isFetchingMetadata = false;
      streamTitleError = null;
      playedOnError = null;
    });
  }

  Future<void> _saveStreamLink() async {
    if (AppSessionScope.read(context).currentUser?.canManageStreams != true) {
      setState(() {
        errorMessage = 'Solo il capitano o un vice autorizzato possono salvare le live';
      });
      return;
    }

    final streamUrl = normalizeStreamUrl(streamUrlController.text);
    final streamTitle = normalizeStreamTitle(streamTitleController.text);
    final competitionName = normalizeOptionalCompetitionName(
      competitionNameController.text,
    );
    final result = normalizeOptionalResult(resultController.text);

    var hasError = false;

    if (streamUrl.isEmpty) {
      streamUrlError = 'Link obbligatorio';
      hasError = true;
    } else if (!isValidStreamUrl(streamUrl)) {
      streamUrlError = 'Inserisci un link valido';
      hasError = true;
    } else {
      streamUrlError = null;
    }

    if (streamTitle.isEmpty) {
      streamTitleError = 'Recupera o inserisci il nome della live';
      hasError = true;
    } else {
      streamTitleError = null;
    }

    if (selectedPlayedOn == null) {
      playedOnError = 'Giorno live obbligatorio';
      hasError = true;
    } else {
      playedOnError = null;
    }

    if (selectedStreamStatus == null) {
      metadataError = 'Recupera prima i dati dal link';
      hasError = true;
    } else {
      metadataError = null;
    }

    if (hasError) {
      setState(() {
        errorMessage = null;
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    final streamLink = StreamLink(
      id: widget.streamLink?.id,
      streamTitle: streamTitle,
      competitionName: competitionName,
      playedOn: selectedPlayedOn!,
      streamUrl: streamUrl,
      streamStatus: selectedStreamStatus!,
      streamEndedAt: selectedEndedAt,
      provider: detectedProvider,
      result: result,
    );

    try {
      if (isEditing) {
        await repository.updateStreamLink(streamLink);
        if (!mounted) return;
        AppDataSync.instance.notifyDataChanged(
          {AppDataScope.streams},
          reason: 'stream_updated',
        );
        Navigator.pop(context, true);
        return;
      }

      await repository.createStreamLink(streamLink);

      if (!mounted) return;
      AppDataSync.instance.notifyDataChanged(
        {AppDataScope.streams},
        reason: 'stream_created',
      );
      _resetFormAfterCreate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Live salvata. Puoi inserirne un'altra."),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isSaving = false;
      });
    }
  }

  Widget _buildIntroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: ClublineAppTheme.heroGradient,
        border: Border.all(color: ClublineAppTheme.outlineStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ClublineAppTheme.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isEditing ? 'MODIFICA LIVE' : 'NUOVA LIVE',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ClublineAppTheme.goldSoft,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isEditing ? 'Aggiorna i dettagli in modo ordinato' : 'Aggiungi una live in pochi passaggi',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkSection(BuildContext context) {
    final metadataLoaded = selectedStreamStatus != null;

    return _FormSectionCard(
      icon: Icons.link_outlined,
      title: 'Link e recupero dati',
      child: Column(
        children: [
          TextField(
            controller: streamUrlController,
            keyboardType: TextInputType.url,
            decoration: _inputDecoration(
              'Link streaming',
              errorText: streamUrlError,
              hintText: 'https://...',
              helperText: 'Incolla un link YouTube o Twitch della live da salvare.',
              prefixIcon: Icons.language_outlined,
            ),
            onChanged: (value) {
              final normalized = normalizeStreamUrl(value);
              if (streamUrlError != null || metadataError != null) {
                setState(() {
                  streamUrlError = null;
                  metadataError = null;
                });
              }

              if (lastFetchedUrl != null && normalized != lastFetchedUrl) {
                setState(() {
                  selectedStreamStatus = null;
                  selectedEndedAt = null;
                  detectedProvider = null;
                  if (streamTitleController.text == lastFetchedTitle) {
                    streamTitleController.clear();
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (isFetchingMetadata || isSaving) ? null : _fetchMetadata,
              icon: Icon(
                isFetchingMetadata
                    ? Icons.downloading_outlined
                    : Icons.auto_awesome_outlined,
              ),
              label: Text(
                isFetchingMetadata
                    ? 'Recupero dati live...'
                    : 'Recupera dati dal link',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetadataPreviewCard(
            metadataLoaded: metadataLoaded,
            metadataError: metadataError,
            provider: detectedProvider,
            streamStatus: selectedStreamStatus,
            playedOn: selectedPlayedOn,
            endedAt: selectedEndedAt,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    final metadataLoaded = selectedStreamStatus != null;

    return _FormSectionCard(
      icon: Icons.edit_note_outlined,
      title: 'Dettagli da salvare',
      child: Column(
        children: [
          if (!metadataLoaded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ClublineAppTheme.outlineSoft),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: ClublineAppTheme.goldSoft,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recupera prima i dati dal link: titolo, stato e giorno live verranno compilati in automatico da YouTube o Twitch.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ClublineAppTheme.textMuted,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          if (!metadataLoaded) const SizedBox(height: 12),
          TextField(
            controller: streamTitleController,
            decoration: _inputDecoration(
              'Nome live',
              errorText: streamTitleError,
              hintText: 'Titolo della live',
              helperText: 'Puoi correggerlo se vuoi un nome piu chiaro.',
              prefixIcon: Icons.title_outlined,
            ),
            onChanged: (_) {
              if (streamTitleError == null) return;
              setState(() {
                streamTitleError = null;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: competitionNameController,
            decoration: _inputDecoration(
              'Competizione',
              hintText: 'Es. LEGA / TORNEO',
              helperText: 'Campo opzionale, utile per ordinare meglio le live.',
              prefixIcon: Icons.emoji_events_outlined,
            ),
            onChanged: (value) {
              final normalized = value.trim().toUpperCase();
              if (value != normalized) {
                competitionNameController.value = TextEditingValue(
                  text: normalized,
                  selection: TextSelection.collapsed(
                    offset: normalized.length,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: isSaving ? null : _pickPlayedOnDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: _inputDecoration(
                'Giorno live',
                errorText: playedOnError,
                helperText: 'Controlla la data o cambiala manualmente.',
                prefixIcon: Icons.calendar_today_outlined,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedPlayedOn == null
                        ? 'Seleziona il giorno'
                        : formatPlayedOnDate(selectedPlayedOn!),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Icon(Icons.expand_more_outlined),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: resultController,
            decoration: _inputDecoration(
              'Risultato',
              hintText: 'Es. 2-1',
              helperText: 'Campo opzionale.',
              prefixIcon: Icons.scoreboard_outlined,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveSection(BuildContext context) {
    final title = isEditing ? 'Salva le modifiche' : 'Salva e continua';
    final description = isEditing
        ? 'Aggiorni subito questa live e torni alla lista.'
        : "Dopo il salvataggio resti qui e puoi inserire subito un'altra live.";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ClublineAppTheme.textMuted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isSaving || isFetchingMetadata) ? null : _saveStreamLink,
                icon: Icon(
                  isSaving ? Icons.hourglass_top_outlined : Icons.save_outlined,
                ),
                label: Text(
                  isSaving ? 'Salvataggio...' : 'Salva live',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManageStreams = AppSessionScope.of(context).currentUser?.canManageStreams ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Modifica live' : 'Aggiungi live'),
        ),
        body: !canManageStreams
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Solo il capitano o un vice autorizzato possono creare o modificare le live.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            : Container(
          decoration: BoxDecoration(
            gradient: ClublineAppTheme.pageGradient,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIntroCard(context),
                const SizedBox(height: 18),
                _buildLinkSection(context),
                const SizedBox(height: 16),
                _buildDetailsSection(context),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _InlineErrorCard(message: errorMessage!),
                ],
                const SizedBox(height: 16),
                _buildSaveSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: ClublineAppTheme.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: ClublineAppTheme.goldSoft),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
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

class _MetadataPreviewCard extends StatelessWidget {
  const _MetadataPreviewCard({
    required this.metadataLoaded,
    required this.metadataError,
    required this.provider,
    required this.streamStatus,
    required this.playedOn,
    required this.endedAt,
  });

  final bool metadataLoaded;
  final String? metadataError;
  final String? provider;
  final String? streamStatus;
  final DateTime? playedOn;
  final DateTime? endedAt;

  @override
  Widget build(BuildContext context) {
    if (metadataError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ClublineAppTheme.danger.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ClublineAppTheme.danger.withValues(alpha: 0.35)),
        ),
        child: Text(
          metadataError!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClublineAppTheme.dangerSoft,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    if (!metadataLoaded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ClublineAppTheme.outlineSoft),
        ),
        child: Text(
          'Quando recuperi i dati dal link, qui vedrai subito provider, stato e giorno live.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClublineAppTheme.textMuted,
                height: 1.35,
              ),
        ),
      );
    }

    final statusValue = streamStatus == 'live'
        ? 'LIVE'
        : endedAt == null
            ? 'CONCLUSA'
            : formatStreamDateTime(endedAt!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClublineAppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anteprima dati recuperati',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (provider != null && provider!.trim().isNotEmpty)
                _MetadataBadge(
                  icon: Icons.ondemand_video_outlined,
                  label: provider!,
                ),
              _MetadataBadge(
                icon: streamStatus == 'live'
                    ? Icons.radio_button_checked
                    : Icons.videocam_outlined,
                label: statusValue,
              ),
              if (playedOn != null)
                _MetadataBadge(
                  icon: Icons.calendar_today_outlined,
                  label: formatPlayedOnDate(playedOn!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetadataBadge extends StatelessWidget {
  const _MetadataBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ClublineAppTheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ClublineAppTheme.outlineSoft.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ClublineAppTheme.goldSoft),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ClublineAppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClublineAppTheme.danger.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClublineAppTheme.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: ClublineAppTheme.dangerSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ClublineAppTheme.dangerSoft,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
