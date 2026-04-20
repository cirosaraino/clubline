import type { SupabaseClient } from '@supabase/supabase-js';

import type { PlayerProfileRow, RequestPrincipal, TeamRole } from '../domain/types';
import { ConflictError, ForbiddenError } from '../lib/errors';
import { ensureSuccess, optionalData, requiredData } from '../lib/supabase-result';

function normalize(value: string | null | undefined): string {
  return value?.trim() ?? '';
}

function normalizeOptional(value: string | null | undefined): string | null {
  const normalized = normalize(value);
  return normalized.length > 0 ? normalized : null;
}

function escapeIlike(value: string): string {
  return value
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_');
}

function normalizeEmail(value: string | null | undefined): string | null {
  const normalized = normalize(value).toLowerCase();
  return normalized.length > 0 ? normalized : null;
}

function normalizeRoles(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => (typeof item === 'string' ? item.trim() : ''))
    .filter(Boolean);
}

function normalizeTeamRole(value: unknown, fallback: TeamRole = 'player'): TeamRole {
  return value === 'captain' || value === 'vice_captain' || value === 'player' ? value : fallback;
}

export interface PlayerInput {
  nome: string;
  cognome: string;
  account_email?: string | null;
  shirt_number?: number | null;
  primary_role?: string | null;
  secondary_role?: string | null;
  secondary_roles?: string[] | null;
  id_console?: string | null;
  team_role?: TeamRole | null;
}

export class PlayerService {
  constructor(private readonly db: SupabaseClient) {}

  async listPlayers(
    filters: {
      macro_role?: string;
      role?: string;
      id_console?: string;
      nome?: string;
      cognome?: string;
      q?: string;
    } = {},
    principal: RequestPrincipal,
  ): Promise<PlayerProfileRow[]> {
    const clubId = principal.membership?.club_id;
    if (!clubId) {
      throw new ForbiddenError('Devi appartenere a un club per vedere la rosa');
    }

    let query = this.db
      .from('player_profiles')
      .select('*')
      .eq('club_id', clubId)
      .is('archived_at', null)
      .order('created_at', { ascending: true });

    if (filters.id_console) {
      const needle = escapeIlike(filters.id_console.trim());
      if (needle.length > 0) {
        query = query.ilike('id_console', `%${needle}%`);
      }
    }

    if (filters.nome) {
      const needle = escapeIlike(filters.nome.trim());
      if (needle.length > 0) {
        query = query.ilike('nome', `%${needle}%`);
      }
    }

    if (filters.cognome) {
      const needle = escapeIlike(filters.cognome.trim());
      if (needle.length > 0) {
        query = query.ilike('cognome', `%${needle}%`);
      }
    }

    if (filters.q) {
      const needle = escapeIlike(filters.q.trim()).replaceAll(',', ' ');
      if (needle.length > 0) {
        query = query.or(
          [
            `nome.ilike.%${needle}%`,
            `cognome.ilike.%${needle}%`,
            `id_console.ilike.%${needle}%`,
            `primary_role.ilike.%${needle}%`,
          ].join(','),
        );
      }
    }

    const response = await query;
    let players = (optionalData(response) as PlayerProfileRow[] | null) ?? [];

    if (filters.q) {
      const needle = filters.q.trim().toLowerCase();
      players = players.filter((player) =>
        [player.nome, player.cognome, player.id_console, player.primary_role, ...player.secondary_roles]
          .filter(Boolean)
          .some((value) => value!.toLowerCase().includes(needle)),
      );
    }

    if (filters.role) {
      const needle = filters.role.trim().toLowerCase();
      players = players.filter((player) => {
        const roleValues = [player.primary_role, ...(player.secondary_roles ?? [])].filter(Boolean);
        return roleValues.some((value) => value!.toLowerCase() === needle);
      });
    }

    if (filters.macro_role) {
      const needle = filters.macro_role.trim().toLowerCase();
      players = players.filter((player) => this.roleCategory(player.primary_role) === needle);
    }

    return players;
  }

