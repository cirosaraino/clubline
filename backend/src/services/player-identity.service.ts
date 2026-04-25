import type { SupabaseClient } from '@supabase/supabase-js';

import {
  inferNamesFromEmail,
  normalizeEmailField,
  normalizeOptionalText,
  normalizeOptionalTextField,
  normalizeRoles,
} from '../domain/player-identity';
import type { MembershipRow, PlayerProfileRow, TeamRole } from '../domain/types';
import { ConflictError } from '../lib/errors';
import { optionalData } from '../lib/supabase-result';
import { MembershipsRepository } from '../repositories/memberships.repository';
import { PlayerProfilesRepository } from '../repositories/player-profiles.repository';

export interface AttachPlayerIdentityInput {
  membership: MembershipRow;
  email?: string | null;
  nome?: string | null;
  cognome?: string | null;
  shirtNumber?: number | null;
  primaryRole?: string | null;
  secondaryRole?: string | null;
  secondaryRoles?: string[] | null;
  consoleId?: string | null;
  teamRole: TeamRole;
}

export class PlayerIdentityService {
  constructor(
    private readonly db: SupabaseClient,
  ) {
    this.playerProfiles = new PlayerProfilesRepository(db);
    this.memberships = new MembershipsRepository(db);
  }

  private readonly playerProfiles: PlayerProfilesRepository;
  private readonly memberships: MembershipsRepository;

  async ensureProfileForMembership(
    input: AttachPlayerIdentityInput,
  ): Promise<PlayerProfileRow> {
    const normalized = this.normalizeAttachInput(input);
    const existingMembershipProfile =
      await this.playerProfiles.findActiveByMembershipId(input.membership.id);

    const reusableIdentity = await this.findReusableIdentity({
      authUserId: input.membership.auth_user_id,
      accountEmail: normalized.accountEmail,
      consoleId: normalized.consoleId,
      membershipId: input.membership.id,
    });

    const targetProfile = existingMembershipProfile ?? reusableIdentity;
    await this.ensureConsoleIdAvailable(
      normalized.consoleId,
      targetProfile?.id,
    );

    const fallbackNames = inferNamesFromEmail(normalized.accountEmail);
    const payload = {
      club_id: input.membership.club_id,
      membership_id: input.membership.id,
      auth_user_id: input.membership.auth_user_id,
      account_email: normalized.accountEmail ?? targetProfile?.account_email ?? null,
      nome:
        normalized.nome ??
        targetProfile?.nome ??
        fallbackNames.nome,
      cognome:
        normalized.cognome ??
        targetProfile?.cognome ??
        fallbackNames.cognome,
      shirt_number:
        normalized.shirtNumber !== undefined
          ? normalized.shirtNumber
          : targetProfile?.shirt_number ?? null,
      primary_role:
        normalized.primaryRole !== undefined
          ? normalized.primaryRole
          : targetProfile?.primary_role ?? null,
      secondary_role:
        normalized.secondaryRoles !== undefined
          ? (normalized.secondaryRoles[0] ?? null)
          : targetProfile?.secondary_role ?? null,
      secondary_roles:
        normalized.secondaryRoles !== undefined
          ? normalized.secondaryRoles
          : targetProfile?.secondary_roles ?? [],
      id_console:
        normalized.consoleId !== undefined
          ? normalized.consoleId
          : targetProfile?.id_console ?? null,
      team_role: input.teamRole,
      archived_at: null,
    } as const;

    if (targetProfile) {
      return this.playerProfiles.updateById(targetProfile.id, payload);
    }

    return this.playerProfiles.insert(payload);
  }

  async detachMembershipProfile(
    membershipId: string | number,
    leftAt: string,
  ): Promise<PlayerProfileRow | null> {
    const profile = await this.playerProfiles.findActiveByMembershipId(membershipId);
    await this.memberships.markLeft(membershipId, leftAt);
    if (!profile) {
      return null;
    }

    return this.releaseProfileFromClub(profile, leftAt);
  }

  async releaseProfileFromClub(
    profile: PlayerProfileRow,
    leftAt: string,
  ): Promise<PlayerProfileRow> {
    const keepStandaloneIdentity =
      normalizeOptionalText(profile.auth_user_id) != null ||
      normalizeOptionalText(profile.account_email) != null;
    const hasOperationalHistory = await this.hasOperationalHistory(profile.id);

    if (!keepStandaloneIdentity) {
      return this.playerProfiles.updateById(
        profile.id,
        this.buildDetachedProfilePayload(profile, {
          clubId: profile.club_id,
          membershipId: null,
          teamRole: 'player',
          archivedAt: leftAt,
        }),
      );
    }

    if (hasOperationalHistory) {
      await this.playerProfiles.updateById(
        profile.id,
        this.buildDetachedProfilePayload(profile, {
          clubId: profile.club_id,
          membershipId: null,
          teamRole: 'player',
          archivedAt: leftAt,
        }),
      );

      return this.playerProfiles.insert(
        this.buildDetachedProfilePayload(profile, {
          clubId: null,
          membershipId: null,
          teamRole: 'player',
          archivedAt: null,
        }),
      );
    }

    return this.playerProfiles.updateById(
      profile.id,
      this.buildDetachedProfilePayload(profile, {
        clubId: null,
        membershipId: null,
        teamRole: 'player',
        archivedAt: null,
      }),
    );
  }

