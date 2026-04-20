import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  ClubRow,
  JoinRequestRow,
  LeaveRequestRow,
  MembershipRow,
  RequestPrincipal,
  TeamRole,
} from '../domain/types';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../lib/errors';
import { ensureSuccess, optionalData, requiredData } from '../lib/supabase-result';

const CLUB_LOGO_BUCKET = 'club-assets';
const allowedLogoMimeTypes = new Set([
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/webp',
  'image/gif',
  'image/svg+xml',
]);
const maxLogoBytes = 5 * 1024 * 1024;

type ClubLogoUpload = {
  mimeType: string;
  bytes: Buffer;
  extension: string;
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

function inferNamesFromEmail(email: string | null | undefined): { nome: string; cognome: string } {
  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail) {
    return {
      nome: 'Nuovo',
      cognome: 'Membro',
    };
  }

  const localPart = normalizedEmail.split('@')[0] ?? '';
  const cleaned = localPart.replaceAll(/[^a-zA-Z0-9]+/g, ' ').trim();
  const segments = cleaned
    .split(/\s+/)
    .map((segment) => segment.trim())
    .filter((segment) => segment.length > 0);

  if (segments.length === 0) {
    return {
      nome: 'Nuovo',
      cognome: 'Membro',
    };
  }

  return {
    nome: capitalize(segments[0] ?? ''),
    cognome: segments.length > 1
      ? capitalize(segments.slice(1).join(' '))
      : 'Membro',
  };
}

function capitalize(value: string): string {
  if (value.length === 0) {
    return value;
  }

  return `${value[0]?.toUpperCase() ?? ''}${value.substring(1).toLowerCase()}`;
}

function parseLogoUpload(dataUrl: string): ClubLogoUpload {
  const normalized = dataUrl.trim();
  const match = /^data:([^;]+);base64,(.+)$/i.exec(normalized);
  if (match == null) {
    throw new ValidationError('Il logo deve essere inviato come immagine base64 valida');
  }

  const mimeType = match[1]?.toLowerCase() ?? '';
  const encoded = match[2] ?? '';
  if (!allowedLogoMimeTypes.has(mimeType)) {
    throw new ValidationError('Formato logo non supportato');
  }

  const bytes = Buffer.from(encoded, 'base64');
  if (bytes.length == 0 || bytes.length > maxLogoBytes) {
    throw new ValidationError('Il logo deve essere inferiore a 5 MB');
  }

  return {
    mimeType,
    bytes,
    extension:
      mimeType === 'image/png'
        ? 'png'
        : mimeType === 'image/jpeg' || mimeType === 'image/jpg'
          ? 'jpg'
          : mimeType === 'image/webp'
            ? 'webp'
            : mimeType === 'image/gif'
              ? 'gif'
              : mimeType === 'image/svg+xml'
                ? 'svg'
                : 'img',
  };
}

export interface CreateClubInput {
  name: string;
  logo_data_url?: string | null;
  owner_nome?: string | null;
  owner_cognome?: string | null;
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

export class ClubsService {
  constructor(private readonly db: SupabaseClient) {}

  async listClubs(search?: string): Promise<ClubRow[]> {
    let query = this.db
      .from('clubs')
      .select('*')
      .order('name', { ascending: true });

    const needle = normalizeText(search);
    if (needle.length > 0) {
      const normalizedNeedle = needle.toLowerCase();
      query = query.or(`name.ilike.%${normalizedNeedle}%,slug.ilike.%${normalizedNeedle}%`);
    }

    const response = await query;
    return ((optionalData(response) as ClubRow[] | null) ?? []);
  }

