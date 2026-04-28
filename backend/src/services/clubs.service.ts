import type { SupabaseClient } from '@supabase/supabase-js';

import { env } from '../config/env';
import { inferNamesFromEmail } from '../domain/player-identity';
import type {
  ClubRow,
  JoinRequestRow,
  LeaveRequestRow,
  MembershipRow,
  RequestPrincipal,
  TeamRole,
} from '../domain/types';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ServiceUnavailableError,
  ValidationError,
} from '../lib/errors';
import { mapDatabaseError } from '../lib/database-error';
import { ensureSuccess, optionalData, requiredData } from '../lib/supabase-result';
import { ClubWorkflowsRepository } from '../repositories/club-workflows.repository';
import { MembershipsRepository } from '../repositories/memberships.repository';
import { PlayerProfilesRepository } from '../repositories/player-profiles.repository';
import {
  DEFAULT_CLUB_THEME,
  normalizeStoredClubLogoPath,
  removeClubLogoAsset,
  uploadClubLogoAsset,
} from './club-logo.service';
import { PlayerIdentityService } from './player-identity.service';

type ResolvedClubTheme = {
  primaryColor: string;
  accentColor: string;
  surfaceColor: string;
};

function normalizeText(value: string | null | undefined): string {
  return value?.trim() ?? '';
}

function normalizeOptionalText(value: string | null | undefined): string | null {
  const normalized = normalizeText(value);
  return normalized.length > 0 ? normalized : null;
}

function normalizeEmail(value: string | null | undefined): string | null {
  const normalized = normalizeText(value).toLowerCase();
  return normalized.length > 0 ? normalized : null;
}

function normalizeClubName(value: string): string {
  const normalized = value.trim().replaceAll(/\s+/g, ' ');
  if (normalized.length === 0) {
    throw new ValidationError('Inserisci un nome club valido');
  }

  return normalized;
}

function normalizeClubKey(value: string): string {
  return normalizeClubName(value).toLowerCase();
}

function normalizeClubSearchTerm(value: string | null | undefined): string | null {
  const normalized = normalizeText(value)
    .toLowerCase()
    .replaceAll(/[%,()]/g, ' ')
    .replaceAll(/\s+/g, ' ')
    .trim();
  return normalized.length > 0 ? normalized : null;
}

function slugifyClubName(value: string): string {
  const slug = normalizeClubName(value)
    .toLowerCase()
    .replaceAll(/[^a-z0-9]+/g, '-')
    .replaceAll(/-{2,}/g, '-')
    .replaceAll(/^-|-$/g, '');

  return slug.length === 0 ? 'club' : slug;
}

function normalizeHexColor(value: string | null | undefined): string | null {
  const normalized = normalizeText(value);
  if (normalized.length === 0) {
    return null;
  }

  const hex = normalized.startsWith('#') ? normalized : `#${normalized}`;
  if (!/^#[0-9a-fA-F]{6}$/.test(hex)) {
    throw new ValidationError('I colori del tema devono essere in formato esadecimale');
  }

  return hex.toUpperCase();
}

function resolveClubThemeColors(
  input: {
    primaryColor?: string | null;
    accentColor?: string | null;
    surfaceColor?: string | null;
  },
  fallback: Partial<ResolvedClubTheme> = DEFAULT_CLUB_THEME,
): ResolvedClubTheme {
  return {
    primaryColor:
      normalizeHexColor(input.primaryColor) ??
      fallback.primaryColor ??
      DEFAULT_CLUB_THEME.primaryColor,
    accentColor:
      normalizeHexColor(input.accentColor) ??
      fallback.accentColor ??
      DEFAULT_CLUB_THEME.accentColor,
    surfaceColor:
      normalizeHexColor(input.surfaceColor) ??
      fallback.surfaceColor ??
      DEFAULT_CLUB_THEME.surfaceColor,
  };
}

function ensureHasClub(principal: RequestPrincipal): MembershipRow {
  if (!principal.membership || !principal.club) {
    throw new ForbiddenError('Devi appartenere a un club per eseguire questa operazione');
  }

  return principal.membership;
}

function ensureCaptain(principal: RequestPrincipal): MembershipRow {
  const membership = ensureHasClub(principal);
  if (!principal.isCaptain) {
    throw new ForbiddenError('Solo il capitano puo eseguire questa operazione');
  }

  return membership;
}

export interface CreateClubInput {
  name: string;
  logo_data_url?: string | null;
  owner_nome?: string | null;
  owner_cognome?: string | null;
  owner_id_console?: string | null;
  owner_shirt_number?: number | null;
  owner_primary_role?: string | null;
  primary_color?: string | null;
  accent_color?: string | null;
  surface_color?: string | null;
}

