import type { SupabaseClient } from '@supabase/supabase-js';

import type { PlayerProfileRow, RequestPrincipal, TeamRole } from '../domain/types';
import { ConflictError, ForbiddenError } from '../lib/errors';
import { ensureSuccess, optionalData, requiredData } from '../lib/supabase-result';

function normalize(value: string | null | undefined): string {
  return value?.trim() ?? '';
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

  async listPlayers(filters: {
    macro_role?: string;
    role?: string;
    id_console?: string;
    nome?: string;
    cognome?: string;
    q?: string;
  } = {}): Promise<PlayerProfileRow[]> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .order('created_at', { ascending: true });

    let players = (optionalData(response) as PlayerProfileRow[] | null) ?? [];

    if (filters.id_console) {
      const needle = filters.id_console.trim().toLowerCase();
      players = players.filter((player) => (player.id_console ?? '').toLowerCase().includes(needle));
    }

    if (filters.nome) {
      const needle = filters.nome.trim().toLowerCase();
      players = players.filter((player) => player.nome.toLowerCase().includes(needle));
    }

    if (filters.cognome) {
      const needle = filters.cognome.trim().toLowerCase();
      players = players.filter((player) => player.cognome.toLowerCase().includes(needle));
    }

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
      players = players.filter((player) => {
        const primaryCategory = this.roleCategory(player.primary_role);
        return primaryCategory === needle;
      });
    }

    return players;
  }

  async createPlayer(input: PlayerInput, principal: RequestPrincipal): Promise<PlayerProfileRow> {
    if (!principal.canManagePlayers) {
      return this.claimProfile(input, principal);
    }

    const payload = this.buildPayload(input, principal, {
      preserveExistingAccountEmail: false,
      preserveExistingAuth: false,
      preserveExistingRole: false,
      teamRole: normalizeTeamRole(input.team_role ?? 'player'),
    });
    const response = await this.db.from('player_profiles').insert(payload).select('*').single();
    return requiredData(response) as PlayerProfileRow;
  }

  async updatePlayer(
    playerId: string | number,
    input: PlayerInput,
    principal: RequestPrincipal,
  ): Promise<PlayerProfileRow> {
    const player = await this.getPlayer(playerId);
    const canEditOwn = principal.player?.id === player.id;
    const canManage = principal.canManagePlayers;

    if (!canManage && !canEditOwn) {
      throw new ForbiddenError('Non puoi modificare questo profilo');
    }

    const payload = this.buildPayload(input, principal, {
      existingPlayer: player,
      preserveExistingAccountEmail: true,
      preserveExistingAuth: true,
      preserveExistingRole: !canManage,
      teamRole: canManage ? normalizeTeamRole(input.team_role ?? player.team_role) : player.team_role,
    });
    const response = await this.db
      .from('player_profiles')
      .update(payload)
      .eq('id', player.id)
      .select('*')
      .single();

    return requiredData(response) as PlayerProfileRow;
  }

  async deletePlayer(playerId: string | number, principal: RequestPrincipal): Promise<void> {
    this.ensureCanManagePlayers(principal);
    const response = await this.db.from('player_profiles').delete().eq('id', playerId);
    ensureSuccess(response);
  }

  async claimProfile(input: PlayerInput, principal: RequestPrincipal): Promise<PlayerProfileRow> {
    if (!principal.authUser) {
      throw new ForbiddenError('Autenticazione richiesta');
    }

    const consoleId = normalize(input.id_console);
    if (!consoleId) {
      throw new ConflictError('ID console obbligatorio');
    }

    const existing = await this.findByConsoleId(consoleId);
    if (existing) {
      const canClaim = !existing.auth_user_id && !existing.account_email;

      if (!canClaim) {
        throw new ConflictError('Esiste gia un profilo collegato a questo ID console');
      }

      const payload = this.buildPayload(input, principal, {
        existingPlayer: existing,
        preserveExistingAccountEmail: false,
        preserveExistingAuth: false,
        preserveExistingRole: false,
        teamRole: principal.canBootstrapCaptain ? 'captain' : existing.team_role,
      });
      const response = await this.db
        .from('player_profiles')
        .update({
          ...payload,
          auth_user_id: principal.authUser.id,
          account_email: normalizeEmail(input.account_email) ?? principal.authUser.email,
        })
        .eq('id', existing.id)
        .select('*')
        .single();

      return requiredData(response) as PlayerProfileRow;
    }

    const payload = this.buildPayload(input, principal, {
      preserveExistingAccountEmail: false,
      preserveExistingAuth: false,
      preserveExistingRole: false,
      teamRole: principal.canBootstrapCaptain ? 'captain' : 'player',
    });
    const response = await this.db
      .from('player_profiles')
      .insert({
        ...payload,
        auth_user_id: principal.authUser.id,
        account_email: normalizeEmail(input.account_email) ?? principal.authUser.email,
      })
      .select('*')
      .single();

    return requiredData(response) as PlayerProfileRow;
  }

  async findByConsoleId(consoleId: string): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('id_console', consoleId.trim())
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  async getPlayer(playerId: string | number): Promise<PlayerProfileRow> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('id', playerId)
      .maybeSingle();

    return requiredData(response, 'Giocatore non trovato') as PlayerProfileRow;
  }

  private ensureCanManagePlayers(principal: RequestPrincipal): void {
    if (!principal.canManagePlayers) {
      throw new ForbiddenError('Non hai i permessi per gestire la rosa');
    }
  }

  private buildPayload(
    input: PlayerInput,
    principal: RequestPrincipal,
    options: {
      existingPlayer?: PlayerProfileRow;
      preserveExistingAccountEmail: boolean;
      preserveExistingAuth: boolean;
      preserveExistingRole: boolean;
      teamRole: TeamRole;
    },
  ) {
    const primaryRole = normalize(input.primary_role) || null;
    const secondaryRoles = normalizeRoles([
      ...(input.secondary_roles ?? []),
      ...(input.secondary_role ? [input.secondary_role] : []),
    ]);
    const uniqueSecondaryRoles = secondaryRoles.filter((role) => role !== primaryRole);
    const existingPlayer = options.existingPlayer;

    return {
      nome: normalize(input.nome),
      cognome: normalize(input.cognome),
      shirt_number: input.shirt_number ?? null,
      primary_role: primaryRole,
      secondary_role: uniqueSecondaryRoles[0] ?? null,
      secondary_roles: uniqueSecondaryRoles,
      id_console: normalize(input.id_console) || null,
      team_role: options.preserveExistingRole && existingPlayer
        ? existingPlayer.team_role
        : options.teamRole,
      auth_user_id: options.preserveExistingAuth && existingPlayer ? existingPlayer.auth_user_id : null,
      account_email: options.preserveExistingAccountEmail
        ? existingPlayer?.account_email ?? null
        : normalizeEmail(input.account_email),
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
