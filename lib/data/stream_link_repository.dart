import '../core/stream_link_formatters.dart';
import '../models/stream_link.dart';
import 'api_client.dart';

class StreamLinkRepository {
  StreamLinkRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<List<StreamLink>> fetchStreamLinks() async {
    final response = await _apiClient.get('/streams', authenticated: true);
    final rawStreams = switch (response) {
      {'streams': final List streams} => streams,
      List streams => streams,
      _ => const [],
    };

    final streamLinks = rawStreams
        .map<StreamLink>((row) => StreamLink.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    streamLinks.sort((a, b) {
      final aStatus = a.isLive ? 0 : 1;
      final bStatus = b.isLive ? 0 : 1;
      if (aStatus != bStatus) return aStatus.compareTo(bStatus);

      final aDate = a.streamEndedAt ?? a.playedOn;
      final bDate = b.streamEndedAt ?? b.playedOn;
      return bDate.compareTo(aDate);
    });

    return streamLinks;
  }

  Future<StreamLink> createStreamLink(StreamLink streamLink) async {
    final response = await _apiClient.post(
      '/streams',
      authenticated: true,
      body: streamLink.toDatabaseMap(),
    );

    return _extractStream(response);
  }

  Future<StreamLink> updateStreamLink(StreamLink streamLink) async {
    final response = await _apiClient.put(
      '/streams/${streamLink.id}',
      authenticated: true,
      body: streamLink.toDatabaseMap(),
    );

    return _extractStream(response);
  }

  Future<void> deleteStreamLink(dynamic streamLinkId) async {
    await _apiClient.delete(
      '/streams/$streamLinkId',
      authenticated: true,
    );
  }

  Future<void> deleteAllStreamLinks() async {
    await _apiClient.delete(
      '/streams/all',
      authenticated: true,
    );
  }

  Future<void> deleteStreamLinksForDay(DateTime playedOn) async {
    final normalizedDate = normalizePlayedOnDate(playedOn).toIso8601String().split('T').first;
    await _apiClient.delete(
      '/streams/day/$normalizedDate',
      authenticated: true,
    );
  }

  StreamLink _extractStream(dynamic response) {
    final rawStream = switch (response) {
      {'stream': final Map stream} => Map<String, dynamic>.from(stream),
      Map stream => Map<String, dynamic>.from(stream),
      _ => throw const ApiException('Risposta live non valida dal backend.'),
    };

    return StreamLink.fromMap(rawStream);
  }
}