  async createPlayer(input: PlayerInput, principal: RequestPrincipal): Promise<PlayerProfileRow> {
    const clubId = principal.membership?.club_id;
    if (!clubId) {
      throw new ForbiddenError('Devi appartenere a un club per aggiungere giocatori');
    }

    if (!principal.canManagePlayers) {
      return this.claimProfile(input, principal);
    }

    const requestedRole = normalizeTeamRole(input.team_role ?? 'player');
    if (requestedRole !== 'player') {
      throw new ConflictError('Vice e capitano devono essere membri attivi del club');
    }

    await this.ensureConsoleIdAvailable(normalizeOptional(input.id_console), clubId);
    const payload = this.buildPayload(input, requestedRole);
    const response = await this.db
      .from('player_profiles')
      .insert({
        ...payload,
        club_id: clubId,
      })
      .select('*')
      .single();

    return requiredData(response) as PlayerProfileRow;
  }

  async updatePlayer(
    playerId: string | number,
    input: PlayerInput,
    principal: RequestPrincipal,
  ): Promise<PlayerProfileRow> {
    const clubId = principal.membership?.club_id;
    if (!clubId) {
      throw new ForbiddenError('Devi appartenere a un club per modificare i giocatori');
    }

    const player = await this.getPlayer(playerId, clubId);
    const canEditOwn = principal.player?.id === player.id;
    const canManage = principal.canManagePlayers;

    if (!canManage && !canEditOwn) {
      throw new ForbiddenError('Non puoi modificare questo profilo');
    }

    await this.ensureConsoleIdAvailable(normalizeOptional(input.id_console), clubId, player.id);

    const requestedRole = canManage
      ? normalizeTeamRole(input.team_role ?? player.team_role)
      : player.team_role;

    if (player.membership_id == null && requestedRole !== 'player') {
      throw new ConflictError('Solo i membri attivi possono ricevere ruoli gestionali');
    }

    if (player.team_role === 'captain' && requestedRole !== 'captain') {
      throw new ConflictError('Trasferisci prima il ruolo di capitano dal pannello club');
    }

    if (requestedRole === 'captain' && player.team_role !== 'captain') {
      if (!canManage || !principal.isCaptain || !player.membership_id) {
        throw new ConflictError('Solo il capitano puo trasferire il ruolo a un altro membro attivo');
      }

      await this.transferCaptainRole(
        principal.membership!.id,
        player.membership_id,
      );
    } else if (player.membership_id && requestedRole !== player.team_role) {
      await this.syncMembershipRole(player.membership_id, requestedRole);
    }

    const payload = this.buildPayload(input, requestedRole, {
      authUserId: canEditOwn ? principal.authUser.id : player.auth_user_id,
      membershipId: player.membership_id,
      accountEmail: canEditOwn
        ? normalizeEmail(input.account_email) ?? principal.authUser.email
        : player.account_email,
    });

    const response = await this.db
      .from('player_profiles')
      .update(payload)
      .eq('id', player.id)
      .eq('club_id', clubId)
      .is('archived_at', null)
      .select('*')
      .single();

    return requiredData(response) as PlayerProfileRow;
  }

  async deletePlayer(playerId: string | number, principal: RequestPrincipal): Promise<void> {
    const clubId = principal.membership?.club_id;
    if (!clubId) {
      throw new ForbiddenError('Devi appartenere a un club per modificare la rosa');
    }

    this.ensureCanManagePlayers(principal);
    const player = await this.getPlayer(playerId, clubId);
    if (player.membership_id != null) {
      throw new ConflictError(
        'I membri attivi non possono essere rimossi dalla rosa con questa azione. Usa i flussi club.',
      );
    }

    const response = await this.db
      .from('player_profiles')
      .update({
        archived_at: new Date().toISOString(),
      })
      .eq('id', player.id)
      .eq('club_id', clubId)
      .is('archived_at', null);
    ensureSuccess(response);
  }

  async claimProfile(input: PlayerInput, principal: RequestPrincipal): Promise<PlayerProfileRow> {
    if (!principal.membership) {
      throw new ForbiddenError('Devi prima entrare in un club');
    }

    const existingActiveProfile = principal.player;
    if (existingActiveProfile) {
      return this.updatePlayer(existingActiveProfile.id, input, principal);
    }

    const clubId = principal.membership.club_id;
    const normalizedConsoleId = normalizeOptional(input.id_console);
    if (normalizedConsoleId) {
      const consoleProfile = await this.findByConsoleId(normalizedConsoleId, clubId);
      if (consoleProfile && consoleProfile.membership_id && `${consoleProfile.membership_id}` !== `${principal.membership.id}`) {
        throw new ConflictError('Esiste gia un profilo collegato a questo ID console');
      }
    }

    const payload = this.buildPayload(input, principal.membership.role, {
      authUserId: principal.authUser.id,
      membershipId: principal.membership.id,
      accountEmail: normalizeEmail(input.account_email) ?? principal.authUser.email,
    });

    const response = await this.db
      .from('player_profiles')
      .insert({
        ...payload,
        club_id: clubId,
      })
      .select('*')
      .single();

    return requiredData(response) as PlayerProfileRow;
  }

