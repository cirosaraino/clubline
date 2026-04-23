import type { SupabaseClient } from '@supabase/supabase-js';

import { requiredData } from '../lib/supabase-result';

type RpcCapableClient = SupabaseClient & {
  rpc?: (
    fn: string,
    args?: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: Error | null }>;
};

function asObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }

  return {};
}

function requiredNumberLike(
  payload: Record<string, unknown>,
  key: string,
): string | number {
  const value = payload[key];
  if (typeof value === 'string' || typeof value === 'number') {
    return value;
  }

  throw new Error(`Campo RPC mancante: ${key}`);
}

export class ClubWorkflowsRepository {
  constructor(private readonly db: SupabaseClient) {}

  get canUseRpc(): boolean {
    return typeof (this.db as RpcCapableClient).rpc === 'function';
  }

  async createClub(input: {
    actorUserId: string;
    actorEmail: string | null;
    name: string;
    ownerNome: string;
    ownerCognome: string;
    ownerConsoleId: string;
    ownerShirtNumber?: number | null;
    ownerPrimaryRole?: string | null;
    primaryColor?: string | null;
    accentColor?: string | null;
    surfaceColor?: string | null;
  }): Promise<{
    clubId: string | number;
    membershipId: string | number;
    playerId: string | number;
  }> {
    const result = await (this.db as RpcCapableClient).rpc!(
      'clubline_create_club',
      {
        p_actor_user_id: input.actorUserId,
        p_actor_email: input.actorEmail,
        p_name: input.name,
        p_owner_nome: input.ownerNome,
        p_owner_cognome: input.ownerCognome,
        p_owner_id_console: input.ownerConsoleId,
        p_owner_shirt_number: input.ownerShirtNumber ?? null,
        p_owner_primary_role: input.ownerPrimaryRole ?? null,
        p_primary_color: input.primaryColor ?? null,
        p_accent_color: input.accentColor ?? null,
        p_surface_color: input.surfaceColor ?? null,
      },
    );
    const payload = asObject(requiredData(result) as unknown);

    return {
      clubId: requiredNumberLike(payload, 'club_id'),
      membershipId: requiredNumberLike(payload, 'membership_id'),
      playerId: requiredNumberLike(payload, 'player_id'),
    };
  }

  async requestJoinClub(input: {
    actorUserId: string;
    actorEmail: string | null;
    clubId: string | number;
    requestedNome?: string | null;
    requestedCognome?: string | null;
    requestedShirtNumber?: number | null;
    requestedPrimaryRole?: string | null;
  }): Promise<{ joinRequestId: string | number }> {
    const result = await (this.db as RpcCapableClient).rpc!(
      'clubline_request_join_club',
      {
        p_actor_user_id: input.actorUserId,
        p_actor_email: input.actorEmail,
        p_club_id: input.clubId,
        p_requested_nome: input.requestedNome ?? null,
        p_requested_cognome: input.requestedCognome ?? null,
        p_requested_shirt_number: input.requestedShirtNumber ?? null,
        p_requested_primary_role: input.requestedPrimaryRole ?? null,
      },
    );
    const payload = asObject(requiredData(result) as unknown);
    return {
      joinRequestId: requiredNumberLike(payload, 'join_request_id'),
    };
  }

  async approveJoinRequest(input: {
    actorUserId: string;
    joinRequestId: string | number;
  }): Promise<{ membershipId: string | number; playerId: string | number }> {
    const result = await (this.db as RpcCapableClient).rpc!(
      'clubline_approve_join_request',
      {
        p_actor_user_id: input.actorUserId,
        p_join_request_id: input.joinRequestId,
      },
    );
    const payload = asObject(requiredData(result) as unknown);
    return {
      membershipId: requiredNumberLike(payload, 'membership_id'),
      playerId: requiredNumberLike(payload, 'player_id'),
    };
  }

  async rejectJoinRequest(input: {
    actorUserId: string;
    joinRequestId: string | number;
  }): Promise<void> {
    const result = await (this.db as RpcCapableClient).rpc!(
      'clubline_reject_join_request',
      {
        p_actor_user_id: input.actorUserId,
        p_join_request_id: input.joinRequestId,
      },
    );
    requiredData(result);
  }

  async requestLeaveClub(input: {
    actorUserId: string;
  }): Promise<{ leaveRequestId: string | number }> {
    const result = await (this.db as RpcCapableClient).rpc!(
      'clubline_request_leave_club',
      {
        p_actor_user_id: input.actorUserId,
      },
    );
    const payload = asObject(requiredData(result) as unknown);
    return {
      leaveRequestId: requiredNumberLike(payload, 'leave_request_id'),
    };
  }

  async approveLeaveRequest(input: {
    actorUserId: string;
    leaveRequestId: string | number;
  }): Promise<void> {
    const result = await (this.db as RpcCapableClient).rpc!(
      'clubline_approve_leave_request',
      {
        p_actor_user_id: input.actorUserId,
        p_leave_request_id: input.leaveRequestId,
      },
    );
    requiredData(result);
  }

  async rejectLeaveRequest(input: {
    actorUserId: string;
    leaveRequestId: string | number;
  }): Promise<void> {
    const result = await (this.db as RpcCapableClient).rpc!(
      'clubline_reject_leave_request',
      {
        p_actor_user_id: input.actorUserId,
        p_leave_request_id: input.leaveRequestId,
      },
    );
    requiredData(result);
  }

  async transferCaptain(input: {
    actorUserId: string;
    targetMembershipId: string | number;
  }): Promise<void> {
    const result = await (this.db as RpcCapableClient).rpc!(
      'clubline_transfer_captain_role',
      {
        p_actor_user_id: input.actorUserId,
        p_target_membership_id: input.targetMembershipId,
      },
    );
    requiredData(result);
  }

  async deleteCurrentClub(input: { actorUserId: string }): Promise<void> {
    const result = await (this.db as RpcCapableClient).rpc!(
      'clubline_delete_club_if_valid',
      {
        p_actor_user_id: input.actorUserId,
      },
    );
    requiredData(result);
  }
}