  async ensureConsoleIdAvailable(
    consoleId: string | null | undefined,
    excludingPlayerId?: string | number,
  ): Promise<void> {
    if (!consoleId) {
      return;
    }

    const existing = await this.playerProfiles.findActiveByConsoleId(consoleId);
    if (existing && `${existing.id}` !== `${excludingPlayerId ?? ''}`) {
      throw new ConflictError(
        'Esiste gia un profilo attivo con questo ID console',
        'player_console_conflict',
      );
    }
  }

  async ensureStandaloneAnchor(input: {
    consoleId?: string | null;
    accountEmail?: string | null;
  }): Promise<void> {
    if (!input.consoleId && !input.accountEmail) {
      throw new ConflictError(
        'Per creare un giocatore svincolato serve almeno ID console oppure email account',
        'player_identity_anchor_required',
      );
    }
  }

  async ensureAccountEmailAvailable(
    accountEmail: string | null | undefined,
    excludingPlayerId?: string | number,
  ): Promise<void> {
    if (!accountEmail) {
      return;
    }

    const existing = await this.playerProfiles.findActiveByAccountEmail(accountEmail);
    if (existing && `${existing.id}` !== `${excludingPlayerId ?? ''}`) {
      throw new ConflictError(
        'Esiste gia un profilo attivo con questa email account',
        'player_email_conflict',
      );
    }
  }

  private async findReusableIdentity(options: {
    authUserId: string;
    accountEmail?: string | null;
    consoleId?: string | null;
    membershipId: string | number;
  }): Promise<PlayerProfileRow | null> {
    const candidates: PlayerProfileRow[] = [];

    const authCandidate = await this.playerProfiles.findActiveByAuthUserId(
      options.authUserId,
    );
    if (authCandidate) {
      candidates.push(authCandidate);
    }

    if (options.accountEmail) {
      const emailCandidate = await this.playerProfiles.findActiveByAccountEmail(
        options.accountEmail,
      );
      if (emailCandidate) {
        candidates.push(emailCandidate);
      }
    }

    if (options.consoleId) {
      const consoleCandidate = await this.playerProfiles.findActiveByConsoleId(
        options.consoleId,
      );
      if (consoleCandidate) {
        candidates.push(consoleCandidate);
      }
    }

    const uniqueCandidates = candidates.filter(
      (candidate, index, collection) =>
        collection.findIndex((entry) => `${entry.id}` === `${candidate.id}`) === index,
    );

    if (uniqueCandidates.length === 0) {
      return null;
    }

    if (uniqueCandidates.length > 1) {
      throw new ConflictError(
        'Sono stati trovati piu profili attivi per la stessa identita giocatore',
        'player_identity_conflict',
      );
    }

    const candidate = uniqueCandidates[0] ?? null;
    if (candidate?.membership_id != null && `${candidate.membership_id}` !== `${options.membershipId}`) {
      throw new ConflictError(
        'Il profilo giocatore risulta gia collegato a un altro club attivo',
        'player_already_attached',
      );
    }

    return candidate;
  }

  private async hasOperationalHistory(playerId: string | number): Promise<boolean> {
    const [lineupAssignment, attendanceEntry, attendanceUpdate] = await Promise.all([
      this.db
        .from('lineup_players')
        .select('id')
        .eq('player_id', playerId)
        .limit(1)
        .maybeSingle(),
      this.db
        .from('attendance_entries')
        .select('id')
        .eq('player_id', playerId)
        .limit(1)
        .maybeSingle(),
      this.db
        .from('attendance_entries')
        .select('id')
        .eq('updated_by_player_id', playerId)
        .limit(1)
        .maybeSingle(),
    ]);

    return (
      optionalData(lineupAssignment) != null ||
      optionalData(attendanceEntry) != null ||
      optionalData(attendanceUpdate) != null
    );
  }

  private normalizeAttachInput(input: AttachPlayerIdentityInput): {
    nome: string | null | undefined;
    cognome: string | null | undefined;
    accountEmail: string | null | undefined;
    shirtNumber: number | null | undefined;
    primaryRole: string | null | undefined;
    secondaryRoles: string[] | undefined;
    consoleId: string | null | undefined;
  } {
    const primaryRole = input.primaryRole == null
      ? undefined
      : normalizeOptionalTextField(input.primaryRole);
    const normalizedSecondaryRoles = normalizeRoles([
      ...(input.secondaryRoles ?? []),
      ...(input.secondaryRole ? [input.secondaryRole] : []),
    ]).filter((role) => role !== primaryRole);

    return {
      nome: normalizeOptionalTextField(input.nome),
      cognome: normalizeOptionalTextField(input.cognome),
      accountEmail: normalizeEmailField(input.email),
      shirtNumber: input.shirtNumber == null ? undefined : input.shirtNumber,
      primaryRole,
      secondaryRoles:
        input.secondaryRole !== undefined || input.secondaryRoles !== undefined
          ? normalizedSecondaryRoles
          : undefined,
      consoleId:
        input.consoleId == null
          ? undefined
          : normalizeOptionalTextField(input.consoleId),
    };
  }

  private buildDetachedProfilePayload(
    profile: PlayerProfileRow,
    options: {
      clubId: string | number | null;
      membershipId: string | number | null;
      teamRole: TeamRole;
      archivedAt: string | null;
    },
  ) {
    return {
      club_id: options.clubId,
      membership_id: options.membershipId,
      nome: profile.nome,
      cognome: profile.cognome,
      auth_user_id: profile.auth_user_id,
      account_email: profile.account_email,
      shirt_number: profile.shirt_number,
      primary_role: profile.primary_role,
      secondary_role: profile.secondary_role,
      secondary_roles: profile.secondary_roles,
      id_console: profile.id_console,
      team_role: options.teamRole,
      archived_at: options.archivedAt,
    } as const;
  }
}
