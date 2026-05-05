import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  AppNotificationRow,
  AppNotificationsListResultDto,
  RequestPrincipal,
} from '../domain/types';
import { NotFoundError } from '../lib/errors';
import { ensureSuccess, optionalData, requiredData } from '../lib/supabase-result';

export interface NotificationsListInput {
  filter?: 'all' | 'unread';
  limit?: number;
  cursor?: number;
}

export interface MarkNotificationReadResultDto {
  notification: AppNotificationRow;
  unreadCount: number;
}

function normalizeListLimit(value: number | undefined): number {
  if (!Number.isFinite(value)) {
    return 20;
  }

  return Math.min(50, Math.max(1, Math.trunc(value!)));
}

export class NotificationsService {
  constructor(private readonly db: SupabaseClient) {}

  async listNotifications(
    input: NotificationsListInput,
    principal: RequestPrincipal,
  ): Promise<AppNotificationsListResultDto> {
    const userId = principal.authUser.id;
    const limit = normalizeListLimit(input.limit);
    const filter = input.filter ?? 'all';

    let query = this.db
      .from('app_notifications')
      .select('*')
      .eq('recipient_user_id', userId)
      .order('id', { ascending: false })
      .limit(limit + 1);

    if (filter === 'unread') {
      query = query.is('read_at', null);
    }
    if (input.cursor != null) {
      query = query.lt('id', input.cursor);
    }

    const rows = ((optionalData(await query) as AppNotificationRow[] | null) ?? []);
    const hasMore = rows.length > limit;
    const notifications = hasMore ? rows.slice(0, limit) : rows;

    return {
      notifications,
      unreadCount: await this.countUnread(userId),
      pagination: {
        limit,
        hasMore,
        nextCursor: hasMore ? `${notifications[notifications.length - 1]?.id ?? ''}` : null,
      },
    };
  }

  async markRead(
    notificationId: string | number,
    principal: RequestPrincipal,
  ): Promise<MarkNotificationReadResultDto> {
    const userId = principal.authUser.id;
    const notification = await this.getNotificationByIdForRecipient(notificationId, userId);

    if (notification.read_at != null) {
      return {
        notification,
        unreadCount: await this.countUnread(userId),
      };
    }

    const response = await this.db
      .from('app_notifications')
      .update({
        read_at: new Date().toISOString(),
      })
      .eq('id', notificationId)
      .eq('recipient_user_id', userId)
      .select('*')
      .single();

    return {
      notification: requiredData(response, 'Notifica non trovata') as AppNotificationRow,
      unreadCount: await this.countUnread(userId),
    };
  }

  async markAllRead(principal: RequestPrincipal): Promise<{ unreadCount: number }> {
    const userId = principal.authUser.id;
    const response = await this.db
      .from('app_notifications')
      .update({
        read_at: new Date().toISOString(),
      })
      .eq('recipient_user_id', userId)
      .is('read_at', null);

    ensureSuccess(response);

    return {
      unreadCount: await this.countUnread(userId),
    };
  }

  private async countUnread(userId: string): Promise<number> {
    const response = await this.db
      .from('app_notifications')
      .select('id', { count: 'exact', head: true })
      .eq('recipient_user_id', userId)
      .is('read_at', null);

    if (response.error) {
      throw response.error;
    }

    return response.count ?? 0;
  }

  private async getNotificationByIdForRecipient(
    notificationId: string | number,
    userId: string,
  ): Promise<AppNotificationRow> {
    const response = await this.db
      .from('app_notifications')
      .select('*')
      .eq('id', notificationId)
      .eq('recipient_user_id', userId)
      .maybeSingle();

    const notification = optionalData(response) as AppNotificationRow | null;
    if (!notification) {
      throw new NotFoundError('Notifica non trovata', 'notification_not_found');
    }

    return notification;
  }
}
