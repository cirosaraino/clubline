import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  AttendanceWeekRow,
  AppNotificationType,
  ClubRow,
  LineupRow,
} from '../domain/types';
import { ensureSuccess, optionalData, requiredData } from '../lib/supabase-result';

type RpcCapableClient = SupabaseClient & {
  rpc?: (
    fn: string,
    args?: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: Error | null }>;
};

type ClubNotificationPublishResult = {
  recipientUserIds: string[];
  notificationIds: Array<string | number>;
};

function isNonEmptyText(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function normalizeUserId(value: unknown): string | null {
  if (!isNonEmptyText(value)) {
    return null;
  }

  return value.trim();
}

function formatDateLabel(value: string | null | undefined): string | null {
  if (!isNonEmptyText(value)) {
    return null;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  const day = `${parsed.getUTCDate()}`.padStart(2, '0');
  const month = `${parsed.getUTCMonth() + 1}`.padStart(2, '0');
  const year = `${parsed.getUTCFullYear()}`;
  return `${day}/${month}/${year}`;
}

function formatDateTimeLabel(value: string | null | undefined): string | null {
  if (!isNonEmptyText(value)) {
    return null;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  const dateLabel = formatDateLabel(value);
  if (!dateLabel) {
    return null;
  }

  const hours = `${parsed.getUTCHours()}`.padStart(2, '0');
  const minutes = `${parsed.getUTCMinutes()}`.padStart(2, '0');
  return `${dateLabel} alle ${hours}:${minutes}`;
}

function buildLineupTitle(clubName: string): string {
  return `${clubName}: formazione pubblicata`;
}

function buildLineupBody(lineup: LineupRow): string {
  const parts = ['La nuova formazione'];

  if (isNonEmptyText(lineup.competition_name)) {
    parts.push(`per ${lineup.competition_name.trim()}`);
  }

  if (isNonEmptyText(lineup.opponent_name)) {
    parts.push(`contro ${lineup.opponent_name.trim()}`);
  }

  const dateLabel = formatDateTimeLabel(lineup.match_datetime);
  if (dateLabel) {
    parts.push(`del ${dateLabel}`);
  }

  parts.push("e disponibile nell'app.");

  return parts.join(' ');
}

function buildAttendanceTitle(clubName: string): string {
  return `${clubName}: presenze pubblicate`;
}

function buildAttendanceBody(week: AttendanceWeekRow): string {
  const startLabel = formatDateLabel(week.week_start);
  const endLabel = formatDateLabel(week.week_end);

  if (startLabel && endLabel) {
    return `E disponibile il nuovo sondaggio presenze della settimana dal ${startLabel} al ${endLabel}.`;
  }

  return "E disponibile un nuovo sondaggio presenze nell'app.";
}

export class ClubNotificationPublisherService {
  constructor(private readonly db: SupabaseClient) {}

  async publishLineupPublished(input: {
    clubId: string | number;
    clubName?: string | null;
    lineup: LineupRow;
  }): Promise<ClubNotificationPublishResult> {
    const clubName = await this.resolveClubName(input.clubId, input.clubName);

    return this.publishClubWideNotification({
      clubId: input.clubId,
      notificationType: 'lineup_published',
      title: buildLineupTitle(clubName),
      body: buildLineupBody(input.lineup),
      metadata: {
        redirect: {
          screen: 'lineups',
          path: '/lineups',
          entity: 'lineup',
          lineupId: input.lineup.id,
        },
        clubId: input.clubId,
        lineupId: input.lineup.id,
        matchDateTime: input.lineup.match_datetime,
        competitionName: input.lineup.competition_name,
        opponentName: input.lineup.opponent_name,
        formationModule: input.lineup.formation_module,
      },
      dedupeKey: `lineup_published:${input.lineup.id}`,
    });
  }

  async publishAttendancePublished(input: {
    clubId: string | number;
    clubName?: string | null;
    week: AttendanceWeekRow;
  }): Promise<ClubNotificationPublishResult> {
    const clubName = await this.resolveClubName(input.clubId, input.clubName);

    return this.publishClubWideNotification({
      clubId: input.clubId,
      notificationType: 'attendance_published',
      title: buildAttendanceTitle(clubName),
      body: buildAttendanceBody(input.week),
      metadata: {
        redirect: {
          screen: 'attendance',
          path: '/attendance',
          entity: 'attendance_week',
          attendanceWeekId: input.week.id,
        },
        clubId: input.clubId,
        attendanceWeekId: input.week.id,
        weekStart: input.week.week_start,
        weekEnd: input.week.week_end,
        selectedDates: input.week.selected_dates,
      },
      dedupeKey: `attendance_published:${input.week.id}`,
    });
  }

  private async publishClubWideNotification(input: {
    clubId: string | number;
    notificationType: AppNotificationType;
    title: string;
    body: string;
    metadata: Record<string, unknown>;
    dedupeKey: string;
  }): Promise<ClubNotificationPublishResult> {
    const recipientUserIds = await this.listActiveRecipientUserIds(input.clubId);
    const notificationIds: Array<string | number> = [];

    for (const recipientUserId of recipientUserIds) {
      const notificationId = await this.createNotification({
        recipientUserId,
        clubId: input.clubId,
        notificationType: input.notificationType,
        title: input.title,
        body: input.body,
        metadata: input.metadata,
        dedupeKey: input.dedupeKey,
      });
      notificationIds.push(notificationId);
    }

    return {
      recipientUserIds,
      notificationIds,
    };
  }

  private async listActiveRecipientUserIds(
    clubId: string | number,
  ): Promise<string[]> {
    const response = await this.db
      .from('memberships')
      .select('auth_user_id')
      .eq('club_id', clubId)
      .eq('status', 'active');

    const rows =
      ((optionalData(response) as Array<{ auth_user_id?: unknown }> | null) ?? []);
    const uniqueUserIds = new Set<string>();

    for (const row of rows) {
      const userId = normalizeUserId(row.auth_user_id);
      if (userId) {
        uniqueUserIds.add(userId);
      }
    }

    return [...uniqueUserIds];
  }

  private async resolveClubName(
    clubId: string | number,
    preferredClubName?: string | null,
  ): Promise<string> {
    if (isNonEmptyText(preferredClubName)) {
      return preferredClubName.trim();
    }

    const response = await this.db
      .from('clubs')
      .select('*')
      .eq('id', clubId)
      .maybeSingle();

    const club = optionalData(response) as ClubRow | null;
    if (club && isNonEmptyText(club.name)) {
      return club.name.trim();
    }

    return 'Clubline';
  }

  private async createNotification(input: {
    recipientUserId: string;
    clubId: string | number;
    notificationType: AppNotificationType;
    title: string;
    body: string;
    metadata: Record<string, unknown>;
    dedupeKey: string;
  }): Promise<string | number> {
    const rpcClient = this.db as RpcCapableClient;
    if (typeof rpcClient.rpc === 'function') {
      const result = await rpcClient.rpc('clubline_create_notification', {
        p_recipient_user_id: input.recipientUserId,
        p_club_id: input.clubId,
        p_notification_type: input.notificationType,
        p_title: input.title,
        p_body: input.body,
        p_metadata: input.metadata,
        p_related_invite_id: null,
        p_dedupe_key: input.dedupeKey,
      });

      return requiredData(result, 'Notifica non creata') as string | number;
    }

    return this.createNotificationFallback(input);
  }

  private async createNotificationFallback(input: {
    recipientUserId: string;
    clubId: string | number;
    notificationType: AppNotificationType;
    title: string;
    body: string;
    metadata: Record<string, unknown>;
    dedupeKey: string;
  }): Promise<string | number> {
    const existingResponse = await this.db
      .from('app_notifications')
      .select('*')
      .eq('recipient_user_id', input.recipientUserId)
      .eq('dedupe_key', input.dedupeKey)
      .maybeSingle();

    const existing = optionalData(existingResponse) as { id: string | number } | null;
    if (existing) {
      const updateResponse = await this.db
        .from('app_notifications')
        .update({
          club_id: input.clubId,
          notification_type: input.notificationType,
          title: input.title,
          body: input.body,
          metadata: input.metadata,
        })
        .eq('id', existing.id);
      ensureSuccess(updateResponse);
      return existing.id;
    }

    const insertResponse = await this.db
      .from('app_notifications')
      .insert({
        recipient_user_id: input.recipientUserId,
        club_id: input.clubId,
        notification_type: input.notificationType,
        title: input.title,
        body: input.body,
        metadata: input.metadata,
        related_invite_id: null,
        read_at: null,
        dedupe_key: input.dedupeKey,
      })
      .select('*')
      .single();

    const created = requiredData(insertResponse, 'Notifica non creata') as {
      id: string | number;
    };

    return created.id;
  }
}
