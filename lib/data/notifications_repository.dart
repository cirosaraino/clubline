import '../models/app_notification.dart';
import 'api_client.dart';

class NotificationsRepository {
  NotificationsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<AppNotificationsListResult> getNotifications({
    NotificationsFilter filter = NotificationsFilter.all,
    int limit = 20,
    int? cursor,
  }) async {
    final normalizedLimit = limit.clamp(1, 50);
    final queryParameters = <String>[
      'filter=${Uri.encodeQueryComponent(filter.value)}',
      'limit=$normalizedLimit',
      if (cursor != null) 'cursor=$cursor',
    ];
    final response = await _apiClient.get(
      '/notifications?${queryParameters.join('&')}',
      authenticated: true,
    );
    return AppNotificationsListResult.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<MarkNotificationReadResult> markAsRead(dynamic notificationId) async {
    final response = await _apiClient.post(
      '/notifications/$notificationId/read',
      authenticated: true,
    );
    return MarkNotificationReadResult.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<int> markAllAsRead() async {
    final response = await _apiClient.post(
      '/notifications/read-all',
      authenticated: true,
    );
    final responseMap = Map<String, dynamic>.from(response as Map);
    return responseMap['unreadCount'] is num
        ? (responseMap['unreadCount'] as num).toInt()
        : 0;
  }
}
