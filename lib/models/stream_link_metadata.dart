import '../core/stream_link_formatters.dart';

class StreamLinkMetadata {
  const StreamLinkMetadata({
    required this.title,
    required this.normalizedUrl,
    required this.status,
    required this.provider,
    required this.suggestedPlayedOn,
    this.endedAt,
  });

  final String title;
  final String normalizedUrl;
  final String status;
  final String provider;
  final DateTime suggestedPlayedOn;
  final DateTime? endedAt;

  factory StreamLinkMetadata.fromMap(Map<String, dynamic> map) {
    return StreamLinkMetadata(
      title: normalizeStreamTitle(map['title']?.toString() ?? ''),
      normalizedUrl: normalizeStreamUrl(map['normalizedUrl']?.toString() ?? ''),
      status: map['status']?.toString() ?? 'ended',
      provider: map['provider']?.toString() ?? 'generic',
      suggestedPlayedOn: DateTime.parse(map['suggestedPlayedOn'].toString()),
      endedAt: map['endedAt'] == null
          ? null
          : DateTime.parse(map['endedAt'].toString()),
    );
  }

  bool get isLive => status == 'live';

  String get statusLabel => streamStatusLabel(status);

  String get providerDisplay {
    if (provider.isEmpty) return 'WEB';
    return provider.toUpperCase();
  }
}