export interface JoinClubRequestInput {
  club_id: number | string;
  requested_nome?: string | null;
  requested_cognome?: string | null;
  requested_shirt_number?: number | null;
  requested_primary_role?: string | null;
}

export interface UpdateClubLogoInput {
  logo_data_url: string;
  primary_color?: string | null;
  accent_color?: string | null;
  surface_color?: string | null;
}

export interface ListClubsInput {
  search?: string;
  page?: number;
  limit?: number;
}

export interface ClubListItemRow
  extends Pick<
    ClubRow,
    | 'id'
    | 'name'
    | 'slug'
    | 'logo_url'
    | 'logo_storage_path'
    | 'primary_color'
    | 'accent_color'
    | 'surface_color'
  > {}

export interface ClubListResult {
  clubs: ClubListItemRow[];
  pagination: {
    page: number;
    limit: number;
    hasMore: boolean;
    nextPage: number | null;
    query: string | null;
  };
}

export class ClubsService {
  private readonly workflows: ClubWorkflowsRepository;
  private readonly memberships: MembershipsRepository;
  private readonly playerProfiles: PlayerProfilesRepository;
  private readonly playerIdentity: PlayerIdentityService;

  constructor(private readonly db: SupabaseClient) {
    this.workflows = new ClubWorkflowsRepository(db);
    this.memberships = new MembershipsRepository(db);
    this.playerProfiles = new PlayerProfilesRepository(db);
    this.playerIdentity = new PlayerIdentityService(db);
  }

  async listClubs({ search, page = 1, limit = 20 }: ListClubsInput = {}): Promise<ClubListResult> {
    const safePage = Number.isFinite(page) ? Math.max(1, Math.trunc(page)) : 1;
    const safeLimit = Number.isFinite(limit)
      ? Math.min(50, Math.max(1, Math.trunc(limit)))
      : 20;
    const start = (safePage - 1) * safeLimit;
    const end = start + safeLimit;

    let query = this.db
      .from('clubs')
      .select(
        'id,name,slug,logo_url,logo_storage_path,primary_color,accent_color,surface_color',
      )
      .order('normalized_name', { ascending: true })
      .range(start, end);

    const normalizedSearch = normalizeClubSearchTerm(search);
    if (normalizedSearch != null) {
      const namePrefixPattern = `${normalizedSearch}%`;
      const slugPrefixPattern = `${normalizedSearch.replaceAll(' ', '-')}%`;
      query = query.or(
        `normalized_name.like.${namePrefixPattern},slug.like.${slugPrefixPattern}`,
      );
    }

    const response = await query;
    const rawClubs = ((optionalData(response) as ClubListItemRow[] | null) ?? []);
    const hasMore = rawClubs.length > safeLimit;

    return {
      clubs: hasMore ? rawClubs.slice(0, safeLimit) : rawClubs,
      pagination: {
        page: safePage,
        limit: safeLimit,
        hasMore,
        nextPage: hasMore ? safePage + 1 : null,
        query: normalizedSearch,
      },
    };
  }

  async createClub(input: CreateClubInput, principal: RequestPrincipal): Promise<{
    club: ClubRow;
    membership: MembershipRow;
  }> {
    await this.ensureVerifiedUser(principal);
    this.ensureWorkflowExecutionPath('createClub');
    if (this.workflows.canUseRpc) {
      try {
        return await this.createClubViaRpc(input, principal);
      } catch (error) {
        if (!this.shouldFallbackToLegacyWorkflow(error, 'createClub')) {
          throw error;
        }
      }
    }
    await this.ensureNoActiveMembership(principal.authUser.id);
    await this.ensureNoPendingJoinRequest(principal.authUser.id);

    const clubName = normalizeClubName(input.name);
    const ownerNome = normalizeOptionalText(input.owner_nome);
    const ownerCognome = normalizeOptionalText(input.owner_cognome);
    const ownerConsoleId = normalizeOptionalText(input.owner_id_console);
    if (!ownerNome || !ownerCognome || !ownerConsoleId) {
      throw new ValidationError('Inserisci nome, cognome e ID console del capitano');
    }

    const normalizedName = normalizeClubKey(clubName);
    await this.ensureUniqueClubName(normalizedName);

    const slug = await this.generateUniqueSlug(clubName);
    const initialTheme = resolveClubThemeColors({
      primaryColor: input.primary_color,
      accentColor: input.accent_color,
      surfaceColor: input.surface_color,
    });

    const clubInsertResponse = await this.db
      .from('clubs')
      .insert({
        name: clubName,
        normalized_name: normalizedName,
        slug,
        primary_color: initialTheme.primaryColor,
        accent_color: initialTheme.accentColor,
        surface_color: initialTheme.surfaceColor,
        created_by_user_id: principal.authUser.id,
      })
      .select('*')
      .single();

    const club = requiredData(clubInsertResponse) as ClubRow;
    try {
      const settingsResponse = await this.db
        .from('club_settings')
        .upsert(
          {
            club_id: club.id,
            additional_links: [],
          },
          { onConflict: 'club_id' },
        );
      ensureSuccess(settingsResponse);

      const permissionsResponse = await this.db
        .from('club_permission_settings')
        .upsert(
          {
            club_id: club.id,
            vice_manage_players: false,
            vice_manage_lineups: false,
            vice_manage_streams: false,
            vice_manage_attendance: false,
            vice_manage_team_info: false,
          },
          { onConflict: 'club_id' },
        );
      ensureSuccess(permissionsResponse);

      const membership = await this.memberships.create({
        club_id: club.id,
        auth_user_id: principal.authUser.id,
        role: 'captain',
        status: 'active',
      });
      await this.ensurePlayerProfileForMembership({
        membership,
        email: principal.authUser.email,
        nome: ownerNome,
        cognome: ownerCognome,
        consoleId: ownerConsoleId,
        shirtNumber: input.owner_shirt_number,
        primaryRole: input.owner_primary_role,
        teamRole: 'captain',
      });

      let currentClub = club;
      if (normalizeOptionalText(input.logo_data_url) != null) {
        currentClub = await this.updateClubLogoForClub(
          club.id,
          {
            logo_data_url: normalizeOptionalText(input.logo_data_url)!,
            primary_color: input.primary_color,
            accent_color: input.accent_color,
            surface_color: input.surface_color,
          },
        );
      }

      return {
        club: currentClub,
        membership,
      };
    } catch (error) {
      await this.db.from('clubs').delete().eq('id', club.id);
      throw error;
    }
  }

