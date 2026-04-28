import '../core/stream_link_formatters.dart';

class StreamLink {
  const StreamLink({
    this.id,
    required this.streamTitle,
    this.competitionName,
    required this.playedOn,
    required this.streamUrl,
    required this.streamStatus,
    this.streamEndedAt,
    this.provider,
    this.result,
    this.createdAt,
  });

  final dynamic id;
  final String streamTitle;
  final String? competitionName;
  final DateTime playedOn;
  final String streamUrl;
  final String streamStatus;
  final DateTime? streamEndedAt;
  final String? provider;
  final String? result;
  final DateTime? createdAt;

  factory StreamLink.fromMap(Map<String, dynamic> map) {
    return StreamLink(
      id: map['id'],
      streamTitle: normalizeStreamTitle(map['stream_title']?.toString() ?? ''),
      competitionName: normalizeOptionalCompetitionName(
        map['competition_name']?.toString(),
      ),
      playedOn: DateTime.parse(map['played_on'].toString()),
      streamUrl: normalizeStreamUrl(map['stream_url']?.toString() ?? ''),
      streamStatus: normalizeStreamStatus(map['stream_status']?.toString()),
      streamEndedAt: map['stream_ended_at'] == null
          ? null
          : DateTime.parse(map['stream_ended_at'].toString()),
      provider: map['provider']?.toString(),
      result: normalizeOptionalResult(map['result']?.toString()),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    final normalizedPlayedOn = normalizePlayedOnDate(playedOn);

    return {
      'stream_title': normalizeStreamTitle(streamTitle),
      'competition_name': normalizeOptionalCompetitionName(competitionName),
      'played_on': normalizedPlayedOn.toIso8601String().split('T').first,
      'stream_url': normalizeStreamUrl(streamUrl),
      'stream_status': normalizeStreamStatus(streamStatus),
      'stream_ended_at': isEnded
          ? streamEndedAt?.toUtc().toIso8601String()
          : null,
      'provider': provider,
      'result': normalizeOptionalResult(result),
    };
  }

  String get playedOnDisplay => formatPlayedOnDate(playedOn);

  bool get hasCompetitionName =>
      competitionName != null && competitionName!.trim().isNotEmpty;

  bool get hasResult => result != null && result!.trim().isNotEmpty;

  bool get hasEndedAt => streamEndedAt != null;

  bool get isLive => isLiveStreamStatus(streamStatus);

  bool get isScheduled => isScheduledStreamStatus(streamStatus);

  bool get isEnded => isEndedStreamStatus(streamStatus);

  bool get isUnknown => isUnknownStreamStatus(streamStatus);

  String get statusLabel => streamStatusLabel(streamStatus);

  String? get endedAtDisplay =>
      streamEndedAt == null ? null : formatStreamDateTime(streamEndedAt!);
}