  async createClub(input: CreateClubInput, principal: RequestPrincipal): Promise<{
    club: ClubRow;
    membership: MembershipRow;
  }> {
    await this.ensureVerifiedUser(principal);
    await this.ensureNoActiveMembership(principal.authUser.id);
    await this.ensureNoPendingJoinRequest(principal.authUser.id);

    const clubName = normalizeClubName(input.name);
    const normalizedName = normalizeClubKey(clubName);
    await this.ensureUniqueClubName(normalizedName);

    const slug = await this.generateUniqueSlug(clubName);
    const clubInsertResponse = await this.db
      .from('clubs')
      .insert({
        name: clubName,
        normalized_name: normalizedName,
        slug,
        primary_color: normalizeHexColor(input.primary_color) ?? '#1F2937',
        accent_color: normalizeHexColor(input.accent_color) ?? '#0F766E',
        surface_color: normalizeHexColor(input.surface_color) ?? '#0F172A',
        created_by_user_id: principal.authUser.id,
      })
      .select('*')
      .single();

    const club = requiredData(clubInsertResponse) as ClubRow;

    await this.db
      .from('club_settings')
      .upsert(
        {
          club_id: club.id,
          additional_links: [],
        },
        { onConflict: 'club_id' },
      );

    await this.db
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

    const membershipResponse = await this.db
      .from('memberships')
      .insert({
        club_id: club.id,
        auth_user_id: principal.authUser.id,
        role: 'captain',
        status: 'active',
      })
      .select('*')
      .single();

    const membership = requiredData(membershipResponse) as MembershipRow;
    await this.ensurePlayerProfileForMembership({
      membership,
      email: principal.authUser.email,
      nome: input.owner_nome,
      cognome: input.owner_cognome,
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

    const membershipResponse = await this.db
      .from('memberships')
      .insert({
        club_id: joinRequest.club_id,
        auth_user_id: joinRequest.requester_user_id,
        role: 'player',
        status: 'active',
      })
      .select('*')
      .single();

    const membership = requiredData(membershipResponse) as MembershipRow;
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
      .eq('status', 'pending');
    ensureSuccess(updateResponse);

    return membership;
  }

  async rejectJoinRequest(
    joinRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
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
      .select('*, membership:memberships(*)')
      .eq('club_id', captainMembership.club_id)
      .eq('status', 'pending')
      .order('created_at', { ascending: true });

    return ((optionalData(response) as LeaveRequestRow[] | null) ?? []);
  }

  async approveLeaveRequest(
    leaveRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
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

    const updateMembershipResponse = await this.db
      .from('memberships')
      .update({
        status: 'left',
        left_at: now,
      })
      .eq('id', targetMembership.id)
      .eq('status', 'active');
    ensureSuccess(updateMembershipResponse);

    const archiveProfileResponse = await this.db
      .from('player_profiles')
      .update({
        membership_id: null,
        auth_user_id: null,
        account_email: null,
        archived_at: now,
      })
      .eq('membership_id', targetMembership.id)
      .is('archived_at', null);
    ensureSuccess(archiveProfileResponse);
  }

  async rejectLeaveRequest(
    leaveRequestId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
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
    const captainMembership = ensureCaptain(principal);
    if (`${captainMembership.id}` == `${targetMembershipId}`) {
      throw new ConflictError('Seleziona un altro membro per il trasferimento del ruolo');
    }

    const targetMembership = await this.getMembershipById(targetMembershipId);
    if (`${targetMembership.club_id}` != `${captainMembership.club_id}` || targetMembership.status != 'active') {
      throw new ForbiddenError('Il nuovo capitano deve essere un membro attivo dello stesso club');
    }

    await this.db
      .from('memberships')
      .update({ role: 'player' })
      .eq('id', captainMembership.id)
      .eq('role', 'captain');

    await this.db
      .from('memberships')
      .update({ role: 'captain' })
      .eq('id', targetMembership.id)
      .eq('status', 'active');

    await this.syncPlayerRoleForMembership(captainMembership.id, 'player');
    await this.syncPlayerRoleForMembership(targetMembership.id, 'captain');
  }

  async updateCurrentClubLogo(
    input: UpdateClubLogoInput,
    principal: RequestPrincipal,
  ): Promise<ClubRow> {
    const membership = ensureHasClub(principal);
    if (!principal.canManageTeamInfo) {
      throw new ForbiddenError('Non hai i permessi per aggiornare il logo del club');
    }

    return this.updateClubLogoForClub(membership.club_id, input);
  }

  async deleteCurrentClub(principal: RequestPrincipal): Promise<void> {
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
    const parsedLogo = parseLogoUpload(input.logo_data_url);
    const path = `clubs/${clubId}/logo-${Date.now()}.${parsedLogo.extension}`;
    const uploadResponse = await this.db.storage
      .from(CLUB_LOGO_BUCKET)
      .upload(path, parsedLogo.bytes, {
        contentType: parsedLogo.mimeType,
        upsert: true,
      });

    if (uploadResponse.error) {
      throw uploadResponse.error;
    }

    const publicUrlResponse = this.db.storage.from(CLUB_LOGO_BUCKET).getPublicUrl(path);
    const publicUrl = publicUrlResponse.data.publicUrl;
    const response = await this.db
      .from('clubs')
      .update({
        logo_url: publicUrl,
        logo_storage_path: path,
        primary_color: normalizeHexColor(input.primary_color),
        accent_color: normalizeHexColor(input.accent_color),
        surface_color: normalizeHexColor(input.surface_color),
      })
      .eq('id', clubId)
      .select('*')
      .single();

    return requiredData(response) as ClubRow;
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
    shirtNumber?: number | null;
    primaryRole?: string | null;
    teamRole: TeamRole;
  }): Promise<void> {
    const fallbackNames = inferNamesFromEmail(options.email);
    const response = await this.db
      .from('player_profiles')
      .insert({
        club_id: options.membership.club_id,
        membership_id: options.membership.id,
        nome: normalizeOptionalText(options.nome) ?? fallbackNames.nome,
        cognome: normalizeOptionalText(options.cognome) ?? fallbackNames.cognome,
        auth_user_id: options.membership.auth_user_id,
        account_email: normalizeEmail(options.email),
        shirt_number: options.shirtNumber ?? null,
        primary_role: normalizeOptionalText(options.primaryRole),
        secondary_role: null,
        secondary_roles: [],
        id_console: null,
        team_role: options.teamRole,
      });

    ensureSuccess(response);
  }

  private async syncPlayerRoleForMembership(
    membershipId: string | number,
    role: TeamRole,
  ): Promise<void> {
    const response = await this.db
      .from('player_profiles')
      .update({ team_role: role })
      .eq('membership_id', membershipId)
      .is('archived_at', null);

    ensureSuccess(response);
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
    const response = await this.db
      .from('memberships')
      .select('*')
      .eq('auth_user_id', authUserId)
      .eq('status', 'active')
      .maybeSingle();

    return optionalData(response) as MembershipRow | null;
  }

  private async getMembershipById(membershipId: string | number): Promise<MembershipRow> {
    const response = await this.db
      .from('memberships')
      .select('*')
      .eq('id', membershipId)
      .maybeSingle();

    return requiredData(response, 'Membership non trovata') as MembershipRow;
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
      .select('*, membership:memberships(*)')
      .eq('id', leaveRequestId)
      .maybeSingle();

    return requiredData(response, 'Richiesta di uscita non trovata') as LeaveRequestRow;
  }

  private async countActiveMembers(clubId: string | number): Promise<number> {
    const response = await this.db
      .from('memberships')
      .select('id', { count: 'exact', head: true })
      .eq('club_id', clubId)
      .eq('status', 'active');

    return response.count ?? 0;
  }
}
