import '../models/club.dart';
import '../models/join_request.dart';
import '../models/leave_request.dart';
import '../models/membership.dart';
import 'api_client.dart';

class ClubRepository {
  ClubRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<List<Club>> searchClubs({String? query}) async {
    final path = query == null || query.trim().isEmpty
        ? '/clubs'
        : '/clubs?q=${Uri.encodeQueryComponent(query.trim())}';
    final response = await _apiClient.get(path, authenticated: true);
    final rawClubs = switch (response) {
      {'clubs': final List clubs} => clubs,
      List clubs => clubs,
      _ => const [],
    };

    return rawClubs
        .map<Club>((club) => Club.fromMap(Map<String, dynamic>.from(club)))
        .toList();
  }

  Future<Club?> fetchCurrentClub() async {
    final response = await _apiClient.get(
      '/clubs/current',
      authenticated: true,
    );
    final rawClub = switch (response) {
      {'club': final Map club} => Map<String, dynamic>.from(club),
      Map<String, dynamic> club when club.containsKey('id') => club,
      _ => null,
    };

    return rawClub == null ? null : Club.fromMap(rawClub);
  }

  Future<Membership?> fetchCurrentMembership() async {
    final response = await _apiClient.get(
      '/clubs/current/membership',
      authenticated: true,
    );
    final rawMembership = switch (response) {
      {'membership': final Map membership} => Map<String, dynamic>.from(
        membership,
      ),
      Map<String, dynamic> membership when membership.containsKey('club_id') =>
        membership,
      _ => null,
    };

    return rawMembership == null ? null : Membership.fromMap(rawMembership);
  }

  Future<JoinRequest?> fetchCurrentPendingJoinRequest() async {
    final response = await _apiClient.get(
      '/clubs/current/pending-join-request',
      authenticated: true,
    );
    final rawRequest = switch (response) {
      {'joinRequest': final Map request} => Map<String, dynamic>.from(request),
      Map<String, dynamic> request when request.containsKey('club_id') =>
        request,
      _ => null,
    };

    return rawRequest == null ? null : JoinRequest.fromMap(rawRequest);
  }

  Future<LeaveRequest?> fetchCurrentPendingLeaveRequest() async {
    final response = await _apiClient.get(
      '/clubs/current/pending-leave-request',
      authenticated: true,
    );
    final rawRequest = switch (response) {
      {'leaveRequest': final Map request} => Map<String, dynamic>.from(request),
      Map<String, dynamic> request when request.containsKey('membership_id') =>
        request,
      _ => null,
    };

    return rawRequest == null ? null : LeaveRequest.fromMap(rawRequest);
  }

  Future<void> createClub({
    required String name,
    required String ownerNome,
    required String ownerCognome,
    required String ownerConsoleId,
    int? ownerShirtNumber,
    String? ownerPrimaryRole,
    String? logoDataUrl,
    String? primaryColor,
    String? accentColor,
    String? surfaceColor,
  }) async {
    await _apiClient.post(
      '/clubs',
      authenticated: true,
      body: {
        'name': name.trim(),
        'owner_nome': ownerNome.trim(),
        'owner_cognome': ownerCognome.trim(),
        'owner_id_console': ownerConsoleId.trim(),
        'owner_shirt_number': ownerShirtNumber,
        'owner_primary_role': ownerPrimaryRole?.trim().isEmpty == true
            ? null
            : ownerPrimaryRole?.trim(),
        'logo_data_url': logoDataUrl,
        'primary_color': primaryColor,
        'accent_color': accentColor,
        'surface_color': surfaceColor,
      },
    );
  }

  Future<void> requestJoinClub({
    required dynamic clubId,
    required String nome,
    required String cognome,
    int? shirtNumber,
    String? primaryRole,
  }) async {
    await _apiClient.post(
      '/clubs/join-requests',
      authenticated: true,
      body: {
        'club_id': clubId,
        'requested_nome': nome.trim(),
        'requested_cognome': cognome.trim(),
        'requested_shirt_number': shirtNumber,
        'requested_primary_role': primaryRole?.trim().isEmpty == true
            ? null
            : primaryRole?.trim(),
      },
    );
  }

  Future<List<JoinRequest>> fetchPendingJoinRequests() async {
    final response = await _apiClient.get(
      '/clubs/join-requests/pending',
      authenticated: true,
    );
    final rawRequests = switch (response) {
      {'joinRequests': final List requests} => requests,
      List requests => requests,
      _ => const [],
    };

    return rawRequests
        .map<JoinRequest>(
          (request) => JoinRequest.fromMap(Map<String, dynamic>.from(request)),
        )
        .toList();
  }

  Future<List<LeaveRequest>> fetchPendingLeaveRequests() async {
    final response = await _apiClient.get(
      '/clubs/leave-requests/pending',
      authenticated: true,
    );
    final rawRequests = switch (response) {
      {'leaveRequests': final List requests} => requests,
      List requests => requests,
      _ => const [],
    };

    return rawRequests
        .map<LeaveRequest>(
          (request) => LeaveRequest.fromMap(Map<String, dynamic>.from(request)),
        )
        .toList();
  }

  Future<void> approveJoinRequest(dynamic joinRequestId) {
    return _apiClient.post(
      '/clubs/join-requests/$joinRequestId/approve',
      authenticated: true,
    );
  }

  Future<void> rejectJoinRequest(dynamic joinRequestId) {
    return _apiClient.post(
      '/clubs/join-requests/$joinRequestId/reject',
      authenticated: true,
    );
  }

  Future<void> cancelJoinRequest(dynamic joinRequestId) {
    return _apiClient.delete(
      '/clubs/join-requests/$joinRequestId',
      authenticated: true,
    );
  }

  Future<void> requestLeaveClub() {
    return _apiClient.post('/clubs/leave-requests', authenticated: true);
  }

  Future<void> cancelLeaveRequest(dynamic leaveRequestId) {
    return _apiClient.delete(
      '/clubs/leave-requests/$leaveRequestId',
      authenticated: true,
    );
  }

  Future<void> approveLeaveRequest(dynamic leaveRequestId) {
    return _apiClient.post(
      '/clubs/leave-requests/$leaveRequestId/approve',
      authenticated: true,
    );
  }

  Future<void> rejectLeaveRequest(dynamic leaveRequestId) {
    return _apiClient.post(
      '/clubs/leave-requests/$leaveRequestId/reject',
      authenticated: true,
    );
  }

  Future<void> transferCaptain(dynamic targetMembershipId) {
    return _apiClient.post(
      '/clubs/transfer-captain',
      authenticated: true,
      body: {'target_membership_id': targetMembershipId},
    );
  }

  Future<void> deleteCurrentClub() {
    return _apiClient.delete('/clubs/current', authenticated: true);
  }
}
