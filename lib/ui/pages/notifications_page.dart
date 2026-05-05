import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/club_invites_repository.dart';
import '../../data/notifications_repository.dart';
import '../../models/app_notification.dart';
import '../../models/club_invite.dart';
import '../widgets/app_chrome.dart';
import 'lineups_page.dart';
import 'received_club_invites_page.dart';

class NotificationsPage extends StatefulWidget {
  NotificationsPage({
    super.key,
    NotificationsRepository? repository,
    ClubInvitesRepository? clubInvitesRepository,
  }) : repository = repository ?? NotificationsRepository(),
       clubInvitesRepository = clubInvitesRepository ?? ClubInvitesRepository();

  final NotificationsRepository repository;
  final ClubInvitesRepository clubInvitesRepository;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const List<String> _monthLabels = [
    'gen',
    'feb',
    'mar',
    'apr',
    'mag',
    'giu',
    'lug',
    'ago',
    'set',
    'ott',
    'nov',
    'dic',
  ];

  List<AppNotification> notifications = const [];
  NotificationsFilter selectedFilter = NotificationsFilter.all;
  int unreadCount = 0;
  bool isLoading = true;
  bool isMarkingAllRead = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotifications());
  }

  Future<void> _loadNotifications() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await widget.repository.getNotifications(
        filter: selectedFilter,
        limit: 50,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        notifications = result.notifications;
        unreadCount = result.unreadCount;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _refreshSessionCounts() async {
    final session = AppSessionScope.read(context);
    try {
      await session.refresh(showLoadingState: false);
    } catch (_) {
      // Keep notification interactions resilient even if session refresh fails.
    }
  }

  Future<void> _markAllAsRead() async {
    if (isMarkingAllRead || unreadCount == 0) {
      return;
    }

    setState(() {
      isMarkingAllRead = true;
    });

    try {
      final nextUnreadCount = await widget.repository.markAllAsRead();
      if (!mounted) {
        return;
      }

      final now = DateTime.now();
      setState(() {
        unreadCount = nextUnreadCount;
        notifications = selectedFilter == NotificationsFilter.unread
            ? const []
            : notifications
                  .map(
                    (notification) => notification.isUnread
                        ? notification.copyWith(readAt: now)
                        : notification,
                  )
                  .toList(growable: false);
      });
      unawaited(_refreshSessionCounts());
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isMarkingAllRead = false;
        });
      }
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    var resolvedNotification = notification;

    if (notification.isUnread) {
      try {
        final result = await widget.repository.markAsRead(notification.id);
        resolvedNotification = result.notification;
        if (!mounted) {
          return;
        }

        setState(() {
          unreadCount = result.unreadCount;
          notifications = selectedFilter == NotificationsFilter.unread
              ? notifications
                    .where(
                      (entry) => '${entry.id}' != '${resolvedNotification.id}',
                    )
                    .toList(growable: false)
              : notifications
                    .map(
                      (entry) => '${entry.id}' == '${resolvedNotification.id}'
                          ? resolvedNotification
                          : entry,
                    )
                    .toList(growable: false);
        });
        unawaited(_refreshSessionCounts());
      } catch (error) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
        return;
      }
    }

    if (!mounted) {
      return;
    }

    await _handleRedirect(resolvedNotification);
  }

  Future<void> _handleRedirect(AppNotification notification) async {
    final redirectPath = _extractRedirectPath(notification.metadata);
    if (notification.notificationType ==
        AppNotificationType.clubInviteReceived) {
      final inviteId = _extractInviteId(notification);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceivedClubInvitesPage(
            repository: widget.clubInvitesRepository,
            highlightedInviteId: inviteId,
            initialStatus: ClubInviteListStatus.pending,
          ),
        ),
      );
      return;
    }

    if (notification.notificationType == AppNotificationType.lineupPublished) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LineupsPage()));
      return;
    }

    if (notification.notificationType ==
        AppNotificationType.attendancePublished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Apri la sezione Presenze dalla home del club per vedere il nuovo sondaggio.',
          ),
        ),
      );
      return;
    }

    if (redirectPath == null || redirectPath.isEmpty) {
      return;
    }

    // TODO(codex): resolve internal redirect metadata when destination routes are available.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Collegamento interno non ancora disponibile: $redirectPath',
        ),
      ),
    );
  }

  String? _extractRedirectPath(Map<String, dynamic> metadata) {
    final rawRedirect = metadata['redirect'];
    if (rawRedirect is Map) {
      final path = rawRedirect['path']?.toString().trim();
      if (path != null && path.isNotEmpty) {
        return path;
      }
    }

    final directPath = metadata['path']?.toString().trim();
    if (directPath != null && directPath.isNotEmpty) {
      return directPath;
    }

    return null;
  }

  String? _notificationCategoryLabel(AppNotification notification) {
    return switch (notification.notificationType) {
      AppNotificationType.clubInviteReceived => 'Invito club',
      AppNotificationType.lineupPublished => 'Formazione',
      AppNotificationType.attendancePublished => 'Presenze',
      AppNotificationType.clubInviteAccepted => 'Invito club',
      AppNotificationType.clubInviteDeclined => 'Invito club',
      AppNotificationType.clubInviteRevoked => 'Invito club',
    };
  }

  AppStatusTone _notificationCategoryTone(AppNotification notification) {
    return switch (notification.notificationType) {
      AppNotificationType.clubInviteReceived => AppStatusTone.success,
      AppNotificationType.lineupPublished => AppStatusTone.info,
      AppNotificationType.attendancePublished => AppStatusTone.warning,
      AppNotificationType.clubInviteAccepted => AppStatusTone.success,
      AppNotificationType.clubInviteDeclined => AppStatusTone.info,
      AppNotificationType.clubInviteRevoked => AppStatusTone.warning,
    };
  }

  IconData _notificationIcon(AppNotification notification) {
    return switch (notification.notificationType) {
      AppNotificationType.clubInviteReceived => Icons.mail_outline,
      AppNotificationType.lineupPublished => Icons.sports_soccer_outlined,
      AppNotificationType.attendancePublished =>
        Icons.event_available_outlined,
      AppNotificationType.clubInviteAccepted =>
        Icons.mark_email_read_outlined,
      AppNotificationType.clubInviteDeclined => Icons.mail_lock_outlined,
      AppNotificationType.clubInviteRevoked => Icons.cancel_presentation_outlined,
    };
  }

  String? _notificationActionLabel(AppNotification notification) {
    return switch (notification.notificationType) {
      AppNotificationType.clubInviteReceived => 'Vedi invito',
      AppNotificationType.lineupPublished => 'Apri formazioni',
      AppNotificationType.attendancePublished => 'Apri presenze',
      AppNotificationType.clubInviteAccepted => null,
      AppNotificationType.clubInviteDeclined => null,
      AppNotificationType.clubInviteRevoked => null,
    };
  }

  dynamic _extractInviteId(AppNotification notification) {
    if (notification.relatedInviteId != null) {
      return notification.relatedInviteId;
    }

    final metadata = notification.metadata;
    final rawInviteId = metadata['inviteId'] ?? metadata['invite_id'];
    return rawInviteId;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Adesso';
    }

    final localValue = value.toLocal();
    final day = localValue.day.toString().padLeft(2, '0');
    final month = _monthLabels[localValue.month - 1];
    final year = localValue.year.toString();
    final hours = localValue.hour.toString().padLeft(2, '0');
    final minutes = localValue.minute.toString().padLeft(2, '0');

    return '$day $month $year • $hours:$minutes';
  }

  Future<void> _changeFilter(NotificationsFilter filter) async {
    if (selectedFilter == filter) {
      return;
    }

    setState(() {
      selectedFilter = filter;
    });
    await _loadNotifications();
  }

  Widget _buildScrollableBody(List<Widget> children) {
    return AppPageBackground(
      child: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: AppContentFrame(
          wide: true,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppResponsive.pagePadding(context, top: 24),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                AppCountPill(label: 'Totali', value: '${notifications.length}'),
                AppCountPill(
                  label: 'Da leggere',
                  value: '$unreadCount',
                  emphasized: unreadCount > 0,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<NotificationsFilter>(
                segments: const [
                  ButtonSegment<NotificationsFilter>(
                    value: NotificationsFilter.all,
                    label: Text('Tutte'),
                    icon: Icon(Icons.inbox_outlined),
                  ),
                  ButtonSegment<NotificationsFilter>(
                    value: NotificationsFilter.unread,
                    label: Text('Da leggere'),
                    icon: Icon(Icons.mark_email_unread_outlined),
                  ),
                ],
                selected: {selectedFilter},
                onSelectionChanged: isLoading
                    ? null
                    : (selection) {
                        unawaited(_changeFilter(selection.first));
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final actionLabel = _notificationActionLabel(notification);
    final categoryLabel = _notificationCategoryLabel(notification);

    return Card(
      key: Key('notification-card-${notification.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          unawaited(_openNotification(notification));
        },
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconBadge(
                    icon: _notificationIcon(notification),
                    size: AppResponsive.isCompact(context) ? 50 : 56,
                    iconSize: AppResponsive.isCompact(context) ? 20 : 22,
                    borderRadius: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            AppStatusBadge(
                              key: Key(
                                notification.isUnread
                                    ? 'notification-unread-badge-${notification.id}'
                                    : 'notification-read-badge-${notification.id}',
                              ),
                              label: notification.isUnread
                                  ? 'Da leggere'
                                  : 'Letta',
                              tone: notification.isUnread
                                  ? AppStatusTone.warning
                                  : AppStatusTone.info,
                            ),
                            if (categoryLabel != null)
                              AppStatusBadge(
                                label: categoryLabel,
                                tone: _notificationCategoryTone(notification),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          notification.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: notification.isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                        ),
                        if ((notification.body ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            notification.body!.trim(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: ClublineAppTheme.textMuted,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: ClublineAppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateTime(notification.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ClublineAppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: Key('notification-action-cta-${notification.id}'),
                    onPressed: () {
                      unawaited(_openNotification(notification));
                    },
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: Text(actionLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final header = const AppPageHeader(
      eyebrow: 'Inbox',
      title: 'Notifiche',
      subtitle:
          'Qui trovi gli aggiornamenti interni dell app. Le nuove notifiche aggiornano anche il contatore in tempo reale.',
    );

    if (isLoading) {
      return const AppPageBackground(
        child: AppLoadingState(label: 'Stiamo caricando le notifiche...'),
      );
    }

    if (errorMessage != null) {
      return _buildScrollableBody([
        header,
        const SizedBox(height: AppSpacing.lg),
        _buildHeaderCard(),
        const SizedBox(height: AppSpacing.lg),
        AppErrorState(
          title: 'Impossibile caricare le notifiche',
          message: errorMessage!,
          actionLabel: 'Riprova',
          onAction: _loadNotifications,
        ),
      ]);
    }

    if (notifications.isEmpty) {
      return _buildScrollableBody([
        header,
        const SizedBox(height: AppSpacing.lg),
        _buildHeaderCard(),
        const SizedBox(height: AppSpacing.lg),
        AppEmptyState(
          key: const Key('notifications-empty-state'),
          icon: selectedFilter == NotificationsFilter.unread
              ? Icons.mark_email_read_outlined
              : Icons.notifications_none_outlined,
          title: selectedFilter == NotificationsFilter.unread
              ? 'Nessuna notifica da leggere'
              : 'Nessuna notifica disponibile',
          message: selectedFilter == NotificationsFilter.unread
              ? 'Hai gia letto tutto. Le nuove notifiche appariranno qui automaticamente.'
              : 'Quando ci saranno aggiornamenti interni dell app li troverai in questa inbox.',
        ),
      ]);
    }

    return _buildScrollableBody([
      header,
      const SizedBox(height: AppSpacing.lg),
      _buildHeaderCard(),
      const SizedBox(height: AppSpacing.lg),
      for (final notification in notifications) ...[
        _buildNotificationCard(notification),
        const SizedBox(height: AppSpacing.md),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        actions: [
          TextButton(
            key: const Key('notifications-mark-all-button'),
            onPressed: unreadCount == 0 || isMarkingAllRead
                ? null
                : _markAllAsRead,
            child: Text(isMarkingAllRead ? 'Lettura...' : 'Segna tutte'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
