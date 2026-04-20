import '../core/auth_recovery/auth_recovery_url_bridge.dart';
import '../models/auth_session.dart';
import '../models/authenticated_user.dart';
import 'api_client.dart';
import 'auth_session_store.dart';

class AuthRepository {
  AuthRepository({
    ApiClient? apiClient,
    AuthSessionStore? sessionStore,
  })  : _apiClient = apiClient ?? ApiClient.shared,
        _sessionStore = sessionStore ?? AuthSessionStore();

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;

  AuthSession? _session;

  AuthenticatedUser? get currentUser => _session?.user;

  AuthSession? get currentSession => _session;

  Future<bool> fetchCanBootstrapCaptainRegistration() async {
    final response = await _apiClient.get('/auth/bootstrap-status');
    final responseMap = Map<String, dynamic>.from(response as Map);
    return responseMap['canBootstrapCaptainRegistration'] == true;
  }

  Future<AuthenticatedUser?> restoreSession() async {
    await _restoreRecoverySessionFromUrl();
    _session ??= await _sessionStore.readSession();
    if (_session == null) {
      return null;
    }

    try {
      final response = await _apiClient.get(
        '/auth/me',
        authenticated: true,
        accessToken: _session!.accessToken,
      );
      final responseMap = Map<String, dynamic>.from(response as Map);
      final rawUser = Map<String, dynamic>.from(responseMap['user'] as Map);
      final restoredUser = AuthenticatedUser.fromMap(rawUser);
      _session = _session!.copyWith(user: restoredUser);
      await _sessionStore.saveSession(_session!);
      return restoredUser;
    } on ApiUnauthorizedException {
      return _refreshSession();
    } catch (_) {
      rethrow;
    }
  }

  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    final session = AuthSession.fromMap(Map<String, dynamic>.from(response as Map));
    await _sessionStore.saveSession(session);
    _session = session;
    return session;
  }

  Future<String> requestPasswordReset({
    required String email,
  }) async {
    final response = await _apiClient.post(
      '/auth/request-password-reset',
      body: {
        'email': email.trim(),
        'redirectTo': _passwordResetRedirectUrl(),
      },
    );

    final responseMap = Map<String, dynamic>.from(response as Map);
    return responseMap['message']?.toString() ??
        'Se l account esiste, abbiamo inviato una mail con le istruzioni.';
  }

  Future<String> updatePassword({
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/update-password',
      authenticated: true,
      body: {
        'password': password,
      },
      accessToken: _session?.accessToken,
    );

    final responseMap = Map<String, dynamic>.from(response as Map);
    final updatedSession = (_session ?? await _sessionStore.readSession())
        ?.copyWith(isRecoverySession: false);
    if (updatedSession != null) {
      await _sessionStore.saveSession(updatedSession);
      _session = updatedSession;
    }

    return responseMap['message']?.toString() ??
        'Password aggiornata con successo.';
  }

  Future<String> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'redirectTo': _emailVerificationRedirectUrl(),
      },
    );

    final responseMap = Map<String, dynamic>.from(response as Map);
    return responseMap['message']?.toString() ??
        'Ti abbiamo inviato una mail di verifica. Conferma l indirizzo email prima di accedere.';
  }

  Future<void> signOut() async {
    try {
      final currentSession = _session ?? await _sessionStore.readSession();
      final accessToken = currentSession?.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        await _apiClient.post(
          '/auth/logout',
          authenticated: true,
          accessToken: accessToken,
        );
      }
    } catch (_) {
      // Even if the backend logout fails, the local session must be cleared.
    } finally {
      await _sessionStore.clear();
      _session = null;
    }
  }

  Future<AuthenticatedUser?> _refreshSession() async {
    final currentSession = _session ?? await _sessionStore.readSession();
    if (currentSession == null || currentSession.refreshToken.isEmpty) {
      await _sessionStore.clear();
      _session = null;
      return null;
    }

    try {
      final response = await _apiClient.post(
        '/auth/refresh',
        body: {
          'refreshToken': currentSession.refreshToken,
        },
      );
      final refreshedSession = AuthSession.fromMap(Map<String, dynamic>.from(response as Map));
      await _sessionStore.saveSession(refreshedSession);
      _session = refreshedSession;
      return refreshedSession.user;
    } catch (_) {
      await _sessionStore.clear();
      _session = null;
      return null;
    }
  }

  Future<void> _restoreRecoverySessionFromUrl() async {
    final candidate = authRecoveryUrlBridge.readRecoverySessionCandidate();
    if (candidate == null) {
      return;
    }

    try {
      final response = await _apiClient.get(
        '/auth/me',
        authenticated: true,
        accessToken: candidate.accessToken,
      );
      final responseMap = Map<String, dynamic>.from(response as Map);
      final rawUser = Map<String, dynamic>.from(responseMap['user'] as Map);
      final recoveredSession = AuthSession(
        accessToken: candidate.accessToken,
        refreshToken: candidate.refreshToken,
        expiresAt: candidate.expiresAt,
        isRecoverySession: true,
        user: AuthenticatedUser.fromMap(rawUser),
      );

      await _sessionStore.saveSession(recoveredSession);
      _session = recoveredSession;
      await authRecoveryUrlBridge.clearRecoverySessionCandidate();
    } on ApiException {
      await authRecoveryUrlBridge.clearRecoverySessionCandidate();
      throw const ApiException(
        'Il link di recupero password non e piu valido. Richiedine uno nuovo.',
      );
    }
  }

  String _passwordResetRedirectUrl() {
    final currentUri = Uri.base;
    if ((currentUri.scheme == 'http' || currentUri.scheme == 'https') &&
        currentUri.host.isNotEmpty) {
      return Uri(
        scheme: currentUri.scheme,
        host: currentUri.host,
        port: currentUri.hasPort ? currentUri.port : null,
        path: '/',
      ).toString();
    }

    throw const ApiException(
      'Recupero password disponibile dalla web app pubblica.',
    );
  }

  String _emailVerificationRedirectUrl() {
    final currentUri = Uri.base;
    if ((currentUri.scheme == 'http' || currentUri.scheme == 'https') &&
        currentUri.host.isNotEmpty) {
      return Uri(
        scheme: currentUri.scheme,
        host: currentUri.host,
        port: currentUri.hasPort ? currentUri.port : null,
        path: '/',
      ).toString();
    }

    return _passwordResetRedirectUrl();
  }
}