  async findByConsoleId(
    consoleId: string,
    clubId: string | number,
  ): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('club_id', clubId)
      .eq('id_console', consoleId.trim())
      .is('archived_at', null)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  async getPlayer(playerId: string | number, clubId: string | number): Promise<PlayerProfileRow> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('id', playerId)
      .eq('club_id', clubId)
      .is('archived_at', null)
      .maybeSingle();

    return requiredData(response, 'Giocatore non trovato') as PlayerProfileRow;
  }

  private ensureCanManagePlayers(principal: RequestPrincipal): void {
    if (!principal.canManagePlayers) {
      throw new ForbiddenError('Non hai i permessi per gestire la rosa');
    }
  }

  private async ensureConsoleIdAvailable(
    consoleId: string | null,
    clubId: string | number,
    excludingPlayerId?: string | number,
  ): Promise<void> {
    if (!consoleId) {
      return;
    }

    const existing = await this.findByConsoleId(consoleId, clubId);
    if (existing && `${existing.id}` !== `${excludingPlayerId ?? ''}`) {
      throw new ConflictError('Esiste gia un profilo con questo ID console nel club');
    }
  }

  private async syncMembershipRole(
    membershipId: string | number,
    role: TeamRole,
  ): Promise<void> {
    const response = await this.db
      .from('memberships')
      .update({ role })
      .eq('id', membershipId)
      .eq('status', 'active');
    ensureSuccess(response);
  }

  private async transferCaptainRole(
    currentCaptainMembershipId: string | number,
    nextCaptainMembershipId: string | number,
  ): Promise<void> {
    const demoteResponse = await this.db
      .from('memberships')
      .update({ role: 'player' })
      .eq('id', currentCaptainMembershipId)
      .eq('role', 'captain');
    ensureSuccess(demoteResponse);

    const promoteResponse = await this.db
      .from('memberships')
      .update({ role: 'captain' })
      .eq('id', nextCaptainMembershipId)
      .eq('status', 'active');
    ensureSuccess(promoteResponse);

    await this.db
      .from('player_profiles')
      .update({ team_role: 'player' })
      .eq('membership_id', currentCaptainMembershipId)
      .is('archived_at', null);

    await this.db
      .from('player_profiles')
      .update({ team_role: 'captain' })
      .eq('membership_id', nextCaptainMembershipId)
      .is('archived_at', null);
  }

  private buildPayload(
    input: PlayerInput,
    teamRole: TeamRole,
    overrides?: {
      authUserId?: string | null;
      membershipId?: string | number | null;
      accountEmail?: string | null;
    },
  ) {
    const primaryRole = normalizeOptional(input.primary_role);
    const secondaryRoles = normalizeRoles([
      ...(input.secondary_roles ?? []),
      ...(input.secondary_role ? [input.secondary_role] : []),
    ]).filter((role) => role !== primaryRole);

    return {
      membership_id: overrides?.membershipId ?? null,
      nome: normalize(input.nome),
      cognome: normalize(input.cognome),
      shirt_number: input.shirt_number ?? null,
      primary_role: primaryRole,
      secondary_role: secondaryRoles[0] ?? null,
      secondary_roles: secondaryRoles,
      id_console: normalizeOptional(input.id_console),
      team_role: teamRole,
      auth_user_id: overrides?.authUserId ?? null,
      account_email: normalizeEmail(overrides?.accountEmail ?? input.account_email),
    };
  }

  private roleCategory(role: string | null): string | null {
    if (!role) return null;

    const normalized = role.toLowerCase();
    if (['por', 'dc', 'ts', 'td'].includes(normalized)) return 'difesa';
    if (['cc', 'cdc', 'coc', 'me'].includes(normalized)) return 'centrocampo';
    if (['att', 'sp', 'es', 'ed', 'trq'].includes(normalized)) return 'attacco';
    return 'altro';
  }
}
