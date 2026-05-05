import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  ClubInviteListResultDto,
  ClubInviteRow,
  ClubInviteStatus,
  InviteCandidateDto,
  InviteCandidateReason,
  MembershipRow,
  PlayerProfileRow,
  RequestPrincipal,
} from '../domain/types';
import { mapDatabaseError } from '../lib/database-error';
import {
  ForbiddenError,
  NotFoundError,
  ServiceUnavailableError,
  ValidationError,
} from '../lib/errors';
import { optionalData, requiredData } from '../lib/supabase-result';
import { ClubWorkflowsRepository } from '../repositories/club-workflows.repository';
import { MembershipsRepository } from '../repositories/memberships.repository';
import { PlayerProfilesRepository } from '../repositories/player-profiles.repository';

export interface InviteListInput {
  status?: 'pending' | 'all';
  limit?: number;
  cursor?: number;
}

export interface InviteCandidatesInput {
  q: string;
  limit?: number;
}

export interface CreateInviteInput {
  targetUserId: string;
}

export interface InviteAcceptResultDto {
  invite: ClubInviteRow;
  membership: MembershipRow;
  player: PlayerProfileRow;
}

const inviteSelectColumns = `
  *,
  club:clubs(
    id,
    name,
    normalized_name,
    slug,
    logo_url,
    logo_storage_path,
    primary_color,
    accent_color,
    surface_color,
    created_by_user_id,
    created_at,
    updated_at
  )
`;

function normalizeSearchTerm(value: string): string {
  const normalized = value.trim().replaceAll(/\s+/g, ' ');
  if (normalized.length === 0) {
    throw new ValidationError('Inserisci almeno un termine di ricerca valido');
  }

  return normalized;
}

function normalizeListLimit(value: number | undefined): number {
  if (!Number.isFinite(value)) {
    return 20;
  }

  return Math.min(50, Math.max(1, Math.trunc(value!)));
}

function normalizeCandidatesLimit(value: number | undefined): number {
  if (!Number.isFinite(value)) {
    return 20;
  }

  return Math.min(20, Math.max(1, Math.trunc(value!)));
}

