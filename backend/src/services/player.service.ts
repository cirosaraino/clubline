import type { SupabaseClient } from '@supabase/supabase-js';

import {
  normalizeOptionalText,
  normalizePlayerIdentityInput,
  normalizeTeamRole,
} from '../domain/player-identity';
import type { PlayerProfileRow, RequestPrincipal, TeamRole } from '../domain/types';
import { ConflictError, ForbiddenError, NotFoundError } from '../lib/errors';
import { MembershipsRepository } from '../repositories/memberships.repository';
import { PlayerProfilesRepository } from '../repositories/player-profiles.repository';
import { PlayerIdentityService } from './player-identity.service';

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
  private readonly playerProfiles: PlayerProfilesRepository;
  private readonly memberships: MembershipsRepository;
  private readonly playerIdentity: PlayerIdentityService;

  constructor(db: SupabaseClient) {
    this.playerProfiles = new PlayerProfilesRepository(db);
    this.memberships = new MembershipsRepository(db);
    this.playerIdentity = new PlayerIdentityService(db);
  }

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

    let players = await this.playerProfiles.listActiveByClubId(clubId);

    if (filters.id_console) {
      const needle = filters.id_console.trim().toLowerCase();
      players = players.filter((player) =>
        `${player.id_console ?? ''}`.toLowerCase().includes(needle),
      );
    }

    if (filters.nome) {
      const needle = filters.nome.trim().toLowerCase();
      players = players.filter((player) =>
        player.nome.toLowerCase().includes(needle),
      );
    }

    if (filters.cognome) {
      const needle = filters.cognome.trim().toLowerCase();
      players = players.filter((player) =>
        player.cognome.toLowerCase().includes(needle),
      );
    }

    if (filters.q) {
      const needle = filters.q.trim().replaceAll(',', ' ').toLowerCase();
      players = players.filter((player) =>
        [
          player.nome,
          player.cognome,
          player.id_console,
          player.primary_role,
          ...player.secondary_roles,
        ]
          .filter(Boolean)
          .some((value) => value!.toLowerCase().includes(needle)),
      );
    }

    if (filters.role) {
      const role = filters.role.trim().toLowerCase();
      players = players.filter((player) =>
        [player.primary_role, ...(player.secondary_roles ?? [])]
          .filter(Boolean)
          .some((value) => value!.toLowerCase() === role),
      );
    }

    if (filters.macro_role) {
      const macroRole = filters.macro_role.trim().toLowerCase();
      players = players.filter(
        (player) => this.roleCategory(player.primary_role) === macroRole,
      );
    }

    return players;
  }

  async createPlayer(input: PlayerInput, principal: RequestPrincipal): Promise<PlayerProfileRow> {
    const membership = principal.membership;
    if (!membership) {
      throw new ForbiddenError('Devi appartenere a un club per aggiungere giocatori');
    }

    if (!principal.canManagePlayers) {
      return this.claimProfile(input, principal);
    }

    const requestedRole = normalizeTeamRole(input.team_role ?? 'player');
    if (requestedRole !== 'player') {
      throw new ConflictError(
        'Vice e capitano devono essere membri attivi del club',
        'player_management_role_requires_membership',
      );
    }

    const normalized = normalizePlayerIdentityInput(input);
    await this.playerIdentity.ensureStandaloneAnchor({
      consoleId: normalized.idConsole,
      accountEmail: normalized.accountEmail,
    });
    await this.playerIdentity.ensureConsoleIdAvailable(normalized.idConsole);
    await this.playerIdentity.ensureAccountEmailAvailable(normalized.accountEmail);

    return this.playerProfiles.insert({
      club_id: membership.club_id,
      membership_id: null,
      nome: normalized.nome,
      cognome: normalized.cognome,
      auth_user_id: null,
      account_email: normalized.accountEmail,
      shirt_number: normalized.shirtNumber,
      primary_role: normalized.primaryRole,
      secondary_role: normalized.secondaryRoles[0] ?? null,
      secondary_roles: normalized.secondaryRoles,
      id_console: normalized.idConsole,
      team_role: 'player',
      archived_at: null,
    });
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

    const normalized = normalizePlayerIdentityInput(input);
    if (player.membership_id == null) {
      await this.playerIdentity.ensureStandaloneAnchor({
        consoleId: normalized.idConsole,
        accountEmail: normalized.accountEmail,
      });
    }
    await this.playerIdentity.ensureConsoleIdAvailable(
      normalized.idConsole,
      player.id,
    );
    await this.playerIdentity.ensureAccountEmailAvailable(
      normalized.accountEmail,
      player.id,
    );

    const requestedRole = canManage
      ? normalizeTeamRole(input.team_role ?? player.team_role)
      : player.team_role;

    if (player.membership_id == null && requestedRole !== 'player') {
      throw new ConflictError(
        'Solo i membri attivi possono ricevere ruoli gestionali',
        'player_management_role_requires_membership',
      );
    }

    if (player.team_role === 'captain' && requestedRole !== 'captain') {
      throw new ConflictError(
        'Trasferisci prima il ruolo di capitano dal pannello club',
        'captain_transfer_required',
      );
    }

    if (requestedRole === 'captain' && player.team_role !== 'captain') {
      if (!canManage || !principal.isCaptain || !player.membership_id) {
        throw new ConflictError(
          'Solo il capitano puo trasferire il ruolo a un altro membro attivo',
          'captain_transfer_forbidden',
        );
      }

      await this.transferCaptainRole(principal.membership!.id, player.membership_id);
    } else if (player.membership_id && requestedRole !== player.team_role) {
      await this.memberships.updateRole(player.membership_id, requestedRole);
    }

    return this.playerProfiles.updateByIdAndClubId(player.id, clubId, {
      membership_id: player.membership_id,
      nome: normalized.nome,
      cognome: normalized.cognome,
      shirt_number: normalized.shirtNumber,
      primary_role: normalized.primaryRole,
      secondary_role: normalized.secondaryRoles[0] ?? null,
      secondary_roles: normalized.secondaryRoles,
      id_console: normalized.idConsole,
      team_role: requestedRole,
      auth_user_id: canEditOwn ? principal.authUser.id : player.auth_user_id,
      account_email: canEditOwn
        ? normalized.accountEmail ?? principal.authUser.email
        : normalized.accountEmail ?? player.account_email,
      archived_at: null,
    });
  }

  async releasePlayerFromClub(
    playerId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    const clubId = principal.membership?.club_id;
    if (!clubId) {
      throw new ForbiddenError('Devi appartenere a un club per modificare la rosa');
    }

    this.ensureCanManagePlayers(principal);
    const player = await this.getPlayer(playerId, clubId);
    if (principal.player && `${principal.player.id}` === `${player.id}`) {
      throw new ConflictError(
        'Usa i flussi club per uscire dalla squadra con il tuo account.',
        'self_release_forbidden',
      );
    }

    if (player.team_role === 'captain') {
      throw new ConflictError(
        'Trasferisci prima il ruolo di capitano dal pannello club.',
        'captain_transfer_required',
      );
    }

    const releasedAt = new Date().toISOString();
    if (player.membership_id != null) {
      await this.playerIdentity.detachMembershipProfile(player.membership_id, releasedAt);
      return;
    }

    await this.playerIdentity.releaseProfileFromClub(player, releasedAt);
  }

  async deletePlayer(playerId: string | number, principal: RequestPrincipal): Promise<void> {
    await this.releasePlayerFromClub(playerId, principal);
  }

  async claimProfile(input: PlayerInput, principal: RequestPrincipal): Promise<PlayerProfileRow> {
    const membership = principal.membership;
    if (!membership) {
      throw new ForbiddenError('Devi prima entrare in un club');
    }

    if (principal.player) {
      return this.updatePlayer(principal.player.id, input, principal);
    }

    return this.playerIdentity.ensureProfileForMembership({
      membership,
      email: input.account_email ?? principal.authUser.email,
      nome: input.nome,
      cognome: input.cognome,
      shirtNumber: input.shirt_number,
      primaryRole: input.primary_role,
      secondaryRole: input.secondary_role,
      secondaryRoles: input.secondary_roles,
      consoleId: input.id_console,
      teamRole: membership.role,
    });
  }

  async findByConsoleId(
    consoleId: string,
    clubId: string | number,
  ): Promise<PlayerProfileRow | null> {
    const normalizedConsoleId = normalizeOptionalText(consoleId);
    if (!normalizedConsoleId) {
      return null;
    }

    return this.playerProfiles.findActiveByConsoleIdInClub(normalizedConsoleId, clubId);
  }

  async getPlayer(playerId: string | number, clubId: string | number): Promise<PlayerProfileRow> {
    const player = await this.playerProfiles.findActiveByIdAndClubId(playerId, clubId);
    if (!player) {
      throw new NotFoundError('Giocatore non trovato', 'player_not_found');
    }

    return player;
  }

  private ensureCanManagePlayers(principal: RequestPrincipal): void {
    if (!principal.canManagePlayers) {
      throw new ForbiddenError('Non hai i permessi per gestire la rosa', 'player_management_forbidden');
    }
  }

  private async transferCaptainRole(
    currentCaptainMembershipId: string | number,
    nextCaptainMembershipId: string | number,
  ): Promise<void> {
    await this.memberships.updateRole(currentCaptainMembershipId, 'player');
    await this.memberships.updateRole(nextCaptainMembershipId, 'captain');

    const currentCaptainProfile =
      await this.playerProfiles.findActiveByMembershipId(currentCaptainMembershipId);
    if (currentCaptainProfile) {
      await this.playerProfiles.updateById(currentCaptainProfile.id, {
        team_role: 'player',
      });
    }

    const nextCaptainProfile =
      await this.playerProfiles.findActiveByMembershipId(nextCaptainMembershipId);
    if (nextCaptainProfile) {
      await this.playerProfiles.updateById(nextCaptainProfile.id, {
        team_role: 'captain',
      });
    }
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
