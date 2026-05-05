import 'cursor_pagination.dart';

DateTime? _parseNotificationDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString())?.toLocal();
}

enum AppNotificationType {
  clubInviteReceived,
  clubInviteAccepted,
  clubInviteDeclined,
  clubInviteRevoked,
  lineupPublished,
  attendancePublished;

  static AppNotificationType fromValue(String? value) {
    return switch (value?.trim()) {
      'club_invite_accepted' => AppNotificationType.clubInviteAccepted,
      'club_invite_declined' => AppNotificationType.clubInviteDeclined,
      'club_invite_revoked' => AppNotificationType.clubInviteRevoked,
      'lineup_published' => AppNotificationType.lineupPublished,
      'attendance_published' => AppNotificationType.attendancePublished,
      _ => AppNotificationType.clubInviteReceived,
    };
  }

  String get value => switch (this) {
    AppNotificationType.clubInviteReceived => 'club_invite_received',
    AppNotificationType.clubInviteAccepted => 'club_invite_accepted',
    AppNotificationType.clubInviteDeclined => 'club_invite_declined',
    AppNotificationType.clubInviteRevoked => 'club_invite_revoked',
    AppNotificationType.lineupPublished => 'lineup_published',
    AppNotificationType.attendancePublished => 'attendance_published',
  };
}

enum NotificationsFilter {
  all,
  unread;

  String get value => name;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.notificationType,
    required this.title,
    required this.metadata,
    this.clubId,
    this.body,
    this.relatedInviteId,
    this.readAt,
    this.dedupeKey,
    this.createdAt,
  });

  final dynamic id;
  final String recipientUserId;
  final dynamic clubId;
  final AppNotificationType notificationType;
  final String title;
  final String? body;
  final Map<String, dynamic> metadata;
  final dynamic relatedInviteId;
  final DateTime? readAt;
  final String? dedupeKey;
  final DateTime? createdAt;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final rawMetadata = map['metadata'];

    return AppNotification(
      id: map['id'],
      recipientUserId: map['recipient_user_id']?.toString() ?? '',
      clubId: map['club_id'],
      notificationType: AppNotificationType.fromValue(
        map['notification_type']?.toString(),
      ),
      title: map['title']?.toString().trim() ?? '',
      body: map['body']?.toString(),
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
      relatedInviteId: map['related_invite_id'],
      readAt: _parseNotificationDateTime(map['read_at']),
      dedupeKey: map['dedupe_key']?.toString(),
      createdAt: _parseNotificationDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_user_id': recipientUserId,
      'club_id': clubId,
      'notification_type': notificationType.value,
      'title': title,
      'body': body,
      'metadata': metadata,
      'related_invite_id': relatedInviteId,
      'read_at': readAt?.toUtc().toIso8601String(),
      'dedupe_key': dedupeKey,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }

  bool get isUnread => readAt == null;

  AppNotification copyWith({
    dynamic id,
    String? recipientUserId,
    dynamic clubId,
    AppNotificationType? notificationType,
    String? title,
    String? body,
    Map<String, dynamic>? metadata,
    dynamic relatedInviteId,
    DateTime? readAt,
    bool clearReadAt = false,
    String? dedupeKey,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      clubId: clubId ?? this.clubId,
      notificationType: notificationType ?? this.notificationType,
      title: title ?? this.title,
      body: body ?? this.body,
      metadata: metadata ?? this.metadata,
      relatedInviteId: relatedInviteId ?? this.relatedInviteId,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      dedupeKey: dedupeKey ?? this.dedupeKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AppNotificationsListResult {
  const AppNotificationsListResult({
    required this.notifications,
    required this.unreadCount,
    required this.pagination,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final CursorPagination pagination;

  factory AppNotificationsListResult.fromMap(Map<String, dynamic> map) {
    final rawNotifications = map['notifications'];
    final rawPagination = map['pagination'];

    return AppNotificationsListResult(
      notifications: rawNotifications is Iterable
          ? rawNotifications
                .whereType<Map>()
                .map(
                  (notification) => AppNotification.fromMap(
                    Map<String, dynamic>.from(notification),
                  ),
                )
                .toList(growable: false)
          : const [],
      unreadCount: map['unreadCount'] is num
          ? (map['unreadCount'] as num).toInt()
          : 0,
      pagination: rawPagination is Map
          ? CursorPagination.fromMap(Map<String, dynamic>.from(rawPagination))
          : const CursorPagination(limit: 20, hasMore: false),
    );
  }
}

class MarkNotificationReadResult {
  const MarkNotificationReadResult({
    required this.notification,
    required this.unreadCount,
  });

  final AppNotification notification;
  final int unreadCount;

  factory MarkNotificationReadResult.fromMap(Map<String, dynamic> map) {
    return MarkNotificationReadResult(
      notification: AppNotification.fromMap(
        Map<String, dynamic>.from(map['notification'] as Map),
      ),
      unreadCount: map['unreadCount'] is num
          ? (map['unreadCount'] as num).toInt()
          : 0,
    );
  }
}