  async getCurrentClub(principal: RequestPrincipal): Promise<ClubRow | null> {
    return principal.club;
  }

  async getCurrentMembership(principal: RequestPrincipal): Promise<MembershipRow | null> {
    return principal.membership;
  }

  async getCurrentPendingJoinRequest(authUserId: string): Promise<JoinRequestRow | null> {
    const response = await this.db
      .from('join_requests')
      .select('*, club:clubs(*)')
      .eq('requester_user_id', authUserId)
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    return optionalData(response) as JoinRequestRow | null;
  }

  async getCurrentPendingLeaveRequest(
    membershipId: string | number,
  ): Promise<LeaveRequestRow | null> {
    const response = await this.db
      .from('leave_requests')
      .select('*')
      .eq('membership_id', membershipId)
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    return optionalData(response) as LeaveRequestRow | null;
  }

  async requestJoinClub(
    input: JoinClubRequestInput,
    principal: RequestPrincipal,
  ): Promise<JoinRequestRow> {
    await this.ensureVerifiedUser(principal);
    this.ensureWorkflowExecutionPath('requestJoinClub');
    if (this.workflows.canUseRpc) {
      try {
        return await this.requestJoinClubViaRpc(input, principal);
      } catch (error) {
        if (!this.shouldFallbackToLegacyWorkflow(error, 'requestJoinClub')) {
          throw error;
        }
      }
    }
    await this.ensureNoActiveMembership(principal.authUser.id);
    await this.ensureNoPendingJoinRequest(principal.authUser.id);

    const club = await this.getClubById(input.club_id);
    const fallbackNames = inferNamesFromEmail(principal.authUser.email);
    const response = await this.db
      .from('join_requests')
      .insert({
        club_id: club.id,
        requester_user_id: principal.authUser.id,
        requester_email: normalizeEmail(principal.authUser.email),
        requested_nome: normalizeOptionalText(input.requested_nome) ?? fallbackNames.nome,
        requested_cognome: normalizeOptionalText(input.requested_cognome) ?? fallbackNames.cognome,
        requested_shirt_number: input.requested_shirt_number ?? null,
        requested_primary_role: normalizeOptionalText(input.requested_primary_role),
        status: 'pending',
      })
      .select('*, club:clubs(*)')
      .single();

    return requiredData(response) as JoinRequestRow;
  }

  async cancelJoinRequest(
    joinRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    const response = await this.db
      .from('join_requests')
      .update({
        status: 'cancelled',
        cancelled_at: new Date().toISOString(),
      })
      .eq('id', joinRequestId)
      .eq('requester_user_id', principal.authUser.id)
      .eq('status', 'pending');

    ensureSuccess(response);
  }

  async listPendingJoinRequests(principal: RequestPrincipal): Promise<JoinRequestRow[]> {
    const membership = ensureCaptain(principal);
    const response = await this.db
      .from('join_requests')
      .select('*, club:clubs(*)')
      .eq('club_id', membership.club_id)
      .eq('status', 'pending')
      .order('created_at', { ascending: true });

    return ((optionalData(response) as JoinRequestRow[] | null) ?? []);
  }

