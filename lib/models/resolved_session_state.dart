import 'authenticated_user.dart';
import 'club.dart';
import 'club_info.dart';
import 'join_request.dart';
import 'leave_request.dart';
import 'membership.dart';
import 'player_profile.dart';
import 'vice_permissions.dart';

class ResolvedSessionState {
  const ResolvedSessionState({
    required this.user,
    required this.vicePermissions,
    this.membership,
    this.club,
    this.currentPlayer,
    this.clubInfo,
    this.pendingJoinRequest,
    this.pendingLeaveRequest,
    this.captainPendingJoinRequests = const [],
    this.captainPendingLeaveRequests = const [],
  });

  final AuthenticatedUser user;
  final Membership? membership;
  final Club? club;
  final PlayerProfile? currentPlayer;
  final VicePermissions vicePermissions;
  final ClubInfo? clubInfo;
  final JoinRequest? pendingJoinRequest;
  final LeaveRequest? pendingLeaveRequest;
  final List<JoinRequest> captainPendingJoinRequests;
  final List<LeaveRequest> captainPendingLeaveRequests;

  factory ResolvedSessionState.fromMap(Map<String, dynamic> map) {
    final rawMembership = map['membership'];
    final rawClub = map['club'];
    final rawCurrentPlayer = map['currentPlayer'];
    final rawVicePermissions = map['vicePermissions'];
    final rawClubInfo = map['clubInfo'];
    final rawPendingJoinRequest = map['pendingJoinRequest'];
    final rawPendingLeaveRequest = map['pendingLeaveRequest'];
    final rawCaptainPendingJoinRequests = map['captainPendingJoinRequests'];
    final rawCaptainPendingLeaveRequests = map['captainPendingLeaveRequests'];

    return ResolvedSessionState(
      user: AuthenticatedUser.fromMap(
        Map<String, dynamic>.from(map['user'] as Map),
      ),
      membership: rawMembership is Map
          ? Membership.fromMap(Map<String, dynamic>.from(rawMembership))
          : null,
      club: rawClub is Map
          ? Club.fromMap(Map<String, dynamic>.from(rawClub))
          : null,
      currentPlayer: rawCurrentPlayer is Map
          ? PlayerProfile.fromMap(Map<String, dynamic>.from(rawCurrentPlayer))
          : null,
      vicePermissions: rawVicePermissions is Map
          ? VicePermissions.fromMap(
              Map<String, dynamic>.from(rawVicePermissions),
            )
          : VicePermissions.defaults,
      clubInfo: rawClubInfo is Map
          ? ClubInfo.fromMap(Map<String, dynamic>.from(rawClubInfo))
          : null,
      pendingJoinRequest: rawPendingJoinRequest is Map
          ? JoinRequest.fromMap(
              Map<String, dynamic>.from(rawPendingJoinRequest),
            )
          : null,
      pendingLeaveRequest: rawPendingLeaveRequest is Map
          ? LeaveRequest.fromMap(
              Map<String, dynamic>.from(rawPendingLeaveRequest),
            )
          : null,
      captainPendingJoinRequests: rawCaptainPendingJoinRequests is Iterable
          ? rawCaptainPendingJoinRequests
                .whereType<Map>()
                .map(
                  (request) =>
                      JoinRequest.fromMap(Map<String, dynamic>.from(request)),
                )
                .toList(growable: false)
          : const [],
      captainPendingLeaveRequests: rawCaptainPendingLeaveRequests is Iterable
          ? rawCaptainPendingLeaveRequests
                .whereType<Map>()
                .map(
                  (request) =>
                      LeaveRequest.fromMap(Map<String, dynamic>.from(request)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}
