import '../models/stream_link_metadata.dart';
import 'api_client.dart';

class StreamMetadataService {
  StreamMetadataService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<StreamLinkMetadata> fetchMetadata(String url) async {
    final response = await _apiClient.post(
      '/streams/metadata',
      authenticated: true,
      body: {'url': url},
    );

    final rawMetadata = switch (response) {
      {'metadata': final Map metadata} => Map<String, dynamic>.from(metadata),
      Map metadata => Map<String, dynamic>.from(metadata),
      _ => throw const ApiException('Risposta metadata live non valida dal backend.'),
    };

    return StreamLinkMetadata.fromMap(rawMetadata);
  }
}