  async approveJoinRequest(
    joinRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<MembershipRow> {
    this.ensureWorkflowExecutionPath('approveJoinRequest');
    if (this.workflows.canUseRpc) {
      try {
        return await this.approveJoinRequestViaRpc(joinRequestId, principal);
      } catch (error) {
        if (!this.shouldFallbackToLegacyWorkflow(error, 'approveJoinRequest')) {
          throw error;
        }
      }
    }
    const captainMembership = ensureCaptain(principal);
    const joinRequest = await this.getJoinRequest(joinRequestId);
    if (`${joinRequest.club_id}` != `${captainMembership.club_id}`) {
      throw new ForbiddenError('Non puoi approvare richieste di un altro club');
    }
    if (joinRequest.status != 'pending') {
      throw new ConflictError('Questa richiesta di ingresso e gia stata gestita');
    }

    const activeMembership = await this.findActiveMembership(joinRequest.requester_user_id);
    if (activeMembership) {
      throw new ConflictError('L utente appartiene gia a un club');
    }

    const membership = await this.memberships.create({
      club_id: joinRequest.club_id,
      auth_user_id: joinRequest.requester_user_id,
      role: 'player',
      status: 'active',
    });

    try {
      await this.ensurePlayerProfileForMembership({
        membership,
        email: joinRequest.requester_email,
        nome: joinRequest.requested_nome,
        cognome: joinRequest.requested_cognome,
        shirtNumber: joinRequest.requested_shirt_number,
        primaryRole: joinRequest.requested_primary_role,
        teamRole: 'player',
      });

      const updateResponse = await this.db
        .from('join_requests')
        .update({
          status: 'approved',
          decided_by_membership_id: captainMembership.id,
          decided_at: new Date().toISOString(),
        })
        .eq('id', joinRequest.id)
        .eq('status', 'pending')
        .select('*')
        .single();
      requiredData(updateResponse, 'Richiesta di ingresso non aggiornata');

      return membership;
    } catch (error) {
      await this.memberships.deleteById(membership.id);
      throw error;
    }
  }

  async rejectJoinRequest(
    joinRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    this.ensureWorkflowExecutionPath('rejectJoinRequest');
    if (this.workflows.canUseRpc) {
      try {
        await this.rejectJoinRequestViaRpc(joinRequestId, principal);
        return;
      } catch (error) {
        if (!this.shouldFallbackToLegacyWorkflow(error, 'rejectJoinRequest')) {
          throw error;
        }
      }
    }
    const captainMembership = ensureCaptain(principal);
    const joinRequest = await this.getJoinRequest(joinRequestId);
    if (`${joinRequest.club_id}` != `${captainMembership.club_id}`) {
      throw new ForbiddenError('Non puoi rifiutare richieste di un altro club');
    }
    if (joinRequest.status != 'pending') {
      throw new ConflictError('Questa richiesta di ingresso e gia stata gestita');
    }

    const response = await this.db
      .from('join_requests')
      .update({
        status: 'rejected',
        decided_by_membership_id: captainMembership.id,
        decided_at: new Date().toISOString(),
      })
      .eq('id', joinRequest.id)
      .eq('status', 'pending');

    ensureSuccess(response);
  }

  async requestLeaveClub(principal: RequestPrincipal): Promise<LeaveRequestRow> {
    this.ensureWorkflowExecutionPath('requestLeaveClub');
    if (this.workflows.canUseRpc) {
      try {
        return await this.requestLeaveClubViaRpc(principal);
      } catch (error) {
        if (!this.shouldFallbackToLegacyWorkflow(error, 'requestLeaveClub')) {
          throw error;
        }
      }
    }
    const membership = ensureHasClub(principal);
    if (principal.isCaptain) {
      const membersCount = await this.countActiveMembers(membership.club_id);
      if (membersCount > 1) {
        throw new ConflictError(
          'Trasferisci prima il ruolo di capitano a un altro membro, poi potrai chiedere l uscita.',
        );
      }

      throw new ConflictError(
        'Se sei l unico membro del club puoi eliminarlo direttamente, invece di aprire una leave request.',
      );
    }

    const pending = await this.getCurrentPendingLeaveRequest(membership.id);
    if (pending) {
      throw new ConflictError('Esiste gia una richiesta di uscita pendente');
    }

    const response = await this.db
      .from('leave_requests')
      .insert({
        club_id: membership.club_id,
        membership_id: membership.id,
        requested_by_user_id: principal.authUser.id,
        status: 'pending',
      })
      .select('*')
      .single();

    return requiredData(response) as LeaveRequestRow;
  }

  async cancelLeaveRequest(
    leaveRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    const membership = ensureHasClub(principal);
    const response = await this.db
      .from('leave_requests')
      .update({
        status: 'cancelled',
        cancelled_at: new Date().toISOString(),
      })
      .eq('id', leaveRequestId)
      .eq('membership_id', membership.id)
      .eq('status', 'pending');

    ensureSuccess(response);
  }

  async listPendingLeaveRequests(principal: RequestPrincipal): Promise<LeaveRequestRow[]> {
    const captainMembership = ensureCaptain(principal);
    const response = await this.db
      .from('leave_requests')
      .select('*, membership:memberships!leave_requests_membership_id_fkey(*)')
      .eq('club_id', captainMembership.club_id)
      .eq('status', 'pending')
      .order('created_at', { ascending: true });

    return ((optionalData(response) as LeaveRequestRow[] | null) ?? []);
  }

  async approveLeaveRequest(
    leaveRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    this.ensureWorkflowExecutionPath('approveLeaveRequest');
    if (this.workflows.canUseRpc) {
      try {
        await this.approveLeaveRequestViaRpc(leaveRequestId, principal);
        return;
      } catch (error) {
        if (!this.shouldFallbackToLegacyWorkflow(error, 'approveLeaveRequest')) {
          throw error;
        }
      }
    }
    const captainMembership = ensureCaptain(principal);
    const leaveRequest = await this.getLeaveRequest(leaveRequestId);
    if (`${leaveRequest.club_id}` != `${captainMembership.club_id}`) {
      throw new ForbiddenError('Non puoi approvare richieste di uscita di un altro club');
    }
    if (leaveRequest.status != 'pending') {
      throw new ConflictError('Questa richiesta di uscita e gia stata gestita');
    }

    const targetMembership = await this.getMembershipById(leaveRequest.membership_id);
    if (targetMembership.role == 'captain') {
      throw new ConflictError('Il capitano deve prima trasferire il ruolo prima di uscire');
    }

    const now = new Date().toISOString();
    const updateLeaveResponse = await this.db
      .from('leave_requests')
      .update({
        status: 'approved',
        decided_by_membership_id: captainMembership.id,
        decided_at: now,
      })
      .eq('id', leaveRequest.id)
      .eq('status', 'pending');
    ensureSuccess(updateLeaveResponse);

    await this.finalizeMembershipLeave(targetMembership.id, now);
  }

  async rejectLeaveRequest(
    leaveRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    this.ensureWorkflowExecutionPath('rejectLeaveRequest');
    if (this.workflows.canUseRpc) {
      try {
        await this.rejectLeaveRequestViaRpc(leaveRequestId, principal);
        return;
      } catch (error) {
        if (!this.shouldFallbackToLegacyWorkflow(error, 'rejectLeaveRequest')) {
          throw error;
        }
      }
    }
    const captainMembership = ensureCaptain(principal);
    const leaveRequest = await this.getLeaveRequest(leaveRequestId);
    if (`${leaveRequest.club_id}` != `${captainMembership.club_id}`) {
      throw new ForbiddenError('Non puoi rifiutare richieste di uscita di un altro club');
    }
    if (leaveRequest.status != 'pending') {
      throw new ConflictError('Questa richiesta di uscita e gia stata gestita');
    }

    const response = await this.db
      .from('leave_requests')
      .update({
        status: 'rejected',
        decided_by_membership_id: captainMembership.id,
        decided_at: new Date().toISOString(),
      })
      .eq('id', leaveRequest.id)
      .eq('status', 'pending');

    ensureSuccess(response);
  }

  async transferCaptain(
    targetMembershipId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    this.ensureWorkflowExecutionPath('transferCaptain');
    if (this.workflows.canUseRpc) {
      try {
        await this.transferCaptainViaRpc(targetMembershipId, principal);
        return;
      } catch (error) {
        if (!this.shouldFallbackToLegacyWorkflow(error, 'transferCaptain')) {
          throw error;
        }
      }
    }
    const captainMembership = ensureCaptain(principal);
    if (`${captainMembership.id}` == `${targetMembershipId}`) {
      throw new ConflictError('Seleziona un altro membro per il trasferimento del ruolo');
    }

    const targetMembership = await this.getMembershipById(targetMembershipId);
    if (`${targetMembership.club_id}` != `${captainMembership.club_id}` || targetMembership.status != 'active') {
      throw new ForbiddenError('Il nuovo capitano deve essere un membro attivo dello stesso club');
    }

    await this.memberships.updateRole(captainMembership.id, 'player');
    await this.memberships.updateRole(targetMembership.id, 'captain');

    await this.syncPlayerRoleForMembership(captainMembership.id, 'player');
    await this.syncPlayerRoleForMembership(targetMembership.id, 'captain');
  }

  async updateCurrentClubLogo(
    input: UpdateClubLogoInput,
    principal: RequestPrincipal,
  ): Promise<ClubRow> {
    const membership = ensureHasClub(principal);
    if (!principal.canManageClubInfo) {
      throw new ForbiddenError('Non hai i permessi per aggiornare il logo del club');
    }

    return this.updateClubLogoForClub(membership.club_id, input);
  }

  async deleteCurrentClub(principal: RequestPrincipal): Promise<void> {
    this.ensureWorkflowExecutionPath('deleteCurrentClub');
    if (this.workflows.canUseRpc) {
      try {
        await this.deleteCurrentClubViaRpc(principal);
        return;
      } catch (error) {
        if (!this.shouldFallbackToLegacyWorkflow(error, 'deleteCurrentClub')) {
          throw error;
        }
      }
    }
    const membership = ensureCaptain(principal);
    const membersCount = await this.countActiveMembers(membership.club_id);
    if (membersCount != 1) {
      throw new ConflictError(
        'Puoi eliminare il club solo quando sei l unico membro attivo rimasto',
      );
    }

    const response = await this.db
      .from('clubs')
      .delete()
      .eq('id', membership.club_id);
    ensureSuccess(response);
  }

  private async updateClubLogoForClub(
    clubId: string | number,
    input: UpdateClubLogoInput,
  ): Promise<ClubRow> {
    const currentClub = await this.getClubById(clubId);
    const previousStoragePath = normalizeStoredClubLogoPath(
      currentClub.logo_storage_path,
    );
    const nextTheme = resolveClubThemeColors(
      {
        primaryColor: input.primary_color,
        accentColor: input.accent_color,
        surfaceColor: input.surface_color,
      },
      DEFAULT_CLUB_THEME,
    );

    const uploadedLogo = await uploadClubLogoAsset(
      this.db,
      clubId,
      input.logo_data_url,
    );

    try {
      const response = await this.db
        .from('clubs')
        .update({
          logo_url: uploadedLogo.publicUrl,
          logo_storage_path: uploadedLogo.storagePath,
          primary_color: nextTheme.primaryColor,
          accent_color: nextTheme.accentColor,
          surface_color: nextTheme.surfaceColor,
        })
        .eq('id', clubId)
        .select('*')
        .single();

      const updatedClub = requiredData(response) as ClubRow;
      if (
        previousStoragePath != null &&
        previousStoragePath != uploadedLogo.storagePath
      ) {
        try {
          await removeClubLogoAsset(this.db, previousStoragePath);
        } catch {
          // Best effort cleanup for old assets after a successful update.
        }
      }

      return updatedClub;
    } catch (error) {
      try {
        await removeClubLogoAsset(this.db, uploadedLogo.storagePath);
      } catch {
        // Best effort cleanup for failed writes.
      }
      throw error;
    }
  }

  private async createClubViaRpc(
    input: CreateClubInput,
    principal: RequestPrincipal,
  ): Promise<{
    club: ClubRow;
    membership: MembershipRow;
  }> {
    const ownerNome = normalizeOptionalText(input.owner_nome);
    const ownerCognome = normalizeOptionalText(input.owner_cognome);
    const ownerConsoleId = normalizeOptionalText(input.owner_id_console);
    if (!ownerNome || !ownerCognome || !ownerConsoleId) {
      throw new ValidationError('Inserisci nome, cognome e ID console del capitano');
    }

    try {
      const result = await this.workflows.createClub({
        actorUserId: principal.authUser.id,
        actorEmail: principal.authUser.email,
        name: normalizeClubName(input.name),
        ownerNome,
        ownerCognome,
        ownerConsoleId,
        ownerShirtNumber: input.owner_shirt_number,
        ownerPrimaryRole: input.owner_primary_role,
        primaryColor: normalizeHexColor(input.primary_color),
        accentColor: normalizeHexColor(input.accent_color),
        surfaceColor: normalizeHexColor(input.surface_color),
      });

      let club = await this.getClubById(result.clubId);
      const membership = await this.getMembershipById(result.membershipId);

      if (normalizeOptionalText(input.logo_data_url) != null) {
        try {
          club = await this.updateClubLogoForClub(club.id, {
            logo_data_url: normalizeOptionalText(input.logo_data_url)!,
            primary_color: input.primary_color,
            accent_color: input.accent_color,
            surface_color: input.surface_color,
          });
        } catch (error) {
          await this.workflows.deleteCurrentClub({
            actorUserId: principal.authUser.id,
          });
          throw error;
        }
      }

      return { club, membership };
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private async requestJoinClubViaRpc(
    input: JoinClubRequestInput,
    principal: RequestPrincipal,
  ): Promise<JoinRequestRow> {
    try {
      const result = await this.workflows.requestJoinClub({
        actorUserId: principal.authUser.id,
        actorEmail: principal.authUser.email,
        clubId: input.club_id,
        requestedNome: normalizeOptionalText(input.requested_nome),
        requestedCognome: normalizeOptionalText(input.requested_cognome),
        requestedShirtNumber: input.requested_shirt_number,
        requestedPrimaryRole: normalizeOptionalText(input.requested_primary_role),
      });
      return this.getJoinRequest(result.joinRequestId);
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private async approveJoinRequestViaRpc(
    joinRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<MembershipRow> {
    ensureCaptain(principal);
    try {
      const result = await this.workflows.approveJoinRequest({
        actorUserId: principal.authUser.id,
        joinRequestId,
      });
      return this.getMembershipById(result.membershipId);
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private async rejectJoinRequestViaRpc(
    joinRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    ensureCaptain(principal);
    try {
      await this.workflows.rejectJoinRequest({
        actorUserId: principal.authUser.id,
        joinRequestId,
      });
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private async requestLeaveClubViaRpc(
    principal: RequestPrincipal,
  ): Promise<LeaveRequestRow> {
    ensureHasClub(principal);
    try {
      const result = await this.workflows.requestLeaveClub({
        actorUserId: principal.authUser.id,
      });
      return this.getLeaveRequest(result.leaveRequestId);
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private async approveLeaveRequestViaRpc(
    leaveRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    ensureCaptain(principal);
    try {
      await this.workflows.approveLeaveRequest({
        actorUserId: principal.authUser.id,
        leaveRequestId,
      });
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private async rejectLeaveRequestViaRpc(
    leaveRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    ensureCaptain(principal);
    try {
      await this.workflows.rejectLeaveRequest({
        actorUserId: principal.authUser.id,
        leaveRequestId,
      });
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private async transferCaptainViaRpc(
    targetMembershipId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    ensureCaptain(principal);
    try {
      await this.workflows.transferCaptain({
        actorUserId: principal.authUser.id,
        targetMembershipId,
      });
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private async deleteCurrentClubViaRpc(principal: RequestPrincipal): Promise<void> {
    ensureCaptain(principal);
    try {
      await this.workflows.deleteCurrentClub({
        actorUserId: principal.authUser.id,
      });
    } catch (error) {
      throw mapDatabaseError(error);
    }
  }

  private ensureWorkflowExecutionPath(operation: string): void {
    if (this.workflows.canUseRpc || env.ENABLE_LEGACY_WORKFLOW_FALLBACK) {
      return;
    }

    throw new ServiceUnavailableError(
      `Il workflow hardened per ${operation} non e disponibile. Applica le RPC SQL di Clubline oppure abilita il fallback legacy solo in sviluppo controllato.`,
      'hardened_workflow_unavailable',
      {
        operation,
        reason: 'rpc_transport_unavailable',
      },
    );
  }

  private shouldFallbackToLegacyWorkflow(error: unknown, operation: string): boolean {
    const message = error instanceof Error ? error.message.toLowerCase() : '';
    const code = (error as { code?: string })?.code;
    const isMissingWorkflow =
      code === '42883' ||
      message.includes('does not exist') ||
      message.includes('could not find the function public.clubline_') ||
      message.includes('function public.clubline_');

    if (!isMissingWorkflow) {
      return false;
    }

    if (!env.ENABLE_LEGACY_WORKFLOW_FALLBACK) {
      throw new ServiceUnavailableError(
        `Il workflow hardened per ${operation} non e installato sul database. Applica lo schema SQL aggiornato prima di eseguire questo flusso in ambienti non legacy.`,
        'hardened_workflow_unavailable',
        {
          operation,
          reason: 'rpc_function_missing',
        },
      );
    }

    return true;
  }

  private async ensureVerifiedUser(principal: RequestPrincipal): Promise<void> {
    if (!principal.authUser.emailVerified) {
      throw new ForbiddenError('Conferma il tuo indirizzo email prima di usare i flussi protetti');
    }
  }

  private async ensureNoActiveMembership(authUserId: string): Promise<void> {
    const activeMembership = await this.findActiveMembership(authUserId);
    if (activeMembership) {
      throw new ConflictError('Appartieni gia a un club attivo');
    }
  }

  private async ensureNoPendingJoinRequest(authUserId: string): Promise<void> {
    const existingRequest = await this.getCurrentPendingJoinRequest(authUserId);
    if (existingRequest) {
      throw new ConflictError('Hai gia una richiesta di ingresso pendente');
    }
  }

  private async ensureUniqueClubName(normalizedName: string): Promise<void> {
    const response = await this.db
      .from('clubs')
      .select('id')
      .eq('normalized_name', normalizedName)
      .limit(1)
      .maybeSingle();

    if (optionalData(response) != null) {
      throw new ConflictError('Esiste gia un club con questo nome');
    }
  }

  private async generateUniqueSlug(name: string): Promise<string> {
    const baseSlug = slugifyClubName(name);
    const response = await this.db
      .from('clubs')
      .select('slug')
      .or(`slug.eq.${baseSlug},slug.like.${baseSlug}-%`);

    const existingSlugs = new Set(
      ((optionalData(response) as Array<{ slug?: string }> | null) ?? [])
        .map((row) => row.slug?.trim())
        .filter((value): value is string => Boolean(value)),
    );

    if (!existingSlugs.has(baseSlug)) {
      return baseSlug;
    }

    var suffix = 2;
    while (existingSlugs.has(`${baseSlug}-${suffix}`)) {
      suffix += 1;
    }

    return `${baseSlug}-${suffix}`;
  }

  private async ensurePlayerProfileForMembership(options: {
    membership: MembershipRow;
    email: string | null;
    nome?: string | null;
    cognome?: string | null;
    consoleId?: string | null;
    shirtNumber?: number | null;
    primaryRole?: string | null;
    teamRole: TeamRole;
  }): Promise<void> {
    await this.playerIdentity.ensureProfileForMembership({
      membership: options.membership,
      email: options.email,
      nome: options.nome,
      cognome: options.cognome,
      consoleId: options.consoleId,
      shirtNumber: options.shirtNumber,
      primaryRole: options.primaryRole,
      teamRole: options.teamRole,
    });
  }

  private async syncPlayerRoleForMembership(
    membershipId: string | number,
    role: TeamRole,
  ): Promise<void> {
    const profile = await this.playerProfiles.findActiveByMembershipId(membershipId);
    if (!profile) {
      return;
    }

    await this.playerProfiles.updateById(profile.id, { team_role: role });
  }

  private async getClubById(clubId: string | number): Promise<ClubRow> {
    const response = await this.db
      .from('clubs')
      .select('*')
      .eq('id', clubId)
      .maybeSingle();

    return requiredData(response, 'Club non trovato') as ClubRow;
  }

  private async findActiveMembership(authUserId: string): Promise<MembershipRow | null> {
    const activeMemberships = await this.memberships.listActiveByAuthUserId(authUserId);
    if (activeMemberships.length === 0) {
      return null;
    }

    const stillActiveMemberships: MembershipRow[] = [];
    for (const membership of activeMemberships) {
      const approvedLeave = await this.getLatestApprovedLeaveForMembership(
        membership.id,
      );
      if (approvedLeave != null) {
        await this.finalizeMembershipLeave(
          membership.id,
          approvedLeave.decided_at ?? approvedLeave.created_at ?? new Date().toISOString(),
        );
        continue;
      }

      stillActiveMemberships.push(membership);
    }

    if (stillActiveMemberships.length === 0) {
      return null;
    }

    if (stillActiveMemberships.length > 1) {
      throw new ConflictError(
        'Sono presenti piu membership attive per questo utente',
      );
    }

    return stillActiveMemberships[0] ?? null;
  }

  private async getLatestApprovedLeaveForMembership(
    membershipId: string | number,
  ): Promise<LeaveRequestRow | null> {
    const response = await this.db
      .from('leave_requests')
      .select('*')
      .eq('membership_id', membershipId)
      .eq('status', 'approved')
      .order('decided_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    return optionalData(response) as LeaveRequestRow | null;
  }

  private async finalizeMembershipLeave(
    membershipId: string | number,
    leftAt: string,
  ): Promise<void> {
    await this.playerIdentity.detachMembershipProfile(membershipId, leftAt);
  }

  private async getMembershipById(membershipId: string | number): Promise<MembershipRow> {
    return this.memberships.getById(membershipId);
  }

  private async getJoinRequest(joinRequestId: string | number): Promise<JoinRequestRow> {
    const response = await this.db
      .from('join_requests')
      .select('*, club:clubs(*)')
      .eq('id', joinRequestId)
      .maybeSingle();

    return requiredData(response, 'Richiesta di ingresso non trovata') as JoinRequestRow;
  }

  private async getLeaveRequest(leaveRequestId: string | number): Promise<LeaveRequestRow> {
    const response = await this.db
      .from('leave_requests')
      .select('*, membership:memberships!leave_requests_membership_id_fkey(*)')
      .eq('id', leaveRequestId)
      .maybeSingle();

    return requiredData(response, 'Richiesta di uscita non trovata') as LeaveRequestRow;
  }

  private async countActiveMembers(clubId: string | number): Promise<number> {
    const activeMemberships = await this.memberships.listActiveByClubId(clubId);
    if (activeMemberships.length === 0) {
      return 0;
    }

    let stillActiveCount = 0;
    for (const membership of activeMemberships) {
      const approvedLeave = await this.getLatestApprovedLeaveForMembership(
        membership.id,
      );
      if (approvedLeave != null) {
        await this.finalizeMembershipLeave(
          membership.id,
          approvedLeave.decided_at ?? approvedLeave.created_at ?? new Date().toISOString(),
        );
        continue;
      }

      stillActiveCount += 1;
    }

    return stillActiveCount;
  }
}
