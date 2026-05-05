import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../pages/notifications_page.dart';
import 'app_chrome.dart';

class NotificationsBellButton extends StatelessWidget {
  const NotificationsBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated) {
      return const SizedBox.shrink();
    }

    final unreadCount = session.unreadNotificationsCount;
    final badgeLabel = unreadCount > 99 ? '99+' : '$unreadCount';

    return IconButton(
      key: const Key('notifications-bell-button'),
      tooltip: unreadCount == 0
          ? 'Apri notifiche'
          : unreadCount == 1
          ? '1 notifica da leggere'
          : '$badgeLabel notifiche da leggere',
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => NotificationsPage()));
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_outlined),
          if (unreadCount > 0)
            Positioned(
              key: const Key('notifications-bell-badge'),
              right: -8,
              top: -8,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs - 1,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: ClublineAppTheme.dangerSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 22),
                child: Text(
                  badgeLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
