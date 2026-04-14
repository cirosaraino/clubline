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

  Future<AuthenticatedUser?> restoreSession() async {
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

  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/register',
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
}
