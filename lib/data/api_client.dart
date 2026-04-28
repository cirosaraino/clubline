import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_backend_config.dart';
import 'auth_session_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiUnauthorizedException extends ApiException {
  const ApiUnauthorizedException(super.message, {super.statusCode});
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    AuthSessionStore? sessionStore,
  })  : _httpClient = httpClient ?? http.Client(),
        _sessionStore = sessionStore ?? AuthSessionStore();

  static final ApiClient shared = ApiClient();
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _retryDelay = Duration(milliseconds: 250);

  final http.Client _httpClient;
  final AuthSessionStore _sessionStore;

  Future<void> warmUpBackend() async {
    try {
      await get('/health');
    } catch (_) {
      // Warm-up is best-effort and must never block the real auth flow.
    }
  }

  Future<dynamic> get(
    String path, {
    bool authenticated = false,
    String? accessToken,
  }) {
    return _request(
      method: 'GET',
      path: path,
      authenticated: authenticated,
      accessToken: accessToken,
    );
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
    String? accessToken,
  }) {
    return _request(
      method: 'POST',
      path: path,
      body: body,
      authenticated: authenticated,
      accessToken: accessToken,
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
    String? accessToken,
  }) {
    return _request(
      method: 'PUT',
      path: path,
      body: body,
      authenticated: authenticated,
      accessToken: accessToken,
    );
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
    String? accessToken,
  }) {
    return _request(
      method: 'DELETE',
      path: path,
      body: body,
      authenticated: authenticated,
      accessToken: accessToken,
    );
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required bool authenticated,
    String? accessToken,
  }) async {
    final uri = _buildUri(path);
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    final bearerToken = accessToken ?? await _readStoredAccessToken(authenticated);
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }

    late final http.Response response;
    final encodedBody = body == null ? null : jsonEncode(body);
    final maxAttempts = method == 'GET' ? 2 : 1;
    var attempt = 0;

    while (true) {
      attempt += 1;
      try {
        switch (method) {
          case 'GET':
            response = await _httpClient
                .get(uri, headers: headers)
                .timeout(_requestTimeout);
            break;
          case 'POST':
            response = await _httpClient
                .post(uri, headers: headers, body: encodedBody)
                .timeout(_requestTimeout);
            break;
          case 'PUT':
            response = await _httpClient
                .put(uri, headers: headers, body: encodedBody)
                .timeout(_requestTimeout);
            break;
          case 'DELETE':
            response = await _httpClient
                .delete(uri, headers: headers, body: encodedBody)
                .timeout(_requestTimeout);
            break;
          default:
            throw ApiException('Metodo HTTP non supportato: $method');
        }

        break;
      } on TimeoutException {
        if (attempt < maxAttempts) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        throw const ApiException(
          'Connessione lenta o non disponibile. Riprova tra qualche secondo.',
        );
      } on http.ClientException {
        if (attempt < maxAttempts) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        throw const ApiException(
          'Impossibile raggiungere il server. Controlla la connessione e riprova.',
        );
      }
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      }
      throw _mapError(response, null);
    }

    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } catch (_) {
      decodedBody = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    throw _mapError(response, decodedBody);
  }

  Uri _buildUri(String path) {
    final normalizedBaseUrl = AppBackendConfig.baseUrl.endsWith('/')
        ? AppBackendConfig.baseUrl.substring(0, AppBackendConfig.baseUrl.length - 1)
        : AppBackendConfig.baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBaseUrl$normalizedPath');
  }

  Future<String?> _readStoredAccessToken(bool authenticated) async {
    if (!authenticated) {
      return null;
    }

    final session = await _sessionStore.readSession();
    return session?.accessToken;
  }

  ApiException _mapError(http.Response response, dynamic decodedBody) {
    final message = _extractErrorMessage(decodedBody) ??
        'Richiesta API fallita con stato ${response.statusCode}.';

    if (response.statusCode == 401) {
      return ApiUnauthorizedException(message, statusCode: response.statusCode);
    }

    return ApiException(message, statusCode: response.statusCode);
  }

  String? _extractErrorMessage(dynamic decodedBody) {
    if (decodedBody is String && decodedBody.trim().isNotEmpty) {
      return decodedBody.trim();
    }

    if (decodedBody is Map) {
      final rawError = decodedBody['error'];
      if (rawError is Map && rawError['message'] != null) {
        return rawError['message'].toString();
      }

      final rawMessage = decodedBody['message'];
      if (rawMessage != null) {
        return rawMessage.toString();
      }
    }

    return null;
  }
}
