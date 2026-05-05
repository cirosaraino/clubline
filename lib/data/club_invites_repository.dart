import '../models/club_invite.dart';
import '../models/invite_candidate.dart';
import 'api_client.dart';

class ClubInvitesRepository {
  ClubInvitesRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<List<InviteCandidate>> searchCandidates(
    String query, {
    int limit = 20,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final normalizedLimit = limit.clamp(1, 20);
    final response = await _apiClient.get(
      '/club-invites/candidates?q=${Uri.encodeQueryComponent(normalizedQuery)}&limit=$normalizedLimit',
      authenticated: true,
    );
    final rawCandidates = switch (response) {
      {'candidates': final List candidates} => candidates,
      List candidates => candidates,
      _ => const [],
    };

    return rawCandidates
        .map<InviteCandidate>(
          (candidate) =>
              InviteCandidate.fromMap(Map<String, dynamic>.from(candidate)),
        )
        .toList(growable: false);
  }

  Future<ClubInvite> createInvite(String targetUserId) async {
    final response = await _apiClient.post(
      '/club-invites',
      authenticated: true,
      body: {'targetUserId': targetUserId},
    );
    return _extractInvite(response);
  }

  Future<ClubInviteListResult> getSentInvites({
    ClubInviteListStatus status = ClubInviteListStatus.pending,
    int limit = 20,
    int? cursor,
  }) async {
    final response = await _apiClient.get(
      _buildInviteListPath(
        '/club-invites/sent',
        status: status,
        limit: limit,
        cursor: cursor,
      ),
      authenticated: true,
    );
    return ClubInviteListResult.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<ClubInviteListResult> getReceivedInvites({
    ClubInviteListStatus status = ClubInviteListStatus.pending,
    int limit = 20,
    int? cursor,
  }) async {
    final response = await _apiClient.get(
      _buildInviteListPath(
        '/club-invites/received',
        status: status,
        limit: limit,
        cursor: cursor,
      ),
      authenticated: true,
    );
    return ClubInviteListResult.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<ClubInvite> revokeInvite(dynamic inviteId) async {
    final response = await _apiClient.post(
      '/club-invites/$inviteId/revoke',
      authenticated: true,
    );
    return _extractInvite(response);
  }

  Future<ClubInviteAcceptResult> acceptInvite(dynamic inviteId) async {
    final response = await _apiClient.post(
      '/club-invites/$inviteId/accept',
      authenticated: true,
    );
    return ClubInviteAcceptResult.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<ClubInvite> declineInvite(dynamic inviteId) async {
    final response = await _apiClient.post(
      '/club-invites/$inviteId/decline',
      authenticated: true,
    );
    return _extractInvite(response);
  }

  ClubInvite _extractInvite(dynamic response) {
    final rawInvite = switch (response) {
      {'invite': final Map invite} => Map<String, dynamic>.from(invite),
      Map<String, dynamic> invite when invite.containsKey('id') => invite,
      Map invite => Map<String, dynamic>.from(invite),
      _ => throw const ApiException('Risposta invito non valida dal backend.'),
    };

    return ClubInvite.fromMap(rawInvite);
  }

  String _buildInviteListPath(
    String basePath, {
    required ClubInviteListStatus status,
    required int limit,
    int? cursor,
  }) {
    final normalizedLimit = limit.clamp(1, 50);
    final queryParameters = <String>[
      'status=${Uri.encodeQueryComponent(status.value)}',
      'limit=$normalizedLimit',
      if (cursor != null) 'cursor=$cursor',
    ];
    return '$basePath?${queryParameters.join('&')}';
  }
}