function parseTimestamp(value: string | null | undefined): number {
  if (!value) {
    return 0;
  }

  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function parseNumberLike(value: string | number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function isStandaloneProfile(player: {
  club_id: string | number | null;
  membership_id: string | number | null;
}): boolean {
  return player.club_id == null && player.membership_id == null;
}

function shouldReplaceCandidateProfile(
  current: CandidateProfileRow,
  next: CandidateProfileRow,
): boolean {
  const currentStandalone = isStandaloneProfile(current);
  const nextStandalone = isStandaloneProfile(next);
  if (currentStandalone !== nextStandalone) {
    return nextStandalone;
  }

  const createdCompare = parseTimestamp(next.created_at) - parseTimestamp(current.created_at);
  if (createdCompare !== 0) {
    return createdCompare > 0;
  }

  return parseNumberLike(next.id) > parseNumberLike(current.id);
}

type CandidateProfileRow = Pick<
  PlayerProfileRow,
  | 'id'
  | 'club_id'
  | 'membership_id'
  | 'nome'
  | 'cognome'
  | 'auth_user_id'
  | 'account_email'
  | 'primary_role'
  | 'id_console'
  | 'archived_at'
  | 'created_at'
>;

export class InvitesService {
  private readonly workflows: ClubWorkflowsRepository;
  private readonly memberships: MembershipsRepository;
  private readonly playerProfiles: PlayerProfilesRepository;

  constructor(private readonly db: SupabaseClient) {
    this.workflows = new ClubWorkflowsRepository(db);
    this.memberships = new MembershipsRepository(db);
    this.playerProfiles = new PlayerProfilesRepository(db);
  }

  async listCandidates(
    input: InviteCandidatesInput,
    principal: RequestPrincipal,
  ): Promise<InviteCandidateDto[]> {
    const clubId = this.requireManageInvites(principal);
    const limit = normalizeCandidatesLimit(input.limit);
    const search = normalizeSearchTerm(input.q);

    let query = this.db
      .from('player_profiles')
      .select(
        'id,club_id,membership_id,nome,cognome,auth_user_id,account_email,primary_role,id_console,archived_at,created_at',
      )
      .is('archived_at', null)
      .order('created_at', { ascending: false })
      .limit(Math.min(limit * 5, 100));

    const pattern = `%${search}%`;
    query = query.or(
      `nome.ilike.${pattern},cognome.ilike.${pattern},id_console.ilike.${pattern},account_email.ilike.${pattern}`,
    );

    const rows = ((optionalData(await query) as CandidateProfileRow[] | null) ?? []).filter(
      (row) => row.auth_user_id != null,
    );

    const profilesByUserId = new Map<string, CandidateProfileRow>();
    for (const row of rows) {
      const authUserId = row.auth_user_id;
      if (!authUserId) {
        continue;
      }

      const current = profilesByUserId.get(authUserId);
      if (!current || shouldReplaceCandidateProfile(current, row)) {
        profilesByUserId.set(authUserId, row);
      }
    }

    const userIds = [...profilesByUserId.keys()];
    if (userIds.length === 0) {
      return [];
    }

    const [activeMembershipRows, pendingInviteRows, pendingJoinRequestRows] = await Promise.all([
      this.db
        .from('memberships')
        .select('auth_user_id')
        .in('auth_user_id', userIds)
        .eq('status', 'active'),
      this.db
        .from('club_invites')
        .select('target_user_id')
        .eq('club_id', clubId)
        .eq('status', 'pending')
        .in('target_user_id', userIds),
      this.db
        .from('join_requests')
        .select('requester_user_id,club_id')
        .eq('status', 'pending')
        .in('requester_user_id', userIds),
    ]);

    const activeMembershipUserIds = new Set(
      (
        (optionalData(activeMembershipRows) as Array<{ auth_user_id: string }> | null) ?? []
      ).map((row) => row.auth_user_id),
    );
    const pendingInviteUserIds = new Set(
      (
        (optionalData(pendingInviteRows) as Array<{ target_user_id: string }> | null) ?? []
      ).map((row) => row.target_user_id),
    );
    const pendingJoinRequests = new Map<string, InviteCandidateReason>();
    for (const row of
      ((optionalData(pendingJoinRequestRows) as Array<{
        requester_user_id: string;
        club_id: string | number;
      }> | null) ?? [])) {
      pendingJoinRequests.set(
        row.requester_user_id,
        `${row.club_id}` === `${clubId}`
          ? 'pending_join_request_same_club'
          : 'pending_join_request_other_club',
      );
    }

    const candidates = [...profilesByUserId.values()]
      .filter((row) => !activeMembershipUserIds.has(row.auth_user_id!))
      .filter((row) => !pendingInviteUserIds.has(row.auth_user_id!))
      .map((row) => {
        const reason = pendingJoinRequests.get(row.auth_user_id!) ?? null;
        return {
          user_id: row.auth_user_id!,
          player_profile_id: row.id,
          nome: row.nome,
          cognome: row.cognome,
          account_email: row.account_email,
          id_console: row.id_console,
          primary_role: row.primary_role,
          invitable: reason == null,
          reason,
        } satisfies InviteCandidateDto;
      })
      .sort((left, right) => {
        if (left.invitable !== right.invitable) {
          return left.invitable ? -1 : 1;
        }

        const cognomeCompare = left.cognome.localeCompare(right.cognome, 'it');
        if (cognomeCompare !== 0) {
          return cognomeCompare;
        }

        return left.nome.localeCompare(right.nome, 'it');
      });

    return candidates.slice(0, limit);
  }

  async createInvite(
    input: CreateInviteInput,
    principal: RequestPrincipal,
  ): Promise<ClubInviteRow> {
    this.requireManageInvites(principal);
    this.ensureRpcAvailable('createInvite');

    try {
      const result = await this.workflows.createClubInvite({
        actorUserId: principal.authUser.id,
        targetUserId: input.targetUserId,
      });

      return this.getInviteById(result.inviteId);
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  async listSentInvites(
    input: InviteListInput,
    principal: RequestPrincipal,
  ): Promise<ClubInviteListResultDto> {
    const clubId = this.requireManageInvites(principal);
    return this.listInvites(
      this.db
        .from('club_invites')
        .select(inviteSelectColumns)
        .eq('club_id', clubId),
      input,
    );
  }

  async revokeInvite(
    inviteId: string | number,
    principal: RequestPrincipal,
  ): Promise<ClubInviteRow> {
    this.requireManageInvites(principal);
    this.ensureRpcAvailable('revokeInvite');

    try {
      const result = await this.workflows.revokeClubInvite({
        actorUserId: principal.authUser.id,
        inviteId,
      });
      return this.getInviteById(result.inviteId);
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  async listReceivedInvites(
    input: InviteListInput,
    principal: RequestPrincipal,
  ): Promise<ClubInviteListResultDto> {
    return this.listInvites(
      this.db
        .from('club_invites')
        .select(inviteSelectColumns)
        .eq('target_user_id', principal.authUser.id),
      input,
    );
  }

  async acceptInvite(
    inviteId: string | number,
    principal: RequestPrincipal,
  ): Promise<InviteAcceptResultDto> {
    this.ensureRpcAvailable('acceptInvite');

    try {
      const result = await this.workflows.acceptClubInvite({
        actorUserId: principal.authUser.id,
        inviteId,
      });

      const [invite, membership, player] = await Promise.all([
        this.getInviteById(result.inviteId),
        this.memberships.getById(result.membershipId),
        this.getPlayerById(result.playerId),
      ]);

      return {
        invite,
        membership,
        player,
      };
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  async declineInvite(
    inviteId: string | number,
    principal: RequestPrincipal,
  ): Promise<ClubInviteRow> {
    this.ensureRpcAvailable('declineInvite');

    try {
      const result = await this.workflows.declineClubInvite({
        actorUserId: principal.authUser.id,
        inviteId,
      });
      return this.getInviteById(result.inviteId);
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private requireManageInvites(principal: RequestPrincipal): string | number {
    const clubId = principal.membership?.club_id;
    if (!clubId) {
      throw new ForbiddenError('Devi appartenere a un club per gestire gli inviti');
    }
    if (!principal.canManageInvites) {
      throw new ForbiddenError('Non hai i permessi per gestire gli inviti del club');
    }

    return clubId;
  }

  private ensureRpcAvailable(operation: string): void {
    if (this.workflows.canUseRpc) {
      return;
    }

    throw new ServiceUnavailableError(
      `Il workflow hardened per ${operation} non e disponibile. Applica le RPC SQL di Clubline.`,
      'hardened_workflow_unavailable',
    );
  }

  private async listInvites(
    baseQuery: any,
    input: InviteListInput,
  ): Promise<ClubInviteListResultDto> {
    const limit = normalizeListLimit(input.limit);
    const status = input.status ?? 'pending';

    let query = baseQuery.order('id', { ascending: false }).limit(limit + 1);
    if (status === 'pending') {
      query = query.eq('status', 'pending');
    }
    if (input.cursor != null) {
      query = query.lt('id', input.cursor);
    }

    const rows = ((optionalData(await query) as ClubInviteRow[] | null) ?? []);
    const hasMore = rows.length > limit;
    const invites = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore ? `${invites[invites.length - 1]?.id ?? ''}` : null;

    return {
      invites,
      pagination: {
        limit,
        hasMore,
        nextCursor,
      },
    };
  }

  private async getInviteById(inviteId: string | number): Promise<ClubInviteRow> {
    const response = await this.db
      .from('club_invites')
      .select(inviteSelectColumns)
      .eq('id', inviteId)
      .maybeSingle();

    return requiredData(response, 'Invito non trovato') as ClubInviteRow;
  }

  private async getPlayerById(playerId: string | number): Promise<PlayerProfileRow> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('id', playerId)
      .is('archived_at', null)
      .maybeSingle();

    return requiredData(response, 'Giocatore non trovato') as PlayerProfileRow;
  }
}
